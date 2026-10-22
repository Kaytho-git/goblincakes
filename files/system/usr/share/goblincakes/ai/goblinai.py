"""goblinai – shared core of Goblin AI (the window /usr/bin/goblin-ai and "goblin ai" in the terminal).

Uses the paid services (Claude, OpenAI, DeepSeek, Grok, Perplexity, Mistral)
when you have a key for them, then the free tiers
of Gemini and OpenRouter (OpenAI-compatible APIs; Claude through its own
Messages API), in that order; when one is out of quota or fails, the next one
answers. With a Tavily key the AI can search the web (Tavily's free
tier; Gemini's own Google search needs a paid plan). Keys:
~/.config/goblincakes/ai.env (only readable by you).
"""
import base64
import getpass
import json
import os
import re
import shlex
import subprocess
import sys
import tempfile
import threading
import time
from datetime import date
import urllib.error
import urllib.request
from pathlib import Path

CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "goblincakes"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "goblincakes"
KEYS_FILE = CONFIG / "ai.env"
MODELS_CACHE = CACHE / "ai-models.json"

PROVIDERS = [
    # Paid: only used when you have put in a key (you pay per question)
    {
        "id": "anthropic", "name": "Claude (betald)", "env": "ANTHROPIC_API_KEY", "paid": True,
        "url": "https://api.anthropic.com/v1",
        "keys_page": "https://platform.claude.com/settings/keys",
        "how": "Betald – du betalar per fråga (förbetalda krediter). Logga in, lägg in krediter under Billing "
               "och tryck på Create Key. Används före gratistjänsterna.",
        "models": ["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"],
    },
    {
        "id": "openai", "name": "OpenAI / ChatGPT (betald)", "env": "OPENAI_API_KEY", "paid": True,
        "url": "https://api.openai.com/v1",
        "keys_page": "https://platform.openai.com/api-keys",
        "how": "Betald – du betalar per fråga (API:et ingår inte i ChatGPT Plus). Logga in, lägg in krediter "
               "under Billing och tryck på Create new secret key. Används före gratistjänsterna.",
        "prefer": [r"^gpt-5(\.\d+)?$", r"^gpt-5(\.\d+)?-mini$", r"^gpt-4\.1$", r"^gpt-4o$"],
        "temperature": None,  # the gpt-5 models only take their default
    },
    {
        "id": "deepseek", "name": "DeepSeek (betald)", "env": "DEEPSEEK_API_KEY", "paid": True,
        "url": "https://api.deepseek.com/v1",
        "keys_page": "https://platform.deepseek.com/api_keys",
        "how": "Betald men mycket billig – bra på kod. Logga in, fyll på under Top up och tryck på Create new API key. "
               "Obs: frågorna hanteras i Kina.",
        "prefer": [r"^deepseek-chat$", r"^deepseek-reasoner$"],
    },
    {
        "id": "xai", "name": "Grok från xAI (betald)", "env": "XAI_API_KEY", "paid": True,
        "url": "https://api.x.ai/v1",
        "keys_page": "https://console.x.ai",
        "how": "Betald – du betalar per fråga. Logga in, lägg in krediter under Billing och skapa en nyckel under API Keys.",
        "prefer": [r"^grok-\d+(\.\d+)?(-\d{4})?$", r"^grok-\d+(\.\d+)?-fast", r"^grok-\d+(\.\d+)?-mini"],
    },
    {
        "id": "perplexity", "name": "Perplexity (betald)", "env": "PERPLEXITY_API_KEY", "paid": True,
        "url": "https://api.perplexity.ai",
        "keys_page": "https://www.perplexity.ai/account/api/keys",
        "how": "Betald – söker själv på nätet och visar källorna (ingen Tavily-nyckel behövs). "
               "Logga in, lägg in krediter under API Billing och tryck på Create Key.",
        "models": ["sonar-pro", "sonar"],
        "no_model_list": True,  # no /models endpoint: the key is tried with a short question
    },
    {
        "id": "mistral", "name": "Mistral (betald)", "env": "MISTRAL_API_KEY", "paid": True,
        "url": "https://api.mistral.ai/v1",
        "keys_page": "https://console.mistral.ai/api-keys",
        "how": "Betald – europeisk, frågorna stannar i EU. Logga in, välj betalplanen under Billing och tryck på Create new key.",
        "prefer": [r"^mistral-large-latest$", r"^mistral-medium-latest$", r"^mistral-small-latest$"],
    },
    {
        "id": "gemini", "name": "Google Gemini", "env": "GEMINI_API_KEY",
        "url": "https://generativelanguage.googleapis.com/v1beta/openai",
        "keys_page": "https://aistudio.google.com/apikey",
        "how": "Logga in med ditt Google-konto och tryck på Create API key.",
        "prefer": [r"^gemini-[\d.]+-flash$", r"^gemini-flash-latest$", r"^gemini-.*flash(?!.*(lite|image|tts|audio|live|thinking))"],
        # last resort when the big models are overloaded
        "fallback": [r"^gemini-[\d.]+-flash-lite$", r"^gemini-flash-lite-latest$"],
    },
    {
        "id": "openrouter", "name": "OpenRouter (gratismodeller)", "env": "OPENROUTER_API_KEY",
        "url": "https://openrouter.ai/api/v1",
        "keys_page": "https://openrouter.ai/settings/keys",
        "how": "Skapa ett gratis konto och tryck på Create Key. Bara gratismodeller används.",
        "prefer": [],  # picked among the free ones, see pick_model
    },
]

# Web search for every service: the AI asks for a search with a ```sök block, we search and answer it
SEARCH = {
    "id": "tavily", "name": "Tavily – sök på nätet", "env": "TAVILY_API_KEY",
    "url": "https://api.tavily.com",
    "keys_page": "https://app.tavily.com/home",
    "how": "Gör att Goblin AI kan söka på nätet när frågan gäller något färskt (nyheter, patchar, priser). "
           "Logga in med ditt Google-konto – nyckeln (tvly-…) står direkt på sidan. Gratis 1 000 sökningar i månaden.",
}
# Pictures from the cloud (16 Oct): free with Cloudflare's daily allowance, the services below only with a key
CLOUDFLARE = {
    "id": "cloudflare", "name": "Cloudflare – bilder (gratis)", "env": "CLOUDFLARE_API_TOKEN",
    "url": "https://api.cloudflare.com/client/v4",
    "keys_page": "https://dash.cloudflare.com/?to=/:account/ai/workers-ai",
    "how": "Gratis bilder från molnet när din dator inte kan rita själv (ett spel kör, eller inget bildprogram) – "
           "ungefär 90 bilder om dagen. Skapa ett gratis konto, gå till Workers AI → REST API → "
           "Create a Workers AI API Token och klistra in nyckeln. Inget betalkort behövs.",
}
SERVICES = PROVIDERS + [CLOUDFLARE, SEARCH]

# Local AI (15 Oct): Ollama on this computer (/usr/libexec/goblincakes-ollama, Goblin AI → AI-tjänster →
# Lokal AI) – no key, nothing leaves the computer. Its place among the services is the user's choice
# ("order" in ~/.config/goblincakes/ollama.json): local first (default), cloud first, only local, only cloud.
LOCAL = {
    "id": "ollama", "name": "Lokal AI", "env": "", "local": True,
    "url": "http://127.0.0.1:11434/v1",
    "temperature": 0.4,
}
LOCAL_CONTEXT = 32768  # OLLAMA_CONTEXT_LENGTH in goblincakes-ollama
LOCAL_MIN_TOKENS = 3000  # answer + thinking at least, even when the question is long
LOCAL_MAX_TOKENS = 8000  # and at most – with room for more, gemma4 thought for 28 000 tokens (13 min, 18 Oct)
OLLAMA_FILE = CONFIG / "ollama.json"
OLLAMA_HELPER = os.environ.get("GOBLINCAKES_OLLAMA_HELPER", "/usr/libexec/goblincakes-ollama")
CODE_WORDS = re.compile(r"```|\b(kod|koden|skript|script|python|lua|php|javascript|bash|html|css|sql|"
                        r"funktion|program(mera|met)?|bugg|felmeddelande|traceback|addon|tillägg)\b", re.I)


def local_settings():
    """{"installed", "order", "roles"} for the local AI; installed = Ollama is set up."""
    try:
        data = json.loads(OLLAMA_FILE.read_text())
    except (OSError, ValueError):
        return {"installed": False, "order": "cloud-only", "roles": {}}
    installed = bool(data.get("dir")) and (Path(data["dir"]) / "bin/ollama").is_file()
    return {"installed": installed, "order": data.get("order") or "local-first", "roles": data.get("roles") or {}}


def providers_in_order(keys, order=None):
    """The services to ask, in order: the local AI before or after the cloud ones (or alone).
    order: a project's own choice (None/"inherit" = the one in AI-tjänster)."""
    cloud = [p for p in PROVIDERS if keys.get(p["env"])]
    local = local_settings()
    order = order if order in ("local-first", "cloud-first", "local-only", "cloud-only") else local["order"]
    if order == "local-only":
        return [LOCAL] if local["installed"] else []
    if not local["installed"] or order == "cloud-only":
        return cloud
    return cloud + [LOCAL] if order == "cloud-first" else [LOCAL] + cloud


# goblincakes-ollama serve stops the local AI entirely while a game runs (and writes this file)
LOCAL_PAUSED = Path(os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}") / "goblincakes-ollama-paused"


# What Goblin AI is busy with, for "Spelas nu" in the top bar (17 Oct, the user's wish – after Meta+§
# the quick box closes and nothing showed that the AI was still working). One file per process and
# thread in $XDG_RUNTIME_DIR/goblincakes-ai/ while a question or a picture is under way:
# {"pid", "kind": "ask"|"image", "text", "local", "progress", "started"}; read by
# /usr/libexec/goblincakes-ai-activity (which skips files of processes that are gone).
ACTIVITY_DIR = LOCAL_PAUSED.parent / "goblincakes-ai"


def _activity_file():
    return ACTIVITY_DIR / f"{os.getpid()}-{threading.get_ident()}.json"


def activity(kind, text, local=False, progress=None):
    path = _activity_file()
    try:
        old = json.loads(path.read_text())
    except (OSError, ValueError):
        old = {}
    data = {"pid": os.getpid(), "kind": kind, "text": text, "local": bool(local),
            "progress": progress, "started": old.get("started") or time.time()}
    try:
        ACTIVITY_DIR.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".tmp")
        tmp.write_text(json.dumps(data, ensure_ascii=False))
        tmp.replace(path)
    except OSError:
        pass


def activity_done():
    try:
        _activity_file().unlink()
    except OSError:
        pass


def start_local():
    """Ollama's user service, when it isn't running (it starts at login, but may have been stopped)."""
    subprocess.run(["systemctl", "--user", "start", "goblincakes-ollama.service"], capture_output=True)
    end = time.time() + 30
    while time.time() < end:
        try:
            urllib.request.urlopen("http://127.0.0.1:11434/api/version", timeout=2).close()
            return True
        except (urllib.error.URLError, OSError):
            time.sleep(0.5)
    return False


def local_models(messages, project=None):
    """The installed models, the one for this question first: code → the "kod" model, else "vardag".
    A project can pick its own models per role and which role comes first (its template)."""
    if LOCAL_PAUSED.exists():
        raise ServiceError("avstängd medan ett spel kör")
    try:
        with urllib.request.urlopen("http://127.0.0.1:11434/v1/models", timeout=5) as r:
            ids = [m["id"] for m in json.loads(r.read()).get("data", [])]
    except (urllib.error.URLError, OSError, ValueError):
        if not start_local():
            raise ServiceError("Ollama startar inte") from None
        return local_models(messages, project)
    if not ids:
        raise ServiceError("ingen modell hämtad än (AI-tjänster → Lokal AI)")
    roles = dict(local_settings()["roles"])
    roles.update({r: m for r, m in ((project or {}).get("models") or {}).items() if m})
    if has_images(messages):
        # A picture: only the models that see pictures, the one for pictures first
        seeing = [m for m in ids if local_sees(m)]
        if not seeing:
            raise ServiceError("ingen hämtad modell kan se bilder – hämta t.ex. qwen3-vl:8b under AI-tjänster → Lokal AI")
        first = [m for m in (roles.get("bild"), roles.get("vardag")) if m in seeing]
        return list(dict.fromkeys(first + seeing))
    question = next((m["content"] for m in reversed(messages) if m["role"] == "user"), "")
    want = [roles.get("kod")] if CODE_WORDS.search(question) else []
    if project and project.get("prefer") in roles:
        want.append(roles.get(project["prefer"]))
    want += [roles.get("vardag"), roles.get("kod"), roles.get("bild")]
    first = [m for m in dict.fromkeys(want) if m and m in ids]
    return first + [m for m in ids if m not in first]


def load_keys():
    keys = {}
    if KEYS_FILE.exists():
        for line in KEYS_FILE.read_text().splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                name, value = line.split("=", 1)
                keys[name.strip()] = value.strip()
    for p in SERVICES:  # environment variables win
        if os.environ.get(p["env"]):
            keys[p["env"]] = os.environ[p["env"]]
    return keys


def save_keys(keys):
    CONFIG.mkdir(parents=True, exist_ok=True)
    old_umask = os.umask(0o077)
    try:
        lines = ["# goblin ai – API keys (only readable by you). Remove a line to stop using that service."]
        lines += [f"{p['env']}={keys[p['env']]}" for p in SERVICES if keys.get(p["env"])]
        KEYS_FILE.write_text("\n".join(lines) + "\n")
    finally:
        os.umask(old_umask)
    KEYS_FILE.chmod(0o600)


class ServiceError(Exception):
    pass


def request(provider, key, path, body=None, timeout=90):
    headers = {"Content-Type": "application/json", "User-Agent": "goblincakes-ai"}
    if provider.get("local"):
        timeout = max(timeout, 600)  # the first question loads the model into the graphics card
    elif provider["id"] == "anthropic":
        headers |= {"x-api-key": key, "anthropic-version": "2023-06-01"}
        if body is not None:
            # A declined question is answered by another Claude model instead of stopping
            headers["anthropic-beta"] = "server-side-fallback-2026-07-01"
    else:
        headers |= {
            "Authorization": f"Bearer {key}",
            # OpenRouter asks apps to say who they are
            "HTTP-Referer": "https://github.com/Kaytho-git/goblincakes",
            "X-Title": "GOBLINCAKES goblin ai",
        }
    req = urllib.request.Request(
        provider["url"] + path,
        data=json.dumps(body).encode() if body is not None else None,
        headers=headers,
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:300]
        if e.code >= 500:
            raise ServiceError(f"överbelastad just nu (fel {e.code})") from None
        if provider.get("paid") and (e.code in (402, 429) or re.search(r"credit balance|insufficient_quota|billing", detail)):
            raise ServiceError("slut på krediter eller för många frågor just nu") from None
        reason = {401: "fel nyckel", 403: "nyckeln får inte användas", 429: "slut på gratisfrågor just nu"}.get(e.code, f"fel {e.code}")
        raise ServiceError(f"{reason} ({detail.strip()})" if e.code not in (401, 429) else reason) from None
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        raise ServiceError(f"nås inte ({getattr(e, 'reason', e)})") from None


def web_search(query, key):
    """Tavily search: [{title, url, content}]."""
    req = urllib.request.Request(
        SEARCH["url"] + "/search",
        data=json.dumps({"query": query, "max_results": 5, "search_depth": "basic"}).encode(),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json",
                 "User-Agent": "goblincakes-ai"},
    )
    try:
        with urllib.request.urlopen(req, timeout=40) as resp:
            data = json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        reason = {401: "fel nyckel", 429: "för många sökningar just nu",
                  432: "månadens gratissökningar är slut", 433: "månadens gratissökningar är slut"}.get(e.code, f"fel {e.code}")
        raise ServiceError(reason) from None
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        raise ServiceError(f"nås inte ({getattr(e, 'reason', e)})") from None
    return [{"title": r.get("title") or r.get("url", ""), "url": r.get("url", ""), "content": (r.get("content") or "")[:1200]}
            for r in data.get("results", []) if r.get("url")]


# Links in an own button's instruction (20 Oct, the user's wish): the pages are read when the button is
# pressed and sent along – Tavily's extract with a key (pages built with JavaScript too), otherwise plain HTML
LINK_RE = re.compile(r"https?://[^\s<>\"')\]]+")
LINKS_MAX, LINK_CHARS = 5, 12000


def links_in(text):
    """The links in a text (a comma or full stop after one is not part of it), at most LINKS_MAX."""
    return list(dict.fromkeys(u.rstrip(".,;:!?") for u in LINK_RE.findall(text)))[:LINKS_MAX]


def read_links(messages, keys, status=None):
    """A button's question ("button" set by goblin-ai) gets, once, the pages of its links and the facts
    of the sports teams it names (ESPN). True when something was added."""
    question = next((m for m in reversed(messages) if m["role"] == "user"), None)
    if not (question or {}).pop("button", False):
        return False
    wish = question["content"].split("\n\n(")[0]
    urls, teams = links_in(wish), ""
    try:
        if sport_tools().find_teams(LINK_RE.sub("", wish)):
            if status:
                status("Hämtar lagen från ESPN…")
            teams = sport_tools().sport_info(LINK_RE.sub("", wish))
    except Exception:  # noqa: BLE001 – the sports data is extra; the question goes anyway
        teams = ""
    if teams:
        question["content"] += "\n\n(Lagens fakta från ESPN, hämtade nu – exakta, utgå från dem:)\n" + teams
    if not urls:
        return bool(teams)
    if status:
        status("Läser länkarna…")
    pages, key = {}, keys.get(SEARCH["env"])
    if key:
        try:
            req = urllib.request.Request(
                SEARCH["url"] + "/extract", data=json.dumps({"urls": urls, "extract_depth": "advanced"}).encode(),
                headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json",
                         "User-Agent": "goblincakes-ai"})
            with urllib.request.urlopen(req, timeout=60) as resp:
                for r in json.loads(resp.read().decode()).get("results", []):
                    if r.get("url") and (r.get("raw_content") or "").strip():
                        pages[r["url"]] = r["raw_content"]
        except (urllib.error.URLError, TimeoutError, OSError, ValueError):
            pass
    for url in urls:
        if url not in pages:
            pages[url] = page_text(url)
    wish = LINK_RE.sub("", wish)
    parts = [f"--- {url} ---\n{relevant_part(pages.get(url) or '', wish) or '(gick inte att läsa)'}" for url in urls]
    question["content"] += ("\n\n(Sidorna i instruktionen, hämtade nu – utgå från dem:)\n" + "\n\n".join(parts))
    return True


QUICK = threading.local()  # .on: the answer needs no thinking (a local model is told not to)


def relevant_part(text, wish):
    """A long page: its beginning (a table's headings) and the parts around the instruction's names
    (Anaheim, Ducks …) – a standings table had the team past the limit."""
    text = text.strip()
    if len(text) <= LINK_CHARS:
        return text
    words = {w for w in re.findall(r"\b[A-ZÅÄÖ][\w'-]{3,}", wish)} - {"Senaste", "Vad", "Hur", "Ge"}
    spans = [(0, 3000)]
    for w in words:
        for m in re.finditer(re.escape(w), text):
            spans.append((max(0, m.start() - 1200), m.end() + 1200))
    spans.sort()
    merged = []
    for a, b in spans:
        if merged and a <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], b)
        else:
            merged.append([a, b])
    # Heading rows: table rows of 3+ cells without digits (the row after one says if a name column has no heading)
    heads = []
    for m in re.finditer(r"^\|([^\n]*)\|[ \t]*\n(\|[^\n]*)?", text, re.M):
        cells = [c.strip() for c in m.group(1).split("|")]
        if len(cells) >= 3 and not any(re.search(r"\d", c) for c in cells) and not all(re.fullmatch(r":?-+:?", c) for c in cells):
            data = next((r for r in text[m.end():m.end() + 2000].splitlines() if re.search(r"\|\s*[\d.]+\s*\|", r)), "")
            if data.count("|") - 1 == len(cells) + 1:
                cells.insert(0, "Namn")
            heads.append((m.start(), "| " + " | ".join(cells) + " |"))
    out, used = [], 0
    for a, b in merged:
        # A part of a table gets the table's heading row (GP, W, L …) – without it the columns were misread
        head = next((h for start, h in reversed(heads) if start < a), "")
        piece = ((head + "\n") if head and a > 0 else "") + text[a:b]
        piece = piece[:LINK_CHARS - used]
        out.append(piece)
        used += len(piece)
        if used >= LINK_CHARS:
            break
    return "\n[…]\n".join(out)


def page_text(url):
    """A page's text without Tavily (no JavaScript – may be almost empty for some sites)."""
    from html.parser import HTMLParser

    class Text(HTMLParser):
        skip, out = 0, []

        def handle_starttag(self, tag, attrs):
            self.skip += tag in ("script", "style", "noscript", "svg")

        def handle_endtag(self, tag):
            self.skip -= tag in ("script", "style", "noscript", "svg") and self.skip > 0

        def handle_data(self, data):
            if not self.skip and data.strip():
                self.out.append(" ".join(data.split()))
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) goblincakes-ai"})
        with urllib.request.urlopen(req, timeout=30) as resp:
            html = resp.read(3_000_000).decode(resp.headers.get_content_charset() or "utf-8", "replace")
    except (urllib.error.URLError, TimeoutError, OSError, ValueError):
        return ""
    parser = Text()
    parser.out = []
    parser.feed(html)
    return "\n".join(parser.out)


def test_key(service, key):
    """Tries a key; returns what to show ("använder <modell>") or raises ServiceError."""
    if service["id"] == SEARCH["id"]:
        web_search("GOBLINCAKES Linux", key)
        return "kan söka på nätet"
    if service["id"] == CLOUDFLARE["id"]:
        cloudflare_account(key, refresh=True)
        return "kan skapa bilder"
    model = pick_model(service, key, refresh=True)
    if service.get("no_model_list"):
        chat(service, key, model, [{"role": "user", "content": "Svara bara: ok"}])
    return f"använder {model}"


def pick_model(provider, key, refresh=False):
    """The service's best free chat model, from its own model list (cached for a day)."""
    return pick_models(provider, key, refresh)[0]


def pick_models(provider, key, refresh=False):
    """The service's best free chat models, best first (the next is tried when one is overloaded)."""
    cache = {}
    if MODELS_CACHE.exists():
        try:
            cache = json.loads(MODELS_CACHE.read_text())
        except ValueError:
            cache = {}
    entry = cache.get(provider["id"])
    if provider.get("no_model_list"):
        return provider["models"]
    if entry and entry.get("models") and not refresh and time.time() - entry["time"] < 86400:
        return entry["models"]

    data = request(provider, key, "/models", timeout=30).get("data", [])
    ids = [m["id"].removeprefix("models/") for m in data if "id" in m]
    models = []
    if provider.get("models"):
        models = [m for m in provider["models"] if m in ids] or provider["models"][:1]
    elif provider["id"] == "openrouter":
        free = [m for m in data
                if str(m.get("pricing", {}).get("prompt")) in ("0", "0.0")
                and str(m.get("pricing", {}).get("completion")) in ("0", "0.0")
                and "text" in str(m.get("architecture", {}).get("output_modalities", ["text"]))]
        free.sort(key=lambda m: m.get("context_length") or 0, reverse=True)
        models = [m["id"] for m in free]
    else:
        for pattern in provider["prefer"]:
            models += [i for i in sorted(ids, reverse=True) if re.search(pattern, i) and i not in models]
        models = models[:5] or ids[:1]
        for pattern in provider.get("fallback", []):
            lite = [i for i in sorted(ids, reverse=True) if re.search(pattern, i)]
            if lite:
                models.append(lite[0])
                break
    if not models:
        raise ServiceError("hittade ingen modell att använda")
    cache[provider["id"]] = {"model": models[0], "models": models, "time": time.time()}
    CACHE.mkdir(parents=True, exist_ok=True)
    MODELS_CACHE.write_text(json.dumps(cache))
    return models


EXHAUSTED = set()  # services out of free questions: not asked again while the program runs
BUSY = {}  # model -> when it was overloaded: tried last for 10 minutes
ROTATE_ERRORS = r"överbelastad|fel 404|nås inte|slut på gratisfrågor"  # worth trying the next model


SEARCH_PROMPT = """

Sökning på nätet: du kan söka när frågan gäller något som kan ha ändrats efter det du lärt dig
(nyheter, nya versioner, patchar, priser, öppettider, resultat, väder) eller när du är osäker på ett faktum.
Svara då med BARA ett kodblock märkt ```sök med en kort sökfråga (gärna på engelska om ämnet är internationellt), t.ex.
```sök
World of Warcraft latest patch notes
```
Du får sedan sökresultaten och svarar användaren utifrån dem. Sök inte för sådant du redan vet säkert
(allmän kunskap, recept, texter, Linux-kommandon). Högst {limit} sökningar per fråga."""

SEARCH_LIMIT = 3


# ── Tools the AI asks for with a code block (search, WoW errors, Warcraft Logs) ───────────
WOW_ERRORS_PROMPT = """

WoW-fel: frågar användaren om fel i WoW eller ett tillägg (BugSack, Lua-fel, "ett tillägg strular"),
svara med BARA ett kodblock märkt ```wowfel – tomt, eller med ett tilläggs namn att leta efter.
Du får då felen som BugSack har sparat. Förklara vilket tillägg som orsakar felet (titta i stacken –
Blizzard_-filer är sällan boven) och vad användaren kan göra: uppdatera tillägget (WowUp), stänga av det,
eller rapportera felet till den som gjort tillägget. Föreslå aldrig att ändra WoW:s egna filer."""

WCL_PROMPT = """

Warcraft Logs: frågar användaren om en pull, wipe, kill eller raidkväll ("varför wipade vi?",
"vem dog först?", "hur gick Kith'ix?"), svara med BARA ett kodblock märkt ```warcraftlogs med vad
som söks: `senaste`, en boss (`Kith'ix`), `Kith'ix pull 3`, eller en länk till rapporten.
Vill användaren ha alla bossar i en rapport/kväll, skriv `alla` (+ länken om du har den) – då får du
varje boss på en gång (killen, annars sista pullen). En ny länk = hämta igen, använd aldrig gammal data.
Du får då pullens data: dödsfall, skadan raiden tog, cooldowns med tider (raid, lust, på andra, egna),
interrupts, dispels och alla spelare med DPS/HPS.

Frågar användaren om en viss förmåga, mekanik eller fiende ("vilka körde cooldowns på Venomous Heart?",
"vem fick Stone Venom?", "vem gjorde skada på hjärtat?"), skriv `<boss> förmåga: <namn>`, t.ex.
`Ula'tek förmåga: Venomous Heart` (+ länken om du har den). Då får du varje gång den kom: vem som
fick den, skadan av den, skadan på fienden, vem som dog och alla cooldowns runt den – även
skade-cooldowns. Står namnet fel får du förslag – be då igen med rätt namn. Behöver du både alla
bossar och en förmåga: be om dem efter varandra, ett block i taget.

Regler för svaret (viktigt):
- Använd bara det som står i datan. Hitta aldrig på mekaniker, förmågor, faser eller orsaker som
  inte står där – skriv hellre "det syns inte i datan".
- Saknas något du behöver, hämta det med ett nytt block i stället för att gissa eller ge upp.
- Räkna inte fram egna procent eller betyg; ta siffrorna som de står.
- Namnge rätt spelare: den som står i datan, med samma stavning.
- Analysera: i vilken ordning och av vad folk dog (de första dödsfallen avgör oftast), skada från
  förmågor som går att undvika, om cooldowns kom i tid, och jämför med de andra pullsen.
Var konkret och vänlig – häng inte ut någon. Användarens karaktär står i datan."""

SYSTEM_ERRORS_PROMPT = """

Systemfel: frågar användaren om fel, krascher eller något som strular i datorn ("Steam kraschar",
"programmet startar inte", "något är fel efter uppdateringen", "kolla om allt är ok"), svara med BARA
ett kodblock märkt ```systemfel – tomt för en översikt, eller med ett programs namn för detaljer
(alla krascher med tider, början av stacken, journalens rader om det). Du får då vad datorn själv har
loggat: krascher, journalens fel, misslyckade tjänster, GOBLINCAKES-versionen och vad som ändrats nyligen.

Så här hittar och lagar du felet:
- Använd bara datan. Står det "känt:" vid ett program är det vad programmet ÄR – beskriv det med de orden,
  aldrig på annat sätt, och säg rakt ut när något är ofarligt (många krascher och journalrader är det).
  Ett ofarligt program är ingen orsak till något annat. Koppla inte ihop program som datan inte kopplar ihop.
  Gissa aldrig vad ett okänt program är; be om detaljer eller fråga.
- Börja svaret med det som faktiskt är fel (eller att inget allvarligt syns), sedan det som är ofarligt.
- Leta orsaken i tid: vad uppdaterades eller ändrades strax före den första kraschen? Samma fel med olika
  Proton-versioner pekar bort från Proton.
- Behöver du veta mer: be om ett nytt ```systemfel med programmets namn, föreslå ett ofarligt
  läskommando (```bash, t.ex. journalctl, systemctl status, ls, cat) eller fråga användaren vad som hände
  (vad syntes, när, går det att göra om?). Du ser inget själv utöver det du får.
- Lösning: ett steg i taget, det säkraste först, som ```bash-kort med en mening om vad det gör. Hellre
  goblin-kommandon, GOBLINCAKES inställningar, flatpak, systemctl --user eller rpm-ostree än att ändra
  filer i /etc. Aldrig ta bort användarens filer eller spelens filer. Kräver det sudo, säg varför.
- Ska användaren göra något (starta om Steam, starta spelet, starta om datorn), säg det och vänta på svar.
- Kolla efteråt med ```systemfel igen innan du säger att det är löst."""

TOOL_LIMIT = 4  # tool uses per question


def wow_tools():
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import wowtools  # noqa: PLC0415
    return wowtools


def sport_tools():
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import sporttools  # noqa: PLC0415
    return sporttools


SPORT_PROMPT = """

Sport: frågar användaren om ett lags ställning, tabell, senaste eller nästa match (NHL, NBA, NFL, MLB, WNBA,
MLS och de stora fotbollsligorna inklusive Allsvenskan), svara med BARA ett kodblock märkt ```sport med lagets
namn, t.ex.
```sport
Anaheim Ducks
```
Du får då exakta siffror från ESPN – använd dem i stället för att söka eller gissa, och räkna inte om placeringen."""


def cs2_tools():
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import cs2tools  # noqa: PLC0415
    return cs2tools


CS2_PROMPT = """

Counter-Strike 2: frågar användaren om sina CS2-matcher, sin statistik, sitt snitt eller vad hen ska träna på,
svara med BARA ett kodblock märkt ```cs2 med `senaste` (eller antal matcher för snittet, t.ex. `senaste 20`,
eller en karta, t.ex. `Mirage`), t.ex.
```cs2
senaste 10
```
Du får då användarens egna siffror ur GoblinRecorders lästa demos: senaste matchen, snittet, match för match
och ungefärliga riktvärden. Coacha utifrån dem:
- Börja kort med hur senaste matchen gick jämfört med snittet (siffrorna som de står).
- Välj 2–3 saker att arbeta på – de som ligger längst från riktvärdena eller blivit sämre – och säg varför med siffran.
- Ge för varje en konkret övning (t.ex. Aim Botz/deathmatch för träff och huvudskott, prefire-kartor och att
  hålla siktet i huvudhöjd vid hörn för sikte, utility-lineups för granater, spela med lagkamrat för trades).
- Nämn också något som går bra. Hitta inte på siffror som inte står i datan; TTD och sikte är ungefärliga."""


def sys_tools():
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import systools  # noqa: PLC0415
    return systools


def tools_for(keys, project, messages):
    """The tools the AI may ask for now: {block word: (name, prompt, run(query) -> (text, sources))}."""
    tools = {}
    key = keys.get(SEARCH["env"])
    if key and not (project and project.get("search") is False) and not has_images(messages):
        def search(query):
            results = web_search(query, key)
            found = "\n\n".join(f"[{i}] {r['title']} – {r['url']}\n{r['content']}" for i, r in enumerate(results, 1))
            return found or "Inga träffar.", results
        tools["sök"] = ("Söker på nätet", SEARCH_PROMPT.format(limit=SEARCH_LIMIT), search)
    tools["sport"] = ("Hämtar lagets ställning", SPORT_PROMPT, lambda q: (sport_tools().sport_info(q), []))
    tools["systemfel"] = ("Läser datorns fel", SYSTEM_ERRORS_PROMPT, lambda q: (sys_tools().system_errors(q), []))
    try:  # GoblinRecorder records CS2 → your numbers from its read demos
        cs2_on = bool(json.loads((CONFIG / "recorder.json").read_text()).get("cs2"))
    except (OSError, ValueError):
        cs2_on = False
    if cs2_on:
        tools["cs2"] = ("Läser dina CS2-siffror", CS2_PROMPT, lambda q: (cs2_tools().cs2_stats(q), []))
    if list(Path.home().glob("Games/WoW/*/AddOns")):
        tools["wowfel"] = ("Läser WoW-felen", WOW_ERRORS_PROMPT, lambda q: (wow_tools().wow_errors(q), []))
    wcl = CONFIG / "wcl.json"
    try:
        configured = bool(json.loads(wcl.read_text()).get("clientId"))
    except (OSError, ValueError):
        configured = False
    if configured:
        asked = next((m["content"] for m in reversed(messages) if m["role"] == "user"), "")
        every = isinstance(asked, str) and re.search(r"\b(?:alla|varje|samtliga)\b.{0,25}\bboss", asked, re.I)

        def wcl(q):  # the user asked for every boss but the AI forgot to say so → all of them anyway
            forced = every and not re.search(r"\bpull\s*\d|förmåga|formaga|ability|mekanik", q, re.I)
            return wow_tools().wcl_pull(("alla " if forced else "") + q), []
        tools["warcraftlogs"] = ("Hämtar pullen från Warcraft Logs", WCL_PROMPT, wcl)
    return tools


TOOL_WORDS = {"sök": "sök", "sok": "sök", "search": "sök", "wowfel": "wowfel", "wow-fel": "wowfel",
              "bugsack": "wowfel", "warcraftlogs": "warcraftlogs", "wcl": "warcraftlogs",
              "sport": "sport", "lag": "sport",
              "cs2": "cs2", "counterstrike": "cs2", "cs": "cs2",
              "systemfel": "systemfel", "system-fel": "systemfel", "systemlogg": "systemfel"}


def tool_request(text, tools):
    """(tool, query) when the answer asks for a tool, else None."""
    for m in re.finditer(r"```([\w-]+)[ \t]*\n?(.*?)```", text, re.S):
        tool = TOOL_WORDS.get(m.group(1).lower())
        if tool in tools:
            return tool, " ".join(m.group(2).split())
    return None


def ask(messages, keys, status=None, notice=None, project=None, choice=""):
    """Asks the services; the AI may use tools in between (web search with a Tavily key, the errors
    BugSack saved, a pull from Warcraft Logs) – it answers with the tool's code block, gets the result
    and answers again (at most TOOL_LIMIT times).

    choice: a model picked by the user ("<service id>:<model>", see model_choices) – "" = automatic.
    Returns (answer, "service · model"); web sources are listed at the end of the answer.
    """
    activity("ask", "tänker")
    LAST.tools = []
    messages = with_lessons(messages, project)
    try:
        if read_links(messages, keys, status):
            # The pages are there: one plain answer – no searching on top, no long thinking (a button
            # with links took 3–4 minutes)
            QUICK.on = True
            answer, service = ask_once(messages, keys, status, notice, project, choice)
        else:
            answer, service = _ask(messages, keys, status, notice, project, choice)
    finally:
        QUICK.on = False
        activity_done()
    question = next((m["content"] for m in reversed(messages) if m["role"] == "user"), "")
    return no_unasked_report(answer, question), service


PICTURE_WORDS = re.compile(r"bild|png|jpe?g|infografik|mallen|picture|image", re.I)


def no_unasked_report(answer, question):
    """A ```rapport block (= a PNG) only when the user asked for a picture – small models made one for every
    summary; otherwise the block's Markdown is shown as plain text (the user is asked: bild eller PDF?)."""
    if not isinstance(question, str) or PICTURE_WORDS.search(question):
        return answer
    return re.sub(r"```(?:rapport|report|infografik|sammanst[aä]llning)[^\n]*\n(.*?)(?:\n```|\Z)",
                  lambda m: m.group(1).strip(), answer, flags=re.S | re.I)


# Small local models often guess instead of asking for a search (14 Oct, the plan; built 21 Oct): with
# these words in the question – or the "Sök på nätet" button – the search is done first, by Goblin AI
FRESH_WORDS = re.compile(
    r"\b(?:senaste|senast|nyaste|nyheter|nyhet|nyhetern\w*|patch\w*|hotfix\w*|idag|i dag|igår|i går|ikväll|i kväll|"
    r"just nu|aktuell\w*|pris(?:et|er|erna)?|kostar|väder|vädret|resultat(?:et|en)?|släpp\w*|release\w*|"
    r"latest|news|today|tonight|current|price|weather)\b", re.I)


def fresh_question(question):
    """The question is about something that may have changed: the words above, or this or last year."""
    if not isinstance(question, str):
        return False
    text = question[:600]  # the typed question, not an attached file below it
    year = date.today().year
    return bool(FRESH_WORDS.search(text) or re.search(rf"\b(?:{year - 1}|{year}|{year + 1})\b", text))


LAST = threading.local()  # .tools: [(tool, query)] the last ask() used in this thread (the ♥ remembers them)


def last_tools():
    return list(getattr(LAST, "tools", []))


def _ask(messages, keys, status=None, notice=None, project=None, choice=""):
    messages = [dict(m) for m in messages]
    asked = next((m for m in reversed(messages) if m["role"] == "user"), {})
    forced = asked.pop("search", False)  # the "Sök på nätet" button
    if asked.pop("rewrite", False):  # a quick button under an answer: only the text again – no tools
        return ask_once(messages, keys, status, notice, project, choice)
    tools = tools_for(keys, project, messages)
    LAST.tools = []
    if forced and "sök" not in tools and notice:
        notice("Sökningen gick inte: " + ("ingen Tavily-nyckel (AI-tjänster → Tavily)" if not keys.get(SEARCH["env"])
                                          else "inte här (projektet söker inte, eller en bild är med)"))
    if not tools:
        return ask_once(messages, keys, status, notice, project, choice)
    if messages and messages[0]["role"] == "system":
        messages[0]["content"] += "".join(t[1] for t in tools.values())
    sources, used, searched = [], 0, False
    question = next((m["content"] for m in reversed(messages) if m["role"] == "user"), "")[:2000]
    if "sök" in tools and (forced or fresh_question(asked.get("content"))):
        # Goblin AI searches first, with the question itself (Tavily takes plain questions)
        query = " ".join(str(asked.get("content", "")).split())[:300]
        activity("ask", "söker på nätet")
        if status:
            status("Söker på nätet…")
        try:
            text, found = tools["sök"][2](query)
            sources.extend(found)
            searched, used = True, 1
            LAST.tools.append(("sök", query))
            messages.append({"role": "user", "content":
                             f"[Goblin AI sökte på nätet åt dig innan du svarar – det här skrev eller klistrade användaren "
                             f"inte in]\n\n{text}\n\n[Slut på sökresultaten]\n\nAnvändarens fråga var: \"{question}\"\n"
                             "Svara på den utifrån resultaten (sök igen med ett ```sök-block om de inte räcker). "
                             "Sökresultaten kan vara fel eller gamla – säg till om det verkar så."})
        except Exception as e:  # noqa: BLE001 – the search failed: an ordinary answer instead
            if notice:
                notice(f"Söker på nätet gick inte: {e}")
    while True:
        answer, service = ask_once(messages, keys, status, notice, project, choice)
        request_ = tool_request(answer, tools)
        if not request_:
            break
        tool, query = request_
        messages.append({"role": "assistant", "content": answer})
        if used >= TOOL_LIMIT:
            messages.append({"role": "user", "content": "Inga fler sökningar eller hämtningar – svara nu med det du har."})
            continue
        used += 1
        LAST.tools.append((tool, query))
        name, _, run = tools[tool]
        activity("ask", name[0].lower() + name[1:])
        if status:
            status(f"{name}{': ' + query if query else ''}…")
        try:
            text, found = run(query)
        except Exception as e:  # noqa: BLE001 – ServiceError, wowtools.ToolError, the network
            if notice:
                notice(f"{name} gick inte: {e}")
            messages.append({"role": "user", "content": f"Det gick inte ({e}). Svara utan det, och säg varför."})
            continue
        searched = searched or tool == "sök"
        for r in found:
            if r["url"] not in (s["url"] for s in sources):
                sources.append(r)
        messages.append({"role": "user", "content":
                         f"[Svar från verktyget {tool} som du själv bad om – det här skrev eller klistrade "
                         f"användaren inte in]\n\n{text}\n\n[Slut på verktygets svar]\n\n"
                         f"Användarens fråga var: \"{question}\"\n"
                         "Svara nu på den frågan utifrån det här (eller be om mer med ett nytt block)."})
    if sources:
        answer = answer.rstrip() + "\n\n**Källor:** " + " · ".join(
            f"[{s['title'][:60].replace('[', '(').replace(']', ')')}]({s['url']})" for s in sources[:5])
    if searched:
        service += " · sökte på nätet"
    elif used:
        service += " · hämtade data"
    return answer, service


def ask_once(messages, keys, status=None, notice=None, project=None, choice=""):
    """Asks the services in order; returns (answer, "service · model").

    status(text): "asking X…"; notice(text): a service failed and the next is tried.
    choice: the user's own model – only that one is asked (no other service behind the user's back).
    """
    chosen = chosen_provider(choice)
    if chosen and not chosen[0].get("local") and (project or {}).get("order") == "local-only":
        # A private project: nothing may leave the computer, whatever is picked by the send button
        if notice:
            notice("Projektet får bara använda lokal AI – den valda modellen används inte här")
        chosen = None
    fallback = None
    if chosen:
        try:
            return ask_chosen(*chosen, messages, keys, status)
        except ServiceError as e:
            # The picked model is overloaded (or out of free questions, or doesn't answer – 20 Oct, the
            # user's wish): its service's other models, then the other services, the local AI last.
            # Pictures still go nowhere else.
            provider, model = chosen
            if provider.get("local") or has_images(messages) or not re.search(ROTATE_ERRORS, str(e)):
                raise
            BUSY[model] = time.time()
            if notice:
                notice(f"{provider['name']} · {MODEL_NAMES.get(model, model)} svarar inte – provar nästa")
            # A service that doesn't answer at all: its other models are on the same servers – skip them
            fallback = ([] if "nås inte" in str(e) else [provider]) + [
                p for p in PROVIDERS if p is not provider and keys.get(p["env"])]
            if LOCAL in providers_in_order(keys, (project or {}).get("order")):  # not with "Bara molnet"
                fallback.append(LOCAL)
    if has_images(messages):
        # Automatic never sends a picture of the screen (or a photo) to the cloud: only the local AI
        if not local_settings()["installed"]:
            raise ServiceError("Bilder skickas bara till lokal AI när Automatiskt är valt, och den är inte installerad "
                               "(AI-tjänster → Lokal AI). Vill du skicka bilden till en tjänst i molnet: välj en modell vid Skicka.")
        try:
            models = local_models(messages, project)
        except ServiceError as e:
            raise ServiceError(f"Lokal AI: {e}.\nBilder skickas bara till lokal AI när Automatiskt är valt – "
                               "vill du skicka bilden till molnet: välj en modell vid Skicka.") from None
        return ask_chosen(LOCAL, models[0], messages, keys, status)
    errors = []
    for provider in fallback or providers_in_order(keys, (project or {}).get("order")):
        key = keys.get(provider["env"]) if provider["env"] else ""
        if (not key and not provider.get("local")) or provider["id"] in EXHAUSTED:
            continue
        try:
            reply = None
            for attempt in range(2):
                models = local_models(messages, project) if provider.get("local") else pick_models(provider, key, refresh=attempt > 0)
                models = sorted(models, key=lambda m: time.time() - BUSY.get(m, 0) < 600)
                if fallback and provider is chosen[0]:
                    models = [m for m in models if m != chosen[1]] or models  # the picked one was just asked
                activity("ask", "tänker · " + ("din dator" if provider.get("local") else provider["name"]), provider.get("local"))
                if status:
                    status(f"Frågar {provider['name']}…")
                try:
                    for i, model in enumerate(models):
                        try:
                            reply = chat(provider, key, model, messages)
                            break
                        except ServiceError as e:
                                # Overloaded, or listed but closed to new users: the next model
                            # (Gemini's free questions are counted per model: 429 = the next model too)
                            if re.search(ROTATE_ERRORS, str(e)) and "nås inte" not in str(e) and i + 1 < len(models):
                                BUSY[model] = time.time()
                                if status:
                                    status(f"{model} svarar inte – provar {models[i + 1]}…")
                                continue
                            raise
                    break
                except ServiceError as e:
                    # A model that disappeared: pick again once
                    if attempt == 0 and re.search(r"fel 40[04]", str(e)):
                        continue
                    raise
            text = reply
            if not text.strip():
                raise ServiceError("tomt svar")
            return text, f"{provider['name']} · {model}"
        except (ServiceError, KeyError, IndexError) as e:
            errors.append(f"{provider['name']}: {e}")
            if not provider.get("local") and re.search(r"slut på (gratisfrågor|krediter)|fel nyckel", str(e)):
                EXHAUSTED.add(provider["id"])
            if notice:
                notice(f"{provider['name']}: {e} – provar nästa")
    if not errors:
        if project and project.get("order") == "local-only":
            raise ServiceError("Projektet får bara använda lokal AI, men den är inte installerad (AI-tjänster → Lokal AI).")
        raise ServiceError("Ingen AI-tjänst är inställd.")
    raise ServiceError("Ingen AI-tjänst svarade.\n" + "\n".join(errors))


# The model picked in the window (or goblin ai --model), like switching model in Claude Code: kept until changed
MODEL_FILE = CONFIG / "ai-model"


def chosen_model():
    try:
        return MODEL_FILE.read_text().strip()
    except OSError:
        return ""


def set_chosen_model(choice):
    CONFIG.mkdir(parents=True, exist_ok=True)
    if choice:
        MODEL_FILE.write_text(choice + "\n")
    else:
        MODEL_FILE.unlink(missing_ok=True)


def chosen_provider(choice):
    """(provider, model) for "<service id>:<model>" (the model may itself have a colon: gemma4:e4b)."""
    pid, _, model = (choice or "").partition(":")
    if not model:
        return None
    if pid == LOCAL["id"]:
        return LOCAL, model
    p = next((p for p in PROVIDERS if p["id"] == pid), None)
    return (p, model) if p else None


def local_ids():
    """The models Ollama has (no start: [] when it isn't running or a game pauses it)."""
    if LOCAL_PAUSED.exists():
        return []
    try:
        with urllib.request.urlopen("http://127.0.0.1:11434/v1/models", timeout=3) as r:
            return [m["id"] for m in json.loads(r.read()).get("data", [])]
    except (urllib.error.URLError, OSError, ValueError):
        return []


def local_sizes():
    """{model: "12B"} from Ollama's own list (the number of parameters – bigger = smarter, slower)."""
    try:
        with urllib.request.urlopen("http://127.0.0.1:11434/api/tags", timeout=3) as r:
            return {m["name"]: (m.get("details") or {}).get("parameter_size", "").replace(".0B", "B")
                    for m in json.loads(r.read()).get("models", [])}
    except (urllib.error.URLError, OSError, ValueError, KeyError):
        return {}


def model_choices(keys):
    """What the window lists: [{"id", "name", "group", "note", "tag"}], automatic first.
    tag = which one is best in its group (BÄST, BÄST TILL KOD …, SNABBAST) – the cloud lists are
    best first already (pick_models), the local ones are the models chosen per role in Lokal AI.
    The cloud lists come from the services' own model lists (cached for a day, see pick_models)."""
    items = [{"id": "", "name": "Automatiskt", "group": "", "tag": "",
              "note": "Goblin AI väljer – ordningen i AI-tjänster, nästa tjänst om en inte svarar"}]
    local = local_settings()
    if local["installed"]:
        ids = local_ids()
        if not ids and not LOCAL_PAUSED.exists() and start_local():
            ids = local_ids()
        sizes = local_sizes()
        roles = {m: r for r, m in local["roles"].items() if m}
        tags = {"vardag": "BÄST TILL VARDAG", "kod": "BÄST TILL KOD", "bild": "SER BILDER"}
        for m in ids:
            size = sizes.get(m) or sizes.get(f"{m}:latest") or ""
            note = (f"{size} · " if size else "") + "på din dator · gratis"
            items.append({"id": f"{LOCAL['id']}:{m}", "name": m, "group": "Lokal AI", "note": note,
                          "tag": tags.get(roles.get(m), "")})
        if LOCAL_PAUSED.exists():
            items.append({"id": "", "name": "", "group": "Lokal AI", "tag": "", "note": "Avstängd medan ett spel kör"})
    for p in PROVIDERS:
        key = keys.get(p["env"])
        if not key:
            continue
        try:
            models = pick_models(p, key)
        except ServiceError:
            models = p.get("models") or []
        if p["id"] == "openrouter":
            models = models[:8]
        for i, m in enumerate(models):
            info = MODEL_INFO.get(m)
            if info:
                tag, note = info
            else:
                fast = re.search(r"(^|[-_.:/])(lite|mini|nano|fast|small)([-_.:]|$)", m)
                tag = "BÄST" if i == 0 else "SNABBAST" if fast else ""
                note = "" if i == 0 else "snabbare, enklare svar" if fast else "äldre – reserv"
            note = ("betald" if p.get("paid") else "gratis") + (f" · {note}" if note else "")
            items.append({"id": f"{p['id']}:{m}", "name": MODEL_NAMES.get(m, m), "group": p["name"],
                          "note": note, "tag": tag})
    return items


MODEL_NAMES = {"claude-opus-5-5": "Claude Opus 5.5", "claude-sonnet-5-5": "Claude Sonnet 5.5",
               "claude-haiku-5-5": "Claude Haiku 5.5"}
# Models whose strengths are known: (tag, note)
MODEL_INFO = {
    "claude-opus-5-5": ("BÄST", "smartast, för svåra saker och kod – dyrast"),
    "claude-sonnet-5-5": ("", "nästan lika bra, billigare och snabbare"),
    "claude-haiku-5-5": ("SNABBAST", "billigast, för enkla frågor"),
    "sonar-pro": ("BÄST", "söker grundligare"),
    "sonar": ("SNABBAST", "billigare"),
}


def ask_chosen(provider, model, messages, keys, status=None):
    """One question to the model the user picked; a failure is an error (no other service is asked)."""
    name = f"{provider['name']} · {MODEL_NAMES.get(model, model)}"
    key = "" if provider.get("local") else keys.get(provider["env"])
    if not provider.get("local") and not key:
        raise ServiceError(f"{provider['name']} har ingen nyckel längre – välj en annan modell vid Skicka.")
    if provider.get("local"):
        if LOCAL_PAUSED.exists():
            raise ServiceError("Lokal AI är avstängd medan ett spel kör – välj Automatiskt eller en modell i molnet.")
        if not local_ids() and not start_local():
            raise ServiceError("Lokal AI (Ollama) startar inte.")
    if has_images(messages) and not (local_sees(model) if provider.get("local") else provider["id"] in VISION_CLOUD):
        raise ServiceError(f"{name} kan inte se bilder – välj Automatiskt (din lokala bildmodell) "
                           "eller en modell som kan, vid Skicka.")
    activity("ask", "tänker · " + ("din dator" if provider.get("local") else provider["name"]), provider.get("local"))
    if status:
        status(f"Frågar {name}…")
    try:
        text = chat(provider, key, model, messages)
    except ServiceError as e:
        raise ServiceError(f"{name}: {e}\nVälj Automatiskt eller en annan modell vid Skicka.") from None
    if not text.strip():
        raise ServiceError(f"{name} gav ett tomt svar.")
    return text, f"{provider['name']} · {model}"


# ── Pictures in questions (16 Oct): screenshots and pictures the user attaches ───────────
# A user message may carry "images": [paths] (JPEG/PNG kept in Goblin AI's data folder). Only the
# latest one among the last few questions is sent as a picture – older ones become a short note,
# so a chat with many screenshots doesn't send them all again with every question.
IMAGE_EXTS = (".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp")
IMAGES_RECENT = 3  # user messages back where a picture is still sent
VISION_CLOUD = {"anthropic", "openai", "gemini", "xai"}  # services whose models see pictures

SHOT_PROMPT = """

Skärmbilder och bilder: användaren kan bifoga bilder, och du kan se dem. Vill användaren att du ska
titta på skärmen (t.ex. "titta på min skärm", "vad står det här", "varför ser det ut så här"), svara med
BARA ett tomt kodblock märkt ```skärmbild (skriv raden `båda` i blocket om båda skärmarna behövs).
Användaren får då frågan om skärmbilden får tas, och du får bilden efteråt. Be bara om en skärmbild när
användaren vill att du ska se skärmen – aldrig annars."""


def is_image(path):
    return str(path).lower().endswith(IMAGE_EXTS)


def active_images(messages):
    """The index of the message whose pictures are sent (the latest with pictures among the last
    IMAGES_RECENT user messages), or None."""
    users = [i for i, m in enumerate(messages) if m.get("role") == "user"][-IMAGES_RECENT:]
    for i in reversed(users):
        if messages[i].get("images"):
            return i
    return None


def has_images(messages):
    return active_images(messages) is not None


def image_data(path):
    data = base64.b64encode(Path(path).read_bytes()).decode()
    ext = Path(path).suffix.lower().lstrip(".")
    return {"jpg": "image/jpeg", "jpeg": "image/jpeg"}.get(ext, f"image/{ext}"), data


def wire_messages(messages, anthropic=False):
    """The messages as the services want them: pictures as content parts (OpenAI style, or Claude's)."""
    active = active_images(messages)
    out = []
    for i, m in enumerate(messages):
        images = m.get("images") or []
        msg = {"role": m["role"], "content": m["content"]}
        if images and i == active:
            parts = []
            for path in images:
                try:
                    mime, data = image_data(path)
                except OSError:
                    continue
                parts.append({"type": "image", "source": {"type": "base64", "media_type": mime, "data": data}}
                             if anthropic else
                             {"type": "image_url", "image_url": {"url": f"data:{mime};base64,{data}"}})
            msg["content"] = parts + [{"type": "text", "text": m["content"]}]
        elif images:
            msg["content"] = m["content"] + f"\n\n({len(images)} bild(er) visades tidigare i samtalet)"
        out.append(msg)
    return out


LOCAL_VISION = {}  # model -> sees pictures (Ollama's "capabilities")


def local_sees(model):
    if model not in LOCAL_VISION:
        try:
            req = urllib.request.Request("http://127.0.0.1:11434/api/show", data=json.dumps({"model": model}).encode(),
                                         headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=10) as r:
                LOCAL_VISION[model] = "vision" in (json.loads(r.read()).get("capabilities") or [])
        except (urllib.error.URLError, OSError, ValueError):
            return False
    return LOCAL_VISION[model]


def sees_images(choice=""):
    """Whether a picture can be looked at now: the chosen model, or (automatic) the local AI."""
    chosen = chosen_provider(choice)
    if chosen:
        p, model = chosen
        return local_sees(model) if p.get("local") else p["id"] in VISION_CLOUD
    return local_settings()["installed"]


LOCAL_BUDGET = 80_000  # characters (≈ 24 000 tokens) of a chat sent to the local AI (32 768 tokens, see goblincakes-ollama; 18 Oct: 16 384 was too little for a whole raid night + one ability)
PICTURE_CHARS = 5_000  # what a picture counts as


def fit_local(messages):
    """A long chat for the local AI: the system prompt and the latest messages that fit – the oldest
    are left out (the window keeps them), instead of Ollama refusing the question."""
    system = [m for m in messages if m["role"] == "system"]
    rest = [m for m in messages if m["role"] != "system"]
    used = sum(len(m["content"]) for m in system)
    active = active_images(messages)
    kept = []
    for m in reversed(rest):
        size = len(m["content"]) + (PICTURE_CHARS * len(m.get("images") or []) if messages.index(m) == active else 0)
        if kept and used + size > LOCAL_BUDGET:
            break
        kept.insert(0, m)
        used += size
    if len(kept) < len(rest):
        kept.insert(0, {"role": "user", "content": "(Äldre delar av samtalet är utelämnade för att få plats.)"})
        if kept[1]["role"] == "user":  # keep user/assistant turns alternating
            kept.insert(1, {"role": "assistant", "content": "Okej."})
    return system + kept


def chat(provider, key, model, messages):
    """One question to one model; returns the answer's text."""
    if provider.get("local"):
        messages = fit_local(messages)
    if provider["id"] != "anthropic":
        body = {"model": model, "messages": wire_messages(messages)}
        temperature = provider.get("temperature", 0.4)
        if temperature is not None:
            body["temperature"] = temperature
        if provider.get("local") and getattr(QUICK, "on", False):
            body["reasoning_effort"] = "none"
        if provider.get("local"):
            # Thinking models (gemma4) sometimes think in circles until the whole context is full and
            # give no answer (18 Oct: 12 000 tokens, 3 min) – a ceiling, then once more without thinking
            used = sum(len(m["content"]) if isinstance(m["content"], str) else 2000 for m in messages) // 3
            body["max_tokens"] = max(LOCAL_MIN_TOKENS, min(LOCAL_MAX_TOKENS, LOCAL_CONTEXT - used - 500))
        # The facts are already fetched (a button): a short job – an overloaded server that keeps the
        # question for 50–90 s before saying so is left after 30 (20 Oct, Gemini)
        quick = getattr(QUICK, "on", False) and not provider.get("local")
        reply = request(provider, key, "/chat/completions", body, **({"timeout": 30} if quick else {}))
        text = reply["choices"][0]["message"].get("content") or ""
        if provider.get("local") and reply["choices"][0].get("finish_reason") == "length":  # empty or cut off
            reply = request(provider, key, "/chat/completions", {**body, "reasoning_effort": "none"})
            text = reply["choices"][0]["message"].get("content") or ""
        # Perplexity searches by itself: its sources go under the answer like ours
        links = [r.get("url") for r in reply.get("search_results") or [] if r.get("url")] or reply.get("citations") or []
        if links and text.strip():
            text = text.rstrip() + "\n\n**Källor:** " + " · ".join(
                f"[{i}]({u})" for i, u in enumerate(links[:8], 1))
        return text
    # Claude's Messages API: the system prompt goes beside the messages, not among them
    system = "\n\n".join(m["content"] for m in messages if m["role"] == "system")
    turns = [m for m in wire_messages(messages, anthropic=True) if m["role"] in ("user", "assistant")]
    reply = request(provider, key, "/messages", {
        "model": model, "max_tokens": 16000, "system": system, "messages": turns,
        "fallbacks": "default",
    }, timeout=300)
    if reply.get("stop_reason") == "refusal":
        raise ServiceError("ville inte svara på frågan")
    return "".join(b.get("text", "") for b in reply.get("content", []) if b.get("type") == "text")


def has_keys(keys):
    return bool(providers_in_order(keys))


def system_info():
    info = []
    try:
        osr = dict(line.split("=", 1) for line in Path("/etc/os-release").read_text().splitlines() if "=" in line)
        info.append(f"OS: {osr.get('PRETTY_NAME', '').strip(chr(34))} (bygger på Fedora {osr.get('VERSION_ID', '?').strip(chr(34))})")
    except OSError:
        pass
    info.append(f"Kärna: {os.uname().release}")
    info.append(f"Dagens datum: {date.today().isoformat()}")
    try:
        status = json.loads(subprocess.run(["rpm-ostree", "status", "--json", "--booted"],
                                           capture_output=True, text=True, timeout=10).stdout)
        image = status["deployments"][0].get("container-image-reference", "")
        if image:
            info.append(f"Image: {image}")
    except Exception:
        pass
    info.append(f"Skal: {os.environ.get('SHELL', 'bash')}, användare: {getpass.getuser()}")
    return "\n".join(info)


SYSTEM_PROMPT = """Du är Goblin AI, hjälparen i GOBLINCAKES – en personlig Linux-distribution.
Du hjälper med allt: frågor, texter, översättningar, recept, idéer, spel och datorn.
Svara på samma språk som användaren (oftast svenska), tydligt och vänligt. Användaren är inte expert.
Använd Markdown (rubriker, listor, **fetstil**, tabeller) när det gör svaret lättare att läsa.

Om datorn:
{info}
- GOBLINCAKES är en atomisk, oföränderlig Fedora Kinoite-image (KDE Plasma 6, Wayland; Nvidia-drivrutiner via GOBLINCAKES Config → Grafik)
  byggd med BlueBuild. Systemfilerna i /usr är skrivskyddade; /etc och /var går att ändra.
- Program installeras som Flatpak (Flathub, gärna `flatpak install --user`), som AppImage i ~/AppImages,
  i en Distrobox-container, eller sist i hand som lager med `rpm-ostree install` (kräver omstart).
  Föreslå aldrig `dnf install` direkt på systemet – det fungerar inte här.
- Uppdatera allt: `goblin update`. Systeminfo: `goblin fast`. Installera program och spelinställningar:
  fönstret GOBLINCAKES Config (i AppGrid). Rollback: `rpm-ostree rollback`.
- Spel: Steam finns i imagen (RPM, bibliotek i ~/.local/share/Steam); Lutris, Heroic och Discord är Flatpaks; GE-Proton finns via ProtonUp-Qt; GameMode finns (`gamemoderun %command%`).
  MangoHud (FPS-mätare) slås på i GOBLINCAKES Config → Inställningar, ställs in i GOverlay. NTSYNC är påslaget.
  Battle.net/WoW installeras via GOBLINCAKES Config (Lutris); `goblin wow` länkar alla WoW-versioner: ~/Games/WoW/<Retail|Classic|Classic Era|Anniversary…>/Logs och AddOns, ~/Games/WoW/World of Warcraft (för Raider.IO/Archon), och lägger in dem i WowUp.
  TV-läge (Steam Big Picture i helskärm): `goblin tv` eller TV-läge i AppGrid; tillbaka via Steams strömmeny.
- Terminal: Ghostty (Konsole med samma utseende går att välja i GOBLINCAKES Config → Program). Filhanterare: Dolphin.

När användaren vill få något gjort på datorn:
- Ge de kommandon som behövs i kodblock märkta ```bash – ett kommando eller en kort följd per block.
  Användaren får frågan om varje block innan det körs, och du får se utskriften efteråt.
- Blocken körs efter varandra i samma mapp, som i en terminal: `cd` i ett block gäller även i nästa.
  Sökvägar med mellanslag skrivs inom citattecken: `cd "/run/media/$USER/Min disk/Mapp"`.
- Du kan inte själv se användarens filer eller datorn. Behöver du veta något, be om att få köra ett
  kommando (t.ex. `ls`, `cat fil.py`, `python3 -c "import tkinter"`) – gissa inte. Användaren kan också
  bifoga en fil.
- Ny fil eller nytt skript: skriv HELA filen i ett ```bash-block med `cat > ~/namn.py <<'EOF'` … `EOF`
  (citattecknen runt EOF behövs), så skapas den med ett klick. Kontrollera att alla import finns med.
  I Python förstås inte `~` av open() – använd `Path.home() / "fil"` eller `os.path.expanduser("~/fil")`.
- Varje block körs i en egen bash som avslutas när blocket är klart – då dör allt som startats med bara `&`.
  Program som ska fortsätta köra (servrar, lyssnare, övervakning) startas fristående med logg, och provas
  i SAMMA block som skapar filen. Följ den här mallen (byt namn, port och testdata):
```bash
cat > ~/namn.py <<'EOF'
import os, json
...
EOF
python3 -m py_compile ~/namn.py || exit 1
[ -f ~/namn.pid ] && kill "$(cat ~/namn.pid)" 2>/dev/null; sleep 0.5
setsid python3 -u ~/namn.py > ~/namn.log 2>&1 < /dev/null & echo $! > ~/namn.pid
sleep 1; curl -s -w ' HTTP %{{http_code}}\\n' -X POST -d '{{"test":1}}' http://127.0.0.1:PORT/
kill -0 "$(cat ~/namn.pid)" && echo "Körs." || echo "Har stannat."; cat ~/namn.log
```
  Står det inte HTTP 200, eller syns ett fel (t.ex. NameError = en import saknas) i loggen: rätta och kör om.
  Testraden som skrevs till en datafil tas bort efteråt. Säg hur det stoppas: `kill "$(cat ~/namn.pid)"`.
  Använd aldrig `pkill -f` eller `pgrep -f` med skriptets namn – de träffar även blockets egen bash.
- Ta ett steg i taget när du behöver se resultatet först. Skriv inga ```bash-block när inget ska köras.
- Använd sudo bara när det verkligen behövs och säg varför. Var extra försiktig med kommandon som tar bort saker.
- När uppgiften är klar: säg det kort, utan kodblock.

När användaren har bifogat en fil och vill ha den ändrad (t.ex. rättad, översatt, omskriven):
- Ge HELA den nya versionen i ett kodblock märkt ```fil:FILNAMN (samma filnamn), så kan den sparas med en knapp.
  Kort före blocket: vad du har ändrat."""


GOBLIN_BIN = os.environ.get("GOBLINCAKES_GOBLIN_BIN", "/usr/bin/goblin")


def goblin_commands():
    """GOBLINCAKES' own commands, read from the COMMANDS list in /usr/bin/goblin (the same text as goblin help)."""
    try:
        text = Path(GOBLIN_BIN).read_text()
        block = text[text.index("COMMANDS=(") + 10:]
        block = block[:block.index("\n)")]
    except (OSError, ValueError):
        return ""
    lines = []
    for entry in re.findall(r'^\s*"([^"]+)"', block, re.M):
        name, _, desc = entry.partition("|")
        lines.append(f"- `goblin {name}` – {desc}")
    if not lines:
        return ""
    return ("\n\nGOBLINCAKES egna kommandon (det här är hela listan – hitta inte på andra goblin-kommandon; "
            "`goblin help` visar samma lista):\n" + "\n".join(lines))


NAME_FILE = CONFIG / "ai-name"  # the name the user gave the AI (AI-tjänster → Namn), e.g. Kakan


def ai_name():
    try:
        return NAME_FILE.read_text().strip()
    except OSError:
        return ""


def set_ai_name(name):
    name = " ".join(name.split())[:30]
    CONFIG.mkdir(parents=True, exist_ok=True)
    if name and name.lower() != "goblin ai":
        NAME_FILE.write_text(name + "\n")
    else:
        NAME_FILE.unlink(missing_ok=True)
    return ai_name()


GENDER_FILE = CONFIG / "ai-gender"  # chosen with the name (20 Oct, cosmetic): hon, han, hen or nothing
GENDERS = {"hon": "hon/henne", "han": "han/honom", "hen": "hen/hen"}


def ai_gender():
    try:
        gender = GENDER_FILE.read_text().strip()
    except OSError:
        return ""
    return gender if gender in GENDERS else ""


def set_ai_gender(gender):
    CONFIG.mkdir(parents=True, exist_ok=True)
    if gender in GENDERS:
        GENDER_FILE.write_text(gender + "\n")
    else:
        GENDER_FILE.unlink(missing_ok=True)
    return ai_gender()


# ── The memory (16 Oct): things the AI always knows, in every chat ──────────────────────
MEMORY_FILE = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "goblincakes/ai/minne.json"
MEMORY_MAX = 60       # things
MEMORY_LENGTH = 300   # characters per thing

MEMORY_PROMPT = """

Minne: du har ett minne som följer med i alla chattar. När användaren ber dig komma ihåg något
("kom ihåg att …", "spara att …") – eller berättar något om sig själv som tydligt är bra att veta
framöver – skriv ett kodblock märkt ```minne med en sak per rad, kort och i tredje person
(t.ex. "Spelar WoW som Kaytho på Stormscale (EU)."). Ber användaren dig glömma något, skriv ett
kodblock märkt ```glöm med det som ska bort, en sak per rad. Säg kort i texten vad du sparade eller glömde.
Spara inga lösenord, nycklar eller annat hemligt."""


def load_memory():
    try:
        items = json.loads(MEMORY_FILE.read_text())
        return [i for i in items if isinstance(i, dict) and str(i.get("text", "")).strip()]
    except (OSError, ValueError):
        return []


def save_memory(items):
    MEMORY_FILE.parent.mkdir(parents=True, exist_ok=True)
    MEMORY_FILE.write_text(json.dumps(items[-MEMORY_MAX:], ensure_ascii=False, indent=1))


# ── Own buttons (20 Oct; first a daily update asked when the window opened – too slow, the user's
# wish): a named instruction asked by its own model in a new chat when its button above the input is pressed ──
DAILY_FILE = MEMORY_FILE.parent / "dagligt.json"  # [{"name", "text", "model": choice id or ""}]
DAILY_MAX = 10
DAILY_PROMPT = ("\n\n(Det här är en sparad knapp som användaren tryckt på. Ge det senaste just nu – får du lagens fakta "
                "från ESPN eller sidornas text nedan, utgå från dem (räkna inte om något); sök annars på nätet om du kan. "
                "Kort och överskådligt, med datum.)")


def load_daily():
    try:
        items = json.loads(DAILY_FILE.read_text())
        items = [i for i in items if isinstance(i, dict) and str(i.get("text", "")).strip()]
    except (OSError, ValueError):
        return []
    for i in items:  # from the time of daily updates: no name yet
        i.pop("last", None)
        i["name"] = str(i.get("name") or "").strip() or " ".join(i["text"].split()[:2])[:20]
    return items


def save_daily(items):
    DAILY_FILE.parent.mkdir(parents=True, exist_ok=True)
    DAILY_FILE.write_text(json.dumps(items[:DAILY_MAX], ensure_ascii=False, indent=1))


def remember(texts):
    """Adds things (not twice); returns the ones that were new."""
    items = load_memory()
    known = {i["text"].casefold() for i in items}
    added = []
    for t in texts:
        t = " ".join(t.split())[:MEMORY_LENGTH].lstrip("-•* ").strip()
        if t and t.casefold() not in known:
            items.append({"text": t, "added": date.today().isoformat()})
            known.add(t.casefold())
            added.append(t)
    save_memory(items)
    return added


def forget(texts):
    """Removes the things that best match each line (exact, else containing it, else most shared words);
    returns the removed ones."""
    items = load_memory()
    removed = []
    for t in texts:
        t = " ".join(t.split()).lstrip("-•* ").strip().casefold()
        if not t or not items:
            continue
        words = set(re.findall(r"\w+", t))

        def score(i):
            text = i["text"].casefold()
            if text == t:
                return 1000
            if t in text or text in t:
                return 500
            return len(words & set(re.findall(r"\w+", text)))
        best = max(items, key=score)
        if score(best) >= max(2, len(words) // 2):
            items.remove(best)
            removed.append(best["text"])
    save_memory(items)
    return removed


# ── ♥ on a good answer (18 Oct, the user's idea; step 1 built 21 Oct): what worked is saved as a short
# lesson the AI writes itself, and the 2–3 lessons most like a new question go into its system prompt ──
LESSONS_FILE = MEMORY_FILE.parent / "lardomar.json"  # [{"id", "kind" good|avoid, "question", "lesson", "tools", "service", "project", "added"}]
LESSONS_MAX = 100
LESSONS_PICK = 3
LESSON_LENGTH = 300
STOP_WORDS = set("""och att det som en ett är för på med till av den har inte jag du vi ni de om kan vad hur var när
så men eller från ska vill mig dig min din mitt ditt the and for you are what how this that with från alla något""".split())

LESSON_PROMPT = """Användaren gav ett hjärta (♥) på ditt svar nedan – det var bra. Skriv EN kort lärdom på svenska (högst två meningar, högst 220 tecken) om hur du gick till väga, så att du kan göra likadant nästa gång en liknande fråga kommer: vilket verktyg du använde och med vad, vad du tog med, hur du lade upp svaret. Skriv inte själva svaret och inga siffror ur det. Svara med BARA lärdomen.

Frågan: {question}
Verktyg du använde: {tools}
Ditt svar (början):
{answer}"""

AVOID_PROMPT = """Användaren gav tumme ner (👎) på ditt svar nedan – det var inte bra. {reason}Skriv EN kort lärdom på svenska (högst två meningar, högst 220 tecken) om vad du ska UNDVIKA nästa gång en liknande fråga kommer, och vad du gör i stället: t.ex. gissade i stället för att hämta data, för långt, fel verktyg, fel ton. Skriv inte själva svaret. Svara med BARA lärdomen.

Frågan: {question}
Verktyg du använde: {tools}
Ditt svar (början):
{answer}"""

# The quick buttons under an answer (21 Oct): what each asks the AI to do with that answer
REWRITES = {
    "kortare": ("Gör kortare", "Skriv om svaret kortare – behåll det viktigaste, samma språk och samma fakta."),
    "formell": ("Mer formell", "Skriv om svaret i en mer formell och artig ton, med samma innehåll."),
    "stavning": ("Rätta stavningen", "Rätta stavning, grammatik och skiljetecken i svaret utan att ändra innehållet eller stilen."),
    "engelska": ("Översätt till engelska", "Översätt svaret till engelska. Behåll formatering, kod, länkar och namn."),
}
REWRITE_TAIL = " Svara bara med den nya versionen – ingen inledning, inga kommentarer, inga verktyg."


def rewrite_message(kind, answer, last=True):
    """(what the chat shows, what the AI is asked) for a quick button; the answer is quoted unless it is the last one."""
    label, wish = REWRITES[kind]
    content = wish + REWRITE_TAIL
    if not last or len(answer) <= 20000:
        content += "\n\nSvaret:\n\"\"\"\n" + answer[:20000] + "\n\"\"\""
    return label, content


TOOL_NAMES = {"sök": "sökte på nätet", "wowfel": "läste WoW-felen", "warcraftlogs": "hämtade pullen från Warcraft Logs",
              "sport": "hämtade lagets ställning", "systemfel": "läste datorns fel"}


def load_lessons():
    try:
        items = json.loads(LESSONS_FILE.read_text())
        return [i for i in items if isinstance(i, dict) and str(i.get("lesson", "")).strip()]
    except (OSError, ValueError):
        return []


def save_lessons(items):
    LESSONS_FILE.parent.mkdir(parents=True, exist_ok=True)
    LESSONS_FILE.write_text(json.dumps(items[-LESSONS_MAX:], ensure_ascii=False, indent=1))


def tools_text(tools):
    return ", ".join(f"{TOOL_NAMES.get(t, t)}{f' ({q})' if q else ''}" for t, q in tools) or "inga – svarade direkt"


def make_lesson(question, answer, tools, keys, project=None, choice="", kind="good", reason=""):
    """The AI's own short lesson from an answer the user liked – or, kind "avoid", disliked (👎, with the
    user's reason if given); a plain one when no service answers."""
    if kind == "avoid":
        why = f"Användaren skrev vad som var fel: \"{' '.join(str(reason).split())[:400]}\". " if reason.strip() else ""
        prompt = AVOID_PROMPT.format(reason=why, question=str(question)[:1500], tools=tools_text(tools),
                                     answer=str(answer)[:2500])
    else:
        prompt = LESSON_PROMPT.format(question=str(question)[:1500], tools=tools_text(tools), answer=str(answer)[:2500])
    QUICK.on = True  # a sentence – no long thinking
    try:
        text, _ = ask_once([{"role": "system", "content": "Du skriver korta lärdomar på svenska."},
                            {"role": "user", "content": prompt}], keys, project=project, choice=choice)
    except ServiceError:
        text = ""
    finally:
        QUICK.on = False
    text = " ".join(re.sub(r"```.*?```", "", text, flags=re.S).split()).strip(" \"'")
    if not text and kind == "avoid":
        text = (f"Användaren tyckte inte om svaret: {' '.join(reason.split())}"[:LESSON_LENGTH] if reason.strip() else
                "Svaret var inte bra – hämta data i stället för att gissa, och håll dig till det som frågades.")
    if not text:
        text = ("Svarade utan verktyg, kort och rakt på sak." if not tools else
                f"{tools_text(tools)[0].upper()}{tools_text(tools)[1:]} och svarade utifrån det.")
    return text[:LESSON_LENGTH]


def add_lesson(question, lesson, tools, service="", project=None, kind="good"):
    items = load_lessons()
    entry = {"id": time.strftime("%Y%m%d-%H%M%S") + os.urandom(2).hex(), "kind": kind, "question": " ".join(str(question).split())[:400],
             "lesson": lesson, "tools": [t for t, _ in tools], "service": service,
             "project": (project or {}).get("id", ""), "added": date.today().isoformat()}
    items.append(entry)
    save_lessons(items)
    return entry


def remove_lesson(lesson_id):
    items = load_lessons()
    save_lessons([i for i in items if i.get("id") != lesson_id])


def edit_lesson(lesson_id, text):
    text = " ".join(str(text).split())[:LESSON_LENGTH]
    items = load_lessons()
    for i in items:
        if i.get("id") == lesson_id and text:
            i["lesson"] = text
    save_lessons(items)


def words(text):
    return {w for w in re.findall(r"[\wåäö]{3,}", str(text).casefold()) if w not in STOP_WORDS}


TOOL_HINTS = {"warcraftlogs": r"logs?\b|pull|boss|wcl|wipe|kill", "wowfel": r"bugsack|lua|tillägg|addon|fel i wow",
              "sport": r"\blag\b|match|tabell|serie", "systemfel": r"krasch|fel|startar inte|journal",
              "sök": r"senaste|nyheter|patch|pris"}


def lessons_for(question, project=None):
    """The lessons most like the question: shared words, the same project, a tool the question hints at."""
    asked = words(question)
    picked = []
    for item in load_lessons():
        score = len(asked & words(item["question"] + " " + item["lesson"]))
        if project and item.get("project") == project.get("id"):
            score += 2
        score += sum(2 for t in item.get("tools", []) if t in TOOL_HINTS and re.search(TOOL_HINTS[t], str(question), re.I))
        if score >= 2:
            picked.append((score, item["added"], item))
    picked.sort(key=lambda p: (p[0], p[1]), reverse=True)
    return [p[2] for p in picked[:LESSONS_PICK]]


def with_lessons(messages, project=None):
    """messages with the matching lessons added to the system prompt (a new list; the others untouched)."""
    if not messages or messages[0]["role"] != "system":
        return messages
    question = next((m["content"] for m in reversed(messages) if m["role"] == "user"), "")
    found = lessons_for(question if isinstance(question, str) else "", project)
    if not found:
        return messages
    good = [i for i in found if i.get("kind") != "avoid"]
    avoid = [i for i in found if i.get("kind") == "avoid"]
    text = ""
    if good:
        text += ("\n\nSå här gjorde du bra förut (användaren gav hjärta på de här svaren – gör likadant om det passar "
                 "den här frågan, annars inte):\n" + "\n".join(f"- Frågan \"{i['question'][:120]}\": {i['lesson']}" for i in good))
    if avoid:
        text += ("\n\nGör inte så här (användaren gav tumme ner på de här svaren – undvik samma misstag):\n"
                 + "\n".join(f"- Frågan \"{i['question'][:120]}\": {i['lesson']}" for i in avoid))
    return [{**messages[0], "content": messages[0]["content"] + text}] + list(messages[1:])


def memory_prompt():
    items = load_memory()
    if not items:
        return MEMORY_PROMPT
    return MEMORY_PROMPT + "\n\nDet här har användaren bett dig komma ihåg (gäller alltid):\n" + "\n".join(
        f"- {i['text']}" for i in items)


def system_prompt():
    text = SYSTEM_PROMPT.format(info=system_info()) + goblin_commands() + memory_prompt()
    name = ai_name()
    if name:
        text = text.replace("Du är Goblin AI, hjälparen i GOBLINCAKES",
                            f"Du heter {name} – användaren har döpt dig till det, så kalla dig {name} och svara "
                            f"när du blir tilltalad så. Du är hjälparen (Goblin AI) i GOBLINCAKES", 1)
    gender = ai_gender()
    if gender:
        text += (f"\n\nAnvändaren har valt att du är en {gender} ({GENDERS[gender]}): när någon pratar om dig, "
                 f"eller du beskriver eller ritar dig själv (t.ex. en avatar), utgå från det. Ta inte upp det i onödan.")
    text += REPORT_PROMPT
    if images_possible(load_keys()):
        text += IMAGE_PROMPT
    return text


DANGER = re.compile(r"\brm\s+-[a-z]*r|\bmkfs|\bdd\s|\bwipefs|>\s*/dev/sd|\bchmod\s+-R\s+777\s+/|\bsudo\b", re.I)


def run_in_folder(code, cwd, **kwargs):
    """Runs a command block in bash from cwd; returns (completed process, folder it ended in).

    Every block is its own bash, so without this a `cd` in one block was forgotten by the next –
    the folder is carried over like in a terminal (the end folder is written by an EXIT trap,
    so it also works when the block ends with `exit`)."""
    fd, cwd_file = tempfile.mkstemp(prefix="goblin-ai-cwd-")
    os.close(fd)
    try:
        proc = subprocess.run(["bash", "-c", command_script(code, cwd)],
                              env={**os.environ, "GOBLIN_CWD_FILE": cwd_file}, **kwargs)
        return proc, read_cwd(cwd_file, cwd)
    finally:
        os.unlink(cwd_file)


def command_script(code, cwd):
    """The bash script for a command block: start in cwd, write the end folder to $GOBLIN_CWD_FILE."""
    # On the same line as the code's first line, so bash's "rad N" in errors matches the block
    return (f"{{ cd -- {shlex.quote(cwd)} || cd; }} 2>/dev/null; "
            "[ -n \"$GOBLIN_CWD_FILE\" ] && trap 'pwd > \"$GOBLIN_CWD_FILE\"' EXIT; "
            f"{code}")


def read_cwd(cwd_file, fallback):
    try:
        folder = Path(cwd_file).read_text().strip()
    except OSError:
        return fallback
    return folder if folder and Path(folder).is_dir() else fallback


def code_blocks(text):
    """The ```bash blocks in an answer: the commands to offer."""
    return [b.strip() for b in re.findall(r"```(?:bash|sh|shell|console)\s*\n(.*?)```", text, re.S) if b.strip()]


def segments(text):
    """An answer split into parts for the window: text, command, file (a new version of a file) and code."""
    parts = []
    pos = 0
    for m in re.finditer(r"```([^\n`]*)\n(.*?)```", text, re.S):
        if m.start() > pos and text[pos:m.start()].strip():
            parts.append({"type": "text", "text": text[pos:m.start()].strip()})
        lang, code = m.group(1).strip(), m.group(2).rstrip("\n")
        if lang.lower() in ("bash", "sh", "shell", "console"):
            parts.append({"type": "command", "code": code, "danger": bool(DANGER.search(code)), "state": "new", "output": ""})
        elif lang.lower() in ("minne", "kom ihåg", "memory", "glöm", "glom", "forget"):
            items = [line.strip().lstrip("-•* ").strip() for line in code.splitlines() if line.strip()]
            if items:
                kind = "forget" if lang.lower() in ("glöm", "glom", "forget") else "memory"
                parts.append({"type": kind, "items": items, "state": "new"})
        elif lang.lower() in ("skärmbild", "skarmbild", "screenshot"):
            both = bool(re.search(r"båda|alla|both|all", code, re.I))
            parts.append({"type": "shot", "scope": "all" if both else "screen", "state": "new"})
        elif lang.lower() in REPORT_WORDS:
            if code.strip():
                title = next((re.sub(r"^#+\s*", "", l).strip() for l in code.splitlines() if l.strip()), "Rapport")
                parts.append({"type": "image", "report": True, "markdown": code, "prompt": title,
                              "format": "", "state": "new"})
        elif lang.lower() in ("bild", "image", "picture"):
            prompt, fmt = image_request(code)
            if prompt:
                parts.append({"type": "image", "prompt": prompt, "format": fmt, "state": "new"})
        elif lang.lower().startswith(("fil:", "file:")):
            parts.append({"type": "file", "name": lang.split(":", 1)[1].strip(), "code": code, "state": "new"})
        else:
            parts.append({"type": "code", "lang": lang, "code": code})
        pos = m.end()
    if text[pos:].strip():
        parts.append({"type": "text", "text": text[pos:].strip()})
    return parts


def file_message(path, question, limit=200_000):
    """The user's question with a text file attached (raises ValueError for binary or huge files)."""
    data = Path(path).read_bytes()
    if b"\0" in data[:8192]:
        raise ValueError("Filen är inte en textfil.")
    text = data.decode("utf-8", errors="replace")
    if len(text) > limit:
        raise ValueError("Filen är för stor (max cirka 200 000 tecken).")
    name = Path(path).name
    return f"{question}\n\nBifogad fil: {name}\n```\n{text}\n```"


# ── Projects (15 Oct): own instructions, files, models and where they may run ──────────

PROJECTS_FILE = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "goblincakes/ai/projects.json"
ORDERS = ("inherit", "local-first", "cloud-first", "local-only", "cloud-only")

# Starting points for a new project (all of it can be changed afterwards)
TEMPLATES = {
    "kod": {"name": "Kod", "prefer": "kod", "search": True, "order": "inherit",
            "instructions": "Du hjälper till med programmering. Svara med fungerande kod i kodblock, "
                            "förklara kort vad den gör och varför, och säg till om något behöver testas."},
    "vardag": {"name": "Vardag", "prefer": "vardag", "search": True, "order": "inherit", "instructions": ""},
    "bilder": {"name": "Bilder", "prefer": "bild", "search": False, "order": "inherit",
               "instructions": "Du hjälper till att läsa av, beskriva och tolka bilder och skärmbilder."},
    "privat": {"name": "Privat", "prefer": "vardag", "search": False, "order": "local-only",
               "instructions": "Allt i det här projektet stannar på datorn."},
}
FILE_LIMIT = 60_000      # characters per fixed file
FILES_LIMIT = 150_000    # all fixed files together


def load_projects():
    try:
        data = json.loads(PROJECTS_FILE.read_text())
    except (OSError, ValueError):
        return []
    return [clean_project(p) for p in data if isinstance(p, dict) and p.get("id")]


def clean_project(p):
    return {"id": str(p["id"]), "name": str(p.get("name") or "Projekt")[:60],
            "instructions": str(p.get("instructions") or "")[:20_000],
            "order": p.get("order") if p.get("order") in ORDERS else "inherit",
            "prefer": p.get("prefer") if p.get("prefer") in ("vardag", "kod", "bild") else "vardag",
            "models": {r: str(m) for r, m in (p.get("models") or {}).items() if r in ("vardag", "kod", "bild") and m},
            "files": [str(f) for f in p.get("files") or []][:20],
            "search": p.get("search") is not False,
            "folder": str(p.get("folder") or "")}


def save_projects(projects):
    PROJECTS_FILE.parent.mkdir(parents=True, exist_ok=True)
    tmp = PROJECTS_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps([clean_project(p) for p in projects], ensure_ascii=False, indent=1))
    tmp.replace(PROJECTS_FILE)


def project_prompt(project):
    """The project's part of the system prompt: its name, instructions and fixed files (read each time,
    so a changed file is seen at once)."""
    if not project:
        return ""
    parts = [f"\n\nProjekt: {project['name']}. Det här samtalet hör till projektet."]
    if project["instructions"].strip():
        parts.append("Projektets instruktioner (följ dem):\n" + project["instructions"].strip())
    if project["folder"]:
        parts.append(f"Projektets mapp för sparade filer: {project['folder']}")
    used = 0
    for f in project["files"]:
        path = Path(f).expanduser()
        try:
            text = path.read_text(errors="replace")
        except OSError:
            parts.append(f"(Den fasta filen {path.name} gick inte att läsa.)")
            continue
        text = text[:FILE_LIMIT]
        if used + len(text) > FILES_LIMIT:
            parts.append(f"(Den fasta filen {path.name} fick inte plats.)")
            continue
        used += len(text)
        parts.append(f"Fast fil i projektet – {path.name} ({path}):\n```\n{text}\n```")
    return "\n\n".join(parts)


# ── Pictures (16 Oct): "make a picture of …" in the chat, or the Skapa bild button ─────────
# The AI answers with a ```bild block (an English description); the window draws it at once.
# Order: this computer (goblincakes-image, stable-diffusion.cpp) → Cloudflare (free daily allowance)
# → Gemini (only with Google's paid plan), OpenAI, Grok – each only with a key. A project's
# "where it may run" (and the local AI's choice in AI-tjänster) decides like for text.

IMAGE_HELPER = os.environ.get("GOBLINCAKES_IMAGE_HELPER", "/usr/libexec/goblincakes-image")
IMAGE_FILE = CONFIG / "image.json"
FORMATS = {"1:1": (1024, 1024), "16:9": (1280, 720), "9:16": (720, 1280), "4:3": (1152, 864), "3:4": (864, 1152)}
FORMAT_WORDS = {"kvadrat": "1:1", "fyrkantig": "1:1", "square": "1:1", "liggande": "16:9", "bred": "16:9",
                "landscape": "16:9", "stående": "9:16", "hög": "9:16", "portrait": "9:16"}
IMAGE_PAID = ("gemini", "openai", "xai")  # the cloud services that can draw, after Cloudflare

IMAGE_PROMPT = """

Bilder: du kan skapa bilder. När användaren vill ha en bild (skapa, rita, göra, måla, en bild på …) eller vill
ändra den förra bilden: skriv en kort mening på användarens språk och sedan ett kodblock märkt ```bild med en
utförlig beskrivning PÅ ENGELSKA – motiv, stil (foto, målning, tecknat, pixelkonst …), ljus, färger, komposition;
text som ska synas i bilden inom citattecken. Valfri första rad i blocket: Format: 16:9 (liggande), 9:16 (stående),
1:1, 4:3 eller 3:4. Exempel:
```bild
Format: 16:9
A small green goblin baking blue cupcakes in a cozy cave, warm candle light, detailed digital painting
```
Bilden skapas automatiskt av Goblin AI och visas under svaret – skriv aldrig att du inte kan skapa bilder.
```bild är bara för bilder med motiv. Sammanställningar, rapporter, analyser, tabeller och listor "som bild/png"
görs ALDRIG med ```bild (bildmodellen kan inte skriva exakt text eller siffror) – använd ```rapport.
Ska bilden ändras: skriv en ny, hel beskrivning (den förra bilden följer inte med). Ett block per bild.
Vill användaren att du får en avatar/profilbild (en bild av dig själv): rita den med ```bild, Format: 1:1, ett tydligt
porträtt eller en figur mitt i bilden mot en enkel bakgrund (den visas liten och beskärs till en fyrkant). Säg sedan
att knappen "Använd som avatar" under bilden gör den till din avatar, och att "Gör en till" ger ett nytt förslag."""


def image_request(code):
    """(English description, format) from a ```bild block; an optional first line "Format: 16:9"."""
    lines = code.strip().splitlines()
    fmt = "1:1"
    if lines:
        m = re.match(r"\s*(format|storlek|size)\s*:\s*(.+)$", lines[0], re.I)
        if m:
            value = m.group(2).strip().lower()
            fmt = value if value in FORMATS else FORMAT_WORDS.get(value.split()[0], "1:1")
            lines = lines[1:]
    return " ".join(" ".join(lines).split()), fmt


def local_image_status():
    """{"ready", "model"}: the picture program is installed and has a model."""
    try:
        data = json.loads(IMAGE_FILE.read_text())
    except (OSError, ValueError):
        return {"ready": False, "model": ""}
    ready = bool(data.get("dir")) and (Path(data["dir"]) / "bin/sd-cli").is_file() and bool(data.get("files"))
    return {"ready": ready, "model": data.get("model") or next(iter(data.get("files") or {}), "")}


def images_possible(keys):
    """Can a picture be made at all (Gemini's free key can't – it needs the paid plan)?"""
    return local_image_status()["ready"] or any(keys.get(p["env"]) for p in [CLOUDFLARE] + [
        p for p in PROVIDERS if p["id"] in ("openai", "xai")])


def image_sources(keys, order=None):
    """The places to draw, in order: "local", then the cloud services (ids) that have a key."""
    cloud = [s for s in ("cloudflare",) + IMAGE_PAID
             if keys.get(CLOUDFLARE["env"] if s == "cloudflare" else next(p["env"] for p in PROVIDERS if p["id"] == s))]
    local = ["local"] if local_image_status()["ready"] else []
    order = order if order in ("local-first", "cloud-first", "local-only", "cloud-only") else local_settings()["order"]
    if not local_settings()["installed"] and order == "cloud-only":
        order = "local-first"  # without the local AI its choice says nothing about pictures
    if order == "local-only":
        return local
    if order == "cloud-only":
        return cloud
    return cloud + local if order == "cloud-first" else local + cloud


def pictures_folder(project=None):
    if project and project.get("folder"):
        return Path(project["folder"]).expanduser()
    try:
        pics = subprocess.run(["xdg-user-dir", "PICTURES"], capture_output=True, text=True, timeout=5).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        pics = ""
    return Path(pics if pics and pics != str(Path.home()) else Path.home() / "Bilder") / "Goblin AI"


REPORT_WORDS = ("rapport", "report", "infografik", "sammanställning", "sammanstallning")

REPORT_PROMPT = """

Rapporter som bild: BARA när användaren själv uttryckligen ber om en bild, png, infografik eller "i
GOBLINCAKES-mallen" (aldrig av dig själv, aldrig för en sammanställning, analys eller PDF som inte bett om bild –
då svarar du med vanlig text), skriv EN kort mening och sedan hela innehållet i ett kodblock
märkt ```rapport i Markdown – Goblin AI gör blocket till en PNG (mörk bakgrund, numrerade rutor, tabeller):
```rapport
# Rubrik
En rad under rubriken (t.ex. datum, resultat, vem)

## Första avsnittet
- **Fetstil:** punkt
- punkt

## Avsnitt med tabell
| Namn | Värde |
|---|---|
| A | 12 |
| Totalt | 12 |
```
Regler: "# " en gång överst, "## " för varje ruta (3–6 rutor, korta rubriker, numreras automatiskt), punktlistor
och tabeller hellre än långa stycken, siffrorna exakt som i datan (hitta aldrig på), en rad som börjar med
Totalt/Summa blir summaraden. Rubrikerna väljs efter innehållet – mallen gäller utseendet, inte rubrikerna.
Inget annat block i samma svar behövs; bilden visas automatiskt under svaret.

PDF och Word: under varje svar i Goblin AI-fönstret finns knappen "Spara som…" (och "Spara som bild"), som sparar
just det svaret som PDF, Word (.docx), OpenDocument, text eller Markdown på datorn, och "Kopiera svaret" kopierar
med formatering (klistras in snyggt i Word och mejl). Där finns också snabbknapparna Gör kortare, Mer formell,
Rätta stavningen och Översätt till engelska. Ber användaren om en PDF eller ett Word-dokument (av det du hittat,
en sammanfattning, en rapport), säg aldrig att du inte kan göra sådana: skriv hela innehållet i ETT svar i vanlig Markdown (rubriker, listor,
tabeller – inget kodblock runt det, siffrorna exakt som i datan) och avsluta med en kort rad om att trycka på
"Spara som…" under svaret och välja PDF eller Word. Ligger det användaren vill ha i flera tidigare svar, samla det i det nya svaret.

Efter en sammanställning eller analys (t.ex. av Warcraft Logs) som användaren inte bett om i ett visst format:
avsluta med frågan "Vill du ha det här som bild eller PDF?". Svarar användaren bild → ```rapport med samma
innehåll; PDF → säg att knappen "Spara som…" under svaret sparar det (välj PDF)."""


def make_report(markdown, project=None, footer=""):
    """A ```rapport block → a PNG in GOBLINCAKES' look (report.py, drawn here with Qt). Returns the path."""
    here = Path(__file__).resolve().parent
    for d in (here, here.parent):
        if str(d) not in sys.path:
            sys.path.insert(0, str(d))
    import report  # noqa: PLC0415 – Qt is loaded only when a report is drawn
    title = next((re.sub(r"^#+\s*", "", l).strip() for l in markdown.splitlines() if l.strip()), "rapport")
    path, _ = report.render(markdown, image_path(pictures_folder(project), "rapport " + title), footer)
    return path


def image_path(folder, prompt, ext="png"):
    words = re.sub(r"[^\w\s-]", "", prompt.lower()).split()[:6]
    name = time.strftime("%Y-%m-%d %H.%M.%S") + (" " + "-".join(words) if words else "")
    return Path(folder) / f"{name[:90]}.{ext}"


def save_picture(data, folder, prompt):
    """Bytes from a cloud service → a file (PNG, JPEG or WebP, by its first bytes)."""
    ext = "jpg" if data[:3] == b"\xff\xd8\xff" else "webp" if data[8:12] == b"WEBP" else "png"
    path = image_path(folder, prompt, ext)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return path


def make_image(prompt, fmt, keys, project=None, status=None, notice=None, progress=None):
    """Draws a picture; returns (path, "where · model"). status(text), progress(text, 0–1 or -1)."""
    activity("image", "ritar en bild")
    try:
        return _make_image(prompt, fmt, keys, project, status, notice, progress)
    finally:
        activity_done()


def _make_image(prompt, fmt, keys, project=None, status=None, notice=None, progress=None):
    folder = pictures_folder(project)
    errors = []
    sources = image_sources(keys, (project or {}).get("order"))
    for source in sources:
        if source in EXHAUSTED_IMAGES:
            continue
        try:
            if source == "local":
                return local_image(prompt, fmt, folder, status, progress)
            activity("image", f"ritar en bild · {IMAGE_NAMES[source]}")
            if status:
                status(f"Ritar bilden hos {IMAGE_NAMES[source]}…")
            data, model = CLOUD_DRAW[source](prompt, fmt, keys)
            return save_picture(data, folder, prompt), f"{IMAGE_NAMES[source]} · {model}"
        except ServiceError as e:
            errors.append(f"{'Din dator' if source == 'local' else IMAGE_NAMES[source]}: {e}")
            if source != "local" and re.search(r"slut|fel nyckel|betalplan", str(e)):
                EXHAUSTED_IMAGES.add(source)
            if notice and source != sources[-1]:
                notice(f"{errors[-1]} – provar nästa")
    if not errors:
        if project and project.get("order") == "local-only":
            raise ServiceError("Projektet får bara använda din dator, men bildprogrammet är inte installerat "
                               "(AI-tjänster → Skapa bilder).")
        raise ServiceError("Inget kan skapa bilder än: installera bildprogrammet eller lägg in en "
                           "Cloudflare-nyckel under AI-tjänster.")
    hint = ("" if keys.get(CLOUDFLARE["env"]) else
            "\nTips: med en gratis Cloudflare-nyckel (AI-tjänster) ritas bilder i molnet när din dator inte kan.")
    raise ServiceError("Bilden kunde inte skapas.\n" + "\n".join(errors) + hint)


EXHAUSTED_IMAGES = set()
IMAGE_NAMES = {"cloudflare": "Cloudflare", "gemini": "Google Gemini", "openai": "OpenAI", "xai": "Grok"}


def local_image(prompt, fmt, folder, status=None, progress=None):
    width, height = FORMATS.get(fmt, FORMATS["1:1"])
    path = image_path(folder, prompt)
    model = local_image_status()["model"]
    names = {"z-image-turbo": "Z-Image-Turbo", "flux2-klein-4b": "FLUX.2 klein 4B", "flux2-klein-9b": "FLUX.2 klein 9B"}
    activity("image", "ritar en bild · din dator", True)
    if status:
        status("Ritar bilden på din dator…")
    proc = subprocess.Popen([IMAGE_HELPER, "generate", str(path), str(width), str(height)],
                            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    proc.stdin.write(prompt)
    proc.stdin.close()
    for line in proc.stdout:
        line = line.rstrip("\n")
        if line.startswith("@@progress "):
            try:
                ev = json.loads(line[11:])
                activity("image", "ritar en bild · din dator", True, round(100 * ev["completed"] / ev["total"]))
                if progress:
                    progress(f"Ritar på din dator – steg {ev['completed']} av {ev['total']}", ev["completed"] / ev["total"])
            except (ValueError, KeyError, ZeroDivisionError):
                pass
        elif line.startswith("@@ ") and progress:
            progress(line[3:], -1.0)
    err = proc.stderr.read().strip()
    if proc.wait() != 0 or not path.is_file():
        raise ServiceError((err.splitlines() or ["bilden blev inte klar"])[-1])
    return path, f"Din dator · {names.get(model, model)}"


def post(url, headers, body, timeout=300, raw_body=None):
    """POST JSON (or raw multipart bytes); returns the JSON answer. Errors as ServiceError."""
    req = urllib.request.Request(url, data=raw_body if raw_body is not None else json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json", "User-Agent": "goblincakes-ai", **headers})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:400]
        if e.code in (401, 403) and "billing" not in detail:
            raise ServiceError("fel nyckel") from None
        if re.search(r"limit: 0|billing|paid plan", detail):
            raise ServiceError("kräver tjänstens betalplan") from None
        if e.code in (402, 429) or re.search(r"daily free allocation|insufficient_quota|credit", detail, re.I):
            raise ServiceError("slut på bilder just nu (dagens gratisbilder eller krediterna)") from None
        if re.search(r"safety|moderation|content_policy|blocked", detail, re.I):
            raise ServiceError("tjänsten ville inte göra den bilden") from None
        if e.code >= 500:
            raise ServiceError(f"överbelastad just nu (fel {e.code})") from None
        raise ServiceError(f"fel {e.code} ({detail.strip()[:200]})") from None
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        raise ServiceError(f"nås inte ({getattr(e, 'reason', e)})") from None


def cloudflare_account(key, refresh=False):
    """(account id, token): "id:token" as given, else the token's first account (cached)."""
    if ":" in key:
        account, token = key.split(":", 1)
        return account.strip(), token.strip()
    cache_file = CACHE / "cloudflare.json"
    try:
        cache = json.loads(cache_file.read_text())
    except (OSError, ValueError):
        cache = {}
    tag = key[-8:]
    if cache.get("tag") == tag and cache.get("account") and not refresh:
        return cache["account"], key
    req = urllib.request.Request(CLOUDFLARE["url"] + "/accounts", headers={"Authorization": f"Bearer {key}",
                                                                          "User-Agent": "goblincakes-ai"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            accounts = json.loads(r.read()).get("result") or []
    except urllib.error.HTTPError as e:
        raise ServiceError("fel nyckel" if e.code in (400, 401, 403) else f"fel {e.code}") from None
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        raise ServiceError(f"nås inte ({getattr(e, 'reason', e)})") from None
    if not accounts:
        raise ServiceError("nyckeln hör inte till något konto – skapa den under Workers AI")
    CACHE.mkdir(parents=True, exist_ok=True)
    cache_file.write_text(json.dumps({"tag": tag, "account": accounts[0]["id"]}))
    return accounts[0]["id"], key


def draw_cloudflare(prompt, fmt, keys):
    account, token = cloudflare_account(keys[CLOUDFLARE["env"]])
    run = f"{CLOUDFLARE['url']}/accounts/{account}/ai/run/@cf/black-forest-labs/"
    auth = {"Authorization": f"Bearer {token}"}
    width, height = FORMATS.get(fmt, FORMATS["1:1"])
    # FLUX.2 [klein] takes a form (multipart); FLUX.1 schnell (JSON, always square) when it fails
    boundary = "goblincakes" + os.urandom(8).hex()
    fields = {"prompt": prompt[:2048], "width": str(width), "height": str(height)}
    body = b"".join(f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode()
                    for k, v in fields.items()) + f"--{boundary}--\r\n".encode()
    try:
        reply = post(run + "flux-2-klein-4b", dict(auth, **{"Content-Type": f"multipart/form-data; boundary={boundary}"}),
                     None, raw_body=body)
        model = "FLUX.2 klein 4B"
    except ServiceError as e:
        if re.search(r"slut|fel nyckel", str(e)):
            raise
        reply = post(run + "flux-1-schnell", auth, {"prompt": prompt[:2048], "steps": 6})
        model = "FLUX.1 schnell"
    image = (reply.get("result") or {}).get("image")
    if not image:
        raise ServiceError("tomt svar")
    return base64.b64decode(image), model


def image_model(provider, key, patterns, default):
    """The service's image model, from its model list (cached for a day)."""
    cache = {}
    try:
        cache = json.loads(MODELS_CACHE.read_text())
    except (OSError, ValueError):
        pass
    entry = cache.get(provider["id"] + "-image")
    if entry and time.time() - entry["time"] < 86400:
        return entry["model"]
    try:
        ids = [m["id"].removeprefix("models/") for m in request(provider, key, "/models", timeout=30).get("data", [])]
    except ServiceError:
        ids = []
    model = default
    for pattern in patterns:
        found = sorted((i for i in ids if re.search(pattern, i)), reverse=True)
        if found:
            model = found[0]
            break
    cache[provider["id"] + "-image"] = {"model": model, "time": time.time()}
    CACHE.mkdir(parents=True, exist_ok=True)
    MODELS_CACHE.write_text(json.dumps(cache))
    return model


def provider(pid):
    return next(p for p in PROVIDERS if p["id"] == pid)


def draw_openai_style(pid, prompt, fmt, keys):
    p = provider(pid)
    key = keys[p["env"]]
    if pid == "openai":
        model = image_model(p, key, [r"^gpt-image-\d+(\.\d+)?$", r"^gpt-image"], "gpt-image-1")
        size = {"16:9": "1536x1024", "4:3": "1536x1024", "9:16": "1024x1536", "3:4": "1024x1536"}.get(fmt, "1024x1024")
        body = {"model": model, "prompt": prompt, "size": size, "n": 1}
    else:
        model = image_model(p, key, [r"imagine-image", r"image"], "grok-2-image")
        body = {"model": model, "prompt": prompt, "n": 1, "response_format": "b64_json"}
    reply = post(p["url"] + "/images/generations", {"Authorization": f"Bearer {key}"}, body)
    data = (reply.get("data") or [{}])[0]
    if data.get("b64_json"):
        return base64.b64decode(data["b64_json"]), model
    if data.get("url"):
        try:
            with urllib.request.urlopen(data["url"], timeout=60) as r:
                return r.read(), model
        except (urllib.error.URLError, OSError) as e:
            raise ServiceError(f"bilden gick inte att hämta ({e})") from None
    raise ServiceError("tomt svar")


def draw_gemini(prompt, fmt, keys):
    p = provider("gemini")
    key = keys[p["env"]]
    model = image_model(p, key, [r"^gemini-[\d.]+-flash-image$", r"^gemini-.*-image$"], "gemini-2.5-flash-image")
    reply = post(f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
                 {"x-goog-api-key": key},
                 {"contents": [{"parts": [{"text": prompt}]}],
                  "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": fmt}}})
    for cand in reply.get("candidates") or []:
        for part in (cand.get("content") or {}).get("parts") or []:
            data = part.get("inlineData") or part.get("inline_data")
            if data and data.get("data"):
                return base64.b64decode(data["data"]), model
    raise ServiceError("tjänsten ville inte göra den bilden")


CLOUD_DRAW = {
    "cloudflare": draw_cloudflare,
    "gemini": draw_gemini,
    "openai": lambda prompt, fmt, keys: draw_openai_style("openai", prompt, fmt, keys),
    "xai": lambda prompt, fmt, keys: draw_openai_style("xai", prompt, fmt, keys),
}
