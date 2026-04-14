# GitHub URL Ingest Pipeline

Fetches public-repo contract source from a GitHub URL and persists a contract record. Implemented in api-service 0.37.x via `POST /api/v1/contracts/from-github`.

## Overview

```
Client (dashboard / CLI / curl)
    │
    │ POST /api/v1/contracts/from-github
    │ { "name": "MyToken", "github_url": "https://github.com/owner/repo/blob/main/Token.sol" }
    ▼
api-service (0.37.x)
    ├─ 1. Parse + validate URL          (src/infrastructure/github/url_parser.py)
    ├─ 2. Resolve commit SHA            (api.github.com /repos/.../commits/{branch})
    ├─ 3. Fetch content                 (raw.githubusercontent.com OR Contents API for trees)
    ├─ 4. Validate content              (binary check, null bytes, UTF-8)
    ├─ 5. Apply tier safety limits      (file count + LoC)
    ├─ 6. Detect language               (LanguageDetector — extension + content patterns)
    └─ 7. Persist contract              (ContractModel + ContractFileModel rows for trees)
            │
            ▼
    PostgreSQL: contracts, contract_files
            │
            ▼
    Returns ContractResponse with source_repo_url, source_commit_hash, source_file_path populated
```

## Service

| Property | Value |
|----------|-------|
| Repository | `blocksecops-api-service` |
| Version | 0.37.2 (introduced) |
| Endpoint | `POST /api/v1/contracts/from-github` |
| Auth | Bearer JWT or `X-API-Key` (scope: `contracts:write`) |
| Rate limit | Same as `contractCreate` operation tier limit |

## Request

```json
{
  "name": "<contract or project name>",
  "github_url": "<public GitHub URL>"
}
```

| Field | Type | Constraints |
|-------|------|-------------|
| `name` | string | 1–255 chars, sanitized via `sanitize_user_text` (BSO-SEC-INPUT-001) |
| `github_url` | string | 1–2000 chars, must parse as a supported GitHub URL form |

## Supported URL Forms

| Pattern | Example | Result |
|---------|---------|--------|
| Blob (file) | `https://github.com/{owner}/{repo}/blob/{branch}/{path}` | Single-file contract |
| Tree (dir) | `https://github.com/{owner}/{repo}/tree/{branch}/{path}` | Multi-file project (recursive) |

The parser strips a trailing `.git` from the repo name automatically. Branch names with slashes (e.g., `feature/foo`) are supported when slashes are URL-encoded as `%2F`.

## Rejected URL Forms

`POST /from-github` returns `400 invalid_github_url` for:

- Whole-repo URLs (`/owner/repo` with no kind segment) — ambiguous source dir
- URL kinds other than blob/tree (`/issues`, `/pulls`, `/releases`, etc.)
- Gist URLs — different host (`gist.github.com`), different content model
- SSH URLs (`ssh://git@github.com/...`)
- Non-github.com hosts (returns explanation pointing at the OAuth integration for private repos)
- Path-traversal attempts (`../`)
- Owners containing characters outside `[a-zA-Z0-9-]`
- Repos containing characters outside `[a-zA-Z0-9._-]`

## Fetch Flow

### Blob URL (single file)

1. **Resolve commit SHA** — `GET https://api.github.com/repos/{owner}/{repo}/commits/{branch}` returns the branch's HEAD SHA
2. **Fetch raw** — `GET https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}` returns the file content
3. **Validate** — Reject if not valid UTF-8, contains null bytes, or exceeds 1 MB per-file cap

### Tree URL (multi-file directory)

1. **Resolve commit SHA** — same as blob
2. **Walk tree recursively** via Contents API:
   - `GET https://api.github.com/repos/{owner}/{repo}/contents/{path}?ref={branch}`
   - Returns directory entries with `name`, `type`, `size`, `download_url`
   - For each `dir` entry: recurse (max depth 10)
   - For each `file` entry: fetch via `download_url` (which is a `raw.githubusercontent.com` URL)
3. **Filter** to:
   - Contract source: `*.sol`, `*.rs`, `*.vy`
   - Framework configs: `Anchor.toml`, `Cargo.toml`, `Cargo.lock`, `Xargo.toml`, `foundry.toml`, `remappings.txt`, `hardhat.config.{js,ts}`, `moccasin.toml`, `package.json`
4. **Early size guard** — sums `size` from listings before downloading content; aborts with `413` if cumulative exceeds operational cap

## Error Mapping

| GitHub upstream | Returned by `/from-github` | Notes |
|-----------------|---------------------------|-------|
| 200 | 201 created | Normal path |
| 404 | 404 `github_not_found` | Repo, branch, or path missing |
| 403 (rate-limit hit) | 429 `github_rate_limited` | `x-ratelimit-remaining: 0` |
| 403 (other) | 403 `github_access_denied` | Likely private repo |
| 451 | 403 `github_access_denied` | DMCA / legal block |
| Network timeout | 502 `github_fetch_failed` | Upstream unavailable |
| Content > 1 MB | 413 `github_content_too_large` | Per-file cap |
| Tree > tier safety budget | 413 `github_content_too_large` | Operational cap |
| URL parse failure | 400 `invalid_github_url` | Malformed URL or unsupported form |

## Persistence

For every successful ingest, three columns on `contracts` are populated (previously NULL for non-OAuth contracts):

| Column | Value |
|--------|-------|
| `source_repo_url` | The full GitHub URL the user provided |
| `source_commit_hash` | The branch HEAD SHA at ingest time |
| `source_file_path` | The repo-relative path (file path for blob, directory path for tree) |

For tree (multi-file) ingests, each fetched file is persisted as a `ContractFileModel` row with `is_main_file=true` for the chosen entry point (`lib.rs` for Anchor, alphabetic-first otherwise).

## Tier Safety

The fetcher passes a generous file-count cap (2,000) to itself, but the resulting in-memory file list is then handed to the same `extract_with_smart_dependencies` and tier-limit checks used by `/upload`. Operational safety limits (per `TIER_SAFETY_LIMITS` in upload.py) apply uniformly:

| Tier | Max files | Max LoC |
|------|-----------|---------|
| developer | 50 | 10K |
| starter | 200 | 50K |
| growth | 500 | 100K |
| enterprise | 1,500 | 300K |

A tree URL ingest that exceeds these limits fails with `413` and the same operational-safety-limit error message as a tarball upload.

## No Caching

Fetched content is **not cached server-side**. Re-running a scan against the same GitHub URL re-fetches the content. Trade-offs:

- Pro: zero unbounded storage growth from this feature
- Pro: scans always reflect current branch state at time of scan
- Con: GitHub anonymous rate limit (60 req/hr per source IP) becomes a constraint at high volume

A future iteration may add ETag/If-Modified-Since support to skip re-downloading unchanged content without storing copies.

## Auth: Public Repos Only — by design

This pipeline does **not** present credentials to GitHub. It is intentionally a low-friction path for public-repo ingest. Private repos return `github_access_denied` with a message pointing the user at the OAuth integration.

**For private repos AND for higher rate limits, use the GitHub OAuth integration:**

```
# Org admin: create the integration with the user's GitHub Personal Access Token
POST /api/v1/organizations/{org_id}/integrations
  body: { "provider": "github", "credentials": { "personal_access_token": "ghp_..." } }

# Connect a repository
POST /api/v1/organizations/{org_id}/integrations/{integration_id}/repositories/connect
  body: { "repo_url": "https://github.com/myorg/myrepo" }

# Sync (creates a contract record)
POST /api/v1/organizations/{org_id}/integrations/{integration_id}/repositories/{repo_id}/sync
```

That path uses the stored PAT and supports private repos with GitHub's authenticated 5,000-req/hr rate limit (vs. 60-req/hr anonymous on this pipeline).

## Related

- `docs/pipelines/contract-upload-pipeline.md` — sibling pipeline (paste, archive)
- `docs/workflows/contract-ingest-workflow.md` — comparison of all four ingest user flows
- `docs/playbooks/github-url-ingest-troubleshooting.md` — common errors and fixes
- `docs/audit/2026-04-14-scanner-e2e-test-matrix.md` — verification audit
- `docs/feature-tests/93-github-url-ingest-and-tier-limits-2026-04.md` — feature acceptance test
