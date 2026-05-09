# Unsupported Solidity Version Gate Tests

**Priority**: P1 - High
**Last Tested**: May 9, 2026
**Endpoint**: `POST /api/v1/scans` (gate now runs **synchronously** in api-service before any scanner pod is dispatched)
**Applies to**: All 8 Solidity scanners — wake, slither, aderyn, halmos, mythril, echidna, medusa, and soliditydefend.

**Implementation note**: 7 of the 8 pick up the wrapper-side gate from `scanner-base-solidity:1.0` (the shared base image). `soliditydefend` is a Rust-built CLI on a bespoke `debian:bookworm-slim` Dockerfile and carries its own copy of the `check-pragma` script at `scanner-images/soliditydefend/check-pragma`. The two copies must be kept in sync — when updating the gate logic, change `scanner-images/_base/check-pragma` AND `scanner-images/soliditydefend/check-pragma` together.

**As of api-service 0.43.11 (Migration 090, 2026-05-09)** the wrapper-side `check-pragma` is a **defensive backstop**. The primary enforcement now happens in api-service at scan creation — see "Upstream Pragma Gate" below.

---

## Background

The platform supports Solidity versions **0.8.12 and newer** (first 2022 release). Contracts targeting an older pragma are rejected by a pre-flight gate that runs **before any scanner Job is dispatched**. The user-facing message on the scan detail page reads:

> Contract uses Solidity `<version>` (in `<file>`), which is older than the minimum supported version (0.8.12, released 2022-01-17). Upgrade your pragma or contact support.

### Upstream Pragma Gate (api-service)

Since api-service 0.43.11 (2026-05-09), `POST /api/v1/scans` short-circuits before scanner-Job dispatch when `contract.compiler_version` is parseable but unsupported (< 0.8.12):

1. The endpoint reads `contract.compiler_version` (populated at upload time by `language_detector.py` via the `pragma\s+solidity\s+[\^>=<]*(\d+\.\d+\.\d+)` regex).
2. If null, it re-parses from `contract_files` as a defensive fallback and persists the result back so subsequent scans skip the re-parse.
3. If the parsed version is unsupported, the scan record is created immediately with `status='failed'`, `failure_type='unsupported_solidity_version'`, `error_message=<canonical pragma-gate text>`, and **no scanner Job is dispatched**.
4. If supported (or version unknown), the existing dispatch flow continues. The wrapper-side `check-pragma` covers the unknown-version edge case.

**Compute savings:** Pre-Block-A, every unsupported-version scan dispatched N scanner Jobs (N = scanner count), each pulling its image and running the wrapper for ~10–30 s. Post-Block-A, the same `POST /scans` returns synchronously in <100 ms with zero scanner Jobs created.

The single source of truth for the version policy lives at `blocksecops-api-service/src/domain/entities/solidity_version.py` (`MIN_SUPPORTED = (0, 8, 12)`, `MIN_TEXT = "0.8.12"`, `MIN_RELEASE_DATE = "2022-01-17"`).

### Wrapper-Side Backstop

The wrapper-side gate at `scanner-base-solidity:1.0.0-30aad7ef`/`/usr/local/bin/check-pragma` still fires for the rare cases where api-service couldn't classify the version (e.g., `pragma solidity *` or pragma-less contracts) and the scanner pod parses Solidity for the first time. When fired, the wrapper's failure callback now includes `"failure_type": "unsupported_solidity_version"` so the api-service-side classifier in `store_scan_results` can branch on the structured field rather than pattern-match the message.

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
- [ ] **`POST /scans` returns synchronously (sub-second) — NOT after a 30 s wrapper round-trip**
- [ ] **`kubectl get jobs -n tool-integration-prod` shows NO scanner Job dispatched for this scan_id**
- [ ] Scan status = `failed`
- [ ] `failure_type` field = `"unsupported_solidity_version"`
- [ ] `error_message` field contains: "Contract uses Solidity 0.7.6", "0.8.12", "2022-01-17", "Upgrade your pragma"
- [ ] `critical_count` / `high_count` / `medium_count` / `low_count` all = 0
- [ ] `GET /scans/{id}/executions` returns empty `executions[]` (no scanner ran)
- [ ] Dashboard renders the error message on the scan detail page (not a blank page, not a 500)
- [ ] Dashboard renders the **yellow validation-rejection banner** (`ValidationNoticeBanner`) — NOT the red "Scan Failed During Execution" panel

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
- [ ] Same contract + scanner=`soliditydefend` → rejected with same message

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
  - `failure_type`: `"unsupported_solidity_version"` (Migration 090, 2026-05-09)
  - `error_message`: string starting with "Contract uses Solidity"
  - `critical_count` / `high_count` / `medium_count` / `low_count`: all 0
  - `completed_at`: non-null (ISO-8601 timestamp)
  - `scanners_used`: populated with the requested scanner list

### 4.2 Vulnerabilities endpoint
- [ ] `GET /api/v1/scans/{scan_id}/vulnerabilities` returns an empty list for a rejected scan
- [ ] No 500 errors; empty array is the correct empty-success shape

### 4.3 Per-scanner executions endpoint
- [ ] `GET /api/v1/scans/{scan_id}/executions` on an upstream-rejected scan returns `executions: []` (the scan never reached the dispatch path)
- [ ] On a wrapper-rejected scan (legacy/edge case), each row carries `status='failed'` and `failure_type='unsupported_solidity_version'`

### 4.4 Contract response shape
- [ ] `GET /api/v1/contracts/{id}` on a pre-2022 contract returns:
  - `compiler_version`: e.g. `"0.8.0"`
  - `compiler_version_supported`: `false`
  - `min_supported_solidity_version`: `"0.8.12"`
- [ ] On a supported-pragma contract: `compiler_version_supported`: `true`
- [ ] On a contract whose pragma can't be parsed: `compiler_version_supported`: `null`

### 4.5 `failure_type` enum

Migration 090 reserves the following values; only `unsupported_solidity_version` is wired in v1, the rest are planned:

| Value | Meaning |
|-------|---------|
| `unsupported_solidity_version` | Pragma below 0.8.12 — wired |
| `compile_error` | Reserved — scanner couldn't compile contract |
| `timeout` | Reserved — scanner exceeded its time limit |
| `oom` | Reserved — scanner OOMKilled |
| `internal_error` | Reserved — uncategorized scanner crash |
| `scanner_skipped` | Reserved — scanner gated by pre-flight rule |

CHECK constraint: `failure_type IN (...) OR failure_type IS NULL`.

---

## Related Tests

- **Unit coverage** (in `blocksecops-tool-integration`):
  - `tests/unit/test_check_pragma.py` — 18 tests for the gate itself
  - `tests/integration/test_callback_endpoint.py` — 16 parametrized tests confirming every scanner branch propagates `status=failed` + `error`
- **Unit coverage** (in `blocksecops-api-service`):
  - `tests/unit/presentation/test_scan_failure_propagation.py` — 13 tests pinning the receiver-side contract
- **Related playbook**: `docs/playbooks/scanner-base-solidity-operations.md` — how to add a new solc version or change the minimum-supported cutoff.
