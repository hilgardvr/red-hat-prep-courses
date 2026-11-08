# R2 cheat sheet

A compact reference for review. Everything here is explained in the [theory page](index.md).

## The account files

| File | Holds |
|---|---|
| `/etc/passwd` | name, UID, GID, comment, home, shell |
| `/etc/shadow` | hash, aging, lock state, expiry (root only) |
| `/etc/group` | group name, GID, **supplementary** members |
| `/etc/gshadow` | group password and administrators (root only) |

| Task | Command |
|---|---|
| Look up an account | `getent passwd user` |
| Look up a group | `getent group group` |
| Show identity and groups | `id user` / `id -nG user` |
| Show the shadow entry | `getent shadow user` (root) |
| Safe manual edit | `vipw` and `vigr` (add `-s` for shadow and gshadow) |
| Check file consistency | `pwck` / `grpck` |

## Users

| Task | Command |
|---|---|
| Create a user | `useradd -m -s /bin/bash user` |
| With UID, group, comment | `useradd -u 3001 -g grp -G extra -c "Name" -s /bin/bash -m user` |
| System account | `useradd -r -m -d /var/lib/svc -s /sbin/nologin svc` |
| Home elsewhere | `useradd -d /data/user -m user` |
| Account expiry at creation | `useradd -e 2027-12-31 user` |
| Show defaults | `useradd -D` |
| Change the default shell | `useradd -D -s /bin/sh` |
| Modify | `usermod -c "Name" user` |
| Add a supplementary group | `usermod -aG grp user` |
| Replace the group list | `usermod -G grp1,grp2 user` |
| Change shell | `usermod -s /sbin/nologin user` |
| Rename | `usermod -l newname oldname` |
| Move the home directory | `usermod -d /home/newname -m newname` |
| Lock / unlock | `usermod -L user` / `usermod -U user` |
| Delete, keep files | `userdel user` |
| Delete with home and mail | `userdel -r user` |

## Groups

| Task | Command |
|---|---|
| Create | `groupadd grp` |
| Create with GID | `groupadd -g 3001 grp` |
| System group | `groupadd -r grp` |
| Rename | `groupmod -n newname oldname` |
| Change GID | `groupmod -g 3010 grp` |
| Delete | `groupdel grp` |
| Add a member | `gpasswd -a user grp` |
| Remove a member | `gpasswd -d user grp` |
| Set the member list | `gpasswd -M u1,u2 grp` |
| New primary group for this shell | `newgrp grp` |
| Run one command with a group | `sg grp -c 'command'` |

## Passwords and aging

| Task | Command |
|---|---|
| Change your password | `passwd` |
| Set someone else's | `passwd user` (root) |
| Status | `passwd -S user` — `PS`, `LK`, `NP` |
| Lock / unlock | `passwd -l user` / `passwd -u user` |
| Expire immediately | `passwd -e user` |
| Show aging | `chage -l user` |
| Maximum days | `chage -M 90 user` |
| Minimum days | `chage -m 7 user` |
| Warning days | `chage -W 14 user` |
| Inactive days after expiry | `chage -I 30 user` |
| Account expiry date | `chage -E 2027-12-31 user` |
| Force a change at next login | `chage -d 0 user` |
| Remove an expiry date | `chage -E -1 user` |

## sudo

| Task | Command |
|---|---|
| Run one command as root | `sudo command` |
| Run as another user | `sudo -u postgres psql` |
| Root login shell | `sudo -i` |
| What may I run? | `sudo -l` |
| What may someone else run? | `sudo -l -U user` (root) |
| Never prompt (for testing) | `sudo -n command` |
| Forget cached credentials | `sudo -k` |
| Validate everything | `visudo -c` |
| Validate one candidate file | `visudo -cf /tmp/file` |

Rule shape:

```text
who        where = (as_whom)  what
%operators ALL   = (root)     NOPASSWD: /usr/bin/systemctl status sshd
devon      ALL   = (ALL)      ALL
```

Drop-in rules:

- Directory: `/etc/sudoers.d/`
- Owner: `root:root`
- Mode: `0440`
- No `.` in the filename
- Validate with `visudo -cf` **before** installing
- The main file includes it with `@includedir /etc/sudoers.d`

## umask

| umask | New file | New directory |
|---|---|---|
| `022` | `644` | `755` |
| `027` | `640` | `750` |
| `077` | `600` | `700` |

| Task | Command or file |
|---|---|
| Read it | `umask` |
| Set it for this shell | `umask 027` |
| Persist for one user | append to `~/.bash_profile` |
| Persist for all login shells | `/etc/profile.d/99-umask.sh` |
| Persist for a service | `UMask=` in the unit |
| Test from a login shell | `su - user -c 'umask'` |

## Verification

Run these after a reboot; identical output means the configuration persisted.

```bash
getent passwd devon
getent group developers
id devon
passwd -S devon
chage -l devon
sudo -l -U devon
visudo -c
su - devon -c 'umask'
```

## The persistence rule

Account data lives in files under `/etc`, so it survives a reboot by itself. What does not survive:

- a `umask` set in a shell you typed into
- an exported variable
- a `newgrp` subshell
- a sudo file left in `/tmp` and never installed

Write the change to a file that is read at the right time — `~/.bash_profile`, `/etc/profile.d`, `/etc/sudoers.d`, `/etc/shadow` via `chage` — and then prove it from a fresh login shell.
