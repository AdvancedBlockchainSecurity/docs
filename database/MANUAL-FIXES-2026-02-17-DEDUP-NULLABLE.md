# Database Manual Fix: deduplication_groups.canonical_finding_id NOT NULL Constraint

**Date:** February 17, 2026
**Applied By:** Platform team
**Severity:** Critical (blocked scan deletion from UI)

---

## Issue

Users could not delete scans from the dashboard UI. Clicking "Delete" in the confirmation modal had no effect. The API returned a 500 error.

**Symptom:** DELETE `/api/v1/scans` returns 500 Internal Server Error. No scans can be deleted when they have vulnerabilities linked to deduplication groups.

### Root Cause

The `deduplication_groups.canonical_finding_id` column had a `NOT NULL` constraint in the database, but the foreign key was defined as `ON DELETE SET NULL`. When a scan's vulnerabilities were deleted (cascade from scan deletion), PostgreSQL attempted to set `canonical_finding_id = NULL` in any deduplication group referencing those vulnerabilities. The `NOT NULL` constraint blocked this, causing the entire transaction to fail.

The SQLAlchemy model already declared the column as nullable:

```python
# infrastructure/database/specialized_models/intelligence.py
canonical_finding_id: Mapped[UUID | None] = mapped_column(
    PG_UUID(as_uuid=True), ForeignKey("vulnerabilities.id", ondelete="SET NULL"), nullable=True
)
```

The database constraint did not match the model, likely from an older migration or manual schema creation.

## Fix Applied

```sql
ALTER TABLE deduplication_groups ALTER COLUMN canonical_finding_id DROP NOT NULL;
```

## Verification

```sql
-- Verify column is now nullable
SELECT column_name, is_nullable
FROM information_schema.columns
WHERE table_name = 'deduplication_groups' AND column_name = 'canonical_finding_id';
-- Expected: is_nullable = 'YES'

-- Verify FK rule
SELECT constraint_name, delete_rule
FROM information_schema.referential_constraints
WHERE constraint_name = 'deduplication_groups_canonical_finding_id_fkey';
-- Expected: delete_rule = 'SET NULL'

-- Test scan deletion from UI
-- Navigate to contract detail page, select a scan, click Delete
```

## Impact

- **Before fix:** All scan deletions from the UI failed silently (API 500 error)
- **After fix:** Scan deletion works. Dedup groups with deleted canonical findings get `canonical_finding_id = NULL`. The deduplication maintenance CronJob re-elects a new canonical finding on its next run.

## How to Reproduce Fix

If recreating the database from scratch and this fix is not yet in an Alembic migration:

```bash
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security \
  -c "ALTER TABLE deduplication_groups ALTER COLUMN canonical_finding_id DROP NOT NULL;"
```

## Related

- SQLAlchemy model: `blocksecops-api-service/src/infrastructure/database/specialized_models/intelligence.py:128`
- Dedup maintenance (re-elects canonical): `blocksecops-api-service/src/infrastructure/tasks/deduplication_maintenance.py`
- Scan delete endpoint: `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py:2707`
