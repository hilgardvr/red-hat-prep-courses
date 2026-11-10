# Lab 2 — Loops and command substitution

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R4 — Shell scripting |
| **Time** | 60–75 minutes |
| **Check** | `./bin/lab check r04 lab2` |
| **Skills** | `for` over a glob, `continue`, `$(...)`, `wc -l`, `basename`, `$(( ))`, `case` |

</div>

## What you are building

| Item | End state |
|---|---|
| `/srv/r4/bin/linereport` | An executable script that counts the lines in each regular file of a directory |
| `/srv/r4/logs` | Three log files, a subdirectory, and a broken symlink, so the loop has something to skip |
| Output | One `name count` line per regular file, then `total <sum>` |
| Exit codes | `2` for wrong usage, `0` otherwise |

Where Lab 1 looped over arguments, this lab loops over **files**, captures the output of commands, and does arithmetic on what it captured. That is the combination most administrative scripts are made of.

This lab continues on the machine you used for [Lab 1](lab-1-classify.md). If you restored the clean snapshot, create `/srv/r4/bin` first with `mkdir -p /srv/r4/bin`.

## Step 1 — Build a directory worth reporting on

```bash
mkdir -p /srv/r4/logs/build
printf 'one\ntwo\nthree\nfour\nfive\n' > /srv/r4/logs/app.log
printf 'disk full\nretry\n'            > /srv/r4/logs/error.log
printf 'boot\nlogin\nlogout\n'         > /srv/r4/logs/system.log
ln -s archived.log /srv/r4/logs/oldest
ls -l /srv/r4/logs
wc -l /srv/r4/logs/*.log
```

```text
total 12
-rw-r--r--. 1 root root 24 Nov 10 05:57 app.log
drwxr-xr-x. 2 root root  6 Nov 10 05:57 build
-rw-r--r--. 1 root root 16 Nov 10 05:57 error.log
lrwxrwxrwx. 1 root root 12 Nov 10 05:57 oldest -> archived.log
-rw-r--r--. 1 root root 18 Nov 10 05:57 system.log
 5 /srv/r4/logs/app.log
 2 /srv/r4/logs/error.log
 3 /srv/r4/logs/system.log
10 total
```

The directory contains everything a loop can trip over: regular files, a subdirectory, and a symlink to a file that does not exist. The goal is a report that lists the three files and ignores everything else.

## Step 2 — `wc -l` without the filename

`wc -l file` prints the count **and** the filename:

```bash
wc -l /srv/r4/logs/app.log
```

```text
5 /srv/r4/logs/app.log
```

Feed the file on stdin instead and `wc` has no name to print:

```bash
wc -l < /srv/r4/logs/app.log
```

```text
5
```

That is the form to capture, because the number is then the only thing in the output:

```bash
n=$(wc -l < /srv/r4/logs/app.log)
echo "count=[$n]"
```

```text
count=[5]
```

The brackets prove there is no stray space or newline in the value. `$(...)` removes trailing newlines, which is why `[5]` and not `[5\n]`.

## Step 3 — Write the loop

```bash
cat > /srv/r4/bin/linereport <<'EOF'
#!/bin/bash
# linereport — count the lines in every regular file of a directory.
# usage: linereport DIRECTORY

if [ "$#" -ne 1 ] || [ ! -d "$1" ]; then
  echo "usage: $0 DIRECTORY" >&2
  exit 2
fi

dir=$1
total=0

for f in "$dir"/*; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  n=$(wc -l < "$f")
  echo "$name $n"
  total=$(( total + n ))
done

echo "total $total"
EOF
chmod +x /srv/r4/bin/linereport
bash -n /srv/r4/bin/linereport
/srv/r4/bin/linereport /srv/r4/logs
```

```text
app.log 5
error.log 2
system.log 3
total 10
```

Four techniques are doing the work:

| Line | Technique |
|---|---|
| `for f in "$dir"/*` | A glob. The shell expands it to one word per entry **before** the loop starts, with spaces preserved because it is quoted. |
| `[ -f "$f" ] \|\| continue` | Skips the subdirectory and the broken link without wrapping the rest of the body in an `if`. |
| `name=$(basename "$f")` | Command substitution: `basename` prints `app.log`, and that becomes the value. |
| `n=$(wc -l < "$f")` | Command substitution around a redirection: the count, and nothing else. |
| `total=$(( total + n ))` | Arithmetic. Inside `$(( ))` variables need no `$`. |
| `echo "$name $n"` | Renders the report. Quoting keeps a filename with spaces on one line. |

Two details that are easy to miss:

- The **order** of the lines is the glob's order, which is alphabetical on the lab. `ls` sorts the same way by default, so the output looks sorted; a shell that sorts differently would produce a different order, and the total would still be right.
- `"$dir"/*` does **not** match hidden files. `for f in "$dir"/* "$dir"/.*` would, at the cost of also matching `.` and `..`. If hidden files matter, `find` is the better tool.

## Step 4 — Prove the skips work

The report listed three files out of five entries. Show that the subdirectory and the broken link were skipped, and not silently counted as zero:

```bash
for f in /srv/r4/logs/*; do
  printf '%s\t-d:%s\t-f:%s\n' "$f" "$([ -d "$f" ] && echo yes || echo no)" "$([ -f "$f" ] && echo yes || echo no)"
done
```

```text
/srv/r4/logs/app.log	-d:no	-f:yes
/srv/r4/logs/build	-d:yes	-f:no
/srv/r4/logs/error.log	-d:no	-f:yes
/srv/r4/logs/oldest	-d:no	-f:no
/srv/r4/logs/system.log	-d:no	-f:yes
```

`oldest` is neither a directory nor a file: `-d` and `-f` both follow the symlink, which goes nowhere. Only `-L` would call it a link. The `continue` guard drops exactly those two entries.

## Step 5 — Test the error paths and the empty directory

A report on a directory that does not exist should say so, not print `total 0`:

```bash
/srv/r4/bin/linereport; echo "exit=$?"
/srv/r4/bin/linereport /srv/r4/logs/app.log; echo "exit=$?"
/srv/r4/bin/linereport /srv/r4/nothing; echo "exit=$?"
```

```text
usage: /srv/r4/bin/linereport DIRECTORY
exit=2
usage: /srv/r4/bin/linereport DIRECTORY
exit=2
usage: /srv/r4/bin/linereport DIRECTORY
exit=2
```

One `if` covers all three: the argument count must be exactly one **and** that argument must be a directory. Now the genuinely empty case:

```bash
mkdir /srv/r4/empty
/srv/r4/bin/linereport /srv/r4/empty; echo "exit=$?"
```

```text
total 0
exit=0
```

No files is not an error. The loop body never runs, `total` keeps its initial value, and the total line still prints.

A file with nothing in it is different from a file that is not there:

```bash
: > /srv/r4/logs/empty.log
/srv/r4/bin/linereport /srv/r4/logs
rm /srv/r4/logs/empty.log
```

```text
app.log 5
empty.log 0
error.log 2
system.log 3
total 10
```

`empty.log` is a regular file, so `-f` accepts it and `wc -l` reports 0. It appears in the report and adds nothing to the total.

## Step 6 — Reboot and prove persistence

```bash
reboot
```

From the host:

```bash
cd labs
./bin/lab ssh
sudo -i
/srv/r4/bin/linereport /srv/r4/logs
echo "exit=$?"
```

The same four lines and `exit=0`: the script and its data are both files on disk.

## Step 7 — Run the checker

```bash
./bin/lab check r04 lab2
```

The checker builds its own directory with different filenames (including one empty file, one subdirectory, and one broken link), runs your script against it, and compares the report and the total.

<details>
<summary>Show the expected check output</summary>

```text
R4 Lab 2 — Loops and command substitution
  PASS  script exists: /srv/r4/bin/linereport
  PASS  the script is executable
  PASS  the script parses: bash -n
  PASS  the script starts with a bash shebang
  PASS  no arguments exits 2
  PASS  the usage message goes to stderr
  PASS  a file argument is rejected with exit 2
  PASS  one line per regular file with its line count
  PASS  a file with no lines counts as 0
  PASS  the total line adds the counts
  PASS  a subdirectory is skipped
  PASS  a broken symlink is skipped
  PASS  an empty directory reports total 0
```

</details>

## If something fails

| Symptom | Cause |
|---|---|
| Report includes the directory name, or a `0` for it | `[ -f "$f" ] \|\| continue` is missing or unquoted |
| `a.log 5 /path/a.log` | `wc -l "$f"` instead of `wc -l < "$f"` |
| Total is wrong by the number of files | `total=$(( total + 1 ))` instead of adding `$n` |
| `total` printed as `total 0` for a good directory | The counter is set inside the loop but the total is printed before it, or the loop runs in a subshell |
| Works by hand, empty under the checker | The script hardcodes `/srv/r4/logs` instead of using `$1` |
| `[: too many arguments` | Unquoted `$f` or `$1` |

## What to remember

- `for f in "$dir"/*` expands before the loop; guard the body with `[ -f "$f" ] || continue`.
- `$(...)` captures stdout only, and strips trailing newlines.
- `wc -l < file` gives you a number; `wc -l file` gives you a number and a name.
- `$(( ))` for counters; `-eq`/`-lt` for comparing them.
- Validate `$#` **and** the argument itself before looping over it.
