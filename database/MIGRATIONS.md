# Database Migrations

## Overview

This document tracks all database schema migrations for the BlockSecOps platform. Migrations are managed using Alembic and follow a strict versioning system.

## Migration History

### Migration 001-004: Core Platform Tables
- **Status**: ✅ Completed
- **Created**: 2025-10-XX
- **Description**: Core tables for users, contracts, scans, and vulnerabilities
- **Tables Created**:
  - `users` - User accounts and authentication
  - `contracts` - Smart contract storage and metadata
  - `scans` - Security scan records
  - `vulnerabilities` - Detected security issues
  - `findings_metadata` - Additional vulnerability metadata
  - `scanner_runs` - Individual scanner execution records
  - Supporting tables for user sessions, API keys, etc.

### Migration 005: Vulnerability Intelligence Platform (Phase 4D)
- **Status**: ✅ Completed (Manual SQL execution required)
- **Created**: 2025-10-21 18:00
- **Revision ID**: `005`
- **Description**: Foundation tables for vulnerability pattern intelligence and scanner mapping
- **Tables Created**:
  - `vulnerability_patterns` - Knowledge base with 84+ vulnerability patterns
  - `pattern_tool_mappings` - Maps scanner detector IDs to patterns
- **Critical Note**: ⚠️ This migration could not be applied via standard `alembic upgrade head` due to database state inconsistencies. Tables were created manually via SQL script.
- **SQL Script**: `/tmp/create_intelligence_tables.sql`
- **Resolution Date**: 2025-11-06
- **Related Issues**:
  - Missing tables caused ALL scans to fail with transaction errors
  - PostgreSQL error: `relation "pattern_tool_mappings" does not exist`
  - Root cause documented in `/Users/pwner/Git/ABS/database/DATABASE-RESET-COMPLETED-20251105.md`

### Migration 006: Enhanced Vulnerabilities with Intelligence
- **Status**: ⚠️ Partial (Column already exists)
- **Created**: 2025-10-XX
- **Description**: Adds `pattern_id` column to vulnerabilities table
- **Issue**: Migration failed because `pattern_id` column already existed in database
- **Resolution**: Marked as completed in alembic_version table (version 006)

### Migration 004 (Manual): Scanner Result Tables
- **Status**: ✅ Completed (Manual SQL execution required)
- **Created**: 2025-11-07
- **Description**: Scanner-specific result type tables for gas analysis, code quality, formal verification, and fuzzing
- **Tables Created**:
  - `code_quality_findings` - Code quality issues from linters and static analysis tools
  - `gas_analysis_findings` - Gas optimization findings with cost analysis
  - `formal_verification_results` - Formal verification proof results
  - `fuzzing_results` - Fuzzing test execution results
- **Critical Note**: ⚠️ These tables were created manually during the 2025-11-07 fix session
- **SQL Script**: `/tmp/create_scanner_result_tables.sql`
- **Resolution Date**: 2025-11-07
- **Model Reference**: `/Users/pwner/Git/ABS/blocksecops-api-service/src/infrastructure/database/specialized_models/scan_results.py`
- **Additional Columns Added to gas_analysis_findings**:
  - `contract_id` UUID - Foreign key to contracts table
  - `detector_id` VARCHAR(200) - Scanner detector identifier
  - `file_path` VARCHAR(500) - Source file path
  - `contract_name` VARCHAR(200) - Contract name

### Migrations 007-013: Additional Intelligence Features
- **Status**: ⏳ Pending
- **Description**: Additional intelligence layer features
- **Tables**:
  - `deduplication_groups` - Duplicate vulnerability tracking
  - `vulnerability_classifications` - User feedback and ML training data
  - `vulnerability_trends` - Time-series analytics
- **Note**: Not yet applied due to dependency on migration 005 completion

## Manual Migration Process (2025-11-06)

Due to database state inconsistencies after the 2025-11-05 database reset, the standard Alembic migration process failed. The following manual process was required:

### Problem
1. Database reset on 2025-11-05 did NOT run Alembic migrations
2. Missing intelligence tables caused ALL scans to fail
3. `pattern_tool_mappings` table query → PostgreSQL transaction abort → vulnerability INSERT failures
4. Alembic reported migration 005 success but rolled back due to migration 006 errors

### Resolution Steps

1. **Created Manual SQL Script**
   ```bash
   # File: /tmp/create_intelligence_tables.sql
   # Contains CREATE TABLE statements for:
   # - vulnerability_patterns
   # - pattern_tool_mappings
   # - All associated indexes and constraints
   ```

2. **Executed SQL Directly**
   ```bash
   kubectl cp /tmp/create_intelligence_tables.sql postgresql-local/postgresql-0:/tmp/
   kubectl exec -n postgresql-local postgresql-0 -- psql -U postgres -d solidity_security -f /tmp/create_intelligence_tables.sql
   ```

3. **Updated Alembic Version**
   ```bash
   kubectl exec -n postgresql-local postgresql-0 -- psql -U postgres -d solidity_security -c "UPDATE alembic_version SET version_num = '005';"
   ```

4. **Verified Table Creation**
   ```bash
   kubectl exec -n postgresql-local postgresql-0 -- psql -U postgres -d solidity_security -c "\dt pattern_tool_mappings"
   kubectl exec -n postgresql-local postgresql-0 -- psql -U postgres -d solidity_security -c "\dt vulnerability_patterns"
   ```

### Lessons Learned

1. **Always Run Migrations After Database Reset**
   - After restoring a database or creating a fresh database cluster, ALWAYS run `alembic upgrade head`
   - Verify with: `SELECT * FROM alembic_version;`

2. **Database Reset Checklist**
   ```bash
   # 1. Backup existing database
   kubectl exec -n postgresql-local postgresql-0 -- pg_dump -U postgres -d solidity_security > backup.sql

   # 2. Perform reset/restoration
   # ... (reset steps)

   # 3. Run migrations
   kubectl exec -n api-service-local <pod-name> -- alembic upgrade head

   # 4. Verify migration version
   kubectl exec -n postgresql-local postgresql-0 -- psql -U postgres -d solidity_security -c "SELECT * FROM alembic_version;"

   # 5. Verify critical tables exist
   kubectl exec -n postgresql-local postgresql-0 -- psql -U postgres -d solidity_security -c "\dt pattern_tool_mappings"
   ```

3. **Transaction Rollback Prevention**
   - Alembic migrations are transactional - if ANY statement fails, ALL changes roll back
   - Version number may increment even if migration rolled back
   - Always verify table creation, not just alembic version number

### Migration 20251129_1000: SBOM Tables (REVERTED)
- **Status**: ⚠️ REVERTED (November 30, 2025)
- **Revision ID**: `20251129_1000`
- **Previous Revision**: `20251128_1600`
- **Description**: Added SBOM (Software Bill of Materials) tables for supply chain security
- **Tables Created (then removed)**:
  - `sboms` - SBOM records with CycloneDX/SPDX format support
  - `sbom_components` - Individual SBOM component details
- **Reason for Revert**: SBOM implementation caused authentication conflicts (phantom accounts in dashboard)
- **Rollback Process**:
  1. API code reverted via `git revert efd2b6f` (reverts commit 47a54aa)
  2. Migration file restored from git history
  3. `alembic upgrade 20251129_1000` to recreate tables
  4. `alembic downgrade 20251128_1600` to properly remove tables
  5. Migration file removed
  6. Historical data cleaned: 7 SBOM scans, 3 vulnerabilities deleted
- **Lesson Learned**: Always run `alembic downgrade` BEFORE `git revert` when rolling back features with migrations

---

## Current Database State (2025-11-30)

### Alembic Version
```
version_num: 20251128_1600
```

### Existing Tables
- ✅ `users`
- ✅ `contracts`
- ✅ `scans`
- ✅ `vulnerabilities` (with `pattern_id` column)
- ✅ `vulnerability_patterns` (manually created)
- ✅ `pattern_tool_mappings` (manually created)
- ❌ `deduplication_groups` (pending)
- ❌ `vulnerability_classifications` (pending)
- ❌ `vulnerability_trends` (pending)

## Running Migrations

### Standard Process (When Database State is Clean)
```bash
# Inside API service pod
cd /Users/pwner/Git/ABS/blocksecops-api-service
kubectl exec -n api-service-local <pod-name> -- alembic upgrade head
```

### Verify Migration Status
```bash
# Check current version
kubectl exec -n postgresql-local postgresql-0 -- psql -U postgres -d solidity_security -c "SELECT * FROM alembic_version;"

# List all tables
kubectl exec -n postgresql-local postgresql-0 -- psql -U postgres -d solidity_security -c "\dt"

# Check specific table structure
kubectl exec -n postgresql-local postgresql-0 -- psql -U postgres -d solidity_security -c "\d pattern_tool_mappings"
```

### Rollback Migrations (If Needed)
```bash
# Downgrade to specific version
kubectl exec -n api-service-local <pod-name> -- alembic downgrade <revision>

# Example: Rollback to migration 004
kubectl exec -n api-service-local <pod-name> -- alembic downgrade 004
```

## Migration Development

### Creating New Migrations
```bash
# Auto-generate migration from model changes
alembic revision --autogenerate -m "description of changes"

# Create empty migration (for data migrations)
alembic revision -m "description of changes"
```

### Migration File Naming Convention
```
YYYYMMDD_HHMM-NNN_description.py

Example: 20251021_1800-005_add_vulnerability_intelligence_tables.py
```

### Migration Best Practices
1. Always include both `upgrade()` and `downgrade()` functions
2. Use `op.create_table()` instead of raw SQL when possible
3. Include indexes and constraints in the same migration as table creation
4. Test migrations on development database before applying to production
5. Document any data transformations or manual steps required

## Related Documentation

- **Schema Reference**: `/Users/pwner/Git/ABS/database/SCHEMA.md`
- **Database Reset Report**: `/Users/pwner/Git/ABS/database/DATABASE-RESET-COMPLETED-20251105.md`
- **Database Standards**: `/Users/pwner/Git/ABS/docs/standards/database-management.md`
- **Migration Files**: `/Users/pwner/Git/ABS/blocksecops-api-service/alembic/versions/`

## Troubleshooting

### Migration Fails with "relation already exists"
1. Check if table actually exists: `\dt table_name`
2. If yes, manually update alembic_version to skip that migration
3. If no, check for transaction rollback - table creation may have failed silently

### Migration Succeeds but Tables Don't Exist
1. Check for transaction rollback in PostgreSQL logs
2. Verify alembic version matches expected migration
3. Manually create tables using SQL if needed
4. Update alembic_version to reflect actual state

### Cannot Run Migrations - Module Not Found
1. Ensure you're running migrations inside the API service pod, not locally
2. Use: `kubectl exec -n api-service-local <pod-name> -- alembic upgrade head`
3. Do NOT run migrations from local machine unless development environment is fully configured

## Pending Migrations: Phase 4.5 Enterprise Features

### Migration 013: Wallet Authentication (Phase 3.3)
- **Status**: ⏳ Pending
- **Description**: Add wallet authentication fields to users table
- **Changes**:
  - Add `wallet_address` VARCHAR(42) column to users table
  - Add `wallet_nonce` VARCHAR(255) column
  - Add `wallet_linked_at` TIMESTAMP column
  - Add `ens_name` VARCHAR(255) column
  - Add unique constraint on wallet_address
  - Add index on wallet_address

### Migration 014: Enterprise Features (Phase 4.5)
- **Status**: ⏳ Pending
- **Description**: Enterprise webhook, RBAC, SSO, API key, and audit log tables
- **Tables to Create**:
  - `webhooks` - Webhook configuration with HMAC signing
  - `webhook_deliveries` - Webhook delivery history and retry tracking
  - `organizations` - Multi-tenant organization support
  - `roles` - RBAC role definitions with permissions
  - `organization_members` - Organization membership and role assignments
  - `api_keys` - Scoped API key management with rate limits
  - `audit_logs` - Comprehensive audit trail for compliance
- **Model Reference**: `/Users/pwner/Git/ABS/blocksecops-api-service/src/infrastructure/database/models.py`
- **Feature Documentation**: `/Users/pwner/Git/ABS/docs/features/PHASE-4.5-ENTERPRISE-FEATURES.md`

### Creating Phase 4.5 Migration
```bash
# Generate migration from models
cd /Users/pwner/Git/ABS/blocksecops-api-service
alembic revision --autogenerate -m "add_enterprise_features_tables"

# Or create manually
alembic revision -m "add_enterprise_features_tables"
```

---

## Next Steps

1. ✅ Migration 005 completed (manual SQL execution)
2. ⏳ Test scans to verify fix (in progress)
3. ⏳ Apply migrations 006-013 to complete intelligence layer
4. ⏳ Load vulnerability pattern data into `vulnerability_patterns` table
5. ⏳ Populate `pattern_tool_mappings` with scanner detector mappings
6. ⏳ Create and apply Migration 013 for wallet authentication (Phase 3.3)
7. ⏳ Create and apply Migration 014 for enterprise features (Phase 4.5)
