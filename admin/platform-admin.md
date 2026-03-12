# Platform Admin Panel Guide

**Version:** 2.0.0
**Phase:** 4.7 - Admin Portal Isolation
**Last Updated:** 2026-02-02
**Security Hardening:** January 2026
**Admin Portal Isolation:** February 2026

---

## Overview

The Platform Admin Panel provides Apogee internal team with full administrative access to manage the platform. This includes user management, organization oversight, audit logging, and emergency response capabilities.

> **February 2026 Update:** The admin panel has been moved to a **separate repository** (`blocksecops-admin-portal`) with its own Supabase project for complete authentication isolation. This ensures that any compromise of customer authentication cannot affect admin access.

---

## Admin Portal Architecture

### Separate Repository

| Component | Location |
|-----------|----------|
| **Customer Dashboard** | `blocksecops-dashboard` at `app.0xapogee.com` |
| **Admin Portal** | `blocksecops-admin-portal` at `admin.0xapogee.com` |

### Authentication Isolation

| Aspect | Customer Dashboard | Admin Portal |
|--------|-------------------|--------------|
| Supabase Project | Customer Supabase | Same project (shared) |
| JWT Verification | Customer JWKS | Same JWKS |
| Cookie Domain | `app.0xapogee.com` | `admin.0xapogee.com` |
| Token Storage | localStorage | **Memory only (XSS protection)** |
| Network Access | Public | **IP allowlist (restricted)** |

### Security Benefits

1. **Network Isolation**: Admin portal restricted to allowlisted IPs at ingress level
2. **XSS Protection**: Admin tokens stored in memory only, not localStorage
3. **Cookie Isolation**: Separate subdomain prevents cookie leakage
4. **Defense in Depth**: Client-side rate limiting supplements server-side controls
5. **Role-Based Access**: `admin_role` check in database - not just any authenticated user
6. **Separate Sessions**: Independent `admin_sessions` table with IP binding

---

## Admin Role Hierarchy

| Role | Level | Capabilities |
|------|-------|--------------|
| **super_admin** | 3 | Full platform access, create/revoke admins, emergency actions |
| **platform_admin** | 2 | User/org management, view audit logs, system stats |
| **support_admin** | 1 | Read-only access to user data and audit logs |

---

## Getting Started

### Creating the First Admin

Admin accounts are created **exclusively via CLI** on the server:

```bash
cd /home/pwner/Git/blocksecops-api-service

# Create the first super_admin
python -m src.cli.admin create-admin --email admin@0xapogee.com --role super_admin
```

The CLI will:
1. Generate a TOTP secret
2. Display the secret and a QR code provisioning URI
3. **Save this secret immediately** - it won't be shown again

### Setting Up MFA

1. Open your authenticator app (Google Authenticator, Authy, 1Password, etc.)
2. Add a new account using the TOTP secret or provisioning URI
3. The app will generate 6-digit codes that refresh every 30 seconds

### First Login

**Admin Portal URL:** `https://admin.0xapogee.com` (production) or `http://admin.0xapogee.com:3000` (local)

1. Navigate to the Admin Portal URL
2. Login with your admin credentials (separate Admin Supabase account)
3. You'll be redirected to `/mfa-verify`
4. Enter the 6-digit code from your authenticator app
5. After verification, you'll have access to the admin panel

> **Note:** Admin portal uses a separate Supabase project. You need an account in the Admin Supabase project (not the customer Supabase).

### Creating Admin Supabase Account

1. Contact a super_admin to create your Admin Supabase account
2. Use the same email as your main Apogee account
3. The admin role and permissions are linked by email

---

## Admin Panel Features

### Dashboard (`/admin`)

Overview of platform statistics:
- Total users by tier
- Active organizations
- Scan activity (24h, 7d, 30d)
- Recent admin actions
- System health status

### User Management (`/admin/users`)

Manage all platform users:

| Action | Role Required | Description |
|--------|---------------|-------------|
| View users | support_admin+ | List and search all users |
| View user details | support_admin+ | See full user profile with quota info |
| Update user | platform_admin+ | Change tier, display name, active status |
| Disable user | platform_admin+ | Prevent user from logging in |
| Enable user | platform_admin+ | Re-enable disabled user |
| Delete user | super_admin | Soft delete (anonymize and deactivate) |

**API Endpoints:**

| Method | Endpoint | Role | Description |
|--------|----------|------|-------------|
| GET | `/api/v1/admin/users` | support_admin+ | List users with pagination, filters |
| GET | `/api/v1/admin/users/{id}` | support_admin+ | Get user detail with quota info |
| PATCH | `/api/v1/admin/users/{id}` | platform_admin+ | Update user (tier, display_name, is_active) |
| POST | `/api/v1/admin/users/{id}/disable` | platform_admin+ | Disable user (requires reason) |
| POST | `/api/v1/admin/users/{id}/enable` | platform_admin+ | Enable user (requires reason) |
| DELETE | `/api/v1/admin/users/{id}` | super_admin | Soft delete user (requires reason) |

**Query Parameters (GET /admin/users):**
- `search` - Search by email or display name
- `tier` - Filter by tier (developer, starter, growth, enterprise)
- `is_active` - Filter by active status (true/false)
- `is_superuser` - Filter by admin status (true/false)
- `page` - Page number (default: 1)
- `page_size` - Items per page (default: 20, max: 100)

**Audit Trail**: All user modifications are logged with before/after values.

### Organization Management (`/admin/organizations`)

Manage all organizations on the platform:

| Action | Role Required | Description |
|--------|---------------|-------------|
| View organizations | support_admin+ | List all organizations |
| View org details | support_admin+ | See members, projects, activity |
| Update organization | platform_admin+ | Change name, description, active status |
| Delete organization | super_admin | Soft delete (deactivate) |

**API Endpoints:**

| Method | Endpoint | Role | Description |
|--------|----------|------|-------------|
| GET | `/api/v1/admin/organizations` | support_admin+ | List organizations with pagination |
| GET | `/api/v1/admin/organizations/{id}` | support_admin+ | Get organization detail with members |
| PATCH | `/api/v1/admin/organizations/{id}` | platform_admin+ | Update organization |
| DELETE | `/api/v1/admin/organizations/{id}` | super_admin | Soft delete organization |

**Query Parameters (GET /admin/organizations):**
- `search` - Search by name or slug
- `is_active` - Filter by active status (true/false)
- `page` - Page number (default: 1)
- `page_size` - Items per page (default: 20, max: 100)

### Audit Logs (`/admin/audit-logs`)

View platform-wide audit logs:

- Filter by user, action type, date range
- View admin-specific actions
- Export to CSV/JSON (enterprise feature)

**Important**: Audit logs are permanent and cannot be deleted.

### System (`/admin/system`)

System health and configuration:

| Section | Description |
|---------|-------------|
| Health Check | Service status, database connections |
| Statistics | Resource usage, queue depths |
| Configuration | View (not edit) system configuration |

### Emergency Actions (`/admin/emergency`)

**Access**: platform_admin or super_admin only

For security incidents and urgent situations:

| Action | Role Required | Effect |
|--------|---------------|--------|
| Revoke Sessions | platform_admin+ | Force logout user immediately |
| Disable User | platform_admin+ | Disable account and revoke sessions |
| Revoke Admin | super_admin only | Remove admin access and reset MFA |

**Requirements**:
- Reason must be at least 20 characters
- All emergency actions are permanently logged
- Cannot be undone without manual intervention

---

## Security Model

### Session Security

| Property | Value |
|----------|-------|
| Session timeout (inactivity) | 30 minutes |
| Maximum session duration | 8 hours |
| IP binding | Enabled (session locked to IP) |
| Token storage | Hashed (SHA-256) |
| **Token delivery** | **httpOnly cookie (SameSite=strict)** |
| **XSS protection** | **Token not accessible via JavaScript** |

> **Security Hardening (January 2026)**: Admin session tokens are now stored in httpOnly cookies instead of localStorage, protecting against XSS attacks. The `X-Admin-Session` header is still supported for API/CLI usage.

### MFA Security

| Property | Value |
|----------|-------|
| Algorithm | TOTP (RFC 6238) |
| Code length | 6 digits |
| Time step | 30 seconds |
| Secret encryption | Fernet (AES-128-CBC + HMAC-SHA256) |
| **Rate limiting** | **3 attempts per minute** |
| **Lockout threshold** | **5 failed attempts** |
| **Lockout duration** | **15 minutes** |
| **Timing protection** | **Constant-time comparison** |

> **Security Hardening (January 2026)**: MFA verification now includes:
> - **Rate limiting**: Maximum 3 MFA attempts per minute per IP to prevent brute force
> - **Account lockout**: After 5 failed attempts, account is locked for 15 minutes
> - **Timing-safe comparison**: Uses `hmac.compare_digest` to prevent timing attacks
> - **Uniform error responses**: All failures return identical error messages

### IP Validation (X-Forwarded-For)

| Property | Value |
|----------|-------|
| Trusted proxies | `127.0.0.1`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` |
| Untrusted sources | Use direct socket IP (ignores X-Forwarded-For) |
| Configuration | `TRUSTED_PROXIES` environment variable |

> **Security Hardening (January 2026)**: X-Forwarded-For headers are only trusted from configured proxy networks. Direct connections from untrusted sources have the header ignored, preventing IP spoofing attacks that could bypass session binding.

### Access Control

- Non-superusers see 404 (not 403) on admin routes
- All admin endpoints require valid MFA session
- Role hierarchy enforced on all actions
- Audit log on every modification
- **Uniform error responses** to prevent information leakage

---

## CLI Commands

### Create Admin

```bash
# Create super_admin
python -m src.cli.admin create-admin --email admin@0xapogee.com --role super_admin

# Create platform_admin (tracks creator)
python -m src.cli.admin create-admin \
  --email support@0xapogee.com \
  --role platform_admin \
  --created-by admin@0xapogee.com
```

### List Admins

```bash
python -m src.cli.admin list
```

Output:
```
Email                              Role                 MFA      Created
================================================================================
admin@0xapogee.com              super_admin          Enabled  2026-01-23 10:00
support@0xapogee.com            platform_admin       Pending  2026-01-23 11:00

Total: 2 admin(s)
```

### Revoke Admin Access

```bash
python -m src.cli.admin revoke \
  --email former-admin@0xapogee.com \
  --reason "Employee separation - access no longer required"
```

### Reset MFA (Lost Authenticator)

```bash
python -m src.cli.admin reset-mfa --email admin@0xapogee.com
```

This will:
1. Generate a new TOTP secret
2. Require user to re-verify MFA on next login
3. Display the new secret (save immediately!)

---

## Best Practices

### Account Security

1. **Use unique email addresses** for admin accounts (not personal accounts)
2. **Store MFA recovery codes** securely (password manager recommended)
3. **Report lost/compromised MFA** immediately for reset
4. **Log out** when leaving admin panel unattended

### Admin Actions

1. **Always provide detailed reasons** for destructive actions
2. **Review user details** before making changes
3. **Use least privilege** - don't use super_admin for routine tasks
4. **Verify user identity** before emergency actions

### Monitoring

1. **Review audit logs** regularly for suspicious activity
2. **Monitor failed MFA attempts** for potential attacks
3. **Check session list** for unauthorized admin sessions

---

## Troubleshooting

### "MFA code invalid"

- Ensure device time is synchronized (NTP)
- Try the next code (codes refresh every 30 seconds)
- If persistent, contact super_admin for MFA reset

### "Too many requests" (429)

- **Rate limited**: You've exceeded 3 MFA attempts per minute
- Wait 60 seconds before trying again
- Ensure you're entering the current code from your authenticator

### "Account locked"

- **Lockout triggered**: 5 failed MFA attempts detected
- Account is locked for 15 minutes
- Wait for lockout to expire, then try again
- If urgent, contact another super_admin to unlock via CLI

### "Session expired"

- Re-enter MFA code to create new session
- Sessions expire after 30 min inactivity or 8 hours max

### "Access denied" (403/404)

- Verify your admin role has required permissions
- Check if session is MFA-verified
- Ensure IP hasn't changed (sessions are IP-bound)

### "User not found" in emergency actions

- User ID must be exact UUID
- Use user search first to get correct ID

### Session not working after network change

- Admin sessions are IP-bound for security
- If your IP changes (VPN, network switch), you must re-authenticate
- This is expected behavior to prevent session hijacking

---

## API Reference

### Authentication Methods

**Method 1: httpOnly Cookie (Recommended for Web)**

```
Authorization: Bearer <supabase-jwt>
Cookie: admin_session=<token>
```

The cookie is automatically set by the server after MFA verification with:
- `httpOnly: true` (not accessible via JavaScript)
- `SameSite: strict` (CSRF protection)
- `Secure: true` (production only, HTTPS required)
- `Path: /api/v1/admin` (scoped to admin endpoints)

**Method 2: Header (API/CLI Usage)**

```
Authorization: Bearer <supabase-jwt>
X-Admin-Session: <admin-session-token>
```

Use this method for programmatic access. The session token is returned in the MFA verify response body.

### Key Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/admin/auth/mfa/setup` | Generate MFA secret |
| POST | `/api/v1/admin/auth/mfa/verify` | Verify MFA, get session |
| GET | `/api/v1/admin/users` | List users (with filters) |
| GET | `/api/v1/admin/users/{id}` | Get user details with quota |
| PATCH | `/api/v1/admin/users/{id}` | Update user |
| POST | `/api/v1/admin/users/{id}/disable` | Disable user |
| POST | `/api/v1/admin/users/{id}/enable` | Enable user |
| DELETE | `/api/v1/admin/users/{id}` | Soft delete user |
| GET | `/api/v1/admin/organizations` | List organizations |
| GET | `/api/v1/admin/organizations/{id}` | Get organization details with members |
| PATCH | `/api/v1/admin/organizations/{id}` | Update organization |
| DELETE | `/api/v1/admin/organizations/{id}` | Soft delete organization |
| GET | `/api/v1/admin/system/stats` | Platform statistics |
| GET | `/api/v1/admin/audit/admin-actions` | Admin audit log |
| POST | `/api/v1/admin/emergency/revoke-sessions/{id}` | Revoke sessions |
| POST | `/api/v1/admin/emergency/disable-user/{id}` | Disable user |
| POST | `/api/v1/admin/emergency/revoke-admin/{id}` | Revoke admin |

---

## Database Tables

### `admin_sessions`

Stores MFA-verified admin sessions with IP binding.

### `admin_audit_logs`

Permanent record of all admin actions with before/after state.

### Users Table (admin columns)

| Column | Type | Description |
|--------|------|-------------|
| `admin_role` | String(50) | Role assignment (`super_admin`, `platform_admin`, `support_admin`) |
| `admin_mfa_enabled` | Boolean | MFA setup complete |
| `admin_mfa_secret` | String(255) | Encrypted TOTP secret (Fernet) |
| `admin_last_activity` | DateTime | Last admin panel activity |
| `admin_session_ip` | String(45) | Current session IP (IPv6 max) |
| `admin_created_by` | UUID | Who granted admin access |
| `admin_created_at` | DateTime | When admin was granted |
| **`mfa_failed_attempts`** | Integer | Consecutive failed MFA attempts (default: 0) |
| **`mfa_locked_until`** | DateTime | Account locked until this time (nullable) |
| **`mfa_last_failed_at`** | DateTime | Last failed MFA attempt timestamp |

> **Security Hardening (January 2026)**: Added MFA lockout tracking columns via migration `041_add_mfa_lockout_fields`.

---

## Related Documentation

- [Feature Tests](../feature-tests/46-platform-admin-panel.md) - Testing checklist
- [Database Schema](../database/SCHEMA.md) - Table definitions
- [User Management](./user-management.md) - User tier management

---

## Changelog

### v2.1.0 (2026-02-03) - User & Organization Management Endpoints

**New API Endpoints:**

User Management (`/admin/users`):
- `GET /admin/users` - List users with search, tier, and status filters
- `GET /admin/users/{id}` - Get user detail with quota information
- `PATCH /admin/users/{id}` - Update user (tier, display_name, is_active)
- `POST /admin/users/{id}/disable` - Disable user with reason
- `POST /admin/users/{id}/enable` - Enable user with reason
- `DELETE /admin/users/{id}` - Soft delete user (super_admin only)

Organization Management (`/admin/organizations`):
- `GET /admin/organizations` - List organizations with search filter
- `GET /admin/organizations/{id}` - Get organization detail with members
- `PATCH /admin/organizations/{id}` - Update organization
- `DELETE /admin/organizations/{id}` - Soft delete organization (super_admin only)

**Backend Changes:**
- New file: `src/presentation/api/v1/endpoints/admin/users.py`
- New file: `src/presentation/api/v1/endpoints/admin/organizations.py`
- Updated: `admin/__init__.py` to register new routers
- API Service version: 0.22.4

**Security:**
- All endpoints use `require_admin_role_portal()` for authentication
- Role-based access control enforced (support_admin, platform_admin, super_admin)
- All actions logged to admin audit log with before/after values
- Reason required for destructive actions (disable, enable, delete)

### v2.0.0 (2026-02-02) - Admin Portal Isolation

**Major Architecture Change:**
- Admin panel moved to separate repository: `blocksecops-admin-portal`
- Separate subdomain: `admin.0xapogee.com`
- Separate Supabase project for complete authentication isolation
- Admin code removed from customer dashboard

**Security Improvements:**
- Admin tokens stored in memory only (not localStorage) - XSS protection
- Client-side MFA rate limiting (5 attempts, 5-minute lockout)
- UUID validation for all user ID inputs
- Confirmation dialogs for destructive actions
- Impersonation tokens auto-hide after 30 seconds
- Clipboard auto-clear after copying sensitive tokens
- QR code URL validation (data: URIs only)
- Production security headers (CSP, COOP, COEP, CORP)

**Backend Changes:**
- New module: `admin_supabase_client.py` for admin JWKS verification
- New dependencies: `get_admin_user_unified()`, `get_current_admin_from_portal()`
- Admin auth endpoints support both admin and customer Supabase JWTs
- Backward compatible with legacy authentication

**Kubernetes:**
- Separate deployment manifests in `blocksecops-admin-portal/k8s/`
- Production ingress with security headers
- Optional IP allowlist middleware

### v1.2.0 (2026-02-06) - Scan Monitoring

**New Feature: Scan Timeout & Auto-Retry Monitoring**
- Admin portal Scan Monitoring page with real-time scan health dashboard
- KPI cards: Active Scans, Stale Scans, Auto-Retries 24h, Failed 24h
- Stale scan table with manual Retry and Force Fail actions
- Automatic stale scan detection via Celery Beat task (every 30s)
- Auto-retry of stuck scans with configurable timeout (600s) and retry limit (3)
- All actions audit logged with required reason field

**Database Changes:**
- Added `retry_count`, `last_retry_at`, `retry_reason` columns to `scans` table
- Added composite index `ix_scans_status_started_at`
- Migration: `067_add_scan_retry_tracking`

**API Endpoints:**
- `GET /api/v1/admin/scan-monitoring/stats` — Scan health statistics (support_admin+)
- `GET /api/v1/admin/scan-monitoring/stale` — List stale scans (support_admin+)
- `POST /api/v1/admin/scan-monitoring/scans/{id}/retry` — Manual retry (platform_admin+)
- `POST /api/v1/admin/scan-monitoring/scans/{id}/fail` — Force fail (platform_admin+)

### v1.1.0 (2026-01-24) - Security Hardening

**Security Improvements:**
- MFA rate limiting: 3 attempts per minute
- MFA lockout: 5 failed attempts = 15 minute lockout
- httpOnly cookies for session tokens (XSS protection)
- Timing-safe TOTP comparison (timing attack protection)
- Uniform error responses (no information leakage)
- X-Forwarded-For validation (IP spoofing protection)

**Database Changes:**
- Added `mfa_failed_attempts`, `mfa_locked_until`, `mfa_last_failed_at` columns
- Migration: `041_add_mfa_lockout_fields`

**Frontend Changes:**
- Session tokens no longer stored in localStorage
- All admin API calls use `withCredentials: true`
- Enhanced logout clears all auth-related storage
- Error messages sanitized to prevent information disclosure

### v1.0.0 (2026-01-23) - Initial Release

- Platform Admin Panel implementation
- MFA-protected admin access
- User and organization management
- Audit logging
- Emergency actions

---

**Last Updated**: 2026-02-02
**Maintained By**: Apogee Team
