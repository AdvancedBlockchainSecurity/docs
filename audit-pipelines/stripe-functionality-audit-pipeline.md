# Stripe Functionality Audit Pipeline

**Version:** 1.0.0
**Last Updated:** 2026-04-24
**Status:** Active
**Purpose:** Sequenced technical/automation steps that the functionality audit playbook orchestrates — exact API call sequences for each lifecycle transition with expected HTTP responses, DB state queries (read-only), and webhook payloads.
**Audience:** `apogee-function-unit-regression-tester` agent + operator
**Audit Type:** functionality (technical sequence)

---

## ⚠️ Mandatory End-to-End Execution

**This pipeline MUST be executed from beginning to end without skipping any step, even if it was run recently.** Each step's output (e.g., a created subscription ID) feeds the next step. Skipping invalidates results. If a step fails, fix the underlying issue and re-run **from Phase 1** of `docs/audit-playbooks/stripe-functionality-audit-playbook.md`.

---

## Overview

This pipeline is the technical companion to `docs/audit-playbooks/stripe-functionality-audit-playbook.md`. The playbook describes *what* and *why*; this pipeline describes *how* — exact `curl` commands, expected JSON response structure, and read-only `psql` queries to verify DB state.

Local cluster only (per `feedback_local_not_gcp.md`). Stripe **test mode** keys. Test account `jasonbrailowbizop@mail.com`.

Replace `<ingress-host>`, `<api-namespace>`, `<pg-host>`, `<bearer-token>`, and price-ID variables before execution.

---

## Prerequisites

See `docs/audit-playbooks/stripe-functionality-audit-playbook.md` Prerequisites. Plus:

- [ ] `stripe-cli` authenticated to test mode
- [ ] `psql` access to `solidity_security` DB
- [ ] Bearer token for the test account (session-only)
- [ ] DB backup created per `database-management.md`

---

## Standards Referenced

- `docs/standards/api-endpoint-auth.md`
- `docs/standards/database-management.md`
- `docs/standards/tier-standards.md`
- `docs/standards/INDEX.md`

---

## Prior Audits Referenced

- `docs/audits/2026-02-24-org-team-subscription-audit.md`
- `docs/audits/2026-03-13-tier-v4-audit.md`
- `docs/audit/comprehensive-audit-2026-03-15.md`

---

## Phase 1 — Checkout Session Creation

```bash
# 1.1.1 Starter monthly
curl -s -X POST "https://<ingress-host>/api/v1/billing/checkout" \
  -H "Authorization: Bearer $BEARER" \
  -H "Content-Type: application/json" \
  --data "{\"price_id\":\"$STRIPE_PRICE_STARTER_MONTHLY\",\"success_url\":\"https://<ingress-host>/billing/success\",\"cancel_url\":\"https://<ingress-host>/billing/cancel\"}" \
  | jq .
# Expected: {"checkout_session_url":"https://checkout.stripe.com/..."}; 200

# 1.1.4 Invalid price ID
curl -s -o /dev/null -w "%{http_code}\n" -X POST "https://<ingress-host>/api/v1/billing/checkout" \
  -H "Authorization: Bearer $BEARER" \
  -H "Content-Type: application/json" \
  --data '{"price_id":"price_does_not_exist"}'
# Expected: 400 or 422

# 1.1.5 While already subscribed
# (after Phase 2+ creates a subscription, retry checkout and expect 409)
```

**Capture:** Response bodies, response status codes.

---

## Phase 2 — Tier Change Preview & Proration

```bash
# 2.1.1 Upgrade preview
curl -s "https://<ingress-host>/api/v1/billing/subscription/change-tier/preview?tier=growth&interval=monthly" \
  -H "Authorization: Bearer $BEARER" | jq .
# Expected: {prorated_amount, current_tier, new_tier, period_end, ...}

# 2.1.3 Downgrade preview (no immediate charge)
curl -s "https://<ingress-host>/api/v1/billing/subscription/change-tier/preview?tier=starter&interval=monthly" \
  -H "Authorization: Bearer $BEARER" | jq .
# Expected: scheduled_change_at = period_end; immediate_charge = 0 or credit

# 2.1.4 Same-tier no-op
curl -s -o /dev/null -w "%{http_code}\n" \
  "https://<ingress-host>/api/v1/billing/subscription/change-tier/preview?tier=growth&interval=monthly" \
  -H "Authorization: Bearer $BEARER"
# Expected: 400 or no-op response (per documented policy)
```

**Capture:** Preview JSON; spot-check prorated_amount against Stripe upcoming-invoice.

---

## Phase 3 — Upgrade

```bash
# 3.1.1 Apply upgrade
curl -s -X POST "https://<ingress-host>/api/v1/billing/subscription/change-tier" \
  -H "Authorization: Bearer $BEARER" \
  -H "Content-Type: application/json" \
  --data '{"tier":"growth","interval":"monthly"}' | jq .
# Expected: 200; updated subscription returned

# 3.1.2 Verify webhook + DB
sleep 3
psql "postgresql://blocksecops@<pg-host>/solidity_security?sslmode=prefer" -c "
  SELECT tier, billing_interval, status, updated_at
  FROM subscriptions
  WHERE user_id = '<test-user-uuid>';
"
# Expected: tier='growth'; updated_at recent

# 3.1.3 Plan limit
curl -s "https://<ingress-host>/api/v1/billing/plan-limit" \
  -H "Authorization: Bearer $BEARER" | jq .
# Expected: {contracts_per_month: 75, ...} (Growth quota)
```

---

## Phase 4 — Downgrade (deferred)

```bash
# 4.1.1 Schedule downgrade
curl -s -X POST "https://<ingress-host>/api/v1/billing/subscription/change-tier" \
  -H "Authorization: Bearer $BEARER" \
  -H "Content-Type: application/json" \
  --data '{"tier":"starter","interval":"monthly"}' | jq .
# Expected: 200; schedule object indicates change at period_end

# 4.1.2 Tier remains Growth until period end
psql "..." -c "SELECT tier FROM subscriptions WHERE user_id='<...>';"
# Expected: tier='growth' (NOT 'starter' yet)

# 4.1.4 Cross period boundary via Stripe test clock
TEST_CLOCK=$(stripe test_clocks list --limit 1 -q | jq -r '.data[0].id')
PERIOD_END=$(stripe subscriptions retrieve <sub-id> | jq -r '.current_period_end')
stripe test_helpers test_clocks advance --frozen-time $((PERIOD_END + 60)) "$TEST_CLOCK"
sleep 5
# Expect customer.subscription.updated webhook → tier='starter' in DB
```

---

## Phase 5 — Cancel at Period End

```bash
# 5.1.1
curl -s -X POST "https://<ingress-host>/api/v1/billing/subscription/cancel?at_period_end=true" \
  -H "Authorization: Bearer $BEARER" | jq .
# Expected: 200; cancel_at_period_end=true

# 5.1.2 DB
psql "..." -c "SELECT cancellation_scheduled_for FROM subscriptions WHERE user_id='<...>';"
# Expected: timestamp = current_period_end
```

---

## Phase 6 — Reactivate

```bash
curl -s -X POST "https://<ingress-host>/api/v1/billing/subscription/reactivate" \
  -H "Authorization: Bearer $BEARER" | jq .
# Expected: 200

psql "..." -c "SELECT cancellation_scheduled_for FROM subscriptions WHERE user_id='<...>';"
# Expected: NULL
```

---

## Phase 7 — Cancel Immediately

```bash
# 7.1.1 Self-service immediate cancel (typically 403 unless admin path used)
curl -s -o /dev/null -w "%{http_code}\n" -X POST \
  "https://<ingress-host>/api/v1/billing/subscription/cancel?at_period_end=false" \
  -H "Authorization: Bearer $BEARER"
# Expected: per documented policy (200 admin, 403 self-service)

# 7.1.3 If executed (admin path), verify
psql "..." -c "SELECT status, tier FROM subscriptions WHERE user_id='<...>';"
# Expected: status='canceled', tier reverts to developer in user-tier mapping
```

---

## Phase 8 — Annual vs Monthly Math

```bash
# 8.1.1 Starter annual price object check
stripe prices retrieve "$STRIPE_PRICE_STARTER_ANNUAL" | jq '{id, unit_amount, recurring}'
# Expected: unit_amount = 202800 (cents) → $2,028

# 8.1.2 Growth annual
stripe prices retrieve "$STRIPE_PRICE_GROWTH_ANNUAL" | jq '{id, unit_amount, recurring}'
# Expected: unit_amount = 502800 → $5,028

# 8.1.3 Three-way match
echo "tiers.json:"
jq '.tiers[] | select(.id=="starter") | .pricing' /home/pwner/Git/blocksecops-shared/tier-config/tiers.json
echo "/billing/plans:"
curl -s "https://<ingress-host>/api/v1/billing/plans" | jq .
echo "Stripe (above)"
# Expected: same numbers across all three sources
```

---

## Phase 9 — Tax

```bash
# 9.1.1 US (CA) test customer
stripe customers create --email tax-us-test@example.com --address[country]=US --address[state]=CA --address[postal_code]=94103
# Then trigger checkout for that customer; inspect upcoming invoice for tax line

# 9.1.2 EU customer with VAT ID
stripe customers create --email tax-eu-test@example.com --address[country]=DE --tax_id_data[0][type]=eu_vat --tax_id_data[0][value]=DE123456789

# 9.1.4 Confirm config flag honored
grep -n "stripe_tax_enabled" /home/pwner/Git/blocksecops-api-service/src/infrastructure/config.py
```

---

## Phase 10 — Invoices

```bash
# 10.1.1 List
curl -s "https://<ingress-host>/api/v1/billing/invoices" \
  -H "Authorization: Bearer $BEARER" | jq '.[:5]'

# 10.1.2 PDF
INV_ID=$(curl -s "https://<ingress-host>/api/v1/billing/invoices" -H "Authorization: Bearer $BEARER" | jq -r '.[0].id')
curl -s -o /tmp/invoice.pdf -w "%{content_type}\n" \
  "https://<ingress-host>/api/v1/billing/invoices/$INV_ID/pdf" \
  -H "Authorization: Bearer $BEARER"
# Expected: application/pdf

# 10.1.3 Cross-user denial
curl -s -o /dev/null -w "%{http_code}\n" \
  "https://<ingress-host>/api/v1/billing/invoices/$INV_ID/pdf" \
  -H "Authorization: Bearer $OTHER_BEARER"
# Expected: 404 or 403

# 10.1.4 Combined history
curl -s "https://<ingress-host>/api/v1/billing/history" -H "Authorization: Bearer $BEARER" | jq .
```

---

## Phase 11 — Plan-limit Enforcement

```bash
# 11.1.1-3 Per tier
for TIER in developer starter growth; do
  echo "--- $TIER ---"
  # (Switch test account to $TIER via admin or fresh test user)
  curl -s "https://<ingress-host>/api/v1/billing/plan-limit" -H "Authorization: Bearer $BEARER" | jq .
done
# Expected: developer=3, starter=25, growth=75 (per tiers.json)

# 11.1.4 Quota exhaustion (after submitting N scans)
curl -s -o /dev/null -w "%{http_code}\n" -X POST \
  "https://<ingress-host>/api/v1/scans" \
  -H "Authorization: Bearer $BEARER" \
  -H "Content-Type: application/json" \
  --data '{"contract_address":"0xtest"}'
# Expected after exhausting quota: 402 with quota-error message
```

---

## Output

Pipeline does not produce its own report. Evidence captured here is consumed by `stripe-functionality-audit-playbook.md` and embedded in `docs/audit/YYYY-MM-DD-stripe-functionality-test-results.md`.

---

## Failure Handling

If any step returns unexpected output:
1. Stop the pipeline.
2. Record the unexpected output as a regression with file:line and offending commit/image tag.
3. Route to `stripe-functionality-audit-playbook.md` Failure Handling.

---

## Related Docs

- `docs/audit-playbooks/stripe-functionality-audit-playbook.md`
- `docs/audit-workflows/stripe-subscription-lifecycle-audit-workflow.md`
- `docs/audit-workflows/stripe-billing-portal-audit-workflow.md`
- `docs/audit-workflows/stripe-webhook-event-audit-workflow.md`
- `docs/.claude/agents/apogee-function-unit-regression-tester.md`
- `docs/pipelines/billing-feature-pipeline.md`
- `docs/pipelines/subscription-pipeline.md`
