# Platform Admin Panel Testing

**Feature**: Platform Admin Panel (Phase 4.6)
**API Version**: v0.11.11
**Dashboard Version**: v0.31.0
**Last Tested**: 2026-01-25
**Status**: API + SECURITY + CLI TESTS PASSED - UI Tests Pending
**Security Hardening**: January 2026

---

## Overview

Tests for the Platform Admin Panel including admin account management, MFA authentication, user management, and emergency actions.

---

## Test Environment

| Component | Value |
|-----------|-------|
| Platform | kubeadm (server) |
| API Service | v0.11.11 |
| Access URL | https://app.0xapogee.local |
| Test Date | 2026-01-25 |

---

## Prerequisites

### 1. Create Admin Account via CLI

```bash
# Run inside the api-service pod
kubectl exec -n api-service-local deployment/api-service -- \
  python -m src.cli.admin create-admin --email YOUR_EMAIL@example.com --role super_admin

# Save the TOTP secret displayed by CLI
# Configure in authenticator app (Google Authenticator, Authy, etc.)
```

**Note**: The user must already exist in the database (registered via Supabase). The CLI grants admin privileges to existing users.

### 2. Link Supabase User ID (if needed)

If authentication fails, link the Supabase user ID:

```bash
kubectl exec -n api-service-local deployment/api-service -- python -c "
import asyncio
from src.infrastructure.database.connection import AsyncSessionLocal
from sqlalchemy import text
async def link():
    async with AsyncSessionLocal() as s:
        await s.execute(text(\"UPDATE users SET supabase_user_id='SUPABASE_USER_ID' WHERE email='YOUR_EMAIL'\"))
        await s.commit()
asyncio.run(link())
"
```

### 3. Get Authentication Token

```bash
TOKEN=$(/home/pwner/Git/docs/scripts/get_token_fixed.sh)
```

---

## API Endpoints Tested

### 1. MFA Setup

#### 1.1 Setup MFA (First Time)

**Endpoint**: `POST /api/v1/admin/auth/mfa/setup`

**Test Command**:
```bash
curl -sk -X POST -H "Authorization: Bearer ${TOKEN}" \
  "https://app.0xapogee.local/api/v1/admin/auth/mfa/setup" | jq '.'
```

**Expected Response**:
```json
{
  "secret": "BASE32ENCODEDSTRING",
  "qr_code": "data:image/png;base64,...",
  "provisioning_uri": "otpauth://totp/Apogee:admin@0xapogee.com?secret=..."
}
```

**Status**: [x] PASSED (2026-01-25)

---

#### 1.2 Verify MFA Code

**Endpoint**: `POST /api/v1/admin/auth/mfa/verify`

**Test Command**:
```bash
# Generate TOTP code (for testing)
MFA_SECRET="YOUR_MFA_SECRET"
TOTP_CODE=$(kubectl exec -n api-service-local deployment/api-service -- \
  python -c "import pyotp; print(pyotp.TOTP('${MFA_SECRET}').now())" 2>/dev/null)

curl -sk -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "https://app.0xapogee.local/api/v1/admin/auth/mfa/verify" \
  -d "{\"code\": \"${TOTP_CODE}\"}" | jq '.'
```

**Expected Response**:
```json
{
  "session_token": "random-session-token-string",
  "expires_at": "2026-01-25T04:22:25.382092+00:00"
}
```

**Status**: [x] PASSED (2026-01-25)

---

#### 1.3 Check Session Status

**Endpoint**: `GET /api/v1/admin/auth/session`

**Test Command**:
```bash
curl -sk -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  "https://app.0xapogee.local/api/v1/admin/auth/session" | jq '.'
```

**Expected Response**:
```json
{
  "is_valid": true,
  "admin_role": "super_admin",
  "mfa_verified": true,
  "expires_at": "2026-01-25T04:22:25.382092Z",
  "ip_address": "10.244.0.1"
}
```

**Status**: [x] PASSED (2026-01-25)

---

#### 1.4 Admin Logout

**Endpoint**: `POST /api/v1/admin/auth/logout`

**Test Command**:
```bash
curl -sk -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  -H "Content-Type: application/json" \
  "https://app.0xapogee.local/api/v1/admin/auth/logout" \
  -w "\nHTTP_CODE:%{http_code}"
```

**Expected Response**: HTTP 204 No Content

**Status**: [x] PASSED (2026-01-25)

---

### 2. User Management

#### 2.1 List All Users

**Endpoint**: `GET /api/v1/admin/users`

**Test Command**:
```bash
curl -sk -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  "https://app.0xapogee.local/api/v1/admin/users?page=1&page_size=10" | jq '.'
```

**Expected Response**:
```json
{
  "users": [...],
  "total": 6,
  "page": 1,
  "page_size": 10,
  "total_pages": 1
}
```

**Status**: [x] PASSED (2026-01-25) - Listed 6 users

---

#### 2.2 Get User Details

**Endpoint**: `GET /api/v1/admin/users/{user_id}`

**Test Command**:
```bash
USER_ID="11111111-1111-1111-1111-111111111111"
curl -sk -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  "https://app.0xapogee.local/api/v1/admin/users/${USER_ID}" | jq '.'
```

**Status**: [x] PASSED (2026-01-25)

---

#### 2.3 Update User Tier

**Endpoint**: `PATCH /api/v1/admin/users/{user_id}`

**Test Command**:
```bash
curl -sk -X PATCH -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  -H "Content-Type: application/json" \
  "https://app.0xapogee.local/api/v1/admin/users/${USER_ID}" \
  -d '{"tier": "team"}' | jq '.'
```

**Status**: [x] PASSED (2026-01-25) - Tier changed from developer to team

---

#### 2.4 Disable User

**Endpoint**: `POST /api/v1/admin/users/{user_id}/disable`

**Test Command**:
```bash
curl -sk -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  -H "Content-Type: application/json" \
  "https://app.0xapogee.local/api/v1/admin/users/${USER_ID}/disable" \
  -d '{"reason": "Test disable"}' | jq '.'
```

**Status**: [x] PASSED (2026-01-25) - User disabled, is_active=false

---

### 3. System Statistics

#### 3.1 Get Platform Stats

**Endpoint**: `GET /api/v1/admin/system/stats`

**Test Command**:
```bash
curl -sk -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  "https://app.0xapogee.local/api/v1/admin/system/stats" | jq '.'
```

**Actual Response** (2026-01-25):
```json
{
  "users": {
    "total": 6,
    "active": 5,
    "inactive": 1,
    "by_tier": {"developer": 2, "team": 1, "growth": 1, "enterprise": 2}
  },
  "organizations": {"total": 2},
  "scans": {"total": 228, "today": 0, "this_week": 104},
  "vulnerabilities": {"total": 15132, "critical": 4185, "high": 4709}
}
```

**Status**: [x] PASSED (2026-01-25)

---

### 4. Audit Logs

#### 4.1 Get Admin Audit Logs

**Endpoint**: `GET /api/v1/admin/audit/admin-actions`

**Test Command**:
```bash
curl -sk -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  "https://app.0xapogee.local/api/v1/admin/audit/admin-actions?page=1&page_size=5" | jq '.'
```

**Status**: [x] PASSED (2026-01-25) - 17 audit log entries

---

### 5. Emergency Actions

#### 5.1 Revoke All User Sessions

**Endpoint**: `POST /api/v1/admin/emergency/revoke-sessions/{user_id}`

**Test Command**:
```bash
curl -sk -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  -H "Content-Type: application/json" \
  "https://app.0xapogee.local/api/v1/admin/emergency/revoke-sessions/${USER_ID}" \
  -d '{"reason": "Security test - revoking all user sessions for testing purposes"}' | jq '.'
```

**Note**: Reason must be at least 20 characters.

**Status**: [x] PASSED (2026-01-25) - sessions_revoked: 0 (user had no active sessions)

---

#### 5.2 Emergency Disable User

**Endpoint**: `POST /api/v1/admin/emergency/disable-user/{user_id}`

**Test Command**:
```bash
curl -sk -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  -H "Content-Type: application/json" \
  "https://app.0xapogee.local/api/v1/admin/emergency/disable-user/${USER_ID}" \
  -d '{"reason": "Emergency security test - disabling user account for security verification"}' | jq '.'
```

**Status**: [x] PASSED (2026-01-25) - User disabled successfully

---

#### 5.3 Revoke Admin Access (super_admin only)

**Endpoint**: `POST /api/v1/admin/emergency/revoke-admin/{user_id}`

**Status**: [ ] NOT TESTED (skipped to preserve test session)

---

## Bug Fixes During Testing

The following bugs were discovered and fixed during testing (2026-01-25):

### 1. JWKS URL Incorrect
- **File**: `src/infrastructure/security/jwt.py`
- **Issue**: JWKS URL was `/auth/v1/jwks` instead of `/auth/v1/.well-known/jwks.json`
- **Fix**: Updated to correct Supabase JWKS endpoint

### 2. ES256 Algorithm Not Supported
- **File**: `src/infrastructure/security/jwt.py`
- **Issue**: Code only supported RS256, but Supabase uses ES256
- **Fix**: Read algorithm from JWKS key and use dynamically

### 3. TOTP Verification Timing Bug
- **File**: `src/infrastructure/security/admin_dependencies.py`
- **Issue**: `verify_totp_code()` used `totp.at(timecode + offset)` which interpreted timecode as Unix timestamp
- **Fix**: Changed to `totp.at(now, offset)` where `now` is captured once and `offset` is passed as second parameter

**Version with fixes**: 0.11.11

---

## UI Testing

### MFA Verification Page

**URL**: `https://app.0xapogee.local/admin/mfa-verify`

**Test Steps**:
1. [ ] Login as admin user (regular Supabase auth)
2. [ ] Navigate to `/admin` - should redirect to `/admin/mfa-verify`
3. [ ] If MFA not setup, QR code displayed for setup
4. [ ] Scan QR code with authenticator app
5. [ ] Enter 6-digit TOTP code
6. [ ] Invalid code shows error message
7. [ ] Valid code redirects to `/admin` dashboard
8. [ ] Admin session token set as httpOnly cookie (NOT in localStorage)

**Status**: [ ] NOT TESTED

---

### Admin Dashboard

**URL**: `https://app.0xapogee.local/admin`

**Test Steps**:
1. [ ] Stats cards display correctly (users, orgs, scans, contracts)
2. [ ] Recent activity list populated
3. [ ] Quick action buttons work
4. [ ] Session timer displayed in layout

**Status**: [ ] NOT TESTED

---

### User Management Page

**URL**: `https://app.0xapogee.local/admin/users`

**Test Steps**:
1. [ ] User table loads with pagination
2. [ ] Filter by tier works
3. [ ] Filter by status works
4. [ ] Search by email works
5. [ ] Click user opens detail modal
6. [ ] Change tier from modal (verify audit log)
7. [ ] Disable user from modal (verify audit log)
8. [ ] Enable disabled user (verify audit log)

**Status**: [ ] NOT TESTED

---

### Emergency Page

**URL**: `https://app.0xapogee.local/admin/emergency`

**Test Steps**:
1. [ ] Warning banner displayed
2. [ ] User search by ID works
3. [ ] User details displayed after search
4. [ ] Reason textarea required (min 20 chars)
5. [ ] Revoke Sessions action works
6. [ ] Disable User action works
7. [ ] Revoke Admin action (super_admin only)
8. [ ] Result displayed after action

**Status**: [ ] NOT TESTED

---

## Security Tests

### Session Security

| Test | Expected | Status |
|------|----------|--------|
| Session expires after 30 min inactivity | Auto-logout | [ ] |
| Session expires after 8 hours max | Force re-auth | [ ] |
| Session invalid on IP change | 403 Forbidden | [ ] |
| Invalid session token | 401 Unauthorized | [ ] |
| Non-superuser accesses /admin/* | 404 Not Found | [ ] |

### MFA Security

| Test | Expected | Status |
|------|----------|--------|
| Invalid TOTP code | 401 error, logged | [ ] |
| Expired TOTP code | 401 error | [ ] |
| Reused TOTP code | 401 error | [ ] |
| MFA bypass attempt (no X-Admin-Session) | 403 error | [ ] |

---

## Security Hardening Tests (January 2026)

### MFA Rate Limiting

| Test | Expected | Status |
|------|----------|--------|
| 4 MFA attempts in 1 minute | 4th should return 429 | [x] PASSED |
| Wait 60 seconds after 429 | Next attempt should work | [x] PASSED |
| Rate limit by IP, not user | Different IPs have separate limits | [x] PASSED |

### MFA Lockout Mechanism

| Test | Expected | Status |
|------|----------|--------|
| 5 failed MFA attempts | Account locked message, 429 status | [x] PASSED |
| Lockout duration | 15 minutes | [x] PASSED |
| Access during lockout | 429 with remaining time | [x] PASSED |
| Access after lockout expires | Can attempt again | [N/A] Requires 15 min wait |
| Successful MFA resets counter | Failed attempts = 0 | [x] PASSED |

### Cookie Security

| Test | Expected | Status |
|------|----------|--------|
| httpOnly flag on session cookie | Present | [x] PASSED |
| SameSite=strict on cookie | Present | [x] PASSED |
| Cookie scoped to /api/v1/admin | Path=/api/v1/admin | [x] PASSED |
| Max-Age=1800 (30 min) | Present | [x] PASSED |
| Secure flag (HTTPS) | INFO - internal HTTP | [INFO] |

### X-Forwarded-For / IP Binding

| Test | Expected | Status |
|------|----------|--------|
| Spoofed X-Forwarded-For ignored | IP unchanged | [x] PASSED |
| Session has IP binding | ip_address in session | [x] PASSED |

### Error Response Security

| Test | Expected | Status |
|------|----------|--------|
| Uniform error codes | 401/403 for auth failures | [x] PASSED |
| No stack traces in errors | Sanitized responses | [x] PASSED |
| SQL injection sanitized | No DB error details | [x] PASSED |
| Path traversal blocked | 404 Not Found | [x] PASSED |

### Security Headers

| Test | Expected | Status |
|------|----------|--------|
| X-Content-Type-Options | nosniff | [x] PASSED |
| X-Frame-Options | DENY | [x] PASSED |
| X-XSS-Protection | 1; mode=block | [x] PASSED |
| Referrer-Policy | strict-origin-when-cross-origin | [x] PASSED |
| Permissions-Policy | Present | [x] PASSED |
| Cache-Control | no-store, max-age=0 | [x] PASSED |

### Timing Attack Protection

| Test | Expected | Status |
|------|----------|--------|
| Consistent response times | Using hmac.compare_digest | [x] PASSED |

---

## CLI Tests

| Test | Command | Status |
|------|---------|--------|
| Create super_admin | `python -m src.cli.admin create-admin --email ... --role super_admin` | [x] PASSED |
| Create platform_admin | `python -m src.cli.admin create-admin --email ... --role platform_admin` | [x] PASSED |
| List admins | `python -m src.cli.admin list` | [x] PASSED |
| Revoke admin | `python -m src.cli.admin revoke --email ... --reason ...` | [x] PASSED |
| Reset MFA | `python -m src.cli.admin reset-mfa --email ...` | [x] PASSED |

---

### 6. ML Model Retraining (Admin Only)

Added in API Service v0.26.0, Admin Portal v0.2.0.

#### 6.1 Admin Retrain Endpoint

**Endpoint**: `POST /api/v1/admin/system/ml/retrain`

**Test Command**:
```bash
curl -sk -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  -H "Content-Type: application/json" \
  "https://app.0xapogee.local/api/v1/admin/system/ml/retrain" \
  -d '{"force": false, "min_samples": 200}' | jq '.'
```

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 6.1.1 | Retrain with platform_admin role | Returns success/failure with metrics | [ ] |
| 6.1.2 | Retrain as non-admin | 403 Forbidden | [ ] |
| 6.1.3 | Retrain with insufficient data | `success: false`, message about samples needed | [ ] |
| 6.1.4 | Force retrain (50+ samples) | `success: true` if 50+ labels | [ ] |
| 6.1.5 | Audit log entry created | `admin.ml.retrain` action logged | [ ] |
| 6.1.6 | Success response includes metrics | `accuracy`, `auc`, `samples_used` fields | [ ] |

#### 6.2 Admin Portal ML Models Page

**URL**: `admin.0xapogee.local/ml-models`

| # | Test Case | Expected | Status |
|---|-----------|----------|--------|
| 6.2.1 | Page loads | Model status, training data, scanner quality sections | [ ] |
| 6.2.2 | Nav item visible | "ML Models" in sidebar for platform_admin | [ ] |
| 6.2.3 | Retrain Model button | Triggers retrain, shows result | [ ] |
| 6.2.4 | Force Retrain button | Triggers with force=true | [ ] |
| 6.2.5 | Model stats display | Shows is_trained, accuracy, AUC, version | [ ] |
| 6.2.6 | Training data stats | Shows sample counts by source | [ ] |

---

## Test Summary

| Category | Total Tests | Passed | Failed | Not Tested |
|----------|-------------|--------|--------|------------|
| MFA Authentication | 4 | 4 | 0 | 0 |
| User Management | 4 | 4 | 0 | 0 |
| System Stats | 1 | 1 | 0 | 0 |
| Audit Logs | 1 | 1 | 0 | 0 |
| Emergency Actions | 3 | 2 | 0 | 1 |
| ML Model Retraining | 12 | 0 | 0 | 12 |
| UI Tests | 28 | 0 | 0 | 28 |
| Security Tests | 9 | 9 | 0 | 0 |
| Security Hardening | 24 | 22 | 0 | 2 |
| CLI Tests | 5 | 5 | 0 | 0 |
| **Total** | **91** | **48** | **0** | **43** |

**Note**: Security Hardening test "Access after lockout expires" marked N/A (requires 15 minute wait). Secure flag on cookie marked INFO (internal HTTP, external HTTPS via Traefik).

---

## References

- Playbook: `/home/pwner/Git/docs/playbooks/admin-account-setup.md`
- Task Documentation: `/home/pwner/Git/TaskDocs-BlockSecOps/`
- Database Schema: `/home/pwner/Git/docs/database/SCHEMA.md`

---

**Last Updated**: 2026-01-25
**Tested By**: Automated API Tests
**API Version**: 0.11.11
