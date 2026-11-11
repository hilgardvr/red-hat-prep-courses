# F3 — Shell, commands, and the help system

<div class="module-meta" markdown>

| | |
|---|---|
| **Time** | 60–75 minutes |
| **Prerequisites** | [F1](../f1-linux-rhel-family/index.md) and a running lab from [F2](../f2-lab-first-login/index.md) |
| **Lab** | A shell and documentation walkthrough on the lab `server` |
| **Self-check** | At the end of the page |

</div>

You will type thousands of commands during the exam. Almost none of them will be commands you memorized. They will be commands you looked up, adapted, and checked.

The exam environment is a RHEL 10 system with no internet access. You cannot search the web for a flag. Everything you need is on the machine: `--help`, `man`, `info`, the documentation under `/usr/share/doc`, and the package metadata. This module teaches you to read a command, quote it correctly, and find its options without a browser.

!!! note "Read it; do not memorise it"
    This page is a reference you will come back to, not a list to learn by heart. Run a command if your lab is up and watch what changes; if it is not, read the command and the block beneath it, which shows what it prints. The exam rewards finding and adapting commands, not recalling flags.

    Command blocks have a copy button. Blocks **without** one are output, a transcript, or a syntax synopsis: they show what a command prints and are there to compare against, not to paste into a shell.

## The words this page uses

The shell has its own vocabulary. You do not need it to start, but this page leans on it. The table is the short version; the matching section below, or the module named in the last column, is the full one.

| Term | Plain meaning | Full treatment |
|---|---|---|
| **Command** | The program or instruction you ask the shell to run | [Anatomy of a command](#anatomy-of-a-command) |
| **Argument** | A word after the command that it acts on, such as a path | [Anatomy of a command](#anatomy-of-a-command) |
| **Option** (or **flag**) | A word that changes how the command behaves, usually starting with `-` | [Anatomy of a command](#anatomy-of-a-command) |
| **Variable** | A named value kept in the shell's memory. `HOME`, `PATH`, and `SHELL` are variables; `$HOME` reads one | [Quoting and expansion](#quoting-and-expansion) |
| **`PATH`** | A variable holding the directories the shell searches, in order, for a command | [Builtins, aliases, and external programs](#builtins-aliases-and-external-programs) |
| **Expansion** | The shell replacing part of the line — a variable, a pattern, or a command's output — before the program runs | [Quoting and expansion](#quoting-and-expansion) |
| **Command substitution** | Putting a command inside `$(...)` so its output becomes part of the line | [Quoting and expansion](#quoting-and-expansion) |
| **Glob** | A filename pattern such as `*.txt` that the shell expands to the matching names | [Globbing and brace expansion](#globbing-and-brace-expansion) |
| **Alias** | A shortcut name the shell expands into another command before running anything | [Builtins, aliases, and external programs](#builtins-aliases-and-external-programs) |
| **Builtin** | A command implemented inside the shell itself, such as `cd` | [Builtins, aliases, and external programs](#builtins-aliases-and-external-programs) |
| **External program** | A real file on disk that the shell starts as a child process | [Builtins, aliases, and external programs](#builtins-aliases-and-external-programs) |
| **Exit status** | The number a command returns: `0` for success, non-zero for failure | [Anatomy of a command](#anatomy-of-a-command) |
| **Loop** | Repeating the same command once for each item in a list | [R4 — Shell scripting](../../rhcsa/r04-shell-scripting/index.md); used only as an example here |

Loops are the one term with no full lesson on this page. The word-splitting examples use a one-line `for` loop because it is the clearest way to show the problem; [R4](../../rhcsa/r04-shell-scripting/index.md) teaches the syntax properly. Everything else is defined where it first appears below.

## What the shell actually does

The shell is a userspace program (F1) whose job is to read a line, transform it, and ask the kernel to run something. For every command you type, it does roughly this:

1. Read the line from your terminal.
2. Split it into words.
3. Expand aliases, variables, command substitutions, and filename patterns — in plain terms, replace a shortcut with its command, `$NAME` with its value, `$(...)` with a command's output, and `*.txt` with the files it matches.
4. Find the program in `PATH`, or recognize a shell builtin.
5. Ask the kernel to run it with `execve()`.
6. Wait for it to finish and record its **exit status**.

Steps 3 and 4 are where beginners get surprised. `echo *` is not the same as `echo '*'`, and `ls` may not be `/usr/bin/ls` at all.

Confirm what you are running:

```bash
echo $SHELL
echo $$
ps -p $$ -o pid,comm,args
```

Expected output on the lab:

```text { .no-copy }
/bin/bash
2417
    PID COMMAND         COMMAND
   2417 bash            -bash
```

`$SHELL` is the login shell recorded for your account. `$$` is the PID of the current shell. The `-bash` in the arguments means this is a login shell, which is why it read `/etc/profile` and `~/.bash_profile` when you logged in.

## Anatomy of a command

Every command line has the same three parts:

```text { .no-copy }
command [options] [arguments]
```

| Part | Example | Meaning |
|---|---|---|
| Command | `ls` | The program, builtin, alias, or function to run |
| Option (short) | `-l` | A single-letter switch, usually combinable: `-lh` |
| Option (long) | `--human-readable` | A named switch, usually one per word |
| Argument | `/etc` | What the command acts on |

Some examples:

```bash
ls -l /etc
ls -lh /etc
ls --human-readable --directory /etc
```

Programs are not consistent. `ls` accepts options after arguments; `tar` traditionally wants the archive name right after `-f`; some tools use `-n` for "dry run" and others for "numeric". That inconsistency is exactly why you need the help system rather than a memory of flags.

Three small examples of the same inconsistency.

**Options after arguments.** GNU `ls` does not care where the options go:

```bash
ls -l /etc/hostname
ls /etc/hostname -l
```

```text { .no-copy }
-rw-r--r--. 1 root root 7 Nov 10 05:43 /etc/hostname
```

The option moved; the output did not change.

`find` does care. Its paths must come **before** the expression:

```bash
find /etc -maxdepth 1 -name hostname
```

```text { .no-copy }
/etc/hostname
```

Swap them and the words stop meaning what you intended:

```bash
find -maxdepth 1 /etc -name hostname
```

```text { .no-copy }
find: paths must precede expression: `/etc'
find: possible unquoted pattern after predicate `-maxdepth'?
```

**A value belongs to one option.** `-f` takes the archive name, and the name is the next word after the whole cluster `-czf`. Run both lines in your home directory: the first creates `demo.tar.gz` there, and the second reads that same file, so it only works after the first has succeeded.

```bash
cd ~
tar -czf demo.tar.gz /etc/hostname
tar -tzf demo.tar.gz
```

```text { .no-copy }
tar: Removing leading `/' from member names
etc/hostname
```

The first line is a warning on stderr, not part of the archive; `etc/hostname` is the member it contains.

Leave the value out and `tar` stops instead of guessing:

```text { .no-copy }
tar: option requires an argument -- 'f'
Try 'tar --help' or 'tar --usage' for more information.
```

**The same letter, three meanings.** `-n` is not shorthand for anything standard. In `grep` it numbers the lines:

```bash
grep -n root /etc/passwd
```

```text { .no-copy }
1:root:x:0:0:Super User:/root:/bin/bash
10:operator:x:11:0:operator:/root:/usr/sbin/nologin
```

In `sort` it changes the comparison from text to arithmetic, which reorders the same input:

```bash
printf '10\n2\n1\n' | sort -n
```

```text { .no-copy }
1
2
10
```

```bash
printf '10\n2\n1\n' | sort
```

```text { .no-copy }
1
10
2
```

In `cp` it means "do not overwrite", and it does that silently. This creates two small files, `a` and `b`, in the current directory — your home directory, if you ran the `tar` example above. Remove them with `rm a b` when you are done:

```bash
echo one > a
echo two > b
cp -n a b
cat b
```

```text { .no-copy }
two
```

One letter, three unrelated instructions. The only reliable way to know what a flag does in a program you have not used is to read its help.

Two syntax rules are universal enough to rely on:

- **`--` ends option parsing.** Everything after it is an argument, even if it starts with a dash. The first line creates a file whose name begins with a dash; without the `--`, `rm` would read that name as options:

    ```bash
    touch -- -weird-filename
    rm -- -weird-filename
    ```

- **Exit status is a number.** `0` means success, non-zero means failure. Check it with `$?` immediately after a command:

    ```bash
    ls /etc > /dev/null
    echo $?
    ls /does-not-exist 2> /dev/null
    echo $?
    ```

    ```text { .no-copy }
    0
    2
    ```

    Exit status is how scripts make decisions. R4 builds on this.

### Builtins, aliases, and external programs

Not everything you type is a file. `type` tells you what the shell will actually do:

```bash
type cd
type ls
type -a grep
```

```text { .no-copy }
cd is a shell builtin
ls is aliased to `ls --color=auto'
grep is aliased to `grep --color=auto'
grep is /usr/bin/grep
```

Read it in order. `cd` is a **builtin**: it runs inside the shell process, because it changes the shell's own working directory, and a separate child process could not change its parent. `ls` and `grep` are **aliases**: saved expansions set by `/etc/profile.d/colorls.sh` and `colorgrep.sh`. Typing the name substitutes the stored text first, so `grep` becomes `grep --color=auto`. `type -a` then keeps searching and prints the **external program** the alias expands into, `/usr/bin/grep` — a real file on disk.

That output is the expansion order in miniature: alias first, file second.

`type -P` (capital `P`) skips aliases and builtins and prints only the file. `command -v` reports what the shell would actually run, so for an aliased name it prints the alias instead:

```bash
type -P grep
command -v grep
```

```text { .no-copy }
/usr/bin/grep
alias grep='grep --color=auto'
```

That difference matters. `command -v` answers "what happens if I type this?", while `type -P` answers "where is the file?".

The external program is found through `PATH`, the list of directories kept in a variable. It is colon-separated, searched left to right, and the first match wins:

```bash
echo "$PATH" | tr ':' '\n'
```

```text { .no-copy }
/home/labuser/.local/bin
/home/labuser/bin
/usr/local/bin
/usr/bin
/usr/local/sbin
/usr/sbin
```

That order is deliberate. `/usr/local/bin` comes before `/usr/bin`, so an administrator's own copy of a tool overrides the packaged one without replacing it. The order also explains why `type -P grep` finds `/usr/bin/grep`: no earlier directory contains a `grep`.

`command -v` is also the portable existence check for scripts:

```bash
command -v sshd
command -v nosuchcommand || echo "not installed"
```

```text { .no-copy }
/usr/sbin/sshd
not installed
```

`type` has one more answer you may meet: a **function**, a named block of commands defined inside the shell itself. This page and the labs define none, so you only need to recognize the word when `type` prints it.

## Quoting and expansion

**Expansion** is the shell rewriting your line before any program sees it: `$HOME` becomes a path, `*.txt` becomes filenames, `$(whoami)` becomes a name. Quoting decides which expansions happen.

| Form | Variables expand | Globs expand | Spaces preserved |
|---|---|---|---|
| `bare` | yes | yes | no, splits words |
| `"double"` | yes | no | yes |
| `'single'` | no | no | yes |
| `back\ slash` | no | no | yes, escapes one character |

Try it:

```bash
mkdir -p ~/f3 && cd ~/f3
touch "report final.txt" notes.txt
echo *.txt
echo "*.txt"
echo '*.txt'
```

```text { .no-copy }
notes.txt report final.txt
*.txt
*.txt
```

The first line expanded the pattern into two filenames. `echo` prints them separated by spaces, so the output alone cannot tell you where one word ends and the next begins. The quoted versions passed the literal asterisk to `echo`.

Glob results are *not* split on whitespace, which is why `*.txt` is safer than `$(ls)`. To see the argument boundaries, use `printf`:

```bash
printf '<%s>\n' *.txt
```

```text { .no-copy }
<notes.txt>
<report final.txt>
```

Two arguments, one of which contains a space. Compare that with the unquoted variable case below, where splitting really does happen.

Variables and command substitution behave the same way. A **variable** is a named value kept in the shell's memory; `$HOME` reads one. A **command substitution** runs a command and replaces `$(...)` with its output:

```bash
echo "$HOME and $(whoami)"
echo '$HOME and $(whoami)'
```

```text { .no-copy }
/home/labuser and labuser
$HOME and $(whoami)
```

Older documentation writes command substitution with backticks; prefer `$(...)` because it nests cleanly.

### Globbing and brace expansion

The shell expands filename patterns itself, before running the command:

| Pattern | Matches |
|---|---|
| `*` | Any string, including empty |
| `?` | Exactly one character |
| `[abc]` | One character from the set |
| `[a-z]` | One character from the range |
| `{a,b}` | Brace expansion, not a glob: produces `a` and `b` |

```bash
ls /etc/*.conf | head -5
ls /etc/[abc]*
echo /usr/bin/{ls,cp,mv}
```

Brace expansion happens before globbing and does not require the names to exist. That is why `mkdir -p ~/f3/{docs,logs}` works even though nothing is there yet.

### The word-splitting trap

The `for f in ...; do ...; done` form is a **loop**: bash takes each word from the list, assigns it to `f`, and runs the body once. [R4](../../rhcsa/r04-shell-scripting/index.md) teaches the syntax properly; here the loop is only a way to count the words the shell produced.

This looks reasonable and is wrong:

```bash
for f in $(ls); do echo "file: $f"; done
```

`ls` prints filenames separated by newlines. Command substitution hands that text back to the shell, which splits it on *all* whitespace, so `report final.txt` becomes two iterations. Use a glob instead:

```bash
for f in *; do echo "file: $f"; done
```

The glob produced two words — `notes.txt` and `report final.txt` — so the loop ran twice. That is the difference between the shell's own filename expansion and a program's text output.

Quoting variables is the same discipline. `name=value` stores a value in a variable; there are no spaces around the `=`, or bash reads `name` as a command. Run this in `~/f3`, where the quoting example above created the file; the second line really deletes `report final.txt`, so recreate it with `touch` if you want to repeat the example:

```bash
name="report final.txt"
rm $name        # wrong: tries to delete "report" and "final.txt"
rm "$name"      # right: one argument
```

This is not a style preference. Unquoted variables have deleted the wrong files on production systems for decades.

## Editing the command line

You do not need the arrow keys for everything. These keys work in bash and save real time during the exam.

| Key | Effect |
|---|---|
| ++tab++ | Complete a command, filename, or option |
| ++ctrl+r++ | Search history backwards; press again for older matches |
| ++ctrl+a++ / ++ctrl+e++ | Jump to start / end of the line |
| ++ctrl+u++ / ++ctrl+k++ | Delete to start / end of the line |
| ++ctrl+w++ | Delete the previous word |
| ++ctrl+l++ | Clear the screen, keeping the current line |
| ++ctrl+c++ | Cancel the current command |
| ++ctrl+z++ | Suspend the current command (F7 explains jobs) |
| ++alt+period++ | Insert the last argument of the previous command |

History expansion is worth knowing because it appears in documentation and in habits:

```bash
echo hello
!!
echo !$
```

`!!` repeats the previous command; `!$` is the last word of the previous command. `history | tail` shows numbered entries, and `!42` reruns entry 42. History lives in memory until the shell exits, then it is written to `~/.bash_history`.

## Finding help without the internet

Work down this list. The first four entries are always available on a RHEL system.

| You want | Use |
|---|---|
| A quick reminder of flags | `command --help` |
| The full reference for a command | `man command` |
| A file format such as `/etc/fstab` | `man 5 fstab` |
| A concept, when you know a keyword | `man -k keyword` or `apropos keyword` |
| A one-line description | `whatis command` |
| GNU tool documentation with examples | `info command` |
| Shipped examples and notes | `/usr/share/doc/<package>/` |
| Which files a package installed | `rpm -ql <package>` / `rpm -qd <package>` |
| Shell builtin help | `help cd` |
| Subcommand help | `dnf help install` |
| systemd unit documentation | `systemctl help sshd` |

### Man page sections

`man` is organized in numbered sections. The same name can exist in several.

| Section | Contents | Example |
|---|---|---|
| 1 | User commands | `man 1 passwd` |
| 5 | File formats and conventions | `man 5 passwd` |
| 7 | Overviews and conventions | `man 7 signal` |
| 8 | System administration commands | `man 8 mount` |

If you type `man passwd`, you get section 1, the command. If your question is about the colon-separated fields in `/etc/passwd`, you want `man 5 passwd`. `man -f passwd` lists every section that has that name.

Inside a man page:

- ++space++ pages down, ++b++ pages up, ++g++ and ++G++ jump to the start and end.
- `/pattern` searches forward, ++n++ goes to the next match, ++N++ to the previous.
- `q` quits.
- The `SEE ALSO` section at the bottom is where you find the related page you actually need.

Read the `SYNOPSIS` carefully. It is a compact grammar:

```text { .no-copy }
cp [OPTION]... [-T] SOURCE DEST
```

Bold or plain words are literal; italic or uppercase words are placeholders; `[...]` is optional; `...` means repeatable; `|` means "or". `[-T]` is a real flag, not decoration.

### When `man -k` returns nothing

`apropos` searches a database built by `mandb`. If the database is missing or stale, it finds nothing:

```bash
sudo mandb
man -k copy | head
```

On a fresh minimal system this is a common false alarm. The pages are there; the index is not.

### Documentation you can read offline

Installed packages usually carry their own documentation:

```bash
ls /usr/share/doc | head
ls /usr/share/doc/bash
rpm -qd bash | head
```

`rpm -qd` lists documentation files for an installed package, which is faster than guessing paths. When the exam gives you a tool you have never seen, this is often the only explanation available.

## Lab: drive the shell and the docs

Log in to the lab and switch to the lab user as in F2:

```bash
cd labs
./bin/lab ssh
sudo su - labuser
```

### 1. Identify your shell and your commands

```bash
echo $SHELL
echo $$
type cd
type ls
type -P grep
```

Check that `cd` reports a builtin, `ls` reports an alias, and `type -P grep` reports `/usr/bin/grep`. Then confirm the alias is only a convenience:

```bash
\ls /etc | head -3
alias ls
command -v grep
```

The backslash suppresses the alias for one command; `alias ls` shows the stored text, and `command -v grep` shows that the shell resolves the name to an alias before it looks for the file.

### 2. Prove how quoting changes the line

```bash
mkdir -p ~/f3 && cd ~/f3
touch "report final.txt" notes.txt
echo *.txt
echo "*.txt"
echo '*.txt'
echo "$HOME and $(whoami)"
echo '$HOME and $(whoami)'
printf '<%s>\n' *.txt
```

The `printf` line marks each argument with angle brackets. With the glob you should see two bracketed arguments: `notes.txt` and `report final.txt`. With `printf '<%s>\n' "*.txt"` you should see the literal pattern. The glob preserves the space; an unquoted variable would not.

### 3. Use globbing and brace expansion

```bash
ls /etc/*.conf | head -5
ls /etc/[abc]* | head -5
echo /usr/bin/{ls,cp,mv}
mkdir -p ~/f3/{docs,logs,archive}
ls -d ~/f3/*
```

Brace expansion created three directories in one command even though none existed.

The `ls /etc/[abc]*` line may also print a couple of `Permission denied` lines for `/etc/credstore` and `/etc/credstore.encrypted`. Those are directories owned by `root` with no access for other users, and `ls` reports the failure on stderr while still listing everything it can read. It is normal noise on a RHEL system, not a mistake in your command.

### 4. Reuse history

```bash
echo one
echo two
!!
echo !$
history | tail -5
```

`!!` reran `echo two`. `!$` passed `two` to `echo`, so the output is `two` again. Then press ++ctrl+r++ and type `mkdir` to search backwards.

### 5. Read a man page like an admin

```bash
man -k copy | head -8
whatis cp
man 5 passwd
```

Inside `man 5 passwd`, search for the field description:

```text { .no-copy }
/^ *root
```

You should land on the `root:x:0:0:root:/root:/bin/bash` example and be able to name each colon-separated field without leaving the page. Quit with `q`.

Now find a flag you do not remember:

```bash
man ls
```

Search for `recursive`. The entry explains `-R` and points to `--recursive`. Quit, then confirm with the short form:

```bash
ls --help | grep -- --recursive
```

### 6. Explore offline documentation

```bash
help cd
info coreutils
```

`help` prints bash's own documentation for a builtin. `info` opens the GNU manual; navigate with ++space++ and quit with `q`.

```bash
ls /usr/share/doc/bash
rpm -qd bash | head
```

### 7. Clean up

```bash
cd ~
rm -rf ~/f3
```

Note the form: a quoted, explicit path under your home directory. Never run `rm -rf` with a variable you have not checked.

## Common traps

| Trap | What happens | Fix |
|---|---|---|
| Unquoted variable with spaces | The shell splits it into several arguments | Always quote: `"$file"` |
| `echo *` when you wanted a literal | Globs expand before `echo` runs | Quote it: `'*'` |
| `cmd > file` on an input file | The shell truncates the file before the command reads it | Write to a temporary file, then move it (F5) |
| `rm -rf $DIR/` with `DIR` empty | Becomes `rm -rf /`, deleting the system | Quote and set a default: `rm -rf "${DIR:?}/"` |
| `man name` gives the wrong page | Section 1 shadows section 5 or 8 | Specify the section: `man 5 name` |
| `man -k` finds nothing | The `mandb` index is missing | `sudo mandb`, then retry |
| Alias hides real behavior | Scripts and interactive shells behave differently | Bypass it with `\ls` or `command ls`; scripts do not load aliases |
| Assuming options are portable | `-h` means human-readable in `ls`, help in others | Check `--help` before using a flag in a script |

## Self-check

Answer first, then open the answer. If you miss one, reread the matching section.

### 1. Shell versus kernel

Your shell is PID 2417 and `systemd` is PID 1. What does that tell you about the shell?

??? question "Answer"
    The shell is an ordinary userspace process started after boot, not part of the kernel and not the init system. It asks the kernel to run programs through system calls.

### 2. Builtins and aliases

`type cd` says "shell builtin", `type ls` says "aliased", and `type -P grep` gives a path. Why are these three different?

??? question "Answer"
    `cd` must change the state of the shell process itself, so it is implemented inside bash. `ls` is an alias, a saved expansion the shell substitutes before it searches for anything. `grep` is a separate program on disk; `type -P` ignores the alias and shows the file the shell would run through `PATH`.

### 3. Quoting

What is the difference between `echo "$HOME"`, `echo '$HOME'`, and `echo \$HOME`?

??? question "Answer"
    `"$HOME"` expands the variable and prints the path. `'$HOME'` prints the literal text `$HOME`. `\$HOME` escapes the dollar sign, so it also prints `$HOME` literally; the backslash applies to a single character.

### 4. Word splitting

You have a file named `report final.txt`. Why does `rm $name` fail if `name="report final.txt"`?

??? question "Answer"
    After variable expansion, the unquoted value is split on whitespace into two words, `report` and `final.txt`. `rm` receives two arguments and looks for two files that do not exist. `rm "$name"` passes one argument containing a space.

### 5. Man sections

You need to know the fields in `/etc/passwd`. Which page do you read, and how do you ask for it?

??? question "Answer"
    Section 5, the file format: `man 5 passwd`. Plain `man passwd` gives section 1, the command that changes a password.

### 6. Reading a synopsis

In `cp [OPTION]... SOURCE DEST`, what do the brackets and the ellipsis mean?

??? question "Answer"
    `[OPTION]...` means zero or more optional flags. `SOURCE` and `DEST` are required arguments. The synopsis also shows the alternative `[-T] SOURCE DEST` form, which treats the destination as a normal file rather than a directory to copy into.

### 7. History expansion

You ran `ls -l /var/log` and now want to run `less` on the same path. What is the shortest history-based command?

??? question "Answer"
    `less !$`. `!$` expands to the last word of the previous command, which is `/var/log`.

### 8. Offline help

The exam machine has no internet and you have never used `dnf repoquery`. Name two ways to find its options.

??? question "Answer"
    `dnf repoquery --help` prints the subcommand's options, and `man dnf` covers the command and its subcommands. `dnf help repoquery` also works for DNF subcommands, and `rpm -qd dnf` lists any shipped documentation.

### 9. Globbing versus quoting

You are in `/etc` and type `ls *.conf`. What does the shell pass to `ls` if five matching files exist? What if none exist?

??? question "Answer"
    With matches, the shell passes the five expanded filenames. With no matches, bash leaves the pattern unchanged and passes the literal string `*.conf`, which `ls` then reports as missing. That is why `nullglob` and `failglob` exist in scripts (R4).

## Next

Continue to [F4 — Filesystem hierarchy and file operations](../f4-filesystem-operations/index.md), where you learn where everything lives on a RHEL system and how to create, copy, move, find, and delete files safely.
