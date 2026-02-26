# Feature Test 81: Platform Security Audit

**Date:** February 25, 2026
**Services:** All platform services
**Status:** All tests passing

---

## Scope

Full platform security audit covering SQL injection, XSS, prompt injection, dependency vulnerabilities, Docker hardening, Kubernetes security, authentication, and network isolation.

## Automated Audit Suites

### K8s Security Audit (07)

| Check | Result |
|-------|--------|
| Pod security (runAsNonRoot, runAsUser) — 8 services | 16/16 PASS |
| Container security (readOnlyRootFilesystem, allowPrivilegeEscalation) — 8 services | 16/16 PASS |
| Seccomp profile (RuntimeDefault) — 8 services | 8/8 PASS |
| NetworkPolicies (default deny + allow rules) — 8 namespaces | 8/8 PASS |
| revisionHistoryLimit: 3 — 8 services | 8/8 PASS |
| Resource limits (CPU/memory) — 8 services | 8/8 PASS |
| Image tags (no :latest) | 1/1 PASS |
| **Total** | **65/65 PASS** |

### Application Security (09)

| Check | Result |
|-------|--------|
| strict-transport-security (HSTS 1 year, includeSubdomains, preload) | PASS |
| x-content-type-options: nosniff | PASS |
| x-frame-options: DENY | PASS |
| content-security-policy (CSP with strict directives) | PASS |
| CORS blocks unauthorized origins | PASS |
| **Total** | **5/5 PASS** |

### Authentication & Authorization (06)

| Check | Result |
|-------|--------|
| Invalid API key rejected | PASS |
| CORS blocks evil origins | PASS |
| Unauthenticated request blocked | PASS |
| **Total** | **3/3 PASS** |

### Database Integrity (08)

| Check | Result |
|-------|--------|
| ENUM constraints exist (6 types) | PASS |
| audit_logs table exists | PASS |
| audit_logs has protection triggers (2) | PASS |
| Performance indexes (64, min 3) | PASS |
| Vulnerability severity query uses index | PASS |
| vulnerability_patterns loaded (415, min 393) | PASS |
| pattern_tool_mappings loaded (707, min 637) | PASS |
| No info/informational severity in patterns | PASS |
| **Total** | **8/8 PASS** |

### Auth & x402 Payment Audit (Python)

| Section | Result |
|---------|--------|
| JWT Authentication | 8/8 PASS |
| Ethereum Wallet Auth | 8/8 PASS |
| Solana Wallet Auth | 7/7 PASS |
| API Key Authentication | 10/10 PASS |
| OAuth Provider Callbacks | 5/5 PASS |
| x402 Payment — Public | 5/5 PASS |
| x402 Payment — Authenticated | 6/6 PASS |
| Billing & Subscription | 8/8 PASS |
| Admin Payment Endpoints | 4/4 PASS |
| Cross-Auth Verification | 3/3 PASS |
| **Total** | **64/64 PASS** |

## Grand Total: 145/145 PASS

## Issues Found and Fixed

| Severity | Issue | Fix |
|----------|-------|-----|
| CRITICAL | SQL injection endpoint in data-service | Endpoint removed |
| CRITICAL | CORS wildcard + credentials in data-service | Restricted origins |
| CRITICAL | Unauthenticated schema disclosure in data-service | Added auth requirement |
| HIGH | 7 dependency version vulnerabilities | Minimum versions bumped |
| MEDIUM | 8 issues (Docker pinning, error leaks, DOMPurify, etc.) | All remediated |
| — | Security headers missing on dashboard HTTPS | Middleware + HSTS added |
| — | 2 IngressRoutes not tracked in Git | Codified in kustomize |
| — | Traefik hostPort not configured | hostPort 80/443 added |
| — | Audit script wrong table name | Corrected to pattern_tool_mappings |

## Phase 2 Remediation (February 25, 2026)

### Completed

| Item | Severity | Fix Applied | PR |
|------|----------|------------|-----|
| M2: Admin endpoint rate limits | MEDIUM | 49 rate limit decorators across 8 admin files (20/min reads, 5/min writes, 3/min sensitive ops) | api-service #272 |
| M5: Data service rate limiting | MEDIUM | slowapi middleware with Redis backing, 60/min reads, 30/min writes | data-service #33 |
| M7: Network egress policies | MEDIUM | Default-deny egress added to postgresql, redis, vault namespaces | gcp-infrastructure #22 |
| M8: Traefik RBAC | MEDIUM | Removed nodes, pods, configmaps from ClusterRole (kept services, endpoints, secrets for TLS) | gcp-infrastructure #22 |
| H3: Notification CORS wildcard | HIGH | Replaced `allow_origins=["*"]` with environment-based origin list | notification #38 |
| H5: Data service health info disclosure | HIGH | Generic "unhealthy" returned to client, error logged server-side | data-service #32 |
| H6: Notification input validation | HIGH | Pydantic Field constraints (max_length, ge/le bounds) | notification #38 |
| H7: Notification error leakage | HIGH | Generic error messages, details logged server-side | notification #38 |
| M4: WebSocket JWT fallback | MEDIUM | Removed `verify_signature=False` fallback, connections rejected without secret | notification #38 |

### Deployed Versions

| Service | Version | Harbor Tag |
|---------|---------|------------|
| api-service | 0.29.33 | `blocksecops/api-service:0.29.33` |
| data-service | 0.2.4 | `blocksecops/data-service:0.2.4` |
| notification | 0.2.3 | `blocksecops/notification:0.2.3` |

### Phase 3: Post-Audit Deployment Fixes (February 26, 2026)

| Item | Severity | Fix Applied | PR |
|------|----------|------------|-----|
| H1: Dashboard npm vulnerabilities | HIGH | Reduced from 43 (1 critical, 3 high) to 32 (0 critical, 0 high). jspdf 4.2.0, react-syntax-highlighter 16.1.0 | dashboard #168 |
| L2: OAuth security logging | LOW | Structured security event logging on all OAuth callback paths | api-service #273 |
| Orchestration broken image | — | 0.10.3 had stale Docker cache (missing module), rebuilt as 0.10.4 | orchestration #83 |
| Intelligence engine deploy | — | 0.3.2 image built and deployed (was stuck at 0.3.1) | — |
| Postgres exporter fix | — | Changed user `postgres` → `blocksecops`, `sslmode=disable` → `sslmode=require` | gcp-infrastructure #23 |

### Phase 3 Deployed Versions

| Service | Version | Harbor Tag |
|---------|---------|------------|
| api-service | 0.29.34 | `blocksecops/api-service:0.29.34` |
| dashboard | 0.46.6 | `blocksecops/dashboard:0.46.6` |
| intelligence-engine | 0.3.2 | `blocksecops/intelligence-engine:0.3.2` |
| orchestration | 0.10.4 | `blocksecops/orchestration:0.10.4` |

### Remaining Low-Severity (Accepted Risk)

| Item | Severity | Status |
|------|----------|--------|
| L1: JWT refresh token rotation | LOW | N/A — Supabase handles token lifecycle |
| L3: CORS docs alignment | LOW | Already aligned, no changes needed |
| L4: Redis list growth | LOW | ltrim already in place (RC-FIX-043, max 10,000 entries) |
| Dashboard npm (32 remaining) | LOW/MODERATE | Deep transitive deps in wallet adapter (elliptic, lodash) — requires upstream fixes |

### Known Issue

**Intelligence engine ML model not in image**: The `all-MiniLM-L6-v2` model (~80MB) downloads from HuggingFace on every pod restart, causing readiness probe timeouts. Should be pre-downloaded during Docker build.

## Pre-Existing Warnings (Not from this audit)

- CORS: Missing response for authorized origin (auth)
