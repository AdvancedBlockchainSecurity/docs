# Scanner E2E Test Matrix — 2026-04-14

**Auditor:** Apogee Platform Team
**Account:** `jasonbrailowbizop@mail.com` (production)
**API:** `https://app.0xapogee.com/api/v1`
**api-service version:** `0.37.2`

## Scope

Verify all 16 API-exposed scanners can run end-to-end through the full platform pipeline:

- `POST /api/v1/contracts` (single-file paste) and `POST /api/v1/upload` (archive) — pre-existing ingest paths
- `POST /api/v1/contracts/from-github` — new in api-service 0.37.x

For each scanner, exercise every applicable input shape:

- **Single-file local** — source pasted via JSON
- **Single-file online** — fetched from a public GitHub blob URL
- **Project local** — archive uploaded via `/upload`
- **Project online** — fetched from a public GitHub tree URL

Mythril is not exposed via the public API (16 of 17 scanners tested).

## Result Matrix

Counts are `critical / high / medium / low`. "—" means input shape is not applicable for that scanner per `/api/v1/scanners` `requires_project` flag.

| Scanner | Single-file local | Single-file online | Project local | Project online |
|---------|-------------------|--------------------|--------------|----------------|
| **slither** | completed 1/2/3/3 | completed 0/0/0/0 | — | — |
| **aderyn** | completed 6/0/8/0 | completed 0/0/0/0 | — | — |
| **semgrep** | completed 0/0/0/7 | completed 0/0/0/1 | — | — |
| **solhint** | completed 0/28/0/0 | completed 0/32/0/0 | — | — |
| **wake** | completed 0/1/3/0 | completed 0/0/0/0 | — | — |
| **soliditydefend** | completed 0/0/0/0 | completed 0/0/1/0 | — | — |
| **vyper** | completed 0/0/0/0 | **failed** | — | — |
| **sol-azy** | completed 0/0/0/0 | completed 0/0/0/1 | — | — |
| **rustdefend** | completed 5/4/4/0 | completed 0/6/0/0 | — | — |
| **halmos** | — | — | completed 0/0/0/0 | completed 0/0/0/0 |
| **echidna** | — | — | completed 0/0/0/0 | completed 0/0/0/0 |
| **medusa** | — | — | completed 0/0/0/0 | completed 0/0/0/0 |
| **moccasin** | — | — | completed 0/0/0/0 | completed 0/0/0/0 |
| **sec3-xray** | — | — | completed 0/0/0/0 | completed 0/6/0/2 |
| **trident** | — | — | **failed** | completed 0/0/0/0 |
| **cargo-fuzz-solana** | — | — | completed 0/0/0/0 | completed 0/0/0/0 |

**Tally:** 30 of 32 applicable scans completed; 2 failures are documented below as known issues (neither is a scanner pipeline regression).

## Test Inputs

### Single-file local

| Language | Source | Contract ID |
|----------|--------|-------------|
| Solidity | `tests/test_contracts/VulnerableToken.sol` (vuln intentionally) | `3fabf905-…` |
| Vyper | `examples/vyper/SimpleToken.vy` | `2f4763f1-…` |
| Rust | `test-contracts/solana/vulnerable_vault.rs` | `b7b9856d-…` |

### Single-file online (via `/contracts/from-github` blob URLs)

| Language | GitHub URL | Contract ID |
|----------|-----------|-------------|
| Solidity | `OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol` | `12c58873-…` |
| Vyper | `vyperlang/vyper/blob/master/examples/tokens/ERC20.vy` | `2c43a09c-…` |
| Rust | `coral-xyz/anchor/blob/master/tests/escrow/programs/escrow/src/lib.rs` | `36d8e311-…` |

### Project local (existing test fixtures + new uploads)

| Project | Contract ID |
|---------|-------------|
| `halmos-easy-project.tar` | `3c21e058-…` |
| `echidna-easy-project.tar` | `4c946023-…` |
| `medusa-easy-project.tar` | `29e57b05-…` |
| Vyper moccasin project (created for this test) | `b10ac00d-…` |
| `test-anchor-project.tar.gz` (vulnerable_vault) | `5d536cd0-…` |

### Project online (via `/contracts/from-github` tree URLs)

| Project | Files | LoC | Contract ID |
|---------|-------|-----|-------------|
| `Uniswap/v3-core/tree/main/contracts` | 62 | 27 | `e9f7fe4a-…` |
| `coral-xyz/anchor/tree/master/tests/escrow` | 6 | 260 | `a90661b8-…` |
| `vyperlang/vyper/tree/master/examples/tokens` | 4 | 408 | `750a759c-…` |

## Real Vulnerabilities Detected (sampling)

| Scanner | Input | Finding |
|---------|-------|---------|
| slither | VulnerableToken.sol | 1 critical (reentrancy in withdraw), 2 high (tx.origin auth, unchecked call) |
| aderyn | VulnerableToken.sol | 6 critical |
| solhint | OZ ERC20 (online) | 32 high (style violations) |
| rustdefend | vulnerable_vault.rs | 5 critical, 4 high (integer overflows, missing signer/owner checks) |
| rustdefend | escrow.rs (online) | 6 high |
| sec3-xray | Anchor escrow (online) | 6 high, 2 low |
| sol-azy | escrow.rs (online) | 1 low |

The platform pipeline correctly delivers contracts to scanners, scanners detect real issues, callbacks post results, and findings persist to the `vulnerabilities` table.

## Known Issues (Failures)

> **Update 2026-04-15:** Issues #1, #3, #5 fixed in api-service 0.37.3 + tool-integration 0.5.43. Issue #4 confirmed as by-design (use OAuth integration). Issue #2 reproduced and downgraded to a pre-existing trident-wrapper bug (separately tracked). See [`2026-04-15-known-issue-fixes-verification.md`](./2026-04-15-known-issue-fixes-verification.md) for full re-verification details.

### 1. `vyper` scanner fails on single-file `/from-github` ingest
**Symptom:** Vyper scanner reports `ERROR: No .vy files found in /contracts`.

**Root cause:** When `/contracts/from-github` ingests a single `.vy` file, the contract record's name doesn't include the `.vy` extension. The KJM mounts the source as `/contracts/<contract_name>`, and the Vyper wrapper looks for `*.vy` specifically. The Solidity scanners aren't sensitive to extension-vs-content mismatch the same way — they read source content directly.

**Workaround:** Use the same `.vy` file via local upload (paste source) — works. Or upload as a project archive.

**Fix path:** When `/from-github` ingests a blob, persist the original filename (e.g., `ERC20.vy`) alongside the contract record so the KJM mounts it with the correct extension. Tracked as a follow-up patch.

### 2. `trident` failed on local Anchor project, succeeded on online project
**Symptom:** `trident-anchor-local` returned `failed` ("Job failed after all retries"), but `trident-anchor-online` (same scanner, similar Anchor project from coral-xyz) returned `completed`.

**Root cause:** The local `vulnerable_vault` project ships with a minimal `Anchor.toml` that doesn't fully match the workspace structure trident expects after `trident init`. The online coral-xyz/anchor escrow project has a proper Anchor workspace.

**Not a regression:** Trident's K8s integration is working — the failure is project-shape specific, not pipeline-level.

## What Was Verified

1. **All 16 API-exposed scanners** complete via the platform pipeline for at least one input shape.
2. **`POST /api/v1/contracts/from-github`** works end-to-end for both blob (single-file) and tree (multi-file) URLs.
3. **`source_repo_url`, `source_commit_hash`, `source_file_path`** persist correctly for GitHub-ingested contracts (verified via direct DB query: `9cfdccd35350...` was the resolved commit SHA for the OZ IERC20 test).
4. **Tier safety limits** apply uniformly across `/upload` and `/from-github` paths (both call `extract_with_smart_dependencies`).
5. **Real vulnerabilities** detected on intentionally-vulnerable test contracts (rustdefend 5 critical, slither 1 critical, aderyn 6 critical).
6. **Multi-language archive extraction** correctly identifies Anchor/Foundry/Hardhat/plain frameworks from uploaded tarballs.
7. **Pre-vendored crates** in trident/cargo-fuzz-solana scanner images successfully run `anchor build` and `cargo fuzz build` offline (NetworkPolicy blocks crates.io).

## Coverage Gaps to Address

1. Single-file `/from-github` for Vyper (filename extension preservation — see Known Issue 1).
2. Mythril is in the scanner registry but not exposed via the API — needs registration in `/api/v1/scanners` listing or admin-only flag clarification.
3. `framework=None` is reported on contracts ingested via `/from-github` even when the tree includes `Anchor.toml`/`foundry.toml` — framework detector isn't run on the GitHub fetch path. Scanners still work because they re-detect framework at runtime from the mounted ConfigMap files. Cosmetic only.

## Cross-references

- Feature test: `docs/feature-tests/93-github-url-ingest-and-tier-limits-2026-04.md`
- Pipeline: `docs/pipelines/github-url-ingest-pipeline.md`
- Workflow: `docs/workflows/contract-ingest-workflow.md`
- Playbook: `docs/playbooks/github-url-ingest-troubleshooting.md`
- Work summary: `TaskDocs-BlockSecOps/work-summaries/2026-04-14-github-url-ingest-and-tier-limit-increases.md`
