#!/usr/bin/env bash
# GOverlay – settings window for MangoHud (the FPS meter in GOBLINCAKES Config → Inställningar).
# Optional: the build must not fail if Fedora doesn't have it.
set -uo pipefail
dnf5 -y install goverlay || echo "goverlay not available, skipping"
exit 0
