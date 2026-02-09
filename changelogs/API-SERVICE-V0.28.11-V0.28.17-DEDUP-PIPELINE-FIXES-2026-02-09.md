# API Service v0.28.11-v0.28.17 - Deduplication Pipeline Fixes

**Date:** February 9, 2026
**Component:** blocksecops-api-service
**Type:** Bug Fix / Test Coverage
**Priority:** Critical
**Status:** Complete

---

## Summary

Comprehensive audit and fix of the deduplication maintenance pipeline (18-task orchestrator). Found and fixed missing error isolation on tasks 12-18, added structural regression test suite, and corrected scanner count documentation.

---

## Changes by Version

### v0.28.11-v0.28.15 — Initial Pipeline Bugs

**3 bugs fixed:**

1. **CronJob secret key mismatch** — `cronjob-deduplication.yaml` referenced `database-url` but the ExternalSecret stored it as `DATABASE_URL`. Fixed to match.

2. **Weak label enum mismatch** — `generate_weak_labels_job()` used `wont_fix` status but the DB enum defines `won't_fix` (with apostrophe). Fixed to use correct enum value.

3. **Active learning date arithmetic** — `cleanup_active_learning_queue_job()` used `datetime.now()` (naive) in comparison with timezone-aware DB timestamps. Fixed to use `datetime.now(timezone.utc)`.

### v0.28.16 — Tasks 12-15 Error Isolation

**Bug:** Tasks 12-15 (Phase 3: Analytics & Quality) were added January 27 without orchestrator-level try-catch blocks. A failure in any of these tasks would kill all subsequent tasks (13-18).

**Fix:** Wrapped tasks 12-15 in individual try/except blocks with `await db.rollback()` and fallback error dicts, matching the pattern used by tasks 1-11.

### v0.28.17 — Tasks 16-18 Error Isolation + Test Suite

**Bug:** Tasks 16-18 (Phase 4: ML Training Feedback Loop) were added January 30 without orchestrator-level try-catch blocks. A failure in any of these tasks would kill subsequent tasks.

**Fix:** Wrapped tasks 16-18 in individual try/except blocks with `await db.rollback()` and fallback error dicts.

**Scanner count comment fix:** Updated `scanners.py` comments from "13 operational security scanners" to "15 operational security scanners" (Wake and Medusa were added but comments not updated).

**Test suite added:** New file `tests/unit/infrastructure/test_deduplication_maintenance.py` (405 lines) with 4 test classes enforcing structural invariants:

| Test Class | Tests | Requires asyncpg | Purpose |
|------------|-------|-------------------|---------|
| TestOrchestratorStructure | 4 | No | Verifies all 18 task markers, try-blocks, rollbacks, return dict keys |
| TestTaskFunctionsExist | 18 | No | Verifies all 18 async functions defined with db parameter |
| TestConstants | 3 | No | Verifies EMPTY_FINGERPRINT_HASH, scanner priority derivation, consensus thresholds |
| TestErrorIsolation | 21 | Yes | Mocks tasks and verifies failure isolation, rollback calls, multi-failure resilience |

**Key design decision:** Structural tests read the source file directly with `open()` and parse with regex — no module import needed. This avoids triggering the asyncpg import chain, allowing the tests to run locally without database drivers.

---

## Root Cause Analysis

The deduplication pipeline was built incrementally:

| Date | Tasks Added | Error Isolation |
|------|-------------|----------------|
| January 16 | Tasks 1-11 (original) | Proper try-catch |
| January 27 | Tasks 12-15 (Phase 3) | **Missing** — fixed in v0.28.16 |
| January 30 | Tasks 16-18 (Phase 4) | **Missing** — fixed in v0.28.17 |

**Root cause:** Zero test coverage on the orchestrator function. Individual services (DeduplicationMatcher, ScannerQualityTracker, etc.) had tests, but the orchestrator and all 18 task functions had none. No structural test verified the error isolation invariant when new tasks were added.

**Prevention:** The new test suite will fail if any future task is added without a try-catch + rollback block.

---

## Files Changed

| File | Change |
|------|--------|
| `src/infrastructure/tasks/deduplication_maintenance.py` | Tasks 12-18 wrapped in try/except with rollback |
| `src/infrastructure/scanner_config/scanners.py` | Comment: "13" → "15" scanners |
| `src/infrastructure/database/models.py` | Column additions for pipeline support |
| `src/ml/weak_label_generator.py` | `wont_fix` → `won't_fix` enum fix |
| `k8s/base/api-service/cronjob-deduplication.yaml` | Secret key fix |
| `k8s/overlays/local/api-service/kustomization.yaml` | newTag: "0.28.17" |
| `k8s/overlays/local/api-service/scanner-versions-configmap.yaml` | Scanner metadata updates |
| `pyproject.toml` | version: "0.28.17" |
| `tests/unit/infrastructure/test_deduplication_maintenance.py` | **New** — 46 tests (25 run locally, 21 require asyncpg) |

---

## Verification

1. All 18 tasks execute independently — verified via live CronJob execution
2. Test suite passes: 25 passed, 21 skipped (asyncpg not installed locally)
3. Built, pushed to Harbor, deployed, verified with manual CronJob trigger
4. Job completed successfully with all 18 task results returned

---

## Related Documentation

- [Deduplication Pipeline](../pipelines/deduplication-pipeline.md)
- [Deduplication Workflow](../workflows/deduplication-workflow.md)
- [Docker Image Versioning](../standards/docker-image-versioning.md)
