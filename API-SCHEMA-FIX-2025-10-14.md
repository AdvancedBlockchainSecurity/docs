# API Service VulnerabilityModel Schema Fix - October 14, 2025

## Executive Summary

**Critical Bug Fixed**: VulnerabilityModel schema incompatibility preventing database storage of scan vulnerabilities
**Version**: api-service:0.3.12
**Impact**: Complete end-to-end scan integration now fully operational
**Verification**: Scan ID `f66377d9-8833-4018-9831-7733d01bb4cd` successfully stored vulnerability data

## The Problem

### Root Cause
The API service was failing to store vulnerability results received from the tool-integration service due to a schema mismatch in `/Users/pwner/Git/ABS/blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py:432`.

**Error Symptom**:
```
TypeError: 'vulnerability_type' is an invalid keyword argument for VulnerabilityModel
```

### Technical Details

The code was attempting to pass a `vulnerability_type` field to the SQLAlchemy `VulnerabilityModel`, but this field doesn't exist in the database schema:

**Broken Code (Line 432)**:
```python
vulnerability = VulnerabilityModel(
    scan_id=scan_id,
    contract_id=scan.contract_id,
    vulnerability_type=vuln_data.vulnerability_type,  # ❌ Invalid field!
    title=vuln_data.title,
    description=vuln_data.description,
    severity=vuln_data.severity,
    status="open",
    line_number=vuln_data.line_number,
    code_snippet=vuln_data.code_snippet,
    recommendation=vuln_data.recommendation,
    swc_id=None,
)
```

### Impact
- Tool-integration service could trigger scans successfully
- Slither scanner would run and detect vulnerabilities
- Tool-integration would POST results to API service
- **API service would fail with HTTP 500 when storing vulnerabilities**
- Database remained empty despite successful scan execution

## The Fix

### Code Change
Removed the invalid `vulnerability_type` parameter from the VulnerabilityModel instantiation:

```python
vulnerability = VulnerabilityModel(
    scan_id=scan_id,
    contract_id=scan.contract_id,
    # ✅ Removed: vulnerability_type=vuln_data.vulnerability_type
    title=vuln_data.title,
    description=vuln_data.description,
    severity=vuln_data.severity,
    status="open",
    line_number=vuln_data.line_number,
    code_snippet=vuln_data.code_snippet,
    recommendation=vuln_data.recommendation,
    swc_id=None,
)
```

### Deployment Steps

#### 1. Build Docker Image
```bash
cd /Users/pwner/Git/ABS/blocksecops-api-service
eval $(minikube docker-env)
docker build -t api-service:0.3.12 .
```

**Build Result**: ✅ Success in 45.3s

#### 2. Update Kustomization Configuration

**File**: `k8s/overlays/local/kustomization.yaml`

Changes:
- Updated image tag: `newTag: 0.3.12`
- Updated version label: `app.kubernetes.io/version: 0.3.12`

#### 3. Configuration Fixes Required

During deployment, discovered and fixed multiple configuration issues:

**a) Missing ConfigMap Key**
- **Issue**: Pod failing with `CreateContainerConfigError` - missing `debug` key
- **File**: `k8s/overlays/local/configmap-patch.yaml`
- **Fix**: Added `debug: "true"` to ConfigMap data section

**b) Image Version Not Updating**
- **Issue**: Pod deployed with old image `api-service:0.3.4` instead of `0.3.12`
- **File**: `k8s/overlays/local/deployment-patch.yaml`
- **Fix**: Added explicit image reference:
  ```yaml
  spec:
    template:
      spec:
        containers:
        - name: api-service
          image: api-service:0.3.12
  ```

**c) Immutable Selector Conflict**
- **Issue**: Couldn't update deployment due to immutable selector field
- **Fix**: Deleted old deployment and recreated:
  ```bash
  kubectl delete deployment api-service -n api-service-local
  kubectl apply -k k8s/overlays/local
  ```

#### 4. Deploy to Kubernetes
```bash
kubectl apply -k k8s/overlays/local
kubectl rollout status deployment/api-service -n api-service-local
```

**Deployment Result**: ✅ Successfully deployed and running

## End-to-End Verification

### Test Methodology
1. Authenticated with API service (cookie-based session auth)
2. Created contract via API
3. Triggered scan via API service endpoint
4. Monitored scan execution and completion
5. Verified vulnerability storage in database via API

### Test Results

**Scan ID**: `f66377d9-8833-4018-9831-7733d01bb4cd`

#### Scan Execution
```json
{
  "id": "f66377d9-8833-4018-9831-7733d01bb4cd",
  "contract_id": "c0cf7e72-bbd5-43e6-ae26-76e7ccfb89fc",
  "status": "pending",
  "created_at": "2025-10-14T..."
}
```

**Duration**: ~40 seconds from creation to completion

#### Vulnerability Stored Successfully ✅

```json
{
  "id": "77f47a07-a3f6-4e50-8e4f-92db92a5a3f5",
  "scan_id": "f66377d9-8833-4018-9831-7733d01bb4cd",
  "title": "Reentrancy Attack (Ether)",
  "description": "The contract is vulnerable to reentrancy attacks...",
  "severity": "CRITICAL",
  "line_number": 11,
  "code_snippet": "function withdraw() public {\n    uint256 amount = balances[msg.sender];...",
  "recommendation": "Apply checks-effects-interactions pattern. Update state before external calls...",
  "status": "open",
  "created_at": "2025-10-14T...",
  "updated_at": "2025-10-14T..."
}
```

#### Scan Statistics Updated ✅
- Total vulnerabilities: 1
- Critical count: 1
- High count: 0
- Medium count: 0
- Low count: 0

### Complete Integration Flow Validated

```
User/Dashboard
    ↓
API Service: POST /api/v1/scans
    ↓
Tool Integration: POST /scans/trigger
    ↓
Kubernetes Job: Slither Scanner
    ↓ (scan execution ~35 seconds)
Slither: Detect vulnerabilities
    ↓
Tool Integration: Receive results
    ↓
API Service: POST /scans/{id}/results
    ↓
✅ PostgreSQL Database: Vulnerabilities stored
    ↓
API Service: GET /scans/{id}/vulnerabilities
    ↓
User/Dashboard: View results
```

## Files Modified

### Source Code
- `/Users/pwner/Git/ABS/blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py` (line 432)

### Kubernetes Configuration
- `/Users/pwner/Git/ABS/blocksecops-api-service/k8s/overlays/local/kustomization.yaml`
- `/Users/pwner/Git/ABS/blocksecops-api-service/k8s/overlays/local/configmap-patch.yaml`
- `/Users/pwner/Git/ABS/blocksecops-api-service/k8s/overlays/local/deployment-patch.yaml`

### Documentation
- `/Users/pwner/Git/ABS/blocksecops-docs/deployment/api-service-deployment.md` (Section 4 added, change log updated)
- `/Users/pwner/Git/ABS/docs/API-SCHEMA-FIX-2025-10-14.md` (this document)

## Related Work

### Previous Fixes (October 13-14, 2025)
- **v0.3.8**: Fixed scan trigger to accept contract source in request body
- **v0.3.11**: Fixed contract enum validation for contract types
- **v0.1.2** (notification-service): Fixed CrashLoopBackOff due to missing SECRET_KEY

See:
- `/Users/pwner/Git/ABS/docs/WORK-SUMMARY-2025-10-13.md`
- `/Users/pwner/Git/ABS/docs/FIXES-SUMMARY-2025-10-14.md`

## Deployment Commands Reference

### Build and Deploy
```bash
# Set minikube docker environment
eval $(minikube docker-env)

# Build Docker image
cd /Users/pwner/Git/ABS/blocksecops-api-service
docker build -t api-service:0.3.12 .

# Deploy to Kubernetes
kubectl apply -k k8s/overlays/local

# Monitor deployment
kubectl rollout status deployment/api-service -n api-service-local
kubectl get pods -n api-service-local
kubectl logs -n api-service-local deployment/api-service --tail=50
```

### Port Forwarding for Testing
```bash
# API Service
kubectl port-forward -n api-service-local svc/api-service 8000:8000

# PostgreSQL (for direct database access)
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432
```

### Verify Deployment
```bash
# Check pod status
kubectl get pods -n api-service-local

# Verify image version
kubectl get deployment api-service -n api-service-local -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check application logs
kubectl logs -n api-service-local deployment/api-service --tail=100
```

## Testing Commands

### API Authentication
```bash
# Login and save cookies
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"admin123"}' \
  -c /tmp/cookies.txt

# Use cookies for authenticated requests
curl -X GET http://localhost:8000/api/v1/scans \
  -b /tmp/cookies.txt
```

### Create and Test Scan
```bash
# Create contract (returns contract_id)
curl -X POST http://localhost:8000/api/v1/contracts \
  -H "Content-Type: application/json" \
  -b /tmp/cookies.txt \
  -d '{
    "name": "TestContract",
    "source_code": "pragma solidity ^0.8.0; contract Test { ... }",
    "compiler_version": "0.8.0",
    "contract_type": "token"
  }'

# Trigger scan
curl -X POST http://localhost:8000/api/v1/scans \
  -H "Content-Type: application/json" \
  -b /tmp/cookies.txt \
  -d '{"contract_id": "CONTRACT_ID_HERE"}'

# Check scan status
curl -X GET http://localhost:8000/api/v1/scans/SCAN_ID \
  -b /tmp/cookies.txt

# Get vulnerabilities
curl -X GET http://localhost:8000/api/v1/scans/SCAN_ID/vulnerabilities \
  -b /tmp/cookies.txt
```

## Status

- **Bug Status**: ✅ FIXED
- **Version**: v0.3.12
- **Deployed**: October 14, 2025
- **Verified**: End-to-end scan integration working
- **Next Steps**: Monitor production usage, consider additional integration tests

## Key Takeaways

1. **Schema Validation is Critical**: Mismatch between Pydantic schemas and SQLAlchemy models can silently break functionality
2. **End-to-End Testing Required**: Component-level testing missed this integration issue
3. **Configuration Management**: Kustomize overlays require careful attention to ensure all references are correct
4. **Explicit Image References**: When kustomization image transformations aren't working, explicit image references in patches are effective
5. **Documentation is Essential**: Comprehensive documentation of fixes helps prevent regression and aids troubleshooting

## Contact

For questions about this fix or related integration issues:
- See: `/Users/pwner/Git/ABS/blocksecops-docs/deployment/api-service-deployment.md`
- Architecture: `/Users/pwner/Git/ABS/blocksecops-docs/architecture/`
