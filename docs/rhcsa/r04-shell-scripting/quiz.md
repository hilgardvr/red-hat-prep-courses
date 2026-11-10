# R4 knowledge check

Answer first, then open the answer. If you miss a question, return to the matching section of the [theory page](index.md).

### 1. The shebang

A script starts with `#!/bin/bash`. What reads that line, and what happens if the file has no execute bit?

??? question "Answer"
    The **kernel** reads the first two bytes. `#!` tells it to run `/bin/bash` and pass the script's path as an argument. The execute bit is checked by the kernel as part of running the file, so without it `./script.sh` fails with `Permission denied` — but `bash script.sh` still works, because then bash opens the file itself and the shebang is just a comment.

### 2. Exit status

What does this script return to its caller, and why?

```bash
#!/bin/bash
ls /etc/hostname
echo "done"
```

??? question "Answer"
    `0`. A script's status is the status of its **last** command, and `echo` succeeds. The failing `ls` status was overwritten and nobody looked at it. If the failure matters, end with `exit 1` in the error branch, or use `set -e`.

### 3. The missing space

Explain why `[ -f "$file"]` fails, and what the error means.

??? question "Answer"
    `[` is a command, and its last argument must be `]` on its own. `"$file"]` is one word, so `[` never sees the closing bracket and prints `[: missing \`]'`. The same family of errors — `unary operator expected`, `too many arguments` — comes from unquoted variables and from missing spaces around the operator.

### 4. `-e` before `-L`

A symlink named `old` points at a file that has been deleted. What do `[ -e old ]` and `[ -L old ]` return, and why does the order matter in a script?

??? question "Answer"
    `[ -e old ]` is false, because `-e` follows the link and the target does not exist. `[ -L old ]` is true, because the link itself exists. A script that tests `-e` first reports the link as missing; testing `-L` first and reporting `link` is what makes the output honest.

### 5. Arguments

What is the difference between `"$@"`, `$@`, and `"$*"`?

??? question "Answer"
    `"$@"` expands to one word per argument with spaces and boundaries preserved — always use this when passing arguments on. Unquoted `$@` splits on whitespace and expands globs, so an argument containing a space becomes two. `"$*"` joins all arguments into a **single** word separated by the first character of `IFS` (a space by default).

### 6. Counting arguments

Why is `[ "$#" -eq 0 ]` better than `[ -z "$1" ]` at the top of a script?

??? question "Answer"
    `$#` counts the arguments directly, and it is safe to read even when there are none. `"$1"` is also empty when the script gets no arguments, but the check is about the wrong thing: a script called with one empty string (`""`) has `$#` = 1 and `$1` empty. `$#` also generalises: you can require exactly one argument with `[ "$#" -ne 1 ]`.

### 7. The pipeline trap

Why does this print an empty line instead of a count?

```bash
count=0
cat /etc/passwd | while read -r line; do
  count=$(( count + 1 ))
done
echo "$count"
```

??? question "Answer"
    Each side of a pipeline runs in its own subshell, so the `while` loop counts in a copy of the shell. When the loop ends, the copy exits and `count` in the parent is still 0. Redirect the file into the loop instead — `done < /etc/passwd` — or use process substitution, `done < <(cat /etc/passwd)`.

### 8. Capturing a count

What is the difference between `n=$(wc -l "$file")` and `n=$(wc -l < "$file")`?

??? question "Answer"
    The first captures `5 /path/to/file` — the count and the filename — because `wc` was given a filename argument. The second feeds the file on stdin, so `wc` has no name to print and the output is just `5`. `$(...)` strips the trailing newline, so the value is clean. The same reasoning applies to `grep -c` and most tools that print a filename when given one.

### 9. Arithmetic

What does `total=$(( total + n ))` do with `total=3` and `n=7`, and what does `$(( 7 / 2 ))` evaluate to?

??? question "Answer"
    The first assigns `10`. Variables inside `$(( ))` do not need `$`. The second is `3`: bash arithmetic is integer-only, so the remainder is discarded. For decimals you need `awk` or `bc`.

### 10. `case` and globs

What does this print for `./script.sh app.log`?

```bash
case "$1" in
  *.log) echo "log" ;;
  *)     echo "other" ;;
esac
```

??? question "Answer"
    `log`. `case` patterns are globs, not regular expressions, and `*.log` matches the whole argument. `*)` is the catch-all and must come last, because `case` uses the **first** matching branch and stops.

### 11. Testing a script

You edit a script and it now fails with `command not found` on a line that looks correct. What are the first two commands to run?

??? question "Answer"
    `bash -n script.sh` to confirm it parses, then `bash -x script.sh` (with representative arguments) to see each command **after** expansion. The trace shows what bash actually ran: an unset variable becomes an empty word, a quoted glob stays literal, and a mistyped command name appears with a `+` in front of it.

### 12. The empty glob

`/srv/empty` is an empty directory. What does this loop print, and how do you stop it?

```bash
for f in /srv/empty/*; do
  echo "file: $f"
done
```

??? question "Answer"
    It prints `file: /srv/empty/*` **once**. When a glob matches nothing, bash leaves the pattern in place as literal text — it does not expand to nothing. Guard the body with `[ -f "$f" ] || continue` (or `[ -e "$f" ] || continue`), or set `shopt -s nullglob` so an unmatched pattern expands to zero words and the loop runs zero times.
