# Phase 4.5 Enterprise Endpoints Implementation

**Date**: December 23, 2025
**Version**: API Service 0.5.0
**Type**: Feature Implementation

## Summary

Implemented core Phase 4.5 enterprise feature API endpoints:
- Organizations and RBAC management
- API Key management with scopes and rate limiting
- Audit logging with filtering and export

## New Endpoints

### Organizations (`/api/v1/organizations`)

| Endpoint | Method | Description | Tier |
|----------|--------|-------------|------|
| `/organizations` | GET | List user's organizations | All |
| `/organizations` | POST | Create organization | Enterprise |
| `/organizations/{id}` | GET | Get organization details | All |
| `/organizations/{id}` | PATCH | Update organization | Enterprise |
| `/organizations/{id}` | DELETE | Delete organization | Enterprise |
| `/organizations/{id}/roles` | GET | List organization roles | All |
| `/organizations/{id}/roles` | POST | Create custom role | Enterprise |
| `/organizations/{id}/roles/{role_id}` | PATCH | Update role | Enterprise |
| `/organizations/{id}/roles/{role_id}` | DELETE | Delete role | Enterprise |
| `/organizations/{id}/members` | GET | List members | All |
| `/organizations/{id}/members` | POST | Add member | Enterprise |
| `/organizations/{id}/members/{member_id}` | PATCH | Update member role | Enterprise |
| `/organizations/{id}/members/{member_id}` | DELETE | Remove member | Enterprise |

**System Roles**: owner, admin, developer, auditor, guest

### API Keys (`/api/v1/api-keys`)

| Endpoint | Method | Description | Tier |
|----------|--------|-------------|------|
| `/api-keys` | GET | List user's API keys | All |
| `/api-keys` | POST | Create API key | Pro+ |
| `/api-keys` | DELETE | Revoke all API keys | Pro+ |
| `/api-keys/scopes` | GET | List available scopes | Public |
| `/api-keys/{key_id}` | GET | Get key details | All |
| `/api-keys/{key_id}` | PATCH | Update key | Pro+ |
| `/api-keys/{key_id}` | DELETE | Revoke key | Pro+ |
| `/api-keys/{key_id}/regenerate` | POST | Regenerate key secret | Pro+ |
| `/api-keys/{key_id}/usage` | GET | Get usage statistics | Pro+ |

**Available Scopes**:
- `contracts:read`, `contracts:write`
- `scans:read`, `scans:create`
- `vulnerabilities:read`, `vulnerabilities:write`
- `patterns:read`, `analytics:read`
- `webhooks:read`, `webhooks:write`

**Key Features**:
- SHA-256 hashed storage with `bso_` prefix
- Configurable rate limits (per minute/hour)
- Maximum 10 active keys per user
- Key regeneration support

### Audit Logs (`/api/v1/audit-logs`)

| Endpoint | Method | Description | Tier |
|----------|--------|-------------|------|
| `/audit-logs` | GET | Query audit logs | Enterprise |
| `/audit-logs/actions` | GET | List action categories | Public |
| `/audit-logs/summary` | GET | Get log statistics | Enterprise |
| `/audit-logs/export/csv` | GET | Export as CSV | Enterprise |
| `/audit-logs/export/json` | GET | Export as JSON | Enterprise |
| `/audit-logs/{log_id}` | GET | Get log details | Enterprise |

**Action Categories**:
- `auth`: login, logout, password changes, MFA, API key operations
- `contracts`: CRUD operations
- `scans`: scan lifecycle events
- `vulnerabilities`: status changes
- `organizations`: org/member/role management
- `webhooks`: webhook operations
- `admin`: settings, billing, SSO, exports

## Database Schema Updates

### api_keys table
```sql
ALTER TABLE api_keys ADD COLUMN rate_limit_per_minute INTEGER DEFAULT 60;
ALTER TABLE api_keys ADD COLUMN rate_limit_per_hour INTEGER DEFAULT 1000;
ALTER TABLE api_keys ADD COLUMN revoked_at TIMESTAMP WITH TIME ZONE;
```

### organizations table
```sql
ALTER TABLE organizations ADD COLUMN stripe_subscription_id VARCHAR(255);
ALTER TABLE organizations ADD COLUMN sso_enabled BOOLEAN DEFAULT false;
ALTER TABLE organizations ADD COLUMN sso_provider VARCHAR(50);
ALTER TABLE organizations ADD COLUMN sso_config JSONB;
ALTER TABLE organizations ADD COLUMN sso_domain VARCHAR(255);
CREATE INDEX ix_organizations_sso_domain ON organizations(sso_domain);
```

### organization_members table
```sql
ALTER TABLE organization_members ADD COLUMN is_active BOOLEAN DEFAULT true;
```

## Files Changed

### New Files
- `src/presentation/api/v1/endpoints/organizations.py` - RBAC endpoints (580+ lines)
- `src/presentation/api/v1/endpoints/api_keys.py` - API key management (350+ lines)
- `src/presentation/api/v1/endpoints/audit_logs.py` - Audit logging (500+ lines)

### Modified Files
- `src/main.py` - Registered new routers
- `k8s/overlays/local/kustomization.yaml` - Version bump to 0.5.0
- `k8s/overlays/local/deployment-patch.yaml` - Fixed Redis password

## Testing

All endpoints tested via Traefik at `http://127.0.0.1:3000/api/v1/`

| Category | Status | Notes |
|----------|--------|-------|
| Health endpoints | ✅ Pass | All 3 healthy |
| Organizations | ✅ Pass | Tier gating works |
| API Keys | ✅ Pass | Scopes returned correctly |
| Audit Logs | ✅ Pass | Actions categories listed |
| Tier restrictions | ✅ Pass | Free/Pro/Enterprise enforced |

## Related

- PR #123: feat(api): Add Phase 4.5 enterprise feature endpoints
- Phase 4.5 Overview: `/TaskDocs-BlockSecOps/phases/04-phase-4.5-enterprise-features/`
