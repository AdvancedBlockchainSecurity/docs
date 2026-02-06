# Deduplication Maintenance Pipeline

Daily background job that maintains data integrity across vulnerability fingerprints, deduplication groups, canonical findings, pattern codes, and scanner quality metrics.

## Overview

```
CronJob (2 AM UTC)         deduplication_maintenance.py              Database
──────────────────         ───────────────────────────               ────────
Scheduled trigger →        1. Regenerate empty fingerprints          vulnerabilities
                           2. Backfill missing detector_ids          deduplication_groups
                           3. Generate missing fingerprints          pattern_tool_mappings
                           4. Update deduplication groups             scanner_quality_metrics
                           5. Recalculate canonical findings
                           6. Update pattern codes from mappings
                           7. Refresh dynamic scanner priorities
                           8. Recalculate scanner quality metrics
                           9. Refresh pattern FP aggregates
```

## Trigger

- **Kubernetes CronJob**: Runs daily at 2 AM UTC
- **FastAPI startup task**: Optional periodic scheduling via background task
- **Manual**: Can be run via management command

## Maintenance Tasks

### Phase 1: Data Repair

| # | Task | Description |
|---|------|-------------|
| 1 | Regenerate empty fingerprints | Fix vulnerabilities with `fingerprint_code == SHA256("")` by using `detector_id` as fallback input |
| 2 | Backfill detector_ids | Derive `detector_id` from vulnerability title for records where it is NULL (lowercase, hyphenated) |
| 3 | Generate missing fingerprints | Create fingerprints for vulnerabilities where `fingerprint_code IS NULL` but `code_snippet` exists |

### Phase 2: Deduplication

| # | Task | Description |
|---|------|-------------|
| 4 | Update deduplication groups | Find orphaned vulnerabilities and assign them to existing or new groups |
| 5 | Recalculate canonical findings | Select best representative per group using dynamic scanner priority |
| 6 | Update pattern codes | Apply `pattern_tool_mappings` to assign `pattern_code` where missing |

### Phase 3: Analytics Refresh

| # | Task | Description |
|---|------|-------------|
| 7 | Dynamic scanner priorities | Refresh priority rankings from `DynamicScannerPriorityProvider` |
| 8 | Scanner quality metrics | Recalculate quality scores per scanner via `ScannerQualityTracker` |
| 9 | Pattern FP aggregates | Update false positive rates per pattern via `PatternFPAggregator` |

## Scanner Priority

Canonical finding selection uses dynamic priorities when available, with static fallbacks:

| Scanner | Default Priority | Notes |
|---------|-----------------|-------|
| slither | 1 | Highest priority |
| aderyn | 2 | |
| mythril | 3 | |
| semgrep | 4 | |
| solhint | 5 | |
| soliditydefend | 6 | |
| wake | 7 | |
| echidna | 8 | |
| medusa | 9 | |
| halmos | 10 | Lowest priority |

Lower number = higher priority for canonical selection.

## Key Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `EMPTY_FINGERPRINT_HASH` | `e3b0c44298fc...` | SHA-256 of empty string; marks fingerprints that need regeneration |
| Batch size (fingerprints) | 500 | Vulnerabilities processed per batch |
| Batch size (detector_ids) | 1000 | Vulnerabilities processed per batch |

## Files

| File | Role |
|------|------|
| `blocksecops-api-service/src/infrastructure/tasks/deduplication_maintenance.py` | All maintenance task functions |
| `blocksecops-api-service/src/domain/services/intelligence_service.py` | `VulnerabilityFingerprinter` for fingerprint generation |
| `blocksecops-api-service/src/domain/services/deduplication_matcher.py` | `DeduplicationMatcher` for grouping |
| `blocksecops-api-service/src/domain/services/dynamic_scanner_priority.py` | Dynamic priority calculation |
| `blocksecops-api-service/src/domain/services/scanner_quality_tracker.py` | Scanner quality metric recalculation |
| `blocksecops-api-service/src/domain/services/pattern_fp_aggregator.py` | Pattern-level FP rate aggregation |

## Error Handling

Each maintenance task runs independently and catches its own exceptions. A failure in one task does not prevent others from running. All tasks log statistics (processed, updated, remaining) for monitoring.

## Database Tables

- `vulnerabilities` — fingerprints, detector_ids, pattern_codes
- `deduplication_groups` — group membership and canonical findings
- `pattern_tool_mappings` — scanner detector → pattern mappings
- `scanner_quality_metrics` — per-scanner precision/quality scores
