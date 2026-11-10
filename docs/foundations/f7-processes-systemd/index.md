# F7 — Processes, systemd, and logs

<div class="module-meta" markdown>

| | |
|---|---|
| **Time** | 75–90 minutes |
| **Prerequisites** | [F5](../f5-streams-text/index.md) and [F6](../f6-users-permissions/index.md) |
| **Lab** | Inspect and control processes and services on `server` |
| **Self-check** | At the end of the page |

</div>

A running system is a set of processes managed by `systemd`, with a journal that records what happened. Almost every exam task ends with "start the service, enable it, and prove it survived a reboot". This module gives you the vocabulary for all three parts.

R5 goes deeper into writing your own unit files. R11 covers boot targets and recovery. Here you learn to inspect, start, enable, and read logs.

## Programs and processes

A **program** is a file on disk. A **process** is a running instance of it, with its own memory, open files, user, and PID. One program can have many processes: every `bash` you start gets a new PID.

Each process has attributes the kernel tracks:

| Attribute | What it means | How to see it |
|---|---|---|
| PID | Process ID | `ps`, `pgrep` |
| PPID | Parent process ID | `ps -o ppid` |
| UID | User the process runs as | `ps -o user` |
| State | Running, sleeping, stopped, zombie | `ps -o stat` |
| Priority | Scheduling niceness | `ps -o ni` |
| Open files | File descriptors and sockets | `lsof -p PID` (if installed) |
| Current directory | Where relative paths resolve | `ls -l /proc/PID/cwd` |

The parent-child relationship forms a tree rooted at PID 1:

```bash
ps -p 1 -o pid,comm,args
pstree -p | head
```

```text
    PID COMMAND         COMMAND
      1 systemd         /usr/lib/systemd/systemd --switched-root --system --deserialize=42
```

### Listing processes

```bash
ps -ef
ps aux
ps -eo pid,ppid,user,stat,ni,comm --sort=-%cpu | head
pgrep -a sshd
pidof systemd
```

| Command | Shows |
|---|---|
| `ps -ef` | Every process: UID, PID, PPID, start time, command |
| `ps aux` | BSD style: user, PID, CPU, memory, state, command |
| `ps -eo ...` | Exactly the columns you name |
| `pgrep -a name` | PIDs plus command lines for matching processes |
| `pidof name` | PIDs for an exact program name |

Process states are one letter in the `STAT` column:

| State | Meaning |
|---|---|
| `R` | Running or runnable |
| `S` | Sleeping, waiting for an event |
| `D` | Uninterruptible sleep, usually waiting on I/O |
| `T` | Stopped, for example by ++ctrl+z++ |
| `Z` | Zombie: finished, but the parent has not reaped it |

A `D` state that never clears usually points at a storage problem. A `Z` process uses no CPU; it is waiting for its parent to call `wait()`.

### Foreground, background, and signals

A job is a command the shell is managing. Start one in the background with `&`, suspend the foreground job with ++ctrl+z++, and switch with `fg` and `bg`:

```bash
sleep 300 &
jobs
fg %1        # bring it back to the foreground; then press Ctrl+Z to suspend
bg %1        # resume it in the background
kill %1      # terminate the job
```

Signals are how processes are told to do something:

| Signal | Number | Meaning |
|---|---|---|
| `SIGTERM` | 15 | Please shut down cleanly; the default for `kill` |
| `SIGKILL` | 9 | Die immediately; cannot be caught or cleaned up |
| `SIGHUP` | 1 | Historically "hang up"; many daemons reload configuration |
| `SIGINT` | 2 | Interrupt, what ++ctrl+c++ sends |
| `SIGSTOP` / `SIGCONT` | 19 / 18 | Pause and resume |

```bash
kill -l | head
kill PID
kill -TERM PID
kill -9 PID
pkill -f 'sleep 300'
```

`SIGKILL` is a last resort. It gives the process no chance to flush buffers or remove lock files, which is why services should be stopped with `systemctl stop`. `pkill -f` matches the full command line and is easy to aim at the wrong process; check with `pgrep -af` first.

Priority is **niceness**, from -20 (most favorable) to 19 (least). Only root can lower the value:

```bash
nice -n 10 long-running-command &
renice -n 5 -p PID
```

## systemd as PID 1

`systemd` starts at boot, becomes PID 1, and supervises the rest of the system. You do not start most services by running their binaries; you ask systemd.

### Units

Everything systemd manages is a **unit** described by a unit file:

| Type | Manages | Example |
|---|---|---|
| `.service` | A daemon or one-shot task | `sshd.service` |
| `.socket` | Socket activation | `sshd.socket` |
| `.timer` | Scheduled activation | `dnf-makecache.timer` |
| `.mount` | A mount point | `-.mount` (the root) |
| `.target` | A group of units, like a runlevel | `multi-user.target` |
| `.path` | Watch a path for changes | `systemd-ask-password-wall.path` |

Unit files live in `/usr/lib/systemd/system` when shipped by a package, and in `/etc/systemd/system` when created locally or by an administrator. `systemctl cat` shows the file and any drop-ins:

```bash
systemctl cat sshd
systemctl cat sshd | head -20
```

### Reading status

```bash
systemctl status sshd --no-pager
systemctl is-active sshd
systemctl is-enabled sshd
```

```text
● sshd.service - OpenSSH server daemon
     Loaded: loaded (/usr/lib/systemd/system/sshd.service; enabled; preset: enabled)
     Active: active (running) since Fri 2026-11-07 09:02:11 UTC; 41min ago
   Main PID: 812 (sshd)
```

Three facts matter in that output:

- **Loaded** tells you which unit file is used and whether it is enabled at boot.
- **Active** tells you whether it is running now.
- **Main PID** lets you connect the service to a process.

### Running versus enabled

This is the distinction the exam tests most often:

| Command | Effect |
|---|---|
| `systemctl start unit` | Start now; does not survive reboot |
| `systemctl enable unit` | Start at boot; does not start now |
| `systemctl enable --now unit` | Both |
| `systemctl stop unit` | Stop now |
| `systemctl disable unit` | Do not start at boot |
| `systemctl restart unit` | Stop, then start |
| `systemctl reload unit` | Re-read configuration without dropping connections, if supported |
| `systemctl mask unit` | Prevent it from being started at all |

A service that is active but disabled will not come back after a reboot. A service that is enabled but not started is not running right now. The lab reboot is how you prove which one you have.

### Finding units

```bash
systemctl list-units --type=service --state=running
systemctl list-unit-files --type=service | head
systemctl --failed
systemctl list-timers
```

`systemctl --failed` is the first command to run when something is broken. If it prints nothing, systemd has no failed units, and your problem is elsewhere.

### Reloading after an edit

systemd reads unit files at start time. If you edit or add one, tell systemd:

```bash
sudo systemctl daemon-reload
sudo systemctl restart myapp
```

Without `daemon-reload`, systemd keeps using the old definition, which produces confusing "it did not pick up my change" results. R5 creates a unit file and walks through this.

### Targets

A **target** groups units into a boot state. The two you need now:

| Target | Meaning |
|---|---|
| `multi-user.target` | Full system, text console, no graphical login |
| `graphical.target` | Full system plus a display manager |

```bash
systemctl get-default
systemctl list-units --type=target
```

R11 covers changing the default target with `systemctl set-default` and recovering a system that will not boot.

## The journal

`systemd-journald` collects logs from the kernel, services, and `stdout`/`stderr` of units. `journalctl` reads them.

| Command | Shows |
|---|---|
| `journalctl` | Everything, newest last, in a pager |
| `journalctl -b` | Only this boot |
| `journalctl -u sshd` | Only that unit |
| `journalctl -n 20` | The last 20 lines |
| `journalctl -f` | Follow new entries |
| `journalctl --since "10 min ago"` | Time-bounded |
| `journalctl -p err` | Priority error and above |
| `journalctl -x` | Adds explanatory text and related messages |
| `journalctl --disk-usage` | How much space the journal uses |

```bash
journalctl -u sshd -n 5 --no-pager
journalctl -b -p err --no-pager | tail
journalctl --since "15 min ago" --no-pager | tail -20
```

### Is the journal persistent?

By default the journal may be **volatile**: it lives in `/run/log/journal` and disappears at reboot. If `/var/log/journal` exists, the journal is persistent. Check:

```bash
ls -d /var/log/journal 2>/dev/null || echo "journal is volatile"
journalctl --disk-usage
```

To make it persistent, create the directory and restart the service:

```bash
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal
sudo systemctl restart systemd-journald
```

The alternative is `Storage=persistent` in `/etc/systemd/journald.conf`. Either way, the trade-off is disk space. This matters on the exam when you need to investigate something that happened before a reboot.

### Traditional log files

RHEL-family systems may also have rsyslog writing plain files under `/var/log`:

| File | Content |
|---|---|
| `/var/log/messages` | General system messages |
| `/var/log/secure` | Authentication and sudo events |
| `/var/log/boot.log` | Boot-time messages |
| `/var/log/dnf.log` | Package transactions |
| `/var/log/audit/audit.log` | SELinux and audit events (F8, R10) |

```bash
ls /var/log
```

If those files are absent, rsyslog is not installed or not running, and the journal is your only source. The journal is authoritative either way; the files are a convenience.

### Writing a test entry

`logger` sends a message to the journal, which is useful for proving the pipeline works:

```bash
logger "F7 lab test message"
journalctl -n 5 --no-pager
```

## Lab: watch a service and a process

Log in to `server` and switch to the lab user:

```bash
sudo su - labuser
```

### 1. Confirm PID 1

```bash
ps -p 1 -o pid,comm,args
pstree -p | head
```

`systemd` is PID 1 and the root of the process tree. Every service you inspect is a descendant.

### 2. Inspect a service

```bash
systemctl status sshd --no-pager
systemctl is-active sshd
systemctl is-enabled sshd
systemctl cat sshd | head -15
```

Answer three questions before continuing: is it running now, will it start at boot, and which unit file is in use? Then look at the process:

```bash
pgrep -a sshd
systemctl show sshd -p MainPID
```

The main PID from `systemctl` should appear in `pgrep` output.

### 3. Read its logs

```bash
journalctl -u sshd -n 5 --no-pager
journalctl -u sshd --since "10 min ago" --no-pager
journalctl -x -u sshd -n 3 --no-pager
```

Now generate an event by opening a second SSH session from the host, or by making a failed login attempt from `server`:

```bash
ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=2 labuser@localhost true
journalctl -u sshd -n 5 --no-pager
```

The client prints `Permission denied (publickey,...)`: the lab key is configured for `server` and `node2`, not for `localhost`, so the attempt is refused. `journalctl` still records it, as a `Connection closed by authenticating user` line. A refused login is the event you wanted to see.

`StrictHostKeyChecking=accept-new` is there only so the first `localhost` connection does not stop at `Host key verification failed` before the login is ever attempted.

### 4. Find errors from this boot

```bash
journalctl -b -p err --no-pager | tail
systemctl --failed
```

On a clean boot both may be empty. Empty is a result, not a failure to follow instructions: it tells you there are no failed units and no error-priority messages since boot.

### 5. Write and find a log entry

```bash
logger "F7 lab test message"
journalctl --since "2 min ago" --no-pager | tail -5
```

You should see your message, tagged with the user and process that sent it.

### 6. Manage a background job

```bash
sleep 300 &
jobs
ps -ef | grep '[s]leep 300'
kill %1
jobs
```

The `[s]leep` pattern is a trick: the brackets stop `grep` from matching its own command line. `pgrep -af sleep` is cleaner.

Start another one and stop it with a signal:

```bash
sleep 300 &
pgrep -af 'sleep 300'
kill -TERM <PID>
```

### 7. Survey the running system

```bash
ps -eo pid,user,%cpu,%mem,comm --sort=-%cpu | head
systemctl list-units --type=service --state=running | head -15
systemctl list-timers --no-pager
```

You should recognize `sshd`, `systemd-journald`, and `NetworkManager`. Timers are the systemd replacement for many cron jobs; R8 covers them.

### 8. Check journal persistence

```bash
ls -d /var/log/journal 2>/dev/null || echo "journal is volatile"
journalctl --disk-usage
```

If the journal is volatile, reboot and compare `journalctl -b -1` before and after: after the reboot, `-b -1` may no longer exist. Do not reboot yet if you have unsaved lab work from earlier modules.

## Common traps

| Trap | What happens | Fix |
|---|---|---|
| `systemctl enable` without `start` | Nothing runs until reboot | `enable --now` |
| `systemctl start` without `enable` | Works until reboot, then fails the exam | Enable it and reboot |
| Editing a unit without `daemon-reload` | systemd keeps the old definition | `systemctl daemon-reload` |
| `kill -9` on a service | No cleanup; locks and sockets may be left behind | `systemctl stop` |
| Piping `ps aux` to `grep sshd` | The `grep` process matches itself | Use `pgrep -a` or `[s]shd` |
| Expecting logs to survive reboot | The journal may be volatile | Make `/var/log/journal` or set `Storage=persistent` |
| Reading only `/var/log/messages` | rsyslog may not be installed | Use `journalctl` |
| Assuming `active` means healthy | A service can be active and still failing requests | Read `status` and the journal |

## Self-check

Answer first, then open the answer.

### 1. Program and process

What is the difference between `/usr/sbin/sshd` and the `sshd` process with PID 812?

??? question "Answer"
    The path is a program file on disk. PID 812 is a running instance of it, with its own memory, open sockets, user, and parent. Starting the program again creates another process with a different PID.

### 2. PID 1

Why does the course use `systemctl` to manage services instead of running the daemon binary directly?

??? question "Answer"
    `systemd` is PID 1 and supervises units. Starting a daemon by hand bypasses its unit, so it is not tracked, not restarted on failure, and not started at boot. `systemctl` makes the service part of the system's managed state.

### 3. Start versus enable

A service is `active (running)` but `disabled`. What happens after a reboot, and how do you fix it?

??? question "Answer"
    It will not start after the reboot. Run `systemctl enable --now service` to enable it at boot and start it now, or `systemctl enable service` if it is already running.

### 4. Failed unit

Which command lists units that failed, and what do you read next?

??? question "Answer"
    `systemctl --failed` lists them. Then `systemctl status unit` and `journalctl -u unit -n 50` show the failure reason and recent log lines.

### 5. Signals

Why prefer `SIGTERM` over `SIGKILL`?

??? question "Answer"
    `SIGTERM` asks the process to shut down and lets it flush buffers, close files, and remove lock files. `SIGKILL` cannot be caught, so the process has no chance to clean up.

### 6. Job control

You start `sleep 300` with `&`. How do you find it, and how do you stop it?

??? question "Answer"
    `jobs` lists it with a job number, and `pgrep -af 'sleep 300'` finds the PID. Stop it with `kill %1` or `kill PID`. The shell only knows the job in the session where you started it.

### 7. Journal scope

What does `journalctl -u sshd -b -p err` select?

??? question "Answer"
    Entries from the `sshd` unit, from the current boot, at error priority or higher.

### 8. Persistence

You reboot and `journalctl -b -1` shows nothing from before the reboot. Why?

??? question "Answer"
    The journal was volatile and lived in `/run`, which is cleared at boot. Create `/var/log/journal` or set `Storage=persistent` to keep it.

### 9. States

A process shows state `D` and will not respond to `SIGKILL`. What does that mean?

??? question "Answer"
    The process is in uninterruptible sleep, usually waiting on I/O that is not completing. Signals, including `SIGKILL`, are not delivered until the kernel call returns, so the real problem is the storage or device underneath.

## Next

Continue to [F8 — Networking, storage, and SELinux foundations](../f8-networking-storage-selinux/index.md), the last foundations module. It maps the network, the disks, and the security layer that explains the permission errors ordinary bits cannot.
