#!/usr/bin/env bash
#
# R10 checker — run as root inside the server VM:
#   sudo bash check.sh [lab1|lab2|challenge|all]
#
# R10 is about three layers of hardening, and the checker treats each one
# in the way that actually proves it.
#
#   - SELinux is about labels. The checker asks for the live label of the
#     files, the persistent mapping behind it, the port label, and the
#     boolean, then fetches the page so a label that looks right but does
#     not work still fails.
#   - SSH is about what the daemon will accept. The checker reads the
#     EFFECTIVE configuration with `sshd -T`, then tries a key login and
#     a forced password login, because a drop-in that parses is not the
#     same thing as a daemon that refuses passwords.
#   - firewalld is about reachability. The challenge opens a port to one
#     network with a rich rule, so the checker asks whether the port is
#     open to everyone (it must not be) and whether node2 can fetch it
#     (it must).
#
# The boolean check is behavioural too: the checker stops any backend on
# 18081, starts its own fixture there, and fetches it through httpd's
# ProxyPass. That is the only way to prove `httpd_can_network_connect`.

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

# lacks_text <description> <needle> <command...> — pass when stdout omits it.
lacks_text() {
  local desc=$1 needle=$2 got
  shift 2
  got=$("$@" 2>/dev/null)
  case "$got" in
    *"$needle"*)
      fail "$desc"
      printf '        unexpected text: %q\n' "$needle"
      printf '        actual:          %q\n' "$got"
      ;;
    *) pass "$desc" ;;
  esac
}

# ---------------------------------------------------------------------------
# Predicates
# ---------------------------------------------------------------------------

# Run a command on node2 as labuser, through the shared lab key.
n2() { runuser -u labuser -- ssh -o BatchMode=yes -o ConnectTimeout=8 node2 "$@" 2>/dev/null; }

# The local port label for http_port_t, if the learner added one.
port_label() {
  semanage port -l -C 2>/dev/null | awk '$1 == "http_port_t" && $2 == "tcp" {print $3; exit}'
}

# The persistent value of a boolean: (current, persistent).
bool_perm() {
  semanage boolean -l 2>/dev/null |
    awk '$1 == "httpd_can_network_connect" {v=$4; gsub(/[),]/, "", v); print v; exit}'
}

# The live value of the boolean, from getsebool.
bool_live() {
  getsebool httpd_can_network_connect 2>/dev/null | awk '{print $3; exit}'
}

# One effective sshd setting, from the merged configuration.
sshd_val() { sshd -T 2>/dev/null | awk -v k="$1" '$1 == k {print $2; exit}'; }

# What the server lists as acceptable methods when no key is offered.
# Password authentication shows up as a trailing `,password` in that list.
offered_methods() {
  runuser -u labuser -- ssh -o BatchMode=yes -o PubkeyAuthentication=no \
    -o PreferredAuthentications=password -o StrictHostKeyChecking=no \
    labuser@127.0.0.1 true 2>&1
}

# The deploy account's key login, as the learner would do it.
deploy_key() {
  runuser -u labuser -- ssh -o BatchMode=yes -o IdentitiesOnly=yes \
    -i /home/labuser/.ssh/r10_ed25519 -o StrictHostKeyChecking=no \
    r10deploy@127.0.0.1 "$@" 2>/dev/null
}

# ---------------------------------------------------------------------------
# The proxy backend
#
# httpd_can_network_connect is only real if httpd can connect somewhere.
# The checker serves its own fixture on 18081 and fetches /api/, which the
# lab's ProxyPass points at that port.
# ---------------------------------------------------------------------------

HTTP_DIR=''
HTTP_PID=''

cleanup_http() {
  [ -n "$HTTP_PID" ] && kill "$HTTP_PID" 2>/dev/null
  [ -n "$HTTP_DIR" ] && rm -rf "$HTTP_DIR"
}

start_backend() {
  local i
  pkill -f 'http.server 18081' 2>/dev/null
  sleep 1
  HTTP_DIR=$(mktemp -d)
  printf 'r10 api backend\n' >"$HTTP_DIR/index.html"
  python3 -m http.server 18081 --bind 127.0.0.1 --directory "$HTTP_DIR" >/dev/null 2>&1 &
  HTTP_PID=$!
  for i in 1 2 3 4 5; do
    ss -ltn 2>/dev/null | grep -q ':18081 ' && return
    sleep 1
  done
}

proxied() { curl -fsS --max-time 5 http://127.0.0.1:18443/api/ 2>/dev/null; }

trap cleanup_http EXIT

# ---------------------------------------------------------------------------
# Lab 1 — SELinux: modes, labels, ports, booleans
# ---------------------------------------------------------------------------
run_lab1() {
  section "R10 Lab 1 — SELinux: a mode, a label, and a boolean"

  val_is "SELinux is enforcing" "Enforcing" getenforce
  val_is "SELinux is configured to enforce at boot" "SELINUX=enforcing" \
    bash -c "grep -E '^SELINUX=' /etc/selinux/config"

  val_is "httpd is running" "active" systemctl is-active httpd
  val_is "httpd starts at boot" "enabled" systemctl is-enabled httpd

  val_is "port 18443 carries an http_port_t label" "18443" port_label
  has_text "the custom document root is served" "r10 custom root" \
    bash -c 'curl -fsS --max-time 5 http://127.0.0.1:18443/'
  has_text "the page is labelled as web content" "httpd_sys_content_t" \
    bash -c 'ls -Z /srv/r10/www/index.html'

  # A label that only exists on the file disappears on the next relabel.
  # The persistent mapping is what makes it survive a reboot.
  has_text "the document root has a persistent label mapping" "/srv/r10/www" \
    bash -c 'semanage fcontext -l -C | grep httpd_sys_content_t'

  val_is "the network-connect boolean is on" "on" bool_live
  val_is "the network-connect boolean is persistent" "on" bool_perm

  start_backend
  has_text "httpd proxies to a local backend" "r10 api backend" proxied
  [ -n "$HTTP_DIR" ] && rm -rf "$HTTP_DIR" && HTTP_DIR=''
}

# ---------------------------------------------------------------------------
# Lab 2 — SSH keys and a hardened daemon
# ---------------------------------------------------------------------------
run_lab2() {
  section "R10 Lab 2 — A key, and a daemon that refuses passwords"

  check "the deploy account exists" id -u r10deploy
  val_is "the deploy key is readable only by its owner" "600" \
    stat -c '%a' /home/labuser/.ssh/r10_ed25519
  check "the deploy account logs in with the key" deploy_key true

  val_is "ssh no longer accepts passwords" "no" sshd_val passwordauthentication
  val_is "ssh no longer accepts root logins" "no" sshd_val permitrootlogin
  val_is "ssh still accepts public keys" "yes" sshd_val pubkeyauthentication
  check "the sshd configuration parses" sshd -t

  # The method list in the failure message is the server's answer. Without
  # password authentication the list ends at the key-based methods.
  check_fails "a password-only login is refused" \
    runuser -u labuser -- ssh -o BatchMode=yes -o PubkeyAuthentication=no \
    -o PreferredAuthentications=password -o StrictHostKeyChecking=no \
    labuser@127.0.0.1 true
  lacks_text "the server does not offer the password method" ",password)" offered_methods

  check "labuser still logs in with the lab key" \
    bash -c 'runuser -u labuser -- ssh -o BatchMode=yes -i /home/labuser/.ssh/lab_ed25519 labuser@127.0.0.1 true'
}

# ---------------------------------------------------------------------------
# Challenge — A hardened service host
# ---------------------------------------------------------------------------
run_challenge() {
  section "R10 Challenge — A hardened service host"

  val_is "SELinux is still enforcing" "Enforcing" getenforce
  val_is "httpd is running" "active" systemctl is-active httpd
  val_is "httpd starts at boot" "enabled" systemctl is-enabled httpd

  val_is "port 18443 carries an http_port_t label" "18443" port_label
  has_text "the custom document root is served" "r10 custom root" \
    bash -c 'curl -fsS --max-time 5 http://127.0.0.1:18443/'
  has_text "the page is labelled as web content" "httpd_sys_content_t" \
    bash -c 'ls -Z /srv/r10/www/index.html'
  has_text "the document root has a persistent label mapping" "/srv/r10/www" \
    bash -c 'semanage fcontext -l -C | grep httpd_sys_content_t'

  val_is "the network-connect boolean is on" "on" bool_live
  val_is "the network-connect boolean is persistent" "on" bool_perm

  start_backend
  has_text "httpd proxies to a local backend" "r10 api backend" proxied
  [ -n "$HTTP_DIR" ] && rm -rf "$HTTP_DIR" && HTTP_DIR=''

  # The rule is a source rule, so the port must not be open to everyone.
  val_is "port 18443 is not open to every source" "no" \
    firewall-cmd --zone=public --query-port=18443/tcp
  has_text "a rich rule limits 18443 to the lab network" "10.10.10.0/24" \
    bash -c 'firewall-cmd --permanent --zone=public --list-rich-rules'
  has_text "the rich rule names the service port" "18443" \
    bash -c 'firewall-cmd --permanent --zone=public --list-rich-rules'

  check "node2 can fetch the hardened page" \
    bash -c 'runuser -u labuser -- ssh -o BatchMode=yes node2 curl -fsS --max-time 5 http://10.10.10.10:18443/'

  val_is "ssh still refuses passwords" "no" sshd_val passwordauthentication
  val_is "ssh still refuses root logins" "no" sshd_val permitrootlogin
  val_is "ssh still accepts public keys" "yes" sshd_val pubkeyauthentication
  lacks_text "the server does not offer the password method" ",password)" offered_methods

  check "the deploy account still logs in with the key" deploy_key true
  check "labuser still logs in with the lab key" \
    bash -c 'runuser -u labuser -- ssh -o BatchMode=yes -i /home/labuser/.ssh/lab_ed25519 labuser@127.0.0.1 true'
  check "node2 is still reachable from server" n2 true
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
section "RHCSA Field Guide — R10 checker"

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
