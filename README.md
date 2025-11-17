# S3 Backup Service

Automated backup solution that compresses and uploads a folder to Hetzner Object Storage (S3-compatible) every 30 minutes using Docker Compose.

## Setup

```bash
S3_ACCESS_KEY=your_access_key_here
S3_SECRET_KEY=your_secret_key_here

S3_BUCKET=
S3_ENDPOINT=
S3_REGION=

BACKUP_SOURCE=/path/to/your/folder

# Folder name in S3 bucket (backups will be stored in: backups/{BACKUP_FOLDER_NAME}/)
BACKUP_FOLDER_NAME=my-backup-folder
```

```bash
docker-compose up -d
```

## Usage

### Trigger a manual backup

```bash
docker-compose exec s3-backup /scripts/backup.sh
```

## Backup Schedule

The service runs backups **every 30 minutes** automatically. You can modify this in `entrypoint.sh` by changing the cron expression:

```bash
# Current: Every 30 minutes
*/30 * * * * /scripts/backup.sh
```

## Backup Storage Structure

```
s3://bucket/
└── backups/
    └── {BACKUP_FOLDER_NAME}/
        ├── backup-2025-11-17_14-00-00.tar.gz
        ├── backup-2025-11-17_14-30-00.tar.gz
        └── backup-2025-11-17_15-00-00.tar.gz
```
