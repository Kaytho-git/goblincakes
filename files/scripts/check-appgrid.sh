#!/usr/bin/env bash
# After the COPR package (install-appgrid.sh) and our square-cornered build (copied from the
# appgrid-square stage): the image must have an AppGrid that loads, otherwise the top bar has
# no app menu – then the build stops and everyone keeps the image they have.
set -oue pipefail

marker=/usr/share/goblincakes/appgrid-build
echo "AppGrid build: $(cat "$marker" 2>/dev/null || echo missing)"

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
