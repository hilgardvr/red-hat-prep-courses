# Mock exam A — The web host

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R12 — Capstone |
| **Time** | 2 hours |
| **Check** | `./bin/lab check r12 exama` |
| **Style** | Timed exam: requirements only, no steps |

</div>

!!! warning "Stop before you read on"
    This is an exam, not a lab. Restore the clean snapshot, put your notes away, start a clock, and attempt every task before you run the checker or look at any guide. The grade only teaches you something if the attempt was honest.

    ```bash
    cd labs
    ./bin/lab restore clean
    ./bin/lab up
    ```

## Scenario

`server` is a new intranet host. It needs a small web portal, a deploy account, a labelled document root, and a minute-by-minute health stamp. Build it, then prove it survives a reboot.

Both VMs must be running: the last requirement is a request from `node2`.

## Requirements

### 1. Storage

On `server`, use the empty disk `/dev/vdb`:

- one GPT partition spanning the disk, marked as **Linux LVM**;
- volume group `exama_vg`;
- logical volume `examadata`, **1500 MiB**, **XFS**;
- mounted at `/srv/exama/data`;
- mounted by **UUID** in `/etc/fstab`;
- the whole `fstab` must pass `findmnt --verify`.

### 2. Account and policy

- group `examweb`;
- user `examlogin`, primary group `examweb`, bash shell, home directory, usable password;
- password aging: minimum **10** days, maximum **120** days, warning **7** days;
- a sudo drop-in `/etc/sudoers.d/10-exama`, mode `0440`, that lets `examlogin` run **only** `/usr/bin/systemctl restart httpd.service` as root **without a password**;
- `visudo -c` must parse the whole configuration.

### 3. Content

- `/srv/exama/data/index.html` containing the text `Exam A portal ready`;
- owned by `examlogin`, group `examweb`, mode `0644`;
- SELinux type `httpd_sys_content_t`, and the label must be **persistent** across a relabel.

### 4. Service

- install `httpd`;
- serve the portal on port **8090**;
- the port must be labelled as a web port for SELinux;
- `httpd` must be **enabled** and **active**.

### 5. Firewall

- `8090/tcp` open in the `public` zone, **permanently** and in the running firewall;
- a request from `node2` to `http://10.10.10.10:8090/` must return the page.

### 6. Script

Write `/usr/local/bin/exama-count`, executable, that:

- takes **one** argument: the path to a passwd-format file;
- prints exactly `<n> bash accounts`, where `<n>` is the number of lines whose seventh colon-separated field is `/bin/bash`;
- exits non-zero if the file does not exist.

Example:

```text { .no-copy }
$ exama-count /tmp/sample-passwd
3 bash accounts
```

### 7. Schedule

- a timer `exama-stamp.timer` and its service, running **every minute**;
- the service is `Type=oneshot` and appends a timestamped line to `/srv/exama/reports/stamp.txt`;
- the timer must be **enabled** and **active**, and the file must actually grow.

### 8. Boot

The machine must still boot into `multi-user.target`. Reboot before you grade.

## Grading

From the host, after the reboot:

```bash
./bin/lab check r12 exama
```

The checker reads the end state, not the commands you used. It reports one line per requirement and exits non-zero if any fail.

## After the exam

| If you failed | Revisit |
|---|---|
| Storage, UUID, `findmnt --verify` | [R6 — Local storage](../../r06-local-storage/index.md) |
| Account, aging, sudo | [R2 — Users and groups](../../r02-users-and-groups/index.md) |
| Labels, port label, AVC | [R10 — SELinux and SSH](../../r10-security-selinux-ssh/index.md) |
| Service, timer, journal | [R5 — Processes and services](../../r05-processes-and-services/index.md), [R8 — Scheduling and time](../../r08-scheduling-and-time/index.md) |
| Firewall, peer request | [R9 — Networking and firewalld](../../r09-networking-and-firewall/index.md) |
| Script | [R4 — Shell scripting](../../r04-shell-scripting/index.md) |
