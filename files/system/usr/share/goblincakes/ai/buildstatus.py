"""Build status (point 16 of Kakan's plan, 28 Oct): GOBLINCAKES's builds on GitHub (build.yml, build-iso.yml) –
which failed and why. Kakan's watch service (reminders.py) looks every 10 minutes and gives a notice when a build
has failed (the user's rule 28 Oct: no notice when all is fine), only on a computer with the repo (the one who
builds GOBLINCAKES), and not mid-game – it is told after the game.

    python3 buildstatus.py          the latest builds and why a failed one failed (the tool byggstatus)
    python3 buildstatus.py check    look now, notice for a new failure

Without login GitHub shows which variant and step failed; the reason (the build log's lines before the error) needs
a GitHub key – the one Kakan's GitHub MCP server uses (mcp.env GITHUB_TOKEN), only sent to api.github.com. Kept in
~/.local/state/goblincakes/byggstatus.json. Only the standard library."""

import calendar
import json
import os
import re
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

REPO = "Kaytho-git/goblincakes"
API = f"https://api.github.com/repos/{REPO}"
WORKFLOWS = {"build.yml": "Bygget", "build-iso.yml": "ISO-bygget"}
STATE = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "goblincakes" / "byggstatus.json"
LOOK = 600  # seconds: 2 questions per look, GitHub allows 60 an hour without login
REASON_LINES = 14
ANSI = re.compile(r"\x1b\[[0-9;]*m")
# BlueBuild's log: "<time> [hh:mm:ss ghcr.io/…/<image>:latest] => #57 56.15 <the step's own line>"
STEP_LINE = re.compile(r"=> #(\d+) (?:[\d.]+ )?(.*)$")
NOISE = re.compile(r"^\s*(?:\[\s*\d+/\d+\]|-{20,}|\d+(?:\.\d+)?\s*%|Downloading|Running transaction$)")  # dnf's progress


def token():
    try:
        import mcp  # noqa: PLC0415
        return mcp.load_secrets().get("GITHUB_TOKEN", "")
    except Exception:  # noqa: BLE001
        return ""


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k):
        return None  # the log's own address (Azure) must not get the GitHub key


def get(path, key=None, raw=False):
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "goblincakes-kakan"}
    key = token() if key is None else key
    if key:
        headers["Authorization"] = f"Bearer {key}"
    req = urllib.request.Request(path if "://" in path else API + path, headers=headers)
    if raw:  # the log: GitHub answers 302 to a short-lived address, fetched without the key
        try:
            urllib.request.build_opener(_NoRedirect).open(req, timeout=30)
        except urllib.error.HTTPError as e:
            if e.code not in (301, 302, 303, 307) or not e.headers.get("Location"):
                raise
            with urllib.request.urlopen(e.headers["Location"], timeout=60) as r:
                return r.read().decode(errors="replace")
        return ""
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)


def runs(workflow, n=5):
    return get(f"/actions/workflows/{workflow}/runs?branch=main&per_page={n}").get("workflow_runs", [])


def variant(job_name):
    """"Build Custom Image (recipe-nvidia-legacy.yml)" → "goblincakes-nvidia-legacy"."""
    m = re.search(r"recipe(-[\w-]+)?\.yml", job_name)
    return f"goblincakes{m.group(1) or ''}" if m else job_name


def reason(log):
    """The failing build step's last lines before BlueBuild's own error boxes (dnf's conflict, a script's error)."""
    lines = [ANSI.sub("", line) for line in log.splitlines()]
    failed = next((m.group(1) for line in lines if (m := re.search(r"=> #(\d+) ERROR:", line))), None)
    if failed:
        own = [m.group(2) for line in lines if (m := STEP_LINE.search(line)) and m.group(1) == failed]
        cut = next((i for i, line in enumerate(own) if line.startswith("Error: nu::") or "Failed 'script' Module" in line
                    or line.startswith("ERROR:")), len(own))
        own = [line for line in own[:cut] if line.strip() and not NOISE.match(line)]
    else:  # a failure outside the image build (sign-in, cosign …): the lines before GitHub's ##[error]
        end = next((i for i, line in enumerate(lines) if "##[error]" in line), len(lines))
        own = [re.sub(r"^\S+Z ", "", line) for line in lines[max(0, end - REASON_LINES):end]]
    return "\n".join(line[:300] for line in own[-REASON_LINES:])


def failure(run, key=None):
    """[{variant, step, reason, url}] for a failed run's failed jobs."""
    out = []
    for job in get(f"/actions/runs/{run['id']}/jobs", key).get("jobs", []):
        if job.get("conclusion") != "failure":
            continue
        step = next((s["name"] for s in job.get("steps", []) if s.get("conclusion") == "failure"), "?")
        why = ""
        if key is None:
            key = token()
        if key:
            try:
                why = reason(get(f"/actions/jobs/{job['id']}/logs", key, raw=True))
            except (OSError, ValueError) as e:
                why = f"(loggen gick inte att läsa: {e})"
        out.append({"variant": variant(job.get("name", "")), "job": job.get("name", ""), "step": step,
                    "reason": why, "url": job.get("html_url", run.get("html_url", ""))})
    return out


def when(stamp):
    import systools  # noqa: PLC0415
    try:
        return systools.when(calendar.timegm(time.strptime(stamp, "%Y-%m-%dT%H:%M:%SZ")))
    except (TypeError, ValueError):
        return stamp


RESULT = {"success": "lyckades", "failure": "MISSLYCKADES", "cancelled": "avbröts (ett nyare bygge tog över)",
          "skipped": "hoppades över", "timed_out": "tog för lång tid"}


def describe(fails):
    out = []
    for f in fails:
        out.append(f"  {f['variant']}: steget \"{f['step']}\" misslyckades ({f['url']})")
        if f["reason"]:
            out.append("  Orsak ur byggloggen:\n" + "\n".join("    " + line for line in f["reason"].splitlines()))
        else:
            out.append("  (Orsaken står i byggloggen – den kräver GitHub-nyckeln från Goblin AI:s GitHub-server.)")
    return out


def report(query=""):
    """The text for the AI: the latest builds, and why the newest failed one failed."""
    out = []
    try:
        for workflow, title in WORKFLOWS.items():
            items = runs(workflow, 20)
            shown = items[:5 if workflow == "build.yml" else 2]
            failed = next((r for r in items if r.get("conclusion") == "failure"), None)
            if failed and failed not in shown:  # "varför misslyckades bygget i förmiddags?" – older than the newest
                shown = shown + ["…", failed]
            out.append(f"{title} ({workflow}) – de senaste:")
            for r in shown:
                if r == "…":
                    out.append("- … (senaste misslyckade:)")
                    continue
                state = RESULT.get(r.get("conclusion") or "", "pågår" if r.get("status") != "completed" else "?")
                out.append(f"- {when(r.get('created_at', ''))}, commit {r.get('head_sha', '')[:7]} "
                           f"\"{r.get('display_title', '')[:70]}\" ({r.get('event')}): {state}")
                if r is failed:  # only the newest failure: the log is big
                    out += describe(failure(r))
                    if items[0].get("conclusion") == "success" and items[0] is not failed:
                        out.append("  Senare byggen lyckades – felet är rättat (eller gick över av sig självt).")
            if not failed:
                out.append(f"  Inget av de {len(items)} senaste misslyckades.")
    except (OSError, ValueError) as e:
        out.append(f"GitHub gick inte att fråga: {e}")
    return "\n".join(out)


def load():
    try:
        return json.loads(STATE.read_text())
    except (OSError, ValueError):
        return {}


def save(data):
    STATE.parent.mkdir(parents=True, exist_ok=True)
    tmp = STATE.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False))
    tmp.replace(STATE)


def builder():
    """The repo is on this computer: the one who builds GOBLINCAKES (others get no build notices)."""
    try:
        import knowledge  # noqa: PLC0415
        return knowledge.find_repo() is not None
    except Exception:  # noqa: BLE001
        return False


def check(notify=True):
    """New failed runs since last look → a notice each. The first look ever only remembers what is there."""
    data = load()
    seen = set(data.get("seen", []))
    try:
        import reminders  # noqa: PLC0415
        watched = {i.get("sha") for i in reminders.load() if i.get("kind") == "bygge"}
    except Exception:  # noqa: BLE001
        watched = set()
    first = not data
    new = []
    for workflow, title in WORKFLOWS.items():
        for r in runs(workflow, 5):
            if r.get("status") != "completed" or r["id"] in seen:
                continue
            seen.add(r["id"])
            if r.get("conclusion") == "failure" and not first and r.get("head_sha") not in watched:  # `bevaka bygge` tells
                new.append((title, r))
    save({"seen": sorted(seen)[-50:], "at": time.time()})
    for title, r in new:
        fails = failure(r)
        if notify:
            tell(title, r, fails)
    return new


def commit(ref=""):
    """The full commit id on GitHub (the newest on main without one); "" when GitHub has no such commit."""
    try:
        return get(f"/commits/{ref.strip() or 'main'}").get("sha", "")
    except urllib.error.HTTPError as e:
        if e.code in (404, 422):
            return ""
        raise


def build_state(sha):
    """("none" | "running" | "done", the commit to follow) for build.yml's run of a commit. Cancelled because a
    newer push took over (same concurrency group): the newest run on main, which has this commit too."""
    items = get(f"/actions/workflows/build.yml/runs?head_sha={sha}&per_page=5").get("workflow_runs", [])
    if not items:
        return "none", sha
    live = [r for r in items if r.get("conclusion") != "cancelled"]
    if not live:
        newest = runs("build.yml", 1)
        if newest and newest[0]["head_sha"] != sha and newest[0]["created_at"] > items[0]["created_at"]:
            return "running", newest[0]["head_sha"]
        return "done", sha
    return ("done" if live[0].get("status") == "completed" else "running"), sha


def tell_watched(item, notice):
    """`bevaka bygge`: the build someone waited for is done – told either way (they asked for it)."""
    items = get(f"/actions/workflows/build.yml/runs?head_sha={item['sha']}&per_page=5").get("workflow_runs", [])
    run = next((r for r in items if r.get("conclusion") != "cancelled"), items[0] if items else None)
    note = f"\n{item['note']}" if item.get("note") else ""
    if not run:
        notice("Bygget", f"Inget bygge på GitHub för commit {item['arg']} efter 3 timmar.{note}")
    elif run.get("conclusion") == "success":
        notice("Bygget är klart", f"Commit {item['arg']} \"{run.get('display_title', '')[:80]}\" lyckades – "
               f"den nya versionen kan hämtas (goblin update).{note}", actions=[("open", "Öppna på GitHub")],
               on_action=lambda c: c == "open" and subprocess.Popen(["xdg-open", run["html_url"]], start_new_session=True))
    elif run.get("conclusion") == "failure":
        tell("Bygget", run, failure(run))
    else:
        notice("Bygget", f"Bygget för commit {item['arg']} {RESULT.get(run.get('conclusion') or '', 'slutade')}.{note}")


def tell(title, run, fails):
    import reminders  # noqa: PLC0415
    names = ", ".join(f["variant"] for f in fails) or "?"
    first = next((line for f in fails for line in f["reason"].splitlines()
                  if re.search(r"error|fel|failed|conflict|not found|denied", line, re.I)), "")
    body = f"{names} – steget \"{fails[0]['step'] if fails else '?'}\"" + (f"\n{first.strip()[:200]}" if first else "")
    question = (f"{title} på GitHub misslyckades ({when(run.get('created_at', ''))}, commit "
                f"{run.get('head_sha', '')[:7]} \"{run.get('display_title', '')[:80]}\"):\n" + "\n".join(describe(fails)) +
                "\n\nFörklara kort på vanlig svenska vad som gick fel och om det är något i GOBLINCAKES kod eller hos "
                "någon annan (Fedora, Universal Blue, GitHub). Du ändrar inte koden i repot – säg vad Claude behöver "
                "veta, och föreslå Skicka till Claude.")
    url = run.get("html_url", "")
    reminders.notice(f"{title} misslyckades", body, actions=[("ask", "Fråga Kakan"), ("open", "Öppna på GitHub")],
                     on_action=lambda c: subprocess.Popen(["goblin-ai", "--ask", question], start_new_session=True)
                     if c == "ask" else c == "open" and subprocess.Popen(["xdg-open", url], start_new_session=True))


if __name__ == "__main__":
    if sys.argv[1:2] == ["check"]:
        print(f"{len(check())} nya misslyckade byggen")
        for t in threading.enumerate():  # the notice's thread waits for the click
            if t is not threading.main_thread():
                t.join()
    else:
        print(report(" ".join(sys.argv[1:])))
