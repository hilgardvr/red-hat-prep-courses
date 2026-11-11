# Lab 2 — NFS and autofs

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R7 — File systems and sharing |
| **Time** | 75–90 minutes |
| **Check** | `./bin/lab check r07 lab2` |
| **Skills** | `/etc/exports`, `exportfs`, `nfs-server`, firewalld, `mount -t nfs`, `_netdev`, `autofs`, master and automount maps, `root_squash` |

</div>

## What you are building

| Machine | Item | End state |
|---|---|---|
| `server` | Directory | `/srv/r7/export`, owned by `labuser` |
| `server` | Export | `10.10.10.0/24(rw,sync,no_subtree_check)` in `/etc/exports` |
| `server` | Service | `nfs-server` enabled and active |
| `server` | Firewall | `nfs`, `mountd`, and `rpc-bind` allowed |
| `node2` | Manual mount | Proved once by hand, then unmounted |
| `node2` | autofs | `/mnt/r7auto/share` mounts on first access, at boot and after a reboot |
| Both | Persistence | Reboot both machines; `node2` still reaches the export |

This lab uses both VMs, which is why the course has two. `server` is the NFS server; `node2` is the client. You will meet `root_squash` and a real permission problem, and fix it on the correct machine.

## Before you begin

This lab assumes [Lab 1](lab-1-vfat.md) is complete. If you restored the clean snapshot, walk Lab 1 first.

You need two shells:

- **Shell A** — on `server`, as root: `cd labs; ./bin/lab ssh; sudo -i`
- **Shell B** — on `node2`, as root: `cd labs; ./bin/lab ssh node2; sudo -i`

From here on, commands are labelled by the shell they belong in. The VM's prompt shows the hostname (`server` or `node2`), so check it before you press Enter.

---

## Step 1 — Prepare the export directory (server)

```bash
mkdir -p /srv/r7/export
echo "NFS export from server" > /srv/r7/export/hello.txt
chown -R labuser:labuser /srv/r7/export
chmod 755 /srv/r7/export
ls -ld /srv/r7/export
```

```text { .no-copy }
drwxr-xr-x. 2 labuser labuser 66 Nov 10 19:21 /srv/r7/export
```

The directory belongs to `labuser` so a normal user on the client can write to it. That is the fix for the most common NFS permission problem: the export itself is fine, the directory mode is not.

## Step 2 — Export it (server)

```bash
printf '/srv/r7/export 10.10.10.0/24(rw,sync,no_subtree_check)\n' > /etc/exports
cat /etc/exports
systemctl enable --now nfs-server
exportfs -rav
exportfs -v
showmount -e localhost
```

```text { .no-copy }
/srv/r7/export 10.10.10.0/24(rw,sync,no_subtree_check)
exporting 10.10.10.0/24:/srv/r7/export
/srv/r7/export	10.10.10.0/24(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)
Export list for localhost:
/srv/r7/export 10.10.10.0/24
```

`exportfs -v` shows the options you did **not** type. `root_squash` is on, which is the default and the right choice; the next steps show what it does.

## Step 3 — Open the firewall (server)

```bash
firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=mountd
firewall-cmd --permanent --add-service=rpc-bind
firewall-cmd --reload
firewall-cmd --list-services
```

```text { .no-copy }
cockpit dhcpv6-client mountd nfs rpc-bind ssh
```

Opening only `nfs` leaves `mountd` blocked, and the client fails with `access denied by server` even though the export is correct. That message is about the firewall, not `/etc/exports`.

## Step 4 — Mount it by hand (node2)

```bash
dnf install -y nfs-utils
mkdir -p /mnt/r7-nfs
mount -t nfs 10.10.10.10:/srv/r7/export /mnt/r7-nfs
findmnt /mnt/r7-nfs
cat /mnt/r7-nfs/hello.txt
ls -l /mnt/r7-nfs
```

```text { .no-copy }
TARGET      SOURCE                     FSTYPE OPTIONS
/mnt/r7-nfs 10.10.10.10:/srv/r7/export nfs4   rw,relatime,vers=4.2,rsize=524288,wsize=524288,namlen=255,hard,fatal_neterrors=none,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=10.10.10.11,local_lock=none,addr=10.10.10.10

NFS export from server
total 4
-rw-r--r--. 1 labuser labuser 23 Nov 10 05:46 hello.txt
```

The kernel negotiated NFSv4.2 over TCP. Now write to it **as root**:

```bash
echo "written as root" > /mnt/r7-nfs/root-file.txt
```

```text { .no-copy }
bash: /mnt/r7-nfs/root-file.txt: Permission denied
```

That is `root_squash`: the server mapped the client's UID 0 to `nobody`, and `nobody` may not write to a directory owned by `labuser` with mode `755`. Root on the client is not root on the server. Write as a normal user instead:

```bash
runuser -u labuser -- bash -c 'echo "written by labuser" > /mnt/r7-nfs/user-file.txt'
ls -l /mnt/r7-nfs
```

```text { .no-copy }
total 8
-rw-r--r--. 1 labuser labuser 23 Nov 10 05:46 hello.txt
-rw-r--r--. 1 labuser labuser 19 Nov 10 19:21 user-file.txt
```

`labuser`'s UID was passed through, so the file is owned by `labuser` on both machines. Unmount the manual test; autofs takes over next:

```bash
umount /mnt/r7-nfs
```

## Step 5 — Configure autofs (node2)

```bash
dnf install -y autofs
mkdir -p /mnt/r7auto
printf '/mnt/r7auto /etc/auto.r7\n' > /etc/auto.master.d/r7.autofs
printf 'share -rw,sync 10.10.10.10:/srv/r7/export\n' > /etc/auto.r7
cat /etc/auto.master.d/r7.autofs
cat /etc/auto.r7
```

```text { .no-copy }
/mnt/r7auto /etc/auto.r7
share -rw,sync 10.10.10.10:/srv/r7/export
```

Enable and restart the service:

```bash
systemctl enable --now autofs
systemctl restart autofs
```

Now look at the parent, then access the key:

```bash
ls /mnt/r7auto
ls /mnt/r7auto/share
findmnt /mnt/r7auto/share
```

```text { .no-copy }
hello.txt
user-file.txt

TARGET            SOURCE                     FSTYPE OPTIONS
/mnt/r7auto/share 10.10.10.10:/srv/r7/export nfs4   rw,relatime,sync,vers=4.2,rsize=524288,wsize=524288,namlen=255,hard,fatal_neterrors=none,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=10.10.10.11,local_lock=none,addr=10.10.10.10
```

`ls /mnt/r7auto` printed nothing: the parent is a mount point, not a listing. Accessing `share` triggered the mount, and only then did `ls` show the contents. After a few minutes of disuse autofs unmounts it again; the next access remounts.

!!! note "The first `ls` may pause"
    That pause is autofs mounting the export. If it hangs instead, the server is unreachable or the firewall is blocking `mountd`; `systemctl status autofs` and `/var/log/messages` say which.

## Step 6 — Reboot and prove it

Reboot the server first (shell A):

```bash
systemctl reboot
```

Then reboot `node2` (shell B):

```bash
systemctl reboot
```

Both SSH sessions end. Reconnect to `node2` from the host:

```bash
cd labs
./bin/lab ssh node2
sudo -i
ls /mnt/r7auto/share
findmnt /mnt/r7auto/share
```

```text { .no-copy }
hello.txt
user-file.txt

TARGET            SOURCE                     FSTYPE OPTIONS
/mnt/r7auto/share 10.10.10.10:/srv/r7/export nfs4   rw,relatime,sync,vers=4.2,rsize=524288,wsize=524288,namlen=255,hard,fatal_neterrors=none,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=10.10.10.11,local_lock=none,addr=10.10.10.10
```

Nothing mounted the export at boot. The `ls` did, and the export was reachable because `nfs-server` came back from `systemctl enable`. That is the persistence test for both halves.

## Verify with the checker

From the host, in the `labs` directory:

```bash
./bin/lab check r07 lab2
```

```text { .no-copy }
R7 Lab 2 — An NFS export and autofs
  PASS  the NFS server is enabled at boot
  PASS  the NFS server is running
  PASS  the export list includes /srv/r7/export
  PASS  the export is limited to the lab network
  PASS  showmount lists the export
  PASS  firewalld allows the nfs service
  PASS  node2 has autofs enabled at boot
  PASS  node2 has autofs running
  PASS  node2 has an autofs master drop-in
  PASS  node2 has the r7 automount map
  PASS  the map defines the share key
  PASS  the map points at the server export
  PASS  accessing the automount path mounts the export
  PASS  the automount is an NFS filesystem
  PASS  the VFAT volume is still mounted
```

The checker runs on `server` and reaches `node2` over SSH as `labuser`, using the shared lab key. It triggers the automount by reading the export, then asks `findmnt` what appeared. Both VMs must be running.

## If something went wrong

| Symptom | Likely cause | Fix |
|---|---|---|
| `access denied by server` | Client not in `/etc/exports`, or `mountd` blocked | Check the network in `exportfs -v`; add `mountd` and `rpc-bind` |
| `mount: ... unknown filesystem type 'nfs'` | `nfs-utils` missing on the client | `dnf install -y nfs-utils` |
| `mount` hangs | Firewall blocking, or server down | `firewall-cmd --list-services` on server; `showmount -e 10.10.10.10` |
| Root cannot write | `root_squash` | Write as a normal user; do not disable the squash |
| `labuser` cannot write | Export directory mode or owner | `chown labuser:labuser /srv/r7/export`, mode `755` or `775` |
| `ls /mnt/r7auto` is empty | That is the parent of an indirect map | Access `/mnt/r7auto/share` |
| Map changes ignored | autofs caches the map | `systemctl restart autofs` |
| Mount missing after reboot | `autofs` not enabled, or the map file was not written | `systemctl is-enabled autofs`; `cat` both map files |
| `showmount` lists nothing | `exportfs -rav` not run | Run it, then `exportfs -v` |

To undo this lab without losing Lab 1: on `node2`, `systemctl disable --now autofs`, remove `/etc/auto.master.d/r7.autofs` and `/etc/auto.r7`; on `server`, remove the line from `/etc/exports`, run `exportfs -ra`, and `systemctl disable --now nfs-server`. Then `./bin/lab restore clean` on both if you want a completely fresh start.

## Next

[Challenge — Grow ext4 without losing data](challenge-grow-ext4.md) builds an ext4 logical volume, fills it, grows it while mounted, and proves nothing was lost.
