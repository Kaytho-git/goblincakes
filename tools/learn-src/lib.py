import json
from pathlib import Path
import os
# GOBLINCAKES_LEARN_OUT = an own course's folder (~/.local/share/goblincakes/learn/egna) instead of the course base
ROOT = Path(os.environ.get("GOBLINCAKES_LEARN_OUT") or Path(__file__).resolve().parents[2] / "files/system/usr/share/goblincakes/learn")

def write_track(track, modules):
    """modules: list of dicts with "lesson_md" text; writes <track>/modules.json and the .md files."""
    d = ROOT / track
    d.mkdir(parents=True, exist_ok=True)
    for old in d.glob("*.md"):
        old.unlink()
    out = []
    for m in modules:
        m = dict(m)
        md = m.pop("lesson_md")
        m["lesson"] = m["id"] + ".md"
        (d / m["lesson"]).write_text(md.strip() + "\n")
        out.append(m)
    (d / "modules.json").write_text(json.dumps({"modules": out}, ensure_ascii=False, indent=1) + "\n")

def T(id, level, title, prompt, solution, check, hints, starter="", files=None):
    t = {"id": id, "level": level, "title": title, "prompt": prompt, "starter": starter,
         "check": check, "hints": hints, "solution": solution}
    if files:
        t["files"] = files
    return t
