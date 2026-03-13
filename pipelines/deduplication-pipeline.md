# Deduplication Maintenance Pipeline

**Last Updated:** March 13, 2026
**API Version:** 0.29.82

Hybrid deduplication system with three execution paths: Celery worker dedup (3 phases dispatched from API pod), post-scan maintenance (4 scoped tasks in worker), and weekly housekeeping (full 18-task sweep via CronJob).

## Overview

```
                                                                    Database
API Pod                  Celery Worker Pod                          ────────
────────                 ─────────────────
                         dedup_task.py + deduplication_maintenance.py

PATH 1: CELERY WORKER DEDUP (per scan, v0.29.13+)
store_scan_results()     run_dedup_task() [from Redis queue]        vulnerabilities
  └─ task.delay() ───►     Phase 1: intra-scan dedup                deduplication_groups
     (non-blocking)        Phase 2: cross-scan dedup
                           Phase 3: post-scan maintenance
                             • fuzzy fingerprints (scan-scoped)
                             • semantic fingerprints (scan-scoped)
                             • tool consensus (contract-scoped)
                             • orphan grouping (contract-scoped)

PATH 2: WEEKLY HOUSEKEEPING (CronJob, separate pod)
CronJob (Sun 2 AM UTC) → run_weekly_housekeeping()                 vulnerabilities
                           Phase 1: Cleanup & Fingerprints          deduplication_groups
                           Phase 2: Grouping & Mapping              pattern_tool_mappings
                           Phase 3: Analytics & Quality             scanner_quality_metrics
                           Phase 4: ML Training Feedback            active_learning_queue
```

## Trigger

### Celery Worker Dedup (Automatic, v0.29.13+)

Triggered automatically by `store_scan_results()` in `scans.py` after vulnerabilities are created. Dispatches a Celery task to an isolated worker pod via Redis:

```python
# In store_scan_results() — non-blocking dispatch
if created_vulnerability_ids:
    from src.infrastructure.tasks.dedup_task import run_dedup_task
    run_dedup_task.delay(
        scan_id=str(scan_id),
        contract_id=str(scan.contract_id),
        vulnerability_ids=[str(v) for v in created_vulnerability_ids],
    )
```

The worker runs all 3 dedup phases (intra-scan, cross-scan, post-scan maintenance) in its own process with its own DB connection pool. API pod is never blocked.

**Celery configuration:**
- Broker: `redis://redis-master.redis-local.svc.cluster.local:6379/1`
- Result backend: `redis://redis-master.redis-local.svc.cluster.local:6379/2`
- Queue: `dedup` (dedicated)
- Concurrency: 3 workers
- Retry: 2x with 30s backoff
- Soft time limit: 5 min, hard kill: 10 min

### Weekly Housekeeping (CronJob)

- **Kubernetes CronJob**: Runs weekly Sunday at 2 AM UTC (`k8s/base/api-service/cronjob-deduplication.yaml`)
- **Manual**: `kubectl create job --from=cronjob/deduplication-maintenance deduplication-maintenance-manual -n api-service-local`

### CLI

```bash
# Weekly housekeeping (used by CronJob)
python -m src.infrastructure.tasks.deduplication_maintenance --weekly

# Post-scan for specific scan (manual testing)
python -m src.infrastructure.tasks.deduplication_maintenance --scan-id UUID --contract-id UUID

# Full sweep (legacy default)
python -m src.infrastructure.tasks.deduplication_maintenance
```

## Inline Post-Scan Tasks (4 Tasks)

| # | Task | Function | Scoped By | Description |
|---|------|----------|-----------|-------------|
| 1 | Fuzzy fingerprints | `generate_fuzzy_location_fingerprints(db, scan_id=)` | scan_id | Create `fingerprint_location_fuzzy` for new vulns |
| 2 | Semantic fingerprints | `generate_semantic_fingerprints(db, scan_id=)` | scan_id | Create `fingerprint_semantic` via intelligence-engine |
| 3 | Tool consensus | `calculate_tool_consensus_scores(db, contract_id=)` | contract_id | Update consensus scores for contract's vulns |
| 4 | Orphan grouping | `update_orphaned_vulnerabilities(db, contract_id=)` | contract_id | Assign ungrouped vulns to dedup groups |

**Performance:** Completes within the HTTP response time (sub-second for typical scans).

**Error isolation:** Each task has independent try/except with `db.rollback()`. Failures do not affect the scan result response.

## Weekly Housekeeping Tasks (18 Total)

The weekly CronJob runs all 18 tasks as a full sweep across the entire database.

### Phase 1: Cleanup & Fingerprint Generation (Tasks 1-6)

| # | Task | Function | Description |
|---|------|----------|-------------|
| 1 | Cleanup invalid groups | `cleanup_invalid_groups()` | Remove cross-type, cross-contract, single-member, and empty groups |
| 2 | Generate missing fingerprints | `generate_missing_fingerprints()` | Create `fingerprint_code` for vulnerabilities with code snippets but no fingerprint |
| 3 | Generate fuzzy location fingerprints | `generate_fuzzy_location_fingerprints()` | Create `fingerprint_location_fuzzy` for HIGH confidence matching |
| 4 | Generate AST fingerprints | `generate_ast_fingerprints()` | Create `fingerprint_ast` structural hashes for MEDIUM confidence matching |
| 5 | Generate semantic fingerprints | `generate_semantic_fingerprints()` | Create `fingerprint_semantic` via intelligence-engine embeddings |
| 6 | Calculate tool consensus scores | `calculate_tool_consensus_scores()` | Update consensus scores based on multi-scanner agreement |

### Phase 2: Grouping & Mapping (Tasks 7-11)

| # | Task | Function | Description |
|---|------|----------|-------------|
| 7 | Update orphaned vulnerabilities | `update_orphaned_vulnerabilities()` | Assign ungrouped vulnerabilities to existing or new deduplication groups using 5-level `DeduplicationMatcher` (EXACT→HIGH→MEDIUM→LOW→SEMANTIC) |
| 8 | Update pattern codes | `update_pattern_codes()` | Apply `pattern_tool_mappings` to assign `pattern_code` where missing |
| 9 | Recalculate canonical findings | `recalculate_canonical_findings()` | Select best representative per group using dynamic scanner priority |
| 10 | Update group statistics | `update_group_statistics()` | Refresh finding_count, scanner_count, first_seen, last_seen per group |
| 11 | Integrate FP scores into confidence | `integrate_fp_scores_into_confidence()` | Adjust group confidence based on false positive rates; flag low-confidence groups |

### Phase 3: Analytics & Quality (Tasks 12-15)

| # | Task | Function | Description |
|---|------|----------|-------------|
| 12 | Update scanner quality metrics | `update_scanner_quality_metrics()` | Recalculate quality scores per scanner via `ScannerQualityTracker` |
| 13 | Update pattern FP rates | `update_pattern_fp_rates()` | Update false positive rates per pattern via `PatternFPRateAggregator` |
| 14 | Check FP training trigger | `check_fp_training_trigger()` | Check if sufficient labeled data exists to trigger model retraining |
| 15 | Refresh dynamic priorities | `refresh_dynamic_priorities()` | Refresh scanner priority rankings from `DynamicScannerPriority` |

### Phase 4: ML Training Feedback Loop (Tasks 16-18)

| # | Task | Function | Description |
|---|------|----------|-------------|
| 16 | Generate weak labels | `generate_weak_labels_job()` | Derive training labels from vulnerability status (fixed→real, false_positive→fp) |
| 17 | Populate active learning queue | `populate_active_learning_queue_job()` | Add high-uncertainty vulnerabilities to the active learning queue for human review |
| 18 | Cleanup active learning queue | `cleanup_active_learning_queue_job()` | Remove stale items (shown but not labeled, skipped) older than 30 days |

## 5-Level Matching Strategy

Deduplication uses a hierarchical matching strategy with decreasing confidence:

| Level | Confidence | Matching Criteria |
|-------|-----------|-------------------|
| EXACT | 99% | `fingerprint_code` + `fingerprint_location` |
| HIGH | 95% | `fingerprint_code` + `fingerprint_location_fuzzy` |
| MEDIUM | 85% | `fingerprint_ast` + `fingerprint_location_fuzzy` |
| LOW | 75% | `pattern_code` + `fingerprint_location_fuzzy` |
| SEMANTIC | 80%+ | Embedding similarity via intelligence-engine |

All matching is scoped by contract and detector type to prevent cross-type grouping.

## Scanner Priority

Canonical finding selection uses dynamic priorities (from quality metrics) with static fallbacks. Static priorities are derived from the scanner registry order in `src/infrastructure/scanner_config/scanners.py`:

| Scanner | Default Priority | Language | Notes |
|---------|-----------------|----------|-------|
| slither | 1 | Solidity | Highest priority |
| aderyn | 2 | Solidity | |
| semgrep | 3 | Solidity | |
| solhint | 4 | Solidity | |
| halmos | 5 | Solidity | Formal verification |
| echidna | 6 | Solidity | Fuzzing |
| wake | 7 | Solidity | |
| medusa | 8 | Solidity | Fuzzing |
| soliditydefend | 9 | Solidity | |
| vyper | 10 | Vyper | |
| moccasin | 11 | Vyper | |
| sol-azy | 12 | Solana | |
| sec3-xray | 13 | Solana | |
| trident | 14 | Solana | Fuzzing |
| cargo-fuzz-solana | 15 | Solana | Fuzzing |

Lower number = higher priority for canonical selection. Dynamic priorities override static defaults when sufficient quality data exists (10+ labeled findings per scanner).

## Quality Metrics Formula

Scanner quality score used for dynamic priority:

```
quality = confirmation_rate * 0.4 + (1 - fp_rate) * 0.4 + user_preference * 0.2
```

Priority mapping: quality 1.0 → priority 1, quality 0.0 → priority 20.

## Key Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `EMPTY_FINGERPRINT_HASH` | `e3b0c44298fc...` | SHA-256 of empty string; marks fingerprints that need regeneration |
| Batch size (fingerprints) | 500-1000 | Vulnerabilities processed per batch (varies by task) |
| Batch size (AST) | 500 | AST fingerprint generation |
| Batch size (semantic) | 100 (sub-batches of 20) | Semantic fingerprint generation (embedding API limits) |
| Batch size (detector_ids) | 1000 | Detector ID backfill |
| Scanner quality min samples | 10 | Minimum labeled findings before quality calculation |
| Pattern FP threshold | 30% | FP rate above which patterns are flagged for review |
| Active learning max age | 30 days | Stale queue items removed after this period |

## Files

| File | Role |
|------|------|
| `blocksecops-api-service/src/infrastructure/tasks/deduplication_maintenance.py` | All 18 maintenance task functions + orchestrator |
| `blocksecops-api-service/src/domain/services/intelligence_service.py` | `VulnerabilityFingerprinter` for fingerprint generation |
| `blocksecops-api-service/src/domain/services/deduplication_matcher.py` | `DeduplicationMatcher` for 5-level grouping |
| `blocksecops-api-service/src/domain/services/dynamic_scanner_priority.py` | `DynamicScannerPriority` — cached priority calculation |
| `blocksecops-api-service/src/domain/services/scanner_quality_tracker.py` | `ScannerQualityTracker` — quality metric recalculation |
| `blocksecops-api-service/src/domain/services/pattern_fp_aggregator.py` | `PatternFPRateAggregator` — pattern-level FP rate aggregation |
| `blocksecops-api-service/src/ml/weak_label_generator.py` | Weak label generation from vulnerability status |
| `blocksecops-api-service/src/ml/active_learning.py` | Active learning queue management |
| `blocksecops-api-service/k8s/base/api-service/cronjob-deduplication.yaml` | Kubernetes CronJob definition |
| `blocksecops-api-service/src/infrastructure/celery_app.py` | Celery app instance with queue/concurrency config (v0.29.13+) |
| `blocksecops-api-service/src/infrastructure/tasks/dedup_task.py` | Celery task wrapping async dedup phases (v0.29.13+) |
| `blocksecops-api-service/k8s/base/api-service/deployment-celery-worker.yaml` | Celery worker k8s deployment (v0.29.13+) |
| `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py` | Dispatches `run_dedup_task.delay()` to Celery worker |
| `blocksecops-api-service/tests/unit/infrastructure/test_deduplication_maintenance.py` | Structural + functional regression tests (120 tests) |
| `blocksecops-api-service/tests/unit/presentation/test_scans_phase3.py` | Celery dispatch + dedup_task structural tests |
| `blocksecops-api-service/tests/unit/infrastructure/test_cronjob_manifest.py` | CronJob YAML validation tests |
| `blocksecops-api-service/tests/unit/infrastructure/test_dedup_data_model.py` | Data model functional tests (26 tests) |
| `blocksecops-api-service/tests/unit/infrastructure/test_dedup_pipeline_regression.py` | Pipeline regression tests (5 tests) |

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/deduplication/groups` | Paginated list with filtering (severity, pattern, scanner count) |
| GET | `/deduplication/groups/{id}` | Detail view with all member findings |
| GET | `/deduplication/stats` | Overall deduplication statistics |
| POST | `/deduplication/groups/merge` | Merge two groups |
| DELETE | `/deduplication/findings/{id}/ungroup` | Remove finding from group |
| PATCH | `/deduplication/groups/{id}/canonical` | Set canonical finding |
| POST | `/deduplication/vulnerabilities/{id}/match` | Manual 5-level matching trigger |
| POST | `/deduplication/maintenance/backfill-detector-ids` | Backfill missing detector IDs |
| POST | `/deduplication/maintenance/regenerate-empty-fingerprints` | Regenerate empty fingerprints |
| POST | `/deduplication/maintenance/run-full-backfill` | Run complete backfill process |

## Error Handling

Each of the 18 maintenance tasks runs independently with its own try-catch block and `await db.rollback()` on failure. A failure in one task does not prevent others from running. Failed tasks return an error dict with `"error"` key; successful tasks return statistics for monitoring.

**Graceful degradation:**
- Embedding service timeout → semantic fingerprints retried with exponential backoff (max 3 retries, 2s/4s delay, 30s cap), then skipped
- Intelligence engine unavailable → consensus scores deferred; Task 7 uses fingerprint-only matching (EXACT→HIGH→MEDIUM→LOW) without SEMANTIC level
- ML model missing/unsigned → training trigger uses dev fallback key
- Read-only filesystem → ML models volume mounted as writable emptyDir
- Failed DB query → transaction rolled back, next task starts with clean session
- ML label secondary operations → use `db.begin_nested()` savepoints to prevent session corruption on partial failures (ownership verified before save)

## Test Suite

### Orchestrator Structural Tests (`test_deduplication_maintenance.py`)

Structural regression tests enforce invariants on the orchestrator. These tests parse the source file directly (no module import needed) and will fail if a new task is added without proper error isolation.

| Test Class | Tests | Purpose |
|------------|-------|---------|
| TestOrchestratorStructure | 7 | All 18 markers present, each has try-block + rollback, return dict complete |
| TestTaskFunctionsExist | 2 | All 18 async functions defined with `db` parameter |
| TestConstants | 3 | EMPTY_FINGERPRINT_HASH, scanner priority derivation, consensus thresholds |
| TestErrorIsolation | 4 | Mock-based failure isolation and rollback verification (requires asyncpg) |

### Hybrid Architecture Tests (`test_deduplication_maintenance.py`) [NEW v0.29.11]

| Test Class | Tests | Purpose |
|------------|-------|---------|
| TestPostScanMaintenanceStructure | 7 | Function signature, 4 subtask calls, try/except, return dict keys |
| TestWeeklyHousekeepingStructure | 6 | Delegation to full sweep, CLI entry points |
| TestScopedParameterSignatures | 4 | Parametrized: each function accepts scoped param with `= None` default |
| TestCLIArgparseStructure | 8 | `--weekly`, `--scan-id`, `--contract-id` flags, mutual requirements |
| TestPostScanMaintenanceErrorIsolation | 7 | AsyncMock: error isolation, rollback, partial failures |
| TestWeeklyHousekeepingIntegration | 1 | Delegation to `run_deduplication_maintenance` |

### Phase 3 Integration Tests (`test_scans_phase3.py`) [NEW v0.29.11]

| Test Class | Tests | Purpose |
|------------|-------|---------|
| TestPhase3PostScanIntegration | 6 | Import, call, try/except, guard, params, warning log |

### CronJob Manifest Tests (`test_cronjob_manifest.py`) [NEW v0.29.11]

| Test Class | Tests | Purpose |
|------------|-------|---------|
| TestCronJobScheduleAndCommand | 7 | Weekly schedule, deadline, --weekly flag, concurrency, restart policy |

### Multi-Level Matching Tests (`test_dedup_multilevel_matching.py`)

Regression and security tests for the 5-level matching audit (February 15, 2026). Verify that all automated dedup paths use correct matching strategies with proper scoping.

| Test Class | Tests | Purpose |
|------------|-------|---------|
| TestTask7UsesDeduplicationMatcher | 7 | Task 7 uses DeduplicationMatcher, not hardcoded "location" |
| TestCrossScanDedupLevels | 11 | All 5 levels present in cross-scan dedup (EXACT→HIGH→MEDIUM→LOW→SEMANTIC) |
| TestIntraScanDedupScoping | 3 | detector_id in GROUP BY prevents cross-type grouping |
| TestSemanticFingerprintRetry | 5 | Retry with exponential backoff for IE failures |
| TestScannerIdValidation | 2 | Empty scanner_id prevention guard |
| TestSecurityRegressions | 5 | Cross-contract, cross-type, hierarchical priority invariants |
| TestIntraScanDedupStructure | 2 | Structural verification of GROUP BY and security comment |

### Dead Code & Pipeline Regression Tests (v0.29.82)

| Test Class | Tests | Purpose |
|------------|-------|---------|
| TestVulnerabilityDedupColumns | 8 | VulnerabilityModel has direct FK, fingerprint columns, no join table reference |
| TestDeduplicationGroupModel | 8 | DeduplicationGroupModel uses contract_id scoping, has correct fields |
| TestDedupMatcherLevels | 6 | DeduplicationMatcher implements all 5 matching levels |
| TestIntraScanDedup | 2 | Intra-scan dedup function exists with detector_id scoping |
| TestCrossScanDedup | 2 | Cross-scan dedup tracks occurrence_count |
| TestDedupDispatch | 2 | Scan endpoint dispatches Celery task, no inline dedup |
| TestDedupTaskRegistration | 1 | Task name matches Celery worker registration |
| TestObsoleteMigrationRemoved | 2 | 004 migration deleted, no group_members reference in models |
| TestCeleryAppConfig (new) | 4 | Redis broker pool, transport retry, health check, connection retry |

Run locally:
```bash
# All dedup tests (120 tests)
python3 -m pytest tests/unit/infrastructure/test_deduplication_maintenance.py \
  tests/unit/presentation/test_scans_phase3.py \
  tests/unit/infrastructure/test_cronjob_manifest.py \
  tests/unit/infrastructure/test_dedup_multilevel_matching.py \
  tests/unit/domain/test_deduplication_matcher.py -v -o "addopts="
```

## Database Tables

| Table | Used By |
|-------|---------|
| `vulnerabilities` | Fingerprints, detector IDs, pattern codes, status |
| `deduplication_groups` | Group membership, canonical findings, confidence |
| `pattern_tool_mappings` | Scanner detector → pattern code mappings |
| `vulnerability_patterns` | Pattern definitions, FP rates, review flags |
| `vulnerability_classifications` | User classifications (confirmed/FP) |
| `scanner_quality_metrics` | Per-scanner precision and quality scores |
| `active_learning_queue` | Items awaiting human review |

## CronJob Configuration

```yaml
schedule: "0 2 * * 0"          # Weekly Sunday at 2 AM UTC (changed from daily in v0.29.11)
concurrencyPolicy: Forbid       # No overlapping jobs
activeDeadlineSeconds: 7200      # 2 hour max runtime (increased from 1h for full sweep)
backoffLimit: 2                  # Retry up to 2 times on failure
command: ["python", "-m", "src.infrastructure.tasks.deduplication_maintenance", "--weekly"]
resources:
  requests: { cpu: 100m, memory: 256Mi }
  limits:   { cpu: 500m, memory: 512Mi }
securityContext:
  readOnlyRootFilesystem: true   # Hardened container
volumeMounts:
  - /tmp                         # Scratch space (emptyDir)
  - /app/src/ml/models           # ML model storage (emptyDir, writable)
env:
  - ENVIRONMENT                  # From ConfigMap (api-service-config)
  - LOG_LEVEL                    # From ConfigMap (api-service-config)
  - DATABASE_URL                 # From Secret (api-service-secret)
  - INTELLIGENCE_ENGINE_URL      # From ConfigMap (api-service-config) — required for semantic fingerprints
```

### CronJob NetworkPolicies

The CronJob pods use label `app.kubernetes.io/name: deduplication-maintenance` (not `app: api-service`), so they have their own NetworkPolicies:

| Policy | Target | Port |
|--------|--------|------|
| `dedup-maintenance-to-dns` | kube-dns | 53 UDP/TCP |
| `dedup-maintenance-to-postgresql` | PostgreSQL | 5432 |
| `dedup-maintenance-to-intelligence` | Intelligence Engine | 80 |

## GCP Deployment

The CronJob requires a Cloud SQL Proxy sidecar in GCP (same pattern as the API Service Deployment).

**Key differences from local:**

| Setting | Local | GCP |
|---------|-------|-----|
| Namespace | `api-service-local` | `api-service-gcp` |
| Database | Direct PostgreSQL connection | Cloud SQL Proxy sidecar (`localhost:5432`) |
| Image registry | `harbor.blocksecops.local` | `us-west1-docker.pkg.dev/PROJECT/blocksecops` |
| IE URL | ConfigMap → `.intelligence-engine-local.` | ConfigMap → `.intelligence-engine-gcp.` |
| Auth | Kubernetes ServiceAccount | Workload Identity → GCP Service Account |
| Cloud SQL Proxy | N/A | `--quitquitquit` flag (exits when Job container finishes) |

**GCP overlay files:**
- `blocksecops-gcp-infrastructure/k8s/overlays/gcp/services/api-service/cronjob-deduplication.yaml`
- `blocksecops-gcp-infrastructure/k8s/overlays/gcp/services/api-service/kustomization.yaml` (includes CronJob)

**Verify GCP kustomize build:**
```bash
kubectl kustomize blocksecops-gcp-infrastructure/k8s/overlays/gcp/services/api-service/ | grep -A5 "kind: CronJob"
```

## Monitoring

Check recent job status:
```bash
# Local
kubectl get jobs -n api-service-local | grep dedup
kubectl logs -n api-service-local job/<job-name>

# GCP
kubectl get jobs -n api-service-gcp | grep dedup
kubectl logs -n api-service-gcp job/<job-name>
```

Manual trigger for testing:
```bash
# Local
kubectl create job --from=cronjob/deduplication-maintenance deduplication-maintenance-manual -n api-service-local

# GCP
kubectl create job --from=cronjob/deduplication-maintenance deduplication-maintenance-manual -n api-service-gcp
```

## Reliability & Regression Prevention

### SLO Targets

| Path | Target | Current |
|------|--------|---------|
| Inline post-scan | <1s p99 | Sub-second |
| Weekly CronJob | Completes within 2h activeDeadline | ~24min |
| Error isolation | Zero cascade failures | Every task has independent try/except/rollback |

### Test Layers (Defense in Depth)

| Layer | File(s) | What It Catches |
|-------|---------|-----------------|
| **1. Structural** (source parsing, no imports) | `test_deduplication_maintenance.py` | Missing try/except/rollback, wrong return keys, broken function signatures |
| **2. Manifest** (YAML parsing, no cluster) | `test_cronjob_manifest.py`, `test_cronjob_gcp_overlay.py` | Wrong schedule, missing env vars, missing Cloud SQL Proxy sidecar |
| **3. Functional** (AsyncMock, no external deps) | `test_semantic_deduplicator_retry.py`, `test_ie_url_resolution.py` | Broken retry logic, wrong backoff delays, URL resolution regressions |
| **4. Integration** (requires PostgreSQL + Redis) | CI pipeline | E2E scan flow with dedup |

### Pre-Deployment Checklist

```bash
# All dedup tests (target: 220+)
pytest tests/unit/infrastructure/test_deduplication_maintenance.py \
       tests/unit/infrastructure/test_cronjob_manifest.py \
       tests/unit/infrastructure/test_cronjob_gcp_overlay.py \
       tests/unit/ml/test_semantic_deduplicator*.py \
       tests/unit/ml/test_ie_url_resolution.py \
       tests/unit/presentation/test_scans_phase3.py \
       tests/unit/infrastructure/test_dedup_multilevel_matching.py \
       tests/unit/domain/test_deduplication_matcher.py -v -o "addopts="
```

- [ ] All tests pass
- [ ] Image tag in kustomization.yaml matches pyproject.toml version
- [ ] GCP: Cloud SQL Proxy image in CronJob matches Deployment sidecar
- [ ] GCP: IE URL points to `-gcp` namespace (not `-local`)

### Monitoring & Alerting

| Check | Command | Expected |
|-------|---------|----------|
| CronJob status | `kubectl get cronjob -n <namespace>` | LAST SCHEDULE within 7 days |
| Job logs | `kubectl logs job/<name> -c deduplication-job` | "Maintenance completed" |
| Cloud SQL Proxy (GCP) | `kubectl logs job/<name> -c cloud-sql-proxy` | Clean exit after main container |
| Alert trigger | 2 consecutive CronJob failures | Investigate immediately |
