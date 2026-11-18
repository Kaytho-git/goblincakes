#!/usr/bin/env bash
# demoparser2 (+ pandas, pyarrow, polars) for GoblinRecorder's CS2 demos – reads Valve's .dem
# files (recorder.cs2_demo_*) – and awpy for its line-of-sight check over the maps' walls (time to
# damage, crosshair placement; the map geometry is downloaded to ~/.cache when first needed). Not pinned: each image gets the newest version, so a CS2 update
# that changes the demo format is fixed by goblin update. Own folder, outside the system's
# Python packages. Optional: without it the window says the demo can't be read.
# Python 3.14 on purpose (18 Nov): demoparser2/awpy/pandas ship wheels per Python version and had none for
# Fedora 45's 3.15 – the install failed silently. recorder.cs2_demo_process runs the reader with python3.14.
set -uo pipefail
dnf5 -y install python3.14 || echo "python3.14 not available, skipping"
PY=$(command -v python3.14 || true)
DEST=/usr/lib/goblincakes/demoparser
VENV=$(mktemp -d)
if [ -n "$PY" ] && "$PY" -m venv "$VENV" && "$VENV/bin/pip" install --no-cache-dir --target "$DEST" demoparser2 awpy; then
    find "$DEST" -name __pycache__ -prune -exec rm -rf {} +
    echo "demoparser2 and awpy installed in $DEST"
else
    rm -rf "$DEST"
    echo "demoparser2 could not be installed, skipping"
fi
rm -rf "$VENV"
exit 0
