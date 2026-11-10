# R7 knowledge check

Answer first, then open the answer. If you miss a question, return to the matching section of the [theory page](index.md).

### 1. Where VFAT ownership comes from

You mount a VFAT filesystem with no options and `ls -l` shows every file owned by `root`. You then run `chown labuser file.txt` as root. What happens?

??? question "Answer"
    `chown` may report success, and the owner does not change. VFAT stores no UID and no GID; the ownership `ls -l` prints is synthesized by the kernel from the mounting options. The fix is at mount time:

    ```text { .no-copy }
    UUID=FBF7-223A /srv/r7/vfat vfat defaults,uid=labuser,gid=labuser,umask=0077 0 0
    ```

    Change the options, `systemctl daemon-reload`, and remount. Nothing you do to the files is stored on disk.

### 2. What `umask=0077` becomes

`findmnt` shows `fmask=0077,dmask=0077` even though fstab said `umask=0077`. Why two options, and what mode does a new file get?

??? question "Answer"
    `umask=` is shorthand for setting `fmask` and `dmask` together. VFAT has no mode bits, so the kernel starts from a synthetic `0777` and applies the mask. A file gets `0700` (`-rwx------`) and a directory also gets `0700`. Use `fmask=` and `dmask=` separately when files and directories need different modes.

### 3. Three things VFAT cannot do

Name three behaviours that work on ext4 but fail or silently do nothing on VFAT.

??? question "Answer"
    Any three of: `chmod` (succeeds, changes nothing), `chown` (succeeds, changes nothing), symbolic links (`Operation not permitted`), hard links, case-sensitive names (`CaseFile.txt` and `casefile.txt` are the same file), files larger than 4 GiB. This is why VFAT is for exchange — USB sticks, camera cards — and not for server data.

### 4. The export line

Explain each field:

```text { .no-copy }
/srv/r7/export 10.10.10.0/24(rw,sync,no_subtree_check)
```

??? question "Answer"
    - `/srv/r7/export` — the directory being shared.
    - `10.10.10.0/24` — the only clients allowed to mount it. A hostname, an IP, or a network; `*` would allow anyone.
    - `rw` — read-write. The default is `ro`.
    - `sync` — the server replies only after the write has reached disk. `async` is faster and risks data loss on a crash.
    - `no_subtree_check` — do not verify that each requested file is inside the exported subtree. Faster, and the modern default.

### 5. `exportfs -v` shows options you did not write

Your `/etc/exports` says `rw,sync,no_subtree_check`. `exportfs -v` adds `root_squash`, `secure`, `wdelay`, and `no_all_squash`. Where did they come from, and should you remove them?

??? question "Answer"
    They are the defaults. `exportfs -v` prints the **effective** export, the same idea as `systemctl show` versus a unit file. `root_squash` maps a client's UID 0 to `nobody`, which is a security feature. Do not remove it to solve a write problem; fix the directory's ownership on the server instead.

### 6. A file owned by `nobody`

A user on `node2` writes a file into the export and on `server` it is owned by `nobody`. Is the export broken?

??? question "Answer"
    Only if the user was **not** root. `root_squash` is on, so root on the client is `nobody` on the server. A normal user's UID is passed through, and the file is owned by that user on both machines. If a normal user's file shows as `nobody`, the client UID has no matching account on the server — for example a user that exists only on the client.

### 7. Firewall: `nfs` is not enough

You run `firewall-cmd --add-service=nfs` on the server. `showmount -e 10.10.10.10` works, but mounting fails with `access denied by server`. What did you miss?

??? question "Answer"
    `mountd`. NFSv4 serves data on port 2049 (`nfs`), but the mount protocol is handled by `mountd`, and older negotiation uses `rpc-bind`. Open all three:

    ```bash
    firewall-cmd --permanent --add-service=nfs
    firewall-cmd --permanent --add-service=mountd
    firewall-cmd --permanent --add-service=rpc-bind
    firewall-cmd --reload
    ```

    `showmount` succeeding only proves the port is reachable, not that mounting is allowed.

### 8. Indirect and direct maps

What is the difference between these two autofs maps?

```text { .no-copy }
/mnt/r7auto /etc/auto.r7
/- /etc/auto.direct
```

??? question "Answer"
    The first is an **indirect** map: keys in `/etc/auto.r7` become subdirectories under the common parent `/mnt/r7auto`, so a key `share` gives `/mnt/r7auto/share`. The second is a **direct** map: each line in the file names an absolute path to mount, so the key is the whole path. Indirect maps are the usual choice for a set of shares; direct maps are for individual paths that must appear at a fixed location.

### 9. The empty parent directory

`ls /mnt/r7auto` prints nothing, but `/mnt/r7auto/share/hello.txt` is readable. Is autofs broken?

??? question "Answer"
    No. The parent of an indirect map is a mount point, not a listing of possible keys. Nothing is mounted until something accesses a key, and `ls` of the parent does not access it. That is the point of autofs: no mount at boot, no hang when the server is down, and a mount exactly when a path is used. Accessing `share` triggered it; after a period of disuse autofs unmounts it again.

### 10. Why not fstab for everything?

Give one advantage of autofs over an fstab entry for a network filesystem, and one case where fstab is the right tool.

??? question "Answer"
    **Autofs** mounts on access, so an unreachable server cannot block boot, and a client with many possible shares does not hold all of them at once. **fstab** is right for storage the system needs in order to be useful — a data volume a service reads at startup — where "mounted after boot" is a requirement, not a convenience. An fstab network entry normally wants `_netdev` and `nofail` so a dead server does not drop the boot into emergency mode.

### 11. The order of a grow

You have a 512 MiB logical volume with a 512 MiB ext4 filesystem, and 1 GiB free in the volume group. Put these in order: grow the filesystem, grow the logical volume, check the result with `df`, check the result with `lvs`.

??? question "Answer"
    Grow the logical volume → grow the filesystem → `lvs` → `df`.

    ```bash
    lvextend -L +512M /dev/r7vg/r7data
    resize2fs /dev/r7vg/r7data
    lvs
    df -h /srv/r7/data
    ```

    The block device must exist at the new size before the filesystem can claim it. `lvs` proves the volume grew; `df` proves the filesystem followed. A filesystem grown first would have nowhere to grow into.

### 12. Device or mount point

Which argument does each command take, and what happens if you swap them?

```text { .no-copy }
resize2fs
xfs_growfs
```

??? question "Answer"
    `resize2fs` takes the **device** (`/dev/r7vg/r7data`) and can grow a mounted ext4 filesystem online. `xfs_growfs` takes the **mount point** (`/srv/r7/data`) and fails with `not a mounted XFS filesystem` if given the device. This asymmetry is a favourite exam trap; the filesystem type decides the tool, and the tool decides the argument.

### 13. `e2fsck` while mounted

What happens if you run `e2fsck -f` on a mounted filesystem, and what should you do instead?

??? question "Answer"
    Do not. `e2fsck` writes to the device, and on a mounted filesystem that corrupts data and can leave the filesystem inconsistent in ways the running kernel does not expect. Unmount first:

    ```bash
    umount /srv/r7/data
    e2fsck -f /dev/r7vg/r7data
    mount -a
    ```

    If the filesystem is `/`, boot from rescue media instead (R11). `e2fsck -n` is read-only and safe on a mounted filesystem only as a report, never as a repair.

### 14. Reading the `e2fsck` exit code

`e2fsck -f` exits 1. Did it fail?

??? question "Answer"
    No. The exit code is a bitmask, not a success/failure flag:

    | Code | Meaning |
    |---|---|
    | 0 | No errors |
    | 1 | Errors corrected |
    | 2 | Errors corrected, reboot required |
    | 4 | Errors left uncorrected |
    | 8 | Operational error — wrong device, mounted, no terminal |

    `1` means it found and fixed something. `4` and `8` are the ones to act on. A script that treats any non-zero exit as failure will report a repaired filesystem as broken.

### 15. Which filesystem shrinks?

The exam asks you to extend a filesystem. Which of XFS and ext4 can also **shrink**, and under what conditions?

??? question "Answer"
    Only ext4, and only **offline**: unmount, `e2fsck -f`, then `resize2fs <device> <size>`, and reduce the logical volume afterwards. The new size must still hold every used block. XFS cannot shrink at all, online or offline — which is part of why RHEL makes it the default for system filesystems, where shrinking is rarely wanted.

### 16. What proves persistence here

The checker passes and every mount looks right. What single pair of actions proves this module's configuration survives a reboot?

??? question "Answer"
    Reboot **both** machines, then look without mounting anything by hand. On `server`, `findmnt /srv/r7/vfat` and `findmnt /srv/r7/data` should show both mounts, created from fstab; on `node2`, `ls /mnt/r7auto/share` should mount the export on first access. That tests three separate mechanisms: fstab mounts, `nfs-server` being enabled, and `autofs` being enabled with a valid map. A configuration that only works in the current session fails the objective.
