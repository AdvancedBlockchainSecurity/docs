# Subscription Pipeline

Technical pipeline for Stripe billing integration, webhook processing, tier propagation, and x402 payment verification.

## Overview

```
Stripe API               Webhook Endpoint                  Database
──────────               ────────────────                  ────────
Checkout sessions   →    POST /api/v1/webhooks/stripe  →   SubscriptionModel
Customer portal     →    Signature verification        →   UserModel.tier
Price changes       →    Event routing (6 events)      →   UserQuotaModel
Invoices            →    Tier sync + audit logging     →   BillingDetailsModel

x402 Facilitator         Payment Verification              Database
────────────────         ────────────────────              ────────
USDC on Base        →    PaymentService.verify_payment →   PaymentTransactionModel
Blockchain confirm  →    Facilitator HTTP call         →   ScanCreditModel
                         Idempotency check             →   CreditTransactionModel
```

---

## Stripe Integration Architecture

### Checkout Flow

| Step | Component | Action |
|------|-----------|--------|
| 1 | `billing.py` | `POST /billing/checkout` — receives `plan_tier`, `billing_interval` |
| 2 | `StripeService` | `get_or_create_customer(user, db)` — maps user to Stripe customer |
| 3 | `StripeService` | `create_checkout_session()` — builds line_items from price ID |
| 4 | Stripe | Hosts payment page, collects card details |
| 5 | `stripe_webhook.py` | Receives `checkout.session.completed` |
| 6 | Webhook handler | Creates `SubscriptionModel`, calls `handle_tier_change()` |
| 7 | `sync_user_quotas_to_tier()` | Updates `UserQuotaModel` with new tier quotas |

### Customer Portal

| Step | Component | Action |
|------|-----------|--------|
| 1 | `billing.py` | `POST /billing/portal` — creates portal session |
| 2 | `StripeService` | Returns portal URL for payment method/invoice management |
| 3 | Stripe | User manages billing in Stripe-hosted portal |
| 4 | `stripe_webhook.py` | Receives `customer.subscription.updated` if tier changed via portal |

### Price ID Mapping

| Tier | Monthly | Annual |
|------|---------|--------|
| Starter | `STRIPE_PRICE_STARTER_MONTHLY` | `STRIPE_PRICE_STARTER_ANNUAL` |
| Growth | `STRIPE_PRICE_GROWTH_MONTHLY` | `STRIPE_PRICE_GROWTH_ANNUAL` |
| Enterprise | `STRIPE_PRICE_ENTERPRISE_MONTHLY` | `STRIPE_PRICE_ENTERPRISE_ANNUAL` |

Price IDs are environment-configurable via `src/infrastructure/config.py`. The `StripeService` maps `(tier, interval)` tuples to Stripe price IDs.

---

## Webhook Event Handling

**Endpoint:** `POST /api/v1/webhooks/stripe`
**File:** `blocksecops-api-service/src/presentation/api/v1/endpoints/stripe_webhook.py`

### Production Webhook Endpoint

| Setting | Value |
|---------|-------|
| URL | `https://app.0xapogee.com/api/v1/webhooks/stripe` |
| Endpoint ID | `we_1TAe593ZtjkVcNXVjsJGk7rs` |
| Signing Secret | `apogee-gcp-stripe-webhook-secret` (GCP Secret Manager, version 3) |

### Events Processed

| Event | Handler | Effect |
|-------|---------|--------|
| `checkout.session.completed` | Subscription or credit purchase | Creates SubscriptionModel OR adds credits |
| `customer.subscription.updated` | Tier/status change | Syncs tier, updates quotas, logs audit |
| `customer.subscription.deleted` | Cancellation | Downgrades to developer, clears Stripe IDs |
| `invoice.payment_succeeded` | Payment success | Marks subscription ACTIVE (reactivates if PAST_DUE) |
| `invoice.payment_failed` | Payment failure | Marks subscription PAST_DUE |
| `customer.updated` | Customer data change | Logged only (no action) |

### checkout.session.completed

Two modes based on `session.mode`:

**Subscription mode (`mode=subscription`):**

```
Webhook received
  → Parse subscription metadata (whitelist approach)
  → Create SubscriptionModel record
  → Update user.stripe_subscription_id
  → handle_tier_change(user, new_tier, source="stripe_checkout")
  → sync_user_quotas_to_tier(db, user_id, tier)
```

**Payment mode (`mode=payment`) — Credit purchase:**

```
Webhook received
  → Extract package_id from metadata
  → Idempotency check: has x402_payment_id been processed?
  → Validate package_id against server-side config (never trust metadata for credits)
  → CreditService.add_credits(user_id, credits, package_id)
  → Create PaymentTransactionModel + CreditTransactionModel
```

### customer.subscription.updated

```
Webhook received
  → Find SubscriptionModel by stripe_subscription_id
  → Update status, period_start, period_end, cancel_at_period_end
  → Detect tier change from Stripe price ID mapping
  → If tier changed:
      → handle_tier_change(user, new_tier, source="stripe_portal")
      → sync_user_quotas_to_tier(db, user_id, new_tier)
```

### customer.subscription.deleted

```
Webhook received
  → Mark SubscriptionModel as CANCELED
  → handle_tier_change(user, "developer", source="subscription_deleted")
  → Clear user.stripe_subscription_id
  → sync_user_quotas_to_tier(db, user_id, "developer")
```

---

## Tier Change Propagation

```
Trigger (API or Webhook)
  │
  ├── 1. Stripe subscription updated (price change)
  │
  ├── 2. handle_tier_change(user, new_tier, source)
  │       → log_tier_change() — audit trail with old_tier, new_tier, source
  │       → user.tier = new_tier
  │       → user.tier_updated_at = now()
  │
  ├── 3. sync_user_quotas_to_tier(db, user_id, tier)
  │       → get_tier_quotas_for_db(tier) from blocksecops-tier-config
  │       → Update UserQuotaModel with new limits
  │       → Usage counters preserved (monthly_scans_used, etc.)
  │
  ├── 4. Session invalidation (on downgrade)
  │       → Clear user sessions to force re-authentication
  │
  └── 5. API key revalidation
          → Existing API keys checked against new tier limits
```

---

## x402 Payment Verification Flow

**File:** `blocksecops-api-service/src/application/services/payment_service.py`

```
Client wallet
  │
  ├── 1. USDC transfer on Base (chain ID 8453)
  │       → To: X402_PAYMENT_ADDRESS
  │       → Token: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 (USDC on Base)
  │
  ├── 2. Client sends X-PAYMENT header (base64-encoded)
  │       → Contains: payment_id, tx_hash, from_address
  │
  ├── 3. PaymentService.process_scan_payment()
  │       → parse_payment_header(header)
  │       → Duplicate tx_hash check (idempotency)
  │       → verify_payment(tx_hash, expected_amount, from_address)
  │           → HTTP POST to X402_FACILITATOR_URL
  │           → Returns: (is_valid, error_message, facilitator_response)
  │
  ├── 4. Record transaction
  │       → PaymentTransactionModel created (status=verified)
  │       → Receipt number generated
  │
  └── 5. Scan proceeds or credits added
```

### Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `X402_FACILITATOR_URL` | `https://x402.org` | Payment verification endpoint |
| `X402_PAYMENT_ADDRESS` | `0x0000...` | USDC recipient address |
| `X402_NETWORK` | `base` | Blockchain network |
| `X402_CHAIN_ID` | `8453` | Base mainnet chain ID |
| `PAYMENT_EXPIRY_MINUTES` | `15` | Payment window |

---

## Organization Provisioning

Organization creation is part of the Enterprise tier activation flow. When an Enterprise subscription becomes active, the admin can provision an organization via the API.

### Provisioning Pipeline

```
Enterprise Subscription Active
  │
  ├── 1. Admin calls POST /organizations
  │       → require_tier("enterprise") middleware validates tier
  │       → Checks user doesn't already own an org
  │
  ├── 2. Organization created
  │       → OrganizationModel with tier=enterprise, owner_id=current_user
  │       → Unique slug generated/validated
  │
  ├── 3. Default system roles created
  │       → owner, admin, developer, auditor, guest
  │       → Each with predefined permission sets
  │
  ├── 4. Owner membership established
  │       → OrganizationMemberModel with owner role
  │       → User becomes org owner
  │
  ├── 5. Default team created
  │       → "General" team with is_default=True
  │       → Owner added as team lead
  │
  └── 6. Org ready for member management
          → Admin can add members via API
          → Members added to default team automatically
```

### Ownership Rules

| Rule | Enforcement |
|------|-------------|
| One owner per org | Set at creation, cannot be changed |
| Cannot add additional owners | `add_member`/`update_member` reject owner role assignment |
| Owner cannot self-remove | `remove_current_organization_user` blocks owner removal |
| Owner role immutable | `update_current_organization_user` blocks owner role change |
| Admin as alternative | Admin role has all management permissions except billing |

---

## Security Controls

### Stripe Webhook Security

| Control | Implementation | Reference |
|---------|----------------|-----------|
| Signature verification | `Stripe-Signature` header validated against `stripe_webhook_secret` | BSO-SEC-BIZ-001 |
| Metadata sanitization | `_sanitize_metadata_value()` — truncates to 500 chars, removes control chars | BSO-SEC-BIZ-001 |
| Tier whitelist | `parse_subscription_metadata()` validates against `VALID_TIERS` | BSO-SEC-BIZ-001 |
| Billing interval validation | Only `monthly` or `annual` accepted | BSO-SEC-BIZ-001 |
| Invalid tier logging | Logs security alert on invalid tier attempts | BSO-SEC-BIZ-001 |
| Signature failure alert | `TierSecurityAlert.STRIPE_SIGNATURE_FAILURE` logged | BSO-SEC-BIZ-001 |

### x402 Payment Security

| Control | Implementation | Reference |
|---------|----------------|-----------|
| Idempotency | `x402_payment_id` and `tx_hash` checked for duplicates | BSO-SEC-015 |
| Server-side credits | Credit amounts read from `blocksecops-tier-config`, never from client metadata | BSO-SEC-015 |
| Facilitator verification | External verification via facilitator HTTP call | BSO-SEC-015 |
| Audit logging | `PaymentTransactionModel` created for every transaction | BSO-SEC-015 |

### Metadata Parsing (Whitelist Approach)

```python
# parse_subscription_metadata() — only reads expected keys
Expected keys: plan_tier, billing_interval, user_id, payment_type, package_id
All other metadata keys: IGNORED
Invalid tier value: defaults to "starter", logged as security event
Invalid billing_interval: defaults to "monthly"
```

---

## Database Models

### SubscriptionModel (`subscriptions`)

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `user_id` | UUID FK | Owner |
| `organization_id` | UUID FK | Associated organization (nullable) |
| `stripe_subscription_id` | String (unique) | Stripe sub_* ID |
| `stripe_customer_id` | String | Stripe cus_* ID |
| `stripe_price_id` | String | Active price ID |
| `plan_tier` | String | starter, growth, enterprise |
| `billing_interval` | String | monthly, annual |
| `status` | String | active, past_due, canceled, etc. |
| `current_period_start` | DateTime | Billing period start |
| `current_period_end` | DateTime | Billing period end |
| `cancel_at_period_end` | Boolean | Deferred cancellation flag |
| `canceled_at` | DateTime | When cancellation was requested |
| `cancellation_reason` | String | User-provided reason |
| `stripe_metadata` | JSONB | Stripe metadata |

### BillingDetailsModel (`billing_details`)

| Column | Type | Description |
|--------|------|-------------|
| `user_id` | UUID FK (unique) | One-to-one with user |
| `company_name` | String | Company name |
| `billing_email` | String | Billing contact email |
| `address_line1/2` | String | Street address |
| `city`, `state`, `postal_code` | String | Location |
| `country` | String | ISO 3166-1 alpha-2 (US, GB, etc.) |
| `tax_id`, `tax_id_type` | String | eu_vat, us_ein, etc. |
| `tax_exempt` | Boolean | Tax exemption flag |

### PaymentTransactionModel (`payment_transactions`)

| Column | Type | Description |
|--------|------|-------------|
| `payment_type` | String | per_scan, credits |
| `amount_usd` | Numeric(10,4) | Payment amount |
| `token` | String | USDC (default) |
| `network` | String | base (default) |
| `tx_hash` | String (indexed) | Blockchain transaction hash |
| `from_address` | String | Sender wallet |
| `to_address` | String | Recipient wallet |
| `x402_payment_id` | String | x402 protocol payment ID |
| `status` | String (indexed) | pending, verified, failed, refunded |
| `credits_purchased` | Integer | Credits for package purchases |
| `scan_id` | UUID FK | Associated scan (nullable) |

### ScanCreditModel (`scan_credits`)

| Column | Type | Description |
|--------|------|-------------|
| `user_id` | UUID FK (unique) | One-to-one with user |
| `balance` | Integer | Current credit balance |
| `total_purchased` | Integer | Lifetime purchases |
| `total_used` | Integer | Lifetime usage |

### CreditTransactionModel (`credit_transactions`)

| Column | Type | Description |
|--------|------|-------------|
| `user_id` | UUID FK | Owner |
| `credits` | Integer | Positive=purchase, negative=usage |
| `balance_after` | Integer | Running balance |
| `transaction_type` | String | purchase, scan_usage, refund, gift |
| `payment_transaction_id` | UUID FK | Linked payment (nullable) |
| `scan_id` | UUID FK | Linked scan (nullable) |

---

## Environment Configuration

### Stripe Keys

| Variable | Description | Source |
|----------|-------------|--------|
| `stripe_api_key` | Secret key (`sk_test_...` or `sk_live_...`) | Vault: `secret/local/api-service/stripe` |
| `stripe_webhook_secret` | Webhook signing secret (`whsec_...`) | Vault: `secret/local/api-service/stripe` |
| `stripe_tax_enabled` | Enable Stripe automatic tax | Config |

### Stripe Price IDs

| Variable | Description |
|----------|-------------|
| `STRIPE_PRICE_STARTER_MONTHLY` | Starter tier monthly price ID |
| `STRIPE_PRICE_STARTER_ANNUAL` | Starter tier annual price ID |
| `STRIPE_PRICE_GROWTH_MONTHLY` | Growth tier monthly price ID |
| `STRIPE_PRICE_GROWTH_ANNUAL` | Growth tier annual price ID |
| `STRIPE_PRICE_ENTERPRISE_MONTHLY` | Enterprise tier monthly price ID |
| `STRIPE_PRICE_ENTERPRISE_ANNUAL` | Enterprise tier annual price ID |

### x402 Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `X402_FACILITATOR_URL` | `https://x402.org` | Facilitator endpoint |
| `X402_PAYMENT_ADDRESS` | `0x0000...` | USDC recipient |
| `X402_NETWORK` | `base` | Network name |
| `X402_CHAIN_ID` | `8453` | Base mainnet |
| `PAYMENT_EXPIRY_MINUTES` | `15` | Payment validity window |

### Scan Pricing

| Variable | Default | Description |
|----------|---------|-------------|
| `SCAN_PRICE_MICRO` | `3.00` | 1–5 files |
| `SCAN_PRICE_SMALL` | `7.00` | 6–25 files |
| `SCAN_PRICE_MEDIUM` | `15.00` | 26–100 files |
| `SCAN_PRICE_LARGE` | `25.00` | 100+ files |
| `SCAN_LOC_LIMIT_MICRO` | `4000` | Max LoC for micro |
| `SCAN_LOC_LIMIT_SMALL` | `20000` | Max LoC for small |
| `SCAN_LOC_LIMIT_MEDIUM` | `75000` | Max LoC for medium |
| `SCAN_LOC_LIMIT_LARGE` | `-1` | Unlimited for large |

---

## Tier Pricing Reference

| Tier | Monthly | Annual (17% savings) | Contracts/Month |
|------|---------|----------------------|-----------------|
| Developer | $0 | $0 | 3 |
| Starter | $299 | ~$2,988/yr | 15 |
| Growth | $699 | ~$7,188/yr | 50 |
| Enterprise | $1,999+ | Custom | Unlimited |

Source of truth: `blocksecops-shared/tier-config/tiers.json`

---

## Source Files

| Component | File |
|-----------|------|
| Billing endpoints | `blocksecops-api-service/src/presentation/api/v1/endpoints/billing.py` |
| Stripe webhook | `blocksecops-api-service/src/presentation/api/v1/endpoints/stripe_webhook.py` |
| Stripe service | `blocksecops-api-service/src/application/services/stripe_service.py` |
| Payment service | `blocksecops-api-service/src/application/services/payment_service.py` |
| Pricing service | `blocksecops-api-service/src/application/services/pricing_service.py` |
| Database models | `blocksecops-api-service/src/infrastructure/database/models.py` |
| Config | `blocksecops-api-service/src/infrastructure/config.py` |
| Tier config | `blocksecops-shared/tier-config/tiers.json` |

---

## Deployment

### API Service Rebuild

After modifying subscription or billing code, bump the version and rebuild:

```bash
cd /home/pwner/Git/blocksecops-api-service

# 1. Bump version
VERSION="X.Y.Z"  # Increment per semantic versioning
sed -i "s/version = \".*\"/version = \"${VERSION}\"/" pyproject.toml

# 2. Update kustomization newTag
# k8s/overlays/local/api-service/kustomization.yaml → newTag: "${VERSION}"

# 3. Build and push to Harbor
docker build \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t harbor.blocksecops.local/blocksecops/api-service:${VERSION} .
docker push harbor.blocksecops.local/blocksecops/api-service:${VERSION}

# 4. Apply and restart
kubectl apply -k k8s/overlays/local/api-service/
kubectl rollout restart deployment/api-service -n api-service-local
kubectl rollout status deployment/api-service -n api-service-local

# 5. Commit version + kustomization together
git add pyproject.toml k8s/overlays/local/api-service/kustomization.yaml
git commit -m "chore(api-service): bump version to ${VERSION}"
```

### Database Changes

**MANDATORY:** Follow [Database Management Standards](../standards/database-management.md) before any data changes:

1. **Backup first** — dump to `docs/database/backups/` and log in `docs/database/BACKUPS.md`
2. **Create Alembic migration** — all SQL must be in codebase (codebase-first rule)
3. **Apply via Alembic** — never run raw SQL directly

```bash
# 1. Create backup BEFORE any changes
kubectl exec -n postgresql-local postgresql-0 -- \
  pg_dump -U blocksecops -d solidity_security --clean --if-exists \
  > docs/database/backups/solidity_security_pre_<change>_$(date +%Y%m%d).sql

# 2. Verify backup
ls -lh docs/database/backups/solidity_security_pre_<change>_*.sql
head -5 docs/database/backups/solidity_security_pre_<change>_*.sql

# 3. Log backup in docs/database/BACKUPS.md (use template)

# 4. Create Alembic migration
# blocksecops-api-service/alembic/versions/YYYYMMDD_HHMM-NNN_description.py

# 5. Apply migration
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security -c "SELECT version_num FROM alembic_version;"
# Then rebuild API service with new migration and restart
```

---

## Related Documentation

- [Subscription Workflow](../workflows/subscription-workflow.md) — End-to-end lifecycle
- [Stripe Dashboard Purchase Workflow](../workflows/stripe-dashboard-purchase-workflow.md) — Local testing
- [Tier Standards](../standards/tier-standards.md) — Tier definitions, quotas, pricing
- [Organization Scoping Pipeline](./organization-scoping-pipeline.md) — Org data isolation
- [Secrets Management](../standards/secrets-management.md) — Vault configuration for Stripe keys
- [Docker Image Versioning](../standards/docker-image-versioning.md) — Version bump workflow
- [Kustomize Standards](../standards/kustomize-standards.md) — Base/overlay deployment patterns
- [Database Management](../standards/database-management.md) — Backup requirements
- [Port Forwarding](../standards/port-forwarding.md) — Service access patterns (API on 8000)

---

*Last Updated: March 13, 2026*
