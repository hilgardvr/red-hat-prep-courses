# Study plans

Pick the plan that matches your starting point and the time you can commit. All three cover the same material; they differ in pace and in how much of the foundations you do.

## Before you choose

Answer three questions honestly:

1. **Can you use a shell?** If `cd`, `ls`, `cp`, `mv`, `rm`, and a text editor are unfamiliar, start with the 12-week plan.
2. **Have you administered a Linux system?** Users, services, disks, and networking at work or in a homelab? The 6-week plan is realistic.
3. **Do you already hold a Linux certification or administer RHEL daily?** Use the 2-week plan, but do not skip the mock exams.

The exam is practical. Time spent typing and troubleshooting is worth more than time spent reading.

## The weekly rhythm

A good week looks like this:

| Day | Activity | Time |
|---|---|---|
| 1 | Read the module theory; take notes | 60–90 min |
| 2 | Guided Lab 1 | 60–90 min |
| 3 | Guided Lab 2 | 60–90 min |
| 4 | Challenge lab, no notes | 60–90 min |
| 5 | Reboot, run the checker, fix gaps | 45–60 min |
| 6 | Knowledge check + cheat sheet review | 30–45 min |
| 7 | Rest or light review | optional |

If a lab takes longer, that is normal. The goal is understanding, not speed.

## 12-week plan (beginner)

This plan assumes little or no Linux experience. It includes the full foundations course.

| Week | Focus | Modules |
|---|---|---|
| 1 | What Linux is; installing and using the lab | F1, F2 |
| 2 | Shell, files, and the help system | F3, F4 |
| 3 | Streams, users, and permissions | F5, F6 |
| 4 | Processes, networking, and SELinux | F7, F8 |
| 5 | Essential tools | R1 |
| 6 | Users, groups, and software | R2, R3 |
| 7 | Shell scripting and services | R4, R5 |
| 8 | Storage and filesystems | R6, R7 |
| 9 | Scheduling and networking | R8, R9 |
| 10 | Security and boot | R10, R11 |
| 11 | Capstone: build, break, and repair; Exam A | R12 Lab 1–2, Exam A |
| 12 | Mock exams B and C, then targeted repair | R12 Exams B–C |

A week that lists two modules takes about twice the hours in the rhythm above. If 5–7 hours a week is your limit, stretch this plan to 16 weeks by giving each module its own week; the order does not change.

If a week slips, move the schedule rather than skipping the labs. The capstone will expose gaps.

## 6-week plan (some Linux experience)

Skim F1–F4, do F5–F8 at speed, and spend most of the time in the RHCSA modules.

| Week | Focus | Modules |
|---|---|---|
| 1 | Foundations refresh + essential tools | F1–F5, R1 |
| 2 | Users, software, scripting | R2–R4 |
| 3 | Services, storage, filesystems | R5–R7 |
| 4 | Scheduling, networking, security | R8–R10 |
| 5 | Boot, recovery, updates; review weak spots | R11 + review |
| 6 | Mock exams and targeted repair | R12 |

## 2-week refresher (experienced admin)

Do not read everything. Use the objective matrix, attempt the challenge labs first, and study only what you fail.

| Day | Focus |
|---|---|
| 1 | Lab setup; R1 challenge; note gaps |
| 2 | R2–R3 challenge labs; review Flatpak |
| 3 | R4–R5 challenge labs; systemd timers |
| 4 | R6–R7 challenge labs; LVM and fstab |
| 5 | R8–R9 challenge labs; nmcli and firewalld |
| 6 | R10 challenge; SELinux contexts and booleans |
| 7 | R11 challenge; boot recovery and rd.break |
| 8 | Mock exam 1, timed |
| 9 | Review every failure; redo those labs |
| 10 | Mock exam 2, timed |
| 11 | Weak-area drills; persistence checklist |
| 12 | Light review, rest, exam logistics |
| 13–14 | Buffer, second attempts, exam |

## How to know you are ready

You are ready when you can, without notes:

- Create a user, set password aging, and grant sudo access.
- Configure a local repository and install/remove packages, including Flatpak.
- Write a small script with a conditional, a loop, and command substitution.
- Start, enable, and troubleshoot a systemd service; read its journal.
- Create a GPT partition, PV, VG, and LV; format it; mount it by UUID; reboot and verify.
- Extend an LV and grow the filesystem online.
- Configure an NFS mount and an autofs map.
- Schedule a task with cron, `at`, and a systemd timer.
- Configure an IPv4/IPv6 address with `nmcli`, set the hostname, and resolve names.
- Open a firewall service and port permanently.
- Set SELinux enforcing/permissive, fix a context, set a port label, and toggle a boolean.
- Reset a forgotten root password and boot into a different target.
- Complete a 3-hour mock exam with time to spare and re-verify after a reboot.

If any item makes you reach for a search engine, that is your next practice session.

## Using the mock exams

The capstone includes timed mock exams. Treat them as real:

- No notes, no internet.
- One browser tab for the task sheet only.
- Reboot before you declare yourself finished.
- Grade with the provided checker, then review every failed task.

A mock exam is a diagnostic, not a score. The value is in the list of things you could not do.
