# SolidityDefend Scanner v2.0.1 / Image 0.8.0 Upgrade

**Date:** February 14, 2026
**Type:** Scanner Image Upgrade (Major)
**Impact:** High (clean-slate approach - all v1.x findings deleted due to 76% FP rate)

---

## Summary

Upgraded SolidityDefend from v1.10.13 to v2.0.1 (major version upgrade). This release includes reworked detectors, removed detectors, and pattern work that significantly reduces false positives. A clean-slate data removal was performed because the previous version had a 76% false positive rate, making existing findings unreliable for AI/ML training.

---

## Changes

### Scanner Image
- **Image Version:** 0.7.1 -> 0.8.0 (MINOR bump for new tool major version)
- **Tool Version:** 1.10.13 -> 2.0.1
- **Image Tag:** `scanner-soliditydefend:0.8.0`

### Files Modified

| File | Change |
|------|--------|
| `blocksecops-tool-integration/scanner-images/soliditydefend/Dockerfile` | Updated tool version to 2.0.1, image version to 0.8.0 |
| `blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml` | Updated image tag to 0.8.0, metadata version to 2.0.1 |
| `docs/standards/docker-image-versioning.md` | Updated version tracking notes |

---

## Database Changes

### Pre-Upgrade Cleanup (Clean Slate)

Per scanner-upgrade-pipeline.md, all SolidityDefend data was removed before deploying the new version.

**Pre-cleanup counts:**

| Data Type | Count |
|-----------|-------|
| Vulnerabilities | 1,736 |
| Single-scanner scans | 17 |
| Multi-scanner scans | 4 |
| Dedup groups (SD canonical) | 148 |
| User labels | 0 |

**Cleanup steps performed:**
1. Ungrouped 1,091 vulnerabilities from SD-canonical dedup groups
2. Deleted 148 dedup groups with SD-canonical findings
3. Deleted 1,736 SolidityDefend vulnerabilities
4. Deleted 16 single-scanner SD scans
5. Deleted 1 empty multi-scanner scan
6. Recalculated severity counts for 4 remaining multi-scanner scans
7. Removed 'soliditydefend' from scanners_used arrays
8. Cleaned orphaned dedup groups

**Post-cleanup verification:** 0 SD vulnerabilities, 0 SD scans, 0 SD references in scanners_used.

**Data preserved:** 410 scans, 2,528 vulnerabilities, 617 dedup groups (from other scanners).

### Backup

Database backup created before cleanup:
- `backups/solidity_security_pre_sd_upgrade_20260214_205127.sql` (2.6MB, PostgreSQL custom format)

---

## Verification

- [x] Pre-cleanup backup exists and verified (909 TOC entries)
- [x] Post-cleanup verification shows 0 SD data
- [x] New scanner image `scanner-soliditydefend:0.8.0` pushed to Harbor
- [x] ConfigMap updated with version `2.0.1` and image `0.8.0` (both namespaces)
- [x] tool-integration pod restarted and shows `SCANNER_IMAGE_SOLIDITYDEFEND=scanner-soliditydefend:0.8.0`
- [x] api-service pod restarted and scanner metadata endpoint shows version `2.0.1`

---

## Precedent

This follows the same clean-slate procedure used on January 31, 2026 (see `SOLIDITYDEFEND-0.5.0-UPGRADE-2026-01-31.md`), which deleted 10,515 findings during the v1.4.0 to v1.10.3 upgrade.

---

## Rollback

If needed:
```bash
# Revert ConfigMap
kubectl patch configmap scanner-versions -n tool-integration-local \
  --type merge -p '{"data":{"SCANNER_IMAGE_SOLIDITYDEFEND":"scanner-soliditydefend:0.7.1"}}'
kubectl patch configmap scanner-versions -n api-service-local \
  --type merge -p '{"data":{"SCANNER_IMAGE_SOLIDITYDEFEND":"scanner-soliditydefend:0.7.1"}}'
kubectl rollout restart deployment/tool-integration -n tool-integration-local
kubectl rollout restart deployment/api-service -n api-service-local

# Restore database from backup
pg_restore -h 127.0.0.1 -p 5432 -U blocksecops -d solidity_security \
  --no-owner --no-acl backups/solidity_security_pre_sd_upgrade_20260214_205127.sql
```

---

## Related Documentation

- [Scanner Upgrade Pipeline](../pipelines/scanner-upgrade-pipeline.md)
- [Upgrade Scanner Image Playbook](../playbooks/upgrade-scanner-image.md)
- [Previous Upgrade](SOLIDITYDEFEND-0.5.0-UPGRADE-2026-01-31.md)
