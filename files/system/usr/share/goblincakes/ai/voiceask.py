"""A spoken question to Kakan (Kakan step 9, part D2, 5 Nov): what wasn't a simple command (voicecmd.py)
goes to her the same way as a written one – the same services, model choice and tools – and the chat is
saved like the window's, so "Vill du se hela?" → "ja" opens it in Goblin AI.

    ask(text) → {"id", "speak", "more", "needs_ok", "shown"} or {"error"}

She is told the question was spoken: one or two short sentences first, read aloud; the rest only in the
window. A command in the answer is never run from the voice (the user's decision 4 Nov: changes are
approved with a click, never by voice) – the window opens with the card instead. Reading commands run
at once as in the window (cmdlevel's "read", same timeout and log) and their output goes back to her –
at most ROUNDS answers per question (5 Nov: "free -h" for "hur mycket minne har jag" waited for a click).
Try without a microphone:  python3 voiceask.py "vad är det för väder i morgon"
"""
import json
import os
import re
import subprocess
import threading
import time
from pathlib import Path

CONVERSATION = "röst"         # how her commands are marked in Kakan's log (as voicecmd's)
DATA = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share") / "goblincakes" / "ai"
KEEP_CONVERSATIONS = 50       # as the window and the terminal: the latest 50 outside projects
VOICE_NOTE = ("\n\n(Frågan ställdes med rösten – användaren hör början av svaret uppläst. Börja med en eller "
              "två korta meningar som svarar på frågan, utan listor, tabeller eller markdown. Sedan en tom "
              "rad, och först därefter detaljer om det behövs.)")
ROUNDS = 3
SPEAK_MAX = 260               # characters read aloud before "Vill du se hela?"


def _plain(text):
    """Markdown away, for reading aloud."""
    t = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)          # [text](link)
    t = re.sub(r"`{1,3}([^`]*)`{1,3}", r"\1", t)
    t = re.sub(r"^\s*(?:#+|[-*•]|\d+[.)])\s+", "", t, flags=re.M)
    t = re.sub(r"[*_~>|]+", "", t)
    return " ".join(t.split())


def first_sentences(answer):
    """The first paragraph's first one or two sentences (at most SPEAK_MAX characters)."""
    para = next((p for p in re.split(r"\n\s*\n", answer.strip()) if _plain(p)), "")
    sentences = re.split(r"(?<=[.!?])\s+", _plain(para))
    said = ""
    for s in sentences[:2]:
        if said and len(said) + len(s) > SPEAK_MAX:
            break
        said = f"{said} {s}".strip()
    return said[:SPEAK_MAX].rstrip() if said else ""


def _save(conv):
    DATA.mkdir(parents=True, exist_ok=True)
    (DATA / f"{conv['id']}.json").write_text(json.dumps(conv, ensure_ascii=False))
    loose = []
    for f in sorted(DATA.glob("2*.json"), reverse=True):
        try:
            if not json.loads(f.read_text()).get("project", ""):
                loose.append(f)
        except (OSError, ValueError):
            continue
    for old in loose[KEEP_CONVERSATIONS:]:
        old.unlink(missing_ok=True)


def ask(text, choice=""):
    import goblinai as g  # noqa: PLC0415 – Kakan's own, loaded only when a question comes
    keys = g.load_keys()
    if not g.has_keys(keys):
        return {"error": "Goblin AI har ingen AI-tjänst än – öppna Goblin AI och välj en."}
    question = {"role": "user", "content": text + VOICE_NOTE}
    messages = [{"role": "system", "content": g.system_prompt()}, question]
    levels = g.cmd_level()
    cwd = str(Path.home())
    display = [{"role": "user", "text": text, "segments": [], "service": "", "file": "", "voice": True}]
    needs_ok = False
    for round_ in range(ROUNDS):
        stop = threading.Event()
        steps = g.Steps(report=lambda items: None, stop=stop)
        try:
            answer, service = g.ask(messages, keys, choice=choice or g.chosen_model(), steps=steps)
        except g.ServiceError as e:
            return {"error": str(e)}
        messages.append({"role": "assistant", "content": answer})
        parts = g.segments(answer)
        display.append({"role": "assistant", "text": answer, "segments": parts, "service": service, "file": "",
                        "tools": g.last_tools()})
        cards = [p for p in parts if p["type"] in ("command", "blocked")]
        if not cards:
            break
        if any(p["type"] == "blocked" or p.get("level", "change") != "read" for p in cards) \
                or not levels.autorun() or round_ == ROUNDS - 1:
            needs_ok = True               # a change (or too many steps): the window, with a click
            break
        said = []
        for p in cards:                   # reading ones: at once, as the window does
            code = p["code"]
            try:
                proc, cwd = g.run_in_folder(code, cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                            stdin=subprocess.DEVNULL, text=True, timeout=levels.AUTO_TIMEOUT)
                output, exit_code = proc.stdout or "", proc.returncode
            except subprocess.TimeoutExpired as e:
                output = e.output if isinstance(e.output, str) else (e.output or b"").decode(errors="replace")
                output, exit_code = (output or "") + f"\n(stoppat efter {levels.AUTO_TIMEOUT} s)\n", -9
            levels.log(code, "read", "auto", exit_code, output, None, CONVERSATION)
            p.update(state="done", output=output.strip(), code_result=exit_code)
            said.append(f"$ {g.reported_code(code)}\n{levels.shorten(output, code=code)}(avslutskod {exit_code})")
        messages.append({"role": "user", "content": "Så här gick det:\n\n" + "\n\n".join(said)
                         + f"\n\n(Mappen nu: {cwd})" + g.after_commands(messages)})
    final = display[-1]
    receipt = g.receipt(display, len(display) - 1)
    if receipt:
        final["receipt"] = receipt
    answer = final["text"]
    speak = first_sentences(answer)
    rest = _plain(answer)
    conv_id = time.strftime("%Y%m%d-%H%M%S")
    try:
        _save({"id": conv_id, "title": " ".join(text.split())[:80], "updated": time.time(), "file": None,
               "cwd": cwd, "project": "", "api": messages[1:], "display": display, "voice": True})
    except OSError:
        conv_id = ""
    return {"id": conv_id, "speak": speak, "shown": answer.strip(), "needs_ok": needs_ok,
            "more": needs_ok or len(rest) > len(speak) + 40}


if __name__ == "__main__":
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    print(json.dumps(ask(" ".join(sys.argv[1:]) or "Vad är klockan i Tokyo?"), ensure_ascii=False, indent=1))
