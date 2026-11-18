"""FILER beside Goblin AI's TERMINAL (18 Nov, the user: "a file view where I can look at files while you work"):
the folder of the tab shown (Claude Code's, else the shell's – the git repo's top when it is in one), a tree with
git's marks like VS Code (M changed, U new, A added, D gone, R renamed; ignored files dimmed but shown –
senast-gjort.txt is excluded from git), and a file shown with colours and line numbers or as its change.

Only reads: nothing here writes in the folder, and git runs with --no-optional-locks (a plain `git status` may
take index.lock and stop Claude's `git commit` – "index.lock exists"). Nothing updates by itself: the user
presses ↻ (the user's choice 18 Nov).

    view = fileview.FileView()
    engine.rootContext().setContextProperty("fileView", view)

QML: fileView.open(folder); JSON.parse(fileView.rows(JSON.stringify(expanded), onlyChanged)); fileView.refresh();
JSON.parse(fileView.show(rel, diff)); fileView.copy(text).
"""
import html
import json
import os
import re
import subprocess

from PySide6.QtCore import Property, QObject, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication

try:  # Fedora's python3-pygments – without it the file is shown without colours
    from pygments.lexers import get_lexer_for_filename, guess_lexer_for_filename
    from pygments.token import Token
    from pygments.util import ClassNotFound
except ImportError:  # pragma: no cover
    get_lexer_for_filename = None

SKIP = {".git", "__pycache__", "node_modules", ".mypy_cache", ".pytest_cache", ".ruff_cache", ".venv"}
IMAGES = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".bmp", ".ico")
SHOW_MAX = 1_000_000     # bytes shown (the rest: "only the beginning")
COLOUR_MAX = 600_000     # bytes with colours (Main.qml is ~420 KB)

TEXT = "#E6ECF5"
NUMBER = "#3E4A60"
# pygments' token types → the terminal's palette (index.html's theme)
COLOURS = [
    ("Comment", "#6B7890"), ("Keyword", "#B48EF0"), ("Name.Builtin", "#7CDDF0"), ("Name.Function", "#82A9F5"),
    ("Name.Class", "#82A9F5"), ("Name.Decorator", "#7CDDF0"), ("Name.Tag", "#5B8DEF"), ("Name.Attribute", "#B48EF0"),
    ("Name.Variable", "#C7D0DD"), ("Literal.String", "#4CC38A"), ("Literal.Number", "#4CCCE6"),
    ("Generic.Heading", "#82A9F5"), ("Generic.Subheading", "#82A9F5"), ("Generic.Strong", "#FFFFFF"),
    ("Generic.Emph", "#C7D0DD"), ("Generic.Inserted", "#6BDDA5"), ("Generic.Deleted", "#FF6369"),
    ("Operator.Word", "#B48EF0"), ("Name.Label", "#F5D90A"),
]
# git's letters: colour per mark (U/A new = green, M = yellow, D = red, R = blue)
MARK_COLOURS = {"M": "#E2C04A", "U": "#4CC38A", "A": "#4CC38A", "D": "#E5484D", "R": "#5B8DEF", "!": "#E5484D"}


def git(top, *args, timeout=5):
    try:
        out = subprocess.run(["git", "--no-optional-locks", "-C", top, *args], capture_output=True,
                             timeout=timeout, env={**os.environ, "GIT_TERMINAL_PROMPT": "0", "LC_ALL": "C"})
    except (OSError, subprocess.SubprocessError):
        return None
    return out


def git_top(folder):
    out = git(folder, "rev-parse", "--show-toplevel")
    if out is None or out.returncode != 0:
        return ""
    return out.stdout.decode(errors="replace").strip()


def read_status(top):
    """{path relative to the top: letter} from `git status` (nothing taken from the index – no lock)."""
    out = git(top, "status", "--porcelain=v1", "-z", "--untracked-files=all")
    marks = {}
    if out is None or out.returncode != 0:
        return marks
    parts = out.stdout.decode(errors="replace").split("\0")
    i = 0
    while i < len(parts):
        entry = parts[i]
        i += 1
        if len(entry) < 4:
            continue
        xy, path = entry[:2], entry[3:]
        if "R" in xy or "C" in xy:
            i += 1  # the old name follows
        if xy == "??":
            mark = "U"
        elif "U" in xy or xy in ("AA", "DD"):
            mark = "!"
        elif "D" in xy:
            mark = "D"
        elif "R" in xy:
            mark = "R"
        elif xy[0] == "A":
            mark = "A"
        else:
            mark = "M"
        marks[path] = mark
    return marks


class FileView(QObject):
    changed = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._root = ""
        self._top = False   # the root is a git repo's top
        self._marks = {}
        self._branch = ""
        self._char = 7.2

    # ── the folder ──
    @Slot(str)
    def open(self, folder):
        """The folder of the tab shown (FILER opened, ↻, another tab chosen): the git repo's top when in one."""
        folder = os.path.realpath(os.path.expanduser(folder)) if folder else ""
        if folder and not os.path.isdir(folder):
            folder = ""
        top = git_top(folder) if folder else ""
        root = top or folder
        if root != self._root:
            self._root = root
        self._top = bool(top)
        self._read_git()
        self.changed.emit()

    @Slot()
    def refresh(self):
        self._read_git()
        self.changed.emit()

    def _read_git(self):
        self._marks, self._branch = {}, ""
        if self._root and self._top:
            self._marks = read_status(self._root)
            out = git(self._root, "branch", "--show-current")
            if out is not None and out.returncode == 0:
                self._branch = out.stdout.decode(errors="replace").strip()

    @Property(str, notify=changed)
    def root(self):
        return self._root

    @Property(str, notify=changed)
    def name(self):
        return os.path.basename(self._root.rstrip("/")) or self._root

    @Property(bool, notify=changed)
    def isGit(self):
        return self._top

    @Property(str, notify=changed)
    def branch(self):
        return self._branch

    @Property(int, notify=changed)
    def changedCount(self):
        return len(self._marks)

    # ── the tree ──
    def _dir_mark(self, rel):
        prefix = rel + "/"
        return "•" if any(p.startswith(prefix) for p in self._marks) else ""

    def _ignored(self, paths):
        """Which of these (relative) paths git ignores – one `git check-ignore` for all rows shown."""
        if not self._top or not paths:
            return set()
        try:
            out = subprocess.run(["git", "--no-optional-locks", "-C", self._root, "check-ignore", "-z", "--stdin"],
                                 input="\0".join(paths).encode() + b"\0", capture_output=True, timeout=5,
                                 env={**os.environ, "GIT_TERMINAL_PROMPT": "0"})
        except (OSError, subprocess.SubprocessError):
            return set()
        return {p for p in out.stdout.decode(errors="replace").split("\0") if p}

    @Slot(str, bool, result=str)
    def rows(self, expanded_json, only_changed):
        """The rows shown: [{rel, name, depth, dir, open, mark, ignored}] – the folders in `expanded` opened.
        only_changed: the changed files as a flat list (ÄNDRADE), deleted ones too."""
        if not self._root:
            return "[]"
        if only_changed:
            return json.dumps([{"rel": p, "name": p, "depth": 0, "dir": False, "open": False, "mark": m,
                                "ignored": False} for p, m in sorted(self._marks.items())], ensure_ascii=False)
        try:
            expanded = set(json.loads(expanded_json or "[]"))
        except ValueError:
            expanded = set()
        rows = []

        def walk(rel, depth):
            folder = os.path.join(self._root, rel) if rel else self._root
            try:
                entries = list(os.scandir(folder))
            except OSError:
                return
            items = []
            for e in entries:
                if e.name in SKIP:
                    continue
                try:
                    is_dir = e.is_dir(follow_symlinks=False)
                except OSError:
                    is_dir = False
                items.append((not is_dir, e.name.lower(), e.name, is_dir))
            for _, _, name, is_dir in sorted(items):
                path = f"{rel}/{name}" if rel else name
                rows.append({"rel": path, "name": name, "depth": depth, "dir": is_dir, "open": path in expanded,
                             "mark": self._dir_mark(path) if is_dir else self._marks.get(path, ""), "ignored": False})
                if is_dir and path in expanded and len(rows) < 20000:
                    walk(path, depth + 1)

        walk("", 0)
        ignored = self._ignored([r["rel"] + ("/" if r["dir"] else "") for r in rows])
        for r in rows:
            r["ignored"] = (r["rel"] + ("/" if r["dir"] else "")) in ignored or r["rel"] in ignored
        return json.dumps(rows, ensure_ascii=False)

    @Slot(str, result=str)
    def markColour(self, mark):
        return MARK_COLOURS.get(mark, "#8B98AD")

    # ── a file ──
    @Slot(str, bool, float, result=str)
    def show(self, rel, diff, char_px=7.2):
        """{kind: text|image|binary|missing|folder, html, url, note, canDiff, mark, lines} – char_px: one
        character's width in the view (a wrapped line continues after the line numbers, not under them)."""
        self._char = char_px if char_px > 0 else 7.2
        mark = self._marks.get(rel, "")
        path = os.path.normpath(os.path.join(self._root, rel))
        result = {"kind": "text", "html": "", "url": "", "note": "", "mark": mark, "lines": 0,
                  "canDiff": self._top and mark in ("M", "D", "R", "A", "!")}
        if not self._root or not (path == self._root or path.startswith(self._root.rstrip("/") + "/")):
            result["kind"] = "missing"
            return json.dumps(result)
        if diff and result["canDiff"]:
            out = git(self._root, "diff", "HEAD", "--no-color", "--no-ext-diff", "--", rel, timeout=10)
            text = out.stdout.decode(errors="replace") if out is not None else ""
            if not text.strip():
                result["note"] = "Ingen skillnad mot senaste commit."
            result["html"], result["lines"] = self._diff_html(text[:SHOW_MAX])
            if len(text) > SHOW_MAX:
                result["note"] = "Visar bara början – ändringen är stor."
            return json.dumps(result, ensure_ascii=False)
        if os.path.isdir(path):
            result["kind"] = "folder"
            return json.dumps(result)
        if not os.path.isfile(path):
            result["kind"] = "missing"
            result["note"] = "Filen är borttagen – tryck ÄNDRINGEN för att se vad som fanns." if mark == "D" else "Filen finns inte längre."
            return json.dumps(result, ensure_ascii=False)
        if rel.lower().endswith(IMAGES):
            result["kind"] = "image"
            result["url"] = QUrl.fromLocalFile(path).toString()
            return json.dumps(result)
        try:
            size = os.path.getsize(path)
            with open(path, "rb") as fh:
                data = fh.read(SHOW_MAX)
        except OSError as e:
            result["kind"] = "missing"
            result["note"] = f"Kan inte läsas: {e.strerror}"
            return json.dumps(result, ensure_ascii=False)
        if b"\0" in data[:8192]:
            result["kind"] = "binary"
            result["note"] = f"En binär fil ({size // 1024 or 1} kB) – den kan inte visas som text."
            return json.dumps(result, ensure_ascii=False)
        text = data.decode("utf-8", errors="replace")
        if size > SHOW_MAX:
            text = text[:text.rfind("\n") + 1] or text
            result["note"] = f"Visar bara början ({SHOW_MAX // 1000} kB av {size // 1000} kB)."
        result["html"], result["lines"] = self._code_html(rel, text, colours=len(data) <= COLOUR_MAX)
        return json.dumps(result, ensure_ascii=False)

    def _block(self, chars, colour="", bg=""):
        """A line's style: wrapped rows continue `chars` characters in (a hanging indent)."""
        px = round(chars * self._char, 1)
        return (f"white-space:pre-wrap;margin:0;margin-left:{px}px;text-indent:-{px}px"
                + (f";color:{colour}" if colour else "") + (f";background-color:{bg}" if bg else ""))

    def _line(self, num, width, body):
        return f'<div style="{self._block(width + 2)}"><span style="color:{NUMBER}">{num:>{width}}  </span>{body}</div>'

    def _code_html(self, rel, text, colours=True):
        lines = self._colour_lines(rel, text) if colours else None
        if lines is None:
            lines = [html.escape(l) for l in text.split("\n")]
        if lines and lines[-1] == "" and text.endswith("\n"):
            lines.pop()
        width = len(str(len(lines)))
        body = "".join(self._line(i + 1, width, l) for i, l in enumerate(lines))
        return f'<div style="color:{TEXT}">{body}</div>', len(lines)

    @staticmethod
    def _colour_lines(rel, text):
        if get_lexer_for_filename is None:
            return None
        name = os.path.basename(rel)
        try:
            lexer = get_lexer_for_filename(name, stripnl=False, ensurenl=False)
        except ClassNotFound:
            if name.endswith(".qml"):
                from pygments.lexers import QmlLexer  # noqa: PLC0415
                lexer = QmlLexer(stripnl=False, ensurenl=False)
            else:
                try:
                    lexer = guess_lexer_for_filename(name, text[:4000], stripnl=False, ensurenl=False)
                except ClassNotFound:
                    return None
        except Exception:  # noqa: BLE001
            return None
        cache = {}

        def colour(ttype):
            if ttype not in cache:
                found = ""
                t = ttype
                while t is not Token and not found:
                    found = next((c for n, c in COLOURS if str(t) == "Token." + n), "")
                    t = t.parent
                cache[ttype] = found
            return cache[ttype]

        lines, cur = [], []
        try:
            for ttype, value in lexer.get_tokens(text):
                c = colour(ttype)
                parts = value.split("\n")
                for k, part in enumerate(parts):
                    if k:
                        lines.append("".join(cur))
                        cur = []
                    if part:
                        esc = html.escape(part)
                        cur.append(f'<span style="color:{c}">{esc}</span>' if c else esc)
        except Exception:  # noqa: BLE001 – a lexer that fails: without colours
            return None
        lines.append("".join(cur))
        return lines

    def _diff_html(self, text):
        out, num = [], 0
        lines = text.split("\n")
        if lines and lines[-1] == "":
            lines.pop()
        for l in lines:
            esc = html.escape(l)
            if l.startswith(("diff --git", "index ", "--- ", "+++ ", "new file", "deleted file", "similarity", "rename ")):
                style = self._block(0, "#5C6880")
            elif l.startswith("@@"):
                style = self._block(0, "#5B8DEF", "#101A2C")
            elif l.startswith("+"):
                num += 1
                style = self._block(1, "#6BDDA5", "#0E2419")
            elif l.startswith("-"):
                num += 1
                style = self._block(1, "#FF7A7F", "#2A1216")
            else:
                style = self._block(1, "#8B98AD")
            out.append(f'<div style="{style}">{esc}</div>')
        return f'<div style="color:{TEXT}">{"".join(out)}</div>', num

    @Slot(str, str, bool)
    def copy(self, text, rel, numbered):
        """KOPIERA: the selection (or the whole file) – without the line numbers in front (numbered: a file)."""
        if not text:
            try:
                with open(os.path.join(self._root, rel), encoding="utf-8", errors="replace") as fh:
                    text = fh.read(SHOW_MAX)
            except OSError:
                return
        else:
            text = text.replace("\u2029", "\n").replace("\u2028", "\n").replace("\xa0", " ")
            if numbered:
                text = "\n".join(re.sub(r"^ *\d+  ", "", l, count=1) for l in text.split("\n"))
        QGuiApplication.clipboard().setText(text)
