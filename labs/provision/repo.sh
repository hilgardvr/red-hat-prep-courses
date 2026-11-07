#!/usr/bin/env bash
# Configure DNF repositories for the lab.
#
# online: leave the box's existing repositories alone.
# iso:    mount the attached RHEL/AlmaLinux installation DVD and use BaseOS +
#         AppStream from it. This mirrors the exam's offline package source.

set -euo pipefail

MODE="${1:-online}"

case "$MODE" in
  online)
    echo "==> Using the box's configured DNF repositories"
    ;;

  iso)
    echo "==> Configuring the offline installation-media repository"

    mkdir -p /mnt/rhel-iso

    ISO_DEV=""
    if ! mountpoint -q /mnt/rhel-iso; then
      mounted=0
      for dev in /dev/sr0 /dev/sr1 /dev/cdrom; do
        if [ -b "$dev" ] && mount -o ro "$dev" /mnt/rhel-iso 2>/dev/null; then
          ISO_DEV="$dev"
          mounted=1
          break
        fi
      done
      if [ "$mounted" -ne 1 ]; then
        echo "ERROR: could not mount the installation ISO." >&2
        echo "Check that LAB_ISO points at a bootable RHEL 10 DVD image." >&2
        exit 1
      fi
    fi

    if [ ! -d /mnt/rhel-iso/BaseOS ] || [ ! -d /mnt/rhel-iso/AppStream ]; then
      echo "ERROR: the ISO does not contain BaseOS/ and AppStream/." >&2
      echo "Use a full RHEL 10 installation DVD, not a boot-only image." >&2
      exit 1
    fi

    cat > /etc/yum.repos.d/rhel-lab.repo <<'EOF'
[lab-baseos]
name=RHCSA Lab BaseOS
baseurl=file:///mnt/rhel-iso/BaseOS
enabled=1
gpgcheck=0

[lab-appstream]
name=RHCSA Lab AppStream
baseurl=file:///mnt/rhel-iso/AppStream
enabled=1
gpgcheck=0
EOF

    # In offline mode, do not let an unregistered box's stale online repos
    # break package installation.
    for repo in /etc/yum.repos.d/*.repo; do
      [ -e "$repo" ] || continue
      [ "$repo" = "/etc/yum.repos.d/rhel-lab.repo" ] && continue
      sed -i -E 's/^[[:space:]]*enabled[[:space:]]*=[[:space:]]*1[[:space:]]*$/enabled=0/' "$repo"
    done

    if [ -z "$ISO_DEV" ]; then
      ISO_DEV=$(findmnt -n -o SOURCE /mnt/rhel-iso 2>/dev/null || true)
    fi
    if [ -n "$ISO_DEV" ] && ! grep -q "[[:space:]]/mnt/rhel-iso[[:space:]]" /etc/fstab; then
      echo "$ISO_DEV /mnt/rhel-iso iso9660 ro,nofail 0 0" >> /etc/fstab
    fi

    dnf clean all
    ;;

  *)
    echo "ERROR: unknown repository mode: $MODE" >&2
    exit 1
    ;;
esac
