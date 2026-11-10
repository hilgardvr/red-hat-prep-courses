# Challenge — Extend storage non-destructively

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R6 — Local storage |
| **Time** | 45–60 minutes |
| **Check** | `./bin/lab check r06 challenge` |
| **Style** | Exam task: requirements only, no steps |

</div>

This is the R6 challenge. It is written the way EX200 presents work: required behaviour, no walkthrough. Use the [theory page](../index.md), `man`, and your notes — but try it without a recipe first.

It assumes the machine from [Lab 1](lab-1-partitions-and-lvm.md) and [Lab 2](lab-2-swap-and-labels.md). The new storage adds to that state; it must not undo it.

## Scenario

`server` stores build artefacts under `/srv/r6/data`. The volume is nearly full, and the machine has unused space at the end of `/dev/vdb`. You are asked to add that space to the existing pool and grow the filesystem **while it is mounted**, without losing the artefacts already there.

## Tasks

1. Create `/dev/vdb2` using all the space that remains after `/dev/vdb1`. It must be a Linux LVM partition.

2. Make `/dev/vdb2` a physical volume and add it to the existing `r6vg` volume group.

3. Grow the `r6data` logical volume by **2 GiB**, then grow the XFS filesystem on it while it stays mounted. After the change:

   - `lvs` shows `r6data` at 4 GiB,
   - `df -h /srv/r6/data` shows about 4 GiB,
   - a file you created in `/srv/r6/data` before the change is still readable.

4. Leave the earlier labs intact:

   - `/srv/r6/data` is still mounted, and fstab still finds it by **UUID**,
   - `/srv/r6/label` is still mounted, and fstab still finds it by **LABEL**,
   - `r6swap` is still active swap, enabled by **UUID** in fstab,
   - `findmnt --verify` reports no errors.

5. Reboot `server`. Afterwards, without mounting anything by hand:

   - `/srv/r6/data` and `/srv/r6/label` are mounted,
   - swap is active,
   - the marker file is still readable,
   - `df -h /srv/r6/data` still shows the larger size.

## Hints

Only if you are stuck.

<details>
<summary>How do I use the remaining space?</summary>

Start the second partition where the first one ended. Lab 1 ended at `5121MiB`, so:

```bash
parted -s /dev/vdb mkpart r6extra 5121MiB 100%
parted -s /dev/vdb set 2 lvm on
udevadm settle
parted -s /dev/vdb print
```

`100%` means "to the end of the disk". `parted` rounds down to the last usable sector, so the size will be slightly under 5 GiB. Check that the new partition is `/dev/vdb2` and does not overlap `/dev/vdb1`.

</details>

<details>
<summary>How do I add a partition to an existing volume group?</summary>

A new partition is not a PV until `pvcreate` writes LVM metadata on it, and it is not part of the VG until `vgextend` adds it:

```bash
pvcreate /dev/vdb2
vgextend r6vg /dev/vdb2
pvs
vgs
```

`pvs` should now list two PVs. `vgs` should show `#PV 2` and roughly 5 GiB more `VFree` than before. If `vgextend` says the device is already in a VG, check that you are using `vdb2` and not `vdb1`.

</details>

<details>
<summary>Why is `df` still the old size after `lvextend`?</summary>

`lvextend` changes the block device. The filesystem on it still has its old geometry until you grow it. That is not a bug: the filesystem cannot know that its device changed shape. Grow it:

```bash
lvextend -L +2G /dev/r6vg/r6data
xfs_growfs /srv/r6/data
df -h /srv/r6/data
```

`xfs_growfs` takes the **mount point**, not the device. Running it on `/dev/r6vg/r6data` fails with "not a mounted XFS filesystem". `resize2fs` is the ext4 equivalent and takes the device, which is one reason the two are easy to mix up.

</details>

<details>
<summary>How do I prove nothing was lost?</summary>

Before you extend, write a marker:

```bash
echo "created before the resize" > /srv/r6/data/marker.txt
sync
```

After the grow and the reboot:

```bash
cat /srv/r6/data/marker.txt
```

XFS grows in place. If the marker is gone, something other than `xfs_growfs` ran — most likely `mkfs` on the wrong device.

</details>

<details>
<summary>What if `lvextend` says there is not enough space?</summary>

`vgs` shows `VFree`. Two gigabytes must be free in `r6vg` after `vgextend`. If it is not, the new partition was not added, or it is smaller than expected. Check `pvs` and `vgs` before retrying; do not run `lvextend` repeatedly hoping for a different answer.

</details>

## Verify

From the host, in the `labs` directory:

```bash
./bin/lab check r06 challenge
```

```text { .no-copy }
R6 Challenge — Extend storage non-destructively
  PASS  /dev/vdb2 exists
  PASS  /dev/vdb2 takes the rest of the disk
  PASS  /dev/vdb2 is marked as a Linux LVM partition
  PASS  /dev/vdb2 is a physical volume in r6vg
  PASS  r6vg now spans two physical volumes
  PASS  r6data has grown to at least 4 GiB
  PASS  the r6data filesystem grew with it
  PASS  r6data is still mounted
  PASS  r6data is still handled by UUID in fstab
  PASS  r6label is still mounted by LABEL
  PASS  r6swap is still active swap
  PASS  the whole fstab still parses and its sources resolve
```

The checker reads the partition table, the LVM metadata, the live mount table, and fstab. It does not care which commands you used. The two size checks are separate on purpose: `lvs` proves the logical volume grew, and `findmnt` proves the filesystem followed. Passing only the first is the mistake the challenge exists to catch.

## After the challenge

Nothing needs to be undone. A volume group that spans two disks, a grown filesystem, and the earlier mounts are a valid end state, and they are what `./bin/lab check r06 all` expects.

If you want the machine exactly as the course assumes before R7:

```bash
cd labs
./bin/lab restore clean
```

Restoring the snapshot removes the partition table, the LVM metadata, both filesystems, the swap area, and the fstab lines in one step.
