# Challenge — An unattended maintenance routine

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R8 — Scheduling and time |
| **Time** | 45–60 minutes |
| **Check** | `./bin/lab check r08 challenge` |
| **Style** | Exam task: requirements only, no steps |

</div>

This is the R8 challenge. It is written the way EX200 presents work: required behaviour, no walkthrough. Use the [theory page](../index.md), `man`, and your notes — but try it without a recipe first.

It assumes the machine from [Lab 1](lab-1-cron-and-at.md) and [Lab 2](lab-2-timers-and-chrony.md). The new work is added beside that state and must not undo it.

## Scenario

`server` needs a maintenance routine nobody has to remember. It should write a short system report every hour, keep only the most recent few, and archive the survivors once a week. The routine must survive downtime, and it must run on a clock you can trust.

The two schedulers are both involved on purpose: the report is a **systemd timer** because it must catch up after downtime, and the archive is a **cron job** because a fixed weekly slot is exactly what cron is for.

## Tasks

1. Create `/usr/local/sbin/r8-report`. When run, it:

   - creates `/srv/r8/reports` if it is missing,
   - writes a file named `report-<timestamp>-<pid>.txt` containing at least a `host:` line, a `generated:` line, an `uptime:` line, and a `disk:` line,
   - keeps only the **three newest** `report-*.txt` files and deletes the rest.

2. Create `r8-report.service` (`Type=oneshot`) and `r8-report.timer`, with the timer set to run **hourly**, to **catch up after downtime**, and to activate the service. Enable and start the timer. Do not enable the service.

3. Create `/usr/local/sbin/r8-archive`. When run, it:

   - creates `/srv/r8/archive` if it is missing,
   - writes `/srv/r8/archive/reports-<YYYYMMDD>.tar.gz` containing the reports directory,
   - deletes archives older than **four weeks**.

4. Schedule the archive with a cron system file, `/etc/cron.d/r8-archive`, to run at **03:30 every Sunday** as `root`.

5. Time is part of maintenance:

   - `server`'s timezone is `Europe/Berlin`,
   - `chronyd` is enabled and running on `server`,
   - `node2` still gets its time from `server`, and reports a synchronised clock.

6. Leave the earlier labs intact:

   - the cron heartbeat log `/var/log/r8-heartbeat.log` is still being written,
   - `r8-timer.timer` is still enabled and active.

7. Reboot both machines. Afterwards, without recreating anything:

   - `r8-report.timer` is active and still scheduled,
   - starting `r8-report.service` produces a new report and prunes back to three,
   - running the archive script produces a tarball,
   - the timezone, the time source, and the earlier labs are all unchanged.

## Hints

Only if you are stuck.

<details>
<summary>How do I generate the report filename without collisions?</summary>

Use `date` for the timestamp and the shell's `$$` for the PID, so four runs in one minute do not overwrite each other:

```bash
out="/srv/r8/reports/report-$(date +%Y%m%d-%H%M%S)-$$.txt"
```

For pruning, sort by modification time and drop everything after the third:

```bash
ls -1t /srv/r8/reports/report-*.txt | tail -n +4 | xargs -r rm -f
```

`ls -1t` is newest first, `tail -n +4` skips the three to keep, and `xargs -r` runs nothing when the list is empty (`-r` is a GNU extension; RHEL 10 has it).

</details>

<details>
<summary>What does the timer unit need?</summary>

```text { .no-copy }
[Unit]
Description=Write the R8 system report every hour

[Timer]
OnCalendar=hourly
Persistent=true
Unit=r8-report.service

[Install]
WantedBy=timers.target
```

Then `systemctl daemon-reload` and `systemctl enable --now r8-report.timer`. Check the schedule with `systemctl list-timers r8-report.timer` and `systemd-analyze calendar hourly`.

</details>

<details>
<summary>Why is my timer not listed?</summary>

`systemctl list-timers` without arguments shows **active** timers only. If yours is missing, it is not running:

```bash
systemctl is-enabled r8-report.timer
systemctl status r8-report.timer
systemctl list-timers --all | grep r8-report
```

The usual cause is enabling the service instead of the timer, or forgetting `systemctl daemon-reload` after writing the unit files.

</details>

<details>
<summary>Which fields does the archive cron line need?</summary>

Five time fields, then the user, then the command:

```text { .no-copy }
30 3 * * 0 root /usr/local/sbin/r8-archive
```

`30` is the minute, `3` the hour, `0` is Sunday. There is no need for a `crontab` command; `crond` reads `/etc/cron.d` directly. Make the file mode `0644` and owned by root, and make the script executable.

</details>

<details>
<summary>How do I test a weekly job without waiting a week?</summary>

Run the script directly. The cron line and the script are separate promises: the line says **when**, the script says **what**. Prove the script now, and read the line for the schedule:

```bash
/usr/local/sbin/r8-archive
ls -l /srv/r8/archive
tar -tzf /srv/r8/archive/reports-$(date +%Y%m%d).tar.gz
```

If you want to prove the cron half too, copy the line to a temporary every-minute file, watch the journal, then restore the weekly line.

</details>

<details>
<summary>How do I prove the archive prunes old files?</summary>

Give one file an old modification time, then run the script:

```bash
touch -d '30 days ago' /srv/r8/archive/reports-19700101.tar.gz
/usr/local/sbin/r8-archive
ls -l /srv/r8/archive
```

If the dated file is still there, the `find -mtime` expression is not matching, or the script exits before reaching it.

</details>

<details>
<summary>Why does the checker run the report service four times?</summary>

Because "keeps the three newest" is a behaviour, not a line in a file. Four runs must leave exactly three reports. If yours keeps four, the pruning line is in the wrong place — it must run **after** the new file is written, and it must match the same `report-*.txt` pattern the script creates.

</details>

## Verify

From the host, in the `labs` directory:

```bash
./bin/lab check r08 challenge
```

```text { .no-copy }
R8 Challenge — An unattended maintenance routine
  PASS  the report script is executable
  PASS  r8-report.timer is enabled at boot
  PASS  r8-report.timer is active
  PASS  the report timer survives downtime
  PASS  the report timer fires on the hour
  PASS  the report service runs the report script
  PASS  the reports directory keeps exactly the three newest
  PASS  a report records the hostname
  PASS  a report records disk usage
  PASS  the archive cron job runs weekly as root
  PASS  the archive script is executable
  PASS  archives older than four weeks are pruned
  PASS  the archive job writes a tarball
  PASS  the tarball contains the reports directory
  PASS  the cron heartbeat log is still present
  PASS  r8-timer.timer is still active
  PASS  the server timezone is still Europe/Berlin
  PASS  node2 still selects the lab server as its time source
```

The checker reads effective unit properties (`systemctl show`), the cron line with whitespace collapsed, and the artefacts the scripts produce. It does not care which editor you used.

Two parts are worth noticing:

- **The pruning check is behavioural.** The checker starts the service four times and then counts files. A script that writes reports but never deletes them fails, and so does one whose delete pattern does not match.
- **The last four checks are regressions.** They assert that the two labs are still intact, so `check r08 all` is a valid three-state stack rather than three independent tests.

## After the challenge

Nothing needs to be undone. The report timer, the weekly archive job, and the two-machine time hierarchy are a valid end state, and they are what `./bin/lab check r08 all` expects.

If you want the machine exactly as the course assumes before R9:

```bash
cd labs
./bin/lab restore clean
```

Restoring the snapshot removes the cron files, the user crontab, the unit files, `/srv/r8`, and the chrony changes on both machines in one step.
