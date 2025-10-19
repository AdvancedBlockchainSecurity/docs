# Scanner Metadata Refactoring - ConfigMap-Based Architecture

**Date**: 2025-10-18
**Status**: Implemented
**Version**: API Service v0.1.8, Tool Integration (scanner-versions ConfigMap updated)

## Overview

Refactored the scanner metadata management system to use Kubernetes ConfigMaps as the single source of truth for scanner version and developer information, eliminating hardcoded values and ensuring production sustainability.

## Problem Statement

### Initial Issue
The dashboard displayed a hardcoded version "v1.0.0" for all scanners because:
1. Backend (`blocksecops-api-service`) had no version/developer metadata fields
2. Frontend (`blocksecops-dashboard`) provided a fallback value when metadata was missing
3. Scanner metadata (version, developer) was not exposed via the API

### Sustainability Concerns
After initial implementation with hardcoded values in Python, we identified critical production issues:
1. **Version Drift**: Hardcoded scanner tool versions could become out of sync with actual Docker images
2. **Manual Maintenance**: Every scanner update required editing Python code
3. **No Single Source of Truth**: Version info existed in multiple disconnected locations
4. **Risk of Mismatch**: Displayed versions might not reflect actual running scanners

## Solution Architecture

### ConfigMap-Based Metadata Management

Scanner metadata (version, developer) is now stored in the `scanner-versions` ConfigMap and dynamically loaded by the API service at startup.

#### Single Source of Truth
```
blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml
```

**Structure**:
```yaml
data:
  SCANNER_METADATA: |
    {
      "slither": {
        "version": "0.10.4",
        "developer": "Trail of Bits"
      },
      "aderyn": {
        "version": "0.1.0",
        "developer": "Cyfrin"
      },
      # ... all 21 scanners
    }
```

#### API Service Integration
The API service reads metadata from the `SCANNER_METADATA` environment variable:

**File**: `blocksecops-api-service/src/infrastructure/scanner_config/scanners.py`

```python
def _load_scanner_metadata_from_env() -> Dict[str, dict]:
    """Load scanner metadata from SCANNER_METADATA env var."""
    metadata_json = os.getenv("SCANNER_METADATA", "{}")
    try:
        metadata = json.loads(metadata_json)
        logger.info(f"Loaded metadata for {len(metadata)} scanners from ConfigMap")
        return metadata
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse SCANNER_METADATA env var: {e}")
        return {}

# Load at module initialization
_SCANNER_METADATA_FROM_CONFIG = _load_scanner_metadata_from_env()

class ScannerMetadata:
    def __init__(self, id, name, description, scanner_type, languages, ...):
        # ... other fields

        # Load version/developer from ConfigMap automatically
        config_metadata = _SCANNER_METADATA_FROM_CONFIG.get(id, {})
        self.version = version or config_metadata.get("version", "unknown")
        self.developer = developer or config_metadata.get("developer", "unknown")
```

## Implementation Details

### 1. ConfigMap Updates

**File**: `blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml`

- Added `SCANNER_METADATA` JSON field with all 21 scanner metadata entries
- Includes version and developer for each scanner ID
- Updated documentation in ConfigMap header

### 2. API Service Changes (v0.1.8)

**File**: `blocksecops-api-service/src/infrastructure/scanner_config/scanners.py`

Changes:
- Added JSON and environment variable loading logic
- Made `version` and `developer` optional parameters (defaults to ConfigMap values)
- Removed all hardcoded version/developer values from scanner definitions (21 scanners)
- Maintained backward compatibility with optional override parameters

**File**: `blocksecops-api-service/k8s/base/deployment.yaml`

- Added `SCANNER_METADATA` environment variable from ConfigMap

**File**: `blocksecops-api-service/k8s/overlays/local/deployment-patch.yaml`

- Updated image to `api-service:0.1.8`
- Added `SCANNER_METADATA` environment variable from ConfigMap

### 3. Scanner Metadata

All 21 production scanners now have version/developer metadata:

**Solidity (10 scanners)**:
- Slither 0.10.4 (Trail of Bits)
- Aderyn 0.1.0 (Cyfrin)
- Mythril 0.24.8 (ConsenSys)
- Semgrep 1.97.0 (Semgrep Inc)
- Solhint 5.0.3 (Protofire)
- 4naly3er 0.3.2 (Picodes)
- Halmos 0.2.2 (a16z)
- Echidna 2.2.5 (Trail of Bits)
- Manticore 0.3.8 (Trail of Bits)
- Certora 7.14.2 (Certora)

**Vyper (2 scanners)**:
- Slither-Vyper 0.10.4 (Trail of Bits)
- Moccasin 0.3.0 (Cyfrin)

**Solana/Rust (5 scanners)**:
- Sol-azy 0.2.0 (FuzzingLabs)
- Sec3 X-Ray 1.0.0 (Sec3)
- Trident 0.7.0 (Ackee Blockchain)
- Cargo Fuzz (Solana) 0.12.0 (rust-fuzz)
- Starknet Foundry 0.33.0 (Foundry)

**Move (2 scanners)**:
- Move Prover 1.0.0 (Move Language Team)
- Cargo Fuzz (Move) 0.12.0 (rust-fuzz)

**Cairo (2 scanners)**:
- Caracal 0.2.0 (Trail of Bits)
- Tayt 0.1.0 (Trail of Bits)

## Benefits

### 1. Production Sustainability
- **Single Source of Truth**: All scanner metadata in one ConfigMap
- **Easy Updates**: Update ConfigMap, redeploy API service (no code changes)
- **Version Consistency**: Versions defined alongside Docker image tags
- **Audit Trail**: Git history tracks all version changes

### 2. Operational Excellence
- **No Code Changes**: Scanner version updates don't require Python code modifications
- **Deployment Simplicity**: Update ConfigMap → Rolling deployment
- **Environment Flexibility**: Overlay-specific ConfigMaps can override versions
- **Fail-Safe Defaults**: Falls back to "unknown" if ConfigMap unavailable

### 3. Developer Experience
- **Clear Ownership**: ConfigMap location is well-documented
- **Type Safety**: JSON parsing with error handling
- **Logging**: Clear log messages when metadata loads
- **Backward Compatible**: Optional parameters allow gradual migration

## Deployment

### Build and Deploy
```bash
# 1. Apply updated ConfigMap
cd /Users/pwner/Git/ABS/blocksecops-tool-integration
kubectl apply -f k8s/base/scanner-versions-configmap.yaml

# 2. Build API service v0.1.8
cd /Users/pwner/Git/ABS/blocksecops-api-service
eval $(minikube docker-env)
docker build -t api-service:0.1.8 .

# 3. Deploy
kubectl apply -k k8s/overlays/local
kubectl rollout status deployment/api-service -n api-service-local
```

### Verification
```bash
# Check pod has SCANNER_METADATA env var
kubectl get pod -n api-service-local -l app=api-service -o jsonpath='{.items[0].spec.containers[0].env[?(@.name=="SCANNER_METADATA")]}' | jq

# Check API response includes version/developer
curl http://localhost:8000/api/v1/scanners | jq '.scanners[] | {id, version, developer}'
```

## API Changes

### GET /api/v1/scanners

**Before** (v0.1.7):
```json
{
  "scanners": [{
    "id": "slither",
    "name": "Slither",
    "type": "static_analysis",
    "languages": ["solidity"],
    // No version or developer fields
  }]
}
```

**After** (v0.1.8):
```json
{
  "scanners": [{
    "id": "slither",
    "name": "Slither",
    "type": "static_analysis",
    "languages": ["solidity"],
    "version": "0.10.4",
    "developer": "Trail of Bits",
    "estimated_time_seconds": 15,
    "requires_compilation": true,
    "is_production_ready": true,
    "confidence_level": "high"
  }]
}
```

## Frontend Impact

The dashboard automatically displays real scanner versions once API service v0.1.8 is deployed:

**File**: `blocksecops-dashboard/src/components/scanner/ScannerSelector.tsx` (line 326)

```tsx
<span className="text-xs text-gray-500">v{scanner.version}</span>
```

**Before**: Shows "v1.0.0" (hardcoded fallback)
**After**: Shows actual scanner versions (e.g., "v0.10.4", "v0.24.8")

## Future Enhancements

### Recommended Next Steps

1. **Runtime Version Validation**
   - Scanners report their actual version in callback responses
   - API service compares reported version vs ConfigMap version
   - Log warnings on mismatch for monitoring/alerts

2. **Version History Tracking**
   - Store scanner version changes in database
   - Track which scans used which scanner versions
   - Enable version-based filtering in findings analysis

3. **Automated Version Discovery**
   - Scanner containers expose version via env var or API endpoint
   - Tool-integration service discovers versions and reports to API service
   - ConfigMap becomes cache rather than source of truth

4. **Multi-Environment Support**
   - Staging environment uses different scanner versions for testing
   - Production uses stable versions from ConfigMap
   - Overlay-specific ConfigMaps enable this pattern

## Files Modified

### blocksecops-tool-integration
- `k8s/base/scanner-versions-configmap.yaml` - Added SCANNER_METADATA JSON

### blocksecops-api-service
- `src/infrastructure/scanner_config/scanners.py` - ConfigMap loading logic, removed hardcoded metadata
- `k8s/base/deployment.yaml` - Added SCANNER_METADATA env var
- `k8s/overlays/local/deployment-patch.yaml` - v0.1.8 image, SCANNER_METADATA env var

## Testing

### Manual Testing Steps
1. Deploy API service v0.1.8
2. Navigate to dashboard scanner selection modal
3. Verify scanner versions show actual tool versions (not "1.0.0")
4. Select different blockchain languages
5. Confirm version display for all scanners across all languages

### API Testing
```bash
# Get all scanners and verify metadata
curl http://localhost:8000/api/v1/scanners | jq '.scanners[] | {id, version, developer}'

# Get scanners by language
curl http://localhost:8000/api/v1/scanners?language=solidity | jq '.scanners[] | {id, version}'
```

## Rollback Plan

If issues occur:

```bash
# Revert to v0.1.7
kubectl set image deployment/api-service api-service=api-service:0.1.7 -n api-service-local

# Remove SCANNER_METADATA env var if needed
kubectl edit deployment api-service -n api-service-local
# Remove the SCANNER_METADATA env var section
```

Frontend will fall back to showing "v1.0.0" (acceptable degradation).

## Related Documentation

- `docs/SCANNER-SELECTION-FEATURE.md` - Scanner selection UI documentation
- `blocksecops-docs/deployment/scanner-docker-images.md` - Scanner Docker image management
- `docs/PLATFORM-DEVELOPMENT-STANDARDS.md` - Semantic versioning policy

## Summary

This refactoring establishes a production-grade scanner metadata management system that:
- ✅ Eliminates hardcoded scanner versions
- ✅ Provides single source of truth (ConfigMap)
- ✅ Enables easy version updates without code changes
- ✅ Maintains backward compatibility
- ✅ Supports multi-environment deployments
- ✅ Includes comprehensive logging and error handling

The system is now ready for production use with a clear update path and operational excellence.
