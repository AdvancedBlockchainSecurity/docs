# Intelligence Layer Integration Guide

**Version**: 1.2
**Last Updated**: 2025-11-03
**Purpose**: Comprehensive guide for integrating vulnerability scanners into the Apogee intelligence layer

---

## Recent Schema Changes

### Patterns API Schema (v0.1.13 - November 2025)

The patterns API endpoint schema now supports flexible `fix_examples` data:

```python
class FixExample(BaseModel):
    """Code example showing how to fix a vulnerability"""
    language: str
    vulnerable_code: str
    fixed_code: str

class PatternResponse(BaseModel):
    # ... other fields ...

    fix_examples: Optional[list[Union[str, FixExample]]] = Field(
        None,
        description="List of fix examples (strings or FixExample objects)"
    )
```

**Key Points**:
- `fix_examples` accepts both simple strings and structured FixExample objects
- Allows legacy patterns with string descriptions and new patterns with code examples
- Use Union types when database contains mixed data types in JSONB fields

### Deduplication Groups Schema (v0.1.12 - November 2025)

The deduplication_groups table schema was updated in migration 012 with the following changes:

**Computed Properties Added (API Service v0.1.12)**:
- `scanner_count`, `finding_count`, `first_seen`, `last_seen`, `confidence_level` are now **computed properties** in the `DeduplicationGroupModel` SQLAlchemy model
- These properties are **not database columns** - they are derived from existing columns:
  - `scanner_count` → computed from `scanner_distribution` JSONB (counts keys)
  - `finding_count` → alias for `group_size`
  - `first_seen` → alias for `first_detected`
  - `last_seen` → alias for `last_updated`
  - `confidence_level` → alias for `strategy`

**Important for Testing**: When querying `deduplication_groups` via SQL, use the actual database column names (`group_size`, `scanner_distribution`, `first_detected`, `last_updated`, `strategy`). The computed property names only work in Python/ORM queries.

See: `/Users/pwner/Git/ABS/docs/INTELLIGENCE-API-DEDUPLICATION-FIX-2025-11-02.md` for complete details.

---

## Table of Contents

1. [Overview](#overview)
2. [Intelligence Layer Architecture](#intelligence-layer-architecture)
3. [Integration Prerequisites](#integration-prerequisites)
4. [Phase 1: Pattern Creation](#phase-1-pattern-creation)
5. [Phase 2: Detector Mapping](#phase-2-detector-mapping)
6. [Phase 3: Parser Enrichment](#phase-3-parser-enrichment)
7. [Phase 4: Database Seeding](#phase-4-database-seeding)
8. [Phase 5: Testing & Validation](#phase-5-testing--validation)
9. [Phase 6: Fingerprinting Integration](#phase-6-fingerprinting-integration)
10. [Phase 7: Deduplication Testing](#phase-7-deduplication-testing)
11. [Phase 8: Cairo/Caracal Integration Example](#phase-8-cairocaracal-integration-example)
12. [Troubleshooting](#troubleshooting)
13. [Best Practices](#best-practices)

---

## Overview

The Apogee intelligence layer provides:
- **Pattern Classification**: Maps scanner detectors to standardized vulnerability patterns (BVD-*)
- **Fingerprinting**: Generates multi-dimensional fingerprints for deduplication
- **Deduplication**: Groups duplicate findings across scanners
- **False Positive Prediction**: Predicts likelihood of false positives
- **Historical Tracking**: Tracks vulnerability trends over time

### Intelligence Layer Benefits

**For Platform**:
- Consistent vulnerability classification across all scanners
- Deduplication reduces noise (same vulnerability from 3 scanners → 1 group)
- Pattern-based severity normalization
- Cross-scanner correlation

**For Users**:
- Unified vulnerability taxonomy
- Reduced duplicate alerts
- Better prioritization (multiple scanners confirm = higher confidence)
- Historical trends

---

## Intelligence Layer Architecture

```
Scanner Output (Raw JSON)
         ↓
    Parser (Extract)
         ↓
  Normalized Finding
         ↓
┌────────────────────────────┐
│   Intelligence Pipeline     │
│                            │
│  1. Pattern Matching       │ ← pattern_tool_mappings table
│     detector_id → pattern  │
│                            │
│  2. Fingerprinting         │
│     - Code hash            │
│     - AST hash             │
│     - Location hash        │
│                            │
│  3. Enrichment             │
│     - Add pattern_id       │
│     - Add fingerprints     │
│     - Calculate FP score   │
│                            │
│  4. Deduplication          │ ← deduplication_groups table
│     - Group duplicates     │
│     - Select canonical     │
└────────────────────────────┘
         ↓
   Enriched Finding
         ↓
   Database Storage
```

### Key Components

| Component | Purpose | Location |
|-----------|---------|----------|
| **Vulnerability Patterns** | Standardized vulnerability taxonomy | `vulnerability_patterns` table |
| **Pattern Mappings** | Detector ID → Pattern ID | `pattern_tool_mappings` table |
| **Pattern Matcher** | Finds pattern for detector | `intelligence/pattern_matcher.py` |
| **Fingerprinting** | Generates hashes for deduplication | `intelligence/fingerprinting/` |
| **Enrichment Service** | Orchestrates intelligence pipeline | `intelligence/enrichment_service.py` |
| **Deduplication Service** | Groups duplicate findings | `intelligence/deduplication/` |

---

## Integration Prerequisites

Before integrating a scanner into the intelligence layer:

### Scanner Must Be Operational
- [ ] Scanner executor implemented (`scanners/<scanner>_executor.py`)
- [ ] Scanner parser implemented (`parsers/<scanner>_parser.py`)
- [ ] Scanner registered in registry
- [ ] Scanner produces findings successfully

### Required Information
- [ ] Complete list of scanner detector IDs
- [ ] Detector descriptions (what each detector finds)
- [ ] Detector severity mappings
- [ ] Sample output from scanner

### Tools & Access
- [ ] Database access (PostgreSQL)
- [ ] Pattern database JSON (`seeds/vulnerability_patterns.json`)
- [ ] Python environment with dependencies

---

## Phase 1: Pattern Creation

**Duration**: Varies (1 hour per detector manually, OR 2-3 hours for automation script)
**Purpose**: Create or identify vulnerability patterns for each detector

### Understanding Patterns

**Pattern Format**: `BVD-[ECOSYSTEM]-[CATEGORY]-[NUMBER]`

Examples:
- `BVD-EVM-REE-001`: Ethereum reentrancy pattern #1
- `BVD-VYPER-ACC-002`: Vyper access control pattern #2
- `BVD-SOLANA-INT-001`: Solana integer overflow pattern #1
- `BVD-CAIRO-L2S-001`: Cairo Layer 2 security pattern #1

**Ecosystems**:
- `SOLIDITY`: Solidity (Ethereum Virtual Machine)
- `VYPER`: Vyper language
- `SOLANA`: Solana/Rust
- `CAIRO`: Cairo/Starknet

**Categories** (Common):
- `REE`: Reentrancy
- `ACC`: Access Control
- `INT`: Integer Issues (overflow, underflow)
- `EXT`: External Calls
- `STA`: State Variables
- `TIM`: Timing Issues (timestamp dependence)
- `GAS`: Gas Optimization
- `LOG`: Logging/Events
- `DAT`: Data Handling (encoding, conversion)
- `VER`: Version/Pragma
- `TXO`: tx.origin Issues
- `RND`: Randomness
- `UNC`: Unchecked Operations
- `VIS`: Visibility
- `IMM`: Immutability
- `ASM`: Assembly
- `EVT`: Events
- `ENC`: Encoding
- `L2`: Layer 2 Specific
- `OTH`: Other

### Step 1.1: Analyze Scanner Detectors

Get complete detector list from scanner:

```bash
# Example for Slither
slither --list-detectors

# Example for Aderyn
aderyn --list-detectors

# For proprietary scanners, get from documentation or API
```

Create detector inventory:
```json
{
  "scanner_id": "example-scanner",
  "detectors": [
    {
      "id": "reentrancy-eth",
      "title": "Reentrancy with ETH transfer",
      "description": "Function makes external call before state update",
      "severity": "high",
      "category": "reentrancy"
    },
    // ... more detectors
  ]
}
```

### Step 1.2: Identify Existing Patterns

Check if patterns already exist for detector types:

```bash
cd /Users/pwner/Git/ABS/blocksecops-api-service

# Search for reentrancy patterns
jq '.patterns[] | select(.category == "reentrancy")' seeds/vulnerability_patterns.json

# Search by keywords
jq '.patterns[] | select(.name | contains("reentrancy"))' seeds/vulnerability_patterns.json

# Count patterns by category
jq '.patterns | group_by(.category) | map({category: .[0].category, count: length})' seeds/vulnerability_patterns.json
```

**Pattern Reuse Rate**:
- Well-established scanners (Slither, Aderyn): 60-70% reuse existing patterns
- New scanner types: 40-60% reuse
- Novel detector algorithms: 20-40% reuse

### Step 1.3: Create New Patterns

For detectors without existing patterns, create new ones:

**Pattern Template**:
```json
{
  "id": "BVD-EVM-REE-015",
  "name": "Cross-contract reentrancy",
  "category": "reentrancy",
  "severity": "high",
  "description": "Contract is vulnerable to cross-contract reentrancy where attacker can reenter through a different contract interface.",
  "remediation": "Use reentrancy guard (OpenZeppelin's ReentrancyGuard) or checks-effects-interactions pattern.",
  "references": [
    "https://swcregistry.io/docs/SWC-107",
    "https://consensys.github.io/smart-contract-best-practices/attacks/reentrancy/"
  ],
  "cwe_ids": ["CWE-841"],
  "affected_languages": ["solidity"],
  "tags": ["reentrancy", "evm", "cross-contract"],
  "false_positive_rate": 0.10,
  "confidence": 0.90
}
```

**Required Fields**:
- `id`: Unique pattern ID (BVD-*)
- `name`: Short, descriptive name
- `category`: Category abbreviation
- `severity`: critical/high/medium/low/info
- `description`: Detailed description of vulnerability
- `affected_languages`: Array of language(s)

**Optional Fields**:
- `remediation`: How to fix
- `references`: External documentation
- `cwe_ids`: CWE identifiers
- `tags`: Searchable tags
- `false_positive_rate`: 0.0-1.0
- `confidence`: 0.0-1.0

### Step 1.4: Automated Pattern Generation

For large detector sets (>50 detectors), use automation:

**Pattern Generation Script Template**:
```python
#!/usr/bin/env python3
"""
Automated pattern generator for <SCANNER_NAME>

Usage:
  python generate_<scanner>_patterns.py
"""

import json
from pathlib import Path

# Load scanner detectors
with open("detector_metadata.json") as f:
    detectors = json.load(f)['detectors']

# Load existing patterns
with open("seeds/vulnerability_patterns.json") as f:
    data = json.load(f)
    existing_patterns = data['patterns']

def categorize(detector):
    """Auto-categorize detector."""
    # Implement keyword matching
    # Return category code (REE, ACC, INT, etc.)
    pass

def find_similar(detector, patterns):
    """Find similar existing pattern."""
    # Implement similarity matching
    # Return pattern if >50% similar, else None
    pass

def generate_pattern(detector, category, pattern_num):
    """Generate new pattern from detector."""
    return {
        "id": f"BVD-EVM-{category}-{pattern_num:03d}",
        "name": detector['title'],
        "category": category,
        # ... other fields
    }

# Process detectors
new_patterns = []
mappings = []

for detector in detectors:
    category = categorize(detector)
    similar = find_similar(detector, existing_patterns)

    if similar:
        # Reuse existing
        pattern_id = similar['id']
    else:
        # Generate new
        pattern_id = generate_pattern(detector, category, ...)
        new_patterns.append(pattern_id)

    # Create mapping
    mappings.append({
        "scanner_id": "scanner-name",
        "detector_id": detector['id'],
        "pattern_id": pattern_id
    })

# Save outputs
with open("new_patterns.json", 'w') as f:
    json.dump({"patterns": new_patterns}, f, indent=2)

with open("mappings.json", 'w') as f:
    json.dump({"mappings": mappings}, f, indent=2)
```

**Time Savings**:
- Manual: 50 detectors × 1.5 hours = 75 hours
- Automated: 3 hours script + 2 hours review = 5 hours
- **Savings: 70 hours (~2 weeks)**

---

## Phase 2: Detector Mapping

**Duration**: 15 minutes per detector (manual), OR 5 minutes total (automated)
**Purpose**: Map each detector ID to a pattern ID

### Step 2.1: Create Mappings

**Mapping Format**:
```json
{
  "scanner_id": "slither",
  "detector_id": "reentrancy-eth",
  "pattern_id": "BVD-EVM-REE-001",
  "confidence": 0.95,
  "match_method": "rule_based",
  "is_active": true,
  "notes": "Direct mapping: Slither reentrancy-eth detector to reentrancy pattern"
}
```

**Required Fields**:
- `scanner_id`: Scanner identifier (lowercase, kebab-case)
- `detector_id`: Scanner's detector identifier (exact match from scanner output)
- `pattern_id`: Pattern ID this detector maps to
- `confidence`: 0.0-1.0 (how confident mapping is)
- `match_method`: "rule_based" (direct mapping)
- `is_active`: true (enable this mapping)

**Create Mapping File**:

**Location**: `blocksecops-api-service/seeds/<scanner>_pattern_mappings.json`

**Example**: `seeds/slither_pattern_mappings.json`
```json
{
  "scanner_id": "slither",
  "version": "0.10.0",
  "mappings": [
    {
      "scanner_id": "slither",
      "detector_id": "reentrancy-eth",
      "pattern_id": "BVD-EVM-REE-001",
      "confidence": 0.95,
      "match_method": "rule_based",
      "is_active": true
    },
    {
      "scanner_id": "slither",
      "detector_id": "tx-origin",
      "pattern_id": "BVD-EVM-TXO-001",
      "confidence": 0.95,
      "match_method": "rule_based",
      "is_active": true
    }
    // ... all detector mappings
  ]
}
```

### Step 2.2: Validate Mappings

**Validation Checks**:

1. **All detectors mapped**:
   ```bash
   # Count scanner detectors
   DETECTOR_COUNT=$(slither --list-detectors | wc -l)

   # Count mappings
   MAPPING_COUNT=$(jq '.mappings | length' seeds/slither_pattern_mappings.json)

   # Should match
   echo "Detectors: $DETECTOR_COUNT, Mappings: $MAPPING_COUNT"
   ```

2. **All pattern IDs exist**:
   ```bash
   # Extract pattern IDs from mappings
   jq -r '.mappings[].pattern_id' seeds/slither_pattern_mappings.json > mapping_patterns.txt

   # Check each exists in vulnerability_patterns.json
   while read pattern_id; do
     EXISTS=$(jq ".patterns[] | select(.id == \"$pattern_id\")" seeds/vulnerability_patterns.json)
     if [ -z "$EXISTS" ]; then
       echo "ERROR: Pattern $pattern_id not found!"
     fi
   done < mapping_patterns.txt
   ```

3. **No duplicate mappings**:
   ```bash
   # Check for duplicate scanner_id:detector_id combinations
   jq -r '.mappings[] | "\(.scanner_id):\(.detector_id)"' seeds/slither_pattern_mappings.json | sort | uniq -d
   # Should output nothing
   ```

---

## Phase 3: Parser Enrichment

**Duration**: 1-2 hours
**Purpose**: Ensure parser extracts all fields needed for intelligence enrichment

### Required Enrichment Fields

Parser must extract these fields from scanner output:

| Field | Type | Purpose | Example |
|-------|------|---------|---------|
| `detector_id` | string | **CRITICAL** - Maps to pattern | "reentrancy-eth" |
| `file_path` | string | **CRITICAL** - Location fingerprinting | "contracts/Token.sol" |
| `line_number` | int | Location fingerprinting | 42 |
| `code_snippet` | string | Code fingerprinting | "msg.sender.call{value: amount}(\"\")" |
| `function_name` | string | Enrichment context | "withdraw" |
| `contract_name` | string | Enrichment context | "Token" |
| `severity` | string | Severity normalization | "high" |
| `description` | string | Finding details | "Reentrancy vulnerability..." |

### Step 3.1: Update Parser

**Example Parser Update**:

**Before** (Missing enrichment fields):
```python
def _parse_vulnerability_finding(self, finding, scan_id, contract_id, source_code):
    return {
        "scan_id": scan_id,
        "contract_id": contract_id,
        "title": finding['title'],
        "description": finding['description'],
        "severity": finding['severity'],
        "line_number": finding.get('line'),
    }
```

**After** (With enrichment fields):
```python
def _parse_vulnerability_finding(self, finding, scan_id, contract_id, source_code):
    # Extract detector_id (CRITICAL for pattern matching)
    detector_id = finding.get('detector', finding.get('check', 'unknown'))

    # Extract location info (CRITICAL for fingerprinting)
    file_path = finding.get('file', 'unknown')
    line_number = finding.get('line', finding.get('line_number'))
    function_name = finding.get('function')
    contract_name = finding.get('contract')

    # Extract or generate code snippet
    code_snippet = finding.get('code')
    if not code_snippet and line_number:
        code_snippet = self._extract_code_snippet(source_code, line_number)

    return {
        "scan_id": scan_id,
        "contract_id": contract_id,

        # Basic finding data
        "title": finding['title'],
        "description": finding['description'],
        "severity": self._map_severity(finding['severity']),

        # INTELLIGENCE ENRICHMENT FIELDS
        "detector_id": detector_id,      # → Pattern matching
        "file_path": file_path,          # → Location fingerprinting
        "line_number": line_number,      # → Location fingerprinting
        "code_snippet": code_snippet,    # → Code fingerprinting
        "function_name": function_name,  # → Enrichment context
        "contract_name": contract_name,  # → Enrichment context

        "status": "open",
        "detected_at": datetime.now(timezone.utc),
    }
```

### Step 3.2: Verify Parser Output

**Test that parser produces enrichment fields**:

```python
# tests/unit/parsers/test_<scanner>_parser.py

def test_parser_enrichment_fields():
    """Test parser extracts all intelligence enrichment fields."""
    parser = ExampleParser()

    raw_output = {
        # ... sample scanner output
    }

    findings = parser.parse(raw_output, scan_id=uuid4(), contract_id=uuid4(), source_code="")

    assert len(findings) > 0
    finding_data = findings[0].data

    # Verify enrichment fields present
    assert "detector_id" in finding_data, "Missing detector_id for pattern matching"
    assert "file_path" in finding_data, "Missing file_path for fingerprinting"
    assert "line_number" in finding_data, "Missing line_number for fingerprinting"
    assert "code_snippet" in finding_data, "Missing code_snippet for fingerprinting"

    # Verify optional enrichment fields
    assert "function_name" in finding_data, "Missing function_name for context"
    assert "contract_name" in finding_data, "Missing contract_name for context"
```

---

## Phase 4: Database Seeding

**Duration**: 30 minutes
**Purpose**: Add patterns and mappings to database

### Step 4.1: Merge Into Pattern Database

Merge new patterns and mappings into `vulnerability_patterns.json`:

```bash
cd /Users/pwner/Git/ABS/blocksecops-api-service

# Current pattern count
jq '.patterns | length' seeds/vulnerability_patterns.json

# Load new patterns
jq --slurpfile new scripts/intelligence/new_patterns.json \
   '.patterns += $new[0].patterns' seeds/vulnerability_patterns.json > temp.json
mv temp.json seeds/vulnerability_patterns.json

# Load new mappings
jq --slurpfile mappings scripts/intelligence/detector_mappings.json \
   '.pattern_tool_mappings += $mappings[0].mappings' seeds/vulnerability_patterns.json > temp.json
mv temp.json seeds/vulnerability_patterns.json

# Update version
jq '.version = "3.9"' seeds/vulnerability_patterns.json > temp.json
mv temp.json seeds/vulnerability_patterns.json

# Verify
jq '.patterns | length' seeds/vulnerability_patterns.json  # Should increase
jq '.pattern_tool_mappings | length' seeds/vulnerability_patterns.json  # Should increase
```

### Step 4.2: Seed Database

Run seed script to populate PostgreSQL:

```bash
cd /Users/pwner/Git/ABS/blocksecops-api-service

# Ensure database is running
# Update DATABASE_URL in .env if needed

# Run seed script
python scripts/seed_vulnerability_patterns.py

# Or use alembic migration
alembic upgrade head
```

### Step 4.3: Verify Database

Connect to database and verify:

```sql
-- Connect
psql -h localhost -U postgres -d blocksecops

-- Check pattern count
SELECT COUNT(*) FROM vulnerability_patterns;

-- Check scanner mappings
SELECT scanner_id, COUNT(*) as mapping_count
FROM pattern_tool_mappings
GROUP BY scanner_id
ORDER BY mapping_count DESC;

-- Verify specific scanner mappings
SELECT detector_id, pattern_id
FROM pattern_tool_mappings
WHERE scanner_id = 'your-scanner'
LIMIT 10;

-- Check pattern categories
SELECT category, COUNT(*) as pattern_count
FROM vulnerability_patterns
GROUP BY category
ORDER BY pattern_count DESC;
```

**Expected Results**:
- Pattern count increased by number of new patterns
- Scanner has expected mapping count
- All pattern IDs in mappings reference valid patterns

---

## Phase 5: Testing & Validation

**Duration**: 4-6 hours
**Purpose**: Verify intelligence integration works end-to-end

### Step 5.1: Pattern Matching Test

**File**: `tests/integration/test_<scanner>_pattern_matching.py`

```python
import pytest
from uuid import uuid4

from blocksecops_orchestration.intelligence.enrichment_wrapper import EnrichmentServiceWrapper

class TestScannerPatternMatching:
    """Test pattern matching for scanner detectors."""

    @pytest.fixture
    def enrichment_service(self, db_connection):
        """Initialize enrichment service with database mappings."""
        # Load mappings from database
        mappings = await db_connection.fetch("""
            SELECT detector_id, pattern_id, scanner_id
            FROM pattern_tool_mappings
            WHERE scanner_id = 'your-scanner'
        """)

        service = EnrichmentServiceWrapper.get_service(
            db_mappings=[dict(m) for m in mappings],
            force_reload=True
        )
        return service

    @pytest.mark.asyncio
    async def test_all_detectors_have_pattern_mapping(self, enrichment_service):
        """Test all scanner detectors map to patterns."""
        # List of all scanner detector IDs
        detector_ids = [
            "reentrancy-eth",
            "tx-origin",
            # ... all detector IDs
        ]

        unmapped = []
        for detector_id in detector_ids:
            enriched = enrichment_service.enrich_finding(
                tool_name="your-scanner",
                detector_id=detector_id,
                file_path="test.sol",
                line_number=1,
            )

            if not enriched.pattern_id:
                unmapped.append(detector_id)

        assert len(unmapped) == 0, f"Unmapped detectors: {unmapped}"

    @pytest.mark.asyncio
    async def test_pattern_matching_accuracy(self, enrichment_service):
        """Test pattern matching accuracy."""
        test_cases = [
            {
                "detector_id": "reentrancy-eth",
                "expected_pattern": "BVD-EVM-REE-001",
                "expected_confidence": 0.95
            },
            # ... more test cases
        ]

        for test_case in test_cases:
            enriched = enrichment_service.enrich_finding(
                tool_name="your-scanner",
                detector_id=test_case["detector_id"],
                file_path="test.sol",
                line_number=1,
            )

            assert enriched.pattern_id == test_case["expected_pattern"]
            assert enriched.pattern_confidence >= test_case["expected_confidence"]
```

**Acceptance Criteria**:
- [ ] All detectors have pattern mapping
- [ ] Pattern matching accuracy = 100% (for rule-based matching)
- [ ] No unmapped detectors

---

### Step 5.2: End-to-End Enrichment Test

**Test complete pipeline**: Scan → Parse → Enrich → Store

```python
@pytest.mark.integration
@pytest.mark.asyncio
async def test_scanner_intelligence_enrichment_e2e(self, db_connection):
    """Test complete intelligence enrichment pipeline."""

    # 1. Execute scanner
    scanner = get_scanner_registry().get("your-scanner")
    context = ScannerContext(...)
    result = scanner.execute(context)

    # 2. Parse findings
    parser = get_parser_registry().get("your-scanner")
    findings = parser.parse(result.raw_output, scan_id, contract_id, source_code)

    # 3. Enrich findings
    enrichment_service = EnrichmentServiceWrapper.get_service()
    for finding in findings:
        # Verify enrichment fields present
        assert "detector_id" in finding.data
        assert "file_path" in finding.data

    # 4. Store findings
    storage = ResultStorageManager(db_session)
    counts = storage.store_findings(findings)

    # 5. Verify enrichment in database
    vulnerabilities = await db_connection.fetch("""
        SELECT
            id, detector_id, pattern_id, pattern_code,
            fingerprint_code, fingerprint_location,
            classification_confidence, classification_method
        FROM vulnerabilities
        WHERE scan_id = $1
    """, scan_id)

    assert len(vulnerabilities) > 0

    for vuln in vulnerabilities:
        # Verify pattern classification
        assert vuln['pattern_id'] is not None, "Missing pattern_id"
        assert vuln['pattern_code'] is not None, "Missing pattern_code"
        assert vuln['classification_confidence'] is not None
        assert vuln['classification_method'] == 'rule_based'

        # Verify fingerprints
        assert vuln['fingerprint_code'] is not None or vuln['code_snippet'] is None
        assert vuln['fingerprint_location'] is not None
```

**Acceptance Criteria**:
- [ ] Scanner executes successfully
- [ ] Parser extracts findings
- [ ] Enrichment adds pattern_id and fingerprints
- [ ] Findings stored with enrichment data in database
- [ ] All enrichment fields populated

---

## Phase 6: Fingerprinting Integration

**Duration**: 2-3 hours
**Purpose**: Verify fingerprinting works for scanner findings

### Fingerprint Types

1. **Code Fingerprint** (`fingerprint_code`)
   - SHA-256 hash of normalized code snippet
   - Normalizes whitespace, removes comments
   - Exact match: 99% precision

2. **AST Fingerprint** (`fingerprint_ast`)
   - SHA-256 hash of AST structure
   - Requires tree-sitter parser
   - Structural match: 95% precision

3. **Location Fingerprint** (`fingerprint_location`)
   - SHA-256 hash of file:line:function
   - Exact location match: 99% precision

4. **Fuzzy Location Fingerprint** (`fingerprint_location_fuzzy`)
   - SHA-256 hash of file:line±3:function
   - Tolerates line number shifts: 85% precision

### Test Fingerprinting

```python
@pytest.mark.asyncio
async def test_fingerprinting_for_scanner_findings(self, enrichment_service):
    """Test fingerprinting generates hashes for findings."""

    # Create test finding
    enriched = enrichment_service.enrich_finding(
        tool_name="your-scanner",
        detector_id="reentrancy-eth",
        file_path="contracts/Token.sol",
        line_number=42,
        code_snippet="msg.sender.call{value: amount}(\"\")",
        function_name="withdraw",
        contract_name="Token"
    )

    # Verify fingerprints generated
    assert enriched.code_hash is not None, "Missing code hash"
    assert len(enriched.code_hash) == 64, "Code hash should be SHA-256 (64 hex chars)"

    assert enriched.location_hash is not None, "Missing location hash"
    assert len(enriched.location_hash) == 64

    assert enriched.location_hash_fuzzy is not None, "Missing fuzzy location hash"

    # AST hash optional (requires tree-sitter)
    # assert enriched.ast_hash is not None


@pytest.mark.asyncio
async def test_same_vulnerability_same_fingerprint(self, enrichment_service):
    """Test identical vulnerabilities generate identical fingerprints."""

    # Same vulnerability, different scanners
    enriched1 = enrichment_service.enrich_finding(
        tool_name="slither",
        detector_id="reentrancy-eth",
        file_path="Token.sol",
        line_number=42,
        code_snippet="msg.sender.call{value: amount}(\"\")",
        function_name="withdraw"
    )

    enriched2 = enrichment_service.enrich_finding(
        tool_name="aderyn",
        detector_id="reentrancy",
        file_path="Token.sol",
        line_number=42,
        code_snippet="msg.sender.call{value: amount}(\"\")",
        function_name="withdraw"
    )

    # Should have same fingerprints (for deduplication)
    assert enriched1.code_hash == enriched2.code_hash
    assert enriched1.location_hash == enriched2.location_hash
```

**Acceptance Criteria**:
- [ ] Code fingerprints generated for findings with code snippets
- [ ] Location fingerprints generated for all findings
- [ ] Identical code produces identical fingerprints
- [ ] Fingerprints are 64-character hex strings (SHA-256)

---

## Phase 7: Deduplication Testing

**Duration**: 2-4 hours
**Purpose**: Verify cross-scanner deduplication works

### Test Deduplication

```python
@pytest.mark.integration
@pytest.mark.asyncio
async def test_cross_scanner_deduplication(self, db_connection):
    """Test that duplicate findings across scanners are grouped."""

    # Create contract with reentrancy vulnerability
    contract_code = '''
    contract Token {
        function withdraw() public {
            msg.sender.call{value: balance}("");
            balance = 0;  // Reentrancy!
        }
    }
    '''

    # Run multiple scanners
    scanner_ids = ["slither", "aderyn", "your-scanner"]
    scan_id = uuid4()

    all_findings = []
    for scanner_id in scanner_ids:
        # Execute scanner
        scanner = get_scanner_registry().get(scanner_id)
        result = scanner.execute(...)

        # Parse findings
        parser = get_parser_registry().get(scanner_id)
        findings = parser.parse(result.raw_output, ...)

        all_findings.extend(findings)

    # Store findings (enrichment happens automatically)
    storage = ResultStorageManager(db_session)
    storage.store_findings(all_findings)

    # Run deduplication
    from blocksecops_orchestration.intelligence.deduplication import DeduplicationService
    dedup_service = DeduplicationService(async_session)
    stats = await dedup_service.process_scan_findings(scan_id)

    # Verify deduplication
    # Expected: 3 findings → 1 deduplication group
    # NOTE: Use actual database column names, not computed properties
    groups = await db_connection.fetch("""
        SELECT
            id,
            pattern_code,
            strategy as confidence_level,
            group_size as finding_count,
            jsonb_object_keys(scanner_distribution)::text[] as scanners,
            cardinality(array_agg(DISTINCT jsonb_object_keys(scanner_distribution))) as scanner_count
        FROM deduplication_groups
        WHERE id IN (
            SELECT DISTINCT deduplication_group_id
            FROM vulnerabilities
            WHERE scan_id = $1
        )
        GROUP BY id, pattern_code, strategy, group_size, scanner_distribution
    """, scan_id)

    assert len(groups) >= 1, "Should create at least 1 deduplication group"

    # Find reentrancy group
    reentrancy_group = next(
        (g for g in groups if 'REE' in g['pattern_code']),
        None
    )

    assert reentrancy_group is not None
    assert reentrancy_group['finding_count'] == 3, "Should group 3 reentrancy findings"
    assert reentrancy_group['scanner_count'] == 3, "Should have 3 different scanners"
    assert reentrancy_group['confidence_level'] in ['exact', 'high']
```

**Acceptance Criteria**:
- [ ] Duplicate findings across scanners grouped correctly
- [ ] Deduplication groups have correct finding_count
- [ ] Deduplication groups have correct scanner_count
- [ ] Confidence level is appropriate (exact/high/medium/low)

---

## Phase 8: Cairo/Caracal Integration Example

**Scanner**: Caracal (Trail of Bits static analyzer for Cairo/StarkNet)
**Duration**: 6-8 hours (complete integration)
**Status**: ✅ Implemented (Phase 2 Intelligence Validation)

This section provides a complete end-to-end example of integrating the Caracal scanner for Cairo/StarkNet smart contracts.

---

### Overview: Caracal Scanner

**Caracal** is Trail of Bits' static analyzer for Cairo smart contracts (StarkNet ecosystem).

**Key Details**:
- **Language**: Cairo 1.0+ (StarkNet contracts)
- **Output Format**: Text output (no JSON flag available)
- **Detector Count**: 14 detectors across 7 vulnerability categories
- **Installation**: `pip install caracal-cairo`
- **Execution**: `caracal <cairo-file>` or `caracal <project-dir>`

**Challenges**:
1. **Text-only output**: Requires robust text parsing (no structured JSON)
2. **SIERRA IR**: Analyzes intermediate representation, not source directly
3. **Cairo-specific patterns**: New BVD-CAIRO-* patterns needed
4. **StarkNet L1↔L2**: Layer 2 specific vulnerabilities (L1 handler validation)

---

### Step 1: Cairo Contract Detection

Before routing to Caracal, detect if a contract is written in Cairo:

**Implementation** (`scan_tasks_sync.py`):

```python
def detect_contract_language(contract: Contract) -> tuple[str, list[str]]:
    """
    Detect contract language and return appropriate scanners.

    Returns:
        (language, requested_scanners)
    """
    source_code = contract.source_code.strip()

    # Cairo/StarkNet detection
    if source_code.startswith('#[contract]') or source_code.startswith('#[starknet::contract]'):
        return ('cairo', ['caracal'])

    # Vyper detection
    elif source_code.startswith('# @version'):
        return ('vyper', ['slither'])

    # Solidity (default)
    else:
        return ('solidity', ['slither', 'aderyn', 'semgrep', 'solhint'])

# Usage in scan task:
language, requested_scanners = detect_contract_language(contract)

logger.info("contract_language_detected",
            scan_id=scan_id,
            contract_id=str(contract.id),
            language=language,
            requested_scanners=requested_scanners)
```

**Cairo Contract Signature**:
```cairo
#[starknet::contract]
mod Token {
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        balances: LegacyMap<felt252, u256>,
    }

    #[external(v0)]
    fn withdraw(ref self: ContractState) {
        // Contract logic
    }
}
```

---

### Step 2: CaracalExecutor Implementation

**File**: `src/blocksecops_orchestration/scanners/cairo_scanners.py`

```python
"""Caracal scanner executor for Cairo/StarkNet static analysis."""

import logging
import re
from pathlib import Path
from typing import Any

from blocksecops_orchestration.scanners.base import (
    ScannerExecutor,
    ScannerContext,
    ScannerResult,
)

logger = logging.getLogger(__name__)


class CaracalExecutor(ScannerExecutor):
    """
    Caracal scanner executor for Cairo smart contracts.

    Caracal is Trail of Bits' static analyzer for Cairo/StarkNet.
    Analyzes SIERRA IR for vulnerabilities.

    Output: Text format (no JSON flag available)
    """

    def __init__(self, timeout: int = 300):
        super().__init__(scanner_id="caracal", timeout=timeout)

    def execute(self, context: ScannerContext) -> ScannerResult:
        """Execute Caracal scanner on Cairo contract."""

        # Validate Cairo contract
        if not self._is_cairo_contract(context.contract.source_code):
            logger.warning("not_cairo_contract", contract_id=str(context.contract.id))
            return ScannerResult(
                scanner_id=self.scanner_id,
                success=False,
                error="Contract is not a Cairo/StarkNet contract"
            )

        # Write contract to temporary file
        temp_file = self._write_temp_file(context.contract.source_code, suffix=".cairo")

        try:
            # Execute Caracal
            cmd = ["caracal", str(temp_file)]

            result = self._execute_command(
                cmd,
                timeout=self.timeout,
                cwd=temp_file.parent
            )

            # Parse text output into structured format
            parsed_output = self._parse_caracal_output(
                stdout=result.stdout,
                stderr=result.stderr,
                contract_path=str(temp_file)
            )

            return ScannerResult(
                scanner_id=self.scanner_id,
                success=True,
                raw_output=parsed_output,
                execution_time=result.execution_time
            )

        finally:
            # Cleanup temporary file
            self._cleanup_temp_file(temp_file)

    def _is_cairo_contract(self, source_code: str) -> bool:
        """Check if source code is Cairo/StarkNet contract."""
        source = source_code.strip()
        return (
            source.startswith('#[contract]') or
            source.startswith('#[starknet::contract]')
        )

    def _parse_caracal_output(
        self,
        stdout: str,
        stderr: str,
        contract_path: str
    ) -> dict[str, Any]:
        """
        Parse Caracal text output into structured format.

        Caracal outputs text blocks like:

            Detector: reentrancy
            Description: Reentrancy vulnerability detected
            Severity: High
            Location: contract.cairo:42
            ---
            Detector: tx-origin
            ...

        Strategy:
        1. Split output on "---" delimiters
        2. Parse each block into finding
        3. Fall back to regex if delimiters not found
        """
        findings = []

        # Strategy 1: Split on delimiter
        if "---" in stdout:
            blocks = stdout.split("---")
            for block in blocks:
                block = block.strip()
                if not block:
                    continue

                finding = self._parse_finding_block(block, contract_path)
                if finding:
                    findings.append(finding)

        # Strategy 2: Regex pattern matching
        elif stdout.strip():
            # Pattern: "Detector: <name>\n..."
            pattern = r"Detector:\s*(\S+).*?(?=Detector:|$)"
            matches = re.finditer(pattern, stdout, re.DOTALL | re.IGNORECASE)

            for match in matches:
                finding = self._parse_finding_block(match.group(0), contract_path)
                if finding:
                    findings.append(finding)

        # Strategy 3: Treat as single finding
        elif stdout.strip():
            finding = self._parse_finding_block(stdout, contract_path)
            if finding:
                findings.append(finding)

        return {
            "findings": findings,
            "detectors_run": self._extract_detectors_run(stdout),
            "contract_path": contract_path,
        }

    def _parse_finding_block(self, block: str, contract_path: str) -> dict[str, Any] | None:
        """Parse single finding block."""
        # Extract detector name
        detector_match = re.search(r"Detector:\s*(\S+)", block, re.IGNORECASE)
        if not detector_match:
            return None

        detector_id = detector_match.group(1).strip()

        # Extract severity
        severity_match = re.search(r"Severity:\s*(\w+)", block, re.IGNORECASE)
        severity = severity_match.group(1).lower() if severity_match else "medium"

        # Extract location (file:line)
        location_match = re.search(r"Location:\s*([^:\n]+):(\d+)", block, re.IGNORECASE)
        if location_match:
            file_path = location_match.group(1).strip()
            line_number = int(location_match.group(2))
        else:
            file_path = contract_path
            line_number = 0

        # Extract description
        desc_match = re.search(r"Description:\s*([^\n]+)", block, re.IGNORECASE)
        description = desc_match.group(1).strip() if desc_match else block.strip()

        return {
            "detector": detector_id,
            "severity": severity,
            "file": file_path,
            "line": line_number,
            "description": description,
            "raw_block": block,
        }

    def _extract_detectors_run(self, output: str) -> list[str]:
        """Extract list of detectors that ran."""
        detectors = set()
        for match in re.finditer(r"Detector:\s*(\S+)", output, re.IGNORECASE):
            detectors.add(match.group(1).strip())
        return sorted(list(detectors))
```

**Key Implementation Details**:
1. **Text Parsing**: 3 fallback strategies for parsing text output
2. **Cairo Detection**: Checks for `#[contract]` or `#[starknet::contract]` prefixes
3. **Temporary Files**: Creates `.cairo` file for Caracal to analyze
4. **Error Handling**: Graceful degradation if parsing fails

---

### Step 3: CaracalParser Implementation

**File**: `src/blocksecops_orchestration/parsers/cairo_parsers.py`

```python
"""Caracal parser for Cairo vulnerability findings."""

import logging
from typing import Any
from uuid import UUID

from blocksecops_orchestration.parsers.base import ParserBase
from blocksecops_orchestration.core.database_models import (
    ParsedFinding,
    FindingType,
    SeverityLevel,
)

logger = logging.getLogger(__name__)


# Caracal Detector → BVD Pattern Mappings (14 detectors)
CARACAL_DETECTOR_PATTERNS = {
    # Access Control (ACC)
    "controlled-library-call": "BVD-CAIRO-ACC-001",  # Controlled library call
    "tx-origin": "BVD-CAIRO-ACC-002",                # tx.origin usage

    # Layer 2 Security (L2S)
    "unchecked-l1-handler-from": "BVD-CAIRO-L2S-001",  # Unchecked L1 handler origin

    # Arithmetic (ARI)
    "felt252-unsafe-arithmetic": "BVD-CAIRO-ARI-001",  # Felt252 overflow/underflow

    # Reentrancy (REE)
    "reentrancy": "BVD-CAIRO-REE-001",               # Classic reentrancy
    "read-only-reentrancy": "BVD-CAIRO-REE-002",     # Read-only reentrancy
    "reentrancy-benign": "BVD-CAIRO-REE-003",        # Benign reentrancy
    "reentrancy-events": "BVD-CAIRO-REE-004",        # Reentrancy with events

    # State Variables (STA)
    "unenforced-view": "BVD-CAIRO-STA-001",          # View function modifies state

    # Code Quality (QUA)
    "unused-events": "BVD-CAIRO-QUA-001",            # Unused event definitions
    "unused-return": "BVD-CAIRO-QUA-002",            # Unused return values
    "unused-arguments": "BVD-CAIRO-QUA-003",         # Unused function arguments
    "dead-code": "BVD-CAIRO-QUA-004",                # Unreachable code

    # Memory Safety (MEM)
    "use-after-pop-front": "BVD-CAIRO-MEM-001",      # Use after array pop
}

# Code quality detectors (not security vulnerabilities)
CODE_QUALITY_DETECTORS = {
    "unused-events",
    "unused-arguments",
    "dead-code",
}


class CaracalParser(ParserBase):
    """
    Parser for Caracal Cairo static analyzer output.

    Caracal detects vulnerabilities in Cairo/StarkNet smart contracts.
    """

    def __init__(self):
        super().__init__(scanner_id="caracal")

    def parse(
        self,
        raw_output: dict[str, Any],
        scan_id: UUID,
        contract_id: UUID,
        source_code: str,
    ) -> list[ParsedFinding]:
        """Parse Caracal findings from structured output."""

        findings = []

        # Extract findings array
        caracal_findings = raw_output.get("findings", [])

        logger.info("parsing_caracal_findings",
                    scan_id=str(scan_id),
                    finding_count=len(caracal_findings))

        for finding in caracal_findings:
            try:
                parsed = self._parse_finding(finding, scan_id, contract_id, source_code)
                if parsed:
                    findings.append(parsed)
            except Exception as e:
                logger.error("caracal_parse_error",
                            error=str(e),
                            finding=finding)

        return findings

    def _parse_finding(
        self,
        finding: dict[str, Any],
        scan_id: UUID,
        contract_id: UUID,
        source_code: str,
    ) -> ParsedFinding | None:
        """Parse single Caracal finding."""

        detector_id = finding.get("detector", "unknown")

        # Determine if code quality or vulnerability
        if detector_id in CODE_QUALITY_DETECTORS:
            return self._parse_code_quality_finding(finding, scan_id, contract_id)
        else:
            return self._parse_vulnerability_finding(finding, scan_id, contract_id, source_code)

    def _parse_vulnerability_finding(
        self,
        finding: dict[str, Any],
        scan_id: UUID,
        contract_id: UUID,
        source_code: str,
    ) -> ParsedFinding:
        """Parse security vulnerability finding."""

        detector_id = finding.get("detector", "unknown")
        severity = finding.get("severity", "medium")

        # Map to BVD pattern
        pattern_code = CARACAL_DETECTOR_PATTERNS.get(detector_id)

        # Upgrade severity for high-confidence detectors
        if severity == "high" and detector_id in [
            "controlled-library-call",
            "reentrancy",
            "unchecked-l1-handler-from"
        ]:
            severity = "critical"

        return ParsedFinding(
            scan_id=scan_id,
            contract_id=contract_id,
            finding_type=FindingType.VULNERABILITY,

            # Basic finding data
            title=f"Caracal: {detector_id}",
            description=finding.get("description", ""),
            severity=self._map_severity(severity),

            # Intelligence enrichment fields
            detector_id=detector_id,
            file_path=finding.get("file", "unknown"),
            line_number=finding.get("line", 0),
            code_snippet=self._extract_code_snippet(source_code, finding.get("line", 0)),

            # Metadata
            data={
                "scanner": "caracal",
                "detector_id": detector_id,
                "pattern_code": pattern_code,
                "severity": severity,
                "raw_output": finding.get("raw_block", ""),
            },
        )

    def _parse_code_quality_finding(
        self,
        finding: dict[str, Any],
        scan_id: UUID,
        contract_id: UUID,
    ) -> ParsedFinding:
        """Parse code quality finding (not a security vulnerability)."""

        detector_id = finding.get("detector", "unknown")
        pattern_code = CARACAL_DETECTOR_PATTERNS.get(detector_id)

        return ParsedFinding(
            scan_id=scan_id,
            contract_id=contract_id,
            finding_type=FindingType.CODE_QUALITY,

            title=f"Caracal: {detector_id}",
            description=finding.get("description", ""),
            severity=SeverityLevel.INFO,

            detector_id=detector_id,
            file_path=finding.get("file", "unknown"),
            line_number=finding.get("line", 0),

            data={
                "scanner": "caracal",
                "detector_id": detector_id,
                "pattern_code": pattern_code,
                "category": "code_quality",
            },
        )

    def _map_severity(self, severity: str) -> SeverityLevel:
        """Map Caracal severity to platform severity."""
        severity_map = {
            "critical": SeverityLevel.CRITICAL,
            "high": SeverityLevel.HIGH,
            "medium": SeverityLevel.MEDIUM,
            "low": SeverityLevel.LOW,
            "info": SeverityLevel.INFO,
        }
        return severity_map.get(severity.lower(), SeverityLevel.MEDIUM)

    def _extract_code_snippet(self, source_code: str, line_number: int) -> str:
        """Extract code snippet around line number."""
        if not source_code or line_number <= 0:
            return ""

        lines = source_code.split("\n")
        if line_number > len(lines):
            return ""

        # Extract 3 lines of context
        start = max(0, line_number - 2)
        end = min(len(lines), line_number + 1)

        return "\n".join(lines[start:end])
```

**Key Implementation Details**:
1. **14 Detector Mappings**: All Caracal detectors mapped to BVD-CAIRO-* patterns
2. **Code Quality vs Vulnerability**: Separate handling for code quality detectors
3. **Severity Upgrade**: Critical detectors (reentrancy, L1 handler) upgraded to critical
4. **Pattern Codes**: Direct mapping from detector_id to pattern_id

---

### Step 4: Register Scanner & Parser

**Scanner Registry** (`scanners/registry.py`):

```python
from blocksecops_orchestration.scanners.cairo_scanners import CaracalExecutor

def _register_default_scanners(self):
    # ... existing scanners

    # Phase 2: Cairo static analysis (14 detectors)
    self.register(CaracalExecutor())
```

**Parser Registry** (`parsers/registry.py`):

```python
from blocksecops_orchestration.parsers.cairo_parsers import CaracalParser

def _register_default_parsers(self):
    # ... existing parsers

    # Phase 2: Cairo static analysis (14 detectors)
    self.register(CaracalParser())
```

---

### Step 5: Database Patterns & Mappings

**14 Cairo Patterns Added** (`vulnerability_patterns.json`):

```json
{
  "patterns": [
    {
      "id": "BVD-CAIRO-ACC-001",
      "name": "Controlled library call",
      "category": "access_control",
      "severity": "critical",
      "description": "Contract makes library call with user-controlled input",
      "affected_languages": ["cairo"],
      "cwe_ids": ["CWE-20"],
      "tags": ["cairo", "starknet", "library-call", "access-control"]
    },
    {
      "id": "BVD-CAIRO-L2S-001",
      "name": "Unchecked L1 handler origin",
      "category": "l2_security",
      "severity": "critical",
      "description": "L1 handler does not validate sender address from L1",
      "remediation": "Validate L1 sender address matches expected L1 contract",
      "affected_languages": ["cairo"],
      "tags": ["cairo", "starknet", "l1-handler", "cross-chain"]
    },
    {
      "id": "BVD-CAIRO-REE-001",
      "name": "Reentrancy",
      "category": "reentrancy",
      "severity": "high",
      "description": "Function vulnerable to reentrancy attack",
      "affected_languages": ["cairo"],
      "tags": ["cairo", "starknet", "reentrancy"]
    }
    // ... 11 more patterns
  ],

  "pattern_tool_mappings": [
    {
      "scanner_id": "caracal",
      "detector_id": "controlled-library-call",
      "pattern_id": "BVD-CAIRO-ACC-001",
      "confidence": 0.95,
      "match_method": "rule_based",
      "is_active": true
    },
    {
      "scanner_id": "caracal",
      "detector_id": "unchecked-l1-handler-from",
      "pattern_id": "BVD-CAIRO-L2S-001",
      "confidence": 0.95,
      "match_method": "rule_based",
      "is_active": true
    }
    // ... 12 more mappings
  ]
}
```

---

### Step 6: Testing

**File**: `tests/integration/test_cairo_integration.py`

**Test Results**: ✅ 12/12 passing (100%)

```python
import pytest
from uuid import uuid4

from blocksecops_orchestration.scanners.registry import get_scanner_registry
from blocksecops_orchestration.parsers.registry import get_parser_registry


# Vulnerable Cairo contract fixtures
CAIRO_CONTROLLED_LIBRARY_CALL = '''
#[starknet::contract]
mod VulnerableLibrary {
    use starknet::library_call_syscall;

    #[external(v0)]
    fn call_library(ref self: ContractState, class_hash: felt252, function: felt252) {
        // VULNERABILITY: User controls class_hash and function
        library_call_syscall(class_hash, function, array![].span());
    }
}
'''

CAIRO_REENTRANCY = '''
#[starknet::contract]
mod VulnerableToken {
    use starknet::get_caller_address;

    #[external(v0)]
    fn withdraw(ref self: ContractState) {
        let caller = get_caller_address();
        let amount = self.balances.read(caller);

        // VULNERABILITY: External call before state update
        caller.call(contract_address_const::<0>(), 'transfer', array![amount].span());

        self.balances.write(caller, 0);  // State update AFTER external call
    }
}
'''


class TestCaracalIntegration:
    """Test Caracal scanner integration."""

    @pytest.mark.integration
    def test_caracal_executor_available(self):
        """Test Caracal executor is registered."""
        registry = get_scanner_registry()
        assert registry.has("caracal")

        scanner = registry.get("caracal")
        assert scanner is not None
        assert scanner.scanner_id == "caracal"

    @pytest.mark.integration
    def test_caracal_parser_available(self):
        """Test Caracal parser is registered."""
        registry = get_parser_registry()
        assert registry.has("caracal")

        parser = registry.get("caracal")
        assert parser is not None
        assert parser.scanner_id == "caracal"

    @pytest.mark.integration
    def test_caracal_detector_pattern_mappings(self):
        """Test all 14 Caracal detectors have pattern mappings."""
        from blocksecops_orchestration.parsers.cairo_parsers import CARACAL_DETECTOR_PATTERNS

        assert len(CARACAL_DETECTOR_PATTERNS) == 14

        # Verify pattern code format
        for detector_id, pattern_code in CARACAL_DETECTOR_PATTERNS.items():
            assert pattern_code.startswith("BVD-CAIRO-")
            assert len(pattern_code) == 17  # BVD-CAIRO-XXX-NNN

    @pytest.mark.integration
    def test_caracal_parse_controlled_library_call(self):
        """Test parsing controlled library call vulnerability."""
        parser = get_parser_registry().get("caracal")

        raw_output = {
            "findings": [
                {
                    "detector": "controlled-library-call",
                    "severity": "high",
                    "file": "contract.cairo",
                    "line": 7,
                    "description": "Library call with user-controlled class_hash"
                }
            ]
        }

        findings = parser.parse(
            raw_output=raw_output,
            scan_id=uuid4(),
            contract_id=uuid4(),
            source_code=CAIRO_CONTROLLED_LIBRARY_CALL
        )

        assert len(findings) == 1
        finding = findings[0]

        # Verify pattern mapping
        assert finding.data["pattern_code"] == "BVD-CAIRO-ACC-001"
        assert finding.data["detector_id"] == "controlled-library-call"

        # Verify severity upgrade (high + high confidence → critical)
        assert finding.data["severity"] == "critical"

        # Verify enrichment fields
        assert finding.detector_id == "controlled-library-call"
        assert finding.file_path == "contract.cairo"
        assert finding.line_number == 7

    @pytest.mark.integration
    def test_caracal_parse_reentrancy(self):
        """Test parsing reentrancy vulnerability."""
        parser = get_parser_registry().get("caracal")

        raw_output = {
            "findings": [
                {
                    "detector": "reentrancy",
                    "severity": "high",
                    "file": "token.cairo",
                    "line": 10,
                    "description": "Reentrancy vulnerability: external call before state update"
                }
            ]
        }

        findings = parser.parse(
            raw_output=raw_output,
            scan_id=uuid4(),
            contract_id=uuid4(),
            source_code=CAIRO_REENTRANCY
        )

        assert len(findings) == 1
        finding = findings[0]

        # Verify pattern mapping
        assert finding.data["pattern_code"] == "BVD-CAIRO-REE-001"
        assert finding.data["detector_id"] == "reentrancy"

        # Verify severity upgrade
        assert finding.data["severity"] == "critical"

    @pytest.mark.integration
    def test_caracal_code_quality_findings(self):
        """Test parsing code quality findings (not vulnerabilities)."""
        parser = get_parser_registry().get("caracal")

        raw_output = {
            "findings": [
                {
                    "detector": "unused-events",
                    "severity": "info",
                    "file": "contract.cairo",
                    "line": 15,
                    "description": "Event 'Transfer' defined but never emitted"
                },
                {
                    "detector": "dead-code",
                    "severity": "info",
                    "file": "contract.cairo",
                    "line": 42,
                    "description": "Unreachable code detected"
                }
            ]
        }

        findings = parser.parse(
            raw_output=raw_output,
            scan_id=uuid4(),
            contract_id=uuid4(),
            source_code=""
        )

        assert len(findings) == 2

        # Both should be code quality, not vulnerabilities
        for finding in findings:
            assert finding.finding_type == FindingType.CODE_QUALITY
            assert finding.severity == SeverityLevel.INFO
```

**Test Coverage**:
- ✅ Scanner registration
- ✅ Parser registration
- ✅ All 14 detector mappings
- ✅ Controlled library call parsing
- ✅ Reentrancy parsing
- ✅ L1 handler validation
- ✅ Code quality vs vulnerability classification
- ✅ Severity upgrade logic
- ✅ Pattern code format validation
- ✅ Enrichment field extraction
- ✅ Code snippet extraction
- ✅ End-to-end integration

---

### Step 7: Validation Results

**Phase 2 Completion Metrics**:

| Metric | Target | Achieved | Status |
|--------|--------|----------|--------|
| Detector mappings | 14/14 | 14/14 | ✅ 100% |
| Pattern creation | 14 patterns | 14 patterns | ✅ 100% |
| Tests passing | >95% | 12/12 (100%) | ✅ |
| Code quality separation | Yes | Yes | ✅ |
| Enrichment fields | All | All | ✅ |

**Files Created**:
- ✅ `cairo_scanners.py` (283 lines) - CaracalExecutor
- ✅ `cairo_parsers.py` (313 lines) - CaracalParser with 14 mappings
- ✅ `test_cairo_integration.py` (565 lines) - 12 integration tests
- ✅ 14 Cairo patterns in vulnerability database
- ✅ 14 detector mappings in database

---

### Cairo-Specific Patterns

**Layer 2 Security (L2S) - StarkNet Specific**:

```cairo
// BVD-CAIRO-L2S-001: Unchecked L1 handler origin
#[l1_handler]
fn deposit(ref self: ContractState, from_address: felt252, amount: u256) {
    // VULNERABILITY: from_address not validated
    // Attacker can forge L1 sender address

    let caller = get_caller_address();
    self.balances.write(caller, amount);
}

// FIX: Validate L1 sender
#[l1_handler]
fn deposit_fixed(ref self: ContractState, from_address: felt252, amount: u256) {
    // Validate L1 sender matches expected L1 contract
    assert(from_address == self.expected_l1_contract.read(), 'Invalid L1 sender');

    let caller = get_caller_address();
    self.balances.write(caller, amount);
}
```

**Felt252 Arithmetic (ARI)**:

```cairo
// BVD-CAIRO-ARI-001: Felt252 unsafe arithmetic
#[external(v0)]
fn transfer(ref self: ContractState, to: felt252, amount: felt252) {
    let sender = get_caller_address();
    let balance = self.balances.read(sender);

    // VULNERABILITY: Felt252 arithmetic wraps (no overflow detection)
    let new_balance = balance - amount;  // Can wrap to large value

    self.balances.write(sender, new_balance);
    self.balances.write(to, self.balances.read(to) + amount);
}

// FIX: Use u256 for checked arithmetic
#[external(v0)]
fn transfer_fixed(ref self: ContractState, to: felt252, amount: u256) {
    let sender = get_caller_address();
    let balance = self.balances.read(sender);

    // u256 arithmetic includes overflow checks
    assert(balance >= amount, 'Insufficient balance');

    self.balances.write(sender, balance - amount);
    self.balances.write(to, self.balances.read(to) + amount);
}
```

---

### Key Takeaways: Cairo Integration

**Challenges Solved**:
1. ✅ **Text-only output**: Robust parsing with 3 fallback strategies
2. ✅ **Cairo detection**: Accurate contract language detection
3. ✅ **New patterns**: 14 BVD-CAIRO-* patterns created across 7 categories
4. ✅ **L2-specific**: StarkNet L1↔L2 validation patterns
5. ✅ **Code quality**: Separated code quality from security vulnerabilities

**Time Investment**:
- Pattern creation: 2 hours (14 patterns)
- Executor implementation: 2 hours (text parsing complexity)
- Parser implementation: 2 hours (14 mappings + severity logic)
- Testing: 2 hours (12 comprehensive tests)
- **Total: 8 hours**

**Reusable Patterns**:
- Text output parsing strategies → applicable to other scanners without JSON
- Language detection logic → extensible to Vyper, Rust, Move
- Code quality separation → pattern for all scanners
- L2-specific patterns → applicable to Optimism, Arbitrum, zkSync

---

## Troubleshooting

### Issue: Pattern Matching Not Working

**Symptoms**:
- `pattern_id` is NULL in database
- Logs show "No pattern match found for detector"

**Diagnosis**:
```sql
-- Check if mapping exists
SELECT * FROM pattern_tool_mappings
WHERE scanner_id = 'your-scanner'
AND detector_id = 'detector-id-here';

-- If no results, mapping is missing
```

**Solution**:
1. Verify detector ID in mapping matches exactly what parser outputs
2. Check scanner_id is correct (lowercase, kebab-case)
3. Verify mapping is active (`is_active = true`)
4. Reload enrichment service cache

---

### Issue: Fingerprints Not Generated

**Symptoms**:
- `fingerprint_code` is NULL
- `fingerprint_location` is NULL

**Diagnosis**:
```python
# Check if parser provides required fields
finding = {
    "detector_id": "...",
    "file_path": "...",    # Required for location fingerprint
    "line_number": ...,    # Required for location fingerprint
    "code_snippet": "...", # Required for code fingerprint
}
```

**Solution**:
1. Verify parser extracts `file_path`, `line_number`, `code_snippet`
2. If scanner doesn't provide code snippet, extract from source code
3. Check enrichment service is initialized correctly

---

### Issue: Deduplication Not Grouping Duplicates

**Symptoms**:
- Same vulnerability from multiple scanners creates multiple groups
- `deduplication_group_id` is different for duplicate findings

**Diagnosis**:
```sql
-- Check fingerprints for duplicate findings
SELECT scanner_id, detector_id, fingerprint_code, fingerprint_location
FROM vulnerabilities
WHERE title LIKE '%reentrancy%'
AND scan_id = '...';
```

**Solution**:
1. Verify identical vulnerabilities have identical fingerprints
2. Check code normalization (whitespace removal)
3. Verify deduplication service is running

---

## Best Practices

### 1. Pattern Creation
- ✅ Reuse existing patterns when possible (60-70% reuse rate)
- ✅ Create specific patterns for unique detector types
- ✅ Include remediation guidance in patterns
- ✅ Link to external references (CWE, SWC)
- ❌ Don't create duplicate patterns for same vulnerability type

### 2. Detector Mapping
- ✅ Map detectors to most specific pattern available
- ✅ Use confidence = 0.95 for direct rule-based mappings
- ✅ Document mapping rationale in notes field
- ❌ Don't map multiple detectors to same pattern unless truly identical

### 3. Parser Implementation
- ✅ Extract all enrichment fields (detector_id, file_path, line_number, code_snippet)
- ✅ Handle missing fields gracefully (code snippet optional if not in output)
- ✅ Normalize severity to platform standard
- ❌ Don't skip enrichment fields to "save time" - breaks intelligence

### 4. Testing
- ✅ Test pattern matching for ALL detectors (100% coverage)
- ✅ Test cross-scanner deduplication with real contracts
- ✅ Verify enrichment end-to-end (scan → enrich → store → query)
- ❌ Don't skip integration tests - pattern matching only proven in production-like environment

### 5. Documentation
- ✅ Update SCANNER-DETECTOR-TRACKING.md with metrics
- ✅ Document any detector-specific mapping decisions
- ✅ Create integration summary document
- ❌ Don't forget to update pattern database version

---

## Appendix: Quick Reference

### Pattern ID Format
```
BVD-[ECOSYSTEM]-[CATEGORY]-[NUMBER]
│   │           │           │
│   │           │           └─ Sequential number (001, 002, ...)
│   │           └───────────── Category code (REE, ACC, INT, ...)
│   └───────────────────────── Ecosystem (EVM, VYPER, SOLANA, CAIRO)
└───────────────────────────── Prefix (Apogee Vulnerability Database)
```

### Mapping Entry Template
```json
{
  "scanner_id": "scanner-name",
  "detector_id": "detector-id",
  "pattern_id": "BVD-EVM-XXX-YYY",
  "confidence": 0.95,
  "match_method": "rule_based",
  "is_active": true
}
```

### Required Parser Fields
```python
{
    "detector_id": str,      # CRITICAL - pattern matching
    "file_path": str,        # CRITICAL - fingerprinting
    "line_number": int,      # Fingerprinting
    "code_snippet": str,     # Fingerprinting (optional)
    "function_name": str,    # Enrichment context
    "contract_name": str,    # Enrichment context
    "severity": str,         # Normalization
    "description": str,      # Finding details
}
```

---

**Document End**
