# Stripe Purchase Matrix Audit Playbook

**Version:** 1.0.0
**Last Updated:** 2026-04-24
**Status:** Active
**Purpose:** Reusable, end-to-end exercise of every purchasable Stripe product, service, and coupon in Apogee — six subscription price IDs, every credit package in `tiers.json`, and the referral coupon application path.
**Audience:** Operator (owner) — drives test-mode purchases against the test account
**Audit Type:** purchase

---

## ⚠️ Mandatory End-to-End Execution

**This audit MUST be run from beginning to end without skipping any product, even if it was exercised recently.** Each row in the matrix below is an independent purchasable surface; skipping any row leaves a coverage gap. If a row fails, fix the underlying issue and re-run **the entire matrix from row 1** — do not patch and resume mid-matrix.

When the owner says "run the Stripe purchase matrix audit," every row below runs.

---

## Overview

This playbook walks every purchasable surface in Apogee against the test account `jasonbrailowbizop@mail.com` in Stripe **test mode**. The matrix is generated from authoritative sources:

- Subscription price IDs: `blocksecops-shared/tier-config/tiers.json` and `blocksecops-api-service/src/infrastructure/config.py`
- Credit packages: `blocksecops-shared/tier-config/tiers.json` credit packages section
- Referral coupons: `ReferralRewardModel` and `docs/workflows/referral-system-workflow.md`

Per the standing authorization (memory `feedback_trigger_scans_via_api.md`), the operator may call the Apogee API directly with the test account credentials; the password is session-only and never persisted.

---

## Prerequisites

- [ ] Cluster reachable via ingress per `docs/standards/service-availability.md`
- [ ] Stripe **test mode** keys loaded; live keys NOT in use
- [ ] DB backup created per `docs/standards/database-management.md` (matrix writes test data)
- [ ] Owner approval to invoke `apogee-function-unit-regression-tester` and to drive purchases (Rule 0)
- [ ] Test account `jasonbrailowbizop@mail.com` available; password loaded in session env only
- [ ] Test account starts in known state (Developer tier, no active subscription, zero credits)
- [ ] Stripe CLI installed for local webhook forwarding (per Phase 0 setup; no `kubectl port-forward` per `feedback_no_port_forward.md`)
- [ ] `tier-agent` consulted for tier-gating expectations (per `docs/.claude/agents/tier-agent.md`)

---

## Standards Referenced

- `docs/standards/api-endpoint-auth.md`
- `docs/standards/tier-standards.md`
- `docs/standards/database-management.md`
- `docs/standards/secure-coding.md` (BSO-SEC-014, BSO-SEC-015 — server-side credit amounts, redirect whitelist)
- `docs/standards/INDEX.md`

---

## Prior Audits Referenced

- `docs/audits/2026-02-25-auth-x402-audit.md`
- `docs/audits/2026-02-24-org-team-subscription-audit.md`
- `docs/audits/2026-03-13-tier-v4-audit.md`
- `docs/audit/comprehensive-audit-2026-03-15.md`
- `docs/audits/AUTHENTICATED-TEST-PLAN.md`

---

## Agent Invocation

Invoke `apogee-function-unit-regression-tester` (Sonnet 4.6 default) with the matrix below. Consult `tier-agent` for the expected tier features per row. Output goes to `docs/audit/YYYY-MM-DD-stripe-purchase-matrix-results.md`.

---

## Phase 0: Matrix Pre-flight

### 0.1 Refresh matrix from sources of truth

| # | Test | Expected | Status |
|---|------|----------|--------|
| 0.1.1 | Read price IDs from `tiers.json` and confirm match with `config.py` | Three-way match: `tiers.json` ↔ `config.py` ↔ Stripe dashboard | [ ] |
| 0.1.2 | Read credit packages from `tiers.json` | Each package has Stripe price ID; counts match Stripe dashboard | [ ] |
| 0.1.3 | Stripe CLI forwarding active to local API ingress | `stripe listen` connected; events routed | [ ] |
| 0.1.4 | Test account in clean state (Developer, no sub, zero credits) | DB confirms | [ ] |

If 0.1.1 or 0.1.2 fail, this is a **drift finding** — stop and route to the documentation audit.

---

## Phase 1: Subscription Matrix (6 rows)

For each row: log in → POST `/billing/checkout` → complete checkout in Stripe test mode → wait for webhook → verify DB state → verify `/billing/plan-limit` → reset (cancel + return to Developer) before next row.

| # | Tier | Interval | Price ID source | Expected webhook | Expected DB state | Status |
|---|------|----------|-----------------|------------------|-------------------|--------|
| 1.1 | Starter | monthly | `STRIPE_PRICE_STARTER_MONTHLY` | `checkout.session.completed`, `customer.subscription.updated` | `subscriptions.tier='starter'`, `billing_interval='monthly'`, `status='active'` | [ ] |
| 1.2 | Starter | annual | `STRIPE_PRICE_STARTER_ANNUAL` | same | `billing_interval='annual'`, amount = $2,028 | [ ] |
| 1.3 | Growth | monthly | `STRIPE_PRICE_GROWTH_MONTHLY` | same | `tier='growth'` | [ ] |
| 1.4 | Growth | annual | `STRIPE_PRICE_GROWTH_ANNUAL` | same | amount = $5,028 | [ ] |
| 1.5 | Enterprise | monthly | `STRIPE_PRICE_ENTERPRISE_MONTHLY` | same (or documented custom flow) | `tier='enterprise'` | [ ] |
| 1.6 | Enterprise | annual | `STRIPE_PRICE_ENTERPRISE_ANNUAL` | same | annual amount per `tiers.json` | [ ] |

**Evidence to capture per row:** Checkout session ID, webhook payload, DB row diff, plan-limit response, dashboard UI screenshot.

**Reset between rows:** POST `/billing/subscription/cancel?at_period_end=false` (admin path) OR fast-forward via Stripe test clock.

---

## Phase 2: Credit Package Matrix

For each credit package in `tiers.json`: POST `/payments/checkout/stripe` → complete checkout → verify atomic credit add (RC-FIX-001) → verify ledger entry → verify balance via `/payments/credits` → replay webhook to verify idempotency.

| # | Package | Stripe price ID | Expected credits added | Expected webhook | Status |
|---|---------|-----------------|------------------------|------------------|--------|
| 2.1 | <package 1 from tiers.json> | <price ID> | <amount> (server-side per BSO-SEC-015) | `checkout.session.completed` | [ ] |
| 2.2 | <package 2> | ... | ... | ... | [ ] |
| 2.N | <…enumerate every package…> | ... | ... | ... | [ ] |

**Special checks per row:**
- Credit amount is derived server-side from `package_id`, never from webhook metadata (BSO-SEC-015).
- Replay of `checkout.session.completed` does NOT double-credit (idempotency via `payment_transactions.stripe_payment_intent_id` uniqueness).
- `payment_transactions` row created with correct `payment_type`, `amount`, `stripe_session_id`.

**Evidence to capture:** Pre/post credit balance, ledger row, idempotency replay outcome.

---

## Phase 3: Referral Coupon Matrix

For the referral system end-to-end:

| # | Test | Expected | Status |
|---|------|----------|--------|
| 3.1 | Issue a referral code from referrer account | Code persisted; `ReferralRewardModel` precursor created | [ ] |
| 3.2 | Recipient signs up with referral code | Code recorded against recipient | [ ] |
| 3.3 | Recipient performs first paid checkout (any subscription row from Phase 1) | Stripe coupon applied; discount visible in checkout | [ ] |
| 3.4 | `checkout.session.completed` fires | `ReferralRewardModel` row written; coupon ID recorded | [ ] |
| 3.5 | Referrer sees reward credited (per `docs/workflows/referral-system-workflow.md` rules) | Reward applied per documented policy | [ ] |
| 3.6 | Replay of completion event does NOT issue duplicate reward | Idempotency holds | [ ] |
| 3.7 | Coupon cannot be reused by a second new user (per coupon `max_redemptions` policy) | Stripe rejects second use | [ ] |

**Evidence to capture:** Coupon ID, `ReferralRewardModel` row, referrer balance/reward delta, idempotency replay outcome.

---

## Phase 4: Negative Cases (per row)

For at least one row from Phase 1 and one row from Phase 2, exercise:

| # | Test | Expected | Status |
|---|------|----------|--------|
| 4.1 | Checkout aborted by user | No subscription/credit added; no orphan rows | [ ] |
| 4.2 | Payment method declined (Stripe test card `4000000000000002`) | Checkout fails cleanly; user sees error; no DB write | [ ] |
| 4.3 | Webhook delivery delayed (Stripe CLI artificially delayed) | System eventually consistent; no double-processing | [ ] |
| 4.4 | Webhook replayed after long delay | Idempotency holds | [ ] |
| 4.5 | Checkout with `success_url` outside whitelist (BSO-SEC-014) | Rejected before checkout session created | [ ] |

---

## Audit Report Template

Copy this into `docs/audit/YYYY-MM-DD-stripe-purchase-matrix-results.md`.

```markdown
# Stripe Purchase Matrix Audit — YYYY-MM-DD

**Author:** apogee-function-unit-regression-tester (with tier-agent consult)
**Scope:** Every purchasable Stripe product/SKU/coupon in Apogee, exercised in test mode against jasonbrailowbizop@mail.com.
**Standards referenced:** see Standards Referenced section of `docs/audit-playbooks/stripe-purchase-matrix-playbook.md`

## Executive Summary
<2–4 sentences>

## Matrix Coverage
- Subscriptions exercised: X / 6
- Credit packages exercised: X / N (N from `tiers.json`)
- Referral coupon path: Pass/Fail
- Negative cases: X / 5

## Phase-by-phase Results
| Phase | Outcome | Notable |
|-------|---------|---------|
| 0 Pre-flight | Pass/Fail | |
| 1 Subscription matrix | Pass/Fail | |
| 2 Credit package matrix | Pass/Fail | |
| 3 Referral coupon | Pass/Fail | |
| 4 Negative cases | Pass/Fail | |

## Per-row Results
| Row | Status | Evidence |
|-----|--------|----------|
| 1.1 Starter monthly | Pass/Fail | <link> |
| 1.2 Starter annual | Pass/Fail | <link> |
| ... | ... | ... |

## Drift Items
- <e.g., a credit package in `tiers.json` lacks a corresponding Stripe price object>

## Follow-ups
- [ ] <actionable item tied to owner>
```

---

## Failure Handling

If any row fails:
1. Stop. Do not advance.
2. File the failure with the row reference, expected vs actual, and webhook payload.
3. Fix the root cause; do not skip the row.
4. Re-run the **entire matrix from row 1** (Phase 0 included).

If pre-flight (Phase 0) detects drift between `tiers.json`, `config.py`, and Stripe dashboard, route to the documentation audit before proceeding.

---

## Related Docs

- `docs/audit-playbooks/stripe-full-audit-playbook.md` — orchestrator
- `docs/audit-workflows/stripe-subscription-lifecycle-audit-workflow.md`
- `docs/audit-workflows/stripe-credit-purchase-audit-workflow.md`
- `docs/audit-workflows/stripe-referral-coupon-audit-workflow.md`
- `docs/audit-workflows/stripe-webhook-event-audit-workflow.md`
- `docs/.claude/agents/apogee-function-unit-regression-tester.md`
- `docs/.claude/agents/tier-agent.md`
- `docs/workflows/tier-purchasing-workflow.md`
- `docs/workflows/referral-system-workflow.md`
- `docs/playbooks/stripe-test-subscriptions.md`
- `docs/pricing/pricing-tiers.md`
- `docs/pricing/x402-credits.md`
