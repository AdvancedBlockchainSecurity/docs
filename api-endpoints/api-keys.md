# API Keys Endpoints

All API key endpoints are prefixed with `/api/v1/api-keys` and require authentication.

---

## POST /api/v1/api-keys

Create a new API key.

```bash
curl -X POST https://api.blocksecops.com/api/v1/api-keys \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "CI/CD Pipeline Key",
    "scopes": ["scans:create", "scans:read", "contracts:read"],
    "expires_in_days": 90
  }'
```

**Request Body:**

| Field            | Type     | Required | Description                              |
|------------------|----------|----------|------------------------------------------|
| name             | string   | Yes      | Human-readable name for the key          |
| scopes           | string[] | Yes      | Permission scopes for the key            |
| expires_in_days  | int      | No       | Days until expiration (null = no expiry) |

**Response 201:**

```json
{
  "id": "key_abc123",
  "name": "CI/CD Pipeline Key",
  "key": "bso_live_abc123def456ghi789...",
  "prefix": "bso_live_abc1",
  "scopes": ["scans:create", "scans:read", "contracts:read"],
  "expires_at": "2026-05-15T12:00:00Z",
  "created_at": "2026-02-14T12:00:00Z"
}
```

> **Important:** The full `key` value is only returned once at creation. Store it securely immediately.

---

## GET /api/v1/api-keys

List all API keys for the authenticated user.

```bash
curl -X GET https://api.blocksecops.com/api/v1/api-keys \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "api_keys": [
    {
      "id": "key_abc123",
      "name": "CI/CD Pipeline Key",
      "prefix": "bso_live_abc1",
      "scopes": ["scans:create", "scans:read", "contracts:read"],
      "last_used_at": "2026-02-14T08:30:00Z",
      "expires_at": "2026-05-15T12:00:00Z",
      "created_at": "2026-02-14T12:00:00Z"
    }
  ],
  "total": 1
}
```

---

## DELETE /api/v1/api-keys

Bulk delete multiple API keys.

```bash
curl -X DELETE https://api.blocksecops.com/api/v1/api-keys \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "key_ids": ["key_abc123", "key_def456"]
  }'
```

**Response 200:**

```json
{
  "deleted": 2,
  "message": "2 API keys deleted successfully"
}
```

---

## GET /api/v1/api-keys/scopes

List all available API key scopes.

```bash
curl -X GET https://api.blocksecops.com/api/v1/api-keys/scopes \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
[
  "contracts:read",
  "contracts:write",
  "scans:create",
  "scans:read",
  "vulnerabilities:read",
  "reports:read",
  "reports:export",
  "webhooks:read",
  "webhooks:manage",
  "monitoring:read",
  "monitoring:manage",
  "api-keys:read",
  "api-keys:manage"
]
```

---

## GET /api/v1/api-keys/{key_id}

Retrieve details for a specific API key.

```bash
curl -X GET https://api.blocksecops.com/api/v1/api-keys/key_abc123 \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "id": "key_abc123",
  "name": "CI/CD Pipeline Key",
  "prefix": "bso_live_abc1",
  "scopes": ["scans:create", "scans:read", "contracts:read"],
  "last_used_at": "2026-02-14T08:30:00Z",
  "last_used_ip": "203.0.113.50",
  "usage_count": 1250,
  "expires_at": "2026-05-15T12:00:00Z",
  "created_at": "2026-02-14T12:00:00Z"
}
```

---

## PATCH /api/v1/api-keys/{key_id}

Update an API key's name or scopes.

```bash
curl -X PATCH https://api.blocksecops.com/api/v1/api-keys/key_abc123 \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Production CI/CD Key",
    "scopes": ["scans:create", "scans:read", "contracts:read", "reports:read"]
  }'
```

**Response 200:**

```json
{
  "id": "key_abc123",
  "name": "Production CI/CD Key",
  "prefix": "bso_live_abc1",
  "scopes": ["scans:create", "scans:read", "contracts:read", "reports:read"],
  "updated_at": "2026-02-14T12:30:00Z"
}
```

---

## DELETE /api/v1/api-keys/{key_id}

Delete a specific API key.

```bash
curl -X DELETE https://api.blocksecops.com/api/v1/api-keys/key_abc123 \
  -H "Authorization: Bearer <token>"
```

**Response 204:** No content.

---

## POST /api/v1/api-keys/{key_id}/regenerate

Regenerate an API key. The old key is immediately invalidated and a new key is issued.

```bash
curl -X POST https://api.blocksecops.com/api/v1/api-keys/key_abc123/regenerate \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "id": "key_abc123",
  "name": "CI/CD Pipeline Key",
  "key": "bso_live_newkey123abc456...",
  "prefix": "bso_live_newk",
  "scopes": ["scans:create", "scans:read", "contracts:read"],
  "regenerated_at": "2026-02-14T12:00:00Z",
  "message": "API key regenerated. The previous key is now invalid."
}
```

> **Important:** The full `key` value is only returned once. Store it securely immediately. The previous key stops working immediately.

---

## GET /api/v1/api-keys/{key_id}/usage

Retrieve usage statistics for a specific API key.

```bash
curl -X GET "https://api.blocksecops.com/api/v1/api-keys/key_abc123/usage?period=30d" \
  -H "Authorization: Bearer <token>"
```

**Query Parameters:**

| Parameter | Type   | Description                          |
|-----------|--------|--------------------------------------|
| period    | string | Time period: 7d, 30d, 90d (default: 30d) |

**Response 200:**

```json
{
  "key_id": "key_abc123",
  "period": "30d",
  "total_requests": 1250,
  "requests_by_day": [
    { "date": "2026-02-14", "count": 42 },
    { "date": "2026-02-13", "count": 38 },
    { "date": "2026-02-12", "count": 55 }
  ],
  "requests_by_scope": {
    "scans:create": 320,
    "scans:read": 780,
    "contracts:read": 150
  },
  "requests_by_status": {
    "2xx": 1200,
    "4xx": 45,
    "5xx": 5
  },
  "last_used_at": "2026-02-14T08:30:00Z",
  "last_used_ip": "203.0.113.50"
}
```
