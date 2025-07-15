# Load config values
REPORT_CONF="$(dirname "$0")/report/defaults.conf"

load_config() {
	[[ ! -f "$REPORT_CONF" ]] && echo "Missing config: $REPORT_CONF" && return 1
	eval "$(
		awk -F= '
    /^[[:space:]]*\[/ { next }                # Skip [section] headers
    /^[[:space:]]*#/ { next }                 # Skip comments
    NF >= 2 {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
      printf "%s=\"%s\"\n", $1, $2
    }
  ' "$REPORT_CONF"
	)"
}

report_cli() {
	local cmd="${1:-}"
	shift || true
	load_config

	if [[ -z "$cmd" || "$cmd" == "--help" || "$cmd" == "help" ]]; then
		cat <<EOF

Usage: zman report <subcommand>

Subcommands:

  smart         Check SMART status of physical disks
  degraded      Show degraded pools/devices
  capacity      Show pools nearing full (>$capacity_warn_percent%)
  latency       Show IO stats (via zpool iostat)
  snapshots     List snapshot age/count issues
  quota         Show datasets exceeding reserved/quota thresholds

EOF
		return 0
	fi

	case "$cmd" in
	smart)
		echo "=== SMART Status ==="
		for dev in /dev/sd?; do
			base=$(basename "$dev")
			[[ ",$ignore_disks," == *",$base,"* ]] && continue
			if smartctl -H "$dev" &>/dev/null; then
				health=$(smartctl -H "$dev" | awk '/SMART overall-health/ { print $NF }')
				temp=$(smartctl -A "$dev" | awk '/Temperature_Celsius/ { print $10 }')
				realloc=$(smartctl -A "$dev" | awk '/Reallocated_Sector_Ct/ { print $10 }')
				echo "$base: Health=$health, Temp=${temp:-N/A}°C, Realloc=${realloc:-N/A}"
				[[ "$temp" =~ ^[0-9]+$ && "$temp" -ge "$smart_temp_warn_celsius" ]] && echo "  Temp exceeds $smart_temp_warn_celsius°C"
				[[ "$realloc" =~ ^[0-9]+$ && "$realloc" -ge "$smart_realloc_warn" ]] && echo " Reallocated sector count high"
			fi
		done
		;;

	degraded)
		echo "=== Degraded Pools ==="
		zpool list -H -o name,health | while read -r name health; do
			[[ ",$ignore_pools," == *",$name,"* ]] && continue
			if [[ "$health" != "ONLINE" ]]; then
				echo "$name: $health"
			fi
		done
		;;

	capacity)
		echo "=== Pool Capacity ==="
		zpool list -H -o name,capacity | while read -r name cap; do
			[[ ",$ignore_pools," == *",$name,"* ]] && continue
			usage_pct="${cap%\%}"
			if [[ "$usage_pct" -ge "$capacity_warn_percent" ]]; then
				echo "$name: ${cap} used"
			fi
		done
		;;

	latency)
		echo "=== IO Latency (zpool iostat -v) ==="
		zpool list -H -o name | while read -r name; do
			[[ ",$ignore_pools," == *",$name,"* ]] && continue
			echo "--- $name ---"
			zpool iostat -v "$name" 1 2 | tail -n +4
		done
		;;

	snapshots)
		echo "=== Snapshot Age and Count ==="
		current_ts=$(date +%s)
		zfs list -H -t snapshot -o name,creation | while read -r name ctime; do
			base_dataset="${name%@*}"
			[[ ",$ignore_pools," == *",${base_dataset%%/*},"* ]] && continue
			age_days=$(((current_ts - ctime) / 86400))
			[[ "$age_days" -ge "$snapshot_age_warn_days" ]] && echo "$name is $age_days days old"
		done

		echo "--- Counting per dataset ---"
		zfs list -H -t snapshot -o name | cut -d@ -f1 | sort | uniq -c | while read -r count dataset; do
			if [[ "$count" -gt "$snapshot_count_warn" ]]; then
				echo "$dataset has $count snapshots"
			fi
		done
		;;

	quota)
		echo "=== Quota Violations ==="
		zfs list -H -o name,used,quota,reservation | while read -r name used quota resv; do
			[[ "$quota" != "-" && "$used" > "$quota" ]] && echo "$name exceeds quota ($used > $quota)"
			[[ "$resv" != "-" && "$used" > "$resv" ]] && echo "$name exceeds reservation ($used > $resv)"
		done
		;;

	*)
		echo "Unknown report subcommand: $cmd"
		echo "Run: zman report --help"
		return 1
		;;
	esac
}
