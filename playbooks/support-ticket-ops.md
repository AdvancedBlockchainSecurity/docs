# Support Ticket Operations Playbook

## Status: Fully Functional (2026-03-16)

## Configure JIRA Integration

### Prerequisites
- JIRA Cloud account with project access
- Classic API token (NOT granular scoped — granular tokens use Bearer auth, our integration uses Basic Auth)
- Generate at: https://id.atlassian.com/manage-profile/security/api-tokens

### Setup

1. Create GCP secrets:
```bash
echo -n "https://your-org.atlassian.net" | gcloud secrets create apogee-gcp-jira-base-url --data-file=-
echo -n "your-email@example.com" | gcloud secrets create apogee-gcp-jira-api-email --data-file=-
echo -n "your-classic-api-token" | gcloud secrets create apogee-gcp-jira-api-token --data-file=-
echo -n "PROJECT_KEY" | gcloud secrets create apogee-gcp-jira-project-key --data-file=-
```

2. Sync and restart:
```bash
kubectl annotate externalsecret api-service-secret -n api-service-prod force-sync=$(date +%s) --overwrite
kubectl rollout restart deployment/api-service -n api-service-prod
```

3. Verify:
```bash
kubectl exec -n api-service-prod deploy/api-service -- printenv | grep SUPPORT_JIRA
```

## Verify JIRA Sync

```bash
kubectl logs -n api-service-prod deploy/api-service --tail=20 | grep -i jira
```

- Healthy: `Support ticket APG-XXXX synced to JIRA: KAN-XX`
- Failed: `Failed to sync support ticket APG-XXXX to JIRA: ...`

## Troubleshoot Failed Syncs

Common failures:
- **401 Unauthorized** — API token expired or wrong type (must be classic, not granular scoped)
- **403 Forbidden** — Token account lacks project access
- **404 Not Found** — Wrong project key

Check failed tickets:
```bash
kubectl exec -n api-service-prod deploy/api-service -- python -c "
import asyncio
from sqlalchemy import text
from src.infrastructure.database.connection import engine
async def run():
    async with engine.begin() as conn:
        r = await conn.execute(text(
            \"SELECT ticket_number, jira_sync_status FROM support_tickets WHERE jira_sync_status = 'failed'\"
        ))
        for row in r.fetchall():
            print(f'APG-{row[0]:04d}: {row[1]}')
asyncio.run(run())
"
```

Update token:
```bash
echo -n "new-token" | gcloud secrets versions add apogee-gcp-jira-api-token --data-file=-
kubectl annotate externalsecret api-service-secret -n api-service-prod force-sync=$(date +%s) --overwrite
kubectl rollout restart deployment/api-service -n api-service-prod
```

## Reset Rate Limit

Delete test tickets from today for a user:
```bash
kubectl exec -n api-service-prod deploy/api-service -- python -c "
import asyncio
from sqlalchemy import text
from src.infrastructure.database.connection import engine
async def run():
    async with engine.begin() as conn:
        r = await conn.execute(text(
            \"DELETE FROM support_tickets WHERE user_email = 'user@example.com' AND subject LIKE '%test%' AND created_at >= CURRENT_DATE RETURNING ticket_number\"
        ))
        print(f'Deleted {len(r.fetchall())} test tickets')
asyncio.run(run())
"
```

## Current Configuration

| Setting | Value |
|---------|-------|
| JIRA Base URL | https://bso-abs.atlassian.net |
| JIRA Project | KAN |
| API Email | jasonbrailowbizop@mail.com |
| Rate Limit | 5 tickets/user/day |
| Ticket Prefix | APG- |
| Tier Gate | developer blocked, starter+ allowed |
