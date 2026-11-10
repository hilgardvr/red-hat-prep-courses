# Challenge — The batch runner

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R5 — Processes and services |
| **Time** | 45–60 minutes |
| **Check** | `./bin/lab check r05 challenge` |
| **Style** | Exam task: requirements only, no steps |

</div>

This is the R5 challenge. It is written the way EX200 presents work: required behaviour, no walkthrough. Use the [theory page](../index.md), `man`, and your notes — but try it without a recipe first.

It assumes the machine from [Lab 1](lab-1-service.md) and [Lab 2](lab-2-journal-and-tuning.md). The batch service adds to that state; it must not undo it.

## Scenario

`server` collects build results around the clock. A colleague has been starting the collector by hand each morning, which is why a crashed collector goes unnoticed until the next day. You are asked to install it as a proper service that starts at boot, survives being killed, and stays out of the way of interactive work.

## Tasks

1. Write `/usr/local/bin/r5-batch`, an executable program that never exits. Every five seconds it must write one line to the journal with the tag `r5-batch` and a timestamp, for example:

   ```text
   batch tick 06:14:05
   ```

2. Create `r5-batch.service` so that:

   - it runs that program,
   - it has `Nice=5`,
   - it has `Restart=always`,
   - it is **enabled at boot** and **active now**.

3. Prove the restart works: kill the service's main process. Within ten seconds the unit must be `active` again with a **different** `MainPID`, without any command from you other than the kill.

4. The journal must hold at least one `r5-batch` line from the current boot.

5. Leave the earlier labs intact:

   - `r5-worker` is active, with nice 10 in the unit and in the process,
   - `r5-scratch` is still masked,
   - the journal is still stored under `/var/log/journal`,
   - `tuned`'s active profile is still `throughput-performance`.

6. Reboot `server`. Afterwards, without starting anything by hand:

   - `r5-batch` is active again,
   - the `r5-journal` marker from before the reboot is still readable,
   - everything in task 5 still holds.

## Hints

Only if you are stuck.

<details>
<summary>How do I write a line every five seconds?</summary>

The same loop as Lab 1, with `logger` instead of `echo`:

```bash
#!/bin/bash
while true; do
  logger -t r5-batch "batch tick $(date +%T)"
  sleep 5
done
```

`logger` tags the entry, so `journalctl -t r5-batch` finds it. `echo` would also reach the journal, but without a tag you can choose.

</details>

<details>
<summary>What makes systemd restart it?</summary>

```ini
[Service]
Restart=always
RestartSec=2
```

`Restart=always` restarts on any exit, including a signal. `RestartSec` is the delay; the default is 100 milliseconds, which is fine but hard to watch. `systemctl show -p Restart --value r5-batch` must print `always`.

</details>

<details>
<summary>How do I kill just the main process?</summary>

```bash
systemctl kill -s TERM --kill-whom=main r5-batch
```

or by PID:

```bash
kill -TERM "$(systemctl show -p MainPID --value r5-batch)"
```

Then watch the PID change:

```bash
systemctl show -p MainPID --value r5-batch
```

Do **not** use `systemctl stop`: that sets the unit to inactive on purpose, and `Restart=always` deliberately does not fight a manual stop.

</details>

<details>
<summary>Where does the program go?</summary>

`/usr/local/bin`. Lab 1 showed what happens when `ExecStart` points into `/srv`: `status=203/EXEC`, because the file is labelled `var_t` and systemd may only execute `bin_t`.

</details>

<details>
<summary>Why did my unit change do nothing?</summary>

`systemctl daemon-reload` after editing or creating a unit file. Then `systemctl restart r5-batch` to apply it to the running process.

</details>

## Verify

From the host:

```bash
./bin/lab check r05 challenge
```

The checker reads the unit, the process, and the journal, and then kills the service's main process to see whether it really comes back. A `Restart=always` that is only written down fails that check.

<details>
<summary>Show the expected check output</summary>

```text
R5 Challenge — The batch runner
  PASS  unit r5-batch.service is loaded
  PASS  r5-batch is enabled at boot
  PASS  r5-batch is active
  PASS  the unit sets Nice=5
  PASS  the running process has nice 5
  PASS  the unit sets Restart=always
  PASS  the journal holds r5-batch lines from this boot
  PASS  the persistent journal is still in use
  PASS  r5-worker is still active
  PASS  systemd restarts the service when its main process dies
```

</details>

## After the challenge

Nothing to undo. A service that is enabled, active, and logging is the end state the exam wants, and it is what `./bin/lab check r05 all` expects. If you want the machine exactly as the course assumes before starting R6:

```bash
./bin/lab restore clean
```
