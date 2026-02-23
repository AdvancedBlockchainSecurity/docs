# API Service v0.29.11 - Hybrid Deduplication Architecture

**Component:** blocksecops-api-service
**Scope:** Replace full-sweep-only dedup maintenance with hybrid inline + weekly housekeeping
**Date:** February 23, 2026
**Status:** Deployed

---

## Summary

Introduced a hybrid deduplication architecture that runs 4 critical maintenance tasks inline during scan result ingestion (scoped to the current scan/contract) while retaining the weekly CronJob for full-sweep housekeeping. This eliminates the delay between scan completion and dedup processing — findings now have fingerprints, consensus scores, and group assignments before the API response returns.

---

## Problem

The previous architecture relied entirely on a daily/weekly CronJob (`run_deduplication_maintenance`) to process all 18 maintenance tasks across the entire database. This caused:

1. **Stale data:** Newly scanned vulnerabilities had no fingerprints or dedup groups until the next CronJob run
2. **Slow processing:** Full-sweep over 6,300+ vulnerabilities took 45+ minutes
3. **Poor UX:** Users saw unfingerprinted, ungrouped findings immediately after a scan

---

## Solution: Hybrid Architecture

### Inline Post-Scan Path (New)

**Function:** `run_post_scan_maintenance(db, scan_id, contract_id)`

Called from `store_scan_results()` after vulnerabilities are created. Runs 4 scoped tasks:

| Task | Scoped By | Purpose |
|------|-----------|---------|
| `generate_fuzzy_location_fingerprints(db, scan_id=scan_id)` | scan_id | Fuzzy location fingerprints for new vulns |
| `generate_semantic_fingerprints(db, scan_id=scan_id)` | scan_id | Semantic embeddings for new vulns |
| `calculate_tool_consensus_scores(db, contract_id=contract_id)` | contract_id | Cross-tool agreement scores |
| `update_orphaned_vulnerabilities(db, contract_id=contract_id)` | contract_id | Assign ungrouped vulns to dedup groups |

**Performance:** Completes within the HTTP response time (sub-second for typical scans).

**Error isolation:** Each task wrapped in try/except with `db.rollback()`. A failure in one task does not affect others or the scan result response.

### Weekly Housekeeping (Updated)

**Function:** `run_weekly_housekeeping(db=None)`

**Schedule:** Weekly (Sunday 2 AM UTC) — changed from daily

Delegates to the existing `run_deduplication_maintenance()` full-sweep (all 18 tasks) for:
- Catching any vulns missed by inline processing
- Running analytics tasks (scanner quality, pattern FP rates, ML feedback)
- Cleanup of invalid groups, stale queue items

**CronJob changes:**
- Schedule: `0 2 * * *` → `0 2 * * 0` (daily → weekly)
- `activeDeadlineSeconds`: 3600 → 7200 (1h → 2h, accommodates full sweep)
- Added `--weekly` CLI flag

---

## Files Changed

| File | Change |
|------|--------|
| `src/infrastructure/tasks/deduplication_maintenance.py` | Added `run_post_scan_maintenance()`, `run_weekly_housekeeping()`, CLI `--weekly`/`--scan-id`/`--contract-id` flags, scoped `scan_id`/`contract_id` params on 4 functions |
| `src/presentation/api/v1/endpoints/scans.py` | Phase 3 integration: calls `run_post_scan_maintenance()` after vulns created |
| `k8s/base/api-service/cronjob-deduplication.yaml` | Weekly schedule, 2h deadline, `--weekly` flag |
| `pyproject.toml` | Version bump 0.29.10 → 0.29.11 |
| `k8s/overlays/local/api-service/kustomization.yaml` | newTag + version label → 0.29.11 |

---

## Scoped Query Parameters

Four existing functions gained optional scoped parameters (defaulting to `None` for backwards compatibility with full-sweep):

| Function | New Parameter | Effect When Set |
|----------|---------------|-----------------|
| `generate_fuzzy_location_fingerprints` | `scan_id` | Filters to vulns from this scan only |
| `generate_semantic_fingerprints` | `scan_id` | Filters to vulns from this scan only |
| `calculate_tool_consensus_scores` | `contract_id` | Filters to vulns from this contract only |
| `update_orphaned_vulnerabilities` | `contract_id` | Filters to vulns from this contract only |

When `None` (weekly housekeeping), these functions process all eligible records as before.

---

## CLI Interface

```bash
# Weekly housekeeping (from CronJob)
python -m src.infrastructure.tasks.deduplication_maintenance --weekly

# Post-scan (for manual testing)
python -m src.infrastructure.tasks.deduplication_maintenance --scan-id UUID --contract-id UUID

# Full sweep (default, legacy)
python -m src.infrastructure.tasks.deduplication_maintenance
```

---

## Test Coverage

### Unit Tests (120 passing)

| Test Class | File | Tests | Type |
|------------|------|-------|------|
| TestPostScanMaintenanceStructure | test_deduplication_maintenance.py | 7 | Structural |
| TestWeeklyHousekeepingStructure | test_deduplication_maintenance.py | 6 | Structural |
| TestScopedParameterSignatures | test_deduplication_maintenance.py | 4 | Structural (parametrized) |
| TestCLIArgparseStructure | test_deduplication_maintenance.py | 8 | Structural |
| TestPostScanMaintenanceErrorIsolation | test_deduplication_maintenance.py | 7 | Functional (AsyncMock) |
| TestWeeklyHousekeepingIntegration | test_deduplication_maintenance.py | 1 | Functional (AsyncMock) |
| TestPhase3PostScanIntegration | test_scans_phase3.py | 6 | Structural |
| TestCronJobScheduleAndCommand | test_cronjob_manifest.py | 7 | YAML validation |

### Live Cluster Verification

| Test | Result |
|------|--------|
| CronJob starts with `--weekly` flag | Pass |
| CronJob uses v0.29.11 image | Pass |
| Inline: Slither results (3 vulns) → fingerprints populated | Pass |
| Inline: Aderyn results (2 vulns) → consensus scores updated | Pass |
| Cross-tool consensus: 0.0 → 0.6 after second scanner | Pass |
| Orphan grouping: no false duplicates | Pass |
| Sub-second inline processing | Pass |

---

## Database Impact

- **No schema changes** — uses existing columns (`fingerprint_location_fuzzy`, `fingerprint_semantic`, `tool_consensus_score`, `deduplication_group_id`)
- **No migrations required**
- Query scoping uses existing indexes on `scan_id` and `contract_id`

---

## Rollback Plan

1. Revert `scans.py` Phase 3 block (remove `run_post_scan_maintenance` call)
2. Revert CronJob to daily schedule (`0 2 * * *`) and remove `--weekly` flag
3. Rebuild and deploy previous image version (0.29.10)

The weekly CronJob full-sweep will continue to process all records as before — no data loss from rollback.

---

## Related Documentation

- [Deduplication Pipeline](../pipelines/deduplication-pipeline.md)
- [Deduplication Workflow](../workflows/deduplication-workflow.md)
- [Feature Test: Hybrid Deduplication](../feature-tests/73-hybrid-deduplication-inline-maintenance.md)
- [Feature Test: Error Isolation](../feature-tests/61-dedup-pipeline-error-isolation.md)
- [Docker Image Versioning](../standards/docker-image-versioning.md) — service versions table
