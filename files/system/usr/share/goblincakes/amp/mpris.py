"""GoblinAmp as an MPRIS player while it plays its own music (21 Oct): Plasma's media controls,
the Now playing widget, the media keys and goblin graph see it like any music player.

Gio (python3-gobject) rather than QtDBus: MPRIS wants exact D-Bus types (o, x, as, a{sv})
and PropertiesChanged. Qt runs GLib's main loop on Linux, so the callbacks come in the
window's thread. The name org.mpris.MediaPlayer2.goblinamp exists only while there is local
music (start()/stop()), so GoblinAmp doesn't show up twice while it steers Spotify.
"""
from gi.repository import Gio, GLib

NAME = "org.mpris.MediaPlayer2.goblinamp"
PATH = "/org/mpris/MediaPlayer2"
ROOT = "org.mpris.MediaPlayer2"
PLAYER = "org.mpris.MediaPlayer2.Player"
XML = """<node>
 <interface name="org.mpris.MediaPlayer2">
  <method name="Raise"/><method name="Quit"/>
  <property name="CanQuit" type="b" access="read"/>
  <property name="CanRaise" type="b" access="read"/>
  <property name="HasTrackList" type="b" access="read"/>
  <property name="Identity" type="s" access="read"/>
  <property name="DesktopEntry" type="s" access="read"/>
  <property name="SupportedUriSchemes" type="as" access="read"/>
  <property name="SupportedMimeTypes" type="as" access="read"/>
 </interface>
 <interface name="org.mpris.MediaPlayer2.Player">
  <method name="Next"/><method name="Previous"/><method name="Pause"/><method name="PlayPause"/>
  <method name="Stop"/><method name="Play"/>
  <method name="Seek"><arg direction="in" name="Offset" type="x"/></method>
  <method name="SetPosition"><arg direction="in" name="TrackId" type="o"/><arg direction="in" name="Position" type="x"/></method>
  <method name="OpenUri"><arg direction="in" name="Uri" type="s"/></method>
  <signal name="Seeked"><arg name="Position" type="x"/></signal>
  <property name="PlaybackStatus" type="s" access="read"/>
  <property name="LoopStatus" type="s" access="readwrite"/>
  <property name="Rate" type="d" access="readwrite"/>
  <property name="Shuffle" type="b" access="readwrite"/>
  <property name="Metadata" type="a{sv}" access="read"/>
  <property name="Volume" type="d" access="readwrite"/>
  <property name="Position" type="x" access="read"/>
  <property name="MinimumRate" type="d" access="read"/>
  <property name="MaximumRate" type="d" access="read"/>
  <property name="CanGoNext" type="b" access="read"/>
  <property name="CanGoPrevious" type="b" access="read"/>
  <property name="CanPlay" type="b" access="read"/>
  <property name="CanPause" type="b" access="read"/>
  <property name="CanSeek" type="b" access="read"/>
  <property name="CanControl" type="b" access="read"/>
 </interface>
</node>"""
MIME = ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-vorbis+ogg", "audio/opus", "audio/mp4",
        "audio/x-m4a", "audio/aac", "audio/x-wav", "audio/x-ms-wma", "audio/x-ape", "audio/x-wavpack"]


class Mpris:
    """player = the window's LocalPlayer: state() (dict), control(what), seek_to(seconds),
    set_volume(v), set_shuffle(b), set_loop(s), open_paths([…]); raise_window() and quit()."""

    def __init__(self, player, raise_window, quit_app):
        self.player, self.raise_window, self.quit_app = player, raise_window, quit_app
        self.info = Gio.DBusNodeInfo.new_for_xml(XML)
        self.bus = None
        self.owner = 0
        self.regs = []
        self.last = {}

    # ── own the name only while there is local music ──
    def start(self):
        if self.owner:
            return
        try:
            self.bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        except GLib.Error:
            return
        for iface in self.info.interfaces:
            self.regs.append(self.bus.register_object(PATH, iface, self._call, self._get, self._set))
        self.owner = Gio.bus_own_name_on_connection(self.bus, NAME, Gio.BusNameOwnerFlags.NONE, None, None)
        self.last = self._props()

    def stop(self):
        if not self.owner:
            return
        Gio.bus_unown_name(self.owner)
        self.owner = 0
        for reg in self.regs:
            self.bus.unregister_object(reg)
        self.regs = []

    # ── the properties ──
    def _props(self):
        s = self.player.state()
        length = int((s.get("length") or 0) * 1e6)
        meta = {"mpris:trackid": GLib.Variant("o", s.get("trackid") or "/org/goblincakes/amp/notrack")}
        if s.get("path"):
            meta["xesam:url"] = GLib.Variant("s", Gio.File.new_for_path(s["path"]).get_uri())
            meta["xesam:title"] = GLib.Variant("s", s.get("title") or "")
            if s.get("artist"):
                meta["xesam:artist"] = GLib.Variant("as", [s["artist"]])
            if s.get("album"):
                meta["xesam:album"] = GLib.Variant("s", s["album"])
            if length > 0:
                meta["mpris:length"] = GLib.Variant("x", length)
            if s.get("cover"):
                meta["mpris:artUrl"] = GLib.Variant("s", Gio.File.new_for_path(s["cover"]).get_uri())
        has = bool(s.get("path"))
        return {
            "PlaybackStatus": GLib.Variant("s", s.get("status") or "Stopped"),
            "LoopStatus": GLib.Variant("s", s.get("loop") or "None"),
            "Rate": GLib.Variant("d", 1.0),
            "Shuffle": GLib.Variant("b", bool(s.get("shuffle"))),
            "Metadata": GLib.Variant("a{sv}", meta),
            "Volume": GLib.Variant("d", max(0.0, float(s.get("volume") or 0))),
            "MinimumRate": GLib.Variant("d", 1.0),
            "MaximumRate": GLib.Variant("d", 1.0),
            "CanGoNext": GLib.Variant("b", has),
            "CanGoPrevious": GLib.Variant("b", has),
            "CanPlay": GLib.Variant("b", has),
            "CanPause": GLib.Variant("b", has),
            "CanSeek": GLib.Variant("b", bool(s.get("canSeek"))),
            "CanControl": GLib.Variant("b", True),
        }

    ROOT_PROPS = {
        "CanQuit": GLib.Variant("b", True), "CanRaise": GLib.Variant("b", True),
        "HasTrackList": GLib.Variant("b", False), "Identity": GLib.Variant("s", "GoblinAmp"),
        "DesktopEntry": GLib.Variant("s", "goblin-amp"),
        "SupportedUriSchemes": GLib.Variant("as", ["file"]),
        "SupportedMimeTypes": GLib.Variant("as", MIME),
    }

    def changed(self):
        """After any change in the player: PropertiesChanged with what differs."""
        if not self.owner:
            return
        now = self._props()
        diff = {k: v for k, v in now.items() if k not in self.last or not v.equal(self.last[k])}
        self.last = now
        if diff:
            self.bus.emit_signal(None, PATH, "org.freedesktop.DBus.Properties", "PropertiesChanged",
                                 GLib.Variant("(sa{sv}as)", (PLAYER, diff, [])))

    def seeked(self, seconds):
        if self.owner:
            self.bus.emit_signal(None, PATH, PLAYER, "Seeked", GLib.Variant("(x)", (int(seconds * 1e6),)))

    # ── the bus's calls ──
    def _get(self, conn, sender, path, iface, prop):
        if iface == ROOT:
            return self.ROOT_PROPS.get(prop)
        if prop == "Position":
            return GLib.Variant("x", int((self.player.state().get("position") or 0) * 1e6))
        return self._props().get(prop)

    def _set(self, conn, sender, path, iface, prop, value):
        v = value.unpack()
        if prop == "Volume":
            self.player.set_volume(v)
        elif prop == "Shuffle":
            self.player.set_shuffle(bool(v))
        elif prop == "LoopStatus" and v in ("None", "Track", "Playlist"):
            self.player.set_loop(v)
        return True

    def _call(self, conn, sender, path, iface, method, params, invocation):
        args = params.unpack()
        p = self.player
        if method == "Raise":
            self.raise_window()
        elif method == "Quit":
            self.quit_app()
        elif method in ("Next", "Previous", "Pause", "PlayPause", "Stop", "Play"):
            p.control(method.lower())
        elif method == "Seek":
            p.seek_to((p.state().get("position") or 0) + args[0] / 1e6)
        elif method == "SetPosition":
            if args[0] == p.state().get("trackid"):
                p.seek_to(args[1] / 1e6)
        elif method == "OpenUri":
            path = Gio.File.new_for_uri(args[0]).get_path()
            if path:
                p.open_paths([path])
        invocation.return_value(None)
