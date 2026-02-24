# Deduplication Workflow

**Last Updated:** February 23, 2026
**Status:** Active
**API Version:** 0.29.12+

---

## Overview

The deduplication system uses a hybrid architecture with two execution paths:

1. **Inline post-scan maintenance** — 4 scoped tasks run during scan result ingestion (sub-second)
2. **Weekly housekeeping** — Full 18-task sweep via CronJob (Sunday 2 AM UTC)

This ensures findings have fingerprints, consensus scores, and group assignments before the API response returns.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DEDUPLICATION WORKFLOW                               │
│                                                                             │
│   Scanner Results Stored (store_scan_results)                               │
│        │                                                                    │
│        ▼                                                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │ Phase 1: INTRA-SCAN DEDUPLICATION                                   │  │
│   │ Groups duplicates within the same scan                              │  │
│   │ Uses: fingerprint_location matching                                 │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│        │                                                                    │
│        ▼                                                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │ Phase 2: CROSS-SCAN DEDUPLICATION                                   │  │
│   │ Groups duplicates across prior scans of same contract               │  │
│   │ Uses: 5-tier matching (fingerprint + semantic)                      │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│        │                                                                    │
│        ▼                                                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │ Phase 3: INLINE POST-SCAN MAINTENANCE (v0.29.11)                    │  │
│   │ Runs 4 scoped tasks immediately after vulns created:                │  │
│   │ • Fuzzy fingerprints (scan-scoped)                                  │  │
│   │ • Semantic fingerprints (scan-scoped)                               │  │
│   │ • Tool consensus scores (contract-scoped)                           │  │
│   │ • Orphan grouping (contract-scoped)                                 │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│        │                                                                    │
│        ▼                                                                    │
│   Vulnerabilities fully fingerprinted + grouped in response                 │
│                                                                             │
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│                                                                             │
│   Weekly CronJob (Sunday 2 AM UTC)                                          │
│        │                                                                    │
│        ▼                                                                    │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │ WEEKLY HOUSEKEEPING                                                 │  │
│   │ Full 18-task sweep: cleanup, fingerprints, grouping, analytics,    │  │
│   │ scanner quality, ML feedback, active learning                      │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Services Involved

| Service | Role | Port |
|---------|------|------|
| API Service | Deduplication orchestration | 8000 |
| Intelligence Engine | Embedding generation for semantic matching | 80 (internal) |
| PostgreSQL | Vulnerability and group storage | 5432 |

---

## 5-Tier Matching Strategy

The `DeduplicationMatcher` implements hierarchical matching from most precise to least precise:

| Tier | Level | Confidence | Strategy | Description |
|------|-------|------------|----------|-------------|
| 1 | EXACT | 99% | `code_hash + location_hash` | Identical code at identical location |
| 2 | HIGH | 95% | `code_hash + fuzzy_location` | Same code, slightly different location |
| 3 | MEDIUM | 85% | `ast_hash + fuzzy_location` | Same structure, different formatting |
| 4 | LOW | 75% | `pattern_code + fuzzy_location` | Same vulnerability type at similar location |
| 5 | SEMANTIC | 80%+ | `embedding_similarity` | Semantically similar (via Intelligence Engine) |

**Matching stops at the first successful match.**

---

## Phase 1: Intra-Scan Deduplication

**Purpose:** Group duplicate findings within the same scan (e.g., multiple scanners reporting the same issue).

**Trigger:** After vulnerabilities are stored for a scan.

**Algorithm:**
1. Find vulnerabilities with matching `fingerprint_location` within the scan
2. Group by `detector_id` + `fingerprint_location` (prevents cross-type grouping — e.g., reentrancy and integer-overflow at the same location are not grouped together)
3. Select canonical finding (highest priority scanner)
4. Create `DeduplicationGroup` with all findings

**Scanner Priority (for canonical selection):**

Derived from scanner registry order in `src/infrastructure/scanner_config/scanners.py`. Lower number = higher priority.

```python
DEFAULT_SCANNER_PRIORITY = {
    "slither": 1,           # Highest priority (Solidity)
    "aderyn": 2,            # Solidity
    "semgrep": 3,           # Solidity
    "solhint": 4,           # Solidity
    "halmos": 5,            # Formal verification
    "echidna": 6,           # Fuzzing
    "wake": 7,              # Solidity
    "medusa": 8,            # Fuzzing
    "soliditydefend": 9,    # Solidity (BlockSecOps)
    "vyper": 10,            # Vyper
    "moccasin": 11,         # Vyper
    "sol-azy": 12,          # Solana
    "sec3-xray": 13,        # Solana
    "trident": 14,          # Solana fuzzing
    "cargo-fuzz-solana": 15,# Solana fuzzing
}
```

Dynamic priorities from `DynamicScannerPriority` override static defaults when sufficient quality data exists (10+ labeled findings per scanner).

**Location:** `src/presentation/api/v1/endpoints/scans.py` → `_process_scan_deduplication()`

---

## Phase 2: Cross-Scan Deduplication

**Purpose:** Link new findings to existing findings from prior scans of the same contract.

**Trigger:** After intra-scan deduplication completes.

**Algorithm:**
1. Query existing vulnerabilities from prior scans (same contract_id)
2. For each new vulnerability (including those with intra-scan groups):
   - **Level 1 (EXACT, 99%):** Match `fingerprint_code` + `fingerprint_location`
   - **Level 2 (HIGH, 95%):** Match `fingerprint_code` + `fingerprint_location_fuzzy`
   - **Level 3 (MEDIUM, 85%):** Match `fingerprint_ast` + `fingerprint_location_fuzzy` (same detector)
   - **Level 4 (LOW, 75%):** Match `pattern_code` + `fingerprint_location_fuzzy` (same detector)
   - **Level 5 (SEMANTIC, 80%+):** Use Intelligence Engine embeddings (cosine similarity)

3. On match found:
   - Link to existing `deduplication_group_id`
   - Update `occurrence_count` and `last_seen`
   - Set `is_duplicate = True`, `is_primary = False`
   - **If vulnerability has intra-scan group:** Track for merging

4. **Group Merging (Bug Fix - February 4, 2026):**
   - After processing all vulnerabilities, merge intra-scan groups into cross-scan groups
   - Update all vulnerabilities in intra-scan group to point to cross-scan group
   - Delete empty intra-scan groups

5. If no match:
   - Vulnerability remains standalone (may become group leader later)

**Location:** `src/presentation/api/v1/endpoints/scans.py` → `_process_cross_scan_deduplication()`

### Bug Fix History

**February 4, 2026 (v0.25.0):** Fixed critical bug where cross-scan deduplication skipped vulnerabilities that already had `deduplication_group_id` from intra-scan deduplication. The fix:
- Processes ALL vulnerabilities regardless of existing group assignment
- Tracks intra-scan groups that need to be merged into cross-scan groups
- Merges groups by updating all vulnerabilities to point to the cross-scan group
- Deletes empty intra-scan groups after merging

**Commit:** `6775677` - `fix(deduplication): Fix cross-scan deduplication to handle intra-scan groups`

---

## Semantic Matching

When fingerprint matching fails, semantic matching uses the Intelligence Engine to find similar vulnerabilities.

### Flow

```
New Vulnerability
      │
      ▼
┌─────────────────┐
│ Build text repr │  title + description + code_snippet + category + severity
└─────────────────┘
      │
      ▼
┌─────────────────┐
│ Intelligence    │  POST /api/v1/embeddings
│ Engine          │  → Returns 384-dim embedding vector
└─────────────────┘
      │
      ▼
┌─────────────────┐
│ Cosine          │  Compare against candidate embeddings
│ Similarity      │  Threshold: 0.85
└─────────────────┘
      │
      ▼
Match found if similarity >= 0.85
```

### Configuration

| Setting | Value | Description |
|---------|-------|-------------|
| Model | all-MiniLM-L6-v2 | 384-dimensional embeddings |
| Threshold | 0.85 | Minimum similarity for match |
| Max Candidates | 50 | Limit per detector type |
| Timeout | 30s | HTTP timeout for embedding calls |

**Location:** `src/ml/semantic_deduplicator.py`

---

## Data Model

### DeduplicationGroup

```python
class DeduplicationGroupModel(Base):
    __tablename__ = "deduplication_groups"

    id: UUID
    canonical_finding_id: UUID      # Primary/representative vulnerability
    contract_id: UUID               # Scoped to contract
    pattern_code: str               # BVD pattern code
    group_size: int                 # Number of findings in group
    strategy: str                   # Matching strategy used
    confidence: float               # Match confidence (0.0-1.0)

    # Fingerprints
    fingerprint_code: str
    fingerprint_ast: str
    fingerprint_semantic: str

    # Statistics
    severity_distribution: dict     # {"high": 2, "medium": 1}
    scanner_distribution: dict      # {"slither": 2, "mythril": 1}

    # Tracking
    first_detected: datetime
    last_updated: datetime

    # Verification
    verified: bool
    verified_by: UUID | None
    verified_at: datetime | None
```

### Vulnerability Fields

```python
# Deduplication-related fields on VulnerabilityModel
deduplication_group_id: UUID | None
is_primary: bool                    # True if canonical finding
is_duplicate: bool                  # True if part of a group (non-primary)
deduplication_strategy: str         # Strategy that matched
deduplication_confidence: float     # Match confidence
duplicate_count: int                # Number of duplicates (on primary only)

# Historical tracking
first_seen: datetime
last_seen: datetime
occurrence_count: int               # Times seen across scans
```

---

## API Endpoints

### Deduplication Statistics
```bash
GET /api/v1/deduplication/stats
```

Response:
```json
{
  "total_groups": 150,
  "total_findings": 500,
  "avg_group_size": 3.3,
  "dedup_rate": 0.42,
  "strategy_distribution": {
    "exact_code": 50,
    "location_type": 30,
    "semantic": 20
  }
}
```

### List Deduplication Groups
```bash
GET /api/v1/deduplication/groups?limit=10&offset=0
```

### Get Group Details
```bash
GET /api/v1/deduplication/groups/{group_id}
```

### Set Canonical Finding
```bash
PUT /api/v1/deduplication/groups/{group_id}/canonical
Content-Type: application/json

{
  "vulnerability_id": "uuid-of-new-canonical"
}
```

### Merge Groups
```bash
POST /api/v1/deduplication/groups/merge
Content-Type: application/json

{
  "group_ids": ["group-1-uuid", "group-2-uuid"]
}
```

### Find Matches for Vulnerability
```bash
GET /api/v1/deduplication/vulnerabilities/{vuln_id}/matches
```

---

## Processing Flow in Code

### Scan Results Storage (scans.py)

```python
# After vulnerabilities are created...

# Phase 1: Intra-scan deduplication
intra_stats = await _process_scan_deduplication(
    db=db,
    scan_id=scan_id,
    contract_id=scan.contract_id,
)
# Groups duplicates within this scan

# Phase 2: Cross-scan deduplication
cross_stats = await _process_cross_scan_deduplication(
    db=db,
    scan_id=scan_id,
    contract_id=scan.contract_id,
    new_vulnerability_ids=created_vulnerability_ids,
)
# Links to existing groups from prior scans

# Phase 3: Inline post-scan maintenance (v0.29.11)
post_scan_stats = await run_post_scan_maintenance(
    db=db,
    scan_id=scan_id,
    contract_id=scan.contract_id,
)
# Generates fingerprints, consensus scores, orphan groups inline
```

---

## Troubleshooting

### No Cross-Scan Matches Found

1. **Check existing vulnerabilities exist:**
   ```sql
   SELECT COUNT(*) FROM vulnerabilities
   WHERE contract_id = 'uuid' AND scan_id != 'current-scan-uuid';
   ```

2. **Verify fingerprints are generated:**
   ```sql
   SELECT fingerprint_code, fingerprint_location
   FROM vulnerabilities WHERE scan_id = 'scan-uuid';
   ```

3. **Check Intelligence Engine connectivity:**
   ```bash
   kubectl exec -n blocksecops-api-service-local deploy/blocksecops-api-service -- \
     curl -s http://intelligence-engine.intelligence-engine-local.svc.cluster.local:80/api/v1/health/ready
   ```

### Semantic Matching Disabled

If logs show "Semantic deduplication disabled":

1. **Intelligence Engine not running:**
   ```bash
   kubectl get pods -n intelligence-engine-local
   ```

2. **Environment variable misconfigured:**
   ```bash
   kubectl exec -n blocksecops-api-service-local deploy/blocksecops-api-service -- \
     env | grep INTELLIGENCE
   ```

### Group Statistics Don't Match

Run maintenance to recalculate:
```bash
curl -X POST http://127.0.0.1:8000/api/v1/deduplication/maintenance/recalculate-stats \
  -H "Authorization: Bearer $TOKEN"
```

---

## Known Issues

### Fingerprint Code Generation (Discovered February 4, 2026)

Some scanner parsers generate empty fingerprint codes (SHA256 of empty string: `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`). This prevents fingerprint-based cross-scan matching from working correctly.

**Impact:** Cross-scan deduplication falls back to semantic matching only when fingerprint codes are empty.

**To Verify:**
```sql
-- Check for empty fingerprint codes (all same hash = problem)
SELECT DISTINCT fingerprint_code, COUNT(*)
FROM vulnerabilities
WHERE contract_id = 'your-contract-uuid'
GROUP BY fingerprint_code
ORDER BY COUNT(*) DESC;
```

**Status:** Improved in Deduplication Audit (February 4, 2026). MythrilParser completely rewritten, code_snippet extraction improved in SlitherParser, AderynParser, EchidnaParser, MedusaParser.

---

## Audit Fixes (February 4, 2026)

The comprehensive deduplication and metadata audit addressed 27 issues. Key improvements:

| Fix | Impact |
|-----|--------|
| MythrilParser complete rewrite | Mythril scans now produce vulnerability findings |
| Code snippet extraction improved | 6 parsers now extract meaningful code context |
| SWC-ID mapping implemented | 45+ detector-to-SWC mappings with fallback |
| avg_time_to_fix calculation | Patterns now show average fix times |
| 5 new database indexes | Improved query performance for dedup fields |
| ORM relationships added | `vuln.deduplication_group` and `vuln.pattern` navigation |
| Cascade delete fix | Changed to SET NULL to prevent orphaned records |

See: [Deduplication & Metadata Audit Fixes Changelog](/docs/changelogs/DEDUPLICATION-METADATA-AUDIT-FIXES-2026-02-04.md)

---

## Multi-Level Matching Audit Fixes (February 15, 2026)

The multi-level matching audit discovered that the `DeduplicationMatcher` (5-level) was never used by automated paths. Key fixes:

| Fix | Impact |
|-----|--------|
| Task 7 uses `DeduplicationMatcher` | Orphan grouping now uses all 5 levels instead of location-only |
| Cross-scan MEDIUM + LOW levels added | Missing AST (85%) and pattern (75%) matching levels restored |
| Intra-scan `detector_id` scoping | Prevents cross-type grouping (e.g., reentrancy + integer-overflow) |
| Semantic fingerprint retry | Exponential backoff for transient IE failures (max 3 retries, 30s cap) |
| Scanner ID validation guard | Prevents empty `scanner_id` in scan ingest |

See: [Multi-Level Matching Audit Changelog](/docs/changelogs/API-SERVICE-DEDUP-MULTILEVEL-MATCHING-AUDIT-2026-02-15.md)

---

## Hybrid Deduplication Architecture (February 23, 2026)

v0.29.11 introduced inline post-scan maintenance, eliminating the delay between scan completion and dedup processing:

| Change | Before (v0.29.10) | After (v0.29.11) |
|--------|-------------------|-------------------|
| Fingerprints | Generated by daily CronJob | Generated inline during scan ingestion |
| Consensus scores | Calculated by daily CronJob | Calculated inline (contract-scoped) |
| Orphan grouping | Daily CronJob | Inline (contract-scoped) |
| CronJob schedule | Daily (2 AM) | Weekly Sunday (2 AM) |
| CronJob deadline | 1 hour | 2 hours |
| User experience | Findings unfingerprinted until next CronJob | Findings fully processed in response |

See: [Hybrid Deduplication Changelog](/docs/changelogs/API-SERVICE-V0.29.11-HYBRID-DEDUPLICATION-2026-02-23.md)

---

## Testing & Regression Prevention

### Adding a New Task to the Pipeline

When adding Task 21+, these tests will catch missing invariants:

1. Add try/except/rollback block — enforced by `test_every_task_has_try_block`
2. Add `db.rollback()` in except — enforced by `test_every_task_has_rollback`
3. Update task count — enforced by `test_all_20_tasks_present`
4. Add result key to return dict — enforced by `test_return_dict_has_all_task_keys`
5. Add function to task list — enforced by `TestTaskFunctionsExist`

### Modifying Intelligence Engine Integration

When changing IE URL, timeout, or retry behavior, these tests cover it:

| Test File | What It Validates |
|-----------|-------------------|
| `test_semantic_deduplicator_config.py` | URL resolution structural tests (source parsing) |
| `test_ie_url_resolution.py` | URL resolution functional tests (env var → config → fallback) |
| `test_semantic_deduplicator_retry.py` | Retry behavior: backoff delays, max retries, error types |
| `test_cronjob_gcp_overlay.py` | GCP IE URL uses correct namespace |

### Modifying CronJob Configuration

When changing schedule, resources, sidecar, or env vars:

| Test File | What It Validates |
|-----------|-------------------|
| `test_cronjob_manifest.py` | Base CronJob invariants (schedule, deadline, env vars, security) |
| `test_cronjob_production_overlay.py` | Production overlay (image tags, namespace) |
| `test_cronjob_gcp_overlay.py` | GCP overlay (Cloud SQL Proxy, `--quitquitquit`, Workload Identity) |

### CI/CD Integration

```bash
# All unit tests — no cluster or external services needed
pytest tests/unit/ -v -o "addopts="

# Cross-repo tests (GCP overlay) skip gracefully if sibling repo absent
# pytestmark = pytest.mark.skipif(not _HAS_GCP_INFRA, ...)
```

### Post-Deployment Validation

**Local:**
```bash
kubectl get cronjob deduplication-maintenance -n api-service-local
kubectl create job --from=cronjob/deduplication-maintenance smoke-$(date +%s) -n api-service-local
kubectl logs job/smoke-<id> -n api-service-local --follow
# Verify "Maintenance completed" in logs
```

**GCP:**
```bash
kubectl get cronjob deduplication-maintenance -n api-service-gcp
kubectl create job --from=cronjob/deduplication-maintenance smoke-$(date +%s) -n api-service-gcp
kubectl logs job/smoke-<id> -c deduplication-job -n api-service-gcp --follow
kubectl logs job/smoke-<id> -c cloud-sql-proxy -n api-service-gcp  # verify sidecar exits cleanly
```

---

## Related Documentation

- [Intelligence Pipeline Workflow](./intelligence-pipeline-workflow.md)
- [ML Training Workflow](./ml-training-workflow.md)
- [Smart Contract Scanning Workflow](./smart-contract-scanning-workflow.md)
- [Deduplication Pipeline](../pipelines/deduplication-pipeline.md)
- [Feature Test: Hybrid Deduplication](../feature-tests/73-hybrid-deduplication-inline-maintenance.md)
- [Cross-Scan Deduplication Implementation](../../TaskDocs-BlockSecOps/blocksecops/cross-scan-deduplication-implementation.md)
- [Deduplication & Metadata Audit Fixes](/docs/changelogs/DEDUPLICATION-METADATA-AUDIT-FIXES-2026-02-04.md)
- [Multi-Level Matching Audit](/docs/changelogs/API-SERVICE-DEDUP-MULTILEVEL-MATCHING-AUDIT-2026-02-15.md)
- [Hybrid Deduplication Changelog](/docs/changelogs/API-SERVICE-V0.29.11-HYBRID-DEDUPLICATION-2026-02-23.md)
