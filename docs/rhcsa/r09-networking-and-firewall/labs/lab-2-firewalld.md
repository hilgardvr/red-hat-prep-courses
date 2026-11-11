# Lab 2 — Zones, ports, and a client

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R9 — Networking and firewalld |
| **Time** | 60–75 minutes |
| **Check** | `./bin/lab check r09 lab2` |
| **Skills** | firewalld zones, binding an interface, services versus ports, runtime versus permanent rules, a behavioural test from `node2` |

</div>

## What you are building

| Item | End state |
|---|---|
| `r9web` zone | A permanent zone that allows `http` and `8080/tcp` |
| Interface binding | `lab0` is assigned to `r9web`, permanently |
| `public` zone | Allows `8080/tcp` to the world, and still allows `ssh` |
| Temporary rule | `9090/tcp` opened at runtime only, gone after a reload |
| Proof | `node2` fails to reach port 8080, then succeeds |
| Persistence | After a reboot both zones and the port rule are still there |

The lesson in one sentence: **a firewall rule that exists and a firewall rule that works are different things**, and only a client from another machine can tell you which one you have.

!!! note "The listener does not survive the reboot"
    The lab serves a page with `python3 -m http.server`, started by hand. That process is gone after a reboot, so port 8080 will be *allowed* but nothing will be *listening*. The checker starts its own listener, so it does not depend on yours. The persistence test in Step 7 is about the firewall configuration, not about the web server.

## Before you begin

Continue from [Lab 1](lab-1-static-connection.md): `lab0` exists at `192.0.2.10/24` and `2001:db8::10/64`, and `r9peer` resolves.

Both VMs must be running, because Step 4 and Step 6 test from `node2`:

```bash
cd labs
./bin/lab status
./bin/lab ssh
sudo -i
```

If `node2` is not running, `./bin/lab up` starts it. Every command below runs **inside the `server` VM** as root unless it is marked `n2`, which runs on `node2`.

---

## Step 1 — Read the live firewall before changing it

```bash
firewall-cmd --get-default-zone
firewall-cmd --get-active-zones
firewall-cmd --list-all
firewall-cmd --permanent --get-zones
```

```text { .no-copy }
public

public (default)
  interfaces: eth0 eth1 lab0

public (default, active)
  target: default
  ingress-priority: 0
  egress-priority: 0
  icmp-block-inversion: no
  interfaces: eth0 eth1 lab0
  sources:
  services: cockpit dhcpv6-client ssh
  ports:
  protocols:
  forward: yes
  masquerade: no
  forward-ports:
  source-ports:
  icmp-blocks:
  rich rules:

block dmz drop external home internal nm-shared public trusted work
```

Read that carefully:

- Everything, including the new `lab0` from Lab 1, is in **public**. A new interface is assigned to the default zone automatically.
- `ssh` is in the services list. That is what you are connected through. It must stay.
- `ports` is empty. Nothing is open beyond the named services.

`--list-all` shows the **runtime** state. `--permanent --get-zones` shows what is written on disk. They currently agree, which is the normal starting point.

## Step 2 — A zone for the lab interface

```bash
firewall-cmd --permanent --new-zone=r9web
firewall-cmd --permanent --zone=r9web --add-service=http
firewall-cmd --permanent --zone=r9web --add-port=8080/tcp
firewall-cmd --permanent --zone=r9web --add-interface=lab0
```

```text { .no-copy }
success
success
success
The interface is under control of NetworkManager, setting zone to 'r9web'.
success
```

Four separate changes, all written to `/etc/firewalld/zones/r9web.xml`:

- the zone exists,
- it accepts the `http` service (port 80),
- it accepts raw port `8080/tcp`,
- `lab0` belongs to it.

The message on the fourth command matters. Because NetworkManager owns `lab0`, firewalld asks it to remember the zone, and the setting lands in the connection profile as `connection.zone=r9web`. That is why the binding survives a reboot without anyone re-running `--add-interface`.

Apply it and look at the live zone:

```bash
firewall-cmd --reload
firewall-cmd --zone=r9web --list-all
```

```text { .no-copy }
success

r9web (active)
  target: default
  ingress-priority: 0
  egress-priority: 0
  icmp-block-inversion: no
  interfaces: lab0
  sources:
  services: http
  ports: 8080/tcp
  protocols:
  forward: no
  masquerade: no
  forward-ports:
  source-ports:
  icmp-blocks:
  rich rules:
```

`(active)` means the zone is currently assigned to something. `forward: no` is firewalld's default for a new zone; the `public` zone has `forward: yes` because the distribution ships it that way.

Note what this zone does **not** do: it does not make `node2` able to reach `8080`. `node2` arrives on `eth1`, and `eth1` is in `public`. Traffic is filtered by the zone of the interface it arrives on, and only that zone's rules apply.

## Step 3 — A server to test with

```bash
mkdir -p /srv/r9/web
printf 'r9 web root\n' > /srv/r9/web/index.html
setsid python3 -m http.server 8080 --bind 0.0.0.0 \
  --directory /srv/r9/web >/srv/r9/web.log 2>&1 < /dev/null &
sleep 1
ss -ltn
curl -fsS --max-time 5 http://10.10.10.10:8080/
```

```text { .no-copy }
State  Recv-Q Send-Q Local Address:Port Peer Address:Port
LISTEN 0      128          0.0.0.0:22        0.0.0.0:*
LISTEN 0      5            0.0.0.0:8080      0.0.0.0:*
LISTEN 0      128             [::]:22           [::]:*

r9 web root
```

Three deliberate details:

- `--bind 0.0.0.0` makes the listener answer on every IPv4 address. The default for `http.server` is already all interfaces, but writing it down makes the intent visible.
- `setsid` detaches the server from your shell so it keeps running after the command returns.
- `--directory /srv/r9/web` means the process never changes your working directory.

`curl` from the machine itself succeeds **whatever the firewall says**. Loopback and local traffic do not traverse the interface rules. That is exactly why it is not a firewall test.

## Step 4 — The client cannot reach it yet

Run this on `node2` (the `n2` prefix is shorthand used through the rest of the lab):

```bash
ssh labuser@node2 \
  "curl -sS --max-time 3 http://10.10.10.10:8080/"
```

```text { .no-copy }
curl: (7) Failed to connect to 10.10.10.10 port 8080 after 0 ms: Could not connect to server
```

The port is listening on `server`, the address is routable, and the connection is refused. `public` has no rule for `8080`, so firewalld drops the packet before it reaches the process.

!!! note "Which zone applies?"
    `lab0` is in `r9web`, but `node2`'s traffic enters on `eth1`, which is in `public`. Interface zones are about the **incoming** interface. A port opened in `r9web` is only reachable through `lab0`, which no other machine can use.

## Step 5 — Runtime versus permanent

Open a port at runtime only:

```bash
firewall-cmd --add-port=9090/tcp --zone=public
firewall-cmd --zone=public --list-ports
firewall-cmd --permanent --zone=public --list-ports
```

```text { .no-copy }
success
9090/tcp

```

The runtime list has `9090/tcp`. The permanent list is **empty**: the rule exists in the running firewall and nowhere on disk. A reload throws it away.

Now add `8080` the right way, and reload:

```bash
firewall-cmd --permanent --zone=public --add-port=8080/tcp
firewall-cmd --reload
firewall-cmd --zone=public --list-ports
firewall-cmd --zone=public --query-service=ssh
```

```text { .no-copy }
success
success
8080/tcp
yes
```

Two things happened at once. `8080` is now in both layers, so a client can use it — and `9090` is gone, because the reload rebuilt the runtime state from the permanent files. Confirm that when you are unsure which layer you changed:

```bash
firewall-cmd --permanent --zone=public --list-ports
```

```text { .no-copy }
8080/tcp
```

The permanent list is the source of truth after a reboot.

## Step 6 — The client can reach it now

```bash
ssh labuser@node2 \
  "curl -fsS --max-time 5 http://10.10.10.10:8080/"
```

```text { .no-copy }
r9 web root
```

That is the whole point of the lab. The listening process never changed, the address never changed, and the client never changed. The only difference is a rule in the zone the client's traffic arrives on.

Prove you did not break the management path:

```bash
ssh labuser@node2 true && echo 'node2 still reachable'
```

```text { .no-copy }
node2 still reachable
```

If `ssh` had been removed from `public`, this line would fail — and so would every later lab step, which is why the checker asserts it.

## Step 7 — Persistence: reboot

```bash
systemctl reboot
```

Reconnect on `server`:

```bash
cd labs
./bin/lab ssh
sudo -i

firewall-cmd --get-active-zones
firewall-cmd --zone=r9web --list-all
firewall-cmd --zone=public --list-ports
```

```text { .no-copy }
public (default)
  interfaces: eth0 eth1

r9web
  interfaces: lab0

r9web (active)
  target: default
  ingress-priority: 0
  egress-priority: 0
  icmp-block-inversion: no
  interfaces: lab0
  sources:
  services: http
  ports: 8080/tcp
  protocols:
  forward: no
  masquerade: no
  forward-ports:
  source-ports:
  icmp-blocks:
  rich rules:

8080/tcp
```

`--get-active-zones` prints a zone without `(active)` when the zone exists but currently owns nothing; here it prints `r9web` followed by its interface, which is the same shape as `public` on the line above. `--list-all` calls it `(active)` explicitly.

That brings up the interesting part. The firewall starts before NetworkManager has created `lab0`, so at first the zone has no interface. When the dummy device appears, NetworkManager applies the profile, and the profile carries `connection.zone=r9web`, so firewalld moves `lab0` into the right zone. By the time you log in and look, the move has already happened.

That is why the binding is durable: it is stored twice, in `/etc/firewalld/zones/r9web.xml` for the zone definition and in `/etc/NetworkManager/system-connections/lab0.nmconnection` for the assignment. Either file alone would leave a gap — a zone with no interface, or a zone assignment pointing at a zone that no longer exists.

The listener is gone, as promised:

```bash
ss -ltn | grep 8080 || echo 'nothing listening on 8080'
```

```text { .no-copy }
nothing listening on 8080
```

## Verify with the checker

```bash
./bin/lab check r09 lab2
```

```text { .no-copy }
R9 Lab 2 — A zone, an open port, and a client that can use it
  PASS  the r9web zone exists permanently
  PASS  r9web permanently allows the http service
  PASS  r9web permanently allows port 8080/tcp
  PASS  r9web is bound to lab0
  PASS  the public zone permanently allows port 8080/tcp
  PASS  the public zone allows port 8080/tcp right now
  PASS  the temporary port 9090 was removed when the firewall reloaded
  PASS  the public zone still allows ssh
  PASS  node2 can fetch the page on port 8080
  PASS  node2 can still reach the server over ssh
```

The last two checks are the honest ones. The checker starts its own HTTP listener on `8080` if nothing is listening, then issues a real request **from `node2`** over the lab network. A firewall rule that exists only in the permanent files fails that request, and so does a rule in the wrong zone.

## If something went wrong

| Symptom | Likely cause | Fix |
|---|---|---|
| `node2` still refused after the reload | `8080` was added to `r9web` only | `firewall-cmd --permanent --zone=public --add-port=8080/tcp` and reload |
| The port rule vanished | Added without `--permanent` | Add it again with `--permanent`, then reload |
| `r9web` shows `interfaces:` empty after reboot | The zone is not on the connection profile | `firewall-cmd --permanent --zone=r9web --add-interface=lab0` and reload |
| `Warning: ALREADY_ENABLED` | The rule is already there | Nothing to do; check with `--query-port` |
| Your `ssh` session died | `ssh` was removed from the active zone, or a source zone took over | Reconnect through the console, restore `ssh`, reload |
| `n2 curl` says `Connection refused` | Nothing is listening on `server` | `ss -ltn`, then start the test server again |
| `n2 curl` times out instead of refusing | A drop rule or wrong address | `firewall-cmd --zone=public --list-all`, `ip route` |

To undo the lab:

```bash
firewall-cmd --permanent --zone=public --remove-port=8080/tcp
firewall-cmd --permanent --delete-zone=r9web
firewall-cmd --reload
```

or `./bin/lab restore clean` for a full reset. Deleting `r9web` while `lab0` is assigned to it is refused; remove the interface first with `--permanent --zone=r9web --remove-interface=lab0`.

## Next

[The challenge](challenge-service-host.md) gives `server` a fully qualified name, a second name that resolves only through `/etc/hosts`, and a second open port — and requires that Lab 1 and Lab 2 still work afterwards.
