# GitHub App BYO Manifest Pipeline

**Version:** 1.0.0
**Last Updated:** 2026-04-17
**Related migration:** 087
**Related code:**
- Service: `blocksecops-api-service/src/application/services/github_app_service.py`
- Endpoints: `blocksecops-api-service/src/presentation/api/v1/endpoints/github_app.py`
- Tests: `tests/unit/services/test_github_app_service.py`, `tests/integration/test_github_app_manifest_flow.py`

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

### Stage 9 — Webhook receiver (stub)

**Endpoint:** `POST /api/v1/github-app/webhook`
**Auth:** HMAC-SHA256 signature in `X-Hub-Signature-256` (verified if present, not yet enforced)
**Rate limit:** 120/minute

Currently a 204 stub that:
1. Logs delivery ID + event name + installation ID (from payload) for traceability
2. Returns 204

**Not yet implemented:** signature enforcement, event routing, scan dispatch. These ship in the follow-up "GitHub App webhook dispatcher" pass.

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
