#!/usr/bin/python3
"""A GoblinShare order to Kakan (3 Nov, the user: the wife orders a picture from her laptop, "så kan jag starta
det när det går"). The order comes in through GoblinShare (share.py: a notification with Starta/Senare, the
window's BESTÄLLNINGAR); Starta runs this:

    order.py run <id> [--via ai|chatgpt]
                          ai (default): Goblin AI answers the wish (pictures in ```bild are drawn).
                          chatgpt (3 Nov, the user: "skicka det till chatgpt för ordentliga bilder"): the
                          ChatGPT app opens with the wish written in (goblincakes-chatgpt image – press Enter
                          there), the picture it draws is taken when it comes (≤ 10 min).
                          The answer goes back as a GoblinShare message and the pictures as files (taken there
                          without Ta emot, share.py awaits_reply). Already answered but not sent (the other
                          computer was off) → only sent again.

The state is kept by the GoblinShare service (orders.json): väntar → pågår → skickad, or fel / ej skickad.
"""
import os
import re
import subprocess
import sys
import threading
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(1, str(Path(os.environ.get("GOBLINCAKES_SHARE_DIR") or HERE.parent / "share")))
import share as S  # noqa: E402

MAX_PICTURES = 3

ORDER_PROMPT = """{text}

(Det här är en beställning från {alias}s dator via GoblinShare – inte från användaren vid tangentbordet.
Ditt svar och dina bilder skickas tillbaka till {alias} av sig själv. Vill {alias} ha en bild: rita den med
```bild (högst {most}). Annars svara kort och tydligt, så att svaret går att läsa som ett meddelande. Fråga inte
tillbaka – gör det bästa av beställningen som den är.)"""


def notice(title, body, actions=(), on_action=None):
    cmd = ["notify-send", "-a", "Goblin AI", "-i", "goblincakes-share"]
    for name, text in actions:
        cmd += ["-A", f"{name}={text}"]
    try:
        proc = subprocess.Popen(cmd + [title, body], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
    except OSError:
        return
    if actions and on_action:
        t = threading.Thread(target=lambda: on_action(proc.communicate()[0].strip()))
        t.start()
        t.join()  # keep the process until the notice is answered or closed


def plain_answer(answer):
    """The answer without its code blocks (the pictures go as files) and without empty lines at the ends."""
    text = re.sub(r"```.*?```", "", answer, flags=re.S)
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def pictures(answer):
    """[(English description, format)] from the answer's ```bild blocks."""
    import goblinai  # noqa: PLC0415
    found = [goblinai.image_request(m.group(1)) for m in re.finditer(r"```bild[ \t]*\n?(.*?)```", answer, re.S)]
    return [(p, f) for p, f in found if p][:MAX_PICTURES]


def update(oid, **fields):
    S.call("order_update", id=oid, fields=fields)


def finished(jid, wait):
    """Waits for a GoblinShare sending to end → "" when it got there, else why not."""
    end = time.time() + wait
    while time.time() < end:
        st = S.call("status") or {}
        job = next((t for t in st.get("transfers", []) if t["id"] == jid), None)
        if job and job["state"] in ("klart", "nekad", "avbruten", "fel"):
            return "" if job["state"] == "klart" else job.get("why") or job["state"]
        time.sleep(0.5)
    return "Mottagaren svarade inte"


def send_back(order, text, paths):
    """→ "" when sent, else why not."""
    fp = order["fingerprint"]
    st = S.call("status") or {}
    if not st:
        return "GoblinShare är avstängt"
    if not any(p["fingerprint"] == fp for p in st.get("peers", [])):
        S.call("scan", sweep=True, timeout=10)
        return f"{order['alias']}s dator syns inte i GoblinShare just nu – är den på?"
    if text:
        res = S.call("text", to=fp, text=text, timeout=10) or {}
        why = finished(res["id"], 60) if res.get("ok") else res.get("error") or "Svaret gick inte att skicka"
        if why:
            return why
    if paths:
        res = S.call("send", to=fp, paths=[str(p) for p in paths], timeout=10) or {}
        # Taken there without Ta emot (share.py awaits_reply) – the wait is for the upload itself
        why = finished(res["id"], 15 * 60) if res.get("ok") else res.get("error") or "Bilderna gick inte att skicka"
        if why:
            return why
    return ""


CHATGPT = "/usr/libexec/goblincakes-chatgpt"


def chatgpt_picture(text):
    """The ChatGPT app draws the wish → (path or None, why)."""
    out = Path(os.path.expanduser("~/Bilder/ChatGPT"))
    try:
        res = subprocess.run([CHATGPT, "image", f"Skapa en bild: {text}", "--out", f"{out}/"], capture_output=True,
                             text=True, timeout=12 * 60)
    except (OSError, subprocess.TimeoutExpired) as e:
        return None, f"ChatGPT-appen gick inte att använda ({type(e).__name__})"
    lines = [line.strip() for line in res.stdout.splitlines() if line.strip() and not line.startswith("@@")]
    path = lines[-1] if lines else ""
    if res.returncode == 0 and path and Path(path).is_file():
        return path, ""
    said = [line[3:].strip() for line in res.stdout.splitlines() if line.startswith("@@ ")]
    if not said or said[-1].startswith("Codex i ChatGPT-appen öppnas"):
        said.append("ChatGPT-appen är inte installerad" if not Path(os.path.expanduser(
            "~/.local/share/chatgpt-app/.goblincakes.json")).is_file() else "ChatGPT gav ingen bild")
    return None, said[-1]


def run(oid, via="ai"):
    res = S.call("order_get", id=oid) or {}
    order = res.get("order")
    if not order:
        print("Beställningen finns inte", file=sys.stderr)
        return 1
    import goblinai  # noqa: PLC0415
    name = goblinai.ai_name() or "Goblin AI"
    short = " ".join(order["text"].split())
    short = short[:60] + ("…" if len(short) > 60 else "")

    if order.get("answer") is not None or order.get("paths"):  # answered before, the other one was off
        text, paths = order.get("answer") or "", [p for p in order.get("paths") or [] if Path(p).is_file()]
    elif via == "chatgpt":
        name = "ChatGPT"
        path, why = chatgpt_picture(order["text"])
        if not path:
            update(oid, state="fel", why=why[:300])
            notice(f"Beställningen från {order['alias']} gick inte", f"{short}\n{why}")
            return 1
        text, paths = f"ChatGPT ritade din beställning \"{short}\".", [path]
        update(oid, answer=text, paths=paths, service="ChatGPT")
    else:
        keys = goblinai.load_keys()
        messages = [{"role": "system", "content": goblinai.system_prompt()},
                    {"role": "user", "content": ORDER_PROMPT.format(text=order["text"], alias=order["alias"],
                                                                    most=MAX_PICTURES)}]
        try:
            answer, service = goblinai.ask(messages, keys, choice=goblinai.chosen_model())
        except Exception as e:  # noqa: BLE001 – no service answered: told, the order can be started again
            update(oid, state="fel", why=f"{name} kunde inte svara: {e}"[:300])
            notice(f"Beställningen från {order['alias']} gick inte", f"{short}\n{e}")
            return 1
        paths, errors = [], []
        for prompt, fmt in pictures(answer):
            try:
                path, _ = goblinai.make_image(prompt, fmt, keys)
                paths.append(str(path))
            except Exception as e:  # noqa: BLE001 – the others are still sent
                errors.append(str(e).splitlines()[0])
        body = plain_answer(answer)
        if errors and not paths:
            body += ("\n\n" if body else "") + "(Bilden gick inte att rita: " + errors[0] + ")"
        text = (f"{name} svarar på din beställning \"{short}\":\n\n{body}" if body else "")
        if not text and not paths:
            update(oid, state="fel", why=f"{name} gav inget svar")
            return 1
        update(oid, answer=text, paths=paths, service=service)

    why = send_back(order, text, paths)
    if why:
        update(oid, state="ej skickad", why=why)
        notice(f"Beställningen till {order['alias']} är klar men inte skickad", f"{why}\nTryck Skicka igen i GoblinShare.")
        return 1
    update(oid, state="skickad", why="")
    what = (f"{len(paths)} bild{'er' if len(paths) > 1 else ''}" if paths else "svaret") + f" till {order['alias']}"
    if paths:
        notice(f"{name} skickade {what}", short, actions=[("open", "Visa bilden")],
               on_action=lambda c: c == "open" and subprocess.Popen(["xdg-open", paths[0]], start_new_session=True))
    else:
        notice(f"{name} skickade {what}", short)
    return 0


if __name__ == "__main__":
    if sys.argv[1:2] == ["run"] and len(sys.argv) > 2:
        sys.exit(run(sys.argv[2], sys.argv[sys.argv.index("--via") + 1] if "--via" in sys.argv[:-1] else "ai"))
    print(__doc__.strip())
    sys.exit(2)
