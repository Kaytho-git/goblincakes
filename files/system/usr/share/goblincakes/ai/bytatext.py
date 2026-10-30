#!/usr/bin/python3
"""Byt text i en fil: den gamla texten (exakt en gång i filen) mot den nya – Kakans byt_text-verktyg (30 Oct).

gemma4 lagade gear-tillägget med `sed -i '10,12c\\…\\n…'` och fick `\\n` som text i koden, raderna flyttade mellan
kommandona och hon lagade sina egna trasiga rader i sex varv. Här finns inga radnummer och inga backslash: den gamla
texten letas upp som den är (eller rad för rad med samma ord, om bara mellanrummen skiljer) och byts.

Körs från Tillåt-kortet:
    python3 bytatext.py FIL <<'KAKAN_SLUT'
    <<<<<<< GAMMALT
    …den gamla texten…
    =======
    …den nya texten…
    >>>>>>> NYTT
    KAKAN_SLUT
"""
import difflib
import sys
from pathlib import Path

OLD, MID, NEW, END = "<<<<<<< GAMMALT", "=======", ">>>>>>> NYTT", "KAKAN_SLUT"


class Miss(Exception):
    """The old text can't be told apart in the file (not there, or there several times) – the message says why."""


def _indent(line):
    return line[:len(line) - len(line.lstrip())]


def replace(text, old, new):
    """(new file text, first line, last line of the new part – 1-based). Raises Miss."""
    old, new = old.strip("\n"), new.strip("\n")
    if not old.strip():
        raise Miss("Den gamla texten är tom – skriv raderna som ska bytas, exakt som i filen.")
    count = text.count(old)
    if count == 1:
        at = text.index(old)
        first = text.count("\n", 0, at) + 1
        return text[:at] + new + text[at + len(old):], first, first + new.count("\n")
    if count > 1:
        lines = [text.count("\n", 0, i) + 1 for i in _all(text, old)]
        raise Miss(f"Den gamla texten finns {count} gånger (rad {', '.join(map(str, lines))}) – ta med en rad till "
                   "före eller efter så att den bara finns en gång.")
    # Not as it is: line by line with the same words (indentation, spaces at the end)
    have = text.split("\n")
    want = [w.strip() for w in old.split("\n")]
    hits = [i for i in range(len(have) - len(want) + 1)
            if [h.strip() for h in have[i:i + len(want)]] == want]
    if len(hits) > 1:
        raise Miss(f"Den gamla texten finns {len(hits)} gånger (rad {', '.join(str(i + 1) for i in hits)}) – ta med "
                   "en rad till före eller efter så att den bara finns en gång.")
    if not hits:
        raise Miss("Den gamla texten finns inte i filen." + _closest(have, want))
    i = hits[0]
    # The new lines get the file's indentation where the old text's first line had another
    given, real = _indent(old.split("\n")[0]), _indent(have[i])
    out = [real + line[len(given):] if line.startswith(given) and line.strip() else line for line in new.split("\n")]
    if not new:
        out = []
    have[i:i + len(want)] = out
    return "\n".join(have), i + 1, i + max(len(out), 1)


def _all(text, part):
    i = text.find(part)
    while i >= 0:
        yield i
        i = text.find(part, i + 1)


def _closest(have, want):
    """Where the old text's first line most looks like a line in the file – with the lines there, numbered."""
    first = next((w for w in want if w), "")
    scored = sorted(((difflib.SequenceMatcher(None, first, h.strip()).ratio(), n) for n, h in enumerate(have)),
                    reverse=True)
    if not scored or scored[0][0] < 0.5:
        return " Läs filen med las_fil och kopiera raderna exakt."
    n = scored[0][1]
    near = "\n".join(f"{k + 1:4}  {have[k]}" for k in range(max(0, n - 2), min(len(have), n + len(want) + 2)))
    return (" Närmast liknande står på rad " + str(n + 1) + " – så här ser det ut nu (kopiera exakt, utan "
            "radnumren):\n" + near)


def parse(body):
    """(old, new) from the card's text between the markers. Raises Miss."""
    lines = body.strip("\n").split("\n")
    if not lines or lines[0].strip() != OLD or NEW not in [x.strip() for x in lines]:
        raise Miss(f"Texten ska börja med {OLD}, sedan {MID}, och sluta med {NEW}.")
    end = max(i for i, x in enumerate(lines) if x.strip() == NEW)
    mids = [i for i, x in enumerate(lines[:end]) if x.strip() == MID]
    if len(mids) != 1:
        raise Miss(f"Exakt en rad {MID} ska skilja den gamla texten från den nya.")
    return "\n".join(lines[1:mids[0]]), "\n".join(lines[mids[0] + 1:end])


def card(path, old, new, me=None):
    """The ```bash card's command that makes the change (the same check runs again when it is allowed)."""
    me = me or Path(__file__).resolve()
    quoted = "'" + str(path).replace("'", "'\\''") + "'"
    return f"python3 {me} {quoted} <<'{END}'\n{OLD}\n{old.strip(chr(10))}\n{MID}\n{new.strip(chr(10))}\n{NEW}\n{END}"


def check(path, old, new):
    """What is wrong before a card is made ("" = it can be made): the file, the markers in the texts, the match."""
    p = Path(path).expanduser()
    if not p.is_file():
        return f"Filen {path} finns inte (hela sökvägen behövs, t.ex. från las_fil eller hitta_filer)."
    for t in (old, new):
        if any(x.strip() in (OLD, MID, NEW, END) for x in t.split("\n")):
            return f"Texten får inte ha en egen rad med {OLD}, {MID}, {NEW} eller {END}."
    try:
        replace(p.read_text(errors="replace"), old, new)
    except Miss as e:
        return str(e)
    return ""


def main():
    if len(sys.argv) != 2:
        print(f"Så här: python3 {sys.argv[0]} FIL <<'{END}' … {END}", file=sys.stderr)
        return 2
    p = Path(sys.argv[1]).expanduser()
    try:
        old, new = parse(sys.stdin.read())
        text = p.read_text()
        out, first, last = replace(text, old, new)
    except (Miss, OSError) as e:
        print(f"Inget bytt: {e}", file=sys.stderr)
        return 1
    p.write_text(out)
    lines = out.split("\n")
    print(f"Bytt i {p} – rad {first}–{last} ser nu ut så här:")
    for n in range(max(0, first - 2), min(len(lines), last + 1)):
        print(f"{n + 1:4}  {lines[n]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
