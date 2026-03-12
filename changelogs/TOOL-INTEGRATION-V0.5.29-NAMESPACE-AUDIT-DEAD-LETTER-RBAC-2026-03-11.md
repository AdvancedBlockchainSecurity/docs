# Tool Integration v0.5.29 — Namespace Audit, Dead-Letter Queue, RBAC, Version Fix

**Component:** blocksecops-tool-integration
**Scope:** Namespace references, scan result reliability, RBAC, version reporting
**Date:** March 11, 2026
**Status:** Deployed to GCP production
**PR:** [#136](https://github.com/AdvancedBlockchainSecurity/blocksecops-tool-integration/pull/136)

---

## Summary

Full namespace reference audit and production reliability fixes. Scan results were silently lost due to incorrect `API_SERVICE_URL` namespace reference (`api-service-gcp` instead of `api-service-prod`) in GCP Secret Manager, combined with missing dead-letter queue enqueue calls. Additionally, the `/cluster/metrics` endpoint returned 403 due to missing RBAC, and the service reported version `0.1.0` instead of the actual version.

---

## Changes

### 1. Version Source of Truth

**Files:** `src/main.py`, `Dockerfile`

Previously, 3 locations hardcoded `"0.1.0"`. Now reads version dynamically:

```python
SERVICE_VERSION = os.environ.get("SERVICE_VERSION")
if not SERVICE_VERSION:
    try:
        SERVICE_VERSION = _pkg_version("blocksecops-tool-integration")
    except Exception:
        SERVICE_VERSION = "unknown"
```

Dockerfile now persists the build arg as an env var:
```dockerfile
ARG SERVICE_VERSION=0.0.0
ENV SERVICE_VERSION=${SERVICE_VERSION}
```

### 2. Dead-Letter Queue on Forwarding Failures

**File:** `src/main.py` (12 error handlers)

All 12 `logger.error("Failed to post...to API service")` handlers now call `dead_letter_store.enqueue()` with scan_id, scanner type, payload, error message, and target URL. Scan results are no longer silently lost when api-service is unreachable.

### 3. RBAC — ClusterRole for /cluster/metrics

**Files:** `k8s/base/rbac.yaml`, `k8s/overlays/gcp/clusterrolebinding-patch.yaml`, `k8s/overlays/gcp/kustomization.yaml`

Added `tool-integration-cluster-reader` ClusterRole with `nodes` and `pods` list permissions (cluster scope) and `metrics.k8s.io` nodes list. GCP overlay patches the ClusterRoleBinding to use `tool-integration-prod` namespace for the ServiceAccount.

### 4. Legacy Namespace Cleanup

**Files:** `src/scanners/kubernetes_job_manager.py`, `src/scanners/result_collector.py`, `examples/scanner-job-slither.yaml`, `examples/scanner-job-aderyn.yaml`

Replaced all `solidity-security` references with `tool-integration-local` (the correct local dev namespace convention).

### 5. Import Fix

**File:** `src/main.py`

Added `timedelta` to `from datetime import datetime, timedelta, timezone` — required by `/cluster/metrics` endpoint.

### 6. Version Bump

`0.5.26` -> `0.5.29` across `pyproject.toml` and all 4 kustomization overlays (`gcp`, `local`, `staging`, `production`).

---

## Verification

| Check | Result |
|-------|--------|
| `/health` version | `0.5.29` |
| `/cluster/metrics` | 200 (nodes + pods data) |
| api-service reachable via ClusterIP | HTTP response received |
| `solidity-security` references in src/examples | 0 |
| `SERVICE_VERSION` env var in container | Present |
| Regression tests | 10/10 pass |

---

## Related

- GCP Secret Manager fix: `apogee-gcp-api-service-url` corrected from `api-service-gcp` to `api-service-prod`
- api-service NetworkPolicy fix: [blocksecops-api-service#313](https://github.com/AdvancedBlockchainSecurity/blocksecops-api-service/pull/313)
