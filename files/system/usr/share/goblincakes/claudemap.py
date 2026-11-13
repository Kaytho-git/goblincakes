"""CLAUDE CODE-kartan (13 Nov, the user: "build it in the dashboard and beside the terminal in Goblin AI").

What Claude Code is doing, read from the transcript it writes anyway – ~/.claude/projects/<folder>/<session>.jsonl
(and <session>/subagents/*.jsonl for the subagents' own calls). Nothing is installed into Claude Code: no hooks,
no plugin. Shared by the dashboard (the middle CLAUDE CODE + its frame) and Goblin AI (the pane beside TERMINAL);
drawn by qml/Goblin/ClaudeMap.qml.

    python3 claudemap.py [folder]     the state once, as JSON (the newest session, or the newest in that folder)

Watcher().state(prefer_cwd) is called every ½ s: it reads only what was added since the last call.
"""
import json
import os
import re
import sys
import time
from datetime import datetime
from pathlib import Path

STATIONS = ["you", "model", "memory", "files", "shell", "net", "browser", "agents", "skills", "hooks"]
NAMES = {"you": "DU", "model": "MODELL", "memory": "MINNE", "files": "FILER", "shell": "SKAL", "net": "NÄTVERK",
         "browser": "WEBBLÄSARE", "agents": "AGENTER", "skills": "SKILLS", "hooks": "HOOKS"}
ACTIVE_FOR = 30 * 60        # a session written to within this long counts as going on (chosen among)
TAIL = 2 * 1024 * 1024      # a newly chosen session: only its last 2 MB is read (a long one is 80 MB)
ROWS = 16

NET_CMDS = {"curl", "wget", "gh", "ssh", "scp", "sftp", "rsync", "ping", "nc", "ncat", "telnet", "ftp", "aria2c",
            "yt-dlp", "http", "https", "dig", "nslookup", "host", "skopeo", "cosign", "rpm-ostree", "bootc"}
NET_SUB = {"git": {"push", "pull", "fetch", "clone", "ls-remote", "remote"},
           "npm": {"install", "i", "ci", "publish", "update", "add"}, "pnpm": {"install", "i", "add", "update"},
           "yarn": {"install", "add", "upgrade"}, "pip": {"install", "download"}, "pip3": {"install", "download"},
           "dnf": {"install", "upgrade", "update", "download"}, "flatpak": {"install", "update", "remote-add"},
           "docker": {"pull", "push", "login"}, "podman": {"pull", "push", "login"},
           "cargo": {"install", "fetch", "update"}, "go": {"get", "install"}, "brew": {"install", "update"}}
FILE_CMDS = {"cat", "head", "tail", "less", "more", "grep", "rg", "egrep", "fgrep", "find", "ls", "tree", "mv",
             "cp", "rm", "rmdir", "mkdir", "touch", "sed", "tee", "wc", "diff", "stat", "file", "du", "chmod",
             "chown", "ln", "sort", "uniq", "cut", "tr", "awk", "basename", "dirname", "realpath", "readlink",
             "fd", "bat", "jq", "zcat", "xxd", "od", "cmp", "md5sum", "sha256sum"}
NEUTRAL = {"cd", "echo", "true", "false", "printf", ":", "pwd", "test", "["}
WRAPPERS = {"sudo", "env", "timeout", "nohup", "xargs", "nice", "ionice", "time", "command", "exec", "stdbuf",
            "doas", "builtin", "flatpak-spawn"}


def projects_dir():
    return Path(os.environ.get("CLAUDE_CONFIG_DIR") or Path.home() / ".claude") / "projects"


def folder_key(path):
    """Claude Code's name for a folder's transcripts: every character but letters and digits becomes -."""
    return re.sub(r"[^A-Za-z0-9]", "-", str(path))


def epoch(stamp):
    try:
        return datetime.fromisoformat(str(stamp).replace("Z", "+00:00")).timestamp()
    except ValueError:
        return time.time()


def short_model(name):
    """claude-opus-5-5 → opus 5.5, claude-sonnet-4-5-20250929 → sonnet 4.5."""
    s = re.sub(r"^claude-", "", str(name or "")).replace("[1m]", "")
    s = re.sub(r"-\d{8}$", "", s)
    m = re.match(r"([a-z]+)-(\d+)(?:-(\d+))?", s)
    return f"{m.group(1)} {m.group(2)}" + (f".{m.group(3)}" if m.group(3) else "") if m else s


def first_word(segment):
    """The command a shell segment runs: past assignments, wrappers and their flags."""
    words = segment.strip().lstrip("({!").split()
    i = 0
    while i < len(words):
        w = words[i]
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", w) or w in ("then", "do", "else", "if", "while", "!"):
            i += 1
            continue
        name = w.strip("'\"").rsplit("/", 1)[-1].lower()
        if name.endswith(".exe"):
            name = name[:-4]
        if name in WRAPPERS:
            i += 1
            while i < len(words) and (words[i].startswith("-") or re.match(r"^\d+[smh]?$", words[i])):
                i += 1
            continue
        return name, [x.strip("'\"") for x in words[i + 1:i + 4]]
    return "", []


def shell_station(command):
    """Bash: Network when any part reaches the net, Files when every part only works on files, else Shell."""
    text = str(command or "")
    # Text, not commands: a heredoc's body, '…', and "…" without $( in it (python3 -c "… curl …" is Shell)
    text = re.sub(r"<<-?\s*['\"]?(\w+)['\"]?.*?\n.*?\n\1\b", " ", text, flags=re.S)
    text = re.sub(r"'[^']*'", "''", text)
    text = re.sub(r'"(?:[^"\\$]|\\.)*"', '""', text)
    parts = re.split(r"\|\||&&|[|;&\n]|\$\(|`", text)
    kinds = set()
    for seg in parts:
        name, rest = first_word(seg)
        if not name or name in NEUTRAL:
            continue
        if name in NET_CMDS or (name in NET_SUB and rest and rest[0] in NET_SUB[name]) \
                or (name == "npx" and "-y" in rest):
            return "net"
        kinds.add("files" if name in FILE_CMDS else "shell")
    return "files" if kinds == {"files"} else "shell"


def is_memory_path(path):
    p = str(path or "")
    return "/.claude/" in p and "/memory" in p or p.endswith("/MEMORY.md")


def classify(name, args):
    """A tool call → (station, label)."""
    args = args if isinstance(args, dict) else {}
    path = args.get("file_path") or args.get("notebook_path") or args.get("path") or ""
    short = lambda p: str(p).rstrip("/").rsplit("/", 1)[-1] or str(p)  # noqa: E731
    if name in ("Bash", "PowerShell", "BashOutput"):
        cmd = str(args.get("command") or "").strip()
        # The label: without a leading cd <folder> && (Claude starts many commands so), the first line
        cmd = re.sub(r"^(cd\s+(\"[^\"]*\"|'[^']*'|\S+)\s*(&&|;)\s*)+", "", cmd).splitlines()
        cmd = re.sub(r"\s+", " ", cmd[0]) if cmd else name
        return shell_station(args.get("command")) if name != "BashOutput" else "shell", cmd
    if name in ("Read", "Write", "Edit", "MultiEdit", "NotebookEdit"):
        verb = {"Read": "läser", "Write": "skriver", "Edit": "ändrar", "MultiEdit": "ändrar",
                "NotebookEdit": "ändrar"}[name]
        return ("memory" if is_memory_path(path) else "files"), f"{verb} {short(path)}"
    if name == "Grep":
        return "files", f"söker \"{args.get('pattern', '')}\""
    if name == "Glob":
        return "files", f"letar {args.get('pattern', '')}"
    if name in ("WebFetch",):
        host = re.sub(r"^https?://([^/]+).*$", r"\1", str(args.get("url") or ""))
        return "net", f"hämtar {host}"
    if name == "WebSearch":
        return "net", f"söker på nätet \"{args.get('query', '')}\""
    if name in ("Agent", "Task", "Workflow"):
        return "agents", str(args.get("description") or args.get("subagent_type") or "agent")
    if name in ("Skill",):
        return "skills", f"skill {args.get('skill') or args.get('command') or ''}".strip()
    if name in ("ToolSearch",):
        return "skills", "letar verktyg"
    if name in ("AskUserQuestion", "SendUserFile", "PushNotification"):
        return "you", {"AskUserQuestion": "frågar dig", "SendUserFile": "skickar en fil",
                       "PushNotification": "notis till dig"}[name]
    if name.startswith("mcp__"):
        _, server, *tool = name.split("__")
        tool = "__".join(tool)
        low = (server + " " + tool).lower()
        if "browser" in low or "chrome" in low or "playwright" in low:
            return "browser", f"{server} · {tool}"
        if "memory" in low or tool in ("losningar", "rapporter"):
            return "memory", f"{server} · {tool}"
        return "net", f"{server} · {tool}"
    if name in ("Artifact",):
        return "net", "artifact"
    if name in ("Monitor", "TaskStop", "TaskOutput", "KillShell"):
        return "shell", name.lower()
    return "model", name


def result_text(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return " ".join(str(c.get("text", "")) for c in content if isinstance(c, dict))
    return ""


class Session:
    """One transcript being followed."""

    def __init__(self, path, quiet=True):
        self.path = Path(path)
        self.id = self.path.stem
        self.offsets = {}         # file → read up to
        self.calls = {}           # tool_use id → {st, label, start, src, bg}
        self.done_ids = set()
        self.count = {s: 0 for s in STATIONS}
        self.errors = {s: 0 for s in STATIONS}
        self.mem_hook = 0
        self.rows = []
        self.route = []           # [[station, t]] – the main loop's last stations (not the model)
        self.events = []          # pulses for the drawing: {seq, st, kind, src}
        self.seq = 0
        self.quiet = quiet        # the first reading draws no pulses (it is history)
        self.model = ""
        self.tokens = 0
        self.max_tokens = 0
        self.busy = False
        self.turn_start = 0.0
        self.last_msg = ""
        self.cwd = ""
        self.last_write = 0.0
        self.answered = 0.0

    # ── what the drawing gets ──
    def pulse(self, st, kind, src="core"):
        if self.quiet:
            return
        self.seq += 1
        self.events.append({"seq": self.seq, "st": st, "kind": kind, "src": src})
        del self.events[:-60]

    def row(self, st, label, start, state="run", key=None, end=None):
        r = {"st": st, "label": label[:160], "start": start, "end": end, "state": state, "n": 0, "key": key}
        self.rows.append(r)
        del self.rows[:-40]
        return r

    def finish_row(self, key, end, state):
        for i in range(len(self.rows) - 1, -1, -1):
            r = self.rows[i]
            if r.get("key") == key:
                r["end"], r["state"] = end, state
                prev = self.rows[i - 1] if i > 0 else None
                # Finished calls in a row at one station fold into one: "+2" for the others
                if (state == "ok" and i == len(self.rows) - 1 and prev and prev["st"] == r["st"]
                        and prev["state"] == "ok" and prev.get("fold", True) and r["st"] not in ("you", "model")):
                    r["n"] = prev["n"] + 1
                    r["start"] = prev["start"]
                    del self.rows[i - 1]
                return

    def go(self, st, t):
        if st == "model":
            return
        if self.route and self.route[-1][0] == st:
            self.route[-1][1] = t
        else:
            self.route.append([st, t])
            del self.route[:-6]

    # ── reading ──
    def read(self):
        files = [self.path]
        sub = self.path.with_suffix("") / "subagents"
        if sub.is_dir():
            files += sorted(sub.glob("*.jsonl"))
        for f in files:
            self.read_file(f, f != self.path)
        self.quiet = False

    def read_file(self, path, side):
        try:
            size = path.stat().st_size
            if not side:
                self.last_write = path.stat().st_mtime
        except OSError:
            return
        first = path not in self.offsets
        at = self.offsets.get(path, 0)
        if first and not side:
            at = max(0, size - TAIL)
        if size < at:
            at = 0
        if size == at:
            self.offsets[path] = at
            return
        with open(path, "rb") as fh:
            fh.seek(at)
            data = fh.read(size - at)
        cut = data.rfind(b"\n")
        if cut < 0:
            self.offsets[path] = at
            return
        start = data.find(b"\n") + 1 if first and at else 0     # a tail starts mid-line
        self.offsets[path] = at + cut + 1
        for line in data[start:cut].splitlines():
            try:
                d = json.loads(line)
            except ValueError:
                continue
            if isinstance(d, dict):
                self.entry(d, side)

    def entry(self, d, side):
        kind = d.get("type")
        t = epoch(d["timestamp"]) if d.get("timestamp") else None
        src = "agents" if side or d.get("isSidechain") else "core"
        if d.get("cwd") and not side:
            self.cwd = d["cwd"]
        msg = d.get("message") if isinstance(d.get("message"), dict) else {}
        content = msg.get("content")
        if kind == "assistant" and t:
            self.assistant(d, msg, content, t, src, side)
        elif kind == "user" and t:
            self.user(d, content, t, src, side)
        elif kind == "system" and t:
            sub = d.get("subtype") or ""
            if "hook" in sub:
                bad = bool(d.get("hookErrors")) or d.get("preventedContinuation")
                self.count["hooks"] += 1
                self.pulse("hooks", "err" if d.get("preventedContinuation") else "flash")
                if bad:
                    text = (d.get("hookErrors") or [d.get("stopReason") or "hook"])[0]
                    self.row("hooks", "hook: " + str(text).split("\n")[0].split("]: ", 1)[-1], t,
                             "err" if d.get("preventedContinuation") else "ok", end=t)
            elif sub == "compact_boundary":
                pre = (d.get("compactMetadata") or {}).get("preTokens") or 0
                self.max_tokens = max(self.max_tokens, pre)
                self.tokens = (d.get("compactMetadata") or {}).get("postTokens") or 0
                self.pulse("model", "flash")
                self.row("model", "kontexten komprimerad", t, "ok", end=t)
        elif kind == "attachment" and t and not side:
            a = d.get("attachment") or {}
            if "hook" in str(a.get("type", "")):
                self.count["hooks"] += 1
                self.pulse("hooks", "flash")
            if a.get("type") in ("nested_memory", "memory") or is_memory_path(a.get("filename") or a.get("path")):
                self.mem_hook += 1
                self.pulse("memory", "hollow")

    def assistant(self, d, msg, content, t, src, side):
        model = msg.get("model") or ""
        if not side and model and model != "<synthetic>":
            if self.model and model != self.model:
                self.row("model", f"{short_model(self.model)} → {short_model(model)}", t, "switch", end=t)
                self.pulse("model", "switch")
            self.model = model
        usage = msg.get("usage") or {}
        if usage and not side:
            used = sum(int(usage.get(k) or 0) for k in ("input_tokens", "cache_read_input_tokens",
                                                       "cache_creation_input_tokens"))
            if used:
                self.tokens = used
                self.max_tokens = max(self.max_tokens, used)
        mid = msg.get("id")
        if mid and mid != self.last_msg:      # one model step per message (it comes in several entries)
            self.last_msg = mid
            self.count["model"] += 1
            self.pulse("model", "flash", src)
        if not side:
            self.busy = True
        for c in content if isinstance(content, list) else []:
            if not isinstance(c, dict) or c.get("type") != "tool_use":
                continue
            cid = c.get("id")
            if cid in self.calls or cid in self.done_ids:
                continue
            st, label = classify(c.get("name", ""), c.get("input"))
            bg = bool((c.get("input") or {}).get("run_in_background"))
            self.calls[cid] = {"st": st, "label": label, "start": t, "src": src, "bg": bg}
            self.count[st] += 1
            if not side:
                self.go(st, t)
            self.pulse(st, "out", src)
            r = self.row(st, label, t, key=cid)
            r["src"] = src
        if not side and msg.get("stop_reason") == "end_turn":
            self.end_turn(t)

    def end_turn(self, t):
        if self.busy:
            self.pulse("core", "answer")
            took = t - self.turn_start if self.turn_start else 0
            self.row("you", "svaret klart", self.turn_start or t, "answer", end=t)["took"] = took
        self.busy = False
        self.answered = t

    def user(self, d, content, t, src, side):
        if isinstance(content, list):
            for c in content:
                if not isinstance(c, dict) or c.get("type") != "tool_result":
                    continue
                cid = c.get("tool_use_id")
                call = self.calls.pop(cid, None)
                if not call:
                    continue
                self.done_ids.add(cid)
                text = result_text(c.get("content"))
                err = bool(c.get("is_error"))
                st = call["st"]
                if err:
                    self.errors[st] += 1
                    if "hook" in text.lower()[:200]:
                        self.errors["hooks"] += 1
                        self.pulse("hooks", "err")
                self.pulse(st, "err" if err else "back", call["src"])
                self.finish_row(cid, t, "err" if err else "ok")
            return
        if side or d.get("isMeta") or not isinstance(content, str):
            return
        text = content.strip()
        if text.startswith("[Request interrupted"):
            self.busy = False
            self.row("you", "avbrutet", t, "err", end=t)
            for cid in list(self.calls):
                if self.calls[cid]["src"] == "core":
                    self.finish_row(cid, t, "err")
                    self.calls.pop(cid)
            return
        if text.startswith(("<local-command", "Caveat:", "<task-notification", "This session is being continued")):
            return
        if text.startswith("Stop hook feedback"):
            self.count["hooks"] += 1
            self.pulse("hooks", "flash")
            return
        m = re.search(r"<command-name>(.*?)</command-name>", text)
        label = m.group(1) if m else re.sub(r"\s+", " ", text)
        self.count["you"] += 1
        for s in self.errors:     # the red dots stay until your next message
            self.errors[s] = 0
        self.go("you", t)
        self.pulse("you", "in")
        self.row("you", label, t, "ok", end=t)["fold"] = False
        self.busy = not m
        self.turn_start = t

    def window(self):
        return 1_000_000 if "[1m]" in self.model or self.max_tokens > 200_000 else 200_000

    def state(self, now):
        running = [dict(st=c["st"], label=c["label"], since=c["start"], src=c["src"], bg=c["bg"])
                   for c in self.calls.values()]
        idle = now - self.last_write
        # A crash or a closed terminal leaves calls unanswered: after 15 min without a line they are let go
        if idle > 15 * 60:
            running, self.busy = [], False
        stations = {s: {"n": self.count[s], "err": self.errors[s],
                        "run": sum(1 for r in running if r["st"] == s)} for s in STATIONS}
        stations["memory"]["hook"] = self.mem_hook
        rows = [{k: r.get(k) for k in ("st", "label", "start", "end", "state", "n", "took", "src")}
                for r in self.rows[-ROWS:]]
        now_line = (running[-1]["label"] if running else "tänker…" if self.busy else
                    "väntar på dig" if idle < ACTIVE_FOR else "ingen aktivitet")
        return {"session": self.id, "cwd": self.cwd, "folder": Path(self.cwd).name if self.cwd else "",
                "model": short_model(self.model), "context": round(100 * self.tokens / self.window()),
                "busy": self.busy or bool(running), "running": running, "stations": stations, "rows": rows,
                "route": self.route, "events": self.events, "now": now_line, "agents":
                sum(1 for r in running if r["st"] == "agents"), "answered": self.answered, "idle": round(idle)}


class Watcher:
    """Picks the session to show and keeps it read. prefer_cwd: the folder a terminal stands in (Goblin AI)."""

    def __init__(self, root=None):
        self.root = Path(root) if root else projects_dir()
        self.sessions = {}
        self.pick = ""            # a session chosen by hand (the chips over the map)
        self.scanned = 0.0
        self.found = []
        self.cwds = {}

    def scan(self, now):
        if now - self.scanned < 3 and self.found:
            return self.found
        self.scanned = now
        out = []
        try:
            for f in self.root.glob("*/*.jsonl"):
                try:
                    m = f.stat().st_mtime
                except OSError:
                    continue
                if now - m < ACTIVE_FOR or f.stem == self.pick:
                    out.append((m, f))
        except OSError:
            pass
        if not out:   # nothing going on: the newest at all, so the map shows the last session
            try:
                newest = max(((f.stat().st_mtime, f) for f in self.root.glob("*/*.jsonl")), default=None)
            except OSError:
                newest = None
            out = [newest] if newest else []
        self.found = sorted(out, reverse=True)
        return self.found

    def folder_of(self, path):
        """The session's folder, from the cwd its lines carry (cached; the folder name in projects/ is lossy)."""
        if path not in self.cwds:
            cwd = ""
            try:
                with open(path, "rb") as fh:
                    for _ in range(40):
                        line = fh.readline()
                        if not line:
                            break
                        m = re.search(rb'"cwd":\s*"([^"]+)"', line)
                        if m:
                            cwd = m.group(1).decode(errors="replace")
                            break
            except OSError:
                pass
            self.cwds[path] = cwd
        return self.cwds[path]

    def choose(self, found, prefer_cwd):
        if self.pick:
            for _, f in found:
                if f.stem == self.pick:
                    return f
        if prefer_cwd:
            key = folder_key(prefer_cwd.rstrip("/"))
            for _, f in found:
                if f.parent.name == key:
                    return f
        return found[0][1] if found else None

    def state(self, prefer_cwd=""):
        now = time.time()
        found = self.scan(now)
        path = self.choose(found, prefer_cwd)
        if path is None:
            return {"none": True, "sessions": []}
        s = self.sessions.get(path)
        if s is None:
            s = self.sessions[path] = Session(path)
        s.read()
        for other in list(self.sessions):      # sessions no longer shown are forgotten
            if other != path and other not in {f for _, f in found}:
                del self.sessions[other]
        out = s.state(now)
        out["cwd"] = self.folder_of(path) or out["cwd"]     # the folder it was started in (not where it cd'd)
        out["folder"] = Path(out["cwd"]).name if out["cwd"] else path.parent.name
        out["sessions"] = [{"id": f.stem, "folder": Path(self.folder_of(f)).name or f.parent.name,
                            "active": now - m < 120, "on": f == path} for m, f in found[:6]]
        out["picked"] = bool(self.pick)
        return out


if __name__ == "__main__":
    print(json.dumps(Watcher().state(sys.argv[1] if len(sys.argv) > 1 else ""), ensure_ascii=False, indent=1))
