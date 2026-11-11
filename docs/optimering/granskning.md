# Optimeringsgranskning av GOBLINCAKES

Gjord av Fable 11 nov 2026 enligt `docs/optimering/startinstruktion.md` del 1. Ingen kod är ändrad – bara läst och mätt.

## Läget (för en ny session som fortsätter)
- [x] Område 1 – Prestanda i bakgrunden (punkt 1–8)
- [ ] Område 2 – Uppstart och inloggning ← **nästa**
- [ ] Område 3 – Image och bygge
- [ ] Område 4 – Kodkvalitet och underhåll
- [ ] Område 5 – Fel och risker
- [ ] Mätningar på frugans laptop (bara användarens dator är mätt hittills – se Mätningar sist)
- [ ] Sortering + topp 5 (görs sist)

Punkterna har fasta nummer (P1, P2 …) i den ordning de hittades, så att "Bygg punkt P3" alltid betyder samma sak. Den sorterade listan (mest värt först) och topp 5 kommer sist i filen när allt är granskat.

**Datorerna:** användarens dator = 16 trådar, 32 GB, RTX (12 GB), `goblincakes-nvidia`, Fedora 44. Frugans laptop = Legion Y520, i7-7700HQ (4 kärnor/8 trådar, ungefär hälften så snabb per kärna), 16 GB, GTX 1050 Ti (4 GB), `goblincakes-nvidia-legacy`, Fedora 45. Procenttal nedan är **% av en kärna** på användarens dator om inget annat står; på laptopen blir samma arbete ungefär dubbelt så dyrt ("tror" tills M2 körts där).

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

Allt detta fortsätter medan ett spel kör (utom lokal AI, som stängs av). På laptopens fyra kärnor är det tänkbart en kvarts kärna som spelet inte får – inte katastrof, men onödigt, och det väcker processorn ~16 gånger i sekunden (M4: 483 nya processer på 30 s) vilket också drar batteri.

### P1 – Widgetarna startar skript varje sekund
- **Vad:** Toppfältets/skrivbordsradens widgetar hämtar sina uppgifter genom att starta program med jämna mellanrum. Spelas nu: Goblin AI-läget varje sekund, Discord-röst var 1–3 s, Steam var 5 s, batteri var 30 s, utseendet var 5 s (`plasmoids/org.goblincakes.nowplaying/contents/ui/main.qml:288`, `:297`, `:306`, `:315`, `:350`). Klockan: volym varannan sekund, nätverk var 10 s, batteri var 30 s, utseendet var 5 s (`org.goblincakes.deskclock/contents/ui/main.qml:132`–`:160`). Dockan, kvoten, uppdateringspilen och Meta-tipset läser utseendet var 5:e s var för sig (`dock/…/main.qml:69`, `quota/…/main.qml:138`, `updates/…/main.qml:103` + `:176`, `metahint/…/main.qml:40`). I upplägget Dashboard finns Spelas nu **två gånger** (vänster och höger del) och båda kör alla hämtningar, även dem som bara den andra delen visar. Inget saktar ner när ett spel kör, fast widgetarna redan vet om det (`gaming`).
- **Förslag:** (a) starta inte Python när det inte finns något att läsa – ett litet skalvillkor först (AI-mappen tom → `{}`, Discord inte igång → färdigt svar); (b) varje del kör bara sina egna hämtningar (`part` = left/right); (c) under spel 3–5 gånger glesare; (d) batteriet hämtas av en widget, inte två.
- **Vinst:** ca 7 % av en kärna → uppskattat 1–2 %. Färre uppvaknanden (bättre batteritid på laptopen), lugnare under spel.
- **Säkerhet:** sett/mätt – `plasma-plasmashell.service` drar 7,6 % i vila varav plasmashell själv 0,2 % (M2 + M5). Ett varv kostar: AI-läget 19 ms, Discord-röst 37 ms, Steam 67 ms, batteri 31 ms, kvoten 42 ms (M6). Hur mycket det är på laptopen: tror ungefär det dubbla – bekräftas med M2 där.
- **Risk:** låg. Det som kan gå fel: en ruta (Discord-kanalen, Kakans "tänker") dyker upp någon sekund senare, eller inte alls om villkoret skrivs fel.
- **Storlek:** liten för (a)–(c), en widget i taget.
- **Kan provas:** bara på riktiga datorn (Plasma-widgetar); själva kommandona kan provas i ett skal.
- **Mät efteråt:** M2 (raden `plasma-plasmashell.service`) och M4.

### P2 – GoblinRecorder-tjänsten kör pgrep hela tiden
- **Vad:** Tjänsten tittar efter WoW och CS2 var 5:e s med `pgrep` (`usr/libexec/goblincakes-recorder:908`, `:925`; `usr/share/goblincakes/recorder/recorder.py:908`–`:914`, `:1027`–`:1030`) och efter OBS **varje varv** (varannan sekund i vila, fyra gånger i sekunden under spel) (`goblincakes-recorder:956`, `recorder.py:155`). Varje `pgrep` tar 25 ms (M6) eftersom den läser alla ~520 processer.
- **Förslag:** en enda genomläsning av `/proc` var 5:e s inne i tjänsten (som `gaming.py` gör, ~5 ms) som svarar på alla tre frågorna; OBS-svaret återanvänds mellan varven.
- **Vinst:** 2,1 % → ca 0,1 % i vila. Under spel körs OBS-kollen 4 ggr/s i dag – där är vinsten större (tror ~8–10 % av en kärna på laptopen medan WoW kör; bekräftas med M2 under spel).
- **Säkerhet:** sett/mätt – 2,11 % i vila (M2); under spel: tror, läst i koden (`time.sleep(0.25 …)` på rad 1039 + `R.obs_running()` på rad 956).
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
- **Vad:** Spelvakten läser alla processer var 3:e s (`usr/libexec/goblincakes-gameguard:249`, `usr/share/goblincakes/gaming.py:23`–`:35`), lokal AI-vakten varje sekund (`usr/libexec/goblincakes-ollama:662`–`:679`, `gaming.py:62`–`:73`), Kakans vakt var 15:e s (`ai/reminders.py:584`), Goblin AI vid svar – plus recorderns `pgrep` (P2).
- **Förslag steg 1 (litet):** snabbare genomläsning i `gaming.py` (`os.listdir` + `open` i stället för `pathlib`): 11,2 → 5,3 ms mätt. **Steg 2 (medel):** en del letar (spelvakten, även när Spelläge är avstängt – då bara letandet) och skriver en fil; de andra läser filen. I dag skrivs filen bara med Spelläge på – därför behövs en fil till för "ett spel kör" skild från "Spelläge gör något".
- **Vinst:** ca 2 % → under 0,5 %. Steg 1 ensamt halverar.
- **Säkerhet:** sett/mätt – spelvakten 0,78 %, AI-vakten 1,19 % med Ollama (M2); 11,2 mot 5,3 ms (M8).
- **Risk:** steg 1 låg. Steg 2 medel – lokal AI ska stängas av även med Spelläge av (dagens beslut), och ett avbrott i spelvakten får inte göra att AI:n aldrig startar igen.
- **Storlek:** steg 1 liten, steg 2 medel.
- **Kan provas:** offscreen (attrapp-processer), sedan ett riktigt spel.
- **Mät efteråt:** M2 (`goblincakes-gameguard.service`, `goblincakes-ollama.service`), M8.

### P6 – Fönster som ligger kvar i minnet
- **Vad:** Varje eget fönster är ett helt Python + Qt-program. Verkligt minne (PSS, M3): Goblin AI 356 MB (+ dess webbdel), röstens igenkännare 348 MB, dashboarden gömd 221 MB, GoblinRecorder-fönstret 185 MB, GoblinShare-fönstret 146 MB. De små tjänsterna drar 7–31 MB styck, tillsammans ca 170 MB (nio stycken).
- **Förslag:** (a) dashboarden startas inte vid inloggning på datorer med lite minne utan vid första Meta-trycket (D-Bus-starten finns redan) – kostar en långsammare första öppning; (b) röstens igenkännare lämnar minnet efter t.ex. 30 min utan användning på datorer under 16 GB; (c) inget byggs förrän laptopens siffror finns – med 16 GB är det troligen inget problem där.
- **Vinst:** 200–550 MB mer till spelet på en dator med lite minne. På laptopen (16 GB): tror liten.
- **Säkerhet:** sett/mätt på användarens dator (M3); laptopen: tror – M3 + M9 där avgör om punkten ska byggas alls.
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
- **Vinst:** liten var för sig (några MB, några uppvaknanden) – lättare att läsa `ps`, en process mindre.
- **Säkerhet:** sett (1, 2 på användarens dator; 3, 4 läst i koden).
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

## Mätningar

Kommandona kan köras igen precis som de står. På laptopen: först `ssh frugans-laptop` (eller klistra in i hennes terminal). M1–M3 är hela block – klistra in allt mellan strecken. Räkna bort rader med `sshd` om de dyker upp.

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

### M3 – Verkligt minne (PSS) per GOBLINCAKES-process
```
for p in $(pgrep -u "$(id -u)" -f 'goblin|ollama|reminders.py'); do pss=$(awk '/^Pss:/{print $2}' /proc/$p/smaps_rollup 2>/dev/null); [ -n "$pss" ] && printf "%6d MB  %s\n" $((pss/1024)) "$(tr '\0' ' ' < /proc/$p/cmdline | cut -c1-90)"; done | grep -v 'sshd\|pgrep' | sort -rn | head -25
```
- **Användarens dator, i vila:** goblin-ai 356 · röstens worker 348 · goblin-dashboard (gömd) 221 · goblin-recorder (fönstret) 185 · goblin-share (fönstret) 146 · ollama serve 37 · recorder-tjänsten 31 · archon-tray 30 · voice listen 25 · share-tjänsten 23 · kakan-vakt 21 · notifications 18 · graph-vakten 15 · ollama-vakten 13 · gameguard 7 · fedora-check 6 MB.

### M4 – Nya processer på 30 s (hur ofta något startas)
```
a=$(awk '/^processes/{print $2}' /proc/stat); sleep 30; b=$(awk '/^processes/{print $2}' /proc/stat); echo "nya processer/30 s: $((b-a))"
```
- **Användarens dator, i vila:** 483 (ca 16 per sekund; Claude Codes egna kommandon ingår med några tiotal).

### M5 – plasmashell själv mot skripten den startar (30 s)
```
p=$(pgrep -x plasmashell); cpu() { awk '{print $14+$15}' /proc/$p/stat; }; cg() { systemctl --user show plasma-plasmashell.service -p CPUUsageNSec --value; }; a=$(cpu); ca=$(cg); sleep 30; b=$(cpu); cb=$(cg); echo "plasmashell själv: $(awk -v d=$((b-a)) 'BEGIN{printf "%.1f", d/30}') %  hela enheten med skripten: $(awk -v d=$((cb-ca)) 'BEGIN{printf "%.1f", d/1e9/30*100}') %"
```
- **Användarens dator, i vila:** plasmashell själv 0,2 % · hela enheten 7,6 %.

### M6 – Vad ett varv av varje hämtning kostar
```
t() { n=$1; shift; s=$(date +%s%N); for i in $(seq $n); do sh -c "$*" >/dev/null 2>&1; done; e=$(date +%s%N); echo "$(( (e-s)/n/1000000 )) ms  $*" | cut -c1-110; }; t 10 /usr/libexec/goblincakes-ai-activity; t 10 /usr/libexec/goblincakes-discord-voice; t 5 'pgrep -x steam >/dev/null && /usr/libexec/goblincakes-steam-activity || echo {}'; t 5 /usr/libexec/goblincakes-device-battery; t 10 'wpctl get-volume @DEFAULT_AUDIO_SINK@'; t 5 'nmcli -t -f TYPE,STATE,CONNECTION device status'; t 5 pw-dump; t 5 'pgrep -x obs'; t 5 'flatpak info com.obsproject.Studio'; t 5 '/usr/libexec/goblincakes-quota --cached'; t 10 'python3 -c pass'; ls /proc | grep -c '^[0-9]'
```
- **Användarens dator:** ai-activity 19 ms · discord-voice 37 · steam 67 · device-battery 31 · wpctl 8 · nmcli 8 · pw-dump 13 · pgrep 25 · flatpak info 13 · quota --cached 42 · tom Python 9 ms · 519 processer.

### M7 – Vad som är påslaget (förklarar skillnader mellan datorerna)
```
ls ~/.config/goblincakes/; cat ~/.config/goblincakes/utseende 2>/dev/null; ls ~/.config/autostart/; grep -c 'plugin=org.goblincakes' ~/.config/plasma-org.kde.plasma.desktop-appletsrc; grep 'plugin=org.goblincakes' ~/.config/plasma-org.kde.plasma.desktop-appletsrc | sort | uniq -c
```
- **Användarens dator:** graph-auto, recorder-on, share-on, vencord-on, ollama.json, utseende = levande; autostart: Archon, WoWUp, Discord, goblin-recorder, Raider.IO, Steam; widgetar: nowplaying × 2, deskclock, metahint (upplägget Dashboard).

### M8 – Spelletandet (ett varv)
```
python3 -c "
import sys,time; sys.path.insert(0,'/usr/share/goblincakes'); import gaming
def t(f,n=20):
    s=time.perf_counter(); [f() for _ in range(n)]; return (time.perf_counter()-s)/n*1000
print('game_running: %.1f ms   processes+find_game: %.1f ms' % (t(gaming.game_running), t(lambda: gaming.find_game(gaming.processes()))))"
```
- **Användarens dator:** game_running 11,2 ms · processes + find_game 23,1 ms (samma sak med `os.listdir` + `open`: 5,3 ms – provat i ett löst skript).

### M9 – Minne och växling
```
free -m | sed -n 1,3p; grep -E 'pswpin|pswpout' /proc/vmstat; nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader
```
- **Användarens dator, i vila:** 9 774 av 32 005 MB använt, växling 0 av 8 191 MB, grafikminne 1 237 av 12 288 MiB.
