# Billing & Subscription Workflow

**Version:** 1.0.0
**Last Updated:** March 13, 2026

## Overview

Documents how tier features flow from the centralized configuration to the user's billing page, and how the invite system works.

## Feature Resolution Chain

```
tiers.json (source of truth)
    |
    ├── @blocksecops/tier-config (TypeScript bindings)
    |       |
    |       ├── Dashboard: QuotaUsageCard, Pricing.tsx, billing.ts
    |       └── Dashboard: UpgradeBanner, TierGate
    |
    └── API: /billing/plans endpoint (manually synced values)
            |
            └── API: UserQuotaModel → GET /users/me/enhanced
                    |
                    └── Dashboard: EnhancedUser.quota
```

### Field Mapping: API → Dashboard

| API Field (`QuotaInfo`) | Dashboard Field (`EnhancedUser.quota`) |
|------------------------|----------------------------------------|
| `export_enabled` | `export_enabled` |
| `webhooks_enabled` | `webhooks_enabled` |
| `api_access_enabled` | `api_access_enabled` |
| `scan_priority` | `scan_priority` |
| `quota_reset_at` | `quota_reset_at` |
| `monthly_scan_limit` | `monthly_scan_limit` |
| `monthly_scans_used` | `monthly_scans_used` |

Fields like `max_team_members`, `retention_days`, `concurrent_scans_limit`, and `support_level` are derived from `@blocksecops/tier-config` on the dashboard side (not from the API quota response).

## Subscription & Usage Page

The billing page (`/billing`) displays:
1. **Organization card** with member list and seat allocation
2. **Invite Members card** (owner/admin only) for sending invitations
3. **Subscription card** with current plan and Stripe management
4. **Quota Usage card** with scan usage, feature checklist, and tier details

### Feature Display

Features show green check or grey X based on:
- **API-sourced flags**: `export_enabled`, `webhooks_enabled`, `api_access_enabled`
- **Tier-config flags**: `cicdIntegration`, `ssoSaml`, etc.
- **Tier-config quotas**: `concurrentScansLimit`, `resultRetentionDays`, `maxTeamMembers`

## Invite Flow

1. Org owner/admin opens Billing page
2. Enters email and selects role in the Invite Members card
3. Dashboard calls `POST /organizations/{id}/invites`
4. API creates invite with 7-day expiry, sends email
5. Invitee clicks link → `GET /invites/{token}` for details
6. Invitee accepts → `POST /invites/{token}/accept` creates membership
7. Pending invites appear in the card with cancel option

## localStorage Data Isolation

All localStorage keys are scoped by user ID to prevent cross-account data leakage:

| Key Pattern | Scope |
|------------|-------|
| `blocksecops_scanner_preferences:{userId}` | Scanner selection per project |
| `blocksecops_scanner_defaults:{userId}` | Language-default scanner selection |
| `upgrade-banner-dismissed:{userId}` | Banner dismissal state |
| `blocksecops-current-org:{userId}` | Current organization selection |
| `blocksecops-sidebar-collapsed:{userId}` | Sidebar collapse state |
| `blocksecops-quick-access:{userId}` | Quick access pins |
| `contract-section-preferences:{userId}` | Contract detail section state |

On logout, legacy unscoped keys are cleaned up.

## Troubleshooting

### Feature shows grey X when it should be green check

1. Check API response: `GET /users/me/enhanced` → `quota.export_enabled`, `quota.webhooks_enabled`
2. Verify the API quota model reads from `UserQuotaModel` correctly
3. Verify `tiers.json` has the feature enabled for the user's tier
4. Check browser console for `[useQuota]` debug logs

### Pricing page shows wrong values

1. Verify `tiers.json` is up to date
2. Rebuild `@blocksecops/tier-config`: `cd blocksecops-shared/tier-config/typescript && npm run build`
3. Reinstall dashboard deps: `cd blocksecops-dashboard && npm install`
