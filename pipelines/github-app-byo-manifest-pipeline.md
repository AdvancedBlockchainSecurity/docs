# GitHub App BYO Manifest Pipeline

**Version:** 1.2.0
**Last Updated:** 2026-04-17
**Related migration:** 087
**Code versions:** api-service `0.40.3`, dashboard `0.51.0`
**Related code:**
- Service: `blocksecops-api-service/src/application/services/github_app_service.py`
- Endpoints: `blocksecops-api-service/src/presentation/api/v1/endpoints/github_app.py`
- Tests: `tests/unit/services/test_github_app_service.py`, `tests/integration/test_github_app_manifest_flow.py`
- Dashboard wizard: `blocksecops-dashboard/src/components/integrations/hub/GitHubAppSetupWizard.tsx`
- Dashboard CSP: `blocksecops-dashboard/serve.json` + `k8s/overlays/production/middleware-security-headers.yaml` (both must carry `form-action 'self' https://github.com`)

## Overview

Technical pipeline for the BYO GitHub App flow. Each Apogee org registers their own GitHub App via GitHub's Manifest flow. No platform-level App credentials — everything per-integration in the DB.

## Pipeline stages

### Stage 1 — Manifest init (authenticated)

**Endpoint:** `POST /api/v1/organizations/{org_id}/integrations/github-app/manifest-init`
**Auth:** Bearer JWT + org admin check
**Rate limit:** general/default tier

**Inputs:** `org_id` (path), caller's user UUID (from JWT)

**Process:**
1. Verify org membership with `require_admin=True`
2. Look up `OrganizationModel` to get the org's display name (used in the manifest's default App name)
3. Build manifest dict via `GitHubAppService.build_manifest()`:
   ```json
   {
     "name": "Apogee for <org-name>",
     "url": "https://app.0xapogee.com",
     "hook_attributes": {"url": "https://app.0xapogee.com/api/v1/github-app/webhook", "active": true},
     "redirect_url": "https://app.0xapogee.com/api/v1/github-app/manifest-callback",
     "callback_urls": ["https://app.0xapogee.com/api/v1/github-app/setup"],
     "setup_url": "https://app.0xapogee.com/api/v1/github-app/setup",
     "setup_on_update": true,
     "public": false,
     "default_permissions": {"contents": "read", "metadata": "read", "pull_requests": "read"},
     "default_events": []
   }
   ```
4. Generate a 16-byte URL-safe nonce
5. Sign a state JWT (`iss=apogee-github-app-manifest`, `exp=now+10min`, includes `org_id`, `user_id`, `nonce`)
6. Return `{manifest, state, target_url: "https://github.com/settings/apps/new"}`

**Output:** `ManifestInitResponse` — dashboard auto-submits an HTML form with `manifest` as the body field and `state` as the query param.

### Stage 2 — GitHub App creation (GitHub side)

Dashboard submits:
```
POST https://github.com/settings/apps/new?state=<jwt>
Content-Type: application/x-www-form-urlencoded

manifest=<url-encoded-json>
```

GitHub pre-fills the App creation page from the manifest. Customer:
- Picks account/org ownership
- Optionally renames
- Clicks **Create GitHub App**

GitHub generates the App and redirects to `<redirect_url>?code=<one-hour-code>&state=<our-jwt>`.

### Stage 3 — Manifest callback (unauthenticated from HTTP)

**Endpoint:** `GET /api/v1/github-app/manifest-callback?code=X&state=Y`
**Auth:** state JWT only (no Bearer — GitHub doesn't carry our auth)
**Rate limit:** 30/minute

**Process:**
1. `verify_manifest_state(state)`:
   - JWT decode with `JWT_SECRET_KEY`
   - Require `exp`, `iat`, `iss` claims
   - Reject if `iss != "apogee-github-app-manifest"`
   - Raises `GitHubAppAuthError` on any failure → redirect with `?error=invalid_state`
2. Parse `org_id` + `user_id` from claims (UUID validation)
3. `exchange_manifest_code(code)`:
   - `POST https://api.github.com/app-manifests/{code}/conversions`
   - GitHub returns `{id, slug, client_id, pem, webhook_secret, ...}`
   - Code valid for 1 hour (GitHub-side)
4. Encrypt sensitive fields:
   - `private_key_pem` → Fernet-encrypted via `encryption_service.encrypt`
   - `webhook_secret` → Fernet-encrypted (if present)
5. Upsert:
   - `IntegrationModel` row: one per org with `provider="github"`; `status="pending"`, `settings={"auth_model": "github_app_byo"}`
   - `IntegrationCredentialModel` row: per-integration with encrypted key + metadata columns
6. Redirect to dashboard: `{dashboard_base_url}/integrations?tab=source-control&success=true&provider=github`

**Idempotent:** re-running the flow updates the existing rows rather than creating duplicates.

### Stage 4 — Install URL (authenticated)

**Endpoint:** `POST /api/v1/organizations/{org_id}/integrations/github-app/{integration_id}/install-url`
**Auth:** Bearer + org admin
**Rate limit:** general/default

**Process:**
1. Verify org membership + admin
2. Look up `IntegrationModel` + `IntegrationCredentialModel` joined on `integration_id`
3. Require `credential.github_app_slug` exists (created by manifest callback)
4. Sign an install-flow state JWT (different issuer from manifest state: `apogee-github-app-install`) with `integration_id`, `org_id`, `user_id`
5. Return `{install_url: "https://github.com/apps/{slug}/installations/new?state=<jwt>"}`

### Stage 5 — Install (GitHub side)

Customer picks repos on GitHub, clicks Install. GitHub redirects to Apogee's `setup_url`:

```
/api/v1/github-app/setup?installation_id=N&setup_action=install&state=Y
```

### Stage 6 — Setup callback (unauthenticated from HTTP)

**Endpoint:** `GET /api/v1/github-app/setup?installation_id=N&setup_action=install&state=Y`
**Auth:** state JWT only
**Rate limit:** 30/minute

**Process by setup_action:**
- `install` — proceed (below)
- `update` — no-op, redirect with success (customer reconfigured repo scope)
- `request` — no-op, success (install requires org-admin approval that hasn't happened yet)
- anything else — redirect with `?error=invalid_setup_action`

**For `install`:**
1. `verify_install_state(state)` — issuer must be `apogee-github-app-install`
2. Parse `integration_id` from claims
3. Load credential row; decrypt private key via Fernet
4. Call `get_installation_info(app_id, private_key_pem, installation_id)`:
   - Signs RS256 JWT with decrypted private key
   - `GET https://api.github.com/app/installations/{installation_id}` with `Bearer <jwt>`
   - Returns account metadata (login, avatar_url, id)
5. Update `IntegrationModel`:
   - `status = "connected"`
   - `external_account_id`, `external_username`, `external_avatar_url` populated
6. Update credential row:
   - `github_app_installation_id = N`
   - `github_app_installed_at = now()`
7. Redirect to dashboard with success banner

### Stage 7 — Installation token exchange (runtime, on every GitHub API call)

Invoked whenever Apogee needs to read content from a customer repo:

```
get_installation_token(app_id, private_key_pem, installation_id)
  → check in-process cache keyed on (app_id, installation_id)
  → if cached and >5min remain: return cached
  → else:
      sign RS256 app JWT (iss=app_id, exp=now+10min)
      POST https://api.github.com/app/installations/{installation_id}/access_tokens
        with Bearer <app_jwt>
      receive {token, expires_at} (token lives 1h)
      cache with entry = (token, expires_at)
      return token
```

**Cache characteristics:**
- Scope: in-process per worker, not shared across pods
- Key: `(app_id, installation_id)` tuple — each org gets its own cache entry
- Eviction: automatic after 55 minutes; forced on 401 from GitHub
- Thread safety: `threading.Lock` guards reads/writes

### Stage 8 — GitHub API calls (runtime)

Methods on `GitHubAppService` all take per-integration `(app_id, private_key_pem, installation_id)`:

- `list_installation_repositories` — `GET /installation/repositories` with installation token, paginated via Link header
- `fetch_file_content` — `GET /repos/{owner}/{repo}/contents/{path}?ref=<sha>` with installation token
- `get_installation_info` — `GET /app/installations/{id}` with app JWT (not installation token — the JWT is what GitHub uses to prove we own the App)

### Stage 8.5 — Import installed repositories (authenticated, 0.39.1+)

**Endpoint:** `POST /api/v1/organizations/{org_id}/integrations/github-app/{integration_id}/import-installed-repos`
**Auth:** Bearer JWT + org admin check
**Rate limit:** general/default tier

**Inputs:** `org_id`, `integration_id` (path)

**Process:**
1. Verify org membership with `require_admin=True`
2. Load `(IntegrationModel, IntegrationCredentialModel)` for this org+integration; 404 if missing
3. Reject if `integration.status != "connected"` (400) or credential is missing `github_app_installation_id` / `github_app_id` / `github_app_private_key_encrypted` (400/500 as appropriate)
4. Decrypt PEM via `decrypt_private_key(credential.github_app_private_key_encrypted)`
5. Call `list_installation_repositories(app_id, pem, installation_id)` — paginates via Link headers until all pages consumed
6. Fetch existing `IntegrationRepositoryModel` rows for the integration, keyed on `external_repo_id`
7. For each GitHub repo not already in the set, insert a new row (`sync_status='pending'`, `is_private` mirrored from GitHub, `external_repo_id=str(gh["id"])`)
8. If any new rows inserted, bump `integration.repos_synced`
9. Commit, re-query the full ordered list, return `RepositoryListResponse`

**Idempotency:** The dedupe check on `(integration_id, external_repo_id)` means the endpoint is safe to call repeatedly (customers re-click Import after re-Configuring the installation on GitHub).

**Failure modes:**
- GitHub `401` while listing → installation token evicted, `GitHubAppAuthError` → 502 response
- GitHub `5xx` or timeout → `GitHubAppError` → 502 response
- No network egress to `api.github.com` → surfaces as a 502 with an httpx exception string

### Stage 10 — Repo sync Celery task (0.40.0+)

**Endpoint:** `POST /api/v1/organizations/{org_id}/integrations/{integration_id}/repositories/{repo_id}/sync`
**Auth (HTTP layer):** Bearer JWT + org admin
**Worker queue:** `github_sync` (routed via `task_routes` in `celery_app.py`)
**Task name:** `github_sync.sync_repo_contracts`
**Timeouts:** 10 min soft, 12 min hard; `max_retries=3` with 60 s delay
**Rate limit (HTTP):** general/default tier

**HTTP flow:**
1. `verify_org_membership(require_admin=True)` + 404 if integration/repo missing.
2. Reject 400 if integration `status != connected` or provider is `github` and `IntegrationCredentialModel.github_app_installation_id` is null.
3. Set `repo.sync_status='syncing'`, clear `sync_error`, commit.
4. Import `sync_repo_contracts` from `src.infrastructure.tasks.github_sync_task` (local import — avoids pulling Celery at API-module load in non-worker contexts) and enqueue via `apply_async(args=[org_id, integration_id, repo_id])`.
5. Return the refreshed `IntegrationRepositoryResponse`.

**Worker flow (`_sync_async`):**
1. Single joined `SELECT … FOR UPDATE` loads integration + credential + repo row. Bails early with `sync_status='error'` + message for any missing row, non-connected integration, missing installation_id, or incomplete credentials.
2. `decrypt_private_key(credential.github_app_private_key_encrypted)` via the Fernet wrapper.
3. Parse `repo.repo_full_name` → `(owner, name)`. Bail early with a typed error if the name is malformed.
4. `get_default_branch_commit(app_id, pem, installation_id, owner, name)` → `(default_branch, head_sha)`.
5. `fetch_repo_tree(app_id, pem, installation_id, owner, name, head_sha)` — `GET /repos/{owner}/{name}/git/trees/{sha}?recursive=1` with installation token. Logs a warning if GitHub returns `truncated: true`.
6. Filter to `type=='blob'`, `path.endswith('.sol')`, `size <= 1_048_576`. Enforce 100-file + 50 MB cumulative caps; skipped-due-to-cap count flows into the eventual `sync_error` summary.
7. For each kept file: `fetch_file_content(...)` → base64-decode → UTF-8 decode (skip on UnicodeDecodeError).
8. Upsert on `(organization_id, source_repo_url, source_file_path)`:
    - New row → INSERT `ContractModel` with `language='solidity'`, `status='uploaded'`, all `source_*` fields populated, `user_id = integration.created_by`.
    - Existing row + same commit hash → unchanged.
    - Existing row + different commit → UPDATE `source_code`, `source_commit_hash`, `source_hash`, `lines_of_code`, reset `status='uploaded'`.
9. Update repo row: `sync_status='synced'`, `last_synced_at=now()`, `last_synced_commit=head_sha`, `contracts_found=<recount>`. If there were partial errors / budget skips / decode skips, write a truncated (≤500 chars) summary to `sync_error`.
10. On uncaught exception: set `sync_status='error'` + truncated error message, commit, re-raise so Celery's backoff kicks in.

**Dedupe key:** `(organization_id, source_repo_url, source_file_path)` — this allows the same file path in two different repos to land as two contracts, and allows two orgs to independently own copies of the same file.

**Egress:** celery-worker pods have a dedicated NetworkPolicy (`celery-worker-egress-external-apis`) permitting TCP 443 to non-RFC1918 IPs only. Mirrors the existing `api-service-egress-external-apis` policy so both the API pod and the worker can reach `api.github.com`.

**Failure modes:**

| Failure | sync_status | sync_error | Client impact |
|---|---|---|---|
| Integration missing / not-connected / installation_id null | `error` | clear message | Dashboard shows Error badge + message |
| Private key decryption fails | `error` | "private key decryption failed: …" | Customer likely rotated `INTEGRATION_ENCRYPTION_KEY` without re-encrypt — operator follow-up |
| GitHub 401 on installation token | retry | — | Celery retry × 3 @ 60s; token cache evicted server-side each attempt |
| GitHub 403 / 5xx on tree walk or blob fetch | retry | populated after final retry | Up to 3 retries, then stuck in `error` |
| Individual file fails (404 on rename, binary file, partial 403) | `synced` | per-file summary up to 5 entries | Other files still import; row reports `synced` with partial errors |
| Budget cap hit (file >1 MB, >100 files, >50 MB total) | `synced` | "N file(s) skipped (budget cap)" | Expected; not an error |
| Worker crash mid-task | requeued | — | `acks_late=True` redelivers; subsequent successful run overwrites error state |

### Stage 9 — Webhook dispatcher (api-service ≥ 0.43.0)

**Endpoint:** `POST /api/v1/github-app/webhook`
**Auth:** HMAC-SHA256 signature in `X-Hub-Signature-256` (required, enforced).
**Rate limit:** 120/minute.

**Dispatch pipeline:**
1. Parse JSON body (malformed → 204-ack + log; GitHub won't retry 2xx).
2. Extract `installation.id`; no installation → 204 (ping / meta event, benign ack).
3. Look up `IntegrationCredentialModel` by `github_app_installation_id`; unknown → 204 (non-leak).
4. Fernet-decrypt `github_app_webhook_secret_encrypted`; `InvalidToken` / `ValueError` / `TypeError` → 204.
5. Verify `X-Hub-Signature-256` via `hmac.compare_digest` (constant-time); invalid → **401** `Invalid webhook signature`.
6. Whitelist event to `{push, pull_request}`; other event types → 204.
7. Extract `repository.id`; missing → 204.
8. Look up `IntegrationRepositoryModel` by `(integration_id, external_repo_id=str(repository.id))`; unknown → 204.
9. Gate on `repo.auto_scan_enabled`; for push events additionally require `repo.scan_on_push` AND `ref == refs/heads/<default_branch>`; for PR events additionally require `repo.scan_on_pr` AND `action ∈ {opened, synchronize, reopened}`. Any failed gate → 204 (logged with decision reason for observability).
10. Enqueue `sync_repo_contracts.apply_async(args=[org_id, integration_id, repo_id])` — same code path as the UI's **Sync now** button. Broker failure → **500** (GitHub retries on 5xx).

**Idempotency:** no dedicated webhook-delivery dedup table. The sync task is content-idempotent: on a retried delivery it walks the same tree at the same commit SHA and returns `unchanged` on every contract. Cost: one no-op Celery task per retry.

**Out of scope (filed as follow-up):** auto-creating scans after the sync completes. Keeping scan creation in the existing `create_scan` path preserves tier + quota + scanner-selection enforcement in one place.

**Security boundary:** every dispatch path is gated on valid HMAC **before** any side effect. Unsigned / mis-signed deliveries never touch Celery or the DB beyond the credential read needed to fetch the secret. Pinned by `tests/unit/presentation/test_github_webhook_dispatcher.py::TestWebhookSignatureVerification::test_handler_verifies_signature_before_dispatching`.

## Encryption pipeline

All private key + webhook secret read/writes go through `GitHubAppService.encrypt_private_key` / `.decrypt_private_key` (and `_webhook_secret` variants), which wrap `encryption_service` (Fernet — AES-128-CBC + HMAC-SHA256, key from `INTEGRATION_ENCRYPTION_KEY` env var).

Rotation of `INTEGRATION_ENCRYPTION_KEY` requires decrypting all existing ciphertexts with the old key and re-encrypting with the new one — same constraint as existing OAuth token storage.

## State JWT pipeline

Two separate issuers prevent cross-flow replay:

| Issuer | Purpose | TTL | Claims |
|---|---|---|---|
| `apogee-github-app-manifest` | Manifest-flow CSRF (pre-App-creation) | 10min | org_id, user_id, nonce |
| `apogee-github-app-install` | Install-flow CSRF (post-App-creation) | 10min | integration_id, org_id, user_id, nonce |

Cross-issuer verification fails closed: `verify_manifest_state()` rejects a JWT with `iss=apogee-github-app-install` and vice versa.

## Failure modes

| Stage | Failure | User-visible result |
|---|---|---|
| 1 | Caller not admin | 403 |
| 1 | Org not found | 403 (membership check fails first) |
| 3 | State JWT expired | 302 redirect with `?error=invalid_state` |
| 3 | State JWT wrong issuer | Same as above |
| 3 | Manifest code expired (1h) | 302 redirect with `?error=manifest_conversion_failed` |
| 3 | GitHub 5xx during conversion | Same as above |
| 4 | No slug (manifest callback never completed) | 400 |
| 6 | Installation not found on GitHub | 302 with `?error=installation_lookup_failed` |
| 6 | Private key decryption fails | Same as above (likely key rotation without re-encrypt) |
| 7 | App JWT rejected by GitHub | 401 → cache evicted, `GitHubAppAuthError` bubbles |

## Related

- Feature test checklist: `docs/feature-tests/NN-github-app-byo-manifest-2026-04.md`
- Customer-facing workflow: `docs/workflows/github-app-byo-install-workflow.md`
- Troubleshooting playbook: `docs/playbooks/github-app-byo-troubleshooting.md`
