#!/usr/bin/env bash
# Both GOBLINCAKES variants are signed with the same key. The signing module only
# trusts this image's own name, so trust the other variant too – otherwise
# switching variant (GOBLINCAKES Config → Grafik) would be refused.
# Also note which variant this image is, for the Grafik tab, and the GOBLINCAKES version.
set -oue pipefail

registry=${IMAGE_REGISTRY:-ghcr.io/kaytho-git}
own_key=/etc/pki/containers/${IMAGE_NAME}.pub
[ -f "$own_key" ] || { echo "No signing key $own_key" >&2; exit 1; }

for name in goblincakes goblincakes-nvidia; do
    cp -n "$own_key" "/etc/pki/containers/$name.pub" || true
    jq --arg image "$registry/$name" --arg key "/etc/pki/containers/$name.pub" \
       '.transports.docker[$image] = [{"type": "sigstoreSigned", "keyPath": $key, "signedIdentity": {"type": "matchRepository"}}]' \
       /etc/containers/policy.json > /tmp/policy.json
    mv /tmp/policy.json /etc/containers/policy.json
    printf 'docker:\n  %s/%s:\n    use-sigstore-attachments: true\n' "$registry" "$name" \
        > "/etc/containers/registries.d/${registry##*/}-$name.yaml"
done

mkdir -p /usr/share/goblincakes
case $IMAGE_NAME in
    *-nvidia) echo nvidia ;;
    *) echo base ;;
esac > /usr/share/goblincakes/variant
cat /usr/share/goblincakes/variant

# GOBLINCAKES' own version: the build date (like Bazzite/Universal Blue), e.g. 2026.10.07.
# Shown in GOBLINCAKES Config, goblin fast and the boot menu (PRETTY_NAME). Fedora's own
# VERSION_ID stays as it is – tools rely on it.
version=$(date -u +%Y.%m.%d)
echo "$version" > /usr/share/goblincakes/version
sed -i --follow-symlinks -e '/^IMAGE_VERSION=/d' -e "s|^PRETTY_NAME=.*|PRETTY_NAME=\"GOBLINCAKES $version\"|" /usr/lib/os-release
echo "IMAGE_VERSION=$version" >> /usr/lib/os-release
grep -E '^(PRETTY_NAME|IMAGE_VERSION)=' /usr/lib/os-release
