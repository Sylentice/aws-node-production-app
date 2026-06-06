#!/bin/bash
BACKUP_DIR="/var/www/myapp/backups"
S3_BUCKET="s3://shaylyn-myapp-db-backups-752824437228"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
FILENAME="myapp_backup_$TIMESTAMP.sql"

mkdir -p "$BACKUP_DIR"

/usr/bin/docker exec -t myapp_db pg_dump -U postgres myapp > "$BACKUP_DIR/$FILENAME"
/usr/local/bin/aws s3 cp "$BACKUP_DIR/$FILENAME" "$S3_BUCKET/$FILENAME"

find "$BACKUP_DIR" -name "myapp_backup_*.sql" -mtime +7 -delete
