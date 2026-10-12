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
import os
import re
import secrets
import shutil
import socket
import struct
import subprocess
import time
import urllib.error
from datetime import datetime
from pathlib import Path

HOME = Path.home()
CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "goblincakes"
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "goblincakes"
CONFIG_FILE = CONFIG_DIR / "recorder.json"
STATUS_FILE = CACHE_DIR / "recorder-status.json"
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
    "micGate": "normal",  # off | normal | strong – the gate after the noise suppression, see MIC_GATES
    "quality": "normal",  # high | normal | small – the bitrate, see QUALITY_MBIT  # dB louder game sound – WoW plays quietly next to Discord
    "overlays": [],  # boxes over the video: {"file": image or "" = black, "text", "x", "y", "w", "h" as 0–1 of the picture}
    "postRoll": 5,  # seconds after the end
    "maxGB": 100,  # oldest videos are removed above this
    "keepWipes": False,  # False: only kills stay when WoW closes (and 2 wipes per raid boss meanwhile)
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


def track_names(cfg):
    return ["WoW"] if only_wow(cfg) else TRACK_NAMES
AUDIO_INPUTS = [
    {"name": "WoW-ljud", "target": "World of Warcraft", "tracks": [1, 2]},
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


def obs_encoders():
    """Codecs OBS can record with on this computer, from OBS's latest log."""
    logs = sorted((OBS_CONFIG / "logs").glob("*.txt"), key=lambda p: p.stat().st_mtime)
    text = logs[-1].read_text(errors="replace") if logs else ""
    nvenc = "obs_nvenc_h264_tex" in text or "jim_nvenc" in text
    found = {"h264": nvenc, "hevc": nvenc and "obs_nvenc_hevc_tex" in text,
             "av1": nvenc and "AV1 supported: true" in text, "x264": True}
    return {"hardware": nvenc, "codecs": found, "known": bool(text)}


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


def encoder_settings(cfg, codec):
    """OBS's recording encoder (advanced output mode): which encoder, and its settings –
    a bitrate from the quality choice. H.264 needs more than HEVC for the same picture,
    30 fps less than 60."""
    mbit = QUALITY_MBIT.get(cfg.get("quality"), 10)
    if codec in ("h264", "x264"):
        mbit *= 1.5
    if int(cfg["fps"]) <= 30:
        mbit *= 0.7
    kbit = int(mbit * 1000)
    if codec == "x264":
        return "obs_x264", {"rate_control": "VBR", "bitrate": kbit, "preset": "veryfast", "keyint_sec": 2}
    name = {"h264": "obs_nvenc_h264_tex", "hevc": "obs_nvenc_hevc_tex", "av1": "obs_nvenc_av1_tex"}[codec]
    return name, {"rate_control": "VBR", "bitrate": kbit, "max_bitrate": int(kbit * 1.5),
                  "preset2": "p5", "tune": "hq", "multipass": "qres", "keyint_sec": 2, "bf": 2}


def profile_dir():
    return OBS_CONFIG / "basic/profiles" / OBS_NAME


def write_encoder_file(cfg):
    """recordEncoder.json in our OBS profile – only while OBS is closed (OBS reads it at
    start and writes its own copy when it quits)."""
    enc = obs_encoders()
    codec = pick_codec(cfg, enc)
    _, settings = encoder_settings(cfg, codec)
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
    codec = pick_codec(cfg, obs_encoders())
    encoder, settings = encoder_settings(cfg, codec)
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


def set_audio(obs, cfg):
    """Your microphone (the system's default one, with RNNoise noise suppression and a noise
    gate against breathing) on tracks
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
    gate = MIC_GATES.get(cfg.get("micGate", "normal"))
    settings = dict(gate or MIC_GATES["normal"], attack_time=25, hold_time=200, release_time=150)
    if MIC_GATE not in filters:
        obs.call("CreateSourceFilter", {"sourceName": MIC, "filterName": MIC_GATE, "filterKind": "noise_gate_filter",
                                        "filterSettings": settings}, check=False)
    else:
        obs.call("SetSourceFilterSettings", {"sourceName": MIC, "filterName": MIC_GATE,
                                             "filterSettings": settings}, check=False)
    obs.call("SetSourceFilterEnabled", {"sourceName": MIC, "filterName": MIC_GATE,
                                        "filterEnabled": gate is not None}, check=False)
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
        screens = [o for o in json.loads(out)["outputs"] if o.get("enabled")]
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


# ---------------------------------------------------------------- videos

def safe_name(text):
    return re.sub(r'[/\\:*?"<>|]', "", text).strip() or "WoW"


def video_files(folder):
    folder = Path(folder)
    out = []
    for meta in sorted(folder.glob("*.json"), reverse=True):
        try:
            data = json.loads(meta.read_text())
        except (OSError, ValueError):
            continue
        video = folder / data.get("file", "")
        if not video.is_file():
            continue
        data["path"] = str(video)
        data["size"] = video.stat().st_size
        thumb = meta.with_suffix(".jpg")
        data["thumb"] = str(thumb) if thumb.exists() else ""
        out.append(data)
    out.sort(key=lambda v: v.get("started", 0), reverse=True)
    return out


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


def drop_non_kills(folder):
    """When WoW closes: everything that is not a kill (or a key in time) goes, unless kept."""
    gone = [v for v in video_files(folder) if v.get("result") not in KEPT_RESULTS and not v.get("keep")]
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
        if v.get("keep"):
            continue
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
    if out.get("errors") and not out.get("data"):
        raise RuntimeError(out["errors"][0].get("message", "fel från Warcraft Logs"))
    return out["data"]


def server_slug(realm):
    """Realm in the combat log ("TwistingNether", "Al'Akir") → Warcraft Logs' slug."""
    realm = re.sub(r"(?<=[a-z])(?=[A-Z])", "-", realm).replace("'", "")
    return re.sub(r"[^a-z0-9-]", "", realm.lower().replace(" ", "-"))


REPORT_FIELDS = ("code startTime endTime fights { id encounterID name kill startTime endTime "
                 "bossPercentage fightPercentage keystoneLevel difficulty }")


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
                "parse": parse, "ilvlParse": ilvl_parse,
                "deaths": deaths.get(name, 0)})
    players.sort(key=lambda p: (ROLE_ORDER.get(p["role"], 3), -p["dps"]))
    return {"players": players, "deaths": sum(deaths.values()), "fetched": time.time(),
            "ranked": bool(pdps or phps)}


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
                        "bossPercentage": f.get("bossPercentage"),
                        "url": f"{WCL}/reports/{rep['code']}#fight={f['id']}"}
    return best
