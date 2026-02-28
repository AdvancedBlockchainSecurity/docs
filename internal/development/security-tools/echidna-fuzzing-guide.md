# Echidna Property-Based Fuzzing Guide

## Overview

Echidna is an advanced property-based fuzzer for Ethereum smart contracts developed by Trail of Bits. Unlike traditional static analysis tools that examine code patterns, Echidna generates intelligent test cases to find violations of user-defined properties and Solidity assertions through runtime testing.

The Apogee platform integrates Echidna v2.2.4, providing automatic property-based fuzzing for all Solidity smart contracts with zero configuration required.

## Table of Contents

- [What is Property-Based Fuzzing?](#what-is-property-based-fuzzing)
- [Why Use Echidna?](#why-use-echidna)
- [Quick Start](#quick-start)
- [Writing Properties](#writing-properties)
- [Common Patterns](#common-patterns)
- [Configuration Options](#configuration-options)
- [Understanding Results](#understanding-results)
- [Best Practices](#best-practices)
- [Examples](#examples)
- [FAQ](#faq)

## What is Property-Based Fuzzing?

Property-based fuzzing tests your smart contracts by:

1. **Defining Properties**: You write invariants that should always hold true
2. **Generating Test Cases**: Echidna automatically generates thousands of transaction sequences
3. **Finding Violations**: When a property fails, Echidna provides the exact steps to reproduce the bug
4. **Learning**: The fuzzer learns from successful inputs to improve coverage

**Example Property**:
```solidity
function echidna_balance_never_negative() public returns (bool) {
    // Property: user balance should never go negative
    return balance[msg.sender] >= 0;
}
```

Echidna will try to break this property by calling your contract functions in various combinations with random inputs.

## Why Use Echidna?

### Complements Static Analysis

| Analysis Type | What It Finds | What It Misses |
|---------------|---------------|----------------|
| **Static Analysis** (Slither, Mythril) | Code patterns, known vulnerabilities | Runtime bugs, complex state transitions |
| **Fuzzing** (Echidna) | Runtime bugs, state inconsistencies | Some code patterns without execution |

**Use Both**: Run Slither for quick pattern detection, then run Echidna to find deeper runtime issues.

### Advantages

1. **Finds Runtime Bugs**: Discovers issues that only occur during execution
2. **Counterexamples**: Provides exact transaction sequence to reproduce bugs
3. **State Exploration**: Tests complex state transitions that humans might miss
4. **Automated**: Requires minimal setup - just write properties
5. **Industry Standard**: Used by Trail of Bits, ConsenSys, and leading audit firms

### Disadvantages

1. **Requires Properties**: You must write invariants (or rely on assertions)
2. **Time-Intensive**: Runs longer than static analysis (2-10 minutes)
3. **Solidity Only**: Currently only supports Solidity contracts
4. **Non-Deterministic**: May find different issues on each run (use corpus for consistency)

## Quick Start

### Step 1: Upload Your Contract

Upload your Solidity contract to Apogee as usual:

```bash
# Via API
curl -X POST https://api.0xapogee.io/api/v1/contracts \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@MyToken.sol"
```

### Step 2: Select Echidna Scanner

When initiating a scan, select Echidna as one of your scanners:

```bash
curl -X POST https://api.0xapogee.io/api/v1/scans \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "contract_id": "your-contract-id",
    "scanners": ["echidna", "slither"]
  }'
```

### Step 3: View Results

Echidna will run for 2-5 minutes (depending on contract complexity) and return findings with counterexamples:

```json
{
  "tool": "echidna",
  "findings": [
    {
      "type": "property_violation",
      "severity": "high",
      "message": "Property violated: echidna_balance_never_negative",
      "details": {
        "counterexample": [
          "transfer(0x1234..., 1000000)",
          "withdraw(2000000)"
        ],
        "call_sequence": [
          {"function": "deposit", "args": ["1000000"], "sender": "0x10000"},
          {"function": "transfer", "args": ["0x1234...", "1000000"], "sender": "0x10000"},
          {"function": "withdraw", "args": ["2000000"], "sender": "0x10000"}
        ],
        "gas_used": 125432
      }
    }
  ]
}
```

## Writing Properties

### Property Function Format

Echidna properties are Solidity functions that:
- Start with `echidna_` prefix
- Take no parameters
- Return `bool`
- Should always return `true`

**Example**:
```solidity
function echidna_my_property() public returns (bool) {
    // This should always be true
    return totalSupply >= sumOfBalances();
}
```

### Types of Properties

#### 1. State Invariants

Properties that must always hold about contract state:

```solidity
contract Token {
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    function echidna_conservation_of_tokens() public returns (bool) {
        // Property: sum of all balances equals total supply
        return _sumBalances() <= totalSupply;
    }

    function _sumBalances() private view returns (uint256) {
        // Implementation to sum balances
        // (simplified - real implementation would iterate all addresses)
        return balanceOf[address(0x10000)] +
               balanceOf[address(0x20000)] +
               balanceOf[address(0x30000)];
    }
}
```

#### 2. Relationship Properties

Properties about relationships between variables:

```solidity
contract Vault {
    uint256 public deposits;
    uint256 public withdrawals;

    function echidna_deposits_gte_withdrawals() public returns (bool) {
        // Property: deposits should always be >= withdrawals
        return deposits >= withdrawals;
    }
}
```

#### 3. Monotonicity Properties

Properties about values that should only increase or decrease:

```solidity
contract TimeLock {
    uint256 public lastActionTime;

    function echidna_time_never_decreases() public returns (bool) {
        // Property: time-based values should be monotonic
        uint256 currentTime = block.timestamp;
        if (lastActionTime > 0) {
            return currentTime >= lastActionTime;
        }
        return true;
    }
}
```

#### 4. Bounded Properties

Properties about values staying within bounds:

```solidity
contract GameLogic {
    uint256 public playerScore;

    function echidna_score_bounded() public returns (bool) {
        // Property: score should stay within game limits
        return playerScore <= 1000000;
    }
}
```

#### 5. Access Control Properties

Properties about authorization:

```solidity
contract Ownable {
    address public owner;
    address private initialOwner;

    constructor() {
        owner = msg.sender;
        initialOwner = msg.sender;
    }

    function echidna_owner_stays_authorized() public returns (bool) {
        // Property: owner should never change to unauthorized address
        return owner == initialOwner || owner == address(this);
    }
}
```

### Using Assertions

If you don't want to write explicit properties, add `assert()` statements to your code:

```solidity
function transfer(address to, uint amount) public {
    require(balanceOf[msg.sender] >= amount, "Insufficient balance");

    uint256 balanceBefore = balanceOf[msg.sender] + balanceOf[to];

    balanceOf[msg.sender] -= amount;
    balanceOf[to] += amount;

    // Echidna will test this assertion
    assert(balanceOf[msg.sender] + balanceOf[to] == balanceBefore);
}
```

## Common Patterns

### Pattern 1: Reentrancy Detection

```solidity
contract ReentrancyTest {
    uint256 private initialBalance;
    bool private locked;

    function echidna_no_reentrancy() public returns (bool) {
        // Property: balance should never decrease while locked
        if (locked) {
            return address(this).balance >= initialBalance;
        }
        return true;
    }

    function setLock(bool _locked) internal {
        locked = _locked;
        if (_locked) {
            initialBalance = address(this).balance;
        }
    }
}
```

### Pattern 2: Integer Overflow Prevention

```solidity
contract OverflowTest {
    uint256 public value;

    function echidna_no_overflow() public returns (bool) {
        // Property: arithmetic operations should not overflow
        uint256 oldValue = value;
        // After any operation:
        return value >= oldValue || value == 0; // Allow wrapping to 0
    }
}
```

### Pattern 3: Access Control Validation

```solidity
contract AccessControlTest {
    address public owner;
    uint256 public adminValue;
    uint256 private lastAdminValue;

    function echidna_admin_value_protected() public returns (bool) {
        // Property: adminValue only changes when called by owner
        if (adminValue != lastAdminValue) {
            bool changedByOwner = msg.sender == owner;
            lastAdminValue = adminValue;
            return changedByOwner;
        }
        return true;
    }
}
```

### Pattern 4: Balance Consistency

```solidity
contract BalanceTest {
    mapping(address => uint256) public balances;

    function echidna_balance_consistency() public returns (bool) {
        // Property: contract balance matches internal accounting
        uint256 totalBalances = balances[address(0x10000)] +
                                balances[address(0x20000)] +
                                balances[address(0x30000)];
        return address(this).balance >= totalBalances;
    }
}
```

### Pattern 5: Gas Limit DoS Prevention

```solidity
contract GasLimitTest {
    address[] public users;

    function echidna_bounded_operations() public returns (bool) {
        // Property: critical operations should complete within gas limits
        uint256 gasBefore = gasleft();
        performCriticalOperation();
        uint256 gasUsed = gasBefore - gasleft();
        return gasUsed < 100000; // Reasonable gas limit
    }

    function performCriticalOperation() internal {
        // Critical operation that should never exceed gas limit
    }
}
```

## Configuration Options

### Basic Configuration

When running Echidna through Apogee, you can configure:

```json
{
  "scanner": "echidna",
  "config": {
    "test_limit": 50000,        // Number of test cases (default: 50,000)
    "timeout": 300,              // Timeout in seconds (default: 5 minutes)
    "solc_version": "0.8.25"     // Solidity compiler version
  }
}
```

### Test Limit Recommendations

| Contract Complexity | Test Limit | Expected Runtime | Coverage |
|---------------------|------------|------------------|----------|
| Simple (< 100 LOC)  | 10,000     | 30-60 seconds    | High     |
| Medium (100-500 LOC)| 50,000     | 2-5 minutes      | High     |
| Complex (> 500 LOC) | 100,000    | 5-10 minutes     | Medium   |
| Critical Systems    | 500,000+   | 30+ minutes      | Very High|

### Advanced Configuration (echidna.yaml)

For custom Echidna configuration, include `echidna.yaml` in your project:

```yaml
# echidna.yaml
testLimit: 50000          # Number of test cases
testMode: assertion       # Test mode: property, assertion, or optimization

# Coverage
coverage: true            # Enable coverage reporting
corpusDir: corpus         # Directory to store successful inputs

# Execution
timeout: 300              # Timeout in seconds
seed: 0                   # Random seed (0 = random)

# Shrinking
shrinkLimit: 5000         # Number of shrinking iterations

# Output
format: json              # Output format: text or json
quiet: false              # Suppress output

# Sequence settings
seqLen: 100               # Maximum sequence length
prefix: setup             # Function to call before each test

# Filtering
filterFunctions:          # Functions to exclude from testing
  - internal_*
  - _helper_*
```

## Understanding Results

### Success (No Issues Found)

```json
{
  "tool": "echidna",
  "summary": {
    "total_files": 1,
    "files_with_issues": 0,
    "total_findings": 0
  },
  "metadata": {
    "test_limit": 50000,
    "tests_passed": 12,
    "coverage": "85%"
  }
}
```

**Interpretation**: All properties passed 50,000 test cases. Your contract is likely sound for the tested properties.

### Property Violation

```json
{
  "findings": [
    {
      "type": "property_violation",
      "severity": "high",
      "message": "Property violated: echidna_balance_never_negative",
      "line": 42,
      "details": {
        "test_name": "echidna_balance_never_negative",
        "counterexample": [
          "deposit(1000000)",
          "withdraw(2000000)"
        ],
        "call_sequence": [
          {
            "function": "deposit",
            "args": ["1000000"],
            "sender": "0x10000",
            "value": "1000000",
            "gas_used": 45231
          },
          {
            "function": "withdraw",
            "args": ["2000000"],
            "sender": "0x10000",
            "value": "0",
            "gas_used": 32145
          }
        ],
        "final_state": {
          "balance": "-1000000",
          "msg.sender": "0x10000"
        }
      }
    }
  ]
}
```

**Interpretation**:
1. **Property**: `echidna_balance_never_negative` failed
2. **Counterexample**: Shows the exact steps to reproduce:
   - Call `deposit(1000000)` first
   - Then call `withdraw(2000000)`
3. **Result**: Balance went negative (-1000000)
4. **Fix**: Add validation to prevent withdrawal > deposit

### Assertion Failure

```json
{
  "findings": [
    {
      "type": "assertion_failure",
      "severity": "high",
      "message": "Assertion failed at line 25",
      "line": 25,
      "details": {
        "assertion": "assert(balanceOf[msg.sender] + balanceOf[to] == balanceBefore)",
        "counterexample": [...],
        "failed_assertion": "Conservation of tokens assertion"
      }
    }
  ]
}
```

**Interpretation**: An `assert()` statement failed, indicating a contract invariant was violated.

## Best Practices

### 1. Start with Simple Properties

Begin with basic invariants before adding complex properties:

```solidity
// Good: Start simple
function echidna_balance_non_negative() public returns (bool) {
    return balance >= 0;
}

// Later: Add complex properties
function echidna_balance_accounting_accurate() public returns (bool) {
    return balance == deposits - withdrawals + interest;
}
```

### 2. Test One Property at a Time

Focus on specific aspects:

```solidity
// Separate properties for different concerns
function echidna_no_overflow() public returns (bool) { ... }
function echidna_no_underflow() public returns (bool) { ... }
function echidna_access_control() public returns (bool) { ... }
```

### 3. Use Assertions for Complex Logic

For internal consistency checks:

```solidity
function transfer(address to, uint amount) public {
    uint balBefore = balanceOf[msg.sender] + balanceOf[to];

    balanceOf[msg.sender] -= amount;
    balanceOf[to] += amount;

    assert(balanceOf[msg.sender] + balanceOf[to] == balBefore);
}
```

### 4. Increase Test Limit for Critical Contracts

For production contracts handling significant value:

```json
{
  "config": {
    "test_limit": 100000,  // 2x default
    "timeout": 600          // 10 minutes
  }
}
```

### 5. Review Counterexamples Carefully

When Echidna finds an issue:
1. **Reproduce Manually**: Follow the exact call sequence
2. **Understand the Root Cause**: Why did the property fail?
3. **Fix the Issue**: Add validation or correct logic
4. **Re-test**: Run Echidna again to verify the fix

### 6. Combine with Static Analysis

Run both for comprehensive coverage:

```bash
# 1. Run static analysis (fast)
curl -X POST .../scans -d '{"scanners": ["slither"]}'

# 2. Run fuzzing (thorough)
curl -X POST .../scans -d '{"scanners": ["echidna"]}'
```

### 7. Use Corpus for Consistency

Save the corpus between runs:

```yaml
# echidna.yaml
corpusDir: corpus         # Directory to store successful inputs
```

This makes subsequent runs faster and more consistent.

## Examples

### Example 1: Token Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleToken {
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;

    // Echidna properties
    function echidna_total_supply_constant() public returns (bool) {
        // Property: total supply should never change
        return totalSupply == 1000000;
    }

    function echidna_conservation_of_tokens() public returns (bool) {
        // Property: sum of balances should not exceed total supply
        uint256 sum = balanceOf[address(0x10000)] +
                      balanceOf[address(0x20000)] +
                      balanceOf[address(0x30000)];
        return sum <= totalSupply;
    }

    function echidna_no_negative_balance() public returns (bool) {
        // Property: balances should never be negative (would overflow to huge number)
        return balanceOf[msg.sender] < totalSupply * 2;
    }
}
```

### Example 2: Crowdsale Contract

```solidity
contract Crowdsale {
    uint256 public weiRaised;
    uint256 public tokensSold;
    uint256 public constant RATE = 100; // 1 ETH = 100 tokens

    function echidna_wei_token_relationship() public returns (bool) {
        // Property: tokens sold should match wei raised * rate
        return tokensSold == weiRaised * RATE;
    }

    function echidna_wei_never_decreases() public returns (bool) {
        // Property: wei raised should only increase
        uint256 current = weiRaised;
        // (Would need to track previous value)
        return true; // Simplified
    }
}
```

### Example 3: Governance Contract

```solidity
contract Governance {
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    struct Proposal {
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
    }

    function echidna_no_double_execution() public returns (bool) {
        // Property: executed proposals should have more votesFor
        for (uint256 i = 0; i < proposalCount; i++) {
            if (proposals[i].executed) {
                if (proposals[i].votesFor <= proposals[i].votesAgainst) {
                    return false;
                }
            }
        }
        return true;
    }
}
```

## FAQ

**Q: Do I need to write properties for Echidna to work?**
A: Not necessarily. Echidna will test all `assert()` statements in your code automatically. However, writing properties gives you better coverage.

**Q: How long should I run Echidna?**
A: For quick checks, 10,000 tests (30-60 seconds) is sufficient. For thorough analysis, use 50,000-100,000 tests (2-10 minutes).

**Q: What if Echidna doesn't find anything?**
A: That's good! It means your properties held for thousands of test cases. But remember:
- Echidna can't test properties you don't write
- Increase test limit for more thorough testing
- Combine with static analysis for complete coverage

**Q: Can Echidna test external calls?**
A: Echidna tests within the contract's execution environment. For testing external integrations, consider integration tests.

**Q: How do I debug failing properties?**
A: Use the counterexample provided in the results. It shows the exact transaction sequence that caused the failure. Reproduce it manually to understand the issue.

**Q: Should I use Echidna in CI/CD?**
A: Yes! Run Echidna as part of your CI pipeline. Use a lower test limit (10,000) for faster feedback, and run longer tests nightly.

**Q: Can Echidna find all bugs?**
A: No fuzzer can find all bugs. Echidna is very good at finding runtime issues and property violations, but it should be combined with:
- Static analysis (Slither, Mythril)
- Manual code review
- Formal verification (for critical systems)

**Q: What's the difference between Echidna and Foundry Fuzz?**
A: Both are fuzzers, but:
- **Echidna**: Property-based, generates transaction sequences, learns from corpus
- **Foundry Fuzz**: Simpler, per-function fuzzing, faster but less sophisticated

Use both for comprehensive testing!

## Resources

- **Echidna Documentation**: https://github.com/crytic/echidna/wiki
- **Trail of Bits Blog**: https://blog.trailofbits.com/tag/echidna/
- **Academic Paper**: "Echidna: effective, usable, and fast fuzzing for smart contracts" (ISSTA 2020)
- **Property-Based Testing Guide**: https://github.com/crytic/building-secure-contracts/tree/master/program-analysis/echidna

## Support

- **Apogee Docs**: https://docs.0xapogee.io
- **Discord**: https://discord.gg/blocksecops
- **Email**: support@0xapogee.com

---

**Last Updated**: 2025-10-13
**Echidna Version**: v2.2.4
**Platform Version**: 0.2.0
