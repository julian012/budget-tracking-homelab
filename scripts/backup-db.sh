#!/bin/bash
# backup-db.sh — Daily PostgreSQL backup for Budget Tracker
# Usage: bash scripts/backup-db.sh

set -euo pipefail

CONTAINER="${CONTAINER:-postgres_container}"
DB_NAME="${DB_NAME:-budget}"
DB_USER="${DB_USER:-budget}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/backups/postgres}"
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y-%m-%d)
BACKUP_FILE="$BACKUP_DIR/$DB_NAME-$TIMESTAMP.sql.gz"

mkdir -p "$BACKUP_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting backup of '$DB_NAME'..."

docker exec "$CONTAINER" pg_dump -U "$DB_USER" -d "$DB_NAME" | gzip > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backup completed: $BACKUP_FILE ($SIZE)"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Backup failed for $DB_NAME"
    exit 1
fi

DELETED=$(find "$BACKUP_DIR" -name "$DB_NAME-*.sql.gz" -mtime +$RETENTION_DAYS -delete -print)
if [ -n "$DELETED" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cleaned up old backups:"
    echo "$DELETED"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Done."
