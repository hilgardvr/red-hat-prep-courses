# F4 — Filesystem hierarchy and file operations

<div class="module-meta" markdown>

| | |
|---|---|
| **Time** | 60–75 minutes |
| **Prerequisites** | [F3](../f3-shell-help/index.md) |
| **Lab** | Build and inspect a directory tree on the lab `server` |
| **Self-check** | At the end of the page |

</div>

Linux presents one directory tree. Every disk, partition, network share, and virtual filesystem is attached somewhere inside that tree at a **mount point**. There are no `C:` drives and no separate roots per device.

That design explains most of the exam's file tasks. If you know what belongs in `/etc`, `/var`, and `/usr`, you know where a configuration file should go, why logs can fill a disk, and why moving a file can break a service. This module gives you the map and the operations.

## One tree

Start at the root and work down:

```bash
findmnt /
lsblk
df -hT
```

On the lab you will see the root filesystem on a virtio disk, mounted at `/`. The second disk, `/dev/vdb`, is present but unused; R6 partitions and mounts it. For now the point is structural: a device provides storage, a filesystem organizes it, and a mount point exposes it inside the single tree.

```text { .no-copy }
/            the root of everything
├── etc      configuration
├── var      data that changes: logs, spool, databases
├── usr      programs, libraries, documentation
├── home     user home directories
├── root     root's home, not under /home
├── tmp      scratch space, aged out by systemd-tmpfiles
└── ...
```

## The Filesystem Hierarchy Standard

RHEL follows the FHS. You do not need to memorize every directory, but you do need the big ones and the reason each exists.

| Path | Contains | Why it matters on the exam |
|---|---|---|
| `/` | Root of the tree | Full disks here break the system |
| `/etc` | Host-specific configuration | Almost every service task edits files here |
| `/var` | Variable data: logs, spools, caches, web content | Common cause of full disks |
| `/var/log` | Log files | Troubleshooting, auditing |
| `/usr` | Shareable, read-only program data: binaries, libraries, docs | `PATH` and library lookups |
| `/usr/bin`, `/usr/sbin` | User and administrative commands | Where most commands live |
| `/home` | Regular users' home directories | Permissions, SSH keys, quotas |
| `/root` | root's home directory | Not under `/home`, mode 700 |
| `/tmp` | Temporary files, world-writable with the sticky bit | Aged out by `systemd-tmpfiles`; never store real data |
| `/opt` | Optional add-on software | Third-party applications |
| `/srv` | Data served by this system | Web and FTP content by convention |
| `/boot` | Kernel and bootloader files | Never fill it; R11 works here |
| `/dev` | Device nodes | Disks appear as `/dev/vda`, `/dev/sda` |
| `/proc`, `/sys` | Kernel and hardware interfaces | Not on disk; read live state |
| `/run` | Runtime state since boot | PIDs, sockets, locks |
| `/mnt`, `/media` | Temporary and removable mount points | Where you mount things by hand |

Modern RHEL merges the old split directories into `/usr`. Check it:

```bash
ls -ld /bin /sbin /lib /lib64
```

```text { .no-copy }
lrwxrwxrwx. 1 root root 7 ... /bin -> usr/bin
lrwxrwxrwx. 1 root root 8 ... /sbin -> usr/sbin
lrwxrwxrwx. 1 root root 7 ... /lib -> usr/lib
lrwxrwxrwx. 1 root root 9 ... /lib64 -> usr/lib64
```

They are symlinks kept for compatibility. A path such as `/bin/bash` still works, but the real file is `/usr/bin/bash`. The exam accepts either; scripts should prefer `/usr/bin` when they hardcode paths.

### The rules behind the layout

Three distinctions explain most placement decisions:

- **Static versus variable.** Programs and libraries change only when packages change, so they live in `/usr` and can be mounted read-only. Logs, mail, spools, and databases change constantly, so they live in `/var`.
- **Shareable versus host-specific.** `/usr` can be shared between machines of the same architecture. `/etc` is specific to this host and is never shared.
- **Persistent versus runtime.** `/run` is a `tmpfs` in memory and is wiped at boot. `/tmp` is on the root filesystem and survives a reboot, but `systemd-tmpfiles` deletes files that have sat unused for ten days (`/var/tmp` gets thirty). Neither is a place for data you need later.

When the exam asks you to configure a service, you write to `/etc`. When it asks you to inspect state, you read `/var/log`, `/proc`, or `journalctl`. That mapping is the whole module in one sentence.

## Paths

An **absolute path** starts at `/` and means the same thing from anywhere:

```bash
cat /etc/hostname
```

A **relative path** depends on your current directory:

```bash
pwd
cd /var/log
pwd
ls
cd ..
pwd
```

```text { .no-copy }
/home/labuser
/var/log
/
```

Special path components:

| Component | Meaning |
|---|---|
| `.` | The current directory |
| `..` | The parent directory |
| `~` | Your home directory |
| `~labuser` | Another user's home directory |
| `-` | The previous directory, for `cd -` only |

```bash
cd /etc
cd /var/log
cd -
```

`cd -` returns to `/etc` and prints it. This is faster than typing long paths twice.

Names are case-sensitive: `Notes.txt` and `notes.txt` are different files. They may contain almost any character except `/` and NUL, including spaces and leading dashes. Both of those are legal and both cause trouble; quote names with spaces (F3) and use `--` before names that start with `-`.

Files whose names begin with `.` are **hidden** from plain `ls`. Most are configuration files in your home directory: `~/.bashrc`, `~/.ssh/`.

## Looking at files

`ls` is the primary inspection tool, but the options matter:

| Command | Effect |
|---|---|
| `ls -l` | Long format: type, permissions, links, owner, group, size, time, name |
| `ls -a` | Include hidden entries, including `.` and `..` |
| `ls -A` | Include hidden entries but not `.` and `..` |
| `ls -h` | Human-readable sizes with `-l` |
| `ls -d` | The directory itself, not its contents |
| `ls -i` | Inode number |
| `ls -t` | Newest first |
| `ls -S` | Largest first |
| `ls -R` | Recurse into subdirectories |
| `ls -l --time-style=long-iso` | Stable, sortable timestamps |

The long format is worth reading field by field:

```text { .no-copy }
-rw-r--r--. 1 labuser labuser 1024 Nov  7 09:14 notes.txt
```

| Field | Example | Meaning |
|---|---|---|
| Type and permissions | `-rw-r--r--` | Regular file; F6 explains the bits |
| Hard link count | `1` | Number of names pointing at the inode |
| Owner | `labuser` | The user who owns the file |
| Group | `labuser` | The group that owns the file |
| Size | `1024` | Bytes, unless `-h` |
| Modification time | `Nov 7 09:14` | Content change, not access |
| Name | `notes.txt` | The entry in the directory |

The first character of the type field tells you what you are looking at:

| Character | Type |
|---|---|
| `-` | Regular file |
| `d` | Directory |
| `l` | Symbolic link |
| `c` | Character device, such as `/dev/null` |
| `b` | Block device, such as `/dev/vda` |
| `s` | Socket |
| `p` | Named pipe |

Other tools answer different questions:

```bash
file /etc/hosts
stat /etc/hosts
wc -l /etc/services
head -n 5 /etc/services
tail -n 5 /etc/services
less /etc/services
```

`file` guesses the content type from the bytes, not the extension. `stat` prints three timestamps that beginners often confuse:

| Timestamp | Changes when |
|---|---|
| Access | The file is read (subject to `relatime` behavior) |
| Modify | The file's content changes |
| Change | The inode changes: permissions, owner, links, or content |

`less` is the right tool for long files: search with `/`, quit with `q`. `cat` is for short files; using it on a large log scrolls your screen and teaches you nothing.

## Creating, copying, moving, deleting

### Directories and empty files

```bash
mkdir -p ~/f4/{docs,logs,archive}
touch ~/f4/docs/a.txt
```

`mkdir -p` creates missing parents and succeeds if the directory already exists. Use it in scripts; without `-p`, an existing directory is an error.

`touch` creates an empty file or updates timestamps on an existing one.

### Copying

Run these from `~/f4`, the tree the previous block created:

```bash
cd ~/f4
cp docs/a.txt archive/
cp -v docs/a.txt archive/a-copy.txt
cp -a docs archive/docs-backup
```

| Option | Effect |
|---|---|
| `-r` / `-R` | Recurse into directories |
| `-a` | Archive mode: recursive plus preserve mode, ownership, timestamps, links, and SELinux context |
| `-p` | Preserve mode, ownership, and timestamps, without recursion |
| `-i` | Prompt before overwriting |
| `-v` | Show what is being copied |
| `-n` | Never overwrite an existing file |

`cp -a` is the right choice when duplicating configuration or web content, because it preserves both permissions and SELinux labels (F8 explains why losing the label breaks a service).

`cp file dir/` and `cp file dir` differ if `dir` does not exist: the first fails, the second creates a file named `dir`. When the destination is ambiguous, be explicit.

### Moving and renaming

Still in `~/f4`. The first line creates `docs/b.txt` so the rename has something to act on; `archive/a-copy.txt` is the file the `cp -v` line above made:

```bash
printf 'beta\n' > docs/b.txt
mv docs/b.txt docs/b.bak
mv archive/a-copy.txt archive/a-old.txt
```

`mv` does two different things depending on the destination:

- **Same filesystem:** it renames the directory entry. The inode, content, permissions, and SELinux context are unchanged. This is fast and atomic.
- **Different filesystem:** it copies the content and deletes the source. The result gets a new inode, and some attributes depend on the copy implementation.

That distinction matters on the exam. Moving a file into a directory does not always give it the label the service expects (F8 and R10).

### Deleting

Still in `~/f4`:

```bash
mkdir -p archive/emptydir    # rmdir needs a directory, and it must be empty
rmdir archive/emptydir
rm docs/b.bak
rm -r archive/docs-backup     # recurse
```

`rmdir` refuses a directory with anything in it, which is a useful safety property: it can only ever remove an empty one. `rm -r` removes a tree, and `rm -rf` adds "stop asking".

Linux has no recycle bin. `rm` unlinks the name; when the last name and open file descriptors are gone, the data is gone.

`rm -rf` deserves respect:

- Test the glob first with `ls` or `echo`.
- Quote variables and guard them:

    ```bash
    mkdir -p ~/f4/scratch
    target="$HOME/f4/scratch"
    rm -rf "${target:?}"
    ```

    `${target:?}` makes the shell abort if the variable is empty or unset. The target here is a scratch directory, so the example is safe to run; the pattern is what matters.
- Never run it from `/` with a trailing wildcard you have not inspected.

### `install` for precise results

`install` copies a file and sets mode and ownership in one step, which is why scripts and lab checkers use it:

```bash
sudo install -o labuser -g labuser -m 640 /dev/null /srv/f4-example.txt
ls -l /srv/f4-example.txt
```

```text { .no-copy }
-rw-r----- 1 labuser labuser 0 Nov  7 09:40 /srv/f4-example.txt
```

`install -d` creates a directory with explicit permissions, avoiding a second `chmod`.

## Finding files

`find` walks the tree and evaluates tests. The general form is:

```text { .no-copy }
find [where] [tests] [actions]
```

| Test | Meaning |
|---|---|
| `-name '*.conf'` | Match the basename, case-sensitive |
| `-iname '*.conf'` | Case-insensitive match |
| `-type f` / `-type d` / `-type l` | Regular file / directory / symlink |
| `-size +10M` | Larger than 10 MB; `-size -1k` smaller than 1 KB |
| `-mtime -1` | Content modified within the last day |
| `-mmin -10` | Content modified within the last 10 minutes |
| `-user labuser` | Owned by a user |
| `-perm 0644` | Exact permission match; `-perm -u+w` has the bit |
| `-maxdepth 1` | Do not descend further |
| `-empty` | Empty file or directory |

Actions:

| Action | Effect |
|---|---|
| `-print` | Print the path; the default |
| `-ls` | Long listing, like `ls -l` |
| `-delete` | Delete each match |
| `-exec command {} \;` | Run a command once per match |
| `-exec command {} +` | Run a command with many matches at once |

Useful examples:

```bash
find /etc -maxdepth 1 -name '*.conf'
find /var/log -type f -mtime -1
find /usr/share/doc -maxdepth 2 -iname '*readme*'
find ~/f4 -type f -name '*.txt' -exec wc -l {} +
```

Always run a destructive `find` once without `-delete` to see what it would remove:

```bash
find /tmp -maxdepth 1 -name 'f4-*' -print
find /tmp -maxdepth 1 -name 'f4-*' -delete
```

`locate` is faster but needs a database built by `updatedb`, and it is not installed by default:

```bash
command -v locate || echo "locate not installed"
```

On the exam, do not count on `locate`. Use `find` and `grep -r` (F5).

## Links, briefly

A **hard link** is another name for the same inode. A **symbolic link** is a small file containing a path to another name.

```bash
cd ~/f4
printf 'alpha\n' > docs/a.txt
ln docs/a.txt hard.txt
ln -s docs/a.txt soft.txt
ls -li docs/a.txt hard.txt soft.txt
```

The hard link shares the inode number and the link count becomes 2. The symlink has its own inode, a different size, and an arrow in `ls -l`.

Delete the original and observe:

```bash
rm docs/a.txt
cat hard.txt    # still works: the inode has another name
cat soft.txt    # fails: the path in the link is gone
```

```text { .no-copy }
alpha
cat: soft.txt: No such file or directory
```

R1 Lab 1 works through links in exam detail. For now keep the rule: hard links cannot cross filesystems and cannot point at directories; symlinks can do both, but break if the target moves.

## `/proc` and `/sys` are not files

These directories look like files but are generated by the kernel on access. Nothing there occupies disk space, and writing to the wrong place can change live kernel state.

```bash
head -n 3 /proc/cpuinfo
head -n 3 /proc/meminfo
cat /proc/version
ls /sys/class/net
cat /proc/sys/kernel/hostname
```

`/proc/sys` is the runtime kernel parameter interface. F8 touches it; R5 and R9 use it deliberately.

## Lab: build and inspect a tree

Log in to `server` and switch to the lab user:

```bash
sudo su - labuser
```

### 1. Build the tree

```bash
mkdir -p ~/f4/{docs,logs,archive}
cd ~/f4
printf 'alpha\n' > docs/a.txt
printf 'beta\n' > docs/b.txt
cp docs/a.txt archive/
mv docs/b.txt docs/b.bak
ls -lR
```

You should see two directories under `docs` and a copy in `archive`. Note that `mv` inside the same filesystem kept the inode:

```bash
ls -li docs
```

### 2. Inspect metadata

```bash
stat docs/a.txt
file docs/a.txt
ls -lh archive/a.txt
```

Read all three timestamps from `stat` and say which one changes when you run `chmod 600 archive/a.txt`.

### 3. Find things

```bash
find ~/f4 -name '*.txt'
find ~/f4 -type f -name '*.bak'
find /etc -maxdepth 1 -name '*.conf' | wc -l
find /etc -maxdepth 1 -name '*.conf' | sort | head -5
```

The count differs between systems. The skill is in building a narrow query instead of scanning all of `/`.

### 4. Explore a system directory

```bash
du -sh /usr/share/doc
du -sh /var/log
ls /var/log
```

`du` reports disk usage by walking the tree. If `/var/log` is unexpectedly large, that is a finding worth investigating, not a command to memorize.

As an ordinary user, `du -sh /var/log` also prints `du: cannot read directory ...: Permission denied` for a few subdirectories such as `/var/log/audit` and `/var/log/private`. The total it reports is smaller than the real one for that reason. `sudo du -sh /var/log` walks the whole tree.

### 5. Link and unlink

```bash
cd ~/f4
ln docs/b.bak hard.bak
ln -s docs/b.bak soft.bak
ls -li docs/b.bak hard.bak soft.bak
rm docs/b.bak
cat hard.bak
cat soft.bak
```

Confirm the hard link still has content and the symlink is broken. Then remove the broken link:

```bash
rm soft.bak
```

### 6. Look at live kernel data

```bash
head -n 2 /proc/meminfo
ls /sys/class/net
cat /proc/sys/kernel/hostname
```

Compare the last command with `hostname`. They agree because both read the same kernel value.

### 7. Clean up

```bash
cd ~
rm -rf ~/f4
sudo rm -f /srv/f4-example.txt
```

## Common traps

| Trap | What happens | Fix |
|---|---|---|
| `rm -rf $VAR/` with `VAR` unset | Expands to `rm -rf /` | Quote and use `${VAR:?}` |
| `cp` instead of `cp -a` for web or config content | Ownership, permissions, or SELinux labels are lost | `cp -a` or `install` with explicit mode |
| `cp file dir` when `dir` is missing | Creates a file named `dir` | Create the directory first or use `cp -t dir` |
| Editing `/etc` files with `echo >` | Loses comments and can race with the service | Edit with `vim`, or add a drop-in file in `.d/` |
| `find / -name ...` | Slow, and noisy with permission errors | Narrow the path; add `-maxdepth` |
| Trusting `locate` | Database is absent or stale | Use `find` |
| Filling `/tmp` or `/` | Services fail; the system can become unusable | Watch `df -h`, clean old files |
| Deleting a file that is still open | Space is not freed until the process closes it | Restart the process; check with `lsof +L1` |

## Self-check

Answer first, then open the answer.

### 1. One tree

Why does Linux not have drive letters?

??? question "Answer"
    The kernel exposes every filesystem through the same directory tree. A device is mounted at a mount point, so `/`, `/home`, and `/var` can live on different disks while applications still see one namespace.

### 2. Placement

Where does a service's configuration belong, and where do its logs belong?

??? question "Answer"
    Configuration goes in `/etc`, which is host-specific and static. Logs go under `/var/log`, which is variable data. Unit files live in `/usr/lib/systemd/system` (packaged) or `/etc/systemd/system` (local).

### 3. Absolute and relative

You are in `/var/log` and run `cd ../../etc`. Where are you?

??? question "Answer"
    In `/etc`. `..` from `/var/log` is `/var`, and a second `..` is `/`, then `etc` gives `/etc`.

### 4. `ls -l` fields

In `-rw-r--r--. 1 labuser labuser 1024 Nov 7 09:14 notes.txt`, what does the `1` mean, and what does the leading `-` mean?

??? question "Answer"
    The `1` is the hard link count: one directory entry points at this inode. The leading `-` means it is a regular file, not a directory or device.

### 5. Timestamps

You change a file's permissions with `chmod` but not its content. Which `stat` timestamp changes?

??? question "Answer"
    The change time, `ctime`. It records inode changes such as mode, ownership, and link count. The modification time, `mtime`, records content changes, and the access time, `atime`, records reads.

### 6. Copy versus move

Why can `mv` a file into `/var/www/html` break a web service even though the content is identical?

??? question "Answer"
    Within the same filesystem, `mv` renames the existing inode and keeps its SELinux context. If the file came from `/root` or `/tmp`, it keeps a type the web server is not allowed to read. `cp` creates a new file in the destination directory, which inherits that directory's default context. R10 covers the fix with `restorecon` and `semanage fcontext`.

### 7. `find` safety

Why should you run `find ... -print` before the same command with `-delete`?

??? question "Answer"
    `-delete` acts on every match, and a pattern that is broader than you expected can remove live data. Printing first shows exactly which paths match. The same habit applies to `rm` with a glob.

### 8. Hard and symbolic links

You delete a file that has one hard link and one symlink pointing at it. What happens when you read each link?

??? question "Answer"
    The hard link still returns the content, because both names refer to the same inode and the data survives until the last link is gone. The symlink is now dangling and fails with "No such file or directory".

### 9. `/proc`

Does `/proc/meminfo` consume disk space? Why or why not?

??? question "Answer"
    No. `/proc` is a virtual filesystem generated by the kernel when a process reads it. The values reflect live kernel state, not stored bytes.

## Next

Continue to [F5 — Streams, pipes, and text processing](../f5-streams-text/index.md), where you connect commands together and search their output precisely.

You can also start [R1 — Essential tools](../../rhcsa/r01-essential-tools/index.md) now; it assumes the shell and filesystem basics covered so far.
