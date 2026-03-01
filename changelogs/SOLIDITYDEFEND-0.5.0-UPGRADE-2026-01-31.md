# SolidityDefend Scanner Wrapper 0.5.0 Upgrade

**Date:** January 31, 2026
**Type:** Scanner Image Upgrade
**Impact:** Low (clean slate approach - old findings deleted)

---

## Summary

Upgraded the SolidityDefend scanner wrapper image from 0.4.0 to 0.5.0. This completes the scanner image rebuild following the upstream SolidityDefend 1.10.3 upgrade.

---

## Changes

### Scanner Wrapper Image
- **Version:** 0.4.0 → 0.5.0
- **Tool Version:** 1.10.3 (unchanged)
- **Detectors:** 333

### Files Modified

| File | Change |
|------|--------|
| `blocksecops-tool-integration/scanner-images/soliditydefend/Dockerfile` | Bumped `scanner.image.version` to 0.5.0 |
| `blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml` | Updated note and base image reference |
| `blocksecops-tool-integration/k8s/overlays/local/scanner-versions-patch.yaml` | Updated Harbor image ref to 0.5.0 |

### New Documentation

| File | Purpose |
|------|---------|
| `docs/playbooks/upgrade-scanner-image.md` | Reusable playbook for scanner upgrades |

---

## Verification

### Test Scan Results

| Metric | Value |
|--------|-------|
| Scan ID | `7fb85269-a29f-4524-b0a8-ea64240e2831` |
| Contract | foundry-test (VulnerableToken.sol) |
| Status | completed |
| Duration | 4 seconds |

### Vulnerabilities Found

| Severity | Count |
|----------|-------|
| Critical | 12 |
| High | 15 |
| Medium | 4 |
| Low | 3 |
| **Total** | **34** |

### Unique Detectors Used
22 detectors triggered including:
- `missing-zero-address-check`
- `dos-revert-bomb`
- `logic-error-patterns`
- `post-080-overflow`
- Various reentrancy and access control detectors

---

## Database Changes

### Pre-Upgrade Cleanup
Per the standards-compliant approach, old SolidityDefend findings were deleted before the upgrade:
- 10,515 old findings deleted (from previous 1.4.0 version)
- Scan counts recalculated
- Deduplication groups cleaned

This ensures a clean slate with only findings from the new 1.10.3 tool version.

---

## Bug Fix (Discovered During Testing)

Fixed an unrelated API service bug that was preventing scan result storage:

**Issue:** `last_scan_at` column referenced in code but not in database schema

**File:** `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py`

**Fix:** Removed the invalid column reference from the quota update query

**API Version:** 0.20.2 → 0.20.3

---

## Standards Applied

| Standard | Version | Application |
|----------|---------|-------------|
| Docker Image Versioning | v3.2.0 | Semantic versioning, OCI labels, --no-cache builds |
| Tool Metadata ConfigMaps | v1.8.0 | ConfigMap-based version management |
| Docker Base Images | v2.1.0 | Multi-stage builds, dual versioning |
| Deploy New Image Playbook | v1.0.0 | Step-by-step deployment workflow |

---

## Rollback

If needed:
```bash
kubectl patch configmap scanner-versions -n tool-integration-local \
  --type merge -p '{"data":{"SCANNER_IMAGE_SOLIDITYDEFEND":"harbor.blocksecops.local/blocksecops/scanner-soliditydefend:0.4.0"}}'
kubectl rollout restart deployment/tool-integration -n tool-integration-local
```

---

## Related Documentation

- [Upgrade Scanner Image Playbook](../playbooks/upgrade-scanner-image.md)
- [SolidityDefend v1.10.3 Verification](SOLIDITYDEFEND-V1.10.3-VERIFICATION-2026-01-18.md)
- [Scanner Version Tracking](../database/SCANNER-VERSION-TRACKING.md)
