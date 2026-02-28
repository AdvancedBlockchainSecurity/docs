# Feature Test: Application Security Testing

**Feature ID**: 29
**Version**: 1.0.0
**Added**: v0.6.1 (API)
**Last Updated**: 2025-12-27

---

## Overview

Comprehensive application security testing guide covering OWASP Top 10, input validation, authentication security, and data protection. Use this for manual penetration testing and security validation.

---

## Prerequisites

- [ ] API service running at http://127.0.0.1:8000
- [ ] Dashboard running at http://127.0.0.1:3000
- [ ] Valid test user credentials
- [ ] curl, jq installed
- [ ] Browser developer tools

---

## Test 1: SQL Injection Prevention

### 1.1 API Endpoint Testing

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Search with `'; DROP TABLE users; --` | Query returns empty, no error | [ ] |
| 2 | Search with `1 OR 1=1` | Normal filtered results | [ ] |
| 3 | Search with `UNION SELECT * FROM users` | Query rejected or escaped | [ ] |
| 4 | Check logs | No SQL errors logged | [ ] |

```bash
# Test SQL injection in search
curl -s "http://127.0.0.1:8000/api/v1/search?q=%27%3B%20DROP%20TABLE%20users%3B%20--" \
  -H "Authorization: Bearer $TOKEN" | jq .

# Test in contract name
curl -s -X POST http://127.0.0.1:8000/api/v1/contracts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "test'; DELETE FROM contracts; --", "source_code": "contract Test {}"}' | jq .
```

### 1.2 Database Query Safety

| Check | Expected | Status |
|-------|----------|--------|
| SQLAlchemy ORM used | Yes | [ ] |
| Parameterized queries | Yes | [ ] |
| No raw SQL with user input | Yes | [ ] |

---

## Test 2: Cross-Site Scripting (XSS) Prevention

### 2.1 Stored XSS

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Create contract with `<script>alert('xss')</script>` in name | Script escaped in response | [ ] |
| 2 | Add comment with `<img onerror="alert(1)" src=x>` | Tag escaped or stripped | [ ] |
| 3 | View in dashboard | No script execution | [ ] |

```bash
# Test XSS in contract name
curl -s -X POST http://127.0.0.1:8000/api/v1/contracts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "<script>alert(1)</script>", "source_code": "contract Test {}"}' | jq .

# Test XSS in annotation
curl -s -X POST http://127.0.0.1:8000/api/v1/annotations \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"vulnerability_id": "uuid", "content": "<img src=x onerror=alert(1)>"}' | jq .
```

### 2.2 Reflected XSS

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Access `/search?q=<script>alert(1)</script>` | Query parameter escaped | [ ] |
| 2 | Check response headers | Content-Type set correctly | [ ] |

### 2.3 Dashboard XSS Protection

| Check | Expected | Status |
|-------|----------|--------|
| DOMPurify sanitization | Enabled | [ ] |
| React auto-escaping | Active | [ ] |
| dangerouslySetInnerHTML usage | Sanitized inputs only | [ ] |

---

## Test 3: Authentication Security

### 3.1 Token Security

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Use expired token | 401 Unauthorized | [ ] |
| 2 | Use malformed token | 401 Unauthorized | [ ] |
| 3 | Use token with wrong signature | 401 Unauthorized | [ ] |
| 4 | Omit Authorization header | 401 Unauthorized | [ ] |

```bash
# Test expired token
curl -s http://127.0.0.1:8000/api/v1/users/me \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwiZXhwIjoxfQ.invalid" | jq .

# Test malformed token
curl -s http://127.0.0.1:8000/api/v1/users/me \
  -H "Authorization: Bearer not.a.valid.token" | jq .

# Test missing auth
curl -s http://127.0.0.1:8000/api/v1/users/me | jq .
```

### 3.2 Session Security

| Check | Expected | Status |
|-------|----------|--------|
| JWT RS256 algorithm | Yes | [ ] |
| Token expiration enforced | Yes | [ ] |
| Refresh token rotation | Yes | [ ] |
| Secure cookie flags | HttpOnly, SameSite | [ ] |

### 3.3 Password Security (if applicable)

| Check | Expected | Status |
|-------|----------|--------|
| Argon2id hashing | Yes | [ ] |
| Minimum password length | 8+ characters | [ ] |
| Password not in response | Never returned | [ ] |

---

## Test 4: Authorization & Access Control

### 4.1 Horizontal Privilege Escalation

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Access other user's project | 403 Forbidden | [ ] |
| 2 | Modify other user's contract | 403 Forbidden | [ ] |
| 3 | Delete other user's scan | 403 Forbidden | [ ] |

```bash
# Try to access another user's project (replace with real IDs)
curl -s http://127.0.0.1:8000/api/v1/projects/other-user-project-id \
  -H "Authorization: Bearer $YOUR_TOKEN" | jq .

# Try to delete another user's contract
curl -s -X DELETE http://127.0.0.1:8000/api/v1/contracts/other-user-contract-id \
  -H "Authorization: Bearer $YOUR_TOKEN" | jq .
```

### 4.2 Vertical Privilege Escalation

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Regular user access admin endpoint | 403 Forbidden | [ ] |
| 2 | Modify own role to admin | Rejected | [ ] |
| 3 | Access organization settings without permission | 403 Forbidden | [ ] |

### 4.3 IDOR (Insecure Direct Object Reference)

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Enumerate contract IDs | Only own contracts returned | [ ] |
| 2 | Access scan by guessed ID | 403 if not owner | [ ] |
| 3 | Modify project by ID manipulation | 403 if not authorized | [ ] |

---

## Test 5: Input Validation

### 5.1 API Input Validation

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Send invalid JSON | 400 Bad Request | [ ] |
| 2 | Send missing required fields | 422 Validation Error | [ ] |
| 3 | Send wrong data types | 422 Validation Error | [ ] |
| 4 | Send oversized string (>10KB) | 422 or truncated | [ ] |

```bash
# Test invalid JSON
curl -s -X POST http://127.0.0.1:8000/api/v1/contracts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d 'not valid json' | jq .

# Test missing required fields
curl -s -X POST http://127.0.0.1:8000/api/v1/contracts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}' | jq .

# Test wrong data type
curl -s -X POST http://127.0.0.1:8000/api/v1/contracts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": 12345, "source_code": null}' | jq .
```

### 5.2 File Upload Validation

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Upload .exe file | Rejected | [ ] |
| 2 | Upload file > 10MB | 413 Payload Too Large | [ ] |
| 3 | Upload with path traversal name | Name sanitized | [ ] |
| 4 | Upload polyglot file | Content validated | [ ] |

```bash
# Test path traversal in filename
curl -s -X POST http://127.0.0.1:8000/api/v1/upload \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@test.sol;filename=../../../etc/passwd" | jq .

# Test executable upload
echo "MZ" > /tmp/test.exe
curl -s -X POST http://127.0.0.1:8000/api/v1/upload \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@/tmp/test.exe" | jq .
rm /tmp/test.exe
```

---

## Test 6: Rate Limiting

### 6.1 API Rate Limits

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Send 100 requests in 1 minute | 429 after limit | [ ] |
| 2 | Check Retry-After header | Present on 429 | [ ] |
| 3 | Wait and retry | Requests allowed again | [ ] |

```bash
# Test rate limiting
for i in {1..100}; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/api/v1/health/ready)
  echo "Request $i: $STATUS"
  if [ "$STATUS" == "429" ]; then
    echo "Rate limited at request $i"
    break
  fi
done
```

### 6.2 Login Rate Limits

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | 10 failed logins | Account temporarily locked or rate limited | [ ] |
| 2 | Brute force protection | Exponential backoff | [ ] |

---

## Test 7: Data Protection

### 7.1 Sensitive Data Exposure

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Check API responses for passwords | Never included | [ ] |
| 2 | Check for API keys in responses | Masked or excluded | [ ] |
| 3 | Check error messages for stack traces | Hidden in production | [ ] |
| 4 | Check for internal IPs/paths | Not exposed | [ ] |

### 7.2 Data in Transit

| Check | Expected | Status |
|-------|----------|--------|
| HTTPS enforced (production) | Yes | [ ] |
| TLS 1.2+ required | Yes | [ ] |
| HSTS header (production) | Yes | [ ] |

### 7.3 Data at Rest

| Check | Expected | Status |
|-------|----------|--------|
| Database encrypted | Yes (production) | [ ] |
| Secrets in Vault | Yes | [ ] |
| No secrets in code/config | Yes | [ ] |

---

## Test 8: API Security

### 8.1 HTTP Methods

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | TRACE request | 405 Method Not Allowed | [ ] |
| 2 | CONNECT request | 405 Method Not Allowed | [ ] |
| 3 | Unexpected method on endpoint | 405 Method Not Allowed | [ ] |

```bash
# Test TRACE method
curl -s -X TRACE http://127.0.0.1:8000/api/v1/health/ready -w "%{http_code}"

# Test PUT on GET-only endpoint
curl -s -X PUT http://127.0.0.1:8000/api/v1/health/ready -w "%{http_code}"
```

### 8.2 Content Type Validation

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | POST without Content-Type | 415 or 422 | [ ] |
| 2 | POST with wrong Content-Type | 415 Unsupported Media Type | [ ] |
| 3 | Response Content-Type | application/json | [ ] |

---

## Test 9: Logging & Monitoring

### 9.1 Security Event Logging

| Event | Logged | Status |
|-------|--------|--------|
| Authentication success | Yes | [ ] |
| Authentication failure | Yes | [ ] |
| Authorization failure | Yes | [ ] |
| Rate limit exceeded | Yes | [ ] |
| Input validation failure | Yes | [ ] |

### 9.2 Log Content Safety

| Check | Expected | Status |
|-------|----------|--------|
| No passwords in logs | Yes | [ ] |
| No tokens in logs | Yes | [ ] |
| No PII in debug logs | Yes | [ ] |

---

## Test 10: Business Logic Security

### 10.1 Scan Credit System

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Use negative credits | Rejected | [ ] |
| 2 | Start scan without credits | Rejected | [ ] |
| 3 | Race condition on credit use | Properly synchronized | [ ] |

### 10.2 File Processing

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Upload zip bomb | Detected and rejected | [ ] |
| 2 | Upload deeply nested archive | Depth limit enforced | [ ] |
| 3 | Symlink in archive | Ignored or rejected | [ ] |

---

## Quick Security Scan Script

```bash
#!/bin/bash
# Quick Application Security Scan
# Usage: ./security-scan.sh <token>

TOKEN=$1
BASE_URL="http://127.0.0.1:8000"

echo "=== Apogee Application Security Scan ==="
echo ""

# SQL Injection
echo "1. Testing SQL Injection..."
RESULT=$(curl -s "$BASE_URL/api/v1/search?q=%27%20OR%201%3D1%20--" -H "Authorization: Bearer $TOKEN")
echo "$RESULT" | grep -qi "error\|exception\|sql" && echo "   ! Potential SQL injection vulnerability" || echo "   OK"

# XSS
echo "2. Testing XSS Prevention..."
RESULT=$(curl -s -X POST "$BASE_URL/api/v1/contracts" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "<script>alert(1)</script>", "source_code": "contract T{}"}')
echo "$RESULT" | grep -q "<script>" && echo "   ! XSS not escaped" || echo "   OK"

# Auth
echo "3. Testing Auth Security..."
RESULT=$(curl -s "$BASE_URL/api/v1/users/me" -H "Authorization: Bearer invalid" -w "%{http_code}")
echo "$RESULT" | grep -q "401" && echo "   OK" || echo "   ! Auth bypass possible"

# Rate Limit
echo "4. Testing Rate Limiting..."
for i in {1..70}; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/v1/health/ready")
  if [ "$CODE" == "429" ]; then
    echo "   OK - Rate limited at request $i"
    break
  fi
done

echo ""
echo "=== Scan Complete ==="
```

---

## Severity Classification

| Severity | Description | Response Time |
|----------|-------------|---------------|
| Critical | RCE, Auth bypass, Data breach | Immediate |
| High | SQL injection, XSS, IDOR | 24 hours |
| Medium | Rate limit bypass, Info disclosure | 1 week |
| Low | Missing headers, Verbose errors | 1 month |

---

## Sign-Off

| Tester | Date | Result |
|--------|------|--------|
| | | |

---

## Related Documentation

- [Feature 28: Web Application Security](./28-webapp-security.md)
- [Phase 7A: Security Hardening](../../../TaskDocs-Apogee/phases/07a-phase-7a-webapp-security/README.md)
- [Authentication System](../../../blocksecops-docs/architecture/authentication-system.md)
