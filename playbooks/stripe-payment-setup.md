# Stripe Payment Setup Playbook

**Version:** 1.0.0
**Last Updated:** February 2, 2026
**Status:** Active

## Overview

This playbook covers setting up Stripe for credit card payments in the BlockSecOps platform. It includes both test mode setup for development and production configuration.

## Prerequisites

- Access to Stripe Dashboard (create account at https://stripe.com)
- Access to BlockSecOps API service configuration
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

BlockSecOps has two types of purchasable items:
1. **Credit Packages** - One-time purchases for scan credits
2. **Subscription Tiers** - Monthly/annual subscriptions for platform access

### 3.1 Product Summary Table

Create the following products in Stripe Dashboard (**Products → Add product**):

#### Credit Packages (One-Time Payments)

| Product Name | Credits | Price | Type | Config Key |
|--------------|---------|-------|------|------------|
| Credits - Starter | 10 | $30.00 | One-time | `creditPackages.starter.stripePriceId` |
| Credits - Builder | 50 | $125.00 | One-time | `creditPackages.builder.stripePriceId` |
| Credits - Pro | 200 | $400.00 | One-time | `creditPackages.pro.stripePriceId` |
| Credits - Bulk | 1000 | $1500.00 | One-time | `creditPackages.bulk.stripePriceId` |

#### Subscription Tiers (Recurring Payments)

| Product Name | Monthly Price | Annual Price | Features |
|--------------|---------------|--------------|----------|
| Developer (Free) | $0 | $0 | No Stripe product needed |
| Team | $299/month | $2,988/year ($249/mo) | 50 scans/mo, 5 team members, API access |
| Growth | $699/month | $7,188/year ($599/mo) | 200 scans/mo, 20 team members, priority support |
| Enterprise | $1,999/month | Contact Sales | Unlimited scans, SSO, dedicated support |

### 3.2 Create Credit Package Products

For each credit package:

1. Go to **Products → Add product**
2. Fill in the details:

**Credits - Starter**
```
Name:        Credits - Starter (10 credits)
Description: 10 scan credits for BlockSecOps smart contract security scanning
Pricing:     $30.00 USD - One time
```

**Credits - Builder**
```
Name:        Credits - Builder (50 credits)
Description: 50 scan credits for BlockSecOps - Save 17% ($2.50/credit)
Pricing:     $125.00 USD - One time
```

**Credits - Pro**
```
Name:        Credits - Pro (200 credits)
Description: 200 scan credits for BlockSecOps - Save 33% ($2.00/credit)
Pricing:     $400.00 USD - One time
```

**Credits - Bulk**
```
Name:        Credits - Bulk (1000 credits)
Description: 1000 scan credits for BlockSecOps - Save 50% ($1.50/credit)
Pricing:     $1500.00 USD - One time
```

3. After saving each product, copy the **Price ID** from the product page

### 3.3 Create Subscription Tier Products

For subscription tiers, each product needs TWO prices (monthly and annual):

**Team Tier**
```
Name:        BlockSecOps Team
Description: Team plan - 50 scans/month, 5 team members, API access, email support

Add two prices:
  - $299.00 USD - Recurring monthly
  - $2,988.00 USD - Recurring yearly (saves $600/year)
```

**Growth Tier**
```
Name:        BlockSecOps Growth
Description: Growth plan - 200 scans/month, 20 team members, priority support, webhooks

Add two prices:
  - $699.00 USD - Recurring monthly
  - $7,188.00 USD - Recurring yearly (saves $1,200/year)
```

**Enterprise Tier**
```
Name:        BlockSecOps Enterprise
Description: Enterprise plan - Unlimited scans, SSO, dedicated support, custom integrations

Add one price:
  - $1,999.00 USD - Recurring monthly
  (Annual pricing handled via sales contracts)
```

### 3.4 Record All Price IDs

After creating all products, record the Price IDs:

```
# Credit Packages (One-time)
credits_starter:      price_1Nxxxxxxxxxxxxx
credits_builder:      price_1Nxxxxxxxxxxxxx
credits_pro:          price_1Nxxxxxxxxxxxxx
credits_bulk:         price_1Nxxxxxxxxxxxxx

# Team Tier (Subscription)
team_monthly:         price_1Nxxxxxxxxxxxxx
team_annual:          price_1Nxxxxxxxxxxxxx

# Growth Tier (Subscription)
growth_monthly:       price_1Nxxxxxxxxxxxxx
growth_annual:        price_1Nxxxxxxxxxxxxx

# Enterprise Tier (Subscription)
enterprise_monthly:   price_1Nxxxxxxxxxxxxx
```

---

## Part 4: Configure BlockSecOps

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
    "price": 30.00,
    "perCredit": 3.00,
    "savings": null,
    "stripePriceId": "price_1Nxxxxxxxxxxxxx"
  },
  "builder": {
    "credits": 50,
    "price": 125.00,
    "perCredit": 2.50,
    "savings": "17%",
    "stripePriceId": "price_1Nxxxxxxxxxxxxx"
  },
  "pro": {
    "credits": 200,
    "price": 400.00,
    "perCredit": 2.00,
    "savings": "33%",
    "stripePriceId": "price_1Nxxxxxxxxxxxxx"
  },
  "bulk": {
    "credits": 1000,
    "price": 1500.00,
    "perCredit": 1.50,
    "savings": "50%",
    "stripePriceId": "price_1Nxxxxxxxxxxxxx"
  }
}
```

#### Update Subscription Tiers

Find each tier in the `tiers` section and update the Stripe Price IDs:

**Team Tier** (in `tiers.team`):
```json
"team": {
  "name": "Team",
  "pricing": {
    "monthly": 299,
    "annual": 2988
  },
  "stripePriceIdMonthly": "price_1Nxxxxxxxxxxxxx",
  "stripePriceIdAnnual": "price_1Nxxxxxxxxxxxxx",
  ...
}
```

**Growth Tier** (in `tiers.growth`):
```json
"growth": {
  "name": "Growth",
  "pricing": {
    "monthly": 699,
    "annual": 7188
  },
  "stripePriceIdMonthly": "price_1Nxxxxxxxxxxxxx",
  "stripePriceIdAnnual": "price_1Nxxxxxxxxxxxxx",
  ...
}
```

**Enterprise Tier** (in `tiers.enterprise`):
```json
"enterprise": {
  "name": "Enterprise",
  "pricing": {
    "monthly": 1999,
    "annual": null
  },
  "stripePriceIdMonthly": "price_1Nxxxxxxxxxxxxx",
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

1. Go to **Developers → Webhooks**
2. Click **Add endpoint**
3. Configure:
   - **Endpoint URL:** `https://app.0xapogee.com/api/v1/webhooks/stripe` (production)
   - **Events to send:** Select these events:
     - `checkout.session.completed`
     - `payment_intent.succeeded`
     - `payment_intent.payment_failed`
4. Click **Add endpoint**
5. Copy the **Signing secret** (starts with `whsec_...`)

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
REGISTRY="harbor.0xapogee.local"
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
REGISTRY="harbor.0xapogee.local"
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
5. Click "Pay $125.00 with Card"
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
- [BlockSecOps Tier Standards](/home/pwner/Git/docs/standards/tier-standards.md)
- [Secrets Management](/home/pwner/Git/docs/standards/secrets-management.md)

---

## Document History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2026-02-02 | Initial playbook | BlockSecOps Team |
| 1.1.0 | 2026-02-03 | Updated secrets to use Vault (not ConfigMap), updated webhook forwarding for kubeadm NodePort | BlockSecOps Team |
