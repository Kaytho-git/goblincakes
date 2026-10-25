# Karta över GOBLINCAKES – för Goblin AI

Hur GOBLINCAKES delar hänger ihop: vad varje del gör, vilka filer, hjälpprogram, tjänster och loggar den har,
hur man kollar den och vanliga fel. Läses av verktyget `goblincakes`. En del per `##`, `Ord:` = vad man kan
kalla delen. Håll varje del kort – detaljer står i koden.

## Allmänt: så felsöker du GOBLINCAKES
Ord: felsöka, fungerar inte, syns inte, trasig, slutat, system, atomiskt, rollback, logg, journal
- Systemet är atomiskt: allt under /usr är skrivskyddat och byts ut vid varje uppdatering. Det går inte att ändra där.
- Användarens egna kopior går före systemets: en widget i ~/.local/share/plasma/plasmoids/<id>/ används i stället
  för /usr/share/plasma/plasmoids/<id>/, ett KWin-skript i ~/.local/share/kwin/scripts/ före /usr/share/kwin/scripts/,
  en tjänst i ~/.config/systemd/user/ före /usr/lib/systemd/user/. Finns en egen kopia är det den som gäller – och
  den som kan vara fel. Jämför den med systemets: `diff /usr/share/... ~/.local/share/...`.
- Inställningar: ~/.config/goblincakes/ (en fil per program). Tillstånd och flaggor: ~/.local/state/goblincakes/.
  Data: ~/.local/share/goblincakes/.
- Hjälpprogrammen /usr/libexec/goblincakes-* går att köra för hand för att se vad de svarar.
- Loggar: `journalctl --user -u <tjänst> -n 50` för användartjänster, `journalctl --user -b -p warning` för allt i
  sessionen. Plasmas widgetar och toppfält loggar under `plasma-plasmashell`.
- Ordning: 1) vad ska delen göra, 2) kör/läs det den bygger på (hjälpprogram, fil, tjänst), 3) jämför med vad
  koden förväntar sig (sökvägar, namn), 4) rätta det som skiljer – bara i användarens egna filer.
- Tillbaka till förra systemet efter en dålig uppdatering: `rpm-ostree rollback` och starta om.

## Toppfältet: widgeten Spelas nu
Ord: toppfält, toppfältet, panel, widget, spelas nu, nowplaying, batteri, laddning, mus, musen, headset, tangentbord, handkontroll, musik, discord röst, steam nedladdning, kakans steg
- Det som syns mitt i toppfältet: öppna program, musik som spelas (MPRIS), Discord-röstkanal, Steams nedladdning
  och shaders, vad Goblin AI gör (stegen) och batteriet i trådlösa enheter (mus, headset, tangentbord, handkontroll).
- Kod: /usr/share/plasma/plasmoids/org.goblincakes.nowplaying/contents/ui/main.qml (QML). En egen kopia i
  ~/.local/share/plasma/plasmoids/org.goblincakes.nowplaying/ används i stället om den finns.
- Widgeten kör hjälpprogram med fasta sökvägar (egenskaper i main.qml, t.ex. `batteryCommand`):
  - batteri: /usr/libexec/goblincakes-device-battery – skriver en JSON-lista, t.ex.
    `[{"kind": "mouse", "name": "…", "percent": 75, "charging": false}]` (läser UPower). Var 30:e sekund.
  - Discord-röst: /usr/libexec/goblincakes-discord-voice
  - Goblin AI:s steg: /usr/libexec/goblincakes-ai-activity
- Kolla: kör hjälpprogrammet för hand – svarar det rätt? Läs sedan sökvägen i widgetens main.qml (även den egna
  kopian) och jämför exakt med programmets namn: `grep -n Command <main.qml>` och `ls /usr/libexec/goblincakes-*`.
  Är programmet rätt men inget syns, ligger felet i widgeten.
- En ändrad widget läses in först efter `systemctl --user restart plasma-plasmashell` (toppfältet blinkar till).
- Enheter utan batteri i UPower (många sladdade headset) syns inte – det är inget fel.

## Toppfältet: uppdateringspilen och uppdateringar
Ord: uppdatering, uppdatera, update, grön pil, pilen, goblin update, automatiska uppdateringar, ny version, stäng av, rpm-ostree, flatpak
- Grön pil i toppfältet = något nytt (ny GOBLINCAKES-version, en som hämtas, en som väntar på omstart, Flatpaks).
  Widget: /usr/share/plasma/plasmoids/org.goblincakes.updates. Den läser ~/.cache/goblincakes/updates.json som
  /usr/libexec/goblincakes-updates check skriver (tjänsten/timern goblincakes-updates, vid inloggning och var 4:e timme).
- `goblin update` uppdaterar allt (systemet, Flatpaks, AppImages, Discord, Proton, firmware); `--only <del>` en del.
- Automatiska uppdateringar: reglage i Config → Uppdatera. Under spel väntar de (spelläget).
- Uppdatera och stäng av: /usr/libexec/goblincakes-update-poweroff, logg ~/.local/state/goblincakes/update-poweroff.log.
- Kolla: `rpm-ostree status` (vilken version, väntar en på omstart?), `journalctl --user -u goblincakes-updates`.

## Dockan och AppGrid
Ord: docka, dockan, aktivitetsfält, appgrid, programmeny, meta+z, ikoner nere
- Dockan längst ner döljs av sig själv; Meta+Z tar fram den (även över spel). AppGrid = programmenyn.
- Hjälpprogram: /usr/libexec/goblincakes-dock (`goblin dock`). Meta+Z sköts av KWin-skriptet goblincakes-windows.
- `goblin dock reset` återställer hela GOBLINCAKES-utseendet (tema, typsnitt, toppfält, docka).

## GOBLINCAKES Config
Ord: config, inställningar, goblincakes config, program, förinstallerat, fönster, grafik, uppdatera, reglage
- Fönstret för val och inställningar: /usr/bin/goblincakes-config, QML i /usr/share/goblincakes/config/.
  Flikar: Program, Förinstallerat, Inställningar, Fönster, Grafik, Uppdatera.
- Reglagen i Inställningar körs av /usr/libexec/goblincakes-tweak (status/set per reglage); installationer i
  Program av /usr/libexec/goblincakes-config-install.

## goblin-kommandot
Ord: goblin, kommando, terminal, goblin help
- /usr/bin/goblin (bash): `goblin help` listar alla. Hjälpprogrammen ligger i /usr/libexec/goblincakes-*.

## Goblin AI (du själv)
Ord: goblin ai, kakan, ai, chatt, meta+a, minne, lärdomar, körda kommandon, ångra
- Fönstret /usr/bin/goblin-ai (Meta+A), koden i /usr/share/goblincakes/ai/ (goblinai.py m.fl.).
- Chattar, minne och lärdomar: ~/.local/share/goblincakes/ai/. Nycklar: ~/.config/goblincakes/ai.env – visa aldrig.
- Körda kommandon och hur de ångras: ~/.local/state/goblincakes/ai/kommandon.jsonl, säkerhetskopior bredvid.
  Användaren ångrar under AI-tjänster → Körda kommandon.

## Lokal AI (Ollama)
Ord: lokal ai, ollama, modell, gemma, långsam ai, grafikminne
- Tjänsten goblincakes-ollama (/usr/libexec/goblincakes-ollama serve), inställningar ~/.config/goblincakes/ollama.json.
- Stängs medan ett spel kör (frigör grafikminnet) och startar igen efteråt.
- Kolla: `systemctl --user status goblincakes-ollama`, `journalctl --user -u goblincakes-ollama -n 50`.

## GoblinRecorder
Ord: goblinrecorder, recorder, inspelning, spela in, obs, film, raid, mythic, m+, nyckel, cs2 klipp, wow stats, cs2 stats
- Spelar in WoW-raidbossar (pull till slut) och Mythic+-nycklar med OBS, CS2-matcher via spelets GSI.
- Tjänsten goblincakes-recorder (/usr/libexec/goblincakes-recorder run), fönstret /usr/bin/goblin-recorder
  (kod /usr/share/goblincakes/recorder/). Inställningar ~/.config/goblincakes/recorder.json, påslaget = flaggan
  ~/.config/goblincakes/recorder-on. Historik ~/.local/share/goblincakes/wow-history.json och cs2-history.json.
- Kolla: `systemctl --user status goblincakes-recorder`, `journalctl --user -u goblincakes-recorder -n 80`
  (varför en inspelning inte startade står där). Kräver OBS (Flatpak).

## GoblinAmp
Ord: goblinamp, amp, musikspelare, winamp, spotify, spellista, låtar, mediatangenter
- /usr/bin/goblin-amp (kod /usr/share/goblincakes/amp/), inställningar ~/.config/goblincakes/amp.json och
  spotify.json, Last.fm lastfm.json. Spotify-appen startas dold av /usr/libexec/goblincakes-spotify-app.
- `goblin amp hjälp` visar hur Spotify-listorna ställs in.

## goblin graph
Ord: graph, ljudgraf, staplar, visualisering
- /usr/bin/goblin-graph (QML i /usr/share/goblincakes/graph/), tjänsten goblincakes-graph öppnar den när musik
  spelas om `goblin graph auto on`. Inställningar ~/.config/goblincakes/graph.json. Vilar under spel.

## Spelläget
Ord: spelläge, gamemode, spel, prestanda, lagg, fps, wowup stängs, akonadi, baloo
- Tjänsten goblincakes-gameguard (/usr/libexec/goblincakes-gameguard run) ser var 3:e sekund om ett spel kör:
  GameMode, uppdateringar väntar, Akonadi/Baloo vilar, WoWUp stängs medan WoW kör. Allt återställs efter spelet.
- Vad som räknas som spel: /usr/share/goblincakes/gaming.py. Reglage: Config → Inställningar → Spel.
- Kolla: `goblincakes-gameguard status` (/usr/libexec/), `journalctl --user -u goblincakes-gameguard -n 50`.

## goblin frames och MangoHud
Ord: frames, fps, mangohud, 1% low, ryck, stutter, frametider
- `goblin frames` visar hur jämnt spelet gick (fps, 1 % low, ryck); mätningen sparas i
  ~/.local/state/goblincakes/frames/. Notis efter spelet: tjänsten goblincakes-frames.
- MangoHud: reglage i Config, inställningar i GOverlay; GOBLINCAKES standard /usr/share/goblincakes/mangohud/.

## WoW och tilläggen
Ord: wow, world of warcraft, battle.net, tillägg, addon, addons, bugsack, lua-fel, wowup, archon, wtf
- WoW installeras via Battle.net i Lutris (eller Steam). `goblin wow` länkar alla versioner under ~/Games/WoW/
  (<version>/AddOns, Logs, WTF) – det är länkar till där spelet verkligen ligger (…/_retail_/Interface/AddOns).
- Fel i ett tillägg: verktyget wowfel visar BugSacks fel med fil och radnummer. Läs raden i tilläggets fil, rätta
  den (sed -i … ett Tillåt-kort – filen säkerhetskopieras först), och be användaren skriva `/reload` i spelet.
  Ett tillägg med en .git-mapp är användarens eget: `git -C <mappen> diff` visar vad som ändrats sedan senast.
- Ändra aldrig spelets egna filer – bara tilläggens filer och inställningar.
- WoWUp uppdaterar tilläggen; Archons ikon i systemfältet: tjänsten goblincakes-archon-tray.

## Steam och spel
Ord: steam, proton, spel startar inte, goblin play, tv-läge, big picture, lutris, heroic
- Steam finns i systemet. `goblin play <namn>` startar Steam-spel från terminalen (/usr/libexec/goblincakes-games),
  egna ord i ~/.config/goblincakes/game-aliases. TV-läge: `goblin tv`.
- Krascher syns med verktyget systemfel (coredumps).

## Discord
Ord: discord, röstkanal, vencord, discord-tema
- Discords egen Linux-version i ~/.local/share/discord-app (inte Flatpak), uppdateras med
  `goblin update --only discord`. Röstkanalen i toppfältet: /usr/libexec/goblincakes-discord-voice.
- GOBLINCAKES-utseendet (Vencord) är ett eget val i Config; tjänsten goblincakes-vencord lägger in det igen efter
  Discord-uppdateringar (/usr/libexec/goblincakes-vencord status/ensure).

## Ianseo
Ord: ianseo, bågskytte, tävling, resultat, container
- Ianseo körs i containrar (podman, filer i /usr/share/goblincakes/ianseo/), styrs av /usr/libexec/goblincakes-ianseo.
  Säkerhetskopia av databasen var 30:e minut (goblincakes-ianseo-backup). Ikon i systemfältet när den nås från andra
  enheter (goblincakes-ianseo-tray). Rör aldrig dess lagring (volymerna).
- Kolla: `podman ps`, `/usr/libexec/goblincakes-ianseo network status` och `internet status`.

## Skärmar och fönster
Ord: skärm, skärmar, hz, uppdateringsfrekvens, fönster, tiling, rutor, layout, goblin screen, goblin tile, kwin
- Vilken skärm ett program öppnas på: `goblin screen` (/usr/libexec/goblincakes-screen). Olika Hz: goblincakes-screens.
- Rutor/layouter: `goblin tile` och Config → Fönster, ~/.config/goblincakes/tile-layouts.json.
- KWin-skriptet /usr/share/kwin/scripts/goblincakes-windows placerar fönster (Config i mitten, spel på rätt skärm,
  rutor, Meta+Z). Kolla `journalctl --user -b | grep -i goblincakes-windows`.

## Grafikkort och drivrutiner
Ord: grafikkort, gpu, nvidia, drivrutin, amd, secure boot, variant
- Tre varianter: goblincakes (AMD/Intel), goblincakes-nvidia, goblincakes-nvidia-legacy (GTX 900/10).
  Byte: Config → Grafik (/usr/libexec/goblincakes-gpu). Vilken som körs: `rpm-ostree status`.
- Kolla: `nvidia-smi`, `lspci -k | grep -A3 -i vga`.

## Diskar
Ord: disk, diskar, hårddisk, usb, montera, automount, ägare, rättigheter
- Alla diskar monteras vid inloggning (/usr/libexec/goblincakes-automount) under /run/media/$USER/<namn>;
  goblincakes-disk-owner gör användaren till ägare av nya Linux-diskar.

## Utseende och färg
Ord: utseende, tema, färg, accent, accentfärg, låsskärm, inloggning, sddm, ikoner, typsnitt
- Accentfärgen: `goblin färg` / Config (/usr/libexec/goblincakes-accent, även inloggningsskärmen via
  goblincakes-sddm-accent). Utseendet läggs på vid första inloggningen av /usr/libexec/goblincakes-firstlogin.
- `goblin dock reset` återställer allt utseende.

## Webbläsare och webbappar
Ord: webbläsare, chrome, firefox, brave, webapp, webbapp
- Huvudwebbläsaren: Config → Program (/usr/libexec/goblincakes-browser). Webbappar får ikon av
  goblincakes-webapp-icon.

## Ljud
Ord: ljud, pipewire, latens, mikrofon, headset, högtalare
- PipeWire med låg latens: /usr/share/goblincakes/pipewire/. Kolla: `wpctl status`, `pactl list sinks short`.

## Laptop
Ord: laptop, bärbar, batteri laptop, dubbla grafikkort
- /usr/libexec/goblincakes-laptop körs vid inloggning (gör inget på stationära).

## ChatGPT-appen
Ord: chatgpt, openai-appen
- OpenAIs app uppackad i hemmappen, startas med /usr/libexec/goblincakes-chatgpt; uppdateras med goblin update.
