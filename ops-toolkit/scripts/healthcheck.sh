#!/usr/bin/env bash
# healthcheck.sh — check service/host availability and alert on failure.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# ==== SETTINGS ====
declare -A HTTP_CHECKS=(
    ["frontend"]="https://example.com/health"
    ["api"]="https://api.example.com/health"
)
declare -A TCP_CHECKS=(
    ["postgres"]="10.0.0.10:5432"
    ["fortigate-mgmt"]="10.0.0.1:443"
)
TIMEOUT=5
# ===================

fail=0

for name in "${!HTTP_CHECKS[@]}"; do
    url="${HTTP_CHECKS[$name]}"
    code=$(curl -s -o /dev/null -w '%{http_code}' -m "$TIMEOUT" "$url" || echo "000")
    if [[ "$code" =~ ^2 ]]; then
        log_info "OK  [$name] $url -> HTTP $code"
    else
        log_error "FAIL [$name] $url -> HTTP $code"
        notify "Health-check FAIL: $name ($url) — HTTP $code"
        fail=1
    fi
done

for name in "${!TCP_CHECKS[@]}"; do
    hostport="${TCP_CHECKS[$name]}"
    host="${hostport%%:*}"
    port="${hostport##*:}"
    if timeout "$TIMEOUT" bash -c "cat < /dev/null > /dev/tcp/${host}/${port}" 2>/dev/null; then
        log_info "OK  [$name] $hostport"
    else
        log_error "FAIL [$name] $hostport unreachable"
        notify "Health-check FAIL: $name ($hostport)"
        fail=1
    fi
done

exit $fail
