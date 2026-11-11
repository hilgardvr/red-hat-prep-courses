# Challenge — Update the system and harden the boot

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R11 — Boot, rescue, and updates |
| **Time** | 45–60 minutes, plus download time |
| **Check** | `./bin/lab check r11 challenge` |
| **Style** | Exam task: requirements only, no steps |

</div>

This is the R11 challenge. It is written the way EX200 presents work: required behaviour, no walkthrough. Use the [theory page](../index.md), `man`, and your notes — but try it without a recipe first.

It assumes the machine from [Lab 1](lab-1-targets-and-grub.md) and [Lab 2](lab-2-recovery.md). The new work is added beside that state and must not undo it.

This challenge needs a working repository and internet access. It downloads a full set of updates, which can take several minutes.

## Scenario

`server` has been recovered and is running again. Before it goes back into service it needs its pending security updates, and it needs a boot configuration that behaves like a server: it should come up headless, survive a kernel panic, and reboot when the kernel hits a warning it cannot recover from.

Lab 1 already returned the machine to `multi-user.target` after its graphical round-trip. That is the production setting, and the challenge requires it to stay that way.

## Tasks

1. Keep the Lab 1 boot configuration:
   - `GRUB_TIMEOUT=10`,
   - `menu_auto_hide=0`,
   - `panic=10` on **every** installed kernel,
   - and `panic=10` in the running kernel's `/proc/cmdline`.

2. Update the system:
   - apply all available package updates,
   - leave no updates pending,
   - and run the newest installed kernel.

3. Add a second persistent kernel argument:
   - `panic_on_warn=1` on **every** installed kernel,
   - it must be in the running kernel's `/proc/cmdline`,
   - and the live setting `kernel.panic_on_warn` must be `1`.

4. Keep the machine on a headless default:
   - `systemctl get-default` must still say `multi-user.target`,
   - and the setting must be persistent, not a runtime `isolate`.

5. Keep the Lab 2 recovery intact:
   - root is still unlocked and usable,
   - `/root/r11-recovered` still carries `admin_home_t`,
   - `/.autorelabel` is still absent,
   - SELinux is still enforcing.

6. Everything above survives a reboot.

## What the checker proves

```text { .no-copy }
R11 Challenge — Update the system and harden the boot
  PASS  a full package update completed successfully
  PASS  dnf finds no updates left to install
  PASS  the running kernel is the newest installed kernel
  PASS  every installed kernel carries panic_on_warn=1
  PASS  the running kernel received panic_on_warn=1 (needs a reboot)
  PASS  the kernel applied panic_on_warn
  PASS  panic=10 is still on every installed kernel
  PASS  the running kernel still has panic=10
  PASS  the system now boots into multi-user.target by default
  PASS  GRUB_TIMEOUT is still 10 seconds
  PASS  root is still unlocked
  PASS  the recovery marker is still labelled admin_home_t
  PASS  the relabel marker is still absent
```

The update check is deliberately two-sided. `dnf history` records that a transaction ran and what its return code was; `dnf check-update` proves that nothing is left. Either one alone is easy to satisfy by accident — a successful no-op, or a pending update you never applied.

The kernel argument is checked in three places because it can be true in one and false in another: the BLS entries (intent), `/proc/cmdline` (this boot), and `/proc/sys/kernel/panic_on_warn` (the effect). The second and third fail until you reboot.

## Hints, in the order you will need them

??? hint "The repositories may be off"
    R3 teaches you to disable the distro repositories by hand. If you did, `dnf upgrade` has nothing to work with and says so. Re-enable them before starting. This module needs a real repository.

??? hint "`check-update` exit 100 is not an error"
    `dnf check-update` exits `100` when updates are available, `0` when there are none, and `1` when the check itself failed. A non-zero exit from the first run is the expected state, not a broken repository.

??? hint "Update first, then change the kernel arguments"
    If the update installs a new kernel, it creates a new BLS entry. Run `grubby --update-kernel=ALL --args=panic_on_warn=1` **after** `dnf upgrade` so the new entry gets the argument too. `--update-kernel=ALL` is not a one-time snapshot; it is the instruction to touch every entry that exists now.

??? hint "`panic=10` and `panic_on_warn=1` are a pair"
    `panic=10` says "reboot ten seconds after a panic". `panic_on_warn=1` says "treat a kernel warning as a panic". Without the second, a `WARN()` leaves the machine running in a damaged state; without the first, it stops at the panic. The challenge keeps both.

??? hint "`panic_on_oops` is already 1 on this image"
    Do not copy a blog post that adds `panic_on_oops=1` and expect the checker to see a change. On this image it is already `1` by default, so the visible, verifiable argument is `panic_on_warn=1`.

??? hint "The reboot is part of the task"
    A kernel argument is a promise about the next boot. `grubby --info=ALL` can show the argument while `/proc/cmdline` and the live sysctl still show the old boot. Run the checker before the reboot if you like; three lines will fail, and they are the persistence test.

??? hint "The running kernel is not the newest installed kernel until you reboot"
    `uname -r` reports the running kernel; `rpm -q --last kernel-core` reports what is installed. After a kernel update they disagree until the reboot. That is normal, and it is why the check is written the way it is.

??? hint "Do not undo Lab 1 or Lab 2 to pass the challenge"
    The challenge asks for the new state **and** the old state. Deleting the `panic=10` argument, resetting the timeout, or relocking root to "start clean" fails the regression checks.

??? hint "Set the default target, do not isolate it"
    `systemctl isolate multi-user.target` changes the running system and is undone by the reboot. `systemctl set-default multi-user.target` rewrites `/etc/systemd/system/default.target`. The checker reads the default, not the active target.

??? hint "If the update check fails, read the history"
    `dnf history` shows whether a transaction ran and whether it succeeded. A transaction that failed halfway leaves the system in a state `dnf check-update` will still report as pending. Fix the cause and run `dnf -y upgrade` again; do not delete the history entry.

## When you are done

```bash
cd labs
./bin/lab check r11 all
```

`all` runs the three phases in order: Lab 1, Lab 2, then this challenge. It expects the challenge end state, which includes everything both labs created. If you restored a snapshot between labs, run the individual checks instead. The challenge's update and reboot can take several minutes; the checker's `dnf check-update` contacts the repositories, so give it time.

## Next

[R11 knowledge check](../quiz.md) and the [cheat sheet](../cheatsheet.md) close the module.
