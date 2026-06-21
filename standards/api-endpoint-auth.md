# API Endpoint Authentication Standards

**Version:** 1.0.0
**Last Updated:** January 31, 2026
**Status:** Active

## Overview

This document defines authentication patterns for API endpoints. All endpoints must use one of the approved authentication dependencies to ensure consistent security across the platform.

---

## Authentication Dependencies

### Available Dependencies

| Dependency | Use Case | Bearer Token | API Key | Scope Enforcement |
|------------|----------|--------------|---------|-------------------|
| `get_current_user` | Dashboard-only endpoints | Yes | No | N/A |
| `get_current_user_or_api_key` | Read endpoints (no scope needed) | Yes | Yes | No |
| `require_auth_with_scope(scopes)` | Write endpoints (CLI/SDK access) | Yes | Yes | Yes (API key only) |
| `require_scope(scopes)` | API-key-only endpoints | No | Yes | Yes |

### Import Statements

```python
# For JWT-only endpoints (dashboard)
from src.infrastructure.auth.middleware import get_current_user

# For dual-auth endpoints
from src.infrastructure.auth.api_key_auth import (
    get_current_user_or_api_key,      # Read endpoints
    require_auth_with_scope,           # Write endpoints with scope enforcement
    require_scope,                     # API-key-only endpoints
)
```

---

## When to Use Each Pattern

### 1. Dashboard-Only Endpoints (`get_current_user`)

Use for endpoints that should **only** be accessible via the web dashboard:

- User profile management
- Wallet linking/unlinking
- Team management
- Billing/subscription management
- Feedback submission

```python
@router.post("/profile/update")
async def update_profile(
    data: ProfileUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: UserModel = Depends(get_current_user),
):
    ...
```

### 2. Read Endpoints (`get_current_user_or_api_key`)

Use for **read-only** endpoints that should be accessible via both dashboard and CLI/SDK:

- GET /contracts
- GET /contracts/{id}
- GET /scans
- GET /scans/{id}
- GET /vulnerabilities

```python
@router.get("/{contract_id}")
async def get_contract(
    contract_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: UserModel = Depends(get_current_user_or_api_key),
):
    ...
```

### 3. Write Endpoints (`require_auth_with_scope`)

Use for **write** endpoints that should be accessible via both dashboard and CLI/SDK:

- POST /contracts (create)
- PUT /contracts/{id} (update)
- DELETE /contracts/{id} (delete)
- POST /scans (trigger scan)
- POST /upload (file upload)

**CRITICAL:** Write endpoints MUST use scope enforcement to prevent unauthorized actions.

```python
@router.post("")
async def create_contract(
    data: ContractCreate,
    db: AsyncSession = Depends(get_db),
    current_user: UserModel = Depends(require_auth_with_scope(["contracts:write"])),
):
    ...

@router.post("")
async def create_scan(
    data: ScanCreate,
    db: AsyncSession = Depends(get_db),
    current_user: UserModel = Depends(require_auth_with_scope(["scans:create"])),
):
    ...
```

---

## API Key Scopes

### Available Scopes

| Scope | Description | Typical Endpoints |
|-------|-------------|-------------------|
| `contracts:read` | Read contract data | GET /contracts, GET /contracts/{id} |
| `contracts:write` | Create/update/delete contracts | POST, PUT, DELETE /contracts, POST /upload |
| `scans:read` | Read scan data | GET /scans, GET /scans/{id} |
| `scans:create` | Create/delete scans | POST, DELETE /scans |
| `vulnerabilities:read` | Read vulnerability data | GET /vulnerabilities |
| `vulnerabilities:write` | Update vulnerability status | PATCH /vulnerabilities/{id}/status |
| `patterns:read` | Read vulnerability patterns | GET /patterns |
| `analytics:read` | Read analytics data | GET /analytics/* |
| `webhooks:read` | Read webhook configs | GET /webhooks |
| `webhooks:write` | Create/update webhooks | POST, PATCH, DELETE /webhooks |
| `quality-gates:read` | Evaluate quality gates | POST /quality-gates/projects/{id}/evaluate |
| `quality-gates:write` | Configure quality gates | PUT, PATCH /quality-gates/projects/{id} |

### Scope-to-Endpoint Mapping

```python
# Contracts
POST /contracts           → require_auth_with_scope(["contracts:write"])
PUT /contracts/{id}       → require_auth_with_scope(["contracts:write"])
DELETE /contracts/{id}    → require_auth_with_scope(["contracts:write"])
DELETE /contracts (batch) → require_auth_with_scope(["contracts:write"])

# Scans
POST /scans               → require_auth_with_scope(["scans:create"])
POST /scans/batch         → require_auth_with_scope(["scans:create"])
DELETE /scans/{id}        → require_auth_with_scope(["scans:create"])
DELETE /scans (batch)     → require_auth_with_scope(["scans:create"])

# Upload
POST /upload              → require_auth_with_scope(["contracts:write"])

# Vulnerabilities
PATCH /vulnerabilities/{id}/status → require_auth_with_scope(["vulnerabilities:write"])

# Webhooks
POST /webhooks            → require_auth_with_scope(["webhooks:write"])
PATCH /webhooks/{id}      → require_auth_with_scope(["webhooks:write"])
DELETE /webhooks/{id}     → require_auth_with_scope(["webhooks:write"])
POST /webhooks/{id}/rotate-secret → require_auth_with_scope(["webhooks:write"])

# Quality Gates (CI/CD)
PUT /quality-gates/projects/{id}     → require_auth_with_scope(["quality-gates:write"])
PATCH /quality-gates/projects/{id}   → require_auth_with_scope(["quality-gates:write"])
POST /quality-gates/projects/{id}/evaluate → require_auth_with_scope(["quality-gates:read"])
```

---

## Security Considerations

### API Key Security Controls

1. **Tier Restriction**: Only `growth` and `enterprise` tier users can create/use API keys
2. **Hashing**: API keys are stored as SHA-256 hashes, never in plaintext
3. **Expiration**: All API keys must have an expiration date (max 365 days)
4. **Revocation**: Revoked keys (is_active=False) are immediately rejected
5. **Rate Limiting**: API keys have per-minute and per-hour rate limits based on tier
6. **Usage Tracking**: `last_used_at` and `total_requests` are tracked for auditing

### Scope Enforcement

- **API Key Users**: Scopes are strictly enforced. A key with `contracts:read` cannot create contracts.
- **JWT Users**: Full access to own resources. Scopes only apply to API keys.

### Why Scope Enforcement Matters

Without scope enforcement, an API key created with `scans:read` (intended for monitoring) could:
- Create/delete contracts (data loss risk)
- Trigger scans (quota/billing impact)
- Delete scans (audit trail loss)

**Always use `require_auth_with_scope()` for write endpoints.**

---

## Adding New Endpoints

When creating a new endpoint, follow this decision tree:

```
Is this a read-only endpoint?
├─ Yes: Does it need CLI/SDK access?
│   ├─ Yes → get_current_user_or_api_key
│   └─ No  → get_current_user
└─ No (write operation): Does it need CLI/SDK access?
    ├─ Yes → require_auth_with_scope(["appropriate:scope"])
    └─ No  → get_current_user
```

### Checklist for New Endpoints

- [ ] Identified correct authentication pattern
- [ ] Using appropriate dependency from this document
- [ ] For write endpoints: using `require_auth_with_scope()` with correct scope
- [ ] Scope exists in `API_KEY_SCOPES` list (api_keys.py)
- [ ] Documented in API reference
- [ ] Tested with both Bearer token and API key

---

## Migration Guide

### Converting JWT-only to Dual-Auth

**Before (JWT only):**
```python
from src.infrastructure.auth.middleware import get_current_user

@router.post("")
async def create_contract(
    current_user: UserModel = Depends(get_current_user),
):
    ...
```

**After (Dual-auth with scope):**
```python
from src.infrastructure.auth.api_key_auth import require_auth_with_scope

@router.post("")
async def create_contract(
    current_user: UserModel = Depends(require_auth_with_scope(["contracts:write"])),
):
    ...
```

---

## Related Documentation

- [API Key Management Endpoints](/api/v1/api-keys)
- [Tier Configuration](/docs/standards/tier-standards.md)
- [Rate Limiting](/docs/standards/rate-limiting.md)

---

## Supabase-direct auth flows (signup, login, password reset, password change)

User credential lifecycle endpoints are **NOT proxied by api-service**. The dashboard talks to Supabase Auth directly using the project anon key:

- `POST {SUPABASE_URL}/auth/v1/signup` — account creation
- `POST {SUPABASE_URL}/auth/v1/token?grant_type=password` — login (and in-app password-change re-auth)
- `POST {SUPABASE_URL}/auth/v1/recover` — request password-reset email
- `PUT  {SUPABASE_URL}/auth/v1/user` — set new password (both reset flow and in-app change flow)
- `POST {SUPABASE_URL}/auth/v1/logout?scope=others` — invalidate other sessions after a password change

Implications for api-service auth standards:

- `require_auth_with_scope()` and `get_current_user` continue to apply on every authenticated api-service endpoint that receives a JWT — those JWTs are issued by Supabase via the above flows, then presented to api-service in the `Authorization: Bearer` header. The validation path (`src/infrastructure/auth/supabase_client.py` with JWKS) is unchanged.
- No `password_reset_tokens` table or `/api/v1/auth/*` endpoints in api-service. Do NOT introduce them — duplicating Supabase's token store would create drift and a second attack surface.
- Email deliverability for the auth flows depends on Supabase SMTP configuration (Resend), NOT on `blocksecops-notification`'s SMTP creds. The two are independent.
- See `docs/workflows/password-management-workflow.md` and `docs/playbooks/password-reset-customer-support.md` for the end-to-end sequence and customer support recipes.

---

**Maintained By:** Apogee Team
