"""Goblin AI's commands in three levels (point 4 of Kakan's plan, 25 Oct; the user: "hon ska kunna hjälpa mig att
fixa saker, inte förstöra"):

- "read": only reads (ls, cat, journalctl, systemctl status, nvidia-smi …) – run at once, the AI sees the output.
- "change": everything else – a card with Tillåt / Nej; logged with how it is undone (backups of files first).
- "danger": can't be undone (rm, mkfs, dd, rpm-ostree rebase, chmod -R, curl | bash …) – never run from Goblin AI.
  Deleting goes through the trash (`gio trash`), which is a change and can be undone.

"read" is an allow-list: a block is only "read" when every command in it is known to only read, with arguments that
are known not to write – anything this reader doesn't understand fully is "change"."""

import json
import os
import re
import shlex
import shutil
import subprocess
import time
import urllib.parse
from pathlib import Path

HOME = Path.home()
STATE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "goblincakes/ai"
LOG_FILE = STATE / "kommandon.jsonl"
BACKUPS = STATE / "sakerhetskopior"
LOG_KEEP = 500
BACKUP_MAX = 20 * 1024 * 1024  # bigger files are not copied (the undo says so)
AUTO_TIMEOUT = 30  # seconds a command run at once may take


# ── Danger: can't be undone – never run ──────────────────────────────────────

_CMD = r"(?<![\w.$/-])(?:\S*/)?"  # a command word: at a word start, maybe with its path (/usr/bin/rm)
_WRITES = r"(?:>|\btee\b|\bsed\s+(?:\S+\s+)*?-i|\b(?:cp|mv|install|ln|touch|nano|vi|vim|kate)\b)[^\n]*"  # …then the path
DANGER = [
    (_CMD + r"(?:rm|shred|unlink|srm|wipe)(?=\s|$|;|\))", "tar bort filer för gott – använd papperskorgen: gio trash"),
    (r"(?<![\w-])--?delete(?:-\w+)?\b", "tar bort filer för gott – använd papperskorgen: gio trash"),
    (r"\bgio\s+(?:remove|rm)\b|\bgio\s+trash\b[^\n;&|]*--empty|\btrash-(?:empty|rm)\b|\bkioclient\d?\s+remove\b",
     "tar bort för gott (tömmer papperskorgen)"),
    (_CMD + r"truncate(?=\s)", "tömmer en fil för gott"),
    (_CMD + r"(?:mkfs(?:\.\w+)?|mke2fs|mkswap|wipefs|fdisk|sfdisk|cfdisk|gdisk|sgdisk|parted|blkdiscard|cryptsetup"
     r"|dd|badblocks|hdparm|flashrom|nvme)(?=\s|$)", "ändrar en disk direkt (kan radera allt på den)"),
    (r"\bof=/dev/|>\s*/dev/(?!null\b|stderr\b|stdout\b|tty\b|fd/)", "skriver direkt till en enhet"),
    (r"\brpm-ostree\s+(?:\S+\s+)*?(?:reset|rebase|cleanup|kargs|deploy|initramfs|usroverlay|override\s+remove)\b"
     r"|\bostree\s+admin\b|\bbootc\s+(?:switch|install)\b",
     "byter eller rensar hela systemet (kan ta bort vägen tillbaka)"),
    (_CMD + r"(?:grub2?-install|grub2?-mkconfig|grubby|efibootmgr|dracut|bootctl\s+(?:install|remove))(?=\s|$)",
     "ändrar hur datorn startar"),
    (r"\bmokutil\s+(?:\S+\s+)*?--(?:delete|reset|disable-validation|enable-validation|import|password)\b",
     "ändrar Secure Boot-nycklarna"),
    (_CMD + r"(?:chmod|chown|chgrp|setfacl)\s+(?:\S+\s+)*?(?:-\w*R\w*|--recursive)\b", "ändrar rättigheter på allt i en mapp"),
    (_CMD + r"(?:chmod|chown|chgrp)\s+[^\n;&|]*\s/(?!home/|var/home/|run/media/|tmp/)\w",
     "ändrar rättigheter på systemfiler"),
    (_CMD + r"chattr(?=\s)", "ändrar filattribut (kan låsa filer)"),
    (_CMD + r"(?:passwd|chpasswd|usermod|userdel|useradd|groupdel|groupmod|visudo)(?=\s|$)|/etc/(?:shadow|sudoers)",
     "ändrar användare, lösenord eller sudo"),
    (_WRITES + r"/etc/(?:fstab|crypttab|passwd|group|default/grub)\b", "ändrar en fil som datorn behöver för att starta"),
    (r"\b(?:curl|wget)\b[^\n;]*\|\s*(?:sudo\s+)?(?:\S*/)?(?:ba|z|da|fi)?sh\b|\b(?:curl|wget)\b[^\n;]*\|\s*(?:sudo\s+)?python"
     r"|\b(?:ba|z)?sh\s+<\(\s*(?:curl|wget)|\$\(\s*(?:curl|wget)\b",
     "kör ett skript direkt från nätet"),
    (r"\bgit\s+(?:\S+\s+)*?(?:reset\s+--hard|clean\b|push\s+(?:\S+\s+)*?(?:-f\b|--force)|branch\s+-D\b"
     r"|stash\s+(?:drop|clear)|checkout\s+--\s+\.)", "slänger ändringar i git för gott"),
    (r"\bcrontab\s+(?:\S+\s+)*?-r\b|\bkill\s+(?:-\S+\s+)*-1(?=\s*(?:$|[;&|]))|\bkillall5\b|:\(\)\s*\{", "stänger allt eller rensar för gott"),
    (r"\bsystemctl\s+(?:\S+\s+)*?(?:mask|disable|stop)\s+(?:\S+\s+)*?(?:sddm|display-manager|dbus|polkit|NetworkManager"
     r"|systemd-logind|plasma-plasmashell|plasma-kwin|rpm-ostreed|goblincakes-update)",
     "stänger av något datorn behöver (inloggning, nätverk, skrivbordet eller uppdateringar)"),
    (r"\bpodman\s+(?:\S+\s+)*?(?:system\s+reset|volume\s+(?:rm|prune)|rm\s+(?:\S+\s+)*?-\w*v)",
     "tar bort sparad data i containrar (t.ex. Ianseo)"),
    (r"\bflatpak\s+(?:uninstall|remove)\b[^\n;&|]*(?:--all|--delete-data)", "tar bort alla program eller deras data"),
    (r"\bmv\s+[^\n;&|]*\s/dev/null\b", "tar bort filer för gott"),
    (_WRITES + r"(?:/boot/|/usr/lib/ostree|/sysroot)", "ändrar systemets startfiler"),
]
DANGER = [(re.compile(p), why) for p, why in DANGER]


def code_blocks_in(text):
    """The ```bash blocks in an answer (a command card counts as looking into it)."""
    return re.findall(r"```(?:bash|sh|shell|console)\s*\n(.*?)```", text, re.S)


def danger_reason(code):
    """Why the block can't be undone, or ""."""
    for rx, why in DANGER:
        if rx.search(code):
            return why
    return ""


# ── Reading the shell text: simple commands, words and redirections ──────────

class Unsure(Exception):
    """Something in the block this reader doesn't understand fully – the block is a "change"."""


SAFE_VARS = {"HOME", "USER", "LOGNAME", "PWD", "SHELL", "LANG", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME",
             "XDG_CACHE_HOME", "XDG_RUNTIME_DIR", "UID"}
VAR_DEFAULTS = {"HOME": str(HOME), "XDG_CONFIG_HOME": str(HOME / ".config"), "XDG_DATA_HOME": str(HOME / ".local/share"),
                "XDG_STATE_HOME": str(HOME / ".local/state"), "XDG_CACHE_HOME": str(HOME / ".cache"),
                "UID": str(os.getuid())}


def _var(name):
    if name not in SAFE_VARS:
        raise Unsure(f"använder ${name}")
    return os.environ.get(name) or VAR_DEFAULTS.get(name, "")


def split_commands(code):
    """The block's simple commands: [(words, redirections)], split at ; && || | and new lines.
    A word is {"t": text, "glob": unquoted * ? [}; a redirection is (fd, op, target)."""
    commands, words, redirs = [], [], []
    cur, glob, pending = None, False, None  # the word being read; pending = a redirection waiting for its target
    i, n = 0, len(code)

    def end_word():
        nonlocal cur, glob, pending
        if cur is None:
            return
        if pending:
            redirs.append((*pending, cur))
            pending = None
        else:
            words.append({"t": cur, "glob": glob})
        cur, glob = None, False

    def end_command():
        nonlocal words, redirs
        end_word()
        if pending:
            raise Unsure("en omdirigering utan mål")
        if words or redirs:
            commands.append((words, redirs))
        words, redirs = [], []

    while i < n:
        c = code[i]
        if c in " \t":
            end_word()
        elif c == "\n":
            end_command()
        elif c == "\\":
            if i + 1 < n and code[i + 1] == "\n":
                i += 1
            elif i + 1 < n:
                cur = (cur or "") + code[i + 1]
                i += 1
        elif c == "'":
            j = code.find("'", i + 1)
            if j < 0:
                raise Unsure("ett citattecken som inte stängs")
            cur = (cur or "") + code[i + 1:j]
            i = j
        elif c == '"':
            j, part = i + 1, ""
            while j < n and code[j] != '"':
                if code[j] == "\\" and j + 1 < n and code[j + 1] in '$`"\\\n':
                    part += code[j + 1] if code[j + 1] != "\n" else ""
                    j += 2
                    continue
                if code[j] == "`":
                    raise Unsure("kör ett kommando inuti kommandot")
                if code[j] == "$":
                    value, j = _dollar(code, j)
                    part += value
                    continue
                part += code[j]
                j += 1
            if j >= n:
                raise Unsure("ett citattecken som inte stängs")
            cur = (cur or "") + part
            i = j
        elif c == "`":
            raise Unsure("kör ett kommando inuti kommandot")
        elif c == "$":
            value, j = _dollar(code, i)
            cur = (cur or "") + value
            i = j - 1
        elif c == "#" and cur is None:
            j = code.find("\n", i)
            i = (n if j < 0 else j) - 1
        elif c == ";":
            if code[i + 1:i + 2] == ";":
                raise Unsure(";;")
            end_command()
        elif c == "&":
            if code[i + 1:i + 2] == "&":
                end_command()
                i += 1
            elif code[i + 1:i + 2] == ">":
                end_word()
                op = "&>>" if code[i + 2:i + 3] == ">" else "&>"
                pending = ("", op)
                i += len(op) - 1
            else:
                raise Unsure("startar något i bakgrunden")
        elif c == "|":
            end_command()
            if code[i + 1:i + 2] in "|&" and i + 1 < n:
                i += 1
        elif c in "<>":
            fd = ""
            if cur is not None and cur.isdigit() and not glob:
                fd, cur = cur, None
            end_word()
            m = re.match(r"<<<|<<-?|<>|<&|<|>>|>&|>\||>", code[i:])
            op = m.group(0)
            if op.startswith("<<") or op == "<>":
                raise Unsure("läser text inuti kommandot (<<)")
            pending = (fd, op)
            i += len(op) - 1
        elif c in "(){}!":
            raise Unsure(f"använder {c}")
        elif c in "*?[":
            cur = (cur or "") + c
            glob = True
        elif c == "~" and cur is None and (i + 1 == n or code[i + 1] in "/ \t\n;|&"):
            cur = str(HOME)
        elif c == "~" and cur is None:
            raise Unsure("~användare")
        else:
            cur = (cur or "") + c
        i += 1
    if pending and cur is None:
        raise Unsure("en omdirigering utan mål")
    end_command()
    return commands


def _dollar(code, i):
    """$NAME or ${NAME} at i: (its value, index after it). Anything else ($(…), $1, ${x:-…}) is Unsure."""
    m = re.match(r"\$(?:\{([A-Za-z_]\w*)\}|([A-Za-z_]\w*))", code[i:])
    if not m:
        if code[i + 1:i + 2] == "(":
            raise Unsure("kör ett kommando inuti kommandot")
        raise Unsure("använder $")
    return _var(m.group(1) or m.group(2)), i + len(m.group(0))


# ── Read: the allow-list ──────────────────────────────────────────────────

def _opts(args):
    """The arguments before a lone "--" (after it nothing is an option)."""
    return args[:args.index("--")] if "--" in args else args


def has_opt(args, shorts="", longs=()):
    """Is any of the short (letters, also in a cluster like -tKn) or long options among the arguments?"""
    for a in _opts(args):
        if a.startswith("--"):
            if a.split("=", 1)[0] in longs:
                return True
        elif a.startswith("-") and len(a) > 1 and any(ch in shorts for ch in a[1:]):
            return True
    return False


def positional(args, with_value=()):
    """The arguments that aren't options (options in with_value take the next argument as their value)."""
    out, skip = [], False
    for k, a in enumerate(args):
        if skip:
            skip = False
        elif a == "--":
            out += args[k + 1:]
            break
        elif a.startswith("-") and len(a) > 1:
            skip = a in with_value
        else:
            out.append(a)
    return out


def deny(shorts="", longs=()):
    return lambda args: "en flagga som ändrar" if has_opt(args, shorts, longs) else ""


def sub(*allowed, with_value=(), none_ok=True):
    """The first non-option argument (the subcommand) must be one of these."""
    def rule(args):
        p = positional(args, with_value)
        if not p:
            return "" if none_ok else "utan underkommando"
        return "" if p[0] in allowed else f"underkommandot {p[0]}"
    return rule


def at_most(count):
    """At most this many non-option arguments (uniq/xxd: the second one is a file they write)."""
    return lambda args: "" if len(positional(args)) <= count else "skriver till en fil"


def only(*allowed):
    """Every argument is one of these."""
    return lambda args: "" if all(a in allowed for a in args) else "en flagga som kan ändra"


def _all(*rules):
    def rule(args):
        for r in rules:
            why = r(args)
            if why:
                return why
        return ""
    return rule


def _nvidia_smi(args):
    values = {"-i", "--id", "-d", "--display"}
    ok = re.compile(r"^(-q|--query|-L|--list-gpus|-x|--xml-format|--query-(?:gpu|compute-apps|accounted-apps)=\S+"
                    r"|--format=\S+|--id=\S+|--display=\S+|-[qLx]+)$")
    skip = False
    for a in args:
        if skip:
            skip = False
        elif a in values:
            skip = True
        elif not ok.match(a):
            return f"{a} kan ändra grafikkortet"
    return ""


def _ip(args):
    p = positional(args)
    if not p:
        return ""
    if p[0] not in {"a", "addr", "address", "l", "link", "r", "route", "n", "neigh", "neighbour", "rule", "maddr", "-br"}:
        return f"ip {p[0]}"
    return "" if len(p) == 1 or p[1] in {"show", "s", "list", "ls", "get"} else f"ip {p[0]} {p[1]}"


def _nmcli(args):
    objects = {"general", "g", "gen", "device", "dev", "d", "connection", "con", "c", "wifi", "status"}
    for a in positional(args, with_value={"-f", "--fields", "-g", "--get-values", "-m", "--mode", "-e", "--escape"}):
        if a in {"show", "s", "list", "l"}:
            return ""
        if a not in objects:
            return f"nmcli {a}"
    return ""


def _sed(args):
    """Only `sed -n 'A,Bp' file` (print lines): sed can also write files (-i, w, e)."""
    if any(a.startswith("-") and a not in ("-n", "--quiet", "--silent", "-E", "-r") for a in _opts(args)):
        return "en flagga som kan ändra"
    if not has_opt(args, "n", ("--quiet", "--silent")):
        return "sed utan -n"
    p = positional(args)
    script_ok = re.compile(r"^(?:\d+|\$)(?:,(?:\d+|\$))?p$|^/[^/;]*/(?:,/[^/;]*/)?p$")
    return "" if p and all(script_ok.match(part.strip()) for part in p[0].split(";")) else "ett sed-skript som kan ändra"


def _git(args):
    if has_opt(args, "c", ("--exec-path", "--output", "--config-env")):
        return "en flagga som kan köra eller skriva"
    p = positional(args, with_value={"-C", "--git-dir", "--work-tree"})
    if not p:
        return ""
    if p[0] == "branch":
        return "" if len(p) == 1 and not has_opt(args, "dDmMcC", ("--delete", "--move", "--copy", "--set-upstream-to",
                                                                   "--unset-upstream", "--edit-description")) else "git branch ändrar"
    if p[0] == "remote":
        return "" if len(p) == 1 else "git remote ändrar"
    ok = {"status", "log", "diff", "show", "rev-parse", "describe", "ls-files", "blame", "shortlog", "reflog"}
    return "" if p[0] in ok and (p[0] != "reflog" or len(p) == 1) else f"git {p[0]}"


def _goblin(args):
    p = positional(args)
    if not p or p[0] in {"fast", "help", "nyheter", "old"} or p == ["tile", "layouts"]:
        return ""
    return "" if p[0] in {"screen", "tile", "discord", "frames"} and len(p) == 1 else f"goblin {p[0]}"


def _podman(args):
    p = positional(args)
    if p[:1] and p[0] in {"ps", "images", "logs", "inspect", "info", "version"}:
        return ""
    return "" if tuple(p[:2]) in {("volume", "ls"), ("volume", "inspect"), ("container", "ls"), ("container", "list"),
                                  ("container", "inspect"), ("image", "ls"), ("image", "list")} else "podman ändrar"


def _rpm(args):
    return "" if args and (re.match(r"^-q\w*$", args[0]) or args[0] in {"--query", "-V", "--verify", "--version"}) \
        else "rpm utan -q"


def _rpm_ostree(args):
    p = positional(args)
    return "" if not p or p[0] == "status" or p[:2] in (["db", "diff"], ["db", "list"]) or args == ["--version"] \
        else f"rpm-ostree {p[0]}"


def _gio(args):
    p = positional(args)
    if p[:1] and p[0] in {"info", "list", "tree", "cat"}:
        return ""
    return "" if p[:1] == ["mime"] and len(p) <= 2 else "gio ändrar"


NO_RULE = None
READ = {
    # files and text – none of them can write a file
    **dict.fromkeys(["ls", "cat", "head", "tail", "wc", "stat", "du", "df", "realpath", "readlink", "basename", "dirname",
                     "grep", "egrep", "fgrep", "zgrep", "zcat", "xzcat", "bzcat", "zstdcat", "cut", "tr", "column", "nl",
                     "diff", "cmp", "md5sum", "sha1sum", "sha256sum", "sha512sum", "b2sum", "strings", "tac", "rev",
                     "base64", "jq", "hexdump", "od", "fold", "fmt", "expand", "paste", "join", "comm", "lsattr",
                     "getfacl", "numfmt", "echo", "printf", "test", "[", "true", "false", "seq", "sleep", "cd", "pwd"],
                    NO_RULE),
    "file": deny("C", ("--compile",)),
    "sort": deny("o", ("--output", "--compress-program")),
    "uniq": at_most(1),
    "xxd": at_most(1),
    "tree": deny("o"),
    "sed": _sed,
    "iconv": deny("o", ("--output",)),
    "rg": deny("", ("--pre", "--pre-glob")),
    "find": lambda a: next((f"find {x}" for x in a if x in {"-delete", "-exec", "-execdir", "-ok", "-okdir", "-fprint",
                                                            "-fprint0", "-fprintf", "-fls"}), ""),
    "which": NO_RULE, "whereis": NO_RULE, "type": NO_RULE, "command": lambda a: "" if a[:1] in (["-v"], ["-V"]) else "command kör",
    # the computer
    **dict.fromkeys(["free", "uptime", "uname", "whoami", "id", "groups", "nproc", "getconf", "arch", "lsblk", "lscpu",
                     "lspci", "lsusb", "lsmod", "modinfo", "findmnt", "blkid", "vmstat", "iostat", "mpstat", "lsof",
                     "ps", "pgrep", "pidof", "printenv", "locale", "glxinfo", "vulkaninfo", "eglinfo", "wayland-info",
                     "xdpyinfo", "lshw", "hwinfo", "dmidecode", "upower", "kreadconfig6", "kreadconfig5", "xdg-user-dir",
                     "last", "lastlog", "w", "who", "users", "pw-dump", "zramctl", "tracepath", "dig", "host", "getent",
                     "ping", "nslookup"], NO_RULE),
    "ss": deny("KD", ("--kill", "--diag")),
    "inxi": deny("U", ("--update",)),
    "sensors": deny("s", ("--set",)),
    "date": deny("s", ("--set",)),
    "hostname": only("-I", "-i", "-f", "-s", "-d", "-A"),
    "env": only(),
    "mount": only(),
    "swapon": only("--show", "-s"),
    "top": lambda a: "" if has_opt(a, "b") else "top utan -b",
    "fuser": deny("k", ("--kill",)),
    "nvidia-smi": _nvidia_smi,
    "ip": _ip,
    "nmcli": _nmcli,
    "kscreen-doctor": only("-o", "--outputs", "-j", "--json", "-i", "--info"),
    "xrandr": only("-q", "--query", "--listmonitors", "--listactivemonitors", "--verbose", "--current", "--prop"),
    "aplay": only("-l", "-L", "--list-devices", "--list-pcms"),
    "gamemoded": only("-s", "--status"),
    "mokutil": only("--sb-state", "--list-enrolled", "--list-new", "--list-delete", "--pk", "--kek", "--db", "--dbx",
                    "--version"),
    # services and logs
    "journalctl": deny("fF", ("--follow", "--vacuum-size", "--vacuum-time", "--vacuum-files", "--rotate", "--flush",
                              "--sync", "--relinquish-var", "--smart-relinquish-var", "--setup-keys", "--update-catalog",
                              "--field")),
    "dmesg": deny("cCDEnw", ("--clear", "--read-clear", "--console-off", "--console-on", "--console-level", "--follow")),
    "systemctl": sub("status", "show", "is-active", "is-enabled", "is-failed", "is-system-running", "list-units",
                     "list-unit-files", "list-timers", "list-sockets", "list-dependencies", "list-jobs", "cat",
                     "get-default", with_value={"-H", "--host", "-M", "--machine", "-t", "--type", "--state", "-p",
                                                "--property", "-n", "--lines", "-o", "--output"}),
    "systemd-analyze": sub("blame", "critical-chain", "time", "calendar", "timespan", "timestamp"),
    "loginctl": sub("list-sessions", "show-session", "session-status", "list-users", "show-user", "user-status",
                    "list-seats"),
    "coredumpctl": _all(sub("list", "info"), deny("o", ("--output",))),
    "udevadm": sub("info", none_ok=False),
    "busctl": sub("list", "status", "tree", "introspect", "get-property"),
    "timedatectl": sub("status", "show", "list-timezones", "timesync-status", "show-timesync"),
    "hostnamectl": sub("status"),
    "localectl": sub("status", "list-locales", "list-keymaps"),
    "resolvectl": sub("status", "query", "statistics"),
    "powerprofilesctl": sub("get", "list", "version"),
    "cpupower": sub("frequency-info", "idle-info", "info", with_value={"-c", "--cpu"}, none_ok=False),
    "fwupdmgr": sub("get-devices", "get-updates", "get-history", "security", "--version", none_ok=False),
    "bootctl": sub("status"),
    # sound and settings
    "pactl": sub("list", "info", "stat", "get-default-sink", "get-default-source", "get-sink-volume", "get-sink-mute",
                 "get-source-volume", "get-source-mute", none_ok=False),
    "wpctl": sub("status", "inspect", "get-volume", none_ok=False),
    "amixer": sub("get", "sget", "scontrols", "scontents", "controls", "contents", "info", with_value={"-c", "-D"}),
    "gsettings": sub("get", "list-keys", "list-recursively", "list-schemas", "list-relocatable-schemas",
                     "list-children", "describe", "range", "writable", with_value={"--schemadir"}, none_ok=False),
    "xdg-mime": sub("query", none_ok=False),
    "xdg-settings": sub("get", "check", none_ok=False),
    "gio": _gio,
    # packages and programs
    "rpm": _rpm,
    "rpm-ostree": _rpm_ostree,
    "flatpak": sub("list", "info", "remotes", "remote-ls", "search", "history", "ps", "--version", none_ok=False),
    "bootc": sub("status", none_ok=False),
    "balooctl6": sub("status", none_ok=False),
    "podman": _podman,
    "distrobox": sub("list", "ls", none_ok=False),
    "toolbox": sub("list", none_ok=False),
    "ollama": sub("list", "ls", "ps", "show", "--version", "-v", none_ok=False),
    "git": _git,
    "goblin": _goblin,
}
# GOBLINCAKES' own helpers that only read (the map tells the AI to run them by hand to see what they answer)
LIBEXEC_READ = {
    "goblincakes-device-battery": only(), "goblincakes-discord-voice": only(), "goblincakes-ai-activity": only(),
    "goblincakes-gameguard": lambda a: "" if a == ["status"] else "gameguard ändrar",
    "goblincakes-vencord": lambda a: "" if a == ["status"] else "vencord ändrar",
    "goblincakes-ianseo": lambda a: "" if len(a) == 2 and a[0] in ("network", "internet") and a[1] in ("status", "url")
    else "ianseo ändrar",
    "goblincakes-gpu": lambda a: "" if a in (["status"], ["hw"]) else "gpu ändrar",
}

# Unquoted * ? [ are fine for these (a file name that starts with - can't make them write); others are a change
GLOB_OK = {"ls", "cat", "head", "tail", "wc", "stat", "du", "grep", "egrep", "fgrep", "zgrep", "zcat", "xzcat",
           "md5sum", "sha1sum", "sha256sum", "sha512sum", "strings", "readlink", "realpath", "lsattr", "getfacl", "echo", "test", "["}


def read_reason(words, redirs):
    """Why this simple command is not only reading, or "" when it is."""
    for fd, op, target in redirs:
        if op in (">&", "<&") and re.fullmatch(r"[0-2-]", target):
            continue
        if op == "<":
            continue
        if op in (">", ">>", ">|", "&>", "&>>") and target == "/dev/null":
            continue
        return f"skriver till {target}"
    if not words:
        return ""
    name, args = words[0]["t"], [w["t"] for w in words[1:]]
    if re.match(r"^[A-Za-z_]\w*=", name):
        return "sätter en variabel"
    if name.startswith("/usr/libexec/goblincakes-") and name[len("/usr/libexec/"):] in LIBEXEC_READ:
        return LIBEXEC_READ[name[len("/usr/libexec/"):]](args)
    if "/" in name:
        return f"kör {name}"
    if name not in READ:
        return f"{name} kan ändra något"
    if any(w["glob"] for w in words) and name not in GLOB_OK:
        return "* eller ? i ett kommando som kan skriva"
    rule = READ[name]
    return rule(args) if rule else ""


def foreign_addon(code):
    """A WoW add-on in the block that isn't the user's own (point 22, the user's decision 29 Oct: only their own are
    changed – BigWigs, EllesmereUI … are only read and explained), or ""."""
    import sys  # noqa: PLC0415
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import wowapi  # noqa: PLC0415
    # a path in quotes may have spaces ("…/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/…")
    for m in re.finditer(r"([\"'])((?:~|/)[^\"']*?/AddOns/[^/\"']+)|(?:^|[\s=])((?:~|/)[^\s\"';&|]*?/AddOns/[^/\s\"';&|)]+)",
                         code, re.M):
        path = m.group(2) or m.group(3)
        if not wowapi.own_addon(path):
            return path.rsplit("/", 1)[-1]
    return ""


def level(code):
    """("read" | "change" | "danger", why) for a ```bash block."""
    why = danger_reason(code)
    if why:
        return "danger", why
    result = _level(code)
    if result[0] != "read" and re.search(r"/_[a-z]+_/AddOns\b", code, re.I):
        # `mv gear …/_retail_/AddOns/` (no Interface/): mv renamed the add-on into a new folder in WoW's install (30 Oct)
        return "danger", ("fel mapp: WoW:s tillägg ligger i …/_retail_/Interface/AddOns (Interface/ saknas) – mv "
                          "döper om mappen när målet inte finns. Ta sökvägen under \"Var tillägget ska ligga\"")
    if result[0] != "read" and "AddOns/" in code:
        name = foreign_addon(code)
        if name:
            return "danger", (f"ändrar i {name}, som är någon annans WoW-tillägg – bara användarens egna får ändras. "
                              "Förklara felet och föreslå att uppdatera tillägget (WowUp) eller säga till den som gjort det")
    return result


def _level(code):
    try:
        commands = split_commands(code)
    except Unsure as e:
        return "change", str(e)
    for words, redirs in commands:
        why = read_reason(words, redirs)
        if why:
            return "change", why
    return ("read", "") if commands else ("change", "tomt")


# ── Undo: what is noted (and copied) before a change runs ────────────────

def _expand(word, cwd):
    word = word.strip("'\"")
    word = re.sub(r"\$\{?(HOME|USER|XDG_\w+)\}?", lambda m: os.environ.get(m.group(1)) or VAR_DEFAULTS.get(m.group(1), ""),
                  word)
    if word.startswith("~"):
        word = str(HOME) + word[1:]
    return Path(word) if word.startswith("/") else Path(cwd) / word


def _words(line):
    try:
        return shlex.split(line, comments=True)
    except ValueError:
        return line.split()


def _masked(text):
    """The text with everything inside quotes replaced by x (same length): operators in `sed 's|a|b|'` or
    `echo "a > b"` aren't pipes or redirections (the undo split at the | in s|…|…| and trashed "s", 25 Oct)."""
    out, quote, i = [], None, 0
    while i < len(text):
        ch = text[i]
        if quote:
            if ch == quote:
                quote = None
                out.append(ch)
            elif ch == "\\" and quote == '"' and i + 1 < len(text):
                out.append("xx")
                i += 1
            else:
                out.append("x")
        elif ch in "'\"":
            quote = ch
            out.append(ch)
        elif ch == "\\" and i + 1 < len(text):
            out.append("xx")
            i += 1
        else:
            out.append(ch)
        i += 1
    return "".join(out)


def _split_unquoted(raw):
    """A line split at ; && || | outside quotes."""
    mask, parts, start = _masked(raw), [], 0
    for m in re.finditer(r"&&|\|\||;|\|", mask):
        parts.append(raw[start:m.start()].strip())
        start = m.end()
    parts.append(raw[start:].strip())
    return parts


def _lines(code):
    """The block's command lines (heredoc text left out), split at ; && || |, with sudo dropped."""
    out, skip_to = [], None
    for raw in code.splitlines():
        if skip_to is not None:
            if raw.strip() == skip_to:
                skip_to = None
            continue
        m = re.search(r"<<-?\s*['\"]?(\w+)['\"]?", raw)
        if m:
            skip_to = m.group(1)
        for part in _split_unquoted(raw):
            part = re.sub(r"^\s*(?:sudo|pkexec)\s+(?:-\S+\s+)*", "", part).strip()
            if part and not part.startswith("#"):
                out.append(part)
    return out


def write_targets(code, cwd):
    """Files the block writes over or into: redirections, tee, sed -i, cp/mv/install destinations."""
    targets = []
    for line in _lines(code):
        mask = _masked(line)  # a > inside quotes isn't a redirection
        for m in re.finditer(r"(?<![<&\d])(?:\d|&)?>>?\|?\s*(\"[^\"]+\"|'[^']+'|[^\s;&|<>()]+)", mask):
            target = line[m.start(1):m.end(1)]
            if target not in ("/dev/null",) and not target.startswith("&"):
                targets.append(target)
        w = _words(re.sub(r"<<-?\s*\S+", "", line))
        if not w:
            continue
        files = [a for a in w[1:] if not a.startswith("-")]
        if w[0] == "tee":
            targets += files
        elif w[0] == "sed" and any(a.startswith("-i") or a.startswith("--in-place") for a in w[1:]) and files:
            targets.append(files[-1])
        elif w[0] in ("cp", "mv", "install", "ln") and len(files) >= 2:
            targets.append(files[-1])
        elif w[0].startswith("python3") and len(files) == 2 and files[0].endswith("/bytatext.py"):
            targets.append(files[1])  # Kakan's byt_text card (30 Oct)
    seen, paths = set(), []
    for t in targets:
        p = _expand(t, cwd)
        if p.is_dir():
            continue
        if str(p) not in seen:
            seen.add(str(p))
            paths.append(p)
    return paths


# ── Flatpak on a card: never a question in the middle, never an app id from memory (28 Oct) ──────────────
# The card's command runs without a terminal: `flatpak install flathub …` asked "system or user?" (flathub is in
# both), got no answer and stopped. And the AI wrote org.kde.tuxpaint (it's org.tuxpaint.Tuxpaint) from memory.

FLATPAK_CHANGE = ("install", "uninstall", "remove", "update", "upgrade")
_flatpak_known = {}


def _flatpak(*args, timeout=15):
    try:
        return subprocess.run(["flatpak", *args], capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        return None


def flatpak_app(app):
    """The app id as Flathub knows it: app itself, the one id a search on its last part finds
    (org.kde.tuxpaint → org.tuxpaint.Tuxpaint), or app unchanged when it can't be told."""
    if app in _flatpak_known:
        return _flatpak_known[app]
    found = app
    r = _flatpak("remote-info", "--user", "flathub", app)
    if r is not None and r.returncode != 0:
        token = app.rsplit(".", 1)[-1].lower()
        s = _flatpak("search", "--columns=application", token)
        ids = [line.strip() for line in (s.stdout if s else "").splitlines() if "." in line]
        hits = [i for i in dict.fromkeys(ids) if i.rsplit(".", 1)[-1].lower() == token]
        if len(hits) == 1:
            found = hits[0]
    _flatpak_known[app] = found
    return found


def tidy(code):
    """A command block made ready for a card: flatpak install/uninstall/update get the installation (--user, as
    GOBLINCAKES Config installs; uninstall/update: where the app is) and --noninteractive --assumeyes, and an
    install's app ids are checked against Flathub. Lines with pipes, variables or several commands are left."""
    out = []
    for line in code.split("\n"):
        w = _words(line)
        sub = next((a for a in w[1:] if not a.startswith("-")), "") if w[:1] == ["flatpak"] else ""
        if sub not in FLATPAK_CHANGE or re.search(r"[;&|`$<>(){}]", line):
            out.append(line)
            continue
        i = w.index(sub)
        opts, args = [a for a in w[1:] if a.startswith("-")], [a for a in w[i + 1:] if not a.startswith("-")]
        if sub == "install":
            args = [flatpak_app(a) if a.count(".") >= 2 else a for a in args]
        if not any(o in ("--user", "--system") or o.startswith("--installation") for o in opts):
            apps = [a for a in args if a.count(".") >= 2]
            if sub == "install":
                opts.insert(0, "--user")
            elif apps:  # without apps (flatpak update) both installations, as before
                r = _flatpak("info", "--user", apps[0], timeout=5)
                opts.insert(0, "--user" if r is not None and r.returncode == 0 else "--system")
        for o in ("--noninteractive", "--assumeyes"):
            if o not in opts and not (o == "--assumeyes" and "-y" in opts):
                opts.append(o)
        indent = line[:len(line) - len(line.lstrip())]
        out.append(indent + shlex.join(["flatpak", sub, *opts, *args]))
    return "\n".join(out)


def _read(cmd):
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
        return out.stdout.strip() if out.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None


SYSTEMCTL_UNDO = {"enable": "disable", "disable": "enable", "start": "stop", "stop": "start", "mask": "unmask",
                  "unmask": "mask"}


def prepare(code, cwd):
    """Before a change runs: copies of the files it writes over and the old values of settings it sets.
    Returns {"undo": [commands, newest first], "hint": text, "trash": [paths moved to the trash]}."""
    stamp = time.strftime("%Y%m%d-%H%M%S")
    undo, hints, trash = [], [], []
    for n, path in enumerate(write_targets(code, cwd)):
        q = shlex.quote(str(path))
        if not path.exists():
            undo.append(f"gio trash {q}")
        elif path.is_file() and path.stat().st_size <= BACKUP_MAX:
            copy = BACKUPS / stamp / f"{n}-{path.name}"
            try:
                copy.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, copy)
                undo.append(f"cp -a {shlex.quote(str(copy))} {q}")
            except OSError:
                hints.append(f"{path} kunde inte kopieras först")
        else:
            hints.append(f"{path} är för stor för en säkerhetskopia")
    for line in _lines(code):
        w = _words(line)
        if not w:
            continue
        cmd, rest = w[0], w[1:]
        pos = [a for a in rest if not a.startswith("-")]
        user = " --user" if "--user" in rest else ""
        if cmd == "gio" and pos[:1] == ["trash"]:
            trash += [str(_expand(p, cwd)) for p in pos[1:]]
        elif cmd == "systemctl" and pos and pos[0] in SYSTEMCTL_UNDO and len(pos) > 1:
            now = " --now" if "--now" in rest else ""
            undo.append(f"systemctl{user} {SYSTEMCTL_UNDO[pos[0]]}{now} " + " ".join(shlex.quote(u) for u in pos[1:]))
        elif cmd == "flatpak" and pos[:1] in (["install"], ["uninstall"], ["remove"]) and len(pos) > 1:
            apps = [a for a in pos[1:] if "." in a]  # app ids (com.discordapp.Discord), not the remote (flathub)
            if apps:
                where = " --user" if "--user" in rest else ""
                again = "uninstall -y" if pos[0] == "install" else "install -y flathub"
                undo.append(f"flatpak{where} {again} " + " ".join(apps))
        elif cmd == "rpm-ostree" and pos[:1] in (["install"], ["uninstall"]) and len(pos) > 1:
            undo.append(f"rpm-ostree {'uninstall' if pos[0] == 'install' else 'install'} " + " ".join(pos[1:]))
            hints.append("gäller efter omstart – rpm-ostree rollback går också tillbaka till förra systemet")
        elif cmd in ("kwriteconfig6", "kwriteconfig5"):
            undo.append(_kconfig_undo(cmd, rest))
        elif cmd == "gsettings" and pos[:1] == ["set"] and len(pos) >= 4:
            old = _read(["gsettings", "get", pos[1], pos[2]])
            if old is not None:
                value = f'"{old}"' if not re.search(r'["$`\\]', old) else shlex.quote(old)  # 'prefer-dark' kept readable
                undo.append(f"gsettings set {pos[1]} {pos[2]} {value}")
        elif cmd == "powerprofilesctl" and pos[:1] == ["set"]:
            old = _read(["powerprofilesctl", "get"])
            if old:
                undo.append(f"powerprofilesctl set {old}")
        elif cmd == "mkdir" and pos:
            undo += [f"rmdir {shlex.quote(str(_expand(p, cwd)))}" for p in pos if not _expand(p, cwd).exists()]
        elif cmd == "mv" and len(pos) == 2 and not _expand(pos[1], cwd).is_dir():
            undo.append(f"mv {shlex.quote(str(_expand(pos[1], cwd)))} {shlex.quote(str(_expand(pos[0], cwd)))}")
        elif cmd == "chmod" and len(pos) >= 2:
            for p in pos[1:]:
                old = _read(["stat", "-c", "%a", str(_expand(p, cwd))])
                if old:
                    undo.append(f"chmod {old} {shlex.quote(str(_expand(p, cwd)))}")
        elif cmd in ("pkill", "killall", "kill"):
            hints.append("ett stängt program startas igen från AppGrid")
        elif cmd in ("reboot", "poweroff") or (cmd == "systemctl" and pos[:1] in (["reboot"], ["poweroff"])):
            hints.append("startar om eller stänger av datorn")
    moved_back = {u.split()[1] for u in undo if u.startswith("mv ")}
    undo = [u for u in undo if u and not (u.startswith("gio trash ") and u.split(" ", 2)[2] in moved_back)]
    if not undo and not trash and not hints:
        hints.append("inget automatiskt sätt att ångra")
    return {"undo": undo[::-1], "hint": "; ".join(dict.fromkeys(hints)), "trash": trash}


def _kconfig_undo(cmd, args):
    """kwriteconfig6 --file F --group G [--group G2] --key K value → the same with the old value (or --delete)."""
    try:
        file = args[args.index("--file") + 1] if "--file" in args else ""
        groups = [args[i + 1] for i, a in enumerate(args) if a == "--group"]
        key = args[args.index("--key") + 1]
    except (ValueError, IndexError):
        return ""
    read = ["kreadconfig6" if cmd.endswith("6") else "kreadconfig5"] + (["--file", file] if file else [])
    for g in groups:
        read += ["--group", g]
    old = _read(read + ["--key", key])
    base = cmd + (f" --file {shlex.quote(file)}" if file else "") + "".join(f" --group {shlex.quote(g)}" for g in groups) \
        + f" --key {shlex.quote(key)}"
    return f"{base} {shlex.quote(old)}" if old else f"{base} --delete"


def _trash_dirs(path):
    """The trash folders a path can go to: the home trash, and the disk's own (.Trash-<uid>) for other disks."""
    dirs = [(Path(os.environ.get("XDG_DATA_HOME", HOME / ".local/share")) / "Trash", None)]
    top = Path(path).parent
    while not os.path.ismount(top) and top != top.parent:
        top = top.parent
    if top != Path("/"):
        dirs += [(top / f".Trash-{os.getuid()}", top), (top / ".Trash" / str(os.getuid()), top)]
    return dirs


def trash_restore(paths):
    """After `gio trash`: the commands that put the paths back (gio trash --restore needs gvfs, which KDE doesn't
    run – the trash is read directly: info/<name>.trashinfo has the original Path, files/<name> the file)."""
    cmds = []
    for path in paths:
        best = None
        for trash, top in _trash_dirs(path):
            for info in (trash / "info").glob("*.trashinfo"):
                try:
                    text = info.read_text()
                except OSError:
                    continue
                m, d = re.search(r"^Path=(.*)$", text, re.M), re.search(r"^DeletionDate=(.*)$", text, re.M)
                if not m:
                    continue
                original = urllib.parse.unquote(m.group(1))
                if top is not None and not original.startswith("/"):
                    original = str(top / original)
                if original == str(path) and (best is None or (d and d.group(1) > best[0])):
                    best = (d.group(1) if d else "", trash, info)
        if best:
            _, trash, info = best
            done = STATE / "papperskorgen-aterstallt"
            cmds.append(f"mkdir -p {shlex.quote(str(done))} && mv -n -- {shlex.quote(str(trash / 'files' / info.stem))} "
                        f"{shlex.quote(str(path))} && mv -- {shlex.quote(str(info))} {shlex.quote(str(done))}/")
    return cmds


def shorten(output, keep=6000, code=""):
    """Long output for the AI: the end (usually what matters) – and how to read the part it didn't get (a 28 KB
    `cat main.qml` hid the line that mattered, 25 Oct). An MCP tool's answer (mcp.py kör) keeps its start instead:
    a page from the browser has its top there – with only the end the local model never saw the newest posts and
    opened the page again and again (28 Oct)."""
    if len(output) <= keep:
        return output
    if re.search(r"/mcp\.py'? '?kör'? ", code):
        return output[:keep] + "\n…(resten utelämnad)"
    return (f"…(början utelämnad: utskriften var {len(output)} tecken, här är bara slutet. Läs en viss del med "
            "`grep -n 'ord' fil` eller `sed -n '100,160p' fil` i stället för hela filen)…\n" + output[-keep:])


# ── The log ─────────────────────────────────────────────────────────

def log(code, lvl, by, exit_code, output, plan=None, conversation=""):
    """One run command in the log (newest last); returns its id."""
    entry = {"id": f"{time.time():.3f}", "t": time.strftime("%Y-%m-%d %H:%M"), "code": code, "level": lvl, "by": by,
             "exit": exit_code, "out": (output or "")[-600:], "conv": conversation}
    if plan:
        entry.update(undo="\n".join(plan.get("undo", [])), hint=plan.get("hint", ""))
    try:
        STATE.mkdir(parents=True, exist_ok=True)
        with LOG_FILE.open("a") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
        lines = LOG_FILE.read_text().splitlines()
        if len(lines) > LOG_KEEP + 100:
            LOG_FILE.write_text("\n".join(lines[-LOG_KEEP:]) + "\n")
    except OSError:
        pass
    return entry["id"]


def load_log(limit=60):
    """The latest runs, newest first."""
    try:
        lines = LOG_FILE.read_text().splitlines()
    except OSError:
        return []
    out = []
    for line in reversed(lines):
        try:
            out.append(json.loads(line))
        except ValueError:
            continue
        if len(out) >= limit:
            break
    return out


def mark_undone(entry_id, output):
    """Notes in the log that a run was undone."""
    try:
        lines = LOG_FILE.read_text().splitlines()
    except OSError:
        return
    for k, line in enumerate(lines):
        try:
            e = json.loads(line)
        except ValueError:
            continue
        if e.get("id") == entry_id:
            e.update(undone=time.strftime("%Y-%m-%d %H:%M"), undo_out=(output or "")[-400:])
            lines[k] = json.dumps(e, ensure_ascii=False)
    LOG_FILE.write_text("\n".join(lines) + "\n")


# ── The setting: run reading commands at once (AI-tjänster, on by default) ─────

AUTORUN_OFF = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "goblincakes/ai-autorun-off"


def autorun():
    return not AUTORUN_OFF.exists()


def set_autorun(on):
    if on:
        AUTORUN_OFF.unlink(missing_ok=True)
    else:
        AUTORUN_OFF.parent.mkdir(parents=True, exist_ok=True)
        AUTORUN_OFF.write_text("")
