# Security Configuration Playbook

This playbook describes how to configure security settings for BlockSecOps deployments.

## Overview

The January-February 2026 security audit introduced mandatory security configurations that must be properly set for production deployments. This playbook covers:

- Circuit breaker configuration
- Archive extraction security
- Celery task security
- N+1 query prevention

---

## 1. Circuit Breaker Configuration

### Overview

Circuit breakers protect against cascade failures when external APIs (embeddings, CVE lookup) are unavailable.

### Configuration

```bash
# Circuit breaker settings (defaults are production-ready)
CIRCUIT_BREAKER_FAILURE_THRESHOLD=5      # Open after 5 consecutive failures
CIRCUIT_BREAKER_RECOVERY_TIMEOUT=30      # Seconds before half-open
CIRCUIT_BREAKER_HALF_OPEN_MAX_CALLS=3    # Test calls before closing

# Retry settings with exponential backoff
RETRY_MAX_RETRIES=3                       # Maximum retry attempts
RETRY_BASE_DELAY=1.0                      # Initial delay (seconds)
RETRY_MAX_DELAY=30.0                      # Maximum delay cap (seconds)
RETRY_JITTER_FACTOR=0.5                   # +/-50% jitter to prevent thundering herd
```

### Security Requirements

| Tag | Requirement |
|-----|-------------|
| BSO-SEC-RES-001 | Sanitize all error messages before logging |
| BSO-SEC-RES-002 | No sensitive data in logs (URLs, API keys redacted) |
| BSO-SEC-RES-003 | Graceful degradation returns safe defaults |
| BSO-SEC-RES-004 | Jitter prevents synchronized retries |

### Verification

```bash
# Check circuit breaker state via metrics
curl http://localhost:8000/internal/metrics | grep circuit_breaker

# Simulate external API failure
# Watch logs for: "Circuit opened for embedding_service"
```

---

## 2. Archive Extraction Security

### Overview

Protects against malicious archive uploads: path traversal, zip bombs, symlink attacks.

### Configuration

```bash
# Archive extraction limits
ARCHIVE_MAX_COMPRESSION_RATIO=100        # Max 100:1 compression ratio
ARCHIVE_MAX_SINGLE_FILE_SIZE=10485760    # 10MB per file
ARCHIVE_STREAMING_CHUNK_SIZE=65536       # 64KB streaming chunks
```

### Security Requirements

| CWE | Attack | Protection |
|-----|--------|------------|
| CWE-22 | Path traversal (`../../../etc/passwd`) | Path resolution validation |
| CWE-61 | Symlink attacks | Reject symlinks/hardlinks in TAR |
| CWE-78 | Null byte injection | Check for `\x00` in paths |
| CWE-409 | Zip bombs | Check compression ratio before extraction |
| CWE-362 | Temp file race conditions | Cryptographically random directory names |

### Verification

```bash
# Test path traversal protection
echo "test" > /tmp/test.txt
cd /tmp && zip -r test.zip ../etc/passwd 2>/dev/null || echo "Blocked!"

# Check secure temp directories are being used
ls /tmp/blocksecops-* 2>/dev/null || echo "Secure cleanup working"
```

---

## 3. Celery Task Security (ML Operations)

### Overview

ML model retraining runs as Celery tasks with strict security controls.

### Configuration

```bash
# Celery settings (in orchestration service)
CELERY_TASK_SERIALIZER=json              # JSON only (no pickle!)
CELERY_ACCEPT_CONTENT=["json"]           # Reject all other serializers
CELERY_TASK_TIME_LIMIT=1800              # 30 min hard limit
CELERY_TASK_SOFT_TIME_LIMIT=1700         # 28 min soft limit
```

### Internal Service Authentication

```bash
# Required for API -> Orchestration communication
ORCHESTRATION_URL=http://orchestration:8080
INTERNAL_SERVICE_KEY=<shared-secret>
```

### Allowed Model Names

Only these model names are accepted (whitelist):
- `fp_classifier` - False positive classifier
- `severity_predictor` - Severity prediction model

### Verification

```bash
# Check task queue health
celery -A blocksecops_orchestration.core.celery_app inspect active

# Test model retrain task
curl -X POST http://localhost:8080/internal/tasks/ml/retrain \
  -H "X-Internal-Service-Key: $INTERNAL_SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model_name": "fp_classifier", "triggered_by": "manual", "request_id": "test-123"}'
```

---

## 4. N+1 Query Prevention

### Overview

Database queries must be optimized to prevent N+1 patterns and ensure authorization happens at SQL level.

### Requirements

| Tag | Requirement |
|-----|-------------|
| BSO-SEC-015 | Authorization in SQL WHERE clause |
| BSO-PERF-001 | Batch fetching for related data |

### Pattern

```python
# WRONG: Authorization in Python (N+1 pattern)
entities = db.query(Entity).all()
authorized = [e for e in entities if e.owner_id == user_id]  # BAD

# RIGHT: Authorization in SQL WHERE
entities = db.query(Entity).filter(
    Entity.owner_id == user_id
).all()  # GOOD
```

### Verification

```python
# Use SQLAlchemy query logging to count queries
# Should be O(1) queries regardless of result count
```

---

## 5. API Security Controls (v0.28.1)

### Overview

The February 2026 API security audit added the following mandatory controls.

### Error Message Sanitization

All HTTP error responses must use `get_safe_error_detail()` instead of `str(e)`:

```python
from src.infrastructure.security.error_sanitizer import get_safe_error_detail

# WRONG: Leaks internal details
raise HTTPException(status_code=500, detail=str(e))

# RIGHT: Returns generic message
raise HTTPException(status_code=500, detail=get_safe_error_detail(e, "operation name"))
```

### SSRF Validation on Webhook URLs

All webhook URL inputs must be validated with `SSRFValidator`:

```python
from src.infrastructure.security.url_validation import validate_webhook_url

# Applied via Pydantic field_validator on create AND update schemas
@field_validator('webhook_url')
def validate_url(cls, v):
    validate_webhook_url(str(v))
    return v
```

### AI/ML Tier Gating

All AI/ML endpoints require `team` tier or higher:

```python
router = APIRouter(
    dependencies=[Depends(require_tier("team"))]
)
```

Applies to: copilot, code_review, code_repair, ml endpoints.

### Model Signing

ML models loaded via `joblib.load()` must be signed with HMAC-SHA256:

```python
from src.ml.storage.model_signing import ModelSigner

signer = ModelSigner(secret_key)
signer.verify_and_load(model_path)  # Raises if signature invalid
```

### Rate Limit Key Function

Rate limiting must use trusted proxy validation, not raw `X-Forwarded-For`:

```python
# Uses _get_client_ip_for_rate_limit() which validates trusted proxies
# before extracting client IP from XFF header
```

---

## 6. CORS Configuration (v0.29.4)

### Overview

As of v0.29.4, CORS is handled exclusively by FastAPI CORSMiddleware. Traefik CORS middleware files were removed to eliminate duplicate `Access-Control-*` headers.

### Configuration

CORS origins are configured via ConfigMap environment variables (not hardcoded):

```yaml
# k8s/overlays/local/api-service/configmap-patch.yaml
cors_origins: "https://app.blocksecops.local"
```

FastAPI CORSMiddleware settings in `src/main.py`:

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Request-ID",
                   "X-API-Key", "X-Organization-Id", "Accept", "Origin"],
    expose_headers=["X-Request-ID"],
    max_age=3600,  # 1 hour preflight cache
)
```

### Key Points

- **No Traefik CORS middleware** - `middleware-cors.yaml` files were deleted from both api-service and dashboard overlays
- **No GCP backend CORS headers** - `customResponseHeaders` removed from `backend-config-api.yaml`
- **max_age=3600** - Reduces preflight requests (browsers cache OPTIONS response for 1 hour)
- **Single CORS header set** - `Access-Control-Allow-Origin` must appear exactly once in responses

### Verification

```bash
# Verify CORS headers (should show single set from FastAPI)
curl -sk -X OPTIONS https://app.blocksecops.local/api/v1/contracts \
  -H "Origin: https://app.blocksecops.local" \
  -H "Access-Control-Request-Method: POST" \
  -D - -o /dev/null 2>&1 | grep -i "access-control"

# Verify max-age
curl -sk -X OPTIONS https://app.blocksecops.local/api/v1/contracts \
  -H "Origin: https://app.blocksecops.local" \
  -H "Access-Control-Request-Method: POST" \
  -D - -o /dev/null 2>&1 | grep -i "max-age"
# Expected: access-control-max-age: 3600
```

---

## 7. JWKS Cache TTL (v0.29.4)

### Overview

JWKS (JSON Web Key Set) keys used for Supabase JWT verification are cached with a 1-hour TTL. Previously, `@lru_cache` was used with no TTL, meaning keys were cached indefinitely until service restart.

### Configuration

No environment variables needed. The TTL is set in code:

```python
JWKS_CACHE_TTL = 3600  # 1 hour
```

Applies to both:
- `src/infrastructure/auth/supabase_client.py` (customer auth)
- `src/infrastructure/auth/admin_supabase_client.py` (admin auth)

### Behavior

- JWKS keys are fetched from Supabase on first request
- Subsequent requests use cached keys for up to 1 hour
- After TTL expires, next request fetches fresh keys from Supabase
- If Supabase rotates keys, they will be picked up within 1 hour automatically

### Verification

```bash
# Check service starts and authenticates correctly
curl -sk https://app.blocksecops.local/api/v1/health/ready
# Expected: {"status": "healthy", ...}

# Verify authenticated requests work
curl -sk -H "Authorization: Bearer $TOKEN" \
  https://app.blocksecops.local/api/v1/users/me
# Expected: 200 with user data (not 401)
```

---

## 8. Verification Checklist

### Pre-Deployment

- [ ] All secrets generated with cryptographic randomness
- [ ] No default/insecure values in production config
- [ ] Redis accessible from all API replicas
- [ ] Circuit breaker configured for external APIs
- [ ] Archive extraction limits configured
- [ ] Celery using JSON serialization only
- [ ] Internal service key shared between API and orchestration

### Post-Deployment

```bash
# Check configuration validation passed
kubectl logs -n api-service-local deployment/api-service | grep -i "config\|secret\|warning"

# Verify health endpoints
curl -sk https://app.blocksecops.local/api/v1/health/live
curl -sk https://app.blocksecops.local/api/v1/health/ready
```

---

## Related Documentation

- [Security Testing Guide](../feature-tests/54-security-testing.md)
- [Security Standards](../standards/security-standards.md)
- [API Security Audit Report](../audits/2026-02-07_API_Security_Audit.md)
