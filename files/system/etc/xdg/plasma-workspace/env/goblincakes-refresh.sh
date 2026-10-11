# GOBLINCAKES: runs at every login, before KWin and Plasma start.
# (Sourced by startplasma, so: no "exit", and unset our variables at the end.)

# On an atomic system every file in /usr has the same date, so Plasma never
# notices that our theme changed and keeps showing old cached images
# (e.g. a top bar and dock without background, an old wallpaper). When the GOBLINCAKES
# theme or wallpaper files differ from last login, throw those caches away.
_gc_state="${XDG_STATE_HOME:-$HOME/.local/state}/goblincakes"
_gc_cache="${XDG_CACHE_HOME:-$HOME/.cache}"
_gc_sum=$(find /usr/share/plasma/desktoptheme/goblincakes \
               /usr/share/plasma/look-and-feel/org.goblincakes.desktop \
               /usr/share/aurorae/themes/goblincakes \
               /usr/share/wallpapers/goblincakes \
               -type f -exec cat {} + 2>/dev/null | cksum)
if [ "$_gc_sum" != "$(cat "$_gc_state/theme-sum" 2>/dev/null)" ]; then
    rm -rf "$_gc_cache"/plasma_theme_* "$_gc_cache"/plasma-svgelements* \
           "$_gc_cache"/ksvg-elements* "$_gc_cache"/icon-cache.kcache \
           "$_gc_cache"/plasmashell/qmlcache "$_gc_cache"/plasma_wallpaper* \
           "$_gc_cache"/plasma_engine_preview* "$_gc_cache"/thumbnails 2>/dev/null
    mkdir -p "$_gc_state"
    printf '%s\n' "$_gc_sum" > "$_gc_state/theme-sum"
fi

# See-through windows while dragging: also switch it on in the user's own
# kwinrc (only if they haven't chosen anything themselves).
_gc_kwinrc="${XDG_CONFIG_HOME:-$HOME/.config}/kwinrc"
if ! grep -q '^translucencyEnabled=' "$_gc_kwinrc" 2>/dev/null; then
    kwriteconfig6 --file kwinrc --group Plugins --key translucencyEnabled true
    kwriteconfig6 --file kwinrc --group Effect-translucency --key MoveResize 75
fi

# Meta+A belongs to Goblin AI: take it away from Plasma's "walk through activities"
# (once; changing it back in System Settings sticks). Done here, before KWin starts
# kglobalacceld, so it isn't overwritten.
_gc_flag="$_gc_state/meta-a-freed"
if [ ! -e "$_gc_flag" ]; then
    kwriteconfig6 --file kglobalshortcutsrc --group plasmashell --key "next activity" "none,Meta+A,Walk through activities"
    mkdir -p "$_gc_state" && touch "$_gc_flag"
fi

# The Meta key opens the app launcher (AppGrid) again, Plasma's own default (10 Oct, the user's
# choice: on a real computer the dock comes up when the pointer touches the bottom middle, so
# "Meta shows the dock" (7–10 Oct) wasn't needed). Those versions moved the launcher to
# Shift+Meta: back to Meta + Alt+F1, once, and only if it's still what we set.
_gc_flag="$_gc_state/meta-launcher"
if [ ! -e "$_gc_flag" ]; then
    _gc_now=$(kreadconfig6 --file kglobalshortcutsrc --group plasmashell --key "activate application launcher")
    case $_gc_now in
        Meta+Shift*|Alt+F1*Meta+Shift*)
            kwriteconfig6 --file kglobalshortcutsrc --group plasmashell --key "activate application launcher" \
                "Meta$(printf '\t')Alt+F1,Meta$(printf '\t')Alt+F1,Activate Application Launcher" ;;
    esac
    mkdir -p "$_gc_state" && touch "$_gc_flag"
fi

# Ghostty opens at 100x28 characters: add that to Ghostty configs written by
# goblincakes-firstlogin before the size was part of it (once; removing it sticks).
_gc_flag="$_gc_state/ghostty-size-added"
_gc_ghostty="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config.ghostty"
if [ ! -e "$_gc_flag" ]; then
    if grep -q '^# GOBLINCAKES defaults' "$_gc_ghostty" 2>/dev/null &&
       ! grep -q '^window-\(width\|height\)' "$_gc_ghostty"; then
        printf 'window-width = 100\nwindow-height = 28\n' >> "$_gc_ghostty"
    fi
    mkdir -p "$_gc_state" && touch "$_gc_flag"
fi

# Smaller since 9 Oct (11 pt / 125x35 felt like 150 %): 10 pt and 100x28 in GOBLINCAKES Ghostty
# configs – once, and only values that are still the old defaults (changed ones stay).
_gc_flag="$_gc_state/ghostty-smaller"
if [ ! -e "$_gc_flag" ]; then
    if grep -q '^# GOBLINCAKES defaults' "$_gc_ghostty" 2>/dev/null; then
        sed -i 's/^font-size = 11$/font-size = 10/; s/^window-width = 125$/window-width = 100/; s/^window-height = 35$/window-height = 28/' "$_gc_ghostty"
    fi
    mkdir -p "$_gc_state" && touch "$_gc_flag"
fi

# The 9 Oct layout update wrote the dock's pinned apps back as ONE entry
# ("…ghostty.desktop\,…firefox.desktop": a white icon that gave an error). Split it
# again, once, before Plasma reads the file.
_gc_flag="$_gc_state/dock-launchers-fixed"
_gc_applets="${XDG_CONFIG_HOME:-$HOME/.config}/plasma-org.kde.plasma.desktop-appletsrc"
if [ ! -e "$_gc_flag" ]; then
    [ -f "$_gc_applets" ] && sed -i '/^launchers=/s/\\,/,/g' "$_gc_applets"
    mkdir -p "$_gc_state" && touch "$_gc_flag"
fi

# Discord installed before 10 Oct: start it at login through GOBLINCAKES' own autostart
# (Discord's own setting doesn't work in its Flatpak). Once – removing it later sticks.
_gc_flag="$_gc_state/discord-autostart"
if [ ! -e "$_gc_flag" ]; then
    if [ -d "$HOME/.local/share/flatpak/app/com.discordapp.Discord" ] || [ -d /var/lib/flatpak/app/com.discordapp.Discord ]; then
        /usr/libexec/goblincakes-config-install autostart com.discordapp.Discord --start-minimized >/dev/null 2>&1
    fi
    mkdir -p "$_gc_state" && touch "$_gc_flag"
fi

# VS Code left the image on 11 Oct (now Microsoft's own build in the home folder, from
# Config). Those who used the old one get the new one once, in the background (the
# download mustn't hold up the login); tried again at the next login if there's no network.
_gc_flag="$_gc_state/vscode-home"
if [ ! -e "$_gc_flag" ]; then
    if [ -x "$HOME/.local/share/vscode/code" ] || { [ ! -d "$HOME/.vscode" ] && [ ! -d "${XDG_CONFIG_HOME:-$HOME/.config}/Code" ]; }; then
        mkdir -p "$_gc_state" && touch "$_gc_flag"
    else
        setsid sh -c '
            for try in 1 2 3 4 5 6 7 8 9 10; do
                if /usr/libexec/goblincakes-config-install vscode; then
                    mkdir -p "$(dirname "$1")" && touch "$1"
                    notify-send --app-name=GOBLINCAKES --icon=goblincakes "VS Code är på plats" \
                        "VS Code hämtas nu från Microsoft till din hemmapp och uppdateras av goblin update. Dina inställningar och tillägg finns kvar."
                    exit 0
                fi
                sleep 30
            done' sh "$_gc_flag" >/dev/null 2>&1 </dev/null &
    fi
fi

unset _gc_now _gc_flag _gc_state _gc_cache _gc_sum _gc_kwinrc _gc_ghostty _gc_applets
