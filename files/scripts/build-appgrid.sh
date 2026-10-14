#!/usr/bin/env bash
# Builds AppGrid with square corners, in its own build stage (see "stages" in recipe.yml).
# AppGrid's QML is compiled into the program, so the rounded corners (Kirigami's
# cornerRadius) can't be changed from outside. The result lands in /out and is copied
# over the COPR package's files in the image (install-appgrid.sh; check-appgrid.sh verifies).
set -oue pipefail

# Never stops the image build on its own: if this build fails (for example a new Plasma
# that AppGrid hasn't caught up with), /out only gets a marker, the image keeps the COPR
# package (rounded corners) and check-appgrid.sh decides whether the image still has AppGrid.
if [[ -z "${GOBLINCAKES_APPGRID_INNER:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    if GOBLINCAKES_APPGRID_INNER=1 bash "${BASH_SOURCE[0]}"; then
        exit 0
    fi
    echo "WARNING: AppGrid with square corners could not be built – the image gets the COPR package instead" >&2
    rm -rf /out
    mkdir -p /out/usr/share/goblincakes
    echo failed > /out/usr/share/goblincakes/appgrid-build
    exit 0
fi

dnf5 -y install dnf5-plugins git cmake extra-cmake-modules gcc-c++ gettext qt6-qtbase-private-devel

# Same version as the COPR package, so the rest of its files match
dnf5 -y copr enable scujas/plasma-applet-appgrid
version=$(dnf5 repoquery -q --latest-limit=1 --qf '%{version}\n' plasma-applet-appgrid | tail -n1)
echo "AppGrid version in COPR: ${version:-unknown}"

src=/tmp/appgrid
if ! git clone --depth 1 --branch "v${version}" https://github.com/xarbit/appgrid "$src"; then
    echo "No tag v${version}, building the newest release instead"
    tag=$(git ls-remote --tags --refs --sort=-v:refname https://github.com/xarbit/appgrid 'v*' | head -n1 | sed 's|.*refs/tags/||')
    git clone --depth 1 --branch "$tag" https://github.com/xarbit/appgrid "$src"
    version=${tag#v}
fi

# Build dependencies straight from AppGrid's own CMake files, as cmake(…) packages
# (find_package(KF6 COMPONENTS A B) → cmake(KF6A) cmake(KF6B), find_package(X) → cmake(X))
mapfile -t deps < <(python3 - "$src" <<'PY'
import pathlib, re, sys
deps = set()
for f in pathlib.Path(sys.argv[1]).rglob("*"):
    if f.name != "CMakeLists.txt" and f.suffix != ".cmake":
        continue
    if "tests" in f.parts:
        continue
    for call in re.findall(r"find_package\s*\(([^)]*)\)", f.read_text(errors="ignore"), re.I):
        words = [w for w in call.split() if not w.startswith("${")]
        if not words:
            continue
        name, rest = words[0], words[1:]
        keywords = {"REQUIRED", "COMPONENTS", "OPTIONAL_COMPONENTS", "CONFIG", "NO_MODULE", "QUIET", "EXACT", "MODULE"}
        if "COMPONENTS" in rest or "OPTIONAL_COMPONENTS" in rest:
            first = min(rest.index(k) for k in ("COMPONENTS", "OPTIONAL_COMPONENTS") if k in rest)
            comps = [c for c in rest[first + 1:] if c.isidentifier() and c not in keywords]
            deps.update(f"cmake({name}{c})" for c in comps)
        elif name not in ("Git", "PkgConfig", "Threads", "ECM", "Gettext"):
            deps.add(f"cmake({name})")
print("\n".join(sorted(deps)))
PY
)
echo "Build dependencies: ${deps[*]}"
dnf5 -y install --skip-unavailable "${deps[@]}"

# GOBLINCAKES: everything flat with straight corners
{ grep -rl 'Kirigami\.Units\.cornerRadius' "$src/package" || true; } | xargs -r sed -i 's/Kirigami\.Units\.cornerRadius/0/g'
if grep -rq 'Kirigami\.Units\.cornerRadius' "$src/package"; then
    echo "Rounded corners left in AppGrid" >&2
    exit 1
fi

# Plasma 6.8 removed Applet::globalConfig() (libplasma). Older AppGrid releases still call it:
# swap in the same config group (corona config, [AppletGlobals][<plugin id>]) through public API.
# Only when the installed libplasma no longer has it, so a Plasma 6.7 build is unchanged.
applet_h=$(find /usr/include -path '*lasma*' -name applet.h | head -n1)
if [[ -n "$applet_h" ]] && ! grep -q 'globalConfig()' "$applet_h" && grep -rq 'globalConfig()' "$src/src"; then
    echo "libplasma without Applet::globalConfig() – patching AppGrid"
    python3 - "$src/src" <<'PY'
import pathlib, sys
helper = """
#include <KSharedConfig>
#include <Plasma/Containment>
#include <Plasma/Corona>

// GOBLINCAKES: Applet::globalConfig was removed in Plasma 6.8 – same group, public API
static KConfigGroup goblincakesGlobalConfig(const Plasma::Applet *applet)
{
    KConfigGroup globals;
    const Plasma::Containment *cont = applet->containment();
    if (cont && cont->corona()) {
        globals = KConfigGroup(cont->corona()->config(), QStringLiteral("AppletGlobals"));
    } else {
        globals = KConfigGroup(KSharedConfig::openConfig(), QStringLiteral("AppletGlobals"));
    }
    return KConfigGroup(&globals, applet->pluginMetaData().pluginId());
}
"""
for f in pathlib.Path(sys.argv[1]).rglob("*.cpp"):
    text = f.read_text()
    if "globalConfig()" not in text:
        continue
    lines = text.split("\n")
    # after the includes at the top (not the .moc include at the end)
    first_code = next(i for i, l in enumerate(lines) if l[:1].isalpha())
    last_include = max(i for i, l in enumerate(lines[:first_code]) if l.startswith("#include"))
    lines.insert(last_include + 1, helper)
    text = "\n".join(lines).replace("globalConfig()", "goblincakesGlobalConfig(this)")
    f.write_text(text)
    print("patched", f)
PY
fi

# Plasma 6.8 is Wayland-only – AppGrid's own switch for that
x11=ON
plasma_version=$(rpm -q --qf '%{VERSION}' libplasma 2>/dev/null || true)
if [[ -n "$plasma_version" ]] && [[ "$(printf '%s\n6.8\n' "$plasma_version" | sort -V | head -n1)" == "6.8" ]]; then
    x11=OFF
fi
echo "Plasma ${plasma_version:-unknown}, ENABLE_X11=$x11"

cmake -S "$src" -B "$src/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DKDE_INSTALL_USE_QT_SYS_PATHS=ON \
    -DBUILD_TESTING=OFF \
    -DENABLE_X11="$x11" \
    -DAPPGRID_VERSION_OVERRIDE="$version"
cmake --build "$src/build" -j"$(nproc)"
DESTDIR=/out cmake --install "$src/build"
mkdir -p /out/usr/share/goblincakes
echo "square $version" > /out/usr/share/goblincakes/appgrid-build
find /out -type f | sort
