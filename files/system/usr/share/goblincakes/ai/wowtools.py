"""WoW tools for Goblin AI (16 Oct): the AI asks for them with a code block, like a web search.

- wow_errors(query): the errors BugSack/BugGrabber saved (!BugGrabber.lua in WTF – only read,
  never changed: WoW's files are not touched), with the add-on's version from its .toc.
- wcl_pull(query): one pull from Warcraft Logs – result, boss health and phase, deaths with what
  killed them, the damage the raid took, everyone's DPS/HPS and the other pulls on the boss – or,
  with "alla" in the query, every boss in the report (the kill, else the last pull; 17 Oct) –
  through GoblinRecorder's Warcraft Logs client (recorder.py, ~/.config/goblincakes/wcl.json).

Both return plain text for the AI (Swedish headings, the game's own English names).
"""
import json
import os
import re
import sys
import time
from datetime import datetime
from pathlib import Path

HOME = Path.home()
WOW = HOME / "Games/WoW"  # goblincakes-wow-links: <Version>/AddOns → the real Interface/AddOns
RECORDER = Path(os.environ.get("GOBLINCAKES_RECORDER_SHARE", "/usr/share/goblincakes/recorder"))


class ToolError(Exception):
    pass


# ── BugSack ───────────────────────────────────────────────────────────────────────

def lua_table(text):
    """A small reader for SavedVariables: tables, strings, numbers, booleans, nil."""
    pos = 0

    def skip():
        nonlocal pos
        while pos < len(text):
            if text[pos].isspace():
                pos += 1
            elif text.startswith("--", pos):
                end = text.find("\n", pos)
                pos = len(text) if end < 0 else end
            else:
                break

    def string():
        nonlocal pos
        quote = text[pos]
        pos += 1
        out = []
        while pos < len(text) and text[pos] != quote:
            c = text[pos]
            if c == "\\" and pos + 1 < len(text):
                pos += 1
                c = {"n": "\n", "t": "\t", "r": "\r"}.get(text[pos], text[pos])
            out.append(c)
            pos += 1
        pos += 1
        return "".join(out)

    def value():
        nonlocal pos
        skip()
        c = text[pos]
        if c == "{":
            return table()
        if c in "\"'":
            return string()
        m = re.compile(r"-?[\d.]+(?:e[-+]?\d+)?|true|false|nil").match(text, pos)
        if not m:
            raise ValueError(f"okänt tecken vid {pos}")
        pos = m.end()
        word = m.group()
        return {"true": True, "false": False, "nil": None}.get(word, None) if word in ("true", "false", "nil") \
            else float(word) if "." in word or "e" in word else int(word)

    def table():
        nonlocal pos
        pos += 1
        items, keyed = [], {}
        while True:
            skip()
            if text[pos] == "}":
                pos += 1
                break
            if text[pos] == "[":
                pos += 1
                key = value()
                skip()
                pos += 1  # ]
                skip()
                pos += 1  # =
                keyed[key] = value()
            else:
                m = re.compile(r"[A-Za-z_]\w*\s*=").match(text, pos)
                if m:
                    pos = m.end()
                    keyed[m.group()[:-1].strip()] = value()
                else:
                    items.append(value())
            skip()
            if pos < len(text) and text[pos] in ",;":
                pos += 1
        return keyed if keyed and not items else items or keyed

    out = {}
    for m in re.finditer(r"^(\w+)\s*=\s*", text, re.M):
        pos = m.end()
        try:
            out[m.group(1)] = value()
        except (ValueError, IndexError):
            continue
    return out


def wow_versions():
    """{Retail: <the version's folder (_retail_)>, …} from goblincakes-wow-links' links."""
    out = {}
    for addons in sorted(WOW.glob("*/AddOns")):
        try:
            out[addons.parent.name] = addons.resolve().parents[1]
        except (OSError, IndexError):
            continue
    return out


def addon_version(game, addon):
    toc = next(iter(sorted((game / "Interface/AddOns" / addon).glob("*.toc"))), None)
    if not toc:
        return ""
    try:
        m = re.search(r"^##\s*Version:\s*(.+)$", toc.read_text(errors="replace"), re.M)
    except OSError:
        return ""
    return m.group(1).strip() if m else ""


def wow_errors(query=""):
    """The latest Lua errors (newest session first), at most 8 different ones; query = an add-on
    or a word in the error to look for ("" / "senaste" = all)."""
    words = [w for w in re.findall(r"\w+", query.lower()) if w not in ("senaste", "alla", "fel", "wow")]
    found = []
    for version, game in wow_versions().items():
        for path in sorted(game.glob("WTF/Account/*/SavedVariables/!BugGrabber.lua")):
            try:
                db = lua_table(path.read_text(errors="replace")).get("BugGrabberDB") or {}
            except OSError:
                continue
            for e in db.get("errors") or []:
                if isinstance(e, dict) and e.get("message"):
                    found.append((version, game, e, db.get("session")))
    if not found:
        raise ToolError("hittade inga sparade fel – är BugSack (BugGrabber) installerat, och har WoW stängts "
                        "eller /reload gjorts sedan felet? (felen skrivs till disken då)")
    found.sort(key=lambda f: f[2].get("time") or 0, reverse=True)
    lines, seen = [], set()
    for version, game, e, session in found:
        message = str(e["message"])
        text = (message + " " + str(e.get("stack", ""))).lower()
        if words and not all(w in text for w in words):
            continue
        if message in seen:
            continue
        seen.add(message)
        # The culprit: the first add-on in the message/stack that isn't Blizzard's own (their files
        # are where an add-on's mistake is noticed, seldom the cause)
        names = re.findall(r"Interface/AddOns/([^/\]]+)/", message + "\n" + str(e.get("stack", "")))
        own = [n for n in names if not n.startswith("Blizzard_")]
        m = own or names
        addon = m[0] if m else "okänt tillägg"
        when = datetime.fromtimestamp(e["time"]).strftime("%Y-%m-%d %H:%M") if e.get("time") else "?"
        current = " (senaste spelpasset)" if e.get("session") == session else ""
        ver = addon_version(game, addon) if m and not addon.startswith("Blizzard_") else ""
        stack = "\n".join(str(e.get("stack", "")).splitlines()[:6])
        lines.append(f"### {addon}{' ' + ver if ver else ''} – {version}, {when}{current}, {e.get('counter', 1)} gånger\n"
                     f"{message}\n" + (f"Stack:\n{stack}" if stack else ""))
        if len(lines) >= 8:
            break
    if not lines:
        raise ToolError(f"inga sparade fel som innehåller \"{query}\"")
    return "Fel som BugSack har sparat (nyast först):\n\n" + "\n\n".join(lines)


# ── Warcraft Logs ─────────────────────────────────────────────────────────────────

DIFFICULTY = {1: "LFR", 3: "Normal", 4: "Heroic", 5: "Mythic", 10: "Mythic+"}


def recorder():
    sys.path.insert(0, str(RECORDER))
    try:
        import recorder as r  # noqa: PLC0415 – only when a pull is asked for
    except ImportError:
        raise ToolError("GoblinRecorder saknas") from None
    if not r.wcl_configured():
        raise ToolError("ingen Warcraft Logs-klient inlagd (GoblinRecorder → Inställningar → Warcraft Logs)")
    return r


def mmss(ms):
    s = max(0, int(ms / 1000))
    return f"{s // 60}:{s % 60:02d}"


def short(n):
    n = float(n or 0)
    return f"{n / 1e6:.1f} M" if n >= 1e6 else f"{n / 1e3:.0f} k" if n >= 1e3 else f"{n:.0f}"


def candidate_reports(r):
    """Report codes to look in, newest first: GoblinRecorder's films with a Warcraft Logs link, then
    your account's reports from the last day."""
    codes, player = [], ""
    try:
        folder = r.load_config().get("folder")
        for v in r.video_files(folder) if folder else []:
            player = player or v.get("player", "")
            code = (v.get("wcl") or {}).get("code")
            if code and code not in codes:
                codes.append(code)
    except Exception:  # noqa: BLE001 – the films are only a shortcut
        pass
    user = (r.wcl_load().get("users") or {}).get(player) if player else None
    if user:
        now = time.time() * 1000
        try:
            data = r.wcl_query("query($u:Int,$from:Float,$to:Float){ reportData { reports(userID:$u, startTime:$from,"
                               " endTime:$to, limit: 5) { data { code startTime } } } }",
                               {"u": user, "from": now - 24 * 3600 * 1000, "to": now})
            recent = sorted(data["reportData"]["reports"]["data"], key=lambda x: -x["startTime"])
            codes = [x["code"] for x in recent if x["code"] not in codes] + codes
        except Exception:  # noqa: BLE001
            pass
    return codes[:6], player


def find_fight(r, query):
    """(report, fight) for the query: a report link/code (+ #fight=N), a boss name, "pull N",
    or the latest boss pull."""
    m = re.search(r"reports/([A-Za-z0-9]{16})(?:#.*?fight=(\d+))?", query) or re.search(r"\b([A-Za-z0-9]{16})\b", query)
    codes, player = ([m.group(1)], "") if m else candidate_reports(r)
    wanted = int(m.group(2)) if m and m.lastindex and m.lastindex >= 2 and m.group(2) else None
    pull = re.search(r"\b(?:pull|försök|forsok)\s*(\d+)", query, re.I)
    words = [w for w in re.findall(r"[\w']+", query.lower())
             if w not in ("senaste", "sista", "pull", "pullen", "wipe", "wipen", "kill", "på", "vi", "den", "fight")
             and not w.isdigit() and len(w) > 2]
    for code in codes:
        rep = r.wcl_query("query($c:String){ reportData { report(code:$c) { code title startTime zone { name }"
                          " fights(killType: Encounters) { id name kill bossPercentage fightPercentage startTime"
                          " endTime lastPhase difficulty encounterID keystoneLevel } } } }", {"c": code})["reportData"]["report"]
        if not rep or not rep.get("fights"):
            continue
        fights = rep["fights"]
        if wanted:
            fights = [f for f in fights if f["id"] == wanted]
        elif words:
            fights = [f for f in fights if any(w in f["name"].lower().replace("'", "") or w in f["name"].lower() for w in words)] or (fights if m else [])
        if fights and pull:
            boss = fights[-1]["encounterID"]
            same = [f for f in rep["fights"] if f["encounterID"] == boss]
            n = int(pull.group(1))
            fights = [same[n - 1]] if 0 < n <= len(same) else []
        if fights:
            return rep, fights[-1], player
    raise ToolError("hittade ingen sådan pull i dina senaste rapporter på Warcraft Logs (bara uppladdade, "
                    "publika loggar – eller ge rapportens länk)")


ALL_WORDS = re.compile(r"\b(?:alla|allihop|varje|samtliga|all|every|bossar|bossarna)\b", re.I)


def wcl_pull(query=""):
    r = recorder()
    if ALL_WORDS.search(query):
        return wcl_all(r, query)
    try:
        rep, fight, player = find_fight(r, query)
        data = r.wcl_query(
            "query($c:String,$f:[Int]){ reportData { report(code:$c) {"
            " deaths: table(dataType: Deaths, fightIDs:$f)"
            " taken: table(dataType: DamageTaken, fightIDs:$f, viewBy: Ability, hostilityType: Friendlies)"
            " } } }", {"c": rep["code"], "f": [fight["id"]]})["reportData"]["report"]
        stats = r.wcl_stats({"code": rep["code"], "fight": fight["id"]})
    except ToolError:
        raise
    except Exception as e:  # noqa: BLE001 – the API or the network
        raise ToolError(f"Warcraft Logs svarade inte: {e}") from None
    return pull_text(rep, fight, player, data, stats)


def pull_text(rep, fight, player, data, stats, compact=False):
    """The pull as text for the AI; compact = fewer rows (several bosses in one answer)."""
    same = [f for f in rep["fights"] if f["encounterID"] == fight["encounterID"]]
    number = same.index(fight) + 1
    length = fight["endTime"] - fight["startTime"]
    diff = DIFFICULTY.get(fight.get("difficulty"), "")
    if fight.get("keystoneLevel"):
        diff = f"+{fight['keystoneLevel']}"
    result = "KILL" if fight.get("kill") else f"WIPE på {fight.get('bossPercentage', 0):.1f} % bossliv (fas {fight.get('lastPhase') or '?'})"
    out = [f"Warcraft Logs: {rep.get('title', '')} – {fight['name']} {diff}, pull {number} av {len(same)}: {result}, "
           f"{mmss(length)} lång.",
           f"Länk: https://www.warcraftlogs.com/reports/{rep['code']}#fight={fight['id']}"]
    if player and not compact:
        out.append(f"Användarens karaktär: {player.split('-')[0]}")

    def table(key):
        v = data.get(key) or {}
        return (v.get("data") or {}) if isinstance(v, dict) else {}

    limit = 8 if compact else 20
    deaths = sorted(table("deaths").get("entries") or [], key=lambda d: d.get("timestamp", 0))
    if deaths:
        out.append("\nDödsfall i ordning (tid in i pullen – vem – dödande förmåga och från vem – skada sista sekunderna):")
        for d in deaths[:limit]:
            dmg = d.get("damage") or {}
            ability = (d.get("killingBlow") or {}).get("name") or "?"
            src = ", ".join(s["name"] for s in (dmg.get("sources") or [])[:2])
            top = ", ".join(f"{a['name']} {short(a.get('total'))}" for a in sorted(
                dmg.get("abilities") or [], key=lambda a: -a.get("total", 0))[:3])
            out.append(f"- {mmss(d.get('timestamp', 0) - fight['startTime'])} {d['name']} ({d.get('icon', d.get('type', '')).replace('-', ' ')})"
                       f" – {ability}{' (' + src + ')' if src else ''}; {top}")
        if len(deaths) > limit:
            out.append(f"- … och {len(deaths) - limit} till")
    else:
        out.append("\nInga dödsfall.")
    taken = sorted(table("taken").get("entries") or [], key=lambda a: -a.get("total", 0))[:6 if compact else 10]
    if taken:
        out.append("\nSkadan raiden tog, mest först (förmåga – från – totalt – träffar):")
        for a in taken:
            hits = (a.get("hitCount") or 0) + (a.get("tickCount") or 0)
            out.append(f"- {a['name']} – {a.get('actorName', '?')} – {short(a.get('total'))} – {hits}")
    players = stats.get("players") or []
    if players:
        out.append("\nSpelarna (roll – spec klass – DPS – HPS – dödsfall" + (" – parse" if stats.get("ranked") else "") + "):")
        for p in players:
            parse = f" – {p['parse']:.0f}" if p.get("parse") is not None else ""
            out.append(f"- {p['name']} – {p['role']} – {p['spec']} {p['class']} – {short(p['dps'])} – {short(p['hps'])} – {p['deaths']}{parse}")
    if len(same) > 1:
        out.append(f"\nAlla pulls på {fight['name']} i rapporten (nr – resultat – tid):")
        for i, f in enumerate(same, 1):
            res = "KILL" if f.get("kill") else f"{f.get('bossPercentage', 0):.1f} % fas {f.get('lastPhase') or '?'}"
            mark = "  ← den här" if f is fight else ""
            out.append(f"- {i} – {res} – {mmss(f['endTime'] - f['startTime'])}{mark}")
    return "\n".join(out)


def wcl_all(r, query):
    """Every boss in one report: the kill (else the last pull) per boss, in the order they were fought."""
    m = re.search(r"reports/([A-Za-z0-9]{16})", query) or re.search(r"\b([A-Za-z0-9]{16})\b", query)
    try:
        codes, player = ([m.group(1)], "") if m else candidate_reports(r)
        for code in codes:
            rep, _, player2 = find_fight(r, f"reports/{code}")
            break
        else:
            raise ToolError("hittade ingen rapport på Warcraft Logs – ge rapportens länk")
        player = player or player2
        bosses = {}
        for f in rep["fights"]:  # the kill wins, else the latest pull
            b = bosses.get(f["encounterID"])
            if not b or not b.get("kill"):
                bosses[f["encounterID"]] = f
        chosen = sorted(bosses.values(), key=lambda f: f["startTime"])
        parts = [f"Warcraft Logs: {rep.get('title', '')} – {len(chosen)} bossar i rapporten "
                 f"({', '.join(f['name'] + (' (kill)' if f.get('kill') else ' (ingen kill)') for f in chosen)})."
                 " Analysera varje boss för sig, sedan det som går igen."]
        if player:
            parts.append(f"Användarens karaktär: {player.split('-')[0]}")
        for f in chosen:
            data = r.wcl_query(
                "query($c:String,$f:[Int]){ reportData { report(code:$c) {"
                " deaths: table(dataType: Deaths, fightIDs:$f)"
                " taken: table(dataType: DamageTaken, fightIDs:$f, viewBy: Ability, hostilityType: Friendlies)"
                " } } }", {"c": rep["code"], "f": [f["id"]]})["reportData"]["report"]
            stats = r.wcl_stats({"code": rep["code"], "fight": f["id"]})
            parts.append("\n══════ " + f["name"] + " ══════\n" + pull_text(rep, f, "", data, stats, compact=True))
    except ToolError:
        raise
    except Exception as e:  # noqa: BLE001 – the API or the network
        raise ToolError(f"Warcraft Logs svarade inte: {e}") from None
    return "\n".join(parts)
