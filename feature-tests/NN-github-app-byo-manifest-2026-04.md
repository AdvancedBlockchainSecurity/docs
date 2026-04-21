# GitHub App — Bring-Your-Own via Manifest Flow

**Priority:** P1
**Date:** 2026-04-17
**Versions:** api-service `0.38.1 → 0.39.0 → 0.39.1 → 0.40.0 → 0.40.1 → 0.40.2 → 0.40.3`, dashboard `0.49.1 → 0.50.0 → 0.50.3 → 0.51.0`
**Migration:** 087 (`add_github_app_fields_to_integration_credentials`)
**Related PRs:** blocksecops-api-service#355, blocksecops-dashboard#214 (Phase 2), plus follow-up PATCHes and the Option A repo-sync pipeline
**Status:** **Backend + Dashboard + Repo-sync pipeline all live.** Customer clicks Sync now → .sol files walk → Contract rows upserted → source indicators render in UI. Webhook auto-scan still deferred — see *Deferred* section below.

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

### 5. Webhook dispatcher (api-service ≥ 0.43.0)
- [ ] `POST /api/v1/github-app/webhook` dispatches real push / pull_request events
- [ ] Full tests in `docs/feature-tests/14-github-webhook-dispatcher.md`; the stub behavior this section previously described was replaced in 0.43.0

### 6. Import installed repositories (0.39.1)
- [ ] `POST /api/v1/organizations/{org_id}/integrations/github-app/{integration_id}/import-installed-repos` with Bearer JWT (admin) returns 200 + the connected-repo list
- [ ] Same request without auth → 401
- [ ] Non-admin org member → 403
- [ ] Integration in `pending` status (install not completed) → 400 `Integration is not connected yet`
- [ ] Integration missing `github_app_installation_id` → 400 `Installation ID is missing`
- [ ] First call creates `IntegrationRepository` rows mirroring GitHub's installation repo selection; `repos_synced` incremented
- [ ] Re-calling is idempotent — no duplicate rows; dedupe keys on `(integration_id, external_repo_id)`
- [ ] Pagination works — repos past the 100-per-page GitHub API boundary are included
- [ ] GitHub API `401` from installation token surfaces as 502 `GitHub API error…` (token is invalidated server-side)

### 7. Dashboard wizard + repo management (Phase 2)
- [ ] CSP `form-action 'self' https://github.com` — clicking **Create GitHub App** navigates to `github.com/settings/apps/new` with the manifest pre-filled (no CSP form-action violation)
- [ ] After GitHub redirects back with `?success=true&provider=github`, **exactly one** success toast is shown (not 5) — `setSearchParams` clears the param so the effect does not re-fire on auth re-renders
- [ ] Wizard renders the correct step for integration state: no integration → Create; `status!=connected` → Install; `status=connected` → Manage Repositories
- [ ] In Manage step, **Import from GitHub** button calls the import endpoint and populates the `Connected repositories` modal

### 8. Repo sync pipeline (Option A — api-service 0.40.x + dashboard 0.51.0)
- [ ] Click **Sync now** on a connected repo → endpoint returns in <200ms (task enqueued, not run inline)
- [ ] `integration_repositories.sync_status` transitions `pending → syncing → synced` (or `error`) without manual intervention
- [ ] While any repo is syncing, the dashboard polls the repos query every 3 s so the badge + counts update in-place
- [ ] Celery task walks `/git/trees/{sha}?recursive=1` with the installation token, filters to `.sol` blobs, applies budget caps (1 MB/file, 100 files, 50 MB total)
- [ ] For each `.sol` file: creates `ContractModel` row with `source_repo_url`, `source_commit_hash`, `source_file_path`, `source_hash` populated; `organization_id` matches the integration's org; `user_id = integration.created_by`
- [ ] Re-running sync at the same commit is a no-op (dedupe on `(organization_id, source_repo_url, source_file_path)`)
- [ ] Re-running sync after the branch advances updates `source_code`, `source_commit_hash`, `source_hash`, `lines_of_code`; leaves the contract name intact; resets `status='uploaded'`
- [ ] Worker egress is locked down to port 443 / non-RFC1918 only (NetworkPolicy `celery-worker-egress-external-apis`)
- [ ] Task failures truncate the error message to 500 chars and set `sync_error` before re-raising for Celery retry
- [ ] Files >1 MB or past the 100-file cap are skipped and summarized in `sync_error` — sync still reports `synced`

### 9. "From repo" indicator in the dashboard (0.51.0)
- [ ] Contracts page — each row imported from GitHub shows a small GitHub-logo pill next to the name, labeled `<owner>/<repo>`
- [ ] The badge links to the exact blob at the imported commit (`<repo>/blob/<commit>/<file_path>`) in a new tab
- [ ] The badge refuses to render for any `source_repo_url` not matching `https://github.com/...` (defensive allowlist against bad DB rows)
- [ ] Contract detail page shows a full **Source** panel with clickable repo URL, short-SHA commit link (→ `<repo>/commit/<sha>`), and file path link (→ blob at commit)
- [ ] Manually-uploaded contracts (no `source_repo_url`) render with no badge and no Source panel

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
| Webhook event dispatch (sync-on-push / sync-on-PR) | **Shipped in api-service 0.43.0** — the webhook now parses push/PR events, validates HMAC, checks the per-repo opt-in flags, and enqueues the sync Celery task. See `feature-tests/14-github-webhook-dispatcher.md` and `playbooks/github-app-byo-troubleshooting.md § Issue 7`. |
| Auto-scan-on-sync | Sync imports Contract rows with `status='uploaded'` but does **not** enqueue scans even when `auto_scan_enabled=true`. Wiring the scan-queue call is a narrow follow-up (tier/quota check + POST to tool-integration). |
| Per-repo toggles in the dashboard (`auto_scan_enabled`, `scan_on_push`, `scan_on_pr`) | Backend flags live on `IntegrationRepositoryModel` but aren't exposed in a UI yet. |
| Multi-file Foundry/Hardhat project ingest (via `ContractFileModel`) | Each `.sol` is imported as a single-file contract for this pass. Project-level scanning via the multi-file path is a separate effort. |
| Incremental diff sync via GitHub tree-SHA comparison | Current sync always re-walks the full tree. Diff sync is a future optimization separate from the 0.43.0 webhook dispatcher. |
| `fetch_repo_tree` truncation handling (repos >100k entries) | Only a warning log today; sub-tree recursion is a later enhancement once a customer needs it. |
| Retire legacy `oauth_service.py` GitHub path | Kept as dead code until dashboard confirms no callers |
| GitHub Enterprise Server support via Broker | Multi-week separate initiative |

## Verification (live in prod)

```bash
# 1. Backend version reflects 0.40.3
curl -s https://app.0xapogee.com/api/v1/health/live | jq .version
# Expected: "0.40.3"

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

# 5. Import-installed-repos requires auth
curl -s -o /dev/null -w "%{http_code}" -X POST \
  https://app.0xapogee.com/api/v1/organizations/00000000-0000-0000-0000-000000000000/integrations/github-app/00000000-0000-0000-0000-000000000000/import-installed-repos
# Expected: 401
```

## Related

- Pipeline details: `docs/pipelines/github-app-byo-manifest-pipeline.md`
- Customer install workflow: `docs/workflows/github-app-byo-install-workflow.md`
- Troubleshooting: `docs/playbooks/github-app-byo-troubleshooting.md`
- URL-based GitHub ingest (different path): `docs/feature-tests/93-github-url-ingest-and-tier-limits-2026-04.md`
