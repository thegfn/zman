dataset_cli() {
	local cmd="${1:-}"
	shift || true

	if [[ -z "$cmd" || "$cmd" == "help" || "$cmd" == "--help" ]]; then
		cat <<EOF

Usage: zman dataset <subcommand> [options]

Subcommands:

  create   <pool/dataset> [props...]         Create a new dataset
  list     [filters...]                      List datasets
  destroy  <pool/dataset|snapshot>           Destroy a dataset or snapshot (confirmation required)
  snapshot <pool/dataset> <snapname> [--recursive]  Create a snapshot (optionally recursive)
  clone    <pool/dataset@snap> <target>      Clone snapshot to new dataset
  set      <prop=value> <pool/dataset>       Set a ZFS dataset property
  get      <pool/dataset> [property...]      Get dataset properties
  mount    <pool/dataset>                    Mount a dataset
  umount   <pool/dataset>                    Unmount a dataset
  promote  <pool/clone>                      Promote a clone (confirmation required)

Examples:

  zman dataset create tank/data/compressed compression=zstd
  zman dataset snapshot tank/data daily-2025-07-14 --recursive
  zman dataset destroy tank/data/old_snap@snap1
  zman dataset set compression=zstd tank/data
  zman dataset get tank/data used available
  zman dataset promote tank/clone1

EOF
		return 0
	fi

	case "$cmd" in
	create)
		[[ -z "$1" ]] && echo "Usage: zman dataset create <pool/dataset> [props...]" && return 1
		zfs create "$@"
		;;
	list)
		zfs list "$@"
		;;
	destroy)
		[[ -z "$1" ]] && echo "Usage: zman dataset destroy <pool/dataset or snapshot>" && return 1
		read -rp "Are you sure you want to destroy '$1'? This cannot be undone. (yes/no): " confirm
		if [[ "$confirm" == "yes" ]]; then
			zfs destroy "$1"
		else
			echo "Aborted."
		fi
		;;
	snapshot)
		[[ -z "$1" || -z "$2" ]] && echo "Usage: zman dataset snapshot <pool/dataset> <snapname> [--recursive]" && return 1
		local dataset="$1"
		local snapname="$2"
		shift 2
		local flags=()
		[[ "$1" == "--recursive" ]] && flags+=("-r")
		zfs snapshot "${flags[@]}" "${dataset}@${snapname}"
		;;
	clone)
		[[ -z "$1" || -z "$2" ]] && echo "Usage: zman dataset clone <pool/dataset@snap> <new_dataset>" && return 1
		zfs clone "$1" "$2"
		;;
	set)
		[[ -z "$1" || -z "$2" ]] && echo "Usage: zman dataset set <property=value> <pool/dataset>" && return 1
		zfs set "$1" "$2"
		;;
	get)
		[[ -z "$1" ]] && echo "Usage: zman dataset get <pool/dataset> [property...]" && return 1
		zfs get "$@"
		;;
	mount)
		[[ -z "$1" ]] && echo "Usage: zman dataset mount <pool/dataset>" && return 1
		zfs mount "$1"
		;;
	umount)
		[[ -z "$1" ]] && echo "Usage: zman dataset umount <pool/dataset>" && return 1
		zfs unmount "$1"
		;;
	promote)
		[[ -z "$1" ]] && echo "Usage: zman dataset promote <pool/clone>" && return 1
		read -rp "Promote '$1' to primary? (yes/no): " confirm
		if [[ "$confirm" == "yes" ]]; then
			zfs promote "$1"
		else
			echo "Aborted."
		fi
		;;
	*)
		echo "Unknown dataset subcommand: $cmd"
		echo "Run: zman dataset --help"
		return 1
		;;
	esac
}
