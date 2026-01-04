# Monthly Quota Reset System

**Repository:** blocksecops-orchestration
**Version:** 0.3.0+
**Status:** Production Ready
**Last Updated:** November 25, 2025

---

## Overview

The monthly quota reset system automatically resets user scan counters at the start of each month, preventing users from being permanently blocked after using their monthly quota.

---

## Architecture

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                   Celery Beat Scheduler                      │
│  Schedule: 00:00 UTC on 1st of each month                   │
│  Task: reset_monthly_quotas                                  │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                 Orchestration Worker                         │
│  reset_monthly_quotas task                                   │
│  1. UPDATE user_quotas SET monthly_scans_used = 0           │
│  2. UPDATE user_quotas SET quota_reset_at = next_month      │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                    Database                                  │
│  user_quotas table                                           │
│  - monthly_scans_used: reset to 0                           │
│  - quota_reset_at: updated to 1st of next month             │
└─────────────────────────────────────────────────────────────┘
```

---

## Celery Beat Schedule

**File:** `blocksecops-orchestration/src/blocksecops_orchestration/core/celery_app.py`

```python
from celery.schedules import crontab

celery_app.conf.update(
    beat_schedule={
        # ... other tasks ...

        # Monthly quota reset: runs at 00:00 UTC on the 1st of each month
        "reset-monthly-quotas": {
            "task": "blocksecops_orchestration.tasks.quota_tasks.reset_monthly_quotas",
            "schedule": crontab(minute=0, hour=0, day_of_month=1),
        },

        # Daily quota status check: runs at 06:00 UTC daily for monitoring
        "check-quota-status": {
            "task": "blocksecops_orchestration.tasks.quota_tasks.check_quota_status",
            "schedule": crontab(minute=0, hour=6),
        },
    },
)
```

---

## Task Implementation

### reset_monthly_quotas

**File:** `blocksecops-orchestration/src/blocksecops_orchestration/tasks/quota_tasks_sync.py`

```python
@celery_app.task(
    name="blocksecops_orchestration.tasks.quota_tasks.reset_monthly_quotas",
    bind=False,
)
def reset_monthly_quotas() -> dict:
    """
    Reset monthly scan counters for all users.

    Returns:
        dict: Statistics about the reset operation
    """
    logger.info("reset_monthly_quotas_started")

    try:
        with get_db_session() as session:
            from blocksecops_orchestration.models import UserQuotaModel

            # Calculate next reset date (1st of next month at 00:00 UTC)
            now = datetime.now(timezone.utc)
            next_month = now + relativedelta(months=1)
            next_reset_date = datetime(
                year=next_month.year,
                month=next_month.month,
                day=1,
                hour=0, minute=0, second=0,
                tzinfo=timezone.utc
            )

            # Reset all user quotas
            stmt = (
                update(UserQuotaModel)
                .values(
                    monthly_scans_used=0,
                    quota_reset_at=next_reset_date,
                    updated_at=now,
                )
            )

            result = session.execute(stmt)
            rows_updated = result.rowcount
            session.commit()

            return {
                "status": "success",
                "users_reset": rows_updated,
                "reset_at": now.isoformat(),
                "next_reset_at": next_reset_date.isoformat(),
            }

    except Exception as e:
        logger.error("reset_monthly_quotas_failed", error=str(e))
        return {"status": "failed", "error": str(e)}
```

### check_quota_status

A monitoring task that runs daily to track quota usage statistics.

```python
@celery_app.task(
    name="blocksecops_orchestration.tasks.quota_tasks.check_quota_status",
    bind=False,
)
def check_quota_status() -> dict:
    """
    Check and log quota usage statistics for monitoring.

    Returns:
        dict: Quota statistics summary
    """
    # Returns:
    # {
    #     "total_users": 150,
    #     "total_scans_used": 1234,
    #     "avg_scans_per_user": 8.2,
    #     "users_at_limit": 12
    # }
```

---

## Database Model

### UserQuotaModel in Orchestration

**File:** `blocksecops-orchestration/src/blocksecops_orchestration/models/models.py`

```python
class UserQuotaModel(Base):
    """User quota model for tier-based limits."""

    __tablename__ = "user_quotas"

    id: Mapped[Uuid] = mapped_column(Uuid, primary_key=True)
    user_id: Mapped[Uuid] = mapped_column(Uuid, nullable=False, unique=True)
    tier: Mapped[str] = mapped_column(String(20), nullable=False, server_default="free")
    monthly_scan_limit: Mapped[int] = mapped_column(Integer, nullable=False, server_default="10")
    monthly_scans_used: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0")
    quota_reset_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    # ... timestamps
```

---

## Manual Execution

### Trigger Reset Manually

```python
# Via Celery
from blocksecops_orchestration.tasks.quota_tasks_sync import reset_monthly_quotas
result = reset_monthly_quotas.delay()
print(result.get())

# Direct call (for testing)
result = reset_monthly_quotas()
print(result)
```

### Check Quota Status

```python
from blocksecops_orchestration.tasks.quota_tasks_sync import check_quota_status
result = check_quota_status()
print(result)
```

---

## SQL Queries

### Reset All Quotas

```sql
UPDATE user_quotas
SET
    monthly_scans_used = 0,
    quota_reset_at = date_trunc('month', CURRENT_TIMESTAMP + interval '1 month'),
    updated_at = CURRENT_TIMESTAMP;
```

### Check Users at Limit

```sql
SELECT COUNT(*)
FROM user_quotas
WHERE monthly_scans_used >= monthly_scan_limit
  AND monthly_scan_limit > 0;  -- Exclude unlimited (-1)
```

### View Quota Usage Summary

```sql
SELECT
    tier,
    COUNT(*) as user_count,
    SUM(monthly_scans_used) as total_scans,
    AVG(monthly_scans_used) as avg_scans,
    COUNT(*) FILTER (WHERE monthly_scans_used >= monthly_scan_limit AND monthly_scan_limit > 0) as at_limit
FROM user_quotas
GROUP BY tier
ORDER BY tier;
```

---

## Monitoring

### Celery Flower

Monitor these tasks in Flower:
- `reset_monthly_quotas`: Should run successfully on 1st of each month
- `check_quota_status`: Should run daily at 06:00 UTC

### Log Messages

```
# Successful reset
reset_monthly_quotas_started
reset_monthly_quotas_completed users_reset=150 next_reset_date=2025-02-01T00:00:00+00:00

# Daily check
check_quota_status_started
check_quota_status_completed total_users=150 total_scans_used=1234 avg_scans_per_user=8.2 users_at_limit=12
```

### Alerting

Set up alerts for:
- `reset_monthly_quotas_failed` log messages
- High `users_at_limit` count from `check_quota_status`

---

## Schedule Reference

| Task | Schedule | Purpose |
|------|----------|---------|
| `reset_monthly_quotas` | 00:00 UTC, 1st of month | Reset all quota counters |
| `check_quota_status` | 06:00 UTC, daily | Monitor quota usage |

### Crontab Syntax

```python
# Monthly on 1st at midnight UTC
crontab(minute=0, hour=0, day_of_month=1)

# Daily at 6 AM UTC
crontab(minute=0, hour=6)

# Every hour
crontab(minute=0)

# Every 5 minutes
crontab(minute='*/5')
```

---

## Failure Recovery

### If Reset Fails

1. Check Celery logs for error details
2. Run manual reset:
   ```sql
   UPDATE user_quotas
   SET monthly_scans_used = 0,
       updated_at = CURRENT_TIMESTAMP
   WHERE monthly_scans_used > 0;
   ```

3. Re-run task manually:
   ```python
   reset_monthly_quotas.delay()
   ```

### Partial Reset

If the task fails mid-execution, some users may not be reset. The task is idempotent - running it again will reset all users to 0.

---

## Dependencies

### Python Package

```
python-dateutil>=2.8.2,<3.0.0  # For relativedelta
```

### Celery Beat

The orchestration service must be running with Celery Beat enabled:

```bash
celery -A blocksecops_orchestration.core.celery_app beat --loglevel=info
```

---

## Related Documentation

- [Priority Queue System](/Users/pwner/Git/ABS/blocksecops-docs/backend/priority-queue.md)
- [Quota Frontend](/Users/pwner/Git/ABS/blocksecops-docs/frontend/quota-frontend.md)
- [Session Documentation](/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/DOCUMENTATION-UPDATE-2025-11-25-SESSION-4.md)
