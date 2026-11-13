"""The CLAUDE CODE map's feed for QML (13 Nov): claudemap.Watcher read every ½ s in a thread while `active`.

    feed = claudefeed.ClaudeFeed()
    engine.rootContext().setContextProperty("claudeFeed", feed)

QML: claudeFeed.active = <shown>; claudeFeed.folder = <a terminal's folder> (Goblin AI – its session is chosen
first); claudeFeed.pick(id) ("" = back to the automatic choice); JSON.parse(claudeFeed.state) → ClaudeMap.qml.
"""
import json
import os
import threading
from pathlib import Path

from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot

import claudemap

# Goblin AI: the map beside TERMINAL shown or hidden (KARTA in the tab strip) – remembered as one word
HIDDEN = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "goblincakes" / "claude-karta"


class ClaudeFeed(QObject):
    changed = Signal()
    _arrived = Signal(str)

    def __init__(self, parent=None, interval=500):
        super().__init__(parent)
        self.watcher = claudemap.Watcher()
        self._state = "{}"
        self._active = False
        self._folder = ""
        self._busy = False
        self._lock = threading.Lock()
        self._timer = QTimer(self, interval=interval, timeout=self._read)
        self._arrived.connect(self._got)

    def _read(self):
        if self._busy:
            return
        self._busy = True
        folder = self._folder

        def work():
            try:
                with self._lock:
                    text = json.dumps(self.watcher.state(folder), ensure_ascii=False)
            except Exception:  # noqa: BLE001 – a broken line must not take the window down
                text = ""
            self._arrived.emit(text)
        threading.Thread(target=work, daemon=True).start()

    def _got(self, text):
        self._busy = False
        if text and text != self._state:
            self._state = text
            self.changed.emit()

    @Property(str, notify=changed)
    def state(self):
        return self._state

    def _get_active(self):
        return self._active

    def _set_active(self, on):
        on = bool(on)
        if on == self._active:
            return
        self._active = on
        if on:
            self._read()
            self._timer.start()
        else:
            self._timer.stop()
    activeChanged = Signal()
    active = Property(bool, _get_active, _set_active, notify=activeChanged)

    def _get_folder(self):
        return self._folder

    def _set_folder(self, folder):
        folder = str(folder or "")
        if folder != self._folder:
            self._folder = folder
            if self._active:
                self._read()
    folderChanged = Signal()
    folder = Property(str, _get_folder, _set_folder, notify=folderChanged)

    paneChanged = Signal()

    def _get_pane(self):
        try:
            return HIDDEN.read_text().strip() != "dold"
        except OSError:
            return True

    def _set_pane(self, on):
        try:
            HIDDEN.parent.mkdir(parents=True, exist_ok=True)
            HIDDEN.write_text("visad\n" if on else "dold\n")
        except OSError:
            pass
        self.paneChanged.emit()
    pane = Property(bool, _get_pane, _set_pane, notify=paneChanged)

    @Slot(str)
    def pick(self, session):
        with self._lock:
            self.watcher.pick = session
            self.watcher.scanned = 0
        self._read()
