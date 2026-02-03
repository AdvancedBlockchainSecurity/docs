# Security Testing Guide

**Version:** 1.1.0
**Last Updated:** February 3, 2026
**Security Tags:** BSO-SEC-RES-001 through BSO-SEC-RES-004, BSO-SEC-015, BSO-SEC-TASK-001, BSO-PERF-001

## Overview

This guide covers testing procedures for security features implemented in the January-February 2026 security audit. Use this to verify security controls are working correctly.

---

## Quick Reference

| Security Control | Test Method | Expected Result |
|-----------------|-------------|-----------------|
| Production secret validation | Start with empty secrets | App refuses to start |
| Prompt injection protection | Submit malicious prompts | Sanitized/rejected |
| Rate limiting | Exceed limit | 429 response |
| SSRF protection | Private IP webhook | Rejected |
| SQL wildcard escaping | Search with `%` | Literal match only |
| Nonce single-use | Reuse nonce | Authentication fails |
| Circuit breaker | 5 consecutive failures | Returns fallback, no exception |
| Archive path traversal | Upload `../etc/passwd` | Rejected with error |
| Zip bomb detection | Upload 100:1 ratio | Rejected with error |
| N+1 query prevention | Fetch 100 items | Query count constant |
| Celery JSON-only | Send pickle payload | Rejected by broker |

---

## 1. Circuit Breaker Testing

### 1.1 Circuit Opens After Failures (BSO-SEC-RES-001)

**Goal:** Verify circuit breaker opens after threshold failures

```python
from src.infrastructure.resilience import CircuitBreaker, CircuitBreakerConfig

config = CircuitBreakerConfig(failure_threshold=3, recovery_timeout=5.0)
breaker = CircuitBreaker(name="test", config=config)

# Simulate 3 failures
async def failing_call():
    raise Exception("Service unavailable")

for i in range(3):
    try:
        await breaker.call(failing_call)
    except Exception:
        pass

# Circuit should now be open
assert breaker.state == "open"
```

### 1.2 Graceful Degradation Returns Fallback (BSO-SEC-RES-003)

```python
# With fallback, no exception raised when circuit is open
result = await breaker.call(failing_call, fallback=[])
assert result == []  # Returns fallback, not exception
```

### 1.3 Error Message Sanitization (BSO-SEC-RES-002)

```python
from src.infrastructure.resilience.circuit_breaker import sanitize_error_message

# Sensitive data should be redacted
error = "Connection to https://api.example.com/v1?key=sk-123456 failed"
sanitized = sanitize_error_message(error)
assert "sk-123456" not in sanitized
assert "[REDACTED]" in sanitized
```

### 1.4 Jitter Prevents Thundering Herd (BSO-SEC-RES-004)

```python
from src.infrastructure.resilience import calculate_delay, RetryConfig

config = RetryConfig(base_delay=1.0, jitter_factor=0.5)

# Calculate multiple delays - they should vary
delays = [calculate_delay(1, config) for _ in range(100)]
unique_delays = len(set(delays))
assert unique_delays > 50  # Significant variation
```

---

## 2. Archive Extraction Security Testing

### 2.1 Path Traversal Prevention (CWE-22)

**Goal:** Verify malicious archive paths are blocked

```python
from src.infrastructure.storage.archive_extractor import (
    ArchiveExtractor,
    ArchiveSecurityError,
)

# Test directory traversal
traversal_paths = [
    "../../../etc/passwd",
    "..\\..\\windows\\system32",
    "foo/../../../etc/shadow",
]

for path in traversal_paths:
    try:
        ArchiveExtractor.validate_and_normalize_path(path, "zip")
        assert False, f"Should have blocked: {path}"
    except ArchiveSecurityError as e:
        assert e.error_code == "PATH_TRAVERSAL"
```

### 2.2 Null Byte Injection Prevention (CWE-78)

```python
# Null bytes should be blocked
null_paths = ["file.sol\x00.txt", "contract\x00.exe"]

for path in null_paths:
    try:
        ArchiveExtractor.validate_and_normalize_path(path, "zip")
        assert False, f"Should have blocked: {path}"
    except ArchiveSecurityError as e:
        assert e.error_code == "NULL_BYTE"
```

### 2.3 Zip Bomb Detection (CWE-409)

```python
# Create a high-ratio compressed file
import zipfile
from io import BytesIO

# This simulates a zip bomb (high compression ratio)
buffer = BytesIO()
with zipfile.ZipFile(buffer, 'w', zipfile.ZIP_DEFLATED) as zf:
    # 1KB compressed -> 1MB uncompressed (1000:1 ratio)
    zf.writestr("bomb.txt", "A" * 1_000_000)

# Extraction should detect and block
try:
    ArchiveExtractor.extract_with_smart_dependencies(buffer.getvalue())
    assert False, "Should have detected zip bomb"
except ArchiveSecurityError as e:
    assert e.error_code == "ZIP_BOMB"
```

### 2.4 Secure Temp Directory Unpredictability (CWE-362)

```python
import os
import re

# Create multiple temp directories
dirs = [ArchiveExtractor.create_secure_temp_dir() for _ in range(10)]

# Each should be unique and unpredictable
paths = [str(d) for d in dirs]
assert len(set(paths)) == 10  # All unique

# Should contain cryptographic randomness (32 hex chars)
for path in paths:
    assert re.search(r'blocksecops-[a-f0-9]{32}', path)
```

---

## 3. N+1 Query Testing

### 3.1 Authorization in SQL WHERE (BSO-SEC-015)

**Goal:** Verify authorization happens in database, not Python

```python
# Use SQLAlchemy query listener to count queries
from sqlalchemy import event
from src.presentation.api.v1.endpoints.comments import verify_entity_access

query_count = 0

@event.listens_for(engine, "before_cursor_execute")
def count_queries(*args):
    global query_count
    query_count += 1

# Verify entity access for vulnerability
await verify_entity_access(db, "vulnerability", vuln_id, user_id)

# Should be exactly 1 query, not multiple (N+1)
assert query_count == 1
```

### 3.2 Batch Fetching Constant Query Count (BSO-PERF-001)

```python
# Create test data: 100 comments
comment_ids = [create_comment(db) for _ in range(100)]

# Count queries for batch fetch
query_count = 0
reply_counts = await get_reply_counts_batch(db, comment_ids)

# Should be 1 query regardless of count
assert query_count == 1
```

### 3.3 Unauthorized Access Returns 403

```bash
# User A trying to access User B's vulnerability comments
curl -X GET "http://localhost:8000/api/v1/vulnerabilities/{USER_B_VULN_ID}/comments" \
  -H "Authorization: Bearer $USER_A_TOKEN"
```

**Expected:** 403 Forbidden (not 404, to avoid enumeration)

---

## 4. Celery Task Security Testing

### 4.1 JSON Serialization Only (BSO-SEC-TASK-001)

**Goal:** Verify pickle serialization is rejected

```python
from blocksecops_orchestration.tasks.ml_tasks_sync import retrain_model_task

# Task should only accept JSON
task_info = celery_app.tasks['ml.retrain_model']
assert task_info.serializer == "json"
assert task_info.accept_content == ["json"]

# Pickle content should be rejected by broker
```

### 4.2 Model Name Whitelist Validation

```python
from blocksecops_orchestration.tasks.ml_tasks_sync import RetrainTaskArgs

# Valid model name
valid = RetrainTaskArgs(
    model_name="fp_classifier",
    triggered_by="manual",
    request_id="uuid"
)

# Invalid model name should raise
try:
    RetrainTaskArgs(
        model_name="malicious_model; rm -rf /",
        triggered_by="manual",
        request_id="uuid"
    )
    assert False, "Should have rejected invalid model name"
except ValueError as e:
    assert "Unknown model" in str(e)
```

### 4.3 Internal Service Authentication

```bash
# Request without internal service key
curl -X POST "http://localhost:8000/internal/tasks/ml/retrain" \
  -H "Content-Type: application/json" \
  -d '{"model_name": "fp_classifier", "triggered_by": "manual", "request_id": "uuid"}'
```

**Expected:** 401 Unauthorized

```bash
# With valid internal key
curl -X POST "http://localhost:8000/internal/tasks/ml/retrain" \
  -H "Content-Type: application/json" \
  -H "X-Internal-Service-Key: $INTERNAL_SERVICE_KEY" \
  -d '{"model_name": "fp_classifier", "triggered_by": "manual", "request_id": "uuid"}'
```

**Expected:** 202 Accepted with task_id

---

## 5. Automated Test Suite

Run all security tests:

```bash
# Unit tests for security modules
python -m pytest tests/unit/security/ -v --no-cov

# Integration tests (requires running services)
python -m pytest tests/integration/security/ -v --no-cov
```

---

## 6. Penetration Testing Checklist

For manual security testing:

- [ ] **Authentication bypass:** Try accessing protected endpoints without token
- [ ] **Token manipulation:** Modify JWT payload, test with expired tokens
- [ ] **Privilege escalation:** Free tier accessing paid features
- [ ] **IDOR:** Access other users' resources by guessing IDs
- [ ] **Injection:** SQL, NoSQL, command injection in all inputs
- [ ] **SSRF:** Webhook URLs, any URL input fields
- [ ] **Rate limiting:** Verify all expensive endpoints are limited
- [ ] **File upload:** Path traversal (../), zip bombs, symlinks, null bytes
- [ ] **API versioning:** Old API versions still protected
- [ ] **Circuit breaker:** External API failures return graceful fallback
- [ ] **Archive extraction:** All paths validated before extraction
- [ ] **N+1 queries:** Authorization in SQL WHERE, not Python filtering
- [ ] **Celery tasks:** Only JSON serialization accepted, no pickle

---

## 7. UI Testing Checklist

Manual testing through the dashboard to verify security implementations.

### 7.1 File Upload (Archive Extraction Security)

| Test | Steps | Expected Result |
|------|-------|-----------------|
| Valid ZIP upload | Upload `.zip` with Solidity files | Extracts, creates contract |
| Valid TAR.GZ upload | Upload `.tar.gz` with Solidity files | Extracts, creates contract |
| Nested archive | Upload zip containing another zip | Handles correctly |
| Large file rejection | Upload file >10MB | Clear error message |
| Empty archive | Upload empty `.zip` | Error: no valid files found |

### 7.2 Scans & Results (N+1 Query Fixes)

| Test | Steps | Expected Result |
|------|-------|-----------------|
| Scans list performance | Navigate to Scans page with 50+ scans | Page loads <2s |
| Scan detail load | Click scan with 100+ vulnerabilities | Details load <2s |
| Comments load | View vulnerability with comments | Comments appear instantly |
| Batch delete | Select 10 scans → Delete | All deleted, no timeout |
| Pagination | Navigate pages in scan list | Each page loads quickly |

### 7.3 Intelligence Features (Circuit Breakers)

| Test | Steps | Expected Result |
|------|-------|-----------------|
| CVE enrichment | View vulnerability with CVE mapping | CVE data displays |
| Semantic search | Search "reentrancy attack" | Results return |
| Graceful degradation | (If NVD slow) View vulnerability | Page loads, CVE may be empty |
| SWC mapping | View vulnerability with SWC ID | Related CVEs shown |

### 7.4 Core Functionality (Regression)

| Test | Steps | Expected Result |
|------|-------|-----------------|
| Login | Enter credentials → Submit | Dashboard loads |
| Logout | Click logout | Returns to login page |
| Create contract | Contracts → New → Upload file | Contract created |
| Run scan | Select contract → Run scan (slither) | Scan completes |
| View results | Click completed scan | Vulnerabilities listed |
| Add comment | Click vulnerability → Add comment | Comment saved |
| Filter vulnerabilities | Use severity/status filters | List filters correctly |

### 7.5 Quick Smoke Test Path

```
1. Login → Dashboard loads ✓
2. Contracts → List loads ✓
3. Create new contract (upload .zip) ✓
4. Run scan with slither ✓
5. View results → vulnerabilities display ✓
6. Click vulnerability → details + CVE info loads ✓
7. Add comment → saves correctly ✓
8. Delete scan → removed from list ✓
9. Logout ✓
```

### 7.6 What to Watch For

| Issue | Indicates |
|-------|-----------|
| Slow page loads (>3s) | N+1 query fix may not be applied |
| Upload fails with valid file | Archive extraction too strict |
| Missing CVE data | Circuit breaker may be open |
| 403 on own resources | Authorization query issue |
| Blank vulnerability details | Batch fetch not working |

---

## Related Documentation

- [Security Configuration Playbook](../playbooks/security-configuration.md)
- [Security Standards](../standards/security-standards.md)
