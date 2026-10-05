# GOBLINCAKES – projektöversikt för Claude Code

Personlig Linux-distro byggd med **BlueBuild** ovanpå `ghcr.io/ublue-os/kinoite-nvidia` (Fedora Kinoite, KDE Plasma 6, Nvidia RTX 20xx+).
Repo: `Kaytho-git/goblincakes` (publikt). Image: `ghcr.io/kaytho-git/goblincakes:latest`. Byggs via GitHub Actions (`.github/workflows/build.yml`, skapad av BlueBuild Workshop med cosign-signering).

Användaren kör Windows med VS Code, testar imagen i en VirtualBox-VM (Kinoite → rebase till GOBLINCAKES). Hen redigerar ibland filer direkt på GitHub – kör alltid `git pull` innan du ändrar något.

## Status
- [x] Steg 1: Bas-recept – paket, Flatpaks, udev-regler, tjänster (bygger grönt)
- [~] Ghostty som standardterminal (COPR `mineiro/ghostty`) – aldrig byggt: Ghostty-byggena 5 okt föll på GitHub-störning (ingen runner), inte på receptet
- [~] Steg 3: KDE-utseende + varumärke – splash/utloggning/bakgrund/plasma-tema committade 5 okt, ej testat i VM än
- [ ] Steg 4: Förstagångs-installationsfönster (appväljare)
- [ ] Steg 5: Ianseo i container
- [ ] Steg 6: Egen installations-ISO

## Vad som finns
- `recipes/recipe.yml`: moduler `files`, `dnf` (VS Code, Ghostty, libratbag-ratbagd, ddcutil, gamemode, ananicy-cpp + cachyos-ananicy-rules från COPR `bieszczaders/kernel-cachyos-addons`), `default-flatpaks` (Firefox, Steam, Discord, Lutris, VLC, Piper, Chromium – system scope), `systemd` (ratbagd, ananicy-cpp), `os-release` (NAME/PRETTY_NAME = GOBLINCAKES), `signing`.
- `files/dnf/vscode.repo`
- `files/system/usr/lib/udev/rules.d/60-keychron.rules` (Keychron V10, vendor 3434, hidraw uaccess för VIA)
- `files/system/usr/lib/modules-load.d/i2c-dev.conf` (ddcutil)
- `files/system/etc/xdg/`: `kdeglobals` (Ghostty som terminal, AnimationDurationFactor=0.5), `baloofilerc` (bara filnamn), `kwinrc` (knappar IAX till höger), `ksplashrc` (vår splash), `kscreenlockerrc` (piltavla på låsskärmen), `plasmarc` (plasma-tema goblincakes), `autostart/goblincakes-firstlogin.desktop`
- `files/system/usr/libexec/goblincakes-firstlogin`: kör en gång per användare – `plasma-apply-lookandfeel --apply org.goblincakes.desktop --resetLayout` + `plasma-apply-colorscheme GoblinCakes`
- `files/system/usr/share/plasma/look-and-feel/org.goblincakes.desktop/`: layout = toppfält (kickoff vänster, klocka mitten, systray höger) + centrerad flytande docka nederst med `hiding = "dodgewindows"` + bakgrundsbild
  - `contents/splash/Splash.qml`: vit outline-goblin i cupcake på mörkblått (#0c1a3a), "GOBLINCAKES", laddningslinje
  - `contents/logout/Logout.qml`: vinkande goblin, "Hejdå! Vi syns nästa raid!", knappar kopplade till logout-greeterns signaler (logoutRequested, rebootRequested, haltRequested, cancelRequested)
- `files/system/usr/share/color-schemes/GoblinCakes.colors`: svart + mörkblå accent
- `files/system/usr/share/wallpapers/goblincakes/goblincakes.svg`: piltavla, nästan svart med tunna mörkblå ringar och tre dämpade pilar (skrivbord, låsskärm, SDDM)
- `files/system/usr/share/sddm/themes/breeze/theme.conf.user`: piltavlan på inloggningsskärmen
- `files/system/usr/share/plasma/desktoptheme/goblincakes/`: bara `dialogs/background.svg` (raka hörn på alla popups, t.ex. appmenyn) – resten faller tillbaka på Breeze

## Beslut och önskemål
- Atomisk/immutabel, rollback ska fungera. Fedora-standardkärna. Inte baserad på Bazzite.
- Utseende: GNOME-likt, svart och mörkblått, platta kontroller, behåll minimera/maximera/stäng. Appmenyn (popups) med raka hörn.
- Tema efter intressen: WoW och bågskytte. Goblinen ritas bara som vit outline (ingen fyllning), huvudet sticker upp ur cupcake-formen (ingen glasyr). Bakgrunden ska vara dämpad – inte för mycket färg.
- Ej gjort: Plymouth-uppstartsskärm (kräver initramfs-ombyggnad).
- Alltid installerat: Piper (G502 Hero), VIA via Chromium (Keychron V10), ddcutil.
- Setup-väljaren (steg 4) ska erbjuda: Proton-hanterare (auto-hämta GE-Proton), WowUp, Raider.IO och Archon (AppImages via Gear Lever), OBS, LibreOffice, FileZilla, Flatseal, Gear Lever.
- WoW via Lutris/Battle.net med GE-Proton, installerat *inne i* Wine-prefixet (krävs för att butiken/CEF ska fungera). Symlänkar `~/Games/WoW/Logs` och `~/Games/WoW/AddOns` pekar in i prefixet.
- Ianseo: bara lokalt (ingen LAN-åtkomst), automatiska backuper.
- Användaren är nybörjare på Git – förklara steg kort och tydligt.
