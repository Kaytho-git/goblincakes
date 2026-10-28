"""Testa åt Claude (point 15 of Kakan's plan, 28 Oct): Claude leaves a test list, Kakan runs it and reports back.

Claude Code writes the lists – what it couldn't try on the real computer – as Markdown in
~/.local/share/goblincakes/testlistor/<name>.md:

    # Efter nästa image
    - Lagmätartjänsten finns i imagen
      kör: systemctl --user cat goblincakes-lagmeter.service
      väntat: filen ligger under /usr/lib/systemd/user
    - Graffönstret
      fråga: Tryck Meta+Shift+L medan WoW kör. Syns graferna på den andra skärmen?

One "- " line per point (its title), then `kör:` (a command – or a ```bash block under the point), `väntat:` (what
the output should show; without it the exit code decides) or `fråga:` (something only the user can see).

In Goblin AI: /testa (the newest list), /testa <name>, /testa stopp. Each point is a message in the chat with the
usual command card – reading commands run at once, changing ones wait for Tillåt, dangerous ones are stopped –
and Kakan judges the output against `väntat` (OK / FEL / OKLART). A `fråga` is answered in the chat (ja / nej /
hoppa, or what the user sees). The result, with every command's raw output beside her judgement, is saved in
toclaude.FOLDER (Claude reads it with the MCP tool `rapporter`); the list moves to testlistor/klara/.
"""
import os
import re
from datetime import datetime
from pathlib import Path

import toclaude

FOLDER = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share") / "goblincakes/testlistor"
DONE = FOLDER / "klara"
OUTPUT_CHARS = 3000  # of each output in the result (and what Kakan reads to judge)
VERDICTS = ("OK", "FEL", "OKLART", "HOPPADES ÖVER", "STOPPAT", "EJ TESTAD")
YES = ("ja", "j", "japp", "jo", "yes", "y", "ok", "funkar", "stämmer", "syns")
NO = ("nej", "n", "no", "nope", "funkar inte", "syns inte")
SKIP = ("hoppa", "hoppa över", "skip", "vet inte", "-")


def lists():
    """The lists waiting to be run, newest first."""
    return sorted(FOLDER.glob("*.md"), key=lambda p: p.stat().st_mtime, reverse=True)


def find(name=""):
    """The list to run: the newest, or the one whose file name has `name` in it. None if there is none."""
    found = lists()
    name = name.strip().lower()
    if not name:
        return found[0] if found else None
    return next((p for p in found if name in p.stem.lower()), None)


def parse(text):
    """{"title", "items": [{"title", "run", "expect", "ask"}]}."""
    title, items, fence = "", [], None
    for line in text.replace("\r", "").split("\n"):
        stripped = line.strip()
        if fence is not None:  # inside a ```bash block: the point's command
            if stripped.startswith("```"):
                items[-1]["run"] = "\n".join(fence).strip()
                fence = None
            else:
                fence.append(line.strip() if not line.startswith("      ") else line[6:])
            continue
        if m := re.match(r"^#\s+(.+)", stripped):
            title = title or m.group(1).strip()
        elif m := re.match(r"^[-*]\s+(?:\[[ x]\]\s*)?(.+)", line):  # a point – only at the left edge
            items.append({"title": m.group(1).strip(), "run": "", "expect": "", "ask": ""})
        elif items and (m := re.match(r"^(kör|kor|run|väntat|vantat|expect|fråga|fraga|ask)\s*:\s*(.*)$",
                                      stripped, re.I)):
            key = {"k": "run", "r": "run", "v": "expect", "e": "expect", "f": "ask", "a": "ask"}[m.group(1)[0].lower()]
            items[-1][key] = (items[-1][key] + " " + m.group(2).strip()).strip()
        elif items and stripped.startswith("```"):
            fence = []
        elif items and stripped and not items[-1]["run"] and not items[-1]["expect"] and not items[-1]["ask"]:
            items[-1]["title"] += " " + stripped  # the title went on to the next line
    return {"title": title, "items": items}


def load(path):
    data = parse(Path(path).read_text(encoding="utf-8"))
    data["title"] = data["title"] or Path(path).stem
    return data


def from_answer(text):
    """The user's answer to a `fråga` → (verdict, note)."""
    said = " ".join(text.lower().split()).strip(" .!")
    if said in YES or re.match(r"^(ja|japp|yes)\b", said):
        return "OK", text.strip() if said not in YES else ""
    if said in NO or re.match(r"^(nej|no)\b", said):
        return "FEL", text.strip() if said not in NO else ""
    if said in SKIP:
        return "HOPPADES ÖVER", ""
    return "OKLART", text.strip()  # what they saw, in their own words – Claude reads it


def from_exit(state, exit_code, output):
    """A point without `väntat`: the card's state and exit code decide."""
    if state == "skipped":
        return "HOPPADES ÖVER", "användaren valde att inte köra det"
    if state == "blocked":
        return "STOPPAT", "går inte att ångra – kördes inte"
    if "(i ett terminalfönster)" in (output or "") or exit_code in (None, "?"):
        return "OKLART", "kördes i ett terminalfönster – utdata syns inte här"
    return ("OK", "") if exit_code == 0 else ("FEL", f"avslutskod {exit_code}")


def judge_messages(item, code, exit_code, output):
    """What Kakan is asked to judge a point with `väntat` – one short answer, no tools."""
    out = toclaude._cut(output, OUTPUT_CHARS) or "(ingen utdata)"
    return [{"role": "system", "content":
             "Du bedömer en testpunkt åt Claude. Jämför kommandots utdata med det som var väntat. Svara med en enda "
             "rad: först OK, FEL eller OKLART, sedan ett tankstreck och en kort mening om varför (citera det i utdatan "
             "som avgör). OK = utdatan visar det väntade. FEL = den visar något annat eller ett fel. OKLART = det går "
             "inte att avgöra av utdatan. Hitta inte på något som inte står där."},
            {"role": "user", "content": f"Testpunkt: {item['title']}\nVäntat: {item['expect']}\n\n"
                                        f"$ {code}\n(avslutskod {exit_code})\n{out}"}]


def verdict_of(answer):
    """Kakan's judgement line → (verdict, note); OKLART when she didn't start with one."""
    line = next((l.strip() for l in (answer or "").splitlines() if l.strip()), "")
    line = re.sub(r"^[*_#\s]+", "", line)
    m = re.match(r"^(OKLART|OK|FEL)\b[*_\s]*[–—:\-.]*\s*(.*)$", line, re.I)
    if not m:
        return "OKLART", ("hennes svar: " + line)[:300]
    return m.group(1).upper(), m.group(2).strip()[:300]


def result_markdown(data, results, path, stopped=False):
    """The result for Claude: a table first, then each point with what was run and its raw output."""
    counts = {v: sum(1 for r in results if r["verdict"] == v) for v in VERDICTS}
    summary = ", ".join(f"{n} {v}" for v, n in counts.items() if n)
    out = [f"# Testresultat: {data['title']}",
           f"{datetime.now():%Y-%m-%d %H:%M} – Kakan körde testlistan {Path(path).name} åt Claude"
           + (" (stoppad innan den var klar)" if stopped else "") + f". {summary}.",
           "", "| # | Punkt | Resultat | Varför |", "|---|---|---|---|"]
    for n, r in enumerate(results, 1):
        note = (r.get("note") or "").replace("|", "/").replace("\n", " ")
        out.append(f"| {n} | {r['item']['title'].replace('|', '/')} | {r['verdict']} | {note} |")
    for n, r in enumerate(results, 1):
        item = r["item"]
        out += ["", f"## {n}. {item['title']} – {r['verdict']}"]
        if item["expect"]:
            out.append(f"Väntat: {item['expect']}")
        if item["ask"]:
            out.append(f"Frågan: {item['ask']}")
            if r.get("answer"):
                out.append(f"Användaren svarade: {r['answer']}")
        if item["run"]:
            ran = f"avslutskod {r['exit']}" if r.get("exit") is not None else "kördes inte"
            out += ["", f"`$ {item['run']}` ({ran})"]
            if r.get("output"):
                out.append("````\n" + toclaude._cut(r["output"], OUTPUT_CHARS) + "\n````")
        if r.get("note"):
            out.append(f"Bedömning: {r['note']}")
    return "\n".join(out).strip() + "\n"


def save_result(data, results, path, stopped=False):
    """The result into toclaude.FOLDER; the list moves to klara/ (when it ran to the end). Returns the result's path."""
    markdown = result_markdown(data, results, path, stopped)
    toclaude.FOLDER.mkdir(parents=True, exist_ok=True)
    name = re.sub(r"[^\wåäö-]+", "-", Path(path).stem.lower()).strip("-")[:50] or "testlista"
    target = toclaude.FOLDER / f"{datetime.now():%Y-%m-%d-%H%M}-testresultat-{name}.md"
    target.write_text(markdown, encoding="utf-8")
    if not stopped:
        try:
            DONE.mkdir(parents=True, exist_ok=True)
            Path(path).rename(DONE / Path(path).name)
        except OSError:
            pass
    return target, markdown
