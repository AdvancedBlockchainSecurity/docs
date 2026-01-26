# Playbook: Organization, Team, and Project Setup for Team Leads/Managers

**Version:** 1.0.0
**Last Updated:** January 23, 2026

## Overview

This playbook guides team leads and managers through the complete workflow for creating organizations, teams, projects, and managing user access in BlockSecOps. It covers permission requirements, API endpoints, and known issues to be aware of.

---

## Prerequisites

- [ ] User account with verified email
- [ ] Enterprise tier subscription (required for organization creation)
- [ ] API access token (obtained from user profile or login)
- [ ] `curl` or API client for executing requests
- [ ] Access to BlockSecOps API at `https://app.blocksecops.local/api/v1`

---

## Quick Reference

```bash
# Complete setup workflow
1. Create organization (requires Enterprise tier)
2. Get available roles for the organization
3. Add members to organization (assign roles)
4. Create teams within organization
5. Add members to teams
6. Create projects
7. Grant team access to projects
```

---

## Permission Matrix

| Action | Required Permission | Who Can Perform | API Endpoint |
|--------|---------------------|-----------------|--------------|
| Create Organization | Enterprise tier | Any enterprise user | `POST /organizations` |
| View Organization | Member of org | Any org member | `GET /organizations/{id}` |
| Update Organization | Owner only | Organization owner | `PUT /organizations/{id}` |
| Delete Organization | Owner only | Organization owner | `DELETE /organizations/{id}` |
| Get Available Roles | Member of org | Any org member | `GET /roles` (convenience) or `GET /organizations/{id}/roles` |
| List Org Members | Member of org | Any org member | `GET /organizations/current/users` (convenience) or `GET /organizations/{id}/members` |
| Add Org Member | **See Known Issue #1** | Currently: Any member | `POST /organizations/current/users` (convenience) or `POST /organizations/{id}/members` |
| Update Member Role | Owner only | Organization owner | `PATCH /organizations/current/users/{user_id}` (convenience) or `PUT /organizations/{id}/members/{user_id}` |
| Remove Member | Owner or Admin | Owner/Admin role | `DELETE /organizations/current/users/{user_id}` (convenience) or `DELETE /organizations/{id}/members/{user_id}` |
| Create Team | Owner or Admin | Owner/Admin role | `POST /organizations/{id}/teams` |
| Add Team Member | Owner or Admin | Owner/Admin role | `POST /teams/{id}/members` |
| Remove Team Member | Owner or Admin | Owner/Admin role | `DELETE /teams/{id}/members/{user_id}` |
| Create Project | Any authenticated | Project creator becomes owner | `POST /projects` |
| Grant Project Access | Project owner | Only project owner | `POST /projects/{id}/access` |

---

## System Roles Reference

BlockSecOps defines 5 organization roles with specific permissions:

| Role | Key Permissions | Use Case |
|------|-----------------|----------|
| **Owner** | Full access, can delete org, manage all members | Organization creator, primary admin |
| **Admin** | Manage members, teams, full read/write | Department heads, senior managers |
| **Developer** | Create/manage contracts, scans, vulnerabilities | Active development team members |
| **Auditor** | Read-only access to all resources | Compliance, security reviewers |
| **Guest** | Minimal read access | External stakeholders, limited viewers |

### Role Permission Details

**Owner/Admin includes:**
- `org.*` - Full organization management
- `members.*` - Member management
- `roles.*` - Role management
- `contracts.*`, `scans.*`, `vulnerabilities.*` - Full resource access

**Developer includes:**
- `org.read`, `members.read` - Read org info
- `contracts.create/read/update/delete` - Contract management
- `scans.create/read/update/delete` - Scan management
- `vulnerabilities.read/update` - Vulnerability handling

**Auditor includes:**
- `org.read`, `members.read` - Read org info
- `contracts.read`, `scans.read`, `vulnerabilities.read` - Read-only access

**Guest includes:**
- `org.read` - Basic organization visibility

---

## Step 1: Create Organization

Organizations require an Enterprise tier subscription.

### API Request

```bash
curl -X POST "https://app.blocksecops.local/api/v1/organizations" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Acme Security Team",
    "description": "Smart contract security organization for Acme Corp"
  }'
```

### Expected Response

```json
{
  "id": "org_abc123",
  "name": "Acme Security Team",
  "description": "Smart contract security organization for Acme Corp",
  "owner_id": "user_xyz789",
  "created_at": "2026-01-23T10:00:00Z",
  "updated_at": "2026-01-23T10:00:00Z"
}
```

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| 403 Forbidden | Not Enterprise tier | Upgrade subscription |
| 409 Conflict | Organization name exists | Choose unique name |
| 422 Validation Error | Invalid input | Check name/description format |

---

## Step 2: Get Available Roles

Before adding members, retrieve the available roles for your organization.

### API Request (Convenience Endpoint)

Use the `/roles` convenience endpoint to get roles for your current organization:

```bash
curl -X GET "https://app.blocksecops.local/api/v1/roles" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

### API Request (Specific Organization)

Or specify the organization ID explicitly:

```bash
curl -X GET "https://app.blocksecops.local/api/v1/organizations/{org_id}/roles" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

### Expected Response

```json
{
  "roles": [
    {
      "name": "owner",
      "description": "Full organization access",
      "permissions": ["org.*", "members.*", "roles.*", "contracts.*", "scans.*", "vulnerabilities.*"]
    },
    {
      "name": "admin",
      "description": "Administrative access",
      "permissions": ["org.read", "org.update", "members.*", "contracts.*", "scans.*", "vulnerabilities.*"]
    },
    {
      "name": "developer",
      "description": "Development team member",
      "permissions": ["org.read", "members.read", "contracts.*", "scans.*", "vulnerabilities.read", "vulnerabilities.update"]
    },
    {
      "name": "auditor",
      "description": "Read-only audit access",
      "permissions": ["org.read", "members.read", "contracts.read", "scans.read", "vulnerabilities.read"]
    },
    {
      "name": "guest",
      "description": "Limited guest access",
      "permissions": ["org.read"]
    }
  ]
}
```

---

## Step 3: Add Members to Organization

Add existing users to your organization with a specified role.

> **Important:** Users must already have accounts in BlockSecOps. See [Known Issue #3](#issue-3-no-user-invite-flow-for-external-users) for limitations.

### API Request (Convenience Endpoint)

Use the convenience endpoint to add members to your current organization:

```bash
curl -X POST "https://app.blocksecops.local/api/v1/organizations/current/users" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "role_id": "uuid-of-developer-role"
  }'
```

> **Note:** The convenience endpoint uses `email` and `role_id` (UUID) instead of `user_id` and `role` (name).

### API Request (Specific Organization)

Or specify the organization ID explicitly:

```bash
curl -X POST "https://app.blocksecops.local/api/v1/organizations/{org_id}/members" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user_def456",
    "role": "developer"
  }'
```

### Expected Response

```json
{
  "organization_id": "org_abc123",
  "user_id": "user_def456",
  "role": "developer",
  "status": "active",
  "created_at": "2026-01-23T10:30:00Z"
}
```

### Adding Multiple Members

For bulk operations, make sequential API calls:

```bash
# Add developer
curl -X POST "https://app.blocksecops.local/api/v1/organizations/{org_id}/members" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "user_001", "role": "developer"}'

# Add auditor
curl -X POST "https://app.blocksecops.local/api/v1/organizations/{org_id}/members" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "user_002", "role": "auditor"}'

# Add admin
curl -X POST "https://app.blocksecops.local/api/v1/organizations/{org_id}/members" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "user_003", "role": "admin"}'
```

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| 404 Not Found | User doesn't exist | Ensure user has registered account |
| 409 Conflict | User already member | Check existing membership |
| 422 Validation Error | Invalid role | Use valid role name from Step 2 |

---

## Step 4: Create Teams

Teams provide sub-groupings within organizations for project collaboration.

### API Request

```bash
curl -X POST "https://app.blocksecops.local/api/v1/organizations/{org_id}/teams" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "DeFi Audit Team",
    "description": "Team focused on DeFi protocol security audits"
  }'
```

### Expected Response

```json
{
  "id": "team_xyz789",
  "name": "DeFi Audit Team",
  "description": "Team focused on DeFi protocol security audits",
  "organization_id": "org_abc123",
  "created_at": "2026-01-23T11:00:00Z"
}
```

### Team Naming Conventions

| Team Type | Suggested Naming | Example |
|-----------|------------------|---------|
| Project-based | `{Project}-Team` | `Uniswap-Audit-Team` |
| Function-based | `{Function}-Team` | `Smart-Contract-Review-Team` |
| Client-based | `{Client}-Team` | `Acme-Corp-Team` |

---

## Step 5: Add Members to Teams

Add organization members to specific teams.

> **Note:** Users must already be organization members before being added to teams.

### API Request

```bash
curl -X POST "https://app.blocksecops.local/api/v1/teams/{team_id}/members" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user_def456",
    "role": "member"
  }'
```

### Team Roles

| Role | Permissions | Notes |
|------|-------------|-------|
| `lead` | Team leadership | See [Known Issue #2](#issue-2-team-leads-cannot-manage-their-teams) |
| `member` | Standard team member | Default role |

### Expected Response

```json
{
  "team_id": "team_xyz789",
  "user_id": "user_def456",
  "role": "member",
  "joined_at": "2026-01-23T11:30:00Z"
}
```

---

## Step 6: Create Projects

Projects contain smart contracts and scan configurations.

> **Note:** Projects are owned by individual users, not organizations. See [Known Issue #4](#issue-4-projects-are-user-owned-not-organization-owned).

### API Request

```bash
curl -X POST "https://app.blocksecops.local/api/v1/projects" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Uniswap V4 Audit",
    "description": "Security audit for Uniswap V4 contracts",
    "blockchain": "ethereum"
  }'
```

### Expected Response

```json
{
  "id": "proj_abc123",
  "name": "Uniswap V4 Audit",
  "description": "Security audit for Uniswap V4 contracts",
  "blockchain": "ethereum",
  "user_id": "user_xyz789",
  "created_at": "2026-01-23T12:00:00Z"
}
```

---

## Step 7: Grant Team Access to Projects

Grant team members access to specific projects.

### API Request

```bash
curl -X POST "https://app.blocksecops.local/api/v1/projects/{project_id}/access" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user_def456",
    "access_level": "write"
  }'
```

### Access Levels

| Level | Permissions |
|-------|-------------|
| `owner` | Full control, can grant access to others |
| `write` | Create/edit contracts, run scans |
| `read` | View-only access |

### Expected Response

```json
{
  "project_id": "proj_abc123",
  "user_id": "user_def456",
  "access_level": "write",
  "granted_at": "2026-01-23T12:30:00Z",
  "granted_by": "user_xyz789"
}
```

### Granting Access to Entire Team

Currently, project access must be granted individually to each user. To grant access to all team members:

```bash
# Get team members
TEAM_MEMBERS=$(curl -s "https://app.blocksecops.local/api/v1/teams/{team_id}/members" \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq -r '.[].user_id')

# Grant access to each member
for USER_ID in $TEAM_MEMBERS; do
  curl -X POST "https://app.blocksecops.local/api/v1/projects/{project_id}/access" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"user_id\": \"$USER_ID\", \"access_level\": \"write\"}"
done
```

---

## Verification Procedures

### Verify Organization Setup

```bash
# Get organization details
curl -X GET "https://app.blocksecops.local/api/v1/organizations/{org_id}" \
  -H "Authorization: Bearer $ACCESS_TOKEN"

# List all organization members (convenience endpoint)
curl -X GET "https://app.blocksecops.local/api/v1/organizations/current/users" \
  -H "Authorization: Bearer $ACCESS_TOKEN"

# List available roles (convenience endpoint)
curl -X GET "https://app.blocksecops.local/api/v1/roles" \
  -H "Authorization: Bearer $ACCESS_TOKEN"

# Or use explicit organization ID
curl -X GET "https://app.blocksecops.local/api/v1/organizations/{org_id}/members" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

### Verify Team Setup

```bash
# List organization teams
curl -X GET "https://app.blocksecops.local/api/v1/organizations/{org_id}/teams" \
  -H "Authorization: Bearer $ACCESS_TOKEN"

# Get team members
curl -X GET "https://app.blocksecops.local/api/v1/teams/{team_id}/members" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

### Verify Project Access

```bash
# List project access grants
curl -X GET "https://app.blocksecops.local/api/v1/projects/{project_id}/access" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

---

## Rollback Procedures

### Remove Member from Organization

```bash
curl -X DELETE "https://app.blocksecops.local/api/v1/organizations/{org_id}/members/{user_id}" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

### Remove Member from Team

```bash
curl -X DELETE "https://app.blocksecops.local/api/v1/teams/{team_id}/members/{user_id}" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

### Revoke Project Access

```bash
curl -X DELETE "https://app.blocksecops.local/api/v1/projects/{project_id}/access/{user_id}" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

### Delete Team

```bash
curl -X DELETE "https://app.blocksecops.local/api/v1/teams/{team_id}" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

### Delete Organization

> **Warning:** This permanently deletes the organization and all associated teams.

```bash
curl -X DELETE "https://app.blocksecops.local/api/v1/organizations/{org_id}" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

---

## Troubleshooting

### "User not found" when adding member

**Cause:** The user doesn't have a BlockSecOps account.

**Solution:**
1. User must first register at BlockSecOps
2. Alternatively, use the team invite system (separate flow)
3. Verify user_id is correct: `GET /users?email={email}`

### "Forbidden" when creating organization

**Cause:** User doesn't have Enterprise tier subscription.

**Solution:**
1. Check subscription tier: `GET /users/me`
2. Upgrade to Enterprise tier if needed
3. Contact support for enterprise trial

### "Forbidden" when managing teams

**Cause:** User is not Owner or Admin of the organization.

**Solution:**
1. Verify role: `GET /organizations/{org_id}/members/{user_id}`
2. Request Admin role from organization Owner
3. Note: Team Lead role does NOT grant management permissions (see Known Issue #2)

### Member added but can't access projects

**Cause:** Organization membership doesn't automatically grant project access.

**Solution:**
1. Project owner must explicitly grant access (Step 7)
2. Verify project access: `GET /projects/{project_id}/access`

### Team member can't see team resources

**Cause:** Team membership is separate from project access.

**Solution:**
1. Grant project access to individual team members
2. Check both team membership and project access

---

## Known Issues

### Issue 1: Missing Permission Enforcement on `add_member` Endpoint (HIGH SEVERITY)

**Status:** Open
**Location:** `blocksecops-api-service/src/presentation/api/v1/endpoints/organizations.py:775`

**Problem:** The `add_member` endpoint only checks organization membership, NOT owner status or role permissions.

```python
# Line 775 - Only checks membership, not owner!
await get_organization_with_ownership_check(db, organization_id, current_user.id)
# require_owner=False by default, so ANY member can add members!
```

**Impact:** Any active organization member (including Guest, Auditor, Developer roles) can add new members to the organization. This bypasses the intended Owner-only restriction.

**Workaround:** Limit organization membership to trusted users only until this is fixed.

**Recommended Fix:** Change line 775 to:
```python
await get_organization_with_ownership_check(db, organization_id, current_user.id, require_owner=True)
```

---

### Issue 2: Team Leads Cannot Manage Their Teams

**Status:** Open
**Location:** `blocksecops-api-service/src/presentation/api/v1/endpoints/teams.py`

**Problem:** Team leads (`role: "lead"`) have no special permissions. They cannot:
- Add members to their own team
- Remove members from their team
- Update team settings

All team management requires organization-level Admin role.

**Workaround:** Grant team leads the Admin role at the organization level, or have an Admin perform team management tasks on their behalf.

---

### Issue 3: No User Invite Flow for External Users

**Status:** By Design
**Location:** `blocksecops-api-service/src/presentation/api/v1/endpoints/organizations.py:793-797`

**Problem:** Users must already exist in the system before being added to organizations.

```python
if not user:
    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="User not found",
    )
```

**Workaround:**
1. Have users self-register first at BlockSecOps
2. Use the separate team invite system (`TeamInviteModel`) which sends email invitations

---

### Issue 4: Projects are User-Owned, Not Organization-Owned

**Status:** By Design
**Location:** `blocksecops-api-service/src/infrastructure/database/models.py:427-460`

**Problem:** Projects are tied to individual users (`user_id`), not organizations. When a project owner leaves:
- Ownership transfer is unclear
- Project access may be disrupted

**Workaround:**
1. Create projects with a service account that won't leave
2. Grant write access to multiple team members
3. Document project ownership in external tracking

---

## Checklist

### Organization Setup
- [ ] Enterprise tier subscription confirmed
- [ ] Organization created successfully
- [ ] Organization name and description set appropriately

### Member Management
- [ ] Available roles retrieved
- [ ] All required members added to organization
- [ ] Appropriate roles assigned to each member
- [ ] Member list verified

### Team Setup
- [ ] Teams created for each working group
- [ ] Team members added from organization members
- [ ] Team lead(s) designated (note: limited permissions)

### Project Setup
- [ ] Projects created by designated owner
- [ ] Project access granted to all team members
- [ ] Access levels appropriate for each member

### Verification
- [ ] All members can access organization
- [ ] All team members can access their teams
- [ ] All project members can access projects
- [ ] Permissions verified for each role

---

## Related Documentation

- [API Reference](../api/README.md)
- [Authentication Guide](../guides/authentication.md)
- [Deploy New Image Playbook](./deploy-new-image.md)
- [Troubleshooting Guide](../Troubleshooting/README.md)
