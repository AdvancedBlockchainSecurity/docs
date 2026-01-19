# Database Backup Log

**Purpose:** Track all database backups created for the solidity_security database.

**Location:** All backups are stored in `/Users/pwner/Git/ABS/backups/`

**IMPORTANT:** Backups are created before any manual database modifications or major changes.

---

## Backup Policy

### When to Create Backups
1. Before any manual database fixes (UPDATE, DELETE, ALTER statements)
2. Before running new Alembic migrations
3. Before major version upgrades
4. Weekly scheduled backups (automated)
5. Before database schema changes
6. Before bulk data imports/exports

### Backup Retention
- **Development/Local:** Keep last 10 backups
- **Staging:** Keep last 30 backups
- **Production:** Keep daily backups for 30 days, weekly for 90 days

### Backup Verification
Each backup should be verified by:
1. Checking file size (should be > 0 bytes)
2. Verifying first 20 lines contain PostgreSQL dump headers
3. Testing restore to a temporary database (weekly)

---

## October 18, 2025 - Pre Scanner Comparison Fix

### Backup Details
**Filename:** `solidity_security_backup_20251018_114701.sql`
**Location:** `/Users/pwner/Git/ABS/backups/solidity_security_backup_20251018_114701.sql`
**Created:** October 18, 2025 11:47:01 MDT
**Size:** 135KB
**Database Version:** PostgreSQL 15.4

### Database State
**Tables:**
- `contracts`: 12 records
- `scans`: 31 records
- `vulnerabilities`: 43 records
- `users`: 5 records

**Schema Version:** Migration 004 (scanner tracking)

### Reason for Backup
Created before applying manual fix to populate `scanner_id` field for scanner comparison feature.

### Changes Applied After This Backup
```sql
UPDATE vulnerabilities SET scanner_id = 'slither' WHERE scanner_id IS NULL;
-- Updated 43 rows
```

### Restore Command
```bash
# Stop API service to prevent concurrent access
kubectl scale deployment/api-service -n api-service-local --replicas=0

# Restore database
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security \
  < /Users/pwner/Git/ABS/backups/solidity_security_backup_20251018_114701.sql

# Restart API service
kubectl scale deployment/api-service -n api-service-local --replicas=1

# Verify data
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security \
  -c "SELECT 'contracts' as table, COUNT(*) FROM contracts
      UNION ALL SELECT 'scans', COUNT(*) FROM scans
      UNION ALL SELECT 'vulnerabilities', COUNT(*) FROM vulnerabilities
      UNION ALL SELECT 'users', COUNT(*) FROM users;"
```

### Related Documentation
- [MANUAL-FIXES.md](/Users/pwner/Git/ABS/docs/database/MANUAL-FIXES.md) - October 18, 2025 entry
- [SCANNER-COMPARISON-FIX-2025-10-18.md](/Users/pwner/Git/ABS/docs/SCANNER-COMPARISON-FIX-2025-10-18.md)

---

## Backup Commands Reference

### Create Full Backup
```bash
# Basic backup
BACKUP_FILE="solidity_security_backup_$(date +%Y%m%d_%H%M%S).sql"
kubectl exec -n postgresql-local postgresql-0 -- \
  pg_dump -U postgres -d solidity_security --clean --if-exists \
  > "/Users/pwner/Git/ABS/backups/${BACKUP_FILE}"

# Verify backup
ls -lh "/Users/pwner/Git/ABS/backups/${BACKUP_FILE}"
head -20 "/Users/pwner/Git/ABS/backups/${BACKUP_FILE}"
```

### Create Compressed Backup
```bash
BACKUP_FILE="solidity_security_backup_$(date +%Y%m%d_%H%M%S).sql.gz"
kubectl exec -n postgresql-local postgresql-0 -- \
  pg_dump -U postgres -d solidity_security --clean --if-exists \
  | gzip > "/Users/pwner/Git/ABS/backups/${BACKUP_FILE}"
```

### Create Schema-Only Backup
```bash
BACKUP_FILE="solidity_security_schema_$(date +%Y%m%d_%H%M%S).sql"
kubectl exec -n postgresql-local postgresql-0 -- \
  pg_dump -U postgres -d solidity_security --schema-only \
  > "/Users/pwner/Git/ABS/backups/${BACKUP_FILE}"
```

### Create Data-Only Backup
```bash
BACKUP_FILE="solidity_security_data_$(date +%Y%m%d_%H%M%S).sql"
kubectl exec -n postgresql-local postgresql-0 -- \
  pg_dump -U postgres -d solidity_security --data-only \
  > "/Users/pwner/Git/ABS/backups/${BACKUP_FILE}"
```

### Create Table-Specific Backup
```bash
# Backup single table
kubectl exec -n postgresql-local postgresql-0 -- \
  pg_dump -U postgres -d solidity_security -t vulnerabilities \
  > "/Users/pwner/Git/ABS/backups/vulnerabilities_backup_$(date +%Y%m%d_%H%M%S).sql"
```

### Restore Database
```bash
# Full restore (WARNING: Drops existing data)
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security \
  < /Users/pwner/Git/ABS/backups/solidity_security_backup_YYYYMMDD_HHMMSS.sql

# Restore compressed backup
gunzip -c /Users/pwner/Git/ABS/backups/solidity_security_backup_YYYYMMDD_HHMMSS.sql.gz | \
  kubectl exec -i -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security
```

### List Backups
```bash
ls -lh /Users/pwner/Git/ABS/backups/ | grep solidity_security
```

### Verify Backup Integrity
```bash
# Check if backup is valid SQL
head -50 /Users/pwner/Git/ABS/backups/solidity_security_backup_YYYYMMDD_HHMMSS.sql

# Test restore to temporary database
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -c "CREATE DATABASE solidity_security_test;"

kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security_test \
  < /Users/pwner/Git/ABS/backups/solidity_security_backup_YYYYMMDD_HHMMSS.sql

kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -c "DROP DATABASE solidity_security_test;"
```

---

## November 2, 2025 - Phase 6.6 Hotfix Schema Fix

### Backup Details
**Filename:** `solidity_security_20251102_backup.sql`
**Location:** `/Users/pwner/Git/ABS/database/backups/solidity_security_20251102_backup.sql`
**Created:** November 2, 2025 12:49:00 PST
**Size:** 673KB
**Database Version:** PostgreSQL 15

### Database State
**Tables:**
- `contracts`: 16 records
- `scans`: 69 records (combined)
- `vulnerabilities`: 69 records
- `vulnerability_patterns`: 383 records ✅
- `pattern_tool_mappings`: 397 records ✅
- `deduplication_groups`: 0 records (empty)
- `users`: Multiple test users

**Schema Version:** Migration 011 (Aderyn 100% integration)
**Intelligence Layer:** Phase 1-4 Complete

### Reason for Backup
Created before applying schema fixes for Phase 6.6 hotfix to resolve column name mismatch in `deduplication_groups` table and patterns API implementation.

### Issues Identified
1. **Deduplication Schema Mismatch:**
   - Database has: `primary_vulnerability_id`, `pattern_id`
   - Model expects: `canonical_finding_id`, `pattern_code`
   - **Action:** Create migration 012 to rename columns

2. **Patterns API Missing:**
   - Patterns endpoints were never implemented despite being in phase plan
   - **Action:** Implemented patterns.py endpoints and schemas

3. **Pattern Code Duplication Bug:**
   - Pattern codes showing as "BVD-EVM-BVD-EVM-..." instead of "BVD-EVM-..."
   - **Action:** Fix build_pattern_code() function

### Changes Applied After This Backup
```sql
-- Migration 012 will apply:
ALTER TABLE deduplication_groups
  RENAME COLUMN primary_vulnerability_id TO canonical_finding_id;

ALTER TABLE deduplication_groups
  RENAME COLUMN pattern_id TO pattern_code;

-- Additional schema corrections as needed
```

### Restore Command
```bash
# Stop API service to prevent concurrent access
kubectl scale deployment/api-service -n api-service-local --replicas=0

# Restore database
kubectl exec -i -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security \
  < /Users/pwner/Git/ABS/database/backups/solidity_security_20251102_backup.sql

# Restart API service
kubectl scale deployment/api-service -n api-service-local --replicas=1

# Verify data
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security \
  -c "SELECT 'vulnerability_patterns' as table, COUNT(*) FROM vulnerability_patterns
      UNION ALL SELECT 'pattern_tool_mappings', COUNT(*) FROM pattern_tool_mappings
      UNION ALL SELECT 'vulnerabilities', COUNT(*) FROM vulnerabilities
      UNION ALL SELECT 'contracts', COUNT(*) FROM contracts
      UNION ALL SELECT 'deduplication_groups', COUNT(*) FROM deduplication_groups;"
```

### Related Documentation
- [PHASE-6.6-HOTFIX-MISSING-API-ENDPOINTS.md](/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/blocksecops/03-phase-4-intelligence/PHASE-6.6-HOTFIX-MISSING-API-ENDPOINTS.md)
- [SCHEMA.md](/Users/pwner/Git/ABS/database/SCHEMA.md) - Deduplication groups table documentation

---

## Backup History Template

### [Date] - [Backup Name]

#### Backup Details
**Filename:** `filename.sql`
**Location:** `/Users/pwner/Git/ABS/backups/filename.sql`
**Created:** [Date and time]
**Size:** [File size]
**Database Version:** PostgreSQL X.Y

#### Database State
**Tables:**
- `table1`: X records
- `table2`: Y records

**Schema Version:** Migration XXX

#### Reason for Backup
[Why this backup was created]

#### Changes Applied After This Backup
```sql
-- SQL changes made after this backup
```

#### Restore Command
```bash
# Commands to restore this backup
```

#### Related Documentation
- [Link to related docs]

---

## November 28, 2025 - Phase 3.4 Contract Structure Analysis Migration

### Backup Details
**Filename:** `solidity_security_backup_20251128_231123.sql`
**Location:** `/Users/pwner/Git/ABS/docs/database/backups/solidity_security_backup_20251128_231123.sql`
**Created:** November 28, 2025 23:11:23 PST
**Size:** 1.1MB (1,110,981 bytes)
**Database Version:** PostgreSQL 15
**Backup Method:** kubectl exec pg_dump from within cluster

### Database State Before Migration
**Tables:**
- `contracts`: Existing contracts with framework support columns
- `scans`: Existing scan records
- `vulnerabilities`: Existing vulnerability records
- `vulnerability_patterns`: 352 patterns (BVD compliant)
- `pattern_tool_mappings`: 398 mappings

**Schema Version:** Migration `add_framework_support` (Phase 3.2)

### Reason for Backup
Created before running Phase 3.4 Contract Structure Analysis database migration which adds:
- `contract_functions` table - Extracted function definitions from Solidity AST
- `contract_events` table - Extracted event definitions
- `contract_state_variables` table - Extracted state variable definitions
- New columns on `contracts` table: `structure_analyzed`, `structure_analyzed_at`, `structure_parse_errors`

### Changes Applied After This Backup
```sql
-- Migration 20251128_1600 applied:
-- Created contract_functions table with indexes
-- Created contract_events table with indexes
-- Created contract_state_variables table with indexes
-- Added structure analysis columns to contracts table
```

### Database State After Migration
**New Tables Created:**
- `contract_functions`: Function definitions (name, selector, visibility, mutability, parameters, etc.)
- `contract_events`: Event definitions (name, signature, topic0, parameters, anonymous flag)
- `contract_state_variables`: State variable definitions (name, type, visibility, mutability, storage slot)

**New Indexes:**
- `idx_functions_contract`, `idx_functions_name`, `idx_functions_selector`, `idx_functions_visibility`
- `idx_events_contract`, `idx_events_name`, `idx_events_topic0`
- `idx_variables_contract`, `idx_variables_name`, `idx_variables_type`, `idx_variables_visibility`

**Schema Version:** Migration `20251128_1600` (Phase 3.4)

### Restore Command
```bash
# Stop API service to prevent concurrent access
kubectl scale deployment/api-service -n api-service-local --replicas=0

# Restore database
kubectl cp /Users/pwner/Git/ABS/docs/database/backups/solidity_security_backup_20251128_231123.sql \
  postgresql-local/postgresql-0:/tmp/restore.sql
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security -f /tmp/restore.sql

# Restart API service
kubectl scale deployment/api-service -n api-service-local --replicas=1

# Verify restoration
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security \
  -c "SELECT 'contracts' as table, COUNT(*) FROM contracts
      UNION ALL SELECT 'contract_functions', COUNT(*) FROM contract_functions
      UNION ALL SELECT 'contract_events', COUNT(*) FROM contract_events
      UNION ALL SELECT 'contract_state_variables', COUNT(*) FROM contract_state_variables;"
```

### Related Documentation
- [SCHEMA.md](/Users/pwner/Git/ABS/docs/database/SCHEMA.md) - Updated with Phase 3.4 tables
- [Phase 3.4 Documentation](/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/phases/PHASE-3.4-CONTRACT-STRUCTURE-ANALYSIS-COMPLETE.md)
- [Migration File](/Users/pwner/Git/ABS/blocksecops-api-service/alembic/versions/20251128_1600-add_contract_structure_tables.py)

---

## Notes

- All backups include `--clean --if-exists` flags to drop existing objects before restore
- Backups are NOT automatically backed up to remote storage in local development
- Production backups should be stored in S3/GCS with encryption
- Test restore procedures monthly to ensure backup validity
- Document all manual database changes in MANUAL-FIXES.md
- Consider automating backups with a cron job or Kubernetes CronJob

## Pattern Taxonomy Migration Backup

**Date**: 2025-11-03
**Type**: Pre-Migration Backup
**File**: `backups/vulnerability_patterns_pre_taxonomy_migration_20251103_175226.json`
**Size**: 599KB
**Purpose**: Backup before BVD-EVM → BVD-SOLIDITY taxonomy migration

### Migration Details
- **Version Change**: v3.8 → v3.9
- **Patterns Migrated**: 202 (BVD-EVM-* → BVD-SOLIDITY-*)
- **Mappings Updated**: 397 pattern_tool_mappings
- **Total Patterns**: 347 (unchanged)
- **Migration Type**: Automated (jq-based transformation)
- **Status**: ✅ Complete and verified

### Restore Instructions
```bash
# If rollback needed
cp backups/vulnerability_patterns_pre_taxonomy_migration_20251103_175226.json \
   ../blocksecops-api-service/seeds/vulnerability_patterns.json
```

### Migration Documentation
- Task Doc: `TaskDocs-BlockSecOps/blocksecops/03-phase-4-intelligence/PATTERN-TAXONOMY-MIGRATION-EVM-TO-SOLIDITY.md`
- Integration Summary: `/tmp/wake-soliditydefend-integration-summary.md`

---

## November 3, 2025 - Wake Scanner Intelligence Integration

### Backup Details
**Filename:** `vulnerability_patterns_pre_wake_integration_20251103_200037.json`
**Location:** `/Users/pwner/Git/ABS/database/backups/vulnerability_patterns_pre_wake_integration_20251103_200037.json`
**Created:** November 3, 2025 20:00:37 PST
**Size:** 603KB
**Database Version:** v3.9
**Purpose**: Backup before Wake scanner intelligence integration

### Database State Before Integration
**Pattern Statistics:**
- Version: v3.9 (post-taxonomy migration)
- Total patterns: 347 (202 BVD-SOLIDITY, 145 other ecosystems)
- Total mappings: 397
- Scanners with mappings: 8 (slither, aderyn, semgrep, solhint, halmos, echidna, medusa, mythril)

### Reason for Backup
Created before integrating Wake scanner (26 detectors) into the intelligence layer with pattern mappings and new BVD-SOLIDITY patterns.

### Changes Applied After This Backup
```json
// Added 8 new BVD-SOLIDITY patterns:
- BVD-SOLIDITY-DAT-004: Array Delete Nullification
- BVD-SOLIDITY-ORA-003: Axelar Proxy Contract ID Mismatch
- BVD-SOLIDITY-EXT-007: Call Options Not Called
- BVD-SOLIDITY-ORA-004: Chainlink Deprecated Function
- BVD-SOLIDITY-DAT-005: Empty Byte Array Copy Bug
- BVD-SOLIDITY-STV-004: Struct Mapping Deletion
- BVD-SOLIDITY-COD-034: Missing Function Return Statement
- BVD-SOLIDITY-COD-035: msg.value in Non-Payable Function

// Added 26 Wake detector mappings
// Version incremented: v3.9 → v3.10
// New totals: 355 patterns, 423 mappings
```

### Database State After Integration
**Pattern Statistics:**
- Version: v3.10
- Total patterns: 355 (+8)
- Total mappings: 423 (+26)
- Scanners with mappings: 9 (added wake)

### Restore Command
```bash
# Stop API service
kubectl scale deployment/api-service -n api-service-local --replicas=0

# Restore patterns file
cp /Users/pwner/Git/ABS/database/backups/vulnerability_patterns_pre_wake_integration_20251103_200037.json \
   /Users/pwner/Git/ABS/blocksecops-api-service/seeds/vulnerability_patterns.json

# Restart API service
kubectl scale deployment/api-service -n api-service-local --replicas=1

# Verify restoration
jq -r '.version, (.patterns | length), (.pattern_tool_mappings | length)' \
  /Users/pwner/Git/ABS/blocksecops-api-service/seeds/vulnerability_patterns.json
```

### Related Documentation
- Wake Integration Summary: `/tmp/wake-integration-summary.md`
- Wake Detector Mapping: `/tmp/wake-detector-mapping.md`
- Integration Tracking: `/tmp/wake-soliditydefend-integration-summary.md`

---

## January 18, 2026 - SolidityDefend Pattern Seeding

### Backup Details
**Filename:** `solidity_security_pre_soliditydefend_seeding_20260118_115725.sql`
**Location:** `/home/pwner/Git/docs/database/backups/solidity_security_pre_soliditydefend_seeding_20260118_115725.sql`
**Created:** January 18, 2026 11:57:25 MST
**Size:** 5.6MB
**Database Version:** PostgreSQL 15.4
**Backup Method:** kubectl exec pg_dump from within cluster

### Database State Before Seeding
**Tables:**
- `vulnerability_patterns`: 402 patterns
- `pattern_tool_mappings`: 219 mappings for soliditydefend (total across all scanners higher)
- All existing data preserved

**Schema Version:** Current (all migrations applied)

### Reason for Backup
Created before running SolidityDefend v1.10.3 pattern seeding script to add pattern_tool_mappings for unmapped detectors discovered in vulnerability findings.

### Changes Applied After This Backup
```sql
-- Created 11 new vulnerability patterns:
-- BVD-SOL-MISC-SOL-JIT_LIQUIDITY_E (jit-liquidity-extraction)
-- BVD-SOL-MISC-SOL-INITCODE_INJECT (initcode-injection)
-- BVD-SOL-MISC-SOL-SANDWICH_CONDIT (sandwich-conditional-swap)
-- BVD-SOL-MISC-SOL-REENTRANCY_DETE (reentrancy-detected)
-- BVD-SOL-MISC-SOL-TRANSACTION_ORD (transaction-ordering-dependence)
-- BVD-SOL-MISC-SOL-INVALID_STATE_T (invalid-state-transition)
-- BVD-SOL-MISC-SOL-DOS_UNBOUNDED_S (dos-unbounded-storage)
-- BVD-SOL-MISC-SOL-FLASH_CALLBACK (flash-callback-manipulation)
-- BVD-SOL-MISC-SOL-BACKRUNNING_OPP (backrunning-opportunity)
-- BVD-SOL-MISC-SOL-UNPROTECTED_INI (unprotected-initializer)
-- BVD-SOL-MISC-SOL-TOKEN_LAUNCH_ME (token-launch-mev)

-- Created 11 new pattern_tool_mappings for soliditydefend
-- Total soliditydefend mappings after: 230
-- Total vulnerability_patterns after: 413
```

### Database State After Seeding
**Pattern Statistics:**
- Total vulnerability_patterns: 413 (+11)
- Total soliditydefend mappings: 230 (+11)
- New patterns focus on MEV, reentrancy, DoS, and upgrade safety

### Restore Command
```bash
# Stop API service to prevent concurrent access
kubectl scale deployment/api-service -n api-service-local --replicas=0

# Restore database
kubectl cp /home/pwner/Git/docs/database/backups/solidity_security_pre_soliditydefend_seeding_20260118_115725.sql \
  postgresql-local/postgresql-0:/tmp/restore.sql
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -f /tmp/restore.sql

# Restart API service
kubectl scale deployment/api-service -n api-service-local --replicas=1

# Verify restoration
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security \
  -c "SELECT 'vulnerability_patterns' as table, COUNT(*) FROM vulnerability_patterns
      UNION ALL SELECT 'pattern_tool_mappings (soliditydefend)', COUNT(*) FROM pattern_tool_mappings WHERE scanner_id = 'soliditydefend';"
```

### Related Documentation
- Task Documentation: `TaskDocs-BlockSecOps/phases/03-phase-4-intelligence/SOLIDITYDEFEND-PATTERN-SEEDING-20260118.md`
- Seed Script: `blocksecops-api-service/scripts/seed_scanner_patterns.py`
- Implementation Plan: Original plan in Claude session transcript

---

