# Glossary

Terms used throughout the course. Links point to the module where the term is explained in context.

| Term | Meaning |
|---|---|
| **ACL** | Access control list. An extension to ugo/rwx permissions that grants rights to specific users or groups. Not a current RHCSA objective, but encountered in production. |
| **autofs** | A service that mounts filesystems on demand when a path is accessed. Covered in R7. |
| **block device** | A device that reads and writes fixed-size blocks, such as a disk or partition (`/dev/vda`, `/dev/vdb1`). |
| **bootloader** | The program that loads the kernel. On RHEL, GRUB 2. Covered in R11. |
| **at** | A scheduler for one-off jobs that run once, later. The daemon is `atd`. Covered in R8. |
| **chrony** | The NTP implementation on RHEL 10 (`chronyd`), which keeps the system clock accurate and can serve time to a network. Covered in R8. |
| **CIDR** | Classless Inter-Domain Routing notation: an address followed by the number of network bits, such as `192.0.2.10/24`. The prefix decides which addresses are local. |
| **cron** | A scheduler for recurring jobs defined in crontabs. Covered in R8. |
| **DNF** | The package manager on RHEL 10 (`dnf`). It resolves dependencies and installs RPM packages from repositories. Covered in R3. |
| **exit status** | The number a command returns to the shell: `0` for success, non-zero for failure. Read with `$?`. |
| **fstab** | `/etc/fstab`, the file that defines filesystems to mount at boot. Covered in R6. |
| **filesystem** | The structure that organizes data on a device: ext4, XFS, VFAT, and others. Covered in R6 and R7. |
| **Firewalld** | The dynamic firewall manager on RHEL, controlled with `firewall-cmd`. Covered in R9/R10. |
| **Flatpak** | A cross-distribution application packaging and sandboxing system. A current RHCSA objective. Covered in R3. |
| **GPT** | GUID Partition Table. The current partition table format for the exam; MBR is no longer listed. Covered in R6. |
| **GRUB** | The bootloader used by RHEL. Covered in R11. |
| **hard link** | A directory entry that shares an inode with another entry. See [R1 — Hard and symbolic links](../rhcsa/r01-essential-tools/index.md#hard-and-symbolic-links). |
| **inode** | The metadata structure for a file: mode, owner, size, timestamps, and data block pointers. A filename points to an inode. |
| **journald** | The systemd logging service. Read logs with `journalctl`. Covered in R5. |
| **NTP** | Network Time Protocol. The protocol chrony uses to synchronise clocks over the network. Covered in R8. |
| **LVM** | Logical Volume Manager. A layer that pools physical volumes into volume groups and carves out logical volumes. Covered in R6. |
| **mount point** | A directory where a filesystem is attached to the tree. |
| **NetworkManager** | The network configuration service on RHEL, controlled with `nmcli` or `nmtui`. Covered in R9. |
| **NFS** | Network File System. A protocol for mounting a remote directory. Covered in R7. |
| **package** | An RPM file containing software and metadata. Installed with `dnf` or `rpm`. |
| **partition** | A contiguous region of a disk described by a partition table. |
| **physical volume (PV)** | A disk or partition initialized for LVM. |
| **PID 1** | The first process started by the kernel; on RHEL it is `systemd`. |
| **pipe** | The `\|` operator, which connects one command's stdout to the next command's stdin. |
| **process** | A running instance of a program, with a PID, memory, and open file descriptors. |
| **regular expression** | A pattern language for matching text, used by `grep`, `sed`, and many other tools. |
| **repository** | A source of RPM packages, defined in `/etc/yum.repos.d/*.repo`. |
| **RPM** | The Red Hat package format and the low-level tool (`rpm`) that manages it. |
| **SELinux** | Security-Enhanced Linux. A mandatory access control system that labels files and processes and enforces policy. Covered in R10. |
| **service** | A long-running background process managed by systemd, usually described by a unit file. |
| **zone (firewalld)** | A named set of firewall rules. Traffic is assigned to a zone by incoming interface or source address, and the default zone catches the rest. Covered in R9. |
| **snapshot** | A saved state of a virtual machine. The lab uses snapshots to reset between exercises. |
| **stdin / stdout / stderr** | File descriptors 0, 1, and 2: input, normal output, and error output. |
| **sudo** | A program that runs a command as another user according to `/etc/sudoers` policy. |
| **symbolic link** | A file whose content is a path to another file or directory. Also called a symlink or soft link. |
| **systemd** | The init system and service manager on RHEL. It manages units, targets, timers, mounts, and more. |
| **systemd timer** | A systemd unit that triggers another unit on a schedule, an alternative to cron. `Persistent=true` lets it catch up after downtime. A current RHCSA objective. Covered in R8. |
| **target** | A systemd grouping of units that represents a boot state, roughly equivalent to an old runlevel. |
| **timezone** | The named region that decides how a UTC instant is displayed, set with `timedatectl set-timezone`. It changes presentation, not the clock. Covered in R8. |
| **tuned** | A service that applies performance profiles. Covered in R5. |
| **udev** | The device manager that creates device nodes in `/dev` and applies rules. |
| **umask** | A shell setting that removes permission bits from newly created files and directories. See [R1 — Permissions](../rhcsa/r01-essential-tools/index.md#permissions). |
| **unit file** | A systemd configuration file describing a service, timer, mount, target, or other object. |
| **UUID** | Universally Unique Identifier. A stable identifier for a filesystem, preferred over device names in `/etc/fstab`. |
| **VG / LV** | Volume group and logical volume, the LVM pooling and allocation layers. Covered in R6. |
| **XFS** | The default filesystem on RHEL. It can be grown online but not shrunk. |
| **yum** | A compatibility alias for `dnf` on modern RHEL; both commands work. |
