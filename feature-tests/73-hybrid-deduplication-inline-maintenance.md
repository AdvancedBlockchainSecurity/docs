# Hybrid Deduplication - Inline Post-Scan Maintenance

**Priority**: P1 - High
**Last Tested**: 2026-02-23
**Scope**: Inline post-scan deduplication, weekly housekeeping, CronJob configuration, CLI interface
**API Version**: 0.29.11

---

## 1. Inline Post-Scan Maintenance

### 1.1 Phase 3 Integration in store_scan_results

- [x] `run_post_scan_maintenance` imported in `scans.py`
- [x] Called after vulnerabilities are created (not just imported)
- [x] Wrapped in try/except (failure does not break scan result storage)
- [x] Guarded by `created_vulnerability_ids` check (skipped if no vulns created)
- [x] Passes `scan_id=scan_id` and `contract_id=scan.contract_id`
- [x] Logs warning on failure (does not raise)

### 1.2 Scoped Task Execution

- [x] `generate_fuzzy_location_fingerprints` accepts `scan_id` parameter
- [x] `generate_semantic_fingerprints` accepts `scan_id` parameter
- [x] `calculate_tool_consensus_scores` accepts `contract_id` parameter
- [x] `update_orphaned_vulnerabilities` accepts `contract_id` parameter
- [x] All 4 parameters default to `None` (backwards compatible with full sweep)

### 1.3 Error Isolation (Post-Scan)

- [x] Each of 4 tasks has independent try/except
- [x] Failed task returns dict with `"error"` key
- [x] Successful tasks return normal result dicts
- [x] `db.rollback()` called on each failure
- [x] Return dict contains all 5 keys: `fuzzy_fingerprints`, `semantic_fingerprints`, `tool_consensus`, `orphan_grouping`, `elapsed_seconds`

### 1.4 Live Inline Verification

Test procedure:
```bash
# 1. Create test contract + scan in DB
kubectl exec -n api-service-local deploy/api-service -- python3 -c "..."

# 2. Submit scanner results
curl -sk -X POST https://app.0xapogee.com/api/v1/scans/{scan_id}/results \
  -H "Content-Type: application/json" -d @scan-results.json

# 3. Verify dedup fields populated
SELECT fingerprint_location_fuzzy IS NOT NULL,
       fingerprint_semantic IS NOT NULL,
       tool_consensus_score,
       deduplication_group_id IS NOT NULL
FROM vulnerabilities WHERE scan_id = '{scan_id}';
```

**Results (February 23, 2026):**

| Metric | Single Scanner (Slither) | Two Scanners (+ Aderyn) |
|--------|--------------------------|------------------------|
| Fuzzy fingerprints | 3/3 populated | 5/5 populated |
| Semantic fingerprints | 3/3 populated | 5/5 populated |
| Consensus scores | 0.0 (single scanner) | 0.6 (cross-tool detected) |
| Dedup groups | None (no duplicates) | None (distinct findings) |
| Response time | Sub-second | Sub-second |

---

## 2. Weekly Housekeeping

### 2.1 Function Structure

- [x] `run_weekly_housekeeping` defined as async
- [x] Accepts optional `db` parameter (defaults to `None`)
- [x] Delegates to `run_deduplication_maintenance` (full 18-task sweep)
- [x] `run_weekly_housekeeping_once` entry point defined
- [x] `run_post_scan_once` entry point defined (for CLI `--scan-id`)

### 2.2 CronJob Configuration

- [x] Schedule: `0 2 * * 0` (weekly, Sunday 2 AM UTC)
- [x] `activeDeadlineSeconds`: 7200 (2 hours)
- [x] `concurrencyPolicy`: Forbid
- [x] `--weekly` flag in container command
- [x] Correct Python module in command (`src.infrastructure.tasks.deduplication_maintenance`)
- [x] `runAsNonRoot: true`
- [x] `restartPolicy`: OnFailure
- [x] Image: `harbor.blocksecops.local/blocksecops/api-service:0.29.11`

---

## 3. CLI Interface

### 3.1 Argument Parsing

- [x] `--weekly` flag triggers `run_weekly_housekeeping_once()`
- [x] `--scan-id` flag accepts UUID string
- [x] `--contract-id` flag accepts UUID string
- [x] `--scan-id` requires `--contract-id` (parser.error if missing)
- [x] Both `--scan-id` and `--contract-id` triggers `run_post_scan_once()`
- [x] No flags triggers `run_maintenance_once()` (legacy full sweep)
- [x] `logging.basicConfig` configured in `__main__`

---

## 4. Automated Test Coverage

### 4.1 Structural Tests (test_deduplication_maintenance.py)

| Test Class | Tests | Status |
|------------|-------|--------|
| TestPostScanMaintenanceStructure | 7 | PASS |
| TestWeeklyHousekeepingStructure | 6 | PASS |
| TestScopedParameterSignatures | 4 (parametrized) | PASS |
| TestCLIArgparseStructure | 8 | PASS |

### 4.2 Functional Tests (test_deduplication_maintenance.py)

| Test Class | Tests | Status |
|------------|-------|--------|
| TestPostScanMaintenanceErrorIsolation | 7 (incl. parametrized x4) | PASS |
| TestWeeklyHousekeepingIntegration | 1 | PASS |

### 4.3 Phase 3 Integration Tests (test_scans_phase3.py)

| Test Class | Tests | Status |
|------------|-------|--------|
| TestPhase3PostScanIntegration | 6 | PASS |

### 4.4 CronJob Manifest Tests (test_cronjob_manifest.py)

| Test Class | Tests | Status |
|------------|-------|--------|
| TestCronJobScheduleAndCommand | 7 | PASS |

**Total: 120 tests passing, 0 failures, 0 skips**

Run command:
```bash
cd /home/pwner/Git/blocksecops-api-service
python3 -m pytest tests/unit/infrastructure/test_deduplication_maintenance.py \
  tests/unit/presentation/test_scans_phase3.py \
  tests/unit/infrastructure/test_cronjob_manifest.py -v -o "addopts="
```

---

## 5. Regression Checks

- [x] Full-sweep CronJob still works (tested via `kubectl create job --from=cronjob/...`)
- [x] Existing 18-task pipeline unaffected (scoped params default to `None`)
- [x] No database schema changes required
- [x] Version sync: pyproject.toml = kustomization.yaml newTag = cluster images = 0.29.11
- [x] Immutable tag pushed to Harbor

---

## 6. Known Limitations

1. **Inline path runs 4 of 18 tasks** — the remaining 14 (cleanup, pattern codes, canonical recalc, analytics, ML feedback) run weekly only
2. **Consensus score requires 2+ scanners** — single-scanner scans get 0.0 consensus until another scanner submits results
3. **Weekly job still slow** — full sweep takes 45+ minutes for 6,300+ vulns; this is expected and acceptable for weekly housekeeping
