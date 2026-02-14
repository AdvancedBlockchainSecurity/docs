# Smart Contract Management API

Base URL: `/api/v1/contracts`

## Overview

Endpoints for creating, retrieving, updating, deleting, and analyzing smart contracts.

---

## Endpoints

### List Contracts

```
GET /api/v1/contracts
```

Returns a paginated list of smart contracts.

| Parameter   | Type    | In    | Description              |
|-------------|---------|-------|--------------------------|
| `page`      | integer | query | Page number (default: 1) |
| `page_size` | integer | query | Items per page           |

**Response: `200 OK`**

```json
{
  "contracts": [
    {
      "id": "uuid",
      "name": "MyToken",
      "language": "solidity",
      "created_at": "2026-01-15T10:30:00Z",
      "updated_at": "2026-01-15T10:30:00Z"
    }
  ],
  "total": 42,
  "page": 1,
  "page_size": 20
}
```

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/contracts?page=1&page_size=20" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Create Contract

```
POST /api/v1/contracts
```

Creates a new smart contract entry.

| Parameter     | Type   | In   | Required | Description                    |
|---------------|--------|------|----------|--------------------------------|
| `name`        | string | body | yes      | Contract name                  |
| `source_code` | string | body | yes      | Full source code of contract   |
| `language`    | string | body | yes      | Language (`solidity`, `vyper`)  |

**Request Body:**

```json
{
  "name": "MyToken",
  "source_code": "pragma solidity ^0.8.0;\n\ncontract MyToken { ... }",
  "language": "solidity"
}
```

**Response: `201 Created`**

```json
{
  "id": "uuid",
  "name": "MyToken",
  "language": "solidity",
  "created_at": "2026-01-15T10:30:00Z"
}
```

**Example:**

```bash
curl -X POST "https://api.example.com/api/v1/contracts" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "MyToken",
    "source_code": "pragma solidity ^0.8.0; contract MyToken {}",
    "language": "solidity"
  }'
```

---

### Check Name Availability

```
GET /api/v1/contracts/check-name
```

Checks whether a contract name is already in use.

| Parameter | Type   | In    | Required | Description          |
|-----------|--------|-------|----------|----------------------|
| `name`    | string | query | yes      | Contract name to check |

**Response: `200 OK`**

```json
{
  "name": "MyToken",
  "available": true
}
```

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/contracts/check-name?name=MyToken" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Get Contract Detail

```
GET /api/v1/contracts/{id}
```

Returns the full detail of a single contract including source code, vulnerability counts, and language metadata.

| Parameter | Type   | In   | Required | Description  |
|-----------|--------|------|----------|--------------|
| `id`      | string | path | yes      | Contract ID  |

**Response: `200 OK`**

```json
{
  "id": "uuid",
  "name": "MyToken",
  "source_code": "pragma solidity ^0.8.0;\n\ncontract MyToken { ... }",
  "language": "solidity",
  "language_metadata": {
    "compiler_version": "0.8.19",
    "evm_version": "paris"
  },
  "vulnerabilities": {
    "critical": 0,
    "high": 2,
    "medium": 5,
    "low": 8,
    "informational": 12
  },
  "created_at": "2026-01-15T10:30:00Z",
  "updated_at": "2026-01-15T10:30:00Z"
}
```

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/contracts/{id}" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Update Contract

```
PUT /api/v1/contracts/{id}
```

Updates an existing contract.

| Parameter     | Type   | In   | Required | Description              |
|---------------|--------|------|----------|--------------------------|
| `id`          | string | path | yes      | Contract ID              |
| `name`        | string | body | no       | Updated name             |
| `source_code` | string | body | no       | Updated source code      |
| `language`    | string | body | no       | Updated language         |

**Example:**

```bash
curl -X PUT "https://api.example.com/api/v1/contracts/{id}" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "MyTokenV2"}'
```

---

### Delete Contract

```
DELETE /api/v1/contracts/{id}
```

Deletes a single contract.

| Parameter | Type   | In   | Required | Description  |
|-----------|--------|------|----------|--------------|
| `id`      | string | path | yes      | Contract ID  |

**Response: `204 No Content`**

**Example:**

```bash
curl -X DELETE "https://api.example.com/api/v1/contracts/{id}" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Bulk Delete Contracts

```
DELETE /api/v1/contracts
```

Deletes multiple contracts at once.

| Parameter      | Type     | In   | Required | Description                |
|----------------|----------|------|----------|----------------------------|
| `contract_ids` | string[] | body | yes      | Array of contract IDs      |

**Request Body:**

```json
{
  "contract_ids": ["uuid-1", "uuid-2", "uuid-3"]
}
```

**Response: `204 No Content`**

**Example:**

```bash
curl -X DELETE "https://api.example.com/api/v1/contracts" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"contract_ids": ["uuid-1", "uuid-2"]}'
```

---

## Analytics Endpoints

### Get Contract Analytics

```
GET /api/v1/contracts/{id}/analytics
```

Returns aggregated analytics for a contract including code quality and gas metrics.

| Parameter | Type   | In   | Required | Description  |
|-----------|--------|------|----------|--------------|
| `id`      | string | path | yes      | Contract ID  |

**Response: `200 OK`**

```json
{
  "codeQuality": {
    "score": 85,
    "totalIssues": 15,
    "topIssues": [
      {"type": "reentrancy", "severity": "high", "count": 2},
      {"type": "unchecked-return", "severity": "medium", "count": 5}
    ]
  },
  "gasMetrics": {
    "totalGasUsed": 2450000,
    "functions": [
      {"name": "transfer", "gasUsed": 51000, "optimization": "moderate"},
      {"name": "approve", "gasUsed": 26000, "optimization": "good"}
    ]
  }
}
```

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/contracts/{id}/analytics" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Get Code Quality Details

```
GET /api/v1/contracts/{id}/analytics/code-quality
```

Returns detailed code quality analysis for a contract.

| Parameter | Type   | In   | Required | Description  |
|-----------|--------|------|----------|--------------|
| `id`      | string | path | yes      | Contract ID  |

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/contracts/{id}/analytics/code-quality" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Get Gas Usage Analysis

```
GET /api/v1/contracts/{id}/analytics/gas-usage
```

Returns detailed gas usage analysis for all contract functions.

| Parameter | Type   | In   | Required | Description  |
|-----------|--------|------|----------|--------------|
| `id`      | string | path | yes      | Contract ID  |

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/contracts/{id}/analytics/gas-usage" \
  -H "Authorization: Bearer $TOKEN"
```

---

## Archive Endpoints

### Archive Contract

```
POST /api/v1/contracts/{id}/archive
```

Archives a contract, making it read-only.

| Parameter | Type   | In   | Required | Description  |
|-----------|--------|------|----------|--------------|
| `id`      | string | path | yes      | Contract ID  |

**Response: `200 OK`**

```json
{
  "id": "uuid",
  "archived": true,
  "archived_at": "2026-02-01T12:00:00Z"
}
```

**Example:**

```bash
curl -X POST "https://api.example.com/api/v1/contracts/{id}/archive" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Get Archive Info

```
GET /api/v1/contracts/{id}/archive-info
```

Returns the archive status and metadata for a contract.

| Parameter | Type   | In   | Required | Description  |
|-----------|--------|------|----------|--------------|
| `id`      | string | path | yes      | Contract ID  |

**Response: `200 OK`**

```json
{
  "id": "uuid",
  "archived": true,
  "archived_at": "2026-02-01T12:00:00Z",
  "archived_by": "user-uuid"
}
```

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/contracts/{id}/archive-info" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Restore Archived Contract

```
POST /api/v1/contracts/{id}/restore
```

Restores a previously archived contract.

| Parameter | Type   | In   | Required | Description  |
|-----------|--------|------|----------|--------------|
| `id`      | string | path | yes      | Contract ID  |

**Response: `200 OK`**

```json
{
  "id": "uuid",
  "archived": false,
  "restored_at": "2026-02-10T08:00:00Z"
}
```

**Example:**

```bash
curl -X POST "https://api.example.com/api/v1/contracts/{id}/restore" \
  -H "Authorization: Bearer $TOKEN"
```

---

## Structure Analysis Endpoints

### Trigger Structure Analysis

```
POST /api/v1/contracts/{id}/analyze-structure
```

Triggers an asynchronous structure analysis of the contract source code.

| Parameter | Type   | In   | Required | Description  |
|-----------|--------|------|----------|--------------|
| `id`      | string | path | yes      | Contract ID  |

**Response: `202 Accepted`**

```json
{
  "message": "Structure analysis started",
  "contract_id": "uuid"
}
```

**Example:**

```bash
curl -X POST "https://api.example.com/api/v1/contracts/{id}/analyze-structure" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Get Contract Structure

```
GET /api/v1/contracts/{id}/structure
```

Returns the full parsed structure of a contract.

| Parameter | Type   | In   | Required | Description  |
|-----------|--------|------|----------|--------------|
| `id`      | string | path | yes      | Contract ID  |

**Response: `200 OK`**

```json
{
  "functions": [
    {"name": "transfer", "visibility": "public", "mutability": "nonpayable", "parameters": ["address", "uint256"]}
  ],
  "events": [
    {"name": "Transfer", "parameters": ["address indexed", "address indexed", "uint256"]}
  ],
  "state_variables": [
    {"name": "totalSupply", "type": "uint256", "visibility": "public"}
  ],
  "summary": {
    "total_functions": 12,
    "total_events": 4,
    "total_state_variables": 6
  }
}
```

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/contracts/{id}/structure" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Get Function List

```
GET /api/v1/contracts/{id}/functions
```

Returns the list of functions defined in the contract.

| Parameter | Type   | In   | Required | Description  |
|-----------|--------|------|----------|--------------|
| `id`      | string | path | yes      | Contract ID  |

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/contracts/{id}/functions" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Get Event List

```
GET /api/v1/contracts/{id}/events
```

Returns the list of events defined in the contract.

| Parameter | Type   | In   | Required | Description  |
|-----------|--------|------|----------|--------------|
| `id`      | string | path | yes      | Contract ID  |

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/contracts/{id}/events" \
  -H "Authorization: Bearer $TOKEN"
```

---

### Get State Variable List

```
GET /api/v1/contracts/{id}/state-variables
```

Returns the list of state variables defined in the contract.

| Parameter | Type   | In   | Required | Description  |
|-----------|--------|------|----------|--------------|
| `id`      | string | path | yes      | Contract ID  |

**Example:**

```bash
curl -X GET "https://api.example.com/api/v1/contracts/{id}/state-variables" \
  -H "Authorization: Bearer $TOKEN"
```
