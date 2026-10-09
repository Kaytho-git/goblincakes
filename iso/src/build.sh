#!/usr/bin/bash
# Turns the GOBLINCAKES image into the live system on the ISO (based on Titanoboa's Bazzite example):
#   - starts straight into GOBLINCAKES (our look), in Swedish, as "liveuser"
#   - "Installera GOBLINCAKES" = Fedora's Anaconda; it installs the base variant from the
#     ISO (no internet needed) and points the system at goblincakes-nvidia when the computer
#     has an Nvidia RTX 20xx / GTX 16xx or newer – fetched after the first start
#     (goblincakes-variant-sync.service), used after one more restart
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

mkdir -p "$(realpath /root)" /var/lib/rpm-state

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

# bootupd writes the EFI files itself (must match efi_dir in the Kinoite profile)
%pre-install --erroronfail
rm -rf /mnt/sysroot/boot/efi/EFI/fedora
%end

%include /usr/share/anaconda/post-scripts/goblincakes-variant.ks
%include /usr/share/anaconda/post-scripts/goblincakes-secureboot.ks

%onerror
run0 --user=liveuser yad --title="GOBLINCAKES" --timeout=0 --text-info --no-buttons \\
    --width=700 --height=450 \\
    --text="Något gick fel under installationen. Loggen nedan visar vad – ta gärna en bild av den." \\
    < /tmp/anaconda.log
%end
EOF

# Updates come from the registry, signed, in the variant that fits the graphics card
cat >/usr/share/anaconda/post-scripts/goblincakes-variant.ks <<EOF
%post --nochroot --erroronfail --log=/tmp/goblincakes-logs/variant.log
set -x
image=$payload_repo
if /usr/libexec/goblincakes-gpu hw | python3 -c 'import json, sys; sys.exit(0 if json.load(sys.stdin).get("nvidiaSupported") else 1)'; then
    image=\${image%-nvidia}-nvidia
    echo "Nvidia RTX 20xx / GTX 16xx or newer: \$image is fetched after the first start"
fi
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
run0 --user=liveuser yad --title="GOBLINCAKES" --on-top --timeout=0 --button=OK:0 --text="\$(cat <<'MSG'
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
for unit in ublue-user-setup.service ublue-flatpak-manager.service podman-auto-update.timer \
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

# The dock in the live system: installer, partition manager, Firefox, files
layout=/usr/share/plasma/look-and-feel/org.goblincakes.desktop/contents/layouts/org.kde.plasma.desktop-layout.js
sed -i 's|^tasks.writeConfig("launchers", .*|tasks.writeConfig("launchers", ["applications:liveinst.desktop", "applications:org.kde.partitionmanager.desktop", "preferred://browser", "preferred://filemanager"]);|' "$layout"
grep -q 'liveinst.desktop' "$layout"

# Welcome window after login: install, partition manager or try first
install -m 0755 "$SRC/welcome.sh" /usr/libexec/goblincakes-live-welcome
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

dnf clean all
