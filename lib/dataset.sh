# lib/dataset.sh
dataset_cli() {
  local cmd="${1:-}"
  shift || true

  if [[ -z "$cmd" || "$cmd" == "help" || "$cmd" == "--help" ]]; then
    cat <<EOF

Usage: zman dataset <subcommand> [options]

Subcommands:

  create   <pool/dataset> [key=value ...]          Create a new dataset
  list     [filters...]                            List datasets
  destroy  [-r] <pool/dataset|snapshot> [--dry-run] Destroy a dataset or snapshot
  snapshot <pool/dataset> <snapname> [--recursive] [--dry-run]  Create snapshot
  clone    <pool/dataset@snap> <target> [--dry-run] Clone snapshot
  set      <prop=value> <pool/dataset> [--dry-run] Set a ZFS dataset property
  get      <pool/dataset> [property...]            Get dataset properties
  mount    <pool/dataset> [--dry-run]              Mount a dataset
  umount   <pool/dataset> [--dry-run]              Unmount a dataset
  promote  <pool/clone> [--dry-run]                Promote a clone

EOF
    return 0
  fi

  case "$cmd" in
    create)
      [[ -z "$1" ]] && echo "Usage: zman dataset create <pool/dataset> [key=value ...] [--dry-run]" && return 1
      local dataset="$1"; shift
      local opts=() dry_run="false"
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --dry-run) dry_run="true" ;;
          *=*) opts+=("-o" "$1") ;;
          *) echo "Invalid create argument: $1"; return 1 ;;
        esac
        shift
      done
      if [[ "$dry_run" == "true" ]]; then
        echo "[DRY-RUN] zfs create ${opts[*]} $dataset"
      else
        log_info "Creating dataset: $dataset with options: ${opts[*]}"
        zfs create "${opts[@]}" "$dataset"
      fi
      ;;
    list)
      zfs list "$@"
      ;;
    destroy)
      local recursive="false" dry_run="false"
      [[ "$1" == "-r" ]] && recursive="true" && shift
      [[ -z "$1" ]] && echo "Usage: zman dataset destroy [-r] <target> [--dry-run]" && return 1
      local target="$1"; shift
      [[ "${1:-}" == "--dry-run" ]] && dry_run="true"

      if [[ "$dry_run" == "true" ]]; then
        echo "[DRY-RUN] zfs destroy ${recursive:+-r }$target"
      else
        read -rp "Are you sure you want to destroy '$target'? This cannot be undone. (yes/no): " confirm
        if [[ "$confirm" == "yes" ]]; then
          log_info "Destroying ${recursive:+recursively }dataset: $target"
          zfs destroy ${recursive:+-r} "$target"
        else
          echo "Aborted."
        fi
      fi
      ;;
    snapshot)
      [[ -z "$1" || -z "$2" ]] && echo "Usage: zman dataset snapshot <dataset> <snapname> [--recursive] [--dry-run]" && return 1
      local dataset="$1" snapname="$2"
      shift 2
      local flags=() dry_run="false"
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --recursive) flags+=("-r") ;;
          --dry-run) dry_run="true" ;;
        esac
        shift
      done
      if [[ "$dry_run" == "true" ]]; then
        echo "[DRY-RUN] zfs snapshot ${flags[*]} ${dataset}@${snapname}"
      else
        log_info "Creating snapshot: ${dataset}@${snapname} ${flags[*]}"
        zfs snapshot "${flags[@]}" "${dataset}@${snapname}"
      fi
      ;;
    clone)
      [[ -z "$1" || -z "$2" ]] && echo "Usage: zman dataset clone <source@snap> <target> [--dry-run]" && return 1
      local source="$1" target="$2" dry_run="false"
      shift 2
      [[ "${1:-}" == "--dry-run" ]] && dry_run="true"
      if [[ "$dry_run" == "true" ]]; then
        echo "[DRY-RUN] zfs clone $source $target"
      else
        log_info "Cloning $source to $target"
        zfs clone "$source" "$target"
      fi
      ;;
    set)
      [[ -z "$1" || -z "$2" ]] && echo "Usage: zman dataset set <property=value> <pool/dataset> [--dry-run]" && return 1
      local prop="$1" dataset="$2" dry_run="false"
      shift 2
      [[ "${1:-}" == "--dry-run" ]] && dry_run="true"
      if [[ "$dry_run" == "true" ]]; then
        echo "[DRY-RUN] zfs set $prop $dataset"
      else
        log_info "Setting $prop on $dataset"
        zfs set "$prop" "$dataset"
      fi
      ;;
    get)
      [[ -z "$1" ]] && echo "Usage: zman dataset get <pool/dataset> [property...]" && return 1
      zfs get "$@"
      ;;
    mount)
      [[ -z "$1" ]] && echo "Usage: zman dataset mount <dataset> [--dry-run]" && return 1
      local dataset="$1" dry_run="${2:-false}"
      if [[ "$dry_run" == "--dry-run" ]]; then
        echo "[DRY-RUN] zfs mount $dataset"
      else
        log_info "Mounting $dataset"
        zfs mount "$dataset"
      fi
      ;;
    umount)
      [[ -z "$1" ]] && echo "Usage: zman dataset umount <dataset> [--dry-run]" && return 1
      local dataset="$1" dry_run="${2:-false}"
      if [[ "$dry_run" == "--dry-run" ]]; then
        echo "[DRY-RUN] zfs unmount $dataset"
      else
        log_info "Unmounting $dataset"
        zfs unmount "$dataset"
      fi
      ;;
    promote)
      [[ -z "$1" ]] && echo "Usage: zman dataset promote <clone> [--dry-run]" && return 1
      local dataset="$1" dry_run="${2:-false}"
      if [[ "$dry_run" == "--dry-run" ]]; then
        echo "[DRY-RUN] zfs promote $dataset"
      else
        read -rp "Promote '$dataset' to primary? (yes/no): " confirm
        if [[ "$confirm" == "yes" ]]; then
          log_info "Promoting $dataset to primary"
          zfs promote "$dataset"
        else
          echo "Aborted."
        fi
      fi
      ;;
    *)
      echo "Unknown dataset subcommand: $cmd"
      echo "Run: zman dataset --help"
      return 1
      ;;
  esac
}
