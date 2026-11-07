# Foundations

The exam objectives assume a working mental model of Linux. You do not need to be a kernel developer, but you do need to know what a process is, how the filesystem is organized, what a service manager does, and why permissions behave the way they do.

This pre-course builds that model. It is **optional for experienced Linux users** and **strongly recommended for beginners**. None of it is decorative: every foundation topic reappears in the exam modules.

## What you will learn

| Module | Topic | You will be able to |
|---|---|---|
| [F1](f1-linux-rhel-family/index.md) | Linux, open source, and the RHEL family | Explain kernel vs userspace, distributions, RHEL lifecycle, and where the exam fits |
| [F2](f2-lab-first-login/index.md) | The lab: virtualization and first login | Create the lab VMs, log in, use snapshots, and recover from mistakes |
| F3 | Shell, commands, and the help system | Read command syntax, quote arguments correctly, and find documentation offline |
| F4 | Filesystem hierarchy and file operations | Navigate the FHS, create/copy/move/delete files, and understand paths |
| F5 | Streams, redirection, pipes, grep, and regex | Connect commands, separate stdout/stderr, and search text precisely |
| F6 | Users, permissions, and ownership | Explain the ugo/rwx model, read octal modes, and predict access |
| F7 | Processes, systemd, and logs | Inspect processes, control services, read the journal, and understand targets |
| F8 | Networking and storage foundations; SELinux intro | Read IP addressing, explain DNS and ports, and describe disks, filesystems, and SELinux labels |

## How much time to spend

- **Beginner:** do all eight modules. They take roughly 15–20 hours including practice.
- **Some Linux experience:** skim F1–F4, do F5–F8 properly.
- **Working admin:** use the self-assessment below. If you can answer every question without looking it up, skip to [R1](../rhcsa/r01-essential-tools/index.md).

## Self-assessment

If any of these make you hesitate, read the matching foundation module.

1. What is the difference between the kernel and the shell?
2. What does `chmod 640 file` grant to the owner, group, and others?
3. Where would you look for a service's configuration, logs, and unit file?
4. What is the difference between a hard link and a symbolic link?
5. What does `2>&1` do, and why does its position on the command line matter?
6. What is the difference between a process and a service?
7. What does a subnet mask do, and what is a default gateway for?
8. What is the difference between a partition, a filesystem, and a mount point?
9. What does SELinux enforce that ordinary permissions do not?
10. What happens to a configuration that is not written to persistent storage?

## How the foundations are taught

Each foundations module follows the same pattern as the exam modules, but with lighter labs:

- A plain-language explanation of the concept.
- A diagram or table you can reconstruct from memory.
- Small commands to run in the lab to see the concept in action.
- A short self-check.

They do not have automated check scripts. Their purpose is to prepare you for R1, where automated verification begins.

## A note on depth

You do not need to know how the kernel scheduler is implemented to pass RHCSA. You do need to know that `systemd` is PID 1, that a unit file describes a service, that `journalctl` reads the journal, and that a reboot is the real test of persistence.

When a foundation topic goes deeper than the exam requires, the page says so. Skip the depth, keep the model.

## Start

Begin with F1 and F2. F1 explains the platform; F2 gets the lab running and teaches the snapshot workflow used by every later module.

- [F1 — Linux, open source, and the RHEL family](f1-linux-rhel-family/index.md)
- [F2 — The lab: virtualization and first login](f2-lab-first-login/index.md)

F3–F8 are being written next. Until they are available:

- If you already know your way around a shell, continue to [R1 — Essential tools](../rhcsa/r01-essential-tools/index.md).
- If you have not set up the lab yet, follow [Lab setup](../start-here/lab-setup.md).
- If you want to see where every exam objective is covered, open the [objective coverage matrix](../reference/objective-coverage.md).
