# Organization Scoping Pipeline

Manages data isolation and shared visibility across organizations, teams, and personal workspaces.

## Overview

```
Dashboard / API            API Service               Database
───────────────            ───────────               ────────
OrgSelector.tsx     →      X-Organization-Id header   organization_id FK
OrganizationContext →      get_current_org_id()       org-scoped WHERE clauses
setCurrentOrgIdForApi()    validate membership        contracts, scans, projects
Query keys include orgId   stamp org_id on writes     personal workspace (NULL)
```

## Data Flow

### Read Path (List Endpoints)

| Step | Description |
|------|-------------|
| User selects org | OrgSelector dropdown → OrganizationContext → setCurrentOrgIdForApi() |
| React Query refetch | All query keys include `currentOrgId`, cache invalidated on switch |
| Axios interceptor | Injects `X-Organization-Id` header on every request |
| Dependency injection | `get_current_org_id()` extracts header, validates UUID, verifies active membership |
| SQL WHERE clause | `WHERE organization_id = :org_id` (org mode) or `WHERE user_id = :uid AND organization_id IS NULL` (personal) |

### Write Path (Create Endpoints)

| Step | Description |
|------|-------------|
| API receives request | `X-Organization-Id` header present → org-scoped creation |
| Membership validation | `get_current_org_id()` verifies user is active member of target org |
| Record stamped | `organization_id=org_id` set on new ContractModel, ScanModel, ProjectModel |
| Authorization check | For scans: contract must belong to same org (`contract.organization_id == org_id`) |

### Org Switch (Frontend)

| Step | Description |
|------|-------------|
| User clicks org/personal | `switchOrganization(orgId \| null)` called |
| API client updated | `setCurrentOrgIdForApi(orgId)` — all subsequent requests carry new header |
| localStorage updated | `blocksecops-current-org` key set or removed |
| Cache invalidated | All org-scoped query keys invalidated (dashboard, contracts, scans, vulnerabilities, projects, teams, members) |
| Pages refetch | React Query triggers fresh API calls with new org scope |

## Security Model

### BSO-SEC-015: Authorization in SQL WHERE Clause

All data filtering happens at the SQL layer, never in Python:

```python
# Org mode — show ALL org data (shared visibility within org)
if org_id:
    query = select(Model).where(Model.organization_id == org_id)

# Personal workspace — show only user's unscoped data
else:
    query = select(Model).where(
        Model.user_id == current_user.id,
        Model.organization_id.is_(None),
    )
```

### Membership Validation

Every request with `X-Organization-Id` is validated:

```python
result = await db.execute(
    select(OrganizationMemberModel.id).where(
        OrganizationMemberModel.organization_id == org_id,
        OrganizationMemberModel.user_id == current_user.id,
        OrganizationMemberModel.is_active == True,
    )
)
if not result.scalar_one_or_none():
    raise HTTPException(403, "Not a member of this organization")
```

### Team-Gated Access

Users cannot be members of an org without being on a team:

| Rule | Implementation |
|------|----------------|
| Org creation | Auto-creates "General" default team, owner added as lead |
| Member addition | User added to specified team or org's default team atomically |
| Invite acceptance | Invitee added to invite's target team or org's default team |
| Team removal cascade | Removing user from last team in org → auto-removes from org (except owner) |

## Database Schema

### organization_id Columns (Migration 068)

```sql
ALTER TABLE contracts ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL;
ALTER TABLE scans ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL;
ALTER TABLE projects ADD COLUMN organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL;
```

- **Nullable**: `NULL` = personal workspace (backward compatible)
- **ON DELETE SET NULL**: Deleted org reverts data to personal workspace, no data loss
- **Indexed**: Individual + composite `(organization_id, user_id)` indexes

### Default Team Flag (Migration 070)

```sql
ALTER TABLE teams ADD COLUMN is_default BOOLEAN NOT NULL DEFAULT FALSE;
```

### Default Organization Preference (Migration 072)

```sql
ALTER TABLE users ADD COLUMN default_organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL;
```

## Affected Endpoints

### Backend (org-scoped query layer)

| Endpoint | File | Scoping |
|----------|------|---------|
| `GET /contracts` | contracts.py | `ContractModel.organization_id` |
| `POST /contracts` | contracts.py | Stamps `organization_id` |
| `GET /scans` | scans.py | `ScanModel.organization_id` |
| `POST /scans` | scans.py | Stamps `organization_id`, validates contract belongs to org |
| `GET /vulnerabilities` | vulnerabilities.py | Joins `ContractModel.organization_id` |
| `GET /statistics/dashboard` | statistics.py | Scoped scan + contract filters |
| `GET /statistics/scan-history` | statistics.py | Scoped scan + vulnerability filters |
| `GET /statistics/risk` | statistics.py | Scoped contract + project filters |
| `GET /projects` | projects.py | `ProjectModel.organization_id` via service/repo |
| `POST /projects` | projects.py | Stamps `organization_id` via service/repo |
| `PUT /users/me` | users.py | Sets `default_organization_id` (validated) |

### Frontend (org-aware query keys)

| Page | Query Key | Context |
|------|-----------|---------|
| Dashboard.tsx | `useEffect` dep: `currentOrgId` | Manual fetch with apiClient |
| ContractsList.tsx | `['contracts', currentOrgId, ...]` | React Query |
| RecentScans.tsx | `['recent-scans', currentOrgId, ...]` | React Query |
| VulnerabilitiesList.tsx | `['vulnerabilities', currentOrgId, ...]` | React Query |
| Projects.tsx | `['projects', 'list', currentOrgId, ...]` | Via useProjects hook |

## Backward Compatibility

- All `organization_id` columns are **nullable** — existing data stays `NULL`
- API calls **without** `X-Organization-Id` header work exactly as before (personal workspace)
- Migration 069 backfills `organization_id` for single-org users only
- No breaking changes to existing API contracts
