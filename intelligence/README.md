# Intelligence Engine Documentation

**Last Updated**: February 4, 2026
**Version**: 2.2
**Status**: Production

---

## Overview

The Intelligence Engine provides AI/ML-powered vulnerability analysis and pattern matching for smart contract security findings. It enriches raw scanner output with contextual information, severity analysis, and remediation guidance.

---

## Phase 5: CPU-Only ML Features (December 2025)

**Cost**: ~$1/month (CPU-only, no LLM APIs, no GPU)

### ML Capabilities

| Feature | Description | Status |
|---------|-------------|--------|
| **Risk Scoring** | Aggregate risk score (0-100) for contracts/scans | Ready |
| **Confidence Scoring** | Per-finding confidence (0.0-1.0) | Ready |
| **Smart Prioritization** | Fix priority ranking | Ready |
| **Semantic Similarity** | Embedding-based duplicate detection | Ready |
| **False Positive Detection** | Predict FP probability (0.0-1.0) | Needs training data |

### ML Stack
- **Classifiers**: scikit-learn Random Forest, XGBoost
- **Embeddings**: Sentence Transformers (`all-MiniLM-L6-v2`, 80MB, CPU)
- **Inference**: Existing Kubernetes pods (no GPU)
- **Storage**: Models in container, embeddings base64 encoded

### API Endpoints
- `GET /api/v1/ml/contracts/{id}/risk-score` - Contract risk score
- `GET /api/v1/ml/scans/{id}/risk-score` - Scan risk score
- `GET /api/v1/ml/scans/{id}/prioritized` - Prioritized vulnerabilities
- `GET /api/v1/ml/vulnerabilities/{id}/similar` - Find similar vulnerabilities
- `POST /api/v1/ml/predict-false-positive` - Predict FP probability
- `POST /api/v1/ml/label-vulnerability` - Add training label
- `GET /api/v1/ml/model-stats` - Model performance stats

See: [ML Development Standards](/docs/standards/ml-development.md)

---

## Cross-Scan Deduplication (February 2026)

**New Feature:** Automatic cross-scan deduplication with semantic matching.

### How It Works

When a scan completes, deduplication runs in two phases:

| Phase | Scope | Strategy |
|-------|-------|----------|
| Intra-scan | Within same scan | Location fingerprint matching |
| Cross-scan | Across prior scans | 3-level matching (fingerprint + semantic) |

### Matching Levels

| Level | Confidence | Strategy |
|-------|------------|----------|
| EXACT | 99% | `fingerprint_code` match |
| HIGH | 95% | `fingerprint_location` + detector type |
| SEMANTIC | 85%+ | Embedding similarity via Intelligence Engine |

### Historical Tracking

Cross-scan matches update:
- `occurrence_count` - Times vulnerability seen
- `last_seen` - Latest detection timestamp
- `first_seen` - Original detection (preserved)

See: [Deduplication Workflow](/docs/workflows/deduplication-workflow.md)

---

## Deduplication & Metadata Audit Fixes (February 4, 2026)

27 issues were identified and fixed in the comprehensive audit of deduplication, patterns, vulnerability entries, and metadata systems.

### Critical Fixes

| Issue | Location | Fix |
|-------|----------|-----|
| MythrilParser empty results | `parser.py:253-303` | Complete rewrite with JSON parsing, SWC-ID mapping |
| String length truncation | `models.py:784-789` | Changed `String(20)` to `String(50)` for `pattern_id` |

### SWC-ID Mapping

Now implemented with 45+ detector-to-SWC mappings and fallback matching:

```python
# Direct mapping from pattern database
swc_id = pattern.swc_id  # From vulnerability_patterns table

# Fallback for unmapped detectors
DETECTOR_TO_SWC_FALLBACK = {
    "reentrancy": "SWC-107",
    "tx-origin": "SWC-115",
    "suicidal": "SWC-106",
    # ... 40+ more
}
```

### New Database Indexes

5 new indexes added for query optimization:

- `ix_vulnerabilities_classification_confidence`
- `ix_vulnerabilities_classification_method`
- `ix_vulnerabilities_deduplication_strategy`
- `ix_vulnerabilities_similarity_score`
- `ix_vulnerabilities_multi_class_model_version`

### ORM Relationship Improvements

- VulnerabilityModel now has relationships to `DeduplicationGroupModel` and `VulnerabilityPatternModel`
- DeduplicationGroupModel has bidirectional `vulnerabilities` relationship
- `canonical_finding_id` changed from CASCADE to SET NULL to prevent orphaned records

See: [Changelog](/docs/changelogs/DEDUPLICATION-METADATA-AUDIT-FIXES-2026-02-04.md)

---

## Contents

### 📘 Developer Guides

- **[Intelligence Integration Guide](INTELLIGENCE-INTEGRATION-GUIDE.md)** - Integrate with intelligence engine
  - API endpoints for enrichment
  - Request/response formats
  - Error handling
  - Rate limiting

- **[Detector Addition Guide](DETECTOR-ADDITION-GUIDE.md)** - Add new vulnerability detectors
  - Creating vulnerability patterns
  - Pattern code conventions (BVD-SOLIDITY-XXX-NNN)
  - Detector-to-pattern mappings
  - Testing new patterns

### 👥 User Guides

- **[Enriched Findings User Guide](USER-GUIDE-ENRICHED-FINDINGS.md)** - Understanding enriched results
  - How enrichment works
  - Interpreting enriched data
  - Severity scores
  - Remediation recommendations

### 🔍 Fingerprinting System

Advanced vulnerability fingerprinting strategies:

- **[ASM Fingerprinting Strategy](fingerprinting/ASM-FINGERPRINTING-STRATEGY.md)** - Assembly-level fingerprinting
  - Bytecode pattern matching
  - Low-level vulnerability detection
  - EVM opcode analysis

- **[ENC Fingerprinting Strategy](fingerprinting/ENC-FINGERPRINTING-STRATEGY.md)** - Encoding fingerprinting
  - Data encoding patterns
  - ABI encoding vulnerabilities
  - Calldata analysis

- **[EVT Fingerprinting Strategy](fingerprinting/EVT-FINGERPRINTING-STRATEGY.md)** - Event fingerprinting
  - Event emission patterns
  - Missing event detection
  - Event parameter analysis

- **[L2 Fingerprinting Strategy](fingerprinting/L2-FINGERPRINTING-STRATEGY.md)** - Layer 2 fingerprinting
  - L2-specific vulnerabilities
  - Cross-chain patterns
  - Rollup security issues

- **[Semantic Fingerprinting Roadmap](fingerprinting/SEMANTIC-FINGERPRINTING-ROADMAP.md)** - Future enhancements
  - Semantic analysis plans
  - AST-based fingerprinting
  - ML-powered pattern detection

---

## Intelligence Platform Statistics

### Current Coverage (v3.13)

| Metric | Count | Notes |
|--------|-------|-------|
| **Total Patterns** | 397 | BVD vulnerability patterns |
| **Pattern Mappings** | 214+ | Across 12 scanners |
| **Seed File Version** | 3.13 | `seeds/vulnerability_patterns.json` |

### Integrated Scanners (12)

| Scanner | Mappings | Status |
|---------|----------|--------|
| Slither | 93+ | Complete |
| Mythril | 25+ | Complete |
| Securify2 | 15+ | Complete |
| Oyente | 10+ | Complete |
| SmartCheck | 12+ | Complete |
| Solhint | 16+ | Complete |
| SolidityDefend | 20+ | Complete |
| Wake | 10+ | Complete |
| Echidna | 5+ | Complete |
| Medusa | 5+ | Complete |
| Halmos | 3+ | Complete |

---

## Vulnerability Pattern System

### Pattern Code Convention

**Format**: `BVD-<LANGUAGE>-<CATEGORY>-<NUMBER>`

- **BVD**: Apogee Vulnerability Database
- **LANGUAGE**: SOLIDITY, VYPER, SOLANA (Rust), CAIRO (Starknet)
- **CATEGORY**: 3-letter code (REE, ACC, INT, etc.)
- **NUMBER**: 3-digit sequence (001, 002, etc.)

**Examples**:
- `BVD-SOLIDITY-REE-001` - Reentrancy vulnerability
- `BVD-SOLIDITY-ACC-001` - Access control issue
- `BVD-SOLIDITY-INT-001` - Integer overflow

### Pattern Categories

| Code | Category | Pattern Count | Description |
|------|----------|---------------|-------------|
| **REE** | Reentrancy | 6 | Reentrancy vulnerabilities |
| **ACC** | Access Control | 6 | Authorization issues |
| **ARI** | Arithmetic | 4 | Integer overflow/underflow |
| **UNC** | Unchecked Calls | 3 | Missing return checks |
| **DEL** | Delegatecall | 2 | Dangerous delegatecalls |
| **TOK** | Token Issues | 6 | ERC20/721 vulnerabilities |
| **ORA** | Oracle Security | 3 | Price oracle manipulation |
| **DEP** | Deprecated | 3 | Deprecated Solidity features |
| **COM** | Compiler | 1 | Compiler-related issues |
| **FAL** | Fallback | 1 | Fallback function issues |
| **ASM** | Assembly | 1 | Inline assembly risks |
| **VIS** | Visibility | 3 | State visibility issues |
| ... | ... | ... | ... |

**Total**: 29 categories, 69 patterns

---

## API Integration

### Enrich Vulnerability Finding

```bash
POST /api/v1/intelligence/enrich

{
  "scanner": "slither",
  "detector_id": "reentrancy-eth",
  "finding": {
    "title": "Reentrancy in withdraw()",
    "severity": "high",
    "location": "MyContract.sol#L42"
  }
}
```

**Response**:
```json
{
  "enriched": true,
  "pattern_code": "BVD-SOLIDITY-REE-001",
  "pattern_name": "Reentrancy Vulnerability",
  "severity": "critical",
  "confidence": "high",
  "description": "Enhanced description with context...",
  "remediation": "Use ReentrancyGuard or checks-effects-interactions...",
  "references": [
    "https://consensys.github.io/smart-contract-best-practices/attacks/reentrancy/"
  ]
}
```

---

## Pattern Management

### Adding a New Pattern

**1. Define Pattern in `vulnerability_patterns.json`**:
```json
{
  "pattern_code": "BVD-SOLIDITY-NEW-001",
  "name": "New Vulnerability Type",
  "category": "NEW",
  "chain": "SOLIDITY",
  "severity": "medium",
  "description": "Detailed description...",
  "remediation": "How to fix...",
  "references": [
    "https://example.com/reference"
  ]
}
```

**2. Add Detector Mapping**:
```json
{
  "scanner_id": "slither",
  "detector_id": "my-detector",
  "pattern_code": "BVD-SOLIDITY-NEW-001",
  "confidence_adjustment": 0
}
```

**3. Test Pattern**:
```bash
pytest tests/test_intelligence_integration.py::test_new_pattern
```

See: [Detector Addition Guide](DETECTOR-ADDITION-GUIDE.md)

---

## Fingerprinting Pipeline

### How It Works

1. **Scanner Output**: Raw vulnerability finding
2. **Pattern Matching**: Map detector to pattern code
3. **Enrichment**: Add context, severity, remediation
4. **Fingerprinting**: Generate unique fingerprint hash
5. **Deduplication**: Merge duplicate findings
6. **Storage**: Store enriched finding in database

### Fingerprint Generation

**Components**:
- Pattern code (BVD-SOLIDITY-XXX-NNN)
- Contract address
- Location (file + line number)
- Function name

**Hash Algorithm**: SHA-256

```python
fingerprint = hashlib.sha256(
    f"{pattern_code}:{contract_addr}:{file}:{line}:{function}".encode()
).hexdigest()
```

---

## Intelligence Integration Progress

### Phase 2 Roadmap

| Story | Scanner | Detectors | Status | Completion |
|-------|---------|-----------|--------|------------|
| 2.1 | Semgrep | 43/47 (91.5%) | ✅ Complete | Oct 28, 2025 |
| 2.2 | Solhint | 16/20 (80%) | ✅ Complete | Oct 28, 2025 |
| 2.3 | Aderyn | 88 detectors | ⏳ In Progress | ETA: Nov 2025 |
| 2.4 | 4naly3er | 111 detectors | 📋 Planned | ETA: Dec 2025 |
| 2.5 | Slither | 93 detectors | 📋 Planned | ETA: Jan 2026 |

**Total Progress**: 78/509 detectors (15.3%)

---

## Performance Metrics

### Enrichment Performance
- **Average enrichment time**: < 50ms
- **Pattern lookup**: O(1) hash table lookup
- **Cache hit rate**: ~80% (Redis cached patterns)
- **Throughput**: 1000+ enrichments/second

### Accuracy Metrics
- **Pattern match accuracy**: 95%+
- **Severity classification**: 92% agreement with manual review
- **False positive rate**: < 5%

---

## Related Documentation

### Architecture
- [Intelligence Layer](../architecture/intelligence-layer.md) - System architecture
- [Fingerprinting Engine](../architecture/fingerprinting-engine.md) - Fingerprinting design

### Scanner Integration
- [Scanner Intelligence Integration](../scanners/SCANNER-INTELLIGENCE-INTEGRATION.md)
- [Scanner Detector Tracking](../scanners/SCANNER-DETECTOR-TRACKING.md)

### Development
- [Testing Guide](../development/testing-guide.md)
- [CI/CD Automation](../development/ci-cd-automation.md)

---

## Database Schema

### Vulnerability Patterns Table
```sql
CREATE TABLE vulnerability_patterns (
    pattern_code VARCHAR(50) PRIMARY KEY,  -- Widened from 20 to 50 (Jan 2026)
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    chain VARCHAR(10) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    description TEXT,
    remediation TEXT,
    references JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);
```

### Pattern Mappings Table
```sql
CREATE TABLE pattern_tool_mappings (
    id UUID PRIMARY KEY,
    scanner_id VARCHAR(100) NOT NULL,
    detector_id VARCHAR(100) NOT NULL,
    pattern_id VARCHAR(50) REFERENCES vulnerability_patterns(pattern_code),  -- Widened from 20 to 50
    confidence_adjustment INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(scanner_id, detector_id)
);
```

### Vulnerabilities Pattern Columns
```sql
-- Added to vulnerabilities table
pattern_id VARCHAR(50),      -- BVD pattern code (e.g., BVD-SOLIDITY-REE-001)
pattern_code VARCHAR(50),    -- Denormalized copy for quick access
```

### Deduplication Groups Pattern Column
```sql
-- Added to deduplication_groups table
pattern_code VARCHAR(50),    -- Derived from canonical finding's pattern_code
```

**Note**: Column widths increased from VARCHAR(20) to VARCHAR(50) in January 2026 to accommodate
longer BVD codes like `BVD-SOLIDITY-DEFI-LIQUIDITY-001` (34 characters). See Migration 033.

---

## Contributing

### Adding New Patterns

1. Follow BVD naming convention
2. Include comprehensive description
3. Provide remediation steps
4. Add authoritative references
5. Test with real vulnerabilities

### Quality Standards

- **Accuracy**: Patterns must have <5% false positive rate
- **Coverage**: Each pattern should map to 1+ detectors
- **Documentation**: All patterns must be documented
- **Testing**: Unit tests required for new patterns

---

**Maintained by**: Apogee Intelligence Team
**Last Pattern Update**: October 28, 2025 (v1.3)
**Next Milestone**: Phase 2.3 - Aderyn Integration (88 detectors)
