# Database Reset Task Checklist
**Date:** November 5, 2025
**Related Plan:** DATABASE-RESET-PLAN.md

## Pre-Execution Tasks

### Documentation Preparation
- [ ] **TASK-001:** Review current DATABASE-RESET-PLAN.md
  - Location: `/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/DATABASE-RESET-PLAN.md`
  - Verify all steps are clear and actionable
  - Estimated time: 5 minutes

- [ ] **TASK-002:** Verify SCHEMA.md is current
  - Location: `/Users/pwner/Git/ABS/database/SCHEMA.md`
  - Current version: 3.0.2, Migration 013
  - Compare against actual database schema
  - Command: `kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "\d+ vulnerabilities"`
  - Estimated time: 3 minutes

- [ ] **TASK-003:** Check existing backups
  - Location: `/Users/pwner/Git/ABS/database/backups/`
  - Note latest backup: `solidity_security_20251102_backup.sql`
  - Verify backup directory has space
  - Command: `df -h /Users/pwner/Git/ABS/database/backups/`
  - Estimated time: 2 minutes

### Current State Verification
- [ ] **TASK-004:** Count scans with null scanner_ids
  - Expected: 57 (all scans)
  - Command: `curl -s -b /tmp/cookies.txt "http://127.0.0.1:8000/api/v1/scans?limit=100" | jq '[.scans[] | select(.scanner_ids == null)] | length'`
  - Estimated time: 1 minute

- [ ] **TASK-005:** Count total contracts
  - Expected: 12
  - Command: `curl -s -b /tmp/cookies.txt "http://127.0.0.1:8000/api/v1/contracts?limit=100" | jq '.contracts | length'`
  - Estimated time: 1 minute

- [ ] **TASK-006:** Export current scan statistics
  - Save to: `/Users/pwner/Git/ABS/database/backups/pre-reset-20251105/current_state.json`
  - Include: scan count, contract count, vulnerability count
  - Estimated time: 3 minutes

## Backup Tasks

### Create Backup Directory
- [ ] **TASK-007:** Create timestamped backup directory
  - Path: `/Users/pwner/Git/ABS/database/backups/pre-reset-20251105`
  - Command: `mkdir -p /Users/pwner/Git/ABS/database/backups/pre-reset-20251105`
  - Estimated time: 1 minute

### Database Backups
- [ ] **TASK-008:** Full database dump (data + schema)
  - Output: `solidity_security_full_backup.sql`
  - Command:
    ```bash
    kubectl exec -n postgresql-local postgresql-0 -- \
      pg_dump -U blocksecops -d solidity_security --no-owner --no-privileges \
      > /Users/pwner/Git/ABS/database/backups/pre-reset-20251105/solidity_security_full_backup.sql
    ```
  - Verify: `ls -lh /Users/pwner/Git/ABS/database/backups/pre-reset-20251105/solidity_security_full_backup.sql`
  - Expected size: ~600KB (based on previous backup)
  - Estimated time: 2 minutes

- [ ] **TASK-009:** Schema-only dump
  - Output: `schema_only.sql`
  - Command:
    ```bash
    kubectl exec -n postgresql-local postgresql-0 -- \
      pg_dump -U blocksecops -d solidity_security --schema-only --no-owner --no-privileges \
      > /Users/pwner/Git/ABS/database/backups/pre-reset-20251105/schema_only.sql
    ```
  - Verify: `grep "CREATE TABLE" /Users/pwner/Git/ABS/database/backups/pre-reset-20251105/schema_only.sql | wc -l`
  - Expected: 15+ tables
  - Estimated time: 1 minute

### API Data Export
- [ ] **TASK-010:** Export all scans via API
  - Output: `pre_reset_scans_export.json`
  - Command:
    ```bash
    curl -s -b /tmp/cookies.txt "http://127.0.0.1:8000/api/v1/scans?limit=100" | \
      jq > /Users/pwner/Git/ABS/database/backups/pre-reset-20251105/pre_reset_scans_export.json
    ```
  - Verify: `jq '.scans | length' /Users/pwner/Git/ABS/database/backups/pre-reset-20251105/pre_reset_scans_export.json`
  - Expected: 57
  - Estimated time: 2 minutes

- [ ] **TASK-011:** Export all contracts via API
  - Output: `pre_reset_contracts_export.json`
  - Command:
    ```bash
    curl -s -b /tmp/cookies.txt "http://127.0.0.1:8000/api/v1/contracts?limit=100" | \
      jq > /Users/pwner/Git/ABS/database/backups/pre-reset-20251105/pre_reset_contracts_export.json
    ```
  - Verify: `jq '.contracts | length' /Users/pwner/Git/ABS/database/backups/pre-reset-20251105/pre_reset_contracts_export.json`
  - Expected: 12
  - Estimated time: 2 minutes

### Pattern Database Backup
- [ ] **TASK-012:** Copy vulnerability patterns JSON
  - Source: `/Users/pwner/Git/ABS/blocksecops-api-service/data/vulnerability_patterns.json`
  - Destination: `/Users/pwner/Git/ABS/database/backups/pre-reset-20251105/vulnerability_patterns.json`
  - Command: `cp /Users/pwner/Git/ABS/blocksecops-api-service/data/vulnerability_patterns.json /Users/pwner/Git/ABS/database/backups/pre-reset-20251105/`
  - Verify: `jq '.patterns | length' /Users/pwner/Git/ABS/database/backups/pre-reset-20251105/vulnerability_patterns.json`
  - Expected: 393 patterns
  - Estimated time: 1 minute

- [ ] **TASK-013:** Verify BVD compliance
  - Check all patterns start with "BVD-"
  - Command:
    ```bash
    jq '.patterns[] | select(.id | startswith("BVD-") | not) | .id' \
      /Users/pwner/Git/ABS/database/backups/pre-reset-20251105/vulnerability_patterns.json
    ```
  - Expected: empty output (all compliant)
  - Estimated time: 1 minute

### Backup Verification
- [ ] **TASK-014:** Create backup manifest
  - Output: `BACKUP_MANIFEST.md`
  - List all backup files with sizes and checksums
  - Command:
    ```bash
    cd /Users/pwner/Git/ABS/database/backups/pre-reset-20251105
    ls -lh > BACKUP_MANIFEST.txt
    shasum -a 256 *.sql *.json >> BACKUP_MANIFEST.txt
    ```
  - Estimated time: 2 minutes

- [ ] **TASK-015:** Compress backups
  - Create: `pre-reset-20251105.tar.gz`
  - Command:
    ```bash
    cd /Users/pwner/Git/ABS/database/backups
    tar -czf pre-reset-20251105.tar.gz pre-reset-20251105/
    ```
  - Verify: `ls -lh /Users/pwner/Git/ABS/database/backups/pre-reset-20251105.tar.gz`
  - Estimated time: 2 minutes

## Database Reset Tasks

### Stop Services
- [ ] **TASK-016:** Stop API service
  - Command: `kubectl scale deployment/api-service -n api-service-local --replicas=0`
  - Verify: `kubectl get pods -n api-service-local -l app=api-service`
  - Expected: No pods running
  - Estimated time: 1 minute

- [ ] **TASK-017:** Stop port forwards
  - Command: `pkill -f "kubectl port-forward.*api-service"`
  - Verify: `ps aux | grep "port-forward.*api-service"`
  - Expected: No processes found
  - Estimated time: 1 minute

- [ ] **TASK-018:** Stop local uvicorn processes (if running)
  - Check: `ps aux | grep uvicorn`
  - Kill if needed: `pkill -f uvicorn`
  - Estimated time: 1 minute

### Delete Database
- [ ] **TASK-019:** Final database state verification
  - Command: `kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "SELECT COUNT(*) FROM scans;"`
  - Record count: ____ scans
  - Estimated time: 1 minute

- [ ] **TASK-020:** Delete PostgreSQL PVC
  - **CRITICAL:** This deletes ALL database data
  - Command: `kubectl delete pvc postgresql-data-postgresql-0 -n postgresql-local`
  - Confirm deletion when prompted
  - Estimated time: 1 minute

- [ ] **TASK-021:** Wait for PVC deletion to complete
  - Command: `kubectl get pvc -n postgresql-local --watch`
  - Wait until postgresql-data-postgresql-0 is gone
  - Press Ctrl+C when complete
  - Estimated time: 1-2 minutes

### Recreate Database
- [ ] **TASK-022:** Restart PostgreSQL StatefulSet
  - Command: `kubectl rollout restart statefulset/postgresql -n postgresql-local`
  - This will create a new PVC automatically
  - Estimated time: 1 minute

- [ ] **TASK-023:** Wait for PostgreSQL to be ready
  - Command: `kubectl wait --for=condition=ready pod/postgresql-0 -n postgresql-local --timeout=300s`
  - Monitor: `kubectl get pods -n postgresql-local --watch`
  - Expected: pod/postgresql-0 status Running (1/1)
  - Estimated time: 2-3 minutes

- [ ] **TASK-024:** Verify new PVC created
  - Command: `kubectl get pvc -n postgresql-local`
  - Expected: postgresql-data-postgresql-0 status Bound, AGE < 5m
  - Estimated time: 1 minute

- [ ] **TASK-025:** Verify empty database exists
  - Command: `kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "\dt"`
  - Expected: "Did not find any relations" (empty database)
  - Estimated time: 1 minute

### Run Migrations
- [ ] **TASK-026:** Start API service (triggers auto-migration)
  - Command: `kubectl scale deployment/api-service -n api-service-local --replicas=1`
  - SQLAlchemy will auto-create tables via models
  - Estimated time: 1 minute

- [ ] **TASK-027:** Monitor migration logs
  - Command: `kubectl logs -n api-service-local -l app=api-service -f --tail=50`
  - Look for: "Database tables created successfully" or table creation logs
  - Press Ctrl+C when migrations complete
  - Estimated time: 2-3 minutes

- [ ] **TASK-028:** Verify tables created
  - Command: `kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "\dt"`
  - Expected: List of 15+ tables
  - Verify key tables: users, contracts, scans, vulnerabilities, vulnerability_patterns
  - Estimated time: 1 minute

- [ ] **TASK-029:** Check table schemas
  - Command:
    ```bash
    kubectl exec -n postgresql-local postgresql-0 -- \
      psql -U blocksecops -d solidity_security -c "\d vulnerabilities" | head -50
    ```
  - Verify key columns: scanner_id, pattern_id, fingerprint_*, classification_confidence
  - Estimated time: 2 minutes

### Seed Essential Data
- [ ] **TASK-030:** Verify vulnerability patterns auto-seeded
  - Check if API service auto-loads patterns on startup
  - Query: `curl -s http://127.0.0.1:8000/api/v1/intelligence/patterns?limit=1 | jq '.total'`
  - If 0, run manual seed: `cd /Users/pwner/Git/ABS/blocksecops-api-service && python3 scripts/seed_vulnerability_patterns.py`
  - Expected: 393 patterns
  - Estimated time: 2 minutes

- [ ] **TASK-031:** Create test user
  - Command:
    ```bash
    curl -X POST http://127.0.0.1:8000/api/v1/auth/register \
      -H "Content-Type: application/json" \
      -d '{"email": "test@blocksecops.dev", "password": "TestPass123!", "full_name": "Test User"}'
    ```
  - Record response: ____
  - Estimated time: 1 minute

- [ ] **TASK-032:** Login and save cookies
  - Command:
    ```bash
    curl -X POST http://127.0.0.1:8000/api/v1/auth/login \
      -c /tmp/cookies.txt \
      -H "Content-Type: application/json" \
      -d '{"email": "test@blocksecops.dev", "password": "TestPass123!"}'
    ```
  - Verify: `cat /tmp/cookies.txt | grep access_token`
  - Estimated time: 1 minute

## Verification Tasks

### Schema Verification
- [ ] **TASK-033:** Count created tables
  - Command: `kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "\dt" | wc -l`
  - Expected: 15+ lines (tables)
  - Estimated time: 1 minute

- [ ] **TASK-034:** Verify key tables exist
  - Command:
    ```bash
    kubectl exec -n postgresql-local postgresql-0 -- \
      psql -U blocksecops -d solidity_security -c \
      "SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name;"
    ```
  - Must include: users, sessions, contracts, scans, vulnerabilities, vulnerability_patterns, pattern_tool_mappings, deduplication_groups
  - Estimated time: 1 minute

- [ ] **TASK-035:** Verify indexes created
  - Command:
    ```bash
    kubectl exec -n postgresql-local postgresql-0 -- \
      psql -U blocksecops -d solidity_security -c \
      "SELECT indexname FROM pg_indexes WHERE schemaname='public' ORDER BY indexname;"
    ```
  - Expected: 13+ indexes
  - Estimated time: 1 minute

### Data Verification
- [ ] **TASK-036:** Verify clean slate (0 scans)
  - Command: `curl -s -b /tmp/cookies.txt "http://127.0.0.1:8000/api/v1/scans?limit=10" | jq '.scans | length'`
  - Expected: 0
  - Estimated time: 1 minute

- [ ] **TASK-037:** Verify clean slate (0 contracts)
  - Command: `curl -s -b /tmp/cookies.txt "http://127.0.0.1:8000/api/v1/contracts?limit=10" | jq '.contracts | length'`
  - Expected: 0
  - Estimated time: 1 minute

- [ ] **TASK-038:** Verify vulnerability patterns loaded
  - Command: `curl -s -b /tmp/cookies.txt "http://127.0.0.1:8000/api/v1/intelligence/patterns?limit=1" | jq '.total'`
  - Expected: 393
  - Estimated time: 1 minute

- [ ] **TASK-039:** Verify pattern-tool mappings loaded
  - Command: `curl -s -b /tmp/cookies.txt "http://127.0.0.1:8000/api/v1/intelligence/patterns/mappings?limit=1" | jq '.total'`
  - Expected: 398+ mappings
  - Estimated time: 1 minute

- [ ] **TASK-040:** Verify user created
  - Command: `curl -s -b /tmp/cookies.txt "http://127.0.0.1:8000/api/v1/users/me" | jq '{email, full_name}'`
  - Expected: test@blocksecops.dev
  - Estimated time: 1 minute

## Functional Testing Tasks

### Scanner Selection Test
- [ ] **TASK-041:** Upload test contract
  - File: `/Users/pwner/Git/vulnerable-smart-contract-examples/solidity/Reentrancy.sol`
  - Command:
    ```bash
    curl -X POST http://127.0.0.1:8000/api/v1/contracts \
      -b /tmp/cookies.txt \
      -F "file=@/Users/pwner/Git/vulnerable-smart-contract-examples/solidity/Reentrancy.sol" \
      -F "name=Reentrancy Test Post-Reset" \
      -F "language=solidity" \
      -F "version=0.8.0" | jq '.id'
    ```
  - Record contract_id: ____
  - Estimated time: 2 minutes

- [ ] **TASK-042:** Test Dashboard scanner selection (no auto-load)
  - Open: http://127.0.0.1:3000/contracts/<contract-id>
  - **VERIFY:** No scanners are pre-selected
  - **VERIFY:** "Start Scan" button is disabled
  - **VERIFY:** No localStorage auto-loading occurred
  - Estimated time: 2 minutes

- [ ] **TASK-043:** Trigger Wake-only scan via Dashboard
  - Select ONLY "Wake" checkbox
  - Click "Start Scan"
  - Record scan_id from URL: ____
  - Estimated time: 2 minutes

- [ ] **TASK-044:** Verify scan has proper scanner_ids
  - Wait for scan to complete (check Dashboard or logs)
  - Command:
    ```bash
    curl -s -b /tmp/cookies.txt "http://127.0.0.1:8000/api/v1/scans/<scan-id>" | \
      jq '{scanner_ids, status, scanners_used}'
    ```
  - **CRITICAL:** scanner_ids must NOT be null
  - **EXPECTED:** scanner_ids: null (may still be null in schema - check if migration needed)
  - **EXPECTED:** scanners_used: ["wake"]
  - Estimated time: 3 minutes (wait for scan)

- [ ] **TASK-045:** Verify Wake job executed
  - Command: `kubectl get jobs -n tool-integration-local | grep wake`
  - Expected: 1 job for the scan
  - Estimated time: 1 minute

- [ ] **TASK-046:** Check Wake pod logs
  - Command: `kubectl logs -n tool-integration-local -l job-name=scan-wake-<scan-id> --tail=50`
  - Verify: "Wake static analysis..." and results JSON
  - Estimated time: 2 minutes

- [ ] **TASK-047:** Verify vulnerabilities (if any)
  - Command: `curl -s -b /tmp/cookies.txt "http://127.0.0.1:8000/api/v1/scans/<scan-id>/vulnerabilities" | jq '.vulnerabilities[] | {title, scanner_id, pattern_id}'`
  - **CRITICAL:** NO vulnerability should have scanner_id: null
  - If Wake found 0: verify count is 0
  - If Wake found N: verify all have scanner_id: "wake"
  - Estimated time: 2 minutes

### Multi-Scanner Test
- [ ] **TASK-048:** Trigger Slither + Wake scan via Dashboard
  - Select BOTH "Slither" and "Wake" checkboxes
  - Click "Start Scan"
  - Record scan_id: ____
  - Estimated time: 2 minutes

- [ ] **TASK-049:** Verify both scanner jobs created
  - Command: `kubectl get jobs -n tool-integration-local | grep <scan-id>`
  - Expected: 2 jobs (scan-slither-<id> and scan-wake-<id>)
  - Estimated time: 1 minute

- [ ] **TASK-050:** Verify scan has both scanners
  - Wait for completion
  - Command:
    ```bash
    curl -s -b /tmp/cookies.txt "http://127.0.0.1:8000/api/v1/scans/<scan-id>" | \
      jq '{scanners_used, status}'
    ```
  - Expected: scanners_used contains both "slither" and "wake"
  - Estimated time: 5 minutes (wait for scan)

## Documentation Update Tasks

### Update BACKUPS.md
- [ ] **TASK-051:** Add backup entry to BACKUPS.md
  - Location: `/Users/pwner/Git/ABS/database/BACKUPS.md`
  - Add new section for pre-reset-20251105 backup
  - Include: backup size, file list, purpose, restore procedure
  - Estimated time: 5 minutes

- [ ] **TASK-052:** Document backup location
  - Full path: `/Users/pwner/Git/ABS/database/backups/pre-reset-20251105.tar.gz`
  - Compressed size: ____
  - Uncompressed size: ____
  - Estimated time: 2 minutes

### Update SCHEMA.md
- [ ] **TASK-053:** Verify SCHEMA.md still matches
  - Compare documented schema with actual database
  - Update version number if schema changed
  - Current version: 3.0.2, Migration 013
  - Estimated time: 5 minutes

- [ ] **TASK-054:** Add reset note to SCHEMA.md
  - Add entry to Migration History section
  - Note: "Database reset 2025-11-05 (development environment)"
  - Estimated time: 2 minutes

### Create Reset Documentation
- [ ] **TASK-055:** Add reset procedure to MANUAL-FIXES.md
  - Location: `/Users/pwner/Git/ABS/database/MANUAL-FIXES.md`
  - Add section: "Database Reset Procedure (Development)"
  - Reference: DATABASE-RESET-PLAN.md
  - Estimated time: 5 minutes

- [ ] **TASK-056:** Create reset summary report
  - File: `/Users/pwner/Git/ABS/database/backups/pre-reset-20251105/RESET_SUMMARY.md`
  - Include: date, reason, before/after stats, verification results
  - Estimated time: 10 minutes

## Git Commit Tasks

### Stage Documentation Changes
- [ ] **TASK-057:** Stage database documentation updates
  - Files:
    - `/Users/pwner/Git/ABS/database/BACKUPS.md`
    - `/Users/pwner/Git/ABS/database/SCHEMA.md`
    - `/Users/pwner/Git/ABS/database/MANUAL-FIXES.md`
  - Command: `git add database/BACKUPS.md database/SCHEMA.md database/MANUAL-FIXES.md`
  - Estimated time: 1 minute

- [ ] **TASK-058:** Stage TaskDocs
  - Files:
    - `/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/DATABASE-RESET-PLAN.md`
    - `/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/DATABASE-RESET-TASKS.md`
  - Command: `git add TaskDocs-BlockSecOps/DATABASE-RESET-*.md`
  - Estimated time: 1 minute

### Stage Code Changes
- [ ] **TASK-059:** Stage API service scanner selection fix
  - File: `/Users/pwner/Git/ABS/blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py`
  - Lines: 195-205 (strict scanner validation)
  - Command: `cd /Users/pwner/Git/ABS/blocksecops-api-service && git add src/presentation/api/v1/endpoints/scans.py`
  - Estimated time: 1 minute

- [ ] **TASK-060:** Stage Dashboard scanner selection fix
  - File: `/Users/pwner/Git/ABS/blocksecops-dashboard/src/pages/ContractDetail.tsx`
  - Lines: 102-113, 128-132 (disabled localStorage)
  - Command: `cd /Users/pwner/Git/ABS/blocksecops-dashboard && git add src/pages/ContractDetail.tsx`
  - Estimated time: 1 minute

### Create Commits
- [ ] **TASK-061:** Commit database reset documentation
  - Command:
    ```bash
    cd /Users/pwner/Git/ABS
    git commit -m "docs(database): Add database reset plan and task list for development environment

    - Created DATABASE-RESET-PLAN.md with comprehensive reset procedure
    - Created DATABASE-RESET-TASKS.md with 63 detailed tasks
    - Updated BACKUPS.md with pre-reset-20251105 backup entry
    - Updated SCHEMA.md with reset note
    - Updated MANUAL-FIXES.md with reset procedure reference

    Database reset performed to eliminate stale test data with null scanner_ids
    All 57 scans pre-reset had scanner_ids=null from before strict scanner selection

    Refs: DATABASE-RESET-PLAN.md, DATABASE-RESET-TASKS.md"
    ```
  - Estimated time: 2 minutes

- [ ] **TASK-062:** Commit scanner selection fixes
  - Command:
    ```bash
    cd /Users/pwner/Git/ABS
    git commit -m "fix(scanner-selection): Enforce strict scanner selection with no defaults

    API Service (blocksecops-api-service):
    - src/presentation/api/v1/endpoints/scans.py:195-205
    - Removed fallback to ['slither'] when scanner_ids is empty
    - Added explicit validation requiring scanner_ids to be provided
    - Returns 400 error if no scanners selected

    Dashboard (blocksecops-dashboard):
    - src/pages/ContractDetail.tsx:102-113, 128-132
    - Disabled localStorage auto-loading of scanner preferences
    - Disabled auto-saving of scanner preferences
    - Users must explicitly select scanners for each scan

    BREAKING CHANGE: Scanner selection is now mandatory and explicit.
    No scanners will run by default. This prevents unexpected scanner
    execution and ensures user transparency.

    Closes: #wake-scanner-integration
    Refs: DATABASE-RESET-PLAN.md"
    ```
  - Estimated time: 2 minutes

### Create Git Tag
- [ ] **TASK-063:** Create database reset tag
  - Command:
    ```bash
    cd /Users/pwner/Git/ABS
    git tag -a database-reset-2025-11-05 -m "Database reset - Development environment cleanup

    Reset performed to eliminate stale test data with null scanner_ids.
    All 57 scans pre-reset had scanner_ids=null from before strict scanner selection implementation.

    Changes:
    - Complete PostgreSQL PVC deletion and recreation
    - Migrations re-run via SQLAlchemy auto-migration
    - Vulnerability patterns re-seeded (393 patterns, 637 mappings)
    - Clean slate for testing strict scanner selection

    Backup: /Users/pwner/Git/ABS/database/backups/pre-reset-20251105.tar.gz
    Schema: v3.0.2, Migration 013
    Pattern DB: v3.9, 100% BVD-compliant"
    ```
  - Estimated time: 2 minutes

## Final Verification Tasks

### Post-Reset Checks
- [ ] **TASK-064:** Verify no null scanner_ids in new scans
  - Query: `curl -s -b /tmp/cookies.txt "http://127.0.0.1:8000/api/v1/scans?limit=10" | jq '[.scans[] | select(.scanner_ids == null)] | length'`
  - Expected: 0 (no scans with null scanner_ids)
  - Estimated time: 1 minute

- [ ] **TASK-065:** Verify no null scanner_id in vulnerabilities
  - Query:
    ```bash
    kubectl exec -n postgresql-local postgresql-0 -- \
      psql -U blocksecops -d solidity_security -c \
      "SELECT COUNT(*) FROM vulnerabilities WHERE scanner_id IS NULL;"
    ```
  - Expected: 0
  - Estimated time: 1 minute

- [ ] **TASK-066:** Run comprehensive API health check
  - Endpoints to test:
    - GET /api/v1/health
    - GET /api/v1/contracts
    - GET /api/v1/scans
    - GET /api/v1/intelligence/patterns
  - All should return 200 OK
  - Estimated time: 3 minutes

### Dashboard UI Verification
- [ ] **TASK-067:** Test dashboard loads correctly
  - URL: http://127.0.0.1:3000
  - Verify: No console errors
  - Verify: User can login
  - Estimated time: 2 minutes

- [ ] **TASK-068:** Test contract upload UI
  - Upload a new test contract
  - Verify: Upload succeeds
  - Verify: Contract appears in list
  - Estimated time: 3 minutes

- [ ] **TASK-069:** Test scanner selection UI
  - Open contract detail page
  - **VERIFY:** No scanners pre-selected (clean localStorage)
  - **VERIFY:** "Start Scan" button disabled until scanner selected
  - **VERIFY:** After selecting scanner, button enabled
  - Estimated time: 3 minutes

## Completion Summary

### Task Statistics
- Total tasks: 69
- Completed: ____ / 69
- Failed: ____
- Skipped: ____

### Timing
- Start time: ____
- End time: ____
- Total duration: ____
- Estimated: 20-30 minutes
- Actual: ____

### Outcomes
- [ ] Database successfully reset
- [ ] All migrations completed
- [ ] Vulnerability patterns loaded
- [ ] Strict scanner selection verified
- [ ] No null scanner_ids in new data
- [ ] Documentation updated
- [ ] Changes committed to Git
- [ ] Backups created and verified

### Issues Encountered
_List any issues encountered during execution:_

1.
2.
3.

### Next Steps
_List any follow-up tasks:_

1. Monitor new scans for any scanner_id issues
2. Test SolidityDefend scanner integration
3. Continue with BVD pattern mapping tasks

---

**Task List Prepared By:** Claude (AI Assistant)
**Date:** November 5, 2025
**Execution Status:** PENDING
**Executed By:** _[To be filled during execution]_
**Sign-Off:** _[User signature/confirmation]_
