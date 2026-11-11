# Challenge — A hardened service host

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R10 — Security: SELinux, SSH keys, and a hardened firewall |
| **Time** | 50–60 minutes |
| **Check** | `./bin/lab check r10 challenge` |
| **Style** | Exam task: requirements only, no steps |

</div>

This is the R10 challenge. It is written the way EX200 presents work: required behaviour, no walkthrough. Use the [theory page](../index.md), `man`, and your notes — but try it without a recipe first.

It assumes the machine from [Lab 1](lab-1-selinux.md) and [Lab 2](lab-2-ssh-keys.md). The new work is added beside that state and must not undo it.

Both VMs must be running, because the last requirement is proved from `node2`.

## Scenario

`server` is going to host an internal service. It already serves a page from `/srv` on a non-standard port, and its SSH daemon already refuses passwords. Now the port must be reachable **from the lab network and nowhere else**, and everything that was true before must still be true after a reboot.

The three layers are on purpose: SELinux decides whether the process may bind the port and read the files, firewalld decides who may reach it, and `sshd` decides who may log in.

## Tasks

1. Keep the web service from Lab 1 working:
   - `httpd` runs and is enabled at boot,
   - it serves `r10 custom root` from `/srv/r10/www` on port **18443**,
   - the file is labelled `httpd_sys_content_t` **and** has a persistent `semanage fcontext` mapping,
   - port `18443` carries an `http_port_t` label.

2. Keep the proxy working:
   - `/api/` on port `18443` proxies to a local backend on `127.0.0.1:18081`,
   - `httpd_can_network_connect` is **on and persistent**.

3. Restrict the service port to the lab network:
   - `18443/tcp` must be reachable from `10.10.10.0/24`,
   - it must **not** be open to every source,
   - the rule must be permanent **and** active now,
   - it belongs in the zone the client's traffic arrives in.

4. Keep the SSH hardening from Lab 2:
   - `PasswordAuthentication no`,
   - `PermitRootLogin no`,
   - `PubkeyAuthentication yes`,
   - `r10deploy` still logs in with `/home/labuser/.ssh/r10_ed25519`,
   - `labuser` still logs in with the lab kit's key.

5. Prove it from the client:
   - `node2` can fetch the page on port `18443`,
   - `node2` can still reach `server` over `ssh`,
   - SELinux is still enforcing.

6. Everything above survives a reboot of both VMs.

## What the checker proves

```text { .no-copy }
R10 Challenge — A hardened service host
  PASS  SELinux is still enforcing
  PASS  httpd is running
  PASS  httpd starts at boot
  PASS  port 18443 carries an http_port_t label
  PASS  the custom document root is served
  PASS  the page is labelled as web content
  PASS  the document root has a persistent label mapping
  PASS  the network-connect boolean is on
  PASS  the network-connect boolean is persistent
  PASS  httpd proxies to a local backend
  PASS  port 18443 is not open to every source
  PASS  a rich rule limits 18443 to the lab network
  PASS  the rich rule names the service port
  PASS  node2 can fetch the hardened page
  PASS  ssh still refuses passwords
  PASS  ssh still refuses root logins
  PASS  ssh still accepts public keys
  PASS  the server does not offer the password method
  PASS  the deploy account still logs in with the key
  PASS  labuser still logs in with the lab key
  PASS  node2 is still reachable from server
```

As in Lab 1, the proxy check is behavioural: the checker stops anything on `18081`, starts its own fixture, and fetches `/api/`. The firewall check is behavioural too — it fetches the page from `node2` — while the "not open to everyone" half is a configuration question, because no machine in the lab sits outside `10.10.10.0/24` to test from.

## Hints, in the order you will need them

??? hint "A rich rule is not a port"
    `--add-port=18443/tcp` opens the port to **every** source in that zone. A rich rule names a source, a port, and an action in one line. Adding both would defeat the restriction, and `--query-port=18443/tcp` answering `no` is then correct, not broken.

??? hint "The rule goes where the traffic arrives"
    `node2` reaches `server` on `eth1`, which is in `public`. A rich rule in a zone `eth1` never enters is invisible. Check `firewall-cmd --get-active-zones` before choosing.

??? hint "Permanent first, then reload"
    `--permanent --add-rich-rule=…` writes the file. `--reload` applies it. The checker asks for the permanent rule and for the live effect (a real fetch), so a pass on one and a fail on the other means exactly one half was done.

??? hint "Quote the whole rich rule"
    The rule contains spaces and double quotes. Leave it unquoted and the shell shreds it into arguments; the error mentions an unknown option. Wrap the whole value in single quotes and keep the inner double quotes as firewalld shows them.

??? hint "Do not undo Lab 1 to pass the challenge"
    The challenge asks for the SELinux work **and** the firewall work. Removing the port label, the `fcontext` mapping, or the Boolean to "simplify" fails the first ten checks.

??? hint "Do not undo Lab 2 either"
    The SSH drop-in is still in `/etc/ssh/sshd_config.d/10-r10.conf`. If you renamed or deleted it while experimenting, password authentication comes back and four checks fail.

??? hint "The reboot is part of the task"
    Run the checker before the reboot if you like, then reboot **both** machines and run it again. The port label, the `fcontext` mapping, and the Boolean live in the SELinux policy store; the zone is a file in `/etc/firewalld/zones/`; the SSH setting is a drop-in in `/etc/ssh/sshd_config.d/`. The reboot is what proves each one reached disk rather than the running state.

## When you are done

```bash
cd labs
./bin/lab check r10 all
```

`all` runs the three phases in order: Lab 1, Lab 2, then this challenge. It expects the challenge end state, which includes everything both labs created. If you restored a snapshot between labs, run the individual checks instead.

## Next

[R10 knowledge check](../quiz.md) and the [cheat sheet](../cheatsheet.md) close the module.
