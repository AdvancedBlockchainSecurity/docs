# Security Configuration Playbook

This playbook describes how to configure security settings for Apogee deployments.

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

All AI/ML endpoints require `starter` tier or higher:

```python
router = APIRouter(
    dependencies=[Depends(require_tier("starter"))]
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

## 6. CORS Configuration (v0.29.4+)

### Overview

As of v0.29.4, CORS is handled exclusively by FastAPI CORSMiddleware. Traefik CORS middleware files were removed to eliminate duplicate `Access-Control-*` headers.

### Configuration

CORS origins are configured via ConfigMap environment variables (not hardcoded):

```yaml
# k8s/overlays/local/api-service/configmap-patch.yaml
cors_origins: "https://app.0xapogee.com"
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
curl -sk -X OPTIONS https://app.0xapogee.com/api/v1/contracts \
  -H "Origin: https://app.0xapogee.com" \
  -H "Access-Control-Request-Method: POST" \
  -D - -o /dev/null 2>&1 | grep -i "access-control"

# Verify max-age
curl -sk -X OPTIONS https://app.0xapogee.com/api/v1/contracts \
  -H "Origin: https://app.0xapogee.com" \
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
curl -sk https://app.0xapogee.com/api/v1/health/ready
# Expected: {"status": "healthy", ...}

# Verify authenticated requests work
curl -sk -H "Authorization: Bearer $TOKEN" \
  https://app.0xapogee.com/api/v1/users/me
# Expected: 200 with user data (not 401)
```

---

## 8. Rate Limiting Coverage (v0.29.5)

### Overview

As of v0.29.5, all non-exempt API endpoint files have rate limiting decorators. Rate limits are enforced by slowapi and configured via the centralized tier configuration (`tiers.json`).

### Coverage Summary

| Version | Files Added | Total Files | Total Endpoints |
|---------|-------------|-------------|-----------------|
| Pre-audit | 15 (write/mutation) | 15 | ~50 |
| v0.29.4 | 27 (read/search/CRUD) | 42 | ~170 |
| v0.29.5 | 10 (remaining) | 52 | ~225+ |
| v0.29.33 | 8 (admin endpoints) | 60 | ~275+ |

### v0.29.5 Additions

The following 10 files were rate-limited in v0.29.5:

- `economic_analysis.py` (5 endpoints)
- `contract_structure.py` (5 endpoints)
- `service_accounts.py` (7 endpoints)
- `invites.py` (5 endpoints - public endpoints use fixed 10/min)
- `project_access.py` (7 endpoints)
- `copilot.py` (9 endpoints)
- `ml.py` (25 endpoints)
- `roles.py` (1 endpoint)
- `scanners.py` (4 endpoints)
- `ide_integrations.py` (8 endpoints)

### Exempt Endpoints

| File | Reason |
|------|--------|
| `health.py` | Kubernetes probes must remain unthrottled |
| `websocket.py` | WebSocket connections, not HTTP |
| `monitoring.py` | Internal monitoring |
| `stripe_webhook.py` | Stripe signature-verified |

### Verification

```bash
# Verify rate limit headers present on authenticated requests
curl -sk -v \
  -H "Authorization: Bearer $TOKEN" \
  "https://app.0xapogee.com/api/v1/contracts" \
  2>&1 | grep -i "x-ratelimit"
# Expected: X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset
```

See [Adjust Rate Limits](adjust-rate-limits.md) for modifying rate limit values.

---

## 9. Postgres Exporter Configuration

### Overview

The postgres-exporter (`prometheuscommunity/postgres-exporter:v0.15.0`) provides PostgreSQL metrics to Prometheus via port 9187.

### Configuration

The exporter connects using the `DATA_SOURCE_NAME` environment variable:

```
postgresql://blocksecops:blocksecops-local-password@postgresql:5432/solidity_security?sslmode=require
```

### Key Requirements

| Setting | Value | Why |
|---------|-------|-----|
| User | `blocksecops` | The `postgres` role does not exist; all access uses `blocksecops` |
| SSL Mode | `require` | `pg_hba.conf` enforces `hostssl` for all cluster connections; `hostnossl` is rejected |
| Database | `solidity_security` | Production database name (not `blocksecops`) |

### File Location

```
blocksecops-gcp-infrastructure/k8s/overlays/local/postgresql/postgres-exporter.yaml
```

### Verification

```bash
# Check pg_up metric (should be 1)
kubectl exec -n postgresql-local deploy/postgres-exporter -- \
  wget -qO- http://localhost:9187/metrics | grep "^pg_up"
# Expected: pg_up 1
```

### History

- **Pre-Feb 26, 2026**: Configured with `postgres:postgres` and `sslmode=disable` — `pg_up=0` since Feb 21
- **Feb 26, 2026**: Fixed to `blocksecops` user with `sslmode=require` (gcp-infrastructure PR #23)

---

## 10. Encryption Key Configuration (v0.29.37+)

### Overview

The `INTEGRATION_ENCRYPTION_KEY` is used by the EncryptionService (Fernet) to encrypt OAuth tokens, MFA secrets, and webhook signing secrets. An invalid key silently disables encryption, causing MFA and OAuth failures.

### Configuration

```bash
# Generate a valid Fernet key (must decode to exactly 32 bytes)
python3 -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())'

# Store in Vault
vault kv put secret/local/api-service/encryption key=<generated-key>
```

### Startup Validation

| Environment | Behavior |
|---|---|
| production, staging | **Fails startup** if key is empty, invalid base64, or != 32 bytes decoded |
| local, test | Allows empty key (encryption disabled with log warning) |

### Health Check

The readiness endpoint includes encryption status:

```bash
curl -sk https://app.0xapogee.com/api/v1/health/ready | python3 -c "
import sys,json; d=json.load(sys.stdin)
print('Encryption:', 'configured' if d['checks'].get('encryption_configured') else 'NOT configured')"
```

### Known Bad Keys

| Key | Issue |
|---|---|
| `bG9jYWwtZGV2LWVuY3J5cHRpb24ta2V5LWNoYW5nZS1pbi1wcm9kdWN0aW9u` | Decodes to 45 bytes (not 32). Was the default placeholder that caused the Feb 2026 MFA outage. |

### Verification

```bash
# Confirm encryption is active
curl -sk https://app.0xapogee.com/api/v1/health/ready | grep encryption_configured
# Expected: "encryption_configured": true

# Check startup logs for encryption errors
kubectl logs -n api-service-local deployment/api-service | grep -i "encryption"
```

---

## 11. Resource Limits (v0.29.37+)

### Overview

All pods MUST have resource limits set. Unbounded pods (especially registries and databases) can consume all node memory via kernel page cache.

### Harbor Registry

Harbor was found using 8.9GB memory (page cache from 134GB of image blobs). Resource limits now set via Helm values:

```bash
helm upgrade harbor harbor -n harbor-local --repo https://helm.goharbor.io --reuse-values \
  --set registry.registry.resources.limits.memory=2Gi \
  --set core.resources.limits.memory=512Mi \
  --set database.internal.resources.limits.memory=1Gi \
  --set jobservice.resources.limits.memory=512Mi \
  --set redis.internal.resources.limits.memory=256Mi \
  --set portal.resources.limits.memory=256Mi \
  --set trivy.resources.limits.memory=1Gi
```

### Monitoring Stack

Prometheus and prometheus-adapter must NOT be scaled to 0. A PodDisruptionBudget with `minAvailable: 1` is recommended.

---

## 12. Verification Checklist

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
curl -sk https://app.0xapogee.com/api/v1/health/live
curl -sk https://app.0xapogee.com/api/v1/health/ready
```

---

## Related Documentation

- [Security Testing Guide](../feature-tests/54-security-testing.md)
- [Security Standards](../standards/security-standards.md)
- [API Security Audit Report](../audits/2026-02-07_API_Security_Audit.md)
