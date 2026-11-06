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
import collections
import difflib
import json
import os
import re
import subprocess
import time
from pathlib import Path

CONVERSATION = "röst"   # how the voice's actions are marked in Kakan's log

# ── Understanding ─────────────────────────────────────────────────

HEARD_AS = [
    (r"\b(?:vov|vav|vaw|vow|vå|wov|wow|wåw|förhopp|för hopp)\b", "wow"),   # "Starta förhopp" = starta WoW (4 Nov)
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
    # 5 Nov: "Starta kabeln app" = GoblinAmp, "Starta Bob" = WoW
    (r"\bkab+eln\s*ap+\b", "goblinamp"),
    (r"\b(starta|spela|öppna|kör)\s+bob\b", r"\1 wow"),
    (r"\b(?:go[bl]{1,3}in\s*am[pb]?|go[bl]{1,3}ina[bp]|go[bl]{1,3}ina?m|gob+lorna|gub+larna|gob+larna|gob+linamp)\b",
     "goblinamp"),
]
MUSIC = r"(?:musik(?:en)?|låt(?:en)?|spotify|goblinamp|ljud(?:et)?|volym(?:en)?)"
GAMES = ("wow", "cs2")
KINDS = {"albumet": "album", "album": "album", "albumen": "album", "skivan": "album", "plattan": "album",
         "låten": "låt", "låt": "låt", "artisten": "artist", "bandet": "artist", "gruppen": "artist",
         "listan": "lista", "spellistan": "lista", "spellista": "lista", "lista": "lista"}
PLAY = r"(?:spela|starta|sätt på|lyssna på)\s+(?:upp\s+)?"


def fix_words(text):
    t = text.lower()
    t = re.sub(r"[.,!?;:\"“”]", " ", t)
    t = re.sub(r"(?<=\w)['’](?=\w)", "", t)          # "l'ambe of god"
    for pattern, word in HEARD_AS:
        t = re.sub(pattern, word, t)
    t = re.sub(r"^((?:kakan\s+)?(?:kan du\s+)?)spelar\b", r"\1spela", t)   # Whisper hears "Spelar …" (6 Nov)
    t = re.sub(r"\b(\w{2,}?)(albumet|album)\b", r"\1 \2", t)               # "vengeance falalbum" (6 Nov)
    return " ".join(t.split())


def match_all(text):
    """Every command in what was said ("vad är klockan och visa senaste pullen"), in order; [] = none.
    Split at sentence ends and "och"/"sen"; a part that isn't a command makes the whole thing a question
    for Kakan, so a real question with "och" in it is never half done."""
    whole = match(text)
    # 5 Nov: "Menade du …?" → "nej" → "Sack Wild, Book of Shadros II" without "spela" = the answer
    if not whole and time.monotonic() - _asked < 60 and 0 < len(fix_words(text).split()) <= 10:
        return [("music", ("svar", "", fix_words(text)))]     # an answer, not a new "spela …"
    parts = [p for p in re.split(r"[.?!]+|\s+(?:och sedan|och sen|och|sen|sedan)\s+", text) if p and p.strip()]
    if len(parts) > 1:
        found = [match(p) for p in parts]
        found = [f for f, p in zip(found, parts) if f or len(fix_words(p).split()) > 2]
        if found and all(found):
            return found
    return [whole] if whole else []


def match(text):
    # "Spela Triviums, Vengeance Falls album" (6 Nov): artist, comma, title + kind – the comma is gone
    # after fix_words, so it is looked for first
    m = re.match(r"^(?:kakan\s+)?(?:kan du\s+)?(?:spela|spelar|starta|sätt på|lyssna på)\s+(?:upp\s+)?([^,]+?)s?,\s*"
                 r"([^,]+?)[\s-]*(albumet|album|skivan|plattan|låten)[.!?\s]*$",
                 re.sub(r"\b(\w{2,}?)(albumet|album)\b", r"\1 \2", text.lower().strip()))
    if m and fix_words(m.group(1)) and fix_words(m.group(2)):
        return ("music", (KINDS[m.group(3)], fix_words(m.group(1)), fix_words(m.group(2))))
    t = fix_words(text)
    t = re.sub(r"^(?:kakan\s+)?(?:kan du\s+|snälla\s+)?", "", t)
    if not t:
        return None
    short = len(t.split()) <= 5
    # "det laggar" (5 Nov): the lag meter marks the moment (as Meta+Shift+L) – the looking is Goblin AI's later
    if short and re.search(r"\b(?:laggar|lagar|lagger|hackar|stammar|laggigt|lagget)\b", t):
        return ("lag", "")
    if re.search(r"\bklockan\b", t) and re.search(r"\b(?:vad|hur|vilken)\b", t):
        return ("clock", "")
    if re.search(r"\b(?:senaste|sista|förra)\s+(?:pullen|pull|försöket|wipen|wipe|killen)\b", t) \
            or (re.search(r"\bpullen\b", t) and re.search(r"\b(?:visa|ge|öppna|ta fram)\b", t)):
        return ("pull", "")
    if re.fullmatch(r"(?:ja|japp|jo|jajamän|precis|exakt|ja tack|ja det|ja spela (?:den|det)|gör det|"
                    r"det stämmer|stämmer|ja det stämmer)", t):
        return ("yes", "")              # "Menade du …?" (find_music was unsure)
    if re.fullmatch(r"(?:nej|nä|nej tack|fel|nej det var fel)", t):
        return ("no", "")
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
    # "spela min spellista tyngaste opeth någonsin" (5 Nov: was searched as an artist)
    m = re.match(rf"^{PLAY}(?:min|mina|min egen|vår)\s+(?:spel)?list(?:a|an)\s+(.+)$", t)
    if m:
        return ("music", ("lista", "", m.group(1).strip()))
    # "spela senaste albumet med zakk wylde" / "spela zakk wyldes senaste album" (5 Nov)
    m = re.match(rf"^{PLAY}(?:det\s+)?(?:senaste|nyaste)\s+(?:albumet|album|skivan|plattan)\s+(?:med|av|från)\s+(.+)$", t)
    if not m:
        m = re.match(rf"^{PLAY}(.+?)s?\s+(?:senaste|nyaste)\s+(?:albumet|album|skiva|skivan|platta|plattan)$", t)
    if m:
        return ("music", ("senaste", m.group(1).strip(), ""))
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
        # no kind and no artist ("spela metallica", "spela tyngsta opeth någonsin"): anything –
        # find_music tries artists, the user's lists, albums and tracks
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
                 ("w", "v"), ("ck", "k"), ("ch", "k"), ("kk", "k"), ("c", "k"), ("y", "i"), ("z", "s"), ("ou", "au"), ("ll", "l"),
                 ("ss", "s"), ("tt", "t"), ("pp", "p"), ("ee", "i"), ("oo", "u")):
        t = t.replace(a, b)
    return t


# ── The user's own music: Whisper's word list and what was meant (5 Nov) ──────────
# The test 4 Nov: Whisper heard the Swedish fine but English names the Swedish way ("Saquald" = Zakk Wylde,
# "Aldard Remains" = All That Remains), and the plain Spotify search then played something else
# (Saxon, Cannibal Corpse). Now: the user's own library first, everything compared by how it sounds,
# and only a close match is played – a half-close one is asked about ("Menade du …?" → "ja").

# What she has learned the user means (5 Nov, the user: "jag säger ju inte Strikewild" – it's what Whisper
# hears for Zakk Wylde): a "ja" to "Menade du …?", or the name said again after a "nej", saves heard → meant.
# Only on this computer; the voice card in Goblin AI lists them and can remove one.
LEARNED_FILE = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "goblincakes" / "voice-learned.json"
_missed = None                # (heard, when): after a "nej" – what was heard wrong, until the right one plays
_used = None                  # (heard, when): something just played from what she learned – "nej" forgets it


def _heard_key(artist, title):
    return " ".join(f"{artist} {title}".lower().replace("–", " ").split())


def learned():
    try:
        return json.loads(LEARNED_FILE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def learn(heard, kind, uri, name):
    """heard (as _heard_key) now means this – used at once the next time, without asking."""
    if not heard or not uri:
        return
    data = learned()
    old = data.get(heard, {})
    data[heard] = {"kind": kind, "uri": uri, "name": name, "t": time.time(),
                   "n": old.get("n", 0) + 1 if old.get("uri") == uri else 1}
    LEARNED_FILE.parent.mkdir(parents=True, exist_ok=True)
    tmp = LEARNED_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    tmp.replace(LEARNED_FILE)
    print(f"Lärde mig: \"{heard}\" = {name}", flush=True)


def forget_learned(heard):
    data = learned()
    if data.pop(heard, None) is not None:
        LEARNED_FILE.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")


def _learn_missed(kind, uri, name):
    """After "nej" + the name again: what was heard wrong the first time means what just played."""
    global _missed
    if _missed and time.monotonic() - _missed[1] < 90:
        learn(_missed[0], kind, uri, name)
    _missed = None


WORDS_FILE = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "goblincakes" / "voice-words.json"
WORDS_AGE = 24 * 3600
SURE, MAYBE = 0.75, 0.6        # how alike: play / ask / not found
DASH = re.compile(r"\s+[–—-]\s+")
_pending = None               # (kind, uri, name, when) – what "ja" plays
_asked = 0.0                  # when she last asked about music – a bare name after it = "spela <name>"
_by = None                    # (uri, name, when): "Spela Zakk Wylde" → "Vilket album eller vilken låt?"


def ask_in_window(text):
    """Anything that isn't a simple command: Goblin AI opens with the question asked, so a proper model
    answers there (the user 5 Nov: the voice does the small things; checking is Goblin AI's job)."""
    subprocess.Popen(["goblin-ai", "--ask", text], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)
ANY = re.compile(r"^(?:spela\s+)?(?:vad som helst|vilken som helst|vilket som helst|blanda|bara (?:spela|artisten|honom|henne|dem)|"
                 r"allt|alla|spela bara|det spelar ingen roll|spelar ingen roll|artisten)$")


def own_music():
    """The cached library ({} before the first refresh): artists (most listened first), lists, albums, tracks."""
    try:
        return json.loads(WORDS_FILE.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def refresh_own_music(force=False):
    """Fetches the user's lists, saved albums and liked tracks from Spotify (GoblinAmp's sign-in) once a day.
    Returns the data, or None when not signed in / no network."""
    old = own_music()
    if not force and old and time.time() - old.get("made", 0) < WORDS_AGE:
        return old
    sw = _desktop()._spotify()
    if not sw.load().get("refreshToken"):
        return None
    client = sw.Client()
    counts = collections.Counter()
    lists, albums, tracks = [], [], []
    for e in sw.Library(client).lists():
        if e.get("special") or not e.get("name"):
            continue
        artist, title = _split(e["name"])
        lists.append({"name": title, "artist": artist, "uri": e["uri"], "full": e["name"]})
        counts[artist] += 10 if artist else 0
    for path, out, cap in (("/me/albums", albums, 500), ("/me/tracks", tracks, 2000)):
        url, query = path, {"limit": 50}
        while url and len(out) < cap:
            page = client.get(url, query)
            query = None
            for it in page.get("items") or []:
                thing = (it or {}).get("album" if path == "/me/albums" else "track") or {}
                names = [a.get("name", "") for a in thing.get("artists") or [] if a]
                if not thing.get("uri") or not names:
                    continue
                out.append({"name": thing.get("name", ""), "artist": names[0], "uri": thing["uri"]})
                for n in names:
                    counts[n] += 10 if path == "/me/albums" else 1   # saved = chosen
            url = page.get("next")
    data = {"made": time.time(), "artists": [a for a, _ in counts.most_common(300) if a],
            "lists": lists, "albums": albums, "tracks": tracks}
    WORDS_FILE.parent.mkdir(parents=True, exist_ok=True)
    tmp = WORDS_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    tmp.replace(WORDS_FILE)
    return data


def whisper_words():
    """Names for Whisper to expect, most important first (the worker cuts the list to fit its prompt):
    the most listened artists, then the albums saved as lists."""
    data = own_music()
    words = list(data.get("artists") or [])[:60]
    for e in (data.get("lists") or []) + (data.get("albums") or []):
        if e.get("artist") and e.get("name") and e["name"] not in words:
            words.append(_clean(e["name"]))
    return words


def _split(name):
    """"Zakk Wylde – Book Of Shadows II" → ("Zakk Wylde", "Book Of Shadows II"); no dash → ("", name)."""
    parts = DASH.split(name, maxsplit=1)
    return (parts[0].strip(), parts[1].strip()) if len(parts) == 2 else ("", name.strip())


def _clean(text):
    t = re.sub(r"\s*[(\[].*?[)\]]", "", text)                  # (Deluxe), [2023 Remaster]
    t = re.sub(r"\s+-\s+(?:\d{4}\s+)?(?:remaster|live|deluxe).*$", "", t, flags=re.I)
    return t.strip()


def _sim(heard, real):
    """0–1, how alike two names sound ("saquald" / "Zakk Wylde"); "the", 2/II/två the same."""
    def norm(x):
        x = re.sub(r"^the\s+", "", _clean(x).lower())
        x = re.sub(r"\b(?:2|två)\b", "ii", re.sub(r"\b(?:3|tre)\b", "iii", x))
        return _sounds(x).replace(" ", "")
    a, b = norm(heard), norm(real)
    return difflib.SequenceMatcher(None, a, b).ratio() if a and b else 0.0


def _score(c, artist, title):
    if artist and c.get("artist"):
        sa, st = _sim(artist, c["artist"]), _sim(title, c["name"])
        return 0.6 * (sa + st) / 2 + 0.4 * min(sa, st)          # one name wrong pulls it down
    if artist:      # a list without an artist in its name: the whole heard against it
        return 0.9 * _sim(f"{title} {artist}", c["name"])
    s = _sim(title, c["name"])
    if c.get("artist"):                                        # "candlemass black dwarf" = artist + title
        s = max(s, _sim(title, f"{c['artist']} {c['name']}"), _sim(title, f"{c['name']} {c['artist']}"))
    return s


def _search(client, q, kind):
    try:
        page = client.get("/search", {"q": q, "type": kind, "limit": 10})
    except Exception:  # noqa: BLE001 – the other searches still count
        return []
    return [i for i in (page.get(kind + "s") or {}).get("items") or [] if i]


def _artist(client, heard):
    """(score, name, uri) of the artist that sounds most like it – the user's own first, then Spotify's."""
    own = [(_sim(heard, n) + 0.05, n, "") for n in own_music().get("artists") or []]   # the user's own wins
    found = [(_sim(heard, i.get("name", "")), i.get("name", ""), i.get("uri", "")) for i in _search(client, heard, "artist")]
    best = max(own + found, default=(0.0, "", ""))
    if best[1] and not best[2]:      # own name: Spotify's uri for exactly that name
        exact = [i for i in _search(client, f'artist:"{best[1]}"', "artist")
                 if i.get("name", "").casefold() == best[1].casefold()]
        best = (best[0], best[1], exact[0]["uri"] if exact else "")
    return best


REISSUE = re.compile(r"\b(?:remaster\w*|deluxe|box set|live|anniversary|expanded|reissue|edition|demos?)\b", re.I)
NEWEST = re.compile(r"^(?:spela\s+)?(?:den\s+|det\s+)?(?:senaste|nyaste|sista|nya)(?:\s+(?:albumet|skivan|plattan|album|skiva))?$")


def newest_album(lib, uri, name):
    """The artist's newest album – not a remaster/deluxe/live re-release of an old one (5 Nov:
    "Metallicas senaste skiva" gave "ReLoad (Remastered Deluxe Box Set)", not 72 Seasons).
    Spotify's search by year, newest years first – the artist's album list is not used: Spotify shut it
    for a day after many calls (5 Nov, "vänta 85435 s"), and its stand-in (10 search hits) misses new albums."""
    artist_id = uri.rsplit(":", 1)[-1]
    year = time.localtime().tm_year
    for first, last in ((year - 2, year), (year - 6, year - 3), (year - 14, year - 7), (1950, year - 15)):
        try:
            page = lib.client.get("/search", {"q": f'artist:"{name}" year:{first}-{last}', "type": "album", "limit": 10})
        except Exception:  # noqa: BLE001 – the next span
            continue
        found = [i for i in (page.get("albums") or {}).get("items") or []
                 if i and i.get("album_type") == "album" and not REISSUE.search(i.get("name", ""))
                 and artist_id in {a.get("id") for a in i.get("artists") or [] if a}]
        if found:
            best = max(found, key=lambda i: i.get("release_date") or "")
            return {"uri": best["uri"], "title": best.get("name", "")}
    return None


def find_music(kind, artist, title):
    """What was meant: ("play", kind, uri, name) / ("ask", kind, uri, name) / ("none", "", "", "").
    kind in: album, låt, artist, lista, senaste (the artist's newest album), "" (anything)."""
    sw = _desktop()._spotify()
    client = sw.Client()
    lib = sw.Library(client)
    own = own_music()
    if kind == "senaste":
        score, name, uri = _artist(client, artist)
        if score < MAYBE or not uri:
            return ("none", "", "", "")
        a = newest_album(lib, uri, name)
        if not a:
            return ("none", "", "", "")
        return ("play" if score >= SURE else "ask", "album", a["uri"], f"{name} – {a['title']}")
    want = {"album": {"album", "playlist"}, "låt": {"track"}, "artist": {"artist"}, "lista": {"playlist"}}.get(
        kind, {"album", "track", "artist", "playlist"})
    cands = []     # (kind, uri, name shown, artist, title compared)
    if "playlist" in want:
        for e in own.get("lists") or []:
            if kind == "album" and not e.get("artist"):
                continue                       # only lists saved from an album count as albums
            cands.append(("playlist", e["uri"], e.get("full") or e["name"], e.get("artist", ""), e["name"]))
    if "album" in want:
        cands += [("album", e["uri"], f"{e['artist']} – {e['name']}", e["artist"], e["name"]) for e in own.get("albums") or []]
    if "track" in want:
        cands += [("track", e["uri"], f"{e['artist']} – {e['name']}", e["artist"], e["name"]) for e in own.get("tracks") or []]

    def best_of(cs, bonus=0.0):
        scored = [(_score({"artist": a, "name": t}, artist, title) + bonus, k, u, n) for k, u, n, a, t in cs]
        return max(scored, default=(0.0, "", "", ""))

    best = best_of(cands, 0.03)                  # the user's own wins a tie
    if "artist" in want and not artist:          # always: "spela orbit kultur" is the band, not a liked track
        score, name, uri = _artist(client, title)
        if uri and score >= best[0] - 0.08:      # "Lamb of God" = the band before its album of that name
            best = (max(score, best[0]) + 0.01, "artist", uri, name)
    if best[0] < SURE and kind != "lista":       # Spotify's search too
        more = []
        if "album" in want:
            if artist:
                score, name, uri = _artist(client, artist)
                if score >= MAYBE and uri:
                    albums, singles = lib.artist_albums({"uri": uri, "title": name})
                    cs = [("album", a["uri"], f"{name} – {a['title']}", name, a["title"]) for a in albums + singles]
                    more.append(best_of(cs))
            for n, i in enumerate(_search(client, f"{title} {artist}".strip(), "album")):
                a = ", ".join(x.get("name", "") for x in i.get("artists") or [])   # a tie: Spotify's order
                more.append(best_of([("album", i["uri"], f"{a} – {i.get('name', '')}", a, i.get("name", ""))], -0.005 * n))
        if "track" in want:
            for n, i in enumerate(_search(client, f"{title} {artist}".strip(), "track")):
                a = ", ".join(x.get("name", "") for x in i.get("artists") or [])   # "enter sandman" = Metallica's
                more.append(best_of([("track", i["uri"], f"{a} – {i.get('name', '')}", a, i.get("name", ""))], -0.005 * n))
        best = max([best] + more)
    score, k, uri, name = best
    if score >= SURE:
        return ("play", k, uri, name)
    if score >= MAYBE:
        return ("ask", k, uri, name)
    return ("none", "", "", "")


def _spoken(name):
    """A name for reading aloud (5 Nov, the user: say it even in her English – "Sack Vilde" is
    understood, a box that has gone is not): "Zakk Wylde – Book Of Shadows II" → "Zakk Wylde, Book Of Shadows två"."""
    t = _clean(name).replace(" – ", ", ").replace(" - ", ", ")
    for roman, word in (("III", "tre"), ("II", "två"), ("IV", "fyra")):
        t = re.sub(rf"\b{roman}\b", word, t)
    return t


LABEL = {"album": "albumet", "track": "låten", "artist": "artisten", "playlist": "listan"}


def by_artist(artist_uri, artist_name, title):
    """The album or track of this artist that sounds most like the answer – only the artist's own,
    so a rough hearing is enough (5 Nov, the user's idea: artist first, then she asks which one)."""
    sw = _desktop()._spotify()
    lib = sw.Library(sw.Client())
    entry = {"uri": artist_uri, "title": artist_name}
    albums, singles = lib.artist_albums(entry)
    cands = [("album", a["uri"], f"{artist_name} – {a['title']}", a["title"]) for a in albums + singles]
    # the title itself among the artist's (the album list can be cut to 10 when Spotify limits it)
    artist_id = artist_uri.rsplit(":", 1)[-1]
    for kind in ("album", "track"):
        for i in _search(lib.client, f'{title} artist:"{artist_name}"', kind):
            if artist_id in {a.get("id") for a in i.get("artists") or [] if a}:
                cands.append((kind, i["uri"], f"{artist_name} – {i.get('name', '')}", i.get("name", "")))
    cands += [("track", t["uri"], f"{artist_name} – {t['title']}", t["title"]) for t in lib.artist_tracks(entry)]
    for e in own_music().get("tracks") or []:
        if e.get("artist", "").casefold() == artist_name.casefold():
            cands.append(("track", e["uri"], f"{artist_name} – {e['name']}", e["name"]))
    for e in own_music().get("lists") or []:
        if e.get("artist", "").casefold() == artist_name.casefold():
            cands.append(("playlist", e["uri"], e.get("full") or e["name"], e["name"]))
    heard = re.sub(r"^(?:albumet|skivan|plattan|låten|spela|spela albumet|spela låten)\s+", "", title)
    scored = [(_sim(heard, t) + (0.02 if k == "playlist" else 0), k, u, n) for k, u, n, t in cands]
    return max(scored, default=(0.0, "", "", ""))


def music_sentence(d, kind, artist, title):
    """Plays what was meant, asks about a half-close one, or says it wasn't found. → (shown, spoken)"""
    global _pending, _asked, _by, _missed
    _asked = 0.0
    by, _by = _by, None
    answer = kind == "svar"
    kind = "" if answer else kind
    if by and answer and time.monotonic() - by[2] < 60:      # the answer to "Vilket album …?"
        if NEWEST.match(title):          # "Vilket album …?" – "senaste"
            sw = d._spotify()
            a = newest_album(sw.Library(sw.Client()), by[0], by[1])
            if a:
                said = _plain(d.play_uri("album", a["uri"], f"{by[1]} – {a['title']}", CONVERSATION))
                return said, ("Spelar albumet." if said.startswith("Spelar ") else True)
        if ANY.match(title):
            said = _plain(d.play_uri("artist", by[0], by[1], CONVERSATION))
            return said, ("Spelar artisten." if said.startswith("Spelar ") else True)
        try:
            score, k, uri, name = by_artist(by[0], by[1], title)
        except Exception as e:  # noqa: BLE001
            return f"Spotify svarade inte: {e}", True
        if score >= MAYBE:
            if len(by) > 3 and by[3]:     # "Menade du X? Vilket album …" answered with an album = yes to X
                learn(by[3], "artist", by[0], by[1])
            said = _plain(d.play_uri(k, uri, name, CONVERSATION))
            return said, (f"Spelar {LABEL[k]}." if said.startswith("Spelar ") else True)
        _by, _asked = (by[0], by[1], time.monotonic()) + tuple(by[3:]), time.monotonic()
        return (f"Jag hittar inget av {by[1]} som heter \"{title}\". Säg det igen, eller \"vad som helst\".",
                "Det hittade jag inte. Säg det igen, eller vad som helst.")
    heard = f"{artist} – {title}" if artist and title else (artist or title)
    key = _heard_key(artist, title)
    if not d._spotify().load().get("refreshToken"):
        return "GoblinAmp är inte inloggat på Spotify – logga in i GoblinAmp först (⋯ → Logga in).", True
    known = learned().get(key)
    if known and (known["kind"] != "artist" or kind in ("", "artist")):    # learned: no asking
        what, k, uri, name = "play", known["kind"], known["uri"], known["name"]
        learn(key, k, uri, name)                                             # counted
        global _used
        _used = (key, time.monotonic())
    else:
        try:
            what, k, uri, name = find_music(kind, artist, title)
        except Exception as e:  # noqa: BLE001 – no network, Spotify down
            return f"Spotify svarade inte: {e}", True
    if k == "artist" and kind == "" and what in ("play", "ask"):    # "Spela Zakk Wylde" → which one?
        if what == "play":
            _learn_missed("artist", uri, name)
        _by = (uri, name, time.monotonic(), key if what == "ask" else "")
        _asked = time.monotonic()
        sure = "" if what == "play" else "Menade du "
        return (f"{sure}{name}{'?' if sure else '.'} Vilket album eller vilken låt? (\"Vad som helst\" = blanda artisten.)",
                f"{sure}{_spoken(name)}{'?' if sure else '.'} Vilket album eller vilken låt?")
    if what == "play":
        _learn_missed(k, uri, name)
        said = _plain(d.play_uri(k, uri, name, CONVERSATION))
        # her English is worse than the user's (4 Nov): titles only in the box
        return said, (f"Spelar {LABEL[k]}." if said.startswith("Spelar ") else True)
    if what == "ask":
        _pending = (k, uri, name, time.monotonic(), key)
        _asked = _pending[3]
        return (f"Jag är inte säker på vad jag hörde (\"{heard}\"). Menade du {LABEL[k]} {name}? "
                f"Säg ja så spelar jag det.", f"Menade du {_spoken(name)}? Säg ja.")
    _asked = time.monotonic()
    _missed = (key, time.monotonic())         # the name said next, when it plays, is what this meant
    return (f"Jag hittade inte \"{heard}\" på Spotify. Säg namnet igen.",
            "Det hittade jag inte på Spotify. Säg namnet igen.")


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
    if command == "lag":
        meter = Path(__file__).resolve().parents[3] / "libexec/goblincakes-lagmeter"   # /usr/libexec (or the repo's)
        subprocess.Popen([str(meter), "mark", "laggar nu (röst)"], stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
        return "Jag mäter laggen nu. Fråga mig i Goblin AI efteråt, så går vi igenom det.", True
    if command == "pull":
        try:
            url, said = latest_pull()
        except Exception as e:  # noqa: BLE001 – no report, no network, not signed in to Warcraft Logs
            return f"Jag hittar ingen pull på Warcraft Logs. {e}".strip(), True
        subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
        return said, True
    d = _desktop()
    if command == "play" and not d.players():   # "Starta GoblinAmp" with nothing running (5 Nov)
        subprocess.Popen(["gtk-launch", "goblin-amp"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
        return "Startar GoblinAmp.", True
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
        return music_sentence(d, *arg)
    if command in ("yes", "no"):
        global _pending, _asked, _by, _missed, _used
        pending, _pending = _pending, None
        if command == "no" and not pending and _used and time.monotonic() - _used[1] < 60:
            forget_learned(_used[0])              # learned wrong ("ja" to a wrong guess) – away, and ask again
            _missed, _used, _by, _asked = (_used[0], time.monotonic()), None, None, time.monotonic()
            print(f"Glömde: \"{_missed[0]}\"", flush=True)
            return "Okej, det glömmer jag. Säg namnet igen.", True
        if not pending and _by and time.monotonic() - _by[2] < 60:   # "Menade du Strikkland? Vilket album …" – "nej"
            if command == "no":
                if len(_by) > 3 and _by[3]:
                    _missed = (_by[3], time.monotonic())
                _by, _asked = None, time.monotonic()
                return "Okej. Säg namnet igen.", True
            if len(_by) > 3 and _by[3]:
                learn(_by[3], "artist", _by[0], _by[1])          # "ja" – that artist
            _by = (_by[0], _by[1], time.monotonic())
            return f"Vilket album eller vilken låt av {_by[1]}? Eller \"vad som helst\".", "Vilket album eller vilken låt?"
        if not pending or time.monotonic() - pending[3] > 60:
            return ("", False) if command == "no" else ("Ja till vad? Jag har inte frågat något.", True)
        if command == "no":
            _asked = time.monotonic()        # the name said next is the answer
            _missed = (pending[4], time.monotonic())
            return "Okej. Säg namnet igen, gärna långsamt.", True
        k, uri, name, _when, heard = pending
        learn(heard, k, uri, name)
        said = _plain(d.play_uri(k, uri, name, CONVERSATION))
        return said, (f"Spelar {LABEL[k]}." if said.startswith("Spelar ") else True)
    return "", False


if __name__ == "__main__":
    import sys
    for a in sys.argv[1:] or ["starta vov", "ge mig senaste fullen", "spela albumet master of puppets med metallica"]:
        print(f"{a!r:55} → {match_all(a)}")
