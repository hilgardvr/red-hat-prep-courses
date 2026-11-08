#!/usr/bin/env bash
# node2-specific provisioning.
#
# node2 is the remote target for SSH, NFS, and firewall exercises. sshd must be
# running for the SSH and R1 challenge work. firewalld is installed and enabled
# for both nodes by common.sh.

set -euo pipefail

systemctl enable --now sshd

install -d -o labuser -g labuser -m 755 /home/labuser/handoff

echo "==> node2 ready (sshd enabled, /home/labuser/handoff created)"
