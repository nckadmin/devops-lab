#!/usr/bin/env bash
# common.sh — shared logging and alerting functions.
# Include from a script: source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

LOG_FILE="${LOG_FILE:-/var/log/devops-lab.log}"

log() {
    local level="$1"; shift
    local msg="$*"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$ts] [$level] $msg" | tee -a "$LOG_FILE"
}

log_info()  { log "INFO"  "$@"; }
log_warn()  { log "WARN"  "$@"; }
log_error() { log "ERROR" "$@"; }

die() {
    log_error "$*"
    exit 1
}

# Notify via Telegram/Slack/Discord webhook.
# Set ALERT_WEBHOOK_URL in the environment or directly in the script.
notify() {
    local msg="$1"
    if [[ -n "${ALERT_WEBHOOK_URL:-}" ]]; then
        curl -fsS -m 10 -X POST -H 'Content-Type: application/json' \
            -d "{\"text\": \"$msg\"}" "$ALERT_WEBHOOK_URL" >/dev/null 2>&1 \
            || log_warn "Failed to send notification"
    fi
}

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        die "This script must be run as root (sudo)"
    fi
}

require_cmd() {
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
    done
}
