#!/usr/bin/env bash
#
# R6 checker — run as root inside the server VM:
#   sudo bash check.sh [lab1|lab2|challenge|all]
#
# R6 is about the real block devices, the LVM metadata, the filesystems and
# the running mount table, so this checker asks the kernel and the storage
# tools what they think. There is no file tree to redirect, which means
# LAB_ROOT does not apply, the same way it does not apply to R5.
#
# It reads end state, not the commands used: a partition is a partition
# whether it came from parted, fdisk or the installer.

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

# The partition-table type of /dev/vdbN, lowercased. parted calls the LVM
# type a "flag"; on disk it is a GPT type GUID, which is what sfdisk prints.
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

part_table() {
  parted -s /dev/vdb print 2>/dev/null | sed -n 's/^Partition Table: //p'
}

part_bytes() { blockdev --getsize64 "/dev/vdb$1"; }

pv_vg() { pvs --noheadings -o vg_name "$1" 2>/dev/null; }

lv_exists() { lvs --noheadings -o lv_name "r6vg/$1" >/dev/null 2>&1; }

lv_bytes() {
  lvs --noheadings -o lv_size --units b "r6vg/$1" 2>/dev/null | tr -d '[:space:]B'
}

fs_type()  { blkid -s TYPE  -o value "$1" 2>/dev/null; }
fs_uuid()  { blkid -s UUID  -o value "$1" 2>/dev/null; }
fs_label() { blkid -s LABEL -o value "$1" 2>/dev/null; }

# The source field fstab uses for a mount point, e.g. UUID=... or LABEL=...
fstab_source() { findmnt --fstab -n -o SOURCE "$1" 2>/dev/null | tr -d '[:space:]'; }

is_mounted()  { findmnt -n -o TARGET "$1" >/dev/null 2>&1; }
mount_type()  { findmnt -n -o FSTYPE "$1" 2>/dev/null; }
mount_bytes() { findmnt -b -n -o SIZE "$1" 2>/dev/null; }

swap_uuids() { swapon --show=UUID --noheadings 2>/dev/null | tr -d '[:space:]'; }

fstab_swap_source() {
  awk '$3 == "swap" { print $1 }' /etc/fstab 2>/dev/null | tr -d '[:space:]'
}

# ---------------------------------------------------------------------------
# Lab 1 — Partition, LVM volume, XFS, mounted by UUID
# ---------------------------------------------------------------------------
run_lab1() {
  section "R6 Lab 1 — A partition, a volume group, and a UUID mount"

  check "the LVM tools are installed" command -v pvs

  val_is "/dev/vdb carries a GPT partition table" gpt part_table

  check "/dev/vdb1 exists" test -b /dev/vdb1

  # 5 GiB is 5368709120 bytes; allow a little slack for alignment.
  size_between "/dev/vdb1 is about 5 GiB" 4900000000 5400000000 part_bytes 1

  val_is "/dev/vdb1 is marked as a Linux LVM partition" "$LVM_GUID" part_type 1

  val_is "/dev/vdb1 is a physical volume in r6vg" r6vg pv_vg /dev/vdb1

  check "logical volume r6data exists in r6vg" lv_exists r6data

  val_is "r6data holds an XFS filesystem" xfs fs_type /dev/r6vg/r6data

  check "/srv/r6/data is mounted" is_mounted /srv/r6/data

  val_is "/srv/r6/data is mounted as XFS" xfs mount_type /srv/r6/data

  # Building the expected value from the filesystem's own UUID proves that
  # fstab points at this filesystem, not at a stale UUID from an earlier try.
  local uuid
  uuid=$(fs_uuid /dev/r6vg/r6data)
  if [ -n "$uuid" ]; then
    val_is "fstab mounts /srv/r6/data by its UUID" "UUID=$uuid" fstab_source /srv/r6/data
  else
    fail "fstab mounts /srv/r6/data by its UUID"
    printf '        r6data has no filesystem UUID\n'
  fi

  has_text "the root filesystem is still in fstab" "UUID=" \
    bash -c "findmnt --fstab -n -o SOURCE /"
}

# ---------------------------------------------------------------------------
# Lab 2 — Swap and a labelled ext4 volume
# ---------------------------------------------------------------------------
run_lab2() {
  section "R6 Lab 2 — Swap and a label mount"

  check "logical volume r6swap exists in r6vg" lv_exists r6swap
  check "logical volume r6label exists in r6vg" lv_exists r6label

  local uuid
  uuid=$(fs_uuid /dev/r6vg/r6swap)
  if [ -n "$uuid" ]; then
    has_text "r6swap is active swap" "$uuid" swap_uuids
    val_is "fstab enables swap by UUID" "UUID=$uuid" fstab_swap_source
  else
    fail "r6swap is active swap"
    printf '        r6swap has no swap UUID (was mkswap run?)\n'
    fail "fstab enables swap by UUID"
  fi

  size_between "r6swap is about 512 MiB" 500000000 540000000 lv_bytes r6swap

  val_is "r6label holds an ext4 filesystem" ext4 fs_type /dev/r6vg/r6label
  val_is "the r6label filesystem is labelled r6label" r6label fs_label /dev/r6vg/r6label

  check "/srv/r6/label is mounted" is_mounted /srv/r6/label

  val_is "fstab mounts /srv/r6/label by LABEL" LABEL=r6label fstab_source /srv/r6/label

  val_is "/srv/r6/label is mounted as ext4" ext4 mount_type /srv/r6/label

  check "the whole fstab parses and its sources resolve" findmnt --verify

  # Regression: Lab 2 must not disturb Lab 1.
  check "r6data is still mounted" is_mounted /srv/r6/data
}

# ---------------------------------------------------------------------------
# Challenge — Add a partition, extend the volume group and the filesystem
# ---------------------------------------------------------------------------
run_challenge() {
  section "R6 Challenge — Extend storage non-destructively"

  check "/dev/vdb2 exists" test -b /dev/vdb2

  size_between "/dev/vdb2 takes the rest of the disk" 4900000000 5400000000 part_bytes 2

  val_is "/dev/vdb2 is marked as a Linux LVM partition" "$LVM_GUID" part_type 2

  val_is "/dev/vdb2 is a physical volume in r6vg" r6vg pv_vg /dev/vdb2

  val_is "r6vg now spans two physical volumes" 2 \
    bash -c "vgs --noheadings -o pv_count r6vg"

  size_between "r6data has grown to at least 4 GiB" 3900000000 5000000000 lv_bytes r6data

  size_between "the r6data filesystem grew with it" 4000000000 5000000000 mount_bytes /srv/r6/data

  check "r6data is still mounted" is_mounted /srv/r6/data

  val_is "r6data is still handled by UUID in fstab" \
    "UUID=$(fs_uuid /dev/r6vg/r6data)" fstab_source /srv/r6/data

  # Regression: the challenge must not sacrifice the earlier labs.
  val_is "r6label is still mounted by LABEL" LABEL=r6label fstab_source /srv/r6/label

  local uuid
  uuid=$(fs_uuid /dev/r6vg/r6swap)
  if [ -n "$uuid" ]; then
    has_text "r6swap is still active swap" "$uuid" swap_uuids
  else
    fail "r6swap is still active swap"
    printf '        r6swap has no swap UUID\n'
  fi

  check "the whole fstab still parses and its sources resolve" findmnt --verify
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
section "RHCSA Field Guide — R6 checker"

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
