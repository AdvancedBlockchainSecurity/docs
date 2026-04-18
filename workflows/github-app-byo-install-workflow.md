# GitHub App BYO Install Workflow

User-facing workflow for connecting a GitHub App to an Apogee organization. Each Apogee org owns their own GitHub App; the platform operator does not hold any App credentials.

## Decision: which GitHub integration do I want?

| I want to... | Use this path |
|---|---|
| Scan a **single public file** by pasting a URL | `POST /api/v1/contracts/from-github` (URL-ingest — see `contract-ingest-workflow.md`) |
| Scan a **public directory** from a URL | Same URL-ingest path |
| Scan **private repos** across my GitHub org | **GitHub App BYO (this workflow)** |
| Scan repos continuously (recurring) | **GitHub App BYO (this workflow)** — install once, sync on demand |
| Scan once and never again | URL-ingest is simpler |

## Prerequisites

- Apogee org with **admin** role (owner/admin) — integrations require admin
- **Starter tier or higher** (integrations are tier-gated)
- A GitHub user account or org with permission to install GitHub Apps on the target account. If installing on a GitHub org, you need org-admin or org-owner permissions there.

## Workflow

### Step 1 — Start the App creation from Apogee

1. Log into Apogee, navigate to **Integrations → Source Control**.
2. Click **Create GitHub App** on the GitHub card.
3. Apogee builds a manifest pre-configured with:
   - Name: `Apogee for <your org>` (editable on GitHub)
   - Permissions: Contents (read) + Metadata (read) + Pull requests (read)
   - Webhook URL: `https://app.0xapogee.com/api/v1/github-app/webhook`
   - Callback URLs: pointed back at Apogee
   - `public: false` (not discoverable on Marketplace)
4. Your browser auto-submits the manifest to `https://github.com/settings/apps/new?state=...`

### Step 2 — Create the App on GitHub

1. GitHub shows the "Create GitHub App" page **pre-filled** from Apogee's manifest.
2. Optionally rename the App. Do NOT change the callback URL / permissions / webhook URL — those are set for Apogee to work correctly.
3. **Choose where to register it:**
   - **Personal account** (URL is `github.com/settings/apps/new`) — suitable for individual developers
   - **Organization** (URL is `github.com/organizations/<org>/settings/apps/new`) — recommended for teams; org owner/admin needed
4. Click **Create GitHub App**.
5. GitHub generates the App, private key, and webhook secret, then redirects you back to Apogee's manifest-callback endpoint.

At this point: App exists but is not yet installed on any repos.

### Step 3 — Install the App on repos

1. Apogee now shows **Install on GitHub** on the GitHub card (replacing the Create button).
2. Click **Install on GitHub**.
3. GitHub shows the install page for your newly-created App.
4. **Pick which repos to install on:**
   - **All repositories** — App can access every repo in the account
   - **Only select repositories** — pick specific repos (recommended for most setups)
5. Click **Install**.

### Step 4 — Back in Apogee

1. Apogee shows a green **Connected** banner (single toast — exactly one).
2. The GitHub card now shows:
   - Your GitHub account name + avatar
   - Number of connected repos
   - **Manage Repositories** button

### Step 5 — Import your installed repositories

1. Click **Manage Repositories**. A modal lists the repos already imported (empty on first open).
2. Click **Import from GitHub**. Apogee calls `/integrations/github-app/{integration_id}/import-installed-repos`, which lists the repos your App installation has access to on GitHub and upserts them as `IntegrationRepository` rows.
3. Close the modal — the **Connected repositories** section on the card now shows the imported repos, each with `sync_status=pending`.

Re-running Import is idempotent. Whenever you add/remove repos via GitHub's *Configure* page for the App, come back and click Import again to pull the updated selection into Apogee.

### Step 6 — Sync a repository into Apogee

1. On the wizard card's inline `Connected repositories` list, click **Sync now** on the repo you want to import.
2. The row flips to *Syncing* and the dashboard polls every 3 seconds while any repo is syncing, so you see progress without refreshing.
3. Behind the scenes a Celery task authenticates with your App's installation token, walks the repo tree at the default branch's head commit, and upserts a `ContractModel` row for every `.sol` file under the 1 MB / 100 files / 50 MB budget.
4. When the task finishes, the row shows *Synced* with `contracts_found=<n>`. The new contracts appear on the **Contracts** page, each tagged with a small GitHub badge showing `<owner>/<repo>`. Click the badge to jump to the exact blob on GitHub at the imported commit; click the contract to see the full **Source** panel on the detail view (repository, short-SHA commit link, file path).
5. Re-clicking **Sync now** at the same commit is a no-op (dedupe on `(org_id, repo_url, file_path)`). After a new commit lands, the next sync updates the contract in place — it does not create duplicates.

**Known behavior today:** sync imports contracts but does *not* enqueue scans. Pick contracts manually on the Contracts page and click Scan. Auto-scan-on-sync and push/PR-triggered scans are separate follow-up passes (see the feature-test doc's *Deferred* section).

## Post-install behaviour

- Apogee stores your App's private key and webhook secret **encrypted at rest** (Fernet) in the `integration_credentials` table. The raw values are never logged or exported.
- When you trigger a scan on a repo, Apogee signs a short-lived RS256 JWT with your App's private key, exchanges it for a 1-hour installation token, and uses that token to call `api.github.com`.
- Webhooks hit Apogee's `/github-app/webhook` endpoint. The receiver is currently a 204 stub — push/PR auto-scan is a deferred feature (follow-up pass).

## Known limitations

- **Sync does not auto-scan.** Contracts are imported with `status='uploaded'`; you pick which ones to scan from the Contracts page. Auto-scan-on-sync is a narrow follow-up.
- **Sync does not react to GitHub pushes.** The webhook receiver is still a 204 stub — push/PR events don't auto-trigger sync yet. Click **Sync now** to pull the latest commit.
- **Multi-file projects (Foundry/Hardhat) ingest as individual `.sol` files.** Project-level scanning through `ContractFileModel` will follow in a later pass.
- **GitHub App disconnect does not delete the App on GitHub.** The App stays on your GitHub account under *Settings → Developer settings → GitHub Apps*. Because GitHub App names are globally unique, if you disconnect and then re-create the Apogee integration with the same default name you'll hit "name already taken" — either rename the App on GitHub's create page (second try), or delete the old App on GitHub first (*App settings → Advanced → Delete GitHub App*).

## Reconfiguring

If you need to change which repos the App covers:

1. Go to GitHub → **Settings → Applications → Installed GitHub Apps → your Apogee App → Configure**
2. Add/remove repos, click **Save**
3. GitHub redirects back to Apogee's `/github-app/setup` with `setup_action=update`. Apogee records the change silently.

## Uninstalling

1. Go to GitHub → **Settings → Applications → Installed GitHub Apps → your Apogee App → Uninstall**
2. Or delete the integration from Apogee (Integrations → Source Control → the GitHub row → Disconnect)
3. Either action stops data flow; both should be run together to fully clean up.

## Troubleshooting

See `docs/playbooks/github-app-byo-troubleshooting.md` for:
- "Create GitHub App" button doesn't redirect
- Redirected to GitHub but see "state invalid" on return
- Install succeeded in GitHub but Apogee still shows "Install"
- Installation token 401 errors
- Webhook delivery not reaching Apogee

## Related

- URL-based GitHub ingest: `docs/feature-tests/93-github-url-ingest-and-tier-limits-2026-04.md`
- Pipeline internals: `docs/pipelines/github-app-byo-manifest-pipeline.md`
- Contract ingest overview: `docs/workflows/contract-ingest-workflow.md`
