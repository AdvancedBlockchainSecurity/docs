# Vyper Scanner Integration Documentation

**Version:** 0.4.0
**Last Updated:** 2025-12-29
**Scanner Version:** Vyper 0.3.10/0.4.3, Slither 0.11.3, vvm 0.3.2
**Docker Image:** scanner-vyper:0.4.0

## Overview

The Vyper scanner provides static analysis for Vyper smart contracts using Slither with Vyper compilation support. Vyper is a Pythonic smart contract language for the EVM that emphasizes security and simplicity.

### Key Features

- **Static Analysis**: Detects vulnerabilities in Vyper contracts using Slither
- **Multi-Version Support**: Uses vvm (Vyper Version Manager) for automatic version detection and installation
- **Latest Stable Versions**: Automatically uses latest stable Vyper for each major.minor line
- **Contract Preprocessing**: Handles module-level docstrings that Slither cannot parse
- **Kubernetes Jobs**: Runs as isolated K8s Job with result callback

### Detection Capabilities

- Reentrancy vulnerabilities (HIGH)
- Unchecked send/call return values (LOW)
- Access control vulnerabilities
- State variable issues
- Function visibility problems
- Arithmetic issues (limited compared to Solidity due to Vyper's design)
- Code quality issues

---

## Architecture

### Execution Model

The Vyper scanner runs as a Kubernetes Job orchestrated by the tool-integration service:

```
Tool-Integration Service
  └── KubernetesJobManager
        ├── Creates K8s Job with scanner-vyper image
        ├── Mounts contract via ConfigMap
        └── Job posts results to callback URL

scanner-vyper Container
  └── run-vyper.sh
        ├── Detects Vyper version from pragma
        ├── Installs correct version via vvm
        ├── Preprocesses contract (removes problematic docstrings)
        ├── Runs: slither <file.vy> --json <output>
        └── POSTs JSON results to callback URL
```

### Dependencies

| Component | Version | Purpose |
|-----------|---------|---------|
| vvm | 0.3.2 | Vyper Version Manager for multi-version support |
| Vyper | 0.3.10, 0.4.3 | Pre-installed Vyper compiler versions |
| Slither | 0.11.3 | Static analysis engine with Vyper support |
| Python | 3.11 | Runtime |

### Version Selection Logic

The scanner automatically selects the latest stable version for each major.minor line:

| Contract Pragma | Vyper Version Used | Reason |
|-----------------|-------------------|--------|
| `^0.3.0`, `~=0.3.0`, `>=0.3.0` | 0.3.10 | Latest stable 0.3.x |
| `^0.4.0`, `~=0.4.0`, `>=0.4.0` | 0.4.3 | Latest stable 0.4.x |

This follows the [dependency management standards](/Users/pwner/Git/ABS/docs/standards/dependency-management.md) requiring latest stable versions.

---

## Configuration

### Docker Image

**Location:** `blocksecops-tool-integration/scanner-images/vyper/`

**Files:**
- `Dockerfile` - Multi-stage build with vvm and pre-installed Vyper versions
- `run-vyper.sh` - Entrypoint script with version detection, preprocessing, and callback

**Build Command:**
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/vyper
eval $(minikube docker-env)
docker build -t scanner-vyper:0.4.0 .
docker tag scanner-vyper:0.4.0 scanner-vyper:latest
```

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `CALLBACK_URL` | Yes | URL to POST scan results |
| `SCAN_ID` | Yes | UUID of the scan |
| `CONTRACTS_DIR` | No | Directory containing contracts (default: `/contracts`) |

---

## Usage

### API Request

```bash
curl -X POST "http://127.0.0.1:8000/api/v1/scans" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "contract_id": "<uuid>",
    "scanner_ids": ["vyper"]
  }'
```

### Supported File Types

- `.vy` - Vyper source files

### Example Vyper Contract

```python
# @version ^0.3.0

owner: public(address)
balances: public(HashMap[address, uint256])

@external
def __init__():
    self.owner = msg.sender

@external
@payable
def deposit():
    self.balances[msg.sender] += msg.value

@external
def withdraw(amount: uint256):
    assert self.balances[msg.sender] >= amount, "Insufficient balance"
    self.balances[msg.sender] -= amount
    send(msg.sender, amount)
```

---

## Contract Preprocessing

The scanner includes preprocessing to handle Vyper contracts with module-level docstrings that Slither cannot parse.

### Problem

Slither's Vyper parser fails on contracts with module-level triple-quoted strings (docstrings) that appear after function definitions:

```python
# This causes Slither to fail:
"""
Example code block in a module-level docstring
"""
```

Error: `Unsupported syntax for module namespace: Expr`

### Solution

The `run-vyper.sh` script includes a Python preprocessor that:
1. Preserves the file-level docstring at the top
2. Preserves function docstrings (those immediately after `def`)
3. Converts other module-level docstrings to comments

This is transparent to users - contracts are preprocessed before analysis and vulnerabilities are reported against original line numbers where possible.

---

## Troubleshooting

### Scanner Shows Unavailable

**Symptom:** Vyper scanner shows `is_available: false`

**Cause:** vvm or Slither not installed correctly

**Solution:** Rebuild the scanner image:
```bash
cd /Users/pwner/Git/ABS/blocksecops-tool-integration/scanner-images/vyper
eval $(minikube docker-env)
docker build --no-cache -t scanner-vyper:0.4.0 .
```

### Compilation Errors

**Symptom:** Scanner fails with "Vyper compilation failed"

**Causes:**
- Contract uses Vyper syntax not compatible with installed version
- Module-level docstrings that couldn't be preprocessed

**Debug:**
```bash
# Check job logs
kubectl logs job/scan-vyper-<scan-id> -n tool-integration-local

# Look for version detection and preprocessing output
```

### No Vulnerabilities Found

**Symptom:** Scan completes but shows 0 vulnerabilities

**Causes:**
1. Contract has no detectable vulnerabilities
2. Preprocessing failed silently
3. Slither parser issue with specific syntax

**Debug:**
```bash
# Check full scan logs
kubectl logs job/scan-vyper-<scan-id> -n tool-integration-local

# Look for "vulnerabilities_parsed" in callback response
```

### Version Mismatch Errors

**Symptom:** `Version specification "X" is not compatible with compiler version "Y"`

**Cause:** Contract requires a specific Vyper version not installed

**Solution:** The scanner now uses vvm for dynamic version installation. Check logs for:
```
Installing Vyper X.Y.Z using vvm...
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.4.0 | 2025-12-29 | Updated to latest stable: vvm 0.3.2, Vyper 0.3.10/0.4.3 |
| 0.3.3 | 2025-12-29 | Added automatic latest stable version selection |
| 0.3.2 | 2025-12-29 | Fixed preprocessing for module-level docstrings |
| 0.3.0 | 2025-12-29 | Added vvm for multi-version Vyper support |
| 0.2.0 | 2025-12-15 | Initial Kubernetes Jobs implementation |

---

## References

- [Vyper Documentation](https://docs.vyperlang.org/)
- [Vyper GitHub](https://github.com/vyperlang/vyper)
- [vvm (Vyper Version Manager)](https://github.com/vyperlang/vvm)
- [Slither Vyper Support](https://github.com/crytic/slither)
- [Dependency Management Standards](/Users/pwner/Git/ABS/docs/standards/dependency-management.md)

---

**Document Maintainer:** Apogee Team
**Last Review:** 2025-12-29
