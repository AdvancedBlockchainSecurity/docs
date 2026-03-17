# Support Ticket Workflow

## Overview

Users submit support tickets at https://app.0xapogee.com/support. Tickets create JIRA issues internally for engineering triage. Users communicate with support via a conversation thread — JIRA is invisible to them.

## Status: Fully Functional

All features deployed and tested as of 2026-03-16.

## Tier Access

| Tier | Support Type | Ticket Access |
|------|-------------|:-------------:|
| Developer (free) | Community | No — sees upgrade prompt |
| Starter | Email (24h) | Yes |
| Growth | Priority (4h) | Yes |
| Enterprise | Dedicated | Yes |

Source of truth: `blocksecops-shared/tier-config/tiers.json` → `support.type`

## Ticket Lifecycle

```
User submits ticket
  → Tier check (developer blocked with 403)
  → Rate limit check (5/day/user)
  → DB record created with sequential number + organization_id
  → JIRA issue created internally (KAN project)
  → User sees "APG-XXXX" confirmation (no JIRA link)

Support engineer responds in JIRA
  → Comment fetched on ticket detail view
  → Displayed as "Support Team" (JIRA identity stripped)

User replies in dashboard
  → Comment stored in comments table (entity_type=support_ticket)
  → Forwarded to JIRA as [Customer] comment (non-blocking)

User closes ticket
  → PATCH /support-tickets/{id}/status?new_status=closed
  → Reply input disabled
```

## Scoping

- Tickets scoped to user + organization
- Organization members can view org tickets
- `organization_id` captured from `user.default_organization_id` at creation
- Detail endpoint checks both `user_id` and `organization_id` for access

## JIRA Isolation

Users never see JIRA. The following are NOT in user-facing responses:
- `jira_issue_key`, `jira_issue_url`, `jira_sync_status`, `jira_details`
- JIRA assignee, JIRA status, JIRA comments with author identity

Support team comments appear with author="Support Team".

## Ticket Reference Format

Sequential: `APG-{number:04d}` (e.g., APG-0001, APG-0002)

## Rate Limiting

5 tickets per user per day (UTC). Returns 429 if exceeded.

## Conversation Thread

Users and support communicate via a merged timeline:
- **User messages** (green border) — stored in `comments` table
- **Support Team messages** (blue border) — fetched from JIRA, identity stripped
- Sorted by timestamp ascending
- Reply input disabled when ticket status is "closed"
