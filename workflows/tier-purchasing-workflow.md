# Tier Purchasing Workflow

- **Version:** 1.0.0
- **Last Updated:** March 14, 2026
- **Status:** Active

## Overview

This document describes the end-to-end flow for purchasing a BlockSecOps subscription tier. The source of truth for tier definitions, pricing, quotas, and Stripe price IDs is always `tiers.json`. No prices or limits should be hardcoded outside that file.

## Purchasing Flow

1. User views the pricing page.
2. User selects a tier and clicks upgrade.
3. Dashboard calls the API to create a checkout session.
4. API looks up the Stripe price ID from `tiers.json` for the requested tier.
5. API creates a Stripe Checkout Session with the price ID and user metadata.
6. User is redirected to the Stripe hosted checkout page.
7. User completes payment on Stripe.
8. Stripe sends a `checkout.session.completed` webhook to the API.
9. API processes the webhook: validates metadata, updates `user.tier`, syncs quotas via `tier_change_handler`.
10. User sees the updated tier and quotas in the dashboard.

## ASCII Flow Diagram

```
  User                  Dashboard              API                    Stripe
   |                       |                    |                       |
   |  View pricing page    |                    |                       |
   |---------------------->|                    |                       |
   |                       | GET /billing/plans |                       |
   |                       |------------------->|                       |
   |                       |   (reads tiers.json|                       |
   |                       |    dynamically)    |                       |
   |                       |<-------------------|                       |
   |   Display plans       |                    |                       |
   |<----------------------|                    |                       |
   |                       |                    |                       |
   |  Select tier, click   |                    |                       |
   |  upgrade              |                    |                       |
   |---------------------->|                    |                       |
   |                       | POST /billing/     |                       |
   |                       |   checkout         |                       |
   |                       |  {plan_tier: "..."}|                       |
   |                       |------------------->|                       |
   |                       |                    | Create Checkout       |
   |                       |                    | Session (price ID     |
   |                       |                    | from tiers.json)      |
   |                       |                    |---------------------->|
   |                       |                    |   session_url         |
   |                       |                    |<----------------------|
   |                       |  redirect URL      |                       |
   |                       |<-------------------|                       |
   |  Redirect to Stripe   |                    |                       |
   |<----------------------|                    |                       |
   |                       |                    |                       |
   |  Complete payment     |                    |                       |
   |------------------------------------------------------>|           |
   |                       |                    |                       |
   |                       |                    | checkout.session      |
   |                       |                    |   .completed webhook  |
   |                       |                    |<----------------------|
   |                       |                    |                       |
   |                       |                    | Validate metadata     |
   |                       |                    | Update user.tier      |
   |                       |                    | Sync quotas via       |
   |                       |                    |   tier_change_handler |
   |                       |                    |                       |
   |  Updated tier + quotas|                    |                       |
   |<----------------------|                    |                       |
```

## Tier Pricing Table

All pricing, quotas, and features are defined in `tiers.json`. Refer to that file for current values. The table below shows the structure only:

```
+------------+------------------+------------------+---------------------+
| Tier       | Monthly Price    | Stripe Price ID  | Key Quotas          |
+------------+------------------+------------------+---------------------+
| Free       | See tiers.json   | See tiers.json   | See tiers.json      |
| Starter    | See tiers.json   | See tiers.json   | See tiers.json      |
| Growth     | See tiers.json   | See tiers.json   | See tiers.json      |
| Business   | See tiers.json   | See tiers.json   | See tiers.json      |
| Enterprise | See tiers.json   | See tiers.json   | See tiers.json      |
+------------+------------------+------------------+---------------------+
```

To view current pricing, run:

```bash
cat blocksecops-api-service/tiers.json | python3 -m json.tool
```

## API Endpoints

| Endpoint                | Method | Auth     | Description                              |
|-------------------------|--------|----------|------------------------------------------|
| `/billing/plans`        | GET    | Public   | Returns available plans from tiers.json  |
| `/billing/checkout`     | POST   | Required | Creates Stripe checkout session          |
| `/billing/webhook`      | POST   | Stripe   | Receives Stripe webhook events           |

### POST /billing/checkout

Request body:

```json
{
  "plan_tier": "growth"
}
```

The API looks up the corresponding Stripe price ID from `tiers.json` and creates a checkout session.

## Stripe Webhook Events Handled

| Event                            | Action                                                    |
|----------------------------------|-----------------------------------------------------------|
| `checkout.session.completed`     | Validates metadata, updates user.tier, syncs quotas       |
| `invoice.payment_succeeded`      | Confirms payment, ensures tier remains active             |
| `invoice.payment_failed`         | Flags account, may trigger grace period or downgrade      |
| `customer.subscription.deleted`  | Resets user to free tier, removes paid features           |

## Error Handling

- If the Stripe price ID in `tiers.json` is invalid, the checkout session creation fails and returns a 500 error.
- If the webhook signature validation fails, the API returns 400 and does not process the event.
- If `tier_change_handler` fails to sync quotas, the error is logged and an alert is raised. The tier update is still persisted so it can be reconciled.

## Related Documentation

- [Tier Upgrading Workflow](tier-upgrading-workflow.md)
- [Tier Testing Pipeline](../pipelines/tier-testing-pipeline.md)
- [Tier Testing Playbook](../playbooks/tier-testing.md)
- `tiers.json` -- source of truth for all tier definitions
