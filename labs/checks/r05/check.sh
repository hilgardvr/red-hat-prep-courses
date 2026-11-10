#!/usr/bin/env bash
#
# R5 checker — run as root inside the server VM:
#   sudo bash check.sh [lab1|lab2|challenge|all]
#
# R5 is about live system state, so this checker asks systemd, journald and
# tuned what they think, and asks the kernel for the real nice value of the
# running process. There is no file tree to redirect, so LAB_ROOT does not
# apply (the R2 and R3 checkers work the same way).
#
# One check is behavioural: the challenge requires a service with
# Restart=always, so the checker kills its main process and waits for
# systemd to bring it back with a new PID.

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
  got=$("$@" 2>/dev/null)
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

# The nice value the kernel reports for the unit's main process.
proc_nice() {
  local unit=$1 pid
  pid=$(systemctl show -p MainPID --value "$unit" 2>/dev/null)
  [ -n "$pid" ] && [ "$pid" != 0 ] || return 1
  ps -o ni= -p "$pid" 2>/dev/null | tr -d ' '
}

unit_field() { systemctl show -p "$1" --value "$2" 2>/dev/null; }

# True when the journal holds a marker written during some earlier boot.
marker_predates_boot() {
  local cur
  cur=$(tr -d '-' < /proc/sys/kernel/random/boot_id)
  journalctl -t r5-journal -o json --no-pager 2>/dev/null |
    grep -o '"_BOOT_ID":"[0-9a-f]*"' |
    cut -d'"' -f4 |
    grep -qv "^$cur$"
}

# ---------------------------------------------------------------------------
# Lab 1 — a service that survives
# ---------------------------------------------------------------------------
run_lab1() {
  section "R5 Lab 1 — A service that survives"

  val_is "unit r5-worker.service is loaded" loaded \
    unit_field LoadState r5-worker

  val_is "r5-worker is enabled at boot" enabled \
    systemctl is-enabled r5-worker

  val_is "r5-worker is active" active \
    systemctl is-active r5-worker

  val_is "the unit sets Nice=10" 10 \
    unit_field Nice r5-worker

  val_is "the running process has nice 10" 10 \
    proc_nice r5-worker

  has_text "ExecStart points at /usr/local/bin/r5-worker" \
    'path=/usr/local/bin/r5-worker' \
    unit_field ExecStart r5-worker

  has_text "the nice drop-in is loaded" 'nice.conf' \
    unit_field DropInPaths r5-worker

  check "the journal shows the worker's output" \
    bash -c 'journalctl -u r5-worker -n 20 --no-pager 2>/dev/null | grep -q "worker heartbeat"'

  val_is "r5-scratch is masked" masked \
    systemctl is-enabled r5-scratch

  if systemctl start r5-scratch >/dev/null 2>&1; then
    fail "the masked unit refuses to start"
  else
    pass "the masked unit refuses to start"
  fi
}

# ---------------------------------------------------------------------------
# Lab 2 — logs that survive, and a tuning profile
# ---------------------------------------------------------------------------
run_lab2() {
  section "R5 Lab 2 — Logs that survive, and a tuning profile"

  check "/var/log/journal exists" test -d /var/log/journal

  check "a journal file is stored under /var/log/journal" \
    bash -c 'find /var/log/journal -name "*.journal" -print -quit 2>/dev/null | grep -q .'

  check "the journal holds entries for this boot" \
    bash -c 'journalctl -b -n 1 --no-pager --quiet 2>/dev/null | grep -q .'

  check "the merged journald configuration caps SystemMaxUse at 100M" \
    bash -c 'systemd-analyze cat-config systemd/journald.conf 2>/dev/null | grep -qx "SystemMaxUse=100M"'

  check "the journal contains the r5-journal marker" \
    bash -c 'journalctl -t r5-journal -n 1 --no-pager --quiet 2>/dev/null | grep -q .'

  if marker_predates_boot; then
    pass "the marker was written before the current boot"
  else
    fail "the marker was written before the current boot"
    printf '        the marker is missing, or it belongs to this boot only\n'
    printf '        (this check needs the reboot step in Lab 2)\n'
  fi

  has_text "tuned's active profile is throughput-performance" \
    'throughput-performance' tuned-adm active
}

# ---------------------------------------------------------------------------
# Challenge — the batch runner
# ---------------------------------------------------------------------------
run_challenge() {
  section "R5 Challenge — The batch runner"

  val_is "unit r5-batch.service is loaded" loaded \
    unit_field LoadState r5-batch

  val_is "r5-batch is enabled at boot" enabled \
    systemctl is-enabled r5-batch

  val_is "r5-batch is active" active \
    systemctl is-active r5-batch

  val_is "the unit sets Nice=5" 5 \
    unit_field Nice r5-batch

  val_is "the running process has nice 5" 5 \
    proc_nice r5-batch

  val_is "the unit sets Restart=always" always \
    unit_field Restart r5-batch

  check "the journal holds r5-batch lines from this boot" \
    bash -c 'journalctl -b -t r5-batch -n 1 --no-pager --quiet 2>/dev/null | grep -q .'

  check "the persistent journal is still in use" \
    bash -c 'find /var/log/journal -name "*.journal" -print -quit 2>/dev/null | grep -q .'

  val_is "r5-worker is still active" active \
    systemctl is-active r5-worker

  # Behavioural, and deliberately last: kill the main process and see whether
  # systemd starts a new one. Restart=always in a unit file is only a promise
  # until it happens.
  local before now i restarted=0
  before=$(unit_field MainPID r5-batch)
  if [ -z "$before" ] || [ "$before" = 0 ]; then
    fail "systemd restarts the service when its main process dies"
    printf '        r5-batch has no main process to kill\n'
  else
    kill -TERM "$before" 2>/dev/null
    for i in $(seq 1 20); do
      sleep 0.5
      now=$(unit_field MainPID r5-batch)
      if [ "$(unit_field ActiveState r5-batch)" = active ] &&
         [ -n "$now" ] && [ "$now" != 0 ] && [ "$now" != "$before" ]; then
        restarted=1
        break
      fi
    done
    if [ "$restarted" -eq 1 ]; then
      pass "systemd restarts the service when its main process dies"
    else
      fail "systemd restarts the service when its main process dies"
      printf '        killed PID %s; the unit is %s with MainPID %s\n' \
        "$before" "$(unit_field ActiveState r5-batch)" "${now:-none}"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
section "RHCSA Field Guide — R5 checker"

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
