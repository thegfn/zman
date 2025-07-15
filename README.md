# ZMAN - ZFS Management Toolkit

ZMAN is a modular, extensible Bash-based toolkit for managing ZFS datasets, zpools, replication, snapshotting, and health reporting across local and remote systems. It was designed to make ZFS management a little easier with additional safeguards.

---

## Features

- Modular CLI subcommands for managing datasets and zpools
- Snapshot automation with date-based naming and retention
- Incremental or full send/receive (local or remote) with `mbuffer` support
- Replication plans via config file
- Pool health, SMART, capacity, and snapshot bloat reporting
- Interactive safety confirmations for destructive actions
- Supports air-gapped backup workflows via file-based streams
- **Dry runs** can be executed on any command or subcommand to see what would have happened with `--dry-run` flag

---

## Requirements

- Bash ≥ 4.0
- ZFS utilities (e.g. `zfs`, `zpool`)
- `mbuffer` (optional, for fast pipelined send/receive)
- `smartctl` (optional, for disk health monitoring)
- SSH configured for remote replication
- GNU coreutils (e.g. `date`, `awk`, `grep`, etc.)

---

## Directory Structure

```bash
zman/
├── zman.sh # Main entrypoint script
├── README.md # This file
├── config/
│ └── default.conf # Optional default pool/dataset config
├── report/
│ └── default.conf # Health thresholds, filters
├── plans/
│ └── replication.conf # Dataset-based replication definitions
├── lib/
│ ├── dataset.sh # Dataset operations
│ ├── pool.sh # Zpool operations
│ ├── report.sh # Health and status reporting
│ ├── replicate.sh # Replication logic
│ ├── sendrecv.sh # Send/receive logic
│ ├── snapshot.sh # Snapshot lifecycle
│ ├── zfs.sh # Shared ZFS helpers
│ └── zpool.sh # Shared pool helpers
└── utils/
├── log.sh # Colored logging helpers
└── validate.sh # Input validation logic
```

---

## Installation

1. Clone the repository:

```bash
git clone https://github.com/thegfn/zman.git
cd zman
chmod +x install.sh
./install.sh
```

2. Optionally install `mbuffer` and `smartctl`

```bash
sudo apt install mbuffer smartmontools     # Debian/Ubuntu

sudo dnf install mbuffer smartmontools     # Fedora/RHEL
```

---

## Configuration

1. Set default zpool and dataset - Optional

edit `config/default.conf` and update the values within

```bash
DEFAULT_POOL="tank"
DEFAULT_DATASET="tank/data"
```

2. Modify default thresholds and reporting preferences - Optional

edit `report/defaults.conf` and modify values to your needs

```bash
[report]
capacity_warn_percent=80
snapshot_age_warn_days=90
snapshot_count_warn=100
ignore_disks=sda,sdb
ignore_pools=backup,testpool
smart_temp_warn_celsius=50
smart_realloc_warn=10
```

3. Define replication targets and policies per dataset - Optional

edit `plans/replication.conf` and enter your configuraiton

```bash
[tank/app]
target=remotehost:/zbackup/app
retain_days=14
mbuffer=true

[tank/db]
target=remotehost:/zbackup/db
retain_days=7
mbuffer=false
```

## Usage and Examples

### Manage zpools

`zman pool`

```bash
zman pool list
zman pool status
zman pool scrub tank
zman pool create tank mirror sdc sdd
zman pool destroy tank
zman pool attach tank sde sdf
zman pool detach tank sdf
zman pool replace tank sdf sdg
zman pool export tank
zman pool import tank
```

### Manage ZFS datasets

`zman dataset`

```bash
zman dataset create tank/mydata compression=zstd
zman dataset list
zman dataset destroy tank/olddata
zman dataset set quota=10G tank/mydata
zman dataset get tank/mydata
zman dataset snapshot tank/mydata daily-2025-07-14 --recursive
zman dataset clone tank/mydata@daily-2025-07-14 tank/cloned
zman dataset promote tank/cloned
```

## Manage snapshots - create, list, destroy, prune

`zman snapshot`

```bash
zman snapshot take --dataset tank/mydata --date
zman snapshot take --dataset tank/mydata --name pre-upgrade
zman snapshot list
zman snapshot destroy tank/mydata snap-old
zman snapshot prune --dataset tank/mydata --days 14
```

### Send and Receive snapshots

`zman send`

Send a snapshot to a remote host or local file

```bash
zman send --dataset tank/mydata --snapshot auto-2025-07-15 \
          --to backup@remote:/backup/data \
          --incremental-auto --mbuffer

zman send --dataset tank/mydata --snapshot auto-2025-07-15 \
          --to /mnt/usb/data.zfs --compressed
```

`zman receive`

Receive a snapshot from a remote system or local file

```bash
zman receive --dataset tank/mydata \
             --from backup@remote:/backup/data.zfs --mbuffer

zman receive --dataset tank/mydata \
             --from /mnt/usb/data.zfs
```

Send snapshot to remote host to receive from sender

```bash
zman send \
  --dataset tank/projects \
  --snapshot auto-2025-07-15 \
  --to backup@remote:/zbackup/tank/projects \
  --incremental-auto \
  --mbuffer
```

This will:

- Detect the most recent local snapshot before auto-2025-07-15
- Send incrementally from that base
- Stream with mbuffer over SSH
- Pipe directly into zfs receive on the remote

Send snapshot to local file for air-gapped receive

```bash
zman send \
  --dataset tank/secure \
  --snapshot monthly-2025-07 \
  --to /mnt/usb/monthly-secure.zfs \
  --compressed \
  --incremental-auto
```

This will:

- Use compressed send
- Automatically use the latest prior snapshot
- Write the snapshot stream to a local file
- Useful for air-gapped transfer, cold storage, DR

Receive snapshot from local file from air-gapped send

```bash
zman receive \
  --dataset tank/secure \
  --from /mnt/usb/monthly-secure.zfs
```

#### Notes

- Sender-initiated transfers allow easier orchestration from a backup scheduler (e.g. cron)
- Use of `mbuffer` is optional but recommended for large datasets or remote streams
- `--incremental-auto` simplifies scripting by automatically determining a base snapshot

## Author

Created and maintained by **theGFN**
https://github.com/thegfn
