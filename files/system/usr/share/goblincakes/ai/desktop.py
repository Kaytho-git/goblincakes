"""Goblin AI's ```skrivbord tool (point 5 of Kakan's plan, 28 Oct): Kakan controls the desktop – the music, the
volume … The user's decision 28 Oct: music/volume, opening things, notices/clipboard, moving windows and starting
games run at once without a Tillåt card; closing windows needs Tillåt. Everything is logged under Körda kommandon
with how it is undone (by "kakan")."""

import json
import re
import subprocess
import sys
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


def _done(code, undo, said, conversation=""):
    """Runs code, logs it with its undo and returns what the AI gets back."""
    try:
        exit_code, out = _run(code)
    except (OSError, subprocess.SubprocessError) as e:
        exit_code, out = 1, str(e)
    cmdlevel.log(code, "change", "kakan", exit_code, out, {"undo": undo, "hint": ""} if undo else None, conversation)
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


def volume(what, conversation=""):
    """`40` / `+10` / `-10` / `tyst` / `ljud` / `` (= how loud now) – the computer's sound (speakers/headset)."""
    what = what.lower().replace("%", "").replace("procent", "").strip()
    now, muted = volume_now()
    if now is None:
        return "Hittar ingen ljudutgång."
    if what in ("", "vad", "nu", "hur"):
        return f"Volymen är {now} %" + (" (ljudet avstängt)." if muted else ".")
    back = f"wpctl set-volume {SINK} {now / 100:.2f}"
    if re.match(r"tyst|av|mute|stäng", what):
        return _done(f"wpctl set-mute {SINK} 1", [f"wpctl set-mute {SINK} 0"], "Stängde av ljudet.", conversation)
    if re.match(r"ljud|på|unmute", what):
        return _done(f"wpctl set-mute {SINK} 0", [f"wpctl set-mute {SINK} 1"], f"Ljudet på igen ({now} %).",
                     conversation)
    m = re.fullmatch(r"([+-]?)\s*(\d{1,3})", what)
    if not m:
        return "Okänt: säg ett tal (40), +10, -10, tyst eller ljud."
    level = int(m.group(2))
    level = now + level if m.group(1) == "+" else now - level if m.group(1) == "-" else level
    level = max(0, min(100, level))  # never louder than 100 % (hearing, the headset)
    if level == now and not muted:
        return f"Volymen är redan {now} %."
    code = f"wpctl set-volume {SINK} {level / 100:.2f}" + (f"\nwpctl set-mute {SINK} 0" if muted else "")
    return _done(code, [back] + ([f"wpctl set-mute {SINK} 1"] if muted else []),
                 f"Volymen {now} % → {level} %.", conversation)


def act(line, conversation=""):
    """The tool's line: `musik <paus|spela|nästa|föregående|vad>`, `volym <tal|+10|-10|tyst|ljud>`."""
    word, _, rest = line.strip().partition(" ")
    word = word.lower()
    if word in ("musik", "music", "låt"):
        return music(rest, conversation)
    if word in ("volym", "volume", "ljud"):
        return volume(rest, conversation)
    return "Okänd rad. Raderna: musik paus|spela|nästa|föregående|vad, volym 40|+10|-10|tyst|ljud."


if __name__ == "__main__":  # trying it out: python3 desktop.py musik vad
    print(act(" ".join(sys.argv[1:])))
