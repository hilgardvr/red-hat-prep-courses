# Lab 1 — A static connection

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R9 — Networking and firewalld |
| **Time** | 60–75 minutes |
| **Check** | `./bin/lab check r09 lab1` |
| **Skills** | `nmcli` device/connection model, `connection add` and `modify`, static IPv4 and IPv6, DNS and search domains, `never-default`, `/etc/hosts`, `getent` |

</div>

## What you are building

| Item | End state |
|---|---|
| `lab0` | A dummy interface owned by NetworkManager |
| Addresses | `192.0.2.10/24` and `2001:db8::10/64`, both static |
| DNS | `192.0.2.53`, search domain `r9.lab` |
| Routing | `never-default` on both families |
| Boot | The profile activates automatically |
| Names | `r9peer.r9.lab` and `r9peer` resolve to `192.0.2.11` |
| Persistence | After a reboot the interface, both addresses, and the name are still there |

You are not touching `eth1` or the address you are connected through. That is the point: the commands are the same ones you would use on a real interface, without the risk of ending your own session.

!!! note "Addresses and UUIDs differ on every run"
    The `192.0.2.x` and `2001:db8::` blocks are documentation ranges and are fixed by the lab. The connection's UUID, the link-local IPv6 address, and the timings in `ping` are generated, so yours will differ. Everything else should match.

## Before you begin

Start from the clean snapshot:

```bash
cd labs
./bin/lab restore clean
./bin/lab ssh
sudo -i
```

Every command from here runs **inside the `server` VM** as root.

---

## Step 1 — Look before you change anything

```bash
nmcli device status
nmcli connection show
nmcli connection show --active
```

```text { .no-copy }
DEVICE  TYPE      STATE                   CONNECTION
eth0    ethernet  connected               Wired connection 1
eth1    ethernet  connected               lab-private
lo      loopback  connected (externally)  lo

NAME                UUID                                  TYPE      DEVICE
Wired connection 1  dcac6d89-ed1f-39e4-b4e9-43c10644d3e0  ethernet  eth0
lab-private         1336b26f-4c4a-48d6-8d99-0f8f9135219f  ethernet  eth1
lo                  6e485716-a728-47ab-8537-5853c0c85a54  loopback  lo
```

Three devices, three profiles, one active connection each. `eth0` is the NAT interface that reaches the package mirrors; `eth1` is the lab network at `10.10.10.10`; `lo` is managed outside NetworkManager, hence **externally**.

Confirm the lab address before adding anything:

```bash
ip -brief addr show eth1
ip route
```

```text { .no-copy }
eth1   UP   10.10.10.10/24 fe80::5054:ff:fe69:fabb/64
default via 192.168.121.1 dev eth0 proto dhcp src 192.168.121.100 metric 100
10.10.10.0/24 dev eth1 proto kernel scope link src 10.10.10.10 metric 100
```

There is exactly one default route, through `eth0`. Remember that; the new interface must not add a second one.

## Step 2 — Create the static connection

One command creates the profile, the address configuration, and the DNS settings:

```bash
nmcli connection add type dummy ifname lab0 con-name lab0 \
  ipv4.method manual ipv4.addresses 192.0.2.10/24 \
  ipv4.dns 192.0.2.53 ipv4.dns-search r9.lab \
  ipv6.method manual ipv6.addresses 2001:db8::10/64
```

```text { .no-copy }
Connection 'lab0' (9331d5b6-4abd-4be9-a4c3-9d8b65edb190) successfully added.
```

`type dummy` asks the kernel for a virtual interface named `lab0`; `ifname` is the device, `con-name` is the profile. They are the same here because that is the least confusing choice, but they do not have to be.

Now keep it from competing for the default route, and make it start at boot:

```bash
nmcli connection modify lab0 ipv4.never-default yes ipv6.never-default yes
nmcli connection modify lab0 connection.autoconnect yes
nmcli connection up lab0
```

```text { .no-copy }
Connection successfully activated (D-Bus active path: /org/freedesktop/NetworkManager/ActiveConnection/7)
```

`connection modify` changed the file. `connection up` is what applies it. Skip that second command and the interface stays exactly as it was, which is the most common nmcli mistake.

Look at the result:

```bash
nmcli -t -f NAME,DEVICE,STATE connection show --active
ip -brief addr show lab0
ip route
```

```text { .no-copy }
Wired connection 1:eth0:activated
lab0:lab0:activated
lab-private:eth1:activated
lo:lo:activated

lab0             UNKNOWN        192.0.2.10/24 2001:db8::10/64 fe80::3617:a77a:c06:e49b/64

default via 192.168.121.1 dev eth0 proto dhcp src 192.168.121.100 metric 100
10.10.10.0/24 dev eth1 proto kernel scope link src 10.10.10.10 metric 100
192.0.2.0/24 dev lab0 proto kernel scope link src 192.0.2.10 metric 550
```

Three things to notice:

- `lab0` carries **both** address families at once. One profile, two addresses.
- The `192.0.2.0/24` route is a **connected** route, automatically derived from the address. It is not a default route.
- The default route is still the single line through `eth0`. `never-default` did its job.

`UNKNOWN` is the operational state for a dummy device: it has no carrier to report. `ip addr` and traffic work normally.

## Step 3 — Name resolution

Add a static name. `getent` asks the same chain your programs use, so check the failure first:

```bash
getent hosts r9peer
```

```text { .no-copy }
[exit 2]
```

Nothing, and a non-zero exit. Now add the entry. The command is written to be repeatable:

```bash
grep -q '^192\.0\.2\.11[[:space:]]' /etc/hosts || \
  echo '192.0.2.11 r9peer.r9.lab r9peer' >> /etc/hosts
tail -3 /etc/hosts
getent hosts r9peer
getent hosts r9peer.r9.lab
```

```text { .no-copy }
10.10.10.10 server
10.10.10.11 node2
192.0.2.11 r9peer.r9.lab r9peer

192.0.2.11      r9peer.r9.lab r9peer
192.0.2.11      r9peer.r9.lab r9peer
```

Both names resolve to the same address because they are on the same line. The short name works because of `/etc/hosts`; the long name would also work through the `search r9.lab` directive once DNS is involved.

The DNS settings are in the profile, and NetworkManager used them to write `/etc/resolv.conf`:

```bash
cat /etc/resolv.conf
```

```text { .no-copy }
# Generated by NetworkManager
search r9.lab
nameserver 192.168.121.1
nameserver 192.0.2.53
```

`192.0.2.53` is a documentation address and will never answer. It is there to prove the path: the profile's `ipv4.dns` reached the resolver configuration. Every name in this lab resolves through `/etc/hosts`, which `nsswitch.conf` consults first.

## Step 4 — The profile is a file

```bash
ls -l /etc/NetworkManager/system-connections/lab0.nmconnection
cat /etc/NetworkManager/system-connections/lab0.nmconnection
```

```text { .no-copy }
-rw-------. 1 root root 299 Nov 10 05:46 /etc/NetworkManager/system-connections/lab0.nmconnection

[connection]
id=lab0
uuid=9331d5b6-4abd-4be9-a4c3-9d8b65edb190
type=dummy
interface-name=lab0

[dummy]

[ipv4]
address1=192.0.2.10/24
dns=192.0.2.53;
dns-search=r9.lab;
method=manual
never-default=true

[ipv6]
addr-gen-mode=default
address1=2001:db8::10/64
method=manual
never-default=true

[proxy]
```

This is the difference between `nmcli` and `ip addr add`. The file lives on disk, mode `0600`, and NetworkManager reads it at boot. The `[ipv4]` and `[ipv6]` sections are the same properties you set on the command line, spelled in full.

You may edit this file by hand — but then run `nmcli connection reload` and `nmcli connection up lab0`, or your change is invisible. On the exam, prefer `nmcli`.

## Step 5 — Prove both addresses answer

```bash
ping -c 2 192.0.2.10
ping -6 -c 2 2001:db8::10
```

```text { .no-copy }
PING 192.0.2.10 (192.0.2.10) 56(84) bytes of data.
64 bytes from 192.0.2.10: icmp_seq=1 ttl=64 time=0.035 ms
64 bytes from 192.0.2.10: icmp_seq=2 ttl=64 time=0.144 ms

--- 192.0.2.10 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1060ms
rtt min/avg/max/mdev = 0.035/0.089/0.144/0.054 ms

PING 2001:db8::10 (2001:db8::10) 56 data bytes
64 bytes from 2001:db8::10: icmp_seq=1 ttl=64 time=0.091 ms
64 bytes from 2001:db8::10: icmp_seq=2 ttl=64 time=0.146 ms

--- 2001:db8::10 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1019ms
rtt min/avg/max/mdev = 0.091/0.118/0.146/0.027 ms
```

Pinging your own address goes through the loopback path, so this proves the address is assigned and the stack answers — not that a remote client could reach it. That distinction matters in Lab 2, where the firewall is the subject.

## Step 6 — Persistence: reboot

```bash
systemctl reboot
```

Reconnect and look, without creating anything:

```bash
cd labs
./bin/lab ssh
sudo -i

nmcli -t -f NAME,DEVICE,STATE connection show --active
ip -brief addr show lab0
getent ahostsv4 r9peer
cat /etc/resolv.conf
```

```text { .no-copy }
Wired connection 1:eth0:activated
lab0:lab0:activated
lab-private:eth1:activated
lo:lo:activated

lab0             UNKNOWN        192.0.2.10/24 2001:db8::10/64 fe80::3617:a77a:c06:e49b/64

192.0.2.11      STREAM r9peer.r9.lab
192.0.2.11      DGRAM
192.0.2.11      RAW

# Generated by NetworkManager
search r9.lab
nameserver 192.168.121.1
nameserver 192.0.2.53
```

The profile came back because it is a file; the interface came up because `autoconnect` is `yes`; the name survived because `/etc/hosts` is a file; the resolver configuration was regenerated from the profile. If any of those were missing, the corresponding line would be gone — which is exactly what the checker tests.

## Verify with the checker

From the host, in the `labs` directory:

```bash
./bin/lab check r09 lab1
```

```text { .no-copy }
R9 Lab 1 — A static connection, two address families, and names
  PASS  the lab0 connection exists
  PASS  lab0 is configured manually
  PASS  lab0 carries the documented IPv4 address
  PASS  lab0 carries the documented IPv6 address
  PASS  lab0 comes up at boot
  PASS  lab0 never becomes the IPv4 default route
  PASS  lab0 never becomes the IPv6 default route
  PASS  the lab0 device is up with its IPv4 address
  PASS  the lab0 device is up with its IPv6 address
  PASS  lab0 sets the r9.lab DNS search domain
  PASS  r9peer resolves to its documented address
  PASS  the r9peer mapping lives in /etc/hosts
```

The checker reads the profile with `nmcli`, the live interface with `ip`, the name through `getent`, and the mapping in `/etc/hosts`. It does not care that you used `nmcli` rather than `nmtui`, and it does not read your shell history.

## If something went wrong

| Symptom | Likely cause | Fix |
|---|---|---|
| `Error: unknown connection 'lab0'` | The `add` command failed, or the name differs | `nmcli connection show` |
| The address is missing after `modify` | The connection was not reactivated | `nmcli connection up lab0` |
| A second default route appeared | `never-default` was not set, or a gateway was | `nmcli con mod lab0 ipv4.never-default yes` and re-up |
| `getent hosts r9peer` prints nothing | The `/etc/hosts` line is missing or in the wrong field order | `tail -5 /etc/hosts` |
| `getent hosts` shows IPv6 lines you did not add | `myhostname` answered for the machine's own name | Use `getent ahostsv4`, or resolve a name that is not the local hostname |
| `lab0` is missing after reboot | `autoconnect` is `no`, or the profile was deleted | `nmcli -g connection.autoconnect con show lab0` |
| `/etc/resolv.conf` lost the search domain | The profile was changed but not reapplied | `nmcli con up lab0` |
| `nmcli` prints `\:` in an address | Terse output escapes IPv6 colons | Read `ip addr`, or strip the backslashes |

To undo the lab: `nmcli connection delete lab0`, remove the `192.0.2.11` line from `/etc/hosts`, and reboot or `nmcli connection reload`. `./bin/lab restore clean` resets the whole machine instead.

## Next

[Lab 2 — Firewalld](lab-2-firewalld.md) puts `lab0` in its own zone, opens a port on the zone that `node2` actually reaches, and proves the difference between a rule that exists and a rule that works.
