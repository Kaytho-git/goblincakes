#!/usr/bin/env bash
# demoparser2 (+ pandas, pyarrow, polars) for GoblinRecorder's CS2 demos – reads Valve's .dem
# files (recorder.cs2_demo_*). Not pinned: each image gets the newest version, so a CS2 update
# that changes the demo format is fixed by goblin update. Own folder, outside the system's
# Python packages. Optional: without it the window says the demo can't be read.
set -uo pipefail
DEST=/usr/lib/goblincakes/demoparser
VENV=$(mktemp -d)
if python3 -m venv "$VENV" && "$VENV/bin/pip" install --no-cache-dir --target "$DEST" demoparser2; then
    find "$DEST" -name __pycache__ -prune -exec rm -rf {} +
    echo "demoparser2 installed in $DEST"
else
    rm -rf "$DEST"
    echo "demoparser2 could not be installed, skipping"
fi
rm -rf "$VENV"
exit 0
