# Deduplication Workflow

**Last Updated:** February 4, 2026
**Status:** Active
**API Version:** 0.25.0

---

## Overview

The deduplication system groups duplicate vulnerability findings using a 5-tier matching strategy, combining fingerprint-based and semantic matching to identify the same vulnerability across scanners and scans.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DEDUPLICATION WORKFLOW                               │
│                                                                             │
│   Scan Completes                                                            │
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
│   Vulnerabilities linked to DeduplicationGroups                             │
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
2. Group by `fingerprint_location`
3. Select canonical finding (highest priority scanner)
4. Create `DeduplicationGroup` with all findings

**Scanner Priority (for canonical selection):**
```python
SCANNER_PRIORITY = {
    "slither": 1,      # Highest priority
    "mythril": 2,
    "securify2": 3,
    "oyente": 4,
    "smartcheck": 5,
    "solhint": 6,
    "soliditydefend": 7,
    "wake": 8,
    "echidna": 9,
    "medusa": 10,
    "halmos": 11,
}
```

**Location:** `src/presentation/api/v1/endpoints/scans.py` → `_process_scan_deduplication()`

---

## Phase 2: Cross-Scan Deduplication

**Purpose:** Link new findings to existing findings from prior scans of the same contract.

**Trigger:** After intra-scan deduplication completes.

**Algorithm:**
1. Query existing vulnerabilities from prior scans (same contract_id)
2. For each new vulnerability (including those with intra-scan groups):
   - **Level 1 (EXACT):** Match `fingerprint_code`
   - **Level 2 (HIGH):** Match `fingerprint_location` + same detector
   - **Level 3 (SEMANTIC):** Use Intelligence Engine embeddings

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

**Status:** Requires investigation in scanner parser implementations.

---

## Related Documentation

- [Intelligence Pipeline Workflow](./intelligence-pipeline-workflow.md)
- [ML Training Workflow](./ml-training-workflow.md)
- [Smart Contract Scanning Workflow](./smart-contract-scanning-workflow.md)
- [Cross-Scan Deduplication Implementation](../../TaskDocs-BlockSecOps/blocksecops/cross-scan-deduplication-implementation.md)
