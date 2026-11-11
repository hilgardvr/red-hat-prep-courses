# R10 — Security: SELinux, SSH keys, and a hardened firewall

<div class="module-meta" markdown>

| | |
|---|---|
| **Exam objective group** | 10 — Manage security |
| **Time** | 5–6 hours including labs |
| **Prerequisites** | [R5 — Processes and services](../r05-processes-and-services/index.md) for systemd units and the journal, and [R9 — Networking and firewalld](../r09-networking-and-firewall/index.md) for zones and ports |
| **Labs** | 2 guided labs + 1 challenge |
| **Check command** | `./bin/lab check r10 lab1` (also `lab2` and `challenge`) |

</div>

A Linux system has two kinds of "no". The first is the one you already know: permissions. The file is `0644`, the user is not the owner, the group does not match, so the kernel refuses. That model is called **discretionary access control**, because the owner of a file decides who may use it.

The second kind of "no" comes from **SELinux**. It ignores who owns what and asks a different question: *is this program, running under this policy, allowed to touch this object, whatever its permissions say?* That is **mandatory access control**, and it is why a web server that can read a file as root can still be denied when SELinux is enforcing.

R10 is built from three defences that fail independently:

1. **SELinux** — labels on files, ports, and processes, and a policy that decides what may talk to what.
2. **SSH authentication** — proving who you are with a key instead of a password, and turning the password path off.
3. **The firewall** — letting the network reach exactly the service and the source it should, and nothing else.

Each one is useful alone. Together they mean an attacker who finds one hole still meets two more.

!!! note "Read it; do not memorise it"
    This page is a reference you will return to, not a list to learn by heart. The labs are where the commands become yours.

    Command blocks have a copy button. Blocks **without** one are output: they show what a command printed and are there to compare against, not to paste into a shell.

## Objective checklist

By the end of this module you should be able to:

- [ ] Read a file, process, and port SELinux context with `ls -Z`, `ps -eZ`, and `semanage port -l`
- [ ] Explain the difference between enforcing, permissive, and disabled
- [ ] Switch mode at runtime with `setenforce` and persistently in `/etc/selinux/config`
- [ ] Fix a wrong file label with `restorecon`, and keep it fixed with `semanage fcontext`
- [ ] Explain why `chcon` is temporary and `semanage fcontext` is not
- [ ] Add a port label so a confined service can bind a non-standard port
- [ ] Toggle a Boolean persistently with `setsebool -P` and prove its effect
- [ ] Read an AVC denial and name the type that was denied
- [ ] Generate an SSH key pair and install the public key with `ssh-copy-id`
- [ ] Prove that key authentication works without a password
- [ ] Disable password and root logins in `sshd` safely, and verify the effective configuration
- [ ] Restrict a port to one source network with a firewalld rich rule
- [ ] Prove the whole stack survives a reboot

---

## SELinux: the model

SELinux labels three things, and policy connects them:

| Object | Command to read the label | Example |
|---|---|---|
| File or directory | `ls -Z` | `system_u:object_r:httpd_sys_content_t:s0` |
| Process | `ps -eZ` | `system_u:system_r:httpd_t:s0` |
| Port | `semanage port -l` | `http_port_t  tcp  80, 443` |

A **context** has four fields:

```text { .no-copy }
system_u : object_r : httpd_sys_content_t : s0
   user      role          type             level
```

- **user** and **role** are almost always `system_u` and `object_r` for files.
- **type** is the field policy actually uses. `httpd_sys_content_t` is a *file* type; `httpd_t` is a *process* (domain) type.
- **level** is the MLS range. The `targeted` policy on RHEL leaves it at `s0` unless you configure MLS.

When you read a denial, the two types are the whole story:

```text { .no-copy }
avc: denied { getattr } for pid=13883 comm="httpd"
  path="/srv/r10/www/index.html"
  scontext=system_u:system_r:httpd_t:s0
  tcontext=unconfined_u:object_r:var_t:s0
  tclass=file permissive=0
```

- `scontext` is the **source**: the process, `httpd_t`.
- `tcontext` is the **target**: the file, labelled `var_t`.
- `tclass` is the kind of object: `file`, `dir`, `tcp_socket`, `process`.
- The permission in braces — `getattr`, `open`, `name_bind`, `name_connect` — is what was refused.

The fix is almost always to change the **target's label**, not to loosen the policy.

### Modes

| Mode | Enforces policy | Logs denials | How to set |
|---|---|---|---|
| Enforcing | Yes | Yes | `setenforce 1`, `SELINUX=enforcing` |
| Permissive | No | Yes | `setenforce 0`, `SELINUX=permissive` |
| Disabled | No | No | `SELINUX=disabled`, then reboot |

```bash
getenforce
sestatus
setenforce 0
getenforce
setenforce 1
```

```text { .no-copy }
Enforcing
Permissive
```

`setenforce` changes the running mode only. The persistent setting is in `/etc/selinux/config`:

```text { .no-copy }
SELINUX=enforcing
SELINUXTYPE=targeted
```

Changing that file needs a reboot. **Disabled is not a debugging mode.** A machine that boots with SELinux disabled does not label new files, and switching back to enforcing later requires a full filesystem relabel with `touch /.autorelabel` and a long reboot. Use **permissive** when you need to see what would have been denied, and never hand in an exam task with SELinux disabled.

!!! warning "Permissive still logs"
    In permissive mode the action succeeds, so a broken service starts working and looks "fixed". The AVC denial is still written to the audit log. That is useful: read the denial, fix the label, switch back to enforcing, and test again. A service that only works in permissive has not been fixed.

### The targeted policy and `unconfined_t`

RHEL's default policy is **targeted**: a set of network-facing services is confined, and the rest of the system runs without SELinux restrictions. Your shell is:

```bash
id -Z
```

```text { .no-copy }
unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
```

`unconfined_t` can do almost anything, which is why root can still read `/srv/r10/www/index.html` while `httpd_t` cannot. The confinement applies to the **service**, not to you.

### File labels come from policy

The policy ships a mapping from path patterns to types, in the `file_contexts` file:

```bash
ls -Zd /var/www/html /etc/httpd /usr/sbin/httpd
```

```text { .no-copy }
system_u:object_r:httpd_sys_content_t:s0 /var/www/html
system_u:object_r:httpd_config_t:s0      /etc/httpd
system_u:object_r:httpd_exec_t:s0        /usr/sbin/httpd
```

Those types are not accidents: `httpd_t` may read `httpd_sys_content_t`, read `httpd_config_t`, and execute `httpd_exec_t`. A file created under `/srv` gets `var_t`, which `httpd_t` may not read. That is the whole reason a document root outside `/var/www` fails.

| Tool | Effect | Survives relabel |
|---|---|---|
| `chcon -t TYPE path` | Changes the label on this file now | **No** |
| `restorecon -v path` | Resets files to the policy's label | Yes, that is the point |
| `semanage fcontext -a -t TYPE 'pattern'` | Adds a persistent path mapping | Yes |
| `restorecon -Rv path` | Applies the mapping to existing files | Yes |

The durable recipe is three steps:

```bash
semanage fcontext -a -t httpd_sys_content_t '/srv/r10/www(/.*)?'
restorecon -Rv /srv/r10/www
semanage fcontext -l -C
```

```text { .no-copy }
Relabeled /srv/r10/www from unconfined_u:object_r:var_t:s0 to unconfined_u:object_r:httpd_sys_content_t:s0
Relabeled /srv/r10/www/index.html from unconfined_u:object_r:var_t:s0 to unconfined_u:object_r:httpd_sys_content_t:s0
```

`semanage fcontext -l -C` lists only your **local** additions, which is how you check your own work without scrolling through hundreds of shipped patterns. The pattern is a regular expression; `/srv/r10/www(/.*)?` matches the directory and everything under it.

`chcon` looks simpler and is a trap: the next `restorecon` (or `autorelabel`) puts the policy label back, and your fix disappears. Use it to test a theory, then write the `fcontext` mapping.

### Port labels

A confined service may only bind ports its policy allows. `httpd_t` may bind the ports typed `http_port_t`:

```bash
semanage port -l | grep '^http_port_t'
```

```text { .no-copy }
http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000
```

A non-standard port produces a `name_bind` denial and the service fails to start:

```text { .no-copy }
avc: denied { name_bind } for pid=13858 comm="httpd" src=18443
  scontext=system_u:system_r:httpd_t:s0
  tcontext=system_u:object_r:unreserved_port_t:s0
  tclass=tcp_socket permissive=0
```

Add the label:

```bash
semanage port -a -t http_port_t -p tcp 18443
semanage port -l -C
```

```text { .no-copy }
SELinux Port Type              Proto    Port Number

http_port_t                    tcp      18443
```

| Task | Command |
|---|---|
| List all port labels | `semanage port -l` |
| List your local changes | `semanage port -l -C` |
| Add a port to a type | `semanage port -a -t http_port_t -p tcp 18443` |
| Change an existing label | `semanage port -m -t http_port_t -p tcp 18443` |
| Remove a local label | `semanage port -d -t http_port_t -p tcp 18443` |

If the port is already labelled for another type, `-a` fails with "Port ... already defined". That is not a reason to pick a random higher port: decide which type should own it and use `-m`.

### Booleans

A Boolean is a switch baked into the policy for behaviour that is legitimate sometimes and dangerous always. `httpd_can_network_connect` is the classic:

```bash
getsebool httpd_can_network_connect
semanage boolean -l | grep '^httpd_can_network_connect '
setsebool -P httpd_can_network_connect on
getsebool httpd_can_network_connect
```

```text { .no-copy }
httpd_can_network_connect --> off
httpd_can_network_connect      (on   ,   on)  Allow httpd to can network connect
httpd_can_network_connect --> on
```

The pair in parentheses is `(current, persistent)`. `setsebool` alone changes the running value; `-P` writes it to policy so it survives a reboot. Without the Boolean, an Apache reverse proxy to a local backend fails with `503 Service Unavailable` and a denial:

```text { .no-copy }
avc: denied { name_connect } for pid=14095 comm="httpd" dest=18081
  scontext=system_u:system_r:httpd_t:s0
  tcontext=system_u:object_r:unreserved_port_t:s0
  tclass=tcp_socket permissive=0
```

`name_connect` is the outbound counterpart of `name_bind`: one is "may I listen here", the other is "may I connect there". The destination port's type is `unreserved_port_t`, and the Boolean is what allows it.

### Reading denials

The audit daemon writes denials to `/var/log/audit/audit.log`. Two ways to read them:

```bash
ausearch -m AVC -ts recent
grep ': avc:' /var/log/audit/audit.log | tail -3
```

`ausearch` is the proper tool: it understands the record format and can filter by time, process, or path. The `grep` is the fallback when `ausearch` cannot find the log it expects, and it always shows the raw line you need:

```text { .no-copy }
type=AVC msg=audit(1794289654.620:1251): avc:  denied  { name_connect } for  pid=14477 comm="httpd" dest=18081 scontext=system_u:system_r:httpd_t:s0 tcontext=system_u:object_r:unreserved_port_t:s0 tclass=tcp_socket permissive=0
```

| Symptom | Likely cause | Fix |
|---|---|---|
| `403` from httpd, file exists and is `0644` | File label is `var_t` | `semanage fcontext` + `restorecon` |
| Service fails: `Permission denied` on bind | Port lacks the service's port type | `semanage port -a` |
| `503` from a proxy | Boolean off | `setsebool -P ... on` |
| Denial gone after `chcon` but returns | `chcon` is not persistent | Use `semanage fcontext` |
| Nothing in `ausearch` | Wrong time filter, or `auditd` not running | `grep ': avc:' /var/log/audit/audit.log` |
| A denial with `tcontext=...:var_t` on a config file | File created in the wrong place | Move it, or label it |

---

## SSH: keys instead of passwords

A password proves knowledge. A key proves possession of a private key that matches a public key the server already trusts. The private key never leaves the client; the server only needs the public half.

### Making a key pair

```bash
ssh-keygen -t ed25519 -N '' -f ~/.ssh/r10_ed25519 -C 'r10 deploy'
ls -l ~/.ssh/r10_ed25519 ~/.ssh/r10_ed25519.pub
```

```text { .no-copy }
-rw-------. 1 labuser labuser 399 Nov 11 04:31 /home/labuser/.ssh/r10_ed25519
-rw-r--r--. 1 labuser labuser  92 Nov 11 04:31 /home/labuser/.ssh/r10_ed25519.pub
```

- `-t ed25519` is the current default choice: short keys, strong, fast.
- `-N ''` sets an empty passphrase. Fine for a lab or an automation key; for a human key, use a passphrase and an agent.
- `-f` names the file. Without it you get `id_ed25519`.
- `-C` is a comment, usually an identity or purpose. It ends up in the public key and in logs.

The private key is mode `0600`. If it is group- or world-readable, `ssh` refuses to use it:

```text { .no-copy }
Permissions 0644 for '/home/labuser/.ssh/r10_ed25519' are too open.
```

### Installing the public key

```bash
ssh-copy-id -i ~/.ssh/r10_ed25519.pub r10deploy@server
```

It logs in with the password once, then appends the public key to `~/.ssh/authorized_keys` on the remote account and fixes the permissions:

```text { .no-copy }
Number of key(s) added: 1
```

On the server side, the result is:

```text { .no-copy }
drwx------. 2 r10deploy r10deploy 29 Nov 11 04:31 .
-rw-------. 1 r10deploy r10deploy 92 Nov 11 04:31 authorized_keys
```

Three permission rules matter, and `ssh-copy-id` gets them right: the home directory must not be writable by others, `~/.ssh` is `0700`, and `authorized_keys` is `0600`. A correct key in a world-writable directory is ignored, and the log says `Authentication refused: bad ownership or modes`.

Then log in with no password:

```bash
ssh -i ~/.ssh/r10_ed25519 -o IdentitiesOnly=yes r10deploy@server whoami
```

```text { .no-copy }
r10deploy
```

`IdentitiesOnly=yes` makes `ssh` offer only the key named with `-i`, which turns "it worked" into "this key worked". Without it, an agent or another key in `~/.ssh` could be the one that succeeded.

### How the server decides

The client and server negotiate authentication methods. If the server allows `publickey` and `password`, the client tries keys first and falls back to a prompt. If the server only allows `publickey`, there is no prompt at all — the connection fails immediately:

```text { .no-copy }
labuser@server: Permission denied (publickey,gssapi-keyex,gssapi-with-mic).
```

That method list in the parentheses is the server's answer. Compare it with a server that still accepts passwords:

```text { .no-copy }
labuser@server: Permission denied (publickey,gssapi-keyex,gssapi-with-mic,password).
```

The presence or absence of `,password` is a reliable, scriptable test — and it is what the checker uses.

### The sshd configuration

`sshd` reads `/etc/ssh/sshd_config`, which includes drop-ins:

```text { .no-copy }
Include /etc/ssh/sshd_config.d/*.conf
```

Drop-ins are read in **alphabetical order**, and for most keywords **the first value wins**. This trips people up on RHEL cloud images, which ship:

```text { .no-copy }
/etc/ssh/sshd_config.d/50-cloud-init.conf
```

containing `PasswordAuthentication yes`. A drop-in named `60-r10.conf` is read *after* that file, so its `PasswordAuthentication no` is ignored. A drop-in named `10-r10.conf` is read *first*, so it wins:

```text { .no-copy }
/etc/ssh/sshd_config.d/10-r10.conf
```

```text { .no-copy }
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
```

The same first-wins rule is why the shipped `50-cloud-init.conf` exists in the first place: cloud images want password login for their initial provisioning. Read the directory before you add to it.

### Applying and verifying

```bash
sshd -t
systemctl reload sshd
sshd -T | grep -E '^(passwordauthentication|permitrootlogin|pubkeyauthentication)'
```

```text { .no-copy }
permitrootlogin no
pubkeyauthentication yes
passwordauthentication no
```

- `sshd -t` **tests** the configuration and exits non-zero on a syntax error. Run it before every reload; a broken config plus a restart is how people lose access.
- `reload` re-reads the configuration without killing established sessions.
- `sshd -T` prints the **effective** configuration after includes, `Match` blocks, and defaults. It is the only honest way to check a drop-in actually applied.

| Setting | Effect |
|---|---|
| `PubkeyAuthentication yes` | Accept keys |
| `PasswordAuthentication no` | Refuse password authentication |
| `PermitRootLogin no` | Refuse root over SSH entirely |
| `PermitRootLogin prohibit-password` | Root only with a key (the shipped default) |
| `AllowUsers alice bob` | Only those accounts may log in |

!!! warning "Do not lock yourself out"
    Change authentication only while you have a second way in: an open session, the Vagrant console, or the provider's web console. Keep that session open until a **new** connection with the key succeeds. The lab kit's `./bin/lab ssh` uses its own key and is unaffected by `PasswordAuthentication`, which makes it a good fallback.

`/etc/ssh/sshd_config.d/*.conf` files must not be writable by group or others, or `sshd` refuses to start. `0644` is fine; `0664` is not.

---

## firewalld: narrowing the opening

R9 opened a port to everyone in a zone. Hardening usually means **to whom**, not **whether**:

```bash
firewall-cmd --permanent --zone=public \
  --add-rich-rule='rule family="ipv4" source address="10.10.10.0/24" port port="18443" protocol="tcp" accept'
firewall-cmd --reload
firewall-cmd --zone=public --list-rich-rules
```

```text { .no-copy }
rule family="ipv4" source address="10.10.10.0/24" port port="18443" protocol="tcp" accept
```

A **rich rule** combines a source, a destination, a service or port, logging, and an action in one line. The same result can be built from a dedicated zone bound to a source:

```bash
firewall-cmd --permanent --new-zone=r10api
firewall-cmd --permanent --zone=r10api --add-source=10.10.10.0/24
firewall-cmd --permanent --zone=r10api --add-port=18443/tcp
firewall-cmd --reload
```

| Approach | Use when |
|---|---|
| `--add-port` / `--add-service` | Everyone in that zone may connect |
| Rich rule | One port, one source, no new zone |
| Source zone | Several ports for the same set of sources |

The two are not the same check afterwards:

```bash
firewall-cmd --zone=public --query-port=18443/tcp
firewall-cmd --zone=public --query-rich-rule='rule family="ipv4" source address="10.10.10.0/24" port port="18443" protocol="tcp" accept'
```

```text { .no-copy }
no
yes
```

`query-port` says "not open to everyone", which is exactly what you want when access is source-restricted. Do not add both a plain port and a rich rule: the plain port would defeat the restriction.

A rich rule is still evaluated in the zone the packet arrives in. `node2` reaches `server` on `eth1`, which is in `public`, so that is where the rule belongs.

### Defence in depth, concretely

Getting one page through all three layers requires all three to agree:

| Layer | Question | Failure looks like |
|---|---|---|
| Service | Is it running and listening? | `Connection refused` |
| firewalld | May this source reach this port? | Connection times out or is refused |
| SELinux | May this process read this file, or bind this port? | `403` with an AVC, or the service fails to start |

The lab walks all three in that order, and the challenge checks them together. A common mistake is to fix the layer that produced the most recent error and stop: the firewall was fine, SELinux was the problem, and the next request fails on the firewall.

---

## Common traps

| Trap | What happens | Fix |
|---|---|---|
| `chcon` for a permanent fix | Relabel later reverts it | `semanage fcontext` + `restorecon` |
| `restorecon` without an `fcontext` rule | Nothing changes: policy has no mapping for that path | Add the mapping first |
| Adding a port with `-a` when it is already labelled | `Port ... already defined` | `semanage port -m`, or choose another port |
| `setenforce 0` to "fix" a service | Works, logs a denial, hides the bug | Read the AVC, fix the label, re-enable |
| `SELINUX=disabled` | Needs a reboot and a relabel to undo | Use permissive |
| Editing `sshd_config.d/50-cloud-init.conf` | Works, but the next cloud-init run may rewrite it | Add a lower-numbered drop-in |
| A drop-in numbered after `50-cloud-init.conf` | Its `PasswordAuthentication no` is ignored | `10-r10.conf` |
| Restarting `sshd` with a broken config | You are locked out | `sshd -t` first, then `reload` |
| `authorized_keys` in a world-writable directory | Key ignored, `bad ownership or modes` | `chown`, `chmod 700 ~/.ssh`, `600 authorized_keys` |
| `chmod 644` on a private key | `ssh` refuses to use it | `chmod 600` |
| Adding a port *and* a rich rule | The port is open to everyone | Remove the plain port |
| Testing a rich rule with `--query-port` | Says `no`, looks broken | `--list-rich-rules`, then a real client |
| Firewall rule in the wrong zone | A client on another interface cannot use it | Match the zone of the incoming interface |
| Forgetting `--permanent` or `--reload` | Works now or later, but not both | `--permanent` then `--reload` |

---

## Next

[Lab 1 — SELinux: labels, ports, and booleans](labs/lab-1-selinux.md) serves a page from `/srv` through a confined web server on a non-standard port, and fixes every denial the right way. [Lab 2 — Keys, not passwords](labs/lab-2-ssh-keys.md) replaces password authentication with a key and proves the daemon refuses the old path. The [challenge](labs/challenge-hardened-host.md) combines both with a source-restricted firewall rule and a reboot.
