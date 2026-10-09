#!/usr/bin/bash
# Turns the GOBLINCAKES image into the live system on the ISO (based on Titanoboa's Bazzite example):
#   - starts straight into GOBLINCAKES (our look), in Swedish, as "liveuser"
#   - "Installera GOBLINCAKES" = Fedora's Anaconda; it installs the variant on the ISO (no
#     internet needed): the base ISO (goblincakes) or the Nvidia ISO (goblincakes-nvidia,
#     same build with BASE_IMAGE=…goblincakes-nvidia). When it doesn't fit the computer
#     (Nvidia RTX 20xx / GTX 16xx or newer ↔ everything else), the system is pointed at the
#     other one – fetched after the first start (goblincakes-variant-sync.service)
#   - KDE Partitionshanterare to wipe/format disks; nothing on the disks changes until then
#   - Secure Boot: Universal Blue's key (Nvidia, Xbox drivers) is queued for enrolment –
#     confirmed once in the blue MOK screen at the first restart, password universalblue
set -exo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
payload_image=${GOBLINCAKES_PAYLOAD_IMAGE:-ghcr.io/kaytho-git/goblincakes:latest}
payload_dir=/var/lib/goblincakes-payload
payload_repo=${payload_image%:*}
payload_tag=${payload_image##*:}
secureboot_key=/etc/pki/akmods/certs/akmods-ublue.der
iso_variant=$(cat /usr/share/goblincakes/variant 2>/dev/null || echo base)  # base / nvidia

# The image comes with an empty /var (BlueBuild cleans it): folders the tools below expect
mkdir -p "$(realpath /root)" /var/lib/rpm-state /var/tmp /var/cache /var/log
chmod 1777 /var/tmp

# ── The image Anaconda installs: the same GOBLINCAKES, kept compressed (OCI layout) ──
# Signatures can not be kept in an OCI folder; the installed system checks them on every update
skopeo copy --retry-times 3 --remove-signatures "docker://$payload_image" "oci:$payload_dir:$payload_tag"

# ── Live start: initramfs that boots from the ISO ──
dnf -y versionlock clear || :
dnf install -y dracut-live
kernel=$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | head -1)
DRACUT_NO_XATTR=1 dracut -v --force --zstd --reproducible --no-hostonly \
    --add "dmsquash-live dmsquash-live-autooverlay" \
    "/usr/lib/modules/$kernel/initramfs.img" "$kernel"

# ── Live user (liveuser, logs in by itself into Plasma) ──
dnf install -y livesys-scripts
sed -i "s/^livesys_session=.*/livesys_session=kde/" /etc/sysconfig/livesys
systemctl enable livesys.service livesys-late.service
# GOBLINCAKES logs in through SDDM (not Plasma Login Manager): log liveuser in by itself
mkdir -p /etc/sddm.conf.d
cat >/etc/sddm.conf.d/zz-goblincakes-live.conf <<'EOF'
[Autologin]
User=liveuser
Session=plasma
Relogin=false
EOF

# ── Installer, browser for it, dialogs, partition manager ──
dnf install -y --enable-repo=fedora-cisco-openh264 --allowerasing \
    anaconda-live libblockdev-{btrfs,lvm,dm} firefox yad
dnf install -y kde-partitionmanager || :
# The installer (Anaconda's web UI, a Cockpit page) in GOBLINCAKES' look instead of Fedora's
# blue: it loads Cockpit's branding.css for the OS – ours is added after Fedora's, so it wins.
# Logo, palette, flat with square corners, IBM Plex Sans / Chakra Petch.
branding_dirs=$(ls -d /usr/share/cockpit/branding/fedora* 2>/dev/null || :)
[ -n "$branding_dirs" ] || { mkdir -p /usr/share/cockpit/branding/fedora; branding_dirs=/usr/share/cockpit/branding/fedora; }
for dir in $branding_dirs; do
    cp /usr/share/icons/hicolor/scalable/apps/goblincakes.svg "$dir/goblincakes.svg"
    cat >>"$dir/branding.css" <<'EOF'

/* ── GOBLINCAKES (iso/src/build.sh): the installer in GOBLINCAKES' palette ── */
:root, :root.pf-v6-theme-dark {
  --brand-default: #2F6FED !important;
  --brand-default-light: #4F86F0 !important;
  --pf-t--global--color--brand--default: #2F6FED !important;
  --pf-t--global--color--brand--hover: #4F86F0 !important;
  --pf-t--global--color--brand--clicked: #2558C0 !important;
  --pf-t--global--border--radius--small: 0 !important;
  --pf-t--global--border--radius--medium: 0 !important;
  --pf-t--global--border--radius--large: 0 !important;
  --pf-t--global--border--radius--pill: 0 !important;
  --pf-t--global--font--family--body: "IBM Plex Sans", sans-serif !important;
  --pf-t--global--font--family--heading: "Chakra Petch", "IBM Plex Sans", sans-serif !important;
  --pf-t--global--background--color--primary--default: #0E1420 !important;
  --pf-t--global--background--color--secondary--default: #07090D !important;
  --pf-t--global--border--color--default: #1E2A40 !important;
  --pf-t--global--text--color--regular: #E6ECF5 !important;
  --pf-t--global--text--color--subtle: #8B98AD !important;
}
body, .pf-v6-c-page, .pf-v6-c-page__main { background: #07090D !important; }
.pf-v6-c-page__main-group > .pf-v6-c-page__main-section:first-child {
  background: #0B1018 !important;
  border-bottom: 1px solid #E6ECF5;
}
.pf-v6-c-page__main-group > .pf-v6-c-page__main-section:first-child h1 {
  font-family: "Chakra Petch", "IBM Plex Sans", sans-serif;
  font-weight: 700;
  letter-spacing: 0.08em;
}
.logo {
  background-image: url("goblincakes.svg") !important;
  filter: none !important;
  mix-blend-mode: normal !important;
}
.pf-v6-c-wizard__nav, .pf-v6-c-wizard__footer { background: #0B1018 !important; }
/* The installation page (the one with the progress steps): the long step shows no progress */
.pf-v6-c-empty-state:has(.pf-v6-c-progress-stepper) .pf-v6-c-empty-state__body::after {
  content: "Det här tar en stund – ofta 10–20 minuter, och skärmen kan stå still länge.\A Ta en kaffe, gå på toa, gör något annat än att glo på skärmen!";
  white-space: pre-line;
  display: block;
  margin-top: 1.5em;
  color: #8B98AD;
}
.pf-v6-c-button, .pf-v6-c-form-control, .pf-v6-c-card, .pf-v6-c-modal-box, .pf-v6-c-menu,
.pf-v6-c-progress-stepper__step-icon { border-radius: 0 !important; }
EOF
done

# KDE's own Welcome Center (Fedora's live scripts open it with an install page) – the live
# system has GOBLINCAKES' own welcome window instead. Only the live system: the installed
# GOBLINCAKES comes from the separate payload image.
dnf remove -y --noautoremove plasma-welcome || :
rm -f /etc/xdg/autostart/org.kde.plasma-welcome.desktop

# Anaconda's settings for GOBLINCAKES (the Kinoite profile already gives Btrfs and Fedora's EFI folder)
mkdir -p /etc/anaconda/conf.d
cat >/etc/anaconda/conf.d/90-goblincakes.conf <<'EOF'
[Network]
default_on_boot = FIRST_WIRED_WITH_LINK

[Bootloader]
menu_auto_hide = True

[Storage]
default_scheme = BTRFS
btrfs_compression = zstd:1

[User Interface]
# No root password (sudo with your own) and no network page (the live system has the network)
hidden_spokes =
    NetworkSpoke
    PasswordSpoke
hidden_webui_pages =
    root-password
    network

[Localization]
use_geolocation = False

[Payload]
flatpak_remote = flathub https://dl.flathub.org/repo/
EOF
source /etc/os-release
echo "GOBLINCAKES ${IMAGE_VERSION:-} (Fedora $VERSION_ID)" >/etc/system-release

# Installer name and icon: GOBLINCAKES
for f in /usr/share/icons/hicolor/*/apps/org.fedoraproject.AnacondaInstaller*.svg; do
    [ -e "$f" ] && cp /usr/share/icons/hicolor/scalable/apps/goblincakes.svg "$f"
done
for f in /usr/share/applications/liveinst.desktop /usr/share/applications/*anaconda*.desktop; do
    [ -e "$f" ] || continue
    sed -i 's/^Name=.*/Name=Installera GOBLINCAKES/; /^Name\[/d; s/^Icon=.*/Icon=goblincakes/' "$f"
done

# ── What Anaconda does (kickstart) ──
mkdir -p /usr/share/anaconda/post-scripts
cat >>/usr/share/anaconda/interactive-defaults.ks <<EOF

%pre
mkdir -p /tmp/goblincakes-logs
%end

# GOBLINCAKES from the ISO – no internet needed
ostreecontainer --url=$payload_dir:$payload_tag --transport=oci --no-signature-verification

# No first-boot setup after the installation: the installer already asked for language,
# keyboard, time and the account, and GOBLINCAKES Config takes over at the first login
firstboot --disable

# bootupd writes the EFI files itself (must match efi_dir in the Kinoite profile)
%pre-install --erroronfail
rm -rf /mnt/sysroot/boot/efi/EFI/fedora
%end

%include /usr/share/anaconda/post-scripts/goblincakes-variant.ks
%include /usr/share/anaconda/post-scripts/goblincakes-secureboot.ks

# Fedora's own first-boot programs (KDE's Plasma Setup, Anaconda's Initial Setup) off in the
# installed system too – masked in the new deployment's /etc
%post --nochroot --log=/tmp/goblincakes-logs/firstboot.log
set -x
for etc in /mnt/sysroot/ostree/deploy/*/deploy/*.0/etc /mnt/sysimage/ostree/deploy/*/deploy/*.0/etc; do
    [ -d "\$etc" ] || continue
    mkdir -p "\$etc/systemd/system"
    for unit in plasma-setup.service plasma-setup-live-system.service initial-setup.service \\
                initial-setup-graphical.service initial-setup-text.service; do
        ln -sf /dev/null "\$etc/systemd/system/\$unit"
    done
    rm -f "\$etc/xdg/autostart/org.kde.plasma-setup.desktop" 2>/dev/null || :
done
%end

%onerror
run0 --user=liveuser --setenv=GTK_THEME=GoblinCakes yad --title="GOBLINCAKES" --timeout=0 --text-info --no-buttons \\
    --width=700 --height=450 \\
    --text="Något gick fel under installationen. Loggen nedan visar vad – ta gärna en bild av den." \\
    < /tmp/anaconda.log
%end
EOF

# Updates come from the registry, signed, in the variant that fits the graphics card
cat >/usr/share/anaconda/post-scripts/goblincakes-variant.ks <<EOF
%post --nochroot --erroronfail --log=/tmp/goblincakes-logs/variant.log
set -x
image=${payload_repo%-nvidia}
if /usr/libexec/goblincakes-gpu hw | python3 -c 'import json, sys; sys.exit(0 if json.load(sys.stdin).get("nvidiaSupported") else 1)'; then
    image=\$image-nvidia
fi
[ "\$image" = "$payload_repo" ] || echo "The other variant fits this computer: \$image is fetched after the first start"
found=0
for f in /mnt/sysroot/ostree/deploy/*/deploy/*.origin /mnt/sysimage/ostree/deploy/*/deploy/*.origin; do
    [ -f "\$f" ] || continue
    sed -i "s|^container-image-reference=.*|container-image-reference=ostree-image-signed:docker://\$image:$payload_tag|" "\$f"
    found=1
done
[ "\$found" = 1 ] || { echo "No ostree origin file found"; exit 1; }
%end
EOF

cat >/usr/share/anaconda/post-scripts/goblincakes-secureboot.ks <<EOF
%post --nochroot --log=/tmp/goblincakes-logs/secureboot.log
# Universal Blue's key for the Nvidia and Xbox drivers: confirmed once in the blue MOK
# screen at the first restart (Enroll MOK → Continue → Yes → universalblue → Reboot)
[ -d /sys/firmware/efi ] || exit 0
[ -f $secureboot_key ] || exit 0
mokutil --sb-state 2>/dev/null | grep -qi enabled || exit 0
mokutil --test-key $secureboot_key 2>&1 | grep -qi "already enrolled" && exit 0
mokutil --timeout -1 || :
printf 'universalblue\nuniversalblue\n' | mokutil --import $secureboot_key || exit 0
run0 --user=liveuser --setenv=GTK_THEME=GoblinCakes yad --title="GOBLINCAKES" --on-top --timeout=0 --button=OK:0 --text="\$(cat <<'MSG'
<b>Secure Boot är på</b>

När datorn startar om visas en blå skärm (MOK). Gör så här en gång:
  1. Enroll MOK
  2. Continue
  3. Yes
  4. Lösenord: <b>universalblue</b>
  5. Reboot

Det behövs för Nvidia- och Xbox-drivrutinerna.
MSG
)" || :
%end
EOF

# ── Swedish live system ──
echo 'LANG=sv_SE.UTF-8' >/etc/locale.conf
echo 'KEYMAP=se-nodeadkeys' >/etc/vconsole.conf
mkdir -p /etc/X11/xorg.conf.d
cat >/etc/X11/xorg.conf.d/00-keyboard.conf <<'EOF'
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "se"
EndSection
EOF
mkdir -p /etc/skel/.config
printf '[Layout]\nLayoutList=se\nUse=true\n' >/etc/skel/.config/kxkbrc
rm -f /etc/localtime
systemd-firstboot --timezone Europe/Stockholm

# ── Not in the live system: updates, first-run windows, mounting the disks, … ──
for unit in rpm-ostreed-automatic.timer uupd.timer rpm-ostree-countme.service rpm-ostree-countme.timer \
    goblincakes-snapd-setup.service goblincakes-variant-sync.service bootloader-update.service \
    ublue-system-setup.service tailscaled.service brew-setup.service brew-update.timer brew-upgrade.timer; do
    systemctl disable "$unit" 2>/dev/null || :
done
for unit in ublue-user-setup.service ublue-flatpak-manager.service podman-auto-update.timer goblincakes-updates.timer \
    goblincakes-ianseo-backup.timer; do
    systemctl --global disable "$unit" 2>/dev/null || :
done
# BlueBuild's Flatpak installation at first start (Firefox, Piper, Chromium): happens on the installed system
for f in /usr/lib/systemd/system/*flatpak*setup* /usr/lib/systemd/system/*flatpak*manager* \
    /usr/lib/systemd/user/*flatpak*setup* /usr/lib/systemd/user/*flatpak*manager*; do
    [ -e "$f" ] || continue
    unit=$(basename "$f")
    case $f in
        */user/*) systemctl --global disable "$unit" 2>/dev/null || : ;;
        *) systemctl disable "$unit" 2>/dev/null || : ;;
    esac
done
for name in config automount gpu-check fedora-check wow-links ianseo-tray laptop screens mouse tv-cleanup; do
    rm -f "/etc/xdg/autostart/goblincakes-$name.desktop"
done
mkdir -p /etc/skel/.config
printf '[Wallet]\nEnabled=false\n' >/etc/skel/.config/kwalletrc

# In a virtual machine the live desktop is drawn without 3D: VirtualBox's 3D froze the whole
# screen (and keyboard) during the installation, twice, while Anaconda finished in the background.
# KWin composites with QPainter, programs (Firefox = the installer) use software OpenGL.
# Only the live system – the installed GOBLINCAKES keeps 3D.
cat >/etc/xdg/plasma-workspace/env/goblincakes-live-vm.sh <<'EOF'
# GOBLINCAKES live system (iso/src/build.sh): no 3D in virtual machines
if systemd-detect-virt --vm -q 2>/dev/null; then
    export KWIN_COMPOSE=Q
    export LIBGL_ALWAYS_SOFTWARE=1
fi
EOF

# The dock in the live system: installer, partition manager, Firefox, files
layout=/usr/share/plasma/look-and-feel/org.goblincakes.desktop/contents/layouts/org.kde.plasma.desktop-layout.js
sed -i 's|^tasks.writeConfig("launchers", .*|tasks.writeConfig("launchers", ["applications:liveinst.desktop", "applications:org.kde.partitionmanager.desktop", "preferred://browser", "preferred://filemanager"]);|' "$layout"
grep -q 'liveinst.desktop' "$layout"

# Welcome window after login: install, partition manager or try first
install -m 0755 "$SRC/welcome.sh" /usr/libexec/goblincakes-live-welcome
# Its window class (yad --class) belongs to this entry, so the dock shows the logo, not yad's icon
cat >/usr/share/applications/goblincakes-live-welcome.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Välkommen till GOBLINCAKES
Exec=/usr/libexec/goblincakes-live-welcome
Icon=goblincakes
NoDisplay=true
StartupWMClass=goblincakes-live-welcome
EOF
cat >/etc/xdg/autostart/goblincakes-live-welcome.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Välkommen till GOBLINCAKES
Exec=/usr/libexec/goblincakes-live-welcome
Icon=goblincakes
NoDisplay=true
X-KDE-autostart-phase=2
X-KDE-autostart-after=panel
EOF

# ── What Titanoboa needs to make the ISO ──
dnf install -y grub2-efi-x64-cdboot xorriso isomd5sum
mkdir -p /boot/efi
cp -av /usr/lib/efi/*/*/EFI /boot/efi/
cp -v /boot/efi/EFI/fedora/grubx64.efi /boot/efi/EFI/BOOT/fbx64.efi

# / in the live system is an overlay in RAM (/run is small): give /var/tmp more room
rm -rf /var/tmp || :
mkdir -p /var/tmp
cat >/etc/systemd/system/var-tmp.mount <<'EOF'
[Unit]
Description=Larger tmpfs for /var/tmp on the live system

[Mount]
What=tmpfs
Where=/var/tmp
Type=tmpfs
Options=size=50%%,nr_inodes=1m,x-systemd.graceful-option=usrquota

[Install]
WantedBy=local-fs.target
EOF
systemctl enable var-tmp.mount

mkdir -p /usr/lib/bootc-image-builder
cp "$SRC/iso.yaml" /usr/lib/bootc-image-builder/iso.yaml
# The Nvidia ISO: Nvidia's driver instead of nouveau in the live system (the image's own kargs.d
# only apply once installed); "enkel grafik" stays without it
if [ "$iso_variant" = nvidia ]; then
    sed -i '0,/rd.live.image"/s//rd.live.image rd.driver.blacklist=nouveau modprobe.blacklist=nouveau nvidia-drm.modeset=1"/' \
        /usr/lib/bootc-image-builder/iso.yaml
fi

dnf clean all
