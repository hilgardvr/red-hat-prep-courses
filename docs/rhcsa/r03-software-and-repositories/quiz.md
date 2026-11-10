# R3 knowledge check

Answer first, then open the answer. If you miss a question, return to the matching section of the [theory page](index.md).

### 1. Two tools, two databases

What does `rpm -q zsh` consult, and what does `dnf list zsh` add to that answer?

??? question "Answer"
    `rpm -q` reads only the local RPM database in `/var/lib/rpm`: it knows what is installed and nothing about what could be installed. `dnf list` reads the same database **and** the metadata of the enabled repositories, which is why it can print a repository column — `@r3-local` for an installed package, a repo id for one that is only available.

### 2. Reading a package filename

Break `zsh-5.9-15.el10.x86_64.rpm` into its parts.

??? question "Answer"
    `zsh` is the name, `5.9` the version, `15.el10` the release (build 15 of the el10 stream), `x86_64` the architecture. The distribution is implied by the release string; the release is what usually changes when a package is rebuilt without a new upstream version.

### 3. Where repositories are declared

You create `/etc/yum.repos.d/r3-local.conf` with a correct `[r3-local]` section. `dnf repolist` does not show it. Why?

??? question "Answer"
    Only files whose names end in `.repo` are read. Rename it to `r3-local.repo`. The same rule makes `r3-local.repo.bak` invisible, which is a common reason a "disabled" repository refuses to come back.

### 4. baseurl

`/srv/r3/repo` contains `zsh-5.9-15.el10.x86_64.rpm` and `repodata/`. Which value of `baseurl` is correct?

??? question "Answer"
    `baseurl=file:///srv/r3/repo` — the directory that **contains** `repodata/`. Pointing at `repodata/` itself does not work, and neither does a bare path without the `file://` scheme.

### 5. Counting the slashes

Explain `file:///srv/r3/repo`, including why there are three slashes.

??? question "Answer"
    `file:` is the scheme, `//` introduces an (empty) authority, and `/srv/r3/repo` is the absolute path. With two slashes the path is parsed as something other than an absolute local path, and `dnf` fails to read the repository. The same convention applies to `gpgkey=file:///etc/pki/...`.

### 6. An empty repository

`dnf repoinfo r3-local` prints `Repo-pkgs : 0` even though the directory holds an RPM. What is missing?

??? question "Answer"
    The metadata was generated before the RPM was copied in, so `repodata/` does not describe it. Run `createrepo_c --update /srv/r3/repo` (or `createrepo_c` again) and then `dnf clean all` so the cached copy of the old metadata is discarded.

### 7. Enabling for one command

What is the difference between these two commands?

```bash
dnf --disablerepo='*' --enablerepo=r3-local install zsh
dnf config-manager --set-disabled baseos appstream extras crb
```

??? question "Answer"
    The first changes the repository selection for that one command only; nothing is written to disk, so a reboot restores the previous behaviour. The second rewrites `enabled=0` in the `.repo` files, which is persistent. Also note the quotes around `*`: unquoted, the shell expands it to the filenames in the current directory.

### 8. Why gpgcheck=0

Your own repository file sets `gpgcheck=0`. Is that a mistake?

??? question "Answer"
    Not for a repository you built by hand from packages you already trust: there is no key on the machine that signed them, so `gpgcheck=1` would refuse every package. It is a decision, not a default — you are trusting the disk (or the transport) instead of a signature. For anything arriving over a network, `gpgcheck=1` plus a `gpgkey=` is the correct configuration.

### 9. Reading a removal

`rpm -q tree` prints `package tree is not installed` and exits 1. Is that an error?

??? question "Answer"
    It is the normal answer for a package that is not installed, and the non-zero exit status is deliberate: it makes `rpm -q` usable in a script. `dnf list installed tree` says the same thing differently, with `Error: No matching Packages to list`.

### 10. Undoing a transaction

You removed a package that three others depended on, and they went with it. What can get them back?

??? question "Answer"
    `dnf history` to find the transaction id, then `dnf history undo <id>`. It works only if later transactions have not changed the same packages, and it will not resurrect anything you removed from a repository in the meantime. Reading the transaction summary before confirming is the cheaper fix.

### 11. The slow `provides`

Why can `dnf provides /usr/bin/zsh` take minutes on its first run, while `rpm -qf /usr/bin/zsh` answers immediately?

??? question "Answer"
    `dnf provides` may have to download the filelists metadata for every enabled repository — it maps paths, and repositories do not ship that in the primary metadata. `rpm -qf` asks the local database, which already knows the file list of everything installed.

### 12. Remote versus repository

In one sentence each: what is a Flatpak remote, and where is its configuration stored?

??? question "Answer"
    A remote is a named OSTree repository that Flatpak installs applications and runtimes from — the Flatpak equivalent of a `.repo` file. For the system installation the configuration lives in `/var/lib/flatpak/repo/config`; a `--user` remote lives under `~/.local/share/flatpak`.

### 13. The disappearing disk space

`flatpak list --app` shows nothing, but `/var/lib/flatpak` is 1.8 GB. What is using the space?

??? question "Answer"
    The runtimes. Removing an application does not remove the runtime it depended on, because other applications may share it. `flatpak uninstall --unused` removes runtimes that nothing installed depends on, and the directory drops to around 100 MB.

### 14. Invisible applications

You ran `flatpak install --user flathub org.gnome.Calculator` as `labuser`. As root, `flatpak list` shows nothing. Is the install broken?

??? question "Answer"
    No. `--user` installs into that user's home and is a separate store from the system installation. Use `flatpak list --user` as that user, or install system-wide (the default) if every account should see it. Mixing the two scopes is the usual cause of "I installed it but it is not there".

### 15. What survives a reboot

Which of these survive a reboot: a `.repo` file you wrote, a package you installed, a `--enablerepo` flag you passed, a Flatpak remote, the `dnf` metadata cache?

??? question "Answer"
    The `.repo` file, the installed package, and the Flatpak remote all survive, because each is stored on disk — `/etc/yum.repos.d`, `/var/lib/rpm` plus `/usr`, and `/var/lib/flatpak`. The `--enablerepo` flag was an argument to one command and is gone. The metadata cache under `/var/cache/dnf` usually survives too, but it is not state: deleting it changes nothing except the next command's speed.

### 16. Reading the error

After disabling every distro repository, `dnf -y install cowsay` fails with `Error: Unable to find a match: cowsay`. Is the network down?

??? question "Answer"
    No. `dnf` never contacted anything: no **enabled** repository offers a package called `cowsay`. That is the same failure you get on the exam machine with the wrong repository configuration, and no amount of retrying fixes it. Either enable the repository that has the package, or put the package into a local repository.
