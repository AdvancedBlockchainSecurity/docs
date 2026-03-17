# Playbook: Seed Data Operations

**Version:** 1.0.0
**Last Updated:** March 17, 2026

## Overview

The API service automatically seeds curated data on startup. This playbook covers manual operations: force re-seeding, troubleshooting, and verifying seed state.

---

## Quick Reference

| Data | Auto-seeded | Manual Endpoint | Seed File |
|------|------------|-----------------|-----------|
| Vulnerability Patterns (397) | On startup | `POST /internal/patterns/seed` | `seeds/vulnerability_patterns.json` |
| Exploits (10) | On startup | `POST /internal/intelligence/seed` | `seeds/exploits_and_cves.json` |
| CVEs (10) | On startup | `POST /internal/intelligence/seed` | `seeds/exploits_and_cves.json` |
| Scanner Versions (16) | On startup | `POST /internal/scanners/seed` | ConfigMap `SCANNER_METADATA` |

---

## Force Re-Seed

If seed data needs refreshing without a pod restart (e.g., after updating the seed JSON file in a new image):

```bash
# Get internal service key
KEY=$(kubectl get secret api-service-secret -n api-service-prod -o jsonpath='{.data.INTERNAL_SERVICE_KEY}' | base64 -d)

# Re-seed patterns
curl -X POST https://app.0xapogee.com/api/v1/internal/patterns/seed \
  -H "X-Internal-Service-Key: $KEY" \
  -H "Content-Type: application/json"

# Re-seed exploits and CVEs
curl -X POST https://app.0xapogee.com/api/v1/internal/intelligence/seed \
  -H "X-Internal-Service-Key: $KEY" \
  -H "Content-Type: application/json"

# Re-seed scanner versions from ConfigMap
curl -X POST https://app.0xapogee.com/api/v1/internal/scanners/seed \
  -H "X-Internal-Service-Key: $KEY" \
  -H "Content-Type: application/json"
```

---

## Verify Seed State

```bash
# Check all seed versions from inside the pod
kubectl exec -n api-service-prod deployment/api-service -- python3 -c "
import asyncio
from src.infrastructure.database.connection import get_db_session
from sqlalchemy import text
async def check():
    async with get_db_session() as db:
        r = await db.execute(text(\"\"\"
            SELECT model_name, current_version FROM ml_model_metadata
            WHERE model_name LIKE '%seed%' ORDER BY model_name
        \"\"\"))
        for row in r.fetchall():
            print(f'{row[0]}: {row[1]}')
asyncio.run(check())
"
```

Expected output:
```
exploit_cve_seed: v1.0
pattern_seed: v3.13
scanner_version_seed: configmap-a16e81c40981
```

---

## Troubleshooting

### Seed skipped on startup

Check logs for seed messages:
```bash
kubectl logs -n api-service-prod -l app.kubernetes.io/name=api-service --tail=100 | grep -i seed
```

Common causes:
- **"up to date"**: Version matches, no action needed
- **"skipped"**: Seed file not found or invalid JSON
- **"SCANNER_METADATA" missing**: ConfigMap not mounted as env var

### Scanner versions table empty

1. Verify `SCANNER_METADATA` env var is set:
   ```bash
   kubectl exec -n api-service-prod deployment/api-service -- printenv SCANNER_METADATA | head -5
   ```

2. If empty, check the ConfigMap:
   ```bash
   kubectl get configmap scanner-versions -n api-service-prod -o jsonpath='{.data.SCANNER_METADATA}' | head -5
   ```

3. Verify the deployment mounts it:
   ```bash
   kubectl get deployment api-service -n api-service-prod -o yaml | grep -A3 SCANNER_METADATA
   ```

### Patterns table empty

1. Check if seed file exists in image:
   ```bash
   kubectl exec -n api-service-prod deployment/api-service -- ls -la seeds/vulnerability_patterns.json
   ```

2. Force re-seed via endpoint (see above)

### Alembic migration not applied

If `scanner_versions` table doesn't exist:
```bash
kubectl exec -n api-service-prod deployment/api-service -- python3 -m alembic upgrade head
```

---

## Adding New Seed Data

### Adding new patterns
1. Edit `seeds/vulnerability_patterns.json`
2. Bump the `version` field (e.g., `v3.13` → `v3.14`)
3. Build new image, deploy — startup detects version mismatch and upserts

### Adding new exploits/CVEs
1. Edit `seeds/exploits_and_cves.json`
2. Bump the `version` field
3. Build new image, deploy

### Scanner versions update automatically
Scanner versions sync from ConfigMap on every startup. When the ConfigMap is updated (scanner upgrade), the content hash changes and triggers upsert on next pod restart.
