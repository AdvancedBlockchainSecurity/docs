# AI Invariants API Reference

**Version**: v0.20.0
**Base URL**: `/api/v1/invariants`

## Overview

The AI Invariants API provides endpoints for generating formal verification invariants from smart contract source code using Claude AI. This feature helps developers create robust formal specifications automatically.

## Authentication

All endpoints require Bearer token authentication:
```
Authorization: Bearer <jwt_token>
```

## Tier Requirements

| Tier | Access | Monthly Limit |
|------|--------|---------------|
| Developer | Blocked | - |
| Team | Allowed | 10 |
| Growth | Allowed | 50 |
| Enterprise | Allowed | Unlimited |

---

## Endpoints

### Generate Invariants

Generate formal verification invariants from contract source code.

```
POST /api/v1/invariants/generate
```

#### Request Body

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `contract_id` | UUID | Yes | ID of the contract |
| `contract_source` | string | Yes | Solidity source code (max 500KB) |
| `focus_areas` | string[] | No | Areas to focus on (see below) |

**Focus Areas:**
- `reentrancy` - Reentrancy guard invariants
- `overflow` - Arithmetic bounds checking
- `access_control` - Role-based permission invariants
- `state_consistency` - State machine invariants
- `balance` - Token balance invariants

#### Example Request

```bash
curl -X POST https://api.blocksecops.local/api/v1/invariants/generate \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "contract_id": "c961ca39-c568-4245-aa95-497d34b20c28",
    "contract_source": "pragma solidity ^0.8.0;\n\ncontract Token {\n    mapping(address => uint256) public balances;\n    uint256 public totalSupply;\n\n    function transfer(address to, uint256 amount) public {\n        require(balances[msg.sender] >= amount);\n        balances[msg.sender] -= amount;\n        balances[to] += amount;\n    }\n}",
    "focus_areas": ["overflow", "balance"]
  }'
```

#### Success Response (200)

```json
{
  "invariants": [
    {
      "id": "inv_7f3a2b1c-4d5e-6f7a-8b9c-0d1e2f3a4b5c",
      "name": "balanceConsistency",
      "type": "balance",
      "solidity_code": "assert(totalSupply == sumOfAllBalances());",
      "description": "The total supply must always equal the sum of all individual balances. This prevents tokens from being created or destroyed unexpectedly.",
      "confidence": 0.95
    },
    {
      "id": "inv_8a4b3c2d-5e6f-7a8b-9c0d-1e2f3a4b5c6d",
      "name": "noOverflowTransfer",
      "type": "overflow",
      "solidity_code": "require(balances[to] + amount >= balances[to], \"Overflow\");",
      "description": "Ensures that token transfers cannot cause balance overflow for the recipient.",
      "confidence": 0.92
    }
  ],
  "metadata": {
    "model": "claude-sonnet-4-20250514",
    "tokens_input": 856,
    "tokens_output": 423,
    "generation_time_ms": 2340,
    "cached": false
  }
}
```

#### Error Responses

| Code | Error | Description |
|------|-------|-------------|
| 400 | `INVALID_REQUEST` | Invalid request body |
| 401 | `UNAUTHORIZED` | Missing or invalid token |
| 403 | `TIER_NOT_ALLOWED` | Developer tier cannot access |
| 404 | `CONTRACT_NOT_FOUND` | Contract ID not found |
| 422 | `PARSE_ERROR` | Contract source parsing failed |
| 429 | `QUOTA_EXCEEDED` | Monthly limit reached |
| 429 | `RATE_LIMITED` | Too many requests |
| 500 | `AI_SERVICE_ERROR` | Claude API error |

---

### List Templates

Get available invariant templates.

```
GET /api/v1/invariants/templates
```

#### Query Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `category` | string | - | Filter by category |
| `limit` | integer | 20 | Max results |
| `offset` | integer | 0 | Pagination offset |

#### Example Request

```bash
curl -X GET "https://api.blocksecops.local/api/v1/invariants/templates?category=reentrancy" \
  -H "Authorization: Bearer $TOKEN"
```

#### Success Response (200)

```json
{
  "templates": [
    {
      "id": "tpl_1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d",
      "name": "reentrancyLock",
      "category": "reentrancy",
      "description": "Standard reentrancy guard using a boolean lock",
      "template_code": "bool private _locked;\n\nmodifier noReentrant() {\n    require(!_locked, \"Reentrant call\");\n    _locked = true;\n    _;\n    _locked = false;\n}",
      "variables": []
    }
  ],
  "total": 5,
  "limit": 20,
  "offset": 0
}
```

---

### Get Quota Status

Check remaining invariant generation quota.

```
GET /api/v1/invariants/quota
```

#### Example Request

```bash
curl -X GET https://api.blocksecops.local/api/v1/invariants/quota \
  -H "Authorization: Bearer $TOKEN"
```

#### Success Response (200)

```json
{
  "used": 3,
  "limit": 10,
  "remaining": 7,
  "tier": "team",
  "resets_at": "2026-02-01T00:00:00Z",
  "rate_limit": {
    "requests_per_minute": 10,
    "current_usage": 1
  }
}
```

---

### Get Invariant

Retrieve a specific generated invariant.

```
GET /api/v1/invariants/{invariant_id}
```

#### Path Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `invariant_id` | UUID | ID of the invariant |

#### Example Request

```bash
curl -X GET https://api.blocksecops.local/api/v1/invariants/inv_7f3a2b1c-4d5e-6f7a-8b9c-0d1e2f3a4b5c \
  -H "Authorization: Bearer $TOKEN"
```

#### Success Response (200)

```json
{
  "id": "inv_7f3a2b1c-4d5e-6f7a-8b9c-0d1e2f3a4b5c",
  "contract_id": "c961ca39-c568-4245-aa95-497d34b20c28",
  "name": "balanceConsistency",
  "type": "balance",
  "solidity_code": "assert(totalSupply == sumOfAllBalances());",
  "description": "The total supply must always equal the sum of all individual balances.",
  "confidence": 0.95,
  "focus_areas": ["balance"],
  "model_used": "claude-sonnet-4-20250514",
  "created_at": "2026-01-31T12:00:00Z"
}
```

---

### List Contract Invariants

List all generated invariants for a contract.

```
GET /api/v1/invariants/contract/{contract_id}
```

#### Path Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `contract_id` | UUID | ID of the contract |

#### Query Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `type` | string | - | Filter by invariant type |
| `limit` | integer | 20 | Max results |
| `offset` | integer | 0 | Pagination offset |

#### Example Request

```bash
curl -X GET "https://api.blocksecops.local/api/v1/invariants/contract/c961ca39-c568-4245-aa95-497d34b20c28?type=reentrancy" \
  -H "Authorization: Bearer $TOKEN"
```

#### Success Response (200)

```json
{
  "invariants": [
    {
      "id": "inv_7f3a2b1c-4d5e-6f7a-8b9c-0d1e2f3a4b5c",
      "name": "balanceConsistency",
      "type": "balance",
      "confidence": 0.95,
      "created_at": "2026-01-31T12:00:00Z"
    }
  ],
  "total": 1,
  "limit": 20,
  "offset": 0
}
```

---

## Response Headers

| Header | Description |
|--------|-------------|
| `X-Quota-Used` | Current month's usage |
| `X-Quota-Limit` | Monthly limit for tier |
| `X-Quota-Remaining` | Remaining requests |
| `X-Cache-Hit` | `true` if result from cache |
| `X-RateLimit-Remaining` | Requests remaining in window |

---

## Error Response Format

All errors follow this format:

```json
{
  "error": {
    "code": "QUOTA_EXCEEDED",
    "message": "Monthly AI invariant limit reached",
    "details": {
      "limit": 10,
      "used": 10,
      "resets_at": "2026-02-01T00:00:00Z"
    }
  }
}
```

---

## Security

### Prompt Injection Prevention

The API includes protection against prompt injection attacks. The following patterns are detected and rejected:

- Instruction override attempts ("ignore previous instructions")
- Role manipulation ("you are now...")
- System prompt injection ("[INST]", "<<SYS>>")
- Base64 encoded payloads
- Unicode obfuscation

### Input Validation

- Contract source: Max 500KB
- Focus areas: Must be from allowed list
- Contract ID: Must be valid UUID owned by user

### Rate Limiting

- 10 requests per minute per user
- 429 response when exceeded
- `Retry-After` header included

---

## Caching

Results are cached for 24 hours based on:
- Contract source hash (SHA-256)
- Focus areas (sorted)

Cache behavior:
- `X-Cache-Hit: true` header on cache hit
- Identical requests return cached results instantly
- Cache invalidated on contract update

---

## Related

- [Feature Test #50](/docs/feature-tests/50-ai-invariant-generation.md)
- [Database Schema](/docs/database/INVARIANTS.md)
- [Phase E Implementation](/TaskDocs-BlockSecOps/phases/04-phase-5-ai-ml/phase-e-ai-invariants.md)
