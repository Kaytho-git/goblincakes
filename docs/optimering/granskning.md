# Optimeringsgranskning av GOBLINCAKES

Gjord av Fable 11 nov 2026 enligt `docs/optimering/startinstruktion.md` del 1. Ingen kod är ändrad – bara läst och mätt.

## Läget (för en ny session som fortsätter)
- [x] Område 1 – Prestanda i bakgrunden (punkt 1–8)
- [x] Område 2 – Uppstart och inloggning (punkt 9–11)
- [x] Område 3 – Image och bygge (punkt 12–14)
- [x] Område 4 – Kodkvalitet och underhåll (punkt 15–19)
- [x] Område 5 – Fel och risker (punkt 20–24)
- [x] Mätningar på frugans laptop i vila (11 nov, via GoblinShare)
- [x] Mätningar under spel på användarens dator (11 nov 18:28, WoW utan strid); laptopen har inget spel än
- [x] Sortering + topp 5 (står före Mätningar)
- [x] Byggt: P20, P22, P24 (11 nov, Fable – ej pushat; provas av första bygget + testlistan `fedora-las-rost.md`)
- [x] Byggt: P1 (11 nov, Opus) – testkopia provad i Plasma; Discord-hjälparens del först efter nästa image; testlista `p1-widgetar.md`
- [x] Byggt: P2 + P3 (11 nov, Opus) – repots tjänst och fönster körda på riktigt (i vila, utan spel); testlista `p2-p3-recorder.md`
- [x] Byggt: P4 (11 nov, Opus) – repots vakt körs på riktigt (i vila, utan spel); testlista `p4-graph.md`

Punkterna har fasta nummer (P1, P2 …) i den ordning de hittades, så att "Bygg punkt P3" alltid betyder samma sak. Den sorterade listan (mest värt först) och topp 5 står efter område 5, före Mätningar. När en punkt är byggd: bocka av den i den sorterade listan och för in "efter"-värdet under rätt M-nummer.

**Datorerna:** användarens dator = 16 trådar, 32 GB, RTX (12 GB), `goblincakes-nvidia`, Fedora 44. Frugans laptop = Legion Y520, i7-7700HQ (4 kärnor/8 trådar, ungefär hälften så snabb per kärna), 16 GB, GTX 1050 Ti (4 GB), `goblincakes-nvidia-legacy`, Fedora 45. Procenttal nedan är **% av en kärna** på användarens dator om inget annat står; laptopens egna värden (mätta 11 nov i vila) står vid punkterna och i Mätningar – samma arbete kostar där ungefär 1,3–2 gånger så mycket.

---

## Område 1 – Prestanda i bakgrunden

Mätt på användarens dator 11 nov, 15 min efter inloggning, inget spel igång, upplägget Dashboard (M2 = CPU per tjänst under 60 s, M3 = minne). Det som GOBLINCAKES egna bakgrundsdelar drar i vila, helt utan att göra något nyttigt:

| Del | CPU i vila (M2) | Orsak |
|---|---|---|
| Widgetarnas skript (i plasmashell) | 7,4 % | startar små program varje sekund |
| GoblinRecorder-tjänsten | 2,1 % | `pgrep` ungefär en gång i sekunden |
| GoblinRecorder-fönstret (i systemfältet) | 1,4 % | `flatpak info` varje sekund |
| Lokal AI-vakten | 1,2 % | letar spel varje sekund |
| goblin graph-vakten | 1,15 % | `pw-dump` varannan sekund |
| Spelvakten | 0,8 % | letar spel var tredje sekund |
| **Summa** | **ca 14 %** | |

**På laptopen** (mätt i vila, upplägget Standard, utan recorder/graph/röst): widgetarnas skript 6,1–6,6 %, lokal AI-vakten 1,7 %, spelvakten 0,9 %, Archon-ikonen 0,4 % (fast Archon inte finns där) – tillsammans ca 9 % av en kärna.

Allt detta fortsätter medan ett spel kör (utom lokal AI, som stängs av). Det är ingen katastrof – en tiondels kärna av laptopens fyra – men det är onödigt, det väcker processorn 5–16 gånger i sekunden (M4) och det drar batteri.

**Medan WoW kör** (användarens dator, mätt 11 nov – M2) blir det inte mindre utan mer: widgetarnas skript 8,8 % (Discord-fönstret är öppet, så röstkollen går varje sekund), graph-vakten 2,2 %, recorder-fönstret 1,7 %, recorder-tjänsten 1,4 %, lokal AI-vakten 1,3 % (fast AI:n är avstängd under spel – vakten letar vidare varje sekund), spelvakten 1,0 % – tillsammans ca 17 % av en kärna, medan WoW själv använder 2,7 kärnor.

### P1 – Widgetarna startar skript varje sekund
- **Vad:** Toppfältets/skrivbordsradens widgetar hämtar sina uppgifter genom att starta program med jämna mellanrum. Spelas nu: Goblin AI-läget varje sekund, Discord-röst var 1–3 s, Steam var 5 s, batteri var 30 s, utseendet var 5 s (`plasmoids/org.goblincakes.nowplaying/contents/ui/main.qml:288`, `:297`, `:306`, `:315`, `:350`). Klockan: volym varannan sekund, nätverk var 10 s, batteri var 30 s, utseendet var 5 s (`org.goblincakes.deskclock/contents/ui/main.qml:132`–`:160`). Dockan, kvoten, uppdateringspilen och Meta-tipset läser utseendet var 5:e s var för sig (`dock/…/main.qml:69`, `quota/…/main.qml:138`, `updates/…/main.qml:103` + `:176`, `metahint/…/main.qml:40`). I upplägget Dashboard finns Spelas nu **två gånger** (vänster och höger del) och båda kör alla hämtningar, även dem som bara den andra delen visar. Inget saktar ner när ett spel kör, fast widgetarna redan vet om det (`gaming`).
- **Förslag:** (a) starta inte Python när det inte finns något att läsa – ett litet skalvillkor först (AI-mappen tom → `{}`, Discord inte igång → färdigt svar); (b) varje del kör bara sina egna hämtningar (`part` = left/right); (c) under spel 3–5 gånger glesare; (d) batteriet hämtas av en widget, inte två.
- **Vinst:** ca 6–7 % av en kärna → uppskattat 1–2 %, på båda datorerna. Färre uppvaknanden (bättre batteritid på laptopen), lugnare under spel.
- **Säkerhet:** sett/mätt på båda datorerna – användarens: `plasma-plasmashell.service` 7,6 % i vila varav plasmashell själv 0,2 %; laptopen: 6,6 % varav 0,4 % (M2 + M5). Ett varv kostar (användarens dator / laptopen): AI-läget 19 / 26 ms, Discord-röst 37 / 48 ms, Steam 67 / 18 ms, kvoten 42 / 59 ms, batteri 31 / 1 580 ms (M6).
- **Risk:** låg. Det som kan gå fel: en ruta (Discord-kanalen, Kakans "tänker") dyker upp någon sekund senare, eller inte alls om villkoret skrivs fel.
- **Storlek:** liten för (a)–(c), en widget i taget.
- **Kan provas:** bara på riktiga datorn (Plasma-widgetar); själva kommandona kan provas i ett skal.
- **Mät efteråt:** M2 (raden `plasma-plasmashell.service`) och M4.
- **Byggt 11 nov (Opus):** (a) Kakan-läsningen startar Python bara när mappen `goblincakes-ai/` har en fil (skalets glob, 1 ms); Steam via `~/.steam/steam.pid` i stället för `pgrep` (pgrep bara utan pid-fil, t.ex. Flatpak). (b) Skrivbordsradens delar läser bara sitt: vänster Steam + Discord, höger Kakan, inga batterier (klockrutan har dem). (c) Under spel 3 gånger glesare: Discord, Steam, batteri, och i klockan volym/nätverk/batteri (klockan läser nu också `goblincakes-gaming`); Kakan varannan sekund. Discord var 10:e s när den inte är igång. Därtill `goblincakes-discord-voice`: moduler som bara behövs ibland läses in först när de behövs, och Discords pid sparas (`~/.cache/goblincakes/discord-voice.pid`) – 35 → 22 ms per varv. Kvar under (a): dockan/kvoten/uppdateringspilen/Meta-tipset läser utseendet var 5:e s var för sig (bara `cat`, 1 ms) – inte värt det.

### P2 – GoblinRecorder-tjänsten kör pgrep hela tiden
- **Vad:** Tjänsten tittar efter WoW och CS2 var 5:e s med `pgrep` (`usr/libexec/goblincakes-recorder:910`, `:926`; `usr/share/goblincakes/recorder/recorder.py:908`–`:914`, `:1027`–`:1030`) och – när inget spel kör – efter OBS **varje varv**, alltså varannan sekund (`goblincakes-recorder:959`, `recorder.py:155`). Varje `pgrep` tar 25 ms (M6) eftersom den läser alla ~520 processer. Under spel faller OBS-frågan bort (villkoret på rad 959 kortsluts), men då går varvet fyra gånger i sekunden (`:1039`) och OBS:s hela loggfil läses om varannan och var femte sekund för att se om skärmfångsten frusit eller frågar efter skärm (`recorder.py:245`–`:290`, anropas från `goblincakes-recorder:965`–`:985`) – loggen växer under en raidkväll.
- **Förslag:** en enda genomläsning av `/proc` var 5:e s inne i tjänsten (som `gaming.py` gör, ~5 ms) som svarar på alla tre frågorna; OBS-svaret återanvänds mellan varven; av OBS-loggen läses bara slutet (de sista kilobyten) i stället för hela filen.
- **Vinst:** 2,1 % → ca 0,1 % i vila; 1,4 % → uppskattat 0,3 % medan WoW kör utan strid (mätt 11 nov). Under en strid med inspelning är det inte mätt.
- **Säkerhet:** sett/mätt – 2,11 % i vila (stämmer med 0,9 `pgrep` i sekunden à 25 ms) och 1,40 % medan WoW kör utan strid (M2). Under strid/inspelning: bara läst i koden – tror.
- **Risk:** låg–medel. WoW-igenkänningen är känslig (7 nov: Battle.nets `WoW.exe` med bakåtsnedstreck kändes inte igen) – samma mönster måste gälla efteråt.
- **Storlek:** liten.
- **Kan provas:** offscreen med attrapperna (`GOBLINCAKES_RECORDER_WOW`), sedan en riktig WoW-start på datorn.
- **Mät efteråt:** M2 (raden `goblincakes-recorder.service`), i vila och under spel.
- **Byggt 11 nov (Opus):** `recorder.processes(max_age)` läser `/proc` en gång (comm `obs`/`cs2`, WoW-mönstret på hela kommandoraden – samma träffar som de tre pgrep, provat sida vid sida med låtsasprocesser för båda WoW-formerna, OBS och CS2), ~9 ms. Tjänsten: WoW och CS2 delar samma läsning var 5:e s (`max_age=1`), OBS startad för hand märks inom 5 s (`max_age=5`, förut varje varv). OBS-loggen: bara de sista 128 kB (`obs_log_lines`). **Efter, i vila (11 nov 19:05):** 1,90 % → 0,20 %. Under spel: ej mätt än.

### P3 – GoblinRecorder-fönstret kör `flatpak info` varje sekund
- **Vad:** Fönstret (som ligger kvar i systemfältet) frågar varje sekund om OBS-tillägget är installerat (`flatpak info`, 13 ms) och läser CS2-kopplingen – i fönstrets egen tråd, även när fönstret är gömt (`usr/bin/goblin-recorder:65`–`:67`, `:96`–`:106`; `recorder.py:147`–`:152`).
- **Förslag:** statusfilen läses som nu (billigt, ikonen behöver den), men tillägget och CS2-kopplingen kollas bara när fönstret visas och sedan var 30:e s.
- **Vinst:** 1,4 % → ~0,1 %; fönstret hackar inte när flatpak är långsam.
- **Säkerhet:** sett/mätt – 1,44 % i vila med fönstret gömt (M2, raden `app-goblin-recorder@autostart`).
- **Risk:** låg. "Installera tillägget"-knappen kan visa gammalt läge i upp till 30 s om man inte uppdaterar direkt efter installationen.
- **Storlek:** liten.
- **Kan provas:** offscreen.
- **Byggt 11 nov (Opus):** tillägget och CS2-filen kollas när fönstret visas, efter Koppla in/Koppla bort/Installera och annars var 30:e s (`Backend.recheck`). **Efter, i vila (11 nov 19:05, fönstret öppet på skärmen):** 1,38 % → 0,46 %.
- **Mät efteråt:** M2.

### P4 – goblin graph-vakten kör `pw-dump` varannan sekund
- **Vad:** Vakten som öppnar staplarna när musik spelar frågar PipeWire efter **allt** (239 kB text) varannan sekund och tolkar det (`usr/bin/goblin-graph:66`–`:75`, `:142`–`:174`). Den fortsätter under spel, fast staplarna då ändå står still.
- **Förslag:** under spel (spelvaktens fil finns) – titta inte alls; annars var 5:e s, eller lyssna på ändringar (`pactl subscribe`) i stället för att fråga.
- **Vinst:** 1,15 % → ~0,2 %, och PipeWire slipper svara (ljudet är det sista man vill störa under spel).
- **Säkerhet:** sett/mätt – 1,15 % i vila och **2,19 % medan WoW kör** (M2; samtidigt går pipewire/pipewire-pulse från 0,4 % till 2,8 %, delvis spelets ljud). Gäller bara den som har `goblin graph auto` på (användarens dator; inte laptopen).
- **Risk:** låg. Staplarna öppnas några sekunder senare efter att musiken startat.
- **Storlek:** liten (glesare + vila under spel); medel om den ska lyssna på händelser.
- **Kan provas:** bara på riktiga datorn (ljud).
- **Mät efteråt:** M2 (raden `goblincakes-graph.service`).
- **Byggt 11 nov:** vakten var 5:e s (`WATCH_EVERY`) och inte alls medan spelvaktens fil är färsk (`game_running()`, flyttad före `watch()`); fönstrets länkare (`Linker.run`, pw-dump varannan s) vilar också under spel – länkar som redan finns blir kvar. Gäller bara med Spelläge på (som stillastående staplar förut). Inte byggt: `pactl subscribe`.

### P5 – Fyra delar letar efter spel var för sig
- **Vad:** Spelvakten läser alla processer var 3:e s (`usr/libexec/goblincakes-gameguard:256`, `usr/share/goblincakes/gaming.py:23`–`:35`), lokal AI-vakten varje sekund (`usr/libexec/goblincakes-ollama:662`–`:679`, `gaming.py:62`–`:73`), Kakans vakt var 15:e s (`ai/reminders.py:584`), Goblin AI vid svar – plus recorderns `pgrep` (P2).
- **Förslag steg 1 (litet):** snabbare genomläsning i `gaming.py` (`os.listdir` + `open` i stället för `pathlib`): 11,2 → 5,3 ms mätt. **Steg 2 (medel):** en del letar (spelvakten, även när Spelläge är avstängt – då bara letandet) och skriver en fil; de andra läser filen. I dag skrivs filen bara med Spelläge på – därför behövs en fil till för "ett spel kör" skild från "Spelläge gör något".
- **Vinst:** ca 2 % → under 0,5 %. Steg 1 ensamt halverar.
- **Säkerhet:** sett/mätt – användarens dator i vila: spelvakten 0,78 %, AI-vakten 1,19 %; medan WoW kör: 0,96 % och 1,30 % (AI:n är då stoppad, bara vakten går); laptopen: 0,94 % och 1,71 % (M2); ett varv 11,2 ms mot 5,3 ms med snabbare läsning (M8).
- **Risk:** steg 1 låg. Steg 2 medel – lokal AI ska stängas av även med Spelläge av (dagens beslut), och ett avbrott i spelvakten får inte göra att AI:n aldrig startar igen.
- **Storlek:** steg 1 liten, steg 2 medel.
- **Kan provas:** offscreen (attrapp-processer), sedan ett riktigt spel.
- **Mät efteråt:** M2 (`goblincakes-gameguard.service`, `goblincakes-ollama.service`), M8.
- **Steg 1 byggt 12 nov:** `gaming.py` läser `/proc` med `os.listdir` + `open` (binärt). M8 på användarens dator med repots fil: game_running 10,4 → 4,7 ms, processes + find_game 21,8 → 10,2 ms; samma processlista (513 st, namn och föräldrar lika). Provat med attrapper (`Wow.exe` hittas, `Battle.net.exe` räknas inte, `)` i namnet går bra). Inte provat: M2 efter nästa image och ett riktigt spel – testlista `p5-spelletandet.md`.

### P6 – Fönster som ligger kvar i minnet
- **Vad:** Varje eget fönster är ett helt Python + Qt-program. Verkligt minne (PSS, M3): Goblin AI 356 MB (+ dess webbdel), röstens igenkännare 348 MB, dashboarden gömd 221 MB, GoblinRecorder-fönstret 185 MB, GoblinShare-fönstret 146 MB. De små tjänsterna drar 7–31 MB styck, tillsammans ca 170 MB (nio stycken).
- **Förslag:** (a) dashboarden startas inte vid inloggning på datorer med lite minne utan vid första Meta-trycket (D-Bus-starten finns redan) – kostar en långsammare första öppning; (b) röstens igenkännare lämnar minnet efter t.ex. 30 min utan användning på datorer under 16 GB; (c) inget byggs förrän laptopens siffror finns – med 16 GB är det troligen inget problem där.
- **Vinst:** 200–550 MB mer till spelet på en dator med lite minne. På laptopen (16 GB): tror liten.
- **Säkerhet:** sett/mätt (M3, M9). Laptopen använder 2,4 av 15,9 GB i vila och växlar inte – där behövs punkten inte nu. Värd att bygga först om en dator med 8 GB ska köra GOBLINCAKES, eller om M9 under spel visar växling.
- **Risk:** låg–medel (första Meta-trycket/första röstfrågan blir långsammare).
- **Storlek:** liten per del.
- **Kan provas:** offscreen (start/stopp), känslan bara på riktiga datorn.
- **Mät efteråt:** M3, M9.

### P7 – Småsaker i bakgrunden (slås ihop)
- **Vad:**
  1. `goblincakes-fedora-check` ligger kvar som en egen process hela sessionen och sover 12 h i taget (`usr/libexec/goblincakes-fedora-check:92`–`:93`, autostart) – kan köras av uppdateringstimern som redan går var 4:e h (`goblincakes-updates.timer`).
  2. `goblincakes-start-hidden` lämnar en död process ("zombie") kvar under WoWUp hela sessionen (`usr/libexec/goblincakes-start-hidden:57`–`:63`: barnet som minimerar fönstret avslutas men ingen hämtar dess slutkod) – sett på användarens dator (`[goblincakes-sta] <defunct>`). Lagas med dubbel fork.
  3. Uppdateringspilen startar `cat` + `grep` + två `systemctl is-active` var 30:e s (`updates/…/main.qml:52`–`:54`, `:103`) – kan vara var 2:a min utom när menyn är öppen.
  4. Klockans volymavläsning varannan sekund (`deskclock/…/main.qml:139`) behövs bara medan volymen visas/ändras.
  5. `goblincakes-archon-tray.service` går på alla datorer, även utan Archon: 0,36 % och 33 MB på laptopen (frågar systemfältet var 4:e s, `usr/libexec/goblincakes-archon-tray:41`, `:103`). Ett villkor i enheten (`ConditionPathExists` på Archons AppImage/autostart) räcker.
  6. `goblincakes-device-battery` tar 1,6 s per varv på laptopen (0,03 s hos användaren): den väntar 0,5 s på varje Logitech-enhet på kabel som inte svarar (`usr/libexec/goblincakes-device-battery:38`–`:52`) – laptopen har G502, PRO X och en mottagare. Kom ihåg vilka som inte svarar och fråga dem inte igen förrän de kopplats om.
- **Vinst:** liten var för sig (några MB, några uppvaknanden) – lättare att läsa `ps`, en process mindre.
- **Säkerhet:** sett (1, 2 på användarens dator; 5, 6 mätt på laptopen – M2, M6; 3, 4 läst i koden).
- **Risk:** låg.
- **Storlek:** liten.
- **Byggt 12 nov:** (1) `goblincakes-fedora-check.service` (oneshot, ingen loop) startas av `goblincakes-updates.service` (`ExecStartPost=-systemctl --user start --no-block …`), autostartposten borttagen (även ur ISO:ns lista) – körd på riktigt: 1,1 s, ingen notis (nvidia låst på 44). (2) dubbel fork i `goblincakes-start-hidden` – provat: den gamla lämnar `python3 <defunct>`, den nya inget. (3) uppdateringsrutan var 2:a min (30 s medan automatiska uppdateringen hämtar) + läsning när musen kommer över. (4) **granskningen hade fel:** ljudikonen visar nivån hela tiden, så volymen behövs även utan klick – nu var 6:e s (var 18:e under spel) + läsning vid hovring; ikonen kan ligga efter högst 6 s när volymen ändras någon annanstans. (5) `ConditionPathExists=%h/AppImages/Archon.AppImage`, Config startar tjänsten efter att Archon installerats – villkoret provat med en provenhet. (6) tysta HID++-gränssnitt i `~/.cache/goblincakes/device-battery-silent.json` (nyckel hidraw + HID-instans, ny vid omkoppling), frågas igen efter 10 min – provat med attrapp (4 frågor → 0 → 4 efter 10 min); användarens dator har inga tysta (0,02 s före och efter). Inte provat: laptopen (5, 6) och widgetarna i panelen (3, 4) – testlista `p7-smasaker.md`.
- **Kan provas:** 1–2 offscreen, 3–4 på riktiga datorn.
- **Mät efteråt:** M3 (processen borta), `ps -eo stat,comm | grep '^Z'`.

### P8 – Program startade från dashboarden hamnar i dashboardens enhet
- **Vad:** Goblin AI, GoblinShare och terminaler som öppnas från dashboarden (`usr/bin/goblin-dashboard:556`, `:567`, `:575` – `subprocess.Popen(…, start_new_session=True)`) blir kvar i dashboardens systemd-enhet (`dbus-:1.3-org.goblincakes.dashboard@0.service`). Sett på användarens dator: enheten redovisar 2 976 MB och 12–19 % CPU, nästan allt är Goblin AI och det som körs i dess terminal.
- **Förslag:** starta via `systemd-run --user --scope` (som spelvakten gör för WoWUp) eller KDE:s egen programstart, så varje program får sin egen enhet.
- **Vinst:** rätt siffror per program (M1/M2 blir läsbara), och minnesvakten (`systemd-oomd`) ser inte dashboarden + allt den startat som en enda stor bov att stänga på en gång.
- **Säkerhet:** sett – M1 och listan över processer i enheten. Att oomd skulle stänga hela gruppen: tror (läs `oomctl` på en dator där minnet tar slut; `KillMode=process` gör att ett vanligt stopp av dashboarden **inte** drar med sig programmen – sett).
- **Risk:** låg.
- **Storlek:** liten.
- **Kan provas:** på riktiga datorn (`systemd-cgls --user` efter start från dashboarden).
- **Mät efteråt:** M1.

**Granskat utan anmärkning (område 1):** dashboarden stannar sina timers när den är gömd (`goblin-dashboard:312`–`:317`); KWin-skriptet är händelsestyrt (enda timern går bara medan dockan visas med Meta+Z); notistjänsten, GoblinShare-tjänsten, Kakans vakt, Archon-ikonen och rösten (lyssnar) drar 0,05–0,13 % var; rösten använder inget grafikminne (`device="cpu"`); lagmätaren och prewarm går bara på begäran / en gång; Ianseo-backupen är inte påslagen för den som inte har Ianseo.

---

## Område 2 – Uppstart och inloggning

Mätt (M10, M11). Användarens dator: från strömknapp till skrivbord 43 s, varav 22 s är datorns egen firmware och startmenyn, kärnan 3 s, tidig uppstart (initrd) 8 s och resten 10 s. Laptopen: 57 s – firmware 8 s, startmenyn 16 s, kärnan 1 s, initrd 14 s, resten 17 s. Det mesta i uppstarten är redan genomarbetat (bakgrundsjobben väntar 20 min, mjukvarulistan/man-sidorna körs bara efter en ny image, Steam väntar på diskarna) – här finns mindre att hämta än i område 1.

### P9 – Inloggningen startar 14 hjälpprogram samtidigt med skrivbordet
- **Vad:** 14 autostart-poster (`etc/xdg/autostart/goblincakes-*.desktop`) körs vid varje inloggning, nästan alla i samma ögonblick som Plasma själv startar. De flesta gör ingenting efter första gången men kostar ändå en Python-start var. Mätt (M10, varm disk): `goblincakes-wow-links` 274 ms, `goblincakes-gpu notify` 248 ms, `goblincakes-laptop` 141 ms (även på en stationär – den frågar `goblincakes-gpu hw` och startar Python två gånger för att konstatera att det inte är en laptop, `usr/libexec/goblincakes-laptop:13`–`:15`), `goblincakes-config --first-run` 134 ms (laddar hela Qt innan den tittar efter klar-filen: importerna på `usr/bin/goblincakes-config:19`–`:23`, kollen först på `:1286`), `goblincakes-tweak apply mouse-flat` 122 ms, `goblincakes-ianseo-tray` ~100 ms (laddar Qt innan den ser att Ianseo inte är utdelat, `usr/libexec/goblincakes-ianseo-tray:14`–`:16`), `desktop-layout login` 74 ms, `automount` 62 ms, `season` 27 ms, `calendar` 16 ms. Dessutom `goblincakes-webapp-icon --upgrade` 329 ms i bakgrunden från `goblincakes-refresh.sh:317` för den som har webbappar.
- **Förslag:** (a) titta efter flaggfilen **före** de tunga importerna i Config och Ianseo-ikonen (eller direkt i `.desktop`-filens `Exec=sh -c '[ -e … ] || exec …'`); (b) `goblincakes-laptop`: en billig koll först (finns `/sys/class/power_supply/BAT*`?); (c) det som inte brådskar (WoW-länkarna, grafikkollen, webbapp-ikonerna, årstiden) får `X-KDE-autostart-after=panel` eller startas 10–20 s senare, så de inte tävlar med skrivbordet.
- **Vinst:** ca 1 s mindre processorarbete under inloggningen på användarens dator; på laptopen tror 2–4 s (kall disk, långsammare kärnor) – skrivbordet blir användbart tidigare.
- **Säkerhet:** sett/mätt – tiderna ovan (M10), tillsammans ca 1,4 s på användarens dator. Laptopen: de tre som gick att köra utan att ändra något tog 1,3–1,6 gånger så lång tid (Config 185 ms, `gpu hw` 61 ms, Qt-import 124 ms); resten: tror – hela M10 körs där när hon är med.
- **Risk:** låg. Det som kan gå fel: en hjälpare som måste gå före något annat (automount före Steam – den rörs inte; skärmarna – rörs inte) flyttas för sent.
- **Storlek:** liten.
- **Kan provas:** (a)–(b) offscreen; ordningen bara på riktiga datorn (logga ut/in).
- **Mät efteråt:** M10, och `systemd-analyze --user blame | head -25` (M11).
- **Byggt 12 nov:** (a) Config `--first-run` tittar efter klar-filen före Qt (131 → 32 ms), Ianseo-ikonen laddar Qt först när Ianseo är utdelat (106 → 23 ms); båda provade åt andra hållet också (startar och kör offscreen utan klar-fil / med nätverket på). (b) `goblincakes-laptop`: snabb bash-koll (chassi, eget batteri, antal grafikkort i `/sys/bus/pci`) före `gpu hw`, och `gpu hw` läses med `case` i stället för 2–4 Python-starter: 125 → 8 ms på användarens dator. **Fel hittat:** `is_laptop()` räknade den trådlösa musens batteri (`hidpp_battery_0`, scope Device) – användarens stationära var "laptop" och letade pekplattor vid varje inloggning; lagat i `goblincakes-gpu`. (c) bara webbapp-ikonerna med `nice -n 19 ionice -c 3`: `nice` på WoW-länkarna/grafikkollen skulle ärvas av WowUp/Config (de startar dem) och kan inte höjas igen utan root, och en fördröjning skulle alltid lägga WoW-länkarna efter Raider.IO/WowUp (de hoppar över Raider.IO när det kör) – därför orörda. Inte provat: en riktig inloggning och frugans laptop (testlista `p9-inloggningen.md`).

### P10 – Uppdateringskollen går 20 s efter inloggning och tar 7 s
- **Vad:** `goblincakes-updates.timer` (`OnStartupSec=20s`) kör `goblincakes-updates check`: `rpm-ostree status` två gånger, `skopeo` tre gånger, `flatpak remote-ls` fyra gånger, `fwupdmgr`, ChatGPT-appen (`usr/libexec/goblincakes-updates:49`–`:108`, `:252`–`:392`). Mätt: 7,1 s (M11). Samtidigt startar `goblincakes-fedora-check` och frågar `skopeo` om samma image en gång till (`usr/libexec/goblincakes-fedora-check:27`–`:38`).
- **Förslag:** första kollen 2–3 min efter inloggning i stället för 20 s (pilen visar under tiden det sparade svaret från förra kollen – `~/.cache/goblincakes/updates.json`), och Fedora-kollen läser samma svar i stället för att fråga själv (hör ihop med P7.1).
- **Vinst:** lugnare första minut efter inloggning, särskilt på laptopen (nätverk + disk + processor just när programmen startar). En nätverksfråga mindre.
- **Säkerhet:** sett/mätt – 7,1 s på användarens dator, 9,3 s på laptopen (M11).
- **Risk:** låg. Pilen kan visa gårdagens läge i två minuter.
- **Storlek:** liten.
- **Kan provas:** offscreen (timern) + riktiga datorn.
- **Mät efteråt:** M11 (`goblincakes-updates.service` i `--user blame`).
- **Byggt 12 nov:** timern `OnStartupSec=150s` (pilen läser `/run/ostree/staged-deployment` själv sedan 11 okt, så ett gammalt "starta om" syns inte under väntan – skälet till 20 s finns inte kvar). `goblincakes-fedora-check` väntar 3 min och frågar inte skopeo när `updates.json` är högst 15 min gammal med `system: ""`. Provat: `up_to_date()` med fem låtsasfiler, `systemd-analyze verify`. Inte provat: en riktig inloggning (testlista `p10-uppdateringskollen.md`). Kvar för P7.1: Fedora-kollen som egen process hela sessionen. Känd svaghet: misslyckas systemdelen av kollen (inget nät) men resten lyckas, står `system` kvar från förra gången med ny `checked` – Fedora-notisen kan då komma upp till 12 h senare.

### P11 – Nvidia-modulerna laddas i tidig uppstart: 6 s hos användaren, 12,5 s på laptopen (Universal Blue, inte GOBLINCAKES)
- **Vad:** På Nvidia-varianterna tvingar Nvidia-paketets egen fil `/usr/lib/dracut/dracut.conf.d/99-nvidia.conf` (från `nvidia-kmod-common`, alltså Universal Blue/negativo17) in `i915 amdgpu nvidia nvidia_drm nvidia_modeset nvidia_peermem nvidia_uvm` redan i initrd. På användarens dator tar det steget (`dracut-pre-udev.service`) 6,1 s av uppstartens 43, och slutar varje gång med felet `could not insert 'nvidia_peermem': Invalid argument`. **På laptopen tar samma steg 12,5 s (11,9 s ren processortid) av 57 s** – den enskilt största posten i hela uppstarten – och initramfs är där 400 MB, vilket troligen också förklarar att startmenyn tar 16 s (den läser in hela filen). Det här beror **inte** på Fedora-versionen och inte på GOBLINCAKES egna filer – men GOBLINCAKES kan lägga en egen dracut-fil efter den. Samma sak gör troligen att initramfs är 309 MB (sett; vad som tar plats: M14).
- **Förslag:** (a) litet: ta bort `nvidia_peermem` ur listan (den går aldrig att ladda utan särskild nätverkshårdvara) – ett fel mindre i loggen, kanske någon tiondel; (b) större: ladda inte `nvidia_uvm`/`nvidia` i initrd utan först i det riktiga systemet. Föreslås **inte** utan prov: tidig laddning finns för att startskärmen och inloggningsskärmen ska få rätt upplösning och inte bli svarta.
- **Vinst:** (a) renare logg. (b) upp till ~5 s snabbare uppstart hos användaren och ~10 s på laptopen (plus en mindre initramfs att läsa in) – tror.
- **Säkerhet:** sett/mätt – 6,1 s och felraden på användarens dator, 12,5 s på laptopen (M11). Vad i steget som tar tiden (uppackning, signaturkontroll, vilken modul): vet inte – M14 visar vad som ligger i initramfs. Att (b) går utan svart skärm: tror inte utan prov.
- **Risk:** (a) låg; (b) hög – uppstarten/inloggningsskärmen kan bli svart (rollback i startmenyn räddar).
- **Storlek:** (a) liten, (b) medel + prov på båda Nvidia-datorerna.
- **Kan provas:** bara på riktiga datorn. Går troligen att prova på **en** dator utan ny image: `rpm-ostree initramfs --enable` med egna dracut-växlar bygger en lokal initramfs och `--disable` tar bort den igen (Opus bekräftar växlarna först) – användarens dator före laptopen.
- **Mät efteråt:** M11.
- **Byggt 12 nov – bara (a):** `files/system/usr/lib/dracut/dracut.conf.d/99-zz-goblincakes-no-peermem.conf` läses efter `99-nvidia.conf` (bokstavsordning, båda källas av dracut som bash) och tar bort just `nvidia_peermem` ur `force_drivers` (`${force_drivers//nvidia_peermem/}`) + `omit_drivers`. Resten av Universal Blues lista lämnas – ändrar de den följer den med. Utan Nvidia-filen (basvarianten) gör filen inget. Initramfs byggs om av `type: initramfs` sist i `common-modules.yml` (efter `files`). Provat: filerna källade i bash → listan utan peermem, tom utan Nvidia-filen; `check.py` 0 fel. Ej provat: riktig initramfs/uppstart – testlista `p11a-peermem.md` efter nästa image. **(b) struken** (användaren 12 nov): några sekunder är inte värda risken för svart skärm (tajmingen inloggningsskärm/drivrutin). Ta inte upp den igen om användaren inte frågar.

**Granskat utan anmärkning (område 2):** `goblincakes-firstlogin` avslutar direkt när layouten är samma (två filläsningar); `goblincakes-refresh.sh` kostar lite (kontrollsumman över temafilerna 6 ms, `kreadconfig6` 6 ms styck, färgvalet 89 ms bara för den som valt färg); `goblincakes-disk-owner` väntar 2 s med flit; Steam-väntan har tak på 30 s; `goblincakes-variant-sync` körs bara tills den lyckats en gång. `NetworkManager-wait-online` (5,2 s) och `plasma-kded6` (3,3 s) är Fedoras/Plasmas egna och stoppar inte inloggningsskärmen. Ianseos containrar väntar på nätverket (4,5 s) – bara för den som har Ianseo.

---

## Område 3 – Image och bygge

Gäller alla tre varianterna. Läst ur bygget 11 nov 16:01 (`goblincakes-nvidia`, 12,5 min) och jämfört med bygget tre timmar tidigare (M12, M13).

**Så ser imagen ut:** 288 lager, 6,45 GB packat. 259 lager (5,10 GB) är Universal Blues bas och delas oförändrade. GOBLINCAKES egna 29 lager är 1,35 GB: 242 RPM-paket (684 MB installerat – Steam med 32-bitarsbibliotek, `scx-scheds` 140 MB, `gh` 39 MB m.fl.), demoparser 502 MB (polars 170, pyarrow 166, pandas 46 – användarens val 22 okt), initramfs 309 MB, egna filer 18 MB.

### P12 – Varje uppdatering laddar ner 1,4 GB för 117 MB nytt innehåll
- **Vad:** Bygget kör utan cache och utan omstyckning (byggloggen: `use_cache: false`, `rechunk: false`, `build_chunked_oci: false`, `chunkah: false`; `.github/workflows/build.yml:69`–`:78` sätter inget av dem). Då får alla GOBLINCAKES 29 lager nya namn i varje bygge, även när innehållet är detsamma – och datorn måste hämta alla igen. Två byggen med tre timmars mellanrum (bara fönsterramarna ändrade) delade 260 lager (basen) men inget av de egna: 1,35 GB ny nedladdning. Systemloggen på användarens dator säger samma sak vid varje uppdatering: `layers already present: 260; layers needed: 28 (1,4 GB)` … `New objects: … totaling 116,7 MB`. Alltså 1,4 GB hämtat för 117 MB som faktiskt var nytt. **På laptopen är det värre:** legacy-variantens egna lager är 2,9 GB (Nvidia-drivrutinen ligger i dem) – loggen där säger `custom layers needed: 29 (2,9 GB)` för 119 MB nytt, vid varje uppdatering, över wifi.
- **Förslag:** slå på en av bygg-actionens omstyckningar (`rechunk: true`, `build_chunked_oci: true` eller `chunkah: true` i `build.yml`) – de delar upp den färdiga imagen i lager efter innehåll (paket för paket), så att oförändrade paket behåller sitt lager mellan byggen. Opus läser actionens README och väljer den som BlueBuild rekommenderar nu, provar först på **en** variant (legacy eller bas – inte den användaren kör) och jämför med M12.
- **Vinst:** nedladdningen per uppdatering från 1,4 GB (laptopen 2,9 GB) till uppskattat 150–500 MB (det som verkligen ändrats + initramfs). `goblin update` och de automatiska uppdateringarna går fortare, mindre skrivande på laptopens 256 GB-disk, mindre lagring på GitHub.
- **Säkerhet:** sett/mätt – 1,35 GB nya lager mellan två byggen (M12), 1,4 GB mot 116,7 MB i loggen (M13); inställningarna lästa ur byggloggen. Hur stor vinsten blir efter omstyckning: tror – mäts med M12 på första bygget efter ändringen. Att initramfs (309 MB) ändå byts varje gång: tror (den byggs om i varje bygge).
- **Risk:** medel. Bygget går en annan väg på slutet: det kan ta längre tid (tror +5–15 min), och ett fel där kan ge en image som inte startar – rollback i startmenyn räddar, och ISO-bygget (`build-iso.yml`) måste provas en gång efteråt. Första uppdateringen efter bytet hämtar allt (alla lager byter namn en gång).
- **Storlek:** liten ändring (en–två rader), men medel med proven: ett bygge, uppdatering + omstart på båda datorerna, ISO-bygget.
- **Kan provas:** bara på riktigt (GitHub-bygget + en riktig uppdatering).
- **Mät efteråt:** M12 (två byggen i följd) och M13.
- **Byggt 11 nov (Opus, Fable granskar):** `chunkah: true` för **bara basvarianten** (`recipe.yml`) via matrisens `include` i `build.yml` (`chunkah: ${{ matrix.chunkah }}`). Valet: actionen v1.13 har tre sätt; `rechunk` ska tas bort och kan ge fel filrättigheter, Universal Blues Aurora, Bazzite och image-template styckas med chunkah (ublue-os/main, vår bas, gör det inte – den har kvar Fedoras ostree-lager). CLI:t byter själv till podman när chunkah är på (`build.rs`), max 128 lager (standard). Etiketterna (`org.opencontainers.image.*`, som `goblincakes-updates` och `goblincakes-fedora-check` läser) följer med via `--config` – kolla med `skopeo inspect` efter första bygget. **Fables granskning 11 nov: godkänd** (matrisen rätt, "false" = av för nvidia/legacy, signering och concurrency orörda, ISO-bygget bör klara 128 lager, `goblincakes-updates` klarar indexet). **Vinsten blir troligen mindre än 150–500 MB:** chunkah låser bara tiden på RPM-ägda filer – demoparser (502 MB, `pip --target` + `.pyc` med inbakad tid), initramfs (309 MB), rpm-databasen och våra egna filer (18 MB) får nya lager varje bygge. Att nollställa deras tider (som Bazzites `reset-mtimes.sh`, chunkah#160) är ett eget steg efter M12. Låsa chunkah-versionen (i dag `latest` = v0.7.1; bara tagg går, CLI:ts digest-koll har en bugg) när alla tre varianterna har den. Diskutrymmet (uppskattat 35–45 GB) syns först i bygget – trängre för legacy. Kakans felorsak för basen blir grövre (podman-logg, inga BuildKit-rader). **Kolla efter första bygget, före nästa variant:** `skopeo inspect docker://ghcr.io/kaytho-git/goblincakes:latest` – högst 128 lager, `org.opencontainers.image.version/source/created`, `ostree.linux`, `containers.bootc` kvar, `ostree.commit`/`ostree.final-diffid` borta; byggtiden och inget "no space left" i loggen. **M12 mätt 12 nov: 2,07 → 0,55 GB per uppdatering på basen.** **12 nov: chunkah på för nvidia-legacy också** (ingen egen ISO – ISO-provet gäller bara bas och nvidia; kolla diskutrymmet i första bygget, frugans laptop hämtar allt en gång). **Legacy, första bygget med chunkah (ef8d1e7, 12 nov) kollat:** 128 lager, 4,98 GB, etiketterna version/source/created, `ostree.linux` (7.3.3-300.fc45), `containers.bootc` kvar, `ostree.commit`/`ostree.final-diffid` borta; 88 GB ledigt på byggdatorn vid start, inget "no space left"; byggtiden 10,6 → 14,8 min (basen 13,2 → 17,4 – chunkah kostar ~4 min). Nästa för legacy: M12 efter andra bygget. Nästa: ISO-bygget (söndag, eller kör det för hand) startar och installerar; sedan nvidia-legacy (frugans laptop, mest att vinna) och sist nvidia.

### P13 – AppGrid och libratbag byggs från källkod tre gånger i varje bygge
- **Vad:** Byggstegen i `recipes/common-stages.yml:6`–`:20` körs en gång per variant (tre gånger per bygge), och varje gång hämtas dessutom en hel extra basimage (`kinoite-main`, 213 s) bara för att bygga dem. AppGrid tar 174 s att bygga, libratbag 25 s. Resten av ett bygge: hämta basen 226 s, Steam 131 s, dnf-paketen 85 s, initramfs 54 s, ladda upp 69 s.
- **Förslag:** bygg de två delarna i ett eget flöde (vid ändring av byggskripten och t.ex. en gång per dygn före 06:00) till en liten egen image, och låt recepten bara kopiera ur den (`type: copy` finns redan). `check-appgrid.sh` stoppar redan bygget om AppGrid inte laddar – den kollen blir kvar som skydd när Plasma/Qt bytt version.
- **Vinst:** byggtiden ca 12,5 → 9 min per variant, och ett bygge som inte längre faller på att AppGrids eller libratbags källkod/nedladdning strular just då.
- **Säkerhet:** sett/mätt – tiderna ur byggloggen 11 nov. Att förbyggd AppGrid alltid passar dagens Plasma: tror inte alltid – därför behövs kollen och en reservväg (bygg om direkt när kollen faller).
- **Risk:** medel. En AppGrid byggd mot gårdagens Qt kan vägra ladda efter en Qt-uppdatering → bygget stoppas (inte en trasig image) tills delarna byggts om.
- **Storlek:** medel.
- **Kan provas:** bara på GitHub.
- **Mät efteråt:** byggtiden: `gh run list --workflow build.yml --limit 5`.

### P14 – Småsaker i bygget (slås ihop)
- **Vad:**
  1. `install-demoparser.sh` hämtar "senaste" demoparser2 + awpy utan låst version och avslutar alltid med 0 (`files/scripts/install-demoparser.sh:10`–`:18`): en ny version som ändrat sig, eller ett misslyckat `pip`, ger en image där CS2-siffrorna tyst slutar fungera. Förslag: lås versionerna (höjs med flit), och låt bygget skriva en tydlig varningsrad som `buildstatus.py`/Kakan kan läsa.
  2. `remove-extras.sh` säger "a smaller image" (`recipes/common-modules.yml:105`) – paketen ligger kvar i basens lager, så nedladdningen blir inte mindre, bara disken hos användaren. Bara kommentaren är fel; inget att bygga.
  3. `scx-scheds` (140 MB) följer med för reglaget "Spelschemaläggare (scx_lavd)" i Config → Inställningar → Prestanda, avstängt som standard (`files/scripts/install-scx.sh`) och avstängt på användarens dator (sett 11 nov). Efter P12 laddas paketet inte ner om varje gång – då kostar det bara 140 MB disk och kan lika gärna vara kvar.
  4. Bygget startar för ändringar som inte påverkar imagen: `tools/**`, `.claude/**`, `LICENSE`, `.github/dependabot.yml` saknas i `paths-ignore` (`.github/workflows/build.yml:8`–`:18`).
- **Vinst:** färre tysta fel (1), färre onödiga byggen (4), ev. 140 MB (3).
- **Säkerhet:** sett (läst i filerna). Att reglaget för `scx` inte används: vet inte – användaren avgör.
- **Risk:** låg.
- **Storlek:** liten.
- **Kan provas:** på GitHub (ett bygge).
- **Mät efteråt:** –
- **Byggt 12 nov (delvis):** (1) versionerna **inte** låsta (användaren 12 nov: "olåst") – en CS2-uppdatering som ändrar demoformatet lagas av nästa image. I stället: Kakans efterkontroll (`ai/aftercheck.py`, delen `demoparser`, bara med `recorder-on`) läser in demoparser2 + awpy efter varje ny image – en ny version som inte går att läsa in ger notisen "Efter uppdateringen …" (bara om den fungerade före). Provat: läses in (0,5 s), och med ett trasigt paketnamn → fel med orsaken. (2) **behövs inte längre:** chunkah (P12) styckar det färdiga filsystemet, så borttagna paket följer inte med i nedladdningen – kommentaren "a smaller image" stämmer nu. (3) **borttaget 12 nov (användaren: "A")** – reglaget var dolt sedan scx-scheds 1.1.4 (startas av `scx_loader.service`, inte `scx.service` som `goblincakes-tweak` letade efter → "unavailable"); paketet installerades i vårt byggsteg (147 MB): `install-scx.sh`, receptraden, reglaget i `tweaks.json` och `goblincakes-tweak` borta; `irqbalance` finns inte i imagen, så inget att återställa. (4) `tools/**`, `.claude/**`, `LICENSE`, `.github/dependabot.yml` i `paths-ignore` (kontrollen och generatorerna körs före en commit, deras resultat ligger i `files/`).

**Granskat utan anmärkning (område 3):** Firefox finns både som RPM (341 MB med språkpaket) och som Flatpak – RPM:en behövs för live-ISO:n och för en nyinstallerad dator utan internet, så den ska vara kvar. Ordningen på modulerna (egna filer först) spelar ingen roll så länge bygget kör utan cache, och inte heller efter P12. Besluten i CLAUDE.md (Steam i imagen, Fedoras kärna, inte Bazzite) berörs inte av någon punkt. Byggskripten har `set -e`/`-u` där ett fel ska stoppa bygget och saknar det med flit där bygget ska gå vidare (Xbox-moduler, goverlay, scx, demoparser). initramfs är 309 MB (sett: `/boot/ostree/…/initramfs…img`) – hör ihop med P11 (Nvidia-modulerna i tidig uppstart); vad som tar plats i den kräver `sudo lsinitrd -s` (M14).

---

## Område 4 – Kodkvalitet och underhåll

Läget är bättre än väntat: alla 193 Python-, skal- och JSON-filer klarar syntaxkollen, alla 25 QML-filer i egna fönster kompilerar offscreen, bara 47 rader Python är oanvända (14 små funktioner), inga döda filer av betydelse (bara BlueBuilds mall `files/scripts/example.sh`), och alla "två kopior" i CLAUDE.md är i takt just nu (låsskärmen identisk, utloggningen skiljer bara på en kommentar, de tre Chromium-policyerna identiska, `fitTileToWindow` identisk på båda ställena). Det som finns att göra handlar om att **hålla** det så.

### P15 – Ingen kontroll före bygget
- **Vad:** Ett stavfel i ett skript upptäcks i dag först när det redan ligger i imagen på båda datorerna (uppdateringarna förbereds automatiskt). Bygget (`.github/workflows/build.yml`) kontrollerar bara att PySide6 går att ladda (`recipes/common-modules.yml:129`–`:133`). Reglerna i CLAUDE.md ("ändra båda kopiorna", "höj `LAYOUT_VERSION`", "höj `version` i manifesten") vilar helt på att ingen glömmer.
- **Förslag:** ett litet kontrollskript (`tools/check.sh`) som körs som första steg i bygget och som Claude kör före commit: (1) syntax för alla Python-/skal-/JSON-filer, (2) alla fönsters QML kompilerar offscreen, (3) kopiorna är lika (låsskärm, utloggning, tre policyfiler, `fitTileToWindow`), (4) `tools/learn-validate.py`, (5) varning om layoutfilerna ändrats utan att `LAYOUT_VERSION` höjts, och om Chrome-temat ändrats utan ny `version`. Faller kontrollen stoppas bygget innan något byggs.
- **Vinst:** färre trasiga images (ett fel i t.ex. spelvakten ger i dag en tjänst som tyst inte startar), och reglerna om kopior behöver inte kommas ihåg.
- **Säkerhet:** sett – allt i (1)–(3) går igenom i dag, provkört här: syntaxkollen tog några sekunder, QML-kollen (25 filer) likaså.
- **Risk:** låg. En för sträng kontroll kan stoppa ett bygge i onödan – varningar (5) ska inte stoppa.
- **Storlek:** liten.
- **Kan provas:** i molnet/offscreen.
- **Mät efteråt:** –
- **Byggt 11 nov (Opus):** `tools/check.py` (Python i stället för skal – lättare att hålla rätt) – (1)–(5) som förslaget; (4) bara när kursfilerna ändrats och php/node/lua5.1 finns, annars varning. Eget jobb `check` ("Kontroll före bygget") i `build.yml` som `bluebuild` väntar på (`needs`): Python 3.14, PySide6 6.11 från PyPI (faller installationen = QML-kollen hoppas över med varning), varningarna jämför med förra pushen (`github.event.before`, annars `HEAD~1`). Provat här: 0 fel på dagens repo (2 s), och i en kopia med ett påhittat fel av varje sort (Python, skal, JSON, QML-egenskap, policyfil, fitTileToWindow, layoutfil) – alla sex fel + varningen hittades. Mot HEAD~30 kommer en äkta varning (Aurorae v2 i `defaults` 59ec341 utan ny LAYOUT_VERSION – löst med engångsfix, alltså rätt att det bara är en varning). **Första bygget på GitHub (2d6cd2a) stoppades:** GitHubs maskin saknade `libpulse.so.0` (QtMultimedia, `recorder/Main.qml`) och `org.kde.layershell` (`voice/Box.qml`) – inget fel i koden. Rättat 11 nov: `libpulse0` installeras i jobbet, och saknade `org.kde.*`-moduler/systembibliotek blir varning (`MISSING_HERE`) – hemma finns allt, så där kollas de fullt. Provat här med påhittad KDE-modul (varning) + syntaxfel (fel). Ej provat på GitHub än.

### P16 – Samma QML-komponenter kopierade i flera fönster
- **Vad:** `FastWheel` finns som egen kopia i sju fönster (`ai/Main.qml:1240`, `config/Main.qml:377`, `recorder/Main.qml:390`, `dashboard/Main.qml:195`, `amp/Main.qml:540`, `share/Main.qml:89`, `remove/Main.qml:73`) – fem är identiska, **dashboardens och GoblinAmps har redan glidit isär**. `SectionTitle` och `Note` är identiska i tre fönster (`recorder/Main.qml:452`/`:460`, `share/Main.qml:122`/`:130`, `remove/Main.qml:148`/`:156`), `Monogram` i två (`config/Main.qml:447`, `remove/Main.qml:103`). USB-skaparen har egna kopior av allt (`usb-skaparen/Main.qml:70`–`:223`) – den byggs för sig och får vara så.
- **Förslag:** flytta `FastWheel`, `SectionTitle`, `Note` och `Monogram` till `share/goblincakes/qml/Goblin` som de andra, och låt fönstren använda dem (dashboardens/Amps skillnader blir egenskaper).
- **Vinst:** en ändring av rullningen görs på ett ställe i stället för sju; ca 250 rader mindre.
- **Säkerhet:** sett – jämfört med kontrollsumma.
- **Risk:** låg–medel. Rullningen i dashboarden/Amp kan bete sig lite annorlunda om skillnaderna inte förs över rätt.
- **Storlek:** liten–medel (ett fönster i taget).
- **Kan provas:** offscreen (kompilerar) + rulla i varje fönster på riktiga datorn.
- **Mät efteråt:** –
- **Byggt 12 nov:** `qml/Goblin/FastWheel.qml` (egenskaper `step` – Amp 0.5, `chain` – Amp av, `takeSideways` + signalen `sideways` – dashboarden → `win.nudgeView`), `SectionTitle.qml`, `Note.qml`, `Monogram.qml`; fönstren har kvar en rad `component X: G.X { … }` (som FlatButton), så användningarna är orörda; GoblinAmp fick `import "../qml/Goblin" as G`. 217 rader mindre i sju fönster. Provat: riktiga hjulhändelser offscreen mot gamla kopiorna från git och nya – samma resultat för vanliga (inre lista till slutet, sedan den yttre), Amp (halvt steg, ingen fortsättning) och dashboarden (sidled → vy); alla sju fönstren kompilerar. Inte provat: rulla i fönstren på riktiga datorn (testlista `p16-rullning.md`).

### P17 – Fönstrens startkod kopierad i tio program
- **Vad:** Varje fönster sätter själv skalan (`QT_SCALE_FACTOR` 0.9 och tar bort den igen), laddar typsnitten, ordnar "ett fönster i taget" (QLocalServer/QLocalSocket), kopplar in färgvalet och sätter ikon – samma ~40 rader i `usr/bin/goblin-recorder:749`–`:780`, `goblin-share:390`–`:420`, `goblin-dashboard:661`–`:705`, `goblincakes-config:1285`–`:1320`, `goblin-ai:3414`–`:3485`, `goblin-amp:1935`–`:1960`, `goblin-graph:806`–`:845`, `usr/libexec/goblincakes-lagmeter:761`–`:785`, `goblincakes-voice:615`–`:630` (+ Avinstallera). De skiljer redan: GoblinAmp och goblin graph sätter ingen skala, och GoblinAmps fyra fildialoger saknar `sharpText` (`amp/Main.qml:2168`–`:2187`) som regeln i CLAUDE.md kräver.
- **Förslag:** en gemensam modul bredvid `accent.py` (t.ex. `goblinapp.py`: `start(namn, ikon)` → app + motor, `single_instance(namn, visa)`), ett fönster i taget enligt användarens regel om stora ändringar.
- **Vinst:** lättare underhåll – nästa ändring av skalan/typsnitten görs en gång; nya fönster blir rätt från början.
- **Säkerhet:** sett (läst i koden). Om GoblinAmps avvikelser är avsiktliga: vet inte – kolla "GoblinAmp" i anteckningarna före ändring.
- **Risk:** medel – rör alla fönster; fel i den gemensamma modulen = inget fönster startar. P15 (QML-/syntaxkollen) bör byggas först.
- **Storlek:** medel (en session, ett fönster i taget).
- **Kan provas:** offscreen per fönster + start på riktiga datorn.
- **Mät efteråt:** –

### P18 – Inga färdigkompilerade Python-filer i imagen
- **Vad:** `/usr` går inte att skriva i, och imagen har inga `__pycache__` för GOBLINCAKES egna moduler (`/usr/share/goblincakes/**`) eller demoparser (`files/scripts/install-demoparser.sh:11` tar till och med bort dem). Python kompilerar därför om källkoden vid **varje** start av varje program.
- **Förslag:** en rad sist i bygget: `python3 -m compileall -q --invalidation-mode unchecked-hash /usr/share/goblincakes /usr/lib/goblincakes` (hash-läget behövs eftersom alla filer i en atomisk image har datumet 1970), och låt bli att ta bort demoparserns.
- **Vinst:** mätt på användarens dator (M15): demoparser-importen (varje CS2-demo) 1,3–2,0 s → 0,4 s; `goblincakes-recorder status` 117 → 73 ms; `goblin-ai` 418 → 356 ms; `goblincakes-share status` 86 → 66 ms. På laptopen: `goblincakes-recorder status` 184 → 110 ms, `goblincakes-share status` 132 → 90 ms (mätt). Kostar ca 23 MB i imagen.
- **Säkerhet:** sett/mätt (M15, med `PYTHONPYCACHEPREFIX` som låtsas-cache).
- **Risk:** låg. Fel läge (tidsstämpel i stället för hash) ger bara att filerna inte används – inget går sönder.
- **Storlek:** liten.
- **Kan provas:** i bygget; effekten på riktiga datorn efter nästa image.
- **Mät efteråt:** M15 (första talet på varje rad ska bli som det andra).
- **Byggt 12 nov (Opus):** `files/scripts/compile-python.sh` (modul i `common-modules.yml` direkt efter PySide6-kollen – inga Python-filer läggs till efter den): `compileall -q -f -j 0 --invalidation-mode checked-hash` på `/usr/share/goblincakes` + `/usr/lib/goblincakes`; `-f` skriver om pips tidsstämpelfiler i demoparser (dess `rm __pycache__` får stå kvar). Stoppar aldrig bygget. Provat här på en kopia: 48 filer, ~0,9 MB (utan demoparser), datum satta till 1970 → Python säger "matches" och använder filen; två översättningar ger byte för byte samma filer (bra för chunkah). **checked-hash, inte unchecked** (användaren: "ingen ny millenniebugg"): ingen tid i filerna, och en källa ändrad under `usroverlay` översätts på nytt (provat) i stället för att en gammal fil används; kostar ~1 ms (dash: 0,7 ms mot 9 ms utan fil). Ej provat: bygget och M15 på riktiga datorn efter nästa image.

### P19 – Städning (slås ihop)
- **Vad:**
  1. `goblincakes-refresh.sh` har tolv engångsfixar med flaggfil från 9–29 okt (`etc/xdg/plasma-workspace/env/goblincakes-refresh.sh:50`, `:64`, `:72`, `:87`, `:100`, `:112`, `:123`, `:132`, `:152`, `:177`, `:232`, `:296`) – ca 200 av filens 334 rader. Användarens dator har alla flaggorna (sett); laptopen installerades 3 nov med en image där felen redan var lagade. De gamla (Ghostty-storleken, dockans fästa program, klockans vikt, AppGrid-storleken, Meta-tangenten) kan tas bort – laptopen har flaggorna också (M16).
  2. De "två kopiorna" kan bli en: `files/scripts/plasma-shell-overrides.sh` kan kopiera låsskärm och utloggning direkt ur look-and-feel-paketet i stället för ur en egen kopia, och de tre Chromium-policyfilerna kan skapas i bygget ur en. (Alternativt räcker kontrollen i P15.)
  3. Fem widgetar har var sin kopia av samma `lookCommand`-rad (`nowplaying/…/main.qml:60`, `dock/…/main.qml:52`, `quota/…/main.qml:121`, `updates/…/main.qml:159`, `deskclock/…/main.qml:47`, `metahint/…/main.qml:23`) – görs lämpligen samtidigt med P1.
  4. `files/scripts/example.sh` (BlueBuilds mall, används inte) och 14 oanvända småfunktioner (t.ex. `goblinai.py:2955` `receipt_text`, `:5791` `reserve_command`, `goblin-ai:1078`–`:1091` `sidePinned`, `share.py:1723` `service_active`) kan tas bort.
- **Vinst:** kortare filer att läsa (även för Claude – mindre kvot per session), färre ställen att glömma.
- **Säkerhet:** sett (flaggorna på båda datorerna – M16, kontrollsummorna, namnsökningen).
- **Risk:** låg. En engångsfix som tas bort för tidigt drabbar bara en dator som inte loggat in sedan oktober – finns ingen sådan.
- **Storlek:** liten.
- **Kan provas:** offscreen / låtsas-hemmapp.
- **Mät efteråt:** –
- **Byggt 12 nov (delvis):** (1) sju engångsfixar ur `goblincakes-refresh.sh` (335 → 213 rader): meta-launcher, ghostty-size-added, ghostty-smaller, dock-launchers-fixed, clock-weight, appgrid-smaller, goblincakes-dock – de lagade bara hemmappar från oktober; nya användare får samma värden ur look-and-feel-layouten (`fontWeight 600`, `org.goblincakes.dock`, AppGrid `iconSize 0`). Kvar (behövs även för nya användare eller är nya): aurorae-v2, meta-a-freed, meta-arrows-rotate, autoscroll, Discord-, VS Code-, AppImage-autostartfixarna. Provat: skriptet körs med låtsas-hemmapp före/efter – rc 0, inga kvarlämnade variabler, bara de sju flaggorna saknas. (2) inte gjort (användaren 12 nov: "låt bli") – kontrollen P15 håller kopiorna i takt. (3) inte gjort: de fem widgetarnas `lookCommand` + bevakning är fortfarande kopior (12 nov ändrade till bevakning) – en gemensam fil går inte att importera säkert i plasmoider. (4) `files/scripts/example.sh` bort; av de 14 oanvända funktionerna fanns bara fyra kvar – `code_blocks` (goblinai.py), `short_image` (fakepodman.py), `git_files` (tools/learn-src/bash.py), egenskapen `updateBusy` (goblincakes-config, används inte i QML) – borttagna; de andra med en enda förekomst är metoder Python själv anropar (`handle_data`, `redirect_request` …). Kurserna genererade om utan skillnad.

**Granskat utan anmärkning (område 4):** skalskripten har felhantering (`set -u`/`-e` + `pipefail`) utom `goblincakes-firstlogin` (se P21) och `goblincakes-steam-wait-libraries` (ska aldrig stoppa Steam); tjänsterna har `Restart=on-failure`; inställningar sparas genomgående med temporärfil + byte. De stora filerna (`ai/Main.qml` 7 768 rader, `goblinai.py` 7 122, `config/Main.qml` 4 454, `recorder/Main.qml` 3 984, `recorder.py` 3 692) vore lättare att arbeta i uppdelade, men det är en stor och riskabel omflyttning utan att användaren märker något – föreslås inte nu.

---

## Område 5 – Fel och risker

Det som hittades på vägen. Tre av punkterna gäller just Fedora-hopp – och ett sådant pågår nu (basen och legacy är på Fedora 45, `goblincakes-nvidia` på 44).

### P20 – AppGrid och libratbag byggs på Fedora 45 men läggs i Fedora 44-imagen
- **BYGGD 11 nov (Fable, användaren: ja).** `recipes/nvidia-stages.yml` (ny, bas `kinoite-nvidia:44`) + `common-stages.yml` (`kinoite-main:45`); stegen skriver vilken Fedora de byggdes på och `check-appgrid.sh` / nya `check-libratbag.sh` stoppar bygget om imagen är en annan; AppGrid laddas på riktigt med `QPluginLoader`, ratbagd startas. Provat här mot den installerade imagen och med låtsad skillnad 45/44. **Kvar:** första bygget på GitHub efter push är det riktiga provet (testlistan `fedora-las-rost.md`). Detaljer: grep "Fedora-låset" i anteckningarna.
- **Vad:** Byggstegen i `recipes/common-stages.yml:7` och `:16` byggs alltid på `kinoite-main:latest`, oavsett variant. Kommentaren säger "KDE and Qt are the same in both variants" – det stämmer inte under ett Fedora-hopp: i dag är `kinoite-main` Fedora 45 (kärna 7.3.3.fc45) och `kinoite-nvidia` Fedora 44 (sett med `skopeo`, M17). Användarens egen dator kör alltså AppGrid och ratbagd kompilerade på Fedora 45 i en Fedora 44-image. Just nu fungerar det (båda har Qt 6.11; ratbagd kräver högst GLIBC 2.38). Skyddet `files/scripts/check-appgrid.sh:16`–`:22` kollar bara med `ldd` att biblioteken finns – inte att Qt går med på att ladda ett tillägg byggt mot en nyare Qt (det vägrar Qt), och för libratbag finns ingen koll alls.
- **Förslag:** bygg stegen på samma bas som varianten (en egen stages-fil för Nvidia med `from: ghcr.io/ublue-os/kinoite-nvidia:latest`). Bonus: Nvidia-bygget slipper hämta en extra basimage (213 s, se P13). Och låt kollen ladda tillägget på riktigt (`QPluginLoader` via PySide6) + köra `ratbagd --version`.
- **Vinst:** ingen risk att toppfältet står utan programmeny eller att Piper slutar hitta musen på Nvidia-varianten den dag Fedora 45 får en nyare Qt/glibc än 44. Snabbare Nvidia-bygge.
- **Säkerhet:** sett – Fedora-versionerna (M17), byggloggen (`FROM ghcr.io/ublue-os/kinoite-main:latest` i steget för `goblincakes-nvidia`), `ldd`-kollen läst. Att Qt vägrar nyare tillägg: tror (Qt:s vanliga regel) – syns först när versionerna skiljer.
- **Risk:** låg (bygget blir rättare, inte annorlunda för bas/legacy).
- **Storlek:** liten.
- **Kan provas:** på GitHub (ett bygge av Nvidia-varianten) + menyn och Piper på användarens dator.
- **Mät efteråt:** M17 + `cat /usr/share/goblincakes/appgrid-build`.

### P21 – Första-inloggningen skriver "klart" även när den misslyckades
- **Vad:** `usr/libexec/goblincakes-firstlogin` saknar felkontroll: `plasma-apply-lookandfeel` (`:92`–`:93`) körs 3 s efter inloggning (`:59`), och oavsett om det gick skrivs `LAYOUT_VERSION` till klar-filen (`:165`). Samma sak för systemfältet (`trim_systray`, `:23`–`:30`: märket skrivs även om alla tio försök misslyckades). På en långsam dator (laptopen hade 7 min uppstart på hårddisken) hinner Plasma inte upp på 3 s → den nya layouten kommer aldrig, och inget syns i någon logg.
- **Förslag:** skriv märket bara när kommandot lyckades (annars nytt försök vid nästa inloggning), och vänta på att plasmashell svarar i stället för fasta 3 s.
- **Vinst:** en ny layoutversion når säkert fram även på en seg start.
- **Säkerhet:** sett (läst i koden). Att det faktiskt hänt: vet inte.
- **Risk:** låg–medel. Skrivs märket aldrig (ett fel som alltid ger felkod) byggs panelerna om vid **varje** inloggning – därför högst t.ex. tre försök.
- **Storlek:** liten.
- **Kan provas:** offscreen med låtsas-hemmapp + en riktig inloggning.
- **Mät efteråt:** –
- **Byggt 12 nov:** `goblincakes-firstlogin` väntar efter 3 s tills plasmashell svarar på `evaluateScript` (högst 2 min till); märket (`firstlogin-done`, `systray-done`) skrivs bara när `plasma-apply-lookandfeel` resp. systray.js lyckades; annars `<märke>.tries` ("version antal") och en rad i journalen ("… misslyckades (försök n av 3)"), nytt försök vid nästa inloggning, efter 3:e försöket skrivs märket ändå. Provat med attrapper och låtsas-hemmapp: lyckas, fyra misslyckanden i rad (ger upp efter 3), misslyckas–lyckas, Plasma svarar aldrig, gammal version i märket. Riktigt prov: nästa gång LAYOUT_VERSION höjs – `journalctl --user -b | grep firstlogin` ska vara tom och märket ha nya numret.

### P22 – Kakans röst slutar fungera när Fedora byter Python-version
- **BYGGD 11 nov (Fable, användaren: ja).** Tjänsten märker en miljö gjord för en annan Python och visar notisen "Kakans röst behöver lagas" med knappen Laga nu (inget hämtas utan knappen, ingen omstartsslinga); `goblin update` lagar också (steget Kakans röst). Provat i en tillfällig mapp med en låtsas-miljö för Python 3.13: upptäckt, riktig ombyggnad med pip, `goblin update --only voice`. **Kvar:** den riktiga notisen och ett riktigt Fedora-hopp (när Nvidia-varianten höjs till 45).
- **Vad:** Röstens Python-miljö (`~/.local/share/goblincakes-voice/venv`) pekar på systemets `/usr/bin/python3` men har sina paket i `lib/python3.14/` (sett). När en ny Fedora kommer med Python 3.15 hittar den inga paket. `installed()` (`usr/libexec/goblincakes-voice:186`–`:189`) tittar bara efter filerna, så tjänsten startar, kraschar och startas om var 10:e sekund (`Restart=on-failure`) – utan att något säger varför.
- **Förslag:** `installed()` kollar också att miljön hör till den Python som körs (`venv/lib/pythonX.Y` finns); annars bygger `goblin update`/tjänsten om miljön (modellerna ligger kvar, bara paketen hämtas om) eller säger till med en notis.
- **Vinst:** rösten överlever Fedora-hoppet på användarens dator (Nvidia-varianten går till 45 när Universal Blue släpper den).
- **Säkerhet:** sett – länken och `python3.14`-mappen på användarens dator; Fedora 45 har Python 3.15.2 (sett på laptopen, M18). Rösten slutar alltså fungera den dag `goblincakes-nvidia` går till Fedora 45, om inget görs.
- **Risk:** låg.
- **Storlek:** liten.
- **Kan provas:** offscreen (låtsas-miljö med fel versionsmapp).
- **Mät efteråt:** M18.

### P23 – Qt:s QML-cache används inte för fönstren i imagen
- **Vad:** Qt sparar normalt färdigkompilerad QML i `~/.cache/<program>/qmlcache`, men gör det inte för filer daterade 1970 – och det är alla filer i en atomisk image. Provat (M19): med datum 1970 skrivs ingen cachefil alls, med vanligt datum gör den det. Varje fönster kompilerar alltså sin QML från början vid varje start: Goblin AI 488 ms, GoblinRecorder 178 ms, Config 154 ms, dashboarden 126 ms – mot 19, 11, 7 och 8 ms med cache. (Ingen risk för gammal kod efter en uppdatering – det provades också: ändrat innehåll med samma storlek och datum gav rätt resultat.)
- **Förslag:** kräver en liten undersökning innan något byggs. Tänkbara vägar: (a) fönstren läser sin QML ur en kopia med riktiga datum som görs om när imagen bytts (samma kontrollsumma som `goblincakes-refresh.sh` redan räknar för temat); (b) Qt:s färdigkompilering vid bygget, om den går att få att gälla för 1970-daterade filer.
- **Vinst:** Goblin AI öppnas ca 0,5 s fortare hos användaren och ca 1 s fortare på laptopen (där: ai 989 ms, recorder 359, config 305, dashboard 252 ms – mätt); de andra fönstren 0,1–0,3 s.
- **Säkerhet:** sett/mätt (M19). Vilken lösning som fungerar: tror – måste provas.
- **Risk:** medel för (a) – en kopia som inte följer med imagen = gamla fönster efter en uppdatering; därför kontrollsumman.
- **Storlek:** medel.
- **Kan provas:** offscreen (M19 visar direkt om cachen används).
- **Mät efteråt:** M19.
- **Byggt 12 nov – väg (a):** Qt:s egna val hjälper inte (`QML_FORCE_DISK_CACHE=1`, `QML_DISK_CACHE=qmlc`: fortfarande 0 cachefiler med 1970-filer – provat). `usr/share/goblincakes/qmlcache.py` (`local(path)`): mapparna med QML (ai, amp, config, dashboard, graph, lagmeter, plasma-shell, qml, recorder, remove, share, voice – hittas själv) kopieras utan `.py` (43 filer, 1,9 MB) till `~/.cache/goblincakes/qml-src/<nyckel>/` med vanliga datum (`shutil.copyfile`); nyckeln = sha1 av sökväg + inode + storlek för varje fil (2,8 ms) – i ostree är en ändrad fil alltid ett nytt objekt = ny inode; andra nycklars kopior tas bort; kopian görs i `.new-*` och döps om (två fönster samtidigt går bra). Utanför `/usr/share/goblincakes` (repot) och vid alla fel: originalfilen. De tio fönstren (goblin-ai, -config, -recorder, -dashboard, -amp, -share, -graph, remove-apps, lagmeter, rösten) har `cached_qml()` som läser in `qmlcache.py` bredvid sin QML (parents[1]) – fel = som förut. Mätt med en kopia av imagens filer: ai 495 → 20 ms, config 156 → 10, recorder 180 → 13, dashboard 137 → 11, amp 63 → 7, share 38 → 8 ms (första starten efter en uppdatering: +17 ms för kopian). Provat: alla tio QML-filer kompilerar från kopian i en låtsas-image (1970-datum); ändrad fil → ny kopia, gamla borta; skrivskyddad cache → originalet. Inte provat: fönstren i imagen (imagen har inte modulen än) – testlista `p23-qmlcache.md`.

### P24 – Fedora-hoppet kommer av sig självt
- **BESLUTAT OCH BYGGT 11 nov (användaren: "Ja, lås", "från och med 45").** `image-version: 45` i `recipe.yml` och `recipe-nvidia-legacy.yml`, `44` i `recipe-nvidia.yml` (det användarens dator kör). Hur ett hopp görs står i CLAUDE.md (Beslut) och anteckningarna ("Fedora-låset"): Nvidia-varianten först, de andra när det är provat där.
- **Vad:** Alla tre recepten har `image-version: latest` (`recipes/recipe*.yml`), och uppdateringarna förbereds automatiskt (`AutomaticUpdates: stage`). När Universal Blue flyttar `latest` till nästa Fedora följer GOBLINCAKES med samma dag och nästa omstart startar i den – notisen (`goblincakes-fedora-check`) hinner i praktiken bara berätta det. Så gick det 9 nov: laptopen (legacy, Nvidia 580 – enligt `frugans-laptop.md` inte provad på Fedora 45) fick Fedora 45 förberett utan att någon valt det. Det är ett medvetet upplägg ("GOBLINCAKES' daily build follows"), och rollback finns – men den svagaste datorn blir först ut som provdator.
- **Förslag (användarens beslut):** lås recepten vid en Fedora-version (`image-version: 45`/`44`) och höj med flit när användaren provat på sin egen dator – de dagliga byggena fortsätter ge säkerhetsuppdateringar inom versionen. Eller behåll `latest` men låt legacy-varianten ligga ett steg efter.
- **Vinst:** inga överraskande Fedora-hopp på frugans dator; hoppet görs när det passar.
- **Säkerhet:** sett – recepten, `rpm-ostree status` (stage), anteckningen från 9 nov. Universal Blue har taggarna `43`, `44` och `45` för både `kinoite-main` och `kinoite-nvidia` (sett 11 nov med `skopeo list-tags`) – `kinoite-nvidia:45` finns alltså redan, så `latest` kan flytta dit vilken dag som helst.
- **Risk:** låg tekniskt; kostnaden är att någon måste komma ihåg att höja versionen (en påminnelse hos Kakan räcker).
- **Storlek:** liten.
- **Kan provas:** på GitHub (ett bygge).
- **Mät efteråt:** `rpm-ostree status` efter nästa uppdatering.

**Övrigt i område 5:** den döda processen under WoWUp står i P7.2, dashboardens enhet i P8, demoparser utan låst version i P14.1. Rollback: inget konkret fel hittat – `goblincakes-firstlogin` jämför layoutversionen med "inte lika med", så en äldre image lägger tillbaka sin layout och en nyare gör om den igen (syns som att panelerna byggs om, inget går sönder); engångsfixarna i hemmappen backas inte men de äldre imagerna tål dem. Nätverk: GoblinRecorders CS2-mottagare lyssnar bara lokalt (`127.0.0.1`), GoblinShare lyssnar med flit på hela nätverket – en egen säkerhetsgranskning (`/security-review`) har inte gjorts här.

---

## Prioriterad lista – mest värt först

Sorterad efter vinst delat med risk och storlek. "Märks" = vad användaren ser. Bocka av i första kolumnen när punkten är byggd och mätt.

| Klar | Nr | Punkt | Märks | Risk | Storlek |
|---|---|---|---|---|---|
| [x] | 1 | **P12** (byggd 12 nov, alla tre varianterna; nvidia ej mätt än) Uppdateringarna laddar ner 1,4–2,9 GB för ~120 MB nytt | uppdateringar på minuter i stället för en kvart på wifi | medel | liten + prov |
| [x] | 2 | **P1** (byggd 11 nov) Widgetarna startar skript varje sekund | 5 % av en kärna tillbaka, alltid, båda datorerna | låg | liten |
| [x] | 3 | **P2** (byggd 11 nov) GoblinRecorder-tjänstens `pgrep` och loggläsning | 2 % i vila, 1,4 % medan WoW kör (användarens dator) | låg–medel | liten |
| [x] | 4 | **P3** (byggd 11 nov) GoblinRecorder-fönstrets `flatpak info` | 1,4 % (användarens dator) | låg | liten |
| [x] | 5 | **P15** (byggd 11 nov) Kontroll före bygget | färre trasiga images, kopiorna kan inte glida isär | låg | liten |
| [x] | 6 | **P20** Byggstegen på rätt Fedora-bas (byggd 11 nov) | ingen trasig programmeny/Piper vid Fedora-hopp, snabbare Nvidia-bygge | låg | liten |
| [x] | 7 | **P22** Rösten och ny Python-version (byggd 11 nov) | rösten överlever Fedora 45 på användarens dator | låg | liten |
| [x] | 8 | **P18** (byggd 12 nov) Färdigkompilerade Python-filer | CS2-demon 1–1,5 s fortare, fönster 0,05 s fortare | låg | liten |
| [x] | 9 | **P5** (steg 1 byggd 12 nov) Spelletandet (steg 1: snabbare läsning) | 1–1,5 % av en kärna, båda datorerna | låg | liten |
| [x] | 10 | **P4** (byggd 11 nov) goblin graph-vaktens `pw-dump` | 1 % i vila, 2,2 % medan WoW kör + lugnare ljudserver (användarens dator) | låg | liten |
| [x] | 11 | **P10** (byggd 12 nov) Uppdateringskollen senare efter inloggning | lugnare första minut (7–9 s arbete flyttas) | låg | liten |
| [x] | 12 | **P9** (byggd 12 nov, (c) bara webbapp-ikonerna) Inloggningens hjälpprogram | 1–3 s mindre arbete vid inloggning | låg | liten |
| [x] | 13 | **P21** (byggd 12 nov) Första-inloggningen skriver "klart" vid fel | ny layout når säkert fram | låg–medel | liten |
| [x] | 14 | **P7** (byggd 12 nov, alla 6) Småsaker i bakgrunden (6 st) | några MB och uppvaknanden, renare processlista | låg | liten |
| [x] | 15 | **P24** Fedora-hoppet kommer av sig självt (låst 11 nov) | inga överraskande hopp på frugans dator (beslut) | låg | liten |
| [x] | 16 | **P11** (bara (a) byggd 12 nov; (b) struken – användaren: risken för stor för några sekunder) Nvidia-modulerna i tidig uppstart | renare logg (a); (b) hade gett 5–10 s | låg | liten |
| [x] | 17 | **P23** (byggd 12 nov, väg (a)) QML-cachen används inte | Goblin AI öppnas 0,5–1 s fortare | medel | medel |
| [x] | 18 | **P16** (byggd 12 nov) Kopierade QML-komponenter | lättare underhåll | låg–medel | liten–medel |
| [x] | 19 | **P14** (12 nov: 1 som efterkontroll, olåst; 2 behövs inte; 3 scx borttaget; 4) Småsaker i bygget | färre tysta fel, färre onödiga byggen | låg | liten |
| [x] | 20 | **P19** (12 nov: 1, 4; 2 struken; 3 kvar som kopior) Städning | kortare filer, mindre att läsa | låg | liten |
| [ ] | 21 | **P5** steg 2: en del letar spel, resten läser | ytterligare ~0,5 % | medel | medel |
| [ ] | 22 | **P13** AppGrid/libratbag i eget flöde | bygget 3 min kortare (delvis löst av P20) | medel | medel |
| [ ] | 23 | **P8** Program från dashboarden i egen enhet | rätt siffror per program | låg | liten |
| [ ] | 24 | **P17** Gemensam startkod för fönstren | lättare underhåll | medel | medel |
| [ ] | 25 | **P6** Fönster som ligger kvar i minnet | behövs inte med 16 GB | låg–medel | liten |

## Topp 5 – börja här

1. **P1 – widgetarna.** Störst vinst för minst risk, och den enda som märks på båda datorerna hela tiden. En widget i taget (Spelas nu först); M2 och M5 visar direkt om det hjälpte.
2. **P12 – uppdateringarnas storlek.** Det användaren (och frugan på wifi) märker mest: 1,4–2,9 GB per uppdatering blir några hundra MB. Prova på legacy- eller basvarianten först, mät med M12, ta sedan Nvidia-varianten. Hög effekt men rör bygget – låt Fable bygga eller granska.
3. **P2 + P3 – GoblinRecorder** (samma session). 3,5 % av en kärna i vila på användarens dator och 3,1 % medan WoW kör (mätt). Litet och provbart med attrapperna.
4. **P15 – kontrollen före bygget.** Gör alla punkter efter den säkrare att bygga (syntax, QML, kopior) och kostar en halvtimme.
5. **P20 + P22 – före nästa Fedora-hopp.** `goblincakes-nvidia` går till Fedora 45 när Universal Blue släpper den; innan dess bör byggstegen byggas på rätt bas och rösten klara ny Python. Båda är små.

Därefter i tur: P18, P5 (steg 1), P4, P10, P9 – alla små och ofarliga. **P11** (uppstarten) ger mest på laptopen (12,5 s) men är den enda med hög risk: gör M14 först och prova på användarens dator. **P24** är ett beslut, inte ett bygge.

**"Före"-värdena under spel är mätta** (11 nov, WoW på användarens dator – se M2, M4, M5, M9). Efter spelmätningen är **P4** värd att ta tidigare än plats 10: graph-vakten drar mer under spel (2,2 %) än i vila, och lagningen är liten. Laptopen har inget spel installerat än.

---

## Mätningar

Kommandona kan köras igen precis som de står – i en terminal på datorn, eller från användarens dator med `ssh victoria '<kommandot>'` medan GoblinShare-terminalen till laptopen är öppen (aliaset heter `victoria`, se `~/.ssh/goblinshare.conf`). Varje block är ett enda kommando – klistra in hela. Rader med `sshd`, `bash -s` och GoblinShares hjälpsession räknas bort.

**När det mättes:** användarens dator 11 nov 17:10–17:35, 15–40 min efter inloggning, inget spel, upplägget Dashboard. Laptopen 11 nov 17:39–17:45 via GoblinShare (uppkopplingen var redan öppen), 38 min efter start, inget spel, upplägget Standard.

**Under spel:** mätt på användarens dator 11 nov 18:28 med WoW igång (inloggad på en karaktär, ingen strid, ingen stridslogg, OBS igång utan inspelning) – M2, M4, M5, M9. **Kvar att mäta:** samma under en riktig strid med inspelning (raid/nyckel) om P2 ska bedömas fullt ut, och på laptopen när den har ett spel (bara Tux Paint 11 nov). M10 i sin helhet och M14 på laptopen (M10 kör inloggningens hjälpprogram på riktigt, M14 kräver lösenord – görs när hon är med).

**Anmärkning (ärligt):** första versionen av M15 startade `goblin-ai --help` över ssh utan skärm. Qt avbröt då programmet, och det ligger nu tre kraschposter (python3.15, SIGABRT, 17:41) i laptopens `coredumpctl` – ofarliga och rensas av sig själva, men Katsuyos efterkontroll kan nämna dem. M15 är ändrad så att den inte startar något fönsterprogram.

### M1 – CPU-tid och minne per tjänst sedan inloggningen
```
now=$(awk '{print $1}' /proc/uptime); for u in $(systemctl --user list-units --type=service,scope --state=running --no-legend --plain | awk '{print $1}'); do eval "$(systemctl --user show "$u" -p CPUUsageNSec -p MemoryCurrent -p ActiveEnterTimestampMonotonic | sed 's/^/v_/')"; case "$v_CPUUsageNSec" in ''|*[!0-9]*) continue;; esac; case "$v_MemoryCurrent" in ''|*[!0-9]*) v_MemoryCurrent=0;; esac; awk -v u="$u" -v c="$v_CPUUsageNSec" -v m="$v_MemoryCurrent" -v a="$v_ActiveEnterTimestampMonotonic" -v now="$now" 'BEGIN{age=now-a/1e6; if(age<1)age=1; printf "%6.2f%%  %7.1fs cpu  %6.0f MB  %6.0fs  %s\n", c/1e9/age*100, c/1e9, m/1048576, age, u}'; done | sort -rn | head -40
```
- **Användarens dator, 16 min efter inloggning, inget spel:** dashboard-enheten (med Goblin AI + Claude Code i den) 12,2 % / 2 976 MB · plasmashell 7,75 % · kwin 5,8 % · `goblincakes-ollama` 2,68 % · `goblincakes-recorder` 2,01 % · recorder-fönstret 1,60 % · `goblincakes-graph` 1,13 % · `goblincakes-gameguard` 0,77 % · `goblincakes-voice` 0,37 % (1 007 MB med filcache) · share 0,13 % · kakan-vakt 0,11 % · archon-tray 0,10 % · notifications 0,03 %.

### M2 – CPU per tjänst under 60 s (stadigt läge) – **huvudmätningen**
```
S=60; snap() { for u in $(systemctl --user list-units --type=service,scope --state=running --no-legend --plain | awk '{print $1}'); do c=$(systemctl --user show "$u" -p CPUUsageNSec --value); case "$c" in ''|*[!0-9]*) continue;; esac; echo "$u $c"; done; }; a=$(snap); sleep $S; b=$(snap); awk -v S=$S 'NR==FNR{a[$1]=$2; next} ($1 in a){d=($2-a[$1])/1e9; if(d>0.005) printf "%6.2f%%  %6.2fs  %s\n", d/S*100, d, $1}' <(echo "$a") <(echo "$b") | sort -rn | head -30
```
- **Användarens dator, i vila efter inloggning (11 nov 17:15):** plasmashell-enheten 7,73 % · `goblincakes-recorder.service` 2,11 % · `app-goblin-recorder@autostart` 1,44 % · `goblincakes-ollama.service` 1,19 % · `goblincakes-graph.service` 1,15 % · `goblincakes-gameguard.service` 0,78 % · share 0,13 % · kakan-vakt 0,09 % · voice 0,08 % · archon-tray 0,07 %. (Annat: dashboard-enheten 18,7 % = Goblin AI med Claude Code som arbetade, Firefox 10,5 %, kwin 8,4 %, Discord 6,5 + 3,0 %.)
- **Användarens dator medan WoW kör (11 nov 18:28, inloggad på en karaktär, ingen strid och ingen stridslogg, OBS igång men spelar inte in, 535 processer):** WoW 273 % · plasmashell-enheten 9,17 % · `goblincakes-graph.service` 2,19 % · `app-goblin-recorder@autostart` 1,70 % · `goblincakes-recorder.service` 1,40 % · `goblincakes-ollama.service` 1,30 % (Ollama är stoppad – det är bara vakten som letar) · `goblincakes-gameguard.service` 0,96 % · share 0,14 % · voice 0,10 % · kakan-vakt 0,09 % · archon-tray 0,09 %. GOBLINCAKES egna delar tillsammans ca 17 % av en kärna. (Annat: kwin 16,4 %, OBS 10,3 %, Discord 9,6 + 5,4 %, pipewire-pulse 1,5 %, pipewire 1,3 %, dashboard-enheten 13,6 % = Goblin AI med Claude Code.)
- **Frugans laptop (11 nov 17:40, 38 min efter start, i vila, inget spel, upplägget Standard, Fedora 45):** plasmashell-enheten 6,12 % · `goblincakes-ollama.service` 1,71 % · `goblincakes-gameguard.service` 0,94 % · `goblincakes-share.service` 0,57 % (hjälpsessionen var öppen) · `goblincakes-archon-tray.service` 0,36 % (Archon finns inte på datorn) · kakan-vakt 0,08 %. Recorder, graph och rösten är inte påslagna där.
- **Frugans laptop under spel:** ej mätt än (se "Kvar att mäta" överst i Mätningar).
- **Efter P2 + P3, användarens dator i vila (11 nov 19:05, repots tjänst och fönster):** recorder-tjänsten 1,90 → 0,20 % · fönstret 1,38 → 0,46 % (öppet på skärmen; förut gömt).
- **Efter P4, användarens dator i vila (11 nov kväll, repots vakt, ingen musik):** graph-vakten 1,15 → 0,44 %. Under spel tittar den inte alls (väntat ~0 %; ej mätt med WoW än).

### M3 – Verkligt minne (PSS) per GOBLINCAKES-process
```
for p in $(pgrep -u "$(id -u)" -f 'goblin|ollama|reminders.py'); do pss=$(awk '/^Pss:/{print $2}' /proc/$p/smaps_rollup 2>/dev/null); [ -n "$pss" ] && printf "%6d MB  %s\n" $((pss/1024)) "$(tr '\0' ' ' < /proc/$p/cmdline | cut -c1-90)"; done | grep -v 'sshd\|pgrep' | sort -rn | head -25
```
- **Användarens dator, i vila:** goblin-ai 356 · röstens worker 348 · goblin-dashboard (gömd) 221 · goblin-recorder (fönstret) 185 · goblin-share (fönstret) 146 · ollama serve 37 · recorder-tjänsten 31 · archon-tray 30 · voice listen 25 · share-tjänsten 23 · kakan-vakt 21 · notifications 18 · graph-vakten 15 · ollama-vakten 13 · gameguard 7 · fedora-check 6 MB.
- **Frugans laptop (11 nov 17:40, 38 min efter start, i vila, inget spel, upplägget Standard, Fedora 45):** goblin-share (fönstret) 102 MB · ollama serve 34 · archon-tray 33 · share-tjänsten 20 · kakan-vakt 19 · notifications 18 · ollama-vakten 13 · gameguard 7 · fedora-check 6 MB. Inget minnesproblem (M9).

### M4 – Nya processer på 30 s (hur ofta något startas)
```
a=$(awk '/^processes/{print $2}' /proc/stat); sleep 30; b=$(awk '/^processes/{print $2}' /proc/stat); echo "nya processer/30 s: $((b-a))"
```
- **Användarens dator, i vila:** 483 (ca 16 per sekund; Claude Codes egna kommandon ingår med några tiotal).
- **Användarens dator medan WoW kör:** 958 på 60 s (ca 16 per sekund – lika många som i vila).
- **Frugans laptop (11 nov 17:40, 38 min efter start, i vila, inget spel, upplägget Standard, Fedora 45):** 333 på 60 s (ca 5,5 per sekund).

### M5 – plasmashell själv mot skripten den startar (30 s)
```
p=$(pgrep -x plasmashell); cpu() { awk '{print $14+$15}' /proc/$p/stat; }; cg() { systemctl --user show plasma-plasmashell.service -p CPUUsageNSec --value; }; a=$(cpu); ca=$(cg); sleep 30; b=$(cpu); cb=$(cg); echo "plasmashell själv: $(awk -v d=$((b-a)) 'BEGIN{printf "%.1f", d/30}') %  hela enheten med skripten: $(awk -v d=$((cb-ca)) 'BEGIN{printf "%.1f", d/1e9/30*100}') %"
```
- **Användarens dator, i vila:** plasmashell själv 0,2 % · hela enheten 7,6 %.
- **Efter P1, användarens dator i vila (11 nov 18:58, testkopia av widgetarna, upplägget Dashboard, Discord + Steam igång, Discord-hjälparen ännu den gamla):** före 7,4 % (mätt 18:52) → efter 5,5 %. Väntat efter nästa image (snabbare Discord-hjälpare): ca 4 %.
- **Användarens dator medan WoW kör:** plasmashell själv 0,3 % · hela enheten 9,1 %.
- **Frugans laptop (11 nov 17:40, 38 min efter start, i vila, inget spel, upplägget Standard, Fedora 45):** plasmashell själv 0,4 % · hela enheten 6,6 %.

### M6 – Vad ett varv av varje hämtning kostar
```
t() { n=$1; shift; s=$(date +%s%N); for i in $(seq $n); do sh -c "$*" >/dev/null 2>&1; done; e=$(date +%s%N); echo "$(( (e-s)/n/1000000 )) ms  $*" | cut -c1-110; }; t 10 /usr/libexec/goblincakes-ai-activity; t 10 /usr/libexec/goblincakes-discord-voice; t 5 'pgrep -x steam >/dev/null && /usr/libexec/goblincakes-steam-activity || echo {}'; t 5 /usr/libexec/goblincakes-device-battery; t 10 'wpctl get-volume @DEFAULT_AUDIO_SINK@'; t 5 'nmcli -t -f TYPE,STATE,CONNECTION device status'; t 5 pw-dump; t 5 'pgrep -x obs'; t 5 'flatpak info com.obsproject.Studio'; t 5 '/usr/libexec/goblincakes-quota --cached'; t 10 'python3 -c pass'; ls /proc | grep -c '^[0-9]'
```
- **Användarens dator:** ai-activity 19 ms · discord-voice 37 · steam 67 · device-battery 31 · wpctl 8 · nmcli 8 · pw-dump 13 · pgrep 25 · flatpak info 13 · quota --cached 42 · tom Python 9 ms · 519 processer.
- **Frugans laptop (11 nov 17:40, 38 min efter start, i vila, inget spel, upplägget Standard, Fedora 45):** ai-activity 26 ms · discord-voice 48 · steam 18 (Steam inte igång) · **device-battery 1 580 ms** (väntar 0,5 s på varje Logitech-enhet som inte svarar; bara 41 ms processortid) · wpctl 20 · nmcli 18 · pw-dump 20 · pgrep 18 · flatpak info 21 · quota --cached 59 · tom Python 15 ms · 295 processer.

### M7 – Vad som är påslaget (förklarar skillnader mellan datorerna)
```
ls ~/.config/goblincakes/; cat ~/.config/goblincakes/utseende 2>/dev/null; ls ~/.config/autostart/; grep -c 'plugin=org.goblincakes' ~/.config/plasma-org.kde.plasma.desktop-appletsrc; grep 'plugin=org.goblincakes' ~/.config/plasma-org.kde.plasma.desktop-appletsrc | sort | uniq -c
```
- **Användarens dator:** graph-auto, recorder-on, share-on, vencord-on, ollama.json, utseende = levande; autostart: Archon, WoWUp, Discord, goblin-recorder, Raider.IO, Steam; widgetar: nowplaying × 2, deskclock, metahint (upplägget Dashboard).
- **Frugans laptop (11 nov 17:40, 38 min efter start, i vila, inget spel, upplägget Standard, Fedora 45):** accent, mouse-flat, ollama.json, share-on, steam-dgpu, utseende = levande; ingen egen autostart; widgetar: dock, nowplaying × 1, quota, updates, week (upplägget Standard). Inte påslaget: recorder, graph-auto, rösten, vencord.

### M8 – Spelletandet (ett varv)
```
python3 -c "
import sys,time; sys.path.insert(0,'/usr/share/goblincakes'); import gaming
def t(f,n=20):
    s=time.perf_counter(); [f() for _ in range(n)]; return (time.perf_counter()-s)/n*1000
print('game_running: %.1f ms   processes+find_game: %.1f ms' % (t(gaming.game_running), t(lambda: gaming.find_game(gaming.processes()))))"
```
- **Användarens dator:** game_running 11,2 ms · processes + find_game 23,1 ms (samma sak med `os.listdir` + `open`: 5,3 ms – provat i ett löst skript).
- **Användarens dator efter P5 steg 1 (12 nov, repots fil):** game_running 4,7 ms · processes + find_game 10,2 ms (före samma stund: 10,4 · 21,8).
- **Frugans laptop (11 nov 17:40, 38 min efter start, i vila, inget spel, upplägget Standard, Fedora 45):** game_running 8,4 ms · processes + find_game 16,4 ms (295 processer mot 519 på användarens dator).

### M9 – Minne och växling
```
free -m | sed -n 1,3p; grep -E 'pswpin|pswpout' /proc/vmstat; nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader
```
- **Användarens dator, i vila:** 9 774 av 32 005 MB använt, växling 0 av 8 191 MB, grafikminne 1 237 av 12 288 MiB.
- **Användarens dator medan WoW kör:** 17 265 av 32 005 MB använt, växling 0 av 8 191 MB (pswpin 103, pswpout 347 sedan start), grafikminne 5 476 av 12 288 MiB.
- **Frugans laptop (11 nov 17:40, 38 min efter start, i vila, inget spel, upplägget Standard, Fedora 45):** 2 358 av 15 866 MB använt, växling 0, grafikminne 2 av 4 096 MiB, 32 °C.

### M10 – Inloggningens hjälpprogram, ett i taget (alla är gjorda för att köras om)
```
t() { s=$(date +%s%N); "$@" >/dev/null 2>&1; e=$(date +%s%N); echo "$(( (e-s)/1000000 )) ms  $*" | cut -c1-120; }; cd /tmp; t goblincakes-config --first-run; t /usr/libexec/goblincakes-gpu hw; t /usr/libexec/goblincakes-gpu notify; t /usr/libexec/goblincakes-wow-links; t /usr/libexec/goblincakes-season apply; t /usr/libexec/goblincakes-tweak apply calendar; t /usr/libexec/goblincakes-tweak apply mouse-flat; t /usr/libexec/goblincakes-laptop; t /usr/libexec/goblincakes-desktop-layout login; t /usr/libexec/goblincakes-automount; t /usr/libexec/goblincakes-webapp-icon --upgrade; t python3 -c "from PySide6.QtWidgets import QApplication"
```
- **Användarens dator (varm disk):** config --first-run 134 ms · gpu hw 38 · gpu notify 248 · wow-links 274 · season 27 · calendar 16 · mouse-flat 122 · laptop 141 · desktop-layout login 74 · automount 62 · webapp-icon 329 · Qt-import 97 ms.
- **Frugans laptop (11 nov 17:40, 38 min efter start, i vila, inget spel, upplägget Standard, Fedora 45):** (bara de tre som inte ändrar något kördes) config --first-run 185 ms · gpu hw 61 · Qt-import 124 ms.

### M11 – Uppstarten
```
systemd-analyze; systemd-analyze blame --no-pager | grep -v '\.device$' | head -12; systemd-analyze --user; systemd-analyze --user blame --no-pager | head -15; journalctl -b -o short-monotonic -u dracut-pre-udev --no-pager | tail -4
```
- **Användarens dator (start 11 nov 16:57):** 11,3 s firmware + 10,7 s startmeny + 3,1 s kärna + 8,1 s initrd + 9,8 s resten = 43,0 s. Längst: `dracut-pre-udev` 6,1 s (Nvidia-modulerna, slutar med `nvidia_peermem`-felet) · `NetworkManager-wait-online` 5,2 s · `fedora-atomic-desktop-appstream-cache-refresh` 4,4 s (ny image i dag) · `bootc-update-ca-trust` 1,5 s. Användarsessionen: 8,7 s; `goblincakes-updates.service` 7,1 s · `podman-user-wait-network-online` 4,5 s (Ianseo) · `plasma-kded6` 3,3 s · `plasma-startupsound` 2,2 s · `goblincakes-disk-owner` 2,0 s (väntar med flit).
- **Frugans laptop (11 nov 17:40, 38 min efter start, i vila, inget spel, upplägget Standard, Fedora 45):** 7,6 s firmware + **16,0 s startmeny** + 1,4 s kärna + **14,5 s initrd** + 17,1 s resten = 56,6 s. Längst: **`dracut-pre-udev` 12,5 s** (11,9 s processortid – Nvidia-modulerna) · `NetworkManager-wait-online` 5,5 s · appstream-cache 4,7 s · `ldconfig` 3,6 s · `system-flatpak-setup` 2,3 s · `bootc-update-ca-trust` 2,1 s · `nvidia-cdi-refresh` 1,8 s. Användarsessionen: `goblincakes-updates.service` 9,3 s · `plasma-kded6` 2,6 s · `plasma-plasmashell` 2,5 s · startljudet 2,3 s · `goblincakes-disk-owner` 2,2 s. initramfs: 400 MB.

### M12 – Hur mycket en uppdatering laddar ner (lager som skiljer mellan två byggen)
Kräver bara `skopeo` och nätverk. Byt variant i `IMG` vid behov. `OLD` = digesten för det bygge datorn kör (`rpm-ostree status | grep Digest | head -1`).
```
IMG=ghcr.io/kaytho-git/goblincakes-nvidia; OLD=$(rpm-ostree status | awk '/Digest:/{print $2; exit}'); skopeo inspect docker://$IMG:latest > /tmp/ny.json; skopeo inspect docker://$IMG@$OLD > /tmp/gammal.json; python3 -c "
import json
n=[(l['Digest'],l['Size']) for l in json.load(open('/tmp/ny.json'))['LayersData']]; o={l['Digest'] for l in json.load(open('/tmp/gammal.json'))['LayersData']}
ny=[s for d,s in n if d not in o]
print('lager: %d, hela imagen %.2f GB, nya lager mot det du kör: %d = %.2f GB att ladda ner' % (len(n), sum(s for _,s in n)/1e9, len(ny), sum(ny)/1e9))"
```
- **11 nov (bygget 16:12 mot bygget 13:17, bara fönsterramarna ändrade):** 288 lager, 6,45 GB; 28 nya lager = 1,35 GB att ladda ner. Basen (259 lager, 5,10 GB) delades helt.
- **12 nov, basvarianten `goblincakes` (taggarna `<commit>-45`):** före chunkah 5f5c0ff mot c937a37: 289 lager, 5,49 GB, 29 nya = **2,07 GB**. Första chunkah-bygget 47c86f5: 128 lager, 4,13 GB, allt nytt (väntat, engångs). **Chunkah mot chunkah, da1a54b mot 47c86f5** (ändrat: bara tools/check.py + build.yml, inget i imagen): 7 nya lager = **0,55 GB** (−73 %); största 258, 97, 76, 48, 40, 22, 8 MB – troligen demoparser/initramfs/rpm-databasen (se P12). Hela imagen 5,49 → 4,13 GB.
- **12 nov, `goblincakes-nvidia-legacy` (frugans laptop, taggarna `<commit>-45`):** före chunkah 8f79eaa mot da1a54b: 290 lager, 6,36 GB, 29 nya = **2,12 GB**. Chunkah mot chunkah: 9ff9a37 mot 3a86abc (6 filer ändrade) 7 nya lager = **0,75 GB** (−65 %); 3a86abc mot 4ead22c (2 filer i repot, men troligen nya paket i Universal Blues bas samma dygn) 20 nya = **1,21 GB**. Största lagret 422 MB kommer med varje gång (troligen Nvidia 580-modulerna/initramfs – samma sorts lager som 258 MB på basen). Hela imagen 6,36 → 4,98 GB.
- **12 nov: chunkah på för `goblincakes-nvidia` också** (användaren: ja) – alla tre varianterna har den nu. Kolla efter första bygget: skopeo-kollen (128 lager, etiketterna) + diskutrymmet; efter andra bygget M12; ISO-bygget på söndag är första Nvidia-ISO:n från en chunkah-image.
- **13 nov: nvidia, första chunkah-bygget (bd05f5c, 12 nov) kollat:** 128 lager, 4,99 GB (före 6,45), etiketterna version/source/created, `ostree.linux` (7.2.15-200.fc44), `containers.bootc` kvar, `ostree.commit`/`ostree.final-diffid` borta; 88 GB ledigt vid start, inget "no space left"; byggtiden 16,4 min. Kvar: M12 mot nästa bygge (c563963).

### M13 – Vad uppdateringarna faktiskt hämtade (systemloggen)
```
journalctl -u rpm-ostreed --since "7 days ago" --no-pager | grep -E "layers needed|New objects" | tail -8
```
- **Användarens dator:** 10 nov 21:51 `layers needed: 27 (1,3 GB)` → `New objects … totaling 116,7 MB` · 11 nov 16:52 `layers needed: 28 (1,4 GB)` → `totaling 116,7 MB`.
- **Frugans laptop (11 nov 17:40, 38 min efter start, i vila, inget spel, upplägget Standard, Fedora 45):** 10 nov 08:42 `custom layers needed: 29 (2,9 GB)` + `ostree chunk layers needed: 44 (579 MB)` = 3,5 GB → `New objects … totaling 119 MB` · 11 nov 16:51 `layers needed: 129 (4,0 GB)`. Legacy-variantens egna lager är alltså 2,9 GB (Nvidia-drivrutinen ligger i dem).

### M14 – Vad som tar plats i initramfs (kräver lösenord)
```
sudo lsinitrd -s /usr/lib/modules/$(uname -r)/initramfs.img | sort -k5 -n -r | head -25; ls -la /boot/ostree/*/initramfs*
```
- **Användarens dator:** filen är 309 MB (sett); innehållet ej läst (kräver sudo).

### M15 – Starttid med och utan färdigkompilerade Python-filer
```
C=$(mktemp -d); t() { s=$(date +%s%N); "$@" >/dev/null 2>&1; e=$(date +%s%N); echo "$(( (e-s)/1000000 )) ms"; }; cd /tmp; D='import sys; sys.path.insert(0,"/usr/lib/goblincakes/demoparser"); import pandas, polars, demoparser2'; a=$(t python3 -c "$D"); PYTHONPYCACHEPREFIX=$C python3 -c "$D"; echo "demoparser: som imagen är $a, med .pyc $(PYTHONPYCACHEPREFIX=$C t python3 -c "$D")"; I='import sys; sys.path[:0]=["/usr/share/goblincakes/ai","/usr/share/goblincakes"]; import goblinai'; a=$(t python3 -c "$I"); PYTHONPYCACHEPREFIX=$C python3 -c "$I"; echo "import goblinai: som imagen är $a, med .pyc $(PYTHONPYCACHEPREFIX=$C t python3 -c "$I")"; for prog in "/usr/libexec/goblincakes-recorder status" "/usr/libexec/goblincakes-share status"; do a=$(t $prog); PYTHONPYCACHEPREFIX=$C $prog >/dev/null 2>&1; echo "$prog: som imagen är $a, med .pyc $(PYTHONPYCACHEPREFIX=$C t $prog)"; done; rm -rf "$C"
```
- **Användarens dator:** demoparser 1 321–2 013 ms → 398 ms · `goblin-ai --help` 418 → 356 ms · `goblincakes-recorder status` 117 → 73 ms · `goblincakes-share status` 86 → 66 ms.
- **Frugans laptop (11 nov 17:40, 38 min efter start, i vila, inget spel, upplägget Standard, Fedora 45):** `goblincakes-recorder status` 184 → 110 ms · `goblincakes-share status` 132 → 90 ms. (`goblin-ai --help` gick inte över ssh utan skärm – se anmärkningen överst i Mätningar; kommandot ovan är ändrat så att det inte händer igen.)

### M16 – Vilka engångsfixar datorn redan har
```
ls ~/.local/state/goblincakes/
```
- **Användarens dator:** alla tolv flaggorna finns (aurorae-v2, meta-a-freed, meta-arrows-rotate, meta-launcher, ghostty-size-added, ghostty-smaller, dock-launchers-fixed, clock-weight, appgrid-smaller, goblincakes-dock, discord-native, vscode-home).
- **Frugans laptop (11 nov 17:40, 38 min efter start, i vila, inget spel, upplägget Standard, Fedora 45):** samma flaggor som användarens dator utom `aurorae-v2` och `meta-freed` (aurorae-v2 skrivs vid nästa inloggning med nya imagen).

### M17 – Vilken Fedora baserna är på (byggstegen byggs på kinoite-main)
```
for i in kinoite-main kinoite-nvidia; do skopeo inspect --no-tags docker://ghcr.io/ublue-os/$i:latest | python3 -c 'import json,sys; l=json.load(sys.stdin)["Labels"]; print(sys.argv[1], l.get("org.opencontainers.image.version"), l.get("ostree.linux"))' $i; done
```
- **11 nov:** kinoite-main 45.20261111.2 (kärna 7.3.3-300.fc45) · kinoite-nvidia 44.20261107.1 (kärna 7.2.15-200.fc44).

### M18 – Python-versionen och röstens miljö
```
python3 --version; ls ~/.local/share/goblincakes-voice/venv/lib/ 2>/dev/null; systemctl --user is-active goblincakes-voice
```
- **Användarens dator (Fedora 44):** Python 3.14.10 · `python3.14` · rösten kördes från repot under provet (tjänsten stoppad).
- **Frugans laptop (11 nov 17:40, 38 min efter start, i vila, inget spel, upplägget Standard, Fedora 45):** Python **3.15.2** · rösten är inte installerad.

### M19 – Används QML-cachen? (tid att kompilera fönstrens QML)
```
D=$(mktemp -d); cat > $D/t.py <<'EOF'
import sys, time
from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlEngine, QQmlComponent
app = QGuiApplication(sys.argv); app.setApplicationName("qmlcachetest")
for f in sys.argv[1:]:
    e = QQmlEngine(); t = time.perf_counter(); c = QQmlComponent(e, QUrl.fromLocalFile(f))
    print("%5.0f ms  %s" % ((time.perf_counter()-t)*1000, "/".join(f.split("/")[-2:])))
EOF
F="ai config recorder dashboard amp share"; export QT_QPA_PLATFORM=offscreen XDG_CACHE_HOME=$D/cache; echo "som imagen är:"; python3 $D/t.py $(for f in $F; do echo /usr/share/goblincakes/$f/Main.qml; done) 2>/dev/null; python3 $D/t.py $(for f in $F; do echo /usr/share/goblincakes/$f/Main.qml; done) >/dev/null 2>&1; echo "cachefiler efter två körningar: $(find $D/cache -type f 2>/dev/null | wc -l) (0 = cachen används inte)"; rm -rf $D
```
- **Användarens dator:** ai 488 ms · config 154 · recorder 178 · dashboard 126 · amp 55 · share 39 ms; cachefiler: 0. (Samma filer kopierade med vanligt datum, andra körningen: 19 · 7 · 11 · 8 · 5 · 7 ms.)
- **Frugans laptop (11 nov 17:40, 38 min efter start, i vila, inget spel, upplägget Standard, Fedora 45):** ai 989 ms · config 305 · recorder 359 · dashboard 252 · amp 121 · share 78 ms; cachefiler: 0.
