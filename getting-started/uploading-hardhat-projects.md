# Uploading Hardhat Projects

This guide explains how to upload and scan Hardhat projects with BlockSecOps.

## Overview

BlockSecOps natively supports Hardhat project structures. When you upload a Hardhat project, BlockSecOps automatically:

1. Detects the framework from `hardhat.config.js` or `hardhat.config.ts`
2. Parses your configuration (compiler version, paths, optimizer settings)
3. Resolves npm package imports (`@openzeppelin/contracts`, etc.)
4. Extracts only the files your contracts actually import
5. Runs security scanners in Hardhat-compatible mode

## Preparing Your Project

### Required Files

Your project must include:

- `hardhat.config.js` or `hardhat.config.ts` - Hardhat configuration
- `package.json` - npm dependencies
- Source files in `contracts/` (or your configured source directory)

### Recommended Structure

```
my-project/
├── hardhat.config.js
├── package.json
├── contracts/
│   ├── Token.sol
│   └── interfaces/
│       └── IToken.sol
├── node_modules/
│   └── @openzeppelin/
│       └── contracts/
└── test/ (excluded from scanning)
```

### What Gets Extracted

BlockSecOps uses **smart dependency extraction**:

- **Included**: Your contract files + only the npm packages they import
- **Excluded**: Test files (`test/`), scripts (`scripts/`), deployment files, unimported packages

**Example**: If `node_modules/@openzeppelin/contracts/` has 200+ files but your contracts only import ERC20 and Ownable, BlockSecOps extracts only those ~10 files.

## Creating the Archive

### Option 1: ZIP with node_modules

```bash
cd my-project
zip -r my-project.zip . \
  -x "*.git*" \
  -x "artifacts/*" \
  -x "cache/*" \
  -x "coverage/*" \
  -x "typechain-types/*"
```

### Option 2: Using tar.gz

```bash
cd my-project
tar --exclude='.git' \
    --exclude='artifacts' \
    --exclude='cache' \
    --exclude='coverage' \
    -czvf my-project.tar.gz .
```

### Option 3: Without node_modules (Smaller Archive)

If you want a smaller archive, exclude `node_modules`:

```bash
zip -r my-project.zip . -x "*.git*" -x "node_modules/*" -x "artifacts/*"
```

**Note**: Scans may fail on imports if `node_modules` is excluded. Ensure all imported packages are present.

### Recommended Exclusions

Exclude these directories to reduce upload size:

- `.git/` - Version control
- `artifacts/` - Compiled artifacts
- `cache/` - Hardhat cache
- `coverage/` - Test coverage reports
- `typechain-types/` - TypeChain generated types
- `.openzeppelin/` - Upgrade plugin data

## Uploading to BlockSecOps

### Via Dashboard

1. Navigate to **Contracts** > **Upload Contract**
2. Select **Upload Archive** (ZIP or tar.gz)
3. Choose your archive file
4. BlockSecOps auto-detects Hardhat and shows configuration
5. Click **Upload**

### Via API

```bash
curl -X POST "https://api.0xapogee.com/api/v1/contracts/upload" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@my-project.zip" \
  -F "name=MyToken"
```

**Response**:
```json
{
  "id": "uuid",
  "name": "MyToken",
  "framework": "hardhat",
  "framework_config": {
    "solc_version": "0.8.20",
    "sources_path": "./contracts",
    "optimizer_enabled": true,
    "optimizer_runs": 200,
    "dependencies": {
      "@openzeppelin/contracts": "^5.0.0"
    }
  },
  "is_multi_file": true,
  "file_count": 12,
  "main_file_path": "contracts/Token.sol"
}
```

## Configuration Parsing

BlockSecOps parses these fields from `hardhat.config.js`:

| Field | Description | Default |
|-------|-------------|---------|
| `solidity.version` | Solidity compiler version | Latest |
| `paths.sources` | Source directory | `./contracts` |
| `paths.tests` | Test directory (excluded) | `./test` |
| `solidity.settings.optimizer.enabled` | Optimizer enabled | `false` |
| `solidity.settings.optimizer.runs` | Optimizer iterations | `200` |
| `solidity.settings.evmVersion` | Target EVM version | `paris` |

### Example hardhat.config.js

```javascript
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      evmVersion: "paris"
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  }
};
```

### TypeScript Configuration

TypeScript configs (`hardhat.config.ts`) are also supported:

```typescript
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  }
};

export default config;
```

## npm Dependencies

BlockSecOps reads `package.json` to understand your dependencies:

```json
{
  "dependencies": {
    "@openzeppelin/contracts": "^5.0.0",
    "@openzeppelin/contracts-upgradeable": "^5.0.0"
  },
  "devDependencies": {
    "hardhat": "^2.19.0",
    "@nomicfoundation/hardhat-toolbox": "^4.0.0"
  }
}
```

### Import Resolution

BlockSecOps resolves imports from `node_modules`:

```solidity
// This import:
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Resolves to:
// node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol
```

## Scanner Compatibility

| Scanner | Hardhat Support | Notes |
|---------|-----------------|-------|
| Slither | Full | Native Hardhat mode |
| Aderyn | Partial | Best with Foundry |
| SolidityDefend | Full | Project mode enabled |
| Echidna | Full | Requires compilation |
| Halmos | Full | Symbolic execution |

## Tier Limits

File count limits apply after smart dependency extraction:

| Tier | Max Files | Typical Use |
|------|-----------|-------------|
| Free | 25 files | Small projects, single contracts |
| Pro | 100 files | Medium projects with dependencies |
| Enterprise | Unlimited | Large monorepos |

**Note**: Most Hardhat projects with OpenZeppelin fit within Free tier limits due to smart extraction.

## Troubleshooting

### "Import not found" Error

**Cause**: Missing npm package or incorrect import path.

**Solutions**:
1. Ensure `node_modules/` is included in archive
2. Run `npm install` before creating archive
3. Verify package is in `package.json` dependencies
4. Check import path matches package structure

### "Too many files" Error

**Cause**: Extracted file count exceeds tier limit.

**Solutions**:
1. Upgrade to Pro tier for 100 files
2. Remove unused dependencies from `package.json`
3. Upload a subset of contracts

### Framework Not Detected

**Cause**: Missing or malformed `hardhat.config.js`.

**Solutions**:
1. Ensure config file is in archive root (not nested)
2. Verify JavaScript/TypeScript syntax is valid
3. Check for syntax errors in config

### TypeScript Config Not Parsed

**Cause**: Complex TypeScript configuration.

**Solution**: The MVP Hardhat parser uses regex extraction. For complex configs:
1. Simplify exported config
2. Avoid dynamic configuration
3. Use explicit values instead of variables

### Scanner Fails on Import

**Cause**: Complex or nested npm dependencies.

**Solutions**:
1. Ensure all transitive dependencies are installed
2. Check for conflicting package versions
3. Verify `node_modules` structure is correct

## Best Practices

1. **Run npm install**: Always run `npm install` before creating archive
2. **Lock dependencies**: Use `package-lock.json` for consistent installs
3. **Exclude build artifacts**: Don't include `artifacts/` or `cache/`
4. **Test locally first**: Run `npx hardhat compile` to verify compilation
5. **Check file count**: Use `find contracts node_modules -name "*.sol" | wc -l`

## Plugin Support

BlockSecOps recognizes common Hardhat plugins:

| Plugin | Supported | Notes |
|--------|-----------|-------|
| @nomicfoundation/hardhat-toolbox | Yes | Standard toolbox |
| @openzeppelin/hardhat-upgrades | Yes | Proxy contracts |
| hardhat-deploy | Partial | Deployment scripts excluded |
| @typechain/hardhat | Yes | Types excluded |
| hardhat-gas-reporter | N/A | Testing plugin |
| solidity-coverage | N/A | Testing plugin |

## Example Projects

### Minimal Hardhat Project

```
minimal-project/
├── hardhat.config.js
├── package.json
├── contracts/
│   └── Lock.sol
└── node_modules/
```

### DeFi Project with OpenZeppelin

```
defi-project/
├── hardhat.config.ts
├── package.json
├── tsconfig.json
├── contracts/
│   ├── Token.sol
│   ├── Staking.sol
│   └── governance/
│       └── Governor.sol
└── node_modules/
    └── @openzeppelin/
        └── contracts/
```

### Upgradeable Contracts

```
upgradeable-project/
├── hardhat.config.js
├── package.json
├── contracts/
│   ├── MyTokenV1.sol
│   └── MyTokenV2.sol
└── node_modules/
    └── @openzeppelin/
        ├── contracts/
        └── contracts-upgradeable/
```

## Migration from Foundry

If migrating from Foundry, note these differences:

| Aspect | Foundry | Hardhat |
|--------|---------|---------|
| Config file | `foundry.toml` | `hardhat.config.js` |
| Source dir | `src/` | `contracts/` |
| Dependencies | `lib/` (git submodules) | `node_modules/` (npm) |
| Remappings | `remappings.txt` | Implicit from node_modules |
| Test framework | Solidity (forge-std) | JavaScript/TypeScript |

---

**Document Version**: 1.0.0
**Last Updated**: November 27, 2025
