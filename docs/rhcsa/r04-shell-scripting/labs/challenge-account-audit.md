# Challenge — The account audit

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R4 — Shell scripting |
| **Time** | 45–60 minutes |
| **Check** | `./bin/lab check r04 challenge` |
| **Style** | Exam task: requirements only, no steps |

</div>

This is the R4 challenge. It is written the way EX200 presents work: required behaviour, no walkthrough. Use the [theory page](../index.md), `man`, and your notes — but try it without a recipe first.

It assumes the scripts from [Lab 1](lab-1-classify.md) and [Lab 2](lab-2-linereport.md) exist, because it uses the same three habits: validate the arguments, loop over input, and return a status the caller can act on.

## Scenario

The team that runs the build machines wants a weekly check for accounts whose home directory has disappeared — usually because a share was unmounted, or because someone deleted a directory by hand. The check must read a passwd-format file, not the live system, so it can be pointed at a captured file or at another machine's `/etc/passwd`.

## Tasks

Write `/srv/r4/bin/accounts`. It takes exactly one argument, the path to a passwd-format file.

1. If it is called with no argument, more than one argument, or an argument that is not a readable file, it must print a usage line to **stderr** and exit **2**.

2. It must read the file one line at a time. Blank lines and lines whose first character is `#` are comments and must be ignored.

3. Each remaining line is in `/etc/passwd` format — seven colon-separated fields. The first field is the account name and the sixth is the home directory.

4. For every account whose home directory exists and is a directory, print:

   ```text { .no-copy }
   <user> <home> ok <n>
   ```

   where `<n>` is the number of **regular files directly inside** that home directory. Subdirectories are not counted, and the count is not recursive.

5. For every account whose home is missing, or is not a directory, print:

   ```text { .no-copy }
   <user> <home> missing
   ```

6. The last line of output must be a summary:

   ```text { .no-copy }
   ok=<count> missing=<count>
   ```

7. Exit **0** when nothing is missing, and **1** when at least one account is missing. This is what lets the report be run from cron and alert on a non-zero status.

8. Reboot `server`. Afterwards the script must still be executable and produce the same output for the same input.

## Sample input

Create a fixture so you can test without touching the real `/etc/passwd`:

```bash
mkdir -p /srv/r4/homes/alpha/archive /srv/r4/homes/beta
echo "one" > /srv/r4/homes/alpha/a.txt
echo "two" > /srv/r4/homes/alpha/b.txt
echo "old" > /srv/r4/homes/alpha/archive/old.txt

cat > /srv/r4/users.txt <<'EOF'
# captured from a build machine
alpha:x:3001:3001::/srv/r4/homes/alpha:/bin/bash
beta:x:3002:3002::/srv/r4/homes/beta:/bin/bash
ghost:x:3003:3003::/srv/r4/homes/ghost:/bin/bash
EOF
```

The correct report for that file is exactly:

```text { .no-copy }
alpha /srv/r4/homes/alpha ok 2
beta /srv/r4/homes/beta ok 0
ghost /srv/r4/homes/ghost missing
ok=2 missing=1
```

with exit status `1`. `alpha` has two files in its home and one inside `archive/`, which must not be counted. `beta` exists and is empty, so its count is `0` — that is not the same as missing.

## Hints

Only if you are stuck.

<details>
<summary>How do I split a colon-separated line into fields?</summary>

Set `IFS` for the `read` command and name one variable per field:

```bash
while IFS=: read -r user _ _ _ _ home _; do
  ...
done < "$1"
```

`_` is just a variable name; reusing it is the convention for "I do not need this field".

</details>

<details>
<summary>Why does my counter stay at zero?</summary>

If you piped the file into the loop — `cat "$1" | while read ...` — the loop ran in a subshell, and its variables disappeared when it exited. Redirect the file into the loop instead: `done < "$1"`. The theory page calls this the pipeline trap.

</details>

<details>
<summary>How do I count files without counting directories?</summary>

```bash
n=$(find "$home" -maxdepth 1 -type f | wc -l)
```

`-maxdepth 1` stops at the home directory itself, and `-type f` excludes subdirectories. `wc -l` receives no filename, so the output is only the number.

</details>

<details>
<summary>How do I ignore blank lines and comments?</summary>

Inside the loop, before using the fields:

```bash
[ -n "$user" ] || continue
case "$user" in \#*) continue ;; esac
```

`\#` escapes the `#` so `case` treats it as a literal character rather than the start of a comment.

</details>

<details>
<summary>How should the script end?</summary>

The last command's exit status becomes the script's:

```bash
[ "$missing" -eq 0 ]
```

succeeds when nothing is missing and fails otherwise. An explicit `if ... exit 1; fi` is clearer if you prefer it.

</details>

## Verify

From the host:

```bash
./bin/lab check r04 challenge
```

The checker creates its own passwd-format fixture, with its own user names, homes, subdirectories and comment lines, and runs your script against it. Hardcoding the sample output fails.

<details>
<summary>Show the expected check output</summary>

```text { .no-copy }
R4 Challenge — The account audit
  PASS  script exists: /srv/r4/bin/accounts
  PASS  the script is executable
  PASS  the script parses: bash -n
  PASS  the script starts with a bash shebang
  PASS  no arguments exits 2
  PASS  the usage message goes to stderr
  PASS  a missing file is rejected with exit 2
  PASS  one line per account, in file order
  PASS  comments and blank lines are ignored
  PASS  the summary line reports both counts
  PASS  subdirectories are not counted
  PASS  exits 1 when an account is missing
  PASS  a file with no missing accounts exits 0
```

</details>

## After the challenge

Nothing to undo. The script and the fixture live under `/srv/r4`, which the next module does not use, and they do no harm. If you want the machine exactly as the course assumes:

```bash
./bin/lab restore clean
```
