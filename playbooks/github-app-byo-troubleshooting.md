# GitHub App BYO Troubleshooting

Operator-facing playbook for issues with the bring-your-own GitHub App flow (migration 087, api-service 0.40.3+, dashboard 0.51.0+).

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
| `Create GitHub App` button blocked by CSP `form-action` | Dashboard CSP missing `https://github.com` in `form-action` | Issue 8 |
| 5 duplicate "Successfully connected GitHub!" toasts after install | Dashboard <0.50.3 used `window.history.replaceState` which did not update React Router's `useSearchParams` | Issue 9 |
| List-integrations 422 "undefined" on page load after GitHub redirect | Dashboard called `refetch()` before `currentOrganization?.id` resolved | Issue 10 |
| Modal empty; "Import from GitHub" button missing or does nothing | api-service <0.39.1 lacks `/import-installed-repos` endpoint, or button not clicked after install | Issue 11 |
| Repo shows `Syncing` forever, 0 contracts | celery-worker egress or mapper-load issue; was the 0.39.1 stub | Issue 12 |
| Sync hits `error`, `sync_error` says "private key decryption failed" | Fernet key rotated without re-encrypt | Issue 13 |
| Sync `synced` but no contracts on `/contracts` page | API response schema not returning `source_repo_url`; browser cache | Issue 14 |
| Disconnect → re-create fails with "name already taken" | GitHub App names are globally unique; Apogee's disconnect keeps the App on GitHub | Issue 15 |

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

## Issue 8: CSP `form-action` blocks the manifest POST to github.com

**Symptom (browser console):**
```
Content-Security-Policy: The page's settings blocked the loading of a resource
(form-action) at https://github.com/settings/apps/new?state=...
because it violates the following directive: "form-action 'self'"
```

**Cause:** Before dashboard 0.50.1 the CSP declared `form-action 'self'`, which blocks the auto-submitted manifest form that POSTs to `github.com/settings/apps/new` (or `github.com/organizations/<org>/settings/apps/new`).

**Fix:** `form-action 'self' https://github.com` in both CSP sources:

- `blocksecops-dashboard/serve.json` (baked into the static `serve` config)
- `blocksecops-dashboard/k8s/overlays/production/middleware-security-headers.yaml` (Traefik middleware for the production GCP path)

Both must stay in sync; changing only one silently drifts depending on which ingress path a cluster uses.

**Verify after deploy:**
```bash
docker run --rm --entrypoint cat \
  us-west1-docker.pkg.dev/<project>/apogee/dashboard:<new-version> \
  /app/dist/serve.json | grep -o "form-action[^;]*"
# Expected: form-action 'self' https://github.com
```

## Issue 9: 5 duplicate "Successfully connected GitHub!" toasts

**Symptom:** After GitHub redirects to `/integrations?success=true&provider=github`, the user sees multiple identical success toasts (often 5) stacked up.

**Cause (dashboard <0.50.3):** `SourceControlTab` used `window.history.replaceState({}, '', '/integrations?tab=source-control')` to clear the `success=true` query param. `replaceState` does **not** notify React Router's `useSearchParams`, so subsequent re-renders (auth state flickers, `addToast` reference changes, etc.) still see `success=true` and re-run the effect.

**Fix (dashboard 0.50.3+):** use `setSearchParams({ tab: 'source-control' }, { replace: true })` so React Router actually observes the cleared query, and guard the effect with a `useRef` so even if it did re-fire, the toast wouldn't double-up.

## Issue 10: `GET /organizations/undefined/integrations` → 422 after GitHub redirect

**Symptom:** Browser network tab shows `XHR GET /api/v1/organizations/undefined/integrations 422` immediately after returning from GitHub, and the integration does not appear in the UI even though it exists in the DB.

**Cause:** After a GitHub round-trip the entire dashboard re-mounts; `currentOrganization` is null until `/users/me` resolves and the org list loads. `SourceControlTab`'s callback-handler effect called `refetch()` on the integrations query, which **bypasses React Query's `enabled: !!orgId` gate** and fires with `orgId=undefined`.

**Fix (dashboard 0.50.3+):** the effect now early-returns unless `currentOrganization?.id` is truthy, and re-runs once it resolves. The `enabled` gate handles all other call sites automatically.

**Verify the integration really is in the DB despite the UI not showing it:**
```bash
kubectl exec -n postgresql-prod postgresql-0 -- psql -U blocksecops -d solidity_security -c \
  "SELECT id, status, external_username, settings->>'auth_model' as auth_model
   FROM integrations WHERE provider='github' AND organization_id='<ORG_ID>';"
```

## Issue 11: "Import from GitHub" button missing or no-op

**Symptom:** In the Manage Repositories modal the empty state reads *"No repositories imported yet. Click Import from GitHub above…"* but either the button is missing (older dashboard), or clicking it fails with `404` / `501`.

**Cause:** The import endpoint lives in api-service 0.39.1+ — earlier versions don't have it. Dashboard 0.50.3+ expects the endpoint.

**Diagnostic:**
```bash
# Confirm backend is 0.39.1+ and endpoint is registered
kubectl -n api-service-prod get deployment api-service \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

curl -s -o /dev/null -w "%{http_code}" -X POST \
  https://app.0xapogee.com/api/v1/organizations/00000000-0000-0000-0000-000000000000/integrations/github-app/00000000-0000-0000-0000-000000000000/import-installed-repos
# Expected: 401 (unauth). If 404, api-service is pre-0.39.1.
```

**Fix:** bump api-service to 0.39.1 (or later), redeploy.

**If both versions are current and it's still failing,** check the api-service logs:
```bash
kubectl logs -n api-service-prod deployment/api-service --tail=100 | grep -iE "import|github"
```
A 502 with *"GitHub API error while listing installation repositories"* means the stored App credentials can't authenticate — go to Issue 6.

## Issue 12: Repo stuck on `Syncing`, 0 contracts

**Symptom:** Customer clicks `Sync now` on a connected repo. Status flips to `Syncing`, but after minutes/hours no contracts appear.

Three possible causes in order of likelihood for api-service 0.40.3+:

### 12a. celery-worker cannot reach api.github.com

The worker needs TCP 443 egress to the public internet. The dedicated policy `celery-worker-egress-external-apis` (api-service 0.40.1+) permits this; if missing, sync tasks fail with `ConnectTimeout`.

**Diagnostic:**
```bash
kubectl -n api-service-prod logs deployment/celery-worker --tail=100 | grep -iE "ConnectTimeout|github-sync"
kubectl -n api-service-prod get networkpolicy celery-worker-egress-external-apis
```

**Fix:** `kubectl apply -k k8s/overlays/gcp/` to re-apply the base policies.

### 12b. SQLAlchemy mapper resolution fails on task start

The Celery task imports `ContractModel` which triggers `VulnerabilityModel`'s string-relationship to `DeduplicationGroupModel` — a class living in `src/infrastructure/database/specialized_models/intelligence.py`. If that module isn't imported before first mapper resolution, the task raises `InvalidRequestError: failed to locate a name ('DeduplicationGroupModel')`.

**Fix (already in 0.40.1):** `github_sync_task.py` explicitly imports every submodule of `specialized_models` for side effects. If a new model file is added to that package later, add it to the import list.

### 12c. Stuck row left over from the 0.39.1 stub era

Before api-service 0.40.0, the endpoint set `sync_status='syncing'` and returned without enqueuing any task. Integrations that were clicked in that window have DB rows stuck in `syncing` indefinitely — the dashboard disables the Sync button for rows in that state.

**Cleanest recovery (no direct DB write):** ask the customer to click **Disconnect** on the repo row in the Manage Repositories modal, then **Import from GitHub** again. That re-creates the row with `sync_status='pending'` and the Sync button is re-enabled on 0.40.1+.

**Operator override (direct UPDATE, requires owner approval):**
```bash
kubectl -n postgresql-prod exec postgresql-0 -- psql -U blocksecops -d solidity_security -c \
  "UPDATE integration_repositories
   SET sync_status='pending', sync_error=NULL
   WHERE sync_status='syncing' AND integration_id='<INTEGRATION_ID>';"
```

**Verify the worker actually processed a task:**
```bash
kubectl -n api-service-prod logs deployment/celery-worker --tail=200 \
  | grep -E "Task github_sync.sync_repo_contracts"
# Expect: received → start → done lines for the customer's repo_id
```

## Issue 13: `sync_error: private key decryption failed`

**Symptom:** Sync row shows *Error*, `sync_error` starts with "private key decryption failed".

**Cause:** `INTEGRATION_ENCRYPTION_KEY` has been rotated in the running api-service pods without re-encrypting existing `github_app_private_key_encrypted` ciphertexts. Fernet decrypt fails because the ciphertext was written with the old key.

**Fix (operator):** revert `INTEGRATION_ENCRYPTION_KEY` to the previous value *or* re-encrypt all affected rows with a small migration helper. The customer-visible recovery is a full re-create of the integration (disconnect → manifest flow → install → sync), which generates fresh credentials under the current key.

## Issue 14: Sync reports `synced` but contracts don't appear on the Contracts page

**Symptom:** DB shows `contracts_found > 0` and the `contracts` table has matching rows with `source_repo_url` populated, but the dashboard `/contracts` page doesn't list them.

Two causes to check in order:

### 14a. Browser cache — old dashboard bundle

The contract list uses a 30 s React Query `staleTime`, but if the dashboard bundle is older than 0.51.0 the `source_repo_url`, `source_commit_hash`, and `source_file_path` fields are never rendered (the TS type doesn't include them).

**Fix:** customer hard-refreshes (Ctrl-Shift-R). Check the bundle filename changes from `index-Dr11r53i.js` (0.50.3) to whatever 0.51.0 baked.

### 14b. Backend response schema missing the fields

If a new endpoint that returns `ContractResponse` is added without passing the three source fields to the constructor, the dashboard won't render the badge for contracts surfaced via that endpoint. Every `ContractResponse(...)` and `ContractDetailResponse(...)` call site in the codebase MUST include `source_repo_url`, `source_commit_hash`, `source_file_path`.

**Diagnostic:**
```bash
kubectl -n api-service-prod exec deployment/api-service -- grep -rnE "ContractResponse\(|ContractDetailResponse\(" /app/src/ | xargs -I{} sh -c 'echo {} && ...' # or check locally
```

**Fix:** add the three fields to any constructor that's missing them; rebuild + bump PATCH.

## Issue 15: Disconnect + re-create fails with "name already taken"

**Symptom:** Customer disconnects a GitHub integration in Apogee, goes through the Create GitHub App flow again, and GitHub rejects with *"Name is already taken"* on the Create page.

**Cause:** GitHub App names are **globally unique across github.com**. Apogee's disconnect removes the `integrations` + `integration_credentials` + `integration_repositories` rows from our DB but **does not** delete the underlying GitHub App — it still lives on the customer's GitHub account under *Settings → Developer settings → GitHub Apps*.

**Three recovery options, fastest first:**

1. **Rename on the GitHub Create page.** The manifest pre-fills the `GitHub App name` field but GitHub lets you edit it. Add a suffix like "Apogee for AcmeCorp 2" and click Create.
2. **Delete the old App on GitHub first.** Navigate to `https://github.com/settings/apps/<slug>`, *Advanced* tab, *Delete GitHub App*. Then retry the manifest flow with the default name.
3. **Reuse the existing App.** Not supported by the current manifest flow; an "attach existing App" path is a backlog item.

## Related

- Feature test: `docs/feature-tests/NN-github-app-byo-manifest-2026-04.md`
- Workflow: `docs/workflows/github-app-byo-install-workflow.md`
- Pipeline internals: `docs/pipelines/github-app-byo-manifest-pipeline.md`
- URL-ingest troubleshooting (different path): `docs/playbooks/github-url-ingest-troubleshooting.md`
