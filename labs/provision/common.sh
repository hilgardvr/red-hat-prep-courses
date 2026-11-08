#!/usr/bin/env bash
# First-boot provisioning shared by server and node2.
#
# Arguments:
#   $1  node name (server|node2)
#   $2  node IP

set -euo pipefail

NODE_NAME="${1:?node name is required}"
NODE_IP="${2:?node IP is required}"

echo "==> Provisioning ${NODE_NAME} (${NODE_IP})"

# ---------------------------------------------------------------------------
# Hostname and name resolution
# ---------------------------------------------------------------------------
hostnamectl set-hostname "$NODE_NAME"

# The cloud image maps the hostname to 127.0.1.1, which shadows the lab
# addresses for `getent hosts`. Remove it so name resolution uses 10.10.10.x.
sed -i '/^127\.0\.1\.1[[:space:]]/d' /etc/hosts

if ! grep -q '^10\.10\.10\.10[[:space:]]' /etc/hosts; then
  cat >> /etc/hosts <<'EOF'

# RHCSA lab
10.10.10.10 server
10.10.10.11 node2
EOF
fi

# ---------------------------------------------------------------------------
# Private lab network
# ---------------------------------------------------------------------------
# The Vagrantfile attaches the private NIC with auto_config disabled because
# Vagrant's guest-side static network configuration is unreliable on AlmaLinux
# 10. Configure it with NetworkManager instead so the address is persistent.
MGMT_IFACE=$(ip route show default | awk '/^default/ {print $5; exit}')
PRIVATE_IFACE=""

while IFS=: read -r dev type _state; do
  [ "$type" = "ethernet" ] || continue
  [ "$dev" = "$MGMT_IFACE" ] && continue
  PRIVATE_IFACE="$dev"
done < <(nmcli -t -f DEVICE,TYPE,STATE device status)

if [ -z "$PRIVATE_IFACE" ]; then
  echo "ERROR: could not identify the private lab interface" >&2
  exit 1
fi

echo "==> Configuring ${PRIVATE_IFACE} as ${NODE_IP}/24"
nmcli connection delete lab-private >/dev/null 2>&1 || true
nmcli connection add \
  type ethernet \
  con-name lab-private \
  ifname "$PRIVATE_IFACE" \
  ipv4.method manual \
  ipv4.addresses "${NODE_IP}/24" \
  ipv4.never-default yes \
  ipv6.method disabled \
  connection.autoconnect yes \
  connection.autoconnect-priority 100

# Remove any DHCP profile the box created for the private NIC so only the
# static profile can activate after a reboot.
while IFS=: read -r cname cdev; do
  [ "$cdev" = "$PRIVATE_IFACE" ] || continue
  [ "$cname" = "lab-private" ] && continue
  nmcli connection delete "$cname" >/dev/null 2>&1 || true
done < <(nmcli -t -f NAME,DEVICE connection show)

nmcli connection up lab-private

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

The VM could not reach usable DNF repositories. Check that the host and the
VM have working internet access, then rebuild the lab:

  ./bin/lab destroy
  ./bin/lab up
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
EOF

rm -f /tmp/lab_key /tmp/lab_key.pub

echo "==> ${NODE_NAME} ready"
