"""Goblin AI's ```wiki tool (30 Oct, the user's wish: "wikipedia verktyg, det är en bra grej att ha"): an encyclopedia
and a dictionary from Wikipedia and Wiktionary's open API (no key, no account). Swedish first, English when Swedish
has nothing. Only the beginning of an article and the names of its parts, or one part asked for – a whole article
would fill a local model's memory (the web pages did in the add-on repair the same night). Only the standard library.

    python3 wikitools.py <ämne>              the beginning, the first part, the parts' names and the link
    python3 wikitools.py "<ämne> ; <del>"    one part (Historia, Biologi …), or what it says about a word (skidor)
    python3 wikitools.py "en: <topic>"       English Wikipedia
    python3 wikitools.py "ord: <ord>"        Wiktionary (Swedish)"""

import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

# Wikimedia asks for a User-Agent that says who calls (no e-mail address: the repo's page)
AGENT = "GOBLINCAKES-GoblinAI/1.0 (https://github.com/Kaytho-git/goblincakes)"
INTRO_MAX = 1800
PART_MAX = 3500
FIRST_MAX = 1800
WORD_MAX = 2500


# A part asked for in Swedish, when only the English article has it ("bågskytte ; Historia" → History)
PART_NAMES = {"historia": "History", "historik": "History", "etymologi": "Etymology", "biologi": "Biology",
              "geografi": "Geography", "klimat": "Climate", "befolkning": "Demographics", "ekonomi": "Economy",
              "kultur": "Culture", "politik": "Politics", "utrustning": "Equipment", "regler": "Rules",
              "barndom": "Early life", "uppväxt": "Early life", "död": "Death", "karriär": "Career",
              "teknik": "Technique", "utbredning": "Distribution", "beskrivning": "Description", "användning": "Uses",
              "tillverkning": "Manufacture", "typer": "Types", "sport": "Sport", "tävling": "Competition"}


class WikiError(Exception):
    pass


def _api(site, **params):
    params.update(format="json", formatversion="2")
    url = f"https://{site}/w/api.php?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": AGENT})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.loads(r.read())
    except (OSError, ValueError) as e:
        raise WikiError(f"{site} svarade inte ({e})") from e


def _page_url(site, title):
    return f"https://{site}/wiki/" + urllib.parse.quote(title.replace(" ", "_"))


def find(site, query):
    """The best article's title for the words, or "". The exact title first (redirects followed), then the search."""
    data = _api(site, action="query", titles=query, redirects=1)
    page = (data.get("query", {}).get("pages") or [{}])[0]
    if page.get("title") and not page.get("missing") and not page.get("invalid"):
        return page["title"]
    hits = _api(site, action="query", list="search", srsearch=query, srlimit=1).get("query", {}).get("search") or []
    return hits[0]["title"] if hits else ""


def text_of(site, title):
    """The article as plain text, the parts marked "== Name ==" (TextExtracts)."""
    data = _api(site, action="query", prop="extracts", explaintext=1, exsectionformat="wiki", titles=title, redirects=1)
    page = (data.get("query", {}).get("pages") or [{}])[0]
    return page.get("title", title), page.get("extract") or ""


def parts(text):
    """[(name, level, text)] – the beginning has the name ""."""
    out, name, level, rows = [], "", 1, []
    for row in text.splitlines():
        m = re.match(r"^(={2,6})\s*(.+?)\s*\1\s*$", row)
        if m:
            out.append((name, level, "\n".join(rows).strip()))
            name, level, rows = m.group(2), len(m.group(1)), []
        else:
            rows.append(row)
    out.append((name, level, "\n".join(rows).strip()))
    return out


def _cut(text, limit):
    if len(text) <= limit:
        return text
    end = text.rfind(". ", 0, limit)
    return text[:end + 1 if end > limit // 2 else limit] + " …"


def _disambiguation(text):
    return bool(re.search(r"\bkan (?:avse|syfta på)\b|\bmay (?:refer|also refer) to\b", text[:400]))


def article(query):
    """(text for the AI, [sources])."""
    topic, _, want = (x.strip() for x in query.partition(";"))
    sites = ["sv.wikipedia.org", "en.wikipedia.org"]
    if re.match(r"^(?:en|eng|engelska)\s*:", topic, re.I):
        topic, sites = topic.split(":", 1)[1].strip(), ["en.wikipedia.org"]
    if not topic:
        raise WikiError("skriv vad du vill slå upp")
    for site in sites:
        title = find(site, topic)
        if not title:
            continue
        title, text = text_of(site, title)
        if not text.strip():
            continue
        url = _page_url(site, title)
        lang = "svenska" if site.startswith("sv") else "engelska"
        all_parts = parts(text)
        names = [n for n, level, t in all_parts if n and t and level == 2
                 and n.lower() not in ("referenser", "källor", "noter", "externa länkar", "se även", "litteratur",
                                       "references", "external links", "see also", "notes", "further reading")]
        out = [f"Wikipedia på {lang}: {title} ({url})"]
        if want:
            hit = next((p for p in all_parts if p[0] and p[0].lower() == want.lower()), None) or next(
                (p for p in all_parts if p[0] and want.lower() in p[0].lower()), None)
            if hit:
                # the part with its sub-parts (=== under it), up to the next part on the same level
                i = all_parts.index(hit)
                body = [hit[2]] + [f"{n}:\n{t}" for n, level, t in
                                   _until_level(all_parts[i + 1:], hit[1]) if t]
                out.append(f"\nDelen \"{hit[0]}\":\n" + _cut("\n\n".join(b for b in body if b), PART_MAX))
            elif mentions(all_parts, want):
                found = mentions(all_parts, want)
                out.append(f"\nDet artikeln säger om \"{want}\" ({len(found)} {'stycke' if len(found) == 1 else 'stycken'}):\n"
                           + _cut("\n\n".join(f"[{n or 'Inledningen'}] {t}" for n, t in found), PART_MAX))
            else:
                other = _english_title(title) if site.startswith("sv") else ""
                if other:  # a short Swedish article: the same subject in English has the part more often
                    text_en, sources_en = article(f"en: {other} ; {PART_NAMES.get(want.lower(), want)}")
                    if "finns inte i artikeln" not in text_en:
                        return (f"Wikipedia på svenska: {title} ({url}) har ingen del \"{want}\" – den engelska "
                                f"artikeln om samma sak:\n" + text_en,
                                [{"title": f"Wikipedia: {title}", "url": url, "content": ""}] + sources_en)
                    listed = re.search(r"Artikelns delar[^:]*: (.+)$", text_en, re.M)
                    if listed:
                        out.append(f"\nDen engelska artikeln \"{other}\" har delarna (slå upp en med "
                                   f"`en: {other} ; <del>`): {listed.group(1)}")
                out.append(f"\nDelen \"{want}\" finns inte i artikeln. Början:\n" + _cut(all_parts[0][2], INTRO_MAX))
        else:
            intro = all_parts[0][2]
            if _disambiguation(intro):
                out.append("\nOrdet har flera betydelser – sidan listar dem:\n" + _cut(intro, INTRO_MAX))
            else:
                out.append("\n" + _cut(intro, INTRO_MAX))
                # and the first part (the user 30 Oct: "inledning och första avsnittet, sen länken – så kan jag
                # fortsätta själv")
                first = next(((n, t) for n, level, t in all_parts[1:] if n in names and t), None)
                if first:
                    out.append(f"\nFörsta delen, \"{first[0]}\":\n" + _cut(first[1], FIRST_MAX))
        if names:
            out.append("\nArtikelns delar (slå upp en med `" + topic + " ; <del>`): " + ", ".join(names[:25]))
        out.append(f"\nHela artikeln: {url}")
        return "\n".join(out), [{"title": f"Wikipedia: {title}", "url": url, "content": ""}]
    return f"Ingen artikel om \"{topic}\" på Wikipedia (svenska eller engelska).", []


def mentions(all_parts, want, most=4):
    """[(part, paragraph)] that have all of want's words (Swedish endings: "skidor" finds skidåkning, skida …);
    the first `most`. "Vad står det om Gustav Vasa och skidor?" → `Gustav Vasa ; skidor` (the user, 30 Oct)."""
    words = [w[:max(4, len(w) - 2)] for w in re.findall(r"\w{3,}", want.lower()) if w not in ("och", "med", "som", "the", "and")]
    if not words:
        return []
    out = []
    for name, _, text in all_parts:
        for para in (x.strip() for x in text.split("\n") if x.strip()):
            low = para.lower()
            if all(w in low for w in words):
                out.append((name, para))
                if len(out) >= most:
                    return out
    return out


def _english_title(title):
    """The English article on the same subject as a Swedish one (its language link), or ""."""
    data = _api("sv.wikipedia.org", action="query", prop="langlinks", lllang="en", titles=title)
    links = ((data.get("query", {}).get("pages") or [{}])[0]).get("langlinks") or []
    return links[0].get("title", "") if links else ""


def _until_level(rest, level):
    for p in rest:
        if p[1] <= level:
            break
        yield p


def word(query):
    """A word in Swedish Wiktionary: what it means, its forms (text for the AI, [sources])."""
    w = query.split(":", 1)[1].strip() if ":" in query else query.strip()
    site = "sv.wiktionary.org"
    title = find(site, w)
    if not title:
        return f"\"{w}\" finns inte i Wiktionary.", []
    title, text = text_of(site, title)
    url = _page_url(site, title)
    swedish = next((t for n, level, t in _sections_with_sub(parts(text)) if n.lower() == "svenska"), "")
    body = swedish or text
    return (f"Wiktionary: {title} ({url})\n\n" + _cut(re.sub(r"\n{3,}", "\n\n", body), WORD_MAX),
            [{"title": f"Wiktionary: {title}", "url": url, "content": ""}])


def _sections_with_sub(all_parts):
    """Each part with the parts under it joined in (Svenska → Substantiv → Böjningar …)."""
    for i, (n, level, t) in enumerate(all_parts):
        sub = [f"{m}:\n{u}" for m, _, u in _until_level(all_parts[i + 1:], level) if u]
        yield n, level, "\n\n".join([t] + sub).strip()


def lookup(query):
    query = " ".join(str(query).split())
    if re.match(r"^(?:ord|wiktionary|lexikon)\s*:", query, re.I):
        return word(query)
    return article(query)


if __name__ == "__main__":
    try:
        text, sources = lookup(" ".join(sys.argv[1:]))
    except WikiError as e:
        sys.exit(f"wiki: {e}")
    print(text)
    for s in sources:
        print("Källa:", s["url"])
