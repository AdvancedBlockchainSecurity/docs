# Team Management Pipeline

Technical pipeline for team operations within organizations, including team CRUD, member assignment, project access control, and cascade behaviors.

## Overview

```
Dashboard / API                API Service                    Database
───────────────                ───────────                    ────────
OrgSelector context    →       X-Organization-Id header   →   TeamModel
Teams page (future)    →       /organizations/{id}/teams  →   TeamMemberModel
Project Settings       →       Team access grants         →   ProjectTeamAccessModel
```

---

## Team CRUD Pipeline

### Create Team

```
Admin/Owner calls POST /organizations/{org_id}/teams
  │
  ├── 1. Validate org membership + admin permission
  │       → verify_member_management_permission()
  │
  ├── 2. Create TeamModel
  │       → organization_id = org_id
  │       → slug = auto-generated or provided (unique within org)
  │       → color = optional hex color (#rrggbb)
  │       → is_default = false (only "General" is default)
  │       → created_by = current_user.id
  │
  └── 3. Return team with member count
```

### List Teams

```
Member calls GET /organizations/{org_id}/teams
  │
  ├── 1. Validate org membership
  │
  ├── 2. Query TeamModel WHERE organization_id = org_id
  │       → Include member count via subquery
  │
  └── 3. Return list with member counts
```

### Update Team

```
Admin/Owner calls PATCH /organizations/{org_id}/teams/{team_id}
  │
  ├── 1. Validate org membership + admin permission
  │
  ├── 2. Validate team belongs to organization
  │
  ├── 3. Update allowed fields: name, description, color, slug
  │
  └── 4. Return updated team
```

### Delete Team

```
Admin/Owner calls DELETE /organizations/{org_id}/teams/{team_id}
  │
  ├── 1. Validate org membership + admin permission
  │
  ├── 2. Cannot delete default team (is_default=true)
  │
  ├── 3. Cascade: TeamMemberModel records deleted
  │       → Members removed from team
  │       → If user has no other teams in org → auto-remove from org
  │
  ├── 4. Cascade: ProjectTeamAccessModel records deleted
  │       → Team loses access to all projects
  │
  └── 5. TeamModel deleted
```

---

## Team Member Pipeline

### Add Member to Team

```
Admin/Owner calls POST /organizations/{org_id}/teams/{team_id}/members
  │
  ├── 1. Validate org membership + admin permission
  │
  ├── 2. Validate team belongs to organization
  │
  ├── 3. Validate target user is an active org member
  │       → Must have OrganizationMemberModel with is_active=true
  │
  ├── 4. Check team member quota (tier-dependent)
  │       → Enterprise: configurable max
  │       → Growth: limited max_team_members
  │
  ├── 5. Create TeamMemberModel
  │       → team_id, user_id
  │       → role = "member" (default) or "lead"
  │       → added_by = current_user.id
  │
  └── 6. Return team member record
```

### Update Team Member Role

```
Admin/Owner calls PATCH /organizations/{org_id}/teams/{team_id}/members/{user_id}
  │
  ├── 1. Validate org membership + admin permission
  │
  ├── 2. Update role: "member" ↔ "lead"
  │       → lead: can manage team assignments (future)
  │       → member: standard team access
  │
  └── 3. Return updated team member
```

### Remove Member from Team

```
Admin/Owner calls DELETE /organizations/{org_id}/teams/{team_id}/members/{user_id}
  │
  ├── 1. Validate org membership + admin permission
  │
  ├── 2. Delete TeamMemberModel
  │
  ├── 3. Check if user has other teams in this org
  │       → Query: SELECT count(*) FROM team_members
  │         JOIN teams ON teams.id = team_members.team_id
  │         WHERE teams.organization_id = org_id
  │         AND team_members.user_id = target_user_id
  │
  ├── 4. If user has NO other teams:
  │       → Auto-remove from organization (delete OrganizationMemberModel)
  │       → EXCEPTION: Cannot auto-remove org owner
  │
  └── 5. Return success
```

---

## Project Access Control

### Grant Team Access to Project

```
ProjectTeamAccessModel created
  │
  ├── project_id (FK projects.id)
  ├── team_id (FK teams.id)
  ├── access_level: "owner" | "write" | "read"
  ├── granted_by: user who granted access
  └── granted_at: timestamp
```

### Direct User Access (Bypass Team)

```
ProjectUserAccessModel created
  │
  ├── project_id (FK projects.id)
  ├── user_id (FK users.id)
  ├── access_level: "owner" | "write" | "read"
  ├── granted_by: user who granted access
  └── granted_at: timestamp
```

### Access Resolution Order

```
1. Is user the project owner? → Full access
2. Does user have ProjectUserAccessModel? → Use that access_level
3. Is user on a team with ProjectTeamAccessModel? → Use highest team access_level
4. Is user an org member (shared org visibility)? → Read access to org projects
5. None of the above → 403 Forbidden
```

---

## Database Models

### TeamModel (`teams`)

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID | PK |
| `organization_id` | UUID FK | Indexed, cascade delete |
| `name` | String(100) | Required |
| `slug` | String(100) | Required |
| `description` | Text | Optional |
| `color` | String(7) | Optional (#rrggbb) |
| `is_default` | Boolean | Default false |
| `created_by` | UUID FK users.id | Set null on delete |
| `created_at` | DateTime | Server default now |
| `updated_at` | DateTime | Auto-update |

**Unique:** `(organization_id, slug)`

### TeamMemberModel (`team_members`)

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID | PK |
| `team_id` | UUID FK teams.id | Indexed, cascade delete |
| `user_id` | UUID FK users.id | Indexed, cascade delete |
| `role` | String(20) | "lead" or "member" |
| `added_by` | UUID FK users.id | Set null on delete |
| `added_at` | DateTime | Server default now |

**Unique:** `(team_id, user_id)`

### ProjectTeamAccessModel (`project_team_access`)

| Column | Type | Constraints |
|--------|------|-------------|
| `id` | UUID | PK |
| `project_id` | UUID FK projects.id | Cascade delete |
| `team_id` | UUID FK teams.id | Cascade delete |
| `access_level` | String(20) | "owner", "write", "read" |
| `granted_by` | UUID FK users.id | Set null |
| `granted_at` | DateTime | Server default now |

**Unique:** `(project_id, team_id)`

---

## Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/organizations/{org_id}/teams` | Admin/Owner | Create team |
| GET | `/organizations/{org_id}/teams` | Member | List teams with member counts |
| GET | `/organizations/{org_id}/teams/{team_id}` | Member | Get team details with members |
| PATCH | `/organizations/{org_id}/teams/{team_id}` | Admin/Owner | Update team |
| DELETE | `/organizations/{org_id}/teams/{team_id}` | Admin/Owner | Delete team (cascade) |
| POST | `/organizations/{org_id}/teams/{team_id}/members` | Admin/Owner | Add team member |
| PATCH | `/organizations/{org_id}/teams/{team_id}/members/{user_id}` | Admin/Owner | Update member role |
| DELETE | `/organizations/{org_id}/teams/{team_id}/members/{user_id}` | Admin/Owner | Remove team member |

---

## Cascade Behaviors

| Trigger | Effect |
|---------|--------|
| Organization deleted | All teams deleted (cascade) |
| Team deleted | All team members removed, project access revoked |
| User removed from last team | Auto-removed from organization (except owner) |
| User removed from organization | All team memberships in that org deleted |
| Project deleted | All team access and user access records deleted |

---

## Security Controls

| Control | Implementation |
|---------|----------------|
| Org boundary enforcement | Team must belong to target organization |
| Member prerequisite | User must be org member before joining team |
| Permission check | `verify_member_management_permission()` on all mutations |
| Default team protection | Cannot delete the `is_default=true` team |
| Owner protection | Owner cannot be auto-removed via team cascade |

---

## Related

- [Organization Management Workflow](../workflows/organization-management-workflow.md) — Org lifecycle
- [Organization Scoping Pipeline](organization-scoping-pipeline.md) — Data isolation
- [Subscription Pipeline](subscription-pipeline.md) — Enterprise provisioning
- [Tier Standards](../standards/tier-standards.md) — Seat limits per tier

---

*Last Updated: February 25, 2026*
