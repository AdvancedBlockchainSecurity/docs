# Playbook: Adjust Pricing

**Version:** 1.1.0
**Last Updated:** March 13, 2026

## Overview

This playbook documents how to properly adjust pricing tiers, quotas, features, and credit packages using the centralized tier configuration system.

---

## Prerequisites

- [ ] Access to `blocksecops-shared` repository
- [ ] Understanding of tier structure (see [Tier Standards](../standards/tier-standards.md))
- [ ] Stripe Dashboard access (for price changes)
- [ ] Database migration access (for quota defaults)

---

## Source of Truth Architecture

```
blocksecops-shared/tier-config/tiers.json  <-- SINGLE SOURCE OF TRUTH
                    |
    +---------------+---------------+
    |               |               |
    v               v               v
Python Package   TypeScript       Database
(loader.py)      (@blocksecops/   (via Python)
                  tier-config)
    |               |               |
    v               v               v
API Service    Dashboard +       Alembic
               Pricing.tsx       Migrations
               billing.ts
               QuotaUsageCard
```

**Important:** The `tiers.json` file is the authoritative source for all tier values. When values differ between systems, `tiers.json` is correct.

**As of v0.42.0 (February 2026):** The TypeScript package (`@blocksecops/tier-config`) is fully implemented. The dashboard imports `PLAN_TIERS`, `getPricingTable()`, `generateFeatureComparisonRows()`, and `generateQuotaComparisonRows()` directly from the package. Manual frontend syncing is no longer required for dashboard components.

---

## Key Files

| File | Purpose |
|------|---------|
| `blocksecops-shared/tier-config/tiers.json` | **PRIMARY SOURCE** - all tier values |
| `blocksecops-shared/tier-config/schema/tier-config.schema.json` | JSON Schema validation |
| `blocksecops-shared/tier-config/python/blocksecops_tier_config/models.py` | Pydantic models |
| `blocksecops-shared/tier-config/python/blocksecops_tier_config/loader.py` | Python loader with caching |
| `blocksecops-shared/tier-config/typescript/index.ts` | TypeScript bindings (dashboard imports this) |
| `blocksecops-dashboard/src/lib/api/billing.ts` | Dashboard PLAN_TIERS (derived from tier-config) |
| `blocksecops-dashboard/src/pages/Pricing.tsx` | Dashboard pricing page (derived from tier-config) |
| `blocksecops_com/lib/pricing-data.ts` | Marketing website (still requires manual sync) |
| `docs/standards/tier-standards.md` | Human-readable tier documentation |

---

## Step 1: Update tiers.json

Edit `blocksecops-shared/tier-config/tiers.json` with your changes.

### Change Tier Price

```json
{
  "tiers": {
    "starter": {
      "pricing": {
        "monthly": 199,        // Was 299
        "annual": 2028,        // Was 2988
        "perContract": 7.96    // Recalculate: monthly / contracts
      },
      "display": {
        "badge": "$199/mo"     // Update display badge
      }
    }
  }
}
```

### Adjust Quota Limits

```json
{
  "tiers": {
    "growth": {
      "quotas": {
        "monthlyContractLimit": 75,    // Was 50
        "maxTeamMembers": 25,          // Was 15
        "monthlyAiExplanationsLimit": 300  // Was 200
      }
    }
  }
}
```

### Add/Remove Features

```json
{
  "tiers": {
    "starter": {
      "features": {
        "multiChainEnabled": true,    // Now enabled for Starter tier
        "newFeatureName": true        // Add new feature
      }
    }
  }
}
```

### Update Credit Packages

```json
{
  "creditPackages": {
    "starter": {
      "credits": 10,          // 10 credits
      "price": 25.00,         // Was 30
      "perCredit": 2.50,      // Recalculate
      "savings": null
    }
  }
}
```

### Add Premium Add-Ons

```json
{
  "premiumAddOns": {
    "newAddOn": {
      "price": 199,
      "description": "Description of the add-on"
    }
  }
}
```

### Update Metadata

Always update the metadata when making changes:

```json
{
  "version": "4.0",           // Increment version
  "lastUpdated": "2026-03-13" // Update date
}
```

---

## Step 2: Validate Changes

### JSON Schema Validation

```bash
cd /home/pwner/Git/blocksecops-shared/tier-config

# Install ajv-cli if not present
npm install -g ajv-cli

# Validate against schema
ajv validate -s schema/tier-config.schema.json -d tiers.json
```

### Python Loader Test

```bash
cd /home/pwner/Git/blocksecops-shared/tier-config/python

# Install package in development mode
pip install -e .

# Test loading
python -c "
from blocksecops_tier_config import get_tier_config, get_tier
config = get_tier_config()
print(f'Version: {config.version}')
print(f'Tiers: {list(config.tiers.keys())}')
starter = get_tier('starter')
print(f'Starter monthly price: \${starter.pricing.monthly}')
"
```

---

## Step 3: Update Stripe (if prices changed)

If subscription prices changed, update Stripe:

### Create New Stripe Price

1. Go to [Stripe Dashboard](https://dashboard.stripe.com/products)
2. Find the relevant product (e.g., "Apogee Starter")
3. Click "Add another price"
4. Configure:
   - Pricing model: Standard pricing
   - Price: New amount
   - Billing period: Monthly/Annual
5. Copy the new `price_xxx` ID

### Update tiers.json with Stripe IDs

```json
{
  "tiers": {
    "starter": {
      "stripePriceIdMonthly": "price_1TAfcL3ZtjkVcNXVjTSRsgYs",
      "stripePriceIdAnnual": "price_1TAfcM3ZtjkVcNXVg9ll3Pqm"
    }
  }
}
```

### Archive Old Prices (Optional)

In Stripe Dashboard, archive old prices to prevent new subscriptions at old rates.

---

## Step 4: Update Frontend

### Dashboard (Automatic via tier-config)

**As of v0.42.0**, the dashboard automatically reads from `@blocksecops/tier-config`. After updating `tiers.json` and rebuilding the TypeScript bindings:

```bash
cd /home/pwner/Git/blocksecops-shared/tier-config/typescript
npm run build

cd /home/pwner/Git/blocksecops-dashboard
npm install  # picks up updated tier-config
npm run type-check  # ensure no type errors
```

Dashboard components that auto-sync:
- `Pricing.tsx` — uses `getPricingTable()`, `generateFeatureComparisonRows()`, `generateQuotaComparisonRows()`
- `billing.ts` — `PLAN_TIERS` derived from `getAllTiers()`
- `SubscriptionCard.tsx` — plan display from `PLAN_TIERS`
- `QuotaUsageCard.tsx` — supplementary data from `getTier()`

See [Billing Feature Pipeline](/docs/pipelines/billing-feature-pipeline.md) for the full step-by-step process.

### Marketing Website (Manual Sync Required)

The marketing website (`blocksecops_com`) still duplicates pricing data. Manual sync is required.

#### Update pricing-data.ts

Edit `blocksecops_com/lib/pricing-data.ts` to match `tiers.json`:

```typescript
export const PRICING_TIERS: PricingTier[] = [
  {
    id: 'starter',
    name: 'Starter',
    price: 199,           // Match tiers.json
    priceDisplay: '$199',
    scansPerMonth: 25,    // Match quotas.monthlyContractLimit
    users: 15,            // Match quotas.maxProjects
    features: [
      '25 contract scans/month',
      '15 projects',
      // ...
    ],
  },
  // ... other tiers
];
```

### Update Credit Packages

```typescript
export const CREDIT_PACKAGES: CreditPackage[] = [
  { name: 'Starter', credits: 10, price: 25, perScan: '2.50' },
  // ... match creditPackages in tiers.json
];
```

---

## Step 5: Update Documentation

### Update tier-standards.md

Edit `docs/standards/tier-standards.md` to reflect any changes:

1. Update pricing tables
2. Update quota tables
3. Update feature availability tables
4. Add changelog entry

### Changelog Entry Format

```markdown
## Changelog

| Date | Change | Author |
|------|--------|--------|
| 2026-03-13 | **v4.0**: Competitive pricing adjustment. Starter $199/mo, Growth $499/mo, Enterprise $1,499/mo. Updated credit packages and quotas. | Apogee Team |
```

---

## Step 6: Deploy Changes

### Backend (Automatic)

The Python backend uses `blocksecops_tier_config.loader` which reads `tiers.json` at startup. Changes take effect on:

- API service restart
- Next deployment

```bash
# If needed, restart API service to pick up changes
kubectl rollout restart deployment/api-service -n api-service-local
```

### Database Defaults (Alembic Migration)

If quota defaults changed for new users, create an Alembic migration:

```bash
cd /home/pwner/Git/blocksecops-api-service

# Create migration
alembic revision -m "update_tier_quota_defaults"
```

Migration template:

```python
"""update_tier_quota_defaults

Revision ID: xxx
"""

def upgrade():
    # Update trigger function with new defaults
    op.execute("""
    CREATE OR REPLACE FUNCTION create_user_quota()
    RETURNS TRIGGER AS $$
    BEGIN
      INSERT INTO user_quotas (user_id, tier, monthly_contract_limit, ...)
      VALUES (
        NEW.id,
        'developer',
        3,  -- Updated default
        ...
      );
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """)
```

### Frontend

```bash
cd /home/pwner/Git/Platform-websites/blocksecops_com

# Build to verify
npm run build

# Deploy (triggers on push to main)
git add lib/pricing-data.ts
git commit -m "chore(pricing): sync pricing with tiers.json v4.0"
git push origin main
```

---

## Verification Checklist

After making changes, verify:

- [ ] `tiers.json` validates against JSON Schema
- [ ] Python loader successfully loads config
- [ ] Stripe prices created (if price changed)
- [ ] Stripe price IDs updated in `tiers.json`
- [ ] Dashboard tier-config package rebuilt (`cd tier-config/typescript && npm run build`)
- [ ] Dashboard `npm install && npm run type-check` passes
- [ ] Marketing website `pricing-data.ts` synced with `tiers.json` (manual)
- [ ] `tier-standards.md` documentation updated
- [ ] API service restarted and healthy
- [ ] Pricing page shows correct values
- [ ] Billing docs match new pricing

### Verification Commands

```bash
# Check API health
curl -s http://127.0.0.1:8000/api/v1/health/ready | jq .

# Verify tier data from API (if endpoint exists)
curl -s http://127.0.0.1:8000/api/v1/billing/tiers | jq .

# Check frontend pricing page
open http://localhost:4000/pricing
```

---

## Common Changes

### Change Tier Price

1. Update `pricing.monthly` and `pricing.annual` in `tiers.json`
2. Update `display.badge` in `tiers.json`
3. Create new Stripe price
4. Update Stripe price IDs in `tiers.json`
5. Sync `pricing-data.ts`
6. Update `tier-standards.md`

### Adjust Quota Limits

1. Update `quotas.*` in `tiers.json`
2. Create Alembic migration if defaults changed
3. Sync `pricing-data.ts`
4. Update `tier-standards.md`

### Add/Remove Features

1. Update `features.*` in `tiers.json`
2. Update Python models if new feature added
3. Sync `pricing-data.ts`
4. Update `tier-standards.md`

### Update Credit Packages

1. Update `creditPackages.*` in `tiers.json`
2. Sync `pricing-data.ts`
3. Update `tier-standards.md`

### Add Premium Add-Ons

1. Add to `premiumAddOns` in `tiers.json`
2. Create Stripe product/price
3. Sync `pricing-data.ts`
4. Update `tier-standards.md`

---

## Rollback

If changes need to be reverted:

### Revert tiers.json

```bash
cd /home/pwner/Git/blocksecops-shared

# Find previous commit
git log --oneline tier-config/tiers.json

# Revert to previous version
git checkout <commit-hash> -- tier-config/tiers.json

# Commit the revert
git commit -m "revert(pricing): rollback to previous tier config"
```

### Revert Stripe Changes

1. Archive new prices in Stripe Dashboard
2. Reactivate old prices
3. Update `tiers.json` with old price IDs

### Revert Frontend

```bash
cd /home/pwner/Git/Platform-websites/blocksecops_com

git revert HEAD  # If pricing commit was latest
# OR
git checkout <commit-hash> -- lib/pricing-data.ts
git commit -m "revert(pricing): rollback pricing-data.ts"
```

---

## Troubleshooting

### JSON Schema Validation Fails

```bash
# Check error details
ajv validate -s schema/tier-config.schema.json -d tiers.json --verbose
```

Common issues:
- Missing required fields
- Wrong data types (string vs number)
- Invalid enum values

### Python Loader Fails

```python
# Debug loading
from blocksecops_tier_config.loader import _load_raw_config
import json

raw = _load_raw_config()
print(json.dumps(raw, indent=2))
```

### Frontend/Backend Mismatch

Compare values directly:

```bash
# Frontend values
grep -A5 "id: 'starter'" blocksecops_com/lib/pricing-data.ts

# Backend values
python -c "
from blocksecops_tier_config import get_tier
t = get_tier('starter')
print(f'Price: {t.pricing.monthly}')
print(f'Contracts: {t.quotas.monthly_contract_limit}')
"
```

---

## Important: billing.py Hardcoded Plan Data

**`blocksecops-api-service/src/application/services/billing.py`** contains hardcoded plan data (prices, plan names, Stripe price IDs) that is **not** sourced from `tiers.json`. When subscription prices or tier quotas change, `billing.py` must be manually updated to match.

This was discovered during the v4.0 competitive pricing adjustment (March 13, 2026): the tier audit found that `billing.py` still had v3.2 prices after all other files had been updated. The fix required updating the hardcoded values in `billing.py` and rebuilding the API service to v0.29.88. After the fix, the full tier audit passed 133/133 checks.

**When changing prices, always verify `billing.py` is in sync with `tiers.json`.**

---

## Related Documentation

- [Tier Standards](../standards/tier-standards.md) - Human-readable tier documentation
- [tiers.json](../../blocksecops-shared/tier-config/tiers.json) - Source of truth
- [Stripe Dashboard](https://dashboard.stripe.com) - Price management
- [Alembic Migrations](../../blocksecops-api-service/alembic/) - Database migrations
