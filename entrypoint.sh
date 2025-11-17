#!/bin/bash

set -e

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Initializing S3 backup service..." | tee -a /logs/backup.log

# Validate environment variables
if [ -z "$S3_ACCESS_KEY" ] || [ -z "$S3_SECRET_KEY" ] || [ -z "$S3_BUCKET" ] || [ -z "$S3_ENDPOINT" ] || [ -z "$BACKUP_FOLDER_NAME" ]; then
    echo "ERROR: Missing required environment variables" | tee -a /logs/backup.log
    echo "Required: S3_ACCESS_KEY, S3_SECRET_KEY, S3_BUCKET, S3_ENDPOINT, BACKUP_FOLDER_NAME" | tee -a /logs/backup.log
    exit 1
fi

# Create environment file for the backup script (with restricted permissions)
cat > /scripts/.backup.env <<EOF
S3_ACCESS_KEY=$S3_ACCESS_KEY
S3_SECRET_KEY=$S3_SECRET_KEY
S3_BUCKET=$S3_BUCKET
S3_ENDPOINT=$S3_ENDPOINT
S3_REGION=${S3_REGION:-nbg}
BACKUP_FOLDER_NAME=$BACKUP_FOLDER_NAME
EOF
chmod 600 /scripts/.backup.env

# Create crontab file
cat > /tmp/crontab <<EOF
# Run backup every 30 minutes
*/30 * * * * /scripts/backup.sh
EOF

# Install crontab
crontab /tmp/crontab
rm /tmp/crontab

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cron configured to run backups every 30 minutes" | tee -a /logs/backup.log

# Run initial backup immediately
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running initial backup..." | tee -a /logs/backup.log
/scripts/backup.sh

# Start cron in background
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting cron daemon..." | tee -a /logs/backup.log
crond

# Keep container alive by tailing the log file
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Service is running. Backups will run every 30 minutes." | tee -a /logs/backup.log
tail -f /logs/backup.log
