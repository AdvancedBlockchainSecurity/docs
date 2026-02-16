# API Service - Deduplication Multi-Level Matching Audit & Fixes

**Date:** February 15, 2026
**Component:** blocksecops-api-service
**Type:** Bug Fix / Security
**Priority:** Critical
**Status:** Complete (code changes in Git, no GitOps yet)

---

## Summary

Comprehensive audit of the deduplication pipeline revealed that the 5-level `DeduplicationMatcher` was never used by any automated code path. All three automated dedup paths (intra-scan, cross-scan, and maintenance Task 7) bypassed the matcher in favor of hardcoded single-level strategies. This audit fixes all five findings and adds 35 new regression tests.

---

## Issues Resolved

| # | Severity | Finding | Root Cause |
|---|----------|---------|------------|
| 1 | Critical | `DeduplicationMatcher` never used by automated paths | Task 7 hardcoded "location" strategy; only manual API endpoint used the matcher |
| 2 | High | IE connectivity failures during CronJob | No retry logic for transient `EmbeddingServiceError` in semantic fingerprint generation |
| 3 | Medium | Cross-scan dedup missing MEDIUM and LOW levels | Only EXACT, HIGH, SEMANTIC levels implemented; 2 of 5 levels skipped |
| 4 | Medium | Intra-scan dedup cross-type grouping | `GROUP BY fingerprint_location` without `detector_id` could group different vuln types |
| 5 | Low | 79 vulnerabilities with empty `scanner_id` | Slither parser edge case; no validation guard in scan ingest |

---

## Added

- 5-level `DeduplicationMatcher` integration into maintenance Task 7 (`update_orphaned_vulnerabilities`)
- Two-phase orphan matching: Phase 1 matches against existing groups, Phase 2 groups remaining orphans
- MEDIUM level (AST + fuzzy location, 85% confidence) in cross-scan dedup
- LOW level (pattern_code + fuzzy location, 75% confidence) in cross-scan dedup
- `detector_id` scoping in intra-scan dedup GROUP BY clause
- Retry with exponential backoff for semantic fingerprint IE calls (max 3 retries, 2s/4s delay, 30s cap)
- Scanner ID validation guard in scan ingest (prevents empty `scanner_id`)
- 35 new regression tests in `test_dedup_multilevel_matching.py`

## Fixed

- 79 Slither vulnerabilities with empty `scanner_id` updated via SQL
- Task 7 now returns `strategy_counts` dict showing which matching levels were used

## Security

- Cross-contract grouping prevented: all matching scoped by `contract_id`
- Cross-type grouping prevented: `detector_id` added to intra-scan GROUP BY
- Non-retryable errors break immediately (only `EmbeddingServiceError` retried)
- Scanner ID fallback uses first scanner in `scanners_used` array, never allows empty string

---

## Code Changes

**Files Modified:**

| File | Change |
|------|--------|
| `src/infrastructure/tasks/deduplication_maintenance.py` | Task 7 rewrite (5-level matcher), semantic fingerprint retry with backoff, `import time` |
| `src/presentation/api/v1/endpoints/scans.py` | MEDIUM/LOW cross-scan levels, detector_id in intra-scan GROUP BY, scanner_id validation guard |

**Files Created:**

| File | Description |
|------|-------------|
| `tests/unit/infrastructure/test_dedup_multilevel_matching.py` | 35 tests across 7 test classes |

**Key Changes:**

Task 7 rewrite — `update_orphaned_vulnerabilities()`:
```python
# Before: hardcoded "location" strategy
for fingerprint, count in duplicate_groups:
    # ... location-only matching

# After: 5-level DeduplicationMatcher
matcher = DeduplicationMatcher(semantic_deduplicator=semantic_dedup)
# Phase 1: match orphans against existing grouped vulnerabilities
result = matcher.match(orphan_dict, candidate_dicts)
# Phase 2: group remaining orphans against each other
```

Cross-scan MEDIUM level:
```python
# Level 3: MEDIUM — AST hash + fuzzy location (85% confidence)
if not match_found and new_vuln.fingerprint_ast and new_vuln.fingerprint_location_fuzzy:
    for candidate in existing_by_detector.get(detector, []):
        if (candidate.fingerprint_ast == new_vuln.fingerprint_ast
                and candidate.fingerprint_location_fuzzy == new_vuln.fingerprint_location_fuzzy):
            match_strategy = "medium"
            match_confidence = 0.85
```

Intra-scan detector_id scoping:
```python
# Before: GROUP BY fingerprint_location
# After:  GROUP BY detector_id, fingerprint_location
# Prevents grouping reentrancy + integer-overflow at same location
```

Semantic fingerprint retry:
```python
for attempt in range(max_retries):
    try:
        embeddings = deduplicator.embed_batch(vuln_dicts)
        break  # Success
    except EmbeddingServiceError:
        delay = min(2.0 * (2 ** attempt), 30.0)
        await asyncio.sleep(delay)
    except Exception:
        break  # Non-retryable
```

---

## Testing

### New Test Suite (35 tests)

| Test Class | Tests | Purpose |
|------------|-------|---------|
| `TestTask7UsesDeduplicationMatcher` | 7 | Verifies matcher integration, no hardcoded "location", returns strategy_counts |
| `TestCrossScanDedupLevels` | 11 | All 5 levels present, MEDIUM/LOW use correct fingerprints and strategy labels |
| `TestIntraScanDedupScoping` | 3 | detector_id in SELECT, GROUP BY, and WHERE clauses |
| `TestSemanticFingerprintRetry` | 5 | Retry loop, exponential backoff, asyncio.sleep, max delay cap, non-retryable break |
| `TestScannerIdValidation` | 2 | Empty scanner_id guard and fallback logic |
| `TestSecurityRegressions` | 5 | Cross-contract prevention, cross-type prevention, hierarchical priority |
| `TestIntraScanDedupStructure` | 2 | Structural verification of GROUP BY and security comment |

### Full Test Results

```
tests/unit/infrastructure/test_dedup_multilevel_matching.py  — 35 passed
tests/unit/domain/test_deduplication_matcher.py              — 26 passed
tests/unit/infrastructure/test_deduplication_maintenance.py   — 51 passed (21 skipped)
Full unit suite (excluding missing deps)                     — 324 passed, 22 skipped
```

Run locally:
```bash
python3 -m pytest tests/unit/infrastructure/test_dedup_multilevel_matching.py -v -o "addopts="
```

---

## Database Changes

| Change | SQL | Rows Affected |
|--------|-----|---------------|
| Fix empty scanner_id | `UPDATE vulnerabilities SET scanner_id = 'slither' WHERE scanner_id IS NULL OR scanner_id = ''` | 79 |

**Backup created:** `backups/solidity_security_pre_dedup_fix_20260215_135116.sql` (2.6 MB)

### Post-Fix Database State

| Metric | Count |
|--------|-------|
| Total vulnerabilities | 3,328 |
| Empty scanner_id | 0 |
| SolidityDefend vulnerabilities | 780 |
| Deduplication groups | 662 |
| Grouped vulnerabilities | 1,649 |
| Ungrouped vulnerabilities | 1,679 |

Note: The 1,679 ungrouped vulnerabilities will be grouped when the maintenance CronJob next runs with the updated Task 7 (5-level matching).

---

## Impact

- **False positive reduction**: 5-level matching provides more accurate grouping than location-only
- **Cross-type safety**: detector_id scoping prevents reentrancy and integer-overflow from grouping together
- **IE resilience**: Retry logic handles transient embedding service failures without losing fingerprints
- **Data integrity**: No more empty scanner_id values; validation guard prevents recurrence

---

## Deployment Notes

Code changes are in Git. **No GitOps has been run.** Deployment requires:

1. Version bump in `pyproject.toml` and `kustomization.yaml`
2. Docker build and push to Harbor
3. `kubectl apply -k` and rollout restart

---

## Related Documentation

- [Deduplication Pipeline](../pipelines/deduplication-pipeline.md)
- [Deduplication Workflow](../workflows/deduplication-workflow.md)
- [Feature Test #63: Dedup Multi-Level Matching](../feature-tests/63-dedup-multilevel-matching-audit.md)
- [Previous Dedup Pipeline Fixes](API-SERVICE-V0.28.11-V0.28.17-DEDUP-PIPELINE-FIXES-2026-02-09.md)
