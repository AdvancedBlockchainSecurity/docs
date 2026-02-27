# Playbook: Scan Stale Recovery & Monitoring

**Version**: 2.0.0
**Last Updated**: 2026-02-27

## Overview

This playbook covers monitoring and recovering stale scans — scans stuck in `queued` or `running` state due to worker preemption, crashes, queue failures, or infrastructure issues. The platform includes automatic detection and recovery for both states, but admins may need to intervene for scans that exceed retry limits.

**When to use this playbook:**
- Investigating elevated stale scan counts
- Manually recovering a stuck scan
- Diagnosing repeated scan failures
- Verifying auto-retry is functioning

## Prerequisites

- Admin portal access (`platform_admin` role or higher)
- Access to `admin.blocksecops.local` or `admin.blocksecops.com`

## How Auto-Recovery Works

```
┌──────────────┐     ┌─────────────────┐     ┌──────────────┐
│  Scan starts │────▶│  Running state   │────▶│  Completed   │
│  (queued)    │     │  (started_at)    │     │              │
└──────┬───────┘     └────────┬─────────┘     └──────────────┘
       │                      │
       │ Never picked up      │ Worker killed (preemption/crash)
       │ (queue failure)      │ Scan stuck in running state
       ▼                      ▼
┌──────────────┐     ┌─────────────────┐
│ Stale queued │     │  Stale running  │ (check_stale_scans, every 30s)
│ created_at > │     │  started_at >   │
│ stale_timeout│     │  stale_timeout  │
└──────┬───────┘     └────────┬────────┘
       │                      │
       ▼               ┌──────┴──────┐
┌──────────────┐       │             │
│   Failed     │  retry_count < retry_count >=
│ (never ran)  │  retry_limit   retry_limit
└──────────────┘       │             │
                       ▼             ▼
                ┌────────────┐ ┌──────────────┐
                │  Requeued  │ │   Failed     │
                │  (retry)   │ │  (max retry) │
                └────────────┘ └──────────────┘
```

**Important (v0.10.6+):** Scans stuck in `queued` state (never picked up by a worker) are always failed immediately — they are not retried because the issue is queue/worker availability, not a transient scan failure. Running scans are retried up to `scan_retry_limit` times before being failed.

**Configuration:**
| Setting | Default | Description |
|---------|---------|-------------|
| `scan_stale_timeout` | 600s (10m) | Time before a running scan is considered stale |
| `scan_retry_limit` | 3 | Maximum auto-retry attempts |
| Beat interval | 30s | How often stale scan check runs |

## Step 1: Check Scan Health (Admin Portal)

1. Navigate to **Admin Portal** > **Scan Monitoring**
2. Review the KPI cards:
   - **Active Scans**: Currently running scans
   - **Stale Scans**: Scans stuck past timeout (should be 0 in healthy state)
   - **Auto-Retries 24h**: Number of automatic recovery events
   - **Failed 24h**: Scans that exhausted retries

**Healthy state**: Stale Scans = 0, Auto-Retries stable or low

## Step 2: Investigate Stale Scans

If the stale scan count is elevated:

1. Check the **Stale Scans Table** for affected scans
2. Note the **stale duration** — longer durations indicate the auto-retry may not be catching them
3. Check **retry count** — scans near the retry limit may need manual intervention

**Via API:**
```bash
curl -s -H "Authorization: Bearer $JWT" \
  -H "X-Admin-Session: $SESSION" \
  "https://admin.blocksecops.com/api/v1/admin/scan-monitoring/stale"
```

## Step 3: Manual Recovery

### Retry a Scan
Use when a scan should be attempted again:

1. Click **Retry** button on the stale scan in the admin portal
2. Enter a reason (required for audit trail)
3. Confirm — scan resets to `queued` and will be picked up by the queue poller

**Via API:**
```bash
curl -X POST -H "Authorization: Bearer $JWT" \
  -H "X-Admin-Session: $SESSION" \
  -H "Content-Type: application/json" \
  -d '{"reason": "Worker node recovered, retrying scan"}' \
  "https://admin.blocksecops.com/api/v1/admin/scan-monitoring/scans/{scan_id}/retry"
```

### Force Fail a Scan
Use when a scan should not be retried (e.g., known bad input, permanent infrastructure issue):

1. Click **Force Fail** button on the scan
2. Enter a reason (required for audit trail)
3. Confirm — scan is marked as `failed` with admin reason

**Via API:**
```bash
curl -X POST -H "Authorization: Bearer $JWT" \
  -H "X-Admin-Session: $SESSION" \
  -H "Content-Type: application/json" \
  -d '{"reason": "Contract source corrupted, scan cannot complete"}' \
  "https://admin.blocksecops.com/api/v1/admin/scan-monitoring/scans/{scan_id}/fail"
```

## Step 4: Verify Recovery

After taking action:
1. Click **Refresh** on the scan monitoring page
2. Verify the stale scan count decreased
3. Check that retried scans appear in the queue or complete successfully

## Troubleshooting

| Problem | Root Cause | Fix |
|---------|-----------|-----|
| Stale scans not being detected | Beat task not running | Check orchestration-beat container logs |
| Scans keep becoming stale | Worker nodes being preempted frequently | Review GCP spot instance configuration |
| High auto-retry count | Intermittent infrastructure issues | Check worker node health and resource limits |
| Force fail not working | Scan already completed by the time admin acts | Normal race condition — no action needed |

## Verification Checklist

- [ ] Scan Monitoring page loads in admin portal
- [ ] KPI cards show correct counts
- [ ] Stale scans table displays when scans are stuck
- [ ] Retry action resets scan to queued
- [ ] Force fail action marks scan as failed
- [ ] Auto-refresh updates every 30 seconds
- [ ] All actions appear in audit logs

## Two Recovery Mechanisms

The platform has two independent stale scan recovery mechanisms:

### 1. Orchestration Celery Beat (Primary — v0.10.6+)

Runs every 30 seconds via `check_stale_scans` task. Directly queries the database.

- **Queued scans**: Failed immediately with `error_message: "Scan stuck in queued state — never picked up by worker"`
- **Running scans (retries left)**: Requeued with incremented `retry_count`
- **Running scans (max retries)**: Failed with `error_message: "Scan exceeded maximum retries after becoming unresponsive"`

The outer exception handler in `execute_scan_analysis` also records `error_message` on unexpected failures, preventing NULL error messages on failed scans.

### 2. API Service Maintenance Endpoint (Secondary — v0.28.38+)

HTTP endpoint for recovery of scans that the orchestration beat may miss (e.g., scans where the callback never arrived):

```bash
# Recover scans stuck in queued/running for >1 hour
# Records error_message with recovery context and original status
curl -sk -X POST https://app.blocksecops.local/api/v1/scans/maintenance/recover-stale-scans \
  -H "X-Internal-Service: true"
```

This endpoint records `error_message: "Recovered by maintenance: scan was stuck in '{status}' status for over 1 hour (created {timestamp})"` and resets associated contract status from `scanning` to `scanned`.

### Key Difference

| Mechanism | Interval | Timeout | Handles Queued | Retries Running | Records error_message |
|---|---|---|---|---|---|
| Orchestration beat | 30s | 600s (10m) | Yes (v0.10.6+) | Yes (up to 3) | Yes |
| API maintenance endpoint | On-demand / CronJob | 3600s (1h) | Yes | No (fails immediately) | Yes (v0.29.37+) |

**See also:** [Database manual fix for existing stuck contracts](../database/MANUAL-FIXES-2026-02-17-STALE-SCANS.md)

---

## Related Playbooks

- [upgrade-scanner-image.md](./upgrade-scanner-image.md) — Scanner upgrade procedures
- [admin-emergency-operations.md](./admin-emergency-operations.md) — Emergency admin actions
