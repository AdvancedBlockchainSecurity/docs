#!/bin/bash
#
# BVD Pattern Code Migration - Execution Script
#
# This script executes the complete BVD pattern code migration including:
# - Pre-migration checks
# - Database backup
# - SQL migration execution
# - Post-migration verification
# - Service restart
#
# Usage:
#   chmod +x execute_bvd_migration.sh
#   ./execute_bvd_migration.sh
#

set -e  # Exit on error

# Configuration
DB_NAME="solidity_security"
DB_USER="blocksecops"
BACKUP_DIR="/Users/pwner/Git/ABS/database/backups/bvd-migration-$(date +%Y%m%d)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
MIGRATION_SQL="/Users/pwner/Git/ABS/blocksecops-api-service/alembic/versions/20251028_1230_add_bvd_prefix_to_pattern_codes.sql"
ROLLBACK_SQL="/Users/pwner/Git/ABS/blocksecops-api-service/alembic/versions/20251028_1230_rollback_bvd_prefix.sql"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 command not found. Please install PostgreSQL client tools."
        exit 1
    fi
}

pause_for_confirmation() {
    echo ""
    read -p "Press Enter to continue or Ctrl+C to abort..."
    echo ""
}

# Header
echo "================================================================================"
echo "                    BVD PATTERN CODE MIGRATION"
echo "================================================================================"
echo ""
echo "Database: $DB_NAME"
echo "User: $DB_USER"
echo "Migration: Pattern codes REE-001 → BVD-EVM-REE-001 (all 60 patterns)"
echo "Timestamp: $TIMESTAMP"
echo ""
echo "================================================================================"
echo ""

# Step 0: Pre-flight checks
log_info "Step 0/9: Pre-flight checks..."

check_command "psql"
check_command "pg_dump"

# Check if database is accessible
if ! psql -U $DB_USER -d $DB_NAME -c "SELECT 1;" > /dev/null 2>&1; then
    log_error "Cannot connect to database $DB_NAME as user $DB_USER"
    log_error "Please check your database connection settings"
    exit 1
fi

log_success "Database connection verified"

# Check if migration SQL exists
if [ ! -f "$MIGRATION_SQL" ]; then
    log_error "Migration SQL file not found: $MIGRATION_SQL"
    exit 1
fi

log_success "Migration SQL file found"

# Check if rollback SQL exists
if [ ! -f "$ROLLBACK_SQL" ]; then
    log_error "Rollback SQL file not found: $ROLLBACK_SQL"
    exit 1
fi

log_success "Rollback SQL file found"
log_success "Pre-flight checks passed"
echo ""

pause_for_confirmation

# Step 1: Display current state
log_info "Step 1/9: Checking current state..."

PATTERN_COUNT=$(psql -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM vulnerability_patterns;")
VULN_COUNT=$(psql -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM vulnerabilities;")
OLD_FORMAT_COUNT=$(psql -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM vulnerability_patterns WHERE code NOT LIKE 'BVD-%';")

echo "   Patterns in database: $PATTERN_COUNT"
echo "   Vulnerabilities: $VULN_COUNT"
echo "   Patterns without BVD- prefix: $OLD_FORMAT_COUNT"
echo ""

if [ "$OLD_FORMAT_COUNT" -eq 0 ]; then
    log_warning "All patterns already have BVD- prefix. Migration may have already been applied."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Migration aborted by user"
        exit 0
    fi
fi

echo "   Sample current patterns:"
psql -U $DB_USER -d $DB_NAME -c "SELECT code, name FROM vulnerability_patterns ORDER BY code LIMIT 5;"
echo ""

pause_for_confirmation

# Step 2: Create backup directory
log_info "Step 2/9: Creating backup directory..."

mkdir -p "$BACKUP_DIR"
log_success "Backup directory created: $BACKUP_DIR"
echo ""

# Step 3: Full database backup
log_info "Step 3/9: Creating full database backup..."
log_warning "This may take several minutes depending on database size..."

FULL_BACKUP="$BACKUP_DIR/solidity_security_full_backup_$TIMESTAMP.dump"
pg_dump -U $DB_USER -d $DB_NAME -Fc -f "$FULL_BACKUP"

if [ -f "$FULL_BACKUP" ]; then
    BACKUP_SIZE=$(du -h "$FULL_BACKUP" | cut -f1)
    log_success "Full backup created: $FULL_BACKUP ($BACKUP_SIZE)"
else
    log_error "Full backup failed"
    exit 1
fi
echo ""

# Step 4: Table-specific backups
log_info "Step 4/9: Creating table-specific backups..."

PATTERNS_BACKUP="$BACKUP_DIR/vulnerability_patterns_backup_$TIMESTAMP.sql"
VULNS_BACKUP="$BACKUP_DIR/vulnerabilities_backup_$TIMESTAMP.sql"

pg_dump -U $DB_USER -d $DB_NAME -t vulnerability_patterns -f "$PATTERNS_BACKUP"
log_success "Patterns backup: $PATTERNS_BACKUP"

pg_dump -U $DB_USER -d $DB_NAME -t vulnerabilities -f "$VULNS_BACKUP"
log_success "Vulnerabilities backup: $VULNS_BACKUP"
echo ""

# Step 5: Export current data
log_info "Step 5/9: Exporting current pattern data for reference..."

PATTERNS_CSV="$BACKUP_DIR/patterns_before_migration.csv"
psql -U $DB_USER -d $DB_NAME -c "
COPY (
  SELECT code, name, category, severity
  FROM vulnerability_patterns
  ORDER BY code
) TO '$PATTERNS_CSV' WITH CSV HEADER;
"
log_success "Pattern data exported: $PATTERNS_CSV"

FINDINGS_CSV="$BACKUP_DIR/findings_by_pattern.csv"
psql -U $DB_USER -d $DB_NAME -c "
COPY (
  SELECT pattern_code, COUNT(*) as finding_count
  FROM vulnerabilities
  WHERE pattern_code IS NOT NULL
  GROUP BY pattern_code
  ORDER BY pattern_code
) TO '$FINDINGS_CSV' WITH CSV HEADER;
"
log_success "Findings data exported: $FINDINGS_CSV"
echo ""

pause_for_confirmation

# Step 6: Check for active scans
log_info "Step 6/9: Checking for active scans..."

ACTIVE_SCANS=$(psql -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM scans WHERE status = 'running';")

if [ "$ACTIVE_SCANS" -gt 0 ]; then
    log_warning "Found $ACTIVE_SCANS active scan(s) running"
    log_warning "It's recommended to wait for scans to complete or stop the application"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Migration aborted by user"
        exit 0
    fi
else
    log_success "No active scans found"
fi
echo ""

# Step 7: Execute migration
log_info "Step 7/9: Executing SQL migration..."
log_warning "This will update all pattern codes with BVD- prefix"
echo ""

pause_for_confirmation

log_info "Running migration SQL..."

if psql -U $DB_USER -d $DB_NAME -f "$MIGRATION_SQL"; then
    log_success "Migration SQL executed successfully"
else
    log_error "Migration failed!"
    log_error "Database may be in inconsistent state"
    log_error "To rollback, run: psql -U $DB_USER -d $DB_NAME -f $ROLLBACK_SQL"
    exit 1
fi
echo ""

# Step 8: Verify migration
log_info "Step 8/9: Verifying migration results..."

BVD_PATTERN_COUNT=$(psql -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM vulnerability_patterns WHERE code LIKE 'BVD-%';")
OLD_PATTERN_COUNT=$(psql -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM vulnerability_patterns WHERE code NOT LIKE 'BVD-%';")
BVD_VULN_COUNT=$(psql -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM vulnerabilities WHERE pattern_code LIKE 'BVD-%';")
OLD_VULN_COUNT=$(psql -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM vulnerabilities WHERE pattern_code NOT LIKE 'BVD-%' AND pattern_code IS NOT NULL;")

echo "   Verification Results:"
echo "   ---------------------"
echo "   Patterns with BVD- prefix: $BVD_PATTERN_COUNT"
echo "   Patterns without BVD- prefix: $OLD_PATTERN_COUNT"
echo "   Vulnerabilities with BVD- codes: $BVD_VULN_COUNT"
echo "   Vulnerabilities with old codes: $OLD_VULN_COUNT"
echo ""

if [ "$OLD_PATTERN_COUNT" -gt 0 ]; then
    log_error "Migration incomplete: $OLD_PATTERN_COUNT patterns still without BVD- prefix"
    log_error "Rolling back migration..."
    psql -U $DB_USER -d $DB_NAME -f "$ROLLBACK_SQL"
    exit 1
fi

log_success "All patterns successfully migrated to BVD- format"

# Show sample migrated patterns
echo ""
echo "   Sample migrated patterns:"
psql -U $DB_USER -d $DB_NAME -c "SELECT code, name FROM vulnerability_patterns ORDER BY code LIMIT 10;"
echo ""

# Step 9: Post-migration instructions
log_info "Step 9/9: Post-migration steps..."
echo ""
echo "   Next steps:"
echo "   1. Restart API service to load new pattern codes"
echo "   2. Test application functionality"
echo "   3. Monitor for any issues"
echo ""
echo "   Service restart commands:"
echo "   -------------------------"
echo "   Docker Compose: docker-compose restart api-service"
echo "   Kubernetes: kubectl rollout restart deployment/blocksecops-api-service"
echo "   Systemd: sudo systemctl restart blocksecops-api-service"
echo ""

# Success summary
echo "================================================================================"
log_success "MIGRATION COMPLETE!"
echo "================================================================================"
echo ""
echo "Summary:"
echo "--------"
echo "✅ Backups created in: $BACKUP_DIR"
echo "✅ Patterns migrated: $BVD_PATTERN_COUNT"
echo "✅ Vulnerabilities updated: $BVD_VULN_COUNT"
echo "✅ All pattern codes now use BVD- prefix"
echo ""
echo "Backup files:"
echo "- Full backup: $FULL_BACKUP"
echo "- Patterns backup: $PATTERNS_BACKUP"
echo "- Vulnerabilities backup: $VULNS_BACKUP"
echo "- Pattern data: $PATTERNS_CSV"
echo "- Findings data: $FINDINGS_CSV"
echo ""
echo "Rollback (if needed):"
echo "  psql -U $DB_USER -d $DB_NAME -f $ROLLBACK_SQL"
echo ""
echo "================================================================================"
