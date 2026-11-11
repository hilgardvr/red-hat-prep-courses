# Lab 2 — Logs that survive, and a tuning profile

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R5 — Processes and services |
| **Time** | 45–60 minutes |
| **Check** | `./bin/lab check r05 lab2` |
| **Skills** | `journalctl`, `journald.conf` drop-ins, `systemd-analyze cat-config`, `logger`, `tuned-adm` |

</div>

## What you are building

| Item | End state |
|---|---|
| `/var/log/journal` | Exists, so the journal is written to disk |
| `/etc/systemd/journald.conf.d/10-size.conf` | Sets `SystemMaxUse=100M` |
| Journal | Contains a `r5-journal` marker that survives a reboot |
| `tuned` | Active profile is `throughput-performance`, not the default `virtual-guest` |

This lab continues on the machine you used for [Lab 1](lab-1-service.md). It uses `r5-worker` to show journal filters, and the reboot at the end proves both labs at once.

## Step 1 — Where the journal lives now

```bash
ls -d /var/log/journal
journalctl --disk-usage
ls -d /run/log/journal/*/
```

```text { .no-copy }
ls: cannot access '/var/log/journal': No such file or directory
Archived and active journals take up 8M in the file system.
/run/log/journal/edbc4119a83247f397a80af808d2da7e/
```

The disk usage number is real, but the files are in **`/run`**, which is a tmpfs. Everything the journal knows will be gone at the next boot. That is the default on a fresh install, and it is why "preserve system journals" is an objective rather than a footnote.

`Storage=auto` in `journald.conf` means: use `/var/log/journal` if it exists, otherwise keep the journal in memory. The switch is the directory, not a setting.

## Step 2 — Make it persistent

```bash
mkdir -p /var/log/journal
systemctl restart systemd-journald
journalctl --flush
ls -d /var/log/journal/*
```

```text { .no-copy }
/var/log/journal/edbc4119a83247f397a80af808d2da7e
```

```bash
find /var/log/journal -name '*.journal'
journalctl --disk-usage
```

```text { .no-copy }
/var/log/journal/edbc4119a83247f397a80af808d2da7e/system.journal
Archived and active journals take up 8M in the file system.
```

The directory is named after `/etc/machine-id`, which is how the journal keeps two machines' logs apart when `/var` is shared. `--flush` is the step people forget: the restart re-reads the configuration, but the entries already in memory move to disk on journald's own schedule (every few minutes) unless you ask for it now.

## Step 3 — Write a marker

`logger` sends a line to the journal with a tag you choose:

```bash
logger -t r5-journal "journal persistence marker"
journalctl -t r5-journal --no-pager
```

```text { .no-copy }
Nov 10 05:47:21 server r5-journal[14002]: journal persistence marker
```

A tag is not a unit, so `-u` will not find it. `-t` matches the syslog identifier, which is exactly what `logger -t` sets. Later you will search for this line again, after a reboot, and that search is the persistence proof.

## Step 4 — Cap the size of the journal

An unbounded journal fills `/var`. The supported way to change the limit is a drop-in, not an edit to the vendor file:

```bash
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/10-size.conf <<'EOF'
[Journal]
SystemMaxUse=100M
EOF
systemctl restart systemd-journald
```

Read the **merged** configuration back:

```bash
systemd-analyze cat-config systemd/journald.conf | tail -5
```

```text { .no-copy }
Audit=

# /etc/systemd/journald.conf.d/10-size.conf
[Journal]
SystemMaxUse=100M
```

```bash
journalctl --disk-usage
```

```text { .no-copy }
Archived and active journals take up 8M in the file system.
```

`systemd-analyze cat-config` prints every file that contributes to the setting, in the order systemd reads them, with commented defaults around them. Reading `/etc/systemd/journald.conf` alone would show the system default (10% of the filesystem), not your cap.

The journal is now capped at 100M, but it will not shrink to that number: the limit applies as new entries arrive. To reclaim space immediately you delete **archived** files:

```bash
journalctl --rotate
journalctl --vacuum-size=50M
```

`--rotate` closes the active file and starts a new one, so there is an archived file to remove. Without it, `--vacuum-size` reports `freed 0B`, because the file being written cannot be deleted.

## Step 5 — Filter the journal

The journal is only useful if you can find one line in it.

```bash
journalctl --list-boots --no-pager
```

```text { .no-copy }
IDX BOOT ID                          FIRST ENTRY                 LAST ENTRY
  0 533fdfe1061f43279509180ca943fe46 Tue 2026-11-10 05:42:06 UTC Tue 2026-11-10 05:47:21 UTC
```

```bash
journalctl -b -u r5-worker -n 2 --no-pager
```

```text { .no-copy }
Nov 10 05:47:12 server systemd[1]: Started r5-worker.service - R5 worker (heartbeat).
Nov 10 05:47:12 server r5-worker[13807]: worker heartbeat 05:47:12
```

```bash
journalctl -b -p err --no-pager | tail -3
```

```text { .no-copy }
Nov 10 05:43:11 localhost.localdomain systemd[1]: Failed to start NetworkManager-wait-online.service - Network Manager Wait Online.
Nov 10 05:47:08 server (worker)[13617]: r5-worker.service: Failed at step EXEC spawning /srv/r5/bin/worker: Permission denied
```

Two errors this boot, and one of them is the `203/EXEC` from Lab 1 — this is how you would have found it without `systemctl status`. The other is this VM's `NetworkManager-wait-online` unit failing at boot; it is not part of this module, and it is a reminder that `-p err` shows everything, including what you did not cause.

```bash
journalctl --since "10 min ago" -t r5-journal --no-pager
```

```text { .no-copy }
Nov 10 05:47:21 server r5-journal[14002]: journal persistence marker
```

```bash
journalctl -o short-iso -n 2 --no-pager
```

```text { .no-copy }
2026-11-10T05:47:21+00:00 server systemd-journald[14008]: System Journal (/var/log/journal/edbc4119a83247f397a80af808d2da7e) is 8M, max 100M, 92M free.
2026-11-10T05:47:21+00:00 server systemd[1]: Started systemd-journald.service - Journal Service.
```

Read that first line again: journald itself reports `max 100M`, which is the drop-in from Step 4 already in force. The timestamp format changed because `-o` asked for it — useful when you are correlating the journal with another machine's logs.

Filters combine with AND. `-b -u r5-worker` means "this boot **and** this unit"; `-p err --since "1 hour ago"` means "errors in the last hour".

## Step 6 — Switch the tuning profile

```bash
tuned-adm active
tuned-adm recommend
```

```text { .no-copy }
Current active profile: virtual-guest
virtual-guest
```

`recommend` reads the platform. This machine is a virtual guest, so the default is already right for a generic VM — but the point of the objective is to change it deliberately.

```bash
tuned-adm profile throughput-performance
tuned-adm active
cat /etc/tuned/active_profile
systemctl is-enabled tuned
```

```text { .no-copy }
Current active profile: throughput-performance
throughput-performance
enabled
```

The profile name is stored in `/etc/tuned/active_profile`, and `tuned` is enabled, so the daemon re-applies it during boot. A profile change is not "set and forget" in the sense of a shell variable: it is a file plus a running daemon, and both must be right.

## Step 7 — Reboot and prove both labs

```bash
reboot
```

From the host:

```bash
cd labs
./bin/lab ssh
sudo -i
```

```bash
journalctl -t r5-journal --no-pager
journalctl --list-boots --no-pager
ls -d /var/log/journal/*
systemctl is-active r5-worker
tuned-adm active
```

```text { .no-copy }
Nov 10 05:47:21 server r5-journal[14002]: journal persistence marker
IDX BOOT ID                          FIRST ENTRY                 LAST ENTRY
 -1 533fdfe1061f43279509180ca943fe46 Tue 2026-11-10 05:42:06 UTC Tue 2026-11-10 05:47:36 UTC
  0 cc5fefdc840b428aa2f4d31d49a9768f Tue 2026-11-10 18:38:00 UTC Tue 2026-11-10 18:38:52 UTC
/var/log/journal/edbc4119a83247f397a80af808d2da7e
active
Current active profile: throughput-performance
```

The marker's timestamp and its boot ID belong to the **previous** boot — `-1` in the list — and it is still readable. That is what a persistent journal buys you: the evidence survives the crash you are trying to investigate.

`r5-worker` came back because Lab 1 enabled it, and `tuned` re-applied its profile because Lab 2 stored it. Neither needed you.

## Step 8 — Run the checker

```bash
./bin/lab check r05 lab2
```

One of the checks compares the marker's boot ID with the current one. If you run the checker **before** rebooting, that one fails by design: the marker is from this boot, which proves nothing. After the reboot it passes, and that is the persistence test.

<details>
<summary>Show the expected check output</summary>

```text { .no-copy }
R5 Lab 2 — Logs that survive, and a tuning profile
  PASS  /var/log/journal exists
  PASS  a journal file is stored under /var/log/journal
  PASS  the journal holds entries for this boot
  PASS  the merged journald configuration caps SystemMaxUse at 100M
  PASS  the journal contains the r5-journal marker
  PASS  the marker was written before the current boot
  PASS  tuned's active profile is throughput-performance
```

</details>

## If something fails

| Symptom | Cause |
|---|---|
| `/var/log/journal` exists but is empty | `journalctl --flush` was not run (or journald was not restarted) |
| `journalctl -t r5-journal` says `-- No entries --` | The tag is wrong: `logger -t r5-journal ...`, not `-u` |
| Marker gone after reboot | The journal was still volatile: no `/var/log/journal`, or `Storage=volatile` |
| `cat-config` shows the default, not 100M | The drop-in is in the wrong directory, or is not named `*.conf` |
| `--vacuum-size` reports `freed 0B` | There are no archived files: `journalctl --rotate` first |
| `tuned-adm active` still says `virtual-guest` after reboot | The profile switch was not run, or `tuned` is not enabled |
| Checker's two boot-ID checks fail | You have not rebooted since writing the marker |

## What to remember

- `/var/log/journal` existing is what makes the journal persistent; `Storage=auto` follows the directory.
- `journalctl --flush` moves the current entries to disk now.
- `-u` filters units, `-t` filters tags, `-b` filters boots, `-p` filters severity, `--since` filters time.
- Change journald settings with drop-ins and read them back with `systemd-analyze cat-config`.
- `--vacuum-*` deletes archived files; rotate first.
- `tuned-adm profile` writes `/etc/tuned/active_profile`, and the enabled daemon re-applies it at boot.
