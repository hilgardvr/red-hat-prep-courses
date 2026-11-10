<div class="hero" markdown>

# RHCSA Field Guide

<p class="subtitle">A free, lab-first course for the Red Hat Certified System Administrator exam — built around RHEL 10 and the current EX200 objectives.</p>

</div>

[Start the course](start-here/how-to-use.md){ .md-button .md-button--primary }
[Set up your lab](start-here/lab-setup.md){ .md-button }

---

## The exam at a glance

| | |
|---|---|
| **Certification** | Red Hat Certified System Administrator (RHCSA) |
| **Exam** | EX200, version 10 |
| **Platform** | Red Hat Enterprise Linux 10 |
| **Format** | 100% performance-based, hands-on |
| **Duration** | 3 hours |
| **Internet** | Not available during the exam |
| **Pass mark** | Commonly reported as 210/300; Red Hat does not publish it prominently |
| **Golden rule** | Every configuration must survive a reboot |

!!! warning "Objectives change"
    Red Hat updates exam objectives when the platform moves. The current EX200 is based on RHEL 10 and adds **Flatpak** and **systemd timer units**, while dropping **containers/Podman** and **set-GID collaboration directories**. Always confirm the objectives on the [official EX200 page](https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam) before booking.

## What you get

<div class="grid cards" markdown>

-   :material-book-open-variant: **Theory that explains the why**

    ---

    Mental models for the shell, permissions, storage, systemd, networking, and SELinux — not just a list of commands to memorize.

-   :material-flask: **Labs on real RHEL-family systems**

    ---

    Two disposable virtual machines, reproducible from a snapshot. Practice LVM, boot recovery, SELinux, firewalld, and NFS the way the exam tests them.

-   :material-check-decagram: **Automated verification**

    ---

    Every lab ships with a check script. It inspects the end state — including after a reboot — and tells you exactly what is missing.

-   :material-school: **Exam-style challenges**

    ---

    Each module ends with a task written in the same style as EX200, followed by a timed capstone that pulls the domains together.

</div>

## Course map

| Stage | What it covers | Status |
|---|---|---|
| **Foundations** | Linux and RHEL architecture, shell, filesystem, processes, systemd, networking, storage basics | <span class="badge badge-ready">F1–F8 available</span> |
| **R1 — Essential tools** | Shell syntax, help system, files, links, permissions, streams, grep, archives, SSH | <span class="badge badge-ready">Available</span> |
| **R2 — Users and groups** | Accounts, groups, password aging, `sudo`, default permissions | <span class="badge badge-ready">Available</span> |
| **R3 — Software and repositories** | DNF, RPM repositories, local repos, Flatpak | <span class="badge badge-ready">Available</span> |
| **R4 — Shell scripting** | Arguments, conditionals, loops, command substitution, exit codes | <span class="badge badge-ready">Available</span> |
| **R5 — Processes and services** | systemd units, drop-ins, journald, process priority, tuned | <span class="badge badge-ready">Available</span> |
| **R6–R11** | Storage, filesystems, scheduling, networking, security, boot | <span class="badge badge-planned">Planned</span> |
| **R12 — Capstone** | Timed mock exams and a full review | <span class="badge badge-planned">Planned</span> |

[See the full module roadmap](rhcsa/index.md){ .md-button }

## How the course works

Each module follows the same rhythm:

1. **Read the theory** and build a mental model.
2. **Follow the guided labs** with explained commands and expected output.
3. **Solve the challenge lab** using only the task description.
4. **Reboot** and prove the configuration persisted.
5. **Run the check script** and fix anything it flags.
6. **Review the cheat sheet and knowledge check** before moving on.

!!! tip "Practice like the exam"
    The exam gives you tasks, a live system, and no internet. It does not give you step-by-step instructions. The guided labs teach the mechanics; the challenge labs and capstone teach you to work without a recipe.

## Free core, paid extras

The lessons and labs on this site are free. Paid extras — mock-exam packs, a printable workbook, and instructor materials — may be added later. The free course will remain complete enough to prepare for EX200 on its own.

## Disclaimer

This is an independent, unofficial study resource. It is not affiliated with, endorsed by, or sponsored by Red Hat, Inc. **Red Hat**, **RHCSA**, **RHCE**, and **Red Hat Enterprise Linux** are trademarks of Red Hat, Inc.
