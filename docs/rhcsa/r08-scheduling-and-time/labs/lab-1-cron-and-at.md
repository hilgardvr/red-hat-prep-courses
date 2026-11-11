# Lab 1 — cron and at

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R8 — Scheduling and time |
| **Time** | 60–75 minutes |
| **Check** | `./bin/lab check r08 lab1` |
| **Skills** | `crond`, `/etc/cron.d`, `crontab`, user tables, the `PATH` trap, `atd`, `atq` |

</div>

## What you are building

| Item | End state |
|---|---|
| Clock | Corrected from NTP before anything is scheduled |
| `/srv/r8/bin/heartbeat.sh` | Writes a timestamped line to `/var/log/r8-heartbeat.log` |
| `/etc/cron.d/r8-heartbeat` | Runs it every minute as `root` |
| `labuser`'s crontab | Runs `userbeat.sh` every minute into `/srv/r8/home/userbeat.log` |
| `atd` | Enabled, with one job queued and then run |
| `/srv/r8/at/once.txt` | Written by the `at` job |
| Persistence | After a reboot the schedules are still in place and still firing |

You will prove each schedule by its output, not by its configuration. That is the only honest test.

!!! note "Timestamps differ on every run"
    The log lines and `at` times below are captures. Yours will show the current time, and the minute boundary will be different. What must match is the **shape** of the line and the fact that it appeared at all.

## Before you begin

Start from the clean snapshot:

```bash
cd labs
./bin/lab restore clean
./bin/lab ssh
sudo -i
```

From here on, every command runs **inside the `server` VM** as root.

---

## Step 0 — Check the clock first

A restored snapshot carries the clock it was saved with, and that clock can be hours behind. Scheduling anything before the clock is right means waiting on the wrong minute.

```bash
timedatectl
```

```text { .no-copy }
               Local time: Tue 2026-11-10 05:46:48 UTC
           Universal time: Tue 2026-11-10 05:46:48 UTC
                 RTC time: Tue 2026-11-10 19:46:23
                Time zone: UTC (UTC, +0000)
System clock synchronized: yes
              NTP service: active
          RTC in local TZ: no
```

Look at the gap between `Local time` and `RTC time`: the system clock came back 14 hours behind the hardware clock. chrony already knows, but it has not had a reason to step yet. Restart it and wait for synchronisation:

```bash
systemctl restart chronyd
chronyc waitsync 30 0.1
timedatectl
```

```text { .no-copy }
try: 1, refid: 00000000, correction: 0.000000000, skew: 0.000
try: 2, refid: C40A3439, correction: 0.000005149, skew: 22.539

               Local time: Tue 2026-11-10 19:46:33 UTC
           Universal time: Tue 2026-11-10 19:46:33 UTC
                 RTC time: Tue 2026-11-10 19:46:33
                Time zone: UTC (UTC, +0000)
System clock synchronized: yes
              NTP service: active
          RTC in local TZ: no
```

The two clocks now agree and `System clock synchronized` is `yes`. Do not continue until it is. If `waitsync` times out, the VM cannot reach its NTP sources; check `chronyc sources` and the network.

## Step 1 — The cron service and the scripts

```bash
rpm -q cronie
systemctl enable --now crond
systemctl is-enabled crond
```

```text { .no-copy }
cronie-1.7.0-14.el10.x86_64
enabled
```

`crond` is already installed and enabled on the lab image. The command is there so you know which package owns it and how to check.

Create the scripts. Each one writes one line, which is enough to prove it ran:

```bash
mkdir -p /srv/r8/bin /srv/r8/at
install -d -o labuser -g labuser -m 0755 /srv/r8/home

cat > /srv/r8/bin/heartbeat.sh <<'EOF'
#!/bin/bash
printf '%s heartbeat\n' "$(date -Is)" >> /var/log/r8-heartbeat.log
EOF

cat > /srv/r8/bin/userbeat.sh <<'EOF'
#!/bin/bash
printf '%s userbeat\n' "$(date -Is)" >> /srv/r8/home/userbeat.log
EOF

cat > /srv/r8/bin/at-once.sh <<'EOF'
#!/bin/bash
printf 'ran once at %s\n' "$(date -Is)" > /srv/r8/at/once.txt
EOF

chmod 0755 /srv/r8/bin/heartbeat.sh /srv/r8/bin/userbeat.sh /srv/r8/bin/at-once.sh
ls -l /srv/r8/bin
```

```text { .no-copy }
total 12
-rwxr-xr-x. 1 root root 74 Nov 10 19:46 at-once.sh
-rwxr-xr-x. 1 root root 79 Nov 10 19:46 heartbeat.sh
-rwxr-xr-x. 1 root root 78 Nov 10 19:46 userbeat.sh
```

`install -d -o labuser -g labuser` is the first half of the lesson. `userbeat.sh` runs as `labuser`, so it must write somewhere `labuser` may write. A root-owned `/srv/r8/home` would make the job fail silently, with the error going to mail nobody reads. Creating the directory with the right owner prevents the most common cron failure before it happens.

## Step 2 — A system cron job in `/etc/cron.d`

System cron files carry a **user** field after the five time fields:

```bash
cat > /etc/cron.d/r8-heartbeat <<'EOF'
# R8 heartbeat: prove cron runs
* * * * * root /srv/r8/bin/heartbeat.sh
EOF

cat /etc/cron.d/r8-heartbeat
ls -l /etc/cron.d/r8-heartbeat
```

```text { .no-copy }
# R8 heartbeat: prove cron runs
* * * * * root /srv/r8/bin/heartbeat.sh
-rw-r--r--. 1 root root 72 Nov 10 19:46 /etc/cron.d/r8-heartbeat
```

The schedule is every minute, `root` is the user, and the command is an absolute path. No `crontab` command is involved: `crond` reads `/etc/cron.d` directly, and it picks up changes without a restart.

## Step 3 — A user crontab

A user table has no user field — the table already belongs to someone. Build it as a file so the command is reproducible, then install it for `labuser`:

```bash
cat > /srv/r8/user.cron <<'EOF'
PATH=/usr/bin:/bin
* * * * * /srv/r8/bin/userbeat.sh
EOF

crontab -u labuser /srv/r8/user.cron
crontab -l -u labuser
```

```text { .no-copy }
PATH=/usr/bin:/bin
* * * * * /srv/r8/bin/userbeat.sh
```

`PATH=` at the top is not decoration. Without it the job inherits cron's `PATH=/usr/bin:/bin`; here that is enough, but a script in `/usr/local/bin` would silently not be found. Setting it once at the top of the table is the habit worth keeping.

## Step 4 — A one-off job with `at`

`at` is not on the base image:

```bash
rpm -q at
dnf install -y at
systemctl enable --now atd
systemctl is-enabled atd
```

```text { .no-copy }
package at is not installed
...
Installed:
  at-3.2.5-14.el10_1.x86_64

enabled
```

Queue the job for one minute from now, and look at the queue:

```bash
echo /srv/r8/bin/at-once.sh | at now + 1 minute
atq
```

```text { .no-copy }
warning: commands will be executed using /bin/sh
job 1 at Tue Nov 10 19:47:00 2026
1	Tue Nov 10 19:47:00 2026 a root
```

The warning is the same environment lesson as cron: `/bin/sh`, no profile. `atq` shows the job while it is pending.

## Step 5 — Wait, then look at what happened

Cron has one-minute granularity, so nothing fires until the next minute boundary. Wait until a minute has passed — `watch -n 5 ls -l /var/log/r8-heartbeat.log`, or just wait — then:

```bash
cat /var/log/r8-heartbeat.log
cat /srv/r8/home/userbeat.log
cat /srv/r8/at/once.txt
atq
```

```text { .no-copy }
2026-11-10T19:46:36+00:00 heartbeat
2026-11-10T19:47:01+00:00 heartbeat

2026-11-10T19:46:36+00:00 userbeat
2026-11-10T19:47:01+00:00 userbeat

ran once at 2026-11-10T19:47:00+00:00
```

`atq` printed nothing, which is what success looks like: the job ran and left the queue.

Three separate mechanisms just proved themselves. The root job wrote `/var/log/r8-heartbeat.log`, the user job wrote into `labuser`'s directory, and the `at` job wrote its file and disappeared. The second line in each log is the minute after you created the job — the schedule repeating.

## Step 6 — Persistence: reboot and look again

```bash
systemctl reboot
```

Reconnect and check, without creating anything:

```bash
cd labs
./bin/lab ssh
sudo -i

cat /srv/r8/home/userbeat.log
crontab -l -u labuser
systemctl is-enabled crond atd
```

```text { .no-copy }
2026-11-10T19:46:36+00:00 userbeat
2026-11-10T19:47:01+00:00 userbeat
PATH=/usr/bin:/bin
* * * * * /srv/r8/bin/userbeat.sh
enabled
enabled
```

The tables survive because they are files. The daemons survive because they are enabled. Give the machine a minute and the logs grow again — that is the part that proves the scheduling, not the file on disk.

## Verify with the checker

From the host, in the `labs` directory:

```bash
./bin/lab check r08 lab1
```

```text { .no-copy }
R8 Lab 1 — Repeating jobs with cron and one-off jobs with at
  PASS  crond is enabled at boot
  PASS  crond is running
  PASS  the system cron job has the documented schedule and user
  PASS  the heartbeat script is executable
  PASS  the system cron job has written its log
  PASS  the last log line is a heartbeat
  PASS  labuser has a personal crontab job
  PASS  the personal cron job has written its log
  PASS  atd is enabled at boot
  PASS  atd is running
  PASS  the one-off at job produced its file
  PASS  the at job recorded that it ran
  PASS  the at queue is empty once the job has run
```

The two log checks are the behavioural ones. A learner who writes the crontab files but never lets them run fails them, and that is the point: the configuration is not the deliverable, the run is.

## If something went wrong

| Symptom | Likely cause | Fix |
|---|---|---|
| The log never appears | The cron line has the wrong number of fields | Five time fields, then `root`, then the command |
| `userbeat.log` missing | `/srv/r8/home` is not writable by `labuser` | `chown labuser:labuser /srv/r8/home` |
| `command not found` in the journal | `PATH` does not include the program's directory | Absolute path, or `PATH=` in the table |
| `at: command not found` | The `at` package is missing | `dnf install -y at`, then enable `atd` |
| `atq` still lists the job after a minute | `atd` is not running | `systemctl status atd` |
| Log timestamps look hours old | The snapshot's clock was restored | Step 0: restart `chronyd`, `chronyc waitsync` |
| `crontab -l -u labuser` prints nothing | The table was written to the wrong user | `crontab -u labuser /srv/r8/user.cron` |

To undo this lab without losing anything else, remove `/etc/cron.d/r8-heartbeat`, run `crontab -r -u labuser`, and `systemctl disable --now atd`. `./bin/lab restore clean` removes all of it and the files under `/srv` together.

## Next

[Lab 2 — Timers, NTP, and timezones](lab-2-timers-and-chrony.md) does the same job with a systemd timer, then makes `server` the lab's time source and points `node2` at it.
