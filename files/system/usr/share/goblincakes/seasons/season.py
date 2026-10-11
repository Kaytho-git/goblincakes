"""season – which seasonal look GOBLINCAKES has today (shared by goblincakes-season, the
windows' logos and fastfetch). Periods in seasons.json (month-day, both days included,
may wrap over the new year); a season counts only when its folder has the pictures.
On purpose not mentioned anywhere users read – it is a surprise.
"""
import json
import os
from datetime import date
from pathlib import Path

DIR = Path(os.environ.get("GOBLINCAKES_SEASONS", "/usr/share/goblincakes/seasons"))


def _md(text):
    m, d = text.split("-")
    return int(m), int(d)


OFF_FILE = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "goblincakes" / "season-off"


def chosen_off(sid):
    """Has the user switched this season's look off (Config → Inställningar → Utseende)?"""
    try:
        return OFF_FILE.read_text().strip() == sid
    except OSError:
        return False


def set_off(sid, off):
    """off=True: the ordinary look for the rest of this season. The next season starts as a
    surprise again (the file names only this one)."""
    if off:
        OFF_FILE.parent.mkdir(parents=True, exist_ok=True)
        OFF_FILE.write_text(sid + "\n")
    else:
        try:
            OFF_FILE.unlink()
        except OSError:
            pass


def current(today=None, user=True):
    """The season id for today, or "" for the ordinary look. user=False: regardless of the
    user's choice (the login screen shows it to everyone)."""
    sid = season_by_date(today)
    return "" if user and sid and chosen_off(sid) else sid


def season_by_date(today=None):
    if os.environ.get("GOBLINCAKES_SEASON") is not None:  # tests: pretend
        return os.environ["GOBLINCAKES_SEASON"]
    today = today or date.today()
    md = (today.month, today.day)
    try:
        seasons = json.loads((DIR / "seasons.json").read_text())
    except (OSError, ValueError):
        return ""
    for s in seasons:
        start, end = _md(s["from"]), _md(s["to"])
        inside = start <= md <= end if start <= end else (md >= start or md <= end)
        if inside and (DIR / s["id"] / "wallpaper.svg").exists():
            return s["id"]
    return ""


def asset(name, default):
    """The season's version of a picture (logo.svg, fastfetch-logo.png …), else default."""
    sid = current()
    if sid and (DIR / sid / name).exists():
        return str(DIR / sid / name)
    return default
