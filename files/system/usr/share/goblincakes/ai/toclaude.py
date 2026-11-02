"""Skicka till Claude (point 14 of Kakan's plan, 28 Oct): what Kakan couldn't solve becomes a report for Claude Code.

The report is put together from the chat itself – the questions, Kakan's answers, her steps, what her tools showed
and the commands she ran with their output – so nothing in it is made up. It is saved as Markdown in
~/.local/share/goblincakes/till-claude/ (never sent anywhere by itself: it can hold logs and names).

Two ways on (the user's choice, 28 Oct):
  fix   Claude Code in a terminal, in the GOBLINCAKES repo, with the report as its task – the user sees it work
        and approves changes as usual.
  ask   Claude Code without a window (claude -p), only allowed to read – the answer comes back into the chat.
Either one costs from the week's Claude quota, so it only ever starts on the user's own click.

Claude Code reads the reports with the MCP tool `rapporter` (kakan_mcp.py) as well.

Who gets it (2 Nov, the user: "for those who use ChatGPT"): Claude Code, OpenAI's Codex or an own command –
Goblin AI → Inställningar → Skicka vidare (~/.config/goblincakes/ai-helper.json). The name stays toclaude.py.
"""
import json
import os
import re
import shutil
import subprocess
from datetime import datetime
from pathlib import Path

FOLDER = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share") / "goblincakes/till-claude"
SOLUTIONS = Path(__file__).resolve().parent / "solutions.py"  # Claude Code saves what it fixed as a known solution
OUTPUT_CHARS = 4000  # of each command's output in the report
TOOL_CHARS = 3000    # of each tool's answer (kept with the answer as "report_done")
KEEP = 12            # messages back from the one sent
FILE_LINES = 400     # of each file she read, numbered in the report (2 Nov: Claude needn't look for them again)
FILES_MAX = 4
FILE_SUFFIXES = {".lua", ".toc", ".xml", ".py", ".sh", ".js", ".qml", ".json", ".css", ".html", ".conf", ".ini",
                 ".cfg", ".txt", ".md", ".desktop", ".service", ".yml", ".yaml", ".toml"}
ASK_TOOLS = "Read,Grep,Glob"  # "Fråga bara": Claude reads, never changes
ASK_SECONDS = 600
MODEL = "sonnet"     # the user, 28 Oct: Opus is more than Kakan's problems need; Haiku loses its way across several parts
SETTINGS = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "goblincakes/ai-helper.json"
NAMES = {"claude": "Claude", "codex": "Codex", "egen": "eget program"}
PROGRAMS = {"claude": "Claude Code", "codex": "Codex", "egen": "Ditt program"}


def claude_path():
    """Claude Code on this computer, or None (the buttons are hidden then)."""
    found = shutil.which("claude") or str(Path.home() / ".local/bin/claude")
    return found if Path(found).is_file() else None


def codex_path():
    """OpenAI's Codex (its installer puts it in ~/.local/bin), or None."""
    found = shutil.which("codex") or str(Path.home() / ".local/bin/codex")
    return found if Path(found).is_file() else None


def settings():
    try:
        data = json.loads(SETTINGS.read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def save_settings(**changes):
    data = {**settings(), **changes}
    SETTINGS.parent.mkdir(parents=True, exist_ok=True)
    SETTINGS.write_text(json.dumps(data, ensure_ascii=False))


def installed(helper):
    if helper == "claude":
        return claude_path() is not None
    if helper == "codex":
        return codex_path() is not None
    return helper == "egen" and bool(settings().get("command", "").strip())


def current(wanted=""):
    """The helper to use: the one asked for (when it is there), else the chosen one, else the first installed –
    "" when there is none (the buttons are hidden)."""
    for helper in (wanted, settings().get("helper", ""), "claude", "codex"):
        if helper in NAMES and installed(helper):
            return helper
    return ""


def _cut(text, chars):
    text = str(text or "").strip()
    return text if len(text) <= chars else text[:chars] + "\n[… avkortat]"


def _fence(text):
    return "````\n" + text + "\n````"


def _title(text):
    words = re.sub(r"[^\wåäöÅÄÖ ]+", " ", text).split()[:6]
    return " ".join(words) or "rapport"


def files_read(chat, question):
    """The files she read (las_fil / leta läs, wowapi kolla <tillägg>) and the paths in the question – as they are
    now, numbered: Claude starts from them instead of finding and reading them again (2 Nov, the user: as little
    of Claude's quota as possible when Kakan has done her part)."""
    paths = re.findall(r"(?:~|/(?:home|var|run|usr|etc|opt|tmp))/[^\s\"'`<>|]+", question)
    for m in chat:
        for tool, query in (t[:2] for t in m.get("tools") or [] if isinstance(t, (list, tuple)) and len(t) >= 2):
            q = str(query).strip()
            if tool == "leta" and q.startswith(("läs ", "las ")):
                paths.append(q.split(" ", 1)[1])
            elif tool == "wowapi" and q.startswith("kolla ") and len(q) > 6:
                paths.append(q.split(" ", 1)[1])
    files = []
    for raw in paths:
        p = Path(os.path.expanduser(raw.strip().strip("'\"").rstrip(".,:;)")))
        found = sorted(f for f in p.iterdir() if f.is_file() and f.suffix.lower() in FILE_SUFFIXES)[:6] \
            if p.is_dir() else [p] if p.is_file() else []
        for f in found:
            if f.resolve() not in (x.resolve() for x in files):
                files.append(f)
    out = []
    for f in files[:FILES_MAX]:
        try:
            rows = f.read_text(errors="replace").splitlines()
        except OSError:
            continue
        shown = "\n".join(f"{n:4}  {row}" for n, row in enumerate(rows[:FILE_LINES], 1))
        more = f"\n[… {len(rows) - FILE_LINES} rader till]" if len(rows) > FILE_LINES else ""
        out += ["", f"### {f.resolve()}", _fence(shown + more)]
    return out


def build(display, index, info=""):
    """The report for the answer at display[index], with the messages before it (the last KEEP) – Markdown."""
    chat = display[max(0, index - KEEP + 1):index + 1]
    # The user's own question – not an answer to a test point (it was "ja", 28 Oct); a test run without one is
    # named after its first message (the list's title)
    question = next((m.get("text", "") for m in reversed(display[:index + 1])
                     if m.get("role") == "user" and not m.get("test")), "")
    if not question:
        first = next((m for m in chat if m.get("service") == "Testa åt Claude"), display[index])
        question = re.sub(r"[*]", "", (first.get("text") or "").split("\n", 1)[0]).split(" – ")[0]
    out = [f"# Kakans rapport: {_title(question)}",
           f"{datetime.now():%Y-%m-%d %H:%M} – från Goblin AI (Skicka till Claude). Kakan kunde inte lösa det här "
           "själv; allt nedan är hämtat ur samtalet, inget är skrivet i efterhand.",
           "", "## Frågan", question.strip() or "(ingen fråga hittades)"]
    if info:
        out += ["", "## Datorn", info.strip()]
    files = files_read(chat, question)
    if files:
        out += ["", "## Filerna hon läste (som de ser ut nu, med radnummer)"] + files
    out += ["", "## Samtalet"]
    for m in chat:
        role = m.get("role")
        if role == "user":
            out += ["", "### Användaren", (m.get("text") or "").strip()]
        elif role == "error":
            out += ["", "### Fel i Goblin AI", (m.get("text") or "").strip()]
        elif role == "assistant":
            out += ["", f"### Kakan ({m.get('service') or 'okänd modell'})", (m.get("text") or "").strip()]
            steps = m.get("steps") or []
            if steps:
                out += ["", "**Hennes steg:**"]
                out += [f"- {s.get('text', '')} – {s.get('state', '')}"
                        + (f" ({s['note']})" if s.get("note") else "") + (f", {s['secs']} s" if s.get("secs") else "")
                        for s in steps]
            done = m.get("report_done") or m.get("done") or []
            if done:
                out += ["", "**Verktygen hon använde och vad de visade:**"]
                for tool, query, text in (d if isinstance(d, (list, tuple)) else (d, "", "") for d in done):
                    out += ["", f"- `{tool}` {query}".rstrip()]
                    if text:
                        out.append(_fence(_cut(text, TOOL_CHARS)))
            cmds = [s for s in m.get("segments") or [] if s.get("type") in ("command", "blocked")]
            if cmds:
                out += ["", "**Kommandon:**"]
                for s in cmds:
                    state = {"done": f"kördes (avslutskod {s.get('code_result', '?')})", "skipped": "hoppades över",
                             "blocked": "STOPPAT – " + s.get("why", "går inte att ångra"),
                             "new": "kördes inte", "running": "körs fortfarande"}.get(s.get("state"), s.get("state", ""))
                    out += ["", f"`$ {s.get('code', '')}` – {state}"]
                    if s.get("output"):
                        out.append(_fence(_cut(s["output"], OUTPUT_CHARS)))
            r = m.get("receipt")
            if r:  # punkt 23: counted from the tools and cards, not from her words
                out += ["", f"**Kvitto:** {r.get('line', '')}"
                        + (f" – klart-kontrollen: {r['verdict']}" if r.get("verdict") else "")]
    return "\n".join(out).strip() + "\n"


def save(markdown):
    """The report as a file in FOLDER; returns its path."""
    FOLDER.mkdir(parents=True, exist_ok=True)
    head = markdown.split("\n", 1)[0].replace("# Kakans rapport:", "")
    name = re.sub(r"\s+", "-", head.strip().lower())[:50].strip("-") or "rapport"
    path = FOLDER / f"{datetime.now():%Y-%m-%d-%H%M}-{name}.md"
    path.write_text(markdown, encoding="utf-8")
    return path


def task(path, mode, helper="claude"):
    """What Claude Code (or Codex, or the user's own program) is asked."""
    tools = "Kakans MCP-verktyg finns – losningar visar om det hänt förut" if helper == "claude" else (
        f"python3 {SOLUTIONS} list visar om det hänt förut")
    if mode == "ask":
        return (f"Kakan (GOBLINCAKES lokala AI) kunde inte lösa ett problem. Läs hennes rapport {path} (hennes analys "
                "är en ledtråd, inte facit – filerna hon läste står i den med radnummer) och svara på "
                "svenska, kort och utan jargong för en användare som inte är programmerare: vad är troligen fel, och "
                "vad ska användaren göra? Du får bara läsa – ändra inget. Behövs en "
                f"ändring i datorn eller i GOBLINCAKES kod: säg vad, så tar användaren det i {PROGRAMS[helper]}. Är du säker "
                "på orsak och lösning: avsluta svaret med ett kodblock märkt ```löst med tre rader – \"Tecken: <vad "
                "användaren märkte>\", \"Orsak: <vad som är fel>\", \"Lösning: <vad som ska göras>\" – då sparas det "
                "som en känd lösning åt Kakan (ej bekräftad tills den fungerat). Är du osäker: inget sådant block.")
    return (f"Kakan (GOBLINCAKES lokala AI) kunde inte lösa ett problem och skickade det till dig. Läs hennes rapport "
            f"{path}, ta reda på vad som är fel ({tools}) och lös det. Hennes analys är en ledtråd, inte facit – "
            "kontrollera varje påstående själv; användarens egen beskrivning av vad som händer är det säkraste. "
            "Filerna hon läste står i rapporten med radnummer: börja där i stället för att leta upp och läsa dem "
            "igen, och läs bara vidare när det behövs. Två fall:\n"
            "1. Felet är bara på den här datorn (ett WoW-tillägg, en inställning, ett program, en fil i hemmappen): "
            "rätta det där. Rör INTE repot – ingen commit, ingen push, ingen rad i Kakans karta.\n"
            "2. Felet är i GOBLINCAKES egen kod: rätta koden i repot enligt CLAUDE.md (projektets regler). Är det "
            "något Kakan borde känna igen nästa gång: en kort rad (tecken på felet → vad som är fel → vad hon ska "
            "göra) i den delens ##-avsnitt i hennes karta, files/system/usr/share/goblincakes/ai/karta.md.\n"
            "Skriv bara det du har kontrollerat (t.ex. med wowapi eller i filen) – inga gissningar om att något "
            "\"inte finns\". I båda fallen: spara lösningen som en känd lösning, så att Kakan känner igen den på den "
            f"här datorn: python3 {SOLUTIONS} add --tecken \"<vad användaren märkte, med hens ord>\" --orsak \"<vad som "
            "var fel>\" --losning \"<vad som gjordes>\" (lägg till --bekraftad bara om du provat att det fungerar "
            "nu). Säg sedan kort vad det var, om repot ändrades (och vad) och att lösningen är sparad.")


def fix_command(path, helper=""):
    """The helper with the report as its task – for a TERMINAL tab in Goblin AI (2 Nov) or a terminal of its own.
    "" when there is none."""
    helper = current(helper)
    job = _quote(task(path, "fix", helper))
    if helper == "claude":
        return f"{_quote(claude_path())} --model {MODEL} {job}"
    if helper == "codex":
        return f"{_quote(codex_path())} {job}"
    if helper == "egen":
        return f"{settings()['command'].strip()} {job}"
    return ""


def start_fix(path, repo=None, helper=""):
    """The helper in the user's terminal, in the repo (else the home folder). False if it couldn't start."""
    command = fix_command(path, helper)
    if not command:
        return False
    folder = str(repo or Path.home())
    script = f"cd {_quote(folder)} && {command}; exec bash"
    try:
        subprocess.Popen(["/usr/libexec/goblincakes-terminal", "run", "bash", "-c", script],
                         start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except OSError:
        return False


def ask(path, repo=None, helper=""):
    """Fråga bara: the helper without a window, read-only. Returns its answer (raises RuntimeError)."""
    helper = current(helper)
    folder = str(repo or Path.home())
    last = None
    if helper == "claude":
        cmd = [claude_path(), "-p", task(path, "ask", helper), "--model", MODEL, "--tools", ASK_TOOLS,
               "--allowedTools", f"{ASK_TOOLS},mcp__kakan", "--add-dir", str(FOLDER)]
    elif helper == "codex":
        # read-only sandbox; its last message to a file – stdout has the whole run (2 Nov)
        last = FOLDER / f".codex-svar-{os.getpid()}.txt"
        cmd = [codex_path(), "exec", "-s", "read-only", "--skip-git-repo-check", "--ephemeral", "-C", folder,
               "-o", str(last), task(path, "ask", helper)]
    else:
        raise RuntimeError("Fråga finns bara för Claude Code och Codex")
    try:
        done = subprocess.run(cmd, cwd=folder, capture_output=True, text=True,
                              timeout=ASK_SECONDS, stdin=subprocess.DEVNULL)
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"{NAMES[helper]} svarade inte på {ASK_SECONDS // 60} minuter") from None
    answer = done.stdout.strip()
    if last:
        try:
            answer = last.read_text(encoding="utf-8").strip()
            last.unlink()
        except OSError:
            answer = ""
    if done.returncode or not answer:
        raise RuntimeError(_cut(done.stderr or answer or f"avslutskod {done.returncode}", 400))
    return answer


def _quote(text):
    return "'" + str(text).replace("'", "'\\''") + "'"


# ── For Claude Code (kakan_mcp.py: the tool `rapporter`) ─────────────────

def reports():
    return sorted(FOLDER.glob("*.md"), reverse=True)


def read(query=""):
    """Empty: the list (newest first) and the newest one in full; a name or a part of it: that report."""
    found = reports()
    if not found:
        return f"Inga rapporter från Kakan ännu ({FOLDER})."
    query = query.strip().lower()
    if query and query not in ("senaste", "nyaste", "latest"):
        hit = next((p for p in found if query in p.name.lower()), None)
        if not hit:
            return "Ingen rapport heter så. Rapporterna:\n" + "\n".join(p.name for p in found[:30])
        return f"{hit}\n\n{hit.read_text(encoding='utf-8')}"
    listing = "\n".join(f"- {p.name}" for p in found[:30])
    return (f"Kakans rapporter i {FOLDER} (nyast först):\n{listing}\n\n--- Den senaste: {found[0]} ---\n\n"
            + found[0].read_text(encoding="utf-8"))
