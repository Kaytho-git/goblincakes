"""Goblin AI's TERMINAL tab (1 Nov, the user: "the terminal in Goblin AI's main window, it doesn't have to use
Goblin AI"): real shells in pseudo-terminals, drawn by xterm.js (terminal/index.html) in a WebEngineView.
The page talks to the `Terminals` object over QWebChannel; QML only keeps the tabs."""

import codecs
import fcntl
import json
import os
import pty
import shlex
import signal
import struct
import termios

from PySide6.QtCore import QObject, QSocketNotifier, QUrl, Signal, Slot
from PySide6.QtGui import QDesktopServices, QGuiApplication


class Session:
    def __init__(self, pid, fd):
        self.pid = pid
        self.fd = fd
        self.decoder = codecs.getincrementaldecoder("utf-8")("replace")  # a character split between two reads
        self.notifier = None


class Terminals(QObject):
    """The shells. Ids are numbers; the page asks for one with open() and gets `opened` + `output` back."""
    opened = Signal(int, str, str)    # id, the folder, the command ("" = a plain shell)
    output = Signal(int, str)         # id, text from the shell
    exited = Signal(int)              # the shell is gone (exit, ✕)
    titled = Signal(int, str)         # the shell's own title (Fedora's bash: user@host:folder)
    wanted = Signal(str, str)         # QML → page: open a terminal here (the folder, the command)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._sessions = {}
        self._next = 1
        self._ready = False
        self._waiting = []  # asked for before the page had loaded (the first click on "Claude Code här")

    @Slot(str, str)
    def request(self, folder, command):
        """From QML (+ in the tabs, a folder's menu): the page opens it at its size."""
        if self._ready:
            self.wanted.emit(folder, command)
        else:
            self._waiting.append([folder, command])

    @Slot(int)
    def requestNear(self, sid):
        """+ / Ctrl+Shift+T: a new shell in the folder the current tab's shell stands in (home without one)."""
        s = self._sessions.get(sid)
        folder = ""
        if s:
            try:
                folder = os.readlink(f"/proc/{s.pid}/cwd")
            except OSError:
                pass
        self.request(folder, "")

    @Slot(result=str)
    def ready(self):
        """The page has loaded: what to open first ([] = one plain shell in the home folder)."""
        self._ready = True
        waiting, self._waiting = self._waiting, []
        return json.dumps(waiting)

    @Slot(str, str, int, int, result=int)
    def open(self, folder, command, cols, rows):
        folder = os.path.expanduser(folder or "~")
        if not os.path.isdir(folder):
            folder = os.path.expanduser("~")
        shell = os.environ.get("SHELL") or "/bin/bash"
        argv = [shell, "-c", command + "; exec " + shlex.quote(shell)] if command else [shell]
        # Not Goblin AI's own (Qt's scale) or a Claude Code session's markers when started from one
        env = {k: v for k, v in os.environ.items() if not k.startswith(("QT_", "QML_", "GOBLIN_AI_", "CLAUDECODE", "CLAUDE_CODE_"))}
        env.update(TERM="xterm-256color", COLORTERM="truecolor", TERM_PROGRAM="goblin-ai")
        pid, fd = pty.fork()
        if pid == 0:  # the child: only exec from here
            try:
                os.chdir(folder)
                os.execvpe(argv[0], argv, env)
            finally:
                os._exit(127)
        sid = self._next
        self._next += 1
        session = Session(pid, fd)
        self._sessions[sid] = session
        self._size(fd, cols, rows)
        session.notifier = QSocketNotifier(fd, QSocketNotifier.Type.Read, self)
        session.notifier.activated.connect(lambda *_: self._read(sid))
        self.opened.emit(sid, folder, command)
        return sid

    def _read(self, sid):
        s = self._sessions.get(sid)
        if not s:
            return
        try:
            data = os.read(s.fd, 65536)
        except OSError:
            data = b""
        if not data:  # EIO: the shell has exited
            self._end(sid)
            return
        text = s.decoder.decode(data)
        if text:
            self.output.emit(sid, text)

    def _end(self, sid):
        s = self._sessions.pop(sid, None)
        if not s:
            return
        s.notifier.setEnabled(False)
        s.notifier.deleteLater()
        try:
            os.close(s.fd)
        except OSError:
            pass
        try:
            os.waitpid(s.pid, os.WNOHANG)
        except ChildProcessError:
            pass
        self.exited.emit(sid)

    @staticmethod
    def _size(fd, cols, rows):
        if cols > 0 and rows > 0:
            fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))

    @Slot(int, str)
    def write(self, sid, text):
        s = self._sessions.get(sid)
        if s:
            try:
                os.write(s.fd, text.encode())
            except OSError:
                pass

    @Slot(int, int, int)
    def resize(self, sid, cols, rows):
        s = self._sessions.get(sid)
        if s:
            self._size(s.fd, cols, rows)

    @Slot(int, str)
    def setTitle(self, sid, title):
        self.titled.emit(sid, title)

    @Slot(int)
    def close(self, sid):
        """✕ on the tab: hang up like a closed terminal window (the shell and what runs in it)."""
        s = self._sessions.get(sid)
        if s:
            try:
                os.killpg(os.getpgid(s.pid), signal.SIGHUP)
            except OSError:
                pass

    @Slot(result=int)
    def count(self):
        return len(self._sessions)

    @Slot(str)
    def copy(self, text):
        if text:
            QGuiApplication.clipboard().setText(text)

    @Slot(result=str)
    def paste(self):
        return QGuiApplication.clipboard().text()

    @Slot(str)
    def openUrl(self, url):
        QDesktopServices.openUrl(QUrl(url))

    def close_all(self):
        """The window closes: no shells left behind."""
        for sid in list(self._sessions):
            self.close(sid)
