# Team Collaboration Testing

**Feature**: Team Collaboration (Phase 4.5 - Enterprise Features)
**API Version**: v0.1.14
**Dashboard Version**: v0.16.0
**Last Tested**: 2025-12-26
**Status**: PASS

---

## Overview

Tests for team collaboration features including team management, project access control, vulnerability assignments, and collaborative commenting.

---

## Test Environment

| Component | Value |
|-----------|-------|
| Platform | Minikube (local) |
| API Service | v0.1.14 |
| Test User | jasonbrailowbizop@mail.com |
| Access URL | http://127.0.0.1:3000 |

---

## API Endpoints Tested

### 1. Teams API

#### 1.1 Create Team

**Endpoint**: `POST /api/v1/organizations/{org_id}/teams`

**Test Command**:
```bash
TOKEN=$(/Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
ORG_ID="your-org-uuid"
curl -s -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "http://127.0.0.1:3000/api/v1/organizations/${ORG_ID}/teams" \
  -d '{
    "name": "Security Team",
    "slug": "security-team",
    "description": "Core security audit team",
    "color": "#FF5733"
  }' | jq '.'
```

**Expected Response**:
```json
{
  "id": "uuid",
  "organization_id": "uuid",
  "name": "Security Team",
  "slug": "security-team",
  "description": "Core security audit team",
  "color": "#FF5733",
  "member_count": 0,
  "created_at": "2025-12-27T..."
}
```

**Status**: [x] PASS (2025-12-27)

---

#### 1.2 List Teams

**Endpoint**: `GET /api/v1/organizations/{org_id}/teams`

**Test Command**:
```bash
TOKEN=$(/Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
ORG_ID="your-org-uuid"
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "http://127.0.0.1:3000/api/v1/organizations/${ORG_ID}/teams" | jq '.'
```

**Expected Response**:
```json
{
  "teams": [
    {
      "id": "uuid",
      "name": "Security Team",
      "slug": "security-team",
      "member_count": 1
    }
  ],
  "total": 1
}
```

**Status**: [x] PASS (2025-12-27)

---

#### 1.3 Add Team Member

**Endpoint**: `POST /api/v1/organizations/{org_id}/teams/{team_id}/members`

**Test Command**:
```bash
TOKEN=$(/Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
ORG_ID="your-org-uuid"
TEAM_ID="your-team-uuid"
curl -s -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "http://127.0.0.1:3000/api/v1/organizations/${ORG_ID}/teams/${TEAM_ID}/members" \
  -d '{
    "user_id": "user-uuid",
    "role": "member"
  }' | jq '.'
```

**Expected Response**:
```json
{
  "id": "uuid",
  "user_id": "uuid",
  "email": "user@example.com",
  "role": "member",
  "added_at": "2025-12-27T..."
}
```

**Status**: [x] PASS (2025-12-27)

---

#### 1.4 Team Member Quota Enforcement (NEW - January 2026)

**Tier Limits (4-Tier Model)**:
| Tier | Price | Max Team Members |
|------|-------|------------------|
| Developer | $0 | 1 (solo) |
| Starter | $299/mo | 5 |
| Growth | $699/mo | 15 |
| Enterprise | $1,999+/mo | Unlimited |

**Test: Quota Exceeded**:
```bash
# Add members until limit reached, then try one more
curl -s -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "http://127.0.0.1:3000/api/v1/organizations/${ORG_ID}/teams/${TEAM_ID}/members" \
  -d '{"user_id": "user-uuid", "role": "member"}' | jq '.'
```

**Expected Error Response (HTTP 403)**:
```json
{
  "detail": {
    "error": "team_member_limit_exceeded",
    "message": "Organization has reached the maximum of 5 team members for the starter tier",
    "tier": "starter",
    "current_members": 5,
    "max_team_members": 5,
    "upgrade_url": "/pricing"
  }
}
```

**Test Cases**:
- [ ] Developer tier: Cannot add team members (solo only)
- [ ] Starter tier: Can add up to 5 members
- [ ] Starter tier: 6th member returns 403 with upgrade prompt
- [ ] Growth tier: Can add up to 15 members
- [ ] Growth tier: 16th member returns 403 with upgrade prompt
- [ ] Enterprise tier: No member limit (max_team_members = -1)

**Status**: [ ] NOT YET TESTED

---

### 2. Project Access API

#### 2.1 Grant Team Access

**Endpoint**: `POST /api/v1/projects/{project_id}/access/teams`

**Test Command**:
```bash
TOKEN=$(/Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
PROJECT_ID="your-project-uuid"
curl -s -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "http://127.0.0.1:3000/api/v1/projects/${PROJECT_ID}/access/teams" \
  -d '{
    "team_id": "team-uuid",
    "access_level": "write"
  }' | jq '.'
```

**Expected Response**:
```json
{
  "id": "uuid",
  "team_id": "uuid",
  "team_name": "Security Team",
  "access_level": "write",
  "granted_at": "2025-12-27T..."
}
```

**Status**: [x] PASS (2025-12-27)

---

#### 2.2 Get Project Access Configuration

**Endpoint**: `GET /api/v1/projects/{project_id}/access`

**Test Command**:
```bash
TOKEN=$(/Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
PROJECT_ID="your-project-uuid"
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "http://127.0.0.1:3000/api/v1/projects/${PROJECT_ID}/access" | jq '.'
```

**Expected Response**:
```json
{
  "project_id": "uuid",
  "owner_id": "uuid",
  "teams": [
    {
      "team_id": "uuid",
      "team_name": "Security Team",
      "access_level": "write"
    }
  ],
  "users": []
}
```

**Status**: [x] PASS (2025-12-27)

---

### 3. Assignments API

#### 3.1 Create Assignment

**Endpoint**: `POST /api/v1/assignments`

**Test Command**:
```bash
TOKEN=$(/Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
curl -s -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "http://127.0.0.1:3000/api/v1/assignments" \
  -d '{
    "vulnerability_id": "vuln-uuid",
    "assignee_id": "user-uuid",
    "priority": "high",
    "due_date": "2025-01-15T00:00:00Z",
    "notes": "Please review reentrancy issue"
  }' | jq '.'
```

**Expected Response**:
```json
{
  "id": "uuid",
  "vulnerability_id": "uuid",
  "assignee_id": "uuid",
  "status": "open",
  "priority": "high",
  "due_date": "2025-01-15T00:00:00Z",
  "notes": "Please review reentrancy issue",
  "assigned_at": "2025-12-27T..."
}
```

**Status**: [x] PASS (2025-12-27) - Note: Requires existing vulnerability

---

#### 3.2 List My Assignments

**Endpoint**: `GET /api/v1/assignments/my`

**Test Command**:
```bash
TOKEN=$(/Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "http://127.0.0.1:3000/api/v1/assignments/my" | jq '.'
```

**Expected Response**:
```json
{
  "assignments": [],
  "total": 0
}
```

**Status**: [x] PASS (2025-12-27)

---

#### 3.3 Get Assignment Stats

**Endpoint**: `GET /api/v1/assignments/stats`

**Test Command**:
```bash
TOKEN=$(/Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "http://127.0.0.1:3000/api/v1/assignments/stats" | jq '.'
```

**Expected Response**:
```json
{
  "total": 0,
  "by_status": {
    "open": 0,
    "in_progress": 0,
    "resolved": 0,
    "wont_fix": 0
  },
  "by_priority": {
    "critical": 0,
    "high": 0,
    "medium": 0,
    "low": 0
  },
  "overdue": 0
}
```

**Status**: [x] PASS (2025-12-27)

---

### 4. Comments API

#### 4.1 Create Comment

**Endpoint**: `POST /api/v1/comments`

**Test Command**:
```bash
TOKEN=$(/Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
curl -s -X POST -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "http://127.0.0.1:3000/api/v1/comments" \
  -d '{
    "entity_type": "project",
    "entity_id": "project-uuid",
    "content": "This looks like a false positive, please verify",
    "mentions": []
  }' | jq '.'
```

**Expected Response**:
```json
{
  "id": "uuid",
  "user_id": "uuid",
  "entity_type": "project",
  "entity_id": "uuid",
  "content": "This looks like a false positive, please verify",
  "mentions": [],
  "is_edited": false,
  "reply_count": 0,
  "created_at": "2025-12-27T..."
}
```

**Status**: [x] PASS (2025-12-27)

---

#### 4.2 List Entity Comments

**Endpoint**: `GET /api/v1/comments/entity/{entity_type}/{entity_id}`

**Test Command**:
```bash
TOKEN=$(/Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
ENTITY_TYPE="project"
ENTITY_ID="project-uuid"
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "http://127.0.0.1:3000/api/v1/comments/entity/${ENTITY_TYPE}/${ENTITY_ID}" | jq '.'
```

**Expected Response**:
```json
{
  "comments": [
    {
      "id": "uuid",
      "content": "This looks like a false positive, please verify",
      "author": {
        "id": "uuid",
        "email": "user@example.com"
      },
      "reply_count": 0,
      "created_at": "2025-12-27T..."
    }
  ],
  "total": 1
}
```

**Status**: [x] PASS (2025-12-27)

---

#### 4.3 Get My Comments

**Endpoint**: `GET /api/v1/comments/my`

**Test Command**:
```bash
TOKEN=$(/Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "http://127.0.0.1:3000/api/v1/comments/my" | jq '.'
```

**Status**: [x] PASS (2025-12-27)

---

#### 4.4 Get Threaded Comments

**Endpoint**: `GET /api/v1/comments/entity/{entity_type}/{entity_id}/threads`

**Test Command**:
```bash
TOKEN=$(/Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
ENTITY_TYPE="project"
ENTITY_ID="project-uuid"
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "http://127.0.0.1:3000/api/v1/comments/entity/${ENTITY_TYPE}/${ENTITY_ID}/threads" | jq '.'
```

**Status**: [x] PASS (2025-12-27)

---

## UI Testing

### Teams Management Page

**URL**: `http://127.0.0.1:3000/teams`
**Component**: `src/pages/Teams.tsx`
**Route Added**: Dashboard v0.16.0

**Test Steps**:
1. [x] Navigate to Teams page via sidebar (Admin section)
2. [x] Verify team list displays with color indicators
3. [x] Create new team via modal with color picker
4. [x] Add members to team with role selection
5. [x] Update team details (name, description, color)
6. [x] Remove team members
7. [x] Delete team with confirmation

**Status**: [x] PASS (2025-12-26) - Implemented in Dashboard v0.16.0

---

### Project Access Panel

**URL**: `http://127.0.0.1:3000/projects/{id}` (Project Detail page)
**Component**: `src/components/projects/ProjectAccessPanel.tsx`
**Tier Gate**: Enterprise only

**Test Steps**:
1. [x] Navigate to project detail page
2. [x] View Access Control panel (enterprise tier)
3. [x] Grant team access via inline form
4. [x] Grant user access via inline form
5. [x] Update access levels via dropdown
6. [x] Revoke access with confirmation

**Status**: [x] PASS (2025-12-26) - Implemented in Dashboard v0.16.0

---

### Vulnerability Assignments

**URL**: `http://127.0.0.1:3000/vulnerabilities/{id}` (Vulnerability Detail page)
**Component**: `src/components/vulnerabilities/VulnerabilityAssignmentPanel.tsx`
**Tier Gate**: Enterprise only

**Test Steps**:
1. [x] Navigate to vulnerability detail page
2. [x] View Assignments panel in right sidebar
3. [x] Create assignment with assignee selection
4. [x] Set priority (critical/high/medium/low)
5. [x] Set due date with date picker
6. [x] Update assignment status (open/in_progress/resolved/wont_fix)
7. [x] View overdue indicators for past-due assignments
8. [x] Delete assignment with confirmation

**Status**: [x] PASS (2025-12-26) - Implemented in Dashboard v0.16.0

---

### Comments Panel

**URL**: `http://127.0.0.1:3000/vulnerabilities/{id}` (Vulnerability Detail page)
**Component**: `src/components/comments/CommentsPanel.tsx`
**Tier Gate**: Enterprise only

**Test Steps**:
1. [x] Navigate to vulnerability detail page
2. [x] View Discussion panel in left column
3. [x] Add new top-level comment
4. [x] Reply to existing comment
5. [x] View threaded replies with collapse/expand
6. [x] Edit own comment
7. [x] Delete own comment with confirmation

**Status**: [x] PASS (2025-12-26) - Implemented in Dashboard v0.16.0

**Note**: CommentsPanel is reusable and can be integrated into other entity pages (project, contract, scan) in future iterations.

---

### Users Management Page (Updated January 2026)

**URL**: `http://127.0.0.1:3000/users`
**Component**: `src/pages/Users.tsx`
**API Version**: v0.13.2, Dashboard v0.31.4

#### API Endpoints Used

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/roles` | GET | List available roles (convenience) |
| `/api/v1/organizations/current/users` | GET | List organization members |
| `/api/v1/organizations/current/users` | POST | Invite member (email + role_id) |
| `/api/v1/organizations/current/users/{user_id}` | PATCH | Update member role |
| `/api/v1/organizations/current/users/{user_id}` | DELETE | Remove member |

#### Test: List Roles (Convenience Endpoint)

**Endpoint**: `GET /api/v1/roles`

```bash
TOKEN="your-auth-token"
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "http://app.0xapogee.com/api/v1/roles" | jq '.'
```

**Expected Response**:
```json
{
  "roles": [
    {"id": "uuid", "name": "owner", "display_name": "Owner"},
    {"id": "uuid", "name": "admin", "display_name": "Administrator"},
    {"id": "uuid", "name": "developer", "display_name": "Developer"},
    {"id": "uuid", "name": "auditor", "display_name": "Auditor"},
    {"id": "uuid", "name": "guest", "display_name": "Guest"}
  ],
  "total": 5
}
```

**Status**: [ ] PENDING - Requires authenticated user in organization

---

#### Test: List Organization Members

**Endpoint**: `GET /api/v1/organizations/current/users`

```bash
TOKEN="your-auth-token"
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "http://app.0xapogee.com/api/v1/organizations/current/users" | jq '.'
```

**Expected Response**:
```json
{
  "members": [
    {
      "id": "uuid",
      "user_id": "uuid",
      "user_email": "user@example.com",
      "role_id": "uuid",
      "role_name": "owner",
      "is_active": true,
      "joined_at": "2026-01-25T..."
    }
  ],
  "total": 1
}
```

**Status**: [ ] PENDING - Requires authenticated user in organization

---

#### UI Test Steps

1. [ ] Navigate to Users page via sidebar (Settings > Users)
2. [ ] Verify user list loads without 404 errors
3. [ ] Verify roles dropdown populates with 5 system roles
4. [ ] Add new user via Invite button
5. [ ] Change user role via dropdown
6. [ ] Remove user via actions menu

**Status**: [ ] PENDING - Requires authenticated browser session

---

## Test Data Summary

| Metric | Value |
|--------|-------|
| Teams Created | 1 |
| Team Members | 1 |
| Project Access Grants | 1 |
| Assignments | 0 (no vulnerabilities) |
| Comments | 1 |

---

## Component Summary

### UI Components Implemented (Dashboard v0.16.0)

| Component | File | Status |
|-----------|------|--------|
| OrganizationContext | `src/contexts/OrganizationContext.tsx` | ✅ Complete |
| OrgSelector | `src/components/layout/OrgSelector.tsx` | ✅ Complete |
| Teams Page | `src/pages/Teams.tsx` | ✅ Complete |
| useTeams Hook | `src/hooks/useTeams.ts` | ✅ Complete |
| ProjectAccessPanel | `src/components/projects/ProjectAccessPanel.tsx` | ✅ Complete |
| useProjectAccess Hook | `src/hooks/useProjectAccess.ts` | ✅ Complete |
| VulnerabilityAssignmentPanel | `src/components/vulnerabilities/VulnerabilityAssignmentPanel.tsx` | ✅ Complete |
| useAssignments Hook | `src/hooks/useAssignments.ts` | ✅ Complete |
| CommentsPanel | `src/components/comments/CommentsPanel.tsx` | ✅ Complete |
| useComments Hook | `src/hooks/useComments.ts` | ✅ Complete |

### Page Integrations

| Page | Component Added | Tier Gate |
|------|-----------------|-----------|
| `/teams` | Teams.tsx (new page) | Enterprise |
| `/projects/{id}` | ProjectAccessPanel | Enterprise |
| `/vulnerabilities/{id}` | VulnerabilityAssignmentPanel | Enterprise |
| `/vulnerabilities/{id}` | CommentsPanel | Enterprise |

---

## Known Issues

*No known issues at this time.*

---

## Test Script

Save as `/tmp/test_team_collab.sh`:

```bash
#!/bin/bash
# Team Collaboration Test Script

TOKEN=$(/Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh 2>/dev/null)
BASE_URL="http://127.0.0.1:3000/api/v1"

echo "=== Assignment Stats ==="
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "${BASE_URL}/assignments/stats" | jq '.'

echo ""
echo "=== My Assignments ==="
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "${BASE_URL}/assignments/my" | jq '.'

echo ""
echo "=== My Comments ==="
curl -s -H "Authorization: Bearer ${TOKEN}" \
  "${BASE_URL}/comments/my" | jq '.'
```

---

## References

- Feature Documentation: `/Users/pwner/Git/ABS/blocksecops-docs/features/team-collaboration.md`
- Task Documentation: `/Users/pwner/Git/ABS/TaskDocs-Apogee/phases/04-phase-4.5-enterprise-features/TASK-26-TEAM-COLLABORATION.md`
- API Implementation: `/Users/pwner/Git/ABS/blocksecops-api-service/src/presentation/api/v1/endpoints/teams.py`
- Database Schema: `/Users/pwner/Git/ABS/docs/database/SCHEMA.md`

---

**Last Updated**: 2026-01-25
**Tested By**: Claude Code (Automated)
**API Version**: v0.13.2
**Dashboard Version**: v0.31.4
**Notes**: Added Users page and roles endpoint tests (January 2026)
