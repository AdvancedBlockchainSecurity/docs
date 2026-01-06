# EVT (Events) Fingerprinting Strategy

**Category**: BVD-SOL-EVT-* (Solidity Event-Related Vulnerabilities)
**Status**: Strategy Defined
**Priority**: Medium
**Created**: 2025-11-01
**Last Updated**: 2025-11-01

---

## Overview

Event-related vulnerabilities in Solidity involve missing, incorrect, or malicious event emissions that can impact transparency, auditing, and off-chain monitoring. This document defines fingerprinting strategies for detecting and deduplicating event-related security issues.

**Pattern Examples**:
- `BVD-SOL-EVT-001`: Missing event emission for critical state changes
- `BVD-SOL-EVT-002`: Event emitted before state change (reentrancy risk)
- `BVD-SOL-EVT-003`: Incorrect event parameters (data integrity)
- `BVD-SOL-EVT-004`: Event front-running vulnerability
- `BVD-SOL-EVT-005`: Unused event declarations

---

## Event Code Characteristics

### Unique Challenges

1. **Event Signatures**: Events have unique signatures based on parameter types
2. **Emission Sites**: Same event can be emitted from multiple locations
3. **Parameter Order**: Event parameter order matters for indexing
4. **Indexed Parameters**: `indexed` keyword affects event storage/filtering
5. **Missing Events**: Absence of events is a vulnerability (hard to detect)

### Example Event Vulnerabilities

```solidity
contract VulnerableEvents {
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    mapping(address => uint256) public balances;
    address public owner;

    // VULNERABILITY 1: Missing event emission
    function setOwner(address newOwner) public {
        require(msg.sender == owner, "Not owner");
        owner = newOwner;  // State change without event
        // MISSING: emit OwnershipTransferred(owner, newOwner);
    }

    // VULNERABILITY 2: Event before state change (reentrancy)
    function withdraw(uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        // Event emitted BEFORE state change
        emit Transfer(msg.sender, address(0), amount);

        // External call (reentrancy risk)
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        // State change AFTER event and external call
        balances[msg.sender] -= amount;
    }

    // VULNERABILITY 3: Incorrect event parameters
    function transfer(address to, uint256 amount) public {
        balances[msg.sender] -= amount;
        balances[to] += amount;

        // WRONG: Swapped parameters
        emit Transfer(to, msg.sender, amount);  // Should be (msg.sender, to, amount)
    }
}
```

---

## Fingerprinting Strategy

### 1. Event Signature Hash

**Approach**: Generate hash based on event declaration signature

**Event Signature Format**:
```
EventName(type1,type2,type3)
```

**Implementation**:
```python
def hash_event_signature(event_declaration: str) -> str:
    """
    Generate hash for event signature.

    Args:
        event_declaration: Event declaration like "event Transfer(address,address,uint256)"

    Returns:
        SHA-256 hash of normalized signature
    """
    # Extract event name and parameter types
    match = re.match(r'event\s+(\w+)\s*\((.*?)\)', event_declaration)
    if not match:
        return ""

    event_name = match.group(1)
    params = match.group(2)

    # Remove indexed keyword and parameter names
    param_types = []
    for param in params.split(','):
        # Extract just the type
        param_clean = re.sub(r'\s*indexed\s*', '', param).strip()
        param_type = param_clean.split()[0] if param_clean else ''
        if param_type:
            param_types.append(param_type)

    # Build canonical signature
    signature = f"{event_name}({','.join(param_types)})"

    return hashlib.sha256(signature.encode()).hexdigest()
```

**Example**:
```python
event1 = "event Transfer(address indexed from, address indexed to, uint256 amount)"
event2 = "event Transfer(address sender, address recipient, uint256 value)"

hash1 = hash_event_signature(event1)  # SHA-256("Transfer(address,address,uint256)")
hash2 = hash_event_signature(event2)  # SHA-256("Transfer(address,address,uint256)")

assert hash1 == hash2  # ✅ Same signature despite different names
```

### 2. Emission Site Hash

**Approach**: Hash location where event is emitted

**Components**:
- File path
- Function name
- Line number of `emit` statement
- Event name

**Implementation**:
```python
def hash_emission_site(
    file_path: str,
    function_name: str,
    line_number: int,
    event_name: str,
    contract_name: str = None
) -> str:
    """
    Generate hash for event emission site.

    Args:
        file_path: Contract file path
        function_name: Function emitting the event
        line_number: Line where emit statement is
        event_name: Name of emitted event
        contract_name: Optional contract name

    Returns:
        SHA-256 emission site hash
    """
    location_parts = [
        normalize_path(file_path),
        str(line_number),
        event_name.lower(),
    ]

    if contract_name:
        location_parts.append(contract_name.lower())

    if function_name:
        location_parts.append(function_name.lower())

    location_string = ":".join(location_parts)

    return hashlib.sha256(location_string.encode()).hexdigest()
```

### 3. Event Parameter Hash

**Approach**: Hash event parameters to detect incorrect emissions

**Normalization**:
```python
def normalize_event_parameters(emit_statement: str) -> str:
    """
    Normalize event parameters for hashing.

    Args:
        emit_statement: Like "emit Transfer(msg.sender, to, amount)"

    Returns:
        Normalized parameter string
    """
    # Extract parameters from emit statement
    match = re.search(r'emit\s+\w+\s*\((.*?)\)', emit_statement)
    if not match:
        return ""

    params = match.group(1)

    # Categorize parameters
    categorized = []
    for param in params.split(','):
        param = param.strip()

        # Identify parameter type
        if 'msg.sender' in param:
            categorized.append('SENDER')
        elif re.match(r'0x[0-9a-fA-F]+', param):
            categorized.append('ADDRESS')
        elif param.isdigit():
            categorized.append('NUMBER')
        elif 'address(this)' in param:
            categorized.append('CONTRACT')
        else:
            categorized.append('VARIABLE')

    return ','.join(categorized)
```

---

## Vulnerability Pattern Examples

### Pattern 1: Missing Event Emission (BVD-SOL-EVT-001)

**Detection Strategy**:
```python
def detect_missing_event_emission(function_ast) -> bool:
    """
    Detect critical state changes without event emission.

    Returns:
        True if vulnerability found
    """
    has_state_change = False
    has_event_emission = False

    for node in function_ast.body:
        # Check for state variable assignment
        if node.type == 'assignment_expression':
            left = node.left
            if is_state_variable(left):
                has_state_change = True

        # Check for emit statement
        if node.type == 'emit_statement':
            has_event_emission = True

    return has_state_change and not has_event_emission
```

**Fingerprint**:
```
detection_method: "missing_event_emission"
location_hash: SHA-256("contracts/token.sol:42:setOwner")
state_variable: "owner"
expected_event: "OwnershipTransferred"
```

### Pattern 2: Event Before State Change (BVD-SOL-EVT-002)

**Detection Strategy**:
```python
def detect_event_before_state_change(function_ast) -> list:
    """
    Detect events emitted before state changes (reentrancy risk).

    Returns:
        List of vulnerable event emissions
    """
    vulnerabilities = []
    events_emitted = []
    state_changes = []

    for idx, node in enumerate(function_ast.body):
        if node.type == 'emit_statement':
            events_emitted.append((idx, node))

        if node.type == 'assignment_expression' and is_state_variable(node.left):
            state_changes.append((idx, node))

    # Check if events come before state changes
    for event_idx, event in events_emitted:
        for state_idx, state in state_changes:
            if event_idx < state_idx:
                # Event emitted before state change
                vulnerabilities.append({
                    'event_line': event.line,
                    'state_line': state.line,
                    'event_name': extract_event_name(event),
                })

    return vulnerabilities
```

**Fingerprint**:
```
pattern: "event_before_state_change"
event_name: "Transfer"
event_line: 28
state_change_line: 35
gap: 7  # Lines between event and state change
```

### Pattern 3: Incorrect Event Parameters (BVD-SOL-EVT-003)

**Detection Strategy**:
```python
def detect_incorrect_event_parameters(emit_stmt, event_declaration) -> bool:
    """
    Detect incorrect event parameter usage.

    Example:
        event Transfer(address from, address to, uint256 amount);
        emit Transfer(to, from, amount);  // ❌ Swapped parameters
    """
    emit_params = extract_emit_parameters(emit_stmt)
    decl_params = extract_declaration_parameters(event_declaration)

    # Check parameter count
    if len(emit_params) != len(decl_params):
        return True

    # Check parameter types/patterns
    for emit_param, decl_param in zip(emit_params, decl_params):
        # Example: If declaration says "from" but emit uses "to"
        if is_semantically_incorrect(emit_param, decl_param):
            return True

    return False
```

---

## Deduplication Examples

### Example 1: Same Missing Event Across Scanners

**Scanner A (Slither)**: Detects missing event in `setOwner()`
```python
{
    "detector": "missing-events-state-change",
    "function": "setOwner",
    "state_variable": "owner",
    "line": 42
}
```

**Scanner B (Aderyn)**: Detects missing event in `setOwner()`
```python
{
    "detector": "state-change-no-event",
    "function": "setOwner",
    "variable": "owner",
    "line": 42
}
```

**Fingerprint Matching**:
```python
# Both hash to same location + pattern
location_hash_a = hash_emission_site("Token.sol", "setOwner", 42, "MISSING")
location_hash_b = hash_emission_site("Token.sol", "setOwner", 42, "MISSING")

assert location_hash_a == location_hash_b  # ✅ Deduplicated
```

### Example 2: Event Order Issues

**Finding 1**: Event before state change in `withdraw()`
**Finding 2**: Event before external call in `withdraw()`

**Different Patterns**:
```python
pattern_1 = "event_before_state_change"
pattern_2 = "event_before_external_call"

# Related but different vulnerability types
# Should create separate findings with "related_findings" link
```

---

## Fuzzy Matching Strategy

### Event Signature Similarity

**Approach**: Use Levenshtein distance for event name similarity

```python
def calculate_event_similarity(event1: str, event2: str) -> float:
    """
    Calculate similarity between two event signatures.

    Returns:
        Similarity score 0.0-1.0
    """
    # Extract event names
    name1 = extract_event_name(event1)
    name2 = extract_event_name(event2)

    # Calculate name similarity
    name_similarity = 1 - (levenshtein(name1, name2) / max(len(name1), len(name2)))

    # Extract parameter types
    params1 = extract_parameter_types(event1)
    params2 = extract_parameter_types(event2)

    # Calculate parameter similarity
    if params1 == params2:
        param_similarity = 1.0
    else:
        param_similarity = len(set(params1) & set(params2)) / max(len(params1), len(params2))

    # Combined score
    return (name_similarity * 0.6) + (param_similarity * 0.4)
```

**Example**:
```python
event1 = "Transfer(address,address,uint256)"
event2 = "TransferFrom(address,address,uint256)"

similarity = calculate_event_similarity(event1, event2)
# Returns: ~0.85 (similar but not identical)
```

---

## Implementation Roadmap

### Phase 1: Event Detection (Current)

✅ **Status**: Partially Implemented
- Scanners detect missing events
- Event emissions tracked in findings
- Basic pattern matching

### Phase 2: Event Signature Hashing (Q1 2026)

**Tasks**:
- Implement `hash_event_signature()`
- Build event signature database
- Match event emissions to declarations

**Acceptance Criteria**:
- All events have signature hashes
- Duplicate event detections > 90% deduplicated

### Phase 3: Emission Site Analysis (Q2 2026)

**Tasks**:
- Implement `hash_emission_site()`
- Track event emission order
- Detect event-before-state-change patterns

**Acceptance Criteria**:
- Event order vulnerabilities detected
- Cross-scanner deduplication > 95%

### Phase 4: Semantic Event Analysis (Q3 2026)

**Tasks**:
- Parameter correctness checking
- Event-state change correlation
- Missing event inference

**Acceptance Criteria**:
- Incorrect parameter detection
- Missing event suggestions

---

## Testing Strategy

### Unit Tests

```python
def test_event_signature_hash():
    """Test event signature hashing."""
    event1 = "event Transfer(address indexed from, address indexed to, uint256 amount)"
    event2 = "event Transfer(address sender, address receiver, uint256 value)"

    hash1 = hash_event_signature(event1)
    hash2 = hash_event_signature(event2)

    # Same signature despite different parameter names
    assert hash1 == hash2

def test_emission_site_hash():
    """Test emission site hashing."""
    hash1 = hash_emission_site("Token.sol", "transfer", 42, "Transfer")
    hash2 = hash_emission_site("Token.sol", "transfer", 42, "Transfer")

    assert hash1 == hash2

def test_different_events_different_hashes():
    """Test different events have different hashes."""
    hash1 = hash_event_signature("event Transfer(address,address,uint256)")
    hash2 = hash_event_signature("event Approval(address,address,uint256)")

    assert hash1 != hash2
```

### Integration Tests

```python
def test_missing_event_deduplication():
    """Test missing event findings deduplicate correctly."""
    finding1 = create_finding(
        scanner="slither",
        detector="missing-events-state-change",
        function="setOwner",
        line=42
    )

    finding2 = create_finding(
        scanner="aderyn",
        detector="state-change-no-event",
        function="setOwner",
        line=42
    )

    groups = deduplicate_findings([finding1, finding2])

    assert len(groups) == 1
    assert groups[0].scanner_count == 2
```

---

## References

- **Solidity Events**: https://docs.soliditylang.org/en/latest/contracts.html#events
- **Event Indexing**: https://docs.soliditylang.org/en/latest/abi-spec.html#indexed-event-parameters
- **Best Practices**: https://consensys.github.io/smart-contract-best-practices/development-recommendations/general/event-monitoring/

---

**Status**: ✅ Strategy Defined
**Next Steps**: Implement Phase 2 (Event Signature Hashing)
**Owner**: Intelligence Layer Team
**Review Date**: Q1 2026
