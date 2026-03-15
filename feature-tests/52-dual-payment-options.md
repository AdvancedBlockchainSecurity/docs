# Feature Test: Payment Options (Stripe Only)

**Feature**: Stripe Card Payment for Subscriptions and Credits
**Status**: Active
**Last Updated**: 2026-03-15
**Version**: 0.47.2

## Overview

The pricing page supports card payments via Stripe Checkout. Crypto/x402 payment option was removed in v0.47.0.

## Prerequisites

### Backend
- [ ] Stripe API configured (`STRIPE_API_KEY` in Vault)
- [ ] Stripe Webhook Secret configured (`STRIPE_WEBHOOK_SECRET` in Vault)
- [ ] Billing API endpoints available at `/api/v1/billing/*`

### Frontend
- [ ] `VITE_STRIPE_PUBLISHABLE_KEY` baked into image via build arg
- [ ] Dashboard version 0.47.2+ deployed

### Verification
```bash
# Check dashboard version
kubectl get deployment -n dashboard-prod dashboard -o jsonpath='{.spec.template.spec.containers[0].image}'

# Verify Stripe key loaded (no console warning)
# Browser console should NOT show: "VITE_STRIPE_PUBLISHABLE_KEY not set"
```

---

## Test Cases

### TC-52-001: Pricing Page Display
**Priority**: High

**Steps**:
1. Navigate to `/pricing` page
2. Click "Upgrade" on any tier

**Expected Result**:
- Payment modal opens
- Stripe card payment form loads
- No crypto/wallet payment tab visible

---

### TC-52-002: Card Payment - Stripe Checkout Redirect
**Priority**: High

**Steps**:
1. Navigate to Pricing page
2. Click "Upgrade" on Growth tier
3. Click "Pay with Card"

**Expected Result**:
- Redirects to Stripe Checkout page
- Checkout shows correct plan (Growth)
- Checkout shows correct price
- Can complete with test card: `4242 4242 4242 4242`

**Test Data**:
- Test card (success): `4242 4242 4242 4242`
- Expiry: Any future date
- CVC: Any 3 digits

---

### TC-52-003: Card Payment - Success Redirect
**Priority**: High

**Steps**:
1. Complete Stripe Checkout with test card
2. Wait for redirect back to app

**Expected Result**:
- Redirects to `/pricing?success=true&tier=growth`
- Success toast appears: "Successfully upgraded!"
- User credits/tier updated
- URL params cleared after toast

---

### TC-52-004: Card Payment - Canceled Redirect
**Priority**: Medium

**Steps**:
1. Start Stripe Checkout
2. Click "Back" or close the Stripe page

**Expected Result**:
- Redirects to `/pricing?canceled=true`
- Info toast appears: "Payment was canceled."
- URL params cleared after toast
- No subscription created

---

### TC-52-005: Annual vs Monthly Billing Toggle
**Priority**: Medium

**Steps**:
1. Navigate to Pricing page
2. Toggle between Monthly and Annual billing
3. Click Upgrade on a tier
4. Complete card payment

**Expected Result**:
- Prices update when toggling billing period
- Checkout session created with correct `billing_interval`
- Annual shows discounted rate
- Subscription period matches selection

---

### TC-52-006: Free Tier - No Payment Required
**Priority**: Medium

**Steps**:
1. Navigate to Pricing as non-authenticated user
2. Click on Free tier

**Expected Result**:
- No payment modal opens
- Redirects to signup/login flow
- Free tier automatically assigned after signup

---

### TC-52-007: Already Subscribed - Manage Subscription
**Priority**: Medium

**Steps**:
1. Login with account that has active Stripe subscription
2. Navigate to Pricing page
3. Click on current tier

**Expected Result**:
- Shows "Current Plan" indicator
- Option to manage subscription (Stripe Portal)
- Option to upgrade to higher tier

---

## API Endpoints Tested

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/billing/checkout` | POST | Create Stripe Checkout session |
| `/api/v1/billing/portal` | POST | Create Stripe Customer Portal session |
| `/api/v1/billing/subscription/current` | GET | Get current subscription |
| `/api/v1/credits/balance` | GET | Get credit balance |

---

## Security Considerations

- [ ] Stripe publishable key only (never secret key in frontend)
- [ ] Card data never touches our servers (PCI compliant)
- [ ] All transactions validated server-side
- [ ] Webhook signatures verified for Stripe events
- [ ] CSP allows `js.stripe.com`, `api.stripe.com`, `hooks.stripe.com`

---

## Related Documentation

- [Stripe Billing Tests](./37-stripe-billing.md)
- [Pricing Page Tests](./07-pricing-page.md)
