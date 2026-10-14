#!/usr/bin/env bash
# AppGrid from the COPR package – brings AppGrid's runtime dependencies, and is the fallback
# if our own build (appgrid-square stage) failed. Doesn't stop the build when the package can't
# be installed (e.g. a new Plasma the COPR hasn't been rebuilt for yet) – check-appgrid.sh
# afterwards decides whether the image has a working AppGrid.
set -oue pipefail

dnf5 -y install dnf5-plugins
dnf5 -y copr enable scujas/plasma-applet-appgrid
if dnf5 -y install plasma-applet-appgrid; then
    echo "AppGrid COPR package installed"
else
    echo "WARNING: AppGrid's COPR package can't be installed right now – relying on our own build" >&2
fi
dnf5 -y copr remove scujas/plasma-applet-appgrid || rm -f /etc/yum.repos.d/_copr*plasma-applet-appgrid*.repo
