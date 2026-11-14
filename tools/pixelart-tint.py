#!/usr/bin/env python3
"""Coloured copies of Kakan's gold sparkle and white star for Barnläge's splash (14 Nov).

Her pictures are gold and white (pink and purple would have been taken for the magenta background when they were
cleaned), and a live colour effect (MultiEffect) isn't drawn without a graphics card – so the colours are made here
once: every pixel moves towards the colour times its own brightness (a little lifted) – the star 60 %, the gold
sparkle 90 % (less turned gold into mud); white stays a pale tint, the outline dark.

    python3 tools/pixelart-tint.py        → kids/pixelart/<gnista|stjarna>-<rrggbb>.png
Glint.qml picks them by the colour; keep COLOURS in step with starColours in Splash.qml.
"""
from pathlib import Path

from PySide6.QtGui import QColor, QImage

KIDS = Path(__file__).resolve().parents[1] / "files/system/usr/share/goblincakes/kids/pixelart"
COLOURS = ["ff7eb6", "7fe3ff", "b69cff", "8cffb0", "ffb86b"]   # gold and white use the pictures as they are
AMOUNT = {"stjarna": 0.6, "gnista": 0.9}


def tint(src, colour, amount):
    img = QImage(str(src)).convertToFormat(QImage.Format.Format_RGBA8888)
    c = QColor("#" + colour)
    for y in range(img.height()):
        for x in range(img.width()):
            p = img.pixelColor(x, y)
            if p.alpha() == 0:
                continue
            g = min(1.0, 1.25 * (0.299 * p.red() + 0.587 * p.green() + 0.114 * p.blue()) / 255)
            mix = [min(255, round(a * (1 - amount) + b * g * amount)) for a, b in
                   ((p.red(), c.red()), (p.green(), c.green()), (p.blue(), c.blue()))]
            img.setPixelColor(x, y, QColor(*mix, p.alpha()))
    return img


def main():
    for base in ("gnista", "stjarna"):
        for colour in COLOURS:
            out = KIDS / f"{base}-{colour}.png"
            tint(KIDS / f"{base}.png", colour, AMOUNT[base]).save(str(out))
            print(out.name)


if __name__ == "__main__":
    main()
