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
               /usr/share/plasma/plasmoids/org.goblincakes.* \
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

# Meta+Left/Right/Up rotate the screens (goblincakes-rotate.desktop, the user's choice 29 Oct):
# take them away from KWin's quick tile left/right/top (once; changing it back sticks)
_gc_flag="$_gc_state/meta-arrows-rotate"
if [ ! -e "$_gc_flag" ]; then
    for _gc_now in "Left:Window Quick Tile Left:Fönster snabbt sida vid sida till vänster" \
                   "Right:Window Quick Tile Right:Fönster snabbt sida vid sida till höger" \
                   "Up:Window Quick Tile Top:Fönster snabbt sida vid sida längst upp"; do
        kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "$(echo "$_gc_now" | cut -d: -f2)" \
            "none,Meta+$(echo "$_gc_now" | cut -d: -f1),$(echo "$_gc_now" | cut -d: -f3)"
    done
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

# The clock had dropped back to normal weight (400) on the real install (11 Oct) – it looked
# thin and small. Back to semi-bold, once, only where the clock still has our font.
_gc_flag="$_gc_state/clock-weight"
if [ ! -e "$_gc_flag" ]; then
    [ -f "$_gc_applets" ] && python3 - "$_gc_applets" <<'EOF' >/dev/null 2>&1
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
def fix(m):
    body = m.group(2)
    if "fontFamily=IBM Plex Sans\n" in body and "fontWeight=400\n" in body:
        body = body.replace("fontWeight=400\n", "fontWeight=600\n")
    return m.group(1) + body
new = re.sub(r"(^\[[^\n]*\[Configuration\]\[Appearance\]\n)((?:[^\[\n][^\n]*\n|\n)*)", fix, text, flags=re.M)
if new != text:
    open(path, "w", encoding="utf-8").write(new)
EOF
    mkdir -p "$_gc_state" && touch "$_gc_flag"
fi

# AppGrid about half its size (16 Oct, the user's wish – as layout.js now does): small icons,
# 4 × 3 per page. Once, and only the keys not already set (own choices in AppGrid stay).
_gc_flag="$_gc_state/appgrid-smaller"
if [ ! -e "$_gc_flag" ]; then
    [ -f "$_gc_applets" ] && python3 - "$_gc_applets" <<'EOF' >/dev/null 2>&1
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
want = {"iconSize": "0", "gridColumns": "4", "gridRows": "3"}
for applet in re.findall(r"^\[(Containments\]\[\d+\]\[Applets\]\[\d+)\]\n(?:[^\[\n][^\n]*\n)*?plugin=dev\.xarbit\.appgrid\n", text, re.M):
    head = "[" + applet + "][Configuration][General]\n"
    if head not in text:
        text = text.rstrip("\n") + "\n\n" + head
    start = text.index(head) + len(head)
    end = re.compile(r"^\[", re.M).search(text, start)
    body = text[start:end.start() if end else len(text)]
    text = text[:start] + "".join(f"{k}={v}\n" for k, v in want.items()
                                  if not re.search(rf"^{k}=", body, re.M)) + text[start:]
open(path, "w", encoding="utf-8").write(text)
EOF
    mkdir -p "$_gc_state" && touch "$_gc_flag"
fi

# The GOBLINCAKES dock (29 Oct, the user's choice) instead of Plasma's task manager in the
# bottom panel: same "launchers" key, so only the plugin name changes and the pinned apps stay.
# Once, before Plasma reads the file. Only when the widget is in the image (a test copy in the
# home folder would go away again).
_gc_flag="$_gc_state/goblincakes-dock"
if [ ! -e "$_gc_flag" ] && [ -d /usr/share/plasma/plasmoids/org.goblincakes.dock ]; then
    [ -f "$_gc_applets" ] && python3 - "$_gc_applets" <<'EOF' >/dev/null 2>&1
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
def body(head):
    m = re.search(r"^\[" + re.escape(head) + r"\]\n((?:[^\[\n][^\n]*\n|\n)*)", text, re.M)
    return m.group(1) if m else ""
for cid in re.findall(r"^\[Containments\]\[(\d+)\]\n", text, re.M):
    panel = body(f"Containments][{cid}")
    if "plugin=org.kde.panel\n" not in panel or "location=4\n" not in panel:
        continue  # only the bottom panel (the dock), never the top bar
    applets = re.findall(rf"^\[Containments\]\[{cid}\]\[Applets\]\[(\d+)\]\n", text, re.M)
    plugins = {a: body(f"Containments][{cid}][Applets][{a}") for a in applets}
    if any("plugin=org.goblincakes.dock\n" in p for p in plugins.values()):
        continue
    for a, p in plugins.items():
        if "plugin=org.kde.plasma.icontasks\n" in p:
            head = f"[Containments][{cid}][Applets][{a}]\n"
            start = text.index(head) + len(head)
            text = text[:start] + text[start:].replace("plugin=org.kde.plasma.icontasks\n",
                                                       "plugin=org.goblincakes.dock\n", 1)
open(path, "w", encoding="utf-8").write(text)
EOF
    mkdir -p "$_gc_state" && touch "$_gc_flag"
fi

# Middle-click autoscroll as on Windows (11 Oct, the user's choice) in the Chromium-based
# Flatpaks – Chromium has it switched off on Linux. Firefox gets it from
# /usr/share/goblincakes/firefox. Once per browser, when it is installed; a browser
# installed later gets it at the next login. As a feature (--enable-features): the first
# version used --enable-blink-features, which Chromium shows a warning bar about in every
# window ("unsupported command line flag") – that line is swapped once (autoscroll2-).
# Not when the flags file already enables other features (a second --enable-features
# would replace them).
for _gc_was in org.chromium.Chromium:chromium com.google.Chrome:chrome com.brave.Browser:brave; do
    _gc_now="${_gc_was#*:}-flags.conf"
    _gc_was="${_gc_was%%:*}"
    _gc_flag="$_gc_state/autoscroll2-$_gc_was"
    [ -e "$_gc_flag" ] && continue
    [ -d "/var/lib/flatpak/app/$_gc_was" ] || [ -d "$HOME/.local/share/flatpak/app/$_gc_was" ] || continue
    _gc_now="$HOME/.var/app/$_gc_was/config/$_gc_now"
    [ -f "$_gc_now" ] && sed -i '/^--enable-blink-features=MiddleClickAutoscroll$/d' "$_gc_now"
    if ! grep -q 'enable-features' "$_gc_now" 2>/dev/null; then
        mkdir -p "$(dirname "$_gc_now")"
        [ -s "$_gc_now" ] && [ -n "$(tail -c1 "$_gc_now")" ] && echo >> "$_gc_now"
        echo '--enable-features=MiddleClickAutoscroll' >> "$_gc_now"
    fi
    mkdir -p "$_gc_state" && touch "$_gc_flag"
done

# Discord from Flathub → Discord's own build (11 Oct), once, in the background: login and
# settings come along (goblincakes-discord-move). The Flatpak mustn't start at this login
# while it moves; if the move fails it gets its autostart back and it's tried again next time.
_gc_flag="$_gc_state/discord-native"
if [ ! -e "$_gc_flag" ]; then
    if [ -d "$HOME/.local/share/flatpak/app/com.discordapp.Discord" ] && [ ! -x "$HOME/.local/share/discord-app/discord" ]; then
        _gc_auto="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/com.discordapp.Discord.desktop"
        _gc_was=0
        [ -e "$_gc_auto" ] && _gc_was=1 && rm -f "$_gc_auto"
        setsid /usr/libexec/goblincakes-discord-move "$_gc_flag" "$_gc_was" >/dev/null 2>&1 </dev/null &
    else
        mkdir -p "$_gc_state" && touch "$_gc_flag"
    fi
fi
# A dock icon pinned for the Flatpak points at Discord's own build once that's there
_gc_applets="${XDG_CONFIG_HOME:-$HOME/.config}/plasma-org.kde.plasma.desktop-appletsrc"
if [ -x "$HOME/.local/share/discord-app/discord" ] && [ -f "$_gc_applets" ] \
    && grep -q 'com\.discordapp\.Discord\.desktop' "$_gc_applets"; then
    sed -i '/^launchers=/s/com\.discordapp\.Discord\.desktop/discord.desktop/g' "$_gc_applets"
fi

# Discord through XWayland on Nvidia (12 Oct, the user: other people's streams stuttered – as
# if frames were skipped; at once smooth with --ozone-platform=x11). Electron picks Wayland by
# itself, and Discord's own chromiumSwitches setting only lets a few switches through, so the
# flag goes where Discord starts: its launcher (every start through the menu, ~/.local/bin and
# our autostart; checked at each login, Config writes a new launcher at updates) and Discord's
# own autostart file, which points straight at app-<version>/Discord and is rewritten by Discord.
_gc_launcher="$HOME/.local/share/discord-app/discord"
if [ -e /proc/driver/nvidia/version ] && [ -f "$_gc_launcher" ] && ! grep -q 'GOBLINCAKES' "$_gc_launcher"; then
    /usr/libexec/goblincakes-config-install discord-launcher >/dev/null 2>&1 || :
fi
_gc_auto="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/discord.desktop"
if [ -e /proc/driver/nvidia/version ] && [ -f "$_gc_auto" ] && ! grep -q 'ozone-platform' "$_gc_auto"; then
    sed -i '/^Exec=.*\/app-[0-9.]*\/Discord/s/$/ --ozone-platform=x11/' "$_gc_auto"
fi
# Discord's own file names the version folder, which is gone after the next Discord update
# (28 Oct, the user: Discord didn't start at login, app-1.0.166 → 1.0.167) – the launcher
# finds the newest version itself, so the entry points there instead
if [ -x "$_gc_launcher" ] && [ -f "$_gc_auto" ] && grep -q '^Exec=.*/app-[0-9.]*/Discord' "$_gc_auto"; then
    sed -i "/^Exec=/s|^Exec=[^ ]*/app-[0-9.]*/Discord|Exec=$_gc_launcher|; /^Icon=.*\\/app-[0-9.]*\\//s|^Icon=.*|Icon=${_gc_launcher%/*}/discord.png|" "$_gc_auto"
fi

# Autostart entries an AppImage wrote itself point into its temporary mount (/tmp/.mount_…),
# which is gone at the next login – WowUp's "start with the system" did that (15 Oct). They never
# work, so they go; GOBLINCAKES Config's own entries (Starta vid inloggning) start the AppImage.
# Those made before 15 Oct lack the app's quiet flag (WowUp --hidden, Archon --run-on-startup).
for _gc_f in "${XDG_CONFIG_HOME:-$HOME/.config}"/autostart/*.desktop; do
    [ -f "$_gc_f" ] || continue
    grep -q '^Exec=["]*/tmp/\.mount_' "$_gc_f" && rm -f "$_gc_f" && continue
    case "$_gc_f" in
        */appimage-wowup.desktop) _gc_arg=--hidden ;;
        */appimage-archon.desktop) _gc_arg=--run-on-startup ;;
        *) continue ;;
    esac
    grep -q '^X-GOBLINCAKES-Autostart=true' "$_gc_f" && ! grep -q -- "$_gc_arg" "$_gc_f" \
        && sed -i "s|^Exec=.*|& $_gc_arg|" "$_gc_f"
    # WowUp 2.24.1 shows its window despite --hidden (24 Oct): started through the helper
    case "$_gc_f" in
        */appimage-wowup.desktop)
            grep -q '^X-GOBLINCAKES-Autostart=true' "$_gc_f" && ! grep -q 'goblincakes-start-hidden' "$_gc_f" \
                && sed -i 's|^Exec=|Exec=/usr/libexec/goblincakes-start-hidden wowupcf -- |' "$_gc_f" ;;
    esac
done

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

# Web apps whose icon came from a small picture (blurry in AppGrid): a sharper one may
# be in the browser's cache by now, once the site has been opened (no network used)
if ls "$HOME"/.local/share/applications/goblincakes-webapp-*.desktop >/dev/null 2>&1; then
    setsid /usr/libexec/goblincakes-webapp-icon --upgrade >/dev/null 2>&1 </dev/null &
fi

# The accent colour (Config → Utseende): its copies of the Kvantum, GTK and window frame
# themes are made again when GOBLINCAKES' own themes changed (a new version) – before Plasma
# and the programs start
if [ -e "${XDG_CONFIG_HOME:-$HOME/.config}/goblincakes/accent" ]; then
    /usr/libexec/goblincakes-accent refresh >/dev/null 2>&1
fi

# Steam switches (goblin frames, MangoHud, the powerful graphics card) also in Steam's own
# "start at login" entry – Steam writes it again from its menu entry when that is switched –
# and Steam starts quietly in the system tray from there (-silent, 28 Oct)
if [ -e "${XDG_CONFIG_HOME:-$HOME/.config}/autostart/steam.desktop" ]; then
    /usr/libexec/goblincakes-tweak apply steam-desktop >/dev/null 2>&1 || :
fi

unset _gc_auto _gc_was _gc_now _gc_flag _gc_state _gc_cache _gc_sum _gc_kwinrc _gc_ghostty _gc_applets
