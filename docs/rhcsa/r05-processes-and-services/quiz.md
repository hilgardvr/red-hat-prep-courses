# R5 knowledge check

Answer first, then open the answer. If you miss a question, return to the matching section of the [theory page](index.md).

### 1. Nice values

What is the range of a nice value, which end gets more CPU, and who may move a process towards that end?

??? question "Answer"
    The range is **-20 to 19**, with a default of **0**. Lower numbers are *less nice*: the process takes priority. Raising a process towards -20 requires root; any user may make their own process nicer (a higher number). `nice -n 5 cmd` starts one, `renice -n 5 -p PID` changes a running one.

### 2. `show` says 10, `ps` says 0

`systemctl show -p Nice --value r5-worker` prints `10`, but `ps -o ni= -p $(systemctl show -p MainPID --value r5-worker)` prints `0`. What happened?

??? question "Answer"
    The unit was edited (or a drop-in added) and `daemon-reload` was run, but the service was not restarted. `systemctl show` reads the **configuration**; `ps` reads the **running process**, which started under the old setting. `systemctl restart r5-worker` applies it.

### 3. Signals

Why is `kill -9` a last resort rather than the first thing to try?

??? question "Answer"
    `SIGKILL` cannot be caught, so the process cannot flush buffers, close files cleanly, remove lock files, or tell its parent why it died. `SIGTERM` (15) gives it that chance. Escalate to `-9` only after `SIGTERM` has been ignored for long enough to be a real problem.

### 4. `start` and `enable`

You run `systemctl start httpd` on a fresh machine. It works. You reboot. What is the state of the service, and what should you have run?

??? question "Answer"
    It is **inactive** after the reboot. `start` only changes the runtime state; nothing was added to a `.wants/` directory, so nothing started it at boot. The single command that does both is `systemctl enable --now httpd`.

### 5. What `enable` actually does

`systemctl enable r5-worker` prints a line about a symlink. What is the symlink, and why does that make the service start at boot?

??? question "Answer"
    It creates `/etc/systemd/system/multi-user.target.wants/r5-worker.service`, pointing at the real unit. When the system reaches `multi-user.target`, systemd starts every unit in that target's `.wants/` directory. Enable is a symlink, not a database flag.

### 6. Masking

`systemctl mask r5-scratch` fails with `Failed to mask unit: File '/etc/systemd/system/r5-scratch.service' already exists`. Why, and what is the correct sequence?

??? question "Answer"
    A mask is itself a file at that exact path — a symlink to `/dev/null`. systemd will not overwrite a real unit file with it. Sequence: `systemctl disable --now r5-scratch`, remove the unit file, `systemctl daemon-reload`, then `systemctl mask r5-scratch`. The name stays blocked even though the file is gone.

### 7. Disable versus mask

A unit is `disabled` and another unit has `Wants=` on it. Can it still start? What if it is `masked`?

??? question "Answer"
    A disabled unit **can** start: by hand, or because another unit wants it. Disable only removes the boot-time symlink. A masked unit cannot start at all — systemd finds `/dev/null` where the unit should be and refuses, even for a dependency.

### 8. `daemon-reload`

You edit a unit file and run `systemctl restart foo`. The old behaviour persists. What did you forget?

??? question "Answer"
    `systemctl daemon-reload`. systemd keeps unit definitions in memory; `restart` re-runs the process but uses the definition it already has. `status` warns that the unit file changed on disk. Reload after creating, editing, or deleting any unit file or drop-in.

### 9. Drop-ins

Why change a unit with a drop-in in `foo.service.d/` instead of editing the unit file itself?

??? question "Answer"
    A vendor unit in `/usr/lib/systemd/system` is overwritten by the next package update. A drop-in in `/etc` survives updates, appears separately in `systemctl cat`, and can be removed to revert the change. Numbered filenames (`10-`, `90-`) control the order in which drop-ins apply.

### 10. `203/EXEC`

A service fails with `status=203/EXEC` and `Permission denied`, but the program is executable and runs fine when you type its path. What is the cause?

??? question "Answer"
    SELinux. systemd runs as `init_t`, which may execute files labelled `bin_t` but not `var_t`. `/srv` is `var_t`; `/usr/local/bin` is `bin_t`. The interactive root shell is `unconfined_t`, which is why it worked by hand. `ls -Z` shows the label.

### 11. Volatile or persistent

How do you tell whether the journal on a machine will survive a reboot?

??? question "Answer"
    Look for `/var/log/journal`. With `Storage=auto` (the default), journald writes to disk only if that directory exists; otherwise it keeps the journal in `/run/log/journal`, which is memory. `journalctl --disk-usage` reports the size either way, so it does not answer the question.

### 12. Filters

What is the difference between `journalctl -u r5-worker` and `journalctl -t r5-journal`?

??? question "Answer"
    `-u` filters by **unit**, matching entries systemd associates with `r5-worker.service`. `-t` filters by **syslog identifier**, the tag set by `logger -t` or by a program's logging. A line written with `logger -t r5-journal` has no unit, so `-u` will not find it.

### 13. Effective configuration

You set `SystemMaxUse=100M` in a drop-in, but `journalctl --disk-usage` still shows 4G. You read `/etc/systemd/journald.conf` and see the old value. Which command shows what journald actually uses, and why is the size not shrinking?

??? question "Answer"
    `systemd-analyze cat-config systemd/journald.conf` prints the merged configuration, with every drop-in applied. The cap is enforced as new entries arrive; existing files are not rewritten. `journalctl --rotate` then `journalctl --vacuum-size=100M` removes archived files now.

### 14. Tuning across reboots

You run `tuned-adm profile throughput-performance`. What two pieces of state make that survive a reboot, and how do you check each?

??? question "Answer"
    `/etc/tuned/active_profile` contains the name (check with `cat`), and `tuned` is enabled so the daemon starts and applies it (`systemctl is-enabled tuned` → `enabled`). `tuned-adm active` confirms what is actually applied right now.

### 15. Killing the main process

You kill the MainPID of an enabled service that has no `Restart=` setting, using `SIGTERM`. Is the unit stopped or failed? What changes if you use `SIGKILL`?

??? question "Answer"
    `SIGTERM` is a clean exit to systemd: the unit goes **inactive (dead)** and the journal says `Deactivated successfully`. `SIGKILL` is not clean: the unit goes **failed** (`Result: signal`, `code=killed, signal=KILL`) and appears in `systemctl --failed`. Neither restarts the service, because `Restart=` is not set. `Restart=always` brings it back after both, but it does **not** fight a deliberate `systemctl stop`.
