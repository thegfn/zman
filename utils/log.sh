log_info()  { echo -e "\e[32m[INFO]\e[0m $*"; }
log_warn()  { echo -e "\e[33m[WARN]\e[0m $*"; }
log_error() { echo -e "\e[31m[ERROR]\e[0m $*" >&2; }
log_debug() { [[ "${DEBUG:-}" == "1" ]] && echo -e "\e[34m[DEBUG]\e[0m $*"; }
