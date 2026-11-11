# R11 — Boot, rescue, and updates

<div class="module-meta" markdown>

| | |
|---|---|
| **Exam objective groups** | 4 — Operate running systems, and 7 — Deploy, configure, and maintain systems |
| **Time** | 5–6 hours including labs |
| **Prerequisites** | [R5 — Processes and services](../r05-processes-and-services/index.md) for systemd units and targets, and [R8 — Scheduling and time](../r08-scheduling-and-time/index.md) for the habit of checking that a change survives a reboot |
| **Labs** | 2 guided labs + 1 challenge |
| **Check command** | `./bin/lab check r11 lab1` (also `lab2` and `challenge`) |

</div>

Everything in R1–R10 assumed the machine was already running. R11 is about the part that happens first: the firmware, the bootloader, the kernel, and the moment systemd takes over. It is also about what to do when that sequence does not end at a login prompt.

This is the module where a mistake can cost you the machine. That is not a reason to avoid it. It is the reason the lab kit gives you a serial console, snapshots, and a second VM: you can break the boot on purpose, watch it fail, and fix it without reinstalling anything.

The exam asks three things in this area:

- boot into a different target, by hand and automatically;
- interrupt the boot to get a root shell when you cannot log in;
- modify the bootloader and update the system without breaking either.

Those look like three topics. They are one skill: knowing **where each setting lives**, and whether it applies to this boot or the next one.

## The boot chain

A Linux boot is a relay race. Each stage hands control to the next, and each one has its own configuration.

```text { .no-copy }
power on
  │
  ├─ firmware (BIOS or UEFI)
  │    picks a boot device and runs its bootloader
  │
  ├─ bootloader (GRUB 2)
  │    reads /boot/grub2/grub.cfg
  │    builds the menu from /boot/loader/entries/*.conf
  │    loads the selected kernel and initramfs into memory
  │
  ├─ kernel
  │    starts from the initramfs (a small temporary root filesystem)
  │    loads storage and filesystem drivers, assembles LVM/RAID
  │    mounts the real root filesystem
  │    switch_root → the real init
  │
  └─ systemd (PID 1)
       reads its default target and starts the units that target needs
       reaches multi-user.target or graphical.target
```

Two consequences follow from that picture, and they explain most of this module:

1. **There are several places to intervene.** You can change what the bootloader will do (persistent), or override it for one boot (temporary). You can stop in the initramfs before the real root is mounted, or in systemd after it is.
2. **"It works now" is not the same as "it will work after a reboot".** A `systemctl isolate` changes the running system. A `systemctl set-default` changes the next boot. Both are correct tools; mixing them up is the classic mistake.

### The initramfs, in one paragraph

The kernel cannot mount the real root filesystem by itself when that filesystem is on LVM, on a software RAID array, or behind an encrypted device. So the bootloader also loads an **initramfs**: a compressed mini-system that the kernel unpacks into memory and runs as a temporary root. It loads the needed drivers, finds the real root, mounts it, and then calls `switch_root` to hand control to the real `/usr/lib/systemd/systemd`.

On RHEL the initramfs is built by **dracut** and stored as `/boot/initramfs-<version>.img`. You will meet it again in Lab 2, because `rd.break` stops the boot *inside* it, before `switch_root`.

## Targets

A **target** is a named group of units that systemd brings the system to. It replaces the old SysV runlevels, and the familiar numbers still work as aliases.

| Target | Runlevel | What it means |
|---|---|---|
| `poweroff.target` | 0 | Shut down |
| `rescue.target` | 1 | Single-user; root shell through `sulogin`; most services and networking are not started |
| `multi-user.target` | 3 | Text-mode multi-user; networking and normal services; no display manager |
| `graphical.target` | 5 | `multi-user.target` plus a display manager |
| `reboot.target` | 6 | Reboot |
| `emergency.target` | — | More minimal than rescue; the root filesystem is mounted read-only and almost nothing else starts |

`rescue.target` and `emergency.target` are not "safe modes" in the Windows sense. They are real boot targets with almost no services, which is exactly why they are useful when a service is what broke the boot.

### `get-default`, `set-default`, `isolate`

Three commands, three different questions:

```bash
systemctl get-default
```

```text { .no-copy }
multi-user.target
```

`get-default` reads `/etc/systemd/system/default.target`, which is a symlink to the target systemd should reach at boot:

```bash
ls -l /etc/systemd/system/default.target
```

```text { .no-copy }
lrwxrwxrwx. 1 root root 41 Sep 14 12:45 /etc/systemd/system/default.target -> /usr/lib/systemd/system/multi-user.target
```

To change the **running system** without touching the next boot:

```bash
systemctl isolate graphical.target
systemctl get-default
```

```text { .no-copy }
multi-user.target
```

`get-default` still says `multi-user.target`, because `isolate` started the units `graphical.target` needs but did not rewrite the default symlink. Reboot, and you are back in `multi-user.target`.

To change the **next boot**:

```bash
systemctl set-default graphical.target
systemctl get-default
```

```text { .no-copy }
Removed '/etc/systemd/system/default.target'.
Created symlink '/etc/systemd/system/default.target' → '/usr/lib/systemd/system/graphical.target'.
graphical.target
```

That pair is the whole lesson. The exam will ask you to make a target survive a reboot; if you use `isolate`, it will not.

!!! note "On a headless server, graphical is nearly multi-user"
    `graphical.target` pulls in `multi-user.target` and then `display-manager.service`. The lab VMs have no display manager installed, so the machine reaches `graphical.target` and simply has no graphical login. The difference is small in practice, but the setting is real, survives a reboot, and is easy to verify. The lab uses it in both directions: it sets `graphical.target`, reboots to prove the setting persists, and then returns the machine to `multi-user.target`, which is what a headless server should run.

### Checking what is active

```bash
systemctl list-units --type=target
```

```text { .no-copy }
  basic.target             loaded active active Basic System
  getty.target             loaded active active Login Prompts
  local-fs.target          loaded active active Local File Systems
  multi-user.target        loaded active active Multi-User System
  network.target           loaded active active Network
  ...
```

Only the targets that are **active** appear. After `systemctl isolate graphical.target`, `graphical.target` joins the list. After `systemctl isolate multi-user.target`, it leaves.

`systemd-analyze` answers a different question: how long each stage took.

```bash
systemd-analyze time
systemd-analyze blame | head -5
```

```text { .no-copy }
Startup finished in 895ms (kernel) + 1.967s (initrd) + 4.384s (userspace) = 7.247s
multi-user.target reached after 3.821s in userspace.
2.609s sys-devices-platform-serial8250-serial8250:0-serial8250:0.2-tty-ttyS2.device
2.609s dev-ttyS2.device
2.575s dev-ttyS0.device
2.568s sys-devices-platform-serial8250-...-ttyS1.device
```

The three numbers are the kernel, the initramfs, and userspace. If a machine is slow to boot, the split tells you which of the three to investigate. `systemd-analyze critical-chain` shows the dependency chain that decided the finish time.

## The bootloader

RHEL 10 uses **GRUB 2**. It is configured in two layers, and confusing them is the most common source of "I changed it and nothing happened".

### Layer 1: the source of truth

`/etc/default/grub` holds the settings an administrator is meant to edit:

```bash
cat /etc/default/grub
```

```text { .no-copy }
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console serial"
GRUB_CMDLINE_LINUX="no_timer_check biosdevname=0 net.ifnames=0 console=tty0 console=ttyS0,115200n8"
GRUB_DISABLE_RECOVERY="true"
GRUB_ENABLE_BLSCFG=true
GRUB_TERMINAL_INPUT="console serial"
GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"
```

Two lines matter for this module:

- `GRUB_TIMEOUT=5` is how long the menu waits before booting the default entry. `0` hides the menu; a positive number gives you time to press `e`.
- `GRUB_CMDLINE_LINUX` is the set of kernel arguments that every entry starts from.

The lab kit added the `console=`, `serial`, and `terminal_*` lines so that the GRUB menu and the boot messages appear on **both** the virtual screen and the serial console. Without them, a learner who attaches with `./bin/lab console server` would see a silent machine until the login prompt.

### Layer 2: the generated menu

`/boot/grub2/grub.cfg` is generated. It is the file GRUB actually reads:

```bash
grub2-mkconfig -o /boot/grub2/grub.cfg
```

```text { .no-copy }
Generating grub configuration file ...
Adding boot menu entry for UEFI Firmware Settings ...
done
```

Do not edit `grub.cfg` by hand. The next kernel update or `grub2-mkconfig` run will overwrite it. Change `/etc/default/grub`, then regenerate.

The output mentions a UEFI firmware entry even though this VM boots legacy BIOS. `/etc/grub.d/30_uefi-firmware` prints that line every time it runs, whatever the firmware. The `menuentry` it writes is wrapped in `if [ "$grub_platform" = "efi" ]`, and `/sys/firmware/efi` does not exist here, so the entry never reaches the menu. The message is normal.

### Boot Loader Specification (BLS)

Look at the generated menu and you will not find one big `menuentry` per kernel. Instead you find:

```bash
ls /boot/loader/entries
grep -H options /boot/loader/entries/*.conf
```

```text { .no-copy }
747b95e22dbe4f9da4edd3b4537bf951-6.12.0-211.53.1.el10_2.x86_64.conf
7a94f52d4c9d451eacc54509281ea671-6.12.0-211.74.2.el10_2.x86_64.conf
...747b...conf:options root=UUID=bfdf... ro no_timer_check biosdevname=0 net.ifnames=0 console=tty0 console=ttyS0,115200n8
...7a94...conf:options root=UUID=bfdf... ro no_timer_check biosdevname=0 net.ifnames=0 $tuned_params console=tty0 console=ttyS0,115200n8
```

Each installed kernel has its own small file in `/boot/loader/entries/`. GRUB's `blscfg` command reads them and builds the menu at boot time. This is the **Boot Loader Specification**, and RHEL 10 enables it with `GRUB_ENABLE_BLSCFG=true`.

The important consequence: **`grub2-mkconfig` does not rewrite these files.** Each entry carries its own `options` line, and that line is what the kernel actually receives. If you add an argument only to `/etc/default/grub`, existing kernels will not see it. That is why the tool for kernel arguments is `grubby`, not `grub2-mkconfig`.

### `grubby`

`grubby` edits the BLS entries (and, on RHEL, keeps `/etc/default/grub` and `/etc/kernel/cmdline` in step):

```bash
grubby --info=ALL
```

```text { .no-copy }
index=0
kernel="/boot/vmlinuz-6.12.0-211.53.1.el10_2.x86_64"
args="ro no_timer_check biosdevname=0 net.ifnames=0 console=tty0 console=ttyS0,115200n8"
root="UUID=bfdf6531-5328-4725-a424-ff1ef506b6a4"
initrd="/boot/initramfs-6.12.0-211.53.1.el10_2.x86_64.img"
title="AlmaLinux (6.12.0-211.53.1.el10_2.x86_64) 10.2 (Lavender Lion)"
id="747b95e22dbe4f9da4edd3b4537bf951-6.12.0-211.53.1.el10_2.x86_64"
index=1
kernel="/boot/vmlinuz-6.12.0-211.74.2.el10_2.x86_64"
args="ro no_timer_check biosdevname=0 net.ifnames=0 $tuned_params console=tty0 console=ttyS0,115200n8"
...
```

`--default-kernel`, `--default-index`, `--set-default`, `--add-kernel`, and `--remove-kernel` choose which entry boots. `--update-kernel=ALL --args=...` and `--remove-args=...` change the arguments on every entry.

The `$tuned_params` and `$tuned_initrd` tokens are filled in by `tuned` at boot. They are not a mistake; leave them alone.

### The menu environment

GRUB has a tiny key/value store called `grubenv`, managed by `grub2-editenv`:

```bash
grub2-editenv list
```

```text { .no-copy }
saved_entry=7a94f52d4c9d451eacc54509281ea671-6.12.0-211.74.2.el10_2.x86_64
menu_auto_hide=0
boot_success=0
boot_indeterminate=0
```

`menu_auto_hide` is the one that surprises people. The `12_menu_auto_hide` script hides the menu after a successful boot even when `GRUB_TIMEOUT` is not zero. A hidden menu is a menu you cannot press `e` on. The lab kit sets `menu_auto_hide=0` so the timeout is always visible:

```bash
grub2-editenv - set menu_auto_hide=0
```

## Kernel arguments

A kernel argument is a word on the kernel's command line. Some are understood by the kernel itself (`panic=10`, `console=...`), some by dracut (`rd.break`), and some by systemd (`systemd.unit=...`). The syntax is the same: `name` or `name=value`, separated by spaces.

### Temporary: the GRUB editor

At the GRUB menu:

1. Press any key to stop the countdown.
2. Highlight the entry and press `e`.
3. Move to the `linux` line. On this image it is the third line down, after `load_video` and `insmod gzio`.
4. Press ++ctrl+e++ to jump to the end of that line.
5. Type the argument, with a leading space.
6. Press ++ctrl+x++ to boot, or ++esc++ to discard the edit.

That change applies to **this boot only**. It is not written anywhere. It is the right tool for a one-off rescue and the wrong tool for a permanent setting.

### Persistent: `grubby`

```bash
grubby --update-kernel=ALL --args=panic=10
```

That one command updates every BLS entry, `/etc/default/grub`, and `/etc/kernel/cmdline`. A kernel installed later inherits the setting from `/etc/kernel/cmdline`.

To remove an argument:

```bash
grubby --update-kernel=ALL --remove-args=panic=10
```

A reboot is required before the running kernel sees either change. `grubby --info=ALL` proves the configuration; `/proc/cmdline` proves the boot.

### Where the argument has to live

| Layer | File | Updated by | Affects |
|---|---|---|---|
| Administrator intent | `/etc/default/grub` | you, or `grubby` | future `grub2-mkconfig` runs |
| Generated menu | `/boot/grub2/grub.cfg` | `grub2-mkconfig` | the menu GRUB shows |
| Per-kernel arguments | `/boot/loader/entries/*.conf` | `grubby`, kernel install | **this is what the kernel receives** |
| New kernels | `/etc/kernel/cmdline` | `grubby` | kernels installed later |
| This boot | `/proc/cmdline` | the bootloader | the running kernel |

The fourth column of that table is the whole module in one line: the BLS entry wins. A setting that is only in `/etc/default/grub` is a setting that existing kernels do not have.

### `systemd.unit=`

`systemd.unit=rescue.target` on the kernel command line tells systemd to reach a different target for this boot, ahead of the default. It is a one-boot override and it does not change `get-default`:

```text { .no-copy }
Note: found "systemd.unit" on the kernel command line, which overrides the default unit.
```

That note is systemd telling you why the machine is not in the target you configured. It is a feature, not an error.

## Interrupting the boot

There are three doors into a broken machine, and they open at different moments.

| Door | How | Where you land | Root filesystem | Services | Use it when |
|---|---|---|---|---|---|
| `rd.break` | GRUB `e`, append `rd.break` | dracut emergency shell, before `switch_root` | `/sysroot`, mounted read-only | none | You forgot the root password, or `/etc` is broken |
| `init=/bin/bash` | GRUB `e`, append `init=/bin/bash` | a bash shell as PID 1 | `/`, usually mounted read-only | none; systemd never starts | You need a shell on the real root and do not need the initramfs |
| `systemd.unit=rescue.target` | GRUB `e`, append `systemd.unit=rescue.target` | systemd rescue mode, `sulogin` asks for the root password | `/`, read-write | almost none; networking and `sshd` are down | You know the root password but a service or target is broken |

All three start the same way: reboot, catch the menu, press `e`, go to the `linux` line, append the argument, ++ctrl+x++.

### `rd.break` in detail

`rd.break` makes dracut stop after it has mounted the real root at `/sysroot` but before it switches to it. On this image you land in dracut's emergency mode:

```text { .no-copy }
Entering emergency mode. Exit the shell to continue.
Type "journalctl" to view system logs.
...
Press Enter for maintenance
(or press Control-D to continue):
sh-5.2#
```

Press ++enter++ to get the shell. Then:

```bash
mount -o remount,rw /sysroot
chroot /sysroot
passwd root
touch /.autorelabel
exit
exit
```

The first line matters. `/sysroot` is mounted **read-only**, and `passwd` cannot write `/etc/shadow` on a read-only filesystem. Skip the remount and you get `Authentication token manipulation error`, which sounds like a password problem and is really a mount problem.

`chroot /sysroot` makes the real root the root of the shell. Everything you do after that — `passwd`, `touch /.autorelabel`, editing `/etc/fstab` — happens to the installed system, not to the initramfs.

The two `exit`s leave the chroot and then the dracut shell. The boot continues, sees `/.autorelabel`, relabels the filesystem, and reboots itself. The relabel boot takes longer than a normal boot; that is expected.

### Why `/.autorelabel`

SELinux is not enforcing inside the initramfs. Files you create or rewrite there may end up with no label or the wrong one. `passwd` rewrites `/etc/shadow`, so after a recovery `/etc/shadow` can be missing its `shadow_t` label. The login program runs as `login_t` and is not allowed to read an unlabelled shadow file, so the machine rejects every password, including the one you just set.

`touch /.autorelabel` asks systemd to run a full relabel on the next boot. The relabel boot rewrites every label from policy, removes `/.autorelabel`, and reboots again. Then the labels are correct and the login works.

Inside the chroot, `ls -Z` shows a `?` in the label column for the files you touched. That is the symptom to recognise. After the relabel boot, the same files show `system_u:object_r:shadow_t:s0` and `system_u:object_r:admin_home_t:s0`.

### `init=/bin/bash`

`init=/bin/bash` replaces the program the kernel runs as PID 1. systemd never starts. You get a bash prompt on the console with the real root mounted, usually read-only:

```text { .no-copy }
bash-5.2# id
uid=0(root) gid=0(root) groups=0(root)
bash-5.2# ps -p 1 -o pid,comm=
    PID COMMAND
      1 bash
bash-5.2# findmnt -no TARGET,FSTYPE,OPTIONS /
/ xfs ro,relatime,attr2,inode64,logbufs=8,logbsize=32k,noquota
bash-5.2# systemctl is-system-running
offline
```

Remount the root read-write before changing anything:

```bash
mount -o remount,rw /
```

There is no job control, no login environment, and no `systemd`. A `touch` in that shell produced a mode `0666` file because the usual `umask` comes from the login process, which never ran. When you are done, `exec /usr/sbin/init` replaces bash with systemd and lets the boot continue, or `reboot -f` restarts immediately.

This door is faster than `rd.break` when you do not need to change the initramfs's view of the root. It is also less forgiving: a mistake in `/etc` is live immediately, with no systemd to fall back on.

### Rescue mode and `sulogin`

`systemd.unit=rescue.target` boots systemd, but only as far as rescue mode. `sulogin` asks for the **root** password:

```text { .no-copy }
You are in rescue mode. After logging in, type "journalctl -xb" to view
system logs, "systemctl reboot" to reboot, or "exit"
to continue bootup.
Give root password for maintenance
(or press Control-D to continue):
```

This is the door to use when the root password still works but a normal boot does not. Networking and `sshd` are not running, so you cannot reach the machine over SSH; you need the console. To return to a normal system without rebooting:

```bash
systemctl isolate multi-user.target
```

That is the same `isolate` from the targets section, used for recovery. It starts the normal units and leaves rescue mode. `systemctl get-default` is unchanged, and the `systemd.unit=` note explains why the boot-time override is still on the command line.

`emergency.target` is one step further: the root filesystem is mounted read-only and almost nothing else starts. It is useful when even rescue mode's mounts are the problem.

## Software updates

An update is two questions: *is anything newer?* and *did it apply?*

```bash
dnf check-update
```

`dnf check-update` exits `100` when updates are available, `0` when there are none, and `1` when the check itself failed. The exit code is the reliable answer; the list is for humans.

```bash
dnf -y upgrade
```

`dnf upgrade` and `dnf update` are aliases. `upgrade` is the safer spelling in documentation because it cannot be confused with the old `yum update` behaviour. It resolves dependencies, downloads, and applies the transaction.

### The kernel is special

A kernel update does **not** replace the running kernel. `dnf` installs the new kernel alongside the old one, adds a new BLS entry, and makes the new entry the default. The machine keeps running the old kernel until you reboot.

That is why the end state is checked in two places:

```bash
uname -r
rpm -q --last kernel-core | head -3
```

```text { .no-copy }
6.12.0-211.74.2.el10_2.x86_64
kernel-core-6.12.0-211.74.2.el10_2.x86_64     Wed 11 Nov 2026 04:54:25 AM UTC
kernel-core-6.12.0-211.53.1.el10_2.x86_64     Mon 14 Sep 2026 12:43:58 PM UTC
```

`uname -r` is the kernel that is running. `rpm -q --last` is the set that is installed, newest first. After a kernel update and before a reboot, the two disagree, and that is normal. The challenge requires them to agree, which means a reboot.

Old kernels are kept so you can boot one if the new one fails. Remove them with `dnf remove --oldinstallonly` when the list grows; do not remove the running kernel.

### `dnf history`

Every transaction is recorded:

```bash
dnf history
```

```text { .no-copy }
ID     | Command line             | Date and time    | Action(s)      | Altered
-------------------------------------------------------------------------------
     2 | -y upgrade               | 2026-11-11 05:09 | I, U           |   66
     1 | -y install man-db man-pa | 2026-11-11 04:54 | I, U           |   31 EE
```

`dnf history info 2` shows the return code, the user, and every package the transaction changed. `dnf history undo 2` reverses a transaction. Undo is a real tool, but it is not a backup: a kernel or glibc change may not be cleanly reversible, and packages installed from a repository that no longer carries the old version cannot be rolled back.

### Does the update need a reboot?

`dnf needs-restarting -r` answers that question: it exits `1` when a reboot is needed and `0` when it is not, so a script can branch on the status directly. The command comes from `dnf-plugins-core`, which is not installed in the base image. Install it in the lab if you want to use it; the checker deliberately does not depend on it.

The older, still useful `needs-restarting` without `-r` lists processes that are running an old version of a library. On a server, the honest answer after a kernel or systemd update is "reboot at the next maintenance window".

### The safer production path

`dnf offline-upgrade` downloads the updates, then reboots into a minimal environment that applies them before the normal services start. It avoids updating a running system underneath itself, which matters for systemd, glibc, and the kernel. It is mentioned here so you recognise it; the lab uses the ordinary `dnf upgrade` because seeing the transaction and the reboot is the lesson.

## What survives a reboot

| Change | Survives? | Where it lives |
|---|---|---|
| `systemctl isolate graphical.target` | No | The running system only |
| `systemctl set-default graphical.target` | Yes | `/etc/systemd/system/default.target` |
| `GRUB_TIMEOUT` edited in `/etc/default/grub` | Only after `grub2-mkconfig` | `/etc/default/grub` → `/boot/grub2/grub.cfg` |
| `grubby --update-kernel=ALL --args=...` | Yes | Every BLS entry, `/etc/default/grub`, `/etc/kernel/cmdline` |
| A GRUB-editor edit | No | That boot only |
| An argument only in `/etc/default/grub` | Not for existing kernels | BLS entries win |
| `/.autorelabel` | Exactly one boot | Deleted by the relabel |
| A new root password | Yes | `/etc/shadow` |
| A package update | Yes | The RPM database and `/boot` |
| The new kernel actually running | Only after a reboot | The old kernel keeps running until then |

## Traps worth memorising

| Trap | What actually happens | The fix |
|---|---|---|
| `isolate` when you meant `set-default` | The change works until the next reboot | `systemctl set-default` |
| Edited `grub.cfg` by hand | The next `grub2-mkconfig` or kernel update overwrites it | Edit `/etc/default/grub`, then regenerate |
| Added an argument to `/etc/default/grub` only | Existing kernels never see it | `grubby --update-kernel=ALL --args=...` |
| `GRUB_TIMEOUT=0`, or `menu_auto_hide=1` | There is no menu to press `e` on | Set a timeout and `menu_auto_hide=0` |
| Forgot `mount -o remount,rw /sysroot` | `passwd` fails with `Authentication token manipulation error` | Remount read-write first |
| Forgot `touch /.autorelabel` | Login fails even with the new password; `/etc/shadow` has no `shadow_t` label | Touch it inside the chroot, reboot twice |
| Added `rd.break` permanently | Every boot stops in the initramfs | Remove the argument after the rescue |
| Expected SSH in rescue mode | `sshd` is not running | Use the console, or `isolate multi-user.target` |
| `dnf check-update` exited `100` | That means updates are available, not that it failed | Read the exit code |
| Updated the kernel and did not reboot | `uname -r` still shows the old kernel | Reboot, then check again |
| `dnf upgrade` with R3's repositories disabled | `There are no enabled repositories` | Re-enable the distro repositories |
| Read `systemctl is-system-running` under `init=/bin/bash` | It says `offline`; systemd is not running | That is the point of that door |

## How the checker works

`labs/checks/r11/check.sh` reads the boot state in the way each fact is actually decided:

- **Targets** are read from `systemctl get-default` and from the `default.target` symlink, because a target can be active and still not be the default.
- **The menu** is read from both `/etc/default/grub` and the generated `grub.cfg`, because editing one without regenerating the other is the mistake the lab teaches.
- **Kernel arguments** are checked on **every** BLS entry with `grubby --info=ALL`, and then on the running kernel through `/proc/cmdline`. The first proves intent; the second proves the boot.
- **Recovery** is proved by usability (`passwd -S root` must say `P`, not `L`), by the marker file the learner creates inside the chroot, and by the labels only a completed relabel boot can produce. The password itself is never asserted.
- **Updates** are proved by a successful `dnf history` transaction plus `dnf check-update` finding nothing left, and by `uname -r` matching the newest installed `kernel-core`.
- The `panic=10` and `panic_on_warn=1` checks read `/proc/cmdline` and the live sysctl, so they **fail until you reboot**. That is the persistence test, not a broken checker.

Run `./bin/lab check r11 all` only after walking all three phases in order. The challenge assumes Lab 1's kernel argument and Lab 2's recovered root account still hold.

## Next

[Lab 1 — Targets, the menu, and a persistent kernel argument](labs/lab-1-targets-and-grub.md) starts with the running system and ends with a change that is still there after a reboot.
