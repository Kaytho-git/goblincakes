#!/bin/bash
# Menyposten "A Boy to the Rescue – Redigera" (användaren 15 nov): startar spelet ur repomappen (där
# redigerarens ändringar sparas) med banväljaren (-- --meny). Godot-kopian och ikonen från
# tools/barnspelet-installera.sh. Bara på användarens dator – aldrig i barnläget.
#   tools/barnspelet-redigera-meny.sh
set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
DEST=$HOME/.local/share/goblincakes/barnspelet
APP=$HOME/.local/share/applications/goblincakes-barnspelet-redigera.desktop
[ -x "$DEST/godot" ] || { echo "Kör tools/barnspelet-installera.sh <godot> först (Godot-kopian saknas)"; exit 1; }
mkdir -p "$(dirname "$APP")"
cat > "$APP" <<DESK
[Desktop Entry]
Type=Application
Name=A Boy to the Rescue – Redigera
Comment=Välj bana, bygg och provspela (barnspelet)
Exec=$DEST/godot --path "$REPO/games/barnspelet" -- --meny
Icon=$DEST/ikon.png
StartupWMClass=A Boy to the Rescue
Categories=Game;
DESK
update-desktop-database "$(dirname "$APP")" 2>/dev/null || true
echo "  ✓ $APP"
