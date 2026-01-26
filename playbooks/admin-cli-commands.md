# Playbook: Admin CLI Commands

**Version**: 1.0.0
**Last Updated**: 2026-01-25
**Tested On**: api-service v0.13.2

---

## Overview

This playbook documents all available commands in the Platform Admin CLI tool (`src.cli.admin`). The CLI provides secure, auditable management of admin accounts and user tiers without direct database access.

## Prerequisites

- Running Kubernetes cluster with api-service deployed
- Access to kubectl with api-service-local namespace permissions
- For admin commands: existing Supabase user account

---

## CLI Access

All commands are run via kubectl exec into the api-service pod:

```bash
kubectl exec -n api-service-local deployment/api-service -- \
  python -m src.cli.admin <command> [options]
```

### Quick Help

```bash
kubectl exec -n api-service-local deployment/api-service -- \
  python -m src.cli.admin --help
```

---

## Commands

### 1. Create Admin Account

Grants admin privileges to an existing user. The user must have registered via Supabase first.

```bash
kubectl exec -n api-service-local deployment/api-service -- \
  python -m src.cli.admin create-admin \
  --email user@example.com \
  --role super_admin
```

#### Options

| Option | Required | Description |
|--------|----------|-------------|
| `--email` | Yes | Email of existing user |
| `--role` | Yes | Admin role to assign |
| `--created-by` | No | Email of super_admin creating this account |

#### Available Roles

| Role | Permissions |
|------|-------------|
| `super_admin` | Full access, can manage other admins |
| `platform_admin` | User management, emergency actions |
| `support_admin` | Read-only user data, basic support |

#### Example Output

```
============================================================
BlockSecOps Platform Admin Management
============================================================

[SUCCESS] Admin account created for user@example.com

============================================================
MFA SETUP REQUIRED
============================================================

TOTP Secret (for manual entry):
  ABCDEFGHIJKLMNOPQRSTUVWXYZ234567

Or use this URI with an authenticator app:
  otpauth://totp/BlockSecOps%20Admin:user@example.com?secret=...

IMPORTANT: Save this secret securely. It will not be shown again.
============================================================
```

---

### 2. List Admins

Lists all users with admin privileges.

```bash
kubectl exec -n api-service-local deployment/api-service -- \
  python -m src.cli.admin list
```

#### Example Output

```
============================================================
BlockSecOps Platform Admin Management
============================================================

Email                                    Role                 MFA      Created
------------------------------------------------------------------------------------------
admin@blocksecops.com                    super_admin          Enabled  2026-01-15 10:30
support@blocksecops.com                  support_admin        Pending  2026-01-20 14:15

Total: 2 admin(s)
```

---

### 3. Reset MFA

Generates a new MFA secret for an admin account. Use when an admin loses access to their authenticator app.

```bash
kubectl exec -n api-service-local deployment/api-service -- \
  python -m src.cli.admin reset-mfa \
  --email admin@example.com
```

#### Options

| Option | Required | Description |
|--------|----------|-------------|
| `--email` | Yes | Email of admin to reset |

#### Confirmation Required

```
[WARNING] You are about to reset MFA for admin admin@example.com
Are you sure? (y/N): y
```

#### Example Output

```
[SUCCESS] MFA reset for admin@example.com

============================================================
NEW MFA SECRET
============================================================

TOTP Secret (for manual entry):
  NEWSECRETHEREABCDEFGHIJ234567

Or use this URI with an authenticator app:
  otpauth://totp/BlockSecOps%20Admin:admin@example.com?secret=...

IMPORTANT: Save this secret securely. It will not be shown again.
============================================================
```

---

### 4. Unlock MFA

Clears MFA lockout for an admin who exceeded failed attempts. Does NOT reset the MFA secret - the admin still needs their existing authenticator.

```bash
kubectl exec -n api-service-local deployment/api-service -- \
  python -m src.cli.admin unlock-mfa \
  --email admin@example.com
```

#### Options

| Option | Required | Description |
|--------|----------|-------------|
| `--email` | Yes | Email of admin to unlock |

#### Example Output

```
[INFO] Current status for admin@example.com:
  Failed attempts: 5
  Locked until: 2026-01-25 15:30:00+00:00

[WARNING] You are about to unlock MFA for admin admin@example.com
Are you sure? (y/N): y

[SUCCESS] MFA unlocked for admin@example.com

The admin can now attempt MFA verification again.
Note: They still need to enter the correct MFA code.
```

---

### 5. Set User Tier

Updates the subscription tier for a user. Used for testing or support operations.

```bash
kubectl exec -n api-service-local deployment/api-service -- \
  python -m src.cli.admin set-tier \
  --email user@example.com \
  --tier growth
```

#### Options

| Option | Required | Description |
|--------|----------|-------------|
| `--email` | Yes | Email of user to update |
| `--tier` | Yes | New subscription tier |

#### Available Tiers

| Tier | API Access | Rate Limits |
|------|------------|-------------|
| `developer` | No | N/A |
| `team` | No | N/A |
| `growth` | Yes | 300/min, 10,000/hr |
| `enterprise` | Yes | Custom |

#### Example Output

```
============================================================
BlockSecOps Platform Admin Management
============================================================

[SUCCESS] Tier updated for user@example.com: none -> growth
```

---

## Common Workflows

### Grant API Access to a User

Users need `growth` or `enterprise` tier to use API keys:

```bash
# 1. Set tier to growth
kubectl exec -n api-service-local deployment/api-service -- \
  python -m src.cli.admin set-tier --email user@example.com --tier growth

# 2. User can now create API keys via the dashboard or API
```

### Recover Locked Admin

When an admin is locked out due to failed MFA attempts:

```bash
# 1. Check if locked
kubectl exec -n api-service-local deployment/api-service -- \
  python -m src.cli.admin list

# 2. Unlock (keeps existing MFA secret)
kubectl exec -n api-service-local deployment/api-service -- \
  python -m src.cli.admin unlock-mfa --email admin@example.com

# 3. If authenticator app lost, reset MFA
kubectl exec -n api-service-local deployment/api-service -- \
  python -m src.cli.admin reset-mfa --email admin@example.com
```

### Create Admin Hierarchy

Super admins can track who created other admins:

```bash
# Create platform admin, tracking who created them
kubectl exec -n api-service-local deployment/api-service -- \
  python -m src.cli.admin create-admin \
  --email support@example.com \
  --role platform_admin \
  --created-by super@example.com
```

---

## Troubleshooting

### "User not found"

The user must register through Supabase authentication first:
1. Have the user log in via the dashboard
2. Verify they appear in the users table
3. Then run the CLI command

### "User already has admin role"

The user is already an admin. The CLI will prompt to update the role:
```
[WARNING] User already has admin role: platform_admin
Do you want to update the role? (y/N):
```

### "Invalid role" or "Invalid tier"

Check the exact spelling. Available values:
- Roles: `super_admin`, `platform_admin`, `support_admin`
- Tiers: `developer`, `team`, `growth`, `enterprise`

### Pod Not Ready

If the api-service pod isn't ready:
```bash
# Check pod status
kubectl get pods -n api-service-local

# Wait for rollout
kubectl rollout status deployment/api-service -n api-service-local
```

---

## Verification

### Verify Admin Creation

```bash
kubectl exec -n api-service-local deployment/api-service -- \
  python -m src.cli.admin list | grep "user@example.com"
```

### Verify Tier Update

```bash
kubectl exec -n api-service-local deployment/api-service -- python -c "
import asyncio
from src.infrastructure.database.connection import AsyncSessionLocal
from sqlalchemy import text

async def check():
    async with AsyncSessionLocal() as session:
        result = await session.execute(text(
            \"SELECT email, tier FROM users WHERE email = 'user@example.com'\"
        ))
        row = result.fetchone()
        print(f'{row[0]}: {row[1]}')

asyncio.run(check())
" 2>&1 | grep -v "INFO:"
```

---

## Security Notes

- CLI commands require kubectl access to the cluster
- All operations are logged to pod stdout (audit trail)
- MFA secrets are encrypted at rest using Fernet
- Tier changes are timestamped (`tier_updated_at`)
- Admin creation tracks the creator (`admin_created_by`)

---

## Related Documentation

- [Admin Account Setup](admin-account-setup.md) - Full admin setup workflow
- [Admin MFA Lockout Reset](admin-mfa-lockout-reset.md) - MFA recovery procedures
- [Tier Standards](/home/pwner/Git/docs/standards/tier-standards.md) - Tier feature definitions
