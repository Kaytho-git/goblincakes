#!/usr/bin/env bash
# Builds AppGrid with square corners, in its own build stage (see "stages" in recipe.yml).
# AppGrid's QML is compiled into the program, so the rounded corners (Kirigami's
# cornerRadius) can't be changed from outside. The result lands in /out and is copied
# over the COPR package's files in the image (which still brings in AppGrid's dependencies).
set -oue pipefail

dnf5 -y install dnf5-plugins git cmake extra-cmake-modules gcc-c++ gettext \
    qt6-qtbase-devel qt6-qtbase-private-devel qt6-qtdeclarative-devel libplasma-devel \
    kf6-kpackage-devel kf6-kio-devel kf6-kservice-devel kf6-ki18n-devel kf6-kconfig-devel \
    kf6-kcoreaddons-devel kf6-kcolorscheme-devel kf6-kiconthemes-devel kf6-ksvg-devel \
    kf6-kwindowsystem-devel kf6-krunner-devel layer-shell-qt-devel plasma-activities-devel \
    plasma-activities-stats-devel plasma-workspace-devel appstream-qt-devel

# Same version as the COPR package, so the rest of its files match
dnf5 -y copr enable scujas/plasma-applet-appgrid
version=$(dnf5 repoquery -q --latest-limit=1 --qf '%{version}\n' plasma-applet-appgrid | tail -n1)
echo "AppGrid version in COPR: ${version:-unknown}"

src=/tmp/appgrid
if ! git clone --depth 1 --branch "v${version}" https://github.com/xarbit/appgrid "$src"; then
    echo "No tag v${version}, building the newest release instead"
    tag=$(git ls-remote --tags --refs --sort=-v:refname https://github.com/xarbit/appgrid 'v*' | head -n1 | sed 's|.*refs/tags/||')
    git clone --depth 1 --branch "$tag" https://github.com/xarbit/appgrid "$src"
    version=${tag#v}
fi

# GOBLINCAKES: everything flat with straight corners
{ grep -rl 'Kirigami\.Units\.cornerRadius' "$src/package" || true; } | xargs -r sed -i 's/Kirigami\.Units\.cornerRadius/0/g'
if grep -rq 'Kirigami\.Units\.cornerRadius' "$src/package"; then
    echo "Rounded corners left in AppGrid" >&2
    exit 1
fi

cmake -S "$src" -B "$src/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DKDE_INSTALL_USE_QT_SYS_PATHS=ON \
    -DBUILD_TESTING=OFF \
    -DAPPGRID_VERSION_OVERRIDE="$version"
cmake --build "$src/build" -j"$(nproc)"
DESTDIR=/out cmake --install "$src/build"
find /out -type f | sort
