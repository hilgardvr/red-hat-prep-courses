# F8 — Networking, storage, and SELinux foundations

<div class="module-meta" markdown>

| | |
|---|---|
| **Time** | 90–105 minutes |
| **Prerequisites** | [F6](../f6-users-permissions/index.md) and [F7](../f7-processes-systemd/index.md) |
| **Lab** | Map the network, mount a temporary filesystem, and read SELinux labels |
| **Self-check** | At the end of the page |

</div>

Three layers sit under almost every remaining exam objective: the network, the storage stack, and SELinux. R9 configures networking, R6 and R7 build storage, and R10 handles security. This module gives you the vocabulary and the inspection commands so those modules can focus on configuration.

## Networking

### Addresses and masks

An IPv4 address is 32 bits, written as four decimal octets. A **prefix length** says how many leading bits identify the network:

| Notation | Netmask | Addresses per network | Usable hosts |
|---|---|---|---|
| `/24` | `255.255.255.0` | 256 | 254 |
| `/25` | `255.255.255.128` | 128 | 126 |
| `/16` | `255.255.0.0` | 65,536 | 65,534 |
| `/8` | `255.0.0.0` | 16,777,216 | 16,777,214 |

Two addresses in each network are reserved: the network address and the broadcast address. On the lab, `10.10.10.10/24` means the network is `10.10.10.0`, the broadcast is `10.10.10.255`, and the usable range is `.1` through `.254`. `server` and `node2` are two hosts in it.

Other pieces:

| Piece | Purpose | Lab value |
|---|---|---|
| Default gateway | Where traffic for other networks goes | The libvirt NAT address, on the management interface |
| DNS resolver | Turns names into addresses | Configured by NetworkManager |
| `/etc/hosts` | Static local name overrides | `10.10.10.10 server`, `10.10.10.11 node2` |
| `/etc/resolv.conf` | Resolver configuration | Generated; do not edit by hand |

### Inspecting the network

```bash
ip -br a
ip route
hostnamectl
getent hosts server node2
cat /etc/resolv.conf
```

```text { .no-copy }
lo               UNKNOWN        127.0.0.1/8 ::1/128
eth0             UP             192.168.121.45/24
eth1             UP             10.10.10.10/24
default via 192.168.121.1 dev eth0 proto dhcp src 192.168.121.45 metric 100
10.10.10.0/24 dev eth1 proto kernel scope link src 10.10.10.10
```

Interface names on modern RHEL-family systems are predictable: `eth0`, `ens3`, `enp1s0`, not necessarily `eth0`. The lab uses virtio devices, so `eth0` and `eth1` are typical. `nmcli device status` shows what NetworkManager thinks of each:

```bash
nmcli device status
nmcli connection show
```

The private interface is managed by the `lab-private` connection profile that F2 described. R9 creates and modifies profiles like it with `nmcli`.

`/etc/resolv.conf` on a NetworkManager system is generated. Editing it works until the next connection event, then your changes disappear. Put DNS configuration in the connection profile instead:

```bash
nmcli connection show lab-private | grep ipv4
```

### Ports and sockets

A **port** identifies a service on a host. The pair (address, port, protocol) is a **socket**.

| Port | Service |
|---|---|
| 22 | SSH |
| 53 | DNS |
| 80 | HTTP |
| 443 | HTTPS |
| 25 | SMTP |
| 123 | NTP |

```bash
ss -tuln
sudo ss -tulpn
ss -tan
```

| Flag | Meaning |
|---|---|
| `-t` | TCP |
| `-u` | UDP |
| `-l` | Listening sockets |
| `-n` | Numeric addresses and ports |
| `-p` | Process name and PID (root for other users' sockets) |
| `-a` | All sockets |

On the lab you should see port 22 listening on all addresses. If a service is "running" but nothing listens, it either failed to bind, bound to `127.0.0.1` only, or the firewall is blocking the connection from outside.

```bash
ping -c 2 node2
ssh -o BatchMode=yes -o ConnectTimeout=2 labuser@node2 true && echo "ssh works"
```

`ping` tests ICMP reachability. A TCP test such as `ssh` proves more: routing, the listener, and the firewall all have to cooperate. R9 configures `firewalld`; for now treat a blocked port as a firewall question, not a broken service.

### IPv6, briefly

IPv6 addresses are 128 bits, written as eight groups of four hex digits. `::` collapses one run of zeros. Link-local addresses begin with `fe80::` and exist on every interface automatically.

```bash
ip -6 addr show
ip -6 route
```

The lab disables IPv6 on the private interface for simplicity, so you will mostly see it on `lo`. R9 covers IPv6 configuration for the exam.

## Storage

### The stack

Storage is layered. Each layer has to exist before the next one can be used.

```text { .no-copy }
physical disk          /dev/vda, /dev/vdb
      ↓
partition table        GPT or MBR
      ↓
partition              /dev/vda1, /dev/vdb1
      ↓
filesystem             XFS, ext4, VFAT, swap
      ↓
mount point            /, /home, /var, /mnt/data
```

R6 creates partitions, LVM volumes, filesystems, and swap. R7 adds VFAT, NFS, autofs, and filesystem repair. This module teaches you to *see* the stack.

### Seeing disks, partitions, and filesystems

```bash
lsblk
lsblk -f
df -hT
findmnt /
sudo blkid
```

| Tool | Answers |
|---|---|
| `lsblk` | What block devices and partitions exist? |
| `lsblk -f` | What filesystem and UUID is on each? |
| `df -hT` | What is mounted, how full, and with which filesystem type? |
| `findmnt` | What is mounted where, and with which options? |
| `blkid` | What are the UUIDs and labels? (root) |

The lab's second disk, `/dev/vdb`, is attached and empty. `lsblk` shows it with no filesystem, which is why R6 exists: it needs a partition table, a partition, and a filesystem before it can hold data.

Device names matter and are not stable. `/dev/sdb` may become `/dev/sdc` when disks are added or reordered. That is why `/etc/fstab` should use `UUID=` or `LABEL=` rather than a device path. `blkid` prints the UUID.

### Mounting and unmounting

Mounting attaches a filesystem at a directory. The directory must already exist, and anything that was in it before is hidden until you unmount.

```bash
sudo mkdir -p /mnt/demo
sudo mount -t tmpfs -o size=16M tmpfs /mnt/demo
df -h /mnt/demo
findmnt /mnt/demo
sudo cp /etc/hosts /mnt/demo/
ls -l /mnt/demo
sudo umount /mnt/demo
ls -l /mnt/demo
```

`tmpfs` lives in RAM. The file you copied disappears on unmount because the mount point returns to being an empty directory on the root filesystem.

A mount made this way exists only until reboot. Persistence requires an entry in `/etc/fstab`:

```text { .no-copy }
UUID=abcd-1234  /mnt/data  xfs  defaults  0 0
```

| Field | Meaning |
|---|---|
| Device | `UUID=`, `LABEL=`, or a device path |
| Mount point | Absolute directory |
| Type | `xfs`, `ext4`, `vfat`, `nfs`, `swap`, ... |
| Options | `defaults`, `ro`, `noatime`, `_netdev`, ... |
| Dump | Usually `0` |
| Pass | `fsck` order: `0` for no check, `1` for root, `2` for others |

Always test an `fstab` change before rebooting:

```bash
sudo mount -a
sudo findmnt --verify
```

A broken entry can leave the system in emergency mode at boot. R6 and R11 cover the repair path.

### Filesystem types

| Type | Typical use |
|---|---|
| `xfs` | Default for RHEL. Cannot shrink. |
| `ext4` | General purpose. Can grow and shrink. |
| `vfat` | EFI system partition and removable media. |
| `swap` | Paging and hibernation. Not mounted as a directory. |
| `tmpfs` | RAM-backed temporary storage. |
| `nfs` | Network filesystem from another host. |

### Space and inodes

`df` reports filesystem-level usage; `du` reports what a directory tree actually uses:

```bash
df -h
df -i
du -sh /var/log
sudo du -h --max-depth=1 /var | sort -h | tail
```

The unprivileged `du` prints a few `Permission denied` lines for subdirectories like `/var/log/audit`, so its total understates the tree; the `sudo` line sees everything.

If `df` says a filesystem is full while `du` does not, look for **deleted files that are still open**:

```bash
sudo lsof +L1
```

The space returns only when the process closes the file. Restarting the service releases it.

`df -i` reports inode usage. Running out of inodes fills the filesystem while `df -h` still shows free bytes, which happens with many tiny files.

Swap is not a mount point in the usual sense:

```bash
free -h
swapon --show
```

The cloud image may have no swap configured. R6 creates a swap logical volume and adds it to `/etc/fstab`.

## SELinux

### What it adds

Standard permissions answer "which user and group may access this inode?". SELinux answers a different question: "is this *process* allowed to use this *type of object*?" It is **mandatory access control**: even root is constrained by policy.

Every process and every file has a **security context**:

```text { .no-copy }
system_u:object_r:sshd_t:s0
```

| Part | Meaning |
|---|---|
| User | SELinux user, not the Linux account |
| Role | Intermediate role, mostly for RBAC |
| Type | The part that does the work in targeted policy |
| Level | MLS/MCS sensitivity, `s0` on ordinary systems |

Targeted policy, the RHEL default, confines selected services such as `sshd`, `httpd`, and `named`. Unconfined processes such as your shell run as `unconfined_t` but are still subject to file-type checks when they touch confined resources.

### Inspecting labels

```bash
getenforce
sestatus
id -Z
ls -Zd /etc /var/log /home /tmp
ps -ZC sshd
```

`getenforce` prints one word. `sestatus` prints a short block that also names the policy and its mode:

```text { .no-copy }
Enforcing
SELinux status:                 enabled
SELinuxfs mount:                /sys/fs/selinux
Current mode:                   enforcing
Policy from config file:        targeted
```

The remaining commands print contexts:

```text { .no-copy }
unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
system_u:object_r:etc_t:s0 /etc
system_u:object_r:var_log_t:s0 /var/log
system_u:object_r:home_root_t:s0 /home
system_u:object_r:tmp_t:s0 /tmp
LABEL                                     PID TTY          TIME CMD
system_u:system_r:sshd_t:s0-s0:c0.c1023  1094 ?   00:00:00 sshd
```

The type is what matters in practice. A file in `/var/log` is `var_log_t`, and a service allowed to write `var_log_t` can write it; a service not allowed to cannot, regardless of the `rwx` bits.

Use `ps -ZC sshd` rather than `ps -Z | grep sshd`. The plain form also matches `sshd-session`, the per-login child process that runs with *your* user context, so the first line it prints is `unconfined_t` and looks wrong. The listener — the process that owns the service — is the one with `sshd_t`.

### Modes

| Mode | Effect |
|---|---|
| Enforcing | Policy is applied and denials are logged |
| Permissive | Policy is checked and denials are logged, but access is allowed |
| Disabled | No policy at all; requires a reboot and a relabel to re-enable |

```bash
getenforce
sudo setenforce 0     # temporary: permissive until reboot
sudo setenforce 1     # back to enforcing
```

Permissive mode is a diagnostic tool: it tells you whether SELinux is the cause without changing any files. Never leave a system permissive, and never disable SELinux to make a lab pass. The exam runs with it enforcing.

### Why labels get wrong

Labels come from policy rules in `/etc/selinux/targeted/contexts/files/file_contexts`, applied when a file is created in a directory. Two operations behave differently:

- `cp` creates a new file in the destination, so it inherits the **destination directory's** default type.
- `mv` within the same filesystem preserves the inode and its **existing** label.

That is the single most common SELinux surprise. A configuration file moved from `/root` into a web directory keeps `admin_home_t`, and the web server is denied.

Fix a wrong label with `restorecon`, which reapplies the policy default:

```bash
sudo restorecon -Rv /var/www/html
ls -Z /var/www/html
```

For a location that has no policy rule, `semanage fcontext` adds one, then `restorecon` applies it:

```bash
sudo semanage fcontext -a -t httpd_sys_content_t '/srv/web(/.*)?'
sudo restorecon -Rv /srv/web
```

`semanage` comes from `policycoreutils-python-utils`, which is not installed by default. R10 covers this workflow, including booleans:

```bash
getsebool -a | head
sudo setsebool -P httpd_can_network_connect on
```

`-P` makes the boolean persistent across reboots. Without it, the change is gone after a restart.

### Reading a denial

When SELinux blocks something, it writes an **AVC denial**:

```bash
sudo ausearch -m AVC -ts recent
journalctl -t audit -n 20 --no-pager
```

A denial names the source context, the target context, and the permission that was refused. It is evidence, not noise: the fix is usually a label, a boolean, or a policy module, in that order. Disabling SELinux destroys the evidence and fails the exam's expectations.

## Lab: map the machine

Log in to `server` and switch to the lab user:

```bash
sudo su - labuser
```

### 1. Addresses and routing

```bash
ip -br a
ip route
hostnamectl
getent hosts server node2
cat /etc/hosts
```

Identify which interface carries `10.10.10.10`, which one carries the default route, and where name resolution for `node2` comes from.

### 2. Services and ports

```bash
ss -tuln
sudo ss -tulpn | head
nmcli device status
ping -c 2 node2
ssh -o BatchMode=yes -o ConnectTimeout=2 labuser@node2 'hostname'
```

You should see SSH listening and a successful cross-VM SSH. `hostname` on the far end prints `node2`, which proves you reached the other machine.

### 3. Disks and filesystems

```bash
lsblk
lsblk -f
df -hT
findmnt /
sudo blkid
```

`/dev/vdb` appears with no filesystem. That is the disk R6 will partition. Do not format it now.

### 4. Mount something temporary

```bash
sudo mkdir -p /mnt/demo
sudo mount -t tmpfs -o size=16M tmpfs /mnt/demo
df -h /mnt/demo
sudo cp /etc/hosts /mnt/demo/
ls -l /mnt/demo
sudo umount /mnt/demo
ls -l /mnt/demo
```

The file is gone after `umount`. You have now seen the difference between "a directory" and "a mounted filesystem".

### 5. Space and inodes

```bash
df -h
df -i
du -sh /var/log
sudo du -h --max-depth=1 /var | sort -h | tail
free -h
swapon --show
```

The unprivileged `du` reports `Permission denied` for subdirectories such as `/var/log/audit` and understates the tree; the `sudo` line does not.

If `swapon --show` prints nothing, the lab has no swap. That is worth knowing before R6 adds some.

### 6. SELinux state and labels

```bash
getenforce
sestatus | head
id -Z
ls -Zd /etc /var/log /home /tmp
ps -ZC sshd
```

Confirm that the system is enforcing and that every file has a type. Note that your shell is `unconfined_t` while the `sshd` listener is `sshd_t`.

### 7. Reproduce the label problem

```bash
echo "label demo" > /tmp/f8-label.txt
cp /tmp/f8-label.txt ~/f8-copied.txt
mv /tmp/f8-label.txt ~/f8-moved.txt
ls -Z ~/f8-*.txt
```

The copied file has the home-directory type. The moved file kept the `/tmp` type, because `mv` renamed the inode. Now relabel:

```bash
sudo restorecon -Rv ~
ls -Z ~/f8-*.txt
```

Both files now have the home type. This is exactly what happens when a file is moved into a web root, a home directory for SSH keys, or a directory a service must write.

### 8. Look for denials

```bash
sudo ausearch -m AVC -ts recent
sudo journalctl -t audit -n 10 --no-pager
```

On a clean system there may be nothing to show. That is fine; you are learning where to look. R10 creates a denial on purpose and walks through the fix.

### 9. Clean up

```bash
rm -f ~/f8-copied.txt ~/f8-moved.txt
sudo rmdir /mnt/demo 2>/dev/null || true
```

## Common traps

| Trap | What happens | Fix |
|---|---|---|
| Configuring an address with `ip addr add` | It disappears at reboot | Use `nmcli`, which persists (R9) |
| Editing `/etc/resolv.conf` | NetworkManager overwrites it | Set DNS on the connection |
| Adding a mount without `fstab` | Works until reboot, then the data is unreachable | Add a UUID entry and test with `mount -a` |
| Using `/dev/sdb` in `fstab` | The name changes when disks are added | Use `UUID=` or `LABEL=` |
| `setenforce 0` to "fix" a service | Security is off, and the real cause remains | Read the AVC, fix the label or boolean |
| Moving a file into a service directory | The label stays with the inode | `restorecon -Rv` after the move, or `cp` |
| Adding a boolean without `-P` | It reverts at reboot | `setsebool -P` |
| Filling `/` or `/var` | Services fail, logs stop, the system may not boot | Monitor `df -h` and `df -i` |
| Trusting `du` alone | Deleted-but-open files hide usage | `lsof +L1` |

## Self-check

Answer first, then open the answer.

### 1. Prefix length

What does `10.10.10.10/24` tell you about the network, and how many hosts can it hold?

??? question "Answer"
    The first 24 bits are the network, `10.10.10.0`, and the mask is `255.255.255.0`. There are 256 addresses, of which 254 are usable after the network and broadcast addresses.

### 2. Gateway and DNS

What is the difference between a default gateway and a DNS resolver?

??? question "Answer"
    The gateway routes traffic to networks the host does not have a direct route for. The resolver turns hostnames into addresses. They are often different hosts and different addresses.

### 3. Listening sockets

A service is active, but `ssh` from `node2` is refused. Name two likely causes.

??? question "Answer"
    The service may be listening only on `127.0.0.1` or a different port, which `ss -tuln` reveals, or `firewalld` may be blocking port 22. A failed bind would also leave nothing listening.

### 4. Storage layers

Put these in order and explain the relationship: filesystem, partition, mount point, disk.

??? question "Answer"
    Disk, partition, filesystem, mount point. The disk provides the device, the partition table divides it, the filesystem organizes the partition's blocks, and the mount point attaches that filesystem to the directory tree.

### 5. UUID

Why does `/etc/fstab` prefer `UUID=` over `/dev/vdb1`?

??? question "Answer"
    Device names depend on discovery order and can change when hardware is added or reordered. A UUID is stored in the filesystem and identifies it regardless of the device name.

### 6. Mount versus directory

You mount a filesystem at `/mnt/demo` that already contains files. What happens to them, and what happens when you unmount?

??? question "Answer"
    The mount hides the existing directory contents. They are not deleted; they reappear when you unmount. This is why a full root filesystem can look empty at a mount point.

### 7. `df` and `du`

`df -h` says a filesystem is 100% full, but `du -sh` on its directories adds up to far less. What is the likely cause?

??? question "Answer"
    A deleted file is still open by a process. The inode and its blocks are not freed until the process closes it. `lsof +L1` lists those files, and restarting the process releases the space.

### 8. SELinux types

Why can `ls -l` show `rw-r--r--` and access still be denied?

??? question "Answer"
    The classic bits are only one check. SELinux also compares the process type with the file type and the requested permission. If policy does not allow that pair, the operation is denied even for root, and an AVC is logged.

### 9. `cp` versus `mv`

Why does moving a configuration file into a service directory often break the service, while copying it does not?

??? question "Answer"
    `mv` within a filesystem preserves the inode and its SELinux label, so the file keeps the type it had in the old location. `cp` creates a new file in the destination directory, which inherits that directory's default type. `restorecon` fixes the moved file.

### 10. Booleans

What does `setsebool -P` add over `setsebool` without `-P`?

??? question "Answer"
    `-P` writes the setting to policy so it survives a reboot. Without it, the change applies only until the next boot.

## Next

You have finished the foundations. Continue to [R1 — Essential tools](../../rhcsa/r01-essential-tools/index.md), which turns these concepts into exam tasks with guided labs, a challenge, and an automated checker.

If any self-check felt shaky, reread that section before starting R1. The modules are independent enough to revisit later, but R1 assumes you can read a command, quote an argument, and find a man page.
