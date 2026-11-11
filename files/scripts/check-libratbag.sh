#!/usr/bin/env bash
# After our newer libratbag (copied from the libratbag-git stage over Fedora's package): ratbagd – the
# service Piper talks to – must start. Until 11 Nov nothing checked it, and the stage was built on another
# Fedora than the image of goblincakes-nvidia. A ratbagd that can't run stops the build: everyone keeps
# the image they have (Piper would otherwise silently find no mouse).
set -oue pipefail

built_on=$(cat /usr/share/goblincakes/libratbag-built-on 2>/dev/null || true)
echo "libratbag built on Fedora: ${built_on:-unknown}"
if [[ -n "$built_on" && "$built_on" != "$(rpm -E %fedora)" ]]; then
    echo "libratbag was built on Fedora $built_on, this image is Fedora $(rpm -E %fedora):" >&2
    echo "the \`from:\` lines in recipes/common-stages.yml / nvidia-stages.yml must name the recipe's base and version" >&2
    exit 1
fi

missing=$(ldd /usr/bin/ratbagd | grep 'not found' || true)
if [[ -n "$missing" ]]; then
    echo "ratbagd can't load:" >&2
    echo "$missing" >&2
    exit 1
fi
# Prints its version and ends – without the system bus, so it works in the build
if ! version=$(ratbagd --version 2>&1); then
    echo "ratbagd doesn't start: $version" >&2
    exit 1
fi
echo "ratbagd OK: $version"
