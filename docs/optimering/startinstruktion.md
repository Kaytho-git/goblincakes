# Startinstruktion – optimeringsgranskning med Fable

Så här kör du den:
1. Starta Claude Code i repot, välj Fable med `/model` och sätt `/effort high`.
2. Klistra in texten i rutan nedan.
3. Om kvoten är viktig: stryk punkt 6 (UX) och kör den som en egen session efteråt.
4. Gå sedan igenom rapporten och säg vilka punkter som ska byggas. Det kan göras med Opus, en eller några punkter per session.

```
Uppgift: granska hela GOBLINCAKES och ta fram en prioriterad optimeringslista. ÄNDRA INGEN KOD i den här uppgiften – bara läs, mät där det går och rapportera. Jag bestämmer sedan vad som byggs.

Börja med: git pull, läs CLAUDE.md. docs/anteckningar.md är stor – läs den inte hel, grep på det du granskar (t.ex. varför något gjorts på ett visst sätt – kolla det innan du föreslår att ändra det). Följ alla regler i CLAUDE.md.

Vilken dator: bedöm prestanda utifrån den svagaste datorn som kör GOBLINCAKES – frugans laptop (Lenovo Legion Y520, äldre Nvidia-kort, varianten goblincakes-nvidia-legacy, Fedora 45). Min dator kör goblincakes-nvidia (Fedora 44 tills Universal Blue släpper den på 45) – skilj på vad som beror på Fedora-versionen och vad som beror på GOBLINCAKES. Föreslå inget som gör den starkare datorn sämre; tunga funktioner (lokal AI, inspelning, effekter) ska hellre anpassa sig efter hårdvaran än tas bort. Image och bygge gäller båda varianterna.

Mätningar på laptopen: du körs på min dator och når laptopen via GoblinShare (Be om hjälp på laptopen → Terminal + koden här; sedan går `ssh frugans-laptop <kommando>` så länge den terminalen är öppen). Samla alla mätkommandon för laptopen i en lista och säg till när du behöver dem – jag kopplar upp först då, vi kör allt i ett svep och avslutar. Räkna bort sshd-processen i mätningarna. Mät gärna både efter en vanlig inloggning och medan ett spel kör (fråga mig när spelet är igång). Går uppkopplingen inte: skriv kommandona så jag kan köra dem på laptopen och klistra in svaren.

Granska de här områdena (i den här ordningen):
1. Prestanda i bakgrunden – tjänster, timers, autostart, pollande skript och Python-processer som drar CPU/minne, särskilt medan spel kör (spelvakten, Kakan, GoblinRecorder, toppfältet, docka, widgets).
2. Uppstart och inloggning – vad som körs vid boot och första/varje inloggning (goblincakes-firstlogin, goblincakes-refresh.sh, plasma-workspace/env, systemd-enheter), vad som kan köras senare, parallellt eller inte alls.
3. Image och bygge – recipes/common-modules.yml, common-stages.yml, build.yml: onödiga paket, lager som kan slås ihop, cachning, byggtid, imagens storlek. Inga beslut i CLAUDE.md får brytas (t.ex. Steam i imagen, inte Bazzite, Fedoras kärna).
4. Kodkvalitet och underhåll – kopierad kod mellan fönstren (FlatButton/CheckSquare/FlatScrollBar/FlatField m.fl.), döda filer/funktioner, saker som görs på två olika sätt, ställen där en ändring lätt glöms på ena stället (de "två kopiorna" i CLAUDE.md), skript utan felhantering.
5. Fel och risker du hittar på vägen – buggar, race conditions, saker som kan gå sönder vid Fedora-uppgradering eller rollback.
6. UX – gå igenom våra egna fönster (Config, Goblin AI, Dashboard, GoblinAmp, GoblinShare m.fl.):
   - Avvikelser från designen (https://claude.ai/artifact/BqT4GjvtTacjAgiCnRKwqt) och Configs stil: färger, typsnitt, avstånd, knappar, raka hörn, accent.color.
   - Inkonsekvenser mellan fönstren (samma sak gjord/benämnd olika).
   - Texter: otydliga, tekniska, felstavade, blandad svenska/engelska.
   - Flöden: onödiga steg, saknad återkoppling (laddar/klart/fel), saker som är svåra att hitta.
   - Rendera fönstren offscreen med attrapper och titta på skärmdumparna där det går. Skriv vad som är sett på bild och vad som bara är läst i koden.
   Lägg UX-punkterna i ett eget avsnitt i rapporten.

Leverans: skriv rapporten till docs/optimering/granskning.md och committa bara den filen (ingen push). För varje punkt:
- Vad: kort beskrivning + filer (fil:rad)
- Vinst: vad jag märker (snabbare, mindre minne, färre fel, lättare underhåll) och ungefär hur mycket
- Risk: låg/medel/hög + vad som kan gå sönder
- Storlek: liten (< 1 h), medel, stor (flera sessioner)
- Kan provas: offscreen/i molnet, eller bara på riktiga datorn
Sortera efter vinst delat med risk och storlek – mest värt först. Max ~30 punkter (UX-avsnittet räknas för sig); slå ihop småsaker. Skriv på vanlig svenska, kort. Avsluta med en topp 5 som du rekommenderar att börja med.

Gissa inte: skilj på "har sett/mätt" och "tror". Om något kräver att man mäter på riktiga datorn, skriv vilket kommando jag ska köra.
```
