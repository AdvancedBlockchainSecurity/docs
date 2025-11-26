# Database Migration History

This document tracks all database schema migrations for the BlockSecOps platform.

## Migration Summary

| Revision | Date | Description |
|----------|------|-------------|
| 001 | 2025-10-12 | Initial database schema |
| 002 | 2025-10-14 | Add 'uploaded' status to contract_status enum |
| 003 | 2025-10-15 | Add projects table and project_contracts junction |
| 004 | 2025-10-18 | Production enhancements (scanner tracking, saved searches, indexes) |
| 005 | 2025-10-24 | Parser enrichment fields to vulnerabilities |
| 006 | 2025-10-24 | Parser enrichment fields to gas_analysis_findings |
| 012 | 2025-11-02 | Deduplication groups column rename fix |
| cf314965ed8c | 2025-11-12 | Supabase auth integration (tier tracking) |
| efa3c7c50d04 | 2025-11-12 | User quotas table with auto-creation trigger |
| d7381fad7bd9 | 2025-11-25 | Scan priority column for tier-based queue |

---

## Detailed Migration History

### Migration 001 - Initial Schema
- **Date:** 2025-10-12
- **File:** `20251012_1500-001_initial_schema.py`
- **Tables Created:** users, contracts, scans, vulnerabilities
- **Features:** Multi-language and multi-file support

### Migration 002 - Uploaded Status
- **Date:** 2025-10-14
- **File:** `20251014_1400-002_add_uploaded_status.py`
- **Changes:** Add 'uploaded' status to contract_status enum

### Migration 003 - Projects
- **Date:** 2025-10-15
- **File:** `20251015_1000-003_add_projects_table.py`
- **Tables Created:** projects, project_contracts

### Migration 004 - Production Enhancements
- **Date:** 2025-10-18
- **File:** `20251017_2112-08bf8921767b_comprehensive_production_enhancements_.py`
- **Features:**
  - Scanner tracking fields
  - Vulnerability categorization
  - Saved searches
  - User preferences
  - Enrichment fingerprint fields
  - 13+ performance indexes

### Migrations 005-006 - Parser Enrichment (Phase 4D)
- **Date:** 2025-10-24
- **Files:** Manual SQL scripts
- **Changes:**
  - detector_id, file_path, function_name, contract_name to vulnerabilities
  - Same fields to gas_analysis_findings

### Migration 012 - Deduplication Groups Fix
- **Date:** 2025-11-02
- **File:** `20251102_1251-a2240d8cd745_fix_deduplication_groups_column_names.py`
- **Changes:**
  - Renamed `primary_vulnerability_id` → `canonical_finding_id`
  - Renamed `pattern_id` → `pattern_code` (VARCHAR(50))

### Migration cf314965ed8c - Supabase Auth Integration
- **Date:** 2025-11-12
- **File:** `20251112_1408-cf314965ed8c_add_supabase_tier_tracking_to_users.py`
- **Columns Added to users:**
  - tier, tier_updated_at
  - supabase_user_id
  - stripe_customer_id, stripe_subscription_id

### Migration efa3c7c50d04 - User Quotas
- **Date:** 2025-11-12
- **File:** `20251112_1453-efa3c7c50d04_create_user_quotas_table_with_trigger.py`
- **Tables Created:** user_quotas
- **Features:** Auto-creation trigger for tier-based limits

### Migration d7381fad7bd9 - Scan Priority
- **Date:** 2025-11-25
- **File:** `20251125_1600-d7381fad7bd9_add_scan_priority_column.py`
- **Changes:**
  - Added `priority` column to scans (INTEGER NOT NULL DEFAULT 50)
  - Created ix_scans_priority index
  - Created ix_scans_status_priority composite index
- **Purpose:** Tier-based queue processing (Enterprise=5, Pro=25, Free=50)

---

## Running Migrations

**Apply all migrations:**
```bash
cd /Users/pwner/Git/ABS/blocksecops-api-service
source .venv/bin/activate
export DATABASE_URL="postgresql+asyncpg://postgres:postgres@127.0.0.1:5432/solidity_security"
alembic upgrade head
```

**Check current version:**
```bash
alembic current
```

**Generate new migration:**
```bash
alembic revision -m "description"
```

**Rollback last migration:**
```bash
alembic downgrade -1
```

---

## Related Documentation

- [Database Schema](/Users/pwner/Git/ABS/docs/database/SCHEMA.md)
- [Manual Fixes](/Users/pwner/Git/ABS/docs/database/MANUAL-FIXES.md)
- [Migration Files](/Users/pwner/Git/ABS/blocksecops-api-service/alembic/versions/)
