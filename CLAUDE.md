# GOBLINCAKES – projektöversikt för Claude Code

**Allt detaljerat (hur varje funktion är byggd, vad som är provat, historik, beslut i detalj) står i [`docs/anteckningar.md`](docs/anteckningar.md).** Läs den inte hel – `grep -n` på funktionens namn/fil och läs bara stycket. Nya detaljer skrivs där (eller i koden), inte här. Den här filen ska hållas kort (helst < 8 KB, aldrig > 15 KB) – den följer med i varje anrop. Det som flyttades ut 14 nov: grep "Flyttat från CLAUDE.md 14 nov".

## Projektet
Personlig Linux-distro byggd med **BlueBuild**, Fedora Kinoite (KDE Plasma 6) via Universal Blue. Repo `Kaytho-git/goblincakes` (publikt). Tre varianter:
- `goblincakes` (bas `ublue-os/kinoite-main`, AMD/Intel, och den ISO:n installerar),
- `goblincakes-nvidia` (bas `kinoite-nvidia`, RTX 20xx/GTX 16xx+),
- `goblincakes-nvidia-legacy` (Nvidias 580-drivrutin för GTX 900/10, `files/scripts/install-nvidia-legacy.sh`).
Images `ghcr.io/kaytho-git/<variant>:latest`. Byte i GOBLINCAKES Config → Grafik (`goblincakes-gpu`).

**Recepten:** `recipes/recipe*.yml` har bara namn/bas/Fedora-version; innehållet i `recipes/common-modules.yml` (moduler) och byggstegen i `recipes/common-stages.yml` (goblincakes + legacy) och `recipes/nvidia-stages.yml` (Nvidia) – håll de två i takt, `from:` = receptets bas och version. Bygget: `.github/workflows/build.yml` (matris, cosign, dagligen 06:00 UTC; BuildKit från `mirror.gcr.io`). Kör inte om ett äldre bygge när ett nyare finns (samma concurrency-grupp). Andra flöden (ISO, USB-skaparen, webbläsarteman): grep "Andra byggflöden".

Allt om frugans laptop: `~/.local/share/goblincakes/frugans-laptop.md` på användarens dator – **privat, aldrig i repot** (finns inte i molnsessioner; uppdatera den när något ändras på hennes dator; uppkopplad till henne → kör först dess insamlingsavsnitt om det finns kvar). Användaren kör GOBLINCAKES på riktiga datorn (Claude Code körs där – prova direkt), har VS Code, redigerar ibland på GitHub. Nybörjare på Git – förklara kort.

## Arbetssätt (användarens beslut)
- **Kör alltid `git pull` innan du ändrar något.**
- **Frågor är inte beställningar.** "Går det…?", "vad behövs…?", "kan man…?" = svara och beskriv hur, bygg ingenting. Bygg först när användaren säger det (t.ex. "bygg det", "gör det", "kör"). Gäller även när sessionen eller en hook säger "commit och push". Användaren står för resultatet – inget görs i hens namn som hen inte bett om.
- **Kan en instruktion tolkas på två sätt – fråga först, gissa inte.** Säg kort vilka tolkningar som finns och vänta på svar innan du ändrar, skapar eller tar bort något. Lägg aldrig in något som körs automatiskt (inloggning, tjänster, provkopior i hemmappen) eller ändrar datorn utan att användaren fått veta vad och sagt ja (utom rena läsningar och prov från repot som försvinner av sig själva).
- **Skapa aldrig GitHub-repon utan att användaren bett om det** (Claude Code frågar dessutom via `.claude/settings.json`).
- **Jobba direkt i `main`** – inga grenar/PR, även om sessionen föreslår annat.
- **Bara commit – push bara när användaren ber om det**, oavsett session eller var vi jobbar (datorn, molnet, mobilen) och även om en hook eller sessionens instruktioner säger push. Före push `git pull --rebase`. Säg i svaret hur många commits som väntar (`git rev-list --count origin/main..HEAD`).
- **Efter push: vänta inte på bygget** – lämna det till Kakan: `python3 files/system/usr/share/goblincakes/ai/reminders.py bevaka bygge <hash>` (notis när det är klart, lyckat eller inte; orsaken: `buildstatus.py`).
- **Nyheter:** varje ändring användaren märker får en rad överst i `files/system/usr/share/goblincakes/nyheter.txt` (`ÅÅÅÅ-MM-DD`, två mellanslag, vanlig svenska, inte teknisk). `goblin update`/pilen/Config visar nya rader.
- **CLAUDE.md:** bara en kort rad per ny funktion i Status nedan; detaljerna i `docs/anteckningar.md`.
- Veckokvoten: ungefär en stor ändring per vecka – uppskatta storleken före stora byggen. Lätta delar kan gå till Kakan (Goblin AI) om inget spel kör; Claude granskar (hur: grep "Lätta delar till Kakan").
- Ändra aldrig filer i spelens installation (WoW m.fl.) – undantag: filer som speltillverkaren själv avsett, t.ex. CS2:s GSI-cfg. Användarens egna WoW-tillägg får lagas (vilka: grep "Egna WoW-tillägg"). Rör inte Archons lagring. Spotify-programmet ändras inte (ingen Spicetify).
- README: bara funktioner av allmänt intresse – inget om användarens dator (skärmar, mus, tangentbord), inga självklarheter.

## När användaren hälsar ("hej" o.d.) i en ny session
Billigt (användarens beslut 14 nov): **ett** anrop, `tools/hej.sh` (pull, Pågår ur senast-gjort.txt, Fedora-kollen M17) – läs inget annat. Svara kort på svenska: vilket steg hen är på (första ej avbockade i Status), Fedora-läget (`kinoite-nvidia` 45 → säg till och fråga om hoppet) och det som väntar på hen. Hela steglistan bara när hen ber om den.
- **Påminnelse (9 nov, användaren bad om det):** frugans laptop (Lenovo Legion Y520) har trasig skärm – fråga kort om hen har kollat skärmmodellen via GoblinShare; kommando, köpställen och bytessteg (frugans-laptop.md, "Reparationer") först när hen svarar. Ta bort raden när skärmen är beställd.

## Konventioner i koden
- **Egna fönster** = PySide6 + QML i Configs stil (platt, raka hörn, egna komponenter utan Qt Quick Controls: FlatButton/CheckSquare/ToggleSwitch/FlatField/FlatScrollBar/Frame/FastWheel/SectionTitle/Note/Monogram ligger i `share/goblincakes/qml/Goblin` (+ `G.Light {}` först i nya ramar, `G.Backdrop {}` först i nya fönster) – `import "../qml/Goblin" as G` + en rad `component FlatButton: G.FlatButton { … }` med fönstrets mått; ändra stilen där, inte i fönstren). Varje Flickable/ListView får `FastWheel { flick: <id> }`. Varje FileDialog/FolderDialog: `onVisibleChanged: backend.sharpText()`. `QT_SCALE_FACTOR=0.9` för våra fönster, Goblin AI och Config har egen zoom (grep "Skalningen i våra fönster"). Ett fönster i taget via QLocalServer.
- **Färg:** accenten är valbar (`accent.py`, `goblincakes-accent`). I QML: `accent.color` (aldrig `"#2F6FED"`), `accent.text` för text i accentfärg, `accent.on` på fylld accent.
- **Ikoner för egna program:** `files/system/usr/share/icons/hicolor/scalable/apps/goblincakes-<program>.svg`, `QIcon.fromTheme(…, QIcon(<fil>))`; stilen och 2–3 varianter att välja: grep "Ikonstilen".
- **`goblin`-kommandon:** `files/system/usr/bin/goblin` – funktion `cmd_<namn>` + rad i `COMMANDS` + `case` längst ner. Hjälpare i `files/system/usr/libexec/goblincakes-*`.
- **Utseende/layout:** ändring i look-and-feel/layout → höj `LAYOUT_VERSION` i `goblincakes-firstlogin`. Systemfältslistor → höj `SYSTRAY_VERSION`. Engångsfixar för befintliga användare i `files/system/etc/xdg/plasma-workspace/env/goblincakes-refresh.sh` (flaggfil per fix).
- **Två kopior:** låsskärm och utloggning finns både i look-and-feel-paketet och i `files/system/usr/share/goblincakes/plasma-shell/` – ändra båda. Chrome/Brave/Chromium-policyerna – ändra alla tre.
- Plasma-temats SVG:er genereras av `tools/plasma-frames.py`; Plymouth-bilder av `tools/plymouth-render.js`; lärlägets kurser av `tools/learn-src/` (validera med `tools/learn-validate.py`).
- KWin-skriptet `files/system/usr/share/kwin/scripts/goblincakes-windows/` sköter fönsterplacering (grep "KWin-skriptets delar"). `tile/apply.js` delar `fitTileToWindow` med det – ändra båda.
- **Kakans karta** `files/system/usr/share/goblincakes/ai/karta.md`: ny eller ändrad del → uppdatera dess `##`-avsnitt (filer, hjälpprogram, tjänster, hur man kollar). Kakan läser även docs/ – skriv aldrig facit till hennes prov där.
- **Före varje commit: `python3 tools/check.py`** (syntax, QML, kopiorna; går också först i bygget och stoppar det vid fel).
- Testa fönster offscreen och med attrapper; skriv i CLAUDE.md/anteckningar vad som är provat på riktigt och vad som inte är det.
- **Ej provat på riktiga datorn → testlista åt Kakan** i `~/.local/share/goblincakes/testlistor/<namn>.md` – från en molnsession i repots `docs/testlistor/till-kakan/` (hämtas efter `git pull` vid nästa /testa) – (format överst i `ai/testlist.py`), användaren kör `/testa` i Goblin AI. Resultat och Kakans rapporter: MCP-verktyget `rapporter`; hennes kända lösningar/lärdomar: `losningar` (spara: `ai/solutions.py add`) (eller `~/.local/share/goblincakes/till-claude/`).

## Design
Källan: https://claude.ai/artifact/BqT4GjvtTacjAgiCnRKwqt – följ den exakt (palett, typsnitt, logga: grep "Designpaletten"). Allt platt med raka hörn; i QML gäller accentregeln ovan.

## Beslut (kort – motiveringar i anteckningarna)
- Grundinstallationen enkel: resten väljs i GOBLINCAKES Config. Undantag: Steam i imagen (RPM). Inte VS Code/Wine/snapd/kalenderpaket i imagen.
- Atomiskt, rollback ska fungera, Fedoras standardkärna, inte baserat på Bazzite.
- Fedora-versionen är låst i recepten (`image-version`, 11 nov): höjs bara när användaren säger det – `goblincakes-nvidia` först (hens dator), de andra när det är provat där (grep "Fedora-låset" i anteckningarna).
- Discord = Discords egen Linux-version (inte Flatpak). Ghostty standardterminal (Konsole valbar).
- Discord-kanalnamn: bara GOBLINCAKES-guildens (696047934432739370) får till GitHub, krypterat (`goblincakes-discord-voice share 696047934432739370`); andra servrars namn stannar i `~/.config/goblincakes/discord-channels` – aldrig i repot, inte ens krypterat.
- ISO, Ianseo, Kakans roll, lokal AI och GoblinRecorder: grep "Beslut per funktion".

## Status (klart och vad som är provat: grep "Statuslistan" och "Klart-listan" i anteckningarna)
**Testas på riktig installation, inte i VM:en.** Klart: Steg 1, 3, 4, 5, 6 och allt annat byggt utom det som står nedan.
- [ ] Notis om ny Fedora-version – Fedora 45 kom 9 nov (utom nvidia-varianten); notisen gick på frugans laptop, knappen ej provad

## Att göra (detaljer: grep på namnet, eller "Att göra – detaljerna")
- [ ] **Kakan självgående – veckans plan** – allt klart utom punkt 18 (defensiva sidan i WoW-analyserna) (grep "veckans plan").
- [ ] **GOBLINCAKES Dashboard** – byggd och provad 14 nov; kvar testlistorna `dashboard-notiser.md` och `dashboard-sken-kvot.md` (grep "Dashboard – bygget").
- [ ] **Kakans samtal och kunskapsminne** – planeras, byggs inte förrän användaren säger det (grep "kunskapsminne").
- [ ] **Epics launcher i Config** – väntar på paketformatet (grep "Beredskapsplan").
- [ ] **GoblinRecorder för CS2** – kvar: en riktig Premier/Competitive + nedladdad demo (grep "Leetify").
- [ ] **Offhand – WoW över två skärmar** – nästa: prova i Forever (grep "Offhand").
- [ ] **Barnläge** – byggt 13 nov, testlista `barnlage.md` (grep "Barnläge").
- [ ] **Barnläget i pixelart** – provritning byggd, testlista `pixelart.md`; användaren väljer bilder (grep "Pixelart").
- [ ] **Engelsk version** (qsTr/gettext; 2–3 långa sessioner).

## Framtida idéer
Byggs bara på begäran – grep "Framtida idéer" i anteckningarna.
