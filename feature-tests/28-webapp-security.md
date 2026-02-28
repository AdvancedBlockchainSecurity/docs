# Feature Test: Web Application Security

**Feature ID**: 28
**Version**: 1.1.0
**Added**: v0.1.6 (API), v0.17.1 (Dashboard)
**Last Updated**: 2026-02-20

---

## Overview

Test guide for web application security features including security headers, CORS, error handling, request size limits, and security event logging.

---

## Prerequisites

- [ ] API service running (accessible via `https://app.0xapogee.local/api/v1/`)
- [ ] Dashboard running (accessible via `https://app.0xapogee.local`)
- [ ] Access to application logs
- [ ] curl or similar HTTP client

> **Note (v0.29.4):** As of the February 2026 security audit, CORS is handled exclusively by FastAPI CORSMiddleware. Traefik CORS middleware was removed to eliminate duplicate header issues. CORS `max_age` is set to 3600 seconds (1 hour) to reduce preflight requests.

---

## Test 1: Security Headers

### 1.1 API Security Headers

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | `curl -skI https://app.0xapogee.local/api/v1/health/ready` | Response includes security headers | [ ] |
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

> **Architecture Note (v0.29.4):** CORS is handled solely by FastAPI CORSMiddleware. Traefik CORS middleware files were removed to prevent duplicate `Access-Control-*` headers. The CORS `max_age` is set to 3600 seconds.

### 2.1 Allowed Methods

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Send OPTIONS preflight for GET | Allowed | [ ] |
| 2 | Send OPTIONS preflight for POST | Allowed | [ ] |
| 3 | Send OPTIONS preflight for PUT | Allowed | [ ] |
| 4 | Send OPTIONS preflight for PATCH | Allowed | [ ] |
| 5 | Send OPTIONS preflight for DELETE | Allowed | [ ] |

```bash
curl -sk -X OPTIONS https://app.0xapogee.local/api/v1/contracts \
  -H "Origin: https://app.0xapogee.local" \
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
| X-Organization-Id | Allowed | [ ] |
| Accept | Allowed | [ ] |
| Origin | Allowed | [ ] |

### 2.3 CORS max-age (v0.29.4)

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Send OPTIONS preflight request | `Access-Control-Max-Age: 3600` in response | [ ] |
| 2 | Verify single CORS header set | `Access-Control-Allow-Origin` appears exactly once | [ ] |

```bash
curl -sk -X OPTIONS https://app.0xapogee.local/api/v1/contracts \
  -H "Origin: https://app.0xapogee.local" \
  -H "Access-Control-Request-Method: POST" \
  -D - -o /dev/null 2>&1 | grep -i "access-control"
```

### 2.4 Blocked Methods/Headers

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

## Test 7: CSP via Traefik Middleware (Dashboard)

**Note**: As of v0.30.4, CSP is delivered via Traefik middleware HTTP headers, not HTML meta tags.
This provides better security (server-enforced) and supports `frame-ancestors` directive.

### 7.1 CSP Header Present (via Traefik)

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Deploy dashboard with IngressRoute | Deployment succeeds | [ ] |
| 2 | Check response headers via curl | CSP header present | [ ] |
| 3 | Verify default-src | `'self'` | [ ] |
| 4 | Verify connect-src | Contains Supabase, wallet domains | [ ] |
| 5 | Verify frame-ancestors | `'none'` (only works via HTTP headers) | [ ] |
| 6 | Verify X-Frame-Options | `DENY` | [ ] |
| 7 | Verify X-Content-Type-Options | `nosniff` | [ ] |

```bash
# Test CSP and security headers via Traefik
curl -sI http://dashboard.local.0xapogee.com | grep -i -E "(content-security|x-frame|x-content-type|referrer-policy|permissions-policy)"
```

### 7.2 Traefik Middleware Configuration

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Check middleware exists | `kubectl get middleware -n dashboard-local` shows security-headers | [ ] |
| 2 | Check IngressRoute | References security-headers middleware | [ ] |
| 3 | Verify CSP contains Supabase URL | `huzjlpypdlelqnbjvxad.supabase.co` in connect-src | [ ] |

```bash
# Verify middleware configuration
kubectl get middleware security-headers -n dashboard-local -o yaml | grep -A 30 spec

# Verify IngressRoute references middleware
kubectl get ingressroute dashboard -n dashboard-local -o yaml | grep -A 5 middlewares
```

### 7.3 CSP Violations

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Inject inline script | Blocked by CSP | [ ] |
| 2 | Check browser console | CSP violation error | [ ] |
| 3 | Load external script | Blocked by CSP | [ ] |
| 4 | Try to embed in iframe | Blocked by frame-ancestors | [ ] |

### 7.4 Anti-Pattern Check

| Step | Action | Expected Result | Status |
|------|--------|-----------------|--------|
| 1 | Check index.html | NO CSP meta tags present | [ ] |
| 2 | Check index.html | Comment referencing middleware | [ ] |

```bash
# Verify no CSP meta tags in HTML (should be empty)
grep -i "content-security-policy" /path/to/dashboard/index.html

# Should see only comment about middleware
grep -i "middleware" /path/to/dashboard/index.html
```

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

echo "=== Apogee Security Hardening Tests ==="
echo ""

# Test 1: API Security Headers
echo "1. Testing API Security Headers..."
HEADERS=$(curl -skI https://app.0xapogee.local/api/v1/health/ready)
echo "$HEADERS" | grep -q "x-content-type-options: nosniff" && echo "   ✓ X-Content-Type-Options" || echo "   ✗ X-Content-Type-Options MISSING"
echo "$HEADERS" | grep -q "x-frame-options: DENY" && echo "   ✓ X-Frame-Options" || echo "   ✗ X-Frame-Options MISSING"
echo "$HEADERS" | grep -q "x-xss-protection: 1; mode=block" && echo "   ✓ X-XSS-Protection" || echo "   ✗ X-XSS-Protection MISSING"
echo "$HEADERS" | grep -q "referrer-policy:" && echo "   ✓ Referrer-Policy" || echo "   ✗ Referrer-Policy MISSING"
echo "$HEADERS" | grep -q "permissions-policy:" && echo "   ✓ Permissions-Policy" || echo "   ✗ Permissions-Policy MISSING"
echo "$HEADERS" | grep -q "cache-control: no-store" && echo "   ✓ Cache-Control" || echo "   ✗ Cache-Control MISSING"
echo ""

# Test 1b: Dashboard CSP via Traefik (v0.30.4+)
echo "1b. Testing Dashboard CSP via Traefik..."
DASHBOARD_HEADERS=$(curl -sI http://dashboard.local.0xapogee.com 2>/dev/null || echo "")
if [ -n "$DASHBOARD_HEADERS" ]; then
  echo "$DASHBOARD_HEADERS" | grep -qi "content-security-policy" && echo "   ✓ CSP Header Present" || echo "   ✗ CSP Header MISSING"
  echo "$DASHBOARD_HEADERS" | grep -qi "x-frame-options" && echo "   ✓ X-Frame-Options" || echo "   ✗ X-Frame-Options MISSING"
  echo "$DASHBOARD_HEADERS" | grep -qi "x-content-type-options" && echo "   ✓ X-Content-Type-Options" || echo "   ✗ X-Content-Type-Options MISSING"
  echo "$DASHBOARD_HEADERS" | grep -qi "referrer-policy" && echo "   ✓ Referrer-Policy" || echo "   ✗ Referrer-Policy MISSING"
  echo "$DASHBOARD_HEADERS" | grep -qi "permissions-policy" && echo "   ✓ Permissions-Policy" || echo "   ✗ Permissions-Policy MISSING"
else
  echo "   ⚠ Dashboard not accessible at dashboard.local.0xapogee.com"
fi
echo ""

# Test 2: CORS Configuration (FastAPI-only since v0.29.4)
echo "2. Testing CORS Configuration..."
CORS=$(curl -sk -X OPTIONS https://app.0xapogee.local/api/v1/contracts \
  -H "Origin: https://app.0xapogee.local" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Authorization,Content-Type" \
  -i 2>&1)
echo "$CORS" | grep -q "access-control-allow-origin: https://app.0xapogee.local" && echo "   ✓ CORS Origin Allowed" || echo "   ✗ CORS Origin FAILED"
echo "$CORS" | grep -q "access-control-allow-methods:" && echo "   ✓ CORS Methods Configured" || echo "   ✗ CORS Methods MISSING"
echo "$CORS" | grep -q "access-control-allow-headers:" && echo "   ✓ CORS Headers Configured" || echo "   ✗ CORS Headers MISSING"
echo "$CORS" | grep -q "access-control-max-age: 3600" && echo "   ✓ CORS Max-Age 3600" || echo "   ✗ CORS Max-Age MISSING"
# Verify no duplicate CORS headers (Traefik middleware removed in v0.29.4)
ORIGIN_COUNT=$(echo "$CORS" | grep -ci "access-control-allow-origin:")
[ "$ORIGIN_COUNT" -eq 1 ] && echo "   ✓ No Duplicate CORS Headers" || echo "   ✗ DUPLICATE CORS Headers ($ORIGIN_COUNT occurrences)"
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
curl -skI https://app.0xapogee.local/api/v1/health/ready

# Test CORS preflight (FastAPI-only since v0.29.4, max-age=3600)
curl -sk -X OPTIONS https://app.0xapogee.local/api/v1/contracts \
  -H "Origin: https://app.0xapogee.local" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Authorization,Content-Type" \
  -i 2>&1 | grep -i "access-control"

# Test request size limit (15MB > 10MB limit)
dd if=/dev/zero of=/tmp/large.bin bs=1M count=15 2>/dev/null && \
curl -sk -X POST https://app.0xapogee.local/api/v1/upload \
  -H "Content-Type: application/octet-stream" \
  --data-binary @/tmp/large.bin -w "\nHTTP: %{http_code}" && \
rm /tmp/large.bin

# Test rate limiting - verify X-RateLimit headers present
curl -sk -v https://app.0xapogee.local/api/v1/health/ready 2>&1 | grep -i "x-ratelimit"

# Test error handling
curl -sk https://app.0xapogee.local/api/v1/nonexistent | jq .

# Test auth failure
curl -sk https://app.0xapogee.local/api/v1/users/me -H "Authorization: Bearer invalid" | jq .
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

- [Phase 7A: Web Application Security](../../../TaskDocs-Apogee/phases/07a-phase-7a-webapp-security/README.md)
- [API Architecture](../../../blocksecops-docs/architecture/api-service-architecture.md)
- [Authentication System](../../../blocksecops-docs/architecture/authentication-system.md)
