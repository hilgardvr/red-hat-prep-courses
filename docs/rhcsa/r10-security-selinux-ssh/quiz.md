# R10 knowledge check

Answer first, then open the answer. If you miss a question, return to the matching section of the [theory page](index.md).

### 1. Two kinds of "no"

A file is mode `0644`, owned by root, and contains a page the web server should serve. The request returns `403`. Permissions say the file is world-readable. What refused the request?

??? question "Answer"
    SELinux. The file's **type** is wrong — probably `var_t` because it was created under `/srv` — and the `targeted` policy has no rule allowing `httpd_t` to read `var_t`. This is the difference between discretionary access control (the owner decides, via permissions) and mandatory access control (the policy decides, whatever the owner wants). The audit log names the exact types.

### 2. Four fields

Break `unconfined_u:object_r:httpd_sys_content_t:s0` into its parts and say which one the policy actually uses.

??? question "Answer"
    `unconfined_u` is the SELinux user, `object_r` the role, `httpd_sys_content_t` the **type**, and `s0` the MLS level. The type is what policy rules are written against: `allow httpd_t httpd_sys_content_t : file read;`. For files the user and role are almost always `system_u`/`unconfined_u` and `object_r`, and `targeted` leaves the level at `s0`.

### 3. `chcon` looked like a fix

You run `chcon -t httpd_sys_content_t /srv/app/index.html`, the page starts working, and after the next `restorecon` it breaks again. Why, and what is the durable version?

??? question "Answer"
    `chcon` changes the label on that inode and nothing else. `restorecon` resets files to the label the **policy** dictates, and the policy has no mapping for `/srv/app`, so the file goes back to `var_t`. The durable version is a persistent mapping plus a relabel: `semanage fcontext -a -t httpd_sys_content_t '/srv/app(/.*)?'` then `restorecon -Rv /srv/app`. `semanage fcontext -l -C` shows your local additions.

### 4. `restorecon` changes nothing

You add the `fcontext` mapping, run `restorecon -v /srv/app`, and it prints nothing at all. The labels are still `var_t`. What are the two likely reasons?

??? question "Answer"
    Either the path you passed does not match the pattern you wrote (a trailing slash, a different directory, or an unquoted shell-expanded pattern are the usual causes), or you are looking at a path the pattern does not cover. `matchpathcon -n /srv/app/index.html` prints the label policy *would* assign, which is the fastest way to see whether the mapping is being consulted at all.

### 5. The port that will not bind

`systemctl restart httpd` fails with `(13)Permission denied: AH00072: make_sock: could not bind to address 0.0.0.0:18443`, and `ss -ltn` shows nothing on that port. Name the denial and the fix.

??? question "Answer"
    The denial is `name_bind` with `scontext=…:httpd_t` and `tcontext=…:unreserved_port_t`. The port has no label that `httpd_t` is allowed to bind. Fix it with `semanage port -a -t http_port_t -p tcp 18443`. `Permission denied` on a bind is an SELinux message; a port already in use gives `Address already in use` instead.

### 6. The Boolean that forgets

You run `setsebool httpd_can_network_connect on`, the proxy starts working, and after a reboot it returns `503` again. `getsebool` now says `off`. What did you miss?

??? question "Answer"
    `-P`. `setsebool` changes the running value only; `setsebool -P` writes it into the policy store so it persists. `semanage boolean -l` prints the pair `(current, persistent)`, and after a plain `setsebool` the two disagree — which is exactly the state you were in before the reboot.

### 7. Same status code, different layer

`curl http://127.0.0.1:18443/api/` returned `503` before you enabled `httpd_can_network_connect`, and it returns `503` again after a reboot. Are these the same failure?

??? question "Answer"
    No. The first was SELinux refusing the outbound connection: a `name_connect` denial with `dest=18081`. The second is the proxy being **allowed** to connect and finding nothing there, because the backend was a hand-started `python3 -m http.server` that did not survive the reboot. The status code tells you the request failed; only the audit log tells you which layer refused it.

### 8. First value wins

`/etc/ssh/sshd_config.d/50-cloud-init.conf` contains `PasswordAuthentication yes`. You add `60-r10.conf` with `PasswordAuthentication no`, reload, and `sshd -T` still says `yes`. Why?

??? question "Answer"
    `sshd` reads the drop-ins in alphabetical order and, for most keywords, **the first value wins**. `50-cloud-init.conf` is read first and sets `yes`; your later file is parsed and ignored. Name the drop-in `10-r10.conf` so it is read before the cloud-init file. `sshd -T` is the only reliable check, because the file you wrote is correct and still has no effect.

### 9. `-t` and `-T` are not the same

What does each of these do, and which one would you run before a reload?

```bash
sshd -t
sshd -T
```

??? question "Answer"
    `sshd -t` **tests** the configuration: it parses the files and exits non-zero on a syntax error, printing nothing when they are valid. It is the one to run before a reload, because a restart with a broken config can leave the daemon down. `sshd -T` prints the **effective** configuration after includes, `Match` blocks, and defaults. It is the one to run when you want to know what the daemon will actually do.

### 10. Reading the refusal

A hardened server rejects your login with:

```text { .no-copy }
labuser@server: Permission denied (publickey,gssapi-keyex,gssapi-with-mic).
```

How do you know password authentication is off, and what would the same message look like if it were on?

??? question "Answer"
    The list in the parentheses is the set of methods the server is willing to use. There is no `,password`, so the server does not offer it. With password authentication on, the same line ends `…,password)`. This is a better test than grepping the config file, because it is the daemon's own answer after every include and `Match` block has been applied.

### 11. The key that is ignored

`authorized_keys` contains the right public key, the file is `0600`, and the login still fails. The server log says `Authentication refused: bad ownership or modes`. What is wrong?

??? question "Answer"
    One of the parent directories is writable by group or others. The checks are: the home directory must not be group- or world-writable, `~/.ssh` must be `0700`, and `authorized_keys` must be `0600`. A key in a world-writable directory could be replaced by anyone, so `sshd` refuses to trust it. `chmod go-w ~` and `chmod 700 ~/.ssh` fix it.

### 12. Port or rich rule

You need `18443/tcp` reachable from `10.10.10.0/24` only. Which of these is right, and what does the wrong one do?

```bash
firewall-cmd --permanent --zone=public --add-port=18443/tcp
firewall-cmd --permanent --zone=public --add-rich-rule='rule family="ipv4" source address="10.10.10.0/24" port port="18443" protocol="tcp" accept'
```

??? question "Answer"
    The rich rule. `--add-port` opens the port to **every** source in that zone, which is the opposite of the requirement. The rich rule carries source, port, and action in one line. After adding it, `--query-port=18443/tcp` correctly answers `no`; use `--list-rich-rules` or the rich-rule query to check the restriction. Adding both would defeat it.

### 13. Permissive is not fixed

A service fails to start under `Enforcing`. You run `setenforce 0`, it starts, and you move on. What have you actually done, and what will happen at the next boot?

??? question "Answer"
    Nothing durable. You changed the running mode only; `/etc/selinux/config` still says `enforcing`, so the next boot is back to enforcing and the service fails again. Meanwhile the denial is still being logged, which is the useful part: read it, fix the label or Boolean, `setenforce 1`, and test again. A service that only works in permissive has not been fixed.

### 14. Why not `disabled`

Why is `SELINUX=disabled` worse than `SELINUX=permissive` when you are debugging?

??? question "Answer"
    `disabled` needs a reboot in both directions, stops the kernel from labelling new files, and returning to enforcing requires a full filesystem relabel (`touch /.autorelabel` and a slow reboot) because files created while disabled have no usable labels. Permissive keeps labelling and keeps logging denials while allowing the action, which is exactly what you want from a diagnostic mode.
