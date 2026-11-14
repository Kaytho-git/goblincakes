#!/bin/bash
# Allt Claude behöver när användaren säger "hej" – i ett enda anrop (billigare).
# Bara läsning: git pull, Pågår-delen av senast-gjort.txt och Fedora-kollen (M17).
cd "$(dirname "$0")/.." || exit 1

echo "== git"
git pull -q 2>&1 | tail -2
echo "ej pushade commits: $(git rev-list --count origin/main..HEAD 2>/dev/null)"
git status --short | head -5

echo "== senast-gjort.txt (Pågår)"
[ -f senast-gjort.txt ] && sed -n '/^## Pågår/,/^## /{/^## Kvar/d;p}' senast-gjort.txt

echo "== Fedora (M17)"
for i in kinoite-main kinoite-nvidia; do
  skopeo inspect --no-tags "docker://ghcr.io/ublue-os/$i:latest" 2>/dev/null |
    python3 -c 'import json,sys; l=json.load(sys.stdin)["Labels"]; print(sys.argv[1], l.get("org.opencontainers.image.version"))' "$i" ||
    echo "$i: kunde inte läsas"
done
