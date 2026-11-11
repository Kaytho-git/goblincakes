#!/usr/bin/env python3
"""Checks before the build (P15 in docs/optimering/granskning.md). Run before every commit, and as the
first job in .github/workflows/build.yml – an error stops the build before anything is built.

Errors (exit code 1):
  1. syntax: every Python, shell (bash -n) and JSON file in the repo
  2. QML: every window's QML file compiles offscreen (needs PySide6; skipped with a warning without it)
  3. the copies are equal: lock screen + logout (look-and-feel and plasma-shell), the three
     Chrome/Brave/Chromium policy files, fitTileToWindow in the KWin script and tile/apply.js
  4. tools/learn-validate.py – only when the course files changed and php/node/lua5.1 exist
Warnings (never stop anything):
  5. the layout changed without a new LAYOUT_VERSION, systray.js without SYSTRAY_VERSION,
     the Chrome theme without a new version in its manifest

Usage: python3 tools/check.py [base]   – base = the git ref the warnings compare with
       (default HEAD = your uncommitted changes; the build passes the previous push).
"""
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SKIP_DIRS = {".git", "node_modules", "__pycache__", ".venv", "venv"}
GH = bool(os.environ.get("GITHUB_ACTIONS"))
errors, warnings = [], []


def rel(p):
    return str(Path(p).relative_to(ROOT))


def files():
    for dirpath, dirs, names in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for n in names:
            p = Path(dirpath) / n
            if p.is_file() and not p.is_symlink():
                yield p


def shebang(p):
    try:
        with open(p, "rb") as f:
            first = f.readline(200)
    except OSError:
        return ""
    return first.decode("utf-8", "replace") if first.startswith(b"#!") else ""


# 1. Syntax ---------------------------------------------------------------------------------------
def check_syntax():
    py = sh = js = 0
    for p in files():
        line = shebang(p)
        if p.suffix == ".py" or (not p.suffix and "python" in line):
            py += 1
            try:
                compile(p.read_bytes(), str(p), "exec", dont_inherit=True)
            except SyntaxError as e:
                errors.append(f"Python-syntax: {rel(p)}:{e.lineno}: {e.msg}")
        elif p.suffix == ".sh" or re.match(r"#!\s*/(usr/)?bin/(env\s+)?(ba)?sh\b", line):
            sh += 1
            r = subprocess.run(["bash", "-n", rel(p)], capture_output=True, text=True, cwd=ROOT)
            if r.returncode:
                errors.append(f"Skal-syntax: {rel(p)}: {r.stderr.strip().splitlines()[-1] if r.stderr.strip() else 'fel'}")
        elif p.suffix == ".json":
            js += 1
            try:
                json.loads(p.read_text(encoding="utf-8"))
            except (ValueError, UnicodeDecodeError) as e:
                errors.append(f"JSON: {rel(p)}: {e}")
    print(f"  syntax: {py} Python, {sh} skal, {js} JSON")


# 2. QML ------------------------------------------------------------------------------------------
QML_TEST = r"""
import sys
from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlEngine, QQmlComponent
app = QGuiApplication(sys.argv)
bad = 0
for f in sys.argv[1:]:
    engine = QQmlEngine()  # kept in a variable: a temporary engine is gone before the file compiles
    c = QQmlComponent(engine, QUrl.fromLocalFile(f))
    if not c.isReady():
        bad += 1
        print("FEL " + f + ": " + " | ".join(e.toString() for e in c.errors()[:3]))
sys.exit(1 if bad else 0)
"""


def check_qml():
    share = ROOT / "files/system/usr/share/goblincakes"
    # Our own windows (PySide6) – not the Plasma parts (lock screen, logout, widgets), which need Plasma's modules
    qml = sorted(p for p in share.rglob("*.qml") if "plasma-shell" not in p.parts and "plasma-levande" not in p.parts)
    qml += sorted((ROOT / "usb-skaparen").glob("*.qml"))
    try:
        import PySide6  # noqa: F401
    except ImportError:
        warnings.append("QML-kollen hoppades över: PySide6 finns inte (pip install PySide6)")
        return
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_LOGGING_RULES="*.debug=false;qt.qpa.*=false")
    r = subprocess.run([sys.executable, "-c", QML_TEST, *map(str, qml)], capture_output=True, text=True,
                       env=env, timeout=300)
    for line in r.stdout.splitlines():
        if line.startswith("FEL "):
            errors.append("QML: " + line[4:].replace(str(ROOT) + "/", ""))
    if r.returncode and not any(e.startswith("QML:") for e in errors):
        errors.append("QML-kollen kraschade: " + (r.stderr.strip().splitlines() or ["?"])[-1])
    print(f"  QML: {len(qml)} filer")


# 3. The copies -----------------------------------------------------------------------------------
def strip_header(text):
    """The plasma-shell copy of Logout.qml starts with its own comment lines – compared without them."""
    lines = text.splitlines()
    while lines and lines[0].lstrip().startswith("//"):
        lines.pop(0)
    return "\n".join(lines)


def js_function(text, name):
    start = text.find(f"function {name}(")
    if start < 0:
        return None
    depth, i = 0, text.index("{", start)
    for j in range(i, len(text)):
        depth += {"{": 1, "}": -1}.get(text[j], 0)
        if depth == 0:
            return text[start:j + 1]
    return None


def check_copies():
    S = ROOT / "files/system"
    laf = S / "usr/share/plasma/look-and-feel/org.goblincakes.desktop/contents"
    shell = S / "usr/share/goblincakes/plasma-shell"
    pairs = [(laf / "lockscreen/LockScreen.qml", shell / "lockscreen/LockScreen.qml"),
             (laf / "logout/Logout.qml", shell / "logout/Logout.qml")]
    for d in ("logout/images",):
        for p in sorted((laf / d).glob("*")):
            pairs.append((p, shell / d / p.name))
        for p in sorted((shell / d).glob("*")):
            if not (laf / d / p.name).exists():
                errors.append(f"Kopiorna: {rel(p)} finns inte i look-and-feel-paketet")
    for a, b in pairs:
        if not b.exists():
            errors.append(f"Kopiorna: {rel(b)} saknas (kopia av {rel(a)})")
            continue
        ta, tb = a.read_bytes(), b.read_bytes()
        if a.suffix == ".qml":
            ta, tb = strip_header(ta.decode()), strip_header(tb.decode())
        if ta != tb:
            errors.append(f"Kopiorna skiljer sig: {rel(a)} och {rel(b)} (ändra båda)")
    policies = [S / "etc/opt/chrome/policies/managed/goblincakes.json",
                S / "etc/brave/policies/managed/goblincakes.json",
                S / "usr/share/goblincakes/chromium-policy/policies/managed/goblincakes.json"]
    texts = [p.read_bytes() if p.exists() else None for p in policies]
    if len(set(texts)) != 1:
        errors.append("Kopiorna skiljer sig: Chrome/Brave/Chromium-policyerna (" + ", ".join(map(rel, policies)) + ")")
    kwin = S / "usr/share/kwin/scripts/goblincakes-windows/contents/code/main.js"
    tile = S / "usr/share/goblincakes/tile/apply.js"
    fa, fb = js_function(kwin.read_text(), "fitTileToWindow"), js_function(tile.read_text(), "fitTileToWindow")
    if fa is None or fb is None or fa != fb:
        errors.append(f"Kopiorna skiljer sig: fitTileToWindow i {rel(kwin)} och {rel(tile)}")
    print("  kopiorna: låsskärm, utloggning, policyerna, fitTileToWindow")


# 4. The course base ------------------------------------------------------------------------------
def git(*args):
    r = subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None


def changed_since(base):
    """Changed paths since base (committed + uncommitted), or None when base is unknown."""
    if git("rev-parse", "--verify", "--quiet", base + "^{commit}") is None:
        return None
    out = git("diff", "--name-only", base)
    return set(out.split()) if out is not None else None


def check_learn(changed):
    touched = changed is None or any(p.startswith(("files/system/usr/share/goblincakes/learn/", "tools/learn-"))
                                     for p in changed)
    if not touched:
        print("  kurserna: oförändrade")
        return
    missing = [t for t in ("php", "node", "lua5.1") if not shutil.which(t)]
    if missing:
        warnings.append("Kurskollen (learn-validate) hoppades över: " + ", ".join(missing) + " saknas")
        return
    r = subprocess.run([sys.executable, str(ROOT / "tools/learn-validate.py")], capture_output=True, text=True,
                       timeout=600)
    if r.returncode:
        errors.append("Kurserna (tools/learn-validate.py): " + " | ".join((r.stdout + r.stderr).strip().splitlines()[-5:]))
    print("  kurserna: learn-validate")


# 5. Warnings: versions to bump -------------------------------------------------------------------
def value_at(ref, path, pattern):
    text = git("show", f"{ref}:{path}") if ref else (ROOT / path).read_text() if (ROOT / path).exists() else None
    m = re.search(pattern, text or "", re.M)
    return m.group(1) if m else None


def check_versions(base, changed):
    if changed is None:
        print(f"  versionerna: hoppades över (känner inte {base})")
        return
    fl = "files/system/usr/libexec/goblincakes-firstlogin"
    laf = "files/system/usr/share/plasma/look-and-feel/org.goblincakes.desktop/contents/"
    layout = sorted(p for p in changed if p.startswith((laf + "layouts/", laf + "defaults"))
                    or p == "files/system/usr/share/color-schemes/GoblinCakes.colors")
    rules = [(layout, fl, r"^LAYOUT_VERSION=(\d+)", "LAYOUT_VERSION i goblincakes-firstlogin"),
             (sorted(p for p in changed if p == "files/system/usr/share/goblincakes/systray.js"), fl,
              r"^SYSTRAY_VERSION=(\d+)", "SYSTRAY_VERSION i goblincakes-firstlogin"),
             (sorted(p for p in changed if p.startswith("chrome-tema/") and p != "chrome-tema/manifest.json"),
              "chrome-tema/manifest.json", r'"version":\s*"([^"]+)"', "version i chrome-tema/manifest.json")]
    for paths, where, pattern, name in rules:
        if paths and value_at(base, where, pattern) == value_at(None, where, pattern):
            warnings.append(f"{', '.join(paths)} ändrad men {name} är inte höjd")
    print("  versionerna: LAYOUT_VERSION, SYSTRAY_VERSION, Chrome-temat")


def main():
    base = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1].strip("0") else "HEAD"
    print("GOBLINCAKES-kontrollen (tools/check.py)")
    changed = changed_since(base)
    check_syntax()
    check_qml()
    check_copies()
    check_learn(changed)
    check_versions(base, changed)
    for w in warnings:
        print(("::warning::" if GH else "VARNING: ") + w)
    for e in errors:
        print(("::error::" if GH else "FEL: ") + e)
    print(f"{len(errors)} fel, {len(warnings)} varningar" + (" – bygget stoppas" if errors and GH else ""))
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
