# R6 cheat sheet

A compact reference for review. Everything here is explained in the [theory page](index.md).

## The stack

```text { .no-copy }
disk → partition table → partition → PV → VG → LV → filesystem → mount
```

| Layer | Create | List | Remove |
|---|---|---|---|
| Partition table + partition | `parted -s /dev/vdb mklabel gpt`<br>`parted -s /dev/vdb mkpart NAME START END` | `parted -s /dev/vdb print` | `parted -s /dev/vdb rm N` |
| Physical volume | `pvcreate /dev/vdb1` | `pvs`, `pvdisplay` | `pvremove /dev/vdb1` |
| Volume group | `vgcreate r6vg /dev/vdb1` | `vgs`, `vgdisplay` | `vgremove r6vg` |
| Logical volume | `lvcreate -n r6data -L 2G r6vg` | `lvs`, `lvdisplay` | `lvremove /dev/r6vg/r6data` |
| Filesystem | `mkfs.xfs /dev/r6vg/r6data`<br>`mkfs.ext4 -L r6label /dev/r6vg/r6label` | `blkid`, `lsblk -f` | `mkfs` (destroys) |
| Mount | edit `/etc/fstab` | `findmnt`, `findmnt --fstab` | `umount`, remove line |

Removal order: `umount` → remove fstab line → `daemon-reload` → `lvremove` → `vgremove` → `pvremove` → `parted rm`.

## Partitions

| Task | Command |
|---|---|
| New GPT table | `parted -s /dev/vdb mklabel gpt` |
| New partition | `parted -s /dev/vdb mkpart r6data 1MiB 5121MiB` |
| Mark as LVM | `parted -s /dev/vdb set 1 lvm on` |
| Show table | `parted -s /dev/vdb print` |
| Delete partition N | `parted -s /dev/vdb rm N` |
| Re-read the table | `udevadm settle` or `partprobe /dev/vdb` |
| Machine-readable table | `sfdisk -d /dev/vdb` |

GPT type GUID for Linux LVM: `E6D6D379-F507-44C2-A23C-238F2A3DF928`.
Start partitions at `1MiB`, not sector 0.

## LVM

| Task | Command |
|---|---|
| Create PV | `pvcreate /dev/vdb1` |
| Create VG | `vgcreate r6vg /dev/vdb1` |
| Create LV, absolute size | `lvcreate -n r6data -L 2G r6vg` |
| Create LV, extents/percent | `lvcreate -n r6data -l 50%FREE r6vg` |
| Add a PV to a VG | `vgextend r6vg /dev/vdb2` |
| Grow an LV by 2 GiB | `lvextend -L +2G /dev/r6vg/r6data` |
| Grow an LV and its filesystem | `lvextend -r -L +2G /dev/r6vg/r6data` |
| Set an LV to an absolute size | `lvresize -L 4G /dev/r6vg/r6data` |
| List | `pvs`, `vgs`, `lvs`, `lsblk` |
| Detail | `pvdisplay`, `vgdisplay`, `lvdisplay` |

LV paths: `/dev/r6vg/r6data` and `/dev/mapper/r6vg-r6data` are the same device.
Default physical extent: 4 MiB. `PFree` / `VFree` is the space left.

## Filesystems

| Task | XFS | ext4 |
|---|---|---|
| Create | `mkfs.xfs /dev/r6vg/r6data` | `mkfs.ext4 /dev/r6vg/r6label` |
| Create with label | `mkfs.xfs -L r6data /dev/r6vg/r6data` | `mkfs.ext4 -L r6label /dev/r6vg/r6label` |
| Grow | `xfs_growfs /srv/r6/data` (mount point) | `resize2fs /dev/r6vg/r6data` (device) |
| Shrink | not possible | `resize2fs` offline, after `e2fsck` |
| Identify | `blkid /dev/r6vg/r6data` | same |
| Filesystem check | `xfs_repair` (unmounted) | `e2fsck` (unmounted) |

`mkfs` destroys whatever is on the device. Format partitions and LVs, never a disk with a partition table you need.

## fstab

```text { .no-copy }
UUID=...     /srv/r6/data  xfs   defaults        0 0
LABEL=r6label /srv/r6/label ext4  defaults        0 0
UUID=...     none          swap  defaults        0 0
```

| Field | Meaning |
|---|---|
| 1 | Source: `UUID=`, `LABEL=`, or `/dev/...` |
| 2 | Mount point, or `none` for swap |
| 3 | `xfs`, `ext4`, `swap`, `vfat` |
| 4 | Options; `defaults`, add `nofail` for optional storage |
| 5 | Dump: `0` |
| 6 | `fsck` order: `0` none, `1` root, `2` others |

Apply a change:

```bash
systemctl daemon-reload
mount -a
findmnt --verify
```

| Ask | Command |
|---|---|
| What is mounted now? | `findmnt`, `findmnt /srv/r6/data` |
| What will boot do? | `findmnt --fstab`, `findmnt --fstab /srv/r6/data` |
| Is the whole file valid? | `findmnt --verify` |
| What filesystem is this? | `blkid /dev/r6vg/r6data` |
| What is mounted where? | `lsblk -f` |

## Swap

| Task | Command |
|---|---|
| Create the signature | `mkswap /dev/r6vg/r6swap` |
| Activate one | `swapon /dev/r6vg/r6swap` |
| Activate every fstab entry | `swapon -a` |
| Deactivate | `swapoff /dev/r6vg/r6swap`, `swapoff -a` |
| Show active areas | `swapon --show`, `swapon --show=NAME,UUID` |
| Show memory and swap | `free -h` |
| Read the UUID | `blkid -s UUID -o value /dev/r6vg/r6swap` |

`PRIO` is the priority; higher is used first. The default from fstab is `-2`.

## Growing a filesystem, in order

```bash
parted -s /dev/vdb mkpart r6extra 5121MiB 100%
parted -s /dev/vdb set 2 lvm on
udevadm settle
pvcreate /dev/vdb2
vgextend r6vg /dev/vdb2
lvextend -L +2G /dev/r6vg/r6data
xfs_growfs /srv/r6/data
df -h /srv/r6/data
```

`lvs` proves the volume grew. `df` proves the filesystem followed. You need both.

## Quick diagnosis

| Symptom | Check |
|---|---|
| `mount -a`: can't find UUID | `blkid` the device; compare the fstab value exactly |
| `mount -a`: can't find LABEL | `blkid -s LABEL`; labels are case-sensitive |
| `findmnt --verify` warns about the old fstab | `systemctl daemon-reload` |
| Mount missing after reboot | fstab line, mount-point directory, UUID/label, `findmnt --verify` |
| `df` smaller than `lvs` | Grow the filesystem: `xfs_growfs` / `resize2fs` |
| `xfs_growfs` says "not a mounted XFS filesystem" | Pass the mount point, not the device |
| `lvremove` refuses | `umount` first |
| `pvcreate` says no such file | `lsblk`; wait for udev, or `partprobe` |
| Swap not active after reboot | fstab line must be `... none swap ...`; run `swapon -a` |
| Boot drops to emergency mode | A non-optional fstab entry cannot mount; add `nofail` only where it is safe |
