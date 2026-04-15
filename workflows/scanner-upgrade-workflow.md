# Scanner Upgrade Workflow

**Last Updated:** March 19, 2026
**Status:** Active
**API Version:** 0.35.2

---

## Overview

The scanner upgrade workflow updates scanner version metadata, validates detector changes, seeds new patterns, and triggers deduplication maintenance. It can be initiated manually (CLI scripts) or via the Admin Dashboard "Upgrade" button.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       SCANNER UPGRADE WORKFLOW                              │
│                                                                             │
│   Version Check (Automated)                                                 │
│        │                                                                    │
│        ▼                                                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │ Phase 1: VERSION UPDATE                                             │  │
│   │ Update ConfigMap metadata + restart tool-integration pod            │  │
│   │ Method: Admin Dashboard button OR manual ConfigMap patch            │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│        │                                                                    │
│        ▼                                                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │ Phase 2: DOCKER IMAGE BUILD (Host-Side)                             │  │
│   │ Rebuild scanner image with new upstream version                     │  │
│   │ Push to Harbor registry                                             │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│        │                                                                    │
│        ▼                                                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │ Phase 3: DETECTOR COMPARISON                                        │  │
│   │ Compare old vs new detector lists                                   │  │
│   │ Identify added/removed/renamed detectors                            │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│        │                                                                    │
│        ▼                                                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │ Phase 4: PATTERN SEEDING                                            │  │
│   │ Create vulnerability_patterns for unmapped detectors                │  │
│   │ Uses: seed_scanner_patterns.py                                      │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│        │                                                                    │
│        ▼                                                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │ Phase 5: AUDIT & VALIDATION                                         │  │
│   │ Verify coverage, run test scan, validate results                    │  │
│   │ Uses: audit_scanner_upgrade.py                                      │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│        │                                                                    │
│        ▼                                                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │ Phase 6: DEDUPLICATION MAINTENANCE                                  │  │
│   │ Re-run deduplication for affected contracts                         │  │
│   │ Daily Celery Beat handles this automatically (04:00 UTC)             │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│        │                                                                    │
│        ▼                                                                    │
│   Scanner upgrade complete                                                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Services Involved

| Service | Role | Port |
|---------|------|------|
| Tool Integration | Scanner metadata management, ConfigMap patching | 8005 |
| API Service | Proxy endpoint, admin auth, audit logging | 8000 |
| Admin Portal | "Upgrade" button UI on Admin System page | 3000 |
| PostgreSQL | Scanner patterns, vulnerability storage | 5432 |
| Intelligence Engine | Embedding generation for deduplication | 80 (internal) |

---

## Upgrade Methods

### Method 1: Admin Dashboard (Full Pipeline)

The Admin Dashboard provides an "Upgrade" button for scanners that show a newer version available (yellow `→ x.y.z` indicator on the Admin System → Security Scanners table). As of API Service v0.25.9, this button runs the **full upgrade pipeline** including database-side intelligence operations.

**What it does:**
1. Validates scanner name
2. Proxies to tool-integration to update ConfigMap metadata
3. Tool-integration reads `scanner-versions` ConfigMap via K8s API
4. Updates `SCANNER_METADATA` version field and patches ConfigMap
5. Triggers deployment rollout restart
6. On success, API service runs the upgrade pipeline:
   - **Detector comparison** — compares detector list against existing mappings
   - **Pattern seeding** — creates patterns for unmapped vulnerabilities
   - **Audit validation** — calculates coverage and health score
7. Updates `scanner_versions` database table with new version (immediate, not waiting for pod restart)
8. Returns combined result with pipeline data

**What it does NOT do:**
- Rebuild Docker images (requires host-side Docker access)
- Trigger deduplication (handled by daily Celery Beat at 04:00 UTC)

**API Flow:**
```
Admin Portal                API Service                     Tool Integration
─────────────              ─────────────                   ──────────────────
Click "Upgrade" →          POST /admin/system/             POST /scanners/{name}/upgrade
                           scanners/{name}/upgrade
                           1. Proxy to tool-integration     1. Validate scanner name
                           2. On success, run pipeline:     2. Read ConfigMap via K8s API
                              a. Detector comparison        3. Update SCANNER_METADATA
                              b. Pattern seeding            4. Patch ConfigMap
                              c. Audit validation           5. Update in-memory metadata
                           3. Return combined result    ←   6. Trigger rollout restart
                    ←      (includes pipeline results)
```

Each pipeline phase catches exceptions independently so a failure in one phase does not stop others. Phase errors are captured in the response (e.g., `detector_comparison.error`) rather than failing the entire upgrade.

### Method 2: CLI Scripts (Manual Pipeline)

For running individual pipeline phases manually, or for a complete upgrade including Docker image rebuild:

```bash
# Phase 1: Update Dockerfile and build image
# See playbook: docs/playbooks/upgrade-scanner-image.md

# Phase 2: Detector comparison
cd /home/pwner/Git/blocksecops-api-service
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/solidity_security" \
  .venv/bin/python scripts/upgrade_scanner.py --scanner <scanner_id> --new-version <version>

# Phase 3: Pattern seeding (dry-run first)
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/solidity_security" \
  .venv/bin/python scripts/seed_scanner_patterns.py --scanner <scanner_id> --dry-run

# Phase 3: Pattern seeding (apply)
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/solidity_security" \
  .venv/bin/python scripts/seed_scanner_patterns.py --scanner <scanner_id> --apply

# Phase 4: Audit validation
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/solidity_security" \
  .venv/bin/python scripts/audit_scanner_upgrade.py --scanner <scanner_id>
```

---

## Phase Details

### Phase 1: Version Update

**Trigger:** Admin clicks "Upgrade" button or manual ConfigMap edit.

**ConfigMap:** `scanner-versions` in `tool-integration-local` namespace.

**Data format:**
```json
{
  "slither": {
    "version": "0.10.4",
    "developer": "Crytic/Trail of Bits",
    "_note": "Updated 2026-02-05 via admin dashboard"
  }
}
```

**RBAC Requirements:**
The tool-integration ServiceAccount needs:
- `configmaps`: `get`, `patch`
- `deployments`: `get`, `patch`

These are defined in `blocksecops-tool-integration/k8s/base/rbac.yaml`.

### Phase 2: Docker Image Build

**Host-side operation** — pods don't have Docker socket access.

See [Upgrade Scanner Image Playbook](../playbooks/upgrade-scanner-image.md) for full build instructions.

**Key steps:**
1. Update Dockerfile with new upstream version
2. Build with `--no-cache` (or without, depending on requirements)
3. Push to Harbor: `harbor.blocksecops.local/blocksecops/scanner-<name>:<version>`
4. Update ConfigMap `SCANNER_IMAGE_<NAME>` entry
5. Restart tool-integration deployment

### Phase 3: Detector Comparison

**Script:** `blocksecops-api-service/scripts/upgrade_scanner.py`

**Purpose:** Compare old vs new detector lists to identify:
- New detectors added in the upgrade
- Detectors removed or deprecated
- Detectors renamed (requiring mapping updates)

**Output:**
```
Scanner: slither
Old detectors: 93
New detectors: 97
Added: reentrancy-no-eth, unchecked-transfer, ...
Removed: (none)
```

### Phase 4: Pattern Seeding

**Script:** `blocksecops-api-service/scripts/seed_scanner_patterns.py`

**Purpose:** Create `vulnerability_patterns` database entries for new detectors that don't have pattern mappings yet. This ensures:
- New detectors get BVD (Apogee Vulnerability Database) codes
- Findings from new detectors are properly categorized
- Deduplication can match findings across scanners

**Dry-run first:** Always run with `--dry-run` to review before applying.

### Phase 5: Audit & Validation

**Script:** `blocksecops-api-service/scripts/audit_scanner_upgrade.py`

**Purpose:** Validate the upgrade was successful:
- All detectors have pattern mappings
- Coverage percentage meets threshold
- Test scan produces expected results
- No regressions in existing findings

### Phase 6: Deduplication Maintenance

**Automated:** Daily Celery Beat at 04:00 UTC (`dedup.daily_maintenance` via orchestration service).

**20 maintenance tasks** including:
- Re-fingerprint findings with empty fingerprints
- Merge overlapping deduplication groups
- Update canonical selections
- Clean orphaned groups

After a scanner upgrade, the next daily maintenance run will automatically process any new findings from rescans.

---

## Version Detection

The tool-integration service checks for newer versions using the GitHub API:

**Mapping:** `GITHUB_REPOS` dict in `blocksecops-tool-integration/src/main.py` (tool-integration 0.5.45).

Format: `scanner_id -> (owner/repo, tag_prefix)`. `tag_prefix` is stripped from the GitHub release `tag_name` to yield a plain semver; empty string means the upstream tags without a prefix.

```python
GITHUB_REPOS = {
    # Solidity (10 of 10)
    "slither":         ("crytic/slither", "v"),
    "aderyn":          ("Cyfrin/aderyn", "aderyn-v"),
    "soliditydefend":  ("AdvancedBlockchainSecurity/SolidityDefend", "v"),
    "solhint":         ("protofire/solhint", "v"),
    "semgrep":         ("semgrep/semgrep", "v"),
    "echidna":         ("crytic/echidna", "v"),
    "halmos":          ("a16z/halmos", "v"),
    "wake":            ("Ackee-Blockchain/wake", "v"),
    "medusa":          ("crytic/medusa", "v"),
    "mythril":         ("ConsenSysDiligence/mythril", "v"),
    # Vyper (2 of 2)
    "vyper":           ("vyperlang/vyper", "v"),
    "moccasin":        ("Cyfrin/moccasin", ""),
    # Solana/Rust (3 of 5)
    "sec3-xray":       ("sec3-product/x-ray", "v"),
    "trident":         ("Ackee-Blockchain/trident", ""),
    "cargo-fuzz-solana": ("rust-fuzz/cargo-fuzz", ""),
}
```

**Coverage:** 15 of 17 registered scanners. The remaining two are deliberate exclusions:
- `sol-azy` (FuzzingLabs/sol-azy) — upstream has no releases or tags
- `rustdefend` — internal-only scanner, no public upstream

**Cache:** 1-hour TTL (`_github_cache` with timestamp check, `_github_cache_lock` mutex for thread safety).

**Display:** Admin System → Security Scanners table shows:
- Current version (from ConfigMap `SCANNER_METADATA`)
- Latest version (from GitHub API, shown as yellow `→ x.y.z` when different)
- "Upgrade" button appears when versions differ
- Scanners without a `GITHUB_REPOS` entry show no latest-version indicator and no upgrade button

## Validation layers (in order)

An upgrade request passes through four independent validation layers before the ConfigMap is mutated. Each layer catches a different class of mistake; together they close the admin-facing gaps surfaced in the 2026-04-15 pipeline review.

### Layer 1 — `target_version` semver shape (api-service 0.37.4)

Strict regex on `ScannerUpgradeRequest.target_version`:

```python
_SCANNER_VERSION_RE = re.compile(r"^\d+\.\d+\.\d+([.+\-][A-Za-z0-9.+\-]+)?$")
```

Accepts `MAJOR.MINOR.PATCH` with optional PEP440-style suffix (`-rc1`, `.post1`, `+build5`). Rejects empty, letters-only, shell metachars, XSS payloads, path-traversal chars, whitespace.

### Layer 2 — scanner-name existence (api-service 0.37.4)

Pre-flight call to tool-integration `/scanners/health` — returns 404 if `scanner_name` is not in the current registry. Soft-fails if the health endpoint is unreachable; tool-integration's own allowlist is the last line of defence.

### Layer 3 — upstream GitHub release list (tool-integration 0.5.46)

Before mutating the ConfigMap, tool-integration fetches (with 1-hour cache) the list of published GitHub releases for the scanner. If `target_version` is not in that list, returns **400** with "not a published upstream release".

```python
known = await get_known_github_versions(scanner_name)
if known is not None and body.target_version not in known:
    raise HTTPException(400, "target_version ... is not a published upstream release")
```

Exceptions:
- Scanners without a `GITHUB_REPOS` entry (sol-azy, rustdefend) bypass the check (legacy behaviour)
- Compensating reverts from api-service fix #5 (target_version equals current_version) bypass the check — always targets a previously-valid version

Residual gap: "upstream cut release X but we haven't built + pushed our scanner image for X yet". Narrow window (minutes to hours given the build pipeline). Future closure: Artifact Registry HEAD probe behind Workload Identity — tracked, not scheduled.

### Layer 4 — Kubernetes admission (existing, always on)

If layers 1–3 are bypassed or wrong, the Deployment rollout still fails cleanly: kubelet gets `ImagePullBackOff`, the `CronJobPodConfigError` alert fires within 5 min, and manual remediation is well-documented in `docs/playbooks/upgrade-scanner-image.md`.

See `docs/audit/2026-04-15-admin-scanner-upgrade-pipeline-review.md` for the full pipeline audit (5 of 6 fixes shipped; #3 rollback endpoint queued).

---

## Verification

After completing a scanner upgrade:

```bash
# 1. Verify ConfigMap updated
kubectl get cm scanner-versions -n tool-integration-local \
  -o jsonpath='{.data.SCANNER_METADATA}' | jq '.<scanner>.version'

# 2. Verify scanner health
curl -s http://127.0.0.1:8005/scanners/health | jq '.<scanner>'

# 3. Verify via Admin Dashboard API
curl -s http://127.0.0.1:8000/api/v1/admin/system/scanners/health | jq '.scanners.<scanner>'

# 4. Run test scan
curl -X POST "http://127.0.0.1:8000/api/v1/scans" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <TOKEN>" \
  -d '{"contract_id": "<ID>", "scanner_ids": ["<scanner>"]}'

# 5. Check audit log
# Admin System → Audit Log → filter by "admin.scanner.upgrade"
```

---

## FP-Heavy Scanner Upgrades

When a scanner upgrade fixes a large number of false positives (>20% of findings), the standard workflow above is not sufficient. Old false-positive findings will pollute data quality, deduplication groups, and ML predictions.

**Use the Clean-Slate Procedure** documented in the [Scanner Upgrade Pipeline — FP-Heavy Scanner Upgrade](../pipelines/scanner-upgrade-pipeline.md#fp-heavy-scanner-upgrade-clean-slate).

This applies to maturing scanners like SolidityDefend and RustDefend where upstream releases may fix large batches of FPs. It does NOT apply to mature scanners (slither, aderyn, wake) where upgrades typically add detectors rather than fix FPs.

**Completed clean-slate upgrades:**
- **SolidityDefend** (2026-02-06): 10,515 old findings deleted, 34 new findings after rescan
- **RustDefend** (2026-02-18): 9 old findings deleted, 46 new findings across 13 contracts, 100% pattern coverage

**Summary of clean-slate steps:**
1. Database backup
2. Delete old vulnerabilities for the scanner
3. Delete single-scanner scans (scans that only used this scanner)
4. Recalculate severity counts on multi-scanner scans
5. Clean orphaned deduplication groups
6. Trigger deduplication maintenance
7. Run upgrade pipeline (pattern seeding + audit)
8. Rescan all contracts with new scanner version
9. Label new findings
10. Retrain ML model (Admin Portal → ML Models → Force Retrain)
11. Verify health score

---

## Related Documentation

- [Scanner Upgrade Pipeline](../pipelines/scanner-upgrade-pipeline.md) - Pipeline phases, ML retrain, and clean-slate procedure
- [Upgrade Scanner Image Playbook](../playbooks/upgrade-scanner-image.md) - Full manual upgrade steps
- [Deduplication Workflow](./deduplication-workflow.md) - Deduplication matching strategy
- [Smart Contract Scanning Workflow](./smart-contract-scanning-workflow.md) - Scan execution flow
- [Tool Metadata ConfigMaps Standard](../standards/tool-metadata-configmaps.md) - ConfigMap structure
- [Docker Image Versioning Standards](../standards/docker-image-versioning.md) - Image versioning
- [Scanner Documentation](../scanners/README.md) - Scanner management guides
- [Scanner Version Tracking Database](../database/SCANNER-VERSION-TRACKING.md) - DB schema for version tracking
