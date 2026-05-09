# Scanner Audit Changelog

**Status:** Active
**Last Updated:** 2026-05-09

Reverse-chronological log of every scanner status change, fix attempt, regression, and verification.
Each entry follows [Documentation Standards](../standards/documentation-standards.md) Change Summary format.

---

## 2026-05-09 — Pragma-gate UX: upstream gate + `failure_type` classification + dashboard rendering

**Scanner(s):** all 8 Solidity scanners (wake, slither, aderyn, halmos, mythril, echidna, medusa, soliditydefend) — wrapper-side gate now demoted to defensive backstop
**Author:** Apogee
**Services Affected:** blocksecops-api-service (image 0.43.10 → 0.43.11), blocksecops-tool-integration (source-only — no rebuild), blocksecops-dashboard (image → 0.53.4), database (Migration 090)

### What changed

**Block A — Upstream pragma gate (api-service).** `POST /api/v1/scans` now short-circuits before scanner-Job dispatch when `contract.compiler_version` is parseable but unsupported (< 0.8.12). Implemented in `src/presentation/api/v1/endpoints/scans.py` (create handler) using a new domain helper `src/domain/entities/solidity_version.py` (`MIN_SUPPORTED = (0, 8, 12)`, `MIN_TEXT = "0.8.12"`, `MIN_RELEASE_DATE = "2022-01-17"`). The endpoint creates a scan record with `status='failed'`, `failure_type='unsupported_solidity_version'`, and the canonical pragma-gate `error_message`. **No scanner Jobs are dispatched.** Synchronous response in <1 s vs ~2 min wrapper-based path.

**Migration 090.** New nullable `VARCHAR(50) failure_type` column on `scans` and `scanner_executions`. CHECK constraint enumerates `unsupported_solidity_version`, `compile_error`, `timeout`, `oom`, `internal_error`, `scanner_skipped`. Only `unsupported_solidity_version` is wired in v1; the rest are reserved for future blocks. Manual prod backup taken before alembic upgrade per `docs/standards/database-management.md`.

**Block C — Tool-integration backstop payload (source-only).** Both `scanner-images/_base/check-pragma` and `scanner-images/soliditydefend/check-pragma` now include `"failure_type": "unsupported_solidity_version"` in their failure callbacks. Image rebuilds remain deferred (batched into next routine rebuild) — the api-service `store_scan_results` classifier pattern-matches the canonical `error_message` text as a backup for callbacks that arrive without the structured field.

**Block D — Dashboard rendering.**
- `Scan` and `Contract` TypeScript interfaces extended with `error_message`, `failure_type`, `compiler_version`, `compiler_version_supported`, `min_supported_solidity_version`.
- New `ValidationNoticeBanner` component (`src/components/common/`) with dark-mode-aware amber palette (`bg-amber-50 dark:bg-amber-900/20 border-amber-200 dark:border-amber-800 text-amber-900 dark:text-amber-100`).
- `ScanResults.tsx` branches on `scan.failure_type === 'unsupported_solidity_version'` to render the yellow validation banner instead of the generic red "Scan Failed During Execution" panel.
- `ContractDetail.tsx` adds a Solidity version chip near the language/framework labels and the inline notice when `compiler_version_supported === false`.
- `ContractMetadataPanel.tsx` now reads from `contract.compiler_version` (was hardcoded mock `0.8.20`).
- `ContractsList.tsx` adds a default-visible **Compiler** column. `STORAGE_KEY` bumped to `contracts-visible-columns-v2` so existing localStorage snapshots fall through to defaults and users see the new column without manual toggling.
- Language filter dropdown trimmed from `LANGUAGES` to `TIER1_LANGUAGES` (Solidity, Vyper, Rust) — Tier 2/3 entries were aspirational placeholders that misled users.

### Why

User reported scan `88710862-db8e-4b51-817c-4748a238ee25` (contract `52fecf33-4d15-45f0-87b5-c228109d36f3`, `pragma solidity ^0.8.0`) rendering as a hard "Scan Failed During Execution" red banner. The scan was rejected by the wrapper-side `check-pragma` gate for an unsupported pragma — a user-actionable validation error, not a system failure. The platform had no structured signal to distinguish the two on the dashboard.

Moving enforcement upstream to scan creation also saves Spot-VM compute: every unsupported-version scan previously dispatched N scanner Jobs (N = scanner count), each pulling its image and running for ~10–30 s before the wrapper exited. Post-Block-A, zero Jobs are created.

### Verification (against the user-reported contract)

- `POST /api/v1/scans` with `contract_id=52fecf33-…` now returns synchronously in <1 s with `status: 'failed'`, `failure_type: 'unsupported_solidity_version'`.
- `kubectl get jobs -n tool-integration-prod` confirmed zero new scanner Jobs created.
- `GET /scans/{id}/executions` returns empty `executions: []`.
- `GET /contracts/{id}` returns `compiler_version: "0.8.0"`, `compiler_version_supported: false`, `min_supported_solidity_version: "0.8.12"`.
- Dashboard `/scans/{id}` renders the yellow `ValidationNoticeBanner` (not the red panel) with the canonical message and link to language-support docs.
- Dashboard `/contracts/{id}` shows the `Solidity v0.8.0` chip + the unsupported notice above the metadata panel.
- Dashboard `/contracts` shows the new **Compiler** column populated for each row.
- 17-scanner regression smoke against a supported contract confirmed no false-rejects.

### Files changed

**blocksecops-api-service (PR #367, image 0.43.11):**
- `alembic/versions/20260509_1450-090_add_failure_type_to_scans_and_executions.py` — NEW migration
- `src/domain/entities/solidity_version.py` — NEW domain helper (single source of truth)
- `src/infrastructure/database/models.py` — `failure_type` column on `ScanModel` + `ScannerExecutionModel`
- `src/presentation/schemas/scans.py` — `failure_type` on `ScanResults`, scan response, `ScannerExecution`
- `src/presentation/schemas/contracts.py` — `compiler_version_supported`, `min_supported_solidity_version`
- `src/presentation/api/v1/endpoints/scans.py` — upstream gate in create handler, backstop classifier in `store_scan_results`
- `src/presentation/api/v1/endpoints/contracts.py` — populate derived fields on list and detail
- `tests/regression/test_failure_type_classification.py` — NEW (28 tests)
- `pyproject.toml`, `k8s/overlays/gcp/kustomization.yaml` — version bump

**blocksecops-tool-integration (PR #177, source-only):**
- `scanner-images/_base/check-pragma`
- `scanner-images/soliditydefend/check-pragma`

**blocksecops-dashboard (image 0.53.4):**
- `src/lib/api/scans.ts`, `src/lib/api/contracts.ts` — type additions
- `src/components/common/ValidationNoticeBanner.tsx` — NEW
- `src/pages/ScanResults.tsx` — `failure_type` branching
- `src/pages/ContractDetail.tsx` — chip + notice
- `src/components/contract/ContractMetadataPanel.tsx` — wire real `compiler_version`
- `src/pages/ContractsList.tsx` — Compiler column + Tier 1 language filter

### Out of scope

- Image rebuilds for the 9 Solidity scanner images carrying the Block C backstop payload (still batched into next routine rebuild).
- Backfill of `compiler_version` for contracts uploaded before language detection populated the column — dashboard renders "detection pending" for those.
- Wiring `failure_type` for non-pragma rejections (`compile_error`, `oom`, `timeout`, `internal_error`) — column + enum exist; classifier wiring deferred.
- Backfilling `failure_type` to old failed scans — only new scans carry the structured field.

---

## 2026-05-08 — Block 7 R1 RBAC cleanup + R2 stale `production/` overlay removal

**Scanner(s):** none (infrastructure cleanup)
**Author:** Apogee
**Services Affected:** blocksecops-tool-integration (overlay removal + docs path fix); production GKE cluster (orphan RBAC deletion)

### What changed

**R1** — deleted two orphan cluster-scoped RBAC objects accidentally created during the audit on 2026-05-08 13:59 when `kubectl apply -k k8s/overlays/production/` was run against the prod cluster against my better judgment. Both were dangling — `ClusterRoleBinding` subject was a ServiceAccount in the non-existent-in-prod namespace `tool-integration-local`. No consumer pod referenced either object.

```bash
kubectl delete clusterrolebinding prod-tool-integration-cluster-reader
kubectl delete clusterrole prod-tool-integration-cluster-reader
```

**R2** — removed the stale `blocksecops-tool-integration/k8s/overlays/production/` overlay entirely. It was a pre-GCP-migration relic pinned to image `0.5.42` (current `0.6.30`), and applying it created the R1 orphans. Production GKE is deployed via `k8s/overlays/gcp/`; `production/` had no current consumer. The single doc reference (`docs/SCANNER-VERSION-MANAGEMENT.md:166`) was updated from `production/` → `gcp/`. No CI/CD or deployment-script references existed.

### Why

Pre-customer launch hygiene — orphan cluster-scoped RBAC objects are a security-audit finding, and stale overlays are a foot-gun that caused this exact incident. The `staging/` overlay is preserved (active staging deployments). Only `production/` was stale.

### Verification

- `kubectl get clusterrole,clusterrolebinding | grep prod-tool-integration` returns nothing.
- Org-wide grep for `overlays/production` shows the single doc reference was updated.
- The 17-scanner regression smoke from earlier today (post-Block 4 deploy) confirmed all scanners still operating normally — no dependency on the removed RBAC objects existed.

### Files changed

- **In-cluster:** `ClusterRole/prod-tool-integration-cluster-reader` and `ClusterRoleBinding/prod-tool-integration-cluster-reader` deleted.
- **blocksecops-tool-integration PR #176:**
  - `k8s/overlays/production/` directory removed (5 files: `kustomization.yaml`, `scanner-versions-patch.yaml`, `patches/{replica,resource,security}-patch.yaml`).
  - `docs/SCANNER-VERSION-MANAGEMENT.md:166` — prod path `production/` → `gcp/`.

### Plan reference

Plan: `/home/pwner/.claude/plans/gentle-whistling-russell.md` — Block 7 (R1 + R2 cleanup). **All 7 blocks of the plan are now shipped.**

---

## 2026-05-08 — Audit plan complete

**Plan:** `/home/pwner/.claude/plans/gentle-whistling-russell.md`
**Status:** ✅ All 7 blocks shipped
**Author:** Apogee

| Block | Subject | Status | Image bumps |
|---|---|---|---|
| 1 | solhint P0-2 severity mapping | ✅ shipped 2026-05-07 | `scanner-solhint:0.1.13 → 0.1.14` |
| 2 | mythril M2 (corrective) + M3 (multi-file gate) | ✅ shipped | `scanner-mythril:0.2.10 → 0.2.12` |
| 3 | wake P2-1 single-file perf | ✅ shipped (484s → 20s) | `scanner-wake:0.5.8 → 0.5.10` |
| 4 | P0-3 `scanner_executions` table + endpoint | ✅ shipped | `api-service:0.43.6 → 0.43.9`, `tool-integration:0.6.28 → 0.6.30` |
| 5 | P3-1 trident fixture `overflow-checks` | ✅ shipped (DB UPDATE) | none |
| 6 | UX batch P2-3, P2-4, P3-2 | ✅ shipped (P2-4 image rebuilds deferred) | `api-service:0.43.8 → 0.43.9` |
| 7 | R1 RBAC cleanup + R2 stale overlay removal | ✅ shipped | none |

### Final audit state (post-plan)

- `docs/scanners-audit/scanner-status.md` — all scanner rows reflect current production state. Mythril promoted from `⚠️ partial` to `✅ working`. Wake promoted from `✅ working (perf concern)` to `✅ working (perf fixed)`. Trident promoted from `✅ working (scanner) / ⚠️ fixture` to `✅ working`.
- `/scans/{id}/result-types` returns only types with non-zero rows (no more empty dashboard tabs).
- New `GET /api/v1/scans/{id}/executions` endpoint returns per-scanner observability rows.
- Pragma-gate rejection text now action-oriented with `help_url` (image rebuilds deferred to next routine update).
- New `blocksecops-docs/api/auth-jwt-refresh.md` page closes the JWT refresh-flow documentation gap.
- Production cluster is clean of orphan RBAC objects; stale `production/` overlay removed from the repo.

### Verification matrix

| Check | Result |
|---|---|
| 17-scanner regression smoke | 17/17 (post-block-5 trident fixture fix) |
| Mythril surfaces issues-found JSON correctly (Reentrancy.sol) | ✅ 2 findings (was 0 + `exit_1_check_pod_logs`) |
| Wake single-file perf | ✅ 20s (was 484s) |
| `GET /scans/{id}/executions` returns rows with `image_tag` | ✅ |
| `GET /scans/{id}/result-types` filters empty types | ✅ |
| Trident `overflow-checks` fixture | ✅ `status=completed` |
| Orphan RBAC objects | ✅ deleted |

### Memory rules pinned during the plan

- `feedback_methodical_not_reactive` — fix one scanner at a time, baseline-test, no pre-emptive fixes.
- `feedback_baseline_fixtures` — reuse same `contract_id`s as the last passing audit.
- `feedback_verify_against_standards` — read source-of-truth files in Stage A; discard fix candidates that contradict architecture.
- `feedback_autonomous_within_plan` — once a plan is approved, complete it autonomously without per-stage approval gates; only pause for scope-creep, unexpected state, judgment calls, or verification failures.

### Out of scope (intentionally not shipped this audit)

- Pre-emptive fixes for issues not surfaced in cluster verification.
- Refactoring beyond the minimal change for each fix.
- Detector-quality improvements (adding new detectors to scanners).
- New scanner integrations.
- Performance tuning beyond P2-1 (wake).

---

## 2026-05-08 — Block 6 UX batch (P2-3, P2-4, P3-2)

**Scanner(s):** all 17 (platform-level UX/observability)
**Author:** Apogee
**Services Affected:** blocksecops-api-service (P2-3 result-types filter), blocksecops-tool-integration (P2-4 pragma-gate text — source-only), blocksecops-docs (P3-2 JWT refresh-token doc)
**Image bumps:** `api-service:0.43.8 → 0.43.9` (P2-3)

### P2-3 — `/scans/{id}/result-types` filters to non-empty types

`/scans/{id}/result-types` previously returned all types from the static `SCANNER_RESULT_TYPE_MAP` based on which scanners were *requested*, regardless of whether the corresponding finding tables actually had rows. The dashboard was showing empty tabs (e.g., halmos requested → "Formal Verification" tab → empty because no `prove_*` invariants).

The fix runs a per-type EXISTS query against each finding table (`vulnerabilities`, `code_quality_findings`, `gas_analysis_findings`, `formal_verification_results`, `fuzzing_results`) and only returns types with at least one row. The static `SCANNER_RESULT_TYPE_MAP` lookup is dropped from `get_scan_result_types`.

**Verification:**

```
GET /scans/4f8cf80b-e42b-4c16-b87a-6f3459fef65f/result-types
→ ['fuzzing']  (trident scan with fuzzing rows)

GET /scans/77826ec8-a121-414b-84f6-d54c1744e35a/result-types
→ []           (mythril scan with 0 findings; was returning ['vulnerability'])
```

Source-level test: `tests/regression/test_result_types_p2_3.py` — 4/4 pass. Shipped via blocksecops-api-service PR #366 (image 0.43.9).

### P2-4 — Friendlier pragma-gate rejection message + help link (source-only)

User-flagged scan `1ae2f5d8-cba3-4f78-a570-1abb805be550` (scanners=[soliditydefend, slither] on a contract with `pragma solidity ^0.8.0;`) surfaced unfriendly rejection wording. Both check-pragma scripts (`scanner-images/_base/check-pragma` shared by 9 Solidity scanners + `scanner-images/soliditydefend/check-pragma` for soliditydefend's own variant) now emit a clearer, action-oriented message with an embedded link to `https://docs.0xapogee.com/language-support`. Both payloads gain a `help_url` field for clients that prefer structured links.

Status remains `failed` (not `completed`) — the scan was rejected at dispatch, and treating that as `completed` would mislead the dashboard's success-counter aggregation. The friendlier `error_message` + `help_url` is the right shape.

**Image rebuilds deferred** to the next routine scanner image rebuild — the change requires rebuilding `scanner-base-solidity` (used by 9 of 10 Solidity scanners) plus a fresh `scanner-soliditydefend` image. The current production message (since F1/2026-05-06) already mentions the actual version + min version + release date; the text-only sharpening + help link is a polish improvement, not a regression fix.

Shipped via blocksecops-tool-integration PR #175.

### P3-2 — JWT auth + refresh-token flow doc

Closes the documentation gap flagged in the audit ("undocumented JWT refresh-token flow makes SDK consumers reverse-engineer the auth from the dashboard source"). New `blocksecops-docs/api/auth-jwt-refresh.md` covers:

- Endpoint URLs + required headers (apikey + Content-Type)
- Password-grant initial sign-in
- Calling Apogee `/api/v1/*` endpoints with Bearer + apikey
- Refresh-grant proactive renewal pattern (refresh when `expires_at - now < 60s`)
- Refresh-token rotation behavior
- Python + TypeScript auto-refresh wrappers (copy-paste ready)
- Sign-out
- Troubleshooting matrix

Cross-linked to existing `api-key.md`, `rate-limits.md`, `sdk-overview.md`. Shipped via blocksecops-docs PR #185.

### Plan reference

Plan: `/home/pwner/.claude/plans/gentle-whistling-russell.md` — Block 6 (UX batch P2-3, P2-4, P3-2).

---

## 2026-05-08 — trident P3-1 fixture overflow-checks fix

**Scanner(s):** trident (fixture-data fix; no scanner code change)
**Author:** Apogee
**Services Affected:** none (DB UPDATE on `contract_files` table only)

### What changed

The audit baseline fixture `86096252-b524-4ee1-beb6-4c3539627b3c` (E2E-Rust-anchor-basic1-tree) ships a workspace `Cargo.toml` that contains only:

```toml
[workspace]
members = [
  "programs/*"
]
```

Trident's underlying `anchor build` requires `[profile.release] overflow-checks = true` for security-critical builds, so every smoke run produced `status: failed, error: "Anchor build failed (exit 1): Error: overflow-checks is not enabled in the release profile..."`. The F1 trident scanner fix from 2026-05-06 (image 0.4.3) was correct — it surfaced the build failure in `error_message` cleanly — but the fixture itself was the broken party.

Per `docs/standards/database-management.md`, applied a SQL UPDATE inside `BEGIN; ... COMMIT;` against `contract_files`:

```sql
UPDATE contract_files
SET file_content = '[workspace]
members = [
  "programs/*"
]

[profile.release]
overflow-checks = true
'
WHERE contract_id = '86096252-b524-4ee1-beb6-4c3539627b3c'
  AND file_path = 'Cargo.toml';
```

`file_size` was also updated to match the new content length (83 bytes).

### Why

Trident has been the only persistent failure on every 17-scanner regression smoke run since 2026-05-06. With the fixture fixed, smoke goes from 16/17 to a clean 17/17.

### Verification

**Pre-update backup** confirmed: `postgresql-backup-pre-p3-1-1778284750` Job uploaded 74.7 MiB to `gs://apogee-production-db-backups/postgresql/`.

**Pre-fix state** (last smoke before this entry):

```
trident: status=failed err='Anchor build failed (exit 1): Error: `overflow-che...'
```

**Post-fix verification** scan `4f8cf80b-e42b-4c16-b87a-6f3459fef65f`:

```
[poll t=   0s] status=queued
[poll t=   8s] status=completed crit=0 high=0 med=0 low=0
final: completed
```

**P0-3 endpoint** corroboration:

```json
{
  "scanner_id": "trident",
  "status": "completed",
  "image_tag": "scanner-trident:0.4.3",
  "error_message": null,
  ...
}
```

(was `error_message: "Anchor build failed..."` before the fixture fix)

### Files changed

- DB-only: `contract_files` row for `(contract_id=86096252-..., file_path='Cargo.toml')` — `file_content` + `file_size` updated.
- `docs/scanners-audit/scanner-status.md` — trident row promoted from `✅ working (scanner) / ⚠️ fixture` to `✅ working`.

### Rollback plan

```sql
UPDATE contract_files
SET file_content = '[workspace]
members = [
  "programs/*"
]
'
WHERE contract_id = '86096252-b524-4ee1-beb6-4c3539627b3c'
  AND file_path = 'Cargo.toml';
```

Or restore from `postgresql-backup-pre-p3-1-1778284750` if needed.

### Plan reference

Plan: `/home/pwner/.claude/plans/gentle-whistling-russell.md` — Block 5 (P3-1 trident fixture).

---

## 2026-05-08 — P0-3 per-scanner execution observability (`scanner_executions` table + endpoint)

**Scanner(s):** all 17 (platform-level observability)
**Author:** Apogee
**Services Affected:** blocksecops-api-service (Migration 089; ScannerExecutionModel; ScanResults schema; new GET endpoint), blocksecops-tool-integration (callback payload enrichment)
**Image bumps:** `api-service:0.43.6 → 0.43.8`, `tool-integration:0.6.28 → 0.6.30`
**Pushed to:** `us-west1-docker.pkg.dev/.../api-service:0.43.8` digest `sha256:8d569e23...`, `us-west1-docker.pkg.dev/.../tool-integration:0.6.30` digest `sha256:6008793d...`

### What changed

The mythril 0.2.9 issues-found regression silently discarded findings for ~2 weeks (since approximately 2026-04-29) because the dashboard collapsed 17-scanner detail into one scan-level `status` + `error_message` field. Operators had no way to answer "for scan X, which scanner failed and why?" without pulling K8s pod logs (TTL'd at 1h by the Job controller).

P0-3 adds a `scanner_executions` table with one row per scanner Job dispatched for a scan, plus a new endpoint `GET /api/v1/scans/{scan_id}/executions`. The columns:

| Column | Notes |
|---|---|
| `id` | BIGINT PK |
| `scan_id` | UUID FK → `scans.id` ON DELETE CASCADE |
| `scanner_id` | matches `scanner_versions.scanner_name` |
| `status` | CHECK queued/running/completed/failed/skipped/timeout |
| `started_at` / `completed_at` | TIMESTAMPTZ; null while not yet started/completed |
| `exit_code` | INT (0/124/137/etc.); v1 leaves null for wrapper-native callbacks |
| `error_message` | per-scanner mirror of `scan.error_message` |
| `duration_seconds` | INT (precomputed); v1 leaves null for wrapper-native callbacks |
| `image_tag` | e.g., `scanner-mythril:0.2.12` (sourced from tool-integration env) |
| `created_at` / `updated_at` | TIMESTAMPTZ |

Constraints: `uq_scanner_executions_scan_scanner UNIQUE(scan_id, scanner_id)`, `valid_scanner_execution_status` CHECK on the 6-value status enum. Indexes on `scan_id` and `(scan_id, scanner_id)`.

`store_scan_results` upserts a row in `scanner_executions` BEFORE the BSO-BUG-170 terminal-state-preservation gates. Wrapped in `db.begin_nested()` so an upsert failure (transient FK conflict, or the table-not-yet-migrated edge case during the 0.43.7→0.43.8 rollout) doesn't taint the outer session and break vulnerability persistence.

`tool-integration` enriches the callback payload at two points: `forward_to_api()` (skip-gate synthetic callbacks) and 8 inline `scan_results = {...}` dict literals (wrapper-native callbacks). For v1 only `image_tag` (env lookup) and `completed_at` (server now-ish) are populated; `started_at`, `exit_code`, `duration_seconds` require a K8s Job status lookup deferred to a follow-up.

### Why

Customer-facing impact: per-scanner failures were rolling up into a generic scan-level status. The mythril 0.2.9 regression wasn't caught for ~2 weeks. The new endpoint gives operators a queryable "which scanner did what, and when" view.

### Verification

**Pre-migration backup** confirmed: `postgresql-backup-pre-089-1778282289` Job uploaded 9 files / 74.7 MiB to `gs://apogee-production-db-backups/postgresql/` including a fresh `postgresql-20260508-231821.sql.gz` snapshot.

**Migration applied**: alembic at `089 (head)` in prod. The table was auto-created by api-service startup (`Base.metadata.create_all`) before alembic ran, so `alembic stamp 089` was used to align history with the actual schema. Schema verified via `\d scanner_executions` against prod DB: all 12 columns, all 4 indexes, FK ON DELETE CASCADE, status CHECK constraint present.

**End-to-end** mythril scan against contract `eafe2b12` (scan `77826ec8-a121-414b-84f6-d54c1744e35a`):

```
GET /api/v1/scans/77826ec8-a121-414b-84f6-d54c1744e35a/executions
HTTP 200
{
  "scan_id": "77826ec8-...",
  "requested_scanners": ["mythril"],
  "executions": [
    {
      "scanner_id": "mythril",
      "status": "completed",
      "completed_at": "2026-05-08T23:47:02.768878Z",
      "image_tag": "scanner-mythril:0.2.12",
      ...
    }
  ]
}
```

**17-scanner regression smoke**: 16/17 pass; only the pre-existing P3-1 trident fixture failure (block 5 on the audit plan).

**Source-level tests**: 24/24 unit tests pass in api-service (`tests/regression/test_scanner_executions_p0_3.py` — pinning migration shape, model definition, schema additions, upsert ordering, endpoint wiring).

### Files changed

**blocksecops-api-service** (PR #365):
- `alembic/versions/20260508_2330-089_add_scanner_executions_table.py` — additive migration.
- `src/infrastructure/database/models.py` — `ScannerExecutionModel` + `ScanModel.scanner_executions` relationship.
- `src/presentation/schemas/scans.py` — `ScanResults` Optional fields; `ScannerExecution` + `ScanExecutionsResponse`.
- `src/presentation/api/v1/endpoints/scans.py` — new GET endpoint; savepoint-protected upsert.
- `tests/regression/test_scanner_executions_p0_3.py` — 24 tests.
- `pyproject.toml` + `k8s/overlays/gcp/kustomization.yaml` — version 0.43.6 → 0.43.8.

**blocksecops-tool-integration** (PR #174):
- `src/main.py` — `_scanner_image_tag()` helper; enrichment in `forward_to_api()` + 8 inline `scan_results` dicts.
- `pyproject.toml` + `k8s/overlays/gcp/kustomization.yaml` — version 0.6.28 → 0.6.30.

### Rollback plan

Migration 089 is additive (new table only). Rollback path: `alembic downgrade 088` drops the table. Service rollback: revert deployment image tags to api-service:0.43.6 and tool-integration:0.6.28; old code ignores the new fields.

### Plan reference

Plan: `/home/pwner/.claude/plans/gentle-whistling-russell.md` — Block 4 (P0-3 scanner_executions table + endpoint).

---

## 2026-05-08 — wake P2-1 single-file perf fix

**Scanner(s):** wake
**Author:** Apogee
**Services Affected:** blocksecops-tool-integration (scanner-wake image; ConfigMap; KJM default_images; regression test)
**Image bump:** `scanner-wake:0.5.8 → 0.5.10` (0.5.9 was an intermediate buggy ordering — see note)
**Pushed to:** `us-west1-docker.pkg.dev/project-8a2657b9-d96c-4c0a-a69/apogee/scanner-wake:0.5.10` digest `sha256:baf7667a...`

### What changed

In-cluster diagnostic (wake-debug-init Job, this date) showed `wake init --force` itself eagerly fetches solc-list metadata from `https://binaries.soliditylang.org/linux-amd64/list.json` AND `https://raw.githubusercontent.com/.../list.json` via wake's SVM module **before** producing `wake.toml`. Both requests are blocked by the scanner NetworkPolicy egress rule and time out after ~10s each with multiple retries — the dominant contributor to the ~480s single-file scan latency.

The 0.5.8 fix (writing `wake.toml` with `target_version = $SOLC_VERSION`) was correct, but the write was gated on `grep -rqE @openzeppelin/contracts/` in two branches (Foundry+OZ at line ~199 and Hardhat-converted-Foundry at line ~268). Single-file scans, plain multi-file scans, and OZ-free Foundry/Hardhat projects fell through to the bare `wake init --force` path and triggered the network fetch in wake init itself.

`scanner-images/wake/wake-scan` now writes a minimal `wake.toml` with `target_version` **before** the `wake init --force` invocation:

```bash
if [ ! -f wake.toml ]; then
    cat > wake.toml <<EOF
[compiler.solc]
target_version = "${SOLC_VERSION:-0.8.20}"
EOF
elif ! grep -q "^target_version" wake.toml 2>/dev/null; then
    if grep -q '^\[compiler\.solc\]' wake.toml 2>/dev/null; then
        sed -i "/^\[compiler\.solc\]/a target_version = \"${SOLC_VERSION:-0.8.20}\"" wake.toml
    else
        cat >> wake.toml <<EOF

[compiler.solc]
target_version = "${SOLC_VERSION:-0.8.20}"
EOF
    fi
fi

# Initialize Wake project if not already initialized
if [ ! -f "wake.toml" ]; then
    echo "Initializing Wake project..."
    wake init --force 2>/dev/null || true
fi
```

`wake init --force`'s `[ ! -f wake.toml ]` gate now short-circuits because the unconditional block always leaves a wake.toml in place, eliminating the network fetch entirely.

> **Note on 0.5.9:** an intermediate image was pushed where the unconditional block was placed *after* `wake init --force` rather than before — so the network fetch still fired. 0.5.9 was deployed and a verification scan ran for ~368s (still slow). 0.5.10 corrects the ordering. The 0.5.9 image remains in the registry (immutable tags) but is no longer referenced by any ConfigMap or KJM default.

### Why

Customer-facing impact: every single-file Solidity scan, plain multi-file scan, and OZ-free Foundry/Hardhat scan with wake was waiting ~484s while wake init's `aiohttp` calls timed out under the scanner NetworkPolicy. Findings still surfaced eventually, but the user-experienced delay was unacceptable for a single-file lint.

### Verification

**In-cluster wake-debug-init Job (image 0.5.9 — proves the network fetch fires inside wake init, before wake.toml is created):**

```
=== running wake init --force ===
[23:01:37] Found 10 *.sol files in 0.00 s
           Failed to load previous build artifacts
WARNING ... wake.svm.svm: Failed to download solc list from
         https://binaries.soliditylang.org/linux-amd64/list.json: <urlopen error timed out>
WARNING ... wake.svm.svm: Failed to download solc list from
         https://raw.githubusercontent.com/.../list.json: <urlopen error timed out>
=== wake.toml after init === [empty]
```

**API end-to-end on Reentrancy.sol single-file (contract `7b72c90b`, image 0.5.10):**

```
[poll t=   0s] status=queued
[poll t=  16s] status=completed crit=0 high=1 med=0 low=0
final: completed   wall_seconds=20
```

20s wall-clock end-to-end (was ~484s) — >95% latency reduction. 1 high finding surfaced.

**17-scanner regression smoke:** 16/17 completed; only the pre-existing P3-1 trident fixture failure remains (block 5 on the audit plan).

### Files changed

- `blocksecops-tool-integration/scanner-images/wake/wake-scan` — unconditional `wake.toml` + `target_version` write moved BEFORE `wake init --force`.
- `blocksecops-tool-integration/scanner-images/wake/Dockerfile` — `ARG SCANNER_IMAGE_VERSION=0.5.10`.
- `blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml` — `SCANNER_IMAGE_WAKE: "scanner-wake:0.5.10"` + updated `_note`.
- `blocksecops-tool-integration/src/scanners/kubernetes_job_manager.py` — `default_images['wake'] = "scanner-wake:0.5.10"`.
- `blocksecops-tool-integration/tests/regression/test_wake_p2_1.py` — new `TestWakeP21UnconditionalTargetVersion` (4 tests asserting the unconditional block precedes `wake init --force`) + `TestWakeImageVersionSync` (3 tests). 7/7 unit tests pass.

### Rollback plan

Revert `SCANNER_IMAGE_WAKE` in the ConfigMap to `scanner-wake:0.5.8` and `kubectl apply -k k8s/overlays/gcp/`. The 0.5.8 image is still pushed and pullable. This restores the (slow) baseline behavior without affecting correctness — only perf regresses.

### Plan reference

Plan: `/home/pwner/.claude/plans/gentle-whistling-russell.md` — Block 3 (wake P2-1 single-file perf).

---

## 2026-05-08 — mythril P0-2 corrective M2 (issues-found regression fix)

**Scanner(s):** mythril
**Author:** Apogee
**Services Affected:** blocksecops-tool-integration (scanner-mythril image; ConfigMap; KJM default_images; regression test)
**Image bump:** `scanner-mythril:0.2.11 → 0.2.12`
**Pushed to:** `us-west1-docker.pkg.dev/project-8a2657b9-d96c-4c0a-a69/apogee/scanner-mythril:0.2.12` digest `sha256:d02b1590...`

### What changed

Corrective fix on top of 0.2.11's M2 stderr-pattern refinement. The original M2 had been solving the wrong problem: an in-cluster diagnostic (mythril-debug-stderr Job, this date) showed mythril 0.24.8 exits code **1 on issues-found** per upstream CI convention, while still emitting valid JSON `{"error": null, "issues": [...]}` and **empty** stderr. The Task #182 bucketing introduced in image 0.2.9 (commit bc73fb4) treated all `MYTH_EXIT==1` as failure and discarded the JSON, so since approximately 2026-04-29 every successful issues-found scan was silently reported as `failed: 0 findings, exit_1_check_pod_logs` and the dashboard hid real findings.

`scanner-images/mythril/run-mythril.sh` exit-1 branch now inspects `$MYTHRIL_RAW` first:

```diff
elif [ $MYTH_EXIT -eq 1 ]; then
+    if [ -s "$MYTHRIL_RAW" ] && jq -e '.error == null and (.issues | type == "array")' "$MYTHRIL_RAW" >/dev/null 2>&1; then
+        : # case (a) — exit-1-on-issues-found; fall through to JSON parsing
+        echo "  Note: Mythril exited 1 on $sol_file but produced valid issues-found JSON ..."
+    elif [ -s "$MYTHRIL_RAW" ] && jq -e '.success == false' "$MYTHRIL_RAW" >/dev/null 2>&1; then
+        FILE_FAIL_REASON=$(jq -r '"compile:" + (.error // "unknown" | gsub("\n"; " ") | .[:120])' "$MYTHRIL_RAW" 2>/dev/null || echo "compile:unknown")
+    elif grep -qE 'z3\.|Z3Exception|SMT' /tmp/mythril-stderr.log 2>/dev/null; then
        FILE_FAIL_REASON="z3_solver_crash"
    elif grep -qE 'Traceback|RuntimeError|...' /tmp/mythril-stderr.log 2>/dev/null; then
        ...
```

The 0.2.11 stderr-pattern matching becomes a fallback only when the JSON is missing/invalid/error-shaped. The pre-existing `success == false` compile-error path (line 311 in 0.2.10/0.2.11) is folded into the new exit-1 ladder so compile errors are surfaced with their actual error text.

### Why

Customer-facing impact: every contract that mythril successfully analyzed and **found a vulnerability** since image 0.2.9 was being reported in the dashboard as `0 findings, status=failed, error_message="exit_1_check_pod_logs"`. Real reentrancy / TOD findings were being thrown away.

### Verification

**In-cluster Reentrancy debug Job (mythril-debug-stderr-v12):**

```
Analyzing: /contracts/contract.sol
  Exit code: 1
  Raw output size: 8194 bytes
  Stderr:
  Note: Mythril exited 1 on /contracts/contract.sol but produced valid issues-found JSON (upstream CI convention) — treating as success
  Found 2 issues
Status: completed
Total issues: 2
  Medium: 1  Low: 1
```

The 2 surfaced findings: External Call To User-Supplied Address (low, line 14) + Transaction Order Dependence (medium, line 14) — both legitimate reentrancy-related findings on the test contract.

**Multi-file (M3) re-verification:** in-cluster Job with `Token.sol` + `utils_Context.sol` (flattened upload simulation) entered the multi-file block (`SOL_FILE_COUNT=2 > 1`), reconstructed `utils_Context.sol → utils/Context.sol`, synthesized the permissive foundry.toml, and analyzed both files at exit 0. M3 confirmed working in-cluster.

**API end-to-end:** `POST /scans` against multi-file Foundry+OZ baseline `eafe2b12` returned `status=completed` (scan_id `81cb6b5d-9301-47b1-954a-f61df051afcb`).

**17-scanner regression smoke:** 16 of 17 scanners completed normally against their baselines. The only failure was the pre-existing P3-1 trident fixture issue (`overflow-checks` not enabled in workspace `Cargo.toml` of `86096252`) — already on the plan as block 5; not caused by this rollout.

### Files changed

- `blocksecops-tool-integration/scanner-images/mythril/run-mythril.sh` — exit-1 branch now JSON-success-aware (lines ~286-313).
- `blocksecops-tool-integration/scanner-images/mythril/Dockerfile` — `ARG SCANNER_IMAGE_VERSION=0.2.12`.
- `blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml` — `SCANNER_IMAGE_MYTHRIL: "scanner-mythril:0.2.12"` + updated `_note` describing the 0.2.9 regression and the corrective fix.
- `blocksecops-tool-integration/src/scanners/kubernetes_job_manager.py` — `default_images['mythril'] = "scanner-mythril:0.2.12"`.
- `blocksecops-tool-integration/tests/regression/test_mythril_m2_m3.py` — new `TestMythrilM2ExitOneIssuesFoundSuccess` class (2 tests) asserting the exit-1 branch inspects `$MYTHRIL_RAW` first and the JSON-success arm does not set `FILE_FAIL_REASON`. Image-version assertions bumped to `0.2.12`. 10 of 10 unit tests pass.

### Rollback plan

Revert `SCANNER_IMAGE_MYTHRIL` in the ConfigMap to `scanner-mythril:0.2.11` and `kubectl apply -k k8s/overlays/gcp/`. The 0.2.11 image is still pushed and pullable. This restores the (broken) issues-found behavior but unblocks if any unforeseen regression emerges.

### Plan reference

Plan: `/home/pwner/.claude/plans/gentle-whistling-russell.md` — Block 2 (mythril M2 corrective). M3 marked verified in-cluster; M2 corrective replaces the 0.2.11 stderr-pattern attempt.

---

## 2026-05-07 — solhint P0-2 fix deployed

**Scanner(s):** solhint
**Author:** Apogee
**Services Affected:** blocksecops-tool-integration (scanner-solhint image; ConfigMap; KJM default_images)
**Image bump:** `scanner-solhint:0.1.13 → 0.1.14`
**Pushed to:** `us-west1-docker.pkg.dev/project-8a2657b9-d96c-4c0a-a69/apogee/scanner-solhint:0.1.14` digest `sha256:bcc15219...`

### What changed

The solhint wrapper's jq severity mapping at `scanner-images/solhint/solhint-scan` lines 197-201 was treating linter style/gas/best-practice rules as if they were security findings:

```diff
-if .severity == 2 or "error" then "CRITICAL"
-elif .severity == 1 or "warning" then "HIGH"
-else "MEDIUM"
+if .severity == 2 or "error" then "MEDIUM"
+elif .severity == 1 or "warning" then "LOW"
+else "LOW"
```

Plus version sync across `Dockerfile` (`ARG SCANNER_IMAGE_VERSION`), `k8s/base/scanner-versions-configmap.yaml` (`SCANNER_IMAGE_SOLHINT` + `SCANNER_METADATA.solhint._note`), and `src/scanners/kubernetes_job_manager.py` (`default_images['solhint']`). New regression test: `tests/regression/test_solhint_severity_map.py` (6 tests, guards both the jq mapping and the version sync).

### Why

Solhint is a linter — its rule set is style/gas/NatSpec/naming, not security. The wrapper's old mapping put 26 of 26 findings on a textbook reentrancy contract into the `high` severity bucket alongside actual reentrancy detections from real security scanners. Customers see "16 high severity issues" on a vanilla OZ project and either panic or lose trust in the platform.

### Verification (Stage D, 2026-05-07)

Re-ran solhint × 6 contract structures via end-user API (`jasonbrailowbizop@mail.com`):

| Structure | contract_id | scan_id | Pre-fix counts (c/h/m/l) | Post-fix counts | Verdict |
|---|---|---|---|---|---|
| single | `7b72c90b` (Reentrancy) | `563910da-1939-4d6a-ac1b-524abc24dc71` | 0/26/0/0 | 0/0/0/26 | ✅ all linter findings now low |
| proxy | `31b6ac0b` | `b041e883-94c6-46af-ae8d-b14ac4ec1bec` | 0/0/0/0 | 0/0/0/0 | ✅ unchanged (no findings) |
| upgradeable | `12fbb2d3` | `044f3ec8-2bdf-479c-8d56-cd10914046de` | 0/0/0/0 | 0/0/0/0 | ✅ unchanged |
| project (foundry) | `eafe2b12` | `5481399b-c276-4dff-99da-cdcac62c67b9` | 0/16/0/0 | 0/0/0/16 | ✅ |
| project (hardhat) | `0c7542c6` | `ae17b8ec-7022-43bd-ae46-2e9a17dc4505` | 0/16/0/0 | 0/0/0/16 | ✅ |
| project (plain multi-file) | `24b7de7b` | `d312ade5-e261-4662-b030-8872e7ac87c6` | 0/0/0/0 | 0/0/0/0 | ✅ unchanged |

Total finding counts unchanged (26, 16, 16); only severity bucket shifted high → low.

### Deployment record

- `kubectl apply -k k8s/overlays/gcp/` against `gke_project-8a2657b9-d96c-4c0a-a69_us-west1_apogee-production-gke` — ConfigMap `scanner-versions/scanner-solhint` updated `:0.1.13 → :0.1.14`.
- `kubectl rollout restart deployment/tool-integration -n tool-integration-prod` — successfully rolled out.
- 33/33 unit + regression tests pass locally before push.

### Issues observed (separate from solhint)

- **Stale `production` overlay**: `k8s/overlays/production/` references a non-existent namespace `blocksecops` (live deployment is in `tool-integration-prod` via the `gcp` overlay). Earlier accidental `kubectl apply -k k8s/overlays/production/` created two orphan cluster-scoped resources (`prod-tool-integration-cluster-reader` ClusterRole + ClusterRoleBinding) before erroring on the namespace mismatch. **Follow-up**: either delete the stale `production/` overlay directory or align it with the live cluster. The two orphan RBAC objects should be cleaned up: `kubectl delete clusterrole/prod-tool-integration-cluster-reader clusterrolebinding/prod-tool-integration-cluster-reader`.

### Status

verified

---

## 2026-05-06 — P0-1 "count/listing mismatch" — false alarm correction

**Scanner(s):** slither, semgrep, aderyn, solhint, soliditydefend, sol-azy, sec3-xray
**Author:** Apogee
**Services Affected:** none (no platform bug after all)

### What changed

Earlier 2026-05-06 verification entries flagged a "multi-file count/listing API discrepancy" as an open issue across multiple scanners — symptom: scan record's `*_count` fields populated, but `/scans/{id}/vulnerabilities` returned 0 items. Direct API confirmation against scan `9adc0acd-db93-4e43-8338-9c8401549812` (slither on `eafe2b12`):

- `GET /scans/{scan_id}/vulnerabilities?limit=100` → `total: 0`
- `GET /scans/{scan_id}/vulnerabilities?limit=100&include_duplicates=true` → `total: 6` (matches `*_count` fields exactly)

### Root cause

The `/vulnerabilities` endpoint at `blocksecops-api-service/src/presentation/api/v1/endpoints/scans.py:2032-2036` defaults to filtering `WHERE is_primary == True`, hiding cross-scan duplicates. Contracts `eafe2b12` and `0c7542c6` have been scanned many times in prior audit cycles, so the platform's deduplication processor marks every new finding for them as `is_primary=False` (canonical lives in the first scan that found it). The scan-record `*_count` fields, however, count *all* findings created (primary + duplicate). So a re-scan of an already-scanned contract produces non-zero counts but a default-filtered listing of 0.

The dashboard correctly passes `include_duplicates=true` per the docstring at scans.py:2103-2108 ("Mirrors the flag on /vulnerabilities so the breakdown counts match the list when the dashboard asks for all findings"). My audit harness called the default and was misled.

### Verdict

**Not a platform bug.** Customers using the dashboard see findings correctly. The default-`is_primary-only` behavior on the API endpoint is a design choice. Scanner-status open-issues column updated to remove the spurious "count/listing discrepancy" notes from slither, semgrep, aderyn, soliditydefend, sol-azy, sec3-xray rows.

### Optional UX consideration (not a fix)

Considering demoting the API default of `/scans/{id}/vulnerabilities` to `include_duplicates=true` since "show me findings for this scan" is more intuitive than "show me only findings unique to this scan." Tracked as P2-5 in the fix plan, not a launch-blocker.

### Status

verified — false alarm

---

## 2026-05-06 — `cargo-fuzz-solana` verification

**Scanner(s):** cargo-fuzz-solana
**Author:** Apogee
**Image version:** `scanner-cargo-fuzz-solana:0.4.3` / upstream `0.13.1`

| Structure | contract_id | scan_id | status | counts |
|---|---|---|---|---|
| project (anchor) | `86096252` | `6216f18b-416c-4146-a190-c6757508b897` | ✅ | 0 (matches baseline) |

✅ **working** — promoted from ⚠️. Runs cleanly in 57 s; legitimate-zero (fixture has no `fuzz_targets/`). F2 fix from 2026-05-06 (workspace Cargo.toml detection at depth ≤3) is implicitly verified by the scan completing without the previous "Not a Rust project" error. Verifying actual fuzzer execution requires a fixture with explicit fuzz harnesses.

**Status:** verified

---

## 2026-05-06 — `trident` verification

**Scanner(s):** trident
**Author:** Apogee
**Image version:** `scanner-trident:0.4.3` / upstream `0.12.0`

| Structure | contract_id | scan_id | status | error_message |
|---|---|---|---|---|
| project (anchor) | `86096252` | `20bc2443-33bf-4bd9-90c7-ba3b22b65c19` | ❌ failed (data) | `Anchor build failed (exit 1): \`overflow-checks\` is not enabled. To enable, add: [profile.release] overflow-checks = true in workspace root Cargo.toml` |

✅ **scanner working** — promoted from ⚠️. F1 fix from 2026-05-06 (capture anchor build stdout/stderr to error_message) is verified end-to-end and surpasses the F1 doc's claimed verification (which only said "Anchor build failed"). The new error_message includes the specific cargo failure with the exact remediation step.

**Fixture issue (separate)**: `86096252` (E2E-Rust-anchor-basic1-tree) lacks `[profile.release] overflow-checks = true` in its workspace Cargo.toml — Anchor 0.30+ requires this. Not a scanner bug; the fixture itself needs updating.

**Status:** verified

---

## 2026-05-06 — `sec3-xray` verification

**Scanner(s):** sec3-xray
**Author:** Apogee
**Image version:** `scanner-sec3-xray:0.4.1` / upstream `0.0.6`

| Structure | contract_id | scan_id | counts | vulns_total |
|---|---|---|---|---|
| project (anchor) | `86096252` (E2E-Rust-anchor-basic1-tree) | `7489745c-88cd-4309-a928-ae1cb988d27d` | 0/4/0/0 | 1 |

✅ **working** — promoted from ⚠️. Produces 4 high findings on the canonical Anchor baseline (vs 2 high in 2026-05-04 baseline). Likely improved detector coverage since baseline; the 2 vs 4 delta is a detection-quality observation, not a regression.

**Status:** verified

---

## 2026-05-06 — `sol-azy` verification

**Scanner(s):** sol-azy
**Author:** Apogee
**Image version:** `scanner-sol-azy:0.5.1` / upstream `0.4.1`

| Structure | contract_id | scan_id | counts | vulns_total |
|---|---|---|---|---|
| single | `7b536063` (E2E-Rust-anchor-lib-blob) | `047b6fda-c08d-4bdc-a50d-642df727b949` | 0/0/0/1 | 0 |
| project (anchor) | `86096252` (E2E-Rust-anchor-basic1-tree) | `b9a53e8b-80d4-46a9-9def-6d83f8e7c739` | 0/0/0/1 | 0 |

✅ **working** — promoted from ⚠️. Both scans produce 1 low finding (count fields). Anchor project matches 2026-05-04 baseline (1 low). Same multi-file count/listing discrepancy as Solidity scanners (counts populated, `/vulnerabilities` returns 0).

**Status:** verified

---

## 2026-05-06 — `moccasin` verification

**Scanner(s):** moccasin
**Author:** Apogee
**Image version:** `scanner-moccasin:0.3.4` / upstream `0.4.3`

| Structure | contract_id | scan_id | status | counts |
|---|---|---|---|---|
| project (vyper multi-file) | `a355b720` (E2E-Vyper-tokens-tree) | `b1bfaf8c-bd67-48a8-8ec3-a69e0789ecad` | ✅ | 0 (matches 2026-05-04 baseline) |

✅ **working** — promoted from ⚠️. Earlier inconclusive verdict (audit snapshot 2026-05-06) was due to framework misdetection on a throwaway Mox scaffold; baseline fixture `a355b720` runs cleanly. The framework-detector gap on minimal scaffolds is a separate concern but doesn't affect canonical Vyper project structures.

**Status:** verified

---

## 2026-05-06 — `medusa` verification

**Scanner(s):** medusa
**Author:** Apogee
**Image version:** `scanner-medusa:0.4.5` / upstream `1.5.0`

| Structure | contract_id | scan_id | status | counts | fuzzing rows |
|---|---|---|---|---|---|
| project (foundry) | `eafe2b12` | `5519a6d0-3b28-4903-9780-8ed77f657bfc` | ✅ | 0 | 1 |
| project (hardhat) | `0c7542c6` | `8b29f16f-0c9f-4370-8e69-8ec380b7a413` | ✅ | 0 | 1 |
| project (plain) | `24b7de7b` | `b7b1b856-4c70-4a57-b9b2-cb067fd92119` | ✅ | 0 | 1 |

✅ **working** — promoted from ⚠️. F3 fix from 2026-05-06 (jq -n output construction replacing the broken bash heredoc) is verified end-to-end. Each scan now produces exactly 1 fuzzing summary record per the fuzz endpoint. Earlier "executions=0 with no fuzzing rows" symptom is resolved.

**Status:** verified

---

## 2026-05-06 — `echidna` verification

**Scanner(s):** echidna
**Author:** Apogee
**Image version:** `scanner-echidna:0.5.4` / upstream `2.2.7`

| Structure | contract_id | scan_id | status | counts |
|---|---|---|---|---|
| project (foundry) | `eafe2b12` | `d0c889be-0f4d-4215-be7e-b4f8658cea98` | ✅ | 0 (matches baseline) |
| project (hardhat) | `0c7542c6` | `d9115a44-e36b-4461-b452-e4fd78745d4d` | ✅ | 0 |
| project (plain) | `24b7de7b` | `96f46544-947d-4205-8df6-2ae8240a9990` | ✅ | 0 |

✅ **working** — promoted from ⚠️. Echidna requires `echidna_*` invariant tests; OZ-only fixtures legitimately produce 0.

**Status:** verified

---

## 2026-05-06 — `halmos` verification

**Scanner(s):** halmos
**Author:** Apogee
**Image version:** `scanner-halmos:0.4.4` / upstream `0.3.3`

| Structure | contract_id | scan_id | status | counts | Notes |
|---|---|---|---|---|---|
| project (foundry) | `eafe2b12` | `20b19a1f-8dd5-443e-8c05-4b85edefb804` | ✅ | 0 | matches baseline (legitimate-zero, no invariants) |
| project (hardhat) | `0c7542c6` | `9f99af96-eaa6-4569-856d-4b289273ac11` | ✅ | 0 | parity |
| project (plain) | `24b7de7b` | `c1ea5acd-5756-4e51-978f-54212420814b` | ✅ | 0 | runs cleanly on plain multi-file |

✅ **working** — promoting from ⚠️ inconclusive → ✅ working. Halmos requires `prove_*` invariant functions in the contracts to find anything; OZ-only fixtures legitimately produce 0. Verifying actual detector firing requires a fixture with prove_ functions — separate enhancement.

**Status:** verified

---

## 2026-05-06 — `soliditydefend` verification

**Scanner(s):** soliditydefend
**Author:** Apogee
**Services Affected:** none
**Image version:** `scanner-soliditydefend:0.9.9` / upstream `2.0.9`

| Structure | contract_id | scan_id | status | counts | vulns_total | Notes |
|---|---|---|---|---|---|---|
| single | `7b72c90b` (Reentrancy ^0.8.0) | `1de6d284-66dc-4a36-8725-ec003165dd27` | ❌ failed | 0/0/0/0 | 0 | Pragma gate fired (`0.8.0 < 0.8.12`) — **intentional** per 2026-04-21 design |
| proxy | `31b6ac0b` | `bdd4c643-a559-45a8-a308-00127b043de7` | ✅ | 0/2/0/0 | 2 | retrievable |
| upgradeable | `12fbb2d3` | `6ccee62d-cef2-4743-a125-53fe8272dac7` | ✅ | 0/1/0/0 | 1 | retrievable |
| project (foundry) | `eafe2b12` | `eedc266e-512d-4d30-a4df-53e1592c0612` | ✅ | 1/0/0/0 | 0 | ✅ **matches 2026-05-04 baseline (1 critical) exactly** |
| project (hardhat) | `0c7542c6` | `eac50825-c5b5-476e-a4ad-5d97a83b22f9` | ✅ | 1/0/0/0 | 0 | parity with foundry |
| project (plain multi-file) | `24b7de7b` | `56224322-d12b-40db-aa11-283469f55da1` | ✅ | 1/0/2/0 | 0 | 1 critical + 2 medium |

### Verdict

✅ **working — baseline parity confirmed.** Promoting from ⚠️ inconclusive → ✅ working.

**Vindicates owner's claim** that soliditydefend was fully functional before recent changes. Foundry+OZ produces 1 critical = same as 2026-05-04 baseline. Earlier "0 findings" verdict (audit snapshot 2026-05-06) was due to fixture mismatch — owner's single-file 0.8.20 throwaway is too clean for soliditydefend's detector set, and the canonical `^0.8.0` Reentrancy fixture trips the pragma gate.

### Notes

- **Pragma gate behavior is by design** per 2026-04-21 image 0.9.9 update: contracts with pragma < 0.8.12 are rejected at compile-time check (the platform's bundled solc starts at 0.8.12). The single-file Reentrancy fixture (`^0.8.0`) hits this. Customers with legacy code see this rejection. UX consideration but not a scanner-functional bug.
- Same multi-file count/listing API discrepancy as slither/semgrep/aderyn (counts say findings, `/vulnerabilities` returns 0 on Foundry/Hardhat scans).

**Status:** verified

---

## 2026-05-06 — `mythril` verification

**Scanner(s):** mythril
**Author:** Apogee
**Services Affected:** none (verification only)
**Image version:** `scanner-mythril:0.2.10` / upstream `0.24.8`

| Structure | contract_id | scan_id | status | duration | counts | error_message |
|---|---|---|---|---|---|---|
| single | `7b72c90b` (Reentrancy) | `bad79f12-7a93-4da7-a39c-ae3760ed0bd6` | ❌ failed | 222s | 0 | `exit_1_check_pod_logs` |
| proxy | `31b6ac0b` (VulnerableProxy) | `b3f39e19-91b0-4a24-b3d1-0feb4da646d8` | ❌ failed | 16s | 0 | `Solc TypeError: storage pointer access without prior a...` |
| upgradeable | `12fbb2d3` (VulnerableDiamond) | `6698bf43-54df-4813-8922-33f413ea5632` | ❌ failed | 16s | 0 | `Solc TypeError: explicit type conversion not allowed address → contract` |
| project (foundry) | `eafe2b12` | `2ac045b0-fd03-4c41-8e88-86d1ef0e7108` | ✅ completed | 16s | 0 | — (matches 2026-05-04 baseline) |
| project (hardhat) | `0c7542c6` | `fc1592f1-544b-42fa-a5ac-690ebc6b444c` | ✅ completed (synthetic) | 0s | 0 | `mythril does not support multi-file Hardhat projects (z3 SMT solver memory ceiling at 2Gi)...` — F5 skip-gate working as designed |
| project (plain multi-file) | `24b7de7b` (E2E-OZ-ERC20-tree) | `0d52b43d-5118-49ea-a4ba-b5e0ec927c64` | ❌ failed | 57s | 0 | Multiple `Solc ParserError: Source "/utils/Context.sol" not found` etc. (import resolution failure) |

### Verdict

⚠️ **partial — works in 2 of 6 contexts.** Foundry+OZ matches baseline; F5 KJM Hardhat skip-gate working as designed (improvement vs 2026-05-06 fix doc).

**Failures (4 of 6):**

1. **Single-file Solidity with older patterns (3/3 single-file scans):**
   - `Reentrancy.sol` → opaque `exit_1_check_pod_logs` (took 222s, suggests timeout or z3 memory issue, not compile)
   - `VulnerableProxy.sol` → solc TypeError on storage pointer access (Solidity 0.5/0.6-era pattern)
   - `VulnerableDiamond.sol` → solc TypeError on address→contract explicit conversion (older pattern)
   
   Mythril's bundled solc may be too strict for older contract patterns. Whether this is "scanner broken" or "fixture needs newer pragma" depends on customer expectations. Customers with legacy code will hit this.

2. **Plain multi-file with relative imports (`24b7de7b`):**
   - `Solc ParserError: Source "/utils/Context.sol" not found` — multi-file project upload not generating proper remappings for OZ relative imports. Affects every file in the project. Distinct from the F6 GHBlob pattern (this is regular multi-file upload).
   - This may be a `tool-integration` project-mode handling gap for non-Foundry/non-Hardhat multi-file projects.

### Issues for later remediation

- **Issue M1**: mythril fails on single-file Solidity contracts using pre-0.7 patterns (storage pointers, address→contract). Either bundle older solc or document required pragma range.
- **Issue M2**: `Reentrancy.sol` failed with opaque `exit_1_check_pod_logs` — F4 fix improved exit code mapping but `1_check_pod_logs` is still opaque. The scan took 222 s (vs 16 s for Solc errors), suggesting a different failure mode (timeout, z3 OOM, or hang) that's not yet mapped. Refine F4 codes further.
- **Issue M3**: plain multi-file projects (no Foundry/Hardhat config) hit Solc import-resolution errors. Need remapping generation for non-framework multi-file uploads.

**Status:** verified (audit only — no fixes shipped this session)

---

## 2026-05-06 — `wake` verification

**Scanner(s):** wake
**Author:** Apogee
**Services Affected:** none
**Image version:** `scanner-wake:0.5.8` / upstream `4.22.0`

| Structure | contract_id | scan_id | counts | duration | Verdict |
|---|---|---|---|---|---|
| single | `7b72c90b` | `dec657ce-8fce-4032-b2fe-eb83de9cf5e6` | 0/0/0/0 | 484s | ✅ slow but functional |
| proxy | `31b6ac0b` | `55cd6403-0f59-4308-a0b2-f8e108d8a1da` | 0/0/0/0 | 484s | ✅ slow but functional |
| upgradeable | `12fbb2d3` | `7c5c90cb-b254-4553-8949-12dca6d2f54a` | 0/0/0/0 | 487s | ✅ slow but functional |
| project (foundry) | `eafe2b12` | `8d1389ec-e2ad-422f-87b0-19c20f2c2a15` | 0/0/2/0 | 16s | ✅ **improvement vs baseline (was 0)** |
| project (hardhat) | `0c7542c6` | `edd6d73b-7df8-411e-a9fd-a9d222f73774` | 0/0/2/0 | 16s | ✅ same as foundry |
| project (plain multi-file) | `24b7de7b` | `ca51110d-e228-4106-b657-578876b4d2cf` | 0/0/0/0 | 485s | ✅ slow, 0 |

✅ **working** — promoting from ⚠️ inconclusive → ✅ working. Foundry/Hardhat now produce 2 medium findings (vs 0 in 2026-05-04 baseline) — consistent with the 2026-05-05 wake target_version regression fix that restored proper compilation on Foundry+OZ.

### Issues observed

- **Performance concern**: single-file and plain-multi-file scans take ~8 minutes (484-487 s). Foundry/Hardhat scans take 16 s. The 30× difference suggests wake's non-framework code path is doing extra work (likely re-fetching solc binaries or full re-compilation) that the framework path skips. Customer UX impact for direct single-file uploads. Worth a separate platform investigation.

**Status:** verified

---

## 2026-05-06 — `aderyn` verification

**Scanner(s):** aderyn
**Author:** Apogee
**Services Affected:** none
**Image version:** `scanner-aderyn:0.8.5` / upstream `0.6.7`

| Structure | contract_id | scan_id | counts (c/h/m/l) | vulns_total | Verdict |
|---|---|---|---|---|---|
| single | `7b72c90b` (Reentrancy) | `44826f38-499b-409b-b739-453b052da948` | 5/0/12/0 | 17 | ✅ findings retrievable |
| proxy | `31b6ac0b` | `adad6fdc-3d3e-4cb4-9a7e-ad816db60b60` | 0/0/0/0 | 0 | ✅ legitimate-zero |
| upgradeable | `12fbb2d3` | `ebd3b462-c0f5-4c74-8deb-5f97d12fe34e` | 0/0/0/0 | 0 | ✅ legitimate-zero |
| project (foundry) | `eafe2b12` | `db4da773-df4e-47f7-a32d-a4474608850f` | 0/0/5/0 | 0 | ✅ **matches 2026-05-04 baseline (5 medium)** |
| project (hardhat) | `0c7542c6` | `0e6a2b6f-a26b-4836-b585-3396b4f939a8` | 0/0/5/0 | 0 | ✅ same as foundry |
| project (plain multi-file) | `24b7de7b` | `b2c7c7bb-54d7-4113-9f42-d52a4f00f2fb` | 0/0/0/0 | 0 | ✅ legitimate-zero |

✅ **working — baseline parity confirmed.** Promoting from ⚠️ inconclusive → ✅ working. Earlier inconclusive verdict (audit snapshot 2026-05-06) was due to single-file fixture mismatch; same-baseline fixture confirms aderyn is functional.

**Issues observed:** Same multi-file count/listing API discrepancy on Foundry/Hardhat scans.

**Status:** verified

---

## 2026-05-06 — `rustdefend` verification

**Scanner(s):** rustdefend
**Author:** Apogee
**Services Affected:** none
**Image version:** `scanner-rustdefend:0.4.6` / upstream `0.5.1`

| Structure | contract_id | scan_id | counts | Verdict |
|---|---|---|---|---|
| single | `7b536063` (E2E-Rust-anchor-lib-blob) | `9023bb50-9aab-4e06-9db9-3b078dcae199` | 0/0/0/0 | ✅ legitimate-zero |
| project (Anchor) | `86096252` (E2E-Rust-anchor-basic1-tree) | `59e6e60b-8ff9-4d32-a35f-ef2a81c7cc6f` | 0/0/0/0 | ✅ matches 2026-05-04 baseline |

✅ **working** — runs cleanly, baseline parity. Both fixtures legitimately produce 0.

**Status:** verified

---

## 2026-05-06 — `vyper` verification

**Scanner(s):** vyper (Slither-Vyper)
**Author:** Apogee
**Services Affected:** none
**Image version:** `scanner-vyper:0.3.5` / upstream `0.4.3`

| Structure | contract_id | scan_id | counts | Verdict |
|---|---|---|---|---|
| single | `8d5bea5f` (E2E-Vyper-Ownable) | `1854d6c5-b85a-4a48-8c0c-1e82412badc1` | 0/0/0/0 | ✅ matches baseline; Ownable has no detector targets |
| project (multi-file) | `a355b720` (E2E-Vyper-tokens-tree) | `bf941e40-3c73-4554-b544-293c5138ba95` | 0/0/0/0 | ✅ legitimate-zero |

✅ **working** — runs cleanly, baseline parity. Both fixtures legitimately produce 0 (no detector-targets in these Vyper contracts).

**Status:** verified

---

## 2026-05-06 — `solhint` verification

**Scanner(s):** solhint
**Author:** Apogee
**Services Affected:** none (verification only — no code changes)
**TaskDocs ref:** none
**Image version:** `scanner-solhint:0.1.13` / upstream `6.0.2`

### What changed

- Re-verified solhint against six contract structures via end-user API as `jasonbrailowbizop@mail.com`. All scans completed cleanly.

### Scan IDs

| Structure | contract_id | scan_id | counts (c/h/m/l) | `/vulnerabilities` total | Verdict |
|---|---|---|---|---|---|
| single | `7b72c90b` (Reentrancy) | `cfef81b0-ffc8-4bcc-9ca6-159ea7ca2388` | 0/26/0/0 | 17 | ✅ findings present; 26 vs 17 count/listing mismatch (single-file too) |
| proxy | `31b6ac0b` (VulnerableProxy) | `dbb2fa81-275f-4be5-a545-3fbfcc0a9693` | 0/0/0/0 | 0 | ✅ legitimate-zero (lint-clean proxy file) |
| upgradeable | `12fbb2d3` (VulnerableDiamond) | `1a767672-f0df-421f-9282-01c7029322e2` | 0/0/0/0 | 0 | ✅ legitimate-zero |
| project (foundry) | `eafe2b12` (foundry-oz-project) | `d6905e18-8945-48be-842d-419242cd7f13` | 0/16/0/0 | 0 | ✅ **matches 2026-05-04 baseline (16 high)** |
| project (hardhat) | `0c7542c6` (oz-hardhat-project) | `2839c93e-ff06-4240-b2f1-936feb3b1616` | 0/16/0/0 | 0 | ✅ same as foundry |
| project (plain multi-file) | `24b7de7b` (E2E-OZ-ERC20-tree) | `73edb67c-9245-4c33-84fb-513a106f48a3` | 0/0/0/0 | 0 | ✅ legitimate-zero (lint-clean OZ) |

### Why

Phase A re-verification of currently-working scanners against the same baseline used on 2026-05-04, plus three additional structure types. Confirms solhint is unchanged.

### Verdict

✅ **working — baseline parity confirmed.** Solhint runs cleanly, Foundry+OZ matches baseline (16 high). Proxy/diamond/plain returning 0 is consistent with lint-clean files.

### Issues observed (carry-over)

- **Severity-mapping bug**: solhint linter style/gas/best-practice rules are still mapped to severity `high` (26 of 26 on single-file Reentrancy, 16 of 16 on Foundry/Hardhat). Already documented in 2026-05-06 audit snapshot. Inflates customer-facing severity counts.
- **Count/listing mismatch now seen on single-file too** (`cfef81b0`): scan record shows 26 high but `/vulnerabilities` returns 17. Previously thought multi-file-specific based on slither/semgrep observations — confirmed scanner-agnostic and structure-agnostic. Persistent platform-side issue.

### Status

verified

---

## 2026-05-06 — `semgrep` verification

**Scanner(s):** semgrep
**Author:** Apogee
**Services Affected:** none (verification only — no code changes)
**TaskDocs ref:** none
**Image version:** `scanner-semgrep:0.3.12` / upstream `1.144.0`

### What changed

- Re-verified semgrep against six contract structures via end-user API as `jasonbrailowbizop@mail.com`. All scans completed cleanly.

### Scan IDs

| Structure | contract_id | scan_id | counts (c/h/m/l) | `/vulnerabilities` total | Verdict |
|---|---|---|---|---|---|
| single | `7b72c90b` (Reentrancy) | `f5b8d684-cb2c-429c-b495-159248d5c02a` | 0/0/0/6 | 6 | ✅ findings retrievable |
| proxy | `31b6ac0b` (VulnerableProxy) | `d781cc23-e1db-48ef-812a-470c5173740d` | 0/0/0/16 | 16 | ✅ findings retrievable |
| upgradeable | `12fbb2d3` (VulnerableDiamond) | `49412f61-bc57-4e82-b0e2-3feb83c9e632` | 0/0/0/28 | 28 | ✅ findings retrievable |
| project (foundry) | `eafe2b12` (foundry-oz-project) | `022931ec-9f26-40f8-ba46-e779b44efb03` | 0/0/0/6 | 0 | ✅ **matches 2026-05-04 baseline (6 low)**; multi-file count/listing discrepancy |
| project (hardhat) | `0c7542c6` (oz-hardhat-project) | `2e8a9e8d-4974-4d5e-a098-ce057674d30f` | 0/0/0/6 | 0 | ✅ same as foundry |
| project (plain multi-file) | `24b7de7b` (E2E-OZ-ERC20-tree) | `d5c54e29-62d3-40e2-aef2-71cd0c726dee` | 0/0/0/9 | 0 | ✅ findings present in counts |

### Why

Phase A re-verification of currently-working scanners against the same baseline used on 2026-05-04, plus three additional structure types. Confirms semgrep is unchanged.

### Verdict

✅ **working — baseline parity confirmed.** Semgrep produces findings on all 6 structure types. Foundry+OZ match: 6 low = 2026-05-04 baseline exactly.

### Issues observed

- Same multi-file API count/listing discrepancy as slither (scans `022931ec`, `2e8a9e8d`, `d5c54e29`): scan record `*_count` fields show findings but `/vulnerabilities` returns 0 items. This is now the second scanner exhibiting it — confirms it's a platform-side issue, not scanner-specific.

### Status

verified

---

## 2026-05-06 — `slither` verification

**Scanner(s):** slither
**Author:** Apogee
**Services Affected:** none (verification only — no code changes)
**TaskDocs ref:** none
**Image version:** `scanner-slither:0.4.7` / upstream `0.11.5`

### What changed

- Re-verified slither against six contract structures via end-user API as `jasonbrailowbizop@mail.com`. All scans completed cleanly. No code or config changes.

### Scan IDs

| Structure | contract_id | scan_id | counts (c/h/m/l) | `/vulnerabilities` total | Verdict |
|---|---|---|---|---|---|
| single | `7b72c90b` (Reentrancy) | `79695e14-a418-4dc3-886a-c13481f36eab` | 1/0/0/3 | 4 | ✅ reentrancy detected |
| proxy | `31b6ac0b` (VulnerableProxy) | `d15814ad-fa0b-4ef3-ae15-760c0a9ce03f` | 0/0/0/0 | 0 | ✅ legitimate-zero (slither doesn't flag basic proxy patterns in isolation) |
| upgradeable | `12fbb2d3` (VulnerableDiamond) | `f3ce6b02-3931-4046-8a45-eff2ffb1cc3b` | 0/0/0/0 | 0 | ✅ legitimate-zero |
| project (foundry) | `eafe2b12` (foundry-oz-project) | `9adc0acd-db93-4e43-8338-9c8401549812` | 0/0/1/5 | 0 | ✅ **matches 2026-05-04 baseline (1m+5l = 6)** |
| project (hardhat) | `0c7542c6` (oz-hardhat-project) | `35bba6f1-b3bc-48d6-a360-e322757bc9f1` | 0/0/1/5 | 0 | ✅ same as foundry — same OZ contracts compiled both ways |
| project (plain multi-file) | `24b7de7b` (E2E-OZ-ERC20-tree) | `8d84f62e-6871-418a-87a0-fd1466f638c9` | 0/0/0/0 | 0 | ✅ legitimate-zero (clean OZ ERC20) |

### Why

Phase A re-verification of currently-working scanners against the same baseline used on 2026-05-04, plus three additional structure types (proxy, upgradeable, plain multi-file) per the methodical-not-reactive scanner audit plan. Confirms harness/auth/network is reliable before testing the 12 inconclusive scanners.

### Verdict

✅ **working — baseline parity confirmed.** Slither produces findings on textbook reentrancy and on multi-file Foundry/Hardhat OZ projects with the same finding shape as 2026-05-04. Zero findings on simple proxy/diamond/clean-ERC20 are consistent with slither's detector profile (these contracts don't trigger its rule set in isolation).

### Issues observed (not slither-specific)

- **API count vs listing discrepancy** (4 of 6 scans): scan record's `critical_count`/`high_count`/`medium_count`/`low_count` show findings, but `/scans/{id}/vulnerabilities` returns 0 items, and `/code-quality`, `/gas-analysis`, `/formal-verification`, `/fuzzing` also all return 0. The 6 findings on Foundry/Hardhat are visible in the count fields but not retrievable through any list endpoint. Affects: `9adc0acd`, `35bba6f1`. Worth a separate platform-side investigation; not a scanner fault. **Does not block slither verdict** since baseline parity is established via the count fields.
- `result_types` for these scans returns `['gas_analysis', 'vulnerability']` even when both list endpoints are empty — same pattern as the 2026-05-06 audit snapshot entry below.

### Status

verified

---

## 2026-05-06 — audit snapshot

**Scanner(s):** all 17 — slither, aderyn, semgrep, solhint, halmos, mythril, echidna, wake, medusa, soliditydefend, vyper, moccasin, sol-azy, sec3-xray, trident, cargo-fuzz-solana, rustdefend
**Author:** Apogee
**Services Affected:** none (audit only — no code changes)
**TaskDocs ref:** none (this folder is the new home for ongoing scanner-audit tracking)

### What changed

- Created `docs/scanners-audit/` to track scanner functional status methodically going forward.
- Ran a full end-user audit against `https://app.0xapogee.com/api/v1` as `jasonbrailowbizop@mail.com` (enterprise tier, unlimited quota).
- Six scans across Solidity / Vyper / Rust, single-file + project, plus one retry on Solidity with a 0.8.20 pragma after the original `^0.8.0` fixture hit the `< 0.8.12` pragma gate.
- Confirmed all 17 scanners route through `blocksecops-tool-integration` K8s Jobs (no divergent execution paths).

### Scan IDs

| # | Scope | scan_id | Result summary |
|---|---|---|---|
| 1 | Solidity single-file (`Reentrancy.sol`, ^0.8.0) | `bbbd6da0-5073-4356-ac6d-66bcddaa25a2` | failed @ 8s — pragma gate `< 0.8.12` |
| 1b | Solidity single-file (`Reentrancy_0_8_20.sol`, ^0.8.20) | `d412c5bf-4cb1-4fdb-98f0-4c5918da169a` | slither 4, semgrep 6, solhint 15, aderyn 0, mythril 0, wake 0, soliditydefend 0 |
| 2 | Solidity Foundry project (`foundry-test/`) | `592b7412-0d64-41ee-a7dc-79f716b4f939` | halmos 0, echidna 0, medusa 0 (1 fuzzing summary, executions=0) |
| 3 | Vyper single-file (`reentrancy.vy`) | `0766e0d5-ed2c-4371-9969-f23458773cf7` | vyper 2 (1 high, 1 low) |
| 4 | Vyper Mox project (scaffold) | `43bd976e-df6f-47bc-954a-7bad4207fd4e` | moccasin 0; framework detected as `plain` (not `moccasin`) |
| 5 | Rust single-file (`arbitrary_cpi.rs`) | `23e71b0c-2837-4965-bb0e-3148e9a2b7d4` | rustdefend 1 critical, sol-azy 0 |
| 6 | Rust Anchor project (scaffold) | `676a71c9-6fdf-461c-8b79-7e7c62e6b291` | sec3-xray 0, trident 0, cargo-fuzz-solana 0 |

### Why

To establish a current snapshot vs the 2026-05-04 baseline and the 2026-05-06 fixes, and to set up a tracking document so future audits don't re-derive this from scratch.

### Findings

- **Confirmed working (5/17):** `slither`, `semgrep`, `solhint`, `vyper`, `rustdefend`.
- **Inconclusive (12/17):** `aderyn`, `halmos`, `mythril`, `echidna`, `wake`, `medusa`, `soliditydefend`, `moccasin`, `sol-azy`, `sec3-xray`, `trident`, `cargo-fuzz-solana`.
- **Confirmed broken (0/17):** none cluster-verified.

### Important caveat

**The 12 inconclusive verdicts are NOT regression evidence.** This audit used different fixtures than the 2026-05-04 baseline:

- The 2026-05-04 baseline ran most Solidity scanners against `eafe2b12` (multi-file Foundry+OZ).
- This audit ran them against single-file `Reentrancy_0_8_20.sol`.
- Different fixtures exercise different code paths inside each scanner — a 0-finding result on a different fixture is not the same code path failing.
- Same logic applies for moccasin (baseline: `a355b720` / mine: scaffold), sol-azy/sec3-xray/trident/cargo-fuzz-solana (baseline: `86096252` / mine: scaffold).

The owner's report that `soliditydefend` was fully functional before recent changes is consistent with the 2026-05-04 baseline showing 1 critical on `eafe2b12`. **Before declaring `soliditydefend` (or any inconclusive scanner) regressed, the next session must re-verify against the same baseline fixture (`eafe2b12`).**

### Open issues recorded against scanner rows

- `aderyn`, `wake`, `mythril`, `soliditydefend` — single-file fixture mismatch with multi-file Foundry+OZ baseline; needs same-fixture re-test.
- `halmos`, `echidna` — fixture lacked invariants/proof targets; needs fixture with `prove_*` / `echidna_*` functions to verify execution.
- `medusa` — same as above; F3 fix from 2026-05-06 (image 0.4.5) shipped, needs fixture with property invariants for verification.
- `solhint` — severity-mapping bug: linter style/gas rules tagged as severity `high` (15 of 15 findings). Inflates customer-facing severity counts.
- `moccasin` — framework detector returned `plain` instead of `moccasin` for a `moccasin.toml` project; either detector gap or scaffold layout; needs `a355b720` re-test.
- `sol-azy` — single-file fixture; sol-azy likely needs Anchor project context; needs `86096252` re-test.
- `sec3-xray`, `cargo-fuzz-solana`, `trident` — Anchor scaffold may be too minimal; needs `86096252` re-test.

### Platform-level observations (not scanner-specific)

- **Pragma gate `< 0.8.12`:** Real customers with `^0.8.0` codebases fail at scan time before any scanner runs. Documented as intended (`scanner-base-solidity:1.0.0-30aad7ef` carries the gate per soliditydefend `_note` 2026-04-21), but the customer-facing UX is "your contract is rejected" not "your contract is too old to scan."
- **No per-scanner execution status:** the scan record's `scanners_used` field is just an echo of `scanner_ids_requested`. There is no API surface that reports per-scanner success / failure / skipped status — only "scan completed" plus the count of findings produced. This makes silent failure invisible to customers and to operators without pulling pod logs.
- **`/scans/{id}/result-types` inconsistency:** scan 4 returned `result_types: ['fuzzing']` despite producing zero fuzzing rows; scan 6 returned `['fuzzing', 'vulnerability']` with neither. Cosmetic but confusing.
- **JWT 1h expiry:** long audits hit auth refresh; documented for any future SDK or CLI integration.

### Verification

- This entry is the verification snapshot. No fixes shipped here.
- Owner approval required before any next step (per `docs/standards/core-development-rules.md` Rule 0).

### Status

verified — audit snapshot recorded; no fixes applied; this changelog entry is the source of truth for the 2026-05-06 state.
