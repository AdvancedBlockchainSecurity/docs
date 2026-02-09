# Supabase User Creation Pipeline

Technical implementation of user registration, email verification, and local database synchronization.

## Overview

```
Supabase Auth               Dashboard (AuthContext)         API Service (Middleware)
──────────────               ──────────────────────         ──────────────────────
signUp(email, password)  →   SIGNED_IN event fires     →   get_current_user() middleware
Email sent to user           Set initial user from JWT      Decode Supabase JWT (RS256/JWKS)
                             getEnhancedUser() call    →   Lookup by supabase_user_id
User clicks verify link  →   Supabase sets session          If not found → create UserModel
Redirect to Site URL         localStorage: auth_token       Set tier=developer, create quota
```

## Data Flow

### 1. Signup Request

| Step | Component | Action |
|------|-----------|--------|
| User submits form | `Register.tsx` | Calls `register()` from `AuthContext` |
| Supabase SDK | `supabase.auth.signUp()` | Creates user in Supabase project |
| Confirmation email | Supabase | Sends verification link to user's email |
| Redirect URL | Supabase project config | `Site URL` setting controls where verification link redirects |

### 2. Email Verification & Session

| Step | Component | Action |
|------|-----------|--------|
| User clicks email link | Browser | Navigates to `{Site URL}/#access_token=...&type=signup` |
| Supabase SDK detects | `supabase.ts` | `detectSessionInUrl: true` parses hash fragment |
| Auth state change | `AuthContext.tsx` | `onAuthStateChange` fires `SIGNED_IN` event |
| Immediate user set | `AuthContext.tsx` | Creates `EnhancedUser` from JWT with default developer tier |
| Token stored | `AuthContext.tsx` | `localStorage.setItem('auth_token', session.access_token)` |

### 3. Local Database Sync (Lazy)

| Step | Component | Action |
|------|-----------|--------|
| Enhanced profile fetch | `AuthContext.tsx` | `usersApi.getEnhancedUser()` calls `GET /api/v1/users/me/enhanced` |
| JWT decoded | `middleware.py` | Extracts `sub` (Supabase user ID) and `email` from JWT |
| JWKS verification | `middleware.py` | Validates JWT signature against Supabase JWKS endpoint |
| User lookup | `middleware.py` | `SELECT * FROM users WHERE supabase_user_id = :sub` |
| User creation | `middleware.py` | If not found, creates `UserModel(tier="developer", is_active=True)` |
| Quota creation | DB trigger | `create_user_quota()` trigger fires on user insert |
| Response | `users.py` | Returns full user profile with tier and quota data |

## Security Model

### JWT Verification

```python
# Supabase JWT is RS256, verified against JWKS endpoint
# JWKS URL: {SUPABASE_URL}/auth/v1/.well-known/jwks.json
# Claims used: sub (user ID), email, exp (expiry)
```

### Lazy Sync Guarantees

| Guarantee | Implementation |
|-----------|---------------|
| Idempotent | Lookup by `supabase_user_id` prevents duplicate users |
| Atomic | User + quota created in single DB transaction |
| Default tier | New users always start as `developer` (free tier) |
| No data leak | User can only access their own data until added to an org |

## Configuration

### Supabase Project Settings

These must be configured in the [Supabase Dashboard](https://supabase.com/dashboard):

| Setting | Local Value | Production Value |
|---------|-------------|------------------|
| Site URL | `http://app.blocksecops.local` | `https://app.blocksecops.com` |
| Redirect URLs | `http://app.blocksecops.local/**` | `https://app.blocksecops.com/**` |

### Environment Variables

| Variable | Service | Source |
|----------|---------|--------|
| `VITE_SUPABASE_URL` | Dashboard (build-time) | Dockerfile build arg |
| `VITE_SUPABASE_ANON_KEY` | Dashboard (build-time) | Dockerfile build arg |
| `supabase_url` | API Service | ConfigMap |
| `supabase_anon_key` | API Service | Vault (ExternalSecret) |
| `supabase_service_key` | API Service | Vault (ExternalSecret) |

## Database Schema

### Users Table (created by lazy sync)

```sql
-- Created by get_current_user() middleware on first authenticated API call
INSERT INTO users (
    email,              -- From Supabase JWT
    hashed_password,    -- Empty string (Supabase manages passwords)
    supabase_user_id,   -- From JWT 'sub' claim
    is_active,          -- true
    is_superuser,       -- false
    tier                -- 'developer' (default free tier)
) VALUES (...);
```

### User Quotas (created by DB trigger)

```sql
-- Trigger: create_user_quota() fires on users INSERT
-- Creates UserQuotaModel with developer tier limits:
--   monthly_scan_limit: 3
--   retention_days: 7
--   max_team_members: 1
```

## Related Documentation

- [Supabase User Creation Workflow](../workflows/supabase-user-creation-workflow.md) - End-to-end user experience
- [Subscription Workflow](../workflows/subscription-workflow.md) - Tier upgrades after registration
- [Organization Scoping Pipeline](./organization-scoping-pipeline.md) - Org membership and data isolation
- [Domain Management](../standards/domain-management.md) - Supabase redirect URL configuration

---

*Last Updated: February 8, 2026*
