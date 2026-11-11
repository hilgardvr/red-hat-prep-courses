#!/usr/bin/env bash
#
# R9 checker — run as root inside the server VM:
#   sudo bash check.sh [lab1|lab2|challenge|all]
#
# R9 is about the network: NetworkManager connections, IPv4 and IPv6
# addressing, name resolution, and firewalld. Two kinds of state matter.
#
#   - Configuration: the connection profile, /etc/hosts, and the permanent
#     firewall. These are read with nmcli, getent, and firewall-cmd
#     --permanent.
#   - Behaviour: does a real client actually reach the port? The checker
#     starts its own HTTP listener, then curls it from node2 over the lab
#     network. That is the only honest proof that a firewall rule works.
#
# node2 is reached as labuser over the shared lab key, like R7 and R8.

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

# line_is <description> <expected> <command...> — compare one line verbatim.
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

# All live IPv4 addresses of an interface, one per line.
v4_addrs() { ip -4 -o addr show dev "$1" 2>/dev/null | awk '{print $4}'; }

# All live IPv6 addresses of an interface, one per line.
v6_addrs() { ip -6 -o addr show dev "$1" 2>/dev/null | awk '{print $4}'; }

# The first IPv4 address getent reports for a name, if any.
v4_of_name() { getent ahostsv4 "$1" 2>/dev/null | awk '{print $1; exit}'; }

# The IPv6 address of the lab0 profile. nmcli's terse mode writes `\:` for
# the colons, so they have to be stripped before comparing.
conn_v6() { nmcli -g ipv6.addresses connection show lab0 2>/dev/null | tr -d '\\'; }

# A firewall-cmd value for one zone, permanent or runtime.
fw_perm() { firewall-cmd --permanent --zone="$1" "${@:2}" 2>/dev/null; }
fw_live() { firewall-cmd --zone="$1" "${@:2}" 2>/dev/null; }

# hosts_has_ip <name> <address> — true when /etc/hosts maps that address to
# the name. Comments are ignored and the address must be in field 1, so a
# stale line under a different address does not count.
hosts_has_ip() {
  awk -v name="$1" -v ip="$2" '
    $0 !~ /^[[:space:]]*#/ && $1 == ip {
      for (i = 2; i <= NF; i++) if ($i == name) found = 1
    }
    END { exit(found ? 0 : 1) }
  ' /etc/hosts 2>/dev/null
}

# ---------------------------------------------------------------------------
# Behavioural HTTP helpers
#
# A firewall rule is only real if a client can use it. The checker serves a
# directory on the port it wants to test and curls it from node2, so the
# result does not depend on anything the learner started.
# ---------------------------------------------------------------------------

HTTP_DIR=''
HTTP_PIDS=''

cleanup_http() {
  if [ -n "$HTTP_PIDS" ]; then
    # Word splitting is intended: one PID per background server.
    kill $HTTP_PIDS 2>/dev/null
  fi
  [ -n "$HTTP_DIR" ] && rm -rf "$HTTP_DIR"
}

listening() { ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$1\$"; }

serve_port() {
  local port=$1 i
  [ -n "$HTTP_DIR" ] || HTTP_DIR=$(mktemp -d)
  if listening "$port"; then
    return
  fi
  python3 -m http.server "$port" --bind 0.0.0.0 --directory "$HTTP_DIR" >/dev/null 2>&1 &
  HTTP_PIDS="$HTTP_PIDS $!"
  for i in 1 2 3 4 5; do
    listening "$port" && return
    sleep 1
  done
}

reachable() { n2 curl -fsS --max-time 5 "http://10.10.10.10:$1/" >/dev/null 2>&1; }

trap cleanup_http EXIT

# ---------------------------------------------------------------------------
# Lab 1 — A static connection with IPv4, IPv6, and name resolution
# ---------------------------------------------------------------------------
run_lab1() {
  section "R9 Lab 1 — A static connection, two address families, and names"

  check "the lab0 connection exists" nmcli connection show lab0
  val_is "lab0 is configured manually" manual \
    bash -c 'nmcli -g ipv4.method connection show lab0'
  val_is "lab0 carries the documented IPv4 address" "192.0.2.10/24" \
    bash -c 'nmcli -g ipv4.addresses connection show lab0'
  # nmcli escapes the colons in an IPv6 address as \: in terse output.
  val_is "lab0 carries the documented IPv6 address" "2001:db8::10/64" \
    conn_v6
  val_is "lab0 comes up at boot" yes \
    bash -c 'nmcli -g connection.autoconnect connection show lab0'
  val_is "lab0 never becomes the IPv4 default route" yes \
    bash -c 'nmcli -g ipv4.never-default connection show lab0'
  val_is "lab0 never becomes the IPv6 default route" yes \
    bash -c 'nmcli -g ipv6.never-default connection show lab0'

  has_text "the lab0 device is up with its IPv4 address" "192.0.2.10/24" v4_addrs lab0
  has_text "the lab0 device is up with its IPv6 address" "2001:db8::10/64" v6_addrs lab0

  val_is "lab0 sets the r9.lab DNS search domain" "r9.lab" \
    bash -c 'nmcli -g ipv4.dns-search connection show lab0'

  val_is "r9peer resolves to its documented address" "192.0.2.11" v4_of_name r9peer
  check "the r9peer mapping lives in /etc/hosts" hosts_has_ip r9peer 192.0.2.11
}

# ---------------------------------------------------------------------------
# Lab 2 — Zones, ports, and the runtime/permanent split
# ---------------------------------------------------------------------------
run_lab2() {
  section "R9 Lab 2 — A zone, an open port, and a client that can use it"

  has_text "the r9web zone exists permanently" "r9web" \
    bash -c 'firewall-cmd --permanent --get-zones'

  val_is "r9web permanently allows the http service" yes \
    fw_perm r9web --query-service=http
  val_is "r9web permanently allows port 8080/tcp" yes \
    fw_perm r9web --query-port=8080/tcp
  has_text "r9web is bound to lab0" "lab0" \
    bash -c 'firewall-cmd --permanent --zone=r9web --list-interfaces'

  val_is "the public zone permanently allows port 8080/tcp" yes \
    fw_perm public --query-port=8080/tcp
  val_is "the public zone allows port 8080/tcp right now" yes \
    fw_live public --query-port=8080/tcp
  check_fails "the temporary port 9090 was removed when the firewall reloaded" \
    bash -c 'firewall-cmd --zone=public --list-ports | grep -q 9090'

  # The lab opens the port without losing the management path.
  val_is "the public zone still allows ssh" yes \
    fw_perm public --query-service=ssh

  serve_port 8080
  check "node2 can fetch the page on port 8080" reachable 8080
  check "node2 can still reach the server over ssh" n2 true
}

# ---------------------------------------------------------------------------
# Challenge — A named service host
# ---------------------------------------------------------------------------
run_challenge() {
  section "R9 Challenge — A named service host"

  val_is "the static hostname is fully qualified" "server.r9.lab" \
    bash -c 'hostnamectl --static'
  check "the hostname has an /etc/hosts mapping" hosts_has_ip server.r9.lab 10.10.10.10
  val_is "the hostname resolves to its lab address" "10.10.10.10" \
    v4_of_name server.r9.lab

  val_is "r9api resolves to its documented address" "192.0.2.20" v4_of_name r9api
  check "the r9api mapping lives in /etc/hosts" hosts_has_ip r9api 192.0.2.20

  val_is "the public zone permanently allows port 8443/tcp" yes \
    fw_perm public --query-port=8443/tcp
  val_is "the public zone allows port 8443/tcp right now" yes \
    fw_live public --query-port=8443/tcp

  serve_port 8443
  check "node2 can fetch the API on port 8443" reachable 8443
  serve_port 8080
  check "node2 can still fetch the web page on port 8080" reachable 8080

  # Regressions: the challenge must not sacrifice the two labs.
  has_text "lab0 still carries its static IPv4 address" "192.0.2.10/24" v4_addrs lab0
  val_is "r9peer still resolves" "192.0.2.11" v4_of_name r9peer
  val_is "r9web still allows http" yes fw_perm r9web --query-service=http
  check "node2 can still reach the server over ssh" n2 true
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
section "RHCSA Field Guide — R9 checker"

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
