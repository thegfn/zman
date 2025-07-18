LOG_FILE="/var/log/zman.log"  

log_info() {
  local ts
  ts=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "[INFO] [$ts] $*" | tee -a "$LOG_FILE"
}

log_warn() {
  local ts
  ts=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "[WARN] [$ts] $*" | tee -a "$LOG_FILE" >&2
}

log_error() {
  local ts
  ts=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "[ERROR] [$ts] $*" | tee -a "$LOG_FILE" >&2
}
