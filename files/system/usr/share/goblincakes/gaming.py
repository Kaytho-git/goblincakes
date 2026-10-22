"""What counts as a game running – one rule for all of GOBLINCAKES (22 Oct): Spelläge
(goblincakes-gameguard), the local AI's game watcher (goblincakes-ollama) and through
Spelläge's state file goblin graph and GoblinAmp's bars.

A game = Steam's game wrapper (reaper), a Windows program in Wine/Proton, or gamescope –
not Wine's own helpers and not the launchers: Battle.net (and Blizzard's Agent.exe) is only
used to update the game, World of Warcraft is Wow.exe (the user's words 22 Oct).
Only the standard library.
"""
import re
from pathlib import Path

GAME = re.compile(r"^(reaper|.*\.exe|gamescope|wine.*preloader)$", re.I)
# Wine's own helpers and the launchers – a Battle.net left open is not a game
NOT_GAMES = {"steamwebhelper.exe", "explorer.exe", "services.exe", "winedevice.exe", "plugplay.exe",
             "svchost.exe", "rpcss.exe", "conhost.exe", "start.exe", "tabtip.exe", "battle.net.exe",
             "agent.exe", "steam.exe", "rundll32.exe", "regedit.exe", "wineboot.exe", "winemenubuilder"}
WOW = re.compile(r"^wow[a-z]*\.exe$", re.I)


def processes():
    """(pid, comm, rss kB, parent) of every process."""
    out = []
    for p in Path("/proc").iterdir():
        if not p.name.isdigit():
            continue
        try:
            comm = (p / "comm").read_text().strip()
            stat = (p / "stat").read_text().rsplit(")", 1)[1].split()
            out.append((int(p.name), comm, int(stat[21]) * 4, int(stat[1])))
        except (OSError, IndexError, ValueError):
            continue
    return out


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
    return find_game() is not None
