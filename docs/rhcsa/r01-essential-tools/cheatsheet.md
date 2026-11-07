# R1 cheat sheet

A compact reference for review. Everything here is explained in the [theory page](index.md).

## Shell basics

| Task | Command |
|---|---|
| Find what a command is | `type -a name` / `command -v name` |
| Exit status of the last command | `echo $?` |
| Run B only if A succeeds | `A && B` |
| Run B only if A fails | `A \|\| B` |
| Command substitution | `$(command)` |
| Last command's arguments | `!$` |
| Search history | `Ctrl+R` |
| Cancel foreground command | `Ctrl+C` |

## Help

| Task | Command |
|---|---|
| Command manual | `man command` |
| Specific section | `man 5 passwd` |
| Search descriptions | `man -k keyword` / `apropos keyword` |
| Rebuild manual index | `sudo mandb` |
| Short help | `command --help` |
| GNU info | `info command` |
| Package documentation | `ls /usr/share/doc`, `rpm -qd package` |

## Files and directories

| Task | Command |
|---|---|
| Current directory | `pwd` |
| List all, long | `ls -la` |
| Change directory | `cd path` / `cd -` |
| Create tree | `mkdir -p a/b/c` |
| Create empty file | `touch file` |
| Copy | `cp source dest` |
| Copy tree, preserve | `cp -a source dest` |
| Move or rename | `mv source dest` |
| Remove file | `rm file` |
| Remove tree | `rm -r dir` |
| File type | `file path` |
| Metadata | `stat path` |
| Find by name | `find /path -name '*.conf'` |
| Find by type | `find /path -type f` |
| Find by size | `find /path -size +100M` |

## Links

| Task | Command |
|---|---|
| Hard link | `ln target newname` |
| Symbolic link | `ln -s target newname` |
| Inode and link count | `ls -li file` / `stat -c '%i %h %n' file` |
| Read symlink target | `readlink link` |
| Resolve to absolute path | `readlink -f link` |
| Find hard links | `find /path -samefile file` |

## Permissions

| Task | Command |
|---|---|
| Show mode | `ls -ld path` / `stat -c '%a %U %G %n' path` |
| Octal mode | `chmod 640 file` |
| Symbolic mode | `chmod u+x,g-w file` |
| Recursive | `chmod -R 750 dir` |
| Owner and group | `chown user:group path` |
| Group only | `chgrp group path` |
| Show current umask | `umask` |
| Set umask | `umask 027` |
| Path permissions | `namei -l path` |
| Test as another user | `sudo -u user command` |

### Octal quick reference

| Mode | Meaning |
|---|---|
| `755` | `rwxr-xr-x` — executable, world-readable |
| `750` | `rwxr-x---` — owner and group only |
| `700` | `rwx------` — private executable |
| `644` | `rw-r--r--` — normal file |
| `640` | `rw-r-----` — group-readable, private to others |
| `600` | `rw-------` — private file |
| `770` | `rwxrwx---` — shared directory for a group |

## Redirection and pipes

| Task | Syntax |
|---|---|
| Write stdout | `cmd > file` |
| Append stdout | `cmd >> file` |
| Write stderr | `cmd 2> file` |
| Both to one file | `cmd > file 2>&1` |
| Both, shorthand | `cmd &> file` |
| Read stdin from file | `cmd < file` |
| Pipe | `cmd1 \| cmd2` |
| Write and display | `cmd \| tee file` |
| Discard | `cmd > /dev/null 2>&1` |
| Heredoc | `cat <<'EOF' > file` … `EOF` |

## grep and regex

| Task | Command |
|---|---|
| Literal match | `grep 'text' file` |
| Case-insensitive | `grep -i 'text' file` |
| Invert | `grep -v 'text' file` |
| Line numbers | `grep -n 'text' file` |
| Count | `grep -c 'text' file` |
| Recursive | `grep -r 'text' /path` |
| Extended regex | `grep -E 'a\|b' file` |
| Only the match | `grep -o 'pattern' file` |
| IPv4 | `grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' file` |

Regex anchors: `^` start, `$` end, `.` any character, `*` zero or more, `+` one or more (ERE), `?` zero or one (ERE), `[abc]` set, `[^abc]` negated set, `{n,m}` repetition (ERE), `\b` word boundary.

## Archives and compression

| Task | Command |
|---|---|
| Create `.tar.gz` | `tar -czf archive.tar.gz dir/` |
| Create `.tar.bz2` | `tar -cjf archive.tar.bz2 dir/` |
| Create plain `.tar` | `tar -cf archive.tar dir/` |
| List | `tar -tf archive.tar.gz` |
| Extract | `tar -xzf archive.tar.gz` |
| Extract elsewhere | `tar -xzf archive.tar.gz -C /dest` |
| Compress file | `gzip file` / `bzip2 file` |
| Decompress | `gunzip file.gz` / `bunzip2 file.bz2` |
| View compressed | `zcat file.gz` / `bzcat file.bz2` |

## SSH and file transfer

| Task | Command |
|---|---|
| Log in | `ssh user@host` |
| Run one command | `ssh user@host command` |
| Copy to remote | `scp file user@host:/path/` |
| Copy tree to remote | `scp -r dir user@host:/path/` |
| Copy from remote | `scp user@host:/path/file .` |
| Interactive SFTP | `sftp user@host` |
| Remove stale host key | `ssh-keygen -R host` |
| Generate key | `ssh-keygen -t ed25519` |
| Install public key | `ssh-copy-id user@host` |

## Users and privilege

| Task | Command |
|---|---|
| Identity | `id` / `whoami` |
| Login shell as user | `su - user` |
| One command as user | `su - user -c 'command'` |
| One command as root | `sudo command` |
| Root login shell | `sudo -i` |
| One command as another user | `sudo -u user command` |
| List sudo rights | `sudo -l` |

## Integrity

| Task | Command |
|---|---|
| SHA-256 | `sha256sum file` |
| Verify a checksum file | `sha256sum -c file.sha256` |
| Compare two files | `cmp file1 file2` |

## The persistence four

When a task changes system state, check all four:

1. **Mount** — in `/etc/fstab`, verified with `findmnt` after reboot.
2. **Service** — `systemctl enable --now`, verified with `systemctl is-enabled`.
3. **Firewall** — `firewall-cmd --permanent`, then `--reload`, verified with `--list-all`.
4. **SELinux** — persistent context or boolean, verified with `ls -Z`, `getsebool`, or a relabel.
