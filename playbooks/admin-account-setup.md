# Playbook: Platform Admin Account Setup

**Version**: 1.0.0
**Last Updated**: 2026-01-25
**Tested On**: api-service v0.11.11

---

## Overview

This playbook covers the complete process for setting up a Platform Admin account with MFA authentication on the BlockSecOps platform.

## Prerequisites

- Running Kubernetes cluster with api-service deployed
- Access to the server via `https://app.blocksecops.local` (server) or `http://127.0.0.1:3000` (minikube)
- An existing Supabase user account (the user must register first)
- Access to kubectl with api-service-local namespace permissions

---

## Step 1: Verify Existing User

Admin privileges are granted to existing users. The user must have registered via Supabase first.

```bash
# Check if user exists in database
kubectl exec -n api-service-local deployment/api-service -- python -c "
import asyncio
from src.infrastructure.database.connection import AsyncSessionLocal
from sqlalchemy import text

async def check_user():
    async with AsyncSessionLocal() as session:
        result = await session.execute(text('''
            SELECT id, email, supabase_user_id, admin_role
            FROM users WHERE email = 'YOUR_EMAIL@example.com'
        '''))
        row = result.fetchone()
        if row:
            print(f'User found: {row[1]}')
            print(f'Supabase ID: {row[2]}')
            print(f'Admin role: {row[3]}')
        else:
            print('User NOT found - must register via Supabase first')

asyncio.run(check_user())
" 2>&1 | grep -v "INFO:"
```

### If User Doesn't Exist

The user must register through the standard Supabase authentication flow (dashboard login page) before they can be granted admin privileges.

---

## Step 2: Grant Admin Privileges via CLI

```bash
kubectl exec -n api-service-local deployment/api-service -- \
  python -m src.cli.admin create-admin \
  --email YOUR_EMAIL@example.com \
  --role super_admin
```

### Available Roles

| Role | Permissions |
|------|-------------|
| `super_admin` | Full access, can manage other admins |
| `platform_admin` | User management, emergency actions |
| `support_admin` | Read-only user data, basic support |

### Expected Output

```
============================================================
BlockSecOps Platform Admin Management
============================================================

[SUCCESS] Admin account created for YOUR_EMAIL@example.com

============================================================
MFA SETUP REQUIRED
============================================================

TOTP Secret (for manual entry):
  ABCDEFGHIJKLMNOPQRSTUVWXYZ234567

Or use this URI with an authenticator app:
  otpauth://totp/BlockSecOps%20Admin:YOUR_EMAIL@example.com?secret=...&issuer=BlockSecOps%20Admin

IMPORTANT: Save this secret securely. It will not be shown again.
============================================================
```

**SAVE THE TOTP SECRET** - You'll need it for MFA verification.

---

## Step 3: Link Supabase User ID (If Needed)

If authentication fails with "Not authenticated", the Supabase user ID may not be linked:

```bash
# Get the Supabase user ID from a valid JWT token
# The 'sub' claim in the JWT contains the Supabase user ID

# Then link it to the local database user:
kubectl exec -n api-service-local deployment/api-service -- python -c "
import asyncio
from src.infrastructure.database.connection import AsyncSessionLocal
from sqlalchemy import text

async def link_supabase():
    async with AsyncSessionLocal() as session:
        await session.execute(text('''
            UPDATE users
            SET supabase_user_id = 'SUPABASE_USER_ID_FROM_JWT'
            WHERE email = 'YOUR_EMAIL@example.com'
        '''))
        await session.commit()
        print('Supabase ID linked successfully')

asyncio.run(link_supabase())
" 2>&1 | grep -v "INFO:"
```

---

## Step 4: Configure MFA in Authenticator App

1. Open your authenticator app (Google Authenticator, Authy, 1Password, etc.)
2. Add a new account using either:
   - **Scan QR Code**: Use the QR code from the `/admin/auth/mfa/setup` endpoint
   - **Manual Entry**: Enter the TOTP secret from Step 2

---

## Step 5: Verify MFA and Create Session

### Get Authentication Token

```bash
# Using the token script
TOKEN=$(/home/pwner/Git/docs/scripts/get_token_fixed.sh)
```

### Setup MFA (if not done via CLI)

```bash
curl -sk -X POST -H "Authorization: Bearer ${TOKEN}" \
  "https://app.blocksecops.local/api/v1/admin/auth/mfa/setup" | jq '.'
```

### Verify MFA Code

```bash
# Replace 123456 with the current code from your authenticator app
TOTP_CODE="123456"

curl -sk -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"code\": \"${TOTP_CODE}\"}" \
  "https://app.blocksecops.local/api/v1/admin/auth/mfa/verify" | jq '.'
```

### Expected Response

```json
{
  "session_token": "random-session-token-string",
  "expires_at": "2026-01-25T04:30:00Z"
}
```

**Save the `session_token`** - You'll need it for all admin API calls.

---

## Step 6: Verify Admin Session

```bash
ADMIN_SESSION="your-session-token-from-step-5"

curl -sk -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  "https://app.blocksecops.local/api/v1/admin/auth/session" | jq '.'
```

### Expected Response

```json
{
  "is_valid": true,
  "admin_role": "super_admin",
  "mfa_verified": true,
  "expires_at": "2026-01-25T04:30:00Z",
  "ip_address": "10.244.0.1"
}
```

---

## Step 7: Test Admin Endpoints

### List Users

```bash
curl -sk -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  "https://app.blocksecops.local/api/v1/admin/users?page=1&page_size=5" | jq '.'
```

### Get Platform Stats

```bash
curl -sk -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  "https://app.blocksecops.local/api/v1/admin/system/stats" | jq '.'
```

---

## Automated Testing Script

For testing purposes, you can generate TOTP codes programmatically:

```bash
#!/bin/bash
# admin-mfa-test.sh

TOKEN=$(/home/pwner/Git/docs/scripts/get_token_fixed.sh)
MFA_SECRET="YOUR_MFA_SECRET"

# Generate TOTP code
TOTP_CODE=$(kubectl exec -n api-service-local deployment/api-service -- \
  python -c "import pyotp; print(pyotp.TOTP('${MFA_SECRET}').now())" 2>/dev/null)

echo "TOTP Code: $TOTP_CODE"

# Verify and get session
RESPONSE=$(curl -sk -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"code\": \"${TOTP_CODE}\"}" \
  "https://app.blocksecops.local/api/v1/admin/auth/mfa/verify")

ADMIN_SESSION=$(echo "$RESPONSE" | jq -r '.session_token')
echo "Admin Session: ${ADMIN_SESSION:0:30}..."

# Test session
curl -sk -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  "https://app.blocksecops.local/api/v1/admin/auth/session" | jq '.'
```

---

## Troubleshooting

### "Not authenticated" Error

1. Token may be expired - regenerate with `get_token_fixed.sh`
2. Supabase user ID not linked - see Step 3
3. User doesn't exist in local database - user must register first

### "Invalid MFA code" Error

1. Time sync issue - ensure server and authenticator have same time
2. Wrong secret - verify the TOTP secret matches
3. Code expired - TOTP codes are valid for 30 seconds

### "Invalid or expired admin session" Error

1. Session expired (30 min inactivity, 8 hour max)
2. IP address changed - session is IP-bound
3. Session was revoked via logout

### Session IP Mismatch

Admin sessions are bound to the IP address that created them. If accessing through different network paths (e.g., Traefik vs direct pod), the IP may differ.

---

## Security Notes

- Admin sessions expire after 30 minutes of inactivity
- Maximum session lifetime is 8 hours
- Sessions are bound to the originating IP address
- MFA codes are rate-limited (3 attempts/minute)
- 5 failed MFA attempts result in 15-minute lockout
- Session tokens are stored in httpOnly cookies (XSS protection)

---

## CLI Commands Reference

```bash
# Create admin
python -m src.cli.admin create-admin --email EMAIL --role ROLE

# List admins
python -m src.cli.admin list

# Revoke admin
python -m src.cli.admin revoke --email EMAIL --reason "Reason"

# Reset MFA
python -m src.cli.admin reset-mfa --email EMAIL
```

---

## Related Documentation

- Feature Tests: `/home/pwner/Git/docs/feature-tests/46-platform-admin-panel.md`
- API Documentation: `/api/v1/docs` (OpenAPI)
- Database Schema: `/home/pwner/Git/docs/database/SCHEMA.md`
