# Security Audit (Fresh) — 2026-03-15

## Scope

Full security code review across all 12 BlockSecOps repositories. Covers dependencies, secrets exposure, Docker image security, OWASP Top 10, and NetworkPolicy enforcement.

**Method:** Static code review (no live cluster access)
**Previous audit:** security-audit-2026-03-14.md (all passed)

---

## 1A — Dependency Vulnerability Scan

### Findings

| ID | Severity | Repo | Finding | File |
|----|----------|------|---------|------|
| SEC-001 | HIGH | api-service | `python-jose[cryptography]>=3.3.0` — unmaintained since 2022, CVE-2024-33663/33664 (JWT algorithm confusion). Migrate to PyJWT or joserfc | requirements/base.txt:23 |
| SEC-002 | HIGH | notification | `cryptography>=41.0.7,<42.0.0` — upper pin blocks CVE fixes (CVE-2024-26130, CVE-2025-0686). Raise floor to >=42.0.5 | requirements/base.txt:84 |
| SEC-003 | MEDIUM | api-service | `Pillow>=10.1.0,<11.0.0` — floor allows CVE-2024-28219 (buffer overflow). Raise to >=10.3.0 | requirements/base.txt:68 |
| SEC-004 | MEDIUM | 5 Python services | `aiohttp>=3.9.1` — floor allows CVE-2024-23829 (HTTP request smuggling). Raise to >=3.9.4 | requirements/base.txt (all) |
| SEC-005 | HIGH | orchestration | `redlock-py>=1.0.8` — abandoned (archived 2017). Replace with redis built-in Lock() | requirements/base.txt:53 |
| SEC-006 | MEDIUM | orchestration | `hiredis>=3.0.0` — no upper pin (all other repos cap it). Add ceiling | requirements/base.txt:16 |

### Version Pinning Summary

| Repo | Style | Risk |
|------|-------|------|
| api-service (47 deps) | All `>=` with ceilings | MEDIUM — floor versions may be vulnerable |
| tool-integration (28 deps) | All `>=` with ceilings | LOW |
| orchestration (42 deps) | All `>=` with ceilings | MEDIUM — 1 no-ceiling |
| data-service (40 deps) | All `>=` with ceilings | LOW |
| intelligence-engine (5 deps) | Mixed `==`/`>=` | LOW — tightest pins |
| notification (44 deps) | All `>=` with ceilings | MEDIUM |
| dashboard (27 deps) | `^` ranges (npm standard) | LOW |
| admin-portal (8 deps) | `^` ranges | LOW |
| contract-parser (9 deps) | Bare major (Cargo standard) | LOW — Cargo.lock present |

---

## 1B — Secrets Exposure Scan

### Findings

| ID | Severity | Repo/File | Finding |
|----|----------|-----------|---------|
| SEC-007 | **CRITICAL** | docs/audits/scripts/audit-tier-v4.py:40 | **Production JWT signing secret hardcoded** — targets app.0xapogee.com. Anyone with repo access can forge JWTs. ROTATE IMMEDIATELY |
| SEC-008 | **CRITICAL** | bso-website/ecosystem.config.js:15 | **Production PAYLOAD_SECRET hardcoded** — [REDACTED, rotated] |
| SEC-009 | **CRITICAL** | bso-website/ecosystem.config.js:22 | **Production Cloudflare Turnstile secret key hardcoded** — [REDACTED, rotated] |
| SEC-010 | **CRITICAL** | advanced-blockchain-security-website/ecosystem.config.js:15 | **Production PAYLOAD_SECRET hardcoded** — second website CMS secret |
| SEC-011 | HIGH | docs/audits/scripts/audit-org-team-subscription.py:40 | JWT secret `local-dev-jwt-secret-key-change-in-production` — script targets production URL |
| SEC-012 | HIGH | docs/audits/scripts/load-test-by-tier.py:31 | Same JWT secret as SEC-011 |
| SEC-013 | HIGH | docs/audits/scripts/audit-auth-x402.py:48 | Same JWT secret as SEC-011 |
| SEC-014 | HIGH | notification/k8s/overlays/local/externalsecret.yaml:38 | Hardcoded plaintext webhook secret in ExternalSecret template |
| SEC-015 | HIGH | shared/k8s/base/vault-setup/secrets-init-job.yaml:83-90 | Hardcoded local dev credentials: postgres password, scanner API keys |
| SEC-016 | HIGH | api-service/seed_patterns_simple.py:22 | Hardcoded DB password `password='postgres'` |
| SEC-017 | HIGH | api-service (6+ files) | Hardcoded `password='postgres'` in seeds/*.py and tests/integration/*/conftest.py |
| SEC-018 | MEDIUM | api-service/scripts/create_test_tier_users.py:60 | Test password `TestPass123!` — if these users exist in production, escalates to HIGH |
| SEC-019 | MEDIUM | docs/rca/2026-03-03-scanner-503-service-token-mismatch.md:20,61 | RCA doc contains actual service tokens |

### .env Files in Git

[x] PASS — No actual `.env` files committed. All `.env.example` files contain only placeholders.

### ConfigMaps

[x] PASS — Secrets properly migrated to ExternalSecrets/Vault. Migration comments confirm cleanup.

---

## 1C — Docker Image Security

### Summary

| Service | Multi-stage | Non-root | SHA-pinned | OCI Labels | Port Match | Secrets | HEALTHCHECK | .dockerignore |
|---------|:-----------:|:--------:|:----------:|:----------:|:----------:|:-------:|:-----------:|:-------------:|
| api-service | [x] | [x] | [x] | [x] | [x] | [x] | [x] | [x] |
| tool-integration | [x] | [x] | [x] | [x] | [x] | [x] | [x] | [x] |
| orchestration | [x] | [x] | [!] | [x] | [x] | [x] | [x] | [x] |
| data-service | [x] | [x] | [x] | [x] | [x] | [x] | [x] | [x] |
| intelligence-engine | [x] | [x] | [!] | [x] | [x] | [x] | [x] | [x] |
| notification | [x] | [x] | [x] | [x] | [x] | [x] | [x] | [x] |
| dashboard | [x] | [x] | [!] | [x] | [x] | [x] | [x] | [x] |
| admin-portal | [x] | [x] | [!] | [!] | [x] | [x] | [x] | [!] |
| contract-parser | [x] | [x] | [x] | [x] | [x] | [x] | [x] | [x] |
| shared | [x] | [!] | [!] | [!] | N/A | [x] | N/A | [x] |

### Findings

| ID | Severity | Service | Finding |
|----|----------|---------|---------|
| SEC-020 | HIGH | orchestration | Base image referenced by mutable tag, no SHA256 digest |
| SEC-021 | HIGH | intelligence-engine | Base image referenced by mutable tag, no SHA256 digest |
| SEC-022 | HIGH | dashboard | `node:20-alpine` — no SHA256 digest (lines 4, 99) |
| SEC-023 | HIGH | admin-portal | `node:20-alpine` — no SHA256 digest; missing .dockerignore; missing OCI `source` label |
| SEC-024 | HIGH | shared | Runs as root (no USER directive); no OCI labels; unpinned rust/node base images |
| SEC-025 | MEDIUM | dashboard, admin-portal | Uses `npm install` instead of `npm ci` — non-deterministic builds |
| SEC-026 | MEDIUM | tool-integration | `docker.io` installed in runtime image with docker group — privilege escalation vector if socket mounted |
| SEC-027 | LOW | 5 Python services | `--reload` flag in default CMD — development setting in production image |

---

## 1D — OWASP Top 10

### A01 Broken Access Control

| ID | Severity | Service | Finding |
|----|----------|---------|---------|
| SEC-028 | HIGH | tool-integration | **10 endpoints lack authentication**: /scans/{id}/status, /scanners/status, /scanners/health, /scanners/{name}/upgrade (can upgrade without auth), /api/v1/scans/{id}/results (accepts results without auth), /cluster/metrics, /api/v1/dead-letters (list/retry/delete) |
| SEC-029 | MEDIUM | orchestration | 3 read endpoints without auth: GET /scans/{id}, /scans/{id}/status, /scans/{id}/findings |
| SEC-030 | ADVISORY | intelligence-engine | All endpoints unauthenticated — acceptable only if NetworkPolicy enforced (see SEC-038) |
| SEC-031 | MEDIUM | notification | GET /notifications/recent and /notifications/stats lack auth |

### A03 Injection

| ID | Severity | Service | Finding |
|----|----------|---------|---------|
| SEC-032 | MEDIUM | data-service | `execute_query()` accepts raw SQL string — safe only if all callers use static queries. No parameterized query enforcement at function boundary |

### A05 Security Misconfiguration

| ID | Severity | Service | Finding |
|----|----------|---------|---------|
| SEC-033 | MEDIUM | orchestration | Hardcoded localhost CORS origins (`http://localhost:3000`, `http://127.0.0.1:3000`) in production image |
| SEC-034 | MEDIUM | tool-integration | `HTTPException(detail=str(e))` leaks internal errors (DB errors, connection strings) to clients |

### A07 Authentication Failures

[x] PASS — JWT validation in api-service uses JWKS with timeout. Notification validates algorithm and audience.
[~] ADVISORY — Notification missing JWT issuer (`iss`) validation (low risk, single issuer)

### A10 SSRF

| ID | Severity | Service | Finding |
|----|----------|---------|---------|
| SEC-035 | HIGH | tool-integration | Dead-letter retry endpoint (`POST /api/v1/dead-letters/{entry_id}/retry`) forwards HTTP POST to stored `target_url`. Combined with unauthenticated results endpoint (SEC-028), attacker can poison dead-letter store and trigger SSRF to arbitrary URLs |

---

## 1E — NetworkPolicy Review

### Findings

| ID | Severity | Service | Finding |
|----|----------|---------|---------|
| SEC-036 | HIGH | api-service | Contract-parser egress port 8007 (line 350) — actual port is 9000. Traffic blocked |
| SEC-037 | HIGH | orchestration (base+prod) | No default-deny-all policy; `to: []` egress for DNS/PostgreSQL/Redis allows any destination |
| SEC-038 | HIGH | intelligence-engine (prod) | No default-deny-all; wrong ingress port 8002 (actual 8000); `to: []` egress rules |
| SEC-039 | HIGH | admin-portal | No default-deny-all policy |
| SEC-040 | HIGH | shared (prod) | No default-deny-all; `to: []` for DNS/HTTP/HTTPS egress |
| SEC-041 | MEDIUM | gcp-infra PostgreSQL | Ingress uses OR logic between namespaceSelector and podSelector — wider access than intended |
| SEC-042 | LOW | data-service, intelligence-engine, notification, dashboard, contract-parser | DNS egress uses `namespaceSelector: {}` — should target kube-system only |

---

## Summary

| Severity | Count | Details |
|----------|-------|---------|
| **CRITICAL** | 4 | SEC-007 (production JWT secret in repo), SEC-008/009/010 (website secrets in repo) |
| **HIGH** | 20 | SEC-001/002/005 (deps), SEC-011-017 (hardcoded creds), SEC-020-024 (Docker), SEC-028/035 (OWASP), SEC-036-040 (NetworkPolicy) |
| **MEDIUM** | 12 | SEC-003/004/006 (deps), SEC-018/019/025/026 (secrets/Docker), SEC-029/031-034 (OWASP), SEC-041 (NetworkPolicy) |
| **LOW** | 3 | SEC-027, SEC-042, JWT issuer advisory |
| **ADVISORY** | 2 | Intelligence-engine auth, notification JWT issuer |

### Remediation Status

| Finding | Status | Change |
|---------|--------|--------|
| SEC-001 | **FIXED** | Replaced python-jose with PyJWT[crypto] in api-service (requirements + 6 source files) |
| SEC-005 | **FIXED** | Removed abandoned redlock-py from orchestration (unused dead dependency) |
| SEC-007 | **FIXED** | Removed hardcoded JWT secret from audit scripts; now reads SUPABASE_JWT_SECRET env var |
| SEC-008/009/010 | **FIXED** | Replaced hardcoded secrets in website ecosystem.config.js with process.env references |
| SEC-011/012/013 | **FIXED** | Same as SEC-007 — all 4 audit scripts updated |
| SEC-023 | **FIXED** | Created .dockerignore for admin-portal |
| SEC-028 | **FIXED** | Added verify_internal_token auth to all 10 unprotected tool-integration endpoints |
| SEC-035 | **FIXED** | Added SSRF prevention — dead-letter retry validates target_url against configured api-service URL |
| SEC-036 | **FIXED** | api-service base NetworkPolicy: contract-parser egress port 8007→9000 |
| SEC-038 | **FIXED** | intelligence-engine production overlay: ingress port 8002→8000; replaced `to: []` egress with scoped namespace selectors |
| SEC-020/021/022/024 | OPEN | SHA-pinned base images — requires registry digest lookup (orchestration, intelligence-engine, dashboard, shared) |
| SEC-002 | OPEN | cryptography upper pin in notification — requires testing |
| SEC-037/039/040 | OPEN | Missing default-deny-all in orchestration, admin-portal, shared production overlays |

### Comparison to Previous Audit (2026-03-14)

| Area | Previous | Current | Delta |
|------|----------|---------|-------|
| Kustomize includeSelectors | Fixed | Still fixed | No regression |
| Dependency CVEs | Fixed (urllib3, cryptography, pyjwt, axios) | New: python-jose, Pillow, aiohttp, redlock-py | 4 new findings |
| Wallet/x402 removal | Completed | Still clean | No regression |
| Secrets in repo | Not checked | **4 CRITICAL** | New scope |
| Docker SHA pinning | Not checked | **5 services missing** | New scope |
| NetworkPolicy ports | Not checked | **2 mismatches** | New scope |
| OWASP/SSRF | Not checked | **1 HIGH SSRF** | New scope |
