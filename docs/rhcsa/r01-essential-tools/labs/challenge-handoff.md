# Challenge — Handoff bundle

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R1 — Essential tools |
| **Time** | 45–60 minutes |
| **Check** | `./bin/lab check r01 challenge` |
| **Style** | Exam task: requirements only, no steps |

</div>

This is the R1 challenge. It is written the way EX200 presents work: a set of required end states, with no command walkthrough. Use the theory page, `man`, and your notes if you need them — but try the whole thing without a recipe first.

Complete [Lab 2](lab-2-streams-and-permissions.md) before this challenge. It produces `/srv/r1/streams/ips.txt`, which you will reuse.

## Scenario

You are preparing a release handoff for another administrator. The bundle must be readable by the `wheel` group, must include a short report script, must be archived in two formats, and must be copied to `node2` with a verifiable checksum. Everything must still be in place after the server reboots.

## Tasks

1. Create `/srv/handoff` with these properties:
   - owner `root`, group `wheel`
   - mode `0770`

2. Create `/srv/handoff/release` with mode `0750`.

3. Create `/srv/handoff/release/report.sh`:
   - executable
   - mode `0750`
   - prints the hostname, the current date, and the kernel release
   - uses a `#!/usr/bin/env bash` shebang

4. Create `/srv/handoff/release/readme.txt`:
   - mode `0640`
   - contains the text `RHCSA handoff`

5. Copy the unique IPv4 list from Lab 2 to `/srv/handoff/release/ips.txt`:
   - mode `0644`
   - exactly the three unique addresses from `sample.log`

6. Create `/srv/handoff/release/tar-help.txt`:
   - non-empty
   - contains documentation text for `tar`, taken from the system's own documentation (for example, the first part of `man tar`)

7. Create two archives in `/srv/handoff`:
   - `handoff.tar.gz`, gzip-compressed
   - `handoff.tar.bz2`, bzip2-compressed
   - both must contain the `release/` directory and its files

8. Create `/srv/handoff/handoff.tar.gz.sha256`:
   - contains only the SHA-256 checksum of `handoff.tar.gz`
   - no filename, no extra text

9. Create `/srv/handoff/whoami.txt`:
   - contains `labuser`
   - produced by running `whoami` as `labuser` through `su -c`

10. Create `/srv/handoff/root-id.txt`:
    - contains `0`
    - produced by running `id -u` with `sudo`

11. Copy `handoff.tar.gz` and `handoff.tar.gz.sha256` to `node2`:
    - destination `/home/labuser/handoff/`
    - the files must be readable by `labuser` on `node2`

12. Verify the checksum on `node2`. The copied archive must match the checksum file.

13. Reboot `server`, reconnect, and run the checker. Every item must still pass.

## Constraints

- Run day-to-day commands as `labuser`.
- Use `sudo` where root privileges are required.
- Do not change the permissions of `/srv/r1`.
- Do not disable SELinux or the firewall. (Neither should interfere with this task.)
- The archives must be created from `/srv/handoff`, not from a copy elsewhere.

## Hints

<details>
<summary>Hint 1 — Creating the directory with the right owner and mode</summary>

`install -d` can create a directory and set its owner, group, and mode in one step:

```bash
sudo install -d -o root -g wheel -m 0770 /srv/handoff
sudo install -d -o root -g wheel -m 0750 /srv/handoff/release
```

The group matters as much as the mode. With `0750 root:root` you would lock yourself out of your own handoff directory.

</details>

<details>
<summary>Hint 2 — Writing the report script</summary>

`/srv/handoff/release` is `0750 root:wheel`. You are in `wheel`, so you can read and traverse it, but the group does **not** have write permission. Build the file where you can write, then install it with root ownership and the final mode:

```bash
cat > /tmp/report.sh <<'EOF'
#!/usr/bin/env bash
echo "hostname: $(hostname)"
echo "date: $(date)"
echo "kernel: $(uname -r)"
EOF
sudo install -m 0750 /tmp/report.sh /srv/handoff/release/report.sh
```

`install -m` copies the file and sets the mode in one step. The same pattern works for `readme.txt` and `ips.txt`, with `0640` and `0644`.

</details>

<details>
<summary>Hint 3 — Creating the archives</summary>

`-C` changes directory before archiving, so the archive contains `release/...` rather than the full path. Run `tar` with `sudo`: you cannot read every file in `release/` — `readme.txt` is `0640 root:root`, so group and world have no read access:

```bash
sudo tar -czf /srv/handoff/handoff.tar.gz -C /srv/handoff release
sudo tar -cjf /srv/handoff/handoff.tar.bz2 -C /srv/handoff release
sudo chown labuser /srv/handoff/handoff.tar.gz /srv/handoff/handoff.tar.bz2
```

Without `sudo`, `tar` stops with `release/readme.txt: Cannot open: Permission denied` and leaves a partial archive. The `chown` only matters for the next step, where `labuser` hashes and copies the file.

</details>

<details>
<summary>Hint 4 — Checksum file with only the hash</summary>

```bash
sha256sum /srv/handoff/handoff.tar.gz | cut -d' ' -f1 > /srv/handoff/handoff.tar.gz.sha256
```

</details>

<details>
<summary>Hint 5 — Copying to node2</summary>

The lab SSH configuration already points `node2` at the lab key, so this should work without `-i`:

```bash
ssh labuser@node2 'mkdir -p ~/handoff'
scp /srv/handoff/handoff.tar.gz /srv/handoff/handoff.tar.gz.sha256 \
  labuser@node2:~/handoff/
ssh labuser@node2 'sha256sum ~/handoff/handoff.tar.gz'
```

Compare the remote hash with `cat /srv/handoff/handoff.tar.gz.sha256`.

</details>

## Verify

From the host:

```bash
./bin/lab check r01 challenge
```

The checker inspects the local files, the archive contents, the checksum, and the copy on `node2`. It does not care which commands you used.

<details>
<summary>Show the expected check output</summary>

```text { .no-copy }
R1 Challenge — Handoff bundle
  PASS  /srv/handoff exists
  PASS  /srv/handoff is owned by root:wheel
  PASS  /srv/handoff is mode 770
  PASS  release directory is mode 750
  PASS  report.sh exists
  PASS  report.sh is executable
  PASS  report.sh is mode 750
  PASS  report.sh has a bash shebang
  PASS  report.sh prints the hostname
  PASS  report.sh prints the date
  PASS  report.sh prints the kernel
  PASS  readme.txt is mode 640
  PASS  readme.txt contains the marker
  PASS  ips.txt has three lines
  PASS  ips.txt contains the three unique addresses
  PASS  tar-help.txt is non-empty
  PASS  tar-help.txt mentions tar
  PASS  handoff.tar.gz exists
  PASS  handoff.tar.gz contains release/report.sh
  PASS  handoff.tar.gz contains release/readme.txt
  PASS  handoff.tar.bz2 exists
  PASS  handoff.tar.bz2 contains release/report.sh
  PASS  checksum file matches handoff.tar.gz
  PASS  whoami.txt contains labuser
  PASS  root-id.txt contains 0
  PASS  node2 has the archive
  PASS  node2 copy matches the checksum
```

</details>

## After the reboot

Reboot `server`:

```bash
sudo reboot
```

Wait for it to come back, reconnect with `./bin/lab ssh`, and run the checker again. This is the persistence test. In R1 the files themselves persist automatically, but the habit matters: from R6 onward, an unverified mount or service will fail exactly here.

## Review

If you passed, you have demonstrated the R1 objectives in one task:

- creating and permissioning directories and files
- writing and executing a script
- extracting and reusing text data
- creating archives in two formats
- using system documentation
- switching users with `su` and `sudo`
- copying files securely with `scp`
- verifying data integrity with `sha256sum`
- confirming the result after a reboot

If any item failed, note the exact command or concept that slowed you down. That is your review list before R2.
