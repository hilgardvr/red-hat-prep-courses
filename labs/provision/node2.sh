#!/usr/bin/env bash
# node2-specific provisioning.
#
# node2 is the remote target for SSH, NFS, and firewall exercises. For R1 it
# only needs sshd running and a handoff directory for the challenge.

set -euo pipefail

systemctl enable --now sshd

install -d -o labuser -g labuser -m 755 /home/labuser/handoff

echo "==> node2 ready (sshd enabled, /home/labuser/handoff created)"
