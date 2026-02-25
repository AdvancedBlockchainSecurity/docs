# Organization Management Workflow

**Version:** 1.0.0
**Last Updated:** February 25, 2026

## Overview

```
Enterprise Subscription       API Endpoints              Database
─────────────────────        ─────────────              ────────
Stripe checkout active  →    POST /organizations   →    OrganizationModel
                              require_tier("enterprise")  RoleModel (5 system roles)
                                                          TeamModel (default "General")
                                                          OrganizationMemberModel (owner)
```

Organization creation is exclusively available to Enterprise tier subscribers. There is no "Create Organization" button in the dashboard — organizations are provisioned via the API as part of the Enterprise activation flow.

---

## Services Involved

| Service | Role | Port |
|---------|------|------|
| API Service | Organization CRUD, member management, role management | 8000 |
| Dashboard | OrgSelector dropdown, billing page member list | 3000 (via Traefik) |
| PostgreSQL | Organization, member, role, team, invite data | 5432 |

---

## Organization Lifecycle

### 1. Creation (Enterprise Only)

| Step | Description |
|------|-------------|
| Prerequisite | User has active Enterprise tier subscription |
| API call | `POST /organizations` with name, optional slug/description |
| Tier gate | `require_tier("enterprise")` middleware validates tier |
| Ownership check | User cannot already own an active organization |
| Organization created | `OrganizationModel` with `tier=enterprise`, `owner_id=current_user` |
| System roles created | owner, admin, developer, auditor, guest — each with predefined permissions |
| Owner membership | `OrganizationMemberModel` created with owner role |
| Default team | "General" team auto-created, owner added as team lead |
| Slug generation | Auto-generated from name if not provided (`{name}-{random-hex}`) |

### 2. Member Management

| Action | Endpoint | Who Can Do It | Rules |
|--------|----------|---------------|-------|
| List members | `GET /organizations/current/users` | Any member | Paginated with role info |
| Add member | `POST /organizations/current/users` | Owner or Admin | Checks seat limit, cannot assign owner role |
| Update role | `PATCH /organizations/current/users/{user_id}` | Owner or Admin | Cannot change owner role, cannot demote last admin |
| Remove member | `DELETE /organizations/current/users/{user_id}` | Owner or Admin | Cannot remove owner |

### 3. Invite Flow

| Step | Description |
|------|-------------|
| Admin creates invite | `POST /organizations/{org_id}/invites` with email, name, role, optional team_id |
| Seat limit check | Current members + pending invites counted against tier quota |
| Token generated | 64-character invite token, 7-day expiry |
| Invitee views details | `GET /invites/{token}` — public endpoint, shows org name, inviter, role, expiry |
| Invitee accepts | `POST /invites/{token}/accept` — requires authentication |
| Membership created | `OrganizationMemberModel` + `TeamMemberModel` (target team or default) |
| Invite marked accepted | `status=accepted`, `accepted_at` recorded |

**Invite statuses:** pending → accepted / expired / revoked

### 4. Role Management

| Role | Permissions | System Role |
|------|-------------|-------------|
| **owner** | `["*"]` — full access including billing | Yes (immutable) |
| **admin** | org.*, members.*, contracts.*, scans.*, vulnerabilities.*, webhooks.*, api_keys.*, audit_logs.read | Yes |
| **developer** | org.read, members.read, contracts.*, scans.*, vulnerabilities.* | Yes |
| **auditor** | org.read, members.read, contracts.read, scans.read, vulnerabilities.read, audit_logs.read | Yes |
| **guest** | org.read, contracts.read, scans.read | Yes |
| **custom** | Any permission combination | No (can be created/modified/deleted) |

Custom roles: `POST /organizations/{org_id}/roles` (owner only)

### 5. Organization Updates

| Field | Endpoint | Who Can Do It |
|-------|----------|---------------|
| Name, description, logo | `PATCH /organizations/{org_id}` | Owner or Admin |
| AI data opt-out | `PUT /organizations/{org_id}/settings/ai-opt-out` | Enterprise tier + member |
| Soft delete | `DELETE /organizations/{org_id}` | Owner only |

### 6. Data Scoping

When a user selects an organization in the dashboard:

| Step | Description |
|------|-------------|
| User clicks org in OrgSelector | `switchOrganization(orgId)` called |
| API client updated | `X-Organization-Id` header injected on all requests |
| Backend validates | `get_current_org_id()` checks active membership |
| Data filtered | SQL `WHERE organization_id = :org_id` applied to all queries |
| Personal workspace | If no org selected, `WHERE user_id = :uid AND organization_id IS NULL` |

---

## Ownership Rules (BSO-SEC-016)

| Rule | Enforcement |
|------|-------------|
| One owner per org | Set at creation, cannot be reassigned |
| Cannot assign owner role | `add_member`, `update_member` reject owner role |
| Owner cannot be removed | `remove_member` blocks owner removal |
| Owner role immutable | `update_member` blocks owner role change |
| One org per owner | `create_organization` checks existing ownership |

---

## Admin Endpoints (Platform Admins)

| Method | Path | Role Required | Description |
|--------|------|---------------|-------------|
| GET | `/admin/organizations` | support_admin | List all orgs with search/filter |
| GET | `/admin/organizations/{id}` | support_admin | Org detail with members and stats |
| PATCH | `/admin/organizations/{id}` | platform_admin | Update org name/description/status |
| DELETE | `/admin/organizations/{id}` | super_admin | Soft delete with reason logging |

---

## API Endpoints Summary

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/organizations` | Enterprise tier | Create organization |
| GET | `/organizations` | Auth | List user's organizations |
| GET | `/organizations/{id}` | Auth | Get organization details |
| PATCH | `/organizations/{id}` | Owner/Admin | Update organization |
| DELETE | `/organizations/{id}` | Owner | Soft delete organization |
| GET | `/organizations/current/users` | Auth | List current org members |
| POST | `/organizations/current/users` | Owner/Admin | Add member to current org |
| PATCH | `/organizations/current/users/{id}` | Owner/Admin | Update member role |
| DELETE | `/organizations/current/users/{id}` | Owner/Admin | Remove member |
| GET | `/organizations/{id}/roles` | Auth | List roles |
| POST | `/organizations/{id}/roles` | Owner | Create custom role |
| PATCH | `/organizations/{id}/roles/{id}` | Owner | Update custom role |
| DELETE | `/organizations/{id}/roles/{id}` | Owner | Delete custom role |
| GET | `/organizations/{id}/members` | Auth | List members |
| POST | `/organizations/{id}/members` | Owner/Admin | Add member |
| PATCH | `/organizations/{id}/members/{id}` | Owner/Admin | Update member role |
| DELETE | `/organizations/{id}/members/{id}` | Owner/Admin | Remove member |
| POST | `/organizations/{id}/invites` | Owner/Admin | Create invite |
| GET | `/organizations/{id}/invites` | Owner/Admin | List invites |
| DELETE | `/organizations/{id}/invites/{id}` | Owner/Admin | Revoke invite |
| GET | `/invites/{token}` | Public | View invite details |
| POST | `/invites/{token}/accept` | Auth | Accept invite |
| PUT | `/organizations/{id}/settings/ai-opt-out` | Enterprise | Toggle AI opt-out |
| GET | `/organizations/{id}/settings/ai-status` | Auth | Get AI status |
| GET | `/roles` | Auth | List current org roles (convenience) |

---

## Security Controls

| Control | Implementation |
|---------|----------------|
| Anti-enumeration | Invalid/expired/revoked invites all return same 404 |
| Seat limit enforcement | Members + pending invites counted against tier quota |
| Membership validation | Every `X-Organization-Id` request validates active membership |
| SQL-level isolation | `WHERE organization_id = :org_id` on all data queries |
| Audit logging | Admin actions logged with old_values/new_values |
| Soft deletes | Organizations are soft-deleted, data preserved |

---

## Related

- [Organization Scoping Pipeline](../pipelines/organization-scoping-pipeline.md) — Data isolation details
- [Team Management Pipeline](../pipelines/team-management-pipeline.md) — Team operations
- [Subscription Workflow](subscription-workflow.md) — Enterprise subscription activation
- [Tier Standards](../standards/tier-standards.md) — Tier definitions and quotas

---

*Last Updated: February 25, 2026*
