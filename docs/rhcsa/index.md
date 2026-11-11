# RHCSA course roadmap

The course is organized around the ten objective groups Red Hat publishes for EX200. Each module teaches the theory behind the group, then makes you perform the work on the lab systems.

## Modules

| Module | Focus | Exam objective group | Status |
|---|---|---|---|
| **R1** | Essential tools: shell, help, files, links, permissions, streams, grep, archives, SSH | 1 — Understand and use essential tools | <span class="badge badge-ready">Available</span> |
| **R2** | Users, groups, password aging, sudo, default permissions | 9 — Users and groups; part of 10 | <span class="badge badge-ready">Available</span> |
| **R3** | Software: DNF, RPM repositories, Flatpak | 2 — Manage software | <span class="badge badge-ready">Available</span> |
| **R4** | Shell scripting: arguments, conditionals, loops, command substitution | 3 — Create simple shell scripts | <span class="badge badge-ready">Available</span> |
| **R5** | Processes, systemd services, journald, tuned | 4 — Operate running systems | <span class="badge badge-ready">Available</span> |
| **R6** | GPT partitions, LVM, swap, fstab by UUID/label | 5 — Configure local storage | <span class="badge badge-ready">Available</span> |
| **R7** | VFAT, NFS, autofs, filesystem repair and resize | 6 — Create and configure file systems | <span class="badge badge-ready">Available</span> |
| **R8** | cron, at, systemd timers, chrony | 7 — Deploy, configure, and maintain systems | <span class="badge badge-ready">Available</span> |
| **R9** | nmcli, IPv4/IPv6, hostname resolution, firewalld | 8 — Manage basic networking | <span class="badge badge-ready">Available</span> |
| **R10** | SELinux, SSH key authentication, firewall hardening | 10 — Manage security | <span class="badge badge-ready">Available</span> |
| **R11** | Boot targets, GRUB, rescue, rd.break, updates | 4 + 7 | <span class="badge badge-ready">Available</span> |
| **R12** | Capstone: timed mock exams and full review | All | <span class="badge badge-planned">Planned</span> |

## How the modules fit together

```mermaid
flowchart LR
    F[Foundations] --> R1[R1 Essential tools]
    R1 --> R2[R2 Users & groups]
    R2 --> R3[R3 Software]
    R3 --> R4[R4 Scripting]
    R4 --> R5[R5 Services & logs]
    R5 --> R6[R6 Storage & LVM]
    R6 --> R7[R7 Filesystems]
    R7 --> R8[R8 Scheduling & time]
    R8 --> R9[R9 Networking]
    R9 --> R10[R10 Security]
    R10 --> R11[R11 Boot & recovery]
    R11 --> R12[R12 Capstone]
```

The order is pedagogical, not mandatory. Storage depends on users and permissions; networking depends on services; security depends on both. If you already know a domain, attempt its challenge lab first and study only what you fail.

## What every module contains

- **Theory** with diagrams and the "why".
- **Two guided labs** with explained commands and expected output.
- **A challenge lab** written like an exam task, with no steps.
- **A persistence test** that requires a reboot.
- **An automated checker** that verifies the end state.
- **A knowledge check** and a **cheat sheet**.

## Start with R1, then work through R2–R10

[R1 — Essential tools](r01-essential-tools/index.md) is the best place to begin. It covers the largest objective group and establishes the lab workflow that every later module uses. Once it passes its checker, continue with [R2 — Users and groups](r02-users-and-groups/index.md), which turns the permission model from R1 into real accounts, policy, and privileged access, then with [R3 — Software and repositories](r03-software-and-repositories/index.md), which is where the exam's no-internet condition first matters.

[R4 — Shell scripting](r04-shell-scripting/index.md) comes next. It is the module that turns the commands you have been typing into programs, and every later module uses the same patterns.

[R5 — Processes and services](r05-processes-and-services/index.md) is where those programs become services: systemd units, the journal, process priorities, and tuning profiles. It is also the first module whose state must survive a reboot on its own.

[R6 — Local storage](r06-local-storage/index.md) takes the same persistence test to the block layer: GPT partitions, LVM physical volumes and logical volumes, XFS and ext4, swap, and mounts that find their filesystems by UUID or label after a reboot.

[R7 — File systems and sharing](r07-file-systems/index.md) turns that storage outward: a VFAT volume whose ownership comes from mount options, an NFS export opened through the firewall, autofs on the client, and an ext4 volume grown and checked while the data on it stays intact. It is the first module that needs both VMs at once.

[R8 — Scheduling and time](r08-scheduling-and-time/index.md) makes the machine act without you: cron, one-off `at` jobs, systemd timers that catch up after downtime, and a two-machine NTP hierarchy with the lab's timezone set explicitly. Its checker proves each schedule by the output it produced, not by the file that describes it.

[R9 — Networking and firewalld](r09-networking-and-firewall/index.md) connects the machine to everything else: NetworkManager connection profiles, static IPv4 and IPv6 on the same interface, name resolution through `/etc/hosts` and DNS, and firewalld zones. It teaches the firewall on a dummy interface, so a mistake cannot end your SSH session, and then proves every rule with a real request from `node2`.

[R10 — Security: SELinux and SSH](r10-security-selinux-ssh/index.md) adds the two defences that decide what happens after a password or a firewall rule has already failed: SELinux labels and types, and key-based SSH with the password path turned off. It deliberately walks into a `403`, a failed bind, and a `503`, and fixes each at the layer that refused it. The challenge then restricts the service port to the lab network and proves the whole stack survives a reboot.

[R11 — Boot, rescue, and updates](r11-boot-rescue-updates/index.md) goes below the running system: firmware, GRUB 2, the initramfs, systemd targets, and the bootloader's two layers. It teaches the difference between a runtime change and a persistent one, then breaks the root login on purpose and recovers it through `rd.break`, a relabel, and a second boot. The challenge applies a full package update and adds a second kernel argument without losing the recovery.

Before R1, make sure the lab is running:

```bash
cd labs
./bin/lab up
./bin/lab snapshot clean
```

If you are new to Linux, work through [Foundations F1–F8](../foundations/index.md) first, starting with [F1 — Linux, open source, and the RHEL family](../foundations/f1-linux-rhel-family/index.md), then return to R1. If you are experienced, take the R1 challenge lab and see how far you get.

## The capstone

R12 will contain:

- Three full mock exams in the style of EX200, each with a task sheet and a grading script.
- A two-node scenario for SSH, NFS, and firewall tasks.
- A review checklist organized by the "persistence four": mounts, services, firewall, SELinux.

The capstone is where the domains stop being separate topics and become one system, which is how the exam presents them.
