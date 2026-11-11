#!/usr/bin/env bash
# P18 (docs/optimering/granskning.md, 12 Nov): GOBLINCAKES' own Python modules and demoparser compiled
# once in the build. /usr can't be written on the computer, so without this Python compiled the source
# again at every start of every program (a CS2 demo 1.3–2.0 s → 0.4 s, the windows some hundredths).
# checked-hash: a fingerprint of the source instead of a time – every file in an atomic image has the date
# 1970 (the usual timestamp check would throw the files away, and it has a year-2038 limit), the same
# source gives the same file in every build (chunkah keeps its layer), and Python checks the fingerprint
# at each start: a source changed under `rpm-ostree usroverlay` is compiled anew, never an old file used
# (unchecked-hash would – user, 12 Nov: "no new millennium bug"). The check costs ~1 ms per file.
# -f rewrites pip's own timestamp files in demoparser.
# Never stops the build: without the files Python just compiles in memory as before.
set -uo pipefail
dirs=()
for d in /usr/share/goblincakes /usr/lib/goblincakes; do
    [ -d "$d" ] && dirs+=("$d")
done
if [ ${#dirs[@]} -gt 0 ] && python3 -m compileall -q -f -j 0 --invalidation-mode checked-hash "${dirs[@]}" >/dev/null; then
    echo "Python compiled: $(find "${dirs[@]}" -name '*.pyc' | wc -l) files, $(du -csh $(find "${dirs[@]}" -name __pycache__) 2>/dev/null | tail -1 | cut -f1)"
else
    echo "compileall had errors (some files stay uncompiled) – the build goes on"
fi
exit 0
