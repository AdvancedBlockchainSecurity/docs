# Support Ticket Workflow

## Overview

Users submit support tickets through the dashboard at https://app.0xapogee.com/support. Tickets create JIRA issues internally for engineering triage. Users communicate with support via a conversation thread — JIRA is invisible to them.

## Tier Access

| Tier | Support Type | Ticket Access |
|------|-------------|:-------------:|
| Developer (free) | Community | No |
| Starter | Email (24h) | Yes |
| Growth | Priority (4h) | Yes |
| Enterprise | Dedicated | Yes |

Source of truth: `blocksecops-shared/tier-config/tiers.json` → `support.type`

Developer tier users see an upgrade prompt instead of the ticket form.

## Ticket Lifecycle

```
User submits ticket → API creates DB record + JIRA issue (internal)
                    → Sequential reference assigned (APG-0001)
                    → User sees confirmation with reference

Support engineer responds in JIRA → Comment appears as "Support Team" in dashboard

User replies in dashboard → Comment stored in DB + forwarded to JIRA as [Customer]

User or support closes ticket → Status updated to "closed", replies disabled
```

## Scoping

- Tickets are scoped to the user who created them AND their organization
- Organization members can view tickets from their org
- `organization_id` captured from `user.default_organization_id` at creation

## Ticket Reference Format

Sequential: `APG-{number:04d}` (e.g., APG-0001, APG-0002)

## Rate Limiting

5 tickets per user per day (UTC). Enforced at API level.
