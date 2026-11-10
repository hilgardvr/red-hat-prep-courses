# Lab 1 — A service that survives

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R5 — Processes and services |
| **Time** | 60–75 minutes |
| **Check** | `./bin/lab check r05 lab1` |
| **Skills** | unit files, `systemctl`, drop-ins, `daemon-reload`, `enable`, `mask`, `ps`, `renice`, `kill`, `journalctl -u` |

</div>

## What you are building

| Item | End state |
|---|---|
| `/usr/local/bin/r5-worker` | An executable program that prints one line every ten seconds |
| `/etc/systemd/system/r5-worker.service` | A unit that runs it, enabled at boot |
| `/etc/systemd/system/r5-worker.service.d/nice.conf` | A drop-in that sets `Nice=10` |
| `r5-worker.service` | Enabled **and** active, with nice 10 in the unit *and* in the process |
| `r5-scratch.service` | Masked, and impossible to start |

You will meet the two mistakes that cost the most time in this objective: an `ExecStart` that systemd is not allowed to execute, and a `daemon-reload` that was skipped. Both produce confusing errors, and both are easy to recognise once you have seen them.

## Before you begin

Start from the clean snapshot:

```bash
cd labs
./bin/lab restore clean
./bin/lab ssh
sudo -i
```

From here on, every command runs **inside the `server` VM** as root.

## Step 1 — A program that never exits

A service needs a program that keeps running. Create one that writes a heartbeat every ten seconds:

```bash
mkdir -p /srv/r5/bin
cat > /srv/r5/bin/worker <<'EOF'
#!/bin/bash
# worker — write a heartbeat to the journal every ten seconds.
while true; do
  echo "worker heartbeat $(date +%T)"
  sleep 10
done
EOF
chmod +x /srv/r5/bin/worker
timeout 3 /srv/r5/bin/worker; echo "exit=$?"
```

```text
worker heartbeat 05:47:04
exit=124
```

`timeout` stops it after three seconds, which is why the exit status is 124 rather than 0 — the command was still running when the limit was reached. That is exactly the behaviour a service needs: something that does not finish.

## Step 2 — Point a unit at it, and watch it fail

```bash
cat > /etc/systemd/system/r5-worker.service <<'EOF'
[Unit]
Description=R5 worker (heartbeat)

[Service]
ExecStart=/srv/r5/bin/worker

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl start r5-worker
systemctl status r5-worker --no-pager --lines=3
```

```text
× r5-worker.service - R5 worker (heartbeat)
     Loaded: loaded (/etc/systemd/system/r5-worker.service; disabled; preset: disabled)
     Active: failed (Result: exit-code) since Tue 2026-11-10 05:47:08 UTC; 7ms ago
   Duration: 9ms
 Invocation: 9be995c5b2dd441aaced10d0323b767d
    Process: 13617 ExecStart=/srv/r5/bin/worker (code=exited, status=203/EXEC)
   Main PID: 13617 (code=exited, status=203/EXEC)
   Mem peak: 1.2M
        CPU: 2ms

Nov 10 05:47:08 server (worker)[13617]: r5-worker.service: Failed at step EXEC spawning /srv/r5/bin/worker: Permission denied
Nov 10 05:47:08 server systemd[1]: r5-worker.service: Main process exited, code=exited, status=203/EXEC
Nov 10 05:47:08 server systemd[1]: r5-worker.service: Failed with result 'exit-code'.
```

"Permission denied" for a file that is executable and runs two minutes earlier is the confusing part. The real reason is the **label**, not the path:

```bash
ls -Z /srv/r5/bin/worker
ls -Zd /usr/local/bin
```

```text
unconfined_u:object_r:var_t:s0 /srv/r5/bin/worker
system_u:object_r:bin_t:s0 /usr/local/bin
```

SELinux labels `/srv` as `var_t` (variable data) and `/usr/local/bin` as `bin_t` (executable programs). systemd runs as `init_t`, which may execute `bin_t` but not `var_t`. Your interactive root shell is `unconfined_t`, which may run both — that is why the script worked when you ran it by hand and fails when systemd tries.

`status=203/EXEC` means "the exec call failed". When a program demonstrably runs, look at `ls -Z` before you look at the path.

## Step 3 — Put the program where systemd can execute it

```bash
install -m 0755 /srv/r5/bin/worker /usr/local/bin/r5-worker
ls -Z /usr/local/bin/r5-worker
rm -rf /srv/r5
```

```text
system_u:object_r:bin_t:s0 /usr/local/bin/r5-worker
```

`install` copies the file and sets the mode in one step. The copy is labelled `bin_t` because of where it was created. Remove the original: two copies of a program that is being edited is how versions drift.

Now point the unit at the new location:

```bash
vim /etc/systemd/system/r5-worker.service
```

The file must read:

```ini
[Unit]
Description=R5 worker (heartbeat)

[Service]
ExecStart=/usr/local/bin/r5-worker

[Install]
WantedBy=multi-user.target
```

```bash
systemctl daemon-reload
systemctl start r5-worker
systemctl is-active r5-worker
```

```text
active
```

`daemon-reload` is not optional. systemd copied the unit into memory when it first loaded it; without the reload it would keep failing on the old `ExecStart` and you would think the edit had not saved.

## Step 4 — A drop-in for the nice value

The unit works. Now make it yield CPU to everything else, without editing the unit itself:

```bash
mkdir -p /etc/systemd/system/r5-worker.service.d
cat > /etc/systemd/system/r5-worker.service.d/nice.conf <<'EOF'
[Service]
Nice=10
EOF
systemctl daemon-reload
systemctl enable --now r5-worker
systemctl restart r5-worker
```

The `restart` is what applies the new value to the running process: `enable --now` starts a stopped unit, but `start` on an already-active one does nothing.

```bash
systemctl status r5-worker --no-pager --lines=2
```

```text
● r5-worker.service - R5 worker (heartbeat)
     Loaded: loaded (/etc/systemd/system/r5-worker.service; enabled; preset: disabled)
    Drop-In: /etc/systemd/system/r5-worker.service.d
             └─nice.conf
     Active: active (running) since Tue 2026-11-10 05:47:08 UTC; 8ms ago
 Invocation: 47498a6914f7488b83832e9b8c2bb56c
   Main PID: 13779 (r5-worker)
      Tasks: 1 (limit: 24625)
     Memory: 100K (peak: 1.2M)
        CPU: 2ms
     CGroup: /system.slice/r5-worker.service
             └─13779 /bin/bash /usr/local/bin/r5-worker

Nov 10 05:47:08 server systemd[1]: Started r5-worker.service - R5 worker (heartbeat).
```

Only one journal line and one process so far, because the unit restarted eight milliseconds earlier: the heartbeat and its `sleep 10` child appear a moment later. Compare this with the same block after the reboot in Step 9, where both are present.

Two checks, because the unit file and the process can disagree:

```bash
systemctl is-enabled r5-worker
systemctl show -p Nice --value r5-worker
pid=$(systemctl show -p MainPID --value r5-worker)
ps -o pid,ni,comm -p "$pid"
```

```text
enabled
10
    PID  NI COMMAND
  13779  10 r5-worker
```

The unit says 10 and the process really has 10. If you had skipped the `restart`, `show` would already report 10 (it reads the configuration) while the running process still had 0 (it started before the change). **Always read the process, not just the unit, when nice matters.**

## Step 5 — Read the unit's output in the journal

Everything the service prints on stdout goes to the journal, tagged with the unit and its PID:

```bash
journalctl -u r5-worker -n 3 --no-pager
```

```text
Nov 10 05:47:08 server systemd[1]: Stopped r5-worker.service - R5 worker (heartbeat).
Nov 10 05:47:08 server systemd[1]: Started r5-worker.service - R5 worker (heartbeat).
Nov 10 05:47:08 server r5-worker[13779]: worker heartbeat 05:47:08
```

Follow it live with `-f` and stop with Ctrl-C:

```bash
journalctl -u r5-worker -f
```

This is the loop you will use for every service problem: `systemctl status` for the state, `journalctl -u` for the story.

## Step 6 — Change a priority by hand

`Nice=` in a unit is not the only way to set a nice value. Start a long sleep, look at it, and renice it:

```bash
nice -n 5 sleep 300 &
```

```text
[1] 13789
```

```bash
ps -o pid,ni,comm -p 13789
renice -n 15 -p 13789
ps -o pid,ni,comm -p 13789
kill -TERM 13789
```

```text
    PID  NI COMMAND
  13789   5 sleep
13789 (process ID) old priority 5, new priority 15
    PID  NI COMMAND
  13789  15 sleep
```

Your PID will differ. `ps` reports nice in the `NI` column, `renice` prints the old and new values, and `kill -TERM` ends it politely. A process that ignores `SIGTERM` would need `kill -9`, but try the polite one first.

## Step 7 — Kill the service, and watch systemd react

The service is a process with a parent that cares. Kill the main process politely:

```bash
pid=$(systemctl show -p MainPID --value r5-worker)
kill -TERM "$pid"
sleep 2
systemctl is-active r5-worker
systemctl status r5-worker --no-pager --lines=3
```

```text
inactive
○ r5-worker.service - R5 worker (heartbeat)
     Loaded: loaded (/etc/systemd/system/r5-worker.service; enabled; preset: disabled)
    Drop-In: /etc/systemd/system/r5-worker.service.d
             └─nice.conf
     Active: inactive (dead) since Tue 2026-11-10 05:47:08 UTC; 2s ago
   Duration: 60ms
 Invocation: 47498a6914f7488b83832e9b8c2bb56c
    Process: 13779 ExecStart=/usr/local/bin/r5-worker (code=killed, signal=TERM)
   Main PID: 13779 (code=killed, signal=TERM)
   Mem peak: 1.2M
        CPU: 5ms

Nov 10 05:47:08 server systemd[1]: Started r5-worker.service - R5 worker (heartbeat).
Nov 10 05:47:08 server r5-worker[13779]: worker heartbeat 05:47:08
Nov 10 05:47:08 server systemd[1]: r5-worker.service: Deactivated successfully.
```

`SIGTERM` is a **clean** exit as far as systemd is concerned, so the unit is `inactive (dead)`, not `failed`, and "Deactivated successfully" says so. Now do it the rude way:

```bash
systemctl restart r5-worker
pid=$(systemctl show -p MainPID --value r5-worker)
kill -9 "$pid"
sleep 2
systemctl is-active r5-worker
```

```text
failed
```

`SIGKILL` is not a clean exit, so systemd marks the unit `failed` (`Result: signal`) and `systemctl --failed` would list it. Either way, **nothing brought the service back**: with no `Restart=` setting, systemd records what happened and waits for a human.

```bash
systemctl restart r5-worker
systemctl is-active r5-worker
```

```text
active
```

The [challenge](challenge-batch-runner.md) adds `Restart=always`, which is the setting that makes systemd do this on its own — for both of the exits above, but not for a deliberate `systemctl stop`.

## Step 8 — Mask a unit for good

Sometimes the requirement is the opposite: a service that must never run, not even when something else asks for it. Build one, run it once, then take it away:

```bash
cat > /etc/systemd/system/r5-scratch.service <<'EOF'
[Unit]
Description=R5 scratch unit

[Service]
ExecStart=/bin/true
EOF
systemctl daemon-reload
systemctl start r5-scratch
systemctl is-active r5-scratch; echo "exit=$?"
```

```text
inactive
exit=3
```

`/bin/true` exits immediately, so a `Type=simple` unit has nothing left to watch: it started, it finished, it is inactive. Now stop it properly, remove the file, and mask the name:

```bash
systemctl stop r5-scratch
rm /etc/systemd/system/r5-scratch.service
systemctl daemon-reload
systemctl mask r5-scratch
```

```text
Unit r5-scratch.service does not exist, proceeding anyway.
Created symlink '/etc/systemd/system/r5-scratch.service' → '/dev/null'.
```

```bash
systemctl is-enabled r5-scratch; echo "exit=$?"
systemctl start r5-scratch; echo "exit=$?"
```

```text
masked
exit=1
Failed to start r5-scratch.service: Unit r5-scratch.service is masked.
exit=1
```

The unit file is gone, yet the name is still blocked, because the mask is its own symlink at that path. `mask` refuses while a real unit file is in the way — that is the `Failed to mask unit: File ... already exists` error, and the fix is the sequence above: disable, remove, reload, mask.

## Step 9 — Reboot and prove it

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
systemctl is-enabled r5-worker
systemctl is-active r5-worker
systemctl show -p Nice --value r5-worker
pid=$(systemctl show -p MainPID --value r5-worker)
ps -o pid,ni,comm -p "$pid"
systemctl is-enabled r5-scratch
journalctl -u r5-worker -n 2 --no-pager
```

```text
enabled
active
10
    PID  NI COMMAND
    705  10 r5-worker
masked
Nov 10 18:38:34 server r5-worker[705]: worker heartbeat 18:38:34
Nov 10 18:38:44 server r5-worker[705]: worker heartbeat 18:38:44
```

The PID changed — 13779 became 705 — because a reboot starts a new process. Everything else is identical, which is the point: the unit file, the drop-in, and the enable symlink are all on disk, so systemd rebuilt the service from them.

## Step 10 — Run the checker

```bash
./bin/lab check r05 lab1
```

The checker asks systemd for the state, then asks the kernel for the process's real nice value. It also tries to start the masked unit and expects the failure.

<details>
<summary>Show the expected check output</summary>

```text
R5 Lab 1 — A service that survives
  PASS  unit r5-worker.service is loaded
  PASS  r5-worker is enabled at boot
  PASS  r5-worker is active
  PASS  the unit sets Nice=10
  PASS  the running process has nice 10
  PASS  ExecStart points at /usr/local/bin/r5-worker
  PASS  the nice drop-in is loaded
  PASS  the journal shows the worker's output
  PASS  r5-scratch is masked
  PASS  the masked unit refuses to start
```

</details>

## If something fails

| Symptom | Cause |
|---|---|
| `status=203/EXEC` and the script runs by hand | The program is under `/srv` (`var_t`): move it to `/usr/local/bin` |
| Edit had no effect | `systemctl daemon-reload` was skipped |
| `Nice` is 10 in `show` but 0 in `ps` | The service started before the drop-in: `systemctl restart` |
| `Unknown command verb ccomm` | Typo in `ps -o`: use `comm` |
| `is-enabled` says `disabled` | `enable --now` was never run, or it was run on the wrong unit |
| `Failed to mask unit: File ... already exists` | The unit file is in `/etc/systemd/system`: remove it first |
| Service is not running after a reboot | It was started but never enabled: use `systemctl enable --now` |

## What to remember

- `start` is now, `enable` is at boot, `mask` is never.
- Edit a unit, then `daemon-reload`; restart to apply it to the running process.
- A drop-in changes part of a unit and leaves the original file alone.
- A program systemd runs belongs in `/usr/local/bin`, not `/srv`.
- `ps -o ni` reads the process; `systemctl show -p Nice` reads the configuration.
- `SIGTERM` leaves the unit `inactive`; `SIGKILL` leaves it `failed`. `Restart=` is what brings it back.
