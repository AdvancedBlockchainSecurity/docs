# Database Reset Plan - Development Environment
**Date:** November 5, 2025
**Purpose:** Complete reset of development database to eliminate stale test data with null scanner_ids
**Environment:** Local Development (postgresql-local namespace)
**Risk Level:** LOW (Development only, no production impact)

## Executive Summary

All 57 scans in the development database have `scanner_ids: null`, indicating they were created before the strict scanner selection implementation. This plan provides a safe, documented process to reset the database while preserving:
- Schema documentation
- Migration history
- Vulnerability pattern database
- Recovery procedures

## Problem Statement

### Current State
- **Total Scans:** 57 (100% have `scanner_ids: null`)
- **Total Contracts:** 12
- **Date Range:** October 16 - November 5, 2025
- **Issue:** All data predates strict scanner selection fixes
- **Impact:** Stale test data causing confusion (e.g., vulnerabilities appearing on scans that reported 0 findings)

### Root Cause
Development database contains test data from before these implementations:
1. Strict scanner selection (no defaults/fallbacks)
2. Explicit scanner_ids tracking in scans table
3. localStorage auto-loading prevention

### Why Reset vs. Selective Deletion
- **100% of data** is pre-strict-scanner-selection
- Selective deletion would be more work than complete reset
- Clean slate ensures no schema inconsistencies
- Fresh start for testing new features

## Objectives

### Primary Goals
1. ✅ **Backup current database state** (data + schema)
2. ✅ **Document current schema** (update SCHEMA.md if needed)
3. ✅ **Delete PostgreSQL PVC** to remove all data
4. ✅ **Verify clean recreation** with migrations
5. ✅ **Validate strict scanner selection** with fresh test scan

### Secondary Goals
- Create rollback procedures
- Document database reset procedures for future use
- Update BACKUPS.md with new backup
- Verify vulnerability pattern database is preserved (in codebase JSON)

## Pre-Reset Checklist

### 1. Verify Current State
```bash
# Confirm all scans have null scanner_ids
curl -s -b /tmp/cookies.txt "http://127.0.0.1:8000/api/v1/scans?limit=100" | \
  jq '[.scans[] | select(.scanner_ids != null)] | length'
# Expected: 0

# Count total scans and contracts
curl -s -b /tmp/cookies.txt "http://127.0.0.1:8000/api/v1/scans?limit=100" | jq '.scans | length'
curl -s -b /tmp/cookies.txt "http://127.0.0.1:8000/api/v1/contracts?limit=100" | jq '.contracts | length'
```

### 2. Backup Existing Data
```bash
# Create backup directory
mkdir -p /Users/pwner/Git/ABS/database/backups/pre-reset-20251105

# Backup via pg_dump
kubectl exec -n postgresql-local postgresql-0 -- \
  pg_dump -U blocksecops -d solidity_security --no-owner --no-privileges \
  > /Users/pwner/Git/ABS/database/backups/pre-reset-20251105/solidity_security_full_backup.sql

# Backup vulnerability patterns (already in codebase)
cp /Users/pwner/Git/ABS/blocksecops-api-service/data/vulnerability_patterns.json \
  /Users/pwner/Git/ABS/database/backups/pre-reset-20251105/

# Export database statistics
curl -s -b /tmp/cookies.txt "http://127.0.0.1:8000/api/v1/scans?limit=100" | \
  jq > /Users/pwner/Git/ABS/database/backups/pre-reset-20251105/pre_reset_scans_export.json

curl -s -b /tmp/cookies.txt "http://127.0.0.1:8000/api/v1/contracts?limit=100" | \
  jq > /Users/pwner/Git/ABS/database/backups/pre-reset-20251105/pre_reset_contracts_export.json
```

### 3. Document Current Schema
```bash
# Verify SCHEMA.md is up to date
diff <(kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "\d+ vulnerabilities" | head -50) \
     <(grep -A 50 "## vulnerabilities" /Users/pwner/Git/ABS/database/SCHEMA.md)

# Export current schema DDL
kubectl exec -n postgresql-local postgresql-0 -- \
  pg_dump -U blocksecops -d solidity_security --schema-only --no-owner --no-privileges \
  > /Users/pwner/Git/ABS/database/backups/pre-reset-20251105/schema_only.sql
```

### 4. Verify Pattern Database
```bash
# Confirm vulnerability patterns are in codebase (not database-only)
ls -lh /Users/pwner/Git/ABS/blocksecops-api-service/data/vulnerability_patterns.json

# Count patterns
jq '.patterns | length' /Users/pwner/Git/ABS/blocksecops-api-service/data/vulnerability_patterns.json

# Verify BVD compliance
jq '.patterns[] | select(.id | startswith("BVD-") | not) | .id' \
  /Users/pwner/Git/ABS/blocksecops-api-service/data/vulnerability_patterns.json
# Expected: empty (all patterns are BVD-compliant)
```

## Reset Procedure

### Phase 1: Stop Services
```bash
# Stop API service (scale down to 0)
kubectl scale deployment/api-service -n api-service-local --replicas=0

# Verify no pods are running
kubectl get pods -n api-service-local -l app=api-service

# Stop any port forwards
pkill -f "kubectl port-forward.*api-service"
```

### Phase 2: Backup and Delete Database
```bash
# Final backup verification
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -c "SELECT COUNT(*) FROM scans;"

# Delete the PVC (this deletes all data)
kubectl delete pvc postgresql-data-postgresql-0 -n postgresql-local

# Wait for PVC to be fully deleted
kubectl get pvc -n postgresql-local --watch
# Press Ctrl+C when postgresql-data-postgresql-0 is gone
```

### Phase 3: Recreate Database
```bash
# Restart PostgreSQL StatefulSet (will create new PVC)
kubectl rollout restart statefulset/postgresql -n postgresql-local

# Wait for PostgreSQL to be ready
kubectl wait --for=condition=ready pod/postgresql-0 -n postgresql-local --timeout=300s

# Verify new empty database exists
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -c "\dt"
# Expected: No relations found (empty database)
```

### Phase 4: Run Migrations
```bash
# Start API service (will auto-run migrations via SQLAlchemy)
kubectl scale deployment/api-service -n api-service-local --replicas=1

# Watch API service logs for migration completion
kubectl logs -n api-service-local -l app=api-service -f --tail=50
# Look for: "Database tables created successfully" or similar

# Verify migrations completed
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -c "\dt"
# Expected: List of all tables (users, contracts, scans, vulnerabilities, etc.)
```

### Phase 5: Seed Essential Data
```bash
# Seed vulnerability patterns (if not auto-seeded by API service)
cd /Users/pwner/Git/ABS/blocksecops-api-service
python3 scripts/seed_vulnerability_patterns.py

# Create test user via API
curl -X POST http://127.0.0.1:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "test@blocksecops.dev", "password": "TestPass123!", "full_name": "Test User"}'

# Login and save cookies
curl -X POST http://127.0.0.1:8000/api/v1/auth/login \
  -c /tmp/cookies.txt \
  -H "Content-Type: application/json" \
  -d '{"email": "test@blocksecops.dev", "password": "TestPass123!"}'
```

## Verification Procedures

### 1. Schema Verification
```bash
# Count tables (expected: 15+)
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -c "\dt" | wc -l

# Verify key tables exist
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -c \
  "SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name;"
```

### 2. Data Verification
```bash
# Verify no scans exist (clean slate)
curl -s -b /tmp/cookies.txt "http://127.0.0.1:8000/api/v1/scans?limit=10" | jq '.scans | length'
# Expected: 0

# Verify vulnerability patterns loaded
curl -s -b /tmp/cookies.txt "http://127.0.0.1:8000/api/v1/intelligence/patterns?limit=10" | jq '.total'
# Expected: 393

# Verify user created
curl -s -b /tmp/cookies.txt "http://127.0.0.1:8000/api/v1/users/me" | jq '.email'
# Expected: test@blocksecops.dev
```

### 3. Strict Scanner Selection Test
```bash
# Upload Reentrancy.sol test contract
curl -X POST http://127.0.0.1:8000/api/v1/contracts \
  -b /tmp/cookies.txt \
  -F "file=@/Users/pwner/Git/vulnerable-smart-contract-examples/solidity/Reentrancy.sol" \
  -F "name=Reentrancy Test" \
  -F "language=solidity" \
  -F "version=0.8.0"

# Trigger scan with ONLY Wake scanner (explicit selection)
# Via Dashboard: http://127.0.0.1:3000/contracts/<contract-id>
# Select ONLY "Wake" checkbox and click "Start Scan"

# Verify scan has proper scanner_ids
SCAN_ID="<scan-id-from-dashboard>"
curl -s -b /tmp/cookies.txt "http://127.0.0.1:8000/api/v1/scans/$SCAN_ID" | \
  jq '{scanner_ids, status, scanner_count: (.scanners_used | length)}'
# Expected: scanner_ids should NOT be null, should contain ["wake"]
```

## Rollback Procedures

### If Issues Occur During Reset

#### Scenario 1: PostgreSQL Won't Start
```bash
# Check pod status
kubectl describe pod postgresql-0 -n postgresql-local

# Check logs
kubectl logs postgresql-0 -n postgresql-local --tail=100

# Delete pod to force recreation
kubectl delete pod postgresql-0 -n postgresql-local

# If PVC is corrupted, delete and recreate
kubectl delete pvc postgresql-data-postgresql-0 -n postgresql-local
kubectl rollout restart statefulset/postgresql -n postgresql-local
```

#### Scenario 2: Migrations Fail
```bash
# Check API service logs
kubectl logs -n api-service-local -l app=api-service --tail=200

# Manual migration (if SQLAlchemy auto-migration fails)
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security \
  < /Users/pwner/Git/ABS/database/backups/pre-reset-20251105/schema_only.sql
```

#### Scenario 3: Need to Restore Old Data
```bash
# Scale down API service
kubectl scale deployment/api-service -n api-service-local --replicas=0

# Restore from backup
kubectl exec -i -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security \
  < /Users/pwner/Git/ABS/database/backups/pre-reset-20251105/solidity_security_full_backup.sql

# Restart API service
kubectl scale deployment/api-service -n api-service-local --replicas=1
```

## Post-Reset Tasks

### 1. Update Documentation
- [ ] Update /Users/pwner/Git/ABS/database/BACKUPS.md with new backup entry
- [ ] Add reset procedure to /Users/pwner/Git/ABS/database/MANUAL-FIXES.md
- [ ] Document any schema changes in /Users/pwner/Git/ABS/database/SCHEMA.md

### 2. Test Critical Paths
- [ ] User registration/login
- [ ] Contract upload (Solidity)
- [ ] Scan execution with Wake only
- [ ] Scan execution with Slither only
- [ ] Scan execution with multiple scanners
- [ ] Vulnerability viewing
- [ ] Scanner selection UI (no localStorage auto-loading)

### 3. Commit Changes
- [ ] Commit updated documentation to Git
- [ ] Commit scanner selection fixes (API + Dashboard)
- [ ] Create Git tag: `database-reset-2025-11-05`

## Success Criteria

✅ **Database reset is successful if:**
1. PostgreSQL is running and accepting connections
2. All migrations completed successfully
3. Schema matches SCHEMA.md (migration 013)
4. Vulnerability patterns loaded (393 patterns)
5. Test scan with Wake has proper `scanner_ids: ["wake"]` (not null)
6. Dashboard scanner selection works (no auto-loading from localStorage)
7. No vulnerabilities appear with `scanner_id: null`

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Data loss | N/A | None | Development environment, stale test data only |
| Migration failure | Low | Medium | Full backup + schema DDL available for restore |
| PostgreSQL corruption | Very Low | Medium | PVC recreation + pod restart resolves |
| Extended downtime | Low | Low | Reset takes ~5-10 minutes, development only |

## Timeline

**Estimated Duration:** 20-30 minutes

| Phase | Duration | Description |
|-------|----------|-------------|
| Pre-Reset Backup | 5 min | Backup data + schema |
| Service Stop | 1 min | Scale down API |
| Database Reset | 3 min | Delete PVC + recreate |
| Migration | 2 min | Auto-run via SQLAlchemy |
| Seed Data | 2 min | Patterns + test user |
| Verification | 5 min | Schema + data checks |
| Test Scan | 3 min | Verify strict scanner selection |
| Documentation | 10 min | Update BACKUPS.md + commit |

## References

- Current Schema: `/Users/pwner/Git/ABS/database/SCHEMA.md`
- Backup History: `/Users/pwner/Git/ABS/database/BACKUPS.md`
- PVC Name: `postgresql-data-postgresql-0`
- Namespace: `postgresql-local`
- Database Name: `solidity_security`
- Pattern File: `/Users/pwner/Git/ABS/blocksecops-api-service/data/vulnerability_patterns.json`

## Sign-Off

**Prepared By:** Claude (AI Assistant)
**Date:** November 5, 2025
**Approved By:** _[User to confirm before execution]_
**Execution Date:** _[To be filled during execution]_

---

**IMPORTANT:** This is a development environment reset. Do NOT execute this procedure in production.
