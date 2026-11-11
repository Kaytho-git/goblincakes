# Optimeringsgranskning av GOBLINCAKES

Gjord av Fable 11 nov 2026 enligt `docs/optimering/startinstruktion.md` del 1. Ingen kod är ändrad – bara läst och mätt.

## Läget (för en ny session som fortsätter)
- [x] Område 1 – Prestanda i bakgrunden (punkt 1–8)
- [x] Område 2 – Uppstart och inloggning (punkt 9–11)
- [x] Område 3 – Image och bygge (punkt 12–14)
- [x] Område 4 – Kodkvalitet och underhåll (punkt 15–19)
- [x] Område 5 – Fel och risker (punkt 20–24)
- [x] Mätningar på frugans laptop i vila (11 nov, via GoblinShare)
- [ ] Mätningar under spel på båda datorerna (M2, M4, M9 – användaren säger till när spelet är igång)
- [x] Sortering + topp 5 (står före Mätningar)

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

Allt detta fortsätter medan ett spel kör (utom lokal AI, som stängs av). Det är ingen katastrof – en tiondels kärna av laptopens fyra – men det är onödigt, det väcker processorn 5–16 gånger i sekunden (M4) och det drar batteri. Hur det ser ut **under spel** är inte mätt än.

### P1 – Widgetarna startar skript varje sekund
- **Vad:** Toppfältets/skrivbordsradens widgetar hämtar sina uppgifter genom att starta program med jämna mellanrum. Spelas nu: Goblin AI-läget varje sekund, Discord-röst var 1–3 s, Steam var 5 s, batteri var 30 s, utseendet var 5 s (`plasmoids/org.goblincakes.nowplaying/contents/ui/main.qml:288`, `:297`, `:306`, `:315`, `:350`). Klockan: volym varannan sekund, nätverk var 10 s, batteri var 30 s, utseendet var 5 s (`org.goblincakes.deskclock/contents/ui/main.qml:132`–`:160`). Dockan, kvoten, uppdateringspilen och Meta-tipset läser utseendet var 5:e s var för sig (`dock/…/main.qml:69`, `quota/…/main.qml:138`, `updates/…/main.qml:103` + `:176`, `metahint/…/main.qml:40`). I upplägget Dashboard finns Spelas nu **två gånger** (vänster och höger del) och båda kör alla hämtningar, även dem som bara den andra delen visar. Inget saktar ner när ett spel kör, fast widgetarna redan vet om det (`gaming`).
- **Förslag:** (a) starta inte Python när det inte finns något att läsa – ett litet skalvillkor först (AI-mappen tom → `{}`, Discord inte igång → färdigt svar); (b) varje del kör bara sina egna hämtningar (`part` = left/right); (c) under spel 3–5 gånger glesare; (d) batteriet hämtas av en widget, inte två.
- **Vinst:** ca 6–7 % av en kärna → uppskattat 1–2 %, på båda datorerna. Färre uppvaknanden (bättre batteritid på laptopen), lugnare under spel.
- **Säkerhet:** sett/mätt på båda datorerna – användarens: `plasma-plasmashell.service` 7,6 % i vila varav plasmashell själv 0,2 %; laptopen: 6,6 % varav 0,4 % (M2 + M5). Ett varv kostar (användarens dator / laptopen): AI-läget 19 / 26 ms, Discord-röst 37 / 48 ms, Steam 67 / 18 ms, kvoten 42 / 59 ms, batteri 31 / 1 580 ms (M6).
- **Risk:** låg. Det som kan gå fel: en ruta (Discord-kanalen, Kakans "tänker") dyker upp någon sekund senare, eller inte alls om villkoret skrivs fel.
- **Storlek:** liten för (a)–(c), en widget i taget.
- **Kan provas:** bara på riktiga datorn (Plasma-widgetar); själva kommandona kan provas i ett skal.
- **Mät efteråt:** M2 (raden `plasma-plasmashell.service`) och M4.

### P2 – GoblinRecorder-tjänsten kör pgrep hela tiden
- **Vad:** Tjänsten tittar efter WoW och CS2 var 5:e s med `pgrep` (`usr/libexec/goblincakes-recorder:910`, `:926`; `usr/share/goblincakes/recorder/recorder.py:908`–`:914`, `:1027`–`:1030`) och – när inget spel kör – efter OBS **varje varv**, alltså varannan sekund (`goblincakes-recorder:959`, `recorder.py:155`). Varje `pgrep` tar 25 ms (M6) eftersom den läser alla ~520 processer. Under spel faller OBS-frågan bort (villkoret på rad 959 kortsluts), men då går varvet fyra gånger i sekunden (`:1039`) och OBS:s hela loggfil läses om varannan och var femte sekund för att se om skärmfångsten frusit eller frågar efter skärm (`recorder.py:245`–`:290`, anropas från `goblincakes-recorder:965`–`:985`) – loggen växer under en raidkväll.
- **Förslag:** en enda genomläsning av `/proc` var 5:e s inne i tjänsten (som `gaming.py` gör, ~5 ms) som svarar på alla tre frågorna; OBS-svaret återanvänds mellan varven; av OBS-loggen läses bara slutet (de sista kilobyten) i stället för hela filen.
- **Vinst:** 2,1 % → ca 0,1 % i vila. Under spel: okänt tills det mätts (M2 medan WoW kör) – `pgrep`-delen är där ca 1 %, loggläsningen tillkommer.
- **Säkerhet:** sett/mätt – 2,11 % i vila (M2), vilket stämmer med 0,9 `pgrep` i sekunden à 25 ms. Under spel: bara läst i koden – tror.
- **Risk:** låg–medel. WoW-igenkänningen är känslig (7 nov: Battle.nets `WoW.exe` med bakåtsnedstreck kändes inte igen) – samma mönster måste gälla efteråt.
- **Storlek:** liten.
- **Kan provas:** offscreen med attrapperna (`GOBLINCAKES_RECORDER_WOW`), sedan en riktig WoW-start på datorn.
- **Mät efteråt:** M2 (raden `goblincakes-recorder.service`), i vila och under spel.

### P3 – GoblinRecorder-fönstret kör `flatpak info` varje sekund
- **Vad:** Fönstret (som ligger kvar i systemfältet) frågar varje sekund om OBS-tillägget är installerat (`flatpak info`, 13 ms) och läser CS2-kopplingen – i fönstrets egen tråd, även när fönstret är gömt (`usr/bin/goblin-recorder:65`–`:67`, `:96`–`:106`; `recorder.py:147`–`:152`).
- **Förslag:** statusfilen läses som nu (billigt, ikonen behöver den), men tillägget och CS2-kopplingen kollas bara när fönstret visas och sedan var 30:e s.
- **Vinst:** 1,4 % → ~0,1 %; fönstret hackar inte när flatpak är långsam.
- **Säkerhet:** sett/mätt – 1,44 % i vila med fönstret gömt (M2, raden `app-goblin-recorder@autostart`).
- **Risk:** låg. "Installera tillägget"-knappen kan visa gammalt läge i upp till 30 s om man inte uppdaterar direkt efter installationen.
- **Storlek:** liten.
- **Kan provas:** offscreen.
- **Mät efteråt:** M2.

### P4 – goblin graph-vakten kör `pw-dump` varannan sekund
- **Vad:** Vakten som öppnar staplarna när musik spelar frågar PipeWire efter **allt** (239 kB text) varannan sekund och tolkar det (`usr/bin/goblin-graph:66`–`:75`, `:142`–`:174`). Den fortsätter under spel, fast staplarna då ändå står still.
- **Förslag:** under spel (spelvaktens fil finns) – titta inte alls; annars var 5:e s, eller lyssna på ändringar (`pactl subscribe`) i stället för att fråga.
- **Vinst:** 1,15 % → ~0,2 %, och PipeWire slipper svara (ljudet är det sista man vill störa under spel).
- **Säkerhet:** sett/mätt – 1,15 % (M2). Gäller bara den som har `goblin graph auto` på (användarens dator; laptopen: M7 visar det).
- **Risk:** låg. Staplarna öppnas några sekunder senare efter att musiken startat.
- **Storlek:** liten (glesare + vila under spel); medel om den ska lyssna på händelser.
- **Kan provas:** bara på riktiga datorn (ljud).
- **Mät efteråt:** M2 (raden `goblincakes-graph.service`).

### P5 – Fyra delar letar efter spel var för sig
- **Vad:** Spelvakten läser alla processer var 3:e s (`usr/libexec/goblincakes-gameguard:256`, `usr/share/goblincakes/gaming.py:23`–`:35`), lokal AI-vakten varje sekund (`usr/libexec/goblincakes-ollama:662`–`:679`, `gaming.py:62`–`:73`), Kakans vakt var 15:e s (`ai/reminders.py:584`), Goblin AI vid svar – plus recorderns `pgrep` (P2).
- **Förslag steg 1 (litet):** snabbare genomläsning i `gaming.py` (`os.listdir` + `open` i stället för `pathlib`): 11,2 → 5,3 ms mätt. **Steg 2 (medel):** en del letar (spelvakten, även när Spelläge är avstängt – då bara letandet) och skriver en fil; de andra läser filen. I dag skrivs filen bara med Spelläge på – därför behövs en fil till för "ett spel kör" skild från "Spelläge gör något".
- **Vinst:** ca 2 % → under 0,5 %. Steg 1 ensamt halverar.
- **Säkerhet:** sett/mätt – användarens dator: spelvakten 0,78 %, AI-vakten 1,19 %; laptopen: 0,94 % och 1,71 % (M2); ett varv 11,2 ms mot 5,3 ms med snabbare läsning (M8).
- **Risk:** steg 1 låg. Steg 2 medel – lokal AI ska stängas av även med Spelläge av (dagens beslut), och ett avbrott i spelvakten får inte göra att AI:n aldrig startar igen.
- **Storlek:** steg 1 liten, steg 2 medel.
- **Kan provas:** offscreen (attrapp-processer), sedan ett riktigt spel.
- **Mät efteråt:** M2 (`goblincakes-gameguard.service`, `goblincakes-ollama.service`), M8.

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

### P10 – Uppdateringskollen går 20 s efter inloggning och tar 7 s
- **Vad:** `goblincakes-updates.timer` (`OnStartupSec=20s`) kör `goblincakes-updates check`: `rpm-ostree status` två gånger, `skopeo` tre gånger, `flatpak remote-ls` fyra gånger, `fwupdmgr`, ChatGPT-appen (`usr/libexec/goblincakes-updates:49`–`:108`, `:252`–`:392`). Mätt: 7,1 s (M11). Samtidigt startar `goblincakes-fedora-check` och frågar `skopeo` om samma image en gång till (`usr/libexec/goblincakes-fedora-check:27`–`:38`).
- **Förslag:** första kollen 2–3 min efter inloggning i stället för 20 s (pilen visar under tiden det sparade svaret från förra kollen – `~/.cache/goblincakes/updates.json`), och Fedora-kollen läser samma svar i stället för att fråga själv (hör ihop med P7.1).
- **Vinst:** lugnare första minut efter inloggning, särskilt på laptopen (nätverk + disk + processor just när programmen startar). En nätverksfråga mindre.
- **Säkerhet:** sett/mätt – 7,1 s på användarens dator, 9,3 s på laptopen (M11).
- **Risk:** låg. Pilen kan visa gårdagens läge i två minuter.
- **Storlek:** liten.
- **Kan provas:** offscreen (timern) + riktiga datorn.
- **Mät efteråt:** M11 (`goblincakes-updates.service` i `--user blame`).

### P11 – Nvidia-modulerna laddas i tidig uppstart: 6 s hos användaren, 12,5 s på laptopen (Universal Blue, inte GOBLINCAKES)
- **Vad:** På Nvidia-varianterna tvingar Nvidia-paketets egen fil `/usr/lib/dracut/dracut.conf.d/99-nvidia.conf` (från `nvidia-kmod-common`, alltså Universal Blue/negativo17) in `i915 amdgpu nvidia nvidia_drm nvidia_modeset nvidia_peermem nvidia_uvm` redan i initrd. På användarens dator tar det steget (`dracut-pre-udev.service`) 6,1 s av uppstartens 43, och slutar varje gång med felet `could not insert 'nvidia_peermem': Invalid argument`. **På laptopen tar samma steg 12,5 s (11,9 s ren processortid) av 57 s** – den enskilt största posten i hela uppstarten – och initramfs är där 400 MB, vilket troligen också förklarar att startmenyn tar 16 s (den läser in hela filen). Det här beror **inte** på Fedora-versionen och inte på GOBLINCAKES egna filer – men GOBLINCAKES kan lägga en egen dracut-fil efter den. Samma sak gör troligen att initramfs är 309 MB (sett; vad som tar plats: M14).
- **Förslag:** (a) litet: ta bort `nvidia_peermem` ur listan (den går aldrig att ladda utan särskild nätverkshårdvara) – ett fel mindre i loggen, kanske någon tiondel; (b) större: ladda inte `nvidia_uvm`/`nvidia` i initrd utan först i det riktiga systemet. Föreslås **inte** utan prov: tidig laddning finns för att startskärmen och inloggningsskärmen ska få rätt upplösning och inte bli svarta.
- **Vinst:** (a) renare logg. (b) upp till ~5 s snabbare uppstart hos användaren och ~10 s på laptopen (plus en mindre initramfs att läsa in) – tror.
- **Säkerhet:** sett/mätt – 6,1 s och felraden på användarens dator, 12,5 s på laptopen (M11). Vad i steget som tar tiden (uppackning, signaturkontroll, vilken modul): vet inte – M14 visar vad som ligger i initramfs. Att (b) går utan svart skärm: tror inte utan prov.
- **Risk:** (a) låg; (b) hög – uppstarten/inloggningsskärmen kan bli svart (rollback i startmenyn räddar).
- **Storlek:** (a) liten, (b) medel + prov på båda Nvidia-datorerna.
- **Kan provas:** bara på riktiga datorn. Går troligen att prova på **en** dator utan ny image: `rpm-ostree initramfs --enable` med egna dracut-växlar bygger en lokal initramfs och `--disable` tar bort den igen (Opus bekräftar växlarna först) – användarens dator före laptopen.
- **Mät efteråt:** M11.

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
  3. `scx-scheds` (140 MB) följer med för ett reglage som är avstängt som standard (`files/scripts/install-scx.sh`). Behålls om reglaget används; annars 140 MB mindre.
  4. Bygget startar för ändringar som inte påverkar imagen: `tools/**`, `.claude/**`, `LICENSE`, `.github/dependabot.yml` saknas i `paths-ignore` (`.github/workflows/build.yml:8`–`:18`).
- **Vinst:** färre tysta fel (1), färre onödiga byggen (4), ev. 140 MB (3).
- **Säkerhet:** sett (läst i filerna). Att reglaget för `scx` inte används: vet inte – användaren avgör.
- **Risk:** låg.
- **Storlek:** liten.
- **Kan provas:** på GitHub (ett bygge).
- **Mät efteråt:** –

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

### P16 – Samma QML-komponenter kopierade i flera fönster
- **Vad:** `FastWheel` finns som egen kopia i sju fönster (`ai/Main.qml:1240`, `config/Main.qml:377`, `recorder/Main.qml:390`, `dashboard/Main.qml:195`, `amp/Main.qml:540`, `share/Main.qml:89`, `remove/Main.qml:73`) – fem är identiska, **dashboardens och GoblinAmps har redan glidit isär**. `SectionTitle` och `Note` är identiska i tre fönster (`recorder/Main.qml:452`/`:460`, `share/Main.qml:122`/`:130`, `remove/Main.qml:148`/`:156`), `Monogram` i två (`config/Main.qml:447`, `remove/Main.qml:103`). USB-skaparen har egna kopior av allt (`usb-skaparen/Main.qml:70`–`:223`) – den byggs för sig och får vara så.
- **Förslag:** flytta `FastWheel`, `SectionTitle`, `Note` och `Monogram` till `share/goblincakes/qml/Goblin` som de andra, och låt fönstren använda dem (dashboardens/Amps skillnader blir egenskaper).
- **Vinst:** en ändring av rullningen görs på ett ställe i stället för sju; ca 250 rader mindre.
- **Säkerhet:** sett – jämfört med kontrollsumma.
- **Risk:** låg–medel. Rullningen i dashboarden/Amp kan bete sig lite annorlunda om skillnaderna inte förs över rätt.
- **Storlek:** liten–medel (ett fönster i taget).
- **Kan provas:** offscreen (kompilerar) + rulla i varje fönster på riktiga datorn.
- **Mät efteråt:** –

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

**Granskat utan anmärkning (område 4):** skalskripten har felhantering (`set -u`/`-e` + `pipefail`) utom `goblincakes-firstlogin` (se P21) och `goblincakes-steam-wait-libraries` (ska aldrig stoppa Steam); tjänsterna har `Restart=on-failure`; inställningar sparas genomgående med temporärfil + byte. De stora filerna (`ai/Main.qml` 7 768 rader, `goblinai.py` 7 122, `config/Main.qml` 4 454, `recorder/Main.qml` 3 984, `recorder.py` 3 692) vore lättare att arbeta i uppdelade, men det är en stor och riskabel omflyttning utan att användaren märker något – föreslås inte nu.

---

## Område 5 – Fel och risker

Det som hittades på vägen. Tre av punkterna gäller just Fedora-hopp – och ett sådant pågår nu (basen och legacy är på Fedora 45, `goblincakes-nvidia` på 44).

### P20 – AppGrid och libratbag byggs på Fedora 45 men läggs i Fedora 44-imagen
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

### P22 – Kakans röst slutar fungera när Fedora byter Python-version
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

### P24 – Fedora-hoppet kommer av sig självt
- **Vad:** Alla tre recepten har `image-version: latest` (`recipes/recipe*.yml`), och uppdateringarna förbereds automatiskt (`AutomaticUpdates: stage`). När Universal Blue flyttar `latest` till nästa Fedora följer GOBLINCAKES med samma dag och nästa omstart startar i den – notisen (`goblincakes-fedora-check`) hinner i praktiken bara berätta det. Så gick det 9 nov: laptopen (legacy, Nvidia 580 – enligt `frugans-laptop.md` inte provad på Fedora 45) fick Fedora 45 förberett utan att någon valt det. Det är ett medvetet upplägg ("GOBLINCAKES' daily build follows"), och rollback finns – men den svagaste datorn blir först ut som provdator.
- **Förslag (användarens beslut):** lås recepten vid en Fedora-version (`image-version: 45`/`44`) och höj med flit när användaren provat på sin egen dator – de dagliga byggena fortsätter ge säkerhetsuppdateringar inom versionen. Eller behåll `latest` men låt legacy-varianten ligga ett steg efter.
- **Vinst:** inga överraskande Fedora-hopp på frugans dator; hoppet görs när det passar.
- **Säkerhet:** sett – recepten, `rpm-ostree status` (stage), anteckningen från 9 nov.
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
| [ ] | 1 | **P12** Uppdateringarna laddar ner 1,4–2,9 GB för ~120 MB nytt | uppdateringar på minuter i stället för en kvart på wifi | medel | liten + prov |
| [ ] | 2 | **P1** Widgetarna startar skript varje sekund | 5 % av en kärna tillbaka, alltid, båda datorerna | låg | liten |
| [ ] | 3 | **P2** GoblinRecorder-tjänstens `pgrep` och loggläsning | 2 % i vila (användarens dator); under spel ej mätt än | låg–medel | liten |
| [ ] | 4 | **P3** GoblinRecorder-fönstrets `flatpak info` | 1,4 % (användarens dator) | låg | liten |
| [ ] | 5 | **P15** Kontroll före bygget | färre trasiga images, kopiorna kan inte glida isär | låg | liten |
| [ ] | 6 | **P20** Byggstegen på rätt Fedora-bas | ingen trasig programmeny/Piper vid Fedora-hopp, snabbare Nvidia-bygge | låg | liten |
| [ ] | 7 | **P22** Rösten och ny Python-version | rösten överlever Fedora 45 på användarens dator | låg | liten |
| [ ] | 8 | **P18** Färdigkompilerade Python-filer | CS2-demon 1–1,5 s fortare, fönster 0,05 s fortare | låg | liten |
| [ ] | 9 | **P5** Spelletandet (steg 1: snabbare läsning) | 1–1,5 % av en kärna, båda datorerna | låg | liten |
| [ ] | 10 | **P4** goblin graph-vaktens `pw-dump` | 1 % + lugnare ljudserver (användarens dator) | låg | liten |
| [ ] | 11 | **P10** Uppdateringskollen senare efter inloggning | lugnare första minut (7–9 s arbete flyttas) | låg | liten |
| [ ] | 12 | **P9** Inloggningens hjälpprogram | 1–3 s mindre arbete vid inloggning | låg | liten |
| [ ] | 13 | **P21** Första-inloggningen skriver "klart" vid fel | ny layout når säkert fram | låg–medel | liten |
| [ ] | 14 | **P7** Småsaker i bakgrunden (6 st) | några MB och uppvaknanden, renare processlista | låg | liten |
| [ ] | 15 | **P24** Fedora-hoppet kommer av sig självt | inga överraskande hopp på frugans dator (beslut) | låg | liten |
| [ ] | 16 | **P11** Nvidia-modulerna i tidig uppstart | upp till 5–10 s snabbare start (laptopen mest) | hög | medel |
| [ ] | 17 | **P23** QML-cachen används inte | Goblin AI öppnas 0,5–1 s fortare | medel | medel |
| [ ] | 18 | **P16** Kopierade QML-komponenter | lättare underhåll | låg–medel | liten–medel |
| [ ] | 19 | **P14** Småsaker i bygget | färre tysta fel, färre onödiga byggen | låg | liten |
| [ ] | 20 | **P19** Städning | kortare filer, mindre att läsa | låg | liten |
| [ ] | 21 | **P5** steg 2: en del letar spel, resten läser | ytterligare ~0,5 % | medel | medel |
| [ ] | 22 | **P13** AppGrid/libratbag i eget flöde | bygget 3 min kortare (delvis löst av P20) | medel | medel |
| [ ] | 23 | **P8** Program från dashboarden i egen enhet | rätt siffror per program | låg | liten |
| [ ] | 24 | **P17** Gemensam startkod för fönstren | lättare underhåll | medel | medel |
| [ ] | 25 | **P6** Fönster som ligger kvar i minnet | behövs inte med 16 GB | låg–medel | liten |

## Topp 5 – börja här

1. **P1 – widgetarna.** Störst vinst för minst risk, och den enda som märks på båda datorerna hela tiden. En widget i taget (Spelas nu först); M2 och M5 visar direkt om det hjälpte.
2. **P12 – uppdateringarnas storlek.** Det användaren (och frugan på wifi) märker mest: 1,4–2,9 GB per uppdatering blir några hundra MB. Prova på legacy- eller basvarianten först, mät med M12, ta sedan Nvidia-varianten. Hög effekt men rör bygget – låt Fable bygga eller granska.
3. **P2 + P3 – GoblinRecorder** (samma session). 3,5 % av en kärna i vila på användarens dator. Hur mycket det är medan WoW kör är inte mätt än – gör M2 under spel först, det är "före"-värdet. Litet och provbart med attrapperna.
4. **P15 – kontrollen före bygget.** Gör alla punkter efter den säkrare att bygga (syntax, QML, kopior) och kostar en halvtimme.
5. **P20 + P22 – före nästa Fedora-hopp.** `goblincakes-nvidia` går till Fedora 45 när Universal Blue släpper den; innan dess bör byggstegen byggas på rätt bas och rösten klara ny Python. Båda är små.

Därefter i tur: P18, P5 (steg 1), P4, P10, P9 – alla små och ofarliga. **P11** (uppstarten) ger mest på laptopen (12,5 s) men är den enda med hög risk: gör M14 först och prova på användarens dator. **P24** är ett beslut, inte ett bygge.

**Kvar att mäta före bygget av P1/P2/P5:** M2, M4 och M9 medan ett spel kör, på båda datorerna – det är "före"-värdet för det som märks i spel.

---

## Mätningar

Kommandona kan köras igen precis som de står – i en terminal på datorn, eller från användarens dator med `ssh victoria '<kommandot>'` medan GoblinShare-terminalen till laptopen är öppen (aliaset heter `victoria`, se `~/.ssh/goblinshare.conf`). Varje block är ett enda kommando – klistra in hela. Rader med `sshd`, `bash -s` och GoblinShares hjälpsession räknas bort.

**När det mättes:** användarens dator 11 nov 17:10–17:35, 15–40 min efter inloggning, inget spel, upplägget Dashboard. Laptopen 11 nov 17:39–17:45 via GoblinShare (uppkopplingen var redan öppen), 38 min efter start, inget spel, upplägget Standard.

**Kvar att mäta:** M2, M4, M9 **medan ett spel kör** – på båda datorerna (helst WoW på laptopen). M10 i sin helhet och M14 på laptopen (M10 kör inloggningens hjälpprogram på riktigt, M14 kräver lösenord – görs när hon är med).

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
- **Under spel:** ej mätt än.
- **Frugans laptop (11 nov 17:40, 38 min efter start, i vila, inget spel, upplägget Standard, Fedora 45):** plasmashell-enheten 6,12 % · `goblincakes-ollama.service` 1,71 % · `goblincakes-gameguard.service` 0,94 % · `goblincakes-share.service` 0,57 % (hjälpsessionen var öppen) · `goblincakes-archon-tray.service` 0,36 % (Archon finns inte på datorn) · kakan-vakt 0,08 %. Recorder, graph och rösten är inte påslagna där.
- **Frugans laptop under spel:** ej mätt än (se "Kvar att mäta" överst i Mätningar).

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
- **Frugans laptop (11 nov 17:40, 38 min efter start, i vila, inget spel, upplägget Standard, Fedora 45):** 333 på 60 s (ca 5,5 per sekund).

### M5 – plasmashell själv mot skripten den startar (30 s)
```
p=$(pgrep -x plasmashell); cpu() { awk '{print $14+$15}' /proc/$p/stat; }; cg() { systemctl --user show plasma-plasmashell.service -p CPUUsageNSec --value; }; a=$(cpu); ca=$(cg); sleep 30; b=$(cpu); cb=$(cg); echo "plasmashell själv: $(awk -v d=$((b-a)) 'BEGIN{printf "%.1f", d/30}') %  hela enheten med skripten: $(awk -v d=$((cb-ca)) 'BEGIN{printf "%.1f", d/1e9/30*100}') %"
```
- **Användarens dator, i vila:** plasmashell själv 0,2 % · hela enheten 7,6 %.
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
- **Frugans laptop (11 nov 17:40, 38 min efter start, i vila, inget spel, upplägget Standard, Fedora 45):** game_running 8,4 ms · processes + find_game 16,4 ms (295 processer mot 519 på användarens dator).

### M9 – Minne och växling
```
free -m | sed -n 1,3p; grep -E 'pswpin|pswpout' /proc/vmstat; nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader
```
- **Användarens dator, i vila:** 9 774 av 32 005 MB använt, växling 0 av 8 191 MB, grafikminne 1 237 av 12 288 MiB.
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
