# Mock exam B — Sharing and time

<div class="module-meta" markdown>

| | |
|---|---|
| **Module** | R12 — Capstone |
| **Time** | 2 hours |
| **Check** | `./bin/lab check r12 examb` |
| **Style** | Timed exam: two machines, requirements only |

</div>

!!! warning "Stop before you read on"
    Restore the clean snapshot on **both** machines, put your notes away, and start a clock. Attempt every task before you grade it.

    ```bash
    cd labs
    ./bin/lab restore clean
    ./bin/lab up
    ```

## Scenario

`server` must export a data directory to the lab network and act as the internal time source. `node2` must mount the export at boot, write to it as `labuser`, and synchronise its clock from `server`. A cron job on `server` records a heartbeat once a minute.

You will work on both machines. `./bin/lab ssh node2` opens the second one.

## Requirements

### On `server`

#### 1. Storage

Using the empty disk `/dev/vdb`:

- one GPT partition, marked as **Linux LVM**;
- volume group `examb_vg`;
- logical volume `exambexport`, **1 GiB**, **ext4**;
- mounted at `/srv/examb/export` by **UUID** in `/etc/fstab`;
- the directory owned by `labuser:labuser`;
- the whole `fstab` must pass `findmnt --verify`.

#### 2. NFS export

- export `/srv/examb/export` to `10.10.10.0/24`, read-write, with root squashing left on;
- `nfs-server` installed, **enabled**, and **active**;
- the export visible in `exportfs -v`.

#### 3. Firewall

Open the services an NFS client needs, in the `public` zone, **permanently** and in the running firewall:

- `nfs`
- `mountd`
- `rpc-bind`

Also open `ntp` in `public`, permanently and now.

#### 4. Time server

- `chronyd` must allow the lab network (`10.10.10.0/24`) to use it as a time source;
- `chronyd` enabled and active.

#### 5. Name

- static hostname `server.examb.lab`;
- `/etc/hosts` maps `10.10.10.11` to the name `exambpeer`.

#### 6. Schedule

- `/usr/local/bin/examb-heartbeat`, executable, appends a timestamped `heartbeat` line to `/srv/examb/export/heartbeat.log`;
- `/etc/cron.d/examb-heartbeat` runs it **every minute** as `labuser`;
- within two minutes the log must contain a new line.

### On `node2`

#### 7. Mount the export

- mount `10.10.10.10:/srv/examb/export` at `/mnt/examb`;
- by an `/etc/fstab` entry, so the mount survives a reboot;
- mounted now.

#### 8. Write as `labuser`

Create `/mnt/examb/from-node2.txt` as `labuser`. The file must be owned by `labuser` on the server too, which proves the export is read-write and root squashing is on.

#### 9. Time client

- point `chronyd` at `10.10.10.10` (use `iburst`);
- restart `chronyd`;
- `timedatectl show -p NTPSynchronized --value` must report `yes`.

#### 10. Resolve the server

`/etc/hosts` on `node2` maps `10.10.10.10` to `server.examb.lab`, so `getent ahostsv4 server.examb.lab` returns `10.10.10.10`.

## Grading

Both VMs must be running. From the host, after a reboot of both:

```bash
./bin/lab check r12 examb
```

The checker runs on `server`, reads the local state, and reaches `node2` as `labuser` over SSH.

## After the exam

| If you failed | Revisit |
|---|---|
| LVM, ext4, UUID, `findmnt --verify` | [R6 — Local storage](../../r06-local-storage/index.md) |
| Export, `mountd`, `rpc-bind`, root squash | [R7 — File systems and sharing](../../r07-file-systems/index.md) |
| Chrony server and client, `ntp` | [R8 — Scheduling and time](../../r08-scheduling-and-time/index.md) |
| cron and the heartbeat | [R8 — Scheduling and time](../../r08-scheduling-and-time/index.md) |
| Static hostname, `/etc/hosts` | [R9 — Networking and firewalld](../../r09-networking-and-firewall/index.md) |
| The client mount | [R7 — File systems and sharing](../../r07-file-systems/index.md) |
