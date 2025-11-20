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
    log "ERROR: Missing required environment variables for cleanup"
    exit 1
fi

export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"
export AWS_DEFAULT_REGION="${S3_REGION:-nbg}"

S3_PREFIX="s3://${S3_BUCKET}/backups/${BACKUP_FOLDER_NAME}/"
TODAY=$(date '+%Y-%m-%d')

log "=========================================="
log "Starting backup cleanup process"
log "S3 Path: ${S3_PREFIX}"
log "Today's date: ${TODAY}"

# Get list of all backups
log "Fetching backup list from S3..."
BACKUPS=$(aws s3 ls "${S3_PREFIX}" --endpoint-url="$S3_ENDPOINT" 2>&1)

if [ $? -ne 0 ]; then
    log "ERROR: Failed to list backups from S3"
    log "$BACKUPS"
    exit 1
fi

# Parse backup files and organize by date
declare -A DATE_BACKUPS

while IFS= read -r line; do
    # Extract filename from s3 ls output (format: "2025-11-17 09:11:27    123456 backup-2025-11-17_09-11-27.tar.gz")
    FILENAME=$(echo "$line" | awk '{print $4}')

    if [[ $FILENAME =~ ^backup-([0-9]{4}-[0-9]{2}-[0-9]{2})_([0-9]{2}-[0-9]{2}-[0-9]{2})\.tar\.gz$ ]]; then
        BACKUP_DATE="${BASH_REMATCH[1]}"
        BACKUP_TIME="${BASH_REMATCH[2]}"
        FULL_TIMESTAMP="${BACKUP_DATE}_${BACKUP_TIME}"

        # Skip today's backups
        if [ "$BACKUP_DATE" == "$TODAY" ]; then
            continue
        fi

        # Store backup for this date
        if [ -z "${DATE_BACKUPS[$BACKUP_DATE]}" ]; then
            DATE_BACKUPS[$BACKUP_DATE]="$FULL_TIMESTAMP"
        else
            # Keep the latest backup for each date
            if [[ "$FULL_TIMESTAMP" > "${DATE_BACKUPS[$BACKUP_DATE]}" ]]; then
                DATE_BACKUPS[$BACKUP_DATE]="$FULL_TIMESTAMP"
            fi
        fi
    fi
done <<< "$BACKUPS"

# Now delete all old backups except the last one per day
DELETED_COUNT=0
KEPT_COUNT=0

while IFS= read -r line; do
    FILENAME=$(echo "$line" | awk '{print $4}')

    if [[ $FILENAME =~ ^backup-([0-9]{4}-[0-9]{2}-[0-9]{2})_([0-9]{2}-[0-9]{2}-[0-9]{2})\.tar\.gz$ ]]; then
        BACKUP_DATE="${BASH_REMATCH[1]}"
        BACKUP_TIME="${BASH_REMATCH[2]}"
        FULL_TIMESTAMP="${BACKUP_DATE}_${BACKUP_TIME}"

        # Skip today's backups (keep all)
        if [ "$BACKUP_DATE" == "$TODAY" ]; then
            log "KEEP (today): $FILENAME"
            KEPT_COUNT=$((KEPT_COUNT + 1))
            continue
        fi

        # Check if this is the last backup for its date
        if [ "${DATE_BACKUPS[$BACKUP_DATE]}" == "$FULL_TIMESTAMP" ]; then
            log "KEEP (last of $BACKUP_DATE): $FILENAME"
            KEPT_COUNT=$((KEPT_COUNT + 1))
        else
            log "DELETE (old backup from $BACKUP_DATE): $FILENAME"
            aws s3 rm "${S3_PREFIX}${FILENAME}" --endpoint-url="$S3_ENDPOINT" 2>&1 | tee -a /logs/backup.log
            if [ $? -eq 0 ]; then
                DELETED_COUNT=$((DELETED_COUNT + 1))
            else
                log "ERROR: Failed to delete $FILENAME"
            fi
        fi
    fi
done <<< "$BACKUPS"

log "Cleanup completed:"
log "  - Backups kept: ${KEPT_COUNT}"
log "  - Backups deleted: ${DELETED_COUNT}"
log "=========================================="
