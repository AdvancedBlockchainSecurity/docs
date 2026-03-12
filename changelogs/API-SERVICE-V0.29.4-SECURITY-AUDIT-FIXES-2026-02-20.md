# API Service v0.29.4 - Security Audit Fixes

## Version 0.29.4 - February 20, 2026

**Date:** 2026-02-20
**Component:** blocksecops-api-service, blocksecops-gcp-infrastructure
**Type:** Security
**Priority:** Medium
**Status:** Complete

### Summary

Comprehensive security audit fix addressing CORS header duplication, missing rate limiting on 27 endpoint files, and indefinite JWKS cache. Removes Traefik CORS middleware (FastAPI handles CORS), adds tier-based rate limiting to all critical unprotected endpoints, and adds 1-hour TTL to JWKS key cache.

### Issues Resolved

1. **CORS header duplication** - Both Traefik middleware and FastAPI CORSMiddleware set CORS headers, causing duplicate `Access-Control-Allow-Origin` headers
2. **Hardcoded IP in CORS** - Traefik CORS middleware contained hardcoded `192.168.86.225`
3. **Short CORS max-age** - Traefik used 100s, FastAPI used default 600s; now explicit 3600s
4. **27 endpoint files lacked rate limiting** - Critical endpoints (payments, billing, organizations, etc.) had no rate limiting
5. **JWKS cache had no TTL** - `@lru_cache` cached JWKS keys indefinitely, preventing key rotation pickup

### Fixed

- **CORS header duplication** - Removed Traefik CORS middleware from both api-service and dashboard IngressRoutes; removed GCP backend-config CORS headers. FastAPI CORSMiddleware is now the single source of CORS headers.
- **CORS max-age** - Set explicit `max_age=3600` (1 hour) in FastAPI CORSMiddleware to reduce preflight requests
- **JWKS cache TTL** - Replaced `@lru_cache(maxsize=1)` with TTL-based cache (1 hour) in both customer and admin Supabase clients

### Added

- **Rate limiting on 27 endpoint files:**

| File | Rate Limit | Type |
|------|-----------|------|
| payments.py | Tier-based (general/default) | Abuse prevention |
| billing.py | Tier-based (general/default) | Abuse prevention |
| organizations.py | Tier-based (general/default) | Abuse prevention |
| teams.py | Tier-based (general/default) | Abuse prevention |
| intelligence.py | Tier-based (general/default) | Abuse prevention |
| search.py | Tier-based (general/default) | Abuse prevention |
| vulnerabilities.py | Tier-based (general/default) | Abuse prevention |
| deduplication.py | Tier-based (general/default) | Abuse prevention |
| annotations.py | Tier-based (general/default) | Abuse prevention |
| comments.py | Tier-based (general/default) | Abuse prevention |
| favorites.py | Tier-based (general/default) | Abuse prevention |
| tags.py | Tier-based (general/default) | Abuse prevention |
| integrations.py | Tier-based (general/default) | Abuse prevention |
| analytics.py | Tier-based (general/default) | Abuse prevention |
| statistics.py | Tier-based (general/default) | Abuse prevention |
| patterns.py | Tier-based (general/default) | Abuse prevention |
| scan_results.py | Tier-based (general/default) | Abuse prevention |
| assignments.py | Tier-based (general/default) | Abuse prevention |
| quality_gates.py | Tier-based (general/default) | Abuse prevention |
| saved_searches.py | Tier-based (general/default) | Abuse prevention |
| notification_channels.py | Tier-based (general/default) | Abuse prevention |
| consent.py | Tier-based (general/default) | Abuse prevention |
| feedback.py | Tier-based (general/default) | Abuse prevention |
| support_tickets.py | Tier-based (general/default) | Abuse prevention |
| oauth_callbacks.py | Fixed: 10/minute | Token exchange protection |
| impersonation.py | Fixed: 5/minute | Admin impersonation protection |
| gdpr.py | Fixed: 5/minute | Data request protection |

### Removed

- `k8s/overlays/local/api-service/middleware-cors.yaml` - Traefik CORS middleware (duplicate)
- `k8s/overlays/local/dashboard/middleware-cors.yaml` - Traefik CORS middleware (duplicate)
- CORS middleware references from api-service and dashboard IngressRoutes
- CORS `customResponseHeaders` from GCP backend-config-api.yaml

### Not Fixed (Tracked as Future Work)

| Issue | Reason |
|-------|--------|
| MFA backup/recovery codes | Significant feature scope (new DB fields, encryption, generation logic) |
| User JWT blacklist for logout | Standard JWT pattern; admin emergency session revocation exists |
| CSP unsafe-inline | Required for Swagger UI; API service only serves JSON otherwise |

### Code Changes

**Files Modified (blocksecops-api-service):**
- `src/main.py` - Added `max_age=3600` to CORSMiddleware
- `src/infrastructure/auth/supabase_client.py` - TTL-based JWKS cache replacing `@lru_cache`
- `src/infrastructure/auth/admin_supabase_client.py` - TTL-based admin JWKS cache replacing `@lru_cache`
- `pyproject.toml` - Version 0.29.3 -> 0.29.4
- `k8s/overlays/local/api-service/kustomization.yaml` - Image tag 0.29.3 -> 0.29.4
- 27 endpoint files in `src/presentation/api/v1/endpoints/` - Added rate limiting

**Files Modified (blocksecops-gcp-infrastructure):**
- `k8s/overlays/local/api-service/ingressroute.yaml` - Removed CORS middleware reference
- `k8s/overlays/local/dashboard/ingressroute.yaml` - Removed CORS middleware reference
- `k8s/overlays/gcp/ingress/backend-config-api.yaml` - Removed CORS customResponseHeaders

**Files Deleted (blocksecops-gcp-infrastructure):**
- `k8s/overlays/local/api-service/middleware-cors.yaml`
- `k8s/overlays/local/dashboard/middleware-cors.yaml`

### Testing

1. **CORS verification:**
   ```bash
   curl -v -X OPTIONS https://app.0xapogee.com/api/v1/health/live \
     -H "Origin: https://app.0xapogee.com"
   # Verify single set of CORS headers, max-age=3600
   ```

2. **Rate limiting verification:**
   ```bash
   # Check X-RateLimit-* headers on previously unprotected endpoint
   curl -v https://app.0xapogee.com/api/v1/payments/...
   ```

3. **JWKS cache:** Service starts and authenticates correctly with TTL cache

4. **Health check:**
   ```bash
   curl https://app.0xapogee.com/api/v1/health/ready
   ```

### Impact

- **Security:** Medium - Closes rate limiting gaps on 27 endpoint files, fixes CORS duplication, adds key rotation support via JWKS TTL
- **Performance:** Positive - CORS max-age=3600 reduces preflight requests by ~85% vs previous 100s/600s values
- **Breaking Changes:** None - All changes are backwards-compatible
