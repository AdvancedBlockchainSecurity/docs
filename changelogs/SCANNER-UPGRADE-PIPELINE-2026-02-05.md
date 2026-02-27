# Scanner Upgrade Pipeline - Full Automation

## Version Changes - February 5, 2026

**Date:** 2026-02-05
**Components:** blocksecops-api-service (0.25.8 -> 0.25.9), blocksecops-admin-portal (0.1.14 -> 0.1.15)
**Type:** Feature
**Priority:** High
**Status:** Complete

---

## Summary

Extended the Admin Dashboard "Upgrade" button to run the full scanner upgrade pipeline: ConfigMap update, detector comparison, pattern seeding, and audit validation. Previously the button only updated ConfigMap metadata and restarted the pod. The full pipeline now automates database-side intelligence operations that were previously manual CLI-only steps.

---

## What Changed

### New Service Module

Created `scanner_upgrade_service.py` in the API service domain layer. This module extracts core logic from three CLI scripts into async functions that accept an `AsyncSession` parameter, enabling the API endpoint to run the full pipeline within the same database transaction.

**Functions extracted from:**
- `scripts/upgrade_scanner.py` - Detector comparison, mapping suggestions
- `scripts/seed_scanner_patterns.py` - Pattern seeding for unmapped vulnerabilities
- `scripts/audit_scanner_upgrade.py` - Coverage auditing, health scoring

### Extended API Endpoint

The `POST /admin/system/scanners/{name}/upgrade` endpoint now runs three pipeline phases after a successful ConfigMap update:

| Phase | Description | Output |
|-------|-------------|--------|
| Detector comparison | Compares detector list against existing mappings | new/changed/removed counts |
| Pattern seeding | Creates patterns for unmapped vulnerabilities | patterns/mappings created |
| Audit validation | Calculates coverage and health score | health % and status |

The response includes a new `pipeline` field with structured results from each phase.

### Updated Admin Portal UI

The upgrade confirmation dialog now displays pipeline results after a successful upgrade:
- Detector comparison summary (new/changed/removed counts)
- Pattern seeding counts (patterns created, mappings created)
- Health score with color coding (green >= 90%, yellow >= 70%, red < 70%)

### Files Modified

| File | Change |
|------|--------|
| `blocksecops-api-service/src/domain/services/scanner_upgrade_service.py` | **NEW** - Pipeline service module |
| `blocksecops-api-service/src/presentation/api/v1/endpoints/admin/system.py` | Added `pipeline` field to response, call pipeline after ConfigMap update |
| `blocksecops-api-service/pyproject.toml` | Version 0.25.8 -> 0.25.9 |
| `blocksecops-api-service/k8s/overlays/local/kustomization.yaml` | newTag 0.25.8 -> 0.25.9 |
| `blocksecops-admin-portal/src/lib/api/admin.ts` | Extended `ScannerUpgradeResponse` with pipeline types |
| `blocksecops-admin-portal/src/pages/AdminSystem.tsx` | Pipeline results display in upgrade dialog |
| `blocksecops-admin-portal/package.json` | Version 0.1.14 -> 0.1.15 |
| `blocksecops-admin-portal/k8s/overlays/local/kustomization.yaml` | newTag 0.1.14 -> 0.1.15 |

---

## Architecture

```
Admin Portal                API Service                     Tool Integration
────────────               ─────────────                   ──────────────────
Click "Upgrade" →          POST /admin/system/             POST /scanners/{name}/upgrade
                           scanners/{name}/upgrade
                           1. Proxy to tool-integration     1. Update ConfigMap
                           2. On success, run pipeline:     2. Restart deployment
                              a. Detector comparison         3. Return result
                              b. Pattern seeding
                              c. Audit validation
                           3. Return combined result
                    ←      (includes pipeline results)
```

The pipeline runs synchronously in the API service after the ConfigMap update succeeds. Each phase catches exceptions independently so a failure in one phase does not stop others.

---

## Error Handling

- Each pipeline phase is wrapped in its own try/except block
- Phase errors are captured in the response (e.g., `detector_comparison.error`) rather than failing the entire upgrade
- The ConfigMap update (via tool-integration) is the primary success condition; pipeline phases are supplementary
- All pipeline operations use `db.flush()` instead of `db.commit()` to stay within the endpoint's transaction

---

## Deployment Steps

### API Service (0.25.9)
```bash
cd /home/pwner/Git/blocksecops-api-service

VERSION=0.25.9
docker build \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t harbor.0xapogee.local/blocksecops/api-service:${VERSION} .

docker push harbor.0xapogee.local/blocksecops/api-service:${VERSION}
kubectl apply -k k8s/overlays/local/
kubectl rollout restart deployment/api-service -n api-service-local
```

### Admin Portal (0.1.15)
```bash
cd /home/pwner/Git/blocksecops-admin-portal

VERSION=0.1.15
SUPABASE_URL=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_url}')
SUPABASE_KEY=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_anon_key}')

docker build \
  --build-arg VITE_ADMIN_SUPABASE_URL=${SUPABASE_URL} \
  --build-arg VITE_ADMIN_SUPABASE_ANON_KEY=${SUPABASE_KEY} \
  --build-arg VITE_ENVIRONMENT=local \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t harbor.0xapogee.local/blocksecops/admin-portal:${VERSION} .

docker push harbor.0xapogee.local/blocksecops/admin-portal:${VERSION}
kubectl apply -k k8s/overlays/local/
```

---

## Verification

### Service Module Import
```bash
kubectl exec -n api-service-local deploy/api-service -- python -c \
  "from src.domain.services.scanner_upgrade_service import run_upgrade_pipeline; print('OK')"
```

### End-to-End
1. Admin System → Security Scanners → click "Upgrade" on a scanner with available update
2. After success, verify "Pipeline Results" section appears with:
   - Detector comparison counts
   - Pattern seeding counts
   - Health score with color coding
3. Admin System → Audit Log → verify `admin.scanner.upgrade` entry includes pipeline success

---

## Related Documentation

- [Scanner Upgrade Pipeline](../pipelines/scanner-upgrade-pipeline.md) - Technical pipeline details
- [Scanner Upgrade Workflow](../workflows/scanner-upgrade-workflow.md) - Full workflow overview
- [Upgrade Scanner Image Playbook](../playbooks/upgrade-scanner-image.md) - Manual upgrade steps
- [Scanner Upgrade Feature Test](../feature-tests/57-scanner-upgrade-admin.md) - Test checklist
- [Intelligence Integration Standards](../standards/INTELLIGENCE-INTEGRATION-STANDARDS.md) - BVD pattern codes

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.25.9 | 2026-02-05 | API Service: Full upgrade pipeline in endpoint |
| 0.1.15 | 2026-02-05 | Admin Portal: Pipeline results display |

---

**Maintained By:** BlockSecOps Team
**Status:** Complete
