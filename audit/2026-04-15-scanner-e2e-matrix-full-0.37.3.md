# Scanner E2E Matrix — Full Run Against 0.37.3 / 0.5.43

**Date:** 2026-04-15
**Account:** `jasonbrailowbizop@mail.com` (production)
**API:** `https://app.0xapogee.com/api/v1`
**Versions:** api-service `0.37.3`, tool-integration `0.5.43` (both live in prod before and after the backup-recovery + known-issue PRs merged earlier today)
**Input modes:** single-file (GitHub blob), project (GitHub tree), archive upload (`.tar.gz`)

## Summary

| Result | Count |
|--------|-------|
| **Scanner × input-mode combinations verified** | 25 |
| **Scanners confirmed working in at least one applicable mode** | **15 of 17** |
| **Scanners blocked by pre-existing infra constraint** | 2 (trident, cargo-fuzz-solana) |
| **Regression found** | 0 |

## Contracts ingested

| Name | ID | Language | Framework | Files | Source |
|------|-----|----------|-----------|-------|--------|
| E2E-OZ-ERC20-blob | `2cb8c590-…` | solidity | — | 1 | GitHub blob (OZ v5.0.2 ERC20.sol) |
| E2E-OZ-ERC20-tree | `24b7de7b-…` | solidity | — | 13 | GitHub tree (OZ v5.0.2 token/ERC20) |
| E2E-Vyper-Ownable | `8d5bea5f-…` | vyper | — | 1 | GitHub blob (vyperlang examples ERC20.vy) |
| E2E-Vyper-tokens-tree | `a355b720-…` | vyper | — | 4 | GitHub tree (vyperlang examples/tokens) |
| E2E-Rust-anchor-lib-blob | `7b536063-…` | rust | — | 1 | GitHub blob (coral-xyz anchor basic-1 lib.rs) |
| E2E-Rust-anchor-basic1-tree | `86096252-…` | rust | **anchor** | 6 | GitHub tree (coral-xyz anchor basic-1) |
| sol_archive.tar | `401c48cb-…` | solidity | **foundry** | 3 | archive upload (.tar.gz) |
| vy_archive.tar | `f6f6bb5b-…` | vyper | plain | 2 | archive upload (.tar.gz) |
| rs_archive.tar | `826ce3b8-…` | rust | **anchor** | 2 | archive upload (.tar.gz) |

Framework detection works on all three input modes: foundry for the Solidity archive, anchor for both Rust project ingests (tree + archive), plain for the Vyper archive. (The GitHub tree contracts came from `coral-xyz/anchor` repo — Anchor config is present at the examples root, not at `basic-1/`, so the per-subtree framework was null; within the archive the Anchor.toml is at the top so framework was `anchor`.)

## Per-scanner × per-input-mode results

Evidence source: Kubernetes Events in `tool-integration-prod` (Job creations persist 1h) + `vulnerabilities` table rows keyed by `scan_id`.

| Scanner | Language | Needs project | Single-file | Project tree | Archive upload |
|---------|----------|:-------------:|:-----------:|:------------:|:--------------:|
| slither | solidity | no | ✅ | ✅ | ✅ |
| aderyn | solidity | no | ✅ | ✅ | ✅ |
| semgrep | solidity | no | ✅ | ✅ | ✅ |
| solhint | solidity | no | ✅ | ✅ | ✅ |
| mythril | solidity | no | ✅ | ✅ | — |
| wake | solidity | no | ✅ | ✅ | — |
| soliditydefend | solidity | no | ✅ | ✅ | — |
| halmos | solidity | **yes** | N/A | ✅ | — |
| echidna | solidity | **yes** | N/A | ✅ | — |
| medusa | solidity | **yes** | N/A | ✅ | — |
| vyper | vyper | no | ✅ | ✅ | ✅ |
| moccasin | vyper | **yes** | N/A | ✅ | — |
| sol-azy | rust | no | ✅ | ✅ | ✅ |
| rustdefend | rust | no | ✅ | ✅ | ✅ |
| sec3-xray | rust | **yes** | N/A | ✅ | ✅ |
| **trident** | rust | **yes** | N/A | ❌ **BLOCKED** | — |
| **cargo-fuzz-solana** | rust | **yes** | N/A | ❌ **BLOCKED** | — |

"—" = input mode not exercised for that scanner in this run (not a failure — archive upload was used as a third data point, not an exhaustive per-scanner sweep).

## Finding-count highlights (verification the scans actually did work, not just queue+drop)

| Scan | Scanner | Severity | Findings |
|------|---------|----------|---------:|
| SOL-single (OZ ERC20.sol) | semgrep | low | 1 |
| SOL-single | solhint | high | 45 |
| SOL-single | soliditydefend | medium | 1 |
| SOL-tree (OZ ERC20 folder) | semgrep | low | 9 |
| SOL-tree | soliditydefend | critical+medium | 3 |
| SOL-arch (custom Token+Ownable) | semgrep | low | 9 |
| SOL-arch | slither | high+low | 3 |
| SOL-arch | solhint | high | 18 |
| RUST-single (Anchor lib.rs) | sol-azy | low | 1 |
| RUST-tree (Anchor basic-1) | sec3-xray | high | 2 |
| RUST-tree | sol-azy | low | 1 |

Zero findings on several Solidity scanners (slither, aderyn, mythril, wake) against OZ ERC20 is expected — that codebase is a widely-audited reference implementation. The scanners *ran* (evidenced by Kubernetes Events and parser log lines) and posted 0 findings.

## NEW FINDING — trident + cargo-fuzz-solana never execute

### Symptom
Jobs `scan-trident-<scan_id>` and `scan-cargo-fuzz-solana-<scan_id>` are created in `tool-integration-prod` but their pods never reach Running. Instead the Job controller loops creating pods that are rejected by admission:

```
Warning  FailedCreate  job/scan-trident-b344a1e1-…
  Error creating: pods "scan-trident-…" is forbidden:
  maximum memory usage per Container is 2Gi, but limit is 4Gi
```

### Root cause
`LimitRange/default-limits` in `tool-integration-prod` (applied 2026-03-10) caps container memory at 2Gi:

```yaml
spec:
  limits:
  - max: {cpu: "1", memory: 2Gi}
    default: {cpu: 500m, memory: 512Mi}
    defaultRequest: {cpu: 100m, memory: 128Mi}
    type: Container
```

Trident and cargo-fuzz-solana job specs request `limits: {memory: 4Gi}` (needed for a realistic fuzz campaign). Every pod-create call is rejected, so the Job never runs. The scan eventually transitions to "failed" with no scanner results.

### Impact
These two scanners have been silently non-functional in prod since 2026-03-10 (5+ weeks). They are listed in the registry (`GET /api/v1/scanners`) and accepted by the scan trigger endpoint, so the UX suggests they work.

### Scope
- Only affects `trident` and `cargo-fuzz-solana`
- All 15 other scanners run within the 2Gi cap
- No data-protection implication; does not affect other workloads

### Proposed fixes (not applied here — requires owner approval per Rule 0)

**Option A (recommended):** Raise the LimitRange max for the `tool-integration-prod` namespace to at least 4Gi:

```yaml
spec:
  limits:
  - max: {cpu: "2", memory: 4Gi}      # was 1 CPU / 2Gi
    default: {cpu: 500m, memory: 512Mi}
    defaultRequest: {cpu: 100m, memory: 128Mi}
    type: Container
```

Only trident and cargo-fuzz-solana ask for >2Gi; other scanners keep their current small requests.

**Option B:** Reduce trident / cargo-fuzz-solana memory limits to 2Gi in their Job specs. Likely causes OOM during fuzz campaigns and defeats the purpose of running them.

**Option C:** Dedicate a separate namespace for high-memory fuzzers with its own LimitRange. Cleaner isolation but adds operational overhead.

Option A is lowest-risk and minimal-change. It should be paired with a ResourceQuota bump (currently 4-pod/4Gi total for `tool-integration-prod`) if concurrent trident and cargo-fuzz runs are expected.

## Input-mode verifications (not scanner-specific)

| Input mode | Verdict | Evidence |
|------------|---------|----------|
| GitHub blob (`/contracts/from-github` with `/blob/` URL) | PASS | HTTP 201, `is_multi_file=false`, single file persisted |
| GitHub tree (`/contracts/from-github` with `/tree/` URL) | PASS | HTTP 201, `is_multi_file=true`, recursive fetch, framework detected when root config present |
| Archive upload (`/upload` with `.tar.gz`) | PASS | HTTP 200, files extracted, framework detected (foundry/anchor/plain), main file path inferred |

## Known-issue fixes re-confirmed

| Issue (from 2026-04-14 audit) | Status |
|-------------------------------|--------|
| #1 Vyper single-file fails with "No .vy files found" | **FIXED** — log confirms `Using language hint 'vyper' → .vy` |
| #3 framework=None on `/from-github` tree | **FIXED** — `framework=anchor` populated on Rust Anchor tree ingest |
| #5 Mythril missing from `/api/v1/scanners` | **FIXED** — mythril listed AND running; 17 scanners registered |

## Follow-up work

1. **LimitRange bump** for `tool-integration-prod` namespace (unblock trident + cargo-fuzz-solana) — separate PR, needs owner approval
2. **Registry truthfulness** — either fix the memory cap or remove trident/cargo-fuzz-solana from the public scanner list until they work; current state lies to users
3. **Concurrency test** — previous 6-scan matrix scheduled all 23 working scanner jobs concurrently and completed in ~80s; should be captured as a soak-test baseline
4. **Archive sweep** — this run exercised archive uploads against 7 scanners (slither, aderyn, semgrep, solhint, vyper, sol-azy, rustdefend, sec3-xray); a follow-up could run the project-required scanners (halmos, echidna, medusa, moccasin) against archive uploads to cover the full matrix cell

## Cross-references

- Prior audit: `docs/audit/2026-04-14-scanner-e2e-test-matrix.md`
- Known-issue verification: `docs/audit/2026-04-15-known-issue-fixes-verification.md`
- Feature test: `docs/feature-tests/93-github-url-ingest-and-tier-limits-2026-04.md`
- Ingest pipeline: `docs/pipelines/github-url-ingest-pipeline.md`
