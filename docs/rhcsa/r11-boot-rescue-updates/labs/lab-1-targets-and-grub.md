# Lab 1 — Targets, the menu, and a persistent kernel argument

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R11 — Boot, rescue, and updates |
| **Time** | 60–75 minutes |
| **Check** | `./bin/lab check r11 lab1` |
| **Skills** | `systemctl get-default`/`set-default`/`isolate`, `systemd-analyze`, `/etc/default/grub`, `grub2-mkconfig`, BLS entries, `grubby`, `grub2-editenv`, the GRUB editor |

</div>

## What you are building

| Item | End state |
|---|---|
| Default target | `multi-user.target`, after a `graphical.target` round-trip that proves `set-default` works |
| Menu timeout | `GRUB_TIMEOUT=10`, regenerated into `grub.cfg` |
| Menu visibility | `menu_auto_hide=0` |
| Persistent kernel argument | `panic=10` on **every** BLS entry, and in `/proc/cmdline` |
| Temporary argument | `systemd.unit=graphical.target`, used for one boot only |

The lesson in one sentence: **a boot setting has a home, and a change that is not in the home the bootloader reads did not happen.**

!!! note "Why this lab visits graphical.target and then leaves it"
    The clean image already defaults to `multi-user.target`, so setting `graphical.target` is a real, visible change that proves `set-default` works. After the reboot confirms it, the lab puts the server back on `multi-user.target`, which is the sensible default for a headless machine. You will have set the default in both directions, and the checker will find the production end state.

## Before you begin

Start from the clean snapshot:

```bash
cd labs
./bin/lab restore clean
./bin/lab up
```

You need **two terminals**, because one of them has to show the GRUB menu while the other reboots the machine.

=== "Terminal A — the console"

    ```bash
    ./bin/lab console server
    ```

    Log in as `labuser` with password `labpass`, then become root:

    ```bash
    sudo -i
    ```

    `Ctrl+]` leaves the console. Do not leave it while the machine is rebooting; that is the screen you are watching.

=== "Terminal B — SSH"

    ```bash
    ./bin/lab ssh
    sudo -i
    ```

    This is where you type most commands. Rebooting from here is fine; Terminal A shows what happens next.

Every command below runs **inside the `server` VM**. The commands are reference material: run them in order the first time, then come back for the syntax.

!!! warning "The console is the only way to see GRUB"
    `./bin/lab ssh` connects to a machine that is already running. It cannot show you the bootloader. Anything that says "at the GRUB menu" happens in Terminal A.

## Step 1 — Look at the chain

```bash
systemctl get-default
ls -l /etc/systemd/system/default.target
systemd-analyze time
```

```text { .no-copy }
multi-user.target
lrwxrwxrwx. 1 root root 41 Sep 14 12:45 /etc/systemd/system/default.target -> /usr/lib/systemd/system/multi-user.target
Startup finished in 895ms (kernel) + 1.967s (initrd) + 4.384s (userspace) = 7.247s
multi-user.target reached after 3.821s in userspace.
```

`get-default` answers "what will the next boot reach?". The symlink is the file behind the answer, and the time line splits the boot into kernel, initramfs, and userspace. On this machine the initramfs costs about two seconds; that is dracut finding the root filesystem.

The targets that are active now:

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

`graphical.target` is not in the list, because nothing has asked for it.

## Step 2 — Runtime versus next boot

Isolate `graphical.target`:

```bash
systemctl isolate graphical.target
systemctl get-default
systemctl list-units --type=target | grep graphical
```

```text { .no-copy }
multi-user.target
  graphical.target         loaded active active Graphical Interface
```

The running system is now in `graphical.target`, but `get-default` still says `multi-user.target`. Nothing was written to disk. Return to the text target:

```bash
systemctl isolate multi-user.target
```

Now make the change persistent. This is the command the exam is looking for:

```bash
systemctl set-default graphical.target
systemctl get-default
readlink /etc/systemd/system/default.target
```

```text { .no-copy }
Removed '/etc/systemd/system/default.target'.
Created symlink '/etc/systemd/system/default.target' → '/usr/lib/systemd/system/graphical.target'.
graphical.target
/usr/lib/systemd/system/graphical.target
```

`set-default` replaced the symlink. The running system is unaffected; the **next** boot will reach `graphical.target`. Prove it. From Terminal B:

```bash
systemctl reboot
```

In Terminal A, watch the machine shut down and come back. When the login prompt returns, log in as `labuser` and check:

```bash
systemctl get-default
systemctl list-units --type=target | grep graphical
```

```text { .no-copy }
graphical.target
  graphical.target         loaded active active Graphical Interface
```

That is the difference between the two commands in one pair of outputs. `isolate` was undone by the reboot; `set-default` was not.

A server should not boot into a graphical target, so put it back. You have now used the command in both directions, which is exactly what the exam asks for:

```bash
systemctl set-default multi-user.target
systemctl get-default
readlink /etc/systemd/system/default.target
```

```text { .no-copy }
Removed '/etc/systemd/system/default.target'.
Created symlink '/etc/systemd/system/default.target' → '/usr/lib/systemd/system/multi-user.target'.
multi-user.target
/usr/lib/systemd/system/multi-user.target
```

The next reboot in Step 4 will confirm it, and the checker expects this end state. The graphical round-trip was the proof; `multi-user.target` is the production setting.

## Step 3 — The two GRUB layers

Read the source of truth:

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

Now look at what GRUB actually reads. The per-kernel entries come first:

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

Two kernels, two files, each with its own `options` line. The generated menu loads them with `blscfg`:

```bash
grep -n 'set timeout=' /boot/grub2/grub.cfg | head -3
grub2-editenv list
```

```text { .no-copy }
67:  set timeout=5
71:  set timeout=5
167:    set timeout="${menu_show_once_timeout}"
saved_entry=7a94f52d4c9d451eacc54509281ea671-6.12.0-211.74.2.el10_2.x86_64
menu_auto_hide=0
boot_success=0
boot_indeterminate=0
```

`grub.cfg` is generated; the BLS entries are the per-kernel truth. Remember that split for the next two steps: a timeout is a `grub.cfg` setting, a kernel argument is a BLS setting.

## Step 4 — A ten-second menu

Five seconds is enough if you are waiting for it. It is not enough when you have just realised you need to interrupt the boot. Make it ten:

```bash
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=10/' /etc/default/grub
grep GRUB_TIMEOUT /etc/default/grub
```

```text { .no-copy }
GRUB_TIMEOUT=10
```

The source is changed, but `grub.cfg` still says five. Regenerate it:

```bash
grub2-mkconfig -o /boot/grub2/grub.cfg
grep -n 'set timeout=' /boot/grub2/grub.cfg | head -3
```

```text { .no-copy }
Generating grub configuration file ...
Adding boot menu entry for UEFI Firmware Settings ...
done
67:  set timeout=10
71:  set timeout=10
167:    set timeout="${menu_show_once_timeout}"
```

Now the menu will wait ten seconds. Make sure it is not hidden after a successful boot:

```bash
grub2-editenv - set menu_auto_hide=0
grub2-editenv list
```

```text { .no-copy }
saved_entry=7a94f52d4c9d451eacc54509281ea671-6.12.0-211.74.2.el10_2.x86_64
menu_auto_hide=0
boot_success=0
boot_indeterminate=0
```

`12_menu_auto_hide` would otherwise set the timeout to one second and the style to `hidden` once `boot_success=1`. A hidden menu cannot be interrupted. The lab kit already sets this; the command is here because a machine you build yourself will not have it.

Confirm the menu from Terminal A. From Terminal B:

```bash
systemctl reboot
```

Terminal A should show the AlmaLinux menu and a countdown:

```text { .no-copy }
 +----------------------------------------------------------------------------+
 | AlmaLinux (6.12.0-211.53.1.el10_2.x86_64) 10.2 (Lavender Lion)             |
 |*AlmaLinux (6.12.0-211.74.2.el10_2.x86_64) 10.2 (Lavender Lion)             |
 |                                                                            |
 +----------------------------------------------------------------------------+
      Use the ^ and v keys to select which entry is highlighted.
      Press enter to boot the selected OS, `e' to edit the commands
      before booting or `c' for a command-line.
   The highlighted entry will be executed automatically in 10s.
```

Let it boot. You will need the menu again in Step 6.

## Step 5 — A persistent kernel argument

`panic=10` tells the kernel: after a panic, wait ten seconds and reboot. It is the second half of an unattended-server policy — the machine comes back even when the kernel cannot continue.

Look at the running kernel's command line first:

```bash
cat /proc/cmdline
```

```text { .no-copy }
BOOT_IMAGE=(hd0,gpt3)/vmlinuz-6.12.0-211.74.2.el10_2.x86_64 root=UUID=bfdf6531-5328-4725-a424-ff1ef506b6a4 ro no_timer_check biosdevname=0 net.ifnames=0 console=tty0 console=ttyS0,115200n8
```

No `panic=`. Add it to every installed kernel:

```bash
grubby --update-kernel=ALL --args=panic=10
grubby --info=ALL | grep -E '^index|^args'
```

```text { .no-copy }
index=0
args="ro no_timer_check biosdevname=0 net.ifnames=0 console=tty0 console=ttyS0,115200n8 panic=10"
index=1
args="ro no_timer_check biosdevname=0 net.ifnames=0 $tuned_params console=tty0 console=ttyS0,115200n8 panic=10"
```

Both entries changed, including the old kernel you are not running. Check the files on disk and the source:

```bash
grep -H options /boot/loader/entries/*.conf
grep GRUB_CMDLINE_LINUX /etc/default/grub
cat /etc/kernel/cmdline
```

```text { .no-copy }
...747b...conf:options root=UUID=bfdf... ro no_timer_check biosdevname=0 net.ifnames=0 console=tty0 console=ttyS0,115200n8 panic=10
...7a94...conf:options root=UUID=bfdf... ro no_timer_check biosdevname=0 net.ifnames=0 $tuned_params console=tty0 console=ttyS0,115200n8 panic=10
GRUB_CMDLINE_LINUX="no_timer_check biosdevname=0 net.ifnames=0 console=tty0 console=ttyS0,115200n8 panic=10"
root=UUID=bfdf6531-5328-4725-a424-ff1ef506b6a4 ro no_timer_check biosdevname=0 net.ifnames=0 console=tty0 console=ttyS0,115200n8 panic=10
```

`grubby` updated all three places. This is why it is the right tool: `grub2-mkconfig` would have rewritten `grub.cfg` and left the BLS entries alone.

The running kernel still does not have the argument — that is the persistence rule. Check before rebooting:

```bash
grep -o 'panic=10' /proc/cmdline || echo 'not in this boot yet'
```

```text { .no-copy }
not in this boot yet
```

Reboot in Step 6 and it will be there.

## Step 6 — A one-boot override

This step is the temporary half of the lesson. You will override the default target **without writing anything**, then let it disappear.

From Terminal B:

```bash
systemctl reboot
```

In Terminal A, at the menu, before the countdown ends:

1. Press any key to stop the countdown.
2. Make sure the newest kernel is highlighted (the `*` entry).
3. Press `e` to edit it.
4. Press ++down++ until the line beginning `linux` is highlighted. On this image that is three presses from the top.
5. Press ++ctrl+e++ to jump to the end of that line.
6. Type a space and `systemd.unit=graphical.target`.
7. Press ++ctrl+x++ to boot.

The edited line should look like this:

```text { .no-copy }
 |linux ($root)/vmlinuz-6.12.0-211.74.2.el10_2.x86_64 root=UUID=bfdf6531-5328\|
 |ole=tty0 console=ttyS0,115200n8 panic=10 systemd.unit=graphical.target      |
```

After the boot, from Terminal B:

```bash
systemctl get-default
systemctl list-units --type=target | grep -E 'graphical|multi-user'
grep -o 'systemd.unit=[a-z.-]*' /proc/cmdline
```

```text { .no-copy }
multi-user.target
  multi-user.target        loaded active active Multi-User System
  graphical.target         loaded active active Graphical Interface
Note: found "systemd.unit" on the kernel command line, which overrides the default unit.
systemd.unit=graphical.target
```

The running system asked for `graphical.target`, but `get-default` is still `multi-user.target`. The override lives only in this boot's command line.

Reboot once more, without editing anything:

```bash
systemctl reboot
```

Terminal A will show the menu with the countdown and boot the default entry. After it comes back:

```bash
systemctl get-default
systemctl list-units --type=target | grep -E 'graphical|multi-user'
grep -o 'panic=10' /proc/cmdline
```

```text { .no-copy }
multi-user.target
  multi-user.target        loaded active active Multi-User System
panic=10
```

All three facts are now true at once: the default target survived, the temporary override is gone, and the persistent kernel argument arrived. That is the whole module in one reboot.

## What the checker will look for

```bash
./bin/lab check r11 lab1
```

| Check | What it reads |
|---|---|
| The default target is `multi-user.target` | `systemctl get-default` |
| The symlink agrees | `readlink -f /etc/systemd/system/default.target` |
| The timeout is ten seconds | `/etc/default/grub` and `grub.cfg` |
| The menu is not auto-hidden | `grub2-editenv list` |
| `panic=10` is on every kernel | `grubby --info=ALL` |
| A new kernel would inherit it | `/etc/kernel/cmdline` |
| The running kernel received it | `/proc/cmdline` |
| The default entry is the running kernel | `grubby --default-kernel` vs `uname -r` |

The `/proc/cmdline` line fails until you have rebooted after Step 5. That is the persistence test.

## Traps worth remembering

| Trap | What you see | The fix |
|---|---|---|
| Used `isolate` and called it done | The change disappears at reboot | `systemctl set-default` |
| Edited `/etc/default/grub`, did not run `grub2-mkconfig` | `grub.cfg` still has the old timeout | Regenerate |
| Added the argument only to `/etc/default/grub` | `grubby --info=ALL` does not show it | `grubby --update-kernel=ALL` |
| Pressed `e` and typed without going to the `linux` line | The text lands on the wrong line | ++down++ to `linux`, then ++ctrl+e++ |
| Pressed ++enter++ in the editor | It boots without your change | ++ctrl+x++ boots; ++esc++ discards |
| Expected `panic=10` immediately | `/proc/cmdline` is the current boot | Reboot |
| `menu_auto_hide=1` | The countdown is one second and hidden | `grub2-editenv - set menu_auto_hide=0` |

## Next

[Lab 2 — Recovering a locked root account](lab-2-recovery.md) breaks the login on purpose and gets it back through the initramfs.
