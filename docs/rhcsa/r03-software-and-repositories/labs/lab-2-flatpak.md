# Lab 2 — Flatpak remotes and applications

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R3 — Software and repositories |
| **Time** | 45–60 minutes, including a large download |
| **Check** | `./bin/lab check r03 lab2` |
| **Skills** | `flatpak remote-add`, `remote-info`, `search`, `install`, `list`, `uninstall --unused` |

</div>

## What you are building

| Item | End state |
|---|---|
| Package `flatpak` | Installed from the distro repositories |
| Remote `flathub` | Configured for the system installation, pointing at `dl.flathub.org` |
| Application `org.gnome.Calculator` | Installed, inspected, then removed |
| Runtimes | Removed with `flatpak uninstall --unused` |
| `/var/lib/flatpak` | Back to roughly its starting size |

The lab ends with a configured remote and nothing installed. That is a normal state for a server: you configure where applications come from, and you keep the disk for the applications that are actually needed.

This lab needs internet access to reach Flathub. The RPM half of the module is the half that works offline.

## Before you begin

Continue on the same `server` VM. If you restored the snapshot, redo [Lab 1](lab-1-rpm-repositories.md) first — the checker does not require it, but the theory assumes you have built a repository.

```bash
cd labs
./bin/lab ssh
sudo -i
```

## Step 1 — Install the Flatpak tooling

```bash
dnf -y install flatpak
rpm -q flatpak
flatpak --version
```

```text
Installed:
  flatpak-1.16.0-9.el10_2.6.x86_64
  ...
Complete!
flatpak-1.16.0-9.el10_2.6.x86_64
Flatpak 1.16.0
```

The transaction is much bigger than the package name suggests — on a minimal server it pulls in around a hundred packages, including `xdg-desktop-portal` and the graphics libraries an application expects. This is the same trade-off as any desktop stack on a server: you install it because the objective requires it, and you should notice how much it brought along.

## Step 2 — Look at the remote list before you add one

```bash
flatpak remotes
```

A fresh system has no output: no remotes are configured, so there is nowhere to install from. A remote is the Flatpak equivalent of a `.repo` file, except that it is stored in `/var/lib/flatpak/repo/config` rather than in `/etc/yum.repos.d/`.

## Step 3 — Configure the Flathub remote

```bash
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak remotes
flatpak remotes --columns=name,url,options
```

```text
flathub	system
flathub	https://dl.flathub.org/repo/	system
```

`--if-not-exists` makes the command safe to rerun — a good habit in any provisioning script. The `.flatpakrepo` URL is a small description file that carries the remote's GPG key, which is how Flatpak establishes trust without a separate key import.

The second column is the **scope**. `system` means the remote is usable by every account on the machine and applications land in `/var/lib/flatpak`. A `--user` remote lives in one home directory instead, needs no root, and is invisible to `flatpak list` run without `--user`.

## Step 4 — Inspect an application before installing it

```bash
flatpak remote-info flathub org.gnome.Calculator
flatpak search calculator
```

```text
        ID: org.gnome.Calculator
       Ref: app/org.gnome.Calculator/x86_64/stable
      Arch: x86_64
    Branch: stable
Collection: org.flathub.Stable
  Download: 2.0 MB
 Installed: 5.1 MB
   Runtime: org.gnome.Platform/x86_64/51
       Sdk: org.gnome.Sdk/x86_64/51
```

```text
Calculator	A feature rich calculator	org.kde.kalk	26.08.3	stable	flathub
Curo Calculator	Financial calculations simplified	app.curocalc.calculator	2.6.2	stable	flathub
BMI Calculator	Calculate your BMI	io.github.johannesboehler2.BmiCalculator	1.6.2	stable	flathub
```

Two things to read from that:

- The **application id** is `org.gnome.Calculator`. That is what every command takes. The name in the search result ("Calculator") is a label, and the third column of the search output is a different application with a similar name.
- `Runtime: org.gnome.Platform/x86_64/51` is the shared runtime the app needs. It is not included in the 5.1 MB installed size.

## Step 5 — Install the application

```bash
flatpak install -y flathub org.gnome.Calculator
```

```text
Installing 7/7… ██████████████████████████████ 100%
Installation complete.
```

Seven objects are transferred: the application, its locale extension, and the runtime plus its graphics drivers. On a fast connection this takes a couple of minutes; the runtime is most of the download.

```bash
flatpak list --app --columns=application,version,origin
```

```text
org.gnome.Calculator	51.1	flathub
```

```bash
flatpak list --runtime --columns=application,branch,origin
```

```text
org.freedesktop.Platform.GL.default	26.08	flathub
org.freedesktop.Platform.GL.default	26.08-extra	flathub
org.freedesktop.Platform.codecs-extra	26.08-extra	flathub
org.gnome.Platform	51	flathub
```

`--columns` selects the fields you want. Plain `flatpak list` prints a wider table — display name, application id, version, branch, and whether it is the `system` or a `user` installation — and mixes applications with runtimes. `--app` and `--runtime` split them, which matters when you are looking for what is using space.

```bash
flatpak info org.gnome.Calculator
du -sh /var/lib/flatpak
```

```text
          ID: org.gnome.Calculator
         Ref: app/org.gnome.Calculator/x86_64/stable
        Arch: x86_64
      Branch: stable
     Version: 51.1
     License: GPL-3.0-or-later
      Origin: flathub
  Collection: org.flathub.Stable
Installation: system
   Installed: 5.1 MB
     Runtime: org.gnome.Platform/x86_64/51
         Sdk: org.gnome.Sdk/x86_64/51
1.8G	/var/lib/flatpak
```

One application, 1.8 GB on disk. `Installed: 5.1 MB` describes the app only; the runtime and its drivers are shared with every GNOME application you install later, and they are large.

!!! note "Why `flatpak run` will not work here"
    `flatpak run org.gnome.Calculator` needs a graphical session. `server` is a headless VM, so it fails. Install, list, inspect, and remove all work fine, and those are the operations the exam asks about.

## Step 6 — Remove the application, then reclaim the runtime

```bash
flatpak uninstall -y org.gnome.Calculator
flatpak list --app --columns=application
```

```text
Uninstalling 1/2…
Uninstalling 2/2…
Uninstall complete.
```

The `list` command prints nothing — the application is gone. The runtimes are not:

```bash
flatpak list --runtime --columns=application
du -sh /var/lib/flatpak
```

```text
org.freedesktop.Platform.GL.default
org.freedesktop.Platform.GL.default
org.freedesktop.Platform.codecs-extra
org.gnome.Platform
1.8G	/var/lib/flatpak
```

That is the trap this lab exists to show: nothing is installed, and the disk is still nearly full. Remove what nothing depends on:

```bash
flatpak uninstall --unused -y
flatpak list --runtime --columns=application
du -sh /var/lib/flatpak
```

```text
Uninstalling 1/5…
Uninstalling 2/5…
Uninstalling 3/5…
Uninstalling 4/5…
Uninstalling 5/5…
Uninstall complete.
111M	/var/lib/flatpak
```

The `list` command prints nothing, and more than a gigabyte has come back. `--unused` only removes runtimes that no installed application depends on, so it is safe to run whenever you remove an app. The exact size left behind varies with what was cached; the drop is what matters.

## Step 7 — Reboot and prove persistence

```bash
reboot
```

From the host, reconnect and check that the remote and the (empty) application set survived:

```bash
cd labs
./bin/lab ssh
sudo -i
flatpak remotes
flatpak list
```

```text
flathub	system
```

An empty second line is the correct answer for `flatpak list`: you removed the application and its runtime. The remote is a file under `/var/lib/flatpak/repo/config`, so it survives the reboot.

## Step 8 — Run the checker

```bash
./bin/lab check r03 lab2
```

<details>
<summary>Show the expected check output</summary>

```text
R3 Lab 2 — Flatpak
  PASS  package flatpak is installed
  PASS  the flathub remote is configured
  PASS  flathub is the system-wide installation
  PASS  flathub points at dl.flathub.org
  PASS  no Flatpak application is installed
  PASS  no Flatpak runtime is installed
```

</details>

The checker can only see the end state, so it verifies the remote configuration and that the store is clean. It cannot tell that you installed an application first — that part of the lab is yours to confirm against the output above.

## What to remember

- A Flatpak **remote** is configured once; applications come from it by name.
- Application ids are reverse-DNS (`org.gnome.Calculator`), not the display name.
- `--user` and system scope are separate stores; `flatpak list` shows one of them unless you ask.
- Removing an application leaves its runtime behind; `flatpak uninstall --unused` reclaims it.
- `flatpak run` needs a graphical session; everything else works on a headless server.
- Flatpak state lives in `/var/lib/flatpak`, so it survives a reboot.
