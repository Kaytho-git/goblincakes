# Karta över GOBLINCAKES – för Goblin AI

Hur GOBLINCAKES delar hänger ihop: vad varje del gör, vilka filer, hjälpprogram, tjänster och loggar den har,
hur man kollar den och vanliga fel. Läses av verktyget `goblincakes`. En del per `##`, `Ord:` = vad man kan
kalla delen. `Kontroll:` = ett kommando som bara läser – verktyget kör det och skickar med svaret (och säger
till om en GOBLINCAKES-sökväg i svaret inte finns). Håll varje del kort – detaljer står i koden.

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
- En omstart är ingen förklaring: föreslå den först när du har hittat och rättat det som var fel.
- Står det FINNS INTE vid en sökväg i kontrollen: den filen eller det programmet saknas – jämför stavningen
  med de som finns (`ls`), det är oftast felet.
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
Kontroll: `/usr/libexec/goblincakes-device-battery`
Kontroll: `grep -n 'Command:' /usr/share/plasma/plasmoids/org.goblincakes.nowplaying/contents/ui/main.qml ~/.local/share/plasma/plasmoids/org.goblincakes.nowplaying/contents/ui/main.qml`
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
Kontroll: `cat ~/.cache/goblincakes/updates.json`

## Byggstatus (GOBLINCAKES byggen på GitHub)
Ord: bygget, bygge, build, github actions, misslyckades bygget, byggloggen, ny image byggd
- Verktyget byggstatus (ai/buildstatus.py): de senaste byggena av build.yml (imagen) och build-iso.yml (ISO:n), det
  senaste misslyckade med variant, steg och orsaken ur byggloggen (loggen kräver GitHub-nyckeln från GitHub-servern i
  Goblin AI, ~/.config/goblincakes/mcp.env; utan den bara steget).
- Vakt-tjänsten tittar var 10:e minut (bara på en dator med repot, inte under spel) och ger en notis när ett bygge
  misslyckats – inget när det lyckas.
- "Säg till när bygget är klart": `bevaka bygge [commit]` – säger till både lyckat och misslyckat. Avbryts bygget av
  ett nyare (samma kö) följs det nyare. Claude lämnar också sådana bevakningar efter en push.
- Felet sitter oftast hos Fedora/Universal Blue (paket som krockar, en server nere) eller i GOBLINCAKES recept/skript
  – du ändrar aldrig koden i repot: förklara och föreslå Skicka till Claude.
- Kolla: `python3 /usr/share/goblincakes/ai/buildstatus.py`, ~/.local/state/goblincakes/byggstatus.json.

## Kontroll efter uppdatering
Ord: efter uppdateringen, efterkontroll, gick sönder, slutade fungera, ny image, startar inte efter uppdatering, rollback
- En gång per start, 3 min efter inloggningen (när inget spel kör), tittar vakt-tjänsten (goblincakes-kakan-vakt,
  ai/aftercheck.py) på GOBLINCAKES påslagna tjänster, misslyckade tjänster, toppfältet och widgetarnas fel
  (org.goblincakes.*), Ollama. Resultatet sparas per image i ~/.local/state/goblincakes/efterkontroll.json.
- Efter en ny image jämförs med förra imagen: bara det som fungerade före och är trasigt nu ger en notis
  ("Efter uppdateringen: N saker gick sönder", knappen Fråga Kakan). Allt bra = ingen notis.
- Var trasigt redan före = inte uppdateringens fel. Kända ofarliga fel (systemd-remount-fs, nvidia-settings-load)
  räknas inte.
- Det som gått sönder rättas del för del (logg → orsak → rätta, t.ex. starta om tjänsten); det du inte kan rätta
  går till Claude (Skicka till Claude). `rpm-ostree rollback` (förra versionen) är inte en lösning – bara om
  användaren själv ber om det, eller om datorn inte går att använda (inget skrivbord, inget nätverk) och
  rättningen redan misslyckats.
- Kolla: `python3 /usr/share/goblincakes/ai/aftercheck.py` (senaste resultatet), verktyget systemfel med
  "efter uppdateringen". Köra om nu: ta bort filen och kör `aftercheck.py check`.

## Toppfältet: kvot-widgeten (Claude och ChatGPT/Codex)
Ord: kvot, kvoten, gräns, användning, usage, limit, 5 h, veckokvot, Claude, Codex, ChatGPT, staplar
- Två staplar bredvid uppdateringspilen: vänster = Claude, höger = ChatGPT/Codex, hur mycket av 5-timmarsgränsen som är använt
  (orange från 75 %, röd från 90 %). Klick = ruta med 5 h och vecka i % och när de nollställs.
  Widget: /usr/share/plasma/plasmoids/org.goblincakes.quota. Den kör /usr/libexec/goblincakes-quota var 5:e minut,
  som sparar ~/.cache/goblincakes/quota.json.
- Claude läses med Claude Codes inloggning (~/.claude/.credentials.json), samma som /usage. "Inloggningen har gått ut" =
  starta Claude Code en gång (den förnyar inloggningen, widgeten gör det inte).
- Codex läses med ~/.codex/auth.json; går det inte används Codex senaste sessionslogg (~/.codex/sessions/).
- Inofficiella vägar: ändrar Anthropic/OpenAI dem står det "Kunde inte läsas" och senast lästa värden visas.
Kontroll: `/usr/libexec/goblincakes-quota` (skriver svaret, inga nycklar)

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
Ord: goblin ai, kakan, ai, chatt, meta+a, minne, lärdomar, kända lösningar, körda kommandon, ångra
- Fönstret /usr/bin/goblin-ai (Meta+A, goblin ai app), koden i /usr/share/goblincakes/ai/ (goblinai.py m.fl.).
- I terminalen: goblin ai = /usr/libexec/goblincakes-ai (prompt_toolkit, python3-prompt-toolkit i imagen; utan den en
  enkel rad). /app öppnar fönstret med samma samtal (goblin-ai --open <id>). Terminalens chattar sparas bland fönstrets.
  /projekt <namn> går in i ett projekt (projects.json), /projekt lämnar.
- Chattar, minne och lärdomar: ~/.local/share/goblincakes/ai/. Nycklar: ~/.config/goblincakes/ai.env – visa aldrig.
- Lärdomar och kända lösningar (kind "solution") i ~/.local/share/goblincakes/ai/lardomar.json, i kategorier, inget tak.
  Visas under AI-tjänster → Lärdomar och lösningar. Liknande (fältet similar) väljer användaren. Kända lösningar från
  Claude Code: python3 /usr/share/goblincakes/ai/solutions.py list [ord].
- Körda kommandon och hur de ångras: ~/.local/state/goblincakes/ai/kommandon.jsonl, säkerhetskopior bredvid.
  Användaren ångrar under AI-tjänster → Körda kommandon.
- Styra skrivbordet (verktyget skrivbord, ai/desktop.py): musik (MPRIS via busctl: paus/spela/nästa/förra/vad) och
  volym (wpctl = datorns, högst 100 %; "i GoblinAmp/Spotify" = spelarens MPRIS-Volume) körs direkt utan Tillåt (användarens val) och loggas som "kakan" med ångring.
  Öppna (program ur menyn via gtk-launch, webbsida/fil/mapp via xdg-open; spel efter 8 s) också direkt.
  Spela låt/album/artist: Spotifys Web API med GoblinAmp:s inloggning (~/.config/goblincakes/spotify.json).
  Notis (notify-send) och urklipp (wl-copy/wl-paste; gamla urklippet sparas för ångra, lösenord visas inte).
  Fönster: KWin-skriptet ai/windows.js via org.kde.kwin.Scripting (flytta, fram, maximera, fullskärm, minimera;
  "andra skärmen" = den programmet inte ligger på; stänga = Tillåt-kort).
  Spel (goblin plays ord, startar efter 8 s) och goblin-kommandon (läsande direkt, andra = Tillåt-kort).
  Kalendern: händelser skrivs i Merkuros fil (~/.config/akonadi_ical_resource_0rc → Path), Akonadi läser in dem själv;
  påminnelserna visas av kalendarac (pgrep kalendarac).
  Påminnelser och bevakningar (ai/reminders.py, tjänsten goblincakes-kakan-vakt.service tittar var 15:e s):
  påminn <när> ; <text> (notis med ljud, även under spel, "Om 10 min"-knapp), bevaka steam|uppdatering|nedladdning|
  stängt X|startat X|sida X [ord] (väntar tills spelet är stängt), fråga <när> ; <frågan> (du svarar då, svaret som
  notis + sparat samtal), påminnelser [bort]. Listan: ~/.local/share/goblincakes/ai/vakt.json. Missad tid (datorn av)
  kommer vid inloggning. Kolla: systemctl --user status goblincakes-kakan-vakt.
  Kolla spelarna: busctl --user list | grep mpris. Volymen: wpctl get-volume @DEFAULT_AUDIO_SINK@.
- Läsa hela webbsidor (verktyget sida, read_page i goblinai.py): Tavilys extract med nyckel, annars sidans HTML
  (sidor som byggs med JavaScript blir då nästan tomma). En länk i frågan läses först; "läs patch notes …" läser
  sökningens bästa träff. Adresser i datorn/hemnätverket läses inte. Svaret får Källor (länkar) och Hämtat från
  (filer, loggar, egna siffror).
- Stora texter i delar (goblinai.py, read_in_parts): ett verktygssvar större än ditt minne läses i delar om ~20 000
  tecken – varje del med tomt minne ("vad här hjälper frågan?") → korta anteckningar, ditt svar ur anteckningarna
  (stegen "Läser i delar: del n av m"). Högst 10 delar: början, slutet och de med frågans ord. ~10 s per del.
  Loggverktyget kortar annars loggen (början, slutet, felen); "hela"/"allt"/"mellan 22 och 23" i frågan, eller
  ```leta logg [program] hela [från HH:MM] [till HH:MM], ger varenda rad. "before-quit" före ett fel i Discord =
  Discord stängdes – ingen krasch, även om ljud-/delprocesser då "kraschar" och KDE visar en krasch. Kolla vad som
  stängde den: "System is rebooting"/"The system will reboot now" (datorn startades om, t.ex. efter en uppdatering)
  eller en ny app-<version>-mapp (Discords egen uppdatering). journalctl --list-boots visar omstarterna.
  Långa samtal (with_summary): de äldsta meddelandena sammanfattas en gång ("Tidigare i samtalet, sammanfattat: …"),
  bara när lokala AI:n svarar; sammanfattningen återanvänds tills fönstret stängs.
- Ärlighet (goblinai.py): faktafrågor utan något hämtat får "Ur minnet – inget hämtat eller kontrollerat" (FROM_MEMORY);
  "jag har läst/kollat …" utan verktyg skickas tillbaka en gång, sedan en Obs-rad (READ_CLAIM); "kan du …?" får
  listan över verktygen hon har just nu + det hon inte kan (abilities, CANNOT).

- MCP-servrar (färdiga verktyg utifrån, ai/mcp.py): ~/.config/goblincakes/mcp.json (mcpServers, samma form som Claude
  Code), nycklar i mcp.env (visa aldrig). Program körs i podman-containrar, startar vid första anropet, stängs efter
  5 min eller när ett spel startar. Läsande verktyg direkt, andra = Tillåt-kort. Verktygslistan cachas i
  ~/.local/state/goblincakes/ai/mcp-verktyg.json. Kolla: python3 /usr/share/goblincakes/ai/mcp.py lista;
  podman ps (servrar som kör). Användaren lägger till/stänger av under AI-tjänster → MCP-servrar.
  Webbläsaren (webblasare, mcr.microsoft.com/playwright/mcp): egen Chromium utan skärm och utan användarens
  inloggningar; öppna/läsa direkt, klicka/skriva = Tillåt. Tillåt-körningen (mcp.py kör) går via socketen
  $GOBLIN_MCP_SOCKET (/run/user/<uid>/goblincakes-mcp-<pid>.sock) till samma webbläsare. Sidor med
  Cloudflare-skydd (t.ex. wowhead.com) svarar 403 – läs dem med las_sida i stället.
- Dina egna verktyg som MCP-server för Claude Code (ai/kakan_mcp.py, servern "kakan"): bara de som läser –
  kartan, systemfel, leta-verktygen, wowstats, warcraftlogs, wowfel, cs2, sport. Inte skrivbordet, sökningen eller
  dina MCP-servrar. Läggs in med python3 /usr/share/goblincakes/ai/kakan_mcp.py claude. Kolla: claude mcp list
  (kakan ✔ Connected), python3 /usr/share/goblincakes/ai/kakan_mcp.py lista. Verktyget rapporter = dina rapporter.
- Skicka till Claude (ai/toclaude.py): under varje svar "Skicka till Claude" (Claude Code i en terminal i
  GOBLINCAKES-repot, löser problemet – användaren ser och godkänner) och "Fråga Claude" (claude -p utan fönster,
  får bara läsa, svaret kommer in i chatten). Även /claude och /claude fråga. Rapporten byggs ur samtalet (frågan,
  dina svar, steg, verktygens svar, kommandon med utdata) och sparas i ~/.local/share/goblincakes/till-claude/;
  Claudes svar skrivs sist i den. Modell: Sonnet. Kostar användarens Claude-kvot – föreslå knappen när du inte
  kommer vidare, men den trycks bara av användaren. Knapparna syns bara om Claude Code finns (~/.local/bin/claude).
- Testa åt Claude (ai/testlist.py): Claude lägger testlistor i ~/.local/share/goblincakes/testlistor/; /testa kör
  den nyaste (/testa <namn>, /testa stopp). Varje punkt = ett eget meddelande med vanligt kommandokort (läsande
  direkt, ändrande Tillåt, farliga stoppas); du bedömer utdatan mot "väntat" (OK/FEL/OKLART), frågor besvaras av
  användaren (ja/nej/hoppa). Resultatet sparas i till-claude/ (…-testresultat-….md), listan flyttas till klara/.
- Bygga egna widgetar: när användaren ber om en Plasma-widget får du en provad mall (WIDGET_GUIDE i goblinai.py:
  metadata.json + contents/ui/main.qml med PlasmoidItem, kpackagetool6 -t Plasma/Applet, prova med timeout 8
  plasmawindowed – felen står i journalen, `journalctl --user -t plasmawindowed`). Klart först när provet visar "Inga fel.".

## Lokal AI (Ollama)
Ord: lokal ai, ollama, modell, gemma, långsam ai, grafikminne
- Tjänsten goblincakes-ollama (/usr/libexec/goblincakes-ollama serve), inställningar ~/.config/goblincakes/ollama.json.
- Stängs medan ett spel kör (frigör grafikminnet) och startar igen efteråt.
- Kolla: `systemctl --user status goblincakes-ollama`, `journalctl --user -u goblincakes-ollama -n 50`.
Kontroll: `systemctl --user is-active goblincakes-ollama`

## GoblinRecorder
Ord: goblinrecorder, recorder, inspelning, spela in, obs, film, raid, mythic, m+, nyckel, cs2 klipp, wow stats, cs2 stats
- Spelar in WoW-raidbossar (pull till slut) och Mythic+-nycklar med OBS, CS2-matcher via spelets GSI.
- Tjänsten goblincakes-recorder (/usr/libexec/goblincakes-recorder run), fönstret /usr/bin/goblin-recorder
  (kod /usr/share/goblincakes/recorder/). Inställningar ~/.config/goblincakes/recorder.json, påslaget = flaggan
  ~/.config/goblincakes/recorder-on. Historik ~/.local/share/goblincakes/wow-history.json och cs2-history.json.
- Kolla: `systemctl --user status goblincakes-recorder`, `journalctl --user -u goblincakes-recorder -n 80`
  (varför en inspelning inte startade står där). Kräver OBS (Flatpak).
Kontroll: `systemctl --user is-active goblincakes-recorder`
Kontroll: `journalctl --user -u goblincakes-recorder -n 15 --no-pager`

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
Kontroll: `/usr/libexec/goblincakes-gameguard status`

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

## Lagmätaren
Ord: lagg, laggar, ping, laggknappen, meta+shift+l, lagmätning, hackar, nätet, paketförlust
- Meta+Shift+L = "laggar nu": noterar klockslaget och startar mätningen om den inte går
  (/usr/libexec/goblincakes-lagmeter mark, kortkommandot i /usr/share/kglobalaccel/goblincakes-lag.desktop).
- Tjänsten goblincakes-lagmeter (startas bara av Meta+Shift+L eller `goblincakes-lagmeter start`) mäter en rad
  per sekund: ping till spelets server och routern, processor, grafikkort (klocka, temp, varför det bromsar),
  RAM/swap, PSI, disk, nät, vilka program som tar processorn. Stannar 15 s efter spelet, efter 15 min utan spel
  eller 6 h. Filerna: ~/.local/state/goblincakes/lagmeter/*.jsonl (20 sparas).
- Frametider/fps kommer från MangoHud (Spelmätning, se goblin frames) – bara om det var på när spelet startade.
- Fönstret Lagmätning (`goblincakes-lagmeter window`, QML /usr/share/goblincakes/lagmeter/Main.qml) öppnas när
  mätningen startar: levande grafer (ping, processor, grafikkort, disk) för de senaste 2 minuterna, röd linje vid
  laggar nu. KWin-skriptet goblincakes-windows lägger det uppe till höger på skärmen där spelet inte är. Stängs en
  minut efter mätningen. Av/på: `goblincakes-lagmeter fönster av|på` (flagga ~/.config/goblincakes/lagmeter-window-off).
- Kolla: `goblincakes-lagmeter status`, `goblincakes-lagmeter rapport` (= verktyget lagg),
  `journalctl --user -u goblincakes-lagmeter`.
Kontroll: `/usr/libexec/goblincakes-lagmeter status`

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
  Discord-uppdateringar (/usr/libexec/goblincakes-vencord status/ensure). Bevakaren goblincakes-vencord.path
  vaknar när Discords uppdaterare skriver ~/.config/discord/installer.db (och tjänsten körs vid inloggning).
- Krasch i Discord under skärmdelning/stream (trådarna Voice/VideoEncoderQue/DiscordNvReadTh, signal 5) = Discords
  egen videokodning på Nvidia – inte Vencord. Prova: streama hela skärmen i stället för ett fönster, eller stäng av
  H.264-hårdvaruacceleration i Discord (Röst och video → Avancerat).
- Startar inte vid inloggning efter en Discord-uppdatering, och ~/.config/autostart/discord.desktop pekar på
  …/app-<version>/Discord → Discord har skrivit sin egen sökväg; inloggningen (goblincakes-refresh.sh) byter den mot
  startskriptet ~/.local/share/discord-app/discord. Byt inte versionsnumret för hand: kolla att startskriptet finns
  och be användaren logga ut och in.
Kontroll: `/usr/libexec/goblincakes-discord-voice`

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
