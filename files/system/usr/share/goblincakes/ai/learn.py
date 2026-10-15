"""learn – Goblin AI's learning mode ("Lär dig koda", 15 Oct, the user's wish).

The course base (/usr/share/goblincakes/learn, written beforehand and checked – the AI does not
make up the plan, the tasks or the marking): tracks.json (tracks + goals) and per track
<track>/modules.json (modules with lessons, tasks, checks, hints and solutions) and
<track>/<module>.md (the lesson). A task is marked by its check – the expected output, a
checker script, or rules for HTML/CSS – never by the AI. The AI is the teacher: it explains,
gives hints and reviews code (Goblin AI's project "Lärläge", only local AI by default).

The code runs in a separate container (podman, image localhost/goblincakes-learn built once from
sandbox/Containerfile: Python, PHP, Node.js, Lua 5.1, Bash, SQLite) without network – nothing the
user writes can harm the system. GOBLINCAKES_LEARN_SANDBOX=host runs it directly (tests only).

Progress: ~/.local/share/goblincakes/learn/progress.json.
"""
import json
import os
import re
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

BASE = Path(os.environ.get("GOBLINCAKES_LEARN_BASE", "/usr/share/goblincakes/learn"))
DATA = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "goblincakes/learn"
PROGRESS = DATA / "progress.json"
IMAGE = "localhost/goblincakes-learn:1"
LEVELS = ("nybörjare", "lite", "van")
REVIEW_AFTER = 2 * 86400  # a task that was hard comes back after two days

# How a track's code is run inside the sandbox: the file name and the command
RUNNERS = {
    "python": ("main.py", ["python3", "main.py"]),
    "lua": ("main.lua", ["lua5.1", "main.lua"]),
    "wowlua": ("main.lua", ["lua5.1", "/course/sandbox/wowrun.lua", "main.lua"]),
    "php": ("main.php", ["php", "main.php"]),
    "js": ("main.js", ["node", "main.js"]),
    "bash": ("main.sh", ["bash", "/code/main.sh"]),  # beside the work folder: not in ls/git status
    "sql": ("main.sql", ["python3", "/course/sandbox/sqlrun.py", "main.sql"]),
    "html": ("index.html", None),  # checked by rules, shown in the browser
    "check": ("check.py", ["python3", "check.py"]),  # a task's checker script (the user's file beside it)
}


# ── The course base ───────────────────────────────────────────────

def load_base():
    """{"tracks": [...], "goals": [...], "modules": {id: module}} – modules with their track."""
    try:
        top = json.loads((BASE / "tracks.json").read_text())
    except (OSError, ValueError):
        return {"tracks": [], "goals": [], "modules": {}}
    modules = {}
    for track in top.get("tracks", []):
        try:
            data = json.loads((BASE / track["id"] / "modules.json").read_text())
        except (OSError, ValueError):
            data = {"modules": []}
        track["count"] = len(data.get("modules", []))
        if not track["count"]:
            track["status"] = "ai"  # no lessons written yet: the AI teaches freely ("AI-läge")
        for m in data.get("modules", []):
            m["track"] = track["id"]
            m.setdefault("requires", [])
            m.setdefault("tasks", [])
            modules[m["id"]] = m
    return {"tracks": top.get("tracks", []), "goals": top.get("goals", []), "modules": modules}


def lesson_text(module):
    """The lesson without its first heading (the window shows the module's title itself)."""
    try:
        text = (BASE / module["track"] / module.get("lesson", module["id"] + ".md")).read_text()
    except OSError:
        return ""
    return re.sub(r"\A\s*# [^\n]*\n+", "", text)


def plan(base, tracks, done=()):
    """The modules of the chosen tracks in learning order: each after what it requires (also from
    other tracks – PHP needs HTML first), within a track in the course base's own order."""
    modules = base["modules"]
    wanted = [m for m in modules.values() if m["track"] in tracks]
    order, seen = [], set()

    def visit(mid, depth=0):
        if mid in seen or mid not in modules or depth > 50:
            return
        seen.add(mid)
        for req in modules[mid]["requires"]:
            visit(req, depth + 1)
        order.append(mid)
    track_order = [t["id"] for t in base["tracks"]]
    for m in sorted(wanted, key=lambda m: track_order.index(m["track"]) if m["track"] in track_order else 99):
        visit(m["id"])
    return order


# ── Progress ──────────────────────────────────────────────────────

def load_progress():
    try:
        return json.loads(PROGRESS.read_text())
    except (OSError, ValueError):
        return {}


def save_progress(p):
    DATA.mkdir(parents=True, exist_ok=True)
    tmp = PROGRESS.with_suffix(".tmp")
    tmp.write_text(json.dumps(p, ensure_ascii=False, indent=1))
    tmp.replace(PROGRESS)


def start_course(goal, tracks, level, own_goal="", order="local-only"):
    base = load_base()
    if goal:
        g = next((g for g in base["goals"] if g["id"] == goal), None)
        if g:
            tracks = list(dict.fromkeys(list(g["tracks"]) + list(tracks)))
    old = load_progress()
    p = {"goal": goal, "ownGoal": own_goal.strip(), "tracks": tracks,
         "level": level if level in LEVELS else "nybörjare", "order": order,
         "started": time.time(), "current": "",
         # what was learned before stays learned (a new goal doesn't start over)
         "modules": old.get("modules", {}), "tasks": old.get("tasks", {}), "drafts": old.get("drafts", {}),
         "tutor": old.get("tutor", {})}
    order_ = plan(base, tracks, p["modules"])
    p["current"] = next((m for m in order_ if not p["modules"].get(m)), order_[0] if order_ else "")
    save_progress(p)
    return p


def visible_tasks(module, level):
    """Experienced users skip the first, easiest tasks (level 1) – but never a locked (safety) one."""
    tasks = module.get("tasks", [])
    if level == "van":
        harder = [t for t in tasks if t.get("level", 1) >= 2 or module.get("locked")]
        return harder or tasks[-1:]
    return tasks


def state():
    """Everything the window shows, as one dict."""
    base = load_base()
    p = load_progress()
    out = {"tracks": base["tracks"], "goals": base["goals"], "course": None}
    if not p.get("tracks"):
        return out
    order_ = plan(base, p["tracks"], p.get("modules", {}))
    items, done_count = [], 0
    for mid in order_:
        m = base["modules"][mid]
        done = bool(p.get("modules", {}).get(mid))
        done_count += done
        items.append({"id": mid, "title": m["title"], "track": m["track"], "done": done,
                      "how": (p["modules"].get(mid) or {}).get("how", ""), "locked": bool(m.get("locked"))})
    now = time.time()
    review = [{"task": tid, "module": t.get("module", ""), "title": t.get("title", "")}
              for tid, t in p.get("tasks", {}).items() if t.get("reviewAt") and t["reviewAt"] <= now]
    goal = next((g for g in base["goals"] if g["id"] == p.get("goal")), None)
    ai_tracks = [t["id"] for t in base["tracks"] if t["id"] in p["tracks"] and t.get("status") == "ai"]
    out["course"] = {"goal": goal["name"] if goal else p.get("ownGoal") or "Eget urval",
                     "ownGoal": p.get("ownGoal", ""), "tracks": p["tracks"], "level": p["level"],
                     "order": p.get("order", "local-only"), "plan": items, "done": done_count,
                     "current": p.get("current", ""), "review": review[:5], "aiTracks": ai_tracks}
    return out


def module_view(mid):
    """A module for the window: the lesson, the tasks for the user's level and how far they got."""
    base = load_base()
    p = load_progress()
    m = base["modules"].get(mid)
    if not m:
        return None
    level = p.get("level", "nybörjare")
    tasks = []
    for t in visible_tasks(m, level):
        tp = p.get("tasks", {}).get(t["id"], {})
        tasks.append({"id": t["id"], "title": t["title"], "prompt": t["prompt"], "level": t.get("level", 1),
                      "file": RUNNERS.get(m.get("run") or base_run(base, m), ("main.txt", None))[0],
                      "code": p.get("drafts", {}).get(t["id"], t.get("starter", "")),
                      "hintCount": len(t.get("hints", [])), "hintsShown": tp.get("hints", 0),
                      "hints": t.get("hints", [])[:tp.get("hints", 0)],
                      "solution": t.get("solution", "") if tp.get("solution") else "",
                      "done": bool(tp.get("done")), "html": (m.get("run") or base_run(base, m)) == "html"})
    return {"id": mid, "title": m["title"], "track": m["track"], "locked": bool(m.get("locked")),
            "lesson": lesson_text(m) if level != "van" or not m.get("summary") else m["summary"],
            "summary": m.get("summary", ""), "level": level, "tasks": tasks,
            "done": bool(p.get("modules", {}).get(mid))}


def base_run(base, module):
    return next((t.get("run", t["id"]) for t in base["tracks"] if t["id"] == module["track"]), "python")


def find_task(base, task_id):
    for m in base["modules"].values():
        for t in m.get("tasks", []):
            if t["id"] == task_id:
                return m, t
    return None, None


# ── Running and checking ──────────────────────────────────────────

def sandbox_mode():
    return os.environ.get("GOBLINCAKES_LEARN_SANDBOX", "podman")


def sandbox_ready():
    if sandbox_mode() == "host":
        return True
    r = subprocess.run(["podman", "image", "exists", IMAGE], capture_output=True)
    return r.returncode == 0


def build_sandbox(progress=None):
    """The practice computer: built once from the course base's Containerfile (needs the internet)."""
    if sandbox_ready():
        return True, ""
    cmd = ["podman", "build", "-t", IMAGE, "-f", str(BASE / "sandbox/Containerfile"), str(BASE / "sandbox")]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    last = ""
    for line in proc.stdout:
        last = line.strip() or last
        if progress and line.strip():
            progress(line.strip()[:120])
    return proc.wait() == 0, last


def run_code(run, code, files=None, timeout=10):
    """Runs the user's code; returns (exit code, output). No network, little memory, 10 seconds."""
    filename, cmd = RUNNERS[run]
    work = Path(tempfile.mkdtemp(prefix="goblincakes-learn-"))
    codedir = Path(tempfile.mkdtemp(prefix="goblincakes-learn-code-"))
    try:
        apart = any(c.startswith("/code/") for c in cmd)  # the user's file outside the work folder
        ((codedir if apart else work) / filename).write_text(code)
        for name, text in (files or {}).items():
            (work / name).write_text(text)
        if sandbox_mode() == "host":
            host_cmd = [str(BASE / c[len("/course/"):]) if c.startswith("/course/")
                        else str(codedir / c[len("/code/"):]) if c.startswith("/code/") else c for c in cmd]
            try:
                r = subprocess.run(host_cmd, cwd=work, capture_output=True, text=True, timeout=timeout)
                return r.returncode, (r.stdout + r.stderr)[-8000:]
            except subprocess.TimeoutExpired:
                return 124, "Tog för lång tid (över 10 sekunder) – en loop som aldrig slutar?"
        full = ["podman", "run", "--rm", "--network=none", "--memory=256m", "--pids-limit=64",
                "--security-opt", "label=disable", "-v", f"{work}:/work", "-v", f"{BASE}:/course:ro",
                "-v", f"{codedir}:/code:ro",
                "-w", "/work", IMAGE, "timeout", str(timeout), *cmd]
        try:
            r = subprocess.run(full, capture_output=True, text=True, timeout=timeout + 30)
        except subprocess.TimeoutExpired:
            return 124, "Övningsdatorn svarade inte."
        out = (r.stdout + r.stderr)[-8000:]
        if r.returncode == 124:
            out += "\nTog för lång tid (över 10 sekunder) – en loop som aldrig slutar?"
        return r.returncode, out
    finally:
        shutil.rmtree(work, ignore_errors=True)
        shutil.rmtree(codedir, ignore_errors=True)


def norm(text):
    return "\n".join(line.rstrip() for line in text.strip().splitlines())


def check_html(code, check):
    """HTML/CSS: the things the task asks for must be there (tags, attributes, CSS)."""
    low = re.sub(r"\s+", " ", code.lower())
    missing = []
    for want in check.get("has", []):
        if want.lower() not in low:
            missing.append(want)
    for pattern in check.get("regex", []):
        if not re.search(pattern, code, re.I | re.S):
            missing.append(pattern)
    if missing:
        return False, "Saknas: " + ", ".join(f"`{m}`" for m in missing[:5])
    return True, check.get("ok", "Snyggt – allt som behövdes finns med.")


def check_task(task_id, code):
    """Runs the task's check: {"ok", "output", "message"} – the check marks it, not the AI."""
    base = load_base()
    module, task = find_task(base, task_id)
    if not task:
        return {"ok": False, "output": "", "message": "Uppgiften finns inte."}
    run = module.get("run") or base_run(base, module)
    check = task.get("check", {})
    p = load_progress()
    p.setdefault("drafts", {})[task_id] = code
    tp = p.setdefault("tasks", {}).setdefault(task_id, {"module": module["id"], "title": task["title"]})
    tp["attempts"] = tp.get("attempts", 0) + 1
    if run == "html":
        ok, msg = check_html(code, check)
        output = ""
    else:
        files = dict(task.get("files") or {})  # e.g. setup.sql, slash.txt
        if check.get("type") == "script":
            files["check.py"] = (BASE / module["track"] / check["script"]).read_text()
        code_, out = run_code(run, code, files)
        output = out
        if check.get("type") == "script":
            extra = dict(files, **{RUNNERS[run][0]: code, "output.txt": out})
            extra.pop("check.py")
            c2, msg_out = run_code("check", files["check.py"], extra)
            ok, msg = c2 == 0, msg_out.strip() or ("Rätt!" if c2 == 0 else "Inte riktigt än.")
        elif code_ != 0:
            ok, msg = False, "Programmet stannade med ett fel – läs felmeddelandet nedan."
        elif "expect" in check:
            ok = norm(out) == norm(check["expect"])
            msg = "Rätt!" if ok else "Utskriften blev inte som väntat. Väntat:\n" + check["expect"]
        elif "contains" in check:
            lacking = [c for c in check["contains"] if c not in out]
            ok = not lacking
            msg = "Rätt!" if ok else "Utskriften saknar: " + ", ".join(lacking)
        elif "regex" in check:
            ok = bool(re.search(check["regex"], out, re.S))
            msg = "Rätt!" if ok else "Utskriften blev inte som väntat."
        else:
            ok, msg = code_ == 0, "Körde utan fel."
    if ok:
        tp["done"] = time.time()
        if tp.get("attempts", 0) >= 4 or tp.get("solution"):
            tp["reviewAt"] = time.time() + REVIEW_AFTER  # hard: comes back as a review
        else:
            tp.pop("reviewAt", None)
        visible = visible_tasks(module, p.get("level", "nybörjare"))
        if all(p["tasks"].get(t["id"], {}).get("done") for t in visible):
            p.setdefault("modules", {})[module["id"]] = {"done": time.time(), "how": "klar"}
            order_ = plan(base, p.get("tracks", []), p["modules"])
            p["current"] = next((m for m in order_ if not p["modules"].get(m)), module["id"])
    save_progress(p)
    return {"ok": ok, "output": output, "message": msg}


def test_out(module_id):
    """"Jag kan redan det här": the module's last (hardest) task is the test."""
    base = load_base()
    m = base["modules"].get(module_id)
    return m["tasks"][-1]["id"] if m and m.get("tasks") else ""


def passed_test(module_id):
    p = load_progress()
    p.setdefault("modules", {})[module_id] = {"done": time.time(), "how": "provet"}
    base = load_base()
    order_ = plan(base, p.get("tracks", []), p["modules"])
    p["current"] = next((m for m in order_ if not p["modules"].get(m)), module_id)
    save_progress(p)


def next_hint(task_id):
    base = load_base()
    _, task = find_task(base, task_id)
    p = load_progress()
    tp = p.setdefault("tasks", {}).setdefault(task_id, {})
    tp["hints"] = min(tp.get("hints", 0) + 1, len((task or {}).get("hints", [])))
    save_progress(p)


def show_solution(task_id):
    p = load_progress()
    p.setdefault("tasks", {}).setdefault(task_id, {})["solution"] = True
    save_progress(p)


def save_draft(task_id, code):
    p = load_progress()
    p.setdefault("drafts", {})[task_id] = code
    save_progress(p)


def set_current(module_id):
    p = load_progress()
    p["current"] = module_id
    save_progress(p)


def reset_course():
    """Another goal: the plan goes, what was learned stays."""
    p = load_progress()
    for key in ("goal", "ownGoal", "tracks", "current", "level"):
        p.pop(key, None)
    save_progress(p)


# ── The teacher (Goblin AI's project "Lärläge") ───────────────────

TUTOR_PROMPT = """Du är lärare i GOBLINCAKES lärläge. Användaren lär sig programmera och ska skriva koden själv.
Regler:
- Ge inte hela lösningen. Förklara, ställ en motfråga eller ge EN ledtråd i taget. Visa lösningen bara om användaren uttryckligen ber om den.
- Följ kursgrunden: lektionen och uppgiften nedan är det som gäller. Hitta inte på andra krav. Extra uppgifter du själv föreslår märks "AI-uppgift".
- Förklara felmeddelanden på enkel svenska: vad det betyder, var felet sitter och hur man kan tänka.
- Säkerhetsmoment (prepared statements, lösenordshashning, escaping) får aldrig hoppas över eller ersättas med osäkra genvägar.
- Anpassa dig efter nivån: nybörjare = vardagsord och små steg; van = kort, tekniskt, varför och bästa sätt.
- Svara på svenska. Kort hellre än långt."""


def tutor_context(task_id, code="", error=""):
    """What the teacher gets to know about the task the user is on."""
    base = load_base()
    module, task = find_task(base, task_id)
    p = load_progress()
    if not task:
        return ""
    parts = [f"Nivå: {p.get('level', 'nybörjare')}. Mål: {(state().get('course') or {}).get('goal', '')}.",
             f"Modul: {module['title']} ({module['track']}).",
             "Lektionen (kursgrunden):\n" + (lesson_text(module) or module.get("summary", ""))[:6000],
             f"Uppgiften: {task['title']}\n{task['prompt']}"]
    if code:
        parts.append(f"Användarens kod just nu:\n```\n{code[:6000]}\n```")
    if error:
        parts.append(f"Senaste körningen:\n```\n{error[:3000]}\n```")
    return "\n\n".join(parts)
