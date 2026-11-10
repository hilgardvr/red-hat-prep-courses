# How to use this course

This course is built for people who want to **do the job**, not just pass a quiz. The exam is performance-based, so the course is lab-first: every concept is followed by a task you perform on a live system.

## Who this is for

- You are new to Linux, or you have used it casually but never administered a system.
- You can use a text editor and a terminal, but you do not need previous RHEL experience.
- You want to earn RHCSA and understand what you are doing, not memorize a command list.

If you already administer Linux daily, you can skip most of the foundations and start with [R1 — Essential tools](../rhcsa/r01-essential-tools/index.md), then continue to [R2 — Users and groups](../rhcsa/r02-users-and-groups/index.md). Read [F2 — The lab](../foundations/f2-lab-first-login/index.md) first anyway: it covers this course's lab — the two virtual machines, snapshots, and the `./bin/lab` workflow — which is course logistics rather than Linux knowledge, and no later module repeats it in full. If you are new to Linux, work through [Foundations](../foundations/index.md) in order. The [objective coverage matrix](../reference/objective-coverage.md) shows exactly where each exam bullet is taught.

## The module pattern

Every module has the same parts:

| Part | Purpose |
|---|---|
| **Theory** | The mental model, the commands, and the "why" |
| **Lab 1 and Lab 2** | Guided practice with expected output |
| **Challenge** | An exam-style task with no steps |
| **Persistence test** | Reboot and prove the configuration survives |
| **Check script** | Automated PASS/FAIL verification of the end state |
| **Knowledge check** | Questions with hidden answers |
| **Cheat sheet** | A compact reference for review |

## The lab workflow

The labs run on two disposable virtual machines. You will need the lab kit from the repository; the [lab setup guide](lab-setup.md) walks through it.

```bash
cd labs
./bin/lab doctor          # verify the host
./bin/lab up              # create server and node2
./bin/lab snapshot clean  # save a clean state
./bin/lab ssh             # log in to server
```

Before each lab, restore the clean snapshot so you start from a known state — unless the module says the next lab builds on the previous one:

```bash
./bin/lab restore clean
```

After completing the lab, run the checker **from the host**:

```bash
./bin/lab check r01 lab1
```

The checker runs inside `server` as root and reports each criterion:

```text
R1 Lab 1 — Files and links
  PASS  directory: /srv/r1/project/docs
  PASS  hard link shares an inode with docs/readme.txt
  FAIL  symlink readme-softlink -> docs/readme.txt
```

Fix the failing items and run it again. A lab is complete when every line passes.

!!! tip "Reboot inside the VM, then check again"
    For any task that changes system configuration, reboot `server` **from inside your SSH session** with `sudo systemctl reboot`, then reconnect from the host and run the checker. This is the single most common way candidates lose points on EX200.

    When the VM reboots your session drops. Wait 30–60 seconds, then from the host run `./bin/lab status` followed by `./bin/lab ssh`. Run the checker **before** you restore the snapshot, or you will throw away the work you are trying to verify. The full sequence is in [F2 — The lab workflow](../foundations/f2-lab-first-login/index.md#the-lab-workflow).

## The persistence rule

Red Hat states that configurations must persist after a reboot without intervention. That means:

- A mount is not configured until it is in `/etc/fstab` (or a systemd mount unit) **and** you have tested a reboot.
- A service is not enabled until `systemctl is-enabled` says `enabled`.
- A firewall rule is not permanent until it is in the permanent configuration.
- An SELinux change is not complete until it survives a relabel or reboot.

Every module repeats this rule in context. Treat "it worked until I rebooted" as a fail.

## Suggested pace

| Plan | Time | Best for |
|---|---|---|
| **12 weeks** | 5–7 hours per week | Complete beginners, alongside a job or study |
| **6 weeks** | 10–12 hours per week | Some Linux experience, focused schedule |
| **2 weeks** | 25–30 hours per week | Experienced admins refreshing for the exam |

See [study plans](study-plans.md) for a week-by-week breakdown.

## A good study session

1. **Review** the previous module's cheat sheet for five minutes.
2. **Read** the theory section once without typing.
3. **Work** the guided labs with the theory page open.
4. **Close the book** and attempt the challenge lab.
5. **Reboot** and run the checker.
6. **Write down** the two or three commands or concepts that slowed you down.

The last step matters more than rereading. The exam rewards recall and troubleshooting, not recognition.

## When you get stuck

1. Read the error message literally. Most Linux errors name the file, permission, or unit involved.
2. Use the help system: `man <command>`, `<command> --help`, `man -k <keyword>`.
3. Check the logs: `journalctl -xe`, `systemctl status <unit>`.
4. Inspect state: `ls -l`, `stat`, `id`, `namei -l`, `ss -tulpn`, `firewall-cmd --list-all`.
5. Only then look at the hints in the lab page.

The exam has no internet access, so build the habit of solving problems with the documentation that ships on the system. The R1 module teaches exactly that.

## A note on copying commands

Copying a command from this page is fine while learning. On the exam you will not have this page. After each guided lab, close the tab and repeat the key steps from memory. If you cannot, you have found the thing to practice.

## Next steps

- Read the [exam overview](exam-overview.md) so you know what you are preparing for.
- Pick a [study plan](study-plans.md).
- Set up the [lab](lab-setup.md).
- Start with the [Foundations overview](../foundations/index.md), or jump to [R1 — Essential tools](../rhcsa/r01-essential-tools/index.md) if you already know your way around a shell. [R2 — Users and groups](../rhcsa/r02-users-and-groups/index.md) follows R1.
