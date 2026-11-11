# R9 — Networking and firewalld

<div class="module-meta" markdown>

| | |
|---|---|
| **Exam objective group** | 8 — Manage basic networking |
| **Time** | 4–5 hours including labs |
| **Prerequisites** | [R5 — Processes and services](../r05-processes-and-services/index.md) for systemd, and [R8 — Scheduling and time](../r08-scheduling-and-time/index.md) if you want the client test to use a hostname |
| **Labs** | 2 guided labs + 1 challenge |
| **Check command** | `./bin/lab check r09 lab1` (also `lab2` and `challenge`) |

</div>

A machine without a network is a very fast, very private computer. Everything the exam asks you to do afterwards — remote access, shared storage, a web server, a time client — assumes the network is configured correctly and survives a reboot.

R9 is about three layers that are easy to confuse:

1. **The link and its addresses** — what IPv4 and IPv6 addresses the interface has.
2. **Names** — how a hostname or a short name becomes an address, and which file decides that.
3. **The firewall** — which of those addresses and ports the machine will actually accept traffic on.

The lab teaches all three on a **dummy interface** rather than on the interface you are connected through. That is deliberate: a mistake with `nmcli` on `eth1` would lock you out of your own lab, and an exam task that breaks your session is not a lesson, it is a restart. The commands are identical; only the device name differs.

!!! note "Read it; do not memorise it"
    This page is a reference you will return to, not a list to learn by heart. The labs are where the commands become yours.

    Command blocks have a copy button. Blocks **without** one are output: they show what a command printed and are there to compare against, not to paste into a shell.

## Objective checklist

By the end of this module you should be able to:

- [ ] Explain the difference between a device, a connection profile, and an active connection
- [ ] Create a connection profile with `nmcli connection add`
- [ ] Set a static IPv4 address and a static IPv6 address on the same profile
- [ ] Set DNS servers and a DNS search domain
- [ ] Make a profile start at boot, and explain `never-default`
- [ ] Read `/etc/resolv.conf` and `/etc/nsswitch.conf` and say which is used when
- [ ] Add a static name to `/etc/hosts` and prove it with `getent`
- [ ] Set a fully qualified hostname with `hostnamectl`
- [ ] Read firewalld zones, services, and ports
- [ ] Open a port and a service permanently, and reload safely
- [ ] Explain runtime versus permanent rules
- [ ] Prove a port is reachable from a second machine
- [ ] Prove every change survives a reboot

---

## The NetworkManager model

On RHEL, **NetworkManager** owns the network configuration. You talk to it with `nmcli` (or `nmtui`, or the Cockpit web console). It has three objects, and keeping them apart explains most of the confusing output:

| Object | What it is | Example |
|---|---|---|
| **Device** | The kernel interface | `eth0`, `eth1`, `lab0`, `lo` |
| **Connection** | A saved profile: addresses, DNS, routes | `lab-private`, `lab0` |
| **Active connection** | A profile currently applied to a device | `lab0` on `lab0` |

A device can exist with no connection. A connection can exist with no device (a saved profile for hardware that is not present). One device can have several profiles, but only one is active at a time.

```bash
nmcli device status
nmcli connection show
nmcli connection show --active
```

```text { .no-copy }
DEVICE  TYPE      STATE                   CONNECTION
eth0    ethernet  connected               Wired connection 1
eth1    ethernet  connected               lab-private
lab0    dummy     connected               lab0
lo      loopback  connected (externally)  lo
```

`lo` says **externally** because NetworkManager does not manage the loopback device. That is normal.

### Profiles are files

Every saved connection is a keyfile under `/etc/NetworkManager/system-connections/`, mode `0600`, owned by root:

```text { .no-copy }
/etc/NetworkManager/system-connections/lab0.nmconnection
```

That is why a profile survives a reboot. Contrast it with `ip addr add`, which changes the running kernel and nothing else: it works until the next reboot, then vanishes. The exam objective is about configuration, so the exam wants the profile.

### The commands you will use

| Task | Command |
|---|---|
| List devices | `nmcli device status` |
| List profiles | `nmcli connection show` |
| Show one profile | `nmcli connection show lab0` |
| Create a profile | `nmcli connection add type <type> ifname <dev> con-name <name> ...` |
| Change it | `nmcli connection modify <name> <property> <value>` |
| Activate it | `nmcli connection up <name>` |
| Deactivate it | `nmcli connection down <name>` |
| Delete it | `nmcli connection delete <name>` |
| Re-read files from disk | `nmcli connection reload` |

`connection modify` writes the file; it does **not** apply the change to a running connection. You need `connection up` again (which reactivates it) or `nmcli device reapply <dev>` for changes that can be applied live. This is the single most common "my change did nothing" cause.

### Address properties

| Property | Meaning |
|---|---|
| `ipv4.method manual` | Use exactly the addresses in the profile |
| `ipv4.method auto` | Ask DHCP |
| `ipv4.method disabled` | No IPv4 on this profile |
| `ipv4.method link-local` | IPv4LL only (169.254/16) |
| `ipv4.addresses 192.0.2.10/24` | One or more addresses, comma-separated |
| `ipv4.gateway 192.0.2.1` | Default gateway for this profile |
| `ipv4.dns 192.0.2.53` | DNS servers |
| `ipv4.dns-search r9.lab` | Search domain appended to short names |
| `ipv4.never-default yes` | Never install a default route from this profile |
| `connection.autoconnect yes` | Activate at boot when the device appears |

IPv6 has the same shape under `ipv6.*`. `ipv6.method` accepts `manual`, `auto` (router advertisements or DHCPv6), `dhcp`, `link-local`, `disabled`, and `ignore`.

`never-default` matters on a secondary interface. Without it, a manually configured address with a gateway can compete with your primary route, and traffic leaves through the wrong interface. The lab sets it on both families and never gives the dummy a gateway at all.

### Creating the lab interface

```bash
nmcli connection add type dummy ifname lab0 con-name lab0 \
  ipv4.method manual ipv4.addresses 192.0.2.10/24 \
  ipv4.dns 192.0.2.53 ipv4.dns-search r9.lab \
  ipv6.method manual ipv6.addresses 2001:db8::10/64
nmcli connection modify lab0 ipv4.never-default yes ipv6.never-default yes
nmcli connection up lab0
```

A **dummy** interface is a real kernel interface with no physical backing. It carries addresses and routes like any other, it appears in `ip addr`, and it is perfect for practice because nothing outside the machine can depend on it.

The two address blocks are the documentation ranges — `192.0.2.0/24` (TEST-NET-1) and `2001:db8::/32` — so they cannot collide with anything real.

---

## IPv4 and IPv6 in one breath

| | IPv4 | IPv6 |
|---|---|---|
| Address length | 32 bits | 128 bits |
| Written | `192.0.2.10` | `2001:db8::10` |
| Prefix | `/24` = 255.255.255.0 | `/64` is the normal LAN size |
| Address assignment | DHCP, or manual | Router advertisements, DHCPv6, or manual |
| Loopback | `127.0.0.1` | `::1` |
| Link-local | `169.254.0.0/16` (automatic, rarely useful) | `fe80::/10` (automatic, always present) |
| Default route | `ipv4.gateway` | `ipv6.gateway` |

RHEL 10 prefers IPv6 when both are available. `getent ahosts` and `ssh` will try IPv6 first, which is why a service bound only to `0.0.0.0` can look unreachable when the client connects over IPv6.

A profile can carry both families at once, and the labs do. `ip -brief addr show lab0` prints both:

```text { .no-copy }
lab0   UNKNOWN   192.0.2.10/24 2001:db8::10/64 fe80::3617:a77a:c06:e49b/64
```

The `fe80::` address is generated from the interface's hardware address and is always there. It is how IPv6 neighbours find each other before any global address exists.

| Command | Shows |
|---|---|
| `ip -brief addr` | Addresses, one line per interface |
| `ip addr show lab0` | Full detail for one interface |
| `ip route` | IPv4 routing table |
| `ip -6 route` | IPv6 routing table |
| `ss -ltn` / `ss -lun` | TCP and UDP listeners |
| `ping -c2 192.0.2.10` | IPv4 reachability |
| `ping -6 -c2 2001:db8::10` | IPv6 reachability |
| `tracepath` | Path and MTU (may need installing) |

!!! warning "`ip` changes do not survive a reboot"
    `ip addr add`, `ip route add`, and `ip link set` are runtime changes. Use them to test, then put the same configuration into a NetworkManager profile. On the exam, a task that says "configure" means "configure persistently".

---

## Name resolution

A name becomes an address through a chain, and **`/etc/nsswitch.conf` decides the order**:

```text { .no-copy }
hosts:      files myhostname dns
```

| Source | File or service | Wins when |
|---|---|---|
| `files` | `/etc/hosts` | First by default |
| `myhostname` | systemd's own hostname and addresses | For the machine's own name |
| `dns` | Nameservers in `/etc/resolv.conf` | After the local files |
| `mdns`, `wins` | Multicast DNS / NetBIOS | Only if listed |

That ordering is why an entry in `/etc/hosts` beats a DNS server, and why editing `/etc/hosts` is the fastest way to make a name resolve on one machine.

```text { .no-copy }
192.0.2.11  r9peer.r9.lab r9peer
```

The first field is the address; every following field is a name for it. `getent` asks the same chain your programs do, so it is the honest test:

```bash
getent hosts r9peer
getent ahostsv4 r9peer
```

```text { .no-copy }
192.0.2.11      r9peer.r9.lab r9peer
```

`getent ahostsv4` restricts the answer to IPv4 and prints one address per line, which makes scripts reliable. `getent hosts` may return IPv6 or multiple lines.

### `/etc/resolv.conf`

NetworkManager generates `/etc/resolv.conf` from the active profiles. It collects the `search` domains and nameservers:

```text { .no-copy }
# Generated by NetworkManager
search r9.lab
nameserver 192.168.121.1
nameserver 192.0.2.53
```

- `search r9.lab` means `ping r9peer` also tries `r9peer.r9.lab`.
- `nameserver` lines are queried in order.
- The file is **generated**. Editing it by hand works until the next reconnect, then NetworkManager rewrites it. Put DNS in the connection profile instead.

| Task | Command |
|---|---|
| Set DNS servers | `nmcli connection modify lab0 ipv4.dns 192.0.2.53` |
| Set the search domain | `nmcli connection modify lab0 ipv4.dns-search r9.lab` |
| Prefer one profile's DNS | `nmcli connection modify lab0 ipv4.dns-priority -50` |
| Verify | `nmcli connection show lab0`, `cat /etc/resolv.conf` |

Lower `dns-priority` wins; `0` is the default, and negative values are preferred.

!!! note "This lab has no working DNS server"
    `192.0.2.53` is a documentation address. Adding it to `lab0` proves the configuration and changes `/etc/resolv.conf`, but it will never answer a query. Every name in this module resolves through `/etc/hosts`. That is not a shortcut: static host entries are a legitimate part of "configure hostname resolution", and the exam expects you to know both paths.

### The machine's own name

```bash
hostnamectl
hostnamectl set-hostname server.r9.lab
hostnamectl --static
hostnamectl --transient
```

| Kind | Where it lives | Survives reboot |
|---|---|---|
| Static | `/etc/hostname` | Yes |
| Transient | Kernel hostname | No |
| Pretty | Free-form description | Yes, in `/etc/machine-info` |

`set-hostname` writes the static name and applies it immediately. It does **not** touch `/etc/hosts`. That is why a new FQDN should get a matching line:

```text { .no-copy }
10.10.10.10  server.r9.lab
```

Without it, tools that resolve the hostname through `files` find nothing, and `sudo` may stall or warn. The `myhostname` NSS module is a safety net — it answers for the machine's own name — but it is not a substitute for a correct hosts file, and it can return several addresses.

`getent hosts server.r9.lab` on a machine that owns that name can therefore print the machine's own IPv6 addresses before any `/etc/hosts` line. `getent ahostsv4` narrows it to IPv4 and gives the answer a service actually uses:

```text { .no-copy }
10.10.10.10     STREAM server.r9.lab
```

---

## firewalld

`firewalld` is the firewall manager on RHEL. Underneath it uses nftables; you almost never write nftables rules by hand, and on the exam you never do.

The unit of configuration is a **zone**: a named set of rules that applies to the traffic that is assigned to it. Traffic gets assigned to a zone by its **incoming interface** or by its **source address**. Whatever is left over goes to the **default zone**.

```bash
firewall-cmd --get-default-zone
firewall-cmd --get-active-zones
firewall-cmd --list-all
firewall-cmd --list-all-zones
```

```text { .no-copy }
public (default, active)
  target: default
  interfaces: eth0 eth1
  sources:
  services: cockpit dhcpv6-client ntp ssh
  ports:
  protocols:
  forward: yes
  masquerade: no
  rich rules:
```

| Field | Meaning |
|---|---|
| `target` | What happens to traffic the zone does not allow. `default` is reject; `ACCEPT` allows everything; `DROP` silently discards |
| `interfaces` | Interfaces bound to this zone |
| `sources` | Source addresses or networks bound to this zone |
| `services` | Named services from `/usr/lib/firewalld/services/*.xml` |
| `ports` | Raw `port/protocol` openings |
| `protocols` | Whole IP protocols, rarely used |
| `rich rules` | Rules with addresses, logging, rate limits, and actions |

`ssh` being in `public` is what makes the lab reachable. Any zone change that removes it from the interface you are connected through ends your session. Check before you reload.

### Services versus ports

A **service** is a name for a set of ports, protocols, and helper modules. `http` is `80/tcp`; `https` is `443/tcp`; `ssh` is `22/tcp`; `nfs` is `2049/tcp` plus related ports; `ntp` is `123/udp`.

A **port** is the raw form, for something with no service definition:

```bash
firewall-cmd --permanent --add-port=8080/tcp
```

Use a service when one exists. It documents intent, and it carries the auxiliary ports that a bare port number would miss — the reason R7's NFS lesson needed `mountd` and `rpc-bind` as well as `nfs`.

| Task | Command |
|---|---|
| List services in a zone | `firewall-cmd --zone=public --list-services` |
| Add a service | `firewall-cmd --permanent --zone=public --add-service=http` |
| Remove a service | `firewall-cmd --permanent --zone=public --remove-service=http` |
| Add a port | `firewall-cmd --permanent --zone=public --add-port=8080/tcp` |
| Remove a port | `firewall-cmd --permanent --zone=public --remove-port=8080/tcp` |
| Ask about one | `firewall-cmd --zone=public --query-port=8080/tcp` |
| Show a zone in full | `firewall-cmd --zone=public --list-all` |

### Runtime versus permanent

This is the part that fails exams.

| Layer | Where it lives | Survives reload | Survives reboot |
|---|---|---|---|
| Runtime | Running nftables rules | No | No |
| Permanent | `/etc/firewalld/zones/*.xml` | Yes, after `--reload` | Yes |

- `--add-port=...` without `--permanent` changes the **running** firewall only.
- `--permanent` writes the **file** but does not apply it.
- `firewall-cmd --reload` throws away the runtime rules and rebuilds them from the permanent files.

So the correct pattern is always:

```bash
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --reload
firewall-cmd --list-ports
```

Two shortcuts:

| Command | Effect |
|---|---|
| `firewall-cmd --runtime-to-permanent` | Save the current runtime rules to the permanent files |
| `firewall-cmd --reload` | Discard runtime rules, apply permanent ones |

`--runtime-to-permanent` is useful when you have been experimenting, but it also makes every experiment permanent. On the exam, use `--permanent` as you go and reload once.

### Zones for a second interface

A zone only matters if traffic is assigned to it. Two ways:

```bash
firewall-cmd --permanent --zone=r9web --add-interface=lab0
firewall-cmd --permanent --zone=r9web --add-source=192.0.2.0/24
```

The first binds an interface, the second binds a network. When you add an interface that NetworkManager manages, firewalld asks NetworkManager to remember the zone on the connection, and you will see:

```text { .no-copy }
The interface is under control of NetworkManager, setting zone to 'r9web'.
```

That means the binding survives a reboot through the connection profile, not only through firewalld's own XML.

!!! warning "A source zone can lock you out"
    Adding `--add-source=10.10.10.0/24` assigns every packet from the lab network to that zone. If the zone does not include `ssh`, your next connection is rejected. If you want to practise source zones, include `ssh` in the new zone first, and keep a console open.

### What the firewall does not do

- It does not decide whether a service is running. An open port with no listener still refuses connections.
- It does not apply to loopback traffic. `curl http://127.0.0.1:8080/` succeeds whatever the zone says, which is why the lab tests from the other machine.
- It does not override SELinux. Both have to allow the traffic or the service.

The first point is why the module always pairs a firewall check with `ss -ltn` and a real client:

```bash
ss -ltn
curl -fsS http://10.10.10.10:8080/
```

---

## Common traps

| Trap | What happens | Fix |
|---|---|---|
| `nmcli con modify` and expecting an immediate change | The file changes, the running connection does not | `nmcli con up <name>` or `nmcli device reapply <dev>` |
| `ip addr add` for an exam task | Works until reboot | Put it in a connection profile |
| Forgetting `connection.autoconnect yes` | The address is gone after reboot | `nmcli con modify <name> connection.autoconnect yes` |
| A second interface with a gateway | Traffic leaves the wrong way | `ipv4.never-default yes`, or no gateway |
| Editing `/etc/resolv.conf` | NetworkManager rewrites it | Set DNS on the profile |
| `--add-port` without `--permanent` | Lost at the next reload or reboot | Add `--permanent` and reload |
| `--permanent` without `--reload` | Looks like it failed until reboot | `firewall-cmd --reload` |
| Opening `http` but testing port `8080` | Still refused | Services and ports are different lists |
| Removing `ssh` from the active zone | Your session dies | Add it back before reload, or use the console |
| A source zone without `ssh` | Every lab connection is rejected | Include `ssh`, or use an interface zone |
| `hostnamectl set-hostname` alone | The FQDN does not resolve locally | Add the `/etc/hosts` line |
| `curl` to `127.0.0.1` as a firewall test | Always succeeds | Test from `node2` |
| `ping` succeeds but the port is closed | ICMP is not the service | `ss -ltn` and a real client |
| A service listening on `127.0.0.1` only | Remote clients cannot connect | Bind `0.0.0.0` or the specific address |
| `nmcli` output with `\:` | Terse mode escapes colons in IPv6 | Strip them, or read `ip addr` |

---

## Next

[Lab 1 — A static connection](labs/lab-1-static-connection.md) creates a dummy interface with IPv4, IPv6, DNS, and a static name. [Lab 2 — Firewalld](labs/lab-2-firewalld.md) builds a zone, opens a port permanently, and proves it from `node2`. The [challenge](labs/challenge-service-host.md) turns the pair of VMs into a named service host with two open ports and a fully qualified hostname.
