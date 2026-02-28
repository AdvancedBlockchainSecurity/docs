# Scanner Results API Documentation

**Version**: 1.0
**Date**: 2025-10-19
**Base URL**: `/api/v1`

## Overview

The Scanner Results API provides endpoints for retrieving scanner-specific analysis results beyond traditional vulnerabilities. These endpoints enable dynamic display of different result types (code quality, gas optimization, formal verification, fuzzing) based on which scanners were actually used in a scan.

## Table of Contents

1. [Authentication](#authentication)
2. [Result Types](#result-types)
3. [Endpoints](#endpoints)
4. [Data Models](#data-models)
5. [Error Handling](#error-handling)
6. [Examples](#examples)

---

## Authentication

All scanner results endpoints require authentication via HttpOnly cookies set during login.

### Authentication Headers
```http
Cookie: session=<session-cookie-value>
```

### Error Responses
- **401 Unauthorized**: Missing or invalid session cookie
- **403 Forbidden**: User does not have access to the requested scan

---

## Result Types

Scanner results are categorized into five types based on the analysis performed:

| Result Type | Description | Scanners |
|------------|-------------|----------|
| `vulnerability` | Security vulnerabilities and issues | slither, mythril, aderyn, vyper, semgrep, sol-azy, sec3-xray, tayt, caracal, starknet-foundry |
| `code_quality` | Code quality issues and best practices | solhint, semgrep, 4naly3er |
| `gas_analysis` | Gas optimization opportunities | slither (gas detectors) |
| `formal_verification` | Formal verification proof results | certora, halmos, move-prover |
| `fuzzing` | Fuzzing test execution results | echidna, foundry-fuzz, medusa, moccasin, trident, cargo-fuzz-solana, cargo-fuzz-move, starknet-foundry |

---

## Endpoints

### 1. Get Available Result Types

Retrieve which result types are available for a specific scan based on the scanners that were used.

**Endpoint**: `GET /scans/{scan_id}/result-types`

**Authentication**: Required

**Path Parameters**:
- `scan_id` (UUID, required): The scan identifier

**Response**: `200 OK`
```json
{
  "scan_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "result_types": [
    "vulnerability",
    "code_quality",
    "gas_analysis",
    "fuzzing"
  ]
}
```

**Error Responses**:
- `401 Unauthorized`: Not authenticated
- `404 Not Found`: Scan does not exist or user does not have access

---

### 2. Get Code Quality Findings

Retrieve code quality findings from linters and static analysis tools.

**Endpoint**: `GET /scans/{scan_id}/code-quality`

**Authentication**: Required

**Path Parameters**:
- `scan_id` (UUID, required): The scan identifier

**Query Parameters**:
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `skip` | integer | No | 0 | Number of results to skip (pagination) |
| `limit` | integer | No | 100 | Maximum results to return (max: 1000) |
| `severity` | string | No | - | Filter by severity: `warning`, `info`, `suggestion` |
| `category` | string | No | - | Filter by category (e.g., `security`, `best-practices`) |

**Response**: `200 OK`
```json
{
  "findings": [
    {
      "id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
      "scan_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "scanner_id": "solhint",
      "severity": "warning",
      "category": "security",
      "title": "Avoid using tx.origin",
      "description": "tx.origin should not be used for authorization as it can be manipulated",
      "location": {
        "file": "contracts/MyToken.sol",
        "line": 45,
        "column": 12,
        "end_line": 45,
        "end_column": 21
      },
      "fix_suggestion": "Use msg.sender instead of tx.origin",
      "rule_id": "avoid-tx-origin",
      "rule_url": "https://solhint.readthedocs.io/en/latest/rules/security/avoid-tx-origin.html",
      "created_at": "2025-10-19T14:30:00Z"
    }
  ],
  "total": 15,
  "page": 1,
  "page_size": 100
}
```

**Ordering**: Results are ordered by severity (warning > info > suggestion), then by creation time (newest first).

**Error Responses**:
- `401 Unauthorized`: Not authenticated
- `404 Not Found`: Scan does not exist or user does not have access

---

### 3. Get Gas Analysis Findings

Retrieve gas optimization opportunities identified by gas analyzers.

**Endpoint**: `GET /scans/{scan_id}/gas-analysis`

**Authentication**: Required

**Path Parameters**:
- `scan_id` (UUID, required): The scan identifier

**Query Parameters**:
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `skip` | integer | No | 0 | Number of results to skip (pagination) |
| `limit` | integer | No | 100 | Maximum results to return (max: 1000) |
| `optimization_level` | string | No | - | Filter by level: `critical`, `high`, `medium`, `low` |

**Response**: `200 OK`
```json
{
  "findings": [
    {
      "id": "8d0e7890-8536-51ef-c4gd-3d074e2f91bg8",
      "scan_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "scanner_id": "slither",
      "function_name": "transfer",
      "gas_cost": 45000,
      "optimization_level": "high",
      "optimization_suggestion": "Cache array length in loop to save gas",
      "potential_savings": 3500,
      "location": {
        "file": "contracts/MyToken.sol",
        "line": 67,
        "column": 5
      },
      "code_example": "// Before\nfor (uint i = 0; i < array.length; i++) { ... }\n\n// After\nuint len = array.length;\nfor (uint i = 0; i < len; i++) { ... }",
      "created_at": "2025-10-19T14:30:00Z"
    }
  ],
  "total": 8,
  "page": 1,
  "page_size": 100
}
```

**Ordering**: Results are ordered by optimization level (critical > high > medium > low), then by potential savings (highest first).

**Error Responses**:
- `401 Unauthorized`: Not authenticated
- `404 Not Found`: Scan does not exist or user does not have access

---

### 4. Get Formal Verification Results

Retrieve formal verification proof results from verification tools.

**Endpoint**: `GET /scans/{scan_id}/formal-verification`

**Authentication**: Required

**Path Parameters**:
- `scan_id` (UUID, required): The scan identifier

**Query Parameters**:
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `skip` | integer | No | 0 | Number of results to skip (pagination) |
| `limit` | integer | No | 100 | Maximum results to return (max: 1000) |
| `status` | string | No | - | Filter by status: `proven`, `failed`, `timeout`, `unknown` |
| `proof_type` | string | No | - | Filter by type: `invariant`, `assertion`, `property` |

**Response**: `200 OK`
```json
{
  "results": [
    {
      "id": "9e1f8901-9647-62fg-d5he-4e185f3g02ch9",
      "scan_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "scanner_id": "certora",
      "property_name": "totalSupply_never_decreases",
      "status": "proven",
      "proof_type": "invariant",
      "description": "Total supply should never decrease after initialization",
      "counterexample": null,
      "verification_time": 12.5,
      "created_at": "2025-10-19T14:30:00Z"
    },
    {
      "id": "af2g9a12-a758-73gh-e6if-5f296g4h13di0",
      "scan_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "scanner_id": "certora",
      "property_name": "balance_cannot_exceed_supply",
      "status": "failed",
      "proof_type": "assertion",
      "description": "Individual balance cannot exceed total supply",
      "counterexample": "{\n  \"balance\": 1000000,\n  \"totalSupply\": 999999,\n  \"path\": [\"mint\", \"transfer\", \"burn\"]\n}",
      "verification_time": 8.3,
      "created_at": "2025-10-19T14:30:00Z"
    }
  ],
  "total": 12,
  "page": 1,
  "page_size": 100
}
```

**Ordering**: Results are ordered by status (failed > proven > timeout > unknown), then by creation time (newest first).

**Error Responses**:
- `401 Unauthorized`: Not authenticated
- `404 Not Found`: Scan does not exist or user does not have access

---

### 5. Get Fuzzing Results

Retrieve fuzzing test execution results from fuzzing tools.

**Endpoint**: `GET /scans/{scan_id}/fuzzing`

**Authentication**: Required

**Path Parameters**:
- `scan_id` (UUID, required): The scan identifier

**Query Parameters**:
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `skip` | integer | No | 0 | Number of results to skip (pagination) |
| `limit` | integer | No | 100 | Maximum results to return (max: 1000) |
| `status` | string | No | - | Filter by status: `passed`, `failed`, `error` |

**Response**: `200 OK`
```json
{
  "results": [
    {
      "id": "bg3h0b23-b869-84hi-f7jg-6g3a7h5i24ej1",
      "scan_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "scanner_id": "echidna",
      "test_name": "test_overflow_protection",
      "status": "passed",
      "executions": 10000,
      "coverage_percentage": 87.5,
      "edge_cases_found": [
        {
          "input": "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
          "description": "Maximum uint256 value"
        }
      ],
      "failure_trace": null,
      "seed": "0x1234567890abcdef",
      "created_at": "2025-10-19T14:30:00Z"
    },
    {
      "id": "ch4i1c34-c97a-95ij-g8kh-7h4b8i6j35fk2",
      "scan_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "scanner_id": "echidna",
      "test_name": "test_reentrancy_guard",
      "status": "failed",
      "executions": 5234,
      "coverage_percentage": 65.2,
      "edge_cases_found": [],
      "failure_trace": "Reentrancy detected:\n  1. Call to external contract at line 45\n  2. State change at line 48\n  3. Recursive call detected",
      "seed": "0xabcdef1234567890",
      "created_at": "2025-10-19T14:30:00Z"
    }
  ],
  "total": 25,
  "page": 1,
  "page_size": 100
}
```

**Ordering**: Results are ordered by status (failed > error > passed), then by coverage percentage (highest first).

**Error Responses**:
- `401 Unauthorized`: Not authenticated
- `404 Not Found`: Scan does not exist or user does not have access

---

## Data Models

### CodeLocation

Represents a location in source code.

```typescript
{
  "file": string,           // File path
  "line": integer,          // Line number (1-indexed)
  "column": integer?,       // Column number (optional)
  "end_line": integer?,     // End line number (optional)
  "end_column": integer?    // End column number (optional)
}
```

### Severity Levels (Code Quality)

- `warning`: Potentially problematic code that should be addressed
- `info`: Informational messages about code patterns
- `suggestion`: Suggestions for improvement

### Optimization Levels (Gas Analysis)

- `critical`: High-impact optimizations that significantly reduce gas costs
- `high`: Important optimizations with substantial savings
- `medium`: Moderate optimizations with reasonable savings
- `low`: Minor optimizations with small savings

### Verification Status (Formal Verification)

- `proven`: Property successfully verified
- `failed`: Property violation found (includes counterexample)
- `timeout`: Verification exceeded time limit
- `unknown`: Verification result inconclusive

### Proof Types (Formal Verification)

- `invariant`: Property that should always hold true
- `assertion`: Explicit assertion in code
- `property`: Custom property specification

### Fuzzing Status

- `passed`: Test executed successfully without failures
- `failed`: Test found a failure case
- `error`: Test encountered an execution error

---

## Error Handling

### Error Response Format

All error responses follow this structure:

```json
{
  "detail": "Error message describing what went wrong"
}
```

### Common Error Codes

| Code | Description | Common Causes |
|------|-------------|---------------|
| 400 | Bad Request | Invalid query parameters, malformed UUID |
| 401 | Unauthorized | Missing or invalid session cookie |
| 403 | Forbidden | User does not own the scan |
| 404 | Not Found | Scan does not exist |
| 500 | Internal Server Error | Database error, unexpected server issue |

---

## Examples

### Example 1: Get All Result Types for a Scan

**Request**:
```http
GET /api/v1/scans/3fa85f64-5717-4562-b3fc-2c963f66afa6/result-types
Cookie: session=<session-cookie>
```

**Response** (200 OK):
```json
{
  "scan_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "result_types": [
    "vulnerability",
    "code_quality",
    "gas_analysis",
    "fuzzing"
  ]
}
```

---

### Example 2: Get Code Quality Warnings Only

**Request**:
```http
GET /api/v1/scans/3fa85f64-5717-4562-b3fc-2c963f66afa6/code-quality?severity=warning&limit=10
Cookie: session=<session-cookie>
```

**Response** (200 OK):
```json
{
  "findings": [
    {
      "id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
      "scan_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "scanner_id": "solhint",
      "severity": "warning",
      "category": "security",
      "title": "Avoid using tx.origin",
      "description": "tx.origin should not be used for authorization",
      "location": {
        "file": "contracts/MyToken.sol",
        "line": 45,
        "column": 12
      },
      "fix_suggestion": "Use msg.sender instead",
      "rule_id": "avoid-tx-origin",
      "rule_url": "https://solhint.readthedocs.io/en/latest/rules/security/avoid-tx-origin.html",
      "created_at": "2025-10-19T14:30:00Z"
    }
  ],
  "total": 5,
  "page": 1,
  "page_size": 10
}
```

---

### Example 3: Get High-Priority Gas Optimizations

**Request**:
```http
GET /api/v1/scans/3fa85f64-5717-4562-b3fc-2c963f66afa6/gas-analysis?optimization_level=high
Cookie: session=<session-cookie>
```

**Response** (200 OK):
```json
{
  "findings": [
    {
      "id": "8d0e7890-8536-51ef-c4gd-3d074e2f91bg8",
      "scan_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "scanner_id": "slither",
      "function_name": "transfer",
      "gas_cost": 45000,
      "optimization_level": "high",
      "optimization_suggestion": "Cache array length in loop",
      "potential_savings": 3500,
      "location": {
        "file": "contracts/MyToken.sol",
        "line": 67
      },
      "code_example": "uint len = array.length;\nfor (uint i = 0; i < len; i++) { ... }",
      "created_at": "2025-10-19T14:30:00Z"
    }
  ],
  "total": 3,
  "page": 1,
  "page_size": 100
}
```

---

### Example 4: Get Failed Formal Verification Results

**Request**:
```http
GET /api/v1/scans/3fa85f64-5717-4562-b3fc-2c963f66afa6/formal-verification?status=failed
Cookie: session=<session-cookie>
```

**Response** (200 OK):
```json
{
  "results": [
    {
      "id": "af2g9a12-a758-73gh-e6if-5f296g4h13di0",
      "scan_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "scanner_id": "certora",
      "property_name": "balance_cannot_exceed_supply",
      "status": "failed",
      "proof_type": "assertion",
      "description": "Individual balance cannot exceed total supply",
      "counterexample": "{\n  \"balance\": 1000000,\n  \"totalSupply\": 999999\n}",
      "verification_time": 8.3,
      "created_at": "2025-10-19T14:30:00Z"
    }
  ],
  "total": 1,
  "page": 1,
  "page_size": 100
}
```

---

### Example 5: Paginate Through Fuzzing Results

**Request** (Page 1):
```http
GET /api/v1/scans/3fa85f64-5717-4562-b3fc-2c963f66afa6/fuzzing?skip=0&limit=20
Cookie: session=<session-cookie>
```

**Request** (Page 2):
```http
GET /api/v1/scans/3fa85f64-5717-4562-b3fc-2c963f66afa6/fuzzing?skip=20&limit=20
Cookie: session=<session-cookie>
```

**Response** (200 OK):
```json
{
  "results": [
    {
      "id": "bg3h0b23-b869-84hi-f7jg-6g3a7h5i24ej1",
      "scan_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
      "scanner_id": "echidna",
      "test_name": "test_overflow_protection",
      "status": "passed",
      "executions": 10000,
      "coverage_percentage": 87.5,
      "edge_cases_found": [],
      "failure_trace": null,
      "seed": "0x1234567890abcdef",
      "created_at": "2025-10-19T14:30:00Z"
    }
  ],
  "total": 25,
  "page": 2,
  "page_size": 20
}
```

---

## Rate Limiting

No rate limiting is currently enforced on scanner results endpoints. However, it is recommended to:

- Use pagination to avoid fetching large result sets
- Cache results on the client side when appropriate
- Avoid polling these endpoints excessively

---

## Changelog

### Version 1.0 (2025-10-19)
- Initial release
- Added 5 scanner results endpoints
- Support for code quality, gas analysis, formal verification, and fuzzing results
- Filtering and pagination support for all endpoints

---

## Support

For questions or issues with the Scanner Results API:
- GitHub Issues: https://github.com/AdvancedBlockchainSecurity/api-service/issues
- Documentation: https://docs.0xapogee.com/api
