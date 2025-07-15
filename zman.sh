#!/bin/bash
# ZMAN - ZFS Management Toolkit
# Author: Justin K Long
# https://github.com/thegfn
# Created: 2025-07-14
# Description: Modular CLI for managing ZFS

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils/log.sh"
source "$SCRIPT_DIR/lib/zfs.sh"
source "$SCRIPT_DIR/lib/zpool.sh"
source "$SCRIPT_DIR/lib/snapshot.sh"
source "$SCRIPT_DIR/lib/sendrecv.sh"
source "$SCRIPT_DIR/lib/replicate.sh"
source "$SCRIPT_DIR/lib/dataset.sh"
source "$SCRIPT_DIR/lib/pool.sh"
source "$SCRIPT_DIR/lib/report.sh"

print_usage() {
	cat <<EOF

ZMAN - ZFS Management Toolkit

Usage:
  zman <command> <subcommand> [options]

Commands:

  dataset    → Manage ZFS datasets (create, destroy, snapshot, etc.)
  pool       → Manage ZFS pools (status, scrub, attach, etc.)
  report     → Reporting tools for health, SMART, capacity, snapshots

  snapshot
    take     --dataset <pool/dataset> [--name <snapname>] [--date]
             → Create a snapshot manually or with date-based naming
    prune    --dataset <pool/dataset> --days <N>
             → Prune snapshots older than N days

  send
    --dataset <pool/dataset>
    --snapshot <snapname>
    --to <user@host:pool/dataset | /path/to/file.zfs>
    [--incremental <snapname>]       → Send incrementally from given snapshot
    [--incremental-auto]             → Auto-select most recent prior snapshot
    [--compressed]                   → Use compressed send
    [--mbuffer]                      → Stream with mbuffer
    [--resume-token-file <file>]    → Use resume token from file
    [--dry-run]                      → Show what would be sent

  receive
    --dataset <pool/dataset>
    --from <user@host:/path | /path/to/file.zfs>
    [--mbuffer]                      → Use mbuffer for receive
    [--dry-run]                      → Show what would be received

  replicate
    → Run replication plan defined in plans/replication.conf
      Per-dataset config keys:
        - target = user@host:pool/dataset OR /path/to/file
        - retain_days = <N>
        - mbuffer = true|false
        - incremental_auto = true|false

Examples:

  zman snapshot take --dataset tank/data --date
  zman snapshot prune --dataset tank/data --days 7

  zman send --dataset tank/data --snapshot 2025-07-14 \\
            --to user@remote:/backup/data --incremental-auto --mbuffer

  zman receive --dataset tank/data --from /backups/incr.zfs

  zman replicate

EOF
}

# Entrypoint dispatcher
if [[ $# -eq 0 ]]; then
	print_usage
	exit 0
fi

case "$1" in
dataset)
	shift
	dataset_cli "$@"
	;;
pool)
	shift
	pool_cli "$@"
	;;
report)
	shift
	report_cli "$@"
	;;
snapshot)
	shift
	snapshot_cli "$@"
	;;
send)
	shift
	zfs_send_cli "$@"
	;;
receive)
	shift
	zfs_receive_cli "$@"
	;;
replicate)
	replicate_from_plan
	;;
help | --help | -h)
	print_usage
	;;
*)
	log_error "Unknown command: $1"
	print_usage
	exit 1
	;;
esac
