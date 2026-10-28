"""MCP for Kakan (point 8 of Kakan's plan, 28 Oct): ready-made tools from outside. A server is a program in a
podman container (stdio, the user's choice 28 Oct – no Node/uv on the computer) or an address (HTTP).

    python3 mcp.py lista                         the servers and their tools
    python3 mcp.py kör <server> <tool> '<json>'  one call (the Tillåt card for tools that change something)
    python3 mcp.py github <token>                adds GitHub's official server (read only)
    python3 mcp.py webbläsare                    adds Microsoft's Playwright server (a browser in a container)

The servers are in ~/.config/goblincakes/mcp.json in the same form as Claude Code's and Claude Desktop's
(mcpServers: {name: {command, args, env} | {url, headers}}) so a server's README line can be copied in, plus our
own fields: "av" (off), "verktyg" (the tools that are on – the local AI's memory can't take all of them), "om" (a
line for the model, e.g. the user's account), "direkt" (tools that run without Tillåt although the server doesn't
mark them read-only). Secrets live in mcp.env (0600) and are used as ${NAME} in env and
headers. Tools the server marks read-only run at once, the rest become a Tillåt card. The tool lists are cached
(listing them would start every container on every question); a server starts on its first call and stops after
IDLE seconds or when a game starts. Only the standard library."""

import atexit
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(1, str(HERE.parent))  # gaming.py
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "goblincakes"
STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "goblincakes/ai"
CONFIG_FILE = CONFIG / "mcp.json"
SECRETS_FILE = CONFIG / "mcp.env"
CACHE_FILE = STATE / "mcp-verktyg.json"
PROTOCOL = "2025-06-18"
IDLE = 300  # seconds an unused server is kept
CALL_TIMEOUT = 60
START_TIMEOUT = 60  # podman may pull the image on the first start
DESC_MAX = 400  # characters of a tool's description the model gets
ENUM_MAX = 12  # longer lists of choices are left out of the schema (GitHub's 33 event types)
ANSWER_MAX = 12000

GITHUB = {
    "command": "podman",
    "args": ["run", "-i", "--rm", "--pull=missing", "-e", "GITHUB_PERSONAL_ACCESS_TOKEN", "-e", "GITHUB_READ_ONLY=1",
             "-e", "GITHUB_TOOLSETS=context,repos,issues,actions", "ghcr.io/github/github-mcp-server", "stdio"],
    "env": {"GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"},
    "namn": "GitHub",
    # Questions with these words go to the server first – "gick senaste bygget igenom?" searched the web for
    # "goblincakes" and read the computer's update log instead (28 Oct)
    "ord": ["github", "bygget", "bygge", "byggen", "byggena", "commit", "commits", "issue", "issues",
            "repot", "repo", "workflow", "actions", "release", "pull request", "build"],
    # ~700 tokens each before slimming – a few, the rest can be turned on under AI-tjänster
    "verktyg": ["actions_list", "get_job_logs", "list_commits", "get_commit", "get_file_contents", "list_issues",
                "issue_read", "get_latest_release"],
}

# Microsoft's official Playwright server (del 2, 28 Oct): a headless Chromium in its own container – no logins, no
# files from the computer. A page Kakan opens stays open between calls until the server stops (IDLE).
PLAYWRIGHT = {
    "command": "podman",
    "args": ["run", "-i", "--rm", "--init", "--pull=missing", "mcr.microsoft.com/playwright/mcp"],
    "namn": "Webbläsaren",
    "ord": ["playwright", "webbläsare", "klicka", "klickar"],
    # Opening and looking at pages at once; clicking, typing and keys can send something (Tillåt)
    "sidan": "browser_snapshot",  # the tool that shows the page, called after the ones that only link it
    "direkt": ["browser_navigate", "browser_navigate_back", "browser_tabs"],
    "verktyg": ["browser_navigate", "browser_navigate_back", "browser_snapshot", "browser_find", "browser_wait_for",
                "browser_click", "browser_type", "browser_press_key", "browser_select_option", "browser_tabs"],
    "om": "En egen webbläsare i en container, utan användarens inloggningar. Öppna sidan med browser_navigate; svaret "
          "visar sidans innehåll med ref-nummer (ref=e12) som browser_click/browser_type tar i fältet target. Använd den när en "
          "sida måste klickas på eller fyllas i – bara läsa en sida går fortare med las_sida.",
}
PRESETS = {"github": GITHUB, "webblasare": PLAYWRIGHT}


class McpError(Exception):
    pass


# ── Settings ──

def load_config():
    try:
        servers = json.loads(CONFIG_FILE.read_text()).get("mcpServers") or {}
    except (OSError, ValueError):
        return {}
    return {name: s for name, s in servers.items() if isinstance(s, dict)}


def save_config(servers):
    CONFIG.mkdir(parents=True, exist_ok=True)
    try:
        whole = json.loads(CONFIG_FILE.read_text())
    except (OSError, ValueError):
        whole = {}
    whole["mcpServers"] = servers
    CONFIG_FILE.write_text(json.dumps(whole, ensure_ascii=False, indent=2) + "\n")


def load_secrets():
    out = {}
    try:
        for line in SECRETS_FILE.read_text().splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                name, value = line.split("=", 1)
                out[name.strip()] = value.strip()
    except OSError:
        pass
    return out


def save_secret(name, value):
    secrets = load_secrets()
    if value:
        secrets[name] = value
    else:
        secrets.pop(name, None)
    CONFIG.mkdir(parents=True, exist_ok=True)
    old = os.umask(0o077)
    try:
        SECRETS_FILE.write_text("# MCP-servrarnas nycklar (bara läsbar för dig) – används som ${NAMN} i mcp.json\n"
                                + "".join(f"{k}={v}\n" for k, v in secrets.items()))
    finally:
        os.umask(old)
    SECRETS_FILE.chmod(0o600)


def expand(value, secrets):
    """${NAME} from mcp.env (or the environment); a missing one is an error, not an empty token."""
    def one(m):
        name = m.group(1)
        if name in secrets:
            return secrets[name]
        if name in os.environ:
            return os.environ[name]
        raise McpError(f"nyckeln {name} saknas (AI-tjänster → MCP-servrar)")
    return re.sub(r"\$\{(\w+)\}", one, str(value))


def word_for(name):
    """The tool's block word / the prefix of its function names: a-z, 0-9, _ (OpenAI-style names)."""
    return "mcp_" + (re.sub(r"[^a-z0-9_]", "_", name.lower()) or "server")


def signature(server):
    return hashlib.sha1(json.dumps({k: server.get(k) for k in ("command", "args", "url")},
                                   sort_keys=True).encode()).hexdigest()[:12]


# ── Talking to a server ──

class Stdio:
    """A server as a program: one JSON-RPC message per line on stdin/stdout."""

    def __init__(self, server, secrets):
        env = dict(os.environ)
        env.update({k: expand(v, secrets) for k, v in (server.get("env") or {}).items()})
        env.pop("ELECTRON_RUN_AS_NODE", None)  # VS Code's terminal (see the notes on Electron programs)
        try:
            self.proc = subprocess.Popen([server["command"], *[str(a) for a in server.get("args") or []]],
                                         stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                         env=env, text=True, bufsize=1)
        except OSError as e:
            raise McpError(f"kunde inte starta {server['command']}: {e}") from e
        self.waiting, self.lock, self.errors = {}, threading.Lock(), []
        threading.Thread(target=self._read, daemon=True).start()
        threading.Thread(target=self._read_errors, daemon=True).start()

    def _read(self):
        for line in self.proc.stdout:
            try:
                msg = json.loads(line)
            except ValueError:
                continue
            slot = self.waiting.get(msg.get("id")) if isinstance(msg, dict) else None
            if slot is not None:
                slot.append(msg)
        for slot in self.waiting.values():
            slot.append(None)

    def _read_errors(self):
        for line in self.proc.stderr:
            self.errors = (self.errors + [line.rstrip()])[-5:]

    def send(self, msg, timeout):
        if self.proc.poll() is not None:
            raise McpError("servern har stängts" + (": " + self.errors[-1] if self.errors else ""))
        slot = []
        if "id" in msg:
            self.waiting[msg["id"]] = slot
        with self.lock:
            try:
                self.proc.stdin.write(json.dumps(msg) + "\n")
                self.proc.stdin.flush()
            except OSError as e:
                raise McpError(f"servern svarar inte: {e}") from e
        if "id" not in msg:
            return None
        end = time.monotonic() + timeout
        while not slot and time.monotonic() < end:
            time.sleep(0.02)
        self.waiting.pop(msg["id"], None)
        if not slot or slot[0] is None:
            why = self.errors[-1] if self.errors else ("tog för lång tid" if not slot else "stängdes")
            raise McpError(f"servern svarade inte ({why})")
        return slot[0]

    def close(self):
        if self.proc.poll() is None:
            try:
                self.proc.stdin.close()
                self.proc.wait(3)
            except (OSError, subprocess.TimeoutExpired):
                self.proc.terminate()


class Http:
    """A server at an address (Streamable HTTP): each message is a POST, the answer JSON or an event stream."""

    def __init__(self, server, secrets):
        self.url = server["url"]
        self.headers = {k: expand(v, secrets) for k, v in (server.get("headers") or {}).items()}
        self.session = None

    def send(self, msg, timeout):
        headers = {"Content-Type": "application/json", "Accept": "application/json, text/event-stream",
                   "MCP-Protocol-Version": PROTOCOL, **self.headers}
        if self.session:
            headers["Mcp-Session-Id"] = self.session
        req = urllib.request.Request(self.url, data=json.dumps(msg).encode(), headers=headers, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                self.session = r.headers.get("Mcp-Session-Id") or self.session
                kind = r.headers.get("Content-Type", "")
                body = r.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            raise McpError(f"servern svarade fel {e.code}" + (" (fel nyckel?)" if e.code in (401, 403) else "")) from e
        except (urllib.error.URLError, OSError) as e:
            raise McpError(f"nådde inte servern: {getattr(e, 'reason', e)}") from e
        if "id" not in msg:
            return None
        if "event-stream" in kind:  # the answer is the data line with our id
            for block in body.split("\n\n"):
                data = "\n".join(line[5:].strip() for line in block.splitlines() if line.startswith("data:"))
                try:
                    found = json.loads(data) if data else None
                except ValueError:
                    continue
                if isinstance(found, dict) and found.get("id") == msg["id"]:
                    return found
            raise McpError("servern svarade inte på frågan")
        try:
            return json.loads(body)
        except ValueError as e:
            raise McpError("servern svarade inte med JSON") from e

    def close(self):
        pass


class Client:
    def __init__(self, name, server):
        secrets = load_secrets()
        self.name, self.next_id, self.used = name, 0, time.monotonic()
        self.wire = Http(server, secrets) if server.get("url") else Stdio(server, secrets)
        try:
            self.info = self.request("initialize", {"protocolVersion": PROTOCOL, "capabilities": {},
                                                    "clientInfo": {"name": "goblincakes-kakan", "version": "1"}},
                                     START_TIMEOUT)
            self.wire.send({"jsonrpc": "2.0", "method": "notifications/initialized"}, 5)
        except McpError:
            self.wire.close()
            raise

    def request(self, method, params=None, timeout=CALL_TIMEOUT):
        self.next_id += 1
        self.used = time.monotonic()
        msg = {"jsonrpc": "2.0", "id": self.next_id, "method": method}
        if params is not None:
            msg["params"] = params
        reply = self.wire.send(msg, timeout)
        if reply.get("error"):
            raise McpError(str(reply["error"].get("message") or reply["error"])[:300])
        return reply.get("result") or {}

    def list_tools(self):
        tools, cursor = [], None
        for _ in range(20):
            got = self.request("tools/list", {"cursor": cursor} if cursor else {})
            tools += got.get("tools") or []
            cursor = got.get("nextCursor")
            if not cursor:
                break
        return tools

    def close(self):
        self.wire.close()


CLIENTS = {}
CLIENTS_LOCK = threading.Lock()


def client(name):
    servers = load_config()
    if name not in servers:
        raise McpError(f"ingen MCP-server som heter {name}")
    with CLIENTS_LOCK:
        c = CLIENTS.get(name)
        if c and isinstance(c.wire, Stdio) and c.wire.proc.poll() is not None:
            c = None
        if not c:
            c = CLIENTS[name] = Client(name, servers[name])
            _watch()
        return c


def close_all():
    with CLIENTS_LOCK:
        for c in CLIENTS.values():
            c.close()
        CLIENTS.clear()


atexit.register(close_all)
_WATCHING = []


def _watch():
    """Closes servers unused for IDLE seconds, and all of them when a game starts (no containers beside WoW)."""
    if _WATCHING:
        return
    _WATCHING.append(True)

    def loop():
        import gaming  # noqa: PLC0415
        while True:
            time.sleep(15)
            playing = gaming.game_running()
            with CLIENTS_LOCK:
                for name, c in list(CLIENTS.items()):
                    if playing or time.monotonic() - c.used > IDLE:
                        c.close()
                        del CLIENTS[name]
    threading.Thread(target=loop, daemon=True).start()


# ── The tools ──

def slim(schema, depth=0):
    """A tool's input schema without what only costs tokens: icons, x-…, long lists of choices, deep nesting."""
    if not isinstance(schema, dict):
        return {"type": "string"}
    out = {k: v for k, v in schema.items() if k in ("type", "description", "enum", "items", "properties", "required",
                                                     "default", "minimum", "maximum")}
    if isinstance(out.get("description"), str):
        out["description"] = " ".join(out["description"].split())[:200]
    if isinstance(out.get("enum"), list) and len(out["enum"]) > ENUM_MAX:
        del out["enum"]
    if "properties" in out:
        if depth >= 2:
            return {"type": "object", **({"description": out["description"]} if "description" in out else {})}
        out["properties"] = {k: slim(v, depth + 1) for k, v in (out["properties"] or {}).items()}
    if "items" in out:
        out["items"] = slim(out["items"], depth + 1)
    if isinstance(out.get("type"), list):  # ["string", "null"] – Ollama wants one
        out["type"] = next((t for t in out["type"] if t != "null"), "string")
    return out


def _load_cache():
    try:
        return json.loads(CACHE_FILE.read_text())
    except (OSError, ValueError):
        return {}


def all_tools(name, refresh=False):
    """[{name, description, schema, readonly}] of a server – from the cache unless refresh or the server changed."""
    server = load_config().get(name)
    if not server:
        return []
    cache = _load_cache()
    got = cache.get(name)
    if not refresh and got and got.get("sig") == signature(server):
        return got["tools"]
    listed = client(name).list_tools()
    tools = [{"name": t["name"], "description": " ".join(str(t.get("description") or t.get("title") or "").split()),
              "schema": slim(t.get("inputSchema") or {"type": "object", "properties": {}}),
              "readonly": bool((t.get("annotations") or {}).get("readOnlyHint"))
                          and not (t.get("annotations") or {}).get("destructiveHint")}
             for t in listed if t.get("name")]
    cache[name] = {"sig": signature(server), "tools": tools, "when": time.strftime("%Y-%m-%d %H:%M")}
    STATE.mkdir(parents=True, exist_ok=True)
    CACHE_FILE.write_text(json.dumps(cache, ensure_ascii=False))
    return tools


def _direct(tools, server):
    """Tools in "direkt" count as read-only (run without Tillåt)."""
    direct = set(server.get("direkt") or [])
    return [{**t, "readonly": t["readonly"] or t["name"] in direct} for t in tools]


def on_tools(name, server=None):
    """The tools that are on: "verktyg" in mcp.json, else all of them."""
    server = server or load_config().get(name) or {}
    wanted = server.get("verktyg")
    cached = (_load_cache().get(name) or {})
    tools = cached.get("tools") if cached.get("sig") == signature(server) else None
    if tools is None:
        return []
    return [t for t in _direct(tools, server) if wanted is None or t["name"] in wanted]


RETRY = 600  # seconds before a server that failed to list its tools is tried again


def for_kakan():
    """The servers that are on: [{server, word, title, about, tools}]. A server added by hand in mcp.json (or
    pasted in the window) has no tool list yet – it is fetched here, once (the user 28 Oct: "dom blir användbara av
    kakan direkt"); one that failed is tried again after RETRY seconds."""
    out = []
    cache = _load_cache()
    for name, server in load_config().items():
        if server.get("av"):
            continue
        got = cache.get(name) or {}
        if got.get("sig") != signature(server) and time.time() - got.get("failed", 0) > RETRY:
            try:
                all_tools(name, refresh=True)
            except McpError as e:
                cache[name] = {"failed": time.time(), "error": str(e)[:200]}
                STATE.mkdir(parents=True, exist_ok=True)
                CACHE_FILE.write_text(json.dumps(cache, ensure_ascii=False))
                print(f"goblin ai: MCP-servern {name} gick inte: {e}", file=sys.stderr)
        tools = on_tools(name, server)
        if tools:
            out.append({"server": name, "word": word_for(name), "title": server.get("namn") or name,
                        "about": str(server.get("om") or ""), "tools": tools,
                        "words": [str(w).lower() for w in [name, server.get("namn") or name, *(server.get("ord") or (PRESETS.get(name) or {}).get("ord") or [])]]})
    return out


def asked_for(question, servers):
    """The server a question is about (its name or one of its words, `ord` in mcp.json, also with a Swedish ending:
    "commitsen", "repots"), else None."""
    text = str(question or "")[:600].lower()
    for s in servers:
        if any(re.search(rf"(?<!\w){re.escape(w)}(?:en|et|n|t|s|ar|arna|er|erna|na)?(?!\w)", text) for w in s.get("words") or [] if w):
            return s
    return None


def result_text(result):
    parts = []
    for c in result.get("content") or []:
        if c.get("type") == "text":
            parts.append(c.get("text", ""))
        elif c.get("type") == "resource":
            parts.append((c.get("resource") or {}).get("text") or f"[fil: {(c.get('resource') or {}).get('uri', '')}]")
        elif c.get("type") == "resource_link":
            parts.append(f"[{c.get('name') or 'länk'}: {c.get('uri', '')}]")
        else:
            parts.append(f"[{c.get('type')}]")
    if not any(p.strip() for p in parts) and result.get("structuredContent") is not None:
        parts = [json.dumps(result["structuredContent"], ensure_ascii=False)]
    text = "\n".join(parts).strip() or "(tomt svar)"
    if result.get("isError"):
        raise McpError(text[:400])
    return text[:ANSWER_MAX] + ("\n[… avkortat]" if len(text) > ANSWER_MAX else "")


def call(name, tool, args):
    text = result_text(client(name).request("tools/call", {"name": tool, "arguments": args or {}}))
    page = (load_config().get(name) or {}).get("sidan")
    if page and tool != page and SNAPSHOT_FILE.search(text):
        # After navigate/click Playwright puts the page in a file inside the container – fetched here so the local
        # model doesn't need one more step to see it
        seen = result_text(client(name).request("tools/call", {"name": page, "arguments": {}}))
        text = SNAPSHOT_FILE.sub("", text).rstrip() + "\n### Snapshot" + seen.split("### Snapshot", 1)[-1]
        text = text[:ANSWER_MAX] + ("\n[… avkortat]" if len(text) > ANSWER_MAX else "")
    return text


SNAPSHOT_FILE = re.compile(r"### Snapshot\n- \[Snapshot\]\([^)]*\)\n?")


RELAY_ENV = "GOBLIN_MCP_SOCKET"
_RELAY = []


def _relay():
    """The Tillåt card runs `mcp.py kör …` as a program of its own – that started a second server, and for the
    browser a new, empty one without the page Kakan had open. So the program Kakan runs in listens on a socket (in
    $XDG_RUNTIME_DIR, only the user can open it) and the card's call is passed on to its servers; the commands it
    runs inherit GOBLIN_MCP_SOCKET."""
    if _RELAY:
        return
    import socket  # noqa: PLC0415
    path = Path(os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}") / f"goblincakes-mcp-{os.getpid()}.sock"
    try:
        path.unlink(missing_ok=True)
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        old = os.umask(0o177)
        try:
            sock.bind(str(path))
        finally:
            os.umask(old)
        sock.listen(4)
    except OSError:
        return
    _RELAY.append(path)
    os.environ[RELAY_ENV] = str(path)
    atexit.register(lambda: path.unlink(missing_ok=True))

    def serve(conn):
        with conn:
            try:
                ask = json.loads(conn.makefile("rb").readline())
                answer = {"text": call(ask["server"], ask["tool"], ask.get("args") or {})}
            except McpError as e:
                answer = {"error": str(e)}
            except (ValueError, KeyError, TypeError) as e:
                answer = {"error": f"felaktig fråga: {e}"}
            try:
                conn.sendall(json.dumps(answer, ensure_ascii=False).encode() + b"\n")
            except OSError:
                pass

    def loop():
        while True:
            conn, _ = sock.accept()
            threading.Thread(target=serve, args=(conn,), daemon=True).start()
    threading.Thread(target=loop, daemon=True).start()


def call_shared(name, tool, args):
    """`mcp.py kör`: through the program Kakan runs in when there is one (same server, same open page), else here."""
    path = os.environ.get(RELAY_ENV)
    if not path:
        return call(name, tool, args)
    import socket  # noqa: PLC0415
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
            sock.settimeout(CALL_TIMEOUT + START_TIMEOUT)
            sock.connect(path)
            sock.sendall(json.dumps({"server": name, "tool": tool, "args": args}, ensure_ascii=False).encode() + b"\n")
            answer = json.loads(sock.makefile("rb").readline())
    except (OSError, ValueError):
        return call(name, tool, args)  # the window was closed: a server of our own
    if answer.get("error"):
        raise McpError(answer["error"])
    return answer.get("text", "")


def line_for(tool, args):
    """The code block's line: `list_commits {"owner": "…"}`."""
    return f"{tool} {json.dumps(args or {}, ensure_ascii=False)}"


def run_line(name, line):
    """Kakan's call: read-only tools at once, the rest as a Tillåt card (python3 mcp.py kör …)."""
    _relay()
    tool, _, rest = line.strip().partition(" ")
    try:
        args = json.loads(rest) if rest.strip() else {}
    except ValueError as e:
        raise McpError(f"fälten är inte JSON: {rest[:100]}") from e
    if not isinstance(args, dict):
        raise McpError("fälten ska vara ett JSON-objekt")
    # The page shows "[ref=e17]" – the local model copied all of it as the click's target (28 Oct)
    args = {k: (m.group(1) if isinstance(v, str) and (m := re.fullmatch(r"\[?ref=(\w+)\]?", v.strip())) else v)
            for k, v in args.items()}
    known = {t["name"]: t for t in on_tools(name)}
    if tool not in known:
        raise McpError(f"{tool} finns inte (eller är avstängt) hos {name}: " + ", ".join(known) if known
                       else f"inga påslagna verktyg hos {name}")
    if known[tool]["readonly"]:
        return call(name, tool, args)
    code = " ".join(shlex.quote(p) for p in ["python3", str(Path(__file__).resolve()), "kör", name, tool,
                                              json.dumps(args, ensure_ascii=False)])
    return ("Det här verktyget ändrar något och kräver Tillåt. Svara med det här kodblocket så får användaren ett "
            f"Tillåt-kort:\n```bash\n{code}\n```")


def add_github(token):
    """GitHub's official server (read only: repos, issues, Actions) with the user's token."""
    save_secret("GITHUB_TOKEN", token.strip())
    servers = load_config()
    servers["github"] = {**GITHUB, **{k: v for k, v in servers.get("github", {}).items() if k in ("verktyg", "av", "om")}}
    save_config(servers)
    tools = all_tools("github", refresh=True)
    try:
        me = json.loads(call("github", "get_me", {})).get("login", "")
    except (McpError, ValueError, AttributeError):
        me = ""
    if me and not servers["github"].get("om"):
        servers["github"]["om"] = f"Användarens GitHub-konto: {me}; GOBLINCAKES-repot: Kaytho-git/goblincakes."
        save_config(servers)
    return tools


def add_playwright():
    """Microsoft's Playwright server (the image is ~1 GB, fetched on the first start)."""
    servers = load_config()
    servers["webblasare"] = {**PLAYWRIGHT, **{k: v for k, v in servers.get("webblasare", {}).items()
                                              if k in ("verktyg", "av")}}
    save_config(servers)
    return all_tools("webblasare", refresh=True)


def add_from_text(text):
    """A server pasted from its README: `{"mcpServers": {"namn": {…}}}`, `"namn": {…}` or `{"command": …}` (then
    named after the image/program). npx/uvx don't exist here – such a line is turned into nothing, with why."""
    text = text.strip().rstrip(",")
    try:
        got = json.loads(text)
    except ValueError:
        try:
            got = json.loads("{" + text + "}")
        except ValueError as e:
            raise McpError("det är inte JSON – klistra in raden ur serverns README (\"namn\": {\"command\": …})") from e
    if isinstance(got, dict) and isinstance(got.get("mcpServers"), dict):
        got = got["mcpServers"]
    if isinstance(got, dict) and ("command" in got or "url" in got):
        base = got.get("url") or next((a for a in reversed(got.get("args") or []) if "/" in str(a) or ":" in str(a)),
                                      got["command"])
        got = {re.sub(r"[^a-z0-9]+", "-", str(base).split("/")[-1].split(":")[0].lower()).strip("-") or "server": got}
    if not isinstance(got, dict) or not got or not all(isinstance(v, dict) and ("command" in v or "url" in v)
                                                       for v in got.values()):
        raise McpError("hittade ingen server (command eller url) i texten")
    for v in got.values():
        if v.get("command") in ("npx", "uvx", "node", "bunx", "deno") and not shutil.which(v["command"]):
            raise McpError(f"{v['command']} finns inte på datorn – ta serverns podman/docker-rad i stället "
                           "(docker run … = podman run …)")
        if v.get("command") == "docker":
            v["command"] = "podman"
    servers = load_config()
    servers.update(got)
    save_config(servers)
    for name in got:
        all_tools(name, refresh=True)
    return list(got)


def set_tool(name, tool, on):
    servers = load_config()
    server = servers.get(name)
    if not server:
        return
    names = [t["name"] for t in all_tools(name)]
    wanted = set(server.get("verktyg") if server.get("verktyg") is not None else names)
    (wanted.add if on else wanted.discard)(tool)
    server["verktyg"] = [n for n in names if n in wanted]
    save_config(servers)


def set_off(name, off):
    servers = load_config()
    if name in servers:
        servers[name]["av"] = bool(off)
        if not off:
            servers[name].pop("av")
        save_config(servers)


def remove(name):
    servers = load_config()
    servers.pop(name, None)
    save_config(servers)
    cache = _load_cache()
    if cache.pop(name, None) is not None:
        CACHE_FILE.write_text(json.dumps(cache, ensure_ascii=False))


def overview():
    """For the window: [{server, title, off, url, error, when, tools: [{name, description, readonly, on}]}]."""
    out, cache = [], _load_cache()
    for name, server in load_config().items():
        got = cache.get(name) or {}
        fresh = got.get("sig") == signature(server)
        wanted = server.get("verktyg")
        out.append({"server": name, "title": server.get("namn") or name, "off": bool(server.get("av")),
                    "error": got.get("error", "") if not fresh else "",
                    "where": server.get("url") or " ".join([server.get("command", ""), *map(str, server.get("args") or [])])[:120],
                    "when": got.get("when", "") if fresh else "",
                    "tools": [{"name": t["name"], "description": t["description"][:160], "readonly": t["readonly"],
                               "on": wanted is None or t["name"] in wanted}
                              for t in _direct(got.get("tools") or [] if fresh else [], server)]})
    return out


def main(argv):
    if argv[:1] in (["kör"], ["kor"]) and len(argv) >= 3:
        try:
            args = json.loads(argv[3]) if len(argv) > 3 else {}
            print(call_shared(argv[1], argv[2], args))
        except (McpError, ValueError) as e:
            print(f"Det gick inte: {e}", file=sys.stderr)
            return 1
        return 0
    if argv[:1] == ["github"] and len(argv) == 2:
        try:
            print(f"GitHub tillagd: {len(add_github(argv[1]))} verktyg.")
        except McpError as e:
            print(f"Det gick inte: {e}", file=sys.stderr)
            return 1
        return 0
    if argv[:1] in (["webbläsare"], ["webblasare"]):
        try:
            print(f"Webbläsaren tillagd: {len(add_playwright())} verktyg.")
        except McpError as e:
            print(f"Det gick inte: {e}", file=sys.stderr)
            return 1
        return 0
    if argv[:1] in (["lista"], []):
        for s in overview():
            print(f"{s['title']} ({s['server']}){' – av' if s['off'] else ''}: {s['where']}")
            for t in s["tools"]:
                print(f"  {'✓' if t['on'] else ' '} {t['name']}{'' if t['readonly'] else '  (Tillåt)'}")
        return 0
    print(__doc__.split("\n\n")[1])
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
