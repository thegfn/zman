zfs_manage_cli() {
	case "$1" in
	create) zfs create "$2" ;;
	destroy) zfs destroy "$2" ;;
	set) zfs set "$2" "$3" ;;
	get) zfs get "$2" "$3" ;;
	promote) zfs promote "$2" ;;
	clone) zfs clone "$2" "$3" ;;
	mount) zfs mount "$2" ;;
	umount) zfs umount "$2" ;;
	*)
		log_error "Unknown zfs command"
		exit 1
		;;
	esac
}
