"""Goblin AI's ```systemfel tool (20 Oct): what has gone wrong on the computer – crashes (systemd-coredump),
errors in the journal, failed services, the GOBLINCAKES version/last update and settings changed lately –
short and grouped, with notes on programs that are known and usually harmless, so the AI does not guess.
Only reads; fixes are suggested as command cards the user runs."""

import collections
import json
import re
import subprocess
import time
from pathlib import Path

HOME = Path.home()
COREDUMP_ID = "fc2e22bc6ee647b6b90729ab34a250b1"
CRASH_DAYS = 3
LIMIT = 9000  # characters to the AI

# Known programs: substring of the program/unit name (lowercase) → what it is. "Ofarligt" only where it is.
KNOWN = {
    "xalia": "Protons tillgänglighetshjälp (skärmläsarstöd), startas av Proton i bakgrunden. Kraschar ofta utan "
             "att spelet märker något – ofarligt om spelet fungerar.",
    "d3ddriverquery": "Steams koll av grafikdrivrutinen (körs under Proton när Steam startar/uppdateras). "
                      "Kraschar ofta – ofarligt om Steam och spelen fungerar.",
    "steamwebhelper": "Steams webbläsardel (butik, bibliotek, vänner). Kraschar den blir Steam-fönstret svart "
                      "eller startar om.",
    "fossilize_replay": "Steams shaderbearbetning (förbereder spelens shaders i bakgrunden).",
    "wine64-preloader": "Wines/Protons startprogram – vilket Windows-program det var står som programnamn.",
    "wine-preloader": "Wines/Protons startprogram – vilket Windows-program det var står som programnamn.",
    "pressure-vessel": "Steams Linux-runtime (behållaren spelen körs i).",
    "srt-logger": "Steams Linux-runtime (loggning).",
    "steam": "Steam-klienten själv (32-bitars).",
    "wow.exe": "World of Warcraft.",
    "gdb": "Felsökaren gdb – startas oftast av någon som undersöker en krasch, inte ett fel i sig.",
    "kwin_wayland": "Fönsterhanteraren (KWin) – kraschar den blinkar skärmen och fönstren kommer tillbaka.",
    "plasmashell": "Plasmas paneler och skrivbord (toppfältet, dockan, widgetarna).",
    "pipewire": "Ljud och skärmfångst. Rader som \"pw.context: … Spa:Pod …\" är detaljutskrifter när ett program "
                "(t.ex. OBS) fångar skärmen – oftast ofarliga.",
    "wireplumber": "Styr PipeWire (ljudenheter, vem som får skärmen).",
    "nvidia-settings-load": "Nvidias X-inställningar vid inloggning – behövs inte på Wayland, felet är ofarligt.",
    "systemd-remount-fs": "På GOBLINCAKES (atomiskt, systemet är skrivskyddat) misslyckas den alltid med "
                          "\"overlay: No changes allowed in reconfigure\" – känt och ofarligt.",
    "systemd-udevd": "Enhetshanteraren. \"Failed to resolve group\" för tty/disk/video/audio/kvm/lp/utmp de första "
                     "sekunderna av starten är ofarligt (grupperna står i /usr/lib/group, som läses först lite senare; "
                     "kolla med `getent group <namn>`). 'plugdev' är en Debian-grupp som Fedora inte har – ofarligt.",
    "systemd-tmpfiles": "Skapar filer/mappar vid start. \"Failed to resolve group\" tidigt i starten är ofarligt av "
                        "samma skäl som för systemd-udevd (grupperna finns i /usr/lib/group).",
    "ollama": "GOBLINCAKES lokala AI (Ollama).",
    "goblincakes": "En del av GOBLINCAKES själv.",
}


def run(cmd, timeout=15):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def text_of(value):
    if isinstance(value, list):  # the journal gives binary fields as a list of bytes
        try:
            return bytes(value).decode(errors="replace")
        except (TypeError, ValueError):
            return ""
    return value or ""


def journal(args, timeout=20):
    out = []
    for line in run(["journalctl", "--no-pager", "-o", "json", *args], timeout).splitlines():
        try:
            out.append(json.loads(line))
        except ValueError:
            continue
    return out


def when(stamp):
    """'mån 19 okt 17:20' from seconds."""
    days = ["mån", "tis", "ons", "tor", "fre", "lör", "sön"]
    months = ["jan", "feb", "mar", "apr", "maj", "jun", "jul", "aug", "sep", "okt", "nov", "dec"]
    t = time.localtime(stamp)
    return f"{days[t.tm_wday]} {t.tm_mday} {months[t.tm_mon - 1]} {t.tm_hour:02d}:{t.tm_min:02d}"


def known(name):
    low = name.lower()
    for key, text in KNOWN.items():
        if key in low:
            return text
    return ""


def tool_version(path):
    """'Proton 11.0' / 'GE-Proton11-9' from a path inside a compatibility tool."""
    m = re.search(r"common/(Proton[^/]*)/|compatibilitytools\.d/([^/]+)/", path)
    return (m.group(1) or m.group(2)).replace("-x86_64", "") if m else ""


def crashes(match=""):
    items = []
    for d in journal([f"MESSAGE_ID={COREDUMP_ID}", f"--since=-{CRASH_DAYS}d"]):
        exe, cmd = text_of(d.get("COREDUMP_EXE")), text_of(d.get("COREDUMP_CMDLINE"))
        name = text_of(d.get("COREDUMP_COMM")) or Path(exe).name
        if name.startswith("d3ddriverquery"):
            name = "d3ddriverquery64.exe"
        if match and match not in f"{name} {exe} {cmd}".lower():
            continue
        try:
            stamp = int(d.get("COREDUMP_TIMESTAMP") or d["__REALTIME_TIMESTAMP"]) / 1e6
        except (KeyError, ValueError):
            continue
        items.append({"name": name, "exe": exe, "cmd": cmd, "time": stamp, "pid": text_of(d.get("COREDUMP_PID")),
                      "signal": text_of(d.get("COREDUMP_SIGNAL_NAME")), "unit": text_of(d.get("COREDUMP_USER_UNIT"))
                      or text_of(d.get("COREDUMP_UNIT")), "tool": tool_version(exe + " " + cmd.replace("\\", "/"))})
    return sorted(items, key=lambda c: c["time"])


def stack(pid, frames=6):
    """The first frames of the crashed thread (coredumpctl info) + modules worth knowing (MangoHud …)."""
    info = run(["coredumpctl", "info", "--no-pager", pid], 20)
    lines, out = info.splitlines(), []
    for i, line in enumerate(lines):
        if "Stack trace of thread" in line:
            out = [x.strip() for x in lines[i + 1:i + 1 + frames] if x.strip().startswith("#")]
            break
    extras = sorted({m.group(1) for m in re.finditer(r"Module (\S*(?:mangohud|vkbasalt|gamemode|obs)\S*)", info, re.I)})
    return out, extras


def overview_crashes(items):
    if not items:
        return f"Inga krascher de senaste {CRASH_DAYS} dygnen."
    groups = collections.OrderedDict()
    for c in sorted(items, key=lambda c: -c["time"]):
        groups.setdefault(c["name"], []).append(c)
    out = [f"{len(items)} krascher de senaste {CRASH_DAYS} dygnen, per program (nyast först):"]
    for name, group in list(groups.items())[:10]:
        first, last = group[-1], group[0]
        tools = sorted({c["tool"] for c in group if c["tool"]})
        line = (f"- {name}: {len(group)} st, första {when(first['time'])}, senaste {when(last['time'])}"
                f" ({last['signal']})")
        if tools:
            line += " · " + ", ".join(tools)
        out.append(line)
        cmd = last["cmd"].replace("\n", " ")
        if cmd and cmd != last["exe"]:
            out.append(f"  kommando: {cmd[:160]}")
        if note := known(name):
            out.append(f"  känt: {note}")
    if len(groups) > 10:
        out.append(f"- … och {len(groups) - 10} program till")
    return "\n".join(out)


CONTINUATION = re.compile(r"^(?:[\w.-]+:)?\s{2,}")  # PipeWire's multi-line dumps (pw.context:   Prop: …)


def journal_errors(match="", boot="-b"):
    entries = journal([boot, "-p3"])
    groups, examples, last = collections.Counter(), {}, {}
    for d in entries:
        who = text_of(d.get("SYSLOG_IDENTIFIER")) or text_of(d.get("_COMM")) or "?"
        msg = text_of(d.get("MESSAGE")).strip("\n")
        if not msg or CONTINUATION.match(msg) or msg.startswith("Process ") and "dumped core" in msg:
            continue
        unit = text_of(d.get("_SYSTEMD_USER_UNIT")) or text_of(d.get("_SYSTEMD_UNIT"))
        if match and match not in f"{who} {unit} {msg}".lower():
            continue
        key = (who, re.sub(r"0x[0-9a-f]+|\d+", "#", msg.lower())[:90])
        groups[key] += 1
        examples[key] = msg.splitlines()[0][:220]
        try:
            last[key] = int(d["__REALTIME_TIMESTAMP"]) / 1e6
        except (KeyError, ValueError):
            pass
    return groups, examples, last


def overview_journal(match=""):
    groups, examples, last = journal_errors(match)
    if not groups:
        return "Journalen: inga fel sedan datorn startade" + (f" för \"{match}\"." if match else ".")
    total = sum(groups.values())
    out = [f"Journalen sedan start: {total} felrader i {len(groups)} sorter (vanligast först):"]
    shown_notes = set()
    for key, n in groups.most_common(15 if not match else 25):
        who = key[0]
        out.append(f"- {who} ×{n} (senast {when(last.get(key, 0))}): {examples[key]}")
        note = known(who)
        if note and who not in shown_notes:
            out.append(f"  känt: {note}")
            shown_notes.add(who)
    if len(groups) > 15 and not match:
        out.append(f"- … och {len(groups) - 15} sorter till (be om ett program för fler)")
    return "\n".join(out)


def failed_units():
    out = []
    for scope, args in (("system", []), ("användaren", ["--user"])):
        for line in run(["systemctl", *args, "--failed", "--no-legend", "--plain"]).splitlines():
            unit = line.split()[0] if line.split() else ""
            if unit:
                desc = " ".join(line.split()[4:])
                text = f"- {unit} ({scope}): {desc}"
                if note := known(unit.replace("\\x2d", "-")):
                    text += f"\n  känt: {note}"
                out.append(text)
    return "Misslyckade tjänster:\n" + "\n".join(out) if out else "Misslyckade tjänster: inga."


def system_state():
    out = []
    try:
        version = Path("/usr/share/goblincakes/version").read_text().strip()
        out.append(f"GOBLINCAKES {version}, variant {Path('/usr/share/goblincakes/variant').read_text().strip()}")
    except OSError:
        pass
    out.append(f"Datorn startade {when(time.time() - float(Path('/proc/uptime').read_text().split()[0]))}")
    try:
        status = json.loads(run(["rpm-ostree", "status", "--json"]))
        for d in status.get("deployments", []):
            tag = "körs nu" if d.get("booted") else "väntar på omstart" if d.get("staged") else "förra (rollback)"
            out.append(f"- {tag}: {d.get('version', '?')} (hämtad {when(d.get('timestamp', 0))})")
    except ValueError:
        pass
    return "System:\n" + "\n".join(out)


def recent_changes(days=7):
    """GOBLINCAKES settings, autostart and Steam start lines changed lately – causes are often just before."""
    cutoff, out = time.time() - days * 86400, []
    for folder in (HOME / ".config/goblincakes", HOME / ".config/autostart", HOME / ".config/environment.d",
                   HOME / ".local/share/applications"):
        try:
            files = [f for f in folder.iterdir() if f.is_file()]
        except OSError:
            continue
        for f in files:
            try:
                mtime = f.stat().st_mtime
            except OSError:
                continue
            if mtime > cutoff and not f.name.startswith("goblincakes-webapp"):
                out.append((mtime, f"- {when(mtime)}: {str(f).replace(str(HOME), '~')}"))
    lines = [x for _, x in sorted(out, reverse=True)[:15]]
    for desktop in (HOME / ".config/autostart/steam.desktop", HOME / ".local/share/applications/steam.desktop"):
        try:
            exec_line = next(x for x in desktop.read_text().splitlines() if x.startswith("Exec="))
            lines.append(f"Steams startrad ({str(desktop).replace(str(HOME), '~')}): {exec_line[5:][:200]}")
        except (OSError, StopIteration):
            pass
    return f"Ändrat de senaste {days} dygnen (inställningar, autostart):\n" + ("\n".join(lines) or "- inget")


def details(match):
    """One program: every crash with time and Proton version, the latest crash's stack, its journal lines."""
    out = [f"Detaljer för \"{match}\":"]
    items = crashes(match)
    if items:
        out.append(f"Krascher de senaste {CRASH_DAYS} dygnen: {len(items)}")
        for c in items[-12:]:
            out.append(f"- {when(c['time'])} {c['name']} ({c['signal']})" + (f" · {c['tool']}" if c["tool"] else "")
                       + (f" · startad från {c['unit']}" if c["unit"] else ""))
        frames, extras = stack(items[-1]["pid"])
        if frames:
            out.append(f"Senaste kraschen ({items[-1]['name']}), början av stacken:\n  " + "\n  ".join(frames))
        else:
            out.append("Senaste kraschen: ingen läsbar stack (vanligt för Windows-program under Proton).")
        if extras:
            out.append("Laddat i programmet: " + ", ".join(extras))
        names = collections.Counter(c["name"] for c in items)
        out.append("Programmen som kraschade:")
        for name, n in names.most_common():
            out.append(f"- {name} ×{n}: {known(name) or 'okänt – gissa inte vad det är'}")
    else:
        out.append(f"Inga krascher de senaste {CRASH_DAYS} dygnen.")
    out.append(overview_journal(match))
    lines = []
    for d in journal(["-b", "-n", "400", "-p4"])[-400:]:
        who = text_of(d.get("SYSLOG_IDENTIFIER")) or text_of(d.get("_COMM"))
        msg = text_of(d.get("MESSAGE")).splitlines()[0][:200] if text_of(d.get("MESSAGE")) else ""
        if match in f"{who} {msg}".lower() and not CONTINUATION.match(msg):
            lines.append(f"  {when(int(d['__REALTIME_TIMESTAMP']) / 1e6)} {who}: {msg}")
    if lines:
        out.append("Senaste varningar/fel om det (journalen):\n" + "\n".join(lines[-15:]))
    return "\n".join(out)


def system_errors(query=""):
    """The text for the AI: an overview, or details when a program is named."""
    query = " ".join(query.split()).lower()
    if query in ("", "alla", "översikt", "oversikt", "allt"):
        parts = [system_state(), overview_crashes(crashes()), failed_units(), overview_journal(), recent_changes()]
    else:
        parts = [system_state(), details(query), recent_changes()]
    text = "\n\n".join(parts)
    return text if len(text) <= LIMIT else text[:LIMIT] + "\n… (kortat)"


if __name__ == "__main__":
    import sys
    print(system_errors(" ".join(sys.argv[1:])))
