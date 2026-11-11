"""GOBLINCAKES Dashboard, step 2 – the frames WOW STATS, CS2 STATS, BYGGEN and KAKAN and what they show in the
middle. Only reads what the others have saved (nothing is written to their files):

    python3 stats.py wow|wow-fetch|cs2|builds|reports

wow()       GoblinRecorder's WoW history (~/.local/share/goblincakes/wow-history.json): the characters and the
            latest raid evening per boss. fetch=True also asks Warcraft Logs how low each wipe got the boss (one
            question per report, kept in ~/.cache/goblincakes/dashboard-wcl.json).
cs2()       GoblinRecorder's CS2 history: the season's official matches – the last 10, each map and its matches.
builds()    the image's builds on GitHub (ai/buildstatus.py), kept 5 minutes; only for the one who has the repo.
reports()   Kakan's reports to Claude (ai/toclaude.py's folder).
"""
import calendar
import json
import os
import re
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
for folder in (HERE.parent / "recorder", HERE.parent / "ai"):
    if str(folder) not in sys.path:
        sys.path.insert(0, str(folder))

CACHE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "goblincakes"
WCL_CACHE = CACHE / "dashboard-wcl.json"
BUILD_CACHE = CACHE / "dashboard-builds.json"
BUILD_AGE = 300
BUILD_AGE_RUNNING = 60  # while a build runs (Kakan's "bygget är klart" also removes the file: buildstatus.tell_watched)
DAYS = ["måndag", "tisdag", "onsdag", "torsdag", "fredag", "lördag", "söndag"]
MONTHS = ["jan", "feb", "mar", "apr", "maj", "jun", "jul", "aug", "sep", "okt", "nov", "dec"]


def _recorder():
    import recorder  # noqa: PLC0415 – heavy to read; only when a frame needs it
    return recorder


def _load(path):
    try:
        data = json.loads(Path(path).read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def _save(path, data):
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".tmp")
        tmp.write_text(json.dumps(data, ensure_ascii=False))
        tmp.replace(path)
    except OSError:
        pass


def day_text(t, weekday=True):
    """A time as "söndag 8 nov" (or "8 nov")."""
    lt = time.localtime(t)
    text = f"{lt.tm_mday} {MONTHS[lt.tm_mon - 1]}"
    return f"{DAYS[lt.tm_wday]} {text}" if weekday else text


def span_text(seconds):
    seconds = int(max(0, seconds))
    h, m = seconds // 3600, seconds % 3600 // 60
    return f"{h} h {m} min" if h else f"{m} min"


def clock_text(seconds):
    seconds = int(max(0, seconds or 0))
    return f"{seconds // 60}:{seconds % 60:02d}"


def num(value, digits=2):
    return "–" if value is None else f"{value:.{digits}f}".replace(".", ",")


# ── WoW ───────────────────────────────────────────────────────

def _report_of(url):
    """(code, fight id) of a Warcraft Logs link, or ("", 0)."""
    m = re.search(r"/reports/(\w+)#fight=(\d+)", url or "")
    return (m.group(1), int(m.group(2))) if m else ("", 0)


def boss_percent(codes, fetch):
    """{code: {fight id (text): the boss's health when the pull ended}} from the cache; fetch=True asks Warcraft
    Logs for the reports that are missing (or fresh – a live-logged evening grows)."""
    cache = _load(WCL_CACHE)
    if fetch:
        r = _recorder()
        try:
            ok = r.wcl_configured()
        except Exception:  # noqa: BLE001
            ok = False
        changed = False
        for code, newest in codes.items():
            had = cache.get(code) or {}
            live = time.time() - newest < 12 * 3600      # tonight's raid: asked again every 10 minutes
            if not ok or (had and not (live and time.time() - had.get("at", 0) > 600)):
                continue
            try:
                rep = r.wcl_query("query($c:String){ reportData { report(code:$c) { fights(killType: Encounters) "
                                  "{ id kill bossPercentage } } } }", {"c": code})["reportData"]["report"] or {}
            except Exception:  # noqa: BLE001 – no network, the hour's points spent: the bars come another time
                continue
            cache[code] = {"at": time.time(), "fights": {str(f["id"]): (0 if f.get("kill") else f.get("bossPercentage"))
                                                         for f in rep.get("fights") or []}}
            changed = True
        if changed:
            for code in sorted(cache, key=lambda c: cache[c].get("at", 0))[:-40]:
                del cache[code]
            _save(WCL_CACHE, cache)
    return {code: (cache.get(code) or {}).get("fights") or {} for code in codes}


def latest_raid(entries, fetch=False):
    """The latest raid evening of the character that raided last: per boss its pulls, kill or best wipe, your
    parse and deaths; None without a raid in the history."""
    r = _recorder()
    raids = [e for e in entries if e.get("kind") == "raid" and e.get("started") and e.get("player")]
    if not raids:
        return None
    newest = max(raids, key=lambda e: e["started"])
    evening = r._evening(newest["started"])
    pulls = sorted((e for e in raids if e["player"] == newest["player"] and r._evening(e["started"]) == evening),
                   key=lambda e: e["started"])
    codes = {}
    for e in pulls:
        code, _ = _report_of(e.get("url"))
        if code:
            codes[code] = max(codes.get(code, 0), e["started"])
    percent = boss_percent(codes, fetch)
    bosses = {}
    for e in pulls:
        code, fight = _report_of(e.get("url"))
        kill = e.get("result") == "kill"
        pct = 0 if kill else (percent.get(code) or {}).get(str(fight))
        b = bosses.setdefault((e.get("name"), e.get("difficulty")), {
            "name": e.get("name") or "?", "difficulty": e.get("difficulty") or "", "pulls": [], "kill": False,
            "parse": None, "deaths": 0, "url": ""})
        b["pulls"].append({"kill": kill, "pct": pct, "time": clock_text(e.get("fight")), "url": e.get("url") or ""})
        b["kill"] = b["kill"] or kill
        b["deaths"] += e.get("deaths") or 0
        if kill and e.get("parse") is not None:
            b["parse"] = max(b["parse"] or 0, e["parse"])
        b["url"] = e.get("url") or b["url"]
    rows = []
    for b in bosses.values():
        wipes = [p["pct"] for p in b["pulls"] if not p["kill"] and p["pct"] is not None]
        b["best"] = "kill" if b["kill"] else (num(min(wipes), 1) + " %" if wipes else "wipe")
        b["count"] = len(b["pulls"])
        b["bars"] = all(p["pct"] is not None for p in b["pulls"])
        rows.append(b)
    difficulties = sorted({b["difficulty"] for b in rows if b["difficulty"]},
                          key=lambda d: r.DIFF_ORDER.index(d) if d in r.DIFF_ORDER else 9)
    parses = [b["parse"] for b in rows if b["parse"] is not None]
    last = pulls[-1]
    length = last["started"] + (last.get("fight") or 0) - pulls[0]["started"]
    return {
        "player": newest["player"], "name": newest["player"].split("-")[0], "difficulty": " / ".join(difficulties),
        "day": day_text(pulls[0]["started"]), "short": day_text(pulls[0]["started"], False), "length": span_text(length),
        "killed": sum(b["kill"] for b in rows), "bosses": rows, "pulls": len(pulls),
        "bestParse": max(parses) if parses else None, "deaths": sum(b["deaths"] for b in rows),
        "url": f"{r.WCL}/reports/{next(iter(codes))}" if codes else "", "wcl": bool(codes),
        # PÅGÅR (Levande utseende step 5): the last pull ended less than 30 minutes ago – the raid is still on
        "live": time.time() - (last["started"] + (last.get("fight") or 0)) < 30 * 60,
    }


def wow(fetch=False):
    """{"players": [the characters, the last played first], "raid": latest_raid()} – {} without a history."""
    r = _recorder()
    entries = [e for e in r.wow_history().values() if isinstance(e, dict)]
    if not entries:
        return {}
    by_player = {}
    for e in sorted(entries, key=lambda e: e.get("started") or 0):
        if e.get("player"):
            by_player.setdefault(e["player"], []).append(e)
    players = []
    for player, own in sorted(by_player.items(), key=lambda kv: -(kv[1][-1].get("started") or 0)):
        try:
            seasons = r.season_list("wow", own)
            mine = r.in_season(own, seasons[0]) if seasons else own
        except Exception:  # noqa: BLE001 – a broken seasons file must not hide the characters
            mine = own
        mine = mine or own
        last = next((e for e in reversed(own) if e.get("class")), {})
        done = [e for e in mine if e.get("result") in ("kill", "timed")]
        raid_parses = [e["parse"] for e in done if e.get("kind") == "raid" and e.get("parse") is not None]
        key_parses = [e["parse"] for e in done if e.get("kind") == "mplus" and e.get("parse") is not None]
        keys = [e for e in mine if e.get("kind") == "mplus"]
        parts = player.split("-")
        name, realm, region = (parts[0], "-".join(parts[1:-1]), parts[-1]) if len(parts) >= 3 else (player, "", "")
        avg = lambda xs: round(sum(xs) / len(xs)) if xs else None  # noqa: E731
        players.append({
            "player": player, "name": name, "realm": realm, "region": region,
            "class": last.get("class", ""), "spec": last.get("spec", ""),
            "ilvl": next((round(e["ilvl"]) for e in reversed(own) if e.get("ilvl")), None),
            "raidParse": avg(raid_parses), "bestParse": max(raid_parses + key_parses, default=None),
            "keyParse": avg(key_parses), "kills": sum(e.get("kind") == "raid" and e.get("result") == "kill" for e in mine),
            "wipes": sum(e.get("kind") == "raid" and e.get("result") == "wipe" for e in mine),
            "keys": len(keys), "timed": sum(e.get("result") == "timed" for e in keys),
            "topKey": max((e.get("level") or 0 for e in keys if e.get("result") == "timed"), default=0) or None,
            "trend": [{"parse": e["parse"], "name": e.get("name") or "", "kind": e.get("kind")}
                      for e in mine if e.get("parse") is not None][-40:],
            "last": day_text(own[-1].get("started") or 0, False),
            "wclUrl": f"{r.WCL}/character/{region.lower()}/{r.server_slug(realm)}/{name.lower()}" if region else "",
        })
    return {"players": players, "raid": latest_raid(entries, fetch)}


# ── CS2 ───────────────────────────────────────────────────────

def cs2(count=10):
    """{count, wins, losses, avg {kd, adr, kast, hs}, maps [{name, matches, win %, adr, kd, rows}], last} of the
    season's official matches (not PRIVAT) – {} without any."""
    r = _recorder()
    hist = r.cs2_history()
    side = [m for m in hist.values() if isinstance(m, dict) and isinstance(m.get("stats"), dict)
            and r.cs2_private(m, hist) is False]
    try:
        seasons = r.season_list("cs2", side)
        ms = r.in_season(side, seasons[0] if seasons else None)
    except Exception:  # noqa: BLE001
        ms = side
    ms = sorted(ms or side, key=lambda m: m.get("started", 0))
    if not ms:
        return {}
    recent = ms[-count:]

    def avg(key, of):
        xs = [m["stats"].get(key) for m in of if m["stats"].get(key) is not None]
        return round(sum(xs) / len(xs), 2) if xs else None

    def row(m):
        return {"date": day_text(m.get("started", 0), False), "score": m.get("score") or "", "result": m.get("result") or "",
                "adr": num(m["stats"].get("adr"), 0), "kd": num(m["stats"].get("kd")), "map": m.get("name") or "?"}

    maps = {}
    for m in ms:
        maps.setdefault(m.get("name") or "?", []).append(m)
    return {
        "count": len(recent), "all": len(ms), "wins": sum(m.get("result") == "win" for m in recent),
        "losses": sum(m.get("result") == "loss" for m in recent),
        "avg": {"kd": num(avg("kd", recent)), "adr": num(avg("adr", recent), 0), "kast": num(avg("kast", recent), 0),
                "hs": num(avg("hs", recent), 0)},
        "maps": sorted(({"name": name, "matches": len(g),
                         "win": f"{round(100 * sum(m.get('result') == 'win' for m in g) / len(g))} %",
                         "adr": num(avg("adr", g), 0), "kd": num(avg("kd", g)),
                         "rows": [row(m) for m in reversed(g[-6:])]} for name, g in maps.items()),
                       key=lambda x: -x["matches"]),
        "last": row(ms[-1]),
        "form": [m.get("result") or "" for m in recent],
    }


# ── The builds ────────────────────────────────────────────────

BUILD_STATE = {"success": ("lyckades", "ok"), "failure": ("misslyckades", "fail"), "cancelled": ("avbröts", "off"),
               "skipped": ("hoppades över", "off"), "timed_out": ("tog för lång tid", "fail")}


def _stamp(text):
    try:
        return calendar.timegm(time.strptime(text, "%Y-%m-%dT%H:%M:%SZ"))
    except (TypeError, ValueError):
        return 0


def when_text(t):
    if not t:
        return ""
    lt, now = time.localtime(t), time.localtime()
    clock = time.strftime("%H:%M", lt)
    if lt[:3] == now[:3]:
        return f"i dag {clock}"
    if time.localtime(time.time() - 86400)[:3] == lt[:3]:
        return f"i går {clock}"
    return f"{day_text(t, False)} {clock}"


def builds(count=10, test_runs=None):
    """{builder, rows [{state, kind ok|fail|off|run, hash, sha, title, when, length, url}], ok, failed, running,
    last} – the image's builds; {"builder": False} for someone without the repo."""
    import buildstatus  # noqa: PLC0415
    if test_runs is None:
        if not buildstatus.builder():
            return {"builder": False}
        cache = _load(BUILD_CACHE)
        running = any(r.get("status") != "completed" for r in cache.get("runs") or [])
        if time.time() - cache.get("at", 0) < (BUILD_AGE_RUNNING if running else BUILD_AGE) and cache.get("runs"):
            runs = cache["runs"]
        else:
            try:
                runs = [{k: r.get(k) for k in ("id", "status", "conclusion", "head_sha", "display_title", "created_at",
                                               "run_started_at", "updated_at", "html_url", "event")}
                        for r in buildstatus.runs("build.yml", count)]
                _save(BUILD_CACHE, {"at": time.time(), "runs": runs})
            except Exception:  # noqa: BLE001 – no network, GitHub's hourly limit: the last ones we saw
                runs = cache.get("runs") or []
                if not runs:
                    return {"builder": True, "rows": [], "error": "GitHub svarade inte"}
    else:
        runs = test_runs
    rows = []
    for r in runs[:count]:
        done = r.get("status") == "completed"
        state, kind = BUILD_STATE.get(r.get("conclusion"), ("okänt", "off")) if done else ("pågår", "run")
        start = _stamp(r.get("run_started_at") or r.get("created_at"))
        end = _stamp(r.get("updated_at")) if done else time.time()
        title = r.get("display_title") or ""
        rows.append({"state": state, "kind": kind, "sha": r.get("head_sha") or "", "hash": (r.get("head_sha") or "")[:7],
                     "title": "Dagligt bygge" if r.get("event") == "schedule" else title,
                     "when": when_text(start), "length": span_text(end - start) if start else "",
                     "url": r.get("html_url") or "",
                     "id": str(r.get("id") or (r.get("html_url") or "").rstrip("/").rpartition("/")[2])})
    return {"builder": True, "rows": rows, "ok": sum(r["kind"] == "ok" for r in rows),
            "failed": sum(r["kind"] == "fail" for r in rows), "running": next((r for r in rows if r["kind"] == "run"), None),
            "last": rows[0] if rows else None, "url": f"https://github.com/{buildstatus.REPO}/actions/workflows/build.yml"}


STEP_NAMES = {"Hämta repot (hela historiken)": "Hämta repot", "Nyheternas commits": "Nyheterna",
              "BuildKit from Google's Docker Hub mirror": "Förbered byggverktyget",
              "Build Custom Image": "Bygg imagen (det stora steget, 10–15 min)",
              "PySide6 för QML-kollen": "Hämta Qt för kollen", "Kontrollen (tools/check.py)": "Kontrollen"}
STEP_HIDDEN = re.compile(r"^(Set up job|Complete job|Post |Run actions/)")


def _step_kind(status, conclusion):
    """✓ ok, ● run, ✗ fail, ○ wait (kvar), – off (hoppades över/avbröts)."""
    if status == "completed":
        return {"success": "ok", "failure": "fail", "timed_out": "fail"}.get(conclusion, "off")
    return "run" if status == "in_progress" else "wait"


def build_steps(run_id, test_jobs=None):
    """{id, done, jobs [{name, kind, length, steps [{name, kind}]}]} – what one build has done and what is left
    (GitHub's jobs: the check and one per variant). The image itself is one step on GitHub ("Build Custom Image");
    what goes on inside it is only in the log, after the variant is done."""
    if test_jobs is None:
        import buildstatus  # noqa: PLC0415
        try:
            jobs = buildstatus.get(f"/actions/runs/{int(run_id)}/jobs?per_page=30").get("jobs", [])
        except Exception:  # noqa: BLE001 – no network, GitHub's limit
            return {"id": str(run_id), "error": "GitHub svarade inte – försöker igen om 20 s"}
    else:
        jobs = test_jobs
    import buildstatus  # noqa: PLC0415 – variant(): "Build Custom Image (recipe-nvidia.yml, …)" → the variant's name
    out = []
    for j in jobs:
        name = j.get("name") or ""
        start = _stamp(j.get("started_at") or "")
        end = _stamp(j.get("completed_at") or "") if j.get("status") == "completed" else time.time()
        steps = [{"name": STEP_NAMES.get(s.get("name"), s.get("name") or ""), "kind": _step_kind(s.get("status"), s.get("conclusion"))}
                 for s in j.get("steps") or [] if not STEP_HIDDEN.match(s.get("name") or "")]
        out.append({"name": buildstatus.variant(name) if "recipe" in name else name,
                    "kind": _step_kind(j.get("status"), j.get("conclusion")),
                    "length": span_text(end - start) if start and j.get("status") != "queued" else "", "steps": steps})
    return {"id": str(run_id), "done": bool(out) and all(j["kind"] not in ("run", "wait") for j in out), "jobs": out}


# ── Kakan's reports ───────────────────────────────────────────

def reports(seen=0.0, count=20):
    """{rows [{path, title, when, new}], new} – the reports Kakan left for Claude, newest first."""
    import toclaude  # noqa: PLC0415
    rows = []
    for p in toclaude.reports()[:count]:
        try:
            mtime = p.stat().st_mtime
            head = p.read_text(encoding="utf-8", errors="replace")[:600]
        except OSError:
            continue
        title = next((line.lstrip("# ").strip() for line in head.splitlines() if line.strip()), p.stem)
        rows.append({"path": str(p), "title": title[:140], "when": when_text(mtime), "new": mtime > seen, "at": mtime})
    return {"rows": rows, "new": sum(r["new"] for r in rows)}


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "wow"
    result = {"wow": wow, "wow-fetch": lambda: wow(True), "cs2": cs2, "builds": builds, "reports": reports}.get(what)
    if not result:
        sys.exit(__doc__)
    print(json.dumps(result(), ensure_ascii=False, indent=1))
