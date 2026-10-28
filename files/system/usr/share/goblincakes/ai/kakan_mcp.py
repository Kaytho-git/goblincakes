"""Kakan's own tools as an MCP server (point 8 part 3 of Kakan's plan, 28 Oct): Claude Code – and Claude Haiku in
point 17 – can use WoW Stats, Warcraft Logs, BugSack's errors, CS2, the sport tables, the map of GOBLINCAKES, the
computer's errors, the read-only file tools, Kakan's own reports (rapporter, point 14 – toclaude.py) and her
known solutions and lessons (losningar, point 12 – solutions.py). Only tools that read: nothing on the desktop (music, windows,
reminders), no web search (Claude has its own) and not Kakan's own MCP servers.

    python3 kakan_mcp.py               the server (stdio, one JSON-RPC message per line)
    python3 kakan_mcp.py lista         the tools it hands out
    python3 kakan_mcp.py claude        adds it to Claude Code (claude mcp add --scope user kakan …)

Only the standard library; the tools are goblinai.tools_for's, so they work the same as in the window."""

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
PROTOCOL = "2025-06-18"
SHARED = ("goblincakes", "systemfel", "leta", "wowstats", "warcraftlogs", "wowfel", "cs2", "sport", "lagg")
ANSWER_MAX = 60000  # characters – Claude reads more than the local AI; a raid night from WCL fits
INSTRUCTIONS = ("Verktyg från GOBLINCAKES lokala AI (Kakan) på användarens dator. Svaren är på svenska. "
                "warcraftlogs = vad som hände i en pull/raidkväll, wowstats = användarens egna parses över tid, "
                "wowfel = BugSacks fel, cs2 = egna CS2-siffror ur demos, lagg = lagmätningen kring användarens "
                "Meta+Shift+L (\"laggar nu\") under spel, goblincakes = kartan över systemet (läs "
                "den först när en del av GOBLINCAKES strular), systemfel = datorns loggade fel (och vad kontrollen efter senaste uppdateringen hittade), hitta_filer/las_fil/"
                "visa_mapp/sok_i_filer/logg/program/tjanst = läsa i datorn (nycklar och lösenord visas inte), "
                "rapporter = det Kakan inte kunde lösa (Skicka till Claude i Goblin AI), losningar = hennes kända "
                "lösningar (problem som lösts på datorn) och lärdomar.")


def goblinai():
    import goblinai as g  # noqa: PLC0415 – slow-ish, only once the client asks
    return g


def shared_tools():
    """{word: tool} – Kakan's tools that only read and need no local AI."""
    g = goblinai()
    tools = g.tools_for(g.load_keys(), {"search": False}, [])
    tools = {w: t for w, t in tools.items() if w in SHARED}
    import toclaude  # noqa: PLC0415
    tools["rapporter"] = g.tool("Läser Kakans rapporter", "", "", lambda q: (toclaude.read(q), []), "rapporter",
                                "Kakans rapporter till Claude: det hon inte kunde lösa själv – frågan, hennes svar och "
                                "steg, vad verktygen visade och kommandona hon körde med utdata (Skicka till Claude i "
                                "Goblin AI). Tomt = listan och den senaste i sin helhet.",
                                "Tomt, eller rapportens namn (eller en del av det)")
    import solutions  # noqa: PLC0415
    tools["losningar"] = g.tool("Läser Kakans kända lösningar", "", "", lambda q: (solutions.read(q), []), "losningar",
                                "Kakans kända lösningar – problem som lösts på den här datorn (tecken → orsak → "
                                "lösning, från Kakan eller Claude, bekräftade eller inte) – och hennes lärdomar per "
                                "kategori. Kolla här först när ett fel kan ha hänt förut. Tomt = alla lösningar + "
                                "antal lärdomar; \"lärdomar [kategori]\" = lärdomarna; annars ord ur felet.",
                                "Tomt, \"lärdomar [kategori]\", eller ord ur felet (t.ex. discord startar inte)")
    return tools


def mcp_list(tools):
    """The tools in MCP's form; a tool without its own fields takes `fraga`."""
    out = []
    for f in goblinai().tool_schemas(tools):
        fn = f["function"]
        out.append({"name": fn["name"], "description": fn["description"], "inputSchema": fn["parameters"],
                    "annotations": {"readOnlyHint": True, "openWorldHint": fn["name"] in ("warcraftlogs", "sport")}})
    return out


def run(tools, name, args):
    """One call → the tool's text, the same way the window runs a model's tool call."""
    g = goblinai()
    block = g.tool_call_block({"function": {"name": name, "arguments": args or {}}}, tools)
    if not block:
        raise ValueError(f"okänt verktyg: {name}")
    word, _, query = block[3:-4].partition("\n")
    text, _ = tools[word]["run"](query.strip())
    text = (text or "").strip() or "(tomt svar)"
    return text[:ANSWER_MAX] + ("\n[… avkortat]" if len(text) > ANSWER_MAX else "")


def serve():
    # The protocol gets its own copy of stdout; anything the tools (or their programs) print goes to stderr
    out = os.fdopen(os.dup(1), "w", buffering=1)
    os.dup2(2, 1)
    sys.stdout = sys.stderr
    tools = None

    def reply(msg_id, result=None, error=None):
        msg = {"jsonrpc": "2.0", "id": msg_id}
        msg.update({"error": error} if error else {"result": result})
        out.write(json.dumps(msg, ensure_ascii=False) + "\n")

    for line in sys.stdin:
        try:
            msg = json.loads(line)
        except ValueError:
            continue
        if not isinstance(msg, dict) or "id" not in msg:
            continue  # notifications (initialized, cancelled)
        method, params, msg_id = msg.get("method"), msg.get("params") or {}, msg["id"]
        if method == "initialize":
            asked = params.get("protocolVersion")
            reply(msg_id, {"protocolVersion": asked if asked in (PROTOCOL, "2025-03-26", "2024-11-05") else PROTOCOL,
                           "capabilities": {"tools": {}},
                           "serverInfo": {"name": "goblincakes-kakan", "title": "Kakan (GOBLINCAKES)", "version": "1"},
                           "instructions": INSTRUCTIONS})
        elif method == "ping":
            reply(msg_id, {})
        elif method == "tools/list":
            tools = shared_tools()  # anew each time: WCL or CS2 may have been set up since
            reply(msg_id, {"tools": mcp_list(tools)})
        elif method == "tools/call":
            tools = tools or shared_tools()
            try:
                text = run(tools, params.get("name", ""), params.get("arguments"))
                reply(msg_id, {"content": [{"type": "text", "text": text}]})
            except Exception as e:  # noqa: BLE001 – the tool's error goes back to the model, the server stays up
                reply(msg_id, {"content": [{"type": "text", "text": f"Det gick inte: {e}"}], "isError": True})
        else:
            reply(msg_id, error={"code": -32601, "message": f"okänd metod: {method}"})


def add_to_claude():
    claude = shutil.which("claude") or str(Path.home() / ".local/bin/claude")
    if not Path(claude).exists():
        print("Claude Code hittades inte.", file=sys.stderr)
        return 1
    image = Path("/usr/share/goblincakes/ai/kakan_mcp.py")  # the image's copy, not the repo's, once it's there
    subprocess.run([claude, "mcp", "remove", "--scope", "user", "kakan"], capture_output=True)
    return subprocess.run([claude, "mcp", "add", "--scope", "user", "kakan", "--",
                           "python3", str(image if image.exists() else Path(__file__).resolve())]).returncode


def main(argv):
    if not argv:
        serve()
        return 0
    if argv == ["lista"]:
        for t in mcp_list(shared_tools()):
            print(f"{t['name']}: {t['description'][:90]}…")
        return 0
    if argv == ["claude"]:
        return add_to_claude()
    print(__doc__.split("\n\n")[1])
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
