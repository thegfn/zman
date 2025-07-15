replicate_from_plan() {
	if [[ $# -eq 0 || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
		cat <<EOF

Usage: zman replicate [--help]

Description:
  Execute replication tasks based on a plan defined in: plans/replication.conf

Plan Format (per dataset):

  [tank/data]
  target = user@host:tank-backup/data
  retain_days = 7
  mbuffer = true
  incremental_auto = true

Supported Keys:
  - target             → Destination (remote dataset or local file path)
  - retain_days        → Number of days to retain snapshots
  - mbuffer            → true/false, use mbuffer streaming
  - incremental_auto   → true/false, auto-select base snapshot

Examples:

  zman replicate
  zman replicate --help

  # Sample plan entry:
  [tank/data/projects]
  target = backups@backuphost:tank/archive/projects
  retain_days = 14
  mbuffer = true
  incremental_auto = true

EOF
		return 0
	fi

	local config="plans/replication.conf"

	grep '^\[' "$config" | while read -r section; do
		dataset="${section//[\[\]]/}"

		target=$(awk -v s="[$dataset]" '$0==s {found=1; next} /^\[/{found=0} found && /target/ {print $0}' "$config" | cut -d= -f2-)
		days=$(awk -v s="[$dataset]" '$0==s {found=1; next} /^\[/{found=0} found && /retain_days/ {print $0}' "$config" | cut -d= -f2-)
		mbuffer_enabled=$(awk -v s="[$dataset]" '$0==s {found=1; next} /^\[/{found=0} found && /mbuffer/ {print $0}' "$config" | cut -d= -f2-)
		incremental_enabled=$(awk -v s="[$dataset]" '$0==s {found=1; next} /^\[/{found=0} found && /incremental_auto/ {print $0}' "$config" | cut -d= -f2-)

		mbuffer_enabled="${mbuffer_enabled,,}"
		[[ "$mbuffer_enabled" != "true" ]] && mbuffer_enabled="false"

		incremental_enabled="${incremental_enabled,,}"
		[[ "$incremental_enabled" != "true" ]] && incremental_enabled="false"

		snap_name="$(date +%F)"
		zfs snapshot "$dataset@$snap_name"

		log_info "Replicating $dataset@$snap_name to $target (mbuffer=$mbuffer_enabled, incremental_auto=$incremental_enabled)"

		cmd=("$SCRIPT_DIR/zman.sh" send
			--dataset "$dataset"
			--snapshot "$snap_name"
			--to "$target"
			--compressed
		)
		[[ "$mbuffer_enabled" == "true" ]] && cmd+=(--mbuffer)
		[[ "$incremental_enabled" == "true" ]] && cmd+=(--incremental-auto)

		"${cmd[@]}"

		log_info "Pruning old snapshots on $dataset older than $days days"
		"$SCRIPT_DIR/zman.sh" snapshot prune "$dataset" "$days"
	done
}
