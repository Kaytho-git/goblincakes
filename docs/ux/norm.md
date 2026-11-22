# UI-normen för GOBLINCAKES egna fönster

Steg B i UX-optimeringen (`docs/optimering/startinstruktion.md` del 3), skriven 22 nov av Opus utifrån `docs/ux/inventering.md` och bilderna i `~/.local/share/goblincakes/ux-bilder/`. **Förebilden är Config**: normen tar Configs mått och rättar det Config gör fel när fönstret ändrar storlek. Avvikelserna per fönster står i `docs/ux/granskning.md`.

Alla mått nedan är **enheter** (layoutens egna px före zoom). Ett fönster ritar enheterna × `zoom` (avsnitt 2). Färger och typsnitt följer designkällan (CLAUDE.md, "Design"); accentregeln gäller som förut.

## 1. Grundregeln för storleksändring (orsaken till A–C)

Problemen A–C har **samma rot**. Sett både på bild och i koden:

- Allt innehåll förankras `left: parent.left; right: parent.right`, alltså *fyll bredden*, och inget fönster har en största bredd (inventering 3.1–3.9). Det är **B**: på 1 920 eller 2 560 px blir raderna 1 800–2 500 px långa.
- Rubrikraderna är två grupper som förankras var för sig, en `anchors.left` och en `anchors.right`, och inget hindrar dem från att mötas (`config/Main.qml:459` och `:522`, `share/Main.qml:455` och `:490`, `recorder/Main.qml:841` och `:905`). Under en viss bredd ritas de ovanpå varandra. Det är **A** (krock). Flikraderna är en `Row` utan rullning, så de klipps vid fönsterkanten (`config/Main.qml:531`). Det är **A** (klipps).
- Minsta storleken är en fast siffra (`minimumWidth: 760 * startZoom` …), inte räknad ur innehållet. Därför stämmer den inte med det som faktiskt behöver få plats.
- Det som borde stå mitt i fönstret står kvar till vänster i en yta som bara blir bredare: Configs terminalkort i 3 × 434 px och tomt till höger, lagmätarens knappar längst till vänster, Avinstalleras knappar längst till höger 1 800 px från innehållet. Det är **C**.

**Regeln:** varje vy består av en **sida** med en *läsbredd*. Sidan är centrerad i fönstret och växer bara upp till sin största bredd.

| Del | Beteende |
|---|---|
| Fönstrets bakgrund, rubrikens och fotens linjer, flikradens linje | fyller hela bredden |
| Rubrikens innehåll (logga, titel, knappar till höger), flikarna, vyns innehåll, fotens knappar | ligger i **sidan**: `width = min(fönstret − 2 × sidmarginal, maxbredd)`, centrerad |
| Mediavyer: video, terminal, grafer, Dashboard | får fylla bredden (de *är* innehållet). Kringtexterna (titel, knappar under videon) följer ändå sidans regel om de är löptext |
| Rutnät av kort | antal kolumner = `floor((sidans bredd + mellanrum) / (kortets minsta bredd + mellanrum))`, **högst 4**. Korten delar sidans bredd lika. Rutnätet centreras om det inte fyller sidan |
| Löptext (förklaringar, Note) | högst **760 enheter** bred (≈ 110 tecken i 13 px), annars bryts den |

**Maxbredd per sorts fönster:**

| Sort | Maxbredd (enheter) | Fönster |
|---|---|---|
| Inställningar/formulär | **1 240** | Config, Avinstallera, GoblinShare, GoblinRecorders INSTÄLLNINGAR, Goblin AI:s INSTÄLLNINGAR |
| Chatt/läsning | ingen: samtalet och inmatningen fyller bredden från vänsterkanten (användaren 22 nov – den centrerade spalten på 960 såg sämre ut) | Goblin AI SVAR/CHATTAR |
| Lista + detalj | listan 300–420 (växer med fönstret, 24 % av bredden), detaljen fyller resten. Detaljens text och knappar följer läsbredden 960 | GoblinRecorder INSPELNINGAR |
| Mätare | graferna fyller bredden upp till 1 240, höjden delas lika på graferna | lagmätaren |
| Helskärm | ingen (egen layout) | Dashboard |
| Fast storlek | – | GoblinAmp, goblin graph, röstrutan |

1 240 enheter = Configs startbredd (1 180 + lite luft). Vid start ser alltså inget annorlunda ut. Skillnaden syns först när fönstret blir större än så.

**Under minsta storlek.** Minsta storleken räknas ur innehållet: rubriken (logga + titel + högergruppen *på egen rad*), flikarna (rullbara, se 4) och foten måste få plats. Inget får krocka eller klippas. I tur och ordning, när det blir trångt:

1. **Bryt om:** rubrikens högergrupp flyttar ner under titeln (komponenten `G.PageHeader`, se 6) och kortrutnät tappar kolumner.
2. **Korta:** undertitlar och kortens beskrivningar får `elide` (som i dag) och full text i en hovringsruta.
3. **Rulla:** vyns innehåll ligger alltid i en Flickable med `FastWheel` och `FlatScrollBar`. Knappar som hör till innehållet (GoblinRecorders "Till YouTube …") ligger **i** det rullbara, aldrig under en fast kant där de kan klippas.
4. **Göm:** bara saker som finns på ett annat ställe också (t.ex. Goblin AI:s tangenttips "/ kommandon · ↑ tidigare" när verktygsraden behöver platsen).
5. **Klipp: aldrig.** En ram ritas hel eller inte alls.

`minimumWidth`/`minimumHeight` sätts så att steg 1–4 räcker, och räknas om möjligt ur `implicitWidth` i stället för att skrivas som en fast siffra.

## 2. Skalningen: en regel för alla fönster

I dag finns fem olika sätt (inventering avsnitt 2). Normen:

```
zoom = bas × skärmfaktor × tillväxt
```

- **bas = 0,94.** Användarens val 5 nov ("94 → 104 % känns bättre", anteckningarna "Textstorleken i våra fönster") gäller fortfarande. 0,94 ≈ dagens `QT_SCALE_FACTOR=0.9` plus lite, och samma som Config och Goblin AI redan har.
- **tillväxt** = 1,00 i startstorlek → **1,10** maximerat, jämnt mellan (Configs `grown`-formel, `config/Main.qml:16–18`). Det ger 0,94 → 1,04 som i dag. GoblinShares 1,6 och GoblinRecorders 1,7 utgår. Maximerat ska ge *lite* större text och en centrerad sida, inte allt 60–70 % större. Det var användarens önskan 22 okt ("inställningarna större i stället för små texter utspridda"), och läsbredden i 1 löser det problemet bättre: texten sprids inte längre ut.
- **skärmfaktor** = `clamp(1 + 0,5 × (skärmens tillgängliga höjd / 1 040 − 1), 1, 1,3)`, alltså 1,0 på 1080p och ≈ 1,17 på 1440p. Den är 1 om Plasma redan skalar (`Screen.devicePixelRatio > 1`) eller om användaren själv satt `QT_SCALE_FACTOR`. Varför: på 1440p ritas samma text i dag med exakt lika många pixlar (inventering 4: "inget fönster väljer storlek efter skärmen"), alltså ca 25 % mindre till synes än på användarens 27-tums 1080p. Med 1,17 blir det ca 12 % mindre i stället, och fönstrets startstorlek följer med (Config ≈ 1 300 × 880 px, ca 50 % av en 1440p-skärm mot 58 % på 1080p). **Värdet 0,5 är en gissning.** Det kan inte bedömas utan en riktig 1440p-skärm (avsnitt 8), så det ska vara *ett* tal i `goblinapp.py` som är lätt att ändra.
- **Hur:** som Config gör (`fitZoom`, skalar `win.contentItem`). Det kräver att inga barn läser `win.width`/`win.height` direkt. GoblinShare har sin egen `stage` med `win.width / win.zoom` (`share/Main.qml:442–443`) och GoblinRecorder läser `win.width/height` i hovringsrutan (`recorder/Main.qml:3845–3846`) – båda byts (granskning). Goblin AI behåller sin `zoomRoot`, eftersom Chromium i TERMINAL inte klarar `QT_SCALE_FACTOR < 1` (anteckningarna, "Skalan (1 nov, flera varv)"). Formeln blir ändå densamma, och `uiScale` 0,8 räknas om som i dag. Inget fönster sätter `QT_SCALE_FACTOR` längre. **Undantag:** röstrutan (layer shell, ändrar aldrig storlek) får `zoom = bas × skärmfaktor` som fast skala, och GoblinAmp och goblin graph behåller 100 % (egen Winamp-stil och fast pixelgrafik). De får bara skärmfaktorn.
- **Var:** `share/goblincakes/goblinapp.py` (P17) räknar ut `bas`, `skärmfaktor` och `uiScale` och lägger dem som context-egenskapen `ui` (`ui.base`, `ui.screen`). QML-delen `G.Zoom` (se 6) räknar `tillväxt` och sätter `contentItem.scale`. Ett fönster får alltså en rad i stället för åtta.

**Startstorlek:** i enheter per fönster (tabell 7) × `bas × skärmfaktor`, men aldrig mer än **85 %** av skärmens tillgängliga yta. Den blir därmed större på 1440p av sig själv. Placeringen i mitten av skärmen sköts av KWin-skriptet som förut.

## 3. Text

Sex storlekar i stället för dagens 10–12 (Goblin AI har 12 olika). Alla i enheter:

| Namn | Storlek | Typsnitt | Används till |
|---|---|---|---|
| `meta` | 11 | IBM Plex Mono / Sans | tider, versionsrad, tangenttips, märken (FÖRLUST 10–13) |
| `small` | 13 | IBM Plex Sans | beskrivningar, undertexter i kort, Note, tabellceller |
| `body` | 15 | IBM Plex Sans | brödtext, knappar, fält, listrader, sidans undertitel |
| `label` | 13, `letterSpacing` 2,5, versaler | Chakra Petch DemiBold | SectionTitle, ramrubriker (TERMINAL, PROJEKT) |
| `tab` | 15, `letterSpacing` 2,5, versaler | Chakra Petch DemiBold | flikar |
| `title` | 30, `letterSpacing` 4, versaler | Chakra Petch Bold | sidans rubrik (VÄLJ DINA PROGRAM, GOBLINRECORDER) |

Plus `display` (22–34) för stora siffror/klockor i Dashboard och GoblinRecorders statistik. 12, 14 och 16 utgår: 12 → 13, 14 → 13 eller 15 efter vad det är, 16 → 15. Undantag är GoblinAmp (egen stil, 9–11 är en del av utseendet), goblin graph och skrivbordsraden (mått ur mockupen).

Minsta läsbara storlek på skärmen: **11 enheter × zoom ≥ 10 px**. GoblinRecorders 9 och Goblin AI:s 10 uppfyller inte det.

Textfärger: `#E6ECF5` (text), `#8B98AD` (sekundär), accent enligt regeln. Sekundär text på genomskinlig yta (skrivbordsraden, Levande) får `#A9B4C6` eller en mörkare platta bakom, för kontrastens skull (granskning, skrivbordsraden).

## 4. Avstånd, höjder, ramar

**Raster 4:** mellanrum 4, 8, 12, 16, 24, 32, 48. Inget 6, 10, 14, 20, 22 eller 26 i nya delar.

| Sak | Mått |
|---|---|
| Sidmarginal (vänster/höger om sidan) | **48** i fönster ≥ 900 enheter breda, **24** under det (lagmätaren, halv skärm på 1080p med Goblin AI:s sidospalt). GoblinRecorder och GoblinShare har 40 och byter till 48 |
| Rubriken | logga 64, titel `title`, undertitel `body` sekundär, 32 överst; högergruppen i linje med titelns överkant |
| Flikraden | höjd 44, mellanrum 24 (Config har 22), klickytan och markeringen = bara ordet, inte mellanrummet (användaren 22 nov) |
| Avstånd mellan block i en vy | 32 (avsnitt), 12 (rader/kort i en lista) |
| Knapp | **44** normal (minst 150 bred, padding 48, `body`), **32** kompakt för verktygsrader och rubrikens högergrupp (minst 96, padding 24, `small`), **28** liten (som i dag). GoblinRecorder/GoblinShare 34 → 32 |
| Fält | 44 (32 i kompakta rader) |
| Listrad | minst 44; med två textrader 64 |
| Kort | minsta bredd 300, padding 16, ikon/monogram 44 |
| Kryssruta/brytare | 22 / 44 × 24, klickyta minst 32 × 32 |
| Ram | 1 px `#1E2A40` (avdelare), 1 px `#2A3852` (knappar/fält), fyllning `#0E1420`. Raka hörn. Vald = 1 px accent |
| Fot | höjd 84, knapparna i **sidans** högerkant (inte fönstrets) |

## 5. Känsla

- **Hover** på allt klickbart, även flikar och listrader: textfärg → `#E6ECF5` eller ramfärg → accent, 120 ms. Pekande hand (`Qt.PointingHandCursor`).
- **Klick:** knappar mörknar när de trycks (FlatButton gör det redan). Hela raden/kortet är klickytan, inte bara texten (gäller Configs kort, Avinstalleras kort och listorna i Goblin AI:s vänsterspalt).
- **Rörelse:** bara i Levande (`look.motion`). Glide/FadeText/Rise som i dag, högst 200 ms, inget som studsar. Platt = inga animationer utom hover.
- **Öppna/stäng:** fönstret visas först när det är färdigritat (inget som hoppar i storlek efter visning, se `Qt.callLater(fitZoom)`). Esc stänger dialogrutor och tomma lägen, aldrig hela fönstret (utom röstrutan och Dashboard).
- **Tomma lägen:** centrerade i vyns sida (inte i hela fönstret), rubrik `body` + förklaring `small`, högst 560 bred.
- **Fönstertitel:** bara programmets namn, t.ex. "Avinstallera program". KDE lägger själv till programmets namn efter en "—" (sett: "Avinstallera program – GOBLINCAKES — Avinstallera program").

## 6. Gemensamma komponenter i qml/Goblin (nya)

Nya komponenter i samma anda som `G.FlatButton`: ett fönster använder dem och ändrar bara mått där det behövs.

| Komponent | Gör | Ersätter |
|---|---|---|
| `G.Zoom { win: win; startW; startH }` | räknar `tillväxt`, sätter `contentItem.scale/width/height` (Configs `fitZoom`), exponerar `zoom` | `fitZoom` i Config, `zoom` i GoblinShare/GoblinRecorder, `QT_SCALE_FACTOR` i fyra fönster |
| `G.Page { maxWidth: 1240 }` | en centrerad yta med sidmarginal och maxbredd, `contentItem`-barn läggs i den | `anchors { left; right; leftMargin: 48 … }` i varje vy |
| `G.PageHeader { logo; title; subtitle; right: [ … ] }` | logga + titel + undertitel till vänster och högergruppen till höger. **Bryter om**: när det inte får plats på en rad hamnar högergruppen under titeln. `implicitWidth` = det minsta som behövs | rubrikerna i Config, Avinstallera, GoblinShare, GoblinRecorder |
| `G.TabBar { model; current }` | flikarna enligt 4, rullar i sidled när de inte får plats (pilar/tona ut i kanten, hjulet rullar), bara ordet klickbart | flikraderna i alla fem (även Goblin AI:s) |
| `G.Footer { left; right }` | fotlinje över hela bredden, knappar i sidans kanter | fötterna i Config och Avinstallera |
| `G.Card` | kort med ram, hover, vald-läge och klick på hela kortet, ikon/monogram, titel, beskrivning med elide och hovringsruta | Configs och Avinstalleras kort, `CardSwitch` |
| `G.CardGrid { minCardWidth: 300; maxColumns: 4 }` | kolumnregeln i 1 | `floor((w+16)/340)` på tre ställen |
| `G.Type` (singleton) | storlekarna i 3 som namn: `G.Type.body` … | siffror i 1 000+ `font.pixelSize` |

Startkoden i Python (P17): `share/goblincakes/goblinapp.py` med `start(namn, ikon, qml)` som gör skalan (2: `ui.base`, `ui.screen`, `uiScale` för Goblin AI), typsnitten, `cached_qml`, `use_accent`, säsongsloggan och fönsterikonen, plus `sharp_text_dialogs()`. **Ett fönster i taget** (QLocalServer) stannar i varje fönster (användarens regel; bara hjälparen delas). GoblinAmps fildialoger får `onVisibleChanged: backend.sharpText()` i samma veva (`amp/Main.qml:2173–2195`).

## 7. Startstorlek och minsta storlek per fönster (enheter)

| Fönster | Start | Minst | På 1080p (×0,94) | På 1440p (×0,94×1,17) |
|---|---|---|---|---|
| Config | 1 180 × 800 | 760 × 560 | 1 109 × 752 | ≈ 1 298 × 880 |
| Avinstallera | 1 180 × 800 | 760 × 560 | 1 109 × 752 | ≈ 1 298 × 880 |
| GoblinShare | 1 080 × 720 | 760 × 540 | 1 015 × 677 | ≈ 1 188 × 792 |
| GoblinRecorder | 1 320 × 860 | 980 × 620 | 1 241 × 808 | ≈ 1 452 × 946 |
| Goblin AI | maximerad (avmaximerad 1 320 × 860) | 1 000 × 600 | (1 241 × 808) | (≈ 1 452 × 946) |
| Lagmätaren | 470 × 690 | 380 × 520 | 442 × 649 | ≈ 517 × 759 |
| Röstrutan | 420 × innehåll | – | 395 | ≈ 462 |
| GoblinAmp, goblin graph | som i dag (100 %, bara skärmfaktor) | | | |

Minsta storlekarna gäller **efter** att rubrik och flikar fått bryta om eller rulla (1). Är minsta storleken fortfarande för liten för innehållet, ska den höjas, inte klippa innehållet.

## 8. Kan inte bedömas utan en riktig 1440p-skärm

1440p-bilderna kommer från en virtuell skärm. Pixlarna stämmer, men inte den fysiska storleken.

- Hur stor texten **känns** på 27 tum/109 ppi, och därmed om skärmfaktorns 0,5 (→ 1,17) är rätt eller om 1,25–1,33 behövs.
- Om 11 enheter (`meta`) är läsbart på 109 ppi.
- Om startstorleken ≈ 50 % av skärmen känns rätt, eller för liten eller stor.
- Hur skarp texten blir med zoom på 1,17–1,22 (icke-heltal). Skärpan med 0,9 är provad på riktigt, men inte de nya värdena.
- Ultrawide (3 440 × 1 440): maxbredden bör ge en lugn centrerad sida, men det är bara räknat, inte sett.
- Plasma-skalning 125 % eller 150 % (vanligt på 1440p/4K): skärmfaktorn ska då bli 1. Det är bara läst i koden, inte provat.
