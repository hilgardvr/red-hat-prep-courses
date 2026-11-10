# Lab 2 — Swap and a label

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R6 — Local storage |
| **Time** | 45–60 minutes |
| **Check** | `./bin/lab check r06 lab2` |
| **Skills** | `lvcreate`, `mkswap`, `swapon`, swap in fstab, `mkfs.ext4 -L`, `LABEL=` mounts, `findmnt --verify` |

</div>

## What you are building

| Item | End state |
|---|---|
| Logical volume | `r6swap`, 512 MiB, in `r6vg` |
| Swap | Active, and enabled at boot by **UUID** |
| Logical volume | `r6label`, 512 MiB, in `r6vg` |
| Filesystem | ext4 on `/dev/r6vg/r6label`, label **r6label** |
| Mount | `/srv/r6/label`, recorded in fstab by **LABEL** |
| Regression | Lab 1's `/srv/r6/data` is still mounted by UUID |
| Persistence | After a reboot, swap and the label mount both return |

Lab 1 used a UUID. This lab uses a label, so you can see the two forms of the same idea side by side. Swap is included because it is part of the same objective and because it has its own fstab syntax: a swap area has no mount point.

## Before you begin

This lab assumes [Lab 1](lab-1-partitions-and-lvm.md) is complete: `r6vg` exists, `r6data` is mounted at `/srv/r6/data` by UUID, and `lvm2` is installed. If you restored the clean snapshot, walk Lab 1 first.

```bash
cd labs
./bin/lab ssh
sudo -i
```

Every command runs **inside `server`** as root. As in Lab 1, the UUIDs below are from one walk; yours will differ.

---

## Step 1 — A swap logical volume

Create the volume and write the swap signature:

```bash
lvcreate -n r6swap -L 512M r6vg
mkswap /dev/r6vg/r6swap
```

```text { .no-copy }
  Logical volume "r6swap" created.
Setting up swapspace version 1, size = 512 MiB (536866816 bytes)
no label, UUID=40027ec7-bc8e-4267-a85b-05e02d72679b
```

`mkswap` prints the UUID it generated. Unlike `mkfs.xfs`, it tells you the value directly; you can also read it later with `blkid`. A swap area has no label by default, which is why the line says `no label`.

Add it to fstab with `none` as the mount point:

```bash
SWUUID=$(blkid -s UUID -o value /dev/r6vg/r6swap)
printf 'UUID=%s none swap defaults 0 0\n' "$SWUUID" >> /etc/fstab
tail -1 /etc/fstab
```

```text { .no-copy }
UUID=40027ec7-bc8e-4267-a85b-05e02d72679b none swap defaults 0 0
```

The six fields still apply, but two of them mean something different:

| Field | Value | Why |
|---|---|---|
| Source | `UUID=...` | Stable identifier for the swap area |
| Mount point | `none` | Swap is not mounted in the directory tree |
| Type | `swap` | Tells systemd to generate a `.swap` unit |
| Options | `defaults` | `pri=` can be added if you have several areas |
| Dump | `0` | No dump |
| `fsck` | `0` | `fsck` does not check swap |

Apply it:

```bash
systemctl daemon-reload
swapon -a
swapon --show
free -h
```

```text { .no-copy }
NAME      TYPE      SIZE USED PRIO
/dev/dm-1 partition 512M   0B   -2

               total        used        free      shared  buff/cache   available
Mem:           3.8Gi       591Mi       2.8Gi        12Mi       659Mi       3.2Gi
Swap:          511Mi          0B       511Mi
```

`swapon -a` activates every swap entry in fstab that is not already active. `swapon --show` prints active swap areas, and `free -h` shows the total the kernel accounts for.

!!! note "`/dev/dm-1` instead of `r6vg/r6swap`"
    `swapon --show` prints the device-mapper node the kernel is using, not the LVM path you typed. Which `dm-N` number it gets depends on the order the devices were activated; the UUID and size are what identify it. `swapon --show=NAME,UUID` prints both if you want to match it to the LV.

`PRIO` is the priority. `-2` is the kernel's default for an fstab swap entry with no `pri=` option. If you add a second swap area, the higher priority is used first.

## Step 2 — An ext4 volume with a label

Create the volume and format it with a label:

```bash
lvcreate -n r6label -L 512M r6vg
mkfs.ext4 -L r6label /dev/r6vg/r6label
```

```text { .no-copy }
  Logical volume "r6label" created.
mke2fs 1.47.1 (20-May-2024)
Creating filesystem with 131072 4k blocks and 32768 inodes
Filesystem UUID: 4a885302-5086-44b3-aedb-74e8150c8f09
Superblock backups stored on blocks:
        32768, 98304

Allocating group tables: 0/4   done
Writing inode tables: 0/4   done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: 0/4   done
```

`-L r6label` writes the label into the ext4 superblock. The filesystem also gets a UUID, which `mkfs` prints as `Filesystem UUID`. You can use either; this lab uses the label.

Confirm both identifiers:

```bash
blkid /dev/r6vg/r6label
```

```text { .no-copy }
/dev/r6vg/r6label: LABEL="r6label" UUID="4a885302-5086-44b3-aedb-74e8150c8f09" BLOCK_SIZE="4096" TYPE="ext4"
```

Now mount it by label:

```bash
mkdir -p /srv/r6/label
printf 'LABEL=r6label /srv/r6/label ext4 defaults 0 0\n' >> /etc/fstab
systemctl daemon-reload
mount -a
findmnt /srv/r6/label
```

```text { .no-copy }
TARGET        SOURCE                   FSTYPE OPTIONS
/srv/r6/label /dev/mapper/r6vg-r6label ext4   rw,relatime,seclabel
```

The source in fstab is `LABEL=r6label`; the source `findmnt` reports is the device it resolved to. That difference is the point: the label is a lookup key, not a device path.

Check the whole file again:

```bash
findmnt --verify
```

```text { .no-copy }
Success, no errors or warnings detected
```

If you see a warning about the old fstab, `systemctl daemon-reload` was skipped. If you see `unreachable source: LABEL=r6label`, the label is misspelled or the filesystem was not formatted with it.

## Step 3 — Reboot and prove both survive

```bash
systemctl reboot
```

Reconnect and check, without activating anything by hand:

```bash
cd labs
./bin/lab ssh
sudo -i
swapon --show
free -h
findmnt /srv/r6/label
findmnt /srv/r6/data
findmnt --verify
```

```text { .no-copy }
NAME      TYPE      SIZE USED PRIO
/dev/dm-1 partition 512M   0B   -2

               total        used        free      shared  buff/cache   available
Mem:           3.8Gi       591Mi       2.8Gi        12Mi       659Mi       3.2Gi
Swap:          511Mi          0B       511Mi

TARGET        SOURCE                   FSTYPE OPTIONS
/srv/r6/label /dev/mapper/r6vg-r6label ext4   rw,relatime,seclabel

TARGET       SOURCE                  FSTYPE OPTIONS
/srv/r6/data /dev/mapper/r6vg-r6data xfs    rw,relatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,noquota

Success, no errors or warnings detected
```

Three things came back on their own:

- the swap area, activated from the fstab entry by systemd,
- the ext4 filesystem, found by its label,
- the XFS filesystem from Lab 1, found by its UUID.

That is the persistence test for this module. A mount or swap area that only works until the next reboot fails the objective even if every command in the lab succeeded.

## Verify with the checker

From the host, in the `labs` directory:

```bash
./bin/lab check r06 lab2
```

```text { .no-copy }
R6 Lab 2 — Swap and a label mount
  PASS  logical volume r6swap exists in r6vg
  PASS  logical volume r6label exists in r6vg
  PASS  r6swap is active swap
  PASS  fstab enables swap by UUID
  PASS  r6swap is about 512 MiB
  PASS  r6label holds an ext4 filesystem
  PASS  the r6label filesystem is labelled r6label
  PASS  /srv/r6/label is mounted
  PASS  fstab mounts /srv/r6/label by LABEL
  PASS  /srv/r6/label is mounted as ext4
  PASS  the whole fstab parses and its sources resolve
  PASS  r6data is still mounted
```

The last line is a regression check. Lab 2 adds state; it must not break Lab 1. The checker reads the live devices, mounts, and fstab, so it does not care whether you used `lvcreate` or a drop-in, only that the end state is correct.

## If something went wrong

| Symptom | Likely cause | Fix |
|---|---|---|
| `swapon -a` prints nothing and `swapon --show` is empty | The fstab line is missing or says `swap` in the wrong field | Read the line; source, `none`, `swap` must be fields 1–3 |
| `swapon: /dev/r6vg/r6swap: read swap header failed` | `mkswap` was not run, or ran on the wrong device | `mkswap /dev/r6vg/r6swap` |
| `mount -a` says `can't find LABEL=r6label` | Label typo, or the filesystem has no label | `blkid` the device; re-run `mkfs.ext4 -L r6label` only if the data does not matter |
| `findmnt --verify` warns about the old fstab | `daemon-reload` skipped | `systemctl daemon-reload`, retry |
| The label mount is missing after reboot | fstab line malformed, or the directory does not exist | `mkdir -p /srv/r6/label`; check `findmnt --verify` |
| Swap is active but `free` shows 0 | You are reading a different machine or namespace | Run `free -h` in the same VM |

To start Lab 2 over without losing Lab 1, stop using what this lab added:

```bash
swapoff /dev/r6vg/r6swap
umount /srv/r6/label
```

Remove the two lines this lab appended to `/etc/fstab` — the swap line and the `LABEL=r6label` line — with an editor such as `vi`. Then reload systemd and delete the logical volumes:

```bash
systemctl daemon-reload
lvremove /dev/r6vg/r6swap /dev/r6vg/r6label
```

That is also the correct order for removal: stop using the device, remove it from fstab, reload, then delete the LVs.

## Next

[Challenge — Extend storage non-destructively](challenge-extend-storage.md) adds the rest of the disk to `r6vg`, grows `r6data` by 2 GiB, and expands the XFS filesystem while it is mounted.
