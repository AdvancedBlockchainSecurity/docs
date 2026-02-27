# API Service - Security Audit: Rate Limiting & Auth Scope Enforcement

**Date:** February 18, 2026
**Component:** blocksecops-api-service, blocksecops-shared
**Type:** Security / Hardening
**Priority:** Critical
**Version:** 0.28.42
**Status:** Complete (deployed to local)

---

## Summary

Comprehensive security audit of the API service identified 20 issues (3 critical, 6 high, 7 medium, 4 low). This release resolves 15 of 20 issues, covering all critical and high severity findings. The primary focus was adding rate limiting to 28 unprotected write/mutation endpoints and fixing analytics auth scope enforcement.

---

## Issues Resolved

| # | Severity | Finding | Fix |
|---|----------|---------|-----|
| 1 | Critical | Open redirect in OAuth callbacks | Path validation in `get_dashboard_url()` |
| 2 | Critical | DASHBOARD_BASE_URL env conflict | Fixed in 0.28.40 |
| 3 | Critical | Batch scan operations unrate-limited | 4 rate limit decorators on scan mutation endpoints |
| 4 | High | Contract write operations unrate-limited | 6 rate limit decorators on contract CRUD endpoints |
| 5 | High | Webhook operations unrate-limited | 4 rate limit decorators on webhook CRUD endpoints |
| 6 | High | File upload unrate-limited | 1 rate limit decorator on upload endpoint |
| 7 | High | Wallet auth operations unrate-limited | 3 rate limit decorators on wallet verify/link/unlink |
| 8 | High | Project operations unrate-limited | 5 rate limit decorators on project CRUD endpoints |
| 9 | High | Staging overlay uses mutable tag | Changed `staging-latest` to immutable `0.28.42` |
| 11 | Medium | User profile updates unrate-limited | 2 rate limit decorators on profile/preferences |
| 12 | Medium | Invariant sub-operations unrate-limited | 3 rate limit decorators on apply/feedback/delete |
| 13 | Medium | tiers.json missing rate limit entries | Added 20 new endpoint rate limit entries |
| 14 | Medium | Analytics endpoints lack API key support | 5 endpoints changed to dual-auth |
| 15 | Medium | Dockerfile cache mount ID conflicts | 3 unique cache IDs per build stage |

### Runtime Fix (discovered during deployment)

| Issue | Severity | Fix |
|-------|----------|-----|
| `EndpointRateLimits` model missing `webhooks` category | High | Added `webhooks` field to Pydantic model in blocksecops-shared |

---

## Deferred Issues (5)

| # | Severity | Finding | Reason |
|---|----------|---------|--------|
| 10 | Medium | Core GET endpoints lack per-tier rate limiting | Requires middleware-level changes; separate task |
| 17 | Low | SecurityHeadersMiddleware content unverified | Informational; manual review needed |
| 18 | Low | Internal service key strength unverified | Deployment config review |
| 19 | Low | API key rate_limit_per_minute capped at 300 | Enhancement, not security fix |
| 20 | Low | Production overlay uses placeholder registry | Expected; production not deployed yet |

---

## Added

- 28 `@limiter.limit()` rate limit decorators across 8 endpoint files
- 20 new endpoint rate limit entries in `tiers.json` (operations, webhooks, general categories)
- `webhooks` category in `EndpointRateLimits` Pydantic model
- Unique BuildKit cache mount IDs per Dockerfile stage (`pip-builder`, `pip-test-builder`, `pip-runtime`)

## Changed

- 5 analytics endpoints from JWT-only (`get_current_user`) to dual-auth (`get_current_user_or_api_key`)
- Staging kustomize overlay from mutable `staging-latest` to immutable versioned tag
- Parameter naming in 7 endpoint files to avoid collision with slowapi's `Request` parameter

## Security

- All write/mutation endpoints now rate-limited via centralized tier configuration
- Rate limits sourced from `tiers.json` — adjustable without code changes
- Analytics endpoints now accessible via API keys with appropriate scopes
- Dockerfile build stages isolated with unique cache mount IDs

---

## Code Changes

### blocksecops-api-service (15 files)

| File | Change |
|------|--------|
| `src/presentation/api/v1/endpoints/scans.py` | 4 rate limit decorators (batchScan, storeResults, storeFuzzingResults, recoverStaleScans) |
| `src/presentation/api/v1/endpoints/contracts.py` | Imports + 6 rate limit decorators (create, update, delete, batchDelete, archive, restore) |
| `src/presentation/api/v1/endpoints/webhooks.py` | Imports + 4 rate limit decorators (create, update, delete, secretRotate) |
| `src/presentation/api/v1/endpoints/upload.py` | Imports + 1 rate limit decorator (fileUpload) |
| `src/presentation/api/v1/endpoints/wallet_auth.py` | 3 rate limit decorators (walletVerify, walletLink, unlink) |
| `src/presentation/api/v1/endpoints/projects.py` | Imports + 5 rate limit decorators (create, update, delete, addContract, removeContract) |
| `src/presentation/api/v1/endpoints/users.py` | Imports + 2 rate limit decorators (profileUpdate, preferences) |
| `src/presentation/api/v1/endpoints/invariants.py` | 3 rate limit decorators (apply, feedback, delete) |
| `src/presentation/api/v1/endpoints/analytics.py` | Import + 5 auth dependency changes to dual-auth |
| `src/presentation/api/v1/endpoints/oauth_callbacks.py` | Open redirect fix (path validation) |
| `Dockerfile` | 3 unique cache mount IDs |
| `pyproject.toml` | Version 0.28.40 -> 0.28.42 |
| `k8s/overlays/local/kustomization.yaml` | newTag + version label -> 0.28.42 |
| `k8s/overlays/local/api-service/kustomization.yaml` | newTag -> 0.28.42 |
| `k8s/overlays/staging/kustomization.yaml` | staging-latest -> 0.28.42 |

### blocksecops-shared (3 files)

| File | Change |
|------|--------|
| `tier-config/python/blocksecops_tier_config/tiers.json` | 20 new endpoint rate limit entries across operations, webhooks, general categories |
| `tier-config/python/blocksecops_tier_config/models.py` | Added `webhooks` field to `EndpointRateLimits` model |
| `tier-config/python/blocksecops_tier_config/loader.py` | Updated error message to include `webhooks` category |

---

## Deployment

- **Image:** `harbor.0xapogee.local/blocksecops/api-service:0.28.42`
- **Deployed:** February 18, 2026
- **Smoke tests:** All pass (health, auth, database integrity, internal services)
- **Unit tests:** 11 passed, 0 failed
- **Pod status:** 1/1 Running, 0 restarts, 0 errors in logs

---

## Rate Limit Reference

### New Endpoint Rate Limits Added

| Category | Endpoint | Rate Limit | Description |
|----------|----------|------------|-------------|
| operations | batchScan | 3/min | Batch scan creation |
| operations | storeResults | 60/min | Scan result storage |
| operations | storeFuzzingResults | 30/min | Fuzzing result storage |
| operations | recoverStaleScans | 5/min | Stale scan recovery |
| operations | contractCreate | 10/min | Contract creation |
| operations | contractUpdate | 20/min | Contract update/archive/restore |
| operations | contractDelete | 10/min | Contract deletion |
| operations | contractBatchDelete | 3/min | Batch contract deletion |
| operations | fileUpload | 5/min | File upload |
| operations | projectCreate | 10/min | Project creation |
| operations | projectUpdate | 20/min | Project update/contract association |
| operations | projectDelete | 10/min | Project deletion |
| webhooks | webhookCreate | 5/min | Webhook creation |
| webhooks | webhookUpdate | 10/min | Webhook update |
| webhooks | webhookDelete | 10/min | Webhook deletion |
| webhooks | webhookSecretRotate | 3/min | Webhook secret rotation |
| auth | walletVerify | 5/min | Wallet verification |
| auth | walletLink | 5/min | Wallet link/unlink |
| general | userProfileUpdate | 10/min | Profile and preferences update |
| general | invariantApply | 10/min | Invariant application |
| general | invariantFeedback | 20/min | Invariant feedback |
| general | invariantDelete | 10/min | Invariant deletion |
