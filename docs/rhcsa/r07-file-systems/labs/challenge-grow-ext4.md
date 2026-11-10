# Challenge — Grow ext4 without losing data

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R7 — File systems and sharing |
| **Time** | 45–60 minutes |
| **Check** | `./bin/lab check r07 challenge` |
| **Style** | Exam task: requirements only, no steps |

</div>

This is the R7 challenge. It is written the way EX200 presents work: required behaviour, no walkthrough. Use the [theory page](../index.md), `man`, and your notes — but try it without a recipe first.

It assumes the machine from [Lab 1](lab-1-vfat.md) and, for the regression checks, [Lab 2](lab-2-nfs-autofs.md). The new storage is added beside that state; it must not undo it.

## Scenario

`server` keeps artefacts for a build system under `/srv/r7/data`. The volume is nearly full and there is unused space on `/dev/vdb`. You are asked to add that space to a new volume group, put an **ext4** filesystem on it, and then grow both the volume and the filesystem **while it is mounted**, without losing the data already there.

The exam asks for ext4 specifically here because `resize2fs` behaves differently from `xfs_growfs`: it takes the device, and it is the tool you also need for an offline check.

## Tasks

1. Create `/dev/vdb2`, about 1.5 GiB, in the free space after `/dev/vdb1`. It must be a Linux LVM partition.

2. Create a volume group named `r7vg` on `/dev/vdb2` and a 512 MiB logical volume named `r7data` in it.

3. Put an ext4 filesystem on `/dev/r7vg/r7data` with the label **R7DATA**, and mount it at `/srv/r7/data` through `/etc/fstab` by **UUID**.

4. Write a file of about 100 MB, `/srv/r7/data/blob.bin`, and record its checksum. This is the data that must survive.

5. Grow the logical volume by **512 MiB** and grow the filesystem **while it is still mounted**. After the change:

   - `lvs` shows `r7data` at 1 GiB,
   - `df -h /srv/r7/data` shows about 1 GiB,
   - `blob.bin` still matches the checksum you recorded.

6. Unmount the filesystem, run a **forced** filesystem check on it, and mount it again. The check must report no errors.

7. Leave the earlier labs intact:

   - `/srv/r7/vfat` is still mounted with its VFAT options,
   - the NFS export `/srv/r7/export` is still active,
   - `node2` can still read the export through autofs,
   - `findmnt --verify` reports no errors or warnings.

8. Reboot `server`. Afterwards, without mounting anything by hand:

   - `/srv/r7/data` is mounted and reached through its UUID,
   - it still shows the larger size,
   - `blob.bin` is still readable and still matches its checksum.

## Hints

Only if you are stuck.

<details>
<summary>How do I size the second partition?</summary>

Lab 1 ended `/dev/vdb1` at `513MiB`, so start the new partition there. A 1.5 GiB partition ends at `513 + 1536 = 2049MiB`:

```bash
parted -s /dev/vdb mkpart r7data 513MiB 2049MiB
parted -s /dev/vdb set 2 lvm on
udevadm settle
parted -s /dev/vdb print
```

Do **not** use `100%`. The partition must be about 1.5 GiB, not the whole disk, and the challenge later needs `VFree` inside it. `parted` prints the size in decimal: `1611MB` is 1.5 GiB.

</details>

<details>
<summary>Why is there not enough space in the volume group?</summary>

`r7vg` was created on a 1.5 GiB partition, so it holds roughly 1.5 GiB of extents. A 512 MiB logical volume leaves about 1 GiB free, which is exactly what `lvextend -L +512M` needs.

If `lvextend` says `Insufficient free space`, check `vgs`:

```bash
pvs
vgs
```

The usual cause is a smaller partition than intended — for example `512MiB` to `1024MiB` leaves only about 500 MiB free. Resize the partition while it is still a PV, or start again from a clean snapshot; do not run `lvextend` repeatedly hoping for a different answer.

</details>

<details>
<summary>How do I use LVM at all?</summary>

```bash
dnf install -y lvm2
pvcreate /dev/vdb2
vgcreate r7vg /dev/vdb2
lvcreate -n r7data -L 512M r7vg
mkfs.ext4 -L R7DATA /dev/r7vg/r7data
```

The lab image has `parted` and `blkid` but not the LVM userland, so the install is not optional. If `dnf install` fails, R3's distro repositories are probably still disabled — re-enable them first.

</details>

<details>
<summary>Which resize command, and in what order?</summary>

```bash
lvextend -L +512M /dev/r7vg/r7data
resize2fs /dev/r7vg/r7data
df -h /srv/r7/data
```

`lvextend` changes the block device; the filesystem still has its old geometry until `resize2fs` runs. ext4 can be grown **while it is mounted**, and `resize2fs` says so in its output (`on-line resizing required`).

`resize2fs` takes the **device** (`/dev/r7vg/r7data`). `xfs_growfs` takes the **mount point**. Mixing those two up is the most common failure in this objective.

</details>

<details>
<summary>My checksum changed — what went wrong?</summary>

`mkfs` on the wrong device, or running `resize2fs` in the wrong direction without a check. `resize2fs` can only grow a filesystem that is smaller than its device; given a size argument it can also shrink, which is destructive if the data does not fit.

Confirm what you formatted:

```bash
blkid /dev/r7vg/r7data
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
```

A checksum mismatch after a correct online grow should not happen. If it does, restore the clean snapshot and walk the challenge again carefully, noting each device name.

</details>

<details>
<summary>Why does <code>e2fsck</code> complain about a terminal?</summary>

`e2fsck` asks questions when it finds damage. When its output is not a terminal — a script, a pipe — it cannot ask, and exits 8 with `need terminal for interactive repairs`. On a clean filesystem with `-f` it still runs, but in a script add `-y`:

```bash
e2fsck -f /dev/r7vg/r7data      # interactive
e2fsck -fy /dev/r7vg/r7data     # non-interactive
```

Either way, the filesystem must be **unmounted** first. `e2fsck` on a mounted filesystem damages it.

</details>

<details>
<summary>How do I mount it again after the check?</summary>

The fstab line was never removed, so one command does it:

```bash
mount -a
findmnt /srv/r7/data
```

If `mount -a` reports `can't find UUID`, the UUID in fstab does not match the filesystem. Compare:

```bash
blkid -s UUID -o value /dev/r7vg/r7data
grep r7/data /etc/fstab
```

</details>

## Verify

From the host, in the `labs` directory:

```bash
./bin/lab check r07 challenge
```

```text { .no-copy }
R7 Challenge — Grow ext4 without losing data
  PASS  /dev/vdb2 exists
  PASS  /dev/vdb2 is about 1.5 GiB
  PASS  /dev/vdb2 is marked as a Linux LVM partition
  PASS  /dev/vdb2 is a physical volume in r7vg
  PASS  logical volume r7data exists in r7vg
  PASS  r7data grew to about 1 GiB
  PASS  r7data holds an ext4 filesystem
  PASS  /srv/r7/data is mounted
  PASS  /srv/r7/data is mounted as ext4
  PASS  fstab mounts /srv/r7/data by its UUID
  PASS  the ext4 filesystem grew with the volume
  PASS  the data file written before the grow survived
  PASS  the whole fstab parses and its sources resolve
  PASS  the VFAT volume is still mounted
  PASS  the NFS export is still active
  PASS  node2 can still read the autofs share
```

The checker reads the partition table, the LVM metadata, the ext4 superblock, the live mount table, and fstab. It does not care which commands you used. Three things are worth noticing:

- **Two size checks, not one.** `lvs` proves the logical volume grew; `findmnt -b -o SIZE` proves the filesystem followed. Passing only the first is the common mistake the challenge exists to catch.
- **The data check is the real test.** `blob.bin` must be 100–115 MB after the grow. That is not a proxy for "the grow worked" — it is the thing the objective promises.
- **The last three checks are regressions.** They assert that the VFAT mount and the NFS export from the earlier labs are still in place, which is what makes `check r07 all` a valid three-state stack.

## After the challenge

Nothing needs to be undone. A grown ext4 volume, the VFAT mount, and the NFS export are a valid end state, and they are what `./bin/lab check r07 all` expects.

If you want the machine exactly as the course assumes before R8:

```bash
cd labs
./bin/lab restore clean
```

Restoring the snapshot removes the partition table, the LVM metadata, both filesystems, the NFS export, and the autofs maps in one step, on both machines.
