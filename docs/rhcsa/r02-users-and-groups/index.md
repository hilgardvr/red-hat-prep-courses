# R2 — Users and groups

<div class="module-meta" markdown>

| | |
|---|---|
| **Exam objective group** | 9 — Manage users and groups (plus "configure privileged access" and default permissions) |
| **Time** | 3–4 hours including labs |
| **Prerequisites** | [R1 — Essential tools](../r01-essential-tools/index.md), especially [Permissions](../r01-essential-tools/index.md#permissions) |
| **Labs** | 2 guided labs + 1 challenge |
| **Check command** | `./bin/lab check r02 lab1` (also `lab2` and `challenge`) |

</div>

Every exam task happens as some user. A web server needs an account to run as, a team needs a shared group to write into a directory, and an administrator needs a way to run one privileged command without becoming root. This module is about creating and controlling those identities.

The commands are short. The part that trips people up is the state behind them: which of the four account files holds what, when a group change takes effect, and what actually survives a reboot.

## Objective checklist

By the end of this module you should be able to:

- [ ] Create, delete, and modify local user accounts
- [ ] Create, delete, and modify local groups and group memberships
- [ ] Change passwords and adjust password aging for local accounts
- [ ] Lock an account and force a password change at next login
- [ ] Configure privileged access with `sudo` and `/etc/sudoers.d`
- [ ] Manage default file permissions with `umask`
- [ ] Read `/etc/passwd`, `/etc/shadow`, and `/etc/group` and explain each field
- [ ] Prove that all of the above survives a reboot

---

## Identity in one page

Linux identifies a user by a numeric **UID** and a group by a numeric **GID**. Names exist for humans. The kernel checks numbers, which is why a deleted user's files keep working but show up as a number.

```bash
id
id devon
id -nG devon
getent passwd devon
getent group developers
```

```text
uid=3001(devon) gid=3001(developers) groups=3001(developers),3002(operators)
devon developers operators
devon:x:3001:3001:Devon Rivera:/home/devon:/bin/bash
developers:x:3001:devon,labuser
```

`getent` asks the system's name service, not just the files. On a lab machine that means `/etc/passwd`, but on a real server it may also return accounts from LDAP or Kerberos. The exam asks about **local** accounts, so the files below are what change.

### The four files

| File | Holds | Readable by |
|---|---|---|
| `/etc/passwd` | Account name, UID, GID, comment, home, shell | Everyone |
| `/etc/shadow` | Password hash, aging, lock state, expiry | Root only |
| `/etc/group` | Group name, GID, supplementary members | Everyone |
| `/etc/gshadow` | Group password and group administrators | Root only |

`/etc/passwd` is world-readable on purpose: programs need to turn a UID into a name. The password hash is therefore in `/etc/shadow`, which is mode `0000` and root-only.

### `/etc/passwd` fields

```text
devon:x:3001:3001:Devon Rivera:/home/devon:/bin/bash
  │   │  │    │        │           │          │
  │   │  │    │        │           │          └─ login shell
  │   │  │    │        │           └─ home directory
  │   │  │    │        └─ GECOS: full name and other comment text
  │   │  │    └─ primary group (GID, not a name)
  │   │  └─ UID
  │   └─ password placeholder: "x" means "look in /etc/shadow"
  └─ login name
```

### `/etc/shadow` fields

```text
devon:$y$j9T$...:20430:7:90:14:::
  │      │        │   │ │  │  └─ fields 7-9: inactive days, expiry, reserved
  │      │        │   │ │  └─ warning days before the password expires
  │      │        │   │ └─ maximum days between password changes
  │      │        │   └─ minimum days between password changes
  │      │        └─ days since 1970-01-01 that the password last changed
  │      └─ hash; "!" or "!!" in front means locked
  └─ login name
```

You almost never edit these files by hand. `useradd`, `usermod`, `passwd`, and `chage` write them, and `vipw` / `vigr` exist for the rare manual edit because they lock the file while you work.

### `/etc/group` fields

```text
developers:x:3001:devon,labuser
    │      │   │        └─ supplementary members
    │      │   └─ GID
    │      └─ group password placeholder (almost always unused)
    └─ group name
```

Notice what is **not** in that list: users whose **primary** group this is. Membership is implicit through the GID in `/etc/passwd`. To see everyone, including primary-group members, use `id user` or `getent group` plus the passwd file.

### UID and GID ranges

`/etc/login.defs` decides where new numbers come from:

```text
UID_MIN          1000
UID_MAX         60000
GID_MIN          1000
GID_MAX         60000
SYS_UID_MIN       201
SYS_UID_MAX       999
```

| Range | Used for |
|---|---|
| `0` | `root`, and only root |
| `1–200` | Static system accounts shipped by packages (`bin`, `daemon`) |
| `201–999` | Dynamic system accounts, including `-r` users you create |
| `1000–60000` | Ordinary human accounts |

A UID of `0` is root, whatever the name. Never create a second UID 0 account.

### Primary and supplementary groups

- **Primary group** — exactly one, stored as a number in `/etc/passwd`. New files are created with this group.
- **Supplementary groups** — any number, listed in `/etc/group`. They grant access to files owned by those groups.

`id -nG` lists both. Group membership is read when a **session starts**. Change a user's groups and their already-open shells keep the old set until they log out and back in.

```bash
su - devon          # a fresh login session, with the current groups
newgrp operators    # start a subshell with a different primary group
```

### The user-private-group scheme

On RHEL, `useradd` normally creates a group with the same name as the user and makes it the primary group. That is the **user private group** (UPG) scheme. It is why a user can share files with a group without giving away ownership.

Because of it, `/etc/profile` sets a default umask of `002` for ordinary users whose primary group matches their name, and `022` for everyone else. A user whose primary group is a shared team group therefore gets the more restrictive default. That detail matters when you wonder why one user's files are group-writable and another's are not.

---

## Creating users

The command is `useradd`. Everything it needs has a default, so the exam answer is usually a short list of overrides.

```bash
useradd -u 3001 -g developers -G operators \
        -c "Devon Rivera" -s /bin/bash -m devon
```

| Option | Meaning | Default if omitted |
|---|---|---|
| `-u UID` | Numeric UID | next free number from `/etc/login.defs` |
| `-g GROUP` | Primary group | a new group named after the user |
| `-G g1,g2` | Supplementary groups | none |
| `-c "text"` | GECOS comment (full name) | empty |
| `-d /path` | Home directory | `/home/name` |
| `-m` | Create the home directory | `CREATE_HOME yes` in `/etc/login.defs` |
| `-M` | Do **not** create a home directory | — |
| `-s /bin/bash` | Login shell | `/bin/bash` from `/etc/default/useradd` |
| `-e YYYY-MM-DD` | Account expiry date | never |
| `-f N` | Days after password expiry before the account is disabled | `-1` (never) |
| `-r` | System account (UID below 1000, no aging) | — |

### What `useradd` actually does

Creating a user is more than one line in one file:

1. Adds the entry to `/etc/passwd` and `/etc/shadow`.
2. Creates or reuses the group in `/etc/group` and `/etc/gshadow`.
3. Creates the home directory and copies `/etc/skel` into it (`.bashrc`, `.bash_profile`, `.bash_logout`).
4. Creates a mail spool at `/var/spool/mail/name`.
5. Does **not** set a password. The shadow entry starts as `!!`, which is "locked, no password".

Check all of it:

```bash
getent passwd devon
getent shadow devon          # root only
ls -ld /home/devon
ls -la /home/devon
```

`cat /etc/skel/.bashrc` is worth reading once. It is the file every new user starts with.

### Defaults

```bash
useradd -D                       # show the defaults
useradd -D -s /bin/sh            # change the default shell
cat /etc/default/useradd
grep -E 'UID_MIN|UID_MAX|CREATE_HOME|HOME_MODE' /etc/login.defs
```

`/etc/default/useradd` controls shell, home prefix, skeleton directory, and mail spool. `/etc/login.defs` controls UID ranges, home mode, and the default aging values that `useradd` writes into `/etc/shadow`.

### System accounts

A service account is not a person. It cannot log in, has no aging, and its numbers come from the system range.

```bash
useradd -r -m -d /var/lib/buildbot -s /sbin/nologin -c "Build service" buildbot
```

`-r` puts the UID below 1000 and disables password aging. `-s /sbin/nologin` makes interactive login fail with a polite message. Note that `-r` does **not** create a home directory on its own, even though `CREATE_HOME` is `yes` — system accounts need an explicit `-m` if they need one.

!!! warning "`adduser` is not a different command"
    On RHEL, `adduser` is a symlink to `useradd`. Debian's friendlier interactive `adduser` does not exist here. If a tutorial uses `adduser` and expects prompts, it was written for Ubuntu.

---

## Modifying users

`usermod` changes an existing account. It takes the same options as `useradd`, plus a few of its own.

```bash
usermod -c "Devon Rivera (platform)" devon
usermod -s /bin/sh devon
usermod -G operators,developers devon     # replaces the supplementary list
usermod -aG operators devon               # appends
usermod -L devon                          # lock the password
usermod -U devon                          # unlock it
```

### The `-a` trap

`-G` **replaces** every supplementary group. `-aG` **adds** one.

```bash
id devon
# groups=3001(developers),3002(operators)

usermod -G wheel devon
id devon
# groups=3001(developers),10(wheel)      operators is gone

usermod -aG operators devon
id devon
# groups=3001(developers),10(wheel),3002(operators)
```

This is the single most common exam mistake in this objective. Adding a group almost always means `-aG`. If you do it to your own sudo-enabled account without `-a`, you can remove your own `wheel` membership and lose `sudo` in the same command.

### Renaming and moving

```bash
usermod -l devonr devon                  # rename the account
usermod -d /home/devonr -m devonr        # move the home directory too
```

Renaming does not rename the home directory or the group. Do those separately, or you end up with a user whose home path no longer matches their name.

### Changing the password hash directly

```bash
usermod -p '$y$...' devon
```

`-p` writes the encrypted hash, not a plain password. `$y$` is yescrypt, the RHEL 10 default; older systems use `$6$` for SHA-512. Use `passwd` unless you are generating hashes in an automated build.

---

## Deleting users

```bash
userdel contractor
userdel -r contractor
```

| Command | Account | Home directory | Mail spool |
|---|---|---|---|
| `userdel name` | removed | **left behind** | left behind |
| `userdel -r name` | removed | removed | removed |

The default is deliberately conservative. It keeps data that might be needed. The catch: once the passwd entry is gone, the UID no longer has a name, so `ls -l` shows a number.

```bash
userdel contractor
ls -ld /home/contractor
# drwx------. 2 3003 3003 ... /home/contractor
```

Those numbers are the orphaned UID and GID — whatever `useradd` happened to assign. To hand the data to someone else:

```bash
chown -R devon:developers /home/contractor
```

`userdel` refuses to remove an account with running processes. Log the user out, or use `userdel -f` and accept the consequences.

A user's **group** is removed automatically only if no other account uses it as a primary group and no one is a member. Otherwise it stays, which is why a deleted developer can leave a group behind.

---

## Groups

```bash
groupadd -g 3001 developers        # create with an explicit GID
groupadd -r buildsvc               # system group, GID below 1000
groupmod -n engineering developers # rename
groupmod -g 3010 developers        # change the GID
groupdel engineering               # delete
```

`groupmod -g` renumbers the group but does **not** change the group ownership of existing files. Those files keep the old number and become orphaned in the same way a deleted user's files do. Use `find / -gid OLD -exec chgrp NEW {} +` if you need to repair that, and expect it to be slow.

`groupdel` fails if the group is the primary group of any account. Reassign those users first.

### Adding and removing members

Two commands do the same job:

```bash
usermod -aG developers mira        # add
gpasswd -a mira developers         # add
gpasswd -d mira developers         # remove
gpasswd -M devon,mira developers   # set the complete member list
```

`gpasswd -a` is safe by construction because it never replaces the list. That is why some administrators prefer it to `usermod -G`.

Adding someone to a group does not affect sessions they already have. `su - mira` or a fresh SSH login picks up the new membership. `newgrp developers` starts a subshell with a new primary group, which is a quick way to test without logging out.

---

## Passwords and aging

### Setting a password

```bash
passwd                 # change your own
passwd devon           # as root, set someone else's
passwd -S devon        # status: is it set, locked, or absent?
```

`passwd -S` is the fastest way to answer "can this account log in with a password?"

```text
devon P 2026-11-10 7 90 14 -1
mira  L 2026-11-10 5 60 10 -1
```

The second field is `P` (set), `L` (locked), or `NP` (no password); some releases print the two-letter `PS` and `LK`, with the same meaning. The four numbers are the minimum, maximum, warning, and inactivity values from `/etc/shadow`, in that order. RHEL 10 no longer appends a parenthetical such as `(Password set, SHA512 crypt.)`.

### Locking and unlocking

```bash
passwd -l mira        # lock
passwd -u mira        # unlock
usermod -L mira       # same effect
usermod -U mira       # same effect
```

Locking puts a `!` in front of the hash. The password is not deleted; it becomes unusable. The account, its files, its groups, and its home directory are untouched.

!!! warning "A locked password is not a locked account"
    `passwd -l` blocks password authentication. It does **not** block SSH key authentication, and it does not stop a service from running as that user. To shut an account out completely, also set the shell to `/sbin/nologin` or set an account expiry date with `chage -E`. R10 covers the SSH side.

### Expiry, inactivity, and the three different "expired"

| Concept | Set with | Effect |
|---|---|---|
| Password expires | `chage -M days` | User must change their password at next login |
| Password inactive | `chage -I days` | After the password expires, the account is disabled this many days later |
| Account expires | `chage -E YYYY-MM-DD` | No login at all after this date, whatever the password |

A user whose password has expired can still log in — to change it. A user whose account has expired cannot.

### `chage`

```bash
chage -l devon
chage -M 90 devon          # maximum days between changes
chage -m 7 devon           # minimum days between changes
chage -W 14 devon          # warn this many days before expiry
chage -I 30 devon          # disable 30 days after the password expires
chage -E 2027-12-31 devon  # account expiry date
chage -d 0 devon           # force a change at next login
```

`chage -l` reports the values the way a human reads them:

```text
Last password change                                    : Nov 08, 2026
Password expires                                        : Feb 06, 2027
Password inactive                                       : Mar 08, 2027
Account expires                                         : Dec 31, 2027
Minimum number of days between password change          : 7
Maximum number of days between password change          : 90
Number of days of warning before password expires       : 14
```

`chage -d 0` sets the last-change date to 1970-01-01, which makes every password "expired". That is the standard way to onboard someone: give them a temporary password, force a change, and let them choose their own. `chage -l` then reports `password must be changed` instead of a date.

### Password quality

Aging does not make passwords strong. `/etc/security/pwquality.conf` does, through the PAM stack:

```bash
grep -v '^#' /etc/security/pwquality.conf | grep .
```

`minlen`, `dcredit`, and `ucredit` are the usual settings. The exam does not ask you to tune it, but you should recognise the file and know that it is applied by `pam_pwquality` when a password is set. `authselect` is the tool that manages the PAM profiles these rules live in.

---

## Privileged access with `sudo`

Two ways to gain another identity:

| | `su` | `sudo` |
|---|---|---|
| Password | The **target** user's | **Your own** |
| Authorization | Knowing the password | A rule in `sudoers` |
| Granularity | All or nothing | Per command, per host, per group |
| Audit | Weak | Every command is logged |
| Typical use | Become root on a console | Run one command as root |

`su -` starts a login shell as the target user. `sudo` runs a single command and returns. On a shared system, `sudo` is the right tool: it does not require sharing root's password and it leaves a record in the journal.

```bash
sudo systemctl restart sshd
sudo -u postgres psql
sudo -i                       # interactive root login shell
sudo -l                       # what may I run?
sudo -l -U devon              # what may devon run? (root only)
sudo -k                       # forget my cached credential
```

By default `sudo` remembers your password for five minutes **per terminal**. `sudo -k` clears it.

### How `sudoers` is organised

The main file is `/etc/sudoers`. It is mode `0440` and you do not edit it directly. It ends with:

```text
#includedir /etc/sudoers.d
```

The `#` here is part of the directive, not a comment: in the sudoers grammar that spelling means "include". AlmaLinux 10 uses it; newer sudo releases also accept `@includedir`.

Everything in `/etc/sudoers.d/` is read as part of the configuration. That is where your rules go. Files there must:

- be mode `0440` (or `0400`)
- be owned by root
- not contain a `.` in the name, and not end in `~` — those are ignored as editor leftovers

The RHEL default also contains:

```text
%wheel  ALL=(ALL)       ALL
```

That is why `labuser` is a member of `wheel`: it is the standard "full administrator" grant.

### The rule format

```text
who        where = (as_whom)  what
%operators ALL   = (root)     NOPASSWD: /usr/bin/systemctl status sshd
```

| Part | Meaning |
|---|---|
| `who` | A user, `%group`, `#uid`, or an alias |
| `where` | Hostname or `ALL` |
| `(as_whom)` | Which user the command may run as; `(ALL)` or `(root)` |
| `what` | Full path to the command, with optional arguments |
| `NOPASSWD:` | Skip the password prompt for that rule |

Rules are matched on the **exact command line**, including arguments. `NOPASSWD: /usr/bin/systemctl status sshd` allows `sudo systemctl status sshd` and nothing else — not `systemctl restart sshd`, and not `systemctl status nginx`. Wildcards exist (`/usr/bin/systemctl status *`) but they are easy to widen by accident.

A leading `!` denies a command. The last matching rule wins, so a deny placed before a broad allow is overridden by it — put the deny after the rule it is meant to restrict.

### Validate before you install

A syntax error anywhere in `sudoers` or `sudoers.d` breaks **every** `sudo` command, including the one you would use to fix it.

```bash
visudo -c                                    # check the whole configuration
visudo -cf /tmp/10-r2-operators              # check one candidate file
```

The safe workflow is: write the candidate in `/tmp`, check it, then install it with the right owner and mode.

```bash
cat > /tmp/10-r2-operators <<'EOF'
%operators ALL=(root) NOPASSWD: /usr/bin/systemctl status sshd
EOF
visudo -cf /tmp/10-r2-operators
install -m 0440 -o root -g root /tmp/10-r2-operators /etc/sudoers.d/10-r2-operators
visudo -c
```

!!! danger "If you lock yourself out"
    On the lab, `vagrant` has passwordless `sudo`, so you can always recover. On a real system the recovery path is the root password on the console, or a rescue boot — R11 covers that. This is why you validate with `visudo -cf` before moving a file into place.

### Proving a rule works

```bash
sudo -l -U devon
su - devon -c 'sudo -n systemctl status sshd'
su - devon -c 'sudo -n dnf update'      # should be refused
```

`sudo -n` means "never prompt". It turns "the command hung waiting for a password" into a clean failure, which is exactly what you want in a test.

---

## Default permissions: `umask`

`umask` is a per-process mask subtracted from the permissions a new file or directory would otherwise get.

| umask | New files (`666` minus mask) | New directories (`777` minus mask) |
|---|---|---|
| `022` | `644` | `755` |
| `027` | `640` | `750` |
| `077` | `600` | `700` |

It affects **new** objects only. Changing it never modifies files that already exist.

### Where to set it

The umask is inherited from parent process to child, so it depends on how a shell was started.

| Shell type | Files read | Typical place for a umask |
|---|---|---|
| Login shell (`su -`, console, SSH) | `/etc/profile`, `/etc/profile.d/*.sh`, `~/.bash_profile` | `/etc/profile.d/*.sh`, `~/.bash_profile` |
| Non-login interactive (`su`, new terminal tab) | `~/.bashrc`, `/etc/bashrc` | `~/.bashrc` |
| Service (systemd) | none of the above | `UMask=` in the unit, or `/etc/systemd/system.conf` |

The rule to remember: **`/etc/profile.d` is for login shells**. A umask placed only there will not apply to a systemd service (R5 covers `UMask=`).

```bash
# for one user, persistently, at login
echo 'umask 027' >> /home/devon/.bash_profile

# for every user, at login
cat > /etc/profile.d/99-umask.sh <<'EOF'
umask 027
EOF
chmod 0644 /etc/profile.d/99-umask.sh
```

!!! warning "A system-wide umask is a system-wide change"
    Setting `umask 027` in `/etc/profile.d` also applies to root. Files root creates by redirection during later modules become `640` instead of `644`, and a service running as another user may then be unable to read them. That is a real, confusing failure. The labs set the umask for one user only, and the theory is what the exam asks about.

Services ignore login profiles entirely. They get the umask from their unit file, which defaults to `0022` regardless of what `/etc/profile` says. Do not expect a service to inherit a shell setting — it never does.

### Verify with a login shell

A umask set in `~/.bash_profile` is only visible to a login shell. Running `umask` in your current root shell proves nothing.

```bash
su - devon -c 'umask'
# 0027

su - devon -c 'touch /tmp/f && mkdir /tmp/d && stat -c "%a %n" /tmp/f /tmp/d'
# 640 /tmp/f
# 750 /tmp/d
```

---

## Verification and persistence

Account data lives in files, so it survives a reboot by construction. What does **not** survive automatically is anything you set in a running shell: a `umask`, an exported variable, a `newgrp` subshell.

The commands that prove end state:

```bash
getent passwd devon
getent group developers
id devon
id -nG mira
passwd -S devon
chage -l devon
sudo -l -U devon
visudo -c
su - devon -c 'umask'
```

After a reboot, run the same list. If every line still says what you expect, the configuration is persistent. The checker does exactly this, which is why it can be run before or after a reboot and give the same answer.

---

## Exam lens

1. **`-aG`, not `-G`.** Adding a group means `usermod -aG`. Without `-a` you replace every supplementary group the user had.
2. **`userdel` keeps the home directory.** Only `-r` removes it, and even then only the home and mail spool — never files elsewhere.
3. **Orphaned UIDs.** A deleted user's files show a number and stay owned by that number. Reassign with `chown -R` before you recreate the account, or the new user may inherit old files by accident.
4. **Group membership is per session.** `id` in a new shell shows the truth. An old shell shows the old truth.
5. **Three kinds of expiry.** Password expiry (`-M`), password inactivity (`-I`), and account expiry (`-E`) are different settings with different effects.
6. **Lock ≠ disabled.** `passwd -l` blocks password login only. SSH keys still work.
7. **`sudoers.d` hygiene.** Mode `0440`, root-owned, no dot in the name, and validate with `visudo -cf` before installing.
8. **A broken drop-in breaks everything.** One syntax error in one file disables `sudo` for every user, not just the one you were editing.
9. **Exact command matching.** `sudo` rules match the full command line. `/usr/bin/systemctl status` does not allow `restart`.
10. **`umask` is per process.** Writing it in your current shell changes nothing permanently. Put it in the right profile file, and prove it from a login shell.

---

## Check yourself

<details>
<summary>1. Which file stores the password hash, and why is it not <code>/etc/passwd</code>?</summary>

`/etc/shadow`, which is mode `0000` and readable only by root. `/etc/passwd` must stay world-readable so that any program can turn a UID into a name, so the hash was moved out of it. The `x` in the passwd password field is the pointer.

</details>

<details>
<summary>2. A user is in the group <code>developers</code> as their primary group. Do they appear in the members list of <code>/etc/group</code>?</summary>

No. `/etc/group` lists supplementary members only. Primary-group membership is recorded as the GID field in `/etc/passwd`. `id user` shows both.

</details>

<details>
<summary>3. What is the difference between <code>usermod -G wheel devon</code> and <code>usermod -aG wheel devon</code>?</summary>

`-G` replaces the entire supplementary group list with `wheel`. `-aG` appends `wheel` to whatever the user already had. The second is almost always what you want.

</details>

<details>
<summary>4. You run <code>userdel contractor</code> with no options. What happens to <code>/home/contractor</code>?</summary>

It remains on disk. The passwd entry is gone, so `ls -l` shows the numeric UID instead of the name. `userdel -r` would have removed the home directory and mail spool.

</details>

<details>
<summary>5. Which <code>chage</code> options set the maximum password age, the warning period, and the account expiry date?</summary>

`-M` for maximum days between password changes, `-W` for the warning period, and `-E` for the account expiry date. Minimum is `-m`, and password inactivity is `-I`.

</details>

<details>
<summary>6. How do you force every user to choose a new password at their next login?</summary>

`chage -d 0 user`. That sets the last-change date to the epoch, so the password is considered expired. They can log in, but only to change it.

</details>

<details>
<summary>7. What does <code>passwd -l mira</code> actually block? What does it not block?</summary>

It prefixes the hash in `/etc/shadow` with `!`, so password authentication fails. It does not block SSH key authentication, existing sessions, or services running as that user. To disable the account fully, also set the shell to `/sbin/nologin` or set an expiry with `chage -E`.

</details>

<details>
<summary>8. Why must a file in <code>/etc/sudoers.d</code> be mode <code>0440</code> and owned by root?</summary>

`sudo` refuses to read a drop-in that any unprivileged user could modify, because that would be a trivial privilege escalation. It also ignores filenames containing a dot, which is how it skips editor backup files.

</details>

<details>
<summary>9. What is wrong with this rule: <code>%operators ALL=(root) NOPASSWD: /usr/bin/systemctl status</code>?</summary>

It probably does not do what the author intended. `sudo` matches the full command line, so it allows exactly `systemctl status` with no arguments and refuses `systemctl status sshd`. To allow arguments you would need `status *`, and then you have to think about what else that matches.

</details>

<details>
<summary>10. A user's <code>.bash_profile</code> contains <code>umask 027</code>. You run <code>umask</code> as root and see <code>0022</code>. Is the setting broken?</summary>

No. You are looking at root's shell, not the user's. `umask` is per process. Prove the user's setting from a login shell: `su - devon -c 'umask'` should print `0027`.

</details>

<details>
<summary>11. Where would you set a umask so that a systemd service respects it?</summary>

In the unit file with `UMask=`, or in `/etc/systemd/system.conf` for a global default. Services do not read `/etc/profile`, `~/.bash_profile`, or any shell startup file.

</details>

---

## Labs

Now do the work on the lab systems. These labs change real accounts, so start from the clean snapshot and expect to run the checker as root.

1. [Lab 1 — Accounts and groups](labs/lab-1-accounts-and-groups.md)
2. [Lab 2 — Passwords, policy, and sudo](labs/lab-2-password-policy-and-sudo.md)
3. [Challenge — Onboarding wave 2](labs/challenge-onboarding.md)

Then review the [knowledge check](quiz.md) and keep the [cheat sheet](cheatsheet.md) handy.
