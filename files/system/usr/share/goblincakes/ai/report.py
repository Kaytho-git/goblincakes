"""Reports as pictures (17 Oct): an answer in Markdown drawn as a PNG in GOBLINCAKES' look.

The picture models (Z-Image, FLUX) paint – they can't put exact numbers, tables and lines of text
where they belong. A summary "as a picture" is therefore drawn here, with Qt, from the text the AI
wrote: dark background, numbered boxes with the accent colour, bullet lists, tables, a TOTAL row in
the accent colour. Nothing is sent anywhere, it takes well under a second.

The Markdown: "# Title", an optional line under it (the subtitle), "## Section" for each box
(numbers are added; "1." in the heading is dropped), and in the boxes paragraphs, "- " lists (indented =
a level down), "|" tables, "### Subheading" / a line that is only **bold**, ``` code.
Two short sections next to each other share a row, like in the template.
"""
import html
import re
import time
from pathlib import Path

from PySide6.QtCore import QPointF, QRectF, Qt
from PySide6.QtGui import QColor, QFont, QGuiApplication, QImage, QPainter, QPen, QTextDocument, QTextOption

WIDTH = 1400
MARGIN = 44
GAP = 20          # between boxes
PAD = 26          # inside a box
VOID = "#07090D"
BOX = "#0E1420"
LINE = "#1E2A40"
FROST = "#E6ECF5"
BODY = "#D2DAE6"
MUTED = "#8B98AD"
FAINT = "#5C6880"
SANS, HEAD, MONO = "IBM Plex Sans", "Chakra Petch", "IBM Plex Mono"
BODY_PX = 17
MONTHS = ("jan", "feb", "mars", "apr", "maj", "juni", "juli", "aug", "sep", "okt", "nov", "dec")


def accent_colour():
    try:
        import accent  # noqa: PLC0415 – /usr/share/goblincakes/accent.py, when the window found it
        return accent.current()["text"]
    except Exception:  # noqa: BLE001
        return "#2F6FED"


# ── Markdown → sections and blocks ────────────────────────────────────

def clean_heading(text):
    text = re.sub(r"^\s*\d+\s*[.):]\s*", "", text.strip())
    return re.sub(r"^\*\*(.*)\*\*$", r"\1", text).strip().strip("*_ ").strip()


def parse(markdown):
    """{"title", "subtitle", "sections": [{"title", "blocks"}]}; blocks: ("p", text), ("li", level, text),
    ("table", rows, aligns), ("h", text), ("code", text)."""
    doc = {"title": "", "subtitle": [], "sections": []}
    lines = markdown.replace("\r", "").split("\n")
    levels = sorted({len(m.group(1)) for line in lines if (m := re.match(r"^(#{1,4})\s+\S", line))})
    top = levels[0] if levels else 0
    # One "#" title on top: sections are the next level; without it the top level are the sections
    if top and sum(1 for line in lines if re.match(rf"^{'#' * top}\s+\S", line)) == 1 and len(levels) > 1:
        section_level = levels[1]
    else:
        section_level, top = top, 0
    current = None
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        m = re.match(r"^(#{1,6})\s+(.*)$", stripped)
        if m and top and len(m.group(1)) == top and not doc["title"]:
            doc["title"] = clean_heading(m.group(2))
            i += 1
            continue
        if m and section_level and len(m.group(1)) == section_level:
            current = {"title": clean_heading(m.group(2)), "blocks": []}
            doc["sections"].append(current)
            i += 1
            continue
        blocks = current["blocks"] if current else None
        if stripped.startswith("```"):
            code = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith("```"):
                code.append(lines[i])
                i += 1
            i += 1
            target = blocks if blocks is not None else doc.setdefault("intro", [])
            target.append(("code", "\n".join(code)))
            continue
        if stripped.startswith("|"):
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append([c.strip() for c in lines[i].strip().strip("|").split("|")])
                i += 1
            aligns = []
            if len(rows) > 1 and all(re.fullmatch(r":?-{2,}:?", c.replace(" ", "")) for c in rows[1] if c):
                aligns = ["right" if c.endswith(":") and not c.startswith(":") else "center"
                          if c.startswith(":") and c.endswith(":") else "" for c in rows[1]]
                rows = [rows[0]] + rows[2:]
            (blocks if blocks is not None else doc.setdefault("intro", [])).append(("table", rows, aligns))
            continue
        i += 1
        if not stripped or re.fullmatch(r"[-*_]{3,}", stripped):
            continue
        if blocks is None:
            if m:  # a heading of another level before the first section: one more section
                current = {"title": clean_heading(m.group(2)), "blocks": []}
                doc["sections"].append(current)
            elif re.match(r"^([-*•+]|\d+[.)])\s+", stripped):
                current = {"title": "", "blocks": []}
                doc["sections"].append(current)
                i -= 1
            else:
                doc["subtitle"].append(stripped)
            continue
        if m:
            blocks.append(("h", clean_heading(m.group(2))))
            continue
        b = re.match(r"^(\s*)([-*•+]|\d+[.)])\s+(.*)$", line)
        if b:
            blocks.append(("li", min(2, len(b.group(1).replace("\t", "    ")) // 2), b.group(3).strip()))
            continue
        if re.fullmatch(r"\*\*[^*]+\*\*:?", stripped):
            blocks.append(("h", stripped.strip("*: ")))
            continue
        if blocks and blocks[-1][0] == "p":
            blocks[-1] = ("p", blocks[-1][1] + " " + stripped)
        else:
            blocks.append(("p", stripped))
    if not doc["title"] and doc["subtitle"]:
        doc["title"] = doc["subtitle"].pop(0).strip("*# ")
    return doc


def inline(text, accent):
    """Markdown inline → Qt rich text: **bold** white, *italic*, `code`, [link](url) in the accent colour."""
    out = html.escape(text, quote=False)
    out = re.sub(r"`([^`]+)`", lambda m: f'<span style="font-family:\'{MONO}\'; color:{FROST}; '
                 f'background-color:#162036;">&nbsp;{m.group(1)}&nbsp;</span>', out)
    out = re.sub(r"\[([^\]]+)\]\((https?://[^)\s]+)\)", rf'<span style="color:{accent};">\1</span>', out)
    out = re.sub(r"\*\*(.+?)\*\*", rf'<b style="color:{FROST};">\1</b>', out)
    out = re.sub(r"__(.+?)__", rf'<b style="color:{FROST};">\1</b>', out)
    out = re.sub(r"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?!\w)", r"<i>\1</i>", out)
    out = re.sub(r"(?<!\w)_(?!\s)(.+?)(?<!\s)_(?!\w)", r"<i>\1</i>", out)
    return out


def text_doc(rich, width, px=BODY_PX, colour=BODY, family=SANS, weight=QFont.Weight.Normal, align=None, spacing=0.0):
    doc = QTextDocument()
    font = QFont(family)
    font.setPixelSize(px)
    font.setWeight(weight)
    if spacing:
        font.setLetterSpacing(QFont.SpacingType.AbsoluteSpacing, spacing)
    doc.setDefaultFont(font)
    doc.setDocumentMargin(0)
    if align is not None:
        option = QTextOption(align)
        option.setWrapMode(QTextOption.WrapMode.WrapAtWordBoundaryOrAnywhere)
        doc.setDefaultTextOption(option)
    doc.setDefaultStyleSheet(f"body {{ color: {colour}; }}")
    doc.setHtml(f'<body style="color:{colour}; line-height:135%;">{rich}</body>')
    if width is not None:
        doc.setTextWidth(width)
    return doc


def draw_doc(p, doc, x, y):
    p.save()
    p.translate(x, y)
    doc.drawContents(p)
    p.restore()


# ── Layout: every piece is (height, draw(painter, x, y)) ────────────────

NUMBER = re.compile(r"^[~≈<>±+\-−]?\s*\d[\d\s.,:/%x×–\-]*\s*(%|kr\*?|\*|[kKMG]B?|ms|s|min|h|fps|dps|hps|st|M|k)?\.?$")


def is_number(text):
    plain = re.sub(r"[*_`]", "", text).strip()
    return bool(plain) and bool(NUMBER.match(plain))


def layout_table(rows, aligns, width, accent):
    cols = max(len(r) for r in rows)
    rows = [r + [""] * (cols - len(r)) for r in rows]
    header, body = rows[0], rows[1:]
    if not aligns:
        aligns = [""] * cols
    aligns = (aligns + [""] * cols)[:cols]
    for c in range(cols):  # numbers to the right, like in the template
        if not aligns[c] and body and sum(is_number(r[c]) for r in body if r[c]) >= max(1, len([r for r in body if r[c]]) * 0.6):
            aligns[c] = "right"
    cell_pad = 12

    def cell(text, w, head=False, total=False, c=0):
        align = {"right": Qt.AlignmentFlag.AlignRight, "center": Qt.AlignmentFlag.AlignHCenter}.get(aligns[c], Qt.AlignmentFlag.AlignLeft)
        if head:
            return text_doc(html.escape(re.sub(r"[*_`]", "", text).upper()), w, 12, MUTED, SANS, QFont.Weight.Medium, align, 1.2)
        if total:  # the whole row in the accent colour – a **bold** cell would turn it white
            text = re.sub(r"\*\*|__", "", text)
        weight = QFont.Weight.DemiBold if total or (c > 0 and aligns[c] == "right") else QFont.Weight.Normal
        return text_doc(inline(text, accent), w, 16, accent if total else (FROST if c > 0 and aligns[c] == "right" else BODY),
                        SANS, weight, align)

    natural = []
    for c in range(cols):
        widest = max(cell(r[c], None, i == 0, c=c).idealWidth() for i, r in enumerate(rows))
        natural.append(widest + 2 * cell_pad)
    total_w = sum(natural)
    if total_w <= width:
        extra = width - total_w
        grow = max(range(cols), key=lambda c: (aligns[c] != "right", natural[c]))
        natural[grow] += extra
        widths = natural
    else:
        floor = [min(n, 90) for n in natural]
        spare = width - sum(floor)
        over = [n - f for n, f in zip(natural, floor)]
        widths = [f + (o * spare / sum(over) if sum(over) else 0) for f, o in zip(floor, over)]

    is_total = [bool(re.match(r"^\W*(totalt?|summa|sammanlagt|total|snitt|average)\b", re.sub(r"[*_`]", "", r[0]).strip(), re.I))
                for r in body]
    laid = []
    for i, r in enumerate(rows):
        docs = [cell(r[c], widths[c] - 2 * cell_pad, i == 0, i > 0 and is_total[i - 1], c) for c in range(cols)]
        pad_v = 8 if i == 0 else 11
        laid.append((docs, max(d.size().height() for d in docs) + 2 * pad_v, pad_v))
    height = sum(h for _, h, _ in laid)

    def draw(p, x, y):
        for i, (docs, h, pad_v) in enumerate(laid):
            cx = x
            for c, d in enumerate(docs):
                draw_doc(p, d, cx + cell_pad, y + pad_v)
                cx += widths[c]
            y += h
            if i < len(laid) - 1:
                p.setPen(QPen(QColor(LINE), 1))
                p.drawLine(QPointF(x, y - 0.5), QPointF(x + width, y - 0.5))
    return height, draw


def layout_blocks(blocks, width, accent):
    pieces = []
    for block in blocks:
        kind = block[0]
        if kind == "p":
            d = text_doc(inline(block[1], accent), width)
            pieces.append((d.size().height(), lambda p, x, y, d=d: draw_doc(p, d, x, y), 12))
        elif kind == "h":
            d = text_doc(inline(block[1], accent), width, 17, FROST, SANS, QFont.Weight.Bold)
            pieces.append((d.size().height(), lambda p, x, y, d=d: draw_doc(p, d, x, y), 8))
        elif kind == "li":
            level, indent = block[1], 18 + 20 * block[1]
            d = text_doc(inline(block[2], accent), width - indent)
            line = d.documentLayout().blockBoundingRect(d.firstBlock()).height() / max(1, d.firstBlock().layout().lineCount())

            def draw_li(p, x, y, d=d, indent=indent, line=line, level=level):
                size = 7 if level == 0 else 5
                p.fillRect(QRectF(x + indent - 18, y + line / 2 - size / 2, size, size), QColor(accent if level == 0 else MUTED))
                draw_doc(p, d, x + indent, y)
            pieces.append((d.size().height(), draw_li, 8))
        elif kind == "table":
            h, draw = layout_table(block[1], block[2], width, accent)
            pieces.append((h, draw, 14))
        elif kind == "code":
            d = text_doc(html.escape(block[1]).replace("\n", "<br>").replace("  ", "&nbsp; "), width - 28, 14, FROST, MONO)

            def draw_code(p, x, y, d=d):
                p.fillRect(QRectF(x, y, width, d.size().height() + 20), QColor("#0A0F18"))
                p.setPen(QPen(QColor(LINE), 1))
                p.drawRect(QRectF(x + 0.5, y + 0.5, width - 1, d.size().height() + 19))
                draw_doc(p, d, x + 14, y + 10)
            pieces.append((d.size().height() + 20, draw_code, 12))
    height = sum(h for h, _, _ in pieces) + sum(g for _, _, g in pieces[:-1])

    def draw(p, x, y):
        for h, fn, gap in pieces:
            fn(p, x, y)
            y += h + gap
    return height, draw


def layout_section(section, number, width, accent):
    inner = width - 2 * PAD
    head = text_doc(html.escape(section["title"]), inner - (44 if number else 0), 22, FROST, HEAD, QFont.Weight.DemiBold) \
        if section["title"] else None
    head_h = max(32, head.size().height()) if head else 0
    body_h, body = layout_blocks(section["blocks"], inner, accent)
    height = PAD + head_h + (18 if head and section["blocks"] else 0) + body_h + PAD

    def draw(p, x, y, h):
        p.fillRect(QRectF(x, y, width, h), QColor(BOX))
        p.setPen(QPen(QColor(LINE), 1))
        p.drawRect(QRectF(x + 0.5, y + 0.5, width - 1, h - 1))
        top = y + PAD
        if head:
            tx = x + PAD
            if number:
                p.fillRect(QRectF(tx, top, 30, 32), QColor(accent))
                n = text_doc(str(number), 30, 16, FROST, SANS, QFont.Weight.Bold, Qt.AlignmentFlag.AlignHCenter)
                draw_doc(p, n, tx, top + (32 - n.size().height()) / 2 + 1)
                tx += 44
            draw_doc(p, head, tx, top + (head_h - head.size().height()) / 2)
            top += head_h + (18 if section["blocks"] else 0)
        body(p, x + PAD, top)
    return height, draw


def short(section):
    """Fits in half the width: no wide tables, not too much text."""
    size = sum(len(str(b[-1])) if b[0] != "table" else 0 for b in section["blocks"])
    tables = [b for b in section["blocks"] if b[0] == "table"]
    if tables:
        return False if any(max(len(r) for r in t[1]) > 3 for t in tables) else size < 400
    return size < 900 and not any(b[0] == "code" for b in section["blocks"])


def render(markdown, path, footer=""):
    """Draws the report; returns (path, title). Raises ValueError when there is nothing to draw."""
    if QGuiApplication.instance() is None:  # the terminal: draw without a screen
        import os  # noqa: PLC0415
        os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
        render.app = QGuiApplication([])
    accent = accent_colour()
    doc = parse(markdown)
    if not doc["sections"] and not doc.get("intro"):
        raise ValueError("Det finns ingen text att göra en bild av.")
    if doc.get("intro"):
        doc["sections"].insert(0, {"title": "", "blocks": doc["intro"]})
    full = WIDTH - 2 * MARGIN
    half = (full - GAP) / 2
    numbered = sum(1 for s in doc["sections"] if s["title"]) > 1

    # Rows of one or two boxes
    rows, number, i = [], 0, 0
    sections = doc["sections"]
    while i < len(sections):
        pair = i + 1 < len(sections) and short(sections[i]) and short(sections[i + 1]) \
            and bool(sections[i]["title"]) and bool(sections[i + 1]["title"])
        group = sections[i:i + 2] if pair else [sections[i]]
        laid = []
        for s in group:
            if s["title"]:
                number += 1
            laid.append(layout_section(s, number if numbered and s["title"] else 0, half if pair else full, accent))
        rows.append(laid)
        i += len(group)

    title = text_doc(html.escape(doc["title"] or "Sammanställning").upper(), full, 44, FROST, HEAD, QFont.Weight.Bold, spacing=0.5)
    sub = text_doc(inline(" ".join(doc["subtitle"]), accent), full, 17, MUTED) if doc["subtitle"] else None
    t = time.localtime()
    foot = text_doc(html.escape(" · ".join(x for x in (f"Gjord av Goblin AI {t.tm_mday} {MONTHS[t.tm_mon - 1]} {t.tm_year}", footer) if x)),
                    full, 13, FAINT)
    header_h = title.size().height() + (10 + sub.size().height() if sub else 0) + 30
    rows_h = [max(h for h, _ in row) for row in rows]
    height = int(MARGIN + header_h + sum(rows_h) + GAP * (len(rows) - 1) + 36 + foot.size().height() + MARGIN * 0.8)

    scale = 1.5  # sharp when zoomed in, still small as a PNG
    image = QImage(int(WIDTH * scale), int(height * scale), QImage.Format.Format_RGB32)
    image.fill(QColor(VOID))
    p = QPainter(image)
    p.setRenderHints(QPainter.RenderHint.Antialiasing | QPainter.RenderHint.TextAntialiasing)
    p.scale(scale, scale)
    y = MARGIN
    draw_doc(p, title, MARGIN, y)
    y += title.size().height()
    if sub:
        draw_doc(p, sub, MARGIN, y + 10)
        y += 10 + sub.size().height()
    y += 30
    for row, h in zip(rows, rows_h):
        x = MARGIN
        for w_h, draw in row:
            draw(p, x, y, h)
            x += half + GAP
        y += h + GAP
    y += 36 - GAP
    p.setPen(QPen(QColor(LINE), 1))
    p.drawLine(QPointF(MARGIN, y - 18), QPointF(WIDTH - MARGIN, y - 18))
    draw_doc(p, foot, MARGIN, y)
    p.end()
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if not image.save(str(path), "PNG"):
        raise ValueError(f"Bilden gick inte att spara i {path.parent}.")
    return str(path), doc["title"] or "Sammanställning"
