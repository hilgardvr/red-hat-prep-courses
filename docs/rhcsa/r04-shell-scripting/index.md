# R4 — Shell scripting

<div class="module-meta" markdown>

| | |
|---|---|
| **Exam objective group** | 3 — Create simple shell scripts |
| **Time** | 3–4 hours including labs |
| **Prerequisites** | [R1 — Essential tools](../r01-essential-tools/index.md), especially [Streams and pipes](../r01-essential-tools/index.md#streams-redirection-and-pipes) and [Permissions](../r01-essential-tools/index.md#permissions) |
| **Labs** | 2 guided labs + 1 challenge |
| **Check command** | `./bin/lab check r04 lab1` (also `lab2` and `challenge`) |

</div>

You have been typing commands one at a time. A **shell script** is those same commands written into a file, plus the decisions and repetition that make them useful: run this only if that is true, do it once for every file, stop and report an error.

The exam objective is deliberately modest — *simple* scripts. It asks for four things: conditionals, loops, arguments, and command substitution. Everything in this module is one of those four ideas applied to a real administrative task.

Scripts matter out of proportion to their size. A ten-line script that checks every home directory on a machine does in a second what would take ten minutes by hand, and does it the same way on the next forty machines.

## Objective checklist

By the end of this module you should be able to:

- [ ] Write a script with a shebang, make it executable, and run it
- [ ] Make a script decide something with `if` and `[ ]`, and with `case`
- [ ] Loop over command-line arguments, over files, and over the lines of a file
- [ ] Read `$1`, `$#`, and `$@`, and validate them before using them
- [ ] Capture the output of a command with `$(...)` and do arithmetic on it
- [ ] Exit with a meaningful status code, and explain what `$?` means
- [ ] Prove that the scripts still work after a reboot

---

## What a script is

A script is a text file that the shell reads and executes. Three things make it a program rather than notes:

1. a **shebang** on the first line, which names the interpreter
2. the **execute permission**
3. a **location** where you can call it by name

```bash
#!/bin/bash
# hello.sh — print a greeting.
# The line above is the shebang: it must be the very first line of the file.
echo "hello from $0"
```

```text { .no-copy }
$ chmod +x hello.sh
$ ./hello.sh
hello from ./hello.sh
```

`$0` is the name the script was invoked with. `./hello.sh` and `/srv/r4/bin/hello.sh` print different values, which is useful in usage messages.

### Why the shebang matters

The kernel reads the first two bytes of the file. `#!` means "run the program named next, and pass it this file". So `#!/bin/bash` makes the script a bash program even if your interactive shell is something else.

- `#!/bin/bash` runs bash from a fixed path.
- `#!/usr/bin/env bash` finds bash through `PATH`, which is more portable but one more thing that can fail.
- No shebang: the kernel may treat the file as a shell script for the *current* shell, which is why a script without one can behave differently depending on who runs it.

The exam machine has bash. Use `#!/bin/bash` and be done with it.

### Running a script

| Command | What happens |
|---|---|
| `./script.sh` | The kernel runs it with the shebang's interpreter. Needs the execute bit. |
| `/srv/r4/bin/script.sh` | Same, by absolute path. |
| `bash script.sh` | bash reads the file directly. Ignores the execute bit and the shebang. |
| `source script.sh` or `. script.sh` | Runs in **your current shell**, so variables and `cd` persist. Not how you run a program. |
| `bash -n script.sh` | Parses without running. The first thing to do after editing. |
| `bash -x script.sh` | Prints every command after expansion, prefixed with `+`. The first thing to do when it misbehaves. |

!!! warning "`PATH` does not include the current directory"
    `script.sh` on its own fails with `command not found`, because `.` is not in `PATH` — a safety feature. Write `./script.sh`, or put the script in a directory that is in `PATH`, such as `/usr/local/bin`.

## Exit codes

Every command returns a number to the shell, and the shell stores it in `$?`. **Zero means success.** Anything else means some kind of failure, and the specific number is up to the program.

```bash
ls /etc/hostname; echo "exit=$?"
ls /etc/nope;     echo "exit=$?"
```

```text { .no-copy }
/etc/hostname
exit=0
ls: cannot access '/etc/nope': No such file or directory
exit=2
```

A script's exit status is the status of its **last command**, unless you say otherwise:

```bash
exit 3
```

Conventions you will meet, and should use:

| Code | Meaning |
|---|---|
| `0` | Success |
| `1` | Generic failure, or "the answer is no" |
| `2` | Bad usage — wrong number of arguments |
| `126` | Found but not executable |
| `127` | Command not found |
| `130` | Killed by Ctrl-C |

This is why `if` needs no comparison operator. It does not test truth, it tests **success**:

```bash
if grep -q '^root:' /etc/passwd; then
  echo "root is in passwd"
fi
```

`grep -q` prints nothing and succeeds only if it matched. That is the idiom the whole language is built on.

### `set -euo pipefail`

The top of a careful script often looks like this:

```bash
#!/bin/bash
set -euo pipefail
```

| Part | Effect |
|---|---|
| `-e` | Exit when a command fails |
| `-u` | Treat an unset variable as an error |
| `-o pipefail` | A pipeline fails if **any** stage fails, not just the last |

They turn silent mistakes into visible failures. They also surprise beginners: `-e` does not fire inside an `if`, a `while`, or a `&&` chain, because there a failure is information, not a crash. Use them once your script is working, and understand why a line stopped running before you blame the script.

## Testing conditions

`[` is a command. It is the same program as `test`, spelled with a closing bracket for looks. That explains its two most common errors: **the spaces are mandatory**, and the closing `]` must be its own argument.

```bash
[ -f /etc/passwd ]     # true
[ -f /etc/passwd]      # error: missing ]
[-f /etc/passwd ]      # error: command "[-f" not found
```

On success `[` returns 0. On failure it returns 1. So it composes with `if`, `&&`, `||`, and `$?` like any other command.

### File tests

| Test | True when |
|---|---|
| `-e path` | The path exists (following symlinks) |
| `-f path` | It exists and is a regular file |
| `-d path` | It exists and is a directory |
| `-L path` | It is a symbolic link, **even a broken one** |
| `-s path` | It exists and is not empty |
| `-r` / `-w` / `-x path` | You may read / write / execute it |
| `-b` / `-c` | Block / character device |
| `-p` | Named pipe |
| `-S` | Socket |
| `f1 -nt f2` | `f1` is newer than `f2` |

`-e` follows symlinks; `-L` does not. A link pointing at a file that has been deleted therefore fails `-e` and passes `-L`. **Test in the order that matches what you mean** — usually `-L` first:

```bash
if [ -L "$path" ]; then
  echo "link"
elif [ -e "$path" ]; then
  echo "exists"
else
  echo "missing"
fi
```

### String tests

| Test | True when |
|---|---|
| `-z "$s"` | The string is empty |
| `-n "$s"` | The string is non-empty |
| `"$a" = "$b"` | Equal (use `!=` for not equal) |
| `"$a" < "$b"` | Sorts before, **inside `[[ ]]` only** |

Always quote the variables. `[ "$x" = "y" ]` with an empty `x` becomes `[ "" = "y" ]`, which is valid. Unquoted, it becomes `[ = y ]`, which is a syntax error — and if `x` contains a space or a `*`, the shell splits or expands it into more arguments.

### Integer tests

| Test | Meaning |
|---|---|
| `-eq` / `-ne` | equal / not equal |
| `-lt` / `-le` | less than / less or equal |
| `-gt` / `-ge` | greater than / greater or equal |

`=` compares strings; `-eq` compares numbers. `[ "10" = "10" ]` is true, `[ "10" -eq 10 ]` is true, and `[ "010" -eq 10 ]` is true while `[ "010" = 10 ]` is false. Pick the operator that matches your data.

### `[ ]` and `[[ ]]`

| | `[ ]` (POSIX `test`) | `[[ ]]` (bash keyword) |
|---|---|---|
| Word splitting of variables | Yes — quoting is essential | No |
| Glob patterns on the right of `=` | No | Yes: `[[ $f = *.log ]]` |
| `&&`, `\|\|`, `!` inside the brackets | No | Yes |
| Regex match | No | `[[ $s =~ ^[0-9]+$ ]]` |

`[[ ]]` is easier to get right in bash. The rest of this course uses `[ ]` because every shell supports it and because the exam's scripts are simple, but you will see `[[ ]]` in real scripts and it is not wrong.

## Conditionals

### `if`, `elif`, `else`

```bash
if [ -d "$1" ]; then
  echo "directory"
elif [ -f "$1" ]; then
  echo "file"
else
  echo "something else"
fi
```

The `then` keyword is required. `fi` closes the block. Indentation is for humans — bash ignores it — but unindented scripts are unreadable after a week.

### `case`

`case` compares one value against several patterns. It is cleaner than five `elif`s and it supports globs:

```bash
case "$1" in
  start|up)     echo "starting" ;;
  stop|down)    echo "stopping" ;;
  status)       echo "checking" ;;
  *.log)        echo "a log file" ;;
  *)            echo "usage: $0 start|stop|status" >&2
                exit 2 ;;
esac
```

Each branch ends with `;;`. `*)` is the catch-all and belongs last. The pattern `*.log` is a glob, not a regular expression.

### `&&` and `||`

```bash
mkdir -p /srv/r4 && echo "ready"          # second command only if the first succeeded
[ -f "$1" ] || { echo "missing: $1" >&2; exit 1; }
```

`&&` and `||` test exit status, exactly like `if`. The braces group several commands so the whole group is the right-hand side; the spaces inside `{ ... }` are mandatory.

!!! tip "Write error messages to stderr"
    `echo "usage: ..." >&2` keeps the message out of the script's normal output, so a caller can capture the real result with `$(...)` without collecting complaints. This is a convention the exam does not test and every administrator depends on.

## Arguments

A script sees its command line as numbered variables.

| Variable | Contains |
|---|---|
| `$0` | The name the script was invoked with |
| `$1` … `$9` | The first nine arguments; `${10}` onwards needs braces |
| `$#` | How many arguments there were |
| `$@` | All of them, as separate words |
| `$*` | All of them as one word, joined by the first `IFS` character |
| `$?` | The exit status of the previous command |
| `$$` | This shell's process id |

The difference between `"$@"` and `"$*"` matters the moment an argument contains a space:

```bash
#!/bin/bash
printf 'at: [%s]\n' "$@"
printf 'star: [%s]\n' "$*"
```

```text { .no-copy }
$ ./args.sh "two words" three
at: [two words]
at: [three]
star: [two words three]
```

`"$@"` keeps the original boundaries, which is what you want when passing arguments on. **Quote it.** Unquoted `$@` splits and globs like any other unquoted variable.

### Validating arguments before using them

Reading `$1` without checking `$#` is the most common way a script fails in front of a user:

```bash
if [ "$#" -ne 1 ]; then
  echo "usage: $0 DIRECTORY" >&2
  exit 2
fi

dir=$1
```

Defaults and required values:

| Form | Result |
|---|---|
| `${1:-default}` | `$1` if set and non-empty, otherwise `default` |
| `${1-default}` | `$1` if set (even empty), otherwise `default` |
| `${1:?DIRECTORY is required}` | Exits with that message if `$1` is unset or empty |

`shift` throws away `$1` and renumbers the rest, which is how a script walks its arguments one at a time:

```bash
while [ "$#" -gt 0 ]; do
  echo "argument: $1"
  shift
done
```

For simple scripts, `for arg in "$@"` is clearer.

## Loops

### `for` over a list

```bash
for name in alpha beta gamma; do
  echo "host: $name"
done
```

### `for` over arguments

```bash
for path in "$@"; do
  echo "checking $path"
done
```

### `for` over files

```bash
for f in /srv/r4/logs/*; do
  [ -f "$f" ] || continue      # skip directories and broken links
  echo "file: $f"
done
```

The glob is expanded by the shell **before** the loop starts. If nothing matches, the pattern stays as literal text (`/srv/r4/logs/*`), which is why the `[ -f ]` guard is there. Set `shopt -s nullglob` if you would rather the loop run zero times.

Do not write `for f in $(ls)`. Filenames with spaces break it, and `ls` output is for humans. Use a glob.

### `while read` over the lines of a file

```bash
while IFS= read -r line; do
  echo "line: $line"
done < /etc/hostname
```

- `IFS=` stops leading and trailing whitespace from being stripped.
- `-r` stops backslashes from being interpreted.
- `done < file` redirects the file into the **loop**, so the loop body runs in the current shell and its variables survive.

That last point is a classic trap:

```bash
count=0
grep -c . /etc/passwd | while read -r n; do count=$n; done
echo "$count"      # empty: the pipeline ran the loop in a subshell
```

Anything on the right of a `|` runs in a subshell. Assignments inside it are lost when it exits. Redirect the file into the loop instead, or use process substitution (`done < <(command)`) when you need the output of a command.

### `break` and `continue`

`break` leaves the loop. `continue` skips to the next iteration. Both are used constantly to keep a loop body flat:

```bash
for f in "$dir"/*; do
  [ -f "$f" ] || continue      # not a file: skip it
  [ -s "$f" ] || continue      # empty: skip it
  echo "processing $f"
done
```

### Counting

```bash
total=0
for n in 3 5 2; do
  total=$(( total + n ))
done
echo "$total"      # 10
```

`$(( ))` does integer arithmetic. Bash has no floating point; if you need decimals, use `awk` or `bc`.

## Command substitution

`$(command)` runs the command and replaces itself with its **standard output**, with trailing newlines removed.

```bash
today=$(date +%F)
lines=$(wc -l < /etc/services)
name=$(basename /srv/r4/logs/app.log)
echo "$today $lines $name"
```

```text { .no-copy }
2026-11-10 17873 app.log
```

Rules that save time:

- Use `$(...)`, not backticks. It nests: `$(dirname "$(readlink -f "$0")")`.
- Quote the result when you use it: `echo "$lines"`, not `echo $lines`.
- Only **stdout** is captured. Errors still go to the terminal, which is usually what you want.
- The exit status of the substitution is the status of the command inside, but `local x=$(false)` and `x=$(false)` inside an assignment both return the status of the **assignment**, not the command. Check the command separately when it matters.
- `$(<file)` is a bash shortcut for `$(cat file)`.

A loop plus command substitution is the workhorse of administrative scripting:

```bash
for home in /home/*; do
  [ -d "$home" ] || continue
  files=$(find "$home" -maxdepth 1 -type f | wc -l)
  echo "$home $files"
done
```

## Arithmetic

| Form | Use |
|---|---|
| `$(( 2 + 3 ))` | Substitute the result: `echo $(( 2 + 3 ))` prints `5` |
| `(( i++ ))` | Run as a command; its exit status is 0 when the result is non-zero |
| `$(( total + n ))` | Variables inside `$(( ))` need no `$` |

Operators are the usual ones: `+ - * / % **`, comparisons that produce 1 or 0, and bitwise operators. Division is integer division: `$(( 7 / 2 ))` is `3`.

Careful with `(( i++ ))`: when `i` is 0 the result is 0, so the command "fails" under `set -e`. Prefer `i=$(( i + 1 ))` in scripts that use `set -e`.

## Debugging a script

| Tool | What it tells you |
|---|---|
| `bash -n script.sh` | Whether it parses at all. Run it after every edit. |
| `bash -x script.sh` | Every command as bash actually ran it, after expansion |
| `set -x` / `set +x` | Turn tracing on and off around a suspicious block |
| `echo "DEBUG: x=[$x]"` | The variable's value with its boundaries visible |
| `printf '%q\n' "$var"` | The value quoted so spaces and special characters show |
| `shellcheck script.sh` | A linter that catches quoting, `[ ]`, and portability mistakes |

Brackets around the value in a debug line are not decoration: `DEBUG: x=[]` proves the variable is empty, while `DEBUG: x=[ ]` proves it contains a space.

## Traps worth memorising

| Trap | Symptom | Fix |
|---|---|---|
| `[ $x = y ]` with empty `x` | `[: =: unary operator expected` | `[ "$x" = y ]` |
| `[ -f $file ]` with a space in the name | `[: too many arguments` | `[ -f "$file" ]` |
| `for f in $(ls)` | Breaks on spaces; hides dotfiles | `for f in "$dir"/*` |
| `cat file \| while read` | Counters and variables are lost | `while read ... done < file` |
| `read line` | Backslashes eaten, whitespace trimmed | `IFS= read -r line` |
| `$1` without checking `$#` | Empty path, script acts on `/` or `""` | Validate, then `exit 2` |
| `=` for numbers | `010` compares as a string | `-eq` for integers |
| Missing execute bit | `Permission denied` | `chmod +x` |
| `cd` failing silently | Later commands run in the wrong directory | `cd "$dir" \|\| exit 1` |
| `echo "$var"` with a leading `-` | `echo` treats it as an option | `printf '%s\n' "$value"` |

## What survives a reboot

Scripts are files. Everything about them persists:

| Thing | Persists? | Because |
|---|---|---|
| The script file and its contents | Yes | It is a file on disk |
| The execute bit | Yes | It is file metadata |
| A script in `/usr/local/bin` | Yes | That directory is in the default `PATH` |
| Variables set in a shell | No | They live in that shell's memory |
| An alias | No | Unless written to a startup file |

The persistence test for this module is therefore simple and easy to forget: **run the checker again after a reboot**. A script that only works because of a file you created in `~`, a variable you exported, or a directory you `cd`-ed into will fail it.

## How the checker works

The R4 checker does not look for particular commands. It **runs your scripts** with inputs it creates itself, and compares their output and exit codes with what the lab specified.

That has two consequences worth knowing before you start:

- A script that hardcodes the answers from the lab fails, because the checker uses different names, different paths, and different line counts.
- An error message is never a failure by itself. Only the output and the exit code are judged, though the checker shows what it expected next to what it got.

Run it from the host:

```bash
./bin/lab check r04 lab1
```

## Next

[Lab 1 — Arguments, tests, and exit codes](labs/lab-1-classify.md) builds the first script, then [Lab 2 — Loops and command substitution](labs/lab-2-linereport.md) adds repetition and captured output. The [challenge](labs/challenge-account-audit.md) combines all four objectives into one exam-style task.
