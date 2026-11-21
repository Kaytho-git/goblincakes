"""The shared start of GOBLINCAKES' own windows (P17 in docs/optimering/granskning.md, UX step C 22 Nov).

Before, every window program had its own copy of these (Config, Goblin AI, Dashboard, GoblinShare, GoblinRecorder,
goblin graph, GoblinAmp, Avinstallera, the lag meter, the voice box). A window imports them like this:

    sys.path.append(str(next((d for d in (Path(__file__).resolve().parents[1] / "share/goblincakes",
                                          Path("/usr/share/goblincakes")) if (d / "goblinapp.py").exists()),
                             "/usr/share/goblincakes")))
    from goblinapp import cached_qml, season_logo, use_accent  # noqa: E402

The scale is not here: it is G.Zoom in the QML (qml/Goblin/Zoom.qml, docs/ux/norm.md 2) – no QT_SCALE_FACTOR.
"One window at a time" (QLocalServer) stays in each window, as the user decided (it differs per window).
"""
import importlib.util
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
LOGO = "/usr/share/icons/hicolor/scalable/apps/goblincakes.svg"
FALLBACK_ACCENT = {"color": "#2F6FED", "hover": "#4A82F0", "on": "#E6ECF5", "text": "#2F6FED",
                   "dim": "#1B3A78", "error": "#A4262C", "errorBright": "#E5484D"}


def cached_qml(path):
    """The window's QML from a copy Qt's QML cache works for (share/goblincakes/qmlcache.py, P23 12 Nov:
    image files are dated 1970 and were compiled again at every start) – or the file itself."""
    try:
        spec = importlib.util.spec_from_file_location("qmlcache", Path(path).resolve().parents[1] / "qmlcache.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module.local(path)
    except Exception:  # noqa: BLE001 – anything wrong: load the file as before
        return str(path)


def use_accent(engine, share=None):
    """GOBLINCAKES' accent colour (Config → Utseende) as the QML property "accent", followed live: accent.py next
    to the window's QML (share = that folder's parent, when started from the repo), here, or in /usr.
    Without it: the standard blue."""
    for d in ([Path(share)] if share else []) + [HERE, Path("/usr/share/goblincakes")]:
        if (d / "accent.py").exists():
            if str(d) not in sys.path:
                sys.path.insert(0, str(d))
            break
    try:
        import accent  # noqa: PLC0415
        accent.install(engine)
    except Exception:  # noqa: BLE001 – an old or broken file must not stop the window
        engine.rootContext().setContextProperty("accent", dict(FALLBACK_ACCENT))


def season_logo():
    """The logo – in its look for the time of year when there is one."""
    try:
        sys.path.insert(0, "/usr/share/goblincakes/seasons")
        import season  # noqa: PLC0415
        return season.asset("logo.svg", LOGO)
    except Exception:  # noqa: BLE001
        return LOGO


def sharp_text():
    """After a file dialog: Qt's own text again (KDE's dialog style switches to native text – CLAUDE.md)."""
    from PySide6.QtQuick import QQuickWindow  # noqa: PLC0415
    QQuickWindow.setTextRenderType(QQuickWindow.TextRenderType.QtTextRendering)
