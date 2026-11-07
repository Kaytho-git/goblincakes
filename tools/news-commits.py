#!/usr/bin/env python3
"""Which commit each line of nyheter.txt came from (7 Nov, the user's wish: goblin update shows the commit
by each line). Run by the build (.github/workflows/build.yml) on a checkout with the whole history, before
the image is built; writes files/system/usr/share/goblincakes/nyheter-commits.json = {"<the line's text>":
"<short commit>"}. git blame = the commit that last changed the line (an edited line points at the edit).
Not in git itself (.gitignore) – a build artefact. Try it: python3 tools/news-commits.py"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NEWS = "files/system/usr/share/goblincakes/nyheter.txt"
OUT = ROOT / "files/system/usr/share/goblincakes/nyheter-commits.json"


def main():
    blame = subprocess.run(["git", "-C", str(ROOT), "blame", "--line-porcelain", "--", NEWS],
                           capture_output=True, text=True)
    if blame.returncode != 0:
        print(f"git blame gick inte: {blame.stderr.strip()}", file=sys.stderr)
        return 1
    commits, sha = {}, ""
    for line in blame.stdout.splitlines():
        if re.match(r"^[0-9a-f]{40} ", line):
            sha = line[:40]
        elif line.startswith("\t"):
            m = re.match(r"^(\d{4}-\d{2}-\d{2})\s{2,}(.+)$", line[1:].strip())
            if m and sha.strip("0"):                      # 000… = not committed yet
                commits[m.group(2).strip()] = sha[:7]
    OUT.write_text(json.dumps(commits, ensure_ascii=False, indent=0) + "\n")
    print(f"{len(commits)} nyhetsrader med commit → {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
