# F5 — Streams, pipes, and text processing

<div class="module-meta" markdown>

| | |
|---|---|
| **Time** | 75–90 minutes |
| **Prerequisites** | [F3](../f3-shell-help/index.md) and [F4](../f4-filesystem-operations/index.md) |
| **Lab** | Redirect, pipe, and filter real system data on `server` |
| **Self-check** | At the end of the page |

</div>

Linux tools are small and do one thing. The shell is what turns them into systems: it connects the output of one command to the input of the next, sends errors somewhere else, and writes results to files.

This is the single most useful skill in the whole foundations track. Every exam task that involves reading a log, filtering a list, or writing a configuration file uses what is on this page.

## Three streams and a number

Every process starts with three open **file descriptors**:

| FD | Name | Default destination | Purpose |
|---|---|---|---|
| 0 | stdin | Your terminal keyboard | Input |
| 1 | stdout | Your terminal | Normal output |
| 2 | stderr | Your terminal | Errors and warnings |

Both stdout and stderr appear on your screen, which makes them look identical. They are not. Only stdout can be piped by default, and only stdout is captured by `$(...)`.

Separate them:

```bash
ls /etc > /dev/null
ls /does-not-exist 2> /dev/null
```

The first command succeeds silently. The second fails silently: the error message went to fd 2, which you redirected. Now run both without redirection and compare:

```bash
ls /etc | head -3
ls /does-not-exist | head -3
```

The second command still prints its error, even though its stdout is in a pipe. That is the proof that stderr is a separate stream.

`/dev/null` is a device that discards everything written to it and returns end-of-file when read. It is the standard way to silence output you do not want.

## Redirection

| Operator | Effect |
|---|---|
| `> file` | Send stdout to `file`, truncating it first |
| `>> file` | Append stdout to `file` |
| `2> file` | Send stderr to `file`, truncating |
| `2>> file` | Append stderr |
| `&> file` | Send stdout and stderr to `file` |
| `&>> file` | Append stdout and stderr |
| `< file` | Read stdin from `file` |
| `<<< "text"` | Here-string: feed a line of text to stdin |
| `<<EOF ... EOF` | Here-document: feed a block of text to stdin |
| `n> file` | Redirect fd `n` |

Examples:

```bash
mkdir -p ~/f5 && cd ~/f5
ls /etc > listing.txt
ls /does-not-exist 2> errors.txt
ls /does-not-exist &> both.txt
wc -l < /etc/services
```

`wc -l < file` counts lines without printing the filename, because `wc` never receives a filename argument; its stdin is the file.

### Order matters

`2>&1` means "make fd 2 a copy of whatever fd 1 currently points at". The shell processes redirections left to right, so the position of `2>&1` decides the result.

Correct: send both to the file.

```bash
ls /does-not-exist > out.txt 2>&1
```

1. fd 1 becomes `out.txt`.
2. fd 2 becomes a copy of fd 1, which is now `out.txt`.

Wrong: send only stdout to the file.

```bash
ls /does-not-exist 2>&1 > out.txt
```

1. fd 2 becomes a copy of fd 1, which is still the terminal.
2. fd 1 becomes `out.txt`.

The error appears on screen and `out.txt` stays empty. `&>` is shorthand for the correct order.

### Here-documents

A here-document feeds several lines to a command's stdin. It is how scripts write configuration files:

```bash
cat > ~/f5/motd.txt <<'EOF'
Welcome to the lab.
This file was written by a here-document.
EOF
cat ~/f5/motd.txt
```

Quoting the delimiter (`<<'EOF'`) prevents variable expansion inside the block, which is usually what you want for literal configuration. `<<EOF` expands variables.

### `tee`

`tee` writes its stdin to both a file and stdout. Use it when you want to see output and save it:

```bash
ls /etc | tee ~/f5/etc-list.txt | wc -l
```

By default `tee` truncates the file; `tee -a` appends.

### Truncation happens before the command runs

The shell opens and truncates the output file before it starts the program. This destroys data:

```bash
sort ~/f5/etc-list.txt > ~/f5/etc-list.txt
wc -l ~/f5/etc-list.txt
```

The file is empty. `sort` read an already-empty file. Use a temporary file and `mv`:

```bash
sort ~/f5/etc-list.txt > ~/f5/etc-list.sorted
mv ~/f5/etc-list.sorted ~/f5/etc-list.txt
```

`safe` variants such as `sort -o file file` exist for some tools, but the temporary-file pattern works everywhere.

## Pipes

A pipe connects the stdout of the left command to the stdin of the right command:

```text { .no-copy }
command1 | command2 | command3
```

```bash
ls /etc | wc -l
ls /etc | sort | head -5
cut -d: -f1 /etc/passwd | sort | head -5
```

Rules that prevent confusion:

- **Only stdout is piped.** Stderr still goes to the terminal unless you redirect it: `cmd 2>&1 | grep foo`.
- **All commands run at the same time**, not one after another. Data streams through as it is produced.
- **The pipeline's exit status is the last command's status**, unless `set -o pipefail` is set. That matters in scripts (R4).
- **A pipeline can hang** if the left command waits for input that never ends. `tail -f` is the classic case; ++ctrl+c++ stops it.

## The filter toolbox

These commands read stdin, or files named as arguments, and write a transformed result to stdout.

| Command | Does | Useful options |
|---|---|---|
| `sort` | Sort lines | `-n` numeric, `-r` reverse, `-u` unique, `-k` field, `-t` separator |
| `uniq` | Collapse adjacent duplicates | `-c` count, `-d` only duplicates, `-u` only unique |
| `wc` | Count | `-l` lines, `-w` words, `-c` bytes |
| `head` / `tail` | First or last lines | `-n N`, `tail -f` follow |
| `cut` | Select columns | `-d` delimiter, `-f` fields, `-c` characters |
| `tr` | Translate or delete characters | `tr a-z A-Z`, `tr -d ':'` |
| `grep` | Select matching lines | See below |
| `tee` | Duplicate the stream | `-a` append |

`sort` and `uniq` work as a pair: `uniq` only removes *adjacent* duplicates, so sort first.

```bash
cut -d: -f7 /etc/passwd | sort | uniq -c
```

That command counts how many accounts use each login shell, which is a realistic one-liner for an audit.

`tail -f /var/log/messages` follows a log as it grows. Use it while reproducing a problem in another terminal, then stop it with ++ctrl+c++.

## `grep`

`grep` prints lines that match a pattern. It is the most important text tool on the exam.

| Option | Effect |
|---|---|
| `-i` | Ignore case |
| `-v` | Invert: lines that do not match |
| `-n` | Prefix with line numbers |
| `-c` | Count matching lines instead of printing them |
| `-l` | Print only filenames with matches |
| `-r` | Recurse through directories |
| `-w` | Match whole words |
| `-x` | Match whole lines |
| `-E` | Extended regular expressions |
| `-F` | Fixed strings, no regex |
| `-A N` / `-B N` / `-C N` | Show N lines after / before / around |
| `--color=auto` | Highlight matches on a terminal |

```bash
grep -n 'bash$' /etc/passwd
grep -c '^#' /etc/services
grep -v '^#' /etc/services | grep -v '^$' | head -5
grep -rl '10.10.10' /etc 2>/dev/null
```

The last command lists files under `/etc` containing the lab addresses. `2>/dev/null` hides the permission errors from files you cannot read as `labuser`.

Exit status is meaningful:

| Status | Meaning |
|---|---|
| 0 | At least one line matched |
| 1 | No lines matched |
| 2 | An error occurred |

Scripts rely on this: `if grep -q pattern file; then ...` is a standard test.

## Regular expressions, the useful subset

`grep` patterns are regular expressions. There are two dialects: basic (BRE, the default) and extended (`-E`, ERE). The exam needs a working subset, not a formal language.

| Pattern | Matches | BRE | ERE |
|---|---|---|---|
| `.` | Any single character | `.` | `.` |
| `*` | Zero or more of the previous item | `*` | `*` |
| `+` | One or more | `\+` | `+` |
| `?` | Zero or one | `\?` | `?` |
| `{n,m}` | Between n and m | `\{n,m\}` | `{n,m}` |
| `[abc]` | One character from the set | same | same |
| `[^abc]` | One character not in the set | same | same |
| `^` | Start of line | same | same |
| `$` | End of line | same | same |
| `(...)` | Grouping | `\(...\)` | `(...)` |

Alternation needs a pipe character, which is also the table separator, so it gets its own line: in basic `grep` you write `a\|b`, and with `grep -E` you write `a|b`. Both match `a` or `b`.

Examples against `/etc/passwd` and `/etc/hosts`:

```bash
grep '^root' /etc/passwd
grep 'bash$' /etc/passwd
grep -E '^(root|labuser):' /etc/passwd
grep -E ':[0-9]{4}:' /etc/passwd
grep -E '^[a-z]+:' /etc/passwd | head -3
grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' /etc/hosts
```

Notes that save time:

- A dot matches any character, including a literal dot. To match a real dot, escape it: `\.` or use `-F`.
- `grep -o` prints only the matching part, not the whole line.
- Anchors are the difference between "contains `root`" and "starts with `root`". A surprising number of exam mistakes come from a missing `^`.
- Prefer `-F` when the pattern is a literal string; it avoids surprises with `.`, `[`, and `*`.
- Regex engines are greedy by default: `.*` takes as much as it can.

`sed` and `awk` go further, and R4 uses them for scripting. You do not need them to filter a log.

## Lab: filter real system data

Log in to `server` and switch to the lab user:

```bash
sudo su - labuser
mkdir -p ~/f5 && cd ~/f5
```

### 1. Redirect the two streams

```bash
ls /etc > listing.txt
ls /does-not-exist 2> errors.txt
ls /does-not-exist &> both.txt
wc -l listing.txt errors.txt both.txt
cat errors.txt
```

`errors.txt` and `both.txt` contain the same message. `listing.txt` contains only names, because the `ls` succeeded.

### 2. Prove that order matters

```bash
ls /does-not-exist 2>&1 > order.txt
ls -l order.txt
cat order.txt
```

The error appears on your terminal, and `order.txt` is empty. Now use the correct order:

```bash
ls /does-not-exist > order.txt 2>&1
cat order.txt
```

Both streams are in the file.

### 3. Destroy and recover a file

```bash
cp listing.txt survive.txt
sort survive.txt > survive.txt
wc -l survive.txt
```

The file is empty because the shell truncated it before `sort` opened it. Restore the data and use a temporary file:

```bash
ls /etc > survive.txt
sort survive.txt > survive.sorted
mv survive.sorted survive.txt
wc -l survive.txt
```

### 4. Build a pipeline

```bash
ls /etc | wc -l
ls /etc | sort | head -5
cut -d: -f7 /etc/passwd | sort | uniq -c
cut -d: -f1 /etc/passwd | sort | head -10
```

You now have a count of login shells and a sorted account list. Change `head` to `tail` to see the other end.

### 5. Filter a config file

```bash
grep -c '^#' /etc/services
grep -v '^#' /etc/services | grep -v '^$' | wc -l
grep -n '^ssh' /etc/services
grep -w 'domain' /etc/services | head -3
```

The comment lines are documentation; the third command finds the SSH port assignment. Use `-w` when a short word would otherwise match inside longer words.

### 6. Use regular expressions

```bash
grep -E '^(root|labuser):' /etc/passwd
grep -E ':[0-9]{4}:' /etc/passwd
grep -E '^[a-z]+:' /etc/passwd | head -3
grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' /etc/hosts
grep -rl '10.10.10' /etc 2>/dev/null
```

The `-o` command extracts the IP addresses. The last command names files under `/etc` that mention the lab network.

### 7. Save while you watch

```bash
ping -c 3 10.10.10.11 | tee ping.txt | tail -2
cat ping.txt | tail -3
```

`tee` wrote the full output to `ping.txt` while `tail` showed you the last two lines.

### 8. Silence what you do not need

```bash
command -v nosuchtool 2>/dev/null || echo "not installed"
grep -q '^labuser:' /etc/passwd && echo "labuser exists"
```

Both lines use exit status rather than parsing output, which is how scripts should test conditions.

### 9. Clean up

```bash
cd ~
rm -rf ~/f5
```

## Common traps

| Trap | What happens | Fix |
|---|---|---|
| `cmd > file` where `file` is also an input | The file is truncated before the command reads it | Write to a temporary file, then `mv` |
| `cmd 2>&1 > file` | stderr still goes to the terminal | Use `> file 2>&1` or `&>` |
| `stderr` disappears into a pipe | Only stdout is piped | Add `2>&1` before the pipe |
| `grep` with an unanchored pattern | Matches substrings you did not want | Anchor with `^` and `$`, or use `-w` |
| Unescaped `.` in a pattern | Matches any character, including the separator | Escape it, or use `-F` |
| `sort` without `uniq` | Duplicate lines are counted separately | Sort, then pipe to `uniq -c` |
| `uniq` without `sort` | Only adjacent duplicates collapse | Sort first |
| `cut -d' '` on aligned output | Multiple spaces produce empty fields | Use `awk`, or squeeze spaces with `tr -s ' '` |
| Locale-dependent sorting | Ranges and order differ between systems | Set `LC_ALL=C` when exact byte order matters |
| `grep` on a binary file | Prints "binary file matches" instead of lines | Use `-a` or `-I`, or search the right file |

## Self-check

Answer first, then open the answer.

### 1. Two streams

Why does `ls /does-not-exist | head -3` still print an error?

??? question "Answer"
    The pipe connects only stdout to `head`. The error is written to stderr, which is still attached to your terminal.

### 2. Redirection order

Explain the difference between `cmd > out 2>&1` and `cmd 2>&1 > out`.

??? question "Answer"
    In the first, stdout goes to `out` and then stderr is duplicated from stdout, so both go to `out`. In the second, stderr is duplicated from the terminal first, then stdout goes to `out`, so errors stay on the terminal.

### 3. Truncation

Why does `sort file > file` leave you with an empty file?

??? question "Answer"
    The shell truncates `file` when it opens it for writing, before `sort` starts. `sort` then reads an empty file and writes nothing. Use a temporary file and move it into place.

### 4. `tee`

What does `ls | tee list.txt | wc -l` do that `ls > list.txt` does not?

??? question "Answer"
    `tee` writes the stream to `list.txt` *and* passes it to `wc -l`, so you see the count on screen while the file is saved. A plain redirect would send the output only to the file, leaving `wc` with nothing.

### 5. `grep` exit status

A script runs `grep -q '^labuser:' /etc/passwd`. What status does it get when the user exists, and when it does not?

??? question "Answer"
    Zero when a matching line is found, and one when nothing matches. Status two would mean an error, such as an unreadable file or a bad pattern.

### 6. Anchors

What is the difference between `grep root /etc/passwd` and `grep '^root' /etc/passwd`?

??? question "Answer"
    The first matches any line containing `root`, including `/root` in a shell field or `root` inside another word. The second matches only lines that begin with `root`.

### 7. Regex dialect

How do you write "one or more digits" in basic `grep`, and in `grep -E`?

??? question "Answer"
    Basic: `[0-9]\+`. Extended: `[0-9]+`. Without `-E`, a bare `+` is a literal plus sign.

### 8. `sort` and `uniq`

Why does `cut -d: -f7 /etc/passwd | uniq -c` give a misleading count, while adding `sort` fixes it?

??? question "Answer"
    `uniq` only collapses adjacent identical lines. Identical shells may be separated by other entries, so they are counted separately. Sorting groups them together first.

### 9. Pipeline status

A pipeline `grep pattern file | head -1` prints nothing. How do you find out whether `grep` failed or simply found no match?

??? question "Answer"
    Check `${PIPESTATUS[0]}` in bash (or run the commands separately). The pipeline's `$?` reflects `head`, which succeeds even when `grep` finds nothing. In scripts, `set -o pipefail` makes the pipeline fail if any command fails.

## Next

Continue to [F6 — Users, permissions, and ownership](../f6-users-permissions/index.md), where you learn to predict who can read, write, or traverse a file before you test it.
