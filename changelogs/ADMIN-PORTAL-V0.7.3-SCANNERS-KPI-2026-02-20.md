# Admin Portal v0.7.3 - Total Scans KPI & Per-Scanner Counts

**Component:** blocksecops-admin-portal, blocksecops-api-service
**Scope:** Add total scans KPI card and per-scanner scan counts to the admin scanners page
**Date:** February 20, 2026
**Status:** Deployed

---

## Summary

Added a "Total Scans" KPI card and per-scanner scan count column to the `/scanners` admin page. The backend aggregates scan counts per scanner by UNNESTing the `scanners_used` ARRAY column on the `scans` table.

---

## Key Changes

### Backend (api-service v0.29.2)

- Added `scans_by_scanner` dict to `SystemStatsResponse.scans` in `/admin/system/stats`
- New SQL aggregation uses `func.unnest(ScanModel.scanners_used)` with `GROUP BY` / `ORDER BY count DESC`
- Imported `literal_column` from SQLAlchemy for safe alias references
- No user input in query — fully parameterized via SQLAlchemy ORM

### Frontend (admin-portal v0.7.3)

- Added `scans_by_scanner?: Record<string, number>` to `SystemStatsResponse` type
- Added `getSystemStats()` call to `AdminScanners` page `fetchData()` via `Promise.allSettled`
- Added "Total Scans" KPI card (first card, 5-column grid) showing `systemStats.scans.total`
- Added "Total Scans" column to Scanner Registry table showing per-scanner counts
- Scanners with no recorded scans display `0`

### Tests

- **Backend:** 11 unit tests in `tests/unit/test_scans_by_scanner.py` covering aggregation logic, edge cases, ordering, and response structure
- **Frontend:** 7 vitest tests in `src/pages/__tests__/AdminScanners.test.tsx` covering KPI rendering, per-scanner counts, undefined/null graceful handling, and regression

---

## Files Modified

### blocksecops-api-service
- `src/presentation/api/v1/endpoints/admin/system.py` — Added UNNEST query and `scans_by_scanner` to response
- `tests/unit/test_scans_by_scanner.py` — New test file (11 tests)
- `pyproject.toml` — Version 0.29.0 → 0.29.2
- `k8s/overlays/local/api-service/kustomization.yaml` — newTag and version label updated

### blocksecops-admin-portal
- `src/lib/api/admin.ts` — Added `scans_by_scanner` to `SystemStatsResponse` type
- `src/pages/AdminScanners.tsx` — Added KPI card and table column
- `src/pages/__tests__/AdminScanners.test.tsx` — New test file (7 tests)
- `package.json` — Version 0.7.2 → 0.7.3
- `k8s/overlays/local/kustomization.yaml` — newTag and version label updated

---

## Security Review

- SQL query uses parameterized SQLAlchemy ORM — no user input in the UNNEST query
- `literal_column('scanner_name')` references a hardcoded alias, not user input
- Endpoint protected by `require_admin_role("support_admin")`
- Frontend renders via React JSX auto-escaping — no XSS risk
- Scanner keys are hardcoded in `NAME_TO_KEY` map

---

## Verification

1. `GET /api/v1/admin/system/stats` → `scans.scans_by_scanner` returns `{"slither": N, "aderyn": M, ...}`
2. Admin portal `/scanners` → "Total Scans" KPI card shows total count
3. Scanner Registry table → "Total Scans" column shows per-scanner counts
4. `npm run build` — no errors
5. Backend unit tests — 11/11 passing
6. Frontend vitest — 7/7 passing (80 total across all test files)

---

## Use When

- Understanding how scan counts per scanner are aggregated
- Adding new KPI cards to the admin scanners page
- Modifying the `SystemStatsResponse` schema
- Reviewing UNNEST array aggregation patterns in SQLAlchemy
