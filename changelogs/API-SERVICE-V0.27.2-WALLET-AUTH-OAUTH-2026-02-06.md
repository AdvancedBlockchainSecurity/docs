# API Service v0.27.2 - Wallet Auth Fix & OAuth Kustomize Plumbing

## Version 0.27.2 - February 6, 2026

**Date:** 2026-02-06
**Component:** blocksecops-api-service
**Type:** Bug Fix / Infrastructure
**Priority:** High
**Status:** Complete

### Summary

Fixed wallet authentication nonce endpoints crashing due to slowapi rate limiter parameter conflict. Added per-provider OAuth credential plumbing in Kustomize for GitHub, GitLab, Bitbucket, and Jira integrations. Rebuilt orchestration and admin-portal images to align running tags with source versions.

### Issues Resolved

1. `POST /api/v1/auth/wallet/nonce` returned 500 error due to slowapi finding Pydantic body param instead of Starlette Request
2. `POST /api/v1/auth/wallet/solana/nonce` same issue as above
3. Generic `OAUTH_CLIENT_ID`/`OAUTH_CLIENT_SECRET` insufficient for per-provider OAuth flows
4. Orchestration running `0.9.5-scan-monitoring` tag instead of canonical `0.9.5`
5. Admin-portal running `0.3.0-scan-monitoring` tag instead of canonical `0.3.0`

### Fixed

- **Wallet auth nonce endpoints** - Renamed `http_request: Request` to `request: Request` and `request: WalletNonceRequest` to `body: WalletNonceRequest` so slowapi's `@limiter.limit` decorator finds the correct Starlette `Request` parameter
- **Solana wallet auth nonce endpoint** - Same fix applied: `body: SolanaWalletNonceRequest` with `body.address`

### Added

- **Per-provider OAuth secrets** in ExternalSecret - GitHub, GitLab, Bitbucket, Jira each get dedicated `client_id`/`client_secret` from separate Vault paths
- **Per-provider OAuth env vars** in deployment-patch - 8 new env vars (`GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`, `GITLAB_CLIENT_ID`, etc.)
- **`DASHBOARD_BASE_URL`** env var - Set to `http://app.0xapogee.local` for OAuth callback URL construction
- **Vault paths** for OAuth secrets:
  - `secret/local/api-service/oauth/github`
  - `secret/local/api-service/oauth/gitlab`
  - `secret/local/api-service/oauth/bitbucket`
  - `secret/local/api-service/oauth/jira`

### Changed

- Version bump: `0.27.1` to `0.27.2` (PATCH - bug fix)
- Kustomization `newTag`: `0.27.1` to `0.27.2`

### Code Changes

**Files Modified:**
- `src/presentation/api/v1/endpoints/wallet_auth.py` (line ~200) - Parameter rename
- `src/presentation/api/v1/endpoints/solana_wallet_auth.py` (line ~226) - Parameter rename
- `k8s/overlays/local/api-service/externalsecret.yaml` - Per-provider OAuth secrets
- `k8s/overlays/local/api-service/deployment-patch.yaml` - OAuth env vars + DASHBOARD_BASE_URL
- `k8s/overlays/local/api-service/configmap-patch.yaml` - dashboard_base_url
- `k8s/overlays/local/api-service/kustomization.yaml` - newTag bump
- `pyproject.toml` - Version bump

**Key Fix:**
```python
# wallet_auth.py - Before (broken):
async def request_nonce(http_request: Request, request: WalletNonceRequest):
    address = request.wallet_address

# After (fixed):
async def request_nonce(request: Request, body: WalletNonceRequest):
    address = body.wallet_address
```

### Infrastructure Changes

**Orchestration (0.9.5):** Rebuilt with `--no-cache` and pushed to Harbor. Running image aligned from `0.9.5-scan-monitoring` to canonical `0.9.5` tag.

**Admin Portal (0.3.0):** Rebuilt with `--no-cache`, Supabase build args, and pushed to Harbor. Running image aligned from `0.3.0-scan-monitoring` to canonical `0.3.0` tag.

### Testing

- `POST /api/v1/auth/wallet/nonce` returns nonce (not 500)
- `POST /api/v1/auth/wallet/solana/nonce` returns nonce (not 500)
- `kubectl get externalsecret -n api-service-local` shows SecretSynced
- All 8 OAuth env vars + DASHBOARD_BASE_URL injected in pod
- Orchestration pod Running 4/4 with correct image
- Admin-portal pod Running 1/1 with correct image

### Impact

- **User Impact:** Wallet authentication sign-in flows now work (previously returned 500)
- **OAuth Status:** Plumbing complete; actual OAuth credentials are TODO for GCP deployment
- **Breaking Changes:** None

### Related Documentation

- [Wallet Authentication Tests](../feature-tests/11-wallet-authentication.md) - Updated with known issue fix
- [Docker Image Versioning](../standards/docker-image-versioning.md) - Service versions table updated
- [GCP Pre-Launch Checklist](../../TaskDocs-Apogee/phases/07-phase-7-gcp-deployment/PRE-LAUNCH-CHECKLIST.md) - OAuth apps marked as GCP TODO
