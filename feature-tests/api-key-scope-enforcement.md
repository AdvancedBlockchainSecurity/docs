# Feature Test: API Key Scope Enforcement

**Feature:** API Key Scope Enforcement
**Version:** API Service 0.20.2+
**Last Updated:** January 31, 2026

## Overview

API keys must only access endpoints matching their assigned scopes. Write endpoints require explicit write scopes.

---

## Prerequisites

1. User account on `growth` or `enterprise` tier (API keys require paid tier)
2. Two API keys created:
   - **Read-only key:** scopes `contracts:read`, `scans:read`
   - **Write key:** scopes `contracts:write`, `scans:create`

## Test Cases

### TC-1: Read-Only Key Cannot Create Contracts

**Steps:**
1. Use API key with only `contracts:read` scope
2. Attempt to create a contract

**Request:**
```bash
curl -sk -H 'Host: app.0xapogee.com' \
  -H 'X-API-Key: <read-only-api-key>' \
  -H 'Content-Type: application/json' \
  -X POST \
  -d '{"name": "TestContract", "source_code": "pragma solidity ^0.8.0;", "language": "solidity"}' \
  'https://192.168.86.225:30543/api/v1/contracts'
```

**Expected Result:**
```json
{
  "detail": "API key missing required scope. Required one of: contracts:write. Key has: contracts:read, scans:read"
}
```
**Status Code:** 403 Forbidden

---

### TC-2: Write Key Can Create Contracts

**Steps:**
1. Use API key with `contracts:write` scope
2. Create a contract

**Request:**
```bash
curl -sk -H 'Host: app.0xapogee.com' \
  -H 'X-API-Key: <write-api-key>' \
  -H 'Content-Type: application/json' \
  -X POST \
  -d '{"name": "TestContract", "source_code": "pragma solidity ^0.8.0; contract Test {}", "language": "solidity"}' \
  'https://192.168.86.225:30543/api/v1/contracts'
```

**Expected Result:** 201 Created with contract JSON

---

### TC-3: Read-Only Key Cannot Trigger Scans

**Steps:**
1. Use API key with only `scans:read` scope
2. Attempt to create a scan

**Request:**
```bash
curl -sk -H 'Host: app.0xapogee.com' \
  -H 'X-API-Key: <read-only-api-key>' \
  -H 'Content-Type: application/json' \
  -X POST \
  -d '{"contract_id": "<contract-uuid>", "scanner_ids": ["slither"]}' \
  'https://192.168.86.225:30543/api/v1/scans'
```

**Expected Result:**
```json
{
  "detail": "API key missing required scope. Required one of: scans:create. Key has: contracts:read, scans:read"
}
```
**Status Code:** 403 Forbidden

---

### TC-4: Write Key Can Trigger Scans

**Steps:**
1. Use API key with `scans:create` scope
2. Create a scan

**Request:**
```bash
curl -sk -H 'Host: app.0xapogee.com' \
  -H 'X-API-Key: <write-api-key>' \
  -H 'Content-Type: application/json' \
  -X POST \
  -d '{"contract_id": "<contract-uuid>", "scanner_ids": ["slither"]}' \
  'https://192.168.86.225:30543/api/v1/scans'
```

**Expected Result:** 201 Created with scan JSON

---

### TC-5: Bearer Token Has Full Access (No Scope Restriction)

**Steps:**
1. Use Bearer token from dashboard login
2. Create a contract (no scope check for JWT users)

**Request:**
```bash
curl -sk -H 'Host: app.0xapogee.com' \
  -H 'Authorization: Bearer <jwt-token>' \
  -H 'Content-Type: application/json' \
  -X POST \
  -d '{"name": "TestContract", "source_code": "pragma solidity ^0.8.0;", "language": "solidity"}' \
  'https://192.168.86.225:30543/api/v1/contracts'
```

**Expected Result:** 201 Created (JWT users have full access to own resources)

---

### TC-6: Webhook Scope Enforcement

**Steps:**
1. Use API key with `webhooks:write` scope
2. Create a webhook

**Request:**
```bash
curl -sk -H 'Host: app.0xapogee.com' \
  -H 'X-API-Key: <webhooks-write-key>' \
  -H 'Content-Type: application/json' \
  -X POST \
  -d '{"name": "CI/CD Webhook", "url": "https://ci.example.com/webhook", "events": ["scan.completed"]}' \
  'https://192.168.86.225:30543/api/v1/webhooks'
```

**Expected Result:** 201 Created

---

### TC-7: Quality Gate Evaluation (Read Scope)

**Steps:**
1. Use API key with `quality-gates:read` scope
2. Evaluate a quality gate

**Request:**
```bash
curl -sk -H 'Host: app.0xapogee.com' \
  -H 'X-API-Key: <quality-gates-read-key>' \
  -H 'Content-Type: application/json' \
  -X POST \
  -d '{"scan_id": "<scan-uuid>", "triggered_by": "ci"}' \
  'https://192.168.86.225:30543/api/v1/quality-gates/projects/<project-uuid>/evaluate'
```

**Expected Result:** 200 OK with evaluation result

---

## Scope Reference

| Scope | Allows |
|-------|--------|
| `contracts:read` | GET /contracts, GET /contracts/{id} |
| `contracts:write` | POST, PUT, DELETE /contracts, POST /upload |
| `scans:read` | GET /scans, GET /scans/{id} |
| `scans:create` | POST, DELETE /scans |
| `vulnerabilities:read` | GET /vulnerabilities |
| `vulnerabilities:write` | PATCH /vulnerabilities/{id}/status |
| `webhooks:read` | GET /webhooks |
| `webhooks:write` | POST, PATCH, DELETE /webhooks |
| `quality-gates:read` | POST /quality-gates/.../evaluate |
| `quality-gates:write` | PUT, PATCH /quality-gates/... |

---

## Troubleshooting

### 403 Forbidden with "API key missing required scope"

The API key doesn't have the required scope. Create a new key with appropriate scopes or update the existing key.

### 401 Unauthorized

- Check API key is valid and not expired
- Verify `X-API-Key` header is set correctly
- Ensure user is on `growth` or `enterprise` tier

### 200/201 when expecting 403

If using Bearer token (JWT), scope enforcement doesn't apply - JWT users have full access to their own resources.

---

**Related Documentation:**
- [API Endpoint Authentication Standards](/docs/standards/api-endpoint-auth.md)
- [Tier Standards](/docs/standards/tier-standards.md)
