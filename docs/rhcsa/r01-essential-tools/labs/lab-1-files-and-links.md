# Lab 1 — Files and links

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R1 — Essential tools |
| **Time** | 30–45 minutes |
| **Check** | `./bin/lab check r01 lab1` |
| **Skills** | Navigation, file operations, hard links, symbolic links, `find`, `stat` |

</div>

## What you are building

```text
/srv/r1/project
├── docs
│   ├── readme.txt
│   └── notes.txt
├── src
│   └── nested
│       └── deep
├── archive
│   ├── old.txt
│   └── readme-hardlink.txt
└── readme-softlink -> docs/readme.txt
```

The point is not the tree itself. It is to see how names, inodes, and links relate, and to practice the file operations you will use in every later module.

## Before you begin

From the course repository on your host:

```bash
cd labs
./bin/lab up
./bin/lab restore clean      # or ./bin/lab snapshot clean if this is your first run
./bin/lab ssh
```

You are now logged in to `server` as `vagrant`. Switch to the lab user:

```bash
sudo su - labuser
```

The prompt changes and your home directory becomes `/home/labuser`. All remaining commands run as `labuser`.

## Step 1 — Create the workspace

```bash
sudo mkdir -p /srv/r1
sudo chown labuser:labuser /srv/r1
mkdir -p /srv/r1/project/{docs,src,archive}
cd /srv/r1/project
```

`mkdir -p` creates missing parents and does not fail if the directory already exists. The braces are expanded by the shell into three separate arguments, so one command creates three directories.

Verify:

```bash
ls -ld /srv/r1 /srv/r1/project
```

The owner and group should both be `labuser`.

## Step 2 — Create, copy, move, and delete

```bash
echo "RHCSA lab 1" > docs/readme.txt
cp docs/readme.txt docs/notes.txt
echo "second line" >> docs/notes.txt
```

`>` creates or truncates; `>>` appends. Check both files:

```bash
cat docs/readme.txt
cat docs/notes.txt
```

Now practice a move and a delete:

```bash
echo "old file" > docs/old.txt
mv docs/old.txt archive/
touch docs/delete-me.txt
rm docs/delete-me.txt
```

`mv` is also how you rename a file. `touch` creates an empty file if it does not exist, or updates its timestamp if it does. `rm` removes the directory entry.

Now edit `docs/notes.txt` with a real editor. Use `vim` (installed by the lab) or `nano` if you prefer:

```bash
vim docs/notes.txt
```

Press `i` to enter insert mode, add the line `edited in vim`, press `Esc`, then type `:wq` and press Enter. If you use `nano`, save with `Ctrl+O` and exit with `Ctrl+X`.

Verify that `old.txt` moved and `delete-me.txt` is gone:

```bash
ls -l docs archive
```

## Step 3 — Create nested directories

```bash
mkdir -p src/nested/deep
find /srv/r1/project -type d
```

`find -type d` lists directories only. You should see `src`, `src/nested`, and `src/nested/deep`.

## Step 4 — Create a hard link

```bash
ln docs/readme.txt archive/readme-hardlink.txt
```

Inspect the result:

```bash
ls -li docs/readme.txt archive/readme-hardlink.txt
stat -c '%i %h %n' docs/readme.txt archive/readme-hardlink.txt
```

Expected shape (your inode number will differ):

```text
1234567 -rw-r--r--. 2 labuser labuser 12 ... docs/readme.txt
1234567 -rw-r--r--. 2 labuser labuser 12 ... archive/readme-hardlink.txt
```

Both names show the **same inode** and a **link count of 2**. Now prove they share data:

```bash
echo "written through the hard link" >> archive/readme-hardlink.txt
cat docs/readme.txt
```

The new line appears in `docs/readme.txt` too. There is only one file; there are two names for it.

## Step 5 — Create a symbolic link

```bash
ln -s docs/readme.txt readme-softlink
ls -l readme-softlink
readlink readme-softlink
readlink -f readme-softlink
```

Expected:

```text
lrwxrwxrwx. 1 labuser labuser 15 ... readme-softlink -> docs/readme.txt
docs/readme.txt
/srv/r1/project/docs/readme.txt
```

A symbolic link is a separate file whose content is the target path. Its permissions are almost always `777` and are not used for access control; the target's permissions are what matter.

Test what happens when the target is missing, without destroying your work:

```bash
ln -s /srv/r1/project/docs/missing.txt broken-link
cat broken-link
```

You get `No such file or directory`. The link itself still exists. Remove it:

```bash
rm broken-link
```

## Step 6 — Inspect the tree

```bash
find /srv/r1/project -type f -printf '%i %n %p\n' | sort
find /srv/r1/project -samefile docs/readme.txt
file docs/readme.txt readme-softlink
stat docs/readme.txt
```

`find -samefile` is a quick way to find every hard link to a given file. `file` tells you what a path is (regular file, symlink, directory), and `stat` shows the full metadata.

## Step 7 — Verify

From the host, in the `labs/` directory:

```bash
./bin/lab check r01 lab1
```

You should see a series of `PASS` lines. If something fails, read the message, fix the item, and run the checker again.

<details>
<summary>Show the expected check output</summary>

```text
R1 Lab 1 — Files and links
  PASS  /srv/r1 exists
  PASS  /srv/r1 is owned by labuser:labuser
  PASS  directory: /srv/r1/project/docs
  PASS  directory: /srv/r1/project/src/nested/deep
  PASS  directory: /srv/r1/project/archive
  PASS  file: /srv/r1/project/docs/readme.txt
  PASS  file: /srv/r1/project/docs/notes.txt
  PASS  file: /srv/r1/project/archive/old.txt
  PASS  removed: /srv/r1/project/docs/delete-me.txt
  PASS  hard link exists: /srv/r1/project/archive/readme-hardlink.txt
  PASS  hard link shares an inode with docs/readme.txt
  PASS  hard link count is 2 for docs/readme.txt
  PASS  symlink readme-softlink -> docs/readme.txt
  PASS  readme.txt contains the lab marker
  PASS  notes.txt contains the copied content
  PASS  notes.txt contains the appended line
  PASS  notes.txt was edited in an editor
  PASS  old.txt was moved, not copied
```

</details>

## Clean up

You do not need to remove anything. The next lab builds on `/srv/r1`. If you want a clean slate, run `./bin/lab restore clean` from the host and redo the setup, but the challenge lab expects the results of Lab 2, so do not restore between Lab 2 and the challenge.

## What to remember

- A filename is a directory entry pointing to an inode.
- `ln` creates a hard link; `ln -s` creates a symbolic link.
- `ls -li` shows the inode and link count.
- `stat -c '%i %h %n'` is the script-friendly version.
- `find -samefile` finds hard links; `readlink -f` resolves a symlink.
- `>` truncates, `>>` appends, `mv` renames or moves, `rm` removes the name.
