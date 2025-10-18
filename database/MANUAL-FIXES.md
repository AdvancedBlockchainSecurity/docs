# Database Manual Fixes Log

**Purpose:** Track manual database fixes applied outside of Alembic migrations. These fixes are necessary when the database schema diverges from migration history.

**IMPORTANT:** All manual fixes documented here should be considered when recreating the database from scratch.

---

## October 16, 2025 - Add 'uploaded' Status to contract_status Enum

### Issue
After database recovery, tables were created by SQLAlchemy's automatic schema generation instead of running Alembic migrations. This meant migration `20251014_1400-002_add_uploaded_status.py` was never applied, leaving the `contract_status` enum without the 'uploaded' value.

**Symptom:** When uploading contracts via the API, the status showed as "pending" instead of "uploaded".

### Root Cause
- Database was recreated after corruption incident on October 16, 2025
- Tables were created by SQLAlchemy's `create_all()` method during API startup
- Alembic migrations were not successfully run
- Migration 002 adds 'uploaded' status before 'pending' in the enum

### Fix Applied
```sql
ALTER TYPE contract_status ADD VALUE IF NOT EXISTS 'uploaded' BEFORE 'pending';
```

### Verification
```sql
-- Check enum values
SELECT enumlabel FROM pg_enum
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'contract_status')
ORDER BY enumsortorder;

-- Expected result:
-- uploaded
-- pending
-- scanning
-- scanned
-- failed
```

### How to Reproduce Fix
If recreating the database:

```bash
# 1. Apply this fix after database initialization
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security \
  -c "ALTER TYPE contract_status ADD VALUE IF NOT EXISTS 'uploaded' BEFORE 'pending';"

# 2. Verify the fix
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security \
  -c "SELECT enumlabel FROM pg_enum WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'contract_status') ORDER BY enumsortorder;"
```

### Related Files
- Migration: `/Users/pwner/Git/ABS/blocksecops-api-service/alembic/versions/20251014_1400-002_add_uploaded_status.py`
- Upload endpoint: `/Users/pwner/Git/ABS/blocksecops-api-service/src/presentation/api/v1/endpoints/upload.py` (lines 179, 244)

### Impact
- **Before Fix:** Contracts showed "pending" status immediately after upload
- **After Fix:** Contracts correctly show "uploaded" status after upload
- **Status Flow:** uploaded → pending → scanning → scanned/failed

### Prevention
For future database recreations:
1. Always run Alembic migrations after database initialization
2. Verify all enum values match migration expectations
3. Test contract upload immediately after database setup
4. Check this MANUAL-FIXES.md document for any required manual fixes

---

## October 16, 2025 - Fix Contract Status Stuck at 'scanning'

### Issue
After triggering scans, the contract status remained at "scanning" even though the scans completed successfully with vulnerabilities detected.

**Symptom:** Contract detail page shows status as "scanning" (appears as "pending" in some UI contexts), but scans show status "completed" with vulnerabilities detected.

### Root Cause
- The tool-integration service's result collector did not successfully call the API's `/scans/{scan_id}/results` endpoint
- Scans completed and vulnerabilities were created through an alternate path or during testing
- The `store_scan_results` endpoint (lines 464-465 in `scans.py`) normally updates contract status from "scanning" → "scanned" when scan results are received
- This created a data inconsistency where scans completed but the contract status was not updated

### Fix Applied
```sql
UPDATE contracts SET status = 'scanned'
WHERE id = '86f9a16f-7896-4115-b321-adf9db382682';
```

### Verification
```sql
-- Check contract status and associated scan statuses
SELECT c.id, c.name, c.status, COUNT(s.id) as scan_count, MAX(s.status) as latest_scan_status
FROM contracts c
LEFT JOIN scans s ON c.id = s.contract_id
WHERE c.id = '86f9a16f-7896-4115-b321-adf9db382682'
GROUP BY c.id;

-- Expected result:
-- Contract status: scanned
-- All scans: completed or failed
-- No scans with status: queued or running
```

### How to Reproduce Fix
If contract status is stuck at "scanning" after scans complete:

```bash
# 1. Identify contracts stuck in scanning status
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security \
  -c "SELECT c.id, c.name, c.status, COUNT(s.id) as scan_count
      FROM contracts c
      LEFT JOIN scans s ON c.id = s.contract_id
      WHERE c.status = 'scanning'
      GROUP BY c.id;"

# 2. Check if all scans for the contract are completed/failed
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security \
  -c "SELECT id, status FROM scans WHERE contract_id = '<CONTRACT_ID>';"

# 3. If all scans are completed/failed, update contract status
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security \
  -c "UPDATE contracts SET status = 'scanned' WHERE id = '<CONTRACT_ID>' RETURNING id, name, status;"
```

### Related Files
- Scan results endpoint: `/Users/pwner/Git/ABS/blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py` (lines 377-490, especially 464-465)
- Contract detail page: `/Users/pwner/Git/ABS/blocksecops-dashboard/src/pages/ContractDetail.tsx`

### Impact
- **Before Fix:** Contract status shows "scanning" indefinitely, even after scans complete
- **After Fix:** Contract status correctly shows "scanned" after scan completion
- **Status Flow:** uploaded → pending → scanning → **scanned**/failed

### Prevention
For future operations:
1. Ensure tool-integration service's result collector successfully calls `/scans/{scan_id}/results`
2. Monitor for contracts stuck in "scanning" status
3. Implement health check to detect status inconsistencies
4. Consider adding a database trigger or scheduled job to auto-update contract status when all scans are final

### Technical Details
The contract status should automatically update when the tool-integration service calls:
```
POST /api/v1/scans/{scan_id}/results
```

This endpoint updates both the scan status and contract status. If this endpoint is never called, the contract remains stuck at "scanning".

---

## October 18, 2025 - Populate scanner_id for Scanner Comparison Feature

### Issue
Scanner comparison page (`/scanners`) displayed zero data for all scanners despite having 43 vulnerabilities across 4 contracts. The `vulnerabilities.scanner_id` field was NULL for all vulnerabilities.

**Symptom:** Analytics query filtering by `scanner_id` returned zero results, showing all scanner statistics as 0.

### Root Cause
- Migration 004 added `scanner_id` field to vulnerabilities table
- Field was added as optional (nullable) to support backward compatibility
- Scan service was not updated to populate `scanner_id` when creating vulnerabilities
- All 43 existing vulnerabilities had `scanner_id = NULL`
- Analytics endpoint filtered by `scanner_id`, which matched nothing when NULL

**Technical Details:**
```python
# From analytics.py:478-485
stats_query = (
    select(...)
    .where(
        and_(
            ContractModel.user_id == user_id,
            VulnerabilityModel.scanner_id == scanner_id,  # NULL matched nothing
        )
    )
)
```

### Fix Applied
```sql
-- Backup created first
-- File: /Users/pwner/Git/ABS/backups/solidity_security_backup_20251018_114701.sql
-- Size: 135KB
-- Contains: 12 contracts, 31 scans, 43 vulnerabilities, 5 users

-- Populate scanner_id for all existing vulnerabilities
-- All vulnerabilities were detected by Slither scanner
UPDATE vulnerabilities SET scanner_id = 'slither' WHERE scanner_id IS NULL;
-- Updated 43 rows
```

### Verification
```sql
-- Check scanner_id distribution
SELECT scanner_id, COUNT(*) as count
FROM vulnerabilities
GROUP BY scanner_id
ORDER BY scanner_id NULLS FIRST;

-- Expected result:
-- scanner_id | count
-- -----------+-------
-- slither    |    43

-- Verify sample vulnerabilities
SELECT id, category, severity, scanner_id, scan_id
FROM vulnerabilities
LIMIT 5;

-- All rows should show scanner_id = 'slither'
```

### How to Reproduce Fix
If vulnerabilities have NULL scanner_id after database recreation:

```bash
# 1. Create backup first
BACKUP_FILE="solidity_security_backup_$(date +%Y%m%d_%H%M%S).sql"
kubectl exec -n postgresql-local postgresql-0 -- \
  pg_dump -U postgres -d solidity_security --clean --if-exists \
  > "/Users/pwner/Git/ABS/backups/${BACKUP_FILE}"

# 2. Verify backup
ls -lh "/Users/pwner/Git/ABS/backups/${BACKUP_FILE}"

# 3. Check current scanner_id status
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security \
  -c "SELECT scanner_id, COUNT(*) FROM vulnerabilities GROUP BY scanner_id;"

# 4. Populate scanner_id (adjust scanner based on actual scanner used)
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security \
  -c "UPDATE vulnerabilities SET scanner_id = 'slither' WHERE scanner_id IS NULL;"

# 5. Verify the fix
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security \
  -c "SELECT scanner_id, COUNT(*) FROM vulnerabilities GROUP BY scanner_id;"
```

### Related Files
- Migration: `/Users/pwner/Git/ABS/blocksecops-api-service/alembic/versions/004_add_scanner_tracking.py`
- Analytics endpoint: `/Users/pwner/Git/ABS/blocksecops-api-service/src/presentation/api/v1/endpoints/analytics.py` (lines 478-485)
- Scanner comparison page: `/Users/pwner/Git/ABS/blocksecops-dashboard/src/pages/ScannerComparison.tsx`
- Documentation: `/Users/pwner/Git/ABS/docs/SCANNER-COMPARISON-FIX-2025-10-18.md`

### Impact
- **Before Fix:** Scanner comparison showed all zeros (0 vulnerabilities for all scanners)
- **After Fix:** Scanner comparison displays actual vulnerability counts by scanner
- **Data Integrity:** All 43 vulnerabilities now properly attributed to Slither scanner

### Prevention
For future operations:
1. Update scan service to populate `scanner_id` when creating vulnerabilities
2. Add database constraint to make `scanner_id` NOT NULL (after fixing scan service)
3. Create Alembic migration to document this data fix
4. Add integration test to verify scanner_id is populated during scans
5. Consider adding a database trigger to prevent NULL scanner_id insertions

### Backup Information
**Location:** `/Users/pwner/Git/ABS/backups/solidity_security_backup_20251018_114701.sql`
**Size:** 135KB
**Created:** October 18, 2025 11:47:01 MDT
**Contents:**
- 12 contracts
- 31 scans
- 43 vulnerabilities
- 5 users

**Restore Command:**
```bash
# If rollback is needed
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security \
  < /Users/pwner/Git/ABS/backups/solidity_security_backup_20251018_114701.sql
```

### Future Work
1. **Scan Service Update Required:**
   File: `blocksecops-scan-service/src/domain/services/scan_orchestrator.py`

   Add scanner_id to vulnerability creation:
   ```python
   vulnerability = VulnerabilityModel(
       contract_id=contract_id,
       scan_id=scan.id,
       scanner_id=scanner.id,  # ADD THIS
       category=result.category,
       severity=result.severity,
       # ... other fields
   )
   ```

2. **Create Migration Script:**
   Create Alembic migration to document this fix:
   ```bash
   cd /Users/pwner/Git/ABS/blocksecops-api-service
   alembic revision -m "populate_scanner_id_for_existing_vulnerabilities"
   ```

3. **Add NOT NULL Constraint:**
   After scan service is updated, add constraint:
   ```sql
   ALTER TABLE vulnerabilities ALTER COLUMN scanner_id SET NOT NULL;
   ```

---

## Template for Future Manual Fixes

### [Date] - [Brief Description]

#### Issue
[Describe the problem and symptoms]

#### Root Cause
[Explain why manual fix was necessary]

#### Fix Applied
```sql
-- SQL commands run
```

#### Verification
```sql
-- How to verify the fix worked
```

#### How to Reproduce Fix
```bash
# Step-by-step commands
```

#### Related Files
- [List relevant migration files, code files, etc.]

#### Impact
- **Before Fix:** [behavior]
- **After Fix:** [behavior]

#### Prevention
[Steps to avoid needing this manual fix in the future]

---

## Notes

- All manual fixes should ideally be incorporated into migrations or initialization scripts
- This document serves as a safety net for database recovery scenarios
- When possible, prefer migration-based solutions over manual fixes
- Always create a backup before applying manual fixes
