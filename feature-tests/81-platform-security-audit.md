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

### Resolved: Intelligence Engine ML Model (v0.3.3)

The `all-MiniLM-L6-v2` model is now pre-downloaded into the Docker image at `/opt/ml-models` during build. An initContainer copies it to the `/app/models` emptyDir volume before the main container starts. `HF_HUB_OFFLINE=1` blocks all runtime HuggingFace network calls. Pod starts immediately without download delays.

### Phase 4: Deduplication Security & UI Fixes (February 26, 2026)

| Item | Severity | Fix Applied | PR |
|------|----------|------------|-----|
| BSO-SEC-015: Dedup endpoint org scoping | HIGH | All 8 dedup endpoints now enforce org-scoped access via ContractModel join | api-service #TBD |
| Maintenance endpoints privilege escalation | HIGH | Changed from `get_current_user` to `get_current_active_superuser` | api-service #TBD |
| Cross-contract merge validation | MEDIUM | Added contract_id check to prevent merging groups across projects | api-service #TBD |
| Dedup UI: Compare Scanners not working | MEDIUM | Wired `onCompare` callback, renders ScannerComparisonView | dashboard #TBD |
| Dedup UI: View toggle not working | MEDIUM | URL param-based view mode, ScannerComparisonView integration | dashboard #TBD |
| Dedup UI: Dark mode gaps | MEDIUM | Added dark: variants to all dedup pages, error blocks, badges, filters | dashboard #TBD |
| Source code viewer bright white bg | MEDIUM | Default theme set to dark, theme-aware inline highlight colors | dashboard #TBD |
| Unsafe `as ViewMode` URL cast | LOW | Validated URL param before use instead of blind cast | dashboard #TBD |
| Unsafe `as any` type cast | LOW | Refactored handleGroupClick to accept string directly | dashboard #TBD |

### Phase 5: Encryption Standards Compliance (February 26, 2026)

| Item | Severity | Fix Applied | Service |
|------|----------|------------|---------|
| BSO-JWT-002: No runtime JWT key length validation | MEDIUM | Added min 256-bit (32-byte) check for HS256 keys at startup | api-service |
| BSO-HASH-002: uuid4 instead of secrets module | MEDIUM | Replaced uuid4().hex with secrets.token_hex() for salts, API keys, sessions | shared library |
| BSO-SEC-362: tempfile standard clarification | LOW | Updated encryption-standards.md: stdlib tempfile.TemporaryDirectory() is compliant | docs |
| BSO-ENC-005: 10+ hardcoded http:// URLs | MEDIUM | Extracted to API_SERVICE_URL env var (already in ConfigMap), updated 3 files | tool-integration |

### Phase 5 Deployed Versions

| Service | Version | Harbor Tag |
|---------|---------|------------|
| api-service | 0.29.36 | `blocksecops/api-service:0.29.36` |
| tool-integration | 0.5.5 | `blocksecops/tool-integration:0.5.5` |

---

## Phase 6: Comprehensive Security Audit Remediation (February 26, 2026)

Cross-service security audit against OWASP Top 10, encryption standards, authentication, authorization, and input validation. False positives validated against source code before fixes applied.

### Critical Fixes

| Finding | Severity | Fix | Service |
|---------|----------|-----|---------|
| C1: Wildcard CORS with credentials | CRITICAL | Replaced `allow_origins=["*"]` with env-var-based origins, `allow_credentials=False` | tool-integration |
| C2: Auth bypass when no token configured | CRITICAL | Changed fail-open to fail-closed (503 if token not configured) | orchestration |
| C3: JWT validation stub returns hardcoded data | CRITICAL | Replaced with deprecation error pointing to api-service JWT module | shared library |

### High Fixes

| Finding | Severity | Fix | Service |
|---------|----------|-----|---------|
| H1: Missing auth on POST /notifications/send | HIGH | Added X-Internal-Service-Token verification | notification |
| H2: WebSocket broadcasts to unauthenticated | HIGH | Added `broadcast_authenticated()` method, updated `broadcast_notification()` | notification |
| H3: print() bypasses log filtering | HIGH | Replaced all `print()` with `logger.info()` | orchestration |
| H4: Table name not whitelisted | HIGH | Added explicit `_ALLOWED_TABLES` whitelist | data-service |
| H5: dangerouslySetInnerHTML for recommendations | HIGH | Replaced with plain text `<p>` rendering | dashboard |
| H6: Missing path traversal validation | HIGH | Added `pathlib.resolve()` + prefix validation in base.py and solidity_scanners.py | orchestration |

### Medium Fixes

| Finding | Severity | Fix | Service |
|---------|----------|-----|---------|
| M1: Archive compression ratio 100:1 | MEDIUM | Reduced to 10:1 per OWASP recommendation | api-service |
| M2: Missing auth on /scans/{scan_id}/trigger | MEDIUM | Added `verify_internal_token` dependency | tool-integration |
| M3: Missing input size validation on embeddings | MEDIUM | Added 10MB total payload size limit | intelligence-engine |
| M4: Unbounded JSON parsing | MEDIUM | Added 50MB size check before `json.loads()` | tool-integration |
| M5: Error messages leak response body | MEDIUM | Sanitized to log only HTTP status code | tool-integration |
| M6: `unwrap()` on f64 conversion | MEDIUM | Replaced with `unwrap_or(0)` safe default | shared (Rust) |
| M7: Missing bounds validation in risk score | MEDIUM | Added `clamp()` on all inputs to valid ranges | shared (Rust) |

### False Positives Eliminated

| Finding | Reason |
|---------|--------|
| Stripe webhook signature bypass | Already has `stripe.Webhook.construct_event()` verification |
| Data service SQL injection | Uses parameterized query (`:table_name` binding) |
| WebSocket auth missing | Already has JWT validation (RC-FIX-041/044) |
| Notification error leakage | Already returns generic error message |

### Phase 6 Deployed Versions

| Service | Version | Harbor Tag |
|---------|---------|------------|
| api-service | 0.29.37 | `blocksecops/api-service:0.29.37` |
| dashboard | 0.46.8 | `blocksecops/dashboard:0.46.8` |
| data-service | 0.2.5 | `blocksecops/data-service:0.2.5` |
| intelligence-engine | 0.3.4 | `blocksecops/intelligence-engine:0.3.4` |
| notification | 0.2.4 | `blocksecops/notification:0.2.4` |
| orchestration | 0.10.5 | `blocksecops/orchestration:0.10.5` |
| tool-integration | 0.5.6 | `blocksecops/tool-integration:0.5.6` |

## Pre-Existing Warnings (Not from this audit)

- CORS: Missing response for authorized origin (auth)
