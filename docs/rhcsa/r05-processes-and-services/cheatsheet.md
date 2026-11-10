# R5 cheat sheet

A compact reference for review. Everything here is explained in the [theory page](index.md).

## Processes

| Task | Command |
|---|---|
| Your processes | `ps` |
| Everything, with CPU and memory | `ps aux` |
| Everything, with UID and full command | `ps -ef` |
| Choose the columns | `ps -o pid,ppid,ni,stat,comm` |
| Busiest first | `ps -eo pid,pcpu,comm --sort=-pcpu \| head` |
| One process in detail | `ps -p 1234 -o pid,etime,args` |
| Find by name | `pgrep -a sshd` |
| Find by command line | `pgrep -af 'worker heartbeat'` |
| Live view | `top` (`P` CPU, `M` memory, `k` kill, `r` renice, `q` quit) |

States: `R` running, `S` sleeping, `D` I/O wait, `T` stopped, `Z` zombie, `I` idle.

## Signals

| Signal | No. | Use |
|---|---|---|
| `SIGHUP` | 1 | Reload configuration |
| `SIGINT` | 2 | Ctrl-C |
| `SIGKILL` | 9 | Cannot be caught — last resort |
| `SIGTERM` | 15 | Default, polite exit |
| `SIGSTOP` / `SIGCONT` | 19 / 18 | Pause / resume |

```bash
kill -TERM 1234          # or: kill 1234
kill -9 1234             # only after TERM failed
pkill -TERM worker       # by name
pkill -f 'r5-worker'     # by command line (check with pgrep -af first)
killall sleep
kill -l                  # list every signal
```

## Nice

| Task | Command |
|---|---|
| Start with a nice value | `nice -n 10 command` |
| Change a running process | `renice -n 10 -p PID` |
| Read it | `ps -o pid,ni,comm -p PID` |
| Read a service's process | `ps -o ni= -p $(systemctl show -p MainPID --value foo)` |

Range **-20** (highest priority) to **19** (lowest), default **0**. Only root may lower the number.

## systemd units

| Task | Command |
|---|---|
| Start / stop / restart | `systemctl start foo` / `stop` / `restart` |
| Start now and at boot | `systemctl enable --now foo` |
| Enable / disable | `systemctl enable foo` / `disable foo` |
| Block completely / unblock | `systemctl mask foo` / `unmask foo` |
| State, for scripts | `systemctl is-active foo`, `systemctl is-enabled foo` |
| Full state | `systemctl show foo`, `systemctl show -p Nice --value foo` |
| Unit plus drop-ins | `systemctl cat foo` |
| Re-read unit files | `systemctl daemon-reload` |
| Loaded units / installed files | `systemctl list-units --type=service`, `systemctl list-unit-files` |
| Failures | `systemctl --failed` |
| Signal one process | `systemctl kill -s TERM --kill-whom=main foo` |
| Journal for one unit | `journalctl -u foo` |

`start` = now. `enable` = at boot (a symlink in `multi-user.target.wants/`). `mask` = never (a symlink to `/dev/null`).

## A unit file

```ini
[Unit]
Description=What it is
After=network.target

[Service]
ExecStart=/usr/local/bin/program
Restart=always
RestartSec=2
Nice=10

[Install]
WantedBy=multi-user.target
```

| Directory | Purpose |
|---|---|
| `/usr/lib/systemd/system/` | Vendor units, replaced by package updates |
| `/etc/systemd/system/` | Your units and drop-ins |
| `/run/systemd/system/` | Transient |

Drop-in: `/etc/systemd/system/foo.service.d/10-something.conf` with only the section and keys you change.

**After creating, editing, or deleting a unit or drop-in: `systemctl daemon-reload`.**

## When a service will not start

| Symptom | Look at |
|---|---|
| `status=203/EXEC` | The program's path and its SELinux label (`ls -Z`). `/srv` is `var_t`; use `/usr/local/bin` |
| `status=1` or other exit code | The program's own error: `journalctl -u foo -n 30` |
| Change had no effect | `daemon-reload`, then `restart` |
| `Unit ... is masked` | `systemctl unmask foo` |
| `Unit ... not found` | File name and directory: `/etc/systemd/system/foo.service` |
| Unit file changed on disk | Run `systemctl daemon-reload` |

## Journal

| Task | Command |
|---|---|
| Everything, this boot | `journalctl -b` |
| Previous boot | `journalctl -b -1` |
| List boots | `journalctl --list-boots` |
| One unit | `journalctl -u foo` |
| One tag | `journalctl -t mytag` |
| Errors and worse | `journalctl -p err` |
| Since a time | `journalctl --since "10 min ago"` |
| Follow | `journalctl -f` |
| Last N | `journalctl -n 50` |
| Machine-readable | `journalctl -o json` |
| Disk use | `journalctl --disk-usage` |
| Reclaim space | `journalctl --rotate`, then `journalctl --vacuum-size=100M` |

| Storage | Directory | Survives reboot |
|---|---|---|
| Volatile | `/run/log/journal` | No |
| Persistent | `/var/log/journal` | Yes |

Make it persistent:

```bash
mkdir -p /var/log/journal
systemctl restart systemd-journald
journalctl --flush
```

Cap it:

```ini
# /etc/systemd/journald.conf.d/10-size.conf
[Journal]
SystemMaxUse=100M
```

```bash
systemctl restart systemd-journald
systemd-analyze cat-config systemd/journald.conf   # the merged result
```

Priorities: `emerg` 0, `alert` 1, `crit` 2, `err` 3, `warning` 4, `notice` 5, `info` 6, `debug` 7.

## tuned

| Task | Command |
|---|---|
| Active profile | `tuned-adm active` |
| Available profiles | `tuned-adm list` |
| Recommendation | `tuned-adm recommend` |
| Switch | `tuned-adm profile throughput-performance` |
| Disable tuning | `tuned-adm off` |
| Is the daemon enabled? | `systemctl is-enabled tuned` |

Stored in `/etc/tuned/active_profile`; `tuned` re-applies it at boot.

## What survives a reboot

| Survives | Does not survive |
|---|---|
| Unit files and drop-ins | The process |
| The `enable` symlink | A manual `renice` |
| The `mask` symlink | A started-but-not-enabled service |
| `/var/log/journal` and its files | A volatile journal |
| `/etc/tuned/active_profile` | — |

Check after every reboot:

```bash
systemctl is-enabled foo
systemctl is-active foo
systemctl show -p Nice --value foo
journalctl -u foo -n 5
tuned-adm active
```
