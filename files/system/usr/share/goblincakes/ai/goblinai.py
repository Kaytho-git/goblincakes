"""goblinai – shared core of Goblin AI (the window /usr/bin/goblin-ai and "goblin ai" in the terminal).

Uses the free tiers of Gemini, Groq, OpenRouter and Mistral through their
OpenAI-compatible APIs, in that order; when one is out of quota or fails, the
next one answers. Keys: ~/.config/goblincakes/ai.env (only readable by you).
"""
import getpass
import json
import os
import re
import subprocess
import time
import urllib.error
import urllib.request
from pathlib import Path

CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "goblincakes"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "goblincakes"
KEYS_FILE = CONFIG / "ai.env"
MODELS_CACHE = CACHE / "ai-models.json"

PROVIDERS = [
    {
        "id": "gemini", "name": "Google Gemini", "env": "GEMINI_API_KEY",
        "url": "https://generativelanguage.googleapis.com/v1beta/openai",
        "keys_page": "https://aistudio.google.com/apikey",
        "how": "Logga in med ditt Google-konto och tryck på Create API key.",
        "prefer": [r"^gemini-[\d.]+-flash$", r"^gemini-flash-latest$", r"^gemini-.*flash(?!.*(lite|image|tts|audio|live|thinking))"],
    },
    {
        "id": "groq", "name": "Groq", "env": "GROQ_API_KEY",
        "url": "https://api.groq.com/openai/v1",
        "keys_page": "https://console.groq.com/keys",
        "how": "Skapa ett gratis konto och tryck på Create API Key.",
        "prefer": [r"llama-3\.3-70b", r"llama.*70b", r"^openai/gpt-oss-120b$", r"llama"],
    },
    {
        "id": "openrouter", "name": "OpenRouter (gratismodeller)", "env": "OPENROUTER_API_KEY",
        "url": "https://openrouter.ai/api/v1",
        "keys_page": "https://openrouter.ai/settings/keys",
        "how": "Skapa ett gratis konto och tryck på Create Key. Bara gratismodeller används.",
        "prefer": [],  # picked among the free ones, see pick_model
    },
    {
        "id": "mistral", "name": "Mistral", "env": "MISTRAL_API_KEY",
        "url": "https://api.mistral.ai/v1",
        "keys_page": "https://console.mistral.ai/api-keys",
        "how": "Skapa ett konto, välj den gratis planen (Experiment) och skapa en API-nyckel.",
        "prefer": [r"^mistral-small-latest$", r"^mistral-medium-latest$", r"^mistral-large-latest$"],
    },
]


def load_keys():
    keys = {}
    if KEYS_FILE.exists():
        for line in KEYS_FILE.read_text().splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                name, value = line.split("=", 1)
                keys[name.strip()] = value.strip()
    for p in PROVIDERS:  # environment variables win
        if os.environ.get(p["env"]):
            keys[p["env"]] = os.environ[p["env"]]
    return keys


def save_keys(keys):
    CONFIG.mkdir(parents=True, exist_ok=True)
    old_umask = os.umask(0o077)
    try:
        lines = ["# goblin ai – free API keys (only readable by you). Remove a line to stop using that service."]
        lines += [f"{p['env']}={keys[p['env']]}" for p in PROVIDERS if keys.get(p["env"])]
        KEYS_FILE.write_text("\n".join(lines) + "\n")
    finally:
        os.umask(old_umask)
    KEYS_FILE.chmod(0o600)


class ServiceError(Exception):
    pass


def request(provider, key, path, body=None, timeout=90):
    req = urllib.request.Request(
        provider["url"] + path,
        data=json.dumps(body).encode() if body is not None else None,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "User-Agent": "goblincakes-ai",
            # OpenRouter asks apps to say who they are
            "HTTP-Referer": "https://github.com/Kaytho-git/goblincakes",
            "X-Title": "GOBLINCAKES goblin ai",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:300]
        reason = {401: "fel nyckel", 403: "nyckeln får inte användas", 429: "slut på gratisfrågor just nu"}.get(e.code, f"fel {e.code}")
        raise ServiceError(f"{reason} ({detail.strip()})" if e.code not in (401, 429) else reason) from None
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        raise ServiceError(f"nås inte ({getattr(e, 'reason', e)})") from None


def pick_model(provider, key, refresh=False):
    """The service's best free chat model, from its own model list (cached for a day)."""
    cache = {}
    if MODELS_CACHE.exists():
        try:
            cache = json.loads(MODELS_CACHE.read_text())
        except ValueError:
            cache = {}
    entry = cache.get(provider["id"])
    if entry and not refresh and time.time() - entry["time"] < 86400:
        return entry["model"]

    data = request(provider, key, "/models", timeout=30).get("data", [])
    ids = [m["id"].removeprefix("models/") for m in data if "id" in m]
    model = None
    if provider["id"] == "openrouter":
        free = [m for m in data
                if str(m.get("pricing", {}).get("prompt")) in ("0", "0.0")
                and str(m.get("pricing", {}).get("completion")) in ("0", "0.0")
                and "text" in str(m.get("architecture", {}).get("output_modalities", ["text"]))]
        free.sort(key=lambda m: m.get("context_length") or 0, reverse=True)
        model = free[0]["id"] if free else None
    else:
        for pattern in provider["prefer"]:
            matches = sorted((i for i in ids if re.search(pattern, i)), reverse=True)
            if matches:
                model = matches[0]
                break
        model = model or (ids[0] if ids else None)
    if not model:
        raise ServiceError("hittade ingen modell att använda")
    cache[provider["id"]] = {"model": model, "time": time.time()}
    CACHE.mkdir(parents=True, exist_ok=True)
    MODELS_CACHE.write_text(json.dumps(cache))
    return model


EXHAUSTED = set()  # services out of free questions: not asked again while the program runs


def ask(messages, keys, status=None, notice=None):
    """Asks the services in order; returns (answer, "service · model").

    status(text): "asking X…"; notice(text): a service failed and the next is tried.
    """
    errors = []
    for provider in PROVIDERS:
        key = keys.get(provider["env"])
        if not key or provider["id"] in EXHAUSTED:
            continue
        try:
            for attempt in range(2):
                model = pick_model(provider, key, refresh=attempt > 0)
                if status:
                    status(f"Frågar {provider['name']}…")
                try:
                    reply = request(provider, key, "/chat/completions",
                                    {"model": model, "messages": messages, "temperature": 0.4})
                    break
                except ServiceError as e:
                    # A model that disappeared: pick again once
                    if attempt == 0 and re.search(r"fel 40[04]", str(e)):
                        continue
                    raise
            text = reply["choices"][0]["message"].get("content") or ""
            if not text.strip():
                raise ServiceError("tomt svar")
            return text, f"{provider['name']} · {model}"
        except (ServiceError, KeyError, IndexError) as e:
            errors.append(f"{provider['name']}: {e}")
            if "slut på gratisfrågor" in str(e) or "fel nyckel" in str(e):
                EXHAUSTED.add(provider["id"])
            if notice:
                notice(f"{provider['name']}: {e} – provar nästa")
    if not errors:
        raise ServiceError("Ingen AI-tjänst är inställd.")
    raise ServiceError("Ingen AI-tjänst svarade.\n" + "\n".join(errors))


def has_keys(keys):
    return any(keys.get(p["env"]) for p in PROVIDERS)


def system_info():
    info = []
    try:
        osr = dict(line.split("=", 1) for line in Path("/etc/os-release").read_text().splitlines() if "=" in line)
        info.append(f"OS: {osr.get('PRETTY_NAME', '').strip(chr(34))} (bygger på Fedora {osr.get('VERSION_ID', '?').strip(chr(34))})")
    except OSError:
        pass
    info.append(f"Kärna: {os.uname().release}")
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
- Terminal: Ghostty. Filhanterare: Dolphin.

När användaren vill få något gjort på datorn:
- Ge de kommandon som behövs i kodblock märkta ```bash – ett kommando eller en kort följd per block.
  Användaren får frågan om varje block innan det körs, och du får se utskriften efteråt.
- Ta ett steg i taget när du behöver se resultatet först. Skriv inga ```bash-block när inget ska köras.
- Använd sudo bara när det verkligen behövs och säg varför. Var extra försiktig med kommandon som tar bort saker.
- När uppgiften är klar: säg det kort, utan kodblock.

När användaren har bifogat en fil och vill ha den ändrad (t.ex. rättad, översatt, omskriven):
- Ge HELA den nya versionen i ett kodblock märkt ```fil:FILNAMN (samma filnamn), så kan den sparas med en knapp.
  Kort före blocket: vad du har ändrat."""


def system_prompt():
    return SYSTEM_PROMPT.format(info=system_info())


DANGER = re.compile(r"\brm\s+-[a-z]*r|\bmkfs|\bdd\s|\bwipefs|>\s*/dev/sd|\bchmod\s+-R\s+777\s+/|\bsudo\b", re.I)


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
