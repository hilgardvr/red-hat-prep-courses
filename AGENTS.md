# AGENTS.md — project handoff and status

This is the maintainer-facing source of truth for the **RHCSA Field Guide**. It is written for humans and for future AI agents who need to continue the work without re-deriving the plan.

Update this file whenever a milestone lands, a decision changes, or a module is completed.

| | |
|---|---|
| **Last updated** | 2026-11-08 |
| **Current milestone** | M1 complete — Foundations F1–F8 |
| **Next milestone** | M2 — R2, R3, R4 |
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
| GitHub Pages workflow | **Complete, not yet run in CI** | `.github/workflows/pages.yml` |
| Lab kit | **Complete; re-validation pending** | Vagrant 2.3.4 + vagrant-libvirt 0.11.2, two nodes, cross-VM SSH, reboot persistence, all R1 checkers passed on 2026-11-07. The 2026-11-08 box pin is syntax-checked only. |
| Foundations F1–F8 | **Complete** | Eight modules under `docs/foundations/`; style reference for future modules |
| R1 — Essential tools | **Complete** | Theory, 2 guided labs, challenge, quiz, cheat sheet, checker |
| R2–R11 | **Planned** | See the curriculum map below |
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
│   ├── rhcsa/                 # module roadmap and R1
│   │   └── r01-essential-tools/
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
│   └── README.md              # lab quick reference
└── .github/workflows/pages.yml
```

`site/`, `.venv/`, and `labs/keys/` are gitignored.

---

## 4. Build and validate

### Site

```bash
cd /home/hilgard/orca/workspaces/red-hat-certs/zoanthid
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

### R1 checker without a VM

The checker supports `LAB_ROOT` for a synthetic tree:

```bash
LAB_ROOT=/tmp/opencode/r1-test bash labs/checks/r01/check.sh lab1
LAB_ROOT=/tmp/opencode/r1-test bash labs/checks/r01/check.sh lab2
LAB_ROOT=/tmp/opencode/r1-test bash labs/checks/r01/check.sh challenge
```

Owner-specific and node2 SSH checks will fail outside the real lab; that is expected. The important result is that the checker runs, evaluates each criterion, and exits non-zero on failure.

### Real lab validation

```bash
cd labs
./bin/lab doctor
./bin/lab up
./bin/lab snapshot clean
./bin/lab check r01 lab1
```

**Validated on 2026-11-07** on a Fedora KVM host with Vagrant 2.3.4 and vagrant-libvirt 0.11.2:

- `./bin/lab up` created and provisioned both VMs.
- `10.10.10.10` / `10.10.10.11` were configured by NetworkManager and survived `vagrant reload` on both nodes.
- Cross-VM `ssh labuser@node2` and `ssh labuser@server` worked without extra flags.
- R1 lab 1 (18 checks), lab 2 (21 checks), and the challenge (27 checks) all passed. The full `./bin/lab check r01 all` passed 66/66 after rebooting `server`.

This host is one data point. Re-run the smoke test after changing the Vagrantfile, provisioning, or the box.

**Not yet re-validated:** the 2026-11-08 change that pinned the box and removed `LAB_BOX`/`LAB_ISO` edited the Vagrantfile, `common.sh`, and `bin/lab`. It is syntax-checked only. Re-run the smoke test above and confirm the R1 checkers before treating it as validated.

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
- The foundations are optional as a whole. State that once, in `docs/start-here/how-to-use.md` and `docs/foundations/index.md`. Do not add per-module "skip ahead to R1" links — they read as permission to skip the rest of the foundations.

**Check-script conventions (R1 is the reference implementation):**

- Run as root inside `server`.
- Accept `lab1|lab2|challenge|all`.
- Use `LAB_ROOT` (default `/srv`) so the checker can be tested without a VM.
- Print `PASS`/`FAIL` per criterion and exit non-zero if any fail.
- Inspect end state with `stat`, `grep`, `tar`, `sha256sum`, etc.
- Include node2 checks where the lab involves the second machine.

---

## 7. Curriculum map

### Foundations (M1 — complete)

| Module | Topic | Status |
|---|---|---|
| F1 | Linux, open source, and the RHEL family | **Complete** |
| F2 | The lab: virtualization and first login | **Complete** |
| F3 | Shell, commands, and the help system | **Complete** |
| F4 | Filesystem hierarchy and file operations | **Complete** |
| F5 | Streams, redirection, pipes, grep, regex | **Complete** |
| F6 | Users, permissions, ownership | **Complete** |
| F7 | Processes, systemd, logs | **Complete** |
| F8 | Networking and storage foundations; SELinux intro | **Complete** |

Foundations modules are lighter than RHCSA modules: explanation, diagram/table, small commands, and a self-check. They do not need automated checkers.

### RHCSA modules

| Module | Focus | Objective group | Status |
|---|---|---|---|
| R1 | Essential tools | 1 | **Complete** |
| R2 | Users, groups, password aging, sudo, default permissions | 9 + part of 10 | Planned |
| R3 | Software: DNF, RPM repos, Flatpak | 2 | Planned |
| R4 | Shell scripting | 3 | Planned |
| R5 | Processes, systemd services, journald, tuned | 4 | Planned |
| R6 | GPT partitions, LVM, swap, fstab by UUID/label | 5 | Planned |
| R7 | ext4/XFS/VFAT, NFS, autofs, extend LVs | 6 | Planned |
| R8 | cron, at, systemd timers, chrony | 7 | Planned |
| R9 | nmcli, IPv4/IPv6, hostname resolution, firewalld | 8 | Planned |
| R10 | SELinux, SSH keys, firewall hardening | 10 | Planned |
| R11 | Boot targets, GRUB, rescue, rd.break, updates | 4 + 7 | Planned |
| R12 | Capstone: timed mock exams and full review | All | Planned |

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
| Remove `LAB_BOX` and `LAB_ISO` (2026-11-08) | Two advanced overrides documented in three beginner-facing places; no shipped module used them. Lab is pinned to AlmaLinux 10. The offline-repo teaching need moves to R3, which will use a local RPM directory as a `baseurl`. |
| Shared lab SSH key | Makes cross-VM `ssh`/`scp` work for beginners without teaching key setup before R10 |
| `labuser` account | Gives a non-root account for permission and sudo exercises |
| Free core + paid extras | Keeps the course useful and marketable without paywalling exam preparation |
| CC BY-NC-SA content + MIT code | Allows sharing/adaptation, prevents commercial reuse of the course text |
| R1 checker with `LAB_ROOT` | Allows local testing without a VM and keeps checks deterministic |
| `all` checker assumes every lab end state | Individual checks are recommended when the learner restores snapshots between labs |
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

### M2 — R2, R3, R4

- **R2:** users, groups, password aging, sudoers, default permissions. Checker must verify users/groups/password aging/sudo.
- **R3:** DNF repositories, RPM install/remove, Flatpak remotes and packages. Teach repository configuration with a local directory of RPMs used as a `baseurl` (not an installation DVD — `LAB_ISO` was removed). For the exam's no-internet condition, disconnect the VM's network in a lab step instead of attaching media.
- **R4:** conditionals, loops, arguments, command substitution. Checker runs the learner's script against test inputs.

### M3 — R5–R11

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

- **Foundations F3–F8 labs are written but not yet walked on a live lab.** F1–F2 were validated together with R1 on 2026-11-07. The newer modules use only commands and packages the provisioning installs (`man-db`, `man-pages`, `vim-enhanced`, `bash-completion`, `tar`, `openssh-clients`), plus iproute, util-linux, policycoreutils, and their dependencies, but a full read-through on `server` and `node2` is still owed before calling them validated.
- **The lab kit has been validated on one KVM host only.** The 2026-11-07 run used Fedora, Vagrant 2.3.4, vagrant-libvirt 0.11.2, and `almalinux/10`. Re-validate on other host distributions and Vagrant/plugin versions. The Vagrantfile forces the system libvirt connection and provisioning configures the private NIC with NetworkManager, which should remove the two most common failure modes.
- **First boot requires internet.** Provisioning installs base packages from AlmaLinux's online repositories, and there is no offline path since `LAB_ISO` was removed on 2026-11-08. A learner behind a restrictive proxy fails at `dnf install`.
- **Windows and macOS hosts are unsupported.** The lab needs KVM. The only Windows route is WSL2 with nested virtualization, documented as a non-supported note in `lab-setup.md`; macOS Apple Silicon has no tested path.
- **CI has not run yet.** The Pages workflow is written but unexecuted. The first push to `main` will reveal environment-specific issues.
- **`SITE_URL` fallback is a placeholder.** The workflow sets it from the repository owner/name. Change the fallback for a custom domain.
- **Material for MkDocs reaches end of life on 2027-05-05.** Critical fixes continue until then. Zensical is the maintained successor; migration is not urgent but should be evaluated before the EOL.
- **Snapshots consume disk.** The lab docs explain cleanup, but a learner with a small disk can still run out.
- **`lab check` depends on `vagrant upload`.** Vagrant 2.0+ provides it. If an older Vagrant is used, replace the upload step with `cat | vagrant ssh`.
- **The R1 `all` checker is not the normal workflow.** Restoring the clean snapshot between labs removes Lab 1's end state. Check labs individually unless the learner did them continuously.
- **R1 node2 checks require both VMs running.** If `node2` is halted, the last two challenge checks fail even if the files on `server` are correct.

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

# Validation
for f in labs/bin/lab labs/provision/*.sh labs/checks/*/*.sh; do bash -n "$f"; done
ruby -c labs/Vagrantfile
```
