# Dashboard v0.42.0 - Billing Feature Fix, Data Isolation & Invite UI

**Date:** February 12, 2026
**Component:** blocksecops-dashboard
**Type:** Bug Fix + Feature + Security
**Priority:** High
**Status:** Complete

---

## Summary

Fixed billing/subscription feature display (grey X for enabled features), added localStorage data isolation per user (security), integrated centralized `@blocksecops/tier-config` for pricing/features, and added invite UI to the billing page.

## Bug Fixes

### Field Name Mismatch (ROOT CAUSE of grey X)
- Fixed `EnhancedUser.quota` fields in `users.ts` to match API `QuotaInfo` response
- `can_export_reports` -> `export_enabled`
- `can_use_webhooks` -> `webhooks_enabled`
- `can_use_api` -> `api_access_enabled`
- `reset_date` -> `quota_reset_at`
- Updated all consumers: `AuthContext.tsx`, `QuotaUsageCard.tsx`, `useQuota.ts`, `Billing.tsx`

### Supplementary Data from Tier Config
- `QuotaUsageCard` now uses `getTier()` from `@blocksecops/tier-config` for data not in API response
- Concurrent scans, retention days, team members, support level sourced from centralized config

## Security Fixes

### localStorage Data Isolation
- All localStorage keys now scoped by user ID (`key:${userId}` pattern)
- Prevents cross-account data leakage when multiple users share a browser
- **Affected keys:**
  - `blocksecops_scanner_preferences` -> `blocksecops_scanner_preferences:${userId}`
  - `blocksecops_scanner_defaults` -> `blocksecops_scanner_defaults:${userId}`
  - `upgrade-banner-dismissed` -> `upgrade-banner-dismissed:${userId}`
  - `blocksecops-current-org` -> `blocksecops-current-org:${userId}`
- One-time migration moves existing unscoped data to scoped keys
- Legacy unscoped keys cleaned up on logout

## New Features

### Invite Members Card on Billing Page
- New `InviteMemberCard` component on Billing page
- Email input, role selector (developer/auditor/admin), seat availability indicator
- Pending invitations list with cancel buttons
- Only visible to organization owner/admin
- Uses `POST /organizations/{id}/invites` API

### Tier Change Modal
- "Change Plan" button on SubscriptionCard
- `TierChangeModal` shows available tiers with proration preview
- Uses `GET /billing/subscription/change-tier/preview` and `POST /billing/subscription/change-tier`

### Centralized Tier Config Integration
- `PLAN_TIERS` in `billing.ts` now derived from `@blocksecops/tier-config` via `buildPlanTiers()`
- `Pricing.tsx` uses `getPricingTable()`, `generateFeatureComparisonRows()`, `generateQuotaComparisonRows()`
- Eliminates hardcoded pricing/feature data — single source of truth in `tiers.json`

## Files Modified

| File | Change |
|------|--------|
| `src/lib/api/users.ts` | Fix quota field names to match API |
| `src/contexts/AuthContext.tsx` | Update initial quota field names, add legacy key cleanup |
| `src/components/settings/QuotaUsageCard.tsx` | Use new field names + tier-config |
| `src/hooks/useQuota.ts` | Use new field names |
| `src/lib/api/billing.ts` | Replace hardcoded PLAN_TIERS with tier-config |
| `src/components/billing/SubscriptionCard.tsx` | Dynamic tier access |
| `src/pages/Pricing.tsx` | Use tier-config for all pricing data |
| `src/lib/storage/scannerPreferences.ts` | Scope by userId |
| `src/components/common/UpgradeBanner.tsx` | Scope by userId |
| `src/contexts/OrganizationContext.tsx` | Scope by userId |
| `src/App.tsx` | Init scanner preferences with userId |
| `src/lib/api/invites.ts` | NEW: invite API client |
| `src/components/billing/InviteMemberCard.tsx` | NEW: invite UI component |
| `src/pages/Billing.tsx` | Add InviteMemberCard |
| `package.json` | Version 0.41.5 -> 0.42.0 |
| `k8s/overlays/local/kustomization.yaml` | newTag 0.42.0 |

## API Service Changes

| File | Change |
|------|--------|
| `billing.py` `/billing/plans` endpoint | Updated to match tiers.json v3.2 values |

## Documentation Created

| File | Description |
|------|-------------|
| `docs/workflows/billing-subscription-workflow.md` | Feature resolution chain, field mapping, invite flow, localStorage isolation |
| `docs/pipelines/billing-feature-pipeline.md` | Step-by-step pipeline for tier feature changes |

## Verification

1. Log in as enterprise user -> Billing -> Export Reports and Webhooks show green check
2. Compare Pricing page with `tiers.json` — values match
3. Log in as user A -> set preferences -> log out -> log in as user B -> preferences empty
4. Billing page -> Invite Member -> send invite -> appears in pending list
5. `GET /billing/plans` values match `tiers.json`
