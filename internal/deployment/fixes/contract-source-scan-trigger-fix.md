# Contract Source Scan Trigger Fix - October 13, 2025

> **Critical bug fix for 500 Internal Server Error when triggering scans with large contract source code**

## Executive Summary

**Issue**: POST requests to `/api/v1/scans` were failing with 500 Internal Server Error when triggering scans for contracts with source code, appearing as CORS errors in browser console.

**Root Cause**: Contract source code was being sent as URL query parameter instead of JSON request body. Query parameters have size limits (typically 2-8KB depending on server configuration), causing large Solidity contracts to exceed this limit and fail during request parsing.

**Impact**: Complete scan functionality failure - users unable to trigger security scans on uploaded contracts.

**Fix**: Modified `src/presentation/api/v1/endpoints/scans.py` to send contract source code in JSON request body instead of query parameters.

**Status**: ✅ Fixed in version 0.3.8, deployed October 13, 2025

---

## Problem Description

### Symptoms

**Frontend Console Errors**:
```
POST http://127.0.0.1:8000/api/v1/scans net::ERR_FAILED 500 (Internal Server Error)

Access to XMLHttpRequest has been blocked by CORS policy:
No 'Access-Control-Allow-Origin' header is present on the requested resource.
```

**Key Observations**:
1. CORS preflight (OPTIONS) requests succeeded
2. POST requests failed before reaching application code
3. No server-side logs for the failing POST requests
4. Error appeared as CORS issue but was actually a request parsing failure
5. Small contracts worked, large contracts failed

### Technical Analysis

**Query Parameter Size Limits**:
- Apache: 8KB default
- Nginx: 4KB-8KB default
- Node.js: 8KB default
- Solidity contracts: Can easily exceed 10-50KB

**Error Propagation**:
```
1. Request parser fails due to oversized query params
2. Request rejected before reaching FastAPI middleware
3. CORS middleware never executes
4. Browser receives error without CORS headers
5. Browser shows CORS error (masking the real issue)
```

---

## Root Cause

### Code Location

**File**: `src/presentation/api/v1/endpoints/scans.py`
**Lines**: 184-194
**Function**: `create_scan()`

### Original Implementation (BROKEN)

```python
# Call tool-integration service to create scanner Job with source code
response = await client.post(
    f"{TOOL_INTEGRATION_URL}/scans/{scan.id}/trigger",
    params={
        "scanner": scanner,
        "contract_source": contract_source  # ❌ WRONG: Sends large data in URL
    },
    timeout=10.0
)
```

**Why This Failed**:
- `params=` argument in `httpx.AsyncClient.post()` adds data to URL query string
- Contract source code can be 10KB-100KB+
- Query strings typically limited to 2-8KB
- Request parser rejects oversized URLs before application code runs
- CORS headers never added, causing CORS error in browser

---

## Solution

### Fixed Implementation

```python
# Call tool-integration service to create scanner Job with source code
response = await client.post(
    f"{TOOL_INTEGRATION_URL}/scans/{scan.id}/trigger",
    params={
        "scanner": scanner,  # Small metadata stays in params
    },
    json={
        "contract_source": contract_source  # ✅ CORRECT: Send large data in JSON body
    },
    timeout=10.0
)
```

**Why This Works**:
- `json=` argument sends data in HTTP request body
- HTTP request bodies have no practical size limit (server-configurable, typically 10MB+)
- Request parser handles body correctly
- CORS middleware executes normally
- Application code receives the data properly

---

## Related Changes

### 1. Contract Upload Status Improvements

**Files Modified**:
- `src/presentation/api/v1/endpoints/upload.py` (lines 179, 244)
- `src/presentation/api/v1/endpoints/contracts.py` (line 302)
- `scripts/fix-stuck-contracts.py` (line 107)

**Change**: Initial contract status changed from `"pending"` to `"uploaded"` for better UX clarity.

**Before**:
```python
contract = ContractModel(
    # ...
    status="pending",  # Ambiguous state
)
```

**After**:
```python
contract = ContractModel(
    # ...
    status="uploaded",  # Clear state after file upload
)
```

**Contract Status Lifecycle**:
```
uploaded → scanning → scanned (success)
                    → failed (error)
```

### 2. Python 3.13 Rate Limiter Compatibility

**File**: `src/presentation/api/v1/endpoints/scans.py` (lines 216-221)

**Issue**: SlowAPI rate limiter requires explicit `Response` objects in Python 3.13 due to new exception handling (`ExceptionGroup`).

**Fix**: Wrap Pydantic responses in `JSONResponse`:
```python
# Wrap response in JSONResponse for slowapi compatibility with Python 3.13
scan_response = ScanResponse.model_validate(scan)
return JSONResponse(
    status_code=status.HTTP_201_CREATED,
    content=scan_response.model_dump(mode='json')
)
```

---

## Deployment Process

### 1. Docker Image Build

**CRITICAL**: Must use `--no-cache` to ensure code changes are included.

```bash
# Set minikube Docker environment
eval $(minikube docker-env)

# Build fresh image with no cached layers
docker build --no-cache -t api-service:0.3.8 .

# Verify image was built
docker images | grep api-service
```

**Why `--no-cache` is Required**:
- Docker layer caching can preserve old source code
- Even with version tags, cached layers may contain old code
- `--no-cache` forces complete rebuild from scratch
- Adds ~2 minutes to build time but ensures correctness

### 2. Kubernetes Deployment

```bash
# Update deployment with new image version
kubectl set image deployment/api-service \
  api-service=api-service:0.3.8 \
  -n api-service-local

# Watch rollout progress
kubectl rollout status deployment/api-service -n api-service-local

# Verify pods are running new version
kubectl get pods -n api-service-local -o wide
kubectl describe pod -n api-service-local <pod-name> | grep Image
```

### 3. Port-Forward Management

**IMPORTANT**: Port-forwards die when pods restart during deployment.

```bash
# Kill existing port-forwards
lsof -ti:8000 | xargs kill -9 2>/dev/null

# Restart API port-forward
kubectl port-forward -n api-service-local svc/api-service 8000:8000 &

# Verify connection
curl http://localhost:8000/api/v1/health/live
```

### 4. Verification Testing

```bash
# Test authentication
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "password"}'

# Extract token and test scan trigger
TOKEN="<access_token_from_login>"
CONTRACT_ID="<existing_contract_id>"

curl -X POST http://localhost:8000/api/v1/scans \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"contract_id\": \"$CONTRACT_ID\"}"

# Expected: 201 Created with scan JSON response (not 500 error)
```

---

## Semantic Versioning Strategy

### Version Numbering

**Format**: `MAJOR.MINOR.PATCH` (following SemVer 2.0)

**Current Version**: 0.3.8

**Version History**:
- `0.3.4` - Last stable before bug discovery
- `0.3.5` - Attempted fix (cached layers)
- `0.3.6` - Second attempt (still cached)
- `0.3.7` - Third attempt (still cached)
- `0.3.8` - Fresh build with `--no-cache` (working)

### Image Tagging Best Practices

```bash
# ✅ CORRECT: Semantic version tags
docker build -t api-service:0.3.8 .
docker build -t api-service:0.3.8 -t api-service:latest .

# ❌ WRONG: Only using 'latest' tag
docker build -t api-service:latest .  # Caching issues, no version history
```

**Why This Matters**:
- Kubernetes caches images by tag
- `latest` tag with same SHA won't trigger pull
- Version tags provide deployment history
- Easy rollback to previous versions

### Deployment Manifest Updates

**k8s/overlays/local/api-service/deployment.yaml**:
```yaml
spec:
  template:
    spec:
      containers:
      - name: api-service
        image: api-service:0.3.8  # Use specific version, not 'latest'
        imagePullPolicy: IfNotPresent  # Cache images locally
```

---

## Lessons Learned

### 1. Query Parameter Size Limits

**Lesson**: Never send large data in URL query parameters.

**Guidelines**:
- Query params: Metadata, filters, pagination (< 1KB each)
- Request body: Large data, file content, JSON payloads
- Headers: Authentication tokens, content types
- Path params: Resource identifiers (UUIDs, IDs)

### 2. CORS Error Masking

**Lesson**: CORS errors in browser console may mask underlying server issues.

**Debugging Process**:
1. Verify CORS preflight (OPTIONS) succeeds
2. Check server logs for POST request (if missing, request never reached server)
3. Test with curl/Postman (bypasses CORS)
4. Check request size and server limits
5. Verify middleware execution order

### 3. Docker Layer Caching

**Lesson**: Docker caching can preserve old code even when files have changed.

**Best Practices**:
- Use `--no-cache` for critical fixes
- Use semantic version tags (not just `latest`)
- Verify image contents before deployment: `docker run --rm <image> ls -la /app/src`
- Document version changes in commit messages

### 4. Port-Forward Lifecycle

**Lesson**: Kubernetes port-forwards are tied to pod lifecycle, not deployment lifecycle.

**Best Practices**:
- Automate port-forward restart after deployments
- Use separate terminal tabs for port-forwards
- Monitor port-forward health: `lsof -ti:8000`
- Document required port-forwards in README

---

## Monitoring and Alerts

### Key Metrics to Monitor

**Application Metrics**:
- Scan creation success rate (should be >99%)
- Request size distribution (identify large payloads)
- HTTP 500 error rate by endpoint
- Request parsing errors

**Infrastructure Metrics**:
- API pod restart count
- Memory usage (large requests increase memory)
- Request body size limits
- Connection pool saturation

### Recommended Alerts

**Prometheus Alerts** (to be implemented):
```yaml
- alert: HighScanCreationFailureRate
  expr: |
    rate(http_requests_total{endpoint="/api/v1/scans", status="500"}[5m]) > 0.01
  for: 5m
  annotations:
    summary: "High scan creation failure rate"
    description: "Scan creation failing at {{ $value }} requests/second"

- alert: LargeRequestBodySize
  expr: |
    histogram_quantile(0.95, http_request_size_bytes{endpoint="/api/v1/scans"}) > 100000
  annotations:
    summary: "Large contract source code detected"
    description: "95th percentile request size: {{ $value }} bytes"
```

---

## Future Improvements

### Short Term (Sprint 12)

1. **Request Size Validation**:
   ```python
   @router.post("/scans")
   async def create_scan(
       request: Request,
       scan_data: ScanCreate,
       db: AsyncSession = Depends(get_db),
       current_user: UserModel = Depends(get_current_user),
   ):
       # Validate contract source size
       if len(contract.source_code) > 1_000_000:  # 1MB limit
           raise HTTPException(
               status_code=413,
               detail="Contract source code too large (max 1MB)"
           )
   ```

2. **Improved Error Messages**:
   - Add request size to error responses
   - Log query parameter usage attempts
   - Return 413 (Payload Too Large) instead of generic 500

3. **Automated Testing**:
   - Add integration test with large contract (50KB+)
   - Test query param vs body payload differences
   - Verify CORS headers on error responses

### Medium Term (Sprint 13-14)

1. **Contract Source Compression**:
   - Gzip compress contract source before sending
   - Reduces network bandwidth by 80-90%
   - Improves response times

2. **Streaming Upload**:
   - For very large contracts (>1MB)
   - Upload to S3/blob storage first
   - Send storage reference instead of inline source

3. **API Gateway**:
   - Implement rate limiting at gateway level
   - Request size validation before reaching application
   - Unified error handling and logging

---

## Testing Checklist

### Pre-Deployment Testing

- [ ] Unit tests pass (`pytest tests/unit`)
- [ ] Integration tests pass (`pytest tests/integration`)
- [ ] Docker image builds successfully
- [ ] Image contains correct code version
- [ ] Environment variables configured correctly

### Post-Deployment Testing

- [ ] Health checks pass (`/api/v1/health/live`, `/api/v1/health/ready`)
- [ ] Authentication works (login, token refresh)
- [ ] Small contract scan trigger works (<10KB)
- [ ] Large contract scan trigger works (>50KB)
- [ ] Error responses include CORS headers
- [ ] Port-forwards active and responding

### Load Testing (Optional)

```bash
# Test with multiple concurrent scan requests
for i in {1..10}; do
  curl -X POST http://localhost:8000/api/v1/scans \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"contract_id": "'$CONTRACT_ID'"}' &
done
wait

# Check for any failures
kubectl logs -n api-service-local deployment/api-service | grep ERROR
```

---

## Related Documentation

- **API Service Deployment**: `/Users/pwner/Git/ABS/blocksecops-docs/deployment/api-service-deployment.md`
- **Development Workflow**: `/Users/pwner/Git/ABS/blocksecops-docs/local-development/development-workflow.md`
- **Known Issues**: `/Users/pwner/Git/ABS/TaskDocs-Apogee/blocksecops/api/api-service-known-issues.md`
- **Sprint 8 Contract Source**: `/Users/pwner/Git/ABS/blocksecops-docs/deployment/sprint-8-contract-source-management.md`
- **Docker Standards**: `/Users/pwner/Git/ABS/blocksecops-docs/deployment/docker-image-standards.md`

---

## Change Log

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-10-13 | 1.0 | Claude Code | Initial documentation of contract source scan trigger fix |
| 2025-10-13 | 1.0 | Claude Code | Added deployment process, semantic versioning, and lessons learned |

---

**Document Status**: ✅ Active
**Next Review**: After Sprint 12 completion
**Owner**: Backend Team / DevOps
