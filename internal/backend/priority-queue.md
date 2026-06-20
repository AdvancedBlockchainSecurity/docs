# Scan Priority Queue System

**Repository:** blocksecops-api-service, blocksecops-tool-integration
**Version:** API 0.4.0+
**Status:** Production Ready
**Last Updated:** 2026-06-20

---

## Overview

The priority queue system ensures that paid users (growth, enterprise) get their scans processed before lower-tier users, providing a better experience and incentive to upgrade.

---

## Architecture

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    API Service                               │
│  POST /scans                                                 │
│  1. Get user tier from current_user.tier                     │
│  2. Calculate priority: _get_priority_for_tier(tier)         │
│  3. Create scan with priority field (status = 'queued')      │
│  4. HTTP POST to tool-integration for each scanner           │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                    Database                                  │
│  scans table                                                 │
│  - priority: INTEGER NOT NULL DEFAULT 50                     │
│  - ix_scans_priority: INDEX                                  │
│  - ix_scans_status_priority: INDEX (status, priority)        │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│              Tool Integration Service                        │
│  KubernetesJobManager (KJM)                                  │
│  blocksecops-tool-integration/src/scanners/                  │
│    kubernetes_job_manager.py                                 │
│  Creates one Kubernetes Job per scanner per scan             │
│  Scanner Jobs read priority from the scan record             │
└─────────────────────────────────────────────────────────────┘
```

**Note — scan dispatch path (as of PR #111, 2026-06-20):** The `poll_scan_queue` Celery beat task was removed from `blocksecops-orchestration`. Scans are now dispatched synchronously at scan-creation time: the API service calls tool-integration directly, which creates Kubernetes Jobs via the KubernetesJobManager. The orchestration service no longer polls the database for queued scans or runs scanner subprocesses in-pod.

---

## Priority Values

| Tier | Priority Value | Processing Order |
|------|----------------|------------------|
| enterprise | 5 | First (highest priority) |
| growth | 25 | Second |
| starter | 40 | Third |
| developer | 50 | Last (lowest priority) |

**Note:** Lower number = Higher priority (dispatched first at scan-creation time)

---

## Implementation

### API Service: Scan Creation

**File:** `src/presentation/api/v1/endpoints/scans.py`

```python
def _get_priority_for_tier(tier: str) -> int:
    """
    Get scan priority based on user tier.
    Lower number = higher priority (processed first).
    """
    tier_priorities = {
        "enterprise": 5,
        "enterprise_broker": 5,
        "pro": 25,
        "free": 50,
    }
    return tier_priorities.get(tier.lower() if tier else "free", 50)


# In create_scan endpoint:
scan_priority = _get_priority_for_tier(current_user.tier)
scan = ScanModel(
    contract_id=scan_data.contract_id,
    user_id=current_user.id,
    priority=scan_priority,
    # ... other fields
)
```

### Tool Integration Service: Kubernetes Job Dispatch

**File:** `blocksecops-tool-integration/src/scanners/kubernetes_job_manager.py`

The KubernetesJobManager (KJM) receives dispatch requests from the API service and creates one Kubernetes Job per scanner per scan. Jobs are created immediately when the scan is initiated — there is no polling loop. The `priority` field is stored on the scan record for observability and ordering queries, but Kubernetes Job scheduling is not currently weighted by priority value.

**Known gap — stale-scan re-dispatch (BSO-SEC-030):** The removed `poll_scan_queue` task previously re-dispatched scans that had been reset to `queued` after a stale-scan timeout. The replacement path for this is not yet implemented:

- `check_stale_scans` (Celery beat, still active) marks stale `running` scans as `failed` rather than re-queuing them.
- The admin manual retry endpoint (`blocksecops-api-service/src/presentation/api/v1/endpoints/admin/scan_monitoring.py:285-329`) resets a scan's status to `queued` but does NOT trigger a new Kubernetes Job.
- As a result, a scan manually retried via the admin endpoint will remain in `queued` state indefinitely until BSO-SEC-030 is resolved.

Do not document a re-dispatch path here until BSO-SEC-030 is closed.

---

## Database Schema

### Column Definition

```sql
-- Column: scans.priority
priority INTEGER NOT NULL DEFAULT 50

-- Indexes for efficient querying
CREATE INDEX ix_scans_priority ON scans (priority);
CREATE INDEX ix_scans_status_priority ON scans (status, priority);
```

### Migration

**File:** `alembic/versions/20251125_1600-d7381fad7bd9_add_scan_priority_column.py`

```python
def upgrade() -> None:
    op.add_column(
        'scans',
        sa.Column('priority', sa.Integer(), nullable=False, server_default='50')
    )
    op.create_index('ix_scans_priority', 'scans', ['priority'])
    op.create_index('ix_scans_status_priority', 'scans', ['status', 'priority'])

def downgrade() -> None:
    op.drop_index('ix_scans_status_priority', table_name='scans')
    op.drop_index('ix_scans_priority', table_name='scans')
    op.drop_column('scans', 'priority')
```

---

## Query Performance

The composite index `ix_scans_status_priority` is optimized for admin and monitoring queries over queued scans:

```sql
SELECT * FROM scans
WHERE status = 'queued'
ORDER BY priority ASC
LIMIT 10;
```

This allows PostgreSQL to efficiently:
1. Filter by status using the index
2. Return results already sorted by priority

The `FOR UPDATE SKIP LOCKED` clause was previously used by `poll_scan_queue` to prevent concurrent dispatch conflicts. It is no longer needed for normal scan dispatch now that Jobs are created at scan-creation time by the tool-integration service.

---

## Behavior Scenarios

### Scenario 1: Mixed Submissions
```
Submissions:
- Scan A: developer user (priority 50) — submitted 10:00
- Scan B: enterprise user (priority 5)  — submitted 10:01
- Scan C: growth user (priority 25)     — submitted 10:02

Each scan triggers an immediate Kubernetes Job at submission time.
Priority affects ordering in admin monitoring views, not Job scheduling order.
```

### Scenario 2: Same Tier
```
Submissions:
- Scan A: developer user (priority 50, submitted 10:00)
- Scan B: developer user (priority 50, submitted 10:01)
- Scan C: developer user (priority 50, submitted 10:02)

Jobs are created at submission time. Database index returns A → B → C
(FIFO within same priority) for admin queue monitoring queries.
```

---

## Monitoring

### Check Queue State

```sql
-- View queued scans by priority
SELECT priority, COUNT(*) as count
FROM scans
WHERE status = 'queued'
GROUP BY priority
ORDER BY priority;

-- View priority distribution of all scans
SELECT priority, status, COUNT(*) as count
FROM scans
GROUP BY priority, status
ORDER BY priority, status;
```

### Kubernetes Job Monitoring

Monitor scanner Job creation and completion via the tool-integration service logs and Kubernetes Job resources in the `scanner-jobs` namespace. The `poll_scan_queue` Celery task no longer exists; Celery Flower no longer shows scan dispatch activity.

---

## Configuration

### Priority Values

To modify priority values, update `_get_priority_for_tier()` in:
- `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py`

### Default Priority

The default priority (50) is set in:
- Database migration (server_default)
- ScanModel definition (default value)

---

## Related Documentation

- [Smart Contract Scanning Workflow](/home/pwner/Git/docs/workflows/smart-contract-scanning-workflow.md)
- [Scan Timeout and Retry Workflow](/home/pwner/Git/docs/workflows/scan-timeout-retry-workflow.md)
- [Tool Integration Service](../../../blocksecops-tool-integration/README.md)
