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
