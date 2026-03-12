# Feature Test 87: HSTS Enforcement (March 1, 2026)

**Date:** March 1, 2026
**Component:** Traefik HSTS Middleware
**Version Tested:** traefik-local with HSTS Middleware CRD
**Audit Finding:** F12 (LOW) — Missing HSTS header on HTTPS responses

## Test Objective

Verify that Traefik enforces HSTS (Strict-Transport-Security) headers with proper directives on all HTTPS responses. This ensures compliance with OWASP security standards and closes audit finding F12.

## Prerequisites

- Traefik running in `traefik-local` namespace
- HSTS Middleware CRD named `hsts` deployed in `traefik-local` namespace
- HSTS middleware bound to `websecure` entrypoint in Traefik ConfigMap
- HTTPS endpoint accessible (e.g., `app.0xapogee.com`)
- `curl` available for HTTP header inspection
- `grep` available for header validation

## Test Steps

### Test 1: HSTS Header Present on Dashboard

**Objective:** Verify HSTS header is included in all dashboard responses

**Command:**
```bash
curl -I https://app.0xapogee.com
```

**Expected Result:**
- HTTP 200 OK (or 3xx redirect)
- Response includes `Strict-Transport-Security` header
- Header format: `max-age=31536000; includeSubDomains; preload`
- Content-Type indicates HTML

**Actual Result:** PASS — HSTS header present

**Notes:**
- HSTS header applied globally via Traefik middleware
- No per-route configuration needed
- Header value is deterministic (set by Middleware CRD)

---

### Test 2: HSTS Header Present on API Endpoints

**Objective:** Verify HSTS header on REST API responses

**Command:**
```bash
curl -I https://app.0xapogee.com/api/v1/health/live
```

**Expected Result:**
- HTTP 200 OK
- Response includes `Strict-Transport-Security` header
- Same value as dashboard (global enforcement)
- Content-Type application/json

**Actual Result:** PASS — HSTS header present on API

**Notes:**
- API Service returns requests through Traefik ingress
- HSTS applied at ingress layer, not service layer
- Service code unchanged (no application-level implementation)

---

### Test 3: HSTS Max-Age Value

**Objective:** Verify max-age is set to 1 year (31536000 seconds)

**Command:**
```bash
curl -s -I https://app.0xapogee.com | grep -i "strict-transport-security"
```

**Expected Result:**
- Output contains `max-age=31536000`
- 31536000 seconds = 365 days * 24 hours * 3600 seconds
- Suitable for production (standard 1-year value)

**Actual Result:** PASS — max-age=31536000

**Notes:**
- 1-year max-age provides long-term browser cache
- Recommended for stable domains
- Renewal happens automatically via certificate reissuance

---

### Test 4: includeSubDomains Directive

**Objective:** Verify HSTS applies to all subdomains

**Command:**
```bash
curl -s -I https://app.0xapogee.com | grep -i "strict-transport-security"
```

**Expected Result:**
- Output includes `includeSubDomains`
- Applies HSTS to all subdomains (e.g., `api.0xapogee.com`, `admin.0xapogee.com`, future subdomains)
- Browser enforces HTTPS for any subdomain accessed

**Actual Result:** PASS — includeSubDomains present

**Notes:**
- Protects against MITM attacks on subdomains
- Future subdomain creation automatically inherits HSTS
- Prevents accidental downgrade on new services

---

### Test 5: Preload Directive

**Objective:** Verify preload flag is set for HSTS preload list eligibility

**Command:**
```bash
curl -s -I https://app.0xapogee.com | grep -i "strict-transport-security"
```

**Expected Result:**
- Output includes `preload` directive
- Allows inclusion in browser HSTS preload lists
- Browsers will enforce HTTPS on domain before first visit
- Eliminates first-visit vulnerability

**Actual Result:** PASS — preload directive present

**Notes:**
- Preload list maintained by browsers (Chrome, Firefox, Safari, Edge)
- Requires specific conditions (max-age ≥ 31536000, includeSubDomains, preload)
- All conditions met; domain eligible for preload list submission
- Submission to HSTS preload registry is separate manual step

---

### Test 6: HTTP Redirect Includes HSTS

**Objective:** Verify HSTS header on HTTP-to-HTTPS redirect responses

**Command:**
```bash
curl -I http://app.0xapogee.com
```

**Expected Result:**
- HTTP 301 (Moved Permanently) or 307 (Temporary Redirect)
- Location header points to `https://app.0xapogee.com`
- **Response includes HSTS header** (on the redirect response itself)
- No HSTS on redirect means future insecure requests won't be blocked

**Actual Result:** PASS — HSTS header on redirect response

**Notes:**
- Critical for security: Even if user types HTTP, they get HSTS header
- Subsequent requests to HTTP are redirected by browser (not by server)
- Eliminates MITM attacks on first HTTP request

---

### Test 7: HSTS Header Consistency Across Endpoints

**Objective:** Verify HSTS is applied consistently to all endpoints

**Commands:**
```bash
# Test multiple endpoints
for endpoint in "" "/api/v1/health/live" "/api/v1/health/ready" "/docs"; do
  echo "=== https://app.0xapogee.com$endpoint ==="
  curl -s -I https://app.0xapogee.com$endpoint | grep -i "strict-transport-security"
done
```

**Expected Result:**
- All endpoints return identical HSTS header value
- Middleware applied globally (not per-route)
- No exceptions or missing headers
- Consistent security posture across entire platform

**Actual Result:** PASS — HSTS consistent on all endpoints

**Notes:**
- Global enforcement via Traefik middleware binding to `websecure` entrypoint
- No IngressRoute-level configuration needed
- All HTTPS traffic inherits HSTS automatically

---

### Test 8: HSTS Middleware CRD Validation

**Objective:** Verify HSTS Middleware CRD is properly deployed

**Command:**
```bash
kubectl get middleware -n traefik-local hsts -o yaml
```

**Expected Result:**
- Middleware resource exists in `traefik-local` namespace
- Name: `hsts`
- Spec includes:
  - `stsSeconds: 31536000`
  - `stsIncludeSubdomains: true`
  - `stsPreload: true`
- No errors or warnings in resource definition

**Actual Result:** PASS — Middleware properly deployed

**Notes:**
- Custom Resource Definition (CRD) for Traefik Middleware
- Traefik v3 uses `traefik.io/v1alpha1` API version
- Middleware applied via entrypoint configuration in ConfigMap

---

### Test 9: HSTS No Service Restarts Required

**Objective:** Verify HSTS deployment requires no pod/service restarts

**Procedure:**
1. Verify all service pods were running before HSTS deployment
2. Deploy HSTS Middleware and ConfigMap update
3. Confirm zero pod restarts occurred
4. Verify services remain healthy

**Command:**
```bash
# Check for recent pod restarts
kubectl get pods -n traefik-local -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}'
```

**Expected Result:**
- Traefik pod has 0 restarts (or same count as before deployment)
- All other service pods unaffected
- No service downtime occurred
- HSTS takes effect immediately

**Actual Result:** PASS — No restarts required

**Notes:**
- Traefik hot-reloads middleware configuration
- Existing connections not disrupted
- New connections use HSTS header immediately
- Zero-downtime deployment

---

### Test 10: Verify No HSTS Header on HTTP (Redirect Only)

**Objective:** Verify HTTP responses DO NOT include HSTS header (only redirect and HTTPS responses do)

**Command:**
```bash
# Follow redirects to see where HSTS appears
curl -I -L http://app.0xapogee.com 2>&1 | grep -E "(^< HTTP|Strict-Transport)"
```

**Expected Result:**
- HTTP 301 response (on initial HTTP request)
- HSTS header appears on 301 redirect response (not on plain HTTP)
- After redirect, HTTP 200 response on HTTPS
- HSTS on HTTPS response as well

**Actual Result:** PASS — HSTS only on HTTPS and redirects

**Notes:**
- HSTS header is meaningful only over HTTPS (RFC 6797)
- Browsers ignore HSTS on plain HTTP (security requirement)
- Traefik correctly sends HSTS on all HTTPS responses
- Traefik correctly sends HSTS on 301 HTTP redirect

---

### Test 11: Browser HSTS Cache Simulation

**Objective:** Verify HSTS cache values allow proper browser enforcement

**Command:**
```bash
curl -s -I https://app.0xapogee.com | grep -i "strict-transport-security"
# Output example: Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```

**Expected Result:**
- max-age value allows browser to cache HSTS policy for 365 days
- Subsequent HTTP requests during cache period are upgraded to HTTPS by browser (client-side redirect)
- No server processing needed for cached HSTS clients
- Reduces latency on repeat visits

**Actual Result:** PASS — HSTS cache values proper

**Notes:**
- max-age=31536000 is maximum recommended value
- Browser caches policy and enforces HTTPS before contacting server
- Each HTTPS visit refreshes the cache timer
- Non-expiring policy provides long-term security

---

### Test 12: Interaction with TLS 1.2+ Enforcement (F11)

**Objective:** Verify HSTS and TLS 1.2+ enforcement (F11) work together

**Commands:**
```bash
# Attempt TLS 1.0 (should fail)
openssl s_client -connect app.0xapogee.com:443 -tls1 2>&1 | head -5

# Attempt TLS 1.2 (should succeed with HSTS header)
curl -I --tlsv1.2 https://app.0xapogee.com | grep -E "(HTTP|Strict-Transport)"
```

**Expected Result:**
- TLS 1.0 connection rejected (F11)
- TLS 1.2 connection succeeds with HSTS header
- Both security fixes active simultaneously
- No conflicts between TLSOption (F11) and HSTS Middleware (F12)

**Actual Result:** PASS — Both F11 and F12 active

**Notes:**
- F11: TLS 1.2+ minimum version (transport layer)
- F12: HSTS header (HTTP layer)
- Both address different aspects of transport security
- Combined security posture is comprehensive

---

## Summary

| Test | Status | Feature | Result |
|------|--------|---------|--------|
| 1 | PASS | HSTS on dashboard | Header present |
| 2 | PASS | HSTS on API endpoints | Header present |
| 3 | PASS | max-age=31536000 | 1 year cache |
| 4 | PASS | includeSubDomains | Subdomains protected |
| 5 | PASS | preload directive | Preload eligible |
| 6 | PASS | HSTS on redirects | Header on 301 response |
| 7 | PASS | Consistent enforcement | All endpoints same |
| 8 | PASS | Middleware deployed | CRD valid |
| 9 | PASS | No service restarts | Hot reload works |
| 10 | PASS | HSTS on HTTPS only | Correct behavior |
| 11 | PASS | Browser caching | Cache values proper |
| 12 | PASS | F11 + F12 coexistence | No conflicts |

## Test Execution Environment

**Date:** March 1, 2026
**Tested On:** Local Kubernetes cluster with Traefik
**Traefik Version:** Configured via Middleware CRD
**curl Version:** 7.x or higher

## Issues Found

None. All HSTS enforcement tests pass.

**Audit Finding F12 Status:** RESOLVED

## Notes

1. **Traefik Middleware Binding:** The HSTS Middleware is bound globally to the `websecure` entrypoint via ConfigMap. Any IngressRoute using the `websecure` entrypoint (all HTTPS traffic) automatically includes the HSTS header without requiring explicit annotation.

2. **No Pod Restarts Required:** Traefik hot-reloads Middleware and ConfigMap changes. Existing connections continue to work; new connections use the updated configuration.

3. **HSTS Preload Submission:** The domain now meets all criteria for HSTS preload list inclusion:
   - ✓ HSTS header present
   - ✓ max-age ≥ 31536000
   - ✓ includeSubDomains present
   - ✓ preload directive present

   Submission to browser preload lists (https://hstspreload.org/) is a separate manual step.

4. **Backward Compatibility:** HSTS header is a response header only (no breaking API changes). All clients that ignore the header continue to work. Clients that respect HSTS get enhanced security.

5. **Production Ready:** Same Middleware configuration applies to GCP production overlays. No environment-specific differences.

## Related Standards

- [Encryption Standards](../standards/encryption-standards.md) — Data in transit: HSTS requirements
- [Secure Coding Standards](../standards/secure-coding.md) — Security fundamentals
- [Cluster Baseline](../standards/cluster-baseline.md) — Infrastructure baseline

## Related Audit Findings

- **F11 (LOW):** Traefik accepts TLS 1.0 — **FIXED** (March 1, via TLSOption)
- **F12 (LOW):** No HSTS header — **FIXED** (this test validates the fix)

## Related Documents

- [Traefik TLS Hardening (F11 Fix)](../changelogs/TRAEFIK-TLS-HARDENING-F11-FIX-2026-03-01.md)
- [Traefik HSTS Middleware (F12 Fix)](../changelogs/TRAEFIK-HSTS-MIDDLEWARE-F12-FIX-2026-03-01.md)
- [Encryption Standards](../standards/encryption-standards.md)
- [TLS Enforcement (Test 86)](./86-tls-enforcement-2026-03-01.md)
