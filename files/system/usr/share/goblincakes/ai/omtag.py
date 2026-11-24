#!/usr/bin/env python3
"""Kakans omtag (25 Nov): one line per time Goblin AI sent her answer back – which check, the question, the model.

The checks in goblinai.py ("Kontrollerar svaret", the nudges) and the klart-kontroll in goblin-ai send an answer back
when it looks wrong. A check that fires on right answers only showed when the user happened to read the steps (24 Nov:
6 of 6 status questions). The log shows it by itself: `python3 omtag.py [dagar]` sums up the last days, per check,
with an example question – tools/hej.sh shows the count.

~/.local/share/goblincakes/ai/omtag.jsonl, only on this computer, at most KEEP lines.
"""
import json
import sys
import time
from collections import Counter
from pathlib import Path

LOG = Path.home() / ".local/share/goblincakes/ai/omtag.jsonl"
KEEP = 2000


def add(check, question="", model=""):
    """One round back. Never raises – the log must not stop an answer."""
    try:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        lines = LOG.read_text(encoding="utf-8").splitlines() if LOG.exists() else []
        lines.append(json.dumps({"t": time.strftime("%Y-%m-%d %H:%M"), "check": " ".join(str(check).split())[:120],
                                 "q": " ".join(str(question).split())[:160], "model": str(model)[:60]},
                                ensure_ascii=False))
        LOG.write_text("\n".join(lines[-KEEP:]) + "\n", encoding="utf-8")
    except OSError:
        pass


def rows(days=7):
    since = time.strftime("%Y-%m-%d %H:%M", time.localtime(time.time() - days * 86400))
    out = []
    try:
        for line in LOG.read_text(encoding="utf-8").splitlines():
            try:
                r = json.loads(line)
            except ValueError:
                continue
            if r.get("t", "") >= since:
                out.append(r)
    except OSError:
        pass
    return out


def name(check):
    """The check without what differs each time ("stod inte i det lästa: 40" → "stod inte i det lästa")."""
    return check.strip() if check.startswith("klart-kontrollen") else check.split(":")[0].strip()


def summary(days=7):
    rs = rows(days)
    if not rs:
        return f"Inga omtag de senaste {days} dagarna."
    count = Counter(name(r["check"]) for r in rs)
    models = Counter(r.get("model", "") for r in rs if r.get("model"))
    lines = [f"{len(rs)} omtag de senaste {days} dagarna" + (" (" + ", ".join(f"{m} {n}" for m, n in models.most_common(3))
                                                            + ")" if models else "") + ":"]
    for check, n in count.most_common():
        last = next(r for r in reversed(rs) if name(r["check"]) == check)
        lines.append(f"- {n} × {check} – senast {last['t']}: \"{last['q'][:90]}\"")
    return "\n".join(lines)


def short(days=7):
    """One line for hej.sh: the count and the most common check."""
    rs = rows(days)
    if not rs:
        return f"inga omtag senaste {days} dagarna"
    check, n = Counter(name(r["check"]) for r in rs).most_common(1)[0]
    return f"{len(rs)} omtag senaste {days} dagarna (mest: {check}, {n} st) – python3 omtag.py visar alla"


if __name__ == "__main__":
    if sys.argv[1:2] == ["kort"]:
        print(short())
    else:
        print(summary(int(sys.argv[1]) if sys.argv[1:] and sys.argv[1].isdigit() else 7))
