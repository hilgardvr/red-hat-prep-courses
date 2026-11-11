#!/usr/bin/env bash
#
# R11 checker — run as root inside the server VM:
#   sudo bash check.sh [lab1|lab2|challenge|all]
#
# R11 is about the part of the system that runs before the system does, so the
# checker reads each fact in the place where it is actually decided:
#
#   - The bootloader has three storage layers that can disagree. The intent
#     lives in /etc/default/grub, the generated menu lives in
#     /boot/grub2/grub.cfg, and each kernel's arguments live in its own BLS
#     entry under /boot/loader/entries. A setting that only reaches one of
#     them is the classic mistake, so every kernel-argument check looks at
#     ALL entries and the running /proc/cmdline separately.
#   - "The update is done" is not a command that was run. It is a successful
#     dnf transaction plus `check-update` finding nothing left, so both are
#     asserted.
#   - A recovered root account is proved by usability (`passwd -S` must say
#     P, not L or NP), by a marker file the learner created inside the
#     chroot, and by the label that only a completed relabel boot can put on
#     it. The password itself is never asserted.
#
# The lab1 `panic=10` and challenge `panic_on_warn=1` checks read
# /proc/cmdline and the live sysctl, so they fail until the learner has
# rebooted. That is deliberate: a kernel argument is a promise about the
# next boot.

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

# ---------------------------------------------------------------------------
# Predicates
# ---------------------------------------------------------------------------

# The target /etc/systemd/system/default.target resolves to.
default_target() {
  readlink -f /etc/systemd/system/default.target 2>/dev/null | sed 's|.*/||'
}

# The timeout from the persistent source.
grub_timeout() {
  grep '^GRUB_TIMEOUT=' /etc/default/grub 2>/dev/null | cut -d= -f2
}

# The first `set timeout=` number in the generated menu.
cfg_timeout() {
  grep -m1 -o 'set timeout=[0-9]*' /boot/grub2/grub.cfg 2>/dev/null | cut -d= -f2
}

# The menu_auto_hide flag the bootloader actually reads.
menu_auto_hide() {
  grub2-editenv list 2>/dev/null | sed -n 's/^menu_auto_hide=//p'
}

# The kernel that will boot by default.
default_kernel_version() {
  grubby --default-kernel 2>/dev/null | sed 's|.*/vmlinuz-||'
}

# Every BLS entry's argument line, one per kernel.
entry_args() {
  grubby --info=ALL 2>/dev/null | grep '^args='
}

# all_entries_have <arg> — true when every installed kernel carries it.
all_entries_have() {
  local arg=$1 total have
  total=$(entry_args | wc -l)
  have=$(entry_args | grep -Fc -- "$arg" || true)
  [ "$total" -gt 0 ] && [ "$total" -eq "$have" ]
}

# cmdline_has <arg> — true when the running kernel received it as its own word.
# grep reads the whole (short) input: with `set -o pipefail`, `grep -q` exits
# early and turns tr's SIGPIPE into a pipeline failure.
cmdline_has() {
  tr ' ' '\n' < /proc/cmdline | grep -xF -- "$1" >/dev/null
}

# The version of the newest installed kernel, by install time.
newest_kernel() {
  rpm -q --last kernel-core 2>/dev/null | head -1 | sed 's/^kernel-core-//; s/[[:space:]].*//'
}

# Root's status field from passwd -S is P* when usable, L* when locked.
root_unlocked() {
  local status
  status=$(LC_ALL=C passwd -S root 2>/dev/null | awk '{print $2}')
  case "$status" in
    P*) return 0 ;;
    *)  return 1 ;;
  esac
}

# A freshly recovered account has a real last-change date, not `never`.
root_password_set() {
  local changed
  changed=$(LC_ALL=C passwd -S root 2>/dev/null | awk '{print $3}')
  [ -n "$changed" ] && [ "$changed" != never ]
}

# label_is <path> <type> — true when the live SELinux type matches.
label_is() {
  ls -Z "$1" 2>/dev/null | grep ":$2:" >/dev/null
}

# At least one dnf transaction whose command was an upgrade completed.
upgrade_ok() {
  local id
  for id in $(dnf history list 2>/dev/null |
      awk -F'|' 'NR > 2 && tolower($2) ~ /upgrad|update/ {gsub(/[^0-9]/, "", $1); if ($1 != "") print $1}'); do
    if dnf history info "$id" 2>/dev/null |
        grep -E 'Return-Code[[:space:]]*:[[:space:]]*Success' >/dev/null; then
      return 0
    fi
  done
  return 1
}

# check-update exits 0 when nothing is pending, 100 when updates remain.
no_updates() {
  dnf -q check-update >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Phases
# ---------------------------------------------------------------------------

lab1() {
  section "Lab 1 — targets and the boot menu"

  val_is "the system boots into multi-user.target by default" \
    multi-user.target systemctl get-default
  val_is "the default.target symlink agrees" \
    multi-user.target default_target
  val_is "GRUB_TIMEOUT is 10 seconds in /etc/default/grub" \
    10 grub_timeout
  val_is "the generated menu counts down from 10" \
    10 cfg_timeout
  val_is "the menu is not auto-hidden after a successful boot" \
    0 menu_auto_hide

  if all_entries_have panic=10; then
    pass "every installed kernel carries panic=10"
  else
    fail "every installed kernel carries panic=10"
    printf '        actual: %s\n' "$(entry_args)"
  fi

  has_text "the persistent source carries panic=10" \
    panic=10 grep '^GRUB_CMDLINE_LINUX=' /etc/default/grub
  has_text "a newly installed kernel would inherit panic=10" \
    panic=10 cat /etc/kernel/cmdline

  check "the running kernel received panic=10 (needs a reboot)" \
    cmdline_has panic=10
  val_is "the default boot entry is the kernel that is running" \
    "$(uname -r)" default_kernel_version
}

lab2() {
  section "Lab 2 — root password recovery"

  check "the root account is unlocked" root_unlocked
  check "root's password has a real last-change date" root_password_set
  check "/root/r11-recovered exists" test -f /root/r11-recovered
  check "the marker file is owned by root" \
    test "$(stat -c %U /root/r11-recovered 2>/dev/null)" = root
  check "the marker file carries admin_home_t" \
    label_is /root/r11-recovered admin_home_t
  check "/etc/shadow carries shadow_t" \
    label_is /etc/shadow shadow_t
  check "the relabel marker /.autorelabel is gone" \
    test ! -e /.autorelabel
  val_is "SELinux is still enforcing after the relabel boot" \
    Enforcing getenforce
}

challenge() {
  section "Challenge — update the system, then harden the boot"

  check "a full package update completed successfully" upgrade_ok
  check "dnf finds no updates left to install" no_updates
  val_is "the running kernel is the newest installed kernel" \
    "$(newest_kernel)" uname -r

  if all_entries_have panic_on_warn=1; then
    pass "every installed kernel carries panic_on_warn=1"
  else
    fail "every installed kernel carries panic_on_warn=1"
    printf '        actual: %s\n' "$(entry_args)"
  fi

  check "the running kernel received panic_on_warn=1 (needs a reboot)" \
    cmdline_has panic_on_warn=1
  val_is "the kernel applied panic_on_warn" \
    1 cat /proc/sys/kernel/panic_on_warn

  # The challenge must not undo Lab 1 or Lab 2.
  if all_entries_have panic=10; then
    pass "panic=10 is still on every installed kernel"
  else
    fail "panic=10 is still on every installed kernel"
    printf '        actual: %s\n' "$(entry_args)"
  fi
  check "the running kernel still has panic=10" cmdline_has panic=10
  val_is "the system now boots into multi-user.target by default" \
    multi-user.target systemctl get-default
  val_is "GRUB_TIMEOUT is still 10 seconds" 10 grub_timeout
  check "root is still unlocked" root_unlocked
  check "the recovery marker is still labelled admin_home_t" \
    label_is /root/r11-recovered admin_home_t
  check "the relabel marker is still absent" test ! -e /.autorelabel
}

case "$LAB" in
  lab1)      lab1 ;;
  lab2)      lab2 ;;
  challenge) challenge ;;
  all)       lab1; lab2; challenge ;;
  *)
    printf 'usage: %s [lab1|lab2|challenge|all]\n' "$0" >&2
    exit 2
    ;;
esac

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
