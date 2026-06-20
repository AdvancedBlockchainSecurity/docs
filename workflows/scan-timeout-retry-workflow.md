# Scan Timeout & Auto-Retry Workflow

**Last Updated**: 2026-06-20
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
│              │    │ reset to 'queued'                   │
│              │    │ (retry_count < limit)               │
│              ▼    │ [no auto re-dispatch — BSO-SEC-030] │
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
- No conflict with concurrent `check_stale_scans` executions (Beat runs every 30s)
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

### Phase 4: Re-Dispatch (Gap — BSO-SEC-030)

When `check_stale_scans` exceeds the retry limit, scans are marked `failed`. When under the limit, the scan is reset to `queued` with an incremented `retry_count`. However, **no automatic re-dispatch occurs at this point**.

The `poll_scan_queue` Celery beat task that previously picked up re-queued scans and dispatched new Kubernetes Jobs has been removed (blocksecops-orchestration PR #111, 2026-06-20). The replacement dispatch path for retry scenarios is not yet implemented.

Current behavior after a scan is reset to `queued` by `check_stale_scans`:
- The scan remains in `queued` status indefinitely.
- The admin manual retry endpoint (`POST /api/v1/admin/scan-monitoring/scans/{scan_id}/retry`) resets the scan to `queued` but does not trigger a new Kubernetes Job.
- A human operator must track and re-submit scans via the API until BSO-SEC-030 is resolved.

**BSO-SEC-030** tracks adding automatic re-dispatch from tool-integration when a scan is reset to `queued` after a stale-timeout retry.

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
| Concurrent `check_stale_scans` runs | Uses `SKIP LOCKED` — concurrent Beat executions skip each other's locked rows |
| Manual retry + auto-retry | Manual uses `FOR UPDATE` (blocking), auto uses `SKIP LOCKED` (skips) |
| Double dispatch prevention | Not currently enforced at re-queue time (see BSO-SEC-030) — `poll_scan_queue` which enforced this via batch-locking has been removed |

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
