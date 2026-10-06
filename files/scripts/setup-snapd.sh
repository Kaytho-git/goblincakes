#!/usr/bin/env bash
# snapd on an atomic (read-only) system:
#  - /snap must exist in the root, which is read-only once booted, so the link is made here,
#    while the image is built. It points to /var, which is writable.
#  - Folders that the snapd package puts in /var are only copied on a fresh install,
#    not on updates or rebases, so they are recreated at boot with systemd-tmpfiles.
set -oue pipefail

ln -sfn var/lib/snapd/snap /snap

conf=/usr/lib/tmpfiles.d/goblincakes-snapd.conf
echo "# Generated at image build from the snapd package's folders in /var" > "$conf"
for dir in /var/lib/snapd /var/snap /var/cache/snapd; do
    [ -e "$dir" ] || continue
    find "$dir" -type d -printf 'd %p %#m root root -\n' >> "$conf"
    find "$dir" -type l -printf 'L %p - - - - %l\n' >> "$conf"
done
# The snap folder itself must always be there, the /snap link points to it
grep -q '^d /var/lib/snapd/snap ' "$conf" || echo 'd /var/lib/snapd/snap 0755 root root -' >> "$conf"
cat "$conf"
