# Scan Priority Queue System

**Repository:** blocksecops-api-service, blocksecops-orchestration
**Version:** API 0.4.0+, Orchestration 0.3.0+
**Status:** Production Ready
**Last Updated:** November 25, 2025

---

## Overview

The priority queue system ensures that paid users (Pro, Enterprise) get their scans processed before free tier users, providing a better experience and incentive to upgrade.

---

## Architecture

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    API Service                               │
│  POST /scans                                                 │
│  1. Get user tier from current_user.tier                     │
│  2. Calculate priority: _get_priority_for_tier(tier)         │
│  3. Create scan with priority field                          │
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
│                 Orchestration Service                        │
│  poll_scan_queue task                                        │
│  SELECT * FROM scans                                         │
│  WHERE status = 'queued'                                     │
│  ORDER BY priority ASC  <-- Lower number = Higher priority   │
│  LIMIT batch_size                                            │
└─────────────────────────────────────────────────────────────┘
```

---

## Priority Values

| Tier | Priority Value | Processing Order |
|------|----------------|------------------|
| Enterprise | 5 | First (highest priority) |
| Enterprise Broker | 5 | First |
| Pro | 25 | Second |
| Free | 50 | Third (lowest priority) |

**Note:** Lower number = Higher priority (processed first)

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

### Orchestration Service: Queue Polling

**File:** `src/blocksecops_orchestration/tasks/scan_tasks_sync.py`

```python
@celery_app.task(name="blocksecops_orchestration.tasks.scan_tasks.poll_scan_queue")
def poll_scan_queue() -> dict:
    with get_db_session() as session:
        from blocksecops_orchestration.models import ScanModel

        # Query for queued scans, ordered by priority (lower = higher priority)
        query = (
            select(ScanModel)
            .where(ScanModel.status == "queued")
            .order_by(ScanModel.priority.asc())  # Lower number = higher priority
            .limit(settings.scan_batch_size)
            .with_for_update(skip_locked=True)
        )
        # ... process scans
```

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

The composite index `ix_scans_status_priority` is optimized for the common query pattern:

```sql
SELECT * FROM scans
WHERE status = 'queued'
ORDER BY priority ASC
LIMIT 10
FOR UPDATE SKIP LOCKED;
```

This allows PostgreSQL to efficiently:
1. Filter by status using index
2. Return results already sorted by priority
3. Skip locked rows for concurrent processing

---

## Behavior Scenarios

### Scenario 1: Mixed Queue
```
Queue State:
- Scan A: Free user (priority 50)
- Scan B: Enterprise user (priority 5)
- Scan C: Pro user (priority 25)
- Scan D: Free user (priority 50)

Processing Order: B → C → A → D
```

### Scenario 2: Same Tier
```
Queue State:
- Scan A: Free user (priority 50, created 10:00)
- Scan B: Free user (priority 50, created 10:01)
- Scan C: Free user (priority 50, created 10:02)

Processing Order: A → B → C (FIFO within same priority)
```

### Scenario 3: Continuous Submissions
```
10:00 - Free user submits Scan A (priority 50)
10:01 - Scan A starts processing
10:02 - Enterprise user submits Scan B (priority 5)
10:03 - Next poll picks up Scan B (higher priority than any pending Free scans)
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

### Celery Flower

Monitor the `poll_scan_queue` task execution and scan processing throughput.

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

- [Monthly Quota Reset](/Users/pwner/Git/ABS/blocksecops-docs/backend/monthly-quota-reset.md)
- [Quota Frontend](/Users/pwner/Git/ABS/blocksecops-docs/frontend/quota-frontend.md)
- [Celery Configuration](/Users/pwner/Git/ABS/blocksecops-orchestration/README.md)
