# AGENTS.md — project handoff and status

This is the maintainer-facing source of truth for the **RHCSA Field Guide**. It is written for humans and for future AI agents who need to continue the work without re-deriving the plan.

Update this file whenever a milestone lands, a decision changes, or a module is completed.

| | |
|---|---|
| **Last updated** | 2026-11-07 |
| **Current milestone** | M0 complete — site scaffold, lab kit, and R1 |
| **Next milestone** | M1 — Foundations F1–F8 |
| **Active branch** | `hilgard/rhcsa-prep-course` |
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
| Lab kit | **Complete, not yet run on real VMs** | Vagrant + libvirt, two nodes, checker wrapper |
| Foundations F1–F8 | **Planned** | Only `docs/foundations/index.md` exists |
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
│   ├── foundations/           # F1–F8 (index only so far)
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
│   ├── provision/             # common.sh, repo.sh, node2.sh
│   ├── checks/r01/check.sh    # R1 automated checker
│   ├── box/README.md          # RHEL 10 box notes
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

**This has not been executed in the development sandbox.** The sandbox has no Vagrant, no RHEL 10 box, and no usable nested virtualization. The first real `./bin/lab up` on the user's host is the validation gate.

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

**Default box:** `almalinux/10`. It is freely available and RHEL 10-compatible for the course objectives. There is currently no public generic RHEL 10 box on Vagrant Cloud.

**RHEL 10 fidelity:** set `LAB_BOX=your-org/rhel10`. See `labs/box/README.md` for box requirements and the build outline.

**Offline exam-like repo:** `LAB_ISO=/path/to/rhel-10-x86_64-dvd.iso ./bin/lab up`. Provisioning mounts the ISO on both nodes and configures `BaseOS` + `AppStream` as `file://` repositories. Existing repos are disabled in ISO mode so an unregistered box does not fail on stale online repos.

**Cross-VM SSH:** `bin/lab up` generates `labs/keys/lab_ed25519`, uploads it to both nodes, installs it for `vagrant` and `labuser`, and writes `~/.ssh/config` entries for `server` and `node2`. `ssh labuser@node2` and `scp` work without extra flags.

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

**Check-script conventions (R1 is the reference implementation):**

- Run as root inside `server`.
- Accept `lab1|lab2|challenge|all`.
- Use `LAB_ROOT` (default `/srv`) so the checker can be tested without a VM.
- Print `PASS`/`FAIL` per criterion and exit non-zero if any fail.
- Inspect end state with `stat`, `grep`, `tar`, `sha256sum`, etc.
- Include node2 checks where the lab involves the second machine.

---

## 7. Curriculum map

### Foundations (M1 — next)

| Module | Topic | Status |
|---|---|---|
| F1 | Linux, open source, and the RHEL family | Planned |
| F2 | The lab: virtualization and first login | Planned |
| F3 | Shell, commands, and the help system | Planned |
| F4 | Filesystem hierarchy and file operations | Planned |
| F5 | Streams, redirection, pipes, grep, regex | Planned |
| F6 | Users, permissions, ownership | Planned |
| F7 | Processes, systemd, logs | Planned |
| F8 | Networking and storage foundations; SELinux intro | Planned |

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
| AlmaLinux 10 as default lab box | No public generic RHEL 10 Vagrant box; AlmaLinux is RHEL-compatible and subscription-free |
| Two VMs (`server`, `node2`) | Needed for SSH, NFS, firewall, and client/server exercises |
| Offline DVD repo via `LAB_ISO` | Mimics the exam's no-internet environment and avoids subscription dependency |
| Shared lab SSH key | Makes cross-VM `ssh`/`scp` work for beginners without teaching key setup before R10 |
| `labuser` account | Gives a non-root account for permission and sudo exercises |
| Free core + paid extras | Keeps the course useful and marketable without paywalling exam preparation |
| CC BY-NC-SA content + MIT code | Allows sharing/adaptation, prevents commercial reuse of the course text |
| R1 checker with `LAB_ROOT` | Allows local testing without a VM and keeps checks deterministic |
| `all` checker assumes every lab end state | Individual checks are recommended when the learner restores snapshots between labs |

---

## 9. Next steps (in order)

### M1 — Foundations F1–F8

For each foundation:

1. Create `docs/foundations/fN-topic/index.md`.
2. Add it to the `Foundations` nav section in `mkdocs.yml`.
3. Include a small lab or command walkthrough and a self-check.
4. Link it from `docs/foundations/index.md`.
5. Run `mkdocs build --strict`.

### M2 — R2, R3, R4

- **R2:** users, groups, password aging, sudoers, default permissions. Checker must verify users/groups/password aging/sudo.
- **R3:** DNF repositories, RPM install/remove, Flatpak remotes and packages. Include the offline repo workflow.
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

- **The lab kit has not been run on real VMs in the development sandbox.** Validate `./bin/lab up`, provisioning, cross-VM SSH, and all three R1 checkers on a KVM host before calling the lab stable.
- **No public generic RHEL 10 Vagrant box.** AlmaLinux 10 is the default. A RHEL 10 box must be built or supplied by the user.
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

# RHEL 10 box override
LAB_BOX=your-org/rhel10 ./bin/lab up

# Offline repo
LAB_ISO=/path/to/rhel-10-x86_64-dvd.iso ./bin/lab up

# Validation
for f in labs/bin/lab labs/provision/*.sh labs/checks/*/*.sh; do bash -n "$f"; done
ruby -c labs/Vagrantfile
```
