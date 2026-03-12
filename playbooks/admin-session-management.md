# Playbook: Admin Session Management

**Version**: 1.1.0
**Last Updated**: 2026-02-19
**Tested On**: api-service v0.28.54

---

## Overview

This playbook covers managing admin sessions including viewing active sessions, revoking sessions, and troubleshooting session issues.

## Prerequisites

- Access to kubectl with api-service-local namespace permissions
- Valid admin session token (for API-based operations)
- OR database access (for CLI-based operations)

---

## Session Properties

Admin sessions have the following characteristics:

| Property | Value | Description |
|----------|-------|-------------|
| Inactivity Timeout | 30 minutes | Session expires after 30 min idle |
| Maximum Lifetime | 8 hours | Session expires regardless of activity |
| IP Binding | Enabled | Session bound to originating IP |
| Cookie | httpOnly, SameSite=strict | XSS and CSRF protection |

---

## View Active Admin Sessions

### Via Database (Recommended for Operations)

```bash
kubectl exec -n api-service-local deployment/api-service -- python -c "
import asyncio
from src.infrastructure.database.connection import AsyncSessionLocal
from sqlalchemy import text
from datetime import datetime, timezone

async def list_sessions():
    async with AsyncSessionLocal() as session:
        result = await session.execute(text('''
            SELECT
                s.id,
                u.email,
                u.admin_role,
                s.ip_address,
                s.mfa_verified_at,
                s.last_activity_at,
                s.expires_at,
                s.is_active
            FROM admin_sessions s
            JOIN users u ON s.user_id = u.id
            WHERE s.is_active = true
            ORDER BY s.last_activity_at DESC
        '''))
        rows = result.fetchall()
        print(f'Active Admin Sessions: {len(rows)}')
        print('-' * 80)
        for row in rows:
            now = datetime.now(timezone.utc)
            expires = row[6].replace(tzinfo=timezone.utc) if row[6].tzinfo is None else row[6]
            remaining = (expires - now).total_seconds() / 60
            print(f'Email: {row[1]}')
            print(f'  Role: {row[2]}')
            print(f'  IP: {row[3]}')
            print(f'  Last Activity: {row[5]}')
            print(f'  Expires In: {remaining:.0f} minutes')
            print()

asyncio.run(list_sessions())
" 2>&1 | grep -v "INFO:"
```

### Via API (Requires Valid Session)

```bash
TOKEN=$(cat /tmp/auth_token)
ADMIN_SESSION=$(cat /tmp/admin_session_token)

curl -sk -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  "https://app.0xapogee.com/api/v1/admin/auth/session" | jq '.'
```

---

## Revoke a Specific Admin Session

### Revoke by Session ID

```bash
SESSION_ID="session-uuid-here"

kubectl exec -n api-service-local deployment/api-service -- python -c "
import asyncio
from src.infrastructure.database.connection import AsyncSessionLocal
from sqlalchemy import text

async def revoke_session():
    async with AsyncSessionLocal() as session:
        result = await session.execute(text('''
            UPDATE admin_sessions
            SET is_active = false
            WHERE id = '${SESSION_ID}'
            RETURNING id, user_id
        '''))
        row = result.fetchone()
        await session.commit()
        if row:
            print(f'Session {row[0]} revoked')
        else:
            print('Session not found')

asyncio.run(revoke_session())
" 2>&1 | grep -v "INFO:"
```

### Revoke All Sessions for a User

```bash
ADMIN_EMAIL="admin@example.com"

kubectl exec -n api-service-local deployment/api-service -- python -c "
import asyncio
from src.infrastructure.database.connection import AsyncSessionLocal
from sqlalchemy import text

async def revoke_all():
    async with AsyncSessionLocal() as session:
        result = await session.execute(text('''
            UPDATE admin_sessions
            SET is_active = false
            WHERE user_id = (SELECT id FROM users WHERE email = '${ADMIN_EMAIL}')
            AND is_active = true
        '''))
        await session.commit()
        print(f'Revoked {result.rowcount} session(s) for ${ADMIN_EMAIL}')

asyncio.run(revoke_all())
" 2>&1 | grep -v "INFO:"
```

---

## Revoke via API (Emergency Endpoint)

For super_admin users, use the emergency endpoint:

```bash
TOKEN=$(cat /tmp/auth_token)
ADMIN_SESSION=$(cat /tmp/admin_session_token)
USER_ID="target-user-uuid"

curl -sk -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  -H "Content-Type: application/json" \
  "https://app.0xapogee.com/api/v1/admin/emergency/revoke-sessions/${USER_ID}" \
  -d '{"reason": "Security incident - revoking all sessions for investigation"}' | jq '.'
```

**Note**: Reason must be at least 20 characters.

---

## Clean Up Expired Sessions

Remove expired sessions from the database:

```bash
kubectl exec -n api-service-local deployment/api-service -- python -c "
import asyncio
from src.infrastructure.database.connection import AsyncSessionLocal
from sqlalchemy import text
from datetime import datetime, timezone

async def cleanup():
    async with AsyncSessionLocal() as session:
        now = datetime.now(timezone.utc)
        result = await session.execute(text('''
            UPDATE admin_sessions
            SET is_active = false
            WHERE is_active = true
            AND expires_at < :now
        '''), {'now': now})
        await session.commit()
        print(f'Deactivated {result.rowcount} expired session(s)')

asyncio.run(cleanup())
" 2>&1 | grep -v "INFO:"
```

---

## Troubleshooting

### "Invalid or expired admin session"

1. **Session expired**: Get a new session via MFA verification
2. **IP changed**: Session is bound to original IP; re-authenticate
3. **Session revoked**: An admin may have revoked the session

### "Could not validate credentials"

1. **JWT expired**: Get a fresh Supabase token
2. **User not an admin**: Verify admin role is set
3. **Supabase user ID not linked**: Link the Supabase ID to local user

### Session shows valid but API returns 403

1. Check IP address matches session's IP
2. Verify the X-Admin-Session header is being sent
3. Check if another admin revoked access

---

## Session Security Notes

1. **Never share session tokens** - Tokens are bound to IP and cannot be transferred
2. **Logout when done** - Don't let sessions expire naturally
3. **Monitor active sessions** - Regularly check for unauthorized sessions
4. **IP changes** - VPN/network changes will invalidate sessions

---

## Emergency: Revoke ALL Admin Sessions

In case of security breach, revoke all active admin sessions:

```bash
kubectl exec -n api-service-local deployment/api-service -- python -c "
import asyncio
from src.infrastructure.database.connection import AsyncSessionLocal
from sqlalchemy import text

async def revoke_all_admin_sessions():
    async with AsyncSessionLocal() as session:
        result = await session.execute(text('''
            UPDATE admin_sessions
            SET is_active = false
            WHERE is_active = true
        '''))
        await session.commit()
        print(f'EMERGENCY: Revoked ALL {result.rowcount} active admin sessions')

asyncio.run(revoke_all_admin_sessions())
" 2>&1 | grep -v "INFO:"
```

**Warning**: This will log out all admins including yourself!

---

## Related Documentation

- [Admin Account Setup](admin-account-setup.md) - Initial admin setup
- [Admin MFA Lockout Reset](admin-mfa-lockout-reset.md) - Reset MFA lockout
- Feature Tests: `/home/pwner/Git/docs/feature-tests/46-platform-admin-panel.md`

---

## Checklist

- [ ] Identified the session(s) to manage
- [ ] Used appropriate method (API vs CLI)
- [ ] Verified session status after action
- [ ] Notified affected user(s) if needed
- [ ] Documented reason for action (audit trail)
