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

# "kakan" (14 Nov, the user: "att det visas i kartan när hon jobbar för dig"): Claude or Codex using Kakan – her picture
# program, her model through Ollama, her MCP tools. Not on Kakan's own map (KakanSession.ORDER).
STATIONS = ["you", "model", "memory", "files", "shell", "net", "browser", "agents", "kakan", "skills", "hooks"]
NAMES = {"you": "DU", "model": "MODELL", "memory": "MINNE", "files": "FILER", "shell": "SKAL", "net": "NÄTVERK",
         "browser": "WEBBLÄSARE", "agents": "AGENTER", "kakan": "KAKAN", "skills": "SKILLS", "hooks": "HOOKS"}
KAKAN_CMDS = [   # a command that has Kakan work → its row on the map
    (r"\bgoblin(?:cakes-pixelart|\s+pixelart)\s+kakan\b((?:\s+[a-zåäö][\w-]*)*)", lambda m: "Kakan ritar " + (
        " ".join(m.group(1).split()) or "pixelart")),
    (r"\bgoblincakes-image\s+generate\b", lambda m: "Kakan ritar en bild"),
    (r"\bgoblincakes-image\s+pull-style\b", lambda m: "Kakan hämtar en ritstil"),
    (r"\bollama\s+(?:run|generate)\b", lambda m: "Kakan tänker (Ollama)"),
    (r"(?:localhost|127\.0\.0\.1):11434/api/(?:generate|chat)", lambda m: "Kakan tänker (Ollama)"),
]


def kakan_use(command):
    """The row for a command that has Kakan work, or "" (a plain command). Text isn't a command: a heredoc's body
    and '…'/"…" are left out first, as in shell_station (python3 -c "… goblin pixelart kakan …" is no drawing)."""
    text = str(command or "")
    text = re.sub(r"<<-?\s*['\"]?(\w+)['\"]?.*?\n.*?\n\1\b", " ", text, flags=re.S)
    text = re.sub(r"'[^']*'", "''", text)
    text = re.sub(r'"(?:[^"\\$]|\\.)*"', '""', text)
    for pattern, label in KAKAN_CMDS:
        m = re.search(pattern, text)
        if m:
            return label(m)
    return ""
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
    if not str(name or "").startswith("claude"):
        return str(name or "")             # gpt-5-codex, gemma4:12b · din dator – as they are
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


def command_label(command):
    """A command's row: without a leading cd <folder> && (Claude and Codex start many commands so), the first line."""
    cmd = re.sub(r"^(cd\s+(\"[^\"]*\"|'[^']*'|\S+)\s*(&&|;)\s*)+", "", str(command or "").strip()).splitlines()
    return re.sub(r"\s+", " ", cmd[0]) if cmd else ""


def is_memory_path(path):
    p = str(path or "")
    return "/.claude/" in p and "/memory" in p or p.endswith("/MEMORY.md")


def classify(name, args):
    """A tool call → (station, label)."""
    args = args if isinstance(args, dict) else {}
    path = args.get("file_path") or args.get("notebook_path") or args.get("path") or ""
    short = lambda p: str(p).rstrip("/").rsplit("/", 1)[-1] or str(p)  # noqa: E731
    if name in ("Bash", "PowerShell", "BashOutput"):
        kakan = kakan_use(args.get("command")) if name != "BashOutput" else ""
        if kakan:
            return "kakan", kakan
        cmd = command_label(args.get("command")) or name
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
        if server == "kakan":
            return "kakan", f"Kakan · {tool}"
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
    """One transcript being followed – Claude Code's (the others below change entry() and what they are called)."""
    TOOL, CORE, TITLE, NAMES = "claude", "CLAUDE", "CLAUDE CODE", None
    ORDER = STATIONS

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

    # ── the same for every source (Codex and Kakan use these) ──
    def start_call(self, cid, st, label, t, src="core"):
        if cid in self.calls or cid in self.done_ids:
            return
        self.calls[cid] = {"st": st, "label": label, "start": t, "src": src, "bg": False}
        self.count[st] += 1
        self.go(st, t)
        self.pulse(st, "out", src)
        self.row(st, label, t, key=cid)["src"] = src

    def end_call(self, cid, t, err=False):
        call = self.calls.pop(cid, None)
        if not call:
            return
        self.done_ids.add(cid)
        if err:
            self.errors[call["st"]] += 1
        self.pulse(call["st"], "err" if err else "back", call["src"])
        self.finish_row(cid, t, "err" if err else "ok")

    def model_step(self, t, model=""):
        if model and model != self.model:
            if self.model:
                self.row("model", f"{short_model(self.model)} → {short_model(model)}", t, "switch", end=t)
                self.pulse("model", "switch")
            self.model = model
        self.count["model"] += 1
        self.pulse("model", "flash")
        self.busy = True

    def said(self, label, t):
        """Your message: the red dots go, a new turn starts."""
        self.drop_calls(t)
        self.count["you"] += 1
        for s in self.errors:
            self.errors[s] = 0
        self.go("you", t)
        self.pulse("you", "in")
        self.row("you", re.sub(r"\s+", " ", label), t, "ok", end=t)["fold"] = False
        self.busy = True
        self.turn_start = t

    def drop_calls(self, t):
        for cid in list(self.calls):
            self.finish_row(cid, t, "err")
            self.calls.pop(cid)

    def stopped(self, t, label="avbrutet"):
        self.drop_calls(t)
        self.busy = False
        self.row("you", label, t, "err", end=t)

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
        # Opus/Sonnet 5+ have 1M as standard without "[1m]" in the name (14 Nov: the map showed 24 % instead of 5 %)
        m = re.match(r"claude-(opus|sonnet)-(\d+)", str(self.model or ""))
        big = "[1m]" in str(self.model or "") or self.max_tokens > 200_000 or (m and int(m.group(2)) >= 5)
        return 1_000_000 if big else 200_000

    def state(self, now):
        running = [dict(st=c["st"], label=c["label"], since=c["start"], src=c["src"], bg=c["bg"])
                   for c in self.calls.values()]
        idle = now - self.last_write
        # A crash or a closed terminal leaves calls unanswered: after 15 min without a line they are let go
        if idle > 15 * 60:
            running, self.busy = [], False
        stations = {s: {"n": self.count[s], "err": self.errors[s],
                        "run": sum(1 for r in running if r["st"] == s)} for s in self.ORDER}
        stations["memory"]["hook"] = self.mem_hook
        rows = [{k: r.get(k) for k in ("st", "label", "start", "end", "state", "n", "took", "src")}
                for r in self.rows[-ROWS:]]
        now_line = (running[-1]["label"] if running else "tänker…" if self.busy else
                    "väntar på dig" if idle < ACTIVE_FOR else "ingen aktivitet")
        return {"tool": self.TOOL, "core": self.CORE, "title": self.TITLE, "names": self.NAMES, "order": self.ORDER,
                "session": self.id, "cwd": self.cwd, "folder": Path(self.cwd).name if self.cwd else "",
                "model": short_model(self.model), "context": round(100 * self.tokens / self.window()) if self.window() else 0,
                "busy": self.busy or bool(running), "running": running, "stations": stations, "rows": rows,
                "route": self.route, "events": self.events, "now": now_line, "agents":
                sum(1 for r in running if r["st"] == "agents") if self.TOOL != "kakan" else 0,
                "answered": self.answered, "idle": round(idle)}


# ── Codex (OpenAI's Claude Code, 13 Nov): ~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl ──

def codex_root():
    return Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex") / "sessions"


def codex_call(name, args):
    """A Codex tool call → (station, label)."""
    args = args if isinstance(args, dict) else {"input": args}
    if name in ("shell", "container.exec", "shell_command", "exec_command", "local_shell", "unified_exec"):
        cmd = args.get("command", args.get("cmd", ""))
        if isinstance(cmd, list):
            cmd = cmd[2] if len(cmd) >= 3 and Path(str(cmd[0])).name in ("bash", "sh", "zsh") \
                and cmd[1] in ("-lc", "-c") else " ".join(map(str, cmd))
        kakan = kakan_use(cmd)
        return ("kakan", kakan) if kakan else (shell_station(cmd), command_label(cmd) or name)
    if name == "apply_patch":
        files = re.findall(r"\*\*\* (?:Update|Add|Delete) File: (\S+)", str(args.get("input") or args.get("patch") or ""))
        return "files", "ändrar " + (", ".join(Path(f).name for f in files[:3]) if files else "filer")
    if name in ("read_file", "list_dir", "grep_files", "view_image"):
        return "files", {"read_file": "läser", "list_dir": "listar", "grep_files": "söker", "view_image": "tittar på"}[name] \
            + " " + Path(str(args.get("path") or args.get("file_path") or args.get("pattern") or "")).name
    if name in ("web_search", "web.run"):
        return "net", f"söker på nätet \"{args.get('query', '')}\""
    if name == "write_stdin":
        return "shell", "skriver till kommandot"
    if name == "update_plan":
        return "model", "planerar"
    if "__" in name or "." in name:
        server, _, tool = name.replace("__", ".").partition(".")
        return classify(f"mcp__{server}__{tool}", args)
    return "model", name


def codex_failed(output):
    """Did a Codex call fail? Its output is JSON ({output, metadata: {exit_code}}), {content, success} or text."""
    if isinstance(output, dict):
        if output.get("success") is False:
            return True
        output = output.get("content", "")
    text = str(output or "")
    try:
        d = json.loads(text)
        if isinstance(d, dict):
            code = (d.get("metadata") or {}).get("exit_code")
            return (code not in (None, 0)) or d.get("success") is False
    except ValueError:
        pass
    m = re.search(r"(?:Exit code|Process exited with code):?\s*(-?\d+)", text[:300])
    if m:
        return m.group(1) != "0"
    return bool(re.match(r"(?i)\s*(?:exec command rejected|aborted|error:)", text[:200]))


class CodexSession(Session):
    TOOL, CORE, TITLE = "codex", "CODEX", "CODEX"

    def __init__(self, path, quiet=True):
        super().__init__(path, quiet)
        self.context_window = 0

    def read(self):
        self.read_file(self.path, False)
        self.quiet = False

    def window(self):
        return self.context_window or 272_000

    def entry(self, d, side):
        t = epoch(d["timestamp"]) if d.get("timestamp") else time.time()
        kind, p = d.get("type"), d.get("payload")
        if not isinstance(p, dict):          # the older format: the items themselves, one per line
            p, kind = d, ("session_meta" if "instructions" in d and "id" in d else "response_item")
        if kind in ("session_meta", "turn_context"):
            self.cwd = p.get("cwd") or self.cwd
            if p.get("model") and p["model"] != self.model:
                if self.model:
                    self.model_step(t, p["model"])
                else:
                    self.model = p["model"]
        elif kind == "compacted":
            self.row("model", "kontexten komprimerad", t, "ok", end=t)
            self.pulse("model", "flash")
        elif kind == "event_msg":
            self.event(p, t)
        elif kind == "response_item":
            self.item(p, t)

    def event(self, p, t):
        e = p.get("type")
        if e == "user_message":
            text = str(p.get("message") or "").strip()
            if text and not text.startswith("<"):
                self.said(text, t)
        elif e == "token_count":
            info = p.get("info") or {}
            last = info.get("last_token_usage") or {}
            used = int(last.get("input_tokens") or 0) + int(last.get("output_tokens") or 0)
            if used:
                self.tokens = used
            self.context_window = int(info.get("model_context_window") or self.context_window or 0)
        elif e == "task_started":
            self.context_window = int(p.get("model_context_window") or self.context_window or 0)
            self.busy = True
        elif e == "task_complete":
            self.drop_calls(t)
            self.end_turn(t)
        elif e == "turn_aborted":
            self.stopped(t)

    def item(self, p, t):
        it = p.get("type")
        if it == "reasoning" or (it == "message" and p.get("role") == "assistant"):
            self.model_step(t)
        elif it in ("function_call", "custom_tool_call"):
            raw = p.get("arguments") if it == "function_call" else p.get("input")
            try:
                args = json.loads(raw) if isinstance(raw, str) and it == "function_call" else raw
            except ValueError:
                args = {"input": raw}
            st, label = codex_call(str(p.get("name") or ""), args if isinstance(args, dict) else {"input": args})
            self.start_call(p.get("call_id") or p.get("id"), st, label, t)
        elif it == "local_shell_call":
            cmd = ((p.get("action") or {}).get("command")) or []
            st, label = codex_call("shell", {"command": cmd})
            self.start_call(p.get("call_id") or p.get("id"), st, label, t)
        elif it == "web_search_call":
            q = ((p.get("action") or {}).get("query")) or ""
            cid = p.get("id") or f"ws-{t}"
            self.start_call(cid, "net", f"söker på nätet \"{q}\"" if q else "söker på nätet", t)
            self.end_call(cid, t)
        elif it in ("function_call_output", "custom_tool_call_output"):
            self.end_call(p.get("call_id"), t, codex_failed(p.get("output")))


# ── Kakan (Goblin AI, 13 Nov): ~/.local/state/goblincakes/kakan-karta.jsonl, written by goblinai.kakan_log ──

KAKAN_LOG = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "goblincakes/kakan-karta.jsonl"
KAKAN_TOOLS = {"sök": "net", "sida": "net", "sport": "net", "wiki": "net",
               "warcraftlogs": "browser", "wowstats": "browser", "cs2": "browser", "wowapi": "browser",
               "wowfel": "browser", "systemfel": "agents", "lagg": "agents", "byggstatus": "agents",
               "goblincakes": "agents", "leta": "agents", "skrivbord": "skills", "kalender": "skills",
               "byt": "files", "kommando": "shell", "losningar": "memory", "rapporter": "memory"}
KAKAN_TEXT = [(r"^(Kontrollerar|Kollar|Samma sak igen|Slutar hämta)", "hooks"),
              (r"^(Söker på nätet|Läser webbsidan|Slår upp på Wikipedia)", "net"),
              (r"^Letar i datorn", "agents"), (r"^(Läser filerna|Läser i delar|Byter text)", "files"),
              (r"^(Kalendern|Skriver kalenderraden)", "skills"), (r"WoW|tillägget|Warcraft|CS2", "browser"),
              (r"(?i)minne|lärdom", "memory")]


def kakan_station(tool, text):
    if tool in KAKAN_TOOLS:
        return KAKAN_TOOLS[tool]
    for pattern, st in KAKAN_TEXT:
        if re.search(pattern, text or ""):
            return st
    return "model"


class KakanSession(Session):
    TOOL, CORE, TITLE = "kakan", "KAKAN", "KAKAN"
    ORDER = [s for s in STATIONS if s != "kakan"]
    NAMES = {"you": "DU", "model": "MODELL", "memory": "MINNE", "files": "FILER", "shell": "KOMMANDON",
             "net": "NÄTET", "browser": "SPEL", "agents": "DATORN", "skills": "SKRIVBORDET", "hooks": "KONTROLL"}

    def __init__(self, path, quiet=True):
        super().__init__(path, quiet)
        self.id = "kakan"
        self.cwd = ""
        self.project = ""

    def read(self):
        self.read_file(self.path, False)
        self.quiet = False

    def window(self):
        return 0                       # her context is not counted here

    def entry(self, d, side):
        t, e = float(d.get("t") or time.time()), d.get("e")
        if e == "user":
            self.project = d.get("project") or ""
            self.said(d.get("text") or "fråga", t)
        elif e == "model":
            model = str(d.get("model") or "")
            self.model_step(t, model + (" · din dator" if d.get("local") else f" · {d.get('service')}" if d.get("service") else ""))
        elif e == "start":
            st = kakan_station(d.get("tool") or "", d.get("text") or "")
            self.start_call(d.get("id"), st, d.get("text") or st, t)
        elif e == "end":
            self.end_call(d.get("id"), t, d.get("state") in ("fel", "stopp"))
        elif e == "answer":
            self.drop_calls(t)
            self.end_turn(t)
        elif e == "stopped":
            self.stopped(t, "stoppat")
        elif e == "failed":
            self.stopped(t, "gick inte – ingen tjänst svarade")

    def state(self, now):
        out = super().state(now)
        out["folder"] = self.project or "Goblin AI"
        out["model"] = self.model
        return out


class Watcher:
    """Picks the session to show and keeps it read – Claude Code's, Codex's or Kakan's, the newest going on.
    prefer_cwd: the folder Claude Code/Codex runs in, in the terminal tab shown (Goblin AI) – its session first."""
    KINDS = {"claude": Session, "codex": CodexSession, "kakan": KakanSession}

    def __init__(self, root=None, codex=None, kakan=None):
        self.root = Path(root) if root else projects_dir()
        self.codex = Path(codex) if codex else codex_root()
        self.kakan = Path(kakan) if kakan else KAKAN_LOG
        self.sessions = {}
        self.pick = ""            # a session chosen by hand (the chips over the map)
        self.scanned = 0.0
        self.found = []
        self.cwds = {}

    @staticmethod
    def sid(path, kind):
        return "kakan" if kind == "kakan" else path.stem

    def files(self):
        """Every session file there is: (path, kind)."""
        out = []
        try:
            out += [(f, "claude") for f in self.root.glob("*/*.jsonl")]
        except OSError:
            pass
        try:   # the last three days' folders (YYYY/MM/DD) – months of sessions would be slow to look through
            days = sorted(d for d in self.codex.glob("*/*/*") if d.is_dir())[-3:]
            out += [(f, "codex") for d in days for f in d.glob("rollout-*.jsonl")]
        except OSError:
            pass
        if self.kakan.is_file():
            out.append((self.kakan, "kakan"))
        return out

    def scan(self, now):
        if now - self.scanned < 3 and self.found:
            return self.found
        self.scanned = now
        stamped = []
        for f, kind in self.files():
            try:
                stamped.append((f.stat().st_mtime, f, kind))
            except OSError:
                continue
        out = [x for x in stamped if now - x[0] < ACTIVE_FOR or self.sid(x[1], x[2]) == self.pick]
        if not out and stamped:   # nothing going on: the newest at all, so the map shows the last session
            out = [max(stamped, key=lambda x: x[0])]
        self.found = sorted(out, key=lambda x: x[0], reverse=True)
        return self.found

    def folder_of(self, path, kind="claude"):
        """The session's folder, from the cwd its lines carry (cached; the folder name in projects/ is lossy)."""
        if kind == "kakan":
            return ""
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
            for x in found:
                if self.sid(x[1], x[2]) == self.pick:
                    return x
        if prefer_cwd:
            want = prefer_cwd.rstrip("/")
            for x in found:
                if x[2] != "kakan" and (self.folder_of(x[1], x[2]).rstrip("/") == want
                                        or (x[2] == "claude" and x[1].parent.name == folder_key(want))):
                    return x
        return found[0] if found else None

    def state(self, prefer_cwd=""):
        now = time.time()
        found = self.scan(now)
        chosen = self.choose(found, prefer_cwd)
        if chosen is None:
            return {"none": True, "sessions": []}
        _, path, kind = chosen
        s = self.sessions.get(path)
        if s is None:
            s = self.sessions[path] = self.KINDS[kind](path)
        s.read()
        for other in list(self.sessions):      # sessions no longer shown are forgotten
            if other != path and other not in {x[1] for x in found}:
                del self.sessions[other]
        out = s.state(now)
        if kind != "kakan":
            out["cwd"] = self.folder_of(path, kind) or out["cwd"]   # the folder it was started in (not where it cd'd)
            out["folder"] = Path(out["cwd"]).name if out["cwd"] else path.parent.name
        names = {"claude": "", "codex": "codex · ", "kakan": ""}
        out["sessions"] = [{"id": self.sid(f, k), "tool": k,
                            "folder": "Kakan" if k == "kakan" else names[k] + (Path(self.folder_of(f, k)).name or f.parent.name),
                            "active": now - m < 120, "on": f == path} for m, f, k in found[:6]]
        out["picked"] = bool(self.pick)
        return out


if __name__ == "__main__":
    print(json.dumps(Watcher().state(sys.argv[1] if len(sys.argv) > 1 else ""), ensure_ascii=False, indent=1))
