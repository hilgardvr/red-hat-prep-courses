# Lab setup

The course labs run on two disposable virtual machines on your own Linux host. This keeps the exercises faithful to the exam — you get real systemd, real storage, real SELinux, and real reboots — without cloud costs or restricted features.

The lab kit lives in the `labs/` directory of the course repository.

```text
labs/
├── Vagrantfile          # two VMs: server and node2
├── bin/lab              # up | halt | reset | snapshot | restore | check | ssh | doctor
├── provision/           # first-boot configuration
├── checks/              # automated lab verification
└── keys/                # generated lab SSH key (gitignored)
```

## Host requirements

| Requirement | Minimum | Recommended |
|---|---|---|
| Operating system | Linux with KVM | Fedora or RHEL 10 |
| CPU | 4 cores with virtualization | 8 cores |
| RAM | 16 GB | 24 GB or more |
| Free disk | 40 GB | 60 GB |
| Software | Vagrant 2.4+, vagrant-libvirt, libvirt, QEMU/KVM | Latest stable |

The two VMs request 4 GB and 2 GB of RAM, plus disk for the boxes, snapshots, and the extra storage disk. Overcommitting RAM makes the labs slow and can cause the kernel to kill processes during storage exercises.

## 1. Install the virtualization stack

### Fedora or RHEL-family host

```bash
sudo dnf install -y libvirt libvirt-daemon-kvm qemu-kvm virt-install \
  libvirt-devel gcc make ruby-devel
sudo systemctl enable --now libvirtd
```

Install Vagrant and the libvirt provider:

```bash
sudo dnf install -y dnf-plugins-core

# Fedora (DNF5):
sudo dnf config-manager addrepo \
  --from-repofile=https://rpm.releases.hashicorp.com/fedora/hashicorp.repo

# RHEL 10 (DNF5) — use the RHEL repository instead:
# sudo dnf config-manager addrepo \
#   --from-repofile=https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo

sudo dnf install -y vagrant
vagrant plugin install vagrant-libvirt
```

!!! note "DNF4 hosts"
    On RHEL 9 or another DNF4 host, the repository command is `sudo dnf config-manager --add-repo=<url>` instead of `addrepo --from-repofile=`. The rest is the same.

!!! note "Package names vary"
    Some distributions package Vagrant and vagrant-libvirt directly. If `dnf install vagrant` works on your release, use it. Otherwise the HashiCorp repository above is the supported path.

### Debian or Ubuntu host

```bash
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients virtinst \
  build-essential libvirt-dev ruby-dev
sudo systemctl enable --now libvirtd
```

Install Vagrant from the HashiCorp repository, then the provider:

```bash
wget -O- https://apt.releases.hashicorp.com/gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
. /etc/os-release
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com ${VERSION_CODENAME} main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y vagrant
vagrant plugin install vagrant-libvirt
```

## 2. Grant access to libvirt

Add your user to the `libvirt` and `kvm` groups, then log out and back in so the group membership takes effect:

```bash
sudo usermod -aG libvirt,kvm "$USER"
```

Verify that KVM is available:

```bash
ls -l /dev/kvm
sudo virt-host-validate qemu
```

You should see `QEMU: Checking for hardware virtualization : PASS`. If it fails, enable Intel VT-x or AMD-V in the firmware settings and reload the KVM module.

## 3. Get the course and check the host

```bash
git clone <course-repository-url> red-hat-certs
cd red-hat-certs/labs
./bin/lab doctor
```

`doctor` checks for Vagrant, the libvirt provider, `virsh`, KVM access, RAM, disk space, and the lab SSH key. It prints an install hint for anything missing.

## 4. Choose the lab operating system

The default box is **AlmaLinux 10**, a community rebuild that is binary-compatible with RHEL 10 for the skills in this course. It needs no Red Hat subscription and downloads automatically.

For exact exam fidelity, use **RHEL 10**. You need a RHEL 10 Vagrant box; the public Vagrant Cloud does not currently publish a generic RHEL 10 box. You can build one from the RHEL 10 KVM guest image or an ISO with Packer, then set:

```bash
LAB_BOX=your-org/rhel10 ./bin/lab up
```

The course content targets RHEL 10. When AlmaLinux differs in a way that matters for an exercise, the lab page calls it out.

## 5. Start the lab

```bash
./bin/lab up
```

On first run, this downloads the box, creates both VMs, provisions them, and generates an SSH key for cross-VM access. Expect several minutes.

Check the result:

```bash
./bin/lab status
```

| Machine | Address | Role | Resources |
|---|---|---|---|
| `server` | `10.10.10.10` | Main practice system | 2 vCPU, 4 GB RAM, 20 GB root + 10 GB `/dev/vdb` |
| `node2` | `10.10.10.11` | SSH, NFS, firewall, and client/server target | 1 vCPU, 2 GB RAM, 20 GB root |

Both machines run AlmaLinux 10 (or your chosen RHEL 10 box). The extra `/dev/vdb` disk on `server` is intentionally unpartitioned for the storage module.

### Lab accounts

| User | Password | Access |
|---|---|---|
| `vagrant` | `vagrant` (provided by Vagrant) | Passwordless sudo; used for provisioning |
| `labuser` | `labpass` | Member of `wheel`; normal sudo with password |

The labs use `labuser` for day-to-day work and `sudo` for administrative tasks. This mirrors a real workstation and gives you a non-root account to test permissions against.

```bash
./bin/lab ssh            # log in to server as vagrant
sudo su - labuser        # switch to the lab user
```

Inside the lab, you can also switch users from an existing session:

```bash
sudo su - labuser
```

## 6. Save a clean snapshot

Before the first lab, snapshot both machines:

```bash
./bin/lab snapshot clean
```

When a lab goes wrong — or when you simply want a fresh start — restore it:

```bash
./bin/lab restore clean
```

Other useful commands:

| Command | Effect |
|---|---|
| `./bin/lab halt` | Shut down both VMs, preserving state |
| `./bin/lab up` | Start them again |
| `./bin/lab reset` | Destroy and rebuild both VMs from scratch |
| `./bin/lab destroy` | Delete both VMs (asks for confirmation) |
| `./bin/lab ssh node2` | Log in to the second machine |
| `./bin/lab check r01 lab1` | Run the automated checker for a lab |

Snapshots consume disk. If you run low on space, delete old snapshots with `cd labs && vagrant snapshot list` and `vagrant snapshot delete <machine> <name>`.

## 7. Optional: offline RHEL 10 repository

The exam has no internet access. To make the lab behave the same way, attach a RHEL 10 installation ISO and use it as a local package repository:

```bash
LAB_ISO=/path/to/rhel-10-x86_64-dvd.iso ./bin/lab up
```

Provisioning mounts the ISO read-only on both VMs and writes `file:///mnt/rhel-iso/BaseOS` and `file:///mnt/rhel-iso/AppStream` repository definitions. The mount is added to `/etc/fstab` with `nofail` so it does not block a boot if the ISO is detached.

This is also the easiest way to run a RHEL 10 lab without registering a subscription, provided the box itself is RHEL 10.

## 8. Optional: register a RHEL 10 subscription

If you use a real RHEL 10 box and want online repositories, register it:

```bash
sudo subscription-manager register --username <your-red-hat-account>
sudo subscription-manager attach --auto
sudo dnf repolist
```

A free Red Hat Developer subscription covers individual development use. Check the current terms on the Red Hat Developer site. For an exam-like environment, prefer the local ISO repository.

## Verifying the lab

Run the smoke check:

```bash
./bin/lab check r01 lab1
```

Before you have done the lab it should fail with a list of missing items — that is expected. What matters is that the checker runs, can reach `server`, and produces per-item output.

## Troubleshooting

### `KVM is not available`

- Confirm virtualization is enabled in the BIOS/UEFI.
- Load the module: `sudo modprobe kvm_intel` or `sudo modprobe kvm_amd`.
- Check `ls -l /dev/kvm`. If it does not exist, the host cannot run KVM.

### `Permission denied` talking to libvirt

Your user is not in the `libvirt` group, or the group change has not taken effect. Run `id` and confirm `libvirt` is listed. Log out and back in, or reboot.

### Box download fails

Check network access and any proxy configuration. You can pre-download the box:

```bash
vagrant box add almalinux/10 --provider libvirt
```

### Provisioning fails during `dnf`

The box has no usable repositories. Either register a RHEL subscription or rebuild with `LAB_ISO` pointing at a RHEL 10 DVD. On AlmaLinux, confirm the box has network access.

### `ssh node2` fails from `server`

- Confirm both machines are running: `./bin/lab status`.
- Confirm the lab key exists on both: `ls -l ~/.ssh/lab_ed25519`.
- The lab sets `StrictHostKeyChecking accept-new` for lab hosts, so a new host key is accepted on the first connection. A changed key is still rejected; remove the stale entry with `ssh-keygen -R 10.10.10.11` and reconnect.

### The lab is slow or the kernel kills processes

Reduce VM memory in the `Vagrantfile`, or give the host more RAM. Do not run other memory-heavy virtual machines at the same time.

## Security note

The lab is deliberately disposable and uses well-known passwords. It is not hardened and must not be exposed to an untrusted network. The `10.10.10.0/24` network is private to the host. Destroy the lab when you are finished with the course.
