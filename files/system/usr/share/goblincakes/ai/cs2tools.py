"""Goblin AI's ```cs2 tool (22 Oct, the user's wish – "what do I need to work on?"): your own CS2
numbers from GoblinRecorder's read demos (recorder.cs2_demo_*, kept in each match's .json) – the
latest match, the average over the last N and each match in a row, plus rough guide values, so even a
small local model compares with exact numbers instead of guessing."""

import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, os.environ.get("GOBLINCAKES_RECORDER_SHARE", "/usr/share/goblincakes/recorder"))
import recorder as R  # noqa: E402

DEFAULT_COUNT = 10
# Rough guide values for an ordinary matchmaking player (not Leetify's – TTD and sikte are our own
# approximate measures and not exactly comparable with other sites)
GUIDE = """Ungefärliga riktvärden för en vanlig matchmaking-spelare (inte exakta, bara för jämförelse):
- K/D ~1,0 · ADR ~75 (80+ bra, 90+ mycket bra) · KAST ~70 % (75+ bra) · HS ~40–50 %
- Entry: ungefär lika många vunna som förlorade är normalt
- TTD (time to damage, GOBLINCAKES egen uppskattning) ~500–650 ms, under 450 ms snabbt
- Sikte (crosshair placement, grader från huvudet när fienden syntes, egen uppskattning) ~5–8°, under 4° bra
- Reaktion (från att fienden syns till första skottet, egen uppskattning) ~400–500 ms, under 350 ms snabbt
- Första skottet träffar (när en fiende syns, egen uppskattning) ~20–35 %, 40+ bra
- Spray (kula 4 och framåt som träffar, gevär/k-pistar, egen uppskattning) ~15–25 %, 30+ bra
- Counter-strafe (första skottet avlossat nästan stilla) ~60–75 %, 80+ bra
- Träffsäkerhet med gevär (AK-47/M4) ~15–25 % (allt skjutande räknas, även spray)
- Flash: några bländade fiender per match är bra; många bländade lagkamrater = kasta om"""


def matches(private=False):
    """The CS2 matches with a read demo, oldest first – Valve's servers, or with private the rest
    (friends' servers, casual, workshop: CS2 Stats → PRIVAT)."""
    folder = R.load_config()["folder"]
    hist = R.cs2_history()
    out = [v for v in R.video_files(folder) if v.get("kind") == "cs2" and v.get("demoStats")
           and R.cs2_private(v, hist) == private]
    return sorted(out, key=lambda v: v.get("started", 0))


def _n(x, digits=0):
    if x is None:
        return "–"
    return (f"{x:.{digits}f}" if digits else str(round(x))).replace(".", ",")


def _when(v):
    return datetime.fromtimestamp(v.get("started", 0)).strftime("%Y-%m-%d %H:%M")


def _title(v):
    return f"{v.get('name', '')} {v.get('difficulty', '')} {v.get('score', '')} " \
           f"({ {'win': 'vinst', 'loss': 'förlust', 'tie': 'oavgjort'}.get(v.get('result'), 'avbruten') }) {_when(v)}"


def match_text(v):
    s = v["demoStats"]
    t = s.get("thrown", {})
    lines = [_title(v),
             f"K–D–A {s['kills']}–{s['deaths']}–{s['assists']} · K/D {_n(s['kd'], 2)} · ADR {_n(s['adr'], 1)} · "
             f"KAST {s['kast']} % · HS {s['hs']} %",
             f"Entry vunna–förlorade {s['entryWon']}–{s['entryLost']} · trades {s['trades']} · blev hämnad {s['traded']} gånger · "
             f"clutchar vunna {s['clutchWon']} av {s['clutches']} · " + " ".join(f"{k} {n}" for k, n in s["multi"].items() if n),
             f"TTD {_n(s.get('ttd'))} ms ({s.get('ttdCount', 0)} gånger) · sikte {_n(s.get('cp'), 1)}° ({s.get('cpCount', 0)} gånger)",
             f"Reaktion {_n(s.get('reaction'))} ms · första skottet {_n(s.get('firstShot'))} % ({s.get('firstShots', 0)} skott) · "
             f"spray {_n(s.get('spray'))} % ({s.get('sprayShots', 0)} skott) · counter-strafe {_n(s.get('strafe'))} %",
             "Vapen: " + "; ".join(f"{w['name']} {w['kills']} kills, {w['hs']} HS, träff {_n(w['acc'])} % av {w['shots']} skott"
                                   for w in s.get("weapons", [])),
             f"Granater: {t.get('flash', 0)} flash ({s.get('flashed', 0)} fiender och {s.get('teamFlashed', 0)} lagkamrater bländade, "
             f"{s.get('flashAssists', 0)} flash-assist), {t.get('smoke', 0)} smoke, {t.get('he', 0)} HE ({s.get('heDmg', 0)} skada), "
             f"{t.get('molotov', 0)} molotov ({s.get('fireDmg', 0)} skada)",
             "Ekonomi: snitt $" + str(s.get("avgEquip", 0)) + " · " + ", ".join(
                 f"{name} {b['rounds']} rundor ({b['won']} vunna, {b['kills']} kills)"
                 for name, b in (("fullköp", s["buys"].get("full")), ("halvköp", s["buys"].get("force")), ("eco", s["buys"].get("eco")))
                 if b and b["rounds"])]
    rounds = v.get("demoRounds") or []
    if rounds:
        lines.append("Rundor (V/F, kills, skada, dog?): " + " ".join(
            f"{r['r']}:{'V' if r['won'] else 'F'}{r['k']}k{r['dmg']}{'' if r['died'] else 'ö'}" for r in rounds)
            + " (ö = överlevde)")
    return "\n".join(lines)


def average_text(ms):
    def avg(key):
        xs = [m["demoStats"].get(key) for m in ms if m["demoStats"].get(key) is not None]
        return sum(xs) / len(xs) if xs else None
    per = lambda key: _n(sum(m["demoStats"].get(key, 0) for m in ms) / len(ms), 1)  # noqa: E731 – per match
    guns = {}
    for m in ms:
        for w in m["demoStats"].get("weapons", []):
            g = guns.setdefault(w["name"], {"kills": 0, "hs": 0, "shots": 0, "hits": 0})
            for k in g:
                g[k] += w.get(k) or 0
    wins = sum(m.get("result") == "win" for m in ms)
    lines = [f"Snitt över de senaste {len(ms)} matcherna ({wins} vinster):",
             f"K/D {_n(avg('kd'), 2)} · ADR {_n(avg('adr'), 1)} · KAST {_n(avg('kast'))} % · HS {_n(avg('hs'))} % · "
             f"TTD {_n(avg('ttd'))} ms · sikte {_n(avg('cp'), 1)}° · reaktion {_n(avg('reaction'))} ms · "
             f"första skottet {_n(avg('firstShot'))} % · spray {_n(avg('spray'))} % · counter-strafe {_n(avg('strafe'))} %",
             f"Per match i snitt: entry vunna {per('entryWon')}, förlorade {per('entryLost')} · trades {per('trades')} · "
             f"clutchar vunna {per('clutchWon')} av {per('clutches')} · fiender bländade {per('flashed')} · "
             f"lagkamrater bländade {per('teamFlashed')}",
             "Vapen totalt: " + "; ".join(
                 f"{name} {g['kills']} kills, HS {_n(100 * g['hs'] / g['kills']) if g['kills'] else '–'} %, "
                 f"träff {_n(100 * g['hits'] / g['shots']) if g['shots'] else '–'} %"
                 for name, g in sorted(guns.items(), key=lambda x: -x[1]["kills"])[:6]),
             "Match för match (äldst först): " + " | ".join(
                 f"{m.get('name', '')} {m.get('score', '')} ADR {_n(m['demoStats']['adr'])} K/D {_n(m['demoStats']['kd'], 2)} "
                 f"TTD {_n(m['demoStats'].get('ttd'))} sikte {_n(m['demoStats'].get('cp'), 1)}" for m in ms)]
    return "\n".join(lines)


def cs2_stats(query):
    """The text for the AI: `senaste`, `senaste 20` / `20`, or a map name (its latest match)."""
    q = (query or "").lower()
    private = "privat" in q
    ms = matches(private)
    if not ms and private:
        return "Inga privata CS2-matcher med läst demo än (CS2 Stats → PRIVAT)."
    if not ms:
        waiting = [v for v in R.video_files(R.load_config()["folder"]) if v.get("kind") == "cs2" and v.get("demo") == "waiting"]
        return ("Inga CS2-matcher med läst demo än." + (f" {len(waiting)} väntar på demon (ladda ner i CS2: Watch → Your Matches)."
                                                      if waiting else " GoblinRecorder läser demon efter en Competitive/Premier/Wingman-match."))
    count = int(m.group(1)) if (m := re.search(r"(\d+)", q)) else DEFAULT_COUNT
    latest = ms[-1]
    for v in reversed(ms):  # a map named: its latest match
        if v.get("name", "").lower() in q or v.get("map", "").lower() in q:
            latest = v
            break
    recent = ms[-max(1, count):]
    return "\n\n".join([
        "SENASTE MATCHEN" if latest is ms[-1] else "MATCHEN", match_text(latest),
        average_text(recent),
        GUIDE,
    ])
