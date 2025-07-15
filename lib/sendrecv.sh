zfs_send_cli() {
	if [[ $# -eq 0 || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
		cat <<EOF

Usage: zman send [options]

Required:
  --dataset <pool/dataset>       Dataset to send
  --snapshot <snapshot_name>     Snapshot to send
  --to <user@host:target | /path/to/file.zfs>
                                 Destination dataset or local file

Optional:
  --incremental <snapname>       Send incrementally from specified snapshot
  --incremental-auto             Auto-detect most recent earlier snapshot
  --compressed                   Use 'zfs send -c'
  --resume-token-file <file>     Use resume token (not yet implemented)
  --mbuffer                      Use mbuffer for live streaming
  --dry-run                      Preview what would be sent

Examples:
  zman send --dataset tank/data --snapshot auto-2025-07-15 \\
            --to backup@nas:/backup/tank/data --incremental-auto --mbuffer

  zman send --dataset tank/data --snapshot auto-2025-07-15 \\
            --to /backups/data-2025-07-15.zfs --compressed

EOF
		return 0
	fi

	local dataset="" snapshot="" dest="" flags=""
	local resume_file="" use_mbuffer="false"
	local incremental_auto="false" dest_dataset=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--dataset)
			dataset="$2"
			shift
			;;
		--snapshot)
			snapshot="$2"
			shift
			;;
		--to)
			dest="$2"
			shift
			;;
		--dest-dataset)
			dest_dataset="$2"
			shift
			;;
		--incremental)
			flags="$flags -i $2"
			shift
			;;
		--incremental-auto) incremental_auto="true" ;;
		--compressed) flags="$flags -c" ;;
		--resume-token-file)
			resume_file="$2"
			shift
			;;
		--mbuffer) use_mbuffer="true" ;;
		--dry-run)
			echo "Would send $dataset@$snapshot to $dest using incremental_auto=$incremental_auto mbuffer=$use_mbuffer"
			return
			;;
		esac
		shift
	done

	[[ -z "$dataset" || -z "$snapshot" || -z "$dest" ]] && log_error "Missing required arguments" && return 1

	if [[ "$incremental_auto" == "true" ]]; then
		log_info "Determining previous local snapshot for $dataset before $snapshot"

		local base_snap=""
		local_snaps=$(zfs list -H -t snapshot -o name | grep "^$dataset@" | cut -d@ -f2 | sort)

		for snap in $local_snaps; do
			if [[ "$snap" == "$snapshot" ]]; then
				break
			fi
			base_snap="$snap"
		done

		if [[ -z "$base_snap" ]]; then
			log_warn "No prior local snapshot found; falling back to full send"
		else
			log_info "Using $base_snap as incremental base"
			flags="$flags -i $base_snap"
		fi
	fi

	if [[ "$dest" == *:* ]]; then
		local host="${dest%%:*}"
		local remote_target="${dest#*:}"

		if [[ "$use_mbuffer" == "true" ]]; then
			command -v mbuffer >/dev/null || {
				log_error "mbuffer not installed on sender"
				return 1
			}

			log_info "Sending $dataset@$snapshot to $host:$remote_target using mbuffer"
			zfs send $flags "$dataset@$snapshot" |
				mbuffer -q -s 128k -m 1G |
				ssh "$host" "mbuffer -q -s 128k -m  1G | zfs receive -v $remote_target"
		else
			log_info "Sending $dataset@$snapshot to $host:$remote_target without mbuffer"
			zfs send $flags "$dataset@$snapshot" | ssh "$host" "zfs receive -v $remote_target"
		fi
	else
		log_info "Sending $dataset@$snapshot to local file $dest"
		zfs send $flags "$dataset@$snapshot" >"$dest"
	fi
}

zfs_receive_cli() {
	if [[ $# -eq 0 || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
		cat <<EOF

Usage: zman receive [options]

Required:
  --dataset <pool/dataset>       Destination to receive into
  --from <user@host:/path | /path/to/file.zfs>
                                 Source of stream (remote file or local)

Optional:
  --mbuffer                      Use mbuffer when receiving over SSH
  --dry-run                      Preview what would be received

Examples:
  zman receive --dataset tank/data --from backup@nas:/backup/data.zfs --mbuffer

  zman receive --dataset tank/data --from /backups/data-2025-07-15.zfs

EOF
		return 0
	fi

	local dataset="" source="" use_mbuffer="false"

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--dataset)
			dataset="$2"
			shift
			;;
		--from)
			source="$2"
			shift
			;;
		--mbuffer) use_mbuffer="true" ;;
		--dry-run)
			echo "Would receive $source into $dataset using mbuffer=$use_mbuffer"
			return
			;;
		esac
		shift
	done

	[[ -z "$dataset" || -z "$source" ]] && log_error "Missing required arguments" && return 1

	if [[ "$source" == *:* ]]; then
		local host="${source%%:*}"
		local remote_file="${source#*:}"

		if [[ "$use_mbuffer" == "true" ]]; then
			command -v mbuffer >/dev/null || {
				log_error "mbuffer not installed"
				return 1
			}

			log_info "Receiving from $host:$remote_file into $dataset using mbuffer"
			ssh "$host" "mbuffer -q -s 128k -m 1G < '$remote_file'" |
				mbuffer -q -s 128k -m 1G | zfs receive -v "$dataset"
		else
			log_info "Receiving from remote $source into $dataset"
			ssh "$host" "cat '$remote_file'" | zfs receive -v "$dataset"
		fi
	else
		log_info "Receiving from local file $source into $dataset"
		zfs receive -v "$dataset" <"$source"
	fi
}
