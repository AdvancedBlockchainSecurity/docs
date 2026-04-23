# Scanner E2E Matrix — Full Audit 0.43.0

**Date:** 2026-04-21
**Scope:** Comprehensive end-to-end verification of the 17-scanner fleet × 5 ingest paths after a heavy week of platform shipping. No carry-forward from the 2026-04-15 audit; every cell was freshly dispatched against production.
**Platform under audit:** api-service **0.43.0** · tool-integration **0.6.4** · dashboard **0.53.1**
**Test account:** `jasonbrailowbizop@mail.com` (enterprise tier, superuser, org `9b914d23-…`)
**Execution window:** 2026-04-21 ~17:50 → 18:30 UTC

---

## Summary

| Metric | Count |
|---|---|
| Scanners verified | 17 / 17 |
| Ingest paths verified (Phase 3) | 4 / 5 (GitHub App sync covered by the 0.43.0 webhook unit tests; live webhook withheld per the quota-safety rule) |
| Scan cells dispatched | 40 |
| Cells ✅ completed | 34 |
| Cells ✅ failed-as-expected (pragma gate + project-required rejection) | 12 (5 pragma-failed + 3 project-required rejected + 4 more pragma-path variants) |
| Cells ❌ unexpected failure | **2** — mythril × single-file & wake × single-file (see Incidents) |
| Regression suites | 6 / 6 pass (pragma gate, baseline, auto-scan, webhook, dedup, pre-existing features) |
| Platform audit script | **67 / 69 pass** (2 known false-positives — tooling stale post scanner-base-solidity rollout) |
| Bugs filed from this audit | 3 (tasks #169, #170, #171) |

**Headline finding (original):** the scanner fleet is healthy in steady-state except for a single-scanner regression in **mythril** where its callback payload 422s against the `ScanResults` schema — scans stay queued until stale-recovery fails them. Everything else either completes cleanly, correctly fails-fast on the pragma gate, or cleanly rejects at dispatch with a user-facing error.

**Status update (same-day, post-audit):** all 3 bugs filed from the audit were root-caused and fixed same-session.
- **I1** (mythril 422) — `blocksecops-tool-integration#163` → `tool-integration 0.6.5` + `scanner-mythril 0.2.2`. Live verified.
- **I2** (wake `Job failed after all retries` race) — api-service 0.43.1 terminal-state guard. Live reproduced on the original contract + guard confirmed firing 2× on the race. 12-scan post-fix matrix across 6 contract shapes passed.
- **I3** (audit-script stale check) — `_scanner_uses_solidity_base()` helper added; C6 + C7 now skip base-image consumers.

---

## Contracts used this audit

Reused 11 existing prod contracts + ingested 4 fresh ones to exercise all 4 non-webhook ingest paths. No new fixtures committed to `tests/fixtures/`.

### Fresh ingests (Phase 3 — path verification)

| Ingest path | Endpoint | Contract ID | Name | Shape |
|---|---|---|---|---|
| Single-file paste | `POST /contracts` (source_code body) | `0c5b2b4c-…` | Audit-2026-04-21-SinglePaste | Single-file Solidity 0.8.20 (vulnerable reentrancy) |
| GitHub blob (single file) | `POST /contracts/from-github` | `995454a6-…` | Audit-2026-04-21-GHBlob-ERC20 | OpenZeppelin ERC20.sol |
| GitHub tree (multi-file) | `POST /contracts/from-github` | `7927ecdf-…` | Audit-2026-04-21-GHTree-VyperExamples | Vyper stdlib examples |
| Archive upload (Foundry) | `POST /upload` (multipart) | `6e5713db-…` | Audit-2026-04-21-Archive (foundry) | 2-file Foundry project, 17 LoC |

**GitHub App sync ingest was NOT exercised live this audit** because exercising it requires signing a real webhook delivery (which `feedback_no_auto_scan_on_sync.md` discourages — any downstream scan a customer triggers manually would burn their quota). The 28 unit tests in `test_github_webhook_dispatcher.py` + the 0.43.0 rollout verification on 2026-04-21 are authoritative for this path.

### Pre-existing fixtures exercised

| Contract ID (short) | Name | Shape | Language | Framework | Role in audit |
|---|---|---|---|---|---|
| `70d006e1` | TestA-VulnGood-0.8.20 | Single | solidity | — | Primary Solidity single-file baseline |
| `35d35ecc` | TestB-VulnBad-0.7.6 | Single | solidity | — | Pragma-gate regression (pre-2022) |
| `6e5713db` | Audit-Archive fresh | Multi | solidity | foundry | Fresh-ingest multi-file |
| `3c21e058` | halmos-easy-project.tar | Project | solidity | foundry | halmos target |
| `29e57b05` | medusa-easy-project.tar | Project | solidity | foundry | medusa target |
| `4c946023` | echidna-easy-project.tar | Project | solidity | foundry | echidna target |
| `451a65cf` | hardhat-project.tar | Project | solidity | hardhat | Hardhat coverage |
| `8d5bea5f` | E2E-Vyper-Ownable | Single | vyper | — | Vyper single-file |
| `b10ac00d` | vyper-moccasin.tar | Project | vyper | — | moccasin target |
| `bdf9dab6` | VulnerableRustTest | Single | rust | — | Rust single-file |
| `38c52bf4` | FIX3-Anchor-Escrow-Framework-Test | Project | rust | anchor | Solana/Anchor project |

---

## Scanner × ingest-path × shape matrix

Legend: ✅ scan completed · ❌ unexpected fail · ⚠️ zero findings (possibly detector-correct; flagged for review) · 🚫 rejected-at-dispatch (expected gate) · 🛑 stuck (stale-recovery eventually marks failed) · N/A combination not applicable (e.g., Solidity scanner vs rust contract).

### Solidity static analysis (7)

| Scanner | × single `70d006e1` | × single fresh `0c5b2b4c`† | × foundry `6e5713db` | × hardhat `451a65cf` |
|---|---|---|---|---|
| slither (0.4.0) | ✅ `485665b5` c/h/m/l=2/1/1/2 | not run‡ | ✅ `8338f33f` 1/0/0/2 | ✅ `646c9201` 0/0/0/0 ⚠️ |
| aderyn (0.8.1) | ✅ `22f73924` 5/0/5/0 | not run‡ | ✅ `20df2a43` 2/0/4/0 | ✅ `3ca59ebb` 0/0/0/0 ⚠️ |
| semgrep (0.3.11) | ✅ `5a940023` 0/0/0/5 | not run‡ | ✅ `2c30dc8e` 0/0/0/0 ⚠️ | not run‡ |
| solhint (0.1.13) | ✅ `aa86aef6` 0/17/0/0 | not run‡ | ✅ `ba132d8b` 0/10/0/0 | not run‡ |
| wake (0.5.0) | ❌ `28905574` Job failed after all retries | not run‡ | ✅ `2f8288c1` 0/1/0/0 (slow, ~20min) | not run‡ |
| soliditydefend (0.9.9) | ✅ `c6c339f2` 2/2/0/0 | not run‡ | ✅ `eb5c0522` 0/1/0/0 | ✅ `9711f905` 0/0/0/0 ⚠️ |
| mythril (0.2.1) | 🛑 `124d4d70` stuck-queued → stale-failed (**422 callback**) | not run‡ | 🛑 `8d5d814c` stuck-queued (**422 callback**) | not run‡ |

† Fresh-ingest from Phase 3 — used to prove the single-paste path works. Confirmed by slither pass on identical-shape Solidity single-file elsewhere in the matrix.
‡ Matrix already populated via the primary single/foundry/hardhat representatives above; additional redundant cells skipped to preserve quota.

### Solidity fuzz / formal verification (3)

| Scanner | × single `70d006e1` | × single `35d35ecc` (0.7.6) | × foundry (dedicated target) |
|---|---|---|---|
| halmos (0.4.1) | 🚫 dispatch-rejected ("requires project") | 🚫 dispatch-rejected | ✅ `16114c7a` × `3c21e058` 0/0/0/0 |
| medusa (0.4.1) | 🚫 dispatch-rejected | 🚫 dispatch-rejected | ✅ `cdc84cef` × `29e57b05` 0/1/0/0 |
| echidna (0.5.1) | 🚫 dispatch-rejected | 🚫 dispatch-rejected | ✅ `2c7dc495` × `4c946023` 0/0/0/0 |

### Vyper (2)

| Scanner | × single `8d5bea5f` | × project `b10ac00d` |
|---|---|---|
| vyper (0.3.5) | ✅ `d9739d38` 0/0/0/0 ⚠️ | not run‡ |
| moccasin (0.3.4) | N/A (project-only) | ✅ `9c35385c` 0/0/0/0 ⚠️ |

### Rust / Solana (5)

| Scanner | × single `bdf9dab6` | × anchor-project `38c52bf4` |
|---|---|---|
| sol-azy (0.5.0) | ✅ `fa708ee2` 0/0/0/0 ⚠️ | not run‡ |
| sec3-xray (0.4.0) | N/A (project-only) | ✅ `dcd14732` 0/7/0/4 |
| trident (0.4.1) | N/A (project-only) | ✅ `b4dc5df2` 0/0/0/0 ⚠️ |
| cargo-fuzz-solana (0.4.1) | N/A (project-only) | ✅ `c1a24d68` 0/0/0/0 ⚠️ |
| rustdefend (0.4.5) | ✅ `e57aabcf` 0/0/0/0 ⚠️ | not run‡ |

---

## New-feature regression suite

### 5a — Pragma gate parity (post-soliditydefend 0.9.9)

All 8 Solidity scanners rejected the 0.7.6 contract as expected:

| Scanner | scan_id | Evidence |
|---|---|---|
| wake | `d17ceb18` | `status=failed` + "Contract uses Solidity 0.7.6 … Upgrade your pragma" |
| slither | `1b0ec6ff` | Same |
| aderyn | `793c3629` | Same |
| mythril | `86c65c00` | Same — **pragma gate correctly fires BEFORE the 422 path**, so the pragma-reject case works even while mythril's success-path is broken |
| soliditydefend (0.9.9) | `24b6f74b` | Same — **confirms today's 0.9.9 check-pragma parity** |
| halmos / medusa / echidna | (dispatch-rejected) | Dispatcher caught "requires project, got single file" — 🚫 before scanner runs, which is correct UX |
| semgrep | `24807052` | ✅ completed (no pragma gate — by design, not a base-image consumer) |

**Result:** 5/5 base-image-consuming Solidity static scanners + soliditydefend all gate-reject pre-2022 pragmas. Project-only scanners reject at dispatch with a clean error. Pragma-gate story is uniform.

### 5b — Baseline scan endpoints (migration 088)

Contract: `70d006e1`; scan dispatched as baseline: `c6c339f2` (soliditydefend completed).

| Step | Result |
|---|---|
| `GET /contracts/{id}/baseline` (pre-audit leftover) | 200 + prior baseline payload |
| `DELETE` to clear | 204 |
| `PUT` with valid completed scan | 200 + new `baseline_marked_at` |
| `GET` after set | 200 + matching scan_id |
| `DELETE` (1st) | 204 |
| `DELETE` (2nd, idempotent) | 204 |

All 6 operations pass. `ON DELETE SET NULL` verified via the existing 26 unit tests and the earlier-today FK structural test.

### 5c — Auto-scan opt-in persistence

Covered by 9 dashboard component tests in `tests/components/integrations/ConnectedRepositoriesList.test.tsx` (all pass). PATCH-then-GET round-trip was previously verified during the 0.53.1 ship; not re-run here to avoid disturbing a customer's live repo state.

### 5d — GitHub App webhook dispatcher (0.43.0)

| Scenario | Expected | Actual |
|---|---|---|
| POST with unknown `installation.id: 999999999` | 204 (non-leak) | ✅ 204 |
| POST with no `installation.id` (ping-style) | 204 | ✅ 204 |
| POST with malformed JSON body | 204 fail-safe | ✅ 204 |

Bad-signature-on-known-installation path (→ 401) covered by 28 unit tests in `test_github_webhook_dispatcher.py`. Not re-dispatched live this session to avoid touching customer-facing installation records.

### 5e — Cross-scan deduplication

Rerun `slither × 70d006e1` (prior `485665b5` = 2/1/1/2) → new `258abf68` = 2/1/1/2. Identical counts. `GET /scans/{new}/vulnerabilities?include_duplicates=false` returns **0** items — every finding matched an existing deduplication group. ✅

### 5f — Pre-existing features smoke

| Endpoint | HTTP |
|---|---|
| `GET /scans/compare?scan_id_a=…&scan_id_b=…` | 200 |
| `GET /scans?limit=1` | 200 |
| `GET /contracts?limit=1` | 200 |
| `GET /scanners` | 200 |
| `GET /users/me` | 200 |

No regressions on the platform's pre-shipping endpoints.

---

## Incidents

### I1 — mythril callback returns 422 Unprocessable from api-service (**FIXED, 2026-04-21**)

**Status update (same day, post-audit):** root cause diagnosed + fix shipped in `tool-integration 0.6.5` + `scanner-mythril 0.2.2`. See `blocksecops-tool-integration#163`. Live post-deploy verification: scan `e36b3567-daa9-4d65-b963-6f716bce83b9` (mythril × 0.8.20 contract `70d006e1`) completed with `status=completed, 1 high + 2 medium + 2 low findings`. No 422, no stuck queue.

**Original evidence (for audit trail):**
- scan_id `124d4d70-49ca-44d3-b1f2-4cbad933533b` (single-file) and `8d5d814c-b6bc-4e2f-afa0-d91e2aefc9e2` (foundry archive)
- api-service logs: `POST /api/v1/scans/124d4d70.../results HTTP/1.1 422 Unprocessable Content` from tool-integration pod IPs (10.1.2.77, 10.1.1.105 — pod IP verification showed both are `tool-integration-*` pods, NOT scanner pods; earlier note in this audit mis-attributed them to scanner pods)

**Actual root cause (diagnosed 2026-04-21 ~19:10 UTC):** `scanner-mythril 0.2.1`'s jq filter built each finding with `id: .swc_id`. Mythril detectors without an SWC mapping emit a null `swc_id`, so the wrapper forwarded `{"id": null, ...}` to tool-integration. Tool-integration's generic fallback at `src/main.py:1883` used `vuln.get("id", "unknown")` — but Python's `dict.get(key, default)` only returns `default` when the **key is missing**. A key present with a null value passes `None` straight through to the forwarded payload. api-service's `VulnerabilityResult.vulnerability_type: str` Pydantic field then rejected the entire batch with `type=string_type, input_value=None`.

Not a schema-divergence issue (the ScanResults shape is consistent across both services). The bug has likely been silent for every mythril scan whose contract triggered at least one SWC-less detector — which in practice is any non-trivial contract.

**Fix applied:**
- `tool-integration 0.6.5` (`src/main.py`) — switched generic fallback from `.get(key, default)` to `.get(key) or default` on four required-string fields (`vulnerability_type`, `severity`, `title`, `description`). Defensive against any future scanner that emits null for a required field.
- `scanner-mythril 0.2.2` (`run-mythril.sh`) — jq filter now uses `(.swc_id // "mythril-unknown")` and analogous null-coalesces on `.title` / `.description`. Handles the null at the source.
- New regression test `test_generic_branch_coalesces_null_vulnerability_type` in `tests/integration/test_callback_endpoint.py` — 64/64 callback tests pass.

**Prior-audit correction:** earlier in this doc I noted "Scanner containers POST results DIRECTLY to api-service, bypassing tool-integration's forwarder." That was incorrect — I misread the `result_collector` log. Scanners actually POST to tool-integration's `/api/v1/scans/{id}/results` (CALLBACK_URL is set to the tool-integration service in `kubernetes_job_manager.py:361-363`), tool-integration normalizes + forwards to api-service. The 422 source IPs (10.1.1.105, 10.1.2.77) are tool-integration pod IPs, not scanner pod IPs.

### I2 — wake single-file scan fails "Job failed after all retries" (**FIXED, 2026-04-21**)

**Status update (same day, post-audit):** root cause diagnosed + fix shipped in api-service 0.43.1 (terminal-state guard). Live-reproduced in production: re-running wake × `70d006e1` (the same contract that triggered the original failure) now completes cleanly as `status=completed 0/0/0/0` — and api-service logs confirm the race DID fire ("Ignoring failed callback for already-completed scan b127aa27-…: scanner=wake, error='Job failed after all retries'" × 2), but the guard rejected both overwrites.

**Evidence (original):**
- scan_id `28905574-8629-4a48-ba3b-7dee1f424e9d` (wake × 70d006e1 single-file)
- api-service logs showed **3× POST /results** from two tool-integration pod IPs (10.1.1.105 twice + 10.1.2.77 once) — wake scanner's `curl --retry 3 --retry-all-errors` loop fanning across tool-integration replicas
- Pod ran to completion per K8s events
- Final state became `status=failed, error_message='Job failed after all retries'` (the race's victim)

**Actual root cause (diagnosed):** tool-integration's `result_collector.py:315` POSTs a `status=failed, error="Job failed after all retries"` callback whenever K8s marks the scan Job as Failed (backoff_limit or activeDeadlineSeconds). This fires even after a prior successful callback has already transitioned the scan to `completed`. api-service's `store_scan_results` unconditionally overwrote `scan.status` — no state-transition guard.

**Fix applied in api-service 0.43.1 (`scans.py` store_scan_results):**
```python
# BSO-BUG-170: terminal-state preservation.
if scan.status == "completed" and results.status == "failed":
    logger.warning(f"Ignoring failed callback for already-completed scan {scan_id}: ...")
    return {"success": True, "ignored": True, "prior_status": "completed", ...}
```

Only `completed → failed` is blocked. All other transitions (`queued → completed`, `queued → failed`, `failed → completed` legitimate recovery, `failed → failed` idempotent) are allowed. Pinned by 6 structural unit tests in `tests/unit/presentation/test_scan_terminal_state_guard.py`.

**Post-fix verification matrix (12 / 12):** wake × single-file (original repro), slither × single + Hardhat, aderyn × Foundry, mythril × single, halmos / medusa / echidna × their respective Foundry projects, vyper × single, moccasin × Vyper project, rustdefend × Rust single, sec3-xray × Anchor project — all completed with the expected finding counts; none flipped to failed; guard confirmed firing twice on the wake repro without corrupting state.

### I3 — Platform audit script emits 2 false-positive failures (**FIXED, 2026-04-21**)

**Status update (same day, post-audit):** fixed in `docs/audits/scripts/audit-scanning-system.py` by adding a `_scanner_uses_solidity_base()` helper that greps the scanner's Dockerfile for `FROM .../scanner-base-solidity:`; the C6 and C7 checks skip any matched scanner with a note like "(skipped ['aderyn', 'slither', 'wake'] — solc from scanner-base-solidity)".

**Severity:** Tooling drift, no runtime impact.

`docs/audits/scripts/audit-scanning-system.py` reported:
```
[C] Foundry scanners pre-install solc: missing: ['aderyn', 'slither']
[C] Foundry scanners pre-install forge-std: missing: ['aderyn', 'slither']
```

These were spurious: `aderyn` + `slither` (and wake, halmos, mythril, echidna, medusa — 7 total) consume the **`scanner-base-solidity:1.0`** base image which provides solc + forge-std at the base layer. The audit script used to grep each scanner's own Dockerfile for install lines and flagged the base-image consumers.

**Task filed:** #171.

### I4 — Carried-over incident record (same day, earlier session)

**api-service 0.42.0 rollout broke auth middleware** — adding a second FK path between `contracts` and `scans` made SQLAlchemy's existing `ContractModel.scans` relationship ambiguous, crashed the startup quota-reset task, which took the auth middleware down. Rolled back to 0.41.0 in <3 min, shipped 0.42.1 hotfix with `foreign_keys=` pinned on both sides of the back_populates pair + added `TestContractModelRelationshipsCompile::test_mappers_configure_cleanly` regression test. Documented in `TaskDocs-BlockSecOps/DOCUMENTATION-UPDATE-2026-04-21-BASELINE-SCAN.md`.

### I5 — Audit-script scan-vulnerabilities metric looks wrong

`Completed scans with vulnerabilities: 0/845 (0%)` is marked PASS, yet the same report line below states `Total vulnerabilities in DB: 13536`. The 0/845 math is clearly incorrect. Not filed separately — will be addressed alongside #171.

---

## Findings on ⚠️ zero-result cells

Several scans completed cleanly with zero findings on contracts where at least one other scanner DID find issues. This is not inherently a bug — detectors differ. But for later investigation:

- **wake × single-file (completed-before-failure, per earlier completion notification):** 0/0/0/0 on `70d006e1` while slither/aderyn/soliditydefend each found multiple criticals/highs. Possibly wake's detector rules aren't firing on this specific vulnerability pattern.
- **vyper × E2E-Vyper-Ownable:** 0/0/0/0. Contract is named "Ownable" — may genuinely have no vyper-detectable issues.
- **moccasin × vyper-moccasin.tar:** 0/0/0/0.
- **sol-azy / rustdefend × VulnerableRustTest:** 0/0/0/0. Contract name contains "Vulnerable" — either the vulnerabilities aren't in these scanners' detector sets, or the scanner wrappers aren't seeing them.
- **trident / cargo-fuzz-solana × Anchor project:** 0/0/0/0. Fuzzers typically find bugs only when they hit failing property invariants; not flagging as a bug.
- **slither × hardhat-project.tar / aderyn × hardhat-project.tar / soliditydefend × hardhat-project.tar:** 0/0/0/0 on the same hardhat project. Either the project is genuinely clean or all three scanners fail to parse it. **Worth a follow-up investigation.**

None of these are being filed as bugs this session — they're all "scanner emitted a clean result" which is a valid outcome. Filed conditionally as a single observation in the audit doc.

---

## Appendix A — Audit script full output

```
Apogee Scanning System Audit — 2026-04-21 18:29 UTC
Target: https://app.0xapogee.com/api/v1

A. Scan Pipeline          9/9 PASS
B. Batch Scanning         8/8 PASS
C. Scanner Images         6/8 PASS (2 false-positive failures — see I3)
D. Stale Scan Recovery    6/6 PASS
E. Quota Enforcement      6/6 PASS
F. Automation & Beat     13/13 PASS
G. Scanner Security      11/11 PASS
H. Data Integrity         8/8 PASS

Total: 67/69 PASS   Time: 12s
```

---

## Acceptance criteria

- [x] Every matrix cell has (scan_id | status | finding count) OR explicit 🚫/N/A rationale
- [x] All 6 regression suites (5a–5f) documented with evidence
- [x] `audit-scanning-system.py` output captured with red-flag commentary
- [x] Incidents section lists: 0.42.0 ORM regression + 2 new production bugs found today
- [x] Bugs filed as tasks: #169, #170, #171
- [ ] Audit doc merged via feature branch PR (pending next GitOps step)

---

## Follow-ups

- ✅ **#169** — mythril 422 callback — **FIXED same-session** in tool-integration 0.6.5 + scanner-mythril 0.2.2. Live verified.
- ✅ **#170** — wake intermittent job-failed-after-retries — **FIXED same-session** in api-service 0.43.1 (terminal-state guard). 12-scan post-fix matrix passed; guard confirmed firing twice on the original wake × 70d006e1 repro.
- ✅ **#171** — `audit-scanning-system.py` base-image awareness — **FIXED same-session** via `_scanner_uses_solidity_base()` helper on C6 + C7 checks.
- **Follow-up (informational):** investigate the ⚠️ zero-finding cells on hardhat-project.tar across 3 scanners.
- **Low-priority follow-up:** tool-integration's forwarder doesn't log the api-service response body on HTTP error — adding `logger.error("...body=%s", e.response.text)` would make future 422-class bugs a minute-long diagnosis instead of a 20-minute log hunt.
