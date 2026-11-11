#!/usr/bin/env bash
#
# R12 checker — run as root inside the server VM:
#   sudo bash check.sh [lab1|lab2|all]
#
# R12 is the capstone: one machine has to satisfy several objective groups at
# once, which is how the exam presents work. The checker therefore teaches no
# new command. It re-tests, in one place, the things earlier modules taught
# separately:
#
#   - storage that is real (a GPT partition, an LVM volume, a live mount, and
#     an fstab entry built from the filesystem's own UUID),
#   - an account with aging and a narrowly scoped sudo rule,
#   - SELinux labels that are both live and persistent,
#   - a web service that is enabled, listening, reachable from node2, and
#     allowed through the permanent firewall,
#   - a timer that has actually produced an artefact, not just a unit file,
#   - and the production boot target from R11.
#
# lab1 is the rehearsal end state. lab2 is the same state after three
# deliberate breakages have been diagnosed and repaired, so it asserts the
# repairs where they were made (the persistent layers) and then re-runs the
# full rehearsal check, because a repair that leaves the host broken somewhere
# else is not a repair.
#
# There is no LAB_ROOT: the module's tree is a mount point, so the state is
# live. Run it on the real lab, like R5, R6, and R10.

set -uo pipefail

LAB="${1:-all}"

LAB_ROOT=/srv
WWW=$LAB_ROOT/r12/www
STAMP=$LAB_ROOT/r12/reports/r12-stamp.txt
LVM_GUID='E6D6D379-F507-44C2-A23C-238F2A3DF928'
PORT=8088
MARKER='R12 portal is live'

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

lv_bytes() {
  lvs --noheadings --units b --nosuffix -o lv_size r12vg/r12www 2>/dev/null | tr -d ' '
}

# A "2 GiB" logical volume is not exactly 2 GiB once extents are rounded, so
# the assertion is a range, the same way R6 treats every size.
lv_size_ok() {
  local bytes lo hi
  bytes=$(lv_bytes)
  [ -n "$bytes" ] || return 1
  lo=$((1900 * 1024 * 1024))
  hi=$((2200 * 1024 * 1024))
  [ "$bytes" -ge "$lo" ] && [ "$bytes" -le "$hi" ]
}

# The filesystem's own UUID, and the source fstab will try to mount.
fs_uuid() {
  blkid -s UUID -o value /dev/r12vg/r12www 2>/dev/null
}

fstab_source() {
  findmnt --fstab --noheadings -o SOURCE --target "$WWW" 2>/dev/null | tr -d ' '
}

# Build the expected source from the device, so a stale UUID left in fstab
# from an earlier attempt fails instead of matching itself.
fstab_by_uuid() {
  local uuid
  uuid=$(fs_uuid)
  [ -n "$uuid" ] && [ "UUID=$uuid" = "$(fstab_source)" ]
}

mounted_fstype() {
  findmnt --noheadings -o FSTYPE --target "$WWW" 2>/dev/null | tr -d ' '
}

# chage label -> value, with the C locale so the labels do not translate.
aging() {
  LC_ALL=C chage -l "$1" 2>/dev/null |
    awk -F': *' -v key="$2" 'tolower($1) ~ key {print $2; exit}'
}

# The status letter from passwd -S: P usable, L locked, NP no password.
passwd_state() {
  LC_ALL=C passwd -S "$1" 2>/dev/null | awk '{print substr($2, 1, 1)}'
}

label_is() {
  ls -Z "$1" 2>/dev/null | grep ":$2:" >/dev/null
}

# The persistent SELinux record, not the live label: a chcon looks correct
# until something relabels the file.
fcontext_record() {
  semanage fcontext -l -C 2>/dev/null |
    grep -F "$WWW" | grep -F httpd_sys_content_t >/dev/null
}

port_record() {
  semanage port -l -C 2>/dev/null |
    awk -v p="$PORT" '
      $1 == "http_port_t" && $2 == "tcp" {
        n = split($3, a, ",")
        for (i = 1; i <= n; i++) if (a[i] == p) found = 1
      }
      END {exit !found}'
}

listening() {
  ss -ltnH 2>/dev/null | awk -v p=":$PORT" '$4 ~ p"$" {found = 1} END {exit !found}'
}

# Fetch the page as the lab user on node2, so the request traverses the
# interface rules instead of the loopback shortcut.
fetch_from_node2() {
  runuser -u labuser -- ssh -o BatchMode=yes -o ConnectTimeout=5 node2 \
    "curl -sS -m 5 http://10.10.10.10:$PORT/" 2>/dev/null
}

perm_port_open() {
  firewall-cmd --permanent --zone=public --query-port="$PORT/tcp" >/dev/null 2>&1
}

runtime_port_open() {
  firewall-cmd --zone=public --query-port="$PORT/tcp" >/dev/null 2>&1
}

# A schedule is a promise about the future; the stamp is the evidence that it
# ran. A stamp written since this boot counts, and so does one from the last
# three minutes. A reboot restores a snapshot clock that then steps forward,
# so the previous boot's stamp can look hours old; the timer fires every
# minute, so wait for one tick rather than reporting a false failure.
stamp_fresh() {
  local i now mtime btime
  btime=$(awk '/^btime/ {print $2}' /proc/stat 2>/dev/null)
  for i in $(seq 1 45); do
    if [ -f "$STAMP" ]; then
      now=$(date +%s)
      mtime=$(stat -c %Y "$STAMP" 2>/dev/null) || mtime=0
      if [ "$mtime" -ge "${btime:-0}" ] || [ $((now - mtime)) -le 180 ]; then
        return 0
      fi
    fi
    sleep 2
  done
  return 1
}

# ---------------------------------------------------------------------------
# Shared assertions
# ---------------------------------------------------------------------------

service_host() {
  # --- storage ---
  check "/dev/vdb1 exists" test -b /dev/vdb1
  has_text "/dev/vdb1 is a Linux LVM partition" "$LVM_GUID" sfdisk -d /dev/vdb
  check "the volume group r12vg exists" vgs r12vg
  check "the logical volume r12www exists" lvs r12vg/r12www
  check "r12www is about 2 GiB" lv_size_ok

  val_is "r12www carries an XFS filesystem" xfs mounted_fstype
  check "the filesystem is mounted now" findmnt --target "$WWW"
  check "fstab mounts it by its own UUID" fstab_by_uuid
  check "the whole fstab validates" findmnt --verify

  # --- account ---
  check "the group r12web exists" getent group r12web
  val_is "r12deploy's primary group is r12web" r12web id -gn r12deploy
  val_is "r12deploy has a usable password" P passwd_state r12deploy
  val_is "the password ages in 7 days" 7 aging r12deploy minimum
  val_is "the password expires after 90 days" 90 aging r12deploy maximum
  val_is "the warning comes 14 days early" 14 aging r12deploy warning

  check "the sudo drop-in parses" visudo -cf /etc/sudoers.d/10-r12-deploy
  check "the whole sudoers configuration parses" visudo -c
  has_text "r12deploy may restart httpd without a password" \
    "systemctl restart httpd" sudo -l -U r12deploy

  # --- content and SELinux ---
  check "the document root contains the portal page" test -f "$WWW/index.html"
  val_is "the page belongs to r12deploy:r12web" r12deploy:r12web \
    stat -c '%U:%G' "$WWW/index.html"
  has_text "the page carries the expected text" "$MARKER" cat "$WWW/index.html"
  check "the page is labelled httpd_sys_content_t" \
    label_is "$WWW/index.html" httpd_sys_content_t
  check "a persistent fcontext record covers the document root" fcontext_record
  check "port $PORT has a persistent http_port_t record" port_record
  val_is "SELinux is enforcing" Enforcing getenforce

  # --- service and firewall ---
  val_is "httpd is enabled" enabled systemctl is-enabled httpd
  val_is "httpd is active" active systemctl is-active httpd
  check "something is listening on $PORT" listening
  check "the permanent firewall allows $PORT/tcp in public" perm_port_open
  check "the running firewall allows $PORT/tcp in public" runtime_port_open
  has_text "node2 can fetch the page over the network" "$MARKER" fetch_from_node2

  # --- scheduling ---
  val_is "r12-stamp.timer is enabled" enabled systemctl is-enabled r12-stamp.timer
  val_is "r12-stamp.timer is active" active systemctl is-active r12-stamp.timer
  check "the timer wrote its stamp in the last three minutes" stamp_fresh

  # --- boot ---
  val_is "the machine still boots into multi-user.target" \
    multi-user.target systemctl get-default
}

# ---------------------------------------------------------------------------
# Phases
# ---------------------------------------------------------------------------

lab1() {
  section "Lab 1 — the full-stack rehearsal"
  service_host
}

lab2() {
  section "Lab 2 — the diagnostic loop"

  # Each repair belongs in the persistent layer, which is where the lesson is.
  check "the fcontext mapping was restored, not just chcon'd" fcontext_record
  check "fstab mounts the volume by the live UUID again" fstab_by_uuid
  check "the volume is mounted again" findmnt --target "$WWW"
  check "the permanent firewall rule is back" perm_port_open
  check "the page is labelled httpd_sys_content_t again" \
    label_is "$WWW/index.html" httpd_sys_content_t
  has_text "node2 can fetch the page again" "$MARKER" fetch_from_node2
  check "the timer still probes after the repair" stamp_fresh

  section "The rest of the host must still be intact"
  service_host
}

case "$LAB" in
  lab1) lab1 ;;
  lab2) lab2 ;;
  all)  lab1; lab2 ;;
  *)
    printf 'usage: %s [lab1|lab2|all]\n' "$0" >&2
    exit 2
    ;;
esac

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
