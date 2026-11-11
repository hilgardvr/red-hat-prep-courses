# R8 — Scheduling and time

<div class="module-meta" markdown>

| | |
|---|---|
| **Exam objective group** | 7 — Deploy, configure, and maintain systems (scheduling and time) |
| **Time** | 4–5 hours including labs |
| **Prerequisites** | [R5 — Processes and services](../r05-processes-and-services/index.md) for systemd units and the journal |
| **Labs** | 2 guided labs + 1 challenge |
| **Check command** | `./bin/lab check r08 lab1` (also `lab2` and `challenge`) |

</div>

An administrator's job is to make things happen **without being there**. R5 started services; R8 makes them run on a schedule. It covers the two classic schedulers (`cron` and `at`), the modern one (systemd timers), and the clock all three depend on.

The second half of the module is time itself. A server whose clock is wrong produces logs you cannot correlate, certificates that look expired, and scheduled jobs that fire at the wrong moment. You will configure the lab's own NTP server, point the second machine at it, and set the timezone.

The new idea here is that **a schedule is a promise about the future**. The only honest way to test one is to wait and look at what it produced. The labs make you do exactly that.

## Objective checklist

By the end of this module you should be able to:

- [ ] Read and write the five cron fields, and explain the user field
- [ ] Put a job in `/etc/cron.d`, in a user crontab, and in `/etc/crontab`
- [ ] Explain why a cron job's `PATH` is not your `PATH`
- [ ] Schedule a one-off command with `at`, and list or remove queued jobs
- [ ] Build a systemd service and timer pair
- [ ] Write `OnCalendar` expressions and test them with `systemd-analyze calendar`
- [ ] Make a timer catch up after downtime with `Persistent=true`
- [ ] Choose between cron, `at`, and a timer for a given task
- [ ] Read `chronyc sources` and `chronyc tracking`
- [ ] Serve time from one machine and point a client at it
- [ ] Set the timezone with `timedatectl`
- [ ] Prove every change survives a reboot

!!! note "Read it; do not memorise it"
    This page is a reference you will return to, not a list to learn by heart. The labs are where the commands become yours.

    Command blocks have a copy button. Blocks **without** one are output: they show what a command printed and are there to compare against, not to paste into a shell.

---

## Choosing a scheduler

RHEL 10 ships three ways to run something later. They overlap, but they are not interchangeable.

| | cron | at | systemd timer |
|---|---|---|---|
| Repeats | Yes | No, once | Yes |
| Granularity | One minute | One minute | One second, or calendar events |
| Defined in | `crontab`, `/etc/cron.d` | `at` queue | Service + timer units |
| Logs to | `journalctl -u crond` / mail | mail | `journalctl -u <name>.service` |
| Catch up after downtime | Missed | Missed | `Persistent=true` |
| Runs with | Minimal environment, `/bin/sh` | Minimal environment, `/bin/sh` | Unit environment, dependencies |
| Can depend on other units | No | No | Yes |
| Good for | Simple periodic jobs | One-off reminder or delayed task | Anything that matters |

Cron is everywhere and every sysadmin can read it, which is why the exam still expects it. Timers are what RHEL itself uses to schedule system work, and they are the better answer when you need logging, dependencies, or catch-up. `at` is for the task that should happen exactly once.

---

## cron

The daemon is `crond`, from the `cronie` package. It wakes once a minute, reads the tables, and runs whatever is due.

```bash
systemctl status crond
systemctl enable --now crond
```

### The five fields

```text { .no-copy }
minute  hour  day-of-month  month  day-of-week   command
  0       3        *           *        *          /usr/local/bin/backup
```

| Field | Range | Notes |
|---|---|---|
| Minute | 0–59 | |
| Hour | 0–23 | |
| Day of month | 1–31 | |
| Month | 1–12 | Names work: `jan`, `dec` |
| Day of week | 0–7 | 0 and 7 are Sunday; names work: `mon`, `fri` |

A field may be `*` (every), a number, a list (`1,15`), a range (`1-5`), or a step (`*/10`, `8-17/2`).

| Expression | Means |
|---|---|
| `* * * * *` | Every minute |
| `*/5 * * * *` | Every five minutes |
| `0 * * * *` | On the hour |
| `30 3 * * *` | 03:30 every day |
| `0 9 * * mon-fri` | 09:00 on weekdays |
| `0 0 1 * *` | Midnight on the first of the month |

The day-of-month and day-of-week fields are a trap: when **both** are restricted, cron runs the job if **either** matches, not both. `0 0 1 * mon` is "the first of the month **or** any Monday", which surprises almost everyone once.

### The special strings

| String | Same as |
|---|---|
| `@reboot` | Once, when cron starts |
| `@hourly` | `0 * * * *` |
| `@daily` / `@midnight` | `0 0 * * *` |
| `@weekly` | `0 0 * * 0` |
| `@monthly` | `0 0 1 * *` |
| `@yearly` / `@annually` | `0 0 1 1 *` |

### Where tables live

| Path | Fields | Who may write it |
|---|---|---|
| `crontab -e` (per user) | 5, no user | The user, and root for any user with `-u` |
| `/etc/crontab` | 5 + user | root |
| `/etc/cron.d/*` | 5 + user | root |
| `/etc/cron.hourly/`, `daily/`, `weekly/`, `monthly/` | none; executed by `run-parts` | root |

A **user** crontab has no user field, because the table already belongs to a user. A **system** file needs the user field, because it can run jobs as anyone.

```bash
crontab -e                      # edit your own table
crontab -l                      # list it
crontab -l -u labuser           # root looking at another user's table
crontab -r                      # remove it, without asking
crontab -u labuser file.cron    # install a file as that user's table
```

`crontab -r` deletes the whole table with no confirmation. There is no undo. `crontab -l > backup.cron` before editing is cheap insurance.

### The environment trap

Cron does **not** run your shell profile. The environment is close to:

```text { .no-copy }
HOME=/root
PATH=/usr/bin:/bin
SHELL=/bin/sh
LOGNAME=root
```

Three consequences, and they cause most "works in my shell, fails in cron" reports:

1. **`/usr/local/bin` is not in `PATH`.** Use absolute paths, or set `PATH=` at the top of the table.
2. **`/bin/sh` is the shell.** Bash-specific syntax in a crontab line misbehaves. Put the logic in a script with a `#!/bin/bash` shebang.
3. **There is no terminal.** Jobs that expect one hang or fail. Redirect output yourself.

A table can set variables at the top, one per line:

```text { .no-copy }
PATH=/usr/local/bin:/usr/bin:/bin
MAILTO=admin@example.com
```

`MAILTO=""` discards mail, which is what you want when there is no local mail system.

### Redirect the output

Cron mails anything the job prints to the local user. On a machine with no mail transfer agent, that is a lost message and, for a chatty job, a growing spool.

```bash
0 3 * * * /usr/local/bin/backup >> /var/log/backup.log 2>&1
```

`2>&1` matters: without it, errors go to mail instead of the log.

### The `%` rule

In a crontab, an unescaped `%` means "end of command, start of standard input". This is a real feature (it is how you feed a job stdin) and a real trap:

```text { .no-copy }
# wrong: the rest becomes stdin
0 3 * * * /usr/bin/date +%F > /tmp/date.txt

# right: escape it
0 3 * * * /usr/bin/date +\%F > /tmp/date.txt
```

If the line is long or contains `%`, put it in a script and have cron call the script. That also solves the `PATH` and `/bin/sh` problems in one move.

### Testing a cron job

Do not wait a day. Schedule it every minute, watch, then put the real schedule back:

```bash
* * * * * /usr/local/bin/myjob >> /tmp/myjob.log 2>&1
```

Then:

```bash
journalctl -u crond -f
tail -f /tmp/myjob.log
```

`crond` logs each run to the journal. If the job never appears there, the file is not being read: check the line, the file mode, and that the file is in a directory cron reads.

---

## at

`at` runs a command **once**, later. The daemon is `atd`, from the `at` package, which is not installed on the base lab image.

```bash
dnf install -y at
systemctl enable --now atd
```

Queue a job:

```bash
echo '/usr/local/bin/report' | at now + 5 minutes
at -f /usr/local/bin/report 23:30
```

| Command | Meaning |
|---|---|
| `at now + 5 minutes` | Read commands from stdin, run them in five minutes |
| `at -f script 23:30` | Run the file at 23:30 |
| `at -l` or `atq` | List the queue, with job numbers |
| `atrm 3` or `at -r 3` | Remove job 3 |
| `at -c 3` | Show exactly what job 3 will run, environment included |

`at` takes the same time forms as `date`'s natural language: `now + 2 hours`, `tomorrow 09:00`, `16:30`, `midnight`, `teatime`.

The job runs with `/bin/sh`, in the user's home directory, with cron's minimal environment. The same rules apply: absolute paths, no profile, redirect output if you want to keep it.

`atq` printing nothing is the **success** case: the job ran and left the queue.

---

## systemd timers

A timer is a systemd unit that activates another unit, usually a service. The pair is two files with the same name:

```text { .no-copy }
/etc/systemd/system/r8-timer.service
/etc/systemd/system/r8-timer.timer
```

```text { .no-copy }
[Unit]
Description=R8 timer demonstration worker

[Service]
Type=oneshot
ExecStart=/usr/local/bin/r8-timer.sh
```

```text { .no-copy }
[Unit]
Description=Run the R8 demonstration worker every two minutes

[Timer]
OnCalendar=*:0/2
Persistent=true
Unit=r8-timer.service

[Install]
WantedBy=timers.target
```

```bash
systemctl daemon-reload
systemctl enable --now r8-timer.timer
systemctl list-timers r8-timer.timer
```

Three details decide whether this works:

- **`Type=oneshot`** for a job that runs and exits. Without it, systemd expects the process to keep running and considers the unit failed when it does not.
- **`WantedBy=timers.target`**, not `multi-user.target`. Enabling the **timer** is what schedules the work; the service is started by the timer and normally should not be enabled.
- **`Unit=`** names the service to activate. It defaults to the timer's own name, which is why the two files share one.

`systemctl enable r8-timer.service` as well is a mistake: the job then runs at boot **and** on schedule.

### Calendar and monotonic timers

| Kind | Directive | Meaning |
|---|---|---|
| Calendar | `OnCalendar=*-*-* 03:30:00` | Wall-clock time, like cron |
| Monotonic | `OnBootSec=15min` | Relative to boot |
| Monotonic | `OnStartupSec=5min` | Relative to systemd starting |
| Monotonic | `OnUnitActiveSec=1h` | Relative to the last time this unit ran |

Calendar timers are the cron replacement. Monotonic timers are for "soon after boot" and "an hour after the last run", which cron cannot express.

```text { .no-copy }
OnCalendar=hourly
OnCalendar=daily
OnCalendar=*:0/15
OnCalendar=Mon..Fri 09:00
OnCalendar=*-*-* 03:30:00
```

Test any expression without waiting:

```bash
systemd-analyze calendar 'Mon..Fri 09:00'
systemd-analyze calendar --iterations=5 'Mon..Fri 09:00'
```

```text { .no-copy }
  Original form: Mon..Fri 09:00
Normalized form: Mon..Fri *-*-* 09:00:00
    Next elapse: Tue 2026-11-10 09:00:00 CET
       From now: 13h left
```

`--iterations=5` prints the next five runs, which is the fastest way to confirm you meant "weekdays" and not "every day".

### Persistent catch-up

A calendar timer fires while the machine is off and nothing happens. `Persistent=true` fixes that: systemd records the last trigger, and on the next boot runs the job **once** if it was missed.

```text { .no-copy }
[Timer]
OnCalendar=daily
Persistent=true
```

That attribute has no cron equivalent. A daily cron job on a laptop that was asleep at 03:00 simply did not run.

Two more timer settings worth knowing:

| Setting | Effect |
|---|---|
| `RandomizedDelaySec=5m` | Spread jobs out, so a fleet does not hit a server at the same second |
| `AccuracySec=1m` | How much systemd may delay the run to batch wake-ups; the default is 1 minute |

`AccuracySec` is why a timer set for `03:00` may start at `03:00:47`. For exact timing, set `AccuracySec=1s`.

### Reading timer state

```bash
systemctl list-timers
systemctl list-timers --all
systemctl status r8-timer.timer
journalctl -u r8-timer.service
```

`list-timers` is the timer's `crontab -l`: it shows the next run, the last run, and the unit each timer activates. `Status` and the journal problems live in the **service**, not the timer.

---

## chrony

System time is not a detail. TLS certificates, Kerberos tickets, log correlation, and scheduled jobs all assume the clock is close to everyone else's. **chrony** keeps it there.

```bash
systemctl status chronyd
chronyc sources
chronyc tracking
```

| Command | Answers |
|---|---|
| `chronyc sources` | Which time sources are configured, and which is selected |
| `chronyc tracking` | How far off the clock is, and which source it is following |
| `chronyc sourcestats` | Drift and offset statistics per source |
| `chronyc makestep` | Step the clock now, instead of slewing |
| `chronyc waitsync` | Block until synchronised, for scripts |

`chronyc sources` has a column of symbols, and they matter:

| Symbol | Meaning |
|---|---|
| `^*` | The currently selected source |
| `^+` | Acceptable, but not selected |
| `^-` | Excluded by the selection algorithm |
| `^?` | Unreachable, or not yet known |
| `^x` | A false ticker, rejected |

### The configuration

```text { .no-copy }
pool 2.almalinux.pool.ntp.org iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
```

| Directive | Meaning |
|---|---|
| `pool` | A DNS name that returns several servers; chrony picks the best |
| `server` | One named server |
| `iburst` | Send a burst of packets at start, so the first sync is seconds away rather than a minute |
| `driftfile` | Remember how fast this machine's clock drifts, across reboots |
| `makestep 1.0 3` | If the offset is over one second, step the clock, for the first three updates |
| `rtcsync` | Keep the hardware clock in sync with the system clock |
| `allow 10.10.10.0/24` | **Serve** time to that network. Off by default |

`makestep` matters on a VM or a restored snapshot: the clock can be hours behind, and slewing would take days. Stepping is correct when the offset is large and the service is not yet running.

### Serving time to the lab

A machine with `allow` becomes an NTP server for the listed networks. It still needs upstream time itself, and the firewall must let UDP 123 in:

```bash
echo 'allow 10.10.10.0/24' >> /etc/chrony.conf
firewall-cmd --permanent --add-service=ntp
firewall-cmd --reload
systemctl restart chronyd
```

A client then points at it with `server 10.10.10.10 iburst` in place of the pool. That is the shape of every internal time service: one or two machines talk to the outside, everything else talks to them.

```bash
ss -lunp | grep ':123'
```

That is the server-side proof: `chronyd` listening on UDP 123.

---

## Timezones

The timezone decides how the same UTC instant is displayed. It does not change the clock.

```bash
timedatectl
timedatectl list-timezones | grep -i berlin
timedatectl set-timezone Europe/Berlin
timedatectl set-timezone UTC
```

| Field | Meaning |
|---|---|
| `Local time` | What `date` prints |
| `Universal time` | UTC, the underlying instant |
| `RTC time` | The hardware clock, usually UTC |
| `Time zone` | The name, from `/usr/share/zoneinfo` |
| `System clock synchronized` | Whether chrony says the clock is trustworthy |
| `NTP service` | Whether chrony is enabled |

`set-timezone` writes `/etc/localtime`, usually as a symlink into `/usr/share/zoneinfo`. Services read it at start, so restart long-running services after changing it if they cache the timezone.

`timedatectl set-ntp true` enables `chronyd`; `set-ntp false` disables it.

!!! warning "Never set the clock by hand with NTP running"
    `timedatectl set-time` and `date -s` fight `chronyd`, which will step the clock back. To change the time source, change `chrony.conf` and restart the service. To correct a large offset once, use `chronyc makestep`.

### A note about the lab snapshots

A restored VM snapshot brings its clock with it, and that clock can be hours behind. The lab corrects it on boot with chrony, and Lab 1 starts by proving it:

```bash
systemctl restart chronyd
chronyc waitsync 30 0.1
timedatectl
```

This is not a lab quirk. Any virtual machine restored from a saved state, and any physical machine whose CMOS battery died, has the same problem. Check the clock before you trust a schedule.

---

## Common traps

| Trap | What happens | Fix |
|---|---|---|
| Relying on your shell's `PATH` in cron | `command not found` | Absolute paths, or set `PATH=` in the table |
| Bash syntax in a crontab line | Syntax errors under `/bin/sh` | Call a script with a shebang |
| Unescaped `%` in a crontab | The rest of the line becomes stdin | `\%`, or move the logic into a script |
| Job output not redirected | Mail, or a full spool | `>> log 2>&1` |
| `crontab -r` | The table is gone, with no prompt | Back up with `crontab -l` first |
| User cron job cannot write its output | The target directory belongs to root | `chown` the directory to the user |
| `at` job never runs | `atd` not enabled | `systemctl enable --now atd` |
| Timer enabled but never fires | Enabled the service, not the timer | `systemctl enable --now name.timer` |
| `Type=oneshot` missing | Unit marked failed after the job exits | Add `Type=oneshot` |
| Timer misses a run while off | No catch-up by default | `Persistent=true` |
| Expected the timer at exactly `03:00` | `AccuracySec` batches wake-ups | `AccuracySec=1s` |
| Day-of-month **and** day-of-week both set | Runs on either match | Restrict one, or check the logic |
| `chronyc sources` empty after a restart | chrony has not polled yet | Wait a few seconds, then look again |
| Clock hours off after a snapshot restore | The snapshot carried its clock | `systemctl restart chronyd`, or `chronyc makestep` |
| Client cannot reach the time server | `allow` missing, or UDP 123 blocked | Add `allow`, open `ntp` in firewalld |
| Changed the timezone and apps still show the old one | They cached it at start | Restart them |

---

## Next

[Lab 1 — cron and at](labs/lab-1-cron-and-at.md) builds a system cron job, a user cron job, and a one-off `at` job, and waits for each to prove itself. [Lab 2 — Timers, NTP, and timezones](labs/lab-2-timers-and-chrony.md) replaces the cron job with a systemd timer, makes `server` a time server, and points `node2` at it. The [challenge](labs/challenge-maintenance.md) turns all of that into an unattended maintenance routine.
