"""Goblin AI's ```sport tool (20 Oct, the user's wish – "Google shows exactly that on its first page"):
a team's standing, latest game and next game from ESPN's open data (no key; Google's own box cannot be
read by a program). Exact numbers, so even a small local model answers right – it got the place in the
division wrong when it had to read a table itself."""

import json
import re
import time
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path
import os

API = "https://site.api.espn.com/apis"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "goblincakes" / "sport-teams.json"
# (sport, league, name) – the order decides when a name is in two leagues (Rangers: NHL before MLB)
LEAGUES = [
    ("hockey", "nhl", "NHL"), ("basketball", "nba", "NBA"), ("football", "nfl", "NFL"),
    ("baseball", "mlb", "MLB"), ("soccer", "eng.1", "Premier League"), ("soccer", "esp.1", "La Liga"),
    ("soccer", "ger.1", "Bundesliga"), ("soccer", "ita.1", "Serie A"), ("soccer", "fra.1", "Ligue 1"),
    ("soccer", "swe.1", "Allsvenskan"), ("soccer", "uefa.champions", "Champions League"),
    ("basketball", "wnba", "WNBA"), ("soccer", "usa.1", "MLS"),
]
WORDS_MIN = 5  # a nickname alone ("Ducks", "Kings") must be at least this long to count


def get(path):
    req = urllib.request.Request(API + path, headers={"User-Agent": "goblincakes-ai"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.loads(r.read())


def teams():
    """All teams of the leagues: [{id, name, short, abbr, location, sport, league, leagueName}], a day's cache."""
    try:
        data = json.loads(CACHE.read_text())
        if time.time() - data["time"] < 86400 and data["teams"]:
            return data["teams"]
    except (OSError, ValueError, KeyError):
        pass
    found = []
    for sport, league, name in LEAGUES:
        try:
            d = get(f"/site/v2/sports/{sport}/{league}/teams")
        except (urllib.error.URLError, TimeoutError, OSError, ValueError):
            continue
        for group in d.get("sports", [{}])[0].get("leagues", [{}])[0].get("teams", []):
            t = group.get("team", {})
            found.append({"id": t.get("id"), "name": t.get("displayName", ""), "short": t.get("shortDisplayName", ""),
                          "nick": t.get("name", ""), "abbr": t.get("abbreviation", ""), "location": t.get("location", ""),
                          "sport": sport, "league": league, "leagueName": name})
    if found:
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        CACHE.write_text(json.dumps({"time": time.time(), "teams": found}))
    return found


def find_teams(text, limit=3):
    """The teams a text names: the full name ("Anaheim Ducks") or a long enough nickname ("Ducks")."""
    low = text.casefold()
    hits = []
    for t in teams():
        full = t["name"].casefold()
        names = [full] + [n.casefold() for n in (t["nick"], t["short"]) if len(n) >= WORDS_MIN]
        if any(re.search(r"(?<!\w)" + re.escape(n) + r"(?!\w)", low) for n in names if n):
            hits.append((0 if full in low else 1, t))
    hits.sort(key=lambda h: h[0])
    out = []
    for _, t in hits:  # the same name in two leagues: the first league only, unless the full name says otherwise
        if not any(o["name"] == t["name"] for o in out):
            out.append(t)
    return out[:limit]


DAYS = ["mån", "tis", "ons", "tors", "fre", "lör", "sön"]
MONTHS = ["jan", "feb", "mars", "april", "maj", "juni", "juli", "aug", "sep", "okt", "nov", "dec"]


def local_time(iso):
    try:
        d = datetime.fromisoformat(iso.replace("Z", "+00:00")).astimezone()
    except ValueError:
        return iso
    return f"{DAYS[d.weekday()]} {d.day} {MONTHS[d.month - 1]} kl. {d:%H:%M}"


def stat(row, key):
    return next((s.get("displayValue") for s in row.get("stats", []) if s.get("name") == key), None)


def num(row, key):
    return next((s.get("value") or 0 for s in row.get("stats", []) if s.get("name") == key), 0)


def standing(t):
    """(group name, place, size, lines) for the team's division/group, sorted by points."""
    try:
        d = get(f"/v2/sports/{t['sport']}/{t['league']}/standings?level=3")
    except (urllib.error.URLError, TimeoutError, OSError, ValueError):
        return None
    found = []

    def walk(n):
        rows = n.get("standings", {}).get("entries", [])
        if any(r.get("team", {}).get("id") == t["id"] for r in rows):
            found.append((n.get("name", ""), rows))
        for ch in n.get("children", []):
            walk(ch)
    walk(d)
    if not found:
        return None
    name, rows = min(found, key=lambda f: len(f[1]))  # the smallest group = the division
    rows = sorted(rows, key=lambda r: (-num(r, "points"), num(r, "gamesPlayed"), -num(r, "wins")))
    lines = []
    place = 0
    for i, r in enumerate(rows, 1):
        tm = r.get("team", {})
        if tm.get("id") == t["id"]:
            place = i
        record = "-".join(x for x in (stat(r, "wins"), stat(r, "ties") if t["sport"] == "soccer" else None,
                                      stat(r, "losses"), stat(r, "otLosses") if t["sport"] == "hockey" else None) if x)
        lines.append(f"{i}. {tm.get('displayName', tm.get('abbreviation', '?'))} – {stat(r, 'gamesPlayed') or '?'} matcher, "
                     f"{record}" + (f", {stat(r, 'points')} poäng" if stat(r, "points") else ""))
    return name, place, len(rows), lines


def games(t):
    """(latest finished game, next game) as text."""
    path = f"/site/v2/sports/{t['sport']}/{t['league']}/teams/{t['id']}/schedule"
    events = {}
    # Football: the played games newest first, the coming ones only with fixture=true
    for extra in ([""] + (["?fixture=true"] if t["sport"] == "soccer" else [])):
        try:
            for e in get(path + extra).get("events", []):
                events[e.get("id")] = e
        except (urllib.error.URLError, TimeoutError, OSError, ValueError):
            pass
    events = sorted(events.values(), key=lambda e: e.get("date", ""))
    if not events:
        return None, None
    done = [e for e in events if e["competitions"][0]["status"]["type"].get("completed")]
    coming = [e for e in events if not e["competitions"][0]["status"]["type"].get("completed")]

    def describe(e, finished):
        c = e["competitions"][0]
        us = next((x for x in c["competitors"] if x["team"]["id"] == t["id"]), None)
        them = next((x for x in c["competitors"] if x["team"]["id"] != t["id"]), None)
        if not us or not them:
            return e.get("name", "")
        where = "hemma" if us.get("homeAway") == "home" else "borta"
        text = f"{local_time(e['date'])} {where} mot {them['team'].get('displayName')}"
        if finished:
            score = lambda x: (x.get("score") or {}).get("displayValue", "?")  # noqa: E731
            result = "vinst" if us.get("winner") else "förlust" if them.get("winner") else "oavgjort"
            detail = c["status"]["type"].get("shortDetail", "")
            text += f": {score(us)}–{score(them)} ({result}{', ' + detail if detail and detail not in ('Final', 'FT') else ''})"
        return text
    return (describe(done[-1], True) if done else None), (describe(coming[0], False) if coming else None)


def sport_info(query):
    """The tool: one or more teams named in the query → their facts as text."""
    try:
        found = find_teams(query)
    except (urllib.error.URLError, OSError, ValueError):
        found = []
    if not found:
        return ("Hittade inget lag med det namnet hos ESPN (NHL, NBA, NFL, MLB, WNBA, MLS och de stora "
                "fotbollsligorna inklusive Allsvenskan). Sök på nätet i stället.")
    parts = []
    for t in found:
        lines = [f"{t['name']} ({t['leagueName']}) – från ESPN, hämtat {time.strftime('%Y-%m-%d %H:%M')} (svensk tid):"]
        st = standing(t)
        if st:
            name, place, size, table = st
            lines.append(f"Plats: {place}:a av {size} i {name}")
            lines.append("Tabellen:\n" + "\n".join("  " + x for x in table))
        last, nxt = games(t)
        lines.append(f"Senaste match: {last or 'ingen spelad än'}")
        lines.append(f"Nästa match: {nxt or 'ingen inlagd'}")
        parts.append("\n".join(lines))
    return "\n\n".join(parts)


if __name__ == "__main__":
    import sys
    print(sport_info(" ".join(sys.argv[1:]) or "Anaheim Ducks"))
