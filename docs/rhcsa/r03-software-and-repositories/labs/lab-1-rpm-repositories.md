# Lab 1 — RPM repositories and packages

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R3 — Software and repositories |
| **Time** | 60–75 minutes |
| **Check** | `./bin/lab check r03 lab1` |
| **Skills** | `dnf`, `rpm`, `.repo` files, `dnf download`, `createrepo_c`, `dnf config-manager` |

</div>

## What you are building

| Item | End state |
|---|---|
| `/srv/r3/repo` | A directory of RPMs plus a `repodata/` directory |
| `/etc/yum.repos.d/r3-local.repo` | Repo id `r3-local`, `file:///srv/r3/repo`, enabled, `gpgcheck=0` |
| Package `zsh` | Installed, and the package database says it came from `r3-local` |
| Package `tree` | Installed from the distro repos, then removed again |
| Distro repositories | Disabled for the offline drill, then re-enabled |

You will finish with a repository that `dnf` can use with no network at all, which is the only way to install software under exam conditions.

## Before you begin

Start from the clean snapshot, because this lab writes under `/srv` and installs packages:

```bash
cd labs
./bin/lab restore clean
./bin/lab ssh
sudo -i
```

From here on, every command runs **inside the `server` VM** as root.

## Step 1 — Read the repository configuration

```bash
dnf repolist
ls -l /etc/yum.repos.d/
dnf repoinfo baseos | head -14
```

```text { .no-copy }
repo id                        repo name
appstream                      AlmaLinux 10 - AppStream
baseos                         AlmaLinux 10 - BaseOS
crb                            AlmaLinux 10 - CRB
extras                         AlmaLinux 10 - Extras
```

Four repositories are enabled. Note that `dnf repolist` prints only the **enabled** ones; `dnf repolist --all` also lists the disabled `*-debuginfo` and `*-source` repos that ship in the same files.

Open one file to see how a repository is declared:

```bash
cat /etc/yum.repos.d/almalinux-baseos.repo
```

```ini
[baseos]
name=AlmaLinux $releasever - BaseOS
mirrorlist=https://mirrors.almalinux.org/mirrorlist/$releasever/baseos
# baseurl=https://repo.almalinux.org/almalinux/$releasever/BaseOS/$basearch/os/
enabled=1
gpgcheck=1
countme=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-10
```

The `#` in front of `baseurl` makes it a comment; this repo uses `mirrorlist` instead, which is a URL that returns a list of mirrors. `$releasever` and `$basearch` are filled in at run time, which is why the same file works on every point release.

`dnf repoinfo` is the fastest way to confirm what `dnf` actually loaded: the baseurl or mirrorlist, the package count, and the file that defined the repo.

## Step 2 — Install, query, and remove a package

```bash
dnf -y install tree
rpm -q tree
tree --version
```

```text { .no-copy }
Installed:
  tree-2.1.0-8.el10.x86_64
Complete!
tree-2.1.0-8.el10.x86_64
tree v2.1.0 © 1996 - 2022 by Steve Baker, Thomas Moore, Francesc Rocher, Florian Sesser, Kyosuke Tokoro
```

`rpm -q` answers "is it installed, and which build?" from the local database, with no repository contact. Then look at what the package owns and where it came from:

```bash
rpm -qi tree | head -8
rpm -ql tree
rpm -qf /usr/bin/tree
```

Now remove it, and watch what the database says afterwards:

```bash
dnf -y remove tree
rpm -q tree; echo "exit=$?"
dnf list installed tree
```

```text { .no-copy }
Removed:
  tree-2.1.0-8.el10.x86_64
Complete!
package tree is not installed
exit=1
Error: No matching Packages to list
```

`rpm -q` on a missing package exits non-zero — that is deliberate, and it is why `rpm -q` works well in a script.

`dnf history` is the audit trail of every transaction:

```bash
dnf history | head -8
```

```text { .no-copy }
ID     | Command line             | Date and time    | Action(s)      | Altered
-------------------------------------------------------------------------------
     9 | -y remove tree           | 2026-11-10 06:26 | Removed        |    1
     8 | -y install tree          | 2026-11-10 06:26 | Install        |    1
```

Your transaction numbers will differ. `dnf history info 8` shows the details of one, and `dnf history undo 8` reverses it.

## Step 3 — Build a local repository

An exam machine has no internet and no reachable mirror, but it may well hand you a directory of RPM files. That directory becomes installable once it has metadata.

Pick a package that is not installed yet — `zsh` is a good choice: it is small, it is not on the base image, and it pulls nothing else.

```bash
mkdir -p /srv/r3/repo
dnf download --resolve --destdir /srv/r3/repo zsh
ls -l /srv/r3/repo
```

```text { .no-copy }
zsh-5.9-15.el10.x86_64.rpm                      248 kB/s | 3.3 MB     00:13
-rw-r--r--. 1 root root 3409956 Nov 10 06:20 zsh-5.9-15.el10.x86_64.rpm
```

`dnf download --resolve` fetches the package **and any dependencies that are not already installed**, without installing anything. Here that is the single file, because `zsh` needs nothing else.

Now generate the metadata:

```bash
dnf -y install createrepo_c
createrepo_c /srv/r3/repo
ls /srv/r3/repo
ls /srv/r3/repo/repodata
```

```text { .no-copy }
Directory walk started
Directory walk done - 1 packages
Temporary output repo path: /srv/r3/repo/.repodata/
Pool started (with 5 workers)
Pool finished
```

```text { .no-copy }
$ ls /srv/r3/repo
repodata
zsh-5.9-15.el10.x86_64.rpm

$ ls /srv/r3/repo/repodata
<checksum>-filelists.xml.zst
<checksum>-other.xml.zst
<checksum>-primary.xml.zst
repomd.xml
```

Each of those `.zst` files begins with a long checksum and holds one kind of metadata. `repomd.xml` is the index of them and the file `dnf` looks for first. Without it, `/srv/r3/repo` is just a directory with an RPM in it.

## Step 4 — Point `dnf` at the local repository

```bash
cat > /etc/yum.repos.d/r3-local.repo <<'EOF'
[r3-local]
name=R3 local package repository
baseurl=file:///srv/r3/repo
enabled=1
gpgcheck=0
EOF

dnf repolist
dnf repoinfo r3-local
```

```text { .no-copy }
repo id                        repo name
appstream                      AlmaLinux 10 - AppStream
baseos                         AlmaLinux 10 - BaseOS
crb                            AlmaLinux 10 - CRB
extras                         AlmaLinux 10 - Extras
r3-local                       R3 local package repository
```

```text { .no-copy }
Repo-id            : r3-local
Repo-name          : R3 local package repository
Repo-status        : enabled
Repo-revision      : 1794289681
Repo-updated       : Tue 10 Nov 2026 05:48:01 AM UTC
Repo-pkgs          : 1
Repo-available-pkgs: 1
Repo-size          : 3.3 M
Repo-baseurl       : file:///srv/r3/repo
Repo-expire        : 172,800 second(s) (last: Tue 10 Nov 2026 05:58:29 AM UTC)
Repo-filename      : /etc/yum.repos.d/r3-local.repo
Total packages: 1
```

`Repo-pkgs : 1` proves `dnf` read your metadata. `Repo-filename` proves which file defined it — useful when two files declare the same id.

Three details are easy to get wrong:

- `baseurl` names the directory that **contains** `repodata/`, not `repodata/` itself.
- A `file://` URL has three slashes: two for the scheme and one for the root.
- Only files ending in `.repo` are read. `r3-local.repo.bak` is ignored.

`gpgcheck=0` is correct here and you should be able to say why: the package is signed by nobody you have a key for, so there is nothing to verify. You are trusting the disk it sits on.

## Step 5 — Install with the network out of the picture

Two flags override the enabled/disabled state of repositories for a single command. Use them to force `dnf` to use only your repository:

```bash
dnf --disablerepo='*' --enablerepo=r3-local list --available zsh
dnf --disablerepo='*' --enablerepo=r3-local -y install zsh
```

```text { .no-copy }
Available Packages
zsh.x86_64                    5.9-15.el10                    r3-local
```

```text { .no-copy }
Installed:
  zsh-5.9-15.el10.x86_64
Complete!
```

Check the provenance — this is the interesting part:

```bash
rpm -q zsh
dnf list zsh
dnf --disablerepo='*' --enablerepo=r3-local -q repoquery zsh
```

```text { .no-copy }
zsh-5.9-15.el10.x86_64
Installed Packages
zsh.x86_64                         5.9-15.el10                         @r3-local
zsh-0:5.9-15.el10.x86_64
```

`@r3-local` is the package database recording where the package came from. `repoquery` read the same answer straight out of `repodata/`, without consulting the installed set, which is what you need when the package is not installed.

Note the quotes around `*`. Unquoted, the shell expands it against the files in your current directory and the command fails in a confusing way.

## Step 6 — Reproduce the exam's no-internet condition

The exam machine cannot reach a mirror. You can simulate that without touching the network — which is important, because cutting the interface would also kill your SSH session.

```bash
dnf config-manager --set-disabled baseos appstream extras crb
dnf repolist
```

```text { .no-copy }
repo id                        repo name
r3-local                       R3 local package repository
```

Only the local repository is left. Try to install something that lives on the distro mirrors:

```bash
dnf -y install cowsay
```

```text { .no-copy }
No match for argument: cowsay
Error: Unable to find a match: cowsay
```

That is the exact failure mode of an offline machine with the wrong repository configuration. It is not a network error: `dnf` never tried to reach anything, because nothing enabled offers the package.

`config-manager` did not use a flag or a session: it rewrote the `enabled=` lines in the files.

```bash
grep -E '^enabled=' /etc/yum.repos.d/almalinux-baseos.repo
```

```text { .no-copy }
enabled=1
enabled=0
enabled=0
```

One line per section in that file: `baseos`, `baseos-debuginfo`, `baseos-source`. The debug and source repos were already disabled; the change you just made is the first line.

Put the repositories back, or the rest of the course will fail at its next install:

```bash
dnf config-manager --set-enabled baseos appstream extras crb
dnf repolist
```

```text { .no-copy }
repo id                        repo name
appstream                      AlmaLinux 10 - AppStream
baseos                         AlmaLinux 10 - BaseOS
crb                            AlmaLinux 10 - CRB
extras                         AlmaLinux 10 - Extras
r3-local                       R3 local package repository
```

## Step 7 — Reboot and prove persistence

A `.repo` file and an installed package are both files on disk, so they should survive. Prove it rather than assume it.

```bash
reboot
```

Wait for the machine, then from the host:

```bash
cd labs
./bin/lab ssh
sudo -i
```

```bash
dnf repolist
rpm -q zsh
dnf list zsh
dnf repoinfo r3-local | sed -n '1,4p;9p'
dnf --disablerepo='*' --enablerepo=r3-local -q repoquery zsh
```

```text { .no-copy }
... r3-local ...
zsh-5.9-15.el10.x86_64
zsh.x86_64                         5.9-15.el10                         @r3-local
Repo-id            : r3-local
Repo-name          : R3 local package repository
Repo-status        : enabled
Repo-baseurl       : file:///srv/r3/repo
zsh-0:5.9-15.el10.x86_64
```

## Step 8 — Run the checker

```bash
./bin/lab check r03 lab1
```

<details>
<summary>Show the expected check output</summary>

```text { .no-copy }
R3 Lab 1 — RPM repositories and packages
  PASS  repository directory exists: /srv/r3/repo
  PASS  the repository contains at least one RPM
  PASS  repository metadata exists: /srv/r3/repo/repodata/repomd.xml
  PASS  repo file exists: /etc/yum.repos.d/r3-local.repo
  PASS  r3-local is enabled
  PASS  r3-local baseurl is file:///srv/r3/repo
  PASS  r3-local has gpgcheck=0
  PASS  package zsh is installed
  PASS  zsh is recorded as coming from r3-local
  PASS  the repository still serves zsh
```

</details>

The checker reads end state only: the repository directory, the repo file, the RPM database, and one `repoquery` against your metadata. It cannot tell whether you typed the commands in the right order, and it does not care.

## What to remember

- `rpm` queries the installed database; `dnf` talks to repositories and resolves dependencies.
- A repository is a directory of RPMs plus `repodata/repomd.xml`, generated by `createrepo_c`.
- `baseurl` points at the parent of `repodata/`, and a local one needs `file:///`.
- Only `*.repo` files under `/etc/yum.repos.d/` are read.
- `--disablerepo='*' --enablerepo=id` is for one command; `dnf config-manager --set-disabled` changes the files and survives a reboot.
- `dnf list pkg` shows `@repo` for where an installed package came from.
- An offline machine fails with `Unable to find a match`, not with a network error.
