# Playbook: Admin MFA Lockout Reset

**Version**: 1.0.0
**Last Updated**: 2026-01-25
**Tested On**: api-service v0.11.11

---

## Overview

This playbook covers resetting MFA lockout for admin users who have been locked out due to too many failed MFA attempts. The lockout mechanism triggers after 5 failed attempts and lasts 15 minutes.

## Prerequisites

- Access to kubectl with api-service-local namespace permissions
- Admin user email address
- Reason for reset (for audit purposes)

---

## When to Use

Use this playbook when:
- Admin user reports "Account locked" error message
- Admin user has exceeded 5 failed MFA attempts
- Admin user cannot wait for the 15-minute lockout to expire
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

## Related Documentation

- [Admin Account Setup](admin-account-setup.md) - Initial admin setup
- [Admin Session Management](admin-session-management.md) - Session operations
- Feature Tests: `/home/pwner/Git/docs/feature-tests/46-platform-admin-panel.md`

---

## Checklist

- [ ] Verified user is actually locked out
- [ ] Reset lockout counter in database
- [ ] Verified reset was successful
- [ ] Notified user they can retry
- [ ] Documented reason for reset (audit trail)
