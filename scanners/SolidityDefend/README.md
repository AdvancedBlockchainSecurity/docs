# SolidityDefend Scanner

**Version:** 2.0.1 (Updated February 14, 2026)
**Docker Image:** scanner-soliditydefend:0.8.0
**Language:** Rust
**Target:** Solidity Smart Contracts
**Status:** Fully Integrated and Verified (Single-file + Project Mode)
**Integration Date:** November 20, 2025 (v1.3.7), November 26, 2025 (v1.4.0 + Executor), January 17, 2026 (v1.10.3 Major Upgrade), January 18, 2026 (Full Verification)

---

## Overview

SolidityDefend is a comprehensive Rust-based static analyzer specializing in modern blockchain vulnerabilities. It provides the most extensive coverage of contemporary smart contract security threats in the BlockSecOps platform, with 333 specialized detectors covering EIP-7702, EIP-1153, EIP-3074/4844/6780, ERC-4337 Account Abstraction, ERC-7683 intents, DeFi protocols, MEV, L2/rollup security, advanced proxy patterns, and emerging attack vectors.

### Key Features

- **333 Security Detectors** - Largest detector set in BlockSecOps
- **Modern EIP Coverage** - EIP-7702, EIP-1153, EIP-3074, EIP-4844, EIP-6780, ERC-4337, ERC-7683, ERC-7821
- **DeFi Security** - Vault attacks, AMM invariants, flash loans, oracle manipulation
- **MEV Detection** - Sandwich attacks, front-running, JIT liquidity, liquidation MEV
- **Advanced Proxy Security** - 45 detectors for UUPS, Beacon, Transparent, Diamond, EIP-1167 Clones
- **L2/Rollup Security** - Sequencer MEV, challenge period bypass, blob data manipulation
- **Governance/Access Control** - Timelock bypass, role escalation, quorum manipulation
- **Callback Chain Detection** - Nested reentrancy, multicall msg.value reuse, ERC721/1155 callbacks
- **AI Agent Security** - Emerging threat detection for autonomous contracts
- **Restaking/LRT** - EigenLayer ecosystem vulnerabilities
- **Zero-Knowledge** - ZK proof validation and trusted setup issues

### Why SolidityDefend?

**Unique Coverage:**
- Only scanner detecting EIP-7702 delegation vulnerabilities ($12M+ attacks in 2025)
- Most comprehensive ERC-4337 Account Abstraction coverage (21 detectors)
- Specialized AI agent security detection (4 detectors)
- Complete restaking/LRT protocol analysis (9 detectors)

**Modern Architecture:**
- Written in Rust for performance and safety
- Fast analysis with low false positive rates
- Comprehensive remediation guidance
- Active maintenance and updates

---

## Integration Status

### BlockSecOps Integration

| Component | Status | Details |
|-----------|--------|---------|
| Docker Image | ✅ Complete | `scanner-soliditydefend:latest` (local dev) |
| **Executor** | ✅ **NEW** | `SolidityDefendExecutor` in orchestration (Phase 3.2) |
| Parser | ✅ Complete | `SolidityDefendParser` (updated for v1.4.0 format) |
| **Project Mode** | ✅ **NEW** | Foundry/Hardhat multi-file support (Phase 3.2) |
| API Registration | ✅ Complete | Registered in `scanners.py` (version from ConfigMap) |
| Scan Presets | ✅ Complete | Available in quick/standard/deep scans |
| Pattern Mappings | ✅ Complete | 215 detectors mapped to BVD patterns |
| Intelligence Layer | ✅ Complete | Automatic pattern classification & deduplication |

### Pattern Database Integration (v3.14)

- **Total Detectors:** 333
- **New Patterns Created:** 161 (BVD-SOLIDITY-*)
- **Existing Patterns Used:** 61+
- **Total Pattern Mappings:** 333 (100% coverage)
- **Database Version:** v3.14

---

## Detector Categories

### Critical Severity (12 patterns, 30+ detectors)

**Account Abstraction (ERC-4337)**
- Account takeover vulnerabilities
- EntryPoint trust issues
- Paymaster abuse
- Session key exploits
- Bundler DoS attacks
- Signature aggregation bypasses

**EIP-7702 Delegation**
- Malicious sweeper detection (97% of 2025 delegations)
- Initialization front-running ($1.54M exploit)
- Batch phishing attacks
- tx.origin bypasses

**DeFi Protocol Security**
- Vault share inflation (ERC-4626)
- AMM invariant violations (Uniswap/Curve)
- Lending liquidation abuse (Aave/Compound)
- DEX hook vulnerabilities (UniswapV4)

**Flash Loans & Oracle Manipulation**
- Flash loan price manipulation
- Governance attacks
- Oracle staleness detection
- Single oracle dependencies

**Cross-Chain & L2**
- Bridge message verification
- Optimistic fraud proof timing
- Data availability failures

**Advanced Threats**
- Proxy storage collisions
- Restaking/LRT share inflation
- Zero-knowledge proof vulnerabilities

### High Severity (20 patterns, 60+ detectors)

**MEV & Front-Running**
- Sandwich attack detection
- CREATE2 front-running
- JIT liquidity exploitation
- Toxic flow exposure

**DeFi Mechanics**
- Liquidity pool manipulation
- Yield farming exploits
- Price impact manipulation
- Missing slippage protection

**Modern Standards**
- ERC-7821 batch executor issues
- ERC-7683 intent-based vulnerabilities
- EIP-1153 transient storage reentrancy
- Token standard violations

**Security Fundamentals**
- AI agent decision manipulation
- Logic errors and state transitions
- Input validation failures
- Token supply manipulation

### Medium/Low Severity (11 patterns, 40+ detectors)

**Code Quality & Best Practices**
- Deprecated functions
- Floating pragma versions
- Inefficient storage usage
- Variable shadowing

**Centralization Risks**
- Single admin control
- Guardian role concentration
- Emergency function abuse

**Additional Validations**
- Commit-reveal scheme weaknesses
- Short address attacks
- EXTCODESIZE bypasses
- Withdrawal delay issues

---

## Usage

### Quick Scan

```bash
# Run SolidityDefend scan on a contract
soliditydefend scan path/to/Contract.sol

# Scan entire project
soliditydefend scan path/to/contracts/
```

### Integration with BlockSecOps

SolidityDefend is automatically included in BlockSecOps scan presets:

```bash
# Standard scan (includes SolidityDefend)
0xapogee scan --preset standard path/to/contracts/

# Deep scan (includes SolidityDefend with enhanced checks)
0xapogee scan --preset deep path/to/contracts/
```

### Scan Output

SolidityDefend findings are automatically enriched with:
- **Pattern Code:** BVD-SOLIDITY-* identifier
- **CWE/SWC Mapping:** Standard vulnerability classifications
- **OWASP Category:** Security framework mapping
- **Remediation:** Fix guidance and code examples
- **Fingerprint:** Unique finding identifier for deduplication

**Example Finding:**

```json
{
  "scanner_id": "soliditydefend",
  "detector_id": "vault-share-inflation",
  "pattern_code": "BVD-SOLIDITY-DEFI-VAULT-001",
  "pattern_name": "DeFi Vault Share Manipulation",
  "severity": "critical",
  "title": "Vault Share Inflation Attack",
  "description": "First depositor can inflate share price...",
  "file": "Vault.sol",
  "line": 42,
  "cwe_id": "CWE-682",
  "swc_id": "SWC-XXX",
  "owasp_category": "A3: Logic Errors",
  "remediation": "Implement virtual shares or dead shares...",
  "fingerprint": "hash-of-finding-details",
  "confidence": "high"
}
```

---

## Modern Vulnerability Coverage

### 2024-2025 Attack Vectors

**EIP-7702 Account Delegation** (Critical)
- Detection of malicious sweeper contracts
- Protection against initialization front-running
- Batch operation validation
- Prevents tx.origin authentication bypasses

**ERC-4337 Account Abstraction** (21 detectors)
- EntryPoint trust validation
- Paymaster fund protection
- Session key security
- Bundler DoS prevention
- Signature aggregation safety

**EIP-1153 Transient Storage** (Post-Cancun)
- Low-gas reentrancy detection
- Cross-contract composability checks
- State leakage prevention

**Intent-Based Architecture** (ERC-7683)
- Cross-chain signature replay protection
- Filler front-running detection
- Settlement validation

**AI Agent Security** (Emerging)
- Prompt injection detection
- Decision manipulation prevention
- Resource exhaustion protection

### DeFi Protocol Security

**Vault Security (ERC-4626)**
- Share inflation attacks
- Donation attacks
- First depositor exploits
- Fee manipulation

**AMM Invariants**
- Constant product formula violations
- Liquidity manipulation
- Price impact attacks
- Slippage protection

**Lending Protocols**
- Liquidation abuse
- Borrow bypass
- Collateral manipulation
- Health factor attacks

**Flash Loans**
- Price oracle manipulation
- Governance attacks
- Callback reentrancy
- Flash mint exploits

**Oracle Security**
- Price manipulation detection
- Staleness checks
- Single source dependency
- Time window attacks

**MEV Protection**
- Sandwich attack detection
- Front-running vulnerabilities
- JIT liquidity exploitation
- Toxic flow exposure

### Cross-Chain & Layer 2

**Bridge Security**
- Message verification bypasses
- Replay attack protection
- Data availability issues
- Optimistic challenge periods

**L2 Protocols**
- Fraud proof timing
- Sequencer validation
- Cross-rollup atomicity
- Fee manipulation

---

## Comparison with Other Scanners

| Feature | SolidityDefend | Slither | Aderyn | Mythril |
|---------|----------------|---------|---------|---------|
| **Total Detectors** | **333** | ~80 | ~50 | ~40 |
| **EIP-7702/1153 Coverage** | ✅ 16 | ❌ | ❌ | ❌ |
| **EIP-3074/4844/6780** | ✅ 8 | ❌ | ❌ | ❌ |
| **ERC-4337 Coverage** | ✅ 21 | Partial | Partial | ❌ |
| **Proxy/Upgradeable** | ✅ 45 | ~15 | ~10 | ~5 |
| **L2/Rollup Security** | ✅ 10 | Basic | Basic | ❌ |
| **Governance/Access** | ✅ 10 | Some | Some | ❌ |
| **DeFi Patterns** | ✅ Extensive | Moderate | Limited | Limited |
| **Modern EIPs (2024-26)** | ✅ Complete | Some | Some | Some |
| **AI Agent Security** | ✅ 4 | ❌ | ❌ | ❌ |
| **LRT/Restaking** | ✅ 9 | ❌ | ❌ | ❌ |
| **MEV Detection** | ✅ 12 | Limited | Limited | Limited |
| **Flash Loan Coverage** | ✅ 6 | Basic | Basic | Basic |
| **Pattern Mappings** | **333** | ~100 | ~87 | ~95 |

**Unique Strengths:**
- **SolidityDefend:** Modern vulnerabilities, DeFi security, comprehensive coverage
- **Slither:** Fast analysis, good general coverage
- **Aderyn:** Rust ecosystem, Foundry integration
- **Mythril:** Symbolic execution, formal verification

---

## Pattern Mapping Reference

See [DETECTOR-MAPPING.md](./DETECTOR-MAPPING.md) for complete detector-to-pattern mapping table.

### Summary Statistics

- **Total Detectors:** 333
- **Mapped to Existing Patterns:** 172 (52%)
- **New Patterns Created:** 161 (48%)
- **Pattern Categories:** 40+
- **Coverage:** 100%

### New Patterns Created

All 43 new patterns follow the BVD-SOLIDITY-* taxonomy:

**Modern Blockchain:**
- BVD-SOLIDITY-AA-001 (Account Abstraction)
- BVD-SOLIDITY-EIP7702-001 (EIP-7702 Delegation)
- BVD-SOLIDITY-TRANSIENT-001 (Transient Storage)
- BVD-SOLIDITY-ERC7683-001 (Intent-Based)
- BVD-SOLIDITY-ERC7821-001 (Batch Executor)

**DeFi Security:**
- BVD-SOLIDITY-DEFI-VAULT-001 (Vault Manipulation)
- BVD-SOLIDITY-DEFI-AMM-001 (AMM Invariants)
- BVD-SOLIDITY-DEFI-LENDING-001 (Lending Abuse)
- BVD-SOLIDITY-DEFI-LIQUIDITY-001 (Liquidity Manipulation)
- BVD-SOLIDITY-DEFI-YIELD-001 (Yield Farming)
- BVD-SOLIDITY-DEFI-PRICE-001 (Price Impact)
- BVD-SOLIDITY-DEFI-HOOKS-001 (DEX Hooks)

**Advanced Threats:**
- BVD-SOLIDITY-MEV-001/002/003 (MEV Exploitation)
- BVD-SOLIDITY-FLASH-001 (Flash Loans)
- BVD-SOLIDITY-ORACLE-001/002/003 (Oracle Security)
- BVD-SOLIDITY-L2-001 (Cross-Chain/L2)
- BVD-SOLIDITY-PROXY-001 (Proxy Storage)
- BVD-SOLIDITY-RESTAKING-001 (Restaking/LRT)
- BVD-SOLIDITY-ZK-001 (Zero-Knowledge)
- BVD-SOLIDITY-AI-001 (AI Agents)

*See complete list in [../../../TaskDocs-BlockSecOps/scanners/SOLIDITYDEFEND-PATTERNS-GENERATED.md](../../../TaskDocs-BlockSecOps/scanners/SOLIDITYDEFEND-PATTERNS-GENERATED.md)*

---

## Configuration

### Scanner Settings

SolidityDefend is configured in `blocksecops-orchestration`:

```python
# src/blocksecops_orchestration/scanner_config/scanners.py

SCANNERS = {
    "soliditydefend": ScannerMetadata(
        id="soliditydefend",
        name="SolidityDefend",
        description="Rust-based static analyzer with 333 vulnerability detectors for modern DeFi patterns",
        scanner_type=ScannerType.STATIC_ANALYSIS,
        languages=[ScannerLanguage.SOLIDITY],
        estimated_time_seconds=30,
        requires_compilation=False,
    ),
}
```

### Scan Presets

```python
# Quick scan (essential detectors only)
QUICK_SCAN_DETECTORS = [
    "classic-reentrancy",
    "vault-share-inflation",
    "oracle-manipulation",
    # ... 20 most critical detectors
]

# Standard scan (recommended detectors)
STANDARD_SCAN_DETECTORS = [
    # All quick detectors plus:
    "flash-loan-governance-attack",
    "amm-k-invariant-violation",
    # ... ~80 detectors
]

# Deep scan (all 333 detectors)
DEEP_SCAN_DETECTORS = "all"
```

---

## Performance

### Scan Times

| Project Size | Detectors | Average Time |
|-------------|-----------|--------------|
| Small (1-5 files) | 333 | 5-10 seconds |
| Medium (10-20 files) | 333 | 15-30 seconds |
| Large (50+ files) | 333 | 45-90 seconds |

### Resource Usage

- **CPU:** Single-threaded analysis
- **Memory:** ~500MB typical, ~2GB large projects
- **Disk:** Minimal (analysis only, no compilation)

### False Positive Rates

- **Critical Severity:** 10-15% FP rate
- **High Severity:** 15-25% FP rate
- **Medium Severity:** 25-35% FP rate
- **Low Severity:** 30-40% FP rate

---

## Troubleshooting

### Common Issues

**1. Detector not finding expected issues**
```bash
# Check detector is enabled
soliditydefend list-detectors | grep <detector-id>

# Run with verbose output
soliditydefend scan --verbose path/to/Contract.sol
```

**2. False positives**
- Review detector documentation for limitations
- Check if pattern is expected in your use case
- Suppress specific findings with inline comments

**3. Slow scan times**
- Use quick or standard preset for faster analysis
- Exclude test files and dependencies
- Run on specific files instead of entire project

### Support

- **GitHub Issues:** https://github.com/BlockSecOps/SolidityDefend/issues
- **Documentation:** https://github.com/BlockSecOps/SolidityDefend/tree/main/docs
- **BlockSecOps Docs:** This directory

---

## Integration History

### Version 0.2.6 Result Posting Fix (November 28, 2025)

**Bug Fix: Dashboard Integration**
- Added `CALLBACK_URL` and `SCAN_ID` environment variable support to scanner script
- Added curl POST logic to send results to tool-integration service
- Added `curl` to Dockerfile runtime dependencies
- Fixed issue where scanner found vulnerabilities but results didn't appear in dashboard

**Technical Details:**
- Scanner now POSTs JSON results to callback URL after successful analysis
- Required environment variables: `CALLBACK_URL`, `SCAN_ID`
- Image version: `scanner-soliditydefend:0.2.6`

**Related fixes in session:**
- Fixed jq shell quoting issues with `//` operator (file-based filter approach)
- Fixed version string extraction (grep for version number only)

### Version 1.4.0 Executor Integration (November 26, 2025)

**Phase 3.2: Scanner Executor & Project Mode**
- Created `SolidityDefendExecutor` class in orchestration
- Updated `SolidityDefendParser` for v1.4.0 JSON format
- Added Foundry/Hardhat project mode support
- Registered in `ScannerRegistry` with other Solidity scanners
- Updated version to 1.4.0 via ConfigMap (single source of truth)
- 19 unit tests for project mode
- Tested: Single-file (15 findings), Project mode (28 findings)

**Key Features:**
- **Single-file mode:** `soliditydefend <file> -f json --no-exit-code`
- **Project mode:** `soliditydefend -p <dir> -f json --no-exit-code --framework foundry`
- **JSON extraction:** Handles banner + JSON + summary output format
- **CWE mapping:** Extracts CWE identifiers from findings

### Version 1.3.7 Integration (November 20, 2025)

**Phase 1: Docker & Parser** (October 2025)
- Created scanner Docker image (scanner-soliditydefend:0.2.0)
- Implemented SolidityDefendParser
- Added to API service scanner registry

**Phase 2: Pattern Mapping** (November 20, 2025)
- Mapped all 333 detectors to BVD patterns
- Created 43 new BVD-SOLIDITY patterns
- Achieved 100% coverage

**Phase 3: Database Integration** (November 20, 2025)
- Updated vulnerability_patterns.json to v3.11
- Added 333 pattern_tool_mappings
- Deployed to API service

**Impact:**
- +12% total patterns (355 → 398)
- +48% total mappings (423 → 627)
- +20% SOLIDITY patterns (210 → 253)

---

## References

### External Resources

- **SolidityDefend Repository:** https://github.com/BlockSecOps/SolidityDefend
- **Detector Documentation:** https://github.com/BlockSecOps/SolidityDefend/tree/main/docs/detectors
- **Release Notes:** https://github.com/BlockSecOps/SolidityDefend/releases

### BlockSecOps Documentation

- **Scanner Integration Guide:** [../../SCANNER-INTEGRATION-GUIDE.md](../../SCANNER-INTEGRATION-GUIDE.md)
- **Intelligence Standards:** [../../../docs/standards/INTELLIGENCE-INTEGRATION-STANDARDS.md](../../../docs/standards/INTELLIGENCE-INTEGRATION-STANDARDS.md)
- **Detector Mapping:** [./DETECTOR-MAPPING.md](./DETECTOR-MAPPING.md)

### Integration Documentation

- **Pattern Mapping Status:** [../../../TaskDocs-BlockSecOps/scanners/SOLIDITYDEFEND-PATTERN-MAPPING-STATUS.md](../../../TaskDocs-BlockSecOps/scanners/SOLIDITYDEFEND-PATTERN-MAPPING-STATUS.md)
- **Integration Complete:** [../../../TaskDocs-BlockSecOps/scanners/SOLIDITYDEFEND-INTEGRATION-COMPLETE.md](../../../TaskDocs-BlockSecOps/scanners/SOLIDITYDEFEND-INTEGRATION-COMPLETE.md)
- **Patterns Generated:** [../../../TaskDocs-BlockSecOps/scanners/SOLIDITYDEFEND-PATTERNS-GENERATED.md](../../../TaskDocs-BlockSecOps/scanners/SOLIDITYDEFEND-PATTERNS-GENERATED.md)
- **Database Integration:** [../../../TaskDocs-BlockSecOps/scanners/SOLIDITYDEFEND-DATABASE-INTEGRATION-COMPLETE.md](../../../TaskDocs-BlockSecOps/scanners/SOLIDITYDEFEND-DATABASE-INTEGRATION-COMPLETE.md)

---

**Maintainer:** Advanced Blockchain Security
**Last Updated:** January 18, 2026
**Status:** Production Ready (v1.10.3 with 333 detectors, Image v0.4.0)

---

## Latest Verification (January 18, 2026)

Full platform verification completed. See [Verification Report](/home/pwner/Git/docs/changelogs/SOLIDITYDEFEND-V1.10.3-VERIFICATION-2026-01-18.md).

| Metric | Result |
|--------|--------|
| Version | 2.0.1 |
| Image | scanner-soliditydefend:0.8.0 |
| Detectors | 333 |
| E2E Scan Time | 4 seconds |
| Test Findings | 13 (3 critical, 8 high, 1 medium, 1 low) |
| Verified Patterns | jit-liquidity-sandwich, eip7702-storage-corruption, dos-revert-bomb |
