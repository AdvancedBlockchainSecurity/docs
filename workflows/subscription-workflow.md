# Subscription Workflow

End-to-end subscription lifecycle for Stripe billing, tier changes, and x402 pay-per-scan payments.

---

## Overview

```
User Registration          Stripe Checkout           Webhook Handler
──────────────────         ───────────────           ───────────────
Sign up via Supabase  →    developer tier (free)  →  UserQuotaModel created
                           No Stripe customer        3 contracts/month
                           No subscription            7-day retention

Upgrade Flow               Stripe Hosted Page        Database Updates
────────────               ──────────────────        ────────────────
Pricing page click    →    Stripe Checkout session →  checkout.session.completed webhook
Select tier + interval     User enters payment info   Create SubscriptionModel
POST /billing/checkout     Complete payment            Update user.tier + user_quotas
                                                       Assign stripe_customer_id
```

---

## Services Involved

| Service | Role | Port |
|---------|------|------|
| API Service | Billing endpoints, Stripe integration, webhook handler | 8000 |
| Dashboard | Pricing page, Billing page, TierChangeModal | 3000 (via Traefik) |
| PostgreSQL | Subscription, billing, payment, and quota data | 5432 |
| Stripe (external) | Payment processing, hosted checkout, customer portal | — |
| x402 Facilitator (external) | USDC payment verification on Base | — |

---

## Subscription Lifecycle

### 1. User Registration (Developer Tier)

| Step | Description |
|------|-------------|
| User signs up | Supabase Auth creates account |
| Database trigger | `create_user_quota()` fires on user insert |
| Default tier | `developer` — free, 3 contracts/month, no API access |
| No Stripe objects | No customer, no subscription, no billing details |

### 2. Upgrade to Paid Tier

| Step | Description |
|------|-------------|
| User visits Pricing page | `GET /billing/plans` returns all tier options (public endpoint) |
| User selects tier + interval | Team/Growth/Enterprise, monthly or annual |
| Dashboard calls API | `POST /billing/checkout` with `plan_tier` and `billing_interval` |
| API creates Stripe Checkout | `StripeService.create_checkout_session()` — creates/retrieves Stripe customer |
| User redirected | To Stripe hosted checkout page |
| User completes payment | Card details entered on Stripe's secure page |
| Stripe fires webhook | `checkout.session.completed` event sent to `/api/v1/webhooks/stripe` |
| Webhook handler | Creates `SubscriptionModel`, calls `handle_tier_change()` |
| Tier propagation | `user.tier` updated, `sync_user_quotas_to_tier()` updates `UserQuotaModel` |
| User redirected back | To dashboard success page |

### 3. Tier Change (Upgrade)

| Step | Description |
|------|-------------|
| User clicks upgrade | TierChangeModal opens, selects new tier |
| Preview | `GET /billing/subscription/change-tier/preview` shows proration |
| Confirm | `POST /billing/subscription/change-tier` with `new_tier`, `billing_interval` |
| Proration | **Immediate** — user charged prorated amount for remainder of billing period |
| Stripe update | Subscription item changed to new price ID |
| Webhook | `customer.subscription.updated` fires, syncs new tier |
| Quota update | `sync_user_quotas_to_tier()` applies new limits immediately |

### 4. Tier Change (Downgrade)

| Step | Description |
|------|-------------|
| User clicks downgrade | TierChangeModal opens, selects lower tier |
| Preview | Shows effective date (end of current billing period) |
| Confirm | `POST /billing/subscription/change-tier` |
| Proration | **Deferred** — change takes effect at period end, no immediate charge/refund |
| Stripe schedules | Subscription updates at `current_period_end` |
| Webhook | `customer.subscription.updated` fires at period end |
| Quota update | Quotas reduced at period end, usage counters preserved |

### 5. Cancellation

| Step | Description |
|------|-------------|
| User cancels | `POST /billing/subscription/cancel` |
| Cancel at period end (default) | `cancel_immediately: false` — access continues until period end |
| Cancel immediately | `cancel_immediately: true` — access revoked now |
| Stripe webhook | `customer.subscription.deleted` fires |
| Tier revert | User downgraded to `developer` tier |
| Quota reset | `sync_user_quotas_to_tier("developer")` — 3 contracts/month |
| Stripe IDs cleared | `user.stripe_subscription_id` set to null |

### 6. Reactivation

| Step | Description |
|------|-------------|
| User reactivates | `POST /billing/subscription/reactivate` |
| Precondition | `cancel_at_period_end` must be `true` (deferred cancellation) |
| Result | Cancellation reversed, subscription continues as before |

---

## x402 Pay-Per-Scan (Supplement to Subscription)

x402 payments use USDC on Base blockchain for per-scan or credit package purchases.

### Per-Scan Payment Flow

| Step | Description |
|------|-------------|
| User initiates scan | Scan complexity determined by file count + LoC |
| Price calculated | `PricingService.calculate_scan_price()` returns USDC amount |
| 402 response | If payment required, API returns HTTP 402 with x402 `accepts` array |
| User pays | Wallet sends USDC to payment address on Base |
| Payment header | `X-PAYMENT` header with base64-encoded payment info |
| Verification | `PaymentService.verify_payment()` calls facilitator URL |
| Record created | `PaymentTransactionModel` stored with tx_hash, status=verified |
| Scan proceeds | Credits deducted or per-scan charge applied |

### Scan Complexity Pricing

| Complexity | Files | Max LoC | Price (USDC) |
|------------|-------|---------|--------------|
| Micro | 1–5 | 4,000 | $3.00 |
| Small | 6–25 | 20,000 | $7.00 |
| Medium | 26–100 | 75,000 | $15.00 |
| Large | 100+ | Unlimited | $25.00 |

### Credit Package Purchases

Credit packages can be purchased via Stripe Checkout or x402 crypto payment.

| Package | Credits | Price | Per-Credit | Savings |
|---------|---------|-------|------------|---------|
| Starter | 10 | $30 | $3.00 | — |
| Builder | 50 | $125 | $2.50 | 17% |
| Pro | 200 | $400 | $2.00 | 33% |
| Bulk | 1,000 | $1,500 | $1.50 | 50% |

**Stripe credit purchase flow:**

| Step | Description |
|------|-------------|
| User selects package | `POST /billing/credits/checkout` with `package_id` |
| Stripe Checkout | One-time payment mode (not subscription) |
| Webhook | `checkout.session.completed` with `mode=payment` |
| Idempotency | `x402_payment_id` field prevents double-crediting |
| Server-side validation | Package credits read from `blocksecops-tier-config`, never from metadata |
| Credits added | `CreditService.add_credits()` updates `ScanCreditModel.balance` |

---

## Organization Relationship

```
1 Owner  ──→  1 Organization  ──→  1 Stripe Subscription
                    │
                    ├──→  N Teams
                    ├──→  N Members (via roles)
                    └──→  N Contracts, Scans, Projects (org-scoped)
```

| Rule | Description |
|------|-------------|
| 1 owner = 1 org | A user can only own one active organization |
| 1 org = 1 subscription | Each organization has at most one Stripe subscription |
| Teams subdivide | Use teams for internal organization, not extra orgs |
| Org-scoped billing | Subscription tier applies to entire org |
| Enterprise only | Organization creation requires enterprise tier |

---

## Subscription Status States

| Status | Description | User Impact |
|--------|-------------|-------------|
| `active` | Payment current, full access | Normal operation |
| `past_due` | Payment failed, grace period | Access continues, retry in progress |
| `canceled` | Subscription ended | Reverted to developer tier |
| `trialing` | Trial period (if enabled) | Full tier access |
| `incomplete` | Initial payment pending | Limited access |
| `incomplete_expired` | Initial payment failed | No paid access |
| `unpaid` | Multiple payment failures | Access may be restricted |
| `paused` | Manually paused | No paid access |

---

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/billing/plans` | GET | List available plans (public) |
| `/billing/checkout` | POST | Create Stripe Checkout session |
| `/billing/portal` | POST | Create Stripe Customer Portal session |
| `/billing/subscription` | GET | Get current subscription |
| `/billing/subscription/cancel` | POST | Cancel subscription |
| `/billing/subscription/reactivate` | POST | Reactivate deferred cancellation |
| `/billing/subscription/change-tier` | POST | Upgrade or downgrade tier |
| `/billing/subscription/change-tier/preview` | GET | Preview tier change costs |
| `/billing/invoices` | GET | List invoices |
| `/billing/invoices/{id}/pdf` | GET | Get invoice PDF URL |
| `/billing/details` | GET/PUT | Billing details (company, address, tax) |
| `/billing/history` | GET | Combined Stripe + x402 billing history |
| `/billing/plan-limit` | GET | Current plan's scan limit |

---

## Frontend Components

| Component | File | Purpose |
|-----------|------|---------|
| Pricing.tsx | `blocksecops-dashboard/src/pages/` | Tier comparison and checkout initiation |
| Billing.tsx | `blocksecops-dashboard/src/pages/` | Subscription card, quota usage, billing history |
| TierChangeModal.tsx | `blocksecops-dashboard/src/components/billing/` | Multi-step upgrade/downgrade flow |

---

## Configuration

### Environment Variables

| Variable | Source | Description |
|----------|--------|-------------|
| `stripe_api_key` | Vault: `secret/local/api-service/stripe` | Stripe secret key (`sk_test_...` / `sk_live_...`) |
| `stripe_webhook_secret` | Vault: `secret/local/api-service/stripe` | Webhook signing secret (`whsec_...`) |
| `STRIPE_PRICE_TEAM_MONTHLY` | Config | Stripe price ID for team monthly |
| `STRIPE_PRICE_TEAM_ANNUAL` | Config | Stripe price ID for team annual |
| `STRIPE_PRICE_GROWTH_MONTHLY` | Config | Stripe price ID for growth monthly |
| `STRIPE_PRICE_GROWTH_ANNUAL` | Config | Stripe price ID for growth annual |
| `STRIPE_PRICE_ENTERPRISE_MONTHLY` | Config | Stripe price ID for enterprise monthly |
| `STRIPE_PRICE_ENTERPRISE_ANNUAL` | Config | Stripe price ID for enterprise annual |
| `X402_FACILITATOR_URL` | Config | x402 payment verification endpoint |
| `X402_PAYMENT_ADDRESS` | Config | USDC recipient address on Base |
| `X402_CHAIN_ID` | Config | Base mainnet (8453) |

### Deployment

After modifying billing or subscription code in the API service, follow the standard build and deploy workflow:

```bash
# 1. Bump version in pyproject.toml
cd /home/pwner/Git/blocksecops-api-service
sed -i 's/version = ".*"/version = "X.Y.Z"/' pyproject.toml

# 2. Update kustomization newTag to match
# k8s/overlays/local/api-service/kustomization.yaml → newTag: "X.Y.Z"

# 3. Build and push (Harbor)
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
docker build -t harbor.blocksecops.local/blocksecops/api-service:${VERSION} .
docker push harbor.blocksecops.local/blocksecops/api-service:${VERSION}

# 4. Apply and restart
kubectl apply -k k8s/overlays/local/api-service/
kubectl rollout restart deployment/api-service -n api-service-local
kubectl rollout status deployment/api-service -n api-service-local
```

See [Docker Image Versioning](../standards/docker-image-versioning.md) and [Kustomize Standards](../standards/kustomize-standards.md) for full details.

---

## Related Documentation

- [Subscription Pipeline](../pipelines/subscription-pipeline.md) — Technical implementation details
- [Stripe Dashboard Purchase Workflow](./stripe-dashboard-purchase-workflow.md) — Testing Stripe payments locally
- [Tier Standards](../standards/tier-standards.md) — Tier definitions, quotas, and pricing
- [Organization Scoping Pipeline](../pipelines/organization-scoping-pipeline.md) — Org data isolation
- [Docker Image Versioning](../standards/docker-image-versioning.md) — Version bump workflow
- [Kustomize Standards](../standards/kustomize-standards.md) — Base/overlay deployment patterns
- [Database Management](../standards/database-management.md) — Backup requirements for data changes
- [Port Forwarding](../standards/port-forwarding.md) — Service access patterns
- [Secrets Management](../standards/secrets-management.md) — Vault configuration for Stripe keys

---

*Last Updated: February 7, 2026*
