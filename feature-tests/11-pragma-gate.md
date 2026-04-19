# Unsupported Solidity Version Gate Tests

**Priority**: P1 - High
**Last Tested**: April 19, 2026
**Endpoint**: `POST /api/v1/scans` (indirectly — gate runs inside the scanner pod)
**Applies to**: Every Solidity scanner consuming `scanner-base-solidity:1.0` — wake, slither, aderyn, halmos, mythril, echidna, medusa.

**Not yet applied to**: `soliditydefend` (tracked under Task #160). It's a Rust-built CLI on its own Dockerfile and does not yet invoke `check-pragma`. A 0.7.6 contract submitted for `soliditydefend` currently returns `status=completed, 0 findings` (silent) rather than the clean "upgrade your pragma" rejection the other scanners emit.

---

## Background

The platform supports Solidity versions **0.8.12 and newer** (first 2022 release). Contracts targeting an older pragma are rejected by a pre-flight gate that runs in every Solidity scanner pod **before** the scanner itself. The user-facing message on the scan detail page reads:

> Contract uses Solidity `<version>` (in `<file>`), which is older than the minimum supported version (0.8.12, released 2022-01-17). Upgrade your pragma or contact support.

The gate lives in `scanner-base-solidity:1.0.0-30aad7ef` at `/usr/local/bin/check-pragma`. Every scanner wrapper (wake-scan, run-slither.sh, run-aderyn.sh, halmos-scan, run-mythril.sh, echidna-scan, medusa-scan) invokes it before running the scanner.

---

## 1. Accepted Pragmas (scan runs normally)

### 1.1 Exact-boundary `0.8.12`
- [ ] Upload a contract with `pragma solidity 0.8.12;` → scan completes normally (any findings the scanner detects should appear)
- [ ] Scan status = `completed`
- [ ] Scan detail page shows no pragma-gate error message

### 1.2 Modern pragmas (ranges, caret, tilde)
- [ ] `pragma solidity ^0.8.20;` → accepted
- [ ] `pragma solidity ~0.8.24;` → accepted
- [ ] `pragma solidity >=0.8.13 <0.9.0;` → accepted
- [ ] `pragma solidity 0.8.28;` → accepted (latest supported)

### 1.3 Multi-file projects (foundry/hardhat archive)
- [ ] All files have pragma ≥ 0.8.12 → scan completes
- [ ] Mix of different compatible pragmas (0.8.13 + 0.8.20 + 0.8.28) → scan completes

### 1.4 No pragma directive (uncommon)
- [ ] File with only comments, no `pragma solidity` line → scan runs (scanner handles its own error if it can't compile)

---

## 2. Rejected Pragmas (gate fires)

### 2.1 Single pre-2022 contract
- [ ] Upload `pragma solidity 0.7.6;` contract, trigger wake scan
- [ ] Scan completes within ~30 seconds (no network timeout loop)
- [ ] Scan status = `failed`
- [ ] `error_message` field contains: "Contract uses Solidity 0.7.6", "0.8.12", "2022-01-17", "Upgrade your pragma"
- [ ] `critical_count` / `high_count` / `medium_count` / `low_count` all = 0
- [ ] Dashboard renders the error message on the scan detail page (not a blank page, not a 500)

### 2.2 Just-below-boundary `0.8.11`
- [ ] `pragma solidity 0.8.11;` → rejected (cutoff is 0.8.12, released 1 month later)
- [ ] `unsupported_version` field (if surfaced via API) = `0.8.11`

### 2.3 Mixed good + bad files
- [ ] Project with `0.8.20` file AND `0.5.16` file → rejected (minimum drives the decision)
- [ ] Error message names the offending file with the lowest version

### 2.4 Loose constraint `>=0.7.0 <0.9.0`
- [ ] Accepted pragma style in the Solidity world but conservatively rejected by the gate (lower bound is 0.7.0, below the cutoff)
- [ ] Expected UX: customer tightens the constraint to `>=0.8.12 <0.9.0` and re-runs

### 2.5 Per-scanner consistency
- [ ] Same pre-2022 contract + scanner=`wake` → rejected with pragma-gate message
- [ ] Same contract + scanner=`slither` → rejected with same message
- [ ] Same contract + scanner=`aderyn` → rejected with same message
- [ ] Same contract + scanner=`mythril` → rejected with same message

(halmos/echidna/medusa require project archives; reject-behavior is covered by unit tests in `blocksecops-tool-integration/tests/unit/test_check_pragma.py`.)

---

## 3. No-regression Checks

### 3.1 Scanner-reported failures (non-pragma)
- [ ] A scanner that fails for a DIFFERENT reason (e.g., syntax error, internal parser crash) still surfaces the error to the dashboard. `error_message` reflects the scanner's message, not the pragma-gate message.

### 3.2 Multiple scanners on a rejected contract
- [ ] Submit a 0.7.6 contract with 4 scanners selected (wake + slither + aderyn + mythril) → each scanner's job independently fails with the pragma-gate message
- [ ] Scan-level aggregation: overall `scan.status` = `failed`, `scanners_used` lists all 4

### 3.3 Scan history remains searchable
- [ ] Failed scans appear in the user's scan list
- [ ] Filtering by `status=failed` works
- [ ] Scan detail page loads for a failed scan without errors

---

## 4. API Contract

### 4.1 Scan record response shape
- [ ] `GET /api/v1/scans/{scan_id}` on a pragma-rejected scan returns:
  - `status`: `"failed"`
  - `error_message`: string starting with "Contract uses Solidity"
  - `critical_count` / `high_count` / `medium_count` / `low_count`: all 0
  - `completed_at`: non-null (ISO-8601 timestamp)
  - `scanners_used`: populated with the requested scanner list

### 4.2 Vulnerabilities endpoint
- [ ] `GET /api/v1/scans/{scan_id}/vulnerabilities` returns an empty list for a rejected scan
- [ ] No 500 errors; empty array is the correct empty-success shape

---

## Related Tests

- **Unit coverage** (in `blocksecops-tool-integration`):
  - `tests/unit/test_check_pragma.py` — 18 tests for the gate itself
  - `tests/integration/test_callback_endpoint.py` — 16 parametrized tests confirming every scanner branch propagates `status=failed` + `error`
- **Unit coverage** (in `blocksecops-api-service`):
  - `tests/unit/presentation/test_scan_failure_propagation.py` — 13 tests pinning the receiver-side contract
- **Related playbook**: `docs/playbooks/scanner-base-solidity-operations.md` — how to add a new solc version or change the minimum-supported cutoff.
