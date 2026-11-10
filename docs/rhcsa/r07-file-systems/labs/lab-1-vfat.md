# Lab 1 — A VFAT volume

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R7 — File systems and sharing |
| **Time** | 45–60 minutes |
| **Check** | `./bin/lab check r07 lab1` |
| **Skills** | `parted`, `mkfs.vfat`, VFAT mount options, `uid=`, `gid=`, `umask=`, `/etc/fstab`, `findmnt` |

</div>

## What you are building

| Item | End state |
|---|---|
| `/dev/vdb` | A GPT partition table |
| `/dev/vdb1` | A 512 MiB partition, Microsoft basic data type |
| Filesystem | VFAT, label **R7DATA** |
| Mount | `/srv/r7/vfat`, recorded in fstab by **UUID** |
| Ownership | Supplied by `uid=labuser,gid=labuser,umask=0077` |
| Persistence | After a reboot, the mount and its ownership return |

You will see what VFAT can and cannot store, and why `chmod` lies on it. This is the filesystem your USB stick uses; the exam expects you to mount one and make it usable by a normal user.

!!! note "Values differ on every machine"
    The VFAT volume UUID (for example `FBF7-223A`) is generated when you format, and it is short because VFAT uses a different UUID format from XFS and ext4. Copy it from your own `blkid`, never from this page.

## Before you begin

Start from the clean snapshot:

```bash
cd labs
./bin/lab restore clean
./bin/lab ssh
sudo -i
```

From here on, every command runs **inside the `server` VM** as root.

`mkfs.vfat` comes from `dosfstools`, which the lab image already has. If a later image drops it:

```bash
dnf install -y dosfstools
```

---

## Step 1 — Look at the disk

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

`vdb` is the 10 GB data disk and it is empty. Everything in this module uses it; `/dev/vda` holds the running system.

## Step 2 — GPT and a 512 MiB partition

```bash
parted -s /dev/vdb mklabel gpt
parted -s /dev/vdb mkpart r7vfat fat32 1MiB 513MiB
udevadm settle
parted -s /dev/vdb print
```

```text { .no-copy }
Number  Start   End    Size   File system  Name    Flags
 1      1049kB  538MB  537MB               r7vfat  msftdata
```

`parted mkpart r7vfat fat32 ...` takes a filesystem-type hint and gives the partition the **Microsoft basic data** GPT type, which is what other operating systems expect for a removable disk. `parted` still does not format it; the next step does.

`513MiB - 1MiB` is 512 MiB. `parted` prints decimal `537MB`; `lsblk` prints binary `512M`. Both are correct.

## Step 3 — Format it as VFAT

```bash
mkfs.vfat -F 32 -n R7DATA /dev/vdb1
blkid /dev/vdb1
```

```text { .no-copy }
mkfs.fat 4.2 (2021-01-31)
/dev/vdb1: LABEL_FATBOOT="R7DATA" LABEL="R7DATA" UUID="FBF7-223A" BLOCK_SIZE="512" TYPE="vfat" PARTLABEL="r7vfat" PARTUUID="2eee664d-e268-48fd-9b63-f2a6e95cc32f"
```

Three identifiers now exist, and they are not the same thing:

| Identifier | Identifies |
|---|---|
| `LABEL="R7DATA"` | The filesystem, by a name you chose |
| `UUID="FBF7-223A"` | The filesystem, by a generated short UUID |
| `PARTUUID="2eee…"` | The **partition**, not the filesystem |

fstab wants the filesystem UUID (`FBF7-223A`) or the label (`R7DATA`), not the PARTUUID.

## Step 4 — Mount it with ownership options

```bash
mkdir -p /srv/r7/vfat
UUID=$(blkid -s UUID -o value /dev/vdb1)
printf 'UUID=%s /srv/r7/vfat vfat defaults,uid=labuser,gid=labuser,umask=0077 0 0\n' "$UUID" >> /etc/fstab
tail -1 /etc/fstab
```

```text { .no-copy }
UUID=FBF7-223A /srv/r7/vfat vfat defaults,uid=labuser,gid=labuser,umask=0077 0 0
```

Apply it:

```bash
systemctl daemon-reload
mount -a
findmnt /srv/r7/vfat
findmnt -no OPTIONS /srv/r7/vfat
```

```text { .no-copy }
TARGET       SOURCE    FSTYPE OPTIONS
/srv/r7/vfat /dev/vdb1 vfat   rw,relatime,uid=1001,gid=1001,fmask=0077,dmask=0077,codepage=437,iocharset=ascii,shortname=mixed,errors=remount-ro

rw,relatime,uid=1001,gid=1001,fmask=0077,dmask=0077,codepage=437,iocharset=ascii,shortname=mixed,errors=remount-ro
```

`uid=labuser` became `uid=1001`: the kernel resolves the name once at mount time and stores the number. `umask=0077` became `fmask=0077,dmask=0077`, the separate file and directory masks.

## Step 5 — Prove what VFAT cannot do

Write a file as `labuser` and look at it:

```bash
runuser -u labuser -- bash -c 'echo hello from vfat > /srv/r7/vfat/note.txt'
ls -l /srv/r7/vfat
```

```text { .no-copy }
total 4
-rwx------. 1 labuser labuser 16 Nov 10 05:46 note.txt
```

The file is owned by `labuser` and mode `700`, even though `labuser` never ran `chmod` and VFAT stored no mode. Both came from the mount options.

Now try to change the mode:

```bash
runuser -u labuser -- chmod 777 /srv/r7/vfat/note.txt
ls -l /srv/r7/vfat
```

```text { .no-copy }
total 4
-rwx------. 1 labuser labuser 16 Nov 10 05:46 note.txt
```

`chmod` exited 0 and nothing changed. There is nowhere on a VFAT filesystem to record a mode, so the kernel keeps synthesising it from `umask=`.

A symbolic link is simply not supported:

```bash
runuser -u labuser -- ln -s note.txt /srv/r7/vfat/link
```

```text { .no-copy }
ln: failed to create symbolic link '/srv/r7/vfat/link': Operation not permitted
```

And names are case-insensitive:

```bash
echo case > /srv/r7/vfat/CaseFile.txt
cat /srv/r7/vfat/casefile.txt
```

```text { .no-copy }
case
```

`casefile.txt` opened `CaseFile.txt`. On XFS or ext4 that would be a different name and `cat` would fail.

Finally, confirm the whole fstab is still valid:

```bash
findmnt --verify
```

```text { .no-copy }
Success, no errors or warnings detected
```

## Step 6 — Persistence: reboot and look again

```bash
systemctl reboot
```

Reconnect from the host, and check without mounting anything by hand:

```bash
cd labs
./bin/lab ssh
sudo -i
findmnt /srv/r7/vfat
ls -l /srv/r7/vfat
```

```text { .no-copy }
TARGET       SOURCE    FSTYPE OPTIONS
/srv/r7/vfat /dev/vdb1 vfat   rw,relatime,uid=1001,gid=1001,fmask=0077,dmask=0077,codepage=437,iocharset=ascii,shortname=mixed,errors=remount-ro

total 4
-rwx------. 1 labuser labuser 16 Nov 10 05:46 note.txt
```

The mount came back from fstab, and the ownership still comes from the fstab options. If `findmnt` prints nothing, compare `blkid -s UUID -o value /dev/vdb1` with the fstab line and run `mount -a` to read the error.

## Verify with the checker

From the host, in the `labs` directory:

```bash
./bin/lab check r07 lab1
```

```text { .no-copy }
R7 Lab 1 — A VFAT volume and mount options
  PASS  /dev/vdb carries a GPT partition table
  PASS  /dev/vdb1 exists
  PASS  /dev/vdb1 is about 512 MiB
  PASS  /dev/vdb1 holds a VFAT filesystem
  PASS  the VFAT filesystem is labelled R7DATA
  PASS  /srv/r7/vfat is mounted
  PASS  fstab mounts /srv/r7/vfat by its UUID
  PASS  the mount maps files to labuser's uid
  PASS  a file written by labuser belongs to labuser
  PASS  VFAT rejects a symbolic link
  PASS  the root filesystem is still in fstab
```

Two checks are behavioural. The checker writes a probe file as `labuser` and reads its owner, and it tries to create a symlink and expects the kernel to refuse. Together they prove the mount really is VFAT with the requested ownership, not an ext4 stand-in.

The last check is the same negative as R6: the root entry still exists, so you appended to fstab instead of replacing it.

## If something went wrong

| Symptom | Likely cause | Fix |
|---|---|---|
| `mkfs.vfat: command not found` | `dosfstools` missing | `dnf install -y dosfstools` |
| `parted: invalid token` | `mkpart` arguments out of order | `parted -s /dev/vdb mkpart NAME fat32 START END` |
| `mount -a`: `can't find UUID` | fstab has the wrong UUID | `blkid /dev/vdb1`, fix the line |
| Files owned by `root` | `uid=`/`gid=` missing from the mount options | Edit fstab, `systemctl daemon-reload`, `mount -o remount /srv/r7/vfat` |
| `chmod` changes nothing | Expected on VFAT | Change the mount options instead |
| `ln -s`: `Operation not permitted` | Expected on VFAT | Use XFS or ext4 if you need symlinks |
| Mount missing after reboot | fstab line malformed, or `daemon-reload` skipped | `findmnt --verify`, then `mount -a` |

To start over, `./bin/lab restore clean` removes the partition table, the filesystem, and the fstab line together.

## Next

[Lab 2 — NFS and autofs](lab-2-nfs-autofs.md) exports a directory from `server` and makes `node2` mount it on demand.
