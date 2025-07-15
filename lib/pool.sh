pool_cli() {
	local cmd="${1:-}"
	shift || true

	if [[ -z "$cmd" || "$cmd" == "--help" || "$cmd" == "help" ]]; then
		cat <<EOF

Usage: zman pool <subcommand> [options]

Subcommands:

  status                      Show pool and device health status
  list                        List pools with usage info
  create   <pool> <devs...>   Create a new pool (interactive or direct)
  destroy  <pool>             Destroy a pool (confirmation required)
  import   [pool]             Import pools or a specific one
  export   <pool>             Export a pool (confirmation required)
  scrub    <pool>             Start or check a scrub
  clear    <pool>             Clear device/pool errors

  online   <pool> <dev>       Bring a device online
  offline  <pool> <dev>       Take a device offline
  attach   <pool> <dev1> <dev2>  Attach new dev2 to dev1 (mirroring)
  detach   <pool> <dev>       Detach device (confirmation required)
  replace  <pool> <old> <new> Replace device
  add      <pool> <args...>   Add vdevs (mirror, raidz, cache, etc.)
  remove   <pool> <dev>       Remove device/vdev (confirmation required)

Examples:

  zman pool status
  zman pool create mypool /dev/sdX /dev/sdY
  zman pool scrub mypool
  zman pool attach mypool /dev/sdX /dev/sdZ
  zman pool export mypool

EOF
		return 0
	fi

	case "$cmd" in
	status)
		zpool status "$@"
		;;
	list)
		zpool list "$@"
		;;
	create)
		[[ $# -lt 2 ]] && echo "Usage: zman pool create <pool> <dev1> [dev2...]" && return 1
		local pool="$1"
		shift
		echo "Creating pool '$pool' with devices: $*"
		zpool create "$pool" "$@"
		;;
	destroy)
		[[ -z "$1" ]] && echo "Usage: zman pool destroy <pool>" && return 1
		read -rp "Are you sure you want to destroy pool '$1'? (yes/no): " confirm
		[[ "$confirm" == "yes" ]] && zpool destroy "$1" || echo "Aborted."
		;;
	import)
		zpool import "$@"
		;;
	export)
		[[ -z "$1" ]] && echo "Usage: zman pool export <pool>" && return 1
		read -rp "Are you sure you want to export pool '$1'? (yes/no): " confirm
		[[ "$confirm" == "yes" ]] && zpool export "$1" || echo "Aborted."
		;;
	scrub)
		[[ -z "$1" ]] && echo "Usage: zman pool scrub <pool>" && return 1
		zpool scrub "$1"
		;;
	clear)
		[[ -z "$1" ]] && echo "Usage: zman pool clear <pool>" && return 1
		zpool clear "$1"
		;;
	online | offline)
		[[ $# -lt 2 ]] && echo "Usage: zman pool $cmd <pool> <device>" && return 1
		zpool "$cmd" "$1" "$2"
		;;
	attach)
		[[ $# -lt 3 ]] && echo "Usage: zman pool attach <pool> <dev1> <dev2>" && return 1
		zpool attach "$1" "$2" "$3"
		;;
	detach)
		[[ $# -lt 2 ]] && echo "Usage: zman pool detach <pool> <dev>" && return 1
		read -rp "Are you sure you want to detach device '$2' from pool '$1'? (yes/no): " confirm
		[[ "$confirm" == "yes" ]] && zpool detach "$1" "$2" || echo "Aborted."
		;;
	replace)
		[[ $# -lt 3 ]] && echo "Usage: zman pool replace <pool> <old> <new>" && return 1
		zpool replace "$1" "$2" "$3"
		;;
	add)
		[[ $# -lt 2 ]] && echo "Usage: zman pool add <pool> <vdevs...>" && return 1
		zpool add "$@"
		;;
	remove)
		[[ $# -lt 2 ]] && echo "Usage: zman pool remove <pool> <dev>" && return 1
		read -rp "Are you sure you want to remove device '$2' from pool '$1'? (yes/no): " confirm
		[[ "$confirm" == "yes" ]] && zpool remove "$1" "$2" || echo "Aborted."
		;;
	*)
		echo "Unknown pool subcommand: $cmd"
		echo "Run: zman pool --help"
		return 1
		;;
	esac
}
