"""What counts as a game running – one rule for all of GOBLINCAKES (22 Oct): Spelläge
(goblincakes-gameguard), the local AI's game watcher (goblincakes-ollama) and through
Spelläge's state file goblin graph and GoblinAmp's bars.

A game = Steam's game wrapper (reaper), a Windows program in Wine/Proton, or gamescope –
not Wine's own helpers and not the launchers: Battle.net (and Blizzard's Agent.exe) is only
used to update the game, World of Warcraft is Wow.exe (the user's words 22 Oct).
A reaper that runs Proton counts only when a real Windows game runs under it (13 Nov): Battle.net
started from Steam sits under a reaper of its own, so Battle.net alone turned Spelläge on.
Only one part looks (P5 step 2, 13 Nov): goblincakes-gameguard checks every second – also with
Spelläge off – and keeps GAME_FILE fresh ("1" a game runs, "0" none). game_running() reads it while
it is fresh; a stopped or crashed watcher leaves it stale and every caller looks for itself again.
Only the standard library.
"""
import os
import re
import time

GAME = re.compile(r"^(reaper|.*\.exe|gamescope|wine.*preloader)$", re.I)
# Wine's own helpers and the launchers – a Battle.net left open is not a game
NOT_GAMES = {"steamwebhelper.exe", "explorer.exe", "services.exe", "winedevice.exe", "plugplay.exe",
             "svchost.exe", "rpcss.exe", "conhost.exe", "start.exe", "tabtip.exe", "battle.net.exe",
             "xalia.exe",  # Proton's screen-reader helper (13 Nov: it counted as a game)
             "agent.exe", "steam.exe", "rundll32.exe", "regedit.exe", "wineboot.exe", "winemenubuilder"}
_REAPER_ANSWER = {}  # game_running(): {key: the reapers' pids, at, game}
RUNTIME = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
GAME_FILE = os.path.join(RUNTIME, "goblincakes-game")
GAME_FILE_FRESH = 5  # seconds: the watcher touches it every second
WOW = re.compile(r"^wow[a-z]*\.exe$", re.I)


def _comm(pid):
    """The process's name, or None when it is gone. os.listdir + open, not pathlib: half the time
    (P5 step 1, 12 Nov – the watchers ask every 1–3 s)."""
    try:
        with open(f"/proc/{pid}/comm", "rb") as f:
            return f.read().decode(errors="replace").strip()
    except OSError:
        return None


def processes():
    """(pid, comm, rss kB, parent) of every process."""
    out = []
    for name in os.listdir("/proc"):
        if not name.isdigit():
            continue
        try:
            with open(f"/proc/{name}/comm", "rb") as f:
                comm = f.read().decode(errors="replace").strip()
            with open(f"/proc/{name}/stat", "rb") as f:
                stat = f.read().rsplit(b")", 1)[1].split()
            out.append((int(name), comm, int(stat[21]) * 4, int(stat[1])))
        except (OSError, IndexError, ValueError):
            continue
    return out


def _exe(pid):
    """The Windows program's own name from the command line ("wow.exe"), "" for other programs –
    comm is cut at 15 characters ("Cyberpunk2077.e"), argv[0] isn't."""
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            first = f.read().split(b"\0", 1)[0].decode(errors="replace")
    except OSError:
        return ""
    name = first.replace("\\", "/").rsplit("/", 1)[-1].lower()
    return name if name.endswith(".exe") else ""


def _subtree(root, kids):
    tree, todo = set(), [root]
    while todo:
        pid = todo.pop()
        if pid not in tree:
            tree.add(pid)
            todo += kids.get(pid, [])
    return tree


def _launcher_only(reaper, procs, kids):
    """True when the reaper runs Proton but nothing under it is a game – only Wine's helpers and
    launchers (Battle.net from Steam, 13 Nov). A reaper without Proton (CS2) is always a game."""
    tree = _subtree(reaper, kids)
    comms = {p[0]: p[1] for p in procs if p[0] in tree}
    if "wineserver" not in comms.values():
        return False
    for pid in tree:
        name = _exe(pid)
        if name and name not in NOT_GAMES:
            return False
        if not name and GAME.match(comms.get(pid, "")) and comms[pid] != "reaper" \
                and comms[pid].lower() not in NOT_GAMES:
            return False  # gone between the reads, or a name only comm has: count it
    return True


def find_game(procs=None):
    """The game's process: the biggest under Steam's reaper or gamescope, or the Windows game
    itself. None when no game runs."""
    procs = procs if procs is not None else processes()
    hits = [p for p in procs if GAME.match(p[1]) and p[1].lower() not in NOT_GAMES]
    if not hits:
        return None
    kids = {}
    for pid, _, _, parent in procs:
        kids.setdefault(parent, []).append(pid)
    hits = [p for p in hits if p[1] != "reaper" or not _launcher_only(p[0], procs, kids)]
    if not hits:
        return None
    rss = {p[0]: p[2] for p in procs}
    tree = set()
    todo = [p[0] for p in hits]
    while todo:
        pid = todo.pop()
        if pid not in tree:
            tree.add(pid)
            todo += kids.get(pid, [])
    return max(tree, key=lambda pid: rss.get(pid, 0))


def game_running():
    """Is a game running? The watcher's answer (GAME_FILE) while it is fresh, else scan_running()."""
    try:
        if time.time() - os.stat(GAME_FILE).st_mtime < GAME_FILE_FRESH:
            with open(GAME_FILE, "rb") as f:
                answer = f.read().strip()
            if answer in (b"1", b"0"):
                return answer == b"1"
    except OSError:
        pass
    return scan_running()


def write_game_file(running):
    """The watcher (goblincakes-gameguard) only: the answer for everyone else – rewritten (atomically)
    when it changes, otherwise only touched."""
    want = b"1\n" if running else b"0\n"
    try:
        with open(GAME_FILE, "rb") as f:
            same = f.read() == want
    except OSError:
        same = False
    try:
        if same:
            os.utime(GAME_FILE)
        else:
            tmp = f"{GAME_FILE}.{os.getpid()}"
            with open(tmp, "wb") as f:
                f.write(want)
            os.replace(tmp, GAME_FILE)
    except OSError:
        pass


def scan_running():
    """Same answer as find_game() is not None, from the names only – the watcher asks every second.
    Only a reaper alone (Battle.net from Steam, or a Steam game) costs the whole process list."""
    reapers = []
    for name in os.listdir("/proc"):
        if not name.isdigit():
            continue
        comm = _comm(name)
        if comm and GAME.match(comm) and comm.lower() not in NOT_GAMES:
            if comm != "reaper":
                return True
            reapers.append(name)
    if not reapers:
        return False
    # The whole list is ~15 ms: the answer for the same reapers holds 10 s (Wow.exe under Battle.net
    # is seen by its own name at once)
    key = tuple(sorted(reapers))
    if _REAPER_ANSWER.get("key") == key and time.monotonic() - _REAPER_ANSWER["at"] < 10:
        return _REAPER_ANSWER["game"]
    game = find_game() is not None
    _REAPER_ANSWER.update(key=key, at=time.monotonic(), game=game)
    return game
