pool_cli() {
  local cmd="${1:-}"
  shift || true

  if [[ -z "$cmd" || "$cmd" == "--help" || "$cmd" == "help" ]]; then
    cat <<EOF

Usage: zman pool <subcommand> [options]

Subcommands:

  list                                List all pools
  status                              Show status of all pools
  create   <pool> <devs...>           Create a pool
  destroy  <pool>                     Destroy a pool (confirmation required)
  import   <pool>                     Import a pool
  export   <pool>                     Export a pool
  scrub    <pool>                     Start scrub
  clear    <pool>                     Clear errors
  attach   <pool> <dev1> <dev2>       Attach device
  detach   <pool> <dev>               Detach device
  replace  <pool> <olddev> <newdev>   Replace device
  add      <pool> <vdev_type> <devs>  Add vdevs to pool
  remove   <pool> <dev>               Remove vdev
  online   <pool> <dev>               Bring device online
  offline  <pool> <dev>               Take device offline

Add --dry-run to simulate any destructive/altering operation.

Examples:
  zman pool create testpool /dev/sdX
  zman pool destroy testpool
  zman pool attach testpool sda sdb --dry-run
  zman pool replace testpool sdc sdd

EOF
    return 0
  fi

  case "$cmd" in
    list)
      zpool list
      ;;
    status)
      zpool status
      ;;
    create)
      local pool="" dry_run="false"
      local devs=()
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --dry-run) dry_run="true" ;;
          *) [[ -z "$pool" ]] && pool="$1" || devs+=("$1") ;;
        esac
        shift
      done
      [[ -z "$pool" || ${#devs[@]} -eq 0 ]] && echo "Usage: zman pool create <pool> <devs...> [--dry-run]" && return 1
      if [[ "$dry_run" == "true" ]]; then
        log_info "Would create pool '$pool' with devices: ${devs[*]}"
      else
        zpool create "$pool" "${devs[@]}"
      fi
      ;;
    destroy)
      local pool="" dry_run="false"
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --dry-run) dry_run="true" ;;
          *) pool="$1" ;;
        esac
        shift
      done
      [[ -z "$pool" ]] && echo "Usage: zman pool destroy <pool> [--dry-run]" && return 1
      if [[ "$dry_run" == "true" ]]; then
        log_info "Would destroy pool '$pool'"
      else
        read -rp "Are you sure you want to destroy pool '$pool'? This cannot be undone. (yes/no): " confirm
        [[ "$confirm" == "yes" ]] && zpool destroy "$pool" || echo "Aborted."
      fi
      ;;
    import|export|scrub|clear)
      local pool="" dry_run="false"
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --dry-run) dry_run="true" ;;
          *) pool="$1" ;;
        esac
        shift
      done
      [[ -z "$pool" ]] && echo "Usage: zman pool $cmd <pool> [--dry-run]" && return 1
      if [[ "$dry_run" == "true" ]]; then
        log_info "Would $cmd pool '$pool'"
      else
        zpool "$cmd" "$pool"
      fi
      ;;
    attach|replace)
      local pool="" dev1="" dev2="" dry_run="false"
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --dry-run) dry_run="true" ;;
          *) 
            [[ -z "$pool" ]] && pool="$1" ||
            [[ -z "$dev1" ]] && dev1="$1" ||
            dev2="$1"
            ;;
        esac
        shift
      done
      [[ -z "$pool" || -z "$dev1" || -z "$dev2" ]] && echo "Usage: zman pool $cmd <pool> <olddev> <newdev> [--dry-run]" && return 1
      if [[ "$dry_run" == "true" ]]; then
        log_info "Would $cmd device $dev1 with $dev2 in pool $pool"
      else
        zpool "$cmd" "$pool" "$dev1" "$dev2"
      fi
      ;;
    detach|remove)
      local pool="" dev="" dry_run="false"
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --dry-run) dry_run="true" ;;
          *) [[ -z "$pool" ]] && pool="$1" || dev="$1" ;;
        esac
        shift
      done
      [[ -z "$pool" || -z "$dev" ]] && echo "Usage: zman pool $cmd <pool> <dev> [--dry-run]" && return 1
      if [[ "$dry_run" == "true" ]]; then
        log_info "Would $cmd device $dev from pool $pool"
      else
        zpool "$cmd" "$pool" "$dev"
      fi
      ;;
    add)
      local pool="" vdev_type="" dry_run="false"
      local devs=()
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --dry-run) dry_run="true" ;;
          *)
            if [[ -z "$pool" ]]; then pool="$1"
            elif [[ -z "$vdev_type" ]]; then vdev_type="$1"
            else devs+=("$1")
            fi
            ;;
        esac
        shift
      done
      [[ -z "$pool" || -z "$vdev_type" || ${#devs[@]} -eq 0 ]] && echo "Usage: zman pool add <pool> <vdev_type> <devs...> [--dry-run]" && return 1
      if [[ "$dry_run" == "true" ]]; then
        log_info "Would add $vdev_type vdev with ${devs[*]} to pool $pool"
      else
        zpool add "$pool" "$vdev_type" "${devs[@]}"
      fi
      ;;
    online|offline)
      local pool="" dev="" dry_run="false"
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --dry-run) dry_run="true" ;;
          *) [[ -z "$pool" ]] && pool="$1" || dev="$1" ;;
        esac
        shift
      done
      [[ -z "$pool" || -z "$dev" ]] && echo "Usage: zman pool $cmd <pool> <dev> [--dry-run]" && return 1
      if [[ "$dry_run" == "true" ]]; then
        log_info "Would bring $cmd device $dev in pool $pool"
      else
        zpool "$cmd" "$pool" "$dev"
      fi
      ;;
    *)
      echo "Unknown pool subcommand: $cmd"
      echo "Run: zman pool --help"
      return 1
      ;;
  esac
}
