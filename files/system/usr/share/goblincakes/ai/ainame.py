"""The AI's name – one place for all of GOBLINCAKES (20 Nov, the user: "Kakan är mitt lokala namn på min ai").

Everyone gets "Goblin AI" (DEFAULT – what the name setting always showed when empty; 20 Nov the user: "Goblin AI som standard"); a name of your own is set in Goblin AI → Inställningar → Namn and lives in
~/.config/goblincakes/ai-name (the clock box and GoblinRecorder read the same file). The voice's wake word
follows it. Only the standard library – the voice, the dashboard and the services import it.

    import ainame
    ainame.name()   → "Goblin AI" or the chosen name
    ainame.gen()    → "Goblin AI:s" / "Kakans" (Swedish genitive: ":s" after an abbreviation, nothing after s, x or z)
    ainame.say("Fråga {name} om {gen} rapport") – {name} and {gen} filled in
"""
import os
from pathlib import Path

DEFAULT = "Goblin AI"
FILE = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "goblincakes" / "ai-name"


def chosen():
    """The name the user gave, or "" (none chosen)."""
    try:
        return " ".join(FILE.read_text().split())[:30]
    except OSError:
        return ""


def name():
    return chosen() or DEFAULT


def genitive(word):
    if word[-2:].isupper() and word[-2:].isalpha():   # AI → AI:s
        return word + ":s"
    return word if word[-1:].lower() in ("s", "x", "z") else word + "s"


def gen():
    return genitive(name())


def say(text):
    """text with {name} and {gen} filled in."""
    n = name()
    return text.replace("{name}", n).replace("{gen}", genitive(n))


def prov():
    """The folder in home for the AI's trial copies and widgets: ~/kakan-prov where it already is (made before 20 Nov –
    left as it is), else ~/goblin-prov."""
    old = Path.home() / "kakan-prov"
    return "kakan-prov" if old.is_dir() else "goblin-prov"
