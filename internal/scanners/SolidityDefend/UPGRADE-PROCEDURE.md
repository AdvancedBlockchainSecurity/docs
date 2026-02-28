# SolidityDefend Upgrade Procedure

## Quick Reference

### Files to Update

1. **ConfigMap** (single source of truth):
   - `blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml`
   - `api-service-local` namespace ConfigMap

2. **API Service** (if hardcoded version exists):
   - `blocksecops-api-service/src/infrastructure/scanner_config/scanners.py`

---

## Upgrade Steps

### 1. Update ConfigMap (Primary Source)

```bash
# Edit the tool-integration ConfigMap
vim /Users/pwner/Git/ABS/blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml

# Update in SCANNER_METADATA JSON:
"soliditydefend": {
  "version": "X.Y.Z",
  "developer": "Apogee",
  "_note": "Updated YYYY-MM-DD, description of changes"
}
```

### 2. Update api-service-local ConfigMap

```bash
# Get current ConfigMap
kubectl get configmap scanner-versions -n api-service-local -o yaml > /tmp/cm.yaml

# Edit and update soliditydefend version in SCANNER_METADATA
vim /tmp/cm.yaml

# Apply updated ConfigMap
kubectl apply -f /tmp/cm.yaml
```

### 3. Apply tool-integration ConfigMap

```bash
kubectl apply -k /Users/pwner/Git/ABS/blocksecops-tool-integration/k8s/overlays/local
```

### 4. Restart API Service

```bash
kubectl rollout restart deployment/api-service -n api-service-local
kubectl rollout status deployment/api-service -n api-service-local
```

### 5. Verify

```bash
kubectl exec -n api-service-local deployment/api-service -- python -c "
from infrastructure.scanner_config.scanners import SCANNERS
print(f'SolidityDefend: {SCANNERS[\"soliditydefend\"].version}')
"
```

---

## Notes

- Version must be in ConfigMap `SCANNER_METADATA` JSON (single source of truth)
- Do NOT hardcode version in `scanners.py` - it should load from ConfigMap
- Use `:latest` tag for scanner images in local development
- If `scanners.py` has hardcoded version, rebuild Docker image after removing it

---

## Version History

| Version | Date | Notes |
|---------|------|-------|
| 1.10.13 | 2026-02-03 | Project-aware scanning, cross-contract detection, 4 FP fixes (pool-donation, uups, proxy-storage, token-supply) |
| 1.10.3 | 2026-01-17 | Major upgrade: 333 detectors (+118), EIP-7702/1153, proxy, L2, governance, noise reduction |
| 1.4.0 | 2025-11-26 | Project mode support (Foundry/Hardhat) |
| 1.3.7 | 2025-11-15 | Bug fixes |
| 1.3.0 | 2025-11-03 | Initial platform integration |
