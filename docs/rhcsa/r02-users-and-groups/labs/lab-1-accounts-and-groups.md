# Lab 1 — Accounts and groups

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R2 — Users and groups |
| **Time** | 30–45 minutes |
| **Check** | `./bin/lab check r02 lab1` |
| **Skills** | `groupadd`, `useradd`, `usermod`, `userdel`, system accounts, orphaned files |

</div>

## What you are building

```text
group developers   GID 3001
group operators    GID 3002

user devon      UID 3001, primary developers, supplementary operators
user mira       UID auto, primary developers
user buildbot   system account, no login shell, home in /var/lib
user contractor created, then deleted, with the home directory left behind

/srv/r2/team
├── handover.txt   devon:developers  0640   rescued from the deleted user
└── notes.txt      mira:developers   0640
```

A small team, one service account, and one offboarding. That is most of objective group 9.

## Before you begin

This module changes real accounts on `server`. Start from the clean snapshot:

```bash
cd labs
./bin/lab up
./bin/lab restore clean
./bin/lab ssh
```

You land as `vagrant`. Account management needs root, and the exam has you working as root, so become root for the whole lab:

```bash
sudo -i
```

The prompt changes to `[root@server ~]#`.

!!! warning "Work as root, and expect no undo"
    There is no confirmation prompt for `userdel`. If a step goes wrong, `./bin/lab restore clean` throws the machine away and you start over. That is the correct recovery, and it is fast.

## Step 1 — Create the groups

```bash
groupadd -g 3001 developers
groupadd -g 3002 operators
getent group developers operators
```

Expected:

```text
developers:x:3001:
operators:x:3002:
```

The member list is empty because nobody has been added yet, and a user's primary group never appears here.

Check the GIDs landed where you asked:

```bash
getent group developers | cut -d: -f3     # 3001
```

`-g` pins the GID. Without it, `groupadd` takes the next free number, which is fine for daily work but makes an exam answer unpredictable.

## Step 2 — Onboard devon

```bash
useradd -u 3001 -g developers -G operators \
        -c "Devon Rivera" -s /bin/bash -m devon
```

Read that as one decision per line:

| Flag | Decision |
|---|---|
| `-u 3001` | Fixed UID, so file ownership is predictable |
| `-g developers` | Primary group; new files get group `developers` |
| `-G operators` | Supplementary membership; access to operator-owned files |
| `-c "Devon Rivera"` | Full name, shown by `finger`, mail clients, and `ls` in some tools |
| `-s /bin/bash` | Login shell |
| `-m` | Create `/home/devon` and copy `/etc/skel` into it |

Verify:

```bash
id devon
getent passwd devon
ls -ld /home/devon
ls -A /home/devon
```

Expected shape:

```text
uid=3001(devon) gid=3001(developers) groups=3001(developers),3002(operators)
devon:x:3001:3001:Devon Rivera:/home/devon:/bin/bash
drwx------. 2 devon developers 62 ... /home/devon
.bash_logout  .bash_profile  .bashrc
```

The home directory mode comes from `HOME_MODE` in `/etc/login.defs`. Your value may be `700` or `755`; the owner and group are what matter here.

Note that no password was set. `getent shadow devon` shows `!!` in the hash field, which means "locked, no password". Lab 2 fixes that.

## Step 3 — Onboard mira without pinning a UID

```bash
useradd -g developers -c "Mira Chen" -s /bin/bash -m mira
id mira
getent passwd mira
```

Expected:

```text
uid=1002(mira) gid=3001(developers) groups=3001(developers)
mira:x:1002:3001:Mira Chen:/home/mira:/bin/bash
```

Your UID will be whatever came next in the `1000–60000` range — the lab's existing accounts take `1000` and `1001`. Leave it unpinned: an exam task only asks for a specific UID when it gives you one.

Note that mira's GID is `3001`, the same number as devon's. They share the group; they do not share the UID.

## Step 4 — Add an existing user to a group, and see the `-a` trap

First, prove the trap on a throwaway account:

```bash
useradd -m -G developers tempuser
id tempuser
```

```text
uid=1003(tempuser) gid=1003(tempuser) groups=1003(tempuser),3001(developers)
```

Now replace the list instead of adding to it:

```bash
usermod -G operators tempuser
id tempuser
```

```text
uid=1003(tempuser) gid=1003(tempuser) groups=1003(tempuser),3002(operators)
```

`developers` is gone. `-G` means "this is the complete list now". Remove the test account and do it properly:

```bash
userdel -r tempuser
usermod -aG operators labuser
id labuser
```

```text
uid=1000(labuser) gid=1000(labuser) groups=1000(labuser),10(wheel),3002(operators)
```

`-aG` appended `operators` and left `wheel` alone. That is the difference between keeping and losing your own `sudo` access.

!!! note "When membership takes effect"
    `id labuser` reads the group database, so it shows the new group immediately. A shell that `labuser` already had open does not — group membership is captured when the session starts. Log out and back in, or use `su - labuser`, to get a session that sees the new group.

## Step 5 — A service account

```bash
useradd -r -m -d /var/lib/buildbot -s /sbin/nologin \
        -c "Build service" buildbot
id buildbot
getent passwd buildbot
ls -ld /var/lib/buildbot
```

Expected shape:

```text
uid=997(buildbot) gid=995(buildbot) groups=995(buildbot)
buildbot:x:997:995:Build service:/var/lib/buildbot:/sbin/nologin
drwx------. 2 buildbot buildbot 6 ... /var/lib/buildbot
```

Three things to notice:

- The UID is below `1000`, because `-r` asks for a system number.
- The shell is `/sbin/nologin`. Try `su - buildbot` and the login is refused with "This account is currently not available."
- `-m` was required. `useradd -r` does **not** create a home directory by default, even though `CREATE_HOME` is enabled for ordinary accounts.

`-r` also writes no aging values into `/etc/shadow`, since a service account never changes its own password.

## Step 6 — Offboard the contractor

Create the account and give it a file:

```bash
useradd -m -s /bin/bash -c "Contractor" contractor
echo "handover: rotate the API keys" > /home/contractor/handover.txt
chown contractor:contractor /home/contractor/handover.txt
ls -ld /home/contractor
ls -l /home/contractor
```

Now delete the account the plain way:

```bash
userdel contractor
getent passwd contractor
ls -ld /home/contractor
ls -l /home/contractor
```

`getent` prints nothing — the account is gone from `/etc/passwd`. But the home directory is still there, and now its owner is a number:

```text
drwx------. 2 1003 1002 4096 ... /home/contractor
-rw-r--r--. 1 1003 1002   32 ... handover.txt
```

Those numbers are the deleted UID and GID. The files are intact; there is simply no name left to show. This is what "delete the user, keep the files" looks like, and it is why you check for orphaned files before recreating an account with a recycled UID.

## Step 7 — Rescue the file into the team directory

```bash
mkdir -p /srv/r2/team
cp /home/contractor/handover.txt /srv/r2/team/handover.txt
chown devon:developers /srv/r2/team/handover.txt
chmod 640 /srv/r2/team/handover.txt
rm -rf /home/contractor
```

Read the file back as a member of the owning group:

```bash
sudo -u devon cat /srv/r2/team/handover.txt
```

That works: `devon` is in `developers`, the group has read permission, and the file is `640`.

Now try the same as a user who is not in the group:

```bash
sudo -u labuser cat /srv/r2/team/handover.txt
```

Permission denied. `labuser` is in `wheel` and `operators`, not `developers`, so "other" applies — and "other" has no permission at all.

## Step 8 — A second file with a different owner

```bash
echo "ldap migration pending" > /srv/r2/team/notes.txt
chown mira:developers /srv/r2/team/notes.txt
chmod 640 /srv/r2/team/notes.txt
```

Both team members can read both files, because ownership is per file and access comes from the group. `devon` owns one file, `mira` owns the other, and neither needs to be the other's owner.

## Step 9 — Verify the whole picture

```bash
getent group developers operators
getent passwd devon mira buildbot
id devon
ls -l /srv/r2/team
```

Expected:

```text
developers:x:3001:labuser
operators:x:3002:devon,labuser
devon:x:3001:3001:Devon Rivera:/home/devon:/bin/bash
mira:x:1002:3001:Mira Chen:/home/mira:/bin/bash
buildbot:x:997:995:Build service:/var/lib/buildbot:/sbin/nologin
uid=3001(devon) gid=3001(developers) groups=3001(developers),3002(operators)
-rw-r-----. 1 devon developers 32 ... handover.txt
-rw-r-----. 1 mira  developers 21 ... notes.txt
```

Notice `developers` lists `labuser` but not `devon` or `mira`: they are in it as their primary group, so they do not appear in the member list.

## Step 10 — Run the checker

From the host, in `labs/`:

```bash
./bin/lab check r02 lab1
```

<details>
<summary>Show the expected check output</summary>

```text
R2 Lab 1 — Accounts and groups
  PASS  group developers has GID 3001
  PASS  group operators has GID 3002
  PASS  user devon exists
  PASS  devon has UID 3001
  PASS  devon's primary group is developers
  PASS  devon's shell is /bin/bash
  PASS  devon's home directory is /home/devon
  PASS  devon's comment contains 'Devon'
  PASS  devon is a member of operators
  PASS  /home/devon exists and belongs to devon
  PASS  user mira exists
  PASS  mira's primary group is developers
  PASS  mira's shell is /bin/bash
  PASS  mira's comment contains 'Mira'
  PASS  mira is not a member of operators
  PASS  user buildbot exists as a system account
  PASS  buildbot's shell is /sbin/nologin
  PASS  buildbot's home directory exists
  PASS  buildbot's home is owned by buildbot
  PASS  deleted user contractor has no account
  PASS  labuser is a member of operators
  PASS  /srv/r2/team/handover.txt is mode 640
  PASS  /srv/r2/team/handover.txt is owned by devon:developers
  PASS  handover.txt kept the contractor's content
  PASS  /srv/r2/team/notes.txt is mode 640
  PASS  /srv/r2/team/notes.txt is owned by mira:developers
  PASS  notes.txt has the expected content
```

</details>

If a line fails, fix that one item and run the checker again. The checker reads end state, so it does not care whether you used `usermod` or `gpasswd`.

## What to remember

- `-g` sets the primary group; `-G` sets supplementary groups; `-aG` adds to them.
- `useradd -r` makes a system account and does not create a home directory unless you add `-m`.
- `userdel` keeps the home directory; `userdel -r` removes it. Both leave files elsewhere alone.
- A deleted UID stays on the files as a number until you `chown` it.
- `/etc/group` lists supplementary members only. Use `id` to see everyone.
- Group membership applies to new sessions, not to shells that were already open.
