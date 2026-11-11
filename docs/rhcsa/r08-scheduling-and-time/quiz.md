# R8 knowledge check

Answer first, then open the answer. If you miss a question, return to the matching section of the [theory page](index.md).

### 1. Read the fields

What does this line do, and at what times?

```text { .no-copy }
*/10 8-17 * * mon-fri /usr/local/bin/check
```

??? question "Answer"
    Every ten minutes, from 08:00 through 17:59, Monday to Friday. `*/10` in the minute field means 0, 10, 20, 30, 40, 50; `8-17` in the hour field is a range; `mon-fri` is a named range. The job runs 60 times a weekday.

### 2. The extra field

Why does `/etc/cron.d/r8-heartbeat` need `root` before the command, while `crontab -e` does not?

??? question "Answer"
    A system cron file can run jobs as **any** user, so each line carries the user. A user crontab already belongs to one user, so the field would be redundant and is not accepted. Putting a user in a personal crontab shifts every field left by one and makes the command run as the wrong thing.

### 3. Works in the shell, fails in cron

A script runs perfectly when you type it, and fails from cron with `command not found`. What are the two most likely causes?

??? question "Answer"
    `PATH` and the shell. Cron uses a minimal environment with `PATH=/usr/bin:/bin`, so anything in `/usr/local/bin` is invisible unless the script uses absolute paths or the table sets `PATH=`. Cron also runs the line with `/bin/sh`, not your login shell, so bash-specific syntax fails. The durable fix is a script with a `#!/bin/bash` shebang and absolute paths, called by one cron line.

### 4. The percent sign

Why does this line misbehave?

```text { .no-copy }
0 3 * * * /usr/bin/date +%F > /tmp/date.txt
```

??? question "Answer"
    In a crontab, `%` separates the command from standard input: everything after the first unescaped `%` becomes the job's stdin, so the command becomes `/usr/bin/date +` and the redirect never happens. Escape it as `\%`, or — better — put the logic in a script where `%` has no special meaning.

### 5. Both day fields set

What does `0 0 1 * mon` run on?

??? question "Answer"
    The first of **every** month **and** every Monday — because when both day-of-month and day-of-week are restricted, cron runs the job if **either** matches. That is an OR, not an AND, and it surprises almost everyone. Restrict one field to `*` if you meant "the first Monday", and check with a dry run.

### 6. `crontab -r`

You typed `crontab -r` when you meant `crontab -e`. What happened, and what should you have done first?

??? question "Answer"
    It deleted your entire crontab without a prompt. There is no undo. `crontab -l > ~/crontab.backup` before editing is cheap insurance, and `crontab -l -u user` reads another user's table without touching it.

### 7. Redirecting cron output

Why does every production cron line end with `>> /var/log/job.log 2>&1`?

??? question "Answer"
    Anything the job prints goes to local mail by default. On a machine with no MTA, that is a lost message; on one with an MTA, it is a growing spool nobody reads. `>>` appends stdout, and `2>&1` sends stderr to the same place. Without the second half, errors disappear into mail while stdout is logged.

### 8. `at` versus cron

Name one task for each: a job that should use `at`, and the same task that should use cron.

??? question "Answer"
    `at`: "run this migration once at 02:00 tomorrow" — it must happen exactly once, and a repeating schedule would be wrong. Cron: "run this backup every night at 02:00" — it should keep happening. A cron job that runs once and deletes itself is a hack; an `at` job cannot repeat.

### 9. The empty `atq`

`atq` prints nothing. Did your `at` job fail?

??? question "Answer"
    No. An empty queue is the normal state after the job runs; `at` removes it once executed. The proof that it worked is the file or output the job produced, not its presence in the queue. `atq` before the scheduled time is where you check that it is pending.

### 10. Enabling the wrong unit

You created `r8-timer.service` and `r8-timer.timer`, then ran `systemctl enable --now r8-timer.service`. What happens, and what should you have enabled?

??? question "Answer"
    The job runs once at boot and never on schedule, because the service has no timer driving it. The **timer** is the unit that schedules; the service is activated by it. `systemctl enable --now r8-timer.timer` is the correct command, with `WantedBy=timers.target` in the timer's `[Install]` section. Enabling both makes the job run at boot **and** on schedule.

### 11. `Type=oneshot`

What breaks if you leave `Type=oneshot` out of a service unit that runs a script and exits?

??? question "Answer"
    Systemd assumes the default `Type=simple` process stays in the foreground. When the script exits, the unit goes inactive, and the account of the run is a failure (`Result=exit-code` or an unexpected stop) rather than success. `Type=oneshot` says "this command runs to completion"; add `RemainAfterExit=yes` only if you want the unit to stay `active` afterwards.

### 12. `Persistent=true`

A server is off at 03:00 and boots at 09:00. What does a `daily` timer do with and without `Persistent=true`?

??? question "Answer"
    Without it, the 03:00 run is simply missed; the next run is tomorrow at 03:00. With `Persistent=true`, systemd remembers the last trigger time and, because a scheduled run was missed, runs the job **once** soon after boot. This has no cron equivalent, which is one of the reasons RHEL itself uses timers for system maintenance.

### 13. Calendar or monotonic

Which timer directive would you use for each?

- "every day at 03:30"
- "15 minutes after boot"
- "one hour after the last run"

??? question "Answer"
    - `OnCalendar=*-*-* 03:30:00`
    - `OnBootSec=15min`
    - `OnUnitActiveSec=1h`

    The first is a calendar timer and behaves like cron. The other two are monotonic: they are relative to events, not to the wall clock, and cron cannot express them. Test calendar expressions with `systemd-analyze calendar`; monotonic ones have no equivalent test because they depend on runtime events.

### 14. Why did my timer fire at 03:00:47?

??? question "Answer"
    `AccuracySec` defaults to one minute, so systemd may delay a timer to batch wake-ups and save power. For a job that must start on the second, set `AccuracySec=1s`. For everything else the default is a feature: a fleet of machines does not all wake at once.

### 15. Reading `chronyc sources`

What do `^*`, `^+`, and `^?` mean, and which one tells you the clock is being disciplined?

??? question "Answer"
    `^*` is the currently selected source; the clock is following it. `^+` is an acceptable source that is not selected. `^?` is unreachable or not yet known — a firewall problem, a wrong address, or simply not enough time since the restart. `chronyc tracking` confirms the same thing in words: `Reference ID`, `Stratum`, and `System time`.

### 16. Serving time

You added `allow 10.10.10.0/24` to `chrony.conf`, restarted `chronyd`, and the client still cannot synchronise. What did you forget?

??? question "Answer"
    The firewall. `allow` makes chrony answer, but UDP 123 must reach it:

    ```bash
    firewall-cmd --permanent --add-service=ntp
    firewall-cmd --reload
    ```

    `ss -lunp | grep ':123'` proves chronyd is listening; `firewall-cmd --query-service=ntp` proves the port is open. The client side also needs `server <address> iburst`, not the old pool.

### 17. Timezone versus clock

You run `timedatectl set-timezone Asia/Tokyo`. Did the clock change?

??? question "Answer"
    No. The instant is the same; only its display changed. `date` now shows the same moment as Tokyo local time. The clock itself is changed by NTP (`chronyd`), not by the timezone. This is why logs from machines in different zones can still be correlated: they record the same instant with different offsets.

### 18. What proves persistence here

The checker passes. What actions prove each half of R8 survives a reboot?

??? question "Answer"
    Reboot **both** machines, then check without creating anything:

    - `systemctl is-active r8-timer.timer` and `r8-report.timer` — the timers are enabled, so `timers.target` started them.
    - `crontab -l -u labuser` and `cat /etc/cron.d/r8-archive` — the tables are files and survive by definition.
    - `timedatectl show -p Timezone` — `/etc/localtime` survived.
    - `chronyc sources` on `node2` — the config survived, and after a few seconds the client is synchronised again.

    Then wait a minute and look at the logs: a configuration that is present but not firing fails the objective.
