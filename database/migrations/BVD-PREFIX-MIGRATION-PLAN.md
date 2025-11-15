# BVD Pattern Code Migration Plan

**Date**: 2025-10-28
**Migration Type**: Pattern Code Prefix Addition
**Risk Level**: Low-Medium (Configuration + Data)
**Estimated Duration**: 30-45 minutes
**Rollback Strategy**: Automated SQL rollback script

---

## Executive Summary

Add "BVD-" prefix to all vulnerability pattern codes to establish the **Blockchain Vulnerability Database (BVD)** naming convention. This prepares the platform for future BVD service integration and creates a unique, brandable identifier for vulnerability classifications.

**Change**: `REE-001` → `BVD-EVM-REE-001` (all 60 patterns)

---

## Scope of Changes

### Files Affected
1. **Configuration**: `blocksecops-api-service/seeds/vulnerability_patterns.json`
2. **Database Tables**:
   - `vulnerability_patterns` (pattern catalog)
   - `vulnerabilities` (scan findings)
3. **Documentation**: Schema docs, API docs, references

### Data Impact
- **Pattern Definitions**: 60 patterns
- **Pattern Mappings**: 64 detector mappings
- **Database Records**: All existing vulnerability findings (~1 week of data)

---

## Pre-Migration Checklist

### 1. Verify Current State
```bash
# Check database connection
psql -U blocksecops -d blocksecops -c "SELECT version();"

# Count existing pattern records
psql -U blocksecops -d blocksecops -c "
SELECT
  'Pattern Catalog' as table_name,
  COUNT(*) as count
FROM vulnerability_patterns
UNION ALL
SELECT
  'Vulnerabilities' as table_name,
  COUNT(*) as count
FROM vulnerabilities;
"

# List current pattern codes
psql -U blocksecops -d blocksecops -c "
SELECT code, name
FROM vulnerability_patterns
ORDER BY code
LIMIT 10;
"
```

### 2. Environment Check
- [ ] Database is accessible
- [ ] Database user has UPDATE permissions
- [ ] Sufficient disk space for backup (check: `df -h`)
- [ ] No active scans running (check: `SELECT COUNT(*) FROM scans WHERE status = 'running';`)
- [ ] Application can be temporarily paused/stopped

### 3. Backup Verification
```bash
# Create backup directory
mkdir -p /Users/pwner/Git/ABS/database/backups/bvd-migration-$(date +%Y%m%d)

# Verify backup tools available
which pg_dump
which psql

# Test backup command (dry run)
pg_dump -U blocksecops -d blocksecops --schema-only -f /tmp/test_backup.sql
```

---

## Migration Steps

### Step 1: Backup Database (15 minutes)

#### 1.1 Full Database Backup
```bash
cd /Users/pwner/Git/ABS/database/backups/bvd-migration-$(date +%Y%m%d)

# Full backup (structure + data)
pg_dump -U blocksecops -d blocksecops -Fc \
  -f "blocksecops_full_backup_$(date +%Y%m%d_%H%M%S).dump"

# Verify backup created
ls -lh blocksecops_full_backup_*.dump

# Test restore capability (to verify backup)
pg_restore --list blocksecops_full_backup_*.dump | head -20
```

#### 1.2 Table-Specific Backups
```bash
# Backup vulnerability_patterns table
pg_dump -U blocksecops -d blocksecops -t vulnerability_patterns \
  -f "vulnerability_patterns_backup_$(date +%Y%m%d_%H%M%S).sql"

# Backup vulnerabilities table
pg_dump -U blocksecops -d blocksecops -t vulnerabilities \
  -f "vulnerabilities_backup_$(date +%Y%m%d_%H%M%S).sql"

# Verify backups
ls -lh *_backup_*.sql
```

#### 1.3 Export Current Pattern Data
```bash
# Export current pattern codes for reference
psql -U blocksecops -d blocksecops -c "
COPY (
  SELECT code, name, category, severity
  FROM vulnerability_patterns
  ORDER BY code
) TO '/Users/pwner/Git/ABS/database/backups/bvd-migration-$(date +%Y%m%d)/patterns_before_migration.csv'
WITH CSV HEADER;
"

# Export vulnerability findings count by pattern
psql -U blocksecops -d blocksecops -c "
COPY (
  SELECT pattern_code, COUNT(*) as finding_count
  FROM vulnerabilities
  WHERE pattern_code IS NOT NULL
  GROUP BY pattern_code
  ORDER BY pattern_code
) TO '/Users/pwner/Git/ABS/database/backups/bvd-migration-$(date +%Y%m%d)/findings_by_pattern.csv'
WITH CSV HEADER;
"
```

### Step 2: Update Configuration Files (5 minutes)

#### 2.1 Run Migration Script
```bash
cd /Users/pwner/Git/ABS/blocksecops-api-service

# Execute migration
python3 scripts/migrate_to_bvd_pattern_codes.py --execute
```

**Expected Output**:
```
✅ Migration preparation complete!

Files updated:
   ✓ seeds/vulnerability_patterns.json
   ✓ seeds/vulnerability_patterns.json.backup-YYYYMMDD_HHMMSS
   ✓ alembic/versions/YYYYMMDD_HHMM_add_bvd_prefix_to_pattern_codes.sql
   ✓ alembic/versions/YYYYMMDD_HHMM_rollback_bvd_prefix.sql
```

#### 2.2 Verify JSON Changes
```bash
# Verify pattern codes updated
grep -o '"id": "BVD-[A-Z]*-[0-9]*"' seeds/vulnerability_patterns.json | head -10

# Count BVD patterns
grep -c '"id": "BVD-' seeds/vulnerability_patterns.json
# Expected: 60

# Verify no old pattern codes remain
grep '"id": "[A-Z][A-Z][A-Z]-[0-9]' seeds/vulnerability_patterns.json | grep -v BVD
# Expected: No output (empty)
```

### Step 3: Stop Application Services (2 minutes)

```bash
# Stop API service (prevents new writes during migration)
# Adjust command based on your deployment:

# If using Docker Compose:
docker-compose -f docker-compose.yml stop api-service

# If using Kubernetes:
kubectl scale deployment blocksecops-api-service --replicas=0 -n blocksecops

# If using systemd:
sudo systemctl stop blocksecops-api-service

# Verify no active connections
psql -U blocksecops -d blocksecops -c "
SELECT COUNT(*) as active_connections
FROM pg_stat_activity
WHERE datname = 'blocksecops' AND state = 'active';
"
```

### Step 4: Execute Database Migration (10 minutes)

#### 4.1 Run Migration SQL
```bash
cd /Users/pwner/Git/ABS/blocksecops-api-service/alembic/versions

# Review migration SQL first
cat *_add_bvd_prefix_to_pattern_codes.sql | head -50

# Execute migration
psql -U blocksecops -d blocksecops -f *_add_bvd_prefix_to_pattern_codes.sql
```

**Expected Output**:
```
BEGIN
UPDATE 60  -- vulnerability_patterns updates
UPDATE 150 -- vulnerabilities updates (approximate, depends on scan history)
...
COMMIT
```

#### 4.2 Manual Verification Queries
```bash
psql -U blocksecops -d blocksecops <<EOF

-- Check all patterns have BVD prefix
SELECT
  COUNT(*) as total_patterns,
  COUNT(*) FILTER (WHERE code LIKE 'BVD-%') as bvd_patterns,
  COUNT(*) FILTER (WHERE code NOT LIKE 'BVD-%') as non_bvd_patterns
FROM vulnerability_patterns;

-- Should show: total_patterns=60, bvd_patterns=60, non_bvd_patterns=0

-- Check vulnerability findings updated
SELECT
  COUNT(*) as total_findings,
  COUNT(*) FILTER (WHERE pattern_code LIKE 'BVD-%') as bvd_findings,
  COUNT(*) FILTER (WHERE pattern_code NOT LIKE 'BVD-%' AND pattern_code IS NOT NULL) as old_findings
FROM vulnerabilities;

-- Should show: old_findings=0

-- List updated pattern codes (sample)
SELECT code, name
FROM vulnerability_patterns
ORDER BY code
LIMIT 10;

EOF
```

### Step 5: Update Documentation (5 minutes)

#### 5.1 Update Schema Documentation
```bash
cd /Users/pwner/Git/ABS/database

# Document the migration
cat >> SCHEMA.md <<EOF

## Pattern Code Format Change (2025-10-28)

As of 2025-10-28, all vulnerability pattern codes use the BVD prefix:
- **Old Format**: REE-001, ACC-001, etc.
- **New Format**: BVD-EVM-REE-001, BVD-EVM-ACC-001, etc.

**BVD** = Blockchain Vulnerability Database

All historical data has been migrated to use the new format.
EOF
```

#### 5.2 Update API Documentation
```bash
# Update any API docs referencing pattern codes
# Example locations:
# - API route documentation
# - OpenAPI/Swagger specs
# - Client SDKs
# - Integration guides
```

### Step 6: Restart Application Services (3 minutes)

```bash
# Restart API service

# If using Docker Compose:
docker-compose -f docker-compose.yml start api-service

# If using Kubernetes:
kubectl scale deployment blocksecops-api-service --replicas=3 -n blocksecops

# If using systemd:
sudo systemctl start blocksecops-api-service

# Verify service health
curl http://localhost:8000/health

# Check logs for any errors
docker-compose logs -f api-service --tail=50
# OR
kubectl logs -f deployment/blocksecops-api-service -n blocksecops --tail=50
```

### Step 7: Post-Migration Verification (5 minutes)

#### 7.1 Test Pattern Matching
```bash
# Test that intelligence service loads patterns correctly
curl -X POST http://localhost:8000/api/v1/scans/test-pattern-loading

# Or check via application logs
grep "Loaded.*patterns" /var/log/blocksecops/api-service.log
```

#### 7.2 Run Integration Tests
```bash
cd /Users/pwner/Git/ABS/blocksecops-api-service

# Test pattern integration
python3 scripts/test_semgrep_integration.py

# Expected: All tests pass with BVD- prefixes
```

#### 7.3 Verify Sample Scan
```bash
# Trigger a test scan
curl -X POST http://localhost:8000/api/v1/scans \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "test-project",
    "scanner_id": "slither",
    "contract_code": "..."
  }'

# Check that findings use new pattern codes
psql -U blocksecops -d blocksecops -c "
SELECT pattern_code, title
FROM vulnerabilities
ORDER BY created_at DESC
LIMIT 5;
"

# Should show: BVD-EVM-REE-001, BVD-EVM-ACC-001, etc.
```

---

## Rollback Procedure

If issues occur, execute rollback:

### Quick Rollback (5 minutes)
```bash
cd /Users/pwner/Git/ABS/blocksecops-api-service/alembic/versions

# Stop application
docker-compose stop api-service

# Execute rollback SQL
psql -U blocksecops -d blocksecops -f *_rollback_bvd_prefix.sql

# Restore JSON backup
cp seeds/vulnerability_patterns.json.backup-YYYYMMDD_HHMMSS \
   seeds/vulnerability_patterns.json

# Restart application
docker-compose start api-service
```

### Full Database Restore (15 minutes)
```bash
cd /Users/pwner/Git/ABS/database/backups/bvd-migration-YYYYMMDD

# Stop application
docker-compose stop api-service

# Drop and recreate database (CAUTION)
psql -U postgres -c "DROP DATABASE blocksecops;"
psql -U postgres -c "CREATE DATABASE blocksecops OWNER blocksecops;"

# Restore from backup
pg_restore -U blocksecops -d blocksecops blocksecops_full_backup_*.dump

# Restart application
docker-compose start api-service
```

---

## Risk Assessment

### Low Risk
- ✅ Configuration change (JSON file)
- ✅ Simple string prefix addition
- ✅ No schema changes (column types unchanged)
- ✅ Automated rollback available
- ✅ Full backups before migration

### Medium Risk
- ⚠️ Updates production data (~1 week of scans)
- ⚠️ Requires application downtime (2-5 minutes)
- ⚠️ External integrations may reference old codes

### Mitigation
- 🛡️ Comprehensive backups before migration
- 🛡️ Automated rollback script generated
- 🛡️ Verification steps at each stage
- 🛡️ Test migration on staging first (recommended)

---

## Communication Plan

### Before Migration
- [ ] Notify team of scheduled maintenance window
- [ ] Post notice in team Slack/Discord
- [ ] Email stakeholders about downtime

### During Migration
- [ ] Update status page (if applicable)
- [ ] Monitor logs in real-time
- [ ] Keep communication channel open

### After Migration
- [ ] Announce completion
- [ ] Share verification results
- [ ] Update documentation links

---

## Timeline

| Step | Duration | Task |
|------|----------|------|
| 0 | 10 min | Pre-migration checks |
| 1 | 15 min | Backup database |
| 2 | 5 min | Update configuration files |
| 3 | 2 min | Stop application services |
| 4 | 10 min | Execute database migration |
| 5 | 5 min | Update documentation |
| 6 | 3 min | Restart application services |
| 7 | 5 min | Post-migration verification |
| **Total** | **55 min** | *Includes buffer time* |

**Recommended Window**: Schedule 1 hour maintenance window

---

## Success Criteria

✅ **Migration Successful If**:
1. All 60 patterns updated to BVD- prefix
2. All vulnerability findings updated (pattern_code column)
3. No old pattern codes remain in database
4. Application starts without errors
5. Pattern matching works (integration tests pass)
6. New scans create findings with BVD- codes
7. Historical findings remain accessible

❌ **Rollback Required If**:
1. Database migration fails mid-transaction
2. Application fails to start after migration
3. Pattern matching breaks (tests fail)
4. Data integrity issues detected
5. Critical external integration breaks

---

## Testing Strategy

### Pre-Production Testing (Recommended)
```bash
# If you have a staging environment:
# 1. Clone production database to staging
# 2. Run full migration on staging
# 3. Verify all steps work
# 4. Test application functionality
# 5. Then proceed with production
```

### Post-Migration Testing
1. ✅ Load patterns from JSON (application startup)
2. ✅ Run integration tests (pattern matching)
3. ✅ Execute test scan (Slither on sample contract)
4. ✅ Verify findings use BVD- codes
5. ✅ Check deduplication still works
6. ✅ Verify enrichment metadata loads
7. ✅ Test API endpoints returning patterns

---

## External Dependencies

### Systems to Update After Migration
- [ ] API documentation (Swagger/OpenAPI specs)
- [ ] Client SDKs (if pattern codes are hardcoded)
- [ ] Monitoring dashboards (Grafana queries)
- [ ] Reporting tools (if filtering by pattern code)
- [ ] Integration partners (if they reference pattern codes)

### Third-Party Integrations
- Check if any external systems consume pattern codes
- Update integration documentation
- Notify partners of change (if applicable)

---

## Appendix

### A. Pattern Code Format

**Old Format**:
```
REE-001  (Reentrancy)
ACC-001  (Access Control)
INT-001  (Integer Overflow)
```

**New Format**:
```
BVD-EVM-REE-001  (Blockchain Vulnerability Database - Reentrancy)
BVD-EVM-ACC-001  (Blockchain Vulnerability Database - Access Control)
BVD-EVM-INT-001  (Blockchain Vulnerability Database - Integer Overflow)
```

### B. Database Schema

**`vulnerability_patterns` table**:
```sql
id                UUID PRIMARY KEY
code              VARCHAR(50)  -- Changed: "REE-001" → "BVD-EVM-REE-001"
name              VARCHAR(255)
category          VARCHAR(100)
severity          VARCHAR(20)
-- ... other fields
```

**`vulnerabilities` table**:
```sql
id                UUID PRIMARY KEY
pattern_code      VARCHAR(50)  -- Changed: "REE-001" → "BVD-EVM-REE-001"
pattern_id        UUID REFERENCES vulnerability_patterns(id)
fingerprint_hash  VARCHAR(64)
-- ... other fields
```

### C. Example Migration SQL

```sql
-- Sample of what the migration does:
UPDATE vulnerability_patterns SET code = 'BVD-EVM-REE-001' WHERE code = 'REE-001';
UPDATE vulnerabilities SET pattern_code = 'BVD-EVM-REE-001' WHERE pattern_code = 'REE-001';
```

### D. Verification Queries

```sql
-- Count patterns by prefix
SELECT
  CASE
    WHEN code LIKE 'BVD-%' THEN 'BVD Prefixed'
    ELSE 'Old Format'
  END as format,
  COUNT(*) as count
FROM vulnerability_patterns
GROUP BY format;

-- List all pattern codes
SELECT code, name FROM vulnerability_patterns ORDER BY code;

-- Check findings by pattern
SELECT pattern_code, COUNT(*) FROM vulnerabilities
WHERE pattern_code IS NOT NULL
GROUP BY pattern_code
ORDER BY pattern_code;
```

---

## Sign-Off

**Prepared By**: Claude (AI Assistant)
**Review Required**: Database Administrator, DevOps Lead, Engineering Manager
**Approval Required**: Technical Lead, Product Owner

**Pre-Migration Sign-Off**:
- [ ] Database Administrator
- [ ] DevOps Lead
- [ ] Engineering Manager

**Post-Migration Verification**:
- [ ] All tests passed
- [ ] Application operational
- [ ] Data integrity confirmed

---

**Migration Plan Version**: 1.0
**Last Updated**: 2025-10-28
**Next Review**: After successful migration
