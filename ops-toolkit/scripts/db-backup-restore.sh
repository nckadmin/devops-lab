#!/usr/bin/env bash
# db-backup-restore.sh — back up and restore PostgreSQL/MySQL with checksum verification.
# Usage:
#   ./db-backup-restore.sh backup
#   ./db-backup-restore.sh restore /backup/db/mydb_20260101_120000.sql.gz
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# ==== SETTINGS ====
DB_ENGINE="postgres"      # postgres | mysql
DB_NAME="mydb"
DB_USER="postgres"
DB_HOST="127.0.0.1"
BACKUP_DIR="/backup/db"
RETENTION_DAYS=30
# Set DB_PASSWORD via an environment variable — never hardcode it in this file
# ===================

mkdir -p "$BACKUP_DIR"
ACTION="${1:-}"

do_backup() {
    local ts dump_file
    ts="$(date '+%Y%m%d_%H%M%S')"
    dump_file="${BACKUP_DIR}/${DB_NAME}_${ts}.sql.gz"

    log_info "Backing up database $DB_NAME ($DB_ENGINE) -> $dump_file"
    case "$DB_ENGINE" in
        postgres)
            require_cmd pg_dump
            PGPASSWORD="${DB_PASSWORD:-}" pg_dump -h "$DB_HOST" -U "$DB_USER" "$DB_NAME" | gzip > "$dump_file"
            ;;
        mysql)
            require_cmd mysqldump
            mysqldump -h "$DB_HOST" -u "$DB_USER" -p"${DB_PASSWORD:-}" "$DB_NAME" | gzip > "$dump_file"
            ;;
        *)
            die "Unknown DB_ENGINE: $DB_ENGINE"
            ;;
    esac

    sha256sum "$dump_file" > "${dump_file}.sha256"
    log_info "Database backup created: $(du -h "$dump_file" | cut -f1)"

    find "$BACKUP_DIR" -name "${DB_NAME}_*.sql.gz*" -mtime "+${RETENTION_DAYS}" -print -delete >> "$LOG_FILE"
    notify "DB backup OK: $DB_NAME ($dump_file)"
}

do_restore() {
    local dump_file="$1"
    [[ -f "$dump_file" ]] || die "Dump file not found: $dump_file"

    if [[ -f "${dump_file}.sha256" ]]; then
        log_info "Verifying checksum before restore"
        sha256sum -c "${dump_file}.sha256" || die "Checksum mismatch, restore aborted"
    fi

    log_warn "WARNING: this will overwrite database $DB_NAME"
    read -r -p "Continue? (yes/no): " confirm
    [[ "$confirm" == "yes" ]] || die "Restore cancelled by user"

    case "$DB_ENGINE" in
        postgres)
            require_cmd psql
            gunzip -c "$dump_file" | PGPASSWORD="${DB_PASSWORD:-}" psql -h "$DB_HOST" -U "$DB_USER" "$DB_NAME"
            ;;
        mysql)
            require_cmd mysql
            gunzip -c "$dump_file" | mysql -h "$DB_HOST" -u "$DB_USER" -p"${DB_PASSWORD:-}" "$DB_NAME"
            ;;
        *)
            die "Unknown DB_ENGINE: $DB_ENGINE"
            ;;
    esac
    log_info "Restore of $DB_NAME from $dump_file completed"
}

case "$ACTION" in
    backup) do_backup ;;
    restore) do_restore "${2:-}" ;;
    *) echo "Usage: $0 {backup|restore <file>}"; exit 1 ;;
esac
