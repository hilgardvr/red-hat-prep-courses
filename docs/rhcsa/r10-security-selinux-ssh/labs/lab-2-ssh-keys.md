# Lab 2 — Keys, not passwords

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R10 — Security: SELinux, SSH keys, and a hardened firewall |
| **Time** | 50–65 minutes |
| **Check** | `./bin/lab check r10 lab2` |
| **Skills** | `ssh-keygen`, `ssh-copy-id`, `authorized_keys` permissions, `sshd` drop-ins, first-value-wins, `sshd -t` and `sshd -T`, proving the password path is gone |

</div>

## What you are building

| Item | End state |
|---|---|
| Deploy account | `r10deploy` on `server`, with a password and no key |
| Key pair | `/home/labuser/.ssh/r10_ed25519`, mode `0600` |
| Authorised key | `r10deploy`'s `authorized_keys` holds the public half |
| Key login | `ssh -i … r10deploy@server` works with no prompt |
| Hardened daemon | `PasswordAuthentication no`, `PermitRootLogin no`, `PubkeyAuthentication yes` |
| Proof | The key still works, and a forced password login is refused |
| Persistence | The drop-in and the key both survive a reboot |

The lesson in one sentence: **a password is a secret you send, a key is a secret you keep**, and turning the password path off is only safe once the key path is proven.

!!! note "One convention for this lab"
    You are root on `server` for the whole lab, because `useradd` and `sshd` configuration need it. The commands that must use **labuser's** key — generating it, copying it, and logging in with it — are wrapped in `runuser -u labuser --`. That runs the command as `labuser` and keeps `~` pointing at `/home/labuser`. Type them exactly as shown; the wrapper is part of the command, not commentary.

## Before you begin

Continue from [Lab 1](lab-1-selinux.md) on the same machine, or start from the clean snapshot. Lab 2 does not need `httpd`, but the challenge expects both labs to be present.

```bash
cd labs
./bin/lab ssh
sudo -i
```

Only `server` is needed here.

## Step 1 — What `sshd` accepts today

```bash
sshd -T | grep -E '^(passwordauthentication|pubkeyauthentication|permitrootlogin)'
ls -l /etc/ssh/sshd_config.d/
cat /etc/ssh/sshd_config.d/50-cloud-init.conf
grep -n '^Include' /etc/ssh/sshd_config
```

```text { .no-copy }
permitrootlogin without-password
pubkeyauthentication yes
passwordauthentication yes

total 12
-rw-------. 1 root root 412 Oct 20 00:00 40-redhat-crypto-policies.conf
-rw-------. 1 root root  27 Nov 10 05:43 50-cloud-init.conf
-rw-------. 1 root root 307 Oct 20 00:00 50-redhat.conf

PasswordAuthentication yes

15:Include /etc/ssh/sshd_config.d/*.conf
```

Three things to read out of that:

- `sshd -T` prints the **effective** configuration — after includes, defaults, and `Match` blocks. It is the only honest answer to "what will this daemon actually do".
- `permitrootlogin without-password` is the shipped default: root may log in with a key, never with a password. `without-password` is an old spelling of `prohibit-password`; both mean the same thing.
- `/etc/ssh/sshd_config.d/50-cloud-init.conf` sets `PasswordAuthentication yes`. That file exists because cloud images want password login for their first-boot provisioning.

That last file is the trap in this lab.

## Step 2 — An account with a password and no key

```bash
useradd -m -s /bin/bash r10deploy
echo 'r10deploy:r10pass' | chpasswd
id r10deploy
passwd -S r10deploy
```

```text { .no-copy }
uid=1002(r10deploy) gid=1002(r10deploy) groups=1002(r10deploy)
r10deploy P 2026-11-10 0 99999 7 -1
```

`passwd -S` prints `P` for a usable password. The date column is the day the password was last set, so yours will differ. That is the state you are about to make irrelevant: after Step 6 this account still **has** a password, and it can no longer be used over SSH. That distinction matters — the requirement is normally "keys only", not "an account with no password", and locking the password would break `su` and console login too.

## Step 3 — A key pair

```bash
runuser -u labuser -- test -f ~/.ssh/r10_ed25519 \
  || runuser -u labuser -- ssh-keygen -t ed25519 -N '' \
       -f ~/.ssh/r10_ed25519 -C 'r10 deploy'
runuser -u labuser -- ls -l ~/.ssh/r10_ed25519 ~/.ssh/r10_ed25519.pub
runuser -u labuser -- cat ~/.ssh/r10_ed25519.pub
```

```text { .no-copy }
Generating public/private ed25519 key pair.
Your identification has been saved in /home/labuser/.ssh/r10_ed25519
Your public key has been saved in /home/labuser/.ssh/r10_ed25519.pub
The key fingerprint is:
SHA256:5F6E+0bMwD/0xsqalxNlh1OH620QAOPyWtqvnL3ZpSo r10 deploy
The key's randomart image is:
+--[ED25519 256]--+
|          o... . |
|       . o .  + .|
|        * +  o + |
|       o @ o= +  |
|        S Xo++ o |
|       . X.+  . o|
|        + *o   ..|
|         =E+ o o |
|        o.++*oo  |
+----[SHA256]-----+
-rw-------. 1 labuser labuser 399 Nov 11 04:31 /home/labuser/.ssh/r10_ed25519
-rw-r--r--. 1 labuser labuser  92 Nov 11 04:31 /home/labuser/.ssh/r10_ed25519.pub
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPKPpkTURsYPKH3z44mlZ8z5VZ8U2h9fe5YnuKs4aMDe r10 deploy
```

- `-t ed25519` is the modern default: short, strong, fast. RSA still works, but there is no reason to choose it for a new key.
- `-N ''` sets an empty passphrase. Correct for a deploy or automation key; a human key should have a passphrase and an agent.
- `-f` names the file. Without it you get `id_ed25519`, and a second run would overwrite it.
- `-C` is a comment. It travels inside the public key, so it shows up in `authorized_keys` and in the server's log.

The private half is `0600` and stays here. The public half is what travels.

!!! warning "Permissions are load-bearing"
    If the private key is readable by group or others, `ssh` refuses to use it: `Permissions 0644 for '/home/labuser/.ssh/r10_ed25519' are too open.` That is a safety feature, not a bug. `chmod 600` is the fix.

## Step 4 — Install the public key

`ssh-copy-id` logs in **once with the password**, then appends the key and fixes the permissions on the far side:

```bash
runuser -u labuser -- ssh-copy-id -i /home/labuser/.ssh/r10_ed25519.pub r10deploy@server
```

```text { .no-copy }
/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/home/labuser/.ssh/r10_ed25519.pub"
/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
r10deploy@server's password:

Number of key(s) added: 1

Now try logging into the machine, with: "ssh -i /home/labuser/.ssh/r10_ed25519 -o 'StrictHostKeyChecking=accept-new' 'r10deploy@server'"
and check to make sure that only the key(s) you wanted were added.
```

The password is `r10pass`. The host key is already trusted, because the lab kit's provisioning wrote `server` into `labuser`'s `known_hosts`; on a fresh machine `ssh-copy-id` would ask you to accept the fingerprint first, and the answer is `yes`.

Look at what it created:

```bash
ls -la /home/r10deploy/.ssh
cat /home/r10deploy/.ssh/authorized_keys
```

```text { .no-copy }
total 4
drwx------. 2 r10deploy r10deploy 29 Nov 11 04:31 .
drwx------. 3 r10deploy r10deploy 74 Nov 11 04:31 ..
-rw-------. 1 r10deploy r10deploy 92 Nov 11 04:31 authorized_keys
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPKPpkTURsYPKH3z44mlZ8z5VZ8U2h9fe5YnuKs4aMDe r10 deploy
```

Three modes have to be right, and `ssh-copy-id` gets all three: the home directory is not writable by others (`drwx------`), `~/.ssh` is `0700`, and `authorized_keys` is `0600`. A perfect key in a world-writable directory is ignored, and the server log says `Authentication refused: bad ownership or modes`.

## Step 5 — Log in with the key, and know it was the key

```bash
runuser -u labuser -- ssh -i ~/.ssh/r10_ed25519 -o IdentitiesOnly=yes \
  -o BatchMode=yes r10deploy@server 'whoami; hostname'
```

```text { .no-copy }
r10deploy
server
```

Two options are doing real work:

- `IdentitiesOnly=yes` makes `ssh` offer **only** the key named with `-i`. Without it, an agent or another key in `~/.ssh` might be the one that succeeded and you would learn nothing.
- `BatchMode=yes` forbids a password prompt. If the key fails, the command fails instead of quietly falling back to a password — which is exactly the confusion this lab exists to prevent.

There is also a key already in `~/.ssh/authorized_keys` for `labuser`, installed by the lab kit. It is untouched by this lab and the checker asserts it still works, because the most common way to break a machine here is to harden the *only* account you can log in with.

## Step 6 — Turn off password authentication

Create a drop-in rather than editing `sshd_config`:

```bash
cat >/etc/ssh/sshd_config.d/10-r10.conf <<'EOF'
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
EOF
chmod 0644 /etc/ssh/sshd_config.d/10-r10.conf
sshd -t
systemctl reload sshd
```

```text { .no-copy }
```

No output from `sshd -t` means the configuration parses. Then read the effective result:

```bash
sshd -T | grep -E '^(passwordauthentication|permitrootlogin|pubkeyauthentication)'
```

```text { .no-copy }
permitrootlogin no
pubkeyauthentication yes
passwordauthentication no
```

### Why the drop-in is numbered `10`

`sshd` reads drop-ins in alphabetical order, and for most keywords **the first value wins**. `50-cloud-init.conf` sets `PasswordAuthentication yes`, so a drop-in numbered *after* it is ignored — the daemon keeps the earlier value and your carefully written `no` has no effect at all.

Watch it happen. This is what the same file looks like when it is named `60-r10.conf`:

```bash
mv /etc/ssh/sshd_config.d/10-r10.conf /etc/ssh/sshd_config.d/60-r10.conf
systemctl reload sshd
sshd -T | grep '^passwordauthentication'
```

```text { .no-copy }
passwordauthentication yes
```

The file is correct. The number is wrong. `sshd -ddd -t` shows exactly why:

```text { .no-copy }
debug2: /etc/ssh/sshd_config line 15: including /etc/ssh/sshd_config.d/50-cloud-init.conf
debug3: /etc/ssh/sshd_config.d/50-cloud-init.conf:1 setting PasswordAuthentication yes
debug2: /etc/ssh/sshd_config line 15: including /etc/ssh/sshd_config.d/60-r10.conf
debug3: /etc/ssh/sshd_config.d/60-r10.conf:1 setting PasswordAuthentication no
```

Both lines are parsed, and the first one set the value. Put it back at `10`:

```bash
mv /etc/ssh/sshd_config.d/60-r10.conf /etc/ssh/sshd_config.d/10-r10.conf
systemctl reload sshd
sshd -T | grep -E '^(passwordauthentication|permitrootlogin)'
```

```text { .no-copy }
permitrootlogin no
passwordauthentication no
```

This is the single most useful five minutes in the module. On any RHEL cloud image, a hardening drop-in numbered 50 or above silently does nothing, and the only way to know is `sshd -T` — never the file you wrote.

!!! warning "Never reload a configuration you have not tested"
    `sshd -t` parses the file and exits non-zero on an error. A syntax error plus `systemctl restart sshd` can leave the daemon down and you outside the machine. `reload` keeps established sessions and is the safer verb, but it still applies a broken file if `sshd -t` was skipped.

    Keep a second way in until a **new** connection succeeds: an open session, the Vagrant console, or `./bin/lab ssh`, which uses its own key and is unaffected by `PasswordAuthentication`.

## Step 7 — The key still works, the password does not

```bash
runuser -u labuser -- ssh -i ~/.ssh/r10_ed25519 -o IdentitiesOnly=yes \
  -o BatchMode=yes r10deploy@server true
echo "key login: $?"

runuser -u labuser -- ssh -o BatchMode=yes -o PubkeyAuthentication=no \
  -o PreferredAuthentications=password labuser@server true
echo "password login: $?"

runuser -u labuser -- ssh -o BatchMode=yes labuser@server true
echo "lab key: $?"
```

```text { .no-copy }
key login: 0
labuser@server: Permission denied (publickey,gssapi-keyex,gssapi-with-mic).
password login: 255
lab key: 0
```

Three results, three facts:

- The deploy key works.
- A login that offers only a password is refused, and the method list in the parentheses has **no** `,password` at the end.
- `labuser`'s lab-kit key still works, so the machine is not locked.

That parentheses list is the scriptable answer to "did it take?" Compare it with a server that still accepts passwords:

```text { .no-copy }
labuser@server: Permission denied (publickey,gssapi-keyex,gssapi-with-mic,password).
```

The presence or absence of `,password` is what the checker reads, and it is a far better test than grepping the config file, because it is the daemon's own reply.

## Step 8 — Persistence: reboot

```bash
systemctl reboot
```

Reconnect and check:

```bash
cd labs
./bin/lab ssh
sudo -i

sshd -T | grep -E '^(passwordauthentication|permitrootlogin|pubkeyauthentication)'
runuser -u labuser -- ssh -i /home/labuser/.ssh/r10_ed25519 \
  -o IdentitiesOnly=yes -o BatchMode=yes r10deploy@server true; echo "deploy=$?"
runuser -u labuser -- ssh -o BatchMode=yes labuser@server true; echo "labuser=$?"
```

```text { .no-copy }
permitrootlogin no
pubkeyauthentication yes
passwordauthentication no
deploy=0
labuser=0
```

The drop-in lives in `/etc/ssh/sshd_config.d/`, the key lives in `/home/r10deploy/.ssh/authorized_keys`, and the account lives in `/etc/passwd`. Three files, and every one of them is on disk, so nothing had to be re-created.

## Verify with the checker

```bash
./bin/lab check r10 lab2
```

```text { .no-copy }
R10 Lab 2 — A key, and a daemon that refuses passwords
  PASS  the deploy account exists
  PASS  the deploy key is readable only by its owner
  PASS  the deploy account logs in with the key
  PASS  ssh no longer accepts passwords
  PASS  ssh no longer accepts root logins
  PASS  ssh still accepts public keys
  PASS  the sshd configuration parses
  PASS  a password-only login is refused
  PASS  the server does not offer the password method
  PASS  labuser still logs in with the lab key
```

The checker reads the effective configuration with `sshd -T`, then makes three real connections: one with the deploy key, one that offers only a password, and one with the lab kit's key. Configuration alone would pass a drop-in that lost the first-value-wins race; connections alone would not tell you *which* setting did it. Both together are the honest test.

## If something went wrong

| Symptom | Likely cause | Fix |
|---|---|---|
| `Permission denied (publickey)` on the key login | Wrong key file, or `authorized_keys` permissions | `ls -la ~/.ssh` on the target; fix to `700`/`600` |
| `Permissions 0644 … are too open` | Private key is group- or world-readable | `chmod 600 ~/.ssh/r10_ed25519` |
| `sshd -T` still says `passwordauthentication yes` | Drop-in numbered after `50-cloud-init.conf` | Rename to `10-r10.conf`, reload |
| `sshd -t` fails on a drop-in | File is group- or world-writable | `chmod 0644` |
| Locked out entirely | Password method off and no key installed | Use `./bin/lab ssh`, install the key, re-test |
| `ssh-copy-id` says "key already exists" | Re-running the lab | Harmless; the key is already in `authorized_keys` |
| The deploy key works but `labuser` does not | `labuser`'s key was removed from `authorized_keys` | Re-run `./bin/lab up`, which reinstalls the lab key |
| `Bad owner or permissions on /home/labuser/.ssh/config` | The lab kit's config file was edited | `chmod 600 /home/labuser/.ssh/config` |

To undo the lab:

```bash
rm -f /etc/ssh/sshd_config.d/10-r10.conf
systemctl reload sshd
userdel -r r10deploy
rm -f /home/labuser/.ssh/r10_ed25519 /home/labuser/.ssh/r10_ed25519.pub
```

or `./bin/lab restore clean`. **Remove the drop-in and reload before deleting the account**, or you will have turned passwords off while removing the only key that worked.

## Next

[The challenge](challenge-hardened-host.md) adds a source-restricted firewall rule in front of the SELinux-hardened web server, puts the SSH hardening back in the picture, and requires the whole stack to survive a reboot.
