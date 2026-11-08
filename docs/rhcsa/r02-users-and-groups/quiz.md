# R2 knowledge check

Answer first, then open the answer. If you miss a question, return to the matching section of the [theory page](index.md).

### 1. The account files

Which file holds the password hash, and why is it not `/etc/passwd`?

??? question "Answer"
    `/etc/shadow`, which is mode `0000` and readable only by root. `/etc/passwd` must stay world-readable so any program can map a UID to a name, so the hash was moved into a separate file. The `x` in the passwd password field points there.

### 2. Primary group

A user's primary group is `developers`. Does their name appear in the member list of `/etc/group`?

??? question "Answer"
    No. `/etc/group` lists supplementary members only. Primary-group membership is recorded as the numeric GID in `/etc/passwd`. `id user` shows both.

### 3. Adding a group

What is the difference between `usermod -G wheel devon` and `usermod -aG wheel devon`?

??? question "Answer"
    `-G` replaces the entire supplementary group list with `wheel`. `-aG` appends `wheel` and leaves the other groups alone. Omitting `-a` is the most common way to silently remove a user from groups they needed, including their own sudo access.

### 4. Deleting a user

You run `userdel contractor` with no options. What happens to `/home/contractor` and the files inside it?

??? question "Answer"
    They stay on disk, unchanged. Only the account entry is removed. `ls -l` then shows the numeric UID instead of a name. `userdel -r` would remove the home directory and the mail spool, but nothing else on the filesystem.

### 5. Orphaned ownership

Why is it dangerous to recreate a deleted user's account before dealing with their files?

??? question "Answer"
    The new account may be assigned the same UID, in which case it silently inherits ownership of everything the old user left behind — including files in `/tmp` or in shared directories. Check for orphaned files with `find / -uid N` and reassign them with `chown` before recycling the number.

### 6. Aging options

Which `chage` options set the maximum password age, the minimum password age, the warning period, the password inactivity period, and the account expiry date?

??? question "Answer"
    `-M` maximum, `-m` minimum, `-W` warning, `-I` inactivity, `-E` account expiry. `-M` expires the password, so the user can still log in to change it. `-E` expires the whole account.

### 7. Forcing a change

How do you force a user to choose a new password at their next login?

??? question "Answer"
    `chage -d 0 user`. That sets the last-change date to 1970-01-01, so the password is older than any maximum. `chage -l` reports `password must be changed`. The user can log in, but only to run `passwd`.

### 8. Locking

What does `passwd -l mira` block, and what does it not block?

??? question "Answer"
    It prefixes the shadow hash with `!`, so password authentication fails. It does not block SSH key authentication, existing sessions, or a service running as that user. For a full suspension, also set the shell to `/sbin/nologin` or set `chage -E`.

### 9. sudoers drop-ins

Why must a file in `/etc/sudoers.d` be mode `0440` and root-owned, and why must its name avoid a dot?

??? question "Answer"
    `sudo` refuses to read a drop-in that an unprivileged user could modify — otherwise the rule would be a privilege-escalation path. It ignores filenames containing a `.`, which is how it skips editor backups like `10-r2-operators~` or `10-r2-operators.bak`.

### 10. sudo command matching

Why does `%operators ALL=(root) NOPASSWD: /usr/bin/systemctl status` not let a user run `systemctl status sshd`?

??? question "Answer"
    `sudo` matches the full command line, including arguments. The rule allows exactly `systemctl status` with no arguments. To allow arguments you would need a wildcard such as `status *`, and then you have to think about what else that matches.

### 11. Validating sudoers

What is wrong with editing `/etc/sudoers` directly with `vim`?

??? question "Answer"
    A syntax error disables `sudo` for every user, including the account you would use to fix it. Use `visudo`, which locks the file and validates on save, or write a candidate in `/tmp`, check it with `visudo -cf`, and install it. `visudo -c` validates the whole configuration, drop-ins included.

### 12. umask scope

A user's `.bash_profile` contains `umask 027`, but `umask` in your root shell prints `0022`. Is the setting broken?

??? question "Answer"
    No. The umask is a per-process attribute inherited from the parent. Your root shell never read that file. Prove the user's setting from a login shell: `su - devon -c 'umask'` should print `0027`.

### 13. Services and umask

Where would you set a umask so that a systemd service respects it?

??? question "Answer"
    In the unit file with `UMask=`, or globally in `/etc/systemd/system.conf`. Services do not read `/etc/profile`, `/etc/profile.d`, `~/.bash_profile`, or any other shell startup file.

### 14. System accounts

You run `useradd -r -d /var/lib/buildbot -s /sbin/nologin buildbot`. Why is `/var/lib/buildbot` missing afterwards?

??? question "Answer"
    `-r` creates a system account and does not create a home directory, even when `CREATE_HOME` is enabled in `/etc/login.defs`. Add `-m` explicitly if the service account needs one.
