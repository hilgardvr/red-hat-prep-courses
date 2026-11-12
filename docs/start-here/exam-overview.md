# Exam overview: EX200 v10

Everything below is a study aid, not an official statement. Red Hat controls the exam and can change it. Confirm the current details on the [official EX200 page](https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam) before you book.

## What the exam is

EX200 is a **performance-based** exam. You are given a set of tasks and one or more live RHEL systems. There are no multiple-choice questions. The grader inspects the state of the systems, not the commands you typed.

| Item | Detail |
|---|---|
| Credential | Red Hat Certified System Administrator (RHCSA) |
| Exam code | EX200, version 10 |
| Platform | Red Hat Enterprise Linux 10 |
| Duration | 3 hours |
| Format | Hands-on tasks on live systems |
| Internet | Not available |
| Documentation | Man pages and documentation installed on the system; no outside notes or books |
| Persistence | Configurations must survive a reboot without intervention |
| Pass mark | Commonly reported as 210/300; Red Hat does not publish it prominently |
| Validity | Current for 3 years, then "non-current" |

The exam is offered at Red Hat testing centres and remotely. Remote sessions have their own environment checks; read the Red Hat instructions before exam day.

## The objective groups

The current EX200 objectives are grouped into ten areas. The course follows the same grouping.

| # | Objective group | Course module |
|---|---|---|
| 1 | Understand and use essential tools | R1 |
| 2 | Manage software (RPM and Flatpak) | R3 |
| 3 | Create simple shell scripts | R4 |
| 4 | Operate running systems | R5 |
| 5 | Configure local storage | R6 |
| 6 | Create and configure file systems | R7 |
| 7 | Deploy, configure, and maintain systems | R8 |
| 8 | Manage basic networking | R9 |
| 9 | Manage users and groups | R2 |
| 10 | Manage security | R10 |

R11 covers boot, recovery, and updates across groups 4 and 7. R12 is the capstone.

## What changed in the RHEL 10 objectives

If you are using older study material, check it against the current list.

| Topic | RHEL 9 era | RHEL 10 / EX200 v10 |
|---|---|---|
| Flatpak | Not listed | **Added** — configure remotes, install and remove packages |
| systemd timers | Not listed | **Added** — schedule tasks with timer units |
| Containers / Podman | Included | **Removed** |
| Set-GID collaboration directories | Included | **Removed** |
| Partition tables | MBR and GPT | **GPT only** |
| Everything else | Shell, users, storage, LVM, filesystems, NFS, autofs, networking, firewalld, SELinux, SSH | Still in scope |

The container removal is good news for candidates who do not work with containers, but do not skip Flatpak and timers — they are current objectives and are easy to overlook.

## How the exam is scored

Red Hat reports a total score rather than a per-task breakdown. Third parties commonly cite **210 out of 300 (70%)** as the pass mark, but treat that as unofficial. Your goal should be to complete every task correctly, not to aim for a percentage.

Because the exam is task-based, one task can touch several objectives at once. A typical storage task might require you to:

1. create a partition,
2. build a physical volume, volume group, and logical volume,
3. create and mount a filesystem,
4. add it to `/etc/fstab` by UUID,
5. set the correct SELinux context,
6. open a firewall port if a service uses it,
7. reboot and verify.

That is why the course teaches domains together in the capstone instead of as isolated trivia.

## Exam-day strategy

### Before you start

- Read the entire task list first. Some tasks create resources that later tasks use.
- Note the tasks that require a reboot. Plan to reboot once, near the end, after the configuration is complete.
- Identify the tasks you know cold. Do those first to bank points.

### While working

- Prefer persistent configuration: `/etc/fstab`, `systemctl enable`, `firewall-cmd --permanent`, `semanage`, `nmcli` saved connections.
- Test the service, not just the unit: `curl`, `ssh`, `mount`, `ls`.
- Use `man` and `--help` when you forget syntax. The exam expects you to.
- Keep a mental checklist of the "persistence four": mount, service, firewall, SELinux.

### Before you finish

- Reboot.
- Re-check every task after the reboot.
- Verify mounts with `findmnt`, services with `systemctl is-enabled` **and** `systemctl is-active`, firewall with `firewall-cmd --list-all`, SELinux with `ls -Z` and `getenforce`.
- Do not leave a task half-configured because you ran out of ideas. A partially correct persistent configuration scores better than a perfect temporary one.

## What the exam does not test

- Multiple-choice trivia.
- Memorizing command output.
- Internet research.
- Copying a recipe without understanding it.

It does test whether you can read a requirement, choose the right tool, configure it persistently, and verify it. The labs are designed around that.

## Booking and preparation checklist

- [ ] Confirm the current objectives on the official page.
- [ ] Confirm the exam platform (RHEL 10) and delivery method.
- [ ] Build the lab and complete at least one full mock exam under time.
- [ ] Practice rebooting and re-verifying every configuration.
- [ ] Review the [objective coverage matrix](../reference/objective-coverage.md) for gaps.
- [ ] Read the Red Hat remote-exam requirements if you are testing remotely.

## Official links

- [EX200 exam page](https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam)
- [Red Hat certification program](https://www.redhat.com/en/services/certification)
- [Red Hat Enterprise Linux documentation](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/)

---

## A printable version

The [objective coverage matrix](../reference/objective-coverage.md) is the page to keep beside you while you study: every objective in the official grouping, with the lesson that teaches it. It is also available as a printable PDF together with [mock exam A](../rhcsa/r12-capstone/exams/exam-a-web-host.md), so you can audit yourself away from the screen.

[Get the free exam pack](../subscribe.md){ .md-button }
