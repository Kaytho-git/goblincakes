"""GoblinAmp's own music (21 Oct, the user's wish: play local files and build playlists).

No Qt here – the window (goblin-amp) plays; this file knows the music:
  • the tags (title, artist, album, track number, length) read with ffprobe and kept in
    ~/.cache/goblincakes/amp-tags.json (path → mtime/size + tags; read again when the file changed)
  • the music folder (xdg-user-dir MUSIC, e.g. ~/Musik) and every music file in it
  • the playlists: .m3u8 files in <music folder>/Spellistor – Winamp's own format, so other
    players open them and old Winamp lists can be brought in (.m3u, .m3u8, .pls)
  • "Nu spelas" (Winamp's playlist window): ~/.local/share/goblincakes/amp/nu-spelas.m3u8
"""
import hashlib
import json
import os
import random
import re
import shutil
import subprocess
import threading
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import unquote, urlparse

HOME = Path.home()
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or HOME / ".cache") / "goblincakes"
DATA = Path(os.environ.get("XDG_DATA_HOME") or HOME / ".local/share") / "goblincakes/amp"
TAGS = CACHE / "amp-tags.json"
COVERS = CACHE / "amp-covers"
NOW = DATA / "nu-spelas.m3u8"
MUSIC_EXT = {".mp3", ".flac", ".ogg", ".oga", ".opus", ".m4a", ".aac", ".wav", ".wma", ".ape",
             ".wv", ".aif", ".aiff", ".mka", ".mpc", ".alac"}
LIST_EXT = {".m3u", ".m3u8", ".pls"}
COVER_NAMES = ("cover", "folder", "front", "album", "albumart")


def music_dir():
    """The user's music folder: xdg-user-dir MUSIC (Swedish: ~/Musik), else ~/Musik or ~/Music."""
    folder = os.environ.get("GOBLINCAKES_AMP_MUSIC")
    if not folder:
        try:
            folder = subprocess.run(["xdg-user-dir", "MUSIC"], capture_output=True, text=True,
                                    timeout=3).stdout.strip()
        except (OSError, subprocess.SubprocessError):
            folder = ""
    path = Path(folder) if folder else None
    if not path or path == HOME:
        path = next((HOME / n for n in ("Musik", "Music") if (HOME / n).is_dir()), HOME / "Musik")
    return path


def lists_dir():
    return music_dir() / "Spellistor"


def is_music(path):
    return Path(path).suffix.lower() in MUSIC_EXT


def to_path(text, base=None):
    """A line of a playlist, a dropped URL or a typed path → an absolute path (or None)."""
    text = text.strip()
    if not text:
        return None
    if text.startswith("file:"):
        text = unquote(urlparse(text).path)
    elif re.match(r"^[a-z][a-z0-9+.-]*://", text, re.I):
        return None                      # a web stream: not a file
    path = Path(os.path.expanduser(text))
    if not path.is_absolute() and base is not None:
        path = Path(base) / path
    return str(path.resolve()) if path.exists() else str(path)


def scan(folder):
    """Every music file under a folder (not hidden ones), in path order."""
    found = []
    for root, dirs, files in os.walk(folder):
        dirs[:] = sorted(d for d in dirs if not d.startswith("."))
        found.extend(os.path.join(root, f) for f in sorted(files)
                     if not f.startswith(".") and is_music(f))
    return found


def expand(paths):
    """Files and folders (dropped, chosen) → music files; playlists inside are read too."""
    out = []
    for p in paths:
        path = Path(p)
        if path.is_dir():
            out.extend(scan(path))
        elif path.suffix.lower() in LIST_EXT:
            out.extend(read_list(path))
        elif is_music(path):
            out.append(str(path))
    return out


# ── Playlists (.m3u, .m3u8, .pls) ──

def read_list(path):
    """The files in a playlist, in order. Relative paths are relative to the list's folder."""
    path = Path(path)
    try:
        raw = path.read_bytes()
    except OSError:
        return []
    try:
        text = raw.decode("utf-8-sig")
    except UnicodeDecodeError:
        text = raw.decode("latin-1")      # old Winamp .m3u
    base = path.parent
    out = []
    if path.suffix.lower() == ".pls":
        entries = {}
        for line in text.splitlines():
            m = re.match(r"\s*File(\d+)\s*=\s*(.+)", line, re.I)
            if m:
                entries[int(m.group(1))] = m.group(2)
        lines = [entries[k] for k in sorted(entries)]
    else:
        lines = [line for line in text.splitlines() if line.strip() and not line.startswith("#")]
    for line in lines:
        p = to_path(line, base)
        if p:
            out.append(p)
    return out


def write_list(path, rows):
    """Winamp's extended M3U in UTF-8, absolute paths; written next to it and then renamed."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = ["#EXTM3U"]
    for r in rows:
        name = " - ".join(t for t in (r.get("artist"), r.get("title")) if t)
        lines.append(f"#EXTINF:{int(r.get('seconds') or -1)},{name or Path(r['path']).stem}")
        lines.append(r["path"])
    tmp = path.with_name("." + path.name + ".tmp")
    tmp.write_text("\n".join(lines) + "\n", encoding="utf-8")
    tmp.replace(path)


def safe_name(name):
    name = re.sub(r'[/\\\0:*?"<>|]', " ", name).strip().strip(".")
    return re.sub(r"\s+", " ", name)[:80]


def free_file(name):
    """<music folder>/Spellistor/<name>.m3u8 that doesn't exist yet (Name 2, Name 3 …)."""
    folder = lists_dir()
    base = safe_name(name) or "Ny lista"
    path, n = folder / f"{base}.m3u8", 2
    while path.exists():
        path, n = folder / f"{base} {n}.m3u8", n + 1
    return path


def saved_lists():
    """[(id, name, path)] of the lists in Spellistor, by name."""
    folder = lists_dir()
    if not folder.is_dir():
        return []
    found = [p for p in folder.iterdir() if p.is_file() and p.suffix.lower() in LIST_EXT
             and not p.name.startswith(".")]
    return [("file:" + p.name, p.stem, p) for p in sorted(found, key=lambda p: p.stem.lower())]


def import_list(source):
    """An outside .m3u/.m3u8/.pls → a new list in Spellistor (absolute paths, so it works there)."""
    source = Path(source)
    paths = read_list(source)
    target = free_file(source.stem)
    write_list(target, [row_for(p) for p in paths])
    return target


# ── Tags ──

_lock = threading.Lock()
_cache = None


def _load():
    global _cache
    if _cache is None:
        try:
            _cache = json.loads(TAGS.read_text())
        except (OSError, ValueError):
            _cache = {}
    return _cache


def save_tags():
    with _lock:
        data = json.dumps(_load(), ensure_ascii=False)
    TAGS.parent.mkdir(parents=True, exist_ok=True)
    tmp = TAGS.with_name(".amp-tags.json.tmp")
    tmp.write_text(data)
    tmp.replace(TAGS)


def _stamp(path):
    try:
        st = os.stat(path)
        return [int(st.st_mtime), st.st_size]
    except OSError:
        return None


def row_for(path):
    """The row for a file from the cache: tags if known and the file is unchanged, else the
    file name (known: False – probe() reads it)."""
    stamp = _stamp(path)
    with _lock:
        hit = _load().get(path)
    if stamp is None:
        return {"path": path, "title": Path(path).stem, "artist": "", "album": "", "track": 0,
                "seconds": 0, "missing": True, "known": True}
    if hit and hit.get("stamp") == stamp:
        return {"path": path, **{k: hit.get(k) for k in ("title", "artist", "album", "track", "seconds")},
                "missing": False, "known": True}
    return {"path": path, "title": Path(path).stem, "artist": "", "album": "", "track": 0,
            "seconds": 0, "missing": False, "known": False}


def _number(value):
    m = re.match(r"\s*(\d+)", str(value or ""))
    return int(m.group(1)) if m else 0


def read_tags(path):
    """ffprobe's tags (format or first stream – Ogg keeps them in the stream) and length."""
    try:
        out = subprocess.run(["ffprobe", "-v", "quiet", "-print_format", "json", "-show_format",
                              "-show_streams", "-select_streams", "a:0", path],
                             capture_output=True, timeout=15).stdout
        info = json.loads(out or b"{}")
    except (OSError, ValueError, subprocess.SubprocessError):
        info = {}
    fmt = info.get("format") or {}
    tags = {k.lower(): v for k, v in (fmt.get("tags") or {}).items()}
    for stream in info.get("streams") or []:
        for k, v in (stream.get("tags") or {}).items():
            tags.setdefault(k.lower(), v)
    try:
        seconds = round(float(fmt.get("duration") or 0))
    except ValueError:
        seconds = 0
    return {"title": str(tags.get("title") or Path(path).stem).strip(),
            "artist": str(tags.get("artist") or tags.get("album_artist") or tags.get("albumartist") or "").strip(),
            "album": str(tags.get("album") or "").strip(),
            "track": _number(tags.get("track") or tags.get("tracknumber")),
            "seconds": seconds}


def probe(paths, progress=None, stop=None):
    """Reads the tags of the files that the cache doesn't know (6 at a time); progress(done,
    total, rows) now and then with the rows read so far. Returns {path: row}."""
    todo = [p for p in dict.fromkeys(paths) if not row_for(p)["known"]]
    done = {}
    if not todo:
        return done

    def one(p):
        tags = read_tags(p)
        with _lock:
            _load()[p] = {"stamp": _stamp(p), **tags}
        return p, {"path": p, **tags, "missing": False, "known": True}
    with ThreadPoolExecutor(6) as pool:
        for i, (p, row) in enumerate(pool.map(one, todo), 1):
            done[p] = row
            if progress and (i % 25 == 0 or i == len(todo)):
                progress(i, len(todo), dict(done))
            if stop and stop():
                break
    save_tags()
    return done


# ── Sorting ──

SORTS = {
    "artist": lambda r: (r["artist"].lower(), r["album"].lower(), r["track"], r["title"].lower()),
    "title": lambda r: (r["title"].lower(), r["artist"].lower()),
    "album": lambda r: (r["album"].lower(), r["track"], r["title"].lower()),
    "path": lambda r: r["path"].lower(),
    "length": lambda r: r["seconds"],
}


def sort_rows(rows, how):
    rows = list(rows)
    if how == "shuffle":
        random.shuffle(rows)
    elif how == "reverse":
        rows.reverse()
    elif how in SORTS:
        rows.sort(key=SORTS[how])
    return rows


# ── Cover pictures (for MPRIS: Plasma's media controls show them) ──

def cover_for(path):
    """A picture next to the file (cover.jpg, folder.png …), else the one inside the file
    (ffmpeg, cached). None when there is none."""
    folder = Path(path).parent
    try:
        pictures = {p.stem.lower(): p for p in folder.iterdir()
                    if p.suffix.lower() in (".jpg", ".jpeg", ".png", ".webp")}
    except OSError:
        pictures = {}
    for name in COVER_NAMES:
        if name in pictures:
            return str(pictures[name])
    stamp = _stamp(path)
    if not stamp or not shutil.which("ffmpeg"):
        return None
    key = hashlib.sha1(f"{path}|{stamp[0]}|{stamp[1]}".encode()).hexdigest()[:20]
    target = COVERS / f"{key}.jpg"
    if target.exists():
        return str(target) if target.stat().st_size else None
    COVERS.mkdir(parents=True, exist_ok=True)
    try:
        subprocess.run(["ffmpeg", "-v", "quiet", "-y", "-i", path, "-an", "-frames:v", "1",
                        "-vf", "scale='min(512,iw)':-2", str(target)], capture_output=True, timeout=15)
    except (OSError, subprocess.SubprocessError):
        pass
    if not target.exists():
        target.write_bytes(b"")           # remember: none inside
        return None
    return str(target) if target.stat().st_size else None
