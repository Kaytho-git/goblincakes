# Startinstruktion – optimeringsgranskning med Fable

Tre delar: **1. Fable granskar** (rapport), **2. Opus bygger** punkterna du väljer, **3. UX** – egen granskning (1080p/1440p, fönstren som ett system): Opus samlar underlaget, Fable granskar, Opus bygger.

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

## 3. UX – 1080p och 1440p, fönstren som ett system (Opus + Fable)
Kända problem (användaren 12 nov): ramar försvinner när fönster görs mindre, maximerade fönster känns jättestora, saker som borde vara centrerade ligger vid sidan så det blir svårt att läsa.

Kör alla stegen i Claude Code **på din riktiga dator** (inte i molnet) – där kan Claude öppna de riktiga fönstren på dina skärmar och ta skärmbilder. Grovjobbet (bilder, inventering) gör Opus, så att Fables kvot går till bedömningen.

**Steg A – Opus samlar underlaget** (`/model opus`). Klistra in:

```
Uppgift: förbered en UX-granskning som Fable ska göra sedan. ÄNDRA INGEN KOD. Börja med git pull, läs CLAUDE.md; grep i docs/anteckningar.md i stället för att läsa den hel.

1. Skärmarna: kör kscreen-doctor -o och skriv upp varje skärm – upplösning, skalning, fysisk storlek och ppi.
2. Inventering i docs/ux/inventering.md – per eget fönster (Config, Goblin AI, Dashboard + skrivbordsraden, GoblinAmp, GoblinShare, GoblinRecorder, goblin graph, lagmätaren, Avinstallera, röstfönstret, toppfältet/dockan, låsskärm/utloggning): startfil, QT_SCALE_FACTOR/uiScale, start- och minsta storlek (fast i px eller efter skärmen?), största bredd på innehållet (finns någon?), hur innehållet är förankrat (anchors.left/fill/centerIn, Layout-fyllnad), vilka komponenter som kommer från qml/Goblin och vilka som är egna kopior, textstorlekar, marginaler, knapp-/radhöjder. Ange fil:rad.
3. Skärmbilder (spectacle) i ~/.local/share/goblincakes/ux-bilder/, namn <fönster>-<1080|1440>-<storlek>-<platt|levande>.png. Per fönster, Platt, på båda upplösningarna: minsta storlek, startstorlek, halva skärmen (rutad) och maximerat. Levande bara för fönster där Levande ändrar något, i startstorlek och maximerat. Jag har ingen 1440p-skärm: ta 1440p-bilderna i en kapslad kwin_wayland --virtual på 2560×1440. Ändra aldrig mina riktiga skärmar (upplösning, skalning).
4. Sist: lista över bildfilerna och vilka som inte gick att ta (och varför).
Committa bara inventering.md (ingen push). Bilderna stannar på datorn.
```

**Steg B – Fable granskar** (`/model` Fable, `/effort high`). Klistra in:

```
Uppgift: UX-granskning av GOBLINCAKES egna fönster med fokus på 1080p och 1440p och på att fönstren ska se ut och kännas som ett och samma system. ÄNDRA INGEN KOD – bara granska och föreslå. Börja med git pull, läs CLAUDE.md och docs/ux/inventering.md (underlaget, gjort av Opus); bilderna ligger i ~/.local/share/goblincakes/ux-bilder/. Läs inte docs/anteckningar.md hel – grep när du behöver veta varför något gjorts (t.ex. QT_SCALE_FACTOR 0.9, Goblin AI:s uiScale) innan du föreslår att ändra det. Designen: https://claude.ai/artifact/BqT4GjvtTacjAgiCnRKwqt. Följ alla regler i CLAUDE.md.

Kända problem som jag själv sett – börja med dessa, hitta orsaken i koden (fil:rad) och kolla vilka fönster som har dem:
A. Ramar försvinner när fönstret görs mindre (klipps, hamnar utanför, göms, eller ritas inte?).
B. Maximerade fönster känns jättestora – innehållet sträcks ut över hela skärmen, rader blir för långa, tomrum.
C. Saker som borde vara centrerade ligger vid sidan, så det blir svårt att läsa.
Jag misstänker att A–C har samma rot: ingen gemensam regel för hur innehållet beter sig när fönstret ändrar storlek. Bekräfta eller avfärda det.

Jag har ingen 1440p-skärm – 1440p-bilderna kommer från en virtuell skärm, så pixlarna stämmer men inte den fysiska storleken. Räkna med att en 1440p-skärm oftast är 27 tum (ca 109 ppi) mot 24 tum för 1080p (ca 92 ppi), dvs. samma text ser ca 15 % mindre ut. Gör normen så att den fungerar på alla storlekar (1080p, 1440p, ultrawide, halva skärmen), inte bara de två. Skriv i en egen lista vad som inte kan bedömas utan en riktig 1440p-skärm (t.ex. hur stor texten känns).

Det här vill jag ha ut, i den här ordningen:
1. En UI-norm (docs/ux/norm.md): textskala, avståndsraster, knapp-/rad-/fälthöjder, ramar, startstorlek på 1080p resp. 1440p, hur skalningen ska fungera (en gemensam regel i stället för per fönster) – och särskilt en regel för storleksändring: största läsbredd på innehållet, vad som centreras och vad som får fylla bredden, vad som händer under minsta storlek (rulla, bryta om, gömma – aldrig klippa ramar). Gärna som en gemensam komponent i qml/Goblin som alla fönster kan använda. Utgå från det som fungerar bäst (Config är förebilden), inte från noll. Den gemensamma skalningsregeln byggs i en gemensam startfil share/goblincakes/goblinapp.py (P17 i docs/optimering/granskning.md) – ta med flytten av fönstrens kopierade startkod dit i förslagen (skalan, typsnitten, cached_qml, use_accent, säsongsloggan; "ett fönster i taget" stannar i fönstren), och GoblinAmps fildialoger utan sharpText.
2. Avvikelser per fönster mot normen (docs/ux/granskning.md): A–C ovan, storlek/skalning på 1080p och 1440p, känsla (animationer, hover, återkoppling, öppna/stänga), egna kopior av komponenter, texter.
3. Förslagen, mest värt först, max ~30. Per punkt: vad (fil:rad), vinst (vad jag märker), risk, storlek (liten/medel/stor), sett på bild eller bara läst i koden, och om Opus kan bygga den utifrån normen.
4. Topp 5 sist, med en enkel före/efter-skiss (en artifact för alla fem).

Spara längs vägen: committa norm.md så fort den är klar, sedan granskning.md efter varje fönster. Överst i granskning.md: vilka fönster som är klara och vilket som är nästa. Ingen push.
Gissa inte: säg vad du sett på bild och vad du bara läst i koden. Saknas en bild – be mig ta den hellre än att gissa.
```

Tar kvoten slut mitt i: starta Fable igen och skriv "Fortsätt UX-granskningen i docs/ux/granskning.md enligt docs/optimering/startinstruktion.md del 3 – nästa fönster står överst."

**Steg C – Opus bygger** punkterna du väljer, en eller några per session:

```
Bygg punkt <nr> (och <nr>) i docs/ux/granskning.md och följ docs/ux/norm.md. Börja med git pull och läs CLAUDE.md.
Står det "bara läst i koden": bekräfta först (skärmbild eller läs koden) innan du ändrar något. Stämmer det inte – säg det och bygg inget.
När det är byggt: skärmbilder före/efter på 1080p och 1440p (1440p i en kapslad kwin_wayland --virtual – jag har ingen 1440p-skärm), bocka av punkten i granskning.md, testlista åt Kakan för det som inte provats på riktigt.
```

Stora punkter (t.ex. en gemensam skalningsregel för alla fönster): låt hellre Fable bygga dem, eller granska det Opus byggt, om kvoten räcker.
