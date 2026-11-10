# Lab 1 — A partition, a volume group, and a UUID mount

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R6 — Local storage |
| **Time** | 60–75 minutes |
| **Check** | `./bin/lab check r06 lab1` |
| **Skills** | `parted`, GPT, `pvcreate`, `vgcreate`, `lvcreate`, `mkfs.xfs`, `/etc/fstab`, UUID mounts, `findmnt` |

</div>

## What you are building

| Item | End state |
|---|---|
| `/dev/vdb` | A GPT partition table |
| `/dev/vdb1` | A 5 GiB partition, type Linux LVM |
| Physical volume | `/dev/vdb1` belongs to `r6vg` |
| Logical volume | `r6data`, 2 GiB, allocated from `r6vg` |
| Filesystem | XFS on `/dev/r6vg/r6data` |
| Mount | `/srv/r6/data`, recorded in fstab by **UUID** |
| Persistence | After a reboot, the mount returns with no manual command |

You will build the same stack the exam describes, one layer at a time. Every step prints something you can check before moving on, so a mistake is caught where it happens, not at the reboot.

!!! note "Values differ on every machine"
    Partition UUIDs and filesystem UUIDs are generated, so the values in this page are from one walk of the lab. Your output will have the same shape with different numbers. Copy UUIDs from your own `blkid`, never from this page.

## Before you begin

Start from the clean snapshot:

```bash
cd labs
./bin/lab restore clean
./bin/lab ssh
sudo -i
```

From here on, every command runs **inside the `server` VM** as root.

The base images do not include the LVM tools, so install them first:

```bash
dnf install -y lvm2
```

```text { .no-copy }
Installing:
 lvm2                            x86_64   10:2.03.36-2.el10      baseos   1.6 M
Installing dependencies:
 device-mapper-event             x86_64   10:1.02.210-2.el10     baseos    36 k
 ...
Installed:
  lvm2-2.03.36-2.el10.x86_64
  ...
Complete!
```

This needs a working repository. If you disabled the distro repositories in the R3 challenge and have not re-enabled them, do that first, or install from a repository you configured there. The module needs the `lvm2` package for `pvcreate`, `vgcreate`, and `lvcreate`.

---

## Step 1 — Look at the disk before touching it

```bash
lsblk
parted -s /dev/vdb print
```

```text { .no-copy }
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
vda    252:0    0   20G  0 disk
├─vda1 252:1    0    1M  0 part
├─vda2 252:2    0  200M  0 part /boot/efi
├─vda3 252:3    0    1G  0 part /boot
└─vda4 252:4    0 18.8G  0 part /
vdb    252:16   0   10G  0 disk
```

```text { .no-copy }
Error: /dev/vdb: unrecognised disk label
```

An empty disk has no partition table, so `parted` says it does not recognise the label. That is the expected starting point. `vdb` is the 10 GB second disk; `vda` holds the running system and is not part of this lab.

!!! danger "Only ever partition `/dev/vdb`"
    `/dev/vda` contains `/`, `/boot`, and `/boot/efi`. Writing a label or a filesystem to it destroys the lab. Check the device name in every command before you press Enter.

## Step 2 — Write a GPT table and create the partition

```bash
parted -s /dev/vdb mklabel gpt
parted -s /dev/vdb mkpart r6data 1MiB 5121MiB
parted -s /dev/vdb set 1 lvm on
udevadm settle
```

None of these print anything on success; `-s` is script mode. Now look at the result:

```bash
parted -s /dev/vdb print
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS /dev/vdb
blkid /dev/vdb1
```

```text { .no-copy }
Model: Virtio Block Device (virtblk)
Disk /dev/vdb: 10.7GB
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags:

Number  Start   End     Size    File system  Name    Flags
 1      1049kB  5370MB  5369MB               r6data  lvm

NAME   SIZE TYPE FSTYPE MOUNTPOINTS
vdb     10G disk
└─vdb1   5G part

/dev/vdb1: PARTLABEL="r6data" PARTUUID="ddd1540e-6623-4fe7-a2cc-2196b3057554"
```

Read the three outputs together:

- `parted` says the table is **gpt** and partition 1 is about 5 GiB with the **lvm** flag.
- `lsblk` shows the partition as a child of `vdb`, with no filesystem yet.
- `blkid` shows the **PARTLABEL** and **PARTUUID**. These identify the partition, not a filesystem. They are different values from the filesystem UUID you will use in fstab later.

`5121MiB - 1MiB` is 5120 MiB, which is 5 GiB. `parted` shows decimal sizes, so it prints `5369MB` rather than `5.0GiB`. Both are correct.

If `lsblk` does not show `vdb1`, run `udevadm settle` again, or `partprobe /dev/vdb`, then retry. The partition exists in the table immediately; the kernel and udev need a moment to create `/dev/vdb1`.

## Step 3 — Create the physical volume, volume group, and logical volume

```bash
pvcreate /dev/vdb1
vgcreate r6vg /dev/vdb1
lvcreate -n r6data -L 2G r6vg
```

```text { .no-copy }
  Physical volume "/dev/vdb1" successfully created.
  Creating devices file /etc/lvm/devices/system.devices
  Volume group "r6vg" successfully created
  Logical volume "r6data" created.
```

The `devices file` line is normal on RHEL 10: LVM records the devices it manages in `/etc/lvm/devices/system.devices`, which keeps it from scanning unrelated disks. You do not have to edit it.

Now inspect all three layers:

```bash
pvs
vgs
lvs
```

```text { .no-copy }
  PV         VG   Fmt  Attr PSize  PFree
  /dev/vdb1  r6vg lvm2 a--  <5.00g <3.00g

  VG   #PV #LV #SN Attr   VSize  VFree
  r6vg   1   1   0 wz--n- <5.00g <3.00g

  LV     VG   Attr       LSize Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  r6data r6vg -wi-a----- 2.00g
```

`PFree` is about 3 GiB: 5 GiB of PV minus the 2 GiB LV. `VFree` is the same number from the pool's point of view. The `Attr` string `-wi-a-----` means the LV is writable, active, and allocated, which is the normal state for a new volume.

`/dev/vdb1` is now an LVM physical volume. It no longer has a normal partition filesystem, and `blkid` will report `TYPE="LVM2_member"`. That is expected.

## Step 4 — Put an XFS filesystem on the logical volume

```bash
mkfs.xfs /dev/r6vg/r6data
```

```text { .no-copy }
meta-data=/dev/r6vg/r6data       isize=512    agcount=4, agsize=131072 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=1
data     =                       bsize=4096   blocks=524288, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0, ftype=1, parent=0
log      =internal log           bsize=4096   blocks=16384, version=2
realtime =none                   extsz=4096   blocks=0, rtextents=0
Discarding blocks...Done.
```

The middle lines describe the geometry; the one to notice is `blocks=524288`. At 4 KiB per block that is 2 GiB. `mkfs.xfs` did not ask for confirmation, because `/dev/r6vg/r6data` was a new, empty logical volume. On a device that already holds data, `mkfs` would still not ask — it destroys what is there.

Confirm the filesystem and capture its UUID:

```bash
blkid /dev/r6vg/r6data
```

```text { .no-copy }
/dev/r6vg/r6data: UUID="c85a2f7f-0620-4d82-878f-d40fa93eb239" BLOCK_SIZE="512" TYPE="xfs"
```

Write the UUID down, or capture it in a variable as the next step does. This is the value fstab needs. The path `/dev/r6vg/r6data` would also work today, but it is not the right choice for boot: the exam asks for a UUID or a label.

## Step 5 — Mount it by UUID, now and at boot

Create the mount point:

```bash
mkdir -p /srv/r6/data
```

Append the fstab line, using the UUID that is actually on the filesystem:

```bash
UUID=$(blkid -s UUID -o value /dev/r6vg/r6data)
printf 'UUID=%s /srv/r6/data xfs defaults 0 0\n' "$UUID" >> /etc/fstab
```

The `$(...)` captures only the UUID value, with no label or type around it. `printf` then writes one complete fstab line. Check the file before applying it:

```bash
tail -1 /etc/fstab
```

```text { .no-copy }
UUID=c85a2f7f-0620-4d82-878f-d40fa93eb239 /srv/r6/data xfs defaults 0 0
```

Now tell systemd about the new line, mount everything, and verify:

```bash
systemctl daemon-reload
mount -a
findmnt /srv/r6/data
df -h /srv/r6/data
```

```text { .no-copy }
TARGET       SOURCE                  FSTYPE OPTIONS
/srv/r6/data /dev/mapper/r6vg-r6data xfs    rw,relatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,noquota

Filesystem               Size  Used Avail Use% Mounted on
/dev/mapper/r6vg-r6data  2.0G   71M  1.9G   4% /srv/r6/data
```

`systemctl daemon-reload` is the step people skip. Editing fstab changes a file; systemd generates mount units from that file at boot and when told to reload. Without the reload, `findmnt --verify` warns that "your fstab has been modified, but systemd still uses the old version", and a `systemctl start` of the mount unit uses stale data.

`mount -a` reads fstab, skips what is already mounted, and mounts the rest. It is the honest test of the line you just wrote.

`findmnt` shows the **live** mount. `df -h` shows the size the filesystem believes it has. Both should agree with the LV.

One more check of the whole picture:

```bash
findmnt --verify
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS /dev/vdb
```

```text { .no-copy }
Success, no errors or warnings detected

NAME            SIZE TYPE FSTYPE      MOUNTPOINTS
vdb              10G disk
└─vdb1            5G part LVM2_member
  └─r6vg-r6data   2G lvm  xfs         /srv/r6/data
```

`findmnt --verify` checks every fstab line, not just this one. "Success" means the file parses and every source resolves.

## Step 6 — Persistence: reboot and look again

A mount that works now but not at boot is the failure this objective is really about. Reboot and check without running `mount`:

```bash
systemctl reboot
```

The SSH session ends. Reconnect from the host:

```bash
cd labs
./bin/lab ssh
sudo -i
findmnt /srv/r6/data
df -h /srv/r6/data
```

```text { .no-copy }
TARGET       SOURCE                  FSTYPE OPTIONS
/srv/r6/data /dev/mapper/r6vg-r6data xfs    rw,relatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,noquota

Filesystem               Size  Used Avail Use% Mounted on
/dev/mapper/r6vg-r6data  2.0G   71M  1.9G   4% /srv/r6/data
```

If `findmnt` prints nothing, fstab is wrong, the UUID is stale, or `daemon-reload` was never run. Work backwards: `blkid` the filesystem, compare it with the fstab line, then run `mount -a` and read the error.

## Verify with the checker

From the host, in the `labs` directory:

```bash
./bin/lab check r06 lab1
```

```text { .no-copy }
R6 Lab 1 — A partition, a volume group, and a UUID mount
  PASS  the LVM tools are installed
  PASS  /dev/vdb carries a GPT partition table
  PASS  /dev/vdb1 exists
  PASS  /dev/vdb1 is about 5 GiB
  PASS  /dev/vdb1 is marked as a Linux LVM partition
  PASS  /dev/vdb1 is a physical volume in r6vg
  PASS  logical volume r6data exists in r6vg
  PASS  r6data holds an XFS filesystem
  PASS  /srv/r6/data is mounted
  PASS  /srv/r6/data is mounted as XFS
  PASS  fstab mounts /srv/r6/data by its UUID
  PASS  the root filesystem is still in fstab
```

The last check is a deliberate negative: it proves you appended to fstab instead of replacing it. A machine whose root entry is gone will not boot, and a checker that only looked at the new mount would call that a pass.

## If something went wrong

| Symptom | Likely cause | Fix |
|---|---|---|
| `parted: invalid token` | `mkpart` arguments out of order | `parted -s /dev/vdb mkpart NAME START END` |
| `lsblk` does not show `vdb1` | Kernel has not re-read the table | `udevadm settle` or `partprobe /dev/vdb` |
| `pvcreate` says "No such file" | Partition node does not exist yet | Wait for udev; check `lsblk` |
| `mkfs.xfs` says "appears to contain an existing filesystem" | You formatted twice, or the device is reused | Add `-f` only if you mean it |
| `mount -a` says "can't find UUID" | fstab has a stale or mistyped UUID | `blkid` the device, fix the line |
| `findmnt --verify` warns about the old fstab | `daemon-reload` was skipped | `systemctl daemon-reload`, retry |
| After reboot, no mount | fstab line missing, wrong UUID, or a typo in the mount point | Compare `blkid` with fstab; run `mount -a` for the error |

To start over, restore the clean snapshot and repeat from Step 1. `./bin/lab restore clean` removes the partition table, the LVM metadata, and the fstab line together, which is faster than undoing them by hand.

## Next

[Lab 2 — Swap and a label](lab-2-swap-and-labels.md) adds a swap logical volume and an ext4 volume mounted by `LABEL=`, and checks that both come back after a reboot.
