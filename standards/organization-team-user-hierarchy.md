# Organization, Team, and User Hierarchy

**Version:** 1.0.0
**Last Updated:** March 13, 2026
**Status:** Active

## Overview

The Apogee platform uses a three-level hierarchy for multi-tenant collaboration: **Organization → Team → User**. This document defines the data model, permissions, workflows, and tier requirements for the hierarchy.

---

## Hierarchy Diagram

```
Organization (starter+ tier required to create)
├── Settings (name, slug, logo, SSO config)
├── Billing (Stripe customer/subscription, tier)
├── Roles (RBAC: owner, admin, member, viewer)
├── Members (users assigned to roles)
├── Service Accounts (Growth+ tier, CI/CD automation)
└── Teams
    ├── "General" (default, auto-created)
    ├── Team A
    │   ├── Lead (team-level role)
    │   └── Members
    └── Team B
        ├── Lead
        └── Members
```

**Key relationships:**
- A user can own **one** organization
- A user can be a **member** of multiple organizations
- An organization has **one or more** teams (minimum: the default "General" team)
- A team belongs to **exactly one** organization
- A user can be in **multiple teams** within the same organization

---

## Tier Requirements

| Capability | Developer | Starter | Growth | Enterprise |
|------------|-----------|---------|--------|------------|
| Create organization | No | Yes | Yes | Yes |
| Max team members | 2 | 5 | 25 | Unlimited |
| Max projects | 3 | 15 | Unlimited | Unlimited |
| Service accounts | No | No | Yes | Yes |
| SSO/SAML | No | No | No | Yes |
| Custom roles | No | No | No | Yes |
| Audit log export | No | No | No | Yes |

**Developer tier** users operate in a personal workspace only — no organization creation, individual quotas, max 2 collaborators via team member quota.

---

## Data Model

### OrganizationModel

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK, auto-generated | |
| name | String(255) | NOT NULL | Display name |
| slug | String(100) | UNIQUE, NOT NULL | URL-safe identifier |
| description | Text | Optional | |
| logo_url | String(2048) | Optional | |
| tier | String(50) | Default="developer" | Billing tier |
| stripe_customer_id | String(255) | UNIQUE, optional | Stripe integration |
| stripe_subscription_id | String(255) | Optional | |
| sso_enabled | Boolean | Default=false | Enterprise only |
| sso_provider | String(50) | Optional | "saml" or "oidc" |
| sso_config | JSONB | Optional | Provider configuration |
| sso_domain | String(255) | Optional, indexed | Domain-based SSO matching |
| settings | JSONB | Default={} | Org-level settings |
| owner_id | UUID | FK→users, SET NULL | Organization owner |
| is_active | Boolean | Default=true | Soft delete |

### RoleModel (RBAC)

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK | |
| organization_id | UUID | FK→organizations, CASCADE | NULL for system roles |
| name | String(100) | NOT NULL | Internal name |
| display_name | String(255) | NOT NULL | UI display |
| description | Text | Optional | |
| permissions | JSONB | Default=[] | List of permission strings |
| is_system_role | Boolean | Default=false | Cannot modify/delete if true |

**Default roles** created on organization setup:

| Role | Permissions | System Role |
|------|-------------|-------------|
| owner | Full access — manage billing, members, settings, delete org | Yes |
| admin | Manage members, teams, settings — no billing/delete | Yes |
| member | Access scans, create content, view results | Yes |
| viewer | Read-only access to org resources | Yes |

### OrganizationMemberModel

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK | |
| organization_id | UUID | FK→organizations, CASCADE | |
| user_id | UUID | FK→users, CASCADE | |
| role_id | UUID | FK→roles, RESTRICT | Prevents orphaned assignments |
| invited_by | UUID | Optional | Who sent the invite |
| invited_at | DateTime | Optional | |
| joined_at | DateTime | Default=now() | |
| is_active | Boolean | Default=true | |

### TeamModel

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK | |
| organization_id | UUID | FK→organizations, CASCADE | |
| name | String(100) | NOT NULL | |
| slug | String(100) | UNIQUE per org | Composite unique: (org_id, slug) |
| description | Text | Optional | |
| color | String(7) | Optional | Hex color for UI (e.g., #FF5733) |
| is_default | Boolean | Default=false | True for auto-created "General" team |
| created_by | UUID | FK→users, SET NULL | |

### TeamMemberModel

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK | |
| team_id | UUID | FK→teams, CASCADE | |
| user_id | UUID | FK→users, CASCADE | |
| role | String(20) | Default="member" | "lead" or "member" |
| added_by | UUID | FK→users, SET NULL | |
| added_at | DateTime | Default=now() | |

**Constraint:** Composite unique index on `(team_id, user_id)` prevents duplicate memberships.

### ServiceAccountModel (Growth+ tier)

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PK | |
| organization_id | UUID | FK→organizations, CASCADE | |
| name | String(255) | NOT NULL | e.g., "CI Pipeline Bot" |
| description | String(500) | Optional | |
| created_by | UUID | FK→users, SET NULL | |
| key_prefix | String(16) | Indexed | First 16 chars of key |
| key_hash | String(64) | NOT NULL | SHA-256 hash |
| scopes | JSONB | Default=[] | Permission scopes |
| rate_limit_per_minute | Integer | Default=120 | |
| rate_limit_per_hour | Integer | Default=2000 | |
| is_active | Boolean | Default=true | |
| expires_at | DateTime | Optional | |

---

## Organization Creation Workflow

**Endpoint:** `POST /api/v1/organizations`
**Tier requirement:** `require_tier("starter")`

When a user creates an organization, the following happens automatically:

1. **Validation** — User must not already own an active organization (limit: 1 per user)
2. **Slug generation** — If not provided, auto-generated from name; must be unique
3. **Organization created** — Tier set to user's current tier, owner_id set to user
4. **Default roles created** — owner, admin, member, viewer (all marked as system roles)
5. **Owner membership** — User added as OrganizationMember with "owner" role
6. **Default team created** — "General" team with `is_default=true`, slug=`{org-slug}-general`
7. **Owner added to team** — User added as TeamMember with role="lead"

```
POST /api/v1/organizations
{
  "name": "My Security Team",
  "slug": "my-security-team",        // optional, auto-generated if omitted
  "description": "Smart contract auditing team"
}

→ Creates: Organization + 4 Roles + Owner Membership + "General" Team + Team Lead
```

---

## Team Management

**Base route:** `/api/v1/organizations/{org_id}/teams`

| Operation | Method | Permission | Notes |
|-----------|--------|------------|-------|
| List teams | GET | Any org member | Paginated |
| Create team | POST | Admin+ | Slug must be unique within org |
| Get team | GET | Any org member | Includes member list |
| Update team | PUT | Admin+ | Name, description, color |
| Delete team | DELETE | Admin+ | Cannot delete default team |
| Add member | POST | Admin+ | Specify user_id and role |
| Remove member | DELETE | Admin+ | Cannot remove last lead |
| Update member role | PUT | Admin+ | Toggle lead/member |

**Team member roles:**
- **lead** — Can manage team members within their team
- **member** — Standard team access

**Input validation:** All name/description fields pass through `sanitize_user_text()` (BSO-SEC-INPUT-001).

---

## Invite Workflow

### TeamInviteModel

| Column | Type | Notes |
|--------|------|-------|
| id | UUID | PK |
| inviter_user_id | UUID | FK→users, who sent invite |
| organization_id | UUID | Optional, FK→organizations |
| team_id | UUID | Optional, FK→teams |
| email | String(255) | Invitee email |
| name | String(255) | Optional, for lead generation |
| role | String(50) | Default="member" |
| status | String(20) | pending/accepted/expired/revoked |
| invite_token | String(64) | Unique, secure token |
| expires_at | DateTime | Expiration timestamp |
| marketing_consent | Boolean | Default=false (GDPR) |

### Invite Flow

```
1. Admin/Owner creates invite
   POST /api/v1/organizations/{org_id}/invites
   { "email": "user@example.com", "role": "member", "team_id": "..." }

2. System generates secure invite_token
3. Email sent to invitee (tracked: email_sent_at, email_opened_at)

4. Invitee clicks invite link
   → If existing user: Accept invite, join org + team
   → If new user: Register, then auto-join org + team

5. On acceptance:
   - OrganizationMember created with assigned role
   - TeamMember created if team_id specified
   - Invite status → "accepted"
   - Lead generation data captured
```

---

## Data Scoping Rules

Resources are scoped to their owner level:

| Resource | Scope | Access Rule |
|----------|-------|-------------|
| Scans | User or Organization | Org members see org scans; personal scans are user-only |
| Contracts | User or Organization | Same as scans |
| Vulnerabilities | Scan-level | Visible to whoever can access the parent scan |
| API Keys | User | Personal API keys; service accounts are org-scoped |
| Projects | User or Organization | Org projects visible to all org members |
| Webhooks | User or Organization | Org webhooks managed by admin+ |
| Audit Logs | Organization | Enterprise only; visible to owner/admin |

**Isolation guarantees:**
- Organization data is isolated from other organizations
- Team-level scoping is available for project access (`ProjectTeamAccessModel`)
- Users cannot access resources from organizations they are not members of
- Service account access is limited to the scopes defined at creation

---

## Enterprise Features

Available only on the Enterprise tier ($1,499+/month):

### SSO/SAML
- Configure via `sso_config` JSONB field on OrganizationModel
- Supported providers: SAML 2.0, OIDC
- Domain-based auto-join: users with matching `sso_domain` auto-assigned to org
- Managed through admin API endpoints

### Audit Log Export
- All tier changes, member additions/removals, role changes logged
- Audit actions: `TIER_UPGRADED`, `TIER_DOWNGRADED`, `TIER_CHANGED_ADMIN`, `TIER_ACCESS_DENIED`, `QUOTA_RESET`
- Exportable via admin API for compliance

### Custom Roles
- Enterprise orgs can create custom roles beyond the 4 defaults
- Granular permission strings in JSONB array
- System roles cannot be modified; custom roles fully configurable

### Unlimited Resources
- Unlimited team members, projects, API calls, AI explanations
- 365-day result retention
- Priority 5 scan queue (highest priority)
- Dedicated support channel

---

## Access Control Summary

```
require_tier("starter")  →  Organization creation
require_tier("growth")   →  Service accounts, CI/CD integrations
require_tier("enterprise") → SSO, audit logs, custom roles

Organization-level:
  owner  → Full control (billing, delete, settings, members)
  admin  → Manage members, teams, settings
  member → Create/view scans, contracts, results
  viewer → Read-only access

Team-level:
  lead   → Manage team members
  member → Standard team access
```

---

## Related Documentation

- [Tier Standards](./tier-standards.md) — Quota values, pricing, tier gates
- [API Endpoint Authentication](./api-endpoint-auth.md) — Auth dependencies and scope enforcement
- [Secure Coding Standards](./secure-coding.md) — Input validation requirements
- **Playbooks:**
  - `docs/playbooks/create-organization.md`
  - `docs/playbooks/organization-team-setup.md`
  - `docs/playbooks/create-team.md`
  - `docs/playbooks/invite-team-members.md`
  - `docs/playbooks/configure-roles.md`
