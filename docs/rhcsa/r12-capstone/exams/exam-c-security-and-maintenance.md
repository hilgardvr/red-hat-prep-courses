# Mock exam C — Security, service, and maintenance

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R12 — Capstone |
| **Time** | 2 hours, plus update time |
| **Check** | `./bin/lab check r12 examc` |
| **Style** | Timed exam: requirements only, reboot required |

</div>

!!! warning "Stop before you read on"
    Restore the clean snapshot, put your notes away, and start a clock. The boot task only passes after a reboot, so plan for it.

    ```bash
    cd labs
    ./bin/lab restore clean
    ./bin/lab up
    ```

## Scenario

`server` is going into a restricted network. It needs a hardened SSH daemon, a small labelled web service, a kernel audit argument, a configuration backup, and a maintenance tool. Nothing may break the key login the lab depends on.

Both VMs must be running: the web proof comes from `node2`.

## Requirements

### 1. Software

Install `httpd`, `policycoreutils-python-utils`, and `tree`. `tree` must be installed at the end.

### 2. Web service

- `/srv/examc/www/index.html` containing the text `Exam C service is live`;
- SELinux type `httpd_sys_content_t`, persistent across a relabel;
- port **8081** labelled as a web port for SELinux;
- `httpd` serving 8081, **enabled** and **active**;
- `8081/tcp` open in `public`, permanently and in the running firewall;
- `node2` must fetch `http://10.10.10.10:8081/`.

### 3. SSH hardening

Create `/etc/ssh/sshd_config.d/10-examc.conf`, mode `0600`, containing:

```text { .no-copy }
PasswordAuthentication no
PermitRootLogin no
```

The effective configuration (`sshd -T`) must show both settings, the configuration must parse, and:

- `labuser` must still log in with the lab key;
- a connection that offers only password authentication must **not** be offered the password method.

Do not remove the key from `authorized_keys`. If you lock yourself out, `./bin/lab ssh` still works.

### 4. Boot argument

Add `audit=1` to **every** installed kernel's command line, persistently, with `grubby`. After a reboot, `/proc/cmdline` must contain it. The machine must still default to `multi-user.target`, and SELinux must stay `Enforcing`.

### 5. Maintenance tasks

- create `/srv/examc/backup/etc-backup.tar.gz` containing `etc/hostname` and `etc/hosts` as relative paths;
- confirm the archive lists both members.

### 6. Reboot

Reboot `server`, log back in, and re-run every proof command before you grade.

## Grading

From the host, after the reboot:

```bash
./bin/lab check r12 examc
```

## After the exam

| If you failed | Revisit |
|---|---|
| Packages and repository | [R3 — Software and repositories](../../r03-software-and-repositories/index.md) |
| Labels, port label | [R10 — SELinux and SSH](../../r10-security-selinux-ssh/index.md) |
| SSH drop-ins and effective config | [R10 — SELinux and SSH](../../r10-security-selinux-ssh/index.md) |
| Firewall and peer request | [R9 — Networking and firewalld](../../r09-networking-and-firewall/index.md) |
| Kernel arguments and targets | [R11 — Boot, rescue, and updates](../../r11-boot-rescue-updates/index.md) |
| Archive | [R1 — Essential tools](../../r01-essential-tools/index.md) |
