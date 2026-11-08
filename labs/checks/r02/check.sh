#!/usr/bin/env bash
#
# R2 checker — run as root inside the server VM:
#   sudo bash check.sh [lab1|lab2|challenge|all]
#
# The checker inspects end state, not the commands used. It gives the same
# answer before and after a reboot, which is how it verifies persistence.
# Set LAB_ROOT to test the directory checks against a different tree
# (the default is /srv).

set -uo pipefail

LAB_ROOT="${LAB_ROOT:-/srv}"
R2="$LAB_ROOT/r2"

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

check() {
  local desc=$1
  shift
  if "$@" >/dev/null 2>&1; then
    pass "$desc"
  else
    fail "$desc"
  fi
}

# ---------------------------------------------------------------------------
# Account predicates
# ---------------------------------------------------------------------------
user_exists() {
  getent passwd "$1" >/dev/null 2>&1
}

not_user() {
  ! getent passwd "$1" >/dev/null 2>&1
}

user_field() {
  getent passwd "$1" 2>/dev/null | cut -d: -f"$2"
}

user_uid_is() {
  local uid
  uid=$(user_field "$1" 3)
  [ -n "$uid" ] && [ "$uid" = "$2" ]
}

user_gid_is() {
  local gid
  gid=$(user_field "$1" 4)
  [ -n "$gid" ] && [ "$gid" = "$2" ]
}

user_shell_is() {
  [ "$(user_field "$1" 7)" = "$2" ]
}

user_home_is() {
  [ "$(user_field "$1" 6)" = "$2" ]
}

user_comment_has() {
  case "$(user_field "$1" 5)" in
    *"$2"*) return 0 ;;
    *) return 1 ;;
  esac
}

is_system_uid() {
  local uid
  uid=$(user_field "$1" 3)
  [ -n "$uid" ] || return 1
  case "$uid" in
    ''|*[!0-9]*) return 1 ;;
  esac
  [ "$uid" -ne 0 ] && [ "$uid" -lt 1000 ]
}

group_gid_is() {
  local gid
  gid=$(getent group "$1" 2>/dev/null | cut -d: -f3)
  [ -n "$gid" ] && [ "$gid" = "$2" ]
}

in_group() {
  id -nG "$1" 2>/dev/null | tr ' ' '\n' | grep -qxF -- "$2"
}

not_in_group() {
  ! in_group "$1" "$2"
}

home_owned_by() {
  [ -d "$1" ] && [ "$(stat -c '%U' "$1" 2>/dev/null)" = "$2" ]
}

# ---------------------------------------------------------------------------
# Password and aging predicates
# ---------------------------------------------------------------------------
passwd_status() {
  LC_ALL=C passwd -S "$1" 2>/dev/null | awk '{print $2}'
}

account_usable() {
  case "$(passwd_status "$1")" in
    P*) return 0 ;;
    *) return 1 ;;
  esac
}

account_locked() {
  case "$(passwd_status "$1")" in
    L*) return 0 ;;
    *) return 1 ;;
  esac
}

has_password_hash() {
  local h
  h=$(getent shadow "$1" 2>/dev/null | cut -d: -f2)
  h=${h#!}
  h=${h#!}
  [ -n "$h" ] && [ "$h" != "*" ]
}

chage_value() {
  LC_ALL=C chage -l "$1" 2>/dev/null |
    awk -F: -v pat="$2" '
      $1 ~ pat { gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }
    '
}

chage_max_is()   { [ "$(chage_value "$1" 'Maximum number of days')" = "$2" ]; }
chage_min_is()   { [ "$(chage_value "$1" 'Minimum number of days')" = "$2" ]; }
chage_warn_is()  { [ "$(chage_value "$1" 'warning before password expires')" = "$2" ]; }
chage_expires_is() { [ "$(chage_value "$1" 'Account expires')" = "$2" ]; }

must_change() {
  LC_ALL=C chage -l "$1" 2>/dev/null | grep -qi 'must be changed'
}

# ---------------------------------------------------------------------------
# sudo and umask predicates
# ---------------------------------------------------------------------------
visudo_file_ok() {
  visudo -cf "$1" >/dev/null 2>&1
}

visudo_all_ok() {
  visudo -c >/dev/null 2>&1
}

sudo_allows() {
  sudo -l -U "$1" 2>/dev/null | grep -qF -- "$2"
}

not_sudo_allows() {
  ! sudo_allows "$1" "$2"
}

login_umask() {
  sudo -H -u "$1" bash -lc 'umask' 2>/dev/null |
    tail -n 1 | tr -d '[:space:]'
}

login_file_mode() {
  sudo -H -u "$1" bash -lc '
    d=$(mktemp -d) || exit 1
    : > "$d/f"
    stat -c %a "$d/f"
    rm -rf "$d"
  ' 2>/dev/null | tail -n 1 | tr -d '[:space:]'
}

login_dir_mode() {
  sudo -H -u "$1" bash -lc '
    d=$(mktemp -d) || exit 1
    mkdir "$d/d"
    stat -c %a "$d/d"
    rm -rf "$d"
  ' 2>/dev/null | tail -n 1 | tr -d '[:space:]'
}

# ---------------------------------------------------------------------------
# File predicates
# ---------------------------------------------------------------------------
mode_is() {
  [ "$(stat -c '%a' "$1" 2>/dev/null)" = "$2" ]
}

owner_is() {
  [ "$(stat -c '%U:%G' "$1" 2>/dev/null)" = "$2" ]
}

contains() {
  [ -f "$1" ] && grep -qF -- "$2" "$1"
}

# ---------------------------------------------------------------------------
# Lab 1
# ---------------------------------------------------------------------------
run_lab1() {
  section "R2 Lab 1 — Accounts and groups"

  check "group developers has GID 3001" group_gid_is developers 3001
  check "group operators has GID 3002" group_gid_is operators 3002

  check "user devon exists" user_exists devon
  check "devon has UID 3001" user_uid_is devon 3001
  check "devon's primary group is developers" user_gid_is devon 3001
  check "devon's shell is /bin/bash" user_shell_is devon /bin/bash
  check "devon's home directory is /home/devon" user_home_is devon /home/devon
  check "devon's comment contains 'Devon'" user_comment_has devon Devon
  check "devon is a member of operators" in_group devon operators
  check "/home/devon exists and belongs to devon" home_owned_by /home/devon devon

  check "user mira exists" user_exists mira
  check "mira's primary group is developers" user_gid_is mira 3001
  check "mira's shell is /bin/bash" user_shell_is mira /bin/bash
  check "mira's comment contains 'Mira'" user_comment_has mira Mira
  check "mira is not a member of operators" not_in_group mira operators

  check "user buildbot exists as a system account" is_system_uid buildbot
  check "buildbot's shell is /sbin/nologin" \
    user_shell_is buildbot /sbin/nologin
  check "buildbot's home directory exists" test -d /var/lib/buildbot
  check "buildbot's home is owned by buildbot" \
    home_owned_by /var/lib/buildbot buildbot

  check "deleted user contractor has no account" not_user contractor
  check "labuser is a member of operators" in_group labuser operators

  check "$R2/team/handover.txt is mode 640" \
    mode_is "$R2/team/handover.txt" 640
  check "$R2/team/handover.txt is owned by devon:developers" \
    owner_is "$R2/team/handover.txt" "devon:developers"
  check "handover.txt kept the contractor's content" \
    contains "$R2/team/handover.txt" "rotate the API keys"

  check "$R2/team/notes.txt is mode 640" mode_is "$R2/team/notes.txt" 640
  check "$R2/team/notes.txt is owned by mira:developers" \
    owner_is "$R2/team/notes.txt" "mira:developers"
  check "notes.txt has the expected content" \
    contains "$R2/team/notes.txt" "ldap migration"
}

# ---------------------------------------------------------------------------
# Lab 2
# ---------------------------------------------------------------------------
run_lab2() {
  section "R2 Lab 2 — Passwords, policy, and sudo"

  check "devon has a usable password" account_usable devon
  check "devon's aging: max 90 days" chage_max_is devon 90
  check "devon's aging: min 7 days" chage_min_is devon 7
  check "devon's aging: warn 14 days" chage_warn_is devon 14

  check "mira has a password set" has_password_hash mira
  check "mira's aging: max 60 days" chage_max_is mira 60
  check "mira's aging: min 5 days" chage_min_is mira 5
  check "mira's aging: warn 10 days" chage_warn_is mira 10
  check "mira's account expires on Dec 31, 2027" \
    chage_expires_is mira "Dec 31, 2027"
  check "mira's account is locked" account_locked mira

  check "user intern exists" user_exists intern
  check "intern's shell is /bin/bash" user_shell_is intern /bin/bash
  check "intern is a member of developers" in_group intern developers
  check "intern's aging: max 30 days" chage_max_is intern 30
  check "intern must change password at next login" must_change intern

  local f=/etc/sudoers.d/10-r2-operators
  check "sudoers drop-in exists: $f" test -f "$f"
  check "sudoers drop-in is mode 0440" mode_is "$f" 440
  check "sudoers drop-in is owned by root:root" owner_is "$f" "root:root"
  check "sudoers drop-in parses" visudo_file_ok "$f"
  check "the whole sudoers configuration parses" visudo_all_ok
  check "devon may run 'systemctl status sshd' with sudo" \
    sudo_allows devon "systemctl status sshd"
  check "mira may not run it" not_sudo_allows mira "systemctl status sshd"

  check "devon's login-shell umask is 0027" \
    [ "$(login_umask devon)" = "0027" ]
  check "devon's login shell creates files 640" \
    [ "$(login_file_mode devon)" = "640" ]
  check "devon's login shell creates directories 750" \
    [ "$(login_dir_mode devon)" = "750" ]

  check "labuser still has sudo through wheel" in_group labuser wheel
}

# ---------------------------------------------------------------------------
# Challenge
# ---------------------------------------------------------------------------
run_challenge() {
  section "R2 Challenge — Onboarding wave 2"

  check "group analytics has GID 3500" group_gid_is analytics 3500

  check "user nora exists" user_exists nora
  check "nora has UID 3501" user_uid_is nora 3501
  check "nora's primary group is analytics" user_gid_is nora 3500
  check "nora's shell is /bin/bash" user_shell_is nora /bin/bash
  check "nora's comment contains 'Nora'" user_comment_has nora Nora
  check "/home/nora exists and belongs to nora" home_owned_by /home/nora nora
  check "nora has a usable password" account_usable nora
  check "nora's aging: max 45 days" chage_max_is nora 45
  check "nora's aging: min 5 days" chage_min_is nora 5
  check "nora's aging: warn 7 days" chage_warn_is nora 7
  check "nora's account expires on Jun 30, 2028" \
    chage_expires_is nora "Jun 30, 2028"

  check "user tomas exists" user_exists tomas
  check "tomas has UID 3502" user_uid_is tomas 3502
  check "tomas's primary group is analytics" user_gid_is tomas 3500
  check "tomas's shell is /bin/bash" user_shell_is tomas /bin/bash
  check "tomas's comment contains 'Tomas'" user_comment_has tomas Tomas
  check "/home/tomas exists and belongs to tomas" \
    home_owned_by /home/tomas tomas
  check "tomas's password is set" has_password_hash tomas
  check "tomas's account is locked" account_locked tomas
  check "tomas's aging: max 45 days" chage_max_is tomas 45
  check "tomas's aging: min 5 days" chage_min_is tomas 5
  check "tomas's aging: warn 7 days" chage_warn_is tomas 7

  check "$R2/analytics exists" test -d "$R2/analytics"
  check "$R2/analytics is owned by root:analytics" \
    owner_is "$R2/analytics" "root:analytics"
  check "$R2/analytics is mode 770" mode_is "$R2/analytics" 770

  check "$R2/analytics/plan.txt is owned by nora:analytics" \
    owner_is "$R2/analytics/plan.txt" "nora:analytics"
  check "$R2/analytics/plan.txt is mode 640" \
    mode_is "$R2/analytics/plan.txt" 640
  check "plan.txt contains 'wave 2'" \
    contains "$R2/analytics/plan.txt" "wave 2"

  local f=/etc/sudoers.d/10-r2-analytics
  check "sudoers drop-in exists: $f" test -f "$f"
  check "sudoers drop-in is mode 0440" mode_is "$f" 440
  check "sudoers drop-in is owned by root:root" owner_is "$f" "root:root"
  check "sudoers drop-in parses" visudo_file_ok "$f"
  check "the whole sudoers configuration parses" visudo_all_ok
  check "nora may run 'systemctl status sshd' with sudo" \
    sudo_allows nora "systemctl status sshd"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
section "RHCSA Field Guide — R2 checker"
printf '  root: %s\n' "$LAB_ROOT"

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
