# ASM (Assembly) Fingerprinting Strategy

**Category**: BVD-SOL-ASM-* (Solidity Assembly Vulnerabilities)
**Status**: Strategy Defined
**Priority**: Medium
**Created**: 2025-11-01
**Last Updated**: 2025-11-01

---

## Overview

Assembly (inline assembly) blocks in Solidity (`assembly { ... }`) require specialized fingerprinting strategies due to their low-level nature and different semantics compared to high-level Solidity code. This document defines fingerprinting strategies for detecting and deduplicating assembly-related vulnerabilities.

**Pattern Examples**:
- `BVD-SOL-ASM-001`: Unsafe inline assembly operations
- `BVD-SOL-ASM-002`: Unchecked assembly return values
- `BVD-SOL-ASM-003`: Memory corruption in assembly
- `BVD-SOL-ASM-004`: Storage pointer manipulation
- `BVD-SOL-ASM-005`: Dangerous delegatecall in assembly

---

## Assembly Code Characteristics

### Unique Challenges

1. **Opcode-Level Operations**: Assembly uses EVM opcodes directly
2. **No Type Safety**: Assembly bypasses Solidity type system
3. **Manual Memory Management**: Direct memory manipulation via `mload`, `mstore`
4. **Storage Slot Access**: Direct storage access via `sload`, `sstore`
5. **Low-Level Calls**: `call`, `delegatecall`, `staticcall` without safety checks

### Example Assembly Block

```solidity
function unsafeAssembly(address target, bytes memory data) public returns (bool) {
    assembly {
        // VULNERABILITY: Unchecked delegatecall
        let result := delegatecall(
            gas(),
            target,
            add(data, 0x20),
            mload(data),
            0,
            0
        )
        // Return value not checked
    }
}
```

---

## Fingerprinting Strategy

### 1. Code Hash Strategy

**Approach**: Normalize assembly blocks before hashing

**Normalization Steps**:
```
Raw Assembly Block
  ↓
1. Extract assembly { ... } content
  ↓
2. Normalize opcode names (lowercase)
  ↓
3. Remove comments and whitespace
  ↓
4. Group by opcode categories
   - Memory ops: mload, mstore, mstore8
   - Storage ops: sload, sstore
   - Call ops: call, delegatecall, staticcall
   - Control flow: jump, jumpi, jumpdest
  ↓
5. Generate SHA-256 hash
```

**Implementation**:
```python
def normalize_assembly_block(assembly_code: str) -> str:
    """
    Normalize assembly block for fingerprinting.

    Args:
        assembly_code: Raw assembly block content

    Returns:
        Normalized assembly code
    """
    # Extract assembly content
    assembly_match = re.search(r'assembly\s*{([^}]+)}', assembly_code, re.DOTALL)
    if not assembly_match:
        return assembly_code.lower().strip()

    assembly_content = assembly_match.group(1)

    # Normalize opcodes
    opcodes = extract_opcodes(assembly_content)

    # Sort opcodes by category for consistent ordering
    categorized = categorize_opcodes(opcodes)

    # Build normalized string
    normalized = "assembly{" + ";".join(sorted(categorized)) + "}"

    return normalized.lower()
```

### 2. AST Hash Strategy

**Approach**: Extract assembly AST structure and hash operation tree

**AST Node Types**:
- `yul_block`: Assembly block container
- `yul_function_call`: Function calls (opcodes)
- `yul_identifier`: Variable/function names
- `yul_literal`: Numeric/string literals

**Normalization**:
```python
def hash_assembly_ast(assembly_code: str, ignore_literals: bool = True) -> str:
    """
    Generate AST hash for assembly block.

    Args:
        assembly_code: Assembly block source
        ignore_literals: Ignore literal values (0x20, gas(), etc.)

    Returns:
        SHA-256 hash of AST structure
    """
    # Parse with tree-sitter (Solidity grammar includes Yul/assembly)
    tree = parse_solidity(assembly_code)

    # Extract assembly-specific nodes
    assembly_nodes = extract_nodes(tree, node_types={
        'yul_block',
        'yul_function_call',
        'yul_assignment',
        'yul_variable_declaration'
    })

    # Build opcode sequence
    opcode_sequence = []
    for node in assembly_nodes:
        if node.type == 'yul_function_call':
            opcode = node.child_by_field_name('function').text.decode()
            opcode_sequence.append(opcode.lower())

    # Hash opcode sequence
    return hashlib.sha256(
        ";".join(opcode_sequence).encode()
    ).hexdigest()
```

### 3. Location Hash Strategy

**Standard Location Hashing**:
- File path normalization
- Line number (start of assembly block)
- Function name containing assembly
- Contract name

**Assembly-Specific Considerations**:
```python
def hash_assembly_location(
    file_path: str,
    line_number: int,
    function_name: str,
    contract_name: str,
    assembly_block_id: int = 0  # For multiple assembly blocks in same function
) -> str:
    """
    Generate location hash for assembly block.

    Args:
        file_path: Contract file path
        line_number: Line where assembly block starts
        function_name: Containing function
        contract_name: Containing contract
        assembly_block_id: Index if multiple blocks in same function

    Returns:
        SHA-256 location hash
    """
    location_string = f"{normalize_path(file_path)}:{line_number}:{contract_name}:{function_name}:asm{assembly_block_id}"

    return hashlib.sha256(location_string.encode()).hexdigest()
```

---

## Vulnerability Pattern Examples

### Pattern 1: Unchecked Delegatecall (BVD-SOL-ASM-001)

**Vulnerable Code**:
```solidity
assembly {
    let result := delegatecall(gas(), target, ptr, size, 0, 0)
    // VULNERABILITY: result not checked
}
```

**Fingerprint**:
```
code_hash: SHA-256(normalize("assembly{delegatecall(gas(),target,ptr,size,0,0)}"))
location_hash: SHA-256("contracts/proxy.sol:42:Proxy:execute:asm0")
ast_hash: SHA-256("yul_function_call:delegatecall")
```

### Pattern 2: Memory Corruption (BVD-SOL-ASM-002)

**Vulnerable Code**:
```solidity
assembly {
    // VULNERABILITY: Overwriting memory without bounds check
    mstore(0x40, add(mload(0x40), size))
}
```

**Fingerprint**:
```
code_hash: SHA-256(normalize("assembly{mstore(0x40,add(mload(0x40),size))}"))
opcode_sequence: ["mstore", "add", "mload"]
pattern: memory_manipulation
```

### Pattern 3: Storage Slot Manipulation (BVD-SOL-ASM-003)

**Vulnerable Code**:
```solidity
assembly {
    // VULNERABILITY: Direct storage write without access control
    sstore(slot, value)
}
```

**Fingerprint**:
```
code_hash: SHA-256(normalize("assembly{sstore(slot,value)}"))
opcode_sequence: ["sstore"]
pattern: storage_manipulation
```

---

## Edge Cases and Special Considerations

### 1. Multiple Assembly Blocks

**Challenge**: Same function may have multiple assembly blocks

**Solution**: Use `assembly_block_id` index
```python
# First assembly block
location_hash_1 = hash_assembly_location(..., assembly_block_id=0)

# Second assembly block
location_hash_2 = hash_assembly_location(..., assembly_block_id=1)
```

### 2. Nested Assembly Blocks

**Challenge**: Assembly within assembly (rare but possible)

**Solution**: Flatten nested blocks and track depth
```python
def extract_nested_assembly(code: str) -> list[AssemblyBlock]:
    """Extract all assembly blocks including nested ones."""
    blocks = []
    depth = 0

    for match in find_all_assembly_blocks(code):
        blocks.append(AssemblyBlock(
            code=match.group(0),
            depth=calculate_depth(match.start(), code),
            line=get_line_number(match.start(), code)
        ))

    return blocks
```

### 3. Assembly with External Library Calls

**Challenge**: Assembly calling library functions

**Solution**: Include library references in fingerprint
```solidity
assembly {
    // Call to external library
    let result := call(gas(), libraryAddress, 0, ptr, size, 0, 0)
}
```

**Fingerprint Enhancement**:
```python
# Include external references
fingerprint_data = {
    "code_hash": code_hash,
    "location_hash": location_hash,
    "external_calls": ["libraryAddress"],
    "call_type": "library_call"
}
```

---

## Deduplication Examples

### Example 1: Same Assembly Pattern, Different Variables

**Scanner A (Slither)**:
```solidity
assembly {
    let result := delegatecall(gas(), target, ptr, size, 0, 0)
}
```

**Scanner B (Mythril)**:
```solidity
assembly {
    let success := delegatecall(gas(), addr, dataPtr, dataSize, 0, 0)
}
```

**Fingerprint Matching**:
```python
# Both normalize to same opcode sequence
code_hash_a = hash_assembly_ast("assembly{delegatecall(gas(),*,*,*,0,0)}")
code_hash_b = hash_assembly_ast("assembly{delegatecall(gas(),*,*,*,0,0)}")

assert code_hash_a == code_hash_b  # ✅ Match - same vulnerability pattern
```

### Example 2: Different Assembly Operations

**Finding 1: Unchecked delegatecall**:
```solidity
assembly {
    delegatecall(gas(), target, 0, 0, 0, 0)
}
```

**Finding 2: Unchecked call**:
```solidity
assembly {
    call(gas(), target, 0, 0, 0, 0, 0)
}
```

**Fingerprint Matching**:
```python
# Different opcodes = different vulnerabilities
hash_1 = hash_assembly_ast("assembly{delegatecall(...)}")
hash_2 = hash_assembly_ast("assembly{call(...)}")

assert hash_1 != hash_2  # ✅ Different patterns
```

---

## Implementation Roadmap

### Phase 1: Basic Assembly Detection (Current)

✅ **Status**: Implemented
- Detect assembly blocks in source code
- Extract line numbers and function context
- Store in database

### Phase 2: Assembly-Specific Normalization (Q1 2026)

**Tasks**:
- Implement `normalize_assembly_block()`
- Add opcode categorization
- Generate assembly-specific code hashes

**Acceptance Criteria**:
- Same assembly pattern → same hash > 90%
- Different patterns → different hashes > 95%

### Phase 3: AST-Based Assembly Matching (Q2 2026)

**Tasks**:
- Extend ASTHasher for Yul/assembly nodes
- Implement `hash_assembly_ast()`
- Add opcode sequence extraction

**Acceptance Criteria**:
- Structural matching across variable name changes
- Pattern detection (delegatecall without check)

### Phase 4: Semantic Assembly Analysis (Q3 2026)

**Tasks**:
- Dataflow analysis within assembly blocks
- Taint tracking for user-controlled assembly inputs
- Pattern library for known assembly vulnerabilities

---

## Testing Strategy

### Unit Tests

```python
def test_assembly_code_hash_consistency():
    """Test assembly normalization produces consistent hashes."""
    code1 = "assembly { let x := delegatecall(gas(), target, 0, 0, 0, 0) }"
    code2 = "assembly { let result := delegatecall(gas(), addr, 0, 0, 0, 0) }"

    # Should normalize to same hash (ignore variable names)
    hash1 = hash_assembly_ast(code1, ignore_identifiers=True)
    hash2 = hash_assembly_ast(code2, ignore_identifiers=True)

    assert hash1 == hash2

def test_different_opcodes_different_hashes():
    """Test different assembly operations have different hashes."""
    code1 = "assembly { delegatecall(gas(), target, 0, 0, 0, 0) }"
    code2 = "assembly { call(gas(), target, 0, 0, 0, 0, 0) }"

    hash1 = hash_assembly_code(code1)
    hash2 = hash_assembly_code(code2)

    assert hash1 != hash2  # Different opcodes
```

### Integration Tests

```python
def test_assembly_deduplication_across_scanners():
    """Test assembly vulnerability deduplication."""
    # Same assembly vulnerability detected by 2 scanners
    finding1 = create_finding(
        scanner="slither",
        detector="assembly-delegatecall",
        code="assembly { delegatecall(gas(), target, 0, 0, 0, 0) }",
        line=42
    )

    finding2 = create_finding(
        scanner="mythril",
        detector="unchecked-assembly-call",
        code="assembly { delegatecall(gas(), target, 0, 0, 0, 0) }",
        line=42
    )

    # Should deduplicate
    groups = deduplicate_findings([finding1, finding2])

    assert len(groups) == 1
    assert groups[0].scanner_count == 2
```

---

## References

- **Solidity Assembly Documentation**: https://docs.soliditylang.org/en/latest/assembly.html
- **Yul Language**: https://docs.soliditylang.org/en/latest/yul.html
- **EVM Opcodes**: https://www.evm.codes/
- **Tree-sitter Solidity Grammar**: https://github.com/JoranHonig/tree-sitter-solidity

---

**Status**: ✅ Strategy Defined
**Next Steps**: Implement Phase 2 (Assembly-Specific Normalization)
**Owner**: Intelligence Layer Team
**Review Date**: Q1 2026
