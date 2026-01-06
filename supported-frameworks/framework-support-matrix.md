# Framework Support Matrix

This document provides a comprehensive overview of BlockSecOps framework support, including which scanners work with each framework and known limitations.

## Framework Detection

BlockSecOps automatically detects your project framework based on configuration files:

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
| **Slither** | Full | Full | Full | Native support for all frameworks |
| **Aderyn** | Full | Full | Partial | Designed primarily for Foundry |
| **SolidityDefend** | Full | Full | Full | BlockSecOps premier scanner |
| **Echidna** | Full | Full | Full | Fuzz testing with dependencies |
| **Halmos** | Full | Full | Full | Symbolic execution |
| **Wake** | Full | Partial | Partial | Better with single files |
| **Mythril** | Full | Limited | Limited | Prefers flattened contracts |
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
| Mythril | Limited | No | No | Limited |

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

---

**Document Version**: 1.0.0
**Last Updated**: November 27, 2025
