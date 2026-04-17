# GitHub URL Ingest + Tier Safety Limit Increases — April 2026

**Date:** 2026-04-14
**Versions:**
- api-service 0.36.2 → **0.37.2**
- No scanner image changes
- No tier-config (`tiers.json`) changes

**Repos modified:** `blocksecops-api-service`

---

## Overview

Two related platform changes that ship together:

1. **GitHub URL ingest** — New `POST /api/v1/contracts/from-github` endpoint accepts a public GitHub blob (single-file) or tree (multi-file directory) URL and creates a contract record by fetching the source directly. Closes the gap between the existing four ingest paths (paste, archive, address, OAuth-linked repo sync).

2. **Tier safety limit increases** — `TIER_HARD_LIMITS` in `upload.py` was undersized for real-world audit codebases. Aave V3 (253 files / 28K LoC) didn't fit in growth tier; OpenZeppelin (~200 files / ~20K LoC) didn't fit in starter; mono-repos didn't fit in enterprise. Bumped + renamed to `TIER_SAFETY_LIMITS` to clarify these are operational caps (resource-exhaustion safety net), not user-facing tier quotas.

---

## Tier Safety Limit Changes

### Before / after

| Tier | Price | Old `TIER_HARD_LIMITS` | New `TIER_SAFETY_LIMITS` |
|------|-------|----------------------|--------------------------|
| developer | $0 | 50 files / 10K LoC | unchanged (free tier safety net) |
| starter | $199 | 100 files / 25K LoC | **200 files / 50K LoC** |
| growth | $499 | 250 files / 50K LoC | **500 files / 100K LoC** |
| enterprise | $1,499 | 500 files / 100K LoC | **1,500 files / 300K LoC** |

### Why this matters

`tiers.json` advertises `maxFilesPerScan: -1` and `maxLocPerScan: -1` (unlimited) for every paying tier. The marketing/UI source of truth promises "unlimited". But the upload endpoint enforced hard limits regardless of what tier said. A customer paying $1,499/mo for "unlimited" would be rejected at 101K LoC.

Resolution:
- `tiers.json` stays as-is — "unlimited" is the brand promise; we keep it
- `TIER_HARD_LIMITS` renamed to `TIER_SAFETY_LIMITS` with a comment clarifying intent
- New limits sized against real DeFi codebases:
  - Compound Comet: 112 files / 13K LoC
  - Aave V3: 253 files / 29K LoC
  - Seaport: 71 files / 19K LoC
- Error message changed from "exceeds {tier} tier limit" → "exceeds operational safety limit for {tier} tier — for larger codebases, contact support"

---

## GitHub URL Ingest

### New endpoint

`POST /api/v1/contracts/from-github`

```bash
curl -X POST https://app.0xapogee.com/api/v1/contracts/from-github \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "OZ-ERC20",
    "github_url": "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol"
  }'
```

### Supported URL forms

| Form | Pattern | Result |
|------|---------|--------|
| Blob | `https://github.com/{owner}/{repo}/blob/{branch}/{path}` | Single-file contract |
| Tree | `https://github.com/{owner}/{repo}/tree/{branch}/{path}` | Multi-file project (recursive within path) |

`.git` suffix on repo name is stripped automatically. Branch names with slashes (e.g., `feature/foo`) are supported by URL-encoding the slash as `%2F`.

### Rejected URL forms

- Whole-repo URLs (`/owner/repo`) — ambiguous source dir
- Other GitHub URL kinds (`/issues`, `/pulls`, `/releases`)
- Gist URLs — different host, different content model
- SSH URLs (`ssh://git@github.com/...`)
- Non-github.com hosts
- Path-traversal attempts (`../`)

### Auth model

Public repos only. No OAuth required — uses `raw.githubusercontent.com` for blob fetches and the public `api.github.com` Contents API for tree enumeration. For private repos, use the existing OAuth-linked GitHub integration (`/api/v1/organizations/.../integrations/github/.../sync`).

### Provenance metadata

For every GitHub-ingested contract, three fields persist that were previously NULL:

- `source_repo_url` — full GitHub URL the user provided
- `source_commit_hash` — branch HEAD SHA at fetch time (resolved via Commits API)
- `source_file_path` — repo-relative path

This provides cryptographic provenance — anyone can independently verify which exact code was scanned by checking the repo at that commit.

### Caching policy

**No caching** of fetched content. Re-fetch on every scan. Avoids unbounded storage growth (the only realistic long-term cost vector). GitHub raw content is fast (<1s typically).

### Tier safety integration

The from-github path reuses the same `extract_with_smart_dependencies` and tier-limit checks as `/upload`. Uploading a 2,000-file repo via tree URL fails the same way as uploading a 2,000-file tarball, with the same operational-safety-limit error message.

The fetcher also enforces an early size check via the Contents API before downloading any blob content. If the cumulative size of a tree would exceed the operational safety budget, fetching aborts before touching the data.

### File types fetched

For tree URLs, the fetcher walks recursively and grabs:

- Contract source: `.sol`, `.rs`, `.vy`
- Framework configs: `Anchor.toml`, `Cargo.toml`, `Cargo.lock`, `Xargo.toml`, `foundry.toml`, `remappings.txt`, `hardhat.config.{js,ts}`, `moccasin.toml`, `package.json`

Build artifacts, tests, scripts, docs, and binaries are skipped server-side (the archive extractor would skip them anyway).

---

## E2E Verification

See `docs/audit/2026-04-14-scanner-e2e-test-matrix.md` for the full matrix.

**Summary:** 30 of 32 applicable scans completed across all 16 API-exposed scanners. The 2 failures are documented known issues (vyper single-file ingest doesn't preserve `.vy` extension; one transient trident project shape failure that succeeded in the online variant).

**Real vulnerabilities detected:**

| Scanner | Input | Critical | High | Medium | Low |
|---------|-------|----------|------|--------|-----|
| slither | VulnerableToken.sol (paste) | 1 | 2 | 3 | 3 |
| aderyn | VulnerableToken.sol | 6 | 0 | 8 | 0 |
| solhint | OZ ERC20 (online) | 0 | 32 | 0 | 0 |
| rustdefend | vulnerable_vault.rs | 5 | 4 | 4 | 0 |
| rustdefend | escrow.rs (online) | 0 | 6 | 0 | 0 |
| sec3-xray | coral-xyz/anchor escrow (online) | 0 | 6 | 0 | 2 |

---

## Files Modified

| File | Change |
|------|--------|
| `src/presentation/api/v1/endpoints/upload.py` | `TIER_HARD_LIMITS` → `TIER_SAFETY_LIMITS` (renamed, bumped, error msg reworded) |
| `src/infrastructure/github/__init__.py` | NEW |
| `src/infrastructure/github/url_parser.py` | NEW — `parse_github_url`, `GitHubLocation` |
| `src/application/services/github_fetcher_service.py` | NEW — `GitHubFetcher`, `FileEntry`, error hierarchy |
| `src/presentation/schemas/contracts.py` | Added `ContractFromGitHubCreate` |
| `src/presentation/api/v1/endpoints/contracts.py` | Added `POST /from-github` endpoint |
| `tests/unit/infrastructure/test_github_url_parser.py` | NEW — 25 test cases (positive + negative) |
| `tests/unit/services/test_github_fetcher.py` | NEW — 13 test cases (httpx MockTransport) |
| `pyproject.toml` | 0.36.2 → 0.37.2 |
| `k8s/overlays/gcp/kustomization.yaml` | newTag bump |

**Net test count:** 80 unit tests pass (42 existing + 38 new).

---

## Known Limitations / Follow-ups

> **Update 2026-04-15:** Items 1, 2, 4 below were addressed in api-service 0.37.3 + tool-integration 0.5.43. Item 3 confirmed as by design. See [`docs/audit/2026-04-15-known-issue-fixes-verification.md`](../audit/2026-04-15-known-issue-fixes-verification.md).

1. ~~**Single-file Vyper from-github**~~ — **FIXED in 0.37.3 + 0.5.43.** api-service now sends authoritative `language` field in trigger payload; tool-integration's `detect_extension` also recognizes `#pragma version` Vyper syntax as a defensive fallback.

2. ~~**`framework` field is None** for contracts ingested via `/from-github`~~ — **FIXED in 0.37.3.** `create_contract_from_github` now runs `FrameworkDetector.detect_from_contents()` on the fetched file list before persisting. Verified: `framework=anchor` correctly populated for coral-xyz/anchor escrow tree.

3. **GitHub anonymous rate limit (60/hr)** — **By design.** Users wanting higher limits or private repos use the existing GitHub OAuth integration with their PAT (5,000/hr authenticated). Error message and `docs/playbooks/github-url-ingest-troubleshooting.md` Issue 4 updated to direct users to the OAuth flow.

4. ~~**Mythril missing from `/scanners`**~~ — **FIXED in 0.37.3.** Mythril registered in `SCANNERS` dict and added to the Solidity "deep" scan preset. `GET /api/v1/scanners` now returns 17 scanners (was 16).

### New follow-up identified during fix verification

- **Trident on flat-tarball Anchor projects** — pre-existing trident-scan wrapper bug (path-reconstruction loop only handles top-level `*.rs` files, not nested ones). Affects projects uploaded via `/upload` as a single archive but not those ingested via `/from-github` (which preserves directory structure as ContractFileModel rows). Tracked separately.

---

## Update 2026-04-16: Dashboard wiring + hook test

The api-service endpoint shipped in 0.37.2/0.37.3 but the dashboard side was never wired, so customer-facing ingest via GitHub URL was unreachable through the UI. Closed in this pass:

- `blocksecops-dashboard/src/lib/api/contracts.ts` — added `createContractFromGitHub()` client method, `ContractFromGitHubRequest` type, and `isGitHubIngestError()` type guard. The guard unpacks the server's `{error, message}` detail so components can surface the rate-limit/PAT hint verbatim per the 0.37.3 wording fix.
- `blocksecops-dashboard/src/hooks/useGitHubIngest.ts` — new `useCreateFromGithub` React Query mutation. On success it invalidates the `['contracts']` query so ContractsList picks up the new contract without a manual refresh.
- `blocksecops-dashboard/tests/hooks/useGitHubIngest.test.ts` — locks down three response branches: 201 success, 400 `invalid_github_url`, and 429 `github_rate_limited` with the exact "GitHub PAT via the integrations endpoint" wording. 4 test cases, all pass.

**Still out-of-scope:** wiring the hook into `ContractUploadModal.tsx` as a third ingest tab. The hook is callable from any component; the modal UI surface remains single-file-paste + archive-upload + address until a customer asks for it.

---

## Update 2026-04-16 (part 2): Modal UI wiring + smoke test

The hook shipped earlier in the day was still not reachable from the customer UI. This pass closes that gap and adds end-to-end smoke coverage.

- `blocksecops-dashboard/src/components/contracts/ContractUploadModal.tsx` — added a three-tab input-mode selector at the top of the Source section: **Paste Code** / **Upload File** / **GitHub URL**. Only the active tab's input renders; switching tabs clears cross-mode state and validation errors so the user can't accidentally submit stale data.
- **Client-side URL validation** — strict regex anchored to `https://github.com/{owner}/{repo}/(blob|tree)/{branch}/{path}`. Rejects non-GitHub hosts, missing blob/tree segment, and empty input before any network call.
- **Server error rendering** — the API's structured `detail.message` renders verbatim in a red banner (rate-limit PAT hint, invalid URL, private repo redirect, content-too-large). React auto-escapes, no `dangerouslySetInnerHTML`, no XSS risk.
- **409 conflict reuse** — contract-name-exists from `/from-github` routes into the same `DuplicateContractModal` rename/overwrite flow that the paste and upload paths already use.
- **Submit button label** switches to "Import from GitHub" in GitHub mode so the action is unambiguous.
- `blocksecops-dashboard/tests/components/ContractUploadModal.github.test.tsx` — 8 component-level tests covering tab rendering, tab switching, empty-URL rejection, non-GitHub URL rejection, missing blob/tree path rejection, successful submission via `createContractFromGitHub`, rate-limit error rendering (asserts the exact 0.37.3 "GitHub PAT via the integrations endpoint" wording appears in the DOM).
- `docs/standards/smoke-test.md` — added a "GitHub URL Ingest" block under Authenticated Endpoint Tests: happy-path curl against `/api/v1/contracts/from-github`, invalid-URL 400 check, and a manual browser-side checklist for the modal's three-tab flow. The quick full smoke script now also exits non-zero if the invalid-URL path doesn't return 400.

**Dashboard PR:** AdvancedBlockchainSecurity/blocksecops-dashboard#211 (merged 2026-04-16).
