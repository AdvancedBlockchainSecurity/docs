# Scanner Upgrade via Admin Dashboard

**Priority**: P1 - Important
**Last Tested**: 2026-04-15 (api-service 0.37.4 + tool-integration 0.5.45)
**Endpoint**: `POST /api/v1/admin/system/scanners/{name}/upgrade`

**Recent changes (2026-04-15):**
- api-service 0.37.4 (PR #347) — strict-semver validation on `target_version` + scanner-name existence check (OWASP A03 closure)
- tool-integration 0.5.45 (PR #155) — `GITHUB_REPOS` expanded from 9 → 15 scanners; mythril repo corrected `ConsenSys` → `ConsenSysDiligence`
- api-service 0.37.5 (PR #348) — unit-of-work with compensating revert; new `state` field on upgrade response
- api-service 0.37.6 (PR #349) — `scanner.upgraded` notification event emitted on every post-mutation outcome
- tool-integration 0.5.46 (PR #156) — upstream GitHub-release-list validation; rejects `target_version` that was never published

Full audit + 6-PR remediation plan: `audit/2026-04-15-admin-scanner-upgrade-pipeline-review.md`. 5 of 6 fixes shipped; only #3 (rollback endpoint + `scanner_version_history` table) remains queued.

---

## 1. Version Detection

### 1.1 Latest Version Display
- [ ] Admin System → Security Scanners shows current version for each scanner
- [ ] Latest version fetched from GitHub API (1-hour cache)
- [ ] Yellow `→ x.y.z` indicator shown when versions differ
- [ ] Scanners without GitHub mapping show no latest version
- [ ] Cache refreshes after 1 hour

### 1.2 GITHUB_REPOS coverage (updated 2026-04-15)
- [ ] 15 of 17 scanners show `latest_version` populated: slither, aderyn, soliditydefend, solhint, semgrep, echidna, halmos, wake, medusa, **mythril**, **vyper**, **moccasin**, **sec3-xray**, **trident**, **cargo-fuzz-solana** (bold = added 2026-04-15)
- [ ] sol-azy and rustdefend intentionally show no `latest_version` (sol-azy has no upstream GitHub releases; rustdefend is internal-only)
- [ ] mythril resolves via `ConsenSysDiligence/mythril` (the ConsenSys org was renamed)

### 1.3 Scanner Health Table
- [ ] All registered scanners appear in table
- [ ] Health status (Healthy/Degraded) displayed correctly
- [ ] Job counts (Total/Failed/Running) accurate
- [ ] "Actions" column visible with Upgrade button

---

## 2. Upgrade Button

### 2.1 Button Visibility
- [ ] "Upgrade" button shown only when `latest_version !== version`
- [ ] Button hidden when scanner is up-to-date
- [ ] Button hidden when latest version is unknown/null
- [ ] Button styled with `ArrowUpCircleIcon`

### 2.2 Confirmation Dialog
- [ ] Clicking "Upgrade" opens confirmation modal
- [ ] Modal shows scanner name
- [ ] Modal shows version transition (e.g., `0.10.3 → 0.10.4`)
- [ ] Info notice about Docker image rebuild displayed
- [ ] Optional reason field available
- [ ] "Cancel" button closes dialog
- [ ] "Confirm Upgrade" button initiates upgrade

---

## 3. Upgrade Execution

### 3.1 API Proxy (API Service)
- [ ] `POST /admin/system/scanners/{name}/upgrade` requires `platform_admin` role
- [ ] Invalid scanner names rejected (400)
- [ ] Request proxied to tool-integration service
- [ ] Timeout set to 60 seconds
- [ ] Admin action logged in audit trail

### 3.1.1 target_version input validation (added 2026-04-15, api-service 0.37.4)
- [ ] `target_version="1.2.3"` accepted (valid semver)
- [ ] `target_version="1.2.3-rc1"` accepted (pre-release suffix)
- [ ] `target_version="1.2.3.post1"` accepted (PEP440 post-release)
- [ ] `target_version="1.2.3+build5"` accepted (build metadata)
- [ ] `target_version="1.2.3-beta+exp.sha.5114f85"` accepted
- [ ] `target_version=""` rejected (422)
- [ ] `target_version="latest"` rejected (422)
- [ ] `target_version="v1.2.3"` rejected (leading `v` — 422)
- [ ] `target_version="1.2"` rejected (missing PATCH — 422)
- [ ] `target_version="1.2.3;rm -rf /"` rejected (shell metachar — 422)
- [ ] `target_version="<script>alert(1)</script>"` rejected (XSS — 422)
- [ ] `target_version="../../etc/passwd"` rejected (path traversal — 422)
- [ ] `target_version` > 50 chars rejected (422)
- [ ] `reason` > 500 chars rejected (422)
- [ ] Unknown `scanner_name` rejected (404 "Scanner not registered") via pre-flight to tool-integration `/scanners/health`

### 3.2 ConfigMap Update (Tool Integration)
- [ ] ConfigMap `scanner-versions` read from K8s API
- [ ] `SCANNER_METADATA` JSON updated with new version
- [ ] `_note` field updated with date and source
- [ ] ConfigMap patched in Kubernetes
- [ ] In-memory metadata updated
- [ ] Deployment rollout restart triggered

### 3.3 Success Response
- [ ] Response includes `success: true`
- [ ] Previous and new version numbers returned
- [ ] List of completed steps returned
- [ ] Message includes note about Docker image rebuild
- [ ] Steps list displayed in UI
- [ ] Response includes `state: "applied"` (api-service 0.37.5+)

### 3.4 Error Handling
- [ ] Non-existent scanner returns 404
- [ ] K8s API errors caught and returned as `success: false`
- [ ] Error message displayed in UI
- [ ] Partial step list shows what completed before failure

### 3.5 `state` field contract (added 2026-04-15, api-service 0.37.5)
- [ ] Happy path: `state="applied"` when ConfigMap + DB both updated
- [ ] DB-failure + revert-success: `state="reverted"`, `previous_version == new_version` (both pre-upgrade), `success=false`
- [ ] DB-failure + revert-failure: `state="applied_db_stale"`, `new_version` holds the ConfigMap value, `success=false`, message instructs manual remediation
- [ ] tool-integration network error: `state="tool_integration_failed"`, ConfigMap never mutated, `success=false`, safe to retry
- [ ] tool-integration rejection (bad version, conflict): `state="rejected"`, `success=false`
- [ ] `state` defaults to `"applied"` for backwards compatibility when the field isn't populated

### 3.6 Upstream GitHub-release validation (added 2026-04-15, tool-integration 0.5.46)
- [ ] Valid upstream version accepted: `target_version="0.11.5"` on slither (most recent upstream tag) → 200
- [ ] Unpublished version rejected: `target_version="0.99.99"` on slither → **400** with "not a published upstream release"
- [ ] Unmapped scanner bypasses check: `target_version="0.4.0"` on sol-azy → processed (sol-azy has no `GITHUB_REPOS` entry); tool-integration's own allowlist is still authoritative
- [ ] Unmapped scanner bypasses check: rustdefend accepts any valid semver (internal scanner)
- [ ] Cache honoured: two consecutive upgrades within 1 hour make only one GitHub API call
- [ ] GitHub API failure falls through: if `api.github.com` is unreachable, the check soft-fails (legacy behaviour), logged with a warning
- [ ] **Compensating revert bypass:** when api-service fix #5 issues a revert (target_version == current_version), the upstream-release check is skipped — the previous version was always valid

### 3.7 Automated regression coverage (added 2026-04-16)
- [ ] `blocksecops-api-service/tests/contract/test_scanner_upgrade_request_contract.py` — schema-level contract between api-service `ScannerUpgradeRequest` and tool-integration `UpgradeRequest` (target_version + reason shape, both str, matching response-superset). Catches renames / type drift at CI import time. 8 tests pass.
- [ ] `blocksecops-api-service/tests/integration/test_alembic_migration_086_roundtrip.py` — migration 086 apply/downgrade/idempotency roundtrip for the `scanner_version_history` table (backing store for fix #3 rollback). Shells out to `alembic` CLI; skips cleanly when no Postgres is reachable. 5 tests (Postgres-dependent).
- [ ] `blocksecops-tool-integration/tests/integration/test_preflight_roundtrip.py` — real `TestClient` against `/scanners/health` (shape api-service pre-flight depends on) and `/scanners/slither/upgrade` with `target_version="0.99.99"` (fix #2 400 path) and with an unknown scanner name (404). 6 tests pass.

### 3.7 `scanner.upgraded` notification (added 2026-04-15, api-service 0.37.6)
- [ ] `WebhookEventType.SCANNER_UPGRADED` value is `"scanner.upgraded"`
- [ ] Admin with a configured webhook / email / Slack channel subscribed to `scanner.upgraded` receives a notification after every upgrade call
- [ ] Severity matrix:
  - `state="applied"` → `info`
  - `state="reverted"` → `medium`
  - `state="applied_db_stale"` → `high` (drift — needs manual remediation)
  - `state="tool_integration_failed"` → `low`
  - `state="rejected"` → `low`
- [ ] Payload `metadata` includes: scanner_name, previous_version, new_version, state, reason
- [ ] Notification failure never blocks the upgrade response (best-effort; warning logged, upgrade result unchanged)

---

## 4. Post-Upgrade Verification

### 4.1 ConfigMap Updated
```bash
kubectl get cm scanner-versions -n tool-integration-local \
  -o jsonpath='{.data.SCANNER_METADATA}' | jq '.<scanner>.version'
# Should show new version
```

### 4.2 Scanner Health Refresh
- [ ] After upgrade, refreshing scanner health shows updated version
- [ ] Upgrade indicator disappears if versions now match
- [ ] Pod restart completes without errors

### 4.3 Audit Trail
- [ ] Admin System → Audit Log shows `admin.scanner.upgrade` action
- [ ] Audit entry includes target scanner name
- [ ] Audit entry includes target version and success status

---

## 5. Authorization & Security

### 5.1 Access Control
- [ ] Non-admin users cannot access upgrade endpoint (403)
- [ ] Non-platform_admin roles cannot upgrade (403)
- [ ] Valid admin token required (401 without)

### 5.2 Input Validation
- [ ] Scanner name validated (alphanumeric + hyphens/underscores)
- [ ] Target version required (min 1, max 50 chars)
- [ ] Reason field optional (max 500 chars)

---

## 6. RBAC Verification

### 6.1 ServiceAccount Permissions
```bash
# Verify tool-integration SA can patch configmaps
kubectl auth can-i patch configmaps \
  --as=system:serviceaccount:tool-integration-local:tool-integration-sa \
  -n tool-integration-local
# Should return: yes

# Verify tool-integration SA can patch deployments
kubectl auth can-i patch deployments \
  --as=system:serviceaccount:tool-integration-local:tool-integration-sa \
  -n tool-integration-local
# Should return: yes
```

---

## 7. Upgrade Pipeline Results (v0.25.9+)

### 7.1 Pipeline Execution
- [ ] After successful ConfigMap update, pipeline runs automatically
- [ ] Detector comparison phase executes
- [ ] Pattern seeding phase executes
- [ ] Audit validation phase executes
- [ ] Pipeline results included in API response under `pipeline` field

### 7.2 Detector Comparison Display
- [ ] "Pipeline Results" section appears in upgrade dialog after success
- [ ] New detector count displayed
- [ ] Changed detector count displayed
- [ ] Removed detector count displayed
- [ ] Section hidden if detector comparison data is null (no detector list available)
- [ ] Error message shown if detector comparison failed

### 7.3 Pattern Seeding Display
- [ ] Patterns created count displayed
- [ ] Mappings created count displayed
- [ ] Section hidden if no unmapped detectors found
- [ ] Error message shown if pattern seeding failed

### 7.4 Health Score Display
- [ ] Health score percentage displayed
- [ ] Health status text displayed (healthy/needs_attention/critical)
- [ ] Green color for score >= 90%
- [ ] Yellow color for score >= 70% and < 90%
- [ ] Red color for score < 70%
- [ ] Error message shown if audit failed

### 7.5 Pipeline Error Handling
- [ ] Individual phase failure does not block other phases
- [ ] Phase errors shown inline (e.g., `detector_comparison.error`)
- [ ] Overall upgrade still marked as success if ConfigMap update succeeded
- [ ] Steps list includes pipeline phase descriptions
- [ ] Audit log entry includes pipeline success/failure status

### 7.6 Pipeline Results in Audit Log
- [ ] Admin System → Audit Log → `admin.scanner.upgrade` entry includes pipeline data
- [ ] Pipeline steps visible in audit entry details
- [ ] Health score recorded in audit trail

---

## Related Tests

- [06-scanning.md](./06-scanning.md) - Scan trigger and results tests
- [22-scanner-validation.md](./22-scanner-validation.md) - Per-scanner validation
- [46-platform-admin-panel.md](./46-platform-admin-panel.md) - Admin panel tests
- [47-api-keys-security.md](./47-api-keys-security.md) - API authentication tests
