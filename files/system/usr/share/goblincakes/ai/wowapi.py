"""WoW's API for Goblin AI (point 22, 29 Oct): gemma4 knows Lua but not WoW's API – her gear add-on called
GetItemName, GetItemLevel and CreateFrame("ScrollingFrame") from memory, and "## InterfaceTool" stopped it showing.

- Two sources for the live game, fetched into ~/.local/share/goblincakes/wowapi/ (not the image: they change with
  every patch) and again when older than a week; only read, never unpacked or run – index.json holds what is needed:
  - Ketho/BlizzardInterfaceResources: what exists, dumped from the game itself – every global function (C_Item.…
    and the old ones like GetInventoryItemLink), the frame types with their methods and what they inherit, the events.
  - Gethe/wow-ui-source: Blizzard's own interface code – the documentation (arguments, returns, event values), an
    example call for undocumented functions, the old names Blizzard keeps for a while (Deprecated_*).
- lookup(query): a function, an event, a frame type's methods, a namespace's functions – or "finns inte, menade du …".
- check(folder): an add-on's .toc and .lua: the .toc's name and lines, the interface number, functions, frame types,
  methods and events that don't exist, slash commands that never reach their function. Calls the code guards
  (`if GetContainerItemLink then …`) are left alone – a fallback for older game versions, not a fault.
- own_addon(path): whether one of the user's own add-ons (their git clones, or ~/.config/goblincakes/egna-tillagg) –
  Goblin AI changes only those (cmdlevel's lock); everybody else's are only read and explained.
"""
import difflib
import io
import json
import re
import subprocess
import sys
import tarfile
import time
import urllib.request
from pathlib import Path

HOME = Path.home()
DATA = HOME / ".local/share/goblincakes/wowapi"
INDEX = DATA / "index.json"
OWN_LIST = HOME / ".config/goblincakes/egna-tillagg"  # one add-on folder per line – else the user's git clones
ADDONS = HOME / "Games/WoW/Retail/AddOns"  # goblincakes-wow-links → the game's Interface/AddOns
SOURCE = "https://codeload.github.com/Gethe/wow-ui-source/tar.gz/refs/heads/live"
KETHO = "https://raw.githubusercontent.com/Ketho/BlizzardInterfaceResources/live/Resources/"
KETHO_FILES = ("GlobalAPI", "FrameXML", "Events", "WidgetAPI")
MAX_AGE = 7 * 86400
DOCS = "Blizzard_APIDocumentationGenerated/"
LONG_LINE = 3000  # longer lines are data (a table on one line), not calls – they made one add-on take six minutes


class ToolError(Exception):
    pass


# ── Reading Lua tables ───────────────────────────────────────────────────────────

TOKEN = re.compile(r'\s+|--\[\[.*?\]\]|--[^\n]*|"((?:\\.|[^"\\])*)"|\'((?:\\.|[^\'\\])*)\'|(0x[\da-fA-F]+|-?\d[\d.]*(?:e[-+]?\d+)?)'
                   r'|([A-Za-z_][\w.]*)|(.)', re.S)


def lua_tables(text):
    """{name: table} for the top-level `[local] X = { … }` of a Lua file – a forgiving reader: a name or a sum as a
    value becomes text, and a quote inside a text ("(ex. OnHyperlinkEnter, "OnHyperlinkLeave"…)" in Blizzard's own
    documentation) doesn't stop it (wowtools.lua_table gave up on 95 of the files)."""
    toks = []
    for m in TOKEN.finditer(text):
        dq, sq, num, word, other = m.groups()
        if dq is not None or sq is not None:
            toks.append(("s", dq if dq is not None else sq))
        elif num is not None:
            toks.append(("n", int(num, 16) if num.startswith("0x") else float(num) if re.search(r"[.e]", num) else int(num)))
        elif word is not None:
            toks.append(("w", word))
        elif other is not None:
            toks.append(("p", other))
    pos = 0

    def value():
        nonlocal pos
        kind, v = toks[pos]
        if (kind, v) == ("p", "{"):
            return table()
        pos += 1
        out = {"true": True, "false": False, "nil": None}.get(v, v) if kind == "w" else v
        while pos < len(toks) and toks[pos] not in (("p", ","), ("p", ";"), ("p", "}")):
            pos += 1  # the rest of a sum, or the text after a stray quote
        return out

    def table():
        nonlocal pos
        pos += 1
        items, keyed = [], {}
        while pos < len(toks) and toks[pos] != ("p", "}"):
            if toks[pos] == ("p", "["):
                key = toks[pos + 1][1]
                pos += 4  # [ key ] =
                keyed[key] = value()
            elif toks[pos][0] == "w" and pos + 1 < len(toks) and toks[pos + 1] == ("p", "="):
                key = toks[pos][1]
                pos += 2
                keyed[key] = value()
            else:
                items.append(value())
            if pos < len(toks) and toks[pos] in (("p", ","), ("p", ";")):
                pos += 1
        pos += 1
        return keyed if keyed and not items else items or keyed

    out = {}
    while pos < len(toks):
        if toks[pos][0] == "w" and pos + 2 < len(toks) and toks[pos + 1] == ("p", "=") and toks[pos + 2] == ("p", "{"):
            name = toks[pos][1]
            pos += 2
            try:
                out[name] = table()
            except IndexError:
                break
        else:
            pos += 1
    return out


def _field(f):
    """{Name, Type, Nilable, Default} → "name: Type" (+ "?" when it can be nil, = default)."""
    if not isinstance(f, dict):
        return ""
    text = f"{f.get('Name', '?')}: {f.get('Type', '?')}" + ("?" if f.get("Nilable") else "")
    if f.get("Default") is not None:
        text += f" = {str(f['Default']).lower() if isinstance(f['Default'], bool) else f['Default']}"
    return text


def _docs(f):
    d = f.get("Documentation") if isinstance(f, dict) else None
    return " ".join(str(x) for x in d) if isinstance(d, list) else str(d or "")


def _entry(f):
    return {"args": [_field(a) for a in f.get("Arguments") or []],
            "returns": [_field(r) for r in f.get("Returns") or []], "doc": _docs(f)}


# ── The sources → index.json ─────────────────────────────────────────────────────

LUA_WORDS = {"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in", "local",
             "nil", "not", "or", "repeat", "return", "then", "true", "until", "while", "self"}
CALL = re.compile(r"(?<![\w.:\"'])([A-Za-z_]\w*)\s*\(")
NS_CALL = re.compile(r"\b(C_\w+)\.(\w+)\s*\(")
METHOD = re.compile(r":\s*([A-Za-z_]\w*)\s*\(")
DEFINES = re.compile(r"\bfunction\s+[\w.]*[.:](\w+)\s*\(|\b(\w+)\s*=\s*function\b|\[\"(\w+)\"\]\s*=\s*function\b")
EVENT_REG = re.compile(r"\b(?:RegisterEvent|RegisterUnitEvent|UnregisterEvent|IsEventRegistered)\s*\(\s*[\"']([A-Z0-9_]+)")
XML_TAG = re.compile(r"<([A-Z]\w+)[\s>/]")


def build_index(archive, ketho):
    """index.json's contents from Gethe's tar.gz (bytes, read – never unpacked) and Ketho's files ({name: text})."""
    functions, events, method_docs = {}, {}, {}
    calls, ns_calls, methods, event_names, tags, defined, deprecated = set(), set(), set(), set(), set(), set(), {}
    examples = {}
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as tar:
        for member in tar:
            if not member.isfile() or not member.name.endswith((".lua", ".xml")) or member.size > 4_000_000:
                continue
            text = tar.extractfile(member).read().decode("utf-8", "replace")
            short = member.name.split("/Interface/AddOns/", 1)[-1]
            if DOCS in member.name and member.name.endswith(".lua"):
                for t in lua_tables(text).values():
                    if not isinstance(t, dict):
                        continue
                    ns = t.get("Namespace") if isinstance(t.get("Namespace"), str) else ""
                    for f in t.get("Functions") or []:
                        if isinstance(f, dict) and f.get("Name"):
                            if t.get("Type") == "ScriptObject":
                                method_docs.setdefault(f["Name"], _entry(f))
                            else:
                                functions[f"{ns}.{f['Name']}" if ns else f["Name"]] = _entry(f)
                    for e in t.get("Events") or []:
                        if isinstance(e, dict) and e.get("LiteralName"):
                            events[e["LiteralName"]] = {"payload": [_field(p) for p in e.get("Payload") or []],
                                                        "doc": _docs(e)}
                continue
            if member.name.endswith(".xml"):
                tags.update(XML_TAG.findall(text))
                continue
            code = re.sub(r"--\[\[.*?\]\]|--[^\n]*", "", text, flags=re.S)
            for line in code.splitlines():
                for name in CALL.findall(line) if len(line) < LONG_LINE else []:
                    if name not in LUA_WORDS:
                        calls.add(name)
                        if name not in examples and len(line.strip()) < 140:
                            examples[name] = f"{line.strip()}  ({short})"
            defined.update(a or b for a, b in re.findall(r"^function\s+(\w+)\s*\(|^([A-Za-z_]\w*)\s*=", code, re.M))
            if "/Deprecated" in member.name or "/Blizzard_Deprecated" in member.name:
                # GetInventorySlotInfo = C_PaperDollInfo.GetInventorySlotInfo; – an old name kept for a while, and
                # only when the game's loadDeprecationFallbacks is on
                deprecated.update(re.findall(r"^\s*(\w+)\s*=\s*(C_\w+\.\w+)\s*;?\s*$", code, re.M))
                for name, body in re.findall(r"^\s*function\s+(\w+)\s*\([^)]*\)(.*?)^\s*end\b", code, re.M | re.S):
                    new = re.search(r"\b(C_\w+\.\w+)\s*\(", body)
                    deprecated[name] = new.group(1) if new else ""
            ns_calls.update(f"{a}.{b}" for a, b in NS_CALL.findall(code))
            methods.update(METHOD.findall(code))
            methods.update(next(x for x in m if x) for m in DEFINES.findall(code))
            event_names.update(EVENT_REG.findall(code))
    k = {name: lua_tables(text) for name, text in ketho.items()}
    api = [str(x) for x in k["GlobalAPI"].get("GlobalAPI", []) + k["GlobalAPI"].get("LuaAPI", [])
           + k["FrameXML"].get("FrameXML", [])]
    # Ketho's list has Region inheriting Region (29 Oct) – in the game it is ScriptRegion (SetPoint on a texture)
    widgets = {w: {"inherits": [str(x) if x != w else "ScriptRegion" for x in v.get("inherits") or []],
                   "methods": [str(x) for x in v.get("methods") or []]}
               for w, v in (k["WidgetAPI"].get("WidgetAPI") or {}).items() if isinstance(v, dict)}
    game_events = {str(e) for group in (k["Events"].get("Events") or {}).values() if isinstance(group, list) for e in group}
    globals_ = {n for n in api if "." not in n} | defined | {n for n in functions if "." not in n}
    namespaced = {n for n in api if "." in n} | ns_calls | {n for n in functions if "." in n}
    documented = set(functions)
    return {"fetched": int(time.time()), "functions": functions, "events": events, "method_docs": method_docs,
            "widgets": widgets, "globals": sorted(globals_ - set(deprecated)), "namespaced": sorted(namespaced),
            "deprecated": deprecated,
            "examples": {n: e for n, e in examples.items() if n in globals_ and n not in documented},
            "methods": sorted(methods | {m for w in widgets.values() for m in w["methods"]} | set(method_docs)),
            "event_names": sorted(event_names | set(events) | game_events),
            "frame_types": sorted(tags | set(widgets))}


def _get(url, timeout=120):
    req = urllib.request.Request(url, headers={"User-Agent": "GOBLINCAKES Goblin AI"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def refresh():
    ketho = {name: _get(f"{KETHO}{name}.lua", 60).decode("utf-8", "replace") for name in KETHO_FILES}
    data = build_index(_get(SOURCE), ketho)
    if not data["widgets"] or len(data["globals"]) < 1000:
        raise ToolError("källorna såg inte ut som väntat (ingen lista över WoW:s funktioner)")
    DATA.mkdir(parents=True, exist_ok=True)
    tmp = INDEX.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False))
    tmp.replace(INDEX)
    return data


_index = None


def index(fetch=True):
    """The index, fetched again when older than a week (the old one is used when the net is down)."""
    global _index
    if _index is not None:
        return _index
    try:
        data = json.loads(INDEX.read_text())
    except (OSError, ValueError):
        data = None
    if fetch and (not data or time.time() - data.get("fetched", 0) > MAX_AGE):
        try:
            data = refresh()
        except Exception as e:  # noqa: BLE001 – no net: the old one, or the reason
            if not data:
                raise ToolError(f"WoW:s API kunde inte hämtas ({e})") from e
    if not data:
        raise ToolError("WoW:s API är inte hämtad (python3 wowapi.py hämta)")
    _index = data
    return data


def interface_number():
    """The game's interface number now: from the game's .build.info (12.1.5 → 120105), else the highest an
    installed add-on's .toc names – that alone gave 121000 (atrocityUI names the next patch)."""
    try:
        rows = [r.split("|") for r in (ADDONS.resolve().parents[2] / ".build.info").read_text().splitlines()]
        cols = [c.split("!")[0] for c in rows[0]]
        for r in rows[1:]:
            row = dict(zip(cols, r))
            m = re.match(r"(\d+)\.(\d+)\.(\d+)", row.get("Version", ""))
            if row.get("Product") == "wow" and m:
                return int(m.group(1)) * 10000 + int(m.group(2)) * 100 + int(m.group(3))
    except (OSError, IndexError):
        pass
    best = 0
    for toc in ADDONS.glob("*/*.toc"):
        try:
            m = re.search(r"^##\s*Interface\s*:\s*([\d,\s]+)", toc.read_text(errors="replace")[:2000], re.M)
        except OSError:
            continue
        if m:
            best = max([best] + [int(n) for n in re.findall(r"\d+", m.group(1))])
    return best


def widget_methods(data, kind):
    """A frame type's methods with everything it inherits (Frame → ScriptRegion → Object → …)."""
    out, todo, seen = set(), [kind], set()
    while todo:
        w = todo.pop()
        if w in seen or w not in data["widgets"]:
            continue
        seen.add(w)
        out.update(data["widgets"][w]["methods"])
        todo += data["widgets"][w]["inherits"]
    return out


ABSTRACT = {"FrameScriptObject", "Object", "ScriptObject", "ScriptRegion", "Region", "FontInstance", "TextureBase",
            "Animation", "ScriptRegionResizing"}  # parts others inherit – nothing CreateFrame makes


def method_owners(data, meth):
    """The frame types that have the method, themselves or by inheriting it (SetJustifyH → EditBox, FontString, …)."""
    return sorted(w for w in data["widgets"] if w not in ABSTRACT and meth in widget_methods(data, w))


# ── Looking up ──────────────────────────────────────────────────────────────────

def _function_text(name, f):
    text = f"{name}({', '.join(f['args'])})" + (f" → {', '.join(f['returns'])}" if f["returns"] else " → (inget)")
    return text + (f"\n  {f['doc']}" if f.get("doc") else "")


def _close(word, names, n=5):
    low = {x.lower(): x for x in names}
    return [low[x] for x in difflib.get_close_matches(word.lower(), list(low), n=n, cutoff=0.75)]


def by_short_name(data):
    """"getitemname" → ["C_Item.GetItemName"]: the namespaced functions by their last part."""
    out = {}
    for full in data["namespaced"]:
        out.setdefault(full.split(".")[-1].lower(), []).append(full)
    return out


def _similar(name, data, short):
    """Real functions for a made-up name: the ones with its stem in them (GetItemLevel → …ItemLevel…), then look-alikes."""
    stem = re.sub(r"^(?:Get|Set|Is|Has|Can)", "", name).lower()
    hits = sorted((f for f in data["functions"] if stem and stem in f.split(".")[-1].lower()), key=len)[:3]
    near = [x for c in _close(name, list(data["examples"]) + list(short), n=3) for x in (short.get(c) or [c])]
    return list(dict.fromkeys(hits + near))[:4]


def lookup(query):
    """Text for the AI: what the API says about the query (a function, event, frame type, namespace or a word)."""
    data = index()
    q = " ".join(str(query).split()).strip("`()\"' ")
    if not q:
        return (f"WoW:s API (hämtad {time.strftime('%Y-%m-%d', time.localtime(data['fetched']))} för spelet just nu): "
                f"{len(data['globals']) + len(data['namespaced'])} funktioner, {len(data['event_names'])} händelser, "
                f"{len(data['widgets'])} ramtyper. Interface-numret nu: {interface_number() or 'okänt'}. Slå upp ett "
                "namn, t.ex. `C_Item.GetItemInfo`, `BAG_UPDATE` eller `Frame`.")
    m = re.match(r"(?:kolla|kontrollera|check)\s+(.+)", q, re.I)
    if m:
        return check(m.group(1))
    out = []
    short = by_short_name(data)
    functions = data["functions"]
    known = set(data["globals"]) | set(data["namespaced"])
    exact = [n for n in known if n.lower() == q.lower()] or short.get(q.split(".")[-1].lower(), [])
    for name in sorted(exact)[:4]:
        note = "" if name.lower() == q.lower() else f" (inte `{q}` – den heter så här)"
        if name in functions:
            out.append(_function_text(name, functions[name]) + note)
        elif name in data["examples"]:
            out.append(f"{name} finns (inte dokumenterad – så här anropar Blizzard den):\n  {data['examples'][name]}{note}")
        else:
            out.append(f"{name}() finns i spelet (inte dokumenterad – sök på warcraft.wiki.gg för argumenten){note}")
    if q in data.get("deprecated", {}):
        new = data["deprecated"][q]
        out.append(f"{q} är ett gammalt namn (bara när loadDeprecationFallbacks är på)" + (f" – det nya är {new}." if new else "."))
    if q.upper() in data["events"]:
        e = data["events"][q.upper()]
        out.append(f"Händelsen {q.upper()}: " + (", ".join(e["payload"]) or "inga värden") + (f"\n  {e['doc']}" if e["doc"] else ""))
    elif q.upper() in data["event_names"]:
        out.append(f"Händelsen {q.upper()} finns (inte dokumenterad).")
    widget = next((w for w in data["widgets"] if w.lower() == q.lower()), None)
    if widget:
        names = sorted(widget_methods(data, widget))
        out.append(f"Ramtypen {widget} ärver {', '.join(data['widgets'][widget]['inherits']) or 'inget'} – "
                   f"{len(names)} metoder: " + ", ".join(names))
    meth = next((w for w in data["methods"] if w.lower() == q.lstrip(":").lower()), None)
    owners = method_owners(data, meth) if meth else []
    if owners:
        f = data["method_docs"].get(meth)
        out.append(f"Metoden :{meth}" + (f"({', '.join(f['args'])})" + (f" → {', '.join(f['returns'])}" if f["returns"] else "")
                                       if f else "()") + f" – finns på {', '.join(owners[:8])}" + (" m.fl." if len(owners) > 8 else "")
                   + (f"\n  {f['doc']}" if f and f.get("doc") else ""))
    if q.startswith("C_") and "." not in q:
        names = sorted(n for n in data["namespaced"] if n.startswith(q + "."))
        if names:
            out.append(f"{q} har {len(names)} funktioner: " + ", ".join(n.split(".")[1] for n in names))
    if out:
        return "\n\n".join(out)
    words = q.lower()
    found = (sorted((n for n in known if words in n.lower()), key=len)[:15]
             + sorted(e for e in data["event_names"] if words in e.lower())[:5])
    if found:
        return f"Inget som heter exakt \"{q}\". Namn som innehåller det: " + ", ".join(found)
    near = _similar(q.split(".")[-1], data, short)
    return (f"\"{q}\" finns inte i WoW (varken i spelets lista över funktioner eller i Blizzards kod) – hitta inte på den."
            + (f" Menade du: {', '.join(near)}?" if near else " Sök med ett kortare ord, t.ex. `ItemLevel`."))


# ── Checking an add-on ────────────────────────────────────────────────────────────

TOC_KEYS = ["Interface", "Title", "Notes", "Author", "Version", "SavedVariables", "SavedVariablesPerCharacter",
            "Dependencies", "RequiredDeps", "Dep", "OptionalDeps", "LoadOnDemand", "LoadWith", "LoadManagers",
            "DefaultState", "IconTexture", "IconAtlas", "AddonCompartmentFunc", "AddonCompartmentFuncOnEnter",
            "AddonCompartmentFuncOnLeave", "Category", "Group", "AllowLoadGameType", "OnlyBetaAndPTR", "Secure"]
FLAVORS = ("Mainline", "Standard", "Classic", "Vanilla", "TBC", "BCC", "Wrath", "WOTLKC", "Cata", "Mists", "Wotlk")


def _defined_names(code):
    """Names an add-on gives a value itself: locals, functions, parameters, loop variables, globals it sets."""
    names = set()
    for m in re.finditer(r"\blocal\s+function\s+(\w+)\s*\(([^)]*)\)|\blocal\s+([\w\s,]+?)(?:=|\n|$)"
                         r"|\bfunction\s+([\w.:]+)\s*\(([^)]*)\)|\bfunction\s*\(([^)]*)\)|\bfor\s+([\w\s,]+?)\s+(?:in|=)"
                         r"|^\s*([A-Za-z_]\w*)\s*=", code, re.M):
        for i, g in enumerate(m.groups(), 1):
            if g:
                names.update(re.findall(r"[A-Za-z_]\w*", re.split(r"[.:]", g)[0] if i == 4 else g))
    return names


def _guarded(name, code):
    """The code only calls it after checking that it exists (`if X then`, `X and X()`, `local f = X or Y`) – a
    fallback for another game version (KeystoneDisplay's GetContainerItemLink), not a fault."""
    n = re.escape(name)
    g = rf"(?:_G\s*\.\s*{n}\b|_G\s*\[\s*[\"']{n}[\"']\s*\]|{n}\b)"  # if X / if _G.X / if _G["X"]
    return bool(re.search(rf"\b(?:if|elseif|and|or|not)\s+(?:not\s+)?{g}(?!\s*\()|(?<![.:\w]){n}\s+(?:and|or|then)\b"
                          rf"|=\s*{n}\s*(?:$|[,;)]|\bor\b|\band\b)|\btype\s*\(\s*{n}\s*\)", code, re.M))


_others = None


def _installed_definitions():
    """(globals, methods) every installed add-on defines – libraries, the dependencies an add-on calls. Kept apart:
    Simulationcraft's own :GetItemName() method hid that the gear add-on's global GetItemName() doesn't exist."""
    global _others
    if _others is None:
        names, methods = set(), set()
        for f in ADDONS.glob("*/**/*.lua"):
            try:
                if f.stat().st_size < 2_000_000:
                    code = f.read_text(errors="replace")
                    methods.update(next(x for x in m if x) for m in DEFINES.findall(code))
                    names.update(re.findall(r"^\s*function\s+(\w+)\s*\(", code, re.M))
                    names.update(re.findall(r"^([A-Za-z_]\w*)\s*=", code, re.M))  # not indented: a table's key isn't global
                    names.update(a or b for a, b in re.findall(r"\b_G\s*(?:\[\s*[\"'](\w+)[\"']\s*\]|\.(\w+))\s*=", code))
            except OSError:
                continue
        _others = names, methods
    return _others


def _toc_findings(folder, files):
    sure, maybe = [], []
    tocs = [f for f in files if f.suffix.lower() == ".toc" and f.parent == folder]
    name = folder.name
    main = [t for t in tocs if re.fullmatch(re.escape(name) + r"(?:[-_](?:" + "|".join(FLAVORS) + r"))?", t.stem, re.I)]
    if not tocs:
        sure.append(f"Ingen .toc-fil i {folder} – WoW visar inte tillägget utan en `{name}.toc`.")
    elif not main and all(re.fullmatch(re.escape(name) + r"[-_]\w+", t.stem, re.I) for t in tocs):
        maybe.append(f"{', '.join(t.name for t in tocs)}: bara för en annan WoW-version ({name}.toc saknas) – laddas "
                     "inte i Retail.")
        return sure, maybe
    elif not main:
        sure.append(f".toc-filen heter {', '.join(t.name for t in tocs)} men mappen heter {name} – WoW kräver samma namn: "
                    f"`{name}.toc` (annars syns tillägget inte alls i listan). Rätta med `mv`.")
    current = interface_number()
    for toc in main or tocs:
        try:
            lines = toc.read_text(errors="replace").splitlines()
        except OSError:
            continue
        keys, listed = {}, set()
        for n, line in enumerate(lines, 1):
            s = line.strip().lstrip("\ufeff")
            if s.startswith("##"):
                m = re.match(r"##\s*([\w-]+)\s*:\s*(.*)", s)
                if not m:
                    near = _close(re.sub(r"\W", "", s[2:]), TOC_KEYS, n=1) or _close(s[2:].strip()[:9], TOC_KEYS, n=1)
                    sure.append(f"{toc.name} rad {n}: `{s}` saknar kolon och värde – en rad i huvudet ser ut som "
                                f"`## Nyckel: värde`" + (f" (menade du `## {near[0]}: …`?)" if near else "") + ".")
                    continue
                key, value = m.group(1), m.group(2).strip()
                keys[key.lower()] = (n, value)
                if not key.startswith("X-") and key not in TOC_KEYS and not re.match(r"(?:Title|Notes)-\w+|Interface-\w+", key):
                    near = _close(key, TOC_KEYS, n=1)
                    maybe.append(f"{toc.name} rad {n}: okänd rad `## {key}`" + (f" (menade du `## {near[0]}`?)" if near else ""))
            elif s and not s.startswith("#"):
                path = re.sub(r"(?:\s*\[[^\]]*\])+\s*$", "", s).replace("\\", "/")  # "File.lua [AllowLoadGameType …]"
                if "[" in path:  # a placeholder ([TextLocale], [Family]) the game fills in
                    continue
                listed.add((folder / path).resolve())
                if not (folder / path).exists() and not _exists_any_case(folder, path):  # WoW runs in Wine: case doesn't matter
                    sure.append(f"{toc.name} rad {n}: filen `{path}` finns inte i mappen.")
        if "interface" not in keys:
            sure.append(f"{toc.name}: raden `## Interface: {current or '120000'}` saknas – utan den räknas tillägget som "
                        "för gammalt och laddas inte (\"Incompatible\"/\"Out of date\").")
        else:
            n, value = keys["interface"]
            numbers = [int(x) for x in re.findall(r"\d+", value)]
            if not numbers:
                sure.append(f"{toc.name} rad {n}: `## Interface: {value}` – ska vara ett nummer, nu {current or '120000'}.")
            elif current and max(numbers) < current and max(numbers) >= 100000:
                maybe.append(f"{toc.name} rad {n}: Interface {max(numbers)} är äldre än spelets {current} – tillägget "
                             "visas som inaktuellt (laddas ändå om \"Ladda inaktuella tillägg\" är på).")
        for f in files:
            if f.suffix.lower() == ".lua" and f.parent == folder and f.resolve() not in listed and len(tocs) == 1:
                maybe.append(f"{f.name} står inte i {toc.name} – den laddas aldrig (om ingen .xml-fil tar med den).")
    return sure, maybe


def _exists_any_case(folder, path):
    here = folder
    for part in [p for p in path.split("/") if p and p != "."]:
        if part == "..":
            here = here.parent
            continue
        match = next((c for c in here.iterdir() if c.name.lower() == part.lower()), None) if here.is_dir() else None
        if not match:
            return False
        here = match
    return True


def lua_error(path):
    """(line, message) when WoW couldn't load the file at all, else None. LuaJIT reads Lua 5.1 as WoW does
    (in the image); gemma4's sed left a bare `content.scrollFrame` on a line and the check said nothing (30 Oct).
    LuaJIT's "invalid escape sequence" is left out: WoW takes a backslash before any letter (MRT – the only kind among 2876 installed files)."""
    try:
        r = subprocess.run(["luajit", "-b", str(path), "/dev/null"], capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.TimeoutExpired):
        return None
    m = re.search(r":(\d+): (.+)", r.stderr) if r.returncode else None
    if not m or "invalid escape sequence" in m.group(2):
        return None
    return int(m.group(1)), m.group(2).strip()[:200]


def _call_args(line, end):
    """The arguments of the call whose "(" is just before `end` – a list of texts, or None when it can't be told."""
    depth, start = 0, end
    for i in range(end, len(line)):
        c = line[i]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            if depth == 0:
                inner = line[start:i]
                if "..." in inner or "function" in inner:
                    return None
                parts, d, cur = [], 0, ""
                for ch in inner:
                    if ch in "([{":
                        d += 1
                    elif ch in ")]}":
                        d -= 1
                    if ch == "," and d == 0:
                        parts.append(cur)
                        cur = ""
                    else:
                        cur += ch
                parts.append(cur)
                return [x.strip() for x in parts if x.strip()], i
            depth -= 1
    return None


SIMPLE = {"number", "bool", "boolean", "string", "cstring", "luaIndex", "fileID", "BigUInteger", "WOWGUID", "time_t"}


def check(target):
    """An add-on's folder (or one of its files) against WoW's API: plain text, sure faults first."""
    data = index()
    folder = Path(str(target).strip().strip("`\"'")).expanduser()
    if folder.is_file():
        folder = folder.parent
    if not folder.is_dir():
        raise ToolError(f"mappen {target} finns inte")
    files = sorted(f for f in folder.rglob("*") if f.is_file() and ".git" not in f.parts)[:600]
    sure, maybe = _toc_findings(folder, files)
    known_calls = set(data["globals"])
    known_ns = set(data["namespaced"])
    namespaces = {n.split(".")[0] for n in known_ns}
    known_methods = set(data["methods"])
    frame_types = {t.lower() for t in data["frame_types"]}  # CreateFrame("FRAME") works too
    widget_case = {w.lower(): w for w in data["widgets"]}
    short = by_short_name(data)
    lua = [(f, f.read_text(errors="replace")) for f in files if f.suffix.lower() == ".lua" and f.stat().st_size < 1_500_000]
    code_all = "\n".join(re.sub(r"--\[\[.*?\]\]|--[^\n]*", "", t, flags=re.S) for _, t in lua)
    own = _defined_names(code_all) | {next(x for x in m if x) for m in DEFINES.findall(code_all)}
    own |= set(re.findall(r"[\w\]]\.(\w+)\s*=(?!=)", code_all))  # editBox.RefreshPlaceholder = refreshPlaceholder (gear-planner)
    slash = set(re.findall(r"\bSLASH_(\w+)\s*=", code_all))  # WoW looks up "SLASH_" .. key .. 1, 2, … (SlashCommandsRegistry.lua)
    # Code for several game versions (SimpleQuestRemover: `if IS_RETAIL then … else <Classic's functions>`): which
    # branch runs can't be read here – a missing function is then a "kanske"
    # Other add-ons it uses when they are there (KeystoneLoot → LiteBag_RegisterHook): not installed = unknown names
    deps = set()
    for toc in (f for f in files if f.suffix.lower() == ".toc"):
        try:
            for value in re.findall(r"^##\s*(?:Optional|Required)?Dep\w*\s*:\s*(.+)$", toc.read_text(errors="replace"), re.M):
                deps.update(d.strip().lower() for d in value.split(",") if d.strip())
        except OSError:
            pass
    deps |= {d.lower() for _, t in lua for d in re.findall(r"(?:IsAddOnLoaded|ContinueOnAddOnLoaded)\s*\(\s*[\"']([\w-]+)", t)}
    flavors = bool(re.search(r"WOW_PROJECT_(?:ID|MAINLINE|CLASSIC)|\bis_?(?:retail|classic|era|mainline|vanilla|wrath|cata|mists|"
                             r"forever|sod)\b|GetBuildInfo\s*\(|LE_EXPANSION_LEVEL_CURRENT", code_all, re.I))
    branch = " (tillägget har kod för flera WoW-versioner – kan vara den andra versionens del)"
    other_game = re.compile(r"classic|forever|vanilla|wrath|wotlk|cata|mists|tbc|bcc|\bera\b|_sod|season", re.I)
    others = None
    reported = set()
    keep = re.compile(r"(?:CreateFrame|RegisterEvent|RegisterUnitEvent)\s*\(\s*$|_G\s*\[\s*$|SlashCmdList\s*\[\s*$")

    def once(key, bucket, text):
        if key not in reported and len(bucket) < 20:
            reported.add(key)
            bucket.append(text)

    def installed():
        nonlocal others
        if others is None:
            others = _installed_definitions()
        return others

    for f, _ in lua:
        err = lua_error(f)
        if err:
            once(("lua", str(f)), sure, f"{f.relative_to(folder)} rad {err[0]}: Lua-fel – {err[1]}. WoW laddar inte filen "
                 "alls (inget i den körs). Felet sitter på raden eller strax före – läs raderna runt den.")
    for f, text in lua:
        rel = f.relative_to(folder)
        other = flavors or bool(other_game.search(str(rel)))  # EllesmereUIQoL_ForeverStats.lua: WoW Forever's functions
        sure_ = maybe if other else sure
        note = branch if flavors else " (filen är för en annan WoW-version)" if other else ""
        code = re.sub(r"--\[\[.*?\]\]", lambda m: "\n" * m.group().count("\n"), text, flags=re.S)
        # A variable that gets something else too (a parameter, another value) can't be told by its CreateFrame
        changed = set(re.findall(r"\b([\w.]+)\s*=\s*(?=\S)(?!CreateFrame\b|[\w.]+:Create(?:FontString|Texture)\b|=)", code))
        changed |= {x for params in re.findall(r"\bfunction\b[^(\n]*\(([^)]*)\)", code) for x in re.findall(r"\w+", params)}
        types = {}
        for n, raw in enumerate(code.splitlines(), 1):
            if len(raw) > LONG_LINE or len(sure) >= 20 and len(maybe) >= 20:
                continue
            # Texts are blanked ("…" → "") so a word in one isn't read as a call – except the ones that name things –
            # and comments go, in one pass: a "--" inside a text ("… -- it is the same …") isn't a comment
            line = re.sub(r"\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'|--.*",
                          lambda m: "" if m.group().startswith("--") else m.group()
                          if keep.search(raw[max(0, m.start() - 40):m.start()]) else '""', raw)
            for m in re.finditer(r"(?:local\s+)?([\w.]+)\s*=\s*CreateFrame\s*\(\s*\"(\w+)\"\s*(?:,([^)]*))?\)", line):
                kind = widget_case.get(m.group(2).lower())  # the game's own types – not Lua-made ones (DropdownButton)
                if kind and (m.group(3) or "").count(",") < 2 and m.group(1) not in changed:  # no template either
                    types[m.group(1)] = kind
            for m in re.finditer(r"(?:local\s+)?([\w.]+)\s*=\s*[\w.]+:Create(FontString|Texture)\s*\(", line):
                if m.group(1) not in changed:
                    types[m.group(1)] = m.group(2)
            for var in [v for v in types if re.search(r"\(\s*" + re.escape(v) + r"\s*[,)]", line) and "CreateFrame" not in line]:
                del types[var]  # FlatBackdrop(panel): it may have got the backdrop's methods there
            for m in re.finditer(r"\bCreateFrame\s*\(\s*\"(\w+)\"", line):
                if m.group(1).lower() not in frame_types:
                    near = _close(m.group(1), data["frame_types"], n=2)
                    once(("type", m.group(1)), sure, f"{rel} rad {n}: CreateFrame(\"{m.group(1)}\") – ramtypen {m.group(1)} "
                         "finns inte (laddningsfel – resten av filen körs inte)" + (f"; menade du {' eller '.join(near)}?" if near else "."))
            for name in CALL.findall(line) + [a or b for a, b in re.findall(r"\b_G\s*(?:\[\s*[\"'](\w+)[\"']\s*\]|\.(\w+))\s*\(", line)]:
                if (name in LUA_WORDS or name in own or name in known_calls or ("call", name) in reported
                        or re.search(r"\bfunction\s+" + re.escape(name) + r"\s*\(", line)):
                    continue
                if name in data.get("deprecated", {}):
                    if not _guarded(name, code):
                        new = data["deprecated"][name]
                        once(("call", name), maybe, f"{rel} rad {n}: {name}() är ett gammalt namn – finns bara när spelets "
                             "inställning loadDeprecationFallbacks är på, och tas bort" + (f"; det nya är {new}()." if new else "."))
                    continue
                if name in installed()[0] or _guarded(name, code) or any(name.lower().startswith(d) for d in deps):
                    continue
                if name.lower() in short:
                    once(("call", name), sure_, f"{rel} rad {n}: {name}() finns inte som vanlig funktion. En ANNAN "
                         f"funktion med samma namn finns: {' / '.join(short[name.lower()])} – den kan ta och ge tillbaka "
                         "helt andra saker. Slå upp den med wowapi och se vad den vill ha och ger tillbaka innan du byter; "
                         f"passar den inte, slå upp vad som gör det tillägget behöver.{note}")
                elif name.startswith("_"):  # _G._EQT_SetSuppressed(): another add-on's, behind its own check
                    once(("call", name), maybe, f"{rel} rad {n}: {name}() finns inte i WoW eller i tillägget – kanske ett "
                         "annat tilläggs funktion (fungerar bara när det är installerat).")
                else:
                    near = _similar(name, data, short)
                    once(("call", name), sure_, f"{rel} rad {n}: {name}() finns inte i WoW eller i tillägget"
                         + (f" – menade du {', '.join(near)}?" if near else " – påhittad? Slå upp vad som ska användas med wowapi.")
                         + note)
            for m in NS_CALL.finditer(line):
                full, doc = f"{m.group(1)}.{m.group(2)}", data["functions"].get(f"{m.group(1)}.{m.group(2)}")
                got = _call_args(line, m.end()) if doc else None
                if not got:
                    continue
                args, close = got
                need = [a for a in doc["args"] if not re.search(r"\?$|\?\s*=|=", a)]
                if len(args) < len(need):
                    once(("args", full), sure_, f"{rel} rad {n}: {full}() vill ha {', '.join(doc['args'])} – här får den "
                         f"{len(args)} (\"{', '.join(args) or 'inget'}\"). Slå upp den med wowapi.")
                for arg, want in zip(args, doc["args"]):
                    kind = want.split(":")[-1].strip().rstrip("?")
                    if kind.endswith("Location") and re.fullmatch(r"(?i)\d+|[\w.]*(?:_id|id)", arg):
                        once(("loc", full), maybe, f"{rel} rad {n}: {full}() vill ha en {kind} – inte ett id/nummer "
                             f"(\"{arg}\"). En {kind} skapas med t.ex. {kind}:CreateFromEquipmentSlot(plats); "
                             "slå upp med wowapi.")
                after = line[close + 1:].lstrip()
                first = (doc["returns"] or [""])[0].split(":")[-1].strip().rstrip("?")
                if after[:1] in (".", "[") and not after.startswith("..") and first in SIMPLE:
                    once(("ret", full), sure_, f"{rel} rad {n}: {full}() ger tillbaka {', '.join(doc['returns'])} – inte "
                         f"en tabell, så {after[:20].split()[0]} efter anropet kraschar. Ta värdet direkt: "
                         f"local a, b = {full}(…).")
            for ns, fn in NS_CALL.findall(line):
                full = f"{ns}.{fn}"
                if full in known_ns or ns in own or ("ns", full) in reported or _guarded(full, code) or _guarded(ns, code):
                    continue
                names = [x.split(".")[1] for x in known_ns if x.startswith(ns + ".")]
                near = _close(fn, names, n=3)
                once(("ns", full), sure_, f"{rel} rad {n}: {full}() finns inte"
                     + (f" – {ns} har {', '.join(ns + '.' + x for x in near)}" if near else
                        f" ({ns} finns inte heller)" if ns not in namespaces else "") + note)
            for m in re.finditer(r"([\w.]+)\s*:\s*([A-Za-z_]\w*)\s*\(", line):
                var, meth = m.group(1), m.group(2)
                if meth in own or ("meth", meth) in reported:
                    continue
                kind = types.get(var)
                if kind and not re.search(re.escape(var) + r"\s*[.:]\s*" + re.escape(meth) + r"\s*=|Mixin\s*\(\s*" + re.escape(var), code):
                    if meth not in widget_methods(data, kind):
                        has = method_owners(data, meth)
                        once(("meth", meth), sure if has or meth not in known_methods else maybe,
                             f"{rel} rad {n}: {var} är en {kind} – den har ingen :{meth}()"
                             + (f" (den finns på {', '.join(has[:5])}{' m.fl.' if len(has) > 5 else ''})" if has else " (finns inte alls)" if meth not in known_methods else ""))
                        continue
                if meth not in known_methods and meth not in installed()[1]:
                    near = _close(meth, known_methods, n=2)
                    once(("meth", meth), maybe, f"{rel} rad {n}: :{meth}() finns inte i WoW"
                         + (f" – menade du :{' eller :'.join(near)}?" if near else "") + " (kanske en egen metod på en tabell)")
            for ev in EVENT_REG.findall(line):
                if ev not in data["event_names"]:
                    near = _close(ev, data["event_names"], n=2)
                    once(("ev", ev), sure_, f"{rel} rad {n}: händelsen {ev} finns inte"
                         + (f" – menade du {' eller '.join(near)}?" if near else ".") + note)
            for a, b in re.findall(r"SlashCmdList\s*(?:\[\s*[\"'](\w+)[\"']\s*\]|\.(\w+))\s*=", line):
                key = a or b
                if not any(re.fullmatch(re.escape(key) + r"\d+", x) for x in slash):
                    near = ([re.sub(r"\d+$", "", x) for x in sorted(slash) if x.startswith(key)]
                            or [re.sub(r"\d+$", "", x) for x in sorted(slash) if key.startswith(re.sub(r"\d+$", "", x))])
                    once(("slash", key), sure, f"{rel} rad {n}: SlashCmdList[\"{key}\"] – nyckeln ska vara namnet i "
                         f"SLASH_<namn>1, och det finns ingen SLASH_{key}<nummer>, så kommandot når aldrig funktionen"
                         + (f" (SLASH_{near[0]}1 finns – nyckeln ska vara \"{near[0]}\")" if near and near[0] != key else "") + ".")
    number = interface_number()
    head = f"Kontroll av {folder} mot WoW (spelet just nu" + (f", interface {number})" if number else ")")
    if not sure and not maybe:
        return head + ": inga fel hittade i .toc eller anropen. (Kontrollen ser bara namn som inte finns – inte logiska fel.)"
    return (head + ":\n" + ("\nFEL:\n" + "\n".join("- " + s for s in sure) if sure else "")
            + ("\n\nKANSKE (kontrollen kan inte vara säker):\n" + "\n".join("- " + s for s in maybe) if maybe else "")
            + "\n\nRätta bara raderna ovan (`sed -i` på raden, `mv` för ett namn) – slå upp rätt namn med wowapi först.")


def addon_folder(path):
    """The add-on a file belongs to: the nearest folder with a .toc in it (or the file's folder), else None."""
    p = Path(str(path)).expanduser()
    if p.suffix.lower() not in (".lua", ".toc", ".xml"):
        return None
    for folder in [p.parent, *p.parent.parents][:4]:
        if folder == HOME or folder.name == "AddOns":
            break
        if any(folder.glob("*.toc")):
            return folder
    return p.parent if p.parent.is_dir() else None


# ── The user's own add-ons ───────────────────────────────────────────────────────

def own_addons():
    """The add-on folders that are the user's own: the list in OWN_LIST, else the git clones in AddOns."""
    try:
        return {l.split("=")[0].strip() for l in OWN_LIST.read_text().splitlines() if l.strip() and not l.startswith("#")}
    except OSError:
        pass
    return {d.name for d in ADDONS.glob("*") if (d / ".git").exists()}


def own_addon(path):
    """Whether a path in WoW's AddOns belongs to one of the user's own add-ons (a link into one counts:
    CooldownVoice_Hunter → CooldownVoice/Modules/…). Paths outside AddOns are not add-ons: True."""
    parts = Path(str(path)).expanduser().parts
    if "AddOns" not in parts or parts.index("AddOns") == len(parts) - 1:
        return True
    i = parts.index("AddOns")
    mine = own_addons()
    if parts[i + 1] in mine:
        return True
    try:
        real = str(Path(*parts[:i + 2]).resolve())
    except OSError:
        return False
    return any(real.startswith(str((ADDONS / m).resolve()) + "/") for m in mine)


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        print("wowapi.py hämta | slå upp <namn> | kolla <mapp>")
        return 0
    try:
        if argv[0] in ("hämta", "hamta", "fetch"):
            data = refresh()
            print(f"Hämtad: {len(data['globals']) + len(data['namespaced'])} funktioner, "
                  f"{len(data['event_names'])} händelser → {INDEX}")
        elif argv[0] in ("kolla", "check"):
            print(check(" ".join(argv[1:])))
        else:
            print(lookup(" ".join(argv[2:] if argv[:2] == ["slå", "upp"] else argv)))
    except ToolError as e:
        print(f"Fel: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
