# FIX-BSO-SEC-004: Unauthenticated Scan Endpoints

**Date Fixed:** January 31, 2026
**Severity:** HIGH
**Status:** Fixed
**Audit Area:** API (API Security)

Follow standards for codebase, kustomize, image, database, ports and versioning docs/standards

---

## Issue Description

Certain internal scan-related API endpoints were accessible without authentication. These endpoints are intended for service-to-service communication (tool-integration -> api-service) but could be abused by external attackers:

```python
# BEFORE (VULNERABLE) - No authentication
@router.post("/batch/{batch_id}/update-status")
async def update_batch_status(batch_id: UUID, db: AsyncSession = Depends(get_db)):
    ...

@router.get("/{scan_id}/check-results")
async def check_scan_has_results(scan_id: UUID, db: AsyncSession = Depends(get_db)):
    ...

@router.post("/{scan_id}/results")
async def store_scan_results(scan_id: UUID, results: ScanResults, db: AsyncSession = Depends(get_db)):
    ...

@router.post("/{scan_id}/fuzzing-results")
async def store_fuzzing_results(scan_id: UUID, request: Request, db: AsyncSession = Depends(get_db)):
    ...
```

## Root Cause

Internal endpoints were designed for trusted service-to-service calls without considering network boundary security. No authentication mechanism was implemented for these internal calls.

## Impact

- **Resource exhaustion** via unauthorized scan result submissions
- **Data manipulation** by injecting false vulnerability data
- **Batch status manipulation** affecting scan workflow
- **Audit log poisoning** with fake scan completions

## Fix Applied

### 1. Added Internal Service Key Configuration

```python
# src/infrastructure/config.py
internal_service_key: str = Field(
    default="",
    description="API key for internal service-to-service calls. REQUIRED in production."
)

# Production validation ensures key is set
if not self.internal_service_key or self.internal_service_key.lower() in _INSECURE_SECRET_VALUES:
    if is_production:
        errors.append(
            "INTERNAL_SERVICE_KEY must be set to a secure value in production..."
        )
```

### 2. Created Internal Service Authentication Module

New file: `src/infrastructure/auth/internal_service_auth.py`

```python
async def verify_internal_service(
    request: Request,
    x_internal_service_key: Optional[str] = Header(None, alias="X-Internal-Service-Key"),
) -> None:
    """Verify request is from an authorized internal service."""
    settings = get_settings()

    if not settings.internal_service_key:
        if is_production:
            raise HTTPException(status_code=503, detail="Internal service auth not configured")
        return  # Allow in development with warning

    if not x_internal_service_key:
        raise HTTPException(status_code=401, detail="X-Internal-Service-Key header required")

    # Constant-time comparison to prevent timing attacks
    if not secrets.compare_digest(x_internal_service_key, settings.internal_service_key):
        raise HTTPException(status_code=401, detail="Invalid internal service key")
```

### 3. Applied Authentication to Internal Endpoints

```python
# AFTER (FIXED)
@router.post("/batch/{batch_id}/update-status")
async def update_batch_status(
    batch_id: UUID,
    _: None = Depends(verify_internal_service),  # Added authentication
    db: AsyncSession = Depends(get_db),
):
    ...
```

## Files Modified

| File | Change |
|------|--------|
| `src/infrastructure/config.py` | Added `internal_service_key` field and validation |
| `src/infrastructure/auth/internal_service_auth.py` | New file - internal service authentication |
| `src/presentation/api/v1/endpoints/scans.py` | Added `verify_internal_service` dependency to 4 endpoints |
| `.env.example` | Added INTERNAL_SERVICE_KEY documentation |

## Verification

### Test 1: Unauthenticated Request Blocked (Production Mode)

```bash
# Set production environment
ENVIRONMENT=production INTERNAL_SERVICE_KEY="test-key-12345"

# Request without header should fail
curl -X POST http://localhost:8000/api/v1/scans/batch/123/update-status
# Expected: 401 Unauthorized - "X-Internal-Service-Key header required"
```

### Test 2: Invalid Key Rejected

```bash
curl -X POST http://localhost:8000/api/v1/scans/batch/123/update-status \
  -H "X-Internal-Service-Key: wrong-key"
# Expected: 401 Unauthorized - "Invalid internal service key"
```

### Test 3: Valid Key Accepted

```bash
curl -X POST http://localhost:8000/api/v1/scans/batch/123/update-status \
  -H "X-Internal-Service-Key: test-key-12345"
# Expected: 404 Not Found (batch doesn't exist) or 200 OK
```

### Test 4: Development Mode Allows Without Key (Warning Logged)

```bash
ENVIRONMENT=local INTERNAL_SERVICE_KEY=""

curl -X POST http://localhost:8000/api/v1/scans/batch/123/update-status
# Expected: Request proceeds (with warning logged)
```

## Service Configuration Required

Tool-integration and orchestration services must be configured with the same key:

```bash
# All calling services need this environment variable
INTERNAL_SERVICE_KEY="<same-key-as-api-service>"
```

### Kubernetes ConfigMap/Secret

```yaml
# External Secret or ConfigMap
apiVersion: v1
kind: Secret
metadata:
  name: internal-service-auth
type: Opaque
data:
  INTERNAL_SERVICE_KEY: <base64-encoded-key>
```

## Defense in Depth

This fix is part of a defense-in-depth strategy:

1. **Network Policies** (Kubernetes) - Restrict pod-to-pod traffic
2. **Service Authentication** (This fix) - Validate caller identity with shared secret
3. **Request Logging** - Audit trail for all internal calls

## Endpoints Protected

| Endpoint | Purpose |
|----------|---------|
| `POST /batch/{batch_id}/update-status` | Update batch scan status |
| `GET /{scan_id}/check-results` | Check if scan has results |
| `POST /{scan_id}/results` | Store scan vulnerability results |
| `POST /{scan_id}/fuzzing-results` | Store fuzzing test results |

## Prevention

- All internal endpoints must use `verify_internal_service` dependency
- Production validation enforces key configuration
- Code review checklist includes internal endpoint authentication check
- Network policies should complement authentication
