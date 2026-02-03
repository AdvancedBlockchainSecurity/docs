# Security Standards

**Version:** 2.0.0
**Last Updated:** February 2, 2026

## Overview

This document defines security standards for BlockSecOps platform development, covering circuit breakers, archive extraction, query patterns, and task security.

---

## 1. Circuit Breakers (External API Resilience)

### Pattern: Circuit Breaker

All external API calls MUST use circuit breakers to prevent cascade failures.

```python
from src.infrastructure.resilience import CircuitBreaker, CircuitBreakerConfig

config = CircuitBreakerConfig(
    failure_threshold=5,      # BSO-SEC-RES-001
    recovery_timeout=30.0,    # seconds
    half_open_max_calls=3
)

breaker = CircuitBreaker(name="service_name", config=config)

# Usage with fallback
result = await breaker.call(
    external_api_call,
    fallback=default_value  # BSO-SEC-RES-003
)
```

### Required: Error Message Sanitization

**Tag:** BSO-SEC-RES-001, BSO-SEC-RES-002

All error messages MUST be sanitized before logging:

```python
from src.infrastructure.resilience.circuit_breaker import sanitize_error_message

# Sanitize removes:
# - API keys (sk-*, api_key=*, etc.)
# - Tokens (Bearer *, token=*)
# - URLs with credentials
sanitized = sanitize_error_message(str(error))
logger.error(f"Request failed: {sanitized}")
```

### Required: Exponential Backoff with Jitter

**Tag:** BSO-SEC-RES-004

Retry logic MUST include jitter to prevent thundering herd:

```python
from src.infrastructure.resilience import RetryConfig, calculate_delay

config = RetryConfig(
    max_retries=3,
    base_delay=1.0,
    max_delay=30.0,
    jitter_factor=0.5  # +/-50% randomization
)

delay = calculate_delay(attempt, config)
# delay = min(base * 2^attempt, max) * (1 +/- jitter)
```

---

## 2. Archive Extraction Security

### Vulnerability Prevention

| CWE | Vulnerability | Implementation |
|-----|--------------|----------------|
| CWE-22 | Path Traversal | `validate_and_normalize_path()` |
| CWE-61 | Symlink Following | `_validate_tar_member()` |
| CWE-78 | Null Byte Injection | Null byte check in paths |
| CWE-409 | Zip Bombs | `_check_compression_ratio()` |
| CWE-362 | Race Conditions | `create_secure_temp_dir()` |

### Required: Path Validation

All archive member paths MUST be validated:

```python
from src.infrastructure.storage.archive_extractor import (
    ArchiveExtractor,
    ArchiveSecurityError,
)

# Validates:
# - No path traversal (../)
# - No null bytes
# - No absolute paths
# - No symlinks/hardlinks (TAR)
safe_path = ArchiveExtractor.validate_and_normalize_path(
    member_path, archive_type
)
```

### Required: Secure Temp Directories

**Tag:** BSO-SEC-362

Temp directories MUST use cryptographic randomness:

```python
# Uses secrets.token_hex(16) for unpredictable names
temp_dir = ArchiveExtractor.create_secure_temp_dir()
# Result: /tmp/blocksecops-a1b2c3d4e5f6...
```

---

## 3. N+1 Query Prevention

### Required: Authorization in SQL

**Tag:** BSO-SEC-015

Authorization checks MUST be in SQL WHERE clause, NOT Python:

```python
# WRONG: Fetches all, filters in Python
all_items = db.query(Item).all()
user_items = [i for i in all_items if i.owner_id == user_id]

# CORRECT: Authorization in SQL
user_items = db.query(Item).filter(
    Item.owner_id == user_id
).all()
```

### Required: Batch Fetching

**Tag:** BSO-PERF-001

Related data MUST be fetched in batches, not N+1 loops:

```python
# WRONG: N+1 queries
for item in items:
    count = db.query(Related).filter_by(item_id=item.id).count()

# CORRECT: Single batch query
counts = db.query(
    Related.item_id,
    func.count(Related.id)
).filter(
    Related.item_id.in_([i.id for i in items])
).group_by(Related.item_id).all()

counts_dict = {item_id: count for item_id, count in counts}
```

---

## 4. Celery Task Security

### Required: JSON Serialization Only

**Tag:** BSO-SEC-TASK-001

Celery tasks MUST use JSON serialization (no pickle):

```python
@celery_app.task(
    bind=True,
    name="ml.retrain_model",
    queue="ml-tasks",
    serializer="json",
    accept_content=["json"],
    time_limit=1800,
    soft_time_limit=1700,
)
def retrain_model_task(self, args_dict: dict):
    # Validate with Pydantic
    args = RetrainTaskArgs(**args_dict)
```

### Required: Input Whitelist

Task inputs MUST be validated against whitelists:

```python
ALLOWED_MODEL_NAMES = frozenset({"fp_classifier", "severity_predictor"})

class RetrainTaskArgs(BaseModel):
    model_name: str

    @field_validator("model_name")
    @classmethod
    def validate_model_name(cls, v: str) -> str:
        if v not in ALLOWED_MODEL_NAMES:
            raise ValueError(f"Unknown model: {v}")
        return v
```

---

## 5. Security Tags Reference

| Tag | Description |
|-----|-------------|
| `BSO-SEC-015` | Authorization in SQL WHERE clause |
| `BSO-SEC-RES-001` | Sanitize error messages before logging |
| `BSO-SEC-RES-002` | No sensitive data in logs (URLs, API keys) |
| `BSO-SEC-RES-003` | Graceful degradation returns safe defaults |
| `BSO-SEC-RES-004` | Jitter prevents thundering herd |
| `BSO-SEC-TASK-001` | Celery JSON serialization only |
| `BSO-PERF-001` | N+1 query prevention |

---

## 6. Code Review Checklist

Before approving PRs, verify:

- [ ] External API calls use circuit breakers
- [ ] Archive extraction validates paths (no traversal)
- [ ] Database queries avoid N+1 patterns
- [ ] Celery tasks use JSON serialization only
- [ ] Authorization in SQL WHERE, not Python filtering
- [ ] Error messages sanitized before logging
- [ ] Temp directories use cryptographic randomness

---

## Related Documentation

- [Security Testing Guide](../feature-tests/54-security-testing.md)
- [Security Configuration Playbook](../playbooks/security-configuration.md)
