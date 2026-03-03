# Stripe Test Subscriptions Playbook

**Version:** 1.0.0
**Last Updated:** February 3, 2026
**Status:** Active

## Overview

This playbook covers creating and managing test subscriptions for development and QA testing without affecting production/paying customers. Stripe's test mode provides complete isolation from live data.

---

## Key Concept: Test Mode Isolation

Stripe maintains **completely separate databases** for test and live modes:

| Aspect | Test Mode (`sk_test_`) | Live Mode (`sk_live_`) |
|--------|------------------------|------------------------|
| API Keys | `sk_test_xxx`, `pk_test_xxx` | `sk_live_xxx`, `pk_live_xxx` |
| Transactions | Fake (no real money) | Real money |
| Subscriptions | Isolated test database | Production database |
| Customers | Test customers only | Real customers |
| Credit Cards | Test card numbers only | Real card processing |
| Webhooks | Separate webhook events | Separate webhook events |

**Bottom line:** Test subscriptions CANNOT affect paying customers. They exist in a completely separate Stripe environment.

---

## Prerequisites

1. Stripe account with test mode enabled
2. Local environment configured with test API keys
3. Access to Apogee API service

---

## Part 1: Verify Test Mode Configuration

### 1.1 Check Current Stripe Key

```bash
# Check if API service is using test keys
kubectl get secret stripe-credentials -n api-service-local -o jsonpath='{.data.api_key}' | base64 -d | head -c 10
```

**Expected output:** Should start with `sk_test_`

If you see `sk_live_` or placeholder text, you need to configure test keys first.

### 1.2 Configure Test Keys (If Not Set)

Get your test keys from Stripe Dashboard (Test mode) > Developers > API keys.

```bash
# Create/update the stripe-credentials secret
kubectl create secret generic stripe-credentials \
  --from-literal=api_key=sk_test_YOUR_TEST_KEY \
  --from-literal=webhook_secret=whsec_YOUR_TEST_WEBHOOK_SECRET \
  -n api-service-local \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart API service to pick up new credentials
kubectl rollout restart deployment/api-service -n api-service-local
kubectl rollout status deployment/api-service -n api-service-local
```

---

## Part 2: Create Test Subscriptions

### Option A: Via UI (Recommended for Full Flow Testing)

1. **Create a test user account** in the dashboard
2. Navigate to **Pricing** or **Upgrade** page
3. Select a tier (Starter, Growth, or Enterprise)
4. Use test card number: `4242 4242 4242 4242`
   - Expiry: Any future date (e.g., 12/34)
   - CVC: Any 3 digits (e.g., 123)
5. Complete checkout

### Option B: Via Stripe CLI (Quick Testing)

```bash
# Login to Stripe CLI
stripe login

# Create a test customer
stripe customers create \
  --name="Test User" \
  --email="test-growth@example.com" \
  --metadata[blocksecops_user_id]=YOUR_USER_UUID

# Create a test subscription
stripe subscriptions create \
  --customer=cus_CUSTOMER_ID \
  --items[0][price]=price_growth_monthly \
  --payment-behavior=default_incomplete \
  --payment-settings[save_default_payment_method]=on_subscription

# Attach a test payment method
stripe payment-methods attach pm_card_visa \
  --customer=cus_CUSTOMER_ID

# Set as default payment method
stripe customers update cus_CUSTOMER_ID \
  --invoice-settings[default_payment_method]=pm_card_visa
```

### Option C: Via API (Programmatic Testing)

```bash
# Create subscription via API
curl -X POST http://127.0.0.1:8000/api/v1/billing/subscriptions/create-checkout \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "tier": "growth",
    "billing_period": "monthly",
    "success_url": "http://127.0.0.1:3000/billing/success",
    "cancel_url": "http://127.0.0.1:3000/billing/cancel"
  }'
```

### Option D: Direct Database Insert (No Stripe Validation)

For testing tier features without actual Stripe integration:

```sql
-- Connect to PostgreSQL
PGPASSWORD=postgres psql -h 127.0.0.1 -p 5432 -U postgres -d solidity_security

-- Insert a mock subscription
INSERT INTO subscriptions (
  id,
  user_id,
  tier,
  status,
  stripe_subscription_id,
  stripe_customer_id,
  started_at,
  current_period_start,
  current_period_end,
  created_at,
  updated_at
) VALUES (
  gen_random_uuid(),
  'YOUR_USER_UUID',  -- Replace with actual user ID
  'growth',          -- tier: developer, starter, growth, enterprise
  'active',
  'sub_test_mock_' || substr(md5(random()::text), 1, 14),
  'cus_test_mock_' || substr(md5(random()::text), 1, 14),
  NOW(),
  NOW(),
  NOW() + INTERVAL '30 days',
  NOW(),
  NOW()
);

-- Also update the user's tier in user_quotas
UPDATE user_quotas
SET tier = 'growth',
    monthly_contract_limit = 50,
    max_projects = -1,
    max_team_members = 15,
    api_access_enabled = true,
    multi_chain_enabled = true,
    continuous_monitoring_enabled = true,
    fp_reduction_enabled = true,
    webhooks_enabled = true,
    result_retention_days = 180,
    scan_priority = 25
WHERE user_id = 'YOUR_USER_UUID';
```

**Note:** Direct DB inserts won't work with Stripe operations (cancel, upgrade, billing portal). Use for feature testing only.

---

## Part 3: Test Different Scenarios

### 3.1 Test Card Numbers

| Card Number | Behavior | Use Case |
|-------------|----------|----------|
| `4242 4242 4242 4242` | Always succeeds | Happy path testing |
| `4000 0025 0000 3155` | Requires 3D Secure | Authentication flow |
| `4000 0000 0000 9995` | Declined - insufficient funds | Failure handling |
| `4000 0000 0000 0341` | Attaching fails | Card validation errors |
| `4000 0000 0000 0002` | Generic decline | Error handling |

### 3.2 Test Subscription Lifecycle

```bash
# 1. Create subscription (see Option A, B, or C above)

# 2. Trigger renewal (advance clock in Stripe Test mode)
stripe test-clocks create \
  --frozen-time=$(date -d '+1 month' +%s)

# 3. Cancel subscription
stripe subscriptions cancel sub_SUBSCRIPTION_ID

# 4. Reactivate (create new subscription)
```

### 3.3 Test Tier Changes (Upgrades/Downgrades)

```bash
# Preview a tier change (no charge)
curl -X GET "http://127.0.0.1:8000/api/v1/billing/subscription/change-tier/preview?new_tier=growth&billing_interval=monthly" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Upgrade to Growth tier (immediate proration)
curl -X POST http://127.0.0.1:8000/api/v1/billing/subscription/change-tier \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "new_tier": "growth",
    "billing_interval": "monthly",
    "proration_behavior": "auto"
  }'

# Downgrade to Starter tier (takes effect at period end)
curl -X POST http://127.0.0.1:8000/api/v1/billing/subscription/change-tier \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "new_tier": "starter",
    "billing_interval": "monthly",
    "proration_behavior": "auto"
  }'
```

**Proration Behaviors:**
- `auto` (default): Upgrades charge immediately, downgrades defer to period end
- `immediate`: Both upgrades and downgrades prorate immediately
- `end_of_period`: Both defer to next billing cycle

### 3.4 Test Tier Features

After creating a test subscription, verify tier features work:

```bash
# Test API access (Growth+ only)
curl -X GET http://127.0.0.1:8000/api/v1/scans \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Test concurrent scan limits
# Growth tier allows 5 concurrent scans

# Test multi-chain support (Growth+ only)
curl -X POST http://127.0.0.1:8000/api/v1/scans \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{"language": "rust", "chain": "solana", ...}'
```

---

## Part 4: Webhook Testing with Stripe CLI

### 4.1 Forward Webhooks to Local

```bash
# Start webhook forwarding
stripe listen --forward-to http://127.0.0.1:8000/api/v1/webhooks/stripe

# Note the webhook signing secret output (whsec_...)
# Update the secret in Kubernetes if different
```

### 4.2 Trigger Specific Events

```bash
# Trigger a successful payment
stripe trigger checkout.session.completed

# Trigger subscription events
stripe trigger customer.subscription.created
stripe trigger customer.subscription.updated
stripe trigger customer.subscription.deleted

# Trigger payment failure
stripe trigger invoice.payment_failed
```

### 4.3 Monitor Webhook Processing

```bash
# Watch API logs for webhook processing
kubectl logs -f -n api-service-local deployment/api-service | grep -i stripe
```

---

## Part 5: Clean Up Test Data

### 5.1 Delete Test Subscriptions (Stripe Dashboard)

1. Go to Stripe Dashboard (Test mode)
2. Navigate to **Customers**
3. Find the test customer
4. Cancel any active subscriptions
5. Delete the customer if no longer needed

### 5.2 Delete Test Subscriptions (CLI)

```bash
# Cancel subscription
stripe subscriptions cancel sub_SUBSCRIPTION_ID

# Delete customer (removes all associated data)
stripe customers delete cus_CUSTOMER_ID
```

### 5.3 Clean Database (Local Only)

```sql
-- Delete test subscriptions
DELETE FROM subscriptions
WHERE stripe_subscription_id LIKE 'sub_test_mock_%';

-- Reset user to developer tier
UPDATE user_quotas
SET tier = 'developer',
    monthly_contract_limit = 3,
    max_projects = 3,
    max_team_members = 2,
    api_access_enabled = false,
    multi_chain_enabled = false,
    continuous_monitoring_enabled = false,
    fp_reduction_enabled = false,
    webhooks_enabled = false,
    result_retention_days = 7,
    scan_priority = 50
WHERE user_id = 'YOUR_USER_UUID';
```

---

## Part 6: Test Mode vs Production Checklist

Before going to production, verify:

- [ ] Test mode keys replaced with live keys
- [ ] All `sk_test_` replaced with `sk_live_`
- [ ] All `pk_test_` replaced with `pk_live_`
- [ ] Webhook endpoint updated to production URL
- [ ] Webhook signing secret updated
- [ ] Test customers NOT migrated (start fresh in live)
- [ ] Price IDs updated to live mode IDs

---

## Troubleshooting

### "No such customer" Error

- Customer was created in a different mode (test vs live)
- Verify API key matches the mode where customer exists

### Subscription Created but User Still on Developer Tier

- Webhook not received or processed
- Check API logs: `kubectl logs -n api-service-local deployment/api-service | grep webhook`
- Verify webhook secret matches

### Test Card Declined

- Verify you're in test mode
- Check card number is correct (no spaces in API, with spaces in UI)

### Webhook Signature Verification Failed

- Webhook secret mismatch between Stripe and application
- If using Stripe CLI, use the secret from `stripe listen` output
- Update secret: `kubectl create secret generic stripe-credentials ...`

---

## Quick Reference: Test User Setup

```bash
# Complete setup for a test Growth tier user

# 1. Create user via dashboard or API
# ... (standard registration)

# 2. Get user ID from database
PGPASSWORD=postgres psql -h 127.0.0.1 -p 5432 -U postgres -d solidity_security \
  -c "SELECT id FROM users WHERE email='test@example.com';"

# 3. Create test subscription (direct DB for quick testing)
USER_UUID="from-step-2"

PGPASSWORD=postgres psql -h 127.0.0.1 -p 5432 -U postgres -d solidity_security << EOF
INSERT INTO subscriptions (id, user_id, tier, status, stripe_subscription_id, stripe_customer_id, started_at, current_period_start, current_period_end, created_at, updated_at)
VALUES (gen_random_uuid(), '$USER_UUID', 'growth', 'active', 'sub_test_mock_growth', 'cus_test_mock_growth', NOW(), NOW(), NOW() + INTERVAL '30 days', NOW(), NOW());

UPDATE user_quotas SET tier='growth', monthly_contract_limit=50, max_projects=-1, max_team_members=15, api_access_enabled=true, multi_chain_enabled=true, continuous_monitoring_enabled=true, fp_reduction_enabled=true, webhooks_enabled=true, result_retention_days=180, scan_priority=25 WHERE user_id='$USER_UUID';
EOF

# 4. Verify
PGPASSWORD=postgres psql -h 127.0.0.1 -p 5432 -U postgres -d solidity_security \
  -c "SELECT u.email, q.tier FROM users u JOIN user_quotas q ON u.id = q.user_id WHERE u.id='$USER_UUID';"
```

---

## Related Documentation

- [Stripe Payment Setup](./stripe-payment-setup.md) - Full Stripe configuration
- [Tier Standards](/home/pwner/Git/docs/standards/tier-standards.md) - Tier definitions and quotas
- [Database Management](/home/pwner/Git/docs/standards/database-management.md) - Database operations
- [Stripe Testing Guide](https://stripe.com/docs/testing) - Official Stripe docs

---

## Document History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2026-02-03 | Initial playbook for test subscriptions | Claude Code |
