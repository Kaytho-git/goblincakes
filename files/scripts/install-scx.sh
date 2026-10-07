#!/usr/bin/env bash
# sched_ext schedulers (scx_lavd) for the "Spelschemaläggare" switch in GOBLINCAKES Config.
# Optional: from Fedora, else from the CachyOS addons COPR. If neither has it, the
# switch just shows as not available – the build must not fail because of it.
set -uo pipefail
if ! dnf5 -y install scx-scheds; then
    if dnf5 -y copr enable bieszczaders/kernel-cachyos-addons; then
        dnf5 -y install scx-scheds || echo "scx-scheds not available, skipping"
        dnf5 -y copr disable bieszczaders/kernel-cachyos-addons || true
        rm -f /etc/yum.repos.d/_copr*kernel-cachyos-addons*.repo
    fi
fi
# Installed but off: the user switches it on in GOBLINCAKES Config
systemctl disable scx.service 2>/dev/null || true
exit 0
