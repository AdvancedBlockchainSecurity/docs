# Vyper & Rust SAST Scanner Tests (Phase 3.5)

**Priority**: P2 - Medium
**Last Tested**: December 15, 2025
**Feature**: Vyper Scanner Integration, Solana/Rust Scanner Integration
**Docker Images**: Built and verified (December 8, 2025)
**Scanner Status**: Vyper & Moccasin available (12/15/2025), Solana scanners pending

---

## 0. Quick Start - Docker Image Testing

Run these tests immediately after platform build to verify scanner images work:

### 0.1 Verify Scanner Images Exist
```bash
# In minikube Docker context
eval $(minikube docker-env)
docker images | grep -E "^scanner-(vyper|moccasin|sol-azy|sec3|trident|cargo-fuzz)"
```
- [ ] scanner-vyper:latest exists (221MB)
- [ ] scanner-moccasin:latest exists (773MB)
- [ ] scanner-sol-azy:latest exists (146MB)
- [ ] scanner-sec3-xray:latest exists (238MB)
- [ ] scanner-trident:latest exists (2.09GB)
- [ ] scanner-cargo-fuzz-solana:latest exists (1.69GB)

### 0.2 Test Scanner Help Commands
```bash
# Vyper (uses slither entrypoint)
docker run --rm scanner-vyper:latest --help

# Moccasin
docker run --rm scanner-moccasin:latest

# Sol-azy
docker run --rm scanner-sol-azy:latest --help

# Sec3 X-Ray
docker run --rm scanner-sec3-xray:latest "x-ray-scan --help"

# Trident
docker run --rm scanner-trident:latest trident --help

# Cargo Fuzz
docker run --rm scanner-cargo-fuzz-solana:latest cargo fuzz --help
```
- [ ] scanner-vyper shows slither help
- [ ] scanner-moccasin shows fuzzing banner
- [ ] scanner-sol-azy shows sol-azy SAST help
- [ ] scanner-sec3-xray shows X-Ray help
- [ ] scanner-trident shows trident fuzzer help
- [ ] scanner-cargo-fuzz-solana shows cargo fuzz help

### 0.3 Verify Tool Versions
```bash
# Vyper compiler version
docker run --rm --entrypoint vyper scanner-vyper:latest --version
# Expected: 0.4.3+commit.bff19ea2

# Slither version (in vyper scanner)
docker run --rm scanner-vyper:latest --version
# Expected: 0.11.3

# Moccasin vyper version
docker run --rm --entrypoint vyper scanner-moccasin:latest --version
# Expected: 0.4.3+commit.bff19ea2
```
- [ ] Vyper version is 0.4.3
- [ ] Slither version is 0.11.3
- [ ] Moccasin has vyper 0.4.3

### 0.4 Test Basic Vyper Analysis
```bash
# Create test Vyper contract
cat > /tmp/test.vy << 'EOF'
# @version ^0.4.0
owner: public(address)

@deploy
def __init__():
    self.owner = msg.sender

@external
def withdraw():
    send(msg.sender, self.balance)
EOF

# Run slither analysis
docker run --rm -v /tmp:/contracts scanner-vyper:latest /contracts/test.vy --json -
```
- [ ] Scanner executes without error
- [ ] JSON output returned
- [ ] Detects potential issues (unchecked send)

### 0.5 Test ConfigMap Scanner Metadata
```bash
kubectl get configmap scanner-versions -n tool-integration-local -o yaml | grep -A5 "vyper\|moccasin\|sol-azy\|sec3\|trident"
```
- [ ] vyper version shows 0.4.3
- [ ] moccasin entry exists
- [ ] sol-azy entry exists
- [ ] sec3-xray entry exists
- [ ] trident version shows 0.12.0

---

## 1. Vyper Scanner Infrastructure

### 1.1 Slither-Vyper Scanner
- [ ] Scanner registered in scanner registry
- [ ] Scanner metadata correct (id, name, version)
- [ ] Supported languages includes "vyper"
- [ ] Scanner executes without errors on valid Vyper contract
- [ ] Detects reentrancy vulnerabilities
- [ ] Detects access control issues
- [ ] Detects integer overflow/underflow
- [ ] Output format matches ScannerResult schema
- [ ] Vulnerability severity levels correct (critical/high/medium/low)
- [ ] Line numbers in findings are accurate

### 1.2 Moccasin Scanner
- [ ] Scanner registered in scanner registry
- [ ] Scanner metadata correct (id, name, version)
- [ ] Supported languages includes "vyper"
- [ ] Scanner executes without errors
- [ ] Creates proper temporary project structure
- [ ] Generates moccasin.toml configuration correctly
- [ ] Parses moccasin output correctly
- [ ] Handles compilation errors gracefully
- [ ] Returns structured findings

### 1.3 Vyper File Handling
- [ ] .vy files recognized as Vyper contracts
- [ ] Vyper version detection from pragma
- [ ] Multiple Vyper files in project handled
- [ ] Import resolution works for Vyper
- [ ] Interface files (.vyi) handled

---

## 2. Solana/Rust Scanner Infrastructure

### 2.1 Sol-azy Scanner
- [ ] Scanner registered in scanner registry
- [ ] Scanner metadata correct (id, name, version)
- [ ] Supported languages includes "rust"
- [ ] Creates minimal Cargo project structure
- [ ] Anchor dependency added to Cargo.toml
- [ ] Detects missing signer checks
- [ ] Detects account validation issues
- [ ] Detects PDA seed collisions
- [ ] Output format matches ScannerResult schema
- [ ] Handles non-Anchor Solana programs

### 2.2 Sec3 X-Ray Scanner
- [ ] Scanner registered in scanner registry
- [ ] Scanner metadata correct (id, name, version)
- [ ] Supported languages includes "rust"
- [ ] API key configuration (if required)
- [ ] Detects arbitrary CPI vulnerabilities
- [ ] Detects owner check issues
- [ ] Detects math overflow issues
- [ ] Returns detailed vulnerability descriptions
- [ ] Includes remediation recommendations

### 2.3 Trident Fuzzer
- [ ] Scanner registered in scanner registry
- [ ] Scanner metadata correct (id, name, version)
- [ ] Creates proper Anchor project structure
- [ ] Generates trident-tests directory
- [ ] Fuzzing configuration correct
- [ ] Timeout handling for long-running fuzzing
- [ ] Crash detection and reporting
- [ ] Coverage metrics included (if available)

### 2.4 Cargo Fuzz Solana
- [ ] Scanner registered in scanner registry
- [ ] Scanner metadata correct (id, name, version)
- [ ] Creates fuzz target structure
- [ ] Generates fuzz/Cargo.toml correctly
- [ ] libFuzzer integration works
- [ ] Timeout configuration respected
- [ ] Crash artifacts saved and reported
- [ ] Memory limit handling

---

## 3. Scanner Registration & Discovery

### 3.1 Registry Integration
- [ ] All Vyper scanners appear in GET /api/v1/scanners
- [ ] All Solana scanners appear in GET /api/v1/scanners
- [ ] Scanner filtering by language works (language=vyper)
- [ ] Scanner filtering by language works (language=rust)
- [ ] Scanner metadata complete for all scanners
- [ ] Scanner capabilities accurately described

### 3.2 Scanner Selection
- [ ] Vyper contract automatically selects Vyper scanners
- [ ] Rust/Solana contract automatically selects Rust scanners
- [ ] Manual scanner selection works
- [ ] Scanner availability check works
- [ ] Unsupported scanner returns appropriate error

---

## 4. Scan Execution

### 4.1 Vyper Contract Scanning
- [ ] Upload Vyper contract via API
- [ ] Contract language detected as "vyper"
- [ ] Trigger scan with Vyper scanners
- [ ] Scan status transitions (pending → running → completed)
- [ ] Results returned in standard format
- [ ] Vulnerabilities linked to correct line numbers
- [ ] Source code snippets included in findings
- [ ] Scan history recorded

### 4.2 Solana Program Scanning
- [ ] Upload Rust/Solana program via API
- [ ] Contract language detected as "rust"
- [ ] Trigger scan with Solana scanners
- [ ] Scan status transitions correctly
- [ ] Results include Solana-specific findings
- [ ] Account validation issues reported
- [ ] CPI vulnerabilities highlighted
- [ ] Scan metrics recorded (duration, findings count)

### 4.3 Error Handling
- [ ] Invalid Vyper syntax returns compilation error
- [ ] Invalid Rust syntax returns compilation error
- [ ] Scanner timeout handled gracefully
- [ ] Scanner crash doesn't break orchestration
- [ ] Partial results returned on partial failure
- [ ] Error messages are user-friendly

---

## 5. Dashboard Integration

### 5.1 Language Support Display
- [ ] Vyper language icon displayed
- [ ] Rust/Solana language icon displayed
- [ ] Language filter includes Vyper option
- [ ] Language filter includes Rust option
- [ ] Contract list shows correct language badges

### 5.2 Scanner Selection UI
- [ ] Vyper scanners shown for Vyper contracts
- [ ] Solana scanners shown for Rust contracts
- [ ] Scanner descriptions visible
- [ ] Scanner capabilities tooltip
- [ ] Multiple scanner selection works

### 5.3 Results Display
- [ ] Vyper-specific vulnerabilities render correctly
- [ ] Solana-specific vulnerabilities render correctly
- [ ] Vulnerability categories match scanner output
- [ ] Line numbers link to source code
- [ ] Remediation suggestions displayed

---

## 6. Test Contracts

### 6.1 Vulnerable Token (Vyper)
Location: `blocksecops-orchestration/test-contracts/vyper/vulnerable_token.vy`
- [ ] Contract compiles with Vyper compiler
- [ ] Reentrancy in withdraw() detected
- [ ] Missing access control in mint() detected
- [ ] No false positives on safe functions

### 6.2 Vulnerable Vault (Solana/Rust)
Location: `blocksecops-orchestration/test-contracts/solana/vulnerable_vault.rs`
- [ ] Code parses correctly
- [ ] Missing signer check in deposit() detected
- [ ] Arbitrary CPI in withdraw() detected
- [ ] Missing owner validation detected
- [ ] No false positives on helper functions

---

## 7. Performance & Limits

- [ ] Vyper scan completes in reasonable time (<2 min)
- [ ] Solana scan completes in reasonable time (<5 min)
- [ ] Large Vyper files handled (>1000 lines)
- [ ] Large Rust projects handled (multiple files)
- [ ] Memory usage within limits
- [ ] Concurrent scans don't interfere

---

## Test Notes

_Record Vyper/Rust scanner test results here:_

```
[Date] | [Test] | [Result] | [Notes]
2025-12-15 | Vyper scanner availability | PASS | Scanner shows is_available: true in orchestration
2025-12-15 | Moccasin scanner availability | PASS | Scanner shows is_available: true in orchestration
2025-12-15 | Scanner count | PASS | 16/16 scanners available (all ecosystems)
2025-12-15 | Solana scanners | PASS | Sol-azy, Sec3-xray, Trident, Cargo-fuzz available via Docker-based execution
```

---

## Integration Status (December 15, 2025)

### Vyper Scanners
| Scanner | Status | Notes |
|---------|--------|-------|
| Vyper (Slither) | ✅ Available | Installed in orchestration pod (vyper 0.4.0) |
| Moccasin | ✅ Available | Installed in orchestration pod |

### Solana Scanners
| Scanner | Status | Notes |
|---------|--------|-------|
| Sol-azy | ❌ Unavailable | Requires sol-azy binary (Rust) |
| Sec3 X-Ray | ❌ Unavailable | Requires xray binary (Rust) |
| Trident | ❌ Unavailable | Requires trident binary (Rust) |
| Cargo-fuzz-solana | ❌ Unavailable | Requires cargo-fuzz (Rust) |

### Verification Commands
```bash
# Check Vyper/Moccasin availability
curl -s http://127.0.0.1:8004/api/v1/scanners | jq '.scanners[] | select(.name == "Vyper" or .name == "Moccasin") | {name, is_available}'

# Expected output:
# { "name": "Vyper", "is_available": true }
# { "name": "Moccasin", "is_available": true }
```

### Changes Made
- Added `vyper==0.4.0` to orchestration Dockerfile
- Added `moccasin` to orchestration Dockerfile
- Rebuilt orchestration image to version 0.9.0
- Updated deployment to use new image

### Remaining Work
Solana scanners require Rust toolchain installation which would significantly increase orchestration image size. Options:
1. Create separate Rust-based orchestration image
2. Use K8s Job-based execution (scanner runs in own container)
3. Defer Solana scanner integration to future phase
