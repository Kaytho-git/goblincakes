"""GoblinShare – files and text between the computers and phones on the same network (1 Nov, the user's
wish: "ett goblin share program som alla på ens nätverk ser med samma os").

Speaks LocalSend's open protocol v2 (https://github.com/localsend/protocol), so the same thing reaches
other GOBLINCAKES computers (GoblinShare) and phones/Windows/Mac with the LocalSend app – the family has
both Android and iPhones. Only the standard library (+ the `openssl` command for the certificate).

    discovery   UDP multicast 224.0.0.167:53317 – a JSON announcement; others answer with
                POST /api/localsend/v2/register (or a multicast reply with announce false).
                "Leta igen" also asks every address in the local /24 (GET …/info) for routers that
                block multicast.
    receiving   HTTPS on port 53317 (self-signed certificate, fingerprint = SHA-256 of it), only from
                other GoblinShares (deviceModel GOBLINCAKES + an answer on our own /api/goblincakes):
                prepare-upload (asks: notification with Ta emot / Neka + the window; trusted
                devices directly) → upload per file → saved in the GoblinShare folder.
                LocalSend apps can be sent to, but what they send is turned away (403).
                A single text/plain "file" with a preview = a message (no upload, answer 204).
    sending     prepare-upload to the other one (waits until they answer) → upload per file.
    extra       GET /api/goblincakes/v1/info – the accent colour of another GOBLINCAKES computer
                (LocalSend never asks for it; its own announcement is left untouched).
    orders      (3 Nov, the user: the wife orders a picture from Kakan) a single "file" of the type
                ORDER_TYPE with the wish as its preview, like a message – only between GOBLINCAKES
                computers. Kept in orders.json; a notification with Starta/Senare, and Starta runs
                /usr/share/goblincakes/ai/order.py, which asks Goblin AI and sends the answer and the
                pictures back. Files from a computer we ordered from (the last 3 days) need no Ta emot.

The service (/usr/libexec/goblincakes-share run, user service goblincakes-share) owns everything; the
window (goblin-share) and `goblin share` talk to it over a Unix socket: one JSON line in, one out.
"""
import hashlib
import http.client
import io
import json
import mimetypes
import os
import secrets
import socket
import socketserver
import ssl
import struct
import subprocess
import sys
import threading
import time
import urllib.parse
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

PORT = int(os.environ.get("GOBLINCAKES_SHARE_PORT", 53317))
GROUP = "224.0.0.167"
API = "/api/localsend/v2"
OWN_API = "/api/goblincakes/v1"
PROTOCOL_VERSION = "2.1"
MODEL = "GOBLINCAKES"           # deviceModel: how two GoblinShares know each other

HOME = Path.home()
CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config") / "goblincakes"
CONFIG = CONFIG_DIR / "share.json"
FLAG = CONFIG_DIR / "share-on"   # the user service only runs with it (Config → GoblinShare, the window)
DATA = Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local/share") / "goblincakes/share"
HISTORY = DATA / "history.json"
CHATS = DATA / "chats.json"     # the messages per device (Text → the chat window, 3 Nov)
ORDERS = DATA / "orders.json"
ORDER_TYPE = "application/x-goblincakes-order"
ORDER_RUNNER = Path(__file__).resolve().parent.parent / "ai/order.py"
ORDER_KEEP = 30
ORDER_REPLY_DAYS = 3    # files from a computer we ordered from are taken without asking for this long
CHATGPT_APP = Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local/share") / "chatgpt-app/.goblincakes.json"


def chatgpt_installed():
    """OpenAI's ChatGPT app in the home folder (goblincakes-chatgpt) – an order can be drawn there."""
    return CHATGPT_APP.is_file()
RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}")
SOCK = Path(os.environ.get("GOBLINCAKES_SHARE_SOCK") or RUNTIME / "goblincakes-share.sock")
UNIT = "goblincakes-share.service"

ASK_SECONDS = 180       # a request nobody answers is declined
STALE = 15 * 60         # a device not heard from in 15 min leaves the list
ANNOUNCE_EVERY = 5 * 60
HISTORY_KEEP = 60
CHAT_KEEP = 300         # messages kept per device
CHAT_LOOKING = 3        # s: the window says it shows a chat – no notification, read at once
CHUNK = 256 * 1024
SKIP_IFACES = ("lo", "podman", "docker", "virbr", "veth", "br-", "cni", "tun", "tap", "wg", "tailscale")

DEFAULTS = {
    "alias": "",            # the name others see ("" = the account's real name, else the computer's)
    "folder": "",           # where received files go ("" = Hämtade/GoblinShare)
    "trusted": [],          # fingerprints whose files are taken without asking
    "trustedNames": {},     # fingerprint → alias when trusted (the list shows them while away)
}


# ── Small helpers ─────────────────────────────────────────────────────────────

def load_config():
    cfg = dict(DEFAULTS)
    try:
        cfg.update(json.loads(CONFIG.read_text()))
    except (OSError, ValueError):
        pass
    return cfg


def save_config(cfg):
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    tmp = CONFIG.with_suffix(".tmp")
    tmp.write_text(json.dumps(cfg, ensure_ascii=False, indent=1))
    tmp.replace(CONFIG)


def default_alias():
    try:
        import pwd
        real = pwd.getpwuid(os.getuid()).pw_gecos.split(",")[0].strip()
    except (KeyError, ImportError):
        real = ""
    return real or socket.gethostname().split(".")[0] or "GOBLINCAKES"


def downloads_dir():
    """XDG_DOWNLOAD_DIR from user-dirs.dirs (Hämtade on a Swedish desktop)."""
    try:
        for line in (CONFIG_DIR.parent / "user-dirs.dirs").read_text().splitlines():
            if line.startswith("XDG_DOWNLOAD_DIR="):
                value = line.split("=", 1)[1].strip().strip('"').replace("$HOME", str(HOME))
                if value and value.rstrip("/") != str(HOME):
                    return Path(value)
    except OSError:
        pass
    for name in ("Hämtade", "Downloads"):
        if (HOME / name).is_dir():
            return HOME / name
    return HOME / "Hämtade"


def receive_folder(cfg=None):
    cfg = cfg or load_config()
    return Path(os.path.expanduser(cfg["folder"])) if cfg.get("folder") else downloads_dir() / "GoblinShare"


def safe_relpath(name):
    """The sender's file name ("mapp/under/bild.jpg" for a folder) as a path inside the folder –
    never outside it, no hidden tricks."""
    parts = []
    for part in str(name).replace("\\", "/").split("/"):
        part = "".join(c for c in part if c >= " " and c not in '<>:"|?*').strip().strip(".")
        if part:
            parts.append(part[:180])
    return Path(*parts) if parts else Path("fil")


def unique(path):
    if not path.exists():
        return path
    stem, suffix = path.stem, path.suffix
    if path.name.endswith(".tar.gz"):
        stem, suffix = path.name[:-7], ".tar.gz"
    for n in range(2, 10000):
        candidate = path.with_name(f"{stem} ({n}){suffix}")
        if not candidate.exists():
            return candidate
    return path.with_name(f"{stem} {uuid.uuid4().hex[:6]}{suffix}")


def human_size(n):
    n = float(n or 0)
    for unit in ("B", "kB", "MB", "GB"):
        if n < 1000 or unit == "GB":
            return (f"{n:.0f} {unit}" if unit == "B" or n >= 100 else f"{n:.1f} {unit}").replace(".", ",")
        n /= 1000
    return ""


def accent_color():
    for d in (Path(__file__).resolve().parents[1], Path("/usr/share/goblincakes")):
        if (d / "accent.py").exists():
            sys.path.insert(0, str(d))
            break
    try:
        import accent
        return accent.current().get("color", "#2F6FED")
    except Exception:  # noqa: BLE001 – a broken colour file must not stop the sharing
        return "#2F6FED"


def notify(title, body, actions=None, icon="goblincakes-share", wait_cb=None, urgency="normal"):
    """A notification; with actions [(key, label)] it runs in a thread and calls wait_cb(key or None).
    Returns a function that closes the notification (when the window answered first)."""
    args = ["notify-send", "-a", "GoblinShare", "-i", icon, "-u", urgency]
    if not actions:
        try:
            subprocess.Popen(args + ["-t", "6000", title, body], stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL)
        except OSError:
            pass
        return lambda: None
    box = {"id": None, "proc": None}

    def run():
        cmd = args + ["-p", "-w", "-t", "0"] + [f"--action={k}={label}" for k, label in actions] + [title, body]
        try:
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        except OSError:
            wait_cb(None)
            return
        box["proc"] = proc
        lines = []
        for line in proc.stdout:
            line = line.strip()
            if box["id"] is None and line.isdigit():
                box["id"] = line
                continue
            lines.append(line)
        proc.wait()
        keys = [k for k, _ in actions]
        wait_cb(next((l for l in lines if l in keys), None))

    threading.Thread(target=run, daemon=True).start()

    def close():
        if box["id"]:
            subprocess.run(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications",
                            "--object-path", "/org/freedesktop/Notifications", "--method",
                            "org.freedesktop.Notifications.CloseNotification", box["id"]],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if box["proc"] and box["proc"].poll() is None:
            box["proc"].terminate()
    return close


# ── Network interfaces (ioctl – no `ip` needed) ───────────────────────────────

def interfaces():
    """[(name, address, netmask)] for the IPv4 interfaces that lead to the home network."""
    import fcntl
    found = []
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        for _, name in socket.if_nameindex():
            if name.startswith(SKIP_IFACES):
                continue
            packed = struct.pack("256s", name.encode()[:15])
            try:
                addr = socket.inet_ntoa(fcntl.ioctl(s.fileno(), 0x8915, packed)[20:24])   # SIOCGIFADDR
                mask = socket.inet_ntoa(fcntl.ioctl(s.fileno(), 0x891B, packed)[20:24])   # SIOCGIFNETMASK
            except OSError:
                continue
            if not addr.startswith("127."):
                found.append((name, addr, mask))
    finally:
        s.close()
    return found


def private(addr):
    a = [int(x) for x in addr.split(".")]
    return a[0] == 10 or (a[0] == 172 and 16 <= a[1] <= 31) or (a[0] == 192 and a[1] == 168)


def subnet_hosts(addr, mask):
    """The other addresses in the interface's network – at most a /24 around it."""
    a = struct.unpack("!I", socket.inet_aton(addr))[0]
    m = struct.unpack("!I", socket.inet_aton(mask))[0]
    m = max(m, 0xFFFFFF00)
    net = a & m
    return [socket.inet_ntoa(struct.pack("!I", h)) for h in range(net + 1, (net | (~m & 0xFFFFFFFF)))
            if h != a]


# ── The certificate ───────────────────────────────────────────────────────────

def certificate():
    """(cert path, key path, fingerprint) – made once with openssl; None without openssl (then plain HTTP)."""
    DATA.mkdir(parents=True, exist_ok=True)
    cert, key = DATA / "cert.pem", DATA / "key.pem"
    if not (cert.exists() and key.exists()):
        try:
            subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-sha256",
                            "-keyout", str(key), "-out", str(cert), "-days", "7300",
                            "-subj", "/CN=GoblinShare"], check=True, capture_output=True, timeout=60)
            key.chmod(0o600)
        except (OSError, subprocess.SubprocessError):
            return None
    try:
        der = ssl.PEM_cert_to_DER_cert(cert.read_text())
    except (OSError, ValueError):
        return None
    return cert, key, hashlib.sha256(der).hexdigest()


_CLIENT_CERT = None   # (cert, key) – shown when we connect, so LocalSend knows us by the same fingerprint


def client_context():
    """LocalSend's certificates are self-signed: the connection is encrypted, the device is known by its
    fingerprint (as in LocalSend itself, which reads it from the certificate in HTTPS mode)."""
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    if _CLIENT_CERT:
        try:
            ctx.load_cert_chain(*_CLIENT_CERT)
        except (OSError, ssl.SSLError):
            pass
    return ctx


def request(peer, method, path, body=None, timeout=5, read_timeout=None, headers=None, stream=None,
            length=None, progress=None, cancelled=None, holder=None):
    """One HTTP(S) request to a device → (status, parsed JSON or text). stream = a file object to send
    as the body (length bytes), progress(n) after every piece, cancelled() → stop."""
    host, port = peer["ip"], int(peer.get("port") or PORT)
    if peer.get("protocol", "https") == "https":
        conn = http.client.HTTPSConnection(host, port, timeout=timeout, context=client_context())
    else:
        conn = http.client.HTTPConnection(host, port, timeout=timeout)
    if holder is not None:
        holder["conn"] = conn   # cancel() closes it while we wait for the answer
    try:
        hdrs = dict(headers or {})
        data = None
        if body is not None:
            data = json.dumps(body).encode()
            hdrs["Content-Type"] = "application/json"
            hdrs["Content-Length"] = str(len(data))
        elif stream is not None:
            hdrs["Content-Type"] = "application/octet-stream"
            hdrs["Content-Length"] = str(length)
        else:
            hdrs["Content-Length"] = "0" if method == "POST" else hdrs.get("Content-Length", "0")
        conn.connect()
        if read_timeout:
            conn.sock.settimeout(read_timeout)
        conn.putrequest(method, path)
        for k, v in hdrs.items():
            conn.putheader(k, v)
        conn.endheaders()
        if data:
            conn.send(data)
        elif stream is not None:
            while True:
                if cancelled and cancelled():
                    raise InterruptedError
                piece = stream.read(CHUNK)
                if not piece:
                    break
                conn.send(piece)
                if progress:
                    progress(len(piece))
        resp = conn.getresponse()
        raw = resp.read()
        try:
            parsed = json.loads(raw) if raw else None
        except ValueError:
            parsed = raw.decode(errors="replace")
        return resp.status, parsed
    finally:
        conn.close()


# ── The service ───────────────────────────────────────────────────────────────

class Share:
    def __init__(self):
        self.lock = threading.RLock()
        self.cfg = load_config()
        cert = certificate()
        global _CLIENT_CERT
        if cert:
            self.cert, self.key, self.fingerprint = cert
            self.protocol = "https"
            _CLIENT_CERT = (str(self.cert), str(self.key))
        else:
            self.cert = self.key = None
            self.fingerprint = secrets.token_hex(32)
            self.protocol = "http"
        self.peers = {}         # fingerprint → device
        self.incoming = {}      # session id → a request/receiving
        self.outgoing = {}      # job id → a sending
        self.history = self._load_history()
        self.chats = self._load_chats()
        self.looking = {}       # fingerprint → when the window last showed its chat
        self.orders = self._load_orders()
        self.error = ""
        self.started = time.time()
        self.last_sweep = 0
        self.accent = accent_color()
        self.http = None
        self.udp = None
        self.stop = threading.Event()

    # ---------------------------------------------------------- who we are
    def alias(self):
        return (self.cfg.get("alias") or "").strip() or default_alias()

    def info(self, announce=None):
        d = {"alias": self.alias(), "version": PROTOCOL_VERSION, "deviceModel": MODEL, "deviceType": "desktop",
             "fingerprint": self.fingerprint, "port": PORT, "protocol": self.protocol, "download": False}
        if announce is not None:
            d["announce"] = announce
            d["announcement"] = announce   # protocol v1 devices
        return d

    # ---------------------------------------------------------- history
    def _load_history(self):
        try:
            return json.loads(HISTORY.read_text())[:HISTORY_KEEP]
        except (OSError, ValueError):
            return []

    def remember(self, entry):
        entry.setdefault("t", time.time())
        with self.lock:
            self.history.insert(0, entry)
            del self.history[HISTORY_KEEP:]
            try:
                DATA.mkdir(parents=True, exist_ok=True)
                tmp = HISTORY.with_suffix(".tmp")
                tmp.write_text(json.dumps(self.history, ensure_ascii=False))
                tmp.replace(HISTORY)
            except OSError:
                pass

    # ---------------------------------------------------------- chats (the messages, per device)
    def _load_chats(self):
        """{fingerprint: {"alias", "read", "messages": [{id, dir, text, t, state, why}] oldest first}}.
        Messages in the history from before the chats (3 Nov) move here once."""
        try:
            chats = json.loads(CHATS.read_text())
        except (OSError, ValueError):
            chats = None
        if chats is not None:
            return chats
        chats = {}
        for h in reversed(self.history):
            if h.get("kind") == "text" and h.get("fingerprint"):
                c = chats.setdefault(h["fingerprint"], {"alias": h.get("alias", ""), "read": 0, "messages": []})
                c["messages"].append({"id": uuid.uuid4().hex[:12], "dir": h.get("dir", "in"), "text": h.get("text", ""),
                                      "t": h.get("t", 0), "state": h.get("state", "klart"), "why": h.get("why", "")})
                c["read"] = max(c["read"], h.get("t", 0))   # the old ones count as read
        self.history = [h for h in self.history if h.get("kind") != "text"]
        self._save_chats(chats)
        try:
            HISTORY.write_text(json.dumps(self.history, ensure_ascii=False))
        except OSError:
            pass
        return chats

    def _save_chats(self, chats=None):
        try:
            DATA.mkdir(parents=True, exist_ok=True)
            tmp = CHATS.with_suffix(".tmp")
            tmp.write_text(json.dumps(self.chats if chats is None else chats, ensure_ascii=False))
            tmp.replace(CHATS)
        except OSError:
            pass

    def chat_add(self, fp, alias, direction, text, state="klart", why="", mid=None):
        """A message into the chat with a device → its id."""
        with self.lock:
            c = self.chats.setdefault(fp, {"alias": alias, "read": 0, "messages": []})
            c["alias"] = alias or c.get("alias", "")
            m = {"id": mid or uuid.uuid4().hex[:12], "dir": direction, "text": text[:20000], "t": time.time(),
                 "state": state, "why": why}
            c["messages"].append(m)
            del c["messages"][:-CHAT_KEEP]
            if direction == "in" and time.time() - self.looking.get(fp, 0) < CHAT_LOOKING:
                c["read"] = m["t"]
            self._save_chats()
            return m["id"]

    def chat_state(self, fp, mid, state, why=""):
        with self.lock:
            for m in reversed(self.chats.get(fp, {}).get("messages", [])):
                if m["id"] == mid:
                    m["state"], m["why"] = state, why
                    self._save_chats()
                    return

    def chat_summary(self):
        """Per device: name, unread messages, the last one – for the cards' Text button."""
        out = {}
        for fp, c in self.chats.items():
            msgs = c.get("messages", [])
            out[fp] = {"alias": c.get("alias", ""), "last": msgs[-1]["t"] if msgs else 0,
                       "unread": sum(1 for m in msgs if m["dir"] == "in" and m["t"] > c.get("read", 0))}
        return out

    # ---------------------------------------------------------- orders (to Kakan on this computer)
    @staticmethod
    def _load_orders():
        try:
            data = json.loads(ORDERS.read_text())
            return [o for o in data if isinstance(o, dict) and o.get("id")][:ORDER_KEEP]
        except (OSError, ValueError):
            return []

    def _save_orders(self):
        with self.lock:
            try:
                DATA.mkdir(parents=True, exist_ok=True)
                tmp = ORDERS.with_suffix(".tmp")
                tmp.write_text(json.dumps(self.orders[:ORDER_KEEP], ensure_ascii=False))
                tmp.replace(ORDERS)
            except OSError:
                pass

    def order(self, oid):
        with self.lock:
            return next((o for o in self.orders if o["id"] == oid), None)

    def new_order(self, sender, text):
        o = {"id": uuid.uuid4().hex[:10], "alias": sender["alias"], "fingerprint": sender["fingerprint"],
             "text": text, "t": time.time(), "state": "väntar", "why": ""}
        with self.lock:
            self.orders.insert(0, o)
        self._save_orders()
        self.remember({"dir": "in", "kind": "order", "order": o["id"], "alias": o["alias"],
                       "fingerprint": o["fingerprint"], "text": text, "state": "klart"})
        # Who does it is chosen when it's started (3 Nov, the user): Goblin AI here, or ChatGPT for proper pictures
        actions = [("start", "Goblin AI")] + ([("chatgpt", "ChatGPT")] if chatgpt_installed() else []) + [("later", "Senare")]
        notify(f"Beställning från {o['alias']}", text[:400], actions=actions,
               wait_cb=lambda key: self.start_order(o["id"], "chatgpt" if key == "chatgpt" else "ai")
               if key in ("start", "chatgpt") else None)
        return o

    def start_order(self, oid, via="ai"):
        """Kakan (via "ai") or the ChatGPT app ("chatgpt") takes the order, or a finished answer is sent
        again → "" or why not."""
        via = "chatgpt" if via == "chatgpt" else "ai"
        with self.lock:
            o = self.order(oid)
            if not o:
                return "Beställningen finns inte längre"
            if o["state"] == "pågår" and time.time() - o.get("started", 0) < 30 * 60:
                return "Beställningen pågår redan"  # (after half an hour it may be started again: it hung)
            if o["state"] == "skickad":
                return "Beställningen är redan skickad"
            if o.get("answer") is None and not o.get("paths"):
                o["via"] = via  # (a finished answer is only sent again, whoever made it)
            o["state"], o["why"], o["started"] = "pågår", "", time.time()
        self._save_orders()
        try:
            subprocess.Popen([sys.executable, str(ORDER_RUNNER), "run", oid, "--via", o.get("via") or "ai"],
                             start_new_session=True,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except OSError as e:
            self.update_order(oid, {"state": "fel", "why": f"Kunde inte starta Goblin AI: {e.strerror}"})
            return "Kunde inte starta Goblin AI"
        return ""

    def update_order(self, oid, fields):
        with self.lock:
            o = self.order(oid)
            if not o:
                return False
            for k in ("state", "why", "answer", "paths", "service"):
                if k in fields:
                    o[k] = fields[k]
        self._save_orders()
        return True

    def forget_order(self, oid):
        with self.lock:
            self.orders = [o for o in self.orders if o["id"] != oid]
        self._save_orders()
        return True

    def awaits_reply(self, fp):
        """We sent this computer an order lately: its answer (the pictures) comes in without Ta emot."""
        now = time.time()
        with self.lock:
            return any(h.get("kind") == "order" and h.get("dir") == "out" and h.get("fingerprint") == fp
                       and h.get("state") == "klart" and now - h.get("t", 0) < ORDER_REPLY_DAYS * 86400
                       for h in self.history)

    # ---------------------------------------------------------- devices
    def saw(self, info, ip, how):
        if not isinstance(info, dict):
            return None
        fp = str(info.get("fingerprint") or "")[:128]
        if not fp or fp == self.fingerprint:
            return None
        try:
            port = int(info.get("port") or self.peers.get(fp, {}).get("port") or PORT)
        except (TypeError, ValueError):
            port = PORT
        if not 0 < port < 65536:
            port = PORT
        with self.lock:
            old = self.peers.get(fp, {})
            peer = {
                "fingerprint": fp,
                "alias": str(info.get("alias") or old.get("alias") or "Okänd")[:60],
                "deviceModel": str(info.get("deviceModel") or old.get("deviceModel") or "")[:40],
                "deviceType": str(info.get("deviceType") or old.get("deviceType") or "desktop"),
                "ip": ip,
                "port": port,
                "protocol": "http" if (info.get("protocol") or old.get("protocol")) == "http" else "https",
                "seen": time.time(),
                "how": how,
                "accent": old.get("accent"),
            }
            new = fp not in self.peers
            self.peers[fp] = peer
            if fp in self.cfg.get("trusted", []) and self.cfg.get("trustedNames", {}).get(fp) != peer["alias"]:
                self.cfg.setdefault("trustedNames", {})[fp] = peer["alias"]
                save_config(self.cfg)
        if peer["deviceModel"] == MODEL and (new or not peer.get("accent")):
            threading.Thread(target=self._ask_accent, args=(fp,), daemon=True).start()
        return peer

    def _ask_accent(self, fp):
        peer = self.peers.get(fp)
        if not peer:
            return
        try:
            status, data = request(peer, "GET", OWN_API + "/info", timeout=3)
        except (OSError, ssl.SSLError, http.client.HTTPException):
            return
        if status == 200 and isinstance(data, dict) and str(data.get("accent", "")).startswith("#"):
            with self.lock:
                if fp in self.peers:
                    self.peers[fp]["accent"] = data["accent"][:7]

    def find_peer(self, word):
        """A fingerprint, or a (part of a) name."""
        with self.lock:
            peers = list(self.peers.values())
        if word in self.peers:
            return self.peers[word]
        w = word.strip().lower()
        exact = [p for p in peers if p["alias"].lower() == w]
        if exact:
            return exact[0]
        part = [p for p in peers if w and w in p["alias"].lower()]
        return part[0] if len(part) == 1 else None

    # ---------------------------------------------------------- discovery
    def announce(self, announce=True):
        msg = json.dumps(self.info(announce=announce)).encode()
        sent = False
        for _, addr, _ in interfaces() or [("", "0.0.0.0", "")]:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
            try:
                s.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 1)
                if addr != "0.0.0.0":
                    s.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_IF, socket.inet_aton(addr))
                s.sendto(msg, (GROUP, PORT))
                sent = True
            except OSError:
                pass
            finally:
                s.close()
        return sent

    def udp_loop(self):
        while not self.stop.is_set():
            try:
                s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
                s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                if hasattr(socket, "SO_REUSEPORT"):
                    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
                s.bind(("", PORT))
                joined = 0
                for _, addr, _ in interfaces():
                    try:
                        s.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP,
                                     socket.inet_aton(GROUP) + socket.inet_aton(addr))
                        joined += 1
                    except OSError:
                        pass
                if not joined:
                    s.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP,
                                 socket.inet_aton(GROUP) + socket.inet_aton("0.0.0.0"))
                self.udp = s
                s.settimeout(30)
                self.announce()
                last_ifaces = interfaces()
                while not self.stop.is_set():
                    try:
                        data, (ip, _) = s.recvfrom(65536)
                    except socket.timeout:
                        if interfaces() != last_ifaces:   # wifi changed, cable in: join again
                            break
                        continue
                    try:
                        msg = json.loads(data)
                    except ValueError:
                        continue
                    if not isinstance(msg, dict):
                        continue
                    try:
                        peer = self.saw(msg, ip, "multicast")
                    except Exception as e:  # noqa: BLE001 – a strange announcement must not stop listening
                        print("annons:", e, file=sys.stderr)
                        continue
                    if peer and (msg.get("announce") or msg.get("announcement")):
                        threading.Thread(target=self._answer, args=(peer,), daemon=True).start()
                s.close()
            except OSError as e:
                print("multicast:", e, file=sys.stderr)
                self.stop.wait(15)

    def _answer(self, peer):
        """Someone said hello: tell them who we are (HTTP register, else a multicast reply)."""
        try:
            status, data = request(peer, "POST", API + "/register", body=self.info(), timeout=3)
            if status == 200 and isinstance(data, dict):
                self.saw({**data, "port": peer["port"], "protocol": peer["protocol"]}, peer["ip"], "register")
                return
        except (OSError, ssl.SSLError, http.client.HTTPException):
            pass
        self.announce(announce=False)

    def sweep(self):
        """The protocol's HTTP discovery: register with every address in the local network (routers that
        stop multicast, a phone whose app was asleep when we announced) – they learn about us too."""
        self.last_sweep = time.time()
        hosts = []
        for _, addr, mask in interfaces():
            if private(addr):
                hosts += subnet_hosts(addr, mask)

        def ask(ip):
            for proto in ("https", "http"):
                peer = {"ip": ip, "port": PORT, "protocol": proto}
                try:
                    status, data = request(peer, "POST", API + "/register", body=self.info(), timeout=1.2)
                except (OSError, ssl.SSLError, http.client.HTTPException):
                    if proto == "https":
                        continue
                    return
                if status == 200 and isinstance(data, dict):
                    self.saw({**data, "port": PORT, "protocol": proto}, ip, "sweep")
                return

        with ThreadPoolExecutor(max_workers=64) as pool:
            list(pool.map(ask, hosts[:1024]))

    def scan(self, sweep=False):
        self.announce()
        if sweep:
            threading.Thread(target=self.sweep, daemon=True).start()

    def housekeeping(self):
        while not self.stop.wait(20):
            now = time.time()
            with self.lock:
                for fp in [fp for fp, p in self.peers.items() if now - p["seen"] > STALE]:
                    del self.peers[fp]
                for sid, s in list(self.incoming.items()):
                    if s["state"] in ("klart", "nekad", "avbruten", "fel") and now - s["changed"] > 30:
                        del self.incoming[sid]
                    elif s["state"] == "tar emot" and now - s["changed"] > 600:
                        self._end_incoming(s, "avbruten", "Inget hände på tio minuter")
                for jid, j in list(self.outgoing.items()):
                    if j["state"] in ("klart", "nekad", "avbruten", "fel") and now - j["changed"] > 30:
                        del self.outgoing[jid]
            if now - self.started > 10 and int(now) % ANNOUNCE_EVERY < 20:
                self.announce()
            new_accent = accent_color()
            if new_accent != self.accent:
                self.accent = new_accent

    # ---------------------------------------------------------- receiving
    def prepare_upload(self, ip, body):
        """→ (status, JSON or None)."""
        if not isinstance(body, dict) or not isinstance(body.get("info"), dict):
            return 400, {"message": "Request body malformed"}
        files = body.get("files")
        if not isinstance(files, dict) or not files:
            return 400, {"message": "Request body malformed"}
        items = []
        for key, f in files.items():
            try:
                if not isinstance(f, dict) or int(f.get("size") or 0) < 0:
                    raise ValueError
            except (TypeError, ValueError):
                return 400, {"message": "Request body malformed"}
            items.append({"id": str(f.get("id") or key), "name": str(f.get("fileName") or "fil"),
                          "sha256": str(f.get("sha256") or "").lower() or None,
                          "size": int(f.get("size") or 0), "type": str(f.get("fileType") or ""),
                          "preview": f.get("preview"),
                          "modified": ((f.get("metadata") or {}).get("modified") if isinstance(f.get("metadata"), dict)
                                       else None)})

        # Only from other GoblinShares (1 Nov, the user's decision): LocalSend apps (phones, Windows) can get
        # files from us but not send here. Its own word (deviceModel) and an answer on our own address, which
        # LocalSend doesn't have – turned away at once, no notification.
        if not self.is_goblinshare(body["info"], ip):
            return 403, {"message": "Only GoblinShare devices can send here"}

        # Trusted = the fingerprint AND the address the device was found at. LocalSend reads the sender's
        # fingerprint from its certificate; Python's ssl can't take an unknown client certificate, so a
        # copied fingerprint alone must not be enough (files would only land in the folder, but still).
        fp = str(body["info"].get("fingerprint") or "")
        known = self.peers.get(fp)
        trusted = (fp in self.cfg.get("trusted", []) or self.awaits_reply(fp)) and bool(known) \
            and known["ip"] == ip and known.get("how") != "upload"
        # A known device's entry is only updated from its own address (a copy can't take over its place)
        sender = (self.saw(body["info"], ip, "upload" if not known else known["how"])
                  if not known or known["ip"] == ip else None) or {
            "fingerprint": str(body["info"].get("fingerprint", "")), "alias": str(body["info"].get("alias") or "Okänd"),
            "deviceModel": str(body["info"].get("deviceModel") or ""), "deviceType": "desktop", "ip": ip}

        # An order to Kakan: one "file" of our own type with the wish as its preview
        if len(items) == 1 and items[0]["type"] == ORDER_TYPE:
            text = items[0]["preview"].strip()[:4000] if isinstance(items[0]["preview"], str) else ""
            if not text:
                return 400, {"message": "Empty order"}
            self.new_order(sender, text)
            return 204, None

        # A message: one text file with the text as its preview
        if len(items) == 1 and items[0]["type"] in ("text/plain", "text") and isinstance(items[0]["preview"], str):
            text = items[0]["preview"]
            fp = sender["fingerprint"]
            self.chat_add(fp, sender["alias"], "in", text)
            if time.time() - self.looking.get(fp, 0) >= CHAT_LOOKING:   # not when its chat is on the screen
                def opened(key, fp=fp):
                    if key:
                        try:
                            subprocess.Popen(["goblin-share", "--chat", fp], stdout=subprocess.DEVNULL,
                                             stderr=subprocess.DEVNULL, start_new_session=True)
                        except OSError:
                            pass
                notify(f"Meddelande från {sender['alias']}", text[:400],
                       actions=[("default", "Öppna chatten"), ("open", "Öppna chatten")], wait_cb=opened)
            return 204, None

        with self.lock:
            waiting = [s for s in self.incoming.values() if s["state"] == "frågar"]
            if len(waiting) >= 5:
                return 429, {"message": "Too many requests"}
            sid = uuid.uuid4().hex
            session = {"id": sid, "ip": ip, "sender": sender, "files": {i["id"]: dict(i, token=secrets.token_hex(16),
                       received=0, done=False, path=None) for i in items}, "state": "frågar", "event": threading.Event(),
                       "answer": None, "changed": time.time(), "folder": str(receive_folder(self.cfg)),
                       "total": sum(i["size"] for i in items), "received": 0, "saved": []}
            self.incoming[sid] = session
        if trusted:
            session["answer"] = True
        else:
            count, size = len(items), human_size(session["total"])
            what = items[0]["name"] if count == 1 else f"{count} filer"
            names = ", ".join(i["name"] for i in items[:4]) + (" …" if count > 4 else "")
            close = notify(f"{sender['alias']} vill skicka {what} ({size})", names,
                           actions=[("accept", "Ta emot"), ("decline", "Neka")],
                           wait_cb=lambda key: self.answer(sid, key == "accept") if key else None, urgency="critical")
            session["close"] = close
            session["event"].wait(ASK_SECONDS)
            close()
        with self.lock:
            if not session["answer"] or session["state"] != "frågar":
                if session["state"] == "frågar":
                    self._end_incoming(session, "nekad", "" if session["answer"] is False else "Ingen svarade")
                return 403, {"message": "File request declined by recipient"}
            session["state"] = "tar emot"
            session["changed"] = time.time()
            Path(session["folder"]).mkdir(parents=True, exist_ok=True)
            return 200, {"sessionId": sid, "files": {fid: f["token"] for fid, f in session["files"].items()}}

    def is_goblinshare(self, info, ip):
        if str(info.get("deviceModel") or "") != MODEL:
            return False
        try:
            port = int(info.get("port") or PORT)
        except (TypeError, ValueError):
            port = PORT
        peer = {"ip": ip, "port": port, "protocol": "http" if info.get("protocol") == "http" else "https"}
        try:
            status, data = request(peer, "GET", OWN_API + "/info", timeout=3)
        except (OSError, ssl.SSLError, http.client.HTTPException):
            return False
        return status == 200 and isinstance(data, dict) and data.get("app") == "GoblinShare"

    def answer(self, sid, accept):
        with self.lock:
            s = self.incoming.get(sid)
            if not s or s["state"] != "frågar" or s["answer"] is not None:
                return False
            s["answer"] = bool(accept)
        s["event"].set()
        return True

    def upload(self, ip, query, reader, length):
        sid, fid, token = (query.get(k, [""])[0] for k in ("sessionId", "fileId", "token"))
        if not (sid and fid and token):
            return 400, {"message": "Missing parameters"}
        with self.lock:
            s = self.incoming.get(sid)
            f = s and s["files"].get(fid)
            if not s or not f or f["token"] != token or s["ip"] != ip:
                return 403, {"message": "Invalid token or IP address"}
            if s["state"] != "tar emot" or f["done"]:
                return 409, {"message": "Blocked by another session"}
            folder = Path(s["folder"])
            dest = unique(folder / safe_relpath(f["name"]))
            dest.parent.mkdir(parents=True, exist_ok=True)
            part = dest.with_name(dest.name + ".part")
        digest = hashlib.sha256() if f.get("sha256") else None
        try:
            with open(part, "wb") as out:
                for piece in reader(length):
                    if s["state"] != "tar emot":
                        raise InterruptedError
                    out.write(piece)
                    if digest:
                        digest.update(piece)
                    with self.lock:
                        f["received"] += len(piece)
                        s["received"] += len(piece)
                        s["changed"] = time.time()
            if digest and digest.hexdigest() != f["sha256"]:
                part.unlink(missing_ok=True)
                return 422, {"message": "Checksum mismatch"}
            dest = unique(dest)   # another file with the same name may have finished meanwhile
            part.replace(dest)
        except (OSError, InterruptedError, ValueError):
            part.unlink(missing_ok=True)
            with self.lock:
                if s["state"] == "tar emot":
                    self._end_incoming(s, "fel", "Avsändaren avbröt eller tappade anslutningen")
            return 500, {"message": "Transfer failed"}
        if f.get("modified"):   # the file keeps its own date (the photo's day, not today)
            try:
                t = datetime.fromisoformat(str(f["modified"]).replace("Z", "+00:00")).timestamp()
                os.utime(dest, (t, t))
            except (OSError, ValueError, OverflowError):
                pass
        with self.lock:
            f["done"], f["path"] = True, str(dest)
            s["saved"].append(str(dest))
            s["changed"] = time.time()
            if all(x["done"] for x in s["files"].values()):
                self._end_incoming(s, "klart")
        return 200, None

    def cancel_incoming(self, sid, why="Avbröts av avsändaren"):
        with self.lock:
            s = self.incoming.get(sid)
            if s and s["state"] in ("frågar", "tar emot"):
                if s["state"] == "frågar":
                    s["answer"] = False
                    s["event"].set()
                self._end_incoming(s, "avbruten", why)
                return True
        return False

    def _end_incoming(self, s, state, why=""):
        s["state"], s["why"], s["changed"] = state, why, time.time()
        if s.get("close"):
            threading.Thread(target=s["close"], daemon=True).start()
        if state == "nekad" and not why:
            return    # declined by us: nothing to remember
        names = [Path(p).name for p in s["saved"]] or [f["name"] for f in s["files"].values()]
        self.remember({"dir": "in", "kind": "files", "alias": s["sender"]["alias"],
                       "fingerprint": s["sender"]["fingerprint"], "files": names[:30], "count": len(s["files"]),
                       "size": s["total"], "paths": s["saved"][:30], "folder": s["folder"], "state": state,
                       "why": why})
        if state == "klart":
            count = len(s["saved"])
            what = Path(s["saved"][0]).name if count == 1 else f"{count} filer"
            notify(f"Tog emot {what} från {s['sender']['alias']}", f"Sparat i {s['folder']}")
        elif state in ("fel", "avbruten"):
            notify(f"Överföringen från {s['sender']['alias']} avbröts", why)

    # ---------------------------------------------------------- sending
    def send(self, fp, paths=None, text=None, order=False):
        """Start sending files/folders (or a text, or an order) to a device → the job's id, or an error text."""
        peer = self.peers.get(fp) or self.find_peer(fp)
        if not peer:
            return None, "Hittar inte enheten – tryck Leta igen"
        files = []
        if order:
            text = (text or "").strip()[:4000]
            if not text:
                return None, "Skriv vad du vill beställa"
            if peer["deviceModel"] != MODEL:
                return None, "Beställningar går bara till GOBLINCAKES-datorer"
            data = text.encode()
            files.append({"id": uuid.uuid4().hex, "name": "bestallning.txt", "size": len(data),
                          "type": ORDER_TYPE, "preview": text, "data": data})
        elif text is not None:
            data = text.encode()
            files.append({"id": uuid.uuid4().hex, "name": f"{uuid.uuid4().hex[:8]}.txt", "size": len(data),
                          "type": "text/plain", "preview": text, "data": data})
        for p in paths or []:
            p = Path(p).expanduser()
            if p.is_dir():
                for sub in sorted(p.rglob("*")):
                    if sub.is_file() and not sub.is_symlink():
                        files.append(self._file_entry(sub, f"{p.name}/{sub.relative_to(p).as_posix()}"))
            elif p.is_file():
                files.append(self._file_entry(p, p.name))
        if not files:
            return None, "Inga filer att skicka"
        jid = uuid.uuid4().hex[:12]
        if text is not None and not order:
            self.chat_add(peer["fingerprint"], peer["alias"], "out", text, state="skickar", mid=jid)
        job = {"id": jid, "peer": dict(peer), "files": files, "state": "väntar på svar", "sent": 0,
               "total": sum(f["size"] for f in files), "cancel": False, "session": None, "why": "",
               "changed": time.time(), "text": text, "order": order}
        with self.lock:
            self.outgoing[jid] = job
        threading.Thread(target=self._send_job, args=(job,), daemon=True).start()
        return jid, ""

    @staticmethod
    def _file_entry(path, name):
        st = path.stat()
        return {"id": uuid.uuid4().hex, "name": name, "size": st.st_size, "path": str(path),
                "type": mimetypes.guess_type(path.name)[0] or "application/octet-stream", "preview": None,
                "modified": datetime.fromtimestamp(st.st_mtime, timezone.utc).isoformat()}

    def _send_job(self, job):
        peer = job["peer"]
        body = {"info": self.info(), "files": {}}
        for f in job["files"]:
            meta = {"id": f["id"], "fileName": f["name"], "size": f["size"], "fileType": f["type"],
                    "sha256": None, "preview": f["preview"]}
            if f.get("modified"):
                meta["metadata"] = {"modified": f["modified"]}
            body["files"][f["id"]] = meta
        try:
            status, data = request(peer, "POST", API + "/prepare-upload", body=body, timeout=6,
                                   read_timeout=ASK_SECONDS + 60, holder=job)
        except (OSError, ssl.SSLError, http.client.HTTPException, AttributeError) as e:
            if job["cancel"]:
                return self._end_job(job, "avbruten")
            return self._end_job(job, "fel", f"Når inte {peer['alias']} ({type(e).__name__})")
        if job["cancel"]:
            if status == 200 and isinstance(data, dict) and data.get("sessionId"):
                self._cancel_remote(peer, data["sessionId"])
            return self._end_job(job, "avbruten")
        if status == 204:
            return self._end_job(job, "klart")
        if status != 200 or not isinstance(data, dict):
            why = {401: "Mottagaren kräver en PIN-kod (stäng av den i LocalSend)",
                   403: f"{peer['alias']} tackade nej", 409: f"{peer['alias']} tar emot från någon annan just nu",
                   429: "För många förfrågningar – vänta en stund"}.get(status, f"Fel {status} från mottagaren")
            return self._end_job(job, "nekad" if status == 403 else "fel", why)
        job["session"] = sid = data.get("sessionId", "")
        tokens = data.get("files") or {}
        job["state"], job["changed"] = "skickar", time.time()
        # The receiver may have taken only some of the files
        job["total"] = sum(f["size"] for f in job["files"] if f["id"] in tokens)

        def moved(n):
            job["sent"] += n
            job["changed"] = time.time()

        for f in job["files"]:
            token = tokens.get(f["id"])
            if not token:
                continue
            query = urllib.parse.urlencode({"sessionId": sid, "fileId": f["id"], "token": token})
            try:
                if "data" in f:
                    stream = io.BytesIO(f["data"])
                    status, _ = request(peer, "POST", f"{API}/upload?{query}", stream=stream, length=f["size"],
                                        timeout=6, read_timeout=120, progress=moved, cancelled=lambda: job["cancel"])
                else:
                    with open(f["path"], "rb") as stream:
                        status, _ = request(peer, "POST", f"{API}/upload?{query}", stream=stream, length=f["size"],
                                            timeout=6, read_timeout=120, progress=moved,
                                            cancelled=lambda: job["cancel"])
            except InterruptedError:
                self._cancel_remote(peer, sid)
                return self._end_job(job, "avbruten")
            except (OSError, ssl.SSLError, http.client.HTTPException) as e:
                self._cancel_remote(peer, sid)
                return self._end_job(job, "fel", f"Överföringen bröts ({type(e).__name__})")
            if status != 200:
                self._cancel_remote(peer, sid)
                return self._end_job(job, "fel", f"Mottagaren svarade {status} på {Path(f['name']).name}")
        self._end_job(job, "klart")

    def _cancel_remote(self, peer, sid):
        try:
            request(peer, "POST", f"{API}/cancel?" + urllib.parse.urlencode({"sessionId": sid}), timeout=3)
        except (OSError, ssl.SSLError, http.client.HTTPException):
            pass

    def _end_job(self, job, state, why=""):
        with self.lock:
            job["state"], job["why"], job["changed"] = state, why, time.time()
        peer = job["peer"]
        if job.get("text") is not None and not job.get("order"):
            self.chat_state(peer["fingerprint"], job["id"], state, why)
        elif job.get("text") is not None:
            self.remember({"dir": "out", "kind": "order", "alias": peer["alias"], "fingerprint": peer["fingerprint"],
                           "text": job["text"][:20000], "state": state, "why": why})
        else:
            self.remember({"dir": "out", "kind": "files", "alias": peer["alias"], "fingerprint": peer["fingerprint"],
                           "files": [f["name"] for f in job["files"]][:30], "count": len(job["files"]),
                           "size": sum(f["size"] for f in job["files"]),
                           "paths": [f["path"] for f in job["files"] if f.get("path")][:30], "state": state,
                           "why": why})
        if state == "fel" or state == "nekad":
            notify(f"Kunde inte skicka till {peer['alias']}", why)

    def cancel(self, jid):
        with self.lock:
            job = self.outgoing.get(jid)
            if job:
                if job["state"] not in ("väntar på svar", "skickar"):
                    return False
                job["cancel"] = True
                if job["state"] == "väntar på svar" and job.get("conn"):
                    try:
                        job["conn"].sock and job["conn"].sock.shutdown(socket.SHUT_RDWR)
                    except OSError:
                        pass
                return True
        return self.cancel_incoming(jid, "Du avbröt")

    # ---------------------------------------------------------- settings
    def trust(self, fp, on):
        with self.lock:
            trusted = [x for x in self.cfg.get("trusted", []) if x != fp]
            names = dict(self.cfg.get("trustedNames", {}))
            names.pop(fp, None)
            if on:
                trusted.append(fp)
                if fp in self.peers:
                    names[fp] = self.peers[fp]["alias"]
            self.cfg["trusted"], self.cfg["trustedNames"] = trusted, names
            save_config(self.cfg)

    def set(self, key, value):
        if key not in ("alias", "folder"):
            return False
        with self.lock:
            self.cfg[key] = str(value or "").strip()[:60 if key == "alias" else 1000]
            save_config(self.cfg)
        if key == "alias":
            self.announce()
        return True

    # ---------------------------------------------------------- status for the window
    def status(self):
        now = time.time()
        with self.lock:
            trusted = set(self.cfg.get("trusted", []))
            peers = sorted(self.peers.values(), key=lambda p: (p["deviceModel"] != MODEL, p["alias"].lower()))
            out = {
                "running": True,
                "alias": self.alias(),
                "aliasSet": bool((self.cfg.get("alias") or "").strip()),
                "fingerprint": self.fingerprint,
                "protocol": self.protocol,
                "port": PORT,
                "error": self.error,
                "folder": str(receive_folder(self.cfg)),
                "folderSet": bool(self.cfg.get("folder")),
                "addresses": [a for _, a, _ in interfaces()],
                "sweeping": now - self.last_sweep < 8,
                "peers": [{"fingerprint": p["fingerprint"], "alias": p["alias"], "model": p["deviceModel"],
                           "type": p["deviceType"], "ip": p["ip"], "goblincakes": p["deviceModel"] == MODEL,
                           "accent": p.get("accent") or "", "ago": int(now - p["seen"]),
                           "trusted": p["fingerprint"] in trusted} for p in peers],
                "trustedAway": [{"fingerprint": fp, "alias": self.cfg.get("trustedNames", {}).get(fp, "Okänd")}
                                for fp in trusted if fp not in self.peers],
                "requests": [{"id": s["id"], "alias": s["sender"]["alias"], "model": s["sender"].get("deviceModel", ""),
                              "fingerprint": s["sender"]["fingerprint"],
                              "files": [{"name": f["name"], "size": f["size"]} for f in list(s["files"].values())[:8]],
                              "count": len(s["files"]), "size": s["total"],
                              "left": max(0, int(ASK_SECONDS - (now - s["changed"])))}
                             for s in self.incoming.values() if s["state"] == "frågar"],
                "transfers": [{"id": s["id"], "dir": "in", "alias": s["sender"]["alias"], "count": len(s["files"]),
                               "name": next(iter(s["files"].values()))["name"], "done": s["received"],
                               "total": s["total"], "state": s["state"], "why": s.get("why", ""),
                               "folder": s["folder"]}
                              for s in self.incoming.values() if s["state"] != "frågar"
                              and not (s["state"] == "nekad" and not s.get("why"))]
                             + [{"id": j["id"], "dir": "out", "alias": j["peer"]["alias"], "count": len(j["files"]),
                                 "name": "Beställning" if j.get("order") else "Meddelande" if j.get("text") is not None
                                 else j["files"][0]["name"],
                                 "done": j["sent"], "total": j["total"], "state": j["state"], "why": j["why"]}
                                for j in self.outgoing.values()],
                "history": self.history[:40],
                "chats": self.chat_summary(),
                "chatgpt": chatgpt_installed(),
                "orders": [{k: o.get(k) for k in ("id", "alias", "fingerprint", "text", "t", "state", "why", "via")}
                           for o in self.orders if o.get("state") != "skickad"],
            }
        return out

    # ---------------------------------------------------------- the window's and goblin share's socket
    def control(self, req):
        op = req.get("op")
        if op == "status":
            return self.status()
        if op == "scan":
            self.scan(sweep=bool(req.get("sweep", True)))
            return {"ok": True}
        if op == "send":
            jid, err = self.send(str(req.get("to", "")), paths=req.get("paths") or [])
            return {"ok": bool(jid), "id": jid, "error": err}
        if op == "text":
            jid, err = self.send(str(req.get("to", "")), text=str(req.get("text", "")))
            return {"ok": bool(jid), "id": jid, "error": err}
        if op == "order":
            jid, err = self.send(str(req.get("to", "")), text=str(req.get("text", "")), order=True)
            return {"ok": bool(jid), "id": jid, "error": err}
        if op == "order_get":
            o = self.order(str(req.get("id", "")))
            return {"ok": bool(o), "order": dict(o) if o else None}
        if op == "order_start":
            why = self.start_order(str(req.get("id", "")), str(req.get("via", "ai")))
            return {"ok": not why, "error": why}
        if op == "order_update":
            return {"ok": self.update_order(str(req.get("id", "")), req.get("fields") or {})}
        if op == "order_forget":
            return {"ok": self.forget_order(str(req.get("id", "")))}
        if op == "orders":
            with self.lock:
                return {"ok": True, "orders": [dict(o) for o in self.orders]}
        if op == "answer":
            return {"ok": self.answer(str(req.get("id", "")), bool(req.get("accept")))}
        if op == "cancel":
            return {"ok": self.cancel(str(req.get("id", "")))}
        if op == "trust":
            self.trust(str(req.get("fingerprint", "")), bool(req.get("on")))
            return {"ok": True}
        if op == "set":
            return {"ok": self.set(str(req.get("key", "")), req.get("value"))}
        if op == "chat":
            # The chat window: its messages, and (looking=True) it is on the screen = all read
            fp = str(req.get("fingerprint", ""))
            with self.lock:
                c = self.chats.get(fp) or {"alias": "", "read": 0, "messages": []}
                if req.get("looking"):
                    self.looking[fp] = time.time()
                    last_in = max((m["t"] for m in c["messages"] if m["dir"] == "in"), default=0)
                    if fp in self.chats and last_in > c.get("read", 0):
                        c["read"] = last_in
                        self._save_chats()
                return {"ok": True, "alias": c.get("alias", ""), "messages": list(c["messages"])}
        if op == "chat_clear":
            with self.lock:
                self.chats.pop(str(req.get("fingerprint", "")), None)
                self._save_chats()
            return {"ok": True}
        if op == "forget":
            with self.lock:
                self.history = [h for h in self.history if h.get("t") != req.get("t")]
                try:
                    HISTORY.write_text(json.dumps(self.history, ensure_ascii=False))
                except OSError:
                    pass
            return {"ok": True}
        if op == "clear":
            with self.lock:
                self.history = []
                HISTORY.unlink(missing_ok=True)
            return {"ok": True}
        return {"ok": False, "error": "okänt kommando"}

    def control_server(self):
        share = self

        class Handler(socketserver.StreamRequestHandler):
            def handle(self):
                for line in self.rfile:
                    try:
                        reply = share.control(json.loads(line))
                    except Exception as e:  # noqa: BLE001 – one bad request must not stop the service
                        reply = {"ok": False, "error": str(e)}
                    self.wfile.write(json.dumps(reply, ensure_ascii=False).encode() + b"\n")
                    self.wfile.flush()

        SOCK.parent.mkdir(parents=True, exist_ok=True)
        SOCK.unlink(missing_ok=True)
        server = socketserver.ThreadingUnixStreamServer(str(SOCK), Handler)
        server.daemon_threads = True
        SOCK.chmod(0o600)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        return server

    # ---------------------------------------------------------- HTTP(S)
    def http_server(self):
        share = self
        ctx = None
        if self.protocol == "https":
            ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            ctx.load_cert_chain(str(self.cert), str(self.key))

        class Handler(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"
            server_version = "GoblinShare"
            sys_version = ""

            def log_message(self, *args):
                pass

            def reply(self, status, data=None):
                body = b"" if data is None else json.dumps(data, ensure_ascii=False).encode()
                self.send_response(status)
                if data is not None:
                    self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                if body:
                    self.wfile.write(body)

            def chunks(self, length):
                """The body piece by piece – Content-Length or chunked."""
                if self.headers.get("Transfer-Encoding", "").lower() == "chunked":
                    while True:
                        size = int(self.rfile.readline().split(b";")[0].strip() or b"0", 16)
                        if size == 0:
                            self.rfile.readline()
                            return
                        left = size
                        while left:
                            piece = self.rfile.read(min(CHUNK, left))
                            if not piece:
                                raise ValueError("cut off")
                            left -= len(piece)
                            yield piece
                        self.rfile.readline()
                left = length
                while left > 0:
                    piece = self.rfile.read(min(CHUNK, left))
                    if not piece:
                        raise ValueError("cut off")
                    left -= len(piece)
                    yield piece

            def json_body(self):
                n = int(self.headers.get("Content-Length") or 0)
                if n > 8 * 1024 * 1024:
                    raise ValueError("too big")
                raw = b"".join(self.chunks(n)) if n or self.headers.get("Transfer-Encoding") else b""
                return json.loads(raw) if raw else {}

            def route(self):
                url = urllib.parse.urlsplit(self.path)
                return url.path.rstrip("/"), urllib.parse.parse_qs(url.query)

            def do_GET(self):
                path, _ = self.route()
                if path in (API + "/info", "/api/localsend/v1/info"):
                    return self.reply(200, share.info())
                if path == OWN_API + "/info":
                    return self.reply(200, {"accent": share.accent, "app": "GoblinShare"})
                self.reply(404, {"message": "Not found"})

            def do_POST(self):
                path, query = self.route()
                ip = self.client_address[0]
                if ip.startswith("::ffff:"):
                    ip = ip[7:]
                try:
                    if path == API + "/upload":
                        status, data = share.upload(ip, query, self.chunks, int(self.headers.get("Content-Length") or 0))
                        return self.reply(status, data)
                    if path == API + "/cancel":
                        share.cancel_incoming(query.get("sessionId", [""])[0])
                        return self.reply(200)
                    body = self.json_body()
                except (ValueError, OSError):
                    return self.reply(400, {"message": "Request body malformed"})
                if path in (API + "/register", "/api/localsend/v1/register"):
                    share.saw(body if isinstance(body, dict) else {}, ip, "register")
                    return self.reply(200, share.info())
                if path == API + "/prepare-upload":
                    status, data = share.prepare_upload(ip, body)
                    return self.reply(status, data)
                self.reply(404, {"message": "Not found"})

        class Server(ThreadingHTTPServer):
            daemon_threads = True
            allow_reuse_address = True
            request_queue_size = 64

            def finish_request(self, request, client_address):
                # The TLS handshake in the request's own thread: a slow phone can't hold up the others
                if ctx:
                    request.settimeout(15)
                    try:
                        request = ctx.wrap_socket(request, server_side=True)
                    except (OSError, ssl.SSLError):
                        return
                    request.settimeout(300)
                super().finish_request(request, client_address)

            def handle_error(self, request, client_address):
                pass

        return Server(("0.0.0.0", PORT), Handler)

    # ---------------------------------------------------------- run
    def run(self):
        self.control_server()
        threading.Thread(target=self.housekeeping, daemon=True).start()
        while not self.stop.is_set():
            try:
                self.http = self.http_server()
                break
            except OSError as e:
                self.error = (f"Porten {PORT} används redan av ett annat program (LocalSend?) – stäng det"
                              if e.errno == 98 else f"Kan inte ta emot: {e.strerror}")
                if self.stop.wait(20):
                    return
        self.error = ""
        threading.Thread(target=self.udp_loop, daemon=True).start()
        threading.Thread(target=lambda: (time.sleep(2), self.sweep()), daemon=True).start()
        self.http.serve_forever(poll_interval=1)

    def shutdown(self):
        self.stop.set()
        if self.http:
            threading.Thread(target=self.http.shutdown, daemon=True).start()
        SOCK.unlink(missing_ok=True)


# ── The client side (window, goblin share) ────────────────────────────────────

def call(op, timeout=5, **args):
    """One request to the running service → its JSON answer, or None when it isn't running."""
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(timeout)
    try:
        s.connect(str(SOCK))
        s.sendall(json.dumps({"op": op, **args}, ensure_ascii=False).encode() + b"\n")
        buf = b""
        while not buf.endswith(b"\n"):
            piece = s.recv(65536)
            if not piece:
                break
            buf += piece
        return json.loads(buf) if buf else None
    except (OSError, ValueError):
        return None
    finally:
        s.close()


def service_active():
    return subprocess.run(["systemctl", "--user", "is-active", "--quiet", UNIT]).returncode == 0


def firewall_open():
    """Lets 53317 (TCP + UDP) in when firewalld is on and doesn't already – Fedora's workstation zone lets
    1025–65535 in, other zones don't. Changing asks for the password (polkit), like Ianseo's network switch.
    → "" (open), or why not."""
    def run(*args):
        try:
            return subprocess.run(["firewall-cmd", *args], capture_output=True, text=True, timeout=120)
        except (OSError, subprocess.TimeoutExpired):
            return None
    state = run("--state")
    if not state or state.returncode != 0:
        return ""     # no firewalld, or it's off
    listed = run("--list-ports")
    ports = (listed.stdout.split() if listed and listed.returncode == 0 else [])

    def covered(proto):
        for p in ports:
            rng, _, pr = p.partition("/")
            lo, _, hi = rng.partition("-")
            try:
                if pr == proto and int(lo) <= PORT <= int(hi or lo):
                    return True
            except ValueError:
                continue
        return False
    if covered("tcp") and covered("udp"):
        return ""
    ok = True
    for extra in (["--permanent"], []):
        r = run("--quiet", *extra, f"--add-port={PORT}/tcp", f"--add-port={PORT}/udp")
        ok = ok and bool(r) and r.returncode == 0
    return "" if ok else f"Brandväggen släpper inte in port {PORT} – andra kan inte skicka hit"


def turn_on():
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    FLAG.touch()
    why = firewall_open()
    subprocess.run(["systemctl", "--user", "daemon-reload"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["systemctl", "--user", "start", UNIT], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return why


def turn_off():
    FLAG.unlink(missing_ok=True)
    subprocess.run(["systemctl", "--user", "stop", UNIT], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
