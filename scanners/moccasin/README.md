# Moccasin Scanner Integration Documentation

**Version:** 0.2.0
**Last Updated:** 2025-12-15
**Scanner Version:** Moccasin (latest)
**Docker Image:** scanner-moccasin:0.2.0

## Overview

Moccasin is Cyfrin's Titanoboa-based testing and fuzzing framework for Vyper smart contracts. It provides property-based fuzzing capabilities to find edge cases and potential vulnerabilities in Vyper contracts.

### Key Features

- **Property-based Fuzzing**: Generates test inputs to find edge cases
- **Titanoboa Integration**: Uses Titanoboa for fast EVM execution
- **Vyper Native**: Built specifically for Vyper contracts
- **Python-based**: Easy integration with Python tooling

### Detection Capabilities

- Property violations
- Invariant failures
- Edge case behaviors
- State inconsistencies
- Assertion failures

---

## Architecture

### Execution Model

Moccasin runs within the orchestration service using subprocess execution:

```
Orchestration Service
  └── MoccasinExecutor
        ├── Writes .vy file to temp directory
        ├── Creates moccasin.toml config
        ├── Runs: mox test --json
        └── Parses test output
```

### Dependencies

| Component | Version | Purpose |
|-----------|---------|---------|
| Moccasin | latest | Fuzzing framework |
| Vyper | 0.4.0 | Vyper compiler |
| Titanoboa | bundled | EVM execution |
| Python | 3.11 | Runtime |

---

## Configuration

### Orchestration Service

The Moccasin scanner is registered in the scanner registry:

**Location:** `blocksecops-orchestration/src/blocksecops_orchestration/scanners/vyper_scanners.py`

```python
class MoccasinExecutor(ScannerExecutor):
    def __init__(self, timeout: int = 300):
        super().__init__(scanner_id="moccasin", timeout=timeout)

    def is_available(self) -> bool:
        return shutil.which("mox") is not None
```

### Generated Config

Moccasin requires a `moccasin.toml` configuration file:

```toml
[project]
name = "ContractName"
src = "."

[fuzz]
runs = 100
max_examples = 50

[network.anvil]
url = "http://127.0.0.1:8545"
chain_id = 31337
```

---

## Usage

### API Request

```bash
curl -X POST "http://127.0.0.1:3000/api/v1/scans" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "contract_id": "<uuid>",
    "scanner_ids": ["moccasin"]
  }'
```

### Supported File Types

- `.vy` - Vyper source files

### Scanner Type

**Type:** Fuzzer

**Note:** As a fuzzer, Moccasin finds bugs through dynamic execution and test generation rather than static code analysis. Results may include:
- Test failures
- Property violations
- Invariant failures

---

## Troubleshooting

### Scanner Shows Unavailable

**Symptom:** Moccasin scanner shows `is_available: false`

**Cause:** `mox` binary not installed in orchestration pod

**Solution:** Rebuild orchestration image with Moccasin:
```bash
# Dockerfile addition
RUN pip install moccasin
```

### Fuzzing Timeouts

**Symptom:** Scanner times out during fuzzing

**Cause:** Complex contracts or high fuzz run count

**Solution:** Reduce fuzz runs in scanner configuration or increase timeout

---

## Limitations

1. **Requires Test Harness**: Moccasin works best with contracts that have defined invariants and properties to test
2. **Vyper Only**: Does not support Solidity contracts
3. **Time Intensive**: Fuzzing takes longer than static analysis

---

## References

- [Moccasin GitHub](https://github.com/Cyfrin/moccasin)
- [Cyfrin Documentation](https://docs.cyfrin.io/)
- [Titanoboa](https://github.com/vyperlang/titanoboa)

---

**Document Maintainer:** Apogee Team
**Last Review:** 2025-12-15
