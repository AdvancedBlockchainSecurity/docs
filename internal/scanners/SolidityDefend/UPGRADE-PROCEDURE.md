# SolidityDefend Upgrade Procedure

## Quick Reference

### Files to Update

1. **ConfigMap** (single source of truth):
   - `blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml`

2. **Scanner image** (if Apogee wrapper image changed):
   - `blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml` — `SCANNER_IMAGE_SOLIDITYDEFEND` tag

No api-service files need updating. The api-service fetches version/developer metadata from tool-integration at runtime (5-minute TTL cache via `/scanners/health`).

---

## Upgrade Steps

### 1. Update ConfigMap (Primary Source)

```bash
vim blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml

# Update in SCANNER_METADATA JSON:
"soliditydefend": {
  "version": "X.Y.Z",
  "developer": "Apogee",
  "_note": "Updated YYYY-MM-DD, description of changes"
}

# Update image tag if Apogee scanner image was rebuilt:
SCANNER_IMAGE_SOLIDITYDEFEND: "...:0.X.0"
```

### 2. Apply and Restart tool-integration

```bash
kubectl apply -k blocksecops-tool-integration/k8s/overlays/local
kubectl rollout restart deployment/tool-integration -n tool-integration-local
kubectl rollout status deployment/tool-integration -n tool-integration-local
```

### 3. Verify

The api-service picks up the new version automatically within 5 minutes (no restart needed):

```bash
# Check tool-integration reports the new version
curl -sk https://app.0xapogee.com/api/v1/scanners \
  -H "Authorization: Bearer $TOKEN" | jq '.scanners[] | select(.id == "soliditydefend") | {id, version}'
```

---

## Notes

- Version must be in tool-integration's ConfigMap `SCANNER_METADATA` JSON (single source of truth)
- api-service reads version/developer from tool-integration `/scanners/health` at runtime — no manual ConfigMap sync needed
- Use `:latest` tag for scanner images in local development

---

## Version History

| Version | Date | Image | Notes |
|---------|------|-------|-------|
| 2.0.10 | 2026-05-23 | 0.10.0 | Restore TP recall regressions from v2.0.8-v2.0.9 FP work (reentrancy, access_control, unchecked_external_call). Rust 1.86. |
| 2.0.9 | 2026-05-06 | 0.9.10 | Foundry+OZ remappings.txt sweep (Task #179) |
| 2.0.1 | 2026-02-14 | 0.8.0 | Detectors reworked, FP reduction |
| 1.10.13 | 2026-02-03 | 0.7.0 | Project-aware scanning, cross-contract detection, 4 FP fixes |
| 1.10.3 | 2026-01-17 | 0.4.0 | Major upgrade: 333 detectors (+118), EIP-7702/1153, proxy, L2, governance |
| 1.4.0 | 2025-11-26 | — | Project mode support (Foundry/Hardhat) |
| 1.3.0 | 2025-11-03 | — | Initial platform integration |
