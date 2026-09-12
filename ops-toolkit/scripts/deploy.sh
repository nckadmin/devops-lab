#!/usr/bin/env bash
# deploy.sh — deploy an application from git with health-check and automatic rollback.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# ==== SETTINGS ====
APP_DIR="/opt/myapp"
GIT_BRANCH="main"
SERVICE_NAME="myapp.service"
HEALTHCHECK_URL="http://127.0.0.1:8080/health"
HEALTHCHECK_RETRIES=10
HEALTHCHECK_DELAY=3
# ===================

require_cmd git systemctl curl
cd "$APP_DIR"

PREV_COMMIT=$(git rev-parse HEAD)
log_info "Current commit: $PREV_COMMIT"

log_info "Pulling code from branch $GIT_BRANCH"
git fetch origin "$GIT_BRANCH" || die "git fetch failed"
git checkout "$GIT_BRANCH"
git reset --hard "origin/${GIT_BRANCH}"

if [[ -f "requirements.txt" ]]; then
    log_info "Installing Python dependencies"
    pip install -r requirements.txt --quiet
elif [[ -f "package.json" ]]; then
    log_info "Installing npm dependencies"
    npm ci --silent
fi

log_info "Restarting service $SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

log_info "Checking service health"
ok=0
for i in $(seq 1 "$HEALTHCHECK_RETRIES"); do
    if curl -fsS -m 5 "$HEALTHCHECK_URL" >/dev/null 2>&1; then
        ok=1
        break
    fi
    sleep "$HEALTHCHECK_DELAY"
done

if [[ "$ok" -eq 1 ]]; then
    log_info "Deploy succeeded, service is responding"
    notify "Deploy OK: $SERVICE_NAME at commit $(git rev-parse --short HEAD)"
else
    log_error "Health-check failed, rolling back to $PREV_COMMIT"
    git reset --hard "$PREV_COMMIT"
    systemctl restart "$SERVICE_NAME"
    notify "Deploy FAILED, rolled back to $PREV_COMMIT"
    die "Deploy failed, rollback performed"
fi
