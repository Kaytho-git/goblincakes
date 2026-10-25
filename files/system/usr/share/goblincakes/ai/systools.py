"""Goblin AI's ```systemfel tool (20 Oct): what has gone wrong on the computer – crashes (systemd-coredump),
errors in the journal, failed services, the GOBLINCAKES version/last update and settings changed lately –
short and grouped, with notes on programs that are known and usually harmless, so the AI does not guess.
Only reads; fixes are suggested as command cards the user runs."""

import collections
import json
import os
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


def run(cmd, timeout=15, partial=False):
    """The output; on a timeout nothing, or what came so far (partial)."""
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or "") if partial else ""
        return out.decode(errors="replace") if isinstance(out, bytes) else out
    except OSError:
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



# ```leta (24 Oct): the AI looks around the computer itself – finds files, reads logs and settings, searches
# for text, a program's journal and a service's status. Only reads, never runs anything the AI wrote: a fixed
# set of commands, every path checked against SECRET first, so keys and passwords never reach the AI.
SECRET = re.compile(
    r"/\.ssh(?:/|$)|/\.gnupg(?:/|$)|/\.password-store|/keyrings?(?:/|$)|kwallet|/\.netrc$|/\.aws(?:/|$)|"
    r"/\.docker/config\.json$|/\.git-credentials$|/\.pki(?:/|$)|\.(?:pem|key|p12|pfx|kdbx|enc)$|"
    r"/id_(?:rsa|dsa|ecdsa|ed25519)(?:_sk)?$|"  # private keys outside ~/.ssh too (~/.ollama/id_ed25519)
    r"/goblincakes/(?:ai|ianseo)\.env$|/goblincakes/(?:wcl|spotify|youtube|lastfm|discord-\w+|chrome-nycklar)|"
    r"cookies|login data|logins\.json|key[34]\.db|cert9\.db|web data|token|secret|passw|"
    r"^/etc/(?:shadow|gshadow|sudoers)|^/proc/|^/sys/|^/dev/|^/run/user/\d+/(?:gnupg|keyring)",
    re.I)
FIND_PLACES = [HOME, Path("/etc"), Path("/var/log"), Path("/usr/share/goblincakes"), Path("/usr/lib/systemd"),
               Path("/usr/libexec"), Path("/usr/bin"), Path("/tmp")]


def disks():
    """The plugged-in disks (/run/media/<user>/*, /mnt/*)."""
    found = []
    for root in (Path("/run/media") / HOME.name, Path("/mnt")):
        try:
            found += sorted(d for d in root.iterdir() if d.is_dir() and os.path.ismount(d))
        except OSError:
            continue
    return found


def find_places():
    """FIND_PLACES + the plugged-in disks – punkt 3 (25 Oct): free paths."""
    return FIND_PLACES + disks()
FIND_SKIP = ("/proc", "/sys", "/dev", "/run", str(HOME / ".cache"), str(HOME / ".local/share/Trash"),
             str(HOME / ".ssh"), str(HOME / ".gnupg"), str(HOME / ".local/share/keyrings"))
# A key inside an ordinary file (recorder.json's cs2Token, OBS's password): the value is hidden
SECRET_VALUE = re.compile(r"((?:token|secret|passw\w*|api[_-]?key|\w*key|auth\w*|cookie|bearer)\w*[\"']?\s*[:=]\s*[\"']?)"
                          r"([^\s\"',;}]{6,})", re.I)
READ_LINES = 150
READ_BYTES = 2_000_000  # bigger files: only the end is read


def hide(line):
    return SECRET_VALUE.sub(lambda m: m.group(1) + "***", line)


class SearchError(Exception):
    pass


def path_of(text):
    path = Path(os.path.expandvars(text.strip().strip("\"'`"))).expanduser()  # /run/media/$USER/… (25 Oct)
    if not path.is_absolute():
        path = HOME / path
    return path


def allowed(path):
    return not SECRET.search(str(path)) and not SECRET.search(str(path.resolve()))


def find_files(pattern, where=None):
    """Files and folders whose name contains pattern (or matches a * pattern), newest first."""
    if "/" in pattern.rstrip("/"):  # "~/.ssh/*": the folder part is where
        where, pattern = path_of(pattern.rstrip("/").rsplit("/", 1)[0] or "/"), pattern.rstrip("/").rsplit("/", 1)[1]
        if not allowed(where):
            raise SearchError(f"{where} är hemligt (nycklar/lösenord) och läses inte")
    glob = pattern if any(c in pattern for c in "*?[") else f"*{pattern}*"
    places = [where] if where else find_places()
    secret = 0
    hits, cut = [], False
    for place in places:
        prune = []
        for skip in FIND_SKIP:
            prune += ["-path", skip, "-o"]
        out = run(["find", str(place), "-xdev", "(", *prune[:-1], ")", "-prune", "-o", "-iname", glob,
                   "-printf", "%T@\t%s\t%y\t%p\n"], 20, partial=True)
        if out and not out.endswith("\n"):  # stopped after 20 s: the half line goes
            out, cut = out.rsplit("\n", 1)[0], True
        for line in out.splitlines():
            stamp, size, kind, path = (line.split("\t", 3) + ["", "", "", ""])[:4]
            if path and not allowed(Path(path)):
                secret += 1
            elif path:
                try:
                    hits.append((float(stamp), int(size), kind, path))
                except ValueError:
                    continue
    if not hits and secret:
        return f"{secret} träffar för \"{pattern}\", men alla är hemliga (nycklar/lösenord) och visas inte."
    if not hits:
        return f"Inga filer eller mappar med \"{pattern}\" i namnet" + (f" i {where}." if where else
               f" (letade i {', '.join(str(p).replace(str(HOME), '~') for p in places)}).")
    hits.sort(reverse=True)
    out = [f"{len(hits)} träffar för \"{pattern}\" (nyast först" + (", letade inte klart – ange en mapp" if cut else "") + "):"]
    for stamp, size, kind, path in hits[:40]:
        out.append(f"- {path}{'/' if kind == 'd' else ''}  ({when(stamp)}" + ("" if kind == "d" else f", {size_text(size)}") + ")")
    if len(hits) > 40:
        out.append(f"- … och {len(hits) - 40} till (be om ett noggrannare namn eller en mapp)")
    if secret:
        out.append(f"- ({secret} hemliga visas inte)")
    return "\n".join(out)


def size_text(n):
    for unit in ("B", "kB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024
    return ""


def list_folder(path):
    if not path.is_dir():
        raise SearchError(f"{path} är ingen mapp")
    try:
        items = sorted(path.iterdir(), key=lambda p: p.name.lower())
    except OSError as e:
        raise SearchError(f"kan inte läsa {path}: {e.strerror}") from e
    out = [f"{path}/ ({len(items)} st):"]
    for item in items[:80]:
        if not allowed(item):
            out.append(f"- {item.name}  (hemlig – läses inte)")
            continue
        try:
            st = item.stat()
        except OSError:
            out.append(f"- {item.name}  (trasig länk)")
            continue
        out.append(f"- {item.name}{'/' if item.is_dir() else ''}  ({when(st.st_mtime)}"
                   + ("" if item.is_dir() else f", {size_text(st.st_size)}") + ")")
    if len(items) > 80:
        out.append(f"- … och {len(items) - 80} till")
    return "\n".join(out)


def read_file(path, match="", start=0):
    """The end of a text file (or the lines with match, or READ_LINES lines from line start, with the line numbers)."""
    if path.is_dir():
        return list_folder(path)
    if not path.exists():
        raise SearchError(f"{path} finns inte")
    try:
        size = path.stat().st_size
        with path.open("rb") as f:
            if size > READ_BYTES:
                f.seek(size - READ_BYTES)
            data = f.read(READ_BYTES)
    except OSError as e:
        raise SearchError(f"kan inte läsa {path}: {e.strerror}") from e
    if b"\0" in data[:4096]:
        raise SearchError(f"{path} är ingen textfil ({size_text(size)})")
    text = data.decode(errors="replace")
    if size <= READ_BYTES and text.count("\n") < 3 and text.lstrip()[:1] in "{[":
        # amp.json is 4 kB on one line: only its first 300 characters were seen (25 Oct)
        try:
            text = json.dumps(json.loads(text), ensure_ascii=False, indent=1)
        except ValueError:
            pass
    lines = text.splitlines()
    cut = 300 if len(lines) > 20 else 3000
    first = 1 if size <= READ_BYTES else None
    if match:
        found = [(i, l) for i, l in enumerate(lines, 1) if match.lower() in l.lower()]
        if not found:
            return f"{path}: inga rader med \"{match}\" ({len(lines)} rader lästa)."
        shown = found[-READ_LINES:]
        return (f"{path}: {len(found)} rader med \"{match}\"" + (" (de senaste)" if len(found) > len(shown) else "") + ":\n"
                + "\n".join((f"{i}: " if first else "") + hide(l[:cut]) for i, l in shown))
    head = f"{path} ({size_text(size)}, ändrad {when(path.stat().st_mtime)})"
    if start and first:
        shown = lines[start - 1:start - 1 + READ_LINES]
        if not shown:
            return f"{head}: bara {len(lines)} rader."
        end = start + len(shown) - 1
        return (f"{head} – rad {start}–{end} av {len(lines)}:\n"
                + "\n".join(f"{i}: {hide(l[:cut])}" for i, l in enumerate(shown, start)))
    shown = lines[-READ_LINES:]
    if len(lines) > len(shown) or not first:
        head += f" – de sista {len(shown)} raderna"
    return head + ":\n" + "\n".join(hide(l[:cut]) for l in shown)


def grep_text(text, where):
    if not where.is_dir():
        return read_file(where, text)
    out = run(["grep", "-rIinsF", "--max-count=3", "--exclude-dir=.git", "--exclude-dir=.cache",
               "--exclude-dir=node_modules", "--exclude-dir=compatdata", "--exclude-dir=shadercache", "--", text,
               str(where)], 25)
    lines = [l for l in out.splitlines() if allowed(Path(l.split(":", 1)[0]))]
    if not lines:
        return f"Ingen fil i {where} innehåller \"{text}\"."
    files = collections.OrderedDict()
    for l in lines:
        name, rest = l.split(":", 1)
        files.setdefault(name, []).append(hide(rest[:240]))
    result = [f"\"{text}\" finns i {len(files)} filer i {where}" + (" (de första 30)" if len(files) > 30 else "") + ":"]
    for name, hits in list(files.items())[:30]:
        result.append(f"- {name}")
        result += [f"    {h}" for h in hits]
    return "\n".join(result)


# Lines that say nothing about what went wrong and drown the rest (Discord logs 10+ of them a second)
LOG_NOISE = re.compile(r"Content Security Policy|ResizeObserver loop|\[MessageQueue\]|\[MessageActionCreators\]|"
                       r"\[Routing/Utils\]|\[ChannelMessages\]|print_timing|memory_seq_rm|replace notification", re.I)
LOG_GAP = 20  # seconds without a line worth showing


def gap_text(seconds):
    if seconds < 120:
        return f"{seconds:.0f} s"
    if seconds < 7200:
        return f"{seconds / 60:.0f} min"
    return f"{seconds / 3600:.0f} h"


def program_log(name, since="", lines=90):
    """A program's or service's journal lines since the computer started (or since HH:MM), the user's and the
    system's: noise and repeats left out, long pauses shown – where a program hung."""
    seen, entries = set(), []
    span = ["--since", since] if since else ["-b"]
    for args in (["--user-unit", name], ["-u", name], ["-t", name], [f"_COMM={name[:15]}"],
                 ["--user-unit", f"app-{name}*"], ["-t", name.capitalize()]):
        for d in journal([*span, "-n", "3000", *args], 30):
            key = d.get("__CURSOR")
            if key not in seen:
                seen.add(key)
                entries.append(d)
    if not entries:
        return (f"Journalen har inget om \"{name}\" " + (f"sedan {since}" if since else "sedan start")
                + f" (prova ett tjänstnamn – `tjänster {name}` – eller `filer {name}`).")
    entries.sort(key=lambda d: int(d.get("__REALTIME_TIMESTAMP", 0)))
    rows, noise, last_msg, repeats, last_time, last_day = [], 0, None, 0, None, None
    for d in entries:
        msg = text_of(d.get("MESSAGE")).splitlines()
        if not msg or LOG_NOISE.search(msg[0]):
            noise += 1
            continue
        stamp = int(d["__REALTIME_TIMESTAMP"]) / 1e6
        who = text_of(d.get("SYSLOG_IDENTIFIER")) or text_of(d.get("_COMM"))
        level = {"0": "FEL", "1": "FEL", "2": "FEL", "3": "FEL", "4": "varning"}.get(text_of(d.get("PRIORITY")), "")
        same = re.sub(r"\d+", "#", msg[0])
        if same == last_msg:
            repeats += 1
            continue
        if repeats:
            rows.append(f"  (samma rad {repeats} gånger till)")
            repeats = 0
        if last_time and stamp - last_time >= LOG_GAP:
            rows.append(f"  … {gap_text(stamp - last_time)} utan något …")
        day = when(stamp).rsplit(" ", 1)[0]
        if day != last_day:
            rows.append(f"— {day} —")
            last_day = day
        clock = time.strftime("%H:%M:%S", time.localtime(stamp))
        rows.append(f"{clock} {who}{' ' + level if level else ''}: {msg[0][:240]}")
        last_msg, last_time = same, stamp
    if repeats:
        rows.append(f"  (samma rad {repeats} gånger till)")
    first = int(entries[0]["__REALTIME_TIMESTAMP"]) / 1e6
    head = f"Journalen om \"{name}\" från {when(first)}"
    if len(rows) > lines:  # the start, the end, and what matters in between: pauses and errors
        keep = set(range(15)) | set(range(len(rows) - 25, len(rows)))
        for i, row in enumerate(rows):
            if " s utan något " in row:
                keep |= set(range(i - 4, i + 4))
            elif " FEL: " in row or " varning: " in row:
                keep.add(i)
        keep = sorted(i for i in keep if 0 <= i < len(rows))[:lines + 40]
        picked, prev = [], -1
        for i in keep:
            if i > prev + 1:
                picked.append(f"  ({i - prev - 1} rader överhoppade)")
            picked.append(rows[i])
            prev = i
        head += " – början, slutet, pauserna och felen (be om `från <klockslag>` för allt vid en viss tid)"
        rows = picked
    if noise:
        head += f" ({noise} brusrader utan betydelse bortplockade)"
    return head + ":\n" + "\n".join(rows)


def unit_status(name):
    if not run(["systemctl", "--user", "cat", name]) and not run(["systemctl", "cat", name]):
        # "status ollama" said it didn't run – the service is goblincakes-ollama (25 Oct)
        other = ALIASES.get(name.lower()) or f"goblincakes-{name}"
        if run(["systemctl", "--user", "cat", other]) or run(["systemctl", "cat", other]):
            name = other
    user = run(["systemctl", "--user", "status", "--no-pager", "-n", "15", name])
    system = run(["systemctl", "status", "--no-pager", "-n", "15", name])
    text = "\n\n".join(t.strip() for t in (user and "Användarens tjänst:\n" + user, system and "Systemets tjänst:\n" + system) if t)
    return text or f"Ingen tjänst som heter \"{name}\" (lista med `tjänster`)."


def unit_list(match=""):
    out = []
    for scope in (["--user"], []):
        text = run(["systemctl", *scope, "list-units", "--no-pager", "--plain", "--no-legend", "--type=service,timer"])
        rows = [l.split(None, 4) for l in text.splitlines() if l.strip()]
        rows = [r for r in rows if len(r) >= 4 and (not match or match.lower() in " ".join(r).lower())]
        out.append(("Användarens" if scope else "Systemets") + f" tjänster ({len(rows)}):")
        out += [f"- {r[0]}: {r[2]}/{r[3]}" + (f" – {r[4][:80]}" if len(r) > 4 else "") for r in rows[:60]]
    return "\n".join(out)


SEARCH_HELP = """Så här letar du (en rad i blocket):
filer <namn eller *mönster*> [i <mapp>]   – hittar filer/mappar
läs <sökväg> [med <text> | från rad <n>] – slutet av en textfil, raderna med texten, eller från en rad
mapp <sökväg>                           – vad som ligger i en mapp
sök <text> i <mapp>                     – vilka filer som innehåller texten
logg <program eller tjänst> [från HH:MM] – journalen om det sedan start (eller från klockslaget)
status <tjänst>                         – en tjänsts status
tjänster [text]                         – vilka tjänster som körs"""


def describe(query):
    """A ```leta line in plain words, for the steps: "läs ~/x.json" → "Läser ~/x.json"."""
    q = " ".join(query.split())
    word, _, rest = q.partition(" ")
    word = word.lower().rstrip(":")
    m = re.match(r"(.+?)\s+(?:i|från|fran|med)\s+(.+)$", rest)
    first, second = (m.group(1), m.group(2)) if m else (rest, "")
    if word in ("filer", "fil", "hitta", "find"):
        text = f"Letar efter filer som heter {first}" + (f" i {second}" if second else "")
    elif word in ("läs", "las", "read", "cat", "visa"):
        text = f"Läser {rest}"
    elif word in ("mapp", "ls", "lista"):
        text = f"Tittar i {rest or '~'}"
    elif word in ("sök", "sok", "grep"):
        text = f"Söker efter \"{first}\" i {second}" if second else f"Söker efter {rest}"
    elif word in ("logg", "log", "journal", "journalctl"):
        text = f"Läser loggen för {first}" + (f" från {second}" if second else "")
    elif word == "status":
        text = f"Kollar tjänsten {rest}" if rest else "Kollar tjänsterna"
    elif word in ("tjänster", "tjanster", "services"):
        text = "Kollar vilka tjänster som körs"
    elif word == "systemfel":
        text = "Läser datorns fel" + (f" för {rest}" if rest else "")
    else:
        text = f"Letar i datorn: {q}"
    return text[:110]


def look(query):
    """The text for the AI for one ```leta line."""
    q = " ".join(query.split())
    # A slip in the path: "~/ .config/goblincakes/" looked in the wrong place and found nothing (25 Oct)
    q = re.sub(r"(?<=~/)\s+|(?<=/)\s+(?=\.)", "", q)
    word, _, rest = q.partition(" ")
    word = word.lower().rstrip(":")
    try:
        if word in ("filer", "fil", "hitta", "find"):
            m = re.match(r"(.+?)\s+i\s+(/\S.*|~\S*)$", rest)
            where = path_of(m.group(2)) if m else None
            if where and not allowed(where):
                raise SearchError(f"{where} är hemligt (nycklar/lösenord) och läses inte")
            text = find_files((m.group(1) if m else rest).strip("\"'"), where)
        elif word in ("läs", "las", "read", "cat", "visa"):
            line = re.match(r"(.+?)\s+(?:från\s+|fran\s+)?rad\s+(\d+)$", rest)
            m = None if line else re.match(r"(.+?)\s+med\s+(.+)$", rest)
            path = path_of((line or m).group(1) if line or m else rest)
            if not allowed(path):
                raise SearchError(f"{path} är hemligt (nycklar/lösenord) och läses inte")
            text = read_file(path, m.group(2).strip("\"'") if m else "", int(line.group(2)) if line else 0)
        elif word in ("mapp", "ls", "lista"):
            path = path_of(rest or "~")
            if not allowed(path):
                raise SearchError(f"{path} är hemligt (nycklar/lösenord) och läses inte")
            text = list_folder(path)
        elif word in ("sök", "sok", "grep"):
            m = re.match(r"(.+?)\s+i\s+(\S.*)$", rest)
            if not m:
                raise SearchError("skriv sök <text> i <mapp eller fil>")
            where = path_of(m.group(2))
            if not allowed(where):
                raise SearchError(f"{where} är hemligt (nycklar/lösenord) och läses inte")
            text = grep_text(m.group(1).strip("\"'"), where)
        elif word in ("logg", "log", "journal", "journalctl"):
            m = re.match(r"(.+?)\s+(?:från|fran|since|efter)\s+(\d{1,2}[:.]\d{2})$", rest)
            name, since = (m.group(1), m.group(2).replace(".", ":")) if m else (rest, "")
            text = program_log(name.strip("\"'"), since) if name else "Skriv vilket program eller vilken tjänst."
        elif word == "status":
            text = unit_status(rest) if rest else unit_list()
        elif word in ("tjänster", "tjanster", "services"):
            text = unit_list(rest)
        else:
            return f"Förstod inte \"{q}\".\n\n{SEARCH_HELP}"
    except SearchError as e:
        return f"Gick inte: {e}."
    return text if len(text) <= LIMIT else text[:LIMIT] + "\n… (kortat)"


# Goblin AI looks first (24 Oct): a question about the computer that names a program gets that program's
# journal before the AI answers – a small local model picked the wrong tool and guessed instead
ALIASES = {"goblinrecorder": "goblincakes-recorder", "recorder": "goblincakes-recorder",
           "goblinamp": "goblincakes-amp", "kakan": "goblincakes-ollama", "ollama": "goblincakes-ollama",
           "spelläget": "goblincakes-gameguard", "spelvakten": "goblincakes-gameguard", "ianseo": "goblincakes-ianseo",
           "toppfältet": "plasmashell", "dockan": "plasmashell", "skrivbordet": "plasmashell", "ljudet": "pipewire",
           "fönstren": "kwin_wayland", "wow": "goblincakes-gameguard", "warcraft": "goblincakes-gameguard",
           "spelet": "goblincakes-gameguard", "cs2": "goblincakes-gameguard", "uppdateringen": "goblincakes-updates", "uppdateringarna": "goblincakes-updates"}
SKIP_WORDS = {"och", "att", "det", "som", "för", "med", "inte", "var", "den", "har", "kan", "hon", "han", "jag",
              "när", "efter", "innan", "starta", "startar", "startade", "lång", "tid", "logg", "loggen", "fel",
              "datorn", "varför", "vad", "hur", "idag", "förut", "nyss", "system", "systemet", "program", "programmet"}


def program_names():
    """{word in lowercase: name to read the journal with} from the desktop files and the services."""
    names = {}
    for folder in (Path("/usr/share/applications"), HOME / ".local/share/applications",
                   Path("/var/lib/flatpak/exports/share/applications"), HOME / ".local/share/flatpak/exports/share/applications"):
        for f in folder.glob("*.desktop"):
            try:
                text = f.read_text(errors="replace")
            except OSError:
                continue
            exe = re.search(r"^Exec=(?:env \S+ )*(\S+)", text, re.M)
            target = Path(exe.group(1)).name if exe else f.stem
            if target == "flatpak":
                target = f.stem
            if target in ("xdg-open", "sh", "bash", "env", "gtk-launch", "kioclient", "kde-open"):
                continue
            for label in re.findall(r"^Name=(.+)$", text, re.M)[:1] + [f.stem.split(".")[-1]]:
                for w in re.findall(r"[\wåäö+-]{3,}", label.lower()):
                    if w not in SKIP_WORDS:
                        names.setdefault(w, target)
    for scope in (["--user"], []):
        for line in run(["systemctl", *scope, "list-units", "--all", "--plain", "--no-legend", "--type=service"]).splitlines():
            unit = line.split(None, 1)[0] if line.strip() else ""
            base = unit.removesuffix(".service")
            if base and "@" not in base:
                names.setdefault(base.lower(), base)
                for w in base.lower().split("-")[1:] if base.startswith("goblincakes-") else []:
                    names.setdefault(w, base)
    names.update(ALIASES)
    return names


def since_of(question):
    """"runt 17", "kl 16.55", "17:00" → a time a few minutes before; "idag" → today; else ""."""
    m = re.search(r"\b(?:kl\.?|klockan|runt|vid|strax före|strax efter|ca)?\s*(\d{1,2})(?:[:.](\d{2}))?\b(?=\s|$|[,.?!])",
                  question)
    if m and (m.group(2) or re.search(r"\b(?:kl\.?|klockan|runt|vid|ca)\s*" + m.group(1) + r"\b", question)):
        hour, minute = int(m.group(1)), int(m.group(2) or 0)
        if hour < 24 and minute < 60:
            total = max(0, hour * 60 + minute - 5)
            return f"{total // 60:02d}:{total % 60:02d}"
    if re.search(r"\b(?:idag|i dag|imorse|i morse|i förmiddags|i eftermiddag)\b", question, re.I):
        return "today"
    if re.search(r"\b(?:igår|i går|igårkväll|inatt|i natt)\b", question, re.I):
        return "yesterday"
    return ""


PATH_IN_TEXT = re.compile(r"(?<![\w/])(?:~|\$HOME|/(?:home|var|etc|usr|run|tmp|opt|mnt|srv|boot))(?:/[^\s\"'`,;:()]*)?")


# A GOBLINCAKES program's setting ("vilken codec spelar GoblinRecorder in med?"): its settings file – gemma4
# said "låt mig kontrollera recorder.json" and didn't, twice (25 Oct)
OWN_CONFIGS = [(r"goblin\s?recorder|\brecorder|inspelning\w*", "recorder.json"), (r"goblin\s?amp", "amp.json"),
               (r"goblin\s?graph", "graph.json"), (r"mangohud|goblin frames", "mangohud-frames.conf"),
               (r"tiling|\bruto\w*|layout\w*", "tile-layouts.json")]
SETTING_WORDS = re.compile(r"inställ\w*|codec|kvalitet\w*|fps|bildfrekvens|upplösning\w*|sparar|spelar\s+in|mikrofon\w*|"
                           r"ljud\w*|bitrate|format\w*|\bpå\b|\bav\b|aktiv\w*|påslag\w*", re.I)


def named_paths(question):
    """Paths written in the question (/etc/os-release, ~/.config/x) and disks named with "disk"
    ("Spel-disken") – read before the AI answers (punkt 3, 25 Oct: gemma4 searched the web for /etc/os-release)."""
    paths = [path_of(m.rstrip(".?!")) for m in PATH_IN_TEXT.findall(question) if m not in ("~", "/")]
    if SETTING_WORDS.search(question):
        paths += [HOME / ".config/goblincakes" / f for words, f in OWN_CONFIGS if re.search(words, question, re.I)]
    # "Spel-disken": its folders – not for "a file called … on the disk" (the AI then answered from the listing)
    if re.search(r"disk", question, re.I) and not re.search(r"\bheter\b|\bnamn\w*|\bfil(?:en|er|erna)?\b", question, re.I):
        paths += [d for d in disks() if re.search(rf"\b{re.escape(d.name)}\b", question, re.I)]
    parts, read = [], []
    for path in list(dict.fromkeys(paths))[:2]:
        if not path.exists():
            continue
        try:
            if not allowed(path):
                raise SearchError(f"{path} är hemligt (nycklar/lösenord) och läses inte")
            parts.append(list_folder(path) if path.is_dir() else read_file(path))
        except SearchError as e:
            parts.append(f"Gick inte: {e}.")
        read.append(("mapp " if path.is_dir() else "läs ") + str(path).replace(str(HOME), "~"))
    return "\n\n".join(parts)[:LIMIT], read


def gather(question):
    """What Goblin AI reads by itself for a question about the computer: (text, [what was read])."""
    text, read = named_paths(question)
    if read:
        return text, read
    names = program_names()
    asked = [w for w in re.findall(r"[\wåäö+-]{3,}", question.lower()) if w not in SKIP_WORDS]
    found = []
    for w in asked:
        target = names.get(w) or names.get(w.removesuffix("s")) or names.get(re.sub(r"(?:en|et|n)$", "", w))
        if target and target not in found:
            found.append(target)
    if not found and not re.search(r"\b(?:datorn|systemet|krasch\w*|logg\w*|journal\w*|tjänst\w*)\b", question, re.I):
        return "", []
    since = since_of(question)
    parts, read = [], []
    for target in found[:2]:
        parts.append(program_log(target, since))
        read.append(f"logg {target}" + (f" från {since}" if since else ""))
    if not found or re.search(r"krasch|kraschar|kraschade|fel\b|felet|errors?", question, re.I):
        parts.append(system_errors(found[0] if found else ""))
        read.append("systemfel " + (found[0] if found else ""))
    text = "\n\n".join(parts)
    return (text if len(text) <= LIMIT + 3000 else text[:LIMIT + 3000] + "\n… (kortat)"), read

if __name__ == "__main__":
    import sys
    if sys.argv[1:2] == ["samla"]:
        text, read = gather(" ".join(sys.argv[2:]))
        print(read, "\n", text)
    elif sys.argv[1:2] == ["leta"]:
        print(look(" ".join(sys.argv[2:])))
    else:
        print(system_errors(" ".join(sys.argv[1:])))
