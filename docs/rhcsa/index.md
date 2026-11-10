# RHCSA course roadmap

The course is organized around the ten objective groups Red Hat publishes for EX200. Each module teaches the theory behind the group, then makes you perform the work on the lab systems.

## Modules

| Module | Focus | Exam objective group | Status |
|---|---|---|---|
| **R1** | Essential tools: shell, help, files, links, permissions, streams, grep, archives, SSH | 1 — Understand and use essential tools | <span class="badge badge-ready">Available</span> |
| **R2** | Users, groups, password aging, sudo, default permissions | 9 — Users and groups; part of 10 | <span class="badge badge-ready">Available</span> |
| **R3** | Software: DNF, RPM repositories, Flatpak | 2 — Manage software | <span class="badge badge-ready">Available</span> |
| **R4** | Shell scripting: arguments, conditionals, loops, command substitution | 3 — Create simple shell scripts | <span class="badge badge-ready">Available</span> |
| **R5** | Processes, systemd services, journald, tuned | 4 — Operate running systems | <span class="badge badge-planned">Planned</span> |
| **R6** | GPT partitions, LVM, swap, fstab by UUID/label | 5 — Configure local storage | <span class="badge badge-planned">Planned</span> |
| **R7** | ext4/XFS/VFAT, NFS, autofs, extending logical volumes | 6 — Create and configure file systems | <span class="badge badge-planned">Planned</span> |
| **R8** | cron, at, systemd timers, chrony | 7 — Deploy, configure, and maintain systems | <span class="badge badge-planned">Planned</span> |
| **R9** | nmcli, IPv4/IPv6, hostname resolution, firewalld | 8 — Manage basic networking | <span class="badge badge-planned">Planned</span> |
| **R10** | SELinux, SSH key authentication, firewall hardening | 10 — Manage security | <span class="badge badge-planned">Planned</span> |
| **R11** | Boot targets, GRUB, rescue, rd.break, updates | 4 + 7 | <span class="badge badge-planned">Planned</span> |
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

## Start with R1, then work through R2–R4

[R1 — Essential tools](r01-essential-tools/index.md) is the best place to begin. It covers the largest objective group and establishes the lab workflow that every later module uses. Once it passes its checker, continue with [R2 — Users and groups](r02-users-and-groups/index.md), which turns the permission model from R1 into real accounts, policy, and privileged access, then with [R3 — Software and repositories](r03-software-and-repositories/index.md), which is where the exam's no-internet condition first matters.

[R4 — Shell scripting](r04-shell-scripting/index.md) comes next. It is the module that turns the commands you have been typing into programs, and every later module uses the same patterns.

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
