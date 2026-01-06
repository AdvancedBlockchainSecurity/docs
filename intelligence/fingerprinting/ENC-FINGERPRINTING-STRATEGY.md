# ENC (Encoding) Fingerprinting Strategy

**Category**: BVD-SOL-ENC-* (Solidity Encoding/Decoding Vulnerabilities)
**Status**: Strategy Defined
**Priority**: Medium
**Created**: 2025-11-01

---

## Overview

Encoding-related vulnerabilities in Solidity involve incorrect or unsafe usage of `abi.encode`, `abi.encodePacked`, `abi.encodeWithSelector`, and related functions. These can lead to hash collisions, signature replay attacks, and data corruption.

**Pattern Examples**:
- `BVD-SOL-ENC-001`: Hash collision with abi.encodePacked
- `BVD-SOL-ENC-002`: Signature malleability
- `BVD-SOL-ENC-003`: Incorrect encoding selector
- `BVD-SOL-ENC-004`: Missing encoding validation

---

## Fingerprinting Strategy

### 1. Encoding Call Site Hash

**Normalize encoding function calls**:

```python
def hash_encoding_site(file_path: str, line: int, encoding_type: str, params: list) -> str:
    """
    Hash encoding call site.

    encoding_type: "encodePacked" | "encode" | "encodeWithSelector" | "encodeWithSignature"
    params: Parameter count and types
    """
    normalized = f"{encoding_type}:{len(params)}"
    location = f"{normalize_path(file_path)}:{line}:{normalized}"
    return hashlib.sha256(location.encode()).hexdigest()
```

### 2. Collision Pattern Hash

**Detect hash collision patterns**:

```python
def detect_encodePacked_collision(code: str) -> dict:
    """
    Detect abi.encodePacked usage that could cause hash collisions.

    Vulnerable: keccak256(abi.encodePacked(dynamic_array1, dynamic_array2))
    """
    # Extract encodePacked calls
    packed_calls = extract_function_calls(code, "abi.encodePacked")

    for call in packed_calls:
        params = extract_parameters(call)
        # Check if multiple dynamic types (arrays, strings)
        dynamic_params = [p for p in params if is_dynamic_type(p)]

        if len(dynamic_params) >= 2:
            return {
                "pattern": "encodePacked_collision_risk",
                "param_count": len(dynamic_params),
                "hash": hash_encoding_pattern(call)
            }
```

---

## Example Vulnerabilities

### Pattern 1: abi.encodePacked Collision

```solidity
// VULNERABLE: Hash collision possible
bytes32 hash = keccak256(abi.encodePacked(name, symbol));

// name = "AAA" + symbol = "BBB"  →  "AAABBB"
// name = "AA" + symbol = "ABBB"  →  "AAABBB"  (collision!)
```

**Fingerprint**:
```
pattern: "encodePacked_hash_collision"
encoding_type: "encodePacked"
param_types: ["string", "string"]
hash_collision_risk: HIGH
```

### Pattern 2: Incorrect Selector Encoding

```solidity
// VULNERABLE: Hardcoded selector may be wrong
bytes memory data = abi.encodeWithSelector(0x12345678, amount);

// SHOULD BE: abi.encodeWithSignature("transfer(uint256)", amount)
```

---

## Implementation Roadmap

### Phase 1: Detection (Q1 2026)
- Detect abi.encodePacked with multiple dynamic types
- Detect hardcoded selectors

### Phase 2: Deduplication (Q2 2026)
- Implement encoding site hashing
- Pattern-based matching

---

**Status**: ✅ Strategy Defined
**Owner**: Intelligence Layer Team
