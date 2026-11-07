#!/usr/bin/env bash
# First-boot provisioning shared by server and node2.
#
# Arguments:
#   $1  node name (server|node2)
#   $2  node IP
#   $3  repository mode (online|iso)

set -euo pipefail

NODE_NAME="${1:?node name is required}"
NODE_IP="${2:?node IP is required}"
REPO_MODE="${3:-online}"

echo "==> Provisioning ${NODE_NAME} (${NODE_IP}), repository mode: ${REPO_MODE}"

# ---------------------------------------------------------------------------
# Hostname and name resolution
# ---------------------------------------------------------------------------
hostnamectl set-hostname "$NODE_NAME"

if ! grep -q '^10\.10\.10\.10[[:space:]]' /etc/hosts; then
  cat >> /etc/hosts <<'EOF'

# RHCSA lab
10.10.10.10 server
10.10.10.11 node2
EOF
fi

# ---------------------------------------------------------------------------
# Repositories
# ---------------------------------------------------------------------------
bash /tmp/repo.sh "$REPO_MODE"

# ---------------------------------------------------------------------------
# Base packages
# ---------------------------------------------------------------------------
PACKAGES=(
  man-db
  man-pages
  vim-enhanced
  bash-completion
  tar
  gzip
  bzip2
  openssh-clients
  sudo
)

echo "==> Installing base packages"
if ! dnf -y install "${PACKAGES[@]}"; then
  cat >&2 <<'EOF'

ERROR: package installation failed.

The box has no usable DNF repositories. Choose one of:

  * Use the AlmaLinux 10 default box (no action needed).
  * For RHEL, register a subscription:
        sudo subscription-manager register --username <account>
        sudo subscription-manager attach --auto
  * Or attach a RHEL 10 installation ISO and rebuild:
        LAB_ISO=/path/to/rhel-10-x86_64-dvd.iso ./bin/lab reset
EOF
  exit 1
fi

# ---------------------------------------------------------------------------
# Lab user
# ---------------------------------------------------------------------------
if ! id labuser >/dev/null 2>&1; then
  useradd -m -s /bin/bash labuser
fi

echo 'labuser:labpass' | chpasswd
usermod -aG wheel labuser

cat > /etc/sudoers.d/90-rhcsa-labuser <<'EOF'
labuser ALL=(ALL) ALL
EOF
chmod 440 /etc/sudoers.d/90-rhcsa-labuser

# ---------------------------------------------------------------------------
# Shared lab SSH key and client configuration
# ---------------------------------------------------------------------------
install_lab_key() {
  local user=$1
  local home
  home=$(getent passwd "$user" | cut -d: -f6)

  install -d -m 700 -o "$user" -g "$user" "$home/.ssh"
  install -m 600 -o "$user" -g "$user" /tmp/lab_key "$home/.ssh/lab_ed25519"
  install -m 644 -o "$user" -g "$user" /tmp/lab_key.pub "$home/.ssh/lab_ed25519.pub"

  touch "$home/.ssh/authorized_keys"
  if ! grep -qxF "$(cat /tmp/lab_key.pub)" "$home/.ssh/authorized_keys"; then
    cat /tmp/lab_key.pub >> "$home/.ssh/authorized_keys"
  fi
  chown "$user:$user" "$home/.ssh/authorized_keys"
  chmod 600 "$home/.ssh/authorized_keys"

  cat > "$home/.ssh/config" <<'EOF'
Host server 10.10.10.10
    IdentityFile ~/.ssh/lab_ed25519
    StrictHostKeyChecking accept-new

Host node2 10.10.10.11
    IdentityFile ~/.ssh/lab_ed25519
    StrictHostKeyChecking accept-new
EOF
  chown "$user:$user" "$home/.ssh/config"
  chmod 600 "$home/.ssh/config"
}

install_lab_key vagrant
install_lab_key labuser

cat > /etc/ssh/ssh_config.d/99-rhcsa-lab.conf <<'EOF'
Host 10.10.10.*
    StrictHostKeyChecking accept-new
EOF

# ---------------------------------------------------------------------------
# Lab marker and cleanup
# ---------------------------------------------------------------------------
cat > /etc/rhcsa-lab <<EOF
LAB_NODE=${NODE_NAME}
LAB_IP=${NODE_IP}
LAB_REPO_MODE=${REPO_MODE}
EOF

rm -f /tmp/lab_key /tmp/lab_key.pub

echo "==> ${NODE_NAME} ready"
