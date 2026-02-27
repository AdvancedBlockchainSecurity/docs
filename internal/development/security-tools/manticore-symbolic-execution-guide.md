# Manticore Symbolic Execution Guide

**Last Updated**: October 13, 2025
**Tool Version**: Manticore v0.3.7
**Applies To**: Solidity smart contracts on Ethereum and EVM-compatible chains

---

## Table of Contents

1. [What is Symbolic Execution?](#what-is-symbolic-execution)
2. [Quick Start](#quick-start)
3. [When to Use Manticore](#when-to-use-manticore)
4. [Understanding Vulnerability Patterns](#understanding-vulnerability-patterns)
5. [Configuration Options](#configuration-options)
6. [Reading Manticore Results](#reading-manticore-results)
7. [Best Practices](#best-practices)
8. [Comparison with Other Tools](#comparison-with-other-tools)
9. [Frequently Asked Questions](#frequently-asked-questions)
10. [Troubleshooting](#troubleshooting)
11. [Additional Resources](#additional-resources)

---

## What is Symbolic Execution?

### The Basics

**Symbolic execution** is a program analysis technique that explores **all possible execution paths** through a program by using **symbolic values** instead of concrete inputs.

Think of it like this:
- **Regular testing**: You test your contract with specific values like `amount = 100`
- **Symbolic execution**: Manticore tests with symbolic values like `amount = α` and explores what happens for ALL possible values of α

### How It Works

```solidity
function withdraw(uint256 amount) public {
    require(balances[msg.sender] >= amount);  // Check 1
    balances[msg.sender] -= amount;           // Operation
    payable(msg.sender).transfer(amount);     // Transfer
}
```

**Traditional Testing**:
- Test with amount = 100: ✓ passes
- Test with amount = 1000: ✗ fails if balance < 1000
- **Problem**: You might miss edge cases

**Symbolic Execution (Manticore)**:
1. Represents `amount` and `balances[msg.sender]` as symbolic variables (α, β)
2. Explores BOTH paths:
   - Path 1: β ≥ α (require passes, withdrawal succeeds)
   - Path 2: β < α (require fails, transaction reverts)
3. For each path, uses Z3 SMT solver to find concrete values that reach that path
4. **Result**: Finds ALL possible behaviors, including edge cases you might miss

### Why Use Symbolic Execution?

✅ **Comprehensive**: Tests all possible execution paths
✅ **Precise**: Finds bugs that fuzzing might miss
✅ **Concrete Exploits**: Generates exact transaction parameters to reproduce bugs
✅ **Mathematical Guarantees**: Proves reachability of code paths

⚠️ **Trade-offs**:
- Slower than fuzzing (minutes to hours vs seconds)
- Memory-intensive (state explosion for complex contracts)
- Best for targeted analysis of critical functions

---

## Quick Start

### Using BlockSecOps Dashboard

1. **Upload your contract** to the BlockSecOps platform
2. **Select Manticore** from the security tools dropdown
3. **Configure analysis depth** (see [Configuration Options](#configuration-options))
4. **Run scan** and wait for results (typically 2-15 minutes)
5. **Review findings** with concrete exploit transactions

### Example: Simple Balance Check

```solidity
// VulnerableBank.sol
pragma solidity ^0.8.0;

contract VulnerableBank {
    mapping(address => uint256) public balances;

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;  // BUG: Integer underflow possible in older Solidity
        payable(msg.sender).transfer(amount);
    }
}
```

**Manticore Analysis**:
1. Explores both paths (sufficient balance / insufficient balance)
2. Checks for integer overflow/underflow in the subtraction
3. Verifies transfer safety
4. Generates test cases for edge conditions

**Expected Result**:
```json
{
  "severity": "HIGH",
  "title": "Potential Integer Underflow",
  "description": "Subtraction operation may underflow if balance manipulation occurs",
  "location": {"file": "VulnerableBank.sol", "line": 12},
  "exploit": {
    "initial_state": "balances[0x123...] = 100",
    "transaction": "withdraw(150)",
    "result": "Underflow: balances becomes 2^256 - 50"
  }
}
```

---

## When to Use Manticore

### Ideal Use Cases

✅ **Critical Financial Logic**
Use Manticore for functions that handle:
- Token transfers and approvals
- Balance calculations and withdrawals
- Collateral management in DeFi protocols
- Auction bidding logic

✅ **Access Control Verification**
Verify that privileged functions:
- Cannot be called by unauthorized users under ANY conditions
- Properly check ownership across all code paths
- Handle edge cases in multi-sig logic

✅ **Complex State Machines**
Analyze contracts with:
- Multiple contract states (e.g., Auction: OPEN → CLOSED → FINALIZED)
- Time-dependent logic (timestamps, deadlines)
- Conditional branches based on external data

✅ **Upgrade Verification**
Before deploying contract upgrades:
- Verify new logic doesn't introduce vulnerabilities
- Check that existing safety properties still hold
- Validate migration functions handle all edge cases

### When NOT to Use Manticore

❌ **Large Contracts** (>500 lines)
- State explosion makes analysis impractical
- **Alternative**: Use Slither for static analysis first

❌ **Gas Optimization**
- Manticore finds security bugs, not gas inefficiencies
- **Alternative**: Use Slither's gas optimization detectors

❌ **Simple Contracts**
- Overkill for straightforward logic
- **Alternative**: Use Slither for fast static analysis

❌ **First-Pass Security Review**
- Too slow for initial comprehensive scanning
- **Alternative**: Run Slither → Mythril → then Manticore for critical functions

---

## Understanding Vulnerability Patterns

Manticore detects 10 major vulnerability classes through symbolic execution. Here's what each means and how to fix it:

### 1. Integer Overflow/Underflow (HIGH)

**What It Is**: Arithmetic operations that wrap around integer boundaries.

**Example**:
```solidity
// VULNERABLE
function withdraw(uint256 amount) public {
    require(balances[msg.sender] >= amount);
    balances[msg.sender] -= amount;  // Can underflow in Solidity <0.8
    msg.sender.transfer(amount);
}
```

**How Manticore Finds It**:
- Symbolically represents `balances[msg.sender]` and `amount`
- Checks if `balances[msg.sender] - amount < 0` (underflow)
- Generates exploit: `withdraw(MAX_UINT256)` when balance is low

**Fix**:
```solidity
// SECURE
function withdraw(uint256 amount) public {
    require(balances[msg.sender] >= amount, "Insufficient balance");
    balances[msg.sender] = balances[msg.sender] - amount;  // Solidity >=0.8 reverts on underflow
    payable(msg.sender).transfer(amount);
}
// Or use SafeMath library for Solidity <0.8
```

---

### 2. Reentrancy Vulnerabilities (CRITICAL)

**What It Is**: External calls that allow attacker to re-enter the function before state is updated.

**Example**:
```solidity
// VULNERABLE
function withdraw(uint256 amount) public {
    require(balances[msg.sender] >= amount);
    msg.sender.call{value: amount}("");  // External call BEFORE state update
    balances[msg.sender] -= amount;      // State update AFTER (reentrancy vulnerability)
}
```

**How Manticore Finds It**:
- Explores execution path where external call triggers callback
- Detects that `balances[msg.sender]` is not updated before external call
- Generates exploit showing recursive withdraw calls

**Fix**:
```solidity
// SECURE (Checks-Effects-Interactions)
function withdraw(uint256 amount) public {
    require(balances[msg.sender] >= amount);
    balances[msg.sender] -= amount;       // State update FIRST
    payable(msg.sender).transfer(amount);  // External interaction LAST
}
```

---

### 3. Unchecked Return Values (HIGH)

**What It Is**: Ignoring return values from external calls, leading to silent failures.

**Example**:
```solidity
// VULNERABLE
function transferTokens(address token, address to, uint256 amount) public {
    IERC20(token).transfer(to, amount);  // Return value ignored
    // Assumes transfer succeeded, but it might have failed
}
```

**How Manticore Finds It**:
- Symbolically explores both success and failure paths
- Detects that failure path continues execution
- Shows state corruption when transfer fails silently

**Fix**:
```solidity
// SECURE
function transferTokens(address token, address to, uint256 amount) public {
    bool success = IERC20(token).transfer(to, amount);
    require(success, "Transfer failed");
}

// Or use OpenZeppelin's SafeERC20
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
using SafeERC20 for IERC20;

function transferTokens(address token, address to, uint256 amount) public {
    IERC20(token).safeTransfer(to, amount);  // Reverts on failure
}
```

---

### 4. Access Control Bypass (CRITICAL)

**What It Is**: Unauthorized users can execute privileged functions through unexpected code paths.

**Example**:
```solidity
// VULNERABLE
contract Vault {
    address public owner;
    bool public initialized;

    function initialize(address _owner) public {
        require(!initialized, "Already initialized");
        owner = _owner;
        initialized = true;
    }

    function withdraw(uint256 amount) public {
        require(msg.sender == owner);  // BUG: Anyone can call initialize first
        payable(msg.sender).transfer(amount);
    }
}
```

**How Manticore Finds It**:
- Explores execution paths from different msg.sender addresses
- Finds path where attacker calls `initialize` to become owner
- Generates exploit: `initialize(attackerAddress)` → `withdraw(balance)`

**Fix**:
```solidity
// SECURE
contract Vault {
    address public immutable owner;

    constructor() {
        owner = msg.sender;  // Set owner in constructor (immutable)
    }

    function withdraw(uint256 amount) public {
        require(msg.sender == owner, "Not owner");
        payable(msg.sender).transfer(amount);
    }
}
```

---

### 5. Uninitialized Storage Pointers (CRITICAL)

**What It Is**: Using uninitialized storage references, allowing arbitrary storage manipulation.

**Example**:
```solidity
// VULNERABLE (Solidity <0.5)
struct User {
    uint256 balance;
    bool active;
}

mapping(address => User) users;

function createUser() public {
    User memory user;  // BUG: Uninitialized, defaults to storage slot 0
    user.balance = 100;  // Overwrites critical storage
}
```

**How Manticore Finds It**:
- Tracks storage slot assignments symbolically
- Detects when uninitialized pointer writes to unexpected slots
- Shows which storage variables get corrupted

**Fix**:
```solidity
// SECURE
function createUser() public {
    User memory user = User({balance: 100, active: true});  // Explicitly initialize
    users[msg.sender] = user;
}

// Modern Solidity (>=0.5) prevents this by requiring explicit initialization
```

---

### 6. Timestamp Dependence (MEDIUM)

**What It Is**: Using `block.timestamp` for critical logic, allowing miner manipulation.

**Example**:
```solidity
// VULNERABLE
function claimReward() public {
    require(block.timestamp >= lastClaim + 1 days, "Too soon");
    rewards[msg.sender] += 100;
    lastClaim = block.timestamp;
}
```

**How Manticore Finds It**:
- Symbolically represents `block.timestamp` as variable controlled by miner
- Shows manipulation: miner advances timestamp to claim early
- Demonstrates reward manipulation scenarios

**Fix**:
```solidity
// SECURE (use block numbers instead)
function claimReward() public {
    require(block.number >= lastClaimBlock + 6500, "Too soon");  // ~1 day at 13s/block
    rewards[msg.sender] += 100;
    lastClaimBlock = block.number;
}

// Or add tolerance for timestamp manipulation (miners can manipulate ~900s)
function claimReward() public {
    require(block.timestamp >= lastClaim + 1 days + 900, "Too soon");  // Add 15min buffer
    rewards[msg.sender] += 100;
    lastClaim = block.timestamp;
}
```

---

### 7. Delegate Call Injection (CRITICAL)

**What It Is**: Using `delegatecall` with user-controlled targets, allowing arbitrary code execution.

**Example**:
```solidity
// VULNERABLE
function executeUpgrade(address implementation, bytes memory data) public {
    require(msg.sender == owner);
    implementation.delegatecall(data);  // BUG: Attacker can supply malicious implementation
}
```

**How Manticore Finds It**:
- Explores paths with different `implementation` addresses
- Shows attacker can pass malicious contract address
- Demonstrates storage manipulation through delegatecall

**Fix**:
```solidity
// SECURE
mapping(address => bool) public approvedImplementations;

function executeUpgrade(address implementation, bytes memory data) public {
    require(msg.sender == owner, "Not owner");
    require(approvedImplementations[implementation], "Not approved");  // Whitelist
    (bool success,) = implementation.delegatecall(data);
    require(success, "Delegatecall failed");
}

function approveImplementation(address implementation) public {
    require(msg.sender == owner);
    approvedImplementations[implementation] = true;
}
```

---

### 8. Transaction Order Dependence (MEDIUM)

**What It Is**: Front-running vulnerabilities where transaction order affects outcomes.

**Example**:
```solidity
// VULNERABLE
mapping(address => uint256) public bids;

function placeBid() public payable {
    require(msg.value > highestBid);
    highestBid = msg.value;
    highestBidder = msg.sender;
}
```

**How Manticore Finds It**:
- Analyzes transaction ordering symbolically
- Shows attacker can observe pending bid and front-run with higher bid
- Demonstrates profit scenarios from front-running

**Fix**:
```solidity
// SECURE (commit-reveal scheme)
mapping(address => bytes32) public commitments;
mapping(address => uint256) public reveals;

function commitBid(bytes32 commitment) public {
    commitments[msg.sender] = commitment;
}

function revealBid(uint256 amount, bytes32 secret) public payable {
    require(keccak256(abi.encodePacked(amount, secret)) == commitments[msg.sender]);
    require(msg.value == amount);
    reveals[msg.sender] = amount;
    // Process bid...
}
```

---

### 9. Denial of Service (MEDIUM)

**What It Is**: Operations that can permanently block contract functionality.

**Example**:
```solidity
// VULNERABLE
address[] public users;

function distribute() public {
    for (uint i = 0; i < users.length; i++) {
        payable(users[i]).transfer(rewards);  // BUG: One failing transfer blocks all
    }
}
```

**How Manticore Finds It**:
- Explores execution with failing external calls
- Shows that single failure blocks entire distribution
- Demonstrates permanent contract lockup scenarios

**Fix**:
```solidity
// SECURE (pull payment pattern)
mapping(address => uint256) public pendingRewards;

function updateRewards() public {
    for (uint i = 0; i < users.length; i++) {
        pendingRewards[users[i]] += rewardAmount;  // Update state
    }
}

function claimReward() public {
    uint256 amount = pendingRewards[msg.sender];
    pendingRewards[msg.sender] = 0;  // Clear before transfer
    payable(msg.sender).transfer(amount);  // User pulls their own reward
}
```

---

### 10. Assert Violations (HIGH)

**What It Is**: Unreachable code or logic errors that violate invariants.

**Example**:
```solidity
// VULNERABLE
function processPayment(uint256 amount) public {
    require(amount > 0);

    uint256 fee = amount / 100;  // 1% fee
    uint256 remaining = amount - fee;

    assert(remaining > amount);  // BUG: This should be "remaining < amount"
}
```

**How Manticore Finds It**:
- Evaluates assert statements symbolically
- Finds concrete inputs where assert fails
- Reveals logic errors and unreachable code

**Fix**:
```solidity
// SECURE
function processPayment(uint256 amount) public {
    require(amount > 0, "Amount must be positive");

    uint256 fee = amount / 100;
    uint256 remaining = amount - fee;

    assert(remaining < amount);  // Correct: remaining is less than original amount
    assert(remaining + fee == amount);  // Invariant: parts equal whole
}
```

---

## Configuration Options

### Analysis Depth

Control how deeply Manticore explores execution paths:

**Quick Scan** (default, 2-5 minutes):
```json
{
  "max_depth": 50,
  "max_states": 100,
  "timeout": 300
}
```
- Good for: Initial vulnerability detection
- Finds: Obvious bugs in shallow code paths
- Use when: Running first security scan

**Standard Scan** (5-15 minutes):
```json
{
  "max_depth": 100,
  "max_states": 500,
  "timeout": 900
}
```
- Good for: Comprehensive analysis of medium-sized contracts
- Finds: Most vulnerabilities including nested conditions
- Use when: Auditing production code

**Deep Scan** (15-60 minutes):
```json
{
  "max_depth": 200,
  "max_states": 2000,
  "timeout": 3600
}
```
- Good for: Critical contracts with complex logic
- Finds: Deep, subtle vulnerabilities in complex paths
- Use when: Maximum confidence needed (DeFi protocols, bridges)

### Function Targeting

Focus analysis on specific critical functions:

```json
{
  "target_functions": ["withdraw", "transfer", "updatePrice"],
  "skip_functions": ["view", "pure"]
}
```

**When to use**:
- Large contracts where full analysis times out
- Critical functions that handle assets or permissions
- Known problematic areas from previous audits

### Memory Limits

Adjust memory allocation for complex contracts:

```json
{
  "memory_limit": "3Gi",  // Default for Manticore in BlockSecOps
  "solver_timeout": 120    // Z3 timeout per query (seconds)
}
```

**Increase memory if**:
- Analysis terminates early with "out of memory" errors
- Contract has very large storage structures
- Deep nested loops or recursion

---

## Reading Manticore Results

### Result Structure

```json
{
  "tool": "manticore",
  "version": "0.3.7",
  "scan_time": "2025-10-13T10:30:00Z",
  "contract": "VulnerableBank.sol",
  "summary": {
    "states_explored": 847,
    "paths_completed": 215,
    "unique_bugs": 3,
    "analysis_time_seconds": 423
  },
  "findings": [
    {
      "severity": "CRITICAL",
      "type": "reentrancy",
      "title": "Reentrancy in withdraw function",
      "description": "External call to user-controlled address before state update allows reentrancy attack",
      "location": {
        "contract": "VulnerableBank",
        "function": "withdraw",
        "line": 45,
        "column": 8
      },
      "exploit": {
        "description": "Attacker can recursively call withdraw before balance is updated",
        "steps": [
          "1. Attacker deposits 1 ETH",
          "2. Attacker calls withdraw(1 ETH)",
          "3. In fallback, attacker calls withdraw(1 ETH) again",
          "4. Repeat until contract drained"
        ],
        "test_case": {
          "initial_state": "attacker_balance = 1 ETH, contract_balance = 10 ETH",
          "transactions": [
            {"from": "attacker", "to": "VulnerableBank", "function": "deposit", "value": "1 ETH"},
            {"from": "attacker", "to": "VulnerableBank", "function": "withdraw", "args": ["1 ETH"]}
          ],
          "final_state": "attacker_balance = 10 ETH, contract_balance = 0 ETH"
        }
      },
      "recommendation": "Move state update before external call (Checks-Effects-Interactions pattern)"
    }
  ]
}
```

### Understanding Severity Levels

**CRITICAL** 🔴
- **Definition**: Direct loss of funds or complete contract takeover
- **Examples**: Reentrancy, access control bypass, arbitrary code execution
- **Action**: Fix immediately before deployment

**HIGH** 🟠
- **Definition**: Significant vulnerabilities that could lead to loss under specific conditions
- **Examples**: Integer overflow, unchecked returns, uninitialized storage
- **Action**: Fix before production deployment

**MEDIUM** 🟡
- **Definition**: Potential issues that could be exploited in certain scenarios
- **Examples**: Timestamp dependence, front-running, DoS conditions
- **Action**: Evaluate risk and fix if applicable

**LOW** 🟢
- **Definition**: Minor issues or best practice violations
- **Examples**: Logic errors in non-critical paths, inefficient patterns
- **Action**: Consider fixing for code quality

### Interpreting Test Cases

Manticore provides **concrete exploit scenarios**:

```json
"test_case": {
  "initial_state": "balances[attacker] = 100, balances[victim] = 1000",
  "transactions": [
    {"function": "approve", "args": ["attacker", "100"]},
    {"function": "transferFrom", "args": ["victim", "attacker", "2000"]}
  ],
  "final_state": "balances[victim] = UNDERFLOW (-900)"
}
```

**How to use this**:
1. **Reproduce locally**: Run exact sequence on test network
2. **Verify fix**: Ensure patched code prevents exploit
3. **Document**: Include in security audit report
4. **Test coverage**: Add test case to prevent regression

---

## Best Practices

### 1. Use Manticore as Part of Layered Defense

```
Security Analysis Pipeline:
┌─────────────┐
│   Slither   │ → Static analysis (fast, 30s)
└──────┬──────┘
       ↓
┌─────────────┐
│   Mythril   │ → Symbolic execution (medium, 5min)
└──────┬──────┘
       ↓
┌─────────────┐
│  Manticore  │ → Deep symbolic execution (slow, 15min)
└──────┬──────┘
       ↓
┌─────────────┐
│   Echidna   │ → Property-based fuzzing (30min - 24h)
└─────────────┘
```

**Why this order?**
1. **Slither** catches obvious bugs instantly
2. **Mythril** finds most symbolic execution issues faster
3. **Manticore** provides deepest analysis for critical code
4. **Echidna** tests runtime properties with fuzzing

### 2. Target Critical Functions

Don't run Manticore on entire large contracts:

```solidity
// ✅ GOOD: Analyze critical functions
manticore --target withdraw,transferOwnership,upgrade MyContract.sol

// ❌ BAD: Analyze entire large contract (will timeout)
manticore LargeContract.sol
```

### 3. Use Properties to Guide Analysis

Add assertions to check security properties:

```solidity
contract SecureVault {
    mapping(address => uint256) public balances;

    function withdraw(uint256 amount) public {
        uint256 balanceBefore = balances[msg.sender];

        require(balances[msg.sender] >= amount);
        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);

        // Property: Balance should decrease by exactly amount
        assert(balances[msg.sender] == balanceBefore - amount);
    }
}
```

Manticore will verify this property holds across ALL execution paths.

### 4. Optimize for Analysis

**Reduce state space**:

```solidity
// ❌ BAD: Unbounded loops
for (uint i = 0; i < users.length; i++) {  // Unknown length
    process(users[i]);
}

// ✅ GOOD: Bounded loops
for (uint i = 0; i < min(users.length, 100); i++) {  // Max 100 iterations
    process(users[i]);
}
```

**Limit external dependencies**:

```solidity
// ❌ BAD: Complex external calls
IERC20(unknownToken).transferFrom(user, address(this), amount);

// ✅ GOOD: Mock external contracts for analysis
function transferFromMock(address token, address from, uint256 amount) internal {
    // Simplified logic for symbolic execution
}
```

### 5. Iterative Analysis

For large contracts:

1. **First pass**: Analyze individual functions
2. **Second pass**: Analyze function interactions
3. **Third pass**: Full contract with increased depth
4. **Validate**: Use Echidna for long-running fuzzing

---

## Comparison with Other Tools

### Manticore vs Slither

| Feature | Manticore | Slither |
|---------|-----------|---------|
| **Type** | Symbolic Execution | Static Analysis |
| **Speed** | Slow (5-60 min) | Fast (10-30 sec) |
| **Accuracy** | Very High (concrete exploits) | High (some false positives) |
| **Coverage** | All execution paths | All code patterns |
| **Best For** | Critical functions, deep analysis | First-pass scan, large contracts |
| **Output** | Exploit test cases | Vulnerability patterns |

**Use Both**: Slither first for breadth, Manticore for depth on critical code.

---

### Manticore vs Mythril

| Feature | Manticore | Mythril |
|---------|-----------|---------|
| **Approach** | Deep path exploration | Faster heuristic search |
| **Depth** | Very Deep (configurable) | Moderate |
| **Speed** | Slower | Faster (2-10 min) |
| **Memory** | High (3Gi) | Lower (2Gi) |
| **Best For** | Maximum thoroughness | Balanced speed/depth |
| **Z3 Usage** | Extensive | Moderate |

**Use Both**: Mythril for most contracts, Manticore for critical financial logic.

---

### Manticore vs Echidna

| Feature | Manticore | Echidna |
|---------|-----------|---------|
| **Method** | Symbolic Execution | Property-Based Fuzzing |
| **Coverage** | ALL paths (guaranteed) | Random sampling (probabilistic) |
| **Speed** | Slow (one-time) | Fast (continuous) |
| **Setup** | Automatic | Requires property functions |
| **Best For** | Proving absence of bugs | Finding tricky runtime bugs |
| **Integration** | CI/CD friendly | Long-running test suite |

**Use Both**: Manticore proves properties, Echidna finds unexpected violations.

---

## Frequently Asked Questions

### Q1: How long does Manticore analysis take?

**Answer**: Depends on contract complexity:
- **Simple contracts** (< 100 lines): 2-5 minutes
- **Medium contracts** (100-300 lines): 5-15 minutes
- **Complex contracts** (> 300 lines): 15-60 minutes

For large contracts, use `--target` to analyze critical functions only.

---

### Q2: Why is Manticore using so much memory?

**Answer**: Symbolic execution tracks ALL possible program states, which grows exponentially with:
- Nested loops
- Conditional branches
- External contract interactions
- Large storage structures

**Solutions**:
1. Reduce `max_depth` and `max_states`
2. Target specific functions
3. Simplify complex logic for analysis
4. Use Manticore for critical code only, Slither for full contract

---

### Q3: What does "state explosion" mean?

**Answer**: Each conditional branch creates new symbolic state:

```solidity
if (a > 10) {        // State splits: [a > 10] and [a ≤ 10]
    if (b < 5) {     // Each state splits again: 4 total states
        if (c == 0) { // 8 total states
            // ...
        }
    }
}
```

With 20 branches, you get 2^20 = 1,048,576 states (state explosion).

**Mitigation**: Reduce branches, bound loops, target critical functions.

---

### Q4: Can Manticore analyze proxy contracts?

**Answer**: Yes, but with configuration:

```json
{
  "follow_delegatecall": true,
  "include_implementation": "0x123...implementation_address"
}
```

Manticore will analyze the implementation contract through the proxy.

---

### Q5: Does Manticore work with upgradeable contracts?

**Answer**: Yes, analyze each version separately:

1. Analyze original implementation
2. Analyze upgraded implementation
3. Verify upgrade function safety
4. Compare results to ensure no new vulnerabilities

---

### Q6: What's the difference between Manticore and formal verification?

**Answer**:

**Manticore (Symbolic Execution)**:
- Explores execution paths to find bugs
- Generates concrete exploits
- Finds violations of implicit properties

**Formal Verification (e.g., Certora, Move Prover)**:
- Proves explicit properties mathematically
- Requires specification language
- Provides mathematical guarantees

**Use both** for critical systems: Manticore finds bugs, formal verification proves correctness.

---

### Q7: Can Manticore detect all vulnerabilities?

**Answer**: **No tool is perfect**. Manticore excels at:
- ✅ Path-dependent bugs (reentrancy, integer issues)
- ✅ Logic errors with concrete exploits
- ✅ Access control bypasses

Manticore struggles with:
- ❌ Very complex contracts (state explosion)
- ❌ Business logic bugs (requires understanding intent)
- ❌ Off-chain vulnerabilities (oracles, API attacks)

**Always use multiple tools and manual review.**

---

### Q8: How do I interpret Z3 timeout errors?

**Answer**: Z3 is the constraint solver Manticore uses. Timeouts mean:
- Path constraints are too complex to solve quickly
- Increase `solver_timeout` in config
- Or reduce analysis depth to simplify constraints

```json
{
  "solver_timeout": 240  // Increase from default 120s
}
```

---

### Q9: Can I run Manticore locally?

**Answer**: Yes, but BlockSecOps platform is recommended:

**Local Installation**:
```bash
pip3 install manticore[native]
manticore --detect-all MyContract.sol
```

**BlockSecOps Platform Advantages**:
- Pre-configured optimal settings
- Kubernetes-managed resources (3Gi memory)
- Standardized JSON output
- Integrated with other security tools
- Automatic result aggregation

---

### Q10: What Solidity versions does Manticore support?

**Answer**: Manticore v0.3.7 supports:
- ✅ Solidity 0.4.x - 0.8.x (full support)
- ✅ Multiple files and imports
- ✅ OpenZeppelin contracts
- ✅ Proxy patterns (UUPS, Transparent)

Use `solc-select` to match compiler version:
```bash
solc-select install 0.8.20
solc-select use 0.8.20
```

---

## Troubleshooting

### Issue 1: Analysis Times Out

**Symptoms**:
```
Error: Maximum analysis time exceeded (900s)
States explored: 2847
Paths completed: 142/3000
```

**Solutions**:
1. Reduce `max_depth` from 100 to 50
2. Target specific functions: `--target criticalFunction`
3. Simplify contract logic (remove unnecessary branches)
4. Use Standard Scan instead of Deep Scan

---

### Issue 2: Out of Memory

**Symptoms**:
```
Error: Memory limit exceeded (3Gi)
States in queue: 15432
```

**Solutions**:
1. Reduce `max_states` from 500 to 250
2. Bound loops to fixed iterations
3. Analyze functions individually
4. Contact support for increased memory allocation (enterprise)

---

### Issue 3: No Vulnerabilities Found (False Negatives)

**Symptoms**:
- Contract known to have issues
- Manticore reports zero findings

**Possible Causes**:
1. **Depth too shallow**: Increase `max_depth`
2. **Bug in unreachable code**: Check Slither's unreachable code detector
3. **Business logic bug**: Manticore finds technical bugs, not design flaws
4. **External dependencies**: Mock external contracts for analysis

**Solutions**:
- Add `assert()` statements to check properties
- Use Echidna for complementary fuzzing
- Review with manual audit

---

### Issue 4: Too Many False Positives

**Symptoms**:
- Manticore reports vulnerabilities that aren't exploitable
- Exploit test cases don't reproduce in reality

**Possible Causes**:
1. **Symbolic assumptions differ from reality**: External contract behavior
2. **EVM semantics**: Edge cases in gas, gas limits, etc.

**Solutions**:
- Verify each finding manually with test case
- Add constraints to model real-world behavior
- Use `--avoid-constant` to reduce unrealistic paths

---

### Issue 5: Z3 Solver Crashes

**Symptoms**:
```
Error: Z3 solver crashed
Path constraints: 1847 conditions
```

**Solutions**:
1. Reduce path complexity by targeting specific functions
2. Increase `solver_timeout`
3. Update Z3 to latest version (handled automatically in BlockSecOps)
4. Report to support with contract sample

---

## Additional Resources

### Official Documentation

- **Manticore GitHub**: https://github.com/trailofbits/manticore
- **Trail of Bits Blog**: https://blog.trailofbits.com (Manticore case studies)
- **Z3 Theorem Prover**: https://github.com/Z3Prover/z3

### BlockSecOps Resources

- **Security Tools Overview**: `/development/security-tools-overview.md`
- **Echidna Fuzzing Guide**: `/development/echidna-fuzzing-guide.md`
- **Plugin SDK Guide**: `/development/plugin-sdk-guide.md`
- **Multi-Language Support**: `/architecture/multi-language-support.md`

### Academic Papers

- **Symbolic Execution for Software Testing**: https://dl.acm.org/doi/10.1145/1290520.1290545
- **KLEE Symbolic Execution Engine**: https://www.usenix.org/legacy/event/osdi08/tech/full_papers/cadar/cadar.pdf
- **Z3 SMT Solver**: https://theory.stanford.edu/~nikolaj/programmingz3.html

### Community

- **BlockSecOps Discord**: Security tool discussions and support
- **Trail of Bits Slack**: Manticore-specific questions
- **Ethereum Security**: https://github.com/ethereum/security

---

## Getting Help

### BlockSecOps Support

- **Email**: support@0xapogee.com
- **Discord**: https://discord.gg/blocksecops
- **Documentation**: https://docs.0xapogee.com

### Reporting Bugs

- **Manticore Issues**: https://github.com/trailofbits/manticore/issues
- **Platform Issues**: support@0xapogee.com

### Feature Requests

Have ideas for improving Manticore integration? Contact us:
- **Email**: features@0xapogee.com
- **Feedback Form**: https://0xapogee.com/feedback

---

**Document Version**: 1.0
**Last Updated**: October 13, 2025
**Maintained By**: BlockSecOps Security Team
