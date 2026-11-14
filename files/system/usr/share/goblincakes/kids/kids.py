"""GOBLINCAKES Barnläge – the settings, the games and programs, the PIN code and the locks (13 Nov, the user's wish:
a sandbox started in one's own session when the son, 3, wants to play – his games and nothing else).

Shared by the window (/usr/bin/goblin-kids) and Config → BARNLÄGE (goblincakes-config). Only the standard library;
the KWin and D-Bus parts are busctl/kwriteconfig6 calls, so `goblin-kids --restore` works without a window.

    ~/.config/goblincakes/kids.json        {"items": [{"kind": "steam"|"app", "id", "name"}], "pin": "pbkdf2$…",
                                            "volume": 0|40|60|80, "background": "<id>"}
    ~/.local/share/goblincakes/kids/bilder the parent's pictures (Config copies them here)
    ~/.cache/goblincakes/kids/             the games' cover pictures and the sounds
    ~/.local/state/goblincakes/kids-active.json  while Barnläge is on: what to put back (also after a crash)

Steam games start through goblincakes-games (run-id, like goblin play); programs from their menu entry.
"""
import hashlib
import importlib.machinery
import importlib.util
import json
import math
import os
import re
import secrets
import shlex
import struct
import subprocess
import sys
import tempfile
import time
import urllib.request
import wave
from pathlib import Path

HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config") / "goblincakes/kids.json"
DATA = Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local/share") / "goblincakes/kids"
PICTURES = DATA / "bilder"
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or HOME / ".cache") / "goblincakes/kids"
STATE = Path(os.environ.get("XDG_STATE_HOME") or HOME / ".local/state") / "goblincakes/kids-active.json"
HERE = Path(__file__).resolve().parent
USR = HERE.parents[2]                          # /usr, or the repo's files/system/usr
GAMES = Path(os.environ.get("GOBLINCAKES_KIDS_GAMES") or USR / "libexec/goblincakes-games")
DASH = HERE.parent / "dashboard/dash.py"
KWIN_SCRIPT = "goblincakes-kids"
RULE = "goblincakes-kids"                      # kwinrulesrc group: no global shortcuts in any window
VOLUMES = (0, 40, 60, 80)                       # 0 = no cap
BUILTIN = [{"id": "natt", "name": "Natthimmel"}, {"id": "hav", "name": "Havet"},
           {"id": "regnbage", "name": "Regnbåge"}, {"id": "solnedgang", "name": "Solnedgång"}]
# Tux Paint started for a small child: whole screen, no printing. Its own quit button stays (13 Nov): with --noquit
# there was no way out of it at all (Alt+F4 is blocked in Barnläge) – quitting it takes him back to his games.
TUXPAINT_ARGS = ["--fullscreen=native", "--noprint"]   # 0.9.35: --fullscreen needs a value (13 Nov: it did not start)
TUXPAINT_SAVED = [HOME / ".tuxpaint/saved", HOME / ".var/app/org.tuxpaint.Tuxpaint/.tuxpaint/saved",
                  HOME / ".var/app/org.tuxpaint.Tuxpaint/data/tuxpaint/saved"]
PICTURE_TYPES = (".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif")


# ───────────────────────────────────────────── settings
def load_raw():
    try:
        data = json.loads(CONFIG.read_text())
    except (OSError, ValueError):
        data = {}
    return data if isinstance(data, dict) else {}


def load():
    """The settings; keys this version doesn't know (e.g. "chatterbox", namnljud.py) are kept."""
    data = load_raw()
    items = [i for i in data.get("items") or [] if isinstance(i, dict) and i.get("kind") in ("steam", "app") and i.get("id")]
    volume = data.get("volume") if data.get("volume") in VOLUMES else 80   # 80 % on master (the user 13 Nov)
    return dict(data, items=items, pin=str(data.get("pin") or ""), volume=volume,
                background=str(data.get("background") or "natt"), music=data.get("music") is not False,
                pixelart=data.get("pixelart") is not False)   # 14 Nov: Kakan's pixel art; "pixelart": false = drawn as before


def save(settings):
    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    tmp = CONFIG.with_name(CONFIG.name + ".new")
    tmp.write_text(json.dumps(settings, ensure_ascii=False, indent=1))
    os.chmod(tmp, 0o600)
    os.replace(tmp, CONFIG)


def update(**changes):
    settings = load()
    settings.update(changes)
    save(settings)
    return settings


# ───────────────────────────────────────────── the PIN code (never stored as it is)
def pin_ok_format(pin):
    return bool(re.fullmatch(r"\d{4,8}", pin or ""))


def _hash(pin, salt, rounds):
    return hashlib.pbkdf2_hmac("sha256", pin.encode(), bytes.fromhex(salt), rounds).hex()


def set_pin(pin):
    if not pin_ok_format(pin):
        return False
    salt, rounds = secrets.token_hex(16), 200000
    update(pin=f"pbkdf2${rounds}${salt}${_hash(pin, salt, rounds)}")
    return True


def check_pin(pin, stored=None):
    stored = load()["pin"] if stored is None else stored
    try:
        _, rounds, salt, digest = stored.split("$")
        return secrets.compare_digest(_hash(pin or "", salt, int(rounds)), digest)
    except (ValueError, TypeError):
        return False


# ───────────────────────────────────────────── games and programs
def _module(path, name):
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


_games_module = None


def games_module():
    global _games_module
    if _games_module is None:
        _games_module = _module(GAMES, "goblincakes_games")
    return _games_module


def steam_games():
    try:
        return [{"kind": "steam", "id": gid, "name": name} for name, gid in games_module().games()]
    except Exception:  # noqa: BLE001 – no Steam, or a broken file: no games
        return []


def programs():
    try:
        dash = _module(DASH, "goblincakes_dash")
        apps = dash.apps()
    except Exception:  # noqa: BLE001
        return []
    skip = ("steam.desktop", "goblin-kids.desktop")
    return [{"kind": "app", "id": a["id"], "name": a["name"], "icon": a.get("icon") or "", "path": a.get("path") or "",
             "group": a.get("group") or ""} for a in apps if a["id"] not in skip]


def available():
    """Everything that can be put in Barnläge: Steam's games first, then the programs."""
    return steam_games() + programs()


def _desktop_file(app_id):
    try:
        dash = _module(DASH, "goblincakes_dash")
        folders = dash.DATA_DIRS
    except Exception:  # noqa: BLE001
        folders = [Path("/usr/share/applications"), Path("/var/lib/flatpak/exports/share/applications"),
                   HOME / ".local/share/flatpak/exports/share/applications", HOME / ".local/share/applications"]
    for folder in reversed(folders):       # the home folder's copy wins, as in the menu
        f = Path(folder) / app_id
        if f.is_file():
            return f
    return None


def _entry(app_id):
    f = _desktop_file(app_id)
    try:
        text = f.read_text(errors="replace").split("\n[Desktop Action", 1)[0] if f else ""
    except OSError:
        text = ""

    def field(key):
        m = re.search(rf"^{key}=(.+)$", text, re.M)
        return m.group(1).strip() if m else ""
    return {"exec": field("Exec"), "icon": field("Icon"), "wmclass": field("StartupWMClass"), "name": field("Name")}


def is_tuxpaint(app_id):
    return "tuxpaint" in app_id.lower()


def command(app_id):
    """The program's command from its menu entry, without %f/%U and Flatpak's @@ markers (+ Tux Paint's options)."""
    exe = _entry(app_id)["exec"]
    try:
        parts = shlex.split(exe)
    except ValueError:
        return []
    parts = [p for p in parts if not re.fullmatch(r"%[a-zA-Z]|@@[a-z]?", p)]
    if parts and is_tuxpaint(app_id):
        parts += TUXPAINT_ARGS
    return parts


def window_names(item):
    """Lower-case names KWin may give the program's windows (desktop file, class, command) – allowed in Barnläge."""
    if item["kind"] == "steam":
        return [f"steam_app_{item['id']}"]
    stem = item["id"][:-8] if item["id"].endswith(".desktop") else item["id"]
    names = {stem.lower(), stem.lower().rsplit(".", 1)[-1]}
    entry = _entry(item["id"])
    if entry["wmclass"]:
        names.add(entry["wmclass"].lower())
    parts = command(item["id"])
    for p in parts:
        if p.startswith("--command="):
            names.add(Path(p.split("=", 1)[1]).name.lower())
    if parts and Path(parts[0]).name != "flatpak":
        names.add(Path(parts[0]).name.lower())
    if is_tuxpaint(item["id"]):
        names.add("tuxpaint")
    return sorted(n for n in names if n and n not in ("env", "flatpak", "sh", "bash"))


def steam_running():
    return subprocess.run(["pgrep", "-u", str(os.getuid()), "-x", "steam"], capture_output=True).returncode == 0


def start_steam_quietly():
    """Steam in the background before a game is chosen, so its window never shows (GOBLINCAKES' steam.desktop:
    the same environment as when you start it yourself)."""
    if steam_running():
        return
    for f in (HOME / ".local/share/applications/steam.desktop", Path("/usr/share/applications/steam.desktop")):
        try:
            m = re.search(r"^Exec=(.+)$", f.read_text(errors="replace"), re.M)
        except OSError:
            continue
        if m:
            try:
                parts = [p for p in shlex.split(m.group(1)) if not re.fullmatch(r"%[a-zA-Z]", p)]
            except ValueError:
                continue
            subprocess.Popen(parts + ["-silent"], start_new_session=True,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return


def launch(item):
    if item["kind"] == "steam":
        args = [str(GAMES), "run-id", item["id"], "--kids"]
    else:
        args = command(item["id"])
    if not args:
        return False
    try:
        subprocess.Popen(args, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        return False
    return True


# ───────────────────────────────────────────── pictures: the games' covers
COVER_CDN = ("https://cdn.cloudflare.steamstatic.com/steam/apps/{}/library_600x900_2x.jpg",
             "https://cdn.cloudflare.steamstatic.com/steam/apps/{}/library_600x900.jpg")


def cover(appid, download=True):
    """Steam's tall cover picture for the game (the one in the library): Steam's own cache, ours, or Steam's CDN."""
    own = CACHE / "omslag" / f"{appid}.jpg"
    if own.is_file():
        return str(own)
    try:
        roots = games_module().steam_roots()
    except Exception:  # noqa: BLE001
        roots = []
    for root in roots:
        cache = root / "appcache/librarycache"
        found = sorted(cache.glob(f"{appid}/**/library_600x900*.jpg")) + sorted(cache.glob(f"{appid}_library_600x900*.jpg"))
        if found:
            return str(found[-1])
    if download and appid.isdigit() and len(appid) < 10:   # non-Steam games added to Steam have no cover there
        for url in COVER_CDN:
            try:
                with urllib.request.urlopen(url.format(appid), timeout=8) as reply:
                    data = reply.read()
            except OSError:
                continue
            if data[:3] == b"\xff\xd8\xff":
                own.parent.mkdir(parents=True, exist_ok=True)
                own.write_bytes(data)
                return str(own)
    try:
        icon = games_module().game_icon(appid) if download else None
    except Exception:  # noqa: BLE001
        icon = None
    return icon or ""


def picture_for(item, download=True):
    """{"cover": path} for a Steam game, {"icon": theme name or path} for a program."""
    if item["kind"] == "steam":
        return {"cover": cover(item["id"], download), "icon": ""}
    return {"cover": "", "icon": _entry(item["id"])["icon"] or "application-x-executable"}


# ───────────────────────────────────────────── backgrounds
def pictures():
    if not PICTURES.is_dir():
        return []
    return [str(p) for p in sorted(PICTURES.iterdir(), key=lambda p: p.stat().st_mtime) if p.suffix.lower() in PICTURE_TYPES]


def drawings(most=24):
    """His own drawings from Tux Paint (newest first; not the thumbnails)."""
    found = []
    for folder in TUXPAINT_SAVED:
        if folder.is_dir():
            found += [p for p in folder.glob("*.png") if not p.stem.endswith("-t")]
    found.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return [str(p) for p in found[:most]]


def backgrounds():
    out = [{"id": b["id"], "kind": "builtin", "name": b["name"]} for b in BUILTIN]
    out += [{"id": p, "kind": "picture", "name": Path(p).stem} for p in pictures()]
    out += [{"id": p, "kind": "drawing", "name": Path(p).stem} for p in drawings()]
    return out


def add_pictures(paths):
    PICTURES.mkdir(parents=True, exist_ok=True)
    added = 0
    for p in paths:
        src = Path(p)
        if not src.is_file() or src.suffix.lower() not in PICTURE_TYPES:
            continue
        dest = PICTURES / src.name
        n = 2
        while dest.exists():
            dest = PICTURES / f"{src.stem}-{n}{src.suffix.lower()}"
            n += 1
        dest.write_bytes(src.read_bytes())
        added += 1
    return added


def remove_picture(path):
    p = Path(path)
    if p.parent == PICTURES and p.is_file():
        p.unlink()
        if load()["background"] == str(p):
            update(background="natt")
        return True
    return False


# ───────────────────────────────────────────── Steam's overlay (per game, in Steam's localconfig.vdf)
def _vdf_parse(text):
    """Steam's text VDF → [(key, value)], value a string or such a list (order and doubles kept)."""
    tokens = [q[1:-1] if q else b for q, b in re.findall(r'("(?:\\.|[^"\\])*")|([{}])|//[^\n]*', text) if q or b]
    pos = 0

    def block():
        nonlocal pos
        out = []
        while pos < len(tokens):
            key = tokens[pos]
            pos += 1
            if key == "}":
                return out
            if key == "{" or pos >= len(tokens):
                continue
            value = tokens[pos]
            pos += 1
            out.append((key, block() if value == "{" else value))
        return out
    return block()


def _vdf_dump(pairs, depth=0):
    tab = "\t" * depth
    lines = []
    for key, value in pairs:
        if isinstance(value, list):
            lines += [f'{tab}"{key}"', f"{tab}{{", _vdf_dump(value, depth + 1), f"{tab}}}"] if value else \
                     [f'{tab}"{key}"', f"{tab}{{", f"{tab}}}"]
        else:
            lines.append(f'{tab}"{key}"\t\t"{value}"')
    return "\n".join(l for l in lines if l != "")


def _get(pairs, key):
    for k, v in pairs:
        if k.lower() == key.lower():
            return v
    return None


def _localconfigs():
    try:
        roots = games_module().steam_roots()
    except Exception:  # noqa: BLE001
        roots = []
    files = []
    for root in roots:
        files += list((root / "userdata").glob("*/config/localconfig.vdf"))
    return sorted(files, key=lambda f: f.stat().st_mtime, reverse=True)


def overlay_on(appid):
    """True/False = Steam's overlay is on/off for the game (Steam's newest account), None = not known."""
    for f in _localconfigs()[:1]:
        try:
            root = _get(_vdf_parse(f.read_text(errors="replace")), "UserLocalConfigStore")
        except OSError:
            return None
        apps = _get(root, "apps") if isinstance(root, list) else None
        game = _get(apps, appid) if isinstance(apps, list) else None
        value = _get(game, "OverlayAppEnable") if isinstance(game, list) else None
        return value != "0"
    return None


def overlay_off(appid):
    """Turns Steam's overlay off for the game in localconfig.vdf (a copy is kept next to it). Only while Steam
    is closed – Steam writes the file over when it quits. Returns "" or why not."""
    if steam_running():
        return "Steam är igång. Stäng Steam först, eller gör det i Steam: spelet → Egenskaper → Allmänt."
    files = _localconfigs()
    if not files:
        return "Hittar inga Steam-inställningar."
    for f in files:
        text = f.read_text(errors="replace")
        pairs = _vdf_parse(text)
        root = _get(pairs, "UserLocalConfigStore")
        if not isinstance(root, list):
            continue
        apps = _get(root, "apps")
        if not isinstance(apps, list):
            apps = []
            root.append(("apps", apps))
        game = _get(apps, appid)
        if not isinstance(game, list):
            game = []
            apps.append((appid, game))
        for n, (k, _) in enumerate(game):
            if k.lower() == "overlayappenable":
                game[n] = (k, "0")
                break
        else:
            game.append(("OverlayAppEnable", "0"))
        backup = f.with_name(f.name + ".goblincakes-bak")
        if not backup.exists():
            backup.write_text(text)
        tmp = f.with_name(f.name + ".new")
        tmp.write_text(_vdf_dump(pairs) + "\n")
        os.replace(tmp, f)
    return ""


# ───────────────────────────────────────────── sounds (made here, no sound files in the image)
def _bell(samples, rate, start, freq, length, loud):
    first = int(start * rate)
    for i in range(int(length * rate)):
        t = i / rate
        if first + i >= len(samples):
            break
        env = math.exp(-t * 3.2) * min(1.0, t * 400)
        v = (math.sin(2 * math.pi * freq * t) + 0.35 * math.sin(2 * math.pi * freq * 2.0 * t) * math.exp(-t * 2)
             + 0.18 * math.sin(2 * math.pi * freq * 3.01 * t) * math.exp(-t * 5))
        samples[first + i] += v * env * loud


def _write(path, samples, rate):
    peak = max(1e-6, max(abs(s) for s in samples))
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h", int(s / peak * 0.7 * 32767)) for s in samples))


def sound(name):
    """The path of a sound: "magi" (the splash: a rising sparkle of bells, a chord when the stars burst)
    or "pling" (a game chosen). Made once and kept in the cache."""
    path = CACHE / f"{name}-1.wav"
    if path.is_file():
        return str(path)
    rate = 32000
    if name == "magi":
        samples = [0.0] * int(rate * 5.0)
        notes = [1046.5, 1174.7, 1318.5, 1568.0, 1760.0, 2093.0, 2349.3, 2637.0, 3136.0]   # C6 pentatonic up
        for n, f in enumerate(notes):
            _bell(samples, rate, 0.55 + n * 0.19, f, 1.6, 0.30)
        for f in (523.25, 659.25, 783.99, 1046.5, 1568.0, 2093.0):                         # the burst
            _bell(samples, rate, 2.55, f, 2.4, 0.32)
        for n in range(14):                                                                # the shimmer after
            _bell(samples, rate, 2.7 + n * 0.11, 2093.0 * (1.5 if n % 2 else 1.25) ** (n % 3), 0.7, 0.10)
    else:
        samples = [0.0] * int(rate * 0.9)
        _bell(samples, rate, 0.0, 1568.0, 0.8, 0.5)
        _bell(samples, rate, 0.09, 2349.3, 0.8, 0.4)
    _write(path, samples, rate)
    return str(path)


def play(name):
    play_file(sound(name))


def play_file(path):
    # Marked as a game's sound: pw-play's own default is "Music", and goblin graph opens its bars for music (13 Nov)
    for player in (["pw-play", "--media-role", "Game", path], ["paplay", "--property=media.role=game", path]):
        try:
            subprocess.Popen(player, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            return
        except OSError:
            continue


# ───────────────────────────────────────────── GOBLINCAKES' own songs (the music picture, 13 Nov)
SONGS = HERE.parent / "songs"


def songs():
    """Every song in /usr/share/goblincakes/songs – new ones come along by themselves."""
    if not SONGS.is_dir():
        return []
    return [{"path": str(p), "name": p.stem} for p in sorted(SONGS.iterdir())
            if p.suffix.lower() in (".mp3", ".ogg", ".flac", ".opus", ".wav")]


class Music:
    """One song at a time: ffmpeg → pw-cat (role Game, not Music: goblin graph stays shut in Barnläge), in its own process group so Stopp ends both."""
    def __init__(self):
        self.proc = None
        self.path = ""

    def play(self, path):
        self.stop()
        cmd = ("ffmpeg -v quiet -i \"$1\" -f s16le -ac 2 -ar 48000 - | "
               "pw-cat --playback --media-role Game --raw --format s16 --rate 48000 --channels 2 -")
        try:
            self.proc = subprocess.Popen(["sh", "-c", cmd, "sh", path], start_new_session=True,
                                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.path = path
        except OSError:
            self.proc, self.path = None, ""

    def stop(self):
        if self.proc:
            # TERM first; ffmpeg waiting on a full pipe ignores it, so the whole group is KILLed after a moment
            for sig, wait in ((15, 0.3), (9, 1.0)):
                try:
                    os.killpg(self.proc.pid, sig)
                except OSError:
                    break
                try:
                    self.proc.wait(timeout=wait)
                except subprocess.TimeoutExpired:
                    pass
        self.proc, self.path = None, ""

    def playing(self):
        if self.proc and self.proc.poll() is not None:
            self.proc, self.path = None, ""
        return self.path


# ───────────────────────────────────────────── the volume cap
def volume_now():
    r = subprocess.run(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], capture_output=True, text=True)
    m = re.search(r"Volume:\s*([\d.]+)", r.stdout)
    return float(m.group(1)) if m else None


def cap_volume(percent):
    if not percent:
        return
    now = volume_now()
    if now is not None and now > percent / 100 + 0.005:
        subprocess.run(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", f"{percent / 100:.2f}"], capture_output=True)


# ───────────────────────────────────────────── the locks (on, and back – also after a crash)
def _quiet(*args):
    try:
        return subprocess.run(list(args), capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        return subprocess.CompletedProcess(args, 1, "", "")


def _kwin(*args):
    return _quiet("busctl", "--user", "call", "org.kde.KWin", "/Scripting", "org.kde.kwin.Scripting", *args)


def block_shortcuts(on):
    """Every global shortcut (Meta, Alt+Tab, Alt+F4, Ctrl+Alt+Del …) – KDE's own switch for it."""
    _quiet("busctl", "--user", "call", "org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel",
           "blockGlobalShortcuts", "b", "true" if on else "false")


def _rules_list():
    r = _quiet("kreadconfig6", "--file", "kwinrulesrc", "--group", "General", "--key", "rules")
    return [x for x in r.stdout.strip().split(",") if x]


def _set_rules(rules):
    _quiet("kwriteconfig6", "--file", "kwinrulesrc", "--group", "General", "--key", "rules", ",".join(rules))
    _quiet("kwriteconfig6", "--file", "kwinrulesrc", "--group", "General", "--key", "count", str(len(rules)))


RULE_KEYS = {"Description": "GOBLINCAKES barnläge (tas bort när barnläget slutar)",
             "disableglobalshortcuts": "true", "disableglobalshortcutsrule": "2", "wmclassmatch": "0"}


def kwin_rule(on):
    """A window rule for every window: "ignore global shortcuts" (Force). KWin then keeps them blocked whichever
    window is active – blockGlobalShortcuts alone is undone when the active window changes."""
    rules = [r for r in _rules_list() if r != RULE]
    if on:
        for key, value in RULE_KEYS.items():
            _quiet("kwriteconfig6", "--file", "kwinrulesrc", "--group", RULE, "--key", key, value)
        rules.append(RULE)
    else:
        for key in RULE_KEYS:
            _quiet("kwriteconfig6", "--file", "kwinrulesrc", "--group", RULE, "--key", key, "--delete")
    _set_rules(rules)
    _quiet("busctl", "--user", "call", "org.kde.KWin", "/KWin", "org.kde.KWin", "reconfigure")


POWER_GROUPS = ("AC", "Battery", "LowBattery")


def power_button(off, old=None):
    """The power button does nothing while Barnläge is on (PowerDevil's PowerButtonAction 0). Returns the old values."""
    saved = {}
    for group in POWER_GROUPS:
        base = ["--file", "powerdevilrc", "--group", group, "--group", "SuspendAndShutdown", "--key", "PowerButtonAction"]
        if off:
            saved[group] = _quiet("kreadconfig6", *base).stdout.strip()
            _quiet("kwriteconfig6", *base, "0")
        else:
            value = (old or {}).get(group, "")
            _quiet("kwriteconfig6", *base, *(["--delete"] if not value else [value]))
    for method in ("reparseConfiguration", "refreshStatus"):
        _quiet("busctl", "--user", "call", "org.kde.Solid.PowerManagement", "/org/kde/Solid/PowerManagement",
               "org.kde.Solid.PowerManagement", method)
    return saved


# The screen edges and corners (13 Nov, the user: the mouse in a corner opened the Overview – out of Barnläge on
# the other screen, where no window is active and fullscreen, so KWin does not block the edges). KWin's
# ElectricNone is 9; "None" for the plain actions in [ElectricBorders].
EDGE_KEYS = ([("ElectricBorders", k, "None") for k in
              ("Top", "TopRight", "Right", "BottomRight", "Bottom", "BottomLeft", "Left", "TopLeft")]
             + [(g, k, "9") for g in ("Effect-overview", "Effect-windowview", "Effect-cube", "Effect-desktopgrid")
                for k in ("BorderActivate", "BorderActivateAll", "BorderActivateClass", "TouchBorderActivate",
                          "TouchBorderActivateAll", "TouchBorderActivateClass")]
             + [("TabBox", "BorderActivate", "9"), ("TabBox", "BorderAlternativeActivate", "9"),
                ("TabBox", "TouchBorderActivate", "9"), ("TabBox", "TouchBorderAlternativeActivate", "9"),
                ("Windows", "ElectricBorders", "0")])


def screen_edges(off, old=None):
    """No action at the screen edges and corners while Barnläge is on. Returns the old values ("" = not set)."""
    saved = {}
    for group, key, none in EDGE_KEYS:
        base = ["--file", "kwinrc", "--group", group, "--key", key]
        name = group + "/" + key
        if off:
            saved[name] = _quiet("kreadconfig6", *base).stdout.strip()
            _quiet("kwriteconfig6", *base, none)
        else:
            value = (old or {}).get(name, "")
            _quiet("kwriteconfig6", *base, *(["--delete"] if not value else [value]))
    _quiet("busctl", "--user", "call", "org.kde.KWin", "/KWin", "org.kde.KWin", "reconfigure")
    # The effects (the Overview …) read their own edges only when they are told to
    for effect in ("overview", "windowview", "cube", "desktopgrid"):
        _quiet("busctl", "--user", "call", "org.kde.KWin", "/Effects", "org.kde.kwin.Effects", "reconfigureEffect",
               "s", effect)
    return saved


def overlays(hide):
    """Our own overlays in the games (MangoHud, goblin frames) – through the games script, as the user wished."""
    _quiet(str(GAMES), "kids-overlays", "on" if hide else "off")


def allowed_names(settings):
    names = set()
    for item in settings["items"]:
        names.update(window_names(item))
    return sorted(names)


def kwin_load(name, template, payload):
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir())
    script = runtime / f"{name}.js"
    script.write_text((HERE / template).read_text().replace("__DATA__", json.dumps(payload)))
    _kwin("unloadScript", "s", name)
    ok = _kwin("loadScript", "ss", str(script), name).returncode == 0
    if ok:
        _kwin("start")
    return ok


def write_state(state):
    STATE.parent.mkdir(parents=True, exist_ok=True)
    tmp = STATE.with_name(STATE.name + ".new")
    tmp.write_text(json.dumps(state))
    os.replace(tmp, STATE)


def read_state():
    try:
        return json.loads(STATE.read_text())
    except (OSError, ValueError):
        return None


def lock(settings, service):
    """Everything on. The state file comes first, so a crash halfway can still be put back."""
    state = {"pid": os.getpid(), "started": time.time(), "hidden": [], "allowed": allowed_names(settings),
             "power": {}, "parts": []}
    write_state(state)
    # The window script first (13 Nov): until it has placed the windows the main screen may be uncovered,
    # and the tray panel could be reached from the top edge
    if kwin_load(KWIN_SCRIPT, "kwin-on.js", {"service": service, "allowed": state["allowed"]}):
        state["parts"].append("kwin")
    write_state(state)
    kwin_rule(True)
    state["parts"].append("rule")
    block_shortcuts(True)
    state["parts"].append("shortcuts")
    write_state(state)
    state["power"] = power_button(True)
    state["parts"].append("power")
    write_state(state)
    state["edges"] = screen_edges(True)
    state["parts"].append("edges")
    write_state(state)
    overlays(True)
    state["parts"].append("overlays")
    write_state(state)
    if any(i["kind"] == "steam" for i in settings["items"]):
        start_steam_quietly()
    return state


def remember_hidden(window_id):
    state = read_state()
    if state is not None and window_id not in state["hidden"]:
        state["hidden"].append(window_id)
        write_state(state)


def restore(state=None):
    """Everything back as it was: windows, shortcuts, the power button, the screen edges, the overlays. Safe to run twice."""
    state = state or read_state()
    if state is None:
        return False
    _kwin("unloadScript", "s", KWIN_SCRIPT)
    kwin_load(KWIN_SCRIPT + "-off", "kwin-off.js", {"hidden": state.get("hidden") or [],
                                                     "allowed": state.get("allowed") or []})
    time.sleep(0.3)
    _kwin("unloadScript", "s", KWIN_SCRIPT + "-off")
    kwin_rule(False)
    block_shortcuts(False)
    if "power" in (state.get("parts") or []):
        power_button(False, state.get("power"))
    if "edges" in (state.get("parts") or []):
        screen_edges(False, state.get("edges"))
    overlays(False)
    STATE.unlink(missing_ok=True)
    return True


def running_pid():
    state = read_state()
    pid = (state or {}).get("pid")
    if not pid:
        return 0
    try:
        os.kill(pid, 0)
    except OSError:
        return 0
    try:
        cmdline = Path(f"/proc/{pid}/cmdline").read_bytes()
    except OSError:
        return 0
    return pid if b"goblin-kids" in cmdline else 0


# ───────────────────────────────────────────── for Config
def info(download=False):
    settings = load()
    import namnljud  # noqa: PLC0415
    chosen = []
    for item in settings["items"]:
        pic = picture_for(item, download)
        entry = dict(item, **pic)
        entry["say"] = item.get("say") or namnljud.spoken(item.get("name", ""))
        entry["sound"] = namnljud.sound_for(item)
        if item["kind"] == "steam":
            entry["overlay"] = overlay_on(item["id"])
        chosen.append(entry)
    return {"items": chosen, "hasPin": bool(settings["pin"]), "volume": settings["volume"],
            "music": settings["music"], "songs": songs(),
            "pictures": pictures(), "drawings": len(drawings()), "steamRunning": steam_running(),
            "active": bool(running_pid()), "voice": namnljud.engine()}


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "info":
        print(json.dumps(info(download="--download" in sys.argv), ensure_ascii=False))
    elif cmd == "available":
        print(json.dumps(available(), ensure_ascii=False))
    elif cmd == "restore":
        sys.exit(0 if restore() else 1)
    else:
        print(__doc__)
