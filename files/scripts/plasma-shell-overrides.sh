#!/usr/bin/env bash
# GOBLINCAKES lock screen and logout screen over Plasma's own shell package files
# (kscreenlocker always reads the lock screen from the shell package; since Plasma 6.8 the
# logout screen too). Done here – after every module that installs RPMs – so a Plasma
# update pulled in during the build can't put KDE's own files back over ours.
set -oue pipefail

src=/usr/share/goblincakes/plasma-shell
dest=/usr/share/plasma/shells/org.kde.plasma.desktop/contents
for part in lockscreen logout; do
    mkdir -p "$dest/$part"
    cp -a "$src/$part/." "$dest/$part/"
done
cmp "$src/lockscreen/LockScreen.qml" "$dest/lockscreen/LockScreen.qml"
cmp "$src/logout/Logout.qml" "$dest/logout/Logout.qml"
echo "GOBLINCAKES lock screen and logout screen in place"
