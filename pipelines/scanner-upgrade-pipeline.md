# Scanner Upgrade Pipeline

Full pipeline that runs when an admin clicks "Upgrade" on a scanner in the Admin Portal.

## Overview

```
Admin Portal                API Service                     Tool Integration
────────────               ─────────────                   ──────────────────
Click "Upgrade" →          POST /admin/system/             POST /scanners/{name}/upgrade
                           scanners/{name}/upgrade
                           1. Proxy to tool-integration     1. Update ConfigMap
                           2. On success, run pipeline:     2. Restart deployment
                              a. Detector comparison         3. Return result
                              b. Pattern seeding
                              c. Audit validation
                           3. Return combined result
                    ←      (includes pipeline results)
```

## Pipeline Phases

### Phase 1: Detector Comparison

Compares the scanner's detector list (from `seeds/{scanner}_detectors.json`) against existing `pattern_tool_mappings` in the database.

| Step | Description |
|------|-------------|
| Load detectors | Read JSON file from `seeds/` directory |
| Load existing mappings | Query `pattern_tool_mappings` for scanner |
| Compare | Identify new, changed, and removed detectors |
| Generate suggestions | Auto-suggest pattern codes for new detectors |
| Apply updates | Create new patterns/mappings, deactivate removed |

**Output:** `{ new_detectors, changed_detectors, removed_detectors, mappings_added, mappings_deactivated }`

### Phase 2: Pattern Seeding

Finds vulnerabilities in the database that lack a `pattern_code` and creates patterns/mappings for them.

| Step | Description |
|------|-------------|
| Find unmapped | Query vulnerabilities where `pattern_code IS NULL` |
| Infer category | Score-based keyword matching on detector name |
| Infer severity | Category-based severity + keyword overrides |
| Generate pattern code | `BVD-SOL-{CATEGORY}-{SCANNER}-{DETECTOR}` format |
| Seed to database | Insert `vulnerability_patterns` + `pattern_tool_mappings` |

**Output:** `{ patterns_created, mappings_created, skipped }`

### Phase 3: Audit Validation

Validates data integrity after the upgrade.

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

## Supported Scanners

Detector comparison (Phase 1) requires a `seeds/{scanner}_detectors.json` file. Currently configured:

- `soliditydefend`
- `slither`
- `aderyn`
- `mythril`

Scanners without detector files skip Phase 1 but still run Phase 2 (pattern seeding from existing vulns) and Phase 3 (audit).

## Out of Scope

Docker image rebuild remains a host-side operation and is not part of this pipeline. The pipeline only handles database-side intelligence operations after the ConfigMap update and pod restart.
