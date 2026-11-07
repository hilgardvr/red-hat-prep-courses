# R1 knowledge check

Answer first, then open the answer. If you miss a question, return to the matching section of the [theory page](index.md).

### 1. Command syntax

What is the difference between `ls -l /var/log` and `ls -l/var/log`?

??? question "Answer"
    `ls -l /var/log` passes two arguments: the option `-l` and the path `/var/log`. `ls -l/var/log` passes one argument, `-l/var/log`, which is not a valid option. Whitespace separates arguments; it is not optional.

### 2. Quoting

What does `echo '$HOME'` print, and why?

??? question "Answer"
    It prints the literal text `$HOME`. Single quotes prevent variable expansion. `echo "$HOME"` would print the value of the variable.

### 3. Exit status

You run `mkdir /srv/app && cd /srv/app`. The `mkdir` fails because `/srv/app` already exists. What happens to `cd`?

??? question "Answer"
    It does not run. `&&` executes the second command only if the first returns exit status 0. Use `mkdir -p /srv/app && cd /srv/app` if an existing directory is acceptable.

### 4. man sections

What is the difference between `man 1 passwd` and `man 5 passwd`?

??? question "Answer"
    Section 1 documents the `passwd` command. Section 5 documents the `/etc/passwd` file format. The same name can exist in multiple sections; the section number selects the page.

### 5. Hard links

You create `/data/file` and `ln /data/file /tmp/file-link`. Why does the second command fail if `/data` and `/tmp` are different filesystems?

??? question "Answer"
    A hard link is a second directory entry for the same inode. Inodes are unique within a filesystem, so a hard link cannot cross filesystem boundaries. Use a symbolic link (`ln -s`) instead.

### 6. Symlinks

You create `ln -s /etc/hosts /tmp/hosts-link`, then delete `/etc/hosts`. What happens to `/tmp/hosts-link`?

??? question "Answer"
    The symlink remains but becomes dangling: it still contains the path `/etc/hosts`, and any attempt to use it fails with "No such file or directory". The link file itself is not removed.

### 7. Permissions

A directory is mode `750`, owned by `labuser:labuser`. A file inside it is mode `644`. Can user `vagrant` read the file? Why or why not?

??? question "Answer"
    No. `vagrant` is "other" for the directory and has no `x`, so it cannot traverse the directory to reach the file. The file's `644` mode is irrelevant without directory execute permission.

### 8. umask

With `umask 027`, what mode does a newly created directory receive?

??? question "Answer"
    `750`. Directories start from `777`; subtracting `027` leaves `750` (`rwxr-x---`).

### 9. Redirection

Explain the difference between these two commands:

```bash
command > out.txt 2>&1
command 2>&1 > out.txt
```

??? question "Answer"
    The first sends both stdout and stderr to `out.txt`. The second sends stderr to the terminal (where stdout originally pointed) and stdout to `out.txt`. Redirections are evaluated left to right.

### 10. Pipes

What does `grep ERROR app.log | tee errors.txt | wc -l` do?

??? question "Answer"
    It filters `app.log` for lines containing `ERROR`, writes those lines to both the terminal and `errors.txt` via `tee`, and passes them to `wc -l`, which prints the count.

### 11. grep and regex

Why does `grep '10.0.0.5' app.log` also match `10x0x0x5`?

??? question "Answer"
    An unescaped `.` matches any single character. Use `grep '10\.0\.0\.5'` or a more general IPv4 regex if you want literal dots.

### 12. tar

What is wrong with this command?

```bash
tar -czvf project/ project.tar.gz
```

??? question "Answer"
    The `-f` option takes the archive filename, so the archive name must come immediately after the options, and the directory must come after it:

```bash
tar -czvf project.tar.gz project/
```

### 13. scp

What does `scp report.txt labuser@10.10.10.11/home/labuser/` do?

??? question "Answer"
    It does not copy to the remote host. Without a colon after the host, the whole string is treated as a local path (and fails). The correct form is `scp report.txt labuser@10.10.10.11:/home/labuser/`.

### 14. Switching users

When would you use `su - labuser` instead of `su labuser`?

??? question "Answer"
    `su - labuser` starts a login shell: it reads the target user's profile, resets `HOME`, `PATH`, and the working directory. `su labuser` keeps much of the current environment, which can lead to confusing `PATH` and permission behavior. Prefer `su -` for interactive work.

### 15. Documentation

How do you find the documentation files installed by a package?

??? question "Answer"
    `rpm -qd <package>`. For example, `rpm -qd tar` lists the README, examples, and other documentation files the `tar` package installed. They are usually under `/usr/share/doc`.

### 16. Exam habits

Name three things you should verify after rebooting a system you configured.

??? question "Answer"
    Any three of: mounts (`findmnt`), services (`systemctl is-enabled` and `is-active`), firewall rules (`firewall-cmd --list-all`), SELinux contexts (`ls -Z`, `getenforce`), network configuration (`nmcli`, `ip`), scheduled jobs (`systemctl list-timers`, `crontab -l`), and the specific application behavior the task requires.

---

## Scoring yourself

| Score | Next step |
|---|---|
| 14–16 | Move on to R2 when it is available; review any missed item |
| 11–13 | Reread the matching theory sections and redo the relevant lab steps |
| 8–10 | Redo Labs 1 and 2 before the challenge |
| 0–7 | Work through the theory page again with the lab open; do not rush |

The goal is not the score. It is to find the two or three ideas you cannot yet explain without notes.
