#!/usr/bin/env bash
# Hides Fedora/Universal Blue programs that GOBLINCAKES replaces or that few need
# from AppGrid (NoDisplay=true). They stay installed and still work (Dolphin's
# right-click menu, file types, other programs). The hidden ones are listed in
# /usr/share/goblincakes/hidden-apps; "goblin apps show <name>" shows one again.
set -euo pipefail

apps=/usr/share/applications
list=/usr/share/goblincakes/hidden-apps
patterns=(
    org.kde.kinfocenter.desktop            # Infocenter (goblin fast / Config show the basics)
    'org.kde.kwalletmanager*.desktop'      # KWallet manager (the wallet itself keeps working)
    firewall-config.desktop                # Firewall (the Ianseo switch handles it)
    org.kde.kmenuedit.desktop              # Menu editor
    org.kde.konsole.desktop                # Konsole (Ghostty is the terminal)
    org.kde.discover.desktop               # Discover (Config, goblin update, Flathub)
    org.kde.plasma-welcome.desktop         # Welcome to Plasma (Config does that)
    org.kde.kwrite.desktop                 # KWrite (Kate is there)
    org.kde.khelpcenter.desktop            # KDE help centre
    org.kde.kmag.desktop                   # Magnifier
    org.kde.kmousetool.desktop             # Auto-click accessibility tool
    'org.kde.drkonqi*.desktop'             # Crash reporter
    org.fcitx.Fcitx5.desktop               # Fcitx 5 input methods (Asian languages)
    'org.fcitx.fcitx5-*.desktop'
    'fcitx5-*.desktop'
    kbd-layout-viewer5.desktop
    im-chooser.desktop                     # Input method selector
)

mkdir -p "$(dirname "$list")"
: > "$list"
shopt -s nullglob
for pattern in "${patterns[@]}"; do
    files=()
    for f in "$apps"/$pattern; do
        [ -e "$f" ] && files+=("$f")
    done
    if [ ${#files[@]} -eq 0 ]; then
        echo "hide-apps: not in the image: $pattern"
        continue
    fi
    for f in "${files[@]}"; do
        # Already hidden by its own package (helpers) – nothing to show again later
        if grep -q '^NoDisplay=true' "$f"; then
            continue
        fi
        sed -i '/^NoDisplay=/d; /^\[Desktop Entry\]/a NoDisplay=true' "$f"
        basename "$f" .desktop >> "$list"
        echo "hide-apps: hidden $(basename "$f")"
    done
done

# Welcome to Plasma would otherwise still open by itself after Plasma upgrades
for f in /etc/xdg/autostart/org.kde.plasma-welcome*.desktop; do
    sed -i '/^Hidden=/d; /^\[Desktop Entry\]/a Hidden=true' "$f"
    echo "hide-apps: welcome autostart off"
done
