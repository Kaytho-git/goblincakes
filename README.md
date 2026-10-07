# GOBLINCAKES OS &nbsp; [![bluebuild build badge](https://github.com/kaytho-git/goblincakes/actions/workflows/build.yml/badge.svg)](https://github.com/kaytho-git/goblincakes/actions/workflows/build.yml)

**En personlig Linux-distribution för spel, World of Warcraft och bågskytte – snygg, snabb och omöjlig att förstöra.**

GOBLINCAKES bygger på [Fedora Kinoite](https://fedoraproject.org/atomic-desktops/kinoite/) (KDE Plasma 6) via [Universal Blue](https://universal-blue.org/) och byggs automatiskt varje dag med [BlueBuild](https://blue-build.org/). Allt är platt, mörkt och fyrkantigt, med en goblin som maskot.

## Målet

En dator som bara fungerar – för den som vill spela, raida och sköta bågskyttetävlingar utan att pilla med Linux:

- **Allt klart från start.** Rätt drivrutiner, rätt inställningar för spel och ett genomarbetat utseende redan vid första inloggningen.
- **Går inte att förstöra.** Systemet är *atomiskt*: varje uppdatering är en hel, testad version. Blir något fel väljer du förra versionen i startmenyn och är tillbaka på en minut.
- **Ett ställe för allt.** Program, spelinställningar och grafikdrivrutiner väljs i ett eget fönster, *GOBLINCAKES Config* – ingen terminal behövs.
- **Uppdateras av sig själv.** Ny Fedora-version, nya drivrutiner och säkerhetsfixar kommer automatiskt; ett kommando (`goblin update`) uppdaterar allt annat.
- **Slutmål:** en egen installations-USB, så att GOBLINCAKES kan installeras direkt på vilken dator som helst – precis som Windows eller SteamOS.

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
- **Optimeringar** som reglage: spelschemaläggare (scx_lavd), prestandaläge, större shader-cache, ljud med låg fördröjning med mera.
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
- **Program** – välj det du vill ha: Discord, Lutris, Heroic, OBS, Spotify, GIMP, LibreOffice, Claude, streamingtjänster (Netflix, SVT Play m.fl.) och mycket mer.
- **Optimering** – spelinställningar som reglage.
- **Grafik** – byt mellan AMD/Intel- och Nvidia-drivrutiner med en knapp.

### Kommandon i terminalen
| Kommando | Gör |
|---|---|
| `goblin update` | Uppdaterar allt: systemet, program, WoW-tillägg, GE-Proton och firmware |
| `goblin ai` | **Goblin AI** – fråga om datorn eller vad som helst (även **Meta+A**) |
| `goblin tv` | Startar TV-läget |
| `goblin wow` | Länkar alla WoW-versioner och uppdaterar WowUp |
| `goblin fast` | Systeminformation med GOBLINCAKES-loggan |
| `goblin help` | Visar alla kommandon |

Du får också en notis när GOBLINCAKES har gått över till en ny Fedora-version.

### Hårdvara
- Piper (för möss som Logitech G502), VIA (tangentbord som Keychron), ddcutil (skärmens ljusstyrka).
- Alla diskar syns och monteras automatiskt – även för Steam.
- Snap-stöd utöver Flatpak.

## Två varianter

| Image | För |
|---|---|
| `ghcr.io/kaytho-git/goblincakes` | AMD- och Intel-grafik (och Nvidia med den öppna drivrutinen) |
| `ghcr.io/kaytho-git/goblincakes-nvidia` | Nvidia RTX 20-serien och nyare, med Nvidias egna drivrutiner |

Du behöver inte välja själv: GOBLINCAKES känner av grafikkortet och föreslår rätt variant under **Config → Grafik**.

## Installation

Installations-USB:n är på väg. Tills vidare installerar du **Fedora Kinoite** och byter sedan till GOBLINCAKES:

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

## Tack till

Byggt av **Kaytho och en fin kille**, ovanpå andras fina arbete: [Fedora](https://fedoraproject.org/), [Universal Blue](https://universal-blue.org/), [BlueBuild](https://blue-build.org/), [KDE](https://kde.org/), [Ghostty](https://ghostty.org/), [AppGrid](https://github.com/xarbit/appgrid) och Kvantum-temat KvFlat av Tsu Jan.
