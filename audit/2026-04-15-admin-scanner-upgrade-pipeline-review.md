# Admin Scanner Upgrade Pipeline — Review + Remediation Plan

**Date:** 2026-04-15
**Auditor:** Apogee Platform Team
**Scope:** The scanner-upgrade feature exposed via `admin.0xapogee.com` — from the React UI down through api-service, tool-integration, the `scanner-versions` ConfigMap, the `scanner_versions` DB table, and the post-upgrade pattern-seeding pipeline.

## Summary verdict

**Partially healthy.** UI + core flow work end-to-end. Platform-admin auth + rate limiting + audit logging are present. However the feature is **not production-ready** until five structural gaps are closed.

## Pipeline traced (end-to-end)

1. **UI** — `blocksecops-admin-portal/src/pages/AdminScanners.tsx`
   - Scanner list with current/latest versions (lines 456–547); upgrade modal (lines 589–719)
   - Auto-refresh every 30s (line 140)
   - Mismatch triggers yellow "Upgrade" button
2. **API client** — `blocksecops-admin-portal/src/lib/api/admin.ts` (lines 1228–1287)
3. **api-service** — `src/presentation/api/v1/endpoints/admin/system.py`
   - `GET /api/v1/admin/system/scanners/health` (line 565) — proxies to tool-integration, fetches `latest_version` from GitHub
   - `POST /api/v1/admin/system/scanners/{scanner_name}/upgrade` (line 677) — `require_admin_role("platform_admin")`, rate-limited 3/min
4. **tool-integration** — `src/main.py`
   - Validates internal-service token
   - `/scanners/{scanner_name}/upgrade` (line 746) mutates ConfigMap `scanner-versions` with optimistic concurrency (`resourceVersion` check), patches deployment annotation to trigger rollout
5. **Post-upgrade pipeline** — `api-service/src/application/services/scanner_upgrade_service.py` (lines 629–741)
   - Loads detector list from seed JSON, compares with existing `VulnerabilityPattern` rows
   - Creates new patterns + `PatternToolMappingModel` for unmapped detectors
   - Audits coverage, returns health score
6. **DB record** — `scanner_versions` table (line 722 in system.py), `_note` field tracks who/why

## Findings

### CRITICAL — `target_version` is not validated

`src/presentation/api/v1/endpoints/admin/system.py:655`:
```python
class ScannerUpgradeRequest(BaseModel):
    target_version: str = Field(..., min_length=1, max_length=50)
```

The only constraints are length bounds. An admin (or a compromised admin session, or a typo) can submit `target_version="invalid"`, `target_version="0.0.0"`, `target_version="<script>"`, or any 50-char string. tool-integration's ConfigMap patch will succeed — and the subsequent deployment rollout tries to pull a Docker image that doesn't exist, landing scanner Jobs in `ImagePullBackOff`.

**OWASP mapping:** A03 Injection (lack of input validation at trust boundary). Violates `standards/secure-coding.md` and `standards/api-endpoint-auth.md` (write endpoints must validate all user-supplied values).

**Severity:** HIGH (admin role + rate limit at 3/min mean the blast radius is one admin, but the recovery path is manual ConfigMap editing).

### HIGH — No rollback endpoint

There is no `POST /api/v1/admin/system/scanners/{name}/rollback` or similar. `scanner_versions` table stores only the *current* version; previous versions are overwritten in `_note`. If an upgrade breaks scanning, the admin must:
1. Know the previous version (not exposed in UI)
2. Manually edit the `scanner-versions` ConfigMap via `kubectl` (violates codebase-first)
3. Or re-submit the upgrade endpoint with the old version (which hits the same un-validated path)

**Severity:** HIGH (recoverability is a core requirement per `standards/testing-deployment.md` Rule: "Do not rollback working deployments" — but that assumes a rollback path exists).

### MEDIUM — Only 9 of 17 scanners track upstream versions

`tool-integration/src/main.py` `GITHUB_REPOS` map covers: slither, aderyn, soliditydefend, solhint, semgrep, echidna, halmos, wake, medusa.

**Missing:** sol-azy, sec3-xray, trident, cargo-fuzz-solana, rustdefend, moccasin, mythril, vyper.

For these 8 scanners, the UI shows no "upgrade available" button even when upstream publishes a new release. Silent staleness risk.

**Severity:** MEDIUM (functionality gap, not a broken behavior).

### MEDIUM — Inconsistent state on partial failure

```python
# system.py:689
response = await client.post(f"{tool_integration}/scanners/.../upgrade", ...)
data = response.json()

# system.py:720
if data.get("success"):
    await upsert_scanner_versions(db, {scanner_name: {...}})
```

If tool-integration's ConfigMap patch succeeds but `upsert_scanner_versions` fails (DB connection blip, serialization conflict), K8s is on the new version and the DB is on the old one. No compensating rollback. Next UI refresh shows the DB value, which disagrees with reality.

**Severity:** MEDIUM (recovery via manual DB update; rare in practice).

### MEDIUM — No image-existence probe

tool-integration writes the new version to the ConfigMap and rolls out the Deployment without verifying the Docker image exists in Artifact Registry. Pods enter `ImagePullBackOff`; the upgrade endpoint has already returned `success=true` before the rollout lands.

**Severity:** MEDIUM (detectable via existing `CronJobPodConfigError` / pod-level alerting, but the UI lies about the upgrade result in the window before the rollout fails).

### LOW — Pattern seeding can fail silently

`scanner_upgrade_service.py:674` — if the detector JSON file is missing/malformed, the pipeline logs a warning and still returns `success=true`. UI shows a green tick; the pattern catalog is actually missing entries.

### LOW — Audit log lacks previous version + failure details

`log_admin_action(action="admin.scanner.upgrade", ...)` records the action but not the `previous_version` or the reason for failure when `success=false`. Forensic reconstruction after a bad upgrade requires cross-referencing ConfigMap history (which doesn't persist).

## Remediation plan — six PRs, standards-compliant

Each PR ships independently with full test coverage, follows semver (PATCH), bumps `pyproject.toml` + `k8s/overlays/gcp/kustomization.yaml` `newTag` + `app.kubernetes.io/version` together per `standards/docker-image-versioning.md`, passes `SERVICE_VERSION` / `BUILD_DATE` / `VCS_REF` build args per `standards/build-workflow.md`, and requires owner Rule-0 approval.

| # | Fix | Priority | Standards invoked | Scope |
|---|-----|----------|-------------------|-------|
| **1** | **Validate `target_version`** — strict semver regex on `ScannerUpgradeRequest`; validate `scanner_name` exists in the `scanner-versions` ConfigMap before proxying | CRITICAL | `secure-coding.md` A03, `api-endpoint-auth.md` | api-service only | **✅ SHIPPED** in api-service 0.37.4 (PR #347) |
| **2** | **Upstream-release validation** — tool-integration rejects `target_version` when it isn't in the published GitHub release list for the scanner. Lower-cost variant of the original "Artifact Registry manifest probe" — zero IAM changes, catches the real-world typo case. Residual gap (upstream cut but we haven't built+pushed yet) is narrow; can be closed later by adding an AR HEAD probe behind Workload Identity. | MEDIUM | `secure-coding.md` A03, `testing-deployment.md` | tool-integration | **✅ SHIPPED** in tool-integration 0.5.46 |
| **3** | **Rollback endpoint** — `POST /api/v1/admin/system/scanners/{name}/rollback` reads the most recent `upgrade_source=admin_portal` row from the new `scanner_version_history` table and re-runs the upgrade with that row's `previous_version`. Every upgrade (including rollbacks + auto-reverts) records a history row so the trail is complete. Alembic migration 086 is additive; no existing data touched. | HIGH | `database-management.md` (new table = migration + verified backup first), `testing-deployment.md`, `api-endpoint-auth.md` | api-service | **✅ SHIPPED** in api-service 0.38.0 |
| **4** | **Fill GITHUB_REPOS for missing 8 scanners** — add upstream GitHub releases mapping for 6 of 8 (sol-azy has no upstream releases; rustdefend is internal-only). Corrects mythril repo rename ConsenSys → ConsenSysDiligence at the same time. | MEDIUM | `dependency-management.md` (version policy) | tool-integration | **✅ SHIPPED** in tool-integration 0.5.45 |
| **5** | **Unit-of-work across DB + ConfigMap** — capture pre-upgrade version before mutation; on DB upsert failure call tool-integration again to revert the ConfigMap; surface a `state` field (`applied` / `reverted` / `applied_db_stale` / `tool_integration_failed` / `rejected`) so callers can distinguish outcomes | MEDIUM | `database-management.md` (consistency), `core-development-rules.md` | api-service | **✅ SHIPPED** in api-service 0.37.5 |
| **6** | **Notification hook** — `scanner.upgraded` event emitted through the admin's configured notification channels on every post-mutation outcome; severity scales by state (info for applied, high for applied_db_stale). Best-effort: failure never blocks the upgrade response. | LOW | `service-availability.md` (observability) | api-service | **✅ SHIPPED** in api-service 0.37.6 |

## PR #1 plan — `target_version` validation (shipping in this batch)

**File:** `blocksecops-api-service/src/presentation/api/v1/endpoints/admin/system.py`

- Add pydantic field validator to `ScannerUpgradeRequest.target_version`:
  - Regex: `^\d+\.\d+\.\d+([.-][a-zA-Z0-9.-]+)?$` (accepts `1.2.3`, `1.2.3-rc1`, `1.2.3.post1`, rejects letters-only / control chars / path-traversal chars)
  - `max_length=50` kept as defence-in-depth
- Add scanner-name existence check: fetch `scanner-versions` ConfigMap keys via tool-integration's existing `/scanners/health` proxy; if `scanner_name` not in the set, `raise HTTPException(404, "Scanner not registered")`
- Unit test coverage in `tests/unit/api/test_admin_scanner_upgrade.py`:
  - Happy path (`1.2.3`, `1.2.3-rc1`)
  - Rejected: empty, 51-char, `invalid`, `<script>`, `../../etc/passwd`, `0.0.0` (valid semver; other layers handle non-existence)
  - Rejected: `scanner_name="does-not-exist"`

**Version bump:** api-service `0.37.3 → 0.37.4`. Pyproject + kustomization.yaml `newTag` + `app.kubernetes.io/version` label all bumped together per `docker-image-versioning.md`.

**Database impact:** none (pure endpoint validation).
**Port / service-availability impact:** none.
**Security-first:** closes A03 input-validation gap; no new attack surface.

## See also

- `standards/secure-coding.md` — A03 input validation
- `standards/api-endpoint-auth.md` — write endpoints must use `require_auth_with_scope` + validate inputs
- `standards/docker-image-versioning.md` — semver + kustomization sync
- `standards/database-management.md` — migration + backup for Fix #3
- `audit/2026-04-15-scanner-e2e-matrix-full-0.37.3.md` — scanner inventory referenced in Fix #4
