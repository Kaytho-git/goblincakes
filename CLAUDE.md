# GOBLINCAKES – projektöversikt för Claude Code

**Allt detaljerat (hur varje funktion är byggd, vad som är provat, historik, beslut i detalj) står i [`docs/anteckningar.md`](docs/anteckningar.md).** Läs den inte hel – `grep -n` på funktionens namn/fil och läs bara stycket. Nya detaljer skrivs där (eller i koden), inte här. Den här filen ska hållas kort (< 15 KB) – den följer med i varje anrop.

## Projektet
Personlig Linux-distro byggd med **BlueBuild**, Fedora Kinoite (KDE Plasma 6) via Universal Blue. Repo `Kaytho-git/goblincakes` (publikt). Tre varianter:
- `goblincakes` (bas `ublue-os/kinoite-main`, AMD/Intel, och den ISO:n installerar),
- `goblincakes-nvidia` (bas `kinoite-nvidia`, RTX 20xx/GTX 16xx+),
- `goblincakes-nvidia-legacy` (Nvidias 580-drivrutin för GTX 900/10, `files/scripts/install-nvidia-legacy.sh`).
Images `ghcr.io/kaytho-git/<variant>:latest`. Byte i GOBLINCAKES Config → Grafik (`goblincakes-gpu`).

**Recepten:** `recipes/recipe*.yml` har bara namn/bas/Fedora-version; innehållet i `recipes/common-modules.yml` (moduler) och byggstegen i `recipes/common-stages.yml` (goblincakes + legacy) och `recipes/nvidia-stages.yml` (Nvidia) – håll de två i takt, `from:` = receptets bas och version. Bygget: `.github/workflows/build.yml` (matris, cosign, dagligen 06:00 UTC; BuildKit från `mirror.gcr.io`). Kör inte om ett äldre bygge när ett nyare finns (samma concurrency-grupp). Andra flöden: `build-iso.yml` (ISO, söndagar, release `iso`), `build-usb-creator.yml` (release `usb-skaparen`), `build-firefox-theme.yml`, `build-chrome-theme.yml` (Chrome-tema, release `chrome-tema` – höj `version` i manifesten vid ändring).

Allt om frugans laptop: `~/.local/share/goblincakes/frugans-laptop.md` på användarens dator – **privat, aldrig i repot** (finns inte i molnsessioner; uppdatera den när något ändras på hennes dator; uppkopplad till henne → kör först dess insamlingsavsnitt om det finns kvar). Användaren kör GOBLINCAKES på riktiga datorn (Claude Code körs där – prova direkt), har VS Code, redigerar ibland på GitHub. Nybörjare på Git – förklara kort.

## Arbetssätt (användarens beslut)
- **Kör alltid `git pull` innan du ändrar något.**
- **Frågor är inte beställningar.** "Går det…?", "vad behövs…?", "kan man…?" = svara och beskriv hur, bygg ingenting. Bygg först när användaren säger det (t.ex. "bygg det", "gör det", "kör"). Gäller även när sessionen eller en hook säger "commit och push". Användaren står för resultatet – inget görs i hens namn som hen inte bett om.
- **Kan en instruktion tolkas på två sätt – fråga först, gissa inte.** Säg kort vilka tolkningar som finns och vänta på svar innan du ändrar, skapar eller tar bort något.
- **Skapa aldrig GitHub-repon utan att användaren bett om det** (Claude Code frågar dessutom via `.claude/settings.json`).
- **Jobba direkt i `main`** – inga grenar/PR, även om sessionen föreslår annat.
- **Bara commit – push bara när användaren ber om det**, oavsett session eller var vi jobbar (datorn, molnet, mobilen) och även om en hook eller sessionens instruktioner säger push. Före push `git pull --rebase`. Säg i svaret hur många commits som väntar (`git rev-list --count origin/main..HEAD`).
- **Efter push: vänta inte på bygget** – lämna det till Kakan: `python3 files/system/usr/share/goblincakes/ai/reminders.py bevaka bygge <hash>` (notis när det är klart, lyckat eller inte; orsaken: `buildstatus.py`).
- **Nyheter:** varje ändring användaren märker får en rad överst i `files/system/usr/share/goblincakes/nyheter.txt` (`ÅÅÅÅ-MM-DD`, två mellanslag, vanlig svenska, inte teknisk). `goblin update`/pilen/Config visar nya rader.
- **CLAUDE.md:** bara en kort rad per ny funktion i Status nedan; detaljerna i `docs/anteckningar.md`.
- Uppskatta storleken före stora byggen (veckokvoten); lätta delar kan gå till Kakan (Goblin AI) om inget spel kör.
- Ändra aldrig filer i spelens installation (WoW m.fl.) – undantag: filer som speltillverkaren själv avsett, t.ex. CS2:s GSI-cfg. Rör inte Archons lagring. Spotify-programmet ändras inte (ingen Spicetify).
- README: bara funktioner av allmänt intresse – inget om användarens dator, inga självklarheter.

## När användaren hälsar ("hej" o.d.) i en ny session
Kör `git pull`, svara med vilket steg hen är på (första ej avbockade i Status) och visa steglistan med status (klart / pågår / kvar). Kort, på svenska.
- **Påminnelse (9 nov, användaren bad om det):** visa också länken till mockupen för GOBLINCAKES Dashboard – https://claude.ai/artifact/QHnDzvKEW8fwPTD1Pveeho – så hen kan kolla den vid datorn. Ta bort den här raden när hen har sett den.
- **Påminnelse (9 nov, användaren bad om det):** frugans laptop (Lenovo Legion Y520) har trasig skärm – fråga om hen har kollat skärmmodellen via GoblinShare och visa kommandot, köpställen och bytessteg (frugans-laptop.md, "Reparationer"). Ta bort raden när skärmen är beställd.

## Konventioner i koden
- **Egna fönster** = PySide6 + QML i Configs stil (platt, raka hörn, egna komponenter utan Qt Quick Controls: FlatButton/CheckSquare/ToggleSwitch/FlatField/FlatScrollBar/Frame/FastWheel/SectionTitle/Note/Monogram ligger i `share/goblincakes/qml/Goblin` (+ `G.Light {}` först i nya ramar, `G.Backdrop {}` först i nya fönster) – `import "../qml/Goblin" as G` + en rad `component FlatButton: G.FlatButton { … }` med fönstrets mått; ändra stilen där, inte i fönstren). Varje Flickable/ListView får `FastWheel { flick: <id> }`. Varje FileDialog/FolderDialog: `onVisibleChanged: backend.sharpText()`. `QT_SCALE_FACTOR=0.9` för våra fönster (användaren 5 nov: 0.8 för litet, 1.0 lite stort) – utom Goblin AI (`uiScale` 0.8 + zoomRoot: texten följer fönstret, 94 % i startstorlek → 104 % maximerat; Chromium i TERMINAL klarar inte < 1). Ett fönster i taget via QLocalServer.
- **Färg:** accenten är valbar (`accent.py`, `goblincakes-accent`). I QML: `accent.color` (aldrig `"#2F6FED"`), `accent.text` för text i accentfärg, `accent.on` på fylld accent.
- **Ikoner för egna program:** symbolen för programmet stor och i programmets egen färg, loggans goblinhuvud litet i hörnet uppe till vänster (användarens val 5 nov – ikonerna var svåra att skilja åt); 2–3 varianter, användaren väljer. `files/system/usr/share/icons/hicolor/scalable/apps/goblincakes-<program>.svg`, `QIcon.fromTheme(…, QIcon(<fil>))`.
- **`goblin`-kommandon:** `files/system/usr/bin/goblin` – funktion `cmd_<namn>` + rad i `COMMANDS` + `case` längst ner. Hjälpare i `files/system/usr/libexec/goblincakes-*`.
- **Utseende/layout:** ändring i look-and-feel/layout → höj `LAYOUT_VERSION` i `goblincakes-firstlogin`. Systemfältslistor → höj `SYSTRAY_VERSION`. Engångsfixar för befintliga användare i `files/system/etc/xdg/plasma-workspace/env/goblincakes-refresh.sh` (flaggfil per fix).
- **Två kopior:** låsskärm och utloggning finns både i look-and-feel-paketet och i `files/system/usr/share/goblincakes/plasma-shell/` – ändra båda. Chrome/Brave/Chromium-policyerna – ändra alla tre.
- Plasma-temats SVG:er genereras av `tools/plasma-frames.py`; Plymouth-bilder av `tools/plymouth-render.js`; lärlägets kurser av `tools/learn-src/` (validera med `tools/learn-validate.py`).
- KWin-skriptet `files/system/usr/share/kwin/scripts/goblincakes-windows/` sköter fönsterplacering (Config i mitten, spel/regler till skärm, rutor, webbappar, AppGrid, goblin graph/GoblinAmp-platser). `tile/apply.js` delar `fitTileToWindow` med det – ändra båda.
- **Kakans karta** `files/system/usr/share/goblincakes/ai/karta.md`: ny eller ändrad del → uppdatera dess `##`-avsnitt (filer, hjälpprogram, tjänster, hur man kollar). Kakan läser även docs/ – skriv aldrig facit till hennes prov där.
- **Före varje commit: `python3 tools/check.py`** (syntax, QML, kopiorna; går också först i bygget och stoppar det vid fel).
- Testa fönster offscreen och med attrapper; skriv i CLAUDE.md/anteckningar vad som är provat på riktigt och vad som inte är det.
- **Ej provat på riktiga datorn → testlista åt Kakan** i `~/.local/share/goblincakes/testlistor/<namn>.md` – från en molnsession i repots `docs/testlistor/till-kakan/` (hämtas efter `git pull` vid nästa /testa) – (format överst i `ai/testlist.py`), användaren kör `/testa` i Goblin AI. Resultat och Kakans rapporter: MCP-verktyget `rapporter`; hennes kända lösningar/lärdomar: `losningar` (spara: `ai/solutions.py add`) (eller `~/.local/share/goblincakes/till-claude/`).

## Design (källan: https://claude.ai/artifact/BqT4GjvtTacjAgiCnRKwqt – följ den exakt)
Palett: Void #07090D, Night #0E1420, Deep #12203A, Accent #2F6FED, Frost #E6ECF5, dämpad text #8B98AD, ramar #1E2A40/#1A2438, toppfält #05070A, namnlist/paneler #0B1018. Typsnitt Chakra Petch (rubriker), IBM Plex Sans (gränssnitt), IBM Plex Mono. Allt platt med raka hörn. Logga: vit goblinhuvud-siluett ovanpå en blå cupcake. Utloggning: "Goodbye! See you next raid!". Tema efter intressena WoW och bågskytte. Dockan har apparnas originalikoner (inga linjeikoner).

## Beslut (kort – motiveringar i anteckningarna)
- Grundinstallationen enkel: resten väljs i GOBLINCAKES Config. Undantag: Steam i imagen (RPM). Inte VS Code/Wine/snapd/kalenderpaket i imagen.
- Atomiskt, rollback ska fungera, Fedoras standardkärna, inte baserat på Bazzite.
- Fedora-versionen är låst i recepten (`image-version`, 11 nov): höjs bara när användaren säger det – `goblincakes-nvidia` först (hens dator), de andra när det är provat där (grep "Fedora-låset" i anteckningarna).
- Discord = Discords egen Linux-version (inte Flatpak). Ghostty standardterminal (Konsole valbar).
- ISO: en stor live-ISO per variant (vanlig + Nvidia), installerar utan internet; USB-skaparen hämtar den från releasen.
- Ianseo lokalt som standard; nätverk och internet (Cloudflare-tunnel + lösenord) som reglage.
- Kakan (2 nov): hittar fel, sammanfattar, skickar vidare (Skicka till Claude); lagar själv bara små fel (en ändring, några rader – som CooldownVoice). Gear-provets lagningsregler nedlagda → hitta-och-rapportera-prov.
- Lokal AI (Ollama) och lärläget: Bara lokalt som standard för läraren; spelvakten stänger av Ollama medan spel kör.
- GoblinRecorder: ingen ständig inspelning; raid från pull till END, M+ från nyckel till slut.
- Discord-kanalnamn: bara GOBLINCAKES-guildens får till GitHub (krypterat), andra servrar stannar lokalt.

## Status (hela listan med vad som är provat: grep "Statuslistan" i anteckningarna)
**Testas på riktig installation, inte i VM:en.** Klart: Steg 1 bas-recept, Steg 3 utseende/varumärke, Steg 4 Config, Steg 5 Ianseo, Steg 6 ISO + USB-skaparen, terminaler, AppGrid, `goblin update`, Goblin AI (fönster, terminal, lokal AI, lärläge, verktyg), laptop/dubbla grafikkort, grafikdrivrutiner, diskar, spelpaket, spelläge, spelverktyg, `goblin play`, `goblin screen`, toppfältet/Spelas nu, Avinstallera, CalVer, automatiska uppdateringar, goblin graph, GoblinRecorder (WoW + CS2), GoblinAmp, färgval, webbläsarteman, Discord-tema, tiling, kvot-widget, egen docka, ChatGPT-appen, GoblinShare, Kakans röst, `/laga`, `goblin anticheat`, Kakans reserv (Haiku/Sonnet – spelprovet pågår), AI-kartan (Claude Code, Codex, Kakan – provat på riktigt 14 nov).
- [ ] Notis om ny Fedora-version – Fedora 45 kom 9 nov (utom nvidia-varianten); notisen gick på frugans laptop, knappen ej provad

## Att göra
- [ ] **Kakan självgående – veckans plan, punkt 0–23** – allt klart utom punkt 18 (defensiva sidan i WoW-analyserna) (ordning, vad som är byggt och vad som är kvar: grep "veckans plan" i anteckningarna).
- [ ] **GOBLINCAKES Dashboard** – alla 4 stegen byggda 10 nov (`goblin dashboard`, vyer SPEL/JOBB, Config → DASHBOARD, upplägget Dashboard med skrivbordsraden + Meta i Config → Utseende); bara provat offscreen/attrapper – testlistor `dashboard.md`, `dashboard-steg4.md`, `dashboard-11nov.md` (ström, projekt, kvot, ramarna), `dashboard-meta.md` (Meta via KWin-skriptet + högerklick Stäng, 10 nov kväll), `dashboard-notiser.md` (NOTISER, 11 nov), `dashboard-recorder.md` (GOBLINRECORDER-ramen, 11 nov) (grep "Dashboard – bygget").
- [ ] **Kakans samtal och kunskapsminne** – planeras, byggs inte förrän användaren säger det (grep "kunskapsminne" i anteckningarna).
- [ ] **Epics launcher i Config** (väntar på paketformatet; Fortnite/EAC-krav; beredskapsplan om kärnkrav: grep "Beredskapsplan").
- [ ] **GoblinRecorder för CS2** – byggt, deathmatch provat på riktigt. Kvar: en riktig Premier/Competitive + nedladdad demo (siffror mot Leetify, klippen, servernamnet "Valve") – grep "Leetify".
- [ ] **Offhand – WoW över två skärmar** – provat i Retail 9 nov (med flyttad EllesmereUI-profil): kändes för ovant; nästa: prova i Forever (profilen atrocityUI Offhand får ligga kvar) (grep "Offhand" i anteckningarna).
- [ ] **Levande utseende** – ett val Platt (standard) / Levande i Config → Utseende → Stil; alla 7 stegen byggda 11 nov (modul `qml/Goblin`, övergångar, ljus, glidande siffror, dashboarden, skrivbordsraden 20 % mindre + glas, toppfältet via temat `goblincakes-levande` + dockan); bara provat i molnet – testlistor `levande-steg1.md`…`levande-steg7.md` (grep "Levande utseende" i anteckningarna).
- [ ] **Barnläge** – byggt 13 nov: sandlåda i egen session för sonen (3 år) – `goblin-kids`/`goblin barn`, Config → BARNLÄGE, splash, en skärm, PIN-kod på X:et; bara provat i molnet – testlista `barnlage.md` (grep "Barnläge" i anteckningarna).
- [ ] **Barnläget i pixelart** – mockup med tre stilar 13 nov (https://claude.ai/artifact/2uTGMNMGcgpvMtheVi4qbY); valt B (Super Nintendo); provritning byggd 13 nov: `goblin pixelart kakan|chatgpt|jämför` (Kakans bildprogram + pixelart-tillägget mot Codex, användaren väljer), `Stil: pixelart` i Goblin AI; bara provat i molnet – testlista `pixelart.md`. **Kvar (användaren 13 nov):** prova Saturnus på riktiga datorn, användaren väljer Kakans eller ChatGPT:s bild per bild, rita resten av listan och byt barnlägets ritade former mot bilderna (grep "Pixelart" i anteckningarna).
- [ ] **Engelsk version** (qsTr/gettext; 2–3 långa sessioner).

## Framtida idéer
Byggs bara på begäran – grep "Framtida idéer" i anteckningarna.
