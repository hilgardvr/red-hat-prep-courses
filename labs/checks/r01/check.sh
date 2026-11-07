#!/usr/bin/env bash
#
# R1 checker — run as root inside the server VM:
#   sudo bash check.sh [lab1|lab2|challenge|all]
#
# The checker inspects the end state, not the commands used. Set LAB_ROOT to
# test against a different tree (the default is /srv).

set -uo pipefail

LAB_ROOT="${LAB_ROOT:-/srv}"
R1="$LAB_ROOT/r1"
HANDOFF="$LAB_ROOT/handoff"

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
# Predicates
# ---------------------------------------------------------------------------
mode_is() {
  [ "$(stat -c '%a' "$1" 2>/dev/null)" = "$2" ]
}

owner_is() {
  [ "$(stat -c '%U:%G' "$1" 2>/dev/null)" = "$2" ]
}

same_inode() {
  local a b
  a=$(stat -c '%i' "$1" 2>/dev/null) || return 1
  b=$(stat -c '%i' "$2" 2>/dev/null) || return 1
  [ -n "$a" ] && [ "$a" = "$b" ]
}

link_count_is() {
  [ "$(stat -c '%h' "$1" 2>/dev/null)" = "$2" ]
}

symlink_to() {
  [ -L "$1" ] && [ "$(readlink "$1" 2>/dev/null)" = "$2" ]
}

contains() {
  [ -f "$1" ] && grep -qF -- "$2" "$1"
}

contains_i() {
  [ -f "$1" ] && grep -qiF -- "$2" "$1"
}

content_is() {
  [ -f "$1" ] || return 1
  [ "$(tr -d '[:space:]' < "$1")" = "$2" ]
}

line_count_is() {
  [ -f "$1" ] || return 1
  local n
  n=$(wc -l < "$1")
  n=${n//[[:space:]]/}
  [ "$n" = "$2" ]
}

all_lines_match() {
  [ -s "$1" ] || return 1
  ! grep -q -v -E "$2" "$1"
}

ips_match() {
  [ -f "$1" ] || return 1
  local expected=$'10.0.0.5\n172.16.0.9\n192.168.1.20'
  [ "$(cat "$1")" = "$expected" ]
}

archive_contains() {
  local archive=$1
  local flag=$2
  local member=$3
  [ -f "$archive" ] || return 1
  tar "$flag" "$archive" 2>/dev/null | grep -qxF "$member"
}

sha_matches() {
  local file=$1
  local shafile=$2
  [ -f "$file" ] && [ -f "$shafile" ] || return 1
  local expected actual
  expected=$(tr -d '[:space:]' < "$shafile")
  actual=$(sha256sum "$file" | awk '{print $1}')
  [ -n "$expected" ] && [ "$expected" = "$actual" ]
}

remote_ssh() {
  sudo -H -u labuser ssh \
    -i /home/labuser/.ssh/lab_ed25519 \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=5 \
    labuser@node2 "$@" 2>/dev/null
}

remote_ok() {
  remote_ssh "$@" >/dev/null 2>&1
}

remote_sha_matches() {
  local file=$1
  local shafile=$2
  [ -f "$file" ] && [ -f "$shafile" ] || return 1
  local expected remote
  expected=$(tr -d '[:space:]' < "$shafile")
  remote=$(remote_ssh 'sha256sum /home/labuser/handoff/handoff.tar.gz' | awk '{print $1}')
  [ -n "$remote" ] && [ "$remote" = "$expected" ]
}

# ---------------------------------------------------------------------------
# Lab 1
# ---------------------------------------------------------------------------
run_lab1() {
  section "R1 Lab 1 — Files and links"

  check "$R1 exists" test -d "$R1"
  check "$R1 is owned by labuser:labuser" owner_is "$R1" "labuser:labuser"

  check "directory: $R1/project/docs" test -d "$R1/project/docs"
  check "directory: $R1/project/src/nested/deep" test -d "$R1/project/src/nested/deep"
  check "directory: $R1/project/archive" test -d "$R1/project/archive"

  check "file: $R1/project/docs/readme.txt" test -f "$R1/project/docs/readme.txt"
  check "file: $R1/project/docs/notes.txt" test -f "$R1/project/docs/notes.txt"
  check "file: $R1/project/archive/old.txt" test -f "$R1/project/archive/old.txt"
  check "removed: $R1/project/docs/delete-me.txt" test ! -e "$R1/project/docs/delete-me.txt"

  check "hard link exists: $R1/project/archive/readme-hardlink.txt" \
    test -f "$R1/project/archive/readme-hardlink.txt"
  check "hard link shares an inode with docs/readme.txt" \
    same_inode "$R1/project/archive/readme-hardlink.txt" "$R1/project/docs/readme.txt"
  check "hard link count is 2 for docs/readme.txt" \
    link_count_is "$R1/project/docs/readme.txt" 2
  check "symlink readme-softlink -> docs/readme.txt" \
    symlink_to "$R1/project/readme-softlink" "docs/readme.txt"

  check "readme.txt contains the lab marker" \
    contains "$R1/project/docs/readme.txt" "RHCSA lab 1"
  check "notes.txt contains the copied content" \
    contains "$R1/project/docs/notes.txt" "RHCSA lab 1"
  check "notes.txt contains the appended line" \
    contains "$R1/project/docs/notes.txt" "second line"
  check "notes.txt was edited in an editor" \
    contains "$R1/project/docs/notes.txt" "edited in vim"
  check "old.txt was moved, not copied" \
    contains "$R1/project/archive/old.txt" "old file"
}

# ---------------------------------------------------------------------------
# Lab 2
# ---------------------------------------------------------------------------
run_lab2() {
  section "R1 Lab 2 — Streams and permissions"
  local streams="$R1/streams"

  check "sample.log exists" test -f "$streams/sample.log"
  check "sample.log has 10 lines" line_count_is "$streams/sample.log" 10

  check "errors.txt contains only ERROR lines" \
    all_lines_match "$streams/errors.txt" "ERROR"
  check "errors.txt has 4 lines" line_count_is "$streams/errors.txt" 4
  check "error-count.txt is 4" content_is "$streams/error-count.txt" "4"
  check "ips.txt contains the three unique addresses" \
    ips_match "$streams/ips.txt"

  check "stdout.txt contains /etc/hosts" \
    contains "$streams/stdout.txt" "/etc/hosts"
  check "stderr.txt contains the missing-file error" \
    contains "$streams/stderr.txt" "No such file or directory"
  check "combined.txt contains stdout" \
    contains "$streams/combined.txt" "/etc/hosts"
  check "combined.txt contains stderr" \
    contains "$streams/combined.txt" "No such file or directory"

  check "secure directory is mode 755" mode_is "$R1/secure" 755
  check "report.txt is mode 640" mode_is "$R1/secure/report.txt" 640
  check "report.txt is owned by labuser:labuser" \
    owner_is "$R1/secure/report.txt" "labuser:labuser"
  check "report.txt contains the report text" \
    contains "$R1/secure/report.txt" "quarterly report"

  check "run.sh is executable" test -x "$R1/secure/run.sh"
  check "run.sh is mode 750" mode_is "$R1/secure/run.sh" 750
  check "run.sh is owned by labuser:labuser" \
    owner_is "$R1/secure/run.sh" "labuser:labuser"

  check "shared directory is mode 770" mode_is "$R1/shared" 770
  check "notice.txt is mode 644" mode_is "$R1/public/notice.txt" 644
  check "private.txt is mode 640" mode_is "$R1/secure/private.txt" 640
  check "umask.txt records 0027" content_is "$R1/secure/umask.txt" "0027"
}

# ---------------------------------------------------------------------------
# Challenge
# ---------------------------------------------------------------------------
run_challenge() {
  section "R1 Challenge — Handoff bundle"

  check "$HANDOFF exists" test -d "$HANDOFF"
  check "$HANDOFF is owned by root:wheel" owner_is "$HANDOFF" "root:wheel"
  check "$HANDOFF is mode 770" mode_is "$HANDOFF" 770

  check "release directory is mode 750" mode_is "$HANDOFF/release" 750

  check "report.sh exists" test -f "$HANDOFF/release/report.sh"
  check "report.sh is executable" test -x "$HANDOFF/release/report.sh"
  check "report.sh is mode 750" mode_is "$HANDOFF/release/report.sh" 750
  check "report.sh has a bash shebang" \
    contains "$HANDOFF/release/report.sh" "#!/usr/bin/env bash"
  check "report.sh prints the hostname" \
    contains_i "$HANDOFF/release/report.sh" "hostname"
  check "report.sh prints the date" \
    contains_i "$HANDOFF/release/report.sh" "date"
  check "report.sh prints the kernel" \
    contains_i "$HANDOFF/release/report.sh" "uname"

  check "readme.txt is mode 640" mode_is "$HANDOFF/release/readme.txt" 640
  check "readme.txt contains the marker" \
    contains "$HANDOFF/release/readme.txt" "RHCSA handoff"

  check "ips.txt has three lines" line_count_is "$HANDOFF/release/ips.txt" 3
  check "ips.txt contains the three unique addresses" \
    ips_match "$HANDOFF/release/ips.txt"

  check "tar-help.txt is non-empty" test -s "$HANDOFF/release/tar-help.txt"
  check "tar-help.txt mentions tar" \
    contains_i "$HANDOFF/release/tar-help.txt" "tar"

  check "handoff.tar.gz exists" test -f "$HANDOFF/handoff.tar.gz"
  check "handoff.tar.gz contains release/report.sh" \
    archive_contains "$HANDOFF/handoff.tar.gz" "-tzf" "release/report.sh"
  check "handoff.tar.gz contains release/readme.txt" \
    archive_contains "$HANDOFF/handoff.tar.gz" "-tzf" "release/readme.txt"

  check "handoff.tar.bz2 exists" test -f "$HANDOFF/handoff.tar.bz2"
  check "handoff.tar.bz2 contains release/report.sh" \
    archive_contains "$HANDOFF/handoff.tar.bz2" "-tjf" "release/report.sh"

  check "checksum file matches handoff.tar.gz" \
    sha_matches "$HANDOFF/handoff.tar.gz" "$HANDOFF/handoff.tar.gz.sha256"

  check "whoami.txt contains labuser" content_is "$HANDOFF/whoami.txt" "labuser"
  check "root-id.txt contains 0" content_is "$HANDOFF/root-id.txt" "0"

  check "node2 has the archive" \
    remote_ok 'test -f /home/labuser/handoff/handoff.tar.gz'
  check "node2 copy matches the checksum" \
    remote_sha_matches "$HANDOFF/handoff.tar.gz" "$HANDOFF/handoff.tar.gz.sha256"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
section "RHCSA Field Guide — R1 checker"
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
