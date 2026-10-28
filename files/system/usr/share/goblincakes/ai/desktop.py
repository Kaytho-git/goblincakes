"""Goblin AI's ```skrivbord tool (point 5 of Kakan's plan, 28 Oct): Kakan controls the desktop – the music, the
volume … The user's decision 28 Oct: music/volume, opening things, notices/clipboard, moving windows and starting
games run at once without a Tillåt card; closing windows needs Tillåt. Everything is logged under Körda kommandon
with how it is undone (by "kakan")."""

import json
import re
import shlex
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cmdlevel  # noqa: E402

MPRIS = "org.mpris.MediaPlayer2."
PLAYER = "org.mpris.MediaPlayer2.Player"
MUSIC_APPS = ("goblinamp", "spotify", "elisa", "strawberry", "audacious", "rhythmbox", "lollypop", "amberol",
              "clementine", "deadbeef", "tauon", "quodlibet", "cider", "tidal", "deezer", "youtube", "qmmp", "mpd")
SINK = "@DEFAULT_AUDIO_SINK@"


def _busctl(*args):
    try:
        out = subprocess.run(["busctl", "--user", "--json=short", *args], capture_output=True, text=True,
                             timeout=3).stdout
        return json.loads(out) if out.strip() else None
    except (OSError, ValueError, subprocess.SubprocessError):
        return None


def players():
    """[{name, app, status, title}] – music players first, then the playing ones."""
    found = []
    for n in _busctl("list") or []:
        name = n.get("name", "")
        if not name.startswith(MPRIS):
            continue
        app = name[len(MPRIS):].split(".")[0]
        status = (_busctl("get-property", name, "/org/mpris/MediaPlayer2", PLAYER, "PlaybackStatus") or {}).get("data")
        meta = (_busctl("get-property", name, "/org/mpris/MediaPlayer2", PLAYER, "Metadata") or {}).get("data") or {}
        title = (meta.get("xesam:title") or {}).get("data") or ""
        artists = (meta.get("xesam:artist") or {}).get("data") or []
        artist = ", ".join(artists) if isinstance(artists, list) else str(artists)
        found.append({"name": name, "app": app, "status": status or "Stopped",
                      "title": " – ".join(t for t in (artist, title) if t)})
    music = lambda p: any(a in p["app"].lower() for a in MUSIC_APPS)  # noqa: E731
    return sorted(found, key=lambda p: (p["status"] != "Playing", not music(p), p["status"] != "Paused"))


def _call(name, method):
    return f"busctl --user call {name} /org/mpris/MediaPlayer2 {PLAYER} {method}"


def _run(code):
    proc = subprocess.run(code, shell=True, capture_output=True, text=True, timeout=10)
    return proc.returncode, (proc.stdout + proc.stderr).strip()


def _done(code, undo, said, conversation="", hint=""):
    """Runs code, logs it with its undo (or a hint when there is none) and returns what the AI gets back."""
    try:
        exit_code, out = _run(code)
    except (OSError, subprocess.SubprocessError) as e:
        exit_code, out = 1, str(e)
    cmdlevel.log(code, "change", "kakan", exit_code, out, {"undo": undo, "hint": hint} if undo or hint else None,
                 conversation)
    return said if exit_code == 0 else f"Det gick inte: {out or 'fel ' + str(exit_code)}"


def _app_name(p):
    return {"goblinamp": "GoblinAmp", "spotify": "Spotify"}.get(p["app"].lower(), p["app"])


def music(what, conversation=""):
    """paus / spela / nästa / föregående / vad – on the music player that plays (or was paused last)."""
    what = what.lower().strip()
    found = players()
    if what in ("vad", "vilken", "spelas", "status", ""):
        if not found:
            return "Ingen musikspelare är igång."
        return "\n".join(f"{_app_name(p)}: {dict(Playing='spelar', Paused='pausad').get(p['status'], 'stoppad')}"
                         + (f" – {p['title']}" if p["title"] else "") for p in found)
    if not found:
        return "Ingen musikspelare är igång (starta GoblinAmp eller Spotify först)."
    playing = [p for p in found if p["status"] == "Playing"]
    if re.match(r"paus|stopp|tyst", what):
        if not playing:
            return "Ingen musik spelas just nu."
        return _done("\n".join(_call(p["name"], "Pause") for p in playing),
                     [_call(p["name"], "Play") for p in playing],
                     "Pausade " + ", ".join(_app_name(p) for p in playing) + ".", conversation)
    p = found[0]
    if re.match(r"spela|start|fortsätt|play", what):
        if playing:
            return f"{_app_name(p)} spelar redan" + (f": {p['title']}." if p["title"] else ".")
        return _done(_call(p["name"], "Play"), [_call(p["name"], "Pause")],
                     f"Spelar {_app_name(p)} igen" + (f": {p['title']}." if p["title"] else "."), conversation)
    if re.match(r"näst|nast|skip|hoppa", what):
        return _done(_call(p["name"], "Next"), [_call(p["name"], "Previous")], f"Nästa låt i {_app_name(p)}.",
                     conversation)
    if re.match(r"föreg|foreg|förra|tillbaka|prev", what):
        return _done(_call(p["name"], "Previous"), [_call(p["name"], "Next")], f"Förra låten i {_app_name(p)}.",
                     conversation)
    return "Okänt: säg paus, spela, nästa, föregående eller vad."


def volume_now():
    """(0–150 percent, muted) of the speakers/headset, or (None, False)."""
    try:
        out = subprocess.run(["wpctl", "get-volume", SINK], capture_output=True, text=True, timeout=3).stdout
    except (OSError, subprocess.SubprocessError):
        return None, False
    m = re.search(r"Volume:\s*([\d.]+)", out)
    return (round(float(m.group(1)) * 100) if m else None), "MUTED" in out


def _level(what, now):
    """The new level 0–100 from `40` / `+10` / `-10`, or None."""
    m = re.fullmatch(r"([+-]?)\s*(\d{1,3})", what)
    if not m:
        return None
    level = int(m.group(2))
    level = now + level if m.group(1) == "+" else now - level if m.group(1) == "-" else level
    return max(0, min(100, level))  # never louder than 100 % (hearing, the headset)


def find_player(name):
    """The MPRIS player a program name means: GoblinAmp = its own player, or the one it controls (Spotify);
    musiken = the one playing."""
    found = players()
    name = name.lower().strip()
    if not found:
        return None
    if name in ("goblinamp", "goblin amp", "musiken", "musik", "musikspelaren", "spelaren", "låten"):
        return next((p for p in found if p["app"].lower() == "goblinamp"), found[0])
    return next((p for p in found if name.replace(" ", "") in p["app"].lower()), None)


def player_volume(name, what, conversation=""):
    """The volume in a music player (GoblinAmp's slider = the player's MPRIS Volume), not the computer's."""
    p = find_player(name)
    if p is None:
        return f"Hittar ingen spelare som heter {name} (igång: " + (
            ", ".join(_app_name(q) for q in players()) or "ingen") + "). Starta den först."
    got = (_busctl("get-property", p["name"], "/org/mpris/MediaPlayer2", PLAYER, "Volume") or {}).get("data")
    if not isinstance(got, (int, float)):
        return f"{_app_name(p)} låter inte ändra sin volym."
    now = round(got * 100)
    if what in ("", "vad", "nu", "hur"):
        return f"Volymen i {_app_name(p)} är {now} %."
    level = 0 if re.match(r"tyst|av|mute|stäng", what) else _level(what, now)
    if level is None:
        return "Okänt: säg ett tal (40), +10, -10 eller tyst."
    if level == now:
        return f"Volymen i {_app_name(p)} är redan {now} %."
    set_to = lambda v: (f"busctl --user set-property {p['name']} /org/mpris/MediaPlayer2 {PLAYER} "  # noqa: E731
                        f"Volume d {v / 100:.2f}")
    return _done(set_to(level), [set_to(now)], f"Volymen i {_app_name(p)} {now} % → {level} %.", conversation)


def volume(what, conversation=""):
    """`40` / `+10` / `-10` / `tyst` / `ljud` / `` (= how loud now) – the computer's sound (speakers/headset);
    `… i <program>` = that music player's own volume (28 Oct: "öka till 80 % i GoblinAmp" turned the headset down)."""
    what = what.lower().replace("%", "").replace("procent", "").strip()
    what, _, program = (" " + what).partition(" i ")
    if not program and what.split(" ")[-1:] and not re.fullmatch(r"[+-]?\d+|tyst|av|ljud|på|vad|nu|hur|", what.split(" ")[-1]):
        what, _, program = what.rpartition(" ")  # `80 goblinamp`
    what, program = what.strip(), program.strip()
    if program:
        return player_volume(program, what, conversation)
    now, muted = volume_now()
    if now is None:
        return "Hittar ingen ljudutgång."
    if what in ("", "vad", "nu", "hur"):
        return f"Datorns volym är {now} %" + (" (ljudet avstängt)." if muted else ".")
    back = f"wpctl set-volume {SINK} {now / 100:.2f}"
    if re.match(r"tyst|av|mute|stäng", what):
        return _done(f"wpctl set-mute {SINK} 1", [f"wpctl set-mute {SINK} 0"], "Stängde av datorns ljud.", conversation)
    if re.match(r"ljud|på|unmute", what):
        return _done(f"wpctl set-mute {SINK} 0", [f"wpctl set-mute {SINK} 1"], f"Ljudet på igen ({now} %).",
                     conversation)
    level = _level(what, now)
    if level is None:
        return "Okänt: säg ett tal (40), +10, -10, tyst eller ljud."
    if level == now and not muted:
        return f"Datorns volym är redan {now} %."
    code = f"wpctl set-volume {SINK} {level / 100:.2f}" + (f"\nwpctl set-mute {SINK} 0" if muted else "")
    return _done(code, [back] + ([f"wpctl set-mute {SINK} 1"] if muted else []),
                 f"Datorns volym {now} % → {level} %.", conversation)


GAME_DELAY = 8  # seconds before a game starts: the game guard stops the local AI, so she answers first (28 Oct)
NOT_OPENED = re.compile(r"\.(?:desktop|sh|bash|py|appimage|exe|bat|run|bin)$", re.I)  # would run something


def _sys():
    import systools  # noqa: PLC0415
    return systools


def _detached(cmd, delay=0):
    """A shell line that starts cmd on its own (setsid, no output kept), after delay seconds."""
    inner = " ".join(shlex.quote(c) for c in cmd)
    if delay:
        inner = f"sleep {delay}; {inner}"
        return f"setsid -f sh -c {shlex.quote(inner)} >/dev/null 2>&1"
    return f"setsid -f {inner} >/dev/null 2>&1"


def is_game(app):
    _, _, stem, _, cats, _, _, exe = app
    return stem.startswith("goblincakes-game-") or "Game" in cats.split(";") and "steam://rungameid" in exe


def find_app(name):
    """(app, others): the menu program a name means – the whole name first, then the start of it, then a word
    in it, then its kind/keywords ("kalender" → Merkuro kalender). others = more that fit as well."""
    want = name.lower().strip()
    menu = _sys().menu_apps()
    if re.fullmatch(r"(?:min |mina )?(?:webbläsar\w*|browser|internet)", want):  # the main browser (Config)
        try:
            main = subprocess.run(["xdg-settings", "get", "default-web-browser"], capture_output=True, text=True,
                                  timeout=5).stdout.strip()
        except (OSError, subprocess.SubprocessError):
            main = ""
        if main in menu:
            return menu[main], []
    apps = [a for a in menu.values() if "goblin ai" not in a[0].lower()]
    for test in (lambda a: a[0].lower() == want or a[2].lower() == want,
                 lambda a: a[0].lower().startswith(want),
                 lambda a: re.search(rf"\b{re.escape(want)}", a[0].lower()),
                 lambda a: all(w in f"{a[1]} {a[2]} {a[5]}".lower() for w in want.split())):
        hits = sorted((a for a in apps if test(a)), key=lambda a: (a[3] == "webbapp", len(a[0])))
        if hits:
            return hits[0], hits[1:]
    return None, []


def open_thing(what, conversation=""):
    """A program from the menu, a web page or a file/folder – started on its own, nothing waits for it.
    Games start after GAME_DELAY seconds (the game guard stops the local AI when a game runs)."""
    what = what.strip().strip("\"'`")
    if not what:
        return "Säg vad som ska öppnas: ett program, en webbsida eller en fil/mapp."
    if re.match(r"https?://", what, re.I) or re.fullmatch(r"(?:www\.)?[\w-]+(?:\.[\w-]+)*\.[a-z]{2,}(?:/\S*)?", what, re.I):
        url = what if re.match(r"https?://", what, re.I) else "https://" + what
        return _done(_detached(["xdg-open", url]), [], f"Öppnade {url} i webbläsaren.", conversation,
                     "Stäng fliken själv om du inte vill ha den.")
    if what.startswith(("/", "~", "$HOME")):
        path = _sys().path_of(what)
        if not path.exists():
            return f"{path} finns inte. Leta med verktyget leta (hitta_filer) först."
        if not _sys().allowed(path):
            return "Den platsen är hemlig (nycklar/lösenord) – den öppnas inte."
        if path.is_file() and (NOT_OPENED.search(path.name) or path.stat().st_mode & 0o111):
            return f"{path.name} är ett program eller skript – det öppnas inte härifrån (då körs det)."
        kind = "mappen" if path.is_dir() else "filen"
        return _done(_detached(["xdg-open", str(path)]), [], f"Öppnade {kind} {path}.", conversation,
                     "Stäng fönstret själv om du inte vill ha det.")
    app, others = find_app(what)
    if app is None:
        return (f"Hittar inget program som heter {what}. Kolla namnen med verktyget program "
                "(eller säg en webbadress eller sökväg).")
    name, stem = app[0], app[2]
    also = (" (det finns också: " + ", ".join(o[0] for o in others[:4]) + ")") if others else ""
    if is_game(app):
        return _done(_detached(["gtk-launch", stem], GAME_DELAY), [],
                     f"{name} startar om {GAME_DELAY} sekunder.{also} Medan ett spel kör vilar den lokala AI:n.",
                     conversation, "Avsluta spelet själv.")
    return _done(_detached(["gtk-launch", stem]), [], f"Startade {name}.{also}", conversation,
                 "Stäng programmet själv om du inte vill ha det.")


def _spotify():
    """GoblinAmp's Spotify client (the same sign-in, ~/.config/goblincakes/spotify.json)."""
    here = Path(__file__).resolve().parent
    sys.path.insert(0, str(here.parent / "amp"))
    import spotifyweb  # noqa: PLC0415
    return spotifyweb


def _start_spotify_app():
    helper = Path("/usr/libexec/goblincakes-spotify-app")  # as GoblinAmp: Spotify hidden in the system tray
    if helper.exists():
        subprocess.run([str(helper)], capture_output=True, timeout=10)
    else:
        subprocess.Popen(["flatpak", "run", "com.spotify.Client"], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def _same(a, b):
    return re.sub(r"\W+", " ", a).strip().casefold() == re.sub(r"\W+", " ", b).strip().casefold()


def _best(items, title, artist):
    """The found item that is it: the exact title by the artist first, not a live/remix/deluxe version
    (unless asked for), else Spotify's own first."""
    def names(i):
        return [a.get("name", "") for a in i.get("artists") or []]
    extra = re.compile(r"\b(?:live|remix|remaster\w*|deluxe|acoustic|demo|instrumental|edit)\b", re.I)
    wanted_extra = bool(extra.search(title))
    good = [i for i in items if i and (not artist or any(_same(n, artist) for n in names(i)))] or [i for i in items if i]
    exact = [i for i in good if _same(i.get("name", ""), title)] if title else []
    plain = [i for i in (exact or good) if wanted_extra or not extra.search(
        i.get("name", "") + " " + (i.get("album") or {}).get("name", ""))]
    found = (plain or exact or good or [None])[0]
    return found, names(found) if found else []


def play(kind, what, conversation=""):
    """Plays a track, an album, an artist or a list on Spotify (the GoblinAmp window shows it) – `låt Lamb of God
    - Memento Mori`, `album Lamb of God - Lamb of God`, `artist Lamb of God`, or just words (the best track).
    28 Oct, the user's wish: "starta en låt i goblinamp, en specifik låt eller ett album"."""
    kind = {"låt": "track", "låten": "track", "album": "album", "albumet": "album", "skivan": "album",
            "artist": "artist", "artisten": "artist", "band": "artist", "bandet": "artist",
            "lista": "playlist", "listan": "playlist", "spellista": "playlist", "spellistan": "playlist"}.get(kind, "")
    what = what.strip().strip("\"'`")
    if not what:
        return "Säg vad som ska spelas: `låt <artist> - <titel>`, `album <artist> - <titel>` eller `artist <namn>`."
    artist, _, title = what.partition(" - ") if " - " in what else ("", "", what)
    artist, title = artist.strip(), title.strip()
    sw = _spotify()
    if not sw.load().get("refreshToken"):
        return ("GoblinAmp är inte inloggat på Spotify – logga in i GoblinAmp först (⋯ → Logga in). "
                "Egna musikfiler kan inte väljas härifrån än.")
    client = sw.Client()
    if kind == "artist" or (not kind and not title):
        kind, artist, title = "artist", artist or title, ""
    if not kind:
        kind = "track"
    field = {"track": "track", "album": "album", "playlist": ""}.get(kind, "")
    if kind == "artist":
        q = f'artist:"{artist}"'
    elif field and artist:
        q = f'{field}:"{title}" artist:"{artist}"'
    else:
        q = what
    try:
        page = client.get("/search", {"q": q, "type": kind, "limit": 10})
        items = (page.get(kind + "s") or {}).get("items") or []
        if not items and q != what:  # the fields found nothing (a typo, "feat.") – the words as they are
            items = (client.get("/search", {"q": what, "type": kind, "limit": 10}).get(kind + "s") or {}).get("items") or []
    except sw.SpotifyError as e:
        return f"Spotify svarade inte: {e}"
    if kind == "artist":
        found = next((i for i in items if i and _same(i.get("name", ""), artist)), items[0] if items else None)
        by = []
    else:
        found, by = _best(items, title, artist)
    if not found:
        return f"Hittar inget på Spotify för {what}. Fråga användaren om stavningen."
    label = {"track": "låten", "album": "albumet", "artist": "artisten", "playlist": "listan"}[kind]
    name = (", ".join(by) + " – " if by else "") + found.get("name", "")
    body = {"uris": [found["uri"]]} if kind == "track" else {"context_uri": found["uri"]}
    try:
        lib = sw.Library(client)
        device = lib.device(_start_spotify_app)
        client.request("PUT", "/me/player/play", {"device_id": device}, body)
    except sw.SpotifyError as e:
        return f"Det gick inte att spela: {e}"
    if not any(p["app"].lower() == "goblinamp" for p in players()) and not subprocess.run(
            ["pgrep", "-f", "bin/goblin-amp"], capture_output=True).stdout:
        subprocess.Popen(["gtk-launch", "goblin-amp"], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)  # "i GoblinAmp": the window too
    cmdlevel.log(f"spela {label} {name} ({found['uri']})", "change", "kakan", 0, "", {"undo": [], "hint":
                 "Byt låt själv i GoblinAmp eller Spotify."}, conversation)
    return f"Spelar {label} {name} på Spotify (syns i GoblinAmp)."


CLIP_SHOWN = 4000  # characters of the clipboard the AI gets
# One word of 8–100 characters with letters and digits/signs and no spaces = a password or key: not shown
SECRET_LIKE = re.compile(r"^(?!https?://|www\.|~?/)(?=.*[A-Za-z])(?=.*[\d\W_])\S{8,100}$")


def notify(text, conversation=""):
    """A notice now, from Goblin AI (at a time = reminders.py)."""
    text = " ".join(text.split())[:300]
    if not text:
        return "Säg vad notisen ska säga."
    title, _, body = text.partition(": ") if ": " in text[:60] else ("Goblin AI", "", text)
    code = " ".join(shlex.quote(c) for c in ["notify-send", "-a", "Goblin AI", "-i", "goblincakes-ai", title, body])
    return _done(code, [], f"Visade notisen: {text}", conversation, "En notis går inte att ta tillbaka – stäng den.")


def clipboard_text():
    try:
        out = subprocess.run(["wl-paste", "--no-newline", "--type", "text"], capture_output=True, timeout=3)
    except (OSError, subprocess.SubprocessError):
        return None
    return out.stdout.decode(errors="replace") if out.returncode == 0 else ""


def clipboard(what, conversation=""):
    """`vad` = what is on the clipboard (passwords and keys not shown); anything else = put that text there –
    the old clipboard is kept first, so Ångra puts it back."""
    if what.strip().lower() in ("", "vad", "visa", "läs"):
        now = clipboard_text()
        if now is None:
            return "Kommer inte åt urklippet."
        if not now.strip():
            return "Urklippet är tomt (eller har en bild, som inte visas här)."
        if SECRET_LIKE.match(now.strip()):
            return "Urklippet har något som ser ut som ett lösenord eller en nyckel – det visas inte."
        shown = "\n".join(_sys().hide(line) for line in now[:CLIP_SHOWN].splitlines())
        return f"I urklippet ({len(now)} tecken):\n{shown}" + ("\n[… avkortat]" if len(now) > CLIP_SHOWN else "")
    text = what.strip().strip("`")
    old = clipboard_text() or ""
    cmdlevel.BACKUPS.mkdir(parents=True, exist_ok=True)
    backup = cmdlevel.BACKUPS / f"urklipp-{time.time():.0f}.txt"
    backup.write_text(old)
    backup.chmod(0o600)
    # wl-copy stays in the background holding the clipboard – without its output, or nothing would end
    code = "printf %s " + shlex.quote(text) + " | wl-copy >/dev/null 2>&1"
    undo = [f"wl-copy < {shlex.quote(str(backup))} >/dev/null 2>&1" if old else "wl-copy --clear"]
    short = text if len(text) <= 80 else text[:77] + "…"
    return _done(code, undo, f"Lade \"{short}\" i urklippet – klistra in med Ctrl+V.", conversation)


# ── Windows (KWin, a script loaded for a moment – windows.js) ─────────────────

WIN_ACTIONS = {"fram": "fram", "fokus": "fram", "visa": "fram", "maximera": "maximera", "max": "maximera",
               "maximerad": "maximera", "stor": "maximera", "fullskärm": "fullskärm", "helskärm": "fullskärm",
               "fullscreen": "fullskärm", "minimera": "minimera", "göm": "minimera", "dölj": "minimera",
               "normal": "normal", "vanlig": "normal", "återställ": "normal", "stäng": "stäng", "close": "stäng",
               "avsluta": "avsluta", "helt": "avsluta", "quit": "avsluta", "döda": "avsluta"}
FILLER = {"till", "på", "den", "det", "och", "gör", "flytta", "skärmen", "skärm", "fönstret", "i", "in", "som"}


def screens():
    """[(number, connector, x)] – 1 = the main screen, then as in Systeminställningar (like goblin screen)."""
    try:
        outs = json.loads(subprocess.run(["kscreen-doctor", "-j"], capture_output=True, text=True,
                                         timeout=5).stdout).get("outputs") or []
    except (OSError, ValueError, subprocess.SubprocessError):
        return []
    outs = sorted((o for o in outs if o.get("enabled")), key=lambda o: o.get("priority") or 99)
    return [(i, o["name"], (o.get("pos") or {}).get("x", 0)) for i, o in enumerate(outs, 1)]


def screen_meant(word, now=""):
    """The connector a word means: 1/2/ett/två/första, vänster/höger, huvud, andra/annan (= the other one)."""
    found = screens()
    word = word.lower().strip()
    if not found or not word:
        return ""
    numbers = {"1": 1, "ett": 1, "en": 1, "ettan": 1, "första": 1, "huvud": 1, "huvudskärmen": 1,
               "2": 2, "två": 2, "tvåan": 2, "3": 3, "tre": 3, "trean": 3, "tredje": 3}
    if word in ("andra", "annan", "other", "nästa", "motsatta"):
        # The user, 28 Oct: "den andra skärmen" is always the screen the program is NOT on (with more than two:
        # the first other one in goblin screen's order)
        return next((c for _, c, _ in found if c != now), "")
    if word in numbers:
        return next((c for n, c, _ in found if n == numbers[word]), "")
    by_x = sorted(found, key=lambda f: f[2])
    if word.startswith("vänst"):
        return by_x[0][1]
    if word.startswith("hög"):
        return by_x[-1][1]
    return next((c for _, c, _ in found if c.lower() == word), "")


def _kwin(payload, timeout=4000):
    """Runs windows.js with the payload in a process of its own (Qt's D-Bus wants its own event loop);
    the script's report, or None."""
    try:
        out = subprocess.run([sys.executable, str(Path(__file__).resolve()), "--kwin"], input=json.dumps(payload),
                             capture_output=True, text=True, timeout=timeout / 1000 + 5)
        return json.loads(out.stdout) if out.stdout.strip() else None
    except (OSError, ValueError, subprocess.SubprocessError):
        return None


def _kwin_here(payload, timeout=4000):
    from PySide6.QtCore import ClassInfo, QCoreApplication, QEventLoop, QObject, QTimer, Slot  # noqa: PLC0415
    from PySide6.QtDBus import QDBusConnection  # noqa: PLC0415
    import os  # noqa: PLC0415
    app = QCoreApplication.instance() or QCoreApplication([])  # noqa: F841 – the event loop needs it
    service = f"org.goblincakes.win.p{os.getpid()}"
    result, loop = {}, QEventLoop()

    @ClassInfo({"D-Bus Interface": "org.goblincakes.win"})
    class Receiver(QObject):
        @Slot(str)
        def report(self, text):
            try:
                result["data"] = json.loads(text)
            except ValueError:
                pass
            loop.quit()

    receiver = Receiver()
    bus = QDBusConnection.sessionBus()
    if not bus.registerService(service):
        return None
    bus.registerObject("/win", receiver, QDBusConnection.ExportAllSlots)
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp")
    script = runtime / f"goblincakes-win-{os.getpid()}.js"
    script.write_text((Path(__file__).resolve().parent / "windows.js").read_text()
                      .replace("__DATA__", json.dumps(dict(payload, service=service))))
    name = f"goblincakes-win-{os.getpid()}"

    def kwin(*args):
        return subprocess.run(["busctl", "--user", "call", "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting",
                               *args], capture_output=True, text=True)
    try:
        if kwin("loadScript", "ss", str(script), name).returncode != 0:
            return None
        kwin("start")
        QTimer.singleShot(timeout, loop.quit)
        loop.exec(QEventLoop.AllEvents)
        return result.get("data")
    finally:
        kwin("unloadScript", "s", name)
        script.unlink(missing_ok=True)
        bus.unregisterService(service)


AMP_SOCKET = Path("/tmp") / f"goblin-amp-{__import__('os').getuid()}"  # GoblinAmp's QLocalServer


# Programs with their own way to end for good (they hide in the system tray on ✕): name → (process, command)
QUIT_WAYS = {"steam": ("steam", ["steam", "-shutdown"]),
             "spotify": ("spotify", ["busctl", "--user", "call", "org.mpris.MediaPlayer2.spotify",
                                     "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2", "Quit"]),
             "discord": ("Discord", None)}


def _pids(process):
    try:
        out = subprocess.run(["pgrep", "-x", process], capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return []
    return [int(x) for x in out.split()]


def _gone(pids, wait=6.0):
    end = time.time() + wait
    while time.time() < end:
        if not any(Path(f"/proc/{p}").exists() for p in pids):
            return True
        time.sleep(0.3)
    return False


def quit_program(win):
    """The program for good, also when it only lies in the system tray (28 Oct, the user: "stäng GoblinAmp helt
    eller Steam helt, så ska det stängas helt"): GoblinAmp through its own Stäng helt (with the Spotify app), Steam
    with steam -shutdown, Spotify with MPRIS Quit, others with TERM to the process (programs end as when the
    computer shuts down); KILL never."""
    import os  # noqa: PLC0415
    import signal  # noqa: PLC0415
    import socket  # noqa: PLC0415
    key = _squash(win.get("desktop") or win.get("app") or win.get("caption") or "")
    title = win.get("caption") or key
    if "goblinai" in key:
        return "Goblin AI avslutar inte sig själv – stäng fönstret med ✕."
    if "goblinamp" in key:
        pids = _pids("goblin-amp") or [int(x) for x in subprocess.run(
            ["pgrep", "-f", "bin/goblin-amp$"], capture_output=True, text=True).stdout.split()]
        if not pids:
            return "GoblinAmp är inte igång."
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
                sock.settimeout(2)
                sock.connect(str(AMP_SOCKET))
                sock.sendall(json.dumps({"quit": True}).encode())
        except OSError:
            pass
        if _gone(pids, 4):
            return "Avslutade GoblinAmp helt (och Spotify-appen)."
        title = "GoblinAmp"  # an older GoblinAmp without {"quit"}: TERM below
    else:
        pids = []
    for word, (process, command) in QUIT_WAYS.items():
        if word in key:
            pids = _pids(process)
            if not pids:
                return f"{word.capitalize()} är inte igång."
            if command:
                subprocess.Popen(command, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                if _gone(pids, 15):
                    return f"Avslutade {word.capitalize()} helt."
            title = word.capitalize()
            break
    if not pids:
        pid = int(win.get("pid") or 0)
        pids = [pid] if pid else _pids(win.get("app") or "") or _pids(key)
    pids = [p for p in pids if p != os.getpid() and Path(f"/proc/{p}").exists()]
    if not pids:
        return f"Hittar inget program som heter {title} – det är kanske redan avslutat."
    for pid in pids:
        try:
            os.kill(pid, signal.SIGTERM)
        except OSError:
            pass
    if _gone(pids, 6):
        return f"Avslutade {title} helt."
    return f"Bad {title} avsluta – det svarar inte än (kanske frågar det om att spara)."


def _screen_no(connector):
    return next((f"skärm {n}" for n, c, _ in screens() if c == connector), connector)


def _looks(state):
    return ("i fullskärm" if state.get("full") else "minimerat" if state.get("min") else
            "maximerat" if state.get("max") else "vanligt") + " på " + _screen_no(state.get("screen", ""))


def window(words, conversation="", allow_close=False):
    """`lista`, or `<program> [skärm <1|2|andra|vänster|höger>] [fram|maximera|fullskärm|minimera|normal|stäng]…`
    – several at once ("goblin ai skärm 2 fullskärm"). Closing only with Tillåt (a command card)."""
    text = words.strip().lower()
    if text in ("", "lista", "alla", "vilka"):
        got = _kwin({"mode": "list"})
        if got is None:
            return "Får inget svar från KWin (fönsterhanteraren)."
        return "Öppna fönster (överst först):\n" + "\n".join(
            f"- {w['caption']} ({w['desktop'] or w['app']}) – {_looks(w['state'])}" + (" – aktivt" if w["active"] else "")
            for w in got.get("windows") or [])
    tokens = re.findall(r"[\wåäö.+-]+", text)
    actions, screen_word, name = [], "", []
    i = 0
    while i < len(tokens):
        t = tokens[i]
        if t in WIN_ACTIONS:
            actions.append(WIN_ACTIONS[t])
        elif t in ("skärm", "skärmen") and i + 1 < len(tokens) and not screen_word:
            screen_word = tokens[i + 1]
            i += 1
        elif re.fullmatch(r"(?:vänstr|högr|andr|först|huvud)\w*", t) and i + 1 < len(tokens) and \
                tokens[i + 1].startswith("skärm"):
            screen_word = t
            i += 1
        elif t not in FILLER:
            name.append(t)
        i += 1
    if not name:
        return "Säg vilket program fönstret tillhör, t.ex. `fönster goblin ai skärm 2 fullskärm`."
    if "avsluta" in actions:  # "stäng helt": the program for good, not only its window (28 Oct, the user)
        actions = [a for a in actions if a != "stäng"] + (["stäng"] if "stäng" not in actions else [])
    closing = "avsluta" if "avsluta" in actions else "stäng" if "stäng" in actions else ""
    if closing and not allow_close:
        me = Path(__file__).resolve()
        what = ("Att avsluta ett program helt" if closing == "avsluta" else "Att stänga ett fönster")
        return (f"{what} kräver Tillåt (osparat kan försvinna). Svara med det här kodblocket så får användaren ett "
                f"Tillåt-kort:\n```bash\npython3 {me} fönster {' '.join(name)} {closing}\n```")
    if not actions and not screen_word:
        actions = ["fram"]
    got = _kwin({"mode": "find", "match": " ".join(name)})
    if got is None:
        return "Får inget svar från KWin (fönsterhanteraren)."
    if not got.get("before") and closing == "avsluta" and allow_close:
        return quit_program({"caption": " ".join(name), "desktop": " ".join(name)})  # in the tray only (Steam)
    if not got.get("before"):
        return (f"Hittar inget fönster för {' '.join(name)}. Öppna fönster: " + ", ".join(got.get("windows") or [])
                + ". (Starta programmet med öppna först.)")
    before = got["before"]
    target = screen_meant(screen_word, before["state"]["screen"]) if screen_word else ""
    if screen_word and not target:
        return f"Vet inte vilken skärm \"{screen_word}\" är. Skärmarna: " + ", ".join(
            f"skärm {n} ({c})" for n, c, _ in screens()) + "."
    if closing == "avsluta":  # only here from the Tillåt card
        return quit_program(before)
    if closing:  # only here from the Tillåt card (its run is logged as the card) – the same as ✕
        _kwin({"mode": "close", "id": before["id"]})
        return f"Stängde {before['caption']} (som ✕ – program med ikon i systemfältet kan ligga kvar där)."
    got = _kwin({"mode": "do", "match": " ".join(name), "actions": actions, "screen": target})
    if not got or not got.get("after"):
        return "KWin svarade inte – fönstret är kanske stängt."
    me = Path(__file__).resolve()
    undo = [f"{shlex.quote(sys.executable)} {shlex.quote(str(me))} --restore "
            + shlex.quote(json.dumps({"id": before["id"], "before": before["state"]}))]
    cmdlevel.log(f"fönster {' '.join(name)}: {' '.join(actions)}" + (f" → {_screen_no(target)}" if target else ""),
                 "change", "kakan", 0, "", {"undo": undo, "hint": ""}, conversation)
    time.sleep(0.3)  # KWin finishes full screen/the move after the script – what it looks like now
    after = (_kwin({"mode": "find", "match": " ".join(name)}) or {}).get("before") or got["after"]
    st = after["state"]
    note = (" Programmet går inte att maximera (fast storlek)." if "maximera" in actions and not st.get("max") else
            " Programmet går inte att visa i fullskärm." if "fullskärm" in actions and not st.get("full") else "")
    return f"{after['caption']}: nu {_looks(st)} (var {_looks(before['state'])}).{note}"


# ── Games and the goblin commands ─────────────────────────────────────────────

GAMES = "/usr/libexec/goblincakes-games"
ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")


def _squash(text):
    return re.sub(r"[^a-z0-9]+", "", text.lower())


def _games_module():
    """goblin play's own code (/usr/libexec/goblincakes-games): Steam's games and the user's words."""
    import importlib.machinery  # noqa: PLC0415
    import importlib.util  # noqa: PLC0415
    loader = importlib.machinery.SourceFileLoader("goblincakes_games", GAMES)
    module = importlib.util.module_from_spec(importlib.util.spec_from_loader(loader.name, loader))
    loader.exec_module(module)
    return module


def start_game(name, conversation=""):
    """A game by the user's own word (wow, cs2) or its name, through goblin play, after GAME_DELAY seconds."""
    try:
        gm = _games_module()
        all_games = gm.games()
    except Exception as e:  # noqa: BLE001 – no Steam, or goblin play missing
        return f"Kommer inte åt Steams spel: {e}"
    if _squash(name) in ("", "lista", "alla", "vilka"):
        own = gm.read_aliases()
        return "Spelen (ord du kan säga):\n" + "\n".join(
            f"- {n}: " + ", ".join(gm.words(n) + [w for w, g in own.items() if g == gid]) for n, gid in all_games)
    name = {"worldofwarcraft": "wow", "warcraft": "wow", "counterstrike": "cs2", "cs": "cs2"}.get(_squash(name), name)
    hits = gm.find(name, all_games) or [(n, g) for n, g in all_games if _squash(name) in _squash(n)]
    if not hits:
        app, _ = find_app(name)  # Battle.net, Lutris and other games in the menu
        if app and is_game(app):
            return open_thing(name, conversation)
        return f"Hittar inget spel som heter {name}. Spelen: " + ", ".join(n for n, _ in all_games) + "."
    if len(hits) > 1:
        return f"Flera spel passar {name}: " + ", ".join(n for n, _ in hits) + ". Fråga vilket."
    game, gameid = hits[0]
    return _done(_detached(["xdg-open", f"steam://rungameid/{gameid}"], GAME_DELAY), [],
                 f"{game} startar om {GAME_DELAY} sekunder. Medan ett spel kör vilar den lokala AI:n.",
                 conversation, "Avsluta spelet själv.")


def goblin(args, conversation=""):
    """A goblin command: the ones that only read run at once (nyheter, screen, tile layouts, frames …), window
    layouts too (`tile open <layout>` – moving windows needs no Tillåt); others become a Tillåt card."""
    args = args.strip()
    if args.startswith("goblin "):
        args = args[7:]
    words = args.split()
    if not words:
        return "Säg vilket goblin-kommando, t.ex. `goblin nyheter` (alla: `goblin help`)."
    if words[0] in ("play", "spel", "games") and len(words) == 2:
        return start_game(words[1], conversation)
    code = "goblin " + args
    layout = words[:2] == ["tile", "open"]
    if cmdlevel.level(code)[0] != "read" and not layout:
        return ("Det här ändrar något och kräver Tillåt. Svara med kodblocket så får användaren ett Tillåt-kort:\n"
                f"```bash\n{code}\n```")
    try:
        proc = subprocess.run(["goblin", *words], capture_output=True, text=True, timeout=60,
                              env={**__import__("os").environ, "NO_COLOR": "1", "TERM": "dumb"})
    except (OSError, subprocess.SubprocessError) as e:
        return f"Det gick inte: {e}"
    out = ANSI.sub("", proc.stdout + proc.stderr).strip()
    if layout:
        cmdlevel.log(code, "change", "kakan", proc.returncode, out, {"undo": [], "hint": "Flytta fönstren själv."},
                     conversation)
    return (out[-6000:] or "(skrev inget)") + ("" if proc.returncode == 0 else f"\n(slutade med fel {proc.returncode})")


# ── The calendar (Merkuro: Akonadi's "Personlig kalender" = an iCal file) ─────────

# Written straight into the file: Akonadi's file watcher reads it in by itself (and writes it back in its own
# form). Not its synchronize call – that wrote its old copy over the new event (28 Oct).
CAL_RESOURCE = "akonadi_ical_resource_0"
WEEKDAYS = ["måndag", "tisdag", "onsdag", "torsdag", "fredag", "lördag", "söndag"]
MONTHS = ["jan", "feb", "mar", "apr", "maj", "jun", "jul", "aug", "sep", "okt", "nov", "dec"]


def cal_file():
    """The calendar file Merkuro shows (akonadi_ical_resource_0rc's Path)."""
    import os  # noqa: PLC0415
    rc = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / f"{CAL_RESOURCE}rc"
    try:
        m = re.search(r"^Path(?:\[\$e\])?=(.+)$", rc.read_text(), re.M)
    except OSError:
        m = None
    path = os.path.expandvars(m.group(1).strip()) if m else "~/.local/share/apps/korganizer/std.ics"
    return Path(path).expanduser()


def parse_when(text):
    """(datetime, all_day) from `2026-11-04 23:59`, `4 nov 23:59`, `imorgon 19:00`, `fredag 20`, `idag kl 18.30`,
    a date alone = the whole day; or (None, False)."""
    import datetime as dt  # noqa: PLC0415
    text = text.lower().replace("kl.", " ").replace(" kl ", " ").strip()
    today = dt.date.today()
    day = None
    m = re.search(r"\b(\d{4})-(\d{1,2})-(\d{1,2})\b", text)
    if m:
        day = dt.date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
        text = text.replace(m.group(0), " ")
    if day is None:
        m = re.search(r"\b(\d{1,2})\s*(?:e\s+|:e\s+)?(" + "|".join(MONTHS) + r")\w*\b", text)
        if m:
            day = dt.date(today.year, MONTHS.index(m.group(2)) + 1, int(m.group(1)))
            if day < today:
                day = day.replace(year=today.year + 1)
            text = text.replace(m.group(0), " ")
    if day is None:
        m = re.search(r"\b(\d{1,2})/(\d{1,2})\b", text)  # 4/11 = 4 Nov
        if m:
            day = dt.date(today.year, int(m.group(2)), int(m.group(1)))
            if day < today:
                day = day.replace(year=today.year + 1)
            text = text.replace(m.group(0), " ")
    if day is None:
        if re.search(r"\bi\s*övermorgon\b|\bövermorgon\b", text):
            day = today + dt.timedelta(days=2)
        elif re.search(r"\bi\s*morgon\b|\bimorgon\b", text):
            day = today + dt.timedelta(days=1)
        elif re.search(r"\bi\s*dag\b|\bidag\b|\bikväll\b|\bi kväll\b", text):
            day = today
        else:
            for n, name in enumerate(WEEKDAYS):
                if re.search(rf"\b{name}", text):
                    ahead = (n - today.weekday()) % 7 or 7
                    day = today + dt.timedelta(days=ahead)
                    break
    if day is None:
        return None, False
    m = re.search(r"\b([01]?\d|2[0-3])(?:[:.]([0-5]\d))?\b", text)
    if not m:
        return dt.datetime.combine(day, dt.time()), True
    return dt.datetime.combine(day, dt.time(int(m.group(1)), int(m.group(2) or 0))), False


def parse_before(text):
    """Minutes before from `3 h`, `30 min`, `1 dag`, `2 timmar`, `en timme`; None = no reminder."""
    text = text.lower().replace("en ", "1 ").replace("ett ", "1 ").replace("halvtimme", "30 min").strip()
    if not text or text in ("ingen", "nej", "-"):
        return None
    if re.fullmatch(r"(?:vid start|när det börjar|0)", text):
        return 0
    m = re.match(r"(\d+(?:[.,]\d+)?)\s*(m|min\w*|h|t\w*|d\w*|v\w*)?", text)
    if not m:
        return None
    n = float(m.group(1).replace(",", "."))
    unit = (m.group(2) or "min")[0]
    return round(n * {"m": 1, "h": 60, "t": 60, "d": 1440, "v": 10080}[unit])


def _ics_text(value):
    return value.replace("\\", "\\\\").replace(";", "\\;").replace(",", "\\,").replace("\n", "\\n")


def _fmt_when(when, all_day):
    day = f"{WEEKDAYS[when.weekday()]} {when.day} {MONTHS[when.month - 1]} {when.year}"
    return day if all_day else f"{day} kl {when:%H:%M}"


def _fmt_before(minutes):
    if minutes == 0:
        return "när det börjar"
    if minutes % 1440 == 0:
        return f"{minutes // 1440} dag{'ar' if minutes // 1440 > 1 else ''} innan"
    if minutes % 60 == 0:
        return f"{minutes // 60} h innan"
    return f"{minutes} min innan"


def cal_add(title, when_text, before_text="", minutes=60, conversation=""):
    """An event in Merkuro's calendar, with a reminder – at once, logged, Ångra takes it away again
    (27 Oct, the user: "hon ska ju kunna göra det jag ber om" – the calendar needs no Tillåt)."""
    import datetime as dt  # noqa: PLC0415
    import uuid  # noqa: PLC0415
    title = " ".join(title.split())[:200]
    if not title:
        return "Säg vad händelsen heter."
    when, all_day = parse_when(when_text)
    if when is None:
        return (f"Förstår inte när \"{when_text}\" är. Säg ett datum och en tid, t.ex. `2026-11-04 23:59`, "
                "`4 nov 23:59` eller `imorgon 19:00`.")
    before = parse_before(before_text)
    path = cal_file()
    try:
        text = path.read_text()
    except OSError:
        return f"Hittar inte kalendern ({path}) – öppna Merkuro en gång så skapas den."
    if "END:VCALENDAR" not in text:
        return "Kalenderfilen ser konstig ut – inget ändrat."
    uid = f"goblin-ai-{uuid.uuid4()}"
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    if all_day:
        times = [f"DTSTART;VALUE=DATE:{when:%Y%m%d}", f"DTEND;VALUE=DATE:{when + dt.timedelta(days=1):%Y%m%d}"]
    else:
        start = when.astimezone(dt.timezone.utc)  # local time → UTC (no VTIMEZONE needed)
        times = [f"DTSTART:{start:%Y%m%dT%H%M%SZ}", f"DTEND:{start + dt.timedelta(minutes=minutes):%Y%m%dT%H%M%SZ}"]
    event = ["BEGIN:VEVENT", f"UID:{uid}", f"DTSTAMP:{stamp}", f"CREATED:{stamp}", *times,
             f"SUMMARY:{_ics_text(title)}", "X-GOBLINCAKES-By:Goblin AI"]
    if before is not None:
        event += ["BEGIN:VALARM", "ACTION:DISPLAY", f"DESCRIPTION:{_ics_text(title)}",
                  f"TRIGGER;RELATED=START:-PT{before}M", "END:VALARM"]
    event.append("END:VEVENT")
    new = text.replace("END:VCALENDAR", "\r\n".join(event) + "\r\nEND:VCALENDAR") if "\r\n" in text else \
        text.replace("END:VCALENDAR", "\n".join(event) + "\nEND:VCALENDAR")
    tmp = path.with_suffix(".goblin-ai.tmp")
    tmp.write_text(new)
    tmp.replace(path)
    me = Path(__file__).resolve()
    said = (f"Lade in \"{title}\" {_fmt_when(when, all_day)}"
            + (f", påminnelse {_fmt_before(before)}" if before is not None else ", utan påminnelse") + " i kalendern (Merkuro).")
    cmdlevel.log(f"kalender: {title} – {_fmt_when(when, all_day)}", "change", "kakan", 0, said,
                 {"undo": [f"{shlex.quote(sys.executable)} {shlex.quote(str(me))} --cal-remove {uid}"], "hint": ""},
                 conversation)
    return said


def cal_remove(uid):
    """Ångra: the event with this UID out of the file again."""
    path = cal_file()
    text = path.read_text()
    nl = "\r\n" if "\r\n" in text else "\n"
    blocks = re.split(r"(?=BEGIN:VEVENT)", text)
    kept = [b if f"UID:{uid}" not in b else re.sub(r"BEGIN:VEVENT.*?END:VEVENT" + re.escape(nl), "", b, flags=re.S)
            for b in blocks]
    tmp = path.with_suffix(".goblin-ai.tmp")
    tmp.write_text("".join(kept))
    tmp.replace(path)
    return "Händelsen är borttagen ur kalendern."


def _unfold(text):
    return re.sub(r"\r?\n[ \t]", "", text)


def cal_list(days_text=""):
    """What is in the calendar the coming days (14 if nothing is said) – read from the file."""
    import datetime as dt  # noqa: PLC0415
    m = re.search(r"\d+", days_text or "")
    days = int(m.group(0)) if m else 14
    try:
        text = _unfold(cal_file().read_text())
    except OSError:
        return "Hittar ingen kalender."
    now = dt.datetime.now().astimezone()
    end = now + dt.timedelta(days=days)
    found = []
    for block in re.findall(r"BEGIN:VEVENT(.*?)END:VEVENT", text, re.S):
        title = (re.search(r"^SUMMARY[^:]*:(.*)$", block, re.M) or [None, ""])[1].replace("\\,", ",").replace("\\;", ";")
        start = re.search(r"^DTSTART([^:]*):(\d{8})(?:T(\d{6})(Z?))?", block, re.M)
        if not start:
            continue
        d = dt.datetime.strptime(start.group(2) + (start.group(3) or "000000"), "%Y%m%d%H%M%S")
        all_day = start.group(3) is None
        d = d.replace(tzinfo=dt.timezone.utc).astimezone() if start.group(4) else d.astimezone()
        if "RRULE" in block:
            title += " (upprepas)"
        if now - dt.timedelta(days=1) <= d <= end or "RRULE" in block:
            alarm = re.search(r"TRIGGER[^:]*:-?P(?:T)?(\d+)([MHDW])", block)
            note = ""
            if alarm:
                mins = int(alarm.group(1)) * {"M": 1, "H": 60, "D": 1440, "W": 10080}[alarm.group(2)]
                note = f" – påminnelse {_fmt_before(mins)}"
            found.append((d, f"- {_fmt_when(d, all_day)}: {title}{note}"))
    if not found:
        return f"Inget i kalendern de närmaste {days} dagarna."
    return f"I kalendern de närmaste {days} dagarna:\n" + "\n".join(line for _, line in sorted(found))


def calendar(rest, conversation=""):
    """`kalender visa [dagar]` or `kalender lägg <när> ; <titel> ; <påminnelse>`."""
    word, _, args = rest.strip().partition(" ")
    if word.lower() in ("lägg", "lagg", "ny", "add", "boka"):
        parts = [x.strip() for x in args.split(";")]
        if len(parts) < 2:
            return "Skriv: kalender lägg <när> ; <titel> ; <påminnelse> (t.ex. `kalender lägg 4 nov 23:59 ; WoW Forever ; 3 h`)."
        return cal_add(parts[1], parts[0], parts[2] if len(parts) > 2 else "", conversation=conversation)
    return cal_list(args if word.lower() in ("visa", "vad", "lista") else rest)


def act(line, conversation=""):
    """The tool's line: `musik <paus|spela|nästa|föregående|vad>`, `volym <tal|+10|-10|tyst|ljud> [i <program>]`,
    `öppna <program|webbadress|sökväg>`."""
    word, _, rest = line.strip().partition(" ")
    word = word.lower()
    if word in ("musik", "music", "låt"):
        return music(rest, conversation)
    if word in ("volym", "volume", "ljud"):
        return volume(rest, conversation)
    if word in ("öppna", "oppna", "open", "starta", "start"):
        return open_thing(rest, conversation)
    if word in ("kalender", "kalendern", "calendar"):
        return calendar(rest, conversation)
    if word in ("påminn", "paminn", "påminnelse", "remind", "bevaka", "watch", "fråga", "fraga",
                "påminnelser", "paminnelser", "bevakningar"):
        import reminders  # noqa: PLC0415 – point 7 (28 Oct)
        word = {"paminn": "påminn", "påminnelse": "påminn", "remind": "påminn", "watch": "bevaka",
                "fraga": "fråga"}.get(word, word)
        return reminders.act(word, rest, conversation)
    if word in ("spel", "game"):
        return start_game(rest, conversation)
    if word == "goblin":
        return goblin(rest, conversation)
    if word in ("fönster", "fonster", "window"):
        return window(rest, conversation)
    if word in ("notis", "notify"):
        return notify(rest, conversation)
    if word in ("urklipp", "urklippet", "clipboard"):
        return clipboard(rest, conversation)
    if word in ("spela", "play"):
        kind, _, what = rest.strip().partition(" ")
        if kind.lower() in ("låt", "låten", "album", "albumet", "skivan", "artist", "artisten", "band", "bandet",
                            "lista", "listan", "spellista", "spellistan"):
            return play(kind.lower(), what, conversation)
        return play("", rest, conversation)
    return ("Okänd rad. Raderna: musik paus|spela|nästa|föregående|vad, volym 40|+10|-10|tyst|ljud [i goblinamp|spotify], "
            "öppna <program|webbadress|sökväg>, spela låt|album|artist <artist> - <titel>, notis <text>, "
            "urklipp <text|vad>, fönster <program> [skärm 2] [fram|maximera|fullskärm|minimera|normal], "
            "spel <namn|lista>, goblin <kommando>, kalender visa [dagar], kalender lägg <när> ; <titel> ; <påminnelse>, "
            "påminn <när> ; <text>, bevaka <steam|uppdatering|nedladdning|stängt X|startat X|sida X|bygge [commit]> [; text], "
            "fråga <när> ; <frågan>, påminnelser [bort <nr>].")


if __name__ == "__main__":  # trying it out: python3 desktop.py musik vad
    if sys.argv[1:2] == ["--kwin"]:  # _kwin's own process
        print(json.dumps(_kwin_here(json.loads(sys.stdin.read())) or {}))
    elif sys.argv[1:2] == ["--cal-remove"]:  # Ångra for a calendar event
        print(cal_remove(sys.argv[2]))
    elif sys.argv[1:2] == ["--restore"]:  # Ångra for a window
        data = json.loads(sys.argv[2])
        got = _kwin({"mode": "restore", "id": data["id"], "before": data["before"]})
        print("Fönstret är tillbaka." if got and got.get("after") else "Fönstret finns inte längre.")
    elif sys.argv[1:2] in (["fönster"], ["fonster"]) and sys.argv[-1] in ("stäng", "avsluta"):  # the Tillåt card
        print(window(" ".join(sys.argv[2:]), allow_close=True))
    else:
        print(act(" ".join(sys.argv[1:])))
