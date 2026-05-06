# Contract Ingest Workflow

User-facing workflow comparing the five ways to get a contract into the BlockSecOps platform for scanning.

## The Five Ingest Paths

| Path | Endpoint | When to use |
|------|----------|-------------|
| **Source paste** | `POST /api/v1/contracts` (with `source_code`) | Quick scan of a single file you have locally; when GitHub is unreachable from your network |
| **Archive upload** | `POST /api/v1/upload` (multipart `file=`) | Multi-file project you already have packaged (zip/tar.gz); Hardhat/Foundry/Anchor projects with `node_modules` or `lib/` excluded |
| **GitHub URL** | `POST /api/v1/contracts/from-github` | Public GitHub blob or tree URL; provenance auto-tracked (commit SHA stored) |
| **GitHub App (BYO manifest)** | `/api/v1/github-app/*` + `/organizations/.../github-app/*` | Private repos; recurring syncs; per-repo permissions. Each org registers their own GitHub App via GitHub's manifest flow. See `github-app-byo-install-workflow.md`. |
| **OAuth GitHub sync** (legacy) | `POST /api/v1/organizations/.../integrations/.../sync` | Pre-existing OAuth-based integrations. For new GitHub integrations, prefer the GitHub App BYO path above. |

## Decision Flow

```
Got a contract to scan?
│
├─ Is it a single file you can paste?
│    ├─ Yes → POST /api/v1/contracts with source_code
│    └─ No → continue
│
├─ Is it a public GitHub URL?
│    ├─ Single file (blob URL) → POST /api/v1/contracts/from-github
│    ├─ Directory (tree URL) → POST /api/v1/contracts/from-github
│    └─ Whole repo / private → continue
│
├─ Is it private GitHub or recurring?
│    └─ Yes → GitHub App BYO (register your own App via manifest flow)
│             See docs/workflows/github-app-byo-install-workflow.md
│
└─ Have a tarball / zip locally?
     └─ POST /api/v1/upload
```

## Detailed Walkthroughs

### 1. Source paste (single file)

Use when you have a small contract on your laptop and want to scan it without any setup.

```bash
curl -X POST https://app.0xapogee.com/api/v1/contracts \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "MyToken",
    "language": "solidity",
    "source_code": "pragma solidity ^0.8.0; contract MyToken { ... }"
  }'
```

**Returns:** A contract record. Trigger a scan with `POST /api/v1/scans`.

**Limits:** 10 MB per source_code field (enforced by request middleware).

### 2. Archive upload (multi-file project)

Use when your project has multiple files, dependencies (lib/, node_modules/), or framework config (foundry.toml, hardhat.config.js, Anchor.toml).

```bash
tar -czf myproject.tar.gz \
  --exclude=node_modules --exclude=lib/forge-std/test \
  myproject/

curl -X POST https://app.0xapogee.com/api/v1/upload \
  -H "X-API-Key: $API_KEY" \
  -F "file=@myproject.tar.gz"
```

**Returns:** A contract record with `is_project=true`, `framework` detected (anchor/foundry/hardhat/plain), `main_file_path`.

**Limits (operational safety):**
- developer: 50 files / 10K LoC
- starter: 200 files / 50K LoC
- growth: 500 files / 100K LoC
- enterprise: 1,500 files / 300K LoC

### 3. GitHub URL (public repo)

Use when the code is on a public GitHub repo and you want provenance metadata persisted automatically.

**Single file:**
```bash
curl -X POST https://app.0xapogee.com/api/v1/contracts/from-github \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "OZ-ERC20",
    "github_url": "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol"
  }'
```

**Multi-file directory:**
```bash
curl -X POST https://app.0xapogee.com/api/v1/contracts/from-github \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Uniswap-V3-Core",
    "github_url": "https://github.com/Uniswap/v3-core/tree/main/contracts"
  }'
```

**Returns:** A contract record with `source_repo_url`, `source_commit_hash` (the resolved SHA at fetch time), `source_file_path` populated.

**Provenance benefit:** Anyone can independently verify which exact code was scanned by checking the repo at that commit.

**Single-file blob constraint** (api-service 0.43.6+, audit follow-up F6 — 2026-05-06): blob URLs must point to a self-contained file. If the source contains relative imports (`./X.sol`, `../X.sol`, `./X.vy`, `../X.vy`), the upload is rejected with HTTP 400 `blob_has_relative_imports` and a message pointing to the correct ingest path:

- Use the **tree URL of the parent directory** instead: `https://github.com/<owner>/<repo>/tree/<branch>/<dir>`
- Or upload an **archive** containing the file and its siblings: `POST /api/v1/upload`

Absolute imports (`@openzeppelin/contracts/...`, `@uniswap/...`) are unaffected — the validation only rejects path-relative imports the blob path cannot resolve.

**Limits:** Same operational safety caps as archive upload (re-fetched per scan, not cached).

### 4. OAuth GitHub sync (private repos)

Use when the repo is private and your organization has linked GitHub via OAuth.

```bash
# Step 1: Link the integration (one-time, per org)
curl -X POST https://app.0xapogee.com/api/v1/organizations/$ORG_ID/integrations \
  -H "X-API-Key: $ADMIN_API_KEY" \
  -d '{ "provider": "github", ... }'

# Step 2: Connect a repo
curl -X POST https://app.0xapogee.com/api/v1/organizations/$ORG_ID/integrations/$INT_ID/repositories/connect \
  -H "X-API-Key: $ADMIN_API_KEY" \
  -d '{ "repo_url": "https://github.com/myorg/private-repo" }'

# Step 3: Sync (creates a contract record)
curl -X POST https://app.0xapogee.com/api/v1/organizations/$ORG_ID/integrations/$INT_ID/repositories/$REPO_ID/sync \
  -H "X-API-Key: $ADMIN_API_KEY"
```

## Tradeoffs Summary

| Concern | Source paste | Archive | GitHub URL | OAuth sync |
|---------|--------------|---------|-----------|-----------|
| Single file | Yes | Yes (1-file archive) | Yes (blob URL) | Yes |
| Multi-file project | No | Yes | Yes (tree URL) | Yes |
| Provenance metadata | No | No | Yes (commit SHA) | Yes |
| Private repos | Yes | Yes | No | Yes |
| OAuth setup required | No | No | No | Yes |
| Re-scan picks up new commits | Manual re-paste | Manual re-upload | Manual re-ingest | Automatic on sync |

## Common Pitfalls

- **Whole-repo URL** (`https://github.com/owner/repo`) is rejected by `/from-github`. Use a blob or tree URL pointing at a specific file or directory.
- **GitHub anonymous rate limit** (60 req/hr per source IP) applies to `/from-github`. For higher volume, use OAuth sync.
- **Vyper single-file via `/from-github`** has a known issue where the `.vy` extension isn't preserved in the mounted file path; the Vyper scanner won't find files. Workaround: paste source via `/api/v1/contracts` or upload as a project archive. Tracked as a follow-up patch.
- **Tier safety limits** apply uniformly across `/upload` and `/from-github`. Exceeding them returns `413` with a "for larger codebases, contact support" hint — these are operational caps, not user-tier upgrade nags.

## Related

- `docs/pipelines/contract-upload-pipeline.md`
- `docs/pipelines/github-url-ingest-pipeline.md`
- `docs/playbooks/github-url-ingest-troubleshooting.md`
