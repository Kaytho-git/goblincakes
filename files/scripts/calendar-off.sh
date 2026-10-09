#!/usr/bin/env bash
# Calendar accounts (KDE PIM: kdepim-addons, kdepim-runtime, merkuro) are in the image but off
# until the user switches on Config → Inställningar → Kalender med konton: their autostarts
# would otherwise start Akonadi (database + background services) for everyone at login.
# Hidden here, listed for goblincakes-tweak, which copies them back for that user.
set -euo pipefail
list=/usr/share/goblincakes/calendar-autostart
mkdir -p "$(dirname "$list")"
: > "$list"
for f in $(rpm -ql kdepim-runtime kdepim-addons merkuro akonadi-server 2>/dev/null | grep '^/etc/xdg/autostart/.*\.desktop$' | sort -u); do
    [ -e "$f" ] || continue
    sed -i '/^Hidden=/d; /^\[Desktop Entry\]/a Hidden=true' "$f"
    basename "$f" >> "$list"
    echo "calendar-off: $(basename "$f") hidden"
done
echo "calendar-off: $(wc -l < "$list") autostart entries hidden"
