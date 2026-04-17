# GitHub App BYO Troubleshooting

Operator-facing playbook for issues with the bring-your-own GitHub App flow (migration 087, api-service 0.39.0+).

## Distinguishing from URL-ingest issues

If a customer reports a GitHub-related error, first identify which path they're on:

- URL-ingest errors come from `POST /api/v1/contracts/from-github`. Route to `github-url-ingest-troubleshooting.md`.
- BYO-App errors come from `/api/v1/github-app/*` endpoints, from the Integrations page, or from the `integration_credentials` table with `github_app_*` columns populated. Continue here.

## Quick-reference table

| Symptom | Likely cause | Section below |
|---|---|---|
| `/manifest-init` returns 503 | ENV / config not ready | Issue 1 |
| `/manifest-callback` returns 302 with `?error=invalid_state` | State JWT expired (>10min) or tampered | Issue 2 |
| `/manifest-callback` returns 302 with `?error=manifest_conversion_failed` | GitHub code expired or GitHub 5xx | Issue 3 |
| `/install-url` returns 400 "App was never created" | Customer never completed manifest flow | Issue 4 |
| `/setup` returns 302 with `?error=installation_lookup_failed` | Private key decryption failed OR installation revoked | Issue 5 |
| Sync fails with 401 | Installation token rejected | Issue 6 |
| Webhook delivery fails on GitHub's side | URL unreachable or signature mismatch | Issue 7 |

## Issue 1: `/manifest-init` returns 503

**Diagnostic:**
```bash
kubectl logs -n api-service-prod -l app=api-service --tail=100 | grep -i github
```

**Likely causes:**
- `JWT_SECRET_KEY` not set or empty
- `INTEGRATION_ENCRYPTION_KEY` not set → encryption will fail later in the flow
- `dashboard_base_url` ConfigMap key missing

**Fix:** verify ExternalSecret sync status:
```bash
kubectl describe externalsecret api-service-secret -n api-service-prod | grep -A5 "Sync Status"
```
Re-sync if drifted, pod restart to pick up new values.

## Issue 2: `/manifest-callback` redirects with `?error=invalid_state`

**Most common causes:**

### 2a. State JWT expired

State JWT has a 10-minute TTL (`STATE_JWT_TTL_SECONDS = 600` in `github_app_service.py`). If the customer opened the GitHub page, got distracted, and came back >10 min later, the state is expired.

**Fix:** customer retries from the beginning — click **Create GitHub App** in Apogee again.

### 2b. State JWT has wrong issuer

If the install-flow state (issuer `apogee-github-app-install`) is sent to `/manifest-callback`, it will be rejected because that endpoint expects issuer `apogee-github-app-manifest`. This is a **security feature** (cross-flow replay protection) — not a bug.

**Diagnostic:** check api-service logs for:
```
manifest-callback: state invalid (state issuer mismatch: expected apogee-github-app-manifest, got apogee-github-app-install)
```

### 2c. JWT_SECRET_KEY rotated

If the platform's `JWT_SECRET_KEY` was rotated between the state-JWT signing and verification, every in-flight manifest flow will fail.

**Fix:** customers retry; no platform action needed unless many customers hit this simultaneously.

## Issue 3: `/manifest-callback` returns `?error=manifest_conversion_failed`

**Cause:** `POST https://api.github.com/app-manifests/{code}/conversions` returned non-201.

**Most common subcase:** code expired. GitHub's manifest codes are valid for **1 hour** from redirect. If the customer sat on the GitHub app-creation page for >1 hour, the code is dead.

**Other subcases:**
- GitHub Enterprise not supported by this flow (this is the Cloud endpoint)
- Network egress blocked from api-service pod → check NetworkPolicy

**Diagnostic:**
```bash
kubectl logs -n api-service-prod -l app=api-service --tail=100 | grep "manifest conversion failed"
```

**Fix:** customer retries the whole flow.

## Issue 4: `/install-url` returns 400 "App was never created"

Credential row exists but `github_app_slug` is NULL. The manifest flow was initiated but the callback never completed (network hiccup, user closed tab, etc.).

**Fix:**
```sql
-- Check state
SELECT i.id, i.status, c.github_app_slug, c.github_app_created_at
FROM integrations i
JOIN integration_credentials c ON c.integration_id = i.id
WHERE i.organization_id = '<org_id>' AND i.provider = 'github';
```

If `github_app_slug IS NULL`, customer restarts the flow (manifest-init). If they completed App creation on GitHub's side but Apogee never recorded it, the App exists in GitHub but Apogee doesn't know — customer must delete it from GitHub manually, then restart.

## Issue 5: `/setup` returns `?error=installation_lookup_failed`

**Cause:** Apogee signed an app JWT with the stored private key and called `GET /app/installations/{id}`, but GitHub rejected it.

**Subcases:**

### 5a. Private key decryption failed

Usually means `INTEGRATION_ENCRYPTION_KEY` was rotated without re-encrypting the stored ciphertexts.

**Fix:** restore the old encryption key, OR re-run the manifest flow with a freshly-generated App.

### 5b. App was deleted on GitHub's side

If the customer deleted the App in GitHub settings, GitHub will 404 the installation lookup.

**Fix:** customer starts fresh with a new App (manifest-init).

### 5c. Installation revoked mid-flow

Customer clicked Install, then immediately clicked Uninstall on GitHub before the redirect landed at Apogee. Rare but possible.

## Issue 6: Sync fails with 401 "installation token rejected"

Runtime failure when Apogee tries to call `api.github.com` with an installation token.

**Cause ladder:**
1. Installation was uninstalled from the customer's GitHub account/org
2. Private key rotated on GitHub side (customer regenerated it)
3. App's permissions were narrowed by GitHub (e.g. org admin restricted it)
4. Installation token cache is stale and cache eviction didn't happen

**Diagnostic:**
```bash
kubectl logs -n api-service-prod -l app=api-service --tail=100 | grep "installation token rejected"
```

**Fix:**
- If (1): customer reinstalls the App from GitHub
- If (2) or (3): customer regenerates the private key in GitHub, OR creates a new App via manifest-init
- If (4): next call will refetch; if persistent, restart api-service pods

## Issue 7: Webhook delivery fails on GitHub's side

Customer sees failed deliveries in GitHub App settings → Advanced → Recent Deliveries.

### 7a. Receiver returns 204 but customer expects auto-scans

**Current state (2026-04-17):** the webhook receiver is a 204 stub. Auto-scan-on-push/PR is **deferred to a follow-up pass**. The manifest declares `default_events: []` so GitHub shouldn't even be sending events yet — if it is, the customer enabled events on the App settings page.

**Fix:** this is expected; set expectations with the customer.

### 7b. Signature verification failing

When the webhook receiver ships real dispatch, it'll validate `X-Hub-Signature-256` against the per-integration `github_app_webhook_secret_encrypted`. If the customer rotated the webhook secret on GitHub's side, Apogee's stored ciphertext is stale.

**Fix (once real dispatch ships):** re-run manifest-init — GitHub will issue a new webhook secret on App creation.

## Operator utilities

### Find an integration by GitHub installation ID

```bash
kubectl exec -n postgresql-prod postgresql-0 -- psql -U blocksecops -d solidity_security -c \
  "SELECT i.id, i.organization_id, i.external_username, c.github_app_slug
   FROM integrations i JOIN integration_credentials c ON c.integration_id = i.id
   WHERE c.github_app_installation_id = <ID>;"
```

### Count active GitHub App BYO integrations

```bash
kubectl exec -n postgresql-prod postgresql-0 -- psql -U blocksecops -d solidity_security -c \
  "SELECT COUNT(*) FROM integration_credentials WHERE github_app_installation_id IS NOT NULL;"
```

### Rotate a customer's stored private key (customer-initiated)

1. Customer regenerates private key in GitHub App settings
2. Customer re-runs manifest-init in Apogee — a new App (different App ID) gets created
3. OR: customer manually uploads new PEM via a future support endpoint (not built yet)

## Related

- Feature test: `docs/feature-tests/NN-github-app-byo-manifest-2026-04.md`
- Workflow: `docs/workflows/github-app-byo-install-workflow.md`
- Pipeline internals: `docs/pipelines/github-app-byo-manifest-pipeline.md`
- URL-ingest troubleshooting (different path): `docs/playbooks/github-url-ingest-troubleshooting.md`
