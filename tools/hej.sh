#!/bin/bash
# Allt Claude behöver när användaren säger "hej" – i ett enda anrop (billigare).
# Bara läsning: git pull, Pågår-delen av senast-gjort.txt, Att göra i CLAUDE.md, testlistorna, Kakans omtag och Fedora-kollen (M17).
cd "$(dirname "$0")/.." || exit 1

echo "== git"
git pull -q 2>&1 | tail -2
echo "ej pushade commits: $(git rev-list --count origin/main..HEAD 2>/dev/null)"
git status --short | head -5

echo "== senast-gjort.txt (Pågår)"
[ -f senast-gjort.txt ] && sed -n '/^## Pågår/,/^## /{/^## Kvar/d;p}' senast-gjort.txt

echo "== Att göra (CLAUDE.md, ej avbockat)"
sed -n '/^## Att göra/,/^## /{/^- \[ \]/p}' CLAUDE.md | sed 's/ *(grep[^)]*)//g' | cut -c1-140

echo "== Testlistor som väntar"
ls ~/.local/share/goblincakes/testlistor/*.md 2>/dev/null | wc -l

echo "== Kakans omtag (kontroller som skickat tillbaka svar)"
python3 files/system/usr/share/goblincakes/ai/omtag.py kort 2>/dev/null

echo "== Fedora (M17)"
# Jämför receptens image-version med nästa Fedora-tagg hos Universal Blue
# (:latest kan ligga kvar på en äldre version, därför inte den).
for r in recipes/recipe.yml recipes/recipe-nvidia.yml; do
  bas=$(sed -n 's|^base-image: ghcr.io/ublue-os/||p' "$r")
  v=$(sed -n 's/^image-version: *//p' "$r")
  n=$((v + 1))
  if skopeo inspect --no-tags "docker://ghcr.io/ublue-os/$bas:$n" >/dev/null 2>&1; then
    echo "$bas: recepten $v, Fedora $n FINNS – fråga om hoppet"
  else
    echo "$bas: recepten $v, inget nytt"
  fi
done
