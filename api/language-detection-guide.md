# Multi-Language Contract Support Guide

**Last Updated**: December 21, 2025
**API Version**: v1
**Feature Status**: ✅ Production Ready

---

## Overview

The Apogee Platform provides comprehensive security analysis for **3 blockchain contract languages** across multiple blockchain ecosystems. The platform features automatic language detection, requiring zero manual configuration for supported languages.

### Key Features

- **Automatic Language Detection**: Upload contracts without specifying the language
- **3 Fully Supported Languages**: Solidity, Vyper, and Solana/Rust
- **17 Security Scanners**: 11 Solidity, 2 Vyper, 4 Solana
- **Compiler Version Extraction**: Automatically detects and records compiler versions
- **Language-Specific Metadata**: Framework detection, optimization settings, and more
- **Intelligent Routing**: Contracts automatically routed to appropriate security scanners

---

## Supported Languages

### Production Support

| Language | Extension | Market Share | Blockchain(s) | Scanners |
|----------|-----------|--------------|---------------|----------|
| **Solidity** | `.sol` | 65% | Ethereum, BSC, Polygon, Arbitrum | 12 scanners (see below) |
| **Vyper** | `.vy` | 5-8% | Ethereum (Python-based) | Vyper, Moccasin |
| **Rust/Solana** | `.rs` | 15% | Solana (Anchor) | Sol-azy, Sec3 X-Ray, Trident, Cargo Fuzz |

**Coverage**: These languages cover **85-90% of all blockchain smart contracts**.

### Removed Languages

The following languages were previously planned but have been removed:

| Language | Removed Date | Reason |
|----------|--------------|--------|
| **Cairo/StarkNet** | December 13, 2025 | Ecosystem not prioritized |
| **Move (Aptos/Sui)** | December 11, 2025 | Ecosystem not prioritized |

### Future Languages (Planned)

| Language | Extension | Blockchain(s) | Status |
|----------|-----------|---------------|---------|
| **Tact** | `.tact` | TON | Planned |
| **Clarity** | `.clar` | Stacks (Bitcoin L2) | Planned |
| **Yul** | `.yul` | EVM (low-level) | Planned |

---

## How Language Detection Works

### Detection Flow

```
┌─────────────────────┐
│  Upload Contract    │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────────────┐
│  Language Provided?         │
└──────────┬──────────────────┘
           │
    ┌──────┴──────┐
   YES            NO
    │              │
    ▼              ▼
┌──────────┐  ┌────────────────────┐
│ Validate │  │ Try Extension      │
│ Language │  │ Detection          │
└────┬─────┘  │ (95% confidence)   │
     │        └─────────┬──────────┘
     │                  │
     │         .rs file?│
     │                  │
     │        ┌─────────▼──────────┐
     │        │ Disambiguate:      │
     │        │ RUST vs NEAR vs    │
     │        │ COSMOS (content)   │
     │        └─────────┬──────────┘
     │                  │
     │        ┌─────────▼──────────┐
     │        │ Extract compiler   │
     │        │ version & metadata │
     │        └─────────┬──────────┘
     │                  │
     └──────────────────┤
                        │
                        ▼
             ┌──────────────────┐
             │ Store Contract   │
             │ with language    │
             └──────────────────┘
```

### Detection Methods

#### 1. Extension-Based Detection (95% Confidence)

The fastest and most reliable method. If your file has the correct extension, detection is instant:

```
Token.sol       → Solidity
Vault.vy        → Vyper
program.rs      → Rust/Solana (then disambiguated)
```

**Performance**: ~0.01ms per contract

#### 2. Content-Based Detection (85% Confidence)

If the extension is ambiguous or missing, the system analyzes the source code:

- **Solidity**: `pragma solidity`, `contract`, `function`, `modifier`
- **Vyper**: `# @version`, `@external`, `@payable`, `def`
- **Rust/Solana**: `use anchor_lang`, `use solana_program`, `declare_id!`, `#[program]`

**Performance**: ~1-5ms per contract (analyzes first 500 lines)

#### 3. Rust Disambiguation

`.rs` files require special handling as they can be:
- **Rust** (Solana/Anchor): Contains `anchor_lang`, `solana_program`
- **NEAR**: Contains `near_sdk`, `#[near_bindgen]`
- **Cosmos**: Contains `cosmwasm_std`, `#[entry_point]`

The system checks for framework-specific imports and attributes to determine the exact language.

#### 4. Fallback Detection (50% Confidence)

If all detection methods fail, defaults to Solidity (most common language).

---

## Usage Examples

### Basic Usage: Automatic Detection

The simplest way to upload contracts - let the system detect the language:

```bash
curl -X POST http://localhost:8001/api/v1/contracts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Token.sol",
    "source_code": "pragma solidity ^0.8.20; contract Token { }"
  }'
```

**Response**:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Token.sol",
  "language": "solidity",
  "compiler_version": "0.8.20",
  "language_metadata": {
    "detection_confidence": 0.95,
    "detection_method": "extension",
    "license": null,
    "optimizer_enabled": false
  },
  "status": "pending",
  "created_at": "2025-10-13T15:00:00Z"
}
```

### Explicit Language Specification

You can explicitly specify the language if needed:

```bash
curl -X POST http://localhost:8001/api/v1/contracts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "MyContract",
    "language": "solidity",
    "compiler_version": "0.8.20",
    "source_code": "contract MyContract { }"
  }'
```

This is useful when:
- The file has no extension
- You want to override auto-detection
- You're uploading from a non-standard source

### Filter Contracts by Language

List all contracts for a specific language:

```bash
# Solidity contracts only
curl -X GET "http://localhost:8001/api/v1/contracts?language=solidity&limit=50" \
  -H "Authorization: Bearer $TOKEN"

# Vyper contracts only
curl -X GET "http://localhost:8001/api/v1/contracts?language=vyper" \
  -H "Authorization: Bearer $TOKEN"

# Solana/Rust programs
curl -X GET "http://localhost:8001/api/v1/contracts?language=rust" \
  -H "Authorization: Bearer $TOKEN"

# Move contracts (Aptos/Sui)
curl -X GET "http://localhost:8001/api/v1/contracts?language=move" \
  -H "Authorization: Bearer $TOKEN"

# Cairo contracts (StarkNet)
curl -X GET "http://localhost:8001/api/v1/contracts?language=cairo" \
  -H "Authorization: Bearer $TOKEN"
```

---

## Language-Specific Examples

### Solidity (Ethereum, BSC, Polygon)

```bash
curl -X POST http://localhost:8001/api/v1/contracts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ERC20Token.sol",
    "network": "ethereum",
    "source_code": "// SPDX-License-Identifier: MIT\npragma solidity ^0.8.20;\n\ncontract Token {\n    mapping(address => uint256) public balances;\n}"
  }'
```

**Detected Metadata**:
- Compiler version: `0.8.20`
- License: `MIT`
- Optimizer: detected from pragma
- EVM version: detected from pragma

**Scanners Used**: Slither, Aderyn, Mythril, Semgrep, Solhint, Wake, SolidityDefend, Echidna, Medusa, Halmos

---

### Vyper (Ethereum)

```bash
curl -X POST http://localhost:8001/api/v1/contracts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Vault.vy",
    "network": "ethereum",
    "source_code": "# @version ^0.3.9\n\n@external\n@payable\ndef deposit():\n    pass"
  }'
```

**Detected Metadata**:
- Compiler version: `0.3.9`
- Decorators: `@external`, `@payable`
- Reentrancy guard: detected if present

**Scanners Used**: Vyper (Slither-based), Moccasin

---

### Rust/Anchor (Solana)

```bash
curl -X POST http://localhost:8001/api/v1/contracts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "token_program.rs",
    "network": "solana",
    "source_code": "use anchor_lang::prelude::*;\n\n#[program]\npub mod token_program {\n    use super::*;\n    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {\n        Ok(())\n    }\n}"
  }'
```

**Detected Metadata**:
- Framework: `anchor`
- Anchor version: detected from Cargo.toml if provided
- Program ID: extracted if present

**Scanners Used**: Sol-azy, Sec3 X-Ray, Trident, Cargo Fuzz

---

## Scanner Routing

Contracts are automatically routed to appropriate scanners based on language:

### Solidity → 11 Scanners

**Static Analysis (7)**:
- **Slither**: Fast static analysis (30s)
- **Aderyn**: Solidity-specific checks (30s)
- **Mythril**: Symbolic execution (2-5min)
- **Semgrep**: Pattern-based analysis (10s)
- **Solhint**: Linting and style (10s)
- **Wake**: Static analysis (30s)
- **SolidityDefend**: 204+ detectors (1min)

**Fuzzing & Symbolic (4)**:
- **Echidna**: Property-based fuzzing (5min)
- **Medusa**: Fuzzing (5min)
- **Halmos**: Symbolic execution (5min)

### Vyper → 2 Scanners
- **Vyper (Slither-based)**: Vyper-specific static analysis
- **Moccasin**: Vyper fuzzing

### Rust/Solana → 4 Scanners
- **Sol-azy**: AST-based pattern matching (30s)
- **Sec3 X-Ray**: Deep analysis (2min)
- **Trident**: Property-based fuzzing (5min)
- **Cargo Fuzz**: libFuzzer-based fuzzing (5min)

---

## Language Metadata

Each language provides specific metadata for enhanced analysis:

### Solidity Metadata

```json
{
  "detection_confidence": 0.95,
  "detection_method": "extension",
  "license": "MIT",
  "optimizer_enabled": true,
  "optimizer_runs": 200,
  "evm_version": "istanbul",
  "solc_version": "0.8.20"
}
```

### Vyper Metadata

```json
{
  "detection_confidence": 0.95,
  "detection_method": "extension",
  "vyper_version": "0.3.9",
  "has_reentrancy_guard": true,
  "decorator_count": 5
}
```

### Rust/Anchor Metadata

```json
{
  "detection_confidence": 0.85,
  "detection_method": "content",
  "framework": "anchor",
  "program_id": "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA",
  "anchor_version": "0.28.0"
}
```


---

## Error Handling

### Invalid Language

If you specify an unsupported language:

```bash
curl -X POST http://localhost:8001/api/v1/contracts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Contract",
    "language": "javascript",
    "source_code": "..."
  }'
```

**Response** (400 Bad Request):
```json
{
  "detail": "Invalid language 'javascript'. Valid options: solidity, vyper, solana"
}
```

### Detection Failure

If detection fails completely (rare), the system defaults to Solidity with 50% confidence:

```json
{
  "language": "solidity",
  "language_metadata": {
    "detection_confidence": 0.5,
    "detection_method": "fallback"
  }
}
```

You can override by explicitly specifying the language.

---

## Best Practices

### 1. Use Correct File Extensions

Always include the proper file extension for best results:
- ✅ `Token.sol` (instant detection)
- ❌ `Token` (slower content-based detection)

### 2. Include Version Pragmas

Help the system detect compiler versions:
```solidity
pragma solidity ^0.8.20;  // ✅ Version extracted
contract Token { }
```

### 3. Specify Network

Provide the blockchain network for better scanner selection:
```json
{
  "name": "Token.sol",
  "network": "ethereum",  // ✅ Helps with context
  "source_code": "..."
}
```

### 4. Override When Necessary

If auto-detection is wrong, explicitly specify:
```json
{
  "name": "unknown_contract",
  "language": "vyper",  // ✅ Override detection
  "source_code": "..."
}
```

### 5. Use Language Filtering

When working with specific ecosystems, filter by language:
```bash
# Get all Solidity contracts
GET /contracts?language=solidity

# Get all Vyper contracts
GET /contracts?language=vyper

# Get all Solana programs
GET /contracts?language=solana
```

---

## Performance Characteristics

| Operation | Time | Notes |
|-----------|------|-------|
| Extension-based detection | ~0.01ms | Instant, 95% confidence |
| Content-based detection | 1-5ms | Analyzes first 500 lines |
| Rust disambiguation | 2-8ms | Checks framework imports |
| Compiler version extraction | 1-3ms | Regex pattern matching |
| Metadata extraction | 2-10ms | Language-specific analysis |
| **Total detection time** | **3-15ms** | Negligible overhead |

---

## Integration Examples

### Python SDK

```python
import httpx

client = httpx.AsyncClient(base_url="http://localhost:8001/api/v1")

# Upload with auto-detection
response = await client.post("/contracts", json={
    "name": "Token.sol",
    "source_code": "pragma solidity ^0.8.0; contract Token {}"
}, headers={"Authorization": f"Bearer {token}"})

contract = response.json()
print(f"Detected: {contract['language']}")
print(f"Confidence: {contract['language_metadata']['detection_confidence']}")

# Filter by language
response = await client.get("/contracts", params={"language": "vyper"})
vyper_contracts = response.json()["contracts"]
```

### TypeScript/JavaScript

```typescript
import { contractsApi } from '@/lib/api';

// Upload with auto-detection
const contract = await contractsApi.createContract({
  name: 'Token.sol',
  source_code: 'pragma solidity ^0.8.20; contract Token {}'
});

console.log(`Detected: ${contract.language}`);
console.log(`Confidence: ${contract.language_metadata.detection_confidence}`);

// Filter by language
const solanaPrograms = await contractsApi.listContracts({
  language: 'rust',
  limit: 50
});
```

---

## Troubleshooting

### Detection Issues

**Problem**: Wrong language detected
**Solution**: Explicitly specify language in request

**Problem**: Low confidence score
**Solution**: Ensure file has correct extension and proper syntax

**Problem**: Rust disambiguation incorrect
**Solution**: Include framework imports at top of file

### Filtering Issues

**Problem**: Language filter returns no results
**Solution**: Check valid language values, use lowercase

**Problem**: Can't filter by blockchain
**Solution**: Use `network` parameter, not `language`

---

## Changelog

### v1.1.0 (2025-12-21)

**Changed**:
- Removed Cairo/StarkNet support (ecosystem not prioritized)
- Removed Move (Aptos/Sui) support (ecosystem not prioritized)
- Updated scanner counts: 11 Solidity, 2 Vyper, 4 Solana
- Simplified to 3 supported languages

### v1.0.0 (2025-10-13)

**Added**:
- Automatic language detection
- Extension-based detection (95% confidence)
- Content-based detection (85% confidence)
- Rust/Solana disambiguation
- Compiler version extraction
- Language-specific metadata extraction
- Language filtering on list endpoint

---

## Support

For language detection issues:
1. Check this guide for correct usage
2. Verify language is in supported list
3. Ensure proper file extension
4. Check API logs for detection details
5. Report issues to development team

---

**Related Documentation**:
- [API Endpoints Reference](./endpoints-reference.md)
- [Plugin SDK Guide](../development/plugin-sdk-guide.md)
- [Scanner Docker Images](../deployment/scanner-docker-images.md)
