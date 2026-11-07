# F6 — Users, permissions, and ownership

<div class="module-meta" markdown>

| | |
|---|---|
| **Time** | 75–90 minutes |
| **Prerequisites** | [F4](../f4-filesystem-operations/index.md) and [F5](../f5-streams-text/index.md) |
| **Lab** | Change modes and test access as different users on `server` |
| **Self-check** | At the end of the page |

</div>

Every exam task happens as some user. A service file must be readable by the service account, a web directory must be writable by the right group, and a home directory must not be readable by everyone. If you cannot predict the result of a `chmod`, you are guessing.

This module teaches the model behind the nine permission characters. R2 covers creating users and groups, password aging, and `sudo` configuration; here the goal is to read and control access.

## Identity

Linux identifies a user by a numeric **UID** and a group by a numeric **GID**. Names exist for humans; the kernel checks numbers.

```bash
id
id -nG
whoami
getent passwd labuser
getent group wheel
```

```text
uid=1000(labuser) gid=1000(labuser) groups=1000(labuser),10(wheel)
labuser wheel
labuser
labuser:x:1000:1000::/home/labuser:/bin/bash
wheel:x:10:labuser
```

`id` shows the primary group and every supplementary group. Group membership is decided at login; adding a user to a group does not affect sessions that already exist.

### Where the accounts live

| File | Contains | Who can read it |
|---|---|---|
| `/etc/passwd` | Username, UID, GID, comment, home, shell | Everyone |
| `/etc/shadow` | Password hash and aging fields | root only |
| `/etc/group` | Group name, GID, member list | Everyone |
| `/etc/gshadow` | Group password and administrators | root only |

The fields in `/etc/passwd` are positional:

```text
labuser:x:1000:1000::/home/labuser:/bin/bash
   |    |  |    |   |       |          |
   |    |  |    |   |       |          +-- login shell
   |    |  |    |   |       +------------- home directory
   |    |  |    |   +--------------------- GECOS comment
   |    |  |    +------------------------- primary GID
   |    |  +------------------------------ UID
   |    +--------------------------------- password placeholder, "x" means see shadow
   +-------------------------------------- username
```

The `x` is not the password. The real hash lives in `/etc/shadow`, which is why an unprivileged user can read the account list but not the hashes. As root:

```bash
sudo grep '^labuser:' /etc/shadow
```

The second field is a salted hash, not encrypted text that can be reversed. You will see a value beginning with `$y$` on current RHEL-family releases.

### UID ranges

| Range | Used for |
|---|---|
| 0 | root |
| 1–999 | System accounts and services |
| 1000+ | Regular human users |

`labuser` is in the regular range for this reason. Services such as `sshd` and `chrony` run as system accounts with no login shell, which limits the damage if the service is compromised.

### Changing identity for a test

R2 creates accounts. For this module you only need to *become* someone else temporarily:

```bash
sudo -u vagrant id
sudo -u vagrant cat /etc/shadow
```

The second command fails, which is exactly the point: `sudo` here is a testing tool for access control, not a way to bypass it. `sudo -l` lists what you may run.

## The permission model

Each file has an owner, a group, and a set of permission bits. The bits are split into three classes:

| Class | Applies to |
|---|---|
| User (owner) | The UID that owns the file |
| Group | Members of the file's group |
| Other | Everyone else |

Each class has three bits:

| Bit | On a file | On a directory |
|---|---|---|
| `r` | Read the content | List the names of entries |
| `w` | Change the content | Create, delete, or rename entries |
| `x` | Execute the file as a program | Enter and traverse the directory |

The directory column is where beginners lose points. `r` on a directory does not let you open its files, and `w` without `x` lets you create nothing. Traversal requires `x` on *every* directory in the path.

Read the long listing from F4 again:

```text
-rw-r--r--. 1 labuser labuser 1024 Nov  7 09:14 notes.txt
```

| Position | Meaning |
|---|---|
| 1 | File type: `-`, `d`, `l`, ... |
| 2–4 | Owner: `rw-` |
| 5–7 | Group: `r--` |
| 8–10 | Other: `r--` |
| 11 | `.` means an SELinux context is present (F8) |

### Octal notation

Each class is one octal digit, built by adding 4 for read, 2 for write, and 1 for execute.

| Octal | Bits | Meaning |
|---|---|---|
| 0 | `---` | None |
| 1 | `--x` | Execute only |
| 2 | `-w-` | Write only |
| 3 | `-wx` | Write and execute |
| 4 | `r--` | Read only |
| 5 | `r-x` | Read and execute |
| 6 | `rw-` | Read and write |
| 7 | `rwx` | All |

So `640` is `rw-` for the owner, `r--` for the group, and `---` for everyone else:

```bash
chmod 640 notes.txt
ls -l notes.txt
```

```text
-rw-r----- 1 labuser labuser 1024 Nov  7 09:14 notes.txt
```

### Symbolic notation

Symbolic mode is easier to reason about when you change one thing:

```text
chmod [who][operator][permissions] file
```

| Part | Values |
|---|---|
| Who | `u` owner, `g` group, `o` other, `a` all |
| Operator | `+` add, `-` remove, `=` set exactly |
| Permissions | `r`, `w`, `x`, and `X` (execute only if it makes sense) |

```bash
chmod u+x script.sh
chmod go-w notes.txt
chmod g=u report.txt
chmod a+r /srv/public
```

`chmod -R` recurses. It is convenient and dangerous: a recursive change applies to every file and subdirectory, including ones where the bits meant something different.

### `umask`: the default permissions

New files do not start at `777`. The kernel starts files at `666` and directories at `777`, then subtracts the **umask**:

```bash
umask
touch newfile
mkdir newdir
ls -ld newfile newdir
```

With umask `022`:

```text
-rw-r--r-- 1 labuser labuser 0 ... newfile
drwxr-xr-x 2 labuser labuser 6 ... newdir
```

| Base | Umask | Result |
|---|---|---|
| 666 (file) | 022 | 644 |
| 777 (dir) | 022 | 755 |
| 666 (file) | 077 | 600 |
| 777 (dir) | 077 | 700 |

`umask` affects only newly created files. Changing it does not modify existing ones, and a shell's umask does not change another user's or a service's umask. R2 and R5 cover where to set it permanently.

### Ownership

```bash
chown labuser:labuser notes.txt
chown -R labuser:labuser /srv/project
chgrp wheel notes.txt
ls -l notes.txt
```

- Only root can give a file to another user. An owner may change the group, but only to a group they belong to.
- `chown` follows symbolic links by default; `chown -h` changes the link itself.
- Every file has exactly one owner and one group. ACLs extend this without changing the basic model.

`install` is often cleaner than create-then-chown:

```bash
sudo install -o labuser -g labuser -m 640 /dev/null /srv/f6-owned.txt
```

### Special bits, briefly

The fourth octal digit and three extra letters cover special cases:

| Bit | Octal | Effect | Example |
|---|---|---|---|
| setuid | 4000 | Run as the file's owner | `/usr/bin/passwd` |
| setgid | 2000 | Run as the file's group; on a directory, new files inherit the group | shared project directories |
| sticky | 1000 | Only the owner may delete entries in the directory | `/tmp` |

They appear in `ls -l` as `s`, `S`, `t`, or `T` in place of the execute bit:

```bash
ls -l /usr/bin/passwd
ls -ld /tmp
```

```text
-rwsr-xr-x. 1 root root ... /usr/bin/passwd
drwxrwxrwt. 1 root root ... /tmp
```

The lowercase `s` and `t` mean the execute bit is also set; uppercase means it is not. The current exam objectives include basic special-permission awareness, but do not turn setuid into a habit. R2 covers the exam's user and group tasks, and R10 covers the security side.

### Why "permission denied" happens

Work through this checklist in order. Usually the answer is in the first three lines.

1. **Who are you?** `id` confirms your UID and groups.
2. **What are the bits?** `ls -l` shows mode, owner, and group.
3. **Can you traverse the path?** `namei -l /path/to/file` prints the permissions of every component.
4. **Is an ACL involved?** `getfacl file` shows extra entries.
5. **Is SELinux involved?** `ls -Z` and the journal (F8). SELinux denials look like ordinary permission errors.
6. **Is the filesystem read-only?** `findmnt -no OPTIONS /mountpoint` for `ro`.
7. **Is the file immutable?** `lsattr file` shows `i`; only root can set or clear it.

`namei` is the tool most people do not know and should:

```bash
namei -l /home/labuser/f6/file.txt
```

```text
f: /home/labuser/f6/file.txt
drwxr-xr-x root    root    /
drwxr-xr-x root    root    home
drwx------ labuser labuser labuser
drwxr-xr-x labuser labuser f6
-rw------- labuser labuser file.txt
```

The `700` home directory is why another user cannot reach a file inside it, even when the file itself is world-readable.

## Lab: predict, then test

Log in to `server` and become the lab user:

```bash
sudo su - labuser
mkdir -p ~/f6 && cd ~/f6
```

### 1. Inspect your identity

```bash
id
id -nG
getent passwd labuser
sudo grep '^labuser:' /etc/shadow
```

Name every group you belong to. Then confirm that the shadow hash is not the password: it begins with `$` and is unreadable without `sudo`.

### 2. Change modes on a file

```bash
echo secret > file.txt
ls -l file.txt
chmod 600 file.txt
ls -l file.txt
chmod go+r file.txt
ls -l file.txt
chmod u+x file.txt
ls -l file.txt
chmod 640 file.txt
ls -l file.txt
```

Read the mode back in words after each change: owner read/write, group read, other nothing. Try to execute it:

```bash
./file.txt
```

The kernel refuses with "Permission denied" or "Exec format error" because there is no interpreter line. The execute bit is necessary but not sufficient.

### 3. Test access as another user

```bash
sudo -u vagrant cat /home/labuser/f6/file.txt
```

Access is denied because `/home/labuser` is `700`. Confirm with `namei`:

```bash
namei -l /home/labuser/f6/file.txt
```

Now grant traversal on the home directory only, and test again:

```bash
chmod o+x /home/labuser
sudo -u vagrant cat /home/labuser/f6/file.txt
```

The file is `640` and `vagrant` is not in group `labuser`, so this still fails, but for a different reason. Change the file to `644`:

```bash
chmod 644 file.txt
sudo -u vagrant cat /home/labuser/f6/file.txt
```

It works. Restore both:

```bash
chmod 600 file.txt
chmod 700 /home/labuser
```

That sequence is the whole model in one exercise: directory traversal, then file bits, then group membership.

### 4. Use a group

Create a file owned by root with group `labuser` and mode `640`:

```bash
sudo install -o root -g labuser -m 640 /dev/null /srv/f6-group.txt
echo "group data" | sudo tee /srv/f6-group.txt
ls -l /srv/f6-group.txt
```

As `labuser`, read it through the group bits. As `vagrant`, it is denied:

```bash
cat /srv/f6-group.txt
sudo -u vagrant cat /srv/f6-group.txt
```

If you are not in the group, the group bits do not apply, and "other" takes over.

### 5. Watch the umask

```bash
umask
touch before.txt
mkdir before-dir
ls -ld before.txt before-dir
umask 077
touch after.txt
mkdir after-dir
ls -ld after.txt after-dir
```

The new entries are `600` and `700`. Existing entries are unchanged. Set the umask back:

```bash
umask 022
```

### 6. Directory permissions

```bash
mkdir shared
chmod 644 shared
ls -ld shared
cd shared
```

`cd` fails even though you own the directory and can read it: without `x` you cannot traverse. Restore it:

```bash
chmod 755 shared
cd shared
cd ..
```

### 7. Look at the special bits

```bash
ls -l /usr/bin/passwd
ls -ld /tmp
```

`passwd` is setuid root, which is how an ordinary user can update `/etc/shadow`. `/tmp` is sticky, which is why users cannot delete each other's files there even though the directory is world-writable. Try it if you like:

```bash
touch /tmp/labuser-file
sudo -u vagrant rm -f /tmp/labuser-file
```

The sticky bit blocks the delete.

### 8. Clean up

```bash
cd ~
rm -rf ~/f6
sudo rm -f /srv/f6-group.txt /srv/f6-owned.txt
chmod 700 /home/labuser
```

## Common traps

| Trap | What happens | Fix |
|---|---|---|
| `chmod 777` to "make it work" | Every user can modify the file | Grant only the class that needs access |
| `chmod -R` on a project root | Directories lose `x`, or scripts gain it unnecessarily | Use `find` with `-type f` or `-type d` and separate modes |
| Forgetting directory traversal | A readable file is still unreachable | Check `namei -l`; add `x` where needed |
| Expecting `w` alone to let you create files | Creation needs `w` and `x` on the directory | Set at least `wx` |
| Changing the umask for one user and expecting system-wide effect | Umask is per process and per login | Set it in the right profile or unit file |
| `chown` as a normal user | Operation not permitted | Use `sudo`; R2 covers delegation |
| Confusing SELinux with permissions | `ls -l` looks correct but access fails | Check `ls -Z` and the audit log (F8) |
| Assuming group changes apply immediately | Existing sessions keep old group membership | Log out and back in, or use `newgrp` |

## Self-check

Answer first, then open the answer.

### 1. Reading a mode

What does `chmod 640 report.txt` allow?

??? question "Answer"
    The owner can read and write. Members of the file's group can read. Everyone else has no access.

### 2. Directory bits

A directory is mode `644` and owned by you. Can you `cd` into it? Can you list its names?

??? question "Answer"
    You can list the names because `r` is set, but you cannot `cd` into it or access entries inside because `x` is missing. Without `x`, you cannot traverse.

### 3. Path traversal

A file is mode `644`, but other users get "Permission denied". Give two likely causes.

??? question "Answer"
    A parent directory is missing the `x` bit for those users, most commonly a `700` home directory. Or SELinux is denying access even though the classic bits allow it.

### 4. `umask`

With umask `027`, what modes do a new file and a new directory get?

??? question "Answer"
    The file starts at `666`, and `027` removes group write and all other bits, giving `640`. The directory starts at `777`, giving `750`.

### 5. Ownership rules

Can `labuser` give a file to `vagrant` with `chown`? Can `labuser` change the group to `wheel`?

??? question "Answer"
    Only root can change the owner to another user, so the first needs `sudo`. An owner may change the group, but only to a group they belong to; `labuser` is in `wheel`, so that change is allowed without root.

### 6. Group bits

A file is owned by `root:labuser` with mode `0640`. `labuser` is in group `labuser`, and `vagrant` is not. Who can read it?

??? question "Answer"
    `root` reads as owner, `labuser` reads through the group bits, and `vagrant` falls into "other", which has no permissions. Note that the owner class matches on UID, not on group membership.

### 7. Special bits

Why can an ordinary user run `passwd` and update `/etc/shadow`, which they cannot write?

??? question "Answer"
    `/usr/bin/passwd` is setuid root. When it runs, the process has root's effective UID and can write the shadow file, but only through the logic the program implements.

### 8. Sticky bit

Why can two users both create files in `/tmp` but not delete each other's files?

??? question "Answer"
    `/tmp` is mode `1777`: world-writable with the sticky bit. The sticky bit restricts deletion and renaming to the file's owner, the directory's owner, or root.

### 9. `namei`

You have checked the file and its immediate directory, and the bits look correct. What does `namei -l` add?

??? question "Answer"
    It shows the permissions of every component of the path from `/` down, so you can spot a directory in the middle that blocks traversal.

## Next

Continue to [F7 — Processes, systemd, and logs](../f7-processes-systemd/index.md), where you learn what is actually running, how services are started and enabled, and where the system records what happened.
