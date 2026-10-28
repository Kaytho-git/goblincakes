"""Kakan's reminders and watches (point 7 of Kakan's plan, 28 Oct): "påminn mig 19:45 att …", "säg till när Steam
är klar", "kl 7: kolla vädret och säg till".

    python3 reminders.py run          the user service goblincakes-kakan-vakt: looks every 15 s
    python3 reminders.py remove <id>  Ångra for one Kakan added
    python3 reminders.py ask <id>     a question at its time (started by the service)

Kept in ~/.local/share/goblincakes/ai/vakt.json. The watches are checked without the AI (no GPU, no clash with the
game guard). The user's decision 28 Oct: reminders at a time show at once, also mid-game; "säg till när …" and
questions wait until the game is closed. A reminder whose time passed while the computer was off comes at login.
Only the standard library (+ goblinai for the questions)."""

import datetime as dt
import fcntl
import hashlib
import html
import json
import os
import re
import shlex
import subprocess
import sys
import threading
import time
import urllib.request
import uuid
from contextlib import contextmanager
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(1, str(HERE.parent))  # gaming.py

DATA = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share") / "goblincakes" / "ai"
STORE = DATA / "vakt.json"
LOOK = 15  # seconds between looks
PAGE_LOOK = 600  # a web page is fetched every 10 min
SNOOZE = 10  # minutes for "Om 10 min"
STEAM = "/usr/libexec/goblincakes-steam-activity"
PARTIAL = re.compile(r"\.(?:part|crdownload|download|partial|opdownload)$", re.I)  # Firefox, Chrome, Safari-likes, Opera
WATCH_NAMES = {"steam": "Steam är klar", "uppdatering": "uppdateringen är klar", "nedladdning": "nedladdningen är klar",
               "stängt": "{arg} är stängt", "startat": "{arg} har startat", "sida": "sidan {arg} ändras"}


# ── The store (the service and Goblin AI both write: one at a time) ─────────────

@contextmanager
def _locked():
    DATA.mkdir(parents=True, exist_ok=True)
    with (DATA / "vakt.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)


def load():
    try:
        items = json.loads(STORE.read_text())
    except (OSError, ValueError):
        return []
    return items if isinstance(items, list) else []


def _save(items):
    tmp = STORE.with_suffix(".tmp")
    tmp.write_text(json.dumps(items, ensure_ascii=False, indent=1))
    tmp.replace(STORE)


def _add(item):
    with _locked():
        items = load()
        items.append(item)
        _save(items)


def remove(item_id):
    with _locked():
        items = load()
        kept = [i for i in items if i["id"] != item_id]
        _save(kept)
    return "Borttagen." if len(kept) < len(items) else "Den fanns inte längre."


# ── When ────────────────────────────────────────────────────────────────────────

def parse_at(text):
    """A datetime from `19:45`, `om 20 min`, `om en timme`, `om 2 h`, `imorgon 8`, `fredag 18:30`, `4 nov 9`; a time
    alone = today, or tomorrow when it has passed; a day alone = 09:00. None when it can't be read."""
    import desktop  # noqa: PLC0415 – its parse_when reads the days (the calendar's)
    low = " ".join(text.lower().replace("kl.", " ").split())
    now = dt.datetime.now().replace(second=0, microsecond=0)
    m = re.fullmatch(r"(?:om|efter)?\s*(\d+(?:[.,]\d+)?|en|ett|en halv|halv)\s*(m|min\w*|h|t\w*|s\w*|d\w*)", low) \
        or re.fullmatch(r"om\s+(en|ett|en halv)\s+(timme|minut|dag)", low)
    if m:
        n = {"en": 1, "ett": 1, "en halv": 0.5, "halv": 0.5}.get(m.group(1)) or float(m.group(1).replace(",", "."))
        unit = m.group(2)[0]
        if unit == "s":  # seconds: try-outs only
            return dt.datetime.now() + dt.timedelta(seconds=n)
        return now + dt.timedelta(minutes=n * {"m": 1, "h": 60, "t": 60, "d": 1440}[unit])
    if low in ("om en halvtimme", "om halvtimme", "halvtimme"):
        return now + dt.timedelta(minutes=30)
    when, all_day = desktop.parse_when(low)
    if when is not None:
        return when.replace(hour=9) if all_day else when
    m = re.search(r"\b([01]?\d|2[0-3])(?:[:.]([0-5]\d))?\b", low)
    if not m:
        return None
    when = dt.datetime.combine(dt.date.today(), dt.time(int(m.group(1)), int(m.group(2) or 0)))
    return when if when > now else when + dt.timedelta(days=1)


def _fmt(when):
    today = dt.date.today()
    day = {today: "idag", today + dt.timedelta(days=1): "imorgon"}.get(when.date())
    if day is None:
        import desktop  # noqa: PLC0415
        return desktop._fmt_when(when, False)
    return f"{day} kl {when:%H:%M}"


# ── What the watches look at ────────────────────────────────────────────────────

def _cmdlines():
    out = []
    for p in Path("/proc").iterdir():
        if not p.name.isdigit() or int(p.name) == os.getpid():
            continue
        try:
            comm = (p / "comm").read_text().strip()
            args = (p / "cmdline").read_bytes().split(b"\0")
        except OSError:
            continue
        out.append((comm, [a.decode(errors="replace") for a in args if a]))
    return out


def running(name):
    """Is the program running? `spelet` = any game (gaming.py), `wow`, `cs2`, or a process name ("discord")."""
    import gaming  # noqa: PLC0415
    key = re.sub(r"[\s-]+", "", name.casefold())
    if key in ("spelet", "spel", "spelen", "game"):
        return gaming.game_running()
    if key in ("wow", "worldofwarcraft", "warcraft"):
        return any(gaming.WOW.match(comm) for comm, _ in _cmdlines())
    key = {"counterstrike": "cs2", "counterstrike2": "cs2", "goblinai": "goblin-ai", "battlenet": "battle.net"}.get(key, key)
    for comm, args in _cmdlines():
        names = {comm.casefold()} | ({Path(args[0]).name.casefold()} if args else set())
        if args[:1] and Path(args[0]).name.startswith("python") and len(args) > 1:
            names.add(Path(args[1]).name.casefold())  # our own windows: python3 /usr/bin/goblin-ai
        if any(key in re.sub(r"\.exe$", "", n) for n in names):
            return True
    return False


def steam_busy():
    """What Steam downloads or prepares ("Cyberpunk 2077 – laddar ner"), or "" when it is idle."""
    try:
        out = subprocess.run([STEAM], capture_output=True, text=True, timeout=10).stdout
        now = json.loads(out.strip().splitlines()[-1])
    except (OSError, subprocess.SubprocessError, ValueError, IndexError):
        return ""
    if not now.get("kind"):
        return ""
    return " – ".join(x for x in (now.get("name") or "", "shaders" if now["kind"] == "shader" else now.get("phase") or "") if x)


def update_busy():
    """A system update (rpm-ostree), Flatpak update or goblin update under way."""
    try:
        out = subprocess.run(["rpm-ostree", "status", "--json"], capture_output=True, text=True, timeout=20).stdout
        if json.loads(out).get("transaction"):
            return True
    except (OSError, subprocess.SubprocessError, ValueError):
        pass
    for comm, args in _cmdlines():
        if comm == "flatpak" and "update" in args:
            return True
        if comm == "goblin" and "update" in args:
            return True
    return False


def download_dir():
    try:
        out = subprocess.run(["xdg-user-dir", "DOWNLOAD"], capture_output=True, text=True, timeout=3).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        out = ""
    return Path(out) if out and out != str(Path.home()) else Path.home() / "Downloads"


def downloads():
    """The files a web browser is still downloading – written to the last 5 minutes (a stopped download's .part
    from 11 Oct lay there 17 days)."""
    try:
        return [f.name for f in download_dir().iterdir()
                if PARTIAL.search(f.name) and time.time() - f.stat().st_mtime < 300]
    except OSError:
        return []


def page_text(url):
    url = url if re.match(r"https?://", url) else "https://" + url
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) GOBLINCAKES"})
    with urllib.request.urlopen(req, timeout=20) as r:  # noqa: S310 – the user's own page
        raw = r.read(3_000_000).decode(r.headers.get_content_charset() or "utf-8", errors="replace")
    raw = re.sub(r"(?is)<(script|style|noscript)\b.*?</\1>", " ", raw)
    return " ".join(html.unescape(re.sub(r"<[^>]+>", " ", raw)).split())


def page_state(url, word):
    """(found, hash) – the word on the page, or the visible text's hash."""
    text = page_text(url)
    return (word.casefold() in text.casefold() if word else False), hashlib.sha1(text.encode()).hexdigest()


# ── Adding (from Goblin AI's ```skrivbord) ──────────────────────────────────────

def _log(code, said, item_id, conversation):
    import cmdlevel  # noqa: PLC0415
    cmdlevel.log(code, "change", "kakan", 0, said,
                 {"undo": [f"{shlex.quote(sys.executable)} {shlex.quote(str(Path(__file__).resolve()))} remove {item_id}"],
                  "hint": ""}, conversation)


def _new(kind, **fields):
    return {"id": f"vakt-{uuid.uuid4().hex[:12]}", "kind": kind, "made": time.time(), **fields}


def remind(rest, conversation=""):
    """`påminn <när> ; <text>`"""
    when_text, _, text = rest.partition(";")
    text = " ".join(text.split())[:300]
    if not text:
        when_text, text = _split_when(rest)
    when = parse_at(when_text)
    if when is None:
        return (f"Förstår inte när \"{when_text.strip()}\" är. Skriv t.ex. `påminn 19:45 ; ta ut tvätten`, "
                "`påminn om 20 min ; pizzan` eller `påminn imorgon 8 ; ring tandläkaren`.")
    if not text:
        return "Säg vad påminnelsen ska säga."
    item = _new("tid", at=when.timestamp(), text=text)
    _add(item)
    said = f"Påminner dig {_fmt(when)}: {text}"
    _log(f"påminnelse: {text} – {_fmt(when)}", said, item["id"], conversation)
    return said + " (notis med ljud, även mitt i ett spel)."


def _split_when(rest):
    """`19:45 ta ut tvätten` without the `;`: the time first, the rest is the text."""
    m = re.match(r"\s*((?:om\s+)?(?:\d+(?:[.,]\d+)?|en|ett|en halv)\s*(?:min\w*|h|timm\w*|tim|sek\w*|dag\w*)\b"
                 r"|(?:idag|imorgon|i morgon|övermorgon|måndag|tisdag|onsdag|torsdag|fredag|lördag|söndag)?\s*"
                 r"(?:kl\.?\s*)?\d{1,2}(?:[:.]\d{2})?)\s+(.+)$", rest, re.I)
    return (m.group(1), " ".join(m.group(2).split())[:300]) if m else (rest, "")


def watch(rest, conversation=""):
    """`bevaka steam|uppdatering|nedladdning|stängt <program>|startat <program>|sida <adress> [ord] [; text]`"""
    what, _, note = rest.partition(";")
    note = " ".join(note.split())[:200]
    word, _, arg = " ".join(what.split()).partition(" ")
    kind = {"steam": "steam", "uppdatering": "uppdatering", "uppdateringen": "uppdatering", "update": "uppdatering",
            "nedladdning": "nedladdning", "nedladdningen": "nedladdning", "download": "nedladdning",
            "stängt": "stängt", "stängd": "stängt", "stängs": "stängt", "slut": "stängt", "startat": "startat",
            "startar": "startat", "igång": "startat", "sida": "sida", "sidan": "sida", "webbsida": "sida"}.get(word.lower())
    item = _new(kind or "", note=note)
    if kind == "steam":
        busy = steam_busy()
        if not busy:
            return "Steam laddar inte ner något och bygger inga shaders just nu – inget att vänta på."
        item["arg"] = busy
        said = f"Säger till när Steam är klar ({busy})."
    elif kind == "uppdatering":
        if not update_busy():
            return "Ingen uppdatering pågår just nu (varken systemet, Flatpak eller goblin update)."
        said = "Säger till när uppdateringen är klar."
    elif kind == "nedladdning":
        files = downloads()
        if not files:
            return f"Inget laddas ner till {download_dir()} just nu."
        item.update(arg=", ".join(PARTIAL.sub("", f) for f in files[:3]), files=files)
        said = f"Säger till när nedladdningen är klar ({item['arg']})."
    elif kind in ("stängt", "startat"):
        if not arg:
            return f"Säg vilket program: `bevaka {kind} wow`."
        item["arg"] = arg
        on = running(arg)
        if kind == "stängt" and not on:
            return f"{arg} är inte igång just nu."
        if kind == "startat" and on:
            return f"{arg} är redan igång."
        said = f"Säger till när {arg} {'är stängt' if kind == 'stängt' else 'har startat'}."
    elif kind == "sida":
        url, _, look_for = arg.partition(" ")
        if not url:
            return "Säg vilken sida: `bevaka sida example.com [ord som ska dyka upp]`."
        try:
            found, digest = page_state(url, look_for.strip())
        except Exception as e:  # noqa: BLE001 – any network error: said as it is
            return f"Kommer inte åt {url}: {e}"
        if found:
            return f"\"{look_for.strip()}\" står redan på {url}."
        item.update(arg=url, word=look_for.strip(), hash=digest, looked=time.time())
        said = (f"Tittar på {url} var tionde minut och säger till när \"{look_for.strip()}\" dyker upp."
                if look_for.strip() else f"Tittar på {url} var tionde minut och säger till när sidan ändras.")
    else:
        return ("Det kan jag inte bevaka. Det går: `bevaka steam`, `bevaka uppdatering`, `bevaka nedladdning`, "
                "`bevaka stängt <program>`, `bevaka startat <program>`, `bevaka sida <adress> [ord]`.")
    _add(item)
    _log(f"bevakning: {what.strip()}", said, item["id"], conversation)
    return said + (" Under ett spel väntar notisen tills spelet är stängt." if kind != "startat" else "")


def question(rest, conversation=""):
    """`fråga <när> ; <frågan>` – Kakan answers herself at the time, and the answer comes as a notice."""
    when_text, _, text = rest.partition(";")
    text = " ".join(text.split())[:1000]
    if not text:
        when_text, text = _split_when(rest)
    when = parse_at(when_text)
    if when is None:
        return f"Förstår inte när \"{when_text.strip()}\" är. Skriv t.ex. `fråga imorgon 7 ; hur blir vädret i Malmö idag?`."
    if not text:
        return "Säg vad jag ska ta reda på."
    item = _new("fråga", at=when.timestamp(), text=text)
    _add(item)
    said = f"{_fmt(when)} tar jag reda på: {text} – svaret kommer som en notis och sparas som ett samtal"
    _log(f"fråga senare: {text} – {_fmt(when)}", said, item["id"], conversation)
    return said + " (väntar om ett spel kör)."


def _describe(item):
    if item["kind"] == "tid":
        return f"{_fmt(dt.datetime.fromtimestamp(item['at']))}: {item['text']}"
    if item["kind"] == "fråga":
        return f"{_fmt(dt.datetime.fromtimestamp(item['at']))}: tar reda på \"{item['text']}\""
    what = WATCH_NAMES[item["kind"]].format(arg=item.get("arg", ""))
    if item["kind"] == "sida" and item.get("word"):
        what = f"\"{item['word']}\" dyker upp på {item['arg']}"
    elif item["kind"] in ("steam", "nedladdning") and item.get("arg"):
        what += f" ({item['arg']})"
    return f"säg till när {what}" + (f" – {item['note']}" if item.get("note") else "")


def _ordered(items):
    return sorted(items, key=lambda i: (i.get("at") is None, i.get("at") or i["made"]))


def listing(rest="", conversation=""):
    """`påminnelser [bort <nr|ord|alla>]`"""
    word, _, arg = rest.strip().partition(" ")
    items = _ordered(load())
    if word.lower() in ("bort", "ta", "tabort", "radera", "ångra", "stäng", "glöm"):
        arg = re.sub(r"^bort\s+", "", arg.strip())
        if arg.lower() in ("alla", "allt"):
            gone = items
        elif arg.isdigit() and 1 <= int(arg) <= len(items):
            gone = [items[int(arg) - 1]]
        else:
            gone = [i for i in items if arg and arg.casefold() in _describe(i).casefold()]
        if not gone:
            return "Hittar ingen sådan – " + (listing() if items else "det finns inga påminnelser.")
        for i in gone:
            remove(i["id"])
        said = "Tog bort: " + "; ".join(_describe(i) for i in gone)
        import cmdlevel  # noqa: PLC0415
        cmdlevel.log("påminnelser bort " + arg, "change", "kakan", 0, said,
                     {"undo": [], "hint": "Säg till Kakan igen om du vill ha tillbaka den."}, conversation)
        return said
    if not items:
        return "Inga påminnelser eller bevakningar."
    return "Påminnelser och bevakningar:\n" + "\n".join(f"{n}. {_describe(i)}" for n, i in enumerate(items, 1))


def act(word, rest, conversation=""):
    """The ```skrivbord lines `påminn`, `bevaka`, `fråga` and `påminnelser`."""
    if word == "påminn":
        return remind(rest, conversation)
    if word == "bevaka":
        return watch(rest, conversation)
    if word == "fråga":
        return question(rest, conversation)
    return listing(rest, conversation)


# ── The service ─────────────────────────────────────────────────────────────────

def notice(title, body, critical=False, actions=(), on_action=None):
    """A notice from Goblin AI; with actions a thread waits for the click."""
    cmd = ["notify-send", "-a", "Goblin AI", "-i", "goblincakes-ai", "-h", "string:sound-name:message-new-instant"]
    if critical:
        cmd += ["-u", "critical"]
    for name, text in actions:
        cmd += ["-A", f"{name}={text}"]
    cmd += [title, body]
    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    except OSError:
        return
    if actions and on_action:
        threading.Thread(target=lambda: on_action(proc.communicate()[0].strip()), daemon=True).start()


def _snooze(text):
    def act_on(chosen):
        if chosen == "snooze":
            _add(_new("tid", at=time.time() + SNOOZE * 60, text=text))
    return act_on


def fire(item, late=False):
    if item["kind"] == "tid":
        when = dt.datetime.fromtimestamp(item["at"])
        body = item["text"] + (f"\n(skulle ha kommit {_fmt(when)})" if late else "")
        notice("Påminnelse", body, critical=True, actions=[("snooze", f"Om {SNOOZE} min")], on_action=_snooze(item["text"]))
    elif item["kind"] == "fråga":
        subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "ask", json.dumps(item)],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
    else:
        what = WATCH_NAMES[item["kind"]].format(arg=item.get("arg", ""))
        if item["kind"] == "sida":
            what = (f"\"{item['word']}\" finns nu på {item['arg']}" if item.get("word") else f"{item['arg']} har ändrats")
            notice("Säg till när …", what[:1].upper() + what[1:] + (f"\n{item['note']}" if item.get("note") else ""),
                   actions=[("open", "Öppna sidan")],
                   on_action=lambda c: c == "open" and subprocess.Popen(
                       ["xdg-open", item["arg"] if "://" in item["arg"] else "https://" + item["arg"]]))
            return
        if item["kind"] in ("steam", "nedladdning") and item.get("arg"):
            what += f" ({item['arg']})"
        notice("Säg till när …", what[:1].upper() + what[1:] + (f"\n{item['note']}" if item.get("note") else ""))


def due(item, gaming_now, now):
    """(fire?, changed fields) for one item."""
    kind = item["kind"]
    if kind == "tid":
        return now >= item["at"], {}
    if gaming_now:
        return False, {}  # the user's decision: the rest waits until the game is closed
    if kind == "fråga":
        return now >= item["at"], {}
    if kind == "steam":
        return not steam_busy(), {}
    if kind == "uppdatering":
        return not update_busy(), {}
    if kind == "nedladdning":
        folder = download_dir()
        return not any((folder / f).exists() for f in item.get("files", [])) and not downloads(), {}
    if kind == "stängt":
        return not running(item["arg"]), {}
    if kind == "startat":
        return running(item["arg"]), {}
    if kind == "sida":
        if now - item.get("looked", 0) < PAGE_LOOK:
            return False, {}
        try:
            found, digest = page_state(item["arg"], item.get("word", ""))
        except Exception:  # noqa: BLE001 – offline for a while: try again next time
            return False, {"looked": now}
        return (found if item.get("word") else digest != item.get("hash")), {"looked": now}
    return True, {}  # unknown kind (a newer version's): out of the way


def run():
    import gaming  # noqa: PLC0415
    started = time.time()
    while True:
        now = time.time()
        items = load()
        if items:
            gaming_now = gaming.game_running()
            gone, changed = [], {}
            for item in items:
                try:
                    hit, fields = due(item, gaming_now, now)
                except Exception:  # noqa: BLE001 – one broken watch must not stop the others
                    hit, fields = False, {}
                if hit:
                    gone.append(item)
                elif fields:
                    changed[item["id"]] = fields
            if gone or changed:
                with _locked():  # Goblin AI may have added one in between: only these ids are touched
                    fresh = load()
                    ids = {i["id"] for i in gone}
                    _save([{**i, **changed.get(i["id"], {})} for i in fresh if i["id"] not in ids])
                for item in gone:
                    fire(item, late=item["kind"] == "tid" and item["at"] < started - 60)
        nxt = min((i["at"] for i in load() if i["kind"] == "tid"), default=now + LOOK)
        time.sleep(max(1.0, min(LOOK, nxt - time.time() + 0.2)))


# ── A question at its time ──────────────────────────────────────────────────────

def ask(item):
    import goblinai  # noqa: PLC0415
    name = goblinai.ai_name() or "Goblin AI"
    asked = dt.datetime.fromtimestamp(item["made"])
    question_text = item["text"]
    messages = [{"role": "system", "content": goblinai.system_prompt()},
                {"role": "user", "content": question_text + f"\n\n(Användaren bad dig {asked:%-d/%-m kl %H:%M} ta reda på "
                 f"det här nu – nu är det {_fmt(dt.datetime.now())}. Svara kort – svaret visas som en notis.)"}]
    try:
        answer, service = goblinai.ask(messages, goblinai.load_keys(), choice=goblinai.chosen_model())
    except Exception as e:  # noqa: BLE001 – no service answered: said in the notice
        notice(f"{name} kunde inte svara", f"{question_text}\n{e}")
        return
    conv = time.strftime("%Y%m%d-%H%M%S")
    shown = [{"role": "user", "text": question_text, "segments": [], "service": "", "file": ""},
             {"role": "assistant", "text": answer, "segments": goblinai.segments(answer), "service": service, "file": "",
              "tools": goblinai.last_tools()}]
    data = {"id": conv, "title": " ".join(question_text.split())[:80], "updated": time.time(), "file": None,
            "cwd": str(Path.home()), "project": "", "display": shown,
            "api": [{"role": "user", "content": question_text}, {"role": "assistant", "content": answer}]}
    try:
        (DATA / f"{conv}.json").write_text(json.dumps(data, ensure_ascii=False))
    except OSError:
        pass
    plain = re.sub(r"```.*?```", " ", answer, flags=re.S)
    plain = re.sub(r"[*_`#>]|\[([^\]]*)\]\([^)]*\)", lambda m: m.group(1) or "", plain)
    plain = " ".join(plain.split())
    notice(f"{name}: {question_text[:60]}", plain[:280] + ("…" if len(plain) > 280 else ""),
           actions=[("open", "Öppna i Goblin AI")],
           on_action=lambda c: c == "open" and subprocess.Popen(["goblin-ai", "--open", conv], start_new_session=True))
    for t in threading.enumerate():  # the notice's thread waits for the click: keep the process until it is closed
        if t is not threading.main_thread():
            t.join()


if __name__ == "__main__":
    if sys.argv[1:2] == ["run"]:
        run()
    elif sys.argv[1:2] == ["remove"]:
        print(remove(sys.argv[2]))
    elif sys.argv[1:2] == ["ask"]:
        ask(json.loads(sys.argv[2]))
    else:
        print(act(sys.argv[1] if len(sys.argv) > 1 else "påminnelser", " ".join(sys.argv[2:])))
