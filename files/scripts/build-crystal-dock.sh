#!/usr/bin/env bash
# Builds Crystal Dock (https://github.com/dangvd/crystal-dock, GPL-3.0) – a dock with
# Mac-like zooming icons, as an alternative to Plasma's dock (`goblin dock crystal`).
# Not in Fedora's repos, so it's built here, in its own build stage; the result lands
# in /out and is copied into the image.
set -oue pipefail

dnf5 -y install git cmake gcc-c++ qt6-qtbase-devel qt6-qtbase-private-devel \
    wayland-devel layer-shell-qt-devel

# Newest release
tag=$(git ls-remote --tags --refs https://github.com/dangvd/crystal-dock 'v*' \
      | sed 's|.*refs/tags/||' | sort -V | tail -n1)
echo "Crystal Dock version: $tag"
src=/tmp/crystal-dock
git clone --depth 1 --branch "$tag" https://github.com/dangvd/crystal-dock "$src"

cmake -S "$src/src" -B "$src/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build "$src/build" -j"$(nproc)"
DESTDIR=/out cmake --install "$src/build"
find /out -type f | sort
