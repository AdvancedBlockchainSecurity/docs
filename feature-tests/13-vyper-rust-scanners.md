# Vyper & Rust SAST Scanner Tests (Phase 3.5)

**Priority**: P2 - Medium
**Last Tested**: _Not yet tested_
**Feature**: Vyper Scanner Integration, Solana/Rust Scanner Integration

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
```
