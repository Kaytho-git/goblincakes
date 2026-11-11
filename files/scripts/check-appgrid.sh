#!/usr/bin/env bash
# After the COPR package (install-appgrid.sh) and our square-cornered build (copied from the
# appgrid-square stage): the image must have an AppGrid that loads, otherwise the top bar has
# no app menu – then the build stops and everyone keeps the image they have.
set -oue pipefail

marker=/usr/share/goblincakes/appgrid-build
echo "AppGrid build: $(cat "$marker" 2>/dev/null || echo missing)"

# Our own build must come from the same Fedora as this image (11 Nov: the stage was built on
# kinoite-main:latest = Fedora 45 and copied into the Fedora 44 image of goblincakes-nvidia)
built_on=$(cat /usr/share/goblincakes/appgrid-built-on 2>/dev/null || true)
if [[ -n "$built_on" && "$built_on" != "$(rpm -E %fedora)" ]]; then
    echo "AppGrid was built on Fedora $built_on, this image is Fedora $(rpm -E %fedora):" >&2
    echo "the \`from:\` lines in recipes/common-stages.yml / nvidia-stages.yml must name the recipe's base and version" >&2
    exit 1
fi

mapfile -t plugins < <(find /usr/lib64/qt6/plugins/plasma/applets -name 'dev.xarbit.appgrid*.so' 2>/dev/null)
if (( ${#plugins[@]} == 0 )); then
    echo "No AppGrid in the image (neither our build nor the COPR package)" >&2
    exit 1
fi
for plugin in "${plugins[@]}"; do
    missing=$(ldd "$plugin" | grep 'not found' || true)
    if [[ -n "$missing" ]]; then
        echo "AppGrid can't load: $plugin" >&2
        echo "$missing" >&2
        exit 1
    fi
    echo "AppGrid OK: $plugin"
done

# ldd only sees missing libraries. Qt itself refuses a plugin built with a newer Qt than the one that
# runs – so it is loaded for real, the way Plasma does (QPluginLoader). Only where Qt for Python is
# there (installed before this script; the recipe checks later that it loads).
if python3 -c 'from PySide6.QtCore import QPluginLoader' 2>/dev/null; then
    python3 - "${plugins[@]}" <<'EOF'
import sys
from PySide6.QtCore import QCoreApplication, QPluginLoader, qVersion

app = QCoreApplication(sys.argv[:1])
bad = 0
for path in sys.argv[1:]:
    loader = QPluginLoader(path)
    if loader.load():
        print(f"AppGrid loads in Qt {qVersion()}: {path}")
    else:
        bad = 1
        print(f"AppGrid can't be loaded by Qt {qVersion()}: {path}\n  {loader.errorString()}", file=sys.stderr)
sys.exit(bad)
EOF
else
    echo "Qt for Python isn't in the image yet – AppGrid only checked with ldd"
fi
