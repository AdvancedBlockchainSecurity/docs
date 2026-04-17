# GitHub URL Ingest Troubleshooting

Common errors from `POST /api/v1/contracts/from-github` and how to fix them.

> **Different flow?** If the customer's error involves installing a GitHub App, per-repo permissions, OAuth-linked integrations, or recurring sync (not a one-shot URL fetch), route to [`github-app-byo-troubleshooting.md`](./github-app-byo-troubleshooting.md) instead. This playbook only covers the public-URL-based single-shot ingest.

## UI entry point (dashboard)

As of 2026-04-16, customers reach this endpoint via the **GitHub URL** tab in `ContractUploadModal` (Contracts page → **Upload Contract** button → **GitHub URL** tab). The UI validates the URL shape client-side before submitting and renders the server's `detail.message` verbatim on error — so the guidance below (rate-limit hint, private-repo redirect, etc.) surfaces directly to the end user with no translation. If a customer reports an ingest error, ask them to copy the exact red-banner text; that's the server message string, not a paraphrase.

## Quick Reference: Error Codes

| HTTP | `error` field | Common cause |
|------|--------------|--------------|
| 400 | `invalid_github_url` | Malformed URL, unsupported form, path traversal attempt |
| 403 | `github_access_denied` | Private repo, DMCA block, or non-rate-limit 403 |
| 404 | `github_not_found` | Repo, branch, or path doesn't exist |
| 409 | `contract_name_exists` | A contract with the same name already exists for this user |
| 413 | `github_content_too_large` | File >1 MB, or tree exceeds tier safety limit |
| 429 | `github_rate_limited` | GitHub anonymous API rate limit (60/hr per IP) hit |
| 502 | `github_fetch_failed` | Network/timeout/upstream issue |

## Issue 1: "invalid_github_url" — what URL forms are supported?

**Supported:**
```
https://github.com/{owner}/{repo}/blob/{branch}/{path/to/file.sol}
https://github.com/{owner}/{repo}/tree/{branch}/{path/to/dir}
```

**Common rejections:**

| You sent | Why rejected | Use instead |
|----------|-------------|-------------|
| `https://github.com/foo/bar` | Whole-repo URL — ambiguous source dir | `https://github.com/foo/bar/tree/main/contracts` |
| `https://github.com/foo/bar/issues/1` | Not a blob/tree URL | Find the actual file path |
| `https://gist.github.com/foo/abc` | Different host | Source paste via `/api/v1/contracts` |
| `ssh://git@github.com/foo/bar.git` | Non-HTTPS scheme | Convert to HTTPS |
| `https://github.com/foo/bar/blob/main/../etc/passwd` | Path traversal | Don't do that |

**Branch with slashes** (e.g., `feature/foo`):
URL-encode the slash: `https://github.com/foo/bar/blob/feature%2Ffoo/file.sol`

## Issue 2: "github_not_found" but the file exists in my browser

Most common cause: case mismatch.

GitHub's URL routing is case-insensitive in the browser but `raw.githubusercontent.com` is **case-sensitive**. `Token.sol` and `token.sol` are different files at the raw API.

Diagnostic:
```bash
# Try the raw URL directly to confirm
curl -I https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}
# Should return HTTP/2 200; if 404, the case is wrong somewhere
```

Other causes:
- The branch was renamed/deleted
- The file moved or was deleted
- You used `master` but the default is `main` (or vice versa)

## Issue 3: "github_access_denied" — was it private?

Private repos return 403 from GitHub. `/from-github` translates this to `github_access_denied`.

For private repos, use the OAuth-linked GitHub integration:
```bash
POST /api/v1/organizations/{org_id}/integrations/{integration_id}/repositories/{repo_id}/sync
```

That path uses your stored OAuth token and supports private repos.

If the repo is **public** but you're still seeing this, check:
- DMCA-blocked repo (returns 451 → mapped to 403 in our error)
- Org-level Marketplace restrictions

## Issue 4: "github_rate_limited" — 60 req/hr is tight (use OAuth integration)

`/from-github` uses unauthenticated GitHub API (60 req/hour per source IP for the Contents/Commits API). Tree URLs make multiple requests per ingest (one per directory + one per file).

**This is by design.** `/from-github` is a low-friction public-repo path. For higher rate limits or private repos, use the existing GitHub OAuth integration with your Personal Access Token. Authenticated GitHub API allows 5,000 req/hr.

**Steps to switch to the OAuth integration:**

```bash
# 1. (Org admins) Create the GitHub integration for your org
curl -X POST https://app.0xapogee.com/api/v1/organizations/$ORG_ID/integrations \
  -H "X-API-Key: $ADMIN_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "provider": "github",
    "credentials": { "personal_access_token": "ghp_..." }
  }'

# 2. Connect the repository
curl -X POST https://app.0xapogee.com/api/v1/organizations/$ORG_ID/integrations/$INT_ID/repositories/connect \
  -H "X-API-Key: $ADMIN_API_KEY" \
  -d '{ "repo_url": "https://github.com/myorg/myrepo" }'

# 3. Sync (creates a contract record)
curl -X POST https://app.0xapogee.com/api/v1/organizations/$ORG_ID/integrations/$INT_ID/repositories/$REPO_ID/sync \
  -H "X-API-Key: $ADMIN_API_KEY"
```

Workarounds if you must stick with `/from-github`:
- Wait ~1 hour for the anonymous rate limit to reset
- Use a smaller tree URL (point at a specific subdirectory rather than the whole repo)

## Issue 5: "github_content_too_large" — what are the limits?

Two layers:

**Per-file cap:** 1 MB (hard-coded in `github_fetcher_service.py`). Files larger than this are rejected — audit-grade contracts are essentially never this large.

**Tree cumulative cap:** Operational safety limit per tier (see `docs/standards/tier-standards.md` if it exists, or `TIER_SAFETY_LIMITS` in `upload.py`):

| Tier | Max files | Max LoC |
|------|-----------|---------|
| developer | 50 | 10K |
| starter | 200 | 50K |
| growth | 500 | 100K |
| enterprise | 1,500 | 300K |

These are operational caps to prevent resource exhaustion, not user-tier upgrade nags. If you genuinely need to scan a 2,000-file mono-repo, contact support to discuss a custom plan.

To stay under the limit:
- Point the tree URL at a specific subdirectory rather than the whole `contracts/`
- Exclude tests/scripts from your scan scope (re-organize your repo if necessary, or use `/upload` with a pre-filtered tarball)

## Issue 6: "github_fetch_failed" — transient upstream error

Network timeout, GitHub partial outage, or DNS issue between the API service and GitHub.

Diagnose:
```bash
# Check from inside the api-service pod
kubectl exec -n api-service-prod deploy/api-service -- \
  curl -sI -m 5 https://api.github.com/repos/foo/bar/commits/main
```

If GitHub is reachable but `/from-github` still fails, check api-service logs:
```bash
kubectl logs -n api-service-prod deploy/api-service --tail=100 | grep -i github
```

## Issue 7: Scan succeeded but wrong main file selected

For tree URL ingests, the platform picks a main file with this heuristic:
1. If any `lib.rs` exists, prefer it (Anchor convention)
2. Otherwise, alphabetically first contract file

If the wrong main file is chosen, you can:
- Point the tree URL at a more specific subdirectory
- Use `/upload` with a tarball that includes a `manifest.json` specifying the main file
- Future: a `main_file_path` request parameter on `/from-github` (not implemented)

## Issue 8: Vyper single-file via `/from-github` returns 0 findings

Known bug. The KJM mounts the source as `/contracts/<contract_name>`, but the contract name doesn't carry the `.vy` extension. The Vyper scanner only finds `*.vy` files.

**Workaround:** Paste the source via `/api/v1/contracts` (with `language: "vyper"`), or upload as a single-file tarball.

**Fix path:** Persist the original blob filename alongside the contract record so the KJM mounts with the correct extension. Tracked as a follow-up patch.

## Issue 9: GitHub repo metadata (commit SHA) is from `master` instead of `main`

The fetcher resolves the SHA against the branch you specified in the URL. If you used `/blob/master/...` but the default branch is `main`, you'll get the SHA of `master` — which may be a stale or non-existent ref.

Always specify the actual branch in the URL. To get the default-branch SHA, use the GitHub web UI to find the canonical URL first.

## Issue 10: The `framework` field on the contract record is `None` despite uploading an Anchor project

Cosmetic only. The `framework_detector` runs only on `/upload`, not on `/from-github`. Scanners still detect framework at scan time from the actual mounted files (which include `Anchor.toml`/`Cargo.toml`/`foundry.toml` etc. — those are explicitly fetched by the tree walker).

To fix the cosmetic: a future iteration can run `FrameworkDetector.detect_from_contents()` on the fetched file list before persisting.

## Verification Commands

```bash
# Confirm the contract was created with provenance fields
kubectl exec -n postgresql-prod postgresql-0 -- psql -U postgres -d solidity_security -c "
SELECT name, language, framework, source_repo_url, LEFT(source_commit_hash, 12) as sha, source_file_path
FROM contracts
WHERE source_repo_url LIKE '%github.com%'
ORDER BY created_at DESC LIMIT 5;
"

# Check api-service logs for the most recent /from-github call
kubectl logs -n api-service-prod deploy/api-service --tail=200 | grep -i "from-github\|github_fetch"

# Check current api-service version
kubectl get deployment api-service -n api-service-prod -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## Related

- `docs/pipelines/github-url-ingest-pipeline.md`
- `docs/workflows/contract-ingest-workflow.md`
- `docs/feature-tests/93-github-url-ingest-and-tier-limits-2026-04.md`
