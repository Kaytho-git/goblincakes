# GOBLINCAKES: runs at every login, before KWin and Plasma start.
# (Sourced by startplasma, so: no "exit", and unset our variables at the end.)

# On an atomic system every file in /usr has the same date, so Plasma never
# notices that our theme changed and keeps showing old cached images
# (e.g. a top bar and dock without background). When the GOBLINCAKES theme
# files differ from last login, throw those caches away.
_gc_state="${XDG_STATE_HOME:-$HOME/.local/state}/goblincakes"
_gc_cache="${XDG_CACHE_HOME:-$HOME/.cache}"
_gc_sum=$(find /usr/share/plasma/desktoptheme/goblincakes \
               /usr/share/plasma/look-and-feel/org.goblincakes.desktop \
               /usr/share/aurorae/themes/goblincakes \
               -type f -exec cat {} + 2>/dev/null | cksum)
if [ "$_gc_sum" != "$(cat "$_gc_state/theme-sum" 2>/dev/null)" ]; then
    rm -rf "$_gc_cache"/plasma_theme_* "$_gc_cache"/plasma-svgelements* \
           "$_gc_cache"/ksvg-elements* "$_gc_cache"/icon-cache.kcache \
           "$_gc_cache"/plasmashell/qmlcache 2>/dev/null
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

# The Meta key belongs to the dock (/usr/share/kglobalaccel/goblincakes-dock.desktop):
# the app launcher (AppGrid) gets Shift+Meta (written "Meta+Shift") and Alt+F1. Once, like Meta+A.
_gc_flag="$_gc_state/meta-freed"
if [ ! -e "$_gc_flag" ]; then
    kwriteconfig6 --file kglobalshortcutsrc --group plasmashell --key "activate application launcher" \
        "Meta+Shift$(printf '\t')Alt+F1,Meta$(printf '\t')Alt+F1,Activate Application Launcher"
    mkdir -p "$_gc_state" && touch "$_gc_flag"
fi

# Ghostty opens at 125x35 characters: add that to Ghostty configs written by
# goblincakes-firstlogin before the size was part of it (once; removing it sticks).
_gc_flag="$_gc_state/ghostty-size-added"
_gc_ghostty="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config.ghostty"
if [ ! -e "$_gc_flag" ]; then
    if grep -q '^# GOBLINCAKES defaults' "$_gc_ghostty" 2>/dev/null &&
       ! grep -q '^window-\(width\|height\)' "$_gc_ghostty"; then
        printf 'window-width = 125\nwindow-height = 35\n' >> "$_gc_ghostty"
    fi
    mkdir -p "$_gc_state" && touch "$_gc_flag"
fi

unset _gc_flag _gc_state _gc_cache _gc_sum _gc_kwinrc _gc_ghostty
