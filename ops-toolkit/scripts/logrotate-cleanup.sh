#!/usr/bin/env bash
# logrotate-cleanup.sh — manual log rotation and protection against disk overflow.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# ==== SETTINGS ====
LOG_DIRS=("/var/log/myapp" "/var/log/nginx")
MAX_AGE_DAYS=30
COMPRESS_AFTER_DAYS=3
DISK_USAGE_THRESHOLD=85
MONITOR_PATH="/"
# ===================

for dir in "${LOG_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue

    log_info "Compressing logs older than $COMPRESS_AFTER_DAYS days in $dir"
    find "$dir" -type f -name "*.log" -mtime "+${COMPRESS_AFTER_DAYS}" ! -name "*.gz" \
        -exec gzip {} \;

    log_info "Removing logs older than $MAX_AGE_DAYS days in $dir"
    find "$dir" -type f \( -name "*.log.gz" -o -name "*.log" \) -mtime "+${MAX_AGE_DAYS}" -print -delete
done

usage=$(df --output=pcent "$MONITOR_PATH" | tail -1 | tr -dc '0-9')
log_info "Disk usage on $MONITOR_PATH: ${usage}%"
if (( usage >= DISK_USAGE_THRESHOLD )); then
    log_error "Disk is at ${usage}% (threshold ${DISK_USAGE_THRESHOLD}%)"
    notify "Disk $MONITOR_PATH is at ${usage}% on $(hostname -s)"
fi

log_info "Log rotation completed"
