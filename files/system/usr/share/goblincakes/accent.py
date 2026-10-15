"""GOBLINCAKES' accent colour: the chosen colour and the shades worked out from it.

Shared by /usr/libexec/goblincakes-accent (which applies it to Plasma, Kvantum, GTK, Firefox
and the login screen) and GOBLINCAKES' own windows (Config, Goblin AI, GoblinRecorder,
Avinstallera, goblin graph), which show it through the QML context property "accent":
    accent.color   buttons, ticks, switches, frames, focus, the tab line
    accent.hover   a button under the mouse
    accent.on      text, ticks and knobs drawn on top of accent.color (dark on light colours)
    accent.text    small text in the accent colour on the dark background (lighter if needed)
    accent.dim     a dark tile in the accent colour (chosen buttons, the active program)
    accent.error / accent.errorBright   errors and close buttons (orange for Death Knight)
Only the standard library (the apps import it before Qt is involved).
"""
import json
import os
from pathlib import Path

HERE = Path(__file__).resolve().parent
ACCENTS_FILE = HERE / "accents.json"
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "goblincakes"
CHOICE = CONFIG / "accent"          # the chosen id, one line
PALETTE = CONFIG / "accent.json"    # the worked-out colours, read by the windows

STANDARD = "#2F6FED"
BACKGROUND = "#0E1420"   # cards and lists – where small accent text sits
PANEL = "#0B1018"        # title bars and panels – under accent.dim
FROST = "#E6ECF5"
VOID = "#07090D"

# The standard look, exactly as before the choice existed
DEFAULT = {"id": "standard", "name": "GOBLINCAKES blå", "color": STANDARD, "hover": "#4A82F0",
           "on": FROST, "text": STANDARD, "dim": "#1B3A78", "error": "#A4262C", "errorBright": "#E5484D"}

# Death Knight's red is next to the red of errors and the close button: those turn orange
ERROR_OVERRIDE = {"deathknight": ("#C2570F", "#F0883E")}


def accents():
    try:
        return json.loads(ACCENTS_FILE.read_text())["accents"]
    except (OSError, ValueError, KeyError):
        return [{"id": "standard", "name": DEFAULT["name"], "color": STANDARD, "words": []}]


def find(word):
    """An id, a name or one of its words (goblin färg dk) → the accent, or None."""
    w = word.strip().lower().replace(" ", "").replace("-", "")
    for a in accents():
        if w in (a["id"], a["name"].lower().replace(" ", "")) or w in a.get("words", []):
            return a
    return None


def chosen_id():
    try:
        value = CHOICE.read_text().strip()
    except OSError:
        return "standard"
    return value if find(value) else "standard"


# ── Colour arithmetic ────────────────────────────────────────────

def rgb(hexcolor):
    h = hexcolor.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hexc(r, g, b):
    return "#%02X%02X%02X" % tuple(max(0, min(255, round(v))) for v in (r, g, b))


def mix(a, b, t):
    """t = 0 → a, 1 → b."""
    return hexc(*(x + (y - x) * t for x, y in zip(rgb(a), rgb(b))))


def luminance(c):
    def lin(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(v) for v in rgb(c))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def palette(accent_id=None):
    """All the colours for one accent (the chosen one when no id is given)."""
    a = find(accent_id or chosen_id()) or find("standard")
    if not a or a["id"] == "standard":
        return dict(DEFAULT)
    c = a["color"]
    light = luminance(c) > 0.45
    on = FROST if contrast(c, FROST) >= contrast(c, VOID) else VOID
    hover = mix(c, VOID, 0.15) if light else mix(c, "#FFFFFF", 0.15)
    text = c
    for _ in range(12):  # dark colours: lighter until small text reads well (WCAG 4.5:1)
        if contrast(text, BACKGROUND) >= 4.5:
            break
        text = mix(text, "#FFFFFF", 0.12)
    error, error_bright = ERROR_OVERRIDE.get(a["id"], (DEFAULT["error"], DEFAULT["errorBright"]))
    return {"id": a["id"], "name": a["name"], "color": c, "hover": hover, "on": on, "text": text,
            "dim": mix(PANEL, c, 0.45), "error": error, "errorBright": error_bright}


def current():
    """What the windows show: the saved colours, else the standard."""
    p = dict(DEFAULT)
    try:
        p.update(json.loads(PALETTE.read_text()))
    except (OSError, ValueError):
        pass
    return p


# ── Recolouring theme files ──────────────────────────────────────

def _hsl(c):
    r, g, b = (v / 255 for v in rgb(c))
    mx, mn = max(r, g, b), min(r, g, b)
    l = (mx + mn) / 2
    if mx == mn:
        return 0.0, 0.0, l
    d = mx - mn
    s = d / (2 - mx - mn) if l > 0.5 else d / (mx + mn)
    if mx == r:
        h = (g - b) / d + (6 if g < b else 0)
    elif mx == g:
        h = (b - r) / d + 2
    else:
        h = (r - g) / d + 4
    return h * 60, s, l


def _from_hsl(h, s, l):
    def f(n):
        k = (n + h / 30) % 12
        a = s * min(l, 1 - l)
        return l - a * max(-1, min(k - 3, 9 - k, 1))
    return hexc(f(0) * 255, f(8) * 255, f(4) * 255)


def is_accent_shade(c):
    """GOBLINCAKES' blues in the themes (#2F6FED and its lighter/darker variants) – not the
    dark navy backgrounds, which are blue too but dark and greyish."""
    h, s, l = _hsl(c)
    return 200 <= h <= 240 and s >= 0.5 and l >= 0.28


def shade_for(c, target):
    """The same step lighter/darker from the standard blue, in the target colour."""
    _, s0, l0 = _hsl(STANDARD)
    _, s1, l1 = _hsl(c)
    h, s, l = _hsl(target)
    return _from_hsl(h, max(0.0, min(1.0, s * (s1 / s0) if s0 else s)), max(0.0, min(1.0, l + (l1 - l0))))


def recolor(text, target):
    """Every accent shade in a theme file (#RRGGBB, any case) → the matching shade of target."""
    import re
    if target.upper() == STANDARD:
        return text
    def sub(m):
        c = "#" + m.group(1).upper()
        return shade_for(c, target) if is_accent_shade(c) else m.group(0)
    return re.sub(r"#([0-9A-Fa-f]{6})\b", sub, text)


def install(engine):
    """GOBLINCAKES' own windows: the QML context property "accent" (see the top of this file),
    changed live when another colour is chosen (Config, goblin färg). Call before engine.load()."""
    from PySide6.QtCore import QFileSystemWatcher
    ctx = engine.rootContext()
    ctx.setContextProperty("accent", current())
    CONFIG.mkdir(parents=True, exist_ok=True)
    watcher = QFileSystemWatcher([str(CONFIG)], engine)

    def changed(*_):
        if PALETTE.exists() and str(PALETTE) not in watcher.files():
            watcher.addPath(str(PALETTE))
        ctx.setContextProperty("accent", current())

    if PALETTE.exists():
        watcher.addPath(str(PALETTE))
    watcher.directoryChanged.connect(changed)
    watcher.fileChanged.connect(changed)
    engine.setProperty("goblincakesAccentWatcher", watcher)  # keeps it alive with the engine
    return watcher
