# Lab 1 — The full-stack rehearsal

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R12 — Capstone |
| **Time** | 90–120 minutes |
| **Check** | `./bin/lab check r12 lab1` |
| **Style** | Guided: every step, with expected output |

</div>

This lab builds one small service host from a clean machine. It is not a new topic. Every block comes from a module you have already finished, and the point is to do them **in one sitting, on one machine, in the order a task list would give them**.

That order matters. Storage comes before content, because the content lives on the volume. Content comes before SELinux, because the label applies to a path that must exist. SELinux comes before the service test, because a `403` and a `403` have different causes. The firewall comes after the service, because the port must exist before it can be opened.

Commands on this page are reference material. Read them, then run them on the lab; do not memorise the page.

## What you are building

| Piece | End state |
|---|---|
| Disk | `/dev/vdb1`, GPT, Linux LVM type |
| Volume group | `r12vg` |
| Logical volume | `r12www`, about 2 GiB, XFS |
| Mount | `/srv/r12/www`, by UUID in `/etc/fstab` |
| Group | `r12web` |
| Account | `r12deploy`, primary group `r12web`, password aging 7/90/14 |
| Sudo | `/etc/sudoers.d/10-r12-deploy`, may restart `httpd` without a password |
| Content | `/srv/r12/www/index.html`, owned `r12deploy:r12web` |
| SELinux | `/srv/r12/www` mapped to `httpd_sys_content_t`; port `8088` labelled `http_port_t` |
| Service | `httpd`, enabled and active, listening on `8088` |
| Firewall | `8088/tcp` open in `public`, permanently |
| Schedule | `r12-stamp.timer`, every minute, writes `/srv/r12/reports/r12-stamp.txt` |
| Boot | still `multi-user.target` |

Two machines must be running, because the last proof is a request from `node2`.

Start from the clean snapshot:

```bash
cd labs
./bin/lab restore clean
./bin/lab up
```

Log in to `server` and become root:

```bash
./bin/lab ssh
sudo -i
```

The build needs a working repository. If you left R3's distro repositories disabled, re-enable them first; `dnf` will otherwise fail at the next step with `Unable to find a match`.

## Step 1 — The packages

```bash
dnf -y install lvm2 httpd policycoreutils-python-utils
```

```text { .no-copy }
Installing:
 httpd                          x86_64  2.4.63-13.el10_2.8     appstream   54 k
 lvm2                           x86_64  10:2.03.36-2.el10      baseos     1.6 M
 policycoreutils-python-utils   noarch  3.10-2.el10_2          appstream   45 k
...
Complete!
```

Three packages, three reasons. `lvm2` brings the LVM userland, which the base image does not ship. `httpd` is the service. `policycoreutils-python-utils` brings `semanage`, without which you can set a label but not make it persist.

Enable the service now, while you are thinking about packages:

```bash
systemctl enable httpd
```

```text { .no-copy }
Created symlink '/etc/systemd/system/multi-user.target.wants/httpd.service' → '/usr/lib/systemd/system/httpd.service'.
```

The symlink is the persistence. `enable` creates it; `start` only runs the unit.

## Step 2 — The volume

`/dev/vdb` is the 10 GB disk the lab kit attaches and leaves empty. Partition it, mark the partition as LVM, and build the stack:

```bash
parted -s /dev/vdb mklabel gpt
parted -s /dev/vdb mkpart primary 1MiB 100%
parted -s /dev/vdb set 1 lvm on
partprobe /dev/vdb
sfdisk -d /dev/vdb
```

```text { .no-copy }
label: gpt
label-id: 13D10886-0D9F-40F1-8237-AA5EA6411DF7
device: /dev/vdb
unit: sectors
first-lba: 34
last-lba: 20971486
sector-size: 512

/dev/vdb1 : start=        2048, size=    20967424, type=E6D6D379-F507-44C2-A23C-238F2A3DF928, uuid=80EC23F6-DF3C-4CB9-9A83-30571351E176, name="primary"
```

That long `type=` value is the GPT type GUID for Linux LVM. It is the machine-readable proof that `set 1 lvm on` worked; `parted print` shows the same fact as the word `lvm`, which is harder to check automatically.

```bash
pvcreate /dev/vdb1
vgcreate r12vg /dev/vdb1
lvcreate -n r12www -L 2G r12vg
mkfs.xfs /dev/r12vg/r12www
```

```text { .no-copy }
  Physical volume "/dev/vdb1" successfully created.
  Volume group "r12vg" successfully created
  Logical volume "r12www" created.
meta-data=/dev/r12vg/r12www      isize=512    agcount=4, agsize=131072 blks
...
Discarding blocks...Done.
```

Now mount it by UUID, which is the form that survives a reboot even if the device name changes:

```bash
mkdir -p /srv/r12/www
printf 'UUID=%s /srv/r12/www xfs defaults 0 0\n' \
  "$(blkid -s UUID -o value /dev/r12vg/r12www)" | tee -a /etc/fstab
systemctl daemon-reload
mount -a
findmnt /srv/r12/www
findmnt --verify
```

```text { .no-copy }
UUID=a556ced3-d69a-4da9-8d2a-a03db0ec2059 /srv/r12/www xfs defaults 0 0
TARGET       SOURCE                   FSTYPE OPTIONS
/srv/r12/www /dev/mapper/r12vg-r12www xfs    rw,relatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,noquota
Success, no errors or warnings detected
```

The UUID is generated on your walk and will differ. Everything else should match.

`findmnt --verify` is the closest thing to a boot test you can run without rebooting. It reads the whole of `/etc/fstab` and reports an entry that boot could not mount. It also warns when you edited `fstab` without `daemon-reload`, which is why that command is in the sequence and not after it.

## Step 3 — The account

```bash
groupadd r12web
useradd -g r12web -m -s /bin/bash r12deploy
echo 'R12-labpass' | passwd --stdin r12deploy
chage -m 7 -M 90 -W 14 r12deploy
chage -l r12deploy
```

```text { .no-copy }
Last password change					: Nov 11, 2026
Password expires					: Feb 09, 2027
Password inactive					: never
Account expires						: never
Minimum number of days between password change		: 7
Maximum number of days between password change		: 90
Number of days of warning before password expires	: 14
```

The password is a lab value, not a secret. The aging is the requirement: seven days before a change is allowed, ninety days before it expires, fourteen days of warning.

Now give the account exactly one privileged action, and no more:

```bash
cat > /etc/sudoers.d/10-r12-deploy <<'EOF'
r12deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart httpd.service
EOF
chmod 0440 /etc/sudoers.d/10-r12-deploy
visudo -cf /etc/sudoers.d/10-r12-deploy
visudo -c
sudo -l -U r12deploy
```

```text { .no-copy }
/etc/sudoers.d/10-r12-deploy: parsed OK
/etc/sudoers: parsed OK
/etc/sudoers.d/10-r12-deploy: parsed OK
/etc/sudoers.d/90-cloud-init-users: parsed OK
/etc/sudoers.d/90-rhcsa-labuser: parsed OK
/etc/sudoers.d/vagrant: parsed OK
...
User r12deploy may run the following commands on server:
    (root) NOPASSWD: /usr/bin/systemctl restart httpd.service
```

Two checks, not one. `visudo -cf` proves the drop-in parses on its own. `visudo -c` proves the whole stack still parses; a drop-in that is fine alone can still break the configuration. The mode matters as much as the content, which is why `chmod 0440` comes before both.

The sudoers file names a full path, `/usr/bin/systemctl`, because a rule must match what `sudo` actually execs. `sudo -l -U` is how you confirm the rule from the user's point of view rather than your intention.

## Step 4 — The content and its label

Write the page on the new volume:

```bash
cat > /srv/r12/www/index.html <<'EOF'
<!doctype html>
<title>R12 portal</title>
<h1>R12 portal is live</h1>
EOF
chown r12deploy:r12web /srv/r12/www/index.html
chmod 0644 /srv/r12/www/index.html
ls -l /srv/r12/www
```

```text { .no-copy }
total 4
-rw-r--r--. 1 r12deploy r12web 70 Nov 11 05:00 index.html
```

The file has the right owner and mode, and the web server still cannot read it. Now ask SELinux what it thinks:

```bash
ls -Z /srv/r12/www/index.html
```

```text { .no-copy }
unconfined_u:object_r:unlabeled_t:s0 /srv/r12/www/index.html
```

`unlabeled_t` is what a freshly formatted filesystem can look like before a relabel. A brand-new XFS volume mounted under `/srv` has no stored label for the files created at the top of it, and the policy has no rule that matches `/srv/r12/www`. The filesystem is fine; the label is not.

Write the rule, then apply it:

```bash
semanage fcontext -a -t httpd_sys_content_t '/srv/r12/www(/.*)?'
restorecon -Rv /srv/r12/www
semanage fcontext -l -C
ls -Z /srv/r12/www/index.html
```

```text { .no-copy }
Relabeled /srv/r12/www from system_u:object_r:unlabeled_t:s0 to system_u:object_r:httpd_sys_content_t:s0
Relabeled /srv/r12/www/index.html from unconfined_u:object_r:unlabeled_t:s0 to unconfined_u:object_r:httpd_sys_content_t:s0
SELinux fcontext                                   type               Context

/srv/r12/www(/.*)?                                 all files          system_u:object_r:httpd_sys_content_t:s0
unconfined_u:object_r:httpd_sys_content_t:s0 /srv/r12/www/index.html
```

Two things happened. `restorecon` fixed the label **now**, and `semanage fcontext` recorded the rule so the same label comes back after a relabel or a reboot. `chcon` would have done only the first.

The pattern `/srv/r12/www(/.*)?` matches the directory itself and everything below it. Without the `(/.*)?` the rule matches the directory and leaves the files inside unlabelled, which is a classic partial fix.

## Step 5 — The service

Apache needs two changes: a listener on the new port, and permission to read the directory. The second is already in the policy because you labelled it; the first needs a SELinux port label as well.

```bash
cat > /etc/httpd/conf.d/r12-portal.conf <<'EOF'
Listen 8088

<VirtualHost *:8088>
    DocumentRoot /srv/r12/www
    <Directory /srv/r12/www>
        Require all granted
    </Directory>
</VirtualHost>
EOF
semanage port -a -t http_port_t -p tcp 8088
semanage port -l -C
systemctl restart httpd
systemctl is-active httpd
curl -sS http://127.0.0.1:8088/
```

```text { .no-copy }
SELinux Port Type              Proto    Port Number

http_port_t                    tcp      8088
active
<!doctype html>
<title>R12 portal</title>
<h1>R12 portal is live</h1>
```

The port label is not decoration. Without it, `httpd` fails to bind and the journal reports a `name_bind` denial naming the port. With it, the daemon starts and the page is served.

Check that the listener is where it should be:

```bash
ss -ltnH | grep 8088
```

```text { .no-copy }
LISTEN 0      511          *:8088       *:*
```

## Step 6 — The firewall

A local `curl` never leaves the machine, so it proves the service and nothing about the network. Open the port in the zone that `node2`'s traffic actually enters, and make it permanent in the same operation:

```bash
firewall-cmd --permanent --zone=public --add-port=8088/tcp
firewall-cmd --reload
firewall-cmd --zone=public --query-port=8088/tcp
firewall-cmd --zone=public --list-ports
```

```text { .no-copy }
success
success
yes
8088/tcp
```

Then prove it from the other machine. This is the only check that exercises the interface rules:

```bash
ssh labuser@node2 'curl -sS -m 5 http://10.10.10.10:8088/'
```

```text { .no-copy }
<!doctype html>
<title>R12 portal</title>
<h1>R12 portal is live</h1>
```

If this fails while the local `curl` works, the service is fine and the packet is not arriving. That distinction is the whole lesson of Lab 2.

## Step 7 — The schedule

A timer needs two units: the service that does the work, and the timer that triggers it.

```bash
cat > /usr/local/bin/r12-stamp <<'EOF'
#!/bin/bash
install -d -m 0755 /srv/r12/reports
printf 'r12 portal probe %s\n' "$(date -Is)" >> /srv/r12/reports/r12-stamp.txt
EOF
chmod 0755 /usr/local/bin/r12-stamp
ls -Z /usr/local/bin/r12-stamp
```

```text { .no-copy }
unconfined_u:object_r:bin_t:s0 /usr/local/bin/r12-stamp
```

The program lives in `/usr/local/bin`, not `/srv`. systemd runs as `init_t`, which may execute `bin_t` but not `var_t`. A timer pointing at a program under `/srv` fails with `203/EXEC`, the same trap R5 taught.

```bash
cat > /etc/systemd/system/r12-stamp.service <<'EOF'
[Unit]
Description=R12 portal probe

[Service]
Type=oneshot
ExecStart=/usr/local/bin/r12-stamp
EOF

cat > /etc/systemd/system/r12-stamp.timer <<'EOF'
[Unit]
Description=Run the R12 portal probe every minute

[Timer]
OnCalendar=*:0/1
AccuracySec=1s

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now r12-stamp.timer
systemctl list-timers r12-stamp.timer --no-pager
```

```text { .no-copy }
Created symlink '/etc/systemd/system/timers.target.wants/r12-stamp.timer' → '/etc/systemd/system/r12-stamp.timer'.
NEXT                        LEFT LAST PASSED UNIT            ACTIVATES
Wed 2026-11-11 05:01:00 UTC   5s -         - r12-stamp.timer r12-stamp.service
```

`OnCalendar=*:0/1` means second zero of every minute. `AccuracySec=1s` keeps the timer from being spread across the minute, which matters when you are waiting for the first run. `Type=oneshot` is required for a service that finishes; without it the unit stays `activating`.

Wait one minute, then read the artefact rather than the unit:

```bash
sleep 70
cat /srv/r12/reports/r12-stamp.txt
```

```text { .no-copy }
r12 portal probe 2026-11-11T05:01:00+00:00
r12 portal probe 2026-11-11T05:02:00+00:00
```

Timestamps differ on every walk. What matters is that the file has more than one line, which proves the schedule repeats rather than firing once at enable time.

## Step 8 — Reboot and prove it

Everything so far is a promise that the next boot has to keep:

```bash
systemctl reboot
```

When the machine comes back, log in again and re-run the proofs:

```bash
./bin/lab ssh
sudo -i
```

```bash
systemctl get-default
findmnt /srv/r12/www
systemctl is-enabled httpd r12-stamp.timer
systemctl is-active httpd r12-stamp.timer
firewall-cmd --zone=public --query-port=8088/tcp
curl -sS http://127.0.0.1:8088/
```

```text { .no-copy }
multi-user.target
TARGET       SOURCE                   FSTYPE OPTIONS
/srv/r12/www /dev/mapper/r12vg-r12www xfs    rw,relatime,seclabel,attr2,inode64,logbufs=8,logbsize=32k,noquota
enabled
enabled
active
active
yes
<h1>R12 portal is live</h1>
```

Then run the checker. It lives on your host, not in the guest, so leave the root shell first (`exit` twice, or open a new terminal):

```bash
./bin/lab check r12 lab1
```

```text { .no-copy }
Lab 1 — the full-stack rehearsal
  PASS  /dev/vdb1 exists
  PASS  /dev/vdb1 is a Linux LVM partition
  ...
  PASS  the machine still boots into multi-user.target

35 passed, 0 failed
```

## What the checker reads

| Check | Evidence |
|---|---|
| The volume is real and about 2 GiB | `sfdisk -d` type GUID, `lvs --units b`, `findmnt -b` |
| fstab matches the filesystem | the UUID from `blkid`, compared with `findmnt --fstab` |
| The whole fstab is boot-safe | `findmnt --verify` |
| The account and its aging | `id -gn`, `passwd -S`, `chage -l` in the C locale |
| The sudo rule is narrow | `visudo -c`, `sudo -l -U r12deploy` |
| The label is live **and** persistent | `ls -Z` plus `semanage fcontext -l -C` |
| The port is labelled | `semanage port -l -C` |
| The service is enabled, active, listening | `systemctl`, `ss` |
| The firewall is open in both layers | `--query-port`, permanent and runtime |
| A client can reach it | a real `curl` from `node2` as `labuser` |
| The schedule produced output | the stamp file's age |
| The boot target is unchanged | `systemctl get-default` |

The order is deliberate: each check reads the **end state**, never the command you used. A different sequence that produces the same state passes.

## Traps

| Trap | Symptom | Fix |
|---|---|---|
| Mounted the volume but forgot `fstab` | Works now, gone after reboot | Add the UUID line, `daemon-reload`, `mount -a` |
| `chcon` instead of `semanage fcontext` | Works until a relabel | Write the record, then `restorecon` |
| Pattern without `(/.*)?` | Directory labelled, files not | `/srv/r12/www(/.*)?` |
| Forgot the SELinux port label | `httpd` fails to bind, `name_bind` in the journal | `semanage port -a -t http_port_t -p tcp 8088` |
| Opened the port without `--permanent` | Works until `--reload` | `--permanent`, then `--reload` |
| Tested only with a local `curl` | Service fine, network blocked | Fetch from `node2` |
| Timer unit without `Type=oneshot` | Unit stuck `activating` | Add `Type=oneshot` |
| Program under `/srv` | `203/EXEC` | Install it in `/usr/local/bin` |
| `enable`d the service instead of the timer | Timer never fires | `enable r12-stamp.timer` |

## Next

[Lab 2 — The diagnostic loop](lab-2-diagnosis.md) breaks this machine in three places and makes you find each one from the evidence.
