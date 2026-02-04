# 56. ML Data Preservation & Multi-Class Classification Test Checklist

ML training data preservation through soft deletes, contract archival, implicit labeling, and multi-class vulnerability classification.

**Implementation Date**: 2026-02-03
**API Service Version**: 0.17.0
**Migrations Required**: 062-065

---

## Prerequisites

- [ ] API service deployed with migrations 062-065 applied
- [ ] Test user account available
- [ ] At least one contract with vulnerabilities for testing
- [ ] ML model trained (or test data available)

---

## 1. Vulnerability Soft Delete

### 1.1 Soft Delete Vulnerability

**Endpoint**: `DELETE /api/v1/vulnerabilities/{id}`

```bash
# Get a vulnerability ID first
VULN_ID=$(curl -s "http://127.0.0.1:3000/api/v1/vulnerabilities?limit=1" \
  -H "Authorization: Bearer {TOKEN}" | jq -r '.items[0].id')

# Soft delete the vulnerability
curl -X DELETE "http://127.0.0.1:3000/api/v1/vulnerabilities/${VULN_ID}?reason=user_action" \
  -H "Authorization: Bearer {TOKEN}"
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 1.1.1 | Delete vulnerability with valid reason | 200 OK, vulnerability marked deleted | [ ] |
| 1.1.2 | Verify `deleted_at` is set | Timestamp populated in database | [ ] |
| 1.1.3 | Verify `deleted_by` is set | Current user's ID | [ ] |
| 1.1.4 | Verify `deletion_reason` is set | "user_action" | [ ] |
| 1.1.5 | Invalid reason rejected | 422 Validation Error | [ ] |

### 1.2 Soft Delete Filtering

**Endpoint**: `GET /api/v1/vulnerabilities`

```bash
# Normal query - should NOT include soft-deleted
curl -s "http://127.0.0.1:3000/api/v1/vulnerabilities" \
  -H "Authorization: Bearer {TOKEN}" | jq '.total'

# Include soft-deleted
curl -s "http://127.0.0.1:3000/api/v1/vulnerabilities?include_deleted=true" \
  -H "Authorization: Bearer {TOKEN}" | jq '.total'
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 1.2.1 | Default query excludes soft-deleted | Deleted vuln not in results | [ ] |
| 1.2.2 | `include_deleted=true` includes deleted | Deleted vuln appears in results | [ ] |
| 1.2.3 | Deleted vuln has `deleted_at` field | Timestamp visible in response | [ ] |
| 1.2.4 | Count differs with/without deleted | Total changes appropriately | [ ] |

### 1.3 Contract Deletion Cascade

```bash
# Create a contract and scan, then delete contract
CONTRACT_ID="{contract_with_vulnerabilities}"
curl -X DELETE "http://127.0.0.1:3000/api/v1/contracts/${CONTRACT_ID}" \
  -H "Authorization: Bearer {TOKEN}"

# Verify vulnerabilities are soft-deleted, not hard-deleted
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security \
  -c "SELECT id, deleted_at, deletion_reason FROM vulnerabilities WHERE contract_id='${CONTRACT_ID}';"
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 1.3.1 | Delete contract with vulnerabilities | Contract deleted, vulns soft-deleted | [ ] |
| 1.3.2 | Vulns have deletion_reason='contract_deleted' | Cascade reason recorded | [ ] |
| 1.3.3 | Vulns still exist in database | Not hard-deleted | [ ] |
| 1.3.4 | Vulns excluded from normal queries | Filtered by `deleted_at IS NULL` | [ ] |

---

## 2. Contract Archival

### 2.1 Archive Contract

**Endpoint**: `POST /api/v1/contracts/{id}/archive`

```bash
CONTRACT_ID="{contract_id}"
curl -X POST "http://127.0.0.1:3000/api/v1/contracts/${CONTRACT_ID}/archive" \
  -H "Authorization: Bearer {TOKEN}"
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 2.1.1 | Archive contract with source | 200 OK, archive created | [ ] |
| 2.1.2 | `is_archived` set to true | Contract marked archived | [ ] |
| 2.1.3 | `source_hash` computed | SHA-256 hash stored | [ ] |
| 2.1.4 | `source_code` removed | NULL after archive (unless keep_source=true) | [ ] |
| 2.1.5 | Archive record created | Entry in `contract_archives` table | [ ] |
| 2.1.6 | Already archived returns error | 400 "Contract is already archived" | [ ] |

### 2.2 Get Archive Info

**Endpoint**: `GET /api/v1/contracts/{id}/archive`

```bash
curl -s "http://127.0.0.1:3000/api/v1/contracts/${CONTRACT_ID}/archive" \
  -H "Authorization: Bearer {TOKEN}" | jq
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 2.2.1 | Get archive info for archived contract | Archive details returned | [ ] |
| 2.2.2 | Response includes `source_hash` | Hash value present | [ ] |
| 2.2.3 | Response includes `has_compressed_backup` | Boolean indicating backup exists | [ ] |
| 2.2.4 | Response includes `archived_at` | Timestamp present | [ ] |
| 2.2.5 | Non-archived contract returns null | No archive record found | [ ] |

### 2.3 Restore Contract

**Endpoint**: `POST /api/v1/contracts/{id}/restore`

```bash
curl -X POST "http://127.0.0.1:3000/api/v1/contracts/${CONTRACT_ID}/restore" \
  -H "Authorization: Bearer {TOKEN}"
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 2.3.1 | Restore from compressed backup | 200 OK, source restored | [ ] |
| 2.3.2 | `is_archived` set to false | Contract no longer archived | [ ] |
| 2.3.3 | `source_code` populated | Source code restored | [ ] |
| 2.3.4 | Hash verification succeeds | Restored source matches hash | [ ] |
| 2.3.5 | `restore_count` incremented | Counter increases | [ ] |
| 2.3.6 | Restore non-archived returns error | 400 "Contract is not archived" | [ ] |

---

## 3. Implicit Labeling

### 3.1 Status Change Creates Implicit Label

**Endpoint**: `PATCH /api/v1/vulnerabilities/{id}`

```bash
VULN_ID="{vulnerability_id}"
curl -X PATCH "http://127.0.0.1:3000/api/v1/vulnerabilities/${VULN_ID}" \
  -H "Authorization: Bearer {TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"status": "fixed"}'
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 3.1.1 | Change status to 'fixed' | Implicit label 'confirmed' created | [ ] |
| 3.1.2 | Label confidence is 0.95 | High confidence for fixed status | [ ] |
| 3.1.3 | Change status to 'false_positive' | Implicit label 'false_positive' created | [ ] |
| 3.1.4 | Label confidence is 0.90 | FP status confidence | [ ] |
| 3.1.5 | Change status to 'wont_fix' | Implicit label 'wont_fix' created | [ ] |
| 3.1.6 | Label confidence is 0.80 | Wont_fix confidence | [ ] |

### 3.2 Verify Implicit Label Record

**Database Check**:
```bash
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security \
  -c "SELECT * FROM implicit_labels WHERE vulnerability_id='${VULN_ID}' ORDER BY created_at DESC LIMIT 1;"
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 3.2.1 | Label record exists | Entry in `implicit_labels` | [ ] |
| 3.2.2 | `source` is 'status_change' | Correct source type | [ ] |
| 3.2.3 | `action_type` recorded | e.g., "status:open->fixed" | [ ] |
| 3.2.4 | `is_active` is true | Not overridden | [ ] |
| 3.2.5 | `user_id` recorded | User who made change | [ ] |

### 3.3 Explicit Label Overrides Implicit

```bash
# Create explicit annotation
curl -X POST "http://127.0.0.1:3000/api/v1/annotations" \
  -H "Authorization: Bearer {TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "vulnerability_id": "'${VULN_ID}'",
    "status": "confirmed",
    "note": "Verified manually"
  }'
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 3.3.1 | Create explicit annotation | Annotation created | [ ] |
| 3.3.2 | Implicit label `is_active` set to false | Overridden by explicit | [ ] |
| 3.3.3 | Training data uses explicit label | Explicit takes priority | [ ] |

---

## 4. Multi-Class Classification

### 4.1 Classify Single Vulnerability

**Endpoint**: `GET /api/v1/ml/vulnerabilities/{id}/classify`

```bash
curl -s "http://127.0.0.1:3000/api/v1/ml/vulnerabilities/${VULN_ID}/classify" \
  -H "Authorization: Bearer {TOKEN}" | jq
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 4.1.1 | Get multi-class prediction | Classification result returned | [ ] |
| 4.1.2 | Response includes `predicted_class` | One of 4 classes | [ ] |
| 4.1.3 | Response includes `probabilities` | All 4 class probabilities | [ ] |
| 4.1.4 | Probabilities sum to ~1.0 | Valid probability distribution | [ ] |
| 4.1.5 | Response includes `confidence` | Highest probability value | [ ] |
| 4.1.6 | Response includes `model_version` | Version identifier | [ ] |

### 4.2 Classify All Vulnerabilities in Scan

**Endpoint**: `POST /api/v1/ml/scans/{id}/classify-all`

```bash
SCAN_ID="{scan_id}"
curl -X POST "http://127.0.0.1:3000/api/v1/ml/scans/${SCAN_ID}/classify-all" \
  -H "Authorization: Bearer {TOKEN}" | jq
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 4.2.1 | Classify all vulns in scan | Results for each vulnerability | [ ] |
| 4.2.2 | Each result has 4-class prediction | Multi-class output | [ ] |
| 4.2.3 | Summary includes class distribution | Count per class | [ ] |

### 4.3 Multi-Class Model Training

**Endpoint**: `POST /api/v1/ml/multi-class/train`

```bash
curl -X POST "http://127.0.0.1:3000/api/v1/ml/multi-class/train" \
  -H "Authorization: Bearer {TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"min_samples": 10, "force": true}'
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 4.3.1 | Train multi-class model | Training metrics returned | [ ] |
| 4.3.2 | Response includes `accuracy` | Overall accuracy score | [ ] |
| 4.3.3 | Response includes per-class metrics | Precision/recall per class | [ ] |
| 4.3.4 | Response includes `confusion_matrix` | 4x4 matrix | [ ] |
| 4.3.5 | Response includes `class_distribution` | Sample counts per class | [ ] |
| 4.3.6 | Insufficient samples returns error | 400 if < min_samples | [ ] |

---

## 5. Authorization Checks

### 5.1 Ownership Verification

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 5.1.1 | Archive another user's contract | 403 Forbidden | [ ] |
| 5.1.2 | Restore another user's contract | 403 Forbidden | [ ] |
| 5.1.3 | Classify another user's vulnerability | 403 Forbidden | [ ] |
| 5.1.4 | Soft-delete another user's vulnerability | 403 Forbidden | [ ] |
| 5.1.5 | Annotate another user's vulnerability | 403 Forbidden | [ ] |

---

## 6. ML Training Data Collection

### 6.1 Training Data Stats

**Endpoint**: `GET /api/v1/ml/training-data-stats`

```bash
curl -s "http://127.0.0.1:3000/api/v1/ml/training-data-stats" \
  -H "Authorization: Bearer {TOKEN}" | jq
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 6.1.1 | Stats include explicit label count | From annotations | [ ] |
| 6.1.2 | Stats include implicit label count | From status changes | [ ] |
| 6.1.3 | Stats include soft-deleted count | Preserved for training | [ ] |
| 6.1.4 | Stats include class distribution | Multi-class breakdown | [ ] |

### 6.2 Dataclass Structures

**TrainingDataStats** fields:
```python
@dataclass
class TrainingDataStats:
    total_samples: int
    confirmed_count: int
    false_positive_count: int
    wont_fix_count: int
    from_annotations: int       # From explicit user annotations
    from_classifications: int   # From ML-assisted classifications
    from_inline_labels: int     # From inline code labels
    from_soft_deleted: int      # From preserved soft-deleted vulnerabilities
    is_ready_for_training: bool
    is_recommended_for_training: bool
    message: str
```

**TrainingDataPoint** fields:
```python
@dataclass
class TrainingDataPoint:
    vulnerability_id: str
    scanner_id: str
    detector_id: str
    severity: str
    confidence: float
    code_snippet: str
    description: str
    pattern_code: str
    classification_confidence: float
    tool_consensus_score: Optional[float]
    file_path: str
    is_false_positive: bool
    multi_class_label: str      # One of: confirmed, false_positive, wont_fix, needs_review
    source: str                 # One of: annotation, classification, inline
```

**Multi-Class Labels**:
| Label | Description |
|-------|-------------|
| `confirmed` | Verified true positive vulnerability |
| `false_positive` | Confirmed not a real vulnerability |
| `wont_fix` | Real issue but accepted risk |
| `needs_review` | Requires human analysis |

---

## Database Verification

### Soft Delete Fields
```sql
SELECT id, deleted_at, deleted_by, deletion_reason
FROM vulnerabilities
WHERE deleted_at IS NOT NULL
LIMIT 5;
```

### Contract Archive Records
```sql
SELECT c.id, c.name, c.is_archived, c.source_hash, ca.compressed_source IS NOT NULL as has_backup
FROM contracts c
LEFT JOIN contract_archives ca ON c.id = ca.contract_id
WHERE c.is_archived = true;
```

### Implicit Labels
```sql
SELECT il.label, il.confidence, il.source, il.action_type, il.is_active, COUNT(*)
FROM implicit_labels il
GROUP BY il.label, il.confidence, il.source, il.action_type, il.is_active
ORDER BY COUNT(*) DESC;
```

---

## Related Documentation

- [Database Schema: Vulnerabilities](/docs/database/SCHEMA.md#vulnerabilities)
- [Database Schema: Contract Archives](/docs/database/SCHEMA.md#contract_archives)
- [Database Schema: Implicit Labels](/docs/database/SCHEMA.md#implicit_labels)
- [Migrations 062-065](/docs/database/MIGRATIONS.md#migration-062-vulnerability-soft-delete)
- [Feature Test #48: ML Data Strategy](/docs/feature-tests/48-ml-data-strategy.md)
