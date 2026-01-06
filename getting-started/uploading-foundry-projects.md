# Uploading Foundry Projects

This guide explains how to upload and scan Foundry projects with BlockSecOps.

## Overview

BlockSecOps natively supports Foundry project structures. When you upload a Foundry project, BlockSecOps automatically:

1. Detects the framework from `foundry.toml`
2. Parses your configuration (compiler version, remappings, optimizer settings)
3. Resolves import remappings (`@openzeppelin/`, `forge-std/`, etc.)
4. Extracts only the files your contracts actually import
5. Runs security scanners in Foundry-compatible mode

## Preparing Your Project

### Required Files

Your project must include:

- `foundry.toml` - Foundry configuration file
- Source files in `src/` (or your configured source directory)

### Recommended Structure

```
my-project/
├── foundry.toml
├── remappings.txt (optional - can be in foundry.toml)
├── src/
│   ├── Token.sol
│   └── interfaces/
│       └── IToken.sol
├── lib/
│   ├── forge-std/
│   └── openzeppelin-contracts/
└── test/ (excluded from scanning)
```

### What Gets Extracted

BlockSecOps uses **smart dependency extraction**:

- **Included**: Your source files + only the library files they import
- **Excluded**: Test files (`test/`), scripts (`script/`), unimported libraries

**Example**: If your project has 200+ files in `lib/openzeppelin-contracts/` but your contracts only import 12 of them, BlockSecOps extracts only those 12 files.

## Creating the Archive

### Option 1: ZIP from Project Root

```bash
cd my-project
zip -r my-project.zip . -x "*.git*" -x "out/*" -x "cache/*"
```

### Option 2: Using tar.gz

```bash
cd my-project
tar --exclude='.git' --exclude='out' --exclude='cache' -czvf my-project.tar.gz .
```

### Recommended Exclusions

Exclude these directories to reduce upload size:

- `.git/` - Version control
- `out/` - Build artifacts
- `cache/` - Compiler cache
- `broadcast/` - Deployment broadcasts
- `node_modules/` - If using npm dependencies

## Uploading to BlockSecOps

### Via Dashboard

1. Navigate to **Contracts** > **Upload Contract**
2. Select **Upload Archive** (ZIP or tar.gz)
3. Choose your archive file
4. BlockSecOps auto-detects Foundry and shows configuration
5. Click **Upload**

### Via API

```bash
curl -X POST "https://api.blocksecops.com/api/v1/contracts/upload" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@my-project.zip" \
  -F "name=MyToken"
```

**Response**:
```json
{
  "id": "uuid",
  "name": "MyToken",
  "framework": "foundry",
  "framework_config": {
    "solc_version": "0.8.20",
    "src_dir": "src",
    "remappings": [
      "@openzeppelin/=lib/openzeppelin-contracts/",
      "forge-std/=lib/forge-std/src/"
    ],
    "optimizer_enabled": true,
    "optimizer_runs": 200
  },
  "is_multi_file": true,
  "file_count": 15,
  "main_file_path": "src/Token.sol"
}
```

## Configuration Parsing

BlockSecOps parses these fields from `foundry.toml`:

| Field | Description | Default |
|-------|-------------|---------|
| `solc_version` | Solidity compiler version | Latest |
| `src` | Source directory | `src` |
| `test` | Test directory (excluded) | `test` |
| `out` | Output directory (excluded) | `out` |
| `libs` | Library directories | `["lib"]` |
| `remappings` | Import remappings | From file |
| `optimizer` | Optimizer enabled | `false` |
| `optimizer_runs` | Optimizer iterations | `200` |
| `via_ir` | IR-based compilation | `false` |
| `evm_version` | Target EVM version | `paris` |

### Remappings

Remappings can be specified in:

1. `foundry.toml` under `[profile.default]`
2. `remappings.txt` file in project root

**Example foundry.toml**:
```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc = "0.8.20"
optimizer = true
optimizer_runs = 200

remappings = [
    "@openzeppelin/=lib/openzeppelin-contracts/",
    "forge-std/=lib/forge-std/src/",
    "@chainlink/=lib/chainlink/contracts/"
]
```

## Scanner Compatibility

| Scanner | Foundry Support | Notes |
|---------|-----------------|-------|
| Slither | Full | Native Foundry mode |
| Aderyn | Full | Designed for Foundry |
| SolidityDefend | Full | Project mode enabled |
| Echidna | Full | Fuzz testing with remappings |
| Halmos | Full | Symbolic execution |

## Tier Limits

File count limits apply after smart dependency extraction:

| Tier | Max Files | Typical Use |
|------|-----------|-------------|
| Free | 25 files | Small projects, single contracts |
| Pro | 100 files | Medium projects with dependencies |
| Enterprise | Unlimited | Large monorepos |

**Note**: Most Foundry projects with OpenZeppelin fit within Free tier limits due to smart extraction.

## Troubleshooting

### "Import not found" Error

**Cause**: Missing remapping or library not included in archive.

**Solution**:
1. Ensure `lib/` directory is included in archive
2. Check remappings match your `foundry.toml`
3. Verify the imported file exists at the remapped path

### "Too many files" Error

**Cause**: Extracted file count exceeds tier limit.

**Solutions**:
1. Upgrade to Pro tier for 100 files
2. Remove unused dependencies from `lib/`
3. Upload a subset of contracts

### Framework Not Detected

**Cause**: Missing or malformed `foundry.toml`.

**Solution**:
1. Ensure `foundry.toml` is in archive root (not nested)
2. Verify TOML syntax is valid
3. Check archive structure matches expected layout

### Scanner Fails on Import

**Cause**: Complex remapping patterns or nested imports.

**Solution**:
1. Ensure all transitive dependencies are in `lib/`
2. Check for circular imports (logged in scan output)
3. Contact support with scan ID for investigation

## Best Practices

1. **Keep lib/ updated**: Run `forge install` before creating archive
2. **Use explicit remappings**: Define all remappings in `foundry.toml`
3. **Exclude build artifacts**: Don't include `out/` or `cache/`
4. **Test locally first**: Run `forge build` to verify compilation
5. **Check file count**: Use `find src lib -name "*.sol" | wc -l` to estimate

## Example Projects

### Minimal Foundry Project

```
minimal-project/
├── foundry.toml
├── src/
│   └── Counter.sol
└── lib/
    └── forge-std/
```

### DeFi Project with OpenZeppelin

```
defi-project/
├── foundry.toml
├── remappings.txt
├── src/
│   ├── Token.sol
│   ├── Staking.sol
│   └── governance/
│       └── Governor.sol
└── lib/
    ├── forge-std/
    └── openzeppelin-contracts/
```

---

**Document Version**: 1.0.0
**Last Updated**: November 27, 2025
