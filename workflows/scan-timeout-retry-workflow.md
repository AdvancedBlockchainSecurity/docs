# Scan Timeout & Auto-Retry Workflow

**Last Updated**: 2026-02-06
**Status**: Active
**API Version**: v1

## Overview

This workflow handles detection and recovery of scans stuck in `running` state due to worker preemption, crashes, or infrastructure issues on GCP spot/preemptible VMs.

```
┌────────────────────────────────────────────────────────┐
│                 Scan Lifecycle                          │
│                                                        │
│  queued ──▶ running ──▶ completed                      │
│              │    ▲                                     │
│              │    │ retry (if retry_count < limit)      │
│              ▼    │                                     │
│           stale ──┘                                     │
│              │                                          │
│              ▼ (if retry_count >= limit)                │
│           failed                                        │
└────────────────────────────────────────────────────────┘
```

## Services Involved

| Service | Role | Port |
|---------|------|------|
| Orchestration (Beat) | Schedules `check_stale_scans` every 30s | 8004 |
| Orchestration (Worker) | Executes stale scan detection and recovery | 8004 |
| API Service | Provides admin monitoring endpoints | 8000 |
| Admin Portal | UI for scan health monitoring | 3000 |
| PostgreSQL | Stores scan state and retry tracking | 5432 |

## Automatic Recovery Flow

### Phase 1: Detection (Celery Beat)

Beat scheduler sends `check_stale_scans` task every 30 seconds.

### Phase 2: Query Stale Scans (Worker)

```sql
SELECT * FROM scans
WHERE status = 'running'
  AND started_at < NOW() - INTERVAL '600 seconds'
FOR UPDATE SKIP LOCKED
```

`FOR UPDATE SKIP LOCKED` ensures:
- No conflict with `poll_scan_queue` (which also uses `SKIP LOCKED`)
- No conflict with manual admin retry (which uses `FOR UPDATE`)

### Phase 3: Recovery Decision

For each stale scan:

**If retry_count < retry_limit (default 3):**
- Set `status = 'queued'`
- Set `started_at = NULL`
- Increment `retry_count`
- Set `last_retry_at = NOW()`
- Set `retry_reason = 'stale_timeout'`

**If retry_count >= retry_limit:**
- Set `status = 'failed'`
- Set `error_message = 'Scan exceeded maximum retries after becoming unresponsive'`

### Phase 4: Re-Dispatch

Requeued scans are picked up by `poll_scan_queue` (runs every 10s), which dispatches them respecting priority ordering and batch limits.

## Manual Admin Recovery Flow

### Via Admin Portal

1. Admin navigates to Scan Monitoring page
2. Reviews stale scan table
3. Clicks Retry or Force Fail
4. Enters reason (required, audit logged)
5. System updates scan state

### Via API

**Retry:**
```
POST /api/v1/admin/scan-monitoring/scans/{scan_id}/retry
Authorization: Bearer <jwt>
X-Admin-Session: <session>
Body: {"reason": "Worker recovered after preemption"}
```

**Force Fail:**
```
POST /api/v1/admin/scan-monitoring/scans/{scan_id}/fail
Authorization: Bearer <jwt>
X-Admin-Session: <session>
Body: {"reason": "Permanent infrastructure issue"}
```

## Configuration

| Setting | Location | Default |
|---------|----------|---------|
| `scan_stale_timeout` | Orchestration config | 600 (seconds) |
| `scan_retry_limit` | Orchestration config / API config | 3 |
| Beat schedule interval | `celery_app.py` | 30 (seconds) |

## Race Condition Safety

| Scenario | Protection |
|----------|-----------|
| `check_stale_scans` + `poll_scan_queue` | Both use `SKIP LOCKED` — one skips the other's locked rows |
| Manual retry + auto-retry | Manual uses `FOR UPDATE` (blocking), auto uses `SKIP LOCKED` (skips) |
| Double dispatch prevention | Scans reset to `queued`, not re-dispatched directly |

## Monitoring

Admin Portal Scan Monitoring page shows:
- Active scan count
- Stale scan count (pulsing red when > 0)
- Auto-retry count (24h)
- Failed scan count (24h)
- Average retry count
- Detailed stale scan table with action buttons

## Related Documentation

- [Scan Stale Recovery Playbook](../playbooks/scan-stale-recovery.md)
- [Smart Contract Scanning Workflow](./smart-contract-scanning-workflow.md)
- [Feature Test: Scan Timeout & Auto-Retry](../feature-tests/58-scan-timeout-auto-retry.md)
