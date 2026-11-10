#!/usr/bin/env bash
#
# R7 checker — run as root inside the server VM:
#   sudo bash check.sh [lab1|lab2|challenge|all]
#
# R7 is about filesystems and sharing them. The server side is live state:
# partition tables, superblocks, the mount table, exports and firewalld. The
# NFS client in Lab 2 lives on node2, so those checks run over SSH as labuser
# (the shared lab key and client config make that work without a password).
#
# Sizes are ranges in bytes for the same reason as R6: alignment and
# filesystem overhead mean exact counts are wrong, not correct.

set -uo pipefail

LAB="${1:-all}"

PASS=0
FAIL=0

if [ -t 1 ]; then
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  BOLD=$'\033[1m'
  RESET=$'\033[0m'
else
  RED=''
  GREEN=''
  BOLD=''
  RESET=''
fi

section() { printf '\n%s%s%s\n' "$BOLD" "$*" "$RESET"; }
pass()    { printf '  %sPASS%s  %s\n' "$GREEN" "$RESET" "$*"; PASS=$((PASS + 1)); }
fail()    { printf '  %sFAIL%s  %s\n' "$RED" "$RESET" "$*"; FAIL=$((FAIL + 1)); }

# check <description> <command...> — pass when the command exits 0.
check() {
  local desc=$1
  shift
  if "$@" >/dev/null 2>&1; then
    pass "$desc"
  else
    fail "$desc"
  fi
}

# check_fails <description> <command...> — pass when the command exits non-zero.
check_fails() {
  local desc=$1
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$desc"
  else
    pass "$desc"
  fi
}

# val_is <description> <expected> <command...> — compare captured stdout.
val_is() {
  local desc=$1 want=$2 got
  shift 2
  got=$("$@" 2>/dev/null | tr -d '[:space:]')
  if [ "$got" = "$want" ]; then
    pass "$desc"
  else
    fail "$desc"
    printf '        expected: %q\n' "$want"
    printf '        actual:   %q\n' "$got"
  fi
}

# has_text <description> <needle> <command...> — pass when stdout contains it.
has_text() {
  local desc=$1 needle=$2 got
  shift 2
  got=$("$@" 2>/dev/null)
  case "$got" in
    *"$needle"*) pass "$desc" ;;
    *)
      fail "$desc"
      printf '        expected text: %q\n' "$needle"
      printf '        actual:        %q\n' "$got"
      ;;
  esac
}

# size_between <description> <min bytes> <max bytes> <command...>
size_between() {
  local desc=$1 lo=$2 hi=$3 got
  shift 3
  got=$("$@" 2>/dev/null | tr -d '[:space:]B')
  case "$got" in
    ''|*[!0-9]*)
      fail "$desc"
      printf '        could not read a size; got %q\n' "$got"
      return
      ;;
  esac
  if [ "$got" -ge "$lo" ] && [ "$got" -le "$hi" ]; then
    pass "$desc"
  else
    fail "$desc"
    printf '        expected between %s and %s bytes, got %s\n' "$lo" "$hi" "$got"
  fi
}

# ---------------------------------------------------------------------------
# Predicates over the real system
# ---------------------------------------------------------------------------

# Run a command on node2 as labuser. The provisioning config supplies the
# identity file and accept-new host keys.
n2() { runuser -u labuser -- ssh -o BatchMode=yes -o ConnectTimeout=8 node2 "$*" 2>/dev/null; }

part_table() { parted -s /dev/vdb print 2>/dev/null | sed -n 's/^Partition Table: //p'; }
part_bytes() { blockdev --getsize64 "/dev/vdb$1"; }
part_type() {
  sfdisk -d /dev/vdb 2>/dev/null |
    awk -v p="/dev/vdb$1" '$1 == p {
      for (i = 1; i <= NF; i++)
        if ($i ~ /^type=/) {
          sub(/^type=/, "", $i)
          sub(/,.*/, "", $i)
          print tolower($i)
        }
    }'
}
LVM_GUID="e6d6d379-f507-44c2-a23c-238f2a3df928"

fs_type()  { blkid -s TYPE  -o value "$1" 2>/dev/null; }
fs_uuid()  { blkid -s UUID  -o value "$1" 2>/dev/null; }
fs_label() { blkid -s LABEL -o value "$1" 2>/dev/null; }

fstab_source() { findmnt --fstab -n -o SOURCE "$1" 2>/dev/null | tr -d '[:space:]'; }

is_mounted()    { findmnt -n -o TARGET "$1" >/dev/null 2>&1; }
mount_type()    { findmnt -n -o FSTYPE "$1" 2>/dev/null; }
mount_bytes()   { findmnt -b -n -o SIZE "$1" 2>/dev/null; }
mount_options() { findmnt -n -o OPTIONS "$1" 2>/dev/null; }

lv_exists() { lvs --noheadings -o lv_name "r7vg/$1" >/dev/null 2>&1; }
lv_bytes() {
  lvs --noheadings -o lv_size --units b "r7vg/$1" 2>/dev/null | tr -d '[:space:]B'
}

# ---------------------------------------------------------------------------
# Lab 1 — VFAT and synthesized ownership
# ---------------------------------------------------------------------------
run_lab1() {
  section "R7 Lab 1 — A VFAT volume and mount options"

  val_is "/dev/vdb carries a GPT partition table" gpt part_table

  check "/dev/vdb1 exists" test -b /dev/vdb1

  # 512 MiB is 536870912 bytes.
  size_between "/dev/vdb1 is about 512 MiB" 520000000 545000000 part_bytes 1

  val_is "/dev/vdb1 holds a VFAT filesystem" vfat fs_type /dev/vdb1

  val_is "the VFAT filesystem is labelled R7DATA" R7DATA fs_label /dev/vdb1

  check "/srv/r7/vfat is mounted" is_mounted /srv/r7/vfat

  local uuid
  uuid=$(fs_uuid /dev/vdb1)
  if [ -n "$uuid" ]; then
    val_is "fstab mounts /srv/r7/vfat by its UUID" "UUID=$uuid" fstab_source /srv/r7/vfat
  else
    fail "fstab mounts /srv/r7/vfat by its UUID"
    printf '        /dev/vdb1 has no filesystem UUID\n'
  fi

  # VFAT has no on-disk ownership: uid= on the mount supplies it.
  has_text "the mount maps files to labuser's uid" "uid=$(id -u labuser)" \
    mount_options /srv/r7/vfat

  if is_mounted /srv/r7/vfat; then
    rm -f /srv/r7/vfat/.r7check 2>/dev/null
    if runuser -u labuser -- bash -c 'echo probe > /srv/r7/vfat/.r7check' 2>/dev/null; then
      val_is "a file written by labuser belongs to labuser" labuser \
        bash -c 'stat -c %U /srv/r7/vfat/.r7check'
    else
      fail "a file written by labuser belongs to labuser"
      printf '        labuser could not write to /srv/r7/vfat\n'
    fi
    rm -f /srv/r7/vfat/.r7check 2>/dev/null

    # VFAT cannot store a symlink. This also proves the mount is real VFAT and
    # not an ext4 or XFS stand-in.
    rm -f /srv/r7/vfat/.r7link 2>/dev/null
    check_fails "VFAT rejects a symbolic link" \
      runuser -u labuser -- ln -s note.txt /srv/r7/vfat/.r7link
    rm -f /srv/r7/vfat/.r7link 2>/dev/null
  else
    fail "a file written by labuser belongs to labuser"
    fail "VFAT rejects a symbolic link"
  fi

  has_text "the root filesystem is still in fstab" "UUID=" \
    bash -c "findmnt --fstab -n -o SOURCE /"
}

# ---------------------------------------------------------------------------
# Lab 2 — NFS export on server, autofs on node2
# ---------------------------------------------------------------------------
run_lab2() {
  section "R7 Lab 2 — An NFS export and autofs"

  check "the NFS server is enabled at boot" systemctl is-enabled --quiet nfs-server

  check "the NFS server is running" systemctl is-active --quiet nfs-server

  has_text "the export list includes /srv/r7/export" "/srv/r7/export" exportfs -v

  has_text "the export is limited to the lab network" "10.10.10.0/24" exportfs -v

  has_text "showmount lists the export" "/srv/r7/export" showmount -e localhost

  check "firewalld allows the nfs service" firewall-cmd --query-service=nfs

  # The client half lives on node2.
  val_is "node2 has autofs enabled at boot" enabled n2 "systemctl is-enabled autofs"

  val_is "node2 has autofs running" active n2 "systemctl is-active autofs"

  check "node2 has an autofs master drop-in" \
    n2 "test -f /etc/auto.master.d/r7.autofs"

  check "node2 has the r7 automount map" n2 "test -f /etc/auto.r7"

  check "the map defines the share key" n2 "grep -q '^share' /etc/auto.r7"

  check "the map points at the server export" \
    n2 "grep -q '10.10.10.10:/srv/r7/export' /etc/auto.r7"

  # Accessing the path is what makes autofs mount; there is no mount at boot.
  if n2 "ls /mnt/r7auto/share/hello.txt" >/dev/null 2>&1; then
    pass "accessing the automount path mounts the export"
  else
    fail "accessing the automount path mounts the export"
    printf '        node2 could not read /mnt/r7auto/share/hello.txt\n'
  fi

  has_text "the automount is an NFS filesystem" nfs \
    n2 "findmnt -no FSTYPE /mnt/r7auto/share"

  # Regression: the VFAT volume from Lab 1 is untouched.
  check "the VFAT volume is still mounted" is_mounted /srv/r7/vfat
}

# ---------------------------------------------------------------------------
# Challenge — Grow an ext4 logical volume and its filesystem
# ---------------------------------------------------------------------------
run_challenge() {
  section "R7 Challenge — Grow ext4 without losing data"

  check "/dev/vdb2 exists" test -b /dev/vdb2

  size_between "/dev/vdb2 is about 1.5 GiB" 1550000000 1650000000 part_bytes 2

  val_is "/dev/vdb2 is marked as a Linux LVM partition" "$LVM_GUID" part_type 2

  val_is "/dev/vdb2 is a physical volume in r7vg" r7vg \
    bash -c "pvs --noheadings -o vg_name /dev/vdb2"

  check "logical volume r7data exists in r7vg" lv_exists r7data

  size_between "r7data grew to about 1 GiB" 1000000000 1150000000 lv_bytes r7data

  val_is "r7data holds an ext4 filesystem" ext4 fs_type /dev/r7vg/r7data

  check "/srv/r7/data is mounted" is_mounted /srv/r7/data

  val_is "/srv/r7/data is mounted as ext4" ext4 mount_type /srv/r7/data

  local uuid
  uuid=$(fs_uuid /dev/r7vg/r7data)
  if [ -n "$uuid" ]; then
    val_is "fstab mounts /srv/r7/data by its UUID" "UUID=$uuid" fstab_source /srv/r7/data
  else
    fail "fstab mounts /srv/r7/data by its UUID"
    printf '        r7data has no filesystem UUID\n'
  fi

  # The filesystem followed the logical volume: resize2fs ran.
  size_between "the ext4 filesystem grew with the volume" 1000000000 1150000000 \
    mount_bytes /srv/r7/data

  size_between "the data file written before the grow survived" 100000000 115000000 \
    bash -c "stat -c %s /srv/r7/data/blob.bin"

  check "the whole fstab parses and its sources resolve" findmnt --verify

  # Regressions: the challenge must not sacrifice the earlier labs.
  check "the VFAT volume is still mounted" is_mounted /srv/r7/vfat
  has_text "the NFS export is still active" "/srv/r7/export" exportfs -v
  check "node2 can still read the autofs share" \
    n2 "test -r /mnt/r7auto/share/hello.txt"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
section "RHCSA Field Guide — R7 checker"

case "$LAB" in
  lab1) run_lab1 ;;
  lab2) run_lab2 ;;
  challenge) run_challenge ;;
  all)
    run_lab1
    run_lab2
    run_challenge
    ;;
  *)
    printf 'usage: %s [lab1|lab2|challenge|all]\n' "$0" >&2
    exit 2
    ;;
esac

printf '\n%sSummary%s\n' "$BOLD" "$RESET"
printf '  %d passed, %d failed\n' "$PASS" "$FAIL"

if [ "$FAIL" -eq 0 ]; then
  printf '\n%sAll checks passed.%s\n' "$GREEN" "$RESET"
  exit 0
fi

printf '\n%sReview the failures above and run the checker again.%s\n' "$RED" "$RESET"
exit 1
