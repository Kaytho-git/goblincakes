#!/usr/bin/env bash
# Wine in the image, as new as possible: WineHQ's staging build when WineHQ publishes
# packages for this Fedora version, otherwise Fedora's own wine (usually only weeks behind).
# Winetricks too. (Games themselves mostly use Proton/GE-Proton inside Steam and Lutris.)
set -uo pipefail
. /etc/os-release
repo=https://dl.winehq.org/wine-builds/fedora/${VERSION_ID}/winehq.repo
if curl -fsSL -o /etc/yum.repos.d/winehq.repo "$repo" && dnf5 -y install winehq-staging; then
    echo "Installed WineHQ staging for Fedora ${VERSION_ID}"
else
    echo "WineHQ has no packages for Fedora ${VERSION_ID} (yet) – using Fedora's wine"
    rm -f /etc/yum.repos.d/winehq.repo
    dnf5 -y install wine || { echo "Could not install wine" >&2; exit 1; }
fi
# Kept out of the finished image: updates come with the image, not from WineHQ directly
rm -f /etc/yum.repos.d/winehq.repo
dnf5 -y install winetricks || echo "winetricks not available, skipping"
exit 0
