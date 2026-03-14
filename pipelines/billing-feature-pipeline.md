# Billing Feature Change Pipeline

**Version:** 1.0.0
**Last Updated:** March 13, 2026

## Overview

Step-by-step pipeline for making changes to tier features, quotas, or pricing.

## Pipeline Steps

### 1. Update Source of Truth

Edit `blocksecops-shared/tier-config/tiers.json`:

```bash
vi blocksecops-shared/tier-config/tiers.json
```

Update the relevant tier's `features`, `quotas`, or `pricing` section.

### 2. Rebuild TypeScript Bindings

```bash
cd blocksecops-shared/tier-config/typescript
npm run build
```

### 3. Verify Dashboard Imports

```bash
cd blocksecops-dashboard
npm install  # picks up updated tier-config
npm run type-check  # ensure no type errors
npm run build  # full build verification
```

### 4. Sync API `/billing/plans`

Update `blocksecops-api-service/src/presentation/api/v1/endpoints/billing.py` GET `/billing/plans` to match `tiers.json` values. Add a comment noting the sync date.

### 5. Database Migration (if needed)

If quota defaults change (e.g., `monthlyContractLimit`), create a database migration to update existing `user_quotas` rows:

```sql
-- Example: update developer tier scan limit from 10 to 3
UPDATE user_quotas
SET monthly_scan_limit = 3
WHERE tier = 'developer' AND monthly_scan_limit = 10;
```

### 6. Version Bump

```bash
# Dashboard
cd blocksecops-dashboard
npm version minor --no-git-tag-version
# Update kustomization.yaml newTag to match
```

### 7. Build and Deploy

```bash
cd ~/Git
VERSION=$(grep '"version"' blocksecops-dashboard/package.json | head -1 | cut -d'"' -f4)
docker build -f blocksecops-dashboard/Dockerfile \
  --build-arg SERVICE_VERSION=$VERSION \
  -t harbor.blocksecops.local/blocksecops/dashboard:$VERSION .
docker push harbor.blocksecops.local/blocksecops/dashboard:$VERSION
kubectl apply -k blocksecops-dashboard/k8s/overlays/local/
```

### 8. Verification

1. Log in as each tier → Billing → verify features show correct check/X
2. Compare Pricing page feature table with `tiers.json`
3. Call `GET /billing/plans` API → verify values match `tiers.json`
4. Run smoke test per `docs/standards/smoke-test.md`

## Files Involved

| File | Repo | Role |
|------|------|------|
| `tier-config/tiers.json` | shared | Source of truth |
| `tier-config/typescript/index.ts` | shared | TypeScript bindings |
| `src/lib/api/billing.ts` | dashboard | PLAN_TIERS derived from config |
| `src/pages/Pricing.tsx` | dashboard | Feature comparison from config |
| `src/components/settings/QuotaUsageCard.tsx` | dashboard | Feature display from API + config |
| `src/hooks/useQuota.ts` | dashboard | Quota status from API |
| `src/.../endpoints/billing.py` | api-service | /billing/plans (manually synced) |
