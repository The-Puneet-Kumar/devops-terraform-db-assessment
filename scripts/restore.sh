#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <backup-file.dump>"
  exit 1
fi

BACKUP_FILE="$1"
CONTAINER="${DB_CONTAINER:-devops-assessment-db}"
DB_USER="${DB_USER:-appuser}"
TARGET_DB="${TARGET_DB:-bookings_restore}"
TEMP_NAME="restore_$(date +%Y%m%d_%H%M%S).dump"

if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "Backup file not found: $BACKUP_FILE"
  exit 1
fi

echo "Creating fresh database: ${TARGET_DB}"

docker exec "$CONTAINER" psql \
  -U "$DB_USER" \
  -d postgres \
  -v ON_ERROR_STOP=1 \
  -c "DROP DATABASE IF EXISTS ${TARGET_DB};" \
  -c "CREATE DATABASE ${TARGET_DB};"

docker cp "$BACKUP_FILE" "${CONTAINER}:/tmp/${TEMP_NAME}"

docker exec "$CONTAINER" pg_restore \
  -U "$DB_USER" \
  -d "$TARGET_DB" \
  --exit-on-error \
  "/tmp/${TEMP_NAME}"

docker exec "$CONTAINER" rm -f "/tmp/${TEMP_NAME}"

echo "Restore completed successfully into database: ${TARGET_DB}"
echo "Verify with:"
echo "docker compose exec db psql -U ${DB_USER} -d ${TARGET_DB} -c \"SELECT COUNT(*) FROM hotel_bookings;\""
