# R6 knowledge check

Answer first, then open the answer. If you miss a question, return to the matching section of the [theory page](index.md).

### 1. The order of the layers

You have a blank disk `/dev/vdb`. Put these steps in the correct order: create a logical volume, create a volume group, create a physical volume, create a partition, create a filesystem.

??? question "Answer"
    Partition → physical volume → volume group → logical volume → filesystem. Each layer needs the one below it to exist first. `pvcreate` needs a partition (or a whole disk), `vgcreate` needs a PV, `lvcreate` needs a VG, and `mkfs` needs a block device — the LV.

### 2. `mklabel` and data

Does `parted -s /dev/vdb mklabel gpt` delete the filesystems on the disk?

??? question "Answer"
    It deletes the **partition table**, so the filesystems become unreachable through their old device names. The bytes may still be on the disk, but no partition points at them. Treat it as destructive; on a real machine, back up first. On the lab's `vdb` it is the intended first step.

### 3. What `set 1 lvm on` changes

You create a partition with `parted` and forget `set 1 lvm on`. Will `pvcreate` refuse it?

??? question "Answer"
    No. `pvcreate` will accept any block device, including a partition whose GPT type is the generic Linux data type. But the type is how every other tool recognises the partition as an LVM member, and the exam and the checker expect it. Set it. On disk it is the GPT type GUID `E6D6D379-F507-44C2-A23C-238F2A3DF928`.

### 4. Starting at 1 MiB

Why do the labs start the first partition at `1MiB` instead of sector 0?

??? question "Answer"
    Alignment. Starting at 1 MiB keeps partitions aligned with the disk's internal erase blocks and with the 4 KiB blocks the filesystem uses. Misaligned partitions cause extra read-modify-write work, especially on SSDs. Modern tools default to 1 MiB; the labs state it so you know it is deliberate.

### 5. Three commands, three layers

What does each of these create?

```text { .no-copy }
pvcreate /dev/vdb2
vgcreate r6vg /dev/vdb1
lvcreate -n r6data -L 2G r6vg
```

??? question "Answer"
    - `pvcreate /dev/vdb2` writes LVM metadata on partition 2, making it a **physical volume**.
    - `vgcreate r6vg /dev/vdb1` creates a **volume group** named `r6vg` using partition 1 as its first PV. It does not add `vdb2`; that would be `vgextend`.
    - `lvcreate -n r6data -L 2G r6vg` allocates a 2 GiB **logical volume** named `r6data` from `r6vg`.

### 6. UUID, label, or device path

Why does the exam ask for a mount by UUID or label instead of `/dev/vdb1`?

??? question "Answer"
    Device names are assigned in the order the kernel discovers disks and can change when hardware is added or the controller changes. A UUID or label is stored **inside the filesystem**, so it identifies the data no matter which device node it appears on. The trade-off: a new filesystem gets a new UUID, and a label can be changed or duplicated, so both must be kept unique and correct.

### 7. The step everyone skips

You append a correct line to `/etc/fstab` and run `mount -a`. It mounts. What have you not done, and what will `findmnt --verify` say?

??? question "Answer"
    You have not run `systemctl daemon-reload`. systemd generated the mount units from the old fstab and still holds the old version, so starting the unit later may use stale data. `findmnt --verify` warns: "your fstab has been modified, but systemd still uses the old version; use 'systemctl daemon-reload' to reload". `mount -a` and the reload solve different problems; run both.

### 8. `lvs` grew, `df` did not

`lvextend -L +2G /dev/r6vg/r6data` succeeds. `lvs` shows 4 GiB, but `df -h /srv/r6/data` still shows 2 GiB. Why?

??? question "Answer"
    `lvextend` resized the **block device**, not the filesystem on it. The filesystem still has its old geometry. Grow it with `xfs_growfs /srv/r6/data` (XFS, takes the mount point) or `resize2fs /dev/r6vg/r6data` (ext4, takes the device). Then `df` shows the new size.

### 9. Growing and shrinking

Which filesystem can shrink, and what is the rule for XFS?

??? question "Answer"
    XFS can only **grow**; it cannot shrink, online or offline. ext4 can shrink offline with `resize2fs`, after `e2fsck`, and only to a size that still holds the data. For the exam, remember the asymmetry: growing is routine, shrinking is a last resort and is not part of this objective.

### 10. Swap in fstab

Write the fstab line shape for a swap logical volume, and say why the second field is not a directory.

??? question "Answer"
    ```text { .no-copy }
    UUID=<swap-uuid> none swap defaults 0 0
    ```

    Swap is not mounted into the directory tree, so it has no mount point; the field is the literal `none`. The type `swap` is what makes systemd generate a `.swap` unit. Apply it with `systemctl daemon-reload` and `swapon -a`, and check with `swapon --show`.

### 11. Removing storage

Why does `lvremove /dev/r6vg/r6data` fail while `/srv/r6/data` is mounted, and what is the correct order?

??? question "Answer"
    LVM refuses to remove a logical volume that is in use, which prevents deleting live data. Unmount it first, remove its fstab line, `systemctl daemon-reload`, then `lvremove`. If the whole stack goes, continue with `vgremove r6vg`, `pvremove /dev/vdb1`, and finally `parted -s /dev/vdb rm 1`. Removing the partition first would leave LVM looking for a PV that no longer exists.

### 12. What proves persistence

The checker passes and every mount looks right. What single action proves the configuration survives a reboot?

??? question "Answer"
    Reboot the machine and inspect the state **without mounting or activating anything by hand**. `findmnt`, `swapon --show`, and `df` then report what boot did on its own. A configuration that only works in the current session fails the objective. That is why both guided labs and the challenge end with a reboot.

### 13. The fstab safety net

When should a mount line include `nofail`, and when must it not?

??? question "Answer"
    Add `nofail` for storage the system can start without: a spare data disk, a removable drive, a non-critical network mount. Without it, a missing device can drop the boot into emergency mode. Never put `nofail` on `/`, `/boot`, `/boot/efi`, or anything the system needs to reach a usable state; a silent failure there is worse than a visible one.

### 14. Reading the two `findmnt` views

What is the difference between `findmnt /srv/r6/data` and `findmnt --fstab /srv/r6/data`?

??? question "Answer"
    `findmnt` reads the **live mount table**: what is mounted right now. `findmnt --fstab` reads `/etc/fstab`: what the system will try to mount at boot. You want both to agree. A line can be in fstab but not mounted (forgot `mount -a`), or mounted but not in fstab (mounts now, gone after reboot).
