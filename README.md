# GOBLINCAKES OS &nbsp; [![bluebuild build badge](https://github.com/kaytho-git/goblincakes/actions/workflows/build.yml/badge.svg)](https://github.com/kaytho-git/goblincakes/actions/workflows/build.yml)

**En personlig Linux-distribution för spel, World of Warcraft och bågskytte – snygg, snabb och omöjlig att förstöra.**

GOBLINCAKES bygger på [Fedora Kinoite](https://fedoraproject.org/atomic-desktops/kinoite/) (KDE Plasma 6) via [Universal Blue](https://universal-blue.org/) och byggs automatiskt varje dag med [BlueBuild](https://blue-build.org/). Allt är platt, mörkt och fyrkantigt, med en goblin som maskot.

### ⬇ Ladda ner GOBLINCAKES USB

Programmet som gör ett installations-USB-minne åt dig (se [Installation](#med-goblincakes-usb-enklast)):

**[Windows](https://github.com/Kaytho-git/goblincakes/releases/download/usb-skaparen/GOBLINCAKES-USB-Windows.exe)** &nbsp;·&nbsp; **[Linux](https://github.com/Kaytho-git/goblincakes/releases/download/usb-skaparen/GOBLINCAKES-USB-Linux)** &nbsp;·&nbsp; [Alla filer](https://github.com/Kaytho-git/goblincakes/releases/tag/usb-skaparen)

## Målet

En dator som bara fungerar – för den som vill spela, raida och sköta bågskyttetävlingar utan att pilla med Linux:

- **Allt klart från start.** Rätt drivrutiner, rätt inställningar för spel och ett genomarbetat utseende redan vid första inloggningen.
- **Går inte att förstöra.** Systemet är *atomiskt*: varje uppdatering är en hel, testad version. Blir något fel väljer du förra versionen i startmenyn och är tillbaka på en minut.
- **Ett ställe för allt.** Program, inställningar, uppdateringar och grafikdrivrutiner sköts i ett eget fönster, *GOBLINCAKES Config* – ingen terminal behövs.
- **Håller sig uppdaterat.** En liten ruta i toppfältet visar när något nytt finns och vad det är; en knapp (eller `goblin update`) uppdaterar allt.
- **Egen installations-USB:** GOBLINCAKES USB gör ett USB-minne som installerar GOBLINCAKES på vilken dator som helst – precis som Windows eller SteamOS.

## Vad som finns i

### Utseende och skrivbord
- Eget tema i hela systemet: mörk palett, Chakra Petch och IBM Plex, raka hörn överallt.
- Egen startskärm, inloggning, låsskärm och utloggning (*"Goodbye! See you next raid!"*). Vid inloggningen väljer du **Skrivbord** eller **TV-läge**.
- **Toppfältet:** appmenyn (AppGrid) mitt på skärmen, öppna program, *Spelas nu*, veckonummer, klocka med svenska helgdagar i kalendern, och en ruta som visar när det finns uppdateringar.
- **Spelas nu** i toppfältet: vad Spotify eller musikspelaren spelar (klicka = pausa, scrolla = byt låt), och vilken Discord-röstkanal du är i.
- **Dockan** gömmer sig när ett fönster täcker den och kommer fram när muspekaren går mot skärmens nederkant. **Meta** öppnar appmenyn.
- Ghostty som terminal, med GOBLINCAKES-färger och en lista över `goblin`-kommandona i varje nytt fönster.
- Fedora-program som sällan behövs är dolda i appmenyn men finns kvar – och kan visas igen eller avinstalleras på riktigt (**Avinstallera program** i appmenyn).

### Spel
- **Steam** förinstallerat, plus Gamescope, GameMode och MangoHud (FPS-mätare). Windows-program utanför spelen: Bottles i GOBLINCAKES Config.
- **GE-Proton** hämtas och uppdateras automatiskt.
- **Starta spel från terminalen:** skriv spelets namn eller förkortning (t.ex. `wow`, `cs2`) så startas det via Steam.
- **Spel öppnas på huvudskärmen**, även om muspekaren står på en annan skärm.
- **Handkontroller:** Xbox via dongel, USB och Bluetooth (xone, xpadneo), plus de vanliga PlayStation- och Switch-reglerna.
- **TV-läge:** Steam Big Picture i helskärm, som en Steam Deck – välj det vid inloggningen eller starta det från appmenyn.
- **Emulatorer:** RetroDECK (Super Nintendo, Mega Drive, N64, PlayStation, GameCube, Switch med flera) och Steam ROM Manager, som lägger in spelen i Steam och TV-läget.
- **Snabbare:** NTSYNC för Windows-spel, och Steams förberedelse av shaders ("Bearbetar Vulkan-shaders") får mer kraft.
- **Flera skärmar:** varje skärm körs i sin egen uppdateringsfrekvens (t.ex. 180 Hz + 144 Hz), och den snabbaste blir huvudskärm.
- **Laptops** med två grafikkort: spel startar på det kraftfulla kortet, skrivbordet på det snåla.

### World of Warcraft
- Battle.net via Lutris med GE-Proton, installerat så att butiken fungerar.
- **WowUp, Raider.IO och Archon** installeras och uppdateras automatiskt.
- Mapparna för `Logs` och `AddOns` – för alla WoW-versioner, var de än ligger – länkas till `~/Games/WoW`. WowUp och Raider.IO hittar WoW själva; `goblin wow` talar om vad du väljer i Archon.

### Discord
- Discords egen Linux-version (inte Flatpak), så att Discord ser vilket spel du spelar.
- Röstkanalen du är i syns i toppfältet. Okända kanaler: en notis frågar vad kanalen heter (eller `goblin discord namn Raid`).

### Bågskytte
- **[Ianseo](https://www.ianseo.net/)** (resultatprogrammet för bågskyttetävlingar) med ett klick: körs i en egen container, med automatisk backup var 30:e minut.
- **Tävlingsläge:** surfplattor och mobiler på samma nätverk når Ianseo.
- **Fjärråtkomst:** nå Ianseo via internet bakom ett lösenord (Cloudflare-tunnel, inga ändringar i routern). En ikon i systemfältet visar när Ianseo är nåbart utifrån.

### GOBLINCAKES Config
Ett eget fönster som öppnas vid första inloggningen – och sedan med **Meta+C** eller från appmenyn:
- **Program** – kryssa i det du vill ha, i hopfällbara kategorier: webbläsare (Brave, Opera GX, Google Chrome – med reglaget *Huvudwebbläsare*), spel och WoW (Lutris, Battle.net, Discord, Heroic, ProtonUp-Qt, GPU Screen Recorder, WowUp, Raider.IO, Archon m.fl.), emulatorer, media (Spotify, OBS, GIMP, VLC, EasyEffects, Quod Libet), streaming (Netflix, Disney+, HBO Max, Prime Video, YouTube, SVT Play, TV4 Play), kontor (LibreOffice, Okular, Ark, FileZilla), Ianseo och system (Claude, VS Code, Claude Code, Pika Backup m.fl.).
  - **Egen webbapp:** klistra in en länk så blir sidan ett eget program med ikon.
  - **Starta vid inloggning:** reglage på installerade program.
- **Förinstallerat** – visa eller dölj systemets program i appmenyn.
- **Inställningar** – reglage med rubriker: prestandaläge, spelschemaläggare, MangoHud, spel på det kraftfulla grafikkortet, shader-cache, ljud med låg fördröjning, HDR, ingen musacceleration, automatiska uppdateringar, skärmlåsning, viloläge, kalender med konton (Google, Outlook), Ianseo – och en knapp som återställer GOBLINCAKES-utseendet.
- **Grafik** – byt mellan AMD/Intel- och Nvidia-drivrutiner med en knapp; hjälp med Secure Boot.
- **Uppdatera** – se vad som är nytt och uppdatera allt eller en del i taget (systemet, Flatpak-program, VS Code, Discord, WoW-tillägg, GE-Proton, firmware).

### Goblin AI
Fråga om datorn eller vad som helst – i ett eget fönster (**Meta+A**) eller i terminalen (`goblin ai`). Använder gratisnivåerna hos Gemini, Groq, OpenRouter och Mistral (egen nyckel, hämtas med en knapp). Föreslagna kommandon körs bara när du säger ja, och AI:n kan ändra filer du bifogar.

### Kommandon i terminalen
| Kommando | Gör |
|---|---|
| `goblin update` | Uppdaterar allt: systemet, program, WoW-tillägg, GE-Proton och firmware – och visar vad som är nytt |
| `goblin ai` | **Goblin AI** – fråga om datorn eller vad som helst (även **Meta+A**) |
| `goblin play` | Dina spel – skriv spelets namn eller förkortning direkt i terminalen (t.ex. `wow`, `cs2`) så startas det via Steam |
| `goblin tv` | Startar TV-läget |
| `goblin wow` | Länkar alla WoW-versioner och uppdaterar WowUp |
| `goblin discord` | Namnger Discord-röstkanalen du är i (`goblin discord namn Raid`) |
| `goblin remove` | Avinstallerar Fedora-program (`goblin old` visar dem och hur du får tillbaka dem) |
| `goblin apps` | Visar dolda program igen |
| `goblin dock reset` | Återställer hela GOBLINCAKES-utseendet |
| `goblin nyheter` | Vad som är nytt i GOBLINCAKES |
| `goblin fast` | Systeminformation med GOBLINCAKES-loggan |
| `goblin help` | Visar alla kommandon |

Du får också en notis när GOBLINCAKES har gått över till en ny Fedora-version.

### Hårdvara och vardag
- Piper (för möss som Logitech G502, även G502 X), VIA (tangentbord som Keychron), ddcutil (skärmens ljusstyrka).
- **Mittenknappen** scrollar som i Windows i webbläsarna: klicka och för musen uppåt eller nedåt.
- Alla diskar syns och monteras automatiskt – även för Steam – och du kan skriva på dina egna Linux-diskar utan lösenord.
- **För egna projekt:** git och GitHub CLI (`gh`) är med från start; VS Code (Microsofts egen) och Claude Code installeras med ett klick i Config.

## Två varianter

| Image | För |
|---|---|
| `ghcr.io/kaytho-git/goblincakes` | AMD- och Intel-grafik (och Nvidia med den öppna drivrutinen) |
| `ghcr.io/kaytho-git/goblincakes-nvidia` | Nvidia GTX 16-serien, RTX 20-serien och nyare, med Nvidias egna drivrutiner |

Du behöver inte välja själv: GOBLINCAKES känner av grafikkortet och byter till rätt variant efter första starten, och **Config → Grafik** visar vilken du har.

## Installation

### Med GOBLINCAKES USB (enklast)

**GOBLINCAKES USB** är ett litet program för Windows och Linux som gör ett installations-USB-minne åt dig:

1. Ladda ner programmet från releasen [**usb-skaparen**](https://github.com/Kaytho-git/goblincakes/releases/tag/usb-skaparen):
   - Windows: `GOBLINCAKES-USB-Windows.exe` – ber om administratörsrättigheter. Windows kan varna eftersom programmet inte är signerat än: välj *Mer information → Kör ändå*.
   - Linux: `GOBLINCAKES-USB-Linux` – gör filen körbar (`chmod +x`) och starta den.
2. Välj ISO: **vanlig** (AMD/Intel) eller **Nvidia** (GTX 16xx/RTX 20xx eller nyare). Programmet ser vilket grafikkort datorn har och föreslår rätt – ska USB-minnet till en annan dator, välj efter den datorns kort. Fel val gör ingen skada: GOBLINCAKES rättar det efter första starten.
3. Sätt i ett USB-minne på minst 16 GB, välj det och tryck **Skapa USB-minne**. Allt på USB-minnet raderas.
4. Programmet hämtar ISO:n (ca 9,5 GB, Nvidia ca 11 GB) från releasen [**iso**](https://github.com/Kaytho-git/goblincakes/releases/tag/iso), kontrollerar varje del, skriver den till USB-minnet och läser sedan tillbaka allt för att se att det stämmer.
5. Starta datorn från USB-minnet (oftast F12, F11, F8 eller Esc vid start, i UEFI-läge). GOBLINCAKES startar direkt från USB-minnet – prova, och tryck sedan **Installera GOBLINCAKES**. Steam och TV-läget finns inte på USB-minnet men kommer med i installationen.

ISO:n går också att ladda ner för hand från releasen **iso** (i delar under 2 GB – se releasetexten) och skriva med t.ex. Rufus eller balenaEtcher.

### Från Fedora Kinoite

Har du redan Fedora Kinoite kan du byta till GOBLINCAKES direkt:

1. Byt till GOBLINCAKES (osignerad första gången, för att få signeringsnycklarna):
   ```bash
   rpm-ostree rebase ostree-unverified-registry:ghcr.io/kaytho-git/goblincakes:latest
   ```
   ```bash
   systemctl reboot
   ```
2. Byt till den signerade imagen:
   ```bash
   rpm-ostree rebase ostree-image-signed:docker://ghcr.io/kaytho-git/goblincakes:latest
   ```
   ```bash
   systemctl reboot
   ```
3. Logga in – GOBLINCAKES Config öppnas och hjälper dig med resten.

> [!NOTE]
> GOBLINCAKES är ett personligt projekt och utvecklas fortfarande. Det används på en riktig speldator och fungerar även i en virtuell maskin (VirtualBox: slå på 3D-acceleration och EFI).

## Uppdateringar och versioner

- GOBLINCAKES byggs **varje dag** och versionen är byggdatumet, t.ex. `GOBLINCAKES 2026.10.11`.
- Nya versioner hämtas automatiskt i bakgrunden och används vid nästa omstart (går att stänga av under **Config → Inställningar**). Rutan i toppfältet visar vad som väntar.
- Nya Fedora-versioner kommer automatiskt några veckor efter Fedoras släpp, när Universal Blue har gått över till dem.
- Den förra versionen finns alltid kvar i startmenyn.

## Verifiering

Imagerna är signerade med [Sigstore](https://www.sigstore.dev/)s [cosign](https://github.com/sigstore/cosign). Kontrollera signaturen med `cosign.pub` från det här repot:

```bash
cosign verify --key cosign.pub ghcr.io/kaytho-git/goblincakes
```

## Code signing policy

*(GOBLINCAKES USB – the Windows program `GOBLINCAKES-USB-Windows.exe`)*

- **What is signed:** only `GOBLINCAKES-USB-Windows.exe`, built by GitHub Actions ([`build-usb-creator.yml`](.github/workflows/build-usb-creator.yml)) from the source code in [`usb-skaparen/`](usb-skaparen/) of this repository. Nothing built outside that workflow is signed.
- **Team roles:** committer, reviewer and approver: [Kaytho-git](https://github.com/Kaytho-git). Every signing request is approved by hand. Accounts with write access to this repository use two-factor authentication.
- **Privacy policy:** GOBLINCAKES USB sends no information about you or your computer anywhere. The only network connections it makes are downloads of the installation ISO and its checksum list from this repository's GitHub Releases (github.com), which you start yourself.
- **License:** Apache 2.0 ([LICENSE](LICENSE)). Bundled components: Python, Qt/PySide6 (LGPL) and the fonts Chakra Petch, IBM Plex Sans and IBM Plex Mono (SIL Open Font License).

## Tack till

Byggt av **Kaytho och en fin kille**, ovanpå andras fina arbete: [Fedora](https://fedoraproject.org/), [Universal Blue](https://universal-blue.org/), [BlueBuild](https://blue-build.org/), [KDE](https://kde.org/), [Ghostty](https://ghostty.org/), [AppGrid](https://github.com/xarbit/appgrid) och Kvantum-temat KvFlat av Tsu Jan.
