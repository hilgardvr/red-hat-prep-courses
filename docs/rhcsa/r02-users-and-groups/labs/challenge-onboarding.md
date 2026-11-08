# Challenge — Onboarding wave 2

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R2 — Users and groups |
| **Time** | 45–60 minutes |
| **Check** | `./bin/lab check r02 challenge` |
| **Style** | Exam task: requirements only, no steps |

</div>

This is the R2 challenge. It is written the way EX200 presents work: a set of required end states, with no command walkthrough. Use the [theory page](../index.md), `man`, and your notes if you need them — but try the whole thing without a recipe first.

You can do this on the machine you used for Lab 1 and Lab 2. Nothing here depends on those labs, so you can also start from a clean snapshot and work from the theory alone.

## Scenario

A second team is joining. You must create their group and two accounts, apply an onboarding policy, give them a shared directory and a file, and allow the team to inspect one service without a password. Everything must still be true after a reboot.

## Tasks

1. Create the group `analytics` with GID `3500`.

2. Create the user `nora`:
   - UID `3501`
   - primary group `analytics`
   - comment `Nora Okafor`
   - login shell `/bin/bash`
   - home directory created at the default location

3. Create the user `tomas`:
   - UID `3502`
   - primary group `analytics`
   - comment `Tomas Berg`
   - login shell `/bin/bash`
   - home directory created at the default location

4. Set passwords for both accounts. Then lock `tomas` without deleting anything.

5. Apply password aging to both accounts:
   - maximum `45` days between password changes
   - minimum `5` days
   - warning `7` days before expiry

6. Set `nora`'s **account** expiry to `2028-06-30`.

7. Create `/srv/r2/analytics`:
   - owner `root`, group `analytics`
   - mode `0770`

8. Create `/srv/r2/analytics/plan.txt`:
   - owner `nora`, group `analytics`
   - mode `0640`
   - contains the text `wave 2`

9. Create the sudo drop-in `/etc/sudoers.d/10-r2-analytics`:
   - members of `analytics` may run `/usr/bin/systemctl status sshd` with `sudo`
   - no password prompt for that command
   - mode `0440`, owner `root:root`
   - the configuration must parse cleanly

10. Reboot `server`. After it comes back, every requirement above must still hold.

## Hints

Only if you are stuck.

<details>
<summary>Which command creates the team directory with the right group?</summary>

`install -d -o root -g analytics -m 0770 /srv/r2/analytics` creates the path with the ownership and mode in one step. `mkdir` followed by `chown` and `chmod` is equally correct.

</details>

<details>
<summary>How do I check a sudo drop-in without breaking sudo?</summary>

Write it in `/tmp`, run `visudo -cf /tmp/<file>`, then install it with `install -m 0440 -o root -g root`. Run `visudo -c` again afterwards.

</details>

<details>
<summary>The checker says tomas is not locked. What did I miss?</summary>

`usermod -L` and `passwd -l` both lock the password. Setting a password with `passwd` after locking it unlocks the account again, so the order matters: set the password first, then lock.

</details>

<details>
<summary>How do I verify aging as the checker sees it?</summary>

`LC_ALL=C chage -l nora` and read the three number lines. `LC_ALL=C` keeps the labels in English regardless of your locale.

</details>

## Verify

From the host:

```bash
./bin/lab check r02 challenge
```

The checker inspects end state with `getent`, `id`, `chage`, `passwd -S`, `stat`, `visudo`, and `sudo -l`. It does not care which commands you used.

## After the challenge

If you want a clean machine for the next module:

```bash
./bin/lab restore clean
```

Do that only after the checker passes. `restore` throws away the accounts you just built.
