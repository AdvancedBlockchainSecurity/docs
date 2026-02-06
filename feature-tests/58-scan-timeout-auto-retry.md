# Scan Timeout & Auto-Retry

**Priority**: High
**Last Tested**: 2026-02-06
**Endpoints**: `GET /api/v1/admin/scan-monitoring/stats`, `GET /api/v1/admin/scan-monitoring/stale`, `POST /api/v1/admin/scan-monitoring/scans/{id}/retry`, `POST /api/v1/admin/scan-monitoring/scans/{id}/fail`

## 1. Stale Scan Detection

### 1.1 Celery Beat Task
- [ ] `check_stale_scans` task runs every 30 seconds
- [ ] Detects scans with status `running` and `started_at` older than `scan_stale_timeout` (600s default)
- [ ] Uses `FOR UPDATE SKIP LOCKED` to avoid race conditions with `poll_scan_queue`
- [ ] Logs `check_stale_scans_started` with timeout and retry limit values

### 1.2 Auto-Retry Behavior
- [ ] Stale scan with `retry_count < scan_retry_limit` is reset to `queued`
- [ ] `retry_count` is incremented
- [ ] `last_retry_at` is set to current time
- [ ] `retry_reason` is set to `stale_timeout`
- [ ] `started_at` is cleared (NULL)

### 1.3 Max Retries Exceeded
- [ ] Stale scan with `retry_count >= scan_retry_limit` is set to `failed`
- [ ] `error_message` is set to describe retry exhaustion
- [ ] Scan is not retried further

## 2. Admin Monitoring API

### 2.1 Stats Endpoint
- [ ] `GET /admin/scan-monitoring/stats` returns active, queued, stale scan counts
- [ ] Returns `auto_retries_24h`, `failed_scans_24h`, `completed_scans_24h`
- [ ] Returns `avg_retry_count` across retried scans
- [ ] Returns `config` with `stale_timeout_seconds` and `retry_limit`
- [ ] Requires `support_admin` role or higher

### 2.2 Stale Scans List
- [ ] `GET /admin/scan-monitoring/stale` returns stale scan details
- [ ] Each scan includes: id, user_email (via JOIN), scan_type, priority, started_at, stale_duration_seconds, retry_count, can_retry
- [ ] Limited to 100 results, ordered by started_at ASC
- [ ] Requires `support_admin` role or higher

### 2.3 Manual Retry
- [ ] `POST /admin/scan-monitoring/scans/{scan_id}/retry` resets scan to `queued`
- [ ] Requires `reason` field (1-500 characters)
- [ ] Validates scan_id as UUID
- [ ] Returns 404 for non-existent scans
- [ ] Returns 422 for invalid UUID or missing reason
- [ ] Requires `platform_admin` role or higher

### 2.4 Force Fail
- [ ] `POST /admin/scan-monitoring/scans/{scan_id}/fail` sets scan to `failed`
- [ ] Requires `reason` field (1-500 characters)
- [ ] Sets `error_message` with admin reason
- [ ] Requires `platform_admin` role or higher

## 3. Authentication & Authorization

### 3.1 Auth Enforcement
- [ ] All endpoints return 401 without valid JWT + admin session
- [ ] Read endpoints require `support_admin` role minimum
- [ ] Write endpoints require `platform_admin` role minimum
- [ ] All actions are audit logged

### 3.2 Audit Logging
- [ ] `view_stats` action logged on stats access
- [ ] `view_stale` action logged on stale list access
- [ ] `retry_scan` action logged with scan_id and reason
- [ ] `force_fail_scan` action logged with scan_id and reason

## 4. Admin Portal UI

### 4.1 Navigation
- [ ] "Scan Monitoring" appears in sidebar with refresh icon
- [ ] Only visible for `platform_admin` and `super_admin` roles
- [ ] Navigates to `/scan-monitoring`

### 4.2 Dashboard Cards
- [ ] Active Scans card (blue) shows count
- [ ] Stale Scans card (red with pulse animation when >0, green when 0)
- [ ] Auto-Retries 24h card (yellow) shows count
- [ ] Failed 24h card (red) shows count

### 4.3 Configuration Display
- [ ] Shows stale timeout value in seconds and minutes
- [ ] Shows max retry limit

### 4.4 Stale Scans Table
- [ ] Shows "No stale scans detected" when empty
- [ ] Shows scan ID (truncated), user email, type, priority, stale duration, retry count
- [ ] Retry button appears when `can_retry` is true
- [ ] Force Fail button always appears

### 4.5 Action Modal
- [ ] Opens on Retry or Force Fail button click
- [ ] Requires reason text (textarea, max 500 chars)
- [ ] Confirm button disabled when reason is empty
- [ ] Shows processing spinner during action
- [ ] Closes and refreshes data on success
- [ ] Shows error message on failure

### 4.6 Auto-Refresh
- [ ] Page auto-refreshes every 30 seconds
- [ ] Manual refresh button triggers immediate refresh
- [ ] Refresh icon animates during refresh

## 5. Database

### 5.1 Migration
- [ ] Migration 067 applies cleanly (merge of 3 heads)
- [ ] `retry_count` column exists with default 0
- [ ] `last_retry_at` column exists (nullable timestamp)
- [ ] `retry_reason` column exists (varchar 200, nullable)
- [ ] `ix_scans_status_started_at` composite index exists

## 6. Race Condition Safety

### 6.1 Concurrent Operations
- [ ] `check_stale_scans` and `poll_scan_queue` do not double-dispatch (both use SKIP LOCKED)
- [ ] Manual retry uses `FOR UPDATE` (blocking) for definitive admin response
- [ ] Auto-retry uses `SKIP LOCKED` to skip scans being manually operated on

## Related Tests

- [06-scanning.md](./06-scanning.md) — Core scanning tests
- [57-scanner-upgrade-admin.md](./57-scanner-upgrade-admin.md) — Admin panel scanner features
