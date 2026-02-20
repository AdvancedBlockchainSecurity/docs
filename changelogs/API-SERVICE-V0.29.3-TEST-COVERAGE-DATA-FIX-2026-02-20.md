# API Service v0.29.3 - Test Coverage Fix & Malformed Data Repair

**Component:** blocksecops-api-service
**Scope:** Fix pytest coverage config, rewrite unit tests to import actual source, repair malformed scanners_used data
**Date:** February 20, 2026
**Status:** Deployed

---

## Summary

Fixed a pytest configuration issue where `--cov-fail-under=80` in `pytest.ini` `addopts` caused individual test file runs to fail with 0% coverage (since they only cover a small portion of the entire `src/` tree). Rewrote `test_scans_by_scanner.py` to import and exercise the actual `DeduplicationGroupModel.scanner_count` property instead of reimplementing logic inline. Also discovered and repaired a malformed `scanners_used` database entry.

---

## Root Cause: Coverage Config

The `pytest.ini` `addopts` included `--cov=src` and `--cov-fail-under=80`, which applied globally to every `pytest` invocation. When running a single test file (e.g., `pytest tests/unit/test_scans_by_scanner.py`), coverage measured against the entire `src/` tree (26,237 statements) and reported ~2% coverage, triggering the 80% threshold failure even though all tests passed.

## Root Cause: Malformed Data

Scan `8c8c29be-f2cf-4a9c-ad19-172435025984` (VulnerableVault.sol, created 2026-02-08) had `scanners_used = {"slither aderyn semgrep solhint halmos echidna wake"}` — the entire scanner list as a single space-delimited string instead of individual array elements. The `scan_config` field had the same issue: `{"scanners": ["slither aderyn semgrep solhint halmos echidna wake medusa soliditydefend sol-azy"]}`.

This caused the UNNEST aggregation to count the space-delimited string as a single "scanner name" in the `scans_by_scanner` response.

**Origin:** The scan was created from the web UI (`scan_source = "web"`) on February 8, 2026. The `scanner_ids` field in the `CreateScanRequest` was passed as a single-element array containing a space-delimited string rather than a proper array of individual scanner names. This was a one-off data entry issue — the dashboard's TypeScript types (`scanner_ids: string[]`) and the API's pydantic schema (`scanner_ids: Optional[list[str]]`) both enforce correct typing, but neither validates that individual string elements don't contain spaces.

**Data fix applied:**
```sql
UPDATE scans
SET scanners_used = '{slither,aderyn,semgrep,solhint,halmos,echidna,wake}',
    scan_config = '{"scanners": ["slither", "aderyn", "semgrep", "solhint", "halmos", "echidna", "wake", "medusa", "soliditydefend", "sol-azy"]}'
WHERE id = '8c8c29be-f2cf-4a9c-ad19-172435025984';
```

---

## Key Changes

### pytest Configuration
- Moved `--cov-fail-under=80` from `pytest.ini` `addopts` to Makefile targets (`test-unit`, `test-all`)
- Coverage collection (`--cov=src`) still runs by default for all test invocations
- Coverage threshold only enforced when running the full test suite via `make test-unit` or `make test-all`

### Unit Tests Rewrite (11 tests -> 18 tests)
- Import actual `DeduplicationGroupModel` from `src/infrastructure/database/specialized_models/intelligence.py`
- Test real `scanner_count` property via mock with `type(group).scanner_count = DeduplicationGroupModel.scanner_count`
- Added source-parsing tests to verify endpoint wiring (UNNEST query, GROUP BY, ORDER BY, null filter)
- Added deduplication endpoint verification tests (min_scanner_count parameter, post-query filter logic)

---

## Files Modified

### blocksecops-api-service
- `pytest.ini` — Removed `--cov-fail-under=80` from default addopts
- `Makefile` — Added `--cov-fail-under=80` to `test-unit` and `test-all` targets
- `tests/unit/test_scans_by_scanner.py` — Rewritten to import actual source code (11 -> 18 tests)
- `pyproject.toml` — Version 0.29.2 -> 0.29.3
- `k8s/overlays/local/api-service/kustomization.yaml` — newTag and version label updated

### Database (manual fix)
- `scans` table — Fixed scan `8c8c29be` scanners_used from space-delimited string to proper array

---

## Verification

1. `pytest tests/unit/test_scans_by_scanner.py -v` — 18/18 passing, exit code 0 (no coverage failure)
2. `make test-unit` — Coverage threshold still enforced for full suite
3. UNNEST aggregation query returns clean results (no space-delimited entries)
4. `scans_by_scanner` counts: slither 162, aderyn 113, semgrep 66, solhint 66, wake 66, +11 more

---

## Use When

- Debugging pytest coverage failures when running individual test files
- Understanding the separation between default pytest config and CI coverage thresholds
- Investigating malformed `scanners_used` array entries
- Reviewing how to test SQLAlchemy model properties without a database session
