#!/usr/bin/env bash
# docker-cleanup.sh — clean up unused Docker resources and restart unhealthy containers.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
require_cmd docker

KEEP_IMAGES_HOURS=168   # 7 days

log_info "Checking for unhealthy containers"
for cid in $(docker ps -a --filter "health=unhealthy" -q); do
    name=$(docker inspect --format '{{.Name}}' "$cid" | sed 's#^/##')
    log_warn "Container $name is unhealthy, restarting"
    docker restart "$cid" || log_error "Failed to restart $name"
    notify "Docker: container $name was unhealthy, restarted"
done

log_info "Removing stopped containers"
docker container prune -f >> "$LOG_FILE"

log_info "Removing unused images older than $KEEP_IMAGES_HOURS hours"
docker image prune -af --filter "until=${KEEP_IMAGES_HOURS}h" >> "$LOG_FILE"

log_info "Removing unused volumes and networks"
docker volume prune -f >> "$LOG_FILE"
docker network prune -f >> "$LOG_FILE"

log_info "Docker cleanup completed"
docker system df >> "$LOG_FILE"
