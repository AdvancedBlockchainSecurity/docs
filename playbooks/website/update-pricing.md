# Playbook: Update Website Pricing

> **DEPRECATED:** This playbook is outdated. The frontend is NOT the source of truth for pricing.
>
> **Use instead:** [Adjust Pricing](../adjust-pricing.md)
>
> The source of truth is `blocksecops-shared/tier-config/tiers.json`. See the new playbook for the correct workflow.

---

Update pricing information on blocksecops.com.

## Prerequisites

- Access to `blocksecops_com` repository
- Access to `blocksecops-docs` repository (for billing docs)

## Overview

Pricing data is centralized in `lib/pricing-data.ts`. When pricing changes:
1. Update the source of truth
2. Sync billing documentation manually
3. Verify and deploy

## Step 1: Update Source of Truth

Edit `lib/pricing-data.ts` in the `blocksecops_com` repo.

### Pricing Tiers

```typescript
// lib/pricing-data.ts
export const PRICING_TIERS: PricingTier[] = [
  {
    id: 'developer',
    name: 'Developer',
    price: 0,
    priceDisplay: '$0',
    scansPerMonth: 10,
    users: 1,
    // ... other fields
  },
  // ... other tiers
]
```

### Key Fields to Update

| Field | Description | Example |
|-------|-------------|---------|
| `price` | Monthly price in USD | `299` |
| `priceDisplay` | Formatted price string | `'$299'` |
| `scansPerMonth` | Monthly scan limit | `100` or `'unlimited'` |
| `users` | User limit | `5` or `'unlimited'` |
| `features` | Marketing bullet points | `['100 scans/month', ...]` |

### Credit Packages

```typescript
export const CREDIT_PACKAGES: CreditPackage[] = [
  { name: 'Starter', credits: 10, price: 30, perScan: '3.00' },
  // ...
]
```

## Step 2: Update Billing Docs

The billing docs in `content/docs/billing/` have hardcoded pricing tables. Update these to match:

### Files to Update

```bash
# In blocksecops_com repo
content/docs/billing/README.md           # Overview table
content/docs/billing/choosing-a-plan.md  # Decision tables
content/docs/billing/pricing-tiers.md    # Detailed breakdown
content/docs/support/faq/billing.md      # FAQ pricing table
```

### Table Format

```markdown
| Plan | Monthly | Scans/Mo | Team Size |
|------|---------|----------|-----------|
| **Developer (Free)** | $0 | 10 | 1 user |
| **Team** | $299 | 100 | 5 users |
| **Growth** | $699 | 500 | 15 users |
| **Enterprise** | $1,999+ | Unlimited | Unlimited |
```

## Step 3: Verify Locally

```bash
cd ~/Git/Platform-websites/blocksecops_com

# Build to check for errors
npm run build

# Start dev server
npm run dev

# Open in browser
open http://localhost:4000/pricing
```

### Verification Checklist

- [ ] `/pricing` page shows correct values
- [ ] Homepage pricing section matches
- [ ] `/docs/Billing/README` shows correct table
- [ ] `/docs/Billing/choosing-a-plan` tables are accurate
- [ ] No build errors

## Step 4: Commit and Deploy

```bash
# Stage changes
git add lib/pricing-data.ts
git add content/docs/billing/
git add content/docs/support/faq/billing.md

# Commit
git commit -m "chore(pricing): update pricing to new values

- Updated pricing tiers in lib/pricing-data.ts
- Synced billing documentation"

# Push (triggers deploy)
git push origin main
```

## Rollback

If something goes wrong:

```bash
# Revert to previous commit
git revert HEAD

# Or reset to specific commit
git reset --hard <commit-hash>
git push --force-with-lease origin main
```

## Current Pricing Reference

| Plan | Price | Scans | Users | Projects |
|------|-------|-------|-------|----------|
| Developer | $0 | 10 | 1 | 3 |
| Team | $299 | 100 | 5 | 10 |
| Growth | $699 | 500 | 15 | 25 |
| Enterprise | $1,999+ | Unlimited | Unlimited | Unlimited |

## Related Files

| File | Purpose |
|------|---------|
| `lib/pricing-data.ts` | Source of truth |
| `app/(frontend)/pricing/page.tsx` | Pricing page |
| `components/sections/Pricing.tsx` | Homepage section |
| `content/docs/billing/*.md` | Billing documentation |
| `docs/PRICING.md` | Architecture docs |

## Contacts

- **Engineering:** Check repo CODEOWNERS
- **Product:** For pricing decisions
