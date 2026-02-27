# CORS Wildcard, Legacy Domain, and Deployment Fixes

**Date:** February 27, 2026
**Author:** BlockSecOps Team
**Services Affected:** All 9 platform services + gcp-infrastructure
**Severity:** HIGH (security) + MEDIUM (legacy domain cleanup)

## Summary

Resolved three categories of pre-existing issues across the entire platform:

1. **CORS wildcard origins** — 5 Traefik CORS middlewares used `*` (wildcard) in `accessControlAllowOriginList`, allowing any origin to make cross-origin requests
2. **Legacy domain references** — `solidityops.com`, `soliditysecurity.dev`, and non-harbor `blocksecops.local` references remained in k8s configs across 9 repos
3. **data-service deployment patch** — Referenced non-existent `data-service-vault-secrets` secret, missing `startupProbe` override

Added comprehensive regression test suites (64 tests) to prevent reintroduction of these issues.

## Changes

### 1. CORS Wildcard Elimination (Security Fix)

**Problem:** Five Traefik CORS middleware files used `accessControlAllowOriginList: ["*"]`, allowing unrestricted cross-origin requests. This violates the platform security standard that CORS origins must be explicit domains, never wildcards.

**Fix:** Replaced wildcard with explicit `https://app.0xapogee.local` origin in all middleware files. Restricted allowed methods to `GET, POST, OPTIONS` and headers to `Content-Type, Authorization, Sec-WebSocket-*`. Disabled credentials (`accessControlAllowCredentials: false`).

| File | Repository |
|------|-----------|
| `k8s/overlays/local/notification/middleware-cors.yaml` | blocksecops-notification |
| `k8s/overlays/local/data-service/middleware-cors.yaml` | blocksecops-data-service |
| `k8s/overlays/local/api-service/middleware-cors.yaml` | blocksecops-gcp-infrastructure |
| `k8s/overlays/local/dashboard/middleware-cors.yaml` | blocksecops-gcp-infrastructure |
| `k8s/overlays/local/tool-integration/middleware-cors.yaml` | blocksecops-gcp-infrastructure |

### 2. Legacy Domain Removal

**Problem:** Multiple k8s configuration files still referenced pre-rebrand domains (`solidityops.com`, `soliditysecurity.dev`) and mid-rebrand application domains (`blocksecops.local` for non-harbor services).

**Fix:** Updated all domain references to current standards:
- Production: `*.0xapogee.com`
- Local: `*.0xapogee.local`
- Harbor registry: `harbor.blocksecops.local` (unchanged — infrastructure concern, separate from application rebrand)

**Files updated across repos:**

| Category | Old Domain | New Domain | Files Changed |
|----------|-----------|------------|---------------|
| IngressRoutes (local) | `*.solidityops.com`, `*.soliditysecurity.dev` | `*.0xapogee.local` | 8 files |
| IngressRoutes (production) | `*.blocksecops.com` | `*.0xApogee.com` | 2 files |
| Base ingress.yaml | `*.solidityops.com` | `*.0xapogee.com` | 6 files |
| ConfigMaps | `soliditysecurity.dev` URLs | `app.0xapogee.local` | 3 files |
| cert-manager emails | `soliditysecurity.example.com` | `0xapogee.com` | 2 files |
| admin-portal IngressRoutes | `admin.blocksecops.local` | `admin.0xapogee.local` | 2 files |
| API nginx CORS annotation | `*` (wildcard) | `https://app.0xapogee.local` | 1 file |

**Harbor Registry Exception:** `harbor.blocksecops.local` was intentionally NOT changed. Harbor's TLS certificate, IngressRoute, and DNS all serve on `harbor.blocksecops.local`. Changing this requires coordinated infrastructure migration (new TLS cert, DNS update, IngressRoute update, registry re-trust on all nodes). This is tracked separately as an infrastructure task.

### 3. data-service Deployment Patch Fix

**Problem:** The local overlay deployment patch referenced a non-existent Kubernetes secret `data-service-vault-secrets` with incorrect key names (`database-url`, `redis-auth`). The base deployment also referenced a `vault_token` key not present in the ExternalSecret-managed secret, and a `startupProbe` endpoint (`/api/v1/health/startup`) not implemented by the application.

These issues were pre-existing but surfaced when the kustomization was re-applied during CORS/domain fixes.

**Fix applied to** `blocksecops-data-service/k8s/overlays/local/data-service/deployment-patch.yaml`:
- Corrected secret name from `data-service-vault-secrets` to `data-service-secrets`
- Corrected key names from `database-url`/`redis-auth` to `database_url`/`redis_url`
- Added `VAULT_TOKEN` env var override with static `dev-root-token` value for local dev
- Added `startupProbe` override pointing to `/api/v1/health/live`

### 4. Regression Test Suites Added

**Notification service tests** (`tests/unit/infrastructure/`):
- `test_config.py` — 14 tests: Settings defaults, CORS validation (wildcard rejection, HTTPS requirement, production domain check), environment overrides, caching
- `test_k8s_config_regression.py` — 9 tests: ConfigMap CORS validation, Traefik middleware CORS validation, legacy domain detection across all k8s YAML files

**Cross-repo regression tests** (`blocksecops-api-service/tests/unit/infrastructure/test_domain_cors_regression.py`):
- 41 parametrized tests scanning all 9 service repos:
  - `TestNoCORSWildcardAcrossRepos` — Validates no wildcard in ConfigMaps, middleware files, or gcp-infrastructure overlays
  - `TestNoLegacyDomainsAcrossRepos` — Validates no `solidityops.com`, `soliditysecurity.dev`, or non-harbor `blocksecops.local` in any k8s YAML
  - `TestDashboardConfigMapURLs` — Validates dashboard ConfigMap URLs use HTTPS and current domain
  - `TestAPIServiceCORSDefaults` — Validates API service base configmap CORS settings
  - `TestIngressRouteHostRules` — Validates IngressRoute Host() rules use current domain

**Harbor exclusion pattern:** Tests use negative lookbehind regex `(?<!harbor\.)blocksecops\.local` to correctly exclude `harbor.blocksecops.local` references from legacy domain checks.

## Verification

### Cluster Health (all services healthy after changes)

```
admin-portal:        1/1 Running
api-service:         1/1 Running + 1/1 celery-worker
contract-parser:     1/1 Running
dashboard:           1/1 Running
data-service:        1/1 Running
intelligence-engine: 1/1 Running
notification:        1/1 Running
orchestration:       1/1 Running (4 containers)
tool-integration:    2/2 Running
```

### CORS Verification

```bash
# Correct origin returns Access-Control-Allow-Origin header
curl -sk -X OPTIONS -H "Origin: https://app.0xapogee.local" \
  https://app.0xapogee.local/api/v1/health/live -I
# → access-control-allow-origin: https://app.0xapogee.local

# Bad origin does NOT return Access-Control-Allow-Origin
curl -sk -X OPTIONS -H "Origin: https://evil.example.com" \
  https://app.0xapogee.local/api/v1/health/live -I
# → no access-control-allow-origin header
```

### Test Results

- Cross-repo regression: **41 passed**, 0 failed
- Notification regression: **23 passed**, 0 failed
- **Total: 64 new tests, all passing**

## Risk Assessment

- **CORS changes:** Low risk — restricting from wildcard to specific origin is strictly more secure
- **Domain changes:** Low risk — legacy domains were unreachable; new domains match current infrastructure
- **data-service fix:** Low risk — corrects secret reference to match actual ExternalSecret configuration
- **Harbor exception:** No risk — explicitly preserved working registry configuration

## Repos Modified

| Repository | Files Changed |
|------------|--------------|
| blocksecops-notification | 13 modified + tests/ added |
| blocksecops-api-service | 38 modified + 1 test added |
| blocksecops-data-service | 9 modified |
| blocksecops-gcp-infrastructure | 16 modified |
| blocksecops-dashboard | 27 modified |
| blocksecops-admin-portal | 14 modified |
| blocksecops-tool-integration | 5 modified |
| blocksecops-orchestration | 6 modified |
| blocksecops-intelligence-engine | 5 modified |
| blocksecops-contract-parser | 5 modified |
