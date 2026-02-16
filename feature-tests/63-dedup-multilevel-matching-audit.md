# Feature Test #63: Deduplication Multi-Level Matching Audit

**Date:** February 15, 2026
**Component:** blocksecops-api-service
**Test File:** `tests/unit/infrastructure/test_dedup_multilevel_matching.py`
**Status:** 35/35 passing

---

## Overview

Regression and security tests for the deduplication multi-level matching audit. Verifies that all three automated dedup paths (Task 7, cross-scan, intra-scan) use the correct matching strategies with proper scoping.

---

## Test Classes

### 1. TestTask7UsesDeduplicationMatcher (7 tests)

Verifies that maintenance Task 7 (`update_orphaned_vulnerabilities`) uses the `DeduplicationMatcher` instead of hardcoded "location" strategy.

| Test | Assertion |
|------|-----------|
| `test_imports_deduplication_matcher` | Source file imports `DeduplicationMatcher` |
| `test_creates_matcher_instance` | Function creates a `DeduplicationMatcher(` instance |
| `test_calls_matcher_match` | Function calls `matcher.match(` |
| `test_no_hardcoded_location_strategy` | No hardcoded `strategy = "location"` in function body |
| `test_returns_strategy_counts` | Return dict includes `strategy_counts` key |
| `test_matches_orphans_against_existing_groups` | Two-phase matching (orphans vs existing, then orphans vs orphans) |
| `test_initializes_semantic_deduplicator` | Tries to get semantic deduplicator for SEMANTIC level |

### 2. TestCrossScanDedupLevels (11 tests)

Verifies all 5 matching levels exist in `_process_cross_scan_deduplication()`.

| Test | Assertion |
|------|-----------|
| `test_has_exact_level` | "Level 1" or "EXACT" comment present |
| `test_has_high_level` | "Level 2" or "HIGH" comment present |
| `test_has_medium_level` | "Level 3" or "MEDIUM" comment present |
| `test_has_low_level` | "Level 4" or "LOW" comment present |
| `test_has_semantic_level` | "Level 5" or "SEMANTIC" comment present |
| `test_medium_checks_ast_and_fuzzy` | MEDIUM uses `fingerprint_ast` and `fingerprint_location_fuzzy` |
| `test_low_checks_pattern_and_fuzzy` | LOW uses `pattern_code` and `fingerprint_location_fuzzy` |
| `test_medium_strategy_label` | Strategy labeled `"medium"` |
| `test_low_strategy_label` | Strategy labeled `"low"` |
| `test_tracks_ast_matches` | Increments `ast_matches` counter |
| `test_tracks_pattern_matches` | Increments `pattern_matches` counter |

### 3. TestIntraScanDedupScoping (3 tests)

Verifies `detector_id` is used in intra-scan dedup to prevent cross-type grouping.

| Test | Assertion |
|------|-----------|
| `test_groups_by_detector_id` | `group_by` includes `detector_id` |
| `test_selects_detector_id` | SELECT clause includes `detector_id` |
| `test_where_clause_includes_detector_id` | WHERE clause filters by `detector_id` |

### 4. TestSemanticFingerprintRetry (5 tests)

Verifies retry with exponential backoff for IE connectivity failures.

| Test | Assertion |
|------|-----------|
| `test_has_retry_loop` | `for attempt in range(max_retries)` pattern present |
| `test_has_exponential_backoff` | `2.0 * (2 ** attempt)` or similar exponential formula |
| `test_has_max_delay_cap` | Delay capped at 30 seconds |
| `test_uses_asyncio_sleep` | Uses `asyncio.sleep` (not `time.sleep`) for async compat |
| `test_only_retries_embedding_errors` | Catches `EmbeddingServiceError` specifically |

### 5. TestScannerIdValidation (2 tests)

Verifies empty scanner_id prevention in scan ingest.

| Test | Assertion |
|------|-----------|
| `test_scanner_id_empty_guard` | Checks for `not scanner_id` or `scanner_id.strip()` |
| `test_scanner_id_fallback` | Falls back to `scanners_used[0]` |

### 6. TestSecurityRegressions (5 tests)

Verifies security invariants of the `DeduplicationMatcher` class.

| Test | Assertion |
|------|-----------|
| `test_dedup_matcher_prevents_cross_contract_grouping` | Different `contract_id` returns no match |
| `test_dedup_matcher_prevents_cross_type_grouping` | Different `detector_id` returns no match |
| `test_dedup_matcher_hierarchical_priority` | EXACT match returned when both EXACT and HIGH candidates exist |
| `test_dedup_matcher_medium_level_requires_ast` | MEDIUM match requires `fingerprint_ast` |
| `test_dedup_matcher_low_level_requires_pattern_and_fuzzy` | LOW match requires both `pattern_code` and `fingerprint_location_fuzzy` |

### 7. TestIntraScanDedupStructure (2 tests)

Structural verification of the intra-scan dedup function.

| Test | Assertion |
|------|-----------|
| `test_group_by_has_detector_id` | GROUP BY clause contains `detector_id` |
| `test_security_comment_present` | Security comment explaining detector_id scoping |

---

## Running Tests

```bash
# Run only this test file
python3 -m pytest tests/unit/infrastructure/test_dedup_multilevel_matching.py -v -o "addopts="

# Run all dedup-related tests
python3 -m pytest tests/unit/infrastructure/test_dedup_multilevel_matching.py \
  tests/unit/domain/test_deduplication_matcher.py \
  tests/unit/infrastructure/test_deduplication_maintenance.py -v -o "addopts="
```

---

## Related

- [Dedup Pipeline Error Isolation Tests](61-dedup-pipeline-error-isolation.md)
- [Cross-Scanner Deduplication Tests](24-cross-scanner-deduplication.md)
- [Changelog](../changelogs/API-SERVICE-DEDUP-MULTILEVEL-MATCHING-AUDIT-2026-02-15.md)
