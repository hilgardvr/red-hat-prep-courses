# Objective coverage matrix

This page maps the current EX200 v10 objectives to the course. Use it to find the lesson for a weak area, or to audit the course for gaps.

**Status legend:** <span class="badge badge-ready">Covered</span> means the lesson and labs exist. <span class="badge badge-planned">Planned</span> means the module is scheduled but not yet published.

!!! warning "Use the official list as the source of truth"
    Red Hat can change the objectives. The list below reflects the RHEL 10 / EX200 v10 grouping as published at the time of writing. Confirm it on the [official EX200 page](https://www.redhat.com/en/services/training/ex200-red-hat-certified-system-administrator-rhcsa-exam) before booking.

## 1. Understand and use essential tools

**Module R1** — <span class="badge badge-ready">Covered</span>

| Objective | Where |
|---|---|
| Access a shell prompt and issue commands with correct syntax | [R1 — The shell and command syntax](../rhcsa/r01-essential-tools/index.md#the-shell-and-command-syntax) |
| Use input-output redirection (`>`, `>>`, `\|`, `2>`, etc.) | [R1 — Streams, redirection, and pipes](../rhcsa/r01-essential-tools/index.md#streams-redirection-and-pipes) |
| Use `grep` and regular expressions to analyze text | [R1 — grep and regular expressions](../rhcsa/r01-essential-tools/index.md#grep-and-regular-expressions) |
| Access remote systems using SSH | [R1 — SSH and secure file transfer](../rhcsa/r01-essential-tools/index.md#ssh-and-secure-file-transfer) |
| Log in and switch users in multi-user targets | [R1 — Switching users and privilege](../rhcsa/r01-essential-tools/index.md#switching-users-and-privilege) |
| Archive, compress, unpack, and uncompress files using `tar`, `gzip`, and `bzip2` | [R1 — Archives and compression](../rhcsa/r01-essential-tools/index.md#archives-and-compression) |
| Create and edit text files | [R1 — Editing text files](../rhcsa/r01-essential-tools/index.md#editing-text-files) |
| Create, delete, copy, and move files and directories | [R1 — Files and directories](../rhcsa/r01-essential-tools/index.md#files-and-directories) |
| Create hard and soft links | [R1 — Hard and symbolic links](../rhcsa/r01-essential-tools/index.md#hard-and-symbolic-links) |
| List, set, and change standard ugo/rwx permissions | [R1 — Permissions](../rhcsa/r01-essential-tools/index.md#permissions) |
| Locate, read, and use system documentation including `man`, `info`, and `/usr/share/doc` | [R1 — Getting help offline](../rhcsa/r01-essential-tools/index.md#getting-help-offline) |

## 2. Manage software

**Module R3** — <span class="badge badge-planned">Planned</span>

| Objective | Where |
|---|---|
| Configure access to RPM repositories | R3 |
| Install and remove RPM software packages | R3 |
| Configure access to Flatpak repositories | R3 |
| Install and remove Flatpak software packages | R3 |

## 3. Create simple shell scripts

**Module R4** — <span class="badge badge-planned">Planned</span>

| Objective | Where |
|---|---|
| Conditionally execute code (`if`, `test`, `[]`, etc.) | R4 |
| Use looping constructs (`for`, etc.) to process file and command-line input | R4 |
| Process script inputs (`$1`, `$2`, etc.) | R4 |
| Process the output of shell commands within a script | R4 |

## 4. Operate running systems

**Modules R5 and R11** — <span class="badge badge-planned">Planned</span>; **secure file transfer** is covered in R1

| Objective | Where |
|---|---|
| Boot, reboot, and shut down a system normally | R5 / R11 |
| Boot systems into different targets manually | R11 |
| Interrupt the boot process in order to gain access to a system | R11 |
| Identify CPU/memory intensive processes and kill processes | R5 |
| Adjust process scheduling | R5 |
| Manage tuning profiles | R5 |
| Locate and interpret system log files and journals | R5 |
| Preserve system journals | R5 |
| Start, stop, and check the status of network services | R5 |
| Securely transfer files between systems | [R1 — SSH and secure file transfer](../rhcsa/r01-essential-tools/index.md#ssh-and-secure-file-transfer) <span class="badge badge-ready">Covered</span> |

## 5. Configure local storage

**Module R6** — <span class="badge badge-planned">Planned</span>

| Objective | Where |
|---|---|
| List, create, and delete partitions on GPT disks | R6 |
| Create and remove physical volumes | R6 |
| Assign physical volumes to volume groups | R6 |
| Create and delete logical volumes | R6 |
| Configure systems to mount file systems at boot by UUID or label | R6 |
| Add new partitions and logical volumes, and swap to a system non-destructively | R6 |

## 6. Create and configure file systems

**Module R7** — <span class="badge badge-planned">Planned</span>

| Objective | Where |
|---|---|
| Create, mount, unmount, and use VFAT, ext4, and XFS file systems | R7 |
| Mount and unmount network file systems using NFS | R7 |
| Configure autofs | R7 |
| Extend existing logical volumes | R7 |
| Diagnose and correct file permission problems | R7, with R1 and R2 foundations |

## 7. Deploy, configure, and maintain systems

**Modules R8, R11, and R3** — <span class="badge badge-planned">Planned</span>

| Objective | Where |
|---|---|
| Schedule tasks using `at`, `cron`, and systemd timer units | R8 |
| Start and stop services and configure services to start automatically at boot | R8 |
| Configure systems to boot into a specific target automatically | R8 / R11 |
| Configure time service clients | R8 |
| Install and update software packages from the Red Hat CDN, a remote repository, or the local filesystem | R3 / R11 |
| Modify the system bootloader | R11 |

## 8. Manage basic networking

**Module R9** — <span class="badge badge-planned">Planned</span>

| Objective | Where |
|---|---|
| Configure IPv4 and IPv6 addresses | R9 |
| Configure hostname resolution | R9 |
| Configure network services to start automatically at boot | R9 |
| Restrict network access using `firewalld` and `firewall-cmd` | R9 / R10 |

## 9. Manage users and groups

**Module R2** — <span class="badge badge-ready">Available</span>

| Objective | Where |
|---|---|
| Create, delete, and modify local user accounts | [R2 — Creating users](../rhcsa/r02-users-and-groups/index.md#creating-users), [Modifying users](../rhcsa/r02-users-and-groups/index.md#modifying-users), [Deleting users](../rhcsa/r02-users-and-groups/index.md#deleting-users) |
| Change passwords and adjust password aging for local user accounts | [R2 — Passwords and aging](../rhcsa/r02-users-and-groups/index.md#passwords-and-aging) |
| Create, delete, and modify local groups and group memberships | [R2 — Groups](../rhcsa/r02-users-and-groups/index.md#groups) |
| Configure privileged access | [R2 — Privileged access with sudo](../rhcsa/r02-users-and-groups/index.md#privileged-access-with-sudo) |

## 10. Manage security

**Module R10** — <span class="badge badge-planned">Planned</span>

| Objective | Where |
|---|---|
| Configure firewall settings using `firewall-cmd` / `firewalld` | R10, with R9 |
| Manage default file permissions | R10, with [R2 — umask](../rhcsa/r02-users-and-groups/index.md#default-permissions-umask) and [R1 — Permissions](../rhcsa/r01-essential-tools/index.md#permissions) |
| Configure key-based authentication for SSH | R10, previewed in [R1 — SSH](../rhcsa/r01-essential-tools/index.md#ssh-and-secure-file-transfer) |
| Set enforcing and permissive modes for SELinux | R10 |
| List and identify SELinux file and process context | R10 |
| Restore default file contexts | R10 |
| Manage SELinux port labels | R10 |
| Use Boolean settings to modify system SELinux settings | R10 |

## Capstone

**Module R12** — <span class="badge badge-planned">Planned</span>

Timed mock exams covering all groups, with grading scripts and a persistence checklist.

## Coverage rule

The course is considered complete for a module when every objective bullet in that module has:

1. a theory explanation,
2. at least one guided or challenge lab where it is practiced,
3. an automated check that verifies the result, and
4. a persistence test where the objective changes system state.

R1 meets this rule. The remaining modules are being written to the same standard.
