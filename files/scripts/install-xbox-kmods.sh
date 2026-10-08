#!/usr/bin/env bash
# Xbox controller drivers: xone (wireless dongle, USB) and xpadneo (Bluetooth), pre-built by
# Universal Blue and signed with their key (Secure Boot: Grafik tab in GOBLINCAKES Config).
#
# Replaces BlueBuild's akmods module, which takes Universal Blue's newest akmods image –
# when that is built for a newer kernel than the base image has (they update at different
# times), the whole GOBLINCAKES build failed (8 Oct: 7.2.9 drivers, 7.2.8 kernel). Here the
# drivers are taken from the akmods image made for exactly this kernel; if there is none,
# the build goes on without them (they come back with the next build).
set -uo pipefail

fedora=$(rpm -E %fedora)
kernel=$(rpm -q kernel-core --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -n1)
echo "Kernel in the image: $kernel"

work=$(mktemp -d)
for tag in "main-$fedora-$kernel" "main-$fedora"; do
    echo "Trying ghcr.io/ublue-os/akmods:$tag"
    rm -rf "$work/image" "$work/rpms"
    skopeo copy --retry-times 3 "docker://ghcr.io/ublue-os/akmods:$tag" "dir:$work/image" >/dev/null 2>&1 || continue
    mkdir -p "$work/rpms"
    for layer in $(python3 -c 'import json,sys; [print(l["digest"].split(":")[1]) for l in json.load(open(sys.argv[1]))["layers"]]' "$work/image/manifest.json"); do
        tar -xzf "$work/image/$layer" -C "$work/rpms" 2>/dev/null || true
    done
    mapfile -t rpms < <(find "$work/rpms" -name '*.rpm' \( -name '*xone*' -o -name '*xpadneo*' \))
    [ ${#rpms[@]} -gt 0 ] || continue
    # Only drivers made for this exact kernel can load
    if ! find "$work/rpms" -name "kmod-xone-*.rpm" -exec rpm -qp --requires {} \; 2>/dev/null \
            | grep -q "kernel-uname-r = $kernel"; then
        echo "  built for another kernel, not this one"
        continue
    fi
    if dnf5 -y install "${rpms[@]}"; then
        echo "Xbox drivers installed (xone, xpadneo) from akmods:$tag"
        rm -rf "$work"
        exit 0
    fi
done
rm -rf "$work"
echo "WARNING: no Xbox drivers for kernel $kernel yet – building without them this time"
exit 0
