# R11 cheat sheet

## The boot chain

```text { .no-copy }
firmware → GRUB 2 → kernel + initramfs → switch_root → systemd (PID 1) → default target
```

| Stage | What to remember |
|---|---|
| Firmware | Picks the boot device; BIOS or UEFI |
| GRUB 2 | Reads `/boot/grub2/grub.cfg`; builds the menu from `/boot/loader/entries/*.conf` |
| Kernel | Gets its arguments from the selected BLS entry |
| initramfs | Dracut's temporary root; mounts the real root; `rd.break` stops here |
| systemd | Reaches the default target; `systemd.unit=` overrides it for one boot |

## Targets

| Target | Runlevel | Meaning |
|---|---|---|
| `poweroff.target` | 0 | Shut down |
| `rescue.target` | 1 | Single-user, `sulogin`, most services off |
| `multi-user.target` | 3 | Text login, network, normal services |
| `graphical.target` | 5 | `multi-user` plus a display manager |
| `reboot.target` | 6 | Reboot |
| `emergency.target` | — | More minimal than rescue; root read-only |

```bash
systemctl get-default                     # what the next boot reaches
systemctl set-default multi-user.target   # change it, persistently
systemctl isolate graphical.target        # change it, this boot only
systemctl list-units --type=target        # what is active now
systemd-analyze time                      # kernel / initrd / userspace split
systemd-analyze blame | head              # slowest units
systemd-analyze critical-chain            # the chain that decided the finish time
```

`isolate` survives until reboot. `set-default` survives the reboot. `get-default` reads `/etc/systemd/system/default.target`.

## GRUB: the two layers

| Layer | File | Written by | Edited by you? |
|---|---|---|---|
| Intent | `/etc/default/grub` | you, or `grubby` | Yes |
| Generated menu | `/boot/grub2/grub.cfg` | `grub2-mkconfig` | **No** |
| Per-kernel arguments | `/boot/loader/entries/*.conf` | `grubby`, kernel install | Via `grubby` only |
| New kernels | `/etc/kernel/cmdline` | `grubby` | Via `grubby` only |
| This boot | `/proc/cmdline` | the bootloader | No |

```bash
grub2-mkconfig -o /boot/grub2/grub.cfg   # regenerate the menu
grub2-editenv list                       # saved_entry, menu_auto_hide, boot_success
grub2-editenv - set menu_auto_hide=0     # keep the menu visible after a good boot
```

`grub2-mkconfig` does **not** update the BLS entries. That is why kernel arguments go through `grubby`.

## Kernel arguments

```bash
grubby --info=ALL                                  # every entry and its args
grubby --default-kernel                            # /boot/vmlinuz-...
grubby --default-index                             # 0, 1, ...
grubby --update-kernel=ALL --args=panic=10         # add, all kernels
grubby --update-kernel=ALL --remove-args=panic=10  # remove, all kernels
grubby --set-default=/boot/vmlinuz-<version>       # choose the default kernel
```

Temporary: GRUB menu → `e` → `linux` line → ++ctrl+e++ → append ` arg=value` → ++ctrl+x++. Gone at reboot.

Useful arguments:

| Argument | Effect |
|---|---|
| `panic=10` | Reboot 10 seconds after a kernel panic |
| `panic_on_warn=1` | Treat a kernel `WARN()` as a panic |
| `systemd.unit=rescue.target` | Boot a different target for this boot only |
| `rd.break` | Stop in the initramfs before `switch_root` |
| `init=/bin/bash` | Run bash as PID 1; systemd never starts |
| `console=tty0 console=ttyS0,115200n8` | Send kernel messages to the screen and the serial port |

## Interrupting the boot

At the menu: any key stops the countdown, `e` edits, `c` gives a GRUB shell, ++ctrl+x++ boots the edit, ++esc++ discards it.

| Door | Where you land | Root | Services | Use for |
|---|---|---|---|---|
| `rd.break` | dracut emergency shell | `/sysroot`, read-only | none | Locked or forgotten root password; broken `/etc` |
| `init=/bin/bash` | bash as PID 1 | `/`, usually read-only | none | A quick shell on the real root |
| `systemd.unit=rescue.target` | `sulogin` | `/`, read-write | almost none; no network or `sshd` | A broken service or target, with a working root password |

### The `rd.break` recipe

```bash
mount -o remount,rw /sysroot     # without this, passwd fails
chroot /sysroot
passwd root
touch /.autorelabel              # without this, login rejects every password
exit
exit
```

The machine boots, relabels, and reboots itself. The relabel boot is slower; let it finish.

### The other doors

```bash
# init=/bin/bash, once you have the prompt
mount -o remount,rw /
exec /usr/sbin/init              # hand control back to systemd

# systemd.unit=rescue.target, in the sulogin shell
systemctl isolate multi-user.target   # back to normal, no reboot
```

Rescue mode has no `sshd`; use the console.

## Proof after a recovery

```bash
LC_ALL=C passwd -S root          # root P <date> ...   (P = usable, L = locked)
ls -Z /etc/shadow                # ...:shadow_t:s0
ls -Z /root/r11-recovered        # ...:admin_home_t:s0
test -e /.autorelabel && echo PRESENT || echo absent
getenforce                       # Enforcing
```

`?` in the label column means the relabel has not run.

## Updates

```bash
dnf check-update                 # 100 = updates available, 0 = none, 1 = error
dnf -y upgrade                   # apply them (alias: update)
dnf history                      # every transaction
dnf history info <id>            # return code, user, packages
dnf history undo <id>            # reverse a transaction (not a backup)
needs-restarting -r              # 0 = reboot needed (dnf-plugins-core)
dnf offline-upgrade download     # production-safe path: download...
dnf offline-upgrade reboot       # ...then apply before services start
```

The kernel is installed alongside the old one, not replaced. Reboot to run it.

```bash
uname -r                         # running kernel
rpm -q kernel-core               # installed kernels
rpm -q --last kernel-core        # newest installed first
```

`uname -r` and `rpm -q --last` disagree after a kernel update until the reboot. That is normal.

## One-line health checks

```bash
systemctl get-default
grubby --info=ALL | grep -E '^index|^args'
cat /proc/cmdline
grub2-editenv list
uname -r
dnf -q check-update; echo $?
```

## Traps

| Trap | Fix |
|---|---|
| `isolate` when you meant `set-default` | `set-default` |
| Edited `grub.cfg` by hand | Edit `/etc/default/grub`, then `grub2-mkconfig` |
| Argument only in `/etc/default/grub` | `grubby --update-kernel=ALL --args=...` |
| No menu to interrupt | `GRUB_TIMEOUT` > 0 and `menu_auto_hide=0` |
| `Authentication token manipulation error` | `mount -o remount,rw /sysroot` |
| Login rejects the new password | `touch /.autorelabel`, reboot twice |
| `rd.break` left in the arguments | `grubby --remove-args=rd.break` |
| No SSH in rescue mode | Console, or `systemctl isolate multi-user.target` |
| `check-update` exit `100` treated as failure | It means updates are available |
| Updated the kernel, did not reboot | Reboot, then check `uname -r` |
| `dnf upgrade` with R3's repos disabled | Re-enable them |
| `systemctl` says `offline` after `init=/bin/bash` | systemd is not running; that is the point |
