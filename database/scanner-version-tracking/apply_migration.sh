#!/bin/bash
# Apply Scanner Version Tracking Migration
# Usage: ./apply_migration.sh [--dry-run]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false

# Parse arguments
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "🔍 DRY RUN MODE - No changes will be applied"
fi

# Database connection settings
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-solidity_security}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-postgres}"

# Export for psql
export PGPASSWORD="$DB_PASSWORD"

echo "================================"
echo "Scanner Version Tracking Migration"
echo "================================"
echo "Database: $DB_NAME"
echo "Host: $DB_HOST:$DB_PORT"
echo "User: $DB_USER"
echo ""

# Check if database is accessible
echo "🔍 Checking database connection..."
if ! psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
    echo "❌ Error: Cannot connect to database"
    echo "Make sure PostgreSQL is running and credentials are correct"
    exit 1
fi
echo "✅ Database connection successful"
echo ""

# Create backup
BACKUP_FILE="$SCRIPT_DIR/../backups/pre_scanner_tracking_$(date +%Y%m%d_%H%M%S).dump"
echo "📦 Creating backup: $BACKUP_FILE"
mkdir -p "$(dirname "$BACKUP_FILE")"
pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -Fc -f "$BACKUP_FILE"
echo "✅ Backup created successfully"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "🔍 DRY RUN - Would apply schema..."
    echo "Schema file: $SCRIPT_DIR/schema.sql"
    echo "Data file: $SCRIPT_DIR/initial_data.sql"
    echo ""
    echo "To apply for real, run without --dry-run flag"
    exit 0
fi

# Apply schema
echo "🔨 Applying schema..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$SCRIPT_DIR/schema.sql"
echo "✅ Schema applied successfully"
echo ""

# Load initial data
echo "📊 Loading initial scanner data..."
psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$SCRIPT_DIR/initial_data.sql"
echo "✅ Initial data loaded successfully"
echo ""

# Verify migration
echo "🔍 Verifying migration..."
SCANNER_COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM scanner_versions;")
echo "Scanners loaded: $(echo $SCANNER_COUNT | tr -d ' ')"

HISTORY_COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM scanner_version_history;")
echo "History entries: $(echo $HISTORY_COUNT | tr -d ' ')"

echo ""
echo "================================"
echo "✅ Migration Complete!"
echo "================================"
echo ""
echo "Quick queries to try:"
echo "  psql -d $DB_NAME -c 'SELECT * FROM scanner_version_status;'"
echo "  psql -d $DB_NAME -c 'SELECT * FROM outdated_scanners;'"
echo "  psql -d $DB_NAME -c 'SELECT * FROM scanner_version_history ORDER BY updated_at DESC;'"
echo ""
echo "Backup location: $BACKUP_FILE"
