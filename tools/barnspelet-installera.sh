#!/bin/bash
# Barnspelet → barnläget på den här datorn (användaren 15 nov: "liggandes i barnläget så min son kan testa
# det … utan att redigeraren ligger med"). Kopierar Godot och spelet till hemmappen, skriver menyfilen och
# lägger spelet bland barnlägets rutor (kids.json, en kopia av den gamla sparas först). Kör igen efter ändringar.
#   tools/barnspelet-installera.sh <godot-programmet>
set -euo pipefail
GODOT=${1:?"Ange Godot-programmet (officiella 4.5.1, se docs/anteckningar.md \"Steg 1 – provbanan\")"}
REPO=$(cd "$(dirname "$0")/.." && pwd)
DEST=$HOME/.local/share/goblincakes/barnspelet
APP=$HOME/.local/share/applications/goblincakes-barnspelet.desktop
mkdir -p "$DEST/spel" "$(dirname "$APP")"
"$GODOT" --headless --path "$REPO/games/barnspelet" --import >/dev/null 2>&1 || true
install -m 755 "$GODOT" "$DEST/godot"
rsync -a --delete "$REPO/games/barnspelet/" "$DEST/spel/"
# Banorna som de är sparade i git – inte det som just nu ligger i redigeraren (15 nov: vatten vid starten
# hade följt med till sonen)
for f in "$REPO"/games/barnspelet/banor/*; do
    rel=games/barnspelet/banor/$(basename "$f")
    if git -C "$REPO" cat-file -e "HEAD:$rel" 2>/dev/null; then
        git -C "$REPO" show "HEAD:$rel" > "$DEST/spel/banor/$(basename "$f")"
    else
        rm -f "$DEST/spel/banor/$(basename "$f")"
    fi
done
python3 - "$DEST" <<'PY'
import sys
from pathlib import Path
from PIL import Image
dest = Path(sys.argv[1])
sheet = Image.open(dest / "spel/bilder/pojken.png")
import json
info = json.loads((dest / "spel/bilder/pojken.json").read_text())
cw, ch = info["cell"]
modig = dest / "spel/bilder/modig.png"
if modig.is_file():  # pojken som står modigt (barnlägets ruta)
    frame = Image.open(modig)
    cw, ch = frame.size
else:
    i = info["frames"].index("idle3")  # tittar på oss
    frame = sheet.crop((cw * i, 0, cw * (i + 1), ch))
side = max(cw, ch)
icon = Image.new("RGBA", (side, side))
icon.alpha_composite(frame, ((side - cw) // 2, side - ch))
icon.resize((side * 2, side * 2), Image.NEAREST).save(dest / "ikon.png")
PY
cat > "$APP" <<DESK
[Desktop Entry]
Type=Application
Name=A Boy to the Rescue
Comment=Pojken som räddar sina gossedjur (GOBLINCAKES barnläge)
Exec=$DEST/godot --path $DEST/spel -- --barnlage
Icon=$DEST/ikon.png
StartupWMClass=A Boy to the Rescue
Categories=Game;
DESK
python3 - <<'PY'
import json, shutil, time
from pathlib import Path
f = Path.home() / ".config/goblincakes/kids.json"
if not f.is_file():
    print("Inget barnläge uppsatt (kids.json saknas) – lägg till Barnspelet i Config → BARNLÄGE")
    raise SystemExit
d = json.loads(f.read_text())
items = d.setdefault("items", [])
old = [i for i in items if i.get("id") == "goblincakes-barnspelet.desktop"]
if old:
    if old[0].get("name") != "A Boy to the Rescue":
        old[0]["name"] = "A Boy to the Rescue"
        f.write_text(json.dumps(d, ensure_ascii=False, indent=1) + "\n")
    print("Spelet finns redan i barnläget")
else:
    shutil.copy2(f, f.with_name(f"kids.json.fore-barnspelet-{time.strftime('%Y%m%d-%H%M%S')}"))
    items.append({"kind": "app", "id": "goblincakes-barnspelet.desktop", "name": "A Boy to the Rescue"})
    f.write_text(json.dumps(d, ensure_ascii=False, indent=1) + "\n")
    print("Barnspelet tillagt i barnläget")
PY
echo "Klart: $DEST"
