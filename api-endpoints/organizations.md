# Organization Endpoints

All organization endpoints require authentication. Endpoints are prefixed with `/api/v1` unless otherwise noted.

---

## Organizations CRUD

### POST /api/v1/organizations

Create a new organization.

```bash
curl -X POST https://api.blocksecops.com/api/v1/organizations \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Acme Security",
    "description": "Smart contract security team"
  }'
```

**Response 201:**

```json
{
  "id": "org_xyz789",
  "name": "Acme Security",
  "description": "Smart contract security team",
  "owner_id": "usr_abc123",
  "created_at": "2026-02-14T12:00:00Z"
}
```

### GET /api/v1/organizations

List organizations the authenticated user belongs to.

```bash
curl -X GET https://api.blocksecops.com/api/v1/organizations \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "organizations": [
    {
      "id": "org_xyz789",
      "name": "Acme Security",
      "role": "owner",
      "member_count": 12,
      "plan_tier": "professional",
      "created_at": "2025-06-15T10:30:00Z"
    }
  ],
  "total": 1
}
```

### GET /api/v1/organizations/{id}

Retrieve a specific organization.

```bash
curl -X GET https://api.blocksecops.com/api/v1/organizations/org_xyz789 \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "id": "org_xyz789",
  "name": "Acme Security",
  "description": "Smart contract security team",
  "owner_id": "usr_abc123",
  "plan_tier": "professional",
  "member_count": 12,
  "settings": {
    "ai_opt_out": false,
    "default_scan_depth": "standard"
  },
  "created_at": "2025-06-15T10:30:00Z"
}
```

### PATCH /api/v1/organizations/{id}

Update an organization.

```bash
curl -X PATCH https://api.blocksecops.com/api/v1/organizations/org_xyz789 \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Acme Security Corp",
    "description": "Enterprise smart contract security"
  }'
```

**Response 200:** Returns the updated organization object.

### DELETE /api/v1/organizations/{id}

Delete an organization. Requires owner role.

```bash
curl -X DELETE https://api.blocksecops.com/api/v1/organizations/org_xyz789 \
  -H "Authorization: Bearer <token>"
```

**Response 204:** No content.

---

## Organization Users

### GET /api/v1/organizations/current/users

List users in the current organization.

```bash
curl -X GET https://api.blocksecops.com/api/v1/organizations/current/users \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "users": [
    {
      "id": "usr_abc123",
      "email": "jane@acme.com",
      "name": "Jane Doe",
      "role": "owner",
      "joined_at": "2025-06-15T10:30:00Z"
    }
  ],
  "total": 12
}
```

### POST /api/v1/organizations/current/users

Add a user to the current organization.

```bash
curl -X POST https://api.blocksecops.com/api/v1/organizations/current/users \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "bob@acme.com",
    "role_id": "role_member"
  }'
```

**Response 201:**

```json
{
  "id": "usr_def456",
  "email": "bob@acme.com",
  "role": "member",
  "joined_at": "2026-02-14T12:00:00Z"
}
```

### PATCH /api/v1/organizations/current/users/{id}

Update a user's role or details within the organization.

```bash
curl -X PATCH https://api.blocksecops.com/api/v1/organizations/current/users/usr_def456 \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "role_id": "role_admin"
  }'
```

**Response 200:** Returns the updated user object.

### DELETE /api/v1/organizations/current/users/{id}

Remove a user from the organization.

```bash
curl -X DELETE https://api.blocksecops.com/api/v1/organizations/current/users/usr_def456 \
  -H "Authorization: Bearer <token>"
```

**Response 204:** No content.

---

## Members

### GET /api/v1/organizations/{id}/members

List all members of an organization.

```bash
curl -X GET https://api.blocksecops.com/api/v1/organizations/org_xyz789/members \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "members": [
    {
      "id": "mem_001",
      "user_id": "usr_abc123",
      "email": "jane@acme.com",
      "name": "Jane Doe",
      "role": "owner",
      "status": "active",
      "joined_at": "2025-06-15T10:30:00Z"
    }
  ],
  "total": 12
}
```

### POST /api/v1/organizations/{id}/members

Add a member to the organization.

```bash
curl -X POST https://api.blocksecops.com/api/v1/organizations/org_xyz789/members \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "usr_ghi789",
    "role_id": "role_member"
  }'
```

**Response 201:** Returns the new member object.

### PATCH /api/v1/organizations/{id}/members/{member_id}

Update a member's role.

```bash
curl -X PATCH https://api.blocksecops.com/api/v1/organizations/org_xyz789/members/mem_001 \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "role_id": "role_admin"
  }'
```

**Response 200:** Returns the updated member object.

### DELETE /api/v1/organizations/{id}/members/{member_id}

Remove a member from the organization.

```bash
curl -X DELETE https://api.blocksecops.com/api/v1/organizations/org_xyz789/members/mem_001 \
  -H "Authorization: Bearer <token>"
```

**Response 204:** No content.

---

## Roles

### GET /api/v1/organizations/{id}/roles

List all roles defined for an organization.

```bash
curl -X GET https://api.blocksecops.com/api/v1/organizations/org_xyz789/roles \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "roles": [
    {
      "id": "role_owner",
      "name": "Owner",
      "permissions": ["*"],
      "is_system": true,
      "member_count": 1
    },
    {
      "id": "role_admin",
      "name": "Admin",
      "permissions": ["members.manage", "scans.manage", "settings.manage"],
      "is_system": true,
      "member_count": 3
    },
    {
      "id": "role_member",
      "name": "Member",
      "permissions": ["scans.create", "scans.read", "contracts.read"],
      "is_system": true,
      "member_count": 8
    }
  ],
  "total": 3
}
```

### POST /api/v1/organizations/{id}/roles

Create a custom role.

```bash
curl -X POST https://api.blocksecops.com/api/v1/organizations/org_xyz789/roles \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Auditor",
    "permissions": ["scans.read", "contracts.read", "vulnerabilities.read"]
  }'
```

**Response 201:**

```json
{
  "id": "role_custom_001",
  "name": "Auditor",
  "permissions": ["scans.read", "contracts.read", "vulnerabilities.read"],
  "is_system": false,
  "member_count": 0
}
```

### PATCH /api/v1/organizations/{id}/roles/{role_id}

Update a custom role.

```bash
curl -X PATCH https://api.blocksecops.com/api/v1/organizations/org_xyz789/roles/role_custom_001 \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "permissions": ["scans.read", "contracts.read", "vulnerabilities.read", "reports.read"]
  }'
```

**Response 200:** Returns the updated role object.

### DELETE /api/v1/organizations/{id}/roles/{role_id}

Delete a custom role. System roles cannot be deleted.

```bash
curl -X DELETE https://api.blocksecops.com/api/v1/organizations/org_xyz789/roles/role_custom_001 \
  -H "Authorization: Bearer <token>"
```

**Response 204:** No content.

---

## Teams

### POST /api/v1/organizations/{id}/teams

Create a team within an organization.

```bash
curl -X POST https://api.blocksecops.com/api/v1/organizations/org_xyz789/teams \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "DeFi Audit Team",
    "description": "Responsible for DeFi protocol audits"
  }'
```

**Response 201:**

```json
{
  "id": "team_001",
  "name": "DeFi Audit Team",
  "description": "Responsible for DeFi protocol audits",
  "member_count": 0,
  "created_at": "2026-02-14T12:00:00Z"
}
```

### GET /api/v1/organizations/{id}/teams

List all teams.

```bash
curl -X GET https://api.blocksecops.com/api/v1/organizations/org_xyz789/teams \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "teams": [
    {
      "id": "team_001",
      "name": "DeFi Audit Team",
      "description": "Responsible for DeFi protocol audits",
      "member_count": 5,
      "created_at": "2025-09-01T10:00:00Z"
    }
  ],
  "total": 2
}
```

### GET /api/v1/organizations/{id}/teams/{team_id}

Retrieve a specific team.

```bash
curl -X GET https://api.blocksecops.com/api/v1/organizations/org_xyz789/teams/team_001 \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "id": "team_001",
  "name": "DeFi Audit Team",
  "description": "Responsible for DeFi protocol audits",
  "members": [
    {
      "user_id": "usr_abc123",
      "name": "Jane Doe",
      "role": "lead"
    }
  ],
  "member_count": 5,
  "created_at": "2025-09-01T10:00:00Z"
}
```

### PATCH /api/v1/organizations/{id}/teams/{team_id}

Update a team.

```bash
curl -X PATCH https://api.blocksecops.com/api/v1/organizations/org_xyz789/teams/team_001 \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "DeFi Security Team"
  }'
```

**Response 200:** Returns the updated team object.

### DELETE /api/v1/organizations/{id}/teams/{team_id}

Delete a team.

```bash
curl -X DELETE https://api.blocksecops.com/api/v1/organizations/org_xyz789/teams/team_001 \
  -H "Authorization: Bearer <token>"
```

**Response 204:** No content.

### POST /api/v1/organizations/{id}/teams/{team_id}/members

Add a member to a team.

```bash
curl -X POST https://api.blocksecops.com/api/v1/organizations/org_xyz789/teams/team_001/members \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "usr_def456",
    "role": "member"
  }'
```

**Response 201:** Returns the team member object.

### GET /api/v1/organizations/{id}/teams/{team_id}/members

List team members.

```bash
curl -X GET https://api.blocksecops.com/api/v1/organizations/org_xyz789/teams/team_001/members \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "members": [
    {
      "user_id": "usr_abc123",
      "name": "Jane Doe",
      "email": "jane@acme.com",
      "role": "lead",
      "added_at": "2025-09-01T10:00:00Z"
    }
  ],
  "total": 5
}
```

### PATCH /api/v1/organizations/{id}/teams/{team_id}/members/{user_id}

Update a team member's role.

```bash
curl -X PATCH https://api.blocksecops.com/api/v1/organizations/org_xyz789/teams/team_001/members/usr_def456 \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "role": "lead"
  }'
```

**Response 200:** Returns the updated team member object.

### DELETE /api/v1/organizations/{id}/teams/{team_id}/members/{user_id}

Remove a member from a team.

```bash
curl -X DELETE https://api.blocksecops.com/api/v1/organizations/org_xyz789/teams/team_001/members/usr_def456 \
  -H "Authorization: Bearer <token>"
```

**Response 204:** No content.

---

## Invites

### POST /api/v1/organizations/{id}/invites

Create an invitation to join the organization.

```bash
curl -X POST https://api.blocksecops.com/api/v1/organizations/org_xyz789/invites \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "alice@example.com",
    "role_id": "role_member",
    "message": "Join our security team!"
  }'
```

**Response 201:**

```json
{
  "id": "invite_001",
  "email": "alice@example.com",
  "role_id": "role_member",
  "status": "pending",
  "token": "inv_token_xyz",
  "expires_at": "2026-02-21T12:00:00Z",
  "created_at": "2026-02-14T12:00:00Z"
}
```

### GET /api/v1/organizations/{id}/invites

List pending invitations.

```bash
curl -X GET https://api.blocksecops.com/api/v1/organizations/org_xyz789/invites \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "invites": [
    {
      "id": "invite_001",
      "email": "alice@example.com",
      "role_id": "role_member",
      "status": "pending",
      "expires_at": "2026-02-21T12:00:00Z",
      "created_at": "2026-02-14T12:00:00Z"
    }
  ],
  "total": 1
}
```

### DELETE /api/v1/organizations/{id}/invites/{invite_id}

Revoke a pending invitation.

```bash
curl -X DELETE https://api.blocksecops.com/api/v1/organizations/org_xyz789/invites/invite_001 \
  -H "Authorization: Bearer <token>"
```

**Response 204:** No content.

### GET /api/v1/invites/{token}

Retrieve invitation details by token (public endpoint, no auth required).

```bash
curl -X GET https://api.blocksecops.com/api/v1/invites/inv_token_xyz
```

**Response 200:**

```json
{
  "organization_name": "Acme Security",
  "role": "Member",
  "invited_by": "Jane Doe",
  "expires_at": "2026-02-21T12:00:00Z"
}
```

### POST /api/v1/invites/{token}

Accept an invitation.

```bash
curl -X POST https://api.blocksecops.com/api/v1/invites/inv_token_xyz \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "organization_id": "org_xyz789",
  "role": "member",
  "message": "Successfully joined Acme Security"
}
```

---

## Integrations

### POST /api/v1/organizations/{id}/integrations

Create a new integration.

```bash
curl -X POST https://api.blocksecops.com/api/v1/organizations/org_xyz789/integrations \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "github",
    "name": "GitHub - Acme Org",
    "config": {
      "installation_id": "12345678"
    }
  }'
```

**Response 201:**

```json
{
  "id": "intg_001",
  "type": "github",
  "name": "GitHub - Acme Org",
  "status": "connected",
  "created_at": "2026-02-14T12:00:00Z"
}
```

### GET /api/v1/organizations/{id}/integrations

List all integrations.

```bash
curl -X GET https://api.blocksecops.com/api/v1/organizations/org_xyz789/integrations \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "integrations": [
    {
      "id": "intg_001",
      "type": "github",
      "name": "GitHub - Acme Org",
      "status": "connected",
      "last_synced_at": "2026-02-14T10:00:00Z"
    },
    {
      "id": "intg_002",
      "type": "jira",
      "name": "Jira - Security Board",
      "status": "connected",
      "last_synced_at": "2026-02-14T09:30:00Z"
    }
  ],
  "total": 2
}
```

### GET /api/v1/organizations/{id}/integrations/{integration_id}

Retrieve integration details.

```bash
curl -X GET https://api.blocksecops.com/api/v1/organizations/org_xyz789/integrations/intg_001 \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "id": "intg_001",
  "type": "github",
  "name": "GitHub - Acme Org",
  "status": "connected",
  "config": {
    "installation_id": "12345678",
    "repositories_synced": 15
  },
  "last_synced_at": "2026-02-14T10:00:00Z",
  "created_at": "2026-02-14T12:00:00Z"
}
```

### PATCH /api/v1/organizations/{id}/integrations/{integration_id}

Update integration configuration.

```bash
curl -X PATCH https://api.blocksecops.com/api/v1/organizations/org_xyz789/integrations/intg_001 \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "GitHub - Acme Main Org"
  }'
```

**Response 200:** Returns the updated integration object.

### DELETE /api/v1/organizations/{id}/integrations/{integration_id}

Remove an integration.

```bash
curl -X DELETE https://api.blocksecops.com/api/v1/organizations/org_xyz789/integrations/intg_001 \
  -H "Authorization: Bearer <token>"
```

**Response 204:** No content.

### POST /api/v1/organizations/{id}/integrations/{integration_id}/reconnect

Reconnect a disconnected integration.

```bash
curl -X POST https://api.blocksecops.com/api/v1/organizations/org_xyz789/integrations/intg_001/reconnect \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "id": "intg_001",
  "status": "connected",
  "reconnected_at": "2026-02-14T12:00:00Z"
}
```

### GET /api/v1/organizations/{id}/integrations/{integration_id}/jira-mappings

Retrieve Jira severity-to-priority mappings for a Jira integration.

```bash
curl -X GET https://api.blocksecops.com/api/v1/organizations/org_xyz789/integrations/intg_002/jira-mappings \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "mappings": {
    "critical": "Highest",
    "high": "High",
    "medium": "Medium",
    "low": "Low",
    "informational": "Lowest"
  },
  "project_key": "SEC",
  "issue_type": "Bug"
}
```

### GET /api/v1/organizations/{id}/integrations/{integration_id}/repositories

List repositories available through a source control integration.

```bash
curl -X GET https://api.blocksecops.com/api/v1/organizations/org_xyz789/integrations/intg_001/repositories \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "repositories": [
    {
      "id": "repo_001",
      "name": "defi-protocol",
      "full_name": "acme-org/defi-protocol",
      "url": "https://github.com/acme-org/defi-protocol",
      "default_branch": "main",
      "language": "Solidity"
    }
  ],
  "total": 15
}
```

---

## Service Accounts

### POST /api/v1/organizations/{id}/service-accounts

Create a service account for programmatic access.

```bash
curl -X POST https://api.blocksecops.com/api/v1/organizations/org_xyz789/service-accounts \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "CI/CD Pipeline",
    "description": "Used by GitHub Actions for automated scanning",
    "scopes": ["scans:create", "scans:read", "contracts:read"]
  }'
```

**Response 201:**

```json
{
  "id": "sa_001",
  "name": "CI/CD Pipeline",
  "description": "Used by GitHub Actions for automated scanning",
  "scopes": ["scans:create", "scans:read", "contracts:read"],
  "api_key": "bso_sa_live_abc123def456...",
  "created_at": "2026-02-14T12:00:00Z"
}
```

> **Note:** The `api_key` is only returned once at creation time. Store it securely.

### GET /api/v1/organizations/{id}/service-accounts

List all service accounts.

```bash
curl -X GET https://api.blocksecops.com/api/v1/organizations/org_xyz789/service-accounts \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "service_accounts": [
    {
      "id": "sa_001",
      "name": "CI/CD Pipeline",
      "scopes": ["scans:create", "scans:read", "contracts:read"],
      "last_used_at": "2026-02-14T08:00:00Z",
      "created_at": "2026-02-14T12:00:00Z"
    }
  ],
  "total": 1
}
```

### GET /api/v1/organizations/{id}/service-accounts/{sa_id}

Retrieve a specific service account.

```bash
curl -X GET https://api.blocksecops.com/api/v1/organizations/org_xyz789/service-accounts/sa_001 \
  -H "Authorization: Bearer <token>"
```

**Response 200:** Returns the service account object (without `api_key`).

### PATCH /api/v1/organizations/{id}/service-accounts/{sa_id}

Update a service account.

```bash
curl -X PATCH https://api.blocksecops.com/api/v1/organizations/org_xyz789/service-accounts/sa_001 \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "CI/CD Pipeline - Production",
    "scopes": ["scans:create", "scans:read", "contracts:read", "reports:read"]
  }'
```

**Response 200:** Returns the updated service account object.

### DELETE /api/v1/organizations/{id}/service-accounts/{sa_id}

Delete a service account.

```bash
curl -X DELETE https://api.blocksecops.com/api/v1/organizations/org_xyz789/service-accounts/sa_001 \
  -H "Authorization: Bearer <token>"
```

**Response 204:** No content.

### POST /api/v1/organizations/{id}/service-accounts/{sa_id}/rotate

Rotate the API key for a service account.

```bash
curl -X POST https://api.blocksecops.com/api/v1/organizations/org_xyz789/service-accounts/sa_001/rotate \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "id": "sa_001",
  "api_key": "bso_sa_live_newkey789...",
  "previous_key_expires_at": "2026-02-15T12:00:00Z",
  "message": "New key generated. Previous key remains valid for 24 hours."
}
```

### GET /api/v1/organizations/{id}/service-accounts/{sa_id}/scopes

List available scopes for service accounts.

```bash
curl -X GET https://api.blocksecops.com/api/v1/organizations/org_xyz789/service-accounts/sa_001/scopes \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "available_scopes": [
    "contracts:read",
    "contracts:write",
    "scans:create",
    "scans:read",
    "vulnerabilities:read",
    "reports:read",
    "reports:export",
    "webhooks:manage"
  ]
}
```

---

## Settings

### PUT /api/v1/organizations/{id}/settings/ai-opt-out

Update the AI data usage opt-out setting for the organization.

```bash
curl -X PUT https://api.blocksecops.com/api/v1/organizations/org_xyz789/settings/ai-opt-out \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "opt_out": true
  }'
```

**Response 200:**

```json
{
  "ai_opt_out": true,
  "updated_at": "2026-02-14T12:00:00Z",
  "message": "Organization data will not be used for AI model training"
}
```

### GET /api/v1/organizations/{id}/settings/ai-status

Retrieve the current AI opt-out status.

```bash
curl -X GET https://api.blocksecops.com/api/v1/organizations/org_xyz789/settings/ai-status \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "ai_opt_out": true,
  "opted_out_at": "2026-02-14T12:00:00Z",
  "opted_out_by": "usr_abc123"
}
```
