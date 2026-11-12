"""Lets Qt's QML cache work for GOBLINCAKES' own windows (optimization P23, 12 Nov).

Qt keeps compiled QML in ~/.cache/<program>/qmlcache, but not for files dated 1970 – and every file in
an atomic image is. So each window compiled its QML from scratch at every start (Goblin AI ~0.5 s, on
her laptop ~1 s). Here the window folders' QML (with the pictures and scripts next to it, not the Python)
is copied once per image to ~/.cache/goblincakes/qml-src/<key>/ with ordinary dates, and the window
loads its Main.qml from there; Qt then caches it as usual.

The key is made of every copied file's inode and size: in an ostree image a changed file is always a new
object (a new inode), so an update can never leave an old window. Copies of other keys are removed.
Outside /usr/share/goblincakes (the repo) nothing is copied. Any trouble = the original path, as before.
Only the standard library.
"""
import hashlib
import os
import shutil
import tempfile
from pathlib import Path

ROOT = Path("/usr/share/goblincakes")
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "goblincakes/qml-src"
SKIP = {".py", ".pyc"}


def _folders():
    """The folders with QML in them (or one level down, as qml/Goblin) – relative imports stay inside them."""
    return [d for d in sorted(ROOT.iterdir())
            if d.is_dir() and (any(d.glob("*.qml")) or any(d.glob("*/*.qml")))]


def _files(folders):
    for d in folders:
        for f in sorted(d.rglob("*")):
            if f.is_file() and f.suffix not in SKIP and "__pycache__" not in f.parts:
                yield f


def _key(files):
    h = hashlib.sha1()
    for f in files:
        st = f.stat()
        h.update(f"{f.relative_to(ROOT)}\0{st.st_ino}\0{st.st_size}\n".encode())
    return h.hexdigest()[:16]


def local(path):
    """The path to load instead of `path` (a .qml under /usr/share/goblincakes) – or `path` itself."""
    path = Path(path)
    try:
        rel = path.relative_to(ROOT)
    except ValueError:
        return str(path)
    try:
        files = list(_files(_folders()))
        target = CACHE / _key(files)
        if not (target / rel).is_file():
            CACHE.mkdir(parents=True, exist_ok=True)
            tmp = Path(tempfile.mkdtemp(prefix=".new-", dir=CACHE))
            for f in files:
                dest = tmp / f.relative_to(ROOT)
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(f, dest)  # not copy2: the point is an ordinary date
            try:
                tmp.rename(target)
            except OSError:  # another window made the same copy at the same moment
                shutil.rmtree(tmp, ignore_errors=True)
            for old in CACHE.iterdir():
                if old.name != target.name and not old.name.startswith(".new-"):
                    shutil.rmtree(old, ignore_errors=True)
        if (target / rel).is_file():
            return str(target / rel)
    except OSError:
        pass
    return str(path)
