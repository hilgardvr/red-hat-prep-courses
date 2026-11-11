# R11 knowledge check

Answer first, then open the answer. If you miss a question, return to the matching section of the [theory page](index.md).

### 1. The relay race

Put these in boot order: systemd, the initramfs, the bootloader, the kernel, the firmware.

??? question "Answer"
    Firmware → bootloader → kernel → initramfs → systemd. The firmware picks a boot device and runs GRUB; GRUB loads the kernel **and** the initramfs; the kernel runs the initramfs as a temporary root, mounts the real root, and calls `switch_root`; systemd then starts as PID 1 and reaches the default target. The initramfs is not a stage after the kernel; it is the kernel's first userspace.

### 2. `isolate` or `set-default`?

You run `systemctl isolate graphical.target`, confirm that `graphical.target` is active, and reboot. After the reboot the machine is in `multi-user.target`. What did you use, and what should you have used?

??? question "Answer"
    You used `isolate`, which changes the running system only. It starts the units the target needs but does not rewrite `/etc/systemd/system/default.target`, so the next boot goes back to the configured default. `systemctl set-default graphical.target` writes the symlink and survives the reboot.

### 3. Two files, one truth

You add `panic=10` to `GRUB_CMDLINE_LINUX` in `/etc/default/grub`, run `grub2-mkconfig`, and reboot. `grubby --info=ALL` still does not show `panic=10`. Why?

??? question "Answer"
    `grub2-mkconfig` rewrites `/boot/grub2/grub.cfg`, not the per-kernel BLS entries in `/boot/loader/entries/*.conf`. With BLS enabled, each entry carries its own `options` line, and that line is what the kernel receives. Use `grubby --update-kernel=ALL --args=panic=10`, which updates the BLS entries (and, on RHEL, `/etc/default/grub` and `/etc/kernel/cmdline` too).

### 4. The menu that is not there

`GRUB_TIMEOUT=10` is set and `grub.cfg` contains `set timeout=10`, but the machine boots straight through with no visible menu. What is the most likely cause?

??? question "Answer"
    `menu_auto_hide=1` in the GRUB environment. The `12_menu_auto_hide` script hides the menu after a successful boot, even with a positive timeout, by switching the style to `hidden` and the timeout to one second. Check `grub2-editenv list` and set `menu_auto_hide=0` with `grub2-editenv - set menu_auto_hide=0`. `GRUB_TIMEOUT=0` would also hide it, but then `grub.cfg` would say `set timeout=0`.

### 5. Temporary versus permanent

You need `systemd.unit=rescue.target` for one boot. Where do you put it, and what happens to it afterwards?

??? question "Answer"
    At the GRUB menu, press `e`, go to the `linux` line, append ` systemd.unit=rescue.target`, and press ++ctrl+x++. It exists only in that boot's kernel command line. It is not written to `/etc/default/grub` or any BLS entry, `systemctl get-default` is unchanged, and the next boot is normal.

### 6. Three doors

For each situation, name the best boot interruption:

1. You forgot the root password.
2. You know the root password, but a service change makes the normal boot hang.
3. You need a shell on the real root and do not need systemd at all.

??? question "Answer"
    1. `rd.break` — it stops in the initramfs, where you can remount `/sysroot` read-write, `chroot`, and run `passwd`.
    2. `systemd.unit=rescue.target` — systemd starts, `sulogin` asks for the root password, and almost no services run. You can `systemctl isolate multi-user.target` afterwards.
    3. `init=/bin/bash` — the kernel runs bash as PID 1 on the real root; systemd never starts. It is fast, but there are no services, no job control, and the root is usually mounted read-only.

### 7. The read-only root

Inside the `rd.break` shell you run `chroot /sysroot` and then `passwd root`. It fails with `Authentication token manipulation error`. What did you skip?

??? question "Answer"
    `mount -o remount,rw /sysroot`. Dracut mounts the real root read-only, so `passwd` cannot write `/etc/shadow`. The error sounds like a password problem but is a filesystem one. Remount read-write, then run `passwd` again.

### 8. The `?` in `ls -Z`

Inside the chroot, `ls -Z /etc/shadow /root/r11-recovered` prints a `?` where the label should be. Why, and what do you do about it?

??? question "Answer"
    SELinux is not enforcing in the initramfs, so files created or rewritten there have no usable label. Without a fix, login cannot read `/etc/shadow` and rejects every password. Run `touch /.autorelabel` before leaving the chroot. The next boot relabels the filesystem from policy, removes the marker, and reboots again.

### 9. After the relabel

After the recovery and the relabel boot, `passwd -S root` prints `root P 2026-11-11 0 99999 7 -1`. What do the fields tell you, and would `root L never ...` be a pass?

??? question "Answer"
    `P` means the account has a usable password (older releases print `PS`); `2026-11-11` is the last-change date. `L` (or `LK`) means locked, and `never` means the password has no last-change date. The checker requires a `P*` status **and** a date that is not `never`, because a freshly recovered account must be both usable and actually changed.

### 10. The update that is not an error

`dnf check-update` exits `100`. Is that a failure?

??? question "Answer"
    No. `100` means updates are available, `0` means none are, and `1` means the check itself failed (a repository problem, usually). The checker treats `0` as "nothing left to install", so `100` is the expected result before the update and a failure after it.

### 11. The kernel that is installed but not running

`dnf -y upgrade` installed `kernel-core-6.12.0-211.74.2`, and `rpm -q --last kernel-core` shows it first. `uname -r` still shows `6.12.0-211.53.1`. Is the update broken?

??? question "Answer"
    No. A kernel update installs the new kernel alongside the old one and adds a BLS entry; it does not replace the running kernel. Reboot to run the new one. `uname -r` is the running kernel, `rpm -q --last kernel-core` is what is installed, and they legitimately disagree until the reboot.

### 12. The note on the console

After booting with `systemd.unit=rescue.target`, `systemctl get-default` prints `multi-user.target` and then:

```text { .no-copy }
Note: found "systemd.unit" on the kernel command line, which overrides the default unit.
```

What is systemd telling you, and why can you still `ssh` fail?

??? question "Answer"
    It is telling you that the kernel command line asked for a different target than the configured default, and that the command-line value wins **for this boot**. `get-default` still reports the persistent setting. `sshd` is not running in rescue mode, so SSH is refused until you `systemctl isolate multi-user.target` or reboot without the override.

### 13. `init=/bin/bash` is not a normal shell

You boot with `init=/bin/bash`, run `systemctl status`, and get `offline`. You also notice a file you `touch`ed is mode `0666`. Why?

??? question "Answer"
    systemd never started: bash is PID 1, so there is no service manager and `systemctl` has nothing to talk to. The shell did not go through a login, so the usual `umask` was never applied and files are created with the process's default, often `000`. Use the shell for a focused repair, remount the root read-write first, and finish with `exec /usr/sbin/init` or `reboot -f`.

### 14. The argument that is true in only one place

`grubby --info=ALL` shows `panic_on_warn=1`, but `/proc/sys/kernel/panic_on_warn` is still `0`. What is the state, and what is missing?

??? question "Answer"
    The persistent configuration is correct, but the running kernel booted before the argument was added. Kernel arguments are applied at boot; `grubby` writes files. Reboot, then check `/proc/cmdline` and the sysctl again. Until then, the checker's live checks fail — deliberately, because that is the persistence test.

### 15. The order that matters

Why does the challenge say to run `grubby --update-kernel=ALL --args=panic_on_warn=1` **after** `dnf upgrade`, rather than before?

??? question "Answer"
    A kernel update creates a new BLS entry. `grubby --update-kernel=ALL` touches the entries that exist at the moment it runs. If you add the argument first and the update installs a new kernel afterwards, the new entry is created without it. Update first, then apply the argument to `ALL`, then reboot.
