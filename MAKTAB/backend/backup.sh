#!/bin/bash
# Backup script for self-hosted Maktab Manager SQLite database

BACKUP_DIR="$(dirname "$0")/backups"
mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
DB_FILE="$(dirname "$0")/maktab_backend.db"
BACKUP_FILE="$BACKUP_DIR/maktab_backend_$TIMESTAMP.db"

if [ -f "$DB_FILE" ]; then
    cp "$DB_FILE" "$BACKUP_FILE"
    echo "Backup completed successfully: $BACKUP_FILE"
else
    echo "Error: Database file $DB_FILE not found."
fi
