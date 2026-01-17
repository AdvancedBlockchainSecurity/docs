# Intelligence Engine Documentation

**Last Updated**: January 16, 2026
**Version**: 2.1
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

## Contents

### 📘 Developer Guides

- **[Intelligence Integration Guide](INTELLIGENCE-INTEGRATION-GUIDE.md)** - Integrate with intelligence engine
  - API endpoints for enrichment
  - Request/response formats
  - Error handling
  - Rate limiting

- **[Detector Addition Guide](DETECTOR-ADDITION-GUIDE.md)** - Add new vulnerability detectors
  - Creating vulnerability patterns
  - Pattern code conventions (BVD-EVM-XXX-NNN)
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

### Current Coverage (v1.3)

| Metric | Count | Coverage |
|--------|-------|----------|
| **Total Patterns** | 69 | 15.3% of 509 detectors |
| **Pattern Mappings** | 80 | Multiple detectors per pattern |
| **Solidity Coverage** | 78/371 | 21.0% |
| **Vyper Coverage** | 0/138 | 0% (planned Phase 4) |

### Integrated Scanners (3/27)

✅ **Phase 2.1**: Semgrep (43/47 detectors, 91.5%)
✅ **Phase 2.2**: Solhint (16/20 detectors, 80%)
⏳ **Phase 2.3**: Aderyn (88 detectors, in progress)

**Remaining**: 4naly3er, Slither, Mythril, and 21 others

---

## Vulnerability Pattern System

### Pattern Code Convention

**Format**: `BVD-<CHAIN>-<CATEGORY>-<NUMBER>`

- **BVD**: BlockSecOps Vulnerability Database
- **CHAIN**: EVM, SOL (Solana), STRK (Starknet)
- **CATEGORY**: 3-letter code (REE, ACC, ARI, etc.)
- **NUMBER**: 3-digit sequence (001, 002, etc.)

**Examples**:
- `BVD-EVM-REE-001` - Reentrancy vulnerability
- `BVD-EVM-ACC-001` - Access control issue
- `BVD-EVM-ARI-001` - Arithmetic overflow

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
  "pattern_code": "BVD-EVM-REE-001",
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
  "pattern_code": "BVD-EVM-NEW-001",
  "name": "New Vulnerability Type",
  "category": "NEW",
  "chain": "EVM",
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
  "pattern_code": "BVD-EVM-NEW-001",
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
- Pattern code (BVD-EVM-XXX-NNN)
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

**Maintained by**: BlockSecOps Intelligence Team
**Last Pattern Update**: October 28, 2025 (v1.3)
**Next Milestone**: Phase 2.3 - Aderyn Integration (88 detectors)
