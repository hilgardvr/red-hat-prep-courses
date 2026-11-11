# R12 cheat sheet

A compact review for the capstone. It adds no new commands; it collects the ones the mock exams use, grouped by what they prove. Everything is explained in the [theory page](index.md).

## The four persistence layers

| Layer | Volatile | Persistent | Proof |
|---|---|---|---|
| Storage | `mount /dev/vg/lv /path` | a line in `/etc/fstab` | `findmnt --target /path` and `findmnt --fstab --target /path` |
| Service | `systemctl start unit` | `systemctl enable unit` | `systemctl is-enabled unit` |
| Firewall | `firewall-cmd --add-port=…` | `--permanent` + `--reload` | `firewall-cmd --permanent --query-port=…` |
| SELinux | `chcon -t …` | `semanage fcontext -a -t …` + `restorecon` | `semanage fcontext -l -C` |

Two more that behave the same way:

| Layer | Volatile | Persistent | Proof |
|---|---|---|---|
| Boot target | `systemctl isolate target` | `systemctl set-default target` | `systemctl get-default` |
| Kernel argument | type it at the GRUB menu | `grubby --update-kernel=ALL --args=…` | `grubby --info=ALL` and `/proc/cmdline` |

## Verify as you go

```bash
# Users and policy
id r12deploy
LC_ALL=C chage -l r12deploy
passwd -S r12deploy
visudo -cf /etc/sudoers.d/10-r12-deploy
visudo -c
sudo -l -U r12deploy

# Storage
lsblk -f
findmnt --target /srv/r12/www
findmnt --fstab --target /srv/r12/www
findmnt --verify
lvs
blkid -s UUID -o value /dev/r12vg/r12www

# Services and schedules
systemctl is-enabled httpd r12-stamp.timer
systemctl is-active httpd r12-stamp.timer
systemctl list-timers --all
journalctl -u httpd -n 20 --no-pager

# Network and firewall
ss -ltnH
firewall-cmd --zone=public --list-all
firewall-cmd --zone=public --query-port=8088/tcp
firewall-cmd --permanent --zone=public --query-port=8088/tcp

# SELinux
ls -Z /srv/r12/www/index.html
restorecon -Rn /srv/r12/www
semanage fcontext -l -C
semanage port -l -C
getenforce

# Boot
systemctl get-default
grubby --info=ALL | grep -E '^index|^args'
cat /proc/cmdline
```

## Prove it from the other machine

```bash
ssh labuser@node2 'curl -sS -m 5 http://10.10.10.10:8088/'
```

A local `curl` proves the service. Only a request from `node2` proves the firewall, the zone, and the path a real client takes.

## Reading a failure

| Symptom | First question | Then |
|---|---|---|
| `403` | `ls -Z` on the file | AVC present → SELinux; no AVC → mode, owner, or `Require all granted` |
| `curl: (7)` from the peer | Which zone does the packet enter? | `--permanent --add-port`, `--reload`, fetch again |
| `curl: (6)` from the peer | Name resolution | `getent hosts`, `/etc/hosts` |
| `503` from a proxy path | The backend, then the Boolean | `ss -ltn`, `getsebool httpd_can_network_connect` |
| Works now, gone after reboot | `findmnt --fstab` | Fix the source from `blkid`; `daemon-reload`; `findmnt --verify` |
| `203/EXEC` | `ls -Z` on the program | `var_t` under `/srv`; install in `/usr/local/bin` |
| Timer never fires | `list-timers --all` | Enabled the timer, not the service; `Type=oneshot` |
| Unit `activating` forever | The service type | Add `Type=oneshot` for a program that exits |

## Build order that does not fight itself

```text { .no-copy }
packages → storage → mount + fstab → content → owner/mode
        → SELinux fcontext + restorecon → service config + port label
        → start + enable → firewall → prove from peer
        → schedule → prove the artefact → reboot → re-prove
```

Storage before content, because the content lives on the volume. Content before SELinux, because the label applies to a path that must exist. SELinux before the service test, because a `403` and a `403` have different causes. Service before firewall, because the port must exist before it can be opened. Schedule last, because it should run against a healthy host.

## The pass phrase

For every task, ask three questions before you move on:

1. **Is it true now?** — the live state or a local request.
2. **Will it still be true after a reboot?** — fstab, `enable`, `--permanent`, `semanage fcontext`.
3. **Can someone else see it?** — a request from `node2`, not from loopback.

## Time plan

| Phase | Share | What |
|---|---|---|
| Read | 10% | Read every task; mark the easy ones; do not start |
| First pass | 40% | Confident tasks, fastest first, verify each |
| Second pass | 30% | The rest; abandon a stuck task with a note |
| Persistence pass | 10% | fstab, enabled units, permanent rules, SELinux records |
| Reboot + re-check | 10% | Reboot if allowed; re-run every proof |

## Do not

| Temptation | Why it fails |
|---|---|
| `setenforce 0` or stopping `firewalld` | The grader reads `getenforce` and the zone; the task is the policy |
| `chcon` for a label you must keep | The next relabel reverts it |
| `--add-port` without `--permanent` | Gone at `--reload` or reboot |
| `start` without `enable` | The reboot check fails |
| Editing `/boot/grub2/grub.cfg` by hand | `grub2-mkconfig` overwrites it; use `grubby` |
| `isolate` when the task says "at boot" | `get-default` does not change |
| Testing only on loopback | Proves the service, not the network |
| Twenty minutes on one task | Three easier tasks are worth more |
