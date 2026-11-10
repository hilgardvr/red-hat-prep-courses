# R3 cheat sheet

A compact reference for review. Everything here is explained in the [theory page](index.md).

## `rpm` — ask the local database

| Task | Command |
|---|---|
| Is it installed? | `rpm -q zsh` |
| Full metadata | `rpm -qi zsh` |
| Every file it owns | `rpm -ql zsh` |
| Configuration files only | `rpm -qc zsh` |
| Which package owns a path | `rpm -qf /usr/bin/zsh` |
| What depends on it | `rpm -q --whatrequires zsh` |
| Verify installed files | `rpm -V zsh` |
| Inspect a file you have not installed | `rpm -qpi file.rpm`, `rpm -qpl file.rpm` |
| List imported keys | `rpm -qa gpg-pubkey*` |

## `dnf` — transactions

| Task | Command |
|---|---|
| Install | `dnf install zsh` |
| Install a local file, resolving deps | `dnf install ./zsh-5.9-15.el10.x86_64.rpm` |
| Remove | `dnf remove zsh` |
| Update everything / one package | `dnf update` / `dnf update zsh` |
| Reinstall | `dnf reinstall zsh` |
| History | `dnf history`, `dnf history info 8`, `dnf history undo 8` |
| Clear the metadata cache | `dnf clean all` |
| Re-download metadata | `dnf makecache` |

## `dnf` — queries

| Task | Command |
|---|---|
| Installed packages | `dnf list --installed` |
| Available versions | `dnf list --available zsh` |
| Installed or available, with repo | `dnf list zsh` |
| Which repo supplies a path or capability | `dnf provides /usr/bin/zsh` |
| Package details | `dnf info zsh` |
| File list from repo metadata | `dnf repoquery -l zsh` |
| Dependencies including uninstalled | `dnf repoquery --requires zsh` |

`@r3-local` in the repo column means "installed, and it came from that repository".

## Repository configuration

Files live in `/etc/yum.repos.d/` and **must** end in `.repo`.

```ini
[r3-local]
name=R3 local package repository
baseurl=file:///srv/r3/repo
enabled=1
gpgcheck=0
```

| Key | Meaning |
|---|---|
| `[r3-local]` | The repo id used by `--enablerepo` and printed by `repolist` |
| `name=` | Label only |
| `baseurl=` | Directory that **contains** `repodata/` |
| `mirrorlist=` / `metalink=` | URL that returns mirror addresses |
| `enabled=` | `1` used, `0` configured but ignored |
| `gpgcheck=` | `1` requires a signature from `gpgkey=` |

| Task | Command |
|---|---|
| Enabled repos | `dnf repolist` |
| All configured repos | `dnf repolist --all` |
| One repo in detail | `dnf repoinfo r3-local` |
| One repo's settings | `dnf config-manager --dump r3-local` |
| Disable / enable persistently | `dnf config-manager --set-disabled baseos appstream extras crb` |
| Use only one repo for one command | `dnf --disablerepo='*' --enablerepo=r3-local install zsh` |

## Build a local repository

```bash
mkdir -p /srv/r3/repo
dnf download --resolve --destdir /srv/r3/repo zsh   # package + missing deps, no install
dnf install -y createrepo_c
createrepo_c /srv/r3/repo                           # writes repodata/repomd.xml
```

Then write the `.repo` file, `dnf repolist` to confirm, and install. Added packages later?

```bash
createrepo_c --update /srv/r3/repo
dnf clean all
```

## Flatpak

| Task | Command |
|---|---|
| Add a remote | `flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo` |
| List remotes with scope | `flatpak remotes --columns=name,url,options` |
| Search | `flatpak search calculator` |
| Inspect before installing | `flatpak remote-info flathub org.gnome.Calculator` |
| Install | `flatpak install -y flathub org.gnome.Calculator` |
| Everything installed | `flatpak list` |
| Apps only / runtimes only | `flatpak list --app` / `flatpak list --runtime` |
| Details for one app | `flatpak info org.gnome.Calculator` |
| Run it (needs a desktop session) | `flatpak run org.gnome.Calculator` |
| Remove an app | `flatpak uninstall org.gnome.Calculator` |
| Remove unreferenced runtimes | `flatpak uninstall --unused` |
| Update | `flatpak update` |
| Remove the remote (not the apps) | `flatpak remote-delete flathub` |
| User-scope store | add `--user` to `install`, `list`, `uninstall` |

Application ids are reverse-DNS. One app usually pulls in a runtime (`org.gnome.Platform`), which is not removed with the app.

## What survives a reboot

| Change | Persists? | Because |
|---|---|---|
| A `.repo` file | Yes | A file in `/etc/yum.repos.d/` |
| `config-manager --set-disabled` | Yes | It rewrites `enabled=` in that file |
| `--disablerepo` / `--enablerepo` | No | An argument to one command |
| Installed RPMs | Yes | Files in `/usr` plus `/var/lib/rpm` |
| Flatpak remote or app | Yes | `/var/lib/flatpak` (or the user's home) |
| `dnf clean all` | — | Cache only; it holds no configuration |

## Verification

Run these after a reboot; the same answers mean the configuration persisted.

```bash
dnf repolist
dnf repoinfo r3-local | head -11
dnf list zsh
dnf --disablerepo='*' --enablerepo=r3-local -q repoquery zsh
flatpak remotes
flatpak list
```
