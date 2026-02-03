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

## 5. Verification Checklist

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
