# Scanner Data Audit Pipeline

Systematic data integrity pipeline that validates scanner vulnerabilities, fingerprints, pattern mappings, deduplication groups, ConfigMap consistency, and ML training data across the platform.

## Overview

```
Scanner Data Audit Pipeline
────────────────────────────

Phase 1: PRE-FLIGHT          Phase 2: DATA INVENTORY       Phase 3: CONFIGMAP AUDIT
─────────────────────         ─────────────────────         ───────────────────────
Service health checks         Vuln counts per scanner       API service ConfigMap
Database connectivity         Missing field analysis        Tool-integration ConfigMap
Auth token acquisition        Severity distribution         Version comparison
Database backup               Orphan/NULL detection         API response verification
       │                              │                              │
       ▼                              ▼                              ▼
Phase 4: FINGERPRINTS         Phase 5: PATTERN MAPPING      Phase 6: DEDUP INTEGRITY
─────────────────────         ──────────────────────        ────────────────────────
Component breakdown           Unmapped detector scan        Group size vs actual
(code/ast/location/           Category→mapping alignment    Orphaned group detection
 semantic/composite)          Coverage per scanner          Canonical finding check
Gap identification            Pattern_id population         Scan severity counts
       │                              │                              │
       ▼                              ▼                              ▼
Phase 7: API VALIDATION       Phase 8: ML DATA REVIEW       Phase 9: REPORT
──────────────────────        ─────────────────────         ──────────────────
Scanner list endpoint         Label distribution            Issue classification
Scanner effectiveness         Per-scanner balance           Priority ranking
Dedup severity filter         Training data sufficiency     Fix recommendations
TI scanner health             Sol-azy/new scanner gaps      Checklist generation
```

## Trigger

- **Post-upgrade:** Run after any scanner upgrade or clean-slate operation
- **Post-cleanup:** Run after bulk vulnerability deletion or dedup maintenance
- **Periodic:** Monthly data integrity check
- **On-demand:** When data quality issues are suspected

## Services Involved

| Service | Role | Access |
|---------|------|--------|
| PostgreSQL | Source of truth for all vulnerability data | kubectl exec |
| API Service | Scanner metadata, analytics, dedup endpoints | HTTPS via Traefik |
| Tool Integration | Scanner health, ConfigMap metadata | kubectl exec (socat limitation) |
| Supabase | Auth token for API endpoints | External HTTPS |

---

## Phase 1: Pre-Flight

**Purpose:** Verify services are reachable and create a safety backup.

| Step | Command | Expected |
|------|---------|----------|
| API health | `curl -sL https://app.blocksecops.local/api/v1/health/ready` | `{"ready": true}` |
| TI health | `kubectl exec ... -- curl -s http://localhost:8005/health` | `{"status": "healthy"}` |
| DB connectivity | `kubectl exec ... -- psql -c "SELECT 1"` | `1` |
| Backup | `pg_dump -F c -f pre_audit_backup.dump` | File created |

**Blockers:** If any service is down, stop and fix before proceeding.

---

## Phase 2: Data Inventory

**Purpose:** Build a complete picture of vulnerability data per scanner.

### Query: Scanner Overview

```sql
SELECT
  scanner_id,
  COUNT(*) AS total_vulns,
  COUNT(*) FILTER (WHERE fingerprint_composite IS NULL OR fingerprint_composite = '') AS missing_fingerprint,
  COUNT(*) FILTER (WHERE pattern_id IS NULL OR pattern_id = '') AS missing_pattern,
  COUNT(*) FILTER (WHERE deduplication_group_id IS NULL) AS ungrouped
FROM vulnerabilities
GROUP BY scanner_id
ORDER BY total_vulns DESC;
```

### Metrics Collected

| Metric | Healthy Value | Degraded | Critical |
|--------|--------------|----------|----------|
| `missing_fingerprint` / total | < 5% | 5-50% | > 50% |
| `missing_pattern` / total | < 10% | 10-50% | > 50% |
| `ungrouped` / total | < 10% | 10-30% | > 30% |

### Integrity Checks

| Check | Query | Expected |
|-------|-------|----------|
| NULL scanner_id | `WHERE scanner_id IS NULL OR scanner_id = ''` | 0 |
| NULL category | `WHERE category IS NULL OR category = ''` | 0 |
| Orphaned dedup groups | `LEFT JOIN vulnerabilities ... WHERE v.id IS NULL` | 0 |
| Stale scanner refs | `WHERE scanner_id NOT IN (<valid scanner list>)` | 0 |

---

## Phase 3: ConfigMap Version Audit

**Purpose:** Detect version drift between the API service and tool-integration ConfigMaps.

### Architecture

```
tool-integration ConfigMap        API service ConfigMap         API /scanners response
(source of truth)                 (should mirror TI)           (reads from API CM)
──────────────────────           ─────────────────────         ─────────────────────
SCANNER_METADATA: {              SCANNER_METADATA: {           [{id, version, ...}]
  "slither": "0.11.5",            "slither": "0.11.5",
  "aderyn": "0.6.7",              "aderyn": "0.6.7",
  ...                             ...
}                                }
```

### How Drift Happens

The admin dashboard "Upgrade" button updates only the **tool-integration** ConfigMap via the K8s API. The API service has its own copy in a separate namespace (`api-service-local`). These get out of sync when:

1. Admin dashboard upgrades a scanner (updates TI only)
2. Manual `kubectl patch` on one ConfigMap but not the other
3. Kustomize apply on one service but not the other

### Detection

```bash
# Extract versions from both ConfigMaps
kubectl get cm scanner-versions -n api-service-local \
  -o jsonpath='{.data.SCANNER_METADATA}' | jq 'to_entries[] | "\(.key): \(.value.version)"' -r

kubectl get cm scanner-versions -n tool-integration-local \
  -o jsonpath='{.data.SCANNER_METADATA}' | jq 'to_entries[] | "\(.key): \(.value.version)"' -r
```

### Resolution

1. Copy `SCANNER_METADATA` from `blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml`
2. Paste into `blocksecops-api-service/k8s/overlays/local/api-service/scanner-versions-configmap.yaml`
3. `kubectl apply -k` the API service overlay
4. Restart API service deployment
5. Commit the change via feature branch + PR

### Files

| File | Namespace | Role |
|------|-----------|------|
| `blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml` | tool-integration-local | Source of truth |
| `blocksecops-tool-integration/k8s/overlays/local/scanner-versions-patch.yaml` | tool-integration-local | Local image overrides |
| `blocksecops-api-service/k8s/overlays/local/api-service/scanner-versions-configmap.yaml` | api-service-local | API service copy (must mirror TI) |

---

## Phase 4: Fingerprint Coverage

**Purpose:** Verify vulnerability fingerprints are populated for deduplication quality.

### Fingerprint Components

| Component | Column | Source | Used For |
|-----------|--------|--------|----------|
| Code | `fingerprint_code` | SHA-256 of code_snippet + detector_id | Primary grouping key |
| AST | `fingerprint_ast` | AST structure hash | Cross-scanner matching |
| Location | `fingerprint_location` | File + line range hash | Location-based dedup |
| Semantic | `fingerprint_semantic` | Intelligence engine embedding | Semantic similarity |
| Composite | `fingerprint_composite` | Combined hash of above | Final dedup key |

### Query: Component Breakdown

```sql
SELECT scanner_id,
  COUNT(*) AS total,
  COUNT(*) FILTER (WHERE fingerprint_code IS NOT NULL AND fingerprint_code != '') AS fp_code,
  COUNT(*) FILTER (WHERE fingerprint_ast IS NOT NULL AND fingerprint_ast != '') AS fp_ast,
  COUNT(*) FILTER (WHERE fingerprint_location IS NOT NULL AND fingerprint_location != '') AS fp_location,
  COUNT(*) FILTER (WHERE fingerprint_semantic IS NOT NULL AND fingerprint_semantic != '') AS fp_semantic,
  COUNT(*) FILTER (WHERE fingerprint_composite IS NOT NULL AND fingerprint_composite != '') AS fp_composite
FROM vulnerabilities
GROUP BY scanner_id
ORDER BY scanner_id;
```

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| fp_composite = 0 for all | Backfill never ran after initial import | Run dedup maintenance backfill |
| Scanner has 0 fingerprints | Scanner wrapper not generating fingerprint data | Fix scanner wrapper script |
| fp_semantic = 0 | Intelligence engine was down during scan | Re-run semantic fingerprinting |

---

## Phase 5: Pattern Mapping Analysis

**Purpose:** Identify vulnerabilities that lack BVD pattern classification.

### How Pattern Mapping Works

```
Scanner wrapper outputs:              pattern_tool_mappings table:
  category: "reentrancy-eth"    →     scanner_id: "slither"
                                      detector_id: "reentrancy-eth"
                                      pattern_id: "BVD-SOLIDITY-REE-001"

vulnerability.pattern_id = "BVD-SOLIDITY-REE-001"  (assigned during dedup maintenance)
```

### Gap Types

| Gap Type | Example | Cause | Fix |
|----------|---------|-------|-----|
| **Broad category** | category="reentrancy" | Scanner wrapper outputs category name, not detector ID | Fix scanner wrapper OR add mapping for category name |
| **New detector** | category="new-detector-v2" | Upstream scanner added detector, no mapping exists | Run `seed_scanner_patterns.py` |
| **Uncategorized** | category="uncategorized" | Scanner couldn't classify the finding | Manual review and mapping |

### Query: Unmapped Detector Scan

```sql
SELECT v.scanner_id, v.category AS detector_id, COUNT(*) AS vuln_count
FROM vulnerabilities v
LEFT JOIN pattern_tool_mappings ptm
  ON v.scanner_id = ptm.scanner_id AND v.category = ptm.detector_id
WHERE ptm.id IS NULL
  AND v.category IS NOT NULL AND v.category != ''
GROUP BY v.scanner_id, v.category
ORDER BY v.scanner_id, vuln_count DESC;
```

### Impact Assessment

| Missing Patterns % | Impact | Action |
|--------------------|--------|--------|
| < 5% | Low | Monitor, seed at next upgrade |
| 5-30% | Medium | Schedule pattern seeding |
| > 30% | High | Immediate pattern seeding required |

---

## Phase 6: Deduplication Group Integrity

**Purpose:** Verify dedup group metadata matches actual member counts.

### Checks

| Check | Query Approach | Fix |
|-------|---------------|-----|
| Size mismatch | Compare `group_size` vs `COUNT(*)` of members | `UPDATE group_size = actual count` |
| Orphaned groups | Canonical finding ID points to deleted vuln | Delete orphaned group |
| Scan severity drift | Recorded counts vs actual vulnerability counts | Recalculate severity counts |

### Query: Size Mismatches

```sql
SELECT dg.id, dg.group_size AS recorded,
  (SELECT COUNT(*) FROM vulnerabilities v
   WHERE v.deduplication_group_id = dg.id) AS actual
FROM deduplication_groups dg
WHERE dg.group_size != (
  SELECT COUNT(*) FROM vulnerabilities v
  WHERE v.deduplication_group_id = dg.id
);
```

### Common Causes of Size Mismatches

| Cause | When | Prevention |
|-------|------|------------|
| Clean-slate vuln deletion | After scanner clean-slate procedure | Include size recalc in clean-slate steps |
| Partial dedup maintenance failure | Maintenance job crashed mid-run | Re-run dedup maintenance |
| Manual vuln deletion | Ad-hoc DB operations | Always recalc after manual deletes |

### Fix: Bulk Size Recalculation

```sql
-- MANDATORY: Backup first
UPDATE deduplication_groups
SET group_size = (
  SELECT COUNT(*) FROM vulnerabilities
  WHERE deduplication_group_id = deduplication_groups.id
)
WHERE group_size != (
  SELECT COUNT(*) FROM vulnerabilities
  WHERE deduplication_group_id = deduplication_groups.id
);
```

---

## Phase 7: API Endpoint Validation

**Purpose:** Verify API endpoints return correct data reflecting database state.

| Endpoint | Method | What to Verify |
|----------|--------|----------------|
| `/api/v1/scanners` | GET | All 15 scanners listed, versions match ConfigMap |
| `/api/v1/analytics/scanner-effectiveness` | GET | All data-bearing scanners present, metrics populated |
| `/api/v1/deduplication/groups?severity=high` | GET | Returns groups, total > 0 |
| `/api/v1/deduplication/groups?severity=info` | GET | Returns 422 (invalid severity) |
| `/api/v1/scans?status=pending` | GET | Maps to "queued" or returns empty (not 500) |
| `/api/v1/vulnerabilities?page=1&page_size=3` | GET | Returns vulns with scanner_id, severity, pattern_id |

### Scanner Effectiveness Fields

| Field | Should Be | If NULL |
|-------|-----------|---------|
| `total_findings` | > 0 | Scanner has no vulnerability data |
| `unique_findings` | > 0 | Dedup not assigning primary status |
| `overlap_rate` | 0.0 - 1.0 | Analytics query not computing overlap |
| `false_positive_rate` | 0.0 - 1.0 | No user_classification labels exist |

---

## Phase 8: ML Training Data Review

**Purpose:** Assess ML model readiness and label quality.

### Query: Label Distribution

```sql
SELECT scanner_id, user_classification, COUNT(*)
FROM vulnerabilities
WHERE user_classification IS NOT NULL
GROUP BY scanner_id, user_classification
ORDER BY scanner_id, user_classification;
```

### Thresholds

| Metric | Minimum | Ideal |
|--------|---------|-------|
| Total labels | 50 | 500+ |
| Confirmed labels | 25 | 250+ |
| False positive labels | 25 | 250+ |
| Scanners with labels | 2 | All active |
| Class balance ratio | 30/70 | 40/60 - 60/40 |

### Flags

| Flag | Condition | Action |
|------|-----------|--------|
| Insufficient data | < 50 total labels | Label more vulns before training |
| Extreme imbalance | One class > 90% | Review labeling methodology |
| Scanner gaps | Active scanner with 0 labels | Prioritize labeling for that scanner |
| Stale labels | All labels older than 90 days | Re-validate sample of labels |

---

## Phase 9: Report Generation

### Issue Severity Classification

| Severity | Criteria | SLA |
|----------|----------|-----|
| **CRITICAL** | Data corruption, orphaned references, service returning wrong data | Fix immediately |
| **HIGH** | > 50% missing fingerprints/patterns, ConfigMap drift | Fix within 1 day |
| **MEDIUM** | Dedup size mismatches, partial metric gaps | Fix within 1 week |
| **LOW** | ML data imbalance, empty scans, minor gaps | Fix at next maintenance window |
| **INFO** | Expected state, no action needed | Document only |

### Output Format

See [Scanner Data Audit Playbook](../playbooks/scanner-data-audit.md#audit-report-template) for the report template.

---

## Error Handling

Each phase runs independently. A failure in one phase does not block subsequent phases. Phases that modify data (fixes) require explicit user confirmation and a pre-existing backup.

| Phase | Reads Data | Writes Data | Backup Required |
|-------|-----------|-------------|-----------------|
| 1. Pre-Flight | Yes | No (except backup) | Creates backup |
| 2. Data Inventory | Yes | No | No |
| 3. ConfigMap Audit | Yes | Fix: Yes (ConfigMap + restart) | No (config only) |
| 4. Fingerprints | Yes | Fix: triggers maintenance job | Yes |
| 5. Pattern Mapping | Yes | Fix: runs seeder script | Yes |
| 6. Dedup Integrity | Yes | Fix: UPDATE group_size | Yes |
| 7. API Validation | Yes | No | No |
| 8. ML Data Review | Yes | No | No |
| 9. Report | No | No (generates report) | No |

---

## Database Tables

| Table | Audit Role |
|-------|-----------|
| `vulnerabilities` | Fingerprints, pattern_id, scanner_id, category, user_classification, deduplication_group_id |
| `deduplication_groups` | Group size, canonical_finding_id, strategy |
| `pattern_tool_mappings` | Scanner-to-pattern detector mappings |
| `vulnerability_patterns` | BVD pattern definitions |
| `scans` | Severity counts, scanners_used array |
| `scanner_quality_metrics` | Per-scanner quality scores |

---

## Related Documentation

- [Scanner Data Audit Playbook](../playbooks/scanner-data-audit.md) - Step-by-step audit procedure with commands
- [Scanner Upgrade Pipeline](scanner-upgrade-pipeline.md) - Pipeline phases and clean-slate procedure
- [Deduplication Pipeline](deduplication-pipeline.md) - Daily maintenance tasks
- [Intelligence Pipeline](intelligence-pipeline.md) - Fingerprint and embedding generation
- [Database Management Standards](../standards/database-management.md) - Backup requirements
- [Tool Metadata ConfigMaps Standard](../standards/tool-metadata-configmaps.md) - ConfigMap structure
