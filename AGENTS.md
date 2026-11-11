# AGENTS.md — project handoff and status

This is the maintainer-facing source of truth for the **RHCSA Field Guide**. It is written for humans and for future AI agents who need to continue the work without re-deriving the plan.

Update this file whenever a milestone lands, a decision changes, or a module is completed.

| | |
|---|---|
| **Last updated** | 2026-11-11 |
| **Current milestone** | M4 — R12 core validated; mock exams next |
| **Next milestone** | R12 mock exams A–C, then PDF/print export |
| **Active branch** | `main` |
| **Remote** | `git@github.com:hilgardvr/red-hat-prep-courses.git` (SSH) |

---

## 1. What this project is

A free, lab-first course for the **Red Hat Certified System Administrator (RHCSA)** exam, **EX200 v10**, targeting **Red Hat Enterprise Linux 10**.

The product is a website built with MkDocs Material and hosted on GitHub Pages. The course teaches the underlying Linux theory first, then makes the learner perform every exam objective on disposable virtual machines.

**Audience:** near-beginners. Do not assume prior RHEL administration experience.

**Business model:** free core course; paid extras (mock-exam packs, printable workbook, instructor materials) may be added later. The free course must remain complete enough to prepare for EX200 on its own.

**Licensing:**

- Code, lab scripts, site tooling: MIT (`LICENSE`)
- Course content: CC BY-NC-SA 4.0 (`LICENSE-CONTENT`)
- Include the unofficial/not-affiliated-with-Red-Hat disclaimer on the site, README, and license notice.

---

## 2. Current status

| Area | Status | Notes |
|---|---|---|
| Site scaffold | **Complete** | MkDocs Material, nav, theme, landing page, reference pages |
| GitHub Pages workflow | **Validated 2026-11-10** | `.github/workflows/pages.yml` has run and deployed successfully on `main` |
| Lab kit | **Validated 2026-11-10** | Vagrant 2.3.4 + vagrant-libvirt 0.11.2, two nodes, cross-VM SSH, reboot persistence, `visudo -c` clean on both nodes. A serial console is provisioned on both nodes (`console=tty0 console=ttyS0,115200n8`) with the GRUB menu visible (`GRUB_TIMEOUT=5`, `menu_auto_hide=0`), and `./bin/lab console` attaches to it for R11. Rebuilt from scratch and re-walked on 2026-11-10 against AlmaLinux 10.2 (box `10.2.20260914`); the serial console was re-validated on 2026-11-11. |
| Foundations F1–F8 | **Complete; walked 2026-11-10** | Eight modules under `docs/foundations/`; every command in F1 and F3–F8 was run on the 2026-11-10 lab. F2 was walked with the lab kit. No automated checkers, by decision. |
| R1 — Essential tools | **Validated** | Theory, 2 guided labs, challenge, quiz, cheat sheet, checker. 66/66 on 2026-11-07 and again on 2026-11-10 after a reboot. |
| R2 — Users and groups | **Validated 2026-11-10** | Theory, 2 guided labs, challenge, quiz, cheat sheet, checker (27 + 26 + 35 = 88). Walked end to end on a fresh lab, 88/88 after a reboot. |
| R3 — Software and repositories | **Validated 2026-11-10** | Theory, 2 guided labs, challenge, quiz, cheat sheet, checker (10 + 6 + 17 = 33). Walked end to end on a fresh lab, 33/33 after a reboot. |
| R4 — Shell scripting | **Validated 2026-11-10** | Theory, 2 guided labs, challenge, quiz, cheat sheet, checker (14 + 13 + 13 = 40). Checker runs the learner's scripts against its own fixtures; walked end to end on a fresh lab, 40/40 after a reboot. |
| R5 — Processes and services | **Validated 2026-11-10** | Theory, 2 guided labs, challenge, quiz, cheat sheet, checker (10 + 7 + 10 = 27). Checker reads live systemd/journald/tuned state; walked end to end on a fresh lab, 27/27 after a reboot. |
| R6 — Local storage | **Validated 2026-11-10** | Theory, 2 guided labs, challenge, quiz, cheat sheet, checker (12 + 12 + 12 = 36). Checker reads the live partition table, LVM metadata, mounts, and fstab; walked end to end on a fresh lab, 36/36 after a reboot. |
| R7 — File systems and sharing | **Validated 2026-11-10** | Theory, 2 guided labs, challenge, quiz, cheat sheet, checker (11 + 15 + 16 = 42). Checker reads live partition, superblock, mount, export, and firewalld state on `server`, and reaches `node2` over SSH for the autofs half; walked end to end on a fresh lab, 42/42 after rebooting both VMs. |
| R8 — Scheduling and time | **Validated 2026-11-10** | Theory, 2 guided labs, challenge, quiz, cheat sheet, checker (13 + 12 + 18 = 43). Checker reads live systemd timer properties, cron files, produced artefacts, and chrony state on `server`, and reaches `node2` over SSH for the client half; walked end to end on a fresh lab, 43/43 after rebooting both VMs. |
| R9 — Networking and firewalld | **Validated 2026-11-11** | Theory, 2 guided labs, challenge, quiz, cheat sheet, checker (12 + 10 + 13 = 35). Checker reads the `nmcli` profile, live addresses, `/etc/hosts`, and permanent/runtime firewalld state, then proves each open port by fetching it from `node2` with a listener the checker starts itself; walked end to end on a fresh lab, 35/35 after rebooting both VMs. |
| R10 — Security: SELinux and SSH | **Validated 2026-11-11** | Theory, 2 guided labs, challenge, quiz, cheat sheet, checker (11 + 10 + 21 = 42). Checker reads live SELinux state (mode, file label, `semanage fcontext`/`port` records, Boolean pair), the effective `sshd` configuration plus two real logins, and firewalld rich-rule state, then fetches `/api/` through Apache and the hardened port from `node2`; walked end to end on a fresh lab, 42/42 after rebooting both VMs. |
| R11 — Boot, rescue, and updates | **Validated 2026-11-11** | Theory, 2 guided labs, challenge, quiz, cheat sheet, checker (10 + 8 + 13 = 31). Checker reads the default target and its symlink, both GRUB layers (`/etc/default/grub` and `grub.cfg`), every BLS entry with `grubby --info=ALL`, `/etc/kernel/cmdline`, the live `/proc/cmdline` and `/proc/sys/kernel/panic_on_warn`, the `dnf` history and `check-update`, root's `passwd -S` status, the recovery marker and both SELinux labels; walked from `clean` through Lab 1, Lab 2 (`rd.break` + relabel), the challenge, a reboot of `server`, and passed 31/31. |
| R12 — Capstone | **Core validated 2026-11-11; exams pending** | Theory, Lab 1 (full-stack rehearsal), Lab 2 (diagnostic loop), quiz, cheat sheet, checker (`lab1\|lab2\|all`). Lab 1 35/35, Lab 2 42/42 after repairs, `all` 77/77 after a reboot of `server`. The three timed mock exams and their checker phases are next. |
| PDF export | **Planned** | M4 |

**Definition of done for a module:** theory, two guided labs, a challenge lab, a reboot-persistence test, a knowledge check, a cheat sheet, and a passing automated checker from a clean snapshot.

---

## 3. Repository map

```text
.
├── AGENTS.md                  # this file
├── README.md                  # public project overview
├── mkdocs.yml                 # site config and navigation
├── requirements.txt           # mkdocs-material
├── docs/
│   ├── index.md               # landing page
│   ├── start-here/            # how to use, exam overview, study plans, lab setup
│   ├── foundations/           # index + F1–F8, complete
│   ├── rhcsa/                 # module roadmap, R1–R6
│   │   ├── r01-essential-tools/
│   │   │   ├── index.md       # theory
│   │   │   ├── labs/          # 2 guided labs + challenge
│   │   │   ├── quiz.md
│   │   │   └── cheatsheet.md
│   │   ├── r02-users-and-groups/
│   │   │   ├── index.md       # theory
│   │   │   ├── labs/          # 2 guided labs + challenge
│   │   │   ├── quiz.md
│   │   │   └── cheatsheet.md
│   │   ├── r03-software-and-repositories/
│   │   │   ├── index.md       # theory
│   │   │   ├── labs/          # 2 guided labs + challenge
│   │   │   ├── quiz.md
│   │   │   └── cheatsheet.md
│   │   ├── r04-shell-scripting/
│   │   │   ├── index.md       # theory
│   │   │   ├── labs/          # 2 guided labs + challenge
│   │   │   ├── quiz.md
│   │   │   └── cheatsheet.md
│   │   ├── r05-processes-and-services/
│   │   │   ├── index.md       # theory
│   │   │   ├── labs/          # 2 guided labs + challenge
│   │   │   ├── quiz.md
│   │   │   └── cheatsheet.md
│   │   ├── r06-local-storage/
│   │   │   ├── index.md       # theory
│   │   │   ├── labs/          # 2 guided labs + challenge
│   │   │   ├── quiz.md
│   │   │   └── cheatsheet.md
│   │   ├── r07-file-systems/
│   │   │   ├── index.md       # theory
│   │   │   ├── labs/          # 2 guided labs + challenge
│   │   │   ├── quiz.md
│   │   │   └── cheatsheet.md
│   │   ├── r08-scheduling-and-time/
│   │   │   ├── index.md       # theory
│   │   │   ├── labs/          # 2 guided labs + challenge
│   │   │   ├── quiz.md
│   │   │   └── cheatsheet.md
│   │   ├── r09-networking-and-firewall/
│   │   │   ├── index.md       # theory
│   │   │   ├── labs/          # 2 guided labs + challenge
│   │   │   ├── quiz.md
│   │   │   └── cheatsheet.md
│   │   ├── r10-security-selinux-ssh/
│   │   │   ├── index.md       # theory
│   │   │   ├── labs/          # 2 guided labs + challenge
│   │   │   ├── quiz.md
│   │   │   └── cheatsheet.md
│   │   └── r11-boot-rescue-updates/
│   │       ├── index.md       # theory
│   │       ├── labs/          # 2 guided labs + challenge
│   │       ├── quiz.md
│   │       └── cheatsheet.md
│   │   └── r12-capstone/
│   │       ├── index.md       # theory
│   │       ├── labs/          # rehearsal + diagnostic loop
│   │       ├── quiz.md
│   │       └── cheatsheet.md
│   ├── reference/             # objective coverage, glossary, RHEL 9 vs 10
│   └── assets/stylesheets/    # extra.css
├── labs/
│   ├── Vagrantfile            # server + node2
│   ├── bin/lab                # lifecycle CLI
│   ├── provision/             # common.sh, node2.sh
│   ├── checks/r01/check.sh    # R1 automated checker
│   ├── checks/r02/check.sh    # R2 automated checker
│   ├── checks/r03/check.sh    # R3 automated checker
│   ├── checks/r04/check.sh    # R4 automated checker
│   ├── checks/r05/check.sh    # R5 automated checker
│   ├── checks/r06/check.sh    # R6 automated checker
│   ├── checks/r07/check.sh    # R7 automated checker (server + node2)
│   ├── checks/r08/check.sh    # R8 automated checker (server + node2)
│   ├── checks/r09/check.sh    # R9 automated checker (server + node2)
│   ├── checks/r10/check.sh    # R10 automated checker (server + node2)
│   ├── checks/r11/check.sh    # R11 automated checker (boot state)
│   └── README.md              # lab quick reference
└── .github/workflows/pages.yml
```

`site/`, `.venv/`, and `labs/keys/` are gitignored.

---

## 4. Build and validate

### Site

```bash
cd ~/workspace/red-hat-certs/zoanthid
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
mkdocs serve
```

Build exactly as CI does:

```bash
mkdocs build --strict
```

`--strict` turns MkDocs warnings into errors. Do not merge a change that fails it. Every new page must be added to `mkdocs.yml`; broken relative links or missing nav targets will fail the build.

### Lab scripts

```bash
for f in labs/bin/lab labs/provision/*.sh labs/checks/*/*.sh; do
  bash -n "$f"
done

ruby -c labs/Vagrantfile
```

### Checkers without a VM

All four of the tree-based checkers (R1–R4) accept `LAB_ROOT` for a synthetic tree of the filesystem half:

```bash
LAB_ROOT=/tmp/opencode/r1-test bash labs/checks/r01/check.sh lab1
LAB_ROOT=/tmp/opencode/r2-test bash labs/checks/r02/check.sh lab1
LAB_ROOT=/tmp/opencode/r3-test bash labs/checks/r03/check.sh lab1
LAB_ROOT=/tmp/opencode/r4-test bash labs/checks/r04/check.sh all
```

Owner-specific and node2 SSH checks will fail outside the real lab; that is expected. The important result is that the checker runs, evaluates each criterion, and exits non-zero on failure.

R4 is the easiest to exercise this way: every R4 check reads a script under `$LAB_ROOT/r4/bin` and runs it. Create `r4/bin/{classify,linereport,accounts}` in a temporary tree, point `LAB_ROOT` at it, and the whole 40-check run works with no VM. The reference implementations used to validate the checker live in `/tmp`, not in the repository.

`LAB_ROOT` only redirects the **directory** checks under `/srv`. R2's account predicates read the live `passwd`/`shadow` databases, R3's repository predicates read the live `dnf` configuration, and every R5 and R6 check reads live systemd, journald, `tuned`, block-device, or mount state, so they cannot be simulated that way. Test them by feeding the parsers faked command output — define shell functions named `chage` and `passwd` that print a known real-world block, then call the predicate helpers against it. That is how the `chage -l` labels, the `passwd -S` status prefixes (`P`/`L` on RHEL 10, `PS`/`LK` on older releases), and the `must be changed` string were verified. Any script that does this belongs in `/tmp`, not in the repository.

R5 has no off-VM path at all: `systemctl show`, `is-enabled`, `MainPID`, `journalctl`, and `tuned-adm` are the subject of the module, and faking all of them would test the fakes. Its checker was validated only on `server`, from the `clean` snapshot, by walking the two labs and the challenge and then rebooting. It also has a side effect: the last challenge check kills `r5-batch`'s main process to prove `Restart=always` works, so `systemctl status r5-batch` shows an extra `Scheduled restart job` line afterwards. That is normal.

R6 has the same limitation for the same reason: `parted`, `sfdisk`, `pvs`, `vgs`, `lvs`, `blkid`, `findmnt`, and `swapon` are the subject. It was validated only on `server`, from the `clean` snapshot, by walking both labs and the challenge, rebooting, and running `./bin/lab check r06 all`.

R7 is the first checker that is deliberately **not** confined to one machine. Its `lab2` and `challenge` phases run on `server` and reach `node2` as `labuser` over SSH, using the key and `~/.ssh/config` entries that provisioning installs. That means both blocks of the checker depend on the lab kit being provisioned normally: if `ssh labuser@node2` does not work from `server`, the autofs checks fail no matter how correct the client configuration is. `runuser -u labuser -- ssh ...` is used on purpose: it exercises the same path a learner uses and proves the shared key works. Validate it with both VMs running, from `clean`, by walking Lab 1, Lab 2, and the challenge, rebooting both machines, and running `./bin/lab check r07 all`.

R8 is the second two-machine checker and adds a different problem: **a schedule is a promise about the future**, so most of it cannot be checked by reading configuration. Each phase asserts something the scheduler produced — a log line from a cron job, a stamp from a timer, a report the service wrote — and the challenge runs the report service four times to prove the pruning works. `lab2` and `challenge` reach `node2` as `labuser` to read `chronyc sources` and `NTPSynchronized` there, so both VMs must be up. The client half polls for up to 60 s (`check_n2_sync`), because a freshly booted `node2` needs a few seconds before chrony reports a synchronised clock. Validate it from `clean` by walking Lab 1, Lab 2 (both machines), and the challenge, rebooting both, and running `./bin/lab check r08 all`.

R9 is a networking checker and takes the next step: **configuration is not behaviour**. Half of it reads the `nmcli` profile, the live addresses, `/etc/hosts`, and both firewalld layers; the other half starts an HTTP listener on `server` and fetches it **from `node2` as `labuser`**, using the shared lab key and `~/.ssh/config`. That request is the only honest proof that a port is open in the right zone, and it is why `lab2` and `challenge` need both VMs running. The checker also asserts that `ssh` to `node2` still works after every change, because the module's whole risk is a firewall edit that ends the session. Validate it from `clean` by walking Lab 1, Lab 2 (both machines), and the challenge, rebooting both, and running `./bin/lab check r09 all`.

R10 is the first checker that has to prove **policy** rather than a file or a service. SELinux is checked three ways: the live label with `ls -Z`, the persistent record with `semanage fcontext -l -C` / `semanage port -l -C`, and the Boolean pair from `semanage boolean -l`, because a `chcon` and a `setsebool` without `-P` both look correct until something relabels files or the machine reboots. SSH is checked with `sshd -T` **and** two real connections, because a drop-in that parses can still lose the first-value-wins race with `50-cloud-init.conf`. The Boolean is checked behaviourally: the checker kills anything on `18081`, starts its own fixture, and fetches `/api/` through Apache's `ProxyPass`, so a Boolean that is `on` in the store but not in force fails. The challenge reaches `node2` as `labuser` to prove the rich rule, so both VMs must be up. Validate it from `clean` by walking Lab 1, Lab 2, and the challenge, rebooting both, and running `./bin/lab check r10 all`.

### Real lab validation

```bash
cd labs
./bin/lab doctor
./bin/lab up
./bin/lab snapshot clean
./bin/lab ssh            # check firewalld, SELinux, and cross-VM SSH
```

Then walk a module's labs and run its checker. On a clean snapshot almost every check fails by design, because the checkers read end state:

```bash
./bin/lab check r01 all
./bin/lab check r02 all
```

**Validated on 2026-11-10** on a Fedora KVM host with Vagrant 2.3.4 and vagrant-libvirt 0.11.2, against AlmaLinux 10.2 (box `10.2.20260914`):

- `./bin/lab reset` destroyed both VMs and rebuilt them from the current Vagrantfile and provisioning.
- `10.10.10.10` / `10.10.10.11` were configured by NetworkManager and survived `vagrant reload` on both nodes.
- Cross-VM `ssh labuser@node2` and `ssh labuser@server`, plus `scp` in both directions, worked without extra flags.
- `firewalld` active and enabled, SELinux `Enforcing`, `vdb` (10 GB) present and unmounted on `server`.
- `visudo -c` exited 0 on both nodes, and `/etc/sudoers.d` was mode-clean (see the `vagrant` drop-in fix below).
- Snapshot save, restore, and delete round-tripped on both machines; an in-guest `systemctl reboot` plus host reconnect worked.
- R1 lab 1 (18), lab 2 (21), and the challenge (27) passed; `./bin/lab check r01 all` passed 66/66 after rebooting `server`.
- R2 lab 1 (27), lab 2 (26), and the challenge (35) passed; `./bin/lab check r02 all` passed 88/88 after rebooting `server`.
- R3 lab 1 (10), lab 2 (6), and the challenge (17) passed; `./bin/lab check r03 all` passed 33/33 after rebooting `server`. The labs were walked in order on one machine, which is the sequence `all` assumes: Lab 1 leaves `r3-local` and `zsh`, Lab 2 leaves the Flathub remote with an empty store, and the challenge adds `r3-extra`, `tree`, and disabled distro repositories without undoing either.
- R4 lab 1 (14), lab 2 (13), and the challenge (13) passed; `./bin/lab check r04 all` passed 40/40 after rebooting `server`. The three scripts were written and exercised in order on one machine from the clean snapshot. Unlike R1–R3, the R4 checks do not inspect the lab's own files: they create fresh fixtures in `mktemp -d`, run each script against them, and compare stdout plus exit status, so the lab's sample outputs are never the thing being tested.
- R5 lab 1 (10), lab 2 (7), and the challenge (10) passed; `./bin/lab check r05 all` passed 27/27 after rebooting `server`. The walk started from `clean`, ran Lab 1, Lab 2, and the challenge on one machine, rebooted, and only then ran the checker, because two Lab 2 checks require a journal entry from an earlier boot. Lab 1 deliberately produces a `203/EXEC` failure first: a program under `/srv` is labelled `var_t`, and systemd (`init_t`) may not execute it. The walk confirmed that `SIGTERM` leaves the unit `inactive (dead)` with `Deactivated successfully`, while `SIGKILL` leaves it `failed` with `Result: signal`; the docs and quiz say exactly that.
- R6 lab 1 (12), lab 2 (12), and the challenge (12) passed; `./bin/lab check r06 all` passed 36/36 after rebooting `server`. The walk started from `clean`, installed `lvm2`, created the 5 GiB GPT partition on `/dev/vdb`, built `r6vg` with a 2 GiB XFS `r6data` mounted by UUID, added a 512 MiB swap LV and a 512 MiB ext4 `r6label` mounted by `LABEL=r6label`, then added `/dev/vdb2`, extended the VG, grew `r6data` to 4 GiB, and ran `xfs_growfs`. A marker file written before the resize was readable after the reboot. `findmnt --verify` reported no errors at the end of each phase.
- R7 lab 1 (11), lab 2 (15), and the challenge (16) passed; `./bin/lab check r07 all` passed 42/42 after rebooting **both** machines. The walk started from `clean`, created a 512 MiB VFAT partition on `/dev/vdb` with `uid=`/`gid=`/`umask=` mount options, exported `/srv/r7/export` to `10.10.10.0/24` from `server` and opened `nfs`, `mountd`, and `rpc-bind`, mounted it by hand and then through autofs on `node2`, and built `r7vg` on a 1.5 GiB second partition with a 512 MiB ext4 `r7data`. A 100 MB `blob.bin` was written before `lvextend -L +512M` and `resize2fs`, and its checksum was unchanged after an offline `e2fsck -fy` and a reboot. Writing to the export as root failed with `Permission denied` (`root_squash`), and writing as `labuser` produced a file owned by `labuser` on both machines. `findmnt --verify` reported no errors at the end of each phase.
- R8 lab 1 (13), lab 2 (12), and the challenge (18) passed; `./bin/lab check r08 all` passed 43/43 after rebooting **both** machines. The walk started from `clean`, corrected the snapshot's stale clock in Lab 1 Step 0 with `systemctl restart chronyd` and `chronyc waitsync 30 0.1`, then installed `at`, created `/etc/cron.d/r8-heartbeat` and a `labuser` crontab, and queued one `at` job. Lab 2 replaced the cron work with an `OnCalendar=*:0/2` timer, added `allow 10.10.10.0/24`, opened `ntp`, set `Europe/Berlin`, and pointed `node2` at `10.10.10.10`. The challenge added `/usr/local/sbin/r8-report` under an `hourly` `Persistent=true` timer and `/usr/local/sbin/r8-archive` under a Sunday 03:30 cron line, then proved pruning by running the report service four times. On the first clean walk the user cron job failed because `/srv/r8/home` was root-owned; the lab now creates it with `install -d -o labuser -g labuser`.
- R9 lab 1 (12), lab 2 (10), and the challenge (13) passed; `./bin/lab check r09 all` passed 35/35 after rebooting **both** machines. The walk started from `clean`, created a dummy connection `lab0` with `192.0.2.10/24` and `2001:db8::10/64`, DNS `192.0.2.53`, search domain `r9.lab`, and `never-default` on both families, then added the `r9peer` hosts line. Lab 2 created the `r9web` zone with `http`, `8080/tcp`, and `lab0`, proved that `node2` could not reach `8080` through `public`, opened `9090` at runtime and watched it vanish on `--reload`, made `8080` permanent, and fetched the page from `node2`. The challenge set the static hostname `server.r9.lab`, added the `r9api` hosts line, opened `8443/tcp` permanently, and fetched both pages from `node2`. Two checker bugs were found and fixed during the walk: `nmcli -g ipv6.addresses` escapes the colons (`2001\:db8\:\:10/64`), so `conn_v6` strips backslashes before comparing; and the first `/etc/hosts` helper mis-parsed the file, so `hosts_has_ip` now matches the address in field 1 and the name in a later field. The docs also explain why `getent hosts <own-fqdn>` returns IPv6 and link-local answers through `myhostname`, while `getent ahostsv4` gives the address a service actually uses.
- R10 lab 1 (11), lab 2 (10), and the challenge (21) passed; `./bin/lab check r10 all` passed 42/42 after rebooting **both** machines. The walk started from `clean`, installed `httpd` and `policycoreutils-python-utils` in Lab 1, hit the `name_bind` denial on `18443`, labelled the port, hit the `getattr` denial on `/srv/r10/www`, added the `semanage fcontext` mapping and relabelled, then hit the `name_connect` denial on the proxy and proved `setsebool -P httpd_can_network_connect on` fixes it. Lab 2 created `r10deploy`, generated `/home/labuser/.ssh/r10_ed25519`, installed the public key, and proved that `10-r10.conf` wins the first-value-wins race while `60-r10.conf` does not. The challenge added the source-restricted rich rule and fetched the page from `node2`. After the reboot `Enforcing`, the port label, the `fcontext` mapping, the Boolean, the `sshd` drop-in, and the key login all held; `/api/` returned `503` because the hand-started backend is not a service, which is why the checker starts its own. One checker bug was found and fixed during the walk: `semanage port -l -C` prints `type proto port`, so `port_label` reads field 2 and 3, not 3 and 4.

- R11 lab 1 (10), lab 2 (8), and the challenge (13) passed; `./bin/lab check r11 all` passed 31/31 after rebooting `server`. The walk started from `clean`. Lab 1 read `get-default`, demonstrated `isolate graphical.target` (default unchanged), then `set-default graphical.target`, rebooted through the serial console, confirmed `graphical.target` was active, and set the default back to `multi-user.target`. It set `GRUB_TIMEOUT=10`, ran `grub2-mkconfig`, forced `menu_auto_hide=0`, watched the ten-second menu, added `panic=10` with `grubby --update-kernel=ALL`, and proved `/proc/cmdline` did not have it until the next boot. The one-boot override used `systemd.unit=graphical.target` in the GRUB editor: the target became active while `get-default` stayed `multi-user.target`, and the following unedited reboot dropped the override and kept `panic=10`. Lab 2 locked root (`root L never`), booted `rd.break`, remounted `/sysroot` read-write, chrooted, set the password to `R11-recovery`, touched `/.autorelabel` and `/root/r11-recovered`, watched `ls -Z` show `?`, and let the relabel boot finish. After it, `root P 2026-11-11`, `shadow_t`, `admin_home_t`, no `/.autorelabel`, `Enforcing`, and a root console login worked; a second reboot kept all of it. The challenge ran `dnf -y upgrade` (66 altered), confirmed `check-update` moved from 100 to 0, added `panic_on_warn=1` to every entry, rebooted, and proved `panic_on_warn=1` in `/proc/cmdline` and `1` in the live sysctl, with `uname -r` equal to the newest `kernel-core`. One checker bug was found and fixed: `grep -q` in a pipeline under `set -o pipefail` failed with SIGPIPE, so `cmdline_has`, `label_is`, and `upgrade_ok` now use `grep ... >/dev/null`. Lab 1's expected target was also changed to `multi-user.target` when the lab was changed to end on the production default rather than leave the machine graphical.

The 2026-11-07 run produced the same R1 numbers on the previous box image; the 2026-11-08 box pin, the removal of `LAB_BOX`/`LAB_ISO`, and the `firewalld` install are covered by the 2026-11-10 run.

**Base-image bug found and fixed on 2026-11-10:** the AlmaLinux box ships `/etc/sudoers.d/vagrant` at mode `0644`. `sudo` still works because `90-cloud-init-users` repeats the grant, but `visudo -c` reports `bad permissions` and exits 1, which failed the R2 `the whole sudoers configuration parses` check on an otherwise perfect lab. `labs/provision/common.sh` now chmods it to `0440`. Do not weaken that checker: a bad mode is exactly the kind of real misconfiguration it exists to catch.

This host is one data point. Re-run the smoke test after changing the Vagrantfile, provisioning, or the box.

**Applying a provisioning change to an existing lab** (maintainer only, not a learner command): `cd labs && vagrant provision` re-runs `common.sh` and `node2.sh` without rebuilding. It resets anything the scripts set — `labuser`'s password, the sudoers drop-in, the `lab-private` connection — so never use it mid-exercise. Learners pick up provisioning changes with `./bin/lab reset`.

**Two behaviours confirmed on the 2026-11-10 run:** a login shell picks up `umask 027` from `~/.bash_profile` (`su - devon -c umask` → `0027`), and `LC_ALL=C chage -l` renders `Dec 31, 2027` / `Jun 30, 2028` exactly as the docs show.

---

## 5. Lab environment

| Machine | Address | Resources | Role |
|---|---|---|---|
| `server` | `10.10.10.10` | 2 vCPU, 4 GB RAM, root disk + 10 GB `/dev/vdb` | Main practice system |
| `node2` | `10.10.10.11` | 1 vCPU, 2 GB RAM, root disk | SSH, NFS, firewall, client/server target |

**Users:**

| User | Password | Access |
|---|---|---|
| `vagrant` | `vagrant` | Passwordless sudo; provisioning |
| `labuser` | `labpass` | Member of `wheel`; normal sudo with password |

**Base box:** `almalinux/10`, pinned in the Vagrantfile. It is freely available and RHEL 10-compatible for the course objectives. There is no box override: the lab does not support swapping in a RHEL 10 box, and `LAB_BOX`/`LAB_ISO` were removed on 2026-11-08 because they were documented noise for a beginner audience and no shipped module used them.

**Repositories:** the VMs use the box's own online AlmaLinux repositories. Provisioning needs internet access on first boot. The exam's no-internet condition is simulated by disconnecting the VM, not by attaching an installation DVD.

**Base services:** the AlmaLinux cloud image does not ship `firewalld`. Provisioning installs and enables it, then asserts that SELinux is `Enforcing` and that firewalld is active *and* enabled. Those assertions exist because the docs (F1, F2) describe that base state; without them a box change would contradict the course silently.

**Cross-VM SSH:** `bin/lab up` generates `labs/keys/lab_ed25519`, uploads it to both nodes, installs it for `vagrant` and `labuser`, and writes `~/.ssh/config` entries for `server` and `node2`. `ssh labuser@node2` and `scp` work without extra flags.

**Private network:** the Vagrantfile forces `qemu_use_session = false` because vagrant-libvirt 0.11.x otherwise defaults to the session connection, which cannot create the private lab network. Both VMs attach to the libvirt network `rhcsa-lab` with DHCP disabled. `provision/common.sh` configures the second NIC with a NetworkManager profile named `lab-private`, so `10.10.10.10` / `10.10.10.11` survive reboot.

**Lab commands:** `./bin/lab doctor|up|status|ssh|console|snapshot|restore|check|halt|reset|destroy`.

**Serial console:** `./bin/lab console [server|node2]` wraps `virsh -c qemu:///system console rhcsa<name>`; ++ctrl++] detaches and the VM keeps running. Both nodes boot with `console=tty0 console=ttyS0,115200n8`, and provisioning also enables `serial-getty@ttyS0` so a login prompt appears there. R11 needs it: SSH cannot show GRUB, the initramfs, or `sulogin`.

**Checker wrapper:** `./bin/lab check <module> [lab1|lab2|challenge|all]` uploads `labs/checks/<module>/check.sh` to `server` and runs it as root.

---

## 6. Content conventions

Every RHCSA module follows the same anatomy:

1. **Theory** — mental model, commands, and why they matter.
2. **Guided Lab 1** — step-by-step with expected output.
3. **Guided Lab 2** — a second skill cluster.
4. **Challenge lab** — exam-style requirements only, no steps.
5. **Reboot-persistence test** — the configuration must survive a reboot.
6. **Automated checker** — verifies the end state, not the commands used.
7. **Knowledge check** — questions with hidden answers.
8. **Cheat sheet** — compact review.

**Hard rules:**

- Every configuration task must include a persistence check.
- A module is not done until its checker passes from a clean snapshot.
- Original content only. Do not copy Red Hat courseware, exam questions, or instructor materials.
- Prefer official documentation and `man` pages as references.
- Use relative links in Markdown. Add every page to `mkdocs.yml`.
- Put commands in ` ```bash ` blocks. Put command output, transcripts, and syntax synopses in ` ```text { .no-copy } `: Material skips the copy button for `.no-copy`, and `extra.css` draws a muted left edge, so a reader can tell at a glance what is runnable. Never leave output in a plain `text` block — the copy button invites pasting a transcript into a shell.
- State the preconditions of an example that writes anything or depends on an earlier step: which directory to run it in, and what it creates. `tar -czf demo.tar.gz /etc/hostname` writes to the current directory, and the `tar -tzf demo.tar.gz` on the next line reads that file. Say so, or add the `cd`.
- Do not assume the reader will run every example while reading. Say once per page, where it matters, that the commands are reference material to return to, not a list to memorise.
- Keep the disclaimer and licensing notices intact.
- Do not commit generated keys (`labs/keys/`) or build output (`site/`).
- Do not disable SELinux or firewalld in a lab unless the lesson is specifically about doing so.
- Do not claim a lab was validated without running it.
- The foundations are optional except F2. State that once, in `docs/start-here/how-to-use.md` and `docs/foundations/index.md`: an experienced admin may skip F1 and F3–F8, but F2 teaches the lab and snapshot workflow, which is course logistics rather than Linux knowledge. Do not add per-module "skip ahead to R1" links — they read as permission to skip the rest of the foundations.
- `PACKAGES` in `labs/provision/common.sh` is base state only: things F1 and F2 assert, or that every module needs before it starts. A module that needs a package installs it in its own lab. Do not grow `PACKAGES` for module features — it would force every existing learner to rebuild mid-course.

**Check-script conventions.** The reference implementations cover different kinds of state:

- **R1 (`labs/checks/r01/check.sh`) — filesystem state.** Use it as the model for anything under `LAB_ROOT`: files, links, modes, ownership, archives, checksums.
- **R2 (`labs/checks/r02/check.sh`) — account state.** Use it as the model for users, groups, passwords, aging, `sudo`, and anything else that lives in a system database rather than a file under `/srv`.
- **R4 (`labs/checks/r04/check.sh`) — program behaviour.** Use it when the deliverable is a script. It builds fixtures with `mktemp -d`, runs the learner's script against them, and compares stdout and exit status. Nothing in it greps the script's source for particular commands.
- **R5 (`labs/checks/r05/check.sh`) — live service state.** Use it for systemd units, the journal, and `tuned`. It asks `systemctl`, `journalctl`, and `tuned-adm` what they think, and reads the process's real nice value with `ps`; one check is behavioural (kill the main PID, wait for a new one).
- **R6 (`labs/checks/r06/check.sh`) — live block-device and mount state.** Use it for partitions, LVM, filesystems, swap, and fstab. It reads the partition table with `parted` and `sfdisk`, the LVM metadata with `pvs`/`vgs`/`lvs`, the superblocks with `blkid`, and the live mount table with `findmnt`. Size checks are ranges, not exact equality, because a correct disk loses a little room to alignment.
- **R9 (`labs/checks/r09/check.sh`) — network configuration plus behaviour.** Use it when a rule can exist and still not work. It reads the `nmcli` keyfile, the live addresses, `/etc/hosts`, and both firewalld layers, then starts its own HTTP listener and fetches it from `node2` as `labuser`. That split — configuration questions answered from files, reachability answered by a real client — is the model for any networking check.
- **R10 (`labs/checks/r10/check.sh`) — policy and daemon state.** Use it for SELinux and for any service whose configuration is merged from includes. It pairs evidence deliberately: the live file label with the persistent `semanage fcontext` record, the live port label with the `semanage port -l -C` record, the Boolean's running value with its persistent value, and the effective `sshd -T` output with two real logins. The Boolean is also proved behaviourally by proxying to a fixture the checker starts itself.
- **R11 (`labs/checks/r11/check.sh`) — boot state.** Use it for targets, the bootloader, kernel arguments, and recovery. It reads `/etc/default/grub` and `grub.cfg` separately, every BLS entry with `grubby --info=ALL`, `/etc/kernel/cmdline`, and the running `/proc/cmdline`; a setting that reaches only one of those layers is the mistake being checked. It proves recovery by account usability (`passwd -S` `P*`, a date that is not `never`), a marker file, and the labels only a finished relabel boot restores — never the password. It proves an update two ways (`dnf history` return code plus `dnf check-update` exit 0) and requires `uname -r` to match the newest installed `kernel-core`.

All of them follow these rules:

- Run as root inside `server`.
- Accept `lab1|lab2|challenge|all`.
- Use `LAB_ROOT` (default `/srv`) where the module has a file tree, so the tree checks can be tested without a VM. R5, R6, and R10 have no tree; their state is live.
- Print `PASS`/`FAIL` per criterion and exit non-zero if any fail.
- Inspect end state, not the commands used.
- Include node2 checks where the lab involves the second machine.

Account-state checks add these rules:

- Prefix anything parsed from `chage` or `passwd` with `LC_ALL=C`. The labels and date formats are locale-dependent, and a checker that passes in English will silently fail elsewhere.
- Match `passwd -S` on a status **prefix**: `P*` for usable, `L*` for locked. RHEL prints `PS`/`LK`; other shadows print `P`/`L`. `NP` must not count as usable.
- Never assert a password, a hash, or a `$6$` prefix. Assert usability and lock state instead.
- Prove a `umask` from a **fresh login shell** (`sudo -H -u user bash -lc`), never from the shell where it was set.
- Validate `sudoers` with `visudo -cf` on the file and `visudo -c` on the whole configuration. A drop-in that parses alone can still break the stack.
- Add at least one negative check that proves the lab is not broken — R2 asserts `labuser` still has `wheel`, which catches a learner who dropped `-a` from `usermod -aG`.
- Cheap negation checks (`user X does not exist`, `X is not in group Y`) pass vacuously on a fresh machine. That is deliberate and acceptable; do not treat a single passing line as evidence the lab was done.

Behaviour checks (R4) add these rules:

- Build every fixture in `mktemp -d` and delete it on exit with a `trap`. Never borrow the lab's own sample directory: a script that hardcodes the lab's answers would then pass.
- Compare **stdout and exit status**, not stderr text. An error message is a diagnostic, not a contract; the exit code is the contract.
- Print the expected and actual values on failure (`%q` shows spaces and newlines). For a script, "FAIL" alone is nearly useless — the learner needs to see what their script printed.
- Assert exit codes with `rc_is`, output with exact-string or line-set comparisons. Keep one negative check where it teaches something (R4 asserts the subdirectory was not counted, which catches `find` without `-maxdepth`).
- Gate every negative check on a non-empty result. "The subdirectory is absent" is true when the script printed nothing at all, so the R4 predicates require `[ -n "$OUT" ]` first; without that guard a clean snapshot passes four checks that should fail.
- A missing or non-executable script makes every behavioural check fail with `exit 127`. That is honest and still readable, because each line names the script.

Service-state checks (R5) add these rules:

- Read the **effective** unit, not the file: `systemctl show -p Nice --value`, `-p DropInPaths`, `-p ExecStart`, `-p Restart`, `-p LoadState`. A learner may have used a drop-in instead of editing the unit, and both are correct.
- Read the **process** as well as the unit: `ps -o ni= -p "$(systemctl show -p MainPID --value unit)"`. `systemctl show -p Nice` reports the configuration and will happily say 10 while the running process still has 0.
- Assert `is-enabled`/`is-active` through `val_is`, so the failure prints the actual word (`disabled`, `inactive`, `masked`). Those two verbs already print one word and set the exit status; no parsing needed.
- Prove persistence with time, not with a flag. The journal check compares `_BOOT_ID` with `/proc/sys/kernel/random/boot_id` and requires at least one entry from an **earlier** boot. That is why `lab2` fails until the learner reboots, and the failure message says so.
- Read merged configuration with `systemd-analyze cat-config`, never `/etc/systemd/journald.conf`. A drop-in is the supported way to set `SystemMaxUse`, and the main file will not show it.
- Prefer one behavioural check over another state check when the promise is a behaviour: `Restart=always` is proven by killing the main PID and waiting for a different one. Guard it with a real PID and a bounded wait (20 × 0.5 s), and fail with the old PID, the new state, and the new PID.
- Do not assert that `systemctl --failed` is empty. This lab's `NetworkManager-wait-online.service` fails at boot on a correct machine, and a module-level failure is not the learner's fault.

Block-state checks (R6) add these rules:

- Verify a partition's type by its **GPT type GUID** with `sfdisk -d`, not with `lsblk -o PARTFLAGS` or `PARTTYPE`. On the AlmaLinux 10.2 image those two columns are empty even when `parted` prints the `lvm` flag, and parsing `parted`'s prose is version-sensitive.
- Read sizes in **bytes** (`blockdev --getsize64`, `lvs --units b`, `findmnt -b -o SIZE`) and assert a range. `lsblk` and `parted` round, and `parted` reports a 5 GiB partition as `5369MB` in decimal units.
- Build the expected fstab source from the filesystem's own identifier (`blkid -s UUID -o value`, `blkid -s LABEL -o value`). That way a stale UUID left in fstab from an earlier attempt fails instead of matching itself.
- Check both views of a mount: `findmnt <target>` for what is mounted now and `findmnt --fstab <target>` for what boot will do.
- Run `findmnt --verify` as one check. It validates the whole fstab and only passes after `systemctl daemon-reload`; it is the closest thing to a boot test without rebooting.
- Prove non-destructive growth in two parts: `lvs` for the logical volume and `findmnt -b -o SIZE` for the filesystem. `lvextend` alone leaves `df` at the old size, which is the mistake the challenge exists to catch.
- Include regression checks. R6 Lab 2 asserts Lab 1's mount still works, and the challenge asserts both earlier labs are intact, because `all` runs the three phases as one state stack.

Boot-state checks (R11) add these rules:

- Read the **intent** and the **generated** bootloader files separately. `/etc/default/grub`, `/boot/grub2/grub.cfg`, `/boot/loader/entries/*.conf`, and `/etc/kernel/cmdline` can disagree, and each disagreement is a real failure mode.
- Check a kernel argument on **every** BLS entry with `grubby --info=ALL` **and** in `/proc/cmdline`. The first proves what the next boot will do; the second proves what this boot did.
- Treat a kernel argument as a promise about the next boot. The live `/proc/cmdline` and `/proc/sys/kernel/*` checks must fail until the learner reboots; say so in the failure text.
- Prove recovery without asserting a password: `passwd -S root` must return a `P*` status, the last-change field must not be `never`, the marker file must exist and be root-owned, and `/etc/shadow` plus the marker must carry `shadow_t` and `admin_home_t`. `/.autorelabel` must be gone.
- Prove an update two ways: an `upgrade`/`update` transaction in `dnf history` whose `Return-Code` is `Success`, and `dnf check-update` exiting 0. Require `uname -r` to equal the newest installed `kernel-core`, which forces the reboot.
- Guard the stack: Lab 1 must leave the production default target that the challenge also expects, or `all` (which runs lab1, lab2, and challenge against one end state) can never pass. The R11 lab proves `set-default` by visiting `graphical.target` and returning to `multi-user.target`.
- Never assert a boot *duration*, a GRUB menu screenshot, or a timer's `NEXT` value. Read the setting (`GRUB_TIMEOUT`, `set timeout=`) and the produced state (`/proc/cmdline`), not the numbers a particular boot printed.

Capstone checks (R12) add these rules:

- **One host, every layer.** R12 is not a new topic, so its checker is a union of the modules it closes: storage (`sfdisk -d`, `lvs`, `blkid`, `findmnt`), accounts (`id -gn`, `passwd -S`, `chage -l`), SELinux (`ls -Z`, `semanage fcontext -l -C`, `semanage port -l -C`), the service (`systemctl`, `ss`), the firewall in both layers, a timer's produced artefact, and the boot target.
- **The proof is a request from the other machine.** The web check runs `curl` on `node2` as `labuser`, because a local request proves the service and nothing about the zone. This is the same rule as R9 and R10.
- **A repair is only a repair if the rest of the host still works.** `lab2` asserts the three repaired layers first, then runs the entire `lab1`/`service_host` block. The lab is designed so that fixing the symptom in the wrong layer leaves a regression the second half catches.
- **A timer check is a check for an artefact, and a restored snapshot clock can lie.** `stamp_fresh` accepts a stamp newer than `/proc/stat`'s `btime` **or** within three minutes of now, and polls for up to 90 s. Right after a reboot the previous boot's stamp can look hours old; a fixed window reports a false failure. This is the same reasoning as R8's `check_n2_sync`.
- **`all` is the normal workflow here.** Unlike R1–R11, Lab 2 **ends** where Lab 1 does (the three breakages are repaired), so `check r12 all` is valid on one continuous walk and is the documented persistence test. The labs say to restore `clean` only before a mock exam.
- **Use `chcon -t var_t` as the deterministic SELinux break.** `semanage fcontext -d` followed by `restorecon` can still apply the old record once; `chcon -t var_t` always produces the `403` and the `getattr` AVC that the lab teaches. The repair is the record plus `restorecon`, which is what the checker asserts.

---

## 7. Curriculum map

### Foundations (M1 — complete)

| Module | Topic | Status |
|---|---|---|
| F1 | Linux, open source, and the RHEL family | **Complete; walked 2026-11-10** |
| F2 | The lab: virtualization and first login | **Complete; walked 2026-11-10** |
| F3 | Shell, commands, and the help system | **Complete; walked 2026-11-10** |
| F4 | Filesystem hierarchy and file operations | **Complete; walked 2026-11-10** |
| F5 | Streams, redirection, pipes, grep, regex | **Complete; walked 2026-11-10** |
| F6 | Users, permissions, ownership | **Complete; walked 2026-11-10** |
| F7 | Processes, systemd, logs | **Complete; walked 2026-11-10** |
| F8 | Networking and storage foundations; SELinux intro | **Complete; walked 2026-11-10** |

Foundations modules are lighter than RHCSA modules: explanation, diagram/table, small commands, and a self-check. They do not need automated checkers.

### RHCSA modules

| Module | Focus | Objective group | Status |
|---|---|---|---|
| R1 | Essential tools | 1 | **Validated 2026-11-10** |
| R2 | Users, groups, password aging, sudo, default permissions | 9 + part of 10 | **Validated 2026-11-10** |
| R3 | Software: DNF, RPM repos, Flatpak | 2 | **Validated 2026-11-10** |
| R4 | Shell scripting | 3 | **Validated 2026-11-10** |
| R5 | Processes, systemd services, journald, tuned | 4 | **Validated 2026-11-10** |
| R6 | GPT partitions, LVM, swap, fstab by UUID/label | 5 | **Validated 2026-11-10** |
| R7 | VFAT, NFS, autofs, filesystem repair and online ext4 growth | 6 | **Validated 2026-11-10** |
| R8 | cron, at, systemd timers, chrony, timezones | 7 | **Validated 2026-11-10** |
| R9 | nmcli, IPv4/IPv6, hostname resolution, firewalld | 8 | **Validated 2026-11-11** |
| R10 | SELinux, SSH keys, firewall hardening | 10 | **Validated 2026-11-11** |
| R11 | Boot targets, GRUB, rescue, rd.break, updates | 4 + 7 | **Validated 2026-11-11** |
| R12 | Capstone: full-stack rehearsal, diagnostic loop, timed mock exams | All | **Core validated; exams pending** |

Status values: **Validated** means the checker has passed from a clean snapshot on a real lab. **Complete; walked** (foundations) means every command in the page was run on the 2026-11-10 lab; foundations have no automated checkers. **Content complete; validation pending** means the full anatomy is written and syntax-checked but has not been walked end to end on a VM. **Planned** means not started. A module moves to **Validated** only after its checkers are re-run on `server`, not because the files exist.

The objective-to-module mapping lives in `docs/reference/objective-coverage.md`. Keep it in sync when a module lands.

---

## 8. Decisions and rationale

| Decision | Rationale |
|---|---|
| R11 ends on `multi-user.target`, not `graphical.target` | The `all` checker runs lab1, lab2, and challenge against one end state. Lab 1 proves `set-default` by setting `graphical.target`, rebooting, and then returning to `multi-user.target`, so the challenge can require the headless default without contradicting Lab 1. The graphical round-trip is the proof; multi-user is the production setting. |
| R11 needs a serial console, so the lab kit gained one | GRUB, the initramfs, `sulogin`, and a locked root account are invisible over SSH. Provisioning now sets `console=tty0 console=ttyS0,115200n8`, `GRUB_TERMINAL_INPUT/OUTPUT="console serial"`, `GRUB_SERIAL_COMMAND`, and `serial-getty@ttyS0`; `./bin/lab console` wraps `virsh console`. Without it the module could not be taught or checked honestly. |
| R11's challenge argument is `panic_on_warn=1` | `panic_on_oops` is already 1 on this image, `loglevel=7` is already the printk default, and `nmi_watchdog` is already 0, so none of those produces a visible change. `panic_on_warn` defaults to 0, is readable at `/proc/sys/kernel/panic_on_warn`, and pairs with `panic=10` to describe a server that reboots itself. |
| R11 proves an update two-sided | `dnf history` alone passes a no-op transaction; `dnf check-update` alone passes a machine that was never updated but has no pending packages after a partial mirror. The checker requires a successful `upgrade`/`update` transaction **and** `check-update` exiting 0, then `uname -r` matching the newest `kernel-core` so the kernel reboot is part of the task. |
| R11 never asserts a root password | The lesson is recovery, not secret storage. `passwd -S root` (`P*` and a date that is not `never`), the marker file, and the labels restored by the relabel boot prove the account is usable and the repair completed. A test password in the repository would be both a secret and a brittleness trap. |
| R11 teaches `rd.break` before `init=/bin/bash` and rescue mode | `rd.break` is the tool the exam is most likely to ask for and the one that needs `/sysroot` remounted and `/.autorelabel` touched. The other two doors are demonstrated afterwards so the learner knows when each is the right choice: `init=/bin/bash` for a real-root shell without systemd, rescue mode when the root password still works. |
| `grep -q` is forbidden in R11's pipeline predicates | With `set -o pipefail`, `grep -q` closes the pipe early, the upstream command dies of SIGPIPE, and the predicate returns failure even though the match succeeded. `cmdline_has`, `label_is`, and `upgrade_ok` use `grep ... >/dev/null` and read the whole input. |
| R11's snapshot clock can be stale | A restored snapshot carries the clock it was saved with. Lab 1 does not schedule anything, so it does not matter here, but a learner who compares `date` to the host should know that R8's `chronyc waitsync` is the fix, not a broken VM. |
| Target EX200 v10 / RHEL 10 | Current exam platform; adds Flatpak and systemd timers; drops Podman and set-GID |
| MkDocs Material | Markdown-first, good search/navigation, easy GitHub Pages deploy |
| GitHub Pages + Actions | Free hosting, no server to maintain |
| AlmaLinux 10 as the lab OS | No public generic RHEL 10 Vagrant box; AlmaLinux is RHEL-compatible and subscription-free |
| Two VMs (`server`, `node2`) | Needed for SSH, NFS, firewall, and client/server exercises |
| Remove `LAB_BOX` and `LAB_ISO` (2026-11-08) | Two advanced overrides documented in three beginner-facing places; no shipped module used them. Lab is pinned to AlmaLinux 10. The offline-repo teaching need moved to R3, which uses a local RPM directory as a `baseurl`. |
| Shared lab SSH key | Makes cross-VM `ssh`/`scp` work for beginners without teaching key setup before R10 |
| `labuser` account | Gives a non-root account for permission and sudo exercises |
| Free core + paid extras | Keeps the course useful and marketable without paywalling exam preparation |
| CC BY-NC-SA content + MIT code | Allows sharing/adaptation, prevents commercial reuse of the course text |
| R1 checker with `LAB_ROOT` | Allows local testing without a VM and keeps checks deterministic |
| R2 checks account state, not files | `getent`, `id`, `chage`, `passwd -S`, `visudo -c`, and `sudo -l -U` are the only reliable way to prove users, groups, aging, and sudo policy; parsing `/etc/shadow` by hand would test the file, not the system |
| R2 owns `/etc/sudoers.d/10-r2-operators` | The lab already has `90-rhcsa-labuser` for `labuser`. Giving the module its own drop-in means a learner who breaks theirs cannot lock out the account they need to fix it |
| R2 sets the umask per user, not system-wide | A system-wide `umask 027` in `/etc/profile.d` would make every file root creates by redirection in R5–R11 `640`. A service running as another user would then fail to read its own config, which is a confusing failure that has nothing to do with the lesson |
| R2 never asserts a password or hash | The checker proves usability (`passwd -S` → `P`, printed as `PS` on older releases) and lock state (`L`/`LK`). Storing an expected password in the repository would be both a secret and a brittleness trap |
| Provisioning repairs the mode of the box's `/etc/sudoers.d/vagrant` | The AlmaLinux box ships that drop-in at `0644`. `sudo` still works because `90-cloud-init-users` repeats the grant, but `visudo -c` exits non-zero on the bad mode, which made the R2 checkers fail on a correct lab. `chmod 0440` in `common.sh` fixes the root cause; loosening the checker would have hidden a real misconfiguration in the learner's own configuration |
| Foundations optional except F2 (2026-11-09) | The skip offer is skill-based, but F2 is course logistics: the VMs, `./bin/lab`, snapshots, and reboot-and-recheck. `how-to-use` and `lab-setup` summarise the commands, but F2 is the only page that explains the loop and the guest/host boundary. An experienced admin can skip the Linux theory, not the operating procedure |
| `all` checker assumes every lab end state | Individual checks are recommended when the learner restores snapshots between labs |
| R3 uses a directory of RPMs as a `baseurl` (2026-11-10) | The objective is "configure access to repositories, including the local filesystem". A `createrepo_c` directory served over `file://` teaches the whole mechanism with no media to mount, and it is where the removed `LAB_ISO` path was headed. |
| R3 simulates "no internet" by disabling the distro repositories (2026-11-10) | Cutting the VM's network also drops the learner's SSH session, so a repository lesson becomes a connectivity lesson. `dnf config-manager --set-disabled` produces the exam's exact failure (`Unable to find a match`) while the session stays alive. This supersedes the older "disconnect the VM" plan. |
| R3's Flatpak remote is Flathub | The objective is "configure access to Flatpak repositories". Flathub is the public reference remote and one command to add; building a local OSTree repository would add machinery without teaching anything the objective asks for. Lab 2 therefore needs internet, and the module says so. |
| R3 Lab 2 installs an app, then removes it | Leaving `org.gnome.Calculator` installed would contradict the challenge's "no Flatpak application" requirement, so `check r03 all` could never pass. The lab ends with a configured remote and an empty store; the challenge tests that same end state from scratch. |
| R3 checker pins every `dnf` query to one repository | `--disablerepo='*' --enablerepo=<id>` keeps the checker off the network: same answer offline, and a distro repo that happens to carry the package cannot make a pass look real. |
| R4 checks behaviour, not source (2026-11-10) | A script is a program; the only honest test is to run it. Grepping for `if` or `for` would pass a script that prints the right words and fails on any other input. The checker supplies its own fixtures, so hardcoding the lab's sample output cannot pass. |
| R4 fixtures are built in `mktemp -d` | They must not be the lab's own files. Independent paths and line counts (3, 5, 2, and an empty file) prove the script computes rather than remembers, and the whole checker then runs off-VM with `LAB_ROOT`. |
| R4's challenge reads a passwd **file argument**, not `/etc/passwd` | The result would otherwise depend on which accounts the machine has, and a missing home on the real system would make a correct script "fail". A captured file makes the task reproducible and teaches why scripts take input as arguments. |
| R4 scripts live in `/srv/r4/bin` | Keeps every module's artefacts under `/srv`, so `restore clean` removes R4 completely and no module leaves files in `PATH` for the next one. `/usr/local/bin` is taught as the persistent alternative, not used. |
| R5 programs live in `/usr/local/bin`, not `/srv` (2026-11-10) | systemd runs as `init_t`, which may execute `bin_t` (`/usr/local/bin`) but not `var_t` (`/srv`). A unit pointing at `/srv/r5/bin/worker` fails with `status=203/EXEC` and "Permission denied" even though the file is executable and the root shell can run it. Lab 1 walks into that failure on purpose, then installs the program with `install -m 0755` and explains `ls -Z`, because the same message in the exam looks like a missing file. R4's `/srv` rule does not apply: those scripts are run by a shell (`unconfined_t`), not by systemd. |
| Journal persistence needs `journalctl --flush`, not just a restart (2026-11-10) | `mkdir -p /var/log/journal` plus `systemctl restart systemd-journald` leaves the machine-ID directory empty until journald next rotates; `--flush` moves the buffered entries to disk immediately, so `find /var/log/journal -name '*.journal'` and the persistence check work in the same session. Without it the lab appears to succeed and the checker fails for a reason the learner cannot see. |
| R5's checker reads live state and cannot run off-VM | The module is about systemd, journald, and tuned; faking them would only test the fakes. It is validated on `server` only, like R2's account predicates. Two Lab 2 checks require a reboot by design, and the last challenge check kills `r5-batch`'s main process to prove `Restart=always`. |
| `SIGTERM` and `SIGKILL` are taught as different end states (2026-11-10) | The first walk showed that `SIGTERM` on a unit's MainPID leaves it `inactive (dead)` with `Deactivated successfully`, while `SIGKILL` leaves it `failed` with `Result: signal`. An earlier draft said `failed` for both, which would have taught the wrong diagnostic: inactive after a kill means a clean exit, while failed means it did not shut down. Lab 1 does both, in that order, and the quiz asks which is which. |
| R6 installs `lvm2` in the lab, not in `PACKAGES` (2026-11-10) | Only R6 needs the LVM userland. Adding it to `PACKAGES` would force every existing learner to rebuild mid-course for one module, which the `PACKAGES` rule exists to prevent. The lab says the install needs a working repository; a learner who left R3's distro repositories disabled must re-enable them first. |
| R6 uses a 5 GiB first partition and a second partition for the challenge (2026-11-10) | The lab disk is 10 GB. A 5 GiB partition leaves room for a second one, and the first partition's ~5 GiB holds the 2 GiB `r6data`, the 512 MiB swap, the 512 MiB label volume, and 2 GiB free for the challenge's `lvextend -L +2G`. The second partition takes the rest with `100%`. |
| R6 verifies partition type by GPT type GUID, not `lsblk` flags (2026-11-10) | On the AlmaLinux 10.2 image `lsblk -o PARTFLAGS` and `PARTTYPE` print empty for these partitions even though `parted` prints the `lvm` flag, and `partx` reports `0x0`. The flag is really the GPT type GUID, which `sfdisk -d` prints as `type=E6D6D379-...`. The checker parses that GUID, which is machine-readable and stable. |
| R6 teaches one UUID mount and one LABEL mount (2026-11-10) | The objective names both. Lab 1 mounts XFS by `UUID=`; Lab 2 mounts ext4 by `LABEL=` and swap by `UUID=`. Seeing both in one fstab makes the trade-off concrete: a UUID is generated and safe, a label is chosen and must be unique. |
| R6 makes `findmnt --verify` the fstab check (2026-11-10) | It validates the whole file, not just the new line, and it catches the skipped `systemctl daemon-reload` with an explicit warning. It is the closest thing to a boot test without rebooting, so both labs and the challenge end with it. |
| R6 teaches `lvextend` and `xfs_growfs` as separate steps (2026-11-10) | `lvextend -r` does both, and the theory mentions it. The labs split them because the exam may ask which layer changed: `lvs` proves the volume grew, and `df` proves the filesystem followed. A single command hides that distinction. |
| R6's checker reads live block state and cannot run off-VM (2026-11-10) | The module is about partitions, LVM, filesystems, and mounts; faking `parted`, `pvs`, `blkid`, and `findmnt` would only test the fakes. Like R5, it was validated on `server` only, and it asserts sizes as ranges because alignment and filesystem overhead make exact byte counts wrong. |
| Force `qemu_use_session = false`; configure the private NIC in provisioning | vagrant-libvirt 0.11.x defaults to session mode, where `private_network` fails with "Network ... is not available". NetworkManager makes the static address reliable across Vagrant and AlmaLinux 10 versions. |
| R7 uses LVM for the ext4 growth challenge, not `parted resizepart` (2026-11-10) | `parted -s /dev/vdb resizepart 2 ...` refuses a mounted partition with "Partition /dev/vdb2 is being used", and the objective is to grow a filesystem **while it is in use**. LVM grows online, which is what the exam asks for; the partition is created once at a fixed 1.5 GiB and never resized. |
| R7's challenge partition is 1.5 GiB, not the rest of the disk (2026-11-10) | A 1.5 GiB PV is about 1533 MiB of extents. A 512 MiB LV leaves roughly 1 GiB free, which is exactly enough for `lvextend -L +512M`. Taking the whole disk would leave no visible constraint and no `VFree` arithmetic to reason about; sizing it tightly makes "is there room?" a real question the learner must answer with `vgs`. |
| R7's checker spans two machines (2026-11-10) | NFS is a two-machine lesson by definition. The checker runs on `server` and reaches `node2` as `labuser` over the shared lab key, so Lab 2's autofs state is verified where it actually lives. This is the first checker that depends on provisioning (the `~/.ssh/config` entries and the installed key), which is one more reason to run `./bin/lab check r07 lab2` with both VMs up. |
| R7 teaches `root_squash` through a failure, not a definition (2026-11-10) | The lab has the learner write to the export as root and meet `Permission denied`, then write as `labuser` and watch the ownership pass through. The mistake is the lesson: root on a client is not root on a server, and disabling the squash is the wrong fix. |
| R7 splits ext4 and XFS grow tools by argument (2026-11-10) | R6 grows XFS with `xfs_growfs <mount point>`; R7 grows ext4 with `resize2fs <device>`. The two are one line apart in the exam objective and are the most common tool/argument mix-up, so the challenge uses ext4 deliberately and the cheat sheet puts the two side by side. |
| R7 documents `e2fsck`'s "need terminal" behaviour (2026-11-10) | A non-interactive `e2fsck -f` exits 8 with `need terminal for interactive repairs` even on a clean filesystem, because it cannot ask questions. The lab says so once and gives `-y` for scripts, so a learner whose terminal is a pipe does not conclude the filesystem is damaged. |
| Vagrantfile pins `lv.cpu_mode = "host-passthrough"` (2026-11-10) | Newer libvirt/QEMU rejected the `host-model` CPU XML vagrant-libvirt generated (`CPU vendor specified without CPU model`), which made an existing domain un-updatable and `vagrant up` fail on `node2`. `host-passthrough` exposes the host CPU without the vendor/model pair. It was needed to get `node2` Vagrant-managed again and does not change the guest's view of the CPU. |
| R8 verifies schedules by their output, not their configuration (2026-11-10) | A crontab line or a unit file is a promise, and a promise is not a result. Every R8 phase asserts an artefact the scheduler produced: a line in `/var/log/r8-heartbeat.log`, a stamp in `/srv/r8/timer/last-run`, a report file, a tarball. That is why `lab1` fails until the learner has actually waited a minute, and why the challenge runs the report service four times rather than grepping the script. |
| R8 Lab 1 starts with a clock check (2026-11-10) | A restored snapshot carries the clock it was saved with; the clean snapshot came back about 14 hours behind the host. Scheduling anything before chrony steps the clock means waiting on the wrong minute and then debugging a correct configuration. Step 0 restarts `chronyd`, runs `chronyc waitsync 30 0.1`, and shows `timedatectl` before and after. This is also why `chronyc waitsync` is taught: it is the script-friendly way to say "block until the clock is trustworthy". |
| R8's user cron job needs `/srv/r8/home` owned by `labuser` (2026-11-10) | The first clean walk failed `the personal cron job has written its log` because `mkdir -p` created `/srv/r8/home` as root, so `labuser`'s job could not write there and the error went to mail. The lab now runs `install -d -o labuser -g labuser -m 0755 /srv/r8/home` and explains why. The failure is the most common real cron bug, so the fix is taught rather than hidden in provisioning. |
| R8 programs live in `/usr/local/bin` and `/usr/local/sbin`, not `/srv` (2026-11-10) | Same SELinux reason as R5: systemd runs as `init_t` and may execute `bin_t`, not `var_t`. R8's timer worker and both challenge scripts are launched by systemd or cron, so a `/srv` path would produce `203/EXEC` on the timer. Data (`/srv/r8/*`) still lives under `/srv` so `restore clean` removes it. |
| R8 makes the timer-housekeeping job a timer and the weekly archive a cron job (2026-11-10) | The split is deliberate teaching, not nostalgia. The hourly report must catch up after downtime, which only `Persistent=true` provides, so it is a timer. The weekly archive wants one fixed slot and no dependencies, which is exactly cron's strength. Showing both in one challenge makes the choice in the theory's comparison table concrete. |
| R8's challenge report name includes `$$` (2026-11-10) | The checker starts the service four times in a couple of seconds. A name built only from `date +%Y%m%d-%H%M%S` would collide and leave one file, so the pruning check could pass without pruning anything. Adding the PID makes four distinct files, so "keeps the three newest" is a real assertion. |
| R8's checker polls `node2` for synchronisation instead of sleeping once (2026-11-10) | `NTPSynchronized` is `no` for a few seconds after boot while chrony selects a source. A fixed `sleep 5` would be flaky on a loaded host; `check_n2_sync` polls for up to 60 s and fails with the last value it saw. The check is about the end state, not the delay. |
| R8 uses `line_is` for cron lines (2026-11-10) | `val_is` strips all whitespace so it can compare one-word values such as `enabled`. A cron line's spaces are load-bearing, and stripping them turned `* * * * * root /path` into `*****root/path`, which failed a correct job on the first run. `line_is` compares one line verbatim and is now the helper for any multi-field comparison. |
| R9 teaches firewalld on a dummy interface (2026-11-11) | A mistake with `nmcli` or a zone change on `eth1` ends the learner's SSH session, which turns a firewall lesson into a connectivity lesson and needs a console to recover. `lab0` is a real kernel interface with no physical backing, so every command is the one used on a real NIC, and nothing outside the machine can depend on it. |
| R9's static addresses come from the documentation ranges (2026-11-11) | `192.0.2.0/24` (TEST-NET-1) and `2001:db8::/32` cannot collide with anything real. The addresses are fixed by the lab, so the checker can assert them exactly; only the UUID and the link-local IPv6 address are generated. |
| R9 configures a DNS server that never answers (2026-11-11) | The objective is "configure hostname resolution", and the honest subset without a second resolver VM is: the DNS settings reach the profile and NetworkManager writes them to `/etc/resolv.conf`, while names themselves resolve through `/etc/hosts` — a legitimate part of the `nsswitch` chain. Running a real DNS daemon would add machinery without teaching a new command, and the module says plainly that `192.0.2.53` is a documentation address. |
| R9 proves the firewall with a request from `node2` (2026-11-11) | A rule can exist, be permanent, and still be in the wrong zone. Only a client whose traffic traverses the interface rules can tell the difference, so every phase ends with a real HTTP fetch from the other machine. The checker starts its own listener, so a stopped web server is not a failure, and a learner cannot pass by leaving a process behind. |
| R9 opens 8080 in `public` as well as in `r9web` on purpose (2026-11-11) | `node2` arrives on `eth1`, which is in `public`; the rule in `r9web` is invisible to it. The lab makes the learner meet that failure (`curl: (7) Failed to connect`) before fixing it, because zone selection by incoming interface is the concept most often missed. The checker verifies both zones, so neither half can be skipped. |
| R9 checks the runtime and permanent layers separately (2026-11-11) | `9090/tcp` is opened at runtime only and must be absent after `--reload`; `8080` and `8443` must be present in both layers. A checker that only asks the runtime question passes a configuration that dies at reboot, and one that only asks the permanent question passes a rule that is not active now. |
| R9 matches hosts mappings by address, not by name (`hosts_has_ip`) (2026-11-11) | Grepping `/etc/hosts` for `r9peer` passes on a stale line under a different address, which is exactly the mistake the lab is about. The helper requires the documented address in field 1 and the name in a later field, so a partial edit fails. |
| `conn_v6` strips `nmcli`'s backslash escapes (2026-11-11) | Terse `nmcli -g ipv6.addresses` prints `2001\:db8\:\:10/64`. Comparing that raw string fails a perfectly correct profile; stripping the backslashes keeps the profile as the subject of the check rather than the output format. |
| R9 records why the `lab0` zone survives a reboot (2026-11-11) | firewalld asks NetworkManager to remember the zone, and the assignment lands in the profile as `connection.zone=r9web`. Without that note a learner would expect `--add-interface` to be undone when the firewall starts before the dummy device exists; the lab explains the race and the two files involved. |
| R10 is one module, not two (2026-11-11) | SELinux and key-based SSH are separate exam bullets but the same lesson: the decision has already moved past the password and the permission bit. Building them as Labs 1 and 2 of one module lets the challenge combine them, and keeps the lab count at two guided labs plus a challenge, like every other module. |
| R10 uses `httpd` on 18443, not 8443 (2026-11-11) | RHEL 10 already labels 8443 as `http_port_t` (it is the cockpit/TLS alternate), so a `Listen 8443` would start without a `name_bind` denial and Lab 1 would have nothing to teach. 18443 is unlabelled, so the first start fails, the AVC names the port, and `semanage port -a` is the visible fix. |
| R10's custom document root is `/srv/r10/www` (2026-11-11) | `/srv` is `var_t`, so the `403` and the `getattr` AVC appear without any setup, and the module's own `semanage fcontext` mapping is what makes it work. Nothing in the lab touches `/var/www/html`, so the shipped label is still there to compare against. |
| R10 proves `httpd_can_network_connect` with a local proxy (2026-11-11) | The Boolean has no visible effect on the static page; it only matters when httpd makes an **outbound** connection. A `ProxyPass /api/` to `127.0.0.1:18081` turns it into a `503` that becomes a `200` after `setsebool -P`, and produces the `name_connect` denial that pairs with Lab 1's `name_bind`. Using a real remote service would add a second machine and a network dependency to a SELinux lesson. |
| R10's SSH hardening is applied to `server`, not `node2` (2026-11-11) | The checker must read the **effective** configuration with `sshd -T`, which needs root. Keeping the hardening on `server` lets the checker run locally and lets the learner test both the key path and the password path in the same shell. Hardening `node2` would need `sudo` over SSH from the checker and would test the transport instead of the policy. |
| R10's drop-in is `/etc/ssh/sshd_config.d/10-r10.conf` (2026-11-11) | `sshd` is first-value-wins, and the AlmaLinux cloud image ships `50-cloud-init.conf` with `PasswordAuthentication yes`. A drop-in named 50 or above is parsed and ignored, which is a silent failure the learner cannot see without `sshd -T`. Numbering it 10 makes it win, and Lab 2 demonstrates the failure by renaming it to 60 and watching `sshd -T` flip back. |
| R10's checker starts its own proxy backend (2026-11-11) | The lab's backend is `python3 -m http.server`, started by hand, so it is gone after the reboot. If the checker depended on it, a correct Boolean would fail the persistence test. Starting a fixture on 18081 means the Boolean is tested and the backend's lifetime is irrelevant. |
| R10 checks the password path by connecting, not by grepping (`offered_methods`, 2026-11-11) | The method list in `Permission denied (publickey,…,password)` is the daemon's own answer after includes and `Match` blocks. A checker that greps `PasswordAuthentication no` passes a drop-in that lost the ordering race. |
| R10 keeps `chcon` as a deliberate wrong turn (2026-11-11) | The lab applies `chcon`, shows the page working, then runs `restorecon` and breaks it again before writing the `fcontext` mapping. Telling a beginner that `chcon` is temporary does not stick; watching a working page revert does. |
| R10's rich rule is a source rule, and `--query-port` answers `no` (2026-11-11) | The challenge requires the port to be restricted, so a plain `--add-port` is the failure mode being tested. `--query-port=18443/tcp` returning `no` is the correct state and would read as broken to anyone who has only used `--add-port`; the docs and the cheat sheet say so explicitly. |
| R10 is the first module that installs its own web server (2026-11-11) | `httpd` and `policycoreutils-python-utils` are module features, not base state, so they stay out of `PACKAGES` and are installed in Lab 1. A learner who left R3's distro repositories disabled must re-enable them, exactly as with R6's `lvm2`, R7's `autofs`, and R8's `at`. |

---

## 9. Next steps (in order)

### M1 — Foundations F1–F8 — **done**

All eight modules follow the same pattern: module-meta table, theory with diagrams and tables, one hands-on lab, traps table, and a self-check with hidden answers. They have no automated checkers, by decision.

When adding or revising a foundation, repeat the same five steps:

1. Create `docs/foundations/fN-topic/index.md`.
2. Add it to the `Foundations` nav section in `mkdocs.yml`.
3. Include a small lab or command walkthrough and a self-check.
4. Link it from `docs/foundations/index.md`, and update the previous module's `## Next` link.
5. Run `mkdocs build --strict`.

### M2 — R2, R3, R4, R5, R6, R7, R8

- **R2 — done and validated 2026-11-10 (88/88 from a clean snapshot).** Users, groups, password aging, sudoers, default permissions. Checker verifies users/groups/password aging/sudo with `getent`, `id`, `chage`, `passwd -S`, `visudo -c`, and `sudo -l -U`. Design decisions worth keeping:
  - The module creates its own sudo drop-in (`/etc/sudoers.d/10-r2-operators`) and never touches `90-rhcsa-labuser`, so a learner editing sudoers cannot lock out the lab account by accident.
  - The umask is set per user in `~/.bash_profile`, not system-wide in `/etc/profile.d`. A system-wide `027` would make files root creates in later modules `640`, which can break services that need to read them as another user.
  - Password hashes are never asserted. The checker proves usability (`passwd -S` → `P`/`L`, printed `PS`/`LK` on older releases) rather than the password itself.
  - A negative check (`labuser still has sudo through wheel`) catches a learner who removed `-a` from `usermod -aG`.
- **R3 — done and validated 2026-11-10 (33/33 from a clean snapshot).** DNF repositories, RPM install/remove, Flatpak remotes and packages. Design decisions worth keeping:
  - The local repository is a plain directory of RPMs served over `file://`, built with `createrepo_c`. No ISO, no DVD, no `LAB_ISO`.
  - The exam's no-internet condition is simulated by persistently disabling the four distro repositories, not by cutting the VM's network. Cutting the interface also kills the learner's SSH session, which teaches the wrong lesson (see the decisions table).
  - `flatpak` is installed inside the lab, not added to `PACKAGES`.
  - Lab 2 installs Flathub's `org.gnome.Calculator`, inspects it, removes it, and runs `flatpak uninstall --unused`, so the lab ends with a configured remote and an empty store. That end state is what the challenge also expects, which is why `check r03 all` can pass: the three lab end states stack instead of overwriting each other.
  - Every `dnf` query in the checker is pinned with `--disablerepo='*'` and one explicit `--enablerepo`, so the checker never contacts a mirror and gives the same answer on an offline machine.
  - Package provenance is asserted with the `@repo` column of `dnf list`, not by trusting that the learner used a particular command.
  - The challenge requires the distro repositories to stay disabled, so the docs tell the learner to run the checker **before** re-enabling them; `all` assumes the challenge end state, the same way R1 `all` assumes every lab's files are still present.
- **R4 — done and validated 2026-11-10 (40/40 from a clean snapshot).** Shell scripting: shebang, exit codes, `[ ]` tests, `if`/`case`, arguments, `for`, `while read`, `$(...)`, arithmetic. Design decisions worth keeping:
  - The checker **runs the learner's scripts** against fixtures it builds itself, and compares stdout and exit status. It never greps the script for a particular command, and it never reuses the lab's sample paths, so hardcoding the lab output fails.
  - Scripts live in `/srv/r4/bin`, run by absolute path. `/usr/local/bin` is mentioned as the alternative that is in `PATH`, but the module does not install anything outside `/srv`, so `restore clean` removes all of R4.
  - Lab 1 (`classify`) is deliberately built around test **order**: `-L` before `-e` is the only way a broken symlink is reported as a link. The checker includes a broken link and a filename with a space, which catch the two most common bash bugs.
  - Lab 2 (`linereport`) uses `wc -l < "$f"` so the captured value is a number and nothing else, and confirms that an empty file counts as `0` while a subdirectory and a broken link are skipped.
  - The challenge (`accounts`) reads a passwd-format **file given as an argument** rather than `/etc/passwd`, so the result does not depend on the machine's accounts. It forces `IFS=: read` plus `done < file`; a learner who pipes into `while` loses the counters and the summary line fails.
  - Every expected-output block in the labs was captured on the VM, including `ls -l` sizes and the `[: too many arguments` message. The sample outputs in the challenge use `/srv/r4/homes/*`, so the counts are reproducible.
- **R5 — done and validated 2026-11-10 (27/27 from a clean snapshot).** Processes, systemd units, drop-ins, `enable`/`mask`, journald persistence and size caps, `tuned`. Design decisions worth keeping:
  - The module teaches the SELinux consequence first. Lab 1 points `ExecStart` at `/srv/r5/bin/worker`, gets `status=203/EXEC` with "Permission denied", then shows `ls -Z` (`var_t` versus `bin_t`) and installs the program into `/usr/local/bin`. This is the most useful five minutes in the module, because the error looks like a missing file.
  - `mask` is taught as a sequence, not a verb. Lab 1 starts a unit, stops it, deletes the file, runs `daemon-reload`, and only then masks. `systemctl mask` refuses while a real unit file exists, and a learner who meets that error mid-exam loses time.
  - Nice is checked twice. `systemctl show -p Nice` reads configuration; `ps -o ni=` reads the process. The lab makes the two disagree by adding the drop-in without restarting, which is the mistake the check exists to catch.
  - Lab 2 makes the journal persistent with `mkdir -p /var/log/journal`, a journald restart, **and** `journalctl --flush`. The restart alone leaves the machine-ID directory empty, so the checker's `find` fails for a reason that is invisible in the UI.
  - Two Lab 2 checks deliberately fail before the reboot: they look for a `r5-journal` entry whose `_BOOT_ID` differs from the current boot. That encodes the persistence test instead of trusting a flag.
  - The size cap is a drop-in, read back with `systemd-analyze cat-config`. The lab also shows `journalctl --rotate` before `--vacuum-size`, because vacuuming an active file frees nothing.
  - The challenge adds `r5-batch` (`Nice=5`, `Restart=always`) without undoing Labs 1 and 2, so `check r05 all` is a valid three-state stack. Its checker kills the main PID and waits for a different one, which is the only honest test of `Restart=always`.
  - Expected-output blocks are VM captures. PIDs and timestamps differ on every walk; the docs say so once, in Lab 1.
- **R6 — done and validated 2026-11-10 (36/36 from a clean snapshot).** GPT partitions, LVM physical volumes/volume groups/logical volumes, XFS and ext4, swap, and UUID/LABEL mounts. Design decisions worth keeping:
  - The module installs `lvm2` first. The base image has `parted` and `blkid` but not the LVM userland, so a learner who skips the install meets `pvcreate: command not found` at the first LVM step.
  - Lab 1 builds a 5 GiB GPT partition marked Linux LVM, a PV, `r6vg`, a 2 GiB XFS LV, and an fstab entry by UUID. Lab 2 adds a 512 MiB swap LV (UUID) and a 512 MiB ext4 LV mounted by `LABEL=r6label`. The challenge adds a second ~5 GiB partition, extends the VG, grows `r6data` by 2 GiB, and runs `xfs_growfs` while it is mounted.
  - The three states stack, so `check r06 all` is valid: Lab 2 leaves Lab 1's mount alone, and the challenge leaves both alone. The checker asserts those regressions explicitly.
  - The partition type is verified by the GPT type GUID from `sfdisk -d`, because `lsblk -o PARTFLAGS` and `PARTTYPE` are empty on this image even when `parted` shows the `lvm` flag.
  - Sizes are ranges: `blockdev --getsize64` for partitions, `lvs --units b` for LVs, `findmnt -b -o SIZE` for filesystems. A 5 GiB partition is 5368709120 bytes in the table but `parted` prints `5369MB`, and XFS reports slightly less than 4 GiB after `xfs_growfs`.
  - Every fstab edit is followed by `systemctl daemon-reload`, `mount -a` (or `swapon -a`), and `findmnt --verify`. The lab calls out the daemon-reload warning by name, because skipping it produces a configuration that works now and fails later.
  - `lvextend` and `xfs_growfs` are separate steps in the labs; `lvextend -r` is mentioned in the theory as the one-command alternative. The challenge checks both `lvs` and the mounted filesystem size, because growing only the LV is the common mistake.
  - The walk started from `clean`, ran Lab 1, Lab 2, and the challenge on one machine, rebooted, and then ran `./bin/lab check r06 all`: 36/36. The marker file written before the resize was still readable after the reboot, which is the non-destructive part of the objective.
- **R7 — done and validated 2026-11-10 (42/42 from a clean snapshot).** VFAT with mount-supplied ownership, an NFS export with the firewall opened correctly, autofs on the client, ext4 online growth, and an offline `e2fsck`. Design decisions worth keeping:
  - The module is the first two-machine one. Lab 2 needs `server` and `node2` at the same time, and the checker proves it by reaching `node2` over SSH as `labuser`. Everything in `lab2` and `challenge` fails if the lab kit was not provisioned normally, so the docs say "both VMs must be running" once, in the lab.
  - Lab 1 is built around what VFAT **cannot** do. A `chmod` that succeeds and changes nothing, an `ln -s` that is refused, and a case-insensitive filename are three checks that cannot pass on a stand-in ext4 mount, so the checker's behavioural checks prove the filesystem type as well as the options.
  - The NFS lab teaches `root_squash` by making it hurt: root's write fails with `Permission denied`, and the fix is to write as `labuser`, not to add `no_root_squash`. The export directory is `labuser`-owned and mode `755`, which is the other half of the permission story.
  - The firewall lesson is the failure mode, not the port number. Opening `nfs` alone leaves `mountd` and `rpc-bind` blocked, and the client's error is `access denied by server`, which reads like an exports problem.
  - The challenge grows ext4 online with `lvextend` + `resize2fs`, because `parted resizepart` refuses a mounted partition. `resize2fs` takes the device and `xfs_growfs` takes the mount point; the cheat sheet puts them side by side and the quiz asks which is which.
  - `e2fsck -f` on a non-terminal exits 8 with `need terminal for interactive repairs` even on a clean filesystem. The docs explain it and give `-fy` for scripts so a learner does not read a healthy filesystem as broken.
  - The walk started from `clean`, ran Lab 1 and the challenge on `server` and Lab 2 across both machines, rebooted **both**, and then ran `./bin/lab check r07 all`: 42/42. The 100 MB `blob.bin` checksum was unchanged after the online grow and the offline check.
- **R8 — done and validated 2026-11-10 (43/43 from a clean snapshot).** cron, `at`, systemd timers, chrony server/client, and the timezone. Design decisions worth keeping:
  - The checker is behavioural throughout. It reads the log a cron job wrote, the stamp a timer appended, the report a service produced, and the tarball the archive script made. A learner who writes perfect configuration and never lets it run fails, which is the correct outcome for a scheduling module.
  - Lab 1 begins with the clock. A restored snapshot came back about 14 hours behind, so Step 0 restarts `chronyd` and runs `chronyc waitsync 30 0.1` before anything is scheduled. The theory says why: a wrong clock makes every later diagnosis misleading.
  - The user cron job writes into `/srv/r8/home`, which the lab creates with `install -d -o labuser -g labuser`. The first clean walk failed exactly there, and that failure — a root-owned output directory with the error going to mail — is the most common cron bug in production. It is now the documented lesson rather than a hidden setup step.
  - Lab 2 teaches `Persistent=true`, `OnCalendar` syntax, and `systemd-analyze calendar`. It also shows the two ways to get persistence wrong: enabling the service instead of the timer, and omitting `Type=oneshot`.
  - The chrony half is a two-machine hierarchy: `server` follows the internet, `allow 10.10.10.0/24`, firewalld `ntp`, and `node2` replaces its pool with `server 10.10.10.10 iburst`. That is the shape of every internal time service, and it makes `^*` and `Reference ID` mean something.
  - The challenge splits the work on purpose: hourly report on a timer because it must catch up after downtime, weekly archive on a cron line because the slot is fixed. The comparison table in the theory is then not abstract.
  - Report filenames carry `$$`, so four runs in two seconds produce four files and pruning can be tested. Without the PID the check would pass vacuously.
  - `check_n2_sync` polls for up to 60 s instead of sleeping a fixed time, because a freshly booted `node2` takes a few seconds to report `NTPSynchronized=yes`.
  - The walk started from `clean`, ran Lab 1, Lab 2 on both machines, and the challenge, rebooted **both**, and ran `./bin/lab check r08 all`: 43/43. A cron line that was correct failed the first checker run because `val_is` strips whitespace; `line_is` now compares multi-field lines verbatim.

### M3 — R9–R11

- **R9 — done and validated 2026-11-11 (35/35 from a clean snapshot).** NetworkManager connections, static IPv4 and IPv6, name resolution, and firewalld. Design decisions worth keeping:
  - The lab network is a **dummy interface** (`lab0`), not `eth1`. The commands are identical to a real NIC, and a mistake cannot end the SSH session the learner is working through.
  - Addresses come from the documentation ranges (`192.0.2.0/24`, `2001:db8::/32`), so the checker can assert them exactly and nothing real can collide.
  - Lab 1 builds the profile with `connection add`, then proves `modify` alone changes nothing until `connection up`. It sets `never-default` on both families so the dummy never competes for the default route, and adds the `r9peer` line to `/etc/hosts` so resolution is proved through `files`, the first source in `nsswitch.conf`.
  - Lab 2 makes zone selection the lesson: `8080` is opened in `r9web`, and `node2` still fails, because it arrives on `eth1` in `public`. The fix is a rule in the zone the traffic actually enters, and the failure output is recorded in the lab.
  - The runtime/permanent split is taught by opening `9090` at runtime, watching the permanent list stay empty, and watching `9090` disappear on `--reload` while `8080` appears.
  - Every phase ends with a behavioural check: the checker starts its own HTTP listener and fetches it from `node2` as `labuser`. It also asserts the `ssh` path still works, because a firewall edit that removes `ssh` is the module's main failure mode.
  - The challenge adds a fully qualified hostname, a second hosts-file name (`r9api`), and a second permanent port (`8443`), without undoing either lab. `getent hosts <own-fqdn>` answers through `myhostname` with IPv6 and link-local addresses; the docs and the checker use `getent ahostsv4` where a service address is what matters.
  - The walk started from `clean`, ran the three phases in order, rebooted **both** machines, and ran `./bin/lab check r09 all`: 35/35. Two checker bugs surfaced and were fixed: `conn_v6` strips `nmcli`'s escaped colons, and `hosts_has_ip` matches the address field rather than searching for the name anywhere in the line.

- **R10 — done and validated 2026-11-11 (42/42 from a clean snapshot).** SELinux modes, labels, port labels, Booleans, and AVC reading; SSH keys, `authorized_keys` permissions, drop-in ordering, and proving the password path is gone; a source-restricted firewalld rich rule. Design decisions worth keeping:
  - The module walks into three failures in order and fixes each at the layer that refused it: `name_bind` on `18443`, `getattr` on `/srv/r10/www`, `name_connect` to `18081`. That sequence is the whole lesson — a hardened host has several independent "no"s, and fixing the most recent one is not the same as fixing the host.
  - Lab 1 uses `18443` because RHEL 10 already labels `8443` as `http_port_t`; there would be no port denial to teach. It uses `/srv/r10/www` because `/srv` is `var_t`, so the file denial needs no setup.
  - `chcon` is applied on purpose, the page works, then `restorecon` breaks it again before the `semanage fcontext` mapping is written. The wrong turn is the lesson.
  - The Boolean is proved with a local proxy to `127.0.0.1:18081`, which produces a `503` and a `name_connect` denial, then a `200` after `setsebool -P`. A static page would never touch the Boolean at all.
  - Lab 2 hardens `server`, not `node2`, so `sshd -T` can be read locally. The drop-in is `10-r10.conf` because `50-cloud-init.conf` sets `PasswordAuthentication yes` and first value wins; the lab renames it to `60` to show the setting silently reverting, then back.
  - The checker proves SSH with `sshd -T` **and** three real connections (deploy key, forced password, lab key), and starts its own proxy fixture so the Boolean is tested after the hand-started backend is long gone.
  - The challenge adds a source-restricted rich rule in `public` and fetches the page from `node2`, without undoing either lab. `--query-port=18443/tcp` correctly answers `no`; the docs and cheat sheet call that out, because it reads as broken to anyone used to `--add-port`.
  - The walk started from `clean`, ran the three phases in order, rebooted **both** machines, and ran `./bin/lab check r10 all`: 42/42. One checker bug was fixed: `semanage port -l -C` prints `type proto port`, so `port_label` reads fields 2 and 3.

- **R11 — done and validated 2026-11-11 (31/31 from a clean snapshot).** Boot chain, targets, GRUB 2 and BLS, temporary and persistent kernel arguments, `rd.break` root recovery with `/.autorelabel`, `init=/bin/bash`, rescue mode, and `dnf` update/history. Design decisions worth keeping:
  - **The module ends on `multi-user.target`.** Lab 1 sets `graphical.target`, reboots to prove `set-default` survives, then sets `multi-user.target` back. The challenge requires the headless default as a regression, and `all` passes because lab1, lab2, and the challenge all agree on the end state. A lab that ended graphical would make `all` impossible.
  - **The serial console is part of the lab kit.** GRUB, the initramfs, and `sulogin` cannot be reached over SSH. `common.sh` now sets `console=tty0 console=ttyS0,115200n8`, `GRUB_TERMINAL_INPUT/OUTPUT`, `GRUB_SERIAL_COMMAND`, `GRUB_TIMEOUT=5`, `menu_auto_hide=0`, and enables `serial-getty@ttyS0`; `./bin/lab console [server|node2]` wraps `virsh console`. The console was validated end to end (menu, `e`, Ctrl-X, login) during the R11 walk.
  - **`grubby` is the tool for kernel arguments, not `grub2-mkconfig`.** The lab reads all three layers: `/etc/default/grub`, `grub.cfg`, and the BLS entries. `grubby --update-kernel=ALL --args=panic=10` updates every entry plus `/etc/default/grub` and `/etc/kernel/cmdline`; `grub2-mkconfig` would leave the BLS entries alone. The checker asserts all three and then `/proc/cmdline`, so a setting that reaches only one layer fails.
  - **The challenge argument is `panic_on_warn=1`.** `panic_on_oops` is already 1 on this image, `loglevel=7` is already the printk default, and `nmi_watchdog` is already 0. `panic_on_warn` starts at 0, is visible at `/proc/sys/kernel/panic_on_warn`, and pairs with `panic=10` to describe a server that reboots itself.
  - **Recovery is proved without a password.** `passwd -S root` must say `P*` with a date that is not `never`, `/root/r11-recovered` must be root-owned, `/etc/shadow` must be `shadow_t`, the marker must be `admin_home_t`, `/.autorelabel` must be gone, and SELinux must still be `Enforcing`. The password the learner chose is never stored or asserted.
  - **The read-only root is the lesson.** `rd.break` lands with `/sysroot` read-only; skipping `mount -o remount,rw /sysroot` produces `Authentication token manipulation error`, which reads like a password bug. The lab walks into it, and the `?` in `ls -Z` explains why `/.autorelabel` is the second half of the repair.
  - **The update check is two-sided.** A successful `upgrade`/`update` transaction in `dnf history` plus `dnf check-update` exiting 0 plus `uname -r` equal to the newest `kernel-core`. That last one forces the reboot and proves the new kernel is actually running.
  - **`grep -q` in a pipeline is a trap under `pipefail`.** `cmdline_has`, `label_is`, and `upgrade_ok` all closed the pipe early and turned SIGPIPE into a false failure. They now use `grep ... >/dev/null` and read the whole input.
  - The walk started from `clean`, ran Lab 1 (including the graphical round-trip and the GRUB-editor override), Lab 2 (lock, `rd.break`, relabel, root console login, second reboot), and the challenge (`dnf -y upgrade`, `panic_on_warn=1`, reboot), then ran `./bin/lab check r11 all`: 31/31.

- **R12 core — done and validated 2026-11-11 (`lab1` 35/35, `lab2` 42/42, `all` 77/77 after a reboot).** The capstone is a full-stack rehearsal, a diagnostic lab, a quiz, a cheat sheet, and a checker. It teaches no new command; it makes the learner do several objective groups on one machine in the order a task list would give them. Design decisions worth keeping:
  - **The module deviates from the two-labs-plus-challenge anatomy on purpose.** A capstone's third phase is the mock exams, not another task sheet, so the anatomy is Lab 1 (build), Lab 2 (diagnose and repair), and Exams A–C (timed, under exam conditions). The deviation is documented here and in the theory page.
  - **Lab 2 repairs what it breaks, so `all` is valid.** The three breakages are storage (a stale UUID in fstab), SELinux (the record plus a `chcon -t var_t`), and firewall (`--permanent --remove-port` then `--reload`). Each is repaired in the layer that owns it, which leaves the host exactly where Lab 1 left it. That is why `check r12 all` is the normal persistence test rather than a special case.
  - **The three breakages produce three different symptoms on purpose.** Storage is invisible now and fatal at boot (`findmnt --verify`); SELinux is a local `403` with an AVC; the firewall is a local `200` and a `curl: (7)` from `node2`. The diagnostic table in Lab 2 is the exam skill: group the red lines by layer before touching anything.
  - **`chcon -t var_t` is the deterministic SELinux break.** The first attempt used `semanage fcontext -d` plus `restorecon`, but `restorecon` still applied the deleted record once, so the page kept working. `chcon -t var_t` always produces the label the AVC needs, and the repair is the record plus `restorecon`, which is what the checker asserts.
  - **`stamp_fresh` polls and accepts a stamp newer than `btime`.** After a reboot the restored snapshot clock steps forward, so the previous boot's stamp can look hours old even though the timer is healthy. The predicate accepts a stamp from this boot or from the last three minutes, and waits up to 90 s for the next tick, exactly like R8's `check_n2_sync`.
  - **The checker re-runs the whole rehearsal after the repairs.** A repair that fixes three lines and breaks the account or the timer is not a repair, so `lab2` asserts the repaired layers and then runs `service_host` in full.
  - **The walk started from `clean`.** Lab 1 built the volume, account, label, service, firewall, and timer; `lab1` passed 35/35. The three breakages produced 12 failures; the repairs restored `lab2` to 42/42. A reboot of `server` then held the mount, the label, the service, the port, and the timer, and `all` passed 77/77.
  - **The mock exams are next.** They will reuse the same checker style: Phases `exama`, `examb`, and `examc`, each a task sheet plus a grading run, with `./bin/lab` accepting module-defined phase names.

### M4 — R12 mock exams and polish

- Write Mock Exams A, B, and C as task-sheet pages and add `exama|examb|examc` to the R12 checker.
- Make `labs/bin/lab` accept module-defined phase names (lowercase alphanumeric) instead of the fixed `lab1|lab2|challenge|all`.
- A two-node exam scenario that combines storage, NFS, firewall, SELinux, and services.
- PDF/print export (consider `mkdocs-print-site-plugin` or browser print).
- Review the objective matrix for gaps.
- Update README status and this file.

### Immediate handoff checklist for a new agent

1. Read this file, `README.md`, and `docs/rhcsa/index.md`.
2. Run `git status` and `git log --oneline -5`.
3. Run `mkdocs build --strict` and the shell syntax checks.
4. Read the current module's theory and checker before editing.
5. Make the change, update nav and status tables, validate, then commit.
6. If the change affects the curriculum or a decision, update this file in the same commit.

---

## 10. Known gaps and risks

- **The lab kit has been validated on one KVM host only.** The 2026-11-10 run used Fedora, Vagrant 2.3.4, vagrant-libvirt 0.11.2, and `almalinux/10` 10.2. Re-validate on other host distributions and Vagrant/plugin versions. The Vagrantfile forces the system libvirt connection and provisioning configures the private NIC with NetworkManager, which should remove the two most common failure modes.
- **A rebuilt lab changes the guest host keys.** `labs/provision/common.sh` sets `StrictHostKeyChecking accept-new` for `server` and `node2`, so a first connection succeeds, but an entry left over from a destroyed VM makes the next `ssh` fail with `REMOTE HOST IDENTIFICATION HAS CHANGED`. `docs/start-here/lab-setup.md` tells the learner to clear it with `ssh-keygen -R 10.10.10.11`; `./bin/lab ssh` is unaffected because it goes through Vagrant.
- **First boot requires internet.** Provisioning installs base packages from AlmaLinux's online repositories, and there is no offline path since `LAB_ISO` was removed on 2026-11-08. A learner behind a restrictive proxy fails at `dnf install`.
- **R3 Lab 2 pulls about 1.5 GB from Flathub.** Installing `org.gnome.Calculator` brings in `org.gnome.Platform` and its graphics extensions, and the download rate is out of anyone's control: the same host measured roughly 2 MB/s and roughly 150 KB/s on the same day. On a slow link the download takes hours. The outputs recorded in the lab came from a fast run, and the checker only looks at the remote and the end state of the store, so a slow link does not block validation — but a learner may give up before the install finishes.
- **Windows and macOS hosts are unsupported.** The lab needs KVM. The only Windows route is WSL2 with nested virtualization, documented as a non-supported note in `lab-setup.md`; macOS Apple Silicon has no tested path.
- **`SITE_URL` fallback is a placeholder.** The workflow sets it from the repository owner/name. Change the fallback if a custom domain replaces the default Pages URL.
- **Material for MkDocs reaches end of life on 2027-05-05.** Critical fixes continue until then. Zensical is the maintained successor; migration is not urgent but should be evaluated before the EOL.
- **Snapshots consume disk.** The lab docs explain cleanup, but a learner with a small disk can still run out.
- **`lab check` depends on `vagrant upload`.** Vagrant 2.0+ provides it. If an older Vagrant is used, replace the upload step with `cat | vagrant ssh`.
- **The R1 `all` checker is not the normal workflow.** Restoring the clean snapshot between labs removes Lab 1's end state. Check labs individually unless the learner did them continuously.
- **R1 node2 checks require both VMs running.** If `node2` is halted, the last two challenge checks fail even if the files on `server` are correct.
- **R5 output blocks are version-sensitive.** The `systemctl status` wording (`Deactivated successfully`, `Result: signal`), the journal priority names, and `listen` addresses come from systemd 257 on AlmaLinux 10.2. The checker does not parse that prose — it asks for fields and exit statuses — but a learner on another systemd release may see slightly different status text than the lab shows.
- **R5's challenge check restarts a service on purpose.** Running `check r05 challenge` (or `all`) kills `r5-batch`'s main PID. That is the test, and it leaves a `Scheduled restart job, restart counter is at 1` line in the journal, which is normal.
- **R5's Lab 2 checks need a reboot.** `check r05 lab2` fails two lines until the learner has rebooted after writing the marker. That is deliberate and the failure message says so; it is not a broken checker.
- **R6 needs a working repository to install `lvm2`.** The base image has `parted` but not the LVM userland. If the learner left R3's distro repositories disabled, `dnf install -y lvm2` fails before the first LVM step. The module says to re-enable them, but a learner who jumps straight from R3 to R6 can still be surprised.
- **R6's fstab lines are appended, not merged.** The labs use `printf ... >> /etc/fstab` so the command is reproducible, which means walking a lab twice leaves duplicate lines. The documented recovery is `./bin/lab restore clean` before repeating a lab; a real edit would use an editor and replace the line.
- **R6 output is size- and UUID-sensitive.** `parted` prints decimal sizes, `lsblk` prints binary, XFS reports slightly less than the LV size, and every UUID is generated. The docs say this once in Lab 1. The checker uses ranges and reads the identifiers from the machine, so a different disk or filesystem build does not produce false failures.
- **R6's challenge assumes `/dev/vdb1` ends at `5121MiB`.** That is what Lab 1 creates. A learner who chose a different end sector must start `/dev/vdb2` at the matching offset or leave a gap; the checker only requires that `vdb2` exists, is about 5 GiB, is LVM-typed, and is in the VG, so a sensible variation still passes.
- **R7's `lab2` and `challenge` checks need `node2` running and reachable.** Three checks in `lab2` and two in `challenge` run over SSH as `labuser`. If `node2` is halted, or the shared key was never installed, they fail even when `server` is configured perfectly. `./bin/lab status` is the first thing to check.
- **R7's challenge partition size is load-bearing.** `/dev/vdb2` must be about 1.5 GiB so `r7vg` has ~1 GiB free after the 512 MiB LV. A smaller partition makes `lvextend -L +512M` fail with `Insufficient free space`, and the checker will then fail the "grew to about 1 GiB" checks. Recover with `./bin/lab restore clean`, not by guessing sizes.
- **R7's ext4 challenge uses LVM, not partition resize.** `parted -s /dev/vdb resizepart` refuses while the partition is mounted, so the online-growth lesson is built on `lvextend` + `resize2fs`. A learner who tries the partition route mid-lab meets `Partition /dev/vdb2 is being used`; that is why the challenge specifies LVM.
- **R7 Lab 2 needs `autofs` from a repository.** It is not in the base image and not in `PACKAGES`, so the lab installs it. A learner who left R3's distro repositories disabled must re-enable them first, exactly as with R6's `lvm2`.
- **R7 output is protocol- and UUID-sensitive.** `exportfs -v` prints defaults (`root_squash`, `secure`, `wdelay`) that the learner did not type, `findmnt` prints `uid=` as a number, and the VFAT UUID is short (`FBF7-223A`). The docs say this once; the checker reads identifiers from the machine, so a different walk does not produce false failures.
- **R7's VFAT UUID format is not interchangeable with XFS/ext4 UUIDs.** A `UUID=` line copied from an ext4 lab will never match a VFAT volume, and `LABEL=` is capped at 11 characters.
- **R8's `lab2` and `challenge` checks need `node2` running and reachable.** Four checks read `chronyc sources` and `NTPSynchronized` over SSH as `labuser`. If `node2` is halted, or the shared key was never installed, they fail even when `server` is perfect. `./bin/lab check r08 lab1` is the single-machine subset.
- **R8 Lab 1 makes the learner wait a full minute.** Cron has one-minute granularity and the lab proves the job by its log, so the walk cannot be finished faster than the minute boundary. That is the lesson, not a defect; the docs say so in Step 5.
- **R8's `at` package needs a working repository.** `at` is not in the base image and not in `PACKAGES`, so Lab 1 installs it. A learner who left R3's distro repositories disabled must re-enable them first, exactly as with R6's `lvm2` and R7's `autofs`.
- **R8's snapshot clock is stale by design.** The clean snapshot restores the clock it was saved with, which on this host was about 14 hours behind. `chronyc waitsync` corrects it in seconds, but a learner who skips Step 0 will see timestamps that look wrong and a `at` job that appears not to have run.
- **R8 output is clock- and host-sensitive.** Timestamps, timer `NEXT`/`LEFT` columns, stratum numbers, and NTP addresses all differ on every walk and every network. The docs say this once in Lab 1 and Lab 2; the checker reads *which* source is selected and *whether* the clock is synchronised, not the numbers.
- **R9's `lab2` and `challenge` checks need `node2` running and reachable.** Every port proof is an HTTP fetch from `node2` as `labuser`, so a halted `node2`, or a missing shared key, fails a correct firewall. `./bin/lab check r09 lab1` is the single-machine subset.
- **R9 cannot exercise the `r9web` zone with a client.** `lab0` is a dummy interface on `192.0.2.0/24`; no peer exists on that subnet, so nothing can connect through it. The checker verifies the `r9web` rules by querying the permanent configuration, and proves the `public` rules behaviourally from `node2`. That split is honest — the zone is still real and still applies — but the docs say it once so a learner does not read the configuration checks as fake.
- **R9's web listener is temporary.** `python3 -m http.server` is started by hand in the labs and dies at reboot, so after the persistence test the ports are open but nothing is listening. The checker starts its own listener, so this is not a failure; the labs state the distinction.
- **R9's `192.0.2.53` nameserver never answers.** It is a documentation address. `getent` and `curl` by name will stall if a name is not in `/etc/hosts`, because the resolver waits for a reply that never comes. Every name in the module is static for that reason, and the theory says why.
- **R9's `firewall-cmd --get-active-zones` formatting is version-sensitive.** firewalld 2.4.3 prints a zone with an interface but no `(active)` marker, while `--list-all` prints `(active)` for the same zone. The checker asks `--query-*` and `--list-interfaces` rather than parsing that prose, but a learner on another firewalld release may see slightly different text.
- **R9's firewalld output includes `ingress-priority` and `egress-priority`.** Those fields come from firewalld 2.4.3 — older releases omit them, and a learner comparing their output line by line will see a difference that is not a mistake.
- **R9's dummy interface reports `UNKNOWN` operational state.** It has no carrier to report. `ip addr`, routing, and traffic all work; the lab notes it once.
- **R10's Lab 1 installs `httpd` and `policycoreutils-python-utils` from a repository.** Neither is in the base image or in `PACKAGES`, so a learner who left R3's distro repositories disabled meets `Unable to find a match` before the first SELinux step. The module says to re-enable them, but the failure is the same one R6, R7, and R8 can produce.
- **R10's Lab 1 backend is a hand-started `python3 -m http.server`.** It dies at the reboot, so `curl /api/` returns `503` afterwards even though the Boolean is correct. The lab states that this is expected and the checker starts its own backend; a learner who reads the `503` as a broken Boolean will chase a ghost.
- **R10's `18443` is a free port, not a reserved one.** `semanage port -a` succeeds because nothing else claims it. Another package could label it in a future image; if that happens, `-a` fails with `Port 18443 already defined` and the lab must pick a new number.
- **R10's SSH hardening locks out password login on `server`.** That is the objective, but a learner who removes `labuser`'s key from `authorized_keys` in the same session has no way back except the console. `./bin/lab ssh` uses Vagrant's own credentials and is the documented escape hatch, and the checker asserts the lab key still works for exactly this reason.
- **R10 depends on `/etc/ssh/sshd_config.d/` being read at all.** The `Include` line is in the shipped `sshd_config` on this image. On a system where it has been removed, a drop-in does nothing, and `sshd -T` is the only way to notice.
- **R10's `sshd -T` needs root.** `labuser` on `node2` cannot read `/etc/ssh/sshd_config`, so the checker runs on `server` as root. Do not move the hardening to `node2` without reworking the checker to use `sudo`.
- **R10's rich rule cannot be tested from outside its source range.** Every machine in the lab is in `10.10.10.0/24`, so the checker proves the restriction by asking firewalld (`--query-port` must be `no`, the permanent rich rule must name the source) and proves reachability from `node2`. It cannot prove that a host outside the range is refused, because there is no such host.
- **R10 output is label- and version-sensitive.** `restorecon -Rv` prints one line per relabelled path, `semanage` column widths change between policy releases, and the `PermitRootLogin` default prints as `without-password` here (`prohibit-password` elsewhere; they are the same setting). The docs say so where it matters, and the checker reads fields rather than prose.
- **R11's relabel boot is slow and must not be interrupted.** After `rd.break` and `touch /.autorelabel`, the next boot rewrites every SELinux label and reboots itself. On this host it finished in well under a minute, but a busy or slow disk can take several minutes. A learner who power-cycles during the relabel ends up with half-labelled files and a login that rejects every password; the recovery is another `rd.break` and another `/.autorelabel`.
- **R11's serial console needs a real TTY.** `virsh console` is interactive and `./bin/lab console` is meant for a terminal window. In a script, attach through `tmux new-session -d` (as the maintainer validation does) or use `virsh console` under `script`; reading `/dev/pts/N` directly needs root. The construct is not part of the learner workflow, which is why it is not shipped in `bin/lab`.
- **R11's cold first boot can exceed Vagrant's default timeout.** A rebuilt lab spends minutes in `NetworkManager-wait-online` before provisioning finishes, and the 300 s default aborted `./bin/lab reset`. The Vagrantfile now sets `config.vm.boot_timeout = 600`. Keep that value unless the slow-boot cause is removed.
- **R11's update checks need a working repository and internet.** `dnf history` can show a perfect transaction on an offline machine, but `dnf check-update` will fail, and the challenge cannot be completed without downloading 65 packages. A learner who left R3's distro repositories disabled meets `There are no enabled repositories` before the first update step, exactly as in R6, R7, R8, and R10.
- **R11's GRUB line numbers and `timeout_style` output are version-sensitive.** `grub2-mkconfig` emits `set timeout_style=menu` on this image, and the line numbers move when the file grows. The checker greps for `set timeout=` and reads the number; the docs quote the line numbers from the 2026-11-11 walk, and a different image may show different ones.
- **R11's `all` check runs against the challenge end state.** `lab1`'s `/proc/cmdline` line and the challenge's live sysctl only pass after the reboot, and `all` expects Lab 1's arguments, Lab 2's recovered account, and the challenge's update at the same time. Run the phases in order; restore `clean` and use the individual checks otherwise.
- **R11 leaves `panic_on_warn=1` in the running kernel.** A kernel warning during the rest of the lab will panic the machine after ten seconds and reboot it. That is the configured policy working, not a broken VM, but it makes the machine unsuitable for unrelated long-running work until the argument is removed with `grubby --remove-args=panic_on_warn`.
- **R11's snapshot clock is stale.** A restored `clean` snapshot carries the clock it was saved with. R11 does not schedule anything, so it only affects timestamps a learner compares by eye; R8's `chronyc waitsync 30 0.1` is the fix.
- **R12's Lab 1 needs a working repository and both VMs.** It installs `lvm2`, `httpd`, and `policycoreutils-python-utils` and ends with a request from `node2`. A learner who left R3's distro repositories disabled, or halted `node2`, fails before the first storage step or at the last proof.
- **R12's `/srv` volume can show `unlabeled_t` after formatting.** A fresh XFS mounted under `/srv` has no stored label at its root until `restorecon` runs, so the lab shows it and turns it into the SELinux lesson. It is not a broken filesystem and not a reason to run `setenforce 0`.
- **R12's Lab 2 breakages are repaired by the learner, not by the lab.** If the learner stops halfway, `lab2` fails the layers they did not fix; that is the intended report. `./bin/lab restore clean` is the reset, not a partial repair.
- **R12's `all` check assumes Lab 2 was repaired.** It is a single continuous walk (Lab 1, then Lab 2, then the repairs). A learner who restored `clean` between the labs should run `lab1` and `lab2` individually.
- **R12's timer check waits up to 90 s.** On a busy host the first tick after `enable --now` can be missed, and the restored-clock problem makes a fixed window wrong. The wait is deliberate; a timeout is not a false failure.
- **R12's SELinux break depends on `/srv` being `var_t`.** `chcon -t var_t` produces the web denial because `/srv` is not a content type. A different image could ship a different default; if so, the lab's expected `ls -Z` and AVC differ, but the repair (record plus `restorecon`) is unchanged.
- **R12's mock exams do not exist yet.** The theory page lists them and describes the format; the pages and the `exama|examb|examc` checker phases are the next milestone. Do not claim the capstone is finished until they are validated.
- **The audit log needs `auditd`.** `ausearch -m AVC -ts recent` returned `<no matches>` on this host even with denials present, while `ausearch -if /var/log/audit/audit.log -m AVC` and `grep ': avc:' /var/log/audit/audit.log` both worked. The module teaches the `grep` as the reliable fallback, and the checker never parses the log at all — it asks SELinux for the current state instead.
- **The Vagrantfile's `cpu_mode` pin is host-specific.** `lv.cpu_mode = "host-passthrough"` was added because this host's libvirt rejected the generated `host-model` XML. On a host or libvirt version where `host-model` works, passthrough is still valid but makes the guest see the exact host CPU, which can matter for snapshot portability between machines. Re-test `./bin/lab reset` after changing it.

---

## 11. Useful commands

```bash
# Site
mkdocs serve
mkdocs build --strict

# Lab
cd labs
./bin/lab doctor
./bin/lab up
./bin/lab status
./bin/lab ssh
./bin/lab snapshot clean
./bin/lab restore clean
./bin/lab check r01 lab1
./bin/lab check r01 lab2
./bin/lab check r01 challenge
./bin/lab check r02 lab1
./bin/lab check r02 lab2
./bin/lab check r02 challenge
./bin/lab check r03 lab1
./bin/lab check r03 lab2
./bin/lab check r03 challenge
./bin/lab check r03 all
./bin/lab check r04 lab1
./bin/lab check r04 lab2
./bin/lab check r04 challenge
./bin/lab check r04 all
./bin/lab check r05 lab1
./bin/lab check r05 lab2
./bin/lab check r05 challenge
./bin/lab check r05 all
./bin/lab check r06 lab1
./bin/lab check r06 lab2
./bin/lab check r06 challenge
./bin/lab check r06 all
./bin/lab check r07 lab1
./bin/lab check r07 lab2
./bin/lab check r07 challenge
./bin/lab check r07 all
./bin/lab check r08 lab1
./bin/lab check r08 lab2
./bin/lab check r08 challenge
./bin/lab check r08 all
./bin/lab check r09 lab1
./bin/lab check r09 lab2
./bin/lab check r09 challenge
./bin/lab check r09 all
./bin/lab check r10 lab1
./bin/lab check r10 lab2
./bin/lab check r10 challenge
./bin/lab check r10 all
./bin/lab check r11 lab1
./bin/lab check r11 lab2
./bin/lab check r11 challenge
./bin/lab check r11 all
./bin/lab check r12 lab1
./bin/lab check r12 lab2
./bin/lab check r12 all

# Validation
for f in labs/bin/lab labs/provision/*.sh labs/checks/*/*.sh; do bash -n "$f"; done
ruby -c labs/Vagrantfile
```
