# R4 cheat sheet

A compact reference for review. Everything here is explained in the [theory page](index.md).

## Skeleton

```bash
#!/bin/bash
# name — what it does.
# usage: name ARG

if [ "$#" -ne 1 ]; then
  echo "usage: $0 ARG" >&2
  exit 2
fi

# ... work ...

exit 0
```

| Task | Command |
|---|---|
| Make it runnable | `chmod +x script.sh` |
| Check syntax | `bash -n script.sh` |
| Trace execution | `bash -x script.sh` |
| Run without the execute bit | `bash script.sh` |
| Run in the current shell | `source script.sh` |

## Exit codes

| Value | Meaning |
|---|---|
| `0` | Success |
| `1` | Failure, or "no" |
| `2` | Bad usage |
| `126` | Not executable |
| `127` | Command not found |

`$?` holds the previous status. A script returns its **last** command's status unless it calls `exit`. `if`, `while`, `&&`, `||` test the status directly.

```bash
set -euo pipefail     # fail fast, error on unset variables, fail on any pipe stage
```

## Tests

| File | True when |
|---|---|
| `-e p` | Exists (follows links) |
| `-f p` | Regular file |
| `-d p` | Directory |
| `-L p` | Symlink, **even broken** |
| `-s p` | Exists and not empty |
| `-r` `-w` `-x p` | Readable / writable / executable |
| `-b` `-c` | Block / character device |

| String | True when |
|---|---|
| `-z "$s"` | Empty |
| `-n "$s"` | Not empty |
| `"$a" = "$b"` | Equal (`!=` for not equal) |

| Integer | | |
|---|---|---|
| `-eq` `-ne` | `-lt` `-le` | `-gt` `-ge` |

| `[ ]` | `[[ ]]` |
|---|---|
| Needs quoting | No splitting |
| No `&&`, `\|\|`, `!` inside | Allows them |
| No pattern matching | `[[ $f = *.log ]]`, `[[ $s =~ regex ]]` |

Spaces around every bracket and operator are mandatory. `-L` before `-e` when a link must be recognised.

## Arguments

| Variable | Contains |
|---|---|
| `$0` | How the script was invoked |
| `$1`…`$9`, `${10}` | Positional arguments |
| `$#` | Argument count |
| `"$@"` | All arguments, boundaries preserved |
| `"$*"` | All arguments joined into one word |
| `${1:-default}` | `$1` or a default |
| `${1:?message}` | Exit with a message if unset |
| `shift` | Drop `$1`, renumber the rest |

```bash
for arg in "$@"; do echo "$arg"; done
while [ "$#" -gt 0 ]; do echo "$1"; shift; done
```

## Conditionals

```bash
if [ -d "$1" ]; then
  echo "dir"
elif [ -f "$1" ]; then
  echo "file"
else
  echo "other"
fi
```

```bash
case "$1" in
  start|up)  echo "starting" ;;
  *.log)     echo "log file" ;;
  *)         echo "usage: $0 start|stop" >&2; exit 2 ;;
esac
```

```bash
mkdir -p /srv/x && echo ok                 # only if the first succeeded
[ -f "$1" ] || { echo "missing" >&2; exit 1; }
```

## Loops

```bash
for name in alpha beta; do echo "$name"; done
for path in "$@"; do echo "$path"; done
for f in "$dir"/*; do [ -f "$f" ] || continue; echo "$f"; done

while IFS= read -r line; do
  echo "$line"
done < /etc/hostname          # counters survive; `cat file | while` loses them

for (( i = 0; i < 3; i++ )); do echo "$i"; done
```

| Statement | Effect |
|---|---|
| `continue` | Skip to the next iteration |
| `break` | Leave the loop |
| `done < file` | Feed the loop, keep its variables |
| `done < <(cmd)` | Process substitution, same benefit |

## Command substitution and arithmetic

```bash
today=$(date +%F)
n=$(wc -l < "$file")          # number only
name=$(basename "$f")
count=$(find "$dir" -maxdepth 1 -type f | wc -l)
total=$(( total + n ))
```

| Form | Use |
|---|---|
| `$(...)` | Capture stdout, trailing newlines removed |
| `$(<file)` | Read a file without `cat` |
| `$(( ... ))` | Integer arithmetic, variables need no `$` |
| `(( i++ ))` | Arithmetic as a command; fails when the result is 0 |

## Debugging

| Symptom | Cause |
|---|---|
| `[: =: unary operator expected` | Unquoted variable |
| `[: too many arguments` | Unquoted filename with a space |
| `Usage` branch taken unexpectedly | Compare `$#`, not `$1` |
| Counter always 0 | Loop ran in a pipeline subshell |
| `Permission denied` | No execute bit |
| Everything prints literally | Heredoc written with `<<'EOF'` when expansion was wanted |
| Script behaves differently after reboot | It relied on the working directory or a shell variable |

```bash
bash -n script.sh                 # parse only
bash -x script.sh arg             # trace after expansion
printf '%q\n' "$var"              # show spaces and special characters
echo "DEBUG: x=[$x]"              # brackets reveal an empty value
```
