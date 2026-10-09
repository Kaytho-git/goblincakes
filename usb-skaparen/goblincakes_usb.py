#!/usr/bin/env python3
"""GOBLINCAKES USB – makes a GOBLINCAKES install USB stick, on Windows and Linux.

The window (PySide6 + Main.qml next to this file) lets you pick the ISO kind and the USB
stick; the work is done by this same file in "write" mode, with administrator rights
(pkexec on Linux; on Windows the whole program asks for them when it starts):

  goblincakes_usb.py                       the window
  goblincakes_usb.py drives                JSON: USB sticks (never the computer's own disks)
  goblincakes_usb.py gpu                   JSON: graphics cards + suggestion
  goblincakes_usb.py write <device> <variant-id> [manifest-url]
                                           download the parts straight onto the stick,
                                           check each part, then read the whole stick
                                           back and check it; progress as JSON lines

The ISO comes from the GitHub release "iso" (public, no login): goblincakes-iso.json
lists the ISO kinds and their parts (under 2 GB each, GitHub's limit). Nothing is
stored on the computer on the way – the parts go straight to the stick.
Built for Windows/Linux as one file by .github/workflows/build-usb-creator.yml.
"""
import hashlib
import json
import os
import queue
import re
import shutil
import subprocess
import sys
import threading
import time
import urllib.request
from pathlib import Path

REPO = "Kaytho-git/goblincakes"
MANIFEST_URL = os.environ.get(
    "GOBLINCAKES_USB_MANIFEST", f"https://github.com/{REPO}/releases/download/iso/goblincakes-iso.json")
WINDOWS = sys.platform == "win32"
CHUNK = 4 * 1024 * 1024  # a multiple of every sector size
NO_WINDOW = 0x08000000 if WINDOWS else 0  # CREATE_NO_WINDOW: no black console flashing up
FAKE = os.environ.get("GOBLINCAKES_USB_FAKE")  # tests: JSON file with drives/gpu instead of the real ones


def run(cmd, timeout=60):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, creationflags=NO_WINDOW)


def powershell(script):
    out = run(["powershell", "-NoProfile", "-NonInteractive", "-Command", script]).stdout.strip()
    if not out:
        return []
    data = json.loads(out)
    return data if isinstance(data, list) else [data]


def human_size(n):
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1000 or unit == "TB":
            return f"{n:.1f} {unit}".replace(".0 ", " ").replace(".", ",")
        n /= 1000


# ── USB sticks ────────────────────────────────────────────────

def list_drives():
    """USB sticks only: never the disk the running system is on."""
    if FAKE:
        return json.loads(Path(FAKE).read_text()).get("drives", [])
    drives = []
    if WINDOWS:
        disks = powershell("Get-Disk | Where-Object { $_.BusType -eq 'USB' -and -not $_.IsBoot -and -not $_.IsSystem }"
                           " | Select-Object Number,FriendlyName,Size | ConvertTo-Json")
        for d in disks:
            drives.append({"device": str(d["Number"]), "name": (d.get("FriendlyName") or "USB-minne").strip(),
                           "size": int(d.get("Size") or 0)})
        return drives
    root_disk = ""
    try:
        source = run(["findmnt", "-no", "SOURCE", "/"]).stdout.strip().split("[")[0]
        root_disk = run(["lsblk", "-no", "PKNAME", source]).stdout.strip().splitlines()[0]
    except (IndexError, OSError):
        pass
    out = run(["lsblk", "-J", "-b", "-d", "-o", "NAME,PATH,SIZE,MODEL,VENDOR,TRAN,RM,HOTPLUG,TYPE,RO"]).stdout
    for d in json.loads(out or '{"blockdevices": []}')["blockdevices"]:
        if d.get("type") != "disk" or d.get("ro") in (True, "1") or d.get("name") == root_disk:
            continue
        if d.get("tran") != "usb" and d.get("hotplug") not in (True, "1"):
            continue
        name = " ".join(x for x in ((d.get("vendor") or "").strip(), (d.get("model") or "").strip()) if x)
        drives.append({"device": d["path"], "name": name or "USB-minne", "size": int(d.get("size") or 0)})
    return drives


# ── Graphics card (only a suggestion: the stick may be for another computer) ──

def detect_gpu():
    if FAKE:
        return json.loads(Path(FAKE).read_text()).get("gpu", {"cards": [], "nvidiaSupported": False})
    cards = []
    if WINDOWS:
        for c in powershell("Get-CimInstance Win32_VideoController | Select-Object Name,PNPDeviceID | ConvertTo-Json"):
            m = re.search(r"VEN_([0-9A-F]{4})&DEV_([0-9A-F]{4})", c.get("PNPDeviceID") or "", re.I)
            if m:
                cards.append({"name": c.get("Name") or "Grafikkort", "vendor": m.group(1).lower(),
                              "device": int(m.group(2), 16)})
    else:
        for dev in sorted(Path("/sys/bus/pci/devices").glob("*")):
            try:
                if not (dev / "class").read_text().startswith("0x03"):
                    continue
                vendor = (dev / "vendor").read_text().strip().removeprefix("0x")
                device = int((dev / "device").read_text().strip(), 16)
            except (OSError, ValueError):
                continue
            name = {"10de": "Nvidia", "1002": "AMD", "8086": "Intel"}.get(vendor, "Grafikkort")
            try:
                fields = re.findall(r'"([^"]*)"', run(["lspci", "-mm", "-s", dev.name], 5).stdout)
                if len(fields) >= 3:
                    name = f"{fields[1]} {fields[2]}"
            except (OSError, subprocess.TimeoutExpired):
                pass
            cards.append({"name": name, "vendor": vendor, "device": device})
    # Universal Blue's Nvidia images use Nvidia's open driver: Turing (GTX 16xx/RTX 20xx) and newer
    supported = any(c["vendor"] == "10de" and c["device"] >= 0x1E00 for c in cards)
    return {"cards": [c["name"] for c in cards], "hasNvidia": any(c["vendor"] == "10de" for c in cards),
            "nvidiaSupported": supported}


# ── Writing (runs with administrator rights) ──────────────────

_sink = None  # the window on Windows writes in a thread and gets the events directly


def emit(**event):
    line = json.dumps(event)
    if _sink:
        _sink(line)
    else:
        print(line, flush=True)


def prepare_device(device):
    """Nothing may use the stick while it's written: unmount (Linux) / wipe and take offline (Windows)."""
    if WINDOWS:
        n = int(device)
        script = (f"$d = Get-Disk -Number {n}; if ($d.BusType -ne 'USB' -or $d.IsBoot -or $d.IsSystem) {{ exit 3 }}; "
                  f"Set-Disk -Number {n} -IsReadOnly $false; Set-Disk -Number {n} -IsOffline $false; "
                  f"Clear-Disk -Number {n} -RemoveData -RemoveOEM -Confirm:$false; "
                  f"Set-Disk -Number {n} -IsOffline $true")
        result = run(["powershell", "-NoProfile", "-NonInteractive", "-Command", script], 300)
        if result.returncode == 3:
            raise RuntimeError("Det där är inte ett USB-minne – avbryter")
        return rf"\\.\PhysicalDrive{n}"
    if not Path(device).is_block_device():
        return device  # tests write to a file
    if device not in [d["device"] for d in list_drives()]:
        raise RuntimeError("Det där är inte ett USB-minne – avbryter")
    out = run(["lsblk", "-J", "-o", "PATH,MOUNTPOINTS", device]).stdout
    def walk(nodes):
        for node in nodes:
            yield node
            yield from walk(node.get("children", []))
    for node in walk(json.loads(out)["blockdevices"]):
        if any(node.get("mountpoints") or []):
            run(["umount", node["path"]])
    return device


def finish_device(device):
    if WINDOWS:
        run(["powershell", "-NoProfile", "-NonInteractive", "-Command",
             f"Set-Disk -Number {int(device)} -IsOffline $false; Update-Disk -Number {int(device)}"], 120)
    elif Path(device).is_block_device():
        run(["blockdev", "--rereadpt", device])


BUFFER_CHUNKS = 64  # 64 × 4 MB = 256 MB between the download and the stick


def download_parts(base, parts, out):
    """Downloader thread: every part in order into the queue `out`, while the main
    thread writes to the stick – so the network never waits for a slow USB stick.
    Messages: ("start", index, offset), ("data", bytes), ("retry", text),
    ("error", text), ("done",). A part that fails or whose sha256 is wrong is
    downloaded again from its start (the writer goes back to its offset)."""
    try:
        offset = 0
        for index, part in enumerate(parts):
            for attempt in range(1, 6):
                try:
                    out.put(("start", index, offset))
                    digest, got = hashlib.sha256(), 0
                    request = urllib.request.Request(f"{base}/{part['name']}", headers={"User-Agent": "GOBLINCAKES-USB"})
                    with urllib.request.urlopen(request, timeout=60) as response:
                        while True:
                            data = response.read(CHUNK)
                            if not data:
                                break
                            digest.update(data)
                            got += len(data)
                            out.put(("data", data))
                    if got != part["size"]:
                        raise IOError(f"{part['name']}: fick {got} av {part['size']} byte")
                    if digest.hexdigest() != part["sha256"]:
                        raise IOError(f"{part['name']}: kontrollsumman stämmer inte")
                    break
                except (OSError, IOError) as e:
                    if attempt == 5:
                        out.put(("error", f"{e}. Kolla internetanslutningen och försök igen."))
                        return
                    out.put(("retry", f"{e} – försöker igen ({attempt + 1}/5)"))
                    time.sleep(5 * attempt)
            offset += part["size"]
        out.put(("done",))
    except Exception as e:  # noqa: BLE001 – passed on to the window as text
        out.put(("error", str(e)))


def write(device, variant_id, manifest_url=MANIFEST_URL):
    try:
        with urllib.request.urlopen(urllib.request.Request(manifest_url, headers={"User-Agent": "GOBLINCAKES-USB"}),
                                    timeout=60) as response:
            manifest = json.load(response)
        variant = next((v for v in manifest["variants"] if v["id"] == variant_id), None)
        if not variant:
            raise RuntimeError("Den ISO:n finns inte längre på GitHub – stäng och öppna programmet igen")
        base = manifest_url.rsplit("/", 1)[0]
        total = variant["size"]

        emit(stage="prepare")
        path = prepare_device(device)
        flags = os.O_RDWR | getattr(os, "O_BINARY", 0)
        fd = os.open(path, flags)
        try:
            started = time.monotonic()
            # Download and write at the same time: a thread fetches into a 256 MB buffer
            # while this one writes to the stick (slow sticks no longer stall the network)
            chunks = queue.Queue(maxsize=BUFFER_CHUNKS)
            threading.Thread(target=download_parts, args=(base, variant["parts"], chunks), daemon=True).start()
            current, part_offset, part_written, pending = None, 0, 0, b""
            last_report = 0.0
            while True:
                message = chunks.get()
                kind = message[0]
                if kind == "start":
                    index, offset = message[1], message[2]
                    if index != current and pending:
                        os.write(fd, pending)  # end of the previous part (parts are whole sectors)
                    current, part_offset, part_written, pending = index, offset, 0, b""
                    os.lseek(fd, offset, os.SEEK_SET)  # also back to the start on a retry
                elif kind == "data":
                    pending += message[1]
                    while len(pending) >= CHUNK:
                        os.write(fd, pending[:CHUNK])
                        pending = pending[CHUNK:]
                        part_written += CHUNK
                    now = time.monotonic()
                    if now - last_report > 0.25:
                        last_report = now
                        emit(stage="download", done=part_offset + part_written, total=total, seconds=now - started)
                elif kind == "retry":
                    emit(stage="retry", message=message[1])
                elif kind == "error":
                    raise IOError(message[1])
                else:  # done
                    if pending:
                        # Raw disks on Windows only take whole sectors: pad the very end with zeros
                        os.write(fd, pending + b"\0" * (-len(pending) % 4096) if WINDOWS else pending)
                    emit(stage="download", done=total, total=total, seconds=time.monotonic() - started)
                    break
            if hasattr(os, "fsync"):
                try:
                    os.fsync(fd)
                except OSError:
                    pass

            # Read the whole stick back: what's on it must be exactly the ISO
            emit(stage="verify", done=0, total=total)
            digest = hashlib.sha256()
            os.lseek(fd, 0, os.SEEK_SET)
            read = 0
            while read < total:
                data = os.read(fd, CHUNK)
                if not data:
                    break
                data = data[:total - read]
                digest.update(data)
                read += len(data)
                emit(stage="verify", done=read, total=total)
            if digest.hexdigest() != variant["sha256"]:
                raise IOError("USB-minnet stämmer inte med ISO:n efter skrivningen – försök igen eller med ett annat USB-minne")
        finally:
            os.close(fd)
            finish_device(device)
        emit(stage="done")
        return 0
    except Exception as e:  # noqa: BLE001 – every error goes to the window as text
        emit(stage="error", message=str(e))
        return 1


# ── The window ────────────────────────────────────────────────

def resource(name):
    base = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
    return base / name


def gui():
    from PySide6.QtCore import QObject, QProcess, QUrl, Property, Signal, Slot
    from PySide6.QtGui import QFontDatabase, QGuiApplication, QIcon
    from PySide6.QtQml import QQmlApplicationEngine

    class Backend(QObject):
        manifestChanged = Signal()
        drivesChanged = Signal()
        progress = Signal(str, float, str)  # stage, 0–1, text
        finished = Signal(bool, str)
        line = Signal(str)  # an event from the writing thread (Windows)
        threadDone = Signal()

        def __init__(self):
            super().__init__()
            self._manifest = "{}"
            self._drives = "[]"
            self._gpu = json.dumps(detect_gpu())
            self._proc = None
            self._buffer = b""
            self.line.connect(self._event)
            self.threadDone.connect(lambda: self._done(0, 0))

        @Property(str, notify=manifestChanged)
        def manifest(self):
            return self._manifest

        @Property(str, notify=drivesChanged)
        def drives(self):
            return self._drives

        @Property(str, constant=True)
        def gpu(self):
            return self._gpu

        @Slot()
        def loadManifest(self):
            try:
                with urllib.request.urlopen(urllib.request.Request(MANIFEST_URL, headers={"User-Agent": "GOBLINCAKES-USB"}),
                                            timeout=30) as response:
                    data = json.load(response)
            except Exception as e:  # noqa: BLE001
                data = {"error": f"Kunde inte hämta listan över ISO:er ({e}). Kolla internetanslutningen."}
            self._manifest = json.dumps(data)
            self.manifestChanged.emit()

        @Slot()
        def refreshDrives(self):
            drives = list_drives()
            for d in drives:
                d["sizeText"] = human_size(d["size"])
            self._drives = json.dumps(drives)
            self.drivesChanged.emit()

        @Slot(str, str)
        def write(self, device, variant_id):
            self._ok = False
            self._error = ""
            if WINDOWS:
                # The program already runs as administrator: write in a thread (a windowed .exe
                # has no console to talk through)
                import threading

                def work():
                    global _sink
                    _sink = self.line.emit
                    try:
                        globals()["write"](device, variant_id, MANIFEST_URL)
                    finally:
                        _sink = None
                        self.threadDone.emit()

                threading.Thread(target=work, daemon=True).start()
                return
            proc = QProcess(self)
            me = [sys.executable] if getattr(sys, "frozen", False) else [sys.executable, str(Path(__file__).resolve())]
            args = me + ["write", device, variant_id, MANIFEST_URL]
            if not WINDOWS and not FAKE and os.geteuid() != 0:
                args = ["pkexec"] + args  # asks for the password; the window itself stays a normal program
            proc.readyReadStandardOutput.connect(self._read)
            proc.finished.connect(self._done)
            self._proc = proc
            proc.start(args[0], args[1:])

        def _read(self):
            if not self._proc:
                return
            self._buffer += bytes(self._proc.readAllStandardOutput())
            *lines, self._buffer = self._buffer.split(b"\n")
            for line in lines:
                self._event(line.decode(errors="replace"))

        def _event(self, line):
            try:
                ev = json.loads(line)
            except ValueError:
                return
            stage = ev.get("stage")
            if stage == "download":
                done, total, secs = ev["done"], ev["total"], max(ev.get("seconds", 0), 0.1)
                speed = done / secs
                left = (total - done) / speed if speed > 0 else 0
                self.progress.emit("download", done / total,
                                   f"Hämtar och skriver: {human_size(done)} av {human_size(total)}"
                                   f" · {human_size(speed)}/s · ca {int(left // 60) + 1} min kvar")
            elif stage == "verify":
                self.progress.emit("verify", ev["done"] / max(ev["total"], 1),
                                   f"Kontrollerar USB-minnet: {human_size(ev['done'])} av {human_size(ev['total'])}")
            elif stage == "prepare":
                self.progress.emit("prepare", 0, "Förbereder USB-minnet…")
            elif stage == "retry":
                self.progress.emit("retry", -1, ev.get("message", ""))
            elif stage == "done":
                self._ok = True
            elif stage == "error":
                self._error = ev.get("message", "")

        def _done(self, code, status):
            self._read()
            if not self._ok and not self._error:
                self._error = "Avbrutet – lösenordet gavs inte, eller så stängdes skrivningen."
            self.finished.emit(self._ok, self._error)

    app = QGuiApplication(sys.argv)
    app.setApplicationName("goblincakes-usb")
    app.setApplicationDisplayName("GOBLINCAKES USB")
    app.setDesktopFileName("goblincakes-usb")
    logo = resource("goblincakes.svg")
    if not logo.exists():
        logo = Path("/usr/share/icons/hicolor/scalable/apps/goblincakes.svg")
    # Window and taskbar: the logo on its dark blue square (same as the .exe's icon)
    app_icon = resource("app-icon.png")
    app.setWindowIcon(QIcon(str(app_icon)) if app_icon.exists()
                      else QIcon(str(logo)) if logo.exists() else QIcon.fromTheme("goblincakes"))
    fonts = resource("fonts")
    if fonts.is_dir():
        for f in fonts.glob("*.ttf"):
            QFontDatabase.addApplicationFont(str(f))

    backend = Backend()
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", backend)
    engine.rootContext().setContextProperty("logoUrl", QUrl.fromLocalFile(str(logo)))
    engine.rootContext().setContextProperty("isWindows", WINDOWS)
    engine.load(QUrl.fromLocalFile(str(resource("Main.qml"))))
    if not engine.rootObjects():
        return 1
    return app.exec()


def main(argv):
    if len(argv) > 1 and argv[1] == "drives":
        print(json.dumps(list_drives(), indent=2))
        return 0
    if len(argv) > 1 and argv[1] == "gpu":
        print(json.dumps(detect_gpu(), indent=2))
        return 0
    if len(argv) > 1 and argv[1] == "write":
        if len(argv) < 4:
            sys.exit(__doc__)
        return write(argv[2], argv[3], argv[4] if len(argv) > 4 else MANIFEST_URL)
    return gui()


if __name__ == "__main__":
    sys.exit(main(sys.argv))
