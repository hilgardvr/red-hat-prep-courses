# Lab 2 — Passwords, policy, and sudo

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R2 — Users and groups |
| **Time** | 45–60 minutes |
| **Check** | `./bin/lab check r02 lab2` |
| **Skills** | `passwd`, `chage`, locking, `sudoers.d`, `visudo`, `umask` |

</div>

## What you are building

| Account | Password | Aging | State at the end |
|---|---|---|---|
| `devon` | set | max 90, min 7, warn 14 | usable, can run one command with `sudo` |
| `mira` | set | max 60, min 5, warn 10, expires 2027-12-31 | locked |
| `intern` | set | max 30 | must change password at next login |

Plus a sudo drop-in that lets the `operators` group inspect `sshd` without a password, and a umask of `027` for `devon`.

This lab builds on [Lab 1](lab-1-accounts-and-groups.md). `devon` and the `operators` group must already exist.

## Before you begin

If you restored the snapshot since Lab 1, redo it first. Otherwise log in and become root:

```bash
cd labs
./bin/lab ssh
sudo -i
```

## Step 1 — Set passwords

```bash
passwd devon
passwd mira
```

You are prompted twice per user. Use a password that satisfies the default quality rules — at least eight characters, mixed case, a digit, and a symbol. `Labpass1!` works and is easy to remember on a disposable machine.

Root can set any password. An ordinary user running `passwd` is asked for their current password first, and their new one is checked against the same rules.

Verify the state:

```bash
passwd -S devon
passwd -S mira
```

```text { .no-copy }
devon P 2026-11-10 0 99999 7 -1
mira  P 2026-11-10 0 99999 7 -1
```

`P` means a usable password is set. `L` would mean locked, `NP` would mean no password at all. (Some releases print the two-letter `PS` and `LK`; the meaning is the same.) The four numbers are the minimum, maximum, warning, and inactivity values from `/etc/shadow`; they still hold the defaults from `/etc/login.defs` until you set the policy in the next step.

Look at the hash without printing it in full:

```bash
getent shadow devon | cut -d: -f1,2 | cut -c1-12
```

```text { .no-copy }
devon:$y$j9T
```

`$y$` is yescrypt, the default on RHEL 10 and AlmaLinux 10. Older systems show `$6$` for SHA-512. Either way you never need to produce a hash by hand — `passwd` does it.

## Step 2 — Set password aging with `chage`

```bash
chage -M 90 -m 7 -W 14 devon
chage -M 60 -m 5 -W 10 -E 2027-12-31 mira
```

| Flag | Meaning |
|---|---|
| `-M 90` | Password must be changed at least every 90 days |
| `-m 7` | It cannot be changed again for 7 days — this defeats "change it back immediately" |
| `-W 14` | Start warning 14 days before expiry |
| `-E 2027-12-31` | The **account** stops working on that date |

Read both back:

```bash
chage -l devon
chage -l mira
```

Expected shape:

```text { .no-copy }
Last password change                                    : Nov 08, 2026
Password expires                                        : Feb 06, 2027
Password inactive                                       : never
Account expires                                         : never
Minimum number of days between password change          : 7
Maximum number of days between password change          : 90
Number of days of warning before password expires       : 14
```

```text { .no-copy }
Last password change                                    : Nov 08, 2026
Password expires                                        : Jan 07, 2027
Password inactive                                       : never
Account expires                                         : Dec 31, 2027
Minimum number of days between password change          : 5
Maximum number of days between password change          : 60
Number of days of warning before password expires       : 10
```

Your "Password expires" date depends on the day you ran the command. The three numbers and the account expiry date are what the checker reads.

`-E` is easy to confuse with `-M`. `-M` expires the **password**, and the user can still log in to change it. `-E` expires the **account**, and nothing works.

## Step 3 — Lock mira

```bash
passwd -l mira
passwd -S mira
chage -l mira
```

```text { .no-copy }
mira L 2026-11-10 5 60 10 -1
```

The aging values are still there. Locking is not deletion and it does not clear the policy — it prefixes the hash with `!`, so the password cannot be verified.

Look at the difference in the shadow file:

```bash
getent shadow mira | cut -d: -f1,2 | cut -c1-12
```

```text { .no-copy }
mira:!$y$j9T
```

Do not unlock her; the locked state is what the checker expects. When you want it back, `passwd -u mira` (or `usermod -U mira`) removes the `!`.

!!! warning "Locked password, open door"
    `passwd -l` stops password authentication only. If mira had an SSH key installed, she could still log in. Real account suspension is `passwd -l` **plus** `usermod -s /sbin/nologin` or `chage -E <date>`. R10 covers the SSH key side.

## Step 4 — Onboard an intern who must choose their own password

```bash
useradd -m -s /bin/bash -G developers -c "Intern" intern
passwd intern
chage -M 30 -d 0 intern
chage -l intern
```

The `-d 0` sets the last-change date to 1970-01-01, which means "your password is older than any maximum". Read it back:

```text { .no-copy }
Last password change                                    : password must be changed
Password expires                                        : password must be changed
...
Maximum number of days between password change          : 30
```

That is what every real onboarding process does: an administrator sets a temporary password, the user is forced to replace it on first login, and normal aging applies from then on.

## Step 5 — Write a sudo policy

Look at the baseline first. Read the main file, but do not edit it:

```bash
grep -E '^(#includedir|@includedir|%wheel)' /etc/sudoers
visudo -c
```

```text { .no-copy }
%wheel	ALL=(ALL)	ALL
#includedir /etc/sudoers.d
/etc/sudoers: parsed OK
```

`%wheel ALL=(ALL) ALL` is the standard "full administrator" grant, and it is why `labuser` can use `sudo`. `#includedir` is **not** a comment — in the sudoers grammar a leading `#` on that directive means "include". AlmaLinux 10 uses the legacy spelling; newer releases write `@includedir`. Either way `/etc/sudoers.d` is read, and that is where your own rules go, never in the main file.

Write the candidate in `/tmp` and validate it **before** it is reachable by `sudo`:

```bash
cat > /tmp/10-r2-operators <<'EOF'
# Operators may inspect the SSH service without a password.
%operators ALL=(root) NOPASSWD: /usr/bin/systemctl status sshd, /usr/bin/journalctl -u sshd
EOF

visudo -cf /tmp/10-r2-operators
```

```text { .no-copy }
/tmp/10-r2-operators: parsed OK
```

Only now install it, with the owner and mode `sudo` requires:

```bash
install -m 0440 -o root -g root /tmp/10-r2-operators /etc/sudoers.d/10-r2-operators
ls -l /etc/sudoers.d/
visudo -c
```

```text { .no-copy }
-r--r-----. 1 root root 152 ... 10-r2-operators
-r--r-----. 1 root root 135 ... 90-cloud-init-users
-r--r-----. 1 root root  22 ... 90-rhcsa-labuser
-r--r-----. 1 root root  40 ... vagrant
/etc/sudoers: parsed OK
/etc/sudoers.d/10-r2-operators: parsed OK
...
```

The lab image ships its own drop-ins (`90-cloud-init-users` gives `vagrant` passwordless sudo; `90-rhcsa-labuser` gives `labuser` normal sudo). Your new file is the only one you created; the rest are expected.

Mode `0440` and root ownership are not style choices. `sudo` ignores drop-in files that an unprivileged user could have modified, and it ignores filenames containing a dot — that is how it skips `10-r2-operators~` after an editor crash.

### Prove the rule works, and that it is narrow

```bash
sudo -l -U devon
```

```text { .no-copy }
Matching Defaults entries for devon on server:
    ...
User devon may run the following commands on server:
    (root) NOPASSWD: /usr/bin/systemctl status sshd, /usr/bin/journalctl -u sshd
```

`sudo -l -U` reads another user's rights as root. Note that `devon` appears because of his `operators` membership, not by name.

Now test as `devon`, with `-n` so a prompt cannot hang the command:

```bash
su - devon -c 'sudo -n systemctl status sshd | head -4'
```

You should see the `sshd` service status. Then try something outside the rule:

```bash
su - devon -c 'sudo -n systemctl restart sshd'
```

```text { .no-copy }
sudo: a password is required
```

`-n` means "never prompt". A command that is not covered by a `NOPASSWD` rule would need a password, so with `-n` it fails immediately instead of hanging your script. Drop the `-n` and you would be asked for devon's password, then refused.

That refusal is the point. The rule names one command line, so a different verb is not covered.

For contrast, `mira` is not in `operators`:

```bash
sudo -l -U mira
```

Her list is empty — `sudo` reports `User mira is not allowed to run sudo on server.` Locking her does not affect this; `sudo -l -U` reports policy, not current login ability.

## Step 6 — Set a umask for one user

Check the current default for `devon` from a login shell — not from your root shell:

```bash
su - devon -c 'umask'
```

```text { .no-copy }
0022
```

`022` means new files are `644` and directories `755`. Devon's primary group is `developers`, not `devon`, so he does not get the `002` that the user-private-group rule would give him.

Make it persistent by appending to his profile:

```bash
echo 'umask 027' >> /home/devon/.bash_profile
tail -3 /home/devon/.bash_profile
su - devon -c 'umask'
```

```text { .no-copy }
umask 027
0027
```

Now prove what that does to new objects, again from a login shell:

```bash
su - devon -c 'd=$(mktemp -d); touch "$d/f"; mkdir "$d/d"; stat -c "%a %n" "$d/f" "$d/d"; rm -rf "$d"'
```

```text { .no-copy }
640 /tmp/tmp.a1b2c3/f
750 /tmp/tmp.a1b2c3/d
```

`666` minus `027` is `640`; `777` minus `027` is `750`.

!!! note "Why not `/etc/profile.d`?"
    A file in `/etc/profile.d` would set the umask for **every** login, including root's. Every file root creates by redirection in later modules would then be `640`, and a service running as another user might be unable to read it. The exam asks about default permissions in general; this lab scopes the change to one user so the rest of the course does not inherit it. Section [Default permissions](../index.md#default-permissions-umask) in the theory covers the system-wide option and when it is appropriate.

## Step 7 — Reboot and prove persistence

Everything here is stored in files, so it should survive. The check is still worth doing, because "I set it in a shell once" is a very common failure.

```bash
reboot
```

Wait for the machine to come back, then from the host:

```bash
cd labs
./bin/lab ssh
sudo -i
```

Re-run the verification list:

```bash
id devon
passwd -S devon
passwd -S mira
chage -l devon
chage -l mira
chage -l intern
sudo -l -U devon
visudo -c
su - devon -c 'umask'
```

Every line should match what you saw before the reboot. In particular, `su - devon -c 'umask'` must still print `0027` — that proves the setting is in a file, not in a shell you happened to leave open.

## Step 8 — Run the checker

```bash
./bin/lab check r02 lab2
```

<details>
<summary>Show the expected check output</summary>

```text { .no-copy }
R2 Lab 2 — Passwords, policy, and sudo
  PASS  devon has a usable password
  PASS  devon's aging: max 90 days
  PASS  devon's aging: min 7 days
  PASS  devon's aging: warn 14 days
  PASS  mira has a password set
  PASS  mira's aging: max 60 days
  PASS  mira's aging: min 5 days
  PASS  mira's aging: warn 10 days
  PASS  mira's account expires on Dec 31, 2027
  PASS  mira's account is locked
  PASS  user intern exists
  PASS  intern's shell is /bin/bash
  PASS  intern is a member of developers
  PASS  intern's aging: max 30 days
  PASS  intern must change password at next login
  PASS  sudoers drop-in exists: /etc/sudoers.d/10-r2-operators
  PASS  sudoers drop-in is mode 0440
  PASS  sudoers drop-in is owned by root:root
  PASS  sudoers drop-in parses
  PASS  the whole sudoers configuration parses
  PASS  devon may run 'systemctl status sshd' with sudo
  PASS  mira may not run it
  PASS  devon's login-shell umask is 0027
  PASS  devon's login shell creates files 640
  PASS  devon's login shell creates directories 750
  PASS  labuser still has sudo through wheel
```

</details>

The last check exists for a reason: it is the one that catches a learner who removed `labuser` from `wheel` by accident.

## What to remember

- `passwd -S` answers "is this account usable with a password?" — `P`, `L`, or `NP` (`PS`/`LK` on older releases).
- `chage -M` expires the password; `chage -E` expires the account; `chage -d 0` forces a change.
- `passwd -l` blocks password login only, not SSH keys or running services.
- Rules belong in `/etc/sudoers.d`, mode `0440`, root-owned, no dot in the name.
- Validate with `visudo -cf` in `/tmp` **before** installing the file.
- `sudo` matches the full command line; a rule for `status` does not allow `restart`.
- The umask is per process. Prove it from a login shell, not from the shell where you set it.
