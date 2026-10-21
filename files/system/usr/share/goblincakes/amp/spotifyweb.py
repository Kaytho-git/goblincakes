"""GoblinAmp's playlist (21 Oct, the user's wish – Winamp's PL window): Spotify's Web API with the
user's own app (developer.spotify.com → Create app, the Redirect URI below, Web API) – MPRIS only
tells what is playing now, not the lists or the queue. Only the standard library.

Sign-in: Authorization Code with PKCE, so only the Client ID is needed (no secret); the browser
comes back to 127.0.0.1:8898. Kept in ~/.config/goblincakes/spotify.json (600): clientId,
refreshToken (Spotify may hand out a new one at every refresh – kept), the access token for an hour.

Spotify's February 2026 rules for apps in Development Mode: the owner needs Premium, at most five
users, fewer endpoints – a playlist's tracks only for lists the user made or collaborates on
(others' give 403: the list can still be played as a whole), and playlist entries are under
"item" (was "track"); both names are read. Queries are kept few (the lists once, a list's
tracks when it is opened, cached until the list's snapshot changes).

Search and own lists (21 Oct, the user's yes to the proposals): /search gives at most 10 per type
and call in Development Mode (more with offset); new lists with POST /me/playlists, the tracks
with /playlists/{id}/items (add, remove by uri, move a range), a list away with DELETE
/me/library (Spotify keeps it a while – it can be brought back on spotify.com → Account →
Recover playlists). The modify scopes came with this – an older sign-in has to be redone once.
"""
import base64
import hashlib
import http.server
import json
import os
import secrets
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "goblincakes/spotify.json"
PORT = 8898
REDIRECT = f"http://127.0.0.1:{PORT}/callback"
API = os.environ.get("GOBLINCAKES_SPOTIFY_API", "https://api.spotify.com/v1")
ACCOUNTS = os.environ.get("GOBLINCAKES_SPOTIFY_ACCOUNTS", "https://accounts.spotify.com")
SCOPES = ("playlist-read-private playlist-read-collaborative user-library-read "
          "user-read-playback-state user-modify-playback-state user-read-currently-playing "
          "playlist-modify-private playlist-modify-public user-library-modify user-follow-modify")
EDIT_SCOPE = "playlist-modify-private"
DASHBOARD = "https://developer.spotify.com/dashboard"
LIKED = "liked"     # the list id of "Gillade låtar"
QUEUE = "queue"     # the list id of "Kö"
SEARCH = "search"   # the list id of "Sök i hela Spotify"
SEARCH_LIMIT = 10   # per type and call – the most Development Mode allows
PAGE_LIMIT = 1000   # tracks read from one list at most (pages of 100 – Spotify counts every call)


class SpotifyError(Exception):
    pass


def load():
    try:
        return json.loads(CONFIG.read_text())
    except (OSError, ValueError):
        return {}


def save(data):
    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    tmp = CONFIG.with_suffix(".tmp")
    with open(os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "w") as f:
        json.dump(data, f)
    os.replace(tmp, CONFIG)


def _token_request(fields):
    body = urllib.parse.urlencode(fields).encode()
    req = urllib.request.Request(ACCOUNTS + "/api/token", data=body,
                                 headers={"Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        try:
            err = json.loads(e.read()).get("error", "")
        except ValueError:
            err = ""
        if err == "invalid_grant":
            raise SpotifyError("Inloggningen har gått ut – logga in igen") from None
        if err == "invalid_client":
            raise SpotifyError("Spotify känner inte igen Client ID:t – kolla det i din app på developer.spotify.com") from None
        raise SpotifyError(f"Spotify svarade {e.code} vid inloggningen") from None
    except (urllib.error.URLError, OSError) as e:
        raise SpotifyError(f"Spotify nås inte ({getattr(e, 'reason', e)})") from None


def login(client_id, open_url, timeout=300):
    """The browser to Spotify, back to 127.0.0.1:8898 with a code → a refresh token. Returns the name."""
    client_id = client_id.strip()
    if not client_id:
        raise SpotifyError("Skriv in Client ID först")
    verifier = secrets.token_urlsafe(64)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).decode().rstrip("=")
    state = secrets.token_urlsafe(16)
    got = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            parsed = urllib.parse.urlparse(self.path)
            q = urllib.parse.parse_qs(parsed.query)
            if parsed.path != "/callback" or q.get("state", [""])[0] != state:
                self.send_response(404)
                self.end_headers()
                return
            got["code"] = q.get("code", [""])[0]
            got["error"] = q.get("error", [""])[0]
            page = ("Klart – du kan stänga fliken och gå tillbaka till GoblinAmp." if got["code"]
                    else "Inloggningen avbröts.")
            body = ("<!doctype html><meta charset=utf-8><title>GoblinAmp</title>"
                    "<body style='background:#0E1420;color:#E6ECF5;font-family:sans-serif;padding:40px'>"
                    f"<h2>{page}</h2>").encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    try:
        server = http.server.HTTPServer(("127.0.0.1", PORT), Handler)
    except OSError:
        raise SpotifyError(f"Port {PORT} är upptagen – stäng det som använder den och försök igen") from None
    url = ACCOUNTS + "/authorize?" + urllib.parse.urlencode({
        "client_id": client_id, "response_type": "code", "redirect_uri": REDIRECT, "scope": SCOPES,
        "code_challenge_method": "S256", "code_challenge": challenge, "state": state})
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        open_url(url)
        end = time.time() + timeout
        while "code" not in got and time.time() < end:
            time.sleep(0.2)
    finally:
        server.shutdown()
        server.server_close()
    if not got.get("code"):
        raise SpotifyError("Inloggningen avbröts" if "code" in got else "Ingen inloggning inom 5 minuter")
    tok = _token_request({"client_id": client_id, "grant_type": "authorization_code", "code": got["code"],
                          "redirect_uri": REDIRECT, "code_verifier": verifier})
    data = {"clientId": client_id, "refreshToken": tok.get("refresh_token", ""),
            "accessToken": tok.get("access_token", ""), "expires": time.time() + tok.get("expires_in", 3600) - 60,
            "scope": tok.get("scope", "")}
    save(data)
    me = Client().get("/me")
    data["user"] = me.get("id", "")
    data["name"] = me.get("display_name") or me.get("id", "")
    save(data)
    return data["name"]


def can_edit():
    """Signed in with the scopes for changing lists (sign-ins before 21 Oct lack them)."""
    return EDIT_SCOPE in load().get("scope", "").split()


def logout():
    data = load()
    for key in ("refreshToken", "accessToken", "expires", "user", "name", "scope"):
        data.pop(key, None)
    save(data)


class Client:
    """A signed-in Spotify, the token refreshed when it is old."""

    def __init__(self):
        self.lock = threading.Lock()

    def token(self):
        with self.lock:
            data = load()
            if not data.get("refreshToken"):
                raise SpotifyError("Inte inloggad")
            if data.get("accessToken") and data.get("expires", 0) > time.time():
                return data["accessToken"]
            tok = _token_request({"client_id": data["clientId"], "grant_type": "refresh_token",
                                  "refresh_token": data["refreshToken"]})
            data["accessToken"] = tok["access_token"]
            data["expires"] = time.time() + tok.get("expires_in", 3600) - 60
            if tok.get("refresh_token"):
                data["refreshToken"] = tok["refresh_token"]
            if tok.get("scope"):
                data["scope"] = tok["scope"]
            save(data)
            return data["accessToken"]

    def request(self, method, path, query=None, body=None):
        url = (path if path.startswith("http") else API + path)
        if query:
            url += ("&" if "?" in url else "?") + urllib.parse.urlencode(query)
        data = json.dumps(body).encode() if body is not None else (b"" if method in ("PUT", "POST") else None)
        req = urllib.request.Request(url, data=data, method=method, headers={
            "Authorization": "Bearer " + self.token(), "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=20) as r:
                raw = r.read()
                return json.loads(raw) if raw.strip() else {}
        except urllib.error.HTTPError as e:
            try:
                message = (json.loads(e.read()).get("error") or {}).get("message", "")
            except (ValueError, AttributeError):
                message = ""
            if e.code == 401:
                with self.lock:
                    data = load()
                    data.pop("accessToken", None)
                    save(data)
                raise SpotifyError("Spotify godkände inte inloggningen – försök igen") from None
            if e.code == 403:
                raise SpotifyError(f"403:{message}") from None
            if e.code == 404:
                raise SpotifyError(f"404:{message}") from None
            if e.code == 429:
                wait = e.headers.get("Retry-After", "")
                raise SpotifyError("Spotify vill att vi väntar en stund" + (f" ({wait} s)" if wait else "")) from None
            raise SpotifyError(f"Spotify svarade {e.code}{': ' + message if message else ''}") from None
        except (urllib.error.URLError, OSError) as e:
            raise SpotifyError(f"Spotify nås inte ({getattr(e, 'reason', e)})") from None

    def get(self, path, query=None):
        return self.request("GET", path, query)


def track_row(item):
    """A track (or episode) as GoblinAmp's row."""
    if not item:
        return None
    artists = item.get("artists") or ([item["show"]] if item.get("show") else [])
    return {"uri": item.get("uri", ""), "title": item.get("name", ""),
            "artist": ", ".join(a.get("name", "") for a in artists if a),
            "seconds": round((item.get("duration_ms") or 0) / 1000),
            "local": bool(item.get("is_local"))}


def list_entry(p, me):
    """A playlist object as GoblinAmp's list row."""
    total = (p.get("items") or p.get("tracks") or {}).get("total", 0)
    owner = (p.get("owner") or {}).get("id", "")
    return {"id": p.get("id", ""), "name": p.get("name", ""), "uri": p.get("uri", ""),
            "count": total, "snapshot": p.get("snapshot_id", ""),
            "mine": owner == me or bool(p.get("collaborative")), "own": owner == me,
            "owner": (p.get("owner") or {}).get("display_name") or owner}


def _artists(item):
    return ", ".join(a.get("name", "") for a in item.get("artists") or [] if a)


class Library:
    """The lists, their tracks (cached by snapshot), the queue, playing."""

    def __init__(self, client=None):
        self.client = client or Client()
        self.cache = {}  # list id → (snapshot, rows)

    def lists(self):
        me = load().get("user", "")
        out = [{"id": SEARCH, "name": "Sök i hela Spotify", "special": True},
               {"id": QUEUE, "name": "Kö – det som spelas härnäst", "special": True},
               {"id": LIKED, "name": "Gillade låtar", "special": True, "uri": f"spotify:user:{me}:collection"}]
        url, seen = "/me/playlists", 0
        query = {"limit": 50}
        while url and seen < 500:
            page = self.client.get(url, query)
            query = None
            for p in page.get("items") or []:
                if not p:
                    continue
                out.append(list_entry(p, me))
                seen += 1
            url = page.get("next")
        return out

    def tracks(self, entry):
        """The rows of a list: [{"uri", "title", "artist", "seconds"}]. Raises SpotifyError."""
        list_id = entry["id"]
        if list_id == QUEUE:
            page = self.client.get("/me/player/queue")
            rows = [track_row(page.get("currently_playing"))] + [track_row(i) for i in page.get("queue") or []]
            return [r for r in rows if r]
        cached = self.cache.get(list_id)
        if cached and list_id != LIKED and cached[0] == entry.get("snapshot"):
            return cached[1]
        rows = []
        if entry.get("album"):   # an album opened from the search
            url, query = f"/albums/{entry['uri'].rsplit(':', 1)[-1]}/tracks", {"limit": 50}
        elif list_id == LIKED:
            url, query = "/me/tracks", {"limit": 50}
        else:
            url, query = f"/playlists/{list_id}/items", {"limit": 100, "additional_types": "track,episode"}
        try:
            while url and len(rows) < PAGE_LIMIT:
                page = self.client.get(url, query)
                query = None
                for entry_ in page.get("items") or []:
                    row = track_row(entry_.get("item") or entry_.get("track")
                                    or (entry_ if entry.get("album") else None))
                    if row:
                        rows.append(row)
                url = page.get("next")
        except SpotifyError as e:
            if str(e).startswith("404:") and list_id != LIKED:  # before Spotify's change: …/tracks
                return self._old_tracks(list_id)
            if str(e).startswith("403:"):
                raise SpotifyError("Spotify visar inte låtarna i listor som någon annan har gjort för egna "
                                   "appar (sedan februari 2026) – tryck ▶ Spela listan för att spela hela.") from None
            raise
        self.cache[list_id] = (entry.get("snapshot"), rows)
        return rows

    def _old_tracks(self, list_id):
        rows, url, query = [], f"/playlists/{list_id}/tracks", {"limit": 100}
        while url and len(rows) < PAGE_LIMIT:
            page = self.client.get(url, query)
            query = None
            rows += [r for r in (track_row(e.get("track") or e.get("item")) for e in page.get("items") or []) if r]
            url = page.get("next")
        return rows

    def device(self, start_app=None, wait=15):
        """The Spotify app's own device on this computer (not a web player) – started if needed."""
        def find():
            devices = self.client.get("/me/player/devices").get("devices") or []
            apps = [d for d in devices if d.get("type") == "Computer" and "web player" not in d.get("name", "").lower()]
            active = [d for d in apps if d.get("is_active")]
            return (active or apps or [None])[0]
        found = find()
        if found is None and start_app:
            start_app()
            end = time.time() + wait
            while found is None and time.time() < end:
                time.sleep(1.5)
                found = find()
        if found is None:
            raise SpotifyError("Hittar inte Spotify-appen – starta Spotify och försök igen")
        return found["id"]

    def play(self, entry, rows=None, index=None, start_app=None):
        """Double-click: a track in its list (from there on), or a whole list."""
        device = self.device(start_app)
        if entry["id"] == SEARCH:
            row = rows[index]
            if row.get("kind") in ("album", "playlist"):
                body = {"context_uri": row["uri"]}
            else:   # a found track, and the found tracks after it
                tracks = [r for r in rows if r.get("kind") == "track"]
                body = {"uris": [r["uri"] for r in tracks[tracks.index(row):]]}
        elif entry["id"] == LIKED or not entry.get("uri"):
            if not rows:
                raise SpotifyError("Inget att spela")
            start = index or 0
            body = {"uris": [r["uri"] for r in rows[start:start + 100] if not r.get("local")]}
        else:
            body = {"context_uri": entry["uri"]}
            if index is not None and rows:
                body["offset"] = {"uri": rows[index]["uri"]}
        self.client.request("PUT", "/me/player/play", {"device_id": device}, body)

    # ── Search ──

    def search(self, query, offset=0):
        """Tracks, albums and lists for the words; with offset only more tracks.
        Rows: kind track/album/playlist, plus "more" when Spotify has further tracks."""
        query = query.strip()
        if not query:
            return []
        types = "track" if offset else "track,album,playlist"
        page = self.client.get("/search", {"q": query, "type": types, "limit": SEARCH_LIMIT, "offset": offset})
        rows = []
        tracks = page.get("tracks") or {}
        for item in tracks.get("items") or []:
            row = track_row(item)
            if row:
                row["kind"] = "track"
                rows.append(row)
        for item in (page.get("albums") or {}).get("items") or []:
            if item:
                rows.append({"kind": "album", "uri": item.get("uri", ""), "title": item.get("name", ""),
                             "artist": _artists(item), "count": item.get("total_tracks", 0), "seconds": 0})
        for item in (page.get("playlists") or {}).get("items") or []:
            if item:   # Spotify gives null for lists it hides
                rows.append({"kind": "playlist", "uri": item.get("uri", ""), "title": item.get("name", ""),
                             "artist": (item.get("owner") or {}).get("display_name", ""),
                             "count": (item.get("items") or item.get("tracks") or {}).get("total", 0), "seconds": 0})
        if tracks.get("next"):
            rows.append({"kind": "more", "offset": offset + SEARCH_LIMIT, "uri": "", "title": "", "artist": "", "seconds": 0})
        return rows

    @staticmethod
    def album_entry(row):
        """A found album as an open list: its tracks, ◀ back to the search."""
        return {"id": "album:" + row["uri"].rsplit(":", 1)[-1], "uri": row["uri"], "album": True, "special": True,
                "name": (row["artist"] + " – " if row.get("artist") else "") + row["title"], "count": row.get("count", 0)}

    def enqueue(self, uri, start_app=None):
        self.client.request("POST", "/me/player/queue", {"uri": uri, "device_id": self.device(start_app)})

    # ── Own lists ──

    def _check_edit(self):
        if not can_edit():
            raise SpotifyError("GoblinAmp behöver lov att ändra dina listor – Logga ut (⋯) och logga in igen en gång.")

    def _forget(self, list_id):
        self.cache.pop(list_id, None)

    def create(self, name):
        """A new private list → its list row."""
        self._check_edit()
        p = self.client.request("POST", "/me/playlists", body={"name": name, "public": False})
        return list_entry(p, load().get("user", ""))

    def add(self, list_id, uris):
        """Last in the list. Returns the new snapshot."""
        self._check_edit()
        uris = [u for u in uris if u.startswith("spotify:") and ":local:" not in u]
        if not uris:
            raise SpotifyError("Lokala filer kan inte läggas i Spotify-listor")
        snapshot = ""
        for i in range(0, len(uris), 100):
            snapshot = self.client.request("POST", f"/playlists/{list_id}/items",
                                           body={"uris": uris[i:i + 100]}).get("snapshot_id", "")
        self._forget(list_id)
        return snapshot

    def remove(self, list_id, uris, snapshot=""):
        """Every copy of the tracks out of the list."""
        self._check_edit()
        body = {"items": [{"uri": u} for u in uris[:100]]}
        if snapshot:
            body["snapshot_id"] = snapshot
        self._forget(list_id)
        return self.client.request("DELETE", f"/playlists/{list_id}/items", body=body).get("snapshot_id", "")

    def move(self, list_id, start, before, snapshot=""):
        """The row at start to before (the index it lands in front of, as before the move)."""
        self._check_edit()
        body = {"range_start": start, "insert_before": before, "range_length": 1}
        if snapshot:
            body["snapshot_id"] = snapshot
        self._forget(list_id)
        return self.client.request("PUT", f"/playlists/{list_id}/items", body=body).get("snapshot_id", "")

    def rename(self, list_id, name):
        self._check_edit()
        self.client.request("PUT", f"/playlists/{list_id}", body={"name": name})

    def delete(self, list_id):
        """Off the user's lists (Spotify's "Remove from library"; recoverable on spotify.com)."""
        self._check_edit()
        self.client.request("DELETE", "/me/library", {"uris": f"spotify:playlist:{list_id}"})
        self._forget(list_id)
