#!/usr/bin/env python3
"""GOBLINCAKES lärläge: runs the user's PySide6 program (main.py) without a screen (Qt's offscreen
platform) and tells what the windows look like – so a window program can be checked like any
other task. The user's app.exec() does not wait for a person: it plays the task's script
(actions.txt) and prints the windows at the end ("--- Till sist ---").

actions.txt, one per line (the output shows each as "> …"):
  vänta 300                  let the program run 300 ms (timers, animations)
  hover [namn]               the mouse comes over the window, or over the widget called namn
  lämna                      the mouse leaves the window
  hjul ner|upp [namn] [n]    the scroll wheel, n steps, over namn (else the window's middle)
  klick namn                 a left click on namn (a button, a widget)
  skriv namn text …          types the text into namn
  meny Arkiv/Öppna           chooses Öppna in the menu Arkiv (the menu's own text)
  tangent Ctrl+S             the action with that shortcut (in a menu or on a widget)
  tryck [namn] Esc           a key press to namn (else the window) – for keyPressEvent
  rapport                    prints the windows now
  fil bok.txt                prints a file in the work folder (what the program saved)
namn = a widget's objectName (setObjectName("text")) or its class (QTextEdit, or your own class).

dialog.txt answers file dialogs in order: "öppna bok.txt", "spara ut.txt" or "avbryt"
(QFileDialog.getOpenFileName/getSaveFileName). QMessageBox's question/information/warning
are answered Yes/Ok and printed.
"""
import os
import runpy
import sys
import traceback
from pathlib import Path

os.environ["QT_QPA_PLATFORM"] = "offscreen"
os.environ.setdefault("QT_LOGGING_RULES", "*.debug=false;qt.qpa.*=false;qt.text.font.db=false")

from PySide6.QtCore import QCoreApplication, QEvent, QPoint, QPointF, Qt  # noqa: E402
from PySide6.QtGui import QAction, QCursor, QEnterEvent, QGuiApplication, QKeySequence, QWheelEvent  # noqa: E402
from PySide6.QtTest import QTest  # noqa: E402
from PySide6.QtWidgets import (QAbstractButton, QAbstractScrollArea, QApplication, QFileDialog,  # noqa: E402
                               QLabel, QLineEdit, QMainWindow, QMenu, QMenuBar, QMessageBox,
                               QPlainTextEdit, QStatusBar, QTextEdit, QWidget)

errors = []  # exceptions in the user's slots and event handlers (Qt only prints them)


def hook(kind, value, tb):
    errors.append("".join(traceback.format_exception(kind, value, tb)))
    sys.__stderr__.write(errors[-1])


sys.excepthook = hook


def lines_of(name):
    try:
        return [line.strip() for line in Path(name).read_text().splitlines() if line.strip()]
    except OSError:
        return []


# ── File dialogs and message boxes: answered from dialog.txt ──────────

answers = lines_of("dialog.txt")


def answer(kind):
    if not answers:
        print(f"(Filfönstret ({kind}): Avbryt)")
        return "", ""
    word, _, name = answers.pop(0).partition(" ")
    if word == "avbryt" or not name:
        print(f"(Filfönstret ({kind}): Avbryt)")
        return "", ""
    print(f"(Filfönstret ({kind}): {name})")
    return str(Path(name).resolve()), ""


QFileDialog.getOpenFileName = staticmethod(lambda *a, **k: answer("öppna"))
QFileDialog.getSaveFileName = staticmethod(lambda *a, **k: answer("spara"))


def box(kind):
    def show(parent=None, title="", text="", *a, **k):
        print(f"({kind}: {title} – {text})")
        return QMessageBox.StandardButton.Yes if kind == "Fråga" else QMessageBox.StandardButton.Ok
    return staticmethod(show)


QMessageBox.question = box("Fråga")
QMessageBox.information = box("Information")
QMessageBox.warning = box("Varning")
QMessageBox.critical = box("Fel")


# ── Describing the windows ────────────────────────────────────────

def short(text, n=70):
    text = str(text).replace("\n", "⏎")
    return text if len(text) <= n else text[:n] + "…"


def qt_class(w):
    for cls in type(w).__mro__:
        if cls.__module__.startswith("PySide6"):
            return cls.__name__
    return type(w).__name__


def label(w):
    own, qt = type(w).__name__, qt_class(w)
    text = own if own == qt else f"{own} ({qt})"
    if w.objectName() and not w.objectName().startswith("qt_"):
        text += f' "{w.objectName()}"'
    return text


def menus(bar):
    out = []
    for act in bar.actions():
        menu = act.menu()
        items = []
        if isinstance(menu, QMenu):
            for a in menu.actions():
                if a.isSeparator():
                    continue
                key = a.shortcut().toString(QKeySequence.SequenceFormat.NativeText)
                items.append(a.text().replace("&", "") + (f" [{key}]" if key else ""))
        out.append(f"{act.text().replace('&', '')}: " + ", ".join(items))
    return out


def details(w):
    parts = ["synlig" if w.isVisible() else "dold"]
    if isinstance(w, (QTextEdit, QPlainTextEdit)):
        parts.append(f'text="{short(w.toPlainText())}"')
    elif isinstance(w, QStatusBar):
        parts.append(f'text="{short(w.currentMessage())}"')
    elif isinstance(w, (QLabel, QAbstractButton, QLineEdit)):
        parts.append(f'text="{short(w.text())}"')
    if w.styleSheet():
        parts.append(f"stil={short(' '.join(w.styleSheet().split()), 90)}")
    font = w.font()
    if w.testAttribute(Qt.WidgetAttribute.WA_SetFont) and font.pointSize() > 0:
        parts.append(f"typsnitt={font.family()} {font.pointSize()} pt")
    if not w.isWindow():
        parts.append(f"plats {w.x()},{w.y()} {w.width()}x{w.height()}")
    return ", ".join(parts)


def walk(w, depth, out):
    if isinstance(w, QMenu):
        return
    out.append("  " * depth + label(w) + ": " + details(w))
    if isinstance(w, QMenuBar):
        for line in menus(w):
            out.append("  " * (depth + 1) + "meny " + line)
        return
    if isinstance(w, QAbstractScrollArea):
        return  # a text box's inner parts (viewport, scroll bars) are Qt's own
    for c in w.children():
        if isinstance(c, QWidget) and not c.isWindow() and not c.objectName().startswith("qt_"):
            walk(c, depth + 1, out)


def windows():
    return [w for w in QApplication.topLevelWidgets()
            if not isinstance(w, QMenu) and (w.isVisible() or w.windowTitle())]


def report(heading):
    print(f"--- {heading} ---")
    shown = windows()
    if not shown:
        print("(inget fönster – glömde du show()?)")
    for w in shown:
        flags = w.windowFlags()
        frame = "nej" if flags & Qt.WindowType.FramelessWindowHint else "ja"
        print(f'fönster "{w.windowTitle()}" {w.width()}x{w.height()}, ram: {frame}, '
              f'{"synligt" if w.isVisible() else "dolt"}'
              + (", genomskinlig bakgrund" if w.testAttribute(Qt.WidgetAttribute.WA_TranslucentBackground) else ""))
        out = []
        walk(w, 1, out)
        print("\n".join(out))


# ── The script ────────────────────────────────────────────────────

def find(name):
    if not name:
        shown = [w for w in windows() if w.isVisible()]
        return shown[0] if shown else None
    for top in windows():
        for w in [top] + top.findChildren(QWidget):
            if w.objectName() == name or type(w).__name__ == name or qt_class(w) == name:
                return w
    return None


def deepest(w, pos):
    """The widget the mouse is really over (a QTextEdit's inner viewport, as on a real screen)."""
    child = w.childAt(pos)
    return (child, child.mapFrom(w, pos)) if child else (w, pos)


hovered = []


def hover(target):
    top = target.window()
    centre = target.mapTo(top, target.rect().center())
    chain = []
    w = deepest(top, centre)[0]
    while w is not None:
        chain.insert(0, w)
        w = None if w.isWindow() else w.parentWidget()
    for w in chain:
        if w in hovered:
            continue
        local = QPointF(w.mapFrom(top, centre))
        QApplication.sendEvent(w, QEnterEvent(local, local, QPointF(top.mapToGlobal(centre))))
        hovered.append(w)
    QTest.mouseMove(top, centre)


def leave():
    for w in reversed(hovered):
        QApplication.sendEvent(w, QEvent(QEvent.Type.Leave))
    hovered.clear()
    QCursor.setPos(OUTSIDE)


def wheel(target, down, steps):
    top = target.window()
    centre = target.mapTo(top, target.rect().center())
    for _ in range(steps):
        w, pos = deepest(top, centre)
        while w is not None:
            ev = QWheelEvent(QPointF(pos), QPointF(top.mapToGlobal(centre)), QPoint(0, 0),
                             QPoint(0, -120 if down else 120), Qt.MouseButton.NoButton,
                             Qt.KeyboardModifier.NoModifier, Qt.ScrollPhase.NoScrollPhase, False)
            ev.setAccepted(False)
            QApplication.sendEvent(w, ev)
            if ev.isAccepted() or w.isWindow():
                break
            pos = w.mapToParent(pos)
            w = w.parentWidget()
        QTest.qWait(30)


def menu_action(path):
    want = [p.strip().lower() for p in path.split("/")]
    for top in windows():
        for bar in top.findChildren(QMenuBar):
            for act in bar.actions():
                if act.text().replace("&", "").lower() != want[0] or not act.menu():
                    continue
                for a in act.menu().actions():
                    if len(want) > 1 and a.text().replace("&", "").lower() == want[1]:
                        return a
    return None


def shortcut_action(keys):
    seq = QKeySequence(keys)
    for top in windows():
        for a in top.findChildren(QAction):
            if any(s.matches(seq) == QKeySequence.SequenceMatch.ExactMatch for s in a.shortcuts()):
                return a
    return None


def play():
    for line in lines_of("actions.txt"):
        print(f"> {line}")
        word, *rest = line.split()
        name = rest[0] if rest else ""
        if word == "vänta":
            QTest.qWait(int(name or 100))
            continue
        if word == "rapport":
            report("Nu")
            continue
        if word == "fil":
            try:
                print(Path(name).read_text(), end="" if Path(name).read_text().endswith("\n") else "\n")
            except OSError:
                print(f"(filen {name} finns inte)")
            continue
        if word == "lämna":
            leave()
        elif word == "hover":
            w = find(name)
            if w is None:
                print(f"(hittar ingen {name})")
                continue
            hover(w)
        elif word == "hjul":
            down = name != "upp"
            args = rest[1:]
            steps = int(args[-1]) if args and args[-1].isdigit() else 1
            target = find(args[0]) if args and not args[0].isdigit() else find("")
            if target is None:
                print("(hittar inget att scrolla över)")
                continue
            wheel(target, down, steps)
        elif word == "klick":
            w = find(name)
            if w is None:
                print(f"(hittar ingen {name})")
                continue
            QTest.mouseClick(w, Qt.MouseButton.LeftButton)
        elif word == "skriv":
            w = find(name)
            if w is None:
                print(f"(hittar ingen {name})")
                continue
            w.setFocus()
            QTest.keyClicks(w, line.split(None, 2)[2] if len(line.split(None, 2)) > 2 else "")
        elif word == "meny":
            a = menu_action(" ".join(rest))
            if a is None:
                print(f"(menyn har ingen {' '.join(rest)})")
                continue
            a.trigger()
        elif word == "tryck":
            target = find(rest[0]) if len(rest) > 1 else find("")
            seq = QKeySequence(rest[-1] if rest else "")
            if target is None or seq.isEmpty():
                print("(vet inte vad som ska tryckas)")
                continue
            combo = seq[0]
            QTest.keyClick(target, combo.key(), combo.keyboardModifiers())
        elif word == "tangent":
            a = shortcut_action(name)
            if a is None:
                print(f"(inget kortkommando {name})")
                continue
            print(f"({name} → {a.text().replace('&', '')})")
            a.trigger()
        QTest.qWait(50)


done = []


def run_script(*_a, **_k):
    if done:
        return 0
    done.append(True)
    QTest.qWait(100)  # the windows are shown and laid out
    play()
    QTest.qWait(50)
    report("Till sist")
    if errors:
        print("Ett fel i ditt program (se ovan).")
        sys.stdout.flush()
        os._exit(1)
    sys.stdout.flush()
    os._exit(0)


# Offscreen windows sit at (0, 0) – where the mouse is: it would "come over" every window at
# once. It waits far outside until the script says hover.
OUTSIDE = QPoint(20000, 20000)
_real_init = QApplication.__init__


def _init(self, *a, **k):
    _real_init(self, *a, **k)
    QCursor.setPos(OUTSIDE)


QApplication.__init__ = _init
QApplication.exec = run_script
QApplication.exec_ = run_script
QCoreApplication.exec = run_script
QGuiApplication.exec = run_script

if len(sys.argv) < 2:
    sys.exit("qtrun.py main.py")
sys.argv = sys.argv[1:]
try:
    runpy.run_path(sys.argv[0], run_name="__main__")
except SystemExit:
    raise
if QApplication.instance() is None:
    sys.exit(0)  # plain Python (the class lessons) – nothing to show
print("Obs: app.exec() anropades aldrig – utan den visas fönstret aldrig på riktigt.")
run_script()
