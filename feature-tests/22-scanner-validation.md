# Scanner Validation Tests

**Priority**: P0 - Critical
**Last Tested**: _Not yet tested_
**Active Scanners**: 17 (11 Solidity, 2 Vyper, 4 Solana pending)
**Test Contract Location**: `/Users/pwner/Git/vulnerable-smart-contract-examples`

---

## Quick Reference

| Language | Scanners | Status |
|----------|----------|--------|
| Solidity | slither, aderyn, mythril, semgrep, solhint, wake, soliditydefend, echidna, medusa, halmos | Active |
| Vyper | vyper, moccasin | Active |
| Solana | sol-azy, sec3-xray, trident, cargo-fuzz-solana | Pending |

---

## 0. Pre-Flight Checks

### 0.1 Scanner Images Exist
```bash
eval $(minikube docker-env)
docker images | grep "^scanner-"
```

| Scanner | Expected Image | Expected Size |
|---------|---------------|---------------|
| slither | scanner-slither:0.2.0 | ~400MB |
| aderyn | scanner-aderyn:0.6.5 | ~300MB |
| mythril | scanner-mythril:* | ~500MB |
| semgrep | scanner-semgrep:0.3.0 | ~400MB |
| solhint | scanner-solhint:0.2.0 | ~200MB |
| wake | scanner-wake:0.3.1 | ~400MB |
| soliditydefend | scanner-soliditydefend:0.2.1 | ~300MB |
| echidna | scanner-echidna:0.2.0 | ~500MB |
| medusa | scanner-medusa:0.2.0 | ~400MB |
| halmos | scanner-halmos:0.2.0 | ~400MB |
| vyper | scanner-vyper:0.2.0 | ~250MB |
| moccasin | scanner-moccasin:0.2.0 | ~800MB |
| sol-azy | scanner-sol-azy:0.2.0 | ~150MB |
| sec3-xray | scanner-sec3-xray:0.2.0 | ~250MB |
| trident | scanner-trident:0.2.0 | ~2GB |
| cargo-fuzz-solana | scanner-cargo-fuzz-solana:0.2.0 | ~1.7GB |

- [ ] All Solidity scanner images present
- [ ] All Vyper scanner images present
- [ ] All Solana scanner images present

### 0.2 Scanner Registry
```bash
curl -s http://127.0.0.1:3000/api/v1/scanners | jq '.scanners[] | {id, name, is_available}'
```
- [ ] 17 scanners registered
- [ ] All scanners show `is_available: true`

---

## 1. Solidity Static Analysis Scanners

### 1.1 Slither
**Type**: Static Analysis | **Detectors**: 93 | **Project Mode**: Foundry/Hardhat

#### Image Verification
```bash
docker run --rm scanner-slither:0.2.0 --version
# Expected: Slither version 0.10.x
```
- [ ] Image runs without error
- [ ] Version output correct

#### Basic Analysis Test
```bash
# Use test contract from vulnerable-smart-contract-examples
docker run --rm -v /Users/pwner/Git/vulnerable-smart-contract-examples:/contracts \
  scanner-slither:0.2.0 /contracts/solidity/reentrancy/ReentrancyVulnerable.sol --json -
```
- [ ] Scanner executes without error
- [ ] JSON output returned
- [ ] Reentrancy vulnerability detected

#### Dashboard Test
1. Upload `ReentrancyVulnerable.sol` via dashboard
2. Select Slither scanner
3. Run scan
- [ ] Scan completes successfully
- [ ] Vulnerabilities displayed in results
- [ ] Severity levels shown correctly
- [ ] Line numbers accurate

---

### 1.2 Aderyn
**Type**: Static Analysis | **Detectors**: 88 | **Project Mode**: Foundry

#### Image Verification
```bash
docker run --rm scanner-aderyn:0.6.5 --version
# Expected: aderyn 0.6.x
```
- [ ] Image runs without error
- [ ] Version output correct

#### Basic Analysis Test
```bash
docker run --rm -v /Users/pwner/Git/vulnerable-smart-contract-examples:/contracts \
  scanner-aderyn:0.6.5 /contracts/solidity/access-control/UnprotectedAdmin.sol
```
- [ ] Scanner executes without error
- [ ] Findings output returned
- [ ] Access control issue detected

#### Dashboard Test
1. Upload `UnprotectedAdmin.sol` via dashboard
2. Select Aderyn scanner
3. Run scan
- [ ] Scan completes successfully
- [ ] Vulnerabilities displayed in results
- [ ] Different findings than Slither (complementary)

---

### 1.3 Mythril
**Type**: Symbolic Execution | **Detectors**: 4 | **Project Mode**: Single-file

#### Image Verification
```bash
docker run --rm scanner-mythril:latest myth version
# Expected: Mythril version 0.24.x
```
- [ ] Image runs without error
- [ ] Version output correct

#### Basic Analysis Test
```bash
docker run --rm -v /Users/pwner/Git/vulnerable-smart-contract-examples:/contracts \
  scanner-mythril:latest myth analyze /contracts/solidity/integer-overflow/OverflowVulnerable.sol
```
- [ ] Scanner executes without error
- [ ] Analysis output returned
- [ ] Integer overflow detected (if applicable to Solidity version)

#### Dashboard Test
1. Upload `OverflowVulnerable.sol` via dashboard
2. Select Mythril scanner
3. Run scan (expect longer execution time)
- [ ] Scan completes (may take 2-3 minutes)
- [ ] Symbolic execution findings displayed
- [ ] Deep analysis results shown

---

### 1.4 Semgrep
**Type**: Pattern Matching | **Detectors**: 47 | **Project Mode**: Single-file

#### Image Verification
```bash
docker run --rm scanner-semgrep:0.3.0 semgrep --version
# Expected: semgrep 1.x.x
```
- [ ] Image runs without error
- [ ] Version output correct

#### Basic Analysis Test
```bash
docker run --rm -v /Users/pwner/Git/vulnerable-smart-contract-examples:/contracts \
  scanner-semgrep:0.3.0 semgrep --config=auto /contracts/solidity/
```
- [ ] Scanner executes without error
- [ ] Pattern matches returned
- [ ] Common issues detected

#### Dashboard Test
1. Upload any Solidity contract via dashboard
2. Select Semgrep scanner
3. Run scan
- [ ] Scan completes quickly (<30s)
- [ ] Pattern-based findings displayed

---

### 1.5 Solhint
**Type**: Linter | **Detectors**: 20 | **Project Mode**: Single-file

#### Image Verification
```bash
docker run --rm scanner-solhint:0.2.0 solhint --version
# Expected: solhint 5.x.x
```
- [ ] Image runs without error
- [ ] Version output correct

#### Basic Analysis Test
```bash
docker run --rm -v /Users/pwner/Git/vulnerable-smart-contract-examples:/contracts \
  scanner-solhint:0.2.0 solhint /contracts/solidity/**/*.sol
```
- [ ] Scanner executes without error
- [ ] Linting warnings returned
- [ ] Style issues detected

#### Dashboard Test
1. Upload contract with style issues via dashboard
2. Select Solhint scanner
3. Run scan
- [ ] Scan completes quickly
- [ ] Code quality issues displayed
- [ ] Severity shows as "info" or "low"

---

### 1.6 Wake
**Type**: Static Analysis | **Detectors**: - | **Project Mode**: Foundry

#### Image Verification
```bash
docker run --rm scanner-wake:0.3.1 wake --version
# Expected: wake 4.x.x
```
- [ ] Image runs without error
- [ ] Version output correct

#### Basic Analysis Test
```bash
docker run --rm -v /Users/pwner/Git/vulnerable-smart-contract-examples:/contracts \
  scanner-wake:0.3.1 wake detect /contracts/solidity/
```
- [ ] Scanner executes without error
- [ ] Detection output returned

#### Dashboard Test
1. Upload Solidity contract via dashboard
2. Select Wake scanner
3. Run scan
- [ ] Scan completes successfully
- [ ] Findings displayed

---

### 1.7 SolidityDefend
**Type**: Static Analysis | **Detectors**: 204+ | **Project Mode**: Foundry/Hardhat

#### Image Verification
```bash
docker run --rm scanner-soliditydefend:0.2.1 --version
```
- [ ] Image runs without error
- [ ] Version output correct

#### Basic Analysis Test
```bash
docker run --rm -v /Users/pwner/Git/vulnerable-smart-contract-examples:/contracts \
  scanner-soliditydefend:0.2.1 /contracts/solidity/reentrancy/ReentrancyVulnerable.sol
```
- [ ] Scanner executes without error
- [ ] Comprehensive findings returned
- [ ] High detector coverage visible

#### Dashboard Test
1. Upload complex contract via dashboard
2. Select SolidityDefend scanner
3. Run scan
- [ ] Scan completes successfully
- [ ] 204+ detector coverage utilized
- [ ] Detailed remediation suggestions shown

---

## 2. Solidity Fuzzing & Symbolic Scanners

### 2.1 Echidna
**Type**: Fuzzer | **Project Mode**: Foundry

#### Image Verification
```bash
docker run --rm scanner-echidna:0.2.0 echidna --version
# Expected: Echidna 2.x.x
```
- [ ] Image runs without error
- [ ] Version output correct

#### Basic Fuzzing Test
```bash
# Requires contract with echidna test properties
docker run --rm -v /path/to/echidna-test:/contracts \
  scanner-echidna:0.2.0 echidna /contracts/EchidnaTest.sol --test-mode assertion
```
- [ ] Fuzzer executes without error
- [ ] Fuzzing iterations run
- [ ] Property violations detected (if any)

#### Dashboard Test
1. Upload contract with fuzzing properties
2. Select Echidna scanner
3. Run scan (expect longer execution)
- [ ] Fuzzing runs for configured time
- [ ] Results show pass/fail per property
- [ ] Counterexamples displayed for failures

---

### 2.2 Medusa
**Type**: Fuzzer | **Project Mode**: Foundry

#### Image Verification
```bash
docker run --rm scanner-medusa:0.2.0 medusa --version
# Expected: medusa 0.x.x
```
- [ ] Image runs without error
- [ ] Version output correct

#### Basic Fuzzing Test
```bash
docker run --rm -v /path/to/medusa-test:/contracts \
  scanner-medusa:0.2.0 medusa fuzz --target /contracts/
```
- [ ] Fuzzer executes without error
- [ ] Corpus generated
- [ ] Coverage reported

#### Dashboard Test
1. Upload Foundry project with tests
2. Select Medusa scanner
3. Run scan
- [ ] Fuzzing completes
- [ ] Coverage metrics displayed
- [ ] Crash reports shown (if any)

---

### 2.3 Halmos
**Type**: Symbolic Execution | **Project Mode**: Single-file

#### Image Verification
```bash
docker run --rm scanner-halmos:0.2.0 halmos --version
# Expected: halmos 0.x.x
```
- [ ] Image runs without error
- [ ] Version output correct

#### Basic Symbolic Test
```bash
docker run --rm -v /path/to/halmos-test:/contracts \
  scanner-halmos:0.2.0 halmos --root /contracts/
```
- [ ] Symbolic execution runs
- [ ] Assertions verified
- [ ] Counterexamples found (if any)

#### Dashboard Test
1. Upload contract with formal specifications
2. Select Halmos scanner
3. Run scan
- [ ] Symbolic analysis completes
- [ ] Verification results displayed
- [ ] Proved/disproved assertions listed

---

## 3. Vyper Scanners

### 3.1 Vyper (Slither-based)
**Type**: Static Analysis | **Language**: Vyper

#### Image Verification
```bash
docker run --rm --entrypoint vyper scanner-vyper:0.2.0 --version
# Expected: 0.4.3+commit.bff19ea2

docker run --rm scanner-vyper:0.2.0 --version
# Expected: Slither 0.11.3
```
- [ ] Vyper compiler version 0.4.3
- [ ] Slither version 0.11.3

#### Basic Analysis Test
```bash
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

docker run --rm -v /tmp:/contracts scanner-vyper:0.2.0 /contracts/test.vy --json -
```
- [ ] Scanner executes without error
- [ ] JSON output returned
- [ ] Unchecked send detected

#### Dashboard Test
1. Upload `.vy` file via dashboard
2. Language auto-detected as Vyper
3. Vyper scanner auto-selected
4. Run scan
- [ ] Scan completes successfully
- [ ] Vyper-specific vulnerabilities shown
- [ ] Line numbers accurate

---

### 3.2 Moccasin
**Type**: Fuzzer | **Language**: Vyper

#### Image Verification
```bash
docker run --rm scanner-moccasin:0.2.0
# Expected: Moccasin fuzzing banner

docker run --rm --entrypoint vyper scanner-moccasin:0.2.0 --version
# Expected: 0.4.3
```
- [ ] Image runs without error
- [ ] Vyper available in container

#### Basic Fuzzing Test
```bash
# Moccasin requires project structure
docker run --rm -v /path/to/moccasin-project:/project \
  scanner-moccasin:0.2.0 mox test --fuzz
```
- [ ] Fuzzer executes without error
- [ ] Property tests run
- [ ] Results returned

#### Dashboard Test
1. Upload Vyper contract with test properties
2. Select Moccasin scanner
3. Run scan
- [ ] Fuzzing runs
- [ ] Results displayed
- [ ] Crashes/failures highlighted

---

## 4. Solana/Rust Scanners (Pending Integration)

> **Note**: These scanners have Docker images built but are pending orchestration integration.
> Status shows "Unavailable" until Phase 3.5 integration complete.

### 4.1 Sol-azy
**Type**: Static Analysis | **Language**: Rust/Solana

#### Image Verification
```bash
docker run --rm scanner-sol-azy:0.2.0 --help
```
- [ ] Image runs without error
- [ ] Help output shows sol-azy options

#### Basic Analysis Test
```bash
# Create test Anchor program
cat > /tmp/test.rs << 'EOF'
use anchor_lang::prelude::*;

declare_id!("Test111111111111111111111111111111111111111");

#[program]
pub mod test_program {
    use super::*;

    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        Ok(())
    }
}

#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
}
EOF

docker run --rm -v /tmp:/contracts scanner-sol-azy:0.2.0 /contracts/test.rs
```
- [ ] Scanner executes without error
- [ ] Findings returned
- [ ] Missing signer checks detected

#### Dashboard Test
1. Upload `.rs` Solana program via dashboard
2. Language auto-detected as Solana
3. Sol-azy scanner auto-selected
4. Run scan
- [ ] Scan completes successfully
- [ ] Solana-specific vulnerabilities shown
- [ ] Account validation issues detected

---

### 4.2 Sec3 X-Ray
**Type**: Static Analysis | **Language**: Rust/Solana

#### Image Verification
```bash
docker run --rm scanner-sec3-xray:0.2.0 "x-ray-scan --help"
```
- [ ] Image runs without error
- [ ] Help output shows x-ray options

#### Basic Analysis Test
```bash
docker run --rm -v /tmp:/contracts scanner-sec3-xray:0.2.0 /contracts/test.rs
```
- [ ] Scanner executes without error
- [ ] Security findings returned
- [ ] CPI vulnerabilities detected

#### Dashboard Test
1. Upload Solana program via dashboard
2. Select Sec3 X-Ray scanner
3. Run scan
- [ ] Scan completes
- [ ] Detailed vulnerability descriptions
- [ ] Remediation recommendations shown

---

### 4.3 Trident
**Type**: Fuzzer | **Language**: Rust/Solana

#### Image Verification
```bash
docker run --rm scanner-trident:0.2.0 trident --help
```
- [ ] Image runs without error
- [ ] Trident fuzzer help shown

#### Basic Fuzzing Test
```bash
docker run --rm -v /path/to/anchor-project:/project \
  scanner-trident:0.2.0 trident fuzz run
```
- [ ] Fuzzer initializes
- [ ] Fuzzing iterations run
- [ ] Crashes reported

#### Dashboard Test
1. Upload Anchor project via dashboard
2. Select Trident scanner
3. Run scan (expect long execution)
- [ ] Fuzzing runs for configured time
- [ ] Coverage metrics shown
- [ ] Crash artifacts displayed

---

### 4.4 Cargo Fuzz Solana
**Type**: Fuzzer | **Language**: Rust/Solana

#### Image Verification
```bash
docker run --rm scanner-cargo-fuzz-solana:0.2.0 cargo fuzz --help
```
- [ ] Image runs without error
- [ ] Cargo fuzz help shown

#### Basic Fuzzing Test
```bash
docker run --rm -v /path/to/fuzz-target:/project \
  scanner-cargo-fuzz-solana:0.2.0 cargo fuzz run fuzz_target
```
- [ ] Fuzzer executes
- [ ] libFuzzer runs
- [ ] Crashes detected

#### Dashboard Test
1. Upload Rust project with fuzz targets
2. Select Cargo Fuzz scanner
3. Run scan
- [ ] Fuzzing executes
- [ ] Results displayed
- [ ] Memory/crash issues highlighted

---

## 5. Multi-Scanner Tests

### 5.1 Solidity Multi-Scanner
1. Upload `ReentrancyVulnerable.sol`
2. Select: Slither + Aderyn + SolidityDefend
3. Run scan
- [ ] All three scanners execute
- [ ] Results combined in single view
- [ ] Duplicate findings deduplicated
- [ ] Scanner source shown per finding

### 5.2 Vyper Multi-Scanner
1. Upload Vyper contract
2. Select: Vyper + Moccasin
3. Run scan
- [ ] Both scanners execute
- [ ] Static + fuzzing results combined

### 5.3 Full Suite Test (Solidity)
1. Upload complex Solidity contract
2. Select all available Solidity scanners
3. Run scan
- [ ] All scanners execute without blocking each other
- [ ] Results aggregated
- [ ] No timeout issues
- [ ] Performance acceptable (<5 min total)

---

## 6. Language Detection Tests

### 6.1 Auto-Detection
| File Extension | Expected Language | Expected Scanners |
|----------------|-------------------|-------------------|
| `.sol` | Solidity | slither, aderyn, etc. |
| `.vy` | Vyper | vyper, moccasin |
| `.rs` (with Anchor imports) | Solana | sol-azy, sec3-xray, etc. |

- [ ] `.sol` files detected as Solidity
- [ ] `.vy` files detected as Vyper
- [ ] `.rs` files with Anchor detected as Solana
- [ ] Correct scanners auto-selected per language

### 6.2 Manual Override
- [ ] Can manually select different scanners
- [ ] Warning shown for incompatible scanner/language
- [ ] Invalid combinations rejected

---

## 7. Error Handling Tests

### 7.1 Scanner Timeout
- [ ] Scanner timeout handled gracefully
- [ ] Partial results saved (if any)
- [ ] User notified of timeout
- [ ] Scan marked as "failed" with reason

### 7.2 Scanner Crash
- [ ] Scanner crash doesn't break orchestration
- [ ] Error logged and reported
- [ ] Other scanners continue if multi-scanner
- [ ] User-friendly error message

### 7.3 Invalid Input
- [ ] Syntax errors in contract reported
- [ ] Compilation errors shown clearly
- [ ] Unsupported language rejected
- [ ] Empty file handled

---

## 8. Performance Tests

### 8.1 Response Time Expectations

| Scanner Type | Max Acceptable Time |
|--------------|---------------------|
| Static Analysis (Slither, Aderyn) | 2 min |
| Linter (Solhint) | 30 sec |
| Symbolic (Mythril, Halmos) | 10 min |
| Fuzzing (Echidna, Medusa) | 15 min |

- [ ] Static analyzers complete within 2 min
- [ ] Linters complete within 30 sec
- [ ] Symbolic execution within 10 min
- [ ] Fuzzers within 15 min (configurable)

### 8.2 Concurrent Scans
- [ ] Multiple simultaneous scans supported
- [ ] Scans don't interfere with each other
- [ ] Resource limits respected
- [ ] Queue priority honored (Enterprise > Pro > Free)

---

## Test Notes

_Record scanner validation results here:_

```
[Date] | [Scanner] | [Test Type] | [Result] | [Notes]
```

---

## Related Documentation

- [Scanner Documentation](/blocksecops-docs/scanners/README.md)
- [Scanner Integration Guide](/blocksecops-docs/scanners/SCANNER-INTEGRATION-GUIDE.md)
- [Scanner Detector Tracking](/blocksecops-docs/scanners/SCANNER-DETECTOR-TRACKING.md)
