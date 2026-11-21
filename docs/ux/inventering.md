# UX-underlaget (steg A) – inventering av GOBLINCAKES egna fönster

Underlag för UX-granskningen (steg B, `docs/optimering/startinstruktion.md` del 3). Insamlat 21 nov av Opus. **Ingen kod ändrad.**
Sökvägar är relativa till `files/system/usr/` om inget annat står. Rader gäller commit 1b98b094.

## 1. Skärmarna (kscreen-doctor -o + EDID)

| Utgång | Skärm | Upplösning | Skalning | Fysisk storlek | ppi | Plats |
|---|---|---|---|---|---|---|
| DP-1 | ASUS VG279 | 1920×1080 @ 144 Hz | 1 | 598×336 mm (27 tum) | **82** | vänster (0,0) |
| HDMI-A-1 | MSI MAG 275F | 1920×1080 @ 180 Hz (HDR på) | 1 | 598×336 mm (27 tum) | **82** | höger (1920,0), primär |

**Obs till granskningen:** användarens 1080p-skärmar är **27 tum (82 ppi)**, inte 24 tum (92 ppi) som steg B:s text räknar med. En 27-tums 1440p-skärm (109 ppi) visar alltså samma text **ca 25 % mindre** än hos användaren i dag, inte 15 %.

Skrivbordets upplägg hos användaren: **Dashboard** (`goblincakes-desktop-layout status`), alltså skrivbordsraden överst och ingen docka eller toppfält. Standard för nya användare är toppfält och docka.

## 2. Skalningen – fem olika sätt i dag

| Sätt | Fönster | Var |
|---|---|---|
| `QT_SCALE_FACTOR=0.9`, fast | GoblinRecorder, GoblinShare, Avinstallera, lagmätaren, röstrutan, Dashboard | `bin/goblin-recorder:786–791`, `bin/goblin-share:404–409`, `libexec/goblincakes-remove-apps:164–169`, `libexec/goblincakes-lagmeter:774–783`, `libexec/goblincakes-voice:692–702`, `bin/goblin-dashboard:806–811` |
| Ingen skalfaktor; `win.contentItem` zoomas 0,94 → 1,04 efter fönstrets storlek (`fitZoom`) | Config | `share/goblincakes/config/Main.qml:11–27`, `bin/goblincakes-config:1447–1449` |
| `uiScale` 0,8 × `zoomRoot` 0,94 → 1,04 efter fönstrets storlek (Chromium i TERMINAL klarar inte QT_SCALE_FACTOR < 1) | Goblin AI | `bin/goblin-ai:3589–3593`, `share/goblincakes/ai/Main.qml:12–15`, `:1211–1225` |
| 0,9 **plus** egen uppskalning av allt när fönstret växer (1,0 → 1,6, `min(w/1080, h/720)`) | GoblinShare | `share/goblincakes/share/Main.qml:47–48`, `:439–445` |
| 0,9 **plus** uppskalning av vissa delar (inställningar och inspelningspanelen, 1,0 → 1,7, `w/1320`) | GoblinRecorder | `share/goblincakes/recorder/Main.qml:28`, `:1051`, `:1068`, `:3261` |
| Ingen skalning alls (100 %), fasta pixlar | GoblinAmp, goblin graph | `bin/goblin-amp:1955–1985`, `bin/goblin-graph` (ingen QT_SCALE_FACTOR) |

Varje startprogram har en egen kopia av samma startkod (`use_accent`, `cached_qml`, skalan, ett fönster i taget via QLocalServer): `use_accent` i `bin/goblin-share:35`, `bin/goblin-recorder:667`, `bin/goblin-dashboard:56`, `bin/goblincakes-config:1416`, `bin/goblin-ai:3542`, `bin/goblin-graph:796`, `libexec/goblincakes-remove-apps:132` (GoblinAmp lånar graphs: `bin/goblin-amp:2011`); `cached_qml` i alla tio. Det är P17 i `docs/optimering/granskning.md` (en gemensam `goblinapp.py`).

## 3. Fönster för fönster

Mått i tabellerna: **QML** = måtten i koden, **på 1080p** = det KWin mätte i provmiljön (klientytan, utan namnlist; namnlist + kant = +8×42 px). "Största innehållsbredd": om något i fönstret slutar växa när fönstret blir bredare.

### 3.1 GOBLINCAKES Config
- **Start:** `bin/goblincakes-config` → `share/goblincakes/config/Main.qml` (4 767 rader) + `KidsView.qml` (717).
- **Skala:** egen zoom, se ovan. Start-/minstamått gånger `startZoom` 0,94.
- **Storlek:** start 1180×800 (`Main.qml:14–15`, `:29–30`) → 1109×752 på 1080p; minst 760×560 (`:31–32`) → 714×526. Fast i px, inte efter skärmen. Mitten av skärmen (KWin-skriptet).
- **Största innehållsbredd:** ingen. Alla vyer är `anchors { left; right; top: header.bottom; bottom: footer.top }` (`:585`, `:1046`, `:1185`, `:1874`, `:1880`, `:2772`, `:3780`, `:4258`, `:4359`). Kortrutnätet räknar kolumner `floor((w+16)/340)` (`:768`), så det blir bara fler kolumner.
- **Förankring:** rubriken (`header`, `:432–435`, höjd 176) och foten (`footer`, `:4635`, höjd 84) fyller bredden; texter vänsterställda; tomma lägen `anchors.centerIn` (9 st).
- **Komponenter från qml/Goblin:** FastWheel, FlatField, FlatButton (standardmåtten = Configs, `:381`), CheckSquare, Monogram, FlatScrollBar, ToggleSwitch, Backdrop, Light (38 st). **Egna:** ResultMark (`:388`), CardSwitch (`:1151`), Stepper (`:1657`), SmallButton (`:1836`); i KidsView Heading/Body/Small (`KidsView.qml:106–118`).
- **Text (pixelSize):** 11 ×3, 12 ×11, **13 ×54**, **14 ×40**, 15 ×15, 16 ×16, 22, 30.
- **Mått:** knapp 44 hög, minst 150 bred, 15 px text (`qml/Goblin/FlatButton.qml:16–19`); fält 44 (`FlatField.qml:20`); kryss 22; marginaler oftast 48 i sidled (`leftMargin: 48` ×4), mellanrum 8–14.
- **Sett på bild (1080, max):** kategoriraderna och länkfältet sträcks över hela 1 820 px; terminalkorten är kvar i 3 × 434 px till vänster med tom yta till höger; långa förklaringsrader går över nästan hela skärmen (problem B).

### 3.2 Goblin AI
- **Start:** `bin/goblin-ai` → `share/goblincakes/ai/Main.qml` (8 280 rader) + `FilesPane.qml`, `TerminalView.qml`.
- **Skala:** `uiScale` 0,8 × zoomRoot 0,94 → 1,04.
- **Storlek:** **startar maximerad** med flit (`Main.qml:607`, användarens önskan 1 nov). Normal (avmaximerad) 1320×860 × 0,8 (`:12–13`) → 1056×688; minst 980×600 × 0,8 (`:14–15`) → 784×480. Stående skärm: rutorna läggs på en rad överst (`portrait`, `:40`).
- **Största innehållsbredd:** ingen för chatten och inmatningen; vänsterspalten är fast 330 (`sideWidth`, `:42`).
- **Förankring:** 83 `anchors.fill`, 19 `centerIn`; välkomstvyn är centrerad.
- **Från qml/Goblin:** FastWheel, FlatButton (egna mått 120/40/40/14 + små 70/24/30/13, `:1303–1306`), Backdrop, Light (33), FadeText, ClaudeMap, Count. **Egna:** HoverHint (`:61`), ModelTag (`:84`), StepList (`:106`), WaitDot (`:1245`), SimilarBox (`:1262`), BlockCaret (`:1310`), TextAction (`:1338`), Label (`:1361`), CodeBox (`:1370`), Panel (`:1406`), GroupLabel (`:1470`), PanelRow (`:1482`), Pick (`:4455`), DailyModels (`:6850`); FilesPane: Tool (`FilesPane.qml:22`).
- **Text:** 10 ×7, 11 ×22, 12 ×69, **13 ×113**, 14 ×43, 15 ×7, 16 ×17, 18 ×8, 24, 28 m.fl. (12 olika storlekar).
- **Sett på bild (1080, max):** chattens inmatningsrad och verktygsraden går över hela bredden (ca 1 500 px), välkomsttexten är centrerad i mitten.

### 3.3 GOBLINCAKES Dashboard (+ skrivbordsraden)
- **Start:** `bin/goblin-dashboard` → `share/goblincakes/dashboard/Main.qml` (4 135 rader). Ramlös, helskärm (`win.showFullScreen()`, `bin/goblin-dashboard:867`); QML-måttet 1920×1080 (`Main.qml:19–20`) ersätts av skärmens.
- **Skala:** 0,9 → på 1080p ritas den som 2 133×1 200 logiska px.
- **Största innehållsbredd:** ingen; mitten fyller det som blir över mellan sidospalterna. Programrutnätet `floor((w-12)/132)` kolumner (`:1961–1962`), systemrutan 3 eller 2 kolumner efter bredd (`:2064`).
- **Från qml/Goblin:** FastWheel, FlatScrollBar, FlatButton (96/32/40/14, `:288–289`), Frame, Backdrop, Rise, Light, LiveTag, Count, RollText, FlatField, ClaudeMap, FadeText. **Egna:** FrameColumn (`:247`), Heading (`:294`), AppIcon (`:304`), Tile (`:369`), SideCard (`:395`), Cell (`:457`), StepMark (`:466`), HeadCell (`:484`), BigTitle (`:491`), SubTitle (`:497`), Meter (`:504`), Bars (`:518`), Glyph (`:544`), TopIcon (`:563`).
- **Text:** 10–34, flest 12 (×44) och 13 (×32).
- **Skrivbordsraden:** Plasma-panel med `plasmoids/org.goblincakes.deskclock` (`ClockBox.qml`, `DeskIcon.qml`) och `org.goblincakes.nowplaying` (`DeskBox.qml`), byggd av `libexec/goblincakes-desktop-layout`. Fasta mått ur mockupen: höjd 48, Steam/Kakan 240 px, Discord/Spelas nu 300 px, klocka i Chakra Petch 34 px (anteckningarna, "Skrivbordsraden och valet i Config"). Panelens höjd 84. Bild: `skrivbordsraden-1080-riktig.png` (+ `-hel`, användarens bild 21 nov, upplägget Dashboard, ljus bakgrundsbild). **Sett på bild:** rutorna är halvgenomskinligt grå över en ljus bakgrund, så den små texten ("DISCORD · SHORT BUS", "Lobby", "SPELAS NU", "Inget spelas", "Redo") har svag kontrast; klockrutan är högre än Discord- och Spelas nu-rutorna (de ligger inte i linje nedtill); Discord-rutans text är högerställd, Spelas nu vänsterställd.

### 3.4 GoblinAmp
- **Start:** `bin/goblin-amp` → `share/goblincakes/amp/Main.qml` (2 200 rader). Ramlös, mjukvarurenderad.
- **Skala:** ingen (100 %).
- **Storlek:** **fast bredd 380** (`Main.qml:16`, `:33–34`), höjden efter vad som är öppet (`wantedHeight`, `:22`, `:36–37`) – 380×730 vid start. Går inte att maximera eller ändra.
- **Från qml/Goblin:** bara FastWheel. **Egna:** Btn (`:133`), SmallLink (`:546`) – alla knappar och reglage är egna (Winamp-stil).
- **Text:** mest 10–11 px (11 ×23, 10 ×11), 9–14 och 24 (tiden).
- **Fildialoger:** FileDialog/FolderDialog (`:2173–2195`) **utan** `onVisibleChanged: backend.sharpText()`.

### 3.5 GoblinShare
- **Start:** `bin/goblin-share` → `share/goblincakes/share/Main.qml` (1 509 rader); ChatWindow är ett eget `Window` i samma fil (`:152`).
- **Skala:** 0,9 + egen uppskalning 1,0 → 1,6 (se avsnitt 2): ett maximerat fönster blir större text, inte bredare innehåll.
- **Storlek:** start 1080×720 (`:12–13`) → 972×648; minst 800×560 (`:14–15`) → 720×504.
- **Från qml/Goblin:** FastWheel, FlatField, FlatButton (96/32/34/13, `:93`), ToggleSwitch, CheckSquare, FlatScrollBar, SectionTitle, Note, Backdrop, Light. **Egna:** DeviceGlyph (`:106`), ProgressLine (`:137`), ChatWindow (`:152`).
- **Text:** 11–44, flest 14 (×12).

### 3.6 GoblinRecorder
- **Start:** `bin/goblin-recorder` → `share/goblincakes/recorder/Main.qml` (3 990 rader).
- **Skala:** 0,9 + delvis uppskalning (se avsnitt 2).
- **Storlek:** start 1320×860 (`:13–14`) → 1188×774; minst 980×640 (`:15–16`) → 882×576.
- **Största innehållsbredd:** ingen; inspelningspanelen till höger är 268 × zoom (`:1051`), sidorna fyller resten (`:1203`, `:2417`, `:2903`, `:3260`).
- **Från qml/Goblin:** FastWheel, FlatField, FlatButton (96/32/34/13, `:446`), ToggleSwitch, FlatScrollBar, SectionTitle, Note, Backdrop, Light. **Egna:** SettingRow (`:418`), DemoStats (`:458`), HoverTip (`:693`), PanelSwitch (`:699`), StatusChip (`:723`), SeasonPicker (`:756`), Choice (`:800`), LeetifyMark (`:2201`), StatTile (`:2210`), TableRow (`:2264`), Bars (`:2318`).
- **Text:** 9–30 (+ 200 för en stor siffra), flest 12–15.
- **Sett på bild (1080, minsta):** rubriken "GOBLINRECORDER" går in under knappen "Starta inspelningstjänsten" (rubrikraden har inte plats), och knappraden under filmen ("Till YouTube …" m.fl.) klipps nedtill utan att gå att rulla (problem A).

### 3.7 goblin graph
- **Start:** `bin/goblin-graph` → `share/goblincakes/graph/Main.qml` (208) + `Views.qml` (187, delas med GoblinAmp).
- **Skala:** ingen. Ramlös och genomskinlig.
- **Storlek:** sparad i `graph.json`, annars 720×220 (`Main.qml:14–15`), plats sparad eller nere i mitten (`:16–17`); minst 160×60 (`:18–19`).
- **Komponenter:** inga från qml/Goblin (bara staplar och tre texter 13–15 px).

### 3.8 Lagmätaren
- **Start:** `libexec/goblincakes-lagmeter window` → `share/goblincakes/lagmeter/Main.qml` (228).
- **Storlek:** start 470×690 (`:10–11`) → 423×621; minst 380×520 (`:12–13`) → 342×468.
- **Förankring:** en `Column` med `anchors.fill` + marginal 16 (`:133–135`), graferna fyller bredden.
- **Från qml/Goblin:** FlatButton (130/40/40/14, `:40`), Backdrop, Light. **Egen:** Graph (`:44`).
- **Text:** 12, 13 (×4), 20.

### 3.9 Avinstallera program
- **Start:** `libexec/goblincakes-remove-apps` → `share/goblincakes/remove/Main.qml` (519).
- **Storlek:** start 1180×800 (`:12–13`) → 1062×720; minst 760×560 (`:14–15`) → 684×504 (samma mått som Config, men med 0,9 i stället för 0,94).
- **Största innehållsbredd:** ingen; kortrutnätet `floor((w+16)/340)` kolumner (`:223`, `:245`).
- **Från qml/Goblin:** FastWheel, FlatButton (Configs mått), CheckSquare, Monogram, FlatScrollBar, SectionTitle, Note, Backdrop, Light. **Egen:** AppIcon (`:86`).
- **Text:** 13, 15, 16, 30.
- **Sett på bild:** titelraden blir "Avinstallera program – GOBLINCAKES — Avinstallera program" (titeln + programmets visningsnamn). Maximerat: rutnätet blir 6 kolumner över hela bredden och Stäng/Verkställ hamnar längst ut till höger (problem B).

### 3.10 Röstrutan (Kakans röst)
- **Start:** `libexec/goblincakes-voice box` (startas av `listen`) → `share/goblincakes/voice/Box.qml` (131). Layer shell, uppe till höger, tar inte fokus eller musklick (`:18`).
- **Storlek:** bredd 420 (`:13`) → 378, höjd efter innehållet (`:14`). Ändras aldrig av användaren.
- **Komponenter:** inga från qml/Goblin. Text 13, 14, 16.

### 3.11 Toppfältet och dockan
- Plasma-paneler (inte egna fönster). `plasmashellrc` har kvar två paneler med tjocklek 36 och 52 px (troligen toppfältet och dockan från före Dashboard-upplägget, inte kontrollerat); Plasma-temats SVG:er från `tools/plasma-frames.py`.
- Egna widgetar: `plasmoids/org.goblincakes.dock`, `.updates`, `.quota`, `.week`, `.metahint`, `.nowplaying`, `.deskclock`.
- Användaren kör upplägget Dashboard, så toppfält och docka finns inte på skärmen just nu.

### 3.12 Låsskärm och utloggning
- **Två kopior** (ändra båda): `plasma/look-and-feel/org.goblincakes.desktop/contents/lockscreen/LockScreen.qml` + `share/goblincakes/plasma-shell/lockscreen/`, och `…/contents/logout/Logout.qml` + `share/goblincakes/plasma-shell/logout/` (kopieras in av `files/scripts/plasma-shell-overrides.sh`).
- Bilderna är tagna med den **installerade** versionen (`kscreenlocker_greet --testing`, `ksmserver-logout-greeter --windowed`), inte repots. Låsskärmens bakgrund i provmiljön är Plasmas standard, inte användarens. Utloggningen visades som fönster med namnlist; på riktigt är den i helskärm.

## 4. Skärmbilderna

I `~/.local/share/goblincakes/ux-bilder/` (stannar på datorn). Namn `<fönster>-<1080|1440>-<storlek>-<platt|levande>.png`; storlek = `start`, `min`, `halv` (rutad vänster halva), `max`, och för Goblin AI även `normal` (avmaximerad – den startar maximerad). KWin:s uppmätta mått för varje bild står i `geometri.txt` i samma mapp.

**Så togs de:** i en kapslad `kwin_wayland --virtual` med egen D-Bus och en kopia av `~/.config` och `~/.local/share/goblincakes`, så att användarens skärmar, inställningar och öppna program inte rördes. Fönstren startades från repot. Platt/Levande styrdes med kopians `goblincakes/utseende`. Det betyder: **ingen bakgrundsbild och ingen Plasma-panel** i bilderna, och "maximerat" fyller hela skärmen (på riktigt minus skrivbordsraden/toppfältet). Minsta/startbilderna är bara fönstret, de andra hela skärmen.

### Tagna (1080p, 1920×1080)
- **Platt, start/min/halv/max:** config, goblinshare, goblinrecorder, lagmataren, avinstallera; goblin-ai start/normal/min/halv/max.
- **Platt, bara start:** dashboard (helskärm), goblinamp (fast storlek), rostrutan, lasskarm, utloggning.
- **Platt, start/min/max:** goblin-graph.
- **Levande, start + max:** config, goblinshare, goblinrecorder, lagmataren, avinstallera; goblin-ai normal + max; dashboard start.

### Tagna (1440p, 2560×1440 – samma skript, 21 nov)
Samma uppsättning som på 1080p (46 bilder): Platt start/min/halv/max (Goblin AI även normal), dashboard/goblinamp/rostrutan/lasskarm/utloggning start, goblin-graph start/min/max; Levande start + max för samma sju fönster.
- **Startstorlekarna är exakt samma pixlar som på 1080p** (t.ex. Config 1109×752, GoblinRecorder 1188×774 – `geometri.txt`): inget fönster väljer storlek efter skärmen. På 1440p täcker Config ca 30 % av skärmen mot ca 40 % på 1080p, med lika stor text i px.
- **Sett på bild:** GoblinRecorder maximerad på 1440p – filmsidan skalas inte upp (bara inställningarna gör det), listan till vänster är kvar i ca 270 px med mycket liten text och videon tar resten.
- **Bilder att inte lita på:** `goblin-graph-1440-start` är 1920×1080 i stället för 720×220 – graph sparar sin storlek i `graph.json`, och provet "max" på 1080p sparades i kopian (provmiljöns fel, inte programmets). `goblinamp-1440-start` ligger delvis utanför skärmen (x 2286 + 380 > 2560) eftersom platsen kommer ur användarens sparade läge på två skärmar (3840 px bred) – men det visar att GoblinAmp inte kollar att en sparad plats ryms på skärmen (bara läst/sett i provet, inte kontrollerat i koden).

### Inte tagna, och varför
- **Levande för GoblinAmp, goblin graph och röstrutan:** de har ingen `G.Backdrop`/`G.Light`, så Levande ändrar inget.
- **Toppfältet och dockan:** de är Plasma-paneler och finns bara i användarens riktiga Plasma. Användaren kör upplägget Dashboard (ingen docka/toppfält), och skrivbordsraden göms när ett fönster ligger där. En bild av riktiga skärmen visade bara spelet (raderad). Plasma kan inte startas i provmiljön utan att riskera användarens paneler (`plasmashell` skriver i panelfilerna). Skrivbordsraden: användarens egen bild (se 3.3). Toppfält + docka: bara om upplägget byts tillbaka (inte nödvändigt enligt Claude, användaren bestämmer).
- **GoblinAmp maximerat/halv/minsta:** fast storlek.
- **Dashboard i andra storlekar:** alltid helskärm.
- **Låsskärm/utloggning i Levande:** de följer inte `utseende`.
