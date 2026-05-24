# Scanner Upgrade Pipeline

**Last Updated:** 2026-04-15
**API Version:** 0.37.6 (target_version validation + unit-of-work compensating revert + scanner.upgraded notification)
**Tool-Integration Version:** 0.5.46 (GITHUB_REPOS expanded to 15 scanners + upstream release-list validation)

Full pipeline that runs when an admin clicks "Upgrade" on a scanner in the Admin Portal.

## Overview

```
Admin Portal                API Service                     Tool Integration
────────────               ─────────────                   ──────────────────
Click "Upgrade" →          POST /admin/system/             POST /scanners/{name}/upgrade
                           scanners/{name}/upgrade          (internal-token authed)
                           0. Validate target_version       1. Update ConfigMap
                              (semver regex, 0.37.4)        2. Restart deployment
                           0. Pre-flight scanner-name       3. Return result
                              existence (0.37.4)
                           1. Proxy to tool-integration
                           2. On success, run pipeline:
                              a. Detector comparison
                              b. Pattern seeding
                              c. Audit validation
                           3. Update scanner_versions DB table
                           4. Return combined result
                    ←      (includes pipeline results)
```

## Phase 0: Pre-flight Validation (api-service 0.37.4)

Before any upgrade is proxied to tool-integration:

| Check | Behavior on fail |
|-------|------------------|
| `target_version` matches `^\d+\.\d+\.\d+([.+\-][A-Za-z0-9.+\-]+)?$` | 422 Unprocessable Entity (pydantic `field_validator`) |
| `target_version` length ≤ 50 | 422 |
| `reason` length ≤ 500 | 422 |
| `scanner_name` exists in tool-integration `/scanners/health` registry | 404 "Scanner not registered" |
| `scanner_name` matches `^[A-Za-z0-9_-]+$` | 400 "Invalid scanner name" |

Pre-flight soft-fails if the tool-integration `/scanners/health` endpoint is unreachable; tool-integration's own `valid_scanners` allowlist in `main.py` catches any unknown scanner as the last line of defence.

Covered by OWASP A03 analysis and a 15-case unit-test suite in `tests/unit/test_admin_scanner_upgrade_validation.py`. See `docs/audit/2026-04-15-admin-scanner-upgrade-pipeline-review.md` for the full rationale.

## Phase 4: Unit-of-Work (api-service 0.37.5)

Before calling tool-integration, the endpoint snapshots the pre-upgrade version from the `scanner_versions` table. After ConfigMap mutation succeeds, if the DB upsert fails, the endpoint **auto-reverts the ConfigMap** to the snapshotted version so cluster and DB stay consistent.

Response includes a `state` field that tells the caller the post-mutation outcome:

| `state` | ConfigMap | DB | Meaning |
|---------|-----------|----|---------|
| `applied` | new | new | Upgrade succeeded |
| `reverted` | prev | prev | DB upsert failed; compensating ConfigMap revert succeeded; no drift |
| `applied_db_stale` | new | prev | DB upsert failed; revert also failed; manual remediation required |
| `tool_integration_failed` | prev | prev | Network/timeout reaching tool-integration; ConfigMap never mutated |
| `rejected` | prev | prev | tool-integration refused the request (invalid version, conflict) |

The `state` field is the authoritative signal when `success=false`; legacy consumers that ignore it continue to work because it defaults to `"applied"`.

## Phase 0.5: Upstream Release Validation (tool-integration 0.5.46)

Between api-service's Phase 0 pre-flight and tool-integration's ConfigMap mutation, tool-integration checks the `target_version` against the published GitHub release list for the scanner:

```
api-service 0.37.4+        tool-integration 0.5.46+
─────────────────         ─────────────────────────
Layer 1: semver regex  →  Layer 3: GitHub release list
Layer 2: registry name →                           →  ConfigMap mutation
```

| Outcome | Behaviour |
|---------|-----------|
| `target_version` is in the published upstream release list | Proceed to ConfigMap mutation |
| `target_version` is not in the list | **HTTP 400** — "not a published upstream release" |
| Scanner has no `GITHUB_REPOS` mapping (sol-azy, rustdefend) | Skip the check — legacy behaviour |
| GitHub API unreachable | Soft-fail, log warning, skip the check |
| Compensating revert (target_version == current_version) | Bypass the check — previous version was always valid |

Fetch results are cached for 1 hour in the existing `_github_cache` (asyncio-locked). Residual gap: upstream cuts release X before we build + push `scanner-<name>:X` to Artifact Registry — narrow window; tracked as a future AR HEAD probe behind Workload Identity.

## Phase 5: Notification Emission (api-service 0.37.6)

After the commit / compensating-revert block, api-service emits a `scanner.upgraded` notification through the admin's configured channels (webhook, email, Slack). Severity scales with state:

| state | severity |
|-------|----------|
| `applied` | info |
| `reverted` | medium |
| `applied_db_stale` | **high** (drift — attention required) |
| `tool_integration_failed` | low |
| `rejected` | low |

Payload metadata includes `scanner_name`, `previous_version`, `new_version`, `state`, `reason`. Notification failure is best-effort — a warning is logged but the upgrade response is never blocked.

`WebhookEventType.SCANNER_UPGRADED` is stored as a JSON string in the `webhooks.events` JSONB column, so admins can subscribe per-webhook without any schema migration.

## Pipeline Phases

### Phase 1: Detector Comparison

Compares the scanner's detector list (from `seeds/{scanner}_detectors.json`) against existing `pattern_tool_mappings` in the database.

| Step | Description |
|------|-------------|
| Load detectors | Read JSON file from `seeds/` directory |
| Load existing mappings | Query `pattern_tool_mappings` for scanner |
| Compare | Identify new, changed, and removed detectors |
| Generate suggestions | Auto-suggest pattern codes for new detectors |
| Apply updates | Create new patterns/mappings, soft-deactivate removed |

**Important:** Removed detectors are soft-deactivated (`is_active = False`), never hard-deleted. Vulnerability records referencing those detectors are preserved.

**Output:** `{ new_detectors, changed_detectors, removed_detectors, mappings_added, mappings_deactivated }`

**Note:** Phase 1 requires a `seeds/{scanner}_detectors.json` file. Scanners without detector seed files skip this phase entirely but still run Phases 2 and 3. Currently no detector seed files exist in the repository — this phase is a no-op for all scanners until seed files are created.

### Phase 2: Pattern Seeding

Finds vulnerabilities in the database that lack a `pattern_code` and creates patterns/mappings for them.

| Step | Description |
|------|-------------|
| Find unmapped | Query vulnerabilities where `pattern_code IS NULL` |
| Infer category | Score-based keyword matching on detector name |
| Infer severity | Category-based severity + keyword overrides |
| Generate pattern code | `BVD-{ECOSYSTEM}-{CATEGORY_CODE}-{NNN}` format (sequential) |
| Seed to database | Insert `vulnerability_patterns` + `pattern_tool_mappings` |

Pattern seeding is **additive only** — existing patterns and mappings are never deleted or overwritten. If a pattern or mapping already exists, it is skipped.

**Output:** `{ patterns_created, mappings_created, skipped }`

### Phase 3: Audit Validation

Validates data integrity after the upgrade. This is a **read-only** operation.

| Check | Description |
|-------|-------------|
| Unmapped vulnerabilities | Count vulns still without `pattern_code` |
| Scanner coverage | % of vulnerabilities with pattern mappings |
| Health score | `100 - (unmapped / total * 100)` |

**Output:** `{ health_score, status, unmapped_vulnerabilities, scanner_coverage }`

**Health status thresholds:**
- >= 90%: `healthy`
- >= 70%: `needs_attention`
- < 70%: `critical`

## What the Pipeline Does NOT Do

| Operation | Handled By |
|-----------|-----------|
| Docker image rebuild | Host-side operation (see [Upgrade Scanner Image Playbook](../playbooks/upgrade-scanner-image.md)) |
| Deduplication maintenance | Daily Celery Beat at 04:00 UTC (or manual trigger via internal endpoint) |
| ML model retraining | Admin Portal → ML Models → Retrain Model |
| Delete old vulnerabilities | Manual clean-slate procedure (see below) |
| Delete old scans | Manual clean-slate procedure (see below) |

**API-service version sync:** The api-service `/api/v1/scanners` endpoint fetches version/developer metadata from tool-integration's `/scanners/health` at runtime with a 5-minute TTL cache. The pipeline does not need to update api-service — the UI picks up new versions automatically.

## Data Safety

**The pipeline never deletes data.** Specifically:

| Data Type | Pipeline Behavior |
|-----------|-------------------|
| Vulnerability records | Preserved (never deleted) |
| User labels (`user_classification`) | Preserved (never touched) |
| Deduplication groups | Preserved (cleaned by daily Celery Beat task) |
| ML model weights | Not touched (separate from upgrade pipeline) |
| Patterns (`vulnerability_patterns`) | Additive only (new patterns created, never deleted) |
| Mappings (`pattern_tool_mappings`) | Additive + soft-deactivate (removed detectors set `is_active = False`) |

## Error Handling

Each phase catches exceptions independently. A failure in one phase does not stop the others. The overall `pipeline.success` is `true` even if individual phases report errors (check each phase's `error` field).

## Files

| File | Role |
|------|------|
| `blocksecops-api-service/src/domain/services/scanner_upgrade_service.py` | Service module with all pipeline logic |
| `blocksecops-api-service/src/presentation/api/v1/endpoints/admin/system.py` | API endpoint that triggers the pipeline |
| `blocksecops-admin-portal/src/lib/api/admin.ts` | TypeScript types for pipeline response |
| `blocksecops-admin-portal/src/pages/AdminSystem.tsx` | UI display of pipeline results |

### Source Scripts (original CLI versions)

The service module extracts logic from these standalone scripts:

| Script | Functions extracted |
|--------|--------------------|
| `scripts/upgrade_scanner.py` | `load_scanner_detectors`, `compare_detectors`, `apply_mapping_updates` |
| `scripts/seed_scanner_patterns.py` | `find_unmapped_detectors`, `seed_patterns`, `generate_pattern_seed` |
| `scripts/audit_scanner_upgrade.py` | `audit_unmapped_vulnerabilities`, `audit_scanner_coverage` |

## API Response Shape

```json
{
  "success": true,
  "scanner": "slither",
  "previous_version": "0.10.3",
  "new_version": "0.10.4",
  "message": "Scanner upgraded successfully",
  "steps_completed": [
    "ConfigMap updated",
    "Deployment restarted",
    "Detector comparison: 3 new, 1 changed, 0 removed",
    "Pattern seeding: 2 patterns, 2 mappings",
    "Audit: health score 95.2% (healthy)"
  ],
  "pipeline": {
    "success": true,
    "steps": ["..."],
    "detector_comparison": {
      "new_detectors": 3,
      "changed_detectors": 1,
      "removed_detectors": 0,
      "mappings_added": 3,
      "mappings_deactivated": 0
    },
    "pattern_seeding": {
      "patterns_created": 2,
      "mappings_created": 2,
      "skipped": 1
    },
    "audit": {
      "health_score": 95.2,
      "status": "healthy",
      "unmapped_vulnerabilities": 5,
      "scanner_coverage": {
        "slither": {
          "total_vulnerabilities": 120,
          "mapped_vulnerabilities": 115,
          "coverage_percentage": 95.83,
          "active_mappings": 92
        }
      }
    }
  }
}
```

---

## ML Retrain (Separate from Upgrade Pipeline)

The "Retrain Model" button on the Admin Portal → ML Models page (`POST /admin/system/ml/retrain`) is **completely separate** from the scanner upgrade pipeline. It is never triggered automatically by a scanner upgrade.

### What Retrain Does

1. Queries all vulnerabilities with `user_classification` set to `"confirmed"` or `"false_positive"` (human-labeled findings)
2. Extracts 30+ features from each (scanner_id, detector_id, severity, pattern_code, confidence, code_snippet, etc.)
3. Trains a new `RandomForestClassifier` from scratch (80/20 train/test split, stratified)
4. Overwrites the previous model weights file with the new model
5. Returns accuracy and AUC-ROC metrics

### What Retrain Does NOT Do

- Does NOT delete vulnerability records
- Does NOT delete user labels (`user_classification` stays intact)
- Does NOT delete deduplication groups
- Does NOT delete patterns or mappings
- Does NOT modify any database records

The only thing replaced is the model weights file. All training data (labels, annotations, classifications) remains in the database.

### When to Retrain

| Scenario | Retrain? |
|----------|----------|
| Standard scanner upgrade (minor version bump) | No — existing model is still valid |
| Clean-slate upgrade (old data deleted, rescanned) | Yes — after labeling ~50+ new findings |
| FP-heavy upgrade (scanner fixed many false positives) | Yes — see [FP-Heavy Scanner Upgrade](#fp-heavy-scanner-upgrade-clean-slate) |
| Accumulating new user labels over time | Automatic — triggers after 100 new labels (configurable via `ML_RETRAIN_THRESHOLD`) |

### Retrain Modes

| Button | Behavior |
|--------|----------|
| **Retrain Model** | Requires minimum 200 labeled samples (configurable). Fails if insufficient data. |
| **Force Retrain** | Bypasses minimum sample check. Use when you have fewer labeled vulns but still want to train. |

---

## FP-Heavy Scanner Upgrade (Clean Slate)

When a scanner upgrade fixes a large number of false positives (e.g., SolidityDefend fixing 125+ FPs), the standard upgrade pipeline is not sufficient. Old false-positive findings will pollute data quality metrics, deduplication groups, and ML model accuracy. A clean-slate procedure is recommended.

### Why Clean Slate

| Problem | Impact |
|---------|--------|
| Old FP findings remain in database | Inflated vulnerability counts, misleading severity metrics |
| Old FP findings in deduplication groups | Groups contain findings the scanner no longer produces |
| ML model trained on old FP data | Model learned FP patterns from the old scanner version — predictions will be stale |
| Scan records with stale counts | `high_count`, `medium_count`, `low_count` on scans become inaccurate |
| Scanner effectiveness metrics skewed | Old FP findings inflate the scanner's "total findings" count |

### When to Use Clean Slate

Use the clean-slate procedure when **all** of these apply:
- The scanner upgrade fixes a **significant number** of false positives (>20% of its findings)
- The scanner is still maturing (e.g., SolidityDefend, custom/in-house tools)
- You plan to rescan all contracts with the new version
- Historical audit trail for the old version is not required

Do NOT use clean slate for mature scanners (slither, aderyn, wake) where upstream upgrades typically add detectors rather than fix FPs.

### Clean-Slate Procedure

**Prerequisites:**
- Database backup created (see [Database Management Standards](../standards/database-management.md))
- New scanner Docker image built and pushed to Harbor
- ConfigMap updated and tool-integration restarted

**Execution order matters.** Dedup groups have a NOT NULL FK on `canonical_finding_id` referencing `vulnerabilities`. You must ungroup and delete dedup groups before deleting vulnerabilities, or the DELETE will fail with a FK constraint violation.

```bash
# ─── Step 1: Database Backup ───────────────────────────────────────────
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
kubectl exec -n postgresql-local postgresql-0 -- \
  pg_dump -U blocksecops -d solidity_security -F c \
  -f /tmp/pre_cleanslate_${TIMESTAMP}.dump

kubectl cp postgresql-local/postgresql-0:/tmp/pre_cleanslate_${TIMESTAMP}.dump \
  ~/backups/solidity_security_pre_cleanslate_${TIMESTAMP}.dump

ls -lh ~/backups/solidity_security_pre_cleanslate_${TIMESTAMP}.dump

# ─── Step 2: Record Pre-Cleanup Counts ────────────────────────────────
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "
  SELECT 'vulnerabilities' AS type, COUNT(*) FROM vulnerabilities WHERE scanner_id = '<SCANNER_ID>'
  UNION ALL
  SELECT 'scans (single-scanner)', COUNT(*) FROM scans WHERE scanners_used = ARRAY['<SCANNER_ID>']::varchar[]
  UNION ALL
  SELECT 'scans (multi-scanner)', COUNT(*) FROM scans WHERE '<SCANNER_ID>' = ANY(scanners_used) AND array_length(scanners_used, 1) > 1
  UNION ALL
  SELECT 'dedup groups (scanner canonical)', COUNT(*) FROM deduplication_groups dg JOIN vulnerabilities v ON dg.canonical_finding_id = v.id WHERE v.scanner_id = '<SCANNER_ID>'
  UNION ALL
  SELECT 'user labels', COUNT(*) FROM vulnerabilities WHERE scanner_id = '<SCANNER_ID>' AND user_classification IS NOT NULL;
"

# ─── Step 3: Ungroup and Delete Dedup Groups (MUST run before Step 4) ─
# 3a: Ungroup all vulnerabilities in dedup groups whose canonical finding belongs to this scanner
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "
  UPDATE vulnerabilities SET
    deduplication_group_id = NULL,
    is_primary = TRUE,
    duplicate_count = 0
  WHERE deduplication_group_id IN (
    SELECT dg.id FROM deduplication_groups dg
    JOIN vulnerabilities v ON dg.canonical_finding_id = v.id
    WHERE v.scanner_id = '<SCANNER_ID>'
  );
"

# 3b: Delete dedup groups whose canonical finding belongs to this scanner
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "
  DELETE FROM deduplication_groups WHERE canonical_finding_id IN (
    SELECT id FROM vulnerabilities WHERE scanner_id = '<SCANNER_ID>'
  );
"

# 3c: Ungroup this scanner's vulnerabilities that are non-canonical members of other groups
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "
  UPDATE vulnerabilities SET
    deduplication_group_id = NULL,
    is_primary = TRUE,
    duplicate_count = 0
  WHERE scanner_id = '<SCANNER_ID>' AND deduplication_group_id IS NOT NULL;
"

# ─── Step 4: Delete Vulnerabilities ───────────────────────────────────
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "
  DELETE FROM vulnerabilities WHERE scanner_id = '<SCANNER_ID>';
"

# ─── Step 5: Delete Single-Scanner Scans ──────────────────────────────
# Scans that ONLY used this scanner — no useful data remains.
# NOTE: scanners_used is varchar[] — use explicit cast.
# Some single-scanner scans may have orphaned vulns from other scanners
# due to data integrity issues. Check first, delete orphans if needed.
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "
  DELETE FROM scans WHERE scanners_used = ARRAY['<SCANNER_ID>']::varchar[]
    AND id NOT IN (SELECT DISTINCT scan_id FROM vulnerabilities WHERE scan_id IS NOT NULL);
"

# ─── Step 6: Clean Empty Multi-Scanner Scans ──────────────────────────
# Multi-scanner scans where ALL vulnerabilities were from this scanner
# (0 remaining vulns after deletion) — delete these too
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "
  DELETE FROM scans
  WHERE '<SCANNER_ID>' = ANY(scanners_used)
    AND id NOT IN (SELECT DISTINCT scan_id FROM vulnerabilities WHERE scan_id IS NOT NULL);
"

# ─── Step 7: Recalculate Multi-Scanner Scan Counts ────────────────────
# Scans that used multiple scanners and still have vulns — fix severity counts
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "
  UPDATE scans SET
    critical_count = (SELECT COUNT(*) FROM vulnerabilities WHERE scan_id = scans.id AND severity = 'critical'),
    high_count = (SELECT COUNT(*) FROM vulnerabilities WHERE scan_id = scans.id AND severity = 'high'),
    medium_count = (SELECT COUNT(*) FROM vulnerabilities WHERE scan_id = scans.id AND severity = 'medium'),
    low_count = (SELECT COUNT(*) FROM vulnerabilities WHERE scan_id = scans.id AND severity = 'low')
  WHERE '<SCANNER_ID>' = ANY(scanners_used);
"

# ─── Step 8: Remove Scanner from scanners_used Array ──────────────────
# Remaining scans still list the scanner in their scanners_used array.
# Remove it so the scanner no longer appears in the UI for those scans.
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "
  UPDATE scans SET
    scanners_used = array_remove(scanners_used, '<SCANNER_ID>')
  WHERE '<SCANNER_ID>' = ANY(scanners_used);
"

# ─── Step 9: Clean Remaining Orphaned Dedup Groups ───────────────────
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "
  DELETE FROM deduplication_groups WHERE canonical_finding_id NOT IN (SELECT id FROM vulnerabilities);
"

kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "
  UPDATE vulnerabilities SET
    deduplication_group_id = NULL,
    is_primary = TRUE,
    duplicate_count = 0
  WHERE deduplication_group_id IS NOT NULL
    AND deduplication_group_id NOT IN (SELECT id FROM deduplication_groups);
"

# ─── Step 10: Trigger Deduplication Maintenance ───────────────────────
# The CronJob may fail if api-service-secrets is not available.
# Use the API endpoint instead:
curl -sk -X POST "https://app.0xapogee.com/api/v1/deduplication/maintenance/run-full-backfill" \
  -H "Authorization: Bearer <TOKEN>"

# ─── Step 11: Verify Clean Slate ─────────────────────────────────────
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "
  SELECT 'scanner in scanners_used' AS check, COUNT(*) FROM scans WHERE '<SCANNER_ID>' = ANY(scanners_used)
  UNION ALL
  SELECT 'scanner vulnerabilities', COUNT(*) FROM vulnerabilities WHERE scanner_id = '<SCANNER_ID>'
  UNION ALL
  SELECT 'total scans', COUNT(*) FROM scans
  UNION ALL
  SELECT 'total vulnerabilities', COUNT(*) FROM vulnerabilities
  UNION ALL
  SELECT 'dedup groups', COUNT(*) FROM deduplication_groups;
"

# ─── Step 12: Run Upgrade Pipeline ────────────────────────────────────
# Click "Upgrade" in Admin Dashboard, or run CLI scripts:
cd /home/pwner/Git/blocksecops-api-service
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/solidity_security" \
  .venv/bin/python scripts/seed_scanner_patterns.py --scanner <SCANNER_ID> --dry-run
# Review output, then:
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/solidity_security" \
  .venv/bin/python scripts/seed_scanner_patterns.py --scanner <SCANNER_ID> --apply

# ─── Step 13: Rescan Contracts ────────────────────────────────────────
# Trigger scans for all contracts that were previously scanned by this scanner
# Use the API or Admin Dashboard to initiate rescans

# ─── Step 14: Label New Findings ──────────────────────────────────────
# Review and label at least 50+ findings from the new scanner version
# This provides training data for the ML model

# ─── Step 15: Retrain ML Model ───────────────────────────────────────
# Admin Portal → ML Models → Force Retrain
# Or via API:
# curl -sk -X POST https://app.0xapogee.com/api/v1/admin/system/ml/retrain \
#   -H "Authorization: Bearer <TOKEN>" \
#   -H "Content-Type: application/json" \
#   -d '{"force": true, "min_samples": 50}'

# ─── Step 16: Verify ─────────────────────────────────────────────────
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "
  SELECT scanner_id, COUNT(*) AS vulns, MIN(detected_at), MAX(detected_at)
  FROM vulnerabilities
  WHERE scanner_id = '<SCANNER_ID>'
  GROUP BY scanner_id;
"
```

### Gotchas Discovered During SolidityDefend Clean Slate (2026-02-06)

| Issue | Cause | Solution |
|-------|-------|----------|
| `DELETE FROM vulnerabilities` fails with FK violation | `deduplication_groups.canonical_finding_id` has NOT NULL constraint referencing `vulnerabilities` | Ungroup and delete dedup groups BEFORE deleting vulnerabilities (Step 3) |
| `DELETE FROM scans` fails with FK violation | Other scanners' vulnerabilities reference the scan via `scan_id` | Only delete scans with 0 remaining vulnerabilities (Step 5-6) |
| `scanners_used = ARRAY['x']` type mismatch | Column is `varchar[]`, literal is `text[]` | Use explicit cast: `ARRAY['x']::varchar[]` |
| Scans still show scanner in UI after cleanup | `scanners_used` array still contains the scanner name | Remove scanner from array with `array_remove()` (Step 8) |
| CronJob dedup maintenance fails to start | Pod requires `api-service-secrets` which may not exist as a raw Secret (managed by ExternalSecrets/Vault) | Use the API endpoint `POST /deduplication/maintenance/run-full-backfill` instead (Step 10) |
| `canonical_id` column does not exist | Actual column name is `canonical_finding_id` | Use `canonical_finding_id` in all queries |

### Gotchas Discovered During RustDefend Clean Slate (2026-02-18)

| Issue | Cause | Solution |
|-------|-------|----------|
| `is_canonical` column does not exist | Actual column name is `is_primary` | Use `is_primary` in all UPDATE statements |
| `scanner_id` not on `scans` table | `scanner_id` is on `vulnerabilities`, `scans` uses `scanners_used` array | Join through `vulnerabilities` or use `scanners_used = ANY(...)` |
| PostgreSQL pod has no `psql` or `pg_dump` | Minimal container image | Run database operations via api-service pod using asyncpg |
| Pattern seeding creates mappings with title-derived detector IDs | Seeding script matches by title keywords (e.g., `integer-overflow`) but actual findings use coded IDs (e.g., `SOL-003`) | Create additional mappings for actual detector IDs and backfill `pattern_code` on existing records |
| API rate limiting during bulk rescans | 10 requests/minute rate limit | Stagger scan requests with 60s wait between batches |
| New detector types discovered after rescans | Clean-slate + rescan reveals detectors not present in old data | Run pattern seeding again after rescans complete, map to existing BVD patterns where possible |

### Post-Cleanup Verification Checklist

- [ ] Database backup created and verified (Step 1)
- [ ] Pre-cleanup counts recorded (Step 2)
- [ ] Dedup groups with scanner-canonical findings deleted (Step 3)
- [ ] Scanner vulnerabilities deleted (Step 4)
- [ ] Single-scanner scans deleted (Step 5)
- [ ] Empty multi-scanner scans deleted (Step 6)
- [ ] Multi-scanner scan severity counts recalculated (Step 7)
- [ ] Scanner removed from `scanners_used` arrays (Step 8)
- [ ] Remaining orphaned dedup groups cleaned (Step 9)
- [ ] Deduplication maintenance completed (Step 10)
- [ ] Zero scanner traces in `vulnerabilities` and `scans` tables (Step 11)
- [ ] Upgrade pipeline run — pattern seeding + audit (Step 12)
- [ ] Contracts rescanned with new scanner version (Step 13)
- [ ] At least 50 findings labeled by reviewers (Step 14)
- [ ] ML model retrained with new labeled data (Step 15)
- [ ] Scanner effectiveness shows updated metrics (Step 16)
- [ ] Audit health score >= 90% (healthy)

---

## Authentication

The API service proxies upgrade requests to tool-integration using the `X-Internal-Service-Token` header (BSO-SEC-004). The tool-integration service validates this token before allowing ConfigMap modifications.

**Fixed in v0.35.2:** The `X-Internal-Service-Token` header was missing from the proxy call, causing all upgrade attempts to receive 403 from tool-integration. The RBAC Role for the tool-integration service account was also missing the `update` verb for ConfigMaps (had `patch` only), causing K8s API 403 when replacing the ConfigMap.

## Related Documentation

- [Upgrade Scanner Image Playbook](../playbooks/upgrade-scanner-image.md) — Full manual image build + deploy steps
- [Scanner Upgrade Workflow](../workflows/scanner-upgrade-workflow.md) — Full workflow overview
- [Deduplication Workflow](../workflows/deduplication-workflow.md) — Deduplication matching strategy
- [Intelligence Pipeline Workflow](../workflows/intelligence-pipeline-workflow.md) — Vulnerability enrichment pipeline
- [Database Management Standards](../standards/database-management.md) — Backup and recovery procedures
