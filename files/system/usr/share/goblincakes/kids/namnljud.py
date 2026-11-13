"""Barnläge's name sounds (13 Nov, the user: Cori says the game's name when he holds the mouse over it – made once as a
file when the game is added, not a voice running all the time).

    python3 namnljud.py make      every game/program in kids.json without a sound gets one (JSON lines: progress)
    python3 namnljud.py engine    which voice would be used ("chatterbox", "piper" or "")

Voices, best first:
  1. Chatterbox Multilingual imitating Cori (chosen 5 Nov, cfg_weight 0.3): a folder with a Python environment that has
     chatterbox, and cori/ref.wav – kids.json "chatterbox" (the folder), ~/.local/share/goblincakes-chatterbox, or the
     test folder rostprov-chatterbox on a mounted disk (/run/media/<user>/*/). Its HF_HOME is a folder there with
     hub/ in it. Uses the graphics card for a few seconds while Config makes the sounds – never in Barnläge.
  2. Piper's Cori (en_GB-cori-high, LibriVox = public domain) in Kakan's voice environment (goblincakes-voice);
     the model is fetched (~110 MB) the first time.
The game's name is said in English (most names are); with å/ä/ö in it Chatterbox says it in Swedish.
"""
import hashlib
import json
import os
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import kids as K  # noqa: E402

SOUNDS = K.DATA / "namn"
VOICE_DIR = Path(os.environ.get("GOBLINCAKES_VOICE_DIR")
                 or Path(os.environ.get("XDG_DATA_HOME") or K.HOME / ".local/share") / "goblincakes-voice")
PIPER_PY = VOICE_DIR / "venv/bin/python3"
CORI = VOICE_DIR / "models/piper/en_GB-cori-high.onnx"
CORI_URL = "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_GB/cori/high/en_GB-cori-high"


def spoken(name):
    """What is said for a game: the name before a colon or dash ("Bluey: The Videogame" → "Bluey"), without ™ ®."""
    text = re.sub(r"[™®©]", "", name or "")
    text = re.split(r"\s*[:–—]\s*|\s+-\s+", text)[0].strip()
    return text or (name or "").strip()


def path_for(text):
    slug = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")[:30] or "namn"
    return SOUNDS / f"{slug}-{hashlib.sha1(text.encode()).hexdigest()[:8]}.wav"


def sound_for(item):
    """The made sound for an item, or "" (none yet)."""
    p = path_for(item.get("say") or spoken(item.get("name", "")))
    return str(p) if p.is_file() else ""


# ───────────────────────────────────────────── finding the voices
def _python_in(folder):
    for rel in (".venv/bin/python", "venv/bin/python", ".venv/bin/python3", "venv/bin/python3"):
        if (folder / rel).is_file():
            return folder / rel
    return None


def chatterbox():
    """(python, ref.wav, HF_HOME or None) – or None."""
    folders = []
    own = K.load_raw().get("chatterbox")
    if own:
        folders.append(Path(own).expanduser())
    folders.append(Path(os.environ.get("XDG_DATA_HOME") or K.HOME / ".local/share") / "goblincakes-chatterbox")
    user = os.environ.get("USER") or K.HOME.name
    folders += sorted(Path(f"/run/media/{user}").glob("*/rostprov-chatterbox"))
    for folder in folders:
        py, ref = _python_in(folder), folder / "cori/ref.wav"
        if py and ref.is_file():
            hf = next((d for d in sorted(folder.iterdir()) if d.is_dir() and (d / "hub").is_dir()), None) \
                if folder.is_dir() else None
            return py, ref, hf
    return None


def piper_ok():
    return PIPER_PY.is_file()


def engine():
    return "chatterbox" if chatterbox() else "piper" if piper_ok() else ""


def _fetch_cori():
    for ext in (".onnx", ".onnx.json"):
        dest = CORI.with_suffix(ext)
        if dest.is_file():
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        tmp = dest.with_name(dest.name + ".part")
        req = urllib.request.Request(CORI_URL + ext, headers={"User-Agent": "goblincakes"})
        with urllib.request.urlopen(req, timeout=60) as r, open(tmp, "wb") as f:
            while True:
                chunk = r.read(1 << 20)
                if not chunk:
                    break
                f.write(chunk)
        tmp.replace(dest)


# ───────────────────────────────────────────── making them
def make(jobs, said=print):
    """jobs = [(text, path)]. Returns the number made."""
    if not jobs:
        return 0
    SOUNDS.mkdir(parents=True, exist_ok=True)
    args = [a for text, path in jobs for a in (str(path), text)]
    found = chatterbox()
    if found:
        py, ref, hf = found
        env = dict(os.environ)
        if hf:
            env["HF_HOME"] = str(hf)
        said({"state": "making", "voice": "chatterbox", "count": len(jobs)})
        r = subprocess.run([str(py), str(HERE / "namnljud_chatterbox.py"), str(ref), *args],
                           capture_output=True, text=True, env=env, timeout=600)
        made = sum(1 for _, p in jobs if Path(p).is_file())
        if made == len(jobs):
            return made
        said({"state": "fallback", "why": (r.stderr.strip().splitlines() or ["?"])[-1][:200]})
    if piper_ok():
        said({"state": "making", "voice": "piper", "count": len(jobs)})
        try:
            _fetch_cori()
        except OSError as e:
            said({"state": "error", "why": f"Kunde inte hämta Cori ({e})"})
            return 0
        subprocess.run([str(PIPER_PY), str(HERE / "namnljud_piper.py"), str(CORI), *args],
                       capture_output=True, text=True, timeout=300)
    return sum(1 for _, p in jobs if Path(p).is_file())


def missing():
    jobs = []
    for item in K.load()["items"]:
        text = item.get("say") or spoken(item.get("name", ""))
        p = path_for(text)
        if text and not p.is_file():
            jobs.append((text, p))
    return jobs


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "engine":
        print(engine())
    elif cmd == "make":
        out = lambda d: print(json.dumps(d, ensure_ascii=False), flush=True)  # noqa: E731
        jobs = missing()
        n = make(jobs, out)
        out({"state": "done", "made": n, "wanted": len(jobs), "voice": engine()})
    else:
        print(__doc__)
