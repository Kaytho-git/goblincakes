"""Goblin AI's ```goblincakes tool (point 11 of Kakan's plan, 25 Oct): how GOBLINCAKES' parts hang together, so the
AI troubleshoots from facts instead of guessing (the first test: the mouse battery was gone from the top bar and
it looked for a service that never existed, never reading the widget). The user's choice: the map shipped with
the image (karta.md, written for the AI) – and on a computer with the repo also its notes (docs/anteckningar.md),
CLAUDE.md, plus the news. Only reads."""

import os
import re
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
KARTA = HERE / "karta.md"
NEWS = HERE.parent / "nyheter.txt"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "goblincakes/repo-path"
GENERAL = "Allmänt"  # the map's troubleshooting part: always along
REPO_CHUNK = 1800  # characters per piece of the notes (their lines are long)
LIMIT = 10000

STOP = {"och", "att", "det", "som", "för", "med", "har", "inte", "den", "jag", "min", "mitt", "mina", "kan", "du",
        "är", "på", "en", "ett", "av", "till", "om", "vad", "hur", "var", "när", "nu", "längre", "syns", "funkar",
        "fungerar", "kolla", "fixa", "varför", "ska", "the", "goblincakes", "gör", "vill", "får", "efter", "från"}


def stems(text):
    """The words of a text as short stems ("toppfältet" and "toppfält" meet), without the small words."""
    out = set()
    for w in re.findall(r"[a-zåäöé0-9+#'.-]{3,}", text.lower()):
        w = w.strip(".-'")
        if len(w) >= 3 and w not in STOP:
            out.add(w[:6])
    return out


def sections(text):
    """The map's parts: [(title, keywords, body)]."""
    out = []
    for part in re.split(r"^## ", text, flags=re.M)[1:]:
        title, _, body = part.partition("\n")
        m = re.search(r"^Ord:\s*(.*)$", body, re.M)
        out.append((title.strip(), m.group(1) if m else "", body.strip()))
    return out


CHECK_TIMEOUT = 10
OWN_PATH = re.compile(r"(?:/usr/libexec/goblincakes-[\w.-]+|/usr/bin/goblin[\w.-]*|/usr/share/goblincakes/[\w./-]+)")


def run_checks(body):
    """The part's `Kontroll:` commands run now (only ones cmdlevel calls reading), with their output – and every
    GOBLINCAKES path in it that doesn't exist marked (25 Oct: gemma4 skipped "compare the path in the widget's
    code" and suggested a restart; a check that is always run doesn't get skipped)."""
    import cmdlevel  # noqa: PLC0415 – next to this file
    out = []
    for cmd in re.findall(r"^Kontroll:\s*`(.+)`\s*$", body, re.M):
        if cmdlevel.level(cmd)[0] != "read":
            continue
        try:
            proc = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True, timeout=CHECK_TIMEOUT)
            text = (proc.stdout + proc.stderr).strip() or "(inget)"
        except (OSError, subprocess.TimeoutExpired) as e:
            text = f"(gick inte: {e})"
        text = text.replace(str(Path.home()), "~")
        missing = sorted({p.rstrip(".,:;\"'") for p in OWN_PATH.findall(text)
                          if not Path(p.rstrip(".,:;\"'")).exists()})
        if len(text) > 1500:
            text = text[:1500] + "…"
        out.append(f"$ {cmd}\n{text}" + "".join(f"\nFINNS INTE: {m}" for m in missing))
    return out


def score(query, title, keywords, body):
    q = stems(query)
    t, k, b = stems(title), stems(keywords), stems(body)
    return sum(3 if s in t or s in k else 1 if s in b else 0 for s in q)


def find_repo():
    """A clone of the GOBLINCAKES repo on this computer (its docs/anteckningar.md), or None. Found once, remembered."""
    def ok(p):
        return p and (p / "docs/anteckningar.md").is_file() and (p / "recipes").is_dir()
    env = os.environ.get("GOBLINCAKES_REPO")
    if env and ok(Path(env)):
        return Path(env)
    try:
        cached = Path(CACHE.read_text().strip())
        if ok(cached):
            return cached
    except OSError:
        pass
    user = os.environ.get("USER", "")
    roots = [Path.home()] + sorted(Path(f"/run/media/{user}").glob("*"))
    for root in roots:
        for depth in range(1, 5):
            for p in root.glob("/".join(["*"] * (depth - 1) + ["goblincakes"])):
                if ok(p):
                    try:
                        CACHE.parent.mkdir(parents=True, exist_ok=True)
                        CACHE.write_text(str(p))
                    except OSError:
                        pass
                    return p
    return None


def repo_pieces(repo, query, count=3):
    """The best-matching lines of the repo's notes and CLAUDE.md, each cut around where the words are."""
    q = stems(query)
    if not q:
        return []
    found = []
    for name in ("docs/anteckningar.md", "CLAUDE.md"):
        try:
            lines = (repo / name).read_text().splitlines()
        except OSError:
            continue
        heading = ""
        for line in lines:
            if line.startswith("#"):
                heading = line.lstrip("# ").strip()
                continue
            if len(line) < 40:
                continue
            s = stems(line)
            points = len(q & s)
            if points >= max(2, min(len(q), 3) - 1):
                found.append((points, name, heading, line))
    found.sort(key=lambda f: -f[0])
    out = []
    for _, name, heading, line in found[:count]:
        if len(line) > REPO_CHUNK:  # the notes' lines are whole stories: the part around the first word
            low = line.lower()
            at = min((low.find(w) for w in q if low.find(w) >= 0), default=0)
            start = max(0, at - REPO_CHUNK // 3)
            line = ("…" if start else "") + line[start:start + REPO_CHUNK] + "…"
        out.append(f"[{name}{' – ' + heading if heading else ''}]\n{line.strip()}")
    return out


def news_lines(query, count=4):
    q = stems(query)
    try:
        lines = NEWS.read_text().splitlines()
    except OSError:
        return []
    hits = [(len(q & stems(line)), line) for line in lines if line.strip()]
    hits = [h for h in hits if h[0] >= 2]
    hits.sort(key=lambda h: -h[0])
    return [line for _, line in hits[:count]]


def lookup(query):
    """The tool's answer: the map's best parts (+ the general troubleshooting part), the repo's notes, the news."""
    query = (query or "").strip()
    try:
        parts = sections(KARTA.read_text())
    except OSError:
        return "Kartan över GOBLINCAKES finns inte här (" + str(KARTA) + ")."
    ranked = sorted(((score(query, *p), p) for p in parts), key=lambda r: -r[0])
    best = [p for s, p in ranked[:2] if s > 0]
    general = next((p for p in parts if p[0].startswith(GENERAL)), None)
    if general and general not in best:
        best.append(general)
    out = ["Kartan över GOBLINCAKES (fakta om systemet – följ den):"]
    if not any(s > 0 for s, _ in ranked):
        out.append("Ingen del passade orden \"" + query + "\". Delarna: " + ", ".join(p[0] for p in parts) + ".")
    for n, (title, _, body) in enumerate(best):
        out.append(f"## {title}\n" + re.sub(r"^Kontroll:.*\n?", "", body, flags=re.M).strip())
        checks = run_checks(body) if n == 0 and any(s > 0 for s, _ in ranked) else []  # the best part only
        if checks:
            out.append(f"Kontrollerat nu ({title}):\n" + "\n\n".join(checks))
    repo = find_repo()
    if repo:
        pieces = repo_pieces(repo, query)
        if pieces:
            out.append(f"Ur projektets egna anteckningar i {repo} (detaljer om hur det byggdes – koden kan ha ändrats "
                       "sedan, kontrollera mot filerna):\n\n" + "\n\n".join(pieces))
    news = news_lines(query)
    if news:
        out.append("Ur nyheterna (vad som ändrats och när):\n" + "\n".join(news))
    text = "\n\n".join(out)
    return text if len(text) <= LIMIT else text[:LIMIT] + "\n…(avkortat)"


if __name__ == "__main__":
    import sys
    print(lookup(" ".join(sys.argv[1:])))
