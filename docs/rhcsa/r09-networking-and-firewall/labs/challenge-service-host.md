# Challenge — A named service host

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R9 — Networking and firewalld |
| **Time** | 40–50 minutes |
| **Check** | `./bin/lab check r09 challenge` |
| **Style** | Exam task: requirements only, no steps |

</div>

This is the R9 challenge. It is written the way EX200 presents work: required behaviour, no walkthrough. Use the [theory page](../index.md), `man`, and your notes — but try it without a recipe first.

It assumes the machine from [Lab 1](lab-1-static-connection.md) and [Lab 2](lab-2-firewalld.md). The new work is added beside that state and must not undo it.

Both VMs must be running, because the last requirement is proved from `node2`.

## Scenario

`server` is becoming a small internal service host. It needs a fully qualified name that everything on the machine agrees on, a second service name that resolves through the local hosts file, and a second port open to the lab network. The three things that already work — the static `lab0` interface, the `r9peer` name, and the `r9web` zone — must survive.

## Tasks

1. Give `server` the static hostname `server.r9.lab` and add a matching `/etc/hosts` line so the name resolves to `10.10.10.10` through `files`.

2. Add the name `r9api.r9.lab`, with short form `r9api`, resolving to `192.0.2.20` through `/etc/hosts`.

3. Open **8443/tcp** to the lab network:
   - the rule must be in the `public` zone,
   - it must be permanent **and** active now,
   - the `r9web` zone must keep its `http` service and its `8080/tcp` port.

4. Prove it from the client:
   - `node2` can fetch a page from port **8443**,
   - `node2` can still fetch a page from port **8080**,
   - `ssh` from `node2` to `server` still works.

5. Leave the earlier work intact:
   - `lab0` still carries `192.0.2.10/24` and `2001:db8::10/64`,
   - `lab0` is still in the `r9web` zone,
   - `r9peer` still resolves to `192.0.2.11`.

6. Everything above survives a reboot of `server`.

## What the checker proves

```text { .no-copy }
R9 Challenge — A named service host
  PASS  the static hostname is fully qualified
  PASS  the hostname has an /etc/hosts mapping
  PASS  the hostname resolves to its lab address
  PASS  r9api resolves to its documented address
  PASS  the r9api mapping lives in /etc/hosts
  PASS  the public zone permanently allows port 8443/tcp
  PASS  the public zone allows port 8443/tcp right now
  PASS  node2 can fetch the API on port 8443
  PASS  node2 can still fetch the web page on port 8080
  PASS  lab0 still carries its static IPv4 address
  PASS  r9peer still resolves
  PASS  r9web still allows http
  PASS  node2 can still reach the server over ssh
```

The checker starts its own listeners on `8080` and `8443`, so a stopped web server is not a failure. What it tests is whether a client on the lab network can reach those ports through the firewall.

## Hints, in the order you will need them

??? hint "The hostname and the hosts file are two separate changes"
    `hostnamectl set-hostname` writes `/etc/hostname` and applies the name immediately. It does not add a line to `/etc/hosts`, so the name is not resolvable through `files` until you add one. The checker needs both: the static name string, and a hosts line whose first field is `10.10.10.10` and which lists `server.r9.lab` among its names.

??? hint "The hosts-file mapping can be checked without DNS"
    `getent ahostsv4 <name>` restricts the answer to IPv4 and returns one line per address. Plain `getent hosts` may return the machine's own IPv6 and link-local addresses through the `myhostname` module, which is not wrong but is hard to read. The checker looks at `/etc/hosts` directly for the mapping and uses `getent ahostsv4` for the resolution.

??? hint "A port belongs to a zone"
    `node2` reaches `server` through `eth1`, and `eth1` is in `public`. Adding `8443` to `r9web` would be invisible to it. Check where the client's traffic actually arrives before choosing the zone.

??? hint "Permanent first, then reload"
    `--permanent --add-port=8443/tcp` writes the file. `--reload` applies the files and discards anything runtime-only. The checker asks both layers separately, so a pass on one and a fail on the other means exactly one half was done.

??? hint "Do not lose ssh"
    The `public` zone is the path your own session uses. It already allows `ssh`; adding a port does not remove it, but removing the service, or moving `eth1` to a new zone without `ssh`, ends the session. The checker asserts the `ssh` path at the end for that reason.

??? hint "The reboot is part of the task"
    Run the checker before the reboot if you like, then reboot `server`, wait for it to come back, and run it again. The hostname lives in `/etc/hostname`, the names in `/etc/hosts`, the zone in `/etc/firewalld/zones/`, and the `lab0` assignment in the NetworkManager profile — four files, four reasons the work survives.

## When you are done

```bash
cd labs
./bin/lab check r09 all
```

`all` runs the three phases in order: Lab 1, Lab 2, then this challenge. It expects the challenge end state, which includes everything the labs created. If you restored a snapshot between labs, run the individual checks instead.

## Next

[R9 knowledge check](../quiz.md) and the [cheat sheet](../cheatsheet.md) close the module.
