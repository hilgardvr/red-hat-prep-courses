#!/usr/bin/env bash
#
# R3 checker — run as root inside the server VM:
#   sudo bash check.sh [lab1|lab2|challenge|all]
#
# The checker inspects end state, not the commands used. It gives the same
# answer before and after a reboot, which is how it verifies persistence.
# Set LAB_ROOT to test the directory checks against a different tree
# (the default is /srv).
#
# Every dnf query here is pinned with --disablerepo='*' and an explicit
# --enablerepo, so the checker never contacts a mirror and never depends on
# the repositories the learner left enabled.

set -uo pipefail

LAB_ROOT="${LAB_ROOT:-/srv}"
REPO="$LAB_ROOT/r3/repo"
EXTRA="$LAB_ROOT/r3/extra"
REPO_DIR=/etc/yum.repos.d

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
# Repository predicates
# ---------------------------------------------------------------------------
has_rpm() {
  find "$1" -maxdepth 1 -name '*.rpm' -print -quit 2>/dev/null | grep -q .
}

# dnf config-manager --dump prints "key = value" pairs for one repo. It reads
# the configuration only, so it works with every repository disabled.
repo_setting() {
  dnf config-manager --dump "$1" 2>/dev/null |
    awk -F' = ' -v key="$2" '$1 == key { print $2; exit }'
}

repo_enabled_is() {
  [ "$(repo_setting "$1" enabled)" = "$2" ]
}

repo_baseurl_is() {
  local url
  url=$(repo_setting "$1" baseurl)
  url=${url%/}
  [ -n "$url" ] && [ "$url" = "$2" ]
}

repo_gpgcheck_is() {
  [ "$(repo_setting "$1" gpgcheck)" = "$2" ]
}

# Ask the repository's own metadata whether it can supply a package.
repo_serves() {
  dnf --disablerepo='*' --enablerepo="$1" -q repoquery "$2" >/dev/null 2>&1
}

pkg_installed() {
  rpm -q "$1" >/dev/null 2>&1
}

# The rpm database records where an installed package came from; dnf prints
# that as @repo in the repository column.
pkg_from_repo() {
  dnf --disablerepo='*' list --installed "$1" 2>/dev/null | grep -q "@$2"
}

# ---------------------------------------------------------------------------
# Flatpak predicates
# ---------------------------------------------------------------------------
flatpak_bin() {
  command -v flatpak >/dev/null 2>&1
}

flatpak_remote_named() {
  flatpak remotes --columns=name 2>/dev/null | grep -qxF -- "$1"
}

flatpak_remote_scope() {
  flatpak remotes --columns=name,options 2>/dev/null |
    awk -v n="$1" '$1 == n { print $2 }' | grep -qxF -- "$2"
}

flatpak_remote_url_has() {
  flatpak remotes --columns=name,url 2>/dev/null |
    awk -v n="$1" '$1 == n { print $2 }' | grep -qF -- "$2"
}

no_flatpak_apps() {
  flatpak_bin || return 1
  [ -z "$(flatpak list --app --columns=application 2>/dev/null)" ]
}

no_flatpak_runtimes() {
  flatpak_bin || return 1
  [ -z "$(flatpak list --runtime --columns=application 2>/dev/null)" ]
}

# ---------------------------------------------------------------------------
# Lab 1
# ---------------------------------------------------------------------------
run_lab1() {
  section "R3 Lab 1 — RPM repositories and packages"

  check "repository directory exists: $REPO" test -d "$REPO"
  check "the repository contains at least one RPM" has_rpm "$REPO"
  check "repository metadata exists: $REPO/repodata/repomd.xml" \
    test -f "$REPO/repodata/repomd.xml"

  local f="$REPO_DIR/r3-local.repo"
  check "repo file exists: $f" test -f "$f"
  check "r3-local is enabled" repo_enabled_is r3-local 1
  check "r3-local baseurl is file://$REPO" repo_baseurl_is r3-local "file://$REPO"
  check "r3-local has gpgcheck=0" repo_gpgcheck_is r3-local 0

  check "package zsh is installed" pkg_installed zsh
  check "zsh is recorded as coming from r3-local" pkg_from_repo zsh r3-local
  check "the repository still serves zsh" repo_serves r3-local zsh
}

# ---------------------------------------------------------------------------
# Lab 2
# ---------------------------------------------------------------------------
run_lab2() {
  section "R3 Lab 2 — Flatpak remotes and applications"

  check "package flatpak is installed" pkg_installed flatpak
  check "the flathub remote is configured" flatpak_remote_named flathub
  check "flathub is the system-wide installation" \
    flatpak_remote_scope flathub system
  check "flathub points at dl.flathub.org" \
    flatpak_remote_url_has flathub dl.flathub.org
  check "no Flatpak application is installed" no_flatpak_apps
  check "no Flatpak runtime is installed" no_flatpak_runtimes
}

# ---------------------------------------------------------------------------
# Challenge
# ---------------------------------------------------------------------------
run_challenge() {
  section "R3 Challenge — The offline build server"

  check "repository directory exists: $EXTRA" test -d "$EXTRA"
  check "the repository contains at least one RPM" has_rpm "$EXTRA"
  check "repository metadata exists: $EXTRA/repodata/repomd.xml" \
    test -f "$EXTRA/repodata/repomd.xml"

  local f="$REPO_DIR/r3-extra.repo"
  check "repo file exists: $f" test -f "$f"
  check "r3-extra is enabled" repo_enabled_is r3-extra 1
  check "r3-extra baseurl is file://$EXTRA" \
    repo_baseurl_is r3-extra "file://$EXTRA"
  check "r3-extra has gpgcheck=0" repo_gpgcheck_is r3-extra 0

  check "the repository still serves tree" repo_serves r3-extra tree
  check "package tree is installed" pkg_installed tree
  check "tree is recorded as coming from r3-extra" pkg_from_repo tree r3-extra

  check "distro repo baseos is disabled" repo_enabled_is baseos 0
  check "distro repo appstream is disabled" repo_enabled_is appstream 0
  check "distro repo extras is disabled" repo_enabled_is extras 0
  check "distro repo crb is disabled" repo_enabled_is crb 0

  check "the flathub remote is configured" flatpak_remote_named flathub
  check "no Flatpak application is installed" no_flatpak_apps
  check "no Flatpak runtime is installed" no_flatpak_runtimes
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
section "RHCSA Field Guide — R3 checker"
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
