"""GOBLINCAKES Dashboard – whose builds BYGGEN shows (18 Nov, the user: "andra som använder gc ska kunna se sina egna
byggen" – anyone's GitHub repos, not only GOBLINCAKES'). Only reads GitHub. Saved in ~/.config/goblincakes/github.json
(0600): {user, token, repos [owner/name]} – never in the repo or the image. No file = the GOBLINCAKES repo when it is
on this computer (the builder's view as before), otherwise nothing.

    python3 github.py status | set (JSON {user, token} on stdin – tries it, lists the repos) | repos
                      | choose (JSON {repos} on stdin) | forget-key | forget

A key is only needed for private repos or many repos (GitHub: 60 questions an hour without one, 5000 with):
github.com/settings/personal-access-tokens/new – read access to Actions and Contents is enough.
"""
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "goblincakes"
FILE = CONFIG / "github.json"
API = os.environ.get("GOBLINCAKES_GITHUB_API", "https://api.github.com").rstrip("/")   # tests: another server
TOKEN_PAGE = "https://github.com/settings/personal-access-tokens/new"
MAX_REPOS = 8


class GithubError(RuntimeError):
    pass


def _ai():
    """buildstatus.py and knowledge.py (ai/) – next to this folder in the repo and in the image."""
    ai = Path(__file__).resolve().parent.parent / "ai"
    if str(ai) not in sys.path:
        sys.path.insert(0, str(ai))


def load():
    try:
        data = json.loads(FILE.read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def save(data):
    CONFIG.mkdir(parents=True, exist_ok=True)
    tmp = FILE.with_suffix(".tmp")
    tmp.touch(mode=0o600)
    os.chmod(tmp, 0o600)
    tmp.write_text(json.dumps(data, indent=1))
    tmp.replace(FILE)


def own_repo():
    """The GOBLINCAKES repo when it is cloned here (the one who builds GOBLINCAKES), else ""."""
    _ai()
    try:
        import buildstatus  # noqa: PLC0415
        return buildstatus.REPO if buildstatus.builder() else ""
    except Exception:  # noqa: BLE001
        return ""


def chosen():
    """[owner/name] – the repos BYGGEN shows."""
    data = load()
    if isinstance(data.get("repos"), list):
        return [r for r in data["repos"] if isinstance(r, str) and r.count("/") == 1][:MAX_REPOS]
    own = own_repo()
    return [own] if own else []


def key():
    """The key for GitHub: the one saved here, else Kakan's (GITHUB_TOKEN in her secrets) – "" = none."""
    tok = load().get("token") or ""
    if tok:
        return tok
    _ai()
    try:
        import buildstatus  # noqa: PLC0415
        return buildstatus.token()
    except Exception:  # noqa: BLE001
        return ""


def get(path, tok=None):
    """GitHub's JSON for an API path (/repos/…) – GithubError with a readable text when it does not work."""
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "goblincakes-dashboard",
               "X-GitHub-Api-Version": "2022-11-28"}
    tok = key() if tok is None else tok
    if tok:
        headers["Authorization"] = f"Bearer {tok}"
    req = urllib.request.Request(path if "://" in path else API + path, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        if e.code in (403, 429) and e.headers.get("X-RateLimit-Remaining") == "0":
            raise GithubError("GitHubs gräns för frågor är nådd (60 i timmen utan nyckel) – försök igen om en stund") from e
        if e.code == 401:
            raise GithubError("GitHub-nyckeln stämmer inte (fel eller för gammal)") from e
        if e.code == 404:
            raise GithubError("Hittades inte på GitHub (fel namn, eller privat utan nyckel)") from e
        raise GithubError(f"GitHub svarade {e.code}") from e
    except (OSError, ValueError) as e:
        raise GithubError("Kom inte fram till GitHub – nätet?") from e


def list_repos(user, tok=""):
    """[{repo, name, private, pushed}] newest push first – the user's own repos (with a key also private ones and the
    ones in their organisations)."""
    if tok:
        rows = get("/user/repos?per_page=100&sort=pushed&affiliation=owner,collaborator,organization_member", tok)
    else:
        rows = get(f"/users/{urllib.parse.quote(user)}/repos?per_page=100&sort=pushed&type=owner", "")
    return [{"repo": r.get("full_name", ""), "name": r.get("name", ""), "private": bool(r.get("private")),
             "pushed": r.get("pushed_at") or ""} for r in rows if isinstance(r, dict) and r.get("full_name")]


def set_account(user, tok):
    """Try the name (and key) and save them – the repos already chosen stay. → {user, repos (the list to choose from)}."""
    user, tok = (user or "").strip().lstrip("@"), (tok or "").strip() or load().get("token") or ""
    if tok:   # with a key: the key's own account (and its private repos)
        user = get("/user", tok).get("login") or user
    if not user:
        raise GithubError("Skriv ditt GitHub-namn (eller klistra in en nyckel)")
    if not tok:
        get(f"/users/{urllib.parse.quote(user)}", "")
    repos = list_repos(user, tok)
    data = load()
    data.update({"user": user, "token": tok})
    if "repos" not in data:
        data["repos"] = chosen()   # what BYGGEN showed so far (the GOBLINCAKES repo for its builder) stays chosen
    save(data)
    return {"user": user, "repos": repos}


def choose(repos):
    data = load()
    data["repos"] = [r for r in repos if isinstance(r, str) and r.count("/") == 1][:MAX_REPOS]
    save(data)
    _forget_cache()


def _forget_cache():
    """The dashboard's saved builds – read again with the new repos."""
    try:
        (Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "goblincakes/dashboard-builds.json").unlink()
    except OSError:
        pass


def status():
    data = load()
    return {"user": data.get("user", ""), "hasKey": bool(data.get("token")), "chosen": chosen(),
            "own": own_repo(), "tokenPage": TOKEN_PAGE, "max": MAX_REPOS}


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "status"
    try:
        if what == "status":
            result = status()
        elif what == "set":
            d = json.loads(sys.stdin.read() or "{}")
            result = dict(set_account(d.get("user"), d.get("token")), ok=True, **{k: v for k, v in status().items()
                                                                                 if k != "user"})
        elif what == "repos":
            data = load()
            if not data.get("user"):
                raise GithubError("Inget GitHub-namn sparat")
            result = dict(status(), ok=True, repos=list_repos(data["user"], data.get("token") or ""))
        elif what == "choose":
            choose(json.loads(sys.stdin.read() or "{}").get("repos") or [])
            result = dict(status(), ok=True)
        elif what == "forget-key":
            data = load()
            data.pop("token", None)
            save(data)
            result = dict(status(), ok=True)
        elif what == "forget":
            FILE.unlink(missing_ok=True)
            _forget_cache()
            result = dict(status(), ok=True)
        else:
            sys.exit(__doc__)
    except GithubError as e:
        result = dict(status(), ok=False, why=str(e))
    print(json.dumps(result, ensure_ascii=False, indent=1))
