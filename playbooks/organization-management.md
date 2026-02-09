# Organization Management Playbook

How organizations are created, managed, and secured on the BlockSecOps platform.

---

## Organization Creation

Organizations are created exclusively via the Enterprise tier subscription. There is no user-facing "Create Organization" UI page.

### Prerequisites

| Requirement | Description |
|-------------|-------------|
| Enterprise subscription | User must have an active Enterprise tier Stripe subscription |
| No existing org | User cannot already own an active organization |

### Creation Flow

```bash
# Enterprise admin creates organization via API
curl -X POST http://127.0.0.1:8000/api/v1/organizations \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Acme Security",
    "description": "Enterprise security team"
  }'
```

| Step | What Happens |
|------|--------------|
| 1. Tier check | `require_tier("enterprise")` validates subscription |
| 2. Ownership check | Verifies user doesn't already own an org |
| 3. Org created | `OrganizationModel` with `tier=enterprise`, `owner_id=current_user` |
| 4. Roles created | System roles: owner, admin, developer, auditor, guest |
| 5. Owner membership | User added as member with owner role |
| 6. Default team | "General" team created, owner added as team lead |

### Dashboard Access

- Organization membership is confirmed via the **TopBar OrgSelector**
- Organization name appears on the **Billing page**
- There is no dedicated Organizations page in the sidebar

---

## Member Management

### Adding Members

Only owners and admins can add members.

```bash
# Add member by email with developer role
curl -X POST http://127.0.0.1:8000/api/v1/organizations/{org_id}/members \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "developer@example.com",
    "role_id": "<developer-role-uuid>"
  }'
```

| Rule | Description |
|------|-------------|
| Permission required | Only owners and admins can add members |
| Seat limits | Enterprise tier seat limits enforced (from `UserQuotaModel`) |
| Team assignment | Members auto-added to specified team or org's default team |
| Owner role blocked | Cannot assign the owner role to new members |

### Updating Member Roles

```bash
# Change member role
curl -X PATCH http://127.0.0.1:8000/api/v1/organizations/{org_id}/members/{member_id} \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "role_id": "<admin-role-uuid>"
  }'
```

| Rule | Description |
|------|-------------|
| Permission required | Only owners and admins can change roles |
| Owner role blocked | Cannot assign the owner role |
| Owner immutable | Cannot change the owner's role |
| Last admin protection | Cannot remove the last admin (in `/current/users/{id}` endpoint) |

### Removing Members

```bash
# Remove member
curl -X DELETE http://127.0.0.1:8000/api/v1/organizations/{org_id}/members/{member_id} \
  -H "Authorization: Bearer <token>"
```

| Rule | Description |
|------|-------------|
| Permission required | Only owners and admins can remove members |
| Owner protected | Cannot remove the organization owner |

---

## Ownership Rules

| Rule | Enforcement |
|------|-------------|
| One owner per org | Set at org creation, cannot be transferred |
| Cannot add additional owners | All add/update endpoints reject owner role assignment |
| Owner cannot self-remove | Removal endpoints block owner from removing themselves |
| Owner role immutable | Update endpoints block changes to the owner's role |
| Always at least one owner | Owner is permanent for org lifetime |
| Admin as alternative | Admin role provides all management permissions except billing |

---

## Role Hierarchy

| Role | Display Name | Key Permissions | Member Management |
|------|-------------|-----------------|-------------------|
| `owner` | Owner | Full access (`*`), billing | Full control |
| `admin` | Administrator | Org management, member management, all resources | Add/remove/update members (not owner) |
| `developer` | Developer | Create/manage contracts and scans | No |
| `auditor` | Auditor | Read-only access to contracts, scans, vulnerabilities | No |
| `guest` | Guest | Limited read-only access | No |

---

## Security Fixes Applied (BSO-SEC-016)

| # | Issue | Fix |
|---|-------|-----|
| 1 | `add_current_organization_user` had no permission checks | Added `verify_member_management_permission()` |
| 2 | `update_current_organization_user` called undefined `require_admin_permission()` | Replaced with `verify_member_management_permission()` |
| 3 | `remove_current_organization_user` had no permission checks | Added `verify_member_management_permission()` |
| 4 | `add_member` and `update_member` allowed assigning owner role | Added owner role restriction check |
| 5 | `update_member` only checked membership, not admin permission | Added `verify_member_management_permission()` |

### Permission Check Function

All member management endpoints use `verify_member_management_permission()`:

1. Verifies user is an active org member
2. Checks if user is the org owner (always permitted)
3. Checks if user has an admin-like role (admin, administrator, manager)
4. Checks for explicit `is_admin` or `manage_members` permissions in role settings
5. Logs denial for security monitoring with BSO-SEC-016 tag

---

## API Endpoints

### Current Organization Endpoints

| Endpoint | Method | Description | Permission |
|----------|--------|-------------|------------|
| `/organizations/current/users` | GET | List org members | Any member |
| `/organizations/current/users` | POST | Add member | Owner/Admin |
| `/organizations/current/users/{id}` | PATCH | Update member role | Owner/Admin |
| `/organizations/current/users/{id}` | DELETE | Remove member | Owner/Admin |

### Organization-Scoped Endpoints

| Endpoint | Method | Description | Permission |
|----------|--------|-------------|------------|
| `/organizations/{id}/members` | GET | List members | Any member |
| `/organizations/{id}/members` | POST | Add member | Owner/Admin |
| `/organizations/{id}/members/{id}` | PATCH | Update role | Owner/Admin |
| `/organizations/{id}/members/{id}` | DELETE | Remove member | Owner/Admin |

---

## Related Documentation

- [Subscription Workflow](../workflows/subscription-workflow.md) - Subscription lifecycle and org creation
- [Subscription Pipeline](../pipelines/subscription-pipeline.md) - Technical billing integration
- [Organization Scoping Pipeline](../pipelines/organization-scoping-pipeline.md) - Data isolation and ownership rules
- [Tier Standards](../standards/tier-standards.md) - Tier definitions and quotas
- [API Endpoint Authentication](../standards/api-endpoint-auth.md) - Auth patterns

---

*Last Updated: February 8, 2026*
