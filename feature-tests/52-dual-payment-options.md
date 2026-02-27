# Feature Test: Dual Payment Options (Stripe + Crypto)

**Feature**: Wallet Connection & Credit Purchase with Dual Payment Options
**Status**: Ready for Testing
**Last Updated**: 2026-02-01
**Version**: 0.36.0

## Overview

The pricing page now supports dual payment options allowing users to choose between:
- **Card Payment**: Stripe Checkout for credit card subscriptions
- **Crypto Payment**: x402 protocol with USDC on Base network

## Prerequisites

### Backend
- [ ] Stripe API configured (`STRIPE_API_KEY` in Vault)
- [ ] Stripe Webhook Secret configured (`STRIPE_WEBHOOK_SECRET` in Vault)
- [ ] x402 payment endpoints operational
- [ ] Billing API endpoints available at `/api/v1/billing/*`

### Frontend
- [ ] `VITE_STRIPE_PUBLISHABLE_KEY` set in environment
- [ ] `VITE_WALLETCONNECT_PROJECT_ID` set in environment
- [ ] Dashboard version 0.36.0+ deployed

### Verification
```bash
# Check dashboard version
kubectl get deployment -n dashboard-local dashboard -o jsonpath='{.spec.template.spec.containers[0].image}'
# Should show: harbor.0xapogee.local/blocksecops/dashboard:0.36.0

# Check Stripe key is configured
kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.VITE_STRIPE_PUBLISHABLE_KEY}'
```

---

## Test Cases

### TC-52-001: Payment Method Selector Display
**Priority**: High
**Status**: Pending

**Steps**:
1. Navigate to `/pricing` page
2. Click "Buy Credits" or "Upgrade" on any tier
3. Observe the payment modal

**Expected Result**:
- Payment modal opens
- Two tabs visible: "Card" and "Crypto"
- Card tab selected by default
- Tab icons display correctly (credit card, wallet)

---

### TC-52-002: Switch Between Payment Methods
**Priority**: High
**Status**: Pending

**Steps**:
1. Open payment modal
2. Click "Crypto" tab
3. Click "Card" tab
4. Repeat switching

**Expected Result**:
- Tab selection is responsive
- Content area updates to show appropriate payment UI
- Card tab shows "Pay with Card" button
- Crypto tab shows wallet connection info

---

### TC-52-003: Card Payment - Stripe Checkout Redirect
**Priority**: High
**Status**: Pending

**Steps**:
1. Navigate to Pricing page
2. Click "Upgrade" on Growth tier
3. Ensure "Card" payment method selected
4. Click "Pay with Card"

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

### TC-52-004: Card Payment - Success Redirect
**Priority**: High
**Status**: Pending

**Steps**:
1. Complete Stripe Checkout with test card
2. Wait for redirect back to app

**Expected Result**:
- Redirects to `/pricing?success=true&tier=growth`
- Success toast appears: "Successfully upgraded!"
- User credits/tier updated
- URL params cleared after toast

**Verification**:
```sql
SELECT plan_tier, status FROM subscriptions WHERE user_id = 'user-uuid';
```

---

### TC-52-005: Card Payment - Canceled Redirect
**Priority**: Medium
**Status**: Pending

**Steps**:
1. Start Stripe Checkout
2. Click "Back" or close the Stripe page

**Expected Result**:
- Redirects to `/pricing?canceled=true`
- Info toast appears: "Payment was canceled."
- URL params cleared after toast
- No subscription created

---

### TC-52-006: Crypto Payment - Wallet Connection
**Priority**: High
**Status**: Pending

**Steps**:
1. Open payment modal
2. Select "Crypto" tab
3. Click "Connect Wallet" (if not connected)
4. Connect with MetaMask or WalletConnect

**Expected Result**:
- Wallet connection modal appears
- Can connect via MetaMask browser extension
- Can connect via WalletConnect QR code
- Connected wallet address displayed

---

### TC-52-007: Crypto Payment - USDC Transfer
**Priority**: High
**Status**: Pending

**Steps**:
1. Connect wallet with USDC balance (Base network)
2. Select credit amount
3. Confirm payment in wallet

**Expected Result**:
- Transaction prompt in wallet
- Shows correct USDC amount
- Transaction confirmed on-chain
- Credits added to account after confirmation

---

### TC-52-008: Payment Method Persistence
**Priority**: Medium
**Status**: Pending

**Steps**:
1. Open payment modal
2. Select "Crypto" payment method
3. Close modal
4. Reopen modal

**Expected Result**:
- Previously selected payment method remembered
- Context preserves `preferredPaymentMethod` state

---

### TC-52-009: Stripe Disabled Graceful Degradation
**Priority**: Medium
**Status**: Pending

**Setup**: Remove or invalidate `VITE_STRIPE_PUBLISHABLE_KEY`

**Steps**:
1. Deploy dashboard without Stripe key
2. Navigate to Pricing page
3. Open payment modal

**Expected Result**:
- No console errors about missing Stripe key
- Card payment option may be hidden or disabled
- Crypto payment option still functional
- Warning logged: "VITE_STRIPE_PUBLISHABLE_KEY not set - Stripe payments disabled"

---

### TC-52-010: Annual vs Monthly Billing Toggle
**Priority**: Medium
**Status**: Pending

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

### TC-52-011: Free Tier - No Payment Required
**Priority**: Medium
**Status**: Pending

**Steps**:
1. Navigate to Pricing as non-authenticated user
2. Click on Free tier

**Expected Result**:
- No payment modal opens
- Redirects to signup/login flow
- Free tier automatically assigned after signup

---

### TC-52-012: Already Subscribed - Manage Subscription
**Priority**: Medium
**Status**: Pending

**Steps**:
1. Login with account that has active Stripe subscription
2. Navigate to Pricing page
3. Click on current tier

**Expected Result**:
- Shows "Current Plan" indicator
- Option to manage subscription (Stripe Portal)
- Option to upgrade to higher tier

---

## Component Tests

### PaymentMethodSelector Component
```typescript
// Test: Renders both payment options
expect(screen.getByText('Card')).toBeInTheDocument();
expect(screen.getByText('Crypto')).toBeInTheDocument();

// Test: Calls onSelect when clicked
fireEvent.click(screen.getByText('Crypto'));
expect(mockOnSelect).toHaveBeenCalledWith('crypto');

// Test: Shows correct selected state
expect(screen.getByRole('tab', { name: /card/i })).toHaveAttribute('aria-selected', 'true');
```

### StripeProvider Component
```typescript
// Test: Loads Stripe when key is present
expect(loadStripe).toHaveBeenCalledWith('pk_test_...');

// Test: Handles missing key gracefully
// With no VITE_STRIPE_PUBLISHABLE_KEY
expect(console.warn).toHaveBeenCalledWith(expect.stringContaining('not set'));
```

---

## API Endpoints Tested

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/billing/checkout` | POST | Create Stripe Checkout session |
| `/api/v1/billing/portal` | POST | Create Stripe Customer Portal session |
| `/api/v1/billing/subscription/current` | GET | Get current subscription |
| `/api/v1/credits/balance` | GET | Get credit balance |
| `/api/v1/credits/purchase` | POST | Purchase credits (x402) |

---

## Security Considerations

- [ ] Stripe publishable key only (never secret key in frontend)
- [ ] Card data never touches our servers (PCI compliant)
- [ ] All transactions validated server-side
- [ ] Webhook signatures verified for Stripe events
- [ ] x402 payments verified on-chain

---

## Related Documentation

- [Stripe Billing Tests](./37-stripe-billing.md)
- [Wallet Authentication Tests](./11-wallet-authentication.md)
- [x402 Pay-Per-Scan Tests](./15-x402-pay-per-scan.md)
- [Pricing Page Tests](./07-pricing-page.md)
- [User Guide: Payment Methods](/blocksecops-docs/billing/payment-methods.md)
