# Pre-compiled artifact upload (Migration 091) — feature tests

**Priority**: P1 — High
**Last tested**: 2026-05-12
**Endpoints**: `POST /api/v1/upload`, `POST /api/v1/scans`, `GET /api/v1/contracts/{id}`
**Scope**: Foundry/Hardhat/Anchor artifact-aware upload + scan dispatch + result rendering
**Cross-links:**
- Workflow: [`docs/workflows/contract-with-artifacts-upload.md`](../workflows/contract-with-artifacts-upload.md)
- Pipeline: [`docs/pipelines/artifact-aware-scan-dispatch.md`](../pipelines/artifact-aware-scan-dispatch.md)
- Playbook: [`docs/playbooks/troubleshoot-fuzzer-zero-findings.md`](../playbooks/troubleshoot-fuzzer-zero-findings.md)
- DB migration: [`docs/database/migrations/migration-091-contract-artifacts.md`](../database/migrations/migration-091-contract-artifacts.md)

---

## What this feature does

Lets a user upload a Foundry/Hardhat/Anchor project **with pre-compiled artifacts** (`out/`, `artifacts/`, `target/idl/`) bundled inside the archive. The api-service preserves the artifacts, stores them (inline for `<100 KiB`, GCS for `>=100 KiB`), and ships an artifact manifest in the scan dispatch payload so scanner pods skip their internal build step.

Before this feature: Halmos / Echidna / Medusa / Trident routinely reported **0 findings** on real customer projects because a missing dependency (`forge-std`, `@openzeppelin/contracts`) caused `forge build` to fail silently inside the scanner pod.

---

## Image versions that shipped together

| Component | Version | Notes |
|---|---|---|
| api-service | 0.43.11 → **0.44.2** | MINOR for Migration 091; PATCHes for `test/*.sol` inclusion in artifact-aware extraction + `has_compiled_artifacts` / `artifact_layout` surfaced on contract endpoints |
| tool-integration | 0.6.30 → **0.7.5** | MINOR for the KJM artifact-stager initContainer; PATCHes for `jq`→`python3` (cloud-sdk:slim lacks jq), GCS-pairs JSON envelope, Foundry-aware wrapper gating, Halmos+Echidna parser schema fixes |
| scanner-echidna | 0.5.5 → 0.5.6 → **0.5.7** | `--ignore-compile` is now only set for `hardhat-artifacts` layout |
| scanner-medusa | 0.5.0 → 0.5.1 → **0.5.2** | same gating as echidna |
| scanner-trident | 0.4.3 → **0.4.4** | skips `anchor build` when `target/idl/<program>.json` present |

---

## Test matrix (verified 2026-05-12)

### A. Upload path

| # | Scenario | Expected | Status |
|---|---|---|---|
| A1 | Foundry archive with `out/`, `with_artifacts=true` | HTTP 201; `has_compiled_artifacts=true`, `artifact_layout=foundry-out`, `artifact_files_count > 0` | ✅ |
| A2 | Hardhat archive with `artifacts/` + `cache/`, `with_artifacts=true` | HTTP 201; `artifact_layout=hardhat-artifacts` | ✅ |
| A3 | Source-only archive, `with_artifacts` unset | HTTP 201; `has_compiled_artifacts=false`, `artifact_layout=null` (regression baseline) | ✅ |
| A4 | Source-only archive, `with_artifacts=true` (toggle ON but no `out/` inside) | HTTP 400; `error: no_artifacts_in_archive`; framework-specific bundling guidance in message | ✅ |
| A5 | Foundry archive with `out/Token.so` (disallowed extension) inside `out/` | HTTP 201; archive uploads; database stores only `.json` artifacts (`.so` silently filtered by extension allow-list) | ✅ |
| A6 | Single-file `.sol` upload with `pragma solidity ^0.8.0` | Synchronously fails on first scan with `failure_type: unsupported_solidity_version`; no scanner Job dispatched | ✅ |

### B. Scan dispatch + finding production

| # | Scenario | Expected | Status |
|---|---|---|---|
| B1 | Halmos on Foundry+artifacts contract with intentionally-wrong invariant (`check_addOne` asserts `x + 1 == x`) | `status=completed`, `critical_count=1`; vulnerability row `Symbolic Test Failure: check_addOne(uint256)` stored | ✅ |
| B2 | Halmos on source-only sibling (same source, no `out/`) | `status=completed`, `critical_count=0` — proves the artifact path is what enabled B1 | ✅ |
| B3 | Echidna on Hardhat+artifacts contract with `echidna_neverHundred` property | `status=completed`, `high_count=1`; vulnerability stored with full call sequence (`increment` × 50) | ✅ |
| B4 | Echidna on Foundry+artifacts contract (no echidna-style asserts) | `status=completed`, 0 findings; pod logs show `Pre-compiled artifacts detected (layout=foundry-out); recompile path retained` and `crytic-compile` recompiles cleanly from source | ✅ |
| B5 | Medusa on Foundry+artifacts contract | `status=completed`, 0 findings; pod logs show fuzz run with 4 workers, ~100K calls, 4 assertion tests passed | ✅ |
| B6 | Trident on Anchor+artifacts contract | not tested (Anchor toolchain not available on local box; same plumbing path as Foundry/Hardhat — pipeline implied but not proven E2E) | ⚠️ deferred |

### C. Contract endpoint metadata

| # | Scenario | Expected | Status |
|---|---|---|---|
| C1 | `GET /api/v1/contracts?limit=N` (list) returns `has_compiled_artifacts` + `artifact_layout` for each contract | both fields present, truthy on artifact-aware uploads, false/null on source-only | ✅ |
| C2 | `GET /api/v1/contracts/{id}` (detail) returns the same fields | both fields present | ✅ |

### D. Dashboard UI (browser test — owner-driven)

These are checked in the browser against the production dashboard. Test contracts pre-uploaded under the owner's account:

| # | Contract | What to verify |
|---|---|---|
| D1 | `halmos-buggybank-v6-pure` (`86205bd5-f436-432f-b23e-c253bdcf83b3`) | "Pre-compiled ✓" chip on contract header; Foundry framework badge; halmos critical finding renders with counterexample |
| D2 | `hardhat-echidna` (`0d0c1935-222e-4616-8553-7713404324c0`) | "Pre-compiled ✓" chip; Hardhat badge; echidna HIGH finding with full call sequence |
| D3 | `halmos-buggybank-source-only` (`1b73bd3b-9005-429e-94b3-6c7e9c9cfb00`) | **No** "Pre-compiled ✓" chip — should show "Source only"; halmos scan returns 0 (the A/B baseline) |
| D4 | Re-run halmos on `halmos-buggybank-source-only` from the scanner picker | Soft amber warning above the scanner list: "This scanner depends on pre-compiled artifacts. Without them, the scan may report 0 findings…" |
| D5 | New upload, pick a Foundry archive | Modal shows "Foundry project detected" banner + "Include pre-compiled artifacts" toggle |
| D6 | New upload, single `.sol` file | Modal shows "Single file" guidance; fuzzers disabled in scanner picker |

---

## How to reproduce tests A1 / B1 locally

```bash
# 1. Build a Foundry fixture with an intentionally-wrong halmos invariant.
mkdir -p /tmp/halmos-fixture && cd /tmp/halmos-fixture
forge init --no-commit --quiet .
cat > src/BuggyBank.sol <<'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
contract BuggyBank {
    function add(uint256 a, uint256 b) external pure returns (uint256) {
        unchecked { return a + b - 1; }   // off-by-one
    }
}
EOF
cat > test/BuggyBank.t.sol <<'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Test} from "forge-std/Test.sol";
contract BuggyBankTest is Test {
    function check_addOne(uint256 x) public pure {
        uint256 y; unchecked { y = x + 1; }
        assert(y == x);   // false for every x
    }
}
EOF
cat >> foundry.toml <<'EOF'
ast = true
extra_output = ["storageLayout"]
extra_output_files = ["metadata"]
EOF
rm -rf out cache && forge build

# 2. Archive source + out/
tar -czf /tmp/halmos-buggybank.tgz --exclude='cache' --exclude='lib/forge-std/.git' \
    src test foundry.toml out lib

# 3. Upload with the toggle ON.
TOKEN=<bearer token from /auth>
curl -X POST https://app.0xapogee.com/api/v1/upload \
    -H "Authorization: Bearer $TOKEN" \
    -F "file=@/tmp/halmos-buggybank.tgz" \
    -F "with_artifacts=true"
# Expect contract_id + has_compiled_artifacts=true, artifact_layout=foundry-out.

# 4. Run halmos.
curl -X POST https://app.0xapogee.com/api/v1/scans \
    -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
    -d '{"contract_id":"<id>","scanner_ids":["halmos"]}'
# Expect critical=1 in the scan result.
```

---

## Known limitations

- **Foundry artifact JSON shape vs crytic-compile.** echidna and medusa use crytic-compile under the hood, which expects Hardhat-style `output.{abi,bytecode}` JSONs. Foundry emits flat per-contract JSONs (top-level `abi`/`bytecode`). For `foundry-out` layout, the wrappers fall back to source recompile (cheap because we now bundle test files and `lib/forge-std`). For `hardhat-artifacts`, the wrappers honour `--ignore-compile` and read the build-info file directly.
- **Anchor+trident.** Not E2E-verified — same plumbing path as Foundry/Hardhat but no test fixture built. The wrapper already skips `anchor build` when `target/idl/<program>.json` is present (trident 0.4.4).
- **Per-archive cap.** 200 MB total artifact size, 5,000 files, 10 MB per file. Tested in code; not exercised E2E.

---

## Owner test contracts on production

Already uploaded under `jasonbrailowbizop@mail.com` — ready for dashboard walk-through:

| Contract ID | Name | Purpose |
|---|---|---|
| `86205bd5-f436-432f-b23e-c253bdcf83b3` | `halmos-buggybank-v6-pure` | Foundry artifact-aware, halmos critical=1 |
| `0d0c1935-222e-4616-8553-7713404324c0` | `hardhat-echidna` | Hardhat artifact-aware, echidna high=1 |
| `1b73bd3b-9005-429e-94b3-6c7e9c9cfb00` | `halmos-buggybank-source-only` | A/B baseline: same source, no artifacts → 0 findings |
| `85519e87-f41b-4203-945d-eb1a5b5015d7` | `pragma_test_low` | pragma `^0.8.0` synchronously rejected |
| `7f6c3bb9-d650-423b-af1d-32afb59c1985` | `halmos-with-binary` | `.so` silently filtered by extractor allow-list |
