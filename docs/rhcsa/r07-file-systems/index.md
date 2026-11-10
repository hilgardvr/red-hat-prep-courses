# R7 — File systems and sharing

<div class="module-meta" markdown>

| | |
|---|---|
| **Exam objective group** | 6 — Create and configure file systems |
| **Time** | 4–5 hours including labs |
| **Prerequisites** | [R1 — Essential tools](../r01-essential-tools/index.md) and [R6 — Local storage](../r06-local-storage/index.md), especially [mounting at boot](../r06-local-storage/index.md#mounting-at-boot-etcfstab) |
| **Labs** | 2 guided labs + 1 challenge |
| **Check command** | `./bin/lab check r07 lab1` (also `lab2` and `challenge`) |

</div>

R6 built storage: partitions and logical volumes with XFS and ext4 on them. R7 makes that storage **portable and shared**. You will format a USB-style VFAT filesystem, export a directory over NFS, mount it automatically with autofs, grow an ext4 filesystem while it is in use, and repair filesystems with the tools that exist for exactly that.

The new idea in this module is that a filesystem is not only a container for files. It is also a **contract**: VFAT has no Unix permissions at all, NFS trusts a client's identity only as far as its export options allow, and autofs mounts nothing until someone touches the path. Most of the exam-style mistakes here come from assuming ext4 semantics on a filesystem that does not have them.

## Objective checklist

By the end of this module you should be able to:

- [ ] Create and mount XFS, ext4, and VFAT filesystems
- [ ] Supply ownership and permissions for VFAT through mount options
- [ ] Export a directory over NFS and limit who may mount it
- [ ] Open the firewall for NFS, and prove the export with `showmount`
- [ ] Mount an NFS export by hand and at boot
- [ ] Configure autofs so an NFS mount happens on first access
- [ ] Explain `root_squash` and recognise `nobody` ownership
- [ ] Diagnose and correct a file-permission problem on a shared filesystem
- [ ] Repair an ext4 or XFS filesystem offline with the right tool
- [ ] Grow an existing logical volume and its ext4 filesystem without data loss
- [ ] Prove every one of those changes survives a reboot

!!! note "Read it; do not memorise it"
    This page is a reference you will return to, not a list to learn by heart. The labs are where the commands become yours.

    Command blocks have a copy button. Blocks **without** one are output: they show what a command printed and are there to compare against, not to paste into a shell.

---

## Choosing a filesystem

RHEL ships three filesystems you are expected to know for this objective, and they are not interchangeable.

| | XFS | ext4 | VFAT |
|---|---|---|---|
| Journaling | Yes | Yes | No |
| Unix permissions | Yes | Yes | **No** |
| Symlinks and hard links | Yes | Yes | **No** |
| Case-sensitive names | Yes | Yes | **No** |
| Maximum file size | 8 EiB | 16 TiB | 4 GiB (FAT32) |
| Can grow | Yes, online | Yes, online | Not really |
| Can shrink | **No** | Yes, offline | No |
| Typical use | RHEL default, large files | Older RHEL, shrinkable data | USB sticks, EFI, camera cards |

The exam names all three. The labs use one of each so the differences are concrete rather than a table to memorise.

!!! tip "VFAT is the odd one out"
    VFAT was designed to be simple and portable, not to be a Unix filesystem. It stores no owner, no group, and no mode bits. Everything `ls -l` shows about ownership and permissions on a VFAT mount is **invented by the kernel from the mount options**. That is why `chmod` appears to succeed and changes nothing.

---

## VFAT

Create a VFAT filesystem with `mkfs.vfat` (the same command as `mkfs.fat`):

```bash
mkfs.vfat -F 32 -n R7DATA /dev/vdb1
```

| Option | Meaning |
|---|---|
| `-F 32` | FAT32. Use it for anything above a floppy; `-F 16` and `-F 12` exist for tiny media |
| `-n R7DATA` | Volume label, up to 11 characters, stored in the boot sector |
| `/dev/vdb1` | The partition to format |

`-F 32` matters: FAT32 is what Windows, cameras, and firmware expect for removable media. The label is what `blkid` shows as `LABEL` and what `LABEL=` in fstab can find.

### Ownership comes from the mount

Mount a VFAT filesystem without options and root owns every file. Fix that with mount options:

```bash
UUID=FBF7-223A /srv/r7/vfat vfat defaults,uid=labuser,gid=labuser,umask=0077 0 0
```

| Option | Effect |
|---|---|
| `uid=labuser` | Every file appears owned by `labuser` |
| `gid=labuser` | Every file appears in group `labuser` |
| `umask=0077` | Owner gets `rwx`; group and others get nothing |
| `fmask=0133` / `dmask=0022` | Set file and directory masks separately |

`umask=` is shorthand for setting both `fmask` and `dmask`. The kernel applies the mask to a synthetic `0777` (files) and `0777` (directories), which is why a fresh file shows `-rwx------` with `umask=0077`.

`findmnt` prints the numeric UID even though you wrote a name:

```text { .no-copy }
/dev/vdb1 vfat rw,relatime,uid=1001,gid=1001,fmask=0077,dmask=0077,codepage=437,iocharset=ascii,shortname=mixed,errors=remount-ro
```

### What VFAT cannot do

- **No `chmod`.** The command exits 0 and `ls -l` does not change, because there is nowhere to store the mode.
- **No symlinks.** `ln -s` fails with `Operation not permitted`.
- **No hard links.**
- **No case distinction.** `CaseFile.txt` and `casefile.txt` are the same file.
- **No Unix ownership.** `chown` is meaningless; use `uid=` and `gid=` at mount time.

These limits are why VFAT is for exchange, not for a server's data directory.

---

## Mounting, again

R6 covered fstab in detail. Three additions matter when the filesystem is shared or removable.

```bash
mount -t nfs 10.10.10.10:/srv/r7/export /mnt/r7-nfs
umount /mnt/r7-nfs
```

`mount` normally guesses the type from the device or the fstab entry. With NFS the "device" is `server:/path`, so state `-t nfs` when mounting by hand; the kernel will negotiate NFSv4.

| fstab option | Why it exists |
|---|---|
| `_netdev` | Wait for the network before mounting; without it, boot may hang on a network filesystem |
| `nofail` | Do not drop to emergency mode if the server is unreachable |
| `noauto` | Record the entry but do not mount it at boot |
| `defaults` | `rw,suid,dev,exec,auto,nouser,async` |

A network mount in fstab usually wants both:

```text { .no-copy }
10.10.10.10:/srv/r7/export /mnt/r7-nfs nfs defaults,_netdev,nofail 0 0
```

After any fstab edit: `systemctl daemon-reload`, `mount -a`, `findmnt --verify` — the same loop as R6.

---

## NFS

**NFS** (Network File System) lets one machine's directory appear on another. RHEL 10 uses NFSv4 by default: a single TCP port, 2049, with a pseudo-filesystem that lets the server present several exports under one root.

### The server

```bash
dnf install -y nfs-utils
systemctl enable --now nfs-server
```

The export table is `/etc/exports`. One line per export:

```text { .no-copy }
/srv/r7/export 10.10.10.0/24(rw,sync,no_subtree_check)
```

| Part | Meaning |
|---|---|
| `/srv/r7/export` | The directory being shared |
| `10.10.10.0/24` | Which clients may mount it. A hostname, an IP, or a network |
| `rw` | Read-write. The default is `ro` |
| `sync` | Reply only after the write is on disk |
| `no_subtree_check` | Do not verify that the file is under the exported subtree; faster, and the default in modern NFS |
| `root_squash` | Map client UID 0 to `nobody`. On by default; **keep it** |

Apply and inspect:

```bash
exportfs -rav
exportfs -v
showmount -e localhost
```

| Command | What it does |
|---|---|
| `exportfs -rav` | Re-read `/etc/exports`, export everything, verbose |
| `exportfs -v` | Show the effective options, including defaults you did not type |
| `showmount -e <host>` | Ask a server what it exports. The client-side test |

`exportfs -v` is the honest view. It prints the defaults applied to your line:

```text { .no-copy }
/srv/r7/export	10.10.10.0/24(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)
```

Restarting `nfs-server` also re-reads the file, but `exportfs -rav` is faster and does not interrupt other clients.

### The firewall

NFS needs more than port 2049. Mounting uses `mountd`, and older negotiation uses `rpc-bind`:

```bash
firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=mountd
firewall-cmd --permanent --add-service=rpc-bind
firewall-cmd --reload
```

```text { .no-copy }
cockpit dhcpv6-client mountd nfs rpc-bind ssh
```

Open `nfs` alone and the port is reachable but mounting fails with `access denied by server`, because `mountd` is still blocked. That error is a firewall problem, not an exports problem.

### The client

```bash
dnf install -y nfs-utils
mkdir -p /mnt/r7-nfs
mount -t nfs 10.10.10.10:/srv/r7/export /mnt/r7-nfs
findmnt /mnt/r7-nfs
```

```text { .no-copy }
TARGET      SOURCE                     FSTYPE OPTIONS
/mnt/r7-nfs 10.10.10.10:/srv/r7/export nfs4   rw,relatime,vers=4.2,rsize=524288,wsize=524288,namlen=255,hard,fatal_neterrors=none,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=10.10.10.11,local_lock=none,addr=10.10.10.10
```

`findmnt` shows `nfs4`, `vers=4.2`, and `sec=sys`: the kernel negotiated NFSv4.2 and is using UID/GID-based security.

### `root_squash` and `nobody`

Write to the export **as root** on the client and look at the owner on the server:

```text { .no-copy }
-rw-r--r--. 1 nobody  nobody  system_u:object_r:var_t:s0 19 Nov 10 05:46 from-node2.txt
```

That is `root_squash` working. The client's UID 0 is not trusted; the server maps it to `nobody`. A normal user's UID is passed through unchanged, so a file written by `labuser` is owned by `labuser` on both machines.

This is a security feature, not a bug. `no_root_squash` exists for a reason — exporting a home directory to a trusted backup server, for example — but it lets any root on any allowed client write as root on the server. Do not add it to solve a permission problem; fix the directory's ownership instead.

### Permission problems on NFS

The common failures, in the order to check them:

| Symptom | Check |
|---|---|
| `Permission denied` writing as a normal user | Directory permissions on the **server**: `ls -ld /srv/r7/export` |
| `Permission denied` writing as root | `root_squash` is on; write as a normal user, or change ownership on the server |
| `access denied by server` | Client address not in `/etc/exports`, or `mountd` blocked by the firewall |
| `No such file or directory` mounting | The export path is wrong, or `exportfs -rav` was not run |
| Files appear as `nobody` | Expected for root; unexpected means the client UID does not exist on the server |

SELinux adds one more layer. The export directory must carry a context NFS is allowed to share; `/srv` is `var_t`, and the booleans `nfs_export_all_ro` and `nfs_export_all_rw` are on by default on this lab. If an export works on the server but fails on the client with `Permission denied` and permissions look correct, compare `ls -Z` on both sides. R10 covers `semanage fcontext` in detail.

---

## autofs

Mounting every possible NFS share in fstab does not scale, and a dead server at boot is an emergency-mode risk. **autofs** mounts a filesystem only when someone accesses its path, and unmounts it after a period of disuse.

### The maps

autofs reads **master maps** and **automount maps**. RHEL splits the master map into drop-ins under `/etc/auto.master.d/`:

```text { .no-copy }
/mnt/r7auto /etc/auto.r7
```

That line says: for paths under `/mnt/r7auto`, use the map `/etc/auto.r7`.

The map itself has one line per key:

```text { .no-copy }
share -rw,sync 10.10.10.10:/srv/r7/export
```

| Field | Meaning |
|---|---|
| `share` | The subdirectory created under the mount point |
| `-rw,sync` | Mount options; `-fstype=nfs4` may be added |
| `10.10.10.10:/srv/r7/export` | The NFS source |

Accessing `/mnt/r7auto/share` triggers the mount. `ls /mnt/r7auto` shows nothing until something triggers a key — the directory is a mount point, not a listing of what could be mounted.

### Applying a map

```bash
dnf install -y autofs
systemctl enable --now autofs
systemctl restart autofs
ls /mnt/r7auto/share
findmnt /mnt/r7auto/share
```

Restart `autofs` after changing any map; it does not watch the files. `systemctl reload autofs` also works.

### Direct and wildcard maps

An **indirect** map, like the one above, creates keys under a common directory. A **direct** map mounts absolute paths:

```text { .no-copy }
/- /etc/auto.direct
```

```text { .no-copy }
/mnt/r7auto/share -rw,sync 10.10.10.10:/srv/r7/export
```

A **wildcard** key mounts any name under the parent:

```text { .no-copy }
* -rw,sync 10.10.10.10:/exports/&
```

`&` is replaced by the key, so `/mnt/r7auto/team1` becomes `/exports/team1`. This is how a server with many home directories is presented with one map line.

The built-in `/net` map, enabled by the default `/etc/auto.master`, mounts any host's export on demand at `/net/<host>/<path>`. It is handy and usually left alone.

### autofs versus fstab

| | fstab | autofs |
|---|---|---|
| Mounts at boot | Yes | No, only on access |
| Dead server at boot | Emergency mode risk | No effect until accessed |
| Good for | Storage the system needs | Home directories, many clients, optional shares |
| Proof | `findmnt` after reboot | Access the path, then `findmnt` |

---

## Repairing filesystems

A filesystem that was not unmounted cleanly, or that lost power mid-write, needs a check. The tools depend on the filesystem, and **both refuse or misbehave on a mounted filesystem**.

| Filesystem | Check | Dry run | Notes |
|---|---|---|---|
| ext4 | `e2fsck -f /dev/...` | `e2fsck -fn /dev/...` | `-f` forces a check even if the superblock says clean |
| XFS | `xfs_repair /dev/...` | `xfs_repair -n /dev/...` | Needs the filesystem unmounted; `-n` only reports |
| Any | `fsck /dev/...` | — | A wrapper that picks the right tool from the superblock |

```bash
umount /srv/r7/data
e2fsck -f /dev/r7vg/r7data
mount -a
```

`e2fsck` interacts with you when it finds problems. In a script, `-p` preens (fixes only safe things) or `-y` answers yes to everything. `-n` answers no to everything, so it reports without changing the filesystem — the safe way to inspect a device whose data matters.

Exit codes carry meaning:

| Code | Meaning |
|---|---|
| 0 | No errors |
| 1 | Errors corrected |
| 2 | Errors corrected, reboot required |
| 4 | Errors left uncorrected |
| 8 | Operational error (wrong device, mounted, no terminal) |

XFS journals replay automatically at mount; `xfs_repair` is for damage the journal cannot fix. XFS has no `fsck` that repairs at boot in the ext4 sense, which is one reason RHEL treats it as the default for system filesystems.

!!! danger "Never check a mounted filesystem"
    `e2fsck` and `xfs_repair` write to the device. On a mounted filesystem that corrupts data. Unmount first; if the filesystem is `/`, boot from rescue media (R11). `e2fsck -n` and `xfs_repair -n` are read-only and safe to run, but they are not repairs.

---

## Growing and shrinking

R6 grew XFS on a logical volume. R7 adds the ext4 half of the same objective.

### Growing ext4 online

```bash
lvextend -L +512M /dev/r7vg/r7data
resize2fs /dev/r7vg/r7data
df -h /srv/r7/data
```

```text { .no-copy }
The filesystem on /dev/r7vg/r7data is now 262144 (4k) blocks long.

Filesystem               Size  Used Avail Use% Mounted on
/dev/mapper/r7vg-r7data  991M  101M  835M  11% /srv/r7/data
```

Order matters: **grow the block device first, then the filesystem**. `resize2fs` can grow a mounted ext4 filesystem online, which is why the file written before the grow is still readable afterwards. XFS is the same idea with `xfs_growfs <mount point>`.

### Shrinking ext4

ext4 can shrink, but only offline, and only after a check:

```bash
umount /srv/r7/data
e2fsck -f /dev/r7vg/r7data
resize2fs /dev/r7vg/r7data 512M
mount -a
```

Shrinking is not part of this module's challenge, and it is not something to do casually: the new size must still hold every block in use, and the logical volume must be reduced **after** the filesystem. XFS cannot shrink at all. The exam's wording is "extend", so growing is the skill to practise.

---

## Common traps

| Trap | What happens | Fix |
|---|---|---|
| Expecting `chmod` to work on VFAT | The command succeeds, the mode does not change | Set `uid=`, `gid=`, `umask=` at mount time |
| Creating a symlink on VFAT | `Operation not permitted` | Use a Unix filesystem, or copy the file |
| Mounting NFS without `_netdev` | Boot may hang waiting for the network | Add `_netdev` (and usually `nofail`) |
| Firewall opens only `nfs` | Mount fails with `access denied by server` | Add `mountd` and `rpc-bind` |
| Writing as root over NFS | Files owned by `nobody` | `root_squash` is doing its job; write as a user |
| Leaving `no_root_squash` on | Any root on any allowed client is root on the server | Remove it; fix ownership instead |
| Editing `/etc/exports` but not exporting | Clients see the old export | `exportfs -rav` |
| autofs map changed, not restarted | Old map still in effect | `systemctl restart autofs` |
| Accessing the parent of an indirect map | `ls /mnt/r7auto` is empty | Access the key: `/mnt/r7auto/share` |
| Running `e2fsck` on a mounted filesystem | Corruption | `umount` first; use `-n` to inspect |
| Growing the filesystem before the LV | `resize2fs` has nothing to claim | `lvextend`, then `resize2fs` |
| Running `xfs_growfs` on a device | `not a mounted XFS filesystem` | Pass the mount point |

---

## Next

[Lab 1 — A VFAT volume](labs/lab-1-vfat.md) builds a VFAT partition and mounts it with ownership supplied by the kernel. [Lab 2 — NFS and autofs](labs/lab-2-nfs-autofs.md) exports a directory from `server` and automounts it on `node2`. The [challenge](labs/challenge-grow-ext4.md) grows an ext4 logical volume and its filesystem while it is mounted, and proves the data survived.
