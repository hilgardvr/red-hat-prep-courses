# Challenge — The offline build server

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R3 — Software and repositories |
| **Time** | 40–60 minutes |
| **Check** | `./bin/lab check r03 challenge` |
| **Style** | Exam task: requirements only, no steps |

</div>

This is the R3 challenge. It is written the way EX200 presents work: a set of required end states, with no command walkthrough. Use the [theory page](../index.md), `man`, and your notes if you need them — but try the whole thing without a recipe first.

You can do this on the machine you used for the two labs, and you should: the challenge assumes the Flathub remote from [Lab 2](lab-2-flatpak.md) is already configured, and it will use the `createrepo_c` you installed in [Lab 1](lab-1-rpm-repositories.md).

## Scenario

`server` is about to be handed to a team that builds software in an isolated network. It must install its own tooling with no access to a mirror, and it must not carry a desktop application store's contents.

Leave the Flathub remote in place for whoever needs a desktop application later, but the machine itself must have no Flatpak applications and no Flatpak runtimes installed.

## Tasks

1. Create a local package repository at `/srv/r3/extra` containing the `tree` package.

2. Configure it as a repository with the id `r3-extra`:
   - enabled at boot
   - `baseurl` is the directory you just created
   - no GPG checking, because nothing in it is signed by a key on this machine

3. Install `tree` on the machine, and make sure the package database records that it came from `r3-extra`, not from a distro repository.

4. Disable the four distro repositories — `baseos`, `appstream`, `extras`, and `crb` — **permanently**, so the machine does not try to reach the internet after a reboot.

5. The `flathub` remote must remain configured for the system installation.

6. No Flatpak application and no Flatpak runtime may be installed.

7. Reboot `server`. After it comes back, every requirement above must still hold.

## Hints

Only if you are stuck.

<details>
<summary>How do I get the `tree` RPM without installing it?</summary>

`dnf download --resolve --destdir /srv/r3/extra tree` — run it **before** you disable the distro repositories, because that is where the package comes from. Then `createrepo_c /srv/r3/extra`.

</details>

<details>
<summary>How do I prove the install used only my repository?</summary>

`dnf --disablerepo='*' --enablerepo=r3-extra -y install tree`, then `dnf list installed tree`. The repository column shows `@r3-extra` when the package came from your repository.

</details>

<details>
<summary>`dnf repoinfo r3-extra` says it cannot find the repository. What is wrong?</summary>

The file must be named with a `.repo` suffix under `/etc/yum.repos.d/`, and the section header must match the id exactly: `[r3-extra]`. A file called `r3-extra.repo.bak` is ignored.

</details>

<details>
<summary>The install fails with "Unable to find a match" after I disabled the distro repos.</summary>

Either the metadata is missing (`ls /srv/r3/extra/repodata/`) or `baseurl` points at `repodata/` instead of its parent. `dnf repoinfo r3-extra` prints the baseurl and the package count; `Repo-pkgs : 0` means the metadata does not describe the RPM you placed there.

</details>

<details>
<summary>Do I have to remove the `r3-local` repository from Lab 1?</summary>

No. It can stay enabled; it simply offers a different package.

</details>

## Verify

From the host:

```bash
./bin/lab check r03 challenge
```

The checker reads the repository directory, both repository configurations, the RPM database, the Flatpak remote list, and the Flatpak install set. It does not care which commands you used.

<details>
<summary>Show the expected check output</summary>

```text
R3 Challenge — The offline build server
  PASS  repository directory exists: /srv/r3/extra
  PASS  the repository contains at least one RPM
  PASS  repository metadata exists: /srv/r3/extra/repodata/repomd.xml
  PASS  repo file exists: /etc/yum.repos.d/r3-extra.repo
  PASS  r3-extra is enabled
  PASS  r3-extra baseurl is file:///srv/r3/extra
  PASS  r3-extra has gpgcheck=0
  PASS  the repository still serves tree
  PASS  package tree is installed
  PASS  tree is recorded as coming from r3-extra
  PASS  distro repo baseos is disabled
  PASS  distro repo appstream is disabled
  PASS  distro repo extras is disabled
  PASS  distro repo crb is disabled
  PASS  the flathub remote is configured
  PASS  no Flatpak application is installed
  PASS  no Flatpak runtime is installed
```

</details>

## After the challenge

Two clean-up steps, in this order.

Run the checker first — it expects the distro repositories to be **disabled**, so re-enabling them before checking turns four passing lines into failures.

Then put the machine back the way the rest of the course expects:

```bash
dnf config-manager --set-enabled baseos appstream extras crb
dnf repolist
```

Optionally remove the extra package and repository:

```bash
dnf remove tree
rm /etc/yum.repos.d/r3-extra.repo
```

Or throw the whole machine away and start the next module from a clean snapshot:

```bash
./bin/lab restore clean
```
