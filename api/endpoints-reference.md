# API Endpoints Reference

**Last Updated**: 2026-01-04
**API Version**: v1
**Base URL**: `http://localhost:8000/api/v1` (local) | `https://api.blocksecops.com/api/v1` (production)

## Overview

Complete reference for all BlockSecOps Platform API endpoints. All endpoints require authentication except where noted.

## Authentication

BlockSecOps uses **Supabase Auth** for authentication. User registration, login, password reset, and OAuth flows are handled by Supabase. The BlockSecOps API verifies JWT tokens and enforces tier-based access control.

### Authentication Flow

#### 1. Frontend Authentication (app.blocksecops.com)
Users authenticate through Supabase on the frontend:
- **Email/Password**: Handled by Supabase Auth
- **OAuth Providers**: Google, Microsoft, GitHub (configured in Supabase)
- **Password Reset**: Email-based reset flow via Supabase
- **Email Verification**: Automatic verification emails

#### 2. API Authentication (api.blocksecops.com)
API endpoints require Bearer token in Authorization header:

```bash
curl -X GET https://api.blocksecops.com/api/v1/users/me \
  -H "Authorization: Bearer <supabase_access_token>"
```

#### 3. Token Verification (Backend)
- Backend verifies JWT using ES256 with Supabase's public keys (JWKS)
- User auto-synced to local database on first JWT verification
- Default tier assigned: `free`
- Quota record auto-created via database trigger

### JWT Token Structure

**Supabase Access Token** (ES256):
```json
{
  "aud": "authenticated",
  "exp": 1699834800,
  "sub": "user-uuid-from-supabase",
  "email": "user@example.com",
  "role": "authenticated"
}
```

**Token Expiration**: 1 hour (configurable in Supabase)

### Frontend Integration Example

```typescript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.VITE_SUPABASE_URL,
  process.env.VITE_SUPABASE_ANON_KEY
)

// Get session token
const { data: { session } } = await supabase.auth.getSession()

// Make authenticated API call
const response = await fetch('https://api.blocksecops.com/api/v1/users/me/enhanced', {
  headers: {
    'Authorization': `Bearer ${session.access_token}`
  }
})
```

### Authorization Header Format

All protected endpoints require:
```
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Status Codes**:
- `401` Unauthorized - Missing, invalid, or expired token
- `403` Forbidden - Valid token but insufficient permissions

### Security Features

- **ES256 Encryption**: Asymmetric JWT verification using ECDSA P-256 (public key only on backend)
- **JWKS Verification**: Public keys fetched from `https://[project].supabase.co/auth/v1/.well-known/jwks.json`
- **Auto User Sync**: Users created in local DB on first API request
- **Tier Assignment**: Default tier='free' for new users
- **Session Storage**: Sessions stored in PostgreSQL (not cookies/Redis)

---

## Health & Status

### GET /health/live

Liveness probe - check if service is running.

**Authentication**: Not required

**Response** (200 OK):
```json
{
  "status": "healthy",
  "service": "blocksecops-api-service",
  "version": "0.1.0",
  "timestamp": "2025-10-06T22:00:00Z"
}
```

---

### GET /health/ready

Readiness probe - check if service can accept requests.

**Authentication**: Not required

**Response** (200 OK):
```json
{
  "ready": true,
  "checks": {
    "database": true,
    "service": true
  },
  "message": "Service is ready"
}
```

**Status Codes**:
- `200` OK - Service ready
- `503` Service Unavailable - Service not ready (database down, etc.)

---

### GET /health/startup

Startup probe - check if service has completed startup.

**Authentication**: Not required

**Response** (200 OK):
```json
{
  "started": true,
  "message": "Service has started successfully"
}
```

---

## Contracts

### GET /contracts

List all contracts for authenticated user with pagination and language filtering.

**Authentication**: Required (Bearer token)

**Query Parameters**:
- `skip` (integer, default: 0) - Number of records to skip
- `limit` (integer, default: 100, max: 1000) - Number of records to return
- `network` (string, optional) - Filter by blockchain network
- `status` (string, optional) - Filter by status (pending, scanned, failed)
- `language` (string, optional) - Filter by language (solidity, vyper, rust, move, cairo, near, cosmos, etc.)

**Response** (200 OK):
```json
{
  "contracts": [
    {
      "id": "uuid",
      "user_id": "uuid",
      "name": "MyToken",
      "address": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
      "network": "ethereum",
      "lines_of_code": 450,
      "status": "pending",
      "language": "solidity",
      "compiler_version": "0.8.0",
      "language_metadata": {
        "detection_confidence": 0.95,
        "detection_method": "extension",
        "license": "MIT"
      },
      "is_multi_file": true,
      "file_count": 12,
      "main_file_path": "src/Token.sol",
      "is_project": true,
      "framework": "foundry",
      "framework_config": {
        "solc_version": "0.8.20",
        "src_dir": "src",
        "remappings": ["@openzeppelin/=lib/openzeppelin-contracts/"]
      },
      "projects": [
        {
          "id": "uuid",
          "name": "DeFi Project"
        }
      ],
      "created_at": "2025-10-06T22:00:00Z",
      "updated_at": "2025-10-06T22:00:00Z"
    }
  ],
  "total": 1,
  "page": 1,
  "page_size": 100
}
```

**Status Codes**:
- `200` OK - Success
- `401` Unauthorized - Invalid or missing token

---

### GET /contracts/{id}

Get details of a specific contract.

**Authentication**: Required

**Path Parameters**:
- `id` (UUID) - Contract ID

**Response** (200 OK):
```json
{
  "id": "uuid",
  "user_id": "uuid",
  "name": "MyToken",
  "address": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
  "network": "ethereum",
  "source_code": "pragma solidity ^0.8.0; ...",
  "bytecode": "0x608060...",
  "lines_of_code": 450,
  "status": "pending",
  "language": "solidity",
  "compiler_version": "0.8.20",
  "is_multi_file": true,
  "file_count": 12,
  "main_file_path": "src/Token.sol",
  "is_project": true,
  "framework": "foundry",
  "framework_config": {
    "solc_version": "0.8.20",
    "src_dir": "src",
    "test_dir": "test",
    "libs": ["lib"],
    "remappings": [
      "@openzeppelin/=lib/openzeppelin-contracts/",
      "forge-std/=lib/forge-std/src/"
    ],
    "optimizer_enabled": true,
    "optimizer_runs": 200
  },
  "files": [
    {
      "id": "uuid",
      "file_path": "src/Token.sol",
      "is_main_file": true,
      "file_size": 2048,
      "lines_of_code": 120,
      "created_at": "2025-10-06T22:00:00Z"
    }
  ],
  "last_scan_date": "2025-10-06T23:00:00Z",
  "created_at": "2025-10-06T22:00:00Z",
  "updated_at": "2025-10-06T22:00:00Z"
}
```

**Framework Types**:
- `foundry` - Foundry project (detected via `foundry.toml`)
- `hardhat` - Hardhat project (detected via `hardhat.config.js/ts`)
- `plain` - Plain Solidity project (no framework)
- `null` - Single file upload (pre-Phase 3.2 contracts)

**Status Codes**:
- `200` OK - Contract found
- `404` Not Found - Contract not found
- `403` Forbidden - Not authorized to access this contract

---

### POST /contracts

Create a new contract for analysis with automatic language detection.

**Authentication**: Required

**Request**:
```json
{
  "name": "MyToken.sol",
  "address": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
  "network": "ethereum",
  "source_code": "pragma solidity ^0.8.0; contract MyToken { }",
  "bytecode": "0x608060...",
  "language": "solidity",
  "compiler_version": "0.8.0"
}
```

**Field Descriptions**:
- `language` (optional) - Contract language. Auto-detected from filename/content if not provided
- `compiler_version` (optional) - Compiler version. Auto-extracted from source if not provided

**Response** (201 Created):
```json
{
  "id": "uuid",
  "user_id": "uuid",
  "name": "MyToken.sol",
  "address": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
  "network": "ethereum",
  "lines_of_code": 1,
  "status": "pending",
  "language": "solidity",
  "compiler_version": "0.8.0",
  "language_metadata": {
    "detection_confidence": 0.95,
    "detection_method": "extension",
    "license": "MIT",
    "optimizer_enabled": false
  },
  "created_at": "2025-10-06T22:00:00Z",
  "updated_at": "2025-10-06T22:00:00Z"
}
```

**Automatic Language Detection**:

The platform automatically detects contract language from:
1. **File extension** (high confidence): `.sol`, `.vy`, `.rs`, `.move`, `.cairo`, etc.
2. **Content patterns** (medium confidence): pragma directives, keywords, syntax patterns
3. **Default fallback** (low confidence): Defaults to Solidity if detection fails

**Supported Languages** (23 total across 3 tiers):

*Tier 1* (Full scanner support - Phase 3):
- `solidity` - Ethereum, BSC, Polygon (65% market share)
- `vyper` - Ethereum (Python-based, 5-8%)
- `rust` - Solana/Anchor, Polkadot (15%)
- `move` - Aptos, Sui (3-5%)
- `cairo` - StarkNet (2-3%)

*Tier 2* (Future support - Phase 4-5):
- `tact` - TON blockchain
- `clarity` - Stacks (Bitcoin L2)
- `yul`, `huff`, `fe` - EVM low-level languages
- `simplicity`, `michelson`, `plutus`

*Tier 3* (Emerging - Phase 5+):
- `near` - NEAR Protocol
- `cosmos` - CosmWasm
- `sway`, `cadence`, `motoko`, `ink`, `zinc`, `leo`

**Language-Specific Metadata**:

Each language may include specific metadata:
- **Solidity**: `license`, `optimizer_enabled`, `evm_version`
- **Vyper**: `has_reentrancy_guard`, `decorator_count`
- **Rust/Anchor**: `framework`, `program_id`, `anchor_version`
- **Move**: `framework` (aptos/sui), `resource_count`
- **Cairo**: `cairo_version` (1.x/2.x), `storage_count`
- **NEAR**: `framework`, `has_near_bindgen`, `near_sdk_version`
- **Cosmos**: `framework`, `has_entry_point`, `has_ibc_support`

**Examples**:

*Solidity Contract*:
```json
{
  "name": "Token.sol",
  "source_code": "pragma solidity ^0.8.20; contract Token {}"
}
// Auto-detected: language=solidity, compiler_version=0.8.20
```

*Vyper Contract*:
```json
{
  "name": "Vault.vy",
  "source_code": "# @version ^0.3.9\n@external\ndef withdraw(): pass"
}
// Auto-detected: language=vyper, compiler_version=0.3.9
```

*Rust/Anchor Program*:
```json
{
  "name": "program.rs",
  "source_code": "use anchor_lang::prelude::*;\n#[program]\npub mod my_program {}"
}
// Auto-detected: language=rust, metadata.framework=anchor
```

*Move Contract*:
```json
{
  "name": "coin.move",
  "source_code": "module aptos_framework::coin { struct Coin has key {} }"
}
// Auto-detected: language=move, metadata.framework=aptos
```

*Cairo Contract*:
```json
{
  "name": "contract.cairo",
  "source_code": "#[starknet::contract]\nmod MyContract {}"
}
// Auto-detected: language=cairo, metadata.cairo_version=2.x
```

**Validations**:
- `name`: 1-255 characters, required
- `address`: Valid blockchain address format (optional)
- `network`: Valid blockchain network, required
- `source_code` OR `bytecode`: At least one required
- `language`: Valid language enum value if provided

**Status Codes**:
- `201` Created - Contract created with language detected
- `400` Bad Request - Invalid data or unsupported language
- `409` Conflict - Contract name already exists for user (see below)
- `422` Unprocessable Entity - Validation failed

**Response (409 Conflict)**:
```json
{
  "error": "contract_name_exists",
  "message": "A contract named 'MyToken' already exists",
  "existing_contract": {
    "id": "uuid",
    "name": "MyToken",
    "created_at": "2025-12-31T00:00:00Z",
    "status": "uploaded",
    "is_multi_file": false,
    "file_count": 1
  }
}
```

---

### GET /contracts/check-name

Check if a contract name already exists for the authenticated user. Use this endpoint before creating/uploading to proactively check for conflicts.

**Authentication**: Required

**Query Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| name | string | Yes | Contract name to check (min 1 character) |

**Response (200 OK)** - Name available:
```json
{
  "exists": false,
  "existing_contract": null
}
```

**Response (200 OK)** - Name already exists:
```json
{
  "exists": true,
  "existing_contract": {
    "id": "uuid",
    "name": "MyToken",
    "created_at": "2025-12-31T00:00:00Z",
    "status": "uploaded",
    "is_multi_file": false,
    "file_count": 1
  }
}
```

**Status Codes**:
- `200` OK - Check completed
- `401` Unauthorized - Invalid or missing token
- `422` Unprocessable Entity - Invalid query parameter

---

## Language Detection

### Language Filtering Example

Filter contracts by language to focus on specific blockchain ecosystems:

**Solidity contracts only**:
```bash
curl -X GET "http://localhost:8001/api/v1/contracts?language=solidity&limit=10" \
  -H "Authorization: Bearer $TOKEN"
```

**Vyper contracts only**:
```bash
curl -X GET "http://localhost:8001/api/v1/contracts?language=vyper&limit=10" \
  -H "Authorization: Bearer $TOKEN"
```

**Solana/Rust programs only**:
```bash
curl -X GET "http://localhost:8001/api/v1/contracts?language=rust&limit=10" \
  -H "Authorization: Bearer $TOKEN"
```

**Move contracts only (Aptos/Sui)**:
```bash
curl -X GET "http://localhost:8001/api/v1/contracts?language=move&limit=10" \
  -H "Authorization: Bearer $TOKEN"
```

**Cairo contracts only (StarkNet)**:
```bash
curl -X GET "http://localhost:8001/api/v1/contracts?language=cairo&limit=10" \
  -H "Authorization: Bearer $TOKEN"
```

### Language Detection Confidence Levels

The language detection system provides confidence scores:

- **95% confidence** - Extension-based detection (`.sol`, `.vy`, `.move`, etc.)
- **85% confidence** - Content-based detection (pragma keywords, syntax patterns)
- **50% confidence** - Default fallback (Solidity when unable to detect)

**Response includes detection metadata**:
```json
{
  "language": "solidity",
  "compiler_version": "0.8.20",
  "language_metadata": {
    "detection_confidence": 0.95,
    "detection_method": "extension",
    "license": "MIT"
  }
}
```

### Multi-Language Upload Example

Upload contracts in different languages:

```bash
# Solidity
curl -X POST http://localhost:8001/api/v1/contracts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Token.sol",
    "source_code": "pragma solidity ^0.8.20; contract Token {}"
  }'

# Vyper
curl -X POST http://localhost:8001/api/v1/contracts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Vault.vy",
    "source_code": "# @version ^0.3.9\n@external\ndef deposit(): pass"
  }'

# Rust/Anchor
curl -X POST http://localhost:8001/api/v1/contracts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "program.rs",
    "source_code": "use anchor_lang::prelude::*;\n#[program]\npub mod my_program {}"
  }'

# Move
curl -X POST http://localhost:8001/api/v1/contracts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "coin.move",
    "source_code": "module 0x1::coin { struct Coin has key {} }"
  }'

# Cairo
curl -X POST http://localhost:8001/api/v1/contracts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "contract.cairo",
    "source_code": "#[starknet::contract]\nmod MyContract {}"
  }'
```

All contracts are automatically detected and routed to appropriate scanners based on their language.

---

## Scans

### GET /scans

List all scans for authenticated user.

**Authentication**: Required

**Query Parameters**:
- `skip` (integer, default: 0)
- `limit` (integer, default: 100, max: 1000)
- `status` (string, optional) - Filter by status (queued, running, completed, failed)
- `contract_id` (UUID, optional) - Filter by contract

**Response** (200 OK):
```json
{
  "scans": [
    {
      "id": "uuid",
      "contract_id": "uuid",
      "user_id": "uuid",
      "scan_type": "full",
      "status": "queued",
      "started_at": null,
      "completed_at": null,
      "critical_count": 0,
      "high_count": 0,
      "medium_count": 0,
      "low_count": 0,
      "created_at": "2025-10-06T22:00:00Z",
      "updated_at": "2025-10-06T22:00:00Z"
    }
  ],
  "total": 1,
  "page": 1,
  "page_size": 100
}
```

---

### GET /scans/{id}

Get details of a specific scan.

**Authentication**: Required

**Response** (200 OK):
```json
{
  "id": "uuid",
  "contract_id": "uuid",
  "user_id": "uuid",
  "scan_type": "full",
  "status": "completed",
  "started_at": "2025-10-06T22:00:00Z",
  "completed_at": "2025-10-06T22:05:00Z",
  "critical_count": 2,
  "high_count": 5,
  "medium_count": 8,
  "low_count": 12,
  "created_at": "2025-10-06T22:00:00Z",
  "updated_at": "2025-10-06T22:05:00Z"
}
```

---

### POST /scans

Create a new security scan for a contract.

**Authentication**: Required

**Request**:
```json
{
  "contract_id": "uuid",
  "scan_type": "full"
}
```

**Response** (201 Created):
```json
{
  "id": "uuid",
  "contract_id": "uuid",
  "user_id": "uuid",
  "scan_type": "full",
  "status": "queued",
  "created_at": "2025-10-06T22:00:00Z"
}
```

**Scan Types**:
- `quick` - Fast scan, basic checks only
- `full` - Comprehensive analysis (default)

**Status Codes**:
- `201` Created - Scan queued
- `400` Bad Request - Invalid contract_id
- `402` Payment Required - Quota exceeded (see below)
- `404` Not Found - Contract not found

**Quota Enforcement** (Phase 3.1a Week 2 - November 14, 2025):

When a user exceeds their tier-based scan quota, the API returns HTTP 402 with detailed quota information:

**Response** (402 Payment Required):
```json
{
  "detail": {
    "error": "quota_exceeded",
    "message": "You've used all 10 scans for this month",
    "tier": "free",
    "scans_used": 10,
    "scan_limit": 10,
    "scans_remaining": 0,
    "reset_date": "2025-12-01T00:00:00+00:00",
    "days_until_reset": 17,
    "upgrade_url": "/pricing",
    "upgrade_message": "Upgrade to Pro for unlimited scans or wait until your quota resets",
    "payment_options": {
      "can_use_credits": true,
      "credit_balance": 5,
      "per_scan_price": "1.00",
      "pricing_tiers": {
        "simple": { "files": "1-5", "price_usd": "0.50" },
        "standard": { "files": "6-25", "price_usd": "1.00" },
        "complex": { "files": "26-100", "price_usd": "2.00" },
        "large": { "files": "100+", "price_usd": "5.00" }
      },
      "token": "USDC",
      "network": "base",
      "chain_id": 8453,
      "purchase_credits_url": "/payments/packages",
      "use_credit_endpoint": "/payments/credits/use"
    }
  }
}
```

**Tier Limits**:
- **Free**: 10 scans/month (enforced)
- **Pro**: Unlimited scans
- **Enterprise**: Unlimited scans
- **Enterprise Broker**: Unlimited scans

**Payment Options** (Phase 3.4 - December 2025):
The 402 response includes `payment_options` for x402 pay-per-scan integration:
- `can_use_credits`: Whether user has available credits
- `credit_balance`: Current credit balance
- `per_scan_price`: Default price per scan in USD
- `pricing_tiers`: Complexity-based pricing tiers
- `token`: Payment token (USDC)
- `network`: Blockchain network (base)
- `chain_id`: Network chain ID (8453)
- `purchase_credits_url`: Endpoint to purchase credits
- `use_credit_endpoint`: Endpoint to use credits

**Frontend Behavior**:
- API client automatically intercepts 402 errors
- QuotaExceededModal displays automatically showing quota info and upgrade options
- Users can upgrade to Pro, purchase credits, or wait for monthly quota reset
- If `can_use_credits` is true, users can use existing credits to run the scan

---

### DELETE /scans/{scan_id}

**NEW** (December 9, 2025) - Delete a scan and all related records.

Delete a single scan and cascade delete all associated vulnerabilities and specialized scan results. Payment and credit transactions are preserved with `scan_id` set to NULL.

**Authentication**: Required

**Path Parameters**:
- `scan_id` (UUID) - The scan to delete

**Response** (200 OK):
```json
{
  "success": true,
  "scan_id": "550e8400-e29b-41d4-a716-446655440000",
  "message": "Scan deleted successfully",
  "deleted_vulnerabilities_count": 15,
  "deleted_results_count": 4
}
```

**Status Codes**:
- `200` OK - Scan deleted successfully
- `401` Unauthorized - Missing or invalid token
- `403` Forbidden - Not authorized to delete this scan (belongs to another user)
- `404` Not Found - Scan not found

**Cascade Behavior**:
When a scan is deleted, the following related records are handled:
- `vulnerabilities` - CASCADE DELETE (all findings removed)
- `code_quality_findings` - CASCADE DELETE
- `gas_analysis_findings` - CASCADE DELETE
- `formal_verification_results` - CASCADE DELETE
- `fuzzing_results` - CASCADE DELETE
- `payment_transactions.scan_id` - SET NULL (preserves billing history)
- `credit_transactions.scan_id` - SET NULL (preserves credit usage history)

---

### DELETE /scans (Batch)

**NEW** (December 9, 2025) - Delete multiple scans at once.

Batch delete up to 100 scans in a single request. Returns partial success if some deletions fail.

**Authentication**: Required

**Request**:
```json
{
  "scan_ids": [
    "550e8400-e29b-41d4-a716-446655440000",
    "660e8400-e29b-41d4-a716-446655440001",
    "770e8400-e29b-41d4-a716-446655440002"
  ]
}
```

**Response** (200 OK - Full Success):
```json
{
  "success": true,
  "deleted_count": 3,
  "total_requested": 3,
  "failed_ids": [],
  "errors": null
}
```

**Response** (200 OK - Partial Success):
```json
{
  "success": true,
  "deleted_count": 2,
  "total_requested": 3,
  "failed_ids": ["770e8400-e29b-41d4-a716-446655440002"],
  "errors": {
    "770e8400-e29b-41d4-a716-446655440002": "Scan not found"
  }
}
```

**Request Validation**:
- Maximum 100 scan IDs per request
- All scan IDs must be valid UUIDs
- All scans must belong to the authenticated user

**Status Codes**:
- `200` OK - Request processed (check `deleted_count` and `failed_ids`)
- `400` Bad Request - Invalid request body or exceeds max limit
- `401` Unauthorized - Missing or invalid token
- `422` Unprocessable Entity - Invalid UUID format

---

### GET /scans/compare

**NEW** (December 11, 2025) - Compare two scans to identify new, fixed, and unchanged vulnerabilities (Phase 3.1b - Task 22).

Compares vulnerability findings between two scans using fingerprint-based matching. Scans should be from the same contract for meaningful comparison.

**Authentication**: Required

**Query Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `scan_id_a` | UUID | Yes | First scan ID (baseline) |
| `scan_id_b` | UUID | Yes | Second scan ID (comparison) |

**Response** (200 OK):
```json
{
  "scan_a": {
    "id": "uuid",
    "contract_id": "uuid",
    "contract_name": "MyToken",
    "scan_type": "full",
    "status": "completed",
    "scanners_used": ["slither", "aderyn"],
    "created_at": "2025-12-10T10:00:00Z",
    "vulnerability_count": 5
  },
  "scan_b": {
    "id": "uuid",
    "contract_id": "uuid",
    "contract_name": "MyToken",
    "scan_type": "full",
    "status": "completed",
    "scanners_used": ["slither", "mythril"],
    "created_at": "2025-12-11T10:00:00Z",
    "vulnerability_count": 8
  },
  "total_in_a": 5,
  "total_in_b": 8,
  "new_vulnerabilities": 4,
  "fixed_vulnerabilities": 1,
  "unchanged_vulnerabilities": 4,
  "modified_vulnerabilities": 0,
  "vulnerabilities": [
    {
      "id": "uuid",
      "title": "Reentrancy Attack",
      "severity": "critical",
      "category": "reentrancy",
      "scanner_id": "slither",
      "status": "new",
      "scan_a_details": null,
      "scan_b_details": {
        "id": "uuid",
        "line_number": 42,
        "description": "Potential reentrancy vulnerability",
        "recommendation": "Use ReentrancyGuard"
      }
    },
    {
      "id": "uuid",
      "title": "Unused Variable",
      "severity": "low",
      "category": "code-quality",
      "scanner_id": "slither",
      "status": "fixed",
      "scan_a_details": {
        "id": "uuid",
        "line_number": 15,
        "description": "Variable 'temp' is never used"
      },
      "scan_b_details": null
    },
    {
      "id": "uuid",
      "title": "Missing Zero Check",
      "severity": "medium",
      "category": "validation",
      "scanner_id": "aderyn",
      "status": "unchanged",
      "scan_a_details": {
        "id": "uuid",
        "line_number": 28
      },
      "scan_b_details": {
        "id": "uuid",
        "line_number": 28
      }
    }
  ],
  "summary_by_severity": {
    "critical": { "new": 1, "fixed": 0, "unchanged": 0, "modified": 0 },
    "high": { "new": 1, "fixed": 0, "unchanged": 2, "modified": 0 },
    "medium": { "new": 1, "fixed": 0, "unchanged": 1, "modified": 0 },
    "low": { "new": 1, "fixed": 1, "unchanged": 1, "modified": 0 }
  }
}
```

**Response Fields**:
- `scan_a`: Baseline scan metadata
- `scan_b`: Comparison scan metadata
- `total_in_a`: Total vulnerabilities in scan A
- `total_in_b`: Total vulnerabilities in scan B
- `new_vulnerabilities`: Count of vulnerabilities in B but not A
- `fixed_vulnerabilities`: Count of vulnerabilities in A but not B
- `unchanged_vulnerabilities`: Count of vulnerabilities in both A and B
- `modified_vulnerabilities`: Count of vulnerabilities at same location with different details
- `vulnerabilities`: Array of vulnerability comparison details
- `summary_by_severity`: Breakdown by severity level

**Vulnerability Status Values**:
- `new`: Found in scan B but not in scan A
- `fixed`: Found in scan A but not in scan B
- `unchanged`: Found in both scans (matching fingerprint)
- `modified`: Same location but different vulnerability details

**Fingerprint Matching**:
Vulnerabilities are matched using the Intelligence Layer fingerprint system:
1. `fingerprint_code` - SHA-256 hash of normalized code snippet
2. Fallback: category + scanner_id + line_number + title

**Status Codes**:
- `200` OK - Comparison completed successfully
- `400` Bad Request - Missing scan_id_a or scan_id_b parameter
- `401` Unauthorized - Missing or invalid token
- `403` Forbidden - Not authorized to access one or both scans
- `404` Not Found - One or both scans not found

**Example (curl)**:
```bash
# Get auth token
TOKEN=$(/Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)

# Compare two scans
curl -s "http://127.0.0.1:3000/api/v1/scans/compare?scan_id_a=<SCAN_A>&scan_id_b=<SCAN_B>" \
  -H "Authorization: Bearer $TOKEN" | jq '.'
```

**Use Case**:
- Track security improvements over time
- Identify regressions after code changes
- Measure remediation progress
- Compare results across different scanner tools

---

### GET /scans/{id}/vulnerabilities/breakdown

**NEW** (November 6, 2025) - Get vulnerabilities with scanner/intelligence separation.

This endpoint provides clear distinction between:
- **Scanner Results**: Direct detections by the scanner tool (scanner_id IS NOT NULL)
- **Intelligence Layer**: Platform-wide pattern analysis findings (scanner_id IS NULL)

**Authentication**: Required

**Path Parameters**:
- `id` (UUID) - Scan ID

**Query Parameters**:
- `severity` (string, optional) - Filter by severity (critical, high, medium, low)
- `status` (string, optional) - Filter by status (open, acknowledged, fixed, false_positive)

**Response** (200 OK):
```json
{
  "scanner_results": [
    {
      "id": "uuid",
      "scan_id": "uuid",
      "title": "Reentrancy vulnerability",
      "description": "...",
      "severity": "high",
      "scanner_id": "slither",
      "confidence": 0.8,
      ...
    }
  ],
  "intelligence_results": [
    {
      "id": "uuid",
      "scan_id": "uuid",
      "title": "Locked Ether",
      "description": "...",
      "severity": "medium",
      "scanner_id": null,
      "pattern_code": "BVD-SOLIDITY-STA-002",
      "classification_confidence": 0.95,
      ...
    }
  ],
  "scanner_counts": {
    "total": 1,
    "critical": 0,
    "high": 1,
    "medium": 0,
    "low": 0
  },
  "intelligence_counts": {
    "total": 1,
    "critical": 0,
    "high": 0,
    "medium": 1,
    "low": 0
  }
}
```

**Status Codes**:
- `200` OK - Breakdown retrieved successfully
- `404` Not Found - Scan not found
- `403` Forbidden - Not authorized to access this scan

**Use Case**:
Fixes UX confusion where users see vulnerability counts but don't know the source. For example, a Wake scan showing "2 vulnerabilities" when Wake found 0 (intelligence layer found 2).

**Backward Compatibility**:
The original `/scans/{id}/vulnerabilities` endpoint remains unchanged. This new endpoint provides an enhanced view with source separation.

---

## Scanners

### GET /scanners

List all available security scanners with optional filtering by language, project mode, and category.

**Authentication**: Optional (public endpoint)

**Query Parameters**:
- `language` (string, optional) - Filter by language: `solidity`, `vyper`, `rust`
- `is_project` (boolean, optional) - Filter by project requirement:
  - `true` - Include all scanners (for project uploads)
  - `false` - Exclude scanners requiring project structure (for single-file uploads)
  - Not specified - Return all scanners (backward compatible)

**Response** (200 OK):
```json
{
  "scanners": [
    {
      "id": "slither",
      "name": "Slither",
      "description": "Static analyzer for Solidity smart contracts",
      "version": "0.2.0",
      "is_available": true,
      "languages": ["solidity", "vyper"],
      "requires_project": false,
      "category": "static"
    },
    {
      "id": "echidna",
      "name": "Echidna",
      "description": "Property-based fuzzer for Ethereum smart contracts",
      "version": "0.2.0",
      "is_available": true,
      "languages": ["solidity"],
      "requires_project": true,
      "category": "fuzzing"
    }
  ],
  "total": 15
}
```

**Scanner Categories**:
- `static` - Static analysis tools (Slither, Aderyn, Semgrep, etc.)
- `fuzzing` - Property-based fuzzers (Echidna, Medusa, Moccasin, etc.)
- `symbolic` - Symbolic execution (Halmos)
- `linting` - Code quality linters (Solhint)

**Project-Only Scanners** (`requires_project=true`):
- `echidna` - Solidity fuzzer, requires test harnesses
- `medusa` - Solidity fuzzer, requires property tests
- `moccasin` - Vyper fuzzer, requires Hypothesis tests
- `halmos` - Symbolic execution, requires project structure
- `sec3-xray` - Solana analyzer, requires Anchor project
- `trident` - Solana fuzzer, requires Anchor project
- `cargo-fuzz-solana` - Solana fuzzer, requires cargo workspace

**Single-File Scanners** (`requires_project=false`):
- `slither`, `aderyn`, `semgrep`, `solhint`, `wake`, `soliditydefend`, `vyper`, `sol-azy`

**Example - Get scanners for single-file upload**:
```bash
curl "https://api.blocksecops.com/api/v1/scanners?language=solidity&is_project=false"
# Returns: slither, aderyn, semgrep, solhint, wake, soliditydefend (6 scanners)
```

**Example - Get scanners for project upload**:
```bash
curl "https://api.blocksecops.com/api/v1/scanners?language=solidity&is_project=true"
# Returns: all Solidity scanners including echidna, medusa, halmos (9 scanners)
```

---

### GET /scanners/{scanner_id}

Get detailed information about a specific scanner.

**Authentication**: Optional (public endpoint)

**Path Parameters**:
- `scanner_id` (string) - Scanner identifier (e.g., `slither`, `echidna`)

**Response** (200 OK):
```json
{
  "id": "echidna",
  "name": "Echidna",
  "description": "Property-based fuzzer for Ethereum smart contracts",
  "version": "0.2.0",
  "is_available": true,
  "languages": ["solidity"],
  "requires_project": true,
  "category": "fuzzing",
  "detectors": [],
  "timeout_seconds": 3600,
  "documentation_url": "https://github.com/crytic/echidna"
}
```

**Error Response** (404 Not Found):
```json
{
  "detail": "Scanner not found: invalid-scanner"
}
```

---

### GET /scanners/presets/{language}

Get scanner presets for a specific language. Presets are predefined scanner combinations for Quick, Standard, and Deep scans.

**Authentication**: Optional (public endpoint)

**Path Parameters**:
- `language` (string) - Language: `solidity`, `vyper`, `rust`

**Query Parameters**:
- `is_project` (boolean, optional) - Filter preset scanners by project requirement

**Response** (200 OK):
```json
{
  "language": "solidity",
  "presets": {
    "quick": {
      "name": "Quick Scan",
      "description": "Fast static analysis tools only (~1 minute)",
      "scanner_ids": ["slither", "aderyn", "semgrep", "solhint", "wake", "soliditydefend"],
      "estimated_time_seconds": 105
    },
    "standard": {
      "name": "Standard Scan",
      "description": "Static analysis + basic fuzzing (~3 minutes)",
      "scanner_ids": ["slither", "aderyn", "semgrep", "solhint", "wake", "soliditydefend", "echidna"],
      "estimated_time_seconds": 235
    },
    "deep": {
      "name": "Deep Scan",
      "description": "All tools including symbolic execution and advanced fuzzing (~8 minutes)",
      "scanner_ids": ["slither", "aderyn", "semgrep", "solhint", "wake", "soliditydefend", "halmos", "echidna", "medusa"],
      "estimated_time_seconds": 510
    }
  }
}
```

**Note**: When `is_project=false`, fuzzer scanners (echidna, medusa, etc.) are removed from all presets.

---

### GET /scanners/presets/{language}/{preset_name}

Get a specific preset by name.

**Authentication**: Optional (public endpoint)

**Path Parameters**:
- `language` (string) - Language: `solidity`, `vyper`, `rust`
- `preset_name` (string) - Preset name: `quick`, `standard`, `deep`

**Query Parameters**:
- `is_project` (boolean, optional) - Filter preset scanners by project requirement

**Response** (200 OK):
```json
{
  "name": "Quick Scan",
  "description": "Fast static analysis tools only (~1 minute)",
  "scanner_ids": ["slither", "aderyn", "semgrep", "solhint", "wake", "soliditydefend"],
  "estimated_time_seconds": 105
}
```

---

### POST /scans/{scan_id}/fuzzing-results

Store fuzzing results from fuzzer scanners. Called by the tool-integration service after a fuzzer scan completes.

**Authentication**: Required (service-to-service)

**Path Parameters**:
- `scan_id` (UUID) - Scan ID

**Request Body**:
```json
{
  "results": [
    {
      "test_name": "test_withdraw_reentrancy",
      "status": "passed",
      "executions": 10000,
      "coverage_percentage": 85.5,
      "seed": 12345,
      "failure_trace": null,
      "edge_cases_found": []
    },
    {
      "test_name": "test_invariant_balance",
      "status": "failed",
      "executions": 5432,
      "coverage_percentage": 72.3,
      "seed": 67890,
      "failure_trace": "Call sequence: deposit(1000) -> withdraw(500) -> withdraw(600)",
      "edge_cases_found": ["overflow at uint256 max"]
    }
  ]
}
```

**Response** (200 OK):
```json
{
  "status": "success",
  "results_stored": 2
}
```

---

## Vulnerabilities

### GET /vulnerabilities

List all vulnerabilities for authenticated user with Intelligence Layer enrichment.

**Authentication**: Required

**Query Parameters**:
- `skip` (integer, default: 0)
- `limit` (integer, default: 100, max: 1000)
- `severity` (string, optional) - Filter by severity (critical, high, medium, low)
- `status` (string, optional) - Filter by status (open, acknowledged, fixed, false_positive)
- `pattern_code` (string, optional) - Filter by Intelligence Layer pattern code (e.g., BVD-SOLIDITY-REE-001)
- `min_classification_confidence` (float, optional) - Filter by minimum classification confidence (0.0-1.0)

**Response** (200 OK):
```json
{
  "vulnerabilities": [
    {
      "id": "uuid",
      "contract_id": "uuid",
      "scan_id": "uuid",
      "title": "Reentrancy Vulnerability",
      "description": "Potential reentrancy attack in withdraw function",
      "severity": "critical",
      "category": "reentrancy",
      "line_number": 42,
      "code_snippet": "function withdraw() public { ... }",
      "recommendation": "Use ReentrancyGuard or checks-effects-interactions pattern",
      "status": "open",
      "detected_at": "2025-10-06T22:00:00Z",
      "created_at": "2025-10-06T22:00:00Z",
      "updated_at": "2025-10-06T22:00:00Z",

      "pattern_id": "550e8400-e29b-41d4-a716-446655440003",
      "pattern_code": "BVD-SOLIDITY-REE-001",
      "classification_confidence": 0.95,
      "classification_method": "rule_based",
      "fingerprint_code": "a3f5e2c8b1d7f9e4c6a8d2f5b7e9c1a4d6f8e0a2c4b6d8e0f2a4c6e8b0d2f4a6",
      "fingerprint_location": "b7d4a1f92c8e6f3ad5e7c9f1b4d6a8e2c4f6d8e0a2b4c6d8e0f2a4b6c8d0e2f4",
      "fingerprint_ast": "c9e2f5d8a6b3c1e7f4d2a5c8b1e6d9f3a5c7e9d1b3e5f7d9c1a3e5d7f9b1c3e5",
      "fingerprint_location_fuzzy": "d8f3a9e7c2b5d1f6e4a8c0b2d4f6e8a0c2b4d6f8e0a2c4b6d8e0f2a4b6c8d0e2",
      "deduplication_group_id": "550e8400-e29b-41d4-a716-446655440004",
      "is_canonical": true,
      "duplicate_count": 3,
      "scanner_count": 2
    }
  ],
  "total": 1,
  "page": 1,
  "page_size": 100
}
```

**Intelligence Layer Fields**:
- `pattern_id` (string, nullable) - UUID of matched vulnerability pattern from pattern database
- `pattern_code` (string, nullable) - Standardized pattern code (e.g., BVD-SOLIDITY-REE-001 for Solidity reentrancy)
- `classification_confidence` (float, nullable) - Confidence score for pattern classification (0.0-1.0, where 1.0 is highest confidence)
- `classification_method` (string, nullable) - Classification method used: `rule_based`, `ml_based`, or `hybrid`
- `fingerprint_code` (string, nullable) - SHA-256 hash of normalized code snippet for deduplication
- `fingerprint_location` (string, nullable) - SHA-256 hash of file:line:function location
- `fingerprint_ast` (string, nullable) - SHA-256 hash of AST structure
- `fingerprint_location_fuzzy` (string, nullable) - Fuzzy location hash (±3 line tolerance) for near-duplicate detection
- `deduplication_group_id` (UUID, nullable) - UUID of deduplication group this finding belongs to
- `is_canonical` (boolean, nullable) - True if this is the canonical (primary) finding in its deduplication group
- `duplicate_count` (integer, nullable) - Number of duplicate findings in the same deduplication group
- `scanner_count` (integer, nullable) - Number of unique scanners that detected this vulnerability

**Notes**:
- Intelligence fields will be `null` for vulnerabilities that haven't been enriched
- Pattern codes follow format: BVD-{ECOSYSTEM}-{CATEGORY}-{NUMBER}
  - Ecosystems: EVM, VYPER, SOLANA, CAIRO
  - Categories: REE (Reentrancy), ACC (Access Control), INT (Integer), etc.
- Deduplication groups link findings from multiple scanners detecting the same vulnerability

---

### GET /vulnerabilities/{id}

Get details of a specific vulnerability including Intelligence Layer enrichment (pattern classification, fingerprints, deduplication).

**Authentication**: Required

**Path Parameters**:
- `id` (UUID) - Vulnerability ID

**Response** (200 OK):
```json
{
  "id": "uuid",
  "contract_id": "uuid",
  "scan_id": "uuid",
  "title": "Reentrancy Vulnerability",
  "description": "Potential reentrancy attack in withdraw function",
  "severity": "critical",
  "category": "reentrancy",
  "line_number": 42,
  "code_snippet": "function withdraw() public { msg.sender.call.value(balance)(); }",
  "recommendation": "Use ReentrancyGuard or checks-effects-interactions pattern",
  "status": "open",
  "detected_at": "2025-10-06T22:00:00Z",

  "pattern_id": "550e8400-e29b-41d4-a716-446655440003",
  "pattern_code": "BVD-SOLIDITY-REE-001",
  "classification_confidence": 0.95,
  "classification_method": "rule_based",
  "fingerprint_code": "a3f5e2c8b1d7f9e4c6a8d2f5b7e9c1a4d6f8e0a2c4b6d8e0f2a4c6e8b0d2f4a6",
  "fingerprint_location": "b7d4a1f92c8e6f3ad5e7c9f1b4d6a8e2c4f6d8e0a2b4c6d8e0f2a4b6c8d0e2f4",
  "fingerprint_ast": "c9e2f5d8a6b3c1e7f4d2a5c8b1e6d9f3a5c7e9d1b3e5f7d9c1a3e5d7f9b1c3e5",
  "fingerprint_location_fuzzy": "d8f3a9e7c2b5d1f6e4a8c0b2d4f6e8a0c2b4d6f8e0a2c4b6d8e0f2a4b6c8d0e2",
  "deduplication_group_id": "550e8400-e29b-41d4-a716-446655440004",
  "is_canonical": true,
  "duplicate_count": 3,
  "scanner_count": 2
}
```

**Intelligence Layer Enrichment**:

Returns vulnerability details with Intelligence Layer enrichment:
- **Pattern classification** (pattern_id, pattern_code, classification_confidence)
- **Fingerprints** (code, location, AST, fuzzy location hashes)
- **Deduplication** (group_id, canonical status, scanner count)

Intelligence fields will be `null` for vulnerabilities that haven't been enriched.

**Status Codes**:
- `200` OK - Vulnerability found
- `404` Not Found - Vulnerability not found
- `403` Forbidden - Not authorized to access this vulnerability

---

### GET /vulnerabilities/contracts/{contract_id}/vulnerabilities

Get all vulnerabilities for a specific contract.

**Authentication**: Required

**Query Parameters**:
- `skip` (integer, default: 0)
- `limit` (integer, default: 100)
- `severity` (string, optional)

**Response**: Same as `GET /vulnerabilities`

---

### PATCH /vulnerabilities/{id}/status

Update the status of a vulnerability.

**Authentication**: Required

**Request**:
```json
{
  "status": "fixed"
}
```

**Response** (200 OK):
```json
{
  "id": "uuid",
  "status": "fixed",
  "updated_at": "2025-10-06T22:00:00Z"
}
```

**Valid Statuses**:
- `open` - Newly detected, not yet addressed
- `acknowledged` - Team is aware, working on fix
- `fixed` - Vulnerability has been resolved
- `false_positive` - Not actually a vulnerability

---

## Statistics

### GET /statistics/dashboard

Get aggregated statistics for dashboard display.

**Authentication**: Required

**Response** (200 OK):
```json
{
  "total_scans": 127,
  "total_vulnerabilities": 45,
  "contracts_scanned": 34,
  "average_risk_score": 6.7
}
```

**Field Descriptions**:
- `total_scans`: Total number of scans run by user
- `total_vulnerabilities`: Total vulnerabilities found across all scans
- `contracts_scanned`: Number of unique contracts analyzed
- `average_risk_score`: Average risk score (0-10 scale)

---

### GET /statistics/scan-history

Get 30-day scan history for trend visualization.

**Authentication**: Required

**Response** (200 OK):
```json
{
  "history": [
    {
      "date": "2025-09-06",
      "scans": 12,
      "vulnerabilities": 8
    },
    {
      "date": "2025-09-07",
      "scans": 15,
      "vulnerabilities": 11
    }
    // ... 30 days total
  ]
}
```

**Notes**:
- Returns exactly 30 days of data
- Missing dates have 0 counts
- Dates in YYYY-MM-DD format
- Ordered chronologically

---

## Analytics

### GET /analytics/tools

Get tool effectiveness metrics showing which scanner tools find the most vulnerabilities.

**Authentication**: Required

**Query Parameters**:
- `days` (integer, default: 30, min: 1, max: 365) - Number of days to analyze

**Response** (200 OK):
```json
{
  "tools": [
    {
      "tool_name": "slither",
      "total_scans": 45,
      "total_vulnerabilities": 123,
      "critical_count": 12,
      "high_count": 34,
      "medium_count": 56,
      "low_count": 21,
      "avg_scan_time_seconds": 42.5,
      "success_rate": 98.5
    }
  ],
  "total_tools": 5,
  "date_range": "Last 30 days"
}
```

**Field Descriptions**:
- `tool_name`: Scanner tool name (slither, mythril, etc.)
- `total_scans`: Total scans performed with this tool
- `total_vulnerabilities`: Total vulnerabilities found by this tool
- `critical_count`: Number of critical vulnerabilities
- `high_count`: Number of high severity vulnerabilities
- `medium_count`: Number of medium severity vulnerabilities
- `low_count`: Number of low severity vulnerabilities
- `avg_scan_time_seconds`: Average scan duration in seconds
- `success_rate`: Percentage of successful scans (0-100)

**Notes**:
- Results sorted by total_vulnerabilities (most effective first)
- Only includes scans within specified date range
- User-scoped data (security isolation)

---

### GET /analytics/trends

Get vulnerability trends over time showing new findings and resolutions.

**Authentication**: Required

**Query Parameters**:
- `days` (integer, default: 30, min: 1, max: 365) - Number of days to analyze

**Response** (200 OK):
```json
{
  "trends": [
    {
      "date": "2025-10-17",
      "total": 15,
      "critical": 2,
      "high": 5,
      "medium": 6,
      "low": 2,
      "new_vulnerabilities": 15,
      "resolved_vulnerabilities": 3
    }
  ],
  "total_days": 30,
  "summary": {
    "total_new_vulnerabilities": 450,
    "total_resolved_vulnerabilities": 120,
    "net_change": 330,
    "average_per_day": 15.0
  }
}
```

**Field Descriptions**:
- `date`: Date in YYYY-MM-DD format
- `total`: Total vulnerabilities on this date
- `critical`, `high`, `medium`, `low`: Breakdown by severity
- `new_vulnerabilities`: New vulnerabilities discovered on this date
- `resolved_vulnerabilities`: Vulnerabilities marked as fixed/false_positive
- `summary.total_new_vulnerabilities`: Total new vulnerabilities across all days
- `summary.total_resolved_vulnerabilities`: Total resolved across all days
- `summary.net_change`: Net change (new - resolved)
- `summary.average_per_day`: Average vulnerabilities per day

**Notes**:
- Returns data for every day in range (missing dates have 0 counts)
- Dates ordered chronologically
- User-scoped data

---

### GET /analytics/projects

Get cross-project comparison showing security metrics for all projects.

**Authentication**: Required

**Response** (200 OK):
```json
{
  "projects": [
    {
      "project_id": "uuid",
      "project_name": "DeFi Protocol",
      "contract_count": 5,
      "total_scans": 23,
      "total_vulnerabilities": 67,
      "critical_count": 3,
      "high_count": 12,
      "medium_count": 34,
      "low_count": 18,
      "health_score": 72.5,
      "last_scan_date": "2025-10-17T20:30:00Z",
      "avg_vulnerabilities_per_contract": 13.4
    }
  ],
  "total_projects": 3,
  "global_stats": {
    "total_projects": 3,
    "total_contracts": 15,
    "total_vulnerabilities": 201,
    "avg_vulnerabilities_per_project": 67.0,
    "avg_vulnerabilities_per_contract": 13.4
  }
}
```

**Health Score Calculation**:
```
health_score = max(0, 100 - (critical × 10 + high × 5 + medium × 2 + low × 0.5))
```

**Health Score Ranges**:
- 80-100: Excellent (green)
- 60-79: Good (blue)
- 40-59: Fair (yellow)
- 20-39: Poor (orange)
- 0-19: Critical (red)

**Field Descriptions**:
- `project_id`: Project UUID
- `project_name`: Project name
- `contract_count`: Number of contracts in project
- `total_scans`: Total scans across all contracts
- `total_vulnerabilities`: Total vulnerabilities found
- `health_score`: Calculated health score (0-100)
- `last_scan_date`: Timestamp of most recent scan
- `avg_vulnerabilities_per_contract`: Average vulnerabilities per contract

**Notes**:
- Projects sorted by health score (worst first)
- User-scoped data
- Includes all projects regardless of date range

---

### GET /analytics/summary

Get a comprehensive analytics summary combining all metrics.

**Authentication**: Required

**Response** (200 OK):
```json
{
  "tool_effectiveness": {
    "tools": [...],
    "total_tools": 5,
    "date_range": "Last 30 days"
  },
  "vulnerability_trends": {
    "trends": [...],
    "total_days": 30,
    "summary": {...}
  },
  "project_comparison": {
    "projects": [...],
    "total_projects": 3,
    "global_stats": {...}
  },
  "generated_at": "2025-10-17T21:30:00Z"
}
```

**Field Descriptions**:
- `tool_effectiveness`: Complete tool effectiveness data (last 30 days)
- `vulnerability_trends`: Complete trend data (last 30 days)
- `project_comparison`: Complete project comparison data
- `generated_at`: Timestamp when summary was generated

**Notes**:
- Combines data from all three analytics endpoints
- Fixed 30-day window for tool effectiveness and trends
- Efficient single-request option for dashboard loading
- Ideal for dashboard initialization

---

## Search (Phase 4.5 - December 2025)

Endpoints for searching across all entities in the platform.

### GET /search/quick

Quick search for command palette - searches projects, contracts (including source code), and vulnerabilities.

**Authentication**: Required

**Query Parameters**:
- `q` (string, required, min: 2, max: 100) - Search query
- `limit` (integer, default: 10, min: 1, max: 20) - Max results per entity type

**Response** (200 OK):
```json
{
  "query": "transfer",
  "results": [
    {
      "id": "598d95dc-a1fa-4814-8c18-eae9d7761ebd",
      "type": "contract",
      "title": "Token.sol",
      "subtitle": "Line 87: function transfer(address to, uint256 amount)",
      "url": "/contracts/598d95dc-a1fa-4814-8c18-eae9d7761ebd"
    },
    {
      "id": "9f584406-9a51-47d4-9415-1ea1720e02b2",
      "type": "vulnerability",
      "title": "ETH transferred without address checks",
      "subtitle": "CRITICAL - aderyn",
      "url": "/vulnerabilities/9f584406-9a51-47d4-9415-1ea1720e02b2"
    }
  ],
  "total": 10,
  "query_time_ms": 12.5
}
```

**Result Types**:
| Type | Icon | Subtitle Content |
|------|------|------------------|
| `project` | Folder | Description (truncated) |
| `contract` | Document | Line number + code snippet from source |
| `scan` | Clock | Scanner used |
| `vulnerability` | Shield | Severity - Scanner ID |

**Source Code Search**:
When searching contracts, the endpoint searches the `source_code` field and extracts:
- Line number of first match
- Code snippet (up to 60 chars) showing the match context

**Example Request**:
```bash
curl -X GET "http://localhost:8000/api/v1/search/quick?q=reentrancy&limit=5" \
  -H "Authorization: Bearer <token>"
```

**Performance**:
- Typical response: 10-50ms
- Source code search: 100-350ms (first query)
- Results cached for subsequent queries

**Error Responses**:
- `400` - Query too short (min 2 characters) or too long (max 100)
- `401` - Unauthorized

**Notes**:
- Searches are scoped to the authenticated user's data only
- Case-insensitive matching
- Used by the Command Palette (Cmd+K / Ctrl+K) in the dashboard

### POST /search

Advanced search with multiple filters across contracts, scans, and vulnerabilities.

**Authentication**: Required

**Request Body**:
```json
{
  "query": "reentrancy",
  "languages": ["solidity"],
  "severities": ["critical", "high"],
  "scanner_ids": ["slither", "aderyn"],
  "date_from": "2025-01-01T00:00:00Z",
  "date_to": "2025-12-31T23:59:59Z",
  "has_critical": true,
  "skip": 0,
  "limit": 50,
  "sort_by": "created_at",
  "sort_order": "desc"
}
```

**Filter Options**:
| Field | Type | Description |
|-------|------|-------------|
| `query` | string | Text search (contract names, vulnerability titles) |
| `project_ids` | UUID[] | Filter by projects |
| `contract_ids` | UUID[] | Filter by contracts |
| `languages` | string[] | Contract languages (solidity, vyper, rust, move, cairo) |
| `networks` | string[] | Blockchain networks (ethereum, polygon, bsc) |
| `scanner_ids` | string[] | Scanners (slither, mythril, aderyn) |
| `categories` | string[] | Vulnerability categories |
| `min_confidence` | float | Minimum confidence (0.0-1.0) |
| `severities` | string[] | Severity levels (critical, high, medium, low) |
| `vulnerability_statuses` | string[] | Status (open, acknowledged, fixed, false_positive) |
| `scan_statuses` | string[] | Scan status (queued, running, completed, failed) |
| `date_from` | datetime | Start date filter |
| `date_to` | datetime | End date filter |
| `min_vulnerability_count` | int | Minimum vulnerabilities |
| `max_vulnerability_count` | int | Maximum vulnerabilities |
| `has_critical` | bool | Has critical vulnerabilities |
| `has_source_code` | bool | Has source code attached |

**Pagination**:
- `skip` (int, default: 0) - Offset
- `limit` (int, default: 100, max: 1000) - Page size

**Sorting**:
- `sort_by` - Field to sort (created_at, name, vulnerability_count, severity)
- `sort_order` - Direction (asc, desc)

**Response** (200 OK):
```json
{
  "contracts": [...],
  "scans": [...],
  "vulnerabilities": [...],
  "total_contracts": 15,
  "total_scans": 47,
  "total_vulnerabilities": 123,
  "page": 1,
  "page_size": 100,
  "query_time_ms": 45.2
}
```

---

## Contract Structure (Phase 3.4 - November 28, 2025)

Endpoints for contract structure analysis - extracting functions, events, and state variables from Solidity contracts.

### GET /contracts/{contract_id}/structure

Get complete contract structure including functions, events, and state variables.

**Authentication**: Required

**Path Parameters**:
- `contract_id` (UUID) - Contract ID

**Response** (200 OK):
```json
{
  "contract_id": "uuid",
  "contract_name": "MyToken",
  "analysis_date": "2025-11-28T20:00:00Z",
  "functions": [
    {
      "id": "uuid",
      "name": "transfer",
      "selector": "0xa9059cbb",
      "visibility": "public",
      "state_mutability": "nonpayable",
      "is_constructor": false,
      "is_fallback": false,
      "is_receive": false,
      "parameters": [
        {"name": "to", "type": "address", "storage_location": null},
        {"name": "amount", "type": "uint256", "storage_location": null}
      ],
      "return_types": ["bool"],
      "modifiers": [],
      "start_line": 42,
      "end_line": 50
    }
  ],
  "events": [
    {
      "id": "uuid",
      "name": "Transfer",
      "signature": "Transfer(address,address,uint256)",
      "topic0": "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
      "parameters": [
        {"name": "from", "type": "address", "indexed": true},
        {"name": "to", "type": "address", "indexed": true},
        {"name": "amount", "type": "uint256", "indexed": false}
      ],
      "anonymous": false,
      "start_line": 12
    }
  ],
  "state_variables": [
    {
      "id": "uuid",
      "name": "totalSupply",
      "type_name": "uint256",
      "visibility": "public",
      "mutability": null,
      "storage_slot": 0,
      "initial_value": null,
      "start_line": 8
    }
  ],
  "summary": {
    "total_functions": 10,
    "public_functions": 5,
    "external_functions": 2,
    "internal_functions": 2,
    "private_functions": 1,
    "total_events": 3,
    "total_state_variables": 5,
    "constant_variables": 1,
    "immutable_variables": 1
  },
  "parse_errors": []
}
```

**Status Codes**:
- `200` OK - Structure retrieved
- `404` Not Found - Contract not found
- `403` Forbidden - Not authorized to access this contract

---

### GET /contracts/{contract_id}/functions

Get all functions for a contract.

**Authentication**: Required

**Path Parameters**:
- `contract_id` (UUID) - Contract ID

**Response** (200 OK):
```json
{
  "contract_id": "uuid",
  "total": 10,
  "functions": [
    {
      "id": "uuid",
      "name": "transfer",
      "selector": "0xa9059cbb",
      "visibility": "public",
      "state_mutability": "nonpayable",
      "is_constructor": false,
      "is_fallback": false,
      "is_receive": false,
      "parameters": [
        {"name": "to", "type": "address", "storage_location": null},
        {"name": "amount", "type": "uint256", "storage_location": null}
      ],
      "return_types": ["bool"],
      "modifiers": [],
      "start_line": 42,
      "end_line": 50
    }
  ]
}
```

---

### GET /contracts/{contract_id}/events

Get all events for a contract.

**Authentication**: Required

**Path Parameters**:
- `contract_id` (UUID) - Contract ID

**Response** (200 OK):
```json
{
  "contract_id": "uuid",
  "total": 3,
  "events": [
    {
      "id": "uuid",
      "name": "Transfer",
      "signature": "Transfer(address,address,uint256)",
      "topic0": "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
      "parameters": [
        {"name": "from", "type": "address", "indexed": true},
        {"name": "to", "type": "address", "indexed": true},
        {"name": "amount", "type": "uint256", "indexed": false}
      ],
      "anonymous": false,
      "start_line": 12
    }
  ]
}
```

---

### GET /contracts/{contract_id}/state-variables

Get all state variables for a contract.

**Authentication**: Required

**Path Parameters**:
- `contract_id` (UUID) - Contract ID

**Response** (200 OK):
```json
{
  "contract_id": "uuid",
  "total": 5,
  "state_variables": [
    {
      "id": "uuid",
      "name": "totalSupply",
      "type_name": "uint256",
      "visibility": "public",
      "mutability": null,
      "storage_slot": 0,
      "initial_value": null,
      "start_line": 8
    },
    {
      "id": "uuid",
      "name": "MAX_SUPPLY",
      "type_name": "uint256",
      "visibility": "public",
      "mutability": "constant",
      "storage_slot": null,
      "initial_value": "1000000 * 10**18",
      "start_line": 9
    }
  ]
}
```

---

### POST /contracts/{contract_id}/analyze-structure

Trigger structure analysis to extract functions, events, and state variables.

**Authentication**: Required

**Path Parameters**:
- `contract_id` (UUID) - Contract ID

**Request Body** (optional):
```json
{
  "force": false
}
```

**Field Descriptions**:
- `force` (boolean, default: false) - Force re-analysis even if already analyzed

**Response** (200 OK):
```json
{
  "contract_id": "uuid",
  "status": "completed",
  "message": "Contract structure analysis completed successfully",
  "functions_count": 10,
  "events_count": 3,
  "variables_count": 5,
  "parse_errors": []
}
```

**Response (Already Analyzed)**:
```json
{
  "contract_id": "uuid",
  "status": "already_analyzed",
  "message": "Contract structure was already analyzed. Use force=true to re-analyze.",
  "functions_count": 10,
  "events_count": 3,
  "variables_count": 5,
  "parse_errors": []
}
```

**Response (Failed)**:
```json
{
  "contract_id": "uuid",
  "status": "failed",
  "message": "Structure analysis is currently only supported for Solidity contracts. Contract language: vyper",
  "functions_count": 0,
  "events_count": 0,
  "variables_count": 0,
  "parse_errors": ["Unsupported language: vyper"]
}
```

**Status Codes**:
- `200` OK - Analysis completed or already analyzed
- `404` Not Found - Contract not found
- `403` Forbidden - Not authorized to access this contract

**Notes**:
- Currently only supports Solidity contracts
- Uses py-solc-x for AST parsing with regex fallback
- Computes function selectors (4-byte keccak256)
- Computes event topic0 hashes
- Extracts visibility, mutability, parameters, and modifiers

---

## Contract Analytics

### GET /contracts/{contract_id}/analytics/code-quality

Get code quality and linting metrics for a specific contract.

**Authentication**: Required

**Path Parameters**:
- `contract_id` (UUID) - Contract ID

**Response** (200 OK):
```json
{
  "score": 85,
  "totalIssues": 12,
  "errorCount": 2,
  "warningCount": 5,
  "infoCount": 5,
  "topIssues": [
    {
      "id": "issue-1",
      "rule": "reentrancy-eth",
      "severity": "error",
      "message": "Reentrancy vulnerability detected",
      "line": 42,
      "column": 15,
      "file": "MyContract.sol",
      "category": "security"
    }
  ],
  "lastUpdated": "2025-10-18T22:00:00Z"
}
```

**Field Descriptions**:
- `score`: Overall code quality score (0-100, higher is better)
- `totalIssues`: Total number of linting/quality issues found
- `errorCount`: Number of error-level issues (critical problems)
- `warningCount`: Number of warning-level issues (should fix)
- `infoCount`: Number of info-level issues (suggestions)
- `topIssues`: Array of up to 10 most critical issues
- `lastUpdated`: Timestamp when metrics were last calculated

**Issue Object**:
- `id`: Unique identifier for the issue
- `rule`: Rule/detector name that found the issue
- `severity`: `error`, `warning`, or `info`
- `message`: Human-readable description
- `line`: Line number in source code
- `column`: Column number (optional)
- `file`: Filename (for multi-file contracts)
- `category`: Issue category (e.g., `security`, `best_practice`, `gas-optimization`)

**Score Calculation**:
```
score = max(0, 100 - (errors × 10 + warnings × 5 + info × 1))
```

**Status Codes**:
- `200` OK - Code quality metrics returned
- `404` Not Found - Contract not found
- `403` Forbidden - Not authorized to access this contract

---

### GET /contracts/{contract_id}/analytics/gas-usage

Get gas usage analysis and optimization recommendations for a contract.

**Authentication**: Required

**Path Parameters**:
- `contract_id` (UUID) - Contract ID

**Response** (200 OK):
```json
{
  "totalGasUsed": 245000,
  "averageGasPerFunction": 49000,
  "mostExpensiveFunction": "complexCalculation",
  "optimizationPotential": 35,
  "functions": [
    {
      "name": "complexCalculation",
      "gasUsed": 120000,
      "executionCount": 15,
      "optimization": "high",
      "suggestions": [
        "Consider caching repeated calculations",
        "Use memory instead of storage where possible"
      ]
    },
    {
      "name": "withdraw",
      "gasUsed": 45000,
      "executionCount": 8,
      "optimization": "medium",
      "suggestions": [
        "Optimize loop iterations"
      ]
    }
  ],
  "lastUpdated": "2025-10-18T22:00:00Z"
}
```

**Field Descriptions**:
- `totalGasUsed`: Total estimated gas usage across all functions
- `averageGasPerFunction`: Average gas per function
- `mostExpensiveFunction`: Name of function with highest gas usage
- `optimizationPotential`: Estimated gas savings potential (0-100%)
- `functions`: Per-function gas breakdown
- `lastUpdated`: Timestamp when metrics were calculated

**Function Gas Object**:
- `name`: Function name
- `gasUsed`: Estimated gas usage for this function
- `executionCount`: Number of times function was analyzed (optional)
- `optimization`: Priority level - `optimal`, `low`, `medium`, or `high`
- `suggestions`: Array of gas optimization recommendations

**Optimization Priority Levels**:
- `optimal`: No optimization needed (< 21000 gas)
- `low`: Minor optimizations possible (21000-50000 gas)
- `medium`: Moderate optimizations recommended (50000-100000 gas)
- `high`: Significant optimizations needed (> 100000 gas)

**Status Codes**:
- `200` OK - Gas metrics returned
- `404` Not Found - Contract not found
- `403` Forbidden - Not authorized to access this contract

---

### GET /contracts/{contract_id}/analytics

Get combined code quality and gas metrics for a contract in a single request.

**Authentication**: Required

**Path Parameters**:
- `contract_id` (UUID) - Contract ID

**Response** (200 OK):
```json
{
  "codeQuality": {
    "score": 85,
    "totalIssues": 12,
    "errorCount": 2,
    "warningCount": 5,
    "infoCount": 5,
    "topIssues": [...],
    "lastUpdated": "2025-10-18T22:00:00Z"
  },
  "gasMetrics": {
    "totalGasUsed": 245000,
    "averageGasPerFunction": 49000,
    "mostExpensiveFunction": "complexCalculation",
    "optimizationPotential": 35,
    "functions": [...],
    "lastUpdated": "2025-10-18T22:00:00Z"
  }
}
```

**Field Descriptions**:
- `codeQuality`: Complete code quality metrics object
- `gasMetrics`: Complete gas usage metrics object

**Notes**:
- Combines both code quality and gas analytics in one request
- More efficient than making two separate API calls
- Ideal for contract detail pages in UI
- Both sections may be `null` if no scan data exists

**Status Codes**:
- `200` OK - Analytics returned (sections may be null)
- `404` Not Found - Contract not found
- `403` Forbidden - Not authorized to access this contract

---

## File Upload

### POST /upload

Upload smart contract source file or multi-file archive for analysis.

**Authentication**: Required

**Request**: multipart/form-data
- `file` (file, required) - Smart contract file or archive
- `contract_name` (string, optional) - Contract name (defaults to filename)
- `network` (string, optional) - Blockchain network (default: ethereum)

**Supported Languages** (Phase 3.1a - November 15, 2025):
- **Solidity**: `.sol`
- **Vyper**: `.vy`
- **Rust/Solana**: `.rs`
- **Cairo (StarkNet)**: `.cairo`
- **Archives**: `.zip`, `.tar`, `.tar.gz`, `.tgz`

**Example (curl)**:
```bash
# Single file upload
curl -X POST http://localhost:8000/api/v1/upload \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@MyContract.sol" \
  -F "contract_name=MyToken" \
  -F "network=ethereum"

# Multi-file archive upload
curl -X POST http://localhost:8000/api/v1/upload \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@my-project.zip"
```

**Response** (201 Created):
```json
{
  "contract_id": "uuid",
  "filename": "MyContract.sol",
  "status": "success",
  "message": "File uploaded: 250 lines of code (solidity, confidence: 100%)",
  "is_multi_file": false,
  "file_count": 1,
  "files": [
    {
      "path": "MyContract.sol",
      "size": 12345,
      "lines_of_code": 250
    }
  ],
  "main_file_path": null,
  "framework": "plain",
  "framework_config": null
}
```

**Multi-File Archive Response** (Phase 3.2):
```json
{
  "contract_id": "uuid",
  "filename": "my-foundry-project.zip",
  "status": "success",
  "message": "Archive uploaded [foundry]: 12 files, 500 total lines of code",
  "is_multi_file": true,
  "file_count": 12,
  "files": [
    {"path": "src/Token.sol", "size": 1234, "lines_of_code": 50},
    {"path": "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol", "size": 5678, "lines_of_code": 200}
  ],
  "main_file_path": "src/Token.sol",
  "framework": "foundry",
  "framework_config": {
    "solc_version": "0.8.20",
    "src_dir": "src",
    "remappings": ["@openzeppelin/=lib/openzeppelin-contracts/"]
  }
}
```

**Tier-Based File Size Limits** (Phase 3.1a):

| Tier | Single File | Archive |
|------|-------------|---------|
| Free | 1 MB | 5 MB |
| Pro | 5 MB | 25 MB |
| Enterprise | 10 MB | 50 MB |
| Enterprise Broker | 10 MB | 50 MB |

**Files-per-Scan Limits** (Phase 3.1a):

| Tier | Max Files per Archive |
|------|-----------------------|
| Free | 25 files |
| Pro | 100 files |
| Enterprise | Unlimited |
| Enterprise Broker | Unlimited |

**Framework Support** (Phase 3.2 - November 25, 2025):

Automatic detection of Foundry and Hardhat project structures with smart dependency extraction:

| Framework | Detection | Config Parsed |
|-----------|-----------|---------------|
| Foundry | `foundry.toml` present | solc_version, src_dir, remappings, optimizer settings |
| Hardhat | `hardhat.config.js` or `.ts` present | solc_version, sources_path, dependencies |
| Plain | No framework files | N/A |

**Smart Dependency Extraction**:
- Only imported files are extracted from `lib/` (Foundry) or `node_modules/` (Hardhat)
- OpenZeppelin projects (200+ files) → ~12 files extracted
- Free tier (25 files) can upload large framework projects
- Import remappings automatically resolved (`@openzeppelin/`, `forge-std/`, etc.)

**Status Codes**:
- `201` Created - File uploaded and contract created
- `400` Bad Request - Invalid file type or encoding
- `402` Payment Required - Too many files (exceeds tier limit)
- `409` Conflict - Contract name already exists for user
- `413` Request Entity Too Large - File size exceeds tier limit
- `422` Unprocessable Entity - File parsing failed
- `500` Internal Server Error - Upload processing failed

**Error Response (Contract Name Exists - HTTP 409)**:
```json
{
  "detail": {
    "error": "contract_name_exists",
    "message": "A contract named 'MyToken' already exists",
    "existing_contract": {
      "id": "uuid",
      "name": "MyToken",
      "created_at": "2025-12-31T00:00:00Z",
      "status": "uploaded",
      "is_multi_file": false,
      "file_count": 1
    }
  }
}
```

**Error Response (File Too Large - HTTP 413)**:
```json
{
  "detail": {
    "error": "file_too_large",
    "message": "File size (2.5 MB) exceeds free tier limit of 1 MB for files",
    "tier": "free",
    "file_size_mb": 2.5,
    "max_size_mb": 1,
    "upgrade_url": "/pricing",
    "upgrade_message": "Upgrade to Pro for larger file uploads"
  }
}
```

**Error Response (Too Many Files - HTTP 402)**:
```json
{
  "detail": {
    "error": "too_many_files",
    "message": "Archive contains 30 files, exceeding free tier limit of 25 files per scan",
    "tier": "free",
    "file_count": 30,
    "max_files_per_scan": 25,
    "upgrade_url": "/pricing",
    "upgrade_message": "Upgrade to Pro for up to 100 files per scan, or Enterprise for unlimited files"
  }
}
```

---

## Users

### GET /users/me

Get current authenticated user profile (basic).

**Authentication**: Required (Supabase JWT)

**Response** (200 OK):
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "is_active": true,
  "created_at": "2025-10-01T10:00:00Z"
}
```

**Status Codes**:
- `200` OK - User profile retrieved
- `401` Unauthorized - Invalid or expired token

---

### GET /users/me/enhanced

Get enhanced user profile with tier and quota information.

**Authentication**: Required (Supabase JWT)

**Response** (200 OK):
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "is_active": true,
  "tier": "free",
  "tier_updated_at": "2025-11-01T10:00:00Z",
  "created_at": "2025-10-01T10:00:00Z",
  "quota": {
    "tier": "free",
    "monthly_scan_limit": 10,
    "monthly_scans_used": 3,
    "scans_remaining": 7,
    "percentage_used": 30.0,
    "max_files_per_scan": 25,
    "webhooks_enabled": false,
    "api_access_enabled": false,
    "scan_priority": 25,
    "quota_reset_at": "2025-12-01T00:00:00Z"
  }
}
```

**Field Descriptions**:
- `tier`: User tier (free, pro, enterprise, enterprise_broker)
- `quota.monthly_scan_limit`: Monthly scan limit (-1 for unlimited)
- `quota.monthly_scans_used`: Scans used this month
- `quota.scans_remaining`: Remaining scans (null if unlimited)
- `quota.percentage_used`: Percentage of quota used (0-100)
- `quota.max_files_per_scan`: Maximum files per scan (-1 for unlimited)
- `quota.webhooks_enabled`: Webhooks feature enabled
- `quota.api_access_enabled`: API access enabled
- `quota.scan_priority`: Scan queue priority (0=highest, 100=lowest)
- `quota.quota_reset_at`: Next quota reset date

**Tier Limits**:

| Tier | Monthly Scans | Files/Scan | Priority | Webhooks | API Access |
|------|--------------|------------|----------|----------|------------|
| Free | 10 | 25 | 25 (low) | No | No |
| Pro | Unlimited | 100 | 50 (medium) | Yes | Yes |
| Enterprise | Unlimited | Unlimited | 75 (high) | Yes | Yes |
| Enterprise Broker | Unlimited | Unlimited | 100 (highest) | Yes | Yes |

**Status Codes**:
- `200` OK - Enhanced profile retrieved
- `401` Unauthorized - Invalid or expired token
- `404` Not Found - Quota information not found

**Use Case**:
Frontend dashboard display showing user tier, quota usage with progress bar, and upgrade prompts when approaching limits.

---

### GET /users/quota

Get detailed quota information for current user.

**Authentication**: Required (Supabase JWT)

**Response** (200 OK):
```json
{
  "tier": "free",
  "monthly_scan_limit": 10,
  "monthly_scans_used": 8,
  "scans_remaining": 2,
  "percentage_used": 80.0,
  "max_files_per_scan": 25,
  "webhooks_enabled": false,
  "api_access_enabled": false,
  "scan_priority": 25,
  "quota_reset_at": "2025-12-01T00:00:00Z"
}
```

**Status Codes**:
- `200` OK - Quota information retrieved
- `401` Unauthorized - Invalid or expired token
- `404` Not Found - Quota not found (contact support)

**Quota Enforcement**:
- Scan creation blocked when monthly_scans_used >= monthly_scan_limit
- Returns 429 Too Many Requests with upgrade prompt
- File count validation before scan creation
- Priority queue based on tier

**Use Case**:
- Dashboard quota widget display
- Upgrade banner triggers (50%, 80%, 100% usage)
- Scan creation quota validation
- Analytics tracking

---

### GET /users/me/activity

**NEW** (December 10, 2025) - Get user's activity log with pagination and filtering (Phase 3.1b - Task 21).

**Authentication**: Required (Supabase JWT)

**Query Parameters**:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `page` | integer | 1 | Page number (1+) |
| `page_size` | integer | 20 | Items per page (1-100) |
| `activity_type` | string | null | Filter by activity type |

**Activity Types**:
- `file_upload` - File uploaded to platform
- `contract_created` - New contract created
- `contract_deleted` - Contract deleted
- `scan_started` - Security scan initiated
- `scan_completed` - Security scan completed successfully
- `scan_failed` - Security scan failed
- `payment` - Payment transaction
- `credit_purchase` - Credits purchased
- `credit_used` - Credits consumed for scan

**Response** (200 OK):
```json
{
  "entries": [
    {
      "id": "uuid",
      "activity_type": "scan_completed",
      "description": "Slither scan completed with 5 vulnerabilities",
      "contract_id": "uuid",
      "scan_id": "uuid",
      "scanner_type": "slither",
      "scan_status": "completed",
      "credits_used": 1,
      "payment_amount": null,
      "payment_currency": null,
      "metadata": null,
      "created_at": "2025-12-10T10:00:00Z"
    },
    {
      "id": "uuid",
      "activity_type": "credit_purchase",
      "description": "Purchased 50 credits (Pro package)",
      "contract_id": null,
      "scan_id": null,
      "scanner_type": null,
      "scan_status": null,
      "credits_used": -50,
      "payment_amount": "35.00",
      "payment_currency": "USDC",
      "metadata": {"package_name": "Pro"},
      "created_at": "2025-12-10T09:00:00Z"
    }
  ],
  "total_count": 50,
  "page": 1,
  "page_size": 20,
  "total_pages": 3,
  "summary": {
    "scans_completed": 25,
    "scans_failed": 2,
    "total_credits_used": 27,
    "total_payments": 35.00
  }
}
```

**Response Fields**:
- `entries`: Array of activity log entries
- `total_count`: Total number of entries matching the filter
- `page`: Current page number
- `page_size`: Items per page
- `total_pages`: Total number of pages
- `summary`: Aggregated statistics for the user

**Entry Fields**:
- `id`: Unique activity identifier
- `activity_type`: Type of activity (see enum above)
- `description`: Human-readable description
- `contract_id`: Related contract ID (nullable, for navigation)
- `scan_id`: Related scan ID (nullable, for navigation)
- `scanner_type`: Scanner tool name when applicable
- `scan_status`: Scan completion status when applicable
- `credits_used`: Credits consumed (positive) or added (negative for purchases)
- `payment_amount`: Payment amount when applicable
- `payment_currency`: Payment currency (USD, USDC)
- `metadata`: Additional context data (JSONB)
- `created_at`: Activity timestamp

**Summary Fields**:
- `scans_completed`: Total completed scans
- `scans_failed`: Total failed scans
- `total_credits_used`: Total credits consumed
- `total_payments`: Total payment amount (USD)

**Status Codes**:
- `200` OK - Activity log retrieved
- `401` Unauthorized - Invalid or expired token

**Use Case**:
- Activity Log page in dashboard (`/activity`)
- User history tracking
- Credit usage auditing
- Scan history review

**Example (curl)**:
```bash
# Get first page of all activities
curl -X GET "http://localhost:8000/api/v1/users/me/activity" \
  -H "Authorization: Bearer $TOKEN"

# Filter by scan completions
curl -X GET "http://localhost:8000/api/v1/users/me/activity?activity_type=scan_completed" \
  -H "Authorization: Bearer $TOKEN"

# Get page 2 with 50 items
curl -X GET "http://localhost:8000/api/v1/users/me/activity?page=2&page_size=50" \
  -H "Authorization: Bearer $TOKEN"
```

---

## Error Responses

All endpoints return consistent error responses:

```json
{
  "detail": "Error message describing what went wrong"
}
```

### Common Status Codes

- `200` OK - Request successful
- `201` Created - Resource created successfully
- `400` Bad Request - Invalid request data
- `401` Unauthorized - Missing or invalid authentication
- `403` Forbidden - Authenticated but not authorized for this resource
- `404` Not Found - Resource does not exist
- `422` Unprocessable Entity - Validation failed
- `500` Internal Server Error - Server-side error

### Error Examples

**401 Unauthorized**:
```json
{
  "detail": "Not authenticated"
}
```

**404 Not Found**:
```json
{
  "detail": "Contract with ID abc123 not found"
}
```

**422 Validation Error**:
```json
{
  "detail": [
    {
      "loc": ["body", "email"],
      "msg": "value is not a valid email address",
      "type": "value_error.email"
    }
  ]
}
```

---

## Payments (Phase 3.4 - x402 Pay-Per-Scan)

x402 payment integration for pay-per-scan with USDC on Base blockchain.

### GET /payments/credits

Get current user's credit balance.

**Authentication**: Required (Supabase JWT)

**Response** (200 OK):
```json
{
  "balance": 25,
  "total_purchased": 50,
  "total_used": 25,
  "has_credits": true
}
```

**Field Descriptions**:
- `balance`: Current available credits
- `total_purchased`: Total credits ever purchased
- `total_used`: Total credits ever used
- `has_credits`: Whether user has available credits

**Status Codes**:
- `200` OK - Balance retrieved
- `401` Unauthorized - Invalid or expired token

---

### POST /payments/credits/use

Use a credit for a specific scan.

**Authentication**: Required (Supabase JWT)

**Request Body**:
```json
{
  "scan_id": "uuid"
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "credits_used": 1,
  "new_balance": 24,
  "scan_id": "uuid",
  "message": "Credit successfully applied to scan"
}
```

**Status Codes**:
- `200` OK - Credit applied
- `401` Unauthorized - Invalid token
- `402` Payment Required - Insufficient credits
- `409` Conflict - Failed to use credit

---

### GET /payments/credits/history

Get credit transaction history.

**Authentication**: Required (Supabase JWT)

**Query Parameters**:
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `page` | integer | 1 | Page number (1+) |
| `page_size` | integer | 20 | Items per page (1-100) |

**Response** (200 OK):
```json
{
  "transactions": [
    {
      "id": "uuid",
      "user_id": "uuid",
      "credits": -1,
      "balance_after": 24,
      "transaction_type": "scan_usage",
      "payment_transaction_id": null,
      "scan_id": "uuid",
      "description": "Scan credit used",
      "created_at": "2025-12-01T10:00:00Z"
    }
  ],
  "total": 15,
  "page": 1,
  "page_size": 20
}
```

**Transaction Types**:
- `purchase` - Credits purchased via x402 payment
- `scan_usage` - Credits used for a scan
- `refund` - Credits refunded (e.g., failed scan)
- `gift` - Credits granted by admin

---

### GET /payments/packages

Get available credit packages. No authentication required.

**Response** (200 OK):
```json
{
  "packages": [
    {
      "id": "uuid",
      "name": "Starter",
      "credits": 10,
      "price_usd": "8.00",
      "discount_percent": 20,
      "effective_price": "8.00",
      "price_per_credit": "0.80",
      "is_active": true,
      "created_at": "2025-12-01T00:00:00Z"
    },
    {
      "id": "uuid",
      "name": "Pro",
      "credits": 50,
      "price_usd": "35.00",
      "discount_percent": 30,
      "effective_price": "35.00",
      "price_per_credit": "0.70",
      "is_active": true,
      "created_at": "2025-12-01T00:00:00Z"
    },
    {
      "id": "uuid",
      "name": "Enterprise",
      "credits": 200,
      "price_usd": "120.00",
      "discount_percent": 40,
      "effective_price": "120.00",
      "price_per_credit": "0.60",
      "is_active": true,
      "created_at": "2025-12-01T00:00:00Z"
    }
  ],
  "per_scan_price": "1.00"
}
```

---

### GET /payments/prices

Get current scan pricing tiers. No authentication required.

**Response** (200 OK):
```json
{
  "per_scan": {
    "simple": { "files": "1-5", "price_usd": "0.50" },
    "standard": { "files": "6-25", "price_usd": "1.00" },
    "complex": { "files": "26-100", "price_usd": "2.00" },
    "large": { "files": "100+", "price_usd": "5.00" }
  },
  "default_price": "1.00",
  "token": "USDC",
  "network": "base",
  "chain_id": 8453
}
```

**Complexity Tiers**:
| Complexity | File Count | Price USD |
|------------|------------|-----------|
| Simple | 1-5 | $0.50 |
| Standard | 6-25 | $1.00 |
| Complex | 26-100 | $2.00 |
| Large | 100+ | $5.00 |

---

### POST /payments/initiate

Initiate credit package purchase. Returns x402 payment details.

**Authentication**: Required (Supabase JWT)

**Request Body**:
```json
{
  "package_id": "uuid"
}
```

**Response** (200 OK):
```json
{
  "payment_info": {
    "amount": "35.00",
    "token": "USDC",
    "network": "base",
    "chain_id": 8453,
    "recipient": "0x1234...",
    "payment_id": "bso_abc123...",
    "expires_at": "2025-12-01T10:15:00Z",
    "message": "BlockSecOps Credits: Pro (50 scans)"
  },
  "x402_accepts": [
    {
      "scheme": "exact",
      "network": "base",
      "maxAmountRequired": "35.00",
      "resource": "0x1234...",
      "description": "USDC payment on Base",
      "mimeType": "application/json",
      "payTo": "0x1234...",
      "maxTimeoutSeconds": 900,
      "asset": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
      "extra": { "name": "USDC", "version": "1" }
    }
  ],
  "package": {
    "id": "uuid",
    "name": "Pro",
    "credits": 50,
    "price_usd": 35.00,
    "discount_percent": 30
  }
}
```

**Status Codes**:
- `200` OK - Payment request created
- `401` Unauthorized - Invalid token
- `404` Not Found - Package not found

---

### POST /payments/verify

Verify a completed blockchain payment and add credits.

**Authentication**: Required (Supabase JWT)

**Request Body**:
```json
{
  "tx_hash": "0xabc123..."
}
```

**Response** (200 OK):
```json
{
  "verified": true,
  "tx_hash": "0xabc123...",
  "message": "Payment verified successfully"
}
```

**Status Codes**:
- `200` OK - Payment verified
- `401` Unauthorized - Invalid token
- `402` Payment Required - Verification failed

---

### GET /payments/history

Get payment transaction history.

**Authentication**: Required (Supabase JWT)

**Query Parameters**:
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `page` | integer | 1 | Page number (1+) |
| `page_size` | integer | 20 | Items per page (1-100) |

**Response** (200 OK):
```json
{
  "transactions": [
    {
      "id": "uuid",
      "user_id": "uuid",
      "payment_type": "credits",
      "amount_usd": "35.0000",
      "token": "USDC",
      "network": "base",
      "tx_hash": "0xabc123...",
      "from_address": "0x5678...",
      "to_address": "0x1234...",
      "block_number": 12345678,
      "x402_payment_id": "bso_abc123...",
      "status": "verified",
      "credits_purchased": 50,
      "package_id": "uuid",
      "scan_id": null,
      "verified_at": "2025-12-01T10:05:00Z",
      "created_at": "2025-12-01T10:00:00Z",
      "updated_at": "2025-12-01T10:05:00Z"
    }
  ],
  "total": 5,
  "page": 1,
  "page_size": 20
}
```

**Payment Status Values**:
- `pending` - Payment initiated, awaiting verification
- `verified` - Payment confirmed on blockchain
- `failed` - Payment verification failed
- `refunded` - Payment was refunded

---

### POST /payments/admin/gift (Admin Only)

Gift credits to a user. Requires superuser privileges.

**Authentication**: Required (Supabase JWT + is_superuser)

**Request Body**:
```json
{
  "user_id": "uuid",
  "credits": 10,
  "reason": "Beta tester reward"
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "user_id": "uuid",
  "credits_granted": 10,
  "new_balance": 35,
  "reason": "Beta tester reward",
  "granted_at": "2025-12-01T10:00:00Z"
}
```

**Status Codes**:
- `200` OK - Credits granted
- `401` Unauthorized - Invalid token
- `403` Forbidden - Not an admin

---

### GET /payments/admin/stats (Admin Only)

Get payment statistics. Requires superuser privileges.

**Authentication**: Required (Supabase JWT + is_superuser)

**Response** (200 OK):
```json
{
  "total_transactions": 150,
  "total_revenue_usd": "2500.00",
  "total_credits_sold": 2500,
  "total_credits_used": 1800,
  "per_scan_transactions": 50,
  "credit_purchase_transactions": 100,
  "pending_transactions": 5,
  "verified_transactions": 140,
  "failed_transactions": 5
}
```

**Status Codes**:
- `200` OK - Stats retrieved
- `401` Unauthorized - Invalid token
- `403` Forbidden - Not an admin

---

## Billing (Phase 8a - Stripe Integration)

Stripe-based subscription billing, invoices, and billing details management. Works alongside x402 credit payments.

### POST /billing/checkout

Create Stripe Checkout session for subscription purchase.

**Authentication**: Required (Supabase JWT)

**Request Body**:
```json
{
  "plan_tier": "startup",
  "billing_interval": "monthly",
  "success_url": "https://app.blocksecops.com/billing?success=true",
  "cancel_url": "https://app.blocksecops.com/billing?canceled=true"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| plan_tier | string | Yes | Plan: developer, startup, professional |
| billing_interval | string | Yes | monthly or annual |
| success_url | string | No | Redirect URL on success |
| cancel_url | string | No | Redirect URL on cancel |

**Response** (200 OK):
```json
{
  "checkout_url": "https://checkout.stripe.com/c/pay/cs_test_..."
}
```

**Status Codes**:
- `200` OK - Checkout session created
- `400` Bad Request - Invalid plan tier or interval
- `401` Unauthorized - Invalid token

---

### POST /billing/portal

Get Stripe Customer Portal URL for self-service billing management.

**Authentication**: Required (Supabase JWT)

**Query Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| return_url | string | No | URL to return after portal |

**Response** (200 OK):
```json
{
  "portal_url": "https://billing.stripe.com/p/session/..."
}
```

**Status Codes**:
- `200` OK - Portal session created
- `400` Bad Request - No Stripe customer found
- `401` Unauthorized - Invalid token

---

### GET /billing/subscription

Get current user's subscription details.

**Authentication**: Required (Supabase JWT)

**Response** (200 OK):
```json
{
  "id": "uuid",
  "plan_tier": "startup",
  "billing_interval": "monthly",
  "status": "active",
  "current_period_start": "2026-01-01T00:00:00Z",
  "current_period_end": "2026-02-01T00:00:00Z",
  "cancel_at_period_end": false,
  "canceled_at": null,
  "trial_end": null,
  "created_at": "2025-12-01T00:00:00Z"
}
```

Returns `null` if user has no subscription (free tier).

**Status Codes**:
- `200` OK - Subscription retrieved (or null)
- `401` Unauthorized - Invalid token

---

### POST /billing/subscription/cancel

Cancel current subscription.

**Authentication**: Required (Supabase JWT)

**Request Body**:
```json
{
  "cancel_immediately": false
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| cancel_immediately | boolean | false | If true, cancel now; if false, cancel at period end |

**Response** (200 OK):
```json
{
  "id": "uuid",
  "plan_tier": "startup",
  "status": "active",
  "cancel_at_period_end": true,
  ...
}
```

**Status Codes**:
- `200` OK - Subscription canceled
- `400` Bad Request - No active subscription
- `401` Unauthorized - Invalid token

---

### POST /billing/subscription/reactivate

Reactivate a subscription scheduled for cancellation.

**Authentication**: Required (Supabase JWT)

**Response** (200 OK):
```json
{
  "id": "uuid",
  "plan_tier": "startup",
  "status": "active",
  "cancel_at_period_end": false,
  ...
}
```

**Status Codes**:
- `200` OK - Subscription reactivated
- `400` Bad Request - Subscription not scheduled for cancellation
- `401` Unauthorized - Invalid token

---

### GET /billing/invoices

List user's Stripe invoices.

**Authentication**: Required (Supabase JWT)

**Query Parameters**:
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| limit | integer | 10 | Max invoices (1-100) |

**Response** (200 OK):
```json
{
  "invoices": [
    {
      "id": "in_xxx",
      "number": "INV-0001",
      "status": "paid",
      "amount_due": 99900,
      "amount_paid": 99900,
      "currency": "usd",
      "created": "2026-01-01T00:00:00Z",
      "period_start": "2026-01-01T00:00:00Z",
      "period_end": "2026-02-01T00:00:00Z",
      "invoice_pdf": "https://pay.stripe.com/invoice/...",
      "hosted_invoice_url": "https://invoice.stripe.com/..."
    }
  ],
  "total": 5
}
```

**Status Codes**:
- `200` OK - Invoices retrieved
- `401` Unauthorized - Invalid token

---

### GET /billing/invoices/{invoice_id}/pdf

Get PDF URL for a specific invoice.

**Authentication**: Required (Supabase JWT)

**Response** (200 OK):
```json
{
  "pdf_url": "https://pay.stripe.com/invoice/..."
}
```

**Status Codes**:
- `200` OK - PDF URL retrieved
- `404` Not Found - Invoice not found or not owned by user

---

### GET /billing/details

Get user's billing details (company, address, tax ID).

**Authentication**: Required (Supabase JWT)

**Response** (200 OK):
```json
{
  "id": "uuid",
  "user_id": "uuid",
  "company_name": "Acme Corp",
  "billing_email": "billing@acme.com",
  "address_line1": "123 Main St",
  "address_line2": "Suite 100",
  "city": "San Francisco",
  "state": "CA",
  "postal_code": "94102",
  "country": "US",
  "tax_id": "US123456789",
  "tax_id_type": "us_ein",
  "created_at": "2025-12-01T00:00:00Z",
  "updated_at": "2026-01-01T00:00:00Z"
}
```

Returns `null` if no billing details exist.

---

### PUT /billing/details

Update user's billing details.

**Authentication**: Required (Supabase JWT)

**Request Body**:
```json
{
  "company_name": "Acme Corp",
  "billing_email": "billing@acme.com",
  "address_line1": "123 Main St",
  "city": "San Francisco",
  "state": "CA",
  "postal_code": "94102",
  "country": "US",
  "tax_id": "US123456789",
  "tax_id_type": "us_ein"
}
```

**Response** (200 OK): Same as GET /billing/details

---

### GET /billing/history

Get combined billing history (Stripe invoices + x402 receipts).

**Authentication**: Required (Supabase JWT)

**Query Parameters**:
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| page | integer | 1 | Page number |
| page_size | integer | 10 | Items per page (1-50) |
| filter | string | all | Filter: all, subscriptions, credits |

**Response** (200 OK):
```json
{
  "items": [
    {
      "id": "in_xxx",
      "type": "stripe_invoice",
      "description": "Subscription - INV-0001",
      "amount": "$999.00",
      "currency": "USD",
      "status": "paid",
      "date": "2026-01-01T00:00:00Z",
      "download_url": "https://pay.stripe.com/invoice/..."
    },
    {
      "id": "uuid",
      "type": "x402_receipt",
      "description": "Credit Purchase - 25 credits",
      "amount": "$17.50",
      "currency": "USDC",
      "status": "verified",
      "date": "2025-12-15T00:00:00Z",
      "download_url": "/api/v1/payments/uuid/receipt",
      "payment_transaction_id": "uuid"
    }
  ],
  "total": 10,
  "page": 1,
  "page_size": 10
}
```

---

### GET /billing/plans

Get available subscription plans with pricing (public endpoint).

**Authentication**: Not required

**Response** (200 OK):
```json
{
  "plans": [
    {
      "tier": "free",
      "name": "Free",
      "scans_per_month": 5,
      "price_monthly": 0,
      "price_annual": 0,
      "features": ["5 scans per month", "Basic vulnerability detection"]
    },
    {
      "tier": "developer",
      "name": "Developer",
      "scans_per_month": 50,
      "price_monthly": 29,
      "price_annual": 290,
      "features": ["50 scans per month", "All scanners", "API access"]
    }
  ]
}
```

---

### POST /webhooks/stripe

Stripe webhook endpoint for subscription lifecycle events.

**Authentication**: Stripe signature verification (not JWT)

**Events Handled**:
- `checkout.session.completed` - Creates subscription record
- `customer.subscription.updated` - Updates status/period
- `customer.subscription.deleted` - Marks as canceled
- `invoice.payment_succeeded` - Ensures active status
- `invoice.payment_failed` - Marks as past_due

**Response** (200 OK):
```json
{
  "received": true
}
```

---

### GET /payments/{payment_id}/receipt

Download PDF receipt for x402 credit purchase.

**Authentication**: Required (Supabase JWT)

**Response** (200 OK):
- Content-Type: `application/pdf`
- Content-Disposition: `attachment; filename="blocksecops-receipt-BSO-260101-XXXX.pdf"`

**Status Codes**:
- `200` OK - PDF returned
- `404` Not Found - Payment not found or not owned by user
- `400` Bad Request - Payment not verified (no receipt available)

---

## Rate Limiting

**Current Limits** (per user, per hour):
- Authentication endpoints: 100 requests
- Read endpoints (GET): 1000 requests
- Write endpoints (POST/PATCH/DELETE): 100 requests
- File upload: 10 requests
- Payment endpoints: 50 requests

**Rate Limit Headers**:
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1633024800
```

---

## Testing

All endpoints have been tested and verified:

| Endpoint | Status | Test Script |
|----------|--------|-------------|
| POST /auth/login | ✅ Pass | /tmp/test-api.sh |
| GET /contracts | ✅ Pass | /tmp/test-api.sh |
| POST /contracts | ✅ Pass | /tmp/test-api.sh |
| GET /contracts/{id} | ✅ Pass | /tmp/test-api.sh |
| GET /scans | ✅ Pass | /tmp/test-scan-history.sh |
| POST /scans | ✅ Pass | /tmp/test-api.sh |
| GET /scans/{id} | ✅ Pass | /tmp/test-scan-history.sh |
| GET /vulnerabilities | ✅ Pass | /tmp/test-vulnerabilities.sh |
| GET /statistics/dashboard | ✅ Pass | /tmp/test-api.sh |
| GET /statistics/scan-history | ✅ Pass | /tmp/test-scan-history.sh |
| POST /upload | ✅ Pass | /tmp/test-upload.sh |
| GET /users/me | ✅ Pass | /tmp/test-api.sh |
| GET /payments/credits | ✅ Pass | API service |
| GET /payments/packages | ✅ Pass | API service |
| GET /payments/prices | ✅ Pass | API service |
| POST /payments/initiate | ✅ Pass | API service |
| POST /payments/verify | ✅ Pass | API service |
| POST /payments/credits/use | ✅ Pass | API service |
| GET /payments/credits/history | ✅ Pass | API service |
| GET /payments/history | ✅ Pass | API service |
| GET /users/me/activity | ✅ Pass | API service |
| GET /scans/compare | ✅ Pass | API service |

**Success Rate**: 23/23 (100%) - All endpoints tested and verified

---

## Interactive Documentation

The API includes auto-generated interactive documentation:

- **Swagger UI**: http://localhost:8001/docs
- **ReDoc**: http://localhost:8001/redoc

These provide:
- Live API testing
- Request/response examples
- Schema definitions
- Authentication testing

---

## Client Libraries

### TypeScript/JavaScript

```typescript
import { contractsApi } from '@/lib/api';

// List contracts
const contracts = await contractsApi.listContracts({ limit: 10 });

// Create contract
const contract = await contractsApi.createContract({
  name: 'MyToken',
  address: '0x...',
  network: 'ethereum',
  source_code: '...'
});
```

### Python

```python
import httpx

# Create client
client = httpx.AsyncClient(base_url="http://localhost:8001/api/v1")

# List contracts
response = await client.get("/contracts", headers={
    "Authorization": f"Bearer {token}"
})
contracts = response.json()
```

---

## Favorites

User favorites (pinned items) for quick access to frequently used projects, contracts, and scans.

### POST /favorites

Add an item to favorites.

**Request Body**:
```json
{
  "item_type": "contract",
  "item_id": "uuid-of-item"
}
```

**Response** (201):
```json
{
  "id": "favorite-uuid",
  "item_type": "contract",
  "item_id": "uuid-of-item",
  "display_order": 0,
  "created_at": "2025-12-11T00:00:00Z",
  "item_name": "MyToken",
  "item_details": {}
}
```

### GET /favorites

List all user favorites.

**Query Parameters**:
- `item_type` (optional): Filter by type (`project`, `contract`, `scan`)

**Response** (200):
```json
{
  "favorites": [...],
  "total": 5
}
```

### DELETE /favorites/{item_type}/{item_id}

Remove item from favorites.

**Response**: 204 No Content

### PUT /favorites/reorder

Reorder favorites.

**Request Body**:
```json
{
  "favorite_ids": ["uuid1", "uuid2", "uuid3"]
}
```

**Response** (200): Updated favorites list

### GET /favorites/check/{item_type}/{item_id}

Check if item is favorited.

**Response** (200):
```json
{
  "is_favorited": true
}
```

---

## Vulnerability Annotations

Mark vulnerabilities with status and notes for workflow management.

### POST /annotations

Create or update an annotation.

**Request Body**:
```json
{
  "vulnerability_id": "vuln-uuid",
  "status": "false_positive",
  "note": "This is a test contract, not production code",
  "reason": "Test code only"
}
```

**Valid Statuses**: `false_positive`, `acknowledged`, `confirmed`, `wont_fix`, `in_progress`, `fixed`

**Response** (201):
```json
{
  "id": "annotation-uuid",
  "vulnerability_id": "vuln-uuid",
  "user_id": "user-uuid",
  "status": "false_positive",
  "note": "This is a test contract",
  "reason": "Test code only",
  "created_at": "2025-12-11T00:00:00Z",
  "updated_at": "2025-12-11T00:00:00Z"
}
```

### GET /annotations/vulnerability/{vulnerability_id}

Get annotation for a specific vulnerability.

**Response** (200): Annotation object or null

### GET /annotations

List all user annotations.

**Query Parameters**:
- `status_filter` (optional): Filter by status
- `limit` (default: 50)
- `offset` (default: 0)

**Response** (200):
```json
{
  "annotations": [...],
  "total": 10
}
```

### DELETE /annotations/{annotation_id}

Delete an annotation (history preserved).

**Response**: 204 No Content

### GET /annotations/{annotation_id}/history

Get change history for an annotation.

**Response** (200):
```json
{
  "history": [
    {
      "id": "history-uuid",
      "annotation_id": "annotation-uuid",
      "user_id": "user-uuid",
      "previous_status": "acknowledged",
      "new_status": "false_positive",
      "change_reason": "Confirmed not a real issue",
      "created_at": "2025-12-11T00:00:00Z"
    }
  ],
  "total": 2
}
```

### GET /annotations/scan/{scan_id}

Get all annotations for vulnerabilities in a scan.

**Response** (200): Annotations list

### POST /annotations/bulk

Bulk create/update annotations (max 100).

**Request Body**: Array of annotation requests

**Response** (201): Created annotations list

---

## Changelog

See `/docs/changelogs/API-ENDPOINTS-CHANGELOG.md` for version history.

---

## Organizations (Phase 4.5 - Enterprise)

### GET /organizations

List all organizations the authenticated user belongs to.

**Authentication**: Required
**Tier**: All tiers

**Response** (200 OK):
```json
{
  "organizations": [
    {
      "id": "uuid",
      "name": "Acme Corp",
      "slug": "acme-corp",
      "subscription_tier": "enterprise",
      "max_members": 100,
      "created_at": "2025-12-23T10:00:00Z",
      "updated_at": "2025-12-23T10:00:00Z"
    }
  ],
  "total": 1
}
```

---

### POST /organizations

Create a new organization.

**Authentication**: Required
**Tier**: Enterprise only

**Request Body**:
```json
{
  "name": "Acme Corp",
  "slug": "acme-corp"
}
```

**Response** (201 Created):
```json
{
  "id": "uuid",
  "name": "Acme Corp",
  "slug": "acme-corp",
  "subscription_tier": "enterprise",
  "max_members": 100,
  "created_at": "2025-12-23T10:00:00Z"
}
```

**Status Codes**:
- `201` Created - Organization created
- `400` Bad Request - Invalid input
- `402` Payment Required - Enterprise tier required
- `409` Conflict - Slug already exists

---

### GET /organizations/{id}

Get organization details.

**Authentication**: Required
**Tier**: All tiers (member of organization)

**Path Parameters**:
- `id` (UUID) - Organization ID

**Response** (200 OK):
```json
{
  "id": "uuid",
  "name": "Acme Corp",
  "slug": "acme-corp",
  "subscription_tier": "enterprise",
  "max_members": 100,
  "sso_enabled": false,
  "sso_provider": null,
  "created_at": "2025-12-23T10:00:00Z",
  "updated_at": "2025-12-23T10:00:00Z"
}
```

---

### PATCH /organizations/{id}

Update an organization.

**Authentication**: Required
**Tier**: Enterprise only (owner/admin role)

**Path Parameters**:
- `id` (UUID) - Organization ID

**Request Body**:
```json
{
  "name": "Acme Corporation"
}
```

---

### DELETE /organizations/{id}

Delete an organization.

**Authentication**: Required
**Tier**: Enterprise only (owner role)

---

### GET /organizations/{id}/roles

List roles in an organization.

**Authentication**: Required
**Tier**: All tiers (member of organization)

**Response** (200 OK):
```json
{
  "roles": [
    {
      "id": "uuid",
      "name": "owner",
      "display_name": "Owner",
      "permissions": ["*"],
      "is_system_role": true
    },
    {
      "id": "uuid",
      "name": "admin",
      "display_name": "Administrator",
      "permissions": ["members:manage", "roles:manage", "settings:manage"],
      "is_system_role": true
    },
    {
      "id": "uuid",
      "name": "developer",
      "display_name": "Developer",
      "permissions": ["contracts:read", "contracts:write", "scans:create"],
      "is_system_role": true
    },
    {
      "id": "uuid",
      "name": "auditor",
      "display_name": "Auditor",
      "permissions": ["contracts:read", "scans:read", "audit_logs:read"],
      "is_system_role": true
    },
    {
      "id": "uuid",
      "name": "guest",
      "display_name": "Guest",
      "permissions": ["contracts:read", "scans:read"],
      "is_system_role": true
    }
  ]
}
```

**System Roles**: owner, admin, developer, auditor, guest

---

### POST /organizations/{id}/roles

Create a custom role.

**Authentication**: Required
**Tier**: Enterprise only (admin role)

**Request Body**:
```json
{
  "name": "security_lead",
  "display_name": "Security Lead",
  "permissions": ["contracts:read", "contracts:write", "scans:create", "vulnerabilities:write"]
}
```

---

### GET /organizations/{id}/members

List organization members.

**Authentication**: Required
**Tier**: All tiers (member of organization)

**Response** (200 OK):
```json
{
  "members": [
    {
      "user_id": "uuid",
      "email": "user@example.com",
      "role_name": "owner",
      "role_display_name": "Owner",
      "is_active": true,
      "joined_at": "2025-12-23T10:00:00Z"
    }
  ],
  "total": 1
}
```

---

### POST /organizations/{id}/members

Add a member to the organization.

**Authentication**: Required
**Tier**: Enterprise only (admin role)

**Request Body**:
```json
{
  "user_email": "newuser@example.com",
  "role_name": "developer"
}
```

---

### PATCH /organizations/{id}/members/{member_id}

Update a member's role.

**Authentication**: Required
**Tier**: Enterprise only (admin role)

---

### DELETE /organizations/{id}/members/{member_id}

Remove a member from the organization.

**Authentication**: Required
**Tier**: Enterprise only (admin role)

---

## Current Organization Convenience Endpoints

These endpoints automatically use the authenticated user's current organization, eliminating the need to specify the organization ID. Useful for frontend applications where the user is typically working within a single organization context.

### GET /roles

List roles in the current user's organization.

**Authentication**: Required
**Tier**: All tiers

**Response** (200 OK):
```json
{
  "roles": [
    {
      "id": "uuid",
      "name": "owner",
      "display_name": "Owner",
      "description": "Full access to all organization resources",
      "is_system_role": true
    },
    {
      "id": "uuid",
      "name": "admin",
      "display_name": "Administrator",
      "description": "Manage members, roles, and settings",
      "is_system_role": true
    },
    {
      "id": "uuid",
      "name": "developer",
      "display_name": "Developer",
      "description": "Create and manage contracts and scans",
      "is_system_role": true
    },
    {
      "id": "uuid",
      "name": "auditor",
      "display_name": "Auditor",
      "description": "Read-only access with audit log visibility",
      "is_system_role": true
    },
    {
      "id": "uuid",
      "name": "guest",
      "display_name": "Guest",
      "description": "Limited read-only access",
      "is_system_role": true
    }
  ],
  "total": 5
}
```

**Status Codes**:
- `200` OK - Roles listed
- `401` Unauthorized - Not authenticated
- `404` Not Found - User not a member of any organization

---

### GET /organizations/current/users

List members in the current user's organization.

**Authentication**: Required
**Tier**: All tiers

**Response** (200 OK):
```json
{
  "members": [
    {
      "id": "uuid",
      "user_id": "uuid",
      "user_email": "user@example.com",
      "role_id": "uuid",
      "role_name": "owner",
      "is_active": true,
      "joined_at": "2025-12-23T10:00:00Z"
    }
  ],
  "total": 1
}
```

**Status Codes**:
- `200` OK - Members listed
- `401` Unauthorized - Not authenticated
- `404` Not Found - User not a member of any organization

---

### POST /organizations/current/users

Add a member to the current organization.

**Authentication**: Required
**Tier**: Enterprise only (admin role)

**Request Body**:
```json
{
  "email": "newuser@example.com",
  "role_id": "uuid"
}
```

**Response** (201 Created):
```json
{
  "id": "uuid",
  "user_id": "uuid",
  "user_email": "newuser@example.com",
  "role_id": "uuid",
  "role_name": "developer",
  "is_active": true,
  "joined_at": "2025-12-23T10:00:00Z"
}
```

**Status Codes**:
- `201` Created - Member added
- `400` Bad Request - Invalid input
- `401` Unauthorized - Not authenticated
- `403` Forbidden - Not admin role
- `404` Not Found - Role not found or user not in organization
- `409` Conflict - User already a member

---

### PATCH /organizations/current/users/{user_id}

Update a member's role in the current organization.

**Authentication**: Required
**Tier**: Enterprise only (admin role)

**Path Parameters**:
- `user_id` (UUID) - The member's user ID

**Request Body**:
```json
{
  "role_id": "uuid"
}
```

**Response** (200 OK):
```json
{
  "id": "uuid",
  "user_id": "uuid",
  "user_email": "user@example.com",
  "role_id": "uuid",
  "role_name": "admin",
  "is_active": true,
  "joined_at": "2025-12-23T10:00:00Z"
}
```

**Status Codes**:
- `200` OK - Member updated
- `400` Bad Request - Invalid input
- `401` Unauthorized - Not authenticated
- `403` Forbidden - Not admin role or cannot modify owner
- `404` Not Found - Member or role not found

---

### DELETE /organizations/current/users/{user_id}

Remove a member from the current organization.

**Authentication**: Required
**Tier**: Enterprise only (admin role)

**Path Parameters**:
- `user_id` (UUID) - The member's user ID

**Status Codes**:
- `204` No Content - Member removed
- `401` Unauthorized - Not authenticated
- `403` Forbidden - Not admin role or cannot remove owner
- `404` Not Found - Member not found

---

## API Keys (Phase 4.5 - Enterprise)

### GET /api-keys/scopes

List all available API key scopes.

**Authentication**: Not required

**Response** (200 OK):
```json
{
  "scopes": [
    {"name": "contracts:read", "description": "Read contract data"},
    {"name": "contracts:write", "description": "Create and update contracts"},
    {"name": "scans:read", "description": "Read scan results"},
    {"name": "scans:create", "description": "Trigger new scans"},
    {"name": "vulnerabilities:read", "description": "Read vulnerability data"},
    {"name": "vulnerabilities:write", "description": "Update vulnerability status"},
    {"name": "patterns:read", "description": "Read vulnerability patterns"},
    {"name": "analytics:read", "description": "Access analytics data"},
    {"name": "webhooks:read", "description": "Read webhook configuration"},
    {"name": "webhooks:write", "description": "Manage webhooks"}
  ]
}
```

---

### GET /api-keys

List all API keys for the authenticated user.

**Authentication**: Required
**Tier**: All tiers

**Response** (200 OK):
```json
{
  "api_keys": [
    {
      "id": "uuid",
      "name": "CI/CD Pipeline",
      "key_prefix": "bso_****abcd",
      "scopes": ["scans:create", "scans:read"],
      "rate_limit_per_minute": 60,
      "rate_limit_per_hour": 1000,
      "expires_at": "2026-12-23T00:00:00Z",
      "last_used_at": "2025-12-23T15:30:00Z",
      "created_at": "2025-12-23T10:00:00Z"
    }
  ],
  "total": 1
}
```

---

### POST /api-keys

Create a new API key.

**Authentication**: Required
**Tier**: Pro+ only
**Max Keys**: 10 active keys per user

**Request Body**:
```json
{
  "name": "CI/CD Pipeline",
  "scopes": ["scans:create", "scans:read"],
  "rate_limit_per_minute": 60,
  "rate_limit_per_hour": 1000,
  "expires_at": "2026-12-23T00:00:00Z"
}
```

**Response** (201 Created):
```json
{
  "id": "uuid",
  "name": "CI/CD Pipeline",
  "key": "bso_live_abc123...xyz789",
  "key_prefix": "bso_live_abc1",
  "scopes": ["scans:create", "scans:read"],
  "rate_limit_per_minute": 60,
  "rate_limit_per_hour": 1000,
  "expires_at": "2026-12-23T00:00:00Z",
  "created_at": "2025-12-23T10:00:00Z"
}
```

**Important**: The full `key` value is only returned once at creation. Store it securely.

**Key Format**: `bso_live_` prefix + random token (SHA-256 hashed for storage)

---

### GET /api-keys/{key_id}

Get API key details.

**Authentication**: Required
**Tier**: All tiers

---

### PATCH /api-keys/{key_id}

Update API key settings.

**Authentication**: Required
**Tier**: Pro+ only

---

### DELETE /api-keys/{key_id}

Revoke an API key.

**Authentication**: Required
**Tier**: Pro+ only

---

### POST /api-keys/{key_id}/regenerate

Regenerate an API key's secret.

**Authentication**: Required
**Tier**: Pro+ only

**Response** (200 OK):
```json
{
  "id": "uuid",
  "key": "bso_live_new123...xyz789",
  "message": "API key regenerated successfully"
}
```

---

### GET /api-keys/{key_id}/usage

Get API key usage statistics.

**Authentication**: Required
**Tier**: Pro+ only

**Response** (200 OK):
```json
{
  "key_id": "uuid",
  "total_requests": 1524,
  "requests_today": 42,
  "requests_this_hour": 5,
  "last_used_at": "2025-12-23T15:30:00Z",
  "usage_by_endpoint": {
    "/api/v1/scans": 1200,
    "/api/v1/contracts": 324
  }
}
```

---

### DELETE /api-keys

Revoke all API keys for the authenticated user.

**Authentication**: Required
**Tier**: Pro+ only

---

## Audit Logs (Phase 4.5 - Enterprise)

### GET /audit-logs/actions

List all audit log action categories.

**Authentication**: Not required

**Response** (200 OK):
```json
{
  "categories": {
    "auth": ["login", "logout", "password_change", "mfa_enable", "mfa_disable", "api_key_create", "api_key_revoke"],
    "contracts": ["create", "update", "delete", "upload"],
    "scans": ["create", "complete", "fail", "delete"],
    "vulnerabilities": ["update", "acknowledge", "dismiss", "reopen"],
    "organizations": ["create", "update", "delete", "member_add", "member_remove", "role_create", "role_update", "role_delete"],
    "webhooks": ["create", "update", "delete", "test"],
    "admin": ["settings_change", "billing_update", "sso_configure", "export_data"]
  }
}
```

---

### GET /audit-logs

Query audit logs with filtering.

**Authentication**: Required
**Tier**: Enterprise only

**Query Parameters**:
- `action_category` (string, optional) - Filter by category (auth, contracts, scans, etc.)
- `action` (string, optional) - Filter by specific action
- `user_id` (UUID, optional) - Filter by user
- `organization_id` (UUID, optional) - Filter by organization
- `resource_type` (string, optional) - Filter by resource type
- `resource_id` (UUID, optional) - Filter by resource ID
- `from_date` (ISO 8601, optional) - Start date
- `to_date` (ISO 8601, optional) - End date
- `skip` (integer, default: 0)
- `limit` (integer, default: 50, max: 1000)

**Response** (200 OK):
```json
{
  "logs": [
    {
      "id": "uuid",
      "action_category": "contracts",
      "action": "create",
      "user_id": "uuid",
      "user_email": "user@example.com",
      "organization_id": "uuid",
      "resource_type": "contract",
      "resource_id": "uuid",
      "ip_address": "192.168.1.1",
      "user_agent": "Mozilla/5.0...",
      "request_id": "req_abc123",
      "old_values": null,
      "new_values": {"name": "MyToken", "language": "solidity"},
      "success": true,
      "created_at": "2025-12-23T15:30:00Z"
    }
  ],
  "total": 150,
  "page": 1,
  "page_size": 50
}
```

---

### GET /audit-logs/{log_id}

Get audit log entry details.

**Authentication**: Required
**Tier**: Enterprise only

---

### GET /audit-logs/summary

Get audit log statistics summary.

**Authentication**: Required
**Tier**: Enterprise only

**Query Parameters**:
- `from_date` (ISO 8601, optional)
- `to_date` (ISO 8601, optional)

**Response** (200 OK):
```json
{
  "period": {
    "from": "2025-12-01T00:00:00Z",
    "to": "2025-12-23T23:59:59Z"
  },
  "total_events": 1523,
  "by_category": {
    "auth": 245,
    "contracts": 512,
    "scans": 689,
    "vulnerabilities": 77
  },
  "by_user": [
    {"user_id": "uuid", "email": "user@example.com", "count": 523}
  ],
  "top_actions": [
    {"action": "scans.create", "count": 450},
    {"action": "contracts.upload", "count": 312}
  ]
}
```

---

### GET /audit-logs/export/csv

Export audit logs as CSV.

**Authentication**: Required
**Tier**: Enterprise only

**Query Parameters**: Same as GET /audit-logs

**Response**: CSV file download

---

### GET /audit-logs/export/json

Export audit logs as JSON.

**Authentication**: Required
**Tier**: Enterprise only

**Query Parameters**: Same as GET /audit-logs

**Response**: JSON file download

---

## Webhooks (Phase 4.5 - Enterprise)

### GET /webhooks

List all webhooks for the authenticated user.

**Authentication**: Required
**Tier**: Pro+ only

---

### POST /webhooks

Create a new webhook.

**Authentication**: Required
**Tier**: Pro+ only

**Request Body**:
```json
{
  "url": "https://example.com/webhook",
  "events": ["scan.completed", "vulnerability.detected"],
  "active": true
}
```

**Response** (201 Created):
```json
{
  "id": "uuid",
  "url": "https://example.com/webhook",
  "events": ["scan.completed", "vulnerability.detected"],
  "secret": "whsec_abc123...",
  "active": true,
  "created_at": "2025-12-23T10:00:00Z"
}
```

**Important**: The `secret` is only returned once at creation.

---

### GET /webhooks/events

List available webhook event types.

**Authentication**: Not required

**Response** (200 OK):
```json
{
  "events": [
    {"name": "scan.started", "description": "Triggered when a scan begins"},
    {"name": "scan.completed", "description": "Triggered when a scan completes"},
    {"name": "scan.failed", "description": "Triggered when a scan fails"},
    {"name": "vulnerability.detected", "description": "Triggered when new vulnerability found"},
    {"name": "vulnerability.critical", "description": "Triggered for critical vulnerabilities"},
    {"name": "contract.added", "description": "Triggered when contract uploaded"},
    {"name": "contract.deleted", "description": "Triggered when contract deleted"}
  ]
}
```

---

### GET /webhooks/{id}

Get webhook details.

---

### PATCH /webhooks/{id}

Update webhook configuration.

---

### DELETE /webhooks/{id}

Delete a webhook.

---

### POST /webhooks/{id}/test

Send a test webhook payload.

---

### GET /webhooks/{id}/deliveries

Get webhook delivery history.

---

### POST /webhooks/{id}/rotate-secret

Rotate webhook secret.

---

## Notification Channels (CI/CD Integrations - January 2026)

Notification channels for Slack, Teams, and Discord webhook integrations. Enables automated alerts for scan events and vulnerability notifications.

**Base Path**: `/api/v1/notification-channels`

### GET /notification-channels

List all notification channels for the authenticated user.

**Authentication**: Required (Bearer token)

**Response** (200 OK):
```json
{
  "channels": [
    {
      "id": "uuid",
      "name": "My Slack Channel",
      "channel_type": "slack",
      "events": ["scan.completed", "vulnerability.critical"],
      "is_active": true,
      "filters": {
        "min_severity": "high",
        "project_ids": []
      },
      "total_notifications": 45,
      "successful_notifications": 43,
      "failed_notifications": 2,
      "last_triggered_at": "2026-01-04T10:00:00Z",
      "created_at": "2026-01-03T08:00:00Z"
    }
  ]
}
```

---

### POST /notification-channels

Create a new notification channel.

**Authentication**: Required (Bearer token)

**Request Body**:
```json
{
  "name": "My Slack Channel",
  "channel_type": "slack",
  "webhook_url": "https://hooks.slack.com/services/...",
  "events": ["scan.completed", "vulnerability.critical"],
  "filters": {
    "min_severity": "high",
    "project_ids": []
  }
}
```

**Channel Types**:
| Type | Format | Features |
|------|--------|----------|
| `slack` | Block Kit | Color-coded severity, action buttons |
| `teams` | Adaptive Cards | Fact sets, action URLs |
| `discord` | Rich Embeds | Colored sidebar, fields layout |

**Response** (201 Created):
```json
{
  "id": "uuid",
  "name": "My Slack Channel",
  "channel_type": "slack",
  "events": ["scan.completed", "vulnerability.critical"],
  "is_active": true,
  "created_at": "2026-01-04T10:00:00Z"
}
```

**Errors**:
- 400: Invalid webhook URL or channel_type

---

### GET /notification-channels/events

List available event types for notification subscriptions.

**Authentication**: Not required

**Response** (200 OK):
```json
{
  "events": [
    {"id": "scan.completed", "name": "Scan Completed", "description": "When a scan finishes successfully"},
    {"id": "scan.failed", "name": "Scan Failed", "description": "When a scan encounters an error"},
    {"id": "vulnerability.critical", "name": "Critical Vulnerability", "description": "Critical severity vulnerability found"},
    {"id": "vulnerability.high", "name": "High Vulnerability", "description": "High severity vulnerability found"}
  ]
}
```

---

### GET /notification-channels/{id}

Get notification channel details.

**Authentication**: Required (Bearer token)

**Response** (200 OK):
```json
{
  "id": "uuid",
  "name": "My Slack Channel",
  "channel_type": "slack",
  "events": ["scan.completed", "vulnerability.critical"],
  "is_active": true,
  "filters": {
    "min_severity": "high",
    "project_ids": []
  },
  "total_notifications": 45,
  "successful_notifications": 43,
  "failed_notifications": 2,
  "last_triggered_at": "2026-01-04T10:00:00Z",
  "last_success_at": "2026-01-04T10:00:00Z",
  "last_failure_at": "2026-01-03T15:30:00Z",
  "last_error": "Connection timeout",
  "created_at": "2026-01-03T08:00:00Z",
  "updated_at": "2026-01-04T09:00:00Z"
}
```

**Errors**:
- 404: Channel not found
- 403: Not authorized to access this channel

---

### PUT /notification-channels/{id}

Update notification channel configuration.

**Authentication**: Required (Bearer token)

**Request Body**:
```json
{
  "name": "Updated Channel Name",
  "events": ["scan.completed"],
  "is_active": false,
  "filters": {
    "min_severity": "critical"
  }
}
```

**Response** (200 OK): Updated channel object

**Errors**:
- 404: Channel not found
- 403: Not authorized to modify this channel

---

### DELETE /notification-channels/{id}

Delete a notification channel.

**Authentication**: Required (Bearer token)

**Response** (204 No Content)

**Note**: Delivery history is also deleted (cascade).

**Errors**:
- 404: Channel not found
- 403: Not authorized to delete this channel

---

### POST /notification-channels/{id}/test

Send a test notification to verify channel configuration.

**Authentication**: Required (Bearer token)

**Response** (200 OK):
```json
{
  "success": true,
  "message": "Test notification sent successfully",
  "status_code": 200,
  "duration_ms": 245
}
```

**Errors**:
- 404: Channel not found
- 502: Webhook delivery failed (includes error details)

---

### GET /notification-channels/{id}/deliveries

Get notification delivery history for a channel.

**Authentication**: Required (Bearer token)

**Query Parameters**:
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | integer | 20 | Max results (1-100) |
| `offset` | integer | 0 | Pagination offset |
| `status` | string | - | Filter by "success" or "failed" |

**Response** (200 OK):
```json
{
  "deliveries": [
    {
      "id": "uuid",
      "event_type": "scan.completed",
      "success": true,
      "status_code": 200,
      "duration_ms": 156,
      "error_message": null,
      "created_at": "2026-01-04T10:00:00Z"
    },
    {
      "id": "uuid",
      "event_type": "vulnerability.critical",
      "success": false,
      "status_code": 504,
      "duration_ms": 30000,
      "error_message": "Gateway timeout",
      "created_at": "2026-01-03T15:30:00Z"
    }
  ],
  "total": 45,
  "limit": 20,
  "offset": 0
}
```

---

## ML Endpoints (Phase 5 - Implemented)

Machine learning endpoints for vulnerability analysis. **Status: Implementation Complete**

CPU-only ML features (~$1/month operating cost) providing intelligent vulnerability analysis.

### POST /ml/predict-false-positive

Predict probability that a vulnerability is a false positive.

**Request Body**:
```json
{
  "vulnerability_id": "uuid"
}
```

**Response**:
```json
{
  "vulnerability_id": "uuid",
  "false_positive_probability": 0.15,
  "confidence": 0.87,
  "top_features": ["scanner_confidence=0.9", "severity=3", "has_modifier=1"]
}
```

---

### POST /ml/label-vulnerability

Add a training label to a vulnerability (for FP classifier training).

**Request Body**:
```json
{
  "vulnerability_id": "uuid",
  "is_real_vulnerability": true,
  "confidence": 0.9,
  "reason": "Confirmed reentrancy issue in withdraw function"
}
```

---

### POST /ml/retrain

Trigger model retraining with current labeled data.

**Request Body**:
```json
{
  "force": false,
  "min_samples": 200
}
```

**Response**:
```json
{
  "success": true,
  "samples_used": 423,
  "accuracy": 0.87,
  "auc": 0.92,
  "message": "Model retrained successfully"
}
```

---

### GET /ml/model-stats

Get current model performance statistics.

**Response**:
```json
{
  "model_version": "1.0.0",
  "trained_at": "2025-01-15T10:30:00Z",
  "samples_count": 423,
  "accuracy": 0.87,
  "auc": 0.92,
  "true_positive_count": 215,
  "false_positive_count": 208
}
```

---

### GET /contracts/{id}/risk-score

Get risk score (0-100) for a contract.

**Response**:
```json
{
  "score": 72,
  "level": "HIGH",
  "vulnerability_breakdown": {
    "critical": 1,
    "high": 3,
    "medium": 5,
    "low": 2,
    "info": 0
  },
  "adjustments": ["+10: Known exploit pattern", "+5: High consensus findings"]
}
```

---

### GET /projects/{id}/risk-score

Get aggregate risk score for a project (all contracts).

---

### GET /projects/{id}/contracts

Get all contracts within a project with full details.

**Authentication**: Required (Bearer token)

**Path Parameters**:
- `id` (UUID) - Project ID

**Query Parameters**:
- `skip` (integer, default: 0) - Number of records to skip
- `limit` (integer, default: 100, max: 1000) - Number of records to return

**Response** (200 OK):
```json
{
  "contracts": [
    {
      "id": "uuid",
      "name": "MyToken",
      "address": "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
      "network": "ethereum",
      "lines_of_code": 450,
      "status": "scanned",
      "language": "solidity",
      "compiler_version": "0.8.20",
      "is_multi_file": true,
      "file_count": 12,
      "main_file_path": "src/Token.sol",
      "created_at": "2025-10-06T22:00:00Z",
      "updated_at": "2025-10-06T22:00:00Z"
    }
  ],
  "total": 5
}
```

**Status Codes**:
- `200` OK - Success
- `401` Unauthorized - Invalid or missing token
- `403` Forbidden - Not owner of project
- `404` Not Found - Project does not exist

**Added**: January 2026

---

### GET /scans/{id}/risk-score

Get risk score for a specific scan result.

**Response**:
```json
{
  "score": 65,
  "level": "HIGH",
  "vulnerability_breakdown": {
    "critical": 0,
    "high": 4,
    "medium": 3,
    "low": 1,
    "info": 2
  },
  "adjustments": ["+5: High consensus findings"]
}
```

---

### GET /scans/{id}/prioritized

Get vulnerabilities from a scan ranked by fix priority.

**Query Parameters**:
- `limit` (int, default: 20) - Maximum results
- `offset` (int, default: 0) - Pagination offset

**Response**:
```json
{
  "scan_id": "uuid",
  "total": 15,
  "vulnerabilities": [
    {
      "id": "uuid",
      "title": "Reentrancy in withdraw",
      "severity": "critical",
      "priority_score": 125.5,
      "priority_rank": 1,
      "priority_level": "CRITICAL",
      "breakdown": {
        "base_severity": 100,
        "confidence_factor": 0.95,
        "fp_factor": 0.85,
        "consensus_boost": 10,
        "exploit_boost": 20
      }
    }
  ]
}
```

---

### GET /contracts/{id}/top-priorities

Get top priority vulnerabilities for a contract.

**Query Parameters**:
- `limit` (int, default: 10) - Maximum results

**Response**:
```json
{
  "contract_id": "uuid",
  "total": 8,
  "vulnerabilities": [
    {
      "id": "uuid",
      "title": "Integer overflow in balance calculation",
      "severity": "high",
      "priority_score": 85.2,
      "priority_rank": 1,
      "priority_level": "HIGH",
      "breakdown": {}
    }
  ]
}
```

---

### GET /vulnerabilities/{id}/confidence

Get confidence score for a vulnerability.

**Response**:
```json
{
  "vulnerability_id": "uuid",
  "score": 0.87,
  "percentage": 87,
  "level": "high",
  "signals": [
    {
      "name": "fp_inverse",
      "value": 0.92,
      "weight": 0.4
    },
    {
      "name": "scanner_confidence",
      "value": 0.85,
      "weight": 0.2
    },
    {
      "name": "classification_confidence",
      "value": 0.78,
      "weight": 0.2
    },
    {
      "name": "tool_consensus",
      "value": 0.90,
      "weight": 0.2
    }
  ]
}
```

---

### GET /vulnerabilities/{id}/similar

Find semantically similar vulnerabilities.

**Query Parameters**:
- `threshold` (float, default: 0.85) - Minimum similarity score
- `limit` (int, default: 10) - Maximum results

**Response**:
```json
{
  "query_id": "uuid",
  "threshold": 0.85,
  "similar": [
    {
      "vulnerability_id": "uuid",
      "title": "Reentrancy in withdraw",
      "severity": "high",
      "contract_name": "Vault.sol",
      "similarity": 0.92
    }
  ]
}
```

---

## Economic Analysis (Phase 5.5a - Implemented)

Economic security analysis endpoints for detecting flash loan attacks, MEV exploitation, oracle manipulation, and DeFi protocol risks. **Status: Implementation Complete**

These endpoints aggregate economic security findings already detected by SolidityDefend and provide focused visibility into financial attack vectors.

### GET /scans/{scan_id}/economic-analysis

Get economic security summary for a specific scan.

**Authentication**: Required (Bearer token)

**Path Parameters**:
- `scan_id` (UUID) - Scan ID

**Response** (200 OK):
```json
{
  "scan_id": "uuid",
  "total_economic_findings": 5,
  "economic_risk_score": 45,
  "highest_severity": "high",
  "flash_loan_findings": [
    {
      "id": "uuid",
      "title": "Flash Loan Attack Vector",
      "description": "Function vulnerable to flash loan manipulation",
      "severity": "high",
      "pattern_id": "BVD-SOLIDITY-FLASH-001",
      "contract_name": "LendingPool.sol",
      "contract_id": "uuid",
      "line_start": 142,
      "line_end": null,
      "confidence": 0.87,
      "category": "flash_loan"
    }
  ],
  "oracle_mev_findings": [
    {
      "id": "uuid",
      "title": "MEV Sandwich Attack Risk",
      "description": "Swap function vulnerable to sandwich attacks",
      "severity": "medium",
      "pattern_id": "BVD-SOLIDITY-MEV-002",
      "contract_name": "DEX.sol",
      "contract_id": "uuid",
      "line_start": 89,
      "line_end": null,
      "confidence": 0.78,
      "category": "mev"
    }
  ],
  "defi_findings": [
    {
      "id": "uuid",
      "title": "Oracle Manipulation Risk",
      "description": "Price oracle can be manipulated in single transaction",
      "severity": "high",
      "pattern_id": "BVD-SOLIDITY-DEFI-003",
      "contract_name": "PriceOracle.sol",
      "contract_id": "uuid",
      "line_start": 56,
      "line_end": null,
      "confidence": 0.92,
      "category": "defi"
    }
  ],
  "critical_count": 0,
  "high_count": 2,
  "medium_count": 2,
  "low_count": 1,
  "risk_level": "high",
  "ai_explanation": null
}
```

**Status Codes**:
- `200` OK - Success
- `401` Unauthorized - Invalid or missing token
- `403` Forbidden - Not owner of scan
- `404` Not Found - Scan does not exist

**Economic Pattern Detection**:
- `BVD-SOLIDITY-FLASH-*`: Flash loan attacks
- `BVD-SOLIDITY-MEV-*`: MEV exploitation (sandwich, frontrun, backrun)
- `BVD-SOLIDITY-DEFI-*`: DeFi protocol risks (oracle, liquidity, AMM)

**Added**: January 2026 (Phase 5.5a)

---

### GET /scans/{scan_id}/economic-analysis/explain

Get AI-generated explanation of economic security risks for a scan.

**Authentication**: Required (Bearer token)

**Tier Requirements**:
| Tier | Monthly AI Explanations |
|------|------------------------|
| Free | 0 (not available) |
| Developer | 10 |
| Startup | 100 |
| Professional | 500 |
| Enterprise | Unlimited |

**Path Parameters**:
- `scan_id` (UUID) - Scan ID

**Response** (200 OK):
```json
{
  "scan_id": "uuid",
  "explanation": "## Economic Security Analysis\n\nThis scan detected **5 economic security vulnerabilities** with an overall risk score of **45/100** (HIGH).\n\n### Critical Findings\n\n1. **Flash Loan Attack Vector** (High Severity)\n   - Location: LendingPool.sol:142\n   - The `borrow()` function can be exploited within a single transaction...\n\n2. **Oracle Manipulation Risk** (High Severity)\n   - Location: PriceOracle.sol:56\n   - Price can be manipulated by...\n\n### Recommendations\n1. Implement flash loan protection using reentrancy guards\n2. Use time-weighted average prices (TWAP) for oracle data\n3. Add MEV protection via commit-reveal schemes",
  "generated_at": "2026-01-12T10:30:00Z",
  "model": "claude-3-haiku",
  "quota_remaining": 9
}
```

**Response (402 Quota Exceeded)**:
```json
{
  "detail": "AI explanation quota exceeded. Upgrade your plan for more explanations.",
  "quota_limit": 10,
  "quota_used": 10,
  "upgrade_url": "https://app.blocksecops.com/settings/billing"
}
```

**Status Codes**:
- `200` OK - Success
- `401` Unauthorized - Invalid or missing token
- `402` Payment Required - AI explanation quota exceeded
- `403` Forbidden - Not owner of scan or tier not eligible
- `404` Not Found - Scan does not exist

**Added**: January 2026 (Phase 5.5a)

---

### GET /contracts/{contract_id}/economic-findings

Get economic security findings for a specific contract.

**Authentication**: Required (Bearer token)

**Path Parameters**:
- `contract_id` (UUID) - Contract ID

**Response** (200 OK):
```json
{
  "contract_id": "uuid",
  "findings": [
    {
      "id": "uuid",
      "title": "Flash Loan Attack Vector",
      "description": "Function vulnerable to flash loan manipulation",
      "severity": "high",
      "pattern_id": "BVD-SOLIDITY-FLASH-001",
      "contract_name": "LendingPool.sol",
      "contract_id": "uuid",
      "line_start": 142,
      "line_end": null,
      "confidence": 0.87,
      "category": "flash_loan"
    }
  ],
  "total": 1
}
```

**Status Codes**:
- `200` OK - Success
- `401` Unauthorized - Invalid or missing token
- `403` Forbidden - Not owner of contract
- `404` Not Found - Contract does not exist

**Added**: January 2026 (Phase 5.5a)

---

### GET /projects/{project_id}/economic-risk

Get aggregated economic risk across all scans in a project.

**Authentication**: Required (Bearer token)

**Path Parameters**:
- `project_id` (UUID) - Project ID

**Response** (200 OK):
```json
{
  "project_id": "uuid",
  "total_economic_findings": 12,
  "aggregate_risk_score": 67,
  "scans_analyzed": 5,
  "highest_severity": "critical"
}
```

**Status Codes**:
- `200` OK - Success
- `401` Unauthorized - Invalid or missing token
- `403` Forbidden - Not owner of project
- `404` Not Found - Project does not exist

**Added**: January 2026 (Phase 5.5a)

---

## Quality Gates (Phase 5.5c - CI/CD Integration)

Quality gate endpoints for enforcing security standards in CI/CD pipelines. Configure blocking rules and check build status programmatically. **Status: Implementation Complete**

### GET /quality-gates/projects/{project_id}

Get quality gate configuration for a project.

**Authentication**: Required (Bearer token)

**Tier Requirements**: Developer+ (not available on Free tier)

**Path Parameters**:
- `project_id` (UUID) - Project ID

**Response** (200 OK):
```json
{
  "id": "uuid",
  "project_id": "uuid",
  "organization_id": null,
  "name": "Production Security Gate",
  "description": "Blocks critical and high vulnerabilities",

  "block_on_critical": true,
  "block_on_high": true,
  "block_on_medium": false,
  "block_on_low": false,

  "max_critical": 0,
  "max_high": 0,
  "max_medium": -1,
  "max_low": -1,

  "advanced_rules": null,

  "is_active": true,
  "enforce_on_pr": true,
  "enforce_on_main": true,

  "notify_on_failure": true,
  "notification_channels": null,

  "created_at": "2026-01-12T10:00:00Z",
  "updated_at": "2026-01-12T10:00:00Z"
}
```

**Configuration Options**:
- `block_on_*`: Block build if ANY vulnerability of this severity exists
- `max_*`: Block if count exceeds threshold (-1 = disabled)
- `enforce_on_pr`: Enforce on pull request builds
- `enforce_on_main`: Enforce on main branch builds

**Status Codes**:
- `200` OK - Success
- `401` Unauthorized - Invalid or missing token
- `403` Forbidden - Tier not eligible (Free tier)
- `404` Not Found - Project not found

**Added**: January 2026 (Phase 5.5c)

---

### PUT /quality-gates/projects/{project_id}

Create or update quality gate configuration for a project.

**Authentication**: Required (Bearer token)

**Tier Requirements**: Developer+

**Path Parameters**:
- `project_id` (UUID) - Project ID

**Request Body**:
```json
{
  "name": "Production Security Gate",
  "description": "Strict security requirements for production",

  "block_on_critical": true,
  "block_on_high": true,
  "block_on_medium": false,
  "block_on_low": false,

  "max_critical": 0,
  "max_high": 0,
  "max_medium": 10,
  "max_low": -1,

  "enforce_on_pr": true,
  "enforce_on_main": true,
  "notify_on_failure": true
}
```

**Response** (200 OK): Same as GET response

**Status Codes**:
- `200` OK - Created/Updated
- `401` Unauthorized - Invalid or missing token
- `403` Forbidden - Tier not eligible
- `404` Not Found - Project not found

**Added**: January 2026 (Phase 5.5c)

---

### POST /quality-gates/projects/{project_id}/evaluate

Evaluate a scan against the project's quality gate.

**Authentication**: Required (Bearer token)

**Path Parameters**:
- `project_id` (UUID) - Project ID

**Request Body**:
```json
{
  "scan_id": "uuid",
  "triggered_by": "ci",
  "ci_context": {
    "branch": "main",
    "commit": "abc123def456",
    "pr": 42,
    "workflow": "security-scan",
    "run_id": "12345"
  }
}
```

**Response** (200 OK):
```json
{
  "quality_gate_id": "uuid",
  "scan_id": "uuid",
  "project_id": "uuid",

  "passed": false,
  "status": "failing",

  "critical_count": 2,
  "high_count": 5,
  "medium_count": 12,
  "low_count": 23,

  "violations": [
    {
      "rule": "block_on_critical",
      "threshold": 0,
      "actual": 2,
      "severity": "critical",
      "message": "Found 2 critical vulnerabilities (blocking)"
    },
    {
      "rule": "max_high",
      "threshold": 0,
      "actual": 5,
      "severity": "high",
      "message": "High vulnerabilities (5) exceed threshold (0)"
    }
  ],

  "triggered_by": "ci",
  "ci_context": {
    "branch": "main",
    "commit": "abc123def456",
    "pr": 42
  },
  "evaluated_at": "2026-01-12T10:30:00Z"
}
```

**Status Values**:
- `passing`: All rules satisfied
- `failing`: One or more violations
- `warning`: Soft violations (advisory)
- `skipped`: No quality gate configured
- `pending`: Awaiting scan completion

**Status Codes**:
- `200` OK - Evaluation complete
- `401` Unauthorized - Invalid or missing token
- `404` Not Found - Scan or project not found

**Added**: January 2026 (Phase 5.5c)

---

### GET /quality-gates/projects/{project_id}/build-status

Get current build status for CI/CD integration.

**Authentication**: Optional (public access for badges)

**Path Parameters**:
- `project_id` (UUID) - Project ID

**Response** (200 OK):
```json
{
  "project_id": "uuid",
  "status": "passing",
  "quality_gate_name": "Production Security Gate",

  "last_scan_id": "uuid",
  "last_evaluation_id": "uuid",

  "critical_count": 0,
  "high_count": 0,
  "medium_count": 5,
  "low_count": 12,

  "violations": [],

  "badge_url": "/api/v1/quality-gates/projects/{id}/badge.svg",
  "evaluated_at": "2026-01-12T10:30:00Z"
}
```

**Usage in CI/CD**:
```bash
# Check build status and fail if not passing
STATUS=$(curl -s "https://api.blocksecops.com/api/v1/quality-gates/projects/$PROJECT_ID/build-status" \
  -H "Authorization: Bearer $TOKEN" | jq -r '.status')

if [ "$STATUS" != "passing" ]; then
  echo "Quality gate failed!"
  exit 1
fi
```

**Status Codes**:
- `200` OK - Success
- `404` Not Found - Project not found

**Added**: January 2026 (Phase 5.5c)

---

### GET /quality-gates/projects/{project_id}/badge.svg

Get SVG badge for build status (suitable for README files).

**Authentication**: None (public)

**Path Parameters**:
- `project_id` (UUID) - Project ID

**Response**: SVG image

**Badge States**:
- ![passing](https://img.shields.io/badge/security-passing-brightgreen) - All checks pass
- ![failing](https://img.shields.io/badge/security-failing-red) - Violations detected
- ![pending](https://img.shields.io/badge/security-pending-lightgrey) - No scans yet

**Usage in README**:
```markdown
[![Security](https://api.blocksecops.com/api/v1/quality-gates/projects/YOUR_PROJECT_ID/badge.svg)](https://app.blocksecops.com/projects/YOUR_PROJECT_ID)
```

**Added**: January 2026 (Phase 5.5c)

---

### GET /quality-gates/projects/{project_id}/history

Get quality gate evaluation history for a project.

**Authentication**: Required (Bearer token)

**Path Parameters**:
- `project_id` (UUID) - Project ID

**Query Parameters**:
- `limit` (int, default=50, max=100) - Number of results

**Response** (200 OK):
```json
[
  {
    "quality_gate_id": "uuid",
    "scan_id": "uuid",
    "project_id": "uuid",
    "passed": true,
    "status": "passing",
    "critical_count": 0,
    "high_count": 0,
    "medium_count": 3,
    "low_count": 8,
    "violations": [],
    "triggered_by": "ci",
    "ci_context": {"branch": "main", "commit": "abc123"},
    "evaluated_at": "2026-01-12T10:30:00Z"
  }
]
```

**Status Codes**:
- `200` OK - Success
- `401` Unauthorized - Invalid or missing token
- `403` Forbidden - Not project owner
- `404` Not Found - Project not found

**Added**: January 2026 (Phase 5.5c)

---

## Support

For API issues:
1. Check interactive docs: http://localhost:8001/docs
2. Review test scripts in `/tmp/`
3. Check API logs: `kubectl logs -n api-service-local deployment/api-service`
4. Verify authentication token is valid
