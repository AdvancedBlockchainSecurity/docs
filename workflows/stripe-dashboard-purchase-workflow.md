# Stripe Dashboard Purchase Workflow

**Quick Reference for Testing Stripe Payments in the Dashboard**

---

## Key Concepts

```
┌─────────────────────────────────────────────────────────────────────┐
│                         STRIPE KEYS                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   PUBLISHABLE KEY (pk_test_...)        SECRET KEY (sk_test_...)     │
│   ┌─────────────────────────┐          ┌─────────────────────────┐  │
│   │  Frontend (Dashboard)   │          │  Backend (API Service)  │  │
│   │  - Initialize Stripe.js │          │  - Verify webhooks      │  │
│   │  - Show payment forms   │          │  - Process charges      │  │
│   │  - Create sessions      │          │  - Manage subscriptions │  │
│   │  SAFE TO EXPOSE         │          │  MUST BE SECRET         │  │
│   └─────────────────────────┘          └─────────────────────────┘  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Pre-Flight Checklist

| Requirement | Command to Verify | Expected Result |
|-------------|------------------|-----------------|
| API Service Running | `kubectl get pods -n api-service-local` | `1/1 Running` |
| Dashboard Running | `kubectl get pods -n dashboard-local` | `1/1 Running` |
| Stripe Secret in Vault | `kubectl exec vault-0 -n vault-local -- ...` | Shows `api_key` and `webhook_secret` |
| Stripe Listener Running | `pgrep -f "stripe listen"` | Returns PID |
| ExternalSecret Synced | `kubectl get externalsecret -n api-service-local` | `SecretSynced True` |

---

## Quick Start Workflow

### Step 1: Verify Backend Configuration

```bash
# Check Stripe secrets in Vault
ROOT_TOKEN=$(kubectl exec vault-0 -n vault-local -- cat /vault/data/.vault-init.json 2>/dev/null | jq -r '.root_token')
kubectl exec vault-0 -n vault-local -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault kv get secret/local/api-service/stripe"
```

### Step 2: Start Webhook Forwarding

```bash
# Start Stripe CLI listener (kubeadm)
export STRIPE_API_KEY="sk_test_YOUR_KEY"
~/bin/stripe listen \
  --api-key "$STRIPE_API_KEY" \
  --forward-to http://192.168.86.225:30180/api/v1/webhooks/stripe

# For minikube:
# --forward-to http://127.0.0.1:3000/api/v1/webhooks/stripe
```

### Step 3: Configure Dashboard (if needed)

The dashboard needs the **publishable key**. Rebuild if not configured:

```bash
cd /home/pwner/Git
STRIPE_PK="pk_test_YOUR_PUBLISHABLE_KEY"

docker build --no-cache \
  -f blocksecops-dashboard/Dockerfile \
  --build-arg VITE_STRIPE_PUBLISHABLE_KEY=${STRIPE_PK} \
  --build-arg VITE_SUPABASE_URL=$(kubectl get cm dashboard-config -n dashboard-local -o jsonpath='{.data.supabase_url}') \
  --build-arg VITE_SUPABASE_ANON_KEY=$(kubectl get cm dashboard-config -n dashboard-local -o jsonpath='{.data.supabase_anon_key}') \
  -t harbor.blocksecops.local/blocksecops/dashboard:latest .

docker push harbor.blocksecops.local/blocksecops/dashboard:latest
kubectl rollout restart deployment/dashboard -n dashboard-local
```

### Step 4: Test Purchase

1. Open dashboard: `http://app.0xapogee.local` or `http://127.0.0.1:3000`
2. Log in → Navigate to **Billing** or **Credits**
3. Select a plan or credit package
4. Click **Purchase** / **Subscribe**
5. Use test card: `4242 4242 4242 4242`
6. Complete checkout

### Step 5: Verify Success

```bash
# Check webhook was received (look for [200] responses)
cat /tmp/stripe-listener.log | tail -10

# Check API logs
kubectl logs deployment/api-service -n api-service-local --tail=20 | grep -i stripe
```

---

## Test Card Numbers

| Card | Result |
|------|--------|
| `4242 4242 4242 4242` | Success |
| `4000 0000 0000 3220` | 3D Secure required |
| `4000 0000 0000 9995` | Decline (insufficient funds) |
| `4000 0000 0000 0002` | Decline (generic) |

**All cards:** Expiry: `12/34`, CVC: `123`, ZIP: `12345`

---

## Payment Flow Diagram

```
┌──────────┐    ┌───────────┐    ┌─────────────┐    ┌────────┐
│ Dashboard │───▶│ API Service│───▶│Stripe Checkout│───▶│ Stripe │
│ (Browser) │    │ (Backend)  │    │   (Hosted)    │    │ Server │
└──────────┘    └───────────┘    └─────────────┘    └────────┘
     │                                                    │
     │              ┌─────────────────────────────────────┘
     │              │ Webhook: checkout.session.completed
     │              ▼
     │         ┌───────────┐
     │         │ API Service│ ──▶ Update database
     │         │ (Webhook)  │ ──▶ Add credits/subscription
     │         └───────────┘
     │              │
     └──────────────┘ Redirect to success page
```

---

## Common Issues & Solutions

### Dashboard shows "Stripe not configured"

```bash
# Check if publishable key is set (should show the key, not empty)
kubectl exec deployment/dashboard -n dashboard-local -- printenv | grep STRIPE
# If empty, rebuild dashboard with VITE_STRIPE_PUBLISHABLE_KEY
```

### Webhook returns non-200

```bash
# Check webhook secret matches
kubectl exec vault-0 -n vault-local -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault kv get -field=webhook_secret secret/local/api-service/stripe"

# Compare with Stripe CLI output
~/bin/stripe listen --api-key "$STRIPE_API_KEY" --print-secret
```

### Checkout fails immediately

```bash
# Check API can reach Stripe
kubectl exec deployment/api-service -n api-service-local -- curl -s https://api.stripe.com/v1/charges -u "sk_test_YOUR_KEY:" | head -5

# Check API logs for errors
kubectl logs deployment/api-service -n api-service-local --tail=50 | grep -i error
```

---

## Environment URLs

| Environment | Dashboard URL | Webhook Endpoint |
|-------------|--------------|------------------|
| minikube | `http://127.0.0.1:3000` | `http://127.0.0.1:3000/api/v1/webhooks/stripe` |
| kubeadm (server) | `http://app.0xapogee.local` | `http://192.168.86.225:30180/api/v1/webhooks/stripe` |
| GCP Production | `https://app.0xapogee.com` | `https://app.0xapogee.com/api/v1/webhooks/stripe` |

---

## Related Documentation

- [Stripe Dashboard Purchase Playbook](../playbooks/stripe-dashboard-purchase-playbook.md) - Detailed guide
- [Stripe Payment Setup Playbook](../playbooks/stripe-payment-setup.md) - Initial configuration
- [Secrets Management Standards](../standards/secrets-management.md) - Vault configuration

---

*Last Updated: February 3, 2026*
