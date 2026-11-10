#!/usr/bin/env bash
#
# R4 checker — run as root inside the server VM:
#   sudo bash check.sh [lab1|lab2|challenge|all]
#
# R4 is about behaviour, so this checker does not look for particular
# commands. It builds its own fixtures — its own paths, its own line counts,
# its own passwd file — runs the learner's scripts against them, and compares
# output and exit status. A script that hardcodes the values from the lab
# fails here.
#
# The scripts are looked up under LAB_ROOT (default /srv), so the whole
# checker can be exercised against a synthetic tree outside a VM.

set -uo pipefail

LAB_ROOT="${LAB_ROOT:-/srv}"
BIN="$LAB_ROOT/r4/bin"

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

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

OUT=''
ERR=''
RC=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# run <script> [args...] — capture stdout, stderr, and the exit status.
run() {
  local script=$1
  shift
  if [ ! -x "$script" ]; then
    OUT=''
    ERR="not an executable file: $script"
    RC=127
    return
  fi
  OUT=$("$script" "$@" 2>"$WORK/stderr")
  RC=$?
  ERR=$(cat "$WORK/stderr")
}

# check_run <description> <expected exit> <expected stdout> -- <script> [args...]
check_run() {
  local desc=$1 want_rc=$2 want_out=$3
  shift 3
  [ "${1:-}" = "--" ] && shift
  run "$@"
  if [ "$RC" -eq "$want_rc" ] && [ "$OUT" = "$want_out" ]; then
    pass "$desc"
  else
    fail "$desc"
    printf '        expected exit %s, output: %q\n' "$want_rc" "$want_out"
    printf '        actual   exit %s, output: %q\n' "$RC" "$OUT"
    if [ -n "$ERR" ]; then
      printf '        stderr: %q\n' "$ERR"
    fi
  fi
}

rc_is() { [ "$RC" -eq "$1" ]; }

stderr_has() {
  case "$ERR" in
    *"$1"*) return 0 ;;
    *) return 1 ;;
  esac
}

# All output lines except the last, sorted, for report comparisons.
body_lines_sorted() {
  printf '%s\n' "$OUT" | sed '$d' | sed '/^$/d' | LC_ALL=C sort
}

check_body() {   # check_body <description> <expected sorted lines>
  local desc=$1 want=$2 got
  got=$(body_lines_sorted)
  if [ "$got" = "$want" ]; then
    pass "$desc"
  else
    fail "$desc"
    printf '        expected: %q\n' "$want"
    printf '        actual:   %q\n' "$got"
  fi
}

out_has_line()  { printf '%s\n' "$OUT" | grep -qxF -- "$1"; }
# Negation checks must not pass just because the script printed nothing:
# a missing script produces empty output and would "skip" everything.
out_lacks_line() { [ -n "$OUT" ] && ! printf '%s\n' "$OUT" | grep -qxF -- "$1"; }
out_body_is()   { [ "$(printf '%s\n' "$OUT" | sed '$d')" = "$1" ]; }
last_line_is()  { printf '%s\n' "$OUT" | tail -n 1 | grep -qxF -- "$1"; }
out_lacks_word() { [ -n "$OUT" ] && ! printf '%s\n' "$OUT" | grep -qwF -- "$1"; }

has_bash_shebang() {
  head -n 1 "$1" 2>/dev/null | grep -q '^#!.*bash'
}

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

mk_classify_dir() {
  local d="$WORK/classify"
  mkdir -p "$d/sub"
  printf 'plain\n' > "$d/plain.txt"
  printf 'spaced\n' > "$d/with space.txt"
  ln -s plain.txt "$d/goodlink"
  ln -s nowhere "$d/deadlink"
  printf '%s' "$d"
}

mk_report_dir() {
  local d="$WORK/report"
  mkdir -p "$d/sub"
  printf 'a\nb\nc\n' > "$d/a.log"
  printf '1\n2\n3\n4\n5\n' > "$d/b.log"
  printf 'x\ny\n' > "$d/c.log"
  : > "$d/empty.log"
  ln -s gone.log "$d/oldest"
  printf 'ignored\n' > "$d/sub/inside.log"
  printf '%s' "$d"
}

mk_accounts_file() {
  local d="$WORK/accounts"
  mkdir -p "$d/alpha/archive" "$d/beta"
  printf 'x\n' > "$d/alpha/a.txt"
  printf 'y\n' > "$d/alpha/b.txt"
  printf 'z\n' > "$d/alpha/archive/old.txt"
  printf 'not a directory\n' > "$d/notadir"
  {
    printf '# captured from a build machine\n'
    printf 'alpha:x:3001:3001::%s/alpha:/bin/bash\n' "$d"
    printf 'beta:x:3002:3002::%s/beta:/bin/sh\n' "$d"
    printf '\n'
    printf 'gamma:x:3003:3003::%s/ghost:/sbin/nologin\n' "$d"
    printf 'delta:x:3004:3004::%s/notadir:/bin/bash\n' "$d"
  } > "$d/passwd"
  printf '%s' "$d/passwd"
}

mk_accounts_ok_file() {
  local d="$WORK/accounts-ok"
  mkdir -p "$d/one" "$d/two/sub"
  printf 'x\n' > "$d/two/file"
  {
    printf 'one:x:4001:4001::%s/one:/bin/bash\n' "$d"
    printf 'two:x:4002:4002::%s/two:/bin/bash\n' "$d"
  } > "$d/passwd"
  printf '%s' "$d/passwd"
}

# ---------------------------------------------------------------------------
# Lab 1 — arguments, tests, exit codes
# ---------------------------------------------------------------------------
run_lab1() {
  section "R4 Lab 1 — Arguments, tests, and exit codes"

  local s="$BIN/classify"
  check "script exists: $s" test -f "$s"
  check "the script is executable" test -x "$s"
  check "the script parses: bash -n" bash -n "$s"
  check "the script starts with a bash shebang" has_bash_shebang "$s"

  local d
  d=$(mk_classify_dir)

  run "$s"
  check "no arguments exits 2" rc_is 2
  check "the usage message goes to stderr" stderr_has usage

  check_run "a regular file is reported as file" 0 \
    "file $d/plain.txt" -- "$s" "$d/plain.txt"
  check_run "a directory is reported as dir" 0 \
    "dir $d/sub" -- "$s" "$d/sub"
  check_run "a symlink to a file is reported as link" 0 \
    "link $d/goodlink" -- "$s" "$d/goodlink"
  check_run "a broken symlink is reported as link" 0 \
    "link $d/deadlink" -- "$s" "$d/deadlink"
  check_run "a missing path is reported as missing, exit 1" 1 \
    "missing $d/nope" -- "$s" "$d/nope"
  check_run "several paths are reported in argument order" 1 \
    "$(printf 'file %s\ndir %s\nmissing %s' "$d/plain.txt" "$d/sub" "$d/nope")" \
    -- "$s" "$d/plain.txt" "$d/sub" "$d/nope"
  check_run "a filename containing a space is still one path" 0 \
    "file $d/with space.txt" -- "$s" "$d/with space.txt"
  check_run "a run where every path exists exits 0" 0 \
    "$(printf 'file %s\ndir %s' "$d/plain.txt" "$d/sub")" \
    -- "$s" "$d/plain.txt" "$d/sub"
}

# ---------------------------------------------------------------------------
# Lab 2 — loops and command substitution
# ---------------------------------------------------------------------------
run_lab2() {
  section "R4 Lab 2 — Loops and command substitution"

  local s="$BIN/linereport"
  check "script exists: $s" test -f "$s"
  check "the script is executable" test -x "$s"
  check "the script parses: bash -n" bash -n "$s"
  check "the script starts with a bash shebang" has_bash_shebang "$s"

  local d
  d=$(mk_report_dir)

  run "$s"
  check "no arguments exits 2" rc_is 2
  check "the usage message goes to stderr" stderr_has usage
  check_run "a file argument is rejected with exit 2" 2 "" -- "$s" "$d/a.log"

  run "$s" "$d"
  check_body "one line per regular file with its line count" \
    "$(printf 'a.log 3\nb.log 5\nc.log 2\nempty.log 0' | LC_ALL=C sort)"
  check "a file with no lines counts as 0" out_has_line "empty.log 0"
  check "the total line adds the counts" last_line_is "total 10"
  check "a subdirectory is skipped" out_lacks_word sub
  check "a broken symlink is skipped" out_lacks_word oldest

  mkdir -p "$WORK/empty"
  check_run "an empty directory reports total 0" 0 "total 0" -- "$s" "$WORK/empty"
}

# ---------------------------------------------------------------------------
# Challenge — the account audit
# ---------------------------------------------------------------------------
run_challenge() {
  section "R4 Challenge — The account audit"

  local s="$BIN/accounts"
  check "script exists: $s" test -f "$s"
  check "the script is executable" test -x "$s"
  check "the script parses: bash -n" bash -n "$s"
  check "the script starts with a bash shebang" has_bash_shebang "$s"

  run "$s"
  check "no arguments exits 2" rc_is 2
  check "the usage message goes to stderr" stderr_has usage

  local f
  f=$(mk_accounts_file)
  check_run "a missing file is rejected with exit 2" 2 "" -- "$s" "$WORK/does-not-exist"

  local d="$WORK/accounts" want
  want=$(printf 'alpha %s/alpha ok 2\nbeta %s/beta ok 0\ngamma %s/ghost missing\ndelta %s/notadir missing' \
    "$d" "$d" "$d" "$d")

  run "$s" "$f"
  check "one line per account, in file order" out_body_is "$want"
  check "comments and blank lines are ignored" out_lacks_word captured
  check "the summary line reports both counts" last_line_is "ok=2 missing=2"
  check "subdirectories are not counted" out_lacks_line "alpha $d/alpha ok 3"
  check "exits 1 when an account is missing" rc_is 1

  local okf
  okf=$(mk_accounts_ok_file)
  local okd="$WORK/accounts-ok"
  check_run "a file with no missing accounts exits 0" 0 \
    "$(printf 'one %s/one ok 0\ntwo %s/two ok 1\nok=2 missing=0' "$okd" "$okd")" \
    -- "$s" "$okf"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
section "RHCSA Field Guide — R4 checker"
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
