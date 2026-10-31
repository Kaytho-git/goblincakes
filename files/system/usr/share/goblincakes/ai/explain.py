#!/usr/bin/python3
"""What a command card does, in plain Swedish – shown above the card, the code behind "Visa koden" (31 Oct).

The user found the cards confusing when several came at once: only code. The text is made from the command
itself (no AI), so it always says what will really run. byt_text cards also get before/after lines.
"""
import difflib
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cmdlevel  # noqa: E402

HOME = str(Path.home())
MAX_LINES = 4
# Filters after a pipe: `journalctl … | grep x | tail` says nothing new about what the command does
FILTERS = {"grep", "egrep", "fgrep", "head", "tail", "sort", "uniq", "wc", "cut", "tr", "awk", "less", "more", "column",
           "sed", "xargs", "nl", "tac"}


def place(path):
    """A path as the user knows it: the add-on, the widget, the test folder – or the path with ~."""
    p = path.strip("'\"").rstrip("/")
    p = re.sub(r"^\$\{?HOME\}?", "~", p)
    if p.startswith(HOME):
        p = "~" + p[len(HOME):]
    if re.search(r"/Interface/AddOns$", p):
        return "WoW:s tilläggsmapp (AddOns)"
    m = re.search(r"/Interface/AddOns/([^/]+)(?:/(.+))?$", p)
    if m:
        return f"{m.group(2)} i WoW-tillägget {m.group(1)}" if m.group(2) else f"WoW-tillägget {m.group(1)}"
    m = re.search(r"/plasmoids/([^/]+)(?:/.*?([^/]+))?$", p)
    if m:
        return f"{m.group(2)} i widgeten {m.group(1)}" if m.group(2) else f"widgeten {m.group(1)}"
    m = re.match(r"~/kakan-prov/([^/]+)(?:/(.+))?$", p)
    if m:
        return f"{m.group(2)} i provmappen {m.group(1)}" if m.group(2) else f"provmappen {m.group(1)}"
    return p


def _files(args, with_value=()):
    out, skip = [], False
    for a in args:
        if skip:
            skip = False
        elif a in with_value:
            skip = True
        elif not a.startswith("-") or a == "-":
            out.append(a)
    return out


def _redirect(line):
    """(">" or ">>", target) for the line's first redirection to a file, or None."""
    mask = cmdlevel._masked(line)
    for m in re.finditer(r"(?<![<&\d])(?:\d|&)?(>>?)\|?\s*(\"[^\"]+\"|'[^']+'|[^\s;&|<>()]+)", mask):
        target = line[m.start(2):m.end(2)]
        if target != "/dev/null" and not target.startswith("&"):
            return m.group(1), target
    return None


SYSTEMCTL = {"start": "Startar tjänsten {}", "stop": "Stoppar tjänsten {}", "restart": "Startar om tjänsten {}",
             "reload": "Läser om inställningarna för tjänsten {}", "enable": "Slår på tjänsten {} (startar automatiskt)",
             "disable": "Slår av tjänsten {} (startar inte automatiskt)", "status": "Kollar hur tjänsten {} mår",
             "is-active": "Kollar om tjänsten {} är igång", "daemon-reload": "Läser om tjänsternas inställningar",
             "mask": "Spärrar tjänsten {}", "unmask": "Tar bort spärren för tjänsten {}"}
GOBLIN = {"update": "Uppdaterar systemet", "play": "Startar spelet {}", "screen": "Flyttar ett program till en skärm",
          "wow": "Kör WoW-verktyget (goblin wow {})"}


def _one(line, pipe_pos):
    """One simple command → a sentence, or "" when it adds nothing (a filter after a pipe)."""
    words = cmdlevel._words(re.sub(r"<<-?\s*['\"]?\w+['\"]?", "", line))
    while words and re.match(r"^[A-Za-z_]\w*=", words[0]):
        words = words[1:]
    if not words:
        return ""
    name, args = Path(words[0]).name, words[1:]
    files = _files(args)
    red = _redirect(line)
    fx = [place(f) for f in files]

    if name in FILTERS and pipe_pos > 0:
        return ""
    if name.startswith("python") and files and files[0].endswith("/bytatext.py"):
        return f"Ändrar text i {place(files[1])}" if len(files) > 1 else "Ändrar text i en fil"
    if red and name in ("cat", "echo", "printf", "tee"):
        return (f"Lägger till text sist i {place(red[1])}" if red[0] == ">>" else f"Skriver filen {place(red[1])}")
    if name == "tee" and files:
        return ("Lägger till text sist i " if "-a" in args else "Skriver filen ") + ", ".join(fx)
    if name in ("cp", "rsync") and len(files) >= 2:
        return f"Kopierar {', '.join(fx[:-1])} till {fx[-1]}"
    if name == "mv" and len(files) >= 2:
        src, dst = files[0].rstrip("/"), files[-1].rstrip("/")
        if os.path.dirname(src) == os.path.dirname(dst) and len(files) == 2:
            return f"Döper om {place(src)} till {Path(dst).name}"
        return f"Flyttar {', '.join(fx[:-1])} till {fx[-1]}"
    if name == "mkdir" and files:
        return f"Skapar mappen {', '.join(fx)}"
    if name in ("rm", "rmdir", "unlink") and files:
        return f"Tar bort {', '.join(fx)}"
    if name in ("trash-put", "trash", "kioclient", "kioclient5") or (name == "gio" and args[:1] == ["trash"]):
        rest = [place(f) for f in _files(args[1:] if name in ("gio", "kioclient", "kioclient5") else args)]
        return f"Lägger {', '.join(rest)} i papperskorgen" if rest else "Lägger något i papperskorgen"
    if name == "touch" and files:
        return f"Skapar (eller rör) filen {', '.join(fx)}"
    if name == "sed" and any(a.startswith("-i") or a.startswith("--in-place") for a in args):
        return f"Ändrar text i {fx[-1]}" if len(fx) >= 2 else "Ändrar text i en fil"
    if name == "chmod" and len(files) >= 2:
        return (f"Gör {', '.join(fx[1:])} körbar" if "x" in files[0] and "+" in files[0]
                else f"Ändrar behörigheterna för {', '.join(fx[1:])}")
    if name == "ln" and len(files) >= 2:
        return f"Skapar en länk {fx[-1]} som pekar på {fx[0]}"
    if name == "systemctl" and any(u.startswith("plasma-plasmashell") for u in files[1:]):
        return "Startar om skrivbordet (Plasma)" if files[0] == "restart" else f"Kör systemctl {files[0]} på skrivbordet (Plasma)"
    if name == "systemctl":
        sub = next((a for a in files), "")
        units = files[1:]
        tmpl = SYSTEMCTL.get(sub)
        if tmpl:
            text = tmpl.format(", ".join(units) or "")
            return text + (" (din användares)" if "--user" in args and units else "")
    if name in ("kquitapp6", "kquitapp5") and "plasmashell" in files or name == "plasmashell" and "--replace" in args:
        return "Startar om skrivbordet (Plasma)"
    if name == "kstart" and "plasmashell" in files:
        return "Startar skrivbordet (Plasma)"
    if name == "kpackagetool6":
        target = place(next((a for a in files if a not in ("Plasma/Applet",)), ""))
        if any(a in args for a in ("-i", "--install")):
            return f"Installerar widgeten {target}"
        if any(a in args for a in ("-u", "--upgrade")):
            return f"Uppdaterar widgeten {target}"
        if any(a in args for a in ("-r", "--remove")):
            return f"Tar bort widgeten {target}"
        return "Visar installerade widgetar"
    if name in ("kwriteconfig6", "kwriteconfig5"):
        f = re.search(r"--file\s+(\S+)", line)
        k = re.search(r"--key\s+(\S+)", line)
        return f"Ändrar inställningen {k.group(1) if k else ''} i {f.group(1) if f else 'en inställningsfil'}".replace("  ", " ")
    if name in ("pkill", "killall"):
        return f"Stänger {files[-1]}" if files else "Stänger ett program"
    if name == "flatpak" and files:
        verb = {"install": "Installerar", "uninstall": "Avinstallerar", "remove": "Avinstallerar",
                "update": "Uppdaterar", "run": "Startar"}.get(files[0])
        if verb:
            apps = [f for f in files[1:] if f not in ("flathub", "fedora")]
            return f"{verb} {', '.join(apps) or 'Flatpak-program'}"
    if name == "goblin" and files:
        tmpl = GOBLIN.get(files[0])
        return tmpl.format(" ".join(files[1:])).strip() if tmpl else f"Kör GOBLINCAKES-kommandot goblin {' '.join(files)}"
    if name in ("notify-send",):
        return "Visar en notis"
    if name in ("xdg-open", "kde-open", "kde-open5", "gio") and fx:
        return f"Öppnar {fx[-1]}"
    if name in ("curl", "wget"):
        out = re.search(r"(?:-o|-O|--output)\s+(\S+)", line)
        return f"Laddar ner till {place(out.group(1))}" if out else "Hämtar en sida från nätet"
    if name in ("unzip", "tar", "7z", "bsdtar") and fx:
        return f"Packar upp {fx[0]}" if name != "tar" or re.search(r"\s-?\w*x", line) else f"Packar ihop {fx[0]}"
    if name == "git" and files:
        return {"diff": "Visar vad som är ändrat (git)", "status": "Visar läget i git", "log": "Visar git-historiken",
                "checkout": "Återställer filer med git", "restore": "Återställer filer med git",
                "stash": "Lägger undan ändringarna (git stash)"}.get(files[0], f"Kör git {files[0]}")
    # Only reading
    if name in ("cat", "head", "tail", "less", "bat") and fx:
        return f"Läser {', '.join(fx)}"
    if name == "ls":
        return f"Visar vad som finns i {', '.join(fx)}" if fx else "Visar vad som finns i mappen"
    if name in ("grep", "egrep", "rg") and files:
        where = ", ".join(place(f) for f in files[1:])
        return f"Söker efter \"{files[0]}\"" + (f" i {where}" if where else "")
    if name == "find":
        return f"Letar efter filer i {fx[0]}" if fx else "Letar efter filer"
    if name == "journalctl":
        return "Läser systemloggen"
    if name in ("stat", "file", "du", "df", "wc"):
        return f"Kollar {', '.join(fx)}" if fx else "Kollar diskarna"
    if red:
        return f"Kör {name} och skriver resultatet till {place(red[1])}"
    return f"Kör {name}"


def describe(code, level="change", why=""):
    """The card's plain text: one line, or bullets for several commands."""
    sentences, skip_to = [], None
    for raw in code.splitlines():  # like cmdlevel._lines, but knowing which part comes after a pipe
        if skip_to is not None:
            if raw.strip() == skip_to:
                skip_to = None
            continue
        m = re.search(r"<<-?\s*['\"]?(\w+)['\"]?", raw)
        if m:
            skip_to = m.group(1)
        mask, start, after_pipe = cmdlevel._masked(raw), 0, False
        pieces = []
        for op in re.finditer(r"&&|\|\||;|\|", mask):
            pieces.append((raw[start:op.start()], after_pipe))
            after_pipe, start = op.group(0) == "|", op.end()
        pieces.append((raw[start:], after_pipe))
        for part, piped in pieces:
            part = re.sub(r"^\s*(?:sudo|pkexec)\s+(?:-\S+\s+)*", "", part).strip()
            if not part or part.startswith("#"):
                continue
            s = _one(part, 1 if piped else 0)
            if s and s not in sentences:
                sentences.append(s)
    if not sentences:
        return "Läser information från datorn" if level == "read" else f"Ändrar något ({why})" if why else ""
    if len(sentences) == 1:
        return sentences[0] + "."
    more = len(sentences) - MAX_LINES
    shown = sentences[:MAX_LINES] if more > 1 else sentences
    return "\n".join("• " + s for s in shown) + (f"\n• … och {more} saker till" if more > 1 else "")


def byt_diff(code):
    """A byt_text card → (path, [[kind, line], …]) with kind " " same, "-" goes, "+" comes; None for other cards."""
    m = re.match(r"python3\s+\S*bytatext\.py\s+('(?:[^']|'\\'')*'|\S+)\s*<<'?KAKAN_SLUT'?\n(.*?)\nKAKAN_SLUT", code, re.S)
    if not m:
        return None
    import bytatext  # noqa: PLC0415
    try:
        old, new = bytatext.parse(m.group(2) + "\n" + bytatext.END)
    except bytatext.Miss:
        return None
    path = m.group(1).strip("'").replace("'\\''", "'")
    a, b = old.strip("\n").split("\n"), new.strip("\n").split("\n")
    rows = []
    for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(None, a, b, autojunk=False).get_opcodes():
        if tag == "equal":
            rows += [[" ", x] for x in a[i1:i2]]
        else:
            rows += [["-", x] for x in a[i1:i2]] + [["+", x] for x in b[j1:j2]]
    return path, rows


def byt_text(code):
    """The plain line for a byt_text card: which lines in which file, and how many go/come."""
    found = byt_diff(code)
    if not found:
        return ""
    path, rows = found
    gone, came = sum(r[0] == "-" for r in rows), sum(r[0] == "+" for r in rows)
    at = ""
    try:
        import bytatext  # noqa: PLC0415
        m = re.search(r"\n(.*?)\nKAKAN_SLUT", code, re.S)
        old, _new = bytatext.parse(m.group(1) + "\n" + bytatext.END)
        text = Path(path).expanduser().read_text(errors="replace")
        idx = text.find(old.strip("\n"))
        if idx >= 0:
            first = text.count("\n", 0, idx) + 1
            last = first + old.strip("\n").count("\n")
            at = f" rad {first}" + (f"–{last}" if last > first else "")
    except (OSError, AttributeError, bytatext.Miss):
        pass
    what = (f"tar bort {gone} och lägger till {came} rader" if gone and came
            else f"lägger till {came} rader" if came else f"tar bort {gone} rader")
    return f"Ändrar{at} i {place(path)}: {what}.".replace(" 1 rader", " 1 rad")


def card_info(code, level, why=""):
    """{"explain", "diff", "diffFile"} for a command card (diff only for byt_text)."""
    found = byt_diff(code)
    if found:
        return {"explain": byt_text(code), "diff": found[1], "diffFile": place(found[0])}
    return {"explain": describe(code, level, why)}


if __name__ == "__main__":
    print(describe(sys.stdin.read()))
