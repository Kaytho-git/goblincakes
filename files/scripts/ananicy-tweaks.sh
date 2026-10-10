#!/usr/bin/env bash
# Changes CachyOS's ananicy-cpp rules where they get in the way.
# fossilize_replay = Steam's "Processing Vulkan shaders". CachyOS gives it the
# idle CPU and I/O class (only runs when nothing else wants the CPU/disk), so the
# processing before a game starts crawls while Steam is busy. Low priority is
# kept (nice 10) so it still yields to a running game, but it is no longer starved.
set -euo pipefail

rule=/etc/ananicy.d/00-default/Games/steam-shader-compilation.rules
if [[ -f $rule ]]; then
    cat > "$rule" <<'RULE'
# GOBLINCAKES: low priority but not idle (idle made "Processing Vulkan shaders" crawl)
{ "name": "fossilize_replay", "nice": 10, "sched": "other", "ioclass": "best-effort", "ionice": 7 }
RULE
    echo "ananicy-tweaks: fossilize_replay = nice 10, best-effort I/O"
else
    echo "ananicy-tweaks: WARNING $rule is missing – nothing changed"
fi
