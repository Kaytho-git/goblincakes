#!/usr/bin/env bash
# GOBLINCAKES Levande (Levande utseende step 7, 11 Nov): the Plasma theme "goblincakes-levande" = the GOBLINCAKES
# theme with the top bar as tinted glass (Config → Utseende → Stil: Levande switches to it, Platt back). Made here
# from the one theme, so there is only one copy of it to change in the repo; only the files in
# /usr/share/goblincakes/plasma-levande differ.
set -oue pipefail

src=/usr/share/plasma/desktoptheme/goblincakes
dest=/usr/share/plasma/desktoptheme/goblincakes-levande
glass=/usr/share/goblincakes/plasma-levande
rm -rf "$dest"
cp -a "$src" "$dest"
cp "$glass/solid-panel-background.svg" "$dest/solid/widgets/panel-background.svg"
sed -i -e 's/"Id": "goblincakes"/"Id": "goblincakes-levande"/' \
       -e 's/"Name": "GOBLINCAKES"/"Name": "GOBLINCAKES Levande"/' \
       -e 's/"Description": "GOBLINCAKES: /"Description": "GOBLINCAKES Levande (tinted glass top bar): /' "$dest/metadata.json"
grep -q '"Id": "goblincakes-levande"' "$dest/metadata.json"
cmp "$glass/solid-panel-background.svg" "$dest/solid/widgets/panel-background.svg"
echo "GOBLINCAKES Levande Plasma theme in place"
