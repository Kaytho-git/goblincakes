#!/usr/bin/env bash
# Newer libratbag (ratbagd, the service Piper talks to), in its own build stage (see
# common-stages.yml). Fedora has the last release, 0.18 from 2024; the Logitech G502 X Plus,
# the G502 X Wireless through its Lightspeed receiver and the profile fix for all G502 X
# (INDEX_OFFSET) only exist in libratbag's git (10 Oct: Piper didn't see the user's G502 X).
# Pinned to a tested commit; the result lands in /out and is copied over Fedora's package.
set -oue pipefail

commit=8235b5bb6032dea15901ab58a8218956f4494d08 # 17 Sep 2026

dnf5 -y install git meson gcc swig python3-devel libunistring-devel \
    'pkgconfig(libudev)' 'pkgconfig(libevdev)' 'pkgconfig(glib-2.0)' \
    'pkgconfig(json-glib-1.0)' 'pkgconfig(libsystemd)' 'pkgconfig(systemd)'

src=/tmp/libratbag
git clone https://github.com/libratbag/libratbag "$src"
git -C "$src" checkout --quiet "$commit"

# Same places as Fedora's package (/usr/sbin is a link to /usr/bin in Fedora – install
# straight into bin, so copying the result never replaces that link with a folder)
meson setup "$src/build" "$src" --prefix=/usr --sbindir=bin --libdir=lib64 \
    -Dtests=false -Ddocumentation=false
ninja -C "$src/build"
DESTDIR=/out meson install -C "$src/build"

# Only what ratbagd and Piper need: no headers or development files
rm -rf /out/usr/include /out/usr/lib64/pkgconfig
ls /out/usr/share/libratbag | grep -c '\.device$'
ls /out/usr/share/libratbag | grep g502
find /out -type f ! -name '*.device' | sort
