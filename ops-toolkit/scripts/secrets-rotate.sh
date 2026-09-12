#!/usr/bin/env bash
# secrets-rotate.sh — rotate SSH keys across a list of hosts, verifying before revoking the old key.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
require_cmd ssh-keygen ssh ssh-copy-id

# ==== SETTINGS ====
KEY_DIR="$HOME/.ssh/rotation"
KEY_NAME="deploy_key_$(date +%Y%m%d)"
REMOTE_USER="deploy"
HOSTS=("host1.example.com" "host2.example.com")
# ===================

mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"

log_info "Generating new key $KEY_NAME"
ssh-keygen -t ed25519 -f "${KEY_DIR}/${KEY_NAME}" -N "" -C "rotated-$(date +%Y%m%d)"

for host in "${HOSTS[@]}"; do
    log_info "Deploying new key to $host"
    if ssh-copy-id -i "${KEY_DIR}/${KEY_NAME}.pub" "${REMOTE_USER}@${host}"; then
        log_info "Key added on $host"
    else
        log_error "Failed to add key on $host"
        notify "Secrets rotate: failed to add key on $host"
        continue
    fi

    log_info "Verifying login with the new key on $host"
    if ssh -i "${KEY_DIR}/${KEY_NAME}" -o BatchMode=yes -o ConnectTimeout=5 "${REMOTE_USER}@${host}" 'echo ok' >/dev/null 2>&1; then
        log_info "New key works on $host"
    else
        log_error "New key does NOT work on $host — NOT revoking the old key"
        notify "Secrets rotate: new key failed verification on $host"
        continue
    fi

    log_warn "Check all services, then manually remove the old key from authorized_keys on $host"
done

log_info "Key rotation completed. Private keys are stored in $KEY_DIR — do NOT commit them to git!"
