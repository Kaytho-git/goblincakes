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
"""
import os
import re
import shutil
import subprocess
from datetime import datetime
from pathlib import Path

FOLDER = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share") / "goblincakes/till-claude"
OUTPUT_CHARS = 4000  # of each command's output in the report
TOOL_CHARS = 3000    # of each tool's answer (kept with the answer as "report_done")
KEEP = 12            # messages back from the one sent
ASK_TOOLS = "Read,Grep,Glob"  # "Fråga bara": Claude reads, never changes
ASK_SECONDS = 600
MODEL = "sonnet"     # the user, 28 Oct: Opus is more than Kakan's problems need; Haiku loses its way across several parts


def claude_path():
    """Claude Code on this computer, or None (the buttons are hidden then)."""
    found = shutil.which("claude") or str(Path.home() / ".local/bin/claude")
    return found if Path(found).is_file() else None


def _cut(text, chars):
    text = str(text or "").strip()
    return text if len(text) <= chars else text[:chars] + "\n[… avkortat]"


def _fence(text):
    return "````\n" + text + "\n````"


def _title(text):
    words = re.sub(r"[^\wåäöÅÄÖ ]+", " ", text).split()[:6]
    return " ".join(words) or "rapport"


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
    return "\n".join(out).strip() + "\n"


def save(markdown):
    """The report as a file in FOLDER; returns its path."""
    FOLDER.mkdir(parents=True, exist_ok=True)
    head = markdown.split("\n", 1)[0].replace("# Kakans rapport:", "")
    name = re.sub(r"\s+", "-", head.strip().lower())[:50].strip("-") or "rapport"
    path = FOLDER / f"{datetime.now():%Y-%m-%d-%H%M}-{name}.md"
    path.write_text(markdown, encoding="utf-8")
    return path


def task(path, mode):
    """What Claude Code is asked."""
    if mode == "ask":
        return (f"Kakan (GOBLINCAKES lokala AI) kunde inte lösa ett problem. Läs hennes rapport {path} och svara på "
                "svenska, kort och utan jargong för en användare som inte är programmerare: vad är troligen fel, och "
                "vad ska användaren göra? Du får bara läsa (filer och Kakans MCP-verktyg) – ändra inget. Behövs en "
                "ändring i datorn eller i GOBLINCAKES kod: säg vad, så tar användaren det i Claude Code.")
    return (f"Kakan (GOBLINCAKES lokala AI) kunde inte lösa ett problem och skickade det till dig. Läs hennes rapport "
            f"{path}, ta reda på vad som är fel (Kakans MCP-verktyg finns) och lös det: är felet i GOBLINCAKES, rätta "
            "koden i repot enligt CLAUDE.md; är det bara på den här datorn, rätta det där. Är det något Kakan borde "
            "känna igen nästa gång och det gäller en del av GOBLINCAKES: skriv en kort rad (tecken på felet → vad "
            "som är fel → vad hon ska göra) i den delens ##-avsnitt i hennes karta, "
            "files/system/usr/share/goblincakes/ai/karta.md i repot – hon läser kartan (den nya raden efter nästa "
            "image). Säg sedan kort vad det var och vilken rad du lade i kartan (eller att ingen behövdes).")


def start_fix(path, repo=None):
    """Claude Code in the user's terminal, in the repo (else the home folder). False if it couldn't start."""
    claude = claude_path()
    if not claude:
        return False
    folder = str(repo or Path.home())
    script = f"cd {_quote(folder)} && {_quote(claude)} --model {MODEL} {_quote(task(path, 'fix'))}; exec bash"
    try:
        subprocess.Popen(["/usr/libexec/goblincakes-terminal", "run", "bash", "-c", script],
                         start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except OSError:
        return False


def ask(path, repo=None):
    """Fråga bara: Claude Code without a window, read-only. Returns its answer (raises RuntimeError)."""
    claude = claude_path()
    if not claude:
        raise RuntimeError("Claude Code finns inte på datorn")
    cmd = [claude, "-p", task(path, "ask"), "--model", MODEL, "--tools", ASK_TOOLS,
           "--allowedTools", f"{ASK_TOOLS},mcp__kakan", "--add-dir", str(FOLDER)]
    try:
        done = subprocess.run(cmd, cwd=str(repo or Path.home()), capture_output=True, text=True,
                              timeout=ASK_SECONDS, stdin=subprocess.DEVNULL)
    except subprocess.TimeoutExpired:
        raise RuntimeError(f"Claude svarade inte på {ASK_SECONDS // 60} minuter") from None
    answer = done.stdout.strip()
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
