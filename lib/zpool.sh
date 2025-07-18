zpool_manage_cli() {
	case "$1" in
	list) zpool list ;;
	status) zpool status ;;
	scrub) zpool scrub "$2" ;;
	clear) zpool clear "$2" ;;
	import) zpool import "$2" ;;
	export) zpool export "$2" ;;
	attach) zpool attach "$2" "$3" "$4" ;;
	detach) zpool detach "$2" "$3" ;;
	replace) zpool replace "$2" "$3" "$4" ;;
	*)
		log_error "Unknown zpool command"
		exit 1
		;;
	esac
}
