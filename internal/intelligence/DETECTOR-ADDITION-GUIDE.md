# Adding Detectors After Scanner Integration

**Document Version**: 1.0
**Last Updated**: 2025-11-01
**Applies To**: Intelligence Layer v3.8+

## Overview

This guide covers the process for adding new detectors to an **already-integrated** scanner in Apogee. This is different from initial scanner integration (see [INTELLIGENCE-INTEGRATION-GUIDE.md](./INTELLIGENCE-INTEGRATION-GUIDE.md)).

### When to Use This Guide

- Adding new detectors to Slither, Aderyn, Semgrep, or other integrated scanners
- Scanner updated its detector library (e.g., Slither 0.10.0 → 0.10.1)
- Custom detectors developed for existing scanner
- Re-enabling previously disabled detectors

### When NOT to Use This Guide

- Initial scanner integration → Use [INTELLIGENCE-INTEGRATION-GUIDE.md](./INTELLIGENCE-INTEGRATION-GUIDE.md)
- Scanner parser changes → Use [SCANNER-UPDATE-GUIDE.md](../SCANNER-UPDATE-GUIDE.md)
- Scanner output format changes → Use [SCANNER-UPDATE-GUIDE.md](../SCANNER-UPDATE-GUIDE.md)

---

## Prerequisites

Before adding new detectors, ensure:

1. **Parser Already Extracts Required Fields**
   - `detector_id` field populated
   - `file_path`, `line_number` extracted
   - `function_name`, `contract_name` extracted (if available)

2. **Scanner Already Integrated**
   - Executor exists in `src/blocksecops_orchestration/scanners/`
   - Parser exists in `src/blocksecops_orchestration/parsers/`
   - Scanner registered in `ScannerRegistry` and `ParserRegistry`

3. **Intelligence Layer Operational**
   - Pattern database seeded
   - Enrichment service active
   - Deduplication working for existing detectors

---

## 5-Step Process

### Step 1: Pattern Creation (If New Vulnerability Type)

#### Decision: New Pattern vs. Reuse Existing?

**Reuse Existing Pattern** (~60-70% of detectors):
- Detector finds same vulnerability as existing pattern
- Example: New reentrancy detector → Use existing `BVD-EVM-REE-*` pattern

**Create New Pattern** (~30-40% of detectors):
- Detector finds novel vulnerability type
- No existing pattern matches semantically

#### 1.1: Research the New Detector

**Gather Information**:
```bash
# Example: Research new Slither detector
slither --list-detectors | grep "new-detector-name"
slither --help-detector new-detector-name
```

**Key Questions**:
- What vulnerability does it detect?
- What's the security impact? (High/Medium/Low)
- What category does it belong to? (REE, ACC, INT, etc.)
- Is there an existing pattern for this?

#### 1.2: Check Existing Patterns

**Query Pattern Database**:
```bash
# Search for similar patterns
cd blocksecops-orchestration/migrations/data
cat vulnerability_patterns.json | jq '.patterns[] | select(.title | contains("reentrancy"))'

# List patterns by category
cat vulnerability_patterns.json | jq '.patterns[] | select(.pattern_id | startswith("BVD-EVM-REE"))'
```

**Pattern Reuse Examples**:
| New Detector | Existing Pattern | Rationale |
|--------------|------------------|-----------|
| `slither-reentrancy-no-eth` | `BVD-EVM-REE-001` | Same root cause (reentrancy) |
| `aderyn-unchecked-return` | `BVD-EVM-EXT-002` | Same issue (unchecked external call) |
| `semgrep-tx-origin-auth` | `BVD-EVM-TXO-001` | Same vulnerability (tx.origin usage) |

#### 1.3: Create New Pattern (If Required)

**Pattern Template**:
```json
{
  "pattern_id": "BVD-EVM-XXX-YYY",
  "title": "Descriptive Vulnerability Title",
  "description": "Detailed description of the vulnerability class",
  "severity": "high|medium|low",
  "category": "REE|ACC|INT|EXT|STA|TIM|GAS|LOG|DAT|VER|TXO|RND|UNC|VIS|IMM|ASM|EVT|ENC|L2|OTH",
  "ecosystem": "EVM|VYPER|SOLANA|CAIRO",
  "cwe_ids": ["CWE-123"],
  "owasp_category": "A01:2021-Broken Access Control",
  "references": [
    "https://docs.soliditylang.org/en/latest/security-considerations.html",
    "https://swcregistry.io/docs/SWC-XXX"
  ],
  "remediation": "How to fix this vulnerability",
  "fingerprint_strategy": "code|ast|location|semantic",
  "tags": ["reentrancy", "state-modification", "external-call"]
}
```

**Pattern ID Format**: `BVD-[ECOSYSTEM]-[CATEGORY]-[NUMBER]`

**Category Codes**:
```
REE = Reentrancy              ACC = Access Control       INT = Integer Overflow/Underflow
EXT = External Calls          STA = State Management     TIM = Timestamp Dependence
GAS = Gas Optimization        LOG = Logic Errors         DAT = Data Validation
VER = Version Issues          TXO = tx.origin Usage      RND = Randomness
UNC = Unchecked Return Values VIS = Visibility           IMM = Immutability
ASM = Assembly Issues         EVT = Event Emission       ENC = Encoding Issues
L2  = Layer 2 Specific        OTH = Other
```

**Example - New Pattern**:
```json
{
  "pattern_id": "BVD-EVM-ACC-015",
  "title": "Missing Role-Based Access Control on Critical Function",
  "description": "Function performs privileged operation without checking caller's role membership in RBAC system",
  "severity": "high",
  "category": "ACC",
  "ecosystem": "EVM",
  "cwe_ids": ["CWE-284"],
  "owasp_category": "A01:2021-Broken Access Control",
  "references": [
    "https://docs.openzeppelin.com/contracts/4.x/access-control"
  ],
  "remediation": "Add role-based access control using OpenZeppelin AccessControl or similar",
  "fingerprint_strategy": "code",
  "tags": ["access-control", "rbac", "authorization"]
}
```

#### 1.4: Add Pattern to Pattern Database

**File**: `blocksecops-orchestration/migrations/data/vulnerability_patterns.json`

```bash
cd blocksecops-orchestration/migrations/data

# Backup current version
cp vulnerability_patterns.json vulnerability_patterns.json.backup

# Add new pattern to "patterns" array
# Use jq or manual edit
jq '.patterns += [{
  "pattern_id": "BVD-EVM-ACC-015",
  "title": "Missing Role-Based Access Control on Critical Function",
  ...
}]' vulnerability_patterns.json > tmp.json && mv tmp.json vulnerability_patterns.json
```

**Verify Pattern Count**:
```bash
# Count patterns before
jq '.patterns | length' vulnerability_patterns.json.backup

# Count patterns after
jq '.patterns | length' vulnerability_patterns.json

# Should be +1 (or +N for batch additions)
```

---

### Step 2: Detector Mapping (Always Required)

Every new detector MUST have a mapping, even if it reuses an existing pattern.

#### 2.1: Create Detector Mapping Entry

**Mapping Template**:
```json
{
  "scanner_id": "slither|aderyn|semgrep|soliditydefend|...",
  "detector_id": "detector-name-from-scanner",
  "pattern_id": "BVD-EVM-XXX-YYY",
  "confidence": 0.90,
  "match_method": "rule_based|ml_based|heuristic",
  "notes": "Optional context about this mapping",
  "is_active": true
}
```

**Field Guidelines**:
- `scanner_id`: Must match scanner ID in `ScannerRegistry`
- `detector_id`: Exact detector ID as reported by scanner (case-sensitive)
- `pattern_id`: Pattern ID from Step 1 (existing or newly created)
- `confidence`: 0.0-1.0 (how confident scanner is about this finding)
  - Rule-based detectors: 0.90-0.95
  - Heuristic detectors: 0.70-0.85
  - ML-based detectors: 0.60-0.90
- `match_method`: How detector identifies vulnerability
- `is_active`: `true` for production use, `false` to disable

**Example Mappings**:
```json
// Example 1: New detector, existing pattern
{
  "scanner_id": "slither",
  "detector_id": "reentrancy-no-eth",
  "pattern_id": "BVD-EVM-REE-001",
  "confidence": 0.95,
  "match_method": "rule_based",
  "notes": "Variant of reentrancy-eth without ETH transfer",
  "is_active": true
}

// Example 2: New detector, new pattern
{
  "scanner_id": "aderyn",
  "detector_id": "missing-rbac-check",
  "pattern_id": "BVD-EVM-ACC-015",
  "confidence": 0.85,
  "match_method": "heuristic",
  "notes": "Detects missing role checks in privileged functions",
  "is_active": true
}

// Example 3: Custom SolidityDefend detector
{
  "scanner_id": "soliditydefend",
  "detector_id": "sd-gas-001-inefficient-storage",
  "pattern_id": "BVD-EVM-GAS-005",
  "confidence": 0.90,
  "match_method": "rule_based",
  "is_active": true
}
```

#### 2.2: Add Mapping to Pattern Database

**File**: `blocksecops-orchestration/migrations/data/vulnerability_patterns.json`

```bash
# Add new mapping to "pattern_tool_mappings" array
jq '.pattern_tool_mappings += [{
  "scanner_id": "slither",
  "detector_id": "new-detector-name",
  "pattern_id": "BVD-EVM-XXX-YYY",
  "confidence": 0.90,
  "match_method": "rule_based",
  "is_active": true
}]' vulnerability_patterns.json > tmp.json && mv tmp.json vulnerability_patterns.json
```

**Verify Mapping Count**:
```bash
# Count mappings
jq '.pattern_tool_mappings | length' vulnerability_patterns.json

# List all mappings for a scanner
jq '.pattern_tool_mappings[] | select(.scanner_id == "slither")' vulnerability_patterns.json
```

---

### Step 3: Database Update

#### 3.1: Update Pattern Database Version

**File**: `blocksecops-orchestration/migrations/data/vulnerability_patterns.json`

```bash
# Update version (e.g., v3.8 → v3.9)
jq '.version = "3.9"' vulnerability_patterns.json > tmp.json && mv tmp.json vulnerability_patterns.json

# Update last_updated timestamp
jq '.last_updated = "2025-11-01T12:00:00Z"' vulnerability_patterns.json > tmp.json && mv tmp.json vulnerability_patterns.json
```

**Versioning Convention**:
- **Major version** (v3.x → v4.x): Breaking schema changes, major refactoring
- **Minor version** (v3.8 → v3.9): Adding new patterns/mappings, new categories
- **Patch version** (v3.8.0 → v3.8.1): Fixing typos, updating references

**For Adding Detectors**: Increment **minor version**

#### 3.2: Run Database Seed Script

**Development Environment**:
```bash
cd blocksecops-orchestration

# Activate virtual environment
source .venv/bin/activate

# Run seed script
python -m blocksecops_orchestration.migrations.seed_vulnerability_patterns

# Expected output:
# ✅ Loaded 348 patterns from vulnerability_patterns.json (was 347)
# ✅ Seeded 348 patterns to database
# ✅ Loaded 395 detector mappings (was 393)
# ✅ Seeded 395 mappings to database
```

**Production Environment**:
```bash
# Use kubectl exec to run seed script in orchestrator pod
kubectl exec -n blocksecops deployment/orchestrator -- \
  python -m blocksecops_orchestration.migrations.seed_vulnerability_patterns

# Or use Kubernetes Job
kubectl apply -f k8s/jobs/seed-intelligence-patterns.yaml
```

#### 3.3: Verify Database Seeding

**Query Database**:
```bash
# Connect to PostgreSQL
kubectl exec -n blocksecops deployment/postgres -- psql -U blocksecops

# Verify patterns seeded
SELECT COUNT(*) FROM vulnerability_patterns;
-- Should match pattern count in JSON

# Verify new pattern exists
SELECT pattern_id, title, severity
FROM vulnerability_patterns
WHERE pattern_id = 'BVD-EVM-ACC-015';

# Verify mappings seeded
SELECT COUNT(*) FROM pattern_tool_mappings;
-- Should match mapping count in JSON

# Verify new mapping exists
SELECT scanner_id, detector_id, pattern_id, confidence
FROM pattern_tool_mappings
WHERE detector_id = 'new-detector-name';
```

**Expected Results**:
- Pattern count in database = Pattern count in JSON
- Mapping count in database = Mapping count in JSON
- New patterns/mappings present in database

---

### Step 4: Testing

#### 4.1: Create Test Contract

Create a contract that triggers the new detector.

**Example Test Contract** (for `missing-rbac-check` detector):
```solidity
// test_contracts/access_control/missing_rbac.sol
pragma solidity ^0.8.0;

contract MissingRBACCheck {
    mapping(address => bool) public admins;
    uint256 public criticalValue;

    // VULNERABILITY: Missing role check on critical function
    function setCriticalValue(uint256 _value) external {
        criticalValue = _value; // Should require admin role
    }

    // SECURE: Has role check
    function setCriticalValueSecure(uint256 _value) external {
        require(admins[msg.sender], "Not admin");
        criticalValue = _value;
    }
}
```

**Test Contract Repository**:
```
blocksecops-orchestration/tests/test_contracts/
├── reentrancy/
├── access_control/
│   ├── missing_rbac.sol          # New test contract
│   └── expected_findings.json     # Expected detector output
├── integer_overflow/
└── ...
```

#### 4.2: Run Scanner Locally

Test that scanner detects the vulnerability:

```bash
cd blocksecops-orchestration

# Run scanner on test contract
slither tests/test_contracts/access_control/missing_rbac.sol

# Expected output should include new detector:
# missing-rbac-check in setCriticalValue (missing_rbac.sol#10-12)
```

#### 4.3: Test Pattern Matching

Verify that enrichment service maps detector to pattern:

```python
# tests/integration/test_new_detector_mapping.py
import pytest
from blocksecops_orchestration.intelligence.enrichment_service import FindingEnrichmentService
from blocksecops_orchestration.intelligence.pattern_matcher import PatternMatcher

def test_new_detector_pattern_mapping():
    """Test that new detector maps to correct pattern"""

    # Initialize services
    pattern_matcher = PatternMatcher()

    # Mock finding from new detector
    finding = {
        "detector_id": "missing-rbac-check",
        "scanner_id": "aderyn",
        "severity": "high",
        "title": "Missing RBAC Check",
        "description": "Function lacks role-based access control",
        "file_path": "contracts/MyContract.sol",
        "line_number": 42,
    }

    # Test pattern matching
    pattern_result = pattern_matcher.match_pattern(
        scanner_id=finding["scanner_id"],
        detector_id=finding["detector_id"]
    )

    # Assertions
    assert pattern_result is not None, "Pattern matching failed"
    assert pattern_result["pattern_id"] == "BVD-EVM-ACC-015"
    assert pattern_result["confidence"] >= 0.80
    assert pattern_result["pattern_code"] == "BVD-EVM-ACC-015"

def test_new_detector_end_to_end_enrichment():
    """Test end-to-end enrichment pipeline"""

    enrichment_service = FindingEnrichmentService()

    finding = {
        "detector_id": "missing-rbac-check",
        "scanner_id": "aderyn",
        "severity": "high",
        "title": "Missing RBAC Check",
        "file_path": "contracts/MyContract.sol",
        "line_number": 42,
        "code_snippet": "function setCriticalValue(uint256 _value) external { ... }",
        "function_name": "setCriticalValue",
        "contract_name": "MyContract",
    }

    # Run enrichment
    enriched = enrichment_service.enrich_finding(finding)

    # Assertions
    assert enriched["pattern_id"] == "BVD-EVM-ACC-015"
    assert enriched["pattern_code"] == "BVD-EVM-ACC-015"
    assert enriched["classification_confidence"] >= 0.80
    assert enriched["classification_method"] == "pattern_match"
    assert enriched["fingerprint_code"] is not None  # Fingerprint generated
    assert enriched["fingerprint_location"] is not None
```

**Run Tests**:
```bash
# Run specific test
pytest tests/integration/test_new_detector_mapping.py -v

# Run all pattern matching tests
pytest tests/integration/ -k "pattern" -v

# Expected output:
# test_new_detector_pattern_mapping PASSED
# test_new_detector_end_to_end_enrichment PASSED
```

#### 4.4: Integration Test (Full Scan)

Run a complete scan with the new detector:

```bash
# Trigger scan via API
curl -X POST http://localhost:8000/api/v1/scans \
  -H "Content-Type: application/json" \
  -d '{
    "repository_url": "https://github.com/test/missing-rbac-contract",
    "scanner_ids": ["aderyn"],
    "scan_type": "full"
  }'

# Wait for scan completion
# Expected: 1 finding with pattern_id = BVD-EVM-ACC-015
```

**Verify in Database**:
```sql
-- Check finding was enriched with correct pattern
SELECT
    detector_id,
    pattern_id,
    pattern_code,
    classification_confidence,
    fingerprint_code,
    file_path,
    function_name
FROM vulnerabilities
WHERE detector_id = 'missing-rbac-check'
ORDER BY created_at DESC
LIMIT 5;

-- Expected:
-- detector_id           | pattern_id       | pattern_code     | classification_confidence
-- missing-rbac-check    | BVD-EVM-ACC-015  | BVD-EVM-ACC-015  | 0.85
```

#### 4.5: Deduplication Test (If Applicable)

If another scanner detects the same vulnerability type:

```python
# tests/integration/test_deduplication_new_detector.py
def test_deduplication_with_new_detector():
    """Test that new detector deduplicates with existing detectors"""

    # Run multiple scanners on same contract
    findings = [
        # Existing detector
        {
            "scanner_id": "slither",
            "detector_id": "missing-role-check",
            "pattern_id": "BVD-EVM-ACC-015",
            "file_path": "contracts/MyContract.sol",
            "line_number": 42,
            "code_snippet": "function setCriticalValue(...) { ... }"
        },
        # New detector
        {
            "scanner_id": "aderyn",
            "detector_id": "missing-rbac-check",
            "pattern_id": "BVD-EVM-ACC-015",
            "file_path": "contracts/MyContract.sol",
            "line_number": 42,
            "code_snippet": "function setCriticalValue(...) { ... }"
        }
    ]

    # Run deduplication
    dedup_service = DeduplicationService()
    groups = dedup_service.group_duplicates(findings)

    # Assertions
    assert len(groups) == 1, "Should create 1 deduplication group"
    assert len(groups[0]["findings"]) == 2, "Group should contain both findings"
    assert groups[0]["primary_finding"]["scanner_id"] in ["slither", "aderyn"]
```

---

### Step 5: Documentation

#### 5.1: Update Scanner Detector Tracking

**File**: `blocksecops-docs/SCANNER-DETECTOR-TRACKING.md`

Add new detector to the appropriate scanner section:

```markdown
## Aderyn (Solidity - Rust-based)

**Scanner ID**: `aderyn`
**Total Detectors**: 52 → 53 (updated 2025-11-01)

| Detector ID | Pattern ID | Severity | Description | Status |
|-------------|------------|----------|-------------|--------|
| ... | ... | ... | ... | ... |
| `missing-rbac-check` | `BVD-EVM-ACC-015` | High | Missing role-based access control on critical function | ✅ Active |
```

**Update Summary Stats**:
```markdown
## Summary Statistics

**Last Updated**: 2025-11-01

| Metric | Count |
|--------|-------|
| Total Patterns | 347 → 348 |
| Total Detector Mappings | 393 → 395 |
| Scanners Integrated | 4 |
| Ecosystems Supported | 4 (EVM, Vyper, Solana, Cairo) |
```

#### 5.2: Update Changelog

**File**: `blocksecops-docs/CHANGELOG-INTELLIGENCE.md`

```markdown
## v3.9 - 2025-11-01

### Added
- **New Pattern**: BVD-EVM-ACC-015 - Missing Role-Based Access Control
- **New Detector Mapping**: Aderyn `missing-rbac-check` → BVD-EVM-ACC-015
- **New Detector Mapping**: Slither `reentrancy-no-eth` → BVD-EVM-REE-001

### Changed
- Updated Aderyn detector count: 52 → 53
- Updated total patterns: 347 → 348
- Updated total mappings: 393 → 395

### Testing
- ✅ Pattern matching test: 100% accuracy
- ✅ Integration test: Scan completed successfully
- ✅ Deduplication test: Groups correctly with existing detectors
```

#### 5.3: Update Release Notes (If Applicable)

If adding detectors as part of a release:

**File**: `blocksecops-docs/releases/v1.5.0-release-notes.md`

```markdown
## Intelligence Layer Enhancements

### New Detectors (2 added)
- **Aderyn**: `missing-rbac-check` - Detects missing role-based access control
- **Slither**: `reentrancy-no-eth` - Detects reentrancy without ETH transfer

### Pattern Coverage
- Total patterns: 348 (+1 from v1.4.0)
- Total detector mappings: 395 (+2 from v1.4.0)
- Pattern matching accuracy: 100% (validated on 50 test contracts)
```

#### 5.4: Update Test Documentation

**File**: `blocksecops-orchestration/tests/README.md`

```markdown
## Test Contracts for New Detectors

### Access Control Tests
- `tests/test_contracts/access_control/missing_rbac.sol`
  - Tests: Aderyn `missing-rbac-check`
  - Expected findings: 1 high-severity finding
  - Pattern: BVD-EVM-ACC-015
```

---

## Batch Updates (Adding 10-20 Detectors)

For efficiency when adding multiple detectors:

### Batch Process

#### 1. Pattern Generation Script

```python
# scripts/batch_add_detectors.py
import json
from typing import List, Dict

def batch_add_detectors(detectors: List[Dict]) -> Dict:
    """
    Add multiple detectors at once

    Args:
        detectors: List of detector definitions

    Returns:
        Summary of patterns/mappings created
    """

    # Load current pattern database
    with open("migrations/data/vulnerability_patterns.json", "r") as f:
        db = json.load(f)

    new_patterns = []
    new_mappings = []
    existing_pattern_count = len(db["patterns"])

    for detector in detectors:
        # Check if pattern exists
        existing_pattern = find_similar_pattern(detector, db["patterns"])

        if existing_pattern:
            pattern_id = existing_pattern["pattern_id"]
        else:
            # Generate new pattern
            pattern = generate_pattern(detector)
            new_patterns.append(pattern)
            pattern_id = pattern["pattern_id"]

        # Create mapping
        mapping = {
            "scanner_id": detector["scanner_id"],
            "detector_id": detector["detector_id"],
            "pattern_id": pattern_id,
            "confidence": detector.get("confidence", 0.90),
            "match_method": detector.get("match_method", "rule_based"),
            "is_active": True
        }
        new_mappings.append(mapping)

    # Update database
    db["patterns"].extend(new_patterns)
    db["pattern_tool_mappings"].extend(new_mappings)
    db["version"] = increment_version(db["version"])  # v3.8 → v3.9

    # Save
    with open("migrations/data/vulnerability_patterns.json", "w") as f:
        json.dump(db, f, indent=2)

    return {
        "patterns_added": len(new_patterns),
        "patterns_reused": len(detectors) - len(new_patterns),
        "mappings_added": len(new_mappings),
        "version": db["version"]
    }

# Usage
detectors = [
    {
        "scanner_id": "aderyn",
        "detector_id": "missing-rbac-check",
        "title": "Missing RBAC Check",
        "severity": "high",
        "category": "ACC"
    },
    {
        "scanner_id": "slither",
        "detector_id": "reentrancy-no-eth",
        "title": "Reentrancy (No ETH Transfer)",
        "severity": "high",
        "category": "REE"
    },
    # ... 18 more detectors
]

result = batch_add_detectors(detectors)
print(f"✅ Added {result['mappings_added']} detectors")
print(f"   - Created {result['patterns_added']} new patterns")
print(f"   - Reused {result['patterns_reused']} existing patterns")
print(f"   - Updated version to {result['version']}")
```

#### 2. Batch Testing Script

```python
# scripts/batch_test_detectors.py
def batch_test_pattern_matching(detector_ids: List[str]):
    """Test pattern matching for multiple detectors"""

    results = []

    for detector_id in detector_ids:
        # Query database for mapping
        mapping = session.execute(
            text("""
                SELECT pattern_id, confidence
                FROM pattern_tool_mappings
                WHERE detector_id = :detector_id
            """),
            {"detector_id": detector_id}
        ).fetchone()

        results.append({
            "detector_id": detector_id,
            "pattern_id": mapping.pattern_id if mapping else None,
            "passed": mapping is not None
        })

    # Summary
    passed = sum(1 for r in results if r["passed"])
    print(f"Pattern Matching: {passed}/{len(results)} detectors mapped")

    if passed < len(results):
        failed = [r["detector_id"] for r in results if not r["passed"]]
        print(f"❌ Failed detectors: {failed}")

    return all(r["passed"] for r in results)
```

---

## Time Estimates

### Per-Detector Estimates

| Step | Manual Time | Automated Time | Notes |
|------|-------------|----------------|-------|
| Pattern Research | 15-30 min | 5 min | Check existing patterns |
| Pattern Creation | 20-30 min | 2 min | If new pattern needed |
| Detector Mapping | 5-10 min | 1 min | Always required |
| Database Update | 5 min | 1 min | Run seed script |
| Testing | 15-20 min | 5 min | Create test, verify |
| Documentation | 10-15 min | 5 min | Update tracking docs |
| **Total per detector** | **70-110 min** | **15-20 min** | With automation |

### Batch Estimates (20 detectors)

| Approach | Total Time | Time per Detector |
|----------|------------|-------------------|
| Manual (sequential) | 23-37 hours | 70-110 min |
| Semi-automated | 8-12 hours | 25-35 min |
| Fully automated | 3-5 hours | 9-15 min |

**Recommendation**: Use batch automation scripts for 10+ detectors

---

## Rollback Procedure

If new detectors cause issues in production:

### 1. Disable Detector Mapping

```sql
-- Temporarily disable problematic detector
UPDATE pattern_tool_mappings
SET is_active = false
WHERE detector_id = 'problematic-detector';
```

### 2. Restore Previous Pattern Database

```bash
cd blocksecops-orchestration/migrations/data

# Restore from backup
cp vulnerability_patterns.json.backup vulnerability_patterns.json

# Re-seed database
python -m blocksecops_orchestration.migrations.seed_vulnerability_patterns
```

### 3. Verify Rollback

```sql
-- Check detector is disabled
SELECT scanner_id, detector_id, is_active
FROM pattern_tool_mappings
WHERE detector_id = 'problematic-detector';

-- Check pattern count matches previous version
SELECT COUNT(*) FROM vulnerability_patterns;
```

---

## Troubleshooting

### Issue: Pattern Matching Fails for New Detector

**Symptoms**:
- Finding has `detector_id` but `pattern_id` is NULL
- Warning in logs: "No pattern mapping found for detector: xyz"

**Diagnosis**:
```sql
-- Check if mapping exists in database
SELECT * FROM pattern_tool_mappings
WHERE detector_id = 'your-detector-id';

-- Check if detector_id matches exactly (case-sensitive)
SELECT DISTINCT detector_id
FROM vulnerabilities
WHERE detector_id LIKE '%your-detector%';
```

**Solutions**:
1. **Mapping not seeded**: Re-run seed script
2. **Detector ID mismatch**: Update mapping in JSON to match exact scanner output
3. **Scanner ID mismatch**: Verify `scanner_id` in mapping matches `ScannerRegistry`

### Issue: Fingerprints Not Generated

**Symptoms**:
- Finding has `pattern_id` but all fingerprint fields are NULL

**Diagnosis**:
```python
# Check if parser extracts required fields
finding = session.query(VulnerabilityModel).filter_by(
    detector_id='your-detector-id'
).first()

print(f"file_path: {finding.file_path}")        # Must be non-NULL
print(f"line_number: {finding.line_number}")    # Must be non-NULL
print(f"code_snippet: {finding.code_snippet}")  # Optional but helpful
```

**Solutions**:
1. **Parser not extracting fields**: Update parser to extract `file_path`, `line_number`
2. **Enrichment service error**: Check logs for fingerprinting failures
3. **Invalid code snippet**: Ensure code snippet is valid Solidity/Vyper/etc.

### Issue: Deduplication Not Working

**Symptoms**:
- Same vulnerability reported multiple times
- No deduplication groups created

**Diagnosis**:
```sql
-- Check fingerprints for same vulnerability from different scanners
SELECT
    scanner_id,
    detector_id,
    fingerprint_code,
    fingerprint_location,
    file_path,
    line_number
FROM vulnerabilities
WHERE pattern_id = 'BVD-EVM-XXX-YYY'
ORDER BY file_path, line_number;
```

**Solutions**:
1. **Different fingerprints**: Parsers extracting code snippets differently
2. **Different patterns**: Detectors mapped to different patterns (should be same)
3. **Deduplication disabled**: Check `ENABLE_DEDUPLICATION` config

---

## Best Practices

### 1. Always Reuse Patterns When Possible
- 60-70% of detectors map to existing patterns
- Search thoroughly before creating new pattern
- Use pattern similarity search tools

### 2. Batch Updates for Efficiency
- Add 10-20 detectors at once
- Use automation scripts
- Single database seed operation

### 3. Test Before Production Deploy
- Run integration test with test contract
- Verify pattern matching 100% accurate
- Check fingerprinting generates correctly
- Test deduplication if applicable

### 4. Document Everything
- Update SCANNER-DETECTOR-TRACKING.md
- Update CHANGELOG-INTELLIGENCE.md
- Add test contracts with comments
- Keep release notes

### 5. Version Incrementally
- Minor version for new detectors (v3.8 → v3.9)
- Increment version EVERY time database changes
- Keep backups of previous versions

### 6. Monitor in Production
- Track pattern matching success rate
- Monitor enrichment service errors
- Alert on unmapped detectors
- Review deduplication group sizes

---

## Related Documentation

- [INTELLIGENCE-INTEGRATION-GUIDE.md](./INTELLIGENCE-INTEGRATION-GUIDE.md) - Initial scanner intelligence integration
- [SCANNER-INTEGRATION-GUIDE.md](../SCANNER-INTEGRATION-GUIDE.md) - General scanner integration (Docker, Kubernetes, parser)
- [SCANNER-UPDATE-GUIDE.md](../SCANNER-UPDATE-GUIDE.md) - Scanner version updates, output format changes
- [SCANNER-DETECTOR-TRACKING.md](../SCANNER-DETECTOR-TRACKING.md) - Current detector inventory
- [PATTERN-DATABASE-SCHEMA.md](./PATTERN-DATABASE-SCHEMA.md) - Pattern database structure

---

## Support

For questions or issues:
1. Check [Troubleshooting](#troubleshooting) section above
2. Review [INTELLIGENCE-INTEGRATION-GUIDE.md](./INTELLIGENCE-INTEGRATION-GUIDE.md)
3. Consult intelligence layer documentation
4. Contact Apogee development team
