# AGENTS.md — project handoff and status

This is the maintainer-facing source of truth for the **RHCSA Field Guide**. It is written for humans and for future AI agents who need to continue the work without re-deriving the plan.

Update this file whenever a milestone lands, a decision changes, or a module is completed.

| | |
|---|---|
| **Last updated** | 2026-11-10 |
| **Current milestone** | M2 — R1–R5 validated; R6 next |
| **Next milestone** | R6 |
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
| Lab kit | **Validated 2026-11-10** | Vagrant 2.3.4 + vagrant-libvirt 0.11.2, two nodes, cross-VM SSH, reboot persistence, `visudo -c` clean on both nodes. Rebuilt from scratch and re-walked on 2026-11-10 against AlmaLinux 10.2 (box `10.2.20260914`). |
| Foundations F1–F8 | **Complete; walked 2026-11-10** | Eight modules under `docs/foundations/`; every command in F1 and F3–F8 was run on the 2026-11-10 lab. F2 was walked with the lab kit. No automated checkers, by decision. |
| R1 — Essential tools | **Validated** | Theory, 2 guided labs, challenge, quiz, cheat sheet, checker. 66/66 on 2026-11-07 and again on 2026-11-10 after a reboot. |
| R2 — Users and groups | **Validated 2026-11-10** | Theory, 2 guided labs, challenge, quiz, cheat sheet, checker (27 + 26 + 35 = 88). Walked end to end on a fresh lab, 88/88 after a reboot. |
| R3 — Software and repositories | **Validated 2026-11-10** | Theory, 2 guided labs, challenge, quiz, cheat sheet, checker (10 + 6 + 17 = 33). Walked end to end on a fresh lab, 33/33 after a reboot. |
| R4 — Shell scripting | **Validated 2026-11-10** | Theory, 2 guided labs, challenge, quiz, cheat sheet, checker (14 + 13 + 13 = 40). Checker runs the learner's scripts against its own fixtures; walked end to end on a fresh lab, 40/40 after a reboot. |
| R5 — Processes and services | **Validated 2026-11-10** | Theory, 2 guided labs, challenge, quiz, cheat sheet, checker (10 + 7 + 10 = 27). Checker reads live systemd/journald/tuned state; walked end to end on a fresh lab, 27/27 after a reboot. |
| R6–R11 | **Planned** | See the curriculum map below |
| R12 — Capstone | **Planned** | Mock exams, PDF/print polish |
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
│   ├── rhcsa/                 # module roadmap, R1–R5
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
│   │   └── r05-processes-and-services/
│   │       ├── index.md       # theory
│   │       ├── labs/          # 2 guided labs + challenge
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

All four checkers accept `LAB_ROOT` for a synthetic tree of the filesystem half:

```bash
LAB_ROOT=/tmp/opencode/r1-test bash labs/checks/r01/check.sh lab1
LAB_ROOT=/tmp/opencode/r2-test bash labs/checks/r02/check.sh lab1
LAB_ROOT=/tmp/opencode/r3-test bash labs/checks/r03/check.sh lab1
LAB_ROOT=/tmp/opencode/r4-test bash labs/checks/r04/check.sh all
```

Owner-specific and node2 SSH checks will fail outside the real lab; that is expected. The important result is that the checker runs, evaluates each criterion, and exits non-zero on failure.

R4 is the easiest to exercise this way: every R4 check reads a script under `$LAB_ROOT/r4/bin` and runs it. Create `r4/bin/{classify,linereport,accounts}` in a temporary tree, point `LAB_ROOT` at it, and the whole 40-check run works with no VM. The reference implementations used to validate the checker live in `/tmp`, not in the repository.

`LAB_ROOT` only redirects the **directory** checks under `/srv`. R2's account predicates read the live `passwd`/`shadow` databases, R3's repository predicates read the live `dnf` configuration, and every R5 check reads live systemd, journald, or `tuned` state, so they cannot be simulated that way. Test them by feeding the parsers faked command output — define shell functions named `chage` and `passwd` that print a known real-world block, then call the predicate helpers against it. That is how the `chage -l` labels, the `passwd -S` status prefixes (`P`/`L` on RHEL 10, `PS`/`LK` on older releases), and the `must be changed` string were verified. Any script that does this belongs in `/tmp`, not in the repository.

R5 has no off-VM path at all: `systemctl show`, `is-enabled`, `MainPID`, `journalctl`, and `tuned-adm` are the subject of the module, and faking all of them would test the fakes. Its checker was validated only on `server`, from the `clean` snapshot, by walking the two labs and the challenge and then rebooting. It also has a side effect: the last challenge check kills `r5-batch`'s main process to prove `Restart=always` works, so `systemctl status r5-batch` shows an extra `Scheduled restart job` line afterwards. That is normal.

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

**Lab commands:** `./bin/lab doctor|up|status|ssh|snapshot|restore|check|halt|reset|destroy`.

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
- Keep the disclaimer and licensing notices intact.
- Do not commit generated keys (`labs/keys/`) or build output (`site/`).
- Do not disable SELinux or firewalld in a lab unless the lesson is specifically about doing so.
- Do not claim a lab was validated without running it.
- The foundations are optional except F2. State that once, in `docs/start-here/how-to-use.md` and `docs/foundations/index.md`: an experienced admin may skip F1 and F3–F8, but F2 teaches the lab and snapshot workflow, which is course logistics rather than Linux knowledge. Do not add per-module "skip ahead to R1" links — they read as permission to skip the rest of the foundations.
- `PACKAGES` in `labs/provision/common.sh` is base state only: things F1 and F2 assert, or that every module needs before it starts. A module that needs a package installs it in its own lab. Do not grow `PACKAGES` for module features — it would force every existing learner to rebuild mid-course.

**Check-script conventions.** There are four reference implementations and they cover different kinds of state:

- **R1 (`labs/checks/r01/check.sh`) — filesystem state.** Use it as the model for anything under `LAB_ROOT`: files, links, modes, ownership, archives, checksums.
- **R2 (`labs/checks/r02/check.sh`) — account state.** Use it as the model for users, groups, passwords, aging, `sudo`, and anything else that lives in a system database rather than a file under `/srv`.
- **R4 (`labs/checks/r04/check.sh`) — program behaviour.** Use it when the deliverable is a script. It builds fixtures with `mktemp -d`, runs the learner's script against them, and compares stdout and exit status. Nothing in it greps the script's source for particular commands.
- **R5 (`labs/checks/r05/check.sh`) — live service state.** Use it for systemd units, the journal, and `tuned`. It asks `systemctl`, `journalctl`, and `tuned-adm` what they think, and reads the process's real nice value with `ps`; one check is behavioural (kill the main PID, wait for a new one).

All four follow these rules:

- Run as root inside `server`.
- Accept `lab1|lab2|challenge|all`.
- Use `LAB_ROOT` (default `/srv`) where the module has a file tree, so the tree checks can be tested without a VM. R5 has no tree; its state is live.
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
| R6 | GPT partitions, LVM, swap, fstab by UUID/label | 5 | Planned |
| R7 | ext4/XFS/VFAT, NFS, autofs, extend LVs | 6 | Planned |
| R8 | cron, at, systemd timers, chrony | 7 | Planned |
| R9 | nmcli, IPv4/IPv6, hostname resolution, firewalld | 8 | Planned |
| R10 | SELinux, SSH keys, firewall hardening | 10 | Planned |
| R11 | Boot targets, GRUB, rescue, rd.break, updates | 4 + 7 | Planned |
| R12 | Capstone: timed mock exams and full review | All | Planned |

Status values: **Validated** means the checker has passed from a clean snapshot on a real lab. **Complete; walked** (foundations) means every command in the page was run on the 2026-11-10 lab; foundations have no automated checkers. **Content complete; validation pending** means the full anatomy is written and syntax-checked but has not been walked end to end on a VM. **Planned** means not started. A module moves to **Validated** only after its checkers are re-run on `server`, not because the files exist.

The objective-to-module mapping lives in `docs/reference/objective-coverage.md`. Keep it in sync when a module lands.

---

## 8. Decisions and rationale

| Decision | Rationale |
|---|---|
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
| Force `qemu_use_session = false`; configure the private NIC in provisioning | vagrant-libvirt 0.11.x defaults to session mode, where `private_network` fails with "Network ... is not available". NetworkManager makes the static address reliable across Vagrant and AlmaLinux 10 versions. |

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

### M2 — R2, R3, R4, R5

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

### M3 — R6–R11

Add each module with the full anatomy. Prioritize the domains that are hardest to learn from prose: R6 (LVM), R7 (NFS/autofs), R10 (SELinux), R11 (boot recovery).

### M4 — R12 and polish

- Three timed mock exams with grading scripts.
- A two-node scenario that combines storage, NFS, firewall, SELinux, and services.
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

# Validation
for f in labs/bin/lab labs/provision/*.sh labs/checks/*/*.sh; do bash -n "$f"; done
ruby -c labs/Vagrantfile
```
