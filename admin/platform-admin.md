# Platform Admin Panel Guide

**Version:** 1.1.0
**Phase:** 4.6 - Platform Administration
**Last Updated:** 2026-01-24
**Security Hardening:** January 2026

---

## Overview

The Platform Admin Panel provides BlockSecOps internal team with full administrative access to manage the platform. This includes user management, organization oversight, audit logging, and emergency response capabilities.

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
python -m src.cli.admin create-admin --email admin@blocksecops.com --role super_admin
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

1. Login to BlockSecOps dashboard with your regular credentials
2. Navigate to `/admin`
3. You'll be redirected to `/admin/mfa-verify`
4. Enter the 6-digit code from your authenticator app
5. After verification, you'll have access to the admin panel

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
| View user details | support_admin+ | See full user profile with activity |
| Change tier | platform_admin+ | Upgrade/downgrade user tier |
| Disable user | platform_admin+ | Prevent user from logging in |
| Enable user | platform_admin+ | Re-enable disabled user |

**Audit Trail**: All user modifications are logged with before/after values.

### Organization Management (`/admin/organizations`)

View all organizations on the platform:

| Action | Role Required | Description |
|--------|---------------|-------------|
| View organizations | support_admin+ | List all organizations |
| View org details | support_admin+ | See members, projects, activity |

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
python -m src.cli.admin create-admin --email admin@blocksecops.com --role super_admin

# Create platform_admin (tracks creator)
python -m src.cli.admin create-admin \
  --email support@blocksecops.com \
  --role platform_admin \
  --created-by admin@blocksecops.com
```

### List Admins

```bash
python -m src.cli.admin list
```

Output:
```
Email                              Role                 MFA      Created
================================================================================
admin@blocksecops.com              super_admin          Enabled  2026-01-23 10:00
support@blocksecops.com            platform_admin       Pending  2026-01-23 11:00

Total: 2 admin(s)
```

### Revoke Admin Access

```bash
python -m src.cli.admin revoke \
  --email former-admin@blocksecops.com \
  --reason "Employee separation - access no longer required"
```

### Reset MFA (Lost Authenticator)

```bash
python -m src.cli.admin reset-mfa --email admin@blocksecops.com
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
| GET | `/api/v1/admin/users` | List users |
| GET | `/api/v1/admin/users/{id}` | Get user details |
| PATCH | `/api/v1/admin/users/{id}` | Update user |
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

**Last Updated**: 2026-01-24
**Maintained By**: BlockSecOps Team
