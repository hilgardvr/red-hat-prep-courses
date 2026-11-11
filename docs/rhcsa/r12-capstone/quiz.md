# R12 knowledge check

Answer first, then open the answer. If you miss a question, return to the matching section of the [theory page](index.md) or the lab that taught it.

### 1. The command that proves nothing

You run `systemctl start httpd`, the page loads, and you move on. What will the reboot check say, and why?

??? question "Answer"
    It will fail, because `start` changes the running system only. The grader reads `systemctl is-enabled httpd`, which will say `disabled`. `enable` creates the `multi-user.target.wants` symlink that makes the unit start at boot; `start` does not.

### 2. The four layers

For each task, name the volatile form and the persistent form:

1. A filesystem mounted at `/srv/data`.
2. A firewall port opened for a service.
3. A custom SELinux label on a document root.
4. The machine booting to a different target.

??? question "Answer"
    1. `mount /dev/vg/lv /srv/data` → a line in `/etc/fstab`, proved with `findmnt --fstab`.
    2. `firewall-cmd --add-port=…` → the same with `--permanent`, then `--reload`, proved with `--permanent --query-port`.
    3. `chcon -t …` → `semanage fcontext -a -t …` plus `restorecon`, proved with `semanage fcontext -l -C`.
    4. `systemctl isolate target` → `systemctl set-default target`, proved with `systemctl get-default`.

### 3. The future-tense check

`findmnt /srv/data` shows the volume, but `findmnt --verify` reports `unreachable on boot required source: UUID=…`. Which one is the problem, and why does the mount still work?

??? question "Answer"
    The mount is live, so the current machine is fine. `fstab` names a UUID that no filesystem currently carries, so boot will fail to mount it. `findmnt --verify` resolves the source the way boot will; the live mount was made by hand or by an earlier, correct line. Fix the fstab source from `blkid`, run `systemctl daemon-reload`, and check again.

### 4. Three failures, three tools

You get a `403` from `httpd`. What is the first command you run, and what changes your diagnosis?

??? question "Answer"
    `ls -Z` on the file. If the type is wrong — for example `var_t` under `/srv` — the cause is SELinux; confirm with `grep ': avc:' /var/log/audit/audit.log` and look for `getattr denied`. If the label is correct and there is no AVC, the cause is a file mode, ownership, or a missing `Require all granted`, and `ls -l` plus the vhost file are the next tools.

### 5. A `403` with no AVC

The page returns `403`, `ls -Z` shows `httpd_sys_content_t`, and the audit log has no denial. What are the two most likely causes?

??? question "Answer"
    A permission problem — the file or one of its parent directories is not readable or searchable by the `apache` user — or the vhost is missing `<Directory …> Require all granted`. Check `namei -l /srv/r12/www/index.html` and the `<Directory>` block. SELinux is not refusing, because it would have logged an AVC.

### 6. Local works, the peer does not

`curl http://127.0.0.1:8088/` returns `200`, and `curl` from `node2` fails with `curl: (7) Failed to connect`. What layer is it, and what do you run?

??? question "Answer"
    The firewall. The service is healthy — it answered on loopback — but the packet from `node2` entered an interface whose zone does not allow the port. Run `firewall-cmd --zone=public --list-all` and confirm the port is missing, then `--permanent --add-port`, `--reload`, and fetch again. A `curl: (7)` means the connection never reached HTTP, which is why there is no journal line on `server`.

### 7. The zone that decides

`8088/tcp` is open in the `r12web` zone and `node2` still cannot reach it. Why?

??? question "Answer"
    `node2` arrives on `eth1`, which is in `public`. firewalld decides by the zone the **incoming interface** belongs to, so a rule in a zone the traffic never enters has no effect. Either move the interface to the zone or add the rule to `public`. R12 uses `public` because that is where the lab interfaces live.

### 8. Permanent without reload

`firewall-cmd --permanent --add-port=8088/tcp` prints `success`, and a request from `node2` still fails until you run `--reload`. Why?

??? question "Answer"
    `--permanent` writes the zone file; the running firewall keeps its current rules until it is reloaded (or restarted, or the machine reboots). `--permanent --query-port` says `yes` and `--query-port` says `no` in that window. Always do both, and prove the runtime layer separately.

### 9. The label that comes back

You run `chcon -t httpd_sys_content_t /srv/r12/www/index.html`, the page works, and after the next boot it is `var_t` again. What did you forget?

??? question "Answer"
    The persistent record. `chcon` changes the label now; `semanage fcontext -a -t httpd_sys_content_t '/srv/r12/www(/.*)?'` adds the rule, and `restorecon -Rv /srv/r12/www` applies it. A relabel at boot or `restorecon` elsewhere uses the record, not the last `chcon`.

### 10. The pattern that matches too little

You add `semanage fcontext -a -t httpd_sys_content_t '/srv/r12/www'` and the page still fails. Why?

??? question "Answer"
    The pattern matches the directory only, not the files inside it. Use `/srv/r12/www(/.*)?` so the rule covers the directory and everything below it, then `restorecon -Rv`. A correct rule applied to too narrow a path is one of the most common SELinux mistakes.

### 11. The port label

`httpd` is configured with `Listen 8088`, and it fails to start without a useful error in the browser. What does the journal show, and what is the fix?

??? question "Answer"
    A `name_bind` denial for `httpd_t` on the port, because `8088` is not in a web port type. Fix it with `semanage port -a -t http_port_t -p tcp 8088`, then restart `httpd`. The Boolean is not involved: binding a local port is a port-label question, not a network-connect question.

### 12. The live label and the record

Two files have `httpd_sys_content_t`, but one is restored by a relabel and the other is not. What distinguishes them, and which command tells you?

??? question "Answer"
    The persistent `fcontext` record. `semanage fcontext -l -C` lists the locally added rules; the file with a matching rule keeps its label, and the `chcon`-only file reverts. `ls -Z` shows the same label on both **now**, which is why a live check alone is not enough.

### 13. The timer that runs once

You enable a timer and the stamp file appears once, then never grows. Name two likely causes.

??? question "Answer"
    The timer is not enabled — you may have enabled `r12-stamp.service` instead of `r12-stamp.timer` — or the service lacks `Type=oneshot`, so the unit stays `activating` and the timer will not trigger it again. `systemctl list-timers --all` shows the `NEXT` line; `systemctl status r12-stamp.service` shows the state.

### 14. The program systemd cannot run

A timer's `ExecStart` points at `/srv/r12/r12-stamp`, the file is executable, and the unit fails with `203/EXEC`. Why?

??? question "Answer"
    SELinux. `/srv` is `var_t`, and systemd runs as `init_t`, which may execute `bin_t` (such as `/usr/local/bin`) but not `var_t`. Install the program in `/usr/local/bin` and point the unit there. The root shell can run the same file, which makes the failure look like a missing file rather than a policy denial.

### 15. The sudo rule that does nothing

`r12deploy` is in `wheel` and also has a drop-in, but `sudo -l -U r12deploy` does not show the narrow rule. What should you check first?

??? question "Answer"
    Whether the drop-in parses and whether the path in the rule is exact. Run `visudo -cf /etc/sudoers.d/10-r12-deploy` and `visudo -c`. A rule must name the command the way `sudo` execs it: `/usr/bin/systemctl restart httpd.service`, with the full path and the unit name. `sudo -l -U` is the user's view and the honest test.

### 16. The account that will not authenticate

The account exists, has the right group, and `passwd -S` says `L`. Can it log in, and what would the checker report?

??? question "Answer"
    No. `L` (or `LK`) means locked, and `NP` means no password. The checker requires a `P*` status — `P` on this image, `PS` on older releases — and never asserts the password itself. Unlock it with `passwd r12deploy` and confirm with `passwd -S`.

### 17. Time is a task too

You have eight tasks, six done, and twenty minutes left. One of the remaining is a storage task you have failed twice. What do you do?

??? question "Answer"
    Leave a note, move to the task you can finish, and come back only if time remains. A performance exam is graded per task; twenty more minutes on one task can cost three others. The theory page's time plan puts the confident tasks first and reserves the last ten percent for the persistence pass and the reboot.

### 18. The reboot pass

The exam allows a reboot at the end. What do you check first when it comes back?

??? question "Answer"
    The four persistence layers: `findmnt --fstab` and the live mount, `systemctl is-enabled` on every service and timer you touched, both firewall layers with `--permanent --query-port` and `--query-port`, and `semanage fcontext -l -C` plus `ls -Z` for the labels. Then the proof no local command replaces: a request from the other machine.
