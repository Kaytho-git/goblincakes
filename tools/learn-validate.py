#!/usr/bin/env python3
"""Checks GOBLINCAKES' course base (files/system/usr/share/goblincakes/learn): every module has its
lesson, every "requires" exists, and every task's solution passes its own check (and the
starter does not). Runs the code directly (needs python3, php with pdo_sqlite, node, lua5.1,
bash, git). Usage: python3 tools/learn-validate.py [track …]"""
import json
import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
os.environ["GOBLINCAKES_LEARN_BASE"] = str(ROOT / "files/system/usr/share/goblincakes/learn")
os.environ["GOBLINCAKES_LEARN_SANDBOX"] = "host"
os.environ["XDG_DATA_HOME"] = tempfile.mkdtemp()
sys.path.insert(0, str(ROOT / "files/system/usr/share/goblincakes/ai"))
import learn  # noqa: E402

base = learn.load_base()
only = set(sys.argv[1:])
errors, count = [], 0
for mid, m in base["modules"].items():
    if only and m["track"] not in only:
        continue
    if not learn.lesson_text(m):
        errors.append(f"{mid}: lektionen saknas ({m.get('lesson')})")
    for req in m["requires"]:
        if req not in base["modules"]:
            errors.append(f"{mid}: kräver {req}, som inte finns")
    if not m["tasks"]:
        errors.append(f"{mid}: inga uppgifter")
    for t in m["tasks"]:
        count += 1
        for key in ("id", "title", "prompt", "check", "hints", "solution"):
            if key not in t:
                errors.append(f"{t.get('id', mid)}: saknar {key}")
        r = learn.check_task(t["id"], t["solution"])
        if not r["ok"]:
            errors.append(f"{t['id']}: lösningen klarar inte kontrollen – {r['message']}\n{r['output']}")
        if t.get("starter", "").strip():
            r2 = learn.check_task(t["id"], t["starter"])
            if r2["ok"]:
                errors.append(f"{t['id']}: startkoden klarar redan kontrollen")
print(f"{count} uppgifter i {len([m for m in base['modules'].values() if not only or m['track'] in only])} moduler")
for e in errors:
    print("FEL:", e)
sys.exit(1 if errors else 0)
