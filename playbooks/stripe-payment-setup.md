# Stripe Payment Setup Playbook

**Version:** 1.3.0
**Last Updated:** March 13, 2026
**Status:** Active

## Overview

This playbook covers setting up Stripe for credit card payments in the Apogee platform. It includes both test mode setup for development and production configuration.

## Prerequisites

- Access to Stripe Dashboard (create account at https://stripe.com)
- Access to Apogee API service configuration
- Access to `blocksecops-shared` repository for tier configuration

---

## Part 1: Stripe Account Setup

### 1.1 Create Stripe Account

1. Go to https://dashboard.stripe.com/register
2. Complete registration with your business details
3. Verify your email address

### 1.2 Enable Test Mode

1. In the Stripe Dashboard, look at the top-right corner
2. Toggle **"Test mode"** ON (you'll see an orange "Test mode" indicator)
3. All operations in test mode use fake money and test cards

**Important:** Always develop and test in Test mode before switching to Live mode.

---

## Part 2: Get API Keys

### 2.1 Locate API Keys

1. In Stripe Dashboard (Test mode), go to **Developers → API keys**
2. You'll see two keys:

| Key Type | Format | Usage |
|----------|--------|-------|
| Publishable key | `pk_test_...` | Frontend (safe to expose) |
| Secret key | `sk_test_...` | Backend (keep secret!) |

### 2.2 Copy Your Keys

Click "Reveal test key" to see the secret key. Save both keys securely.

**Test Keys Example:**
```
Publishable: pk_test_51ABC123...
Secret: sk_test_51ABC123...
```

---

## Part 3: Create Stripe Products

Apogee has two types of purchasable items:
1. **Credit Packages** - One-time purchases for scan credits
2. **Subscription Tiers** - Monthly/annual subscriptions for platform access

### 3.1 Product Summary Table

Create the following products in Stripe Dashboard (**Products → Add product**):

#### Credit Packages (One-Time Payments)

| Product Name | Credits | Price | Type | Config Key |
|--------------|---------|-------|------|------------|
| Credits - Starter | 10 | $25.00 | One-time | `creditPackages.starter.stripePriceId` |
| Credits - Builder | 50 | $99.00 | One-time | `creditPackages.builder.stripePriceId` |
| Credits - Pro | 250 | $399.00 | One-time | `creditPackages.pro.stripePriceId` |
| Credits - Bulk | 1000 | $1,250.00 | One-time | `creditPackages.bulk.stripePriceId` |

#### Subscription Tiers (Recurring Payments)

| Product Name | Monthly Price | Annual Price | Features |
|--------------|---------------|--------------|----------|
| Developer (Free) | $0 | $0 | No Stripe product needed |
| Starter | $199/month | $2,028/year ($169/mo) | 25 scans/mo, 15 projects, API access |
| Growth | $499/month | $5,028/year ($419/mo) | 75 scans/mo, 25 team members, priority support |
| Enterprise | $1,499/month | Contact Sales | Unlimited scans, SSO, dedicated support |

### 3.2 Create Credit Package Products

For each credit package:

1. Go to **Products → Add product**
2. Fill in the details:

**Credits - Starter**
```
Name:        Credits - Starter (10 credits)
Description: 10 scan credits for Apogee smart contract security scanning
Pricing:     $25.00 USD - One time
```

**Credits - Builder**
```
Name:        Credits - Builder (50 credits)
Description: 50 scan credits for Apogee - Save 21% ($1.98/credit)
Pricing:     $99.00 USD - One time
```

**Credits - Pro**
```
Name:        Credits - Pro (250 credits)
Description: 250 scan credits for Apogee - Save 36% ($1.60/credit)
Pricing:     $399.00 USD - One time
```

**Credits - Bulk**
```
Name:        Credits - Bulk (1000 credits)
Description: 1000 scan credits for Apogee - Save 50% ($1.25/credit)
Pricing:     $1,250.00 USD - One time
```

3. After saving each product, copy the **Price ID** from the product page

### 3.3 Create Subscription Tier Products

For subscription tiers, each product needs TWO prices (monthly and annual):

**Starter Tier**
```
Name:        Apogee Starter
Description: Starter plan - 25 scans/month, 15 projects, API access, email support

Add two prices:
  - $199.00 USD - Recurring monthly
  - $2,028.00 USD - Recurring yearly (saves $360/year)
```

**Growth Tier**
```
Name:        Apogee Growth
Description: Growth plan - 75 scans/month, 25 team members, priority support, webhooks

Add two prices:
  - $499.00 USD - Recurring monthly
  - $5,028.00 USD - Recurring yearly (saves $960/year)
```

**Enterprise Tier**
```
Name:        Apogee Enterprise
Description: Enterprise plan - Unlimited scans, SSO, dedicated support, custom integrations

Add one price:
  - $1,499.00 USD - Recurring monthly
  (Annual pricing handled via sales contracts)
```

### 3.4 Record All Price IDs

After creating all products, record the Price IDs:

```
# Credit Packages (One-time)
credits_starter:      price_1TAfcV3ZtjkVcNXVM6qpmvA1
credits_builder:      price_1TAfcW3ZtjkVcNXVX6QaB1Sm
credits_pro:          price_1TAfcX3ZtjkVcNXVvKAhWeXY
credits_bulk:         price_1TAfcZ3ZtjkVcNXVLfhIA2K3

# Starter Tier (Subscription)
starter_monthly:      price_1TAfcL3ZtjkVcNXVjTSRsgYs
starter_annual:       price_1TAfcM3ZtjkVcNXVg9ll3Pqm

# Growth Tier (Subscription)
growth_monthly:       price_1TAfcN3ZtjkVcNXVZQUALruH
growth_annual:        price_1TAfcO3ZtjkVcNXVVhAFfSwW

# Enterprise Tier (Subscription)
enterprise_monthly:   price_1TAfcP3ZtjkVcNXVgFFrvw9i
```

---

## Part 4: Configure Apogee

### 4.1 Update Tier Configuration

Edit the tier configuration file:

```bash
vim /home/pwner/Git/blocksecops-shared/tier-config/tiers.json
```

#### Update Credit Packages

Find the `creditPackages` section and update the `stripePriceId` values:

```json
"creditPackages": {
  "starter": {
    "credits": 10,
    "price": 25.00,
    "perCredit": 2.50,
    "savings": null,
    "stripePriceId": "price_1TAfcV3ZtjkVcNXVM6qpmvA1"
  },
  "builder": {
    "credits": 50,
    "price": 99.00,
    "perCredit": 1.98,
    "savings": "21%",
    "stripePriceId": "price_1TAfcW3ZtjkVcNXVX6QaB1Sm"
  },
  "pro": {
    "credits": 250,
    "price": 399.00,
    "perCredit": 1.60,
    "savings": "36%",
    "stripePriceId": "price_1TAfcX3ZtjkVcNXVvKAhWeXY"
  },
  "bulk": {
    "credits": 1000,
    "price": 1250.00,
    "perCredit": 1.25,
    "savings": "50%",
    "stripePriceId": "price_1TAfcZ3ZtjkVcNXVLfhIA2K3"
  }
}
```

#### Update Subscription Tiers

Find each tier in the `tiers` section and update the Stripe Price IDs:

**Starter Tier** (in `tiers.starter`):
```json
"starter": {
  "name": "Starter",
  "pricing": {
    "monthly": 199,
    "annual": 2028
  },
  "stripePriceIdMonthly": "price_1TAfcL3ZtjkVcNXVjTSRsgYs",
  "stripePriceIdAnnual": "price_1TAfcM3ZtjkVcNXVg9ll3Pqm",
  ...
}
```

**Growth Tier** (in `tiers.growth`):
```json
"growth": {
  "name": "Growth",
  "pricing": {
    "monthly": 499,
    "annual": 5028
  },
  "stripePriceIdMonthly": "price_1TAfcN3ZtjkVcNXVZQUALruH",
  "stripePriceIdAnnual": "price_1TAfcO3ZtjkVcNXVVhAFfSwW",
  ...
}
```

**Enterprise Tier** (in `tiers.enterprise`):
```json
"enterprise": {
  "name": "Enterprise",
  "pricing": {
    "monthly": 1499,
    "annual": null
  },
  "stripePriceIdMonthly": "price_1TAfcP3ZtjkVcNXVgFFrvw9i",
  "stripePriceIdAnnual": null,
  ...
}
```

**Note:** The `developer` tier is free and doesn't need Stripe Price IDs.

### 4.2 Rebuild Tier Config Package

```bash
cd /home/pwner/Git/blocksecops-shared/tier-config/python

# Build the wheel
python -m build

# Copy to Git root for API service to use
cp dist/blocksecops_tier_config-*.whl /home/pwner/Git/
```

### 4.3 Configure API Service Secrets

The API service needs the Stripe Secret Key. **All secrets MUST be stored in Vault** per [Secrets Management Standards](../standards/secrets-management.md).

**Local Development (Vault)**
```bash
# Get Vault root token
ROOT_TOKEN=$(kubectl exec vault-0 -n vault-local -- cat /vault/data/.vault-init.json 2>/dev/null | jq -r '.root_token')

# Store Stripe secrets in Vault
kubectl exec vault-0 -n vault-local -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault kv put secret/local/api-service/stripe \
  api_key='sk_test_YOUR_KEY' \
  webhook_secret='whsec_YOUR_SECRET'"

# Force ExternalSecret to resync
kubectl annotate externalsecret api-service-secret -n api-service-local force-sync="$(date +%s)" --overwrite

# Restart API service to pick up new secrets
kubectl rollout restart deployment/api-service -n api-service-local
```

**GCP Production (Secret Manager)**
```bash
# Create secrets in GCP Secret Manager
echo -n "sk_live_YOUR_KEY" | gcloud secrets create solidity-security-production-stripe-api-key --data-file=-
echo -n "whsec_YOUR_SECRET" | gcloud secrets create solidity-security-production-stripe-webhook-secret --data-file=-
```

**Note:** Never store secrets in ConfigMaps. The ExternalSecret automatically syncs from Vault to the `api-service-secret` Kubernetes Secret.

### 4.4 Configure Dashboard

The dashboard needs the Stripe Publishable Key at build time.

Update the dashboard ConfigMap:
```bash
vim /home/pwner/Git/blocksecops-dashboard/k8s/overlays/local/configmap-patch.yaml
```

Add:
```yaml
data:
  VITE_STRIPE_PUBLISHABLE_KEY: "pk_test_51ABC123..."
```

---

## Part 5: Set Up Stripe Webhooks

Webhooks notify your application when payments complete.

### 5.1 Create Webhook Endpoint in Stripe

#### Option A: Via Stripe API (Recommended)

```bash
# Create webhook endpoint via API
curl https://api.stripe.com/v1/webhook_endpoints \
  -u "sk_live_YOUR_KEY:" \
  -d "url=https://app.0xapogee.com/api/v1/webhooks/stripe" \
  -d "enabled_events[]=checkout.session.completed" \
  -d "enabled_events[]=customer.subscription.updated" \
  -d "enabled_events[]=customer.subscription.deleted" \
  -d "enabled_events[]=invoice.payment_succeeded" \
  -d "enabled_events[]=invoice.payment_failed" \
  -d "enabled_events[]=customer.updated"
```

The response contains the `secret` field (starts with `whsec_...`) — save this for the next step.

**Current Production Endpoint:**
- **URL:** `https://app.0xapogee.com/api/v1/webhooks/stripe`
- **Endpoint ID:** `we_1TAe593ZtjkVcNXVjsJGk7rs`
- **Events:** checkout.session.completed, customer.subscription.updated, customer.subscription.deleted, invoice.payment_succeeded, invoice.payment_failed, customer.updated

#### Option B: Via Stripe Dashboard

1. Go to **Developers → Webhooks**
2. Click **Add endpoint**
3. Configure:
   - **Endpoint URL:** `https://app.0xapogee.com/api/v1/webhooks/stripe` (production)
   - **Events to send:** Select these events:
     - `checkout.session.completed`
     - `customer.subscription.updated`
     - `customer.subscription.deleted`
     - `invoice.payment_succeeded`
     - `invoice.payment_failed`
     - `customer.updated`
4. Click **Add endpoint**
5. Copy the **Signing secret** (starts with `whsec_...`)

### 5.1.1 Update Webhook Secret in GCP Secret Manager

After creating the webhook endpoint, update the signing secret in GCP:

```bash
# Update the existing secret with the new webhook signing secret
echo -n "whsec_YOUR_NEW_SECRET" | \
  gcloud secrets versions add apogee-gcp-stripe-webhook-secret --data-file=-

# Verify the new version was created
gcloud secrets versions list apogee-gcp-stripe-webhook-secret

# Force ESO to resync the secret to Kubernetes
kubectl annotate externalsecret api-service-secret -n api-service-prod \
  force-sync="$(date +%s)" --overwrite

# Restart API service to pick up the new secret
kubectl rollout restart deployment/api-service -n api-service-prod
```

**Current secret version:** 3 (updated 2026-03-13)

### 5.2 Local Development Webhook Testing

For local development, use Stripe CLI to forward webhooks:

**Install Stripe CLI:**
```bash
# macOS
brew install stripe/stripe-cli/stripe

# Linux (Debian/Ubuntu)
curl -s https://packages.stripe.dev/api/security/keypair/stripe-cli-gpg/public | gpg --dearmor | sudo tee /usr/share/keyrings/stripe.gpg
echo "deb [signed-by=/usr/share/keyrings/stripe.gpg] https://packages.stripe.dev/stripe-cli-debian-local stable main" | sudo tee /etc/apt/sources.list.d/stripe.list
sudo apt update && sudo apt install stripe
```

**Login to Stripe:**
```bash
stripe login
```

**Forward Webhooks to Local (kubeadm server):**
```bash
# Get webhook secret first (save this!)
~/bin/stripe listen --api-key "sk_test_YOUR_KEY" --print-secret

# Forward to API service via Traefik NodePort
# Node IP: 192.168.86.225, NodePort: 30180
~/bin/stripe listen \
  --api-key "sk_test_YOUR_KEY" \
  --forward-to http://192.168.86.225:30180/api/v1/webhooks/stripe

# The CLI will show forwarded events like:
# 2026-02-03 23:01:42   --> checkout.session.completed [evt_xxx]
# 2026-02-03 23:01:42  <--  [200] POST http://192.168.86.225:30180/api/v1/webhooks/stripe
```

**Forward Webhooks to Local (minikube):**
```bash
# With minikube tunnel running:
~/bin/stripe listen \
  --api-key "sk_test_YOUR_KEY" \
  --forward-to http://127.0.0.1:3000/api/v1/webhooks/stripe
```

The CLI outputs a webhook signing secret (starts with `whsec_...`). **Store this in Vault** using the commands in section 4.3.

### 5.3 Update Webhook Secret

Add the webhook signing secret to your configuration:

```bash
# Vault (production)
vault kv put secret/api-service STRIPE_WEBHOOK_SECRET="whsec_..."

# Or ConfigMap (local)
# Add to configmap-patch.yaml:
#   STRIPE_WEBHOOK_SECRET: "whsec_..."
```

---

## Part 6: Rebuild and Deploy

### 6.1 Rebuild API Service

```bash
cd /home/pwner/Git/blocksecops-api-service

# Bump version
sed -i 's/version = ".*"/version = "0.22.3"/' pyproject.toml

# Update kustomization
sed -i 's/newTag: "0.22.2"/newTag: "0.22.3"/' k8s/overlays/local/api-service/kustomization.yaml

# Build
VERSION="0.22.3"
REGISTRY="harbor.blocksecops.local"
docker build \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t ${REGISTRY}/blocksecops/api-service:${VERSION} .

# Push and deploy
docker push ${REGISTRY}/blocksecops/api-service:${VERSION}
kubectl apply -k k8s/overlays/local/api-service/
kubectl rollout restart deployment/api-service -n api-service-local
```

### 6.2 Rebuild Dashboard (if Stripe key changed)

```bash
cd /home/pwner/Git

# Bump version
sed -i 's/"version": "0.37.2"/"version": "0.37.3"/' blocksecops-dashboard/package.json

# Update kustomization
sed -i 's/newTag: "0.37.2"/newTag: "0.37.3"/' blocksecops-dashboard/k8s/overlays/local/kustomization.yaml
sed -i 's/version: "0.37.2"/version: "0.37.3"/' blocksecops-dashboard/k8s/overlays/local/kustomization.yaml

# Build with Stripe key
VERSION="0.37.3"
REGISTRY="harbor.blocksecops.local"
SUPABASE_URL=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_url}')
SUPABASE_KEY=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_anon_key}')
WALLETCONNECT_ID=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.VITE_WALLETCONNECT_PROJECT_ID}')
STRIPE_PK="pk_test_51ABC123..."  # Your publishable key

docker build \
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
kubectl apply -k blocksecops-dashboard/k8s/overlays/local/
kubectl rollout restart deployment/dashboard -n dashboard-local
```

---

## Part 7: Test the Integration

### 7.1 Test Card Numbers

Stripe provides test card numbers for testing:

| Card Number | Description |
|-------------|-------------|
| `4242 4242 4242 4242` | Succeeds and charges |
| `4000 0000 0000 3220` | Requires 3D Secure authentication |
| `4000 0000 0000 9995` | Always declines (insufficient funds) |
| `4000 0000 0000 0002` | Always declines (generic) |

**For all test cards:**
- Expiry: Any future date (e.g., 12/34)
- CVC: Any 3 digits (e.g., 123)
- ZIP: Any 5 digits (e.g., 12345)

### 7.2 Test Purchase Flow

1. Navigate to `/credits` page
2. Select a credit package (e.g., "Builder")
3. Click "Purchase Credits"
4. Select "Card" payment method
5. Click "Pay $99.00 with Card"
6. In Stripe Checkout, enter test card: `4242 4242 4242 4242`
7. Complete the purchase
8. Verify redirect to success page
9. Check credits were added to your account

### 7.3 Verify Webhook Received

Check API logs for webhook processing:
```bash
kubectl logs -n api-service-local deployment/api-service --tail=50 | grep -i "stripe\|webhook\|checkout"
```

### 7.4 Check Stripe Dashboard

In Stripe Dashboard:
1. Go to **Payments** - see the test payment
2. Go to **Customers** - see the customer created
3. Go to **Developers → Events** - see webhook events

---

## Part 8: Production Checklist

Before going live:

- [ ] Switch Stripe Dashboard to **Live mode**
- [ ] Get **Live API keys** (start with `pk_live_` and `sk_live_`)
- [ ] Create **Live products and prices** (copy from test)
- [ ] Update `tiers.json` with **Live Price IDs**
- [ ] Create **Live webhook endpoint** with production URL
- [ ] Update Vault with **Live secrets**
- [ ] Rebuild and deploy API service and dashboard
- [ ] Test with a real card (small amount, then refund)
- [ ] Enable Stripe Radar for fraud protection
- [ ] Set up Stripe alerts and notifications

---

## Troubleshooting

### Error: "No such price"
- The Price ID in `tiers.json` doesn't exist in Stripe
- Ensure you're using the correct mode (test vs live)
- Verify the Price ID is copied correctly

### Error: "Invalid API Key"
- Check if API key matches the mode (test key for test mode)
- Ensure the secret key is correctly set in environment/Vault

### Webhook not receiving events
- Verify endpoint URL is correct and accessible
- Check webhook signing secret matches
- For local dev, ensure `stripe listen` is running

### Payment succeeds but credits not added
- Check API logs for webhook processing errors
- Verify webhook events include `checkout.session.completed`
- Check database for credit transaction records

---

## Security Notes

1. **Never commit Stripe keys to Git** - use environment variables or Vault
2. **Publishable key** is safe to expose in frontend code
3. **Secret key** must never be exposed to clients
4. **Webhook secret** must be kept secure
5. Always validate webhook signatures before processing
6. Use HTTPS for all production webhook endpoints

---

## Related Documentation

- [Stripe API Documentation](https://stripe.com/docs/api)
- [Stripe Testing Guide](https://stripe.com/docs/testing)
- [Stripe CLI Reference](https://stripe.com/docs/stripe-cli)
- [Apogee Tier Standards](/home/pwner/Git/docs/standards/tier-standards.md)
- [Secrets Management](/home/pwner/Git/docs/standards/secrets-management.md)

---

## Document History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2026-02-02 | Initial playbook | Apogee Team |
| 1.1.0 | 2026-02-03 | Updated secrets to use Vault (not ConfigMap), updated webhook forwarding for kubeadm NodePort | Apogee Team |
| 1.2.0 | 2026-03-13 | Added API-based webhook creation, GCP Secret Manager update steps, updated event list for subscriptions | Apogee Team |
| 1.3.0 | 2026-03-13 | Competitive pricing adjustment per tiers.json v4.0: updated subscription prices, credit packages, quotas, and Stripe price IDs | Apogee Team |
