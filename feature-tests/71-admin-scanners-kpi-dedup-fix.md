# Admin Scanners KPI & Deduplication Page Fix Tests

**Priority**: P1 - Important
**Last Tested**: 2026-02-20
**Endpoints**: `GET /api/v1/admin/system/stats`, Dashboard `/deduplication`

---

## 1. Total Scans KPI Card (Admin Portal)

### 1.1 KPI Card Displays
- [ ] Navigate to admin portal `/scanners` page
- [ ] "Total Scans" KPI card is visible as the first card in the stats grid
- [ ] Card shows the correct total scan count matching `scans.total` from API
- [ ] Card shows "X this week" subtitle

### 1.2 Total Scans Count Accuracy
- [ ] `GET /api/v1/admin/system/stats` returns `scans.total` matching database count
- [ ] `scans.today` and `scans.this_week` are accurate
- [ ] Values update on page refresh (30-second auto-refresh)

---

## 2. Per-Scanner Scan Counts (Admin Portal)

### 2.1 Scanner Registry Table Column
- [ ] "Total Scans" column header is visible in the Scanner Registry table
- [ ] Each scanner row shows the correct scan count from `scans_by_scanner`
- [ ] Scanners with no scans show `0`

### 2.2 scans_by_scanner API Response
- [ ] `GET /api/v1/admin/system/stats` returns `scans.scans_by_scanner` as object
- [ ] Keys are scanner names (e.g., `slither`, `aderyn`, `semgrep`)
- [ ] Values are positive integers
- [ ] Ordered by count descending
- [ ] Scanners not in any scan's `scanners_used` array are absent from the response

### 2.3 Edge Cases
- [ ] New scanner with zero scans shows `0` in table
- [ ] Scanner name with hyphens (e.g., `sol-azy`, `cargo-fuzz-solana`) renders correctly
- [ ] API failure for `getSystemStats` does not break the page — other KPIs still render

---

## 3. Deduplication Page Filter Fix (Dashboard)

### 3.1 Default Filter Behavior
- [ ] Navigate to `https://app.0xapogee.com/deduplication`
- [ ] Min Scanner Count filter defaults to "1+ scanners"
- [ ] All deduplication groups are visible (including single-scanner groups)

### 3.2 Pattern Filter with Single-Scanner Groups
- [ ] Navigate to `/deduplication?pattern=BVD-SOLIDITY-GAS-001`
- [ ] Page shows deduplication groups (not "No deduplication groups found")
- [ ] Groups with `scanner_distribution = {'semgrep': 2}` are visible

### 3.3 Filter Interactions
- [ ] Changing filter to "2+ scanners" hides single-scanner groups
- [ ] Changing filter to "3+ scanners (high confidence)" further reduces results
- [ ] Changing filter back to "1+ scanners" shows all groups again
- [ ] URL updates with `min_scanners` param when value is not `1`
- [ ] URL does NOT include `min_scanners` param when value is `1` (default)

### 3.4 Regression
- [ ] Pattern code filter still works
- [ ] Severity filter still works
- [ ] Pagination (Load More) still works
- [ ] Stats Summary cards display when groups exist

---

## 4. Automated Test Coverage

### 4.1 Backend Tests (pytest)
- [ ] `tests/unit/test_scans_by_scanner.py` — 18 tests passing
- [ ] Tests import actual `DeduplicationGroupModel.scanner_count` property from source
- [ ] Tests cover: multiple/single/empty/None/non-dict distributions, hyphenated names, many scanners
- [ ] Tests cover: min_scanner_count filter at threshold 2 (old bug), threshold 1 (fix), empty distribution exclusion
- [ ] Tests cover: endpoint source verification (UNNEST, GROUP BY, ORDER BY, literal_column, null filter, scans_by_scanner in response)
- [ ] Tests cover: deduplication endpoint min_scanner_count parameter and post-query filter

### 4.2 Frontend Tests (vitest)
- [ ] `src/pages/__tests__/AdminScanners.test.tsx` — 7 tests passing
- [ ] Tests cover: KPI card value, weekly count, per-scanner counts, zero counts, undefined scans_by_scanner, getSystemStats called, regression KPI cards

---

## Test Notes

| Date | Tester | Result | Notes |
|------|--------|--------|-------|
| 2026-02-20 | - | DEPLOY | api-service v0.29.2, admin-portal v0.7.3, dashboard v0.46.1 deployed |
| 2026-02-20 | - | FIX | api-service v0.29.3: pytest coverage config fix, tests rewritten (11->18), malformed scanners_used data repaired |
