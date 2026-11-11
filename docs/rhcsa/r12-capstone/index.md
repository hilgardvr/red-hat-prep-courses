# R12 — Capstone: mock exams and the full review

<div class="module-meta" markdown>

| | |
|---|---|
| **Exam objective groups** | All ten |
| **Time** | 2 hours for the rehearsal, 2 hours per mock exam |
| **Prerequisites** | R1–R11. This module teaches no new commands |
| **Labs** | 1 full-stack rehearsal, 1 diagnostic loop, 3 timed mock exams |
| **Check command** | `./bin/lab check r12 lab1` (also `lab2`, then `exama`, `examb`, `examc`) |

</div>

R1–R11 taught eleven domains. Each module ended with a checker that read one kind of state: files, accounts, block devices, timers, firewall rules, labels, boot entries. The exam does not work that way. It hands you a machine and a list of tasks, and every task lands on top of the last one. A wrong label breaks a web request; a missing firewall rule hides a working service; a forgotten `enable` survives until someone reboots.

The capstone is where the domains stop being separate topics and become one system. It adds no new syntax. It tests whether you can:

1. read a requirement and translate it into a change,
2. make that change **persistently**,
3. prove it from the place a client or the next boot will look,
4. and do all three in a fixed amount of time, without breaking what you already built.

If you can do that for every task in the three mock exams, you are ready. If you cannot, the failures tell you exactly which module to revisit.

## What EX200 actually asks

EX200 is a performance-based exam. There are no multiple-choice questions. You are given one or more running systems and a list of tasks, and you perform them live. Red Hat publishes the current duration, environment, and objectives on the [official EX200 page](https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam); check it before you book, because details change between releases.

Three properties of that format matter more than any single command:

- **The task is the end state, not the command.** If the requirement says "the service starts at boot", then `enable` is what makes it true, but the grader looks for the enabled unit. A running service that is disabled fails.
- **The tasks share a machine.** Storage you create in task 3 is what the web service in task 7 serves. Accounts you create in task 5 are what the sudo rule in task 9 names. A shortcut in one task becomes a mystery in another.
- **You are graded on what survives.** Many tasks are checked after a reboot. Anything held only in memory is worth zero.

The course has prepared you for the commands. The capstone prepares you for the **conditions**.

## The four persistence layers

Almost every "it works now but not after a reboot" failure in this course came from one of four places. Learn the layer, and the fix is obvious.

| Layer | Volatile form | Persistent form | Proof |
|---|---|---|---|
| Storage | `mount /dev/vg/lv /path` | a line in `/etc/fstab` | `findmnt --target /path` and `findmnt --fstab --target /path` |
| Services | `systemctl start unit` | `systemctl enable unit` | `systemctl is-enabled unit` |
| Firewall | `firewall-cmd --add-port=…` | the same with `--permanent`, then `--reload` | `firewall-cmd --permanent --query-port=…` |
| SELinux | `chcon -t …` | `semanage fcontext -a -t …` + `restorecon` | `semanage fcontext -l -C` |

Two more that behave the same way:

| Layer | Volatile form | Persistent form | Proof |
|---|---|---|---|
| Boot target | `systemctl isolate target` | `systemctl set-default target` | `systemctl get-default` |
| Kernel arguments | editing the line in GRUB | `grubby --update-kernel=ALL --args=…` | `grubby --info=ALL` and `/proc/cmdline` |

The right-hand column is the column the grader reads. Make it a habit: after every task, run the proof command before moving on. Two seconds of verification is cheaper than a failed task you have to find later.

## The verification habit

A performance exam rewards people who check their own work. These are the commands that answer "did it actually happen?", grouped by what they prove:

```bash
# Users and policy
id r12deploy
LC_ALL=C chage -l r12deploy
visudo -c
sudo -l -U r12deploy

# Storage
findmnt --target /srv/r12/www
findmnt --fstab --target /srv/r12/www
findmnt --verify
lvs

# Services and schedules
systemctl is-enabled httpd
systemctl is-active httpd
systemctl list-timers --all

# Network and firewall
ss -ltnH
firewall-cmd --zone=public --list-all
firewall-cmd --permanent --query-port=8088/tcp

# SELinux
ls -Z /srv/r12/www/index.html
semanage fcontext -l -C
semanage port -l -C
getenforce

# Boot
systemctl get-default
grubby --info=ALL | grep -E '^index|^args'
cat /proc/cmdline
```

And the one check no local command can replace: **ask the other machine**.

```bash
ssh labuser@node2 'curl -sS -m 5 http://10.10.10.10:8088/'
```

A service can be running, listening, and correctly labelled, and still be unreachable because the packet entered a zone you did not open. Only a client on the other side of the interface rules can tell you that.

## A time plan

Every timed exam has the same failure mode: three tasks finished beautifully, five untouched. Plan against it.

| Phase | Share of the time | What you do |
|---|---|---|
| Read | first 10% | Read every task. Mark the ones you can do without notes. Do not start yet |
| First pass | next 40% | Do the tasks you are confident about, fastest first. Verify each one as you finish |
| Second pass | next 30% | Do the rest. If a task resists for more than a few minutes, leave a note and move on |
| Persistence pass | next 10% | Go back over the four layers: fstab, enabled units, permanent firewall, SELinux records |
| Reboot and re-check | last 10% | Reboot if the exam allows it. Re-run every proof command. Fix what broke |

Two rules of thumb:

- **Do not debug the same task twice.** A task you abandon and return to later often looks obvious on the second read. A task you fight for twenty minutes costs three others.
- **Never leave the machine unbootable.** Firewall and SELinux mistakes are recoverable; a broken `/etc/fstab` or a removed default target is not, without a rescue boot. Test with `findmnt --verify` and `systemctl get-default` before you move on.

## The self-audit matrix

Work down this table before your first mock exam. For each row, if you cannot do the action **without notes**, revisit that module's challenge lab.

| Group | Module | Be able to do this without notes |
|---|---|---|
| 1 — Essential tools | R1 | Build a pipeline, find files by owner and permission, archive and extract a tree, explain a hard link versus a symlink |
| 2 — Manage software | R3 | Write a repository file, install and remove a package, query provenance, add a Flatpak remote |
| 3 — Shell scripts | R4 | Write a script that takes arguments, tests a file, loops over lines, and exits with a meaningful status |
| 4 — Operate running systems | R5, R11 | Write a unit, enable and mask it, read the journal, change the default target, interrupt a boot |
| 5 — Local storage | R6 | Partition a disk, build a PV, VG, and LV, format it, mount it by UUID, grow it |
| 6 — File systems | R7 | Mount VFAT with ownership options, export NFS and open the firewall, configure autofs, repair and grow ext4 |
| 7 — Deploy and maintain | R3, R8, R11 | Add a repo, schedule with cron and a timer, point chrony at a server, add a kernel argument, update the system |
| 8 — Networking | R9 | Build a static `nmcli` profile, add a hosts entry, open a port in the right zone, prove it from the peer |
| 9 — Users and groups | R2 | Create a user and group, set aging, write a sudo drop-in, set a umask that survives a login |
| 10 — Security | R10 | Map a path with `semanage fcontext`, label a port, set a Boolean persistently, install an SSH key, order an `sshd` drop-in |

If a row scares you, that is the module to redo. The capstone is a bad place to learn a command for the first time.

## How to use this module

| Page | What it is | Time |
|---|---|---|
| [Lab 1 — The full-stack rehearsal](labs/lab-1-rehearsal.md) | A guided build of one service host: storage, account, SELinux, web, firewall, timer, boot | ~2 hours |
| [Lab 2 — The diagnostic loop](labs/lab-2-diagnosis.md) | Three deliberate breakages, and the evidence that identifies each one | ~45 minutes |
| Mock exam A | Single machine, mixed domains | 2 hours |
| Mock exam B | Two machines, sharing and time | 2 hours |
| Mock exam C | Security, boot, and maintenance | 2 hours |

Do Lab 1 and Lab 2 first. They teach the shape of the work and the habit of reading a failure. Then take the exams **from a clean snapshot**, one at a time, with a clock running. Restore `clean` before each one:

```bash
cd labs
./bin/lab restore clean
./bin/lab up
```

A mock exam is only useful if you take it under exam conditions: no notes, no looking at the checker first, no "I will just check whether this is right" in the middle. Finish, grade it, and only then read the solution.

## Reading a failing check

The grader prints one line per requirement. A failure is a claim about the end state, not an insult. Treat it as the first clue in a short investigation:

1. **Read the line exactly.** "the permanent firewall allows 8088/tcp in public" tells you the layer, the zone, the port, and the protocol.
2. **Ask the layer, not the file.** `firewall-cmd --permanent --query-port=8088/tcp` is the answer. Reading `/etc/firewalld/zones/public.xml` only tells you what you hope is true.
3. **Collect the evidence the layer produces.** A denied request leaves a journal line and, for SELinux, an AVC. A refused connection leaves nothing locally, which is itself the clue that the packet never arrived.
4. **Fix the layer that refused.** A 403 with an AVC is SELinux; a 403 without one is a file mode or a missing `Require all granted`; a timeout is the firewall; a `curl: (7)` from the peer is usually the zone.
5. **Re-run the grader.** A repair you did not verify is a guess.

Lab 2 walks this loop three times, once per layer.

## What not to do

| Temptation | Why it fails |
|---|---|
| Disabling SELinux or firewalld to make a task pass | The grader reads `getenforce` and the zone; the task is the policy, not the symptom |
| Using `chcon` for a label you must keep | The next relabel reverts it; the record is what persists |
| Opening a port with `--add-port` and no `--permanent` | It works until `--reload` or a reboot |
| Leaving a service running but disabled | The reboot check fails |
| Editing `/boot/grub2/grub.cfg` by hand | The next `grub2-mkconfig` overwrites it; use `grubby` |
| Using `isolate` when the task says "at boot" | `get-default` does not change |
| Debugging one task for twenty minutes | Three easier tasks are worth more |
| Skipping the final reboot | The persistence pass is where most marks are lost |

## Next

Start with [Lab 1 — The full-stack rehearsal](labs/lab-1-rehearsal.md). It builds the machine that both the diagnostic lab and every mock exam assume you understand.
