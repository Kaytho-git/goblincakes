"""Last.fm for GoblinAmp's GENRER tab: what is popular in a genre (tag), what is like a track.

Spotify closed its recommendations for new own apps (Nov 2024), so the suggestions come from
Last.fm's open API with the user's own free API key (last.fm/api/account/create); the tracks
are then looked up in Spotify and played there. Only the standard library.
"""

import json
import os
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API = os.environ.get("GOBLINCAKES_LASTFM_API", "https://ws.audioscrobbler.com/2.0/")
KEY_FILE = Path.home() / ".config/goblincakes/lastfm.json"
CREATE_URL = "https://www.last.fm/api/account/create"


class LastfmError(Exception):
    pass


def key():
    try:
        return json.loads(KEY_FILE.read_text()).get("key", "")
    except (OSError, ValueError):
        return ""


def set_key(value):
    """Kept only when Last.fm accepts it. Empty = forget it."""
    value = value.strip()
    if not value:
        KEY_FILE.unlink(missing_ok=True)
        return
    call("tag.getinfo", api_key=value, tag="rock")
    KEY_FILE.parent.mkdir(parents=True, exist_ok=True)
    KEY_FILE.write_text(json.dumps({"key": value}))
    KEY_FILE.chmod(0o600)


def call(method, api_key=None, **params):
    params.update(method=method, api_key=api_key or key(), format="json")
    if not params["api_key"]:
        raise LastfmError("Ingen Last.fm-nyckel – lägg in den under ⋯ → Last.fm-nyckel…")
    request = urllib.request.Request(API + "?" + urllib.parse.urlencode(params),
                                     headers={"User-Agent": "GoblinAmp/1 (GOBLINCAKES)"})
    try:
        with urllib.request.urlopen(request, timeout=15) as reply:
            data = json.loads(reply.read().decode())
    except urllib.error.HTTPError as e:
        try:
            data = json.loads(e.read().decode())
        except ValueError:
            raise LastfmError(f"Last.fm svarade {e.code}") from None
    except (urllib.error.URLError, OSError, ValueError):
        raise LastfmError("Når inte Last.fm – är datorn ute på nätet?") from None
    if "error" in data:
        if data["error"] in (10, 26):
            raise LastfmError("Last.fm-nyckeln stämmer inte – kolla den under ⋯ → Last.fm-nyckel…")
        if data["error"] == 29:
            raise LastfmError("Last.fm vill att vi väntar en stund – försök igen om en minut")
        if data["error"] == 6:   # no such tag/track/artist
            return {}
        raise LastfmError(f"Last.fm: {data.get('message', data['error'])}")
    return data


def _pairs(tracks):
    out = []
    for t in tracks or []:
        artist = t.get("artist") or {}
        name = artist.get("name") if isinstance(artist, dict) else artist
        if name and t.get("name"):
            out.append((name, t["name"]))
    return out


def tag_tracks(tag, limit=20):
    """The genre's most played tracks: [(artist, title)]."""
    return _pairs((call("tag.gettoptracks", tag=tag, limit=limit).get("tracks") or {}).get("track"))


def similar_tracks(artist, title, limit=20):
    return _pairs((call("track.getsimilar", artist=artist, track=title, autocorrect=1,
                        limit=limit).get("similartracks") or {}).get("track"))


def similar_artists(artist, limit=8):
    found = (call("artist.getsimilar", artist=artist, autocorrect=1, limit=limit).get("similarartists") or {})
    return [a["name"] for a in found.get("artist") or [] if a.get("name")]
