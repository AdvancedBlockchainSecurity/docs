# Tier Upgrading Workflow

- **Version:** 1.0.0
- **Last Updated:** March 14, 2026
- **Status:** Active

## Overview

This document describes the flow for upgrading or downgrading a BlockSecOps subscription tier. The source of truth for tier definitions, pricing, quotas, and Stripe price IDs is always `tiers.json`. Upgrades and downgrades are handled through Stripe subscription modifications with proration.

## Upgrade/Downgrade Flow

1. User views their current subscription details.
2. User previews the cost of changing to a different tier.
3. API returns a proration preview showing the prorated amount and effective date.
4. User confirms the tier change.
5. API updates the Stripe subscription to the new price ID from `tiers.json`.
6. Stripe sends a `customer.subscription.updated` webhook.
7. API processes the webhook: `tier_change_handler` updates the tier and syncs quotas.
8. On downgrade: features are removed immediately and quotas are reduced to the new tier limits.

## ASCII Flow Diagram

```
  User                  Dashboard              API                    Stripe
   |                       |                    |                       |
   |  View subscription    |                    |                       |
   |---------------------->|                    |                       |
   |                       | GET /billing/      |                       |
   |                       |   subscription     |                       |
   |                       |------------------->|                       |
   |                       |  current tier,     |                       |
   |                       |  quotas, billing   |                       |
   |                       |<-------------------|                       |
   |  Display current plan |                    |                       |
   |<----------------------|                    |                       |
   |                       |                    |                       |
   |  Preview tier change  |                    |                       |
   |---------------------->|                    |                       |
   |                       | GET /billing/      |                       |
   |                       |   subscription/    |                       |
   |                       |   change-tier/     |                       |
   |                       |   preview?target_  |                       |
   |                       |   tier=growth      |                       |
   |                       |------------------->|                       |
   |                       |                    | Retrieve upcoming     |
   |                       |                    | invoice preview       |
   |                       |                    |---------------------->|
   |                       |                    |  proration details    |
   |                       |                    |<----------------------|
   |                       |  prorated amount,  |                       |
   |                       |  effective date    |                       |
   |                       |<-------------------|                       |
   |  Display preview      |                    |                       |
   |<----------------------|                    |                       |
   |                       |                    |                       |
   |  Confirm change       |                    |                       |
   |---------------------->|                    |                       |
   |                       | POST /billing/     |                       |
   |                       |   subscription/    |                       |
   |                       |   change-tier      |                       |
   |                       |  {target_tier:     |                       |
   |                       |   "growth"}        |                       |
   |                       |------------------->|                       |
   |                       |                    | Update subscription   |
   |                       |                    | to new price ID       |
   |                       |                    | (from tiers.json)     |
   |                       |                    |---------------------->|
   |                       |                    |  subscription updated |
   |                       |                    |<----------------------|
   |                       |  success           |                       |
   |                       |<-------------------|                       |
   |  Confirmation         |                    |                       |
   |<----------------------|                    |                       |
   |                       |                    |                       |
   |                       |                    | customer.subscription |
   |                       |                    |   .updated webhook    |
   |                       |                    |<----------------------|
   |                       |                    |                       |
   |                       |                    | tier_change_handler:  |
   |                       |                    |   update user.tier    |
   |                       |                    |   sync quotas         |
   |                       |                    |                       |
   |  Tier + quotas updated|                    |                       |
   |<----------------------|                    |                       |
```

## API Endpoints

| Endpoint                                        | Method | Auth     | Description                                   |
|-------------------------------------------------|--------|----------|-----------------------------------------------|
| `/billing/subscription`                         | GET    | Required | Returns current subscription details          |
| `/billing/subscription/change-tier/preview`     | GET    | Required | Returns proration preview for a tier change   |
| `/billing/subscription/change-tier`             | POST   | Required | Executes the tier change                      |

### GET /billing/subscription/change-tier/preview

Query parameters:

```
?target_tier=growth
```

Response:

```json
{
  "current_tier": "starter",
  "target_tier": "growth",
  "prorated_amount_cents": 2450,
  "currency": "usd",
  "effective_date": "2026-03-14T00:00:00Z",
  "next_billing_date": "2026-04-01T00:00:00Z",
  "description": "Prorated upgrade from Starter to Growth"
}
```

### POST /billing/subscription/change-tier

Request body:

```json
{
  "target_tier": "growth"
}
```

## Proration Example

Assume a user is on the Starter tier and upgrades to Growth mid-billing cycle. Refer to `tiers.json` for actual prices.

```
Billing cycle:       March 1 -- March 31 (31 days)
Change date:         March 15 (16 days remaining)

Credit for unused Starter:
  (Starter monthly price) * (16 / 31) = credit amount

Charge for remaining Growth:
  (Growth monthly price) * (16 / 31) = charge amount

Prorated amount due = charge amount - credit amount
```

The exact amounts depend on the prices defined in `tiers.json`. The preview endpoint returns the calculated proration so the user sees the exact cost before confirming.

## Upgrade vs Downgrade Behavior

```
+-------------------+----------------------------+----------------------------+
| Aspect            | Upgrade                    | Downgrade                  |
+-------------------+----------------------------+----------------------------+
| Timing            | Effective immediately      | Effective immediately      |
+-------------------+----------------------------+----------------------------+
| Billing           | Prorated charge for the    | Prorated credit applied    |
|                   | remaining billing period   | to next invoice            |
+-------------------+----------------------------+----------------------------+
| Features          | New features available     | Higher-tier features       |
|                   | immediately                | removed immediately        |
+-------------------+----------------------------+----------------------------+
| Quotas            | Quotas increased to new    | Quotas reduced to new      |
|                   | tier limits immediately    | tier limits immediately    |
+-------------------+----------------------------+----------------------------+
| Existing data     | All data retained          | Data exceeding new limits  |
|                   |                            | is retained but read-only  |
+-------------------+----------------------------+----------------------------+
| API rate limits   | Increased immediately      | Reduced immediately        |
+-------------------+----------------------------+----------------------------+
| Feature gates     | require_tier() allows      | require_tier() returns 403 |
|                   | access to new tier         | for features above new tier|
+-------------------+----------------------------+----------------------------+
```

## Stripe Webhook Events Handled

| Event                              | Action                                                  |
|------------------------------------|---------------------------------------------------------|
| `customer.subscription.updated`    | Detects tier change, runs tier_change_handler            |
| `invoice.payment_succeeded`        | Confirms proration payment processed                    |
| `invoice.payment_failed`           | Flags account, may revert tier change                   |

## Edge Cases

- **Same tier request:** API returns 400 if `target_tier` matches the current tier.
- **Free tier downgrade:** Cancels the Stripe subscription entirely and resets to free tier.
- **Pending invoice:** If a previous proration invoice is unpaid, the tier change is blocked until payment is resolved.
- **Concurrent changes:** The API uses optimistic locking to prevent race conditions when multiple tier change requests arrive simultaneously.

## Related Documentation

- [Tier Purchasing Workflow](tier-purchasing-workflow.md)
- [Tier Testing Pipeline](../pipelines/tier-testing-pipeline.md)
- [Tier Testing Playbook](../playbooks/tier-testing.md)
- `tiers.json` -- source of truth for all tier definitions
