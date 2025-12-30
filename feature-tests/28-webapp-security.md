# Feature Test: Web Application Security

**Feature ID**: 28
**Version**: 1.0.0
**Added**: v0.1.6 (API), v0.17.1 (Dashboard)
**Last Updated**: 2025-12-27

---

## Overview

Test guide for web application security features including security headers, CORS, error handling, request size limits, and security event logging.

---

## Prerequisites

- [ ] API service running at http://127.0.0.1:8000
- [ ] Dashboard running at http://127.0.0.1:3000
- [ ] Access to application logs
- [ ] curl or similar HTTP client

---

## Test 1: Security Headers

### 1.1 API Security Headers

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | `curl -I http://127.0.0.1:8000/api/v1/health/ready` | Response includes security headers | [ ] |
| 2 | Check X-Content-Type-Options | `nosniff` | [ ] |
| 3 | Check X-Frame-Options | `DENY` | [ ] |
| 4 | Check X-XSS-Protection | `1; mode=block` | [ ] |
| 5 | Check Referrer-Policy | `strict-origin-when-cross-origin` | [ ] |
| 6 | Check Permissions-Policy | Contains `geolocation=(), microphone=(), camera=()` | [ ] |
| 7 | Check Cache-Control | `no-store, max-age=0` | [ ] |

### 1.2 HSTS in Production

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Set `ENVIRONMENT=production` | Config change | [ ] |
| 2 | Restart API service | Service restarts | [ ] |
| 3 | Check headers | `Strict-Transport-Security` present | [ ] |
| 4 | Verify HSTS value | `max-age=31536000; includeSubDomains; preload` | [ ] |

---

## Test 2: CORS Configuration

### 2.1 Allowed Methods

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Send OPTIONS preflight for GET | Allowed | [ ] |
| 2 | Send OPTIONS preflight for POST | Allowed | [ ] |
| 3 | Send OPTIONS preflight for PUT | Allowed | [ ] |
| 4 | Send OPTIONS preflight for PATCH | Allowed | [ ] |
| 5 | Send OPTIONS preflight for DELETE | Allowed | [ ] |

```bash
curl -X OPTIONS http://127.0.0.1:8000/api/v1/contracts \
  -H "Origin: http://127.0.0.1:3000" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Authorization,Content-Type" \
  -v
```

### 2.2 Allowed Headers

| Header | Expected | Status |
|--------|----------|--------|
| Authorization | Allowed | [ ] |
| Content-Type | Allowed | [ ] |
| X-Request-ID | Allowed | [ ] |
| X-API-Key | Allowed | [ ] |
| Accept | Allowed | [ ] |
| Origin | Allowed | [ ] |

### 2.3 Blocked Methods/Headers

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Request TRACE method | Not in Allow header | [ ] |
| 2 | Request arbitrary header | Not in Allow headers | [ ] |

---

## Test 3: Error Handling

### 3.1 Development Mode

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Set `ENVIRONMENT=local` | Config change | [ ] |
| 2 | Trigger 500 error | Response includes error type and message | [ ] |
| 3 | Check response body | Contains `type` field with exception name | [ ] |

### 3.2 Production Mode

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Set `ENVIRONMENT=production` | Config change | [ ] |
| 2 | Trigger 500 error | Generic error message | [ ] |
| 3 | Check response body | Only contains generic message | [ ] |
| 4 | Check server logs | Full error details logged | [ ] |

**Expected Production Response**:
```json
{
  "error": "internal_server_error",
  "message": "An unexpected error occurred. Please try again later."
}
```

---

## Test 4: Request Size Limit

### 4.1 Normal Requests

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | POST with 1MB body | 200 OK (if valid endpoint) | [ ] |
| 2 | POST with 5MB body | 200 OK (if valid endpoint) | [ ] |
| 3 | POST with 9MB body | 200 OK (if valid endpoint) | [ ] |

### 4.2 Oversized Requests

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | POST with 11MB body | 413 Payload Too Large | [ ] |
| 2 | Check error message | Contains "exceeds maximum size" | [ ] |
| 3 | POST with 50MB body | 413 Payload Too Large | [ ] |

```bash
# Test oversized request
dd if=/dev/zero bs=1M count=15 2>/dev/null | \
  curl -X POST http://127.0.0.1:8000/api/v1/upload \
    -H "Content-Type: application/octet-stream" \
    -H "Content-Length: 15728640" \
    --data-binary @- \
    -w "%{http_code}"
```

**Expected Response** (413):
```json
{
  "error": "payload_too_large",
  "message": "Request body exceeds maximum size of 10MB",
  "max_size_bytes": 10485760
}
```

---

## Test 5: Security Event Logging

### 5.1 Authentication Success

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Login with valid credentials | Auth success logged | [ ] |
| 2 | Check logs for AUTH_SUCCESS | Contains user_id, email, IP | [ ] |
| 3 | Check auth_method | `supabase_jwt` | [ ] |

### 5.2 Authentication Failure

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Request with invalid token | 401 Unauthorized | [ ] |
| 2 | Check logs for AUTH_FAILURE | Contains reason, IP | [ ] |
| 3 | Request with expired token | 401 Unauthorized | [ ] |
| 4 | Check logs | Contains `reason: invalid_token` | [ ] |

### 5.3 Rate Limit Logging

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Exceed rate limit | 429 Too Many Requests | [ ] |
| 2 | Check logs for RATE_LIMIT_EXCEEDED | Contains limit, IP, path | [ ] |

**Log Format Examples**:
```
AUTH_SUCCESS: {"event_type": "auth_success", "timestamp": "2025-12-27T12:00:00", "ip": "192.168.1.1", "user_agent": "...", "user_id": "uuid", "email": "user@example.com", "auth_method": "supabase_jwt"}

AUTH_FAILURE: {"event_type": "auth_failure", "timestamp": "2025-12-27T12:00:00", "ip": "192.168.1.1", "user_agent": "...", "reason": "invalid_token"}

RATE_LIMIT_EXCEEDED: {"event_type": "rate_limit_exceeded", "timestamp": "2025-12-27T12:00:00", "ip": "192.168.1.1", "path": "/api/v1/contracts", "limit": "60 per 1 minute"}
```

---

## Test 6: SQL Logging Control

### 6.1 Local Environment

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Set `ENVIRONMENT=local`, `DEBUG=true` | Config change | [ ] |
| 2 | Make database query | SQL logged to console | [ ] |
| 3 | Check logs | Query text visible | [ ] |

### 6.2 Production Environment

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Set `ENVIRONMENT=production`, `DEBUG=true` | Config change | [ ] |
| 2 | Make database query | SQL NOT logged | [ ] |
| 3 | Check logs | No query text visible | [ ] |

---

## Test 7: Production CSP (Dashboard)

### 7.1 CSP Header Present

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Deploy production dashboard | Deployment succeeds | [ ] |
| 2 | Check response headers | CSP header present | [ ] |
| 3 | Verify default-src | `'self'` | [ ] |
| 4 | Verify script-src | `'self'` (no unsafe-inline) | [ ] |
| 5 | Verify frame-ancestors | `'none'` | [ ] |

### 7.2 CSP Violations

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Inject inline script | Blocked by CSP | [ ] |
| 2 | Check browser console | CSP violation error | [ ] |
| 3 | Load external script | Blocked by CSP | [ ] |

---

## Test 8: Container Security (Production)

### 8.1 Security Context

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Check pod security context | runAsNonRoot: true | [ ] |
| 2 | Check container security | allowPrivilegeEscalation: false | [ ] |
| 3 | Check filesystem | readOnlyRootFilesystem: true | [ ] |
| 4 | Check capabilities | All dropped | [ ] |

```bash
kubectl get pod dashboard-xxx -n dashboard-prod -o yaml | grep -A 20 securityContext
```

---

## Quick Verification Script

Run this script to verify all security hardening is in place:

```bash
#!/bin/bash
# Security Hardening Verification Script
# Run from terminal with API service accessible at 127.0.0.1:8000

echo "=== BlockSecOps Security Hardening Tests ==="
echo ""

# Test 1: Security Headers
echo "1. Testing Security Headers..."
HEADERS=$(curl -sI http://127.0.0.1:8000/api/v1/health/ready)
echo "$HEADERS" | grep -q "x-content-type-options: nosniff" && echo "   ✓ X-Content-Type-Options" || echo "   ✗ X-Content-Type-Options MISSING"
echo "$HEADERS" | grep -q "x-frame-options: DENY" && echo "   ✓ X-Frame-Options" || echo "   ✗ X-Frame-Options MISSING"
echo "$HEADERS" | grep -q "x-xss-protection: 1; mode=block" && echo "   ✓ X-XSS-Protection" || echo "   ✗ X-XSS-Protection MISSING"
echo "$HEADERS" | grep -q "referrer-policy:" && echo "   ✓ Referrer-Policy" || echo "   ✗ Referrer-Policy MISSING"
echo "$HEADERS" | grep -q "permissions-policy:" && echo "   ✓ Permissions-Policy" || echo "   ✗ Permissions-Policy MISSING"
echo "$HEADERS" | grep -q "cache-control: no-store" && echo "   ✓ Cache-Control" || echo "   ✗ Cache-Control MISSING"
echo ""

# Test 2: CORS Configuration
echo "2. Testing CORS Configuration..."
CORS=$(curl -sX OPTIONS http://127.0.0.1:8000/api/v1/contracts \
  -H "Origin: http://127.0.0.1:3000" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Authorization,Content-Type" \
  -i 2>&1)
echo "$CORS" | grep -q "access-control-allow-origin: http://127.0.0.1:3000" && echo "   ✓ CORS Origin Allowed" || echo "   ✗ CORS Origin FAILED"
echo "$CORS" | grep -q "access-control-allow-methods:" && echo "   ✓ CORS Methods Configured" || echo "   ✗ CORS Methods MISSING"
echo "$CORS" | grep -q "access-control-allow-headers:" && echo "   ✓ CORS Headers Configured" || echo "   ✗ CORS Headers MISSING"
echo ""

# Test 3: Request Size Limit
echo "3. Testing Request Size Limit (10MB)..."
dd if=/dev/zero of=/tmp/test_large.bin bs=1M count=15 2>/dev/null
RESPONSE=$(curl -sX POST http://127.0.0.1:8000/api/v1/upload \
  -H "Content-Type: application/octet-stream" \
  --data-binary @/tmp/test_large.bin \
  -w "\n%{http_code}" 2>&1)
rm -f /tmp/test_large.bin
echo "$RESPONSE" | grep -q "413" && echo "   ✓ 413 Payload Too Large returned" || echo "   ✗ Size limit NOT enforced"
echo "$RESPONSE" | grep -q "payload_too_large" && echo "   ✓ Correct error message" || echo "   ✗ Error message incorrect"
echo ""

# Test 4: Error Handling
echo "4. Testing Error Handling..."
ERROR=$(curl -s http://127.0.0.1:8000/api/v1/nonexistent)
echo "$ERROR" | grep -q "Not Found" && echo "   ✓ 404 returns clean error" || echo "   ✗ 404 handling issue"
echo ""

# Test 5: Auth Failure Response
echo "5. Testing Auth Failure Response..."
AUTH=$(curl -s http://127.0.0.1:8000/api/v1/users/me -H "Authorization: Bearer invalid_token" -w "\n%{http_code}")
echo "$AUTH" | grep -q "401" && echo "   ✓ 401 Unauthorized returned" || echo "   ✗ Auth check FAILED"
echo ""

echo "=== Security Tests Complete ==="
```

## API Test Commands

```bash
# Test security headers
curl -I http://127.0.0.1:8000/api/v1/health/ready

# Test CORS preflight
curl -X OPTIONS http://127.0.0.1:8000/api/v1/contracts \
  -H "Origin: http://127.0.0.1:3000" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Authorization,Content-Type" \
  -i 2>&1 | grep -i "access-control"

# Test request size limit (15MB > 10MB limit)
dd if=/dev/zero of=/tmp/large.bin bs=1M count=15 2>/dev/null && \
curl -X POST http://127.0.0.1:8000/api/v1/upload \
  -H "Content-Type: application/octet-stream" \
  --data-binary @/tmp/large.bin -w "\nHTTP: %{http_code}" && \
rm /tmp/large.bin

# Test rate limiting (run multiple times quickly)
for i in {1..100}; do curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8000/api/v1/health/ready; done | sort | uniq -c

# Test error handling
curl -s http://127.0.0.1:8000/api/v1/nonexistent | jq .

# Test auth failure
curl -s http://127.0.0.1:8000/api/v1/users/me -H "Authorization: Bearer invalid" | jq .
```

---

## Known Issues

None at this time.

---

## Troubleshooting

### Security Headers Missing

1. Verify SecurityHeadersMiddleware is imported in main.py
2. Verify middleware is added with `app.add_middleware(SecurityHeadersMiddleware)`
3. Check middleware order (security headers should wrap response)

### CORS Errors

1. Verify origin is in `cors_origins` setting
2. Check preflight OPTIONS response headers
3. Verify method is in allowed list

### Rate Limit Not Working

1. Check Redis connection
2. Verify `enable_rate_limiting` is True
3. Check slowapi configuration

### Security Logs Missing

1. Verify security_logger is imported
2. Check log level is INFO or lower
3. Verify log handlers are configured

---

## Sign-Off

| Tester | Date | Result |
|--------|------|--------|
| | | |

---

## Related Documentation

- [Phase 7A: Web Application Security](../../../TaskDocs-BlockSecOps/phases/07a-phase-7a-webapp-security/README.md)
- [API Architecture](../../../blocksecops-docs/architecture/api-service-architecture.md)
- [Authentication System](../../../blocksecops-docs/architecture/authentication-system.md)
