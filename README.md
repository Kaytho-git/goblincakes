# GOBLINCAKES OS &nbsp; [![bluebuild build badge](https://github.com/kaytho-git/goblincakes/actions/workflows/build.yml/badge.svg)](https://github.com/kaytho-git/goblincakes/actions/workflows/build.yml)

**En personlig Linux-distribution för spel, World of Warcraft och bågskytte – snygg, snabb och omöjlig att förstöra.**

GOBLINCAKES bygger på [Fedora Kinoite](https://fedoraproject.org/atomic-desktops/kinoite/) (KDE Plasma 6) via [Universal Blue](https://universal-blue.org/) och byggs automatiskt varje dag med [BlueBuild](https://blue-build.org/). Allt är platt, mörkt och fyrkantigt, med en goblin som maskot.

## Målet

En dator som bara fungerar – för den som vill spela, raida och sköta bågskyttetävlingar utan att pilla med Linux:

- **Allt klart från start.** Rätt drivrutiner, rätt inställningar för spel och ett genomarbetat utseende redan vid första inloggningen.
- **Går inte att förstöra.** Systemet är *atomiskt*: varje uppdatering är en hel, testad version. Blir något fel väljer du förra versionen i startmenyn och är tillbaka på en minut.
- **Ett ställe för allt.** Program, spelinställningar och grafikdrivrutiner väljs i ett eget fönster, *GOBLINCAKES Config* – ingen terminal behövs.
- **Uppdateras av sig själv.** Ny Fedora-version, nya drivrutiner och säkerhetsfixar kommer automatiskt; ett kommando (`goblin update`) uppdaterar allt annat.
- **Egen installations-USB:** GOBLINCAKES USB gör ett USB-minne som installerar GOBLINCAKES på vilken dator som helst – precis som Windows eller SteamOS.

## Vad som finns i

### Utseende
- Eget tema i hela systemet: mörk palett, Chakra Petch och IBM Plex, raka hörn överallt.
- Egen startskärm, inloggning, låsskärm och utloggning (*"Goodbye! See you next raid!"*).
- Toppfält med appmeny i mitten av skärmen (AppGrid), och en docka som gömmer sig när ett fönster täcker den. **Meta** visar dockan, **Shift+Meta** öppnar appmenyn.
- Ghostty som terminal, med GOBLINCAKES-färger och systeminfo (`goblin fast`).

### Spel
- **Steam** förinstallerat, plus Gamescope, GameMode, MangoHud (FPS-mätare) och nyaste Wine.
- **GE-Proton** hämtas och uppdateras automatiskt.
- **Handkontroller:** Xbox via dongel, USB och Bluetooth (xone, xpadneo), plus de vanliga PlayStation- och Switch-reglerna.
- **TV-läge:** Steam Big Picture i helskärm, som en Steam Deck – starta det från appmenyn.
- **Emulatorer:** RetroDECK (Super Nintendo, Mega Drive, N64, PlayStation, GameCube, Switch med flera) och Steam ROM Manager, som lägger in spelen i Steam och TV-läget.
- **Inställningar** som reglage: spelschemaläggare (scx_lavd), prestandaläge, större shader-cache, ljud med låg fördröjning med mera.
- **Flera skärmar:** varje skärm körs i sin egen uppdateringsfrekvens (t.ex. 180 Hz + 144 Hz), och den snabbaste blir huvudskärm.
- **Laptops** med två grafikkort: spel startar på det kraftfulla kortet, skrivbordet på det snåla.

### World of Warcraft
- Battle.net via Lutris med GE-Proton, installerat så att butiken fungerar.
- **WowUp, Raider.IO och Archon** installeras och uppdateras automatiskt.
- Mapparna för `Logs` och `AddOns` – för alla WoW-versioner – länkas till `~/Games/WoW`, och WowUp hittar dem själv.

### Bågskytte
- **[Ianseo](https://www.ianseo.net/)** (resultatprogrammet för bågskyttetävlingar) med ett klick: körs i en egen container, med automatisk backup var 30:e minut.
- **Tävlingsläge:** surfplattor och mobiler på samma nätverk når Ianseo.
- **Fjärråtkomst:** nå Ianseo via internet bakom ett lösenord (Cloudflare-tunnel, inga ändringar i routern). En ikon i systemfältet visar när Ianseo är nåbart utifrån.

### GOBLINCAKES Config
Ett eget fönster som öppnas vid första inloggningen – och sedan med **Meta+C** eller från appmenyn:
- **Program** – välj det du vill ha: Discord, Lutris, Heroic, OBS, Spotify, GIMP, LibreOffice, Claude, Claude Code, streamingtjänster (Netflix, SVT Play m.fl.), emulatorer (RetroDECK, Steam ROM Manager) och mycket mer.
- **Inställningar** – prestanda, spel, ljud, system och utseende som reglage, med rubriker.
- **Grafik** – byt mellan AMD/Intel- och Nvidia-drivrutiner med en knapp.

### Kommandon i terminalen
| Kommando | Gör |
|---|---|
| `goblin update` | Uppdaterar allt: systemet, program, WoW-tillägg, GE-Proton och firmware |
| `goblin ai` | **Goblin AI** – fråga om datorn eller vad som helst (även **Meta+A**) |
| `goblin play` | Dina spel i Steam – skriv spelets namn eller förkortning direkt i terminalen (t.ex. `wow`, `cs2`) så startas det via Steam |
| `goblin tv` | Startar TV-läget |
| `goblin wow` | Länkar alla WoW-versioner och uppdaterar WowUp |
| `goblin fast` | Systeminformation med GOBLINCAKES-loggan |
| `goblin help` | Visar alla kommandon |

Du får också en notis när GOBLINCAKES har gått över till en ny Fedora-version.

### Hårdvara
- Piper (för möss som Logitech G502), VIA (tangentbord som Keychron), ddcutil (skärmens ljusstyrka).
- Alla diskar syns och monteras automatiskt – även för Steam.
- Snap-stöd utöver Flatpak.
- **För egna projekt:** git, GitHub CLI (`gh`) och VS Code är med från start; Claude Code installeras med ett klick i Config.

## Två varianter

| Image | För |
|---|---|
| `ghcr.io/kaytho-git/goblincakes` | AMD- och Intel-grafik (och Nvidia med den öppna drivrutinen) |
| `ghcr.io/kaytho-git/goblincakes-nvidia` | Nvidia RTX 20-serien och nyare, med Nvidias egna drivrutiner |

Du behöver inte välja själv: GOBLINCAKES känner av grafikkortet och föreslår rätt variant under **Config → Grafik**.

## Installation

### Med GOBLINCAKES USB (enklast)

**GOBLINCAKES USB** är ett litet program för Windows och Linux som gör ett installations-USB-minne åt dig:

1. Ladda ner programmet från releasen [**usb-skaparen**](https://github.com/Kaytho-git/goblincakes/releases/tag/usb-skaparen):
   - Windows: `GOBLINCAKES-USB-Windows.exe` – ber om administratörsrättigheter. Windows kan varna eftersom programmet inte är signerat än: välj *Mer information → Kör ändå*.
   - Linux: `GOBLINCAKES-USB-Linux` – gör filen körbar (`chmod +x`) och starta den.
2. Sätt i ett USB-minne på minst 16 GB, välj det och tryck **Skapa USB-minne**. Allt på USB-minnet raderas.
3. Programmet hämtar installations-ISO:n från releasen [**iso**](https://github.com/Kaytho-git/goblincakes/releases/tag/iso), kontrollerar varje del, skriver den direkt till USB-minnet och läser sedan tillbaka allt för att se att det stämmer. Inget sparas på datorn.
4. Starta datorn från USB-minnet (oftast F12, F11, F8 eller Esc vid start, i UEFI-läge). GOBLINCAKES startar direkt från USB-minnet – prova, och tryck sedan **Installera GOBLINCAKES**.

Programmet visar också vilket grafikkort datorn har. Med ett Nvidia-kort (GTX 16xx/RTX 20xx eller nyare) hämtas Nvidias drivrutiner automatiskt efter första starten.

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
> GOBLINCAKES är ett personligt projekt och utvecklas fortfarande. Det fungerar bra i en virtuell maskin (VirtualBox: slå på 3D-acceleration).

## Uppdateringar och versioner

- GOBLINCAKES byggs **varje dag** och versionen är byggdatumet, t.ex. `GOBLINCAKES 2026.10.07`.
- Nya Fedora-versioner kommer automatiskt några veckor efter Fedoras släpp, när Universal Blue har gått över till dem.
- Uppdatera med `goblin update` och starta om. Den förra versionen finns alltid kvar i startmenyn.

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
