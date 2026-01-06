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

### Migration 014_x402_payments: x402 Pay-Per-Scan Tables (Phase 3.4)
- **Status**: ✅ Completed (December 1, 2025)
- **Revision ID**: `014_x402_payments`
- **Previous Revision**: `20251128_1600`
- **Description**: x402 payment integration for pay-per-scan with USDC on Base blockchain
- **Tables Created**:
  - `credit_packages` - Pre-defined credit bundles with pricing and discounts
  - `scan_credits` - Per-user credit balance tracking (1:1 with users)
  - `payment_transactions` - USDC payment records with blockchain verification
  - `credit_transactions` - Credit purchase/usage audit trail
- **Default Data Seeded**:
  - Starter package: 5 credits @ $4.50 (10% discount)
  - Standard package: 10 credits @ $8.00 (20% discount)
  - Professional package: 25 credits @ $17.50 (30% discount)
  - Enterprise package: 50 credits @ $30.00 (40% discount)
- **API Endpoints Added**:
  - `GET /api/v1/payments/packages` - List credit packages
  - `GET /api/v1/payments/prices` - Get current pricing
  - `GET /api/v1/payments/credits` - Get user credit balance
  - `POST /api/v1/payments/credits/use` - Consume credits for scan
  - `GET /api/v1/payments/credits/history` - Credit transaction history
  - `POST /api/v1/payments/initiate` - Initiate x402 payment
- **Related Files**:
  - Models: `src/infrastructure/database/models.py` (CreditPackageModel, ScanCreditModel, PaymentTransactionModel, CreditTransactionModel)
  - Schemas: `src/presentation/schemas/payments.py`
  - Services: `src/application/services/payment_service.py`, `credit_service.py`, `pricing_service.py`
  - Endpoints: `src/presentation/api/v1/endpoints/payments.py`

### Migration 015_user_activity_logs: User Activity Logging (Phase 3.1b - Task 21)
- **Status**: ✅ Completed (December 10, 2025)
- **Revision ID**: `015_user_activity_logs`
- **Previous Revision**: `014_x402_payments`
- **Description**: User activity logging for uploads, scans, payments, and credit usage
- **Tables Created**:
  - `user_activity_logs` - User activity entries with timestamps and metadata
- **Table Schema**:
  - `id` (UUID) - Primary key
  - `user_id` (UUID) - FK to users, CASCADE DELETE
  - `activity_type` (VARCHAR(50)) - Activity type enum (file_upload, contract_created, scan_started, etc.)
  - `description` (VARCHAR(500)) - Human-readable description
  - `contract_id` (UUID) - Optional FK to contracts, SET NULL on delete
  - `scan_id` (UUID) - Optional FK to scans, SET NULL on delete
  - `scanner_type` (VARCHAR(50)) - Scanner tool name
  - `scan_status` (VARCHAR(20)) - Scan completion status
  - `credits_used` (INTEGER) - Credits consumed (default 0)
  - `payment_amount` (NUMERIC(10,2)) - Payment amount
  - `payment_currency` (VARCHAR(10)) - Payment currency
  - `activity_metadata` (JSONB) - Additional context data
  - `created_at` (TIMESTAMPTZ) - Activity timestamp
- **Indexes Created**:
  - `ix_user_activity_logs_user_id` on `user_id`
  - `ix_user_activity_logs_activity_type` on `activity_type`
  - `ix_user_activity_logs_created_at` on `created_at`
  - `ix_user_activity_logs_user_id_created_at` composite for efficient user queries
- **API Endpoints Added**:
  - `GET /api/v1/users/me/activity` - Get user activity log with pagination and filtering
- **Related Files**:
  - Migration: `alembic/versions/20251210_0100-015_add_user_activity_logs.py`
  - Models: `src/infrastructure/database/models.py` (UserActivityLogModel)
  - Schemas: `src/presentation/schemas/users.py` (ActivityType, ActivityLogEntry, UserActivityResponse)
  - Services: `src/application/services/activity_service.py`
  - Endpoints: `src/presentation/api/v1/endpoints/users.py`
- **Dashboard Components**:
  - Activity Log Page: `blocksecops-dashboard/src/pages/ActivityLog.tsx`
  - API Client: `blocksecops-dashboard/src/lib/api/users.ts`
  - Navigation: Added to Sidebar under OVERVIEW section

### Migration 016_user_favorites: User Favorites (Phase 3.1b - Task 27.1)
- **Status**: ✅ Completed (December 11, 2025)
- **Revision ID**: `016_user_favorites`
- **Previous Revision**: `015_user_activity_logs`
- **Description**: Favorites system for contracts, scans, and vulnerabilities
- **Tables Created**:
  - `user_favorites` - User favorite items with polymorphic reference
- **Table Schema**:
  - `id` (UUID) - Primary key
  - `user_id` (UUID) - FK to users, CASCADE DELETE
  - `item_type` (VARCHAR(50)) - Type of favorited item (contract, scan, vulnerability)
  - `item_id` (UUID) - ID of the favorited item
  - `notes` (VARCHAR(500)) - Optional user notes
  - `created_at` (TIMESTAMPTZ) - When favorited
- **Indexes Created**:
  - `ix_user_favorites_user_id` on `user_id`
  - `ix_user_favorites_item_type` on `item_type`
  - Unique constraint on `(user_id, item_type, item_id)`
- **API Endpoints Added**:
  - `GET /api/v1/users/me/favorites` - List user favorites
  - `POST /api/v1/users/me/favorites` - Add a favorite
  - `DELETE /api/v1/users/me/favorites/:id` - Remove a favorite
- **Related Files**:
  - Migration: `alembic/versions/20251211_0100-016_add_user_favorites.py`
  - Models: `src/infrastructure/database/models.py` (UserFavoriteModel)
  - Schemas: `src/presentation/schemas/users.py` (FavoriteType, UserFavorite*)
  - Endpoints: `src/presentation/api/v1/endpoints/users.py`

### Migration 017_vulnerability_annotations: Vulnerability Annotations (Phase 3.1b - Task 27.1)
- **Status**: ✅ Completed (December 11, 2025)
- **Revision ID**: `017_vulnerability_annotations`
- **Previous Revision**: `016_user_favorites`
- **Description**: User annotations on vulnerabilities for tracking and notes
- **Tables Created**:
  - `vulnerability_annotations` - User annotations on vulnerabilities
- **Table Schema**:
  - `id` (UUID) - Primary key
  - `user_id` (UUID) - FK to users, CASCADE DELETE
  - `vulnerability_id` (UUID) - FK to vulnerabilities, CASCADE DELETE
  - `status` (VARCHAR(50)) - Annotation status (confirmed, false_positive, investigating, etc.)
  - `notes` (TEXT) - Detailed user notes
  - `assigned_to` (VARCHAR(200)) - Assignment field
  - `priority` (VARCHAR(20)) - Priority level (low, medium, high, critical)
  - `tags` (ARRAY[VARCHAR(50)]) - User-defined tags
  - `created_at` (TIMESTAMPTZ) - Created timestamp
  - `updated_at` (TIMESTAMPTZ) - Last update timestamp
- **Indexes Created**:
  - `ix_vulnerability_annotations_user_id` on `user_id`
  - `ix_vulnerability_annotations_vulnerability_id` on `vulnerability_id`
  - `ix_vulnerability_annotations_status` on `status`
  - Unique constraint on `(user_id, vulnerability_id)`
- **API Endpoints Added**:
  - `GET /api/v1/vulnerabilities/:id/annotations` - Get annotations for vulnerability
  - `POST /api/v1/vulnerabilities/:id/annotations` - Create/update annotation
  - `DELETE /api/v1/vulnerabilities/:id/annotations` - Delete annotation
- **Related Files**:
  - Migration: `alembic/versions/20251211_0200-017_add_vulnerability_annotations.py`
  - Models: `src/infrastructure/database/models.py` (VulnerabilityAnnotationModel)
  - Schemas: `src/presentation/schemas/vulnerabilities.py` (AnnotationStatus, VulnerabilityAnnotation*)
  - Endpoints: `src/presentation/api/v1/endpoints/vulnerabilities.py`

### Migration 018_scan_batches: Batch Scan Operations (Phase 3.1b - Task 27.2)
- **Status**: ✅ Completed (December 11, 2025)
- **Revision ID**: `018_scan_batches`
- **Previous Revision**: `017_vulnerability_annotations`
- **Description**: Batch scan tracking for multi-contract scan operations
- **Tables Created**:
  - `scan_batches` - Batch scan records for grouping multiple scans
- **Table Schema**:
  - `id` (UUID) - Primary key
  - `user_id` (UUID) - FK to users, CASCADE DELETE
  - `project_id` (UUID) - Optional FK to projects, SET NULL on delete
  - `total_contracts` (INTEGER) - Total contracts in batch
  - `completed_count` (INTEGER) - Completed scans count
  - `failed_count` (INTEGER) - Failed scans count
  - `status` (VARCHAR(50)) - Batch status (pending, running, completed, partially_completed, failed)
  - `priority` (VARCHAR(20)) - Batch priority
  - `scanner_ids` (ARRAY[VARCHAR(50)]) - Scanners to use
  - `created_at` (TIMESTAMPTZ) - Created timestamp
  - `completed_at` (TIMESTAMPTZ) - Completion timestamp
- **Columns Added**:
  - `scans.batch_id` (UUID) - FK to scan_batches, SET NULL on delete
- **Indexes Created**:
  - `ix_scan_batches_user_id` on `user_id`
  - `ix_scan_batches_status` on `status`
  - `ix_scan_batches_created_at` on `created_at`
  - `ix_scans_batch_id` on `scans.batch_id`
- **API Endpoints Added**:
  - `POST /api/v1/scans/batch` - Create batch scan for multiple contracts
  - `GET /api/v1/scans/batch` - List batch scans
  - `GET /api/v1/scans/batch/:batch_id` - Get batch scan status with details
  - `POST /api/v1/scans/batch/:batch_id/update-status` - Internal status update
- **Related Files**:
  - Migration: `alembic/versions/20251211_0300-018_add_scan_batches.py`
  - Models: `src/infrastructure/database/models.py` (ScanBatchModel, ScanModel.batch_id)
  - Schemas: `src/presentation/schemas/scans.py` (BatchScan*, ScanBatchStatus)
  - Endpoints: `src/presentation/api/v1/endpoints/scans.py`
- **Dashboard Components**:
  - Batch Scan Page: `blocksecops-dashboard/src/pages/BatchScan.tsx`
  - API Client: `blocksecops-dashboard/src/lib/api/scans.ts`
  - Route: `/scan` - Batch scan management

### Migration Model Relationship Fix (December 2, 2025)
- **Status**: ✅ Completed
- **Description**: Fixed SQLAlchemy ORM relationship mapping errors for x402 models
- **Issue**: `ScanCreditModel` had invalid `credit_transactions` relationship (no FK existed)
- **Resolution**:
  - Removed invalid relationship from `ScanCreditModel`
  - Added `credit_transactions` relationship to `UserModel`
  - Updated `CreditTransactionModel` to reference user instead of user_credits
- **PR**: blocksecops-api-service#107

---

## Current Database State (2026-01-04)

### Alembic Version
```
version_num: 025_add_notification_channels
```

### Existing Tables
- ✅ `users`
- ✅ `contracts`
- ✅ `scans` (with `batch_id` column)
- ✅ `vulnerabilities` (with `pattern_id` column)
- ✅ `vulnerability_patterns` (manually created)
- ✅ `pattern_tool_mappings` (manually created)
- ✅ `credit_packages` (Phase 3.4 x402)
- ✅ `scan_credits` (Phase 3.4 x402)
- ✅ `payment_transactions` (Phase 3.4 x402)
- ✅ `credit_transactions` (Phase 3.4 x402)
- ✅ `user_activity_logs` (Phase 3.1b Task 21)
- ✅ `user_favorites` (Phase 3.1b Task 27.1)
- ✅ `vulnerability_annotations` (Phase 3.1b Task 27.1)
- ✅ `scan_batches` (Phase 3.1b Task 27.2)
- ✅ `notification_channels` (CI/CD Integrations)
- ✅ `notification_deliveries` (CI/CD Integrations)
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

### Migration 012: Wallet Authentication (Phase 3.3) - MODELS COMPLETE
- **Status**: ✅ Models Complete (December 1, 2025)
- **Description**: Add wallet authentication fields to users table for MetaMask/WalletConnect SIWE
- **Changes**:
  - Add `wallet_address` VARCHAR(42) column to users table
  - Add `wallet_nonce` VARCHAR(64) column for SIWE signature verification
  - Add `wallet_linked_at` TIMESTAMP column
  - Add `ens_name` VARCHAR(255) column for ENS domain resolution
  - Add unique constraint on wallet_address
  - Add indexes on wallet_address and ens_name
- **Model Reference**: `UserModel` in `/Users/pwner/Git/ABS/blocksecops-api-service/src/infrastructure/database/models.py`

### Migration 013: Enterprise Features (Phase 4.5) - MODELS COMPLETE
- **Status**: ✅ Models Complete (December 1, 2025)
- **Description**: Enterprise webhook, RBAC, SSO, API key, and audit log tables
- **Tables Created**:
  - `organizations` - Multi-tenant organization support with SSO
  - `roles` - RBAC role definitions with JSON permissions
  - `organization_members` - Organization membership and role assignments
  - `webhooks` - Webhook configuration with HMAC-SHA256 signing
  - `webhook_deliveries` - Webhook delivery history and retry tracking
  - `api_keys` - Scoped API key management with rate limits
  - `audit_logs` - Comprehensive audit trail for compliance
- **Model Reference**: `/Users/pwner/Git/ABS/blocksecops-api-service/src/infrastructure/database/models.py`
- **Feature Documentation**: `/Users/pwner/Git/ABS/docs/features/PHASE-4.5-ENTERPRISE-FEATURES.md`

### Migration 014: x402 Pay-Per-Scan (Phase 3.4) - MODELS COMPLETE
- **Status**: ✅ Models Complete (December 1, 2025)
- **Description**: x402 payment integration for pay-per-scan with USDC on Base
- **Tables Created**:
  - `credit_packages` - Credit packages available for purchase (Starter/Pro/Enterprise)
  - `scan_credits` - User's scan credit balance tracking
  - `payment_transactions` - x402 payment transactions with blockchain verification
  - `credit_transactions` - Credit usage and purchase history
- **Features**:
  - USDC payments on Base blockchain (chain ID 8453)
  - x402 protocol integration with facilitator verification
  - Credit packages with volume discounts (20-40%)
  - Per-scan pricing tiers ($0.50-$5.00 based on complexity)
  - Credit balance tracking and transaction history
  - Admin credit gifting for promotions/support
- **Model Reference**: `/Users/pwner/Git/ABS/blocksecops-api-service/src/infrastructure/database/models.py`
- **Service Layer**:
  - `PaymentService` - x402 payment processing
  - `CreditService` - Credit balance management
  - `PricingService` - Scan pricing and packages
- **API Endpoints**: `GET/POST /api/v1/payments/*`

### Migration 019: Expand Vulnerability Patterns Columns
- **Status**: ✅ Applied (December 24, 2025)
- **Revision ID**: `019_expand_vuln_patterns`
- **Description**: Expands column sizes in vulnerability_patterns table for multi-ecosystem support
- **Changes**:
  - `id` VARCHAR(20) → VARCHAR(50) - Accommodate longer pattern IDs (e.g., BVD-SOLANA-CPI-001)
  - `name` VARCHAR(200) → VARCHAR(100) - Standardized name length
  - `category` VARCHAR(50) - No change (already adequate)
  - `severity` VARCHAR(20) - No change (already adequate)
  - `swc_id` VARCHAR(20) - No change (already adequate)
  - `cwe_id` VARCHAR(20) - No change (already adequate)
  - `owasp_category` VARCHAR(100) - No change (already adequate)
- **Reason**: Original column sizes were too small for Solana, Cairo, and other ecosystem patterns
- **Manual Fix Applied**: See `/Users/pwner/Git/ABS/docs/database/MANUAL-FIXES.md` - December 24, 2025 entry
- **Migration File**: `/Users/pwner/Git/ABS/blocksecops-api-service/alembic/versions/20251224_0100-019_expand_vulnerability_patterns_columns.py`

### Migration 020: Expand Pattern Tool Mappings FK
- **Status**: ✅ Applied (December 24, 2025)
- **Revision ID**: `020_expand_mappings_fk`
- **Description**: Expands pattern_id FK column to match parent table
- **Changes**:
  - `pattern_tool_mappings.pattern_id` VARCHAR(20) → VARCHAR(50)
- **Reason**: FK column must match parent vulnerability_patterns.id column size
- **Migration File**: `/Users/pwner/Git/ABS/blocksecops-api-service/alembic/versions/20251224_0200-020_expand_pattern_tool_mappings_fk.py`

### Migration 021: Team Collaboration (Phase 4.5 - Task 26)
- **Status**: ✅ Applied (December 27, 2025)
- **Revision ID**: `021_add_team_collaboration`
- **Previous Revision**: `020_expand_mappings_fk`
- **Description**: Core tables for team collaboration feature
- **Tables Created**:
  - `teams` - Team definitions within organizations
  - `team_members` - Team membership with roles (lead/member)
  - `project_team_access` - Team-level project permissions
  - `project_user_access` - Individual user project permissions
  - `vulnerability_assignments` - Vulnerability remediation tracking
  - `comments` - Polymorphic comments on entities (vulnerability, scan, contract, project)
- **Table Schemas**:
  - **teams**: id, organization_id (FK), name, slug, description, color, created_by (FK), timestamps
  - **team_members**: id, team_id (FK), user_id (FK), role, added_by (FK), added_at
  - **project_team_access**: id, project_id (FK), team_id (FK), access_level, granted_by (FK), granted_at
  - **project_user_access**: id, project_id (FK), user_id (FK), access_level, granted_by (FK), granted_at
  - **vulnerability_assignments**: id, vulnerability_id (FK), assignee_id (FK), assigned_by (FK), status, priority, due_date, notes, timestamps
  - **comments**: id, user_id (FK), entity_type, entity_id, content, mentions (JSONB), parent_id (FK), is_edited, timestamps
- **Indexes Created**:
  - Unique constraint on (organization_id, slug) for teams
  - Unique constraint on (team_id, user_id) for team_members
  - Unique constraint on (project_id, team_id) for project_team_access
  - Unique constraint on (project_id, user_id) for project_user_access
  - Unique constraint on (vulnerability_id, assignee_id) for assignments
  - Composite indexes on entity_type/entity_id for comments
- **API Endpoints Added**:
  - Teams: `/api/v1/organizations/{org_id}/teams/*`
  - Project Access: `/api/v1/projects/{project_id}/access/*`
  - Assignments: `/api/v1/assignments/*`
  - Comments: `/api/v1/comments/*`
- **Migration File**: `/Users/pwner/Git/ABS/blocksecops-api-service/alembic/versions/20251226_0100-021_add_team_collaboration.py`
- **Related Files**:
  - Endpoints: `teams.py`, `project_access.py`, `assignments.py`, `comments.py`
  - Models: `TeamModel`, `TeamMemberModel`, `ProjectTeamAccessModel`, `ProjectUserAccessModel`, `VulnerabilityAssignmentModel`, `CommentModel`

### Migration 022: Add Missing Collaboration Columns
- **Status**: ✅ Applied (December 27, 2025)
- **Revision ID**: `022_add_missing_collab_cols`
- **Previous Revision**: `021_add_team_collaboration`
- **Description**: Adds missing columns required for team collaboration endpoints
- **Columns Added**:
  - `users.display_name` (VARCHAR(255)) - User display name for UI
  - `roles.display_name` (VARCHAR(255)) - Role display name for UI
  - `organization_members.invited_at` (TIMESTAMPTZ) - Invitation timestamp
- **Note**: Uses IF NOT EXISTS checks for idempotent upgrades
- **Migration File**: `/Users/pwner/Git/ABS/blocksecops-api-service/alembic/versions/20251226_1900-022_add_missing_collaboration_columns.py`

### Migration 023: Add Max Projects Quota
- **Status**: ✅ Applied (January 3, 2026)
- **Revision ID**: `023_add_max_projects_quota`
- **Previous Revision**: `022_add_missing_collab_cols`
- **Description**: Adds tier-based project limits to user quotas
- **Columns Added**:
  - `user_quotas.max_projects` (INTEGER, NOT NULL, DEFAULT 3) - Maximum projects per tier (-1 = unlimited)
- **Tier Defaults** (old naming):
  - Free: 3 projects
  - Pro: 10 projects
  - Enterprise: -1 (unlimited)
  - Enterprise Broker: -1 (unlimited)
- **Trigger Updated**: `create_user_quota()` function updated to include `max_projects` based on tier
- **Note**: Superseded by Migration 024 which restructures all tier values
- **Migration File**: `/Users/pwner/Git/ABS/blocksecops-api-service/alembic/versions/20260102_0100-023_add_max_projects_quota.py`

### Migration 024: Tier Restructure (5-Tier Pricing)
- **Status**: ✅ Applied (January 3, 2026)
- **Revision ID**: `024_tier_restructure`
- **Previous Revision**: `023_add_max_projects_quota`
- **Description**: Major tier restructure implementing new 5-tier pricing model
- **Breaking Change**: Tier names changed

**Tier Renaming:**
| Old Tier | New Tier |
|----------|----------|
| `free` | `free` (unchanged) |
| `pro` | `developer` |
| `enterprise` | `professional` |
| `enterprise_broker` | `enterprise` |
| (new) | `startup` |

**New Columns Added to `user_quotas`:**
- `monthly_api_calls_limit` (INTEGER, NOT NULL, DEFAULT 0) - Monthly API call limit (0=no access, -1=unlimited)
- `monthly_api_calls_used` (INTEGER, NOT NULL, DEFAULT 0) - API calls used this month
- `max_team_members` (INTEGER, NOT NULL, DEFAULT 1) - Maximum team members (-1 = unlimited)

**New Table Created:**
- `team_invites` - Team/organization invite tracking for onboarding and lead generation

**Tier Limits (New Values):**

| Tier | Scans/Mo | Files/Scan | Projects | API Calls/Mo | Team | Retention | Priority |
|------|----------|------------|----------|--------------|------|-----------|----------|
| Free | 10 | 25 | 3 | 0 | 1 | 30 days | 50 |
| Developer | 100 | 50 | 5 | 1,000 | 1 | 90 days | 40 |
| Startup | 500 | 100 | 20 | 10,000 | 10 | 180 days | 25 |
| Professional | -1 | -1 | -1 | -1 | 25 | 365 days | 10 |
| Enterprise | -1 | -1 | -1 | -1 | -1 | 730 days | 5 |

**Feature Flags by Tier:**
- `api_access_enabled`: developer+
- `webhooks_enabled`: startup+

**Trigger Updated:**
- `create_user_quota()` function updated with new 5-tier structure and all new columns

**Index Created:**
- `ix_team_invites_email` on `team_invites(email)`
- `ix_team_invites_status` on `team_invites(status)`
- `ix_team_invites_inviter` on `team_invites(inviter_user_id)`
- `ix_team_invites_token` (UNIQUE) on `team_invites(invite_token)`
- `ix_team_invites_organization` on `team_invites(organization_id)`

**Migration File**: `/Users/pwner/Git/ABS/blocksecops-api-service/alembic/versions/20260103_0100-024_tier_restructure.py`

**Rollback Warning**: Downgrade reverses tier names back to old format and drops new columns/table

### Migration 025: Notification Channels (CI/CD Integrations)
- **Status**: ✅ Applied (January 3, 2026)
- **Revision ID**: `025_add_notification_channels`
- **Previous Revision**: `024_tier_restructure`
- **Description**: Notification channel configuration for Slack, Teams, and Discord webhook integrations
- **Tables Created**:
  - `notification_channels` - User-configured notification channels with webhook URLs
  - `notification_deliveries` - Audit log for notification delivery attempts

**Table Schema - `notification_channels`:**
- `id` (UUID) - Primary key
- `user_id` (UUID) - FK to users, CASCADE DELETE
- `organization_id` (UUID) - Optional FK to organizations, CASCADE DELETE
- `name` (VARCHAR(255)) - Channel display name
- `channel_type` (VARCHAR(50)) - Channel type: `slack`, `teams`, `discord`
- `webhook_url` (VARCHAR(2048)) - Webhook endpoint URL
- `events` (JSONB) - List of subscribed event types (e.g., `["scan.completed", "vulnerability.critical"]`)
- `filters` (JSONB) - Optional filters (severity, project_id, etc.)
- `is_active` (BOOLEAN) - Channel active status
- `total_notifications` (INTEGER) - Total notifications sent
- `successful_notifications` (INTEGER) - Successful deliveries
- `failed_notifications` (INTEGER) - Failed deliveries
- `last_triggered_at` (TIMESTAMPTZ) - Last notification attempt
- `last_success_at` (TIMESTAMPTZ) - Last successful delivery
- `last_failure_at` (TIMESTAMPTZ) - Last failed delivery
- `last_error` (TEXT) - Last error message
- `created_at` (TIMESTAMPTZ) - Created timestamp
- `updated_at` (TIMESTAMPTZ) - Updated timestamp

**Table Schema - `notification_deliveries`:**
- `id` (UUID) - Primary key
- `channel_id` (UUID) - FK to notification_channels, CASCADE DELETE
- `event_type` (VARCHAR(50)) - Event type (e.g., `scan.completed`)
- `event_id` (VARCHAR(100)) - Event identifier
- `payload` (JSONB) - Notification payload sent
- `status_code` (INTEGER) - HTTP response status code
- `response_body` (TEXT) - HTTP response body
- `success` (BOOLEAN) - Delivery success flag
- `error_message` (TEXT) - Error message if failed
- `duration_ms` (INTEGER) - Delivery duration in milliseconds
- `triggered_at` (TIMESTAMPTZ) - When notification was triggered
- `delivered_at` (TIMESTAMPTZ) - When delivery completed

**Indexes Created:**
- `ix_notification_channels_user_id` on `user_id`
- `ix_notification_channels_organization_id` on `organization_id`
- `ix_notification_channels_channel_type` on `channel_type`
- `ix_notification_channels_is_active` on `is_active`
- `ix_notification_deliveries_channel_id` on `channel_id`
- `ix_notification_deliveries_event_type` on `event_type`
- `ix_notification_deliveries_triggered_at` on `triggered_at`

**API Endpoints Added:**
- `GET /api/v1/notification-channels` - List user's notification channels
- `POST /api/v1/notification-channels` - Create notification channel
- `GET /api/v1/notification-channels/{id}` - Get channel by ID
- `PUT /api/v1/notification-channels/{id}` - Update channel
- `DELETE /api/v1/notification-channels/{id}` - Delete channel
- `POST /api/v1/notification-channels/{id}/test` - Test channel with sample notification
- `GET /api/v1/notification-channels/{id}/deliveries` - Get delivery history
- `GET /api/v1/notification-channels/events` - List available event types

**Related Files:**
- Migration: `alembic/versions/20260103_1200-025_add_notification_channels.py`
- Models: `src/infrastructure/database/models.py` (NotificationChannelModel, NotificationDeliveryModel)
- Notifiers: `src/infrastructure/notifications/` (slack.py, teams.py, discord.py, service.py)
- Endpoints: `src/presentation/api/v1/endpoints/notification_channels.py`
- API Service Version: v0.7.1

---

### Creating Migrations
```bash
# Generate migration from models
cd /Users/pwner/Git/ABS/blocksecops-api-service
alembic revision --autogenerate -m "add_wallet_authentication_fields"
alembic revision --autogenerate -m "add_enterprise_features_tables"
alembic revision --autogenerate -m "add_x402_payment_tables"

# Or create manually
alembic revision -m "add_wallet_authentication_fields"
alembic revision -m "add_enterprise_features_tables"
alembic revision -m "add_x402_payment_tables"
```

---

## Next Steps

1. ✅ Migration 005 completed (manual SQL execution)
2. ✅ Test scans to verify fix - all working
3. ✅ Intelligence layer complete - 397 patterns, 397 mappings
4. ✅ Load vulnerability pattern data into `vulnerability_patterns` table
5. ✅ Populate `pattern_tool_mappings` with scanner detector mappings
6. ✅ Migration 012 - Wallet authentication models complete (Phase 3.3)
7. ✅ Migration 013 - Enterprise features models complete (Phase 4.5)
8. ✅ Migration 014 - x402 payment models complete (Phase 3.4)
9. ⏳ Generate and apply alembic migrations for new tables
10. ⏳ Seed credit packages with default pricing
