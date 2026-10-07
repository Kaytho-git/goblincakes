#!/usr/bin/env bash
# Builds Crystal Dock (https://github.com/dangvd/crystal-dock, GPL-3.0) – a dock with
# Mac-like zooming icons, as an alternative to Plasma's dock (`goblin dock crystal`).
# Not in Fedora's repos, so it's built here, in its own build stage; the result lands
# in /out and is copied into the image.
set -oue pipefail

dnf5 -y install git cmake gcc-c++ qt6-qtbase-devel qt6-qtbase-private-devel \
    wayland-devel layer-shell-qt-devel

# Newest release
tag=$(git ls-remote --tags --refs https://github.com/dangvd/crystal-dock 'v*' \
      | sed 's|.*refs/tags/||' | sort -V | tail -n1)
echo "Crystal Dock version: $tag"
src=/tmp/crystal-dock
git clone --depth 1 --branch "$tag" https://github.com/dangvd/crystal-dock "$src"

# GOBLINCAKES changes:
#  - an app dragged onto the dock (from AppGrid, Dolphin…) is pinned there;
#    Crystal Dock itself only pins through its right-click menus
#  - `pkill -USR1 crystal-dock` shows or hides the dock (the Meta key, goblincakes-dock toggle)
python3 - "$src/src/view/dock_panel.cc" <<'PY'
import sys
path = sys.argv[1]
s = open(path).read()

def sub(old, new):
    global s
    if old not in s:
        sys.exit(f"Crystal Dock patch: can't find {old!r} – the source has changed")
    s = s.replace(old, new, 1)

sub("#include <QVariant>\n", """#include <QVariant>
#include <QFile>
#include <QSocketNotifier>
#include <QStandardPaths>

#include <csignal>
#include <vector>
#include <sys/socket.h>
#include <unistd.h>

#include <model/launcher_config.h>
""")

sub("  setAcceptDrops(true);\n\n  createMenu();", """  setAcceptDrops(true);

  // GOBLINCAKES: SIGUSR1 shows the dock, or hides it again if a window covers it.
  {
    static std::vector<int> toggleFds;
    int fds[2];
    if (::socketpair(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0, fds) == 0) {
      toggleFds.push_back(fds[1]);
      std::signal(SIGUSR1, [](int) {
        for (int fd : toggleFds) { char c = 1; ssize_t r = ::write(fd, &c, 1); (void)r; }
      });
      auto* notifier = new QSocketNotifier(fds[0], QSocketNotifier::Read, this);
      connect(notifier, &QSocketNotifier::activated, this, [this, fd = fds[0]] {
        char buf[64];
        while (::read(fd, buf, sizeof(buf)) > 0) {}
        if (isHidden_) {
          setAutoHide(false);
        } else if (autoHide() || intellihideShouldHide()) {
          setAutoHide(true);
        }
      });
    }
  }

  createMenu();""")

sub("void DockPanel::dropEvent(QDropEvent* e) {\n", """void DockPanel::dropEvent(QDropEvent* e) {
  // GOBLINCAKES: pin apps dropped on the dock.
  bool pinned = false;
  for (const QUrl& url : e->mimeData()->urls()) {
    QString path = url.isLocalFile() ? url.toLocalFile() : QString();
    if (url.scheme() == "applications") {
      path = QStandardPaths::locate(QStandardPaths::ApplicationsLocation, url.path());
    }
    if (!path.endsWith(".desktop") || !QFile::exists(path)) {
      continue;
    }
    LauncherConfig launcher(path);
    if (!model_->launchers(dockId_).contains(launcher.appId)) {
      model_->addLauncher(dockId_, launcher);
    }
    pinned = true;
  }
  if (pinned) {
    for (const auto& item : items_) {
      if (Trash* trash = dynamic_cast<Trash*>(item.get())) {
        trash->setAcceptDrops(false);
      }
    }
    e->acceptProposedAction();
    return;
  }

""")

open(path, "w").write(s)
PY

cmake -S "$src/src" -B "$src/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build "$src/build" -j"$(nproc)"
DESTDIR=/out cmake --install "$src/build"
find /out -type f | sort
