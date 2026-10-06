#!/usr/bin/env bash
# Builds AppGrid with square corners, in its own build stage (see "stages" in recipe.yml).
# AppGrid's QML is compiled into the program, so the rounded corners (Kirigami's
# cornerRadius) can't be changed from outside. The result lands in /out and is copied
# over the COPR package's files in the image (which still brings in AppGrid's dependencies).
set -oue pipefail

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

cmake -S "$src" -B "$src/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DKDE_INSTALL_USE_QT_SYS_PATHS=ON \
    -DBUILD_TESTING=OFF \
    -DAPPGRID_VERSION_OVERRIDE="$version"
cmake --build "$src/build" -j"$(nproc)"
DESTDIR=/out cmake --install "$src/build"
find /out -type f | sort
