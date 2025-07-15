snapshot_cli() {
	local subcmd="${1:-}"

	if [[ -z "$subcmd" || "$subcmd" == "--help" || "$subcmd" == "-h" ]]; then
		cat <<EOF

Usage: zman snapshot <subcommand> [options]

Subcommands:

  take     --dataset <pool/dataset> [--name <snapname>] [--date]
           → Create snapshot manually or with date-based naming

  prune    --dataset <pool/dataset> --days <N>
           → Destroy snapshots older than N days (default: 7)

  list
           → List all snapshots sorted by creation time

  destroy  <pool/dataset> <snapshot>
           → Destroy a specific snapshot

Examples:

  zman snapshot take --dataset tank/data --date
  zman snapshot take --dataset tank/data --name pre-upgrade
  zman snapshot prune --dataset tank/data --days 14
  zman snapshot list
  zman snapshot destroy tank/data snap-old

EOF
		return 0
	fi

	case "$subcmd" in
	take | create)
		local dataset="" snap_name="" use_date="false"
		shift
		while [[ $# -gt 0 ]]; do
			case "$1" in
			--dataset)
				dataset="$2"
				shift
				;;
			--name)
				snap_name="$2"
				shift
				;;
			--date) use_date="true" ;;
			*)
				log_error "Unknown snapshot take argument: $1"
				exit 1
				;;
			esac
			shift
		done

		[[ -z "$dataset" ]] && log_error "Missing --dataset" && exit 1
		[[ "$use_date" == "true" ]] && snap_name="$(date +%F)"
		[[ -z "$snap_name" ]] && log_error "Missing snapshot name (use --name or --date)" && exit 1

		log_info "Creating snapshot: ${dataset}@${snap_name}"
		zfs snapshot "${dataset}@${snap_name}"
		;;

	destroy)
		[[ $# -lt 3 ]] && log_error "Usage: zman snapshot destroy <dataset> <snapname>" && return 1
		zfs destroy "${2}@${3}"
		;;

	list)
		zfs list -t snapshot -o name,creation -s creation
		;;

	prune)
		local dataset="" days="7" pattern="auto-"
		shift
		while [[ $# -gt 0 ]]; do
			case "$1" in
			--dataset)
				dataset="$2"
				shift
				;;
			--days)
				days="$2"
				shift
				;;
			*)
				log_error "Unknown prune argument: $1"
				exit 1
				;;
			esac
			shift
		done

		[[ -z "$dataset" ]] && log_error "Missing --dataset" && exit 1

		now=$(date +%s)
		zfs list -H -t snapshot -o name,creation -s creation |
			grep "^${dataset}@" |
			while read -r snap creation; do
				[[ "$snap" != *"$pattern"* ]] && continue
				snap_time=$(date -d "$creation" +%s)
				age=$(((now - snap_time) / 86400))
				if [[ "$age" -gt "$days" ]]; then
					log_info "Destroying $snap (age $age days)"
					zfs destroy "$snap"
				fi
			done
		;;

	*)
		log_error "Unknown snapshot subcommand: $subcmd"
		return 1
		;;
	esac
}
