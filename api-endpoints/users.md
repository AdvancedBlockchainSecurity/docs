# User Endpoints

Base URL: `/api/v1/users`

These endpoints manage user profiles, preferences, activity history, and quota information. All endpoints require authentication.

## Endpoints

| Method | Path | Auth Required | Description | Status |
|--------|------|---------------|-------------|--------|
| GET | `/api/v1/users/me` | Yes | Get current user profile | **Bug** (500) |
| GET | `/api/v1/users/me/activity` | Yes | Get user activity history | OK |
| GET | `/api/v1/users/me/enhanced` | Yes | Get enhanced user profile | **Bug** (500) |
| GET | `/api/v1/users/me/preferences` | Yes | Get user preferences | OK |
| PUT | `/api/v1/users/me/preferences` | Yes | Update user preferences | OK |
| PUT | `/api/v1/users/me` | Yes | Update user profile | OK |
| GET | `/api/v1/users/quota` | Yes | Get user quota and tier info | OK |

---

## GET `/api/v1/users/me`

Returns the authenticated user's profile.

> **Known Bug:** Returns `500 Internal Server Error` due to an email validation issue with `.local` TLD addresses. The email validator rejects `.local` as an invalid top-level domain, causing an unhandled exception.

### Example Request

```bash
curl -X GET https://api.blocksecops.example.com/api/v1/users/me \
  -H "Authorization: Bearer <token>"
```

### Response `500 Internal Server Error`

```json
{
  "detail": "Internal server error"
}
```

### Audit Status

- **Fail** — Email validation bug with `.local` TLD causes 500 error. Needs fix.

---

## GET `/api/v1/users/me/activity`

Returns paginated activity history for the authenticated user.

### Example Request

```bash
curl -X GET https://api.blocksecops.example.com/api/v1/users/me/activity \
  -H "Authorization: Bearer <token>"
```

### Query Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `page` | integer | No | 1 | Page number |
| `limit` | integer | No | 20 | Items per page |

### Response `200 OK`

```json
{
  "activities": [],
  "total_count": 0,
  "page": 1,
  "summary": {
    "scans_completed": 0,
    "total_credits_used": 0
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `activities` | array | List of activity records |
| `total_count` | integer | Total number of activities |
| `page` | integer | Current page number |
| `summary.scans_completed` | integer | Total scans completed by the user |
| `summary.total_credits_used` | integer | Total credits consumed |

### Audit Status

- **Pass** — No issues identified.

---

## GET `/api/v1/users/me/enhanced`

Returns an enhanced user profile with additional computed fields.

> **Known Bug:** Returns `500 Internal Server Error` due to the same email validation issue with `.local` TLD addresses as `/api/v1/users/me`.

### Example Request

```bash
curl -X GET https://api.blocksecops.example.com/api/v1/users/me/enhanced \
  -H "Authorization: Bearer <token>"
```

### Response `500 Internal Server Error`

```json
{
  "detail": "Internal server error"
}
```

### Audit Status

- **Fail** — Same email validation bug with `.local` TLD. Shares root cause with `/api/v1/users/me`.

---

## GET `/api/v1/users/me/preferences`

Returns the authenticated user's preferences.

### Example Request

```bash
curl -X GET https://api.blocksecops.example.com/api/v1/users/me/preferences \
  -H "Authorization: Bearer <token>"
```

### Response `200 OK`

```json
{
  "user_id": "usr_abc123",
  "email_notifications": true,
  "theme": "dark",
  "timezone": "UTC",
  "language": "en"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `user_id` | string | User identifier |
| `email_notifications` | boolean | Whether email notifications are enabled |
| `theme` | string | UI theme preference (`dark`, `light`) |
| `timezone` | string | User timezone (IANA format) |
| `language` | string | Preferred language (ISO 639-1 code) |

### Audit Status

- **Pass** — No issues identified.

---

## PUT `/api/v1/users/me/preferences`

Updates the authenticated user's preferences.

### Example Request

```bash
curl -X PUT https://api.blocksecops.example.com/api/v1/users/me/preferences \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "email_notifications": false,
    "theme": "light",
    "timezone": "America/New_York",
    "language": "en"
  }'
```

### Request Body

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `email_notifications` | boolean | No | Enable or disable email notifications |
| `theme` | string | No | UI theme (`dark`, `light`) |
| `timezone` | string | No | IANA timezone string |
| `language` | string | No | ISO 639-1 language code |

### Response `200 OK`

Returns the updated preferences object (same schema as GET).

### Audit Status

- **Pass** — No issues identified.

---

## PUT `/api/v1/users/me`

Updates the authenticated user's profile.

### Example Request

```bash
curl -X PUT https://api.blocksecops.example.com/api/v1/users/me \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "display_name": "Alice",
    "company": "Acme Corp"
  }'
```

### Request Body

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `display_name` | string | No | User display name |
| `company` | string | No | Company or organization name |

### Response `200 OK`

Returns the updated user profile.

### Audit Status

- **Pass** — Functional, though the GET counterpart is currently broken.

---

## GET `/api/v1/users/quota`

Returns the authenticated user's quota and tier information.

### Example Request

```bash
curl -X GET https://api.blocksecops.example.com/api/v1/users/quota \
  -H "Authorization: Bearer <token>"
```

### Response `200 OK`

```json
{
  "tier": "free",
  "monthly_scan_limit": 100,
  "monthly_scans_used": 12,
  "webhooks_enabled": false,
  "api_access_enabled": true
}
```

| Field | Type | Description |
|-------|------|-------------|
| `tier` | string | User's subscription tier (e.g., `free`, `pro`, `enterprise`) |
| `monthly_scan_limit` | integer | Maximum scans allowed per month |
| `monthly_scans_used` | integer | Scans used in the current billing period |
| `webhooks_enabled` | boolean | Whether webhook integrations are available |
| `api_access_enabled` | boolean | Whether direct API access is enabled |

### Audit Status

- **Pass** — No issues identified.
