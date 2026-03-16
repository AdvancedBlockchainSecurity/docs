# Support Ticket Operations Playbook

## Configure JIRA Integration

### Prerequisites
- JIRA Cloud account with project access
- Classic API token (NOT granular scoped token)

### Setup

1. Create GCP secrets:
```bash
echo -n "https://your-org.atlassian.net" | gcloud secrets create apogee-gcp-jira-base-url --data-file=-
echo -n "your-email@example.com" | gcloud secrets create apogee-gcp-jira-api-email --data-file=-
echo -n "your-classic-api-token" | gcloud secrets create apogee-gcp-jira-api-token --data-file=-
echo -n "PROJECT_KEY" | gcloud secrets create apogee-gcp-jira-project-key --data-file=-
```

2. ExternalSecret references are in `api-service/k8s/overlays/gcp/externalsecret.yaml`

3. Deployment env vars are in `api-service/k8s/overlays/gcp/deployment-patch.yaml`:
   - `SUPPORT_JIRA_ENABLED=true`
   - `SUPPORT_JIRA_BASE_URL`, `SUPPORT_JIRA_API_EMAIL`, `SUPPORT_JIRA_API_TOKEN`, `SUPPORT_JIRA_PROJECT_KEY` from secretKeyRef

4. Sync and restart:
```bash
kubectl annotate externalsecret api-service-secret -n api-service-prod force-sync=$(date +%s) --overwrite
kubectl rollout restart deployment/api-service -n api-service-prod
```

## Verify JIRA Sync

```bash
kubectl logs -n api-service-prod deploy/api-service --tail=20 | grep -i jira
```

Healthy: `Support ticket APG-XXXX synced to JIRA: KAN-XX`
Failed: `Failed to sync support ticket APG-XXXX to JIRA: ...`

## Troubleshoot Failed Syncs

1. Check sync status:
```bash
kubectl exec -n api-service-prod deploy/api-service -- python -c "
import asyncio
from sqlalchemy import text
from src.infrastructure.database.connection import engine
async def run():
    async with engine.begin() as conn:
        r = await conn.execute(text(
            \"SELECT ticket_number, jira_sync_status, jira_issue_key FROM support_tickets WHERE jira_sync_status = 'failed'\"
        ))
        for row in r.fetchall():
            print(f'APG-{row[0]:04d}: sync={row[1]}, jira={row[2]}')
asyncio.run(run())
"
```

2. Common failures:
   - **401 Unauthorized** — API token expired or wrong type (must be classic, not granular)
   - **403 Forbidden** — Token account doesn't have project access
   - **404 Not Found** — Wrong project key

3. Update token:
```bash
echo -n "new-token-value" | gcloud secrets versions add apogee-gcp-jira-api-token --data-file=-
kubectl annotate externalsecret api-service-secret -n api-service-prod force-sync=$(date +%s) --overwrite
kubectl rollout restart deployment/api-service -n api-service-prod
```

## Reset Rate Limit

If a user hits the daily limit due to test tickets:
```bash
kubectl exec -n api-service-prod deploy/api-service -- python -c "
import asyncio
from sqlalchemy import text
from src.infrastructure.database.connection import engine
async def run():
    async with engine.begin() as conn:
        await conn.execute(text(
            \"DELETE FROM support_tickets WHERE user_email = 'user@example.com' AND subject LIKE '%test%' AND created_at >= CURRENT_DATE\"
        ))
asyncio.run(run())
"
```
