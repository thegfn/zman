replicate_from_plan() {
	if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
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

EOF
		return 0
	fi
        
	local config="$SCRIPT_DIR/plans/replication.conf"
	[[ ! -f "$config" ]] && log_error "Replication plan not found: $config" && return 1

	grep '^\[' "$config" | while read -r section; do
		local dataset="${section//[\[\]]/}"

		local target days mbuffer_enabled incremental_enabled
		target=$(awk -v s="[$dataset]" '$0==s {found=1; next} /^\[/{found=0} found && /target/ {sub(/^.*= */, "", $0); print $0}' "$config")
		days=$(awk -v s="[$dataset]" '$0==s {found=1; next} /^\[/{found=0} found && /retain_days/ {sub(/^.*= */, "", $0); print $0}' "$config")
		mbuffer_enabled=$(awk -v s="[$dataset]" '$0==s {found=1; next} /^\[/{found=0} found && /mbuffer/ {sub(/^.*= */, "", $0); print tolower($0)}' "$config")
		incremental_enabled=$(awk -v s="[$dataset]" '$0==s {found=1; next} /^\[/{found=0} found && /incremental_auto/ {sub(/^.*= */, "", $0); print tolower($0)}' "$config")

		mbuffer_enabled="${mbuffer_enabled:-false}"
		incremental_enabled="${incremental_enabled:-false}"

		local snap_name
		snap_name="$(date +%F)"
		log_info "[$dataset] Creating snapshot $dataset@$snap_name"
		if ! zfs snapshot "$dataset@$snap_name"; then
			log_error "[$dataset] Snapshot creation failed"
			continue
		fi

		log_info "[$dataset] Replicating to $target (mbuffer=$mbuffer_enabled, incremental_auto=$incremental_enabled)"
		cmd=("$SCRIPT_DIR/zman.sh" send
			--dataset "$dataset"
			--snapshot "$snap_name"
			--to "$target"
			--compressed
		)
		[[ "$mbuffer_enabled" == "true" ]] && cmd+=(--mbuffer)
		[[ "$incremental_enabled" == "true" ]] && cmd+=(--incremental-auto)

		if ! "${cmd[@]}"; then
			log_error "[$dataset] Replication failed"
			continue
		fi

		if [[ -n "$days" ]]; then
			log_info "[$dataset] Pruning snapshots older than $days days"
			if ! "$SCRIPT_DIR/zman.sh" snapshot prune --dataset "$dataset" --days "$days"; then
				log_warn "[$dataset] Snapshot pruning failed"
			fi
		fi
	done
}
