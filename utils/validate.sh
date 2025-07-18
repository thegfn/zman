validate_dataset() {
  zfs list "$1" &>/dev/null || { log_error "Dataset '$1' not found"; exit 1; }
}
validate_pool() {
  zpool list "$1" &>/dev/null || { log_error "Pool '$1' not found"; exit 1; }
}
