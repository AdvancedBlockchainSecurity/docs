# Deduplication Pipeline Error Isolation

**Priority**: P1 - High
**Last Tested**: 2026-02-23
**Scope**: All 18 maintenance tasks error isolation, rollback behavior, pipeline resilience, inline post-scan error isolation
**API Version**: 0.29.11

---

## 1. Pipeline Completes Successfully

### 1.1 All Tasks Run
- [ ] Manual CronJob trigger completes without error
- [ ] Job logs show all 18 "Task N/18:" entries
- [ ] Return dict contains all 18 result keys
- [ ] Status field is "success"

### 1.2 Task Result Keys Present
- [ ] `cleanup` — cleanup_invalid_groups
- [ ] `fingerprints` — generate_missing_fingerprints
- [ ] `fuzzy_location_fingerprints` — generate_fuzzy_location_fingerprints
- [ ] `ast_fingerprints` — generate_ast_fingerprints
- [ ] `semantic_fingerprints` — generate_semantic_fingerprints
- [ ] `tool_consensus` — calculate_tool_consensus_scores
- [ ] `orphaned_vulnerabilities` — update_orphaned_vulnerabilities
- [ ] `pattern_codes` — update_pattern_codes
- [ ] `canonical_findings` — recalculate_canonical_findings
- [ ] `group_statistics` — update_group_statistics
- [ ] `fp_confidence_adjustment` — integrate_fp_scores_into_confidence
- [ ] `scanner_quality_metrics` — update_scanner_quality_metrics
- [ ] `pattern_fp_rates` — update_pattern_fp_rates
- [ ] `fp_training_check` — check_fp_training_trigger
- [ ] `dynamic_priorities` — refresh_dynamic_priorities
- [ ] `weak_labels` — generate_weak_labels_job
- [ ] `active_learning_queue` — populate_active_learning_queue_job
- [ ] `active_learning_cleanup` — cleanup_active_learning_queue_job

---

## 2. Error Isolation

### 2.1 Single Task Failure
- [ ] If one task throws an exception, subsequent tasks still execute
- [ ] Failed task returns dict with `"error"` key containing the exception message
- [ ] Successful tasks return their normal statistics dicts
- [ ] Overall pipeline status is still "success"

### 2.2 Database Rollback
- [ ] Each failed task calls `await db.rollback()` before the next task starts
- [ ] This prevents SQLAlchemy async session poisoning from a failed query
- [ ] Next task can use the session without `InvalidRequestError`

### 2.3 Multiple Simultaneous Failures
- [ ] If 3+ tasks fail, remaining tasks still execute
- [ ] Each failed task has independent error dict
- [ ] Pipeline completes with partial results

---

## 3. Structural Invariants (Automated Tests)

These are verified by `tests/unit/infrastructure/test_deduplication_maintenance.py`:

### 3.1 TestOrchestratorStructure
- [ ] All 18 task markers (`# Task N:`) present in order 1-18
- [ ] Every task marker has a `try:` block within 5 lines
- [ ] Every task's `except` block contains `db.rollback()`
- [ ] Return dict contains all 18 expected keys

### 3.2 TestTaskFunctionsExist
- [ ] All 18 task functions defined as `async def func_name(db...)`

### 3.3 TestConstants
- [ ] `EMPTY_FINGERPRINT_HASH` equals SHA-256 of empty string
- [ ] `DEFAULT_SCANNER_PRIORITY` derived from `_SCANNER_CONFIGS.keys()`
- [ ] Consensus score thresholds: 0.6, 0.8, 0.95

---

## 4. Manual Verification

### 4.1 Trigger Manual Job
```bash
kubectl create job --from=cronjob/deduplication-maintenance deduplication-maintenance-manual -n api-service-local
```

### 4.2 Check Logs
```bash
kubectl logs -n api-service-local job/deduplication-maintenance-manual --tail=50
```

### 4.3 Run Test Suite Locally
```bash
cd /home/pwner/Git/blocksecops-api-service
python3 -m pytest tests/unit/infrastructure/test_deduplication_maintenance.py -v \
  --override-ini="addopts=-v --tb=short -ra"
```

Expected: 120 passed, 0 skipped

---

## 5. Inline Post-Scan Error Isolation (v0.29.11)

### 5.1 Post-Scan Maintenance Error Isolation

- [x] `run_post_scan_maintenance` wraps each of 4 tasks in independent try/except
- [x] Each failed task calls `await db.rollback()`
- [x] Return dict contains 5 keys: `fuzzy_fingerprints`, `semantic_fingerprints`, `tool_consensus`, `orphan_grouping`, `elapsed_seconds`
- [x] Single task failure does not affect other tasks (parametrized x4)
- [x] All 4 failures still returns dict (no exception raised)

### 5.2 Phase 3 Integration Error Isolation

- [x] Phase 3 call in `store_scan_results()` wrapped in try/except
- [x] Failure logs warning but does not break scan result storage
- [x] Guarded by `created_vulnerability_ids` check (skipped if no vulns)

### 5.3 Automated Tests

| Test Class | Tests | File |
|------------|-------|------|
| TestPostScanMaintenanceErrorIsolation | 7 | test_deduplication_maintenance.py |
| TestPhase3PostScanIntegration | 6 | test_scans_phase3.py |

---

## 6. Regression Prevention

The test suite enforces that:
1. **New tasks must have try-catch** — adding `# Task 19:` without try/except will fail `test_every_task_has_try_block`
2. **New tasks must have rollback** — missing `db.rollback()` will fail `test_every_task_has_rollback`
3. **Task count must be updated** — adding tasks without updating the count will fail `test_all_18_tasks_present`
4. **Return dict must be complete** — missing result keys will fail `test_return_dict_has_all_task_keys`
