#!/usr/bin/env bash
# Ghostty needs OpenGL 4.3. In VirtualBox/VMware with 3D acceleration the virtual
# graphics card only offers 4.1, and Ghostty won't open ("OpenGL version is too old").
# So /usr/bin/ghostty becomes a small wrapper: inside those VMs Ghostty draws with the
# CPU (Mesa's llvmpipe, OpenGL 4.5) while the rest of the desktop keeps 3D. On real
# hardware nothing changes. Covers every way Ghostty starts (dock, AppGrid, KDE's
# terminal setting, D-Bus/systemd activation, our own scripts).
set -oue pipefail

[ -x /usr/bin/ghostty ] || { echo "ghostty not installed" >&2; exit 1; }
mv /usr/bin/ghostty /usr/libexec/ghostty-bin
cat > /usr/bin/ghostty <<'EOF'
#!/bin/sh
# GOBLINCAKES: see files/scripts/ghostty-wrapper.sh
case "$(systemd-detect-virt --vm 2>/dev/null)" in
    oracle|vmware) export LIBGL_ALWAYS_SOFTWARE=1 ;;
esac
export GHOSTTY_RESOURCES_DIR="${GHOSTTY_RESOURCES_DIR:-/usr/share/ghostty}"
exec /usr/libexec/ghostty-bin "$@"
EOF
chmod 755 /usr/bin/ghostty
