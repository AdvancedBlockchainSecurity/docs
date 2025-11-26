# Database Schema Changelog - November 25, 2025

**Date:** November 25, 2025
**Session:** Priority Queue & Monthly Quota Reset Implementation

---

## Migration: d7381fad7bd9 - Add Scan Priority Column

**File:** `blocksecops-api-service/alembic/versions/20251125_1600-d7381fad7bd9_add_scan_priority_column.py`
**Parent:** `efa3c7c50d04`

### Changes

#### New Column: `scans.priority`
- **Type:** INTEGER NOT NULL DEFAULT 50
- **Purpose:** Tier-based scan priority for queue processing
- **Values:**
  - Enterprise: 5 (highest priority)
  - Pro: 25 (high priority)
  - Free: 50 (standard priority)
- Lower number = higher priority (processed first)

#### New Indexes
- `ix_scans_priority` - Index on priority column
- `ix_scans_status_priority` - Composite index on (status, priority) for queue polling

### SQL Applied
```sql
ALTER TABLE scans ADD COLUMN priority INTEGER NOT NULL DEFAULT 50;
CREATE INDEX ix_scans_priority ON scans (priority);
CREATE INDEX ix_scans_status_priority ON scans (status, priority);
```

### Related Code Changes

**API Service:**
- `src/infrastructure/database/models.py` - Added `priority` field to ScanModel
- `src/presentation/api/v1/endpoints/scans.py` - Added `_get_priority_for_tier()` helper and priority assignment on scan creation

**Orchestration Service:**
- `src/blocksecops_orchestration/models/models.py` - Added `priority` field to ScanModel
- `src/blocksecops_orchestration/tasks/scan_tasks_sync.py` - Updated `poll_scan_queue` to sort by priority
- `src/blocksecops_orchestration/tasks/quota_tasks_sync.py` - New module for quota reset tasks
- `src/blocksecops_orchestration/core/celery_app.py` - Added monthly reset to beat_schedule

---

## Migration History Reference

All migrations are tracked in the Alembic versions directory:
`/blocksecops-api-service/alembic/versions/`

| Revision | Date | Description |
|----------|------|-------------|
| 001 | 2025-10-12 | Initial schema |
| 002 | 2025-10-14 | Add 'uploaded' status |
| 003 | 2025-10-15 | Projects table |
| 004 | 2025-10-18 | Production enhancements |
| 005-006 | 2025-10-24 | Parser enrichment fields |
| 012 | 2025-11-02 | Deduplication groups fix |
| cf314965ed8c | 2025-11-12 | Supabase auth integration |
| efa3c7c50d04 | 2025-11-12 | User quotas table |
| **d7381fad7bd9** | **2025-11-25** | **Scan priority column** |

---

## Related Documentation

- [Priority Queue System](/Users/pwner/Git/ABS/blocksecops-docs/backend/priority-queue.md)
- [Monthly Quota Reset](/Users/pwner/Git/ABS/blocksecops-docs/backend/monthly-quota-reset.md)
- [Session Documentation](/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/DOCUMENTATION-UPDATE-2025-11-25-SESSION-4.md)
