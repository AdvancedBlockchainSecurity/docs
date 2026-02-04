# Cross-Scanner Deduplication Testing

**Feature**: Intelligence Layer - Cross-Scanner Deduplication
**Version**: v0.11.0 (integrated into scan ingestion pipeline)
**Last Tested**: 2026-01-17
**Status**: PASS

> **Enhancement (January 17, 2026)**: API v0.11.0 integrates deduplication directly into scan ingestion pipeline. Fingerprints are now generated automatically during scan result processing, and deduplication groups are created in real-time.

---

## Recent Changes (v0.11.0)

### Scan Ingestion Integration

Deduplication is now **automatically triggered** when scan results are stored:

1. **Fingerprint Generation**: Each vulnerability gets fingerprints generated during `store_scan_results()`
2. **Real-time Deduplication**: After scan completion, `_process_scan_deduplication()` creates groups for duplicates
3. **Pattern Code Assignment**: Groups inherit `pattern_code` from canonical findings

### Key Files Modified

| File | Change |
|------|--------|
| `src/presentation/api/v1/endpoints/scans.py` | Integrated `VulnerabilityFingerprinter` and deduplication processing |
| `src/application/services/vulnerability_fingerprinter.py` | Fingerprint generation logic |
| `src/infrastructure/config.py` | Version now read from pyproject.toml via importlib.metadata |

### Verified Behavior

```sql
-- Test scan with duplicate findings from different scanners
-- Both vulnerabilities at line 42 share the same fingerprint_location
SELECT v.id, v.title, v.scanner_id, v.line_number,
       LEFT(v.fingerprint_location, 20) as fp_loc,
       v.deduplication_group_id
FROM vulnerabilities v
WHERE v.scan_id = '615f68e1-918d-44a0-a437-9376d23a78c7';

-- Result:
-- Reentrancy Detected      | soliditydefend | 42 | 96bdd07ce5dfd8d4c9e4 | 08431010-3f04-4991-ba96-a8b33c5a7618
-- Reentrancy Vulnerability | slither        | 42 | 96bdd07ce5dfd8d4c9e4 | 08431010-3f04-4991-ba96-a8b33c5a7618
```

---

## Overview

Tests for the deduplication engine that automatically identifies and groups duplicate vulnerability findings across multiple security scanners.

---

## Test Environment

| Component | Value |
|-----------|-------|
| Platform | kubeadm (server) |
| API Service | v0.11.0 |
| Test User | jasonbrailowbizop@mail.com |
| Access URL | http://localhost:30180 (via Traefik NodePort) |

---

## API Endpoints Tested

### 1. Deduplication Stats

**Endpoint**: `GET /api/v1/deduplication/stats`

**Test Command**:
```bash
TOKEN=$(/Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "http://127.0.0.1:3000/api/v1/deduplication/stats" | jq '.'
```

**Expected Response**:
```json
{
  "total_groups": 137,
  "total_findings_deduplicated": 421,
  "average_group_size": 3.07,
  "confidence_breakdown": {
    "exact": 0,
    "high": 0,
    "medium": 0,
    "low": 0,
    "location": 137,
    "fuzzy": 0,
    "semantic": 0
  }
}
```

**Status**: [x] PASS (2025-12-25)

---

### 2. List Deduplication Groups

**Endpoint**: `GET /api/v1/deduplication/groups`

**Parameters**:
| Param | Type | Description |
|-------|------|-------------|
| limit | int | Results per page (default: 50) |
| offset | int | Pagination offset |
| pattern_code | string | Filter by BVD pattern code |
| severity | string | Filter by severity |
| min_scanner_count | int | Minimum scanners (default: 2) |

**Test Command**:
```bash
TOKEN=$(/Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "http://127.0.0.1:3000/api/v1/deduplication/groups?limit=5" | jq '.'
```

**Expected Response**:
```json
{
  "groups": [
    {
      "id": "uuid",
      "project_id": "uuid",
      "canonical_finding_id": "uuid",
      "pattern_code": null,
      "confidence_level": "location",
      "finding_count": 2,
      "scanner_count": 2,
      "first_seen": "2025-12-24T01:25:42.680455Z",
      "last_seen": "2025-12-24T18:04:46.440225Z",
      "canonical_finding_title": "Constable States",
      "canonical_finding_severity": "low"
    }
  ],
  "total": 137,
  "limit": 5,
  "offset": 0
}
```

**Status**: [x] PASS (2025-12-25)

---

### 3. Get Group Details

**Endpoint**: `GET /api/v1/deduplication/groups/{group_id}`

**Test Command**:
```bash
TOKEN=$(/Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
GROUP_ID="f992caa5-9f03-490c-81a6-abf1b1d5db2d"
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "http://127.0.0.1:3000/api/v1/deduplication/groups/${GROUP_ID}" | jq '.'
```

**Expected Response**:
```json
{
  "id": "f992caa5-9f03-490c-81a6-abf1b1d5db2d",
  "project_id": "27ef7de0-d303-4365-a16a-984a09ed9d07",
  "canonical_finding_id": "be9fd373-181d-4ec9-8683-8214519adff5",
  "pattern_code": null,
  "confidence_level": "location",
  "matched_fingerprints": ["fingerprint_code"],
  "finding_count": 2,
  "scanner_count": 2,
  "first_seen": "2025-12-24T01:25:42.680455Z",
  "last_seen": "2025-12-24T18:04:46.440225Z",
  "findings": [
    {
      "id": "be9fd373-181d-4ec9-8683-8214519adff5",
      "scanner_id": "slither",
      "pattern_code": null,
      "severity": "low",
      "title": "Constable States",
      "file_path": null,
      "line_number": 18,
      "match_confidence": "location",
      "is_canonical": true,
      "added_at": "2025-12-24T01:25:45.271893Z"
    },
    {
      "id": "2eb800a1-6f57-4cd4-8eee-b9242265877a",
      "scanner_id": "aderyn",
      "pattern_code": null,
      "severity": "medium",
      "title": "State Variable Could Be Constant",
      "file_path": null,
      "line_number": 18,
      "match_confidence": "location",
      "is_canonical": false,
      "added_at": "2025-12-24T01:25:42.680455Z"
    }
  ]
}
```

**Verification Points**:
- [x] Group contains findings from multiple scanners (slither, aderyn)
- [x] One finding marked as `is_canonical: true`
- [x] Findings matched by location (same line number: 18)
- [x] Scanners report different titles for same issue

**Status**: [x] PASS (2025-12-25)

---

## UI Testing

### Deduplication List Page

**URL**: `http://127.0.0.1:3000/deduplication`

**Test Steps**:
1. [x] Navigate to `/deduplication`
2. [x] Verify filter controls are visible (pattern code, severity, min scanners)
3. [x] Verify stats summary shows (total groups, findings, avg scanners)
4. [x] Verify groups list displays with clickable items
5. [x] Click a group to view details
6. [x] Verify detail page shows all grouped findings
7. [x] Verify canonical finding is highlighted

**Status**: [x] PASS (2025-12-26) - Dashboard v0.15.1

---

### Frontend Type Alignment Fix (v0.15.1)

**Issue**: Frontend TypeScript interfaces did not match API response structure, causing runtime errors on deduplication pages.

**Errors Fixed**:
- `DeduplicationGroupCard.tsx:122` - `fingerprint_code.substring()` undefined
- `DeduplicationDetail.tsx:147` - `group.fingerprint_code.slice()` undefined
- `DeduplicationDetail.tsx:113` - Missing import for `DeduplicationGroupCard`

**Solution**: Updated frontend types to match actual API response:
```typescript
// DeduplicationGroup - list view
interface DeduplicationGroup {
  id: string;
  canonical_finding_id: string;
  canonical_finding_title?: string;  // Added
  canonical_finding_severity?: string; // Added
  pattern_code?: string;
  confidence_level: ConfidenceLevel;
  finding_count: number;
  scanner_count: number;
  first_seen: string;
  last_seen: string;
}

// DeduplicationGroupDetail - detail view
interface DeduplicationGroupDetail extends DeduplicationGroup {
  matched_fingerprints: string[];  // Added
  findings: DuplicateFinding[];
}
```

**Files Modified**:
- `src/lib/api/deduplication.ts` - Type definitions
- `src/components/intelligence/DeduplicationGroupCard.tsx` - Display logic
- `src/pages/DeduplicationDetail.tsx` - Page display and imports

---

## Test Data Summary

| Metric | Value |
|--------|-------|
| Total Deduplication Groups | 137 |
| Total Findings Deduplicated | 421 |
| Average Group Size | 3.07 |
| Primary Match Type | Location-based |

---

## Known Issues

### 1. DNS Resolution After Cluster Restart

**Issue**: After laptop crash/minikube restart, external DNS resolution fails from pods.

**Symptom**: Token validation fails with "Failed to resolve 'huzjlpypdlelqnbjvxad.supabase.co'"

**Root Cause**: CoreDNS forwards to Docker Desktop DNS (192.168.65.254) which times out after cluster restart.

**Fix Applied**:
```bash
# Update CoreDNS to use Google DNS directly
kubectl get configmap coredns -n kube-system -o json | \
  jq '.data.Corefile |= sub("forward . /etc/resolv.conf"; "forward . 8.8.8.8 8.8.4.4")' | \
  kubectl apply -f -

# Restart CoreDNS
kubectl delete pod -n kube-system -l k8s-app=kube-dns

# Add control-plane hostname
minikube ssh "echo '192.168.49.2 control-plane.minikube.internal' | sudo tee -a /etc/hosts"
```

**Status**: Fixed

---

## Test Script

Save as `/tmp/test_dedup.sh`:

```bash
#!/bin/bash
# Cross-Scanner Deduplication Test Script

TOKEN=$(/Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh 2>/dev/null)

echo "=== Deduplication Stats ==="
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "http://127.0.0.1:3000/api/v1/deduplication/stats" | jq '.'

echo ""
echo "=== Deduplication Groups (first 3) ==="
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "http://127.0.0.1:3000/api/v1/deduplication/groups?limit=3" | jq '.'

echo ""
echo "=== Group Detail (first group) ==="
GROUP_ID=$(curl -s -H "Authorization: Bearer ${TOKEN}" \
  "http://127.0.0.1:3000/api/v1/deduplication/groups?limit=1" | jq -r '.groups[0].id')
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "http://127.0.0.1:3000/api/v1/deduplication/groups/${GROUP_ID}" | jq '.'
```

---

## References

- Technical Documentation: `/Users/pwner/Git/ABS/blocksecops-docs/features/deduplication-engine.md`
- API Implementation: `/Users/pwner/Git/ABS/blocksecops-api-service/src/presentation/api/v1/endpoints/deduplication.py`
- Dashboard Page: `/Users/pwner/Git/ABS/blocksecops-dashboard/src/pages/DeduplicationList.tsx`

---

## v0.11.0 Verification (January 17, 2026)

### Fingerprint Generation Test

```bash
# Create a test scan
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "
INSERT INTO scans (contract_id, user_id, scan_type, status, critical_count, high_count, medium_count, low_count)
VALUES ('598d95dc-a1fa-4814-8c18-eae9d7761ebd', '66f28736-4c19-43ec-8560-e70c645f1893', 'security', 'running', 0, 0, 0, 0)
RETURNING id;"

# Post results via API
curl -X POST -H "Host: localhost" -H "Content-Type: application/json" \
  http://localhost:30180/api/v1/scans/{scan_id}/results \
  -d '{"scanner":"slither","status":"completed","vulnerabilities":[...]}'
```

### Verification Queries

```bash
# Check fingerprints are generated
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "
SELECT COUNT(*) as total,
       COUNT(fingerprint_code) as with_fp_code,
       COUNT(fingerprint_location) as with_fp_loc
FROM vulnerabilities WHERE scan_id = 'YOUR_SCAN_ID';"

# Check deduplication groups created
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "
SELECT id, group_size, pattern_code, scanner_distribution
FROM deduplication_groups WHERE canonical_finding_id IN (
  SELECT id FROM vulnerabilities WHERE scan_id = 'YOUR_SCAN_ID'
);"
```

### Expected Results

- [x] All vulnerabilities have `fingerprint_code` generated
- [x] All vulnerabilities have `fingerprint_location` generated
- [x] Duplicates at same location share `deduplication_group_id`
- [x] Deduplication groups have correct `group_size`
- [x] Deduplication groups have `pattern_code` from canonical finding
- [x] `scanner_distribution` shows scanner breakdown (e.g., `{"slither": 1, "soliditydefend": 1}`)

---

**Last Updated**: 2026-02-04
**Tested By**: Claude Code (Automated)
**API Version**: v0.25.0

---

## Cross-Scan Deduplication Enhancement (February 4, 2026)

**Major Feature:** Cross-scan deduplication with semantic matching via Intelligence Engine.

### What's New

Deduplication now operates in **two phases**:

| Phase | Scope | Strategy |
|-------|-------|----------|
| Phase 1: Intra-scan | Within same scan | `fingerprint_location` matching |
| Phase 2: Cross-scan | Across prior scans | 3-level matching (fingerprint + semantic) |

### Cross-Scan Matching Levels

| Level | Confidence | Strategy | Description |
|-------|------------|----------|-------------|
| EXACT | 99% | `fingerprint_code` | Identical code hash |
| HIGH | 95% | `fingerprint_location` + detector | Same location, same detector type |
| SEMANTIC | 85%+ | Embedding similarity | Via Intelligence Engine |

### New Function Added

**File:** `src/presentation/api/v1/endpoints/scans.py`
**Function:** `_process_cross_scan_deduplication()`

```python
async def _process_cross_scan_deduplication(
    db: AsyncSession,
    scan_id: UUID,
    contract_id: UUID,
    new_vulnerability_ids: list[UUID],
) -> dict:
    """
    Process cross-scan deduplication for vulnerabilities.

    1. Queries existing vulnerabilities from prior scans (same contract)
    2. Uses fingerprint AND semantic matching
    3. Links to existing deduplication groups or creates new ones
    4. Updates occurrence_count and last_seen for historical tracking
    """
```

### Automatic Flow on Scan Completion

```
Store Results
     │
     ▼
Phase 1: Intra-scan Deduplication
     │ Groups duplicates within this scan
     ▼
Phase 2: Cross-scan Deduplication (NEW)
     │ Links to prior scans via:
     │ - Fingerprint code matching
     │ - Location + detector matching
     │ - Semantic similarity (Intelligence Engine)
     ▼
Done - Vulnerabilities linked to groups
```

### Intelligence Engine Integration

Semantic matching requires Intelligence Engine for embeddings:

```
URL: http://intelligence-engine.intelligence-engine-local.svc.cluster.local:80
Endpoint: POST /api/v1/embeddings
Model: all-MiniLM-L6-v2 (384-dim)
Threshold: 0.85 similarity
```

### Historical Tracking

Cross-scan matches update historical fields:
- `occurrence_count` - Incremented on each match
- `last_seen` - Updated to current timestamp
- `first_seen` - Preserved from original finding

### Verification Query

```sql
-- Check cross-scan deduplication worked
SELECT
    v.id,
    v.title,
    v.scan_id,
    v.deduplication_group_id,
    v.is_duplicate,
    v.occurrence_count,
    v.deduplication_strategy
FROM vulnerabilities v
WHERE v.contract_id = 'your-contract-uuid'
ORDER BY v.first_seen ASC;

-- Verify groups span multiple scans
SELECT
    dg.id as group_id,
    dg.group_size,
    dg.strategy,
    COUNT(DISTINCT v.scan_id) as scans_in_group
FROM deduplication_groups dg
JOIN vulnerabilities v ON v.deduplication_group_id = dg.id
GROUP BY dg.id, dg.group_size, dg.strategy
HAVING COUNT(DISTINCT v.scan_id) > 1;
```

---

## Architecture Update (January 26, 2026)

**ML Dependency Split:** Semantic deduplication embeddings now generated by intelligence-engine instead of api-service.

| Component | Role |
|-----------|------|
| api-service | HTTP client calls to intelligence-engine for embeddings |
| intelligence-engine | Hosts `/api/v1/embeddings` endpoint with SentenceTransformer model |

**Impact:**
- API service image reduced from 12.6GB to 934MB (93% reduction)
- Deduplication functionality unchanged - same API, different internal implementation
- Intelligence engine model: `all-MiniLM-L6-v2` (384 dimensions)

---

## Deduplication & Metadata Audit Fixes (February 4, 2026)

Comprehensive audit of deduplication, patterns, vulnerability entries, and metadata systems identified and fixed 27 issues.

### Critical Fixes

| Issue | Location | Fix |
|-------|----------|-----|
| MythrilParser empty results | `parser.py:253-303` | Complete rewrite with JSON parsing, SWC-ID mapping, code snippets |
| String length truncation | `models.py:784-789` | Changed `String(20)` to `String(50)` for `pattern_id`/`pattern_code` |

### High Priority Fixes

| Issue | Fix |
|-------|-----|
| Missing FK on `pattern_id` | Added FK to `vulnerability_patterns` with `SET NULL` |
| Missing FK on `deduplication_group_id` | Added FK to `deduplication_groups` with `SET NULL` |
| Orphaned records on cascade delete | Changed `canonical_finding_id` from `CASCADE` to `SET NULL` |
| Missing ORM relationships | Added `deduplication_group` and `pattern` relationships |

### New Database Indexes

5 new indexes added for query optimization:
- `ix_vulnerabilities_classification_confidence`
- `ix_vulnerabilities_classification_method`
- `ix_vulnerabilities_deduplication_strategy`
- `ix_vulnerabilities_similarity_score`
- `ix_vulnerabilities_multi_class_model_version`

### SWC-ID Mapping Implementation

Now implemented with 45+ detector-to-SWC fallback mappings:
- Pattern lookup returns `swc_id` from database
- Fallback function handles unmapped detectors with partial matching
- Example: `"reentrancy" → "SWC-107"`, `"tx-origin" → "SWC-115"`

### Code Snippet Extraction Improvements

| Parser | Before | After |
|--------|--------|-------|
| SlitherParser | Function name only | Elements (function, expression, variable, contract) |
| AderynParser | None | `src` field or `hint` fallback |
| MythrilParser | None | `code` field from JSON |
| EchidnaParser | None | Counterexample/call_sequence |
| MedusaParser | None | Location code, function, or counterexample |

### Verification Queries

```sql
-- Check pattern_id truncation is fixed
SELECT id FROM vulnerability_patterns WHERE LENGTH(id) > 20;

-- Verify FK constraints work
INSERT INTO vulnerabilities (pattern_id, ...) VALUES ('nonexistent-pattern', ...);
-- Should fail with FK violation

-- Check new indexes exist
SELECT indexname FROM pg_indexes WHERE tablename = 'vulnerabilities'
  AND indexname LIKE '%classification%';
```

### Related Documentation

- [Changelog](/docs/changelogs/DEDUPLICATION-METADATA-AUDIT-FIXES-2026-02-04.md)
- [Deduplication Workflow](/docs/workflows/deduplication-workflow.md)
- [Intelligence README](/docs/intelligence/README.md)
