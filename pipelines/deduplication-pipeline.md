# Deduplication Maintenance Pipeline

Daily background job that maintains data integrity across vulnerability fingerprints, deduplication groups, canonical findings, pattern codes, scanner quality metrics, and ML training feedback.

## Overview

```
CronJob (2 AM UTC)         deduplication_maintenance.py              Database
──────────────────         ───────────────────────────               ────────
Scheduled trigger →        Phase 1: Cleanup & Fingerprints           vulnerabilities
                           Phase 2: Grouping & Mapping               deduplication_groups
                           Phase 3: Analytics & Quality              pattern_tool_mappings
                           Phase 4: ML Training Feedback             scanner_quality_metrics
                                                                     active_learning_queue
```

## Trigger

- **Kubernetes CronJob**: Runs daily at 2 AM UTC (`k8s/base/api-service/cronjob-deduplication.yaml`)
- **Manual**: `kubectl create job --from=cronjob/deduplication-maintenance deduplication-maintenance-manual -n api-service-local`
- **Programmatic**: `python -m src.infrastructure.tasks.deduplication_maintenance`

## Maintenance Tasks (18 Total)

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
| 7 | Update orphaned vulnerabilities | `update_orphaned_vulnerabilities()` | Assign ungrouped vulnerabilities to existing or new deduplication groups |
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
| `blocksecops-api-service/tests/unit/infrastructure/test_deduplication_maintenance.py` | Structural regression tests (46 tests) |

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
- Embedding service timeout → semantic fingerprints skipped, other tasks continue
- Intelligence engine unavailable → consensus scores deferred
- ML model missing/unsigned → training trigger uses dev fallback key
- Read-only filesystem → ML models volume mounted as writable emptyDir
- Failed DB query → transaction rolled back, next task starts with clean session

## Test Suite

Structural regression tests in `tests/unit/infrastructure/test_deduplication_maintenance.py` enforce invariants on the orchestrator. These tests parse the source file directly (no module import needed) and will fail if a new task is added without proper error isolation.

| Test Class | Purpose |
|------------|---------|
| TestOrchestratorStructure | All 18 markers present, each has try-block + rollback, return dict complete |
| TestTaskFunctionsExist | All 18 async functions defined with `db` parameter |
| TestConstants | EMPTY_FINGERPRINT_HASH, scanner priority derivation, consensus thresholds |
| TestErrorIsolation | Mock-based failure isolation and rollback verification (requires asyncpg) |

Run locally:
```bash
python3 -m pytest tests/unit/infrastructure/test_deduplication_maintenance.py -v \
  --override-ini="addopts=-v --tb=short -ra"
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
schedule: "0 2 * * *"          # Daily at 2 AM UTC
concurrencyPolicy: Forbid       # No overlapping jobs
activeDeadlineSeconds: 3600      # 1 hour max runtime
backoffLimit: 2                  # Retry up to 2 times on failure
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

## Monitoring

Check recent job status:
```bash
kubectl get jobs -n api-service-local | grep dedup
kubectl logs -n api-service-local job/<job-name>
```

Manual trigger for testing:
```bash
kubectl create job --from=cronjob/deduplication-maintenance deduplication-maintenance-manual -n api-service-local
```
