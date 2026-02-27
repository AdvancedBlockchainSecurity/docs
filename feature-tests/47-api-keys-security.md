# Feature Test: API Keys Security

**Feature:** API Keys Management Security
**Version:** 0.13.2
**Last Updated:** 2026-01-25
**Status:** Active

## Overview

This document covers testing for API Keys security features implemented in the API Keys page security audit.

## Prerequisites

- Growth or Enterprise tier account (Developer/Team do not have API access)
- Valid Bearer token for authentication
- Access to API service at `https://app.0xapogee.local`

### Setting Up Test User Tier

If your test user doesn't have `growth` tier, set it using the admin CLI:

```bash
kubectl exec -n api-service-local deployment/api-service -- \
  python -m src.cli.admin set-tier --email YOUR_EMAIL@example.com --tier growth
```

Verify the tier was set:
```bash
kubectl exec -n api-service-local deployment/api-service -- \
  python -m src.cli.admin list | grep YOUR_EMAIL
```

## Test Scenarios

### 1. Expiration Required

**Requirement:** All API keys must have an expiration date.

#### Test 1.1: Create Key Without Expiration (Should Fail)

```bash
TOKEN=$(./get_token_fixed.sh)
curl -sk -X POST "https://app.0xapogee.local/api/v1/api-keys" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"test-no-expiry","scopes":["contracts:read"]}'
```

**Expected Response:**
```json
{
  "detail": [{
    "type": "missing",
    "loc": ["body", "expires_in_days"],
    "msg": "Field required"
  }]
}
```

#### Test 1.2: Create Key With Expiration (Should Succeed)

```bash
curl -sk -X POST "https://app.0xapogee.local/api/v1/api-keys" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"test-key","scopes":["contracts:read"],"expires_in_days":30}'
```

**Expected Response:**
```json
{
  "id": "...",
  "name": "test-key",
  "key": "bso_...",
  "expires_at": "2026-02-25T...",
  ...
}
```

---

### 2. Rate Limit Enforcement

**Requirement:** Rate limits must not exceed tier maximums (Growth: 300/min, 10000/hr).

#### Test 2.1: Exceeding Rate Limit (Should Fail)

```bash
curl -sk -X POST "https://app.0xapogee.local/api/v1/api-keys" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"test","scopes":["contracts:read"],"expires_in_days":30,"rate_limit_per_minute":500}'
```

**Expected Response:**
```json
{
  "detail": [{
    "type": "less_than_equal",
    "loc": ["body", "rate_limit_per_minute"],
    "msg": "Input should be less than or equal to 300"
  }]
}
```

#### Test 2.2: Valid Rate Limit (Should Succeed)

```bash
curl -sk -X POST "https://app.0xapogee.local/api/v1/api-keys" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"test","scopes":["contracts:read"],"expires_in_days":30,"rate_limit_per_minute":100}'
```

**Expected:** Key created successfully with `rate_limit_per_minute: 100`

---

### 3. X-API-Key Authentication

**Requirement:** API keys can authenticate via `X-API-Key` header.

#### Test 3.1: Create and Use API Key

```bash
# Create a key
RESULT=$(curl -sk -X POST "https://app.0xapogee.local/api/v1/api-keys" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"test","scopes":["contracts:read"],"expires_in_days":30}')

API_KEY=$(echo "$RESULT" | jq -r '.key')

# Use the key to access contracts
curl -sk "https://app.0xapogee.local/api/v1/contracts" \
  -H "X-API-Key: $API_KEY"
```

**Expected Response:** List of contracts (status 200)

#### Test 3.2: Invalid API Key

```bash
curl -sk "https://app.0xapogee.local/api/v1/contracts" \
  -H "X-API-Key: bso_invalid_key"
```

**Expected Response:** 401 Unauthorized

#### Test 3.3: Missing Required Scope

```bash
# Create key with only contracts:read scope
# Try to access vulnerabilities (requires vulnerabilities:read)
curl -sk "https://app.0xapogee.local/api/v1/vulnerabilities" \
  -H "X-API-Key: $API_KEY"
```

**Expected Response:** 403 Forbidden (insufficient scope)

---

### 4. Last Used Tracking

**Requirement:** `last_used_at` and `total_requests` are updated on API key usage.

#### Test 4.1: Verify Usage Tracking

```bash
# Create a key
RESULT=$(curl -sk -X POST "https://app.0xapogee.local/api/v1/api-keys" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"track-test","scopes":["contracts:read"],"expires_in_days":30}')

API_KEY=$(echo "$RESULT" | jq -r '.key')
KEY_ID=$(echo "$RESULT" | jq -r '.id')

# Check initial state
curl -sk "https://app.0xapogee.local/api/v1/api-keys/$KEY_ID" \
  -H "Authorization: Bearer $TOKEN" | jq '.last_used_at, .total_requests'
# Expected: null, 0

# Use the key
curl -sk "https://app.0xapogee.local/api/v1/contracts" \
  -H "X-API-Key: $API_KEY"

# Check updated state
curl -sk "https://app.0xapogee.local/api/v1/api-keys/$KEY_ID" \
  -H "Authorization: Bearer $TOKEN" | jq '.last_used_at, .total_requests'
# Expected: "2026-01-26T...", 1
```

---

### 5. Key Revocation

**Requirement:** Revoked keys cannot be used for authentication.

#### Test 5.1: Revoke and Attempt Use

```bash
# Create and use a key
API_KEY="..."
KEY_ID="..."

# Revoke the key
curl -sk -X DELETE "https://app.0xapogee.local/api/v1/api-keys/$KEY_ID" \
  -H "Authorization: Bearer $TOKEN"

# Try to use revoked key
curl -sk "https://app.0xapogee.local/api/v1/contracts" \
  -H "X-API-Key: $API_KEY"
```

**Expected Response:** 401 Unauthorized (key revoked)

---

### 6. Key Refresh Security

**Requirement:** Refreshing a key invalidates the old key immediately.

#### Test 6.1: Refresh and Verify Old Key Invalid

```bash
# Create a key
API_KEY="..."
KEY_ID="..."

# Refresh the key
RESULT=$(curl -sk -X POST "https://app.0xapogee.local/api/v1/api-keys/$KEY_ID/regenerate" \
  -H "Authorization: Bearer $TOKEN")

NEW_KEY=$(echo "$RESULT" | jq -r '.key')

# Try old key
curl -sk "https://app.0xapogee.local/api/v1/contracts" \
  -H "X-API-Key: $API_KEY"
# Expected: 401 Unauthorized

# Try new key
curl -sk "https://app.0xapogee.local/api/v1/contracts" \
  -H "X-API-Key: $NEW_KEY"
# Expected: 200 OK
```

---

## Cleanup

After testing, revoke all test keys:

```bash
# List all keys
curl -sk "https://app.0xapogee.local/api/v1/api-keys" \
  -H "Authorization: Bearer $TOKEN" | jq '.[] | select(.name | startswith("test")) | .id'

# Revoke each test key
for KEY_ID in ...; do
  curl -sk -X DELETE "https://app.0xapogee.local/api/v1/api-keys/$KEY_ID" \
    -H "Authorization: Bearer $TOKEN"
done
```

## Related Documentation

- [API Key Authentication](/home/pwner/Git/blocksecops-docs/api/api-key.md)
- [Rate Limits](/home/pwner/Git/blocksecops-docs/api/rate-limits.md)
- [Tier Standards](/home/pwner/Git/docs/standards/tier-standards.md)
- [Admin CLI Commands](/home/pwner/Git/docs/playbooks/admin-cli-commands.md)
- [Security Audit](/home/pwner/Git/TaskDocs-BlockSecOps/audits/API-KEYS-SECURITY-AUDIT-2026-01-26.md)
