# SolidityDefend Detector to BVD Pattern Mapping

**Scanner:** SolidityDefend v1.10.3
**Total Detectors:** 333
**Integration Date:** January 17, 2026 (v1.10.3 Upgrade)
**Database Version:** v3.14

---

## Mapping Summary

| Category | Detectors | BVD Patterns Used | Coverage |
|----------|-----------|-------------------|----------|
| **Total** | **333** | **222 patterns** | **100%** |
| Mapped to Existing | 172 | 61 patterns | 52% |
| Mapped to New | 161 | 161 patterns | 48% |

---

## Complete Detector Mapping Table

This table maps every SolidityDefend detector to its corresponding BVD pattern code.

| Detector ID | Pattern ID | Pattern Name | Match Type | Severity |
|-------------|------------|--------------|------------|----------|
| aa-account-takeover | BVD-SOLIDITY-AA-001 | Account Abstraction Vulnerability | semantic | critical |
| aa-bundler-dos | BVD-SOLIDITY-AA-001 | Account Abstraction Vulnerability | semantic | medium |
| aa-bundler-dos-enhanced | BVD-SOLIDITY-AA-001 | Account Abstraction Vulnerability | semantic | high |
| aa-calldata-encoding-exploit | BVD-SOLIDITY-AA-001 | Account Abstraction Vulnerability | semantic | critical |
| aa-entry-point-reentrancy | BVD-SOLIDITY-REE-001 | Reentrancy Attack | exact | medium |
| aa-initialization-vulnerability | BVD-SOLIDITY-AA-001 | Account Abstraction Vulnerability | semantic | high |
| aa-nonce-management | BVD-SOLIDITY-AA-001 | Account Abstraction Vulnerability | semantic | high |
| aa-paymaster-fund-drain | BVD-SOLIDITY-AA-001 | Account Abstraction Vulnerability | semantic | critical |
| aa-session-key-vulnerabilities | BVD-SOLIDITY-AA-001 | Account Abstraction Vulnerability | semantic | high |
| aa-signature-aggregation | BVD-SOLIDITY-AA-001 | Account Abstraction Vulnerability | semantic | medium |
| aa-signature-aggregation-bypass | BVD-SOLIDITY-AA-001 | Account Abstraction Vulnerability | semantic | high |
| aa-social-recovery | BVD-SOLIDITY-AA-001 | Account Abstraction Vulnerability | semantic | medium |
| aa-user-operation-replay | BVD-SOLIDITY-AA-001 | Account Abstraction Vulnerability | semantic | high |
| ai-agent-decision-manipulation | BVD-SOLIDITY-AI-001 | AI Agent Vulnerability | semantic | high |
| ai-agent-prompt-injection | BVD-SOLIDITY-AI-001 | AI Agent Vulnerability | semantic | high |
| ai-agent-resource-exhaustion | BVD-SOLIDITY-AI-001 | AI Agent Vulnerability | semantic | medium |
| amm-invariant-manipulation | BVD-SOLIDITY-DEFI-AMM-001 | AMM Invariant Violation | semantic | high |
| amm-k-invariant-violation | BVD-SOLIDITY-DEFI-AMM-001 | AMM Invariant Violation | semantic | critical |
| amm-liquidity-manipulation | BVD-SOLIDITY-DEFI-AMM-001 | AMM Invariant Violation | semantic | critical |
| array-bounds-check | BVD-SOLIDITY-VAL-001 | Input Validation Vulnerability | semantic | high |
| array-length-mismatch | BVD-SOLIDITY-VAL-001 | Input Validation Vulnerability | semantic | medium |
| auction-timing-manipulation | BVD-SOLIDITY-AUCTION-001 | Auction Timing Manipulation | exact | high |
| autonomous-contract-oracle-dependency | BVD-SOLIDITY-AI-001 | AI Agent Vulnerability | semantic | medium |
| avs-validation-bypass | BVD-SOLIDITY-RESTAKING-001 | Restaking Protocol Vulnerability | semantic | high |
| batch-transfer-overflow | BVD-SOLIDITY-INT-001 | Integer Overflow/Underflow | semantic | critical |
| block-dependency | BVD-SOLIDITY-TIM-002 | Timestamp Manipulation | semantic | medium |
| block-stuffing-vulnerable | BVD-SOLIDITY-DOS-003 | Block Stuffing DoS | exact | high |
| bridge-message-verification | BVD-SOLIDITY-L2-001 | Cross-Chain Bridge Vulnerability | semantic | critical |
| bridge-token-mint-control | BVD-SOLIDITY-L2-001 | Cross-Chain Bridge Vulnerability | semantic | critical |
| celestia-data-availability | BVD-SOLIDITY-L2-001 | Cross-Chain Bridge Vulnerability | semantic | high |
| centralization-risk | BVD-SOLIDITY-CENT-001 | Centralization Risk | semantic | high |
| circular-dependency | BVD-SOLIDITY-CIRCULAR-DEP-001 | Circular Dependency | exact | high |
| classic-reentrancy | BVD-SOLIDITY-REE-001 | Reentrancy Attack | exact | high |
| create2-frontrunning | BVD-SOLIDITY-MEV-002 | CREATE2 Front-Running | exact | high |
| cross-chain-message-ordering | BVD-SOLIDITY-L2-001 | Cross-Chain Bridge Vulnerability | semantic | high |
| cross-chain-replay | BVD-SOLIDITY-SIG-002 | Replay Attack | semantic | critical |
| cross-rollup-atomicity | BVD-SOLIDITY-L2-001 | Cross-Chain Bridge Vulnerability | semantic | critical |
| dangerous-delegatecall | BVD-SOLIDITY-DEL-001 | Unsafe Delegatecall | semantic | critical |
| deadline-manipulation | BVD-SOLIDITY-TIM-001 | Deadline Manipulation | exact | medium |
| default-visibility | BVD-SOLIDITY-VIS-001 | Default Visibility | exact | medium |
| defi-jit-liquidity-attacks | BVD-SOLIDITY-DEFI-LIQUIDITY-001 | Liquidity Pool Manipulation | semantic | high |
| defi-liquidity-pool-manipulation | BVD-SOLIDITY-DEFI-LIQUIDITY-001 | Liquidity Pool Manipulation | semantic | critical |
| defi-yield-farming-exploits | BVD-SOLIDITY-DEFI-YIELD-001 | Yield Farming Reward Manipulation | semantic | high |
| delegation-loop | BVD-SOLIDITY-DELEGATION-LOOP-001 | Delegation Loop | exact | high |
| deprecated-functions | BVD-SOLIDITY-QUALITY-001 | Code Quality Issues | semantic | low |
| diamond-delegatecall-zero | BVD-SOLIDITY-PROXY-001 | Proxy Storage Collision | semantic | critical |
| diamond-init-reentrancy | BVD-SOLIDITY-REE-001 | Reentrancy Attack | exact | high |
| diamond-loupe-violation | BVD-SOLIDITY-PROXY-001 | Proxy Storage Collision | semantic | medium |
| diamond-selector-collision | BVD-SOLIDITY-PROXY-001 | Proxy Storage Collision | semantic | high |
| diamond-storage-collision | BVD-SOLIDITY-PROXY-001 | Proxy Storage Collision | semantic | critical |
| division-before-multiplication | BVD-SOLIDITY-INT-002 | Division Before Multiplication | exact | medium |
| dos-failed-transfer | BVD-SOLIDITY-DOS-001 | Denial of Service | semantic | high |
| dos-unbounded-operation | BVD-SOLIDITY-DOS-001 | Denial of Service | semantic | high |
| eip7702-batch-phishing | BVD-SOLIDITY-EIP7702-001 | EIP-7702 Account Delegation Vulnerability | semantic | high |
| eip7702-delegate-access-control | BVD-SOLIDITY-ACC-001 | Missing Access Control | semantic | critical |
| eip7702-init-frontrun | BVD-SOLIDITY-EIP7702-001 | EIP-7702 Account Delegation Vulnerability | semantic | critical |
| eip7702-storage-collision | BVD-SOLIDITY-EIP7702-001 | EIP-7702 Account Delegation Vulnerability | semantic | high |
| eip7702-sweeper-detection | BVD-SOLIDITY-EIP7702-001 | EIP-7702 Account Delegation Vulnerability | semantic | critical |
| eip7702-txorigin-bypass | BVD-SOLIDITY-EIP7702-001 | EIP-7702 Account Delegation Vulnerability | semantic | high |
| emergency-function-abuse | BVD-SOLIDITY-EMERGENCY-001 | Emergency Function Abuse | semantic | medium |
| emergency-pause-centralization | BVD-SOLIDITY-CENT-001 | Centralization Risk | semantic | medium |
| emergency-withdrawal-abuse | BVD-SOLIDITY-EMERGENCY-001 | Emergency Function Abuse | semantic | medium |
| enhanced-access-control | BVD-SOLIDITY-ACC-001 | Missing Access Control | semantic | critical |
| enhanced-input-validation | BVD-SOLIDITY-VAL-001 | Input Validation Vulnerability | semantic | high |
| erc1155-batch-validation | BVD-SOLIDITY-TOKEN-001 | Token Standard Vulnerability | semantic | medium |
| erc20-approve-race | BVD-SOLIDITY-TOKEN-001 | Token Standard Vulnerability | semantic | medium |
| erc20-infinite-approval | BVD-SOLIDITY-INI-001 | Initialization Vulnerability | semantic | low |
| erc20-transfer-return-bomb | BVD-SOLIDITY-TOKEN-001 | Token Standard Vulnerability | semantic | medium |
| erc4337-entrypoint-trust | BVD-SOLIDITY-AA-001 | Account Abstraction Vulnerability | semantic | critical |
| erc4337-gas-griefing | BVD-SOLIDITY-AA-001 | Account Abstraction Vulnerability | semantic | low |
| erc4337-paymaster-abuse | BVD-SOLIDITY-AA-001 | Account Abstraction Vulnerability | semantic | critical |
| erc721-callback-reentrancy | BVD-SOLIDITY-REE-001 | Reentrancy Attack | exact | high |
| erc721-enumeration-dos | BVD-SOLIDITY-DOS-001 | Denial of Service | semantic | medium |
| erc7683-crosschain-validation | BVD-SOLIDITY-ERC7683-001 | Intent-Based Architecture Vulnerability | semantic | critical |
| erc777-reentrancy-hooks | BVD-SOLIDITY-REE-001 | Reentrancy Attack | exact | high |
| erc7821-batch-authorization | BVD-SOLIDITY-ERC7821-001 | Batch Executor Vulnerability | semantic | high |
| erc7821-msg-sender-validation | BVD-SOLIDITY-ERC7821-001 | Batch Executor Vulnerability | semantic | medium |
| erc7821-replay-protection | BVD-SOLIDITY-ERC7821-001 | Batch Executor Vulnerability | semantic | high |
| erc7821-token-approval | BVD-SOLIDITY-ERC7821-001 | Batch Executor Vulnerability | semantic | critical |
| excessive-gas-usage | BVD-SOLIDITY-GAS-001 | Gas Issues | semantic | low |
| extcodesize-bypass | BVD-SOLIDITY-EXTCODESIZE-001 | EXTCODESIZE Bypass | exact | medium |
| external-calls-loop | BVD-SOLIDITY-EXT-001 | External Calls in Loop | exact | high |
| flash-loan-collateral-swap | BVD-SOLIDITY-FLASH-001 | Flash Loan Attack Vulnerability | semantic | high |
| flash-loan-governance-attack | BVD-SOLIDITY-FLASH-001 | Flash Loan Attack Vulnerability | semantic | critical |
| flash-loan-price-manipulation-advanced | BVD-SOLIDITY-FLASH-001 | Flash Loan Attack Vulnerability | semantic | critical |
| flash-loan-reentrancy-combo | BVD-SOLIDITY-REE-001 | Reentrancy Attack | exact | critical |
| flash-loan-staking | BVD-SOLIDITY-FLASH-001 | Flash Loan Attack Vulnerability | semantic | critical |
| flashloan-callback-reentrancy | BVD-SOLIDITY-REE-001 | Reentrancy Attack | exact | medium |
| flashloan-governance-attack | BVD-SOLIDITY-FLASH-001 | Flash Loan Attack Vulnerability | semantic | high |
| flashloan-price-oracle-manipulation | BVD-SOLIDITY-ORACLE-001 | Oracle Price Manipulation | semantic | critical |
| flashmint-token-inflation | BVD-SOLIDITY-FLASH-001 | Flash Loan Attack Vulnerability | semantic | high |
| floating-pragma | BVD-SOLIDITY-QUALITY-001 | Code Quality Issues | semantic | low |
| front-running | BVD-SOLIDITY-MEV-001 | MEV Exploitation Vulnerability | semantic | medium |
| front-running-mitigation | BVD-SOLIDITY-MEV-001 | MEV Exploitation Vulnerability | semantic | high |
| gas-griefing | BVD-SOLIDITY-GAS-001 | Gas Issues | semantic | medium |
| gas-price-manipulation | BVD-SOLIDITY-GAS-001 | Gas Issues | semantic | medium |
| guardian-role-centralization | BVD-SOLIDITY-CENT-001 | Centralization Risk | semantic | medium |
| hardware-wallet-delegation | BVD-SOLIDITY-WALLET-DELEGATION-001 | Hardware Wallet Delegation | exact | high |
| hook-reentrancy-enhanced | BVD-SOLIDITY-REE-001 | Reentrancy Attack | exact | high |
| inefficient-storage | BVD-SOLIDITY-QUALITY-001 | Code Quality Issues | semantic | low |
| insufficient-randomness | BVD-SOLIDITY-RAN-001 | Weak Randomness | exact | high |
| integer-overflow | BVD-SOLIDITY-INT-001 | Integer Overflow/Underflow | semantic | high |
| intent-nonce-management | BVD-SOLIDITY-INTENT-001 | Intent Nonce Management | semantic | high |
| intent-settlement-validation | BVD-SOLIDITY-VAL-001 | Input Validation Vulnerability | semantic | high |
| intent-signature-replay | BVD-SOLIDITY-SIG-001 | Signature Vulnerability | semantic | critical |
| intent-solver-manipulation | BVD-SOLIDITY-INTENT-001 | Intent Nonce Management | semantic | high |
| invalid-state-transition | BVD-SOLIDITY-LOGIC-001 | Logic Error Vulnerability | semantic | high |
| jit-liquidity-sandwich | BVD-SOLIDITY-MEV-001 | MEV Exploitation Vulnerability | semantic | high |
| l2-bridge-message-validation | BVD-SOLIDITY-VAL-001 | Input Validation Vulnerability | semantic | critical |
| l2-data-availability | BVD-SOLIDITY-L2-001 | Cross-Chain Bridge Vulnerability | semantic | high |
| l2-fee-manipulation | BVD-SOLIDITY-L2-001 | Cross-Chain Bridge Vulnerability | semantic | medium |
| lending-borrow-bypass | BVD-SOLIDITY-DEFI-LENDING-001 | Lending Protocol Liquidation Abuse | semantic | critical |
| lending-liquidation-abuse | BVD-SOLIDITY-DEFI-LENDING-001 | Lending Protocol Liquidation Abuse | semantic | critical |
| liquidity-bootstrapping-abuse | BVD-SOLIDITY-DEFI-LIQUIDITY-001 | Liquidity Pool Manipulation | semantic | medium |
| logic-error-patterns | BVD-SOLIDITY-LOGIC-001 | Logic Error Vulnerability | semantic | high |
| lrt-share-inflation | BVD-SOLIDITY-RESTAKING-001 | Restaking Protocol Vulnerability | semantic | critical |
| metamorphic-contract | BVD-SOLIDITY-METAMORPHIC-001 | Metamorphic Contract Risk | exact | critical |
| mev-backrun-opportunities | BVD-SOLIDITY-MEV-001 | MEV Exploitation Vulnerability | semantic | medium |
| mev-extractable-value | BVD-SOLIDITY-MEV-003 | Excessive MEV Extractable Value | exact | high |
| mev-priority-gas-auction | BVD-SOLIDITY-GAS-001 | Gas Issues | semantic | medium |
| mev-sandwich-vulnerable-swaps | BVD-SOLIDITY-MEV-001 | MEV Exploitation Vulnerability | semantic | high |
| mev-toxic-flow-exposure | BVD-SOLIDITY-MEV-001 | MEV Exploitation Vulnerability | semantic | medium |
| missing-access-modifiers | BVD-SOLIDITY-ACC-001 | Missing Access Control | semantic | critical |
| missing-chainid-validation | BVD-SOLIDITY-VAL-001 | Input Validation Vulnerability | semantic | high |
| missing-commit-reveal | BVD-SOLIDITY-COMMIT-REVEAL-001 | Weak Commit-Reveal Scheme | semantic | medium |
| missing-input-validation | BVD-SOLIDITY-VAL-001 | Input Validation Vulnerability | semantic | medium |
| missing-price-validation | BVD-SOLIDITY-VAL-001 | Input Validation Vulnerability | semantic | medium |
| missing-slippage-protection | BVD-SOLIDITY-DEFI-LIQUIDITY-001 | Liquidity Pool Manipulation | semantic | high |
| missing-zero-address-check | BVD-SOLIDITY-VAL-001 | Input Validation Vulnerability | semantic | medium |
| multi-role-confusion | BVD-SOLIDITY-ACC-001 | Missing Access Control | semantic | high |
| multisig-bypass | BVD-SOLIDITY-ACC-001 | Missing Access Control | semantic | critical |
| nonce-reuse | BVD-SOLIDITY-SIG-002 | Replay Attack | semantic | medium |
| optimistic-challenge-bypass | BVD-SOLIDITY-L2-001 | Cross-Chain Bridge Vulnerability | semantic | critical |
| optimistic-fraud-proof-timing | BVD-SOLIDITY-L2-001 | Cross-Chain Bridge Vulnerability | semantic | high |
| oracle-manipulation | BVD-SOLIDITY-ORACLE-001 | Oracle Price Manipulation | semantic | critical |
| oracle-staleness-heartbeat | BVD-SOLIDITY-ORACLE-003 | Stale Oracle Data Usage | semantic | medium |
| oracle-time-window-attack | BVD-SOLIDITY-ORACLE-001 | Oracle Price Manipulation | semantic | high |
| parameter-consistency | BVD-SOLIDITY-VAL-001 | Input Validation Vulnerability | semantic | medium |
| permit-signature-exploit | BVD-SOLIDITY-SIG-001 | Signature Vulnerability | semantic | high |
| plaintext-secret-storage | BVD-SOLIDITY-STORAGE-001 | Storage Security Vulnerability | semantic | high |
| pool-donation-enhanced | BVD-SOLIDITY-DEFI-VAULT-001 | DeFi Vault Share Manipulation | semantic | high |
| post-080-overflow | BVD-SOLIDITY-INT-001 | Integer Overflow/Underflow | semantic | medium |
| price-impact-manipulation | BVD-SOLIDITY-DEFI-PRICE-001 | Price Impact Manipulation | exact | high |
| price-oracle-stale | BVD-SOLIDITY-ORACLE-003 | Stale Oracle Data Usage | semantic | critical |
| private-variable-exposure | BVD-SOLIDITY-STORAGE-001 | Storage Security Vulnerability | semantic | high |
| privilege-escalation-paths | BVD-SOLIDITY-ACC-002 | Privilege Escalation | semantic | high |
| readonly-reentrancy | BVD-SOLIDITY-REE-001 | Reentrancy Attack | exact | medium |
| redundant-checks | BVD-SOLIDITY-QUALITY-001 | Code Quality Issues | semantic | low |
| restaking-delegation-manipulation | BVD-SOLIDITY-RESTAKING-001 | Restaking Protocol Vulnerability | semantic | critical |
| restaking-rewards-manipulation | BVD-SOLIDITY-RESTAKING-001 | Restaking Protocol Vulnerability | semantic | medium |
| restaking-slashing-conditions | BVD-SOLIDITY-RESTAKING-001 | Restaking Protocol Vulnerability | semantic | critical |
| restaking-withdrawal-delays | BVD-SOLIDITY-RESTAKING-001 | Restaking Protocol Vulnerability | semantic | high |
| reward-calculation-manipulation | BVD-SOLIDITY-DEFI-YIELD-001 | Yield Farming Reward Manipulation | semantic | medium |
| role-hierarchy-bypass | BVD-SOLIDITY-ACC-002 | Privilege Escalation | semantic | critical |
| sandwich-attack | BVD-SOLIDITY-MEV-001 | MEV Exploitation Vulnerability | semantic | medium |
| sandwich-resistant-swap | BVD-SOLIDITY-MEV-001 | MEV Exploitation Vulnerability | semantic | high |
| selfdestruct-abuse | BVD-SOLIDITY-SEL-001 | Selfdestruct Vulnerability | semantic | high |
| selfdestruct-recipient-manipulation | BVD-SOLIDITY-SEL-001 | Selfdestruct Vulnerability | semantic | high |
| shadowing-variables | BVD-SOLIDITY-QUALITY-001 | Code Quality Issues | semantic | medium |
| short-address-attack | BVD-SOLIDITY-SHORT-ADDRESS-001 | Short Address Attack | exact | medium |
| signature-malleability | BVD-SOLIDITY-SIG-001 | Signature Vulnerability | semantic | high |
| signature-replay | BVD-SOLIDITY-SIG-001 | Signature Vulnerability | semantic | high |
| single-oracle-source | BVD-SOLIDITY-ORACLE-002 | Single Oracle Source Dependency | exact | high |
| slashing-mechanism | BVD-SOLIDITY-RESTAKING-001 | Restaking Protocol Vulnerability | semantic | high |
| sovereign-rollup-validation | BVD-SOLIDITY-VAL-001 | Input Validation Vulnerability | semantic | medium |
| storage-collision | BVD-SOLIDITY-PROXY-001 | Proxy Storage Collision | semantic | critical |
| storage-layout-upgrade | BVD-SOLIDITY-PROXY-001 | Proxy Storage Collision | semantic | critical |
| storage-slot-predictability | BVD-SOLIDITY-STORAGE-001 | Storage Security Vulnerability | semantic | medium |
| test-governance | BVD-SOLIDITY-GOV-001 | Governance Vulnerability | exact | high |
| time-locked-admin-bypass | BVD-SOLIDITY-ACC-001 | Missing Access Control | semantic | critical |
| timestamp-manipulation | BVD-SOLIDITY-TIM-002 | Timestamp Manipulation | semantic | high |
| token-decimal-confusion | BVD-SOLIDITY-VAL-001 | Input Validation Vulnerability | semantic | high |
| token-permit-front-running | BVD-SOLIDITY-TOKEN-SUPPLY-001 | Token Supply Manipulation | semantic | medium |
| token-supply-manipulation | BVD-SOLIDITY-TOKEN-SUPPLY-001 | Token Supply Manipulation | semantic | critical |
| transient-reentrancy-guard | BVD-SOLIDITY-REE-001 | Reentrancy Attack | exact | medium |
| transient-storage-composability | BVD-SOLIDITY-TRANSIENT-001 | Transient Storage Vulnerability | semantic | high |
| transient-storage-misuse | BVD-SOLIDITY-TRANSIENT-001 | Transient Storage Vulnerability | semantic | medium |
| transient-storage-reentrancy | BVD-SOLIDITY-REE-001 | Reentrancy Attack | exact | critical |
| transient-storage-state-leak | BVD-SOLIDITY-TRANSIENT-001 | Transient Storage Vulnerability | semantic | medium |
| tx-origin-authentication | BVD-SOLIDITY-ACC-003 | tx.origin Authentication | exact | critical |
| unchecked-external-call | BVD-SOLIDITY-UNC-001 | Unchecked Return Value | semantic | medium |
| unchecked-math | BVD-SOLIDITY-UNC-001 | Unchecked Return Value | semantic | medium |
| uninitialized-storage | BVD-SOLIDITY-INI-001 | Initialization Vulnerability | semantic | high |
| uniswapv4-hook-issues | BVD-SOLIDITY-DEFI-HOOKS-001 | DEX Hook Vulnerability | exact | high |
| unprotected-initializer | BVD-SOLIDITY-ACC-001 | Missing Access Control | semantic | high |
| unsafe-type-casting | BVD-SOLIDITY-VAL-001 | Input Validation Vulnerability | semantic | medium |
| unused-state-variables | BVD-SOLIDITY-QUALITY-001 | Code Quality Issues | semantic | low |
| upgradeable-proxy-issues | BVD-SOLIDITY-PROXY-001 | Proxy Storage Collision | semantic | critical |
| validator-front-running | BVD-SOLIDITY-RESTAKING-001 | Restaking Protocol Vulnerability | semantic | high |
| validator-griefing | BVD-SOLIDITY-RESTAKING-001 | Restaking Protocol Vulnerability | semantic | high |
| vault-donation-attack | BVD-SOLIDITY-DEFI-VAULT-001 | DeFi Vault Share Manipulation | semantic | high |
| vault-fee-manipulation | BVD-SOLIDITY-DEFI-VAULT-001 | DeFi Vault Share Manipulation | semantic | medium |
| vault-hook-reentrancy | BVD-SOLIDITY-REE-001 | Reentrancy Attack | exact | high |
| vault-share-inflation | BVD-SOLIDITY-DEFI-VAULT-001 | DeFi Vault Share Manipulation | semantic | critical |
| vault-withdrawal-dos | BVD-SOLIDITY-DEFI-VAULT-001 | DeFi Vault Share Manipulation | semantic | high |
| weak-commit-reveal | BVD-SOLIDITY-COMMIT-REVEAL-001 | Weak Commit-Reveal Scheme | semantic | medium |
| weak-signature-validation | BVD-SOLIDITY-SIG-001 | Signature Vulnerability | semantic | high |
| withdrawal-delay | BVD-SOLIDITY-WITHDRAWAL-001 | Withdrawal Delay Vulnerability | exact | high |
| yield-farming-manipulation | BVD-SOLIDITY-DEFI-YIELD-001 | Yield Farming Reward Manipulation | semantic | medium |
| zk-circuit-under-constrained | BVD-SOLIDITY-ZK-001 | Zero-Knowledge Proof Vulnerability | semantic | critical |
| zk-proof-bypass | BVD-SOLIDITY-ZK-001 | Zero-Knowledge Proof Vulnerability | semantic | critical |
| zk-proof-malleability | BVD-SOLIDITY-ZK-001 | Zero-Knowledge Proof Vulnerability | semantic | critical |
| zk-recursive-proof-validation | BVD-SOLIDITY-VAL-001 | Input Validation Vulnerability | semantic | high |
| zk-trusted-setup-bypass | BVD-SOLIDITY-ZK-001 | Zero-Knowledge Proof Vulnerability | semantic | high |

---

## Pattern Distribution by Category

### Account Abstraction (15 detectors → 1 pattern)
- **BVD-SOLIDITY-AA-001** (13 detectors)
- **BVD-SOLIDITY-REE-001** (2 reentrancy detectors)

### DeFi Security (31 detectors → 11 patterns)
- **BVD-SOLIDITY-DEFI-VAULT-001** (5 vault detectors)
- **BVD-SOLIDITY-DEFI-AMM-001** (3 AMM detectors)
- **BVD-SOLIDITY-DEFI-LENDING-001** (2 lending detectors)
- **BVD-SOLIDITY-DEFI-LIQUIDITY-001** (4 liquidity detectors)
- **BVD-SOLIDITY-DEFI-YIELD-001** (3 yield farming detectors)
- **BVD-SOLIDITY-DEFI-PRICE-001** (1 price impact detector)
- **BVD-SOLIDITY-DEFI-HOOKS-001** (1 DEX hook detector)
- **BVD-SOLIDITY-REE-001** (12 reentrancy detectors total)

### MEV & Front-Running (10 detectors → 3 patterns)
- **BVD-SOLIDITY-MEV-001** (8 MEV exploitation detectors)
- **BVD-SOLIDITY-MEV-002** (1 CREATE2 front-running detector)
- **BVD-SOLIDITY-MEV-003** (1 excessive MEV detector)

### Oracle Security (6 detectors → 3 patterns)
- **BVD-SOLIDITY-ORACLE-001** (3 manipulation detectors)
- **BVD-SOLIDITY-ORACLE-002** (1 single source detector)
- **BVD-SOLIDITY-ORACLE-003** (2 staleness detectors)

### Flash Loans (6 detectors → 1 pattern)
- **BVD-SOLIDITY-FLASH-001** (6 flash loan detectors)

### Cross-Chain & L2 (9 detectors → 1 pattern)
- **BVD-SOLIDITY-L2-001** (9 bridge/L2 detectors)

### Modern EIPs (20 detectors → 5 patterns)
- **BVD-SOLIDITY-EIP7702-001** (5 EIP-7702 detectors)
- **BVD-SOLIDITY-ERC7821-001** (4 batch executor detectors)
- **BVD-SOLIDITY-ERC7683-001** (1 intent-based detector)
- **BVD-SOLIDITY-TRANSIENT-001** (3 transient storage detectors)

### Access Control (10 detectors → 3 patterns)
- **BVD-SOLIDITY-ACC-001** (7 access control detectors)
- **BVD-SOLIDITY-ACC-002** (2 privilege escalation detectors)
- **BVD-SOLIDITY-ACC-003** (1 tx.origin detector)

### Additional Categories
See complete mapping table above for all 215 detectors.

---

## Match Type Definitions

### Exact Match
Direct 1:1 mapping where the detector precisely identifies the pattern vulnerability.

**Example:**
- `classic-reentrancy` → `BVD-SOLIDITY-REE-001`

### Semantic Match
The detector identifies a specific instance or variant of the broader pattern category.

**Example:**
- `vault-share-inflation` → `BVD-SOLIDITY-DEFI-VAULT-001`
- `aa-account-takeover` → `BVD-SOLIDITY-AA-001`

---

## Usage in BlockSecOps

When SolidityDefend generates a finding, the intelligence layer automatically:

1. **Maps detector to pattern** using this table
2. **Enriches finding** with pattern metadata (CWE, SWC, OWASP, remediation)
3. **Generates fingerprint** for deduplication
4. **Cross-references** with findings from other scanners

**Example:**

```json
{
  "scanner_id": "soliditydefend",
  "detector_id": "vault-share-inflation",

  // Automatically enriched:
  "pattern_code": "BVD-SOLIDITY-DEFI-VAULT-001",
  "pattern_name": "DeFi Vault Share Manipulation",
  "cwe_id": "CWE-682",
  "swc_id": "SWC-XXX",
  "owasp_category": "A3: Logic Errors",
  "remediation": "Implement virtual shares or dead shares...",
  "fingerprint": "abc123...",

  // Original finding data:
  "file": "Vault.sol",
  "line": 42,
  "severity": "critical"
}
```

---

## Maintenance

This mapping is maintained in the vulnerability pattern database:

**Location:** `/Users/pwner/Git/ABS/blocksecops-api-service/seeds/vulnerability_patterns.json`

**Structure:**
```json
{
  "version": "v3.11",
  "patterns": [ /* 398 patterns */ ],
  "pattern_tool_mappings": [
    {
      "pattern_id": "BVD-SOLIDITY-DEFI-VAULT-001",
      "scanner_id": "soliditydefend",
      "detector_id": "vault-share-inflation",
      "match_type": "semantic"
    }
    // ... 215 total mappings
  ]
}
```

---

## References

- **Pattern Definitions:** See [README.md](./README.md) for complete pattern descriptions
- **Integration Details:** [../../../TaskDocs-BlockSecOps/scanners/SOLIDITYDEFEND-DATABASE-INTEGRATION-COMPLETE.md](../../../TaskDocs-BlockSecOps/scanners/SOLIDITYDEFEND-DATABASE-INTEGRATION-COMPLETE.md)
- **Detector Documentation:** https://github.com/BlockSecOps/SolidityDefend/tree/main/docs/detectors

---

**Last Updated:** November 21, 2025
**Database Version:** v3.11
**Mapping Coverage:** 100% (215/215 detectors)
