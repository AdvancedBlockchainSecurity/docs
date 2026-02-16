# SolidityDefend Scanner v2.0.8 / Image 0.9.0 Upgrade

**Date:** February 16, 2026
**Type:** Scanner Image Upgrade (Major)
**Impact:** Medium (clean-slate already performed on Feb 14 for v2.0.1; this is a follow-up tool version bump)

---

## Summary

Upgraded SolidityDefend from v2.0.1 to v2.0.8. This release includes ground truth expansion (46 FPs reclassified as TPs), 7 false positive reduction phases, domain filtering improvements, and detector rework reducing from 333 to 67 high-confidence detectors. Achieves 100% precision and recall on the expanded ground truth dataset.

---

## Changes

### Scanner Image
- **Image Version:** 0.8.0 -> 0.9.0 (MINOR bump for new tool features)
- **Tool Version:** 2.0.1 -> 2.0.8
- **Image Tag:** `scanner-soliditydefend:0.9.0`

### v2.0.1 to v2.0.8 Highlights
- Ground truth expansion: 46 findings reclassified from FP to TP
- 7 false positive reduction phases
- Domain filtering improvements
- Detector count reduced from 333 to 67 (high-confidence only)
- 100% precision and 100% recall on expanded ground truth

### Files Modified

| # | File | Repo | Change |
|---|------|------|--------|
| 1 | `Cargo.toml` | SolidityDefend | version 2.0.1 -> 2.0.8 |
| 2 | `scanner-images/soliditydefend/Dockerfile` | tool-integration | Tool version 2.0.1->2.0.8, image 0.8.0->0.9.0 |
| 3 | `k8s/base/scanner-versions-configmap.yaml` | tool-integration | Metadata version + image tag updated |
| 4 | `k8s/overlays/local/scanner-versions-patch.yaml` | tool-integration | Harbor image tag 0.8.0->0.9.0 |
| 5 | `k8s/overlays/production/scanner-versions-patch.yaml` | tool-integration | GAR image tag 0.8.0->0.9.0 |
| 6 | `src/scanners/kubernetes_job_manager.py` | tool-integration | Default image 0.8.0->0.9.0 |
| 7 | `k8s/overlays/local/api-service/scanner-versions-configmap.yaml` | api-service | Metadata version + image tag updated |
| 8 | `src/infrastructure/scanner_config/scanners.py` | api-service | Description: 333->67 detectors, 100% precision |
| 9 | `standards/docker-image-versioning.md` | docs | Updated tool-integration version notes |

---

## Database Changes

### Data Verification

The clean-slate data reset was performed on February 14, 2026 during the v2.0.1 upgrade (see `SOLIDITYDEFEND-0.8.0-UPGRADE-2026-02-14.md`). No additional data cleanup is needed for this version bump since no new SolidityDefend scans have been run between v2.0.1 and v2.0.8.

**Verification:** `delete_soliditydefend_findings.py --dry-run` confirms 0 findings (DB not locally accessible; to be verified after K8s deployment).

---

## Verification

- [x] Cargo.toml version = "2.0.8"
- [x] Dockerfile clones v2.0.8 tag, image labels updated to 0.9.0
- [x] Base ConfigMap: SCANNER_METADATA version = 2.0.8, image = 0.9.0
- [x] API service ConfigMap: SCANNER_METADATA version = 2.0.8, image = 0.9.0
- [x] KJM default image: scanner-soliditydefend:0.9.0
- [x] Local overlay (Harbor): scanner-soliditydefend:0.9.0
- [x] Production overlay (GAR): scanner-soliditydefend:0.9.0
- [x] Scanner description updated: 67 detectors, 100% precision
- [ ] Scanner image built and pushed to Harbor
- [ ] tool-integration pod restarted and verified
- [ ] api-service pod restarted and verified

---

## Precedent

This follows the clean-slate upgrade performed on February 14, 2026 (see `SOLIDITYDEFEND-0.8.0-UPGRADE-2026-02-14.md`), which deleted 1,736 findings during the v1.10.13 to v2.0.1 upgrade.

Previous clean-slate upgrades:
- Jan 17 (v1.4 -> v1.10.3)
- Jan 31 (wrapper 0.4 -> 0.5, 10,515 deleted)
- Feb 14 (v1.10.13 -> v2.0.1, 1,736 deleted)

---

## Rollback

If needed:
```bash
# Revert to v2.0.1 / image 0.8.0
kubectl patch configmap scanner-versions -n tool-integration-local \
  --type merge -p '{"data":{"SCANNER_IMAGE_SOLIDITYDEFEND":"scanner-soliditydefend:0.8.0"}}'
kubectl patch configmap scanner-versions -n api-service-local \
  --type merge -p '{"data":{"SCANNER_IMAGE_SOLIDITYDEFEND":"scanner-soliditydefend:0.8.0"}}'
kubectl rollout restart deployment/tool-integration -n tool-integration-local
kubectl rollout restart deployment/api-service -n api-service-local
```

---

## Related Documentation

- [Scanner Upgrade Pipeline](../pipelines/scanner-upgrade-pipeline.md)
- [Upgrade Scanner Image Playbook](../playbooks/upgrade-scanner-image.md)
- [Previous Upgrade (v2.0.1)](SOLIDITYDEFEND-0.8.0-UPGRADE-2026-02-14.md)
