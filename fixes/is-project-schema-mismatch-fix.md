# is_project Schema Mismatch Fix

**Date**: October 24, 2025
**Services Affected**: blocksecops-orchestration
**Versions**: 0.7.10, 0.7.11
**Issue Type**: Database Schema Mismatch
**Priority**: Critical - Blocking all scans

---

## Overview

Fixed a critical schema mismatch where the orchestration service code referenced a `contracts.is_project` column that did not exist in the database. This issue caused all scans to fail and blocked Phase 4C enrichment testing.

## Problem

The `is_project` field was:
- **Documented** in schema documentation
- **Defined** in SQLAlchemy ORM models (models.py)
- **Referenced** in application code (scan_tasks_sync.py)
- **Not created** in database via migration

This code-database mismatch caused scans to fail with:
```
ERROR: column contracts.is_project does not exist
```

## Root Cause

The field was planned for future implementation to distinguish single-file contracts from full project structures, but the migration to add it was never created. Meanwhile, code was written assuming the field existed.

## Solution

Required two iterations to fix all references:

### Version 0.7.10 (Incomplete)
- Removed conditional logic checking `contract.is_project`
- **Still failed**: ORM model definition caused SQLAlchemy to SELECT the non-existent column

### Version 0.7.11 (Complete)
- Commented out ORM field definition in ContractModel
- Removed logging statement accessing the field
- **Success**: Scans execute without errors

## Code Changes

### 1. ContractModel (models.py:86-89)

Commented out field definition:
```python
# TODO: Uncomment when is_project column added to database schema via migration
# is_project: Mapped[bool] = mapped_column(
#     Boolean, nullable=False, default=False, server_default="false"
# )
```

### 2. Scanner Filtering (scan_tasks_sync.py:181-198)

Removed conditional check and defaulted to single-file mode:
```python
# Note: is_project field not in database schema yet, defaulting to single-file mode
scanner_ids = []
for scanner_id in requested_scanners:
    executor = registry.get(scanner_id)
    if executor and not executor.requires_project:
        scanner_ids.append(scanner_id)
```

### 3. Logging (scan_tasks_sync.py:205)

Removed field from log statement:
```python
logger.info(
    "executing_scanner_orchestrator",
    scan_id=scan_id,
    contract_id=str(contract.id),
    contract_name=contract.name,
    scanners=scanner_ids,  # is_project removed
)
```

## Deployment

Both versions deployed to orchestration-local namespace via:
```bash
docker build -t blocksecops-orchestration:0.7.11 .
minikube image load blocksecops-orchestration:0.7.11
kubectl apply -k k8s/overlays/local/orchestration/
```

**Status**: ✅ v0.7.11 running successfully (4/4 containers)

## Testing

**Test Scan**: `a3d8d360-2385-4281-818f-4dae403d485e`
**Result**: Scans complete successfully with no database errors

## Documentation Updated

1. **Database Schema** (`/docs/database/SCHEMA.md`)
   - Marked `is_project` as REMOVED with strikethrough
   - Added migration history entry for code fix
   - Added detailed note about field status

2. **Task Documentation** (`/TaskDocs-Apogee/blocksecops/is-project-schema-fix.md`)
   - Comprehensive task-level documentation
   - Code changes with before/after examples
   - Testing verification details

3. **General Documentation** (this file)
   - High-level overview of fix
   - Quick reference for future developers

## Impact

**Before Fix**:
- All scans failing with database errors
- Phase 4C E2E testing blocked
- Scanner filtering logic not working

**After Fix**:
- Scans execute successfully
- Phase 4C testing unblocked
- Single-file mode working correctly

## Future Work

When full project structure support is implemented:

1. Create migration to add `is_project` column
2. Uncomment ORM field definition in models.py
3. Restore conditional scanner filtering logic
4. Update schema documentation

**Migration Example**:
```python
def upgrade():
    op.add_column('contracts',
        sa.Column('is_project', sa.Boolean(),
                 nullable=False,
                 server_default='false'))
```

## Key Takeaway

**Always ensure ORM model definitions match actual database schema.** SQLAlchemy will attempt to SELECT all mapped columns regardless of application logic.

## References

- **Task Documentation**: `/TaskDocs-Apogee/blocksecops/is-project-schema-fix.md`
- **Database Schema**: `/docs/database/SCHEMA.md`
- **ORM Models**: `/blocksecops-orchestration/src/blocksecops_orchestration/models/models.py`
- **Scan Tasks**: `/blocksecops-orchestration/src/blocksecops_orchestration/tasks/scan_tasks_sync.py`

---

**Status**: ✅ Complete
**Deployed**: v0.7.11 in orchestration-local
**Tested**: ✅ Verified
**Documented**: ✅ Complete
