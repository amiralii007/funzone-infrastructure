#!/bin/bash
set -e

echo "🔍 FunZone Database Initialization Script"
echo "📦 Checking for FunZoneApp.backup file..."

# Check if backup file exists
if [ ! -f /docker-entrypoint-initdb.d/FunZoneApp.backup ]; then
    echo "ℹ️  FunZoneApp.backup not found. Database will be initialized as empty."
    exit 0
fi

echo "📦 Found FunZoneApp.backup file"

# At this point, PostgreSQL is already running and the database has been created
# by the PostgreSQL entrypoint script, but we're still in the initialization phase

# Check if database is empty (this script only runs on first initialization)
echo "🔍 Checking if database is empty..."
TABLE_COUNT=$(PGPASSWORD="${POSTGRES_PASSWORD}" psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null || echo "0")

if [ "$TABLE_COUNT" = "0" ] || [ -z "$TABLE_COUNT" ] || [ "$TABLE_COUNT" = "" ]; then
    echo "📥 Database is empty. Restoring from FunZoneApp.backup..."
    
    # Check if it's a custom format backup or SQL dump
    # Custom format backups start with "PGDMP" magic bytes
    BACKUP_FILE="/docker-entrypoint-initdb.d/FunZoneApp.backup"
    FILE_HEADER=$(head -c 5 "$BACKUP_FILE" 2>/dev/null || echo "")
    
    if [ "$FILE_HEADER" = "PGDMP" ]; then
        # Custom format backup - use pg_restore
        echo "📦 Detected PostgreSQL custom format backup. Using pg_restore..."
        if PGPASSWORD="${POSTGRES_PASSWORD}" pg_restore \
            -U "${POSTGRES_USER}" \
            -d "${POSTGRES_DB}" \
            -v \
            --no-owner \
            --no-acl \
            "$BACKUP_FILE" 2>&1; then
            echo "✅ Database restored successfully from FunZoneApp.backup!"
        else
            echo "❌ Failed to restore database from backup using pg_restore."
            echo "⚠️  Continuing with empty database. Check logs above for errors."
        fi
    else
        # SQL dump - use psql
        echo "📦 Detected SQL dump format. Using psql..."
        if PGPASSWORD="${POSTGRES_PASSWORD}" psql \
            -U "${POSTGRES_USER}" \
            -d "${POSTGRES_DB}" \
            -f "$BACKUP_FILE" 2>&1; then
            echo "✅ Database restored successfully from FunZoneApp.backup!"
        else
            echo "❌ Failed to restore database from backup using psql."
            echo "⚠️  Continuing with empty database. Check logs above for errors."
        fi
    fi
else
    echo "ℹ️  Database already contains data (${TABLE_COUNT} tables). Skipping restore."
fi

echo "✅ Database initialization complete!"

