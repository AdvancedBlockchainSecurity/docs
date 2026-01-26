# Playbook: Admin Emergency Operations

**Version**: 1.0.0
**Last Updated**: 2026-01-25
**Tested On**: api-service v0.11.11

---

## Overview

This playbook covers emergency administrative operations including disabling compromised accounts, revoking admin access, and responding to security incidents.

**Warning**: These operations have significant impact. Use with caution and document all actions.

## Prerequisites

- Super admin access (for API operations)
- OR kubectl access (for CLI operations)
- Documented reason for emergency action

---

## Emergency Actions Matrix

| Action | API Endpoint | CLI Command | Who Can Perform |
|--------|--------------|-------------|-----------------|
| Disable User | POST `/admin/emergency/disable-user/{id}` | Database update | super_admin |
| Revoke Sessions | POST `/admin/emergency/revoke-sessions/{id}` | Database update | super_admin, platform_admin |
| Revoke Admin | POST `/admin/emergency/revoke-admin/{id}` | CLI | super_admin only |

---

## Emergency Disable User

Use when a user account is compromised or violating terms.

### Via API (Preferred - Creates Audit Log)

```bash
TOKEN=$(cat /tmp/auth_token)
ADMIN_SESSION=$(cat /tmp/admin_session_token)
USER_ID="target-user-uuid"

curl -sk -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  -H "Content-Type: application/json" \
  "https://app.blocksecops.local/api/v1/admin/emergency/disable-user/${USER_ID}" \
  -d '{"reason": "Security incident - account potentially compromised, disabling pending investigation"}' | jq '.'
```

**Response**:
```json
{
  "success": true,
  "user_id": "...",
  "sessions_revoked": 2,
  "message": "User disabled and all sessions revoked"
}
```

### Via Database (When API Access Unavailable)

```bash
USER_EMAIL="compromised@example.com"

kubectl exec -n api-service-local deployment/api-service -- python -c "
import asyncio
from src.infrastructure.database.connection import AsyncSessionLocal
from sqlalchemy import text

async def emergency_disable():
    async with AsyncSessionLocal() as session:
        # Disable user account
        result = await session.execute(text('''
            UPDATE users
            SET is_active = false
            WHERE email = '${USER_EMAIL}'
            RETURNING id, email
        '''))
        user = result.fetchone()

        if user:
            # Revoke all sessions
            await session.execute(text('''
                UPDATE admin_sessions
                SET is_active = false
                WHERE user_id = :user_id
            '''), {'user_id': user[0]})

            await session.commit()
            print(f'EMERGENCY: User {user[1]} disabled and all sessions revoked')
        else:
            print('ERROR: User not found')

asyncio.run(emergency_disable())
" 2>&1 | grep -E "^(EMERGENCY|ERROR)"
```

---

## Revoke Admin Access

Remove admin privileges from a user while keeping their regular account active.

### Via CLI (Recommended)

```bash
kubectl exec -n api-service-local deployment/api-service -- sh -c \
  'echo "y" | python -m src.cli.admin revoke --email admin@example.com --reason "Security review - temporary revocation pending audit"'
```

### Via API (Super Admin Only)

```bash
TOKEN=$(cat /tmp/auth_token)
ADMIN_SESSION=$(cat /tmp/admin_session_token)
USER_ID="admin-user-uuid"

curl -sk -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  -H "Content-Type: application/json" \
  "https://app.blocksecops.local/api/v1/admin/emergency/revoke-admin/${USER_ID}" \
  -d '{"reason": "Security review - administrative access revoked pending investigation"}' | jq '.'
```

### Via Database (Emergency Only)

```bash
ADMIN_EMAIL="admin@example.com"

kubectl exec -n api-service-local deployment/api-service -- python -c "
import asyncio
from src.infrastructure.database.connection import AsyncSessionLocal
from sqlalchemy import text

async def revoke_admin():
    async with AsyncSessionLocal() as session:
        # Remove admin privileges
        result = await session.execute(text('''
            UPDATE users
            SET admin_role = NULL,
                admin_mfa_secret = NULL,
                is_superuser = false
            WHERE email = '${ADMIN_EMAIL}'
            RETURNING id, email
        '''))
        user = result.fetchone()

        if user:
            # Revoke all admin sessions
            await session.execute(text('''
                UPDATE admin_sessions
                SET is_active = false
                WHERE user_id = :user_id
            '''), {'user_id': user[0]})

            await session.commit()
            print(f'EMERGENCY: Admin access revoked for {user[1]}')
        else:
            print('ERROR: User not found')

asyncio.run(revoke_admin())
" 2>&1 | grep -E "^(EMERGENCY|ERROR)"
```

---

## Mass Session Revocation

In case of widespread security incident, revoke all user sessions:

### Revoke All Admin Sessions

```bash
kubectl exec -n api-service-local deployment/api-service -- python -c "
import asyncio
from src.infrastructure.database.connection import AsyncSessionLocal
from sqlalchemy import text

async def revoke_all():
    async with AsyncSessionLocal() as session:
        result = await session.execute(text('''
            UPDATE admin_sessions SET is_active = false WHERE is_active = true
        '''))
        await session.commit()
        print(f'EMERGENCY: Revoked {result.rowcount} admin sessions')

asyncio.run(revoke_all())
" 2>&1 | grep "EMERGENCY"
```

---

## Security Incident Response Checklist

When responding to a security incident:

### Immediate Actions (First 15 minutes)

- [ ] **Identify affected accounts** - Which users/admins are compromised?
- [ ] **Revoke sessions** - Invalidate all sessions for affected accounts
- [ ] **Disable accounts** - Prevent further access
- [ ] **Preserve evidence** - Don't delete audit logs or sessions yet

### Short-term Actions (First hour)

- [ ] **Review audit logs** - What actions were taken?
- [ ] **Check for lateral movement** - Were other accounts accessed?
- [ ] **Notify stakeholders** - Inform security team and management
- [ ] **Document timeline** - Record all actions and findings

### Recovery Actions

- [ ] **Reset MFA secrets** - Generate new TOTP secrets
- [ ] **Review permissions** - Verify admin roles are appropriate
- [ ] **Re-enable accounts** - After investigation and remediation
- [ ] **Post-incident review** - Document lessons learned

---

## View Audit Logs

Check what actions were taken:

```bash
TOKEN=$(cat /tmp/auth_token)
ADMIN_SESSION=$(cat /tmp/admin_session_token)

# Get recent admin actions
curl -sk -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Admin-Session: ${ADMIN_SESSION}" \
  "https://app.blocksecops.local/api/v1/admin/audit/admin-actions?page=1&page_size=20" | jq '.entries[] | {action, admin_email: .admin_user.email, target_type, created_at}'
```

### Via Database

```bash
kubectl exec -n api-service-local deployment/api-service -- python -c "
import asyncio
from src.infrastructure.database.connection import AsyncSessionLocal
from sqlalchemy import text

async def audit_log():
    async with AsyncSessionLocal() as session:
        result = await session.execute(text('''
            SELECT
                l.action,
                u.email as admin_email,
                l.target_type,
                l.details,
                l.ip_address,
                l.created_at
            FROM admin_audit_logs l
            JOIN users u ON l.admin_user_id = u.id
            ORDER BY l.created_at DESC
            LIMIT 20
        '''))
        rows = result.fetchall()
        print('Recent Admin Actions:')
        print('-' * 80)
        for row in rows:
            print(f'{row[5]} | {row[0]} | {row[1]} | {row[2]} | {row[4]}')

asyncio.run(audit_log())
" 2>&1 | grep -v "INFO:"
```

---

## Re-enable Disabled User

After investigation, re-enable a user account:

```bash
USER_EMAIL="user@example.com"

kubectl exec -n api-service-local deployment/api-service -- python -c "
import asyncio
from src.infrastructure.database.connection import AsyncSessionLocal
from sqlalchemy import text

async def enable_user():
    async with AsyncSessionLocal() as session:
        await session.execute(text('''
            UPDATE users SET is_active = true WHERE email = '${USER_EMAIL}'
        '''))
        await session.commit()
        print(f'User {USER_EMAIL} re-enabled')

asyncio.run(enable_user())
" 2>&1 | grep -v "INFO:"
```

---

## Restore Admin Access

Re-grant admin privileges after investigation:

```bash
kubectl exec -n api-service-local deployment/api-service -- \
  python -m src.cli.admin create-admin --email admin@example.com --role platform_admin
```

**Note**: This generates a new MFA secret. The user must set up MFA again.

---

## Related Documentation

- [Admin Account Setup](admin-account-setup.md) - Initial admin setup
- [Admin MFA Lockout Reset](admin-mfa-lockout-reset.md) - Reset MFA lockout
- [Admin Session Management](admin-session-management.md) - Session operations
- Feature Tests: `/home/pwner/Git/docs/feature-tests/46-platform-admin-panel.md`

---

## Emergency Contact

For critical security incidents:
- Security Team: [internal contact]
- On-call Admin: [internal contact]

---

## Checklist

### Pre-Action
- [ ] Confirmed identity of requester
- [ ] Verified the emergency is legitimate
- [ ] Documented reason for action

### During Action
- [ ] Executed appropriate emergency action
- [ ] Verified action completed successfully
- [ ] Preserved audit logs

### Post-Action
- [ ] Notified affected users
- [ ] Updated incident documentation
- [ ] Scheduled post-incident review
