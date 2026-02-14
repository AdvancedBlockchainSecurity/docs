# Billing Endpoints

All billing endpoints are prefixed with `/api/v1/billing` and require authentication.

---

## GET /api/v1/billing/plans

Retrieve available plan tiers with features and x402 pricing.

```bash
curl -X GET https://api.blocksecops.com/api/v1/billing/plans \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "plans": [
    {
      "id": "free",
      "name": "Free",
      "price_usd": 0,
      "billing_period": "month",
      "features": {
        "scans_per_month": 3,
        "is_unlimited": false,
        "vulnerability_reports": true,
        "api_access": false,
        "priority_support": false,
        "custom_rules": false
      },
      "x402_price_usdc": "0"
    },
    {
      "id": "starter",
      "name": "Starter",
      "price_usd": 29,
      "billing_period": "month",
      "features": {
        "scans_per_month": 25,
        "is_unlimited": false,
        "vulnerability_reports": true,
        "api_access": true,
        "priority_support": false,
        "custom_rules": false
      },
      "x402_price_usdc": "29000000"
    },
    {
      "id": "professional",
      "name": "Professional",
      "price_usd": 99,
      "billing_period": "month",
      "features": {
        "scans_per_month": 100,
        "is_unlimited": false,
        "vulnerability_reports": true,
        "api_access": true,
        "priority_support": true,
        "custom_rules": true
      },
      "x402_price_usdc": "99000000"
    },
    {
      "id": "enterprise",
      "name": "Enterprise",
      "price_usd": 299,
      "billing_period": "month",
      "features": {
        "scans_per_month": -1,
        "is_unlimited": true,
        "vulnerability_reports": true,
        "api_access": true,
        "priority_support": true,
        "custom_rules": true,
        "dedicated_scanner": true,
        "sla_guarantee": true
      },
      "x402_price_usdc": "299000000"
    }
  ]
}
```

---

## GET /api/v1/billing/subscription

Retrieve the current subscription. Returns `null` if the user has no active subscription.

```bash
curl -X GET https://api.blocksecops.com/api/v1/billing/subscription \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "subscription": {
    "id": "sub_abc123",
    "plan_tier": "professional",
    "status": "active",
    "amount_usd": 99.00,
    "currency": "usd",
    "current_period_start": "2026-01-14T00:00:00Z",
    "current_period_end": "2026-02-14T00:00:00Z",
    "cancel_at_period_end": false,
    "stripe_subscription_id": "sub_stripe_xyz"
  }
}
```

**Response 200 (no subscription):**

```json
{
  "subscription": null
}
```

---

## GET /api/v1/billing/details

Retrieve billing details. Returns `null` if billing details have not been set.

```bash
curl -X GET https://api.blocksecops.com/api/v1/billing/details \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "details": {
    "company_name": "Acme Security Corp",
    "email": "billing@acme.com",
    "address": {
      "line1": "123 Main St",
      "line2": "Suite 400",
      "city": "San Francisco",
      "state": "CA",
      "postal_code": "94105",
      "country": "US"
    },
    "tax_id": "US12345678"
  }
}
```

---

## PUT /api/v1/billing/details

Update billing details.

```bash
curl -X PUT https://api.blocksecops.com/api/v1/billing/details \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "company_name": "Acme Security Corp",
    "email": "billing@acme.com",
    "address": {
      "line1": "123 Main St",
      "city": "San Francisco",
      "state": "CA",
      "postal_code": "94105",
      "country": "US"
    },
    "tax_id": "US12345678"
  }'
```

**Response 200:** Returns the updated billing details object.

---

## GET /api/v1/billing/history

Retrieve billing history.

```bash
curl -X GET "https://api.blocksecops.com/api/v1/billing/history?page=1&limit=25" \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "items": [
    {
      "id": "bh_001",
      "type": "subscription_payment",
      "amount_usd": 99.00,
      "status": "succeeded",
      "description": "Professional plan - February 2026",
      "created_at": "2026-02-01T00:00:00Z"
    },
    {
      "id": "bh_002",
      "type": "credit_purchase",
      "amount_usd": 125.00,
      "status": "succeeded",
      "description": "Builder credit package (50 credits)",
      "created_at": "2026-01-20T14:30:00Z"
    }
  ],
  "total": 12
}
```

---

## GET /api/v1/billing/invoices

Retrieve invoices.

```bash
curl -X GET "https://api.blocksecops.com/api/v1/billing/invoices?page=1&limit=25" \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "invoices": [
    {
      "id": "inv_abc123",
      "number": "INV-2026-0042",
      "amount_usd": 99.00,
      "status": "paid",
      "period_start": "2026-01-14T00:00:00Z",
      "period_end": "2026-02-14T00:00:00Z",
      "pdf_url": "/api/v1/billing/invoices/inv_abc123/pdf",
      "created_at": "2026-02-01T00:00:00Z"
    }
  ],
  "total": 6
}
```

---

## GET /api/v1/billing/invoices/{invoice_id}/pdf

Download an invoice as a PDF file.

```bash
curl -X GET https://api.blocksecops.com/api/v1/billing/invoices/inv_abc123/pdf \
  -H "Authorization: Bearer <token>" \
  -o invoice.pdf
```

**Response 200:** Binary PDF file with `Content-Type: application/pdf`.

---

## GET /api/v1/billing/plan-limit

Retrieve the current plan's scan limits.

```bash
curl -X GET https://api.blocksecops.com/api/v1/billing/plan-limit \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "plan_tier": "professional",
  "scans_per_month": 100,
  "is_unlimited": false,
  "scans_used_this_month": 42,
  "scans_remaining": 58,
  "period_resets_at": "2026-03-14T00:00:00Z"
}
```

---

## POST /api/v1/billing/checkout

Create a Stripe checkout session for a new subscription.

```bash
curl -X POST https://api.blocksecops.com/api/v1/billing/checkout \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "plan_tier": "professional",
    "billing_period": "month",
    "success_url": "https://app.blocksecops.com/billing/success",
    "cancel_url": "https://app.blocksecops.com/billing/cancel"
  }'
```

**Response 200:**

```json
{
  "checkout_url": "https://checkout.stripe.com/c/pay/cs_live_abc123",
  "session_id": "cs_live_abc123",
  "expires_at": "2026-02-14T13:00:00Z"
}
```

---

## POST /api/v1/billing/portal

Create a Stripe customer portal session for managing payment methods and invoices.

```bash
curl -X POST https://api.blocksecops.com/api/v1/billing/portal \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "return_url": "https://app.blocksecops.com/billing"
  }'
```

**Response 200:**

```json
{
  "portal_url": "https://billing.stripe.com/p/session/abc123",
  "expires_at": "2026-02-14T13:00:00Z"
}
```

---

## POST /api/v1/billing/subscription/cancel

Cancel the current subscription. Cancellation takes effect at the end of the billing period.

```bash
curl -X POST https://api.blocksecops.com/api/v1/billing/subscription/cancel \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "reason": "Switching to a different tool",
    "feedback": "Great product but no longer needed"
  }'
```

**Response 200:**

```json
{
  "subscription_id": "sub_abc123",
  "status": "active",
  "cancel_at_period_end": true,
  "current_period_end": "2026-03-14T00:00:00Z",
  "message": "Subscription will be cancelled at the end of the current billing period"
}
```

---

## POST /api/v1/billing/subscription/change-tier

Change the subscription plan tier (upgrade or downgrade).

```bash
curl -X POST https://api.blocksecops.com/api/v1/billing/subscription/change-tier \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "new_tier": "enterprise"
  }'
```

**Response 200:**

```json
{
  "subscription_id": "sub_abc123",
  "previous_tier": "professional",
  "new_tier": "enterprise",
  "proration_amount_usd": 133.33,
  "effective_immediately": true,
  "next_billing_amount_usd": 299.00
}
```

---

## GET /api/v1/billing/subscription/change-tier/preview

Preview the effects of changing the subscription tier before committing.

```bash
curl -X GET "https://api.blocksecops.com/api/v1/billing/subscription/change-tier/preview?new_tier=enterprise" \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "current_tier": "professional",
  "new_tier": "enterprise",
  "proration_amount_usd": 133.33,
  "next_billing_amount_usd": 299.00,
  "next_billing_date": "2026-03-14T00:00:00Z",
  "immediate_charge_usd": 133.33,
  "features_gained": ["dedicated_scanner", "sla_guarantee"],
  "features_lost": []
}
```

---

## POST /api/v1/billing/subscription/reactivate

Reactivate a subscription that was set to cancel at the end of the billing period.

```bash
curl -X POST https://api.blocksecops.com/api/v1/billing/subscription/reactivate \
  -H "Authorization: Bearer <token>"
```

**Response 200:**

```json
{
  "subscription_id": "sub_abc123",
  "status": "active",
  "cancel_at_period_end": false,
  "message": "Subscription has been reactivated"
}
```
