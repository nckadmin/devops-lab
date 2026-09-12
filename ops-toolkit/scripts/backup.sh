#!/usr/bin/env bash
# backup.sh — back up directories with retention-based rotation.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# ==== SETTINGS (fill in your values) ====
SOURCE_DIRS=("/etc" "/opt/myapp/data")   # what to back up
BACKUP_ROOT="/backup/local"              # where to store archives
REMOTE_DEST=""                           # optional: user@host:/path (rsync), empty = skip
RETENTION_DAYS=14                        # how many days to keep local backups
HOSTNAME_TAG="$(hostname -s)"
DATE_TAG="$(date '+%Y%m%d_%H%M%S')"
ARCHIVE_NAME="${HOSTNAME_TAG}_${DATE_TAG}.tar.gz"
ARCHIVE_PATH="${BACKUP_ROOT}/${ARCHIVE_NAME}"
# =========================================

require_cmd tar sha256sum find
mkdir -p "$BACKUP_ROOT"

log_info "Starting backup: ${SOURCE_DIRS[*]} -> $ARCHIVE_PATH"

tar -czf "$ARCHIVE_PATH" "${SOURCE_DIRS[@]}" 2>>"$LOG_FILE" \
    || die "Failed to create archive"

sha256sum "$ARCHIVE_PATH" > "${ARCHIVE_PATH}.sha256"
log_info "Archive created: $(du -h "$ARCHIVE_PATH" | cut -f1)"

if [[ -n "$REMOTE_DEST" ]]; then
    require_cmd rsync
    log_info "Copying to remote storage: $REMOTE_DEST"
    rsync -az --partial "$ARCHIVE_PATH" "${ARCHIVE_PATH}.sha256" "$REMOTE_DEST" \
        || { log_error "Failed to copy backup to $REMOTE_DEST"; notify "Backup: failed to copy to $REMOTE_DEST ($HOSTNAME_TAG)"; exit 1; }
fi

log_info "Rotation: removing backups older than $RETENTION_DAYS days"
find "$BACKUP_ROOT" -maxdepth 1 -name "${HOSTNAME_TAG}_*.tar.gz*" -mtime "+${RETENTION_DAYS}" -print -delete >> "$LOG_FILE"

log_info "Backup completed successfully"
notify "Backup OK: $ARCHIVE_NAME ($HOSTNAME_TAG)"
