# API Service 0.28.40 - Deployment Fix & Lazy Code Snippet Extraction

**Date:** February 18, 2026
**Component:** blocksecops-api-service
**Version:** 0.28.38 -> 0.28.40

---

## Summary

Resolved a Kubernetes deployment failure that blocked api-service 0.28.40 from rolling out. The cluster was stuck on 0.28.38 (which lacked GET-endpoint code snippet extraction). Also added lazy code snippet extraction on the vulnerability detail GET endpoint so code context is extracted and persisted on first view.

---

## Fix 1: Kustomize Env Config Conflict (Deployment Blocker)

**Problem:** `kubectl apply -k k8s/overlays/local/` failed with:

```
The Deployment "api-service" is invalid: spec.template.spec.containers[0].env[16].valueFrom:
Invalid value: "": may not be specified when `value` is not empty
```

**Root Cause:** The base deployment (`k8s/base/api-service/deployment.yaml:73`) defines `DASHBOARD_BASE_URL` with `valueFrom` (configMapKeyRef pointing to `dashboard_base_url` in `api-service-config`). The local overlay patch (`k8s/overlays/local/deployment-patch.yaml:88`) also defined `DASHBOARD_BASE_URL` with a hardcoded `value`. Kustomize strategic merge produced an env entry with both `value` and `valueFrom`, which Kubernetes rejects.

**Fix:** Removed the hardcoded `DASHBOARD_BASE_URL` entry from `deployment-patch.yaml`. The base deployment's `valueFrom` resolves correctly via the configmap.

**Files Changed:**
- `k8s/overlays/local/deployment-patch.yaml` - Removed duplicate `DASHBOARD_BASE_URL` env entry (lines 87-89)

---

## Fix 2: Missing ConfigMap Keys

**Problem:** After removing the hardcoded env var, the new pod failed with `CreateContainerConfigError`: `couldn't find key allowed_hosts in ConfigMap api-service-local/api-service-config`.

**Root Cause:** The base deployment references `allowed_hosts` and `dashboard_base_url` via `configMapKeyRef`, but the overlay configmap patch (`k8s/overlays/local/configmap-patch.yaml`) did not provide these keys.

**Fix:** Added `allowed_hosts` and `dashboard_base_url` to the overlay configmap patch.

**Files Changed:**
- `k8s/overlays/local/configmap-patch.yaml` - Added `allowed_hosts: "app.0xapogee.local"` and `dashboard_base_url: "https://app.0xapogee.local"`

---

## Fix 3: Kustomization Version Sync

**Problem:** `kustomization.yaml` had `newTag: "0.26.0"` while `pyproject.toml` was at `0.28.40`. Per docker-image-versioning standards, these must be in sync.

**Fix:** Updated `newTag` and `app.kubernetes.io/version` label to `"0.28.40"` in both kustomization files.

**Files Changed:**
- `k8s/overlays/local/kustomization.yaml` - Updated `newTag` and version label from 0.26.0 to 0.28.40
- `k8s/overlays/local/api-service/kustomization.yaml` - Updated `newTag` from 0.28.38 to 0.28.40

---

## Feature: Lazy Code Snippet Extraction on GET

**Problem:** Many vulnerabilities have `code_snippet = NULL` or invalid `line:col` strings (e.g. "669:16") stored by scanners. This hides the Code Location section and disables AI Code Repair on the vulnerability detail page.

**Fix:** Added lazy extraction in `GET /vulnerabilities/{id}`. When a vulnerability has `line_number` but no valid `code_snippet`:

1. Reads contract source from `contract.source_code` (single-file) or `ContractFileModel.file_content` (multi-file, matched by `file_path`)
2. Extracts a 5-line context window (2 lines before, target line with arrow marker, 2 lines after)
3. Persists the snippet to the database on first view

Also rejects bare `line:col` patterns (e.g. "669:16") as invalid code snippets in both `store_scan_results` and the GET endpoint.

**Files Changed:**
- `src/presentation/api/v1/endpoints/vulnerabilities.py` - Lazy code snippet extraction and persistence
- `src/presentation/api/v1/endpoints/scans.py` - Reject `line:col` patterns during scan result storage

---

## Deployment

```bash
# Image already built and pushed to Harbor
docker push harbor.0xapogee.local/blocksecops/api-service:0.28.40

# Applied kustomize overlay
kubectl apply -k k8s/overlays/local/

# Verified
kubectl -n api-service-local get pods -o jsonpath='{.items[?(@.status.phase=="Running")].spec.containers[*].image}'
# harbor.0xapogee.local/blocksecops/api-service:0.28.40

curl -sk https://app.0xapogee.local/api/v1/health/live
# {"status":"healthy","version":"0.28.40"}
```

---

## Verification

- [x] `kubectl apply -k` succeeds without env config conflict
- [x] Pod running: api-service:0.28.40, 1/1 READY
- [x] Health endpoint returns version 0.28.40
- [x] Code snippet visible on vulnerability detail page: `https://app.0xapogee.local/vulnerabilities/5bd16f06-1d70-401d-905d-c6876504509c`
- [x] Code snippet persisted to database after first view

---

## Security Note

The `configmap-patch.yaml` still contains `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_KEY` in plaintext. Per secrets-management standards, the service key should be migrated to Vault via ExternalSecret. Tracked for follow-up.
