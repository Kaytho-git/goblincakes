"""Kakan's simple voice commands (Kakan step 9, part C, 4 Nov): what was said → something done at once,
without a language model, so they also work during games (when the local AI rests).

    match(text) → (command, argument) or None    – None = a question for Kakan (part D)
    run(command, argument) → (sentence, speak)   – does it; speak = read the sentence aloud
                                                   (music commands only show it in the box)

The doing is Kakan's own (desktop.py: music, player_volume, start_game, open_thing, play – the same as
when she is asked in writing, logged in her receipt the same way); here is only the understanding.
Commands: clock, pull (the latest pull on Warcraft Logs, opened in the browser), pause, play, next,
previous, louder, quieter (the music's own volume), start <game or program>, spela <album/låt/artist>
(Spotify, shown in GoblinAmp – the user's wish 4 Nov: "starta ett album av en artist").

Whisper hears English game words the Swedish way: "Starta Vov" = WoW, "fullen" = pullen (both heard
with the user's microphone 4 Nov) – fix_words() turns them back before matching.
Try without a microphone:  python3 voicecmd.py "starta vov" "spela albumet master of puppets med metallica"
"""
import difflib
import os
import re
import subprocess
import time

CONVERSATION = "röst"   # how the voice's actions are marked in Kakan's log

# ── Understanding ─────────────────────────────────────────────────

HEARD_AS = [
    (r"\b(?:vov|vav|vaw|vow|vå|wov|wow|wåw)\b", "wow"),
    (r"\b(?:world|wall|vold|ward|wold|vöröld|world's)\s+(?:of|av)\s+warcraft\b", "wow"),
    # The reading test 4 Nov (the user's 15 lines): game words heard the Swedish way
    (r"\bh[eä]j\s+(?=vol)", "höj "),                                   # "Hej volymen" ×3 = höj
    (r"\b(?:volleimen|volymer|volymmen|volejmen|vollymen)\b", "volymen"),
    (r"\b(?:spartify|spotifaj|spotifej|spåtify|spottify)\b", "spotify"),
    (r"\b(?:mitic|mytic|mythik|mitik|mytik|mythic)\s*(?:plus|pluss|\+)", "mythic plus"),
    (r"\b(?:parces|parsar|parsen|parser)\b", "parses"),
    (r"\b(?:buggsäck|bugsäck|buggsack|bug sack|buggsäcken)\b", "bugsack"),
    (r"\b(?:gerplaner|gear\s*planer|gir\s*planer|gearplaner|gerplanner|gear planner)\b", "gear-planner"),
    (r"\bpremiär(?=matchen|match|\b)", "premier"),
    (r"\b(?:fullen|pulen|bullen|pullan|poolen|pullet)\b", "pullen"),
    (r"\b(?:cs\s*två|cs\s*2|counter[\s-]*strike(?:\s*2|\s*två)?|ces två)\b", "cs2"),
    (r"\bwarcraft\s*l[oå]g[gs]?s?\b", "warcraft logs"),
    (r"\bgoblin\s*a\s*i\b|\bgoblin\s*aj\b", "goblin ai"),
    # GoblinAmp as Whisper heard it 4 Nov: gollinab, gobblorna, gubblarna ("spela gubblarna" found Babblarna)
    (r"\b(?:go[bl]{1,3}in\s*am[pb]?|go[bl]{1,3}ina[bp]|go[bl]{1,3}ina?m|gob+lorna|gub+larna|gob+larna|gob+linamp)\b",
     "goblinamp"),
]
MUSIC = r"(?:musik(?:en)?|låt(?:en)?|spotify|goblinamp|ljud(?:et)?|volym(?:en)?)"
GAMES = ("wow", "cs2")
KINDS = {"albumet": "album", "album": "album", "albumen": "album", "skivan": "album", "plattan": "album",
         "låten": "låt", "låt": "låt", "artisten": "artist", "bandet": "artist", "gruppen": "artist",
         "listan": "lista", "spellistan": "lista"}


def fix_words(text):
    t = text.lower()
    t = re.sub(r"[.,!?;:\"“”]", " ", t)
    t = re.sub(r"(?<=\w)['’](?=\w)", "", t)          # "l'ambe of god"
    for pattern, word in HEARD_AS:
        t = re.sub(pattern, word, t)
    return " ".join(t.split())


def match_all(text):
    """Every command in what was said ("vad är klockan och visa senaste pullen"), in order; [] = none.
    Split at sentence ends and "och"/"sen"; a part that isn't a command makes the whole thing a question
    for Kakan, so a real question with "och" in it is never half done."""
    whole = match(text)
    parts = [p for p in re.split(r"[.?!]+|\s+(?:och sedan|och sen|och|sen|sedan)\s+", text) if p and p.strip()]
    if len(parts) > 1:
        found = [match(p) for p in parts]
        found = [f for f, p in zip(found, parts) if f or len(fix_words(p).split()) > 2]
        if found and all(found):
            return found
    return [whole] if whole else []


def match(text):
    t = fix_words(text)
    t = re.sub(r"^(?:kakan\s+)?(?:kan du\s+|snälla\s+)?", "", t)
    if not t:
        return None
    short = len(t.split()) <= 5
    if re.search(r"\bklockan\b", t) and re.search(r"\b(?:vad|hur|vilken)\b", t):
        return ("clock", "")
    if re.search(r"\b(?:senaste|sista|förra)\s+(?:pullen|pull|försöket|wipen|wipe|killen)\b", t) \
            or (re.search(r"\bpullen\b", t) and re.search(r"\b(?:visa|ge|öppna|ta fram)\b", t)):
        return ("pull", "")
    if re.fullmatch(r"(?:lite|ännu|en gång|en bit)?\s*(?:till|mer|igen|en gång till)", t):
        return ("again", "")
    m = re.search(r"\b(?:volym\w*|ljud\w*|musik\w*)\b.*?\btill\s+(\d{1,3})\s*(?:%|procent)?", t)
    if m and re.search(r"\b(?:sätt|ställ|höj\w*|sänk\w*|ändra)\b", t):
        return ("volume_to", m.group(1))
    if re.search(r"\b(?:höj\w*|ök\w*|högre|starkare|mer ljud)\b", t) and (short or re.search(MUSIC, t)):
        return ("louder", "big" if re.search(r"\bmycket\b", t) else "")
    if re.search(r"\b(?:sänk\w*|minsk\w*|lägre|tystare|svagare|mindre ljud)\b", t) and (short or re.search(MUSIC, t)):
        return ("quieter", "big" if re.search(r"\bmycket\b", t) else "")
    if re.search(r"\b(?:pausa|pause|stoppa|stopp)\b", t) and (short or re.search(MUSIC, t)):
        return ("pause", "")
    if re.search(r"\b(?:nästa|hoppa över|skippa)\b", t) and (short or re.search(MUSIC, t)):
        return ("next", "")
    if re.search(r"\b(?:förra|föregående)\s+låt", t) or re.search(r"\bspela\s+(?:förra|föregående)\b", t):
        return ("previous", "")
    if re.fullmatch(rf"(?:spela|fortsätt|fortsätt spela)(?:\s+upp)?(?:\s+{MUSIC})?", t) \
            or re.fullmatch(rf"(?:starta|sätt på)\s+(?:upp\s+)?{MUSIC}", t):   # "kan du starta?" alone = nothing
        return ("play", "")
    if re.fullmatch(r"(?:spela|starta|fortsätt(?: spela)?|sätt på)\s+(?:i\s+|på\s+)?(?:goblinamp|spotify)", t):
        return ("play", "")
    t = re.sub(r"\s+(?:i|på|med)\s+(?:goblinamp|spotify)$", "", t)   # where: always Spotify
    # "starta <artist> albumet <titel>" (artist first, 4 Nov: "Starta Lamb of God, albumet Lamb of God")
    m = re.match(r"^(?:spela|starta|sätt på|lyssna på)\s+(?:upp\s+)?(.+?)\s+(albumet|album|skivan|plattan|låten)\s+"
                 r"(?!med\b|av\b)(.+)$", t)
    if m and m.group(1) not in KINDS:
        return ("music", (KINDS[m.group(2)], m.group(1).strip(), m.group(3).strip()))
    # "starta <titel>-albumet med <artist>" / "<titel> albumet av <artist>"
    m = re.match(r"^(?:kan du\s+)?(?:spela|starta|sätt på|lyssna på)\s+(?:upp\s+)?(.+?)[\s-]+(albumet|album|skivan|plattan|låten)"
                 r"(?:\s+(?:med|av)\s+(.+))?$", t)
    if m and m.group(1) not in KINDS:
        return ("music", (KINDS[m.group(2)], (m.group(3) or "").strip(), m.group(1).strip()))
    # spela [albumet/låten/artisten] <titel> [med/av <artist>] – Spotify; "spela wow" = the game
    m = re.match(r"^(?:kan du\s+)?(?:spela|sätt på|lyssna på|starta (?=albumet|skivan|plattan|låten|artisten|bandet))"
                 r"\s*(?:upp\s+)?(?:lite\s+)?(.+)$", t)
    if m:
        rest = m.group(1).strip()
        if rest in GAMES:
            return ("start", rest)
        first, _, after = rest.partition(" ")
        kind = KINDS.get(first, "")
        if kind:
            rest = after.strip()
        title, sep, artist = rest.rpartition(" med ") if " med " in rest else rest.rpartition(" av ")
        if not sep:
            title, artist = rest, ""
        title, artist = title.strip(), artist.strip()
        if not title:
            return None
        if not kind and not artist:
            kind = "artist"          # "spela metallica"
        return ("music", (kind, artist, title))
    m = re.match(r"^(?:kan du\s+|snälla\s+)?(?:starta|öppna|kör|sätt igång)\s+(?:upp\s+)?(.+)$", t)
    if m and short:
        name = re.sub(r"\b(?:spelet|programmet|appen|åt mig|tack|snälla)\b", "", m.group(1)).strip()
        if name:
            return ("start", name)
    return None


# ── Doing (Kakan's own functions) ─────────────────────────────────

def _desktop():
    import desktop  # noqa: PLC0415 – Kakan's; loaded only when a command comes
    return desktop


def _plain(sentence):
    """Kakan's written answers, made for reading aloud: no "→", no notes about the local AI."""
    s = re.sub(r"\s*Medan ett spel kör vilar den lokala AI:n\.", "", sentence)
    s = re.sub(r"\(det finns också:[^)]*\)", "", s)
    s = s.replace(" (syns i GoblinAmp)", "").replace("%", " procent").replace(" → ", " till ")
    return " ".join(s.split())


def _sounds(text):
    """Roughly how a title sounds, so Swedish-heard English compares with the real spelling:
    "venions falls" and "vengeance falls" → "venians fals" / "venjans fals"."""
    t = re.sub(r"\W+", " ", text.lower()).strip()
    for a, b in (("ng", "n"), ("ge", "je"), ("ce", "s"), ("ea", "e"), ("io", "ia"), ("ph", "f"), ("th", "t"),
                 ("w", "v"), ("ck", "k"), ("c", "k"), ("y", "i"), ("z", "s"), ("ou", "au"), ("ll", "l"),
                 ("ss", "s"), ("tt", "t"), ("pp", "p"), ("ee", "i"), ("oo", "u")):
        t = t.replace(a, b)
    return t


def heard_album(d, artist, title):
    """Whisper hears English titles the Swedish way ("Venjans Fals" by "Trivim" = Vengeance Falls by
    Trivium, 4 Nov): Spotify's own search finds the artist despite the spelling, then the artist's album
    whose name sounds most like it. (artist, title) as Spotify writes them; unchanged when not found."""
    try:
        sw = d._spotify()
        client = sw.Client()
        items = (client.get("/search", {"q": artist, "type": "artist", "limit": 5}).get("artists") or {}).get("items") or []
        found = next((i for i in items if i), None)
        if not found:
            return artist, title
        albums, singles = sw.Library(client).artist_albums({"uri": found["uri"], "title": found.get("name", artist)})
        heard = _sounds(title)
        scored = []
        for a in albums + singles:
            plain = re.sub(r"\s*[(\[].*?[)\]]|\s+-\s+.*$", "", a["title"]).strip()   # "(2023 Remaster)" away
            scored.append((difflib.SequenceMatcher(None, heard, _sounds(plain)).ratio(), plain))
        scored.sort(reverse=True)
        best = scored[0] if scored and scored[0][0] >= 0.5 else None
        return found.get("name", artist), (best[1] if best else title)
    except Exception:  # noqa: BLE001 – not signed in, no network: the plain search in play() then
        return artist, title


def latest_pull():
    """(url, sentence) for the latest pull on Warcraft Logs (GoblinRecorder's/WoW Stats' reports)."""
    import wowtools  # noqa: PLC0415
    rep, fight, _player = wowtools.find_fight(wowtools.recorder(), "senaste pullen")
    url = f"https://www.warcraftlogs.com/reports/{rep['code']}#fight={fight['id']}"
    boss = fight.get("name") or "bossen"
    if fight.get("kill"):
        return url, f"Här är den senaste pullen. {boss}, ni dödade den."
    pct = fight.get("bossPercentage")
    left = f", wipe på {round(pct)} procent" if isinstance(pct, (int, float)) else ", wipe"
    return url, f"Här är den senaste pullen. {boss}{left}."


def clock_sentence():
    t = time.localtime()
    return f"Klockan är {t.tm_hour} och {t.tm_min:02d}." if t.tm_min else f"Klockan är {t.tm_hour} prick."


def run(command, arg):
    """Does it. Returns (sentence, speak): speak True = read the sentence aloud, a string = say that
    instead (the sentence is still shown), False = only show it."""
    if command == "clock":
        return clock_sentence(), True
    if command == "pull":
        try:
            url, said = latest_pull()
        except Exception as e:  # noqa: BLE001 – no report, no network, not signed in to Warcraft Logs
            return f"Jag hittar ingen pull på Warcraft Logs. {e}".strip(), True
        subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
        return said, True
    d = _desktop()
    if command in ("pause", "play", "next", "previous"):
        word = {"pause": "paus", "play": "spela", "next": "nästa", "previous": "föregående"}[command]
        return _plain(d.music(word, CONVERSATION)), False
    if command == "volume_to":
        return _plain(d.player_volume("musiken", arg, CONVERSATION)), False
    if command in ("louder", "quieter"):
        step = 25 if arg == "big" else 10
        return _plain(d.player_volume("musiken", f"{'+' if command == 'louder' else '-'}{step}", CONVERSATION)), False
    if command == "start":
        if arg in ("goblin ai", "kakan", "dig", "dig själv"):
            subprocess.Popen(["goblin-ai"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             start_new_session=True)
            return "Här är jag.", True
        if os.environ.get("GOBLINCAKES_VOICE_NO_GAMES"):   # a reading test: everything but the games
            gm = d._games_module()
            name = {"wow": "wow", "cs2": "cs2"}.get(arg, arg)
            if arg in GAMES or gm.find(name, gm.games()):
                return f"Prov: {arg} startas inte.", True
        said = d.start_game(arg, CONVERSATION)
        if said.startswith(("Hittar inget spel", "Kommer inte åt")):
            said = d.open_thing(arg, CONVERSATION)
        return _plain(said), True
    if command == "music":
        kind, artist, title = arg
        if kind == "album" and artist:
            artist, title = heard_album(d, artist, title)
        what = f"{artist} - {title}" if artist else title
        said = _plain(d.play(kind, what, CONVERSATION))
        if said.startswith("Spelar "):   # her English is worse than the user's (4 Nov): titles only in the box
            return said, {"album": "Spelar albumet.", "låt": "Spelar låten.", "artist": "Spelar artisten.",
                          "lista": "Spelar listan."}.get(kind, "Spelar.")
        return said, True
    return "", False


if __name__ == "__main__":
    import sys
    for a in sys.argv[1:] or ["starta vov", "ge mig senaste fullen", "spela albumet master of puppets med metallica"]:
        print(f"{a!r:55} → {match_all(a)}")
