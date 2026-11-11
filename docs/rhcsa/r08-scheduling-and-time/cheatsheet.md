# R8 cheat sheet

A compact reference for review. Everything here is explained in the [theory page](index.md).

## Choosing a scheduler

| | cron | at | systemd timer |
|---|---|---|---|
| Repeats | Yes | No | Yes |
| Granularity | 1 minute | 1 minute | 1 second or calendar |
| Defined in | crontab, `/etc/cron.d` | `at` queue | `.service` + `.timer` |
| Catch up after downtime | No | No | `Persistent=true` |
| Dependencies | No | No | Yes |
| Logs to | journal / mail | mail | `journalctl -u <name>.service` |

## cron fields

```text { .no-copy }
minute  hour  day-of-month  month  day-of-week   command
  0       3        *           *        *          /usr/local/bin/backup
```

| Field | Range | Notes |
|---|---|---|
| Minute | 0–59 | |
| Hour | 0–23 | |
| Day of month | 1–31 | |
| Month | 1–12 | `jan`…`dec` |
| Day of week | 0–7 | 0 and 7 are Sunday; `mon`…`sun` |

`*` every · `*/5` step · `1,15` list · `1-5` range · `8-17/2` range with step.

| Expression | Means |
|---|---|
| `* * * * *` | Every minute |
| `*/5 * * * *` | Every 5 minutes |
| `0 * * * *` | Hourly |
| `30 3 * * *` | 03:30 daily |
| `0 9 * * mon-fri` | 09:00 weekdays |
| `0 0 1 * *` | Midnight on the 1st |

!!! warning "Both day fields set means OR"
    `0 0 1 * mon` runs on the first of the month **and** every Monday, not only when the two coincide.

| Special string | Same as |
|---|---|
| `@reboot` | Once at cron start |
| `@hourly` | `0 * * * *` |
| `@daily` / `@midnight` | `0 0 * * *` |
| `@weekly` | `0 0 * * 0` |
| `@monthly` | `0 0 1 * *` |
| `@yearly` | `0 0 1 1 *` |

## Where cron reads

| Path | User field? |
|---|---|
| `crontab -e` | No |
| `/etc/crontab` | Yes |
| `/etc/cron.d/*` | Yes |
| `/etc/cron.{hourly,daily,weekly,monthly}/` | No — `run-parts` |

```bash
crontab -e                      # edit yours
crontab -l                      # list yours
crontab -l -u labuser           # list another user's
crontab -u labuser file.cron    # install a file
crontab -r                      # delete yours, no prompt
```

System file line:

```text { .no-copy }
* * * * * root /srv/r8/bin/heartbeat.sh
```

## The cron environment

```text { .no-copy }
HOME=/root
PATH=/usr/bin:/bin
SHELL=/bin/sh
LOGNAME=root
```

| Trap | Fix |
|---|---|
| `command not found` | Absolute path, or `PATH=` at the top of the table |
| Bash syntax fails | Call a script with `#!/bin/bash` |
| Output lost to mail | `>> /var/log/job.log 2>&1` |
| Unescaped `%` truncates the command | `\%`, or move logic into a script |
| User job cannot write | `chown` the target directory to the user |

```bash
journalctl -u crond -f
```

## at

```bash
dnf install -y at
systemctl enable --now atd
echo /usr/local/bin/job | at now + 5 minutes
at -f /usr/local/bin/job 23:30
```

| Command | Meaning |
|---|---|
| `atq` / `at -l` | List the queue |
| `at -c 3` | Show what job 3 will run |
| `atrm 3` / `at -r 3` | Remove job 3 |

Empty `atq` after the scheduled time is success: the job ran and left the queue.

## systemd timers

```text { .no-copy }
/etc/systemd/system/r8-timer.service
/etc/systemd/system/r8-timer.timer
```

```text { .no-copy }
[Service]
Type=oneshot
ExecStart=/usr/local/bin/r8-timer.sh
```

```text { .no-copy }
[Timer]
OnCalendar=*:0/2
Persistent=true
Unit=r8-timer.service

[Install]
WantedBy=timers.target
```

```bash
systemctl daemon-reload
systemctl enable --now r8-timer.timer     # the timer, not the service
systemctl list-timers --all
systemctl status r8-timer.timer
journalctl -u r8-timer.service
```

| Directive | Meaning |
|---|---|
| `OnCalendar=` | Wall-clock schedule, cron-like |
| `OnBootSec=15min` | Once, 15 min after boot |
| `OnUnitActiveSec=1h` | 1 h after the last run |
| `Persistent=true` | Run once at boot if a run was missed |
| `AccuracySec=1s` | Do not batch this timer's wake-up |
| `RandomizedDelaySec=5m` | Spread a fleet's start times |

```text { .no-copy }
OnCalendar=hourly
OnCalendar=daily
OnCalendar=*:0/15
OnCalendar=Mon..Fri 09:00
OnCalendar=*-*-* 03:30:00
```

```bash
systemd-analyze calendar 'Mon..Fri 09:00'
systemd-analyze calendar --iterations=5 'Mon..Fri 09:00'
```

| Symptom | Cause |
|---|---|
| Enabled, never fires | Enabled the service, not the timer |
| Service `failed` after a quick success | Missing `Type=oneshot` |
| Fired at `:47` | `AccuracySec` default is 1 minute |
| `203/EXEC` in the journal | Program under `/srv`, or not executable |

Programs go in `/usr/local/bin` or `/usr/local/sbin`: systemd (`init_t`) may execute `bin_t`, not `var_t`.

## chrony

```bash
systemctl status chronyd
chronyc sources
chronyc tracking
chronyc sourcestats
chronyc makestep
chronyc waitsync 30 0.1
```

| Symbol | Meaning |
|---|---|
| `^*` | Selected, the clock is following it |
| `^+` | Acceptable, not selected |
| `^-` | Excluded |
| `^?` | Unreachable / not yet known |
| `^x` | False ticker |

```text { .no-copy }
pool 2.almalinux.pool.ntp.org iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
allow 10.10.10.0/24
```

| Directive | Meaning |
|---|---|
| `pool` / `server` | Many candidates / one named source |
| `iburst` | Burst at start, sync in seconds |
| `makestep 1.0 3` | Step instead of slew if off by >1 s, first 3 updates |
| `allow <net>` | **Serve** time to that network; off by default |

```bash
firewall-cmd --permanent --add-service=ntp
firewall-cmd --reload
ss -lunp | grep ':123'
```

Client line, replacing the pool:

```text { .no-copy }
server 10.10.10.10 iburst
```

| Symptom | Cause |
|---|---|
| `sources` empty right after restart | chrony has not polled yet; wait ~10 s |
| `^?` for the server | `allow` missing, `ntp` blocked, or wrong address |
| Clock hours off after a snapshot restore | Snapshot carried its clock; restart `chronyd` |

## Timezones

```bash
timedatectl
timedatectl list-timezones | grep -i berlin
timedatectl set-timezone Europe/Berlin
timedatectl set-ntp true
```

| Field | Meaning |
|---|---|
| `Local time` | What `date` shows |
| `Universal time` | UTC |
| `RTC time` | Hardware clock |
| `Time zone` | Name from `/usr/share/zoneinfo` |
| `System clock synchronized` | chrony trusts the clock |

`set-timezone` changes the display, not the instant. Never `timedatectl set-time` while chrony runs; use `chronyc makestep`.

## Quick diagnosis

| Symptom | Check |
|---|---|
| Job never runs | `journalctl -u crond`; field count; file mode |
| Ran as the wrong user | User field missing in a system file |
| Works by hand, not from cron | `PATH`, `/bin/sh`, unescaped `%` |
| Timer not in `list-timers` | Not active; `list-timers --all`, `is-enabled` |
| Timer skipped a run | Set `Persistent=true` |
| `at: command not found` | `dnf install -y at`; `systemctl enable --now atd` |
| Client not syncing | `allow`, firewalld `ntp`, `server <ip> iburst` |
| Clock wrong after reboot | Snapshot or RTC problem; `chronyc waitsync` |
| Timezone reverted | Check `/etc/localtime`; set it again |
