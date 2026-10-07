#!/usr/bin/env bash
# Steam in the image (like Bazzite): the steam package from RPM Fusion (nonfree) with its
# 32-bit libraries and controller rules. Steam then keeps its own client up to date in
# ~/.local/share/Steam. RPM Fusion is only used during the build, unless the base image
# already had it.
set -euo pipefail
fedora=$(rpm -E %fedora)
added=()
for repo in free nonfree; do
    if ! rpm -q "rpmfusion-$repo-release" >/dev/null 2>&1; then
        dnf5 -y install "https://mirrors.rpmfusion.org/$repo/fedora/rpmfusion-$repo-release-$fedora.noarch.rpm"
        added+=("rpmfusion-$repo-release")
    fi
done
# Explicitly enabled, in case the base image ships the repos switched off
dnf5 -y install \
    --enablerepo=rpmfusion-free --enablerepo=rpmfusion-free-updates \
    --enablerepo=rpmfusion-nonfree --enablerepo=rpmfusion-nonfree-updates \
    steam
if [ ${#added[@]} -gt 0 ]; then
    dnf5 -y remove "${added[@]}"
fi
