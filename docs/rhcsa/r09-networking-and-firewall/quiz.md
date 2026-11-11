# R9 knowledge check

Answer first, then open the answer. If you miss a question, return to the matching section of the [theory page](index.md).

### 1. Device, connection, active connection

You run `nmcli device status` and see `lab0  dummy  connected  lab0`. Name the three objects that line is describing.

??? question "Answer"
    `lab0` in the first column is the **device**, the kernel interface. The second `lab0` is the **connection**, the saved profile. The word `connected` says the profile is currently **active** on the device. The three can have different names: `nmcli connection add type dummy ifname lab0 con-name practice` gives a device `lab0` and a profile `practice`.

### 2. The change that does nothing

You run this, and the interface keeps its old address:

```bash
nmcli connection modify lab0 ipv4.addresses 192.0.2.20/24
nmcli -g ipv4.addresses connection show lab0
```

The second command prints the new address. Why is the interface still wrong, and what fixes it?

??? question "Answer"
    `connection modify` edits the profile on disk. It does not apply it to the running connection. The `connection show` output reads the file, which is why it looks correct. Apply the profile with `nmcli connection up lab0` (reactivates it) or `nmcli device reapply lab0` for changes that can be applied live. This is the most common `nmcli` mistake.

### 3. Two addresses, one profile

What does this create, and how many profiles does it leave behind?

```bash
nmcli connection add type dummy ifname lab0 con-name lab0 \
  ipv4.method manual ipv4.addresses 192.0.2.10/24 \
  ipv6.method manual ipv6.addresses 2001:db8::10/64
```

??? question "Answer"
    One profile named `lab0`, bound to a dummy device of the same name, carrying a static IPv4 address **and** a static IPv6 address. One profile can hold both families; they are separate sections in the keyfile. The device comes up with both addresses, plus an automatically generated `fe80::` link-local address for IPv6.

### 4. Why `never-default`

A second interface has a static address and a gateway. What can go wrong, and which property prevents it?

??? question "Answer"
    A second default route appears, and traffic leaves through the wrong interface — often the lab interface instead of the NAT interface, which kills package downloads and remote access. Set `ipv4.never-default yes` (and `ipv6.never-default yes`) on the profile. The safer habit is both: `never-default`, and no gateway at all on an interface that does not need one.

### 5. Where DNS comes from

You add `ipv4.dns 192.0.2.53` to the `lab0` profile. Which file shows the result, and what happens to a hand edit of that file?

??? question "Answer"
    `/etc/resolv.conf`, which NetworkManager generates from the active profiles: it writes the `search` domain and one `nameserver` line per configured server. The file is generated, so a hand edit survives only until the next reconnect or NetworkManager reload. Put DNS settings in the profile. `192.0.2.53` is a documentation address in this lab, so it is configured but never answers.

### 6. Which zone applies?

`node2` connects to `server` on `eth1`. Port `8080/tcp` is open in the `r9web` zone, and `lab0` is assigned to `r9web`. `node2` cannot reach port 8080. Why?

??? question "Answer"
    Firewall zones are selected by the **incoming** interface or source address. Traffic from `node2` enters on `eth1`, which is in the `public` zone, so only `public`'s rules apply. The rule in `r9web` is only usable by traffic arriving on `lab0`, and no other machine can send traffic to a dummy interface. Open the port in `public` as well.

### 7. Runtime or permanent?

Explain the difference between these two commands, and what each one does to the other's work:

```bash
firewall-cmd --add-port=9090/tcp
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --reload
```

??? question "Answer"
    The first changes the **running** firewall only; the rule exists in memory and nowhere on disk. The second writes the **permanent** configuration and does not apply it. `--reload` rebuilds the runtime rules from the permanent files, which applies `8080` and **discards** `9090`. The correct pattern is `--permanent` followed by `--reload`.

### 8. `curl` from the wrong place

A learner opens port 8080, runs `curl http://127.0.0.1:8080/`, gets a page, and concludes the firewall rule works. What is wrong with that test?

??? question "Answer"
    Loopback traffic does not traverse the interface rules, so it succeeds whatever the zone says. It does not even prove the rule is in the right zone. The honest test is a real client on another machine, over the network the rule is meant to protect — in this module, `node2` requesting `http://10.10.10.10:8080/`.

### 9. The name that resolves three times

`getent hosts server.r9.lab` prints an IPv6 address and two `fe80::` addresses, none of them the `10.10.10.10` you put in `/etc/hosts`. What is going on?

??? question "Answer"
    The machine owns that hostname, and `nsswitch.conf` lists `myhostname` before `dns`. The `myhostname` module answers for the local hostname from the machine's own addresses, including `lab0`'s IPv6 address and the link-local addresses on each interface. It is not a broken hosts file. Use `getent ahostsv4 <name>` to narrow the answer to IPv4, which is what a service on the lab network actually uses.
