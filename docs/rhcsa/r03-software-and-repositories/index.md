# R3 — Software and repositories

<div class="module-meta" markdown>

| | |
|---|---|
| **Exam objective group** | 2 — Manage software |
| **Time** | 2–3 hours including labs |
| **Prerequisites** | [R1 — Essential tools](../r01-essential-tools/index.md), especially [Permissions](../r01-essential-tools/index.md#permissions) and [Streams and pipes](../r01-essential-tools/index.md#streams-redirection-and-pipes) |
| **Labs** | 2 guided labs + 1 challenge |
| **Check command** | `./bin/lab check r03 lab1` (also `lab2` and `challenge`) |

</div>

Every system you administer needs software installed, updated, and removed, and the exam runs on a machine with **no internet access**. That single constraint shapes this whole module: you cannot rely on a public mirror being reachable, so you have to understand where packages come from, how a repository is described, and how to point the system at one that is local.

RHEL 10 has two software channels. RPM packages are the operating system: installed by `dnf`, tracked in a database, and updated from repositories. Flatpak is the desktop application channel: sandboxed apps with their own runtimes. Both are exam objectives, and they are configured in completely different ways.

## Objective checklist

By the end of this module you should be able to:

- [ ] Explain how an RPM package, a repository, and the package database relate
- [ ] Read repository configuration in `/etc/yum.repos.d/` and change it
- [ ] Configure access to an RPM repository, including a local `file://` directory
- [ ] Build repository metadata with `createrepo_c`
- [ ] Install, query, and remove RPM packages with `dnf` and `rpm`
- [ ] Enable and disable repositories, permanently and for one command
- [ ] Configure a Flatpak remote with `flatpak remote-add`
- [ ] Install, list, and remove Flatpak applications and runtimes
- [ ] Prove that repository configuration and installed software survive a reboot

---

## What a package is

An RPM package is a single file, `name-version-release.arch.rpm`, that contains:

- the files to install, with their permissions and SELinux labels
- metadata: name, version, license, architecture, and the package's dependencies
- scripts that run at install and removal time
- a cryptographic signature, if the package is signed

```text
zsh-5.9-15.el10.x86_64.rpm
```

| Part | Meaning |
|---|---|
| `zsh` | name |
| `5.9` | version, from upstream |
| `15.el10` | release: build 15 for the el10 stream |
| `x86_64` | architecture |
| `.rpm` | a package file |

The system keeps a database of what is installed, which is why `rpm -q` can answer questions without any file being present. `/var/lib/rpm` holds it.

Installing an RPM file directly is possible, but the file does not know where to find its dependencies. **That is the whole reason `dnf` exists**: it reads repository metadata, resolves dependencies, downloads what is missing, checks signatures, and writes an auditable transaction.

## `rpm`: interrogate the database

`rpm` is the low-level tool. On the exam you will mostly use it to *ask questions*, not to install.

```bash
rpm -q zsh                 # is it installed, and which version?
rpm -qi zsh                # full metadata: version, license, install date
rpm -ql zsh                # every file the package owns
rpm -qc zsh                # only its configuration files
rpm -qf /usr/bin/zsh       # which package owns this file?
rpm -q --whatrequires zsh  # what depends on it?
rpm -V zsh                 # verify installed files against the package
```

```text
$ rpm -q zsh
zsh-5.9-15.el10.x86_64
$ rpm -qf /etc/passwd
setup-2.14.5-7.el10.noarch
```

`rpm -V` prints nothing when every file matches the package's recorded size, checksum, mode, owner, and label. Silence is the good answer.

To inspect a package you have *not* installed, add `-p` (for "package file"):

```bash
rpm -qp --info zsh-5.9-15.el10.x86_64.rpm
rpm -qpl zsh-5.9-15.el10.x86_64.rpm
rpm -qp --requires zsh-5.9-15.el10.x86_64.rpm
```

Direct installation (`rpm -i file.rpm`) fails with a list of missing dependencies and leaves you to install them by hand. Use `dnf install ./file.rpm` instead: `dnf` accepts a local file and still resolves dependencies from the configured repositories.

## Repositories

A **repository** is a directory of RPMs plus a `repodata/` directory describing them:

```text
/srv/r3/repo/
├── repodata/
│   ├── repomd.xml                 # index of the index files
│   ├── ...-primary.xml.zst        # package names, versions, dependencies
│   ├── ...-filelists.xml.zst      # which package owns which path
│   └── ...-other.xml.zst          # changelogs and extra metadata
└── zsh-5.9-15.el10.x86_64.rpm
```

`repomd.xml` is the entry point. If it is missing, the directory is just a pile of RPMs and `dnf` cannot use it. `createrepo_c` generates it.

Repositories can live behind HTTP/HTTPS/FTP, or on the local filesystem with a `file://` URL. The exam's "local filesystem" wording means the second kind.

### Repository configuration files

Every repository `dnf` knows about is defined by a `[section]` in a file under `/etc/yum.repos.d/` whose name ends in `.repo`:

```ini
[r3-local]
name=R3 local package repository
baseurl=file:///srv/r3/repo
enabled=1
gpgcheck=0
```

| Key | Meaning |
|---|---|
| `[r3-local]` | The **repo id**. This is what you pass to `--enablerepo` and what `repolist` prints. |
| `name=` | A human-readable label. It has no effect on behaviour. |
| `baseurl=` | URL of the directory that **contains** `repodata/`, not the `repodata/` directory itself. |
| `metalink=` / `mirrorlist=` | A URL that returns a list of mirrors. The distro repos use this instead of `baseurl`. |
| `enabled=` | `1` means `dnf` uses it; `0` means it is configured but ignored. |
| `gpgcheck=` | `1` means every downloaded package must carry a valid signature. |
| `gpgkey=` | Where to find the public key that `gpgcheck` validates against. |

The AlmaLinux repos on the lab look like this:

```ini
[baseos]
name=AlmaLinux $releasever - BaseOS
mirrorlist=https://mirrors.almalinux.org/mirrorlist/$releasever/baseos
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-10
```

`$releasever` and `$basearch` are substituted at run time, which is why one file works for every point release and architecture.

Only files ending in `.repo` are read. `almalinux-baseos.repo.rpmsave` and `r3-local.repo.bak` are ignored — a fact worth remembering when a "disabled" repository refuses to come back.

### The four AlmaLinux repositories

| Repo id | Contains |
|---|---|
| `baseos` | The core operating system packages |
| `appstream` | Applications and language runtimes, including most of what you install by name |
| `crb` | CodeReady Builder: extra development libraries. Disabled by default on RHEL; AlmaLinux ships it enabled |
| `extras` | A few add-on packages |

RHEL's equivalents are the same names plus `rhel-*` subscription repos. The exam machine reaches them through a local mirror, not the internet.

### Looking at what is configured

```bash
dnf repolist                   # enabled repos only
dnf repolist --all             # every configured repo, with its status
dnf repoinfo r3-local          # details for one repo: baseurl, package count, metadata age
```

```text
$ dnf repolist
repo id                  repo name
appstream                AlmaLinux 10 - AppStream
baseos                   AlmaLinux 10 - BaseOS
crb                      AlmaLinux 10 - CRB
extras                   AlmaLinux 10 - Extras
r3-local                 R3 local package repository
```

`dnf repoinfo` is the fastest way to check that a `baseurl` is right and that the metadata was actually read: it prints the package count and the path of the file that defined the repo.

### Signatures and trust

`gpgcheck=1` plus `gpgkey=` makes `dnf` refuse any package that is not signed by that key. The distro key is installed with the system at `/etc/pki/rpm-gpg/`. You can also import a key by hand:

```bash
sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-10
rpm -qa gpg-pubkey*            # list imported keys
```

A repository you build yourself has no signature, so it uses `gpgcheck=0`. That is acceptable for packages you produced locally, and it is a decision you should be able to explain: with `gpgcheck=0` you are trusting the transport (here, the local disk) rather than a signature.

## `dnf`: transactions

`dnf` is the tool that installs things. The commands you need are short; the important part is reading the transaction before you approve it.

```bash
sudo dnf install zsh                  # install from the enabled repos
sudo dnf install ./zsh-5.9-15.el10.x86_64.rpm   # install a local file, resolve deps
sudo dnf remove zsh                   # remove the package and what depends on it
sudo dnf update                       # update everything with an available update
sudo dnf update zsh                   # update one package
sudo dnf reinstall zsh                # reinstall the current version
```

Queries:

```bash
dnf list --installed                  # what is on the system
dnf list --available zsh              # what the repos offer
dnf search calculator                 # search names and summaries
dnf info zsh                          # name, version, size, repo, description
dnf provides /usr/bin/zsh             # which package or repo supplies this path or capability
dnf repoquery -l zsh                  # file list, straight from the repo metadata
dnf repoquery --requires zsh          # dependencies, including ones not installed
```

```text
$ dnf list --available zsh
Available Packages
zsh.x86_64                  5.9-15.el10                  r3-local
```

The right-hand column is where the package would come from. When you are debugging, that column answers "which repository is winning".

`dnf provides` is the command for "I know the file or the capability, not the package name". The first run can be slow, because `dnf` may have to download file lists for the enabled repositories.

### Reading a transaction

`dnf` always shows you the plan first:

```text
Dependencies resolved.
================================================================================
 Package        Architecture   Version            Repository        Size
================================================================================
Installing:
 zsh            x86_64         5.9-15.el10        r3-local          3.3 M

Transaction Summary
================================================================================
Install  1 Package
```

`-y` skips the confirmation. Use it in a script or when you have already read the plan; do not use it to avoid reading the plan.

`dnf history` is the audit log:

```bash
dnf history
dnf history info 5
sudo dnf history undo 5
```

Every install, remove, and update is a numbered transaction. `history undo` reverses one, which is the closest thing to Ctrl-Z the package manager has — and it can fail if later transactions changed the same packages.

### Metadata and the cache

`dnf` keeps repository metadata under `/var/cache/dnf` and reuses it until it expires (`metadata_expire`, 24 hours for the distro repos). Two consequences:

```bash
sudo dnf clean all       # delete cached metadata and packages
sudo dnf makecache       # download it again
```

If you rebuild a repository's metadata and `dnf` still sees the old list, `clean all` is the fix. Also note that only one `dnf` process can hold the lock: a background `PackageKit` or a stale `dnf` shows up as `Waiting for process with pid ... to finish`.

### Choosing repositories per command

Two flags override the enabled/disabled state for a single command:

```bash
sudo dnf --disablerepo='*' --enablerepo=r3-local install zsh
sudo dnf --repo=r3-local list zsh
```

The quotes around `*` matter: unquoted, the shell expands it to filenames and the command fails in a confusing way.

This is exactly how you install software on a machine with no internet: every remote repo is unreachable, so you point `dnf` at the one repository that exists locally.

### Enabling and disabling repositories permanently

Editing the file works, and so does the plugin:

```bash
sudo dnf config-manager --set-disabled baseos appstream extras crb
sudo dnf config-manager --set-enabled baseos appstream extras crb
```

`config-manager` rewrites `enabled=0` or `enabled=1` in the `.repo` files, so the change survives a reboot. A one-shot `--disablerepo` does not. The command comes from the `dnf-plugins-core` package; if it is missing, `dnf install dnf-plugins-core` provides it.

With the distro repositories disabled and a local repository that does not contain the package, an install looks like this:

```text
$ sudo dnf -y install cowsay
No match for argument: cowsay
Error: Unable to find a match: cowsay
```

That error means "no enabled repository offers this package". It is not a network error, and no amount of retrying will fix it — you either enable the right repository or put the package in the local one.

## Building a local repository

The exam can hand you a directory of RPMs and expect you to make it installable. Four steps:

```bash
sudo mkdir -p /srv/r3/repo
sudo dnf download --resolve --destdir /srv/r3/repo zsh
sudo dnf install -y createrepo_c
sudo createrepo_c /srv/r3/repo
```

`dnf download --resolve` fetches the package plus any dependencies that are not already installed, without installing anything. `--destdir` puts them in one place.

`createrepo_c` then writes `repodata/`:

```text
Directory walk done - 1 packages
Temporary output repo path: /srv/r3/repo/.repodata/
Pool started (with 5 workers)
Pool finished
```

Then the `.repo` file above, `dnf repolist` to confirm it is read, and `dnf install`. When you add more RPMs later, rerun `createrepo_c --update /srv/r3/repo` and `dnf clean all`.

The common mistakes are all path mistakes: `baseurl` pointing at `repodata/` instead of its parent, a `file://` URL with two slashes instead of three, and forgetting that only `.repo` files are parsed.

## Flatpak

Flatpak installs **desktop applications** into a sandbox, with their own libraries, independent of the RPM database. It solves a different problem from `dnf`: an application that needs a newer library than the operating system provides, or a user who wants an app without root.

| | RPM / `dnf` | Flatpak |
|---|---|---|
| What it installs | Operating system packages and services | Desktop applications |
| Where the software lives | `/usr` | `/var/lib/flatpak` (system) or `~/.local/share/flatpak` (user) |
| Dependencies | Resolved from repo metadata, installed to `/usr` | Bundled **runtime**, shared between apps |
| Root needed | Yes | No for `--user` scope |
| Repository format | RPM + `repodata/` | OSTree repository, called a **remote** |
| Updates | `dnf update` | `flatpak update` |

A Flatpak application is not a single binary: it is an app plus a runtime (`org.gnome.Platform`, `org.freedesktop.Platform`, and so on). Installing the app downloads the runtime it needs. Removing the app does **not** automatically remove the runtime; `flatpak uninstall --unused` does that.

### Remotes

A remote is configured once, then used by name:

```bash
flatpak remote-add --if-not-exists flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak remotes
flatpak remotes --columns=name,url,options
```

```text
$ flatpak remotes
flathub	system
```

`--if-not-exists` makes the command safe to rerun. The URL is the remote's base; `flatpak remotes --columns=name,url,options` prints it alongside the scope. The `.flatpakrepo` URL is a small file that describes the remote, including its GPG key — which is how Flatpak gets trust without you importing a key by hand.

`flatpak` defaults to installing for **all users** (system scope), which is the `system` column above. Add `--user` to keep an app inside your home directory instead; the options column then reads `user`. Mixing the two is the usual source of "I installed it but it is not there": `flatpak list` without `--user` does not show user-scope installs.

### Installing and removing applications

```bash
flatpak search calculator                    # find the application id
flatpak install -y flathub org.gnome.Calculator
flatpak list                                 # apps and runtimes
flatpak list --app                           # apps only
flatpak list --runtime                       # runtimes only
flatpak info org.gnome.Calculator            # id, version, branch, origin, runtime
flatpak run org.gnome.Calculator             # launch it
flatpak uninstall org.gnome.Calculator
flatpak uninstall --unused                   # drop runtimes nothing needs
flatpak remote-delete flathub                # remove the remote, not the apps
```

Application ids are reverse-DNS (`org.gnome.Calculator`) and are what you pass to `install`, `info`, `run`, and `uninstall`. The human name in `flatpak search` is only a label.

Two details that matter in practice:

- `flatpak run` needs a graphical session. On a headless server the install, list, and remove commands all work, but running the app does not. That is fine — the exam objectives are about managing remotes and packages, not using the app.
- `flatpak update` upgrades apps and runtimes together. `flatpak repair` checks the local OSTree store when something looks corrupt.

What an install actually brings in:

```text
$ flatpak install -y flathub org.gnome.Calculator
...
Installation complete.

$ flatpak list --app --columns=application,version,origin
org.gnome.Calculator	51.1	flathub

$ flatpak list --runtime --columns=application,branch,origin
org.freedesktop.Platform.GL.default	26.08	flathub
org.freedesktop.Platform.GL.default	26.08-extra	flathub
org.freedesktop.Platform.codecs-extra	26.08-extra	flathub
org.gnome.Platform	51	flathub
```

Without `--columns`, `flatpak list` prints its own wide table (display name, id, version, branch, installation) and shows apps and runtimes together; `--app` and `--runtime` split them.

One application, four runtime entries. `flatpak info` reports the app itself as 5.1 MB installed, but `/var/lib/flatpak` grows to about 1.8 GB because the runtime and its graphics drivers are shared with every GNOME app you install later. After `flatpak uninstall org.gnome.Calculator` those runtime entries are still listed; `flatpak uninstall --unused` removes them and the directory drops to roughly 111 MB. That is why a machine can look empty in `flatpak list --app` and still have a full disk.

Because Flatpak state lives in `/var/lib/flatpak` (or the user's home), remotes and installed apps survive a reboot with no extra work. What does not survive is an install you started as one user and expect to see as another.

## Common traps

| Trap | What happens | Fix |
|---|---|---|
| `baseurl=/srv/r3/repo/repodata` | `dnf` cannot read the repo | Point `baseurl` at the directory that *contains* `repodata/` |
| `baseurl=/srv/r3/repo` without `file://` | Treated as a relative URL and fails | `baseurl=file:///srv/r3/repo` — three slashes |
| Rebuilt the repo, `dnf` still sees old packages | Cached metadata is still valid | `sudo dnf clean all`, or `createrepo_c --update` plus a refresh |
| `gpgcheck=1` on an unsigned local repo | `Public key ... is not installed`, install refused | Sign the packages, or set `gpgcheck=0` and know why |
| `rpm -i package.rpm` | Fails on unmet dependencies | `dnf install ./package.rpm` |
| `dnf remove` on a library | Dependent packages go too | Read the transaction summary; `dnf history undo` if it was wrong |
| Unquoted `--disablerepo=*` | Shell expands `*` to filenames | `--disablerepo='*'` |
| `dnf config-manager --set-disabled` and forgot | Installs later fail with "Unable to find a match" | `dnf repolist`, then re-enable |
| `.repo.bak` left in `/etc/yum.repos.d` | Ignored, so the "disabled" repo silently stays disabled | Only `.repo` files are read; rename the real file back |
| Two `dnf` processes at once | `Waiting for process with pid ... to finish` | Wait, or stop the other process |
| `flatpak list` does not show the app | It was installed with `--user` | `flatpak list --user`, or install system-wide |
| Removed the Flatpak app, disk still full | Its runtime is still installed | `flatpak uninstall --unused` |

## Persistence

Three different kinds of state, three different answers:

| What you changed | Survives reboot because |
|---|---|
| A `.repo` file in `/etc/yum.repos.d/` | It is a file on disk |
| Packages installed with `dnf` | They are files on disk plus the RPM database |
| A Flatpak remote or app | `/var/lib/flatpak` (system) or the user's home (`--user`) |
| A `--enablerepo` flag | **Nothing.** It was an argument to one command |

The metadata cache under `/var/cache/dnf` is not state: deleting it changes nothing except the next command's speed.

---

## Labs

Now do the work. The labs install and remove real software, so start from the clean snapshot.

1. [Lab 1 — RPM repositories and packages](labs/lab-1-rpm-repositories.md)
2. [Lab 2 — Flatpak](labs/lab-2-flatpak.md)
3. [Challenge — Offline build server](labs/challenge-offline-build.md)

Then review the [knowledge check](quiz.md) and keep the [cheat sheet](cheatsheet.md) handy.
