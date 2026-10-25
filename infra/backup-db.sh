#!/bin/bash
# Database Backup Script for Qadam
# Run daily via cron: 0 2 * * * /path/to/backup-db.sh

set -e

BACKUP_DIR="/home/qadam/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting database backup..."

# Create backup
docker compose -f docker-compose.prod.yml exec -T postgres pg_dump \
    -U qadam qadam | gzip > "$BACKUP_DIR/qadam_${TIMESTAMP}.sql.gz"

if [ $? -eq 0 ]; then
    echo "[$(date)] Backup completed: qadam_${TIMESTAMP}.sql.gz"

    # Calculate backup size
    SIZE=$(du -h "$BACKUP_DIR/qadam_${TIMESTAMP}.sql.gz" | cut -f1)
    echo "[$(date)] Backup size: $SIZE"

    # Remove old backups
    find "$BACKUP_DIR" -name "qadam_*.sql.gz" -mtime +$RETENTION_DAYS -delete
    echo "[$(date)] Old backups cleaned (retention: ${RETENTION_DAYS} days)"
else
    echo "[$(date)] ERROR: Backup failed!"
    exit 1
fi

# Optional: Upload to cloud storage (S3, etc.)
# aws s3 cp "$BACKUP_DIR/qadam_${TIMESTAMP}.sql.gz" s3://qadam-backups/

echo "[$(date)] Backup process completed"
