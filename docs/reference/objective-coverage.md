# Objective coverage matrix

This page maps the current EX200 v10 objectives to the course. Use it to find the lesson for a weak area, or to audit the course for gaps.

**Status legend:** <span class="badge badge-ready">Covered</span> means the lesson, labs, challenge, and automated checker exist and the module has been validated on the lab.

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

**Module R3** — <span class="badge badge-ready">Covered</span>

| Objective | Where |
|---|---|
| Configure access to RPM repositories | [R3 — Repository configuration](../rhcsa/r03-software-and-repositories/index.md#repository-configuration-files) and [Local repository](../rhcsa/r03-software-and-repositories/index.md#building-a-local-repository) |
| Install and remove RPM software packages | [R3 — `dnf`: transactions](../rhcsa/r03-software-and-repositories/index.md#dnf-transactions) |
| Configure access to Flatpak repositories | [R3 — Remotes](../rhcsa/r03-software-and-repositories/index.md#remotes) |
| Install and remove Flatpak software packages | [R3 — Installing and removing applications](../rhcsa/r03-software-and-repositories/index.md#installing-and-removing-applications) |

## 3. Create simple shell scripts

**Module R4** — <span class="badge badge-ready">Covered</span>

| Objective | Where |
|---|---|
| Conditionally execute code (`if`, `test`, `[]`, etc.) | [R4 — Testing conditions](../rhcsa/r04-shell-scripting/index.md#testing-conditions) and [Conditionals](../rhcsa/r04-shell-scripting/index.md#conditionals) |
| Use looping constructs (`for`, etc.) to process file and command-line input | [R4 — Loops](../rhcsa/r04-shell-scripting/index.md#loops) |
| Process script inputs (`$1`, `$2`, etc.) | [R4 — Arguments](../rhcsa/r04-shell-scripting/index.md#arguments) |
| Process the output of shell commands within a script | [R4 — Command substitution](../rhcsa/r04-shell-scripting/index.md#command-substitution) |

## 4. Operate running systems

**Modules R5 and R11** — <span class="badge badge-ready">Covered</span>; **secure file transfer** is covered in R1

| Objective | Where |
|---|---|
| Boot, reboot, and shut down a system normally | [R11 — The boot chain](../rhcsa/r11-boot-rescue-updates/index.md#the-boot-chain) and [R5 — What survives a reboot](../rhcsa/r05-processes-and-services/index.md#what-survives-a-reboot) |
| Boot systems into different targets manually | [R11 — Targets](../rhcsa/r11-boot-rescue-updates/index.md#targets) |
| Interrupt the boot process in order to gain access to a system | [R11 — Interrupting the boot](../rhcsa/r11-boot-rescue-updates/index.md#interrupting-the-boot) and [Lab 2](../rhcsa/r11-boot-rescue-updates/labs/lab-2-recovery.md) |
| Identify CPU/memory intensive processes and kill processes | [R5 — Processes](../rhcsa/r05-processes-and-services/index.md#processes) and [Signals](../rhcsa/r05-processes-and-services/index.md#signals) |
| Adjust process scheduling | [R5 — Scheduling priority: nice](../rhcsa/r05-processes-and-services/index.md#scheduling-priority-nice) |
| Manage tuning profiles | [R5 — tuned](../rhcsa/r05-processes-and-services/index.md#tuned) |
| Locate and interpret system log files and journals | [R5 — The journal](../rhcsa/r05-processes-and-services/index.md#the-journal) |
| Preserve system journals | [R5 — Two possible homes](../rhcsa/r05-processes-and-services/index.md#two-possible-homes) |
| Start, stop, and check the status of network services | [R5 — systemd: units, services, and state](../rhcsa/r05-processes-and-services/index.md#systemd-units-services-and-state) |
| Securely transfer files between systems | [R1 — SSH and secure file transfer](../rhcsa/r01-essential-tools/index.md#ssh-and-secure-file-transfer) <span class="badge badge-ready">Covered</span> |

## 5. Configure local storage

**Module R6** — <span class="badge badge-ready">Covered</span>

| Objective | Where |
|---|---|
| List, create, and delete partitions on GPT disks | [R6 — Disks and partitions](../rhcsa/r06-local-storage/index.md#disks-and-partitions) |
| Create and remove physical volumes | [R6 — LVM](../rhcsa/r06-local-storage/index.md#lvm-physical-volumes-volume-groups-logical-volumes) |
| Assign physical volumes to volume groups | [R6 — LVM](../rhcsa/r06-local-storage/index.md#lvm-physical-volumes-volume-groups-logical-volumes) |
| Create and delete logical volumes | [R6 — LVM](../rhcsa/r06-local-storage/index.md#lvm-physical-volumes-volume-groups-logical-volumes) |
| Configure systems to mount file systems at boot by UUID or label | [R6 — Mounting at boot](../rhcsa/r06-local-storage/index.md#mounting-at-boot-etcfstab) |
| Add new partitions and logical volumes, and swap to a system non-destructively | [R6 — Growing storage](../rhcsa/r06-local-storage/index.md#growing-storage-without-losing-data) and [R6 — Swap](../rhcsa/r06-local-storage/index.md#swap) |

## 6. Create and configure file systems

**Module R7** — <span class="badge badge-ready">Covered</span>

| Objective | Where |
|---|---|
| Create, mount, unmount, and use VFAT, ext4, and XFS file systems | [R7 — Choosing a filesystem](../rhcsa/r07-file-systems/index.md#choosing-a-filesystem), [VFAT](../rhcsa/r07-file-systems/index.md#vfat), and [Lab 1](../rhcsa/r07-file-systems/labs/lab-1-vfat.md) |
| Mount and unmount network file systems using NFS | [R7 — NFS](../rhcsa/r07-file-systems/index.md#nfs), [Mounting](../rhcsa/r07-file-systems/index.md#mounting-again), and [Lab 2](../rhcsa/r07-file-systems/labs/lab-2-nfs-autofs.md) |
| Configure autofs | [R7 — autofs](../rhcsa/r07-file-systems/index.md#autofs) and [Lab 2](../rhcsa/r07-file-systems/labs/lab-2-nfs-autofs.md) |
| Extend existing logical volumes | [R7 — Growing and shrinking](../rhcsa/r07-file-systems/index.md#growing-and-shrinking) and the [challenge](../rhcsa/r07-file-systems/labs/challenge-grow-ext4.md) (R6 covers XFS) |
| Diagnose and correct file permission problems | [R7 — `root_squash` and `nobody`](../rhcsa/r07-file-systems/index.md#root_squash-and-nobody), [Permission problems on NFS](../rhcsa/r07-file-systems/index.md#permission-problems-on-nfs), and [Common traps](../rhcsa/r07-file-systems/index.md#common-traps), with R1 and R2 foundations |

## 7. Deploy, configure, and maintain systems

**Modules R3, R5, R8, and R11** — <span class="badge badge-ready">Covered</span>.

| Objective | Where |
|---|---|
| Schedule tasks using `at`, `cron`, and systemd timer units | [R8 — Choosing a scheduler](../rhcsa/r08-scheduling-and-time/index.md#choosing-a-scheduler), [cron](../rhcsa/r08-scheduling-and-time/index.md#cron), [at](../rhcsa/r08-scheduling-and-time/index.md#at), and [systemd timers](../rhcsa/r08-scheduling-and-time/index.md#systemd-timers) |
| Start and stop services and configure services to start automatically at boot | [R5 — systemd: units, services, and targets](../rhcsa/r05-processes-and-services/index.md#systemd-units-services-and-state); R8 adds timer units on top |
| Configure systems to boot into a specific target automatically | [R11 — Targets](../rhcsa/r11-boot-rescue-updates/index.md#targets) and [Lab 1](../rhcsa/r11-boot-rescue-updates/labs/lab-1-targets-and-grub.md) |
| Configure time service clients | [R8 — chrony](../rhcsa/r08-scheduling-and-time/index.md#chrony) and [Lab 2](../rhcsa/r08-scheduling-and-time/labs/lab-2-timers-and-chrony.md); the timezone is in [Timezones](../rhcsa/r08-scheduling-and-time/index.md#timezones) |
| Install and update software packages from the Red Hat CDN, a remote repository, or the local filesystem | [R3 — `dnf`: transactions](../rhcsa/r03-software-and-repositories/index.md#dnf-transactions), [Building a local repository](../rhcsa/r03-software-and-repositories/index.md#building-a-local-repository), and [R11 — Software updates](../rhcsa/r11-boot-rescue-updates/index.md#software-updates) |
| Modify the system bootloader | [R11 — The bootloader](../rhcsa/r11-boot-rescue-updates/index.md#the-bootloader) and [Kernel arguments](../rhcsa/r11-boot-rescue-updates/index.md#kernel-arguments) |

## 8. Manage basic networking

**Module R9** — <span class="badge badge-ready">Covered</span>

| Objective | Where |
|---|---|
| Configure IPv4 and IPv6 addresses | [R9 — IPv4 and IPv6](../rhcsa/r09-networking-and-firewall/index.md#ipv4-and-ipv6-in-one-breath), [Lab 1](../rhcsa/r09-networking-and-firewall/labs/lab-1-static-connection.md) |
| Configure hostname resolution | [R9 — Name resolution](../rhcsa/r09-networking-and-firewall/index.md#name-resolution) and the challenge's [named service host](../rhcsa/r09-networking-and-firewall/labs/challenge-service-host.md) |
| Configure network services to start automatically at boot | [R9 — The NetworkManager model](../rhcsa/r09-networking-and-firewall/index.md#the-networkmanager-model) (`connection.autoconnect`) and [Lab 2](../rhcsa/r09-networking-and-firewall/labs/lab-2-firewalld.md) (a permanent zone bound to the interface) |
| Restrict network access using `firewalld` and `firewall-cmd` | [R9 — firewalld](../rhcsa/r09-networking-and-firewall/index.md#firewalld); R10 adds SELinux port labels and hardening |

## 9. Manage users and groups

**Module R2** — <span class="badge badge-ready">Covered</span>

| Objective | Where |
|---|---|
| Create, delete, and modify local user accounts | [R2 — Creating users](../rhcsa/r02-users-and-groups/index.md#creating-users), [Modifying users](../rhcsa/r02-users-and-groups/index.md#modifying-users), [Deleting users](../rhcsa/r02-users-and-groups/index.md#deleting-users) |
| Change passwords and adjust password aging for local user accounts | [R2 — Passwords and aging](../rhcsa/r02-users-and-groups/index.md#passwords-and-aging) |
| Create, delete, and modify local groups and group memberships | [R2 — Groups](../rhcsa/r02-users-and-groups/index.md#groups) |
| Configure privileged access | [R2 — Privileged access with sudo](../rhcsa/r02-users-and-groups/index.md#privileged-access-with-sudo) |

## 10. Manage security

**Module R10** — <span class="badge badge-ready">Covered</span>

| Objective | Where |
|---|---|
| Configure firewall settings using `firewall-cmd` / `firewalld` | [R9 — firewalld](../rhcsa/r09-networking-and-firewall/index.md#firewalld), extended in [R10 — firewalld: narrowing the opening](../rhcsa/r10-security-selinux-ssh/index.md#firewalld-narrowing-the-opening) and the [challenge](../rhcsa/r10-security-selinux-ssh/labs/challenge-hardened-host.md) |
| Manage default file permissions | [R2 — umask](../rhcsa/r02-users-and-groups/index.md#default-permissions-umask) and [R1 — Permissions](../rhcsa/r01-essential-tools/index.md#permissions) |
| Configure key-based authentication for SSH | [R10 — SSH: keys instead of passwords](../rhcsa/r10-security-selinux-ssh/index.md#ssh-keys-instead-of-passwords) and [Lab 2](../rhcsa/r10-security-selinux-ssh/labs/lab-2-ssh-keys.md); previewed in [R1 — SSH](../rhcsa/r01-essential-tools/index.md#ssh-and-secure-file-transfer) |
| Set enforcing and permissive modes for SELinux | [R10 — Modes](../rhcsa/r10-security-selinux-ssh/index.md#modes) and [Lab 1, Step 1](../rhcsa/r10-security-selinux-ssh/labs/lab-1-selinux.md) |
| List and identify SELinux file and process context | [R10 — Contexts](../rhcsa/r10-security-selinux-ssh/index.md#selinux-the-model) |
| Restore default file contexts | [R10 — File labels come from policy](../rhcsa/r10-security-selinux-ssh/index.md#file-labels-come-from-policy) and [Lab 1, Step 5](../rhcsa/r10-security-selinux-ssh/labs/lab-1-selinux.md) |
| Manage SELinux port labels | [R10 — Port labels](../rhcsa/r10-security-selinux-ssh/index.md#port-labels) and [Lab 1, Step 4](../rhcsa/r10-security-selinux-ssh/labs/lab-1-selinux.md) |
| Use Boolean settings to modify system SELinux settings | [R10 — Booleans](../rhcsa/r10-security-selinux-ssh/index.md#booleans) and [Lab 1, Step 6](../rhcsa/r10-security-selinux-ssh/labs/lab-1-selinux.md) |

## Capstone

**Module R12** — <span class="badge badge-ready">Covered</span>

One full-stack rehearsal (storage, account, SELinux, web service, firewall, timer, boot), a diagnostic lab that breaks the host in three layers and repairs it, and three timed mock exams with grading scripts. The capstone adds no new objective; it re-tests every group under exam conditions.

## Coverage rule

The course is considered complete for a module when every objective bullet in that module has:

1. a theory explanation,
2. at least one guided or challenge lab where it is practiced,
3. an automated check that verifies the result, and
4. a persistence test where the objective changes system state.

R1–R12 meet this rule; each has passed its checker from a clean snapshot after a reboot.
