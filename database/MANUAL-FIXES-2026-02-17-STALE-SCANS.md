# Database Manual Fix: Stale Contract Status Recovery

**Date:** February 17, 2026
**Issue:** 10 contracts stuck in "scanning" status with no active scans
**Affected Table:** contracts
**Related:** Scanner Audit Fix #3

---

## Issue

Contracts get status "scanning" when a scan is created (`scans.py:1512`) but the status is only reset to "scanned" when `store_scan_results` is called (`scans.py:2141`). If scanner jobs complete without posting results (container crash, network error, callback failure), contracts stay stuck in "scanning" forever.

---

## One-Time Data Fix

```sql
-- Fix contracts stuck in "scanning" with no active scans
-- Run this AFTER taking a database backup

-- 1. Check how many contracts are stuck
SELECT id, name, status, updated_at
FROM contracts
WHERE status = 'scanning'
AND id NOT IN (
    SELECT DISTINCT contract_id FROM scans
    WHERE status IN ('queued', 'running')
);

-- 2. Apply fix
UPDATE contracts SET status = 'scanned'
WHERE status = 'scanning'
AND id NOT IN (
    SELECT DISTINCT contract_id FROM scans
    WHERE status IN ('queued', 'running')
);

-- 3. Verify fix
SELECT count(*) as still_stuck FROM contracts
WHERE status = 'scanning'
AND id NOT IN (
    SELECT DISTINCT contract_id FROM scans
    WHERE status IN ('queued', 'running')
);
-- Expected: 0
```

---

## Prevention

A new maintenance endpoint `POST /maintenance/recover-stale-scans` was added in api-service v0.28.38. It automatically recovers scans stuck in `queued`/`running` for >1 hour by marking them `failed` and resetting the contract status.

This endpoint should be called by the existing deduplication maintenance CronJob (runs every 6 hours).

---

## Verification

```sql
-- Count contracts by status
SELECT status, count(*) FROM contracts GROUP BY status ORDER BY count(*) DESC;
```
