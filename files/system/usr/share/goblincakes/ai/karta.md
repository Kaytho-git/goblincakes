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
- GOBLINCAKES egna fönster (Config, Goblin AI, GoblinRecorder, Dashboard, GoblinAmp, GoblinShare, goblin graph,
  Avinstallera, lagmätaren, röstrutan) laddar sin QML från en kopia i ~/.cache/goblincakes/qml-src/<nyckel>/ (görs
  om av sig själv när imagen ändrats – /usr/share/goblincakes/qmlcache.py). Ett fönster som ser gammalt/trasigt ut
  efter en uppdatering: ta bort ~/.cache/goblincakes/qml-src och öppna fönstret igen (det är bara en kopia).
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
- Efter en full laddning visar widgeten 100 % fast musen själv säger t.ex. 91 % – avsiktligt: musens första
  siffra efter laddningen sparas som topp i ~/.cache/goblincakes/device-battery.json och räknas om till 100 %
  (ner till 50 %, under det visas musens egen siffra). Skiljer sig siffran från G HUB/upower är det inget fel.

## Toppfältet: uppdateringspilen och uppdateringar
Ord: uppdatering, uppdatera, update, grön pil, pilen, goblin update, automatiska uppdateringar, ny version, stäng av, rpm-ostree, flatpak
- Grön pil i toppfältet = något nytt (ny GOBLINCAKES-version, en som hämtas, en som väntar på omstart, Flatpaks).
  Widget: /usr/share/plasma/plasmoids/org.goblincakes.updates. Den läser ~/.cache/goblincakes/updates.json som
  /usr/libexec/goblincakes-updates check skriver (tjänsten/timern goblincakes-updates, 2,5 min efter inloggning och var 4:e timme – tills dess visar pilen förra svaret).
- `goblin update` uppdaterar allt (systemet, Flatpaks, AppImages, Discord, Proton, firmware); `--only <del>` en del.
  Firmware som datorn redan nekat (fwupdmgr get-history: misslyckad, samma version) hoppas över tyst – t.ex. Lenovos
  som vägrar Microsofts nya Secure Boot-nyckel (KEK 2023); en ny version provas igen. Kolla: `fwupdmgr get-history`.
- Automatiska uppdateringar: reglage i Config → Uppdatera. Under spel väntar de (spelläget).
- Uppdatera och stäng av ("uppdatera när bygget är klart och stäng sen av datorn"): `goblin update --stäng-av` (Tillåt-kort; = Config → Uppdatera och stäng av) – väntar på bygget som pågår, uppdaterar, väntar på spel, stänger av efter två minuter med Avbryt; aldrig om något misslyckas. En bevakning gör inte detta (bara en notis). Avbryt: `goblin update --avbryt`. Läge: /usr/libexec/goblincakes-update-poweroff status, logg ~/.local/state/goblincakes/update-poweroff.log.
- Bakgrundsjobben ger plats åt användaren (för hårddiskar): Flatpaks automatiska uppdatering (flatpak-system-update/
  flatpak-user-update) körs 20 min efter start eller 04:00, med lägsta disk- och processorprioritet; `flatpak repair`
  bara en gång i veckan (/usr/libexec/goblincakes-idle-jobs repair, stämpel /var/lib/goblincakes/idle-jobs/ resp.
  ~/.local/state/goblincakes/idle-jobs/). Fedoras programlista och manualsidor (fedora-atomic-desktop-appstream-cache-refresh,
  -mandb-update) byggs bara om när imagen ändrats ("Skipped due to 'exec-condition'" i journalen = rätt). Tilläggsfilerna:
  /usr/lib/systemd/{system,user}/<tjänst>.d/goblincakes-*.conf. Kolla: `systemctl list-timers`, `systemd-analyze blame`.
- Kolla: `rpm-ostree status` (vilken version, väntar en på omstart?), `journalctl --user -u goblincakes-updates`.
- Notisen "GOBLINCAKES finns nu på Fedora N": goblincakes-fedora-check.service, startas efter varje uppdateringskoll. Kolla: `journalctl --user -u goblincakes-fedora-check`, `cat ~/.local/state/goblincakes/fedora-notified`.
Kontroll: `cat ~/.cache/goblincakes/updates.json`

## Byggstatus (GOBLINCAKES byggen på GitHub)
Ord: bygget, bygge, build, github actions, misslyckades bygget, byggloggen, ny image byggd, vad har bygget med sig
- Verktyget byggstatus (ai/buildstatus.py): de senaste byggena av build.yml (imagen) och build-iso.yml (ISO:n), det
  senaste misslyckade med variant, steg och orsaken ur byggloggen (loggen kräver GitHub-nyckeln från GitHub-servern i
  Goblin AI, ~/.config/goblincakes/mcp.env; utan den bara steget).
- "Vad har bygget med sig?": byggstatus visar commitsen i det senaste bygget sedan förra lyckade (en fråga till
  GitHub). Ett äldre bygge: ge dess commit-id (`byggstatus dac736b`). Leta inte commit för commit med GitHub-servern.
- Vakt-tjänsten tittar var 10:e minut (bara på en dator med repot, inte under spel) och ger en notis när ett bygge
  misslyckats – inget när det lyckas.
- "Säg till när bygget är klart": `bevaka bygge [commit]` – säger till både lyckat och misslyckat. Avbryts bygget av
  ett nyare (samma kö) följs det nyare; flera bevakningar som hamnar på samma bygge blir en (`_same_build`). Claude lämnar också sådana bevakningar efter en push.
- Basvarianten (goblincakes) styckas om efter innehåll i slutet av bygget (chunkah, 11 nov) – steget "Running Chunkah"
  tar några minuter extra; fel där = byggsteget, inte receptet.
- Före bygget går jobbet "Kontroll före bygget" (tools/check.py, 11 nov): syntax i Python/skal/JSON, att fönstrens
  QML kompilerar och att kopiorna (låsskärm, utloggning, webbläsarpolicyerna, fitTileToWindow) är lika. Faller det
  byggs ingen variant (de visas som överhoppade) – orsaken är raden med FEL/::error:: i loggen, felet är i repot.
- Felet sitter oftast hos Fedora/Universal Blue (paket som krockar, en server nere) eller i GOBLINCAKES recept/skript
  – du ändrar aldrig koden i repot: förklara och föreslå Skicka till Claude.
- Fedora-versionen är låst i recepten (11 nov): recipes/recipe*.yml `image-version` (45 för goblincakes och
  goblincakes-nvidia-legacy, 44 för goblincakes-nvidia) – en ny Fedora kommer först när användaren höjer siffran.
  Byggstegen (AppGrid, libratbag) byggs på samma bas: recipes/common-stages.yml (kinoite-main) och
  recipes/nvidia-stages.yml (kinoite-nvidia), raderna `from:`. Skiljer de sig från receptet stoppas bygget av
  check-appgrid.sh / check-libratbag.sh ("was built on Fedora X, this image is Fedora Y") – då ska `from:` rättas.
  Samma skript stoppar bygget om AppGrid inte går att ladda i imagens Qt eller om ratbagd inte startar.
- Kolla: `python3 /usr/share/goblincakes/ai/buildstatus.py`, ~/.local/state/goblincakes/byggstatus.json;
  vilken Fedora delarna byggdes på: `cat /usr/share/goblincakes/appgrid-built-on /usr/share/goblincakes/libratbag-built-on`.

## Kontroll efter uppdatering
Ord: efter uppdateringen, efterkontroll, gick sönder, slutade fungera, ny image, startar inte efter uppdatering, rollback
- En gång per start, 3 min efter inloggningen (när inget spel kör), tittar vakt-tjänsten (goblincakes-kakan-vakt,
  ai/aftercheck.py) på GOBLINCAKES påslagna tjänster, misslyckade tjänster, toppfältet och widgetarnas fel
  (org.goblincakes.*), Ollama, GoblinRecorders CS2-demoläsare (demoparser2/awpy, bara med GoblinRecorder på). Resultatet sparas per image i ~/.local/state/goblincakes/efterkontroll.json.
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
- Dockan = GOBLINCAKES egen widget `org.goblincakes.dock` (/usr/share/plasma/plasmoids/org.goblincakes.dock, sedan 29 okt; ersatte Plasmas icontasks – engångsfixen `goblincakes-dock` i goblincakes-refresh.sh bytte pluginnamnet i den nedre panelen) – bara fästa program (öppna program finns i toppfältet), öppen-markering i accentfärgen, ikonerna växer i en våg under musen inom ramen, flera fönster av samma program → lista. Inställningar: Config → Inställningar → Dockan, `goblin dock get` / `goblin dock set scale|zoom|zoomFactor|zoomRange <värde>` (Storlek sätter även panelens höjd = 48 × storlek + 8), eller högerklick → Konfigurera. Fästa program: `launchers` i ~/.config/plasma-org.kde.plasma.desktop-appletsrc under widgeten (Config, `goblin play dock` och terminalbytet skriver där). Panelens egen bakgrund är osynlig (temats translucent/widgets/panel-background.svg) – dockan ritar sin ram själv. Efter inloggning kikar dockan upp 1,5 s med upplyst ram = redo. Bara första ikonen svarar / dockan gömmer sig när musen går vidare → panelens mus-område fel: temats translucent/widgets/panel-background.svg måste ha `mask-*`-elementen (de synliga är genomskinliga). Fel: `journalctl --user -b -o cat _COMM=plasmashell | grep goblincakes.dock`.
- Klick på en ikon i nya dockan gör inget/fel (t.ex. öppet program minimeras inte) → panelen tar fokus vid trycket, så programmet är redan inaktivt när klicket kommer (`task.active` falskt) → `activate(task, wasActive)` i main.qml räknar programmet som aktivt om det tappade fokus <1 s sen; kolla med `console.warn` i `activate` + `journalctl --user _COMM=plasmashell`.

## GOBLINCAKES Dashboard
Ord: dashboard, dashboarden, överblick, instrumentpanel, helskärm, öppna program, alla program, sök program
- Steg 1 (10 nov): ett eget helskärmsfönster som startas för hand – `goblin dashboard` (samma kommando gömmer det),
  menyposten GOBLINCAKES Dashboard. Med standardupplägget (toppfält och docka) öppnar Meta AppGrid; med upplägget
  Dashboard (steg 4 nedan) tar Meta fram dashboarden.
- /usr/bin/goblin-dashboard (fönstret, kod /usr/share/goblincakes/dashboard/: Main.qml, dash.py = allt som läses,
  windows.js = KWin-skriptet för öppna fönster – växla till och stänga via högerklick). Processen ligger kvar gömd
  efter Esc så att den kommer upp direkt; `goblin dashboard stäng` avslutar den. Inget läses medan den är gömd.
- Program som startas från dashboarden (program, projekt, Fråga Kakan, Anpassa, länkar) får en egen enhet
  app-goblincakes-<namn>-<slump>.scope (dash.start via systemd-run --scope) – inte dashboardens. Kolla:
  systemctl --user list-units 'app-goblincakes-*'
- Klockraden (12 nov): gömd som standard (Plasmas autohide, fram vid överkanten i mitten) eller framme på tomt skrivbord
  (Config → Utseende → "Visa klockraden när skrivbordet är tomt" = dodgewindows; gömmer sig bara för det AKTIVA
  fönstret – raden över ett program när man klickat på andra skärmen är väntat). `goblincakes-desktop-layout row`
  visar läget, `row hidden|empty` byter; sparat som rowHiding i ~/.config/goblincakes/desktop-layout.json.
- Meta i upplägget Dashboard = KWin-skriptet goblincakes-windows (kortkommandot "GOBLINCAKES Dashboard" under
  KWin i Systeminställningar → Genvägar) som anropar D-Bus org.goblincakes.dashboard /dashboard toggle; D-Bus startar
  dashboarden (/usr/share/dbus-1/services/org.goblincakes.dashboard.service, egen enhet
  dbus-:1.x-org.goblincakes.dashboard@N.service) om den inte kör. Meta gör inget → kolla att åtgärden har Meta:
  `busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel shortcut as 4 kwin "GOBLINCAKES Dashboard" KWin "GOBLINCAKES: visa eller göm dashboarden"`
  (ska ge 16777250) och att startmenyn inte har den; lagas med `/usr/libexec/goblincakes-desktop-layout login`.
- Inställningar: ~/.config/goblincakes/dashboard.json (`views` = vyerna [{name, left, right, mid}], `view` = den som
  visas, `apps` = egna program nederst – saknas den används dockans fästa program). Ändras i GOBLINCAKES Config →
  DASHBOARD (eller knappen Anpassa i dashboarden); dashboarden läser om dem varje gång den visas. Projekten = samma lista som Goblin AI:s PROJEKT → MAPPAR
  (~/.config/goblincakes/ai-mappar.json). Kvoten = ~/.cache/goblincakes/quota.json (kvot-widgetens fil).
- 11 nov: ikonraden under loggan = nätverk, ljud, Bluetooth, urklipp, enheter + KVOT (mätare, röd vid ≥ 90 %, tryck =
  liten ruta) + strömknappen (D-Bus org.kde.LogoutPrompt /LogoutPrompt promptAll = avstängningsrutan). + bredvid
  PROJEKT = dashboardens egen mappväljare i mitten (`python3 dash.py browse [mapp]`; inte systemets dialog), ✕ på
  ett projekt = ur listan. SYSTEM-ramen utan DISK (den finns i mitten). PROJEKT tar resten av spalten och rullar själv.
- NOTISER (11 nov, klockan bland ikonerna under loggan, siffra = olästa sedan rutan öppnades senast): Plasmas egen
  notishistorik går inte att läsa utanför plasmashell, så användartjänsten goblincakes-notifications.service
  (/usr/libexec/goblincakes-notifications watch – en D-Bus-monitor på sessionsbussen som bara läser Notify-anropen,
  svaren och NotificationClosed) sparar de 40 senaste i ~/.local/state/goblincakes/notiser.json (bara läsbar för
  användaren). Rutan visar de som fortfarande finns i Plasmas lista (inte bortklickade eller stängda av programmet);
  tryck på en = öppna programmet om det har ett eget fönster (synlig desktop-entry:
  Discord, ChatGPT, Steam), annars får du notisen som fråga (`goblin-ai --ask`, `notice_question` i dash.py) – byggen,
  påminnelser, krascher, systemnotiser – och kollar vad den innebär), Rensa = tömmer rutan (dashboard.json `noticesCleared`; `noticesSeen`
  = när den öppnades). Kolla: `systemctl --user status goblincakes-notifications`, `/usr/libexec/goblincakes-notifications list`,
  `python3 /usr/share/goblincakes/dashboard/dash.py notices`. "Notiserna läses inte" i rutan = filen saknas (tjänsten
  har aldrig kört). Prova: `notify-send Test hej` – ska komma överst i rutan.
- Notisrutorna (Plasmas egna) dyker upp nere till höger: /etc/xdg/plasmanotifyrc `PopupPosition=BottomRight` (11 nov –
  uppe till höger hamnade halva rutan utanför skärmen under systemfältspanelen). Användarens eget val i
  ~/.config/plasmanotifyrc går före. Kolla: `kreadconfig6 --file plasmanotifyrc --group Notifications --key PopupPosition`.
- Varifrån siffrorna kommer: CPU /proc/stat, minne /proc/meminfo, grafikkort /sys/class/drm/card*/device/gpu_busy_percent
  (AMD/Intel) eller nvidia-smi, temperatur /sys/class/hwmon (k10temp/coretemp/amdgpu), disk = hemmappen + monterade
  diskar; musiken = MPRIS via busctl; nätverk nmcli, ljud wpctl, Bluetooth bluetoothctl, urklipp Klipper (D-Bus),
  enheter goblincakes-device-battery + lsblk.
- Öppna program tomt fast program är öppna → KWin svarade inte: dashboarden laddar windows.js via
  org.kde.KWin /Scripting och får svaret på D-Bus-tjänsten org.goblincakes.dashboard.p<pid>.
- Steg 2 (10 nov), ramarna till höger – dashboard/stats.py, läser bara det andra har sparat: WOW STATS och CS2 STATS ur
  GoblinRecorders historik (~/.local/share/goblincakes/wow-history.json, cs2-history.json; CS2 = säsongens officiella
  matcher, inte PRIVAT), BYGGEN = buildstatus.py (bara på datorn som har repot; sparas 5 min i
  ~/.cache/goblincakes/dashboard-builds.json, 1 min medan ett bygge pågår; din "bygget är klart"-bevakning tar bort
  filen så att dashboarden frågar igen; tryck på ett bygge = stegen: kontrollen + varje variant ✓ klart / ● pågår /
  ✗ fel / ○ kvar, läses om var 20:e s tills bygget är klart – stats.build_steps), KAKAN = rapporterna i ~/.local/share/goblincakes/till-claude.
  En ram utan data syns inte alls (ingen WoW-historik → ingen WOW STATS).
- Senaste raiden = senaste raidkvällen för karaktären som raidade sist. Staplarna (bossens hälsa per pull) frågas från
  Warcraft Logs, en fråga per rapport, sparat i ~/.cache/goblincakes/dashboard-wcl.json; utan WCL-nyckel
  (~/.config/goblincakes/wcl.json) eller utan länk på pullen visas bara kill/wipe.
- Den göms av sig själv när ett annat fönster blir aktivt (som Plasmas Instrumentpanel för program).
- Steg 3 (10 nov), vyer: SPEL (Projekt, System | WoW Stats, CS2 Stats) och JOBB (Projekt, System | Byggen, Kakan) som
  standard, högst 3 ramar till vänster och 2 till höger, högst 6 vyer; KVOT och SPELAS NU syns i alla. Byte: prickarna
  under mitten (tryck eller hjulet), svep i sidled, Ctrl+← →. En ram som inte finns i någon vy läses inte alls.
  Ram saknas fast den är vald → den har inget att visa (t.ex. ingen WoW-historik), eller vyn är en annan än man tror:
  `python3 /usr/share/goblincakes/dashboard/dash.py views`.
Kontroll: `python3 /usr/share/goblincakes/dashboard/dash.py system` (även apps, top, player, quota, projects,
`tray nätverk|ljud|bluetooth|urklipp|enheter`, bottom, views, config) – skriver det fönstret skulle visa; ramarna till höger:
`python3 /usr/share/goblincakes/dashboard/stats.py wow` (även wow-fetch = med Warcraft Logs, cs2, builds, reports).
- Steg 4 (10 nov), skrivbordets upplägg – ett val, standard = toppfält och docka: Config → INSTÄLLNINGAR → Utseende →
  Skrivbordets upplägg eller `goblin dashboard upplägg dashboard|klassiskt`; hjälparen /usr/libexec/goblincakes-desktop-layout
  (`status` = classic/dashboard). Dashboard = toppfältet och dockan borta, en panel uppe i mitten (alltid gömd – autohide,
  fram vid överkanten): widgetarna org.goblincakes.nowplaying (part=left: Steam + Discord, part=right: Spelas nu + Kakan),
  org.goblincakes.deskclock (batteri, nätverk nmcli, klocka/datum/vecka, ljud wpctl, headsetbatteri, Kakan längst till höger: cupcaken Redo/Laddar/Ej laddad/Vilar – läser Ollamas /api/ps, klick = goblincakes-ollama wake) och ett litet
  systemfält i en egen panel gömd uppe till höger (autohide; bara notiser + programmens ikoner – behövs för notiserna). Meta = Plasmas globala
  kortkommando goblin-dashboard/toggle (kglobalaccel; Meta tas från plasmashells "activate application launcher", Alt+F1
  blir kvar). Dashboarden lyssnar själv på det, så den måste köra (startas gömd vid inloggning; efter
  `goblin dashboard stäng` gör Meta ingenting förrän `goblin dashboard` eller nästa inloggning). Sparat:
  ~/.config/goblincakes/desktop-layout.json (läget, dockans program och storlek, startmenyns tangenter före =
  launcherBefore), kopior av panelfilen i ~/.local/state/goblincakes/layout-backup/. Tillbaka till toppfält och docka
  lägger dockans program och storlek och Meta på startmenyn tillbaka. Låg något kvar (raden,
  systemfältspanelen, Meta på dashboarden) tas det bort vid inloggningen (`login`). Kolla: `grep -A2 '^\[goblin-dashboard\]'
  ~/.config/kglobalshortcutsrc` och `grep 'activate application launcher' ~/.config/kglobalshortcutsrc` (Meta där =
  AppGrid). Dashboarden öppnas på huvudskärmen (KWin-skriptet goblincakes-windows, screenOrder[0]).
  Storleken (11 nov): `s` 0,6 i DeskBox.qml/ClockBox.qml, panelen 52 px (goblincakes-desktop-layout ROW_HEIGHT – `login` rättar
  höjden). Stil Levande = tonat glas utan ram (widgetarna bevakar ~/.config/goblincakes/utseende och spelvaktens fil – läser vid ändring, annars var 60:e s).
  Meta-tipset längst ner på skrivbordet (11 nov): widgeten org.goblincakes.metahint, läggs dit/tas bort av
  goblincakes-desktop-layout (`login`); borta när dashboarden visats 3 gånger (~/.local/state/goblincakes/dashboard-shown).
  Dashboardens batterirad uppe till höger: goblincakes-device-battery (`python3 dash.py batteries`).
  GOBLINRECORDER-ramen ovanför SPELAS NU (11 nov): OBS, WoW, Logg, Spelas in ur GoblinRecorders statusfil
  ~/.cache/goblincakes/recorder-status.json (`python3 dash.py recorder`; "service": false = tjänsten
  goblincakes-recorder skriver inte – `systemctl --user status goblincakes-recorder`).
- Nederst i dashboarden: GOBLINCAKES egna program i en rad med små ikoner (dash.py own_apps: Config, Goblin AI,
  GoblinRecorder, GoblinAmp, GoblinShare, Barnläge), under dem programraden = dockans fästa program (delas åt båda hållen: Config →
  DASHBOARD → APPARNA LÄNGST NER ändrar dockan; i upplägget Dashboard listan i desktop-layout.json, som dockan får tillbaka).

## GOBLINCAKES Config
Ord: config, inställningar, goblincakes config, program, förinstallerat, fönster, grafik, uppdatera, reglage
- Fönstret för val och inställningar: /usr/bin/goblincakes-config, QML i /usr/share/goblincakes/config/.
  Flikar: Program, Förinstallerat, Inställningar, Fönster, Grafik, Uppdatera.
- Reglagen i Inställningar körs av /usr/libexec/goblincakes-tweak (status/set per reglage); installationer i
  Program av /usr/libexec/goblincakes-config-install.
- Inloggning/lås (System): "Automatisk inloggning" = /etc/sddm.conf.d/90-goblincakes-autologin.conf (bara vid start;
  TV-lägets zz-goblincakes-autologin.conf vinner när den finns). "Inget lösenord efter viloläge" = LockOnResume=false i
  ~/.config/kscreenlockerrc. Kolla: cat filen / kreadconfig6 --file kscreenlockerrc --group Daemon --key LockOnResume.
- "Vila bara när locket stängs" (System, bara laptops: `laptopOnly` i tweaks.json) = powerdevilrc
  [AC|Battery|LowBattery][SuspendAndShutdown] AutoSuspendAction=0; locket/Sov fungerar. Kolla: `goblincakes-tweak status sleep-lid-only`.
- "Inget viloläge" (System) = /etc/systemd/sleep.conf.d/90-goblincakes-no-sleep.conf (AllowSuspend=no m.fl.). Vid
  på/av startas plasma-powerdevil om i alla inloggade sessioner (annars gäller ändringen först efter ny inloggning).
  Kolla: busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanSuspend (yes/na).

- Avinstallera: kryssa ur ett installerat program under Program → knappen Avinstallera = `goblincakes-config-install
  uninstall <kind> <args>` (Flatpak från user/system, AppImage, webbapp, Discord, VS Code, ChatGPT, gamescope).
  Inte Battle.net, Ianseo, GoblinRecorder, Claude Code eller program som ingår i systemet (RPM). Data/inställningar ligger kvar.
## goblin-kommandot
Ord: goblin, kommando, terminal, goblin help
- /usr/bin/goblin (bash): `goblin help` listar alla. Hjälpprogrammen ligger i /usr/libexec/goblincakes-*.

## CLAUDE CODE-kartan (AI-kartan)
Ord: kartan, ai-kartan, claude-kartan, claude code-kartan, KARTA, vad claude gör, codex, kakans karta, stationer, kontexten
- En karta över vad Claude Code gör just nu (13 nov): i dashboarden (ramen CLAUDE CODE, tryck = kartan i mitten) och
  till höger om TERMINAL i Goblin AI (knappen KARTA i flikraden visar/döljer; döljs själv när fliken är under 700 px).
- Läser Claude Codes egen logg: ~/.claude/projects/<mapp>/<session>.jsonl (agenter: <session>/subagents/*.jsonl).
  Inget installeras i Claude Code. Kod: /usr/share/goblincakes/claudemap.py (läsaren), claudefeed.py (Qt),
  qml/Goblin/ClaudeMap.qml (ritningen).
- Kolla för hand: `python3 /usr/share/goblincakes/claudemap.py` (nyaste sessionen) eller `… claudemap.py ~/projekt`
  (den sessionen i mappen) – ger JSON med model, context (%), busy, running, rows. `{"none": true}` = ingen logg alls
  (Claude Code aldrig kört, eller CLAUDE_CONFIG_DIR pekar någon annanstans).
- Visar fel session i Goblin AI: den väljer sessionen i mappen där processen `claude` kör i fliken som visas; kolla
  `pgrep -a claude` och `readlink /proc/<pid>/cwd`. Knapparna ovanför kartan väljer för hand, AUTO = tillbaka.
- Dashboarden öppnar på AI-kartan som standard (VILANDE när ingen jobbar). Ändras i Config → Dashboard överst
  ("När dashboarden öppnas"): AI-kartan / Program / Där du var senast – sparat som `start` i ~/.config/goblincakes/
  dashboard.json. Esc går tillbaka till kartan, Esc igen gömmer dashboarden.
- Rutan i Goblin AI dold/visad sparas i ~/.config/goblincakes/claude-karta (dold/visad). Ramen i dashboarden väljs i
  Config → Dashboard ("Claude Code").
- Visar även **Codex** (~/.codex/sessions/ÅÅÅÅ/MM/DD/rollout-*.jsonl) och **dig själv** (~/.local/state/goblincakes/
  kakan-karta.jsonl – en rad per fråga, modellanrop, steg och kommandokort, skrivs av goblinai.kakan_log). Din karta har
  egna stationer: KOMMANDON, NÄTET, SPEL, DATORN, SKRIVBORDET, FILER, MINNE, KONTROLL. Kolla: `tail -5 ~/.local/state/
  goblincakes/kakan-karta.jsonl` (ska ha nya rader efter en fråga).
- Kontexten räknas mot 200 000 tokens (1 000 000 när sessionen gått över 200 000 eller modellen har [1m]) – kan visa
  för mycket i början av en 1M-session.

## Goblin AI (du själv)
Ord: goblin ai, kakan, ai, chatt, meta+a, minne, lärdomar, kända lösningar, körda kommandon, ångra
- Fönstret /usr/bin/goblin-ai (Meta+A, goblin ai app), koden i /usr/share/goblincakes/ai/ (goblinai.py m.fl.).
- Fönstrets layout (1 nov): rutorna KAKAN (avatar, modell, minne, vad du gör), PROJEKT (MAPPAR + dina projekt),
  KOMMANDON och MODELLER (klick = välj modell, I MINNET = laddad i Ollama) till vänster – på stående
  skärm i en rad överst – och flikarna SVAR, CHATTAR, LÄR DIG KODA, INSTÄLLNINGAR (meny till vänster med delarna).
- Ett /planering-steg som visar "Kontrollerar svaret – fel (saknar sammanfattning …)" fast verktyget sa "Sparade …": det var kontrollen, inte steget – kolla att filen finns (ls) och säg att steget gick. Planeringsturer (`plan`) hoppar över felsöknings­kontrollerna (7 nov).
- MAPPAR = användarens egna projektmappar i ~/.config/goblincakes/ai-mappar.json (en lista med sökvägar). Klick på en
  mapp: Öppna i VS Code (~/.local/share/vscode/bin/code <mapp>) eller Claude Code i terminalen (goblincakes-terminal run
  i mappen, `claude`). Arbetet sker där, inte i fönstret. Du ändrar aldrig koden i mapparna.
- TERMINAL-fliken: riktiga skal i flikar (ai/ptyterm.py startar skalen, ai/TerminalView.qml + ai/terminal/index.html = xterm.js i en webbvy, kräver paketen qt6-qtwebengine och qt6-qtwebchannel). Mappens meny i PROJEKT: Claude Code här; + i terminalflikarna öppnar i den aktuella flikens mapp. Terminalerna avslutas när fönstret stängs. Syns inte fliken: kolla att PySide6.QtWebEngineQuick går att importera.
- Kvoten (knappen KVOT bredvid flikarna, öppnar en ruta med staplar och när den nollställs) läses ur ~/.cache/goblincakes/quota.json (kvot-widgetens fil, varje minut medan fönstret har fokus).
- I terminalen: goblin ai = /usr/libexec/goblincakes-ai (prompt_toolkit, python3-prompt-toolkit i imagen; utan den en
  enkel rad). /app öppnar fönstret med samma samtal (goblin-ai --open <id>). Terminalens chattar sparas bland fönstrets.
  /projekt <namn> går in i ett projekt (projects.json), /projekt lämnar.
- Följdfrågor (9 nov): en kort fråga direkt efter ett svar med **Källor:** (från nätet) söks igen – follow_up_of() och
  follow_up_query() i goblinai.py skriver om den med samtalets ämne (steget "Förstår följdfrågan" visar sökfrågan;
  "ingen ny sökning behövs" = modellen svarade INGEN). Söker hon på fel sak: titta på den raden i stegen.
- Chattar, minne och lärdomar: ~/.local/share/goblincakes/ai/. Nycklar: ~/.config/goblincakes/ai.env – visa aldrig.
- Lärdomar och kända lösningar (kind "solution") i ~/.local/share/goblincakes/ai/lardomar.json, i kategorier, inget tak.
  Visas under Inställningar → Lärdomar och lösningar. Liknande (fältet similar) väljer användaren. Kända lösningar från
  Claude Code: python3 /usr/share/goblincakes/ai/solutions.py list [ord].
- Körda kommandon och hur de ångras: ~/.local/state/goblincakes/ai/kommandon.jsonl, säkerhetskopior bredvid.
  Användaren ångrar under Inställningar → Körda kommandon.
- Styra skrivbordet (verktyget skrivbord, ai/desktop.py): musik (MPRIS via busctl: paus/spela/nästa/förra/vad) och
  volym (wpctl = datorns, högst 100 %; "i GoblinAmp/Spotify" = spelarens MPRIS-Volume) körs direkt utan Tillåt (användarens val) och loggas som "kakan" med ångring.
  Öppna (program ur menyn via gtk-launch, webbsida/fil/mapp via xdg-open; spel efter 8 s) också direkt.
  Spela låt/album/artist: Spotifys Web API med GoblinAmp:s inloggning (~/.config/goblincakes/spotify.json).
  Rösten tar först användarens egna GoblinAmp-listor (voicecmd.own_list → goblin-amp --quiet <lista>).
  Notis (notify-send) och urklipp (wl-copy/wl-paste; gamla urklippet sparas för ångra, lösenord visas inte).
  Fönster: KWin-skriptet ai/windows.js via org.kde.kwin.Scripting (flytta, fram, maximera, fullskärm, minimera;
  "andra skärmen" = den programmet inte ligger på; stänga = Tillåt-kort).
  Spel (goblin plays ord, startar efter 8 s) och goblin-kommandon (läsande direkt, andra = Tillåt-kort).
  Kalendern: händelser skrivs i Merkuros fil (~/.config/akonadi_ical_resource_0rc → Path), Akonadi läser in dem själv;
  påminnelserna visas av kalendarac (pgrep kalendarac).
  Påminnelser och bevakningar (ai/reminders.py, tjänsten goblincakes-kakan-vakt.service tittar var 15:e s):
  påminn <när> ; <text> (notis med ljud, även under spel, "Om 10 min"-knapp), bevaka steam|uppdatering|nedladdning|
  stängt X|startat X|sida X [ord] (väntar tills spelet är stängt), bevaka antifusk (stående, se Grafikkort), fråga <när> ; <frågan> (du svarar då, svaret som
  notis + sparat samtal), påminnelser [bort]. Listan: ~/.local/share/goblincakes/ai/vakt.json. Missad tid (datorn av)
  kommer vid inloggning. Kolla: systemctl --user status goblincakes-kakan-vakt.
  spara <sökväg> ; <text> (verktyget spara_dokument, 7 nov): du sparar själv PDF/Word/odt/txt/md efter ändelsen (ingen
  = PDF; mapp utan ~/ = under ~/Dokument), bara i hemmappen, aldrig över en fil (nytt namn). Görs av
  `QT_QPA_PLATFORM=offscreen goblin-ai --save-doc <md-fil> <mål>` (samma som Spara som…). Ångra = papperskorgen.
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
- Kvittot under svaret (punkt 23, goblinai.receipt): under det senaste svaret till en fråga står "Kvitto: läste n ·
  körde n (n fel) · ändrade n · väntar n · fastnade n" (fastnade = steg som gick fel, t.ex. byt_text "Inget kort gjort", listade sist) – räknat ur verktygen och korten, inte ur det du skriver. Säger du klart/fixat
  kollar klart-kontrollen: väntar ett kort på Tillåt → "Inte klart än"; gav senaste kommandot fel → "men det senaste
  kommandot gav fel"; inget ändrat → "men inget har ändrats"; ändrat utan att läsa efteråt → "inte kontrollerat
  efteråt". Säg alltså klart först när ändringen körts OCH du läst resultatet (cat, leta, wowapi kolla). Fångar
  kontrollen något du kan rätta får du det en gång per fråga ("[Goblin AI – klart-kontrollen] …") – gör då det som
  står där i stället för att upprepa att det är klart. Sparas i
  chatten (fältet receipt), syns i terminalen (goblin ai) och i Skicka till Claude-rapporten.
- Ärlighet (goblinai.py): faktafrågor utan något hämtat får "Ur minnet – inget hämtat eller kontrollerat" (FROM_MEMORY);
  "jag har läst/kollat …" utan verktyg skickas tillbaka en gång, sedan en Obs-rad (READ_CLAIM); "kan du …?" får
  listan över verktygen hon har just nu + det hon inte kan (abilities, CANNOT).

- Uppslagsverket (verktyget wiki, ai/wikitools.py): Wikipedia på svenska (engelska när svenska saknar det eller en
  del bara finns där) och Wiktionary (`ord: <ord>`) via deras öppna API – inget konto. Ger artikelns början, första
  delen, delarnas namn och länken; `<ämne> ; <del eller ord>` = en del eller styckena som nämner ordet. Kolla:
  python3 /usr/share/goblincakes/ai/wikitools.py "Gustav Vasa ; skidor". `/wiki <fråga>` i Goblin AI (fönster och terminal) = bara wiki-verktyget för den frågan – snabbare, menyn med alla verktyg läses inte. Likadant /kalender (bara kalendern + påminnelser ur skrivbord, verktyget kalender = cal_run), /wcl, /wow, /cs2, /sport, /github, /datorn (ONLY_COMMANDS i goblinai.py); svar utan verktyget skickas tillbaka.

- Ändra en fil som finns: verktyget byt_text (ai/bytatext.py) – den gamla texten exakt (några hela rader, inga
  radnummer) mot den nya; finns texten inte, eller flera gånger, visar det närmaste raderna. Ger ett Tillåt-kort
  `python3 …/bytatext.py FIL <<'KAKAN_SLUT'` med GAMMALT/NYTT. sed som skriver in rader (c\, i\, a\, \n) skickas tillbaka.
- Kommandokorten visar först vad kommandot gör på vanlig svenska (ai/explain.py, görs av kommandot – ingen AI),
  koden bakom "Visa koden" (byt_text: före/efter i rött/grönt), "1 AV 3" när flera kort kommer. Kolla:
  echo 'cp -r a b' | python3 /usr/share/goblincakes/ai/explain.py
- MCP-servrar (färdiga verktyg utifrån, ai/mcp.py): ~/.config/goblincakes/mcp.json (mcpServers, samma form som Claude
  Code), nycklar i mcp.env (visa aldrig). Program körs i podman-containrar, startar vid första anropet, stängs efter
  5 min eller när ett spel startar. Läsande verktyg direkt, andra = Tillåt-kort. Verktygslistan cachas i
  ~/.local/state/goblincakes/ai/mcp-verktyg.json. Kolla: python3 /usr/share/goblincakes/ai/mcp.py lista;
  podman ps (servrar som kör). Användaren lägger till/stänger av under Inställningar → MCP-servrar.
  Webbläsaren (webblasare, mcr.microsoft.com/playwright/mcp): egen Chromium utan skärm och utan användarens
  inloggningar; öppna/läsa direkt, klicka/skriva = Tillåt. Tillåt-körningen (mcp.py kör) går via socketen
  $GOBLIN_MCP_SOCKET (/run/user/<uid>/goblincakes-mcp-<pid>.sock) till samma webbläsare. Sidor med
  Cloudflare-skydd (t.ex. wowhead.com) svarar 403 – läs dem med las_sida i stället.
- Dina egna verktyg som MCP-server för Claude Code (ai/kakan_mcp.py, servern "kakan"): bara de som läser –
  kartan, systemfel, leta-verktygen, wowstats, warcraftlogs, wowfel, cs2, sport. Inte skrivbordet, sökningen eller
  dina MCP-servrar. Läggs in med python3 /usr/share/goblincakes/ai/kakan_mcp.py claude. Kolla: claude mcp list
  (kakan ✔ Connected), python3 /usr/share/goblincakes/ai/kakan_mcp.py lista. Verktyget rapporter = dina rapporter.
- Skicka till Claude (ai/toclaude.py): under varje svar "Skicka till Claude" (Claude Code i en TERMINAL-flik i
  Goblin AI, i GOBLINCAKES-repot – sedan 2 nov; utan TERMINAL-fliken ett eget terminalfönster; löser problemet – användaren ser och godkänner) och "Fråga Claude" (claude -p utan fönster,
  får bara läsa, svaret kommer in i chatten). Även /claude och /claude fråga. Rapporten byggs ur samtalet (frågan,
  dina svar, steg, verktygens svar, kommandon med utdata) och sparas i ~/.local/share/goblincakes/till-claude/;
  Claudes svar skrivs sist i den. Modell: Sonnet. Kostar användarens Claude-kvot – föreslå knappen när du inte
  kommer vidare, men den trycks bara av användaren. Knapparna syns bara om Claude Code finns (~/.local/bin/claude).
- Hitta och skicka vidare (2 nov): du lagar själv bara småfel (en eller två ändringar på högst 8 rader, byt_text
  stoppar annars). Allt större: rapporten (Vad som är fel med fil:rad, Vad jag har kollat, Osäker på, Kan jag laga
  det: Nej) – då sparas den i till-claude av sig själv (kostar ingen kvot). Skriver användaren "bara kolla",
  "laga inte", "kolla, sammanfatta och skicka" e.d. ändrar du inget alls (inget byt_text). Skriver användaren
  "skicka till Claude" (eller "till Codex") startar det programmet med rapporten i TERMINAL av sig själv
  (användarens val att använda kvoten); bara "skicka" sparar den. Vem knapparna skickar till: Inställningar →
  Skicka vidare (Claude Code, Codex eller ett eget kommando; ~/.config/goblincakes/ai-helper.json). Codex =
  ~/.local/bin/codex, inloggningen i ~/.codex/auth.json (samma som ChatGPT-appen och kvotwidgeten).
  Hur man kollar: ls till-claude.
- Tyglad (7 nov): ändringskort bara när användaren ber om en ändring (laga, ändra, installera, ta bort, stäng, gör
  det …) – annars titta och berätta. Kort med program som inte finns tas bort; gick ett kommando fel får du inte göra
  ett nytt för samma fråga – säg vad som gick fel. Det är Goblin AI:s regler (rein_in i goblinai.py), inte dina val.
- Din rapport kontrolleras (7 nov): Goblin AI läser raderna du pekar på under Vad som är fel och jämför med det du
  citerar – stämmer det inte står det under svaret. Skriv därför bara det du sett där; gissningar under Osäker på.
- /laga (7 nov): efter din rapport om användarens EGNA kod (tillägg, widget, skript – fil:rad i rapporten) kan
  användaren skriva /laga eller trycka Laga under rapporten. Då börjar du om från noll: bara rapporten, raderna den
  pekar på (±40 rader) och verktygen leta/byt_text/wowapi, med tänkande. Där får du göra högst 4 ändringar på högst
  15 rader var. Samtalet efter /laga stannar i lagningen (bara de tre verktygen) tills användaren skriver /ny.
  Andras tillägg och GOBLINCAKES egna filer lagas inte så. Kod: laga_message/laga_chat/LAGA_GUIDE i goblinai.py.
- /planering (punkt 20, 7 nov): Goblin AI (inte du) frågar användaren ett steg i taget – Vad ska göras? När? (nu,
  16:00, om 20 min, imorgon 8) – till "klart", visar planen (kör / ändra <nr> / lägg till [efter|före <nr>] / stryk <nr> / avbryt). Stegen "nu" får du ett i
  taget i fönstret, från noll med hela planen som bakgrund och svaret från steget före (plan_message/plan_chat i
  goblinai.py); väntar ett kort på Tillåt väntar planen. Ordningen = användarens: "nu" efter ett steg med tid görs
  direkt efter det steget. Efter "nu"-stegen görs resten om till rader datorn kör utan AI (plan_actions: öppna/spela/
  musik/volym/notis/spel/fönster, kontrollerade – filen finns, adressen kom från planen) eller "jag gör det då"; de
  läggs i vakt.json som "plan" (reminders.plan_chain/run_plan, väntar under spel) – "påminn mig att …" = vanlig
  påminnelse. Har ett steg i kedjan gått via dig öppnas Goblin AI med samtalet (inte under spel). Steg en annan dag än idag står också i kalendern (Merkuro, utan kalenderns egen påminnelse). Planen är bara användarens egna svar:
  inget du läser lägger till steg. Fortsätter inte planen: användaren skriver fortsätt eller avbryt.
- Kakans reserv (punkt 17, 7 nov): Claude Code eller Codex med användarens eget abonnemang tar frågan åt dig när
  lokala AI:n vilar (ett spel kör) och när användaren trycker "Försök igen med Claude Haiku" (eller /haiku, /sonnet;
  med Codex /luna, /sol) under ett svar där du fastnat. Programmet startar som sig självt i en TERMINAL-flik i Goblin
  AI (i `goblin ai`: i samma terminal, /exit tillbaka) med frågan och samtalet – dess egna verktyg (Read/Grep/Edit)
  plus dina via ai/kakan_mcp.py; det frågar Ja/Nej i terminalen före varje ändring. Startmapp: tillägget i
  ~/Games/WoW/Retail/AddOns när frågan nämner det, annars AddOns vid WoW-ord, annars hemmappen. Haiku först; fastnar
  den skriver den att användaren ska skriva `/model sonnet`. Svaret står i terminalen, inte i chatten (i chatten bara
  "Claude Haiku jobbar med frågan i TERMINAL-fliken"). Frågas en gång när programmet hittas inloggat (Ja/Nej; Nej =
  aldrig); Inställningar → Skicka vidare → KAKANS RESERV. Aldrig Privat-projekt, bilder eller egna knappars dagliga
  körning. Drar av kvoten. Kod: reserve_terminal/reserve_for i goblinai.py, _reserve_terminal i goblin-ai,
  reserve_here i goblincakes-ai. Hur man kollar: ~/.config/goblincakes/ai-helper.json ("reserv": true/false),
  `claude auth status`, ~/.codex/auth.json; instruktionen och MCP-filen per körning i ~/.cache/goblincakes/reserv/.
  Under spel tar Goblin AI inte fokus från spelet: fönstret (med TERMINAL-fliken) visas på skärmen utan spelet och en
  kort notis säger var – mitt i ett bossförsök/en arenamatch (GoblinRecorder spelar in) väntar det tills försöket är
  slut. Ja/Nej svaras alltid i Goblin AI, aldrig i en notis.
- Testa åt Claude (ai/testlist.py): Claude lägger testlistor i ~/.local/share/goblincakes/testlistor/ (eller i repots
  docs/testlistor/till-kakan/ – kopieras dit en gång efter git pull, minnet i testlistor/.fran-repot.json); /testa kör
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
- `goblincakes-ollama wake` (klick på cupcaken i klockrutan): öppnar Goblin AI, laddar vardagsmodellen för 1 h och hälsar med rösten (notis utan röst). Under spel: bara Goblin AI + "jag vilar". Kolla laddad modell: `curl -s localhost:11434/api/ps`.
- Minnet (kontexten): 64k tokens med ett grafikkort på 12 GB eller mer, annars 32k (context_length() i
  goblincakes-ollama). Bildmodellen qwen3-vl får inte plats helt på kortet med 64k – bildfrågor går lite långsammare.
  Kolla: `curl -s localhost:11434/api/ps` (context_length).
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
- OBS frågar vilken skärm (KDE-rutan) fast den är vald: hände första starten efter inloggning (portalen skrev
  "target not found" i journalen). Tjänsten startar då om OBS en gång själv. Kommer rutan ändå: välj skärmen. Tryck
  aldrig Reload på källan Skärm (då glöms valet). Valet: `flatpak permissions screencast`, OBS logg
  ~/.var/app/com.obsproject.Studio/config/obs-studio/logs/ ("Asking for monitor" utan "source selected").
- CS2-demon läses med demoparser2/awpy (/usr/lib/goblincakes/demoparser). Kartornas väggar (TTD/sikte):
  ~/.cache/goblincakes/awpy/ (Valves kartor); workshop-kartor görs ur kartans .vpk med Source 2 Viewer
  (~/.cache/goblincakes/source2viewer/, hämtas första gången) → ~/.cache/goblincakes/awpy/workshop/<id>-*.mesh.
  Gick det inte: en .failed bredvid (nytt försök efter ett dygn). Egen demo (record) saknar motståndarnas namn.
Kontroll: `systemctl --user is-active goblincakes-recorder`
Kontroll: `journalctl --user -u goblincakes-recorder -n 15 --no-pager`

- WoW Stats → "Leta efter saknade": nycklar och raidbossar från den senaste veckan som finns på Warcraft Logs men inte i WoW Stats (inte inspelade, t.ex. när GoblinRecorder inte kände igen WoW). Raid: kills + bästa wipen per boss och kväll. Läggs bara till när användaren trycker Lägg till (`recorder.py` wow_missing/wow_add_missing). Saknas en körning i WoW Stats → föreslå knappen.
- Parserna i WoW Stats hämtas igen från Warcraft Logs en gång om dagen i en vecka (procenten ändras de första
  dagarna; en för tidigt hämtad kan vara fel – 100 mot ilvl-parse 32). Stämmer en parse inte med Warcraft Logs:
  vänta ett dygn, eller kolla `journalctl --user -u goblincakes-recorder | grep "parses again"`.
## GoblinAmp
Ord: goblinamp, amp, musikspelare, winamp, spotify, spellista, låtar, mediatangenter
- /usr/bin/goblin-amp (kod /usr/share/goblincakes/amp/), inställningar ~/.config/goblincakes/amp.json och
  spotify.json, Last.fm lastfm.json. Spotify-appen startas dold av /usr/libexec/goblincakes-spotify-app.
- `goblin amp hjälp` visar hur Spotify-listorna ställs in.
- Spellistan kan sitta under spelaren eller i ett eget fönster (LOSSA i spellistan, FÄST i fönstrets namnlist):
  amp.json `plDetached`, storleken `plWindow`; platsen sparar KWin-skriptet i kwinrc [Script-goblincakes-windows]
  ampPlPlace (fönstret heter "GoblinAmp – spellista").
- GRAF under spelaren är genomskinlig (fönstret har alfakanal; spelaren och spellistan egna bakgrunder). Omslag vid
  hovring = Spotifys bild-URL (`image` på album- och listrader, spotifyweb.py `_cover`).
- Egen musik (LOKALT): musikmappen = amp.json `musicDir` (vald under "Musikmapp ▾", annars xdg-user-dir MUSIC);
  egna listor = .m3u8 i ~/.local/share/goblincakes/amp/spellistor (förr ~/Musik/Spellistor – kopieras dit en gång).
- Egen musik hörs inte: kolla mixern (`pactl list sink-inputs`, strömmen GoblinAmp / nod goblin-amp, "Mute").
  GoblinAmp håller den avstängd bara vid 0 % – en avstängning från mixern slås på igen direkt (pactl subscribe).

## GoblinShare
Ord: goblinshare, share, dela, skicka fil, ta emot, localsend, airdrop, filer till telefonen, filer mellan datorerna
- Filer, mappar och meddelanden mellan GOBLINCAKES-datorerna i hemnätverket med LocalSends protokoll v2. Telefoner med
  appen LocalSend kan FÅ filer härifrån, men allt de skickar hit nekas (bara GoblinShare kan skicka hit – användarens
  beslut). "Kan inte skicka från telefonen till datorn" är alltså meningen, inget fel. Tjänsten goblincakes-share
  (/usr/libexec/goblincakes-share run, kod /usr/share/goblincakes/share/share.py), fönstret /usr/bin/goblin-share,
  Dolphins högerklick "Skicka med GoblinShare" (/usr/share/kio/servicemenus/goblincakes-share.desktop).
- Påslaget = flaggan ~/.config/goblincakes/share-on (Config → Program → System, fönstrets reglage, `goblin share på`).
  Inställningar ~/.config/goblincakes/share.json (namn, mapp, betrodda), certifikat och historik
  ~/.local/share/goblincakes/share/. Mottagna filer: Hämtade/GoblinShare om inget annat valts.
- Port 53317 TCP (HTTPS) och UDP (multicast 224.0.0.167). Syns ingen: samma wifi? gästnätverk/"AP-isolering" i
  routern stoppar det; brandväggen: `firewall-cmd --list-ports` (Fedoras zon släpper in 1025–65535, annars
  öppnas 53317 när GoblinShare slås på); ett annat program på porten (LocalSend själv) = felrad i fönstret.
  Telefonen syns bara medan LocalSend-appen är öppen. "Leta igen" frågar också hela /24-nätet direkt.
- `goblin share lista` (enheterna), `goblin share status`, `goblin share till <namn> <fil>`, `goblin share text <namn> <text>`.
- Hjälp via terminal (ssh, 4 nov): den som behöver hjälp trycker **Be om hjälp** i GoblinShare (`goblin share hjälp`)
  och läser upp en 6-siffrig kod (10 min, 5 försök, en gång). Hjälparen trycker Terminal på hens ruta och skriver koden
  (`goblin share terminal <namn> <kod>`) → en terminal där. Medan den är öppen fungerar `ssh <namn> <kommando>` i vilken
  terminal som helst (ControlMaster, ~/.ssh/goblinshare.conf) – även för Claude Code. Stängs terminalen eller trycker hen
  Avsluta (fönstret/notisen, `goblin share hjälp avsluta`) är hjälparen ute; nästa gång en ny kod.
  Förutsättning hos den som får hjälp: "Tillåt hjälp via terminal" (Inställningar; första Be om hjälp slår på den;
  root-delen `goblincakes-tweak set share-ssh on|off`: /etc/ssh/sshd_config.d/10-goblincakes-share.conf = bara nycklar,
  ingen root; sshd och brandväggens ssh-tjänst tillbaka som de var vid av, minnet i /etc/goblincakes/share-ssh).
  Nyckeln ligger i ~/.ssh/authorized_keys bara de sekunder det tar att logga in (expiry-time, kommentar goblinshare:…).
  Kolla: `goblin share terminal` (listan/ansluten?), `systemctl status sshd`, `ssh -v <namn> true`.
  "Permission denied (publickey)" = ingen terminal öppen (eller koden inte använd) – be om en ny kod. "REMOTE HOST
  IDENTIFICATION HAS CHANGED" = den andra datorn ominstallerad → Glöm i Inställningar och anslut med ny kod.
- Meddelanden: knappen Text på en enhet öppnar ett eget chattfönster (`goblin-share --chat <fingeravtryck>`, även
  notisens "Öppna chatten"); siffran på Text = olästa. Sparas per enhet i ~/.local/share/goblincakes/share/chats.json
  (300 per enhet; "read" = senast läst), inte i HISTORIK. Ingen notis medan chatten med just den enheten visas.
- Beställningar: en annan GOBLINCAKES-dator kan beställa något av Goblin AI här (knappen Beställ, `goblin share beställ
  <namn> <text>`). De ligger i ~/.local/share/goblincakes/share/orders.json och under BESTÄLLNINGAR i fönstret; Starta kör
  /usr/share/goblincakes/ai/order.py run <id> [--via chatgpt] (Goblin AI svarar och ritar ```bild, eller
  ChatGPT-appen ritar via goblincakes-chatgpt image – Enter i appen – och bilden skickas tillbaka). "ej skickad" = den andra datorn
  syntes inte – Skicka igen. Beställarens dator tar emot bilderna utan Ta emot i 3 dagar. `goblin share beställningar`.
- Medan någon är inne via Be om hjälp håller tjänsten datorn från automatisk vila (systemd-inhibit --what=idle,
  who=GoblinShare); locket och Sov fungerar. Syns med `systemd-inhibit --list`.
Kontroll: `systemctl --user is-active goblincakes-share`
Kontroll: `/usr/libexec/goblincakes-share status`
Kontroll: `journalctl --user -u goblincakes-share -n 30 --no-pager`

## goblin graph
Ord: graph, ljudgraf, staplar, visualisering
- /usr/bin/goblin-graph (QML i /usr/share/goblincakes/graph/), tjänsten goblincakes-graph öppnar den när musik
  spelas om `goblin graph auto on` (tittar var 5:e s, inte alls under spel med Spelläge på – staplarna öppnas därför några sekunder efter att musiken startat). Inställningar ~/.config/goblincakes/graph.json. Vilar under spel.

## Spelläget
Ord: spelläge, gamemode, spel, prestanda, lagg, fps, wowup stängs, battle.net agent, akonadi, baloo, fläktar, fläktboost, lenovo
- Tjänsten goblincakes-gameguard (/usr/libexec/goblincakes-gameguard run) ser varje sekund om ett spel kör:
  GameMode, uppdateringar väntar, Akonadi/Baloo vilar, WoWUp stängs medan WoW kör. Allt återställs efter spelet.
- Den är ensam om att leta efter spel och kör även med Spelläge av (då letar den bara): svaret står i
  $XDG_RUNTIME_DIR/goblincakes-game (1 = spel, 0 = inget, rörs varje sekund). Lokala AI:n, Kakans vakt och Goblin AI läser
  den; är filen äldre än 5 s (tjänsten stannad/kraschad) letar de själva som förut. Kolla: systemctl --user status
  goblincakes-gameguard; stat -c %y $XDG_RUNTIME_DIR/goblincakes-game
- Vad som är ett spel: /usr/share/goblincakes/gaming.py (samma regel för Spelläge och lokala AI:n). Battle.net ensamt är inget
  spel, inte heller när det startas från Steam (en reaper med bara Battle.net/Wine-hjälpare under sig). Kolla:
  python3 -c "import sys; sys.path.insert(0,'/usr/share/goblincakes'); import gaming; print(gaming.game_running(), gaming.find_game())"
- Battle.nets Agent (nedladdningstjänsten, blir kvar när appen avslutats helt) stängs en gång en minut efter att WoW startat –
  bara om Battle.net-appen själv inte är öppen. Journalen: "Battle.nets Agent stängd". Battle.net startar den igen.
- Vad som räknas som spel: /usr/share/goblincakes/gaming.py. Reglage: Config → Inställningar → Spel.
- Fläktboost (Lenovo IdeaPad/Legion, bara där `/sys/bus/platform/devices/VPC2004:*/fan_mode` finns): fan_mode 4 under spel,
  förra läget tillbaka efteråt (0 tyst, 1 standard, 2 dammrensning, 4 kylning). Skrivbar via udev-regeln
  /usr/lib/udev/rules.d/60-goblincakes-ideapad-fan.rules. Av = ~/.config/goblincakes/fan-boost-off (reglaget "Fläktboost under spel").
  Kolla: `cat /sys/bus/platform/devices/VPC2004:*/fan_mode`, `ls -l` på den (ska vara rw för alla), journalen ovan ("Fläktboost på").
- Kolla: `goblincakes-gameguard status` (/usr/libexec/), `journalctl --user -u goblincakes-gameguard -n 50`.
Kontroll: `/usr/libexec/goblincakes-gameguard status`

## goblin frames och MangoHud
Ord: frames, fps, mangohud, 1% low, ryck, stutter, frametider
- `goblin frames` visar hur jämnt spelet gick (fps, 1 % low, ryck); mätningen sparas i
  ~/.local/state/goblincakes/frames/. Notis efter spelet: tjänsten goblincakes-frames.
- MangoHud: reglage i Config, inställningar i GOverlay; GOBLINCAKES standard /usr/share/goblincakes/mangohud/.

## WoW och tilläggen
Ord: wow, world of warcraft, battle.net, tillägg, addon, addons, bugsack, lua-fel, wowup, archon, wtf, wowapi, api, .toc
- WoW installeras via Battle.net i Lutris (eller Steam). `goblin wow` länkar alla versioner under ~/Games/WoW/
  (<version>/AddOns, Logs, WTF) – det är länkar till där spelet verkligen ligger (…/_retail_/Interface/AddOns).
- Fel i ett tillägg: verktyget wowfel visar BugSacks fel med fil och radnummer. Läs raden i tilläggets fil, rätta
  den med verktyget byt_text (ett Tillåt-kort – filen säkerhetskopieras först), och be användaren skriva `/reload` i spelet.
  Ett tillägg med en .git-mapp är användarens eget: `git -C <mappen> diff` visar vad som ändrats sedan senast.
- WoW:s funktioner: verktyget wowapi slår upp en funktion, händelse eller ramtyp för spelet just nu, och `kolla <mapp>` jämför ett tilläggs .toc och .lua med spelet (påhittade namn, fel .toc-namn, Interface-raden). Datan: ~/.local/share/goblincakes/wowapi/index.json (hämtas igen efter en vecka; `python3 /usr/share/goblincakes/ai/wowapi.py hämta`). Efter varje ändring i ett tilläggs fil kör Goblin AI kontrollen själv. Kontrollen läser också Lua-koden med `luajit` (samma Lua som WoW): "Lua-fel" = WoW laddar inte filen alls. Den ser även fel antal argument till C_-funktioner och `.fält` på en funktion som ger tillbaka tal. Och variabler som används men aldrig får ett värde (en `local` som försvann). Den ser inte om tillägget gör rätt sak – det provas i spelet (/reload). En `sed` som inte hittade texten säger ändå OK – Goblin AI säger till efteråt.
- Bara användarens egna tillägg får ändras (git-klonerna i AddOns, eller listan ~/.config/goblincakes/egna-tillagg) – andras (BigWigs, EllesmereUI, RaiderIO …) stoppas; förklara felet och föreslå WoWUp eller att säga till den som gjort det. Committa aldrig – användaren sparar ändringen själv.
- Ändra aldrig spelets egna filer – bara tilläggens filer och inställningar.
- WoWUp uppdaterar tilläggen. Ikonerna för Archon, Raider.IO och WowUp i systemfältet är våra (tjänsten
  goblincakes-archon-tray): deras egna ligger bakom pilen (systray.js), eftersom vänsterklick på dem inte gör något
  (Electron) – vårt vänsterklick väljer programmets "Open …"/"Show" i dess meny. Öppnas inget fönster: kör tjänsten?
  (systemctl --user status goblincakes-archon-tray)

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
- Spelets egna inställningar (30 okt) står sist i rapporten, bara lästa: WoW = <versionsmappen>/WTF/Config.wtf
  (hittas via ~/Games/WoW/<version>/AddOns; grafikläge, raidläge, renderskala, fps-tak, vsync, grafik-API,
  siktavstånd …), CS2 = Steam/userdata/<id>/730/local/cfg/cs2_video.txt + fps_max ur cs2_user_convars/autoexec.cfg.
  "Inställningarna mot mätningen" = vad de betyder bredvid siffrorna (fullt grafikkort + högt grafikläge, inget
  fps-tak, vsync). Föreslå ändringar i spelets meny – filerna ändras aldrig (ändrande kommandon på dem stoppas).
- Kolla: `goblincakes-lagmeter status`, `goblincakes-lagmeter rapport` (= verktyget lagg),
  `journalctl --user -u goblincakes-lagmeter`.
Kontroll: `/usr/libexec/goblincakes-lagmeter status`

## Kakans röst (röstknappen)
Ord: röst, röstknappen, f8, prata, hör inte, hörde fel, uppläsning, rutan, whisper, piper, menade du, lärt
- Håll F8 (musknapp 4 på G502 = F8) och prata, släpp när du är klar. Tjänsten goblincakes-voice
  (/usr/libexec/goblincakes-voice listen, /usr/lib/systemd/user/goblincakes-voice.service) startar bara om
  miljön finns: ~/.local/share/goblincakes-voice (venv med faster-whisper + Piper, kb-whisper-small, rösterna).
- Uttal: Piper läser rent (inget filter); ord hon säger fel stavas om i SAY_AS i /usr/libexec/goblincakes-voice
  (t.ex. Goblin AI → "Gåbblinn ej-aj", GoblinAmp → "Gåbblinn-amp"). Prova: goblincakes-voice say "<text>".
  Kortkommandot heter "goblincakes-voice" i Systeminställningar → Genvägar. Inte F20–F23 (mikrofon av/pekplatta).
- Medan knappen hålls tystas bara mikrofonen mot Discord (dess PipeWire source-output), sedan på igen.
- Tal → text (Whisper, ~1,5 s) → enkla kommandon direkt utan språkmodell (/usr/share/goblincakes/ai/voicecmd.py):
  musik (spela album/låt/artist/min spellista/senaste albumet på Spotify via GoblinAmps inloggning), volym, paus,
  nästa, starta spel och program, klockan, senaste pullen, "det laggar" (= lagmätaren mark). Annat → Goblin AI
  öppnas med frågan (`goblin-ai --ask`). Under spel: inget läses upp, bara rutan; frågor får vänta.
- Musiken kontrolleras: dina listor/sparade album/gillade låtar först (~/.cache/goblincakes/voice-words.json,
  hämtas en gång per dygn), osäkert → "Menade du …?" (ja/nej inom en minut), bara artist → "Vilket album eller låt?".
- Hon lär sig felhörningar: ja/nej sparas i ~/.config/goblincakes/voice-learned.json; "nej" direkt efter = glöm.
  Lista/glöm: `/usr/libexec/goblincakes-voice lärt`, `/usr/libexec/goblincakes-voice glöm <nr|alla>`.
- Rutan uppe till höger (`goblincakes-voice box`, /usr/share/goblincakes/voice/Box.qml, layer-shell över helskärm,
  tar inga klick). Syns den inte: kraschar den visas Plasmas egen ruta i stället – se loggen.
- Kolla: `systemctl --user status goblincakes-voice`, `journalctl --user -u goblincakes-voice` (raderna "Hörde",
  "Kommandon", "Svar", "Lärde mig"), `/usr/libexec/goblincakes-voice status`, prova hörseln utan knappen:
  `/usr/libexec/goblincakes-voice test 5`.
- Ny Fedora = ny Python (44 → 45: 3.14 → 3.15): röstens miljö (venv/lib/pythonX.Y) är gjord för den gamla och
  måste göras om – modellerna ligger kvar. Tjänsten märker det vid inloggning och visar notisen "Kakans röst
  behöver lagas" med knappen Laga nu (inget hämtas utan knappen; stängd notis = frågar igen nästa inloggning, och
  tjänsten är då stoppad utan fel). `goblin update` lagar det också (steget Kakans röst).
  Kolla: `/usr/libexec/goblincakes-voice status` → "stale": true = behöver lagas; `/usr/libexec/goblincakes-voice
  stale; echo $?` (0 = behöver lagas); laga för hand: `/usr/libexec/goblincakes-voice install`.
Kontroll: `/usr/libexec/goblincakes-voice status`

- Under spel (7 nov): en fråga som inte är ett kommando ("gear planner funkar inte, kolla det") går till Goblin AI
  utan att fönstret kommer över spelet – rutan säger "Jag tar det i Goblin AI – svaret kommer på andra skärmen",
  Claude Haiku (Kakans reserv) startar i TERMINAL-fliken, Goblin AI visas på den lediga skärmen med en notis. Hon
  läser aldrig upp något under spel.
- 8 nov: under spel frågar rutan först "Vill du att Claude tittar på det nu, eller kan det vänta …?" och hon lyssnar
  själv (utan F8) i 6 s: "Claude"/"nu"/"ja" = Goblin AI direkt, "vänta"/inget = sparas i
  ~/.local/share/goblincakes-voice/efter-spelet.json; när spelet stängts (koll var 30:e s) en notis med
  frågorna: Skicka till Claude / Släng (stängd utan val = ligger kvar till nästa spel). "fel"/"glöm det" = slängs direkt.
  Bara "Kakan" (eller "hej Kakan") = "Hej <namn från kontot>! Vad kan jag hjälpa dig med?" och sedan lyssnar hon själv.
  Loggen: "Lyssnade själv … s", "Sparad till efter spelet", "Spelet slut – N sparade frågor".
## Steam och spel
Ord: steam, proton, spel startar inte, goblin play, tv-läge, big picture, lutris, heroic
- Steam finns i systemet. `goblin play <namn>` startar Steam-spel från terminalen (/usr/libexec/goblincakes-games),
  egna ord i ~/.config/goblincakes/game-aliases. TV-läge: `goblin tv`.
- Krascher syns med verktyget systemfel (coredumps).
- Steam vid inloggning väntar (högst 30 s) tills alla bibliotek i libraryfolders.vdf finns: /usr/libexec/goblincakes-steam-wait-libraries
  (ExecStartPre i /usr/lib/systemd/user/app-steam@autostart.service.d/). Shaderbearbetningen: ~/.local/share/Steam/logs/shader_log.txt
  ("Committed bucket … from 0" = börjar om från noll).

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
- Battle.net (Proton/Wine) maximeras aldrig på riktigt: maximera (knappen, dubbelklick, Meta+↑) gör det till ett vanligt
  fönster som fyller skärmen (KWin-skriptet `goblincakes-windows`; maximerat hamnade klicken bredvid knapparna – Wine/CEF).
  Battle.nets menyer (högerklick på ikonen) är egna fönster och lämnas i fred. Klicken fel ändå → är fönstret maximerat?
- Vilken skärm ett program öppnas på: `goblin screen` (/usr/libexec/goblincakes-screen). Olika Hz: goblincakes-screens.
- Rotera skärm: `goblin screen rotate 2` (skärm 2 stående), `rotate normal` (alla liggande), `rotate håll vänster|höger` (åt vilket håll, sparas i ~/.config/goblincakes/screen-portrait). Kortkommandon Meta+← (skärm 2), Meta+→ (skärm 1), Meta+↑ (alla) i /usr/share/kglobalaccel/goblincakes-rotate.desktop; KWins "Fönster snabbt sida vid sida" flyttas bort från dem en gång (flaggan ~/.local/state/goblincakes/meta-arrows-rotate). Kolla: `kscreen-doctor -o` (Rotation: 1 = liggande, 2 = vänster, 8 = höger).
- Rutor/layouter: `goblin tile` och Config → Fönster, ~/.config/goblincakes/tile-layouts.json.
- KWin-skriptet /usr/share/kwin/scripts/goblincakes-windows placerar fönster (Config i mitten, spel på rätt skärm,
  rutor, Meta+Z). Kolla `journalctl --user -b | grep -i goblincakes-windows`.

## Grafikkort och drivrutiner
Ord: grafikkort, gpu, nvidia, drivrutin, amd, secure boot, variant, anticheat, easy anti-cheat, fortnite, tpm, faceit, ricochet, javelin, battlefield, call of duty, antifusk
- Tre varianter: goblincakes (AMD/Intel), goblincakes-nvidia, goblincakes-nvidia-legacy (GTX 900/10).
  Byte: Config → Grafik (/usr/libexec/goblincakes-gpu). Vilken som körs: `rpm-ostree status`.
- Kolla: `nvidia-smi`, `lspci -k | grep -A3 -i vga`.
- Easy Anti-Cheat v2 (Fortnite m.fl., Epics krav för Linux): `goblin anticheat` (läser bara) visar tio kontroller –
  signerad kärna/drivrutiner, TPM 2.0, Secure Boot, bara kända MOK-nycklar, measured boot, IOMMU, lockdown, kexec av,
  BPF-LSM. Hjälparen /usr/libexec/goblincakes-anticheat (`check --json`; lockdown och TPM-loggen läses som root via
  pkexec, polkit org.goblincakes.anticheat, inget lösenord). `goblin anticheat fixa` ändrar kärnans argument
  (rpm-ostree kargs, gäller efter omstart), `ångra` tar tillbaka dem; vad som ändrats: ~/.local/state/goblincakes/anticheat-kargs.json.
  BIOS-delarna (Secure Boot, TPM, IOMMU) kan bara användaren slå på. Kort i Config → Grafik. Kolla: `rpm-ostree kargs`.
- Varför Secure Boot spelar roll för anti-fusket: Easy Anti-Cheat v2 på Linux vill kunna lita på att datorn startade
  med en orörd, signerad kärna och signerade drivrutiner – så att inget fuskprogram kan ha laddats in i systemet innan
  spelet. Secure Boot (och TPM, som intygar hur datorn startade) är beviset; utan det startar spelet inte, eller kör utan
  anti-fusk-kraven. Det handlar inte om att spelet självt eller grafikdrivrutinen saknar signatur. Fortnite finns inte för Linux än.
- Bevakning av anti-fusk för Linux (användaren vill spela CS2 på FACEIT, Call of Duty och Battlefield utan Windows):
  `bevaka antifusk` (lagd på användarens dator 5 nov, en gång) läser en gång om dagen areweanticheatyet.coms lista
  (ai/anticheatwatch.py, games.json på GitHub) och ger en notis när status ändras för spel med FACEIT, Ricochet (CoD)
  eller EA Javelin (Battlefield), en ny rad i ett spels historik eller ett nytt spel. Läget nu: `python3
  /usr/share/goblincakes/ai/anticheatwatch.py` (läser bara). Senast sett: posten "antifusk" i vakt.json. Sluta:
  `påminnelser bort antifusk`. Bakgrund: Epics EAC v2 (se ovan) är modellen de andra kan kopiera; EA har sagt att de
  undersöker Linux för Javelin, Activision och FACEIT har inga planer (5 nov).

## Diskar
Ord: disk, diskar, hårddisk, usb, montera, automount, ägare, rättigheter
- Alla diskar monteras vid inloggning (/usr/libexec/goblincakes-automount) under /run/media/$USER/<namn>;
  goblincakes-disk-owner gör användaren till ägare av nya Linux-diskar.

## Utseende och färg
Ord: utseende, tema, färg, accent, accentfärg, låsskärm, inloggning, sddm, ikoner, typsnitt, fönsterram, namnlist, aurorae
- Accentfärgen: `goblin färg` / Config (/usr/libexec/goblincakes-accent, även inloggningsskärmen via
  goblincakes-sddm-accent). Utseendet läggs på vid första inloggningen av /usr/libexec/goblincakes-firstlogin.
- `goblin dock reset` återställer allt utseende.
- Stil (11 nov): Config → Inställningar → Utseende → Stil = Platt (standard) eller Levande; valet i
  ~/.config/goblincakes/utseende (`platt`/`levande`, ingen fil = platt), läses av /usr/share/goblincakes/accent.py
  (`look()`) och följs direkt av GOBLINCAKES egna fönster (QML-egenskapen `look`). Levande byggs i omgångar.
  Med Levande tonar knappar/kryssrutor/reglage/fält och knappar trycks ner 1 px (steg 2) – men bara när `look.motion`:
  inget spel kör ($XDG_RUNTIME_DIR/goblincakes-gaming från goblincakes-gameguard) och Plasmas animationer inte är
  avstängda (kdeglobals AnimationDurationFactor). Ljuset i ramarna (qml/Goblin/Light.qml) och bakgrunden (Backdrop.qml)
  syns med Levande, även under spel. Kolla: `python3 -c "import sys; sys.path.insert(0,'/usr/share/goblincakes'); import accent; print(accent.look())"`.
- Stil Levande byter Plasma-temat till goblincakes-levande (toppfältet som tonat glas; byggs i imagen av
  files/scripts/desktoptheme-levande.sh från goblincakes-temat), Platt tillbaka till goblincakes – bara om ett av de två
  används. Vid inloggning rättar goblincakes-refresh.sh temat efter valet. Kolla: `kreadconfig6 --file plasmarc --group
  Theme --key name`. Dockan och toppfältets widgetar (Spelas nu, kvot, uppdateringar, klockraden) läser valet när filen byts (FolderListModel), annars var 60:e s.
- GOBLINCAKES egna fönster delar knappar, kryssrutor, reglage, textfält, rullister och ramar:
  /usr/share/goblincakes/qml/Goblin/ (FlatButton.qml m.fl.). Ser alla fönstrens knappar fel ut → där.
- Fönsterramarna: Aurorae-temat /usr/share/aurorae/themes/goblincakes, ritat av Aurorae v2 (kwinrc
  [org.kde.kdecoration2] library=org.kde.kwin.aurorae.v2). Death Knight: eget tema goblincakes-dk i
  ~/.local/share/aurorae/themes (orange stäng). Kolla: `kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme`
  och `--key library`. Genomskinlig namnlist (bara titeln syns) = v2 minns en borttagen temamapp – logga ut och in.

## Terminalen (Ghostty, Konsole, Kitty)
Ord: terminal, ghostty, konsole, kitty, terminalval
- Valet i Config → Program → Terminal: /usr/libexec/goblincakes-terminal (`status`, `set ghostty|konsole|kitty`,
  `run <kommando>`); valet i ~/.config/goblincakes/terminal (ingen fil = Ghostty). Sätter kdeglobals
  TerminalApplication/TerminalService och byter terminalen i dockan.
- Ghostty i imagen, utseendet ~/.config/ghostty/config.ghostty (temat /usr/share/ghostty/themes/GoblinCakes).
  Konsole i imagen, profilen /usr/share/konsole/GoblinCakes.profile.
- Kitty: Kittys egen version i ~/.local/kitty.app (hämtas från GitHub när man väljer den, version i
  .goblincakes-version), ~/.local/bin/kitty, menyposten ~/.local/share/applications/kitty.desktop. Uppdateras med
  `goblin update --only kitty`. Utseendet ~/.config/kitty/kitty.conf (include /usr/share/goblincakes/kitty/GoblinCakes.conf
  + goblincakes-accent.conf = accentfärgen från goblincakes-accent). `goblincakes-terminal kitty-config --reset` = ny
  kitty.conf (den gamla som .bak). Kolla: `goblincakes-terminal status`, `~/.local/bin/kitty --version`.
- Accentfärgen i terminalerna (goblincakes-accent): Ghostty ~/.config/ghostty/themes/GoblinCakes (kopia av temat med
  markörfärgen, borta vid blå; läses när Ghostty startar), Konsole ~/.local/share/konsole/GoblinCakes.profile
  (CustomCursorColor), Kitty goblincakes-accent.conf.

## Webbläsare och webbappar
Ord: webbläsare, chrome, firefox, brave, webapp, webbapp
- Huvudwebbläsaren: Config → Program (/usr/libexec/goblincakes-browser). Webbappar får ikon av
  goblincakes-webapp-icon.

## Ljud
Ord: ljud, pipewire, latens, mikrofon, headset, högtalare
- PipeWire med låg latens: /usr/share/goblincakes/pipewire/. Kolla: `wpctl status`, `pactl list sinks short`.

## Tangentbord: dubbla tryck
Ord: tangentbord, dubbla tryck, två tryck, studsar, studsande tangenter, key chatter, tangentupprepning, press and hold
- Fråga först VAR det händer. Bara i WoW (spells med charges/utan GCD går iväg två gånger): nästan alltid WoW:s
  "Press and Hold Casting" (CVar `ActionButtonUseKeyHeldSpell 1` i WTF/Config.wtf eller WTF/Account/*/config-cache.wtf –
  läs med grep, ändra aldrig). Lösning: i spelet Options → Gameplay → Combat → kryssa ur Press and Hold Casting.
- Överallt (även i text): kolla tangentupprepningen i ~/.config/kcminputrc, gruppen [Keyboard] (`KeyRepeat=`,
  `RepeatDelay=`). Mycket kort RepeatDelay ger dubbla tecken.
- Säg inte "studsande tangent" (kontaktstuds) innan det är provat: be användaren köra i terminalen
  `sudo timeout 20 libinput debug-events --show-keycodes` och trycka lugnt på tangenten. Ett tryck = en `pressed` +
  en `released`; två `pressed` på ett tryck = tangenten studsar. Då: Systeminställningar → Hjälpmedel →
  Tangentbordsfilter → Studsande tangenter → Aktivera (fördröjning ~30–50 ms), eller rengör/byt switchen.

## Laptop
Ord: laptop, bärbar, batteri laptop, dubbla grafikkort
- /usr/libexec/goblincakes-laptop körs vid inloggning (gör inget på stationära). Laptop = chassityp eller eget batteri (inte musens/headsetets) – kolla: `/usr/libexec/goblincakes-gpu hw` ("laptop", "hybrid").
- Prestanda (strömmenyn/Config → Prestandaläge) = tuned-profilen goblincakes-performance (/usr/lib/tuned/profiles/,
  vald i /etc/tuned/ppd.conf): Fedoras throughput-performance men med liten skrivbuffert (dirty 10 %/3 % i stället
  för 40 %) – annars frös en hårddisk i flera sekunder. Kolla: `tuned-adm active`, `cat /proc/sys/vm/dirty_ratio`.
- Förvärmning (bara med hårddisk): användartjänsten goblincakes-prewarm (timer 60 s efter inloggning, lägsta
  prioritet) läser de mest startade programmen (användarens journal, 14 dagar, högst 6 st / 2 GB) in i minnet –
  annars tog Firefox 23 s första gången efter start. /usr/libexec/goblincakes-prewarm --list visar vad;
  "SSD – inget att förvärma" = rätt på SSD. Kolla: `journalctl --user -u goblincakes-prewarm`.
- Wifi utan strömsparläge på alla datorer: /usr/lib/NetworkManager/conf.d/90-goblincakes-wifi-powersave.conf
  (wifi.powersave = 2). Kolla: iw dev <wlp…> get power_save → "off". Står det "on": har anslutningen egen
  inställning? nmcli -f 802-11-wireless.powersave connection show <namn> (0 = följer vår fil).

## ChatGPT-appen
Ord: chatgpt, openai-appen
- OpenAIs app uppackad i hemmappen, startas med /usr/libexec/goblincakes-chatgpt; uppdateras med goblin update.

## Barnläge
Ord: barnläge, barn, sandlåda, kids, PIN-kod barnläge, goblin barn
- Fönstret: /usr/bin/goblin-kids (PySide6) + /usr/share/goblincakes/kids/ (Main.qml, Splash.qml, Scene.qml, kids.py,
  kwin-on.js/kwin-off.js). Start: `goblin barn`, AppGrid "Barnläge" eller Config → BARNLÄGE → Starta barnläget.
- Inställningar: ~/.config/goblincakes/kids.json (spelen i ordning, PIN-koden som pbkdf2-hash – aldrig i klartext,
  volym, bakgrund). Föräldrens bilder: ~/.local/share/goblincakes/kids/bilder/. Omslag och ljud: ~/.cache/goblincakes/kids/.
- Medan det är på: ~/.local/state/goblincakes/kids-active.json (vad som ska tillbaka). KWin-skriptet goblincakes-kids
  laddat, fönsterregeln goblincakes-kids i ~/.config/kwinrulesrc (inga globala kortkommandon), PowerButtonAction 0 i
  ~/.config/powerdevilrc, "no_display" under raden "# goblincakes-barnläge …" i ~/.config/MangoHud/MangoHud.conf.
- Kolla om det är på: `cat ~/.local/state/goblincakes/kids-active.json` (pid). Fast på / kortkommandon döda efter en
  krasch: `goblin barn stopp` (eller `goblin-kids --restore`, körs också vid varje inloggning). Glömd PIN:
  Ctrl+Alt+F3, logga in, `goblin barn stopp`.
- Steam-spel startas med `goblincakes-games run-id <appid> --kids` (som goblin play). Steam-överlägget per spel:
  OverlayAppEnable i Steams userdata/<id>/config/localconfig.vdf (kopia .goblincakes-bak när Config ändrat den).
- Namnen (Cori säger spelets namn när musen vilar på det): ljuden i ~/.local/share/goblincakes/kids/namn/, görs av
  `python3 /usr/share/goblincakes/kids/namnljud.py make` (Chatterbox om mappen finns, annars Piper-Cori i
  ~/.local/share/goblincakes-voice). Vilken röst: `python3 /usr/share/goblincakes/kids/namnljud.py engine`.
- Musikbilden: GOBLINCAKES låtar (/usr/share/goblincakes/songs) spelas med ffmpeg | pw-cat (egen processgrupp,
  Stopp = TERM sedan KILL). Hörs inget: `pgrep -a pw-cat` medan en låt ska spela. Av/på i kids.json "music".

- Pixelart (14 nov): de fyra bakgrunderna visas i dina pixelbilder (du ritade alla 15, användaren godkände dem):
  /usr/share/goblincakes/kids/pixelart/<id>.png, Scene.qml → PixelScene.qml (Pix.qml = skarp hel förstoring);
  den gamla ritade versionen = DrawnScene.qml, väljs med "pixelart": false i kids.json. Splashen (Splash.qml,
  Glint.qml; färgade gnistor = tools/pixelart-tint.py) också; rutorna är inte bytta än. Rita om: `goblin pixelart` →
  /usr/libexec/goblincakes-pixelart, listan /usr/share/goblincakes/kids/pixelart.json. `kakan <id>` = du ritar med
  bildprogrammet (`goblincakes-image generate … --style pixelart`: Z-Image-Turbo + pixelart-tillägget i
  <bildmappen>/loras/, hämtas första gången), `chatgpt <id>` = Codex i ChatGPT-appen (användaren trycker Enter; stilen
  står i ~/.codex/AGENTS.md mellan raderna "goblincakes-pixelart: början/slut"), `jämför` = jämförelsebilden.
  Allt i ~/Bilder/Barnläge/pixelart/<kakan|chatgpt>/: <id>-rå.png (som ritad), <id>.png (städad, riktiga pixlar),
  <id>-stor.png (×6). Kolla stilen: `goblincakes-image status` → "styles". Fel "kräver Z-Image-Turbo" = hämta den
  under AI-tjänster → Skapa bilder. I chatten: ```bild med raden `Stil: pixelart` efter Format.
