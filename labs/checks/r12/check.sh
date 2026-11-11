#!/usr/bin/env bash
#
# R12 checker — run as root inside the server VM:
#   sudo bash check.sh [lab1|lab2|exama|examb|examc|all]
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
#   - a timer or cron job that has actually produced an artefact,
#   - and persistent boot state.
#
# lab1 is the rehearsal end state. lab2 is the same state after three
# deliberate breakages are diagnosed and repaired, so it asserts the repairs
# where they were made and then re-runs the full rehearsal check, because a
# repair that leaves the host broken somewhere else is not a repair.
#
# exama, examb, and examc are timed mock exams. Each starts from the clean
# snapshot and is graded on its own; unlike lab1/lab2 they do not stack.
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
# Generic predicates
# ---------------------------------------------------------------------------

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

fstype_at() {
  findmnt --noheadings -o FSTYPE --target "$1" 2>/dev/null | tr -d '[:space:]'
}

fstab_source_at() {
  findmnt --fstab --noheadings -o SOURCE --target "$1" 2>/dev/null | tr -d '[:space:]'
}

# Build the expected source from the device, so a stale UUID left in fstab
# from an earlier attempt fails instead of matching itself.
fstab_by_uuid_dev() {
  local uuid src
  uuid=$(blkid -s UUID -o value "$1" 2>/dev/null)
  src=$(fstab_source_at "$2")
  [ -n "$uuid" ] && [ "UUID=$uuid" = "$src" ]
}

# Size as a range, in MiB, because extents and alignment make exact bytes
# wrong. R6 uses the same rule.
lv_size_ok() {
  local vg=$1 lv=$2 lo=$3 hi=$4 bytes
  bytes=$(lvs --noheadings --units b --nosuffix -o lv_size "$vg/$lv" 2>/dev/null | tr -d '[:space:]')
  [ -n "$bytes" ] || return 1
  [ "$bytes" -ge $((lo * 1024 * 1024)) ] && [ "$bytes" -le $((hi * 1024 * 1024)) ]
}

# The persistent SELinux record, not the live label: a chcon looks correct
# until something relabels the file.
fcontext_record_for() {
  semanage fcontext -l -C 2>/dev/null |
    grep -F "$1" | grep -F httpd_sys_content_t >/dev/null
}

port_record_num() {
  semanage port -l -C 2>/dev/null |
    awk -v p="$1" '
      $1 == "http_port_t" && $2 == "tcp" {
        n = split($3, a, ",")
        for (i = 1; i <= n; i++) if (a[i] == p) found = 1
      }
      END {exit !found}'
}

listen_on() {
  ss -ltnH 2>/dev/null | awk -v p=":$1" '$4 ~ p"$" {found = 1} END {exit !found}'
}

fw_perm_port() {
  firewall-cmd --permanent --zone="${2:-public}" --query-port="$1/tcp" >/dev/null 2>&1
}

fw_run_port() {
  firewall-cmd --zone="${2:-public}" --query-port="$1/tcp" >/dev/null 2>&1
}

fw_perm_service() {
  firewall-cmd --permanent --zone="${2:-public}" --query-service="$1" >/dev/null 2>&1
}

fw_run_service() {
  firewall-cmd --zone="${2:-public}" --query-service="$1" >/dev/null 2>&1
}

# Fetch a page as the lab user on node2, so the request traverses the
# interface rules instead of the loopback shortcut.
fetch_from_node2() {
  runuser -u labuser -- ssh -o BatchMode=yes -o ConnectTimeout=5 node2 \
    "curl -sS -m 5 http://10.10.10.10:$1/" 2>/dev/null
}

n2() { runuser -u labuser -- ssh -o BatchMode=yes -o ConnectTimeout=8 node2 "$*" 2>/dev/null; }

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

n2_getent_v4() {
  n2 "getent ahostsv4 $1" | awk 'NR == 1 {print $1}'
}

# name at address in a hosts file; a stale line under another address fails.
hosts_has_ip() {
  awk -v ip="$2" -v name="$3" '
    $1 == ip { for (i = 2; i <= NF; i++) if ($i == name) found = 1 }
    END {exit !found}' "$1"
}

# A schedule is a promise about the future; the file is the evidence that it
# ran. A file written since this boot counts, and so does one from the last
# three minutes. A restored snapshot clock can make a fresh file look hours
# old, so wait for one tick rather than reporting a false failure.
file_fresh() {
  local f=$1 i now mtime btime
  btime=$(awk '/^btime/ {print $2}' /proc/stat 2>/dev/null)
  for i in $(seq 1 45); do
    if [ -f "$f" ]; then
      now=$(date +%s)
      mtime=$(stat -c %Y "$f" 2>/dev/null) || mtime=0
      if [ "$mtime" -ge "${btime:-0}" ] || [ $((now - mtime)) -le 180 ]; then
        return 0
      fi
    fi
    sleep 2
  done
  return 1
}

sshd_effective() {
  sshd -T 2>/dev/null | awk -v k="$1" 'tolower($1) == k {print $2; exit}'
}

# A connection that offers only password auth must be told the password method
# is not available. This reads the daemon's own answer after includes and
# Match blocks, not the file the learner edited.
offered_methods() {
  runuser -u labuser -- ssh -o BatchMode=yes -o PubkeyAuthentication=no \
    -o PreferredAuthentications=password -o StrictHostKeyChecking=no \
    labuser@127.0.0.1 true 2>&1
}

key_login_local() {
  runuser -u labuser -- ssh -o BatchMode=yes -o StrictHostKeyChecking=no \
    -i /home/labuser/.ssh/lab_ed25519 labuser@127.0.0.1 true
}

bls_all_have() {
  local needle=$1 total hits
  total=$(grubby --info=ALL 2>/dev/null | grep -c '^args=')
  hits=$(grubby --info=ALL 2>/dev/null | grep '^args=' | grep -c -- "$needle")
  [ "$total" -gt 0 ] && [ "$hits" -eq "$total" ]
}

cmdline_has() {
  tr ' ' '\n' < /proc/cmdline | grep -x -- "$1" >/dev/null
}

export_line() {
  # exportfs -v prints the path on one line and the client list, indented, on
  # the next. Join them; on releases that print one line, this still works.
  exportfs -v 2>/dev/null | awk -v p="$1" '
    $1 == p {inside = 1; out = $0; next}
    /^\// {inside = 0}
    inside {out = out " " $0}
    END {print out}'
}

archive_has() {
  tar -tzf /srv/examc/backup/etc-backup.tar.gz 2>/dev/null |
    grep -E "(^|/)$1\$" >/dev/null
}

# ---------------------------------------------------------------------------
# Lab 1 / Lab 2 — the rehearsal host
# ---------------------------------------------------------------------------

service_host() {
  # --- storage ---
  check "/dev/vdb1 exists" test -b /dev/vdb1
  has_text "/dev/vdb1 is a Linux LVM partition" "$LVM_GUID" sfdisk -d /dev/vdb
  check "the volume group r12vg exists" vgs r12vg
  check "the logical volume r12www exists" lvs r12vg/r12www
  check "r12www is about 2 GiB" lv_size_ok r12vg r12www 1900 2200

  val_is "r12www carries an XFS filesystem" xfs fstype_at "$WWW"
  check "the filesystem is mounted now" findmnt --target "$WWW"
  check "fstab mounts it by its own UUID" fstab_by_uuid_dev /dev/r12vg/r12www "$WWW"
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
  check "a persistent fcontext record covers the document root" fcontext_record_for "$WWW"
  check "port $PORT has a persistent http_port_t record" port_record_num "$PORT"
  val_is "SELinux is enforcing" Enforcing getenforce

  # --- service and firewall ---
  val_is "httpd is enabled" enabled systemctl is-enabled httpd
  val_is "httpd is active" active systemctl is-active httpd
  check "something is listening on $PORT" listen_on "$PORT"
  check "the permanent firewall allows $PORT/tcp in public" fw_perm_port "$PORT"
  check "the running firewall allows $PORT/tcp in public" fw_run_port "$PORT"
  has_text "node2 can fetch the page over the network" "$MARKER" fetch_from_node2 "$PORT"

  # --- scheduling ---
  val_is "r12-stamp.timer is enabled" enabled systemctl is-enabled r12-stamp.timer
  val_is "r12-stamp.timer is active" active systemctl is-active r12-stamp.timer
  check "the timer wrote its stamp in the last three minutes" file_fresh "$STAMP"

  # --- boot ---
  val_is "the machine still boots into multi-user.target" \
    multi-user.target systemctl get-default
}

lab1() {
  section "Lab 1 — the full-stack rehearsal"
  service_host
}

lab2() {
  section "Lab 2 — the diagnostic loop"

  # Each repair belongs in the persistent layer, which is where the lesson is.
  check "the fcontext mapping was restored, not just chcon'd" fcontext_record_for "$WWW"
  check "fstab mounts the volume by the live UUID again" \
    fstab_by_uuid_dev /dev/r12vg/r12www "$WWW"
  check "the volume is mounted again" findmnt --target "$WWW"
  check "the permanent firewall rule is back" fw_perm_port "$PORT"
  check "the page is labelled httpd_sys_content_t again" \
    label_is "$WWW/index.html" httpd_sys_content_t
  has_text "node2 can fetch the page again" "$MARKER" fetch_from_node2 "$PORT"
  check "the timer still probes after the repair" file_fresh "$STAMP"

  section "The rest of the host must still be intact"
  service_host
}

# ---------------------------------------------------------------------------
# Mock exam A — the web host
# ---------------------------------------------------------------------------

# The script is a program, so run it against a fixture and compare stdout.
exama_count_ok() {
  local dir out
  dir=$(mktemp -d) || return 1
  printf '%s\n' \
    'root:x:0:0:root:/root:/bin/bash' \
    'daemon:x:2:2:daemon:/sbin:/sbin/nologin' \
    'alice:x:1000:1000::/home/alice:/bin/bash' \
    'bob:x:1001:1001::/home/bob:/bin/bash' \
    'svc:x:1002:1002::/srv:/sbin/nologin' > "$dir/passwd"
  out=$(/usr/local/bin/exama-count "$dir/passwd" 2>/dev/null)
  rm -rf "$dir"
  [ "$out" = "3 bash accounts" ]
}

exama_missing_ok() {
  [ -x /usr/local/bin/exama-count ] &&
    ! /usr/local/bin/exama-count /nonexistent-r12-file >/dev/null 2>&1
}

exama() {
  section "Mock exam A — the web host"

  # storage
  check "/dev/vdb1 exists" test -b /dev/vdb1
  has_text "/dev/vdb1 is a Linux LVM partition" "$LVM_GUID" sfdisk -d /dev/vdb
  check "the volume group exama_vg exists" vgs exama_vg
  check "the logical volume exama_vg/examadata exists" lvs exama_vg/examadata
  check "examadata is about 1500 MiB" lv_size_ok exama_vg examadata 1400 1600
  val_is "examadata carries an XFS filesystem" xfs fstype_at /srv/exama/data
  check "the filesystem is mounted" findmnt --target /srv/exama/data
  check "fstab mounts it by its own UUID" fstab_by_uuid_dev /dev/exama_vg/examadata /srv/exama/data
  check "the whole fstab validates" findmnt --verify

  # account and policy
  check "the group examweb exists" getent group examweb
  val_is "examlogin's primary group is examweb" examweb id -gn examlogin
  val_is "examlogin has a usable password" P passwd_state examlogin
  val_is "the password ages in 10 days" 10 aging examlogin minimum
  val_is "the password expires after 120 days" 120 aging examlogin maximum
  val_is "the warning comes 7 days early" 7 aging examlogin warning
  check "the sudo drop-in parses" visudo -cf /etc/sudoers.d/10-exama
  check "the whole sudoers configuration parses" visudo -c
  has_text "examlogin may only restart httpd" "systemctl restart httpd" \
    sudo -l -U examlogin

  # content and SELinux
  check "the document root contains the page" test -f /srv/exama/data/index.html
  val_is "the page belongs to examlogin:examweb" examlogin:examweb \
    stat -c '%U:%G' /srv/exama/data/index.html
  has_text "the page carries the expected text" "Exam A portal ready" \
    cat /srv/exama/data/index.html
  check "the page is labelled httpd_sys_content_t" \
    label_is /srv/exama/data/index.html httpd_sys_content_t
  check "a persistent fcontext record covers the document root" \
    fcontext_record_for /srv/exama/data
  check "port 8090 has a persistent http_port_t record" port_record_num 8090
  val_is "SELinux is enforcing" Enforcing getenforce

  # service and firewall
  val_is "httpd is enabled" enabled systemctl is-enabled httpd
  val_is "httpd is active" active systemctl is-active httpd
  check "something is listening on 8090" listen_on 8090
  check "the permanent firewall allows 8090/tcp in public" fw_perm_port 8090
  check "the running firewall allows 8090/tcp in public" fw_run_port 8090
  has_text "node2 can fetch the page over the network" "Exam A portal ready" \
    fetch_from_node2 8090

  # script
  check "exama-count prints the bash-account count" exama_count_ok
  check "exama-count fails on a missing file" exama_missing_ok

  # schedule
  val_is "exama-stamp.timer is enabled" enabled systemctl is-enabled exama-stamp.timer
  val_is "exama-stamp.timer is active" active systemctl is-active exama-stamp.timer
  check "the timer wrote its stamp in the last three minutes" \
    file_fresh /srv/exama/reports/stamp.txt

  # boot
  val_is "the machine still boots into multi-user.target" \
    multi-user.target systemctl get-default
}

# ---------------------------------------------------------------------------
# Mock exam B — sharing and time (server + node2)
# ---------------------------------------------------------------------------

examb() {
  section "Mock exam B — the server"

  # storage
  check "/dev/vdb1 exists" test -b /dev/vdb1
  has_text "/dev/vdb1 is a Linux LVM partition" "$LVM_GUID" sfdisk -d /dev/vdb
  check "the volume group examb_vg exists" vgs examb_vg
  check "the logical volume examb_vg/exambexport exists" lvs examb_vg/exambexport
  check "exambexport is about 1 GiB" lv_size_ok examb_vg exambexport 950 1100
  val_is "exambexport carries an ext4 filesystem" ext4 fstype_at /srv/examb/export
  check "the filesystem is mounted" findmnt --target /srv/examb/export
  check "fstab mounts it by its own UUID" \
    fstab_by_uuid_dev /dev/examb_vg/exambexport /srv/examb/export
  check "the whole fstab validates" findmnt --verify
  val_is "the export directory belongs to labuser:labuser" labuser:labuser \
    stat -c '%U:%G' /srv/examb/export

  # export
  has_text "the export names the directory" "/srv/examb/export" export_line /srv/examb/export
  has_text "the export is limited to the lab network" "10.10.10.0/24" \
    export_line /srv/examb/export
  has_text "the export is read-write" "rw" export_line /srv/examb/export
  val_is "nfs-server is enabled" enabled systemctl is-enabled nfs-server
  val_is "nfs-server is active" active systemctl is-active nfs-server

  # firewall for NFS and time
  check "the permanent firewall allows the nfs service" fw_perm_service nfs
  check "the running firewall allows the nfs service" fw_run_service nfs
  check "the permanent firewall allows mountd" fw_perm_service mountd
  check "the running firewall allows mountd" fw_run_service mountd
  check "the permanent firewall allows rpc-bind" fw_perm_service rpc-bind
  check "the running firewall allows rpc-bind" fw_run_service rpc-bind
  check "the permanent firewall allows ntp" fw_perm_service ntp
  check "the running firewall allows ntp" fw_run_service ntp

  # time server
  has_text "chrony allows the lab network" "allow 10.10.10.0/24" \
    bash -c 'grep "^allow" /etc/chrony.conf'
  val_is "chronyd is enabled" enabled systemctl is-enabled chronyd
  val_is "chronyd is active" active systemctl is-active chronyd

  # name resolution
  val_is "the static hostname is server.examb.lab" server.examb.lab \
    hostnamectl --static
  check "server maps exambpeer to node2" hosts_has_ip /etc/hosts 10.10.10.11 exambpeer

  # schedule
  has_text "the cron job is installed" "examb-heartbeat" \
    cat /etc/cron.d/examb-heartbeat
  check "the cron job has written a new heartbeat" \
    file_fresh /srv/examb/export/heartbeat.log

  section "Mock exam B — the client (node2)"
  check "node2 is reachable from server" n2 true
  has_text "node2 mounts the export from fstab" "10.10.10.10:/srv/examb/export" \
    n2 "findmnt --fstab --target /mnt/examb --noheadings -o SOURCE"
  check "node2 has the export mounted now" n2 "findmnt --target /mnt/examb"
  check "node2 wrote from-node2.txt as labuser" n2 "test -f /mnt/examb/from-node2.txt"
  val_is "the file written from node2 belongs to labuser" labuser \
    n2 "stat -c %U /mnt/examb/from-node2.txt"
  val_is "node2 selects server as its time source" 10.10.10.10 n2_source
  check_n2_sync "node2 reports a synchronised clock"
  val_is "node2 resolves server.examb.lab to server" 10.10.10.10 \
    n2_getent_v4 server.examb.lab
}

# ---------------------------------------------------------------------------
# Mock exam C — security, service, and maintenance
# ---------------------------------------------------------------------------

examc() {
  section "Mock exam C — security and maintenance"

  # software
  check "tree is installed" rpm -q tree

  # web service
  check "the document root contains the page" test -f /srv/examc/www/index.html
  has_text "the page carries the expected text" "Exam C service is live" \
    cat /srv/examc/www/index.html
  check "the page is labelled httpd_sys_content_t" \
    label_is /srv/examc/www/index.html httpd_sys_content_t
  check "a persistent fcontext record covers the document root" \
    fcontext_record_for /srv/examc/www
  check "port 8081 has a persistent http_port_t record" port_record_num 8081
  val_is "SELinux is still enforcing" Enforcing getenforce
  val_is "httpd is enabled" enabled systemctl is-enabled httpd
  val_is "httpd is active" active systemctl is-active httpd
  check "something is listening on 8081" listen_on 8081
  check "the permanent firewall allows 8081/tcp in public" fw_perm_port 8081
  check "the running firewall allows 8081/tcp in public" fw_run_port 8081
  has_text "node2 can fetch the page over the network" "Exam C service is live" \
    fetch_from_node2 8081

  # SSH hardening
  check "the sshd drop-in has mode 0600" \
    test "$(stat -c %a /etc/ssh/sshd_config.d/10-examc.conf 2>/dev/null)" = 600
  check "the sshd configuration parses" sshd -t
  val_is "the effective configuration disables password auth" no \
    sshd_effective passwordauthentication
  val_is "the effective configuration disables root login" no \
    sshd_effective permitrootlogin
  lacks_text "the server does not offer the password method" ",password)" offered_methods
  check "labuser still logs in with the lab key" key_login_local

  # boot
  check "audit=1 is on every BLS entry" bls_all_have audit=1
  check "audit=1 is on the running kernel command line" cmdline_has audit=1
  val_is "the machine still boots into multi-user.target" \
    multi-user.target systemctl get-default

  # maintenance archive
  check "the configuration archive exists" test -f /srv/examc/backup/etc-backup.tar.gz
  check "the archive contains etc/hostname" archive_has etc/hostname
  check "the archive contains etc/hosts" archive_has etc/hosts
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

case "$LAB" in
  lab1)  lab1 ;;
  lab2)  lab2 ;;
  exama) exama ;;
  examb) examb ;;
  examc) examc ;;
  all)   lab1; lab2 ;;
  *)
    printf 'usage: %s [lab1|lab2|exama|examb|examc|all]\n' "$0" >&2
    exit 2
    ;;
esac

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
