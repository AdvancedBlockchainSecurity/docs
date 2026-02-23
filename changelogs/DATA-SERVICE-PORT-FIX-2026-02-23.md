# Data Service Port Fix — Service Port 80 → 8001

**Component:** blocksecops-data-service
**Scope:** Restore correct Service port mapping after stale manual apply
**Date:** February 23, 2026
**Status:** Fixed

---

## Summary

The data-service Kubernetes Service was exposing port 80 instead of port 8001, causing cross-namespace health checks to fail. The root cause was a stale manual `kubectl apply` of `k8s/base/data-service/service.yaml` (port 80) which overwrote the kustomize-managed service (port 8001 from `k8s/base/service.yaml`).

---

## Root Cause

The data-service repository has two Service definitions:

| File | Port | Used By |
|------|------|---------|
| `k8s/base/service.yaml` | **8001** | Kustomize overlay (correct) |
| `k8s/base/data-service/service.yaml` | **80** | Not referenced by overlay (stale) |

The overlay at `k8s/overlays/local/kustomization.yaml` references `../../base/` which resolves to `k8s/base/kustomization.yaml`, which includes `service.yaml` (port 8001). The `k8s/base/data-service/` directory has its own kustomization but is not referenced by the local overlay.

At some point, `k8s/base/data-service/service.yaml` was applied manually, overwriting the Service to port 80. Since the data-service container listens on port 8001 (named port `http`), the `targetPort: http` resolved correctly and the pod was healthy internally. However, all cross-namespace callers connecting to port 8001 via the Service got connection timeouts.

---

## Symptom

Platform smoke test failed for data-service:

```
=== Internal Services ===
  PASS: tool-integration
  PASS: orchestration
  PASS: notification
  PASS: intelligence
  FAIL: data-service (response: )
  PASS: contract-parser
```

Direct pod health check worked:
```bash
kubectl exec -n data-service-local deployment/data-service -- curl -s http://localhost:8001/health
# {"status":"healthy","service":"data-service"}
```

Cross-namespace health check timed out:
```bash
kubectl exec -n api-service-local deployment/api-service -- \
  curl -s -m 5 "http://data-service.data-service-local.svc.cluster.local:8001/health"
# Connection timed out
```

---

## Fix

Re-applied the kustomization overlay to restore the correct Service port:

```bash
cd /home/pwner/Git/blocksecops-data-service
kubectl apply -k k8s/overlays/local/
```

This restored the Service to port 8001 (from `k8s/base/service.yaml`), matching the documented port and all cross-namespace callers.

---

## Verification

```bash
# Service port confirmed as 8001
kubectl get svc -n data-service-local data-service -o jsonpath='{.spec.ports[*].port}'
# 8001 50053

# Cross-namespace health check passes
kubectl exec -n api-service-local deployment/api-service -- \
  curl -s -m 5 "http://data-service.data-service-local.svc.cluster.local:8001/health"
# {"status":"healthy","service":"data-service"}

# Full smoke test: 15/15 PASS
```

---

## Prevention

- Always use `kubectl apply -k k8s/overlays/local/` instead of applying individual YAML files
- The `k8s/base/data-service/` directory should be consolidated into `k8s/base/` to avoid confusion
- Run smoke test after any kustomize apply to catch port mismatches early

---

## Documentation Updated

- `docs/standards/smoke-test.md` — Fixed data-service expected response from `"status":"running"` to `"status":"healthy"`
