# Intelligence Pipeline Workflow

**Last Updated:** February 2026
**Status:** Active

---

## Overview

The Intelligence Pipeline processes raw scanner output through multiple stages to produce enriched vulnerability data with classification, fingerprints, and ML predictions.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        INTELLIGENCE PIPELINE                                │
│                                                                             │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   │
│  │   Raw    │ → │ Normalize│ → │ Generate │ → │  Match   │ → │ Predict  │   │
│  │ Scanner  │   │ Finding  │   │Fingerprint│  │ Pattern  │   │    FP    │   │
│  │  Output  │   │          │   │          │   │          │   │  Score   │   │
│  └──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Services Involved

| Service | Role | Port |
|---------|------|------|
| API Service | Pipeline orchestration, REST endpoints | 8000 |
| Intelligence Engine | Embedding generation for semantic matching | 8002 |
| PostgreSQL | Pattern storage, vulnerability persistence | 5432 |

---

## Pipeline Stages

### Stage 1: Normalization

**Purpose:** Convert scanner-specific output to unified format.

**Input:** Raw scanner JSON output
**Output:** `NormalizedFinding` object

```python
@dataclass
class NormalizedFinding:
    scanner_id: str      # e.g., "slither", "mythril"
    detector_id: str     # Scanner's detector name
    title: str
    description: str
    severity: str        # critical, high, medium, low
    swc_id: str | None   # SWC-XXX classification
    cwe_id: str | None   # CWE-XXX classification
    line_number: int | None
    code_snippet: str | None
    confidence: float    # 0.0 - 1.0
    raw_data: dict       # Original scanner output
```

**Location:** `src/domain/services/intelligence_service.py` → `VulnerabilityNormalizer`

### Stage 2: Fingerprint Generation

**Purpose:** Generate multi-dimensional fingerprints for deduplication matching.

**Fingerprint Types:**

| Fingerprint | Algorithm | Purpose |
|-------------|-----------|---------|
| `fingerprint_code` | SHA256(code_snippet + detector_id) | Exact code matching |
| `fingerprint_location` | SHA256(file_path + line_number) | Location matching |
| `fingerprint_location_fuzzy` | SHA256(file_path + line_range) | Fuzzy location matching |
| `fingerprint_ast` | AST hash (future) | Structure-based matching |
| `fingerprint_semantic` | Base64(embedding[384]) | Semantic similarity matching |

**Location:** `src/domain/services/intelligence_service.py` → `VulnerabilityFingerprinter`

### Stage 3: Pattern Classification

**Purpose:** Match vulnerability to known patterns (BVD codes).

**Data Sources:**
- `vulnerability_patterns` table (397 patterns)
- `pattern_tool_mappings` table (214+ scanner-to-pattern mappings)

**Matching Logic:**
1. Look up `scanner_id` + `detector_id` in `pattern_tool_mappings`
2. If found, get `pattern_id` and `category`
3. If not found, use hardcoded fallback categorization

**Location:** `src/domain/services/intelligence_service.py` → `PatternMatcher`

### Stage 4: False Positive Prediction

**Purpose:** Predict probability that finding is a false positive.

**Model:** Random Forest classifier (CPU-only)
**Features:** 30+ features extracted from finding

**Output:**
- `false_positive_score`: 0.0 - 1.0 (higher = more likely FP)
- `confidence`: Model confidence in prediction

**Location:** `src/ml/false_positive_classifier.py`

### Stage 5: Build Enriched Vulnerability

**Purpose:** Combine all enrichments into final database record.

**Enriched Fields Added:**
```python
{
    # Pattern classification
    "pattern_id": "BVD-REENT-001",
    "classification_confidence": 0.95,

    # Fingerprints
    "fingerprint_code": "sha256:...",
    "fingerprint_location": "sha256:...",
    "fingerprint_ast": "sha256:...",
    "fingerprint_semantic": "base64:...",

    # ML predictions
    "false_positive_score": 0.23,

    # Historical tracking
    "first_seen": "2026-02-04T12:00:00Z",
    "last_seen": "2026-02-04T12:00:00Z",
    "occurrence_count": 1,

    # Deduplication (set by dedup service)
    "deduplication_group_id": None,
    "is_primary": True,
    "is_duplicate": False,
}
```

---

## Integration Point

The pipeline is invoked during scan result storage:

**File:** `src/presentation/api/v1/endpoints/scans.py`
**Endpoint:** `POST /api/v1/scans/{scan_id}/results`

```python
# For each vulnerability in scan results:
normalized_finding = NormalizedFinding(
    scanner_id=scanner_id,
    detector_id=detector_id,
    title=vuln_data.title,
    ...
)

fingerprints = fingerprinter.generate_fingerprints(
    normalized_finding,
    file_path=contract.name,
)

pattern_id, category = await _lookup_pattern_category(db, scanner_id, detector_id)

# Create vulnerability with all enrichments
vulnerability = VulnerabilityModel(
    fingerprint_code=fingerprints.fingerprint_code,
    fingerprint_location=fingerprints.fingerprint_location,
    pattern_id=pattern_id,
    ...
)
```

---

## Pattern Database

### Vulnerability Patterns (397 total)

Patterns are identified by BVD (BlockSecOps Vulnerability Database) codes:

| Category | Code Prefix | Count | Example |
|----------|-------------|-------|---------|
| Reentrancy | BVD-REENT | 15 | BVD-REENT-001 |
| Access Control | BVD-ACCESS | 25 | BVD-ACCESS-001 |
| Arithmetic | BVD-ARITH | 20 | BVD-ARITH-001 |
| Logic | BVD-LOGIC | 30 | BVD-LOGIC-001 |
| Gas Optimization | BVD-GAS | 40 | BVD-GAS-001 |
| ... | ... | ... | ... |

### Pattern-Tool Mappings (214+ total)

Maps scanner detectors to BVD patterns:

```json
{
  "scanner_id": "slither",
  "detector_id": "reentrancy-eth",
  "pattern_id": "BVD-REENT-001",
  "category": "reentrancy"
}
```

**Supported Scanners:** slither, mythril, securify2, oyente, smartcheck, solhint, soliditydefend, wake, echidna, medusa, halmos

### Seeding Patterns

```bash
cd /home/pwner/Git/blocksecops-api-service
source .venv/bin/activate
python scripts/seed_vulnerability_patterns.py
```

**Seed File:** `seeds/vulnerability_patterns.json` (version 3.13)

---

## API Endpoints

### Pattern Statistics
```bash
GET /api/v1/ml/pattern-stats
```

### Pattern Lookup
```bash
GET /api/v1/ml/patterns/{pattern_id}
```

### Scanner Quality (based on pattern FP rates)
```bash
GET /api/v1/ml/scanner-quality
```

---

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `INTELLIGENCE_ENGINE_URL` | `http://intelligence-engine...` | Embedding service URL |
| `ML_STORAGE_BACKEND` | `local` | Model storage (local/gcs) |
| `FP_CLASSIFIER_MIN_SAMPLES` | `50` | Minimum samples for training |

---

## Related Documentation

- [Deduplication Workflow](./deduplication-workflow.md)
- [ML Training Workflow](./ml-training-workflow.md)
- [Smart Contract Scanning Workflow](./smart-contract-scanning-workflow.md)
