# Lab 2 — Timers, NTP, and timezones

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R8 — Scheduling and time |
| **Time** | 75–90 minutes |
| **Check** | `./bin/lab check r08 lab2` |
| **Skills** | `OnCalendar`, `Persistent=`, `systemctl list-timers`, `systemd-analyze calendar`, `chrony.conf`, `allow`, firewalld `ntp`, `timedatectl` |

</div>

## What you are building

| Machine | Item | End state |
|---|---|---|
| `server` | Worker | `/usr/local/bin/r8-timer.sh` appends to `/srv/r8/timer/last-run` |
| `server` | Units | `r8-timer.service` (`Type=oneshot`) and `r8-timer.timer` (`OnCalendar=*:0/2`, `Persistent=true`) |
| `server` | Timer | Enabled and active, firing every two minutes and once manually |
| `server` | NTP server | `allow 10.10.10.0/24` in `chrony.conf`, `ntp` open in firewalld |
| `server` | Timezone | `Europe/Berlin` |
| `node2` | NTP client | `server 10.10.10.10 iburst`, selected as its source |
| Persistence | Both machines reboot and the timer and the time source come back |

This lab replaces the cron job with a systemd timer, then turns the pair of VMs into a small time hierarchy: `server` follows the internet, `node2` follows `server`.

## Before you begin

This lab assumes [Lab 1](lab-1-cron-and-at.md) is complete, including its Step 0 clock check. If the clock is wrong, the timer will fire on the wrong minute and the diagnosis will be confusing.

You need two shells:

- **Shell A** — on `server`, as root: `cd labs; ./bin/lab ssh; sudo -i`
- **Shell B** — on `node2`, as root: `cd labs; ./bin/lab ssh node2; sudo -i`

---

## Step 1 — The worker and the units (server)

```bash
mkdir -p /srv/r8/timer

cat > /usr/local/bin/r8-timer.sh <<'EOF'
#!/bin/bash
printf '%s timer fired\n' "$(date -Is)" >> /srv/r8/timer/last-run
EOF

chmod 0755 /usr/local/bin/r8-timer.sh
```

The program lives in `/usr/local/bin`, not `/srv`, for the reason R5 taught: systemd runs as `init_t`, which may execute `bin_t` but not `var_t`. A unit pointing at `/srv` fails with `status=203/EXEC` and a `Permission denied` that looks like a missing file.

Now the pair. The service describes **what** to run:

```bash
cat > /etc/systemd/system/r8-timer.service <<'EOF'
[Unit]
Description=R8 timer demonstration worker

[Service]
Type=oneshot
ExecStart=/usr/local/bin/r8-timer.sh
EOF
```

The timer describes **when**:

```bash
cat > /etc/systemd/system/r8-timer.timer <<'EOF'
[Unit]
Description=Run the R8 demonstration worker every two minutes

[Timer]
OnCalendar=*:0/2
Persistent=true
Unit=r8-timer.service

[Install]
WantedBy=timers.target
EOF
```

`OnCalendar=*:0/2` means "every minute divisible by two, at second zero": `:00`, `:02`, `:04`. `Persistent=true` makes systemd run the job once at boot if a scheduled run was missed. `WantedBy=timers.target` is what `enable` acts on.

## Step 2 — Enable and inspect the timer

```bash
systemctl daemon-reload
systemctl enable --now r8-timer.timer
systemctl is-enabled r8-timer.timer
systemctl list-timers r8-timer.timer --no-pager
```

```text { .no-copy }
Created symlink '/etc/systemd/system/timers.target.wants/r8-timer.timer' -> '/etc/systemd/system/r8-timer.timer'.
enabled
NEXT                        LEFT LAST PASSED UNIT           ACTIVATES
Tue 2026-11-10 19:48:00 UTC   2s -         - r8-timer.timer r8-timer.service

1 timers listed.
```

`LEFT 2s` is a warning worth noticing: the timer is about to fire. That is fine, and the first run may happen before you finish reading.

Test the expression without waiting:

```bash
systemd-analyze calendar '*:0/2'
```

```text { .no-copy }
  Original form: *:0/2
Normalized form: *-*-* *:00/2:00
    Next elapse: Tue 2026-11-10 19:48:00 UTC
       From now: 2s left
```

`systemd-analyze calendar` is the timer equivalent of reading a cron expression aloud. Use `--iterations=5` when the expression is complex.

## Step 3 — Run it once, then let the timer run it

```bash
systemctl start r8-timer.service
systemctl show -p Result r8-timer.service
cat /srv/r8/timer/last-run
journalctl -u r8-timer.service -n 5 --no-pager
```

```text { .no-copy }
Result=success
2026-11-10T19:47:57+00:00 timer fired
Nov 10 19:47:57 server systemd[1]: Starting r8-timer.service - R8 timer demonstration worker...
Nov 10 19:47:57 server systemd[1]: r8-timer.service: Deactivated successfully.
Nov 10 19:47:57 server systemd[1]: Finished r8-timer.service - R8 timer demonstration worker.
```

`Deactivated successfully` is what a `oneshot` unit looks like when it finishes: systemd starts it, the process exits, and the unit goes back to inactive without being a failure.

Now wait up to two minutes and look again:

```bash
cat /srv/r8/timer/last-run
systemctl list-timers r8-timer.timer --no-pager
```

```text { .no-copy }
2026-11-10T19:47:57+00:00 timer fired
2026-11-10T19:48:01+00:00 timer fired
2026-11-10T19:50:01+00:00 timer fired

NEXT                            LEFT LAST                        PASSED UNIT           ACTIVATES
Tue 2026-11-10 19:52:00 UTC 1min 52s Tue 2026-11-10 19:50:01 UTC 5s ago r8-timer.timer r8-timer.service
```

Three lines: your manual run, and two scheduled runs. The journal tells the same story with timestamps and PIDs.

## Step 4 — Make `server` a time server

`chrony` is already installed and running. What is missing is permission to **serve**:

```bash
grep -n '^allow' /etc/chrony.conf || echo 'allow 10.10.10.0/24' >> /etc/chrony.conf
grep -n '^allow' /etc/chrony.conf
```

```text { .no-copy }
51:allow 10.10.10.0/24
```

Without `allow`, `chronyd` answers only its own loopback. The directive says: accept NTP requests from the lab network.

Open UDP 123:

```bash
firewall-cmd --permanent --add-service=ntp
firewall-cmd --reload
firewall-cmd --list-services
```

```text { .no-copy }
success
success
cockpit dhcpv6-client ntp ssh
```

Restart chrony so it re-reads the configuration, and prove it is listening:

```bash
systemctl restart chronyd
systemctl is-active chronyd
ss -lunp | grep ':123'
```

```text { .no-copy }
active
UNCONN 0      0            0.0.0.0:123       0.0.0.0:*    users:(("chronyd",pid=13983,fd=6))
```

`chronyc sources -n` immediately after the restart may print an empty table, because chrony has not polled yet. Give it a few seconds:

```bash
sleep 10
chronyc sources -n
chronyc tracking
```

```text { .no-copy }
MS Name/IP address         Stratum Poll Reach LastRx Last sample
===============================================================================
^- ntp8.inx.net.za               2   6    37     0    -60ms[  -60ms] +/-   71ms
^* 41.175.36.40                  2   6    37     1    +13ms[  +69ms] +/-  102ms
^- ntp4.inx.net.za               2   6    37     1    -44ms[  -44ms] +/-   60ms
^- flipping.cloudhive.net.za     2   6    37     1    -63ms[  -63ms] +/-   27ms

Reference ID    : 29AF2428 (41.175.36.40)
Stratum         : 3
Ref time (UTC)  : Tue 2026-11-10 19:51:19 2026
System time     : 0.054164037 seconds fast of NTP time
```

The addresses and strata will differ on your machine; what matters is one `^*` line and `Stratum` above 1. `server` is now a stratum-3 source for the lab.

## Step 5 — Set the timezone

```bash
timedatectl set-timezone Europe/Berlin
timedatectl show -p Timezone
date
```

```text { .no-copy }
Timezone=Europe/Berlin
Tue Nov 10 20:50:08 CET 2026
```

The clock did not change. Only how that instant is displayed: `20:50 CET` and `19:50 UTC` are the same moment. That distinction is the whole point of the timezone, and it is why logs from two machines in different zones can still be correlated if both record the offset.

Pick a zone from your own region if you prefer; `timedatectl list-timezones | grep -i <place>` finds it. The checker expects `Europe/Berlin`, so set it back before running the check if you choose another.

## Step 6 — Point `node2` at the lab server (shell B)

On `node2`, keep a backup and replace the upstream pool with the server:

```bash
grep -n '^pool\|^server' /etc/chrony.conf
cp /etc/chrony.conf /etc/chrony.conf.orig
sed -i 's|^pool .*|server 10.10.10.10 iburst|' /etc/chrony.conf
grep -n '^pool\|^server' /etc/chrony.conf
```

```text { .no-copy }
3:pool 2.almalinux.pool.ntp.org iburst
3:server 10.10.10.10 iburst
```

Restart and wait for a source:

```bash
systemctl restart chronyd
systemctl is-enabled chronyd
systemctl is-active chronyd
sleep 20
chronyc sources -n
chronyc tracking
```

```text { .no-copy }
enabled
active
MS Name/IP address         Stratum Poll Reach LastRx Last sample
===============================================================================
^* server                        3   6    17     8  -9604ns[-3917ns] +/-   34ms

Reference ID    : 0A0A0A0A (server)
Stratum         : 4
Ref time (UTC)  : Tue 2026-11-10 19:50:19 2026
System time     : 0.000003803 seconds fast of NTP time
Last offset     : +0.000005687 seconds
RMS offset      : 0.000005687 seconds
Frequency       : 4.733 ppm slow
Residual freq   : +11.714 ppm
Skew            : 19.841 ppm
Root delay      : 0.061063789 seconds
Root dispersion : 0.003667896 seconds
Update interval : 2.0 seconds
Leap status     : Normal
```

`^*` means `server` is the selected source, and `Reference ID : 0A0A0A0A` is `10.10.10.10` in hex. `Stratum 4` is one hop further from the truth than `server`'s stratum 3, which is exactly right.

```bash
timedatectl show -p NTPSynchronized -p Timezone
```

```text { .no-copy }
Timezone=UTC
NTPSynchronized=yes
```

`node2` keeps UTC, `server` keeps Berlin time. Both clocks agree; they just display differently.

## Step 7 — Persistence: reboot both machines

Reboot the server first (shell A), then the client (shell B):

```bash
systemctl reboot
```

Reconnect to `server` and check the timer:

```bash
cd labs
./bin/lab ssh
sudo -i

systemctl is-enabled r8-timer.timer
systemctl is-active r8-timer.timer
cat /srv/r8/timer/last-run
timedatectl show -p Timezone
```

```text { .no-copy }
enabled
active
2026-11-10T19:47:57+00:00 timer fired
2026-11-10T19:48:01+00:00 timer fired
2026-11-10T19:50:01+00:00 timer fired
Timezone=Europe/Berlin
```

The timer came back because it is enabled, the log survived because it is on disk, and the timezone survived because `set-timezone` wrote `/etc/localtime`.

On `node2`, after its reboot:

```bash
timedatectl show -p NTPSynchronized
chronyc sources -n
```

```text { .no-copy }
NTPSynchronized=yes
MS Name/IP address         Stratum Poll Reach LastRx Last sample
===============================================================================
^* server                        3   6    17     4    -60us[  -50ms] +/-  104ms
```

It may take ten or twenty seconds after boot for `NTPSynchronized` to become `yes` again; the checker waits for it rather than assuming it.

## Verify with the checker

From the host, in the `labs` directory:

```bash
./bin/lab check r08 lab2
```

```text { .no-copy }
R8 Lab 2 — A systemd timer, an internal time server, and a timezone
  PASS  r8-timer.timer is enabled at boot
  PASS  r8-timer.timer is active
  PASS  the timer catches up after downtime
  PASS  the timer has a calendar schedule
  PASS  the timer's service runs the worker
  PASS  the worker has run at least twice (manual and scheduled)
  PASS  chronyd is enabled at boot
  PASS  chronyd is running
  PASS  the server allows the lab network to query it
  PASS  the server timezone is Europe/Berlin
  PASS  node2 selects the lab server as its time source
  PASS  node2 reports a synchronised clock
```

The checker reads the effective timer (`systemctl show`), the log of runs, and the client's selected source. It does not read the unit files to decide whether the timer is right, and it does not trust `is-active` alone: the log proves the timer actually fired.

Both VMs must be running. The last two checks go over SSH to `node2` as `labuser`.

## If something went wrong

| Symptom | Likely cause | Fix |
|---|---|---|
| Timer enabled, never fires | Enabled the service instead of the timer | `systemctl enable --now r8-timer.timer` |
| `r8-timer.service` is `failed` | `Type=oneshot` missing, or `ExecStart` failed | `journalctl -u r8-timer.service` |
| `203/EXEC` in the journal | Program under `/srv`, or not executable | Put it in `/usr/local/bin`, `chmod 0755` |
| Timer fires at odd seconds | `AccuracySec` batches wake-ups | Add `AccuracySec=1s` |
| `chronyc sources` is empty | chrony restarted and has not polled yet | Wait a few seconds |
| `node2` shows `^?` for `server` | Firewall `ntp` closed, or `allow` missing | `firewall-cmd --list-services` on server; `grep allow /etc/chrony.conf` |
| `node2` cannot reach the source | The two VMs are not on the same lab network | `ping -c2 10.10.10.10` from node2 |
| `NTPSynchronized=no` on node2 | Not enough time has passed, or no server | Wait 20 s, then `chronyc sources` |
| `sed` changed nothing | The `pool` line had leading spaces | Edit the file by hand |
| Timezone reverts | `systemd-timesyncd`-style DHCP setting, or a container | `timedatectl set-timezone` again; check `/etc/localtime` |

To undo this lab: on `node2`, restore `/etc/chrony.conf.orig` and restart `chronyd`; on `server`, remove the `allow` line, `systemctl disable --now r8-timer.timer`, and delete the unit files. `./bin/lab restore clean` on both machines is faster and removes everything.

## Next

[Challenge — An unattended maintenance routine](challenge-maintenance.md) combines both schedulers and the time service into one task: a report on a timer, an archive on a cron job, and a clock that stays right.
