#!/usr/bin/env bash
# cert-renew.sh — renew TLS certificates (certbot), reload services, alert on upcoming expiry.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
require_root
require_cmd certbot openssl

SERVICES_TO_RELOAD=("nginx" "haproxy")
EXPIRY_WARN_DAYS=14

log_info "Checking and renewing certificates"
if certbot renew --quiet >> "$LOG_FILE" 2>&1; then
    log_info "certbot renew completed successfully"
else
    log_error "certbot renew failed"
    notify "Cert renew FAILED on $(hostname -s)"
    exit 1
fi

for svc in "${SERVICES_TO_RELOAD[@]}"; do
    if systemctl is-active --quiet "$svc"; then
        log_info "Reloading $svc"
        systemctl reload "$svc" || systemctl restart "$svc"
    fi
done

for certdir in /etc/letsencrypt/live/*/; do
    domain=$(basename "$certdir")
    [[ "$domain" == "README" ]] && continue
    [[ -f "${certdir}cert.pem" ]] || continue
    end_date=$(openssl x509 -enddate -noout -in "${certdir}cert.pem" | cut -d= -f2)
    end_epoch=$(date -d "$end_date" +%s)
    days_left=$(( (end_epoch - $(date +%s)) / 86400 ))
    if (( days_left < EXPIRY_WARN_DAYS )); then
        log_warn "Certificate $domain expires in $days_left days"
        notify "Certificate $domain expires in $days_left days"
    fi
done

log_info "Certificate check/renewal completed"
