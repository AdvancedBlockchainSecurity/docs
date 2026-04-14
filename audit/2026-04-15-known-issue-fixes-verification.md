# Known Issue Fixes — Verification Audit (2026-04-15)

**Auditor:** Apogee Platform Team
**Account:** `jasonbrailowbizop@mail.com` (production)
**API:** `https://app.0xapogee.com/api/v1`
**Versions:** api-service `0.37.3`, tool-integration `0.5.43`

## Scope

Re-verify the four known issues identified in [`2026-04-14-scanner-e2e-test-matrix.md`](./2026-04-14-scanner-e2e-test-matrix.md). Issue #4 (private repos / higher rate limits) was deferred to the existing GitHub OAuth integration per design.

## Results Summary

| # | Issue | Status | Verification |
|---|-------|--------|--------------|
| 1 | Vyper single-file from-github fails with "No .vy files found" | **FIXED** | Re-ingested + re-scanned ERC20.vy → status=completed, no .vy error |
| 2 | Trident on local Anchor project failed | **DOWNGRADED to Known Bug** | Reproduced; root cause is in trident-scan wrapper's path-reconstruction loop. Not a regression. Tracked as follow-up. |
| 3 | `framework=None` for /from-github tree ingests | **FIXED** | Re-ingested coral-xyz/anchor escrow tree → `framework=anchor` returned and persisted |
| 4 | GitHub anonymous rate limit | **BY DESIGN** | Rate-limit error message reworded to direct users to OAuth integration with PAT |
| 5 | Mythril missing from /api/v1/scanners | **FIXED** | `/scanners` returns 17 scanners (was 16); `/scanners/mythril` returns full metadata |

---

## Detailed Verification

### Fix #1: Vyper single-file from-github

**Before (api-service 0.37.2):** Single-file Vyper ingested via `/from-github` had source content stored without filename extension preservation. KJM's source-pattern detection (`detect_extension` in tool-integration `main.py`) only recognized legacy `# @version` syntax. Modern `#pragma version` Vyper files (Vyper 0.3.10+) fell through to `.sol` default. Vyper scanner mounted the file as `contract.sol` and reported "No .vy files found in /contracts."

**After (api-service 0.37.3 + tool-integration 0.5.43):**

1. api-service now sends `language` field in the trigger payload (authoritative DB value).
2. tool-integration prefers the `language` hint when present; `detect_extension` regex also extended to recognize `#pragma version` for legacy compat.

**Test:**
```bash
curl -X POST https://app.0xapogee.com/api/v1/contracts/from-github \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "FIX1-Vyper-ERC20-from-github",
    "github_url": "https://github.com/vyperlang/vyper/blob/master/examples/tokens/ERC20.vy"
  }'
# Returns: contract_id=3258a084-..., language=vyper

# Trigger vyper scan
POST /scans { "contract_id": "3258a084-...", "scanner_ids": ["vyper"] }
# Scan ID: 829f5d33-ac61-4008-bd54-729d6ba4d3fa
```

**Result:**
```
[t+10s] queued
[t+20s] queued
[t+30s] queued
[t+40s] completed

status=completed
crit/high/med/low: 0/0/0/0
PASS: Vyper scanner ran successfully (no "No .vy files" error)
```

### Fix #3: framework detection on /from-github tree

**Before (api-service 0.37.2):** The `/from-github` endpoint did language detection on the main file but never ran framework detection. Contracts ingested this way had `framework=None` even when `Anchor.toml`/`foundry.toml`/`hardhat.config.*` were present in the fetched tree. Cosmetic only — scanners re-detected framework at runtime from mounted files.

**After (api-service 0.37.3):** `create_contract_from_github` now calls `FrameworkDetector.detect_from_contents()` on the fetched file list (passing both file paths and a content map for hardhat-via-package.json detection) before persisting.

**Test:**
```bash
curl -X POST https://app.0xapogee.com/api/v1/contracts/from-github \
  -H "X-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "FIX3-Anchor-Escrow-Framework-Test",
    "github_url": "https://github.com/coral-xyz/anchor/tree/master/tests/escrow"
  }'
```

**Result:**
```json
{
  "id": "38c52bf4-6257-4406-849d-3c85bd63309a",
  "language": "rust",
  "framework": "anchor",
  "main_file_path": "programs/escrow/src/lib.rs",
  "file_count": 6
}
```

`framework=anchor` correctly populated. Verified persisted via direct DB query.

### Fix #5: Mythril in /api/v1/scanners

**Before (api-service 0.37.2):** Mythril scanner image is registered in tool-integration's KJM and pushed to Artifact Registry, but missing from `SCANNERS` dict in `src/infrastructure/scanner_config/scanners.py`. `GET /api/v1/scanners` returned 16 scanners — Mythril not discoverable.

**After (api-service 0.37.3):** Added Mythril `ScannerMetadata` entry and included Mythril in the Solidity "deep" scan preset.

**Test:**
```bash
curl https://app.0xapogee.com/api/v1/scanners | jq '.scanners | length'
# 17

curl https://app.0xapogee.com/api/v1/scanners/mythril
# { "id": "mythril", "name": "Mythril", "type": "symbolic_execution",
#   "languages": ["solidity"], "requires_project": false, ... }
```

### Fix #4 (by design): GitHub rate limit

**Before:** Error message: "GitHub API rate limit exceeded ... For higher limits, link a GitHub OAuth integration."

**After:** "GitHub anonymous API rate limit exceeded (60/hr per IP, resets at unix=...). To lift this limit and access private repositories, link your GitHub PAT via the integrations endpoint: POST /api/v1/organizations/{org_id}/integrations (provider=github)."

Also updated `docs/playbooks/github-url-ingest-troubleshooting.md` Issue 4 with explicit OAuth integration steps.

### Issue #2: Trident on local Anchor project — investigated, downgraded to follow-up bug

**Root cause:** The local `vulnerable_vault` test contract was uploaded via `/upload` as a tarball and persisted with `is_multi_file=True` (3 files). When KJM creates the ConfigMap for trident, it flattens directory paths using slash → underscore (ConfigMap keys can't contain slashes). So `programs/vulnerable_vault/src/lib.rs` becomes the ConfigMap key `programs_vulnerable_vault_src_lib.rs`.

The trident-scan wrapper has logic to reconstruct the directory structure:
```bash
for file in *.rs; do
    if [ -f "$file" ] && [[ "$file" == *_* ]]; then
        dir_part="${file%%_*}"
        file_part="${file#*_}"
        ...
```

But this loop only iterates **top-level** `*.rs` files. The flattened key `programs/vulnerable_vault_src_lib.rs` is in a `programs/` subdirectory (KJM partially preserves the first directory level), so the loop doesn't see it.

**Why online Anchor (`coral-xyz/anchor escrow`) works:** Online ingest via `/from-github` persists each fetched file as a `ContractFileModel` row with the original path preserved. When api-service builds the trigger payload, it sends `files: [{path, content}, ...]` with original paths, and KJM's multi-file ConfigMap delivery preserves that structure better.

**Why this isn't a regression:** Pre-existing trident wrapper limitation, exposed by the test matrix. No code change shipped for trident in this round.

**Tracked as follow-up:** Improve trident-scan wrapper's path-reconstruction loop to handle nested subdirectory files (or have api-service always use the multi-file path even for single-archive uploads).

---

## What This Verification Confirms

1. **Fixes #1, #3, #5 land cleanly** with no regressions in the rest of the pipeline.
2. **Issue #4 is correctly framed as design, not bug** — error message and playbook now direct users to the existing OAuth integration.
3. **Issue #2 is a real bug but pre-existing** — separately tracked, not in scope for this round.
4. **Mythril is now discoverable** via `/api/v1/scanners` and included in the Solidity deep scan preset.

## Post-Deploy Re-Verification (against live 0.37.3 / 0.5.43)

After image push + cluster rollout, the fixes were re-verified end-to-end against the deployed images:

| Check | Evidence |
|-------|----------|
| GitHub blob ingest | `POST /contracts/from-github` with `blob/v5.0.2/.../ERC20.sol` → HTTP 201, `language=solidity`, 316 LoC (contract `2cb8c590-0027-456c-8af3-8af094f96e3d`) |
| GitHub tree ingest | `POST /contracts/from-github` with `tree/v5.0.2/.../ERC20` folder → HTTP 201, `is_project=true`, 13 files, 1429 LoC |
| Scan queue + completion | Custom preset with `[slither,mythril,aderyn,semgrep,solhint]` → all 5 jobs completed in ~80s (scan `11260167-2ad8-4195-8170-1d9f0577bf53`) |
| Mythril running | Job `scan-mythril-11260167-…` executed and posted results (0 findings on audited OZ ERC20, expected) |
| Vyper `language_hint` | Tool-integration log: `Using language hint 'vyper' → .vy for scan 92368b3e-eccb-4d27-b7ef-ea457f2bb5f9` — confirms 0.5.43 passthrough |

The comprehensive 17-scanner × 3-input-mode matrix is scheduled as a follow-up run; results will be documented in a separate audit file.

## Cross-references

- Original audit: [`2026-04-14-scanner-e2e-test-matrix.md`](./2026-04-14-scanner-e2e-test-matrix.md)
- Feature test: `docs/feature-tests/93-github-url-ingest-and-tier-limits-2026-04.md`
- Pipeline: `docs/pipelines/github-url-ingest-pipeline.md`
- Playbook: `docs/playbooks/github-url-ingest-troubleshooting.md`
- Work summary: `TaskDocs-BlockSecOps/work-summaries/2026-04-15-known-issue-fixes.md`
