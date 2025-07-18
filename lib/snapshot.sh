#!/bin/bash

snapshot_cli() {
  if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<EOF

Usage: zman snapshot <subcommand> [options]

Subcommands:

  take     --dataset <pool/dataset> [--name <snapname>] [--date] [--dry-run]
           → Create a snapshot manually or with date-based naming

  prune    --dataset <pool/dataset> [--days <N> | --keep-last <N>] [--pattern <prefix>] [--dry-run]
           → Prune snapshots older than N days or keep only the most recent N snapshots
             Matching is limited to snapshots with name containing the pattern (default: auto-)

Options:
  --dry-run       → Show what would be done, without making changes

Examples:

  zman snapshot take --dataset tank/data --date
  zman snapshot prune --dataset tank/data --days 30 --pattern daily- --dry-run
  zman snapshot prune --dataset tank/data --keep-last 10

EOF
    return 0
  fi

  case "$1" in
    take)
      shift
      local dataset="" snap_name="" use_date="false" dry_run="false"

      while [[ $# -gt 0 ]]; do
        case "$1" in
          --dataset) dataset="$2"; shift ;;
          --name)    snap_name="$2"; shift ;;
          --date)    use_date="true" ;;
          --dry-run) dry_run="true" ;;
          *) log_error "Unknown take argument: $1"; return 1 ;;
        esac
        shift
      done

      [[ -z "$dataset" ]] && log_error "Missing --dataset" && return 1
      [[ "$use_date" == "true" ]] && snap_name="$(date +%F)"
      [[ -z "$snap_name" ]] && log_error "Missing snapshot name (use --name or --date)" && return 1

      if [[ "$dry_run" == "true" ]]; then
        log_info "[Dry-run] Would create snapshot: ${dataset}@${snap_name}"
      else
        log_info "Creating snapshot: ${dataset}@${snap_name}"
        zfs snapshot "${dataset}@${snap_name}"
      fi
      ;;

    prune)
      shift
      local dataset="" days="" keep_last="" pattern="auto-" dry_run="false"

      while [[ $# -gt 0 ]]; do
        case "$1" in
          --dataset)    dataset="$2"; shift ;;
          --days)       days="$2"; shift ;;
          --keep-last)  keep_last="$2"; shift ;;
          --pattern)    pattern="$2"; shift ;;
          --dry-run)    dry_run="true" ;;
          *) log_error "Unknown prune argument: $1"; return 1 ;;
        esac
        shift
      done

      [[ -z "$dataset" ]] && log_error "Missing --dataset" && return 1
      if [[ -n "$days" && -n "$keep_last" ]]; then
        log_error "Cannot use both --days and --keep-last at the same time"
        return 1
      fi

      if [[ -n "$days" ]]; then
        local now
        now=$(date +%s)

        zfs list -H -t snapshot -o name,creation -s creation |
          grep "^${dataset}@" |
          while read -r snap creation; do
            [[ "$snap" != *"$pattern"* ]] && continue
            snap_time=$(date -d "$creation" +%s)
            age=$(( (now - snap_time) / 86400 ))
            if [[ "$age" -gt "$days" ]]; then
              if [[ "$dry_run" == "true" ]]; then
                log_info "[Dry-run] Would destroy $snap (age $age days)"
              else
                log_info "Destroying $snap (age $age days)"
                zfs destroy "$snap"
              fi
            fi
          done

      elif [[ -n "$keep_last" ]]; then
        mapfile -t snaps < <(zfs list -H -t snapshot -o name -s creation | grep "^${dataset}@" | grep "$pattern")

        local total="${#snaps[@]}"
        if (( total <= keep_last )); then
          log_info "Found $total snapshots, less than or equal to keep-last=$keep_last — nothing to prune."
          return 0
        fi

        for ((i = 0; i < total - keep_last; i++)); do
          snap="${snaps[$i]}"
          if [[ "$dry_run" == "true" ]]; then
            log_info "[Dry-run] Would destroy $snap"
          else
            log_info "Destroying $snap"
            zfs destroy "$snap"
          fi
        done
      else
        log_error "Must provide either --days or --keep-last"
        return 1
      fi
      ;;

    *)
      log_error "Unknown snapshot command: $1"
      return 1
      ;;
  esac
}
