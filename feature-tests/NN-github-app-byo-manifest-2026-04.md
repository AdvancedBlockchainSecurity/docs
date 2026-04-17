# GitHub App — Bring-Your-Own via Manifest Flow

**Priority:** P1
**Date:** 2026-04-17
**Versions:** api-service `0.38.1 → 0.39.0`, dashboard (Phase 2 pending)
**Migration:** 087 (`add_github_app_fields_to_integration_credentials`)
**Related PR:** blocksecops-api-service#355
**Status:** **Phase 1 (backend) live.** Phase 2 (dashboard UI) pending follow-up PR.

## Overview

Each Apogee organization registers **their own** GitHub App (one per subscription) via GitHub's official [App Manifest flow](https://docs.github.com/en/apps/sharing-github-apps/registering-a-github-app-from-a-manifest). The platform itself owns no GitHub App credentials — every App's ID, private key, webhook secret, and installation ID live per-integration in the database, encrypted via the existing Fernet service.

This is distinct from the **URL-based GitHub ingest** path (`POST /api/v1/contracts/from-github`, shipped in 0.37.2), which is public-repo-only, unauthenticated, single-shot. The App flow is authenticated, per-repo, persistent, and supports private repos.

## Flow

```
1. Dashboard:  POST /organizations/{org}/integrations/github-app/manifest-init
               → { manifest, state, target_url }
2. Browser:    auto-submits form (manifest as POST body) to target_url with ?state=...
3. GitHub:     pre-fills App creation page from our manifest; customer names it + clicks Create
4. GitHub:     redirects to /api/v1/github-app/manifest-callback?code=X&state=Y
5. API:        verifies state JWT → POST /app-manifests/{code}/conversions (GitHub)
               → receives { app_id, slug, client_id, pem, webhook_secret }
               → encrypts pem + webhook_secret via Fernet
               → creates IntegrationModel (status=pending) + IntegrationCredentialModel
               → redirects to dashboard with success banner
6. Dashboard:  POST /organizations/{org}/integrations/github-app/{id}/install-url
               → { install_url } (signed state JWT)
7. Browser:    redirects to github.com/apps/{slug}/installations/new?state=...
8. GitHub:     customer picks repos, clicks Install
9. GitHub:     redirects to /api/v1/github-app/setup?installation_id=N&setup_action=install&state=Y
10. API:       verifies state → fetches installation info (account login + avatar)
               → stores installation_id on credential row
               → sets IntegrationModel.status='connected'
               → redirects to dashboard with success banner
```

## Backend checklist (live in 0.39.0)

### 1. Manifest init
- [ ] `POST /api/v1/organizations/{org_id}/integrations/github-app/manifest-init` with Bearer JWT returns 200 with `{manifest, state, target_url}`
- [ ] Same request without auth returns 401
- [ ] Non-admin org member gets 403
- [ ] Manifest JSON has `url`, `hook_attributes.url`, `public: false`, permissions = contents/metadata/pull_requests all `read`, `default_events: []`
- [ ] `state` is a JWT signed with `JWT_SECRET_KEY`, issuer `apogee-github-app-manifest`, 10-min TTL

### 2. Manifest callback (GitHub → Apogee)
- [ ] `GET /api/v1/github-app/manifest-callback?code=X&state=invalid` → 302 redirect with `?error=invalid_state`
- [ ] `GET /api/v1/github-app/manifest-callback?code=X&state=<valid>` with valid JWT → 302 redirect to `/integrations?success=true&provider=github&tab=source-control`
- [ ] After callback, `integration_credentials` row exists with encrypted `github_app_private_key_encrypted` (ciphertext ≠ plaintext)
- [ ] `IntegrationModel.settings` includes `{"auth_model": "github_app_byo"}`
- [ ] Re-running the flow on an existing GitHub integration upserts (no duplicate rows)

### 3. Install URL
- [ ] `POST /api/v1/organizations/{org_id}/integrations/github-app/{integration_id}/install-url` returns `{install_url: "https://github.com/apps/{slug}/installations/new?state=..."}`
- [ ] Install URL's `state` is signed with issuer `apogee-github-app-install` (different from manifest issuer)
- [ ] Returns 400 if the integration has no `github_app_slug` (manifest never completed)

### 4. Setup callback (GitHub → Apogee)
- [ ] `GET /api/v1/github-app/setup?setup_action=install&installation_id=N&state=<valid>` → 302 redirect with `?success=true`
- [ ] Credential row's `github_app_installation_id` updated
- [ ] `IntegrationModel.status` transitions `pending → connected`
- [ ] `IntegrationModel.external_username` populated from `/app/installations/{id}` metadata
- [ ] `setup_action=update` or `=request` → 302 redirect without DB change
- [ ] Missing state → 302 redirect with `?error=missing_state`

### 5. Webhook stub
- [ ] `POST /api/v1/github-app/webhook` returns 204 for any payload
- [ ] Delivery ID + event name logged server-side for traceability
- [ ] **Not** dispatching scans yet — this is a documented no-op until the follow-up receiver ships

## Security posture

- [ ] Each customer's App private key encrypted at rest via Fernet (`INTEGRATION_ENCRYPTION_KEY`)
- [ ] RS256 signatures use per-integration private key (not a shared platform key)
- [ ] State JWTs have discriminated issuers so cross-flow replay (install state → manifest endpoint) fails closed
- [ ] Manifest declares `public: false` — customer Apps are **not** listed on GitHub Marketplace
- [ ] Permissions in the manifest: `contents:read` + `metadata:read` + `pull_requests:read` (no write, no admin)
- [ ] Rate limits: `manifest-init` uses shared default; `manifest-callback` + `setup` capped at 30/min; `webhook` at 120/min

## Deferred to follow-up passes

| Item | Deferred because |
|------|-----------------|
| Webhook event dispatch (scan-on-push / scan-on-PR) | Explicit scope decision on 2026-04-17 — ship install-and-sync first |
| Dashboard `GitHubAppSetupWizard` + repo management UI | Phase 2 PR, queued behind backend verification |
| Retire legacy `oauth_service.py` GitHub path | Kept as dead code until dashboard confirms no callers |
| GitHub Enterprise Server support via Broker | Multi-week separate initiative |

## Verification (live in prod)

```bash
# 1. Backend version reflects 0.39.0
curl -s https://app.0xapogee.com/api/v1/health/live | jq .version
# Expected: "0.39.0"

# 2. Migration 087 applied
kubectl exec -n postgresql-prod postgresql-0 -- psql -U blocksecops -d solidity_security -t \
  -c "SELECT version_num FROM alembic_version;"
# Expected: 087

# 3. All 8 github_app_* columns present
kubectl exec -n postgresql-prod postgresql-0 -- psql -U blocksecops -d solidity_security -t \
  -c "SELECT COUNT(*) FROM information_schema.columns WHERE table_name='integration_credentials' AND column_name LIKE 'github_app%';"
# Expected: 8

# 4. Endpoints respond correctly (unauth checks)
curl -s -o /dev/null -w "%{http_code}" -X POST \
  https://app.0xapogee.com/api/v1/organizations/00000000-0000-0000-0000-000000000000/integrations/github-app/manifest-init
# Expected: 401

curl -s -o /dev/null -w "%{http_code}" \
  "https://app.0xapogee.com/api/v1/github-app/manifest-callback?code=x&state=invalid"
# Expected: 302

curl -s -o /dev/null -w "%{http_code}" \
  "https://app.0xapogee.com/api/v1/github-app/setup?installation_id=1&setup_action=nope"
# Expected: 302

curl -s -o /dev/null -w "%{http_code}" -X POST \
  https://app.0xapogee.com/api/v1/github-app/webhook
# Expected: 204
```

## Related

- Pipeline details: `docs/pipelines/github-app-byo-manifest-pipeline.md`
- Customer install workflow: `docs/workflows/github-app-byo-install-workflow.md`
- Troubleshooting: `docs/playbooks/github-app-byo-troubleshooting.md`
- URL-based GitHub ingest (different path): `docs/feature-tests/93-github-url-ingest-and-tier-limits-2026-04.md`
