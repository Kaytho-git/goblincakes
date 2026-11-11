"""GOBLINCAKES Dashboard – what the window shows, read without Qt (so it can be tried from a terminal):

    python3 dash.py apps|system|top|player|quota|projects|project <mapp>|browse [mapp]|tray <namn>|notices|recorder|bottom|views|config
    python3 dash.py save < {"views": [...], "apps": [...]}

apps()         the programs in the menu (the same folders as Goblin AI's `program`), with icon and group
System         CPU/GPU/temperature/RAM/disk now, with the history since the window was opened
player()       what is playing (MPRIS), music programs first; control() = previous/play-pause/next
quota()        what the quota widget saved (~/.cache/goblincakes/quota.json)
projects()     the folders in Goblin AI's PROJEKT → MAPPAR (~/.config/goblincakes/ai-mappar.json – one list)
browse(path)   the dashboard's own folder chooser (+ in PROJEKT); power() = the logout screen
tray(name)     the rows behind a system tray icon: nätverk, ljud, bluetooth, notiser, urklipp, enheter
notices()      the notifications (goblincakes-notifications) and how many are unread – the NOTISER icon's number
recorder()     GoblinRecorder's checks (OBS, WoW, the combat log, recording) – the GOBLINRECORDER frame
views()        the views (SPEL, JOBB, …) and which frames each shows – chosen in Config → Dashboard
Only the standard library; every command has a short timeout and a missing program gives an empty answer.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config") / "goblincakes"
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or HOME / ".cache") / "goblincakes"
FOLDERS = CONFIG / "ai-mappar.json"       # shared with Goblin AI (PROJEKT → MAPPAR)
SETTINGS = CONFIG / "dashboard.json"      # {"views", "view"} – the programs at the bottom are the dock's (shared)
QUOTA = CACHE / "quota.json"
QUOTA_HELPER = Path(__file__).resolve().parents[3] / "libexec/goblincakes-quota"
BATTERY_HELPER = Path(__file__).resolve().parents[3] / "libexec/goblincakes-device-battery"
# Written by goblincakes-notifications (a user service listening on the session bus) – Plasma's own history
# can't be read from outside plasmashell
NOTICES = Path(os.environ.get("XDG_STATE_HOME") or HOME / ".local/state") / "goblincakes/notiser.json"
# Written every few seconds by GoblinRecorder's service (libexec/goblincakes-recorder) – the GOBLINRECORDER frame
RECORDER_STATUS = CACHE / "recorder-status.json"
OBS_APP = "com.obsproject.Studio"

DATA_DIRS = [Path(p) for p in os.environ.get("GOBLINCAKES_DASHBOARD_APPS", "").split(":") if p] or [
    Path("/usr/share/applications"), Path("/var/lib/flatpak/exports/share/applications"),
    HOME / ".local/share/flatpak/exports/share/applications", HOME / ".local/share/applications"]
GROUPS = (("Game", "Spel"), ("AudioVideo", "Ljud och video"), ("Graphics", "Bild"), ("Network", "Internet"),
          ("Office", "Kontor"), ("Development", "Utveckling"), ("Settings", "Inställningar"),
          ("System", "System"), ("Utility", "Verktyg"))
# At the bottom when neither dashboard.json nor the dock says anything
STANDARD_APPS = ["com.mitchellh.ghostty.desktop", "org.mozilla.firefox.desktop", "org.kde.dolphin.desktop",
                 "steam.desktop", "goblin-ai.desktop", "goblincakes-config.desktop"]
MPRIS = "org.mpris.MediaPlayer2."
PLAYER = "org.mpris.MediaPlayer2.Player"
MUSIC_APPS = ("goblinamp", "spotify", "elisa", "strawberry", "audacious", "rhythmbox", "lollypop", "amberol",
              "clementine", "deadbeef", "tauon", "quodlibet", "cider", "tidal", "deezer", "youtube", "qmmp", "mpd")


def run(cmd, timeout=3):
    """The command's output, or "" (missing program, error, too slow)."""
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def busctl(*args, timeout=3):
    out = run(["busctl", "--user", "--json=short", *args], timeout)
    try:
        return json.loads(out) if out.strip() else None
    except ValueError:
        return None


# ── The programs ──────────────────────────────────────────────

def _field(text, key):
    m = re.search(rf"^{key}\[sv\]=(.+)$", text, re.M) or re.search(rf"^{key}=(.+)$", text, re.M)
    return m.group(1).strip() if m else ""


def apps():
    """[{id, name, kind, icon, group, words, path}] sorted by name – a hidden copy in the home folder hides
    the image's, and programs meant for another desktop only (OnlyShowIn without KDE) are left out."""
    found = {}
    for folder in DATA_DIRS:
        for f in sorted(folder.glob("*.desktop")):
            try:
                text = f.read_text(errors="replace").split("\n[Desktop Action", 1)[0]
            except OSError:
                continue
            only = _field(text, "OnlyShowIn")
            if (re.search(r"^(NoDisplay|Hidden)=true", text, re.M) or not _field(text, "Name")
                    or "Type=Application" not in text or (only and "KDE" not in only.split(";"))
                    or "KDE" in _field(text, "NotShowIn").split(";")):
                found.pop(f.name, None)
                continue
            cats = _field(text, "Categories").split(";")
            found[f.name] = {
                "id": f.name, "name": _field(text, "Name"), "kind": _field(text, "GenericName"),
                "icon": _field(text, "Icon"), "path": str(f),
                "group": next((sv for en, sv in GROUPS if en in cats), "Övrigt"),
                "words": " ".join(re.findall(r"^(?:Keywords|GenericName|Name|Comment)(?:\[[\w@]+\])?=(.+)$",
                                             text, re.M)).lower() + " " + f.stem.lower()}
    return sorted(found.values(), key=lambda a: a["name"].lower())


def launch(path_or_id):
    """Starts a program from its desktop file (detached). "" or why not."""
    stem = Path(path_or_id).stem if path_or_id.endswith(".desktop") else path_or_id
    cmd = ["gtk-launch", stem] if shutil.which("gtk-launch") else ["gio", "launch", path_or_id]
    try:
        subprocess.Popen(cmd, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError as e:
        return f"Kunde inte starta: {e}"
    return ""


def settings():
    try:
        data = json.loads(SETTINGS.read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def save_settings(data):
    """Whole or not at all (a reading at the same moment – NOTISER is marked read in a thread – must never see half
    a file, take it for empty and write the views away)."""
    SETTINGS.parent.mkdir(parents=True, exist_ok=True)
    tmp = SETTINGS.with_name(f".{SETTINGS.name}.{os.getpid()}")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1))
    os.replace(tmp, SETTINGS)


# ── The views (step 3): which frames each view shows, chosen in GOBLINCAKES Config → Dashboard ──

FRAMES = [("projects", "Projekt", "dina mappar – öppna i VS Code, Claude Code"),
          ("system", "System", "CPU, GPU, temperatur, RAM, disk"),
          ("wow", "WoW Stats", "karaktärer och senaste raiden (Warcraft Logs)"),
          ("cs2", "CS2 Stats", "de senaste matcherna och kartorna"),
          ("builds", "Byggen", "GOBLINCAKES byggen på GitHub (när repot finns på datorn)"),
          ("reports", "Kakan", "Kakans rapporter")]
SIDES = {"left": 3, "right": 2}           # at most this many frames on each side
MAX_VIEWS = 6
DEFAULT_VIEWS = [{"name": "SPEL", "left": ["projects", "system"], "right": ["wow", "cs2"]},
                 {"name": "JOBB", "left": ["projects", "system"], "right": ["builds", "reports"]}]
# Which frame a middle belongs to: a middle whose frame is not in the view opens as the programs
MID_FRAME = {"system": "system", "project": "projects", "raid": "wow", "char": "wow", "cs2": "cs2",
             "builds": "builds", "reports": "reports"}


def mid_fits(mid, view):
    frame = MID_FRAME.get(str(mid).split(":", 1)[0])
    return mid == "apps" or bool(frame and frame in view.get("left", []) + view.get("right", []))


def views(saved=None):
    """The views, cleaned: [{name, left, right, mid}] – known frames only, each at most once per view."""
    saved = settings() if saved is None else saved
    rows = saved.get("views")
    if not isinstance(rows, list) or not rows:
        rows = [dict(v, mid=saved.get("mid") or "apps") if i == 0 else dict(v) for i, v in enumerate(DEFAULT_VIEWS)]
    known = {f[0] for f in FRAMES}
    out = []
    for row in rows[:MAX_VIEWS]:
        if not isinstance(row, dict):
            continue
        seen, view = set(), {"name": (str(row.get("name") or "").strip() or f"VY {len(out) + 1}")[:16]}
        for side, most in SIDES.items():
            ids = [i for i in row.get(side) or [] if isinstance(i, str) and i in known and i not in seen][:most]
            seen.update(ids)
            view[side] = ids
        mid = row.get("mid") if isinstance(row.get("mid"), str) else "apps"
        view["mid"] = mid if mid_fits(mid, view) else "apps"
        out.append(view)
    return out or [dict(v, mid="apps") for v in DEFAULT_VIEWS]


def view_index(saved=None, rows=None):
    saved = settings() if saved is None else saved
    rows = views(saved) if rows is None else rows
    try:
        return max(0, min(len(rows) - 1, int(saved.get("view") or 0)))
    except (TypeError, ValueError):
        return 0


def save_views(rows, apps_ids=None):
    """From Config: the views, and (when they were changed) the programs at the bottom – shared with the dock, so
    they are written there. The dashboard reads them the next time it is shown."""
    saved = settings()
    saved["views"] = views({"views": rows})
    saved["view"] = view_index(saved, saved["views"])
    saved.pop("mid", None)                # from step 1–2: now one per view
    saved.pop("apps", None)               # until 10 Nov an own list for the dashboard: now shared with the dock
    save_settings(saved)
    if apps_ids is not None:
        return save_shared_apps([a for a in apps_ids if isinstance(a, str)])
    return True


LAYOUT = CONFIG / "desktop-layout.json"   # goblincakes-desktop-layout: the dock's apps, saved while it is gone

# GOBLINCAKES' own programs, small above the programs at the bottom (10 Nov, the user's choice: only these five)
OWN_APPS = ["goblincakes-config.desktop", "goblin-ai.desktop", "goblin-recorder.desktop", "goblin-amp.desktop",
            "goblin-share.desktop"]


def own_apps(all_apps=None):
    """GOBLINCAKES' own programs shown small above the programs at the bottom in every view (OWN_APPS, in that order)."""
    by_id = {a["id"]: a for a in (all_apps if all_apps is not None else apps())}
    return [by_id[i] for i in OWN_APPS if i in by_id]


def saved_dock_apps():
    """The layout "Dashboard" has no dock: the apps it had, saved by goblincakes-desktop-layout."""
    try:
        data = json.loads(LAYOUT.read_text())
    except (OSError, ValueError):
        return []
    if data.get("layout") != "dashboard":
        return []
    rows = (data.get("dock") or {}).get("launchers") or []
    return [r.split(":", 1)[1] for r in rows if isinstance(r, str) and r.startswith("applications:")]


DOCK_JS = ('panels().forEach(function (p) { if (p.location !== "bottom") return; '
           'p.widgets().forEach(function (w) { if (w.type !== "org.goblincakes.dock" && '
           'w.type !== "org.kde.plasma.icontasks") return; w.currentConfigGroup = ["General"]; %s }); });')


def save_shared_apps(ids):
    """The programs at the bottom = the dock's pinned apps (10 Nov, the user: the dock and the dashboard share them).
    Written into the dock (other kinds of launchers in it are kept, last); in the layout "Dashboard", where there is
    no dock, into the list goblincakes-desktop-layout puts back in the dock. True when it was saved."""
    try:
        data = json.loads(LAYOUT.read_text())
    except (OSError, ValueError):
        data = {}
    if data.get("layout") == "dashboard":
        dock = data.get("dock") if isinstance(data.get("dock"), dict) else {}
        other = [r for r in dock.get("launchers") or [] if isinstance(r, str) and not r.startswith("applications:")]
        dock["launchers"] = ["applications:" + i for i in ids] + other
        data["dock"] = dock
        tmp = LAYOUT.with_suffix(".tmp")
        tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
        tmp.replace(LAYOUT)
        return True
    wanted = json.dumps(["applications:" + i for i in ids])
    js = ('var done = false; ' + DOCK_JS % (
        'var l = w.readConfig("launchers", []); if (typeof l === "string") l = l ? l.split(",") : []; '
        'var keep = l.filter(function (x) { return x.indexOf("applications:") !== 0; }); '
        'w.writeConfig("launchers", ' + wanted + '.concat(keep)); w.reloadConfig(); done = true;')
        + ' print(done ? "done" : "none");')
    answer = busctl("call", "org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript", "s", js)
    try:
        return (answer or {}).get("data", [""])[0] == "done"
    except (IndexError, TypeError, AttributeError):
        return False


def dock_apps():
    """The desktop files pinned in the GOBLINCAKES dock (asked from plasmashell) – in the layout "Dashboard" the
    ones the dock had when it was taken away; [] when there is none."""
    saved = saved_dock_apps()
    if saved:
        return saved
    js = ('var r = []; panels().forEach(function (p) { if (p.location !== "bottom") return; '
          'p.widgets().forEach(function (w) { if (w.type !== "org.goblincakes.dock" && '
          'w.type !== "org.kde.plasma.icontasks") return; w.currentConfigGroup = ["General"]; '
          'var l = w.readConfig("launchers", []); if (typeof l === "string") l = l ? l.split(",") : []; '
          'r = r.concat(l); }); }); print(JSON.stringify(r));')
    answer = busctl("call", "org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript", "s", js)
    try:
        rows = json.loads((answer or {}).get("data", ["[]"])[0])
    except (ValueError, IndexError, TypeError):
        return []
    return [r.split(":", 1)[1] for r in rows if isinstance(r, str) and r.startswith("applications:")]


def current_dock_answers():
    """Plasma answers and there is a dock (or the layout "Dashboard"): an empty list is then really empty."""
    try:
        if json.loads(LAYOUT.read_text()).get("layout") == "dashboard":
            return True
    except (OSError, ValueError, AttributeError):
        pass
    answer = busctl("call", "org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell", "evaluateScript", "s",
                    'var n = 0; ' + DOCK_JS % 'n++;' + ' print(n);')
    try:
        return (answer or {}).get("data", ["0"])[0] not in ("", "0")
    except (IndexError, TypeError, AttributeError):
        return False


def bottom_apps(all_apps=None):
    """The programs along the bottom: the dock's (shared with it), else a standard row."""
    by_id = {a["id"]: a for a in (all_apps if all_apps is not None else apps())}
    for ids in (dock_apps(), STANDARD_APPS):
        rows = [by_id[i] for i in ids if i in by_id]
        if rows:
            return rows[:14]
    return []


# ── The system ────────────────────────────────────────────────

def _read(path):
    try:
        return Path(path).read_text().strip()
    except OSError:
        return ""


def _cpu_times():
    parts = _read("/proc/stat").split("\n", 1)[0].split()[1:]
    nums = [int(p) for p in parts] if parts else [0] * 5
    return sum(nums), nums[3] + (nums[4] if len(nums) > 4 else 0)


def memory():
    """(used GB, total GB, swap used GB)."""
    info = dict(re.findall(r"^(\w+):\s+(\d+)", _read("/proc/meminfo"), re.M))
    kb = lambda k: int(info.get(k, 0))  # noqa: E731
    gb = 1024 * 1024
    return ((kb("MemTotal") - kb("MemAvailable")) / gb, kb("MemTotal") / gb, (kb("SwapTotal") - kb("SwapFree")) / gb)


def temperatures():
    """{"cpu": °C, "gpu": °C} from hwmon (k10temp/coretemp/zenpower, amdgpu/nouveau) – missing ones left out."""
    found = {}
    for hw in sorted(Path("/sys/class/hwmon").glob("hwmon*")):
        name = _read(hw / "name")
        kind = ("cpu" if name in ("k10temp", "coretemp", "zenpower", "cpu_thermal") else
                "gpu" if name in ("amdgpu", "nouveau", "xe", "i915") else "")
        value = _read(hw / "temp1_input")
        if kind and value.isdigit() and kind not in found:
            found[kind] = int(value) / 1000
    return found


def gpu():
    """{"percent", "temp", "name"} – AMD/Intel from sysfs, Nvidia from nvidia-smi; {} when unknown."""
    for busy in sorted(Path("/sys/class/drm").glob("card*/device/gpu_busy_percent")):
        value = _read(busy)
        if value.isdigit():
            return {"percent": int(value), "name": ""}
    if shutil.which("nvidia-smi"):
        out = run(["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,name", "--format=csv,noheader,nounits"])
        parts = [p.strip() for p in out.split("\n", 1)[0].split(",")]
        if len(parts) >= 3 and parts[0].isdigit():
            return {"percent": int(parts[0]), "temp": float(parts[1]) if parts[1].isdigit() else None, "name": parts[2]}
    return {}


def disks():
    """[{name, path, free GB, total GB, percent used}] – the home disk first, then the mounted extra disks."""
    rows, seen = [], set()
    places = [("Hemmappen", str(HOME))]
    for line in _read("/proc/mounts").splitlines():
        parts = line.split()
        if len(parts) > 2 and re.match(r"/(run/media|mnt|var/mnt|media)/", parts[1]) and parts[2] not in (
                "tmpfs", "overlay", "squashfs", "fuse.portal"):
            places.append((Path(parts[1].replace("\\040", " ")).name, parts[1].replace("\\040", " ")))
    for name, path in places:
        try:
            use = shutil.disk_usage(path)
            dev = os.stat(path).st_dev
        except OSError:
            continue
        if dev in seen or not use.total:
            continue
        seen.add(dev)
        rows.append({"name": name, "path": path, "free": use.free / 1e9, "total": use.total / 1e9,
                     "percent": round((use.total - use.free) * 100 / use.total)})
    return rows


def top_processes(count=5):
    """[{name, cpu %}] – what takes the processor now (one core = 100 %)."""
    rows = []
    for line in run(["ps", "-eo", "pcpu,comm", "--sort=-pcpu", "--no-headers"]).splitlines()[:count + 3]:
        parts = line.split(None, 1)
        if len(parts) == 2 and parts[1] != "ps":
            try:
                rows.append({"name": parts[1], "cpu": float(parts[0])})
            except ValueError:
                pass
    return rows[:count]


def gb(value):
    return (f"{value / 1000:.1f} TB" if value >= 1000 else f"{value:.0f} GB").replace(".", ",")


class System:
    """sample() = the rows of the SYSTEM frame + the history (the newest last, `keep` samples)."""

    def __init__(self, keep=40):
        self.keep = keep
        self.last = _cpu_times()
        self.history = {k: [] for k in ("cpu", "gpu", "temp", "ram", "disk")}

    def _push(self, key, value):
        row = self.history[key]
        row.append(round(value))
        del row[:-self.keep]

    def sample(self):
        total, idle = _cpu_times()
        d_total, d_idle = total - self.last[0], idle - self.last[1]
        self.last = (total, idle)
        cpu = max(0.0, min(100.0, (d_total - d_idle) * 100 / d_total)) if d_total > 0 else 0.0
        used, ram_total, swap = memory()
        g, temps, ds = gpu(), temperatures(), disks()
        if g.get("temp") is not None:
            temps.setdefault("gpu", g["temp"])
        hot = max(temps.values()) if temps else None
        home = ds[0] if ds else None
        rows = [{"id": "cpu", "k": "CPU", "v": f"{cpu:.0f} %", "p": cpu, "note": ""}]
        if g:
            rows.append({"id": "gpu", "k": "GPU", "v": f"{g['percent']} %", "p": g["percent"], "note": g.get("name", "")})
        if hot is not None:
            rows.append({"id": "temp", "k": "TEMP", "v": f"{hot:.0f} °C", "p": min(100, hot), "warn": hot >= 85,
                         "note": " · ".join(f"{n.upper()} {v:.0f} °C" for n, v in sorted(temps.items()))})
        if ram_total:
            rows.append({"id": "ram", "k": "RAM", "v": f"{used:.0f}/{ram_total:.0f} GB", "p": used * 100 / ram_total,
                         "note": f"swap {swap:.1f} GB".replace(".", ",") if swap >= 0.1 else "swap används inte"})
        if home:
            rows.append({"id": "disk", "k": "DISK", "v": gb(home["free"]), "p": home["percent"], "warn": home["percent"] >= 90,
                         "note": " · ".join(f"{d['name']}: {gb(d['free'])} kvar" for d in ds[1:]) or "ledigt i hemmappen"})
        for r in rows:
            r["p"] = round(r["p"])
            r.setdefault("warn", r["p"] >= 90)
            self._push(r["id"], r["p"])
            r["bars"] = list(self.history[r["id"]])
        return {"rows": rows, "disks": ds}


# ── What is playing ───────────────────────────────────────────

def _prop(name, prop):
    return (busctl("get-property", name, "/org/mpris/MediaPlayer2", PLAYER, prop, timeout=2) or {}).get("data")


def player():
    """{name, app, status, title, artist, album, art, length s, position s} of the player to show, or {}."""
    names = [n.get("name", "") for n in busctl("list") or [] if n.get("name", "").startswith(MPRIS)]
    found = []
    for name in names:
        app = name[len(MPRIS):].split(".")[0]
        if app.startswith("kdeconnect") or app == "plasma-browser-integration":
            continue
        found.append((name, app, _prop(name, "PlaybackStatus") or "Stopped"))
    if not found:
        return {}
    music = lambda app: any(a in app.lower() for a in MUSIC_APPS)  # noqa: E731
    name, app, status = sorted(found, key=lambda p: (p[2] != "Playing", not music(p[1]), p[2] != "Paused"))[0]
    meta = _prop(name, "Metadata") or {}
    get = lambda key: (meta.get(key) or {}).get("data")  # noqa: E731
    artists = get("xesam:artist") or []
    position = _prop(name, "Position")
    return {"name": name, "app": app, "status": status, "title": get("xesam:title") or "",
            "artist": ", ".join(artists) if isinstance(artists, list) else str(artists),
            "album": get("xesam:album") or "", "art": get("mpris:artUrl") or "",
            "length": (get("mpris:length") or 0) / 1e6,
            "position": (position or 0) / 1e6 if isinstance(position, (int, float)) else 0}


def control(name, what):
    """what = Previous | PlayPause | Next."""
    if name.startswith(MPRIS) and what in ("Previous", "PlayPause", "Next"):
        run(["busctl", "--user", "call", name, "/org/mpris/MediaPlayer2", PLAYER, what])


# ── The quota ─────────────────────────────────────────────────

def quota(refresh_after=600):
    """The quota widget's file as it is; older than `refresh_after` s (the widget is not running – the dashboard
    layout has no top bar) → the helper is started in the background, the next reading has the new values."""
    try:
        data = json.loads(QUOTA.read_text())
    except (OSError, ValueError):
        data = {}
    if time.time() - float(data.get("updated") or 0) > refresh_after and QUOTA_HELPER.exists():
        try:
            subprocess.Popen([str(QUOTA_HELPER)], start_new_session=True,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except OSError:
            pass
    return data


# ── The projects ──────────────────────────────────────────────

def folders():
    try:
        return [str(p) for p in json.loads(FOLDERS.read_text()) if isinstance(p, str)]
    except (OSError, ValueError, TypeError):
        return []


def save_folders(rows):
    FOLDERS.parent.mkdir(parents=True, exist_ok=True)
    FOLDERS.write_text(json.dumps(rows, ensure_ascii=False, indent=1))


def short_path(path):
    home = str(HOME)
    return "~" + path[len(home):] if path == home or path.startswith(home + "/") else path


def _git(path, *args):
    return run(["git", "-C", path, *args], timeout=4).strip()


def ago(stamp):
    """A Unix time as "för 3 timmar sedan"."""
    try:
        seconds = max(0, time.time() - float(stamp))
    except ValueError:
        return ""
    for size, one, many in ((86400 * 365, "år", "år"), (86400 * 30, "månad", "månader"), (86400 * 7, "vecka", "veckor"),
                            (86400, "dag", "dagar"), (3600, "timme", "timmar"), (60, "minut", "minuter")):
        if seconds >= size:
            n = int(seconds // size)
            return f"för {n} {one if n == 1 else many} sedan"
    return "nyss"


def projects():
    """[{path, name, short, exists, branch, changed}] – the folders, with the branch when it is a Git folder."""
    rows = []
    for p in folders():
        exists = Path(p).is_dir()
        branch = _git(p, "rev-parse", "--abbrev-ref", "HEAD") if exists and (Path(p) / ".git").exists() else ""
        changed = len(_git(p, "status", "--porcelain").splitlines()) if branch else 0
        rows.append({"path": p, "name": Path(p).name or p, "short": short_path(p), "exists": exists,
                     "branch": branch, "changed": changed})
    return rows


def project(path, count=8):
    """One project for the middle: {path, name, short, remote, branch, changed, waiting, commits: [{hash, msg, when}]}."""
    info = {"path": path, "name": Path(path).name or path, "short": short_path(path), "remote": "", "branch": "",
            "changed": 0, "waiting": 0, "commits": [], "git": False}
    if not (Path(path) / ".git").exists():
        return info
    info["git"] = True
    info["branch"] = _git(path, "rev-parse", "--abbrev-ref", "HEAD")
    remote = _git(path, "remote", "get-url", "origin")
    info["remote"] = re.sub(r"^(https?://|git@)|\.git$", "", remote).replace(":", "/", 1) if remote else ""
    info["changed"] = len(_git(path, "status", "--porcelain").splitlines())
    waiting = _git(path, "rev-list", "--count", "@{u}..HEAD")
    info["waiting"] = int(waiting) if waiting.isdigit() else 0
    for line in _git(path, "log", f"-{count}", "--format=%h\x1f%s\x1f%ct").splitlines():
        parts = line.split("\x1f")
        if len(parts) == 3:
            info["commits"].append({"hash": parts[0], "msg": parts[1], "when": ago(parts[2])})
    return info


def open_project(path, how):
    """how = code (VS Code) | claude | codex (in the chosen terminal) | folder (the file manager). "" or why not."""
    if not Path(path).is_dir():
        return "Mappen finns inte längre"
    if how == "code":
        code = next((c for c in (str(HOME / ".local/share/vscode/bin/code"), shutil.which("code") or "")
                     if c and Path(c).is_file()), None)
        if not code:
            return "VS Code finns inte – installera det i GOBLINCAKES Config → Program"
        cmd = [code, path]
    elif how == "folder":
        cmd = ["xdg-open", path]
    else:
        tool = shutil.which(how) or str(HOME / ".local/bin" / how)
        if not Path(tool).is_file():
            name = "Codex" if how == "codex" else "Claude Code"
            return f"{name} finns inte – installera det i GOBLINCAKES Config → Program"
        quote = lambda s: "'" + s.replace("'", "'\\''") + "'"  # noqa: E731
        cmd = ["/usr/libexec/goblincakes-terminal", "run", "bash", "-c", f"cd {quote(path)} && {quote(tool)}; exec bash"]
    try:
        subprocess.Popen(cmd, cwd=path, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError as e:
        return f"Kunde inte starta: {e}"
    return ""


def browse(path=""):
    """The dashboard's own folder chooser (+ in PROJEKT; 11 Nov – the system's folder dialog over the full-screen
    dashboard added nothing): {path, short, parent, dirs: [{name, path, git}], added, suggest: [{name, path, short}]}.
    Hidden folders are left out; suggest (in the home folder) = Git folders two levels down not yet in the list."""
    target = Path(path).expanduser() if path else HOME
    if not target.is_dir():
        target = HOME
    target = target.resolve()
    rows = folders()
    dirs = []
    try:
        for child in sorted(target.iterdir(), key=lambda c: c.name.lower()):
            if child.name.startswith(".") or not child.is_dir():
                continue
            dirs.append({"name": child.name, "path": str(child), "git": (child / ".git").exists()})
    except OSError:
        pass
    suggest = []
    if target == HOME.resolve():
        seen = set(rows)
        for depth in ("*/.git", "*/*/.git"):
            for git in sorted(HOME.glob(depth)):
                folder = str(git.parent)
                if folder not in seen and not any(part.startswith(".") for part in git.parent.relative_to(HOME).parts):
                    seen.add(folder)
                    suggest.append({"name": git.parent.name, "path": folder, "short": short_path(folder)})
                if len(suggest) >= 8:
                    break
    return {"path": str(target), "short": short_path(str(target)),
            "parent": str(target.parent) if target != target.parent else "",
            "dirs": dirs[:300], "added": str(target) in rows, "suggest": suggest}


def add_folder(path):
    """Into PROJEKT (the same list as Goblin AI's PROJEKT → MAPPAR). "" or why not."""
    path = str(Path(path).expanduser()).rstrip("/") or "/"
    if not path.startswith("/") or not Path(path).is_dir():
        return "Mappen finns inte"
    rows = folders()
    if path not in rows:
        save_folders(rows + [path])
    return ""


def power():
    """The power button: Plasma's logout screen (GOBLINCAKES' own – Logga ut, Starta om, Stäng av, Avbryt).
    "" or why not."""
    for cmd in (["qdbus6", "org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt.promptAll"],
                ["gdbus", "call", "--session", "--dest", "org.kde.LogoutPrompt", "--object-path", "/LogoutPrompt",
                 "--method", "org.kde.LogoutPrompt.promptAll"]):
        try:
            if subprocess.run(cmd, capture_output=True, timeout=5).returncode == 0:
                return ""
        except (OSError, subprocess.SubprocessError):
            continue
    return "Avstängningsrutan gick inte att öppna"


def project_tools():
    """Which of the ways to open a project exist here."""
    has = lambda n: bool(shutil.which(n)) or (HOME / ".local/bin" / n).is_file()  # noqa: E731
    return {"code": (HOME / ".local/share/vscode/bin/code").is_file() or bool(shutil.which("code")),
            "claude": has("claude"), "codex": has("codex")}


# ── The system tray's icons ───────────────────────────────────

TRAY = [("nätverk", "Nätverk"), ("ljud", "Ljud"), ("bluetooth", "Bluetooth"), ("notiser", "Notiser"),
        ("urklipp", "Urklipp"), ("enheter", "Enheter")]
NM_STATES = {"connected": "ansluten", "disconnected": "inte ansluten", "unavailable": "av", "unmanaged": "sköts inte",
             "connecting": "ansluter …"}
NM_TYPES = {"ethernet": "Ethernet", "wifi": "Wi-Fi", "bluetooth": "Bluetooth", "wireguard": "VPN", "tun": "VPN"}


def volume():
    """{"percent", "muted", "name"} of the default output (wpctl), {} without PipeWire."""
    out = run(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"])
    m = re.search(r"Volume:\s*([\d.]+)", out)
    if not m:
        return {}
    name = re.search(r'node\.description = "([^"]+)"', run(["wpctl", "inspect", "@DEFAULT_AUDIO_SINK@"]))
    return {"percent": round(float(m.group(1)) * 100), "muted": "MUTED" in out, "name": name.group(1) if name else ""}


def set_volume(percent=None, mute=None):
    if percent is not None:
        run(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", f"{max(0, min(100, int(percent))) / 100:.2f}"])
    if mute is not None:
        run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle" if mute == "toggle" else ("1" if mute else "0")])


def clipboard():
    """The clipboard history (Klipper), newest first – long texts on one line."""
    answer = busctl("call", "org.kde.klipper", "/klipper", "org.kde.klipper.klipper", "getClipboardHistoryMenu")
    rows = (answer or {}).get("data", [[]])[0] if answer else []
    return [r for r in rows if isinstance(r, str) and r.strip()][:12]


def set_clipboard(text):
    run(["busctl", "--user", "call", "org.kde.klipper", "/klipper", "org.kde.klipper.klipper",
         "setClipboardContents", "s", text])


def _notice_rows():
    """The notifications still in Plasma's list (not dismissed or closed by the program), after Rensa."""
    try:
        rows = json.loads(NOTICES.read_text()).get("rows", [])
    except (OSError, ValueError, AttributeError):
        return []
    cleared = float(settings().get("noticesCleared") or 0)
    return [r for r in rows if isinstance(r, dict) and r.get("closed", 0) in (0, 1) and float(r.get("time") or 0) > cleared]


def recorder():
    """GOBLINRECORDER above SPELAS NU (11 Nov, the user's wish): GoblinRecorder's own checks – OBS, WoW, the
    combat log and whether something is being recorded – read from the service's status file, the same as the
    recorder window's chips. The service not running → OBS from pgrep/the Flatpak folders, the rest unknown."""
    try:
        st = json.loads(RECORDER_STATUS.read_text())
    except (OSError, ValueError):
        st = {}
    alive = bool(st) and time.time() - float(st.get("time") or 0) < 10
    if alive:
        obs = st.get("obs") or ""
    elif not any((d / OBS_APP).is_dir() for d in (Path("/var/lib/flatpak/app"), HOME / ".local/share/flatpak/app")):
        obs = "missing"
    else:
        obs = "running" if run(["pgrep", "-x", "obs"]).strip() else "stopped"
    current = (st.get("current") or {}) if alive else {}
    what = current.get("name") or ""
    if what and current.get("difficulty"):
        what += f" ({current['difficulty']})"
    return {"service": alive, "obs": obs, "wow": bool(st.get("wow")) if alive else None,
            "logging": bool(st.get("logging")) if alive else None,
            "logDelay": st.get("logDelay") if alive else None,
            "recording": bool(st.get("recording")) if alive else False, "what": what,
            "cs2": bool(st.get("cs2")) if alive else False, "cs2Map": st.get("cs2Map") or "" if alive else ""}


def notices():
    """{"unread", "running"} – unread = newer than the last time NOTISER was opened (11 Nov). running false = the
    listener has never written anything (the service isn't running), so the box says so."""
    seen = float(settings().get("noticesSeen") or 0)
    return {"unread": sum(1 for r in _notice_rows() if float(r.get("time") or 0) > seen), "running": NOTICES.exists()}


def mark_notices(clear=False):
    """NOTISER opened: all are read. Rensa: the box is emptied (the listener's file is left alone – it's its)."""
    saved = settings()
    saved["noticesSeen"] = time.time()
    if clear:
        saved["noticesCleared"] = time.time()
    save_settings(saved)


def clock(stamp):
    """A notification's time: 14:32 today, igår 14:32, 9 nov."""
    t = time.localtime(float(stamp or 0))
    now = time.localtime()
    if t[:3] == now[:3]:
        return time.strftime("%H:%M", t)
    if time.strftime("%Y%m%d", t) == time.strftime("%Y%m%d", time.localtime(time.time() - 86400)):
        return time.strftime("igår %H:%M", t)
    months = ("jan", "feb", "mar", "apr", "maj", "jun", "jul", "aug", "sep", "okt", "nov", "dec")
    return f"{t.tm_mday} {months[t.tm_mon - 1]}"


def batteries():
    """The wireless mouse's, keyboard's, controller's and headset's battery (goblincakes-device-battery, like the
    desktop row and the top bar): [{kind, name, percent, charging}] – [] without any (11 Nov, the user: the mouse's
    battery visible in the dashboard too)."""
    try:
        rows = json.loads(run([str(BATTERY_HELPER)], timeout=5) or "[]")
    except ValueError:
        return []
    return [d for d in rows if isinstance(d, dict) and isinstance(d.get("percent"), (int, float))]


SHOWN = Path(os.environ.get("XDG_STATE_HOME") or HOME / ".local/state") / "goblincakes/dashboard-shown"


def count_shown():
    """The dashboard was shown once more – the desktop's Meta hint (org.goblincakes.metahint) stops after 3."""
    try:
        n = int(SHOWN.read_text().strip() or 0)
    except (OSError, ValueError):
        n = 0
    if n >= 99:
        return
    try:
        SHOWN.parent.mkdir(parents=True, exist_ok=True)
        SHOWN.write_text(f"{n + 1}\n")
    except OSError:
        pass


def tray(name):
    """{"title", "rows": [{a, b, act?}], "volume"?} – the small box under the icons."""
    rows = []
    if name == "nätverk":
        for line in run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"]).splitlines():
            dev, kind, state, conn = (line.split(":") + ["", "", ""])[:4]
            if kind in ("loopback", "bridge", "wifi-p2p") or state == "unmanaged":
                continue
            rows.append({"a": NM_TYPES.get(kind, kind) + (f" · {conn}" if conn else f" · {dev}"),
                         "b": NM_STATES.get(state.split(" ")[0], state)})
        rows = rows or [{"a": "Inget nätverk hittades", "b": ""}]
    elif name == "ljud":
        v = volume()
        if not v:
            return {"title": "LJUD", "rows": [{"a": "Ljudet gick inte att läsa", "b": ""}]}
        return {"title": "LJUD", "volume": v, "rows": [{"a": v["name"] or "Utgång", "b": "tyst" if v["muted"] else f"{v['percent']} %"}]}
    elif name == "bluetooth":
        powered = "Powered: yes" in run(["bluetoothctl", "show"])
        for line in run(["bluetoothctl", "devices", "Connected"]).splitlines():
            parts = line.split(" ", 2)
            if len(parts) == 3 and parts[0] == "Device":
                rows.append({"a": parts[2], "b": "ansluten"})
        rows = rows or [{"a": "Bluetooth", "b": "på – inget anslutet" if powered else "av"}]
    elif name == "notiser":
        for r in _notice_rows()[:12]:
            app = r.get("app") or r.get("entry") or ""
            app = app[:1].upper() + app[1:]
            body = r.get("body") or ""
            rows.append({"a": r.get("summary") or body or app, "b": clock(r.get("time")),
                         "c": " · ".join(x for x in (app, body if r.get("summary") else "") if x),
                         "act": "open" if r.get("entry") else "", "text": r.get("entry") or ""})
        if not rows:
            rows = [{"a": "Inga notiser", "b": ""}] if NOTICES.exists() else [
                {"a": "Notiserna läses inte", "b": "", "c": "Tjänsten goblincakes-notifications kör inte"}]
        return {"title": "NOTISER", "notices": True, "rows": rows}
    elif name == "urklipp":
        rows = [{"a": " ".join(t.split())[:60], "b": "", "act": "copy", "text": t} for t in clipboard()]
        rows = rows or [{"a": "Urklippet är tomt", "b": ""}]
    elif name == "enheter":
        try:
            for d in json.loads(run([str(BATTERY_HELPER)], timeout=5) or "[]"):
                rows.append({"a": d.get("name") or d.get("kind", ""), "b": f"{d.get('percent', '?')} %" + (" · laddar" if d.get("charging") else "")})
        except ValueError:
            pass
        try:
            for dev in json.loads(run(["lsblk", "-J", "-o", "NAME,LABEL,SIZE,HOTPLUG,MOUNTPOINT,TYPE"]) or "{}").get("blockdevices", []):
                for part in dev.get("children") or []:
                    if dev.get("hotplug") in (True, "1") and part.get("type") == "part":
                        rows.append({"a": part.get("label") or part.get("name", ""), "b": f"{part.get('size', '')} · "
                                     + ("monterad" if part.get("mountpoint") else "inte monterad")})
        except ValueError:
            pass
        rows = rows or [{"a": "Inga trådlösa enheter eller USB-diskar", "b": ""}]
    return {"title": dict(TRAY).get(name, name).upper(), "rows": rows}


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "system"
    if what == "apps":
        result = [f"{a['name']} ({a['group']}) – {a['id']}" for a in apps()]
    elif what == "system":
        s = System()
        time.sleep(0.5)
        result = s.sample()
    elif what == "top":
        result = top_processes()
    elif what == "player":
        result = player()
    elif what == "quota":
        result = quota(refresh_after=1e12)
    elif what == "projects":
        result = projects()
    elif what == "project":
        result = project(sys.argv[2] if len(sys.argv) > 2 else os.getcwd())
    elif what == "browse":
        result = browse(sys.argv[2] if len(sys.argv) > 2 else "")
    elif what == "batteries":
        result = batteries()
    elif what == "notices":
        result = notices()
    elif what == "recorder":
        result = recorder()
    elif what == "tray":
        result = tray(sys.argv[2] if len(sys.argv) > 2 else "nätverk")
    elif what == "bottom":
        result = [a["id"] for a in bottom_apps()]
    elif what == "views":
        result = {"view": view_index(), "views": views()}
    elif what == "config":       # GOBLINCAKES Config → Dashboard: everything the page shows
        saved = settings()
        rows = apps()
        result = {"views": views(saved), "view": view_index(saved), "maxViews": MAX_VIEWS, "sides": SIDES,
                  "frames": [{"id": i, "name": n, "note": t} for i, n, t in FRAMES],
                  "apps": [{k: a[k] for k in ("id", "name", "icon", "group")} for a in rows],
                  # the programs at the bottom = the dock's pinned apps (shared); dockOk false = Plasma didn't answer
                  "chosen": dock_apps(), "dock": []}
        result["dockOk"] = bool(result["chosen"]) or current_dock_answers()
    elif what == "save":         # from Config: {"views": [...], "apps": [...] only when changed} on stdin
        data = json.loads(sys.stdin.read() or "{}")
        ok = save_views(data.get("views") or [], data.get("apps"))
        result = {"views": views(), "view": view_index(), "appsSaved": ok}
    else:
        sys.exit(__doc__)
    print(json.dumps(result, ensure_ascii=False, indent=1))
