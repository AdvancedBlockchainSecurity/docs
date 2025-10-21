# Scanner Result Types Guide

**Last Updated**: 2025-10-19

## Overview

BlockSecOps provides comprehensive smart contract analysis through multiple specialized scanners. Each scanner produces different types of results beyond traditional security vulnerabilities. This guide explains the different result types and how to interpret them.

## Result Type Categories

### 1. Vulnerabilities (Traditional Security Issues)

**What it is**: Security vulnerabilities, bugs, and potential exploits in your smart contract code.

**When to use**: Always check vulnerabilities first - these represent security risks that could lead to loss of funds or contract compromise.

**Scanners that provide this**:
- **Solidity**: slither, mythril, aderyn, semgrep
- **Vyper**: vyper
- **Solana/Rust**: sol-azy, sec3-xray
- **Move**: (detected by move-prover side effects)
- **Cairo/StarkNet**: tayt, caracal, starknet-foundry

**Example findings**:
- Reentrancy vulnerabilities
- Integer overflow/underflow
- Unprotected ether withdrawal
- Delegatecall to untrusted contract
- Front-running opportunities

**How to interpret**:
- **Critical/High severity**: Fix immediately before deployment
- **Medium severity**: Should be addressed, may pose risk in certain scenarios
- **Low severity**: Consider fixing for best practices
- **Informational**: Good to know, may not be exploitable

---

### 2. Code Quality

**What it is**: Code style issues, best practices violations, and maintainability concerns.

**When to use**: After addressing security vulnerabilities, review code quality to improve readability, maintainability, and follow Solidity best practices.

**Scanners that provide this**:
- solhint (Solidity linter)
- semgrep (pattern-based static analysis)
- 4naly3er (advanced code quality analyzer)

**Example findings**:
- Missing NatSpec comments
- Use of deprecated Solidity features
- Inconsistent naming conventions
- Unnecessary public visibility
- Complex function logic (high cyclomatic complexity)
- Missing error messages in require statements

**Severity levels**:
- **Warning**: Should be addressed (e.g., use of tx.origin)
- **Info**: Informational (e.g., missing documentation)
- **Suggestion**: Recommendations for improvement (e.g., use newer Solidity syntax)

**Categories**:
- `security`: Security-related best practices
- `best-practices`: General coding best practices
- `naming`: Naming convention violations
- `documentation`: Missing or poor documentation
- `gas-optimization`: Simple gas optimization suggestions
- `complexity`: Code complexity issues

**How to interpret**:
- Code quality issues don't directly cause security vulnerabilities but can lead to bugs
- Well-written code is easier to audit and maintain
- Following best practices reduces the chance of introducing bugs in future changes

---

### 3. Gas Analysis

**What it is**: Opportunities to optimize your contract's gas consumption and reduce transaction costs.

**When to use**: After ensuring security and code quality, optimize gas usage to reduce costs for your users.

**Scanners that provide this**:
- slither (with gas optimization detectors enabled)

**Example findings**:
- Cache array length in loops
- Use `calldata` instead of `memory` for function parameters
- Pack struct variables to save storage slots
- Use `uint256` instead of smaller uints (cheaper in many cases)
- Avoid unnecessary storage reads/writes
- Use events instead of storage for historical data
- Batch operations to reduce transaction overhead

**Optimization levels**:
- **Critical**: High-impact optimizations (save >1000 gas per call)
- **High**: Significant savings (500-1000 gas per call)
- **Medium**: Moderate savings (100-500 gas per call)
- **Low**: Minor savings (<100 gas per call)

**What's included**:
- Current gas cost estimate
- Potential gas savings amount
- Percentage reduction
- Code example showing before/after
- Explanation of why it saves gas

**How to interpret**:
- Focus on critical and high-priority optimizations first
- Consider gas savings vs. code readability trade-offs
- Optimize hot paths (frequently called functions) more aggressively
- Calculate total savings across expected usage patterns

---

### 4. Formal Verification

**What it is**: Mathematical proofs that certain properties of your contract always hold true (or counterexamples showing they don't).

**When to use**: For high-value contracts or critical business logic where mathematical certainty is required.

**Scanners that provide this**:
- certora (Certora Prover)
- halmos (Symbolic testing for Foundry)
- move-prover (Move language formal verification)

**What gets verified**:
- **Invariants**: Properties that should always be true
  - Example: "Total supply equals sum of all balances"
  - Example: "Contract balance >= sum of user deposits"

- **Assertions**: Explicit checks in your code
  - Example: `assert(balance[user] >= amount)`

- **Properties**: Custom specifications
  - Example: "Transfer never increases total supply"
  - Example: "Only owner can mint tokens"

**Verification statuses**:
- **Proven**: Property mathematically verified to always hold ✅
- **Failed**: Counterexample found showing property can be violated ❌
- **Timeout**: Verification took too long (increase timeout or simplify property)
- **Unknown**: Verifier couldn't determine result (may need stronger preconditions)

**How to interpret**:
- **Proven properties**: High confidence in correctness
- **Failed properties**: Critical issue found - review the counterexample
  - Counterexamples show exact sequence of calls that violate the property
  - May reveal edge cases not caught by traditional testing
- **Timeout/Unknown**: May need to adjust verification configuration or simplify the property

**Best practices**:
- Start with simple invariants
- Verify critical business logic first
- Use counterexamples to write targeted unit tests
- Formal verification complements but doesn't replace testing

---

### 5. Fuzzing Results

**What it is**: Results from automated random testing that tries many different inputs to find edge cases and unexpected behavior.

**When to use**: Throughout development to discover edge cases and increase confidence in contract robustness.

**Scanners that provide this**:
- **Solidity**: echidna, foundry-fuzz, medusa, moccasin
- **Solana/Rust**: trident, cargo-fuzz-solana
- **Move**: cargo-fuzz-move
- **Cairo/StarkNet**: starknet-foundry

**What gets tested**:
- Property-based tests (invariants that should hold for any input)
- Assertion tests (explicit checks in test code)
- State machine testing (valid state transitions)
- Edge case discovery (extreme values, unexpected combinations)

**Test statuses**:
- **Passed**: Test executed successfully across all random inputs ✅
- **Failed**: Test found an input that violates the property ❌
- **Error**: Test encountered execution error (e.g., out of gas)

**What's included**:
- Number of executions (how many random inputs were tried)
- Code coverage percentage (how much code was exercised)
- Edge cases found (interesting inputs discovered)
- Failure traces (exact sequence of operations that caused failure)
- Random seed (for reproducing the exact test run)

**How to interpret**:
- **High coverage (>80%)**: Good confidence in test thoroughness
- **Low coverage (<50%)**: May need more test cases or better input generation
- **Passed with edge cases found**: Review edge cases - they might reveal important scenarios
- **Failed tests**: Critical - indicates a property violation
  - Review the failure trace to understand what happened
  - Create a unit test reproducing the failure
  - Fix the issue and re-run fuzzing
- **Error tests**: May indicate gas issues or precondition violations

**Best practices**:
- Run fuzzing for at least 10,000 executions
- Aim for >80% code coverage
- Use edge cases found to create targeted unit tests
- Re-run fuzzing after fixing issues to ensure they're resolved

---

## Scanner Coverage by Blockchain Platform

### Ethereum/Solidity Contracts

| Result Type | Available Scanners |
|------------|-------------------|
| Vulnerabilities | slither, mythril, aderyn, semgrep |
| Code Quality | solhint, semgrep, 4naly3er |
| Gas Analysis | slither |
| Formal Verification | certora, halmos |
| Fuzzing | echidna, foundry-fuzz, medusa, moccasin |

### Vyper Contracts

| Result Type | Available Scanners |
|------------|-------------------|
| Vulnerabilities | vyper |
| Code Quality | N/A |
| Gas Analysis | N/A |
| Formal Verification | N/A |
| Fuzzing | N/A |

### Solana/Rust Programs

| Result Type | Available Scanners |
|------------|-------------------|
| Vulnerabilities | sol-azy, sec3-xray |
| Code Quality | N/A |
| Gas Analysis | N/A |
| Formal Verification | N/A |
| Fuzzing | trident, cargo-fuzz-solana |

### Move Smart Contracts (Aptos/Sui)

| Result Type | Available Scanners |
|------------|-------------------|
| Vulnerabilities | (via move-prover) |
| Code Quality | N/A |
| Gas Analysis | N/A |
| Formal Verification | move-prover |
| Fuzzing | cargo-fuzz-move |

### Cairo/StarkNet Contracts

| Result Type | Available Scanners |
|------------|-------------------|
| Vulnerabilities | tayt, caracal, starknet-foundry |
| Code Quality | N/A |
| Gas Analysis | N/A |
| Formal Verification | N/A |
| Fuzzing | starknet-foundry |

---

## Recommended Analysis Workflow

### 1. Quick Security Check (5-10 minutes)
Run fast scanners to catch obvious issues:
- **Slither** (vulnerabilities + gas analysis)
- **Solhint** (code quality)
- **Foundry-fuzz** (basic fuzzing, 1000 runs)

### 2. Comprehensive Analysis (30-60 minutes)
For contracts approaching deployment:
- **Mythril** or **Aderyn** (deep vulnerability analysis)
- **Semgrep** (pattern-based security and quality checks)
- **Echidna** or **Medusa** (extended fuzzing, 50,000+ runs)

### 3. Pre-Deployment Verification (hours to days)
For high-value contracts:
- **Certora** or **Halmos** (formal verification of critical properties)
- **Manticore** (symbolic execution for complex state exploration)
- **Extended fuzzing** (100,000+ runs with custom invariants)

### 4. Continuous Monitoring
On every code change:
- Re-run quick security checks
- Verify previously proven properties still hold
- Ensure code quality standards are maintained

---

## Understanding Result Prioritization

Results are automatically prioritized in the UI:

1. **Vulnerabilities by Severity**
   - Critical → High → Medium → Low → Informational

2. **Code Quality by Severity**
   - Warning → Info → Suggestion

3. **Gas Analysis by Optimization Level**
   - Critical → High → Medium → Low
   - Then by potential savings (highest first)

4. **Formal Verification by Status**
   - Failed → Proven → Timeout → Unknown
   - (Failed properties shown first as they need attention)

5. **Fuzzing by Status**
   - Failed → Error → Passed
   - Then by coverage (highest first)

---

## Tips for Effective Analysis

### Start Simple
- Don't run all scanners at once initially
- Start with fast tools (slither, solhint)
- Add more comprehensive tools as needed

### Understand Your Contract
- Different contracts need different analysis approaches
- DeFi protocols: Focus on economic invariants and formal verification
- NFT contracts: Focus on access control and enumeration
- Upgradeable contracts: Verify storage layout and initialization

### Iterate and Improve
- Fix critical issues first
- Re-run analysis after each fix
- Gradually improve code quality and gas efficiency
- Add formal properties as you understand contract behavior better

### Use Results Together
- Vulnerabilities tell you what's broken
- Code quality tells you what could break
- Gas analysis tells you what's expensive
- Formal verification proves what's correct
- Fuzzing finds what you didn't expect

### Don't Ignore Low-Severity Issues
- Low-severity issues can combine into critical vulnerabilities
- Code quality issues make future bugs more likely
- Small gas optimizations add up

---

## FAQ

**Q: Which result type is most important?**
A: Vulnerabilities are always the top priority. However, all result types provide value:
- Security comes first
- Code quality prevents future bugs
- Gas optimization saves user money
- Formal verification provides mathematical certainty
- Fuzzing discovers unexpected behavior

**Q: Should I fix all findings?**
A: Not necessarily. Prioritize based on:
- Severity (critical/high first)
- Exploitability (can it be triggered?)
- Impact (what happens if exploited?)
- Cost/benefit (time to fix vs. benefit gained)

**Q: How do I know if my contract is secure?**
A: No single metric guarantees security, but positive indicators include:
- Zero critical/high vulnerabilities
- Important properties formally verified
- High fuzzing coverage (>80%) with all tests passing
- Code quality warnings addressed
- Gas-optimized for common operations

**Q: Why do different scanners report different issues?**
A: Each scanner uses different techniques:
- Static analysis (pattern matching, control flow)
- Dynamic analysis (symbolic execution, concrete execution)
- Formal methods (mathematical proofs)
- Different scanners have different detection capabilities

**Q: What should I do with failed formal verification?**
A: Review the counterexample carefully:
1. Understand the sequence of operations that caused the failure
2. Determine if it's a real issue or an overly strict property
3. If real: Fix the contract logic
4. If overly strict: Refine the property specification
5. Re-run verification

**Q: How long should fuzzing run?**
A: Depends on contract complexity and risk:
- Simple contracts: 10,000 runs
- Production contracts: 50,000-100,000 runs
- High-value DeFi: 1,000,000+ runs over days

---

## Getting Help

If you need assistance interpreting scanner results:

1. **Check Scanner Documentation**: Each scanner has detailed docs explaining their findings
2. **Review Examples**: Look at the example findings in this guide
3. **Ask the Community**: BlockSecOps Discord/Forum for specific questions
4. **Professional Audit**: For high-value contracts, consider a professional audit

---

## Related Documentation

- [API Documentation](/blocksecops-docs/api/scanner-results-api.md)
- [Scanner Selection Guide](/docs/user-guide/scanner-selection-guide.md)
- [Database Schema](/docs/database/SCHEMA.md)
