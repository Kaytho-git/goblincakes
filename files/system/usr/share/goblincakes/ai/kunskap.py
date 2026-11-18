#!/usr/bin/python3
"""Kakans kunskapsminne (18 Nov, the user: "hon ger källor, jag kollar, jag godkänner eller nekar").

What she found on the web or in Wikipedia, kept for the next question – one file shared by every chat,
`~/.local/share/goblincakes/ai/kunskap.md`, a `## title` per subject with dated entries and their source:

    ## Bågskytte – OS Paris 2024
    Sparad 2026-11-18 · Källa: [Wikipedia: Bågskytte vid OS 2024](https://sv.wikipedia.org/…)
    Lim Si-hyeon vann damernas individuella …

Nothing is written without the user's Tillåt on the card under her answer (goblin-ai's allowKnowledge); what
the user says Nej to is kept in `kunskap-nekat.json` so she doesn't offer it again. Only the sections that
match a question are read into her prompt (goblinai.with_knowledge / _ask) – the file itself costs nothing.

  kunskap.py list [ord]          the sections (or the ones matching the words, best first)
  kunskap.py visa RUBRIK         one section whole
  kunskap.py ta-bort RUBRIK      remove a section
  kunskap.py nekat               what the user said Nej to
"""
import fcntl
import json
import os
import re
import sys
from contextlib import contextmanager
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from knowledge import stems  # noqa: E402 – the map's word stems: "länkarmar" and "länkarm" meet

DATA = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "goblincakes/ai"
FILE = DATA / "kunskap.md"
DENIED = DATA / "kunskap-nekat.json"  # [{"title", "url", "facts", "date"}]
HEAD = ("# Kakans kunskapsminne\n"
        "Det Kakan har hittat på nätet och i Wikipedia och användaren godkänt (Tillåt) – ändra eller ta bort i "
        "Goblin AI → Inställningar → Kunskap.\n")
ENTRY = re.compile(r"^Sparad (\d{4}-\d{2}-\d{2}) · Källa: \[(.*?)\]\((\S+?)\)\s*$", re.M)

TITLE_MAX = 80
FACTS_MAX = 1500        # characters of facts per card (a few sentences, not a page)
SECTION_MAX = 4000      # characters of one section in her prompt (the newest entries kept)
PROMPT_MAX = 12000      # characters of memory in one question (also at most a quarter of the local AI's memory)
FIND_MIN = 3            # score: one word in the title, or three in the text
DENIED_MAX = 200


def _norm(title):
    return " ".join(str(title).split()).casefold()


def _url(url):
    """The same page however it was written: no #part, no trailing slash, http = https."""
    url = str(url).strip().split("#", 1)[0].rstrip("/")
    return re.sub(r"^http://", "https://", url)


@contextmanager
def _locked():
    DATA.mkdir(parents=True, exist_ok=True)
    with open(DATA / "kunskap.lock", "w") as fd:
        fcntl.flock(fd, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(fd, fcntl.LOCK_UN)


# ── The file ──────────────────────────────────────────────────────────────────

def parse(text):
    """[{title, entries: [{date, source, url, facts}]}] – text before the first entry of a section (written by
    hand) is kept as an entry without date/source."""
    out = []
    for part in re.split(r"^## ", text, flags=re.M)[1:]:
        title, _, body = part.partition("\n")
        entries, marks = [], list(ENTRY.finditer(body))
        lead = body[:marks[0].start()].strip() if marks else body.strip()
        if lead:
            entries.append({"date": "", "source": "", "url": "", "facts": lead})
        for n, m in enumerate(marks):
            end = marks[n + 1].start() if n + 1 < len(marks) else len(body)
            entries.append({"date": m.group(1), "source": m.group(2), "url": m.group(3),
                            "facts": body[m.end():end].strip()})
        out.append({"title": title.strip(), "entries": entries})
    return out


def dump(sections):
    parts = [HEAD]
    for s in sections:
        lines = [f"## {s['title']}"]
        for e in s["entries"]:
            if e.get("url"):
                lines.append(f"Sparad {e['date']} · Källa: [{_link_text(e['source'])}]({e['url']})")
            lines.append(e["facts"].strip())
            lines.append("")
        parts.append("\n".join(lines).rstrip() + "\n")
    return "\n".join(parts)


def _link_text(text):
    return " ".join(str(text).replace("[", "(").replace("]", ")").split())[:100] or "källa"


def load():
    try:
        return parse(FILE.read_text())
    except OSError:
        return []


def _save(sections):
    DATA.mkdir(parents=True, exist_ok=True)
    tmp = FILE.with_suffix(".tmp")
    tmp.write_text(dump(sections))
    tmp.replace(FILE)


def section(title):
    return next((s for s in load() if _norm(s["title"]) == _norm(title)), None)


def add(title, facts, url, source=""):
    """Saves an entry (the user pressed Tillåt): under the section with that title, or a new one.
    Returns "new" or "added"; raises ValueError when something is missing."""
    title, facts = " ".join(str(title).split())[:TITLE_MAX], str(facts).strip()[:FACTS_MAX]
    if not title or not facts or not _url(url).startswith("https://"):
        raise ValueError("rubrik, fakta och källa (en webbadress) behövs")
    if "\n## " in "\n" + facts or ENTRY.search(facts):
        raise ValueError("fakta får inte ha egna rubriker eller Sparad-rader")
    entry = {"date": date.today().isoformat(), "source": source or url, "url": url.strip(), "facts": facts}
    with _locked():
        sections = load()
        found = next((s for s in sections if _norm(s["title"]) == _norm(title)), None)
        if found:
            if any(_url(e["url"]) == _url(url) and e["facts"].strip() == facts for e in found["entries"]):
                return "added"  # the same card twice
            found["entries"].append(entry)
            _save(sections)
            return "added"
        sections.append({"title": title, "entries": [entry]})
        _save(sections)
        return "new"


def remove(title):
    with _locked():
        sections = load()
        left = [s for s in sections if _norm(s["title"]) != _norm(title)]
        if len(left) == len(sections):
            return False
        _save(left)
        return True


def remove_entry(title, url, facts):
    """Takes one saved entry away again (Ångra on the card); the section goes when it is empty."""
    with _locked():
        sections = load()
        for s in sections:
            if _norm(s["title"]) == _norm(title):
                s["entries"] = [e for e in s["entries"]
                                if not (_url(e["url"]) == _url(url) and e["facts"].strip() == str(facts).strip())]
        _save([s for s in sections if s["entries"]])


# ── What the user said Nej to ────────────────────────────────────────────────

def denied():
    try:
        items = json.loads(DENIED.read_text())
        return items if isinstance(items, list) else []
    except (OSError, ValueError):
        return []


def deny(title, url, facts=""):
    with _locked():
        items = [i for i in denied() if not (_norm(i.get("title", "")) == _norm(title) and _url(i.get("url", "")) == _url(url))]
        items.append({"title": " ".join(str(title).split())[:TITLE_MAX], "url": str(url).strip(),
                      "facts": str(facts).strip()[:300], "date": date.today().isoformat()})
        DATA.mkdir(parents=True, exist_ok=True)
        DENIED.write_text(json.dumps(items[-DENIED_MAX:], ensure_ascii=False, indent=1))


def undeny(title, url=""):
    """Out of the Nej list (the tab's ×, or Ångra on the card); no url = every Nej for that title."""
    with _locked():
        items = [i for i in denied() if not (_norm(i.get("title", "")) == _norm(title)
                                             and (not url or _url(i.get("url", "")) == _url(url)))]
        if DENIED.exists():
            DENIED.write_text(json.dumps(items, ensure_ascii=False, indent=1))


def clear_denied():
    with _locked():
        DENIED.unlink(missing_ok=True)


def was_denied(title, url):
    return any(_norm(i.get("title", "")) == _norm(title) and _url(i.get("url", "")) == _url(url) for i in denied())


# ── Finding what fits a question ─────────────────────────────────────────────

def _score(query, s):
    q = stems(query)
    t = stems(s["title"])
    body = stems(" ".join(e["facts"] for e in s["entries"]))
    return sum(3 if w in t else 1 if w in body else 0 for w in q), len(q & t), len(t)


def find(query, limit=PROMPT_MAX):
    """The sections that match the question, best first, within `limit` characters: [(section, strong)].
    strong = the subject itself is in the question (its title's words) – then she reads the memory first
    instead of the forced web search."""
    scored = []
    for s in load():
        score, title_hits, title_words = _score(query, s)
        if score >= FIND_MIN:
            scored.append((score, s, title_hits >= max(1, min(2, title_words))))
    scored.sort(key=lambda x: -x[0])
    out, used = [], 0
    for _, s, strong in scored[:3]:
        size = len(as_text(s))
        if used + size > limit and out:
            break
        out.append((s, strong))
        used += size
    return out


def as_text(s, limit=SECTION_MAX):
    """One section for her prompt – the newest entries kept when it is long."""
    lines = []
    for e in reversed(s["entries"]):
        head = f"(sparad {e['date']}, källa: {e['url']})" if e.get("url") else "(skrivet för hand)"
        piece = f"{head}\n{e['facts'].strip()}"
        if lines and sum(len(x) for x in lines) + len(piece) > limit:
            break
        lines.insert(0, piece[:limit])
    return f"## {s['title']}\n" + "\n\n".join(lines)


def listing():
    """For the window's Kunskap tab: [{title, entries, added, updated, sources}]."""
    out = []
    for s in load():
        dates = [e["date"] for e in s["entries"] if e.get("date")]
        out.append({"title": s["title"], "entries": s["entries"], "added": min(dates) if dates else "",
                    "updated": max(dates) if dates else "",
                    "sources": list(dict.fromkeys(e["url"] for e in s["entries"] if e.get("url")))})
    return out[::-1]  # the newest subject first


# ── The card under her answer ────────────────────────────────────────────────

CARD_LANG = "kunskap"


def card(title, facts, url, source=""):
    """The ```kunskap block Goblin AI puts under her answer (her own copies in the text are removed)."""
    return (f"```{CARD_LANG}\nRubrik: {' '.join(str(title).split())[:TITLE_MAX]}\n"
            f"Källa: {' '.join(str(source).split())[:100]} | {str(url).strip()}\n---\n{str(facts).strip()[:FACTS_MAX]}\n```")


def parse_card(code):
    """The block back into {title, url, source, facts, update} – None when it isn't one."""
    head, sep, facts = code.partition("\n---\n")
    if not sep:
        return None
    title = re.search(r"^Rubrik:\s*(.+)$", head, re.M)
    src = re.search(r"^Källa:\s*(.*?)\s*\|\s*(\S+)\s*$", head, re.M)
    if not title or not src or not facts.strip():
        return None
    return {"title": title.group(1).strip(), "source": src.group(1).strip(), "url": src.group(2).strip(),
            "facts": facts.strip(), "update": section(title.group(1)) is not None}


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__.split("\n\n")[-1])
        return 0
    cmd, rest = argv[0], " ".join(argv[1:])
    if cmd == "list":
        items = [s for s, _ in find(rest, limit=10**9)] if rest else load()
        if not items:
            print("Inget i kunskapsminnet" + (f" om {rest}." if rest else " än."))
        for s in items:
            dates = [e["date"] for e in s["entries"] if e.get("date")]
            print(f"- {s['title']}  ({len(s['entries'])} st, {max(dates) if dates else 'för hand'})")
        return 0
    if cmd == "visa":
        s = section(rest)
        print(as_text(s, limit=10**9) if s else f"Ingen rubrik som heter {rest}.")
        return 0 if s else 1
    if cmd == "ta-bort":
        ok = remove(rest)
        print("Borttaget." if ok else f"Ingen rubrik som heter {rest}.")
        return 0 if ok else 1
    if cmd == "nekat":
        for i in denied():
            print(f"- {i.get('date', '')}  {i.get('title', '')}  ({i.get('url', '')})")
        return 0
    print(f"Okänt: {cmd} (list, visa, ta-bort, nekat)", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
