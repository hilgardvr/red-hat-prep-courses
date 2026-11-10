# Lab 1 — Arguments, tests, and exit codes

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R4 — Shell scripting |
| **Time** | 60–75 minutes |
| **Check** | `./bin/lab check r04 lab1` |
| **Skills** | shebang, `chmod`, `bash -n`, `$1`, `$#`, `$@`, `[ ]` tests, `if`/`elif`, `exit` |

</div>

## What you are building

| Item | End state |
|---|---|
| `/srv/r4/bin/classify` | An executable bash script that reports what each of its path arguments is |
| `/srv/r4/data` | A small tree with a file, a directory, a symlink, a broken symlink, and a filename containing a space |
| Exit codes | `2` for wrong usage, `1` when any path is missing, `0` otherwise |

`classify` is small enough to understand completely, and it uses every piece of the objective except loops over files: a shebang, argument validation, a loop over `"$@"`, file tests, conditionals, and a meaningful exit status.

## Before you begin

Start from the clean snapshot:

```bash
cd labs
./bin/lab restore clean
./bin/lab ssh
sudo -i
```

From here on, every command runs **inside the `server` VM** as root.

## Step 1 — Create the test tree

```bash
mkdir -p /srv/r4/bin /srv/r4/data/logs
echo "first line" > /srv/r4/data/notes.txt
echo "a file with a space" > "/srv/r4/data/with space.txt"
ln -s notes.txt /srv/r4/data/current
ln -s gone.txt /srv/r4/data/old
ls -l /srv/r4/data
```

```text
total 8
lrwxrwxrwx. 1 root root  9 Nov 10 05:57 current -> notes.txt
drwxr-xr-x. 2 root root  6 Nov 10 05:57 logs
-rw-r--r--. 1 root root 11 Nov 10 05:57 notes.txt
lrwxrwxrwx. 1 root root  8 Nov 10 05:57 old -> gone.txt
-rw-r--r--. 1 root root 20 Nov 10 05:57 with space.txt
```

`old` points at a file that does not exist. That is called a **broken** or **dangling** symlink, and it is the case that separates people who test `-e` from people who test `-L`.

## Step 2 — A script with a shebang

```bash
cat > /srv/r4/bin/classify <<'EOF'
#!/bin/bash
# classify — report what each path is.
# usage: classify PATH...

echo "file $1"
EOF
chmod +x /srv/r4/bin/classify
bash -n /srv/r4/bin/classify
/srv/r4/bin/classify /srv/r4/data/notes.txt
```

```text
file /srv/r4/data/notes.txt
```

Four things to notice:

- The heredoc is quoted (`<<'EOF'`) so the shell does **not** expand `$1` while writing the file. Unquoted, `$1` would be replaced by the *outer* shell's first argument, usually nothing.
- `chmod +x` adds the execute bit for everyone. Without it, `./classify` fails with `Permission denied`.
- `bash -n` printed nothing. Silence is success: the script parses.
- The shebang is the first line and nothing precedes it — not a blank line, not a comment.

This version lies about everything except regular files, which is what the rest of the lab fixes.

## Step 3 — Replace the claim with a test

Open the file and write the real body:

```bash
vim /srv/r4/bin/classify
```

The final script:

```bash
#!/bin/bash
# classify — report what each path is.
# usage: classify PATH...

if [ "$#" -eq 0 ]; then
  echo "usage: $0 PATH..." >&2
  exit 2
fi

status=0

for path in "$@"; do
  if [ -L "$path" ]; then
    echo "link $path"
  elif [ -d "$path" ]; then
    echo "dir $path"
  elif [ -f "$path" ]; then
    echo "file $path"
  elif [ -e "$path" ]; then
    echo "other $path"
  else
    echo "missing $path"
    status=1
  fi
done

exit "$status"
```

Read it from the top, because every line is there for a reason:

| Line | Why |
|---|---|
| `[ "$#" -eq 0 ]` | Checks the count, not `$1` itself. An empty `$1` is also zero arguments, but `$#` says so directly. |
| `>&2` | The usage message goes to stderr, so a caller can capture real output without collecting complaints. |
| `exit 2` | Bad usage, distinct from "a path was missing" (`1`) and from success (`0`). |
| `status=0` | Accumulates failure. One missing path at the end sets the whole script's status. |
| `for path in "$@"` | One iteration per argument, with spaces preserved. |
| `-L` first | `-e`, `-d`, and `-f` all follow symlinks. Testing `-L` first is the only way to report `old` as a link rather than as missing. |
| `exit "$status"` | Without this, the script would exit with the status of the last `echo`, which is always 0. |

## Step 4 — Test every branch

```bash
/srv/r4/bin/classify /srv/r4/data/notes.txt
/srv/r4/bin/classify /srv/r4/data/logs
/srv/r4/bin/classify /srv/r4/data/current
/srv/r4/bin/classify /srv/r4/data/old
/srv/r4/bin/classify /srv/r4/data/nothing
```

```text
file /srv/r4/data/notes.txt
dir /srv/r4/data/logs
link /srv/r4/data/current
link /srv/r4/data/old
missing /srv/r4/data/nothing
```

`old` is reported as a link, not as missing, because `-L` is tested first. Now check what the last one did to the exit status, and prove that one bad path poisons a whole run:

```bash
/srv/r4/bin/classify /srv/r4/data/nothing; echo "exit=$?"
/srv/r4/bin/classify /srv/r4/data/notes.txt /srv/r4/data/logs /srv/r4/data/old /srv/r4/data/nothing
echo "exit=$?"
```

```text
missing /srv/r4/data/nothing
exit=1
file /srv/r4/data/notes.txt
dir /srv/r4/data/logs
link /srv/r4/data/old
missing /srv/r4/data/nothing
exit=1
```

Four arguments produced four lines **in the order given**, and the missing one set the exit status for all of them. That is the behaviour a monitoring script needs: one call, one verdict.

The last two checks are the ones beginners skip:

```bash
/srv/r4/bin/classify; echo "exit=$?"
/srv/r4/bin/classify /srv/r4/data/notes.txt /srv/r4/data/logs; echo "exit=$?"
/srv/r4/bin/classify "/srv/r4/data/with space.txt"
```

```text
usage: /srv/r4/bin/classify PATH...
exit=2
file /srv/r4/data/notes.txt
dir /srv/r4/data/logs
exit=0
file /srv/r4/data/with space.txt
```

The third command printed exactly one line. It worked because both `"$@"` and `"$path"` are quoted. Remove either pair of quotes and the file is classified as something else — try it, then put the quotes back:

```bash
[ -f /srv/r4/data/with space.txt ]   # bash: [: /srv/r4/data/with: binary operator expected
```

`[` receives five arguments instead of three, and reports the only thing it can: a syntax error. This is the single most common bash bug in existence.

## Step 5 — Watch it run

`bash -x` prints each command after the shell has expanded it, which shows you what bash actually did rather than what you meant:

```bash
bash -x /srv/r4/bin/classify /srv/r4/data/notes.txt /srv/r4/data/old
```

```text
+ '[' 2 -eq 0 ']'
+ status=0
+ for path in "$@"
+ '[' -L /srv/r4/data/notes.txt ']'
+ '[' -d /srv/r4/data/notes.txt ']'
+ '[' -f /srv/r4/data/notes.txt ']'
+ echo 'file /srv/r4/data/notes.txt'
+ file /srv/r4/data/notes.txt
+ for path in "$@"
+ '[' -L /srv/r4/data/old ']'
+ echo 'link /srv/r4/data/old'
+ link /srv/r4/data/old
+ exit 0
```

Every expanded command starts with `+`. You can see the loop running twice and the `elif` chain stopping at the first true test — which is what `elif` means, and why the order matters.

## Step 6 — Reboot and prove persistence

```bash
reboot
```

From the host:

```bash
cd labs
./bin/lab ssh
sudo -i
ls -l /srv/r4/bin/classify
/srv/r4/bin/classify /srv/r4/data/old /srv/r4/data/nothing; echo "exit=$?"
```

```text
-rwxr-xr-x. 1 root root 448 Nov 10 05:57 /srv/r4/bin/classify
link /srv/r4/data/old
missing /srv/r4/data/nothing
exit=1
```

The file, its contents, and its execute bit are all on disk, so all three survived. Nothing about a script lives in memory between boots.

## Step 7 — Run the checker

```bash
./bin/lab check r04 lab1
```

The checker does not read `/srv/r4/data`. It creates its own tree with different names — including a filename with a space and a broken link — runs your script against it, and compares output and exit codes. A script that prints fixed answers fails.

<details>
<summary>Show the expected check output</summary>

```text
R4 Lab 1 — Arguments, tests, and exit codes
  PASS  script exists: /srv/r4/bin/classify
  PASS  the script is executable
  PASS  the script parses: bash -n
  PASS  the script starts with a bash shebang
  PASS  no arguments exits 2
  PASS  the usage message goes to stderr
  PASS  a regular file is reported as file
  PASS  a directory is reported as dir
  PASS  a symlink to a file is reported as link
  PASS  a broken symlink is reported as link
  PASS  a missing path is reported as missing, exit 1
  PASS  several paths are reported in argument order
  PASS  a filename containing a space is still one path
  PASS  a run where every path exists exits 0
```

</details>

## If something fails

| Symptom | Cause |
|---|---|
| `Permission denied` | No execute bit: `chmod +x /srv/r4/bin/classify` |
| `[: missing ]` or `unary operator expected` | Unquoted variable, or no space before `]` |
| A broken symlink reports `missing` | `-e` is tested before `-L` |
| `exit=0` even with a missing path | No `exit "$status"` at the end |
| Usage message missing from the script output | It went to stdout: add `>&2` |
| Checker reports "expected ... output ''" | The usage branch is printing to stdout instead of stderr, or exiting 0 |

## What to remember

- `$#` first, then `$1`.
- `"$@"` when passing arguments on; `"$path"` everywhere else.
- Test `-L` before `-e` when a link must be recognised as a link.
- A script's exit status is the last command's, unless you say otherwise.
- `bash -n` after every edit, `bash -x` when confused.
