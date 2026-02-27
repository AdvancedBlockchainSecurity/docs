# Playbook: Admin MFA Recovery & Lockout Reset

**Version**: 2.0.0
**Last Updated**: 2026-02-27
**Tested On**: api-service v0.29.37, admin-portal v0.7.4

---

## Overview

This playbook covers all admin MFA issues: lockout resets, MFA re-setup after encryption key changes, and recovery of corrupted MFA secrets. The MFA lockout mechanism triggers after 5 failed attempts and lasts 15 minutes.

## Prerequisites

- Access to kubectl with api-service-local and postgresql-local namespace permissions
- Admin user email address
- Reason for reset (for audit purposes)

---

## When to Use

Use this playbook when:
- Admin user reports "Account locked" error message
- Admin user has exceeded 5 failed MFA attempts
- Admin user cannot wait for the 15-minute lockout to expire
- Admin user sees "MFA not set up. Call /admin/auth/mfa/setup first."
- Admin user sees "Invalid MFA code" on every attempt (possible encryption key mismatch)
- After an encryption key rotation that invalidated stored MFA secrets
- Admin MFA secret is stored unencrypted (pre-encryption migration)
- Testing MFA lockout functionality

---

## Step 1: Verify Lockout Status

Check if the user is actually locked out:

```bash
kubectl exec -n api-service-local deployment/api-service -- python -c "
import asyncio
from src.infrastructure.database.connection import AsyncSessionLocal
from sqlalchemy import text
from datetime import datetime, timezone

async def check_lockout():
    async with AsyncSessionLocal() as session:
        result = await session.execute(text('''
            SELECT email, mfa_failed_attempts, mfa_locked_until, admin_role
            FROM users
            WHERE email = 'ADMIN_EMAIL@example.com'
        '''))
        row = result.fetchone()
        if row:
            print(f'Email: {row[0]}')
            print(f'Admin Role: {row[3]}')
            print(f'Failed Attempts: {row[1]}')
            print(f'Locked Until: {row[2]}')
            if row[2]:
                now = datetime.now(timezone.utc)
                if row[2] > now:
                    remaining = (row[2] - now).total_seconds() / 60
                    print(f'STATUS: LOCKED ({remaining:.1f} minutes remaining)')
                else:
                    print('STATUS: Lockout expired (can reset counter)')
            else:
                print('STATUS: Not locked')
        else:
            print('User not found')

asyncio.run(check_lockout())
" 2>&1 | grep -v "INFO:"
```

---

## Step 2: Reset Lockout

Reset the lockout counter and unlock the account:

```bash
kubectl exec -n api-service-local deployment/api-service -- python -c "
import asyncio
from src.infrastructure.database.connection import AsyncSessionLocal
from sqlalchemy import text

async def reset_lockout():
    async with AsyncSessionLocal() as session:
        result = await session.execute(text('''
            UPDATE users
            SET mfa_failed_attempts = 0,
                mfa_locked_until = NULL,
                mfa_last_failed_at = NULL
            WHERE email = 'ADMIN_EMAIL@example.com'
            RETURNING email, admin_role
        '''))
        row = result.fetchone()
        await session.commit()
        if row:
            print(f'SUCCESS: MFA lockout reset for {row[0]} ({row[1]})')
        else:
            print('ERROR: User not found')

asyncio.run(reset_lockout())
" 2>&1 | grep -E "^(SUCCESS|ERROR)"
```

---

## Step 3: Verify Reset

Confirm the lockout has been cleared:

```bash
kubectl exec -n api-service-local deployment/api-service -- python -c "
import asyncio
from src.infrastructure.database.connection import AsyncSessionLocal
from sqlalchemy import text

async def verify():
    async with AsyncSessionLocal() as session:
        result = await session.execute(text('''
            SELECT mfa_failed_attempts, mfa_locked_until
            FROM users WHERE email = 'ADMIN_EMAIL@example.com'
        '''))
        row = result.fetchone()
        if row:
            if row[0] == 0 and row[1] is None:
                print('VERIFIED: Lockout successfully reset')
            else:
                print(f'WARNING: Failed attempts={row[0]}, Locked until={row[1]}')

asyncio.run(verify())
" 2>&1 | grep -E "^(VERIFIED|WARNING)"
```

---

## Step 4: Notify User

Inform the admin user they can now attempt MFA verification again.

**Important**: Remind them that:
- TOTP codes are only valid for 30 seconds
- They have 3 attempts per minute (rate limited)
- 5 consecutive failures will trigger another lockout

---

## Quick One-Liner

For experienced operators, here's the reset in a single command:

```bash
# Replace ADMIN_EMAIL with the actual email
kubectl exec -n api-service-local deployment/api-service -- python -c "
import asyncio
from src.infrastructure.database.connection import AsyncSessionLocal
from sqlalchemy import text
async def reset():
    async with AsyncSessionLocal() as s:
        await s.execute(text(\"UPDATE users SET mfa_failed_attempts=0, mfa_locked_until=NULL WHERE email='ADMIN_EMAIL@example.com'\"))
        await s.commit()
        print('Lockout reset complete')
asyncio.run(reset())
" 2>&1 | grep -v "INFO:"
```

---

## Troubleshooting

### "User not found"

The email address may be incorrect. List all admin users:

```bash
kubectl exec -n api-service-local deployment/api-service -- \
  python -m src.cli.admin list 2>&1 | grep -v "INFO:"
```

### User still locked after reset

1. Verify the database update was committed
2. Check if there's a cached session blocking access
3. Have user clear browser cookies and try again

### Rate limit still blocking (429)

The rate limit is IP-based and separate from the lockout. Wait 60 seconds for the rate limit window to reset.

---

## Audit Logging

Lockout resets are **not** automatically logged to admin_audit_logs. For compliance, manually document:

- Who requested the reset
- When the reset was performed
- Why the reset was needed

Consider creating an audit entry:

```bash
kubectl exec -n api-service-local deployment/api-service -- python -c "
import asyncio
from src.infrastructure.database.connection import AsyncSessionLocal
from sqlalchemy import text
import uuid
from datetime import datetime, timezone

async def log_reset():
    async with AsyncSessionLocal() as session:
        await session.execute(text('''
            INSERT INTO admin_audit_logs
            (id, admin_user_id, action, target_type, target_id, details, ip_address, created_at)
            VALUES (
                :id,
                (SELECT id FROM users WHERE email = 'OPERATOR_EMAIL'),
                'mfa_lockout_reset',
                'user',
                (SELECT id FROM users WHERE email = 'ADMIN_EMAIL'),
                '{\"reason\": \"Manual reset requested\", \"method\": \"cli\"}',
                'cli',
                :now
            )
        '''), {'id': str(uuid.uuid4()), 'now': datetime.now(timezone.utc)})
        await session.commit()
        print('Audit log entry created')

asyncio.run(log_reset())
" 2>&1 | grep -v "INFO:"
```

---

## Full MFA Reset (Encryption Key Change / Corrupted Secret)

When an encryption key is rotated or an MFA secret was stored unencrypted (pre-v0.29.37), the stored `admin_mfa_secret` cannot be decrypted. Symptoms:

- Every MFA code attempt returns "Invalid MFA code" (decryption fails silently)
- `/mfa/setup` blocked with "MFA is already enabled. Contact super_admin to reset."

### Diagnose the Issue

```bash
# Check MFA state for all admin users
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "
SELECT email, admin_mfa_enabled,
       admin_mfa_secret IS NOT NULL as has_secret,
       LENGTH(admin_mfa_secret) as secret_len
FROM users WHERE admin_role IS NOT NULL;"
```

**Indicators of corrupted/incompatible secret:**
- `secret_len` < 100: Secret is likely **unencrypted** (raw TOTP base32, e.g., `JBSWY3DPEHPK3PXP`)
- `secret_len` >= 100 but starts with `gAAAAA`: Fernet-encrypted, may be encrypted with old key

### Verify Decryption Works

```bash
kubectl exec -n api-service-local deployment/api-service -- python3 -c "
from cryptography.fernet import Fernet
import os
key = os.environ['INTEGRATION_ENCRYPTION_KEY']
f = Fernet(key.encode())
secret = 'PASTE_ADMIN_MFA_SECRET_HERE'
try:
    result = f.decrypt(secret.encode())
    print(f'OK: Decrypts to {len(result)} bytes')
except Exception as e:
    print(f'FAILED: {e} — secret must be reset')
"
```

### Reset MFA for Affected Account

```bash
# Reset MFA so user can re-setup with current encryption key
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "
UPDATE users
SET admin_mfa_enabled = false,
    admin_mfa_secret = NULL,
    mfa_failed_attempts = 0,
    mfa_locked_until = NULL
WHERE email = 'ADMIN_EMAIL@example.com';"
```

After reset, the admin user must:
1. Login to admin portal (Supabase auth)
2. On the MFA verify page, click **"Set up new authenticator"**
3. Scan the QR code with their authenticator app
4. Enter the 6-digit code to complete setup

### Bulk Reset After Key Rotation

If the encryption key was changed and ALL admin MFA secrets are invalid:

```bash
kubectl exec -n postgresql-local postgresql-0 -- psql -U blocksecops -d solidity_security -c "
UPDATE users
SET admin_mfa_enabled = false,
    admin_mfa_secret = NULL,
    mfa_failed_attempts = 0,
    mfa_locked_until = NULL
WHERE admin_role IS NOT NULL AND admin_mfa_secret IS NOT NULL;
SELECT email, admin_role FROM users WHERE admin_role IS NOT NULL;"
```

**All admin users must re-setup MFA after this operation.**

---

## Admin Portal Stale Bundle Issues

If the admin portal serves an old JS bundle, it may call non-existent API endpoints (e.g., `POST /admin/auth/login` → 404). This happens when the Docker image was built from a stale `dist/` directory.

### Diagnose

```bash
# Check API logs for 404 on login
kubectl logs -n api-service-local deployment/api-service --tail=100 | grep "admin/auth/login"

# Verify no stale /login call in deployed bundle
kubectl exec -n admin-portal-local deployment/admin-portal -- \
  grep -c 'admin/auth/login' /app/dist/assets/index-*.js
# Expected: 0 (no matches)
```

### Fix: Rebuild Admin Portal

```bash
cd /home/pwner/Git/blocksecops-admin-portal
VERSION=$(grep '"version"' package.json | head -1 | cut -d'"' -f4)
REGISTRY="harbor.0xapogee.local"
SUPABASE_URL=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_url}')
SUPABASE_KEY=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_anon_key}')

# Bump version (Harbor immutable tags)
# Update package.json and k8s/overlays/local/kustomization.yaml newTag

docker build \
  --build-arg VITE_ADMIN_SUPABASE_URL="${SUPABASE_URL}" \
  --build-arg VITE_ADMIN_SUPABASE_ANON_KEY="${SUPABASE_KEY}" \
  --build-arg VITE_API_BASE_URL=/api/v1 \
  --build-arg VITE_ENVIRONMENT=local \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t ${REGISTRY}/blocksecops/admin-portal:${VERSION} .

docker push ${REGISTRY}/blocksecops/admin-portal:${VERSION}
kubectl apply -k k8s/overlays/local/
```

---

## Admin MFA Auth Flow Reference

```
Browser                    Admin Portal (React)           API Service
  │                              │                             │
  │  1. Enter email/password     │                             │
  │─────────────────────────────>│                             │
  │                              │                             │
  │                              │  2. Supabase signIn()       │
  │                              │  (direct SDK call, no API)  │
  │                              │                             │
  │  3. Redirect to /mfa-verify  │                             │
  │<─────────────────────────────│                             │
  │                              │                             │
  │  4a. Enter TOTP code         │  POST /admin/auth/mfa/verify│
  │─────────────────────────────>│────────────────────────────>│
  │                              │         (Bearer JWT)        │
  │                              │                             │
  │  4b. OR click "Set up new    │  POST /admin/auth/mfa/setup │
  │      authenticator"          │────────────────────────────>│
  │                              │    Returns QR + secret      │
  │  4c. Scan QR, enter code     │  POST /admin/auth/mfa/verify│
  │─────────────────────────────>│────────────────────────────>│
  │                              │                             │
  │  5. Session cookie set       │  Set-Cookie: admin_session  │
  │<─────────────────────────────│<────────────────────────────│
```

---

## Incident History

### February 2026: MFA broken after encryption key fix

**Root cause:** Two issues compounded:
1. `admin@blocksecops.local` had a raw unencrypted TOTP secret (`JBSWY3DPEHPK3PXP`) stored before encryption was implemented. `decrypt_mfa_secret()` failed silently on plaintext.
2. Admin portal was serving a stale JS bundle that called `POST /admin/auth/login` (404) — an endpoint that was removed when auth moved to Supabase-only.

**Fix:** Reset MFA for affected account (DB update), rebuild admin portal from current source (v0.7.4).

**Prevention:**
- Always rebuild admin portal after auth flow changes
- Encryption key rotation playbook must include MFA secret re-encryption or reset
- Startup validation (v0.29.37+) rejects invalid encryption keys in production

---

## Related Documentation

- [Admin Account Setup](admin-account-setup.md) - Initial admin setup
- [Admin Session Management](admin-session-management.md) - Session operations
- [Admin Portal Deployment](admin-portal-deployment.md) - Build and deploy admin portal
- [Security Configuration](security-configuration.md) - Encryption key management
- [Encryption Standards](../standards/encryption-standards.md) - Fernet key requirements
- Feature Tests: `/home/pwner/Git/docs/feature-tests/46-platform-admin-panel.md`

---

## Checklist

- [ ] Verified user is actually locked out (or MFA secret is corrupted)
- [ ] Reset lockout counter in database
- [ ] If encryption issue: reset `admin_mfa_secret` and `admin_mfa_enabled`
- [ ] Verified reset was successful
- [ ] Notified user they can retry (or re-setup MFA)
- [ ] If stale bundle: rebuilt and redeployed admin portal
- [ ] Documented reason for reset (audit trail)
