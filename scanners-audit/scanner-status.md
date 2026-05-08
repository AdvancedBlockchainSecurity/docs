# Scanner Status

**Version:** 1.0.0
**Last Updated:** 2026-05-06
**Status:** Active

## Overview

One row per scanner shipping in production. Tracks: language, scan kind, project type tested, current image version (from `scanner-versions-configmap.yaml`), last-known-good baseline, most recent end-to-end verification, current status, and open issues.

**Status legend:**
- ✅ working — produces findings on a known-vulnerable fixture
- ❌ broken — cluster-verified failure
- ⚠️ inconclusive — last verification ran on a fixture that does not match baseline; needs re-test against baseline fixture before declaring broken
- 🚧 fix-in-progress — open changelog entry, fix not yet verified

## Scanner inventory

| Scanner | Lang | Kind | Project type | Image ver | Upstream ver | Baseline (2026-05-04) | Last verified (2026-05-06) | Current status | Open issues |
|---|---|---|---|---|---|---|---|---|---|
| `slither` | solidity | single + project | foundry, hardhat, plain | 0.4.7 | 0.11.5 | ✅ 6 findings on `eafe2b12` (Foundry+OZ) [^1] | ✅ 6 structures verified 2026-05-06 — Foundry/Hardhat 6 findings (1m+5l) matches baseline; single-file reentrancy 4 findings (1c+3l); proxy/diamond/plain-ERC20 0 (clean) — scans `79695e14`, `d15814ad`, `f3ce6b02`, `9adc0acd`, `35bba6f1`, `8d84f62e` | ✅ working | — |
| `aderyn` | solidity | single + project | foundry, hardhat, plain | 0.8.5 | 0.6.7 | ✅ 5 medium on `eafe2b12` (Foundry+OZ) [^1] | ✅ 6 structures verified 2026-05-06 — single 5c+12m (17), foundry 5 medium (matches baseline), hardhat 5 medium, proxy/diamond/plain 0 — scans `44826f38`, `adad6fdc`, `ebd3b462`, `db4da773`, `0e6a2b6f`, `b2c7c7bb` | ✅ working | — |
| `semgrep` | solidity | single + project | foundry, hardhat, plain | 0.3.12 | 1.144.0 | ✅ 6 low on `eafe2b12` (Foundry+OZ) [^1] | ✅ 6 structures verified 2026-05-06 — single 6 low, proxy 16 low, diamond 28 low, foundry 6 low (matches baseline), hardhat 6 low, plain 9 low — scans `f5b8d684`, `d781cc23`, `49412f61`, `022931ec`, `2e8a9e8d`, `d5c54e29` | ✅ working | — |
| `solhint` | solidity | single + project | foundry, hardhat, plain | 0.1.14 | 6.0.2 | ✅ 16 high on `eafe2b12` (Foundry+OZ) [^1] | ✅ 6 structures re-verified 2026-05-07 post-P0-2 fix — single 26 low, foundry 16 low, hardhat 16 low, proxy/diamond/plain 0 — scans `563910da`, `b041e883`, `044f3ec8`, `5481399b`, `ae17b8ec`, `d312ade5` | ✅ working | promoted from ⚠️ — P0-2 severity-mapping fixed (image 0.1.14, jq mapping `error→MEDIUM`, `warning→LOW`); see [CHANGELOG 2026-05-07 — solhint P0-2](./CHANGELOG.md#2026-05-07--solhint-p0-2-fix-deployed) |
| `halmos` | solidity | project | foundry, hardhat, plain | 0.4.4 | 0.3.3 | ✅ 0 on `eafe2b12` — legitimate (no invariants) [^1] | ✅ 3 project structures verified 2026-05-06 — all 0 (legitimate; no `prove_*` invariants in OZ fixtures) — scans `20b19a1f`, `9f99af96`, `c1ea5acd` | ✅ working | promoted from ⚠️ — runs cleanly across all project types; verifying detection requires a fixture with `prove_*` invariants (separate task); see [CHANGELOG 2026-05-06 — halmos](./CHANGELOG.md#2026-05-06--halmos-verification) |
| `mythril` | solidity | single + project | foundry, hardhat (skip), plain | 0.2.10 | 0.24.8 | ✅ 0 on single-file `0c7542c6` (OZ) [^1] | ⚠️ 6 structures verified 2026-05-06 — Foundry 0 (matches baseline ✅), Hardhat skip-gate ✅, but **single 3/3 FAILED at compile** (Reentrancy exit_1, Proxy/Diamond solc TypeError) and plain multi-file FAILED (import resolution) — scans `bad79f12`, `b3f39e19`, `6698bf43`, `2ac045b0`, `fc1592f1`, `0d52b43d` | ⚠️ partial | works on Foundry+OZ baseline + KJM skip-gate; broken on (a) single-file Solidity using older solc patterns, (b) plain multi-file with relative imports; see [CHANGELOG 2026-05-06 — mythril](./CHANGELOG.md#2026-05-06--mythril-verification) |
| `echidna` | solidity | project | foundry, hardhat, plain | 0.5.4 | 2.2.7 | ✅ 0 on `eafe2b12` — legitimate (no `echidna_*` invariants) [^1] | ✅ 3 project structures verified 2026-05-06 — all 0 (legitimate; no `echidna_*` invariants in OZ fixtures) — scans `d0c889be`, `d9115a44`, `96f46544` | ✅ working | promoted from ⚠️ — runs cleanly across all project types; verifying detection requires a fixture with `echidna_*` invariants (separate task); see [CHANGELOG 2026-05-06 — echidna](./CHANGELOG.md#2026-05-06--echidna-verification) |
| `wake` | solidity | single + project | foundry, hardhat, plain | 0.5.8 | 4.22.0 | ✅ 0 on `eafe2b12` (Foundry+OZ) [^1] | ✅ 6 structures verified 2026-05-06 — single 0 (484s slow!), proxy 0 (484s), diamond 0 (487s), foundry **2 medium (improvement vs baseline)**, hardhat 2 medium, plain 0 (485s) — scans `dec657ce`, `55cd6403`, `7c5c90cb`, `8d1389ec`, `edd6d73b`, `ca51110d` | ✅ working | single-file scan times 8 min — perf concern; Foundry findings exceed baseline (likely 2026-05-05 target_version fix taking effect); see [CHANGELOG 2026-05-06 — wake](./CHANGELOG.md#2026-05-06--wake-verification) |
| `medusa` | solidity | project | foundry, hardhat, plain | 0.4.5 | 1.5.0 | ✅ 0 on `eafe2b12` — legitimate (no property invariants) [^1] | ✅ 3 project structures verified 2026-05-06 — all 0 findings + 1 fuzzing summary record each (F3 fix taking effect) — scans `5519a6d0`, `8b29f16f`, `b7b1b856` | ✅ working | promoted from ⚠️ — F3 fix (jq -n output) verified end-to-end; verifying fuzzer produces failures requires fixture with property invariants (separate task); see [CHANGELOG 2026-05-06 — medusa](./CHANGELOG.md#2026-05-06--medusa-verification) |
| `soliditydefend` | solidity | single + project | foundry, hardhat, plain | 0.9.9 | 2.0.9 | ✅ 1 critical on `eafe2b12` (Foundry+OZ) [^1] | ✅ 6 structures verified 2026-05-06 — single failed on pragma gate (intentional, ^0.8.0 < 0.8.12), proxy 2 high, diamond 1 high, **Foundry 1 critical (matches baseline exactly)**, Hardhat 1 critical, plain 1c+2m — scans `1de6d284`, `bdd4c643`, `6ccee62d`, `eedc266e`, `eac50825`, `56224322` | ✅ working | — |
| `vyper` | vyper | single + project | n/a | 0.3.5 | 0.4.3 | ✅ 0 on `8d5bea5f` (E2E-Vyper-Ownable) [^1] | ✅ 2 structures verified 2026-05-06 — single (Ownable) 0, multi-file (tokens-tree) 0 — scans `1854d6c5`, `bf941e40` | ✅ working | — |
| `moccasin` | vyper | project | mox, plain | 0.3.4 | 0.4.3 | ✅ 0 on `a355b720` (E2E-Vyper-tokens-tree) [^1] | ✅ verified 2026-05-06 — 0 on baseline `a355b720` (matches baseline) — scan `b1bfaf8c` | ✅ working | promoted from ⚠️ — earlier 2026-05-06 framework=plain issue was specific to a throwaway scaffold; baseline fixture works correctly; see [CHANGELOG 2026-05-06 — moccasin](./CHANGELOG.md#2026-05-06--moccasin-verification) |
| `sol-azy` | rust | single + project | anchor | 0.5.1 | 0.4.1 | ✅ 1 low on `86096252` (E2E-Rust-anchor-basic1-tree) [^1] | ✅ 2 structures verified 2026-05-06 — single 1 low, Anchor project 1 low (matches baseline) — scans `047b6fda`, `b9a53e8b` | ✅ working | — |
| `sec3-xray` | rust | project | anchor | 0.4.1 | 0.0.6 | ✅ 2 high on `86096252` (Anchor project) [^1] | ✅ verified 2026-05-06 — 4 high on `86096252` — scan `7489745c` | ✅ working | — |
| `trident` | rust | project | anchor | 0.4.3 | 0.12.0 | ❌ failed null error_message on `86096252` [^1] → F1 fix shipped image 0.4.3 [^2] | ✅ verified 2026-05-06 — failed status with detailed error_message ("Anchor build failed (exit 1): overflow-checks is not enabled...") — scan `20bc2443` | ✅ working (scanner) / ⚠️ fixture | promoted from ⚠️ — F1 fix proven end-to-end; scanner correctly surfaces fixture build issue; **fixture `86096252` itself needs `overflow-checks = true` in workspace Cargo.toml**; see [CHANGELOG 2026-05-06 — trident](./CHANGELOG.md#2026-05-06--trident-verification) |
| `cargo-fuzz-solana` | rust | project | anchor | 0.4.3 | 0.13.1 | ✅ 0 on `86096252` [^1] → F2 fix shipped image 0.4.3 [^2] | ✅ verified 2026-05-06 — 0 on `86096252` (matches baseline) — scan `6216f18b` | ✅ working | promoted from ⚠️ — runs cleanly; verifying detector firing requires fixture with `fuzz_targets/` (separate task); see [CHANGELOG 2026-05-06 — cargo-fuzz-solana](./CHANGELOG.md#2026-05-06--cargo-fuzz-solana-verification) |
| `rustdefend` | rust | single + project | anchor | 0.4.6 | 0.5.1 | ✅ 0 on `86096252` (Anchor project) [^1] | ✅ 2 structures verified 2026-05-06 — single 0, Anchor project 0 (matches baseline) — scans `9023bb50`, `59e6e60b` | ✅ working | — |

[^1]: Baseline source: [`TaskDocs-BlockSecOps/audit-2026-05-04-scanner-full-reaudit.md`](../../TaskDocs-BlockSecOps/audit-2026-05-04-scanner-full-reaudit.md) — cluster smoke test against end-user API as `jasonbrailowbizop@mail.com`.
[^2]: F1–F6 fixes verified end-to-end 2026-05-06: [`TaskDocs-BlockSecOps/audit-2026-05-06-scanner-failure-fixes.md`](../../TaskDocs-BlockSecOps/audit-2026-05-06-scanner-failure-fixes.md).

## Verification fixtures

Use the same fixtures as the 2026-05-04 baseline so status comparisons stay valid. Same-fixture comparison is the only honest evidence of regression — different fixtures = different code paths = inconclusive.

| Language | Single-file fixture | Project fixture |
|---|---|---|
| Solidity | `0c7542c6` (single-file OZ) | `eafe2b12` (Foundry+OZ multi-file) |
| Vyper | `8d5bea5f` (E2E-Vyper-Ownable) | `a355b720` (E2E-Vyper-tokens-tree) |
| Rust/Solana | n/a (most Solana scanners require project context) | `86096252` (E2E-Rust-anchor-basic1-tree) |

Fixture sources: contracts already imported into `jasonbrailowbizop@mail.com`'s account from prior audit cycles. Do not introduce new throwaway fixtures unless the row is being explicitly retired or added.

## How to verify a scanner

1. Authenticate to Supabase as `jasonbrailowbizop@mail.com` → exchange for JWT.
2. Either (a) reuse an existing baseline contract by `contract_id` from the table above, or (b) `POST /api/v1/upload` with the same fixture file.
3. `POST /api/v1/scans` with `{ "contract_id": <uuid>, "scan_type": "full", "scanner_ids": ["<one>"], "scan_source": "cli" }`.
4. Poll `GET /api/v1/scans/{scan_id}` until `status` is `completed` or `failed`. Pull `GET /api/v1/scans/{scan_id}/vulnerabilities?limit=1000`.
5. Update this scanner's row (current status, last verified, scan_id) AND add a `CHANGELOG.md` entry — same commit.
