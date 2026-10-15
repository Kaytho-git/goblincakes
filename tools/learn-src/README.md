# Kursgrunden för lärläget – källan

Lektionerna, uppgifterna och kontrollerna i `files/system/usr/share/goblincakes/learn/<spår>/`
skrivs av skripten här (ett per spår): `python3 tools/learn-src/<spår>.py`. Ändra här, kör
skriptet och sedan `python3 tools/learn-validate.py` – varje uppgifts lösning måste klara sin
egen kontroll och startkoden får inte göra det.

Godot-spåret kör riktiga Godot: ange programmet med
`GOBLINCAKES_GODOT=/väg/till/Godot_v4.5.1-stable_linux.x86_64 python3 tools/learn-validate.py godot`
(samma version som i `sandbox/Containerfile`). Containerspåret kör övnings-podman
(`sandbox/podrun.py` + `fakepodman.py`) och behöver ingen riktig podman.
