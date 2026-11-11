# Lab 1 — SELinux: a mode, a label, and a boolean

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R10 — Security: SELinux, SSH keys, and a hardened firewall |
| **Time** | 75–90 minutes |
| **Check** | `./bin/lab check r10 lab1` |
| **Skills** | Enforcing and permissive, reading a context, `restorecon`, `semanage fcontext`, port labels, Booleans, AVC denials |

</div>

## What you are building

| Item | End state |
|---|---|
| Web server | `httpd` installed, running, and enabled at boot |
| Non-standard port | `18443` open and labelled `http_port_t` |
| Document root | `/srv/r10/www` served, labelled `httpd_sys_content_t` |
| Label persistence | A `semanage fcontext` mapping, not just a one-off `chcon` |
| Outbound access | A local proxy backend on `18081` reachable only after `httpd_can_network_connect` is on |
| Persistence | Every one of those survives a reboot |

The lesson in one sentence: **SELinux says no to the label, not to the permission**, and every denial in this lab comes with the exact type that has to change.

!!! note "This lab installs two packages"
    `httpd` and `policycoreutils-python-utils` are not in the base image and are deliberately not in the lab kit's `PACKAGES` list, because only this module needs them. The install needs a working repository — if you left R3's distro repositories disabled, re-enable them first.

## Before you begin

Start from the clean snapshot and log in as root on `server`:

```bash
cd labs
./bin/lab restore clean
./bin/lab up
./bin/lab ssh
sudo -i
```

Only `server` is needed for this lab; `node2` is not used until the challenge.

Every command below runs **inside the `server` VM**. The commands are reference material: run them in order the first time, then come back for the syntax.

## Step 1 — The mode

```bash
getenforce
sestatus
grep -E '^SELINUX=' /etc/selinux/config
```

```text { .no-copy }
Enforcing
SELinux status:                 enabled
SELinuxfs mount:                /sys/fs/selinux
SELinux root directory:         /etc/selinux
Loaded policy name:             targeted
Current mode:                   enforcing
Mode from config file:          enforcing
Policy MLS status:              enabled
Policy deny_unknown status:     allowed
Memory protection checking:     actual (secure)
Max kernel policy version:      33
SELINUX=enforcing
```

Two different questions are being answered. `getenforce` and `sestatus` report the **running** mode; `/etc/selinux/config` is what the next boot will use. They agree now.

Now watch what permissive actually does:

```bash
setenforce 0
getenforce
setenforce 1
getenforce
```

```text { .no-copy }
Permissive
Enforcing
```

`setenforce` changes the running mode and nothing else — no reboot, and no effect on `/etc/selinux/config`. Permissive does **not** turn SELinux off: policy is still evaluated and denials are still written to the audit log, the action is simply allowed. That is why permissive is a diagnostic mode and not a fix.

!!! warning "Do not disable SELinux to make something work"
    Setting `SELINUX=disabled` needs a reboot, stops new files from being labelled, and coming back needs a full relabel (`touch /.autorelabel`) and a long reboot. Nothing in this module requires it, and an exam task that ends with SELinux disabled is not finished.

## Step 2 — Install the web server and read its labels

```bash
dnf install -y httpd policycoreutils-python-utils
systemctl enable --now httpd
systemctl is-active httpd
systemctl is-enabled httpd
ss -ltn
```

```text { .no-copy }
Complete!

active
enabled
State  Recv-Q Send-Q Local Address:Port Peer Address:Port
LISTEN 0      128          0.0.0.0:22        0.0.0.0:*
LISTEN 0      128             [::]:22           [::]:*
LISTEN 0      511                *:80              *:*
```

`policycoreutils-python-utils` is the package that provides `semanage`. Without it, the persistence steps below fail with `semanage: command not found`, which looks like a SELinux problem and is a missing package.

Check that the process is confined, and what your own shell looks like:

```bash
ps -eZ | grep httpd | head -3
id -Z
```

```text { .no-copy }
system_u:system_r:httpd_t:s0      13659 ?        00:00:00 httpd
system_u:system_r:httpd_t:s0      13660 ?        00:00:00 httpd
system_u:system_r:httpd_t:s0      13662 ?        00:00:00 httpd
unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
```

`httpd` runs as `httpd_t`, one of the confined domains in the `targeted` policy. Your root shell is `unconfined_t`, which is why root can read files that `httpd_t` cannot. **The confinement is on the service, not on you** — and that is why the same `cat` succeeds while the web request fails.

Now the files:

```bash
ls -Zd /var/www/html /etc/httpd /usr/sbin/httpd
```

```text { .no-copy }
system_u:object_r:httpd_sys_content_t:s0 /var/www/html
system_u:object_r:httpd_config_t:s0      /etc/httpd
system_u:object_r:httpd_exec_t:s0        /usr/sbin/httpd
```

Three paths, three types, and each one exists for a reason: `httpd_t` may **read** `httpd_sys_content_t`, **read** `httpd_config_t`, and **execute** `httpd_exec_t`. Nothing in the policy says `httpd_t` may read `var_t`, which is what a file created under `/srv` gets.

The stock page:

```bash
curl -s -o /dev/null -w 'http_code=%{http_code}\n' http://127.0.0.1/
```

```text { .no-copy }
http_code=403
```

That `403` is not SELinux. This image ships no `index.html` in `/var/www/html`, and the packaged configuration refuses to generate a directory listing:

```text { .no-copy }
AH01276: Cannot serve directory /var/www/html/: No matching DirectoryIndex (index.html) found,
and server-generated directory index forbidden by Options directive
```

The server is running and reachable. It simply has nothing to serve.

## Step 3 — A document root under `/srv`, and the port denial

```bash
mkdir -p /srv/r10/www
printf 'r10 custom root\n' > /srv/r10/www/index.html
ls -Zd /srv /srv/r10 /srv/r10/www
ls -Z /srv/r10/www/index.html
```

```text { .no-copy }
    system_u:object_r:var_t:s0 /srv
unconfined_u:object_r:var_t:s0 /srv/r10
unconfined_u:object_r:var_t:s0 /srv/r10/www
unconfined_u:object_r:var_t:s0 /srv/r10/www/index.html
```

Everything under `/srv` is `var_t`. Nothing about the permissions is unusual:

```bash
ls -l /srv/r10/www/index.html
```

```text { .no-copy }
-rw-r--r--. 1 root root 16 Nov 10 05:46 /srv/r10/www/index.html
```

`0644`, root-owned, readable by everyone — and unreadable to `httpd`, because the type is wrong. This is the moment to understand the two models: **permissions decided nothing here, the label did.**

Point Apache at the directory and at a new port:

```bash
cat >/etc/httpd/conf.d/r10-site.conf <<'EOF'
Listen 18443
DocumentRoot "/srv/r10/www"
<Directory "/srv/r10/www">
  Require all granted
</Directory>
EOF
systemctl restart httpd
```

```text { .no-copy }
Job for httpd.service failed because the control process exited with error code.
See "systemctl status httpd.service" and "journalctl -xeu httpd.service" for details.
```

Ask the journal, then ask the audit log:

```bash
journalctl -u httpd --no-pager -n 6
grep ': avc:' /var/log/audit/audit.log | tail -2
```

```text { .no-copy }
httpd[13858]: (13)Permission denied: AH00072: make_sock: could not bind to address [::]:18443
httpd[13858]: (13)Permission denied: AH00072: make_sock: could not bind to address 0.0.0.0:18443
httpd[13858]: no listening sockets available, shutting down
httpd[13858]: AH00015: Unable to open logs
systemd[1]: httpd.service: Main process exited, code=exited, status=1/FAILURE

type=AVC msg=audit(1794289608.939:1025): avc:  denied  { name_bind } for  pid=13858 comm="httpd" src=18443 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
```

Read the denial field by field:

| Field | Value here | Means |
|---|---|---|
| permission | `name_bind` | "may I listen on this port" |
| `scontext` | `httpd_t` | the process asking |
| `tcontext` | `unreserved_port_t` | the label of port 18443 |
| `tclass` | `tcp_socket` | the kind of object |

`Permission denied` from `make_sock` reads like a permissions problem or a port conflict. It is neither: the process is `httpd_t`, the port is labelled `unreserved_port_t`, and the policy has no rule connecting them.

`ss` confirms nothing is listening:

```bash
ss -ltn | grep 18443 || echo 'nothing on 18443'
```

```text { .no-copy }
nothing on 18443
```

!!! note "Similar message, different cause"
    A port already in use by another process produces `Address already in use`, not `Permission denied`. When you see `Permission denied` on a bind, look for an AVC before you look for another daemon.

## Step 4 — Label the port

```bash
semanage port -l -C
semanage port -a -t http_port_t -p tcp 18443
semanage port -l -C
systemctl restart httpd
ss -ltn | grep 18443
```

```text { .no-copy }
SELinux Port Type              Proto    Port Number

http_port_t                    tcp      18443
LISTEN 0      511                *:18443            *:*
```

`semanage port -l -C` prints only your **local** additions. It is empty before and holds exactly one line after, which makes it a clean way to check your own work without reading the several hundred shipped labels.

The service starts. Now the request:

```bash
curl -s -o /dev/null -w 'http_code=%{http_code}\n' http://127.0.0.1:18443/
curl -s http://127.0.0.1:18443/ | head -1
```

```text { .no-copy }
http_code=403
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
```

A different `403`, for a different reason, and there is a second denial:

```bash
grep ': avc:' /var/log/audit/audit.log | tail -1
```

```text { .no-copy }
type=AVC msg=audit(1794289610.862:1035): avc:  denied  { getattr } for  pid=13883 comm="httpd" path="/srv/r10/www/index.html" dev="vda4" ino=67110571 scontext=system_u:system_r:httpd_t:s0 tcontext=unconfined_u:object_r:var_t:s0 tclass=file permissive=0
```

`getattr` on `var_t`. Port fixed, file still wrong. Two layers, two fixes — and the second one is the file label.

## Step 5 — Label the files, persistently

There are two ways to change a file label, and only one of them lasts:

```bash
chcon -t httpd_sys_content_t /srv/r10/www/index.html
ls -Z /srv/r10/www/index.html
restorecon -Rv /srv/r10/www
```

```text { .no-copy }
unconfined_u:object_r:httpd_sys_content_t:s0 /srv/r10/www/index.html
Relabeled /srv/r10/www from unconfined_u:object_r:var_t:s0 to unconfined_u:object_r:httpd_sys_content_t:s0
Relabeled /srv/r10/www/index.html from unconfined_u:object_r:var_t:s0 to unconfined_u:object_r:httpd_sys_content_t:s0
```

`chcon` looked like a fix. Then `restorecon` put it back, because `restorecon` applies the **policy's** mapping and the policy has no mapping for `/srv/r10/www`. The durable fix adds one:

```bash
semanage fcontext -a -t httpd_sys_content_t '/srv/r10/www(/.*)?'
restorecon -Rv /srv/r10/www
ls -Z /srv/r10/www/index.html
semanage fcontext -l -C
```

```text { .no-copy }
Relabeled /srv/r10/www from unconfined_u:object_r:var_t:s0 to unconfined_u:object_r:httpd_sys_content_t:s0
Relabeled /srv/r10/www/index.html from unconfined_u:object_r:var_t:s0 to unconfined_u:object_r:httpd_sys_content_t:s0
unconfined_u:object_r:httpd_sys_content_t:s0 /srv/r10/www/index.html
SELinux fcontext                                   type               Context

/srv/r10/www(/.*)?                                 all files          system_u:object_r:httpd_sys_content_t:s0
```

Note the quoting on the pattern. `(/.*)?` is a regular expression that matches the directory itself and everything beneath it. Unquoted, the shell would treat the parentheses specially.

The page is served:

```bash
curl -s http://127.0.0.1:18443/
```

```text { .no-copy }
r10 custom root
```

**The three-step recipe to memorise:** `semanage fcontext -a -t TYPE 'pattern'`, then `restorecon -Rv path`, then `semanage fcontext -l -C` to prove it. On a new file created later under that path, `restorecon` alone is enough, because the mapping is already there.

## Step 6 — A Boolean for the outbound connection

`name_bind` was "may I listen here". The outbound counterpart is `name_connect`, "may I connect there". A reverse proxy to a local backend needs it, and the policy ships it off:

```bash
getsebool httpd_can_network_connect
```

```text { .no-copy }
httpd_can_network_connect --> off
```

Build the backend and proxy to it:

```bash
mkdir -p /srv/r10/api
printf 'r10 api backend\n' > /srv/r10/api/index.html
setsid python3 -m http.server 18081 --bind 127.0.0.1 \
  --directory /srv/r10/api >/srv/r10/api.log 2>&1 < /dev/null &
sleep 1
curl -s -o /dev/null -w 'backend=%{http_code}\n' http://127.0.0.1:18081/
cat >/etc/httpd/conf.d/r10-proxy.conf <<'EOF'
ProxyPass /api/ http://127.0.0.1:18081/
ProxyPassReverse /api/ http://127.0.0.1:18081/
EOF
systemctl restart httpd
curl -s -o /dev/null -w 'proxy=%{http_code}\n' http://127.0.0.1:18443/api/
```

```text { .no-copy }
backend=200
proxy=503
```

The backend answers, the proxy does not, and Apache logs a `503 Service Unavailable` rather than an error page with a path in it. The audit log has the reason:

```bash
grep ': avc:' /var/log/audit/audit.log | tail -1
```

```text { .no-copy }
type=AVC msg=audit(1794289613.813:1043): avc:  denied  { name_connect } for  pid=14095 comm="httpd" dest=18081 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
```

Turn the Boolean on, persistently:

```bash
setsebool -P httpd_can_network_connect on
getsebool httpd_can_network_connect
semanage boolean -l | grep '^httpd_can_network_connect '
curl -s http://127.0.0.1:18443/api/
```

```text { .no-copy }
httpd_can_network_connect --> on
httpd_can_network_connect      (on   ,   on)  Allow httpd to can network connect
r10 api backend
```

The pair in `semanage boolean -l` is `(current, persistent)`. Without `-P`, the first becomes `on` and the second stays `off`, and the proxy breaks again at the next reboot — the failure appears hours later, in a different session, with no obvious cause.

`python3 -m http.server` on `127.0.0.1:18081` is a stand-in for a real application server. It is started by hand, so it is gone after a reboot; that is the next step's point.

## Step 7 — Persistence: reboot

```bash
systemctl reboot
```

Reconnect and check every layer:

```bash
cd labs
./bin/lab ssh
sudo -i

getenforce
systemctl is-active httpd
systemctl is-enabled httpd
ss -ltn | grep 18443
curl -s http://127.0.0.1:18443/
ls -Z /srv/r10/www/index.html
semanage port -l -C
getsebool httpd_can_network_connect
curl -s -o /dev/null -w 'api=%{http_code}\n' http://127.0.0.1:18443/api/
```

```text { .no-copy }
Enforcing
active
enabled
LISTEN 0      511                *:18443            *:*
r10 custom root
unconfined_u:object_r:httpd_sys_content_t:s0 /srv/r10/www/index.html
SELinux Port Type              Proto    Port Number

http_port_t                    tcp      18443
httpd_can_network_connect --> on
api=503
```

Five things survived, and one thing did not:

| Item | Survives because |
|---|---|
| Port label | `semanage port -a` wrote it to the local policy store |
| File label | `semanage fcontext` wrote the mapping, and `restorecon` applied it |
| Boolean | `setsebool -P` wrote it to the policy store |
| Service | `systemctl enable` |
| `Enforcing` | `/etc/selinux/config` |
| The backend | **Nothing** — a hand-started `python3` is not a service, so `503` is correct |

That last line is worth reading twice. `503` now means "the proxy is allowed to connect, and there is nothing there". Before Step 6 the same code meant "the proxy was refused". Same number, different layer — which is why you check the audit log rather than the status code.

## Verify with the checker

```bash
cd labs
./bin/lab check r10 lab1
```

```text { .no-copy }
R10 Lab 1 — SELinux: a mode, a label, and a boolean
  PASS  SELinux is enforcing
  PASS  SELinux is configured to enforce at boot
  PASS  httpd is running
  PASS  httpd starts at boot
  PASS  port 18443 carries an http_port_t label
  PASS  the custom document root is served
  PASS  the page is labelled as web content
  PASS  the document root has a persistent label mapping
  PASS  the network-connect boolean is on
  PASS  the network-connect boolean is persistent
  PASS  httpd proxies to a local backend
```

The last check is behavioural on purpose. The checker stops anything on `18081`, starts its own fixture there, and fetches `/api/` through Apache. A Boolean that is `on` in configuration but does not actually let `httpd_t` connect fails that line, and so does a `ProxyPass` that was never added.

## If something went wrong

| Symptom | Likely cause | Fix |
|---|---|---|
| `semanage: command not found` | `policycoreutils-python-utils` not installed | `dnf install -y policycoreutils-python-utils` |
| `403` on port 18443 after the port label | File still `var_t` | `semanage fcontext` + `restorecon` |
| `restorecon` changes nothing | No `fcontext` mapping for that path | Add the mapping first |
| Port label vanished after reboot | Added with `chcon`-style manual edit, not `semanage port` | `semanage port -a` |
| Boolean is `on` but the proxy still `503` | Backend not running, or `setsebool` without `-P` before a reboot | Start the backend, use `-P` |
| `AH00072: make_sock: could not bind` with `Address already in use` | Another process owns the port | `ss -ltnp \| grep 18443` |
| `AH00526: Syntax error` on restart | Bad `conf.d` fragment | `apachectl configtest`, then fix the file |
| `Port 18443 already defined` from `semanage -a` | The port is already labelled for another type | `semanage port -l \| grep 18443`, then `-m` |

To undo the lab:

```bash
systemctl disable --now httpd
rm -f /etc/httpd/conf.d/r10-site.conf /etc/httpd/conf.d/r10-proxy.conf
semanage port -d -t http_port_t -p tcp 18443
semanage fcontext -d '/srv/r10/www(/.*)?'
setsebool -P httpd_can_network_connect off
pkill -f 'http.server 18081'
rm -rf /srv/r10
```

or `./bin/lab restore clean` for a full reset. Restoring the snapshot is faster and removes the packages too.

## Next

[Lab 2 — Keys, not passwords](lab-2-ssh-keys.md) replaces password authentication with a key on the same machine, and proves the daemon refuses the old path.
