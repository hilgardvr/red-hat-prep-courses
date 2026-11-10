# R7 cheat sheet

A compact reference for review. Everything here is explained in the [theory page](index.md).

## Filesystem choice

| | XFS | ext4 | VFAT |
|---|---|---|---|
| Unix permissions | Yes | Yes | **No** |
| Symlinks | Yes | Yes | **No** |
| Case-sensitive | Yes | Yes | **No** |
| Grow | Online | Online | — |
| Shrink | Never | Offline | — |
| Check tool | `xfs_repair` | `e2fsck` | none |
| Use | RHEL default | Shrinkable data | USB, EFI |

## VFAT

| Task | Command |
|---|---|
| Format | `mkfs.vfat -F 32 -n R7DATA /dev/vdb1` |
| Identify | `blkid /dev/vdb1` |
| Mount options | `uid=`, `gid=`, `umask=`, or `fmask=` + `dmask=` |

```text { .no-copy }
UUID=FBF7-223A /srv/r7/vfat vfat defaults,uid=labuser,gid=labuser,umask=0077 0 0
```

| Cannot do | What you see |
|---|---|
| `chmod` / `chown` | Command succeeds; `ls -l` unchanged |
| `ln -s` | `Operation not permitted` |
| Distinguish case | `CaseFile.txt` opens as `casefile.txt` |

`findmnt` prints `uid=`/`gid=` as numbers and `umask=` as `fmask=` plus `dmask=`.

## NFS server

```bash
dnf install -y nfs-utils
systemctl enable --now nfs-server
```

```text { .no-copy }
/srv/r7/export 10.10.10.0/24(rw,sync,no_subtree_check)
```

| Option | Meaning |
|---|---|
| `ro` / `rw` | Read-only (default) or read-write |
| `sync` / `async` | Reply after disk write / before |
| `no_subtree_check` | Skip subtree verification; modern default |
| `root_squash` | Client UID 0 becomes `nobody`; default, keep it |
| `no_root_squash` | Client root is server root; avoid |
| `no_all_squash` | Keep other UIDs; default |

| Task | Command |
|---|---|
| Re-export, verbose | `exportfs -rav` |
| Effective options | `exportfs -v` |
| What does this server export? | `showmount -e <host>` |
| Re-read exports | `exportfs -ra` or restart `nfs-server` |

Firewall — all three are needed:

```bash
firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=mountd
firewall-cmd --permanent --add-service=rpc-bind
firewall-cmd --reload
```

## NFS client

```bash
mount -t nfs 10.10.10.10:/srv/r7/export /mnt/r7-nfs
findmnt /mnt/r7-nfs
umount /mnt/r7-nfs
```

```text { .no-copy }
10.10.10.10:/srv/r7/export /mnt/r7-nfs nfs defaults,_netdev,nofail 0 0
```

`_netdev` waits for the network; `nofail` keeps a dead server from dropping boot into emergency mode.

| Symptom | Cause |
|---|---|
| `Permission denied` as root | `root_squash`; write as a normal user |
| `Permission denied` as a user | Directory mode or owner on the server |
| `access denied by server` | Client not in exports, or `mountd` blocked |
| Files owned by `nobody` | Squashed root, or the client UID is unknown on the server |

## autofs

| File | Content |
|---|---|
| `/etc/auto.master.d/r7.autofs` | `/mnt/r7auto /etc/auto.r7` |
| `/etc/auto.r7` | `share -rw,sync 10.10.10.10:/srv/r7/export` |

```bash
dnf install -y autofs
systemctl enable --now autofs
systemctl restart autofs     # after any map change
ls /mnt/r7auto/share         # access triggers the mount
findmnt /mnt/r7auto/share
```

| Map kind | Master line | Key |
|---|---|---|
| Indirect | `/mnt/r7auto /etc/auto.r7` | `share` → `/mnt/r7auto/share` |
| Direct | `/- /etc/auto.direct` | full path as the key |
| Wildcard | `* -rw,sync srv:/exports/&` | any name; `&` is the key |

`ls /mnt/r7auto` is empty by design: the parent is a mount point, not a listing.

| | fstab | autofs |
|---|---|---|
| At boot | Mounts | Nothing |
| Dead server | Boot risk (use `nofail`) | No effect until accessed |

## Repair

| Filesystem | Check | Read-only |
|---|---|---|
| ext4 | `e2fsck -f /dev/r7vg/r7data` | `e2fsck -fn` |
| XFS | `xfs_repair /dev/r7vg/r7data` | `xfs_repair -n` |
| Any | `fsck /dev/...` (wrapper) | — |

Unmount first. Non-interactive: `-p` preens, `-y` answers yes, `-n` answers no.

`e2fsck` exit codes: `0` clean, `1` corrected, `2` corrected + reboot, `4` uncorrected, `8` operational error.

## Growing ext4

```bash
lvextend -L +512M /dev/r7vg/r7data
resize2fs /dev/r7vg/r7data
lvs
df -h /srv/r7/data
```

| | ext4 | XFS |
|---|---|---|
| Grow | `resize2fs <device>` | `xfs_growfs <mount point>` |
| Online | Yes | Yes |
| Shrink | Offline, with `e2fsck` first | Never |

Order is always: block device first, filesystem second. `lvs` proves the volume, `df` proves the filesystem.

## Quick diagnosis

| Symptom | Check |
|---|---|
| `chmod` does nothing | VFAT; use mount options |
| `ln -s` fails on a mount | VFAT; use XFS or ext4 |
| `mount -t nfs` hangs | Firewall, or server down; `showmount -e 10.10.10.10` |
| `access denied by server` | `mountd`/`rpc-bind` not open, or client not in exports |
| Root cannot write to an export | `root_squash`; write as a normal user |
| `ls /mnt/r7auto` empty | Access the key, not the parent |
| Map change ignored | `systemctl restart autofs` |
| `df` smaller than `lvs` | Run `resize2fs` / `xfs_growfs` |
| `xfs_growfs` says not mounted | Pass the mount point, not the device |
| `e2fsck` says "need terminal" | Output is not a tty; add `-y` |
| Mount missing after reboot | fstab line, `daemon-reload`, UUID |
