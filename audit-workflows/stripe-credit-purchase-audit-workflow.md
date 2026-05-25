# Stripe Credit Purchase Audit Workflow

**Version:** 1.0.0
**Last Updated:** 2026-04-24
**Status:** Active
**Purpose:** End-to-end validation that buying a credit package via Stripe (the dual-payment-options surface alongside x402) atomically credits the balance, writes a ledger entry, exposes the new balance through the API, and is idempotent under webhook replay.
**Audience:** Operator (owner) + `apogee-function-unit-regression-tester` agent
**Audit Type:** functionality (credit-purchase journey)

---

## ⚠️ Mandatory End-to-End Execution

**This workflow MUST be run from beginning to end without skipping any step, even if it was exercised recently.** Each step depends on state established by the previous one. Skipping invalidates the result. If a step fails, fix the underlying issue and re-run **from Step 1** (reset the test account first).

---

## Overview

This workflow exercises the credit purchase path for **one** credit package end-to-end. The purchase matrix audit (`stripe-purchase-matrix-playbook.md` Phase 2) re-runs this workflow once per package in `tiers.json`.

The atomic credit add is BSO-SEC-015-sensitive: the credit amount is derived **server-side from `package_id`**, never from webhook metadata.

Test mode only. Local cluster only.

---

## Prerequisites

- [ ] Cluster reachable per `docs/standards/service-availability.md`
- [ ] Stripe **test mode** keys loaded; Stripe CLI forwarding active
- [ ] DB backup created per `docs/standards/database-management.md`
- [ ] Test account `jasonbrailowbizop@mail.com` available with zero credit balance
- [ ] Selected credit package (`package_id`) read from `blocksecops-shared/tier-config/tiers.json`

---

## Standards Referenced

- `docs/standards/api-endpoint-auth.md`
- `docs/standards/secure-coding.md` (BSO-SEC-014 redirect whitelist; BSO-SEC-015 server-side credit amount)
- `docs/standards/database-management.md`
- `docs/standards/INDEX.md`

---

## Prior Audits Referenced

- `docs/audits/2026-02-25-auth-x402-audit.md`
- `docs/audit/comprehensive-audit-2026-03-15.md`
- `docs/feature-tests/52-dual-payment-options.md`

---

## Steps

### Step 1 — Select package & initiate checkout

| Aspect | Expected |
|--------|----------|
| API | POST `/payments/checkout/stripe` with `package_id` and whitelisted `success_url` / `cancel_url` | [ ] |
| HTTP | 200 with `session_url` | [ ] |
| Validation | `success_url` and `cancel_url` pass `_validate_redirect_url()` whitelist (BSO-SEC-014) | [ ] |
| DB | No premature `payment_transactions` write | [ ] |

### Step 2 — Complete checkout in Stripe test UI

| Aspect | Expected |
|--------|----------|
| User | Test card `4242 4242 4242 4242` succeeds | [ ] |
| Stripe | `checkout.session.completed` event emitted | [ ] |

### Step 3 — Webhook arrives & is verified

| Aspect | Expected |
|--------|----------|
| Webhook | POST `/api/v1/webhooks/stripe` with valid `Stripe-Signature` | [ ] |
| Handler | `stripe.Webhook.construct_event(...)` succeeds | [ ] |
| Audit log | No `STRIPE_SIGNATURE_FAILURE` entry | [ ] |

### Step 4 — Atomic credit add (RC-FIX-001)

| Aspect | Expected |
|--------|----------|
| Credit derivation | Amount derived server-side from `package_id` lookup in `tiers.json` — NOT from webhook metadata (BSO-SEC-015) | [ ] |
| DB | `payment_transactions` row inserted with `stripe_session_id`, `stripe_payment_intent_id`, `payment_type`, `amount`, `package_id` | [ ] |
| DB | Credit ledger row inserted; balance updated atomically | [ ] |
| DB | `payment_transactions.stripe_payment_intent_id` is unique (idempotency key) | [ ] |

### Step 5 — Balance exposed via API

| Aspect | Expected |
|--------|----------|
| API | GET `/payments/credits` returns new balance = previous + package amount | [ ] |
| API | GET `/payments/credits/history` includes the new ledger row | [ ] |
| UI | Dashboard credit-balance widget reflects new value within seconds | [ ] |

### Step 6 — Idempotency replay

| Aspect | Expected |
|--------|----------|
| Stripe CLI | Replay the same `checkout.session.completed` event | [ ] |
| Handler | Detects duplicate `stripe_payment_intent_id`; no-op | [ ] |
| DB | `payment_transactions` row count unchanged | [ ] |
| DB | Credit balance unchanged | [ ] |
| Audit log | Replay logged as duplicate-detected (or silently dropped per implementation) | [ ] |

### Step 7 — Use credits to verify deduction works

| Aspect | Expected |
|--------|----------|
| API | POST `/payments/credits/use` for an amount ≤ balance | [ ] |
| HTTP | 200 with new balance | [ ] |
| DB | Atomic deduction (RC-FIX-001); no race condition window | [ ] |

### Step 8 — Receipt retrieval

| Aspect | Expected |
|--------|----------|
| API | GET `/payments/{payment_id}/receipt` | [ ] |
| HTTP | 200 with PDF bytes | [ ] |
| Authz | Other user cannot fetch this receipt (404/403) | [ ] |

---

## Reset After Run

- [ ] Test account credit balance returned to zero (delete test ledger rows or restore DB backup)
- [ ] Test card / session cleaned up in Stripe test mode

---

## Failure Handling

If any step fails:
1. Stop. Do not advance.
2. Capture: HTTP response, webhook payload, DB row diff, idempotency replay outcome.
3. File the regression per `apogee-function-unit-regression-tester` agent rules.
4. If Step 4 fails server-side credit derivation (i.e., handler used metadata), this is a **security finding** — escalate to the security audit (BSO-SEC-015 regression) before retrying.
5. Reset test account and re-run from Step 1.

---

## Related Docs

- `docs/audit-playbooks/stripe-purchase-matrix-playbook.md` (Phase 2)
- `docs/audit-playbooks/stripe-functionality-audit-playbook.md`
- `docs/audit-playbooks/stripe-security-audit-playbook.md` (Phase 3 metadata whitelist)
- `docs/audit-pipelines/stripe-functionality-audit-pipeline.md`
- `docs/feature-tests/52-dual-payment-options.md`
- `docs/pricing/x402-credits.md`
- `docs/.claude/agents/apogee-function-unit-regression-tester.md`
