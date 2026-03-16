# Support Ticket Pipeline

## Data Flow

```
Dashboard (React)
  ↓ POST /api/v1/support-tickets
API Service (FastAPI)
  ↓ Tier check → 403 if developer
  ↓ Rate limit → 429 if > 5/day
  ↓ Insert into support_tickets table (user_id, organization_id, ticket_number)
  ↓ Create JIRA issue via REST API v3 (async, non-blocking)
  ↓ Return APG-XXXX reference (no JIRA fields)
PostgreSQL + JIRA Cloud
```

## JIRA Integration (Internal)

- **Enabled via:** `SUPPORT_JIRA_ENABLED=true` env var
- **Auth:** Basic Auth (email + classic API token) — NOT granular scoped tokens
- **Project:** KAN
- **Credentials:** GCP Secret Manager → ExternalSecret → K8s Secret → env vars

### Category → JIRA Label Mapping

| Category | JIRA Labels |
|----------|------------|
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

## Comment Flow

```
User replies in dashboard
  ↓ POST /api/v1/comments (entity_type=support_ticket)
  ↓ Stored in comments table
  ↓ Forwarded to JIRA as comment with [Customer] prefix (non-blocking)

Support replies in JIRA
  ↓ Fetched on ticket detail view via JIRA REST API
  ↓ Displayed as "Support Team" (JIRA identity stripped)
```

## Error Handling

- JIRA sync failure does NOT block ticket creation (`jira_sync_status=failed`)
- JIRA comment forwarding failure does NOT block user comment creation
- JIRA unavailable → ticket detail shows conversation without support comments
