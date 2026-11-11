# R10 cheat sheet

A compact reference for review. Everything here is explained in the [theory page](index.md).

## The two models

| | Discretionary (DAC) | Mandatory (MAC) |
|---|---|---|
| Decided by | The file owner | The loaded policy |
| Enforced by | Permission bits, ACLs | SELinux types |
| Bypass | `root` can | Nobody, including `root` |
| Failure looks like | `Permission denied` (EACCES) | `403`, bind failure, `503`, AVC in audit log |

## Contexts

```text { .no-copy }
system_u : object_r : httpd_sys_content_t : s0
   user      role          type             level
```

```bash
ls -Z file                      # file context
ls -Zd dir                      # directory context
ps -eZ | grep httpd             # process context
id -Z                           # your own context
semanage port -l | grep http_port_t
```

| Object | Typical type |
|---|---|
| Web content | `httpd_sys_content_t` |
| Web config | `httpd_config_t` |
| Web binary | `httpd_exec_t` |
| Web process | `httpd_t` |
| Anything under `/srv` | `var_t` |
| Unlabelled port | `unreserved_port_t` |

## Modes

```bash
getenforce
sestatus
setenforce 0        # permissive, now
setenforce 1        # enforcing, now
```

| Mode | Enforces | Logs | Set by |
|---|---|---|---|
| Enforcing | Yes | Yes | `setenforce 1`, `SELINUX=enforcing` |
| Permissive | No | Yes | `setenforce 0`, `SELINUX=permissive` |
| Disabled | No | No | `SELINUX=disabled` + reboot + relabel |

`/etc/selinux/config` holds the boot setting. `setenforce` never writes it.

## File labels

| Tool | Effect | Survives relabel |
|---|---|---|
| `chcon -t TYPE path` | Change this inode now | **No** |
| `restorecon -Rv path` | Reset to the policy's label | Yes |
| `semanage fcontext -a -t TYPE 'pattern'` | Add a persistent mapping | Yes |

The durable recipe:

```bash
semanage fcontext -a -t httpd_sys_content_t '/srv/r10/www(/.*)?'
restorecon -Rv /srv/r10/www
semanage fcontext -l -C
matchpathcon -n /srv/r10/www/index.html
```

```bash
semanage fcontext -d '/srv/r10/www(/.*)?'      # remove the mapping
```

Patterns are regular expressions. Quote them. `(/.*)?` means "this directory and everything below it".

## Port labels

```bash
semanage port -l | grep '^http_port_t'
semanage port -l -C                      # only your local changes
semanage port -a -t http_port_t -p tcp 18443
semanage port -m -t http_port_t -p tcp 18443   # modify an existing label
semanage port -d -t http_port_t -p tcp 18443   # delete
```

| Denial | Meaning |
|---|---|
| `name_bind` | "may I listen on this port" |
| `name_connect` | "may I connect to this port" |

## Booleans

```bash
getsebool httpd_can_network_connect
semanage boolean -l | grep '^httpd_can_network_connect '
setsebool -P httpd_can_network_connect on
```

```text { .no-copy }
httpd_can_network_connect      (on   ,   on)  Allow httpd to can network connect
                                  ^current ^persistent
```

`setsebool` alone forgets at reboot. `-P` writes it.

| Boolean | Allows |
|---|---|
| `httpd_can_network_connect` | httpd to make outbound TCP connections (proxies, databases) |
| `httpd_can_network_connect_db` | httpd to reach database ports |
| `httpd_read_user_content` | httpd to read files in user home directories |
| `httpd_enable_homedirs` | per-user web directories |

## Reading denials

```bash
ausearch -m AVC -ts recent
ausearch -if /var/log/audit/audit.log -m AVC
grep ': avc:' /var/log/audit/audit.log | tail -3
```

```text { .no-copy }
avc: denied { name_connect } for pid=14095 comm="httpd" dest=18081
  scontext=system_u:system_r:httpd_t:s0
  tcontext=system_u:object_r:unreserved_port_t:s0
  tclass=tcp_socket permissive=0
```

`scontext` is the process, `tcontext` the object, `tclass` its kind, and the permission in braces is what was refused. `permissive=0` means it was actually blocked.

## SSH keys

```bash
ssh-keygen -t ed25519 -N '' -f ~/.ssh/key -C 'comment'
ssh-copy-id -i ~/.ssh/key.pub user@host
ssh -i ~/.ssh/key -o IdentitiesOnly=yes user@host
ssh-add ~/.ssh/key
```

| Path | Mode |
|---|---|
| private key | `0600` |
| public key | `0644` |
| `~/.ssh` | `0700` |
| `authorized_keys` | `0600` |
| home directory | not group- or world-writable |

`IdentitiesOnly=yes` proves *which* key worked. `BatchMode=yes` forbids a password fallback.

## sshd

```bash
sshd -t                       # parse the config, exit non-zero on error
sshd -T                       # effective configuration
sshd -T | grep -E '^(passwordauthentication|permitrootlogin|pubkeyauthentication)'
systemctl reload sshd
```

| Setting | Effect |
|---|---|
| `PubkeyAuthentication yes` | Accept keys |
| `PasswordAuthentication no` | Refuse passwords |
| `PermitRootLogin no` | No root over SSH at all |
| `PermitRootLogin prohibit-password` | Root with a key only |
| `AllowUsers a b` | Only these accounts may log in |
| `MaxAuthTries 3` | Fewer attempts per connection |

Drop-ins live in `/etc/ssh/sshd_config.d/*.conf`, are read **alphabetically**, and **the first value wins**:

```text { .no-copy }
50-cloud-init.conf    PasswordAuthentication yes
60-r10.conf           PasswordAuthentication no     <- ignored
10-r10.conf           PasswordAuthentication no     <- wins
```

```text { .no-copy }
labuser@server: Permission denied (publickey,gssapi-keyex,gssapi-with-mic).
```

No `,password` in that list means the server does not offer password authentication.

## firewalld: narrowing, not opening

```bash
firewall-cmd --permanent --zone=public \
  --add-rich-rule='rule family="ipv4" source address="10.10.10.0/24" port port="18443" protocol="tcp" accept'
firewall-cmd --reload
firewall-cmd --zone=public --list-rich-rules
firewall-cmd --zone=public --query-port=18443/tcp
```

| Approach | Use when |
|---|---|
| `--add-service` | A named service, everyone in the zone |
| `--add-port` | A raw port, everyone in the zone |
| Rich rule | One port and one source, no new zone |
| Source zone | Several rules for the same set of sources |

A zone is chosen by the **incoming** interface or source address. A rule in a zone the packet never enters is invisible.

## Defence in depth

| Layer | Question | Failure |
|---|---|---|
| Service | Running and listening? | `Connection refused` |
| firewalld | May this source reach this port? | Refused or timeout |
| SELinux | May this process use this object? | `403`, bind failure, `503`, AVC |

Fix the layer that refused, then test the whole path again. Fixing one layer and stopping is the classic mistake.

## Traps

| Trap | Fix |
|---|---|
| `chcon` for a permanent fix | `semanage fcontext` + `restorecon` |
| `restorecon` with no `fcontext` mapping | Add the mapping first |
| `setenforce 0` to "fix" a service | Read the AVC, fix the label |
| `SELINUX=disabled` | Use permissive while debugging |
| `setsebool` without `-P` | Lost at reboot |
| `semanage port -a` on an already labelled port | `-m`, or a different port |
| Drop-in numbered after `50-cloud-init.conf` | Use `10-…` |
| Restarting `sshd` without `sshd -t` | Locked out; test first |
| `chmod 644` on a private key | `chmod 600` |
| `--add-port` plus a rich rule | The port defeats the restriction |
| Testing a rich rule with `--query-port` | It says `no` correctly; test with a client |
| Testing a firewall rule from loopback | Loopback skips interface rules |
