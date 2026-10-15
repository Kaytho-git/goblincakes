#!/usr/bin/env python3
"""GOBLINCAKES lärläge: runs the user's Bash script (main.sh) with a practice podman. The
practice computer has no network and cannot start real containers inside itself, so `podman`,
`systemctl --user` (for quadlets) and `curl` are stand-ins (fakepodman.py) that behave and
answer like the real ones for the things the lessons use: images from a small built-in
registry, run/ps/logs/stop/rm/exec, ports, volumes, environment, build, pods and quadlets.
Commands inside the containers run for real in a folder of their own (the container's files)."""
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent


def main():
    script = sys.argv[1] if len(sys.argv) > 1 else "main.sh"
    state = tempfile.mkdtemp(prefix="goblincakes-podman-")
    home = Path(state) / "home"
    home.mkdir()
    fakebin = Path(state) / "bin"
    fakebin.mkdir()
    for name in ("podman", "systemctl", "curl", "docker"):
        p = fakebin / name
        p.write_text(f'#!/bin/sh\nexec python3 "{HERE / "fakepodman.py"}" {name} "$@"\n')
        p.chmod(0o755)
    env = dict(os.environ, PATH=f"{fakebin}:{os.environ.get('PATH', '/usr/bin:/bin')}",
               GOBLINCAKES_PODMAN_STATE=state, HOME=str(home), USER="goblin")
    try:
        r = subprocess.run(["bash", script], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env)
        sys.stdout.write(r.stdout)
        return r.returncode
    finally:
        shutil.rmtree(state, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
