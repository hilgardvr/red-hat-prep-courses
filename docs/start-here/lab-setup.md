# Lab setup

The course labs run on two disposable virtual machines on your own Linux host. This keeps the exercises faithful to the exam — you get real systemd, real storage, real SELinux, and real reboots — without cloud costs or restricted features.

The lab kit lives in the `labs/` directory of the course repository.

```text { .no-copy }
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
| Software | Vagrant 2.3+, vagrant-libvirt, libvirt, QEMU/KVM | Latest stable (Vagrant 2.4.7+) |

The two VMs request 4 GB and 2 GB of RAM, plus disk for the boxes, snapshots, and the extra storage disk. Overcommitting RAM makes the labs slow and can cause the kernel to kill processes during storage exercises.

!!! warning "Windows and macOS are not supported hosts"
    The lab needs KVM, which is a Linux kernel feature. On Windows, WSL2 is the only route, and it works only if KVM is available *inside* WSL. That requires Windows 11 and nested virtualization:

    ```ini
    # %UserProfile%\.wslconfig  (on the Windows side, not /etc/wsl.conf)
    [wsl2]
    nestedVirtualization=true
    memory=16GB
    processors=8
    ```

    Then run `wsl --shutdown` and reopen your distro. Also enable systemd inside the distro:

    ```ini
    # /etc/wsl.conf
    [boot]
    systemd=true
    ```

    The gate is `ls -l /dev/kvm` inside WSL. If that file is missing, stop: qemu would fall back to software emulation and the lab would take hours. Install Linux natively, or use a spare Linux machine, instead.

    WSL2 also gives the distro only half the host RAM by default; the two VMs need 6 GB between them, so set `memory=` as shown.

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

## 4. The lab operating system

The lab runs **AlmaLinux 10**, a free community rebuild built from RHEL 10 source. It needs no Red Hat subscription and downloads automatically.

For the skills this course teaches, AlmaLinux 10 behaves like RHEL 10: the same `systemd`, SELinux, firewalld, DNF, NetworkManager, LVM, and filesystem layout. The course targets RHEL 10 for the exam and points out any rebuild difference that matters for an exercise. You do not need to change anything to follow along.

The VMs install their base packages from AlmaLinux's online repositories, so your host and the VMs need internet access on first boot.

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

Both machines run AlmaLinux 10. The extra `/dev/vdb` disk on `server` is intentionally unpartitioned for the storage module.

!!! note "Private lab network"
    Both VMs attach to the libvirt network `rhcsa-lab`, which has DHCP disabled. Provisioning configures the second NIC with a NetworkManager profile named `lab-private`, so the addresses `10.10.10.10` and `10.10.10.11` are applied inside the guest and survive a reboot. `virsh net-list --all` on the host should show `rhcsa-lab` as active.

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

### `Network 10.10.10.10 is not available`

This is a vagrant-libvirt connection-mode problem. Older vagrant-libvirt releases (0.11.x) default to `qemu:///session` when no URI is set, and session mode cannot create a private libvirt network. The lab Vagrantfile forces the system connection, but a VM created before that change can keep stale state.

Destroy and rebuild:

```bash
cd labs
./bin/lab destroy
./bin/lab up
```

If you maintain your own Vagrantfile, set this explicitly:

```ruby
config.vm.provider :libvirt do |lv|
  lv.qemu_use_session = false
end
```

Then confirm the lab network exists:

```bash
virsh --connect qemu:///system net-list --all
```

You should see `rhcsa-lab` in the list.

### The private IP is missing or shows a DHCP address

The lab does not use Vagrant's guest-side static network configuration. Provisioning creates a NetworkManager profile named `lab-private`. Check it inside the VM:

```bash
ip -4 addr show eth1
nmcli connection show
sudo nmcli connection up lab-private
```

If the profile is missing, the VM was provisioned before the current lab kit. Rebuild it with `./bin/lab reset`.

### Box download fails

Check network access and any proxy configuration. You can pre-download the box:

```bash
vagrant box add almalinux/10 --provider libvirt
```

### Provisioning fails during `dnf`

The VM could not reach usable repositories. Check the host's network and any proxy configuration, then rebuild the lab with `./bin/lab destroy && ./bin/lab up`.

### `ssh node2` fails from `server`

- Confirm both machines are running: `./bin/lab status`.
- Confirm the lab key exists on both: `ls -l ~/.ssh/lab_ed25519`.
- The lab sets `StrictHostKeyChecking accept-new` for lab hosts, so a new host key is accepted on the first connection. A changed key is still rejected; remove the stale entry with `ssh-keygen -R 10.10.10.11` and reconnect.

### The lab is slow or the kernel kills processes

Reduce VM memory in the `Vagrantfile`, or give the host more RAM. Do not run other memory-heavy virtual machines at the same time.

## Security note

The lab is deliberately disposable and uses well-known passwords. It is not hardened and must not be exposed to an untrusted network. The `10.10.10.0/24` network is private to the host. Destroy the lab when you are finished with the course.
