#!/bin/bash

set -e

if [ -f /scripts/.backup.env ]; then
    source /scripts/.backup.env
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /logs/backup.log
}

# Check required environment variables
if [ -z "$S3_ACCESS_KEY" ] || [ -z "$S3_SECRET_KEY" ] || [ -z "$S3_BUCKET" ] || [ -z "$S3_ENDPOINT" ] || [ -z "$BACKUP_FOLDER_NAME" ]; then
    log "ERROR: Missing required environment variables"
    log "Required: S3_ACCESS_KEY, S3_SECRET_KEY, S3_BUCKET, S3_ENDPOINT, BACKUP_FOLDER_NAME"
    exit 1
fi

export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"
export AWS_DEFAULT_REGION="${S3_REGION:-nbg}"

TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
BACKUP_NAME="backup-${TIMESTAMP}.tar.gz"
TEMP_BACKUP="/tmp/${BACKUP_NAME}"
S3_PATH="s3://${S3_BUCKET}/backups/${BACKUP_FOLDER_NAME}/${BACKUP_NAME}"

log "=========================================="
log "Starting backup process"
log "Backup name: ${BACKUP_NAME}"
log "Source: /data"
log "Destination: ${S3_PATH}"

log "Creating compressed archive..."
if tar -czf "$TEMP_BACKUP" -C /data . 2>&1 | tee -a /logs/backup.log; then
    BACKUP_SIZE=$(du -h "$TEMP_BACKUP" | cut -f1)
    log "Archive created successfully (Size: ${BACKUP_SIZE})"
else
    log "ERROR: Failed to create archive"
    exit 1
fi

log "Uploading to Hetzner Object Storage..."
if aws s3 cp "$TEMP_BACKUP" "$S3_PATH" \
    --endpoint-url="$S3_ENDPOINT" \
    2>&1 | tee -a /logs/backup.log; then
    log "Upload completed successfully"
else
    log "ERROR: Failed to upload to S3"
    rm -f "$TEMP_BACKUP"
    exit 1
fi

log "Cleaning up temporary files..."
rm -f "$TEMP_BACKUP"
log "Backup process completed successfully"
log "=========================================="
