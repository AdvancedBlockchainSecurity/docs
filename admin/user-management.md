# User Management

Manage users, tiers, and quotas in the Apogee platform.

## Overview

User management covers:
- User account administration
- Tier and subscription management
- Quota monitoring and adjustments
- Access control and permissions

---

## User Tiers

### Available Tiers

| Tier | Scans/Month | Team Size | Features |
|------|-------------|-----------|----------|
| `free` | 10 | 1 user | Basic scanning |
| `developer` | 100 | 1 user | All scanners, priority queue |
| `startup` | 500 | 10 users | Team features, API access |
| `professional` | Unlimited | 25 users | Advanced ML features |
| `enterprise` | Unlimited | Unlimited | SSO, custom integrations |

### Tier Limits

| Tier | Max File Size | Max Files/Scan | Max Contracts |
|------|---------------|----------------|---------------|
| `free` | 5 MB | 10 | 50 |
| `developer` | 10 MB | 50 | 500 |
| `startup` | 25 MB | 100 | 2,000 |
| `professional` | 50 MB | 250 | 10,000 |
| `enterprise` | 100 MB | Unlimited | Unlimited |

---

## User API Operations

### Get Current User

```bash
curl -X GET https://api.0xapogee.com/api/v1/users/me \
  -H "Authorization: Bearer $TOKEN"
```

### Get Enhanced User Info

```bash
curl -X GET https://api.0xapogee.com/api/v1/users/me/enhanced \
  -H "Authorization: Bearer $TOKEN"
```

Response includes:
- User profile
- Current tier details
- Quota usage
- Team memberships
- Recent activity

---

## Quota Management

### Viewing Quota Usage

```bash
curl -X GET https://api.0xapogee.com/api/v1/users/me/quota \
  -H "Authorization: Bearer $TOKEN"
```

### Quota Response

```json
{
  "tier": "developer",
  "scans_used": 45,
  "scans_limit": 100,
  "scans_remaining": 55,
  "contracts_count": 127,
  "contracts_limit": 500,
  "reset_date": "2026-02-01T00:00:00Z"
}
```

### Quota Reset

- Monthly quotas reset on the 1st of each month
- Unused scans do not roll over
- Enterprise tier has no quotas

---

## Team Administration

### Creating a Team

```bash
curl -X POST https://api.0xapogee.com/api/v1/teams \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Security Team",
    "description": "Smart contract security auditors"
  }'
```

### Inviting Members

```bash
curl -X POST https://api.0xapogee.com/api/v1/teams/{team_id}/invites \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "new.member@company.com",
    "role": "member"
  }'
```

### Team Roles

| Role | Permissions |
|------|-------------|
| `owner` | Full admin, billing, delete team |
| `admin` | Manage members, projects |
| `member` | View and scan |
| `viewer` | Read-only access |

---

## Access Control

### Project Permissions

| Permission | Owner | Admin | Member | Viewer |
|------------|-------|-------|--------|--------|
| Create project | Yes | Yes | No | No |
| Upload contracts | Yes | Yes | Yes | No |
| Run scans | Yes | Yes | Yes | No |
| View results | Yes | Yes | Yes | Yes |
| Delete project | Yes | Yes | No | No |
| Manage access | Yes | Yes | No | No |

### API Key Permissions

API keys can be scoped to specific permissions:
- `read` - View data only
- `write` - Create and modify
- `admin` - Full access including delete

---

## Subscription Management

### Viewing Subscription

```bash
curl -X GET https://api.0xapogee.com/api/v1/subscriptions/current \
  -H "Authorization: Bearer $TOKEN"
```

### Upgrading Tier

Tier upgrades are handled through the dashboard:
1. Navigate to **Settings** > **Billing**
2. Click **Upgrade Plan**
3. Select new tier
4. Complete payment

### Downgrading

- Downgrades take effect at end of billing period
- Data exceeding new tier limits is preserved (read-only)
- Active features may become unavailable

---

## Troubleshooting

### User Cannot Login

1. Verify email is correct
2. Check if account exists
3. Reset password if needed
4. Check for account suspension

### Quota Exceeded

1. Check current usage: `/users/me/quota`
2. Wait for monthly reset
3. Purchase additional scans
4. Upgrade tier

### Permission Denied

1. Verify user role
2. Check project/team membership
3. Verify API key permissions
4. Contact team admin
