# Scanner Reliability & RustDefend Fix

**Date:** 2026-02-17
**Component:** blocksecops-tool-integration, blocksecops-api-service
**Type:** Bug Fix
**Priority:** Critical (P0) / High (P1)
**Status:** ✅ Complete

---

## Summary

Fixed 5 production bugs causing scanner failures and data inaccessibility. RustDefend consistently returned 0 findings because Kubernetes jobs were killed by `activeDeadlineSeconds` before completing, caused by a ConfigMap race condition combined with insufficient job timeouts. The vulnerability API's `contract_id`/`scan_id` filters were also non-functional.

---

## Issues Resolved

1. **ConfigMap Race Condition (P0):** Concurrent scanners for the same scan triggered 409 conflicts, causing the KJM to delete and recreate the ConfigMap — destroying mounts for already-running pods
2. **Insufficient Job Timeouts (P1):** solhint (60s), soliditydefend (60s), aderyn (120s), and rustdefend (120s) were too low — image pull alone can consume 30-60s
3. **RustDefend Wrapper Temp File Leak (P1):** Temp files only cleaned on success path, leaked on failure/abort
4. **RustDefend Wrapper Curl Error Masking (P1):** Failure-path curl used `|| true`, silently masking network errors
5. **Vulnerability API Filters Non-Functional (P0):** `contract_id` and `scan_id` query params accepted but never applied to query

---

## Fixed 🐛

### Phase 1: ConfigMap Race Condition Fix

**File:** `blocksecops-tool-integration/src/scanners/kubernetes_job_manager.py` (lines 127-133)

Replaced delete-recreate on 409 conflict with create-or-reuse pattern:

```python
except ApiException as e:
    if e.status == 409:
        logger.info(f"ConfigMap {configmap_name} already exists for scan {scan_id}, reusing")
        return configmap_name
    logger.error(f"Failed to create ConfigMap {configmap_name}: {e}")
    raise
```

**Rationale:** All scanners for a given scan receive the same contract source. The ConfigMap content is identical regardless of which scanner created it.

### Phase 2: Scanner Job Timeout Increases

**File:** `blocksecops-tool-integration/src/scanners/kubernetes_job_manager.py` (lines 699-723)

| Scanner | Before | After | Reason |
|---------|--------|-------|--------|
| solhint | 60s | 180s | Image pull + lint time |
| soliditydefend | 60s | 180s | Image pull + analysis time |
| aderyn | 120s | 300s | Large contracts need more time |
| rustdefend | 120s | 300s | AST analysis + result POST time |

### Phase 3: RustDefend Wrapper Script Hardening

**File:** `blocksecops-tool-integration/scanner-images/rustdefend/rustdefend-scan`

- Added `trap cleanup EXIT` for temp file lifecycle management (replaces individual `rm -f` calls)
- All 4 curl paths now use HTTP code capture pattern (`-w "\n%{http_code}"` + `|| echo "000"`) instead of `|| true`
- Removed `|| true` from sed JSON extraction commands (let `jq empty` validation handle failures)

**Image version:** `scanner-rustdefend:0.3.2` → `0.3.3`

### Phase 4: Vulnerability API Filtering Fix

**File:** `blocksecops-api-service/src/presentation/api/v1/endpoints/vulnerabilities.py` (lines 69-70, 123-134)

Added `contract_id` and `scan_id` as FastAPI `Query()` parameters with UUID validation and SQLAlchemy WHERE clauses. Filters are additive to existing org-scoped base query (no security bypass possible).

### Phase 5: RustDefend Callback Handler Fixes

**File:** `blocksecops-tool-integration/src/main.py`

- Detector ID normalization: `.strip().upper().replace(" ", "-").replace("_", "-")` for consistent storage/aggregation
- Hidden directory filter aligned with shell script: `any(part.startswith('.') and part != '.' for part in path.split('/'))`

---

## Changed 🔧

### Version Propagation (All 4 Locations)

Per SCANNER-VERSION-MANAGEMENT.md, all 4 version locations updated for rustdefend 0.3.2 → 0.3.3:

| Location | File | Change |
|----------|------|--------|
| Dockerfile | `scanner-images/rustdefend/Dockerfile` | Label + FROM tag |
| KJM fallback | `src/scanners/kubernetes_job_manager.py` (line 582) | `0.3.2` → `0.3.3` |
| Base ConfigMap | `k8s/base/scanner-versions-configmap.yaml` | `scanner-rustdefend:0.3.3` |
| Local overlay | `k8s/overlays/local/scanner-versions-patch.yaml` | Harbor path updated |
| Production overlay | `k8s/overlays/production/scanner-versions-patch.yaml` | GCP AR path updated |

---

## Testing

### New Test Files (35 tests total)

| File | Tests | Coverage |
|------|-------|----------|
| `tool-integration/tests/unit/scanners/test_configmap_race.py` | 5 | ConfigMap 409 reuse, no delete, no recursion, success path, non-409 error |
| `tool-integration/tests/unit/scanners/test_job_timeouts.py` | 20 | Parametrized minimum 180s across all 16 scanners, specific value assertions |
| `api-service/tests/unit/test_vulnerability_filters.py` | 10 | contract_id/scan_id params, filter applied, UUID validation, backwards compat |

### Verification Commands

```bash
# ConfigMap race tests
cd /home/pwner/Git/blocksecops-tool-integration
python3 -m pytest tests/unit/scanners/test_configmap_race.py -v

# Timeout validation tests
python3 -m pytest tests/unit/scanners/test_job_timeouts.py -v

# Vulnerability filter tests
cd /home/pwner/Git/blocksecops-api-service
python3 -m pytest tests/unit/test_vulnerability_filters.py -v -o "addopts="
```

---

## Files Modified

### blocksecops-tool-integration

| File | Lines | Change |
|------|-------|--------|
| `src/scanners/kubernetes_job_manager.py` | 127-133, 582, 699-723 | ConfigMap reuse on 409, fallback version bump, timeout increases |
| `scanner-images/rustdefend/rustdefend-scan` | 25-32, 117, 121, 225-262 | Cleanup trap, curl error handling, sed fix |
| `scanner-images/rustdefend/Dockerfile` | 8, 51, 53 | Version bump 0.3.2 → 0.3.3 |
| `src/main.py` | 1454, 1465-1468, 1491 | Detector ID normalization, hidden dir filter |
| `k8s/base/scanner-versions-configmap.yaml` | - | rustdefend 0.3.2 → 0.3.3 |
| `k8s/overlays/local/scanner-versions-patch.yaml` | - | Harbor path updated |
| `k8s/overlays/production/scanner-versions-patch.yaml` | - | GCP AR path updated |
| `tests/unit/scanners/test_configmap_race.py` | NEW | 5 tests |
| `tests/unit/scanners/test_job_timeouts.py` | NEW | 20 tests |

### blocksecops-api-service

| File | Lines | Change |
|------|-------|--------|
| `src/presentation/api/v1/endpoints/vulnerabilities.py` | 69-70, 123-134 | contract_id/scan_id query params + filters |
| `tests/unit/test_vulnerability_filters.py` | NEW | 10 tests |

---

## Impact

- **Scanner Reliability:** ConfigMap race condition eliminated — concurrent scanners no longer destroy each other's mounts
- **RustDefend:** Now completes within 300s timeout and posts results successfully
- **Vulnerability API:** Users can filter findings by contract and scan for the first time
- **Observability:** curl failures now logged with HTTP status codes instead of silently swallowed
- **Breaking Changes:** None — all changes are backwards compatible

---

## Related Documentation

| Document | Path |
|----------|------|
| RustDefend Scanner README | `docs/scanners/RustDefend/README.md` |
| ConfigMap Symlink Fix | `docs/feature-tests/64-configmap-symlink-scanner-fix.md` |
| Docker Image Versioning | `docs/standards/docker-image-versioning.md` |
| RustDefend Integration Changelog | `docs/changelogs/RUSTDEFEND-0.1.0-INTEGRATION-2026-02-16.md` |
| Scan Timeout Workflow | `docs/workflows/scan-timeout-retry-workflow.md` |
