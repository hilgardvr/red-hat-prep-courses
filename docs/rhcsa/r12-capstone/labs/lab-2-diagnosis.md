# Lab 2 — The diagnostic loop

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R12 — Capstone |
| **Time** | 40–60 minutes |
| **Check** | `./bin/lab check r12 lab2` |
| **Style** | Guided: break, diagnose, repair |

</div>

Lab 1 built a working host. This lab breaks it in three places, one per layer, and asks you to find each one from the evidence rather than from memory.

That is the skill the exam actually tests. You will make mistakes under time pressure. The difference between a pass and a fail is rarely the mistake; it is whether you can read the symptom and fix the right layer.

Three breakages:

| # | Layer | What breaks | What still works |
|---|---|---|---|
| 1 | Storage | The fstab entry points at a UUID that does not exist | Everything — until the next boot |
| 2 | SELinux | The page loses its label and the persistent mapping is deleted | The service, the port, and the firewall |
| 3 | Firewall | The permanent port rule is removed | The service, locally |

Each has a different symptom and a different diagnostic tool. Run them together, then work them one at a time.

## Before you start

This lab assumes the end state of [Lab 1](lab-1-rehearsal.md). Confirm it:

```bash
./bin/lab check r12 lab1
```

If that does not end in `35 passed, 0 failed`, finish Lab 1 first. Debugging a broken machine with a broken baseline teaches nothing.

## Step 1 — Break all three

Apply the three changes in one go. Reading them is part of the exercise: each one is a single, realistic mistake.

```bash
# 1. storage: a UUID that does not exist
sed -i 's|^UUID=[0-9a-f-]* /srv/r12/www|UUID=00000000-0000-0000-0000-000000000000 /srv/r12/www|' /etc/fstab

# 2. SELinux: remove the persistent mapping and relabel the page by hand
semanage fcontext -d '/srv/r12/www(/.*)?'
chcon -t var_t /srv/r12/www/index.html

# 3. firewall: drop the permanent rule and reload
firewall-cmd --permanent --zone=public --remove-port=8088/tcp
firewall-cmd --reload
```

Now confirm that the host looks fine from the inside:

```bash
findmnt /srv/r12/www
curl -sS -o /dev/null -w 'local: %{http_code}\n' http://127.0.0.1:8088/
firewall-cmd --zone=public --query-port=8088/tcp
```

The mount is up, the local request returns `403` (break 2), and the firewall says `no` (break 3). Nothing has crashed. That is the point: a broken machine rarely announces itself.

## Step 2 — Read the report

```bash
./bin/lab check r12 lab2
```

```text { .no-copy }
Lab 2 — the diagnostic loop
  FAIL  the fcontext mapping was restored, not just chcon'd
  FAIL  fstab mounts the volume by the live UUID again
  PASS  the volume is mounted again
  FAIL  the permanent firewall rule is back
  FAIL  the page is labelled httpd_sys_content_t again
  FAIL  node2 can fetch the page again
        expected text: R12\ portal\ is\ live
        actual:        ''
...
30 passed, 12 failed
```

Twelve red lines for three mistakes, because each phase checks the consequences as well as the cause. Do not try to fix twelve things. Group them by layer:

| Failed line | Layer |
|---|---|
| `fstab mounts the volume by the live UUID`, `the whole fstab validates` | storage |
| `the page is labelled httpd_sys_content_t`, `a persistent fcontext record …` | SELinux |
| `the permanent firewall allows 8088/tcp`, `the running firewall allows …`, `node2 can fetch …` | firewall |

## Step 3 — Storage: the failure that is invisible now

```bash
grep r12 /etc/fstab
findmnt --verify
```

```text { .no-copy }
UUID=00000000-0000-0000-0000-000000000000 /srv/r12/www xfs defaults 0 0

0 parse errors, 1 error, 1 warning
/srv/r12/www
   [E] unreachable on boot required source: UUID=00000000-0000-0000-0000-000000000000
   [W] your fstab has been modified, but systemd still uses the old version;
       use 'systemctl daemon-reload' to reload
```

This is the most dangerous class of mistake in the exam, because the machine is working. The volume is mounted, the page is served, and the grader for every other task would pass. The failure is scheduled for the next boot.

`findmnt --verify` is the tool that sees the future. It resolves the source the way boot will, and reports an entry that cannot be mounted. That is why R6 made it the last step of every storage task.

Repair it from the device, never by retyping the UUID:

```bash
sed -i "s|^UUID=[0-9a-f-]* /srv/r12/www|UUID=$(blkid -s UUID -o value /dev/r12vg/r12www) /srv/r12/www|" /etc/fstab
grep r12 /etc/fstab
systemctl daemon-reload
findmnt --verify
```

```text { .no-copy }
UUID=a556ced3-d69a-4da9-8d2a-a03db0ec2059 /srv/r12/www xfs defaults 0 0
Success, no errors or warnings detected
```

Building the replacement from `blkid` means the value is the filesystem's own identity, not your memory of it. The `daemon-reload` clears the warning and makes systemd read the new file.

## Step 4 — SELinux: the `403` with a reason

```bash
ls -Z /srv/r12/www/index.html
curl -sS -o /dev/null -w 'local: %{http_code}\n' http://127.0.0.1:8088/
grep ': avc:' /var/log/audit/audit.log | tail -2
```

```text { .no-copy }
unconfined_u:object_r:var_t:s0 /srv/r12/www/index.html
local: 403
type=AVC msg=audit(1794373383.990:812): avc:  denied  { getattr } for  pid=1866 comm="httpd"
  path="/srv/r12/www/index.html" dev="dm-0" ino=131
  scontext=system_u:system_r:httpd_t:s0 tcontext=unconfined_u:object_r:var_t:s0
  tclass=file permissive=0
```

Three pieces of evidence, in increasing order of usefulness. The status code says "no". The label says `var_t`, which is the default for `/srv` and not a web content type. The AVC says **which** permission was refused (`getattr`), **which** process asked (`httpd_t`), and **which** label it found (`var_t`).

That is the difference between guessing and knowing. A `403` with an AVC is SELinux. A `403` without one is a file mode, a missing `Require all granted`, or a missing file.

If `grep` finds nothing, the denial is older than `audit.log`'s rotation or `auditd` is not running. On this image `ausearch -m AVC -ts recent` can return `<no matches>` even with denials present; the `grep` is the reliable fallback.

Repair it in both layers:

```bash
semanage fcontext -a -t httpd_sys_content_t '/srv/r12/www(/.*)?'
restorecon -Rv /srv/r12/www
ls -Z /srv/r12/www/index.html
curl -sS -o /dev/null -w 'local: %{http_code}\n' http://127.0.0.1:8088/
```

```text { .no-copy }
Relabeled /srv/r12/www/index.html from unconfined_u:object_r:var_t:s0 to unconfined_u:object_r:httpd_sys_content_t:s0
unconfined_u:object_r:httpd_sys_content_t:s0 /srv/r12/www/index.html
local: 200
```

The record comes first, the relabel second. Reverse that order and the fix lasts until the next relabel, which is exactly what `chcon` did.

## Step 5 — Firewall: the failure the machine cannot see

```bash
firewall-cmd --zone=public --list-all
curl -sS -o /dev/null -w 'local: %{http_code}\n' http://127.0.0.1:8088/
ssh labuser@node2 'curl -sS -m 5 -o /dev/null -w "from node2: %{http_code}\n" http://10.10.10.10:8088/'
```

```text { .no-copy }
public (default, active)
  target: default
  ingress-priority: 0
  egress-priority: 0
  icmp-block-inversion: no
  interfaces: eth0 eth1
  sources:
  services: cockpit dhcpv6-client ssh
  ports:
  protocols:
  forward: yes
  masquerade: no
  forward-ports:
  source-ports:
  icmp-blocks:
  rich rules:
local: 200
from node2: 000
curl: (7) Failed to connect to 10.10.10.10 port 8088 after 0 ms: Could not connect to server
```

`local: 200` and `from node2: 000` in one pair of lines is the whole case. The service is healthy and the network path is not. The empty `ports:` line names the layer.

`curl: (7)` means the connection was refused or dropped before HTTP existed. There is no journal entry on `server` for a request that never arrived, which is why "check the logs" is the wrong first move here. Ask the firewall, and ask the peer.

Repair it and reload:

```bash
firewall-cmd --permanent --zone=public --add-port=8088/tcp
firewall-cmd --reload
firewall-cmd --zone=public --list-ports
ssh labuser@node2 'curl -sS -m 5 http://10.10.10.10:8088/'
```

```text { .no-copy }
success
success
8088/tcp
<!doctype html>
<title>R12 portal</title>
<h1>R12 portal is live</h1>
```

`success` from `--permanent` alone is not the end of the task; the rule is in the file and not in the running firewall until `--reload` (or a reboot). Do both, every time.

## Step 6 — Prove the repair

Leave the guest root shell (`exit` twice) and run the checker on your host:

```bash
./bin/lab check r12 lab2
```

```text { .no-copy }
Lab 2 — the diagnostic loop
  PASS  the fcontext mapping was restored, not just chcon'd
  PASS  fstab mounts the volume by the live UUID again
  PASS  the volume is mounted again
  PASS  the permanent firewall rule is back
  PASS  the page is labelled httpd_sys_content_t again
  PASS  node2 can fetch the page again
  PASS  the timer still probes after the repair
...
42 passed, 0 failed
```

The last line of the first block is the one people forget: `the timer still probes`. A repair that leaves the host otherwise healthy is the only repair that counts. The checker re-runs the whole rehearsal state after the three specified repairs, so you cannot pass by fixing three lines and breaking something else.

Then take the persistence test. Reboot the guest, log back in, and run `all` from the host:

```bash
systemctl reboot
```

```bash
./bin/lab check r12 all
```

```text { .no-copy }
77 passed, 0 failed
```

`all` runs Lab 1 and Lab 2 against the same end state, because Lab 2 ends where Lab 1 does. If you restored the clean snapshot in between, run them individually.

## The diagnostic table

| Symptom | Ask first | Then |
|---|---|---|
| `403` from `httpd` | `ls -Z` on the file | `grep ': avc:' /var/log/audit/audit.log`; if there is an AVC, it is SELinux |
| `403` with no AVC | file mode, ownership, `Require all granted` | `ls -l`, the vhost file |
| `curl: (7)` from the peer | `firewall-cmd --zone=public --list-all` | which zone the packet enters; `--add-port` and `--reload` |
| `curl: (6)` from the peer | name resolution | `getent hosts`, `/etc/hosts` |
| Works now, gone after reboot | `findmnt --fstab` | the fstab source and `findmnt --verify` |
| Timer never runs | `systemctl list-timers --all` | enabled the timer, not the service; `Type=oneshot` |
| `203/EXEC` | `ls -Z` on the program | a program under `/srv` is `var_t`; install it in `/usr/local/bin` |
| Service active but unreachable | `ss -ltnH` | the listener's address and port, then the zone |

## What the checker reads

| Check | Evidence |
|---|---|
| The mapping is persistent, not a `chcon` | `semanage fcontext -l -C` |
| fstab matches the live filesystem | the UUID from `blkid` versus `findmnt --fstab` |
| The mount is live | `findmnt --target` |
| The permanent firewall rule is back | `firewall-cmd --permanent --query-port` |
| The page is reachable from a real client | a `curl` from `node2` as `labuser` |
| The timer still produces stamps | the stamp file's age, with a wait for the next tick |
| Nothing else regressed | the full Lab 1 check |

The freshness check waits up to ninety seconds. A reboot restores a snapshot clock that then steps forward, so the previous boot's stamp can look hours old; the timer fires every minute, so the checker waits for one tick instead of reporting a false failure. That behaviour is deliberate, and it is the same reason R8's checker polls `node2` for synchronisation.

## Traps

| Trap | Why it fails |
|---|---|
| Fixing the twelve lines one at a time | Three causes, twelve symptoms; group by layer first |
| Repairing fstab by retyping the UUID | Use `blkid`; a typed UUID is a guess |
| `restorecon` before `semanage fcontext -a` | The relabel has no rule to apply |
| `chcon` and calling it fixed | The label is not persistent |
| `--add-port` without `--reload` | The permanent file changed, the running firewall did not |
| Testing only with a local `curl` | Proves the service, not the network |
| Trusting `journalctl` for a refused connection | The request never reached the daemon |
| Passing `lab2` by rebuilding the host | The point is to diagnose, and the exam will not give you a rebuild |

## Next

The three mock exams are next. Restore the clean snapshot before each one, put the notes away, and start a clock.
