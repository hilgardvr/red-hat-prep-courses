# Lab 2 — Streams and permissions

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R1 — Essential tools |
| **Time** | 45–60 minutes |
| **Check** | `./bin/lab check r01 lab2` |
| **Skills** | Redirection, pipes, `grep`, regex, `chmod`, `chown`, `umask`, `namei` |

</div>

This lab gives you a realistic-ish log file and asks you to extract information from it, then builds a small permission model around a protected report and a shared directory.

## Before you begin

From the host:

```bash
cd labs
./bin/lab restore clean
./bin/lab ssh
sudo su - labuser
```

If you did Lab 1 and want to keep its files, do not restore; just continue. The checker for Lab 2 only inspects the paths it creates.

Create the workspace:

```bash
sudo mkdir -p /srv/r1
sudo chown labuser:labuser /srv/r1
mkdir -p /srv/r1/streams /srv/r1/secure /srv/r1/shared /srv/r1/public
```

## Step 1 — Create the sample log

```bash
cat <<'EOF' > /srv/r1/streams/sample.log
2026-01-01 10:00:01 INFO  service started
2026-01-01 10:00:02 WARN  disk usage 81%
2026-01-01 10:00:03 ERROR failed to connect to 10.0.0.5
2026-01-01 10:00:04 INFO  retrying
2026-01-01 10:00:05 ERROR timeout from 192.168.1.20
2026-01-01 10:00:06 ERROR failed to connect to 10.0.0.5
2026-01-01 10:00:07 INFO  recovered
2026-01-01 10:00:08 WARN  certificate expires in 20 days
2026-01-01 10:00:09 ERROR dns lookup failed for 172.16.0.9
2026-01-01 10:00:10 INFO  health check ok
EOF
```

The quoted delimiter `'EOF'` prevents the shell from expanding anything inside the block. Verify the file:

```bash
cd /srv/r1/streams
wc -l sample.log
head -3 sample.log
```

You should have 10 lines.

## Step 2 — Extract the errors

```bash
grep ERROR sample.log > errors.txt
cat errors.txt
```

There are four `ERROR` lines. `>` redirects stdout to the file; nothing is printed to the terminal.

Count them into a file:

```bash
grep ERROR sample.log | wc -l > error-count.txt
cat error-count.txt
```

The pipeline sends the matching lines to `wc -l`, which prints `4`. The final `>` writes that number to the file.

## Step 3 — Extract unique IPv4 addresses

```bash
grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' sample.log | sort -u > ips.txt
cat ips.txt
```

Expected:

```text { .no-copy }
10.0.0.5
172.16.0.9
192.168.1.20
```

How it works:

- `-o` prints only the matched text, not the whole line.
- `-E` enables extended regular expressions.
- `[0-9]{1,3}` matches one to three digits.
- `\.` matches a literal dot; an unescaped `.` would match any character.
- `(...){3}` repeats the `digits + dot` group three times.
- `sort -u` sorts and removes duplicates.

## Step 4 — Separate stdout and stderr

Run a command that produces both success and failure output:

```bash
ls /etc/hosts /does-not-exist > stdout.txt 2> stderr.txt
```

Inspect:

```bash
cat stdout.txt
cat stderr.txt
```

`stdout.txt` contains `/etc/hosts`; `stderr.txt` contains the "No such file or directory" error. Now combine them in the correct order:

```bash
ls /etc/hosts /does-not-exist > combined.txt 2>&1
cat combined.txt
```

`combined.txt` contains both lines. Remember the order: stdout is redirected first, then stderr is pointed at it.

## Step 5 — Build the permission model

### A protected report

```bash
echo "quarterly report" > /srv/r1/secure/report.txt
chown labuser:labuser /srv/r1/secure/report.txt
chmod 640 /srv/r1/secure/report.txt
chmod 755 /srv/r1/secure
```

Mode `640` means:

- owner `labuser`: read and write
- group `labuser`: read
- other: no access

### An executable script

```bash
cat <<'EOF' > /srv/r1/secure/run.sh
#!/usr/bin/env bash
echo "report generator"
hostname
EOF
chown labuser:labuser /srv/r1/secure/run.sh
chmod 750 /srv/r1/secure/run.sh
```

Mode `750` means owner can read/write/execute, group can read/execute, other has nothing. The script is executable but not writable by the group.

Test it:

```bash
/srv/r1/secure/run.sh
```

### A shared directory and a public notice

```bash
chown labuser:labuser /srv/r1/shared
chmod 770 /srv/r1/shared
echo "office notice" > /srv/r1/public/notice.txt
chmod 644 /srv/r1/public/notice.txt
chmod 755 /srv/r1/public
```

`770` lets the owner and group create and remove files in the shared directory; others cannot enter it. `644` is the normal read-only-for-everyone file mode.

## Step 6 — umask

Set a restrictive umask and create a file:

```bash
cd /srv/r1/secure
umask 027
umask > umask.txt
touch private.txt
stat -c '%a %n' private.txt
```

The file mode is `640`: `666` minus `027`. The directory would be `750`: `777` minus `027`.

Restore a normal umask before continuing:

```bash
umask 022
```

## Step 7 — Diagnose access

Show the permissions on every component of the path:

```bash
namei -l /srv/r1/secure/report.txt
```

Then test as another user:

```bash
sudo -u vagrant cat /srv/r1/secure/report.txt
```

This should fail with `Permission denied`, because `vagrant` is "other" for a `640` file. Now test as the owner:

```bash
sudo -u labuser cat /srv/r1/secure/report.txt
```

This succeeds. If the first command had failed because of a missing `x` on a parent directory, `namei -l` would show which component was at fault.

## Step 8 — Verify

From the host:

```bash
./bin/lab check r01 lab2
```

<details>
<summary>Show the expected check output</summary>

```text { .no-copy }
R1 Lab 2 — Streams and permissions
  PASS  sample.log exists
  PASS  sample.log has 10 lines
  PASS  errors.txt contains only ERROR lines
  PASS  errors.txt has 4 lines
  PASS  error-count.txt is 4
  PASS  ips.txt contains the three unique addresses
  PASS  stdout.txt contains /etc/hosts
  PASS  stderr.txt contains the missing-file error
  PASS  combined.txt contains stdout
  PASS  combined.txt contains stderr
  PASS  secure directory is mode 755
  PASS  report.txt is mode 640
  PASS  report.txt is owned by labuser:labuser
  PASS  report.txt contains the report text
  PASS  run.sh is executable
  PASS  run.sh is mode 750
  PASS  run.sh is owned by labuser:labuser
  PASS  shared directory is mode 770
  PASS  notice.txt is mode 644
  PASS  private.txt is mode 640
  PASS  umask.txt records 0027
```

</details>

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `ips.txt` contains extra text | Missing `-o` on `grep`, so whole lines were written |
| `error-count.txt` has spaces | That is normal; the checker trims whitespace |
| `combined.txt` missing the error | Used `2>&1 > file` instead of `> file 2>&1` |
| `report.txt` still readable by `vagrant` | Parent directory is `777`, or the file mode is not `640` |
| `run.sh` will not execute | Missing `x` bit or missing shebang |
| `private.txt` is `644` | The `umask` command ran in a different shell, or was reset before `touch` |

## What to remember

- `>` truncates, `>>` appends, `2>` captures errors, `2>&1` merges streams.
- Redirection order is left to right.
- `grep -o` prints matches, not lines; `grep -E` enables extended regex.
- `chmod` sets the whole mode; `chown` changes ownership; `umask` subtracts from defaults.
- Directory `x` controls traversal; `namei -l` shows every component.
- `sudo -u user command` is the clean way to test access as another user.
