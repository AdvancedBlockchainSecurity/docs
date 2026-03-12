# Platform Security Audit Report

**Date:** February 25, 2026
**Scope:** Full platform — all services, dependencies, Docker images
**Auditor:** Apogee Security Review
**Status:** Remediated

---

## Executive Summary

Platform-wide security audit covering input validation, SQL injection, XSS, prompt injection, dependency vulnerabilities, encryption, and Docker image hardening. Found **3 critical**, **7 high**, and **8 medium** issues. All have been remediated.

**Overall Security Posture:** Strong — the API service demonstrates excellent security engineering. The critical issues were isolated to the internal Data Service.

---

## Critical Findings (Fixed)

### C1. SQL Injection — Data Service Arbitrary Query Endpoint
- **Severity:** CRITICAL
- **File:** `blocksecops-data-service/src/routes/data.py:83-99`
- **Issue:** `POST /api/v1/data/query` accepted arbitrary SQL and executed it without authentication
- **Mitigation:** NetworkPolicy limited access to internal services only
- **Fix:** Endpoint removed entirely. Arbitrary SQL execution is never safe.

### C2. CORS Wildcard + Credentials — Data Service
- **Severity:** CRITICAL
- **File:** `blocksecops-data-service/src/main.py:44-51`
- **Issue:** `allow_origins=["*"]` with `allow_credentials=True`
- **Fix:** Replaced with empty origin list (internal service, no browser access), `allow_credentials=False`, restricted methods/headers

### C3. Unauthenticated Schema Disclosure — Data Service
- **Severity:** CRITICAL
- **Files:** `blocksecops-data-service/src/routes/data.py:29-80`
- **Issue:** Table/column enumeration without authentication
- **Fix:** All data endpoints now require `X-Internal-Service-Key` header with constant-time comparison

---

## High Findings (Fixed)

| ID | Issue | Affected Services | Fix |
|----|-------|-------------------|-----|
| H1 | SQLAlchemy <2.0.25 ORM injection risk | 5 services | Bumped to >=2.0.25 |
| H2 | Jinja2 <3.1.4 template sandbox escape | notification | Bumped to >=3.1.4 |
| H3 | redis no upper bound | orchestration | Added <6.0.0 |
| H4 | ML packages over-pinned (==) | intelligence-engine | Changed to >= ranges |
| H5 | pydantic ==2.5.2 validation bypass | intelligence-engine | Changed to >=2.5.4 |
| H6 | Deprecated slackclient | notification | Removed (slack-sdk kept) |
| H7 | httpx <0.26.0 proxy cert validation | multiple | Bumped to >=0.26.0 |

---

## Medium Findings (Fixed)

| ID | Issue | Fix |
|----|-------|-----|
| M1 | asyncpg <0.29.1 memory leak | Bumped to >=0.29.1 |
| M2 | email-validator <2.1.1 Unicode bypass | Bumped to >=2.1.1 |
| M3 | Stripe <7.4.0 TLS deprecation | Bumped to >=7.4.0 |
| M4 | DOMPurify <3.3.5 iframe sanitization | Bumped to ^3.3.5 |
| M5 | Zod version misalignment | Standardized to ^3.25.76 |
| M6 | Docker base images not SHA-pinned | Pinned all to SHA256 |
| M7 | --break-system-packages in shared | Replaced with virtualenv |
| M8 | Error details leaked in responses | Sanitized to generic messages |

---

## Positive Findings (Already Secure)

| Area | Implementation | Rating |
|------|---------------|--------|
| Password hashing | Argon2id (time=3, mem=64MiB) | Excellent |
| API key storage | SHA-256 hashed, scoped, expirable | Excellent |
| OAuth token encryption | Fernet (AES-128-CBC + HMAC-SHA256) | Good |
| OAuth CSRF protection | JWT-encoded state with nonce, 15min expiry | Excellent |
| Prompt injection defense | Input sanitization + output validation + XML boundaries | Excellent |
| Security headers | Full OWASP set (CSP, HSTS, X-Frame, etc.) | Excellent |
| Rate limiting | Redis-backed, fail-closed in production | Excellent |
| MFA/Admin auth | Rate limited (3/min), lockout (5 attempts/15min) | Excellent |
| File upload security | Path traversal prevention, tier-based size limits | Excellent |
| Webhook verification | HMAC signature, replay protection, SSRF blocking | Excellent |
| SQL injection (API service) | Parameterized SQLAlchemy ORM throughout | Excellent |
| Production config validation | Enforces secrets, rejects insecure defaults | Excellent |
| Network isolation | Default-deny NetworkPolicy on data service | Good |

---

## Post-Audit Fixes

### Security Headers (Dashboard)

- Dashboard HTTPS IngressRoute (`dashboard-server`) was missing security-headers middleware
- HSTS (`strict-transport-security`) was not configured in the middleware
- **Fix:** Created `ingressroute-server.yaml` with middleware reference; added `stsSeconds`, `stsIncludeSubdomains`, `stsPreload` to middleware
- **Verified:** AppSec audit 14/14 PASS (HSTS, CSP, X-Frame-Options, X-Content-Type-Options)

### Codebase-First IngressRoute Codification

Two IngressRoutes existed only in the cluster (not tracked in Git), violating codebase-first standards:

1. **api-service-server** — HTTPS IngressRoute for `PathPrefix(/api/v1)` → codified in `blocksecops-api-service/k8s/overlays/local/api-service/ingressroute-server.yaml`
2. **app-http-redirect + redirect-https middleware** — HTTP→HTTPS redirect → codified in `blocksecops-gcp-infrastructure/k8s/overlays/local/traefik/`

### Traefik hostPort Binding

- Traefik was only accessible via NodePort (30543/30180), requiring volatile iptables NAT rules
- **Fix:** Added `hostPort: 80` and `hostPort: 443` to Traefik deployment local overlay
- **Result:** `https://app.0xapogee.com` accessible immediately after cluster start per service access standards

### Audit Script Bug Fix

- Database integrity audit section 8.10 queried nonexistent `scanner_pattern_mappings` table
- Actual table is `pattern_tool_mappings` (707 rows, threshold 637)
- **Fix:** Corrected table name in `scripts/audit/08-database-integrity.sh`

---

## Verification Results (All Suites)

| Suite | Result |
|-------|--------|
| K8s Security (07) | 65/65 PASS |
| AppSec (09) | 5/5 PASS |
| Auth (06) | 3/3 PASS |
| Database Integrity (08) | 8/8 PASS |
| Auth x402 (Python) | 64/64 PASS |
| **Total** | **145/145 PASS** |

---

## Repos Modified

| Repository | Changes |
|------------|---------|
| blocksecops-data-service | CORS fix, auth on data endpoints, query endpoint removed, version bump, security tests |
| blocksecops-api-service | Dependency version bumps, Dockerfile SHA pinning, IngressRoute codification |
| blocksecops-orchestration | redis upper bound, sqlalchemy bump |
| blocksecops-notification | jinja2 bump, slackclient removed, sqlalchemy bump |
| blocksecops-tool-integration | sqlalchemy bump, Dockerfile SHA pinning |
| blocksecops-intelligence-engine | ML package pin loosening, pydantic bump |
| blocksecops-dashboard | DOMPurify bump, security-headers middleware, HSTS, IngressRoute codification |
| blocksecops-shared | Zod bump, --break-system-packages fix, Dockerfile SHA pinning |
| blocksecops-gcp-infrastructure | HTTP→HTTPS redirect codification, Traefik hostPort binding |
| docs | Audit script table name fix, version updates, documentation |
