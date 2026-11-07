# Using a RHEL 10 box

The lab defaults to **AlmaLinux 10** because it is freely available and binary-compatible with RHEL 10 for the skills in this course. The course content targets RHEL 10, and the exam runs on RHEL 10.

If you want exact exam fidelity, use a RHEL 10 Vagrant box:

```bash
LAB_BOX=your-org/rhel10 ./bin/lab up
```

The public Vagrant Cloud does not currently publish a generic RHEL 10 box. You have three realistic options.

## Option 1 — Use AlmaLinux 10 (default)

No action needed. This is the tested path. Differences that matter for the labs are called out on the relevant pages.

## Option 2 — Use a box from your organization

If your team already publishes a RHEL 10 Vagrant box, set `LAB_BOX` to its name. The box must meet the requirements below.

## Option 3 — Build a RHEL 10 box

Building a Vagrant box is environment-specific. The general path is:

1. Obtain a RHEL 10 installation ISO or KVM guest image. A Red Hat Developer subscription covers individual development use; check the current terms.
2. Create a VM with a `vagrant` user, SSH access, and passwordless sudo.
3. Install `qemu-guest-agent`, `cloud-init` (if you use it), and `openssh-server`.
4. Package the VM as a libvirt Vagrant box.
5. Add it locally and set `LAB_BOX`.

Packer's `qemu` builder with a Kickstart file is the most reproducible approach. A minimal Kickstart needs to create the `vagrant` user, install an SSH key, enable `sshd`, and allow passwordless sudo. The exact package set and disk layout are your choice.

## Box requirements

For the lab kit to work, the box must provide:

| Requirement | Why |
|---|---|
| A `vagrant` user with passwordless sudo | Vagrant provisioning and `./bin/lab ssh` |
| SSH on port 22, key-based login | Vagrant's default connection |
| `dnf` and usable repositories (or an attached ISO) | Package installation during provisioning |
| `qemu-guest-agent` | Clean shutdown and libvirt integration |
| Root disk of at least 20 GB, or support for resizing | Packages, logs, and snapshots |
| No network on `10.10.10.0/24` | The lab uses that private subnet |
| RHEL 10 or a compatible rebuild | Objective fidelity |

## Verifying a custom box

```bash
LAB_BOX=your-org/rhel10 ./bin/lab doctor
LAB_BOX=your-org/rhel10 ./bin/lab up
./bin/lab check r01 lab1
```

If provisioning fails during `dnf`, the box has no repositories. Register a subscription or attach a RHEL 10 ISO with `LAB_ISO`.

## Note on subscriptions

`subscription-manager` commands are RHEL-specific. AlmaLinux, Rocky Linux, and CentOS Stream use their own repository configuration and do not need a Red Hat subscription. The course teaches the RHEL commands because the exam runs on RHEL; the lab notes the rebuild differences where they matter.
