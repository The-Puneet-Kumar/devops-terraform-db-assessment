#!/usr/bin/env bash
set -euo pipefail

CONTAINER="${DB_CONTAINER:-devops-assessment-db}"
DB_USER="${DB_USER:-appuser}"
DB_NAME="${DB_NAME:-bookings}"
BACKUP_DIR="${BACKUP_DIR:-backups}"

mkdir -p "$BACKUP_DIR"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.dump"

echo "Creating PostgreSQL backup: ${BACKUP_FILE}"

docker exec "$CONTAINER" pg_dump \
  -U "$DB_USER" \
  -d "$DB_NAME" \
  -Fc \
  -f "/tmp/${DB_NAME}_${TIMESTAMP}.dump"

docker cp \
  "${CONTAINER}:/tmp/${DB_NAME}_${TIMESTAMP}.dump" \
  "$BACKUP_FILE"

docker exec "$CONTAINER" rm -f "/tmp/${DB_NAME}_${TIMESTAMP}.dump"

echo "Backup completed successfully: ${BACKUP_FILE}"
