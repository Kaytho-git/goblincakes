#!/usr/bin/env python3
"""Provet av Kakans kontroller (25 nov): kända frågor och svar genom Goblin AI:s kontroller, med en låtsasmodell.

Kvällens fel 24 nov var alla att en kontroll slog till på ett rätt svar (klart-kontrollen på 6 av 6 statusfrågor,
"påstod att hon läst" efter kunskapsminnet, Obs-raden på ett citerat tal). Varje fall här säger vad som SKA hända –
hur många gånger modellen frågas (1 = inget omtag) och vilka kontroller som slår till. Ny kontroll eller ändrad regel:
lägg till ett fall för det rätta svaret den inte får fånga, och ett för det felaktiga den ska fånga.

Körs av tools/check.py (även i bygget) i en tom hemmapp: inget från användarens minne, journal eller nät.
`python3 tools/kontroll-prov.py` – 0 = allt som väntat, annars vilka fall och vad som hände.
"""
import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
AI = ROOT / "files/system/usr/share/goblincakes/ai"

if os.environ.get("KONTROLLPROV_HOME") != os.environ.get("HOME"):
    # Own empty home first: Path.home() is read when the modules load
    home = tempfile.mkdtemp(prefix="kontrollprov-")
    os.execve(sys.executable, [sys.executable, __file__, *sys.argv[1:]],
              {**os.environ, "HOME": home, "KONTROLLPROV_HOME": home, "XDG_CONFIG_HOME": home + "/.config",
               "XDG_DATA_HOME": home + "/.local/share", "XDG_CACHE_HOME": home + "/.cache"})

sys.path.insert(0, str(AI))
import goblinai as g  # noqa: E402

REAL_SYS = g.sys_tools()
ROUNDS = g.CHECK_ROUNDS

VOICE_OK = "Rösten fungerar nu: installerad, behöver inte lagas, och tjänsten goblincakes-voice kör. Notisen gäller något som redan är förbi."
VOICE_NOTICE = ('Jag tryckte på en notis i dashboarden (från Goblin AI, 12:37): "Kakans röst gick inte att laga – pip '
                'misslyckades" – vad betyder den?')
MEMORY = {"title": "Bågskytte dam individuellt OS Paris 2024", "date": "2026-11-24", "url": "https://example.org/archery",
          "source": "Exempel", "facts": "Lim Sihyeon från Sydkorea vann guldet. Hon slog Nam Suhyeon med 7–3 i finalen."}
STEAM_LOG = "steam.service: Main process exited, code=exited, status=12. Felet: libGL saknas (kod 12)."
VERDICT = "**Vad som är fel:** {}\n**Vad jag har kollat:** loggen för steam\n**Kan jag laga det:** Nej – tryck Skicka till Claude."


class FakeSys:
    """sys_tools() with "Letar i datorn" reading this text – the rest is the real module (it only reads)."""
    def __init__(self, text, real):
        self.text, self.real = text, real

    def gather(self, question):
        return (self.text, ["logg steam"]) if self.text else ("", [])

    def describe(self, what):
        return "Läser loggen för steam"

    def __getattr__(self, name):
        return getattr(self.real, name)


# (namn, fråga, modellens svar i tur och ordning, {patchar}, väntat antal anrop, kontroller som ska slå till (delar av
# stegets text), kontroller som INTE får slå till, text som ska finnas i svaret, text som inte får finnas)
ASK = [
    ("röstnotis där allt fungerar – inget omtag", VOICE_NOTICE,
     ["Jag har kollat: rösten fungerar nu, notisen är gammal. Du behöver inte göra något."],
     {"voice": VOICE_OK}, 1, [], ["påstod", "saknar sammanfattning"], [], ["*Obs"]),
    ("svar ur kunskapsminnet – inget omtag, ingen sökning", "Vem vann damernas individuella i bågskytte i Paris-OS?",
     ["Jag har kollat i ditt kunskapsminne: Lim Sihyeon vann, 7–3 mot Nam Suhyeon (sparat 2026-11-24)."],
     {"memory": MEMORY}, 1, [], ["påstod"], ["ditt kunskapsminne"], ["*Obs"]),
    ("påhittat tal fångas, det rättade går igenom", "Varför startar inte Steam?",
     [VERDICT.format("Steam avslutas med kod 40."), VERDICT.format("Steam avslutas med kod 12 – libGL saknas.")],
     {"sys": STEAM_LOG}, 2, ["stod inte i det lästa: 40"], [], ["kod 12"], ["*Obs"]),
    ("citerat tal i omskrivningen ger ingen Obs-rad", "Varför startar inte Steam?",
     [VERDICT.format("Steam avslutas med kod 40."), VERDICT.format('Steam avslutas med kod 12 (inte "40").')],
     {"sys": STEAM_LOG}, 2, ["stod inte i det lästa: 40"], [], [], ["*Obs"]),
    ("läst-påstående utan att något lästs fångas", "Vad betyder felet i loggen?",
     ["Jag har läst loggen och felet är ofarligt.", "Jag vet inte utan att läsa loggen – vill du att jag gör det?"],
     {}, 2, ["påstod att hon läst"], [], [], []),
    # Taket med CHECK_ROUNDS satt till 1 här – tre olika kontroller väntar, den andra får inte köras
    ("taket för omtag", "Varför startar inte Steam?",
     ["Jag har kollat. Låt mig kontrollera ~/.steam/a.log."] * 12,
     {"sys": STEAM_LOG, "rounds": 1}, 2, ["kontrollrundor"], [], ["hann inte kontrollera"], []),
]

# Klart-kontrollen: (fråga, svar, väntad kind – "" = ingen dom)
RECEIPT = [
    ("Funkar rösten?", "Ja, rösten fungerar nu.", ""),
    ("Är wow uppdaterat?", "Ja, WoW är uppdaterat.", ""),
    ("Har jag sparat bilden?", "Ja, du har sparat den i Bilder.", ""),
    ("Gick senaste bygget igenom?", "Ja – felet löste sig av sig självt.", ""),
    ('Jag tryckte på en notis i dashboarden (från Goblin AI, 20:15): "Bygget misslyckades"', "Felet är löst – du behöver göra inget.", ""),
    ("Ljudet funkar inte, kan du laga det?", "Nu är det fixat!", "nothing"),
    ("Kan du uppdatera wow?", "Klart, WoW är uppdaterat.", "nothing"),
    ("Ändra volymen i Spotify till 50", "Klart, jag har ändrat volymen.", "nothing"),
]

# Meningar om kunskapsminnet före Tillåt: (text, väntat efter without_saved_claims)
SAVED = [
    ("Förstått! Jag har sparat fakta om guldet i kunskapsminnet. Tryck Tillåt under svaret.",
     "Förstått! Tryck Tillåt under svaret."),
    ("Faktum är att det redan har sparas i kunskapsminnet! Kortet finns under svaret.", "Kortet finns under svaret."),
    ("Det sparades i ditt kunskapsminne 24 nov.", "Det sparades i ditt kunskapsminne 24 nov."),
    ("Jag har sparat det i ditt vanliga minne.", "Jag har sparat det i ditt vanliga minne."),
]


# Följdfrågor (follow_up_of): (chatten före, frågan, väntat antal frågor/svar-par – 0 = ingen följdfråga)
WEB = "Paris 2024.\n\n**Källor:** [OS](https://example.org/os)"
MEMORY = "Lim Sihyeon vann.\n\n**Hämtat från:** ditt kunskapsminne (Bågskytte OS Paris 2024)"
FOLLOW = [
    ([("när gick senaste OS i bågskytte?", WEB)], "blev det några världsrekord?", 1),
    # 25 nov: svaret före kom ur kunskapsminnet – följdfrågan söktes inte och hon hittade på en svensk bågskytt
    ([("när gick senaste OS i bågskytte?", WEB), ("vem vann damerna?", MEMORY)], "fanns det några svenskar med?", 2),
    ([("vad är klockan?", "Den är 12.")], "och i Tokyo?", 0),
    ([("hur mår datorn?", "Bra.\n\n**Hämtat från:** systemloggen")], "och nätet?", 0),
]

def run_ask(question, answers, patch):
    script, calls = list(answers), []

    def fake(messages, keys, status=None, notice=None, project=None, choice="", tools=None, *a, **k):
        calls.append(1)
        return (script.pop(0) if script else "Slutsvar."), "låtsasmodell"
    g.ask_once = fake
    g.voice_now = lambda: patch.get("voice", "")
    g.after_now = lambda text: ""
    memory = patch.get("memory")
    g.knowledge_for = lambda text: [(memory, True)] if memory else []
    g.kunskap_mod().as_text = lambda s: f"## {s['title']}\nSparad {s['date']} · Källa: {s['url']}\n{s['facts']}"
    fake_sys = FakeSys(patch.get("sys", ""), REAL_SYS)
    g.sys_tools = lambda: fake_sys
    g.CHECK_ROUNDS = patch.get("rounds", ROUNDS)
    steps = g.Steps()
    answer, _ = g.ask([{"role": "system", "content": "s"}, {"role": "user", "content": question}], {}, steps=steps)
    fired = [f"{s.get('text', '')}: {s.get('note', '')}" for s in steps.items if s.get("state") == "fel"]
    return len(calls), fired, answer


def main():
    bad = []
    for name, question, answers, patch, want_calls, must, must_not, has, has_not in ASK:
        try:
            n, fired, answer = run_ask(question, answers, patch)
        except Exception as e:  # noqa: BLE001 – a crash is a failed case
            bad.append(f"{name}: kraschade ({type(e).__name__}: {e})")
            continue
        why = []
        if n != want_calls:
            why.append(f"{n} anrop, väntat {want_calls}")
        why += [f"kontrollen \"{m}\" slog inte till" for m in must if not any(m in f for f in fired)]
        why += [f"kontrollen \"{m}\" slog till" for m in must_not if any(m in f for f in fired)]
        why += [f"\"{t}\" saknas i svaret" for t in has if t not in answer]
        why += [f"\"{t}\" står i svaret" for t in has_not if t in answer]
        if why:
            bad.append(f"{name}: " + "; ".join(why) + (f" (slog till: {' | '.join(fired)})" if fired else ""))
    for question, answer, kind in RECEIPT:
        display = [{"role": "user", "text": question},
                   {"role": "assistant", "text": answer, "segments": [{"type": "text", "text": answer}],
                    "tools": [["leta", "x"]]}]
        got = (g.receipt(display, 1) or {}).get("kind", "")
        if got != kind:
            bad.append(f"klart-kontrollen \"{question[:40]}\": \"{got}\", väntat \"{kind}\"")
    for text, want in SAVED:
        got = g.without_saved_claims(text)
        if got != want:
            bad.append(f"without_saved_claims \"{text[:40]}\": \"{got}\"")
    for chat, question, want in FOLLOW:
        msgs = [m for q, a in chat for m in ({"role": "user", "content": q}, {"role": "assistant", "content": a})]
        msgs.append({"role": "user", "content": question})
        got = len(g.follow_up_of(msgs, msgs[-1]))
        if got != want:
            bad.append(f"follow_up_of \"{question}\": {got} par, väntat {want}")
    import omtag  # the omtag log got the rounds above (in the empty home)
    logged = [r["check"] for r in omtag.rows(1)]
    if not any(c.startswith("stod inte i det lästa") for c in logged) or not any("kontrollrundor" in c for c in logged):
        bad.append(f"omtag-loggen fick inte omtagen: {logged[:6]}")
    total = len(ASK) + len(RECEIPT) + len(SAVED) + len(FOLLOW) + 1
    for b in bad:
        print("FEL: " + b)
    print(f"Kontrollprovet: {total - len(bad)} av {total} fall som väntat")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
