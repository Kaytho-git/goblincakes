"""Kakan's watch on anti-cheat for Linux (5 Nov, the user: "jag vill kunna spela CS på FACEIT, CoD och Battlefield
och inte känna mig tvingad att använda Windows"): once a day the list on areweanticheatyet.com (its games.json on
GitHub, kept up to date by the community) is read, and a change for the watched anti-cheats is a notice –
a new status (Denied → Planned/Running/Supported), a new line in a game's history, or a new game with one of them.

The watch is a `bevaka antifusk` item in reminders.py (kind "antifusk", never fired: it stays until removed with
`påminnelser bort antifusk`). The item keeps what was seen last ("known": name → status, number of history lines),
so the first look only remembers. `python3 anticheatwatch.py` = the watched games now (reads only).
Only the standard library."""

import json
import re
import sys
import urllib.request

SOURCE = "https://raw.githubusercontent.com/AreWeAntiCheatYet/AreWeAntiCheatYet/HEAD/games.json"
PAGE = "https://areweanticheatyet.com"
DAY = 24 * 3600
# Anti-cheat as the list names it → what the user plays it for
WATCHED = {
    "faceit": "FACEIT (CS2)",
    "ricochet": "Ricochet (Call of Duty)",
    "ea anticheat": "EA Javelin (Battlefield)",
    "javelin": "EA Javelin (Battlefield)",
    "ea javelin": "EA Javelin (Battlefield)",
}
DEFAULT_ARG = "FACEIT, Ricochet och EA Javelin"
# The games the user named, first in the list
MAIN = re.compile(r"Counter-Strike 2 \(FACEIT\)|Battlefield (6|REDSEC)|Call of Duty", re.I)
STATUS = {
    "Supported": "fungerar (stöds officiellt)",
    "Running": "startar på Linux (inte officiellt)",
    "Planned": "Linux-stöd planerat",
    "Broken": "fungerar inte",
    "Denied": "nekat av tillverkaren",
}


def fetch():
    req = urllib.request.Request(SOURCE, headers={"User-Agent": "GOBLINCAKES Goblin AI"})
    with urllib.request.urlopen(req, timeout=30) as r:  # noqa: S310 – a fixed https address
        return json.loads(r.read(5_000_000))


def watched(games):
    """name → {"s": status, "u": history lines, "last": newest history line, "ac": the watched anti-cheat's name}."""
    out = {}
    for g in games:
        acs = [a for a in g.get("anticheats") or [] if a.casefold() in WATCHED]
        if not acs or not g.get("name"):
            continue
        updates = g.get("updates") or []
        last = updates[-1] if updates else {}
        out[g["name"]] = {"s": g.get("status", ""), "u": len(updates),
                          "last": f"{last.get('name', '')} ({last.get('date', '')})".strip() if last else "",
                          "ac": WATCHED[acs[0].casefold()]}
    return out


def status_text(status):
    return STATUS.get(status, status or "okänt")


def changes(known, now):
    """What is new since `known`, as lines for the notice – the user's games first."""
    lines = []
    for name, g in now.items():
        old = known.get(name)
        if old is None:
            lines.append(f"Nytt på listan: {name} – {status_text(g['s'])} [{g['ac']}]")
        elif old.get("s") != g["s"]:
            lines.append(f"{name}: {status_text(old.get('s'))} → {status_text(g['s'])}")
        elif g["u"] > old.get("u", 0) and g["last"]:
            lines.append(f"{name}: {g['last']}")
    return sorted(lines, key=lambda line: not MAIN.search(line))


def summary(now):
    """The watched games right now – the user's own first."""
    rows = sorted(now.items(), key=lambda kv: (not MAIN.search(kv[0]), kv[1]["ac"], kv[0]))
    return [f"{name}: {status_text(g['s'])} [{g['ac']}]" for name, g in rows]


if __name__ == "__main__":
    try:
        games = watched(fetch())
    except Exception as e:  # noqa: BLE001 – offline: said as it is
        print(f"Kommer inte åt listan ({SOURCE}): {e}", file=sys.stderr)
        sys.exit(1)
    print("\n".join(summary(games)))
    print(f"\nKälla: {PAGE}")
