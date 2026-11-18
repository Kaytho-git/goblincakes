"""GOBLINCAKES Dashboard – Blizzard's own WoW API (18 Nov, the user: "Bygg det" – the character in the middle, PvP and
the frame WOW-LÄGET; not the auction house). Only reads, needs a free API client of the user's own (develop.battle.net,
Client ID + Secret, client credentials – no Battle.net login), saved in ~/.config/goblincakes/blizzard.json (0600),
never in the repo or the image. Idea from github.com/yourdawi/homeassistant-wow-blizzard (MIT) – no code taken.

    python3 blizzard.py status | set (JSON {clientId, clientSecret} on stdin) | forget
    python3 blizzard.py char <name> <realm> <region> | world <region> <realm> [realm …] | refresh

char()     one character: profile (level, ilvl, guild, spec), the picture (render, kept as a file), Mythic+ this season
           (score, best run per dungeon), raid progress of the newest expansion, PvP (rating per bracket, honor level).
           Retail first; a character Retail doesn't know is asked for in WoW Forever's namespace.
world()    WoW-LÄGET: the token's price, the weekly reset (worked out here, not from the API) and the realms' status.
refresh()  for the dashboard: the characters of WoW Stats (stats.wow()) + the realms – each part only when its
           time is up (characters 30 min, the token and realms 10 min), kept in ~/.cache/goblincakes/dashboard-blizzard.json.
"""
import base64
import calendar
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "goblincakes"
KEY_FILE = CONFIG / "blizzard.json"
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "goblincakes"
CACHE = CACHE_DIR / "dashboard-blizzard.json"
PICTURES = CACHE_DIR / "blizzard"
CLIENTS_PAGE = "https://develop.battle.net/access/clients"
SHOP = "https://shop.battle.net/family/world-of-warcraft"
CHAR_AGE = 30 * 60
WORLD_AGE = 10 * 60
# Tests only: another server in place of Blizzard's (both the token and the API)
FAKE = os.environ.get("GOBLINCAKES_BLIZZARD_URL", "").rstrip("/")
FAILED_AGE = 5 * 60       # no network / Blizzard down: try again after this
LOCALE = {"eu": "en_GB", "us": "en_US", "kr": "ko_KR", "tw": "zh_TW"}
# The weekly reset (UTC weekday 0 = Monday, hour) – the API has no answer for it: EU Wednesday 04:00, US Tuesday 15:00
# (KR/TW not checked: treated as EU)
RESET = {"eu": (2, 4), "us": (1, 15)}
FLAVORS = (("retail", "profile-{r}", "Retail"), ("forever", "profile-forever-{r}", "Forever"))


class BlizzardError(RuntimeError):
    pass


# ── The key ──────────────────────────────────────────────────

def load_key():
    try:
        data = json.loads(KEY_FILE.read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def save_key(data):
    CONFIG.mkdir(parents=True, exist_ok=True)
    tmp = KEY_FILE.with_suffix(".tmp")
    tmp.touch(mode=0o600)
    os.chmod(tmp, 0o600)
    tmp.write_text(json.dumps(data, indent=1))
    tmp.replace(KEY_FILE)


def configured():
    d = load_key()
    return bool(d.get("clientId") and d.get("clientSecret"))


def token(data=None, force=False):
    data = data or load_key()
    if not data.get("clientId") or not data.get("clientSecret"):
        raise BlizzardError("Ingen Blizzard-nyckel inlagd (Config → Dashboard)")
    if not force and data.get("accessToken") and time.time() < data.get("expires", 0):
        return data["accessToken"]
    auth = base64.b64encode(f"{data['clientId']}:{data['clientSecret']}".encode()).decode()
    req = urllib.request.Request((FAKE or "https://oauth.battle.net") + "/token",
                                 data=urllib.parse.urlencode({"grant_type": "client_credentials"}).encode(),
                                 headers={"Authorization": "Basic " + auth, "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            tok = json.loads(r.read())
    except urllib.error.HTTPError as e:
        raise BlizzardError("Fel Client ID eller Secret" if e.code in (400, 401) else f"Blizzard svarade {e.code}") from e
    except (OSError, ValueError) as e:
        raise BlizzardError("Kom inte fram till Blizzard – nätet?") from e
    data.update({"accessToken": tok["access_token"], "expires": time.time() + int(tok.get("expires_in", 3600)) - 120})
    save_key(data)
    return data["accessToken"]


def set_key(client_id, secret):
    """Save and try the API client – raises BlizzardError with a readable text when it does not work."""
    data = {"clientId": (client_id or "").strip(), "clientSecret": (secret or "").strip()}
    if len(data["clientId"]) < 10 or len(data["clientSecret"]) < 10:
        raise BlizzardError("Klistra in både Client ID och Client Secret")
    token(data, force=True)


def forget():
    for f in (KEY_FILE, CACHE):
        try:
            f.unlink()
        except OSError:
            pass


# ── Asking ───────────────────────────────────────────────────

def api(region, path, namespace, retry=True):
    """GET https://<region>.api.blizzard.com<path> – the answer as a dict; None for 404 (no such character)."""
    region = region.lower()
    query = urllib.parse.urlencode({"namespace": namespace, "locale": LOCALE.get(region, "en_GB")})
    url = path if path.startswith(("https://", "http://")) else f"{FAKE or f'https://{region}.api.blizzard.com'}{path}"
    url += ("&" if "?" in url else "?") + query
    req = urllib.request.Request(url, headers={"Authorization": "Bearer " + token(), "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        if e.code == 401 and retry:          # the token ran out early
            token(force=True)
            return api(region, path, namespace, retry=False)
        if e.code == 429 and retry:          # 100 a second / 36 000 an hour – wait a moment, once
            time.sleep(1.5)
            return api(region, path, namespace, retry=False)
        raise BlizzardError(f"Blizzard svarade {e.code}") from e
    except (OSError, ValueError) as e:
        raise BlizzardError("Kom inte fram till Blizzard – nätet?") from e


def _name(x):
    """A name in the answer – a text, or {"en_GB": …} without locale."""
    if isinstance(x, dict):
        return x.get("name") if "name" in x else next(iter(x.values()), "")
    return x or ""


def slug(realm):
    """A realm as WoW Stats has it ("TwistingNether", "Al'Akir", "Twisting Nether") → Blizzard's slug."""
    import re  # noqa: PLC0415
    realm = re.sub(r"(?<=[a-z])(?=[A-Z])", "-", realm or "").replace("'", "")
    return re.sub(r"[^a-z0-9-]", "", realm.lower().replace(" ", "-"))


def _color(c):
    """Blizzard's {r, g, b} (0–255, or 0–1) → "#RRGGBB"."""
    try:
        vals = [float(c[k]) for k in ("r", "g", "b")]
    except (KeyError, TypeError, ValueError):
        return ""
    if all(v <= 1 for v in vals):
        vals = [v * 255 for v in vals]
    return "#" + "".join(f"{round(min(255, max(0, v))):02X}" for v in vals)


# ── A character ──────────────────────────────────────────────

def picture(url, key):
    """The render saved as a file (asked again only when Blizzard's address changes) – its path, or ""."""
    if not url:
        return ""
    PICTURES.mkdir(parents=True, exist_ok=True)
    out = PICTURES / (slug(key) + (os.path.splitext(urllib.parse.urlparse(url).path)[1] or ".jpg"))
    mark = out.with_suffix(out.suffix + ".url")
    try:
        if out.exists() and mark.read_text() == url:
            return str(out)
    except OSError:
        pass
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "GOBLINCAKES"}), timeout=20) as r:
            data = r.read(8_000_000)
        tmp = out.with_suffix(".part")
        tmp.write_bytes(data)
        tmp.replace(out)
        mark.write_text(url)
        return str(out)
    except OSError:
        return str(out) if out.exists() else ""


def _mythic(region, base, ns):
    """Mythic+ this season: {score, color, best [{dungeon, level, timed, rating, stars}], top}."""
    seasons = api(region, "/data/wow/mythic-keystone/season/index", "dynamic-" + region) or {}
    season = (seasons.get("current_season") or {}).get("id")
    prof = api(region, f"{base}/mythic-keystone-profile/season/{season}", ns) if season else None
    if not prof:
        prof = api(region, f"{base}/mythic-keystone-profile", ns) or {}
        runs = (prof.get("current_period") or {}).get("best_runs") or []
        rating = prof.get("current_mythic_rating") or {}
    else:
        runs = prof.get("best_runs") or []
        rating = prof.get("mythic_rating") or {}
    best = {}
    for run in runs:
        name = _name(run.get("dungeon"))
        level = int(run.get("keystone_level") or 0)
        timed = bool(run.get("is_completed_within_time"))
        score = float((run.get("mythic_rating") or {}).get("rating") or 0)
        had = best.get(name)
        if not had or score > had["rating"]:
            best[name] = {"dungeon": name, "level": level, "timed": timed, "rating": round(score, 1),
                          "stars": "★" * int(run.get("keystone_upgrades") or (1 if timed else 0))}
    rows = sorted(best.values(), key=lambda b: -b["rating"])
    timed = [b["level"] for b in rows if b["timed"]]
    return {"score": round(float(rating.get("rating") or 0)) if rating else None, "color": _color(rating.get("color") or {}),
            "best": rows, "top": max(timed) if timed else None}


def _raids(region, base, ns):
    """The newest expansion's raids: [{name, modes [{name, done, total}]}] – the newest raid first, at most 3."""
    data = api(region, f"{base}/encounters/raids", ns) or {}
    expansions = data.get("expansions") or []
    if not expansions:
        return []
    newest = max(expansions, key=lambda e: (e.get("expansion") or {}).get("id") or 0)
    order = {"LFR": 0, "NORMAL": 1, "HEROIC": 2, "MYTHIC": 3}
    out = []
    for inst in reversed(newest.get("instances") or []):
        modes = []
        for m in inst.get("modes") or []:
            diff = (m.get("difficulty") or {}).get("type") or ""
            prog = m.get("progress") or {}
            modes.append({"name": _name((m.get("difficulty") or {}).get("name")) or diff.title(), "kind": diff,
                          "done": int(prog.get("completed_count") or 0), "total": int(prog.get("total_count") or 0)})
        modes.sort(key=lambda m: order.get(m["kind"], 9))
        if modes:
            out.append({"name": _name(inst.get("instance")), "modes": modes})
    return out[:3]


BRACKETS = {"2v2": "2v2", "3v3": "3v3", "rbg": "RBG"}


def _pvp(region, base, ns):
    """{honor, rows [{name, rating, won, played}]} – only the brackets played this season."""
    summary = api(region, f"{base}/pvp-summary", ns) or {}
    rows = []
    for b in (summary.get("brackets") or [])[:8]:
        href = b.get("href") or ""
        kind = href.rsplit("/pvp-bracket/", 1)[-1].split("?")[0]
        name = BRACKETS.get(kind) or ("Solo Shuffle" if kind.startswith("shuffle") else
                                      "Blitz" if kind.startswith("blitz") else kind)
        try:
            data = api(region, href.split("?")[0], ns) or {}
        except BlizzardError:
            continue
        stats = data.get("season_match_statistics") or {}
        if data.get("rating") is None:
            continue
        rows.append({"name": name, "rating": int(data["rating"]), "won": int(stats.get("won") or 0),
                     "played": int(stats.get("played") or 0)})
    rows.sort(key=lambda r: -r["rating"])
    return {"honor": summary.get("honor_level"), "rows": rows}


def char(name, realm, region):
    """Everything about one character, or {"missing": True} when neither Retail nor Forever knows it."""
    region = (region or "eu").lower()
    base = f"/profile/wow/character/{slug(realm)}/{urllib.parse.quote(name.lower())}"
    for flavor, pattern, label in FLAVORS:
        ns = pattern.format(r=region)
        prof = api(region, base, ns)
        if prof:
            break
    else:
        return {"missing": True, "at": time.time()}
    out = {
        "flavor": flavor, "game": label, "level": prof.get("level"),
        "ilvl": prof.get("equipped_item_level") or prof.get("average_item_level"),
        "guild": _name(prof.get("guild")), "class": _name(prof.get("character_class")),
        "spec": _name(prof.get("active_spec")), "race": _name(prof.get("race")),
        "realmName": _name(prof.get("realm")), "achievements": prof.get("achievement_points"),
        "lastLogin": int((prof.get("last_login_timestamp") or 0) / 1000),
        "armory": f"https://worldofwarcraft.blizzard.com/character/{region}/{slug(realm)}/{name.lower()}",
        "at": time.time(),
    }
    parts = (("picture", lambda: _media(region, base, ns, f"{region}-{realm}-{name}")),
             ("mplus", lambda: _mythic(region, base, ns)), ("raids", lambda: _raids(region, base, ns)),
             ("pvp", lambda: _pvp(region, base, ns)))
    for key, fn in parts:           # one part failing (Forever has no Mythic+ score, …) leaves the others
        try:
            out[key] = fn()
        except BlizzardError:
            out[key] = None
    return out


def _media(region, base, ns, key):
    media = api(region, f"{base}/character-media", ns) or {}
    assets = {a.get("key"): a.get("value") for a in media.get("assets") or []}
    return picture(assets.get("main-raw") or assets.get("main") or assets.get("inset") or "", key)


# ── WoW-LÄGET ────────────────────────────────────────────────

def next_reset(region, now=None):
    """Seconds until the weekly reset."""
    now = time.time() if now is None else now
    day, hour = RESET.get(region.lower(), RESET["eu"])
    t = time.gmtime(now)
    start = calendar.timegm((t.tm_year, t.tm_mon, t.tm_mday, hour, 0, 0)) + (day - t.tm_wday) * 86400
    while start <= now:
        start += 7 * 86400
    return int(start - now)


def reset_text(seconds):
    d, h, m = seconds // 86400, seconds % 86400 // 3600, seconds % 3600 // 60
    return f"{d} d {h} h" if d else f"{h} h {m} min" if h else f"{m} min"


POPULATION = {"FULL": "full", "HIGH": "många spelare", "MEDIUM": "medel", "LOW": "få spelare", "NEW": "ny",
              "RECOMMENDED": "rekommenderad", "LOCKED": "låst"}


def realm_status(region, realm):
    data = api(region, f"/data/wow/realm/{slug(realm)}", "dynamic-" + region)
    if not data:
        return {"name": realm, "up": None, "text": "okänd realm"}
    connected = api(region, (data.get("connected_realm") or {}).get("href", "").split("?")[0], "dynamic-" + region) or {}
    up = (connected.get("status") or {}).get("type") == "UP"
    queue = bool(connected.get("has_queue"))
    pop = POPULATION.get((connected.get("population") or {}).get("type") or "", "")
    return {"name": _name(data.get("name")) or realm, "up": up,
            "text": ("Online" if up else "Nere") + (" · kö" if queue else " · ingen kö" if up else "") + (f" · {pop}" if pop else "")}


def world(region, realms):
    region = (region or "eu").lower()
    out = {"region": region.upper(), "reset": next_reset(region), "at": time.time(), "shop": SHOP}
    try:
        tok = api(region, "/data/wow/token/index", "dynamic-" + region) or {}
        out["token"] = int(tok.get("price") or 0) // 10000 or None
        out["tokenAt"] = int((tok.get("last_updated_timestamp") or 0) / 1000)
    except BlizzardError as e:
        out["token"], out["why"] = None, str(e)
    rows = []
    for realm in list(dict.fromkeys(realms))[:4]:
        try:
            rows.append(realm_status(region, realm))
        except BlizzardError:
            rows.append({"name": realm, "up": None, "text": "fick inget svar"})
    out["realms"] = rows
    return out


# ── For the dashboard ────────────────────────────────────────

def _load_cache():
    try:
        data = json.loads(CACHE.read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def _save_cache(data):
    try:
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        tmp = CACHE.with_suffix(".tmp")
        tmp.write_text(json.dumps(data, ensure_ascii=False))
        tmp.replace(CACHE)
    except OSError:
        pass


def cached():
    """What the dashboard shows at once: {configured, chars {player: …}, world} – nothing is asked."""
    data = _load_cache()
    return {"configured": configured(), "chars": data.get("chars") or {}, "world": data.get("world") or {}}


def refresh(players, want_world=True, now=None):
    """players = WoW Stats' [{player, name, realm, region}] (the last played first, at most 3 are asked). Asks
    Blizzard only for what is due; returns cached() afterwards."""
    if not configured():
        return cached()
    now = time.time() if now is None else now
    data = _load_cache()
    chars = data.get("chars") or {}
    changed = False
    for p in [p for p in players if p.get("region")][:3]:
        had = chars.get(p["player"]) or {}
        age = FAILED_AGE if had.get("failed") else CHAR_AGE
        if had and now - had.get("at", 0) < age:
            continue
        try:
            chars[p["player"]] = char(p["name"], p["realm"], p["region"])
        except BlizzardError as e:
            chars[p["player"]] = dict(had, failed=str(e), at=now)
        changed = True
    if want_world and players:
        w = data.get("world") or {}
        if now - w.get("at", 0) >= (FAILED_AGE if w.get("why") else WORLD_AGE):
            region = next((p["region"] for p in players if p.get("region")), "eu")
            # Retail's realms only (WoW Forever's realms are not in Retail's dynamic namespace)
            realms = [p["realm"] for p in players if p.get("realm") and p.get("region") == region
                      and (chars.get(p["player"]) or {}).get("flavor", "retail") == "retail"]
            try:
                data["world"] = world(region, realms)
            except BlizzardError as e:
                data["world"] = dict(w, why=str(e), at=now)
            changed = True
    if changed:
        data["chars"] = {k: v for k, v in chars.items() if k in {p["player"] for p in players} or now - v.get("at", 0) < 86400 * 7}
        _save_cache(data)
    out = cached()
    if out["world"].get("reset") is not None:        # the reset counts down between the questions
        out["world"] = dict(out["world"], reset=next_reset(out["world"].get("region", "eu"), now))
    if out["world"]:
        out["world"]["resetText"] = reset_text(out["world"]["reset"])
    return out


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "status"
    try:
        if what == "status":
            result = {"configured": configured(), "clients": CLIENTS_PAGE}
        elif what == "set":
            d = json.loads(sys.stdin.read() or "{}")
            set_key(d.get("clientId"), d.get("clientSecret"))
            result = {"ok": True, "configured": True}
        elif what == "forget":
            forget()
            result = {"ok": True, "configured": False}
        elif what == "char" and len(sys.argv) >= 5:
            result = char(sys.argv[2], sys.argv[3], sys.argv[4])
        elif what == "world" and len(sys.argv) >= 3:
            result = world(sys.argv[2], sys.argv[3:])
        elif what == "refresh":
            sys.path.insert(0, str(Path(__file__).resolve().parent))
            import stats  # noqa: PLC0415
            result = refresh(stats.wow().get("players") or [])
        else:
            sys.exit(__doc__)
    except BlizzardError as e:
        result = {"ok": False, "why": str(e), "configured": configured()}
    print(json.dumps(result, ensure_ascii=False, indent=1))
