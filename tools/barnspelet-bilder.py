#!/usr/bin/python3
"""The kids' platform game (games/barnspelet): ChatGPT/Codex's drawings → real pixel art in the game.

    python3 tools/barnspelet-bilder.py [delar …]      figur, triumf, racerbil, saker, mark (default: all that exist)

The drawings lie in ~/Bilder/barnspelet (GOBLINCAKES_BARNSPEL_SRC) as Codex drew them (magenta background,
not in the repo, 1–2 MB each). Each figure is cut out (the magenta key), put on one pixel grid (the most common
colour in the middle of each square – goblincakes-pixelart's cells()), all its frames share one palette, and
the feet stand on the bottom row. Scale = drawn pixels per game pixel, taken from a reference frame whose
height in game pixels is fixed (the boy: 96). Out: games/barnspelet/bilder/<namn>.png (frames side by side,
equal cells) + <namn>.json (cell size, frame names) for the game.

What was learnt about the walk (15 Nov, the user): two contact frames + two passing frames; the far leg darker
and in the passing frame where the near leg swings, the near leg must be drawn IN FRONT of the straight leg
(colour alone read as "the same leg every time").
"""
import importlib.machinery
import importlib.util
import json
import os
import sys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent
SRC = Path(os.environ.get("GOBLINCAKES_BARNSPEL_SRC", Path.home() / "Bilder/barnspelet"))
OUT = REPO / "games/barnspelet/bilder"
_loader = importlib.machinery.SourceFileLoader("pixelart", str(REPO / "files/system/usr/libexec/goblincakes-pixelart"))
_spec = importlib.util.spec_from_loader("pixelart", _loader)
pa = importlib.util.module_from_spec(_spec)
_loader.exec_module(pa)


class Drawing:
    """One drawn picture: the figures in it (cut out by the magenta key), in reading order."""

    def __init__(self, name, grid=False, join=0):
        self.join = join  # gaps narrower than this (px) inside one figure are kept together
        im = Image.open(SRC / name).convert("RGBA")
        self.w, self.h = im.size
        get = im.get_flattened_data if hasattr(im, "get_flattened_data") else im.getdata
        # strip_halo is not used: the red hoodie (blue a little above green) counted as glow
        self.px = [None if pa.is_key(p) else p for p in get()]
        self.boxes = self._grid() if grid == True else (self._parts() if grid == "delar" else self._columns(0, self.h))

    def _used_cols(self, y0, y1):
        w, px = self.w, self.px
        return [any(px[y * w + x] is not None for y in range(y0, y1, 2)) for x in range(w)]

    def _runs(self, flags, least):
        runs, i = [], 0
        while i < len(flags):
            if flags[i]:
                s = i
                while i < len(flags) and flags[i]:
                    i += 1
                if i - s > least:
                    runs.append((s, i))
            i += 1
        return runs

    def _columns(self, y0, y1):
        boxes = []
        runs = []
        for s, e in self._runs(self._used_cols(y0, y1), 30):
            if runs and s - runs[-1][1] < self.join:  # one figure in pieces (a cracked coconut) – keep it together
                runs[-1] = (runs[-1][0], e)
            else:
                runs.append((s, e))
        for s, e in runs:
            ys = [y for y in range(y0, y1) if any(self.px[y * self.w + x] is not None for x in range(s, e, 2))]
            boxes.append((s, ys[0], e, ys[-1] + 1))
        return boxes

    def _parts(self, step=4):
        """Figures as connected pieces (on a coarse grid) – for pictures where one figure reaches over
        another's columns (the palm's leaves over the banana). Left to right."""
        w, h, px = self.w, self.h, self.px
        gw, gh = w // step, h // step
        on = [[px[(y * step) * w + x * step] is not None for x in range(gw)] for y in range(gh)]
        seen = [[False] * gw for _ in range(gh)]
        boxes = []
        for y in range(gh):
            for x in range(gw):
                if not on[y][x] or seen[y][x]:
                    continue
                stack, x0, y0, x1, y1, n = [(x, y)], x, y, x, y, 0
                seen[y][x] = True
                while stack:
                    cx, cy = stack.pop()
                    n += 1
                    x0, y0, x1, y1 = min(x0, cx), min(y0, cy), max(x1, cx), max(y1, cy)
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            nx, ny = cx + dx, cy + dy
                            if 0 <= nx < gw and 0 <= ny < gh and on[ny][nx] and not seen[ny][nx]:
                                seen[ny][nx] = True
                                stack.append((nx, ny))
                if n > 40:
                    boxes.append((x0 * step, y0 * step, (x1 + 1) * step, (y1 + 1) * step))
        return sorted(boxes)

    def _grid(self):
        w, px = self.w, self.px
        rows = [any(px[y * w + x] is not None for x in range(0, w, 2)) for y in range(self.h)]
        return [b for y0, y1 in self._runs(rows, 30) for b in self._columns(y0, y1)]

    def common_ground(self):
        """All frames stand on the same ground line (the lowest foot) – frames with both feet in the air
        (the run's flight) keep their height above it instead of being put on the ground."""
        y1 = max(b[3] for b in self.boxes)
        self.boxes = [(x0, y0, x1, y1) for x0, y0, x1, _ in self.boxes]

    def scale_for(self, i, game_height):
        x0, y0, x1, y1 = self.boxes[i]
        return (y1 - y0) / game_height

    def peel(self, scale):
        """The outermost source pixels carry a little magenta – peel off about a third of a square."""
        w, h, px = self.w, self.h, self.px
        for _ in range(max(1, round(scale * 0.3))):
            edge = [i for i, p in enumerate(px) if p is not None and (
                i % w == 0 or px[i - 1] is None or i % w == w - 1 or px[i + 1] is None or
                i < w or px[i - w] is None or i >= w * (h - 1) or px[i + w] is None)]
            for i in edge:
                px[i] = None

    def cut(self, i, scale, size=None):
        """Frame i → (tw, th, cells). size = exact (tw, th) (tiles); else the box divided by the scale.
        Other figures' boxes inside this one are blanked first – the palm's box reached over the banana
        lying next to it, and half a banana stood at every palm (the user, 15 Nov)."""
        x0, y0, x1, y1 = self.boxes[i]
        tw, th = size or (max(1, round((x1 - x0) / scale)), max(1, round((y1 - y0) / scale)))
        px = self.px
        area = (x1 - x0) * (y1 - y0)
        # only smaller figures inside this one – never a bigger one around it (the banana lies inside the palm's
        # box; blanking the palm's box cut the banana in half, 15 Nov)
        others = [b for j, b in enumerate(self.boxes) if j != i and b[0] < x1 and b[2] > x0 and b[1] < y1 and b[3] > y0
                  and (b[2] - b[0]) * (b[3] - b[1]) < area]
        if others:
            px = list(px)
            for bx0, by0, bx1, by1 in others:
                for y in range(max(by0, y0), min(by1, y1)):
                    for x in range(max(bx0, x0), min(bx1, x1)):
                        px[y * self.w + x] = None
        return tw, th, pa.cells(self.w, self.h, px, self.boxes[i], tw, th, False)


def is_leg(c):
    r, g, b = c[:3]
    return (b > r + 40 and b > g + 10) or (r > 150 and g > 150 and b > 170)  # trousers or sneakers


def darken_leg(img, side):
    """The far leg darker: below the hoodie's hem, on one side of the thinnest column between the legs."""
    w, h = img.size
    red = [y for y in range(h) for x in range(w)
           if (lambda c: c[3] and c[0] > 150 and c[1] < 110 and c[2] < 110)(img.getpixel((x, y)))]
    y0 = max(red) - 2
    cols = [sum(1 for y in range(y0 + 4, h) if img.getpixel((x, y))[3] and is_leg(img.getpixel((x, y)))) for x in range(w)]
    xs = [x for x in range(w) if cols[x]]
    mid = (xs[0] + xs[-1]) // 2
    split = min(range(mid - 8, mid + 9), key=lambda x: (cols[x], abs(x - mid)))
    for y in range(y0, h):
        for x in range(w):
            c = img.getpixel((x, y))
            if c[3] and is_leg(c) and ((x < split) if side == "left" else (x >= split)):
                img.putpixel((x, y), (round(c[0] * .62), round(c[1] * .62), round(c[2] * .74), 255))


def sheet(name, cuts, names, colours=32, pad=4, bottom=True, fixed=None):
    """cuts → one strip of equal cells with a shared palette; returns the cell images."""
    used = sorted({c[:3] for _, _, o in cuts for c in o if c is not None})
    pal = pa.median_cut(used, colours)
    memo = {}
    cw, ch = fixed or (max(tw for tw, _, _ in cuts) + pad, max(th for _, th, _ in cuts) + pad // 2)
    cells = []
    for tw, th, o in cuts:
        img = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        ox = (cw - tw) // 2
        oy = ch - th if bottom else (ch - th) // 2
        for y in range(th):
            for x in range(tw):
                c = o[y * tw + x]
                if c is not None:
                    img.putpixel((ox + x, oy + y), (*memo.setdefault(c[:3], pa.nearest(c[:3], pal)), 255))
        cells.append(img)
    return cells, (cw, ch)


def save(name, cells, size, names):
    cw, ch = size
    out = Image.new("RGBA", (cw * len(cells), ch), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        out.paste(c, (i * cw, 0))
    OUT.mkdir(parents=True, exist_ok=True)
    out.save(OUT / f"{name}.png")
    (OUT / f"{name}.json").write_text(json.dumps({"cell": [cw, ch], "frames": names}, ensure_ascii=False) + "\n")
    print(f"  ✓ {name}: {len(cells)} bilder à {cw}×{ch}")


# ── The parts ────────────────────────────────────────────────────

def figur():
    """The boy, 96 px: stå, kliv, mellan (far leg swings, behind), kliv, mellan (near leg swings, in front),
    hopp, oj."""
    std = Drawing("pojken-prov1.png")                 # stå, gång, gång, hopp (only stå and hopp used)
    walk = Drawing("pojken-gangcykel-prov3.png")      # kliv, (mellan), kliv, (mellan)
    pass_far = Drawing("pojken-mellansteg-prov4.png")  # far leg swings
    pass_near = Drawing("pojken-mellansteg-nara-prov5.png")
    oj = Drawing("pojken-oj-prov.png")
    run = Drawing("pojken-spring-prov.png")   # push, flight, push, flight – near leg always in front
    fall = Drawing("pojken-fall-prov.png")    # fall, bromsa
    idle = Drawing("pojken-idle-prov.png")    # stå, andas in, tittar på oss, tittar upp (fötterna stilla)
    duck = Drawing("pojken-duck-prov.png")    # ducka, glida (huvudet lika stort som när han står → 68 px hög)
    s = std.scale_for(0, 96)
    pass_h = round((walk.boxes[1][3] - walk.boxes[1][1]) / s)
    s_far, s_near = pass_far.scale_for(0, pass_h), pass_near.scale_for(0, pass_h)
    s_oj = oj.scale_for(0, 96)
    s_run = s * ((run.boxes[0][3] - run.boxes[0][1]) / (walk.boxes[0][3] - walk.boxes[0][1])) ** 0  # same canvas as the walk
    s_fall = fall.scale_for(0, 96)
    s_idle = idle.scale_for(0, 96)
    duck.common_ground()
    s_duck = duck.scale_for(0, 68)
    for d, k in ((std, s), (walk, s), (pass_far, s_far), (pass_near, s_near), (oj, s_oj), (run, s_run), (fall, s_fall),
                 (idle, s_idle), (duck, s_duck)):
        d.peel(k)
    run.common_ground()
    idle.common_ground()
    cuts = [std.cut(0, s), walk.cut(0, s), pass_far.cut(0, s_far), walk.cut(2, s), pass_near.cut(0, s_near),
            std.cut(3, s), oj.cut(0, s_oj)] + [run.cut(i, s_run) for i in range(4)] + [fall.cut(0, s_fall), fall.cut(1, s_fall)] + \
        [idle.cut(i, s_idle) for i in range(4)] + [duck.cut(0, s_duck), duck.cut(1, s_duck)]
    names = ["sta", "kliv1", "mellan1", "kliv2", "mellan2", "hopp", "oj", "spring1", "spring2", "spring3", "spring4",
             "fall", "bromsa", "idle1", "idle2", "idle3", "idle4", "duck", "glid"]
    cells, size = sheet("pojken", cuts, names)
    # The far leg darker – walk: kliv1, mellan1, kliv2; run (15 Nov: Codex drew the alternation right, but its
    # dark blue was too close to the light one, the user saw "the same leg up every time"): push 1 and flight 1 =
    # far knee forward (right), push 2 and flight 2 = far leg planted/behind (left)
    for i, side in ((1, "left"), (2, "left"), (3, "right"), (7, "right"), (8, "right"), (9, "left"), (10, "left")):
        darken_leg(cells[i], side)
    save("pojken", cells, size, names)


def triumf():
    """The boy holding the rescued cuddly toy high (shown instead of text – the user: no text in the game)."""
    d = Drawing("pojken-triumf-prov.png")
    s = d.scale_for(0, 132)  # the boy himself stays ≈ 96, the teddy above
    d.peel(s)
    cells, size = sheet("triumf", [d.cut(0, s)], ["triumf"], pad=0)
    save("triumf", cells, size, ["triumf"])


def modig():
    """The boy standing bravely (barnläge's tile for the game – the user, 15 Nov), 150 px tall: an icon is
    shown big, so more detail than in the game."""
    d = Drawing("pojken-modig-prov.png", grid="delar")
    i = max(range(len(d.boxes)), key=lambda j: (d.boxes[j][2] - d.boxes[j][0]) * (d.boxes[j][3] - d.boxes[j][1]))
    x0 = min(b[0] for b in d.boxes); y0 = min(b[1] for b in d.boxes)
    x1 = max(b[2] for b in d.boxes); y1 = max(b[3] for b in d.boxes)
    d.boxes = [(x0, y0, x1, y1)]  # the sparkles belong to the picture
    s = d.scale_for(0, 150)
    d.peel(s)
    cells, size = sheet("modig", [d.cut(0, s)], ["modig"], pad=0, colours=48)
    save("modig", cells, size, ["modig"])


def racerbil():
    car = Drawing("racerbil-prov.png")
    s = car.scale_for(0, 46)
    car.peel(s)
    cells, size = sheet("racerbil", [car.cut(0, s), car.cut(1, s)], ["kor1", "kor2"])
    save("racerbil", cells, size, ["kor1", "kor2"])


def saker():
    d = Drawing("saker-prov.png")
    heights = {0: 26, 1: 26, 2: 96, 3: 120}
    names = ["knapp", "hjarta", "flagga", "bur"]
    for i, n in enumerate(names):
        s = d.scale_for(i, heights[i])
        cells, size = sheet(n, [d.cut(i, s)], [n], pad=0)
        save(n, cells, size, [n])


def mark():
    """3 × 3 tiles, 48 × 48 each: grass l/m/r, earth l/m/r, plank l/m/r."""
    d = Drawing("mark-prov.png", grid=True)
    if len(d.boxes) != 9:
        sys.exit(f"mark: hittade {len(d.boxes)} rutor, inte 9 – rita om eller dela för hand")
    cuts = [d.cut(i, 1, (48, 48)) for i in range(9)]
    names = ["gras_v", "gras", "gras_h", "jord_v", "jord", "jord_h", "planka_v", "planka", "planka_h"]
    cells, size = sheet("mark", cuts, names, pad=0, fixed=(48, 48))
    save("mark", cells, size, names)


def bakgrund(nr="1"):
    """Kakan's jungle background (goblincakes-image, pixel art style, 1280×720): the middle without the dark
    frame and its own ground, on a grid of 480 × 300 (shown ×2 in the game, a background may be coarser than
    the figures), then the picture + its mirror image side by side – repeats without a seam."""
    im = Image.open(SRC / f"djungel-bakgrund-{nr}.png").convert("RGBA").crop((160, 0, 1120, 600))
    w, h = im.size
    get = im.get_flattened_data if hasattr(im, "get_flattened_data") else im.getdata
    px = list(get())
    tw, th = 480, 300
    out = pa.cells(w, h, px, (0, 0, w, h), tw, th, False)
    # Gula prickar i nedre delen (Kakans blommor i markhöjd) såg ut som saker att plocka – "halva bananer"
    # (användaren 15 nov): målas över med närmaste icke-gula granne till vänster
    gul = lambda c: c and c[0] > 170 and c[1] > 140 and c[2] < 120 and c[0] - c[2] > 90
    for y in range(int(th * 0.55), th):
        for x in range(tw):
            if gul(out[y * tw + x]):
                for d in range(1, 12):
                    n = out[y * tw + max(0, x - d)]
                    if not gul(n):
                        out[y * tw + x] = n
                        break
    pal = pa.median_cut(sorted({c[:3] for c in out if c}), 48)
    memo = {}
    # TOPP extra rader överst = de översta raderna spegelvända uppåt: kameran går upp i höga hopp, och
    # bakgrunden ligger lågt (blomraden bakom marken) – annars syntes en ljus rand överst (användaren 15 nov)
    top = 0  # 0: spegelvänt uppåt såg konstigt ut (användaren) – hela bilden ligger högre i stället
    img = Image.new("RGBA", (tw * 2, th + top))
    for y in range(th):
        for x in range(tw):
            c = memo.setdefault(out[y * tw + x][:3], pa.nearest(out[y * tw + x][:3], pal))
            for yy in ((y + top,) + ((top - 1 - y,) if y < top else ())):
                img.putpixel((x, yy), (*c, 255))
                img.putpixel((tw * 2 - 1 - x, yy), (*c, 255))
    th += top
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / "djungel-bakgrund.png")
    (OUT / "djungel-bakgrund.json").write_text(json.dumps({"cell": [tw * 2, th], "frames": ["bakgrund"]}) + "\n")
    print(f"  ✓ djungel-bakgrund: {tw * 2}×{th} (spegelvänd, upprepas utan skarv, {top} rader extra överst)")


def djungel():
    """The jungle: tiles (3 × 4: ground, soil, branch, water), enemies (one sheet each), palm, banana, bush."""
    d = Drawing("djungel-mark-prov.png", grid=True)
    if len(d.boxes) != 12:
        sys.exit(f"djungel-mark: hittade {len(d.boxes)} rutor, inte 12")
    names = ["gras_v", "gras", "gras_h", "jord_v", "jord", "jord_h", "planka_v", "planka", "planka_h",
             "vattenyta", "vatten", "vattenyta2"]
    cells, size = sheet("djungel-mark", [d.cut(i, 1, (48, 48)) for i in range(12)], names, pad=0, fixed=(48, 48))
    save("djungel-mark", cells, size, names)
    f = Drawing("djungel-fiender-prov.png", grid=True, join=40)
    if len(f.boxes) != 8:
        sys.exit(f"djungel-fiender: hittade {len(f.boxes)} figurer, inte 8")
    for n, (i, h) in {"orm": (0, 26), "papegoja": (2, 46), "krokodil": (4, 96), "kokos": (6, 26)}.items():
        k = f.scale_for(i, h)
        cells, size = sheet(n, [f.cut(i, k), f.cut(i + 1, k)], [n + "1", n + "2"])
        save(n, cells, size, [n + "1", n + "2"])
    p = Drawing("djungel-palm-prov.png", grid="delar")
    if len(p.boxes) != 3:
        sys.exit(f"djungel-palm: hittade {len(p.boxes)} figurer, inte 3")
    for n, i, h in (("palm", 0, 240), ("banan", 1, 22), ("buske", 2, 96)):
        k = p.scale_for(i, h)
        cells, size = sheet(n, [p.cut(i, k)], [n], pad=0)
        save(n, cells, size, [n])


def block():
    """The jungle's blocks (X stone, L crate) – each level's json names its own ("block"), so the blocks follow
    the theme (the user, 15 Nov)."""
    d = Drawing("djungel-block-prov.png", grid=True)
    if len(d.boxes) != 2:
        sys.exit(f"djungel-block: hittade {len(d.boxes)} block, inte 2")
    names = ["sten", "lada"]
    cells, size = sheet("djungel-block", [d.cut(i, 1, (48, 48)) for i in range(2)], names, pad=0, fixed=(48, 48))
    save("djungel-block", cells, size, names)


def orangutang():
    d = Drawing("orangutang-prov.png")
    if len(d.boxes) != 4:
        sys.exit(f"orangutang: hittade {len(d.boxes)} figurer, inte 4")
    d.common_ground()
    k = d.scale_for(0, 190)
    d.peel(k)
    names = ["hungrig", "gapar", "tuggar", "sover"]
    cells, size = sheet("orangutang", [d.cut(i, k) for i in range(4)], names)
    save("orangutang", cells, size, names)


PARTS = {"modig": modig, "block": block, "bakgrund": bakgrund, "djungel": djungel, "orangutang": orangutang, "figur": figur, "triumf": triumf, "racerbil": racerbil, "saker": saker, "mark": mark}

if __name__ == "__main__":
    for part in sys.argv[1:] or PARTS:
        try:
            PARTS[part]()
        except FileNotFoundError as e:
            print(f"  – {part}: saknar {Path(e.filename).name}")
