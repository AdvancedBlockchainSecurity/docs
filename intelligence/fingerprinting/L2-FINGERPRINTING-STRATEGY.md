# L2 (Layer 2) Fingerprinting Strategy

**Category**: BVD-CAIRO-L2S-* (Layer 2 Security Vulnerabilities)
**Status**: Strategy Defined
**Priority**: High (Cairo/StarkNet specific)
**Created**: 2025-11-01

---

## Overview

Layer 2 vulnerabilities are specific to L2 scaling solutions (StarkNet, Optimism, Arbitrum, zkSync). These involve cross-layer communication, L1↔L2 message passing, and L2-specific execution environments.

**Pattern Examples**:
- `BVD-CAIRO-L2S-001`: Unchecked L1 handler origin
- `BVD-SOL-L2S-001`: Cross-chain replay attacks
- `BVD-SOL-L2S-002`: L1→L2 message validation issues
- `BVD-SOL-L2S-003`: Sequencer trust assumptions

---

## L2-Specific Challenges

### 1. Cross-Layer Communication

**StarkNet L1↔L2 Messages**:
```cairo
#[l1_handler]
fn deposit(ref self: ContractState, from_address: felt252, amount: u256) {
    // VULNERABILITY: from_address not validated
    // Attacker can forge L1 sender address
}
```

### 2. Chain ID Dependencies

**Cross-chain Replay**:
```solidity
// VULNERABLE: Signature valid on multiple L2s
bytes32 hash = keccak256(abi.encode(to, amount));
// Missing: block.chainid in hash
```

---

## Fingerprinting Strategy

### 1. L2 Context Hash

**Include L2-specific context**:

```python
def hash_l2_context(
    l2_type: str,  # "starknet" | "optimism" | "arbitrum"
    cross_layer: bool,  # L1↔L2 interaction
    message_type: str,  # "l1_handler" | "l2_message"
    file_path: str,
    line: int
) -> str:
    """Hash L2-specific vulnerability context."""
    context = f"{l2_type}:{message_type}:{cross_layer}"
    location = f"{normalize_path(file_path)}:{line}:{context}"
    return hashlib.sha256(location.encode()).hexdigest()
```

### 2. Cross-Chain Deduplication

**Handle same vulnerability across different L2s**:

```python
def deduplicate_across_l2s(findings: list) -> list:
    """
    Deduplicate vulnerabilities that exist across multiple L2s.

    Example: Missing chainid validation on Optimism + Arbitrum
    """
    # Group by vulnerability pattern (ignoring L2 type)
    groups = defaultdict(list)

    for finding in findings:
        # Hash without L2-specific details
        pattern_hash = hash_vulnerability_pattern(
            detector=finding.detector_id,
            code=normalize_l2_code(finding.code),  # Remove L2-specific syntax
            function=finding.function_name
        )
        groups[pattern_hash].append(finding)

    return groups
```

---

## Example Vulnerabilities

### Pattern 1: Unchecked L1 Handler (Cairo)

```cairo
#[l1_handler]
fn process_deposit(
    ref self: ContractState,
    from_address: felt252,  // L1 sender
    amount: u256
) {
    // VULNERABILITY: from_address not validated against expected L1 contract
}
```

**Fingerprint**:
```
l2_type: "starknet"
pattern: "unchecked_l1_handler"
detector: "unchecked-l1-handler-from"
bvd_code: "BVD-CAIRO-L2S-001"
```

### Pattern 2: Cross-Chain Replay (Solidity L2)

```solidity
// Optimism/Arbitrum contract
function execute(bytes calldata signature) public {
    // VULNERABLE: No chainid in signature
    bytes32 hash = keccak256(abi.encode(msg.sender, nonce));
    address signer = ecrecover(hash, signature);
    // Signature can be replayed on other L2s
}
```

**Fingerprint**:
```
l2_type: "optimism"  // or "arbitrum"
pattern: "cross_chain_replay"
missing_field: "chainid"
```

---

## Cross-L2 Deduplication

**Same vulnerability on Optimism + Arbitrum**:

```python
finding1 = {
    "scanner": "slither",
    "l2_type": "optimism",
    "pattern": "missing_chainid",
    "function": "execute",
    "line": 42
}

finding2 = {
    "scanner": "slither",
    "l2_type": "arbitrum",
    "pattern": "missing_chainid",
    "function": "execute",
    "line": 42
}

# Deduplicate based on pattern (ignore l2_type)
pattern_hash1 = hash_l2_pattern(finding1, ignore_l2_type=True)
pattern_hash2 = hash_l2_pattern(finding2, ignore_l2_type=True)

assert pattern_hash1 == pattern_hash2  # Same vulnerability pattern
```

---

## Implementation Roadmap

### Phase 1: StarkNet L1 Handler Detection (Current)

✅ **Status**: Implemented (Caracal integration)
- Detect unchecked L1 handlers
- BVD-CAIRO-L2S-001 pattern mapping

### Phase 2: Cross-Chain Deduplication (Q1 2026)

**Tasks**:
- Implement L2 context hashing
- Cross-chain pattern matching
- Chainid validation detection

### Phase 3: Multi-L2 Analysis (Q2 2026)

**Tasks**:
- Analyze same contract deployed on multiple L2s
- Compare vulnerability profiles across L2s
- L2-specific remediation suggestions

---

**Status**: ✅ Strategy Defined
**Owner**: Intelligence Layer Team
**Review Date**: Q1 2026
