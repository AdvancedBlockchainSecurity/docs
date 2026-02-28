# Scanner Selection User Guide

**Last Updated**: December 22, 2025
**Version**: 1.1

---

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Scan Profiles](#scan-profiles)
4. [Available Scanners](#available-scanners)
5. [Custom Scanner Selection](#custom-scanner-selection)
6. [Understanding Scanner Categories](#understanding-scanner-categories)
7. [Best Practices](#best-practices)
8. [FAQs](#faqs)

---

## Overview

Apogee provides a comprehensive suite of security scanning tools to analyze your smart contracts. The scanner selection interface allows you to choose which tools to run based on your needs, time constraints, and the specific vulnerabilities you want to detect.

### What You'll Learn

- How to start a security scan on your contract
- The difference between Quick, Standard, and Deep scans
- How to select specific scanners for custom analysis
- Which scanners are best for different types of vulnerabilities

---

## Quick Start

### Starting Your First Scan (30 seconds)

1. **Navigate to your contract**
   - Go to the "Contracts" page in the dashboard
   - Click on the contract you want to scan

2. **Open the scanner selection modal**
   - Click the **"Configure & Start Scan"** button
   - The scanner configuration modal will open

3. **Choose a scan profile**
   - For your first scan, we recommend **"Standard Scan"**
   - This provides comprehensive coverage in ~5 minutes

4. **Start the scan**
   - Click the **"Start Scan"** button
   - The scan will begin immediately
   - Track progress in the "Recent Scans" section

**That's it!** Your scan is now running. Results will appear on the contract detail page when complete.

### Automatic Scanner Selection (New in v1.1)

When you trigger a quick scan from the Contracts list, the dashboard automatically selects the appropriate scanner based on your contract's language:

| Contract Language | Default Scanner |
|-------------------|-----------------|
| Solidity (.sol) | SolidityDefend |
| Vyper (.vy) | Vyper |
| Rust/Solana (.rs) | Sol-azy |

This ensures you always get relevant security analysis without needing to manually configure scanner selection.

---

## Scan Profiles

Apogee offers four preset scan profiles to match different use cases:

### Quick Scan (~2 minutes)

**Best for**:
- First-time scans to get basic security coverage
- Pre-deployment quick checks
- Continuous Integration (CI) pipelines
- Daily development testing

**What it includes**:
- Essential static analyzers (Slither, Aderyn, Semgrep)
- Code linting (Solhint)
- ~8 fast-running tools

**Coverage**:
- Common vulnerabilities (reentrancy, access control, arithmetic issues)
- Code quality issues
- Style and best practice violations

### Standard Scan (~5 minutes)

**Best for**:
- Regular security audits during development
- Pre-staging deployments
- Balanced speed and coverage

**What it includes**:
- All Quick Scan tools
- Advanced static analyzers (Mythril, 4naly3er)
- Fuzzing tools (Echidna, Moccasin, Trident)
- ~16 comprehensive tools

**Coverage**:
- Everything in Quick Scan
- Deep state-related vulnerabilities
- Edge cases discovered through fuzzing
- Gas optimization opportunities

### Deep Scan (~15 minutes)

**Best for**:
- Final pre-production security audit
- High-value contracts (DeFi protocols, NFT marketplaces)
- Preparing for public security audits
- Maximum vulnerability detection

**What it includes**:
- All Standard Scan tools
- Symbolic execution (Halmos)
- Formal verification (Move Prover for Move contracts)
- **All available tools** for your contract's language

**Coverage**:
- Everything in Standard Scan
- Complex logic vulnerabilities
- Mathematical proof of correctness
- Rare edge cases in state transitions

### Custom Scan (Variable time)

**Best for**:
- Targeting specific vulnerability types
- Re-running failed tools from previous scans
- Testing after specific code changes
- Advanced users who know which tools they need

**What it includes**:
- Any combination of available tools
- You choose exactly which scanners to run

**Coverage**:
- Depends on your tool selection

---

## Available Scanners

The platform provides security scanners across 3 smart contract ecosystems:

### Solidity (9 scanners)

| Scanner | Type | Runtime | Best For |
|---------|------|---------|----------|
| **SolidityDefend** | Static Analysis | ~20s | Comprehensive detection (204+ patterns) - Default for quick scans |
| **Slither** | Static Analysis | ~15s | Comprehensive vulnerability detection (90+ checks) |
| **Aderyn** | Static Analysis | ~20s | Rust-based static analysis, fast and accurate |
| **Mythril** | Static Analysis | ~3min | Deep analysis using symbolic execution |
| **Semgrep** | Static Analysis | ~10s | Pattern-based detection with custom rules |
| **Solhint** | Linting | ~5s | Code style and best practices |
| **Wake** | Static Analysis | ~12s | Gas optimization and efficiency analysis |
| **Halmos** | Symbolic Execution | ~2min | Symbolic testing of contract properties |
| **Echidna** | Fuzzing | ~3min | Property-based fuzzing for edge cases |

### Vyper (2 scanners)

| Scanner | Type | Runtime | Best For |
|---------|------|---------|----------|
| **Slither (Vyper)** | Static Analysis | ~15s | Vyper-specific vulnerability detection |
| **Moccasin** | Fuzzing | ~2min | Titanoboa-based fuzzing for Vyper |

### Rust/Solana (4 scanners)

| Scanner | Type | Runtime | Best For |
|---------|------|---------|----------|
| **Sol-azy** | Static Analysis | ~25s | Solana program security analysis |
| **Sec3 X-Ray** | Static Analysis | ~30s | Comprehensive Solana security scanner |
| **Trident** | Fuzzing | ~4min | Fuzzing framework for Solana programs |
| **cargo-fuzz** | Fuzzing | ~5min | LibFuzzer-based fuzzing for Rust/Solana |

### Additional Languages

> **Note**: Move and Cairo/StarkNet scanners have been deprecated as of December 2025. The platform now focuses on Solidity, Vyper, and Rust/Solana ecosystems.

---

## Custom Scanner Selection

### When to Use Custom Selection

Use custom scanner selection when you:
- Want to focus on specific vulnerability types (e.g., only reentrancy checks)
- Need to re-run specific tools after code changes
- Have time constraints (select only fast scanners)
- Are investigating a specific issue found in a previous scan

### How to Select Custom Scanners

1. **Open the scanner configuration modal**
   - Click "Configure & Start Scan" on your contract

2. **Click the "Custom" preset**
   - This allows manual tool selection

3. **Select scanners individually**
   - Click the checkbox on each tool card to enable/disable
   - Selected tools will show a blue checkmark

4. **Use filters to find scanners**
   - **Search**: Type tool name or keyword (e.g., "fuzzing")
   - **Category**: Filter by tool type (Static Analysis, Fuzzing, etc.)
   - **Language**: Filter by supported language

5. **Review your selection**
   - Check the footer: "X tools selected"
   - Review estimated time
   - Quick actions:
     - **Select All**: Enable all available scanners
     - **Clear All**: Deselect all scanners

6. **Start the scan**
   - Click "Start Scan" when ready
   - Modal closes automatically on success

### Tips for Custom Selection

**For Quick Checks (under 1 minute)**:
- Select: Slither, Semgrep, Solhint
- Focus: Common vulnerabilities and style issues

**For Gas Optimization**:
- Select: 4naly3er, Slither
- Focus: Gas costs and optimization opportunities

**For Deep Security (10+ minutes)**:
- Select: All static analyzers + Echidna + Halmos
- Focus: Comprehensive vulnerability coverage

**For Reentrancy Detection**:
- Select: Slither, Mythril, Echidna
- Focus: State manipulation and reentrancy patterns

---

## Understanding Scanner Categories

### Static Analysis

**What it does**: Analyzes source code without executing it

**Strengths**:
- Fast (5-180 seconds)
- Detects common vulnerability patterns
- No setup required

**Limitations**:
- May produce false positives
- Can't detect logic bugs that depend on runtime behavior

**Use when**: You want fast, comprehensive vulnerability detection

### Fuzzing

**What it does**: Generates random inputs to test contract behavior

**Strengths**:
- Finds edge cases and unexpected behaviors
- Tests actual execution, not just code patterns
- Great for finding logic bugs

**Limitations**:
- Slower (2-5 minutes)
- May not find all vulnerabilities
- Requires good test coverage

**Use when**: You want to test how your contract handles unexpected inputs

### Symbolic Execution

**What it does**: Explores all possible execution paths symbolically

**Strengths**:
- Exhaustive path coverage
- Finds deep vulnerabilities
- No false positives (when it finds something, it's real)

**Limitations**:
- Very slow (2-4 minutes)
- May timeout on complex contracts
- High resource usage

**Use when**: You need to verify complex logic or state transitions

### Formal Verification

**What it does**: Mathematically proves properties of your contract

**Strengths**:
- Highest level of assurance
- Proves correctness, not just finds bugs
- Eliminates entire classes of vulnerabilities

**Limitations**:
- Slowest (3-5 minutes)
- Requires writing specifications
- Limited language support

**Use when**: You need mathematical proof of critical properties (DeFi protocols, high-value contracts)

### Linting

**What it does**: Enforces coding standards and best practices

**Strengths**:
- Extremely fast (5-10 seconds)
- Improves code quality and readability
- Prevents common mistakes

**Limitations**:
- Doesn't find security vulnerabilities
- Focuses on style and conventions

**Use when**: You want to maintain code quality and consistency

---

## Best Practices

### Choosing the Right Scan Profile

| Development Stage | Recommended Profile | Frequency |
|-------------------|---------------------|-----------|
| Active Development | Quick Scan | Every commit |
| Pre-PR Review | Standard Scan | Before each PR |
| Pre-Staging | Deep Scan | Before each staging deploy |
| Pre-Production | Deep Scan | Before every prod deploy |
| Post-Deployment | Deep Scan | After deploy verification |

### Interpreting Scan Results

1. **Start with Quick Scans** during development
   - Fix issues early when they're easier to address

2. **Run Standard Scans** before code reviews
   - Ensure PR reviewers don't waste time on auto-detectable issues

3. **Run Deep Scans** before deployment
   - Maximum coverage for production-bound code

4. **Use Custom Scans** for targeted analysis
   - After fixing specific vulnerability types
   - When investigating specific issues

### Common Workflows

**Daily Development**:
```
1. Write code
2. Quick Scan (2 min)
3. Fix critical issues
4. Commit
```

**Pre-Pull Request**:
```
1. Standard Scan (5 min)
2. Review all findings
3. Fix or document issues
4. Create PR
```

**Pre-Deployment**:
```
1. Deep Scan (15 min)
2. Generate security report
3. Review with team
4. Address all critical/high issues
5. Deploy
```

---

## FAQs

### General Questions

**Q: How many scanners should I use?**
A: For most contracts, the Standard Scan profile (~16 tools) provides excellent coverage. Use Deep Scan for high-value contracts or before production deployments.

**Q: Can I run multiple scans simultaneously?**
A: Yes! You can start multiple scans on different contracts at the same time.

**Q: How long do scans take?**
A: Quick: ~2 min, Standard: ~5 min, Deep: ~15 min. Custom scans depend on which tools you select.

**Q: What happens if a scan fails?**
A: Individual tool failures don't stop the scan. Other tools will continue running, and you'll see results from successful tools.

### Scanner Selection

**Q: Which scanners are most important?**
A: For Solidity: Slither, Mythril, and Echidna provide excellent coverage. For other languages, use the recommended Quick or Standard presets.

**Q: Can I skip certain scanners?**
A: Yes, use Custom scan profile to manually select/deselect any scanner.

**Q: Why don't I see all 15 scanners?**
A: The scanner list is automatically filtered based on your contract's programming language. You'll only see scanners that support your contract's language (Solidity: 9, Vyper: 2, Rust/Solana: 4).

**Q: What if I'm not sure which scanners to use?**
A: Start with the Standard Scan profile. It's designed to provide comprehensive coverage for most use cases.

### Results and Reports

**Q: How do I view scan results?**
A: Results appear on the Contract Detail page in the "Recent Scans" section. Click any scan to see detailed findings.

**Q: Can I download scan reports?**
A: Yes, scan reports can be exported as PDF or JSON from the scan results page.

**Q: What should I do about false positives?**
A: Review the finding details carefully. You can mark findings as "False Positive" or "Acknowledged" with a reason.

### Troubleshooting

**Q: The scan is taking longer than expected**
A: Deep scans with symbolic execution tools (Halmos, Mythril) can take 10-20 minutes for complex contracts. This is normal.

**Q: A scanner failed with an error**
A: This can happen if the contract has syntax errors or is too complex. Check the error message for details. Other scanners will still complete.

**Q: I can't find a specific scanner**
A: Make sure you're viewing a contract in the correct language. Scanners are filtered by language - Solidity scanners won't appear for Rust contracts.

---

## Need Help?

### Support Resources

- **Documentation**: [docs.0xapogee.com](https://docs.0xapogee.com)
- **GitHub Issues**: [github.com/AdvancedBlockchainSecurity/platform/issues](https://github.com/AdvancedBlockchainSecurity/platform/issues)
- **Community Discord**: [discord.gg/blocksecops](https://discord.gg/blocksecops)
- **Email Support**: support@0xapogee.com

### Related Guides

- [Contract Upload Guide](./contract-upload.md)
- [Understanding Scan Results](./scan-results.md)
- [Vulnerability Remediation Guide](./remediation-guide.md)
- [API Documentation](../api/scanners.md)

---

**Happy Scanning!** 🔒✨

Remember: Regular security scanning is the first line of defense against smart contract vulnerabilities. Make it part of your development workflow!
