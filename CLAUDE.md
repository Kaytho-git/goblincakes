# GOBLINCAKES – projektöversikt för Claude Code

**Allt detaljerat (hur varje funktion är byggd, vad som är provat, historik, beslut i detalj) står i [`docs/anteckningar.md`](docs/anteckningar.md).** Läs den inte hel – `grep -n` på funktionens namn/fil och läs bara stycket. Nya detaljer skrivs där (eller i koden), inte här. Den här filen ska hållas kort (< 15 KB) – den följer med i varje anrop.

## Projektet
Personlig Linux-distro byggd med **BlueBuild**, Fedora Kinoite (KDE Plasma 6) via Universal Blue. Repo `Kaytho-git/goblincakes` (publikt). Tre varianter:
- `goblincakes` (bas `ublue-os/kinoite-main`, AMD/Intel, och den ISO:n installerar),
- `goblincakes-nvidia` (bas `kinoite-nvidia`, RTX 20xx/GTX 16xx+),
- `goblincakes-nvidia-legacy` (Nvidias 580-drivrutin för GTX 900/10, `files/scripts/install-nvidia-legacy.sh`).
Images `ghcr.io/kaytho-git/<variant>:latest`. Byte i GOBLINCAKES Config → Grafik (`goblincakes-gpu`).

**Recepten:** `recipes/recipe*.yml` har bara namn/bas; innehållet i `recipes/common-modules.yml` (moduler) och `recipes/common-stages.yml` (byggsteg) – ändra där. Bygget: `.github/workflows/build.yml` (matris, cosign, dagligen 06:00 UTC; BuildKit från `mirror.gcr.io`). Kör inte om ett äldre bygge när ett nyare finns (samma concurrency-grupp). Andra flöden: `build-iso.yml` (ISO, söndagar, release `iso`), `build-usb-creator.yml` (release `usb-skaparen`), `build-firefox-theme.yml`, `build-chrome-theme.yml` (Chrome-tema, release `chrome-tema` – höj `version` i manifesten vid ändring).

Användaren kör GOBLINCAKES på riktiga datorn (Claude Code körs där – prova direkt), har VS Code, redigerar ibland på GitHub. Nybörjare på Git – förklara kort.

## Arbetssätt (användarens beslut)
- **Kör alltid `git pull` innan du ändrar något.**
- **Jobba direkt i `main`** – inga grenar/PR, även om sessionen föreslår annat.
- **Pusha först när ≥ 5 commits väntar** (`git rev-list --count origin/main..HEAD`) eller när användaren ber om det. Före push `git pull --rebase`. Säg i svaret hur många commits som väntar.
- **Nyheter:** varje ändring användaren märker får en rad överst i `files/system/usr/share/goblincakes/nyheter.txt` (`ÅÅÅÅ-MM-DD`, två mellanslag, vanlig svenska, inte teknisk). `goblin update`/pilen/Config visar nya rader.
- **CLAUDE.md:** bara en kort rad per ny funktion i Status nedan; detaljerna i `docs/anteckningar.md`.
- Uppskatta storleken före stora byggen (veckokvoten); lätta delar kan gå till Kakan (Goblin AI) om inget spel kör.
- Ändra aldrig filer i spelens installation (WoW m.fl.) – undantag: filer som speltillverkaren själv avsett, t.ex. CS2:s GSI-cfg. Rör inte Archons lagring. Spotify-programmet ändras inte (ingen Spicetify).
- README: bara funktioner av allmänt intresse – inget om användarens dator, inga självklarheter.

## När användaren hälsar ("hej" o.d.) i en ny session
Kör `git pull`, svara med vilket steg hen är på (första ej avbockade i Status) och visa steglistan med status (klart / pågår / kvar). Kort, på svenska.

## Konventioner i koden
- **Egna fönster** = PySide6 + QML i Configs stil (platt, raka hörn, egna komponenter utan Qt Quick Controls: FlatButton/CheckSquare/FlatScrollBar/FlatField kopieras mellan fönstren). Varje Flickable/ListView får `FastWheel { flick: <id> }`. Varje FileDialog/FolderDialog: `onVisibleChanged: backend.sharpText()`. `QT_SCALE_FACTOR=0.8` för våra fönster. Ett fönster i taget via QLocalServer.
- **Färg:** accenten är valbar (`accent.py`, `goblincakes-accent`). I QML: `accent.color` (aldrig `"#2F6FED"`), `accent.text` för text i accentfärg, `accent.on` på fylld accent.
- **Ikoner för egna program:** loggans goblinhuvud oförändrat + cupcaken utbytt mot något som visar programmet; 2–3 varianter, användaren väljer. `files/system/usr/share/icons/hicolor/scalable/apps/goblincakes-<program>.svg`, `QIcon.fromTheme(…, QIcon(<fil>))`.
- **`goblin`-kommandon:** `files/system/usr/bin/goblin` – funktion `cmd_<namn>` + rad i `COMMANDS` + `case` längst ner. Hjälpare i `files/system/usr/libexec/goblincakes-*`.
- **Utseende/layout:** ändring i look-and-feel/layout → höj `LAYOUT_VERSION` i `goblincakes-firstlogin`. Systemfältslistor → höj `SYSTRAY_VERSION`. Engångsfixar för befintliga användare i `files/system/etc/xdg/plasma-workspace/env/goblincakes-refresh.sh` (flaggfil per fix).
- **Två kopior:** låsskärm och utloggning finns både i look-and-feel-paketet och i `files/system/usr/share/goblincakes/plasma-shell/` – ändra båda. Chrome/Brave/Chromium-policyerna – ändra alla tre.
- Plasma-temats SVG:er genereras av `tools/plasma-frames.py`; Plymouth-bilder av `tools/plymouth-render.js`; lärlägets kurser av `tools/learn-src/` (validera med `tools/learn-validate.py`).
- KWin-skriptet `files/system/usr/share/kwin/scripts/goblincakes-windows/` sköter fönsterplacering (Config i mitten, spel/regler till skärm, rutor, webbappar, AppGrid, goblin graph/GoblinAmp-platser). `tile/apply.js` delar `fitTileToWindow` med det – ändra båda.
- **Kakans karta** `files/system/usr/share/goblincakes/ai/karta.md`: ny eller ändrad del → uppdatera dess `##`-avsnitt (filer, hjälpprogram, tjänster, hur man kollar). Kakan läser även docs/ – skriv aldrig facit till hennes prov där.
- Testa fönster offscreen och med attrapper; skriv i CLAUDE.md/anteckningar vad som är provat på riktigt och vad som inte är det.

## Design (källan: https://claude.ai/artifact/BqT4GjvtTacjAgiCnRKwqt – följ den exakt)
Palett: Void #07090D, Night #0E1420, Deep #12203A, Accent #2F6FED, Frost #E6ECF5, dämpad text #8B98AD, ramar #1E2A40/#1A2438, toppfält #05070A, namnlist/paneler #0B1018. Typsnitt Chakra Petch (rubriker), IBM Plex Sans (gränssnitt), IBM Plex Mono. Allt platt med raka hörn. Logga: vit goblinhuvud-siluett ovanpå en blå cupcake. Utloggning: "Goodbye! See you next raid!". Tema efter intressena WoW och bågskytte. Dockan har apparnas originalikoner (inga linjeikoner).

## Beslut (kort – motiveringar i anteckningarna)
- Grundinstallationen enkel: resten väljs i GOBLINCAKES Config. Undantag: Steam i imagen (RPM). Inte VS Code/Wine/snapd/kalenderpaket i imagen.
- Atomiskt, rollback ska fungera, Fedoras standardkärna, inte baserat på Bazzite.
- Discord = Discords egen Linux-version (inte Flatpak). Ghostty standardterminal (Konsole valbar).
- ISO: en stor live-ISO per variant (vanlig + Nvidia), installerar utan internet; USB-skaparen hämtar den från releasen.
- Ianseo lokalt som standard; nätverk och internet (Cloudflare-tunnel + lösenord) som reglage.
- Lokal AI (Ollama) och lärläget: Bara lokalt som standard för läraren; spelvakten stänger av Ollama medan spel kör.
- GoblinRecorder: ingen ständig inspelning; raid från pull till END, M+ från nyckel till slut.
- Discord-kanalnamn: bara GOBLINCAKES-guildens får till GitHub (krypterat), andra servrar stannar lokalt.

## Status (detaljer: grep i docs/anteckningar.md)
**Testas på riktig installation, inte i VM:en.**
- [x] Steg 1: bas-recept (paket, Flatpaks, udev, tjänster)
- [x] Ghostty som standardterminal (VM-wrapper för OpenGL)
- [x] Steg 3: KDE-utseende + varumärke (tema, ramar, paneler, splash, Plymouth, inloggning/SDDM-tema, låsskärm, utloggning)
- [x] AppGrid med raka hörn (byggsteget `appgrid-square`), halva storleken
- [x] `goblin update` + grön/färgad uppdateringsmarkering i toppfältet, Config → Uppdatera
- [x] Steg 4: GOBLINCAKES Config (Program, Förinstallerat, Inställningar, Fönster, Grafik, Uppdatera; webbappar, huvudwebbläsare, starta vid inloggning)
- [x] Steg 5: Ianseo i container (+ systemfältsikon, nätverk, internet)
- [x] Goblin AI (fönster, Meta+A, Meta+§, terminal; lokal AI, bilder, projekt, lärläge, verktyg: sök/WCL/wowfel/sport/systemfel/cs2/wowstats, minne, ♥/👎-lärdomar, avatar, egna knappar, Spara som PDF/Word; inmatning i terminalstil: ↑/↓, Ctrl+R, /kommandon)
- [x] Laptop och dubbla grafikkort (ej testat – kräver laptop)
- [x] Grafikdrivrutiner: tre varianter, Grafik-fliken, Secure Boot
- [x] Diskar: automontering, ägare, I/O-schemaläggare
- [x] Spelpaket 2: MangoHud, goblin frames, NTSYNC, Xbox-kontroller, Battle.net/WoW-länkar, TV-läge, shaders, ljud
- [x] Program för intressena (GPU Screen Recorder, Pika Backup, Ianseo i nätverket)
- [x] Toppfältet: öppna program + Spelas nu (musik, Discord-röst, Steam-nedladdning/shaders, Goblin AI, trådlösa enheters batteri)
- [x] Dolda Fedora-program + Avinstallera program
- [x] Skärmar med olika Hz, program på vald skärm (`goblin screen`)
- [ ] Notis om ny Fedora-version (kan inte testas förrän Fedora 45 i `latest`)
- [x] Version (CalVer) + Config-förbättringar
- [x] Steg 6: installations-ISO + GOBLINCAKES USB (signering via SignPath väntar på ansökan)
- [x] Automatiska systemuppdateringar (reglage)
- [x] Spel från terminalen (`goblin play`, egna ord, `goblin play dock <spel>`)
- [x] Spelverktyg + gaming-optimering (reglage)
- [x] Spelläge (automatiskt under spel: GameMode, uppdateringar väntar, Akonadi/Baloo/WoWUp vilar, OBS stängs efter spel; `gaming.py` = vad som är ett spel)
- [x] goblin graph (ljudstaplar i klassfärger)
- [x] GoblinRecorder (WoW-inspelning med OBS, WCL, YouTube, testinspelning, systemfält; CS2-matcher via GSI → 2K–ACE-klipp + alla kills, matchen tas bort; CS2-demon läses: egna siffror, vunna clutchar som klipp; WoW Stats/CS2 Stats sammanställt lokalt, per säsong med arkiv; privata CS2-servrar under PRIVAT; spelikon på korten)
- [x] Plasma 6.8-förberedelser
- [x] Välj färg (blå + 13 klassfärger)
- [x] Chrome/Brave/Chromium-tema, Firefox-tema
- [x] Discord i GOBLINCAKES-stil (Vencord, eget val i Config; läggs in igen efter Discord-uppdateringar)
- [x] Tiling med egna regler (Config → Fönster, layouter, Meta+Ctrl+1–9)
- [x] GoblinAmp (Winamp-lik spelare: egen musik, Spotify-listor, sök/egna listor, spara album, GENRER med Last.fm, MPRIS, GRAF)
- [x] ChatGPT-appen (OpenAIs RPM uppackad i hemmappen, `goblincakes-chatgpt`; Goblin AI → "Skicka till ChatGPT" via urklipp) – ej provad med riktiga paketet

## Att göra
- [ ] **Kakan självgående – nästa veckas plan, punkt 1–8** (tool calling, arbetsloop, filer, kommandon i tre nivåer, skrivbordet, webbsidor, påminnelser, MCP, 9 = röst med tryck-och-prata, 10–16 = mätverktyg, kunskap om GOBLINCAKES, kända lösningar, kontroll efter uppdatering, "Skicka till Claude", testa åt Claude, byggstatus; 17 = Claude Haiku via abonnemanget med Kakans verktyg, sist; steg 0 = modellprov; Kakan ändrar aldrig koden i repot; + förslag mätverktyg för lagg). Detaljer: grep "veckans plan" i anteckningarna.
- [ ] **Epics launcher i Config** (väntar på paketformatet; Fortnite/EAC-krav).
- [ ] **GoblinRecorder för CS2** – byggt 22 okt: GSI (2K–ACE-klipp + alla kills, matchen tas bort), demon (egna siffror, TTD/första skottet/spray/counter-strafe, vunna clutchar som klipp), CS2 Stats (clutchar 1v1–1v4, ACE, pilar, utfällbar match med alla tio, per säsong med Arkiv). Deathmatch provat på riktigt. Kvar: efter nästa image en riktig Premier/Competitive till slut + nedladdad demo – stämmer siffrorna mot Leetify, blir klippen rätt, börjar demons servernamn med "Valve" (annars hamnar den under PRIVAT)?
- [ ] **Engelsk version** (qsTr/gettext; 2–3 långa sessioner).
- [ ] **GoblinAmp:** spellistan ska kunna kopplas loss från spelaren och dras vart man vill (eget fönster); GRAF-fönstret genomskinligt i stället för svart bakgrund.

## Framtida idéer (byggs bara på begäran – detaljer i anteckningarna)
Kakan lär sig steg 2 (LoRA-finjustering), Goblin AI som vardags-AI (röst, Google-tjänster), Steam-DM i Spelas nu (väntar på freedesktop-notiser), GoblinRecorder fristående (Flatpak/AppImage), Ianseo-nedladdningssida på Simply med TOTP.
