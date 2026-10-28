#!/usr/bin/env bash
# Nvidia's legacy driver (the 580 series, "nvidia-lts") for goblincakes-nvidia-legacy: GTX 900
# and GTX 10 cards (Maxwell, Pascal, Volta), which Nvidia's 590+ drivers and the open kernel
# module no longer support. Pre-built by Universal Blue for exactly this kernel and signed with
# their key (Secure Boot: Grafik tab in GOBLINCAKES Config), installed with their own script –
# the same way their kinoite-nvidia image gets the current driver.
#
# The image has to be made for the kernel in the base image (as for the Xbox drivers). Unlike
# those, the driver is the point of this variant: without it the build stops, and the image
# from the day before stays (no GOBLINCAKES without its driver).
set -euo pipefail

fedora=$(rpm -E %fedora)
kernel=$(rpm -q kernel-core --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -n1)
kernel_noarch=${kernel%.*}
echo "Kernel in the image: $kernel"
command -v skopeo >/dev/null || dnf5 -y install skopeo

work=/tmp/akmods-rpms
found=""
for tag in "main-$fedora-$kernel_noarch" "main-$fedora-$kernel"; do
    echo "Trying ghcr.io/ublue-os/akmods-nvidia-lts:$tag"
    rm -rf "$work" /tmp/akmods-image
    skopeo copy --retry-times 3 "docker://ghcr.io/ublue-os/akmods-nvidia-lts:$tag" "dir:/tmp/akmods-image" >/dev/null 2>&1 || continue
    mkdir -p /tmp/akmods-layers
    for layer in $(python3 -c 'import json,sys; [print(l["digest"].split(":")[1]) for l in json.load(open(sys.argv[1]))["layers"]]' /tmp/akmods-image/manifest.json); do
        tar -xzf "/tmp/akmods-image/$layer" -C /tmp/akmods-layers 2>/dev/null || true
    done
    # The image keeps its files in /rpms
    if [ -d /tmp/akmods-layers/rpms ]; then
        mv /tmp/akmods-layers/rpms "$work"
    else
        mv /tmp/akmods-layers "$work"
    fi
    rm -rf /tmp/akmods-layers /tmp/akmods-image
    if ls "$work"/kmods/kmod-nvidia-*.rpm >/dev/null 2>&1 \
            && rpm -qp --requires "$work"/kmods/kmod-nvidia-*.rpm 2>/dev/null | grep -q "kernel-uname-r = $kernel"; then
        found=$tag
        break
    fi
    echo "  not for this kernel"
done
if [ -z "$found" ]; then
    echo "ERROR: Universal Blue has no legacy Nvidia driver (akmods-nvidia-lts) for kernel $kernel yet –" >&2
    echo "       goblincakes-nvidia-legacy is not built today; yesterday's image stays" >&2
    exit 1
fi
echo "Legacy Nvidia driver from akmods-nvidia-lts:$found"
cat "$work/kmods/nvidia-vars" || true

# The base image's mesa can be older than Fedora's (26.2.3 against 26.2.5, 28 Oct – the old one is
# no longer in the repos): the installer's 32-bit mesa then clashes with it and the build stops.
# The 64-bit mesa is brought to Fedora's version first, so both are the same.
mapfile -t mesa < <(rpm -qa 'mesa-*' --qf '%{NAME}\n' | sort -u)
[ ${#mesa[@]} -eq 0 ] || dnf5 -y upgrade --refresh "${mesa[@]}"

# Universal Blue's installer (the Kinoite flavour: supergfxctl for laptops with two cards)
IMAGE_NAME=kinoite AKMODNV_PATH="$work" bash "$work/ublue-os/nvidia-install.sh"

rpm -q kmod-nvidia nvidia-driver
rm -rf "$work"
