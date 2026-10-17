"""WoW tools for Goblin AI (16 Oct): the AI asks for them with a code block, like a web search.

- wow_errors(query): the errors BugSack/BugGrabber saved (!BugGrabber.lua in WTF – only read,
  never changed: WoW's files are not touched), with the add-on's version from its .toc.
- wcl_pull(query): one pull from Warcraft Logs – result, boss health and phase, deaths with what
  killed them, the damage the raid took, everyone's DPS/HPS and the other pulls on the boss – or,
  with "alla" in the query, every boss in the report (the kill, else the last pull; 17 Oct) –
  through GoblinRecorder's Warcraft Logs client (recorder.py, ~/.config/goblincakes/wcl.json).
  Each pull also has the raid's cooldowns with times, interrupts and dispels (18 Oct), and
  "<boss> förmåga: <namn>" looks at one ability: when it came, who got it, who died and which
  cooldowns were used during it (the user asked who used cooldowns on Venomous Heart and the
  AI only had a summary to go on).

Both return plain text for the AI (Swedish headings, the game's own English names).
"""
import difflib
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
             if w not in ("senaste", "sista", "pull", "pullen", "wipe", "wipen", "kill", "på", "vi", "den", "fight",
                          "alla", "boss", "bossen")
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


# Cooldowns worth reporting (the game's English names, as in Warcraft Logs): raid-wide, on someone
# else, on yourself, Bloodlust and the like, and damage cooldowns (only shown when one ability or
# enemy is asked about – too many otherwise).
RAID_CDS = ("Spirit Link Totem", "Healing Tide Totem", "Tranquility", "Divine Hymn", "Power Word: Barrier",
            "Evangelism", "Rapture", "Apotheosis", "Aura Mastery", "Revival", "Restoral", "Rewind",
            "Zephyr", "Dream Flight", "Emerald Communion", "Rallying Cry", "Anti-Magic Zone", "Darkness",
            "Vampiric Embrace", "Convoke the Spirits", "Ancestral Protection Totem")
EXTERNAL_CDS = ("Pain Suppression", "Guardian Spirit", "Ironbark", "Life Cocoon", "Blessing of Sacrifice",
                "Blessing of Protection", "Blessing of Spellwarding", "Lay on Hands", "Time Dilation",
                "Intervene", "Power Infusion")
PERSONAL_CDS = ("Healthstone", "Ice Block", "Ice Cold", "Alter Time", "Greater Invisibility", "Mirror Image",
                "Divine Shield", "Divine Protection", "Ardent Defender", "Guardian of Ancient Kings",
                "Shield of Vengeance", "Astral Shift", "Unending Resolve", "Dark Pact", "Barkskin",
                "Survival Instincts", "Frenzied Regeneration", "Renewal", "Icebound Fortitude",
                "Anti-Magic Shell", "Lichborne", "Vampiric Blood", "Blur", "Netherwalk", "Fiery Brand",
                "Cloak of Shadows", "Evasion", "Feint", "Crimson Vial", "Aspect of the Turtle",
                "Survival of the Fittest", "Exhilaration", "Fortifying Brew", "Diffuse Magic",
                "Dampen Harm", "Touch of Karma", "Obsidian Scales", "Renewing Blaze", "Die by the Sword",
                "Enraged Regeneration", "Shield Wall", "Last Stand", "Spell Reflection", "Desperate Prayer",
                "Dispersion", "Fade")
LUST = ("Bloodlust", "Heroism", "Time Warp", "Fury of the Aspects", "Primal Rage", "Ancient Hysteria")
DPS_CDS = ("Avenging Wrath", "Crusade", "Pillar of Frost", "Empower Rune Weapon", "Army of the Dead",
           "Dark Transformation", "Unholy Assault", "Abomination Limb", "Apocalypse", "Dancing Rune Weapon",
           "Metamorphosis", "The Hunt", "Celestial Alignment", "Incarnation: Chosen of Elune",
           "Incarnation: Avatar of Ashamane", "Berserk", "Force of Nature", "Dragonrage", "Deep Breath",
           "Breath of Eons", "Trueshot", "Bestial Wrath", "Call of the Wild", "Coordinated Assault",
           "Combustion", "Icy Veins", "Arcane Surge", "Invoke Xuen, the White Tiger",
           "Storm, Earth, and Fire", "Celestial Conduit", "Voidform", "Dark Ascension", "Shadowfiend",
           "Adrenaline Rush", "Shadow Blades", "Deathmark", "Kingsbane", "Shadow Dance", "Ascendance",
           "Stormkeeper", "Feral Spirit", "Doom Winds", "Summon Darkglare", "Summon Demonic Tyrant",
           "Summon Infernal", "Avatar", "Recklessness", "Bladestorm", "Ravager", "Thunderous Roar")
CD_KIND = {**{n: "dps" for n in DPS_CDS}, **{n: "egen" for n in PERSONAL_CDS},
           **{n: "extern" for n in EXTERNAL_CDS}, **{n: "lust" for n in LUST},
           **{n: "raid" for n in RAID_CDS}}
CD_FILTER = "ability.name in (" + ", ".join(f'"{n}"' for n in CD_KIND) + ")"

FIGHT_QUERY = ("query($c:String,$f:[Int]){ reportData { report(code:$c) {"
               " deaths: table(dataType: Deaths, fightIDs:$f)"
               " taken: table(dataType: DamageTaken, fightIDs:$f, viewBy: Ability, hostilityType: Friendlies)"
               " ints: table(dataType: Interrupts, fightIDs:$f)"
               " disp: table(dataType: Dispels, fightIDs:$f)"
               " } } }")

_names = {}  # report code → (ability names by game id, actors by id)


def report_names(r, code):
    if code not in _names:
        md = r.wcl_query("query($c:String){ reportData { report(code:$c) { masterData {"
                         " abilities { gameID name } actors { id name type } } } } }",
                         {"c": code})["reportData"]["report"]["masterData"]
        _names[code] = ({a["gameID"]: a["name"] for a in md.get("abilities") or []},
                        {a["id"]: a for a in md.get("actors") or []})
    return _names[code]


def events(r, code, fight, pages=8, **args):
    """Events in a fight, every page (args: dataType, hostilityType, abilityID, targetID, filterExpression)."""
    types = {"dataType": "EventDataType", "hostilityType": "HostilityType", "abilityID": "Float",
             "targetID": "Int", "filterExpression": "String"}
    decl = "".join(f", ${k}:{types[k]}" for k in args)
    call = "".join(f", {k}:${k}" for k in args)
    query = (f"query($c:String,$f:[Int],$s:Float,$e:Float{decl}){{ reportData {{ report(code:$c) {{"
             f" events(fightIDs:$f, startTime:$s, endTime:$e, limit: 5000{call}) {{ data nextPageTimestamp }} }} }} }}")
    out, start = [], fight["startTime"]
    for _ in range(pages):
        ev = r.wcl_query(query, {"c": code, "f": [fight["id"]], "s": start, "e": fight["endTime"], **args}
                         )["reportData"]["report"]["events"]
        out += ev.get("data") or []
        start = ev.get("nextPageTimestamp")
        if not start:
            break
    return out


def cooldowns(r, rep, fight):
    """The fight's cooldowns in order: {t (ms into the pull), who, name, kind, target}."""
    abilities, actors = report_names(r, rep["code"])
    out, last = [], {}
    for e in events(r, rep["code"], fight, dataType="Casts", hostilityType="Friendlies", filterExpression=CD_FILTER):
        name = abilities.get(e.get("abilityGameID"), "")
        who = (actors.get(e.get("sourceID")) or {}).get("name", "?")
        t = e["timestamp"] - fight["startTime"]
        if name not in CD_KIND or t - last.get((who, name), -99999) < 15000:
            continue  # channels (Divine Hymn) log a cast per tick
        last[(who, name)] = t
        target = (actors.get(e.get("targetID")) or {}).get("name")
        out.append({"t": t, "who": who, "name": name, "kind": CD_KIND[name],
                    "target": target if CD_KIND[name] == "extern" and target != who else None})
    return out


def fight_data(r, rep, fight):
    data = r.wcl_query(FIGHT_QUERY, {"c": rep["code"], "f": [fight["id"]]})["reportData"]["report"]
    data["cooldowns"] = cooldowns(r, rep, fight)
    return data


def cd_text(c):
    return f"{mmss(c['t'])} {c['who']} {c['name']}{' på ' + c['target'] if c.get('target') else ''} ({c['kind']})"


def wcl_pull(query=""):
    r = recorder()
    ability = re.search(r"(?:förmåga|formaga|ability|mekanik)\s*:?\s*(.+)$", query, re.I)
    if ability:  # the link may come before or after the name
        link = re.compile(r"\S*warcraftlogs\.com/reports/\S+|\b[A-Za-z0-9]{16}\b")
        wanted = link.sub(" ", ability.group(1))
        links = " ".join(link.findall(ability.group(1)))
        return wcl_ability(r, f"{query[:ability.start()]} {links}".strip(), " ".join(wanted.split()).strip(" \"'–-"))
    if ALL_WORDS.search(query):
        return wcl_all(r, query)
    try:
        rep, fight, player = find_fight(r, query)
        data = fight_data(r, rep, fight)
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

    def groups(t):  # interrupt/dispel tables: one entry per enemy ability, sometimes one level down
        out_ = []
        for e in t.get("entries") or []:
            out_ += e.get("entries") if isinstance(e.get("entries"), list) else [e]
        return out_

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
    cds = [c for c in data.get("cooldowns") or [] if c["kind"] != "dps" and (not compact or c["kind"] != "egen")]
    if cds:
        out.append("\nCooldowns" + (" (raid, lust och på andra)" if compact else "") +
                   " i tidsordning (tid vem förmåga (sort: raid, lust, extern = på någon annan, egen = försvar"
                   " på sig själv)); skade-cooldowns finns bara när du frågar om en förmåga/fiende:")
        for c in cds[:30 if compact else 120]:
            out.append(f"- {cd_text(c)}")
    else:
        out.append("\nInga raid-cooldowns hittades i loggen.")
    ints = groups(table("ints"))
    if ints:
        out.append("\nInterrupts (fiendens förmåga – påbörjade – avbrutna – vem avbröt):")
        for g in sorted(ints, key=lambda g: -(g.get("spellsBegun") or 0))[:4 if compact else 8]:
            who = ", ".join(f"{d['name']} {d.get('total', 0)}" for d in sorted(
                g.get("details") or [], key=lambda d: -d.get("total", 0)))
            out.append(f"- {g['name']} – {g.get('spellsBegun', 0)} – {g.get('spellsInterrupted', 0)} – {who or 'ingen'}")
    disp = groups(table("disp"))
    if disp and not compact:
        out.append("\nDispels (debuff – vem tog bort den, antal):")
        for g in disp[:8]:
            who = ", ".join(f"{d['name']} {d.get('total', 0)}" for d in sorted(
                g.get("details") or [], key=lambda d: -d.get("total", 0)))
            out.append(f"- {g['name']} – {who}")
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
            data = fight_data(r, rep, f)
            stats = r.wcl_stats({"code": rep["code"], "fight": f["id"]})
            parts.append("\n══════ " + f["name"] + " ══════\n" + pull_text(rep, f, "", data, stats, compact=True))
    except ToolError:
        raise
    except Exception as e:  # noqa: BLE001 – the API or the network
        raise ToolError(f"Warcraft Logs svarade inte: {e}") from None
    return "\n".join(parts)



def waves_of(times, gap):
    """Times (ms) → [start, end] groups where nothing happened for gap ms in between."""
    waves = []
    for t in sorted(set(times)):
        if waves and t - waves[-1][1] < gap:
            waves[-1][1] = t
        else:
            waves.append([t, t])
    return waves


def wcl_ability(r, boss_query, wanted):
    """One ability or enemy in one pull: every time it came, who got it, who took (or did) how much,
    who died during it and the cooldowns used around it – also damage cooldowns and lust."""
    try:
        rep, fight, _ = find_fight(r, boss_query or "senaste")
        abilities, actors = report_names(r, rep["code"])
        code, low = rep["code"], wanted.lower()
        ids = [i for i, n in abilities.items() if n.lower() == low] or \
              [i for i, n in abilities.items() if low in n.lower()][:4]
        enemies = [a for a in actors.values() if a.get("type") == "NPC" and a["name"].lower() == low]
        if not ids and not enemies:
            names = sorted(set(abilities.values()) | {a["name"] for a in actors.values() if a.get("type") == "NPC"})
            near = difflib.get_close_matches(wanted, names, n=6, cutoff=0.6)
            raise ToolError(f"ingen förmåga eller fiende som heter \"{wanted}\" i rapporten"
                            + (f" – menade du: {', '.join(near)}?" if near else ""))
        evs = []
        for i in ids:
            for src, dtype, host in (("e", "Buffs", "Enemies"), ("e", "Debuffs", "Enemies"), ("ec", "Casts", "Enemies"),
                                     ("fd", "Debuffs", "Friendlies"), ("fc", "Casts", "Friendlies"),
                                     ("dt", "DamageTaken", "Friendlies")):
                evs += [{**e, "src": src} for e in events(r, code, fight, dataType=dtype, hostilityType=host, abilityID=i)]
        hits = []  # damage on the enemy asked about
        for a in enemies:
            hits += events(r, code, fight, dataType="DamageDone", hostilityType="Friendlies", targetID=a["id"])
        data = fight_data(r, rep, fight)
    except ToolError:
        raise
    except Exception as e:  # noqa: BLE001 – the API or the network
        raise ToolError(f"Warcraft Logs svarade inte: {e}") from None

    start = fight["startTime"]
    who = lambda i: (actors.get(i) or {}).get("name", "?")  # noqa: E731
    what = (abilities[ids[0]] if ids else enemies[0]["name"])
    out = [f"Warcraft Logs: {rep.get('title', '')} – {fight['name']}, pull {fight['id']} i rapporten "
           f"({'KILL' if fight.get('kill') else 'wipe'}, {mmss(fight['endTime'] - start)} lång) – {what}.",
           f"Länk: https://www.warcraftlogs.com/reports/{code}#fight={fight['id']}"]
    if not evs and not hits:
        return "\n".join(out + ["Den syns inte i den här pullen (fråga om en annan pull eller boss)."])

    # When it came: the enemy's casts, its buffs that are removed again (not auras that last the
    # whole fight), debuffs on players, player casts, the damage, the enemy being hit
    ends = sorted(e["timestamp"] for e in evs if e["type"] in ("removebuff", "removedebuff"))
    applied = [e for e in evs if e["src"] == "e" and e["type"] in ("applybuff", "applydebuff")
               and any(0 < t - e["timestamp"] < 90000 for t in ends)]
    for times, gap in (([e["timestamp"] for e in evs if e["src"] == "ec" and e["type"] == "cast"]
                        + [e["timestamp"] for e in applied], 8000),
                       ([e["timestamp"] for e in evs if e["src"] == "fd" and e["type"] == "applydebuff"], 8000),
                       ([e["timestamp"] for e in evs if e["src"] == "fc" and e["type"] == "cast"], 8000),
                       ([e["timestamp"] for e in evs if e["src"] == "dt"], 4000),
                       ([e["timestamp"] for e in hits], 6000)):
        if times:
            waves = waves_of(times, gap)
            break
    for w in waves:  # a buff/debuff lasts until it is removed
        after = [t for t in ends if w[1] <= t < w[1] + 90000]
        w[1] = max(w[1], after[0] if after else w[1])
    if enemies and hits:  # the enemy: from the first to the last hit in each wave
        for w in waves:
            inside = [e["timestamp"] for e in hits if w[0] - 2000 <= e["timestamp"] <= w[1] + 30000]
            w[1] = max(w[1], max(inside) if inside else w[1])

    def tally(rows, key):
        out_ = {}
        for e in rows:
            if e["type"] == "damage":
                n = who(e.get(key))
                out_[n] = out_.get(n, 0) + (e.get("amount") or 0) + (e.get("absorbed") or 0)
        return sorted(out_.items(), key=lambda x: -x[1])

    deaths = sorted(((data.get("deaths") or {}).get("data") or {}).get("entries") or [],
                    key=lambda d: d.get("timestamp", 0))
    out.append(f"Den kom {len(waves)} gång{'er' if len(waves) != 1 else ''}. Tiderna är från pullens början; "
               "cooldowns räknas från 5 s före till 3 s efter. Sort: dps = skade-cooldown, raid, lust, "
               "extern = på någon annan, egen = försvar på sig själv.")
    for n, (a, b) in enumerate(waves[:15], 1):
        inside = [e for e in evs if a - 1000 <= e["timestamp"] <= b + 1000]
        got = sorted({who(e.get("targetID")) for e in inside
                      if e["src"] == "fd" and e["type"] in ("applydebuff", "applydebuffstack", "refreshdebuff")})
        used = sorted({who(e.get("sourceID")) for e in inside if e["src"] == "fc" and e["type"] == "cast"})
        taken = tally([e for e in inside if e["src"] == "dt"], "targetID")
        done = tally([e for e in hits if a - 1000 <= e["timestamp"] <= b + 1000], "sourceID")
        long = b - a > 60000  # an aura or damage all through the pull: only its own deaths, no cooldowns
        died = [d for d in deaths if a <= d.get("timestamp", 0) <= b + 5000
                and (not long or (d.get("killingBlow") or {}).get("name", "").lower() == what.lower())]
        cds = [] if long else [c for c in data["cooldowns"] if a - start - 5000 <= c["t"] <= b - start + 3000]
        out.append(f"\n{n}. {mmss(a - start)}–{mmss(b - start)}"
                   + (" (pågår större delen av pullen – cooldowns visas inte, dödsfall bara av den)" if long else ""))
        if got:
            out.append(f"- Fick den: {', '.join(got)}")
        if used:
            out.append(f"- Använde den: {', '.join(used)}")
        if taken:
            out.append(f"- Skada av den: {short(sum(v for _, v in taken))} totalt; mest: "
                       + ", ".join(f"{w} {short(v)}" for w, v in taken[:6]))
        if done:
            out.append(f"- Skada på {enemies[0]['name']}: {short(sum(v for _, v in done))} totalt; "
                       + ", ".join(f"{w} {short(v)}" for w, v in done[:12]))
        out.append("- Dog under den (eller inom 5 s): " + ("; ".join(
            f"{d['name']} {mmss(d['timestamp'] - start)} av {(d.get('killingBlow') or {}).get('name', '?')}"
            for d in died) if died else "ingen"))
        if not long:
            out.append("- Cooldowns: " + ("; ".join(cd_text(c) for c in cds) if cds else "inga"))
    if len(waves) > 15:
        out.append(f"\n… och {len(waves) - 15} gånger till.")
    if len(waves) > 1:
        taken = tally([e for e in evs if e["src"] == "dt"], "targetID")
        if taken:
            out.append("\nSkada av den under hela pullen, mest först: "
                       + ", ".join(f"{w} {short(v)}" for w, v in taken[:10]))
        done = tally(hits, "sourceID")
        if done:
            out.append(f"\nSkada på {enemies[0]['name']} under hela pullen: "
                       + ", ".join(f"{w} {short(v)}" for w, v in done[:20]))
    return "\n".join(out)
