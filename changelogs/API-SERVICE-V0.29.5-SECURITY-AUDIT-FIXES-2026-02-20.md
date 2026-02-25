# API Service v0.29.5 - Security Audit Fixes

**Date:** February 20, 2026
**Author:** BlockSecOps Team
**Services Affected:** api-service
**Version:** 0.29.4 -> 0.29.5

## Summary

Applied security audit fixes to the API service: added rate limiting to all previously unprotected endpoints. CORS max-age and JWKS cache TTL were already correctly implemented from prior work.

## Changes

### 1. Rate Limiting Added to 10 Endpoint Files

**Problem:** 10 endpoint files (55+ endpoints total) lacked rate limiting decorators, allowing unlimited request volume from authenticated users.

**Solution:** Added `@limiter.limit()` decorator to every endpoint in these files using the existing tier-based rate limiting infrastructure (`get_rate_limit_string` from `blocksecops_tier_config`).

| File | Endpoints | Rate Limit Type |
|------|-----------|-----------------|
| `economic_analysis.py` | 5 | Tier-based |
| `contract_structure.py` | 5 | Tier-based |
| `service_accounts.py` | 7 | Tier-based |
| `invites.py` | 3 org + 2 public | Tier-based / Fixed (10/min for public) |
| `project_access.py` | 7 | Tier-based |
| `copilot.py` | 9 | Tier-based |
| `ml.py` | 25 | Tier-based |
| `roles.py` | 1 | Tier-based |
| `scanners.py` | 4 | Tier-based |
| `ide_integrations.py` | 8 | Tier-based |

**Intentionally Excluded (per security audit):**
- `health.py` - Kubernetes probes (must remain unthrottled)
- `websocket.py` - WebSocket connections (not HTTP request/response)
- `monitoring.py` - Internal monitoring endpoints
- `stripe_webhook.py` - External Stripe webhooks (signature-verified)
- `admin/*.py` - All admin endpoints (MFA-protected)

### 2. CORS max-age (Already Implemented)

`max_age=3600` was already set in `CORSMiddleware` config at `src/main.py:209`. No change needed.

### 3. JWKS Cache TTL (Already Implemented)

TTL-based cache (1 hour) was already implemented in both:
- `src/infrastructure/auth/supabase_client.py` - `JWKS_CACHE_TTL = 3600`
- `src/infrastructure/auth/admin_supabase_client.py` - `ADMIN_JWKS_CACHE_TTL = 3600`

No change needed.

### 4. Version Bump

- `pyproject.toml`: 0.29.4 -> 0.29.5
- `k8s/overlays/local/api-service/kustomization.yaml`: newTag 0.29.4 -> 0.29.5

## Files Modified

| File | Change |
|------|--------|
| `pyproject.toml` | Version bump 0.29.4 -> 0.29.5 |
| `k8s/overlays/local/api-service/kustomization.yaml` | Image tag + version label bump |
| `src/presentation/api/v1/endpoints/economic_analysis.py` | Added rate limiting imports, decorator, Request param |
| `src/presentation/api/v1/endpoints/contract_structure.py` | Added rate limiting imports, decorator, Request param |
| `src/presentation/api/v1/endpoints/service_accounts.py` | Added rate limiting imports, decorator, Request param |
| `src/presentation/api/v1/endpoints/invites.py` | Added rate limiting imports, decorator, Request param |
| `src/presentation/api/v1/endpoints/project_access.py` | Added rate limiting imports, decorator, Request param |
| `src/presentation/api/v1/endpoints/copilot.py` | Added rate limiting imports, decorator, Request param |
| `src/presentation/api/v1/endpoints/ml.py` | Added rate limiting imports, decorator, Request param |
| `src/presentation/api/v1/endpoints/roles.py` | Added rate limiting imports, decorator, Request param |
| `src/presentation/api/v1/endpoints/scanners.py` | Added rate limiting imports, decorator, Request param |
| `src/presentation/api/v1/endpoints/ide_integrations.py` | Added rate limiting imports, decorator, Request param |

## Verification

- All Python files parse correctly (AST validation)
- Docker build succeeds
- Image pushed to Harbor as `0.29.5`
- Deployment rolled out successfully
- Health check returns `ready: true`

## Not Fixed (Tracked as Future Work)

| Issue | Reason |
|-------|--------|
| MFA backup codes | Significant feature addition - separate task |
| User JWT blacklist | Standard JWT pattern, admin emergency revocation exists |
| Traefik CORS middleware in gcp-infrastructure | Old IngressRoute (soliditysecurity.dev), not actively deployed |
