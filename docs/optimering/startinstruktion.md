# Startinstruktion – optimeringsgranskning med Fable

Tre delar: **1. Fable granskar** (rapport), **2. Opus bygger** punkterna du väljer, **3. UX** – en egen granskning vid ett annat tillfälle.

## 1. Granskningen (Fable)
1. Starta Claude Code i repot på din dator, välj Fable med `/model` och sätt `/effort high`.
2. Klistra in texten i rutan nedan.
3. Gå sedan igenom rapporten och välj vilka punkter som ska byggas (del 2).

Tar kvoten slut mitt i: rapporten sparas efter varje område. När kvoten återställts – starta Fable igen och skriv "Fortsätt granskningen i docs/optimering/granskning.md enligt docs/optimering/startinstruktion.md del 1".

```
Uppgift: granska hela GOBLINCAKES och ta fram en prioriterad optimeringslista. ÄNDRA INGEN KOD i den här uppgiften – bara läs, mät där det går och rapportera. Jag bestämmer sedan vad som byggs. UX (fönstrens utseende och texter) ingår inte – den granskas vid ett annat tillfälle.

Börja med: git pull, läs CLAUDE.md. docs/anteckningar.md är stor – läs den inte hel, grep på det du granskar (t.ex. varför något gjorts på ett visst sätt – kolla det innan du föreslår att ändra det). Följ alla regler i CLAUDE.md.

Vilken dator: bedöm prestanda utifrån den svagaste datorn som kör GOBLINCAKES – frugans laptop (Lenovo Legion Y520, äldre Nvidia-kort, varianten goblincakes-nvidia-legacy, Fedora 45). Min dator kör goblincakes-nvidia (Fedora 44 tills Universal Blue släpper den på 45) – skilj på vad som beror på Fedora-versionen och vad som beror på GOBLINCAKES. Föreslå inget som gör den starkare datorn sämre; tunga funktioner (lokal AI, inspelning, effekter) ska hellre anpassa sig efter hårdvaran än tas bort. Image och bygge gäller båda varianterna.

Mätningar på laptopen: du körs på min dator och når laptopen via GoblinShare (Be om hjälp på laptopen → Terminal + koden här; sedan går `ssh frugans-laptop <kommando>` så länge den terminalen är öppen). Samla alla mätkommandon för laptopen i en lista och säg till när du behöver dem – jag kopplar upp först då, vi kör allt i ett svep och avslutar. Räkna bort sshd-processen i mätningarna. Mät gärna både efter en vanlig inloggning och medan ett spel kör (fråga mig när spelet är igång). Går uppkopplingen inte: skriv kommandona så jag kan köra dem på laptopen och klistra in svaren.

Granska de här områdena (i den här ordningen):
1. Prestanda i bakgrunden – tjänster, timers, autostart, pollande skript och Python-processer som drar CPU/minne, särskilt medan spel kör (spelvakten, Kakan, GoblinRecorder, toppfältet, docka, widgets).
2. Uppstart och inloggning – vad som körs vid boot och första/varje inloggning (goblincakes-firstlogin, goblincakes-refresh.sh, plasma-workspace/env, systemd-enheter), vad som kan köras senare, parallellt eller inte alls.
3. Image och bygge – recipes/common-modules.yml, common-stages.yml, build.yml: onödiga paket, lager som kan slås ihop, cachning, byggtid, imagens storlek. Inga beslut i CLAUDE.md får brytas (t.ex. Steam i imagen, inte Bazzite, Fedoras kärna).
4. Kodkvalitet och underhåll – kopierad kod mellan fönstren (FlatButton/CheckSquare/FlatScrollBar/FlatField m.fl.), döda filer/funktioner, saker som görs på två olika sätt, ställen där en ändring lätt glöms på ena stället (de "två kopiorna" i CLAUDE.md), skript utan felhantering.
5. Fel och risker du hittar på vägen – buggar, race conditions, saker som kan gå sönder vid Fedora-uppgradering eller rollback.

Spara längs vägen (kvoten kan ta slut): skriv in varje område i docs/optimering/granskning.md och committa filen så fort området är klart – vänta inte till slutet. Mätresultaten förs in i avsnittet Mätningar direkt när de körts. Överst i filen: vilka områden som är klara och vilket som är nästa, så en ny session kan fortsätta där du slutade. Sorteringen och topp 5 görs sist.

Leverans: rapporten i docs/optimering/granskning.md; committa bara den filen (ingen push). För varje punkt:
- Vad: kort beskrivning + filer (fil:rad)
- Vinst: vad jag märker (snabbare, mindre minne, färre fel, lättare underhåll) och ungefär hur mycket
- Säkerhet: "sett/mätt" (med siffran) eller "tror" (och hur man bekräftar det)
- Risk: låg/medel/hög + vad som kan gå sönder
- Storlek: liten (< 1 h), medel, stor (flera sessioner)
- Kan provas: offscreen/i molnet, eller bara på riktiga datorn
- Mät efteråt: vilket kommando i avsnittet Mätningar som visar om ändringen hjälpte (om det finns ett)
Sortera efter vinst delat med risk och storlek – mest värt först. Max ~30 punkter; slå ihop småsaker. Skriv på vanlig svenska, kort. Avsluta med en topp 5 som du rekommenderar att börja med.

Avsnittet Mätningar (sist i rapporten): alla kommandon du körde på laptopen (och min dator), numrerade, exakt som de ska skrivas, med när de kördes (efter inloggning / under spel) och resultatet i korthet. Det är "före"-värdena – samma kommandon körs igen när punkterna är byggda, så de ska gå att köra igen utan att du är med.

Gissa inte: skilj på "har sett/mätt" och "tror". Om något kräver att man mäter på riktiga datorn, skriv vilket kommando jag ska köra.
```

## 2. Bygga punkterna (Opus)
En eller några punkter per session. Klistra in och fyll i numren:

```
Bygg punkt <nr> (och <nr>) i docs/optimering/granskning.md. Börja med git pull och läs CLAUDE.md.
Står det "tror" under Säkerhet: bekräfta först (läs koden eller be mig köra kommandot) innan du ändrar något. Visar det sig inte stämma – säg det och bygg inget.
När det är byggt: skriv vilka kommandon i avsnittet Mätningar jag ska köra igen (laptopen via GoblinShare eller min dator), och för in "efter"-värdena i rapporten när jag kört dem. Bocka av punkten i rapporten.
```

Punkter med **hög risk** eller storlek **stor** (t.ex. uppstarten, bygget eller något som rör rollback): låt hellre Fable bygga dem, eller låt Fable granska det Opus byggt, om kvoten räcker.

## 3. UX (vid ett annat tillfälle, Fable)
Egen session. Klistra in:

```
Uppgift: granska UX i GOBLINCAKES egna fönster (Config, Goblin AI, Dashboard, GoblinAmp, GoblinShare m.fl.). ÄNDRA INGEN KOD – bara granska och rapportera. Börja med git pull, läs CLAUDE.md; grep i docs/anteckningar.md i stället för att läsa den hel. Följ alla regler i CLAUDE.md.
- Avvikelser från designen (https://claude.ai/artifact/BqT4GjvtTacjAgiCnRKwqt) och Configs stil: färger, typsnitt, avstånd, knappar, raka hörn, accent.color.
- Inkonsekvenser mellan fönstren (samma sak gjord/benämnd olika).
- Texter: otydliga, tekniska, felstavade, blandad svenska/engelska.
- Flöden: onödiga steg, saknad återkoppling (laddar/klart/fel), saker som är svåra att hitta.
- Rendera fönstren offscreen med attrapper och titta på skärmdumparna där det går. Skriv vad som är sett på bild och vad som bara är läst i koden.
Både Platt och Levande utseende (Config → Utseende → Stil).
Leverans: docs/optimering/ux.md, committa bara den filen (ingen push). Per punkt: vad (fil:rad), vinst, risk, storlek, sett på bild eller bara läst i koden. Mest värt först, max ~30 punkter, vanlig svenska, kort, topp 5 sist.
```
