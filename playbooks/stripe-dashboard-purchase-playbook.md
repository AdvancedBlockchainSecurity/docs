# Stripe Dashboard Purchase Testing Playbook

**Version:** 1.0.0
**Last Updated:** February 3, 2026
**Status:** Active

## Overview

This playbook covers testing Stripe payment flows through the BlockSecOps dashboard UI. It explains the two Stripe keys, how they work together, and step-by-step testing procedures.

## Prerequisites

- Stripe account in **Test mode**
- API service running with Stripe secrets configured in Vault
- Dashboard deployed and accessible
- Stripe CLI installed for webhook forwarding (local development)

---

## Understanding Stripe Keys

Stripe uses two types of API keys that serve different purposes:

| Key Type | Format | Location | Purpose |
|----------|--------|----------|---------|
| **Publishable Key** | `pk_test_...` | Frontend (browser) | Initialize Stripe.js, show payment forms |
| **Secret Key** | `sk_test_...` or `rk_test_...` | Backend (API) | Process charges, verify webhooks |

### Publishable Key (Frontend)

- **Safe to expose** in client-side JavaScript
- Used by dashboard to:
  - Initialize Stripe.js library
  - Render payment elements
  - Create checkout sessions
  - Redirect to Stripe's hosted payment page
- Cannot be used to charge cards or access sensitive data

### Secret Key (Backend)

- **Must be kept secret** - stored in Vault
- Used by API service to:
  - Verify webhook signatures
  - Create/update customers and subscriptions
  - Process refunds
  - Access Stripe Dashboard data programmatically

---

## Part 1: Get Your Stripe Keys

### 1.1 Access Stripe Dashboard

1. Go to https://dashboard.stripe.com
2. Ensure **Test mode** is enabled (toggle in top-right, shows orange "Test mode" indicator)
3. Navigate to **Developers → API keys**

### 1.2 Copy Both Keys

| Key | Location | Example |
|-----|----------|---------|
| Publishable key | Visible by default | `pk_test_51Xxx...` |
| Secret key | Click "Reveal test key" | `sk_test_51Xxx...` or `rk_test_51Xxx...` |

**Note:** Restricted keys (`rk_test_...`) work the same as secret keys but with limited permissions.

---

## Part 2: Configure Backend (Secret Key)

The secret key should already be in Vault if you followed the [Stripe Payment Setup Playbook](./stripe-payment-setup.md).

### 2.1 Verify Secret Key in Vault

```bash
# Get Vault root token
ROOT_TOKEN=$(kubectl exec vault-0 -n vault-local -- cat /vault/data/.vault-init.json 2>/dev/null | jq -r '.root_token')

# Check Stripe secrets exist
kubectl exec vault-0 -n vault-local -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault kv get secret/local/api-service/stripe"
```

Expected output:
```
========= Data =========
Key               Value
---               -----
api_key           sk_test_... or rk_test_...
webhook_secret    whsec_...
```

### 2.2 Update Secret Key (if needed)

```bash
kubectl exec vault-0 -n vault-local -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault kv put secret/local/api-service/stripe \
  api_key='sk_test_YOUR_SECRET_KEY' \
  webhook_secret='whsec_YOUR_WEBHOOK_SECRET'"

# Force sync and restart
kubectl annotate externalsecret api-service-secret -n api-service-local force-sync="$(date +%s)" --overwrite
kubectl rollout restart deployment/api-service -n api-service-local
```

---

## Part 3: Configure Frontend (Publishable Key)

The publishable key must be available to the dashboard. There are two approaches:

### Option A: Runtime Configuration (Recommended)

Add a `/billing/config` endpoint to the API that serves the publishable key. The dashboard fetches it at startup.

**Advantages:**
- No dashboard rebuild required
- Key can be changed without redeployment
- Follows 12-factor app principles

### Option B: Build-Time Configuration (Current)

Bake the publishable key into the dashboard at build time.

**Dashboard Build Command:**
```bash
cd /home/pwner/Git

VERSION=$(grep '"version"' blocksecops-dashboard/package.json | head -1 | cut -d'"' -f4)
REGISTRY="harbor.blocksecops.local"

# Get existing config values
SUPABASE_URL=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_url}')
SUPABASE_KEY=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_anon_key}')
WALLETCONNECT_ID=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.VITE_WALLETCONNECT_PROJECT_ID}')

# Your Stripe publishable key
STRIPE_PK="pk_test_YOUR_PUBLISHABLE_KEY"

# Build with Stripe key
docker build --no-cache \
  -f blocksecops-dashboard/Dockerfile \
  --build-arg VITE_SUPABASE_URL=${SUPABASE_URL} \
  --build-arg VITE_SUPABASE_ANON_KEY=${SUPABASE_KEY} \
  --build-arg VITE_WALLETCONNECT_PROJECT_ID=${WALLETCONNECT_ID} \
  --build-arg VITE_STRIPE_PUBLISHABLE_KEY=${STRIPE_PK} \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(cd blocksecops-dashboard && git rev-parse --short HEAD) \
  -t ${REGISTRY}/blocksecops/dashboard:${VERSION} .

# Push and deploy
docker push ${REGISTRY}/blocksecops/dashboard:${VERSION}
kubectl rollout restart deployment/dashboard -n dashboard-local
```

---

## Part 4: Start Webhook Forwarding

For local testing, Stripe webhooks need to reach your local API.

### 4.1 Start Stripe CLI Listener

```bash
# Get your webhook secret (save this!)
~/bin/stripe listen --api-key "sk_test_YOUR_KEY" --print-secret

# Start forwarding (kubeadm server)
~/bin/stripe listen \
  --api-key "sk_test_YOUR_KEY" \
  --forward-to http://192.168.86.225:30180/api/v1/webhooks/stripe
```

### 4.2 Verify Listener is Running

```bash
# Check process
pgrep -f "stripe listen" && echo "Running" || echo "Not running"

# Check recent forwarded events
cat /tmp/stripe-listener.log | tail -20
```

---

## Part 5: Test Purchase Flow

### 5.1 Access the Dashboard

1. Open browser to `http://127.0.0.1:3000` (minikube) or `http://app.blocksecops.local` (kubeadm)
2. Log in with your account
3. Navigate to **Billing** or **Credits** page

### 5.2 Test Credit Purchase

1. Select a credit package (e.g., "Starter - 10 credits")
2. Click **Purchase Credits** or **Buy Now**
3. You should be redirected to Stripe Checkout

### 5.3 Complete Test Payment

Use Stripe test card numbers:

| Card Number | Scenario |
|-------------|----------|
| `4242 4242 4242 4242` | Successful payment |
| `4000 0000 0000 3220` | Requires 3D Secure |
| `4000 0000 0000 9995` | Decline (insufficient funds) |
| `4000 0000 0000 0002` | Decline (generic) |

**For all test cards:**
- Expiry: Any future date (e.g., `12/34`)
- CVC: Any 3 digits (e.g., `123`)
- ZIP: Any 5 digits (e.g., `12345`)

### 5.4 Verify Webhook Received

Check Stripe CLI output for forwarded events:
```
2026-02-03 23:01:42   --> checkout.session.completed [evt_xxx]
2026-02-03 23:01:42  <--  [200] POST http://192.168.86.225:30180/api/v1/webhooks/stripe
```

Check API logs:
```bash
kubectl logs deployment/api-service -n api-service-local --tail=50 | grep -i stripe
```

### 5.5 Verify Credits Added

1. Return to dashboard
2. Check credits balance increased
3. Check billing history shows the transaction

---

## Part 6: Test Subscription Flow

### 6.1 Navigate to Pricing

1. Go to **Pricing** or **Upgrade** page
2. Select a subscription tier (Team, Growth, or Enterprise)
3. Choose billing interval (Monthly or Annual)

### 6.2 Complete Subscription

1. Click **Subscribe** or **Upgrade**
2. Complete Stripe Checkout with test card
3. Verify redirect to success page

### 6.3 Verify Subscription Active

```bash
# Check via API
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://192.168.86.225:30180/api/v1/billing/subscription

# Check Stripe Dashboard
# Go to https://dashboard.stripe.com/test/subscriptions
```

---

## Troubleshooting

### "Stripe is not configured" in Dashboard

**Cause:** Publishable key not available to frontend

**Solution:**
1. Check if `VITE_STRIPE_PUBLISHABLE_KEY` is set in dashboard build
2. Rebuild dashboard with the key (see Part 3, Option B)

### Webhook Returns 401/403

**Cause:** Webhook signature verification failing

**Solution:**
1. Verify `webhook_secret` in Vault matches Stripe CLI output
2. Force resync ExternalSecret and restart API

### Checkout Redirects But Payment Fails

**Cause:** Secret key mismatch or invalid price IDs

**Solution:**
1. Verify secret key in Vault matches Stripe Dashboard
2. Verify price IDs exist in Stripe (create products if missing)

### Credits Not Added After Payment

**Cause:** Webhook not processed or database error

**Solution:**
1. Check Stripe CLI shows `[200]` response
2. Check API logs for errors
3. Verify database connection is working

---

## Security Notes

1. **Never share secret keys** - even in test mode
2. **Publishable keys are safe** to expose in frontend code
3. **Webhook secrets** must be kept secure and rotated if compromised
4. **Test mode** uses fake money - no real charges occur
5. Always **rotate keys** before going to production

---

## Related Documentation

- [Stripe Payment Setup Playbook](./stripe-payment-setup.md) - Initial Stripe configuration
- [Stripe Test Subscriptions Playbook](./stripe-test-subscriptions.md) - Subscription testing
- [Secrets Management Standards](../standards/secrets-management.md) - Vault configuration
- [Stripe Dashboard Purchase Workflow](../workflows/stripe-dashboard-purchase-workflow.md) - Quick reference

---

## Document History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2026-02-03 | Initial playbook | BlockSecOps Team |
