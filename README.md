# ZMAN - ZFS Management Toolkit

ZMAN is a modular, extensible Bash-based toolkit for managing ZFS datasets, zpools, replication, snapshotting, and health reporting across local and remote systems. It simplifies ZFS management with additional automation, safety features, and reporting tools.

---

## 🚀 Features

- Modular CLI subcommands for managing datasets and zpools
- Snapshot creation with date-based naming and automated pruning
- Incremental or full `zfs send/receive` (local or remote) with `mbuffer` support
- Auto-detects base snapshots for incremental replication
- Plan-based replication via `plans/replication.conf`
- Pool health, SMART, capacity, and snapshot bloat reporting
- Interactive confirmations for destructive actions
- Supports air-gapped backups with file-based transfers
- **Dry runs** for previewing all destructive or transfer operations using `--dry-run`

---

## 📦 Requirements

- Bash ≥ 4.0  
- ZFS utilities (`zfs`, `zpool`)  
- `mbuffer` (optional, for streaming sends)  
- `smartctl` (optional, for SMART disk health checks)  
- SSH access for remote replication  
- GNU coreutils (`awk`, `grep`, `date`, etc.)  

---

## 📁 Directory Structure

```bash
zman/
├── zman.sh                 # Main entrypoint
├── install.sh              # Installer
├── README.md               # This file
├── config/
│   └── default.conf        # Optional default pool/dataset config
├── plans/
│   └── replication.conf    # Replication plans per dataset
├── report/
│   └── defaults.conf       # Reporting thresholds and filters
├── lib/
│   ├── dataset.sh          # Dataset operations
│   ├── pool.sh             # Zpool operations
│   ├── report.sh           # Health and status reports
│   ├── replicate.sh        # Plan-based replication
│   ├── sendrecv.sh         # Snapshot send/receive logic
│   ├── snapshot.sh         # Snapshot lifecycle management
│   ├── zfs.sh              # Common ZFS functions
│   └── zpool.sh            # Common Zpool functions
└── utils/
    ├── log.sh              # Logging helpers
    └── validate.sh         # Input validation
```

---

## 🛠 Installation

```bash
git clone https://github.com/thegfn/zman.git
cd zman
chmod +x install.sh
./install.sh
```

Optional packages:

```bash
# Debian/Ubuntu
sudo apt install mbuffer smartmontools

# Fedora/RHEL
sudo dnf install mbuffer smartmontools
```

---

## ⚙️ Configuration

### Default Pool/Dataset (optional)

Edit `config/default.conf`:

```bash
DEFAULT_POOL="tank"
DEFAULT_DATASET="tank/data"
```

### Report Thresholds (optional)

Edit `report/defaults.conf`:

```ini
# ZMAN Report Defaults
# Thresholds and ignore filters used in health/reporting module

# Pools to ignore from report checks (comma-separated)
ignore_pools =

# Disks to ignore from SMART check (comma-separated, e.g., sda,sdb)
ignore_disks =

# SMART thresholds
smart_temp_warn_celsius = 50
smart_realloc_warn = 5

# Capacity warning threshold (percentage)
capacity_warn_percent = 80

# Snapshot warnings
snapshot_age_warn_days = 30
snapshot_count_warn = 50
```

### Replication Plans (optional)

Edit `plans/replication.conf`:

```ini
[tank/app]
target = backup@remote:/zbackup/app
retain_days = 14
mbuffer = true
incremental_auto = true

[tank/db]
target = backup@remote:/zbackup/db
retain_days = 7
mbuffer = false
incremental_auto = true
```

---

## ⚡ Usage and Examples

### 🔹 Pool Management

```bash
zman pool list
zman pool status
zman pool create tank mirror sdc sdd
zman pool destroy tank
zman pool scrub tank
zman pool export tank
zman pool import tank
zman pool attach tank sde sdf
zman pool detach tank sdf
zman pool replace tank sdf sdg
```

### 🔹 Dataset Management

```bash
zman dataset list
zman dataset create tank/mydata compression=zstd
zman dataset destroy tank/olddata
zman dataset set quota=10G tank/mydata
zman dataset get tank/mydata
zman dataset snapshot tank/mydata daily-2025-07-14 --recursive
zman dataset clone tank/mydata@daily-2025-07-14 tank/cloned
zman dataset promote tank/cloned
```

### 🔹 Snapshot Management

```bash
# Take snapshot
zman snapshot take --dataset tank/mydata --date
zman snapshot take --dataset tank/mydata --name pre-upgrade

# Prune snapshots older than 30 days
zman snapshot prune --dataset tank/mydata --days 30

# Keep only the most recent 10 snapshots
zman snapshot prune --dataset tank/mydata --keep-last 10

# Dry run
zman snapshot prune --dataset tank/mydata --keep-last 5 --dry-run
```

---

## 📤 Snapshot Send/Receive

### Send (to remote host or file)

```bash
zman send --dataset tank/data --snapshot auto-2025-07-15 \
          --to backup@remote:/zbackup/data \
          --incremental-auto --mbuffer

zman send --dataset tank/data --snapshot auto-2025-07-15 \
          --to /backups/data-2025-07-15.zfs --compressed
```

### Receive (from remote host or file)

```bash
zman receive --dataset tank/data --from /backups/data-2025-07-15.zfs
zman receive --dataset tank/data --from backup@remote:/zbackup/data.zfs --mbuffer
```

---

## 🔁 Snapshot Replication Plans

Automated snapshot, send, and prune via `zman replicate`.

### Define Plan

```ini
[tank/projects]
target = backups@host:tank/archive/projects
retain_days = 14
mbuffer = true
incremental_auto = true
```

### Run Replication

```bash
zman replicate
```

ZMAN will:

- Take a new dated snapshot
- Send it (incrementally if possible)
- Prune old snapshots based on `retain_days`

---

## 📊 Reporting & Health Checks

```bash
zman report smart         # Show SMART health summary
zman report degraded      # List degraded pools or devices
zman report capacity      # Warn on near-full pools
zman report snapshots     # Detect excessive or old snapshots
zman report quota         # Report datasets violating quotas
```

---

## 🔎 Notes

- Most commands support `--dry-run` to preview actions
- Logging stored at `/var/log/zman.log`
- Safety prompts are issued for destructive actions
- Remote replication assumes SSH access with key authentication
- `mbuffer` is highly recommended for large or remote data streams

---

## 👤 Author

**theGFN**  
📦 GitHub: [https://github.com/thegfn](https://github.com/thegfn)
