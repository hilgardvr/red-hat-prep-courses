#!/usr/bin/env bash
#
# R8 checker — run as root inside the server VM:
#   sudo bash check.sh [lab1|lab2|challenge|all]
#
# R8 is about time: cron, at, systemd timers, and chrony. Almost everything it
# checks is live state — service enablement, effective timer properties, the
# files a job produced, and the time source a client selected. The chrony
# client half lives on node2, so it is inspected over SSH as labuser, like R7.
#
# A schedule is a promise about the future, and the only honest proof that a
# scheduler works is output it produced. Every phase therefore checks the
# artefacts (logs, stamps, reports), not just the configuration.

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

# line_is <description> <expected> <command...> — compare one line, keeping
# internal spaces. val_is strips whitespace and is for single-word values.
line_is() {
  local desc=$1 want=$2 got
  shift 2
  got=$("$@" 2>/dev/null | head -n 1)
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

# nonempty <description> <command...> — pass when stdout is not blank.
nonempty() {
  local desc=$1 got
  shift
  got=$("$@" 2>/dev/null)
  if [ -n "$(printf '%s' "$got" | tr -d '[:space:]')" ]; then
    pass "$desc"
  else
    fail "$desc"
    printf '        expected some output, got nothing\n'
  fi
}

# lines_at_least <description> <minimum> <file>
lines_at_least() {
  local desc=$1 want=$2 file=$3 got
  got=$(wc -l < "$file" 2>/dev/null | tr -d '[:space:]')
  case "$got" in
    ''|*[!0-9]*) got=0 ;;
  esac
  if [ "$got" -ge "$want" ]; then
    pass "$desc"
  else
    fail "$desc"
    printf '        expected at least %s lines in %s, got %s\n' "$want" "$file" "$got"
  fi
}

# count_is <description> <expected> <directory> <glob>
count_is() {
  local desc=$1 want=$2 dir=$3 pat=$4 got
  got=$(find "$dir" -maxdepth 1 -name "$pat" 2>/dev/null | wc -l | tr -d '[:space:]')
  if [ "$got" = "$want" ]; then
    pass "$desc"
  else
    fail "$desc"
    printf '        expected %s file(s) matching %s in %s, got %s\n' "$want" "$pat" "$dir" "$got"
  fi
}

# ---------------------------------------------------------------------------
# Predicates
# ---------------------------------------------------------------------------

# Run a command on node2 as labuser, through the shared lab key.
n2() { runuser -u labuser -- ssh -o BatchMode=yes -o ConnectTimeout=8 node2 "$*" 2>/dev/null; }

# The source chrony has selected on node2, if any.
n2_source() {
  n2 "chronyc -n sources" | awk '$1 ~ /^\^\*/ {print $2; exit}'
}

n2_synced() { n2 "timedatectl show -p NTPSynchronized --value"; }

# Wait up to 60 s for node2 to report a synchronised clock, then report it.
check_n2_sync() {
  local desc=$1 i got=''
  for i in $(seq 1 30); do
    got=$(n2_synced)
    if [ "$got" = "yes" ]; then
      pass "$desc"
      return
    fi
    sleep 2
  done
  fail "$desc"
  printf '        node2 reported NTPSynchronized=%q after 60 s\n' "$got"
}

# The first real line of a cron file, whitespace collapsed. Comments and blank
# lines are skipped, so a learner may annotate the file freely.
cron_line() {
  awk '!/^[[:space:]]*#/ && NF {print; exit}' "$1" 2>/dev/null | awk '{$1=$1; print}'
}

# ExecStart of a unit as one string, for a substring test.
unit_exec() { systemctl show -p ExecStart --value "$1" 2>/dev/null; }

is_empty() { [ -z "$("$@" 2>/dev/null | tr -d '[:space:]')" ]; }

# ---------------------------------------------------------------------------
# Lab 1 — cron and at
# ---------------------------------------------------------------------------
run_lab1() {
  section "R8 Lab 1 — Repeating jobs with cron and one-off jobs with at"

  val_is "crond is enabled at boot" enabled systemctl is-enabled crond
  val_is "crond is running" active systemctl is-active crond

  # A system job in /etc/cron.d carries a user field; a user crontab does not.
  line_is "the system cron job has the documented schedule and user" \
    "* * * * * root /srv/r8/bin/heartbeat.sh" cron_line /etc/cron.d/r8-heartbeat

  check "the heartbeat script is executable" test -x /srv/r8/bin/heartbeat.sh

  # The log is the proof cron actually ran the job.
  check "the system cron job has written its log" test -s /var/log/r8-heartbeat.log
  has_text "the last log line is a heartbeat" "heartbeat" \
    bash -c 'tail -n 1 /var/log/r8-heartbeat.log'

  has_text "labuser has a personal crontab job" "/srv/r8/bin/userbeat.sh" \
    crontab -l -u labuser

  check "the personal cron job has written its log" test -s /srv/r8/home/userbeat.log

  val_is "atd is enabled at boot" enabled systemctl is-enabled atd
  val_is "atd is running" active systemctl is-active atd

  check "the one-off at job produced its file" test -s /srv/r8/at/once.txt
  has_text "the at job recorded that it ran" "ran once" \
    bash -c 'cat /srv/r8/at/once.txt'

  # After the job fires, the queue must be empty again.
  check "the at queue is empty once the job has run" is_empty atq
}

# ---------------------------------------------------------------------------
# Lab 2 — systemd timer, chrony, timezone
# ---------------------------------------------------------------------------
run_lab2() {
  section "R8 Lab 2 — A systemd timer, an internal time server, and a timezone"

  val_is "r8-timer.timer is enabled at boot" enabled systemctl is-enabled r8-timer.timer
  val_is "r8-timer.timer is active" active systemctl is-active r8-timer.timer
  val_is "the timer catches up after downtime" "yes" \
    systemctl show -p Persistent --value r8-timer.timer
  nonempty "the timer has a calendar schedule" \
    systemctl show -p TimersCalendar --value r8-timer.timer

  has_text "the timer's service runs the worker" "/usr/local/bin/r8-timer.sh" \
    unit_exec r8-timer.service

  # One manual run plus at least one scheduled run.
  lines_at_least "the worker has run at least twice (manual and scheduled)" 2 \
    /srv/r8/timer/last-run

  val_is "chronyd is enabled at boot" enabled systemctl is-enabled chronyd
  val_is "chronyd is running" active systemctl is-active chronyd
  has_text "the server allows the lab network to query it" "allow 10.10.10.0/24" \
    bash -c 'grep "^allow" /etc/chrony.conf'

  val_is "the server timezone is Europe/Berlin" "Europe/Berlin" \
    timedatectl show -p Timezone --value

  # The client half: node2 must actually be using server as its time source.
  val_is "node2 selects the lab server as its time source" "10.10.10.10" n2_source
  check_n2_sync "node2 reports a synchronised clock"
}

# ---------------------------------------------------------------------------
# Challenge — an unattended maintenance routine
# ---------------------------------------------------------------------------
run_challenge() {
  section "R8 Challenge — An unattended maintenance routine"

  check "the report script is executable" test -x /usr/local/sbin/r8-report

  val_is "r8-report.timer is enabled at boot" enabled systemctl is-enabled r8-report.timer
  val_is "r8-report.timer is active" active systemctl is-active r8-report.timer
  val_is "the report timer survives downtime" "yes" \
    systemctl show -p Persistent --value r8-report.timer
  has_text "the report timer fires on the hour" ":00:00" \
    bash -c 'systemctl show -p TimersCalendar --value r8-report.timer'
  has_text "the report service runs the report script" "/usr/local/sbin/r8-report" \
    unit_exec r8-report.service

  # Behaviour: four runs must leave the three newest reports and no more.
  local i
  for i in 1 2 3 4; do
    systemctl start r8-report.service >/dev/null 2>&1
  done
  count_is "the reports directory keeps exactly the three newest" 3 \
    /srv/r8/reports 'report-*.txt'

  has_text "a report records the hostname" "host: $(hostname)" \
    bash -c 'cat "$(ls -1t /srv/r8/reports/report-*.txt | head -1)"'
  has_text "a report records disk usage" "disk: " \
    bash -c 'cat "$(ls -1t /srv/r8/reports/report-*.txt | head -1)"'

  # The weekly archive is a cron job: assert the schedule, then the behaviour.
  line_is "the archive cron job runs weekly as root" \
    "30 3 * * 0 root /usr/local/sbin/r8-archive" cron_line /etc/cron.d/r8-archive

  check "the archive script is executable" test -x /usr/local/sbin/r8-archive

  rm -f /srv/r8/archive/reports-19700101.tar.gz
  touch -d '30 days ago' /srv/r8/archive/reports-19700101.tar.gz
  /usr/local/sbin/r8-archive >/dev/null 2>&1

  check_fails "archives older than four weeks are pruned" \
    test -e /srv/r8/archive/reports-19700101.tar.gz
  check "the archive job writes a tarball" \
    bash -c 'ls /srv/r8/archive/reports-*.tar.gz >/dev/null 2>&1'
  has_text "the tarball contains the reports directory" "reports/" \
    bash -c 'tar -tzf "$(ls -1t /srv/r8/archive/reports-*.tar.gz | head -1)"'

  # Regressions: the challenge must not sacrifice the two labs.
  check "the cron heartbeat log is still present" test -s /var/log/r8-heartbeat.log
  val_is "r8-timer.timer is still active" active systemctl is-active r8-timer.timer
  val_is "the server timezone is still Europe/Berlin" "Europe/Berlin" \
    timedatectl show -p Timezone --value
  val_is "node2 still selects the lab server as its time source" "10.10.10.10" n2_source
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
section "RHCSA Field Guide — R8 checker"

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
