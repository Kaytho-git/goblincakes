# GOBLINCAKES – projektöversikt för Claude Code

Personlig Linux-distro byggd med **BlueBuild** ovanpå `ghcr.io/ublue-os/kinoite-nvidia` (Fedora Kinoite, KDE Plasma 6, Nvidia RTX 20xx+).
Repo: `Kaytho-git/goblincakes` (publikt). Image: `ghcr.io/kaytho-git/goblincakes:latest`. Byggs via GitHub Actions (`.github/workflows/build.yml`, skapad av BlueBuild Workshop med cosign-signering).

Användaren kör Windows med VS Code, testar imagen i en VirtualBox-VM (Kinoite → rebase till GOBLINCAKES). Hen redigerar ibland filer direkt på GitHub – kör alltid `git pull` innan du ändrar något.

## Status
- [x] Steg 1: Bas-recept – paket, Flatpaks, udev-regler, tjänster (bygger grönt)
- [x] Ghostty som standardterminal (COPR `mineiro/ghostty`) – bygger grönt
- [~] Steg 3: KDE-utseende + varumärke – första versionen testad i VM 6 okt (bakgrund, toppfält, docka syns). Efter det: linjeikoner i dockan, begränsat systemfält, klockformat, splash-text, egen inloggningsbakgrund – ej testat än
- [ ] Steg 4: Förstagångs-installationsfönster (appväljare)
- [ ] Steg 5: Ianseo i container
- [ ] Steg 6: Egen installations-ISO

## Vad som finns
- `recipes/recipe.yml`: moduler `files`, `dnf` (VS Code, Ghostty, aurorae, kvantum, libratbag-ratbagd, ddcutil, gamemode, ananicy-cpp + cachyos-ananicy-rules från COPR `bieszczaders/kernel-cachyos-addons`), `fonts` (Google Fonts: Chakra Petch, IBM Plex Sans, IBM Plex Mono), `default-flatpaks` (Firefox, Steam, Discord, Lutris, VLC, Piper, Chromium – system scope), `systemd` (ratbagd, ananicy-cpp), `os-release` (NAME/PRETTY_NAME = GOBLINCAKES), `signing`.
- `files/dnf/vscode.repo`
- `files/system/usr/lib/udev/rules.d/60-keychron.rules` (Keychron V10, vendor 3434, hidraw uaccess för VIA)
- `files/system/usr/lib/modules-load.d/i2c-dev.conf` (ddcutil)
- `files/system/etc/xdg/`: `kdeglobals` (widgetStyle=kvantum, Ghostty som terminal, IBM Plex Sans som systemtypsnitt, AnimationDurationFactor=0.5), `baloofilerc` (bara filnamn), `kwinrc` (Aurorae-temat goblincakes, knappar IAX till höger, genomskinliga fönster vid flytt/storleksändring 75 %), `Kvantum/kvantum.kvconfig` (tema GoblinCakes), `kcminputrc` (ljus muspekare Breeze_Light; även `/usr/share/icons/default/index.theme` och look-and-feel), `ksplashrc` (vår splash), `kscreenlockerrc` (piltavla på låsskärmen), `plasmarc` (plasma-tema goblincakes), `autostart/goblincakes-firstlogin.desktop`
- `files/system/usr/libexec/goblincakes-firstlogin`: kör en gång per användare – `plasma-apply-lookandfeel --apply org.goblincakes.desktop --resetLayout` + `plasma-apply-colorscheme GoblinCakes` + skapar `~/.config/ghostty/config.ghostty` om den saknas (tema GoblinCakes, IBM Plex Mono 11, opacity 0.9 + blur, server-side ramar)
- `files/system/etc/xdg/plasma-workspace/env/goblincakes-refresh.sh`: körs vid varje inloggning före KWin/Plasma. Rensar Plasmas tema-/ikoncache när våra temafiler ändrats (på ostree har alla filer i /usr samma datum, så Plasma märker annars aldrig ändringar → tomma paneler). Sätter även translucency i användarens kwinrc om nyckeln saknas.
- AppGrid (COPR `scujas/plasma-applet-appgrid`, paket `plasma-applet-appgrid`): appmeny mitt på skärmen som GNOME, ersatte helskärms-kickerdash 6 okt. Fönstret använder Plasma-temats `dialogs/background` (vår fyrkantiga ram). Inställningar i `files/system/etc/xdg/appgridrc` ([General]: ingen ikonskugga/animation, inget grönt nytt-märke, ingen uppdateringskoll). Markeringar inuti har Kirigamis små rundade hörn – går inte att ändra utan att patcha.
- `files/system/usr/share/ghostty/themes/GoblinCakes`: Ghostty-färger från paletten (Ghostty har ingen systemgemensam config, bara teman)
- `files/system/usr/share/plasma/look-and-feel/org.goblincakes.desktop/`: layout = toppfält (AppGrid `dev.xarbit.appgrid` med bara loggan vänster; systray bara nätverk/volym/notiser/batteri via extraItems+knownItems, klocka "ddd d MMM" bredvid tiden, strömknapp lock_logout höger) + centrerad flytande docka (Firefox, Steam, Discord, VS Code, VLC) med `hiding = "dodgewindows"` + bakgrundsbild
  - `contents/splash/Splash.qml`: svart, logga, "GOBLINCAKES" i Chakra Petch, blå laddningslinje, "Booting into GOBLINCAKES OS…" (mått från designen, skalade efter skärmhöjd)
  - `contents/logout/Logout.qml`: svart, vinkande goblin, pratbubbla "Goodbye! / See you next raid!", platta raka knappar (texter via Plasmas egna översättningar, användarens språk) kopplade till logout-greeterns signaler (logoutRequested, rebootRequested, haltRequested, cancelRequested)
  - **Plasma 6.8+ läser utloggningsrutan från skalpaketet**, så en identisk kopia ligger i `files/system/usr/share/plasma/shells/org.kde.plasma.desktop/contents/logout/` (ersätter plasma-desktops egen). Ändra alltid båda kopiorna.
- `files/system/usr/share/icons/hicolor/scalable/apps/goblincakes.svg`: loggan (ikonnamn `goblincakes`)
- `files/system/usr/share/color-schemes/GoblinCakes.colors`: designens palett
- `files/system/usr/share/wallpapers/goblincakes/goblincakes.svg`: skrivbord + låsskärm = mörkblå (Deep #12203A) med goblin-loggan ton-i-ton som svingar en yxa (ersatte piltavlan 6 okt)
- **Fedora använder Plasma Login Manager, inte SDDM.** Inloggningsbakgrunden sätts i `files/system/usr/lib/plasmalogin/plasmalogin.conf.d/99-goblincakes.conf` ([Greeter][Wallpaper][org.kde.image][General] Image=…). `theme.conf.user` för SDDM (breeze, 01-breeze-fedora) finns kvar som reserv.
- `files/system/usr/share/wallpapers/goblincakes/goblincakes-login.svg`: inloggningsskärmen = mörkblå (Deep #12203A) med goblin-loggan ton-i-ton till höger om mitten
- Dockan: designens utseende (fyrkantig ram) men apparnas originalikoner – användaren vill inte ha linjeikoner. Ikontema = breeze-dark.
- `files/system/usr/share/plasma/desktoptheme/goblincakes/`: `dialogs/background.svg` (popups) och `widgets/panel-background.svg` (toppfält/docka) – raka hörn, 1px ram (panelram #2A3852, ljusare än designens #1A2438 som försvinner mot den blå bakgrunden); kopior i `translucent/`, `opaque/` och `solid/` krävs (solid = när ett fönster rör panelen), annars tar Plasma Breezes genomskinliga varianter när blur finns; resten faller tillbaka på Breeze
- `files/system/usr/share/aurorae/themes/goblincakes/`: fönsterramar efter designens Desktop-rityta – namnlist 44 px #0B1018, 1 px ram #1E2A40, titel vänster, platta linjeknappar 40×32 (stäng-hover röd #A4262C), inga skuggor/rundade hörn

## Beslut och önskemål
- Atomisk/immutabel, rollback ska fungera. Fedora-standardkärna. Inte baserad på Bazzite.
- **Varumärkets källa: designen https://claude.ai/artifact/BqT4GjvtTacjAgiCnRKwqt** (ritytor Main, Desktop, Wallpaper, Boot, Shutdown). Följ den exakt; användaren var mycket nöjd med den.
  - Palett: Void #07090D, Night #0E1420, Deep #12203A, Accent #2F6FED, Frost #E6ECF5, dämpad text #8B98AD, ramar #1E2A40/#1A2438, toppfält #05070A.
  - Typsnitt: Chakra Petch (rubriker), IBM Plex Sans (gränssnitt).
  - Logga: vit goblinhuvud-siluett med öron som är toppen på en blå cupcake-form.
  - Allt platt med raka hörn (fönster, docka, popups, knappar).
- `files/system/usr/share/Kvantum/GoblinCakes/`: Kvantum-tema = KvFlat (Tsu Jan, GPL-3.0) omfärgat till paletten (färgkarta: `tools/kvantum-colormap.sed`); styr knappar/reglage/flikar i Qt/KDE-program
- Avvikelser från designen som kräver egna widgets: strömknappen har utloggningsikon, "Apps" i IBM Plex (inte Chakra Petch), aktiv-app-markering är Breezes.
- Efter ändringar i look-and-feel måste användaren köra `rm ~/.local/state/goblincakes/firstlogin-done` och logga ut/in för att se dem.
- Utseende: GNOME-likt, behåll minimera/maximera/stäng. Tema efter intressen: WoW och bågskytte. Utloggningstexten på engelska: "Goodbye! See you next raid!" (knapparna på svenska).
- Ej gjort: Plymouth-uppstartsskärm (kräver initramfs-ombyggnad).
- Alltid installerat: Piper (G502 Hero), VIA via Chromium (Keychron V10), ddcutil.
- Setup-väljaren (steg 4) ska erbjuda: Proton-hanterare (auto-hämta GE-Proton), WowUp, Raider.IO och Archon (AppImages via Gear Lever), OBS, LibreOffice, FileZilla, Flatseal, Gear Lever.
- WoW via Lutris/Battle.net med GE-Proton, installerat *inne i* Wine-prefixet (krävs för att butiken/CEF ska fungera). Symlänkar `~/Games/WoW/Logs` och `~/Games/WoW/AddOns` pekar in i prefixet.
- Ianseo: bara lokalt (ingen LAN-åtkomst), automatiska backuper.
- Användaren är nybörjare på Git – förklara steg kort och tydligt.
