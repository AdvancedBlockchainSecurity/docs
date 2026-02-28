# Team Collaboration Feature

**Version:** 1.1.0
**Status:** Active
**Added:** 2025-12-27
**Dashboard Version:** 0.16.0

## Overview

Team Collaboration enables organizations to work together on security audits through structured team management, granular project access control, vulnerability assignment tracking, and collaborative commenting.

## Features

### Team Management

Organizations can create and manage teams to group users for collaborative work.

**Capabilities:**
- Create teams with custom names, slugs, colors
- Add/remove team members
- Assign team roles (lead, member)
- View team membership

**Team Roles:**
| Role | Permissions |
|------|-------------|
| lead | Manage team members, represent team in decisions |
| member | Standard team participant |

### Project Access Control

Projects can be shared with teams or individual users with granular access levels.

**Access Levels:**
| Level | Permissions |
|-------|-------------|
| owner | Full control - manage access, delete project |
| write | Create/update contracts, scans, vulnerabilities |
| read | View project and all contents |

**Access Resolution:**
1. Project owner always has full access
2. Direct user grants take precedence
3. Team-based access aggregates across all teams
4. Highest access level wins

### Vulnerability Assignments

Track remediation work by assigning vulnerabilities to team members.

**Assignment Properties:**
- Assignee (required)
- Status: open, in_progress, resolved, wont_fix
- Priority: critical, high, medium, low
- Due date (optional)
- Notes (optional)

**Workflow:**
```
┌──────────────────────────────────────────────────────┐
│                                                      │
│   open ─────────> in_progress ─────────> resolved    │
│     │                   │                            │
│     │                   └──────────────> wont_fix    │
│     │                                        ▲       │
│     └────────────────────────────────────────┘       │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### Collaborative Comments

Add discussions to any entity in the system.

**Supported Entities:**
- Projects
- Contracts
- Scans
- Vulnerabilities

**Features:**
- Single-level threading (replies to top-level only)
- User mentions with UUID tracking
- Edit history tracking
- Reply counting

## API Endpoints

### Teams

```
POST   /api/v1/organizations/{org_id}/teams           # Create team
GET    /api/v1/organizations/{org_id}/teams           # List teams
GET    /api/v1/organizations/{org_id}/teams/{id}      # Get team details
PATCH  /api/v1/organizations/{org_id}/teams/{id}      # Update team
DELETE /api/v1/organizations/{org_id}/teams/{id}      # Delete team

POST   /api/v1/organizations/{org_id}/teams/{id}/members           # Add member
PATCH  /api/v1/organizations/{org_id}/teams/{id}/members/{user_id} # Update role
DELETE /api/v1/organizations/{org_id}/teams/{id}/members/{user_id} # Remove member
```

### Project Access

```
GET    /api/v1/projects/{id}/access                   # Get access config
POST   /api/v1/projects/{id}/access/teams             # Grant team access
PATCH  /api/v1/projects/{id}/access/teams/{team_id}   # Update team access
DELETE /api/v1/projects/{id}/access/teams/{team_id}   # Revoke team access
POST   /api/v1/projects/{id}/access/users             # Grant user access
PATCH  /api/v1/projects/{id}/access/users/{user_id}   # Update user access
DELETE /api/v1/projects/{id}/access/users/{user_id}   # Revoke user access
```

### Assignments

```
POST   /api/v1/assignments                            # Create assignment
GET    /api/v1/assignments                            # List assignments
GET    /api/v1/assignments/my                         # My assignments
GET    /api/v1/assignments/stats                      # Assignment statistics
GET    /api/v1/assignments/{id}                       # Get assignment
PATCH  /api/v1/assignments/{id}                       # Update assignment
DELETE /api/v1/assignments/{id}                       # Delete assignment
```

### Comments

```
POST   /api/v1/comments                               # Create comment
GET    /api/v1/comments/entity/{type}/{id}            # List entity comments
GET    /api/v1/comments/entity/{type}/{id}/threads    # Get threads
GET    /api/v1/comments/my                            # My comments
GET    /api/v1/comments/mentions                      # Mentions of me
GET    /api/v1/comments/{id}                          # Get comment
PATCH  /api/v1/comments/{id}                          # Update comment
DELETE /api/v1/comments/{id}                          # Delete comment
```

## Data Models

### Team

```typescript
interface Team {
  id: string;
  organization_id: string;
  name: string;
  slug: string;
  description?: string;
  color?: string;  // Hex color code
  member_count: number;
  created_at: string;
  updated_at: string;
}
```

### TeamMember

```typescript
interface TeamMember {
  id: string;
  user_id: string;
  email?: string;
  display_name?: string;
  role: 'lead' | 'member';
  added_at: string;
}
```

### ProjectAccess

```typescript
interface TeamAccessResponse {
  id: string;
  team_id: string;
  team_name?: string;
  team_slug?: string;
  access_level: 'owner' | 'write' | 'read';
  granted_at: string;
}

interface UserAccessResponse {
  id: string;
  user_id: string;
  email?: string;
  display_name?: string;
  access_level: 'owner' | 'write' | 'read';
  granted_at: string;
}
```

### Assignment

```typescript
interface Assignment {
  id: string;
  vulnerability_id: string;
  vulnerability_title?: string;
  vulnerability_severity?: string;
  assignee_id: string;
  assignee_email?: string;
  assignee_name?: string;
  assigned_by?: string;
  status: 'open' | 'in_progress' | 'resolved' | 'wont_fix';
  priority?: 'critical' | 'high' | 'medium' | 'low';
  due_date?: string;
  notes?: string;
  assigned_at: string;
  resolved_at?: string;
  updated_at: string;
}
```

### Comment

```typescript
interface Comment {
  id: string;
  user_id: string;
  author?: {
    id: string;
    email: string;
    display_name?: string;
  };
  entity_type: 'vulnerability' | 'scan' | 'contract' | 'project';
  entity_id: string;
  content: string;
  mentions: string[];  // User UUIDs
  parent_id?: string;
  is_edited: boolean;
  reply_count: number;
  created_at: string;
  updated_at: string;
}
```

## Usage Examples

### Create a Team

```bash
curl -X POST "http://127.0.0.1:3000/api/v1/organizations/{org_id}/teams" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Security Team",
    "slug": "security-team",
    "description": "Core security audit team",
    "color": "#FF5733"
  }'
```

### Grant Team Access to Project

```bash
curl -X POST "http://127.0.0.1:3000/api/v1/projects/{project_id}/access/teams" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "team_id": "team-uuid",
    "access_level": "write"
  }'
```

### Create Vulnerability Assignment

```bash
curl -X POST "http://127.0.0.1:3000/api/v1/assignments" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "vulnerability_id": "vuln-uuid",
    "assignee_id": "user-uuid",
    "priority": "high",
    "due_date": "2025-01-15T00:00:00Z",
    "notes": "Please review reentrancy issue"
  }'
```

### Add Comment with Mentions

```bash
curl -X POST "http://127.0.0.1:3000/api/v1/comments" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "entity_type": "vulnerability",
    "entity_id": "vuln-uuid",
    "content": "This looks like a false positive, please verify",
    "mentions": ["user-uuid-1", "user-uuid-2"]
  }'
```

## Security Considerations

### Authorization

- Team creation requires org admin role
- Project access management requires project owner role
- Comment editing/deletion restricted to author
- Assignment updates allowed by assignee or admin

### Data Validation

- Team slugs: alphanumeric with hyphens only
- Colors: hex format validation (#XXXXXX)
- Content length limits enforced
- UUID validation on all references

### Audit Trail

- All access grants tracked with `granted_by` user
- Assignment changes tracked with timestamps
- Comment edit history via `is_edited` flag

## Frontend Components

The Team Collaboration UI is implemented in Dashboard v0.16.0 with the following components:

### Organization Context

**File:** `src/contexts/OrganizationContext.tsx`

Manages multi-organization support for users who belong to multiple organizations.

**Features:**
- Stores current organization selection in localStorage
- Auto-selects first organization for new users
- Provides `useCurrentOrgId()` hook for API calls
- Invalidates queries on organization switch

**Usage:**
```tsx
import { useCurrentOrgId } from '@/contexts/OrganizationContext';

function MyComponent() {
  const orgId = useCurrentOrgId();
  // Use orgId for team-related API calls
}
```

### Teams Management Page

**File:** `src/pages/Teams.tsx`
**Route:** `/teams`
**Tier:** Enterprise only

Full-featured team management interface with:
- Team list with color indicators
- Create team modal with color picker
- Team detail view with member management
- Add/remove members with role selection (lead/member)
- Edit and delete teams

### Project Access Panel

**File:** `src/components/projects/ProjectAccessPanel.tsx`
**Location:** Project detail page
**Tier:** Enterprise only

Inline panel for managing project access:
- View current team and user access grants
- Grant access to teams or users
- Update access levels (owner/write/read)
- Revoke access with confirmation

### Vulnerability Assignment Panel

**File:** `src/components/vulnerabilities/VulnerabilityAssignmentPanel.tsx`
**Location:** Vulnerability detail page (right sidebar)
**Tier:** Enterprise only

Assignment management interface:
- View existing assignments
- Create new assignments with assignee, priority, due date
- Update assignment status (open/in_progress/resolved/wont_fix)
- Overdue indicators for past-due assignments
- Delete assignments

### Comments Panel

**File:** `src/components/comments/CommentsPanel.tsx`
**Location:** Vulnerability detail page (left column)
**Tier:** Enterprise only

Threaded discussion interface:
- Add new top-level comments
- Reply to existing comments
- Edit own comments
- Delete own comments with confirmation
- Collapsible reply threads
- Relative timestamps

**Reusable:** Can be integrated into any entity page (project, contract, scan, vulnerability).

```tsx
import { CommentsPanel } from '@/components/comments/CommentsPanel';

<CommentsPanel
  entityType="vulnerability"
  entityId={vulnerabilityId}
  title="Discussion"
/>
```

### React Query Hooks

| Hook File | Purpose |
|-----------|---------|
| `src/hooks/useTeams.ts` | Team CRUD and member management |
| `src/hooks/useProjectAccess.ts` | Project access control |
| `src/hooks/useAssignments.ts` | Vulnerability assignments |
| `src/hooks/useComments.ts` | Entity comments and threads |

### Tier Gating

All team collaboration UI features are gated to the **enterprise** tier using the `TierGate` component:

```tsx
import { TierGate } from '@/components/common/TierGate';

<TierGate requiredTier="enterprise" featureName="Team Collaboration" showUpgradePrompt>
  <TeamCollaborationFeature />
</TierGate>
```

## Related Documentation

- [API Endpoints Reference](/api/endpoints-reference.md)
- [Database Schema](/docs/database/SCHEMA.md)
- [Phase 4.5 Overview](/TaskDocs-Apogee/phases/04-phase-4.5-enterprise-features/PHASE-4.5-OVERVIEW.md)
- [Task 26 UI Implementation Plan](/TaskDocs-Apogee/phases/04-phase-4.5-enterprise-features/TASK-26-UI-IMPLEMENTATION-PLAN.md)
