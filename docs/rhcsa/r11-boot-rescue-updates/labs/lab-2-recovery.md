# Lab 2 — Recovering a locked root account

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R11 — Boot, rescue, and updates |
| **Time** | 75–90 minutes |
| **Check** | `./bin/lab check r11 lab2` |
| **Skills** | Interrupting GRUB, `rd.break`, `chroot`, resetting a root password, `/.autorelabel`, `init=/bin/bash`, rescue mode, `sulogin` |

</div>

## What you are building

| Item | End state |
|---|---|
| Root account | Unlocked, with a password you chose and a real last-change date |
| Marker file | `/root/r11-recovered`, owned by root and labelled `admin_home_t` |
| Shadow file | `/etc/shadow` labelled `shadow_t` |
| Relabel marker | `/.autorelabel` is gone, because the relabel completed |
| SELinux | Still `Enforcing` |

The lesson in one sentence: **when you cannot log in, the bootloader is the way in — and the last step of the repair is a relabel, not a password.**

You will need the **serial console** for this lab. There is no other way to see GRUB or the emergency shell. Keep Terminal A open for the whole lab; it is where every important thing happens.

## Before you begin

You can do this lab on the machine from Lab 1, or restore the clean snapshot and do it alone. `./bin/lab check r11 lab2` does not depend on Lab 1; only `./bin/lab check r11 all` does.

If you are starting fresh:

```bash
cd labs
./bin/lab restore clean
./bin/lab up
```

Open the console:

```bash
./bin/lab console server
```

Log in as `labuser` with password `labpass`, then become root:

```bash
sudo -i
```

Keep an SSH session open in a second terminal for the commands that do not need the console:

```bash
./bin/lab ssh
sudo -i
```

Every command below runs **inside the `server` VM**. The commands are reference material: run them in order the first time, then come back for the syntax.

!!! warning "Do not close the console"
    `Ctrl+]` detaches the console. Do not press it while the machine is in the initramfs or in rescue mode; you will have no way back in without reopening it.

## Step 1 — Lock yourself out

Lock the root account:

```bash
passwd -l root
LC_ALL=C passwd -S root
```

```text { .no-copy }
passwd: password changed.
root L never 0 99999 7 -1
```

The second field is the status: `L` means locked. (On some releases it prints `LK`; the prefix is what matters.) The third field is the last-change date, and `never` means the account has no usable password date.

Try to log in as root on the console. It fails, as it should. You have just created the problem this lab solves.

!!! note "Why lock root at all?"
    A locked root account is the honest version of "I do not know the root password". The recovery steps are identical for a forgotten password and a deliberately locked one: the account has to be made usable again from outside the running system.

## Step 2 — Stop the boot

From the console, restart:

```bash
systemctl reboot
```

At the GRUB menu, before the ten-second countdown ends:

1. Press any key to stop the countdown.
2. Highlight the newest kernel.
3. Press `e`.
4. Press ++down++ until the `linux` line is highlighted.
5. Press ++ctrl+e++ to jump to the end of the line.
6. Type a space and `rd.break`.
7. Press ++ctrl+x++ to boot.

The line should end with:

```text { .no-copy }
 |ole=tty0 console=ttyS0,115200n8 panic=10 rd.break                           |
```

`rd.break` tells dracut to stop after it has mounted the real root at `/sysroot` but before it switches to it. You are in the initramfs, not in the installed system.

## Step 3 — Enter the emergency shell

dracut prints a long message and then waits:

```text { .no-copy }
         Starting dracut-emergency.service - Dracut Emergency Shell...
Generating "/run/initramfs/rdsosreport.txt"
Entering emergency mode. Exit the shell to continue.
Type "journalctl" to view system logs.
You might want to save "/run/initramfs/rdsosreport.txt" to a USB stick or /boot
after mounting them and attach it to a bug report.
Press Enter for maintenance
(or press Control-D to continue):
```

Press ++enter++ to get the shell:

```text { .no-copy }
sh-5.2#
```

The prompt is `sh-5.2#`, not `#`, and not `switch_root:/#`. On this image dracut's emergency service is what runs, and it needs the ++enter++ before it gives you a prompt.

## Step 4 — Make the root writable

```bash
mount -o remount,rw /sysroot
```

This line is not optional. `/sysroot` is the installed system's root, and dracut mounted it **read-only**. If you skip the remount, `passwd` cannot write `/etc/shadow` and fails with `Authentication token manipulation error` — a message that sounds like a password problem and is really a filesystem permission problem.

Now enter the installed system:

```bash
chroot /sysroot
```

The prompt stays `sh-5.2#`, but you are now looking at the real root filesystem. `ps` would show the initramfs's processes, not the real system's; that is normal. The files you change here are the files the next boot will use.

## Step 5 — Set the password and schedule the relabel

Choose a password for root. The example uses `R11-recovery`; choose your own if you like, then use it consistently at the console.

```bash
passwd root
```

```text { .no-copy }
New password:
Retype new password:
passwd: password updated successfully
```

If you choose a password containing the user name — `r11rootpass`, for example — `passwd` warns:

```text { .no-copy }
BAD PASSWORD: The password contains the user name in some form
```

The warning does not stop the change, but it is a real warning. Pick something else.

Now the part that is easy to forget:

```bash
touch /.autorelabel
touch /root/r11-recovered
ls -Z /etc/shadow /root/r11-recovered
```

```text { .no-copy }
? /etc/shadow  ? /root/r11-recovered
```

The `?` is the problem. SELinux is not enforcing in the initramfs, so the files you just wrote have no usable label. `/etc/shadow` is the one that matters most: the login program will not be allowed to read it, and every password — including the one you just set — will be rejected.

`/.autorelabel` tells systemd to run a full relabel on the next boot. The boot after that will rewrite every label from policy, remove the marker, and reboot again.

Leave the chroot and then leave dracut:

```bash
exit
exit
```

The boot continues. You will see it start, then relabel, then reboot by itself. The relabel boot is slower than a normal boot; do not interrupt it.

## Step 6 — Log in again

When the login prompt returns, log in as root with the password from Step 5:

```text { .no-copy }
AlmaLinux 10.2 (Lavender Lion)
Kernel 6.12.0-211.74.2.el10_2.x86_64 on an x86_64
server login: root
Password:
[root@server ~]#
```

Check the four things that prove the repair:

```bash
LC_ALL=C passwd -S root
ls -Z /etc/shadow /root/r11-recovered
ls -l /root/r11-recovered
test -e /.autorelabel && echo PRESENT || echo absent
getenforce
```

```text { .no-copy }
root P 2026-11-11 0 99999 7 -1
system_u:object_r:shadow_t:s0 /etc/shadow
system_u:object_r:admin_home_t:s0 /root/r11-recovered
-rw-r--r--. 1 root root 0 Nov 11 05:05 /root/r11-recovered
absent
Enforcing
```

`P` means the account is usable, and `2026-11-11` is the day you changed it. `shadow_t` and `admin_home_t` are the labels the relabel boot restored. `/.autorelabel` is gone because the relabel finished. SELinux is still enforcing, which means you fixed the login without turning the protection off.

Reboot once more and check that the repair survives:

```bash
systemctl reboot
```

After the menu and the boot, log in as root again and confirm:

```bash
id -un
ls -Z /root/r11-recovered
```

```text { .no-copy }
root
system_u:object_r:admin_home_t:s0 /root/r11-recovered
```

That second boot is the persistence test for this lab. A recovery that only works until the next reboot is not a recovery.

## Step 7 — The other two doors

`rd.break` is the right tool for a locked account. The other two are worth seeing once, because the exam may describe a situation where `rd.break` is the wrong choice.

### `init=/bin/bash`

This replaces systemd with bash as PID 1. It is faster than `rd.break` when you need a shell on the real root and do not need the initramfs's view of it.

Reboot, and at the GRUB menu append `init=/bin/bash` to the `linux` line instead of `rd.break`. The kernel mounts the real root and runs bash:

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

The root filesystem is read-only here too:

```bash
mount -o remount,rw /
```

You have no job control and no login environment, so `umask` is not set the way a login shell sets it; a `touch` in this shell produced a mode `0666` file. Use it for a quick look or a single repair, not for an interactive session. When you are done, hand control back to systemd:

```bash
exec /usr/sbin/init
```

The boot continues normally from there. `reboot -f` is the other way out if you do not want systemd to run.

### `systemd.unit=rescue.target`

This one boots systemd, but only to rescue mode. It is for the case where the root password still works and a normal boot does not. Append `systemd.unit=rescue.target` at the GRUB menu. After a few seconds:

```text { .no-copy }
You are in rescue mode. After logging in, type "journalctl -xb" to view
system logs, "systemctl reboot" to reboot, or "exit"
to continue bootup.
Give root password for maintenance
(or press Control-D to continue):
```

Enter the root password. You get a root shell, but almost nothing is running:

```bash
systemctl get-default
systemctl is-active sshd
systemctl list-units --state=active --type=target | grep -E 'rescue|multi-user'
```

```text { .no-copy }
multi-user.target
Note: found "systemd.unit" on the kernel command line, which overrides the default unit.
inactive
  rescue.target         loaded active active Rescue Mode
```

`sshd` is inactive, so you cannot reach this machine over SSH; that is why the console matters. `get-default` is still `multi-user.target`, and the note explains that the kernel command line is overriding it for this boot.

Return to a normal system without rebooting:

```bash
systemctl isolate multi-user.target
```

The normal units start, the getty takes the console back, and `sshd` comes up. Log in over SSH again and confirm:

```bash
systemctl is-active sshd
systemctl list-units --state=active --type=target | grep -E 'rescue|multi-user'
```

```text { .no-copy }
active
  multi-user.target        loaded active active Multi-User System
```

`isolate` is the same command from Lab 1. Here it is a recovery tool: it leaves rescue mode and starts everything the normal target needs, without a reboot and without changing the default.

## What the checker will look for

```bash
./bin/lab check r11 lab2
```

| Check | What it reads |
|---|---|
| Root is unlocked | `passwd -S root`, status `P*` |
| The password has a real date | The third field is not `never` |
| The marker exists and is root-owned | `stat` on `/root/r11-recovered` |
| The marker is labelled | `ls -Z` → `admin_home_t` |
| The shadow file is labelled | `ls -Z /etc/shadow` → `shadow_t` |
| The relabel finished | `/.autorelabel` is absent |
| SELinux is still enforcing | `getenforce` |

The checker never asks for the password. It proves the account is usable and that the relabel did its job.

## Traps worth remembering

| Trap | What you see | The fix |
|---|---|---|
| Skipped `mount -o remount,rw /sysroot` | `Authentication token manipulation error` | Remount, then `passwd` again |
| Forgot `touch /.autorelabel` | Login rejects every password; `/etc/shadow` shows `?` | Boot `rd.break` again, touch it, reboot twice |
| Interrupted the relabel boot | Labels half-written; login may fail | Let it finish; if it is already damaged, `/.autorelabel` again |
| Used `init=/bin/bash` and expected systemd | `systemctl` says `offline`; no services | `exec /usr/sbin/init` |
| Tried SSH from rescue mode | Connection refused; `sshd` is inactive | Use the console, or `isolate multi-user.target` |
| Added `rd.break` and left it there | Every boot stops in the initramfs | Remove the argument with `grubby` |
| Chose a password containing `root` | `BAD PASSWORD`, but the change still applies | Choose a different password |
| Closed the console with `Ctrl+]` mid-boot | No way back in without reopening it | `./bin/lab console server` again |

## Next

[Challenge — Update the system and harden the boot](challenge-update-and-boot.md) combines the two labs: a full package update, a second persistent kernel argument, and a return to the headless default target.
