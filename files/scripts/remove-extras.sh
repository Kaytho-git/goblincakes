#!/usr/bin/env bash
# A smaller GOBLINCAKES (11 Oct, the user's choice): Universal Blue's Kinoite brings input
# methods for Chinese, Japanese, Korean, Thai, Vietnamese, Sinhala and more (fcitx5 with their
# dictionaries). Only needed to type in those languages – Swedish and English don't use them.
# Fcitx 5 itself stays (Plasma's keyboard settings use it); reading those languages is
# unaffected (the fonts stay).
set -euo pipefail
remove=()
for pkg in fcitx5-chewing fcitx5-chinese-addons fcitx5-hangul fcitx5-libthai fcitx5-m17n \
    fcitx5-mozc fcitx5-sayura fcitx5-unikey; do
    rpm -q "$pkg" >/dev/null 2>&1 && remove+=("$pkg")
done
if [ ${#remove[@]} -gt 0 ]; then
    dnf5 -y remove "${remove[@]}"
fi
echo "remove-extras: removed ${#remove[@]} packages: ${remove[*]}"
