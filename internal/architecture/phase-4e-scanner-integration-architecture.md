# Phase 4E Scanner Integration Architecture

**Date**: October 20-21, 2025
**Version**: v0.6.0
**Status**: Core Implementation Complete (Foundry Fuzz only - Manticore removed)
**Scanners Added**: Foundry Fuzz

---

## Overview

Phase 4E introduces one advanced security scanner to the BlockSecOps orchestration platform:
- **Foundry Fuzz**: Industry-standard coverage-guided property-based fuzzer

Note: Manticore was initially included but has been removed as it is no longer actively developed by Trail of Bits.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Scanner Orchestration Layer               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Scanner Registry                         │
│  • slither         • aderyn        • solhint                │
│  • echidna         • semgrep       • halmos                 │
│  • medusa          • mythril       • wake                   │
│  • 4naly3er        • foundry-fuzz* (* Phase 4E addition)    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────┐
│  FoundryFuzzExecutor │
│  • Coverage-guided   │
│  • Property testing  │
│  • NDJSON output     │
│  • 300s timeout      │
└──────────────────────┘
            │
            ▼
┌──────────────────────┐
│  FoundryFuzzParser   │
│  • FUZZING findings  │
│  • Test failures     │
│  • Counterexamples   │
└──────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────┐
│                  Result Storage Manager                      │
│               (Type-based Database Routing)                  │
└─────────────────────────────────────────────────────────────┘
            │
            ▼
┌──────────────────┐
│ fuzzing_results  │
│ (fuzz tests)     │
└──────────────────┘
```

---

## Scanner Specifications

### 1. Foundry Fuzz

#### Technical Details
- **Scanner ID**: `foundry-fuzz`
- **Provider**: Paradigm (Foundry v1.0+)
- **Installation**: Foundry suite (forge binary)
- **Language**: Solidity
- **Analysis Type**: Coverage-guided property-based fuzzing

#### Finding Type
- **Primary**: `FUZZING`
- **Database Table**: `fuzzing_results`

#### Execution Flow
```
1. Create foundry.toml configuration
2. Write contract to src/ directory (Foundry convention)
3. Execute: forge test --json --fuzz-runs 1000
4. Parse NDJSON output (newline-delimited JSON)
5. Extract test failures with counterexamples
6. Create FUZZING findings
```

#### Output Format
```json
{
  "test_results": {
    "test_invariant_balance": {
      "success": false,
      "reason": "Invariant violation: balance mismatch",
      "runs": 256,
      "counterexample": {
        "calldata": "0x...",
        "args": ["0x1234...", "1000"]
      },
      "gas_used": 45000
    }
  },
  "exit_code": 1
}
```

#### Parser Logic
- Iterate through test_results
- Skip entries starting with "_" (summaries)
- For each failed test (success=false):
  - Create FUZZING finding
  - Include counterexample for reproduction
  - Mark as HIGH severity (property violations)

#### Key Features
- **Intelligent Fuzzing**: Coverage-guided, not random
- **Fast Execution**: 40% performance improvement in v1.0
- **Integration**: Works with existing Foundry test suites
- **Counterexamples**: Provides concrete inputs that trigger failures

---

## Database Schema

### fuzzing_results Table (Foundry Fuzz)
```sql
CREATE TABLE fuzzing_results (
    id UUID PRIMARY KEY,
    scan_id UUID NOT NULL REFERENCES scans(id),
    contract_id UUID NOT NULL REFERENCES contracts(id),
    title VARCHAR(255) NOT NULL,           -- "Fuzz Test Failure: test_name"
    description TEXT,                      -- Failure reason
    test_name VARCHAR(255) NOT NULL,       -- Test function name
    runs INTEGER,                          -- Number of fuzz runs
    counterexample TEXT,                   -- JSON string of inputs
    gas_used INTEGER,                      -- Gas consumption (optional)
    status VARCHAR(50) NOT NULL,           -- "FAILED"
    severity VARCHAR(50) NOT NULL,         -- "high"
    created_at TIMESTAMP DEFAULT NOW()
);
```


---

## Integration Points

### Scanner Registry
```python
# File: src/blocksecops_orchestration/scanners/registry.py

from blocksecops_orchestration.scanners.solidity_scanners import (
    FoundryFuzzExecutor,
)

_registry.register("foundry-fuzz", FoundryFuzzExecutor())
```

### Parser Registry
```python
# File: src/blocksecops_orchestration/parsers/registry.py

from blocksecops_orchestration.parsers.solidity_parsers import (
    FoundryFuzzParser,
)

_registry.register("foundry-fuzz", FoundryFuzzParser())
```

### Orchestrator Usage
```python
# Existing orchestrator automatically picks up new scanners
orchestrator = ScannerOrchestrator()
result = orchestrator.execute_scanners(
    scan_id=scan_id,
    contract_id=contract_id,
    contract_name="MyContract",
    source_code=source_code,
    scanner_ids=["slither", "foundry-fuzz"],  # Include Phase 4E
    timeout=600,
)

# Parser and storage handled automatically
for scanner_id, scanner_result in result.scanner_results.items():
    parser = ParserRegistry.get_parser(scanner_id)
    findings = parser.parse(scanner_result, scan_id, contract_id, source_code)
    storage_manager.store_findings(findings)  # Type-based routing
```

---

## Performance Characteristics

### Foundry Fuzz
- **Execution Time**: 30-300 seconds (depends on test complexity)
- **Timeout**: 300s (5 minutes)
- **Memory**: ~200-500 MB
- **CPU**: Moderate (single-threaded)
- **Scalability**: Excellent (fast iterations)

### Comparison with Existing Scanners

| Scanner | Type | Avg Time | Depth | Coverage |
|---------|------|----------|-------|----------|
| Slither | Static | 10-30s | Medium | High |
| Echidna | Fuzzing | 60-300s | High | Medium |
| Halmos | Formal | 120-300s | Very High | Low |
| **Foundry Fuzz** | Fuzzing | 30-180s | High | High |

**Foundry Fuzz Advantages**:
- Faster than Echidna (40% improvement)
- Better coverage than traditional fuzzing
- Native Foundry integration

---

## Docker Installation

### Foundry
```dockerfile
# Install Foundry suite (forge, cast, anvil)
RUN curl -L https://foundry.paradigm.xyz | bash && \
    /root/.foundry/bin/foundryup && \
    ln -s /root/.foundry/bin/forge /usr/local/bin/forge && \
    ln -s /root/.foundry/bin/cast /usr/local/bin/cast && \
    ln -s /root/.foundry/bin/anvil /usr/local/bin/anvil && \
    forge --version
```

**Size Impact**: +80 MB
**Dependencies**: Rust toolchain (already installed)

**Total Image Size**: 5.47 GB → 5.55 GB (+80 MB)

---

## Testing Strategy

### Unit Tests
```python
def test_foundry_fuzz_executor_available():
    executor = FoundryFuzzExecutor()
    assert executor.is_available() == True

def test_foundry_fuzz_parser():
    parser = FoundryFuzzParser()
    raw_output = {
        "test_results": {
            "test_fail": {
                "success": False,
                "reason": "Invariant violated"
            }
        }
    }
    findings = parser.parse(raw_output, scan_id, contract_id, "")
    assert len(findings) == 1
    assert findings[0].finding_type == FindingType.FUZZING
```

### Integration Tests
```python
def test_all_11_scanners_available():
    registry = get_scanner_registry()
    scanner_ids = registry.get_all_scanner_ids()

    expected = {
        'slither', 'aderyn', 'solhint', 'echidna', 'semgrep',
        'halmos', 'medusa', 'mythril', 'wake', '4naly3er',
        'foundry-fuzz'
    }

    assert set(scanner_ids) == expected
    assert len(scanner_ids) == 11

def test_foundry_fuzz_execution(vulnerable_contract):
    executor = FoundryFuzzExecutor()
    parser = FoundryFuzzParser()

    context = create_test_context(vulnerable_contract)
    result = executor.execute(context)

    assert result.success == True

    findings = parser.parse(result.raw_output, scan_id, contract_id, "")
    # May or may not have findings depending on contract
    assert isinstance(findings, list)
```

---

## Error Handling

### Foundry Fuzz
**Common Errors**:
- No tests found → Return empty findings (not an error)
- Compilation failure → Log error, return failure status
- Timeout → Return timeout error after 300s

**Handling**:
```python
try:
    result = subprocess.run(["forge", "test", "--json"], timeout=300)
    if result.returncode == 1:  # Tests failed (expected)
        # Parse failures as findings
    elif result.returncode > 1:  # Actual error
        return ScannerResult(success=False, error_message="...")
except subprocess.TimeoutExpired:
    return ScannerResult(success=False, error_message="Timeout")
```

---

## Migration Notes

### From Phase 4D (v0.5.1) to Phase 4E (v0.6.0)

**Breaking Changes**: None

**New Features**:
- 1 new scanner (foundry-fuzz)
- Scanner count: 10 → 11
- Note: Manticore was removed due to lack of active development

**Database Changes**: None (uses existing tables)

**API Changes**: None (backward compatible)

**Deployment**:
1. Build new Docker image (v0.6.0)
2. Load into Kubernetes
3. Apply updated manifests
4. Verify 12/12 scanners available

**Rollback**:
- Revert to v0.5.1 image
- Apply v0.5.1 manifests
- 10 scanners operational

---

## Future Enhancements

### Phase 4F (Planned)
- Certora Prover (formal verification with CVL)
- Move platform scanners (sec3-xray, move-prover)
- Cairo platform scanners (caracal, starknet-foundry)
- Target: 13-17 scanners

### Performance Optimization
- Parallel scanner execution (currently sequential)
- Cached compilation artifacts
- Incremental analysis for code changes

### Advanced Features
- Custom Foundry fuzz configurations per contract
- Result deduplication across scanners

---

## References

- [Foundry Documentation](https://book.getfoundry.sh/)
- [Foundry v1.0 Release Notes](https://www.paradigm.xyz/2025/02/announcing-foundry-v1-0)
- [Phase 4E Implementation Plan](/TaskDocs-BlockSecOps/blocksecops/implementation-summaries/PHASE-4E-IMPLEMENTATION-PLAN.md)
- [Manticore Removal Documentation](/TaskDocs-BlockSecOps/blocksecops/MANTICORE-REMOVAL-COMPLETE.md)

---

**Document Version**: 1.0
**Last Updated**: October 20, 2025
**Status**: Complete
**Next Review**: Phase 4F Planning
