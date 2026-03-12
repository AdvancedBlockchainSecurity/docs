# Orchestration v0.10.9 — Legacy Service Name and Version Source Fix

**Component:** blocksecops-orchestration
**Scope:** Service metadata, version reporting, legacy namespace cleanup
**Date:** March 11, 2026
**Status:** Deployed to GCP production
**PR:** [#100](https://github.com/AdvancedBlockchainSecurity/blocksecops-orchestration/pull/100)

---

## Summary

Replaced legacy `solidity-security-orchestration` service name default and multiple hardcoded version strings with dynamic version resolution. The service now correctly reports its actual version via the `/health` endpoint, matching the pattern established by tool-integration v0.5.29.

---

## Changes

### 1. Service Name Default

**File:** `src/blocksecops_orchestration/core/config.py`

Changed `service_name` default from `"solidity-security-orchestration"` to `"blocksecops-orchestration"`.

### 2. Dynamic Version Source

**File:** `src/blocksecops_orchestration/core/config.py`

Replaced hardcoded `service_version: str = "0.1.0"` with dynamic resolution:
1. `SERVICE_VERSION` environment variable (set by Dockerfile build arg)
2. `importlib.metadata.version("blocksecops-orchestration")` fallback
3. `"unknown"` final fallback

### 3. FastAPI Version References

**File:** `src/blocksecops_orchestration/api/main.py`

Replaced 3 hardcoded `"0.7.1"` version strings:
- FastAPI app `version` parameter
- Root endpoint `"version"` field
- Added `"version"` field to `/health` endpoint response

### 4. Dockerfile ENV

**File:** `Dockerfile`

Persisted `SERVICE_VERSION` build arg as runtime `ENV` variable for container access.

### 5. Base ConfigMap

**File:** `k8s/base/orchestration/configmap.yaml`

Updated documentation-only `service_version` from `"0.1.0"` to `"0.10.9"`.

### 6. Version Bump

`0.10.8` → `0.10.9` across `pyproject.toml` and all 5 kustomization overlays (gcp, local, local/scanner-jobs, staging, production).

---

## Verification

| Check | Result |
|-------|--------|
| `/health` version | `0.10.9` |
| Image deployed to GCP | `orchestration:0.10.9` |
| No `solidity-security` references in src/ | Confirmed |
| No hardcoded `0.7.1` or `0.1.0` version in src/ | Confirmed |
| All kustomization overlays updated | Confirmed |

---

## Related

- Behavioral audit finding BEH-008: legacy `solidity-security` service name default
- Behavioral audit advisory ADV-B01: missing version in `/health` response
- tool-integration v0.5.29 version source fix: [PR #136](https://github.com/AdvancedBlockchainSecurity/blocksecops-tool-integration/pull/136)
