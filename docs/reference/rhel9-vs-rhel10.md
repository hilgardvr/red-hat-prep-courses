# RHEL 9 vs RHEL 10 for RHCSA

The current EX200 is based on **RHEL 10**. Much of the RHEL 9 material still applies, but the objective list changed. This page summarizes what matters if you are using older notes, books, or videos.

## Objective changes

| Topic | RHEL 9 era | RHEL 10 / EX200 v10 | What to do |
|---|---|---|---|
| **Flatpak** | Not listed | Configure Flatpak remotes; install and remove Flatpak packages | Learn `flatpak remote-add`, `flatpak install`, `flatpak list`, `flatpak uninstall` |
| **systemd timers** | Not listed | Schedule tasks with timer units | Learn `.service` + `.timer` pairs, `systemctl enable --now`, `list-timers` |
| **Containers / Podman** | Included | **Removed** | Do not spend exam time on Podman; learn it for work if useful |
| **Set-GID collaboration directories** | Included | **Removed** | Understand SGID generally, but it is not a current exam bullet |
| **Partition tables** | MBR and GPT | **GPT only** | Practice `parted`, `fdisk`, `gdisk` on GPT disks |
| **NFS / autofs** | Client and server | Client side remains in scope | Focus on mounting and automounting, not exporting |
| **Everything else** | Shell, users, software, scripts, services, storage, LVM, filesystems, networking, firewalld, SELinux, SSH | Still in scope | Keep your existing study material for these |

## Platform changes that affect commands

| Area | RHEL 9 | RHEL 10 | Notes |
|---|---|---|---|
| Kernel | 5.14 | 6.12 | Not an exam topic, but explains minor behavior differences |
| Package manager | DNF 4 | DNF 4 | `dnf` commands are essentially unchanged; Flatpak is the new addition |
| Init / services | systemd | systemd | `systemctl` behavior is stable |
| Networking | NetworkManager + `nmcli` | NetworkManager + `nmcli` | The exam still expects `nmcli`-style persistent configuration |
| Firewall | firewalld + `firewall-cmd` | firewalld + `firewall-cmd` | Permanent/runtime model is unchanged |
| SELinux | Enforcing by default | Enforcing by default | `semanage`, `restorecon`, `getsebool` remain central |
| Filesystems | XFS default, ext4 supported | XFS default, ext4 supported | XFS still cannot be shrunk |
| Image mode (bootc) | Not present | Available | Not a core RHCSA objective; know the concept, do not drill it |

## Old-material traps

1. **Podman questions.** Many RHEL 9 practice exams include container tasks. They are not current EX200 objectives. Skip them unless you are studying for a different certification.
2. **MBR partitioning.** RHEL 9 material often teaches both MBR and GPT. The current objectives list GPT only. Do not ignore GPT tools.
3. **No Flatpak.** Older courses omit Flatpak entirely. It is a current objective; learn the offline repository workflow too.
4. **No timers.** Older courses teach cron and `at` only. Learn systemd timers, including the `.timer` unit and `Persistent=` behavior.
5. **Set-GID exercises.** Some labs teach collaborative directories with SGID. Useful knowledge, but not a current exam bullet. Do not let it crowd out current objectives.
6. **RHEL 9 command output.** Minor output differences (package versions, unit names, default paths) can confuse memorized answers. Learn the concept, not the exact string.

## What did not change

The core of the exam is stable:

- The shell, redirection, pipes, `grep`, `tar`, SSH
- Users, groups, password aging, sudo
- DNF repositories and package management
- systemd services, targets, journals
- GPT partitions, LVM, swap, `/etc/fstab` by UUID
- ext4/XFS/VFAT, NFS, autofs
- `nmcli`, hostname resolution, firewalld
- SELinux modes, contexts, port labels, booleans
- Boot targets, GRUB, root password recovery
- The persistence rule: everything must survive a reboot

If you learned RHCSA on RHEL 9, you are not starting over. You are adding Flatpak and timers, refreshing GPT, and dropping containers.

## A note on AlmaLinux, Rocky, and CentOS Stream

The lab defaults to AlmaLinux 10 because it is freely available and binary-compatible with RHEL 10 for these objectives. The course content targets RHEL 10. Differences you may encounter:

- Package versions and some default packages differ slightly.
- Subscription-manager commands are RHEL-specific; AlmaLinux uses DNF repositories directly.
- SELinux policy versions can differ, but the tools and concepts are the same.
- The exam runs on RHEL; if a command behaves differently on a rebuild, trust the RHEL documentation for exam day.

For exact fidelity, use a RHEL 10 box with a developer subscription or a local DVD repository, as described in [Lab setup](../start-here/lab-setup.md).
