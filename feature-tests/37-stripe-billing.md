# Feature Test: Stripe Billing Integration

**Feature**: Phase 8a - Stripe Billing & Invoices
**Status**: ✅ Local Testing Ready
**Last Updated**: 2026-02-03

## Overview

Stripe integration for subscription billing alongside x402 credit purchases.

## Prerequisites

- [x] Stripe account configured (Test mode)
- [ ] Stripe Products/Prices created for all tiers
- [x] `STRIPE_API_KEY` in Vault (`secret/local/api-service/stripe`)
- [x] `STRIPE_WEBHOOK_SECRET` in Vault
- [ ] Dashboard rebuilt with `VITE_STRIPE_PUBLISHABLE_KEY`
- [x] Stripe CLI installed for local testing

## Local Testing Setup (kubeadm Server)

### 1. Verify Vault Secrets

```bash
# Get Vault root token
ROOT_TOKEN=$(kubectl exec vault-0 -n vault-local -- cat /vault/data/.vault-init.json 2>/dev/null | jq -r '.root_token')

# Check Stripe secrets
kubectl exec vault-0 -n vault-local -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault kv get secret/local/api-service/stripe"
```

### 2. Start Webhook Forwarding

```bash
# Forward webhooks to kubeadm NodePort (192.168.86.225:30180)
~/bin/stripe listen \
  --api-key "YOUR_STRIPE_SECRET_KEY" \
  --forward-to http://192.168.86.225:30180/api/v1/webhooks/stripe

# The webhook signing secret is displayed - store it in Vault if different
```

### 3. Rebuild Dashboard (if needed)

```bash
cd /home/pwner/Git
STRIPE_PK="pk_test_YOUR_PUBLISHABLE_KEY"

docker build --no-cache \
  -f blocksecops-dashboard/Dockerfile \
  --build-arg VITE_STRIPE_PUBLISHABLE_KEY=${STRIPE_PK} \
  --build-arg VITE_SUPABASE_URL=$(kubectl get cm dashboard-config -n dashboard-local -o jsonpath='{.data.supabase_url}') \
  --build-arg VITE_SUPABASE_ANON_KEY=$(kubectl get cm dashboard-config -n dashboard-local -o jsonpath='{.data.supabase_anon_key}') \
  -t harbor.0xapogee.local/blocksecops/dashboard:latest .

docker push harbor.0xapogee.local/blocksecops/dashboard:latest
kubectl rollout restart deployment/dashboard -n dashboard-local
```

### 4. Access Dashboard

- **kubeadm**: http://app.0xapogee.local or http://192.168.86.225
- **minikube**: http://127.0.0.1:3000

## Test Cases

### TC-37-001: Create Checkout Session
**Priority**: High
**Status**: ⏳ Pending

**Steps**:
1. Login to dashboard
2. Navigate to Billing → View Plans
3. Select "Growth" plan (monthly)
4. Click "Subscribe"
5. Verify redirect to Stripe Checkout

**Expected Result**:
- Redirects to Stripe Checkout page
- Shows correct plan and price ($699/month)
- Can complete payment with test card

**Test Data**:
- Test card (success): `4242 4242 4242 4242`
- Test card (decline): `4000 0000 0000 9995`
- Expiry: Any future date
- CVC: Any 3 digits

---

### TC-37-002: Subscription Created After Payment
**Priority**: High
**Status**: ⏳ Pending

**Steps**:
1. Complete checkout with test card
2. Wait for redirect back to app
3. Check Billing page

**Expected Result**:
- Subscription appears in Billing page
- Status shows "Active"
- Plan tier shows "Growth"
- Current period dates are correct
- User's tier updated in database

**Verification**:
```sql
SELECT plan_tier, status, current_period_end
FROM subscriptions
WHERE user_id = 'user-uuid';
```

---

### TC-37-003: View Stripe Invoices
**Priority**: Medium
**Status**: ⏳ Pending

**Steps**:
1. Login with active subscription
2. Navigate to Billing
3. View Billing History (filter: Subscriptions)
4. Click download on an invoice

**Expected Result**:
- Invoices list shows Stripe subscription invoices
- Download opens Stripe-hosted PDF
- Invoice shows correct amount and period

---

### TC-37-004: Cancel Subscription
**Priority**: High
**Status**: ⏳ Pending

**Steps**:
1. Login with active subscription
2. Navigate to Billing
3. Click "Cancel subscription"
4. Confirm cancellation

**Expected Result**:
- Warning shows cancellation date
- After confirm: `cancel_at_period_end = true`
- Status remains "Active" until period end
- User can reactivate before period end

---

### TC-37-005: Reactivate Subscription
**Priority**: Medium
**Status**: ⏳ Pending

**Steps**:
1. Login with subscription scheduled for cancellation
2. Navigate to Billing
3. Click "Reactivate subscription"

**Expected Result**:
- Cancellation notice disappears
- `cancel_at_period_end = false`
- Subscription continues normally

---

### TC-37-006: Stripe Customer Portal
**Priority**: Medium
**Status**: ⏳ Pending

**Steps**:
1. Login with active subscription
2. Navigate to Billing
3. Click "Manage Payment Method"
4. Verify redirect to Stripe Portal

**Expected Result**:
- Opens Stripe Customer Portal
- Can update payment method
- Can view invoices
- Return URL works correctly

---

### TC-37-007: Update Billing Details
**Priority**: Medium
**Status**: ⏳ Pending

**Steps**:
1. Login to dashboard
2. Navigate to Billing
3. Update company name, address, tax ID
4. Save changes

**Expected Result**:
- Details saved successfully
- Appear on next x402 receipt
- (Stripe invoices update via portal)

---

### TC-37-008: Combined Billing History
**Priority**: Medium
**Status**: ⏳ Pending

**Steps**:
1. Create user with both:
   - Stripe subscription
   - x402 credit purchase
2. Navigate to Billing → Billing History

**Expected Result**:
- Shows both invoice types
- Filter "All" shows both
- Filter "Subscriptions" shows Stripe only
- Filter "Credits" shows x402 only
- Download works for both types

---

### TC-37-009: x402 Receipt Download
**Priority**: High
**Status**: ⏳ Pending

**Steps**:
1. Login with verified x402 payment
2. Navigate to Billing → Billing History
3. Filter by "Credits"
4. Click download on x402 receipt

**Expected Result**:
- PDF downloads with format `blocksecops-receipt-BSO-YYMMDD-XXXX.pdf`
- Contains:
  - Receipt number
  - BlockSecOps info
  - User billing details
  - Purchase details (credits, amount)
  - Blockchain verification (tx hash, block, explorer link)

---

### TC-37-010: Webhook - Payment Failed
**Priority**: High
**Status**: ⏳ Pending

**Steps**:
1. Trigger payment failure (test mode)
   - Use card `4000 0000 0000 0341` (requires authentication)
   - Or manually via Stripe Dashboard
2. Check subscription status

**Expected Result**:
- Subscription status changes to `past_due`
- User can still access features (grace period)
- Stripe sends payment retry emails

---

### TC-37-011: Webhook - Subscription Deleted
**Priority**: High
**Status**: ⏳ Pending

**Steps**:
1. Cancel subscription immediately via Stripe Dashboard
2. Check local subscription record

**Expected Result**:
- Status changes to `canceled`
- User tier reverts to `free`
- Quota limits enforced

---

### TC-37-012: Plan Upgrade
**Priority**: Medium
**Status**: ⏳ Pending

**Steps**:
1. Login with Team plan
2. Navigate to Billing → View Plans
3. Select "Growth" plan
4. Complete checkout

**Expected Result**:
- Stripe handles proration
- New subscription created
- Old subscription marked as upgraded
- User tier updated immediately

---

### TC-37-013: Annual vs Monthly Billing
**Priority**: Medium
**Status**: ⏳ Pending

**Steps**:
1. Select Growth plan (annual)
2. Verify pricing shows annual rate
3. Complete checkout

**Expected Result**:
- Checkout shows annual price
- `billing_interval = 'annual'`
- `current_period_end` is 1 year out
- Correct savings displayed

---

### TC-37-014: Tier Change via Change Plan Modal (v0.42.0)
**Priority**: High
**Status**: ⏳ Pending

**Steps**:
1. Login with active subscription (e.g., Team plan)
2. Navigate to Billing
3. Click "Change Plan" button on SubscriptionCard
4. TierChangeModal opens showing available tiers
5. Select a different tier (e.g., Growth)
6. Preview proration costs
7. Confirm tier change

**Expected Result**:
- TierChangeModal shows all available tiers
- Current tier is highlighted/indicated
- Proration preview shows correct amounts via `GET /billing/subscription/change-tier/preview`
- Confirmation executes `POST /billing/subscription/change-tier`
- Subscription updates to new tier
- SubscriptionCard reflects new plan after success callback

---

### TC-37-015: Billing Page Invite Members (v0.42.0)
**Priority**: Medium
**Status**: ⏳ Pending

**Steps**:
1. Login as organization owner/admin
2. Navigate to Billing page
3. Locate InviteMemberCard below Organization card
4. Enter email address and select role
5. Click "Send Invite"
6. Verify pending invite appears in list
7. Cancel pending invite

**Expected Result**:
- InviteMemberCard visible for owner/admin only
- Seat usage indicator shows current/max members
- Email + role form submits to `POST /organizations/{id}/invites`
- Pending invitations list shows with cancel buttons
- Cancel removes invite via `DELETE /organizations/{id}/invites/{inviteId}`

---

### TC-37-016: Billing Feature Display Fix (v0.42.0)
**Priority**: High
**Status**: ⏳ Pending

**Steps**:
1. Login as enterprise tier user
2. Navigate to Billing > Subscription & Usage
3. Check QuotaUsageCard feature list

**Expected Result**:
- Export Reports shows green check (not grey X)
- Webhooks shows green check (not grey X)
- API Access shows green check (not grey X)
- Feature display sourced from API `export_enabled`, `webhooks_enabled`, `api_access_enabled` fields
- Supplementary data (retention, team members, support) from `@blocksecops/tier-config`

---

## Webhook Testing

### Simulate Webhooks (Stripe CLI)

```bash
# Trigger checkout.session.completed
stripe trigger checkout.session.completed

# Trigger subscription.updated
stripe trigger customer.subscription.updated

# Trigger invoice.payment_failed
stripe trigger invoice.payment_failed
```

### Verify Webhook Receipt

```bash
# Check API service logs
kubectl logs -n api-service-local deployment/api-service -f | grep webhook

# Check database
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security -c \
  "SELECT id, status, plan_tier FROM subscriptions ORDER BY created_at DESC LIMIT 5;"
```

---

## Test Cards Reference

| Scenario | Card Number |
|----------|-------------|
| Success | 4242 4242 4242 4242 |
| Declined | 4000 0000 0000 9995 |
| Requires Auth | 4000 0000 0000 3220 |
| Insufficient Funds | 4000 0000 0000 9995 |

---

## Known Limitations

1. **Local Testing**: Webhooks require Stripe CLI forwarding
2. **Production**: Need public HTTPS endpoint for webhooks
3. **Enterprise**: Custom invoicing not yet implemented
4. **Tax**: Stripe Tax not enabled (optional)

---

## Related Documentation

- [API Endpoints Reference](/docs/api/endpoints-reference.md#billing-phase-8a---stripe-integration)
- [Phase 8a Task Docs](/TaskDocs-BlockSecOps/phases/08a-phase-8a-stripe-billing-invoices/)
- [User Guide: Invoices & Receipts](/blocksecops-docs/billing/invoices-receipts.md)
- [Billing Subscription Workflow](/docs/workflows/billing-subscription-workflow.md) - Feature resolution chain, field mapping, invite flow
- [Billing Feature Pipeline](/docs/pipelines/billing-feature-pipeline.md) - Pipeline for tier feature changes
