"""The check after an update (point 13 of Kakan's plan, 28 Oct): once per boot, a few minutes after login, Kakan's
watch service (reminders.py) looks at what should be running – GOBLINCAKES's switched-on services, failed services,
the top bar and its widgets, Ollama. Every look is kept per image; after a boot into a new image only what worked
with the previous image and is broken now is told, as a notice (the user's decision 28 Oct: nothing when all is
fine). What was already broken before, and known harmless failures (systools.KNOWN), are only listed in the text.

    python3 aftercheck.py check   look now (as after a new image when it is one), notice if something broke
    python3 aftercheck.py         the latest result (the same text as systemfel's part about the update)

Kept in ~/.local/state/goblincakes/efterkontroll.json. Only reads. Only the standard library (+ systools)."""

import json
import os
import re
import subprocess
import sys
import threading
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import systools  # noqa: E402

STATE = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "goblincakes" / "efterkontroll.json"
WAIT = 180  # seconds after login: everything has started by then
OLLAMA = "http://127.0.0.1:11434/api/tags"
# A widget that did not load (not a running hiccup in one function – those come too, but are kept apart)
WIDGET_ERROR = re.compile(r"(?:/plasmoids/|plugin=)(org\.goblincakes\.[\w.]+).*?(?:\.qml:\d+:\s*)?(.+)")


def booted():
    """(checksum, version) of the running image."""
    try:
        for d in json.loads(systools.run(["rpm-ostree", "status", "--json"])).get("deployments", []):
            if d.get("booted"):
                return d.get("checksum", ""), d.get("version", "?")
    except ValueError:
        pass
    return "", "?"


def boot_id():
    try:
        return Path("/proc/sys/kernel/random/boot_id").read_text().strip()
    except OSError:
        return ""


def _show(unit):
    out = systools.run(["systemctl", "--user", "show", unit, "-p", "ActiveState,Result,Type,SubState"])
    return dict(line.split("=", 1) for line in out.splitlines() if "=" in line)


def own_units():
    """{key: (ok, text)} for GOBLINCAKES's switched-on user services, timers and path units."""
    out = {}
    for line in systools.run(["systemctl", "--user", "list-unit-files", "goblincakes-*", "--no-legend",
                              "--plain"]).splitlines():
        parts = line.split()
        if len(parts) < 2 or parts[1] != "enabled":
            continue
        unit = parts[0]
        s = _show(unit)
        state = s.get("ActiveState", "")
        if state in ("active", "activating", "reloading"):
            ok = True
        elif unit.endswith(".service") and s.get("Type") == "oneshot":
            ok = state == "inactive" and s.get("Result", "success") == "success"
        else:
            ok = False
        text = "kör" if ok else f"{state or 'okänt'} ({s.get('Result', '?')})"
        out[f"tjänst:{unit}"] = (ok, text)
    return out


def failed():
    """{key: (False, text)} for every failed service, the system's and the user's."""
    out = {}
    for scope, args in (("system", []), ("användaren", ["--user"])):
        for line in systools.run(["systemctl", *args, "--failed", "--no-legend", "--plain"]).splitlines():
            parts = line.split()
            if parts:
                out[f"misslyckad:{parts[0]}"] = (False, f"misslyckades ({scope}): {' '.join(parts[4:])}")
    return out


def top_bar():
    """The top bar runs and GOBLINCAKES's widgets loaded without errors."""
    out = {}
    running = bool(systools.run(["pgrep", "-x", "plasmashell"]).strip())
    out["toppfältet"] = (running, "plasmashell kör" if running else "plasmashell kör inte (toppfältet och dockan borta)")
    errors = {}
    for line in systools.run(["journalctl", "--user", "-b", "--no-pager", "-o", "cat", "_COMM=plasmashell"],
                             timeout=20).splitlines():
        m = WIDGET_ERROR.search(line)
        if m and re.search(r"error|is not a type|not installed|cannot|failed|undefined|not a function", line, re.I):
            errors.setdefault(m.group(1), m.group(2).strip()[:200])
    for widget, error in errors.items():
        out[f"widget:{widget}"] = (False, f"fel i widgeten: {re.sub(r'^/?contents/ui/', '', error)}")
    return out


def ollama():
    """Ollama answers and has its models (only when its service is switched on)."""
    if systools.run(["systemctl", "--user", "is-enabled", "goblincakes-ollama.service"]).strip() != "enabled":
        return {}
    for attempt in range(3):  # right after a game the game guard is starting it again
        try:
            with urllib.request.urlopen(OLLAMA, timeout=10) as r:
                models = json.load(r).get("models", [])
            break
        except (OSError, ValueError) as e:
            if attempt == 2:
                return {"ollama": (False, f"svarar inte ({e})")}
            time.sleep(10)
    return {"ollama": (bool(models), f"svarar, {len(models)} modeller" if models else "svarar men har inga modeller")}


def look():
    found = {}
    for part in (own_units, failed, top_bar, ollama):
        try:
            for key, value in part().items():
                if not (key.startswith("misslyckad:") and f"tjänst:{key.split(':', 1)[1]}" in found):
                    found[key] = value  # an own service that failed: once
        except Exception as e:  # noqa: BLE001 – one broken part must not stop the others
            found[f"kontroll:{part.__name__}"] = (False, f"gick inte att kolla: {e}")
    return {k: {"ok": ok, "text": text} for k, (ok, text) in found.items()}


def load():
    try:
        return json.loads(STATE.read_text())
    except (OSError, ValueError):
        return {}


def save(data):
    STATE.parent.mkdir(parents=True, exist_ok=True)
    tmp = STATE.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1))
    tmp.replace(STATE)


def harmless(key):
    note = systools.known(key.split(":", 1)[-1].replace("\\x2d", "-"))
    return "ofarlig" in note.lower()


def compare(before, now):
    """(broke, already, harmless) – keys. broke = fine with the previous image (or not seen then) and broken now."""
    broke, already, safe = [], [], []
    for key, r in now.items():
        if r["ok"]:
            continue
        if harmless(key):
            safe.append(key)
        elif key in before and not before[key]["ok"]:
            already.append(key)
        else:
            broke.append(key)
    return broke, already, safe


def check(notify=True):
    """Looks now; once per boot. After a new image: compares with the previous image's last look."""
    checksum, version = booted()
    data = load()
    if data.get("boot") == boot_id():
        return data
    now = look()
    prev = data.get("images", {}).get(data.get("image", ""), {})
    new_image = bool(data.get("image")) and data.get("image") != checksum
    result = {"boot": boot_id(), "image": checksum, "version": version, "at": time.time(), "looked": now,
              "images": {**({data["image"]: prev} if new_image else {}), checksum: {"version": version, "looks": now}},
              "update": data.get("update")}
    if new_image:
        broke, already, safe = compare(prev.get("looks", {}), now)
        result["update"] = {"from": prev.get("version", "?"), "to": version, "at": time.time(),
                            "broke": {k: now[k]["text"] for k in broke}, "already": {k: now[k]["text"] for k in already},
                            "harmless": {k: now[k]["text"] for k in safe}, "fine": sum(r["ok"] for r in now.values())}
    save(result)
    if new_image and result["update"]["broke"] and notify:
        tell(result["update"])
    return result


def name(key):
    kind, _, what = key.partition(":")
    what = what.replace("\\x2d", "-")
    return {"tjänst": what, "misslyckad": what, "widget": f"widgeten {what}", "toppfältet": "toppfältet",
            "ollama": "lokala AI:n (Ollama)"}.get(kind, what or kind)


def tell(update):
    lines = [f"{name(k)}: {t}" for k, t in update["broke"].items()]
    n = len(lines)
    question = (f"Efter uppdateringen till GOBLINCAKES {update['to']} fungerar {n} sak{'er' if n > 1 else ''} inte som "
                "före uppdateringen:\n" + "\n".join(f"- {line}" for line in lines) +
                "\n\nLös det här – kolla loggarna för var och en (systemfel, kartan, kända lösningar), säg vad som "
                "hänt och rätta det (starta om tjänsten, rätta en inställning i hemmappen …). Går en del inte att "
                "rätta: föreslå Skicka till Claude för just den delen. Föreslå inte `rpm-ostree rollback` – bara "
                "om användaren själv frågar, eller om datorn inte går att använda (inget skrivbord, inget nätverk) "
                "och du redan försökt rätta det.")
    import reminders  # noqa: PLC0415
    reminders.notice(f"Efter uppdateringen: {n} sak{'er' if n > 1 else ''} gick sönder",
                     "\n".join(lines[:4]) + ("\n…" if n > 4 else ""), actions=[("ask", "Fråga Kakan")],
                     on_action=lambda c: c == "ask" and subprocess.Popen(["goblin-ai", "--ask", question],
                                                                         start_new_session=True))


def report():
    """The text for the AI (systemfel): the latest update's result and what is broken right now."""
    data = load()
    up = data.get("update")
    out = []
    if up:
        when = systools.when(up["at"])
        out.append(f"Kontroll efter senaste uppdateringen ({up['from']} → {up['to']}, {when}):")
        if up["broke"]:
            out.append("Gick sönder med uppdateringen (fungerade före):")
            out += [f"- {name(k)}: {t}" for k, t in up["broke"].items()]
        else:
            out.append("Inget gick sönder med uppdateringen.")
        if up["already"]:
            out.append("Var trasigt redan före uppdateringen:")
            out += [f"- {name(k)}: {t}" for k, t in up["already"].items()]
        if up["harmless"]:
            out.append("Kända ofarliga fel: " + ", ".join(name(k) for k in up["harmless"]))
        out.append(f"Fungerade: {up['fine']} saker.")
    else:
        out.append("Kontroll efter uppdatering: ingen ny image har startats sedan kontrollen kom.")
    looked = data.get("looked", {})
    if looked and not (up and up["at"] >= data["at"]):  # this boot's look is the update's own: said above
        bad = [f"- {name(k)}: {r['text']}" for k, r in looked.items() if not r["ok"] and not harmless(k)]
        out.append(f"Vid inloggningen {systools.when(data['at'])}: " + ("allt startade." if not bad else "trasigt:"))
        out += bad
    return "\n".join(out)


if __name__ == "__main__":
    if sys.argv[1:2] == ["check"]:
        check()
        print(report())
        for t in threading.enumerate():  # the notice's thread waits for the click
            if t is not threading.main_thread():
                t.join()
    else:
        print(report())
