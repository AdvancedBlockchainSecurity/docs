# Comprehensive Platform Audit — 2026-03-15

## Scope

Fresh code review across all 12 BlockSecOps repositories. Covers security, platform health, auth, API endpoints, test coverage, tier/billing, intelligence/ML, performance, behavioral, and readiness.

**Method:** Static code review (no live cluster access)
**Repos audited:** 12 (api-service, tool-integration, orchestration, data-service, intelligence-engine, notification, dashboard, admin-portal, contract-parser, shared, cli, gcp-infrastructure)

---

## All Findings

### Phase 1: Security (SEC-)

| ID | Severity | Status | Finding |
|----|----------|--------|---------|
| SEC-001 | HIGH | **FIXED** | `python-jose` CVE-2024-33663/33664 → replaced with PyJWT[crypto] |
| SEC-002 | HIGH | **FIXED** | `cryptography` upper pin blocking CVE fixes → raised to >=42.0.5 |
| SEC-003 | MEDIUM | OPEN | `Pillow>=10.1.0` floor allows CVE-2024-28219. Raise to >=10.3.0 |
| SEC-004 | MEDIUM | OPEN | `aiohttp>=3.9.1` floor allows CVE-2024-23829. Raise to >=3.9.4 (5 services) |
| SEC-005 | HIGH | **FIXED** | `redlock-py` abandoned → removed (dead dependency) |
| SEC-006 | MEDIUM | OPEN | `hiredis>=3.0.0` no upper pin in orchestration |
| SEC-007 | CRITICAL | **FIXED** | Production JWT secret in audit script → env var |
| SEC-008-010 | CRITICAL | **FIXED** | Website secrets in ecosystem.config.js → process.env |
| SEC-011-013 | HIGH | **FIXED** | Audit script JWT secrets → env vars |
| SEC-014-017 | HIGH | NOTED | Hardcoded dev credentials in seed/vault-setup scripts (local dev only) |
| SEC-020-024 | HIGH | OPEN | Missing SHA-pinned base images (5 services — needs registry digest lookup) |
| SEC-023 | HIGH | **FIXED** | admin-portal missing .dockerignore → created |
| SEC-025 | MEDIUM | OPEN | dashboard/admin-portal use `npm install` not `npm ci` |
| SEC-026 | MEDIUM | NOTED | tool-integration runtime has docker.io installed (by design for K8s Job mgmt) |
| SEC-028 | HIGH | **FIXED** | 10 unauthenticated tool-integration endpoints → auth added |
| SEC-033 | MEDIUM | **FIXED** | orchestration hardcoded CORS → env var |
| SEC-034 | MEDIUM | **FIXED** | tool-integration verbose error → generic message |
| SEC-035 | HIGH | **FIXED** | SSRF via dead-letter retry → target URL validation |
| SEC-036 | HIGH | **FIXED** | api-service NetworkPolicy contract-parser port 8007→9000 |
| SEC-037 | HIGH | **FIXED** | orchestration missing default-deny-all → added |
| SEC-038 | HIGH | **FIXED** | intelligence-engine prod overlay port 8002→8000, scoped egress |
| SEC-039 | HIGH | **FIXED** | admin-portal missing default-deny-all → added |
| SEC-040 | HIGH | **FIXED** | shared prod overlay missing default-deny-all, `to: []` → scoped |

### Phase 2: Platform Health (PLT-)

| ID | Severity | Status | Finding |
|----|----------|--------|---------|
| PLT-001 | — | PASS | All kustomize newTag values match source versions |
| PLT-002 | MEDIUM | **FIXED** | orchestration scanner-jobs version label 0.10.10→0.10.11 |
| PLT-004 | — | PASS | All deployments have required security contexts, probes, resource limits |
| PLT-005 | LOW | OPEN | 5 deployments missing startupProbe (orchestration, notification, dashboard, admin-portal) |
| PLT-006 | — | PASS | All CronJobs valid schedule, correct restartPolicy |

### Phase 3: Auth (AUTH-)

| ID | Severity | Status | Finding |
|----|----------|--------|---------|
| AUTH-001 | MEDIUM | **FIXED** | 3 services used plain `==` for token comparison → `secrets.compare_digest` |
| AUTH-002 | MEDIUM | OPEN | Dashboard stores Supabase tokens in localStorage (XSS-accessible). Admin-portal correctly uses in-memory storage |
| AUTH-003 | — | PASS | Both frontends have protected route guards |

### Phase 4: API Endpoints (API-)

| ID | Severity | Status | Finding |
|----|----------|--------|---------|
| API-001 | — | PASS | Upload validation: tier-based size limits, extension allowlist |
| API-002 | — | PASS | Scan creation uses Pydantic with proper constraints |

### Phase 5: Test Coverage (TST-)

| ID | Severity | Status | Finding |
|----|----------|--------|---------|
| TST-002 | HIGH | OPEN | contract-parser has zero test files |
| TST-004 | HIGH | OPEN | Only 1/9 repos (api-service) has active CI test automation |

### Phase 6: Tier, Billing & Quotas (TIER-)

| ID | Severity | Status | Finding |
|----|----------|--------|---------|
| TIER-001 | — | PASS | Tier config consistency verified (tiers.json → api-service) |
| TIER-002 | — | PASS | Stripe webhook signature verification correct |
| TIER-003 | — | PASS | Tier metadata validation with whitelist |
| TIER-004 | — | PASS | Rate limiting per-tier enforcement via Redis-backed SlowAPI |

### Phase 7: Intelligence & ML (ML-)

| ID | Severity | Status | Finding |
|----|----------|--------|---------|
| ML-001 | — | PASS | HMAC-SHA256 model serialization signing (BSO-SEC-DESER-001) |
| ML-002 | — | PASS | No unsafe joblib/pickle in intelligence-engine |
| ML-003 | — | PASS | BVD pattern naming convention consistent (1,075 patterns) |
| ML-004 | — | PASS | Prompt injection detection in api-service (BSO-SEC-017/018) |

### Phase 8: Performance (PERF-)

| ID | Severity | Status | Finding |
|----|----------|--------|---------|
| PERF-001 | LOW | OPEN | api-service/data-service missing `pool_recycle` on DB connections |

### Phase 9: Behavioral (BEH-)

| ID | Severity | Status | Finding |
|----|----------|--------|---------|
| BEH-9B | — | PASS | All version/newTag values consistent across repos |
| BEH-9C-1 | MEDIUM | **FIXED** | 3 legacy `solidity_security_shared` wheel files → deleted |
| BEH-9C-2 | — | PASS | `harbor.blocksecops.local` refs only in local overlays (correct) |
| BEH-9D | HIGH | **FIXED** | `ML_MODEL_SIGNING_KEY` missing from api-service GCP ExternalSecret → added |
| BEH-9D | HIGH | **FIXED** | `SUPABASE_JWT_SECRET` + `INTERNAL_SERVICE_TOKEN` missing from notification GCP ExternalSecret → added |

### Phase 10: Readiness (RDY-)

| ID | Severity | Status | Finding |
|----|----------|--------|---------|
| RDY-001 | MEDIUM | OPEN | `docs/database/SCHEMA.md` does not exist |
| RDY-002 | HIGH | OPEN | No GCS backup CronJob in GCP overlay — backups only on local PVC |

---

## Summary

| Severity | Total | Fixed | Open |
|----------|-------|-------|------|
| CRITICAL | 4 | 4 | 0 |
| HIGH | 22 | 17 | 5 |
| MEDIUM | 11 | 5 | 6 |
| LOW | 2 | 0 | 2 |

### Remaining Open Items

**HIGH (5):**
- SEC-020-024: SHA-pinned base images (needs registry digest lookup)
- TST-002: contract-parser has zero tests
- TST-004: Only 1/9 repos has active CI test automation
- RDY-002: No GCS backup CronJob for production PostgreSQL

**MEDIUM (6):**
- SEC-003: Pillow version floor
- SEC-004: aiohttp version floor (5 services)
- SEC-006: hiredis no upper pin
- SEC-025: npm install vs npm ci in frontends
- AUTH-002: Dashboard localStorage token storage
- RDY-001: Missing SCHEMA.md

**LOW (2):**
- PLT-005: Missing startupProbes
- PERF-001: Missing pool_recycle

---

## Services Requiring Version Bump & Rebuild

| Repo | Changes | Version Bump Needed |
|------|---------|:-------------------:|
| blocksecops-api-service | python-jose→PyJWT, ExternalSecret | Yes |
| blocksecops-tool-integration | Auth on 10 endpoints, SSRF fix, timing fix, error msg | Yes |
| blocksecops-orchestration | redlock-py removed, CORS env, timing fix, default-deny, version label | Yes |
| blocksecops-notification | cryptography bump, timing fix, ExternalSecret | Yes |
| blocksecops-intelligence-engine | NetworkPolicy port fix | No (kustomize apply only) |
| blocksecops-admin-portal | .dockerignore, default-deny NetworkPolicy | No (kustomize apply only) |
| blocksecops-shared | NetworkPolicy production overlay | No (kustomize apply only) |
| blocksecops-data-service | Legacy wheel deleted | No |
