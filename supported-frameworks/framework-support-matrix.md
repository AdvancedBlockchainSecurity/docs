# Framework Support Matrix

This document provides a comprehensive overview of Apogee framework support, including which scanners work with each framework and known limitations.

## Framework Detection

Apogee automatically detects your project framework based on configuration files:

| Framework | Detection File | Priority |
|-----------|----------------|----------|
| Foundry | `foundry.toml` | 1 (highest) |
| Hardhat | `hardhat.config.js` or `hardhat.config.ts` | 2 |
| Plain | Neither present | 3 (default) |

**Note**: If both `foundry.toml` and `hardhat.config.js` exist, Foundry takes precedence.

## Scanner Compatibility Matrix

### By Framework

| Scanner | Single File | Foundry | Hardhat | Notes |
|---------|-------------|---------|---------|-------|
| **Slither** | Full | Full | Full | Hardhat projects converted to Foundry layout at scan time (offline-compatible). OZ 5.x bundled — see Hardhat Support Details. |
| **Aderyn** | Full | Full | Full | Hardhat → Foundry conversion (Task #172 sweep). OZ 5.x bundled. |
| **SolidityDefend** | Full | Full | Full | Apogee premier scanner |
| **Echidna** | Full | Full | Full | Hardhat → Foundry conversion. Note: only finds issues on contracts with `echidna_*` invariant tests. |
| **Halmos** | Full | Full | Full | Symbolic execution. Hardhat → Foundry conversion. OZ 5.x bundled. |
| **Wake** | Full | Full | Full | Hardhat → Foundry conversion. OZ 5.x bundled. |
| **Mythril** | Full | Single-file only | Single-file only | Symbolic execution. **Multi-file projects are not currently supported** — mythril's z3 SMT solver consistently OOMs at the 2Gi per-container memory limit on multi-file Hardhat/Foundry projects (verified post-Task #182 fix). Single-file and single-entry-point projects work fully, including Hardhat projects importing `@openzeppelin/contracts/...` (Task #176 — solc Standard JSON remapping via `--solc-json`). Multi-file scans terminate cleanly in one attempt (Task #182 eliminated the prior 4× backoff retry pattern) but fail with `status=failed`. The other 6 Solidity scanners (slither, aderyn, wake, halmos, echidna, medusa) handle multi-file projects fine. Auto-skip on multi-file projects is tracked as Task #183 (post-launch). |
| **Medusa** | Full | Full | Full | Hardhat → Foundry conversion. Note: only finds issues on contracts with property-test invariants. |
| **Securify2** | Full | Limited | Limited | Academic tool, limited project support |

### Feature Support by Scanner

| Scanner | Import Resolution | Remappings | npm Packages | Multi-Contract |
|---------|-------------------|------------|--------------|----------------|
| Slither | Yes | Yes | Yes | Yes |
| Aderyn | Yes | Yes | Limited | Yes |
| SolidityDefend | Yes | Yes | Yes | Yes |
| Echidna | Yes | Yes | Yes | Yes |
| Halmos | Yes | Yes | Yes | Yes |
| Wake | Partial | Partial | Partial | Yes |
| Mythril | Single-file | Single-file | Single-file | Single-file only (Task #182) |

## Foundry Support Details

### Fully Supported Features

- **Configuration Parsing**: `foundry.toml` fully parsed
- **Remappings**: From `foundry.toml` and `remappings.txt`
- **Library Resolution**: `lib/` directory imports
- **Compiler Settings**: Version, optimizer, EVM version
- **Smart Extraction**: Only imported files extracted

### Parsed Configuration Fields

```toml
[profile.default]
src = "src"              # Source directory
test = "test"            # Test directory (excluded)
out = "out"              # Build output (excluded)
libs = ["lib"]           # Library directories
solc = "0.8.20"          # Compiler version
optimizer = true         # Optimizer enabled
optimizer_runs = 200     # Optimizer runs
via_ir = false           # IR compilation
evm_version = "paris"    # EVM target
ffi = false              # FFI enabled
fuzz_runs = 256          # Fuzz iterations
invariant_runs = 256     # Invariant runs
```

### Known Limitations

1. **Forge Scripts**: `script/` directory excluded from scanning
2. **FFI Calls**: Not executed during scanning
3. **Cheatcodes**: Test cheatcodes not available in scans
4. **Build Artifacts**: Not used (contracts compiled fresh)

## Hardhat Support Details

### Fully Supported Features

- **Configuration Parsing**: `hardhat.config.js` parsed (regex-based MVP)
- **npm Dependencies**: Read from `package.json`
- **Import Resolution**: `node_modules/` paths
- **Compiler Settings**: Version, optimizer, EVM version

### Offline Compile (Task #172, 2026-04-26)

The scanner namespace is air-gapped — `npx hardhat compile` cannot reach `binaries.soliditylang.org` to download solc (HH502). All 7 Solidity scanners (slither, aderyn, wake, halmos, mythril, echidna, medusa) convert Hardhat projects to a Foundry-compatible layout at scan time: write a minimal `foundry.toml` with `offline = true` and an explicit OpenZeppelin remapping to `/opt/openzeppelin/v5/`, seed the `.svm` solc cache from pre-installed binaries in the base image, and rename `hardhat.config.*` to `.disabled` so the scanner's compile pipeline (crytic-compile, solcx, forge) picks Foundry framework instead of Hardhat. This is shipped via the slither pass-B fix and the Task #172 sweep PR.

### Pre-Bundled npm Dependencies

| Package | Version | Path | Bundled In |
|---------|---------|------|-----------|
| `@openzeppelin/contracts` | 5.0.2 | `/opt/openzeppelin/v5/` | scanner-base-solidity:1.1.0-b49e3f10 |

OZ 4.x, `@openzeppelin/contracts-upgradeable`, and other libraries (`@chainlink/contracts`, `@uniswap/v3-core`, etc.) are **not** bundled. Projects depending on those will surface `forge build` import errors rather than silently scanning to 0 findings. Reactive bundling on first customer request.

### Parsed Configuration Fields

```javascript
module.exports = {
  solidity: {
    version: "0.8.20",           // Compiler version
    settings: {
      optimizer: {
        enabled: true,            // Optimizer enabled
        runs: 200                 // Optimizer runs
      },
      evmVersion: "paris"         // EVM target
    }
  },
  paths: {
    sources: "./contracts",       // Source directory
    tests: "./test"               // Test directory (excluded)
  }
};
```

### Known Limitations

1. **Complex Configs**: Dynamic/computed configurations may not parse
2. **Multiple Compiler Versions**: Only first version used
3. **Plugin Configuration**: Plugin-specific settings not parsed
4. **TypeScript Configs**: Parsed via regex, complex patterns may fail
5. **Network Configs**: Ignored (deployment settings)

### Future Enhancements (Planned)

- Node.js subprocess parser for full accuracy
- Plugin detection (hardhat-deploy, typechain, upgrades)
- Multi-compiler version support

## Import Resolution

### Foundry Remappings

```solidity
// With remapping: @openzeppelin/=lib/openzeppelin-contracts/
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// Resolves to: lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol
```

### Hardhat npm Imports

```solidity
// Resolves from node_modules
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// Resolves to: node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol
```

### Resolution Algorithm

1. Check if import matches a remapping prefix (Foundry)
2. Check if import starts with `@` (npm scoped package)
3. Check relative paths from current file
4. Check library directories (`lib/` or `node_modules/`)

## Tier Limits with Framework Projects

File limits apply **after** smart dependency extraction:

| Tier | Max Files | Typical Project Size |
|------|-----------|---------------------|
| Free | 25 | Small DeFi protocol (5-10 contracts + deps) |
| Pro | 100 | Medium protocol (20-30 contracts + deps) |
| Enterprise | Unlimited | Monorepos, large protocols |

### Smart Extraction Examples

| Project | Total Files | Extracted Files | Fits Tier |
|---------|-------------|-----------------|-----------|
| Simple ERC20 + OZ | 200+ | ~8 | Free |
| DeFi with Uniswap | 500+ | ~45 | Pro |
| Governor + OZ Gov | 200+ | ~25 | Free |
| Full Protocol | 1000+ | ~80 | Pro |

## Best Practices

### For Foundry Projects

1. Define all remappings in `foundry.toml` (not just `remappings.txt`)
2. Use `forge install` to manage dependencies
3. Keep `lib/` directory clean (remove unused packages)
4. Run `forge build` before uploading to verify compilation

### For Hardhat Projects

1. Use `package.json` for all dependencies
2. Run `npm install` before creating archive
3. Use `package-lock.json` for reproducible installs
4. Avoid dynamic configuration in `hardhat.config.js`

### General Recommendations

1. **Exclude test files**: Test directories are automatically excluded
2. **Exclude build artifacts**: Don't include `out/`, `artifacts/`, `cache/`
3. **Check file count**: Use smart extraction to stay within tier limits
4. **Test locally first**: Compile before uploading

## Troubleshooting by Framework

### Foundry Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Import not found | Missing remapping | Add to `foundry.toml` |
| Wrong compiler | Version mismatch | Check `solc` in config |
| Lib not found | Missing submodule | Run `forge install` |

### Hardhat Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Import not found | Missing package | Run `npm install` |
| Config not parsed | Complex config | Simplify config |
| Wrong version | Multiple versions | Use single version |

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Nov 27, 2025 | Initial framework support (Foundry + Hardhat) |
| 1.1.0 | Apr 29, 2026 | Mythril Hardhat+OZ single-file fixed (Task #176); multi-file Hardhat limitation noted (Task #182) |
| 1.2.0 | May 3, 2026 | Mythril multi-file resilience shipped (Task #182, scanner-mythril:0.2.9 — eliminates 4× backoff retry, definitive terminal status in 1 attempt). Multi-file remains explicitly unsupported pending auto-skip implementation (Task #183, post-launch). |

---

**Document Version**: 1.1.0
**Last Updated**: April 29, 2026
