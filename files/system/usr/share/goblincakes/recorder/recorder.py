"""recorder – shared core of GoblinRecorder (the window /usr/bin/goblin-recorder and the
user service /usr/libexec/goblincakes-recorder).

Automatic WoW recordings on Linux: the service follows WoW's combat log and steers OBS
(Flatpak com.obsproject.Studio) through its built-in obs-websocket 5 – recording starts
when a Mythic+ key starts or a raid boss is pulled, and stops just after the end.

Settings: ~/.config/goblincakes/recorder.json. Status for the window:
~/.cache/goblincakes/recorder-status.json. Each video gets a .json beside it with what it
shows (boss, difficulty, kill/wipe, deaths as marks) and a .jpg thumbnail.
"""
import base64
import glob
import hashlib
import json
import math
import os
import re
import secrets
import shutil
import socket
import statistics
import struct
import subprocess
import sys
import time
import urllib.error
from datetime import datetime
from pathlib import Path

HOME = Path.home()
CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "goblincakes"
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "goblincakes"
CONFIG_FILE = CONFIG_DIR / "recorder.json"
STATUS_FILE = CACHE_DIR / "recorder-status.json"
# "Testa inspelningen" in the window (15 Oct, the user's wish): the window writes this file, the
# service records TEST_SECONDS of the screen with the current settings
TEST_REQUEST = CACHE_DIR / "recorder-test"
TEST_SECONDS = 30
QUALITY_NAMES = {"best": "Bäst", "high": "Hög", "normal": "Normal", "small": "Liten"}
OVERLAY_DIR = CONFIG_DIR / "recorder-overlays"  # copies of the images you cover parts of the video with

OBS_APP = "com.obsproject.Studio"
OBS_AUDIO_PLUGIN = "com.obsproject.Studio.Plugin.PipeWireAudioCapture"
OBS_CONFIG = HOME / ".var/app" / OBS_APP / "config/obs-studio"
WS_CONFIG = OBS_CONFIG / "plugin_config/obs-websocket/config.json"
OBS_NAME = "GOBLINCAKES"  # profile, scene collection and scene
WOW_LOGS = Path(os.environ.get("GOBLINCAKES_RECORDER_LOGS", HOME / "Games/WoW"))  # <Version>/Logs (goblincakes-wow-links)

DEFAULTS = {
    "folder": str(HOME / "Videos/WoW"),
    "fps": 60,
    "codec": "h264",  # h264 | hevc | av1 (NVENC on the graphics card) | x264 (processor)
    "raid": True,
    "mplus": True,
    "arena": True,  # 2v2, 3v3, Solo Shuffle, Skirmish – the whole match
    "raidLevels": ["lfr", "normal", "heroic", "mythic"],  # which raid difficulties to record
    "mplusMin": 2,  # keys from this level up
    "autoStartObs": True,
    "mic": True,  # your microphone on tracks 1 and 3 (with noise suppression)
    "capture": "all",  # all = WoW, Discord and your microphone on three tracks | wow = only the game, one track
    "gameBoost": 12,
    "micGate": "normal",  # off | normal | strong | keys – after the noise suppression, see MIC_GATES
    "quality": "normal",  # best | high | normal | small – see QUALITY_MBIT/encoder_settings  # dB louder game sound – WoW plays quietly next to Discord
    "overlays": [],  # boxes over the video: {"file": image or "" = black, "text", "x", "y", "w", "h" as 0–1 of the picture}
    "postRoll": 5,  # seconds after the end
    "maxGB": 100,  # oldest videos are removed above this
    "closeAction": "ask",  # the window's ✕: ask | tray = hide in the system tray | quit
    "keepWipes": False,  # False: only kills stay when WoW closes (and 2 wipes per raid boss meanwhile)
    "cs2": True,  # Counter-Strike 2 matches, from the end of the warm-up to the end (needs the GSI file)
    "cs2KeepMatch": False,  # False: the whole match goes when its clips (2K–ACE, all kills) are made
}

CODECS = {"h264": "NVENC H.264", "hevc": "NVENC HEVC", "av1": "NVENC AV1", "x264": "x264"}
RAID_DIFFICULTIES = {14: "Normal", 15: "Heroic", 16: "Mythic", 17: "LFR"}  # WoW's difficultyID → name
if os.environ.get("GOBLINCAKES_RECORDER_DUNGEON_BOSSES"):  # tests: dungeon bosses count as raid bosses
    RAID_DIFFICULTIES.update({1: "Normal", 2: "Heroic", 23: "Mythic"})


def raid_level_wanted(cfg, difficulty_id):
    """Is this raid difficulty ticked in GoblinRecorder (LFR/Normal/Heroic/Mythic)?"""
    name = RAID_DIFFICULTIES.get(difficulty_id, "").lower()
    return bool(cfg.get("raid")) and name in (cfg.get("raidLevels") or [])
DUNGEON_DIFFICULTIES = {1: "Normal", 2: "Heroic", 8: "Mythic+", 23: "Mythic"}

# Tracks in the video: 1 = everything, 2 = the game, 3 = Discord + your microphone
TRACK_NAMES = ["Allt", "WoW", "Discord"]


def only_wow(cfg):
    """Only the game's sound in the videos (Inställningar → Ljud → Filmen fångar)."""
    return cfg.get("capture") == "wow"


def track_names(cfg, game="WoW"):
    names = [game if n == "WoW" else n for n in TRACK_NAMES]
    return [game] if only_wow(cfg) else names
AUDIO_INPUTS = [
    {"name": "WoW-ljud", "target": "World of Warcraft", "tracks": [1, 2]},
    {"name": "CS2-ljud", "target": "cs2", "tracks": [1, 2]},  # the program's name in PipeWire (heard in a real match 22 Oct)
    {"name": "Discord-ljud", "target": "Discord", "tracks": [1, 3]},
]


# ---------------------------------------------------------------- settings

def load_config():
    cfg = dict(DEFAULTS)
    try:
        cfg.update(json.loads(CONFIG_FILE.read_text()))
    except (OSError, ValueError):
        pass
    return cfg


def save_config(cfg):
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    tmp = CONFIG_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(cfg, indent=2, ensure_ascii=False) + "\n")
    tmp.replace(CONFIG_FILE)


def write_status(status):
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    tmp = STATUS_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(status, ensure_ascii=False))
    tmp.replace(STATUS_FILE)


def read_status():
    try:
        return json.loads(STATUS_FILE.read_text())
    except (OSError, ValueError):
        return {}


# ---------------------------------------------------------------- OBS

def obs_installed():
    return subprocess.run(["flatpak", "info", OBS_APP], capture_output=True).returncode == 0


def audio_plugin_installed():
    return subprocess.run(["flatpak", "info", OBS_AUDIO_PLUGIN], capture_output=True).returncode == 0


def obs_running():
    return subprocess.run(["pgrep", "-x", "obs"], capture_output=True).returncode == 0


def ws_settings():
    try:
        return json.loads(WS_CONFIG.read_text())
    except (OSError, ValueError):
        return {}


def enable_websocket():
    """Turn on OBS's websocket server (with a password). Only while OBS is closed –
    OBS writes its own settings back when it quits."""
    if obs_running():
        return False
    data = ws_settings()
    data.setdefault("alerts_enabled", False)
    data.setdefault("first_load", False)
    data.setdefault("server_port", 4455)
    data["server_enabled"] = True
    data["auth_required"] = True
    if not data.get("server_password"):
        data["server_password"] = secrets.token_urlsafe(12)
    WS_CONFIG.parent.mkdir(parents=True, exist_ok=True)
    WS_CONFIG.write_text(json.dumps(data, indent=2) + "\n")
    return True


SESSION_VARS = ("WAYLAND_DISPLAY", "DISPLAY", "XAUTHORITY", "XDG_SESSION_TYPE", "XDG_CURRENT_DESKTOP",
                "XDG_SESSION_DESKTOP", "QT_QPA_PLATFORMTHEME", "QT_WAYLAND_RECONNECT")
def session_env():
    """The desktop session's environment now – the service may have started before Plasma told
    systemd about the screen (12 Oct, the same thing crashed goblin graph's window)."""
    env = dict(os.environ)
    try:
        out = subprocess.run(["systemctl", "--user", "show-environment"], capture_output=True,
                             text=True, timeout=5).stdout
        for line in out.splitlines():
            key, _, value = line.partition("=")
            if key in SESSION_VARS:
                env[key] = value
    except Exception:
        pass
    return env


def start_obs():
    """Start OBS hidden in the system tray, with our profile and scenes. Returns an
    error text, or "" when it was started (or already running)."""
    if not obs_installed():
        return "OBS är inte installerat. Installera det i GOBLINCAKES Config → Program."
    if obs_running():
        return ""
    enable_websocket()
    write_encoder_file(load_config())
    args = ["flatpak", "run", OBS_APP, "--disable-shutdown-check"]
    if screen_chosen():
        args.append("--minimize-to-tray")  # until then visible: KDE only asks which screen
                                           # to record when OBS's window is shown
    names = obs_names()
    if OBS_NAME in names["profiles"]:
        args += ["--profile", OBS_NAME]
    if OBS_NAME in names["collections"]:
        args += ["--collection", OBS_NAME]
    subprocess.Popen(args, env=session_env(), stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)
    return ""


def screen_chosen():
    """Has KDE been told which screen OBS may record (a restore token in our scenes)?"""
    try:
        scenes = json.loads((OBS_CONFIG / "basic/scenes" / f"{OBS_NAME}.json").read_text())
    except (OSError, ValueError):
        return False
    return any(src.get("name") == "Skärm" and src.get("settings", {}).get("RestoreToken")
               for src in scenes.get("sources", []))


def screen_chosen_live(obs):
    try:
        return bool(obs.call("GetInputSettings", {"inputName": "Skärm"})["inputSettings"].get("RestoreToken"))
    except OBSError:
        return False


SCREEN_STATE = re.compile(r'^(\d\d):(\d\d):(\d\d)\.\d+: \[pipewire\] Stream \S+ state: "(\w+)"')


def screen_stalled():
    """Has OBS's screen capture stopped getting pictures? When the screens go away for a
    moment (sleep, switched off) KWin pauses the stream and it never comes back – the
    video stays on the last picture of the desktop. Seen in OBS's newest log: the last
    state of the screen stream is "paused" (and has been for 10 s)."""
    logs = sorted((OBS_CONFIG / "logs").glob("*.txt"), key=lambda p: p.stat().st_mtime)
    if not logs:
        return False
    try:
        lines = logs[-1].read_text(errors="replace").splitlines()
    except OSError:
        return False
    for line in reversed(lines):
        m = SCREEN_STATE.match(line)
        if m:
            if m[4] != "paused":
                return False
            t = time.localtime()
            age = (t.tm_hour * 3600 + t.tm_min * 60 + t.tm_sec
                   - (int(m[1]) * 3600 + int(m[2]) * 60 + int(m[3]))) % 86400
            return age > 10
    return False


def pick_screen(obs):
    """Open KDE's screen choice for OBS (the source's Select button)."""
    obs.call("PressInputPropertiesButton", {"inputName": "Skärm", "propertyName": "Reload"}, check=False)


def stop_obs(wait=30):
    """Close OBS (it saves its settings) and wait until it is gone."""
    subprocess.run(["pkill", "-TERM", "-x", "obs"], capture_output=True)
    end = time.time() + wait
    while obs_running() and time.time() < end:
        time.sleep(0.25)
    return not obs_running()


def restart_obs():
    """OBS again, hidden – for a new encoder/quality, written while it is closed. The
    screen choice is remembered."""
    stop_obs()
    write_encoder_file(load_config())
    return start_obs()


def obs_names():
    """Profiles and scene collections that exist on disk."""
    profiles = [p.name for p in (OBS_CONFIG / "basic/profiles").glob("*") if p.is_dir()]
    collections = [p.stem for p in (OBS_CONFIG / "basic/scenes").glob("*.json")]
    return {"profiles": profiles, "collections": collections}


def vaapi_device():
    """The render node of an AMD or Intel graphics card (VAAPI), "" when there is none –
    on a laptop with two cards the AMD one first."""
    found = []
    for node in sorted(Path("/sys/class/drm").glob("renderD*")):
        try:
            driver = (node / "device/driver").resolve().name
        except OSError:
            continue
        if driver in ("amdgpu", "radeon", "i915", "xe"):
            found.append((0 if driver in ("amdgpu", "radeon") else 1, f"/dev/dri/{node.name}"))
    return min(found)[1] if found else ""


def obs_encoders():
    """Codecs OBS can record with on this computer, from OBS's latest log: Nvidia's NVENC,
    else VAAPI (AMD and Intel – OBS logs "FFmpeg VAAPI H264 encoding supported" at start),
    else only x264 on the processor."""
    logs = sorted((OBS_CONFIG / "logs").glob("*.txt"), key=lambda p: p.stat().st_mtime)
    text = logs[-1].read_text(errors="replace") if logs else ""
    nvenc = "obs_nvenc_h264_tex" in text or "jim_nvenc" in text
    if nvenc:
        family = "nvenc"
        found = {"h264": True, "hevc": "obs_nvenc_hevc_tex" in text, "av1": "AV1 supported: true" in text}
    else:
        family = "vaapi"
        found = {c: bool(re.search(rf"VAAPI {name} encoding supported", text))
                 for c, name in (("h264", "H264"), ("hevc", "HEVC"), ("av1", "AV1"))}
        if not any(found.values()) or not vaapi_device():
            family, found = "", {"h264": False, "hevc": False, "av1": False}
    found["x264"] = True
    return {"hardware": bool(family), "family": family, "codecs": found, "known": bool(text)}


class OBSError(Exception):
    pass


class OBS:
    """A small obs-websocket 5 client using only the standard library."""

    def __init__(self, host="127.0.0.1", port=None, password=None, timeout=5):
        ws = ws_settings()
        self.host = host
        self.port = port or ws.get("server_port", 4455)
        self.password = password if password is not None else ws.get("server_password", "")
        self.timeout = timeout
        self.sock = None
        self.buf = b""
        self.next_id = 0

    # --- websocket framing
    def _recv_exact(self, n):
        while len(self.buf) < n:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise OBSError("OBS stängde anslutningen")
            self.buf += chunk
        data, self.buf = self.buf[:n], self.buf[n:]
        return data

    def _send_frame(self, opcode, payload):
        head = bytes([0x80 | opcode])
        n = len(payload)
        if n < 126:
            head += bytes([0x80 | n])
        elif n < 65536:
            head += bytes([0x80 | 126]) + struct.pack("!H", n)
        else:
            head += bytes([0x80 | 127]) + struct.pack("!Q", n)
        mask = os.urandom(4)
        body = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        self.sock.sendall(head + mask + body)

    def _recv_message(self):
        parts = []
        while True:
            b1, b2 = self._recv_exact(2)
            fin, opcode = b1 & 0x80, b1 & 0x0F
            n = b2 & 0x7F
            if n == 126:
                n = struct.unpack("!H", self._recv_exact(2))[0]
            elif n == 127:
                n = struct.unpack("!Q", self._recv_exact(8))[0]
            mask = self._recv_exact(4) if b2 & 0x80 else None
            payload = self._recv_exact(n)
            if mask:
                payload = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
            if opcode == 0x8:
                raise OBSError("OBS stängde anslutningen")
            if opcode == 0x9:
                self._send_frame(0xA, payload)
                continue
            if opcode == 0xA:
                continue
            parts.append(payload)
            if fin:
                return json.loads(b"".join(parts).decode())

    def _send(self, op, d):
        self._send_frame(0x1, json.dumps({"op": op, "d": d}).encode())

    # --- obs-websocket protocol
    def connect(self):
        try:
            self.sock = socket.create_connection((self.host, self.port), self.timeout)
        except OSError as e:
            raise OBSError("OBS fjärrstyrning svarar inte") from e
        self.sock.settimeout(self.timeout)
        key = base64.b64encode(os.urandom(16)).decode()
        self.sock.sendall((
            f"GET / HTTP/1.1\r\nHost: {self.host}:{self.port}\r\nUpgrade: websocket\r\n"
            f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n"
            "Sec-WebSocket-Protocol: obswebsocket.json\r\n\r\n").encode())
        while b"\r\n\r\n" not in self.buf:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise OBSError("OBS svarade inte")
            self.buf += chunk
        head, self.buf = self.buf.split(b"\r\n\r\n", 1)
        if b" 101 " not in head.split(b"\r\n")[0]:
            raise OBSError("OBS fjärrstyrning svarade fel")
        hello = self._recv_message()["d"]
        ident = {"rpcVersion": 1, "eventSubscriptions": 0}
        auth = hello.get("authentication")
        if auth:
            secret = base64.b64encode(hashlib.sha256((self.password + auth["salt"]).encode()).digest())
            ident["authentication"] = base64.b64encode(
                hashlib.sha256(secret + auth["challenge"].encode()).digest()).decode()
        self._send(1, ident)
        try:
            msg = self._recv_message()
        except OBSError as e:
            raise OBSError("Fel lösenord till OBS fjärrstyrning") from e
        if msg.get("op") != 2:
            raise OBSError("OBS godkände inte anslutningen")
        return self

    def close(self):
        if self.sock:
            try:
                self._send_frame(0x8, b"")
                self.sock.close()
            except OSError:
                pass
            self.sock = None

    def call(self, request, data=None, check=True):
        self.next_id += 1
        rid = str(self.next_id)
        d = {"requestType": request, "requestId": rid}
        if data is not None:
            d["requestData"] = data
        self._send(6, d)
        while True:
            msg = self._recv_message()
            if msg.get("op") == 7 and msg["d"].get("requestId") == rid:
                st = msg["d"]["requestStatus"]
                if check and not st.get("result"):
                    raise OBSError(f"{request}: {st.get('comment') or st.get('code')}")
                return msg["d"].get("responseData") or {}

    def __enter__(self):
        return self.connect()

    def __exit__(self, *exc):
        self.close()


def setup_obs(obs, cfg):
    """Make OBS ready: our profile and scene collection (made once, the user's own are
    left alone), screen capture, the game and Discord on their own audio tracks, and
    the settings from GoblinRecorder. Returns a list of what was done."""
    done = []
    if obs.call("GetRecordStatus").get("outputActive"):
        return done  # never touch OBS while it records
    profiles = obs.call("GetProfileList")
    if OBS_NAME not in profiles["profiles"]:
        obs.call("CreateProfile", {"profileName": OBS_NAME})
        done.append("profil")
    elif profiles["currentProfileName"] != OBS_NAME:
        obs.call("SetCurrentProfile", {"profileName": OBS_NAME})
    collections = obs.call("GetSceneCollectionList")
    if OBS_NAME not in collections["sceneCollections"]:
        obs.call("CreateSceneCollection", {"sceneCollectionName": OBS_NAME})
        done.append("scener")
    elif collections["currentSceneCollectionName"] != OBS_NAME:
        obs.call("SetCurrentSceneCollection", {"sceneCollectionName": OBS_NAME})
        time.sleep(1)

    scenes = [s["sceneName"] for s in obs.call("GetSceneList")["scenes"]]
    if OBS_NAME not in scenes:
        obs.call("CreateScene", {"sceneName": OBS_NAME})
    obs.call("SetCurrentProgramScene", {"sceneName": OBS_NAME})
    for old in scenes:
        if old != OBS_NAME and not obs.call("GetSceneItemList", {"sceneName": old})["sceneItems"]:
            obs.call("RemoveScene", {"sceneName": old}, check=False)  # OBS's empty "Scen"

    inputs = {i["inputName"]: i["inputKind"] for i in obs.call("GetInputList")["inputs"]}
    if "Skärm" not in inputs:
        # KDE asks once which screen OBS may record; OBS remembers the answer
        obs.call("CreateInput", {"sceneName": OBS_NAME, "inputName": "Skärm",
                                 "inputKind": "pipewire-screen-capture-source",
                                 "inputSettings": {"ShowCursor": True}})
        done.append("skärmfångst")
        pick_screen(obs)
    if audio_plugin_installed():
        for a in AUDIO_INPUTS:
            if a["name"] not in inputs:
                obs.call("CreateInput", {"sceneName": OBS_NAME, "inputName": a["name"],
                                         "inputKind": "pipewire_audio_application_capture",
                                         "inputSettings": {"TargetName": a["target"]}})
                done.append(a["name"])
            obs.call("SetInputAudioTracks", {"inputName": a["name"], "inputAudioTracks":
                     {str(t): t in a["tracks"] for t in range(1, 7)}}, check=False)
    # The desktop/mic sources OBS makes by itself would mix everything into the video
    special = obs.call("GetSpecialInputs")
    for key, name in special.items():
        if name:
            obs.call("SetInputAudioTracks", {"inputName": name, "inputAudioTracks":
                     {str(t): False for t in range(1, 7)}}, check=False)
    if apply_settings(obs, cfg) == "restart":
        done.append("restart")
    return done


QUALITY_MBIT = {"high": 25, "normal": 10, "small": 5}  # HEVC/AV1 at 60 fps
# "best" (15 Oct, the user: Hög looked a bit rough): constant quality instead of a bitrate – as
# many bits as each picture needs (raid effects take a lot), near what the eye can tell apart.
# The level per encoder family; lower = finer. The size follows what happens on screen.
# 22 = Warcraft Recorder's "Ultra" (17 Oct, the user: +14 on 18 was 11.8 GB for 29 min ≈ 56 Mbit/s).
# Measured on a minute of that key (HEVC NVENC, VMAF against the 18 film): 18 → 98.0, 21 → 97.2,
# 23 → 96.5, Hög (VBR 25 Mbit) 97.2 – about 40 % smaller than 18 for a difference hard to see.
BEST_QP = {"nvenc": 22, "vaapi": 22, "x264": 22}


def encoder_settings(cfg, codec, family="nvenc"):
    """OBS's recording encoder (advanced output mode): which encoder, and its settings –
    a bitrate from the quality choice. H.264 needs more than HEVC for the same picture,
    30 fps less than 60."""
    if cfg.get("quality") == "best":
        return best_encoder_settings(cfg, codec, family)
    mbit = QUALITY_MBIT.get(cfg.get("quality"), 10)
    if codec in ("h264", "x264"):
        mbit *= 1.5
    if int(cfg["fps"]) <= 30:
        mbit *= 0.7
    kbit = int(mbit * 1000)
    if codec == "x264":
        return "obs_x264", {"rate_control": "VBR", "bitrate": kbit, "preset": "veryfast", "keyint_sec": 2}
    if family == "vaapi":  # AMD and Intel
        name = {"h264": "ffmpeg_vaapi", "hevc": "hevc_ffmpeg_vaapi", "av1": "av1_ffmpeg_vaapi"}[codec]
        return name, {"vaapi_device": vaapi_device(), "rate_control": "VBR", "bitrate": kbit,
                      "maxrate": int(kbit * 1.5), "keyint_sec": 2, "bf": 0}
    name = {"h264": "obs_nvenc_h264_tex", "hevc": "obs_nvenc_hevc_tex", "av1": "obs_nvenc_av1_tex"}[codec]
    return name, {"rate_control": "VBR", "bitrate": kbit, "max_bitrate": int(kbit * 1.5),
                  "preset2": "p5", "tune": "hq", "multipass": "qres", "keyint_sec": 2, "bf": 2}


def best_encoder_settings(cfg, codec, family):
    if codec == "x264":
        return "obs_x264", {"rate_control": "CRF", "crf": BEST_QP["x264"], "preset": "veryfast", "keyint_sec": 2}
    if family == "vaapi":
        name = {"h264": "ffmpeg_vaapi", "hevc": "hevc_ffmpeg_vaapi", "av1": "av1_ffmpeg_vaapi"}[codec]
        return name, {"vaapi_device": vaapi_device(), "rate_control": "CQP", "qp": BEST_QP["vaapi"],
                      "keyint_sec": 2, "bf": 0}
    name = {"h264": "obs_nvenc_h264_tex", "hevc": "obs_nvenc_hevc_tex", "av1": "obs_nvenc_av1_tex"}[codec]
    return name, {"rate_control": "CQP", "cqp": BEST_QP["nvenc"], "preset2": "p5", "tune": "hq",
                  "multipass": "qres", "keyint_sec": 2, "bf": 2}


def profile_dir():
    return OBS_CONFIG / "basic/profiles" / OBS_NAME


def write_encoder_file(cfg):
    """recordEncoder.json in our OBS profile – only while OBS is closed (OBS reads it at
    start and writes its own copy when it quits)."""
    enc = obs_encoders()
    codec = pick_codec(cfg, enc)
    _, settings = encoder_settings(cfg, codec, enc.get("family") or "nvenc")
    d = profile_dir()
    if d.is_dir():
        (d / "recordEncoder.json").write_text(json.dumps(settings))


def pick_codec(cfg, enc):
    return cfg["codec"] if enc["codecs"].get(cfg["codec"]) or not enc["known"] else (
        "h264" if enc["hardware"] else "x264")


def apply_settings(obs, cfg):
    """Folder, fps, encoder and quality from GoblinRecorder into OBS (not while recording).
    Returns "restart" when OBS must be restarted for them to work (OBS builds the
    recording encoder when it starts – a change while it runs makes the next recording
    fail with "NVENC … update your drivers"), False while recording."""
    if obs.call("GetRecordStatus").get("outputActive"):
        return False
    folder = Path(cfg["folder"])
    folder.mkdir(parents=True, exist_ok=True)
    enc = obs_encoders()
    codec = pick_codec(cfg, enc)
    encoder, settings = encoder_settings(cfg, codec, enc.get("family") or "nvenc")
    params = [
        ("Output", "Mode", "Advanced"),
        ("Output", "FilenameFormatting", "%CCYY-%MM-%DD %hh-%mm-%ss"),
        ("AdvOut", "RecType", "Standard"),
        ("AdvOut", "RecFilePath", str(folder)),
        ("AdvOut", "RecFormat2", "hybrid_mp4"),  # MP4 that survives a crash
        ("AdvOut", "RecEncoder", encoder),
        ("AdvOut", "RecTracks", "1" if only_wow(cfg) else "7"),  # track 1, or tracks 1–3
        ("AdvOut", "RecUseRescale", "false"),
        ("AdvOut", "RecRB", "false"),
    ]
    restart = False
    for cat, name, value in params:
        now = obs.call("GetProfileParameter", {"parameterCategory": cat, "parameterName": name}).get("parameterValue")
        if now == value:
            continue
        obs.call("SetProfileParameter", {"parameterCategory": cat, "parameterName": name,
                                         "parameterValue": value})
        restart = restart or name in ("Mode", "RecEncoder", "RecFormat2", "RecTracks", "RecType")
    try:
        current = json.loads((profile_dir() / "recordEncoder.json").read_text())
    except (OSError, ValueError):
        current = {}
    if any(current.get(k) != v for k, v in settings.items()):
        restart = True  # the file is written while OBS is closed, see restart_obs
    video = obs.call("GetVideoSettings")
    fps = int(cfg["fps"])
    w, h = main_screen_size() or (video["baseWidth"], video["baseHeight"])
    want = {"fpsNumerator": fps, "fpsDenominator": 1, "baseWidth": w, "baseHeight": h,
            "outputWidth": w, "outputHeight": h}  # the screen's own size – a new profile says 720p
    if any(video.get(k) != v for k, v in want.items()):
        obs.call("SetVideoSettings", want, check=False)
    fit_screen(obs, w, h)
    set_audio(obs, cfg)
    set_overlays(obs, cfg, w, h)
    return "restart" if restart else True


OVERLAY_PREFIX = "Dölj "


def set_overlays(obs, cfg, w, h):
    """Images or black boxes on top of the screen in OBS's scene, with an optional text –
    they hide parts of the picture in the video only, never on your screen. Names
    "Dölj 1", "Dölj 1 text", "Dölj 2" …"""
    wanted = {}  # name → (kind, settings, rect as pixels, fit)
    for i, ov in enumerate(cfg.get("overlays") or [], 1):
        rect = (round(ov["x"] * w), round(ov["y"] * h), max(round(ov["w"] * w), 2), max(round(ov["h"] * h), 2))
        kind = overlay_kind(ov)
        wanted[f"{OVERLAY_PREFIX}{i}"] = (kind, {"file": ov["file"], "unload": False} if kind == "image_source"
                                          else {"color": 0xFF000000, "width": 16, "height": 16}, rect, False)
        if (ov.get("text") or "").strip():
            wanted[f"{OVERLAY_PREFIX}{i} text"] = ("text_ft2_source_v2", {
                "text": ov["text"].strip(), "font": {"face": "IBM Plex Sans", "style": "SemiBold", "size": 96, "flags": 1},
                "color1": 0xFFF5ECE6, "color2": 0xFFF5ECE6, "outline": False, "drop_shadow": False}, rect, True)
    inputs = {i["inputName"]: i["inputKind"] for i in obs.call("GetInputList")["inputs"]}
    for name, kind in inputs.items():
        if name.startswith(OVERLAY_PREFIX) and (name not in wanted or wanted[name][0] != kind):
            obs.call("RemoveInput", {"inputName": name}, check=False)
    gone = [n for n in inputs if n.startswith(OVERLAY_PREFIX) and (n not in wanted or wanted[n][0] != inputs[n])]
    for _ in range(20):  # OBS removes them a moment after answering
        left = {i["inputName"] for i in obs.call("GetInputList")["inputs"]}
        if not left.intersection(gone):
            break
        time.sleep(0.1)
    for name, (kind, settings, (x, y, bw, bh), fit) in wanted.items():
        if name in inputs and inputs[name] == kind:
            obs.call("SetInputSettings", {"inputName": name, "inputSettings": settings})
        else:
            obs.call("CreateInput", {"sceneName": OBS_NAME, "inputName": name, "inputKind": kind,
                                     "inputSettings": settings})
        item = obs.call("GetSceneItemId", {"sceneName": OBS_NAME, "sourceName": name})["sceneItemId"]
        if fit:  # text: as large as fits, centred, with some air around it
            pad = min(bw, bh) * 0.12
            tr = {"positionX": x + bw / 2, "positionY": y + bh / 2, "alignment": 0,
                  "boundsType": "OBS_BOUNDS_SCALE_INNER", "boundsAlignment": 0,
                  "boundsWidth": max(bw - 2 * pad, 2), "boundsHeight": max(bh - 2 * pad, 2)}
        else:
            tr = {"positionX": x, "positionY": y, "alignment": 5, "boundsType": "OBS_BOUNDS_STRETCH",
                  "boundsAlignment": 0, "boundsWidth": bw, "boundsHeight": bh}
        obs.call("SetSceneItemTransform", {"sceneName": OBS_NAME, "sceneItemId": item, "sceneItemTransform": tr})
        top = len(obs.call("GetSceneItemList", {"sceneName": OBS_NAME})["sceneItems"]) - 1
        obs.call("SetSceneItemIndex", {"sceneName": OBS_NAME, "sceneItemId": item, "sceneItemIndex": top})


def overlays_for_game(obs, cfg, game):
    """Each box can be off in a game (22 Oct, the user's wish: not in CS2) – shown or hidden in
    OBS's scene when a recording starts. game None (the test) = all of them."""
    for i, ov in enumerate(cfg.get("overlays") or [], 1):
        on = game is None or game in (ov.get("games") or ["wow", "cs2"])
        for name in (f"{OVERLAY_PREFIX}{i}", f"{OVERLAY_PREFIX}{i} text"):
            try:
                item = obs.call("GetSceneItemId", {"sceneName": OBS_NAME, "sourceName": name})["sceneItemId"]
            except OBSError:
                continue  # no text in this box
            obs.call("SetSceneItemEnabled", {"sceneName": OBS_NAME, "sceneItemId": item,
                                             "sceneItemEnabled": on}, check=False)


def overlay_kind(ov):
    return "image_source" if ov.get("file") else "color_source_v3"


def add_overlay_image(src):
    """Copy an image into GoblinRecorder's own folder (stays when the original moves)."""
    OVERLAY_DIR.mkdir(parents=True, exist_ok=True)
    src = Path(src)
    dest = OVERLAY_DIR / f"{secrets.token_hex(4)}{src.suffix.lower()}"
    shutil.copyfile(src, dest)
    return str(dest)


def remove_unused_overlay_images(cfg):
    used = {ov.get("file") for ov in cfg.get("overlays") or []}
    for f in OVERLAY_DIR.glob("*"):
        if str(f) not in used:
            try:
                f.unlink()
            except OSError:
                pass


def preview_image(obs, width=960):
    """The screen OBS records right now, without our boxes, as a data: URL (for the
    window's overlay editor)."""
    return obs.call("GetSourceScreenshot", {"sourceName": "Skärm", "imageFormat": "jpg",
                                            "imageWidth": width, "imageCompressionQuality": 80})["imageData"]


MIC = "Mikrofon"
# A noise gate after RNNoise (12 Oct, the user's breathing was heard a lot): the microphone
# closes below speech. Normal = OBS's own defaults; strong for a sensitive microphone.
MIC_GATES = {"normal": {"open_threshold": -26.0, "close_threshold": -32.0},
             "strong": {"open_threshold": -20.0, "close_threshold": -26.0}}
MIC_GATE = "Brusspärr"
# Against the keyboard (16 Oct, the user: "Stäng mellan orden" let the keys through loud, "Stäng
# mer" cut the words): the gate opens on the peak level, and a key click is short but loud. OBS's
# expander as a gate instead, on the RMS level – speech is loud for a while, a click too short to
# lift it (the 30 ms attack smooths it further) – so the threshold can stay low enough for the
# words. On the filter "Tangentspärr", the gate is off then.
MIC_KEYS = "Tangentspärr"
MIC_KEYS_SETTINGS = {"presets": "gate", "detector": "RMS", "ratio": 10.0, "threshold": -32.0,
                     "attack_time": 30, "release_time": 200, "output_gain": 0.0}


def set_audio(obs, cfg):
    """Your microphone (the system's default one, with RNNoise noise suppression and a noise
    gate against breathing – or the expander against the keyboard) on tracks
    1 and 3, and the game sound boosted – a limiter keeps it from clipping. Works while
    OBS runs."""
    inputs = {i["inputName"] for i in obs.call("GetInputList")["inputs"]}
    if MIC not in inputs:
        obs.call("CreateInput", {"sceneName": OBS_NAME, "inputName": MIC, "inputKind": "pulse_input_capture",
                                 "inputSettings": {"device_id": "default"}})
    filters = {f["filterName"] for f in obs.call("GetSourceFilterList", {"sourceName": MIC})["filters"]}
    if "Brusreducering" not in filters:
        obs.call("CreateSourceFilter", {"sourceName": MIC, "filterName": "Brusreducering",
                                        "filterKind": "noise_suppress_filter_v2",
                                        "filterSettings": {"method": "rnnoise"}}, check=False)
    mode = cfg.get("micGate", "normal")
    gate = MIC_GATES.get(mode)
    settings = dict(gate or MIC_GATES["normal"], attack_time=25, hold_time=200, release_time=150)
    if MIC_GATE not in filters:
        obs.call("CreateSourceFilter", {"sourceName": MIC, "filterName": MIC_GATE, "filterKind": "noise_gate_filter",
                                        "filterSettings": settings}, check=False)
    else:
        obs.call("SetSourceFilterSettings", {"sourceName": MIC, "filterName": MIC_GATE,
                                             "filterSettings": settings}, check=False)
    obs.call("SetSourceFilterEnabled", {"sourceName": MIC, "filterName": MIC_GATE,
                                        "filterEnabled": gate is not None}, check=False)
    if MIC_KEYS not in filters:
        obs.call("CreateSourceFilter", {"sourceName": MIC, "filterName": MIC_KEYS, "filterKind": "expander_filter",
                                        "filterSettings": MIC_KEYS_SETTINGS}, check=False)
    else:
        obs.call("SetSourceFilterSettings", {"sourceName": MIC, "filterName": MIC_KEYS,
                                             "filterSettings": MIC_KEYS_SETTINGS}, check=False)
    obs.call("SetSourceFilterEnabled", {"sourceName": MIC, "filterName": MIC_KEYS,
                                        "filterEnabled": mode == "keys"}, check=False)
    on = bool(cfg.get("mic", True)) and not only_wow(cfg)
    obs.call("SetInputAudioTracks", {"inputName": MIC, "inputAudioTracks":
             {str(t): on and t in (1, 3) for t in range(1, 7)}})
    if "Discord-ljud" in inputs:
        obs.call("SetInputAudioTracks", {"inputName": "Discord-ljud", "inputAudioTracks":
                 {str(t): not only_wow(cfg) and t in (1, 3) for t in range(1, 7)}}, check=False)
    if "WoW-ljud" in inputs:
        boost = float(cfg.get("gameBoost", 12))
        obs.call("SetInputVolume", {"inputName": "WoW-ljud", "inputVolumeDb": boost})
        filters = {f["filterName"] for f in obs.call("GetSourceFilterList", {"sourceName": "WoW-ljud"})["filters"]}
        if "Spärr" not in filters:
            obs.call("CreateSourceFilter", {"sourceName": "WoW-ljud", "filterName": "Spärr",
                                            "filterKind": "limiter_filter",
                                            "filterSettings": {"threshold": -3.0, "release_time": 60}}, check=False)


def main_screen_size():
    """Width and height of the main screen (priority 1 in the display settings)."""
    try:
        out = subprocess.run(["kscreen-doctor", "-j"], capture_output=True, text=True, timeout=10).stdout
        screens = [o for o in json.loads(out)["outputs"] if o.get("enabled", True) and o.get("connected", True)]
    except (OSError, ValueError, KeyError, subprocess.TimeoutExpired):
        return None
    if not screens:
        return None
    main = min(screens, key=lambda o: o.get("priority") or 99)
    mode = next((m for m in main["modes"] if m["id"] == main["currentModeId"]), None)
    size = (mode or {}).get("size") or main.get("size")
    return (size["width"], size["height"]) if size else None


def fit_screen(obs, w, h):
    """The screen capture fills the whole video, whatever screen is picked."""
    for item in obs.call("GetSceneItemList", {"sceneName": OBS_NAME})["sceneItems"]:
        if item["sourceName"] == "Skärm":
            obs.call("SetSceneItemTransform", {"sceneName": OBS_NAME, "sceneItemId": item["sceneItemId"],
                     "sceneItemTransform": {"positionX": 0, "positionY": 0, "boundsType": "OBS_BOUNDS_SCALE_INNER",
                                            "boundsWidth": w, "boundsHeight": h, "boundsAlignment": 0}},
                     check=False)


# ---------------------------------------------------------------- the combat log

LINE = re.compile(r"^(\d+)/(\d+)/(\d{4}) (\d+):(\d+):(\d+)\.(\d+)  ([A-Z_]+),(.*)$")


def split_args(rest):
    """WoW's comma separated values; quoted strings may contain commas."""
    out, cur, quoted = [], [], False
    for ch in rest:
        if ch == '"':
            quoted = not quoted
        elif ch == "," and not quoted:
            out.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    out.append("".join(cur))
    return out


def parse_line(line):
    m = LINE.match(line)
    if not m:
        return None
    mo, d, y, h, mi, s, frac, event, rest = m.groups()
    t = datetime(int(y), int(mo), int(d), int(h), int(mi), int(s)).timestamp()
    t += int(frac) / 10 ** len(frac)
    return t, event, rest


def log_dirs():
    return [Path(p) for p in glob.glob(str(WOW_LOGS / "*/Logs"))]


def newest_log():
    files = []
    for d in log_dirs():
        files += d.glob("WoWCombatLog*.txt")
    return max(files, key=lambda p: p.stat().st_mtime) if files else None


def wow_running():
    if os.environ.get("GOBLINCAKES_RECORDER_WOW"):  # tests: pretend WoW runs
        return True
    return subprocess.run(["pgrep", "-f", r"/_[a-z_]+_/Wow[A-Za-z]*\.exe"],
                          capture_output=True).returncode == 0


# ---------------------------------------------------------------- Counter-Strike 2
# CS2 has no combat log; it sends its game state itself (Valve's Game State Integration):
# a file gamestate_integration_*.cfg in the game's cfg folder – Valve's intended way, the
# user's decision 22 Oct – makes CS2 POST JSON to us on every change. As a player you
# only get your own data (after your death: the player you watch – compare the steamid).

CS2_PORT = 37730
CS2_CFG = "gamestate_integration_goblincakes.cfg"
CS2_OLD_TEST = "gamestate_integration_goblincake.cfg"  # the probe of 17 Oct (port 3000)
CS2_MODES = {"competitive": "Competitive", "scrimcomp2v2": "Wingman", "casual": "Casual",
             "deathmatch": "Deathmatch"}  # GSI's map.mode → the name on the video (all modes are recorded)
STEAM_ROOTS = [HOME / ".local/share/Steam", HOME / ".steam/steam",
               HOME / ".var/app/com.valvesoftware.Steam/.local/share/Steam"]


def cs2_cfg_dir():
    """The game's cfg folder in whichever Steam library CS2 is in, or None."""
    libraries = []
    for root in STEAM_ROOTS:
        libraries.append(root)
        try:
            text = (root / "steamapps/libraryfolders.vdf").read_text(errors="replace")
        except OSError:
            continue
        libraries += [Path(p.replace("\\\\", "\\")) for p in re.findall(r'"path"\s+"([^"]+)"', text)]
    for lib in libraries:
        d = lib / "steamapps/common/Counter-Strike Global Offensive/game/csgo/cfg"
        if d.is_dir():
            return d
    return None


def cs2_token():
    """CS2 sends this with every message – what else posts to the port is not listened to.
    Made once and kept in recorder.json (read fresh: the window and the service share it)."""
    cfg = load_config()
    if not cfg.get("cs2Token"):
        cfg["cs2Token"] = secrets.token_hex(16)
        save_config(cfg)
    return cfg["cs2Token"]


def cs2_cfg_text(token):
    return f'''"GOBLINCAKES GoblinRecorder"
{{
    "uri" "http://127.0.0.1:{CS2_PORT}"
    "timeout" "5.0"
    "buffer" "0"
    "throttle" "0.1"
    "heartbeat" "10.0"
    "auth"
    {{
        "token" "{token}"
    }}
    "data"
    {{
        "provider" "1"
        "map" "1"
        "round" "1"
        "player_id" "1"
        "player_state" "1"
        "player_match_stats" "1"
    }}
}}
'''


def cs2_state():
    """nogame = CS2 not found, off = not connected, on = connected, old = our file but
    another token (a new config) – connect again."""
    d = cs2_cfg_dir()
    if not d:
        return "nogame"
    try:
        text = (d / CS2_CFG).read_text()
    except OSError:
        return "off"
    return "on" if f'"token" "{cs2_token()}"' in text else "old"


def cs2_connect():
    """Puts our file in CS2's cfg folder (and takes away the probe's). An error text or ""."""
    d = cs2_cfg_dir()
    if not d:
        return "Hittar inte Counter-Strike 2 i Steam-biblioteken."
    try:
        (d / CS2_CFG).write_text(cs2_cfg_text(cs2_token()))
        old = d / CS2_OLD_TEST
        if old.exists() and "GOBLINCAKES test" in old.read_text(errors="replace"):
            old.unlink()
    except OSError as e:
        return f"Kunde inte skriva filen: {e}"
    return ""


def cs2_disconnect():
    d = cs2_cfg_dir()
    if d:
        try:
            (d / CS2_CFG).unlink(missing_ok=True)
        except OSError as e:
            return f"Kunde inte ta bort filen: {e}"
    return ""


def cs2_running():
    if os.environ.get("GOBLINCAKES_RECORDER_CS2"):  # tests: pretend CS2 runs
        return True
    return subprocess.run(["pgrep", "-x", "cs2"], capture_output=True).returncode == 0


def cs2_map_name(raw):
    """de_mirage → Mirage, cs_office → Office, workshop/123/aim_map → aim_map."""
    name = raw.rsplit("/", 1)[-1]
    if re.match(r"^(de|cs|ar|dz|gd)_", name):
        name = name.split("_", 1)[1].replace("_", " ").title()
    return name


def cs2_has_rounds(mode):
    """Deathmatch (and Arms Race) have no rounds: round_kills just grows, and there is no score."""
    return mode not in ("deathmatch", "gungameprogressive")


def cs2_kill_text(n, headshot):
    return ({1: "Kill", 5: "ACE"}.get(n) or f"{n}K") + (" · HS" if headshot else "")


# The match → clips (22 Oct, the user's wish – a whole match is 7–10 GB on Bäst): every 2K–ACE
# as its own clip, a reel with all your kills, then the whole match goes. Cut without
# re-encoding (keyframes every 2 s – a clip may start up to 2 s earlier), all audio tracks.
CLIP_BEFORE, CLIP_AFTER = 5.0, 3.0  # 2K–ACE: from the first kill of the round to the last
REEL_BEFORE, REEL_AFTER = 3.0, 1.5  # each kill in the reel …
REEL_JOIN = 8.0  # … and kills at most this far apart become one piece (22 Oct, the user: it jumped
# from a kill straight to a death without what happened between)


def cs2_clip_plan(meta):
    """[(label, round, start, end, [kill times])] for the multikills, and the reel's pieces
    [(start, end, [kill times])]."""
    dur = meta.get("duration") or 0
    rounds = cs2_has_rounds(meta.get("mode"))
    rnd, per_round = 1, {}
    kills = []
    for m in sorted(meta.get("markers", []), key=lambda m: m["t"]):
        if m["kind"] == "round":
            rnd += 1
        elif m["kind"] == "kill":
            kills.append(m["t"])
            per_round.setdefault(rnd, []).append(m["t"])
    multi = []
    if rounds:
        for r, ts in sorted(per_round.items()):
            if len(ts) >= 2:
                label = "ACE" if len(ts) >= 5 else f"{len(ts)}K"
                multi.append((label, r, max(ts[0] - CLIP_BEFORE, 0), min(ts[-1] + CLIP_AFTER, dur), ts))
    pieces = []
    spawns = meta.get("spawns")
    if spawns is None:  # videos from before 22 Oct: about when you were back after a death
        spawns = [m["t"] + 1.0 for m in meta.get("markers", []) if m["kind"] == "death"]
    for t in kills:
        s, e = max(t - REEL_BEFORE, 0), min(t + REEL_AFTER, dur)
        s = max([s] + [sp for sp in spawns if sp < t])  # just spawned: not from the death screen
        if pieces and t - pieces[-1][2][-1] <= REEL_JOIN:
            pieces[-1] = (pieces[-1][0], e, pieces[-1][2] + [t])
        else:
            pieces.append((s, e, [t]))
    return multi, pieces


def video_length(path):
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0",
                        str(path)], capture_output=True, text=True)
    try:
        return float(r.stdout.strip())
    except ValueError:
        return 0.0


def cut_copy(video, start, end, dest):
    """All streams (the three audio tracks too), no re-encoding. True if the file is there.
    A .ts piece (for the reel): MPEG-TS joins without the time stamp jumps MP4 pieces gave."""
    out = ["-f", "mpegts"] if dest.suffix == ".ts" else ["-avoid_negative_ts", "make_zero", "-movflags", "+faststart"]
    r = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", f"{start:.3f}",
                        "-i", str(video), "-t", f"{end - start:.3f}", "-map", "0", "-c", "copy", *out, str(dest)],
                       capture_output=True, text=True)
    return r.returncode == 0 and video_length(dest) > 0.5


def cs2_make_clips(meta_path, keep_match=False):
    """Makes the clips of a CS2 match (each with its own .json, "parent" = the match) and, when
    they are all there, removes the match's video (its .json and picture stay, for the card).
    Returns (the clips' names, error text)."""
    meta_path = Path(meta_path)
    meta = json.loads(meta_path.read_text())
    folder, video = meta_path.parent, meta_path.parent / meta["file"]
    if not video.is_file():
        return [], "Matchens film finns inte."
    multi, pieces = cs2_clip_plan(meta)
    base = Path(meta["file"]).stem
    made, todo = [], []
    shared = {k: meta.get(k) for k in ("name", "difficulty", "result", "score", "tracks", "codec", "fps",
                                       "player", "map", "mode")}

    def clip_meta(dest, label, rnd, start, length, marks):
        data = dict(shared, file=dest.name, kind="cs2clip", parent=meta["file"], clip=label, round=rnd,
                    started=meta["started"] + start, fight=length, duration=length, fightStart=0,
                    markers=marks)
        dest.with_suffix(".json").write_text(json.dumps(data, ensure_ascii=False, indent=1))
        make_thumb(dest, min(max((marks[0]["t"] if marks else 1) - 0.5, 0), max(length - 0.5, 0)),
                   dest.with_suffix(".jpg"))
        made.append(dest.name)

    for label, rnd, start, end, ts in multi:
        dest = folder / (safe_name(f"{base} – {label} runda {rnd}") + video.suffix)
        todo.append(dest)
        if cut_copy(video, start, end, dest):
            length = video_length(dest)
            lead = length - (end - start)  # the cut starts on the keyframe before
            marks = [{"t": round(t - start + lead, 2), "kind": "kill", "text": m["text"]}
                     for m in meta["markers"] if m["kind"] == "kill" and start <= m["t"] <= end for t in [m["t"]]]
            clip_meta(dest, label, rnd, start, length, marks)
    if pieces:
        dest = folder / (safe_name(f"{base} – alla kills") + video.suffix)
        todo.append(dest)
        tmp = folder / f".goblincakes-reel-{os.getpid()}"
        tmp.mkdir(exist_ok=True)
        try:
            parts, marks, at = [], [], 0.0
            texts = {m["t"]: m["text"] for m in meta["markers"] if m["kind"] == "kill"}
            for i, (s, e, ts) in enumerate(pieces):
                part = tmp / f"{i:04d}.ts"
                if not cut_copy(video, s, e, part):
                    continue
                length = video_length(part)
                lead = length - (e - s)
                marks += [{"t": round(at + t - s + lead, 2), "kind": "kill", "text": texts.get(t, "Kill")} for t in ts]
                parts.append(part)
                at += length
            (tmp / "list.txt").write_text("".join(f"file '{p.name}'\n" for p in parts))
            r = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0",
                                "-i", str(tmp / "list.txt"), "-map", "0", "-c", "copy", "-movflags", "+faststart",
                                str(dest)], capture_output=True, text=True)
            if parts and r.returncode == 0 and video_length(dest) > 0.5:
                clip_meta(dest, "Alla kills", None, pieces[0][0], video_length(dest), marks)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
    if len(made) < len(todo):
        return made, f"{len(todo) - len(made)} av {len(todo)} klipp gick inte att göra – hela matchen sparas."
    data = json.loads(meta_path.read_text())
    data["clipsMade"] = True
    if made and not keep_match and not data.get("keep") and data.get("demo") != "waiting":
        video.unlink(missing_ok=True)
        data["videoRemoved"] = True
    meta_path.write_text(json.dumps(data, ensure_ascii=False, indent=1))
    return made, ""


# ---------------------------------------------------------------- CS2 step 2: the demo
# (22 Oct, the user's decision) A Competitive/Premier/Wingman match keeps its whole video until
# its demo is read: CS2's own download (Watch → Your Matches → game/csgo/replays/) or your own
# `record` (game/csgo/) is found by the service, or picked by hand (FACEIT …). The demo knows
# what GSI can't: who was alive (clutches), entry kills, trades, damage, accuracy, utility and
# money. Only your own numbers – the other nine are Leetify's job. No demo in 3 days: the video
# goes, the clips and the card stay. The demo files are left where they are.
DEMO_LIB = Path(os.environ.get("GOBLINCAKES_DEMOPARSER", "/usr/lib/goblincakes/demoparser"))  # the image's build
DEMO_MODES = ("competitive", "scrimcomp2v2", "premier")  # Valve keeps demos of these
DEMO_WAIT = 3 * 24 * 3600
DEMO_SEEN = CACHE_DIR / "cs2-demos.json"  # demos already looked at (path → mtime)
TICKRATE = 64
TRADE_TIME = 5.0  # killing the enemy who killed your teammate this soon after = a trade
CLUTCH_BEFORE, CLUTCH_AFTER = 3.0, 3.0
ALIGN_SLACK = 1.5  # GSI's times and the demo's ticks may differ this much and still pair
NOT_GUNS = re.compile(r"knife|bayonet|grenade|flashbang|smoke|molotov|decoy|inferno|c4|taser|world")
# player_hurt names only the base gun (an M4A1-S hit = "m4a1") – fires and kills name the real one
SAME_GUN = {"m4a1_silencer": "m4a1", "m4a1_silencer_off": "m4a1", "usp_silencer": "hkp2000",
            "usp_silencer_off": "hkp2000", "revolver": "deagle", "cz75a": "p250"}
GRENADES = {"flashbang": "flash", "smokegrenade": "smoke", "hegrenade": "he", "molotov": "molotov",
            "incgrenade": "molotov", "decoy": "decoy"}
WEAPON_NAMES = {"ak47": "AK-47", "m4a1": "M4A4", "m4a1_silencer": "M4A1-S", "awp": "AWP", "deagle": "Desert Eagle",
                "usp_silencer": "USP-S", "hkp2000": "P2000", "glock": "Glock-18", "p250": "P250",
                "fiveseven": "Five-SeveN", "tec9": "Tec-9", "cz75a": "CZ75-Auto", "elite": "Dual Berettas",
                "revolver": "R8", "ssg08": "SSG 08", "famas": "FAMAS", "galilar": "Galil AR", "aug": "AUG",
                "sg556": "SG 553", "mac10": "MAC-10", "mp9": "MP9", "mp7": "MP7", "mp5sd": "MP5-SD",
                "ump45": "UMP-45", "p90": "P90", "bizon": "PP-Bizon", "nova": "Nova", "xm1014": "XM1014",
                "mag7": "MAG-7", "sawedoff": "Sawed-Off", "negev": "Negev", "m249": "M249",
                "g3sg1": "G3SG1", "scar20": "SCAR-20", "taser": "Zeus", "hegrenade": "HE-granat",
                "inferno": "molotov", "knife": "kniv"}


def weapon_name(raw):
    w = str(raw or "").removeprefix("weapon_")
    if w.startswith(("knife", "bayonet")):
        return "kniv"
    return WEAPON_NAMES.get(w, w.upper() if w else "?")


def cs2_demo_dirs():
    """Where CS2 puts demos: replays/ (Watch → Your Matches) and csgo/ (your own `record`)."""
    d = cs2_cfg_dir()
    return [d.parent / "replays", d.parent] if d else []


def cs2_demo_files():
    out = []
    for d in cs2_demo_dirs():
        out += [p for p in d.glob("*.dem") if p.is_file()]
    return sorted(out, key=lambda p: p.stat().st_mtime)


def cs2_waiting(folder):
    """The matches whose video waits for a demo, oldest first."""
    return sorted((v for v in video_files(folder) if v.get("kind") == "cs2" and v.get("demo") == "waiting"),
                  key=lambda v: v.get("started", 0))


def demoparser_ok():
    return (DEMO_LIB / "demoparser2").is_dir()


def _sid(v):
    """A steamid from the demo as text ("" for none – pandas gives NaN)."""
    return "" if v is None or v != v or v == "" else str(v).split(".")[0]


def cs2_demo_load(path):
    """What we use of a demo, as plain lists (no pandas outside this function)."""
    if str(DEMO_LIB) not in sys.path:
        sys.path.insert(0, str(DEMO_LIB))
    from demoparser2 import DemoParser  # noqa: PLC0415 – ~490 MB of libraries, only when a demo is read

    p = DemoParser(str(path))

    def rows(event, **kw):
        try:
            df = p.parse_event(event, **kw)
        except Exception:  # noqa: BLE001 – an event the demo doesn't have
            return []
        return df.to_dict("records") if df is not None and len(df) else []

    live = [r["tick"] for r in rows("round_announce_match_start")] or [r["tick"] for r in rows("begin_new_match")]
    start = max(live) if live else 0
    other = {"other": ["is_warmup_period"]}

    def live_rows(event, **kw):
        return sorted((r for r in rows(event, **kw, **other) if r["tick"] >= start and not r.get("is_warmup_period")),
                      key=lambda r: r["tick"])

    round_ends = [{"tick": r["tick"], "winner": int(r.get("winner") or 0)} for r in live_rows("round_end")]
    freeze = [r["tick"] for r in live_rows("round_freeze_end")]
    at = {}  # freeze-end tick → {steamid: [team, alive, equipment value]}
    if freeze:
        try:
            df = p.parse_ticks(["team_num", "is_alive", "current_equip_value"], ticks=freeze)
            for r in df.to_dict("records"):
                at.setdefault(r["tick"], {})[_sid(r["steamid"])] = [int(r["team_num"] or 0), bool(r["is_alive"]),
                                                                    int(r["current_equip_value"] or 0)]
        except Exception:  # noqa: BLE001
            pass
    players = {}
    try:
        for r in p.parse_player_info().to_dict("records"):
            players[_sid(r["steamid"])] = str(r["name"])
    except Exception:  # noqa: BLE001
        pass
    return {
        "map": p.parse_header().get("map_name", ""), "players": players, "start": start,
        "roundEnds": round_ends, "freeze": [{"tick": t, "players": at.get(t, {})} for t in freeze],
        "deaths": [{"tick": r["tick"], "victim": _sid(r.get("user_steamid")), "killer": _sid(r.get("attacker_steamid")),
                    "assister": _sid(r.get("assister_steamid")), "flash": bool(r.get("assistedflash")),
                    "weapon": str(r.get("weapon") or ""), "hs": bool(r.get("headshot")),
                    "wall": int(r.get("penetrated") or 0) > 0, "smoke": bool(r.get("thrusmoke")),
                    "noscope": bool(r.get("noscope")), "blind": bool(r.get("attackerblind"))}
                   for r in live_rows("player_death")],
        "hurts": [{"tick": r["tick"], "victim": _sid(r.get("user_steamid")), "attacker": _sid(r.get("attacker_steamid")),
                   "dmg": int(r.get("dmg_health") or 0), "health": int(r.get("health") or 0),
                   "weapon": str(r.get("weapon") or "")} for r in live_rows("player_hurt")],
        "fires": [{"tick": r["tick"], "who": _sid(r.get("user_steamid")), "weapon": str(r.get("weapon") or "")}
                  for r in live_rows("weapon_fire")],
        "blinds": [{"tick": r["tick"], "victim": _sid(r.get("user_steamid")), "attacker": _sid(r.get("attacker_steamid")),
                    "time": float(r.get("blind_duration") or 0)} for r in live_rows("player_blind")],
    }


def cs2_demo_me(raw, steamid="", name=""):
    """Your steamid in the demo – by the id GSI gave, or by the name (videos from before step 2)."""
    if steamid and steamid in raw["players"]:
        return steamid
    for sid, n in raw["players"].items():
        if name and n.strip().lower() == name.strip().lower():
            return sid
    return ""


def cs2_demo_analyse(raw, me):
    """Your match from the demo: kills (weapon, wallbang, smoke, entry, trade), clutches, the
    numbers (K/D, ADR, KAST, HS %, accuracy per weapon, utility, money) and each round."""
    ends = raw["roundEnds"]
    n = len(ends)

    def round_of(tick):  # the round a tick belongs to (None after the last round's end)
        for i, e in enumerate(ends):
            if tick <= e["tick"]:
                return i
        return None

    teams = [{} for _ in range(n)]  # per round: steamid → team
    alive0 = [set() for _ in range(n)]
    equip = [None] * n  # your equipment's value when the round starts (none: ended before, a surrender)
    last = {}
    for f in raw["freeze"]:
        r = round_of(f["tick"])
        if r is not None:
            teams[r] = {sid: v[0] for sid, v in f["players"].items() if v[0] in (2, 3)}
            alive0[r] = {sid for sid, v in f["players"].items() if v[0] in (2, 3) and v[1]}
            if me in f["players"]:
                equip[r] = f["players"][me][2]
    for r in range(n):  # a round without its freeze end: the round before's teams
        if not teams[r] and last:
            teams[r], alive0[r] = dict(last["t"]), set(last["a"])
        if teams[r]:
            last = {"t": teams[r], "a": alive0[r]}
    my_team = [teams[r].get(me, 0) for r in range(n)]

    def enemy(r, sid):
        return bool(sid) and teams[r].get(sid) not in (None, my_team[r])

    def mate(r, sid):
        return bool(sid) and sid != me and teams[r].get(sid) == my_team[r]

    kills, deaths, assists, flash_assists = [], [], 0, 0
    clutches = []
    rounds = [{"r": r + 1, "won": ends[r]["winner"] == my_team[r] and my_team[r] > 0, "k": 0, "dmg": 0,
               "died": False, "kast": False, "equip": equip[r], "clutch": 0} for r in range(n)]
    entry = {"won": 0, "lost": 0}
    trades = traded = 0
    by_round = {}
    for d in raw["deaths"]:
        r = round_of(d["tick"])
        if r is not None and my_team[r]:
            by_round.setdefault(r, []).append(d)
    for r, ds in by_round.items():
        alive = set(alive0[r])
        first = True
        clutch = None
        mate_deaths = []  # (tick, killer)
        for d in ds:
            alive.discard(d["victim"])
            if d["killer"] == me and enemy(r, d["victim"]):
                k = dict(d, round=r + 1, entry=first, trade=any(d["tick"] - t <= TRADE_TIME * TICKRATE and kr == d["victim"]
                                                                 for t, kr in mate_deaths))
                kills.append(k)
                rounds[r]["k"] += 1
                trades += k["trade"]
                if first:
                    entry["won"] += 1
            elif d["victim"] == me:
                rounds[r]["died"] = True
                deaths.append(dict(d, round=r + 1))
                if first and enemy(r, d["killer"]):
                    entry["lost"] += 1
                # traded: a teammate killed your killer soon after
                if any(o["killer"] != me and mate(r, o["killer"]) and o["victim"] == d["killer"]
                       and 0 <= o["tick"] - d["tick"] <= TRADE_TIME * TICKRATE for o in ds):
                    rounds[r]["kast"] = True
                    traded += 1
            elif mate(r, d["victim"]):
                mate_deaths.append((d["tick"], d["killer"]))
            if d["assister"] == me and enemy(r, d["victim"]):
                assists += 1
                flash_assists += d["flash"]
                rounds[r]["kast"] = True
            if enemy(r, d["killer"]) or enemy(r, d["victim"]):
                first = False
            mine = {s for s in alive if teams[r].get(s) == my_team[r]}
            theirs = {s for s in alive if enemy(r, s)}
            if clutch is None and mine == {me} and theirs:
                clutch = {"round": r + 1, "vs": len(theirs), "start": d["tick"], "end": ends[r]["tick"],
                          "won": rounds[r]["won"]}
        if clutch:
            clutch["kills"] = sum(1 for k in kills if k["round"] == r + 1 and k["tick"] >= clutch["start"])
            clutches.append(clutch)
            rounds[r]["clutch"] = clutch["vs"] if clutch["won"] else -clutch["vs"]
    for rd in rounds:
        rd["kast"] = rd["kast"] or rd["k"] > 0 or not rd["died"]

    # damage (capped at the health the enemy had left), hits and shots per weapon
    health, dmg, util = {}, 0, {"heDmg": 0, "fireDmg": 0}
    weapons, variant = {}, {}  # base gun → numbers; base gun → {the name you shot with: shots}

    def gun(w, count=0):
        base = SAME_GUN.get(w, w)
        v = variant.setdefault(base, {})
        v[w] = v.get(w, 0) + count
        return weapons.setdefault(base, {"shots": 0, "hits": 0, "kills": 0, "hs": 0})
    for h in raw["hurts"]:
        r = round_of(h["tick"])
        if r is None or h["attacker"] != me or not enemy(r, h["victim"]):
            continue
        real = min(h["dmg"], health.get((r, h["victim"]), 100))
        health[(r, h["victim"])] = h["health"]
        dmg += real
        rounds[r]["dmg"] += real
        w = h["weapon"].removeprefix("weapon_")
        if w == "hegrenade":
            util["heDmg"] += real
        elif w in ("inferno", "molotov", "incgrenade"):
            util["fireDmg"] += real
        elif w and not NOT_GUNS.search(w):
            gun(w)["hits"] += 1
    thrown = {"flash": 0, "smoke": 0, "he": 0, "molotov": 0, "decoy": 0}
    for f in raw["fires"]:
        if f["who"] != me or round_of(f["tick"]) is None:
            continue
        w = f["weapon"].removeprefix("weapon_")
        if w in GRENADES:
            thrown[GRENADES[w]] += 1
        elif w and not NOT_GUNS.search(w):
            gun(w, 1)["shots"] += 1
    for k in kills:
        w = k["weapon"].removeprefix("weapon_")
        if w and not NOT_GUNS.search(w):
            g = gun(w, 1)
            g["kills"] += 1
            g["hs"] += k["hs"]
    flashed = sum(1 for b in raw["blinds"] if b["attacker"] == me and b["time"] >= 1.0
                  and (r := round_of(b["tick"])) is not None and enemy(r, b["victim"]))
    team_flashed = sum(1 for b in raw["blinds"] if b["attacker"] == me and b["time"] >= 1.0
                       and (r := round_of(b["tick"])) is not None and mate(r, b["victim"]))

    nk, nd = len(kills), len(deaths)
    played = max(n, 1)
    buys = {"eco": [], "force": [], "full": []}
    bought = [rd for rd in rounds if rd["equip"] is not None]
    for rd in bought:
        buys["eco" if rd["equip"] < 1500 else "force" if rd["equip"] < 4000 else "full"].append(rd)
    stats = {
        "kills": nk, "deaths": nd, "assists": assists, "kd": round(nk / max(nd, 1), 2),
        "adr": round(dmg / played, 1), "kast": round(100 * sum(rd["kast"] for rd in rounds) / played),
        "hs": round(100 * sum(k["hs"] for k in kills) / max(nk, 1)),
        "entryWon": entry["won"], "entryLost": entry["lost"], "trades": trades, "traded": traded,
        "clutchWon": sum(c["won"] for c in clutches), "clutches": len(clutches),
        "multi": {f"{c}K" if c < 5 else "ACE": sum(1 for rd in rounds if (rd["k"] == c if c < 5 else rd["k"] >= 5))
                  for c in (2, 3, 4, 5)},
        "wallbangs": sum(k["wall"] for k in kills), "smokeKills": sum(k["smoke"] for k in kills),
        "noscopes": sum(k["noscope"] for k in kills), "blindKills": sum(k["blind"] for k in kills),
        "thrown": thrown, "flashed": flashed, "teamFlashed": team_flashed, "flashAssists": flash_assists, **util,
        "weapons": sorted(({"name": weapon_name(max(variant[w], key=variant[w].get)), **v, "acc": round(100 * v["hits"] / v["shots"]) if v["shots"] else None}
                           for w, v in weapons.items() if v["kills"] or v["shots"] >= 5),
                          key=lambda v: (-v["kills"], -v["shots"])),
        "buys": {b: {"rounds": len(rs), "won": sum(rd["won"] for rd in rs), "kills": sum(rd["k"] for rd in rs)}
                 for b, rs in buys.items()},
        "avgEquip": round(sum(rd["equip"] for rd in bought) / max(len(bought), 1)),
    }
    won = sum(rd["won"] for rd in rounds)
    return {"map": raw["map"], "rounds": n, "score": [won, n - won], "kills": kills, "deaths": deaths,
            "clutches": clutches, "stats": stats, "perRound": rounds, "roundEnds": [e["tick"] for e in ends]}


# Time to damage and crosshair placement (22 Oct, the user's wish). Approximate: awpy's map
# geometry (downloaded once per map release to ~/.cache/goblincakes/awpy) says whether you
# could see the enemy through the walls; smokes come from the demo, flashes are not counted.
# An encounter = an enemy you can see (free line of sight, inside the screen, no smoke between)
# after he was out of sight for a second. Placement = the angle from your crosshair to his head
# then; time to damage = from then to your first damage on him (within 2 s).
AWPY_DIR = CACHE_DIR / "awpy"
AWPY_REFRESH = 7 * 24 * 3600  # look for newer map geometry (CS2 updates the maps) this often
AIM_FOV = 53.0  # half of CS2's ~106° wide view (16:9) – an enemy farther out is not on the screen
AIM_GAP = TICKRATE  # out of sight this long and back = a new encounter
TTD_WINDOW = 2 * TICKRATE
SMOKE_RADIUS = 144.0
EYE, DUCK = 64.0, 18.0  # eye height standing, and how much lower crouched


def cs2_map_mesh(map_name):
    """awpy's collision geometry for the map (a download the first time), or None."""
    os.environ["AWPY_DATA_DIR"] = str(AWPY_DIR)
    from awpy import data  # noqa: PLC0415
    try:
        local = data.local_versions()
        old = not local or time.time() - (AWPY_DIR / local[-1]).stat().st_mtime > AWPY_REFRESH
        if old:  # a newer release of the maps? (no network: the cached one)
            socket.setdefaulttimeout(20)
            try:
                return data.mesh_path(map_name, version=int(data.latest_version()))
            except (OSError, ValueError):
                pass
        return data.mesh_path(map_name)
    except (OSError, ValueError, FileNotFoundError):
        return None


def _seg_dist(a, b, c):
    """Distance from point c to the segment a–b."""
    ab = [b[i] - a[i] for i in range(3)]
    ac = [c[i] - a[i] for i in range(3)]
    ll = sum(x * x for x in ab) or 1.0
    k = max(0.0, min(1.0, sum(ab[i] * ac[i] for i in range(3)) / ll))
    return math.dist(c, [a[i] + k * ab[i] for i in range(3)])


def cs2_demo_aim(dem, raw, a, me):
    """{"ttd": ms (median), "cp": degrees (median), and how many encounters each} or {}."""
    mesh = cs2_map_mesh(raw["map"])
    if not mesh:
        return {}
    from awpy import VisibilityChecker  # noqa: PLC0415
    from demoparser2 import DemoParser  # noqa: PLC0415
    vc = VisibilityChecker(mesh)
    p = DemoParser(str(dem))
    ends = a["roundEnds"]
    spans = []  # each round from the end of the freeze time to its end
    for f in raw["freeze"]:
        end = next((e for e in ends if e >= f["tick"]), None)
        if end:
            spans.append((f["tick"], end))
    if not spans:
        return {}
    df = p.parse_ticks(["X", "Y", "Z", "pitch", "yaw", "duck_amount", "is_alive", "team_num"],
                       ticks=[t for s, e in spans for t in range(s, e + 1)])
    df = df.sort_values("tick")
    cols = {c: df[c].tolist() for c in ("tick", "steamid", "X", "Y", "Z", "pitch", "yaw", "duck_amount", "is_alive", "team_num")}
    smokes, started = [], {}
    try:
        for r in p.parse_event("smokegrenade_detonate").to_dict("records"):
            started[r["entityid"]] = (r["tick"], (r["x"], r["y"], r["z"] + 60))
        for r in p.parse_event("smokegrenade_expired").to_dict("records"):
            if r["entityid"] in started:
                t0, c = started.pop(r["entityid"])
                smokes.append((t0, r["tick"], c))
    except Exception:  # noqa: BLE001 – no smokes
        pass
    smokes += [(t0, 10 ** 9, c) for t0, c in started.values()]
    my_hits = {}
    for h in raw["hurts"]:
        if h["attacker"] == me and h["victim"] != me:
            my_hits.setdefault(h["victim"], []).append(h["tick"])
    seen_at, cp, ttd = {}, [], []

    def tick_done(tick, rows):
        mine = rows.get(me)
        if not mine or not mine[6]:
            seen_at.clear()
            return
        x, y, z, pitch, yaw, duck, alive, team = mine[:8]
        eye = (x, y, z + EYE - DUCK * duck)
        pr, yr = math.radians(pitch), math.radians(yaw)
        view = (math.cos(pr) * math.cos(yr), math.cos(pr) * math.sin(yr), -math.sin(pr))
        for sid, (ex, ey, ez, _p, _y, educk, ealive, eteam) in rows.items():
            if sid == me or not ealive or eteam in (team, 0, 1):
                continue
            head = (ex, ey, ez + EYE - DUCK * educk)
            d = math.dist(eye, head) or 1.0
            cosang = sum(view[i] * (head[i] - eye[i]) / d for i in range(3))
            angle = math.degrees(math.acos(max(-1.0, min(1.0, cosang))))
            if angle > AIM_FOV or not vc.is_visible(eye, head):
                continue
            if any(t0 <= tick <= t1 and _seg_dist(eye, head, c) < SMOKE_RADIUS for t0, t1, c in smokes):
                continue
            if tick - seen_at.get(sid, -10 ** 9) > AIM_GAP:  # a new encounter
                cp.append(angle)
                hit = next((t for t in my_hits.get(sid, []) if tick <= t <= tick + TTD_WINDOW), None)
                if hit is not None:
                    ttd.append((hit - tick) * 1000 / TICKRATE)
            seen_at[sid] = tick

    rows, cur = {}, None
    c = cols
    for i in range(len(c["tick"])):
        t = c["tick"][i]
        if t != cur:
            if cur is not None:
                tick_done(cur, rows)
            rows, cur = {}, t
        rows[_sid(c["steamid"][i])] = (c["X"][i], c["Y"][i], c["Z"][i], c["pitch"][i], c["yaw"][i],
                                       c["duck_amount"][i] or 0.0, bool(c["is_alive"][i]), int(c["team_num"][i] or 0))
    if cur is not None:
        tick_done(cur, rows)
    return {"ttd": round(statistics.median(ttd)) if ttd else None, "ttdCount": len(ttd),
            "cp": round(statistics.median(cp), 1) if cp else None, "cpCount": len(cp)}


def cs2_demo_fits(meta, a):
    """Is this demo the match of the video? Same map, you in it, and the same score."""
    if a["map"] and meta.get("map") and a["map"] != meta["map"]:
        return False
    score = re.findall(r"\d+", meta.get("score") or "")
    if len(score) == 2:
        return [int(score[0]), int(score[1])] == a["score"]
    return True


def cs2_demo_offset(meta, a):
    """Video seconds = tick / 64 + offset. The round ends and your kills are in both (GSI
    marked them in the video), paired from the end – a recording that started late (you
    reconnected) misses the first rounds, not the last. None if they don't agree."""
    diffs = []
    for kind, ticks in (("round", a["roundEnds"]), ("kill", [k["tick"] for k in a["kills"]])):
        ts = sorted(m["t"] for m in meta.get("markers", []) if m["kind"] == kind)
        diffs += [t - tick / TICKRATE for t, tick in zip(reversed(ts), reversed(ticks))]
    if len(diffs) < 3:
        return None
    med = statistics.median(diffs)
    good = [d for d in diffs if abs(d - med) <= ALIGN_SLACK]
    if len(good) < max(3, len(diffs) / 2):
        return None
    return statistics.median(good)


def cs2_kill_detail(k):
    parts = [weapon_name(k["weapon"])]
    parts += [t for flag, t in (("noscope", "noscope"), ("wall", "genom vägg"), ("smoke", "genom rök"),
                                ("blind", "bländad"), ("entry", "entry"), ("trade", "trade")) if k.get(flag)]
    return " · ".join(parts)


def cs2_demo_apply(meta_path, dem, a, offset):
    """The demo's knowledge into the match: weapon etc. on the kill marks, a clip per won
    clutch, the numbers on the card; then the whole video goes (as after the clips). Returns
    the text for the notification."""
    meta_path = Path(meta_path)
    meta = json.loads(meta_path.read_text())
    folder, video = meta_path.parent, meta_path.parent / meta["file"]
    # the kill marks get the weapon, wallbang, smoke, entry, trade
    marks = meta.get("markers", [])
    for k in a["kills"]:
        t = k["tick"] / TICKRATE + offset
        near = [m for m in marks if m["kind"] == "kill" and abs(m["t"] - t) <= ALIGN_SLACK and "·" not in m["text"].replace(" · HS", "")]
        if near:
            m = min(near, key=lambda m: abs(m["t"] - t))
            m["text"] += " · " + cs2_kill_detail(k)
    made = []
    if video.is_file():
        base = Path(meta["file"]).stem
        dur = meta.get("duration") or video_length(video)
        ends = [e / TICKRATE + offset for e in a["roundEnds"]]
        for c in a["clutches"]:
            if not c["won"]:
                continue
            r = c["round"] - 1
            round_start = ends[r - 1] if r > 0 else 0
            start = max(c["start"] / TICKRATE + offset - CLUTCH_BEFORE, round_start, 0)
            end = min(c["end"] / TICKRATE + offset + CLUTCH_AFTER, dur)
            label = f"Clutch 1v{c['vs']}"
            dest = folder / (safe_name(f"{base} – {label} runda {c['round']}") + video.suffix)
            if end - start < 1 or not cut_copy(video, start, end, dest):
                continue
            length = video_length(dest)
            lead = length - (end - start)
            cm = [{"t": round(m["t"] - start + lead, 2), "kind": m["kind"], "text": m["text"]}
                  for m in marks if m["kind"] in ("kill", "death") and start <= m["t"] <= end]
            data = {k: meta.get(k) for k in ("name", "difficulty", "result", "score", "tracks", "codec", "fps",
                                             "player", "map", "mode")}
            data.update(file=dest.name, kind="cs2clip", parent=meta["file"], clip=label, round=c["round"],
                        started=meta["started"] + start, fight=length, duration=length, fightStart=0, markers=cm)
            dest.with_suffix(".json").write_text(json.dumps(data, ensure_ascii=False, indent=1))
            make_thumb(dest, min(max((cm[0]["t"] if cm else 1) - 0.5, 0), max(length - 0.5, 0)), dest.with_suffix(".jpg"))
            made.append(dest.name)
    data = json.loads(meta_path.read_text())
    data.update(markers=marks, demo="done", demoFile=str(dem), demoStats=a["stats"], demoRounds=a["perRound"])
    meta_path.write_text(json.dumps(data, ensure_ascii=False, indent=1))
    cs2_drop_match_video(meta_path)
    won = sum(c["won"] for c in a["clutches"])
    text = f"Demon för {meta.get('name', 'matchen')} är läst"
    return text + (f" – {won} {'clutch' if won == 1 else 'clutchar'}" if won else f" – ADR {a['stats']['adr']:g}")


def cs2_drop_match_video(meta_path):
    """The whole match's video goes when it has clips, unless kept (Behåll hela matchen /
    Spara för alltid)."""
    meta_path = Path(meta_path)
    data = json.loads(meta_path.read_text())
    video = meta_path.parent / data["file"]
    if (data.get("keep") or load_config().get("cs2KeepMatch") or not video.is_file()
            or not match_clips(meta_path.parent, data["file"])):
        return False
    video.unlink(missing_ok=True)
    data["videoRemoved"] = True
    meta_path.write_text(json.dumps(data, ensure_ascii=False, indent=1))
    return True


def cs2_demo_skip(meta_path, expired=False):
    """Klar utan demo (or 3 days passed): the clips and the card stay, the whole video goes."""
    set_meta(meta_path, demo="expired" if expired else "none")
    cs2_drop_match_video(Path(meta_path).with_suffix(".json"))


def cs2_demo_run(dem, meta_path=None):
    """Reads a demo and gives it to its match: the one given (picked by hand), else the
    waiting match it fits. {"match": file, "text": …} or {"error": …} or {"match": None}."""
    if not demoparser_ok():
        return {"error": "demoparser2 saknas – den kommer med nästa GOBLINCAKES-uppdatering."}
    try:
        raw = cs2_demo_load(dem)
    except Exception as e:  # noqa: BLE001 – a broken or unknown demo
        return {"error": f"Kunde inte läsa demon: {e}"}
    if meta_path:
        candidates = [json.loads(Path(meta_path).with_suffix(".json").read_text())]
        candidates[0]["path"] = str(Path(meta_path).with_suffix(".json"))
    else:
        mtime = Path(dem).stat().st_mtime
        candidates = [dict(v, path=str(Path(v["path"]).with_suffix(".json"))) for v in cs2_waiting(load_config()["folder"])
                      if v.get("started", 0) <= mtime]
    why = "Demon passar ingen match som väntar."
    for meta in reversed(candidates):  # the newest match first
        me = cs2_demo_me(raw, meta.get("steamid", ""), meta.get("player", ""))
        if not me:
            why = f"Hittar inte {meta.get('player') or 'dig'} i demon."
            continue
        a = cs2_demo_analyse(raw, me)
        if not cs2_demo_fits(meta, a):
            why = (f"Demon är {cs2_map_name(a['map'])} {a['score'][0]}–{a['score'][1]}, "
                   f"matchen {meta.get('name', '')} {meta.get('score', '')}.")
            continue
        offset = cs2_demo_offset(meta, a)
        if offset is None:
            why = "Demons tider stämmer inte med filmens (rundorna och dina kills)."
            continue
        try:
            a["stats"].update(cs2_demo_aim(dem, raw, a, me))
        except Exception:  # noqa: BLE001 – the rest of the numbers still count
            pass
        return {"match": meta["file"], "text": cs2_demo_apply(meta["path"], dem, a, offset)}
    return {"error": why} if meta_path else {"match": None, "why": why}


# ---------------------------------------------------------------- videos

def safe_name(text):
    return re.sub(r'[/\\:*?"<>|]', "", text).strip() or "WoW"


def video_files(folder, grouped=False):
    """Every video, newest first. A CS2 match whose video was removed after the clips stays
    (size 0) for its card. grouped (the window): a match's clips under it ("clips"), not on
    their own."""
    folder = Path(folder)
    out = []
    for meta in sorted(folder.glob("*.json"), reverse=True):
        try:
            data = json.loads(meta.read_text())
        except (OSError, ValueError):
            continue
        video = folder / data.get("file", "")
        if not video.is_file() and not data.get("videoRemoved"):
            continue
        data["path"] = str(video)
        data["size"] = video.stat().st_size if video.is_file() else 0
        thumb = meta.with_suffix(".jpg")
        data["thumb"] = str(thumb) if thumb.exists() else ""
        out.append(data)
    out.sort(key=lambda v: v.get("started", 0), reverse=True)
    if grouped:
        matches = {v["file"]: v for v in out if v.get("kind") == "cs2"}
        for v in sorted(out, key=lambda v: (v.get("clip") != "Alla kills", v.get("started", 0))):
            if v.get("parent") in matches:
                matches[v["parent"]].setdefault("clips", []).append(v)
        out = [v for v in out if v.get("parent") not in matches]
        out = [v for v in out if not (v.get("videoRemoved") and not v.get("clips"))]
    return out


def match_clips(folder, match_file):
    return [v for v in video_files(folder) if v.get("parent") == match_file]


def folder_mtime(folder):
    """When a file was last added to or removed from the videos folder (0 = no folder)."""
    try:
        return Path(folder).stat().st_mtime
    except OSError:
        return 0


def set_meta(video_path, **fields):
    """Change fields in a video's .json."""
    meta = Path(video_path).with_suffix(".json")
    data = json.loads(meta.read_text())
    data.update(fields)
    tmp = meta.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1))
    tmp.replace(meta)


# ---------------------------------------------------------------- YouTube
# The video is cut and made ready here; then either YouTube Studio in the browser (13 Oct,
# the user's choice – title and description are ready to paste) or, when you have signed in,
# straight up with the API (yt_upload below, 15 Oct).

YT_RESULT = {"kill": "Kill", "wipe": "Wipe", "timed": "i tid", "depleted": "för sent",
             "win": "vinst", "loss": "förlust", "done": "klar", "tie": "oavgjort"}
SV_MONTHS = ["jan", "feb", "mar", "apr", "maj", "jun", "jul", "aug", "sep", "okt", "nov", "dec"]


def yt_clock(sec):
    sec = max(0, int(sec))
    h, m, s = sec // 3600, sec // 60 % 60, sec % 60
    return f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"


def youtube_text(meta, start=0.0, end=None):
    """Title and description for YouTube. Mythic+: the bosses as chapters (YouTube makes
    chapters of the time stamps: the first at 0:00, at least three, 10 s apart)."""
    end = meta.get("duration", 0) if end is None else end
    result = YT_RESULT.get(meta.get("result"), "avbruten")
    wcl = meta.get("wcl") or {}
    if meta.get("result") == "wipe" and wcl.get("bossPercentage") is not None:
        result += f" på {round(wcl['bossPercentage'])} %"
    if meta.get("kind") == "mplus":
        title = f"+{meta.get('level')} {meta.get('name', '')} – {result}"
    elif meta.get("kind") == "cs2":
        title = f"CS2 {meta.get('name', '')} {meta.get('difficulty', '')} – {result}" + (
            f" {meta['score']}" if meta.get("score") else "")
    else:
        title = f"{meta.get('name', '')} {meta.get('difficulty', '')}".strip() + f" – {result}"
    title = re.sub(r"[<>]", "", title)[:100]

    when = datetime.fromtimestamp(meta.get("started", time.time()))
    line = [f"{when.day} {SV_MONTHS[when.month - 1]} {when.year}"]
    parts = (meta.get("player") or "").split("-")
    if len(parts) >= 3:
        line.append(f"{parts[0]} ({'-'.join(parts[1:-1])})")
    if meta.get("fight"):
        line.append(yt_clock(meta["fight"]))
    desc = [title, " · ".join(line), ""]
    if wcl.get("url"):
        # YouTube makes "#fight" a hashtag and cuts the link there – Warcraft Logs takes ?fight= too
        desc += [f"Warcraft Logs: {wcl['url'].replace('#', '?', 1)}", ""]

    if meta.get("kind") == "mplus":
        chapters, last = [(0, "Start")], 0
        key = meta.get("fightStart", 0) - start
        if key >= 10:
            chapters.append((key, "Nyckeln startar"))
        for m in sorted(meta.get("markers", []), key=lambda m: m["t"]):
            t = m["t"] - start
            if m.get("kind") == "boss" and 0 <= t <= end - start:
                chapters.append((t, m["text"]))
        kept = []
        for t, text in chapters:  # 10 s apart, else YouTube makes no chapters at all
            if not kept or t - kept[-1][0] >= 10:
                kept.append((t, text))
        if len(kept) >= 2:
            desc += [f"{yt_clock(t)} {text}" for t, text in kept] + [""]
    if meta.get("kind") == "cs2":  # the multikills with times (not chapters – too close together)
        best = [m for m in meta.get("markers", []) if m.get("kind") == "kill" and not m["text"].startswith("Kill")
                and start <= m["t"] <= end]
        if best:
            desc += [f"{yt_clock(m['t'] - start)} {m['text']}" for m in best] + [""]
    deaths = [m for m in meta.get("markers", []) if m.get("kind") == "death" and start <= m["t"] <= end]
    if deaths:
        desc += [f"Dödsfall: {len(deaths)}", ""]
    desc.append("Inspelad med GoblinRecorder på GOBLINCAKES")
    return {"title": title, "description": "\n".join(desc)}


def youtube_clip(video, start, end, dest):
    """Cut without re-encoding (fast, same quality); only the first audio track (everything)
    – YouTube plays just one. Returns an error text or ""."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    cmd = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y"]
    if start > 0:
        cmd += ["-ss", f"{start:.3f}"]
    cmd += ["-i", str(video)]
    if end:
        cmd += ["-t", f"{max(end - start, 1):.3f}"]
    cmd += ["-map", "0:v:0", "-map", "0:a:0?", "-c", "copy", "-movflags", "+faststart", str(dest)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0 or not dest.is_file():
        return (r.stderr or "ffmpeg misslyckades").strip().splitlines()[-1]
    return ""


# ---------------------------------------------------------------- YouTube upload (API)

# Straight to your channel with YouTube Data API v3 (15 Oct, the user's wish – the browser way
# above stays). You make a Google Cloud project with an OAuth client of the type "Desktop
# app" once (like the Warcraft Logs client); signing in goes through the browser to a port on
# 127.0.0.1 (PKCE). Only the right to upload (youtube.upload) + your e-mail address to show
# who is signed in. Note: Google locks videos from an API project that hasn't been audited
# (projects made after 28 July 2020) as private – the YouTube API audit form lifts it.
YT_FILE = CONFIG_DIR / "youtube.json"  # client id/secret + refresh token, only readable by you
YT_CONSOLE = "https://console.cloud.google.com/apis/credentials"
YT_AUDIT = "https://support.google.com/youtube/contact/yt_api_form"
YT_SCOPES = "https://www.googleapis.com/auth/youtube.upload openid email"
YT_CHUNK = 16 * 1024 * 1024  # bytes per request (a multiple of 256 KiB, as YouTube wants)


def yt_load():
    try:
        return json.loads(YT_FILE.read_text())
    except (OSError, ValueError):
        return {}


def yt_save(data):
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    tmp = YT_FILE.with_suffix(".tmp")
    tmp.touch(mode=0o600)
    os.chmod(tmp, 0o600)
    tmp.write_text(json.dumps(data, indent=1))
    tmp.replace(YT_FILE)


def yt_state():
    """{"client": the OAuth client is saved, "signedIn": a refresh token, "email": who}."""
    d = yt_load()
    return {"client": bool(d.get("clientId") and d.get("clientSecret")),
            "signedIn": bool(d.get("refreshToken")), "email": d.get("email", "")}


def yt_set_client(client_id, secret):
    client_id, secret = client_id.strip(), secret.strip()
    if not client_id.endswith(".apps.googleusercontent.com"):
        raise RuntimeError("Client ID ska sluta med .apps.googleusercontent.com")
    yt_save({"clientId": client_id, "clientSecret": secret})


def yt_forget(keep_client=True):
    d = yt_load()
    token = d.get("refreshToken")
    if token:  # also tell Google, so the access is gone from your account too
        import urllib.parse
        import urllib.request
        try:
            urllib.request.urlopen(urllib.request.Request(
                "https://oauth2.googleapis.com/revoke",
                data=urllib.parse.urlencode({"token": token}).encode()), timeout=10).close()
        except (OSError, urllib.error.URLError):
            pass
    if keep_client and d.get("clientId"):
        yt_save({"clientId": d["clientId"], "clientSecret": d.get("clientSecret", "")})
    else:
        try:
            YT_FILE.unlink()
        except OSError:
            pass


def _yt_token_request(fields):
    import urllib.parse
    import urllib.request
    req = urllib.request.Request("https://oauth2.googleapis.com/token",
                                 data=urllib.parse.urlencode(fields).encode(),
                                 headers={"Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        try:
            err = json.loads(e.read()).get("error", "")
        except ValueError:
            err = ""
        if err == "invalid_grant":
            raise RuntimeError("Inloggningen har gått ut – logga in på YouTube igen "
                               "(Google gör så efter 7 dagar när projektet står på Testing)") from e
        if err == "invalid_client":
            raise RuntimeError("Fel Client ID eller hemlighet") from e
        raise RuntimeError(f"Google svarade {e.code} {err}".strip()) from e


def yt_login(open_url, timeout=300):
    """Sign in through the browser: Google sends you back to a port on 127.0.0.1 with a code,
    which becomes a refresh token. open_url(url) opens the browser. Returns the e-mail."""
    import http.server
    import threading
    import urllib.parse
    d = yt_load()
    if not d.get("clientId"):
        raise RuntimeError("Ingen OAuth-klient inlagd")
    verifier = secrets.token_urlsafe(64)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).decode().rstrip("=")
    state = secrets.token_urlsafe(16)
    got = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            if q.get("state", [""])[0] != state:
                self.send_response(404)
                self.end_headers()
                return
            got["code"] = q.get("code", [""])[0]
            got["error"] = q.get("error", [""])[0]
            ok = bool(got["code"])
            page = ("<h2>Klart – du kan stänga fliken och gå tillbaka till GoblinRecorder.</h2>" if ok
                    else "<h2>Inloggningen avbröts.</h2>")
            body = ("<!doctype html><meta charset=utf-8><title>GoblinRecorder</title>"
                    "<body style='background:#0E1420;color:#E6ECF5;font-family:sans-serif;padding:40px'>"
                    + page).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
    redirect = f"http://127.0.0.1:{server.server_port}"
    url = "https://accounts.google.com/o/oauth2/v2/auth?" + urllib.parse.urlencode({
        "client_id": d["clientId"], "redirect_uri": redirect, "response_type": "code",
        "scope": YT_SCOPES, "code_challenge": challenge, "code_challenge_method": "S256",
        "state": state, "access_type": "offline", "prompt": "consent"})
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        open_url(url)
        end = time.time() + timeout
        while "code" not in got and time.time() < end:
            time.sleep(0.2)
    finally:
        server.shutdown()
        server.server_close()
    if not got.get("code"):
        raise RuntimeError("Inloggningen avbröts" if got.get("error") or "code" in got
                           else "Ingen inloggning inom 5 minuter")
    tok = _yt_token_request({"client_id": d["clientId"], "client_secret": d.get("clientSecret", ""),
                             "code": got["code"], "code_verifier": verifier,
                             "grant_type": "authorization_code", "redirect_uri": redirect})
    if not tok.get("refresh_token"):
        raise RuntimeError("Google gav ingen inloggning som håller – försök igen")
    email = ""
    try:  # the id token's middle part says who signed in (straight from Google, over https)
        part = tok.get("id_token", "").split(".")[1]
        email = json.loads(base64.urlsafe_b64decode(part + "=" * (-len(part) % 4))).get("email", "")
    except (IndexError, ValueError):
        pass
    d.update({"refreshToken": tok["refresh_token"], "accessToken": tok.get("access_token", ""),
              "expires": time.time() + tok.get("expires_in", 3600) - 60, "email": email})
    yt_save(d)
    return email


def _yt_access():
    d = yt_load()
    if not d.get("refreshToken"):
        raise RuntimeError("Inte inloggad på YouTube")
    if d.get("accessToken") and time.time() < d.get("expires", 0):
        return d["accessToken"]
    tok = _yt_token_request({"client_id": d["clientId"], "client_secret": d.get("clientSecret", ""),
                             "refresh_token": d["refreshToken"], "grant_type": "refresh_token"})
    d.update({"accessToken": tok["access_token"], "expires": time.time() + tok.get("expires_in", 3600) - 60})
    yt_save(d)
    return d["accessToken"]


YT_ERRORS = {
    "quotaExceeded": "YouTubes dagliga gräns för API-projektet är nådd – försök igen i morgon",
    "uploadLimitExceeded": "Kanalen har laddat upp så många filmer som YouTube tillåter i dag",
    "youtubeSignupRequired": "Google-kontot har ingen YouTube-kanal än – skapa en på youtube.com först",
    "forbidden": "YouTube nekade uppladdningen – är YouTube Data API v3 påslaget i projektet?",
    "accessNotConfigured": "YouTube Data API v3 är inte påslaget i Google Cloud-projektet",
    "insufficientPermissions": "Inloggningen saknar rätt att ladda upp – logga in igen",
    "invalidTitle": "YouTube godtog inte titeln",
    "invalidDescription": "YouTube godtog inte beskrivningen",
}


def _yt_error(status, body):
    try:
        err = json.loads(body).get("error", {})
        reasons = [e.get("reason", "") for e in err.get("errors", [])]
        for r in reasons:
            if r in YT_ERRORS:
                return YT_ERRORS[r]
        if any("SERVICE_DISABLED" in json.dumps(d) for d in err.get("details", [])):
            return YT_ERRORS["accessNotConfigured"]
        return f"YouTube svarade {status}: {err.get('message', '')}".strip()
    except (ValueError, AttributeError):
        return f"YouTube svarade {status}"


def _yt_request(method, url, body=None, headers=None):
    import http.client
    import urllib.parse
    u = urllib.parse.urlsplit(url)
    conn = http.client.HTTPSConnection(u.netloc, timeout=120)
    try:
        conn.request(method, u.path + ("?" + u.query if u.query else ""), body=body, headers=headers or {})
        r = conn.getresponse()
        return r.status, {k.lower(): v for k, v in r.getheaders()}, r.read()
    finally:
        conn.close()


def yt_upload(path, title, description, privacy="private", progress=None, cancelled=None):
    """Resumable upload (several tries per piece, continues where it stopped). progress(sent,
    total) after each piece; cancelled() → True stops. Returns the video's id."""
    total = os.path.getsize(path)
    meta = {"snippet": {"title": title[:100], "description": description[:5000], "categoryId": "20"},
            "status": {"privacyStatus": privacy, "selfDeclaredMadeForKids": False}}
    status, head, body = _yt_request(
        "POST", "https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status",
        json.dumps(meta).encode(), {"Authorization": "Bearer " + _yt_access(),
                                    "Content-Type": "application/json; charset=UTF-8",
                                    "X-Upload-Content-Length": str(total),
                                    "X-Upload-Content-Type": "video/mp4"})
    if status != 200 or "location" not in head:
        raise RuntimeError(_yt_error(status, body))
    session = head["location"]
    sent, tries = 0, 0
    with open(path, "rb") as f:
        while True:
            if cancelled and cancelled():
                try:
                    _yt_request("DELETE", session, headers={"Authorization": "Bearer " + _yt_access()})
                except OSError:
                    pass
                raise RuntimeError("Avbruten")
            f.seek(sent)
            chunk = f.read(YT_CHUNK)
            hdr = {"Authorization": "Bearer " + _yt_access(), "Content-Length": str(len(chunk)),
                   "Content-Range": f"bytes {sent}-{sent + len(chunk) - 1}/{total}" if chunk else f"bytes */{total}"}
            try:
                status, head, body = _yt_request("PUT", session, chunk, hdr)
            except OSError:
                status, head, body = 0, {}, b""
            if status in (200, 201):
                if progress:
                    progress(total, total)
                return json.loads(body)["id"]
            if status == 308:  # this much has arrived – go on from there
                rng = head.get("range", "")
                sent = int(rng.rsplit("-", 1)[1]) + 1 if rng else 0
                tries = 0
                if progress:
                    progress(sent, total)
                continue
            if status in (400, 401, 403, 404):
                raise RuntimeError(_yt_error(status, body))
            tries += 1  # 5xx or the connection broke: ask how much arrived, then go on
            if tries > 8:
                raise RuntimeError(_yt_error(status, body) if status else "Uppladdningen avbröts – nätverket?")
            time.sleep(min(60, 2 ** tries))
            try:
                status, head, body = _yt_request("PUT", session, b"", {
                    "Authorization": "Bearer " + _yt_access(), "Content-Length": "0",
                    "Content-Range": f"bytes */{total}"})
                if status in (200, 201):
                    if progress:
                        progress(total, total)
                    return json.loads(body)["id"]
                if status == 308:
                    rng = head.get("range", "")
                    sent = int(rng.rsplit("-", 1)[1]) + 1 if rng else 0
            except OSError:
                pass


def make_thumb(video, at, dest):
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", str(at),
                    "-i", str(video), "-frames:v", "1", "-vf", "scale=480:-2", str(dest)],
                   capture_output=True)


def remove_video(path):
    p = Path(path)
    for f in (p, p.with_suffix(".json"), p.with_suffix(".jpg")):
        try:
            f.unlink()
        except OSError:
            pass


KEPT_RESULTS = ("kill", "timed", "win", "done")  # a raid kill, a key in time, an arena won / a Solo Shuffle
# CS2 matches always stay (a lost match can have your ace); the oldest go above the folder's limit
RAID_WIPES_KEPT = 2  # per boss and difficulty while you raid – the newest ones


def drop_old_wipes(folder, video):
    """After a raid wipe is saved: keep only the newest wipes of that boss and difficulty."""
    if video.get("kind") != "raid" or video.get("result") == "kill":
        return []
    same = [v for v in video_files(folder) if v.get("kind") == "raid" and v.get("result") != "kill"
            and v.get("name") == video.get("name") and v.get("difficulty") == video.get("difficulty")
            and not v.get("keep")]
    gone = sorted(same, key=lambda v: v.get("started", 0), reverse=True)[RAID_WIPES_KEPT:]
    for v in gone:
        remove_video(v["path"])
    return [v["file"] for v in gone]


def drop_old_tests(folder, video):
    """Only the newest test recording stays (unless kept); a test also goes when WoW closes."""
    gone = [v for v in video_files(folder) if v.get("kind") == "test" and v["path"] != str(video)
            and not v.get("keep")]
    for v in gone:
        remove_video(v["path"])
    return [v["file"] for v in gone]


def drop_non_kills(folder):
    """When WoW closes: everything that is not a kill (or a key in time) goes, unless kept."""
    gone = [v for v in video_files(folder) if v.get("result") not in KEPT_RESULTS and not v.get("keep")
            and v.get("kind") not in ("cs2", "cs2clip")]
    for v in gone:
        remove_video(v["path"])
    return [v["file"] for v in gone]


def prune(folder, max_gb):
    """Oldest videos go when the folder is over max_gb (not the ones marked keep)."""
    vids = video_files(folder)
    total = sum(v["size"] for v in vids)
    limit = max_gb * 1024 ** 3
    for v in reversed(vids):
        if total <= limit:
            break
        if v.get("keep") or not v["size"]:
            continue
        if v.get("kind") == "cs2" and v.get("clipsMade"):  # the clips stay, the match's card too
            Path(v["path"]).unlink(missing_ok=True)
            set_meta(v["path"], videoRemoved=True)
        else:
            remove_video(v["path"])
        total -= v["size"]


# ---------------------------------------------------------------- Warcraft Logs

# Which Warcraft Logs fight a video shows. Nothing is uploaded from here – Warcraft Logs'
# own uploader (Archon) does that; we only look the fight up with the public API. Needs an
# API client (id + secret) you make once on warcraftlogs.com; reports must be public.
WCL = "https://www.warcraftlogs.com"
WCL_FILE = CONFIG_DIR / "wcl.json"  # client id/secret + token, only readable by you
WCL_CLIENTS_PAGE = f"{WCL}/api/clients/"


def wcl_load():
    try:
        return json.loads(WCL_FILE.read_text())
    except (OSError, ValueError):
        return {}


def wcl_save(data):
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    tmp = WCL_FILE.with_suffix(".tmp")
    tmp.touch(mode=0o600)
    os.chmod(tmp, 0o600)
    tmp.write_text(json.dumps(data, indent=1))
    tmp.replace(WCL_FILE)


def wcl_configured():
    d = wcl_load()
    return bool(d.get("clientId") and d.get("clientSecret"))


def _wcl_token(data=None, force=False):
    import urllib.parse
    import urllib.request
    data = data or wcl_load()
    if not data.get("clientId") or not data.get("clientSecret"):
        raise RuntimeError("Ingen Warcraft Logs-klient inlagd")
    if not force and data.get("accessToken") and time.time() < data.get("expires", 0):
        return data["accessToken"]
    auth = base64.b64encode(f"{data['clientId']}:{data['clientSecret']}".encode()).decode()
    req = urllib.request.Request(f"{WCL}/oauth/token", data=urllib.parse.urlencode(
        {"grant_type": "client_credentials"}).encode(), headers={
        "Authorization": "Basic " + auth, "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            tok = json.loads(r.read())
    except urllib.error.HTTPError as e:
        raise RuntimeError("Fel id eller hemlighet" if e.code in (400, 401) else f"Warcraft Logs svarade {e.code}") from e
    data.update({"accessToken": tok["access_token"], "expires": time.time() + tok.get("expires_in", 3600) - 60})
    wcl_save(data)
    return data["accessToken"]


def wcl_set_client(client_id, secret):
    """Save and test the API client. Raises with a readable text when it does not work."""
    data = {"clientId": client_id.strip(), "clientSecret": secret.strip()}
    _wcl_token(data, force=True)


def wcl_forget():
    try:
        WCL_FILE.unlink()
    except OSError:
        pass


def wcl_query(query, variables=None):
    import urllib.request
    req = urllib.request.Request(f"{WCL}/api/v2/client", data=json.dumps(
        {"query": query, "variables": variables or {}}).encode(), headers={
        "Authorization": "Bearer " + _wcl_token(), "Content-Type": "application/json",
        "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        out = json.loads(r.read())
    errors = out.get("errors") or []
    # 22 Oct: with the hour's 1000 points spent the answer has data, but the asked parts are null
    if any("points remaining" in (e.get("message") or "") for e in errors):
        raise RuntimeError("timkvoten är slut (1000 poäng i timmen) – prova igen om en stund")
    if errors and not out.get("data"):
        raise RuntimeError(errors[0].get("message", "fel från Warcraft Logs"))
    return out["data"]


def server_slug(realm):
    """Realm in the combat log ("TwistingNether", "Al'Akir") → Warcraft Logs' slug."""
    realm = re.sub(r"(?<=[a-z])(?=[A-Z])", "-", realm).replace("'", "")
    return re.sub(r"[^a-z0-9-]", "", realm.lower().replace(" ", "-"))


REPORT_FIELDS = ("code startTime endTime fights { id encounterID name kill startTime endTime "
                 "bossPercentage fightPercentage keystoneLevel difficulty averageItemLevel }")


WCL_LIVE_AGE = 10 * 60  # a report that grew this recently is being live logged
wcl_live_seen = 0  # when a live-logged report was last seen (time.time())


def wcl_note_live(reports):
    """Remember when one of the reports is live logged (Archon/the uploader's Live Log: the
    report grows during the evening), so the service looks for new fights often."""
    global wcl_live_seen
    if any(r.get("endTime", 0) / 1000 > time.time() - WCL_LIVE_AGE for r in reports):
        wcl_live_seen = time.time()


def wcl_reports(player, start_ms, end_ms):
    """Public reports around a time that the recording character is in: its recent
    reports, your own uploads and its guild's (Name-Realm-Region from the combat log).
    12 Oct: the character's list only gets a report a while after the upload (tonight's key
    was missing an hour later), your account's list has it at once."""
    parts = player.split("-")
    if len(parts) < 3:
        return []
    name, region, realm = parts[0], parts[-1], "-".join(parts[1:-1])
    window = {"from": start_ms - 8 * 3600 * 1000, "to": end_ms + 8 * 3600 * 1000}
    data = wcl_query(
        "query($n:String,$s:String,$r:String){ characterData { character(name:$n, serverSlug:$s,"
        " serverRegion:$r) { guilds { id } recentReports(limit: 10) { data { owner { id name } "
        + REPORT_FIELDS + " } } } } }",
        {"n": name, "s": server_slug(realm), "r": region.lower()})
    char = data["characterData"]["character"] or {}
    recent = (char.get("recentReports") or {}).get("data") or []
    reports = [r for r in recent if r["startTime"] <= end_ms and r["endTime"] >= start_ms]
    user = wcl_user(player, recent)
    if user:
        reports += wcl_query(
            "query($u:Int,$from:Float,$to:Float){ reportData { reports(userID:$u, startTime:$from,"
            " endTime:$to, limit: 10) { data { " + REPORT_FIELDS + " } } } }",
            dict(window, u=user))["reportData"]["reports"]["data"]
    for g in char.get("guilds") or []:
        reports += wcl_query(
            "query($g:Int,$from:Float,$to:Float){ reportData { reports(guildID:$g, startTime:$from,"
            " endTime:$to, limit: 10) { data { " + REPORT_FIELDS + " } } } }",  # more is too costly for the API
            dict(window, g=g["id"])
        )["reportData"]["reports"]["data"]
    wcl_note_live(reports)
    return reports


def wcl_user(player, recent):
    """Your Warcraft Logs account (its id): the uploader of the character's earlier reports
    whose name is the character's name – Archon uploads under your account. Kept in wcl.json
    once found."""
    data = wcl_load()
    users = data.get("users") or {}
    if users.get(player):
        return users[player]
    name = player.split("-")[0].lower()
    for r in recent:
        owner = r.get("owner") or {}
        if owner.get("id") and str(owner.get("name", "")).lower() == name:
            users[player] = owner["id"]
            data["users"] = users
            wcl_save(data)
            return owner["id"]
    return None


ROLE_ORDER = {"tanks": 0, "healers": 1, "dps": 2}


def wcl_stats(wcl):
    """Everyone in the fight: class, spec, role, DPS, HPS, parse and item level parse (against
    the same item level; healers by HPS, the others by DPS; only kills and timed keys have
    parses) and deaths – the same numbers as the
    report page (total / the fight's time)."""
    rep = wcl_query(
        "query($c:String,$f:[Int]){ reportData { report(code:$c) {"
        " details: playerDetails(fightIDs:$f) dmg: table(dataType: DamageDone, fightIDs:$f)"
        " heal: table(dataType: Healing, fightIDs:$f) deaths: table(dataType: Deaths, fightIDs:$f)"
        " rdps: rankings(fightIDs:$f, playerMetric: dps) rhps: rankings(fightIDs:$f, playerMetric: hps) } } }",
        {"c": wcl["code"], "f": [int(wcl["fight"])]})["reportData"]["report"]

    def data(key):
        v = rep.get(key) or {}
        return v.get("data") if isinstance(v, dict) else None

    def per_second(table):
        t = data(table) or {}
        secs = max((t.get("totalTime") or 0) / 1000, 1)
        return {e["name"]: e.get("total", 0) / secs for e in t.get("entries") or []}

    def parses(table):
        out = {}
        for fight in data(table) or []:
            for role in (fight.get("roles") or {}).values():
                for c in role.get("characters") or []:
                    if c.get("rankPercent") is not None:
                        out[c["name"]] = (c["rankPercent"], c.get("bracketPercent"))
        return out

    dps, hps = per_second("dmg"), per_second("heal")
    pdps, phps = parses("rdps"), parses("rhps")
    deaths = {}
    for e in (data("deaths") or {}).get("entries") or []:
        deaths[e["name"]] = deaths.get(e["name"], 0) + 1
    players = []
    for role, people in ((data("details") or {}).get("playerDetails") or {}).items():
        for p in people:
            name = p["name"]
            parse, ilvl_parse = (phps if role == "healers" else pdps).get(name, (None, None))
            players.append({
                "name": name, "class": p.get("type", ""), "role": role,
                "spec": (p.get("specs") or [{}])[0].get("spec", ""),
                "dps": round(dps.get(name, 0)), "hps": round(hps.get(name, 0)),
                "parse": parse, "ilvlParse": ilvl_parse, "ilvl": p.get("maxItemLevel") or p.get("minItemLevel"),
                "deaths": deaths.get(name, 0)})
    players.sort(key=lambda p: (ROLE_ORDER.get(p["role"], 3), -p["dps"]))
    return {"players": players, "deaths": sum(deaths.values()), "fetched": time.time(),
            "ranked": bool(pdps or phps)}


def wcl_ilvl(wcl, player=""):
    """The group's average item level in the fight ("avg.ilvl" on the card – Warcraft Logs' own
    figure for the fight) and your own – about 3 of the hour's 1000 points (22 Oct, the user's wish)."""
    rep = wcl_query("query($c:String,$f:[Int]){ reportData { report(code:$c) { fights(fightIDs:$f) { averageItemLevel }"
                    " details: playerDetails(fightIDs:$f) } } }",
                    {"c": wcl["code"], "f": [int(wcl["fight"])]})["reportData"]["report"]
    people = [p for ps in ((((rep.get("details") or {}).get("data")) or {}).get("playerDetails") or {}).values() for p in ps]
    mine = next((p for p in people if player and p["name"] == player.split("-")[0]), {})
    avg = ((rep.get("fights") or [{}])[0] or {}).get("averageItemLevel")
    return {"avgIlvl": round(avg, 2) if avg else None, "ilvl": mine.get("maxItemLevel") or mine.get("minItemLevel")}


def wcl_find(meta):
    """The Warcraft Logs fight a video shows, or None (not uploaded yet / not public)."""
    start_ms = meta["started"] * 1000
    end_ms = start_ms + max(meta.get("fight", 0), 1) * 1000
    best, best_score = None, None
    for rep in wcl_reports(meta.get("player", ""), start_ms, end_ms):
        for f in rep.get("fights") or []:
            fs, fe = rep["startTime"] + f["startTime"], rep["startTime"] + f["endTime"]
            if meta["kind"] == "raid":
                if str(f["encounterID"]) != str(meta.get("encounterId")) or abs(fs - start_ms) > 20000:
                    continue
                score = abs(fs - start_ms)
            else:
                overlap = min(fe, end_ms) - max(fs, start_ms)
                if not f.get("keystoneLevel") or overlap <= 0:
                    continue
                score = -overlap
            if best_score is None or score < best_score:
                best_score = score
                best = {"code": rep["code"], "fight": f["id"], "kill": f.get("kill"),
                        "bossPercentage": f.get("bossPercentage"), "avgIlvl": f.get("averageItemLevel"),
                        "url": f"{WCL}/reports/{rep['code']}#fight={f['id']}"}
    return best

# ---------------------------------------------------------------- WoW Stats / CS2 Stats
# (22 Oct, the user's wish: two buttons at the top of the window, and – the user's decision – put
# together from what is already fetched, not from more Warcraft Logs/Raider.io calls.) Every
# recorded pull and key goes into your own history when it is saved; its Warcraft Logs numbers
# (your parse, DPS/HPS, item level) are added when the log is fetched. The history stays when the
# video goes (wipes and old videos are pruned), so WoW Stats keeps everything you recorded.
WOW_HISTORY = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local/share")) / "goblincakes" / "wow-history.json"
DIFF_ORDER = ["Mythic", "Heroic", "Normal", "LFR"]


def wow_history():
    try:
        return json.loads(WOW_HISTORY.read_text())
    except (OSError, ValueError):
        return {}


def wow_history_add(meta, stats=None):
    """A recorded pull/key into the history (kind raid or mplus), with your own row of the log's
    numbers when they are there."""
    if meta.get("kind") not in ("raid", "mplus") or not meta.get("player"):
        return
    hist = wow_history()
    key = f"{meta['player']}|{int(meta.get('started', 0))}"
    e = dict(hist.get(key) or {})  # a copy: compared with the saved one below
    e.update({k: meta.get(k) for k in ("player", "kind", "name", "difficulty", "level", "result", "started",
                                       "fight", "encounterId", "avgIlvl")})
    if meta.get("ilvl"):
        e["ilvl"] = meta["ilvl"]
    if meta.get("wcl"):
        e["url"] = meta["wcl"].get("url")
    stats = stats or meta.get("wclStats")
    me = meta["player"].split("-")[0]
    row = next((p for p in (stats or {}).get("players", []) if p.get("name") == me), None)
    if row:
        e.update({k: row.get(k) for k in ("class", "spec", "role", "dps", "hps", "parse", "ilvlParse", "deaths")})
        e["ilvl"] = row.get("ilvl") or e.get("ilvl")
    if hist.get(key) == e:
        return
    hist[key] = e
    WOW_HISTORY.parent.mkdir(parents=True, exist_ok=True)
    tmp = WOW_HISTORY.with_suffix(".tmp")
    tmp.write_text(json.dumps(hist, ensure_ascii=False))
    tmp.replace(WOW_HISTORY)


def wow_overview(folder, player="", days=0):
    """The WoW Stats page: per raid difficulty and boss your best and median parse, kills, wipes,
    fastest kill, best DPS/HPS and item level (like Warcraft Logs' character page), per dungeon your
    best key and parses, and the parses and item level over time. days = only the last days."""
    for v in video_files(folder):  # videos from before the history (or fetched in the window)
        if v.get("kind") in ("raid", "mplus") and v.get("player"):
            wow_history_add(v)
    entries = list(wow_history().values())
    players = []
    for e in sorted(entries, key=lambda e: -(e.get("started") or 0)):
        if e.get("player") and e["player"] not in players:
            players.append(e["player"])
    player = player if player in players else (players[0] if players else "")
    since = time.time() - days * 86400 if days else 0
    mine = sorted((e for e in entries if e.get("player") == player and (e.get("started") or 0) >= since),
                  key=lambda e: e.get("started") or 0)
    with_row = [e for e in mine if e.get("spec")]
    last = with_row[-1] if with_row else {}

    def amount(e):
        return e.get("hps") if e.get("role") == "healers" else e.get("dps")

    def boss_rows(es, key):
        groups = {}
        for e in es:
            groups.setdefault(e.get(key) or e.get("name"), []).append(e)
        rows = []
        for _, g in groups.items():
            done = [e for e in g if e.get("result") in ("kill", "timed")]
            parses = [e["parse"] for e in done if e.get("parse") is not None]
            best = max(done, key=lambda e: e["parse"] if e.get("parse") is not None else -1, default=None)
            rows.append({
                "name": g[-1].get("name"), "encounterId": g[-1].get("encounterId"), "pulls": len(g),
                "kills": len(done), "wipes": sum(e.get("result") in ("wipe", "depleted") for e in g),
                "best": max(parses) if parses else None,
                "median": round(statistics.median(parses)) if parses else None,
                "ilvlParse": max((e["ilvlParse"] for e in done if e.get("ilvlParse") is not None), default=None),
                "amount": max((amount(e) or 0 for e in done), default=0) or None,
                "fastest": min((e.get("fight") or 0 for e in done), default=0) or None,
                "ilvl": best.get("ilvl") if best else None, "url": (best or {}).get("url") or g[-1].get("url"),
                "avgIlvl": best.get("avgIlvl") if best else None,
                "spec": (best or g[-1]).get("spec") or "", "last": g[-1].get("started"),
                "bestLevel": max((e.get("level") or 0 for e in done), default=0) or None,
                "topLevel": max((e.get("level") or 0 for e in g), default=0) or None,
            })
        return rows

    raid = {}
    for d in DIFF_ORDER + sorted({e.get("difficulty") for e in mine if e.get("kind") == "raid"} - set(DIFF_ORDER) - {None}):
        es = [e for e in mine if e.get("kind") == "raid" and e.get("difficulty") == d]
        if not es:
            continue
        rows = sorted(boss_rows(es, "encounterId"), key=lambda r: r.get("encounterId") or 0)
        ranked = [r for r in rows if r["best"] is not None]
        raid[d] = {"bosses": rows,
                   "best": round(sum(r["best"] for r in ranked) / len(ranked), 1) if ranked else None,
                   "median": round(sum(r["median"] for r in ranked) / len(ranked), 1) if ranked else None,
                   "kills": sum(r["kills"] for r in rows), "pulls": sum(r["pulls"] for r in rows)}
    keys = [e for e in mine if e.get("kind") == "mplus"]
    dungeons = sorted(boss_rows(keys, "name"), key=lambda r: -(r["bestLevel"] or 0))
    ranked = [r for r in dungeons if r["best"] is not None]
    trend = [{"name": e.get("name"), "difficulty": e.get("difficulty"), "level": e.get("level"), "kind": e.get("kind"),
              "parse": e["parse"], "ilvl": e.get("ilvl"), "avgIlvl": e.get("avgIlvl"), "started": e.get("started"),
              "url": e.get("url")}
             for e in mine if e.get("parse") is not None][-40:]
    name, realm, region = (player.split("-")[0], *player.split("-", 1)[1].rsplit("-", 1)) if player.count("-") >= 2 else (player, "", "")
    return {
        "players": players, "player": player, "name": name, "realm": realm, "region": region,
        "class": last.get("class", ""), "spec": last.get("spec", ""), "role": last.get("role", ""),
        "ilvl": next((e["ilvl"] for e in reversed(mine) if e.get("ilvl")), None),
        "wclUrl": f"{WCL}/character/{region.lower()}/{server_slug(realm)}/{name.lower()}" if region else "",
        "difficulties": list(raid), "raid": raid,
        "mplus": {"dungeons": dungeons, "runs": len(keys), "timed": sum(e.get("result") == "timed" for e in keys),
                  "best": round(sum(r["best"] for r in ranked) / len(ranked), 1) if ranked else None,
                  "median": round(sum(r["median"] for r in ranked) / len(ranked), 1) if ranked else None},
        "trend": trend, "missing": sum(1 for e in mine if e.get("result") in ("kill", "timed") and not e.get("spec")),
    }


def cs2_overview(folder, count=10):
    """The CS2 Stats page: your matches with a read demo – the average of the last `count` (0 = all),
    each map, the guns in all of them, and the matches for the over-time charts."""
    ms = sorted((v for v in video_files(folder) if v.get("kind") == "cs2" and v.get("demoStats")),
                key=lambda v: v.get("started", 0))
    waiting = sum(1 for v in video_files(folder) if v.get("kind") == "cs2" and v.get("demo") == "waiting")
    recent = ms[-count:] if count else ms

    def avg(key, of=recent):
        xs = [m["demoStats"].get(key) for m in of if m["demoStats"].get(key) is not None]
        return round(sum(xs) / len(xs), 2) if xs else None

    def per(key):
        return round(sum(m["demoStats"].get(key, 0) for m in recent) / len(recent), 2) if recent else None

    maps = {}
    for m in ms:
        g = maps.setdefault(m.get("name", "?"), [])
        g.append(m)
    guns = {}
    for m in recent:
        for w in m["demoStats"].get("weapons", []):
            g = guns.setdefault(w["name"], {"name": w["name"], "kills": 0, "hs": 0, "shots": 0, "hits": 0})
            for k in ("kills", "hs", "shots", "hits"):
                g[k] += w.get(k) or 0
    for g in guns.values():
        g["acc"] = round(100 * g["hits"] / g["shots"]) if g["shots"] else None
        g["hsp"] = round(100 * g["hs"] / g["kills"]) if g["kills"] else None
    return {
        "count": len(recent), "all": len(ms), "waiting": waiting,
        "wins": sum(m.get("result") == "win" for m in recent), "losses": sum(m.get("result") == "loss" for m in recent),
        "avg": {k: avg(k) for k in ("kd", "adr", "kast", "hs", "ttd", "cp")},
        "per": {k: per(k) for k in ("kills", "deaths", "assists", "entryWon", "entryLost", "trades", "clutchWon",
                                     "clutches", "flashed", "teamFlashed", "flashAssists", "heDmg", "fireDmg")},
        "maps": sorted(({"name": n, "matches": len(g), "wins": sum(m.get("result") == "win" for m in g),
                         "adr": avg("adr", g), "kd": avg("kd", g)} for n, g in maps.items()), key=lambda x: -x["matches"]),
        "weapons": sorted(guns.values(), key=lambda g: -g["kills"])[:10],
        "matches": [{"path": m["path"], "name": m.get("name", ""), "mode": m.get("difficulty", ""), "score": m.get("score", ""),
                     "result": m.get("result", ""), "started": m.get("started", 0),
                     **{k: m["demoStats"].get(k) for k in ("kd", "adr", "kast", "hs", "ttd", "cp", "kills", "deaths")}}
                    for m in ms[-30:]],
    }



def cs2_demo_process(dem, meta_path=None):
    """cs2_demo_run in its own process (pandas & co. stay out of the service and the window),
    with low priority – a demo takes some seconds of CPU, maybe while you play."""
    cmd = ["nice", "-n", "10", sys.executable, "-I", __file__, "cs2-demo", str(dem)] + ([str(meta_path)] if meta_path else [])
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        return json.loads(r.stdout.strip().splitlines()[-1])
    except (OSError, subprocess.TimeoutExpired, ValueError, IndexError) as e:
        return {"error": f"Kunde inte läsa demon: {e}"}


if __name__ == "__main__" and len(sys.argv) > 2 and sys.argv[1] == "cs2-demo":
    print(json.dumps(cs2_demo_run(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None), ensure_ascii=False))
