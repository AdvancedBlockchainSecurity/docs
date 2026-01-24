# Platform Admin Panel Testing

**Feature**: Platform Admin Panel (Phase 4.6)
**API Version**: v0.12.0
**Dashboard Version**: v0.31.0
**Last Tested**: 2026-01-24
**Status**: SECURITY HARDENING COMPLETE - Requires Testing
**Security Hardening**: January 2026

---

## Overview

Tests for the Platform Admin Panel including admin account management, MFA authentication, user management, and emergency actions.

---

## Test Environment

| Component | Value |
|-----------|-------|
| Platform | Minikube (local) |
| API Service | v0.12.0 |
| Access URL | http://127.0.0.1:3000 |

---

## Prerequisites

### 1. Create Admin Account via CLI

```bash
cd /home/pwner/Git/blocksecops-api-service

# Create first super_admin
python -m src.cli.admin create-admin --email admin@blocksecops.com --role super_admin

# Save the TOTP secret displayed by CLI
# Configure in authenticator app (Google Authenticator, Authy, etc.)
```

### 2. Verify Admin User Created

```bash
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 &
PGPASSWORD=postgres psql -h 127.0.0.1 -U postgres -d solidity_security -c \
  "SELECT email, admin_role, admin_mfa_enabled FROM users WHERE admin_role IS NOT NULL;"
```

---

## API Endpoints Tested

### 1. MFA Setup

#### 1.1 Setup MFA (First Time)

**Endpoint**: `POST /api/v1/admin/auth/mfa/setup`

**Test Command**:
```bash
TOKEN=$(/home/pwner/Git/docs/scripts/get_token_fixed.sh)
curl -s -X POST -H "Authorization: Bearer ${TOKEN}" \
  "http://127.0.0.1:3000/api/v1/admin/auth/mfa/setup" | jq '.'
```

**Expected Response**:
```json
{
  "secret": "BASE32ENCODEDSTRING",
  "qr_code": "data:image/png;base64,...",
  "provisioning_uri": "otpauth://totp/BlockSecOps:admin@blocksecops.com?secret=..."
}
```

**Status**: [ ] NOT TESTED

---

#### 1.2 Verify MFA Code

**Endpoint**: `POST /api/v1/admin/auth/mfa/verify`

**Test Command**:
```bash
TOKEN=$(/home/pwner/Git/docs/scripts/get_token_fixed.sh)
TOTP_CODE="123456"  # Replace with code from authenticator app
curl -s -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "http://127.0.0.1:3000/api/v1/admin/auth/mfa/verify" \
  -d "{\"code\": \"${TOTP_CODE}\"}" | jq '.'
```

**Expected Response**:
```json
{
  "session_token": "random-session-token-string",
  "expires_at": "2026-01-23T12:30:00Z"
}
```

**Status**: [ ] NOT TESTED

---

#### 1.3 Check Session Status

**Endpoint**: `GET /api/v1/admin/auth/session`

**Test Command**:
```bash
TOKEN=$(/home/pwner/Git/docs/scripts/get_token_fixed.sh)
ADMIN_SESSION="your-admin-session-token"
curl -s -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  "http://127.0.0.1:3000/api/v1/admin/auth/session" | jq '.'
```

**Expected Response**:
```json
{
  "is_valid": true,
  "admin_role": "super_admin",
  "mfa_verified": true,
  "expires_at": "2026-01-23T12:30:00Z",
  "ip_address": "127.0.0.1"
}
```

**Status**: [ ] NOT TESTED

---

#### 1.4 Admin Logout

**Endpoint**: `POST /api/v1/admin/auth/logout`

**Test Command**:
```bash
TOKEN=$(/home/pwner/Git/docs/scripts/get_token_fixed.sh)
ADMIN_SESSION="your-admin-session-token"
curl -s -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  -H "Content-Type: application/json" \
  "http://127.0.0.1:3000/api/v1/admin/auth/logout" \
  -d '{"reason": "Manual logout"}' -w "\n%{http_code}"
```

**Expected Response**: HTTP 204 No Content

**Status**: [ ] NOT TESTED

---

### 2. User Management

#### 2.1 List All Users

**Endpoint**: `GET /api/v1/admin/users`

**Test Command**:
```bash
TOKEN=$(/home/pwner/Git/docs/scripts/get_token_fixed.sh)
ADMIN_SESSION="your-admin-session-token"
curl -s -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  "http://127.0.0.1:3000/api/v1/admin/users?page=1&page_size=10" | jq '.'
```

**Expected Response**:
```json
{
  "users": [
    {
      "id": "uuid",
      "email": "user@example.com",
      "is_active": true,
      "tier": "developer",
      "admin_role": null,
      "created_at": "2026-01-01T..."
    }
  ],
  "total": 10,
  "page": 1,
  "page_size": 10,
  "total_pages": 1
}
```

**Status**: [ ] NOT TESTED

---

#### 2.2 Get User Details

**Endpoint**: `GET /api/v1/admin/users/{user_id}`

**Test Command**:
```bash
TOKEN=$(/home/pwner/Git/docs/scripts/get_token_fixed.sh)
ADMIN_SESSION="your-admin-session-token"
USER_ID="target-user-uuid"
curl -s -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  "http://127.0.0.1:3000/api/v1/admin/users/${USER_ID}" | jq '.'
```

**Expected Response**:
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "is_active": true,
  "tier": "developer",
  "tier_updated_at": "2026-01-01T...",
  "admin_role": null,
  "created_at": "2026-01-01T...",
  "organization_count": 1,
  "project_count": 5,
  "scan_count": 25
}
```

**Status**: [ ] NOT TESTED

---

#### 2.3 Update User Tier

**Endpoint**: `PATCH /api/v1/admin/users/{user_id}`

**Test Command**:
```bash
TOKEN=$(/home/pwner/Git/docs/scripts/get_token_fixed.sh)
ADMIN_SESSION="your-admin-session-token"
USER_ID="target-user-uuid"
curl -s -X PATCH -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  -H "Content-Type: application/json" \
  "http://127.0.0.1:3000/api/v1/admin/users/${USER_ID}" \
  -d '{"tier": "team", "reason": "Promotional upgrade"}' | jq '.'
```

**Expected Response**:
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "tier": "team",
  "tier_updated_at": "2026-01-23T..."
}
```

**Status**: [ ] NOT TESTED

---

#### 2.4 Disable User

**Endpoint**: `POST /api/v1/admin/users/{user_id}/disable`

**Test Command**:
```bash
TOKEN=$(/home/pwner/Git/docs/scripts/get_token_fixed.sh)
ADMIN_SESSION="your-admin-session-token"
USER_ID="target-user-uuid"
curl -s -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  -H "Content-Type: application/json" \
  "http://127.0.0.1:3000/api/v1/admin/users/${USER_ID}/disable" \
  -d '{"reason": "Terms of service violation"}' | jq '.'
```

**Expected Response**:
```json
{
  "success": true,
  "message": "User disabled successfully"
}
```

**Status**: [ ] NOT TESTED

---

### 3. System Statistics

#### 3.1 Get Platform Stats

**Endpoint**: `GET /api/v1/admin/system/stats`

**Test Command**:
```bash
TOKEN=$(/home/pwner/Git/docs/scripts/get_token_fixed.sh)
ADMIN_SESSION="your-admin-session-token"
curl -s -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  "http://127.0.0.1:3000/api/v1/admin/system/stats" | jq '.'
```

**Expected Response**:
```json
{
  "users": {
    "total": 100,
    "active": 95,
    "by_tier": {
      "developer": 70,
      "team": 20,
      "growth": 8,
      "enterprise": 2
    }
  },
  "organizations": {
    "total": 15
  },
  "scans": {
    "total": 5000,
    "last_24h": 150,
    "last_7d": 800
  },
  "contracts": {
    "total": 2000
  }
}
```

**Status**: [ ] NOT TESTED

---

### 4. Audit Logs

#### 4.1 Get Admin Audit Logs

**Endpoint**: `GET /api/v1/admin/audit/admin-actions`

**Test Command**:
```bash
TOKEN=$(/home/pwner/Git/docs/scripts/get_token_fixed.sh)
ADMIN_SESSION="your-admin-session-token"
curl -s -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  "http://127.0.0.1:3000/api/v1/admin/audit/admin-actions?page=1&page_size=20" | jq '.'
```

**Expected Response**:
```json
{
  "logs": [
    {
      "id": "uuid",
      "admin_email": "admin@blocksecops.com",
      "admin_role": "super_admin",
      "action": "user.tier_changed",
      "target_type": "user",
      "target_id": "uuid",
      "old_values": {"tier": "developer"},
      "new_values": {"tier": "team"},
      "reason": "Promotional upgrade",
      "ip_address": "127.0.0.1",
      "created_at": "2026-01-23T..."
    }
  ],
  "total": 50,
  "page": 1,
  "page_size": 20
}
```

**Status**: [ ] NOT TESTED

---

### 5. Emergency Actions

#### 5.1 Revoke All User Sessions

**Endpoint**: `POST /api/v1/admin/emergency/revoke-sessions/{user_id}`

**Test Command**:
```bash
TOKEN=$(/home/pwner/Git/docs/scripts/get_token_fixed.sh)
ADMIN_SESSION="your-admin-session-token"
USER_ID="target-user-uuid"
curl -s -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  -H "Content-Type: application/json" \
  "http://127.0.0.1:3000/api/v1/admin/emergency/revoke-sessions/${USER_ID}" \
  -d '{"reason": "Suspected account compromise - security incident response"}' | jq '.'
```

**Expected Response**:
```json
{
  "success": true,
  "message": "All sessions revoked for user"
}
```

**Status**: [ ] NOT TESTED

---

#### 5.2 Emergency Disable User

**Endpoint**: `POST /api/v1/admin/emergency/disable-user/{user_id}`

**Test Command**:
```bash
TOKEN=$(/home/pwner/Git/docs/scripts/get_token_fixed.sh)
ADMIN_SESSION="your-admin-session-token"
USER_ID="target-user-uuid"
curl -s -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  -H "Content-Type: application/json" \
  "http://127.0.0.1:3000/api/v1/admin/emergency/disable-user/${USER_ID}" \
  -d '{"reason": "Emergency security lockout - potential breach investigation"}' | jq '.'
```

**Expected Response**:
```json
{
  "success": true,
  "message": "User disabled and all sessions revoked"
}
```

**Status**: [ ] NOT TESTED

---

#### 5.3 Revoke Admin Access (super_admin only)

**Endpoint**: `POST /api/v1/admin/emergency/revoke-admin/{user_id}`

**Test Command**:
```bash
TOKEN=$(/home/pwner/Git/docs/scripts/get_token_fixed.sh)
ADMIN_SESSION="your-admin-session-token"
USER_ID="target-admin-uuid"
curl -s -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  -H "Content-Type: application/json" \
  "http://127.0.0.1:3000/api/v1/admin/emergency/revoke-admin/${USER_ID}" \
  -d '{"reason": "Admin access terminated - employee separation"}' | jq '.'
```

**Expected Response**:
```json
{
  "success": true,
  "message": "Admin access revoked, MFA reset, all sessions terminated"
}
```

**Status**: [ ] NOT TESTED

---

## UI Testing

### MFA Verification Page

**URL**: `http://127.0.0.1:3000/admin/mfa-verify`
**Component**: `src/pages/admin/MfaVerify.tsx`

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

**URL**: `http://127.0.0.1:3000/admin`
**Component**: `src/pages/admin/AdminDashboard.tsx`

**Test Steps**:
1. [ ] Stats cards display correctly (users, orgs, scans, contracts)
2. [ ] Recent activity list populated
3. [ ] Quick action buttons work
4. [ ] Session timer displayed in layout

**Status**: [ ] NOT TESTED

---

### User Management Page

**URL**: `http://127.0.0.1:3000/admin/users`
**Component**: `src/pages/admin/AdminUsers.tsx`

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

**URL**: `http://127.0.0.1:3000/admin/emergency`
**Component**: `src/pages/admin/AdminEmergency.tsx`
**Access**: platform_admin or super_admin only

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

### Role-Based Access

| Test | Expected | Status |
|------|----------|--------|
| support_admin tries to modify user | 403 Forbidden | [ ] |
| platform_admin tries to revoke admin | 403 Forbidden | [ ] |
| super_admin can revoke admin | Success | [ ] |

---

## Security Hardening Tests (January 2026)

### MFA Rate Limiting

| Test | Expected | Status |
|------|----------|--------|
| 4 MFA attempts in 1 minute | 4th should return 429 | [ ] |
| Wait 60 seconds after 429 | Next attempt should work | [ ] |
| Rate limit by IP, not user | Different IPs have separate limits | [ ] |

**Test Command**:
```bash
TOKEN=$(/home/pwner/Git/docs/scripts/get_token_fixed.sh)
# Attempt 4 MFA verifications rapidly - 4th should fail with 429
for i in 1 2 3 4; do
  echo "Attempt $i:"
  curl -s -o /dev/null -w "%{http_code}" -X POST \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    "http://127.0.0.1:3000/api/v1/admin/auth/mfa/verify" \
    -d '{"code": "000000"}'
  echo ""
  sleep 1
done
```

---

### MFA Lockout Mechanism

| Test | Expected | Status |
|------|----------|--------|
| 5 failed MFA attempts | Account locked message, 429 status | [ ] |
| Lockout duration | 15 minutes | [ ] |
| Access during lockout | 429 with remaining time | [ ] |
| Access after lockout expires | Can attempt again | [ ] |
| Successful MFA resets counter | Failed attempts = 0 | [ ] |

**Test Command**:
```bash
TOKEN=$(/home/pwner/Git/docs/scripts/get_token_fixed.sh)
# Attempt 5 invalid MFA codes to trigger lockout
for i in 1 2 3 4 5; do
  echo "Attempt $i:"
  curl -s -X POST \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    "http://127.0.0.1:3000/api/v1/admin/auth/mfa/verify" \
    -d '{"code": "000000"}' | jq '.detail'
  sleep 1
done
# 5th attempt should show lockout message
```

**Database Verification**:
```bash
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 &
PGPASSWORD=postgres psql -h 127.0.0.1 -U postgres -d solidity_security -c \
  "SELECT email, mfa_failed_attempts, mfa_locked_until, mfa_last_failed_at
   FROM users WHERE admin_role IS NOT NULL;"
```

---

### X-Forwarded-For Validation (IP Spoofing Prevention)

| Test | Expected | Status |
|------|----------|--------|
| Untrusted source + X-Forwarded-For header | Uses socket IP, ignores header | [ ] |
| Trusted proxy (127.0.0.1) + X-Forwarded-For | Uses header value | [ ] |
| Session IP binding with spoofed header | Session invalidated on IP change | [ ] |

**Test Command**:
```bash
TOKEN=$(/home/pwner/Git/docs/scripts/get_token_fixed.sh)
ADMIN_SESSION="your-admin-session-token"

# Test: Set fake X-Forwarded-For from non-proxy IP (should be ignored)
curl -s -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  -H "X-Forwarded-For: 1.2.3.4" \
  "http://127.0.0.1:3000/api/v1/admin/auth/session" | jq '.ip_address'
# Expected: 127.0.0.1 (socket IP), NOT 1.2.3.4
```

---

### httpOnly Cookie for Session Token

| Test | Expected | Status |
|------|----------|--------|
| MFA verify sets httpOnly cookie | Cookie in response headers | [ ] |
| Cookie has SameSite=strict | Visible in browser dev tools | [ ] |
| Cookie has Path=/api/v1/admin | Scoped to admin endpoints | [ ] |
| localStorage.getItem('admin_session_token') | Returns null (not in JS storage) | [ ] |
| Logout clears cookie | Cookie deleted | [ ] |

**Test Command**:
```bash
TOKEN=$(/home/pwner/Git/docs/scripts/get_token_fixed.sh)
TOTP_CODE="123456"  # Replace with valid code

# Verify cookie is set in response
curl -v -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "http://127.0.0.1:3000/api/v1/admin/auth/mfa/verify" \
  -d "{\"code\": \"${TOTP_CODE}\"}" 2>&1 | grep -i "set-cookie"
# Expected: Set-Cookie: admin_session=...; HttpOnly; SameSite=Strict; Path=/api/v1/admin
```

---

### Timing Attack Protection

| Test | Expected | Status |
|------|----------|--------|
| Valid code response time | ~same as invalid code | [ ] |
| Measure 10 valid vs 10 invalid | Standard deviation < 50ms | [ ] |

**Test Command** (requires valid TOTP secret):
```bash
# Time 10 invalid code attempts
for i in $(seq 1 10); do
  time curl -s -o /dev/null -X POST \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    "http://127.0.0.1:3000/api/v1/admin/auth/mfa/verify" \
    -d '{"code": "000000"}'
done
# Response times should be consistent regardless of code validity
```

---

### Uniform Error Responses

| Test | Expected | Status |
|------|----------|--------|
| Invalid TOTP code | 401 "Invalid MFA code" | [ ] |
| Decryption error (corrupt secret) | 401 "Invalid MFA code" (same message) | [ ] |
| No stack traces in error response | Clean JSON error only | [ ] |

---

### Complete Logout Cleanup

| Test | Expected | Status |
|------|----------|--------|
| After logout, localStorage.getItem('auth_token') | null | [ ] |
| After logout, all sb-* keys cleared | No Supabase keys remain | [ ] |
| After logout, sessionStorage cleared | Empty | [ ] |
| After logout, admin_session_token cleared | null | [ ] |

**Browser Console Test**:
```javascript
// After logout, run in browser console:
console.log('auth_token:', localStorage.getItem('auth_token'));
console.log('sb-* keys:', Object.keys(localStorage).filter(k => k.startsWith('sb-')));
console.log('supabase keys:', Object.keys(localStorage).filter(k => k.includes('supabase')));
console.log('sessionStorage length:', sessionStorage.length);
// All should be empty/null
```

---

### Error Message Sanitization (Frontend)

| Test | Expected | Status |
|------|----------|--------|
| 400 Bad Request | "Invalid request. Please check your input." | [ ] |
| 401 Unauthorized | "Authentication required. Please sign in." | [ ] |
| 403 Forbidden | "You do not have permission for this action." | [ ] |
| 429 Too Many Requests | "Too many requests. Please wait before trying again." | [ ] |
| 500 Internal Server Error | "A server error occurred. Please try again later." | [ ] |
| Stack trace in response | NOT displayed to user | [ ] |

---

## CLI Tests

### Admin Creation

```bash
# Test: Create super_admin
python -m src.cli.admin create-admin --email test-admin@blocksecops.com --role super_admin
# Expected: Success, TOTP secret displayed

# Test: Create platform_admin with creator tracking
python -m src.cli.admin create-admin --email support@blocksecops.com --role platform_admin --created-by test-admin@blocksecops.com
# Expected: Success, creator tracked in admin_created_by

# Test: List admins
python -m src.cli.admin list
# Expected: Table showing all admins with roles and MFA status

# Test: Revoke admin
python -m src.cli.admin revoke --email support@blocksecops.com --reason "Access no longer needed"
# Expected: Confirmation prompt, success message

# Test: Reset MFA
python -m src.cli.admin reset-mfa --email test-admin@blocksecops.com
# Expected: Confirmation prompt, new TOTP secret displayed
```

**Status**: [ ] NOT TESTED

---

## Test Summary

| Category | Total Tests | Passed | Failed |
|----------|-------------|--------|--------|
| MFA Authentication | 4 | 0 | 0 |
| User Management | 4 | 0 | 0 |
| System Stats | 1 | 0 | 0 |
| Audit Logs | 1 | 0 | 0 |
| Emergency Actions | 3 | 0 | 0 |
| UI - MFA Verify | 8 | 0 | 0 |
| UI - Dashboard | 4 | 0 | 0 |
| UI - Users | 8 | 0 | 0 |
| UI - Emergency | 8 | 0 | 0 |
| Security Tests (Base) | 10 | 0 | 0 |
| **Security Hardening (New)** | **24** | **0** | **0** |
| CLI Tests | 5 | 0 | 0 |
| **Total** | **80** | **0** | **0** |

### Security Hardening Tests Breakdown

| Category | Tests | Description |
|----------|-------|-------------|
| MFA Rate Limiting | 3 | 3 attempts/min limit |
| MFA Lockout | 5 | 5 attempts = 15 min lockout |
| X-Forwarded-For Validation | 3 | IP spoofing prevention |
| httpOnly Cookie | 5 | XSS protection |
| Timing Attack Protection | 2 | Constant-time comparison |
| Uniform Error Responses | 3 | No information leakage |
| Logout Cleanup | 4 | Clear all auth storage |
| Error Sanitization | 6 | Safe user messages |

---

## References

- Task Documentation: `/home/pwner/Git/TaskDocs-BlockSecOps/DOCUMENTATION-UPDATE-2026-01-23-PLATFORM-ADMIN-PANEL.md`
- Database Schema: `/home/pwner/Git/docs/database/SCHEMA.md`
- Admin Guide: `/home/pwner/Git/docs/admin/platform-admin.md`

---

**Last Updated**: 2026-01-24
**Created By**: BlockSecOps Team
**Security Hardening**: January 2026
