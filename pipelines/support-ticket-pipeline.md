# Support Ticket Pipeline

## Status: Fully Functional (2026-03-16)

## Data Flow

```
Dashboard (React)
  ↓ POST /api/v1/support-tickets
API Service (FastAPI)
  ↓ Tier check (developer → 403)
  ↓ Rate limit (5/day → 429)
  ↓ Insert support_tickets table (user_id, organization_id, ticket_number)
  ↓ Create JIRA issue (async, non-blocking)
  ↓ Return APG-XXXX reference (no JIRA fields)
PostgreSQL + JIRA Cloud (KAN project)
```

## JIRA Integration (Internal Only)

- **Auth:** Basic Auth (email + classic API token)
- **Project:** KAN at https://bso-abs.atlassian.net
- **Env vars:** `SUPPORT_JIRA_ENABLED`, `SUPPORT_JIRA_BASE_URL`, `SUPPORT_JIRA_API_EMAIL`, `SUPPORT_JIRA_API_TOKEN`, `SUPPORT_JIRA_PROJECT_KEY`
- **Credentials:** GCP Secret Manager → ExternalSecret → K8s Secret → env vars
- **JIRA isolation:** No JIRA fields in any user-facing API response

### Category → JIRA Labels

| Category | Labels |
|----------|--------|
| bug | support-ticket, bug-report |
| billing | support-ticket, billing |
| feature_request | support-ticket, feature-request |
| security | support-ticket, security, high-priority |
| general | support-ticket, general-inquiry |

### Priority Mapping

| Platform | JIRA |
|----------|------|
| low | Low |
| medium | Medium |
| high | High |
| urgent | Highest |

## Comment Pipeline

```
User replies in dashboard
  ↓ POST /api/v1/comments (entity_type=support_ticket, entity_id=ticket_id)
  ↓ Stored in comments table (polymorphic, reuses existing comment system)
  ↓ verify_entity_access checks ticket ownership (BSO-SEC-015)
  ↓ Forwarded to JIRA as comment: "[Customer] {content}" (non-blocking)

Support replies in JIRA
  ↓ Fetched via JIRA REST API on ticket detail view
  ↓ Author stripped → displayed as "Support Team"
  ↓ Merged with user comments in chronological order
```

## Error Handling

- JIRA sync failure → ticket saved with `jira_sync_status=failed`, user unaffected
- JIRA comment forward failure → user comment saved, JIRA forward logged as warning
- JIRA unavailable → ticket detail shows user comments only, no support team comments

## Database

- **Table:** `support_tickets` (user_id, organization_id, ticket_number, category, priority, subject, description, status, jira_issue_key, jira_sync_status)
- **Comments:** Reuses `comments` table with `entity_type=support_ticket`
- **Migrations:** 083 (ticket_number), 084 (organization_id)
