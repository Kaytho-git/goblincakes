# UX-granskningen (steg B) – avvikelser och förslag

**Steg C (22 nov, Opus):** BYGGT #1, #2, #3, #4, #5 (+ #9 titeln, #17 GoblinAmps sharpText, #24 röstrutan, Dashboards skala ur #12) – testlistor ux-rubrik-flikar, ux-goblin-ai, ux-skalan; bilder efter i `~/.local/share/goblincakes/ux-bilder/efter/`. Kvar att välja bland: #6–8, #10–16, #18–23 och resten av #12.

**Läget (steg B):** klart 22 nov (Opus, inte Fable). Normen finns i `docs/ux/norm.md`. Alla fönster är genomgångna, inget kvar. **Nästa:** steg C. Användaren väljer punkter i avsnitt 3 och Opus bygger dem en eller några per session (`docs/optimering/startinstruktion.md` del 3, steg C).

Underlaget: `docs/ux/inventering.md` och bilderna i `~/.local/share/goblincakes/ux-bilder/`. Sökvägar är relativa till `files/system/usr/share/goblincakes/` om inget annat står, och rader gäller commit 8706f94a. **Sett** = sett på bild i den här granskningen. **Läst** = bara läst i koden; det ska bekräftas innan något byggs.

## 1. Problemen A–C: orsaken

Misstanken stämmer: **A–C har samma rot**. Det finns ingen gemensam regel för hur innehållet beter sig när storleken ändras (norm 1). Konkret:

| | Orsak i koden | Fönster (sett) |
|---|---|---|
| **A** krock | Rubriken = två grupper, en förankrad till vänster och en till höger, utan något som håller dem isär: `config/Main.qml:459`/`:522`, `share/Main.qml:455`/`:490`, `recorder/Main.qml:841`/`:905`. Goblin AI: flikraden `ai/Main.qml:1896` och "+ Ny chatt" `:1986` (bara "svarar nu" göms när det är trångt, `:1991`), verktygsraden `:4025` och tipsen `:4073–4084`. | Config min (versionsraden över titeln), GoblinShare min (knapparna över GOBLINSHARE), GoblinRecorder min (knappen över GOBLINRECORDER), Goblin AI min (Ny chatt över flikarna, tipsen över verktygsraden, förslagsknapparna över "ducks"-raden) |
| **A** klipps | Flikraderna är en `Row` utan rullning (`config/Main.qml:531`, `ai/Main.qml:1896`). Knapparna under videon ligger utanför det rullbara (`recorder/Main.qml` kring `:1973`). Minsta storleken är en fast siffra, inte räknad ur innehållet. | Config min (flikarna slutar på "BA"), Goblin AI min ("TERMINAL"/"INSTÄLLNINGAR" borta), GoblinRecorder min (knappraden "Till YouTube …" klipps nedtill) |
| **B** jättestort | Allt är `anchors { left; right }` utan maxbredd. GoblinShare och GoblinRecorder skalar dessutom upp allt (`share/Main.qml:48`, `recorder/Main.qml:28`) i stället för att begränsa bredden. | Config max (raderna 1 820 px), Avinstallera max (6 kolumner, Stäng/Verkställ 1 800 px från innehållet), GoblinShare max (texten 1,6 gånger så stor och tomt under), Goblin AI max (inmatningen ca 1 500 px), lagmätaren max (graferna 1 900 px breda och lika låga som förut) |
| **C** vid sidan | Innehåll med fast bredd ligger kvar till vänster i en yta som bara växer. Fötterna är förankrade i fönstrets kant, inte innehållets. | Config max (3 terminalkort och tomt till höger), lagmätaren max (knapparna längst till vänster), Avinstallera max (knapparna längst till höger) |

## 2. Avvikelser per fönster

### 2.1 Config (förebilden), klar
- **A:** versionsraden (`:522`) krockar med titeln under ca 900 px (sett, min). Flikarna klipps utan att gå att rulla (sett, min). Användarens egen iakttagelse 13 nov, att "klickytorna ligger till vänster om texten": flikens klickyta är exakt textens bredd (`:542`) utan marginal, så mellanrummet på 22 px mellan flikarna är död yta. Att ytan skulle vara *förskjuten* har inte setts på bild (läst; kan hänga ihop med att `contentItem` skalas, `fitZoom` `:19–24`) – prova med musen före bygge.
- **B/C:** sett, max på 1080p och 1440p. Kategoriraderna, länkfältet och förklaringstexten går över hela bredden. Terminalkorten är 3 × 434 px och vänsterställda.
- **Skala:** följer normen redan (0,94 → 1,04), men utan skärmfaktor: på 1440p är fönstret 1 109 × 752 som på 1080p (sett, `geometri.txt`).
- **Egna kopior:** `ResultMark` `:388`, `CardSwitch` `:1151` (→ `G.Card`), `Stepper` `:1657`, `SmallButton` `:1836` (→ `G.FlatButton { small: true }`, läst).
- **Text:** 8 storlekar (11–16, 22, 30). 13 och 14 blandas för samma sorts text.
- **Känsla:** bra. Hover på flikar och kort.

### 2.2 Avinstallera program, klar
- **Bra:** minsta storleken fungerar bäst av alla. Två kolumner, rullar, ingenting klipps (sett, min).
- **B/C:** sett, max. 6 kolumner, Stäng/Verkställ längst ut till höger.
- **Titel:** `remove/Main.qml:17` "Avinstallera program – GOBLINCAKES" + KDE:s " — Avinstallera program" = namnet två gånger (sett).
- **Skala:** `QT_SCALE_FACTOR=0.9` (0,9 mot Configs 0,94; samma mått men ca 4 % mindre). Ingen tillväxt när fönstret maximeras.
- **Egna kopior:** `AppIcon` `:86`. Rubrik och fot är kopior av Configs.

### 2.3 GoblinShare, klar
- **A:** sett, min. "Be om hjälp"/"Leta igen" ritas över GOBLINSHARE.
- **B:** sett, max. Allt 1,6 gånger så stort (`share/Main.qml:48`, `stage` `:439–445`), tomt-läget går över hela bredden och resten av fönstret är tomt. Normen tar bort uppskalningen och lägger tomt-läget centrerat, högst 560 bred.
- **Mått:** sidmarginal 40 (Config 48), knappar 34 (Config 44/32).
- **Skala:** två steg (0,9 + egen). Ska bli `G.Zoom`.

### 2.4 GoblinRecorder, klar
- **A:** sett, min. Rubrikens högergrupp (statusrad + tre kontroller) går in i GOBLINRECORDER, och knappraden under videon klipps.
- **Halv skärm (952 px):** fungerar. Rubriken får precis plats (sett).
- **Max 1080p:** videon fyller ytan, och det är rätt för en mediavy (sett). Listan är kvar i ca 345 px.
- **Max 1440p:** sett. Listan ca 270 px med text runt 9–10 px, rubrikens knappar och statusrad mycket små, videon tar resten. Delar av fönstret skalas upp (`zoom` `:28`, inställningarna `:1068`, panelen `:1051`, `:3261`), men inte inspelningssidan.
- **Text:** 9 px förekommer (`pixelSize: 9`/`10`: 12 ställen i recorder + ai tillsammans, läst). Under normens minsta.
- **Egna kopior:** `SettingRow` `:418`, `HoverTip` `:693`, `PanelSwitch` `:699`, `StatusChip` `:723`, `Choice` `:800` m.fl. Många är rimliga (bara GoblinRecorder har dem). `HoverTip` finns också i Goblin AI (`HoverHint` `ai/Main.qml:61`), en kandidat för qml/Goblin.

### 2.5 Goblin AI, klar
- **A:** sett, min (784 × 480). Flikarna försvinner bakom "+ Ny chatt", tangenttipsen "/ kommandon · ↑ tidigare" ritas över verktygsraden, och förslagsknapparna ritas över "ducks"-raden (välkomstvyn rullar inte). Minsta storleken (980 × 600 × 0,8, `:14–15`) är för liten för sidospalten på 330 och flikarna.
- **B:** sett, max. Samtalet och inmatningen går över hela den stora rutan (ca 1 500 px). Välkomsttexten är centrerad (bra) men står ensam i en jättestor yta. Normen: samtalet och inmatningen högst 960, centrerade.
- **Skala:** följer redan normens formel via `zoomRoot` (`:1211–1225`). Skärmfaktorn saknas.
- **Text:** 12 olika storlekar (10–28). 10 px under normens minsta.
- **Egna kopior:** 14 egna komponenter (inventering 3.2). `Panel`/`GroupLabel`/`PanelRow` motsvarar `G.Frame` + `G.SectionTitle` (läst, inte jämfört i detalj).
- **Känsla:** bra; Levande-rörelserna fungerar (sett, normal-levande).

### 2.6 Lagmätaren, klar
- **Start:** bra (sett). Liten och tydlig.
- **B/C:** sett, max. Graferna 1 900 px breda men lika låga som förut, knapparna längst till vänster, tomt under. Normen: graferna delar höjden, högst 1 240 bred, centrerat.
- **Mått:** marginal 16 (normen 24 i smala fönster), knappar 40. Rubriken saknar loggan (en liten verktygsruta, rimligt – normen tillåter rubrik utan logga i fönster under 600 enheter).
- **Skala:** `QT_SCALE_FACTOR=0.9`.

### 2.7 Dashboard och skrivbordsraden, klar
- **Dashboard 1080p:** sett. Fungerar som helskärm. I högerspalten finns ett stort tomt glapp mellan CS2 STATS och GOBLINRECORDER (ramarna förankras uppåt respektive nedåt).
- **Dashboard 1440p:** sett. Allt ritas med samma pixlar som på 1080p (0,9), så sidospalterna blir smala med liten text och mitten får mycket tom yta. Skärmfaktorn (norm 2) gör mest nytta just här.
- **Skrivbordsraden:** sett (användarens bild). Svag kontrast för den små grå texten på genomskinlig grå yta över ljus bakgrund. Klockrutan är högre än Discord-/Spelas nu-rutorna, så nederkanterna ligger inte i linje. Discord-rutans text är högerställd och Spelas nu vänsterställd.

### 2.8 GoblinAmp, goblin graph, röstrutan, klar
- **GoblinAmp:** fast 380 px med egen stil, utanför normen med flit. Fildialogerna saknar `sharpText` (`amp/Main.qml:2173–2195`, läst). En sparad plats som inte ryms på skärmen flyttas inte tillbaka (sett i provmiljön på 1440p; koden inte läst).
- **goblin graph:** inget att anmärka (sett).
- **Röstrutan:** 0,9 fast. Ska få `bas × skärmfaktor`. Inget fel sett.

### 2.9 Låsskärm och utloggning, klar
- Bilderna kommer från den installerade versionen med Plasmas standardbakgrund (inventering 3.12). Inget fel sett. De följer inte normens skala (Plasma-skal, inte våra fönster) och ingår inte i förslagen.

## 3. Förslagen (mest värt först)

Storlek: liten = < 1 timme, medel = en session, stor = flera sessioner. "Opus?" = kan Opus bygga den direkt utifrån normen.

| # | Vad (var) | Vinst | Risk | Storlek | Sett/läst | Opus? |
|---|---|---|---|---|---|---|
| 1 | **`G.PageHeader`** som bryter om (norm 6), in i Config `:432–576`, GoblinShare `:449–520`, GoblinRecorder `:835–960`, Avinstallera `remove/Main.qml:113` | inget krockar i rubriken när fönstret är smalt (A) | låg | medel | sett | ja |
| 2 | **`G.TabBar`**: rullar i sidled, hela fliken klickbar inkl. mellanrum, in i Config `:531`, Goblin AI `:1893`, GoblinShare, GoblinRecorder, Avinstallera | flikarna klipps aldrig; lättare att träffa (användarens iakttagelse 13 nov) | låg | medel | sett (klippning), läst (klickyta) | ja |
| 3 | **`G.Page`** (maxbredd 1 240, centrerad) + `G.Footer` i Config, Avinstallera, GoblinShare | maximerat blir en lugn kolumn mitt på skärmen i stället för 1 800 px långa rader (B, C) | låg | medel | sett | ja |
| 4 | **Goblin AI:** samtal + inmatning högst 960 centrerade; tipsen göms när verktygsraden behöver platsen; välkomstvyn i en Flickable; minsta storlek 1 000 × 600 enheter | chatten läsbar maximerat; inget överlappar i litet fönster | låg | liten–medel | sett | ja |
| 5 | **Gemensam skala:** `goblinapp.py` (P17) + `G.Zoom` med skärmfaktorn; `QT_SCALE_FACTOR` bort i fyra fönster; GoblinShares 1,6 och GoblinRecorders 1,7 bort | samma textstorlek i alla fönster; 1440p blir inte 25 % mindre; ett ställe att justera | medel (rör alla fönster; fel = inget fönster startar) | stor | sett (skillnaderna), läst (koden) | Fable bygger, eller Opus ett fönster i taget och Fable granskar |
| 6 | **GoblinRecorder:** knappraden under videon in i det rullbara | knapparna klipps inte i litet fönster | låg | liten | sett | ja |
| 7 | **GoblinRecorder:** listan 24 % av bredden (300–420), minsta text 11; rubrikens högergrupp kompakt 32 | listan läsbar maximerat på 1440p | låg | liten | sett | ja |
| 8 | **`G.CardGrid`** (högst 4 kolumner, korten delar bredden, centrerat) i Config (terminal + kategorier) och Avinstallera | inga 6 smala kolumner; terminalkorten fyller raden | låg | liten | sett | ja |
| 9 | **Avinstallera:** titeln bara "Avinstallera program" (`remove/Main.qml:17`) | ingen dubbel titel i namnlisten | ingen | liten | sett | ja |
| 10 | **Lagmätaren:** graferna delar höjden, högst 1 240, centrerat; marginal 24; knapparna till höger i en fot | maximerat blir användbart, inte tomt | låg | liten | sett | ja |
| 11 | **GoblinShare:** tomt-läget centrerat, högst 560 | maximerat ser avsiktligt ut | låg | liten | sett | ja |
| 12 | **Dashboard:** skärmfaktorn (följer av 5) och högerspaltens glapp – ramarna staplas uppifrån och SPELAS NU nederst | 1440p utnyttjas; ingen tom ruta mitt i spalten | låg | liten–medel | sett | ja |
| 13 | **Skrivbordsraden:** ljusare sekundärtext (`#A9B4C6`) eller mörkare platta, rutorna lika höga med nederkanterna i linje, all text vänsterställd | läsbar över ljus bakgrund, lugnare rad | låg | liten | sett | ja (efter prov på riktiga skrivbordet) |
| 14 | **`G.Type`**: typskalan (6 storlekar), fönster för fönster: 12 → 13, 14 → 13/15, 16 → 15, 9/10 → 11 | samma text betyder samma sak överallt | låg per fönster | medel (Goblin AI stor) | läst | ja, ett fönster i taget |
| 15 | **`G.Card`** (kort med hela ytan klickbar, hover, elide + hovringsruta) ersätter `CardSwitch` och Avinstalleras kort | samma kort överallt; full text på hover | låg | medel | läst (klickytan inte provad) | ja |
| 16 | **Minsta storlek ur innehållet** (`implicitWidth` från PageHeader/TabBar/Footer) i stället för fasta siffror | min-storleken stämmer alltid, även när en flik läggs till | låg | liten (efter 1–2) | läst | ja |
| 17 | **GoblinAmp:** `sharpText` i fildialogerna (`amp/Main.qml:2173–2195`) | skarp text efter dialogen som i andra fönster | ingen | liten | läst | ja (ingår i P17) |
| 18 | **GoblinAmp:** sparad plats utanför skärmen → flytta in | fönstret hamnar aldrig halvt utanför efter skärmbyte | låg | liten | sett i provmiljö, kod inte läst | ja, läs koden först |
| 19 | **Sidmarginaler och knapphöjder** enligt rastret: 40 → 48 (GoblinShare, GoblinRecorder), 34 → 32, 16 → 24 (lagmätaren) | fönstren känns som ett system | låg | liten | läst/sett | ja |
| 20 | **`HoverTip`** (GoblinRecorder `:693`) och `HoverHint` (Goblin AI `:61`) → en `G.HoverTip` | en sorts hovringsruta | låg | liten | läst | ja |
| 21 | **Config:** `SmallButton` `:1836` → `G.FlatButton { small: true }` | en knapp mindre att underhålla | låg | liten | läst | ja |
| 22 | **Goblin AI:** `Panel`/`GroupLabel` jämförs med `G.Frame`/`G.SectionTitle` och slås ihop om de är lika | samma ramar som Dashboard | låg | medel | läst, inte jämfört | ja, jämför först |
| 23 | **Tomma lägen** centrerade i sidan (norm 5) i alla fönster | lugnare vyer | låg | liten | sett (GoblinShare) | ja |
| 24 | **Röstrutan** `bas × skärmfaktor` i stället för 0,9 (följer av 5) | rätt storlek på 1440p | låg | liten | läst | ja |

## 4. Topp 5

1. **`G.PageHeader`** (#1): tar bort de flesta krockarna (A) i fyra fönster med en komponent.
2. **`G.TabBar`** (#2): flikar som aldrig klipps, och användarens klickyteproblem.
3. **`G.Page` + `G.Footer`** (#3): maximerade fönster blir en centrerad kolumn (B, C).
4. **Goblin AI läsbredd och trånga lägen** (#4): det fönster användaren har uppe mest.
5. **Gemensam skala med skärmfaktor** (#5): grunden för 1440p och för att fönstren ska ha samma storlek. Den största punkten, så den görs sist av de fem eller av Fable.

Före/efter-skisserna för de fem: artifact **"UX topp 5"**, https://claude.ai/artifact/QuDtpBUe3V5i4D9Jf5h5CU

**Ordning för steg C:** 1 → 2 → 3 (de bygger på varandra och ger mest för minst), sedan 4, 6, 8–11 (små, fristående) och sist 5 med 12, 14 och 24.
