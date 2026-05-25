# Stripe Referral Coupon Audit Workflow

**Version:** 1.0.0
**Last Updated:** 2026-04-24
**Status:** Active
**Purpose:** End-to-end validation that the referral system correctly issues a Stripe coupon, applies it on the recipient's first paid checkout, writes the `ReferralRewardModel` row, credits the referrer, and is idempotent under webhook replay and second-use attempts.
**Audience:** Operator (owner) + `apogee-function-unit-regression-tester` agent (with `tier-agent` consult on tier-gating)
**Audit Type:** functionality (referral journey)

---

## ⚠️ Mandatory End-to-End Execution

**This workflow MUST be run from beginning to end without skipping any step, even if it was exercised recently.** Each step depends on state established by the previous one. Skipping invalidates the result. If a step fails, fix the underlying issue and re-run **from Step 1**.

---

## Overview

This workflow exercises the referral system's Stripe surface (Stripe coupon objects applied via `ReferralRewardModel`). It is invoked by `stripe-purchase-matrix-playbook.md` Phase 3.

Test mode only. Local cluster only. Two test users required: one referrer (`jasonbrailowbizop@mail.com`) and one recipient (a second test account in the same test environment).

---

## Prerequisites

- [ ] Cluster reachable per `docs/standards/service-availability.md`
- [ ] Stripe **test mode** keys loaded; Stripe CLI forwarding active
- [ ] DB backup created per `docs/standards/database-management.md`
- [ ] Referrer test account exists with referral system enabled per their tier
- [ ] Recipient test account exists with no prior referral relationship
- [ ] Referral system policy reviewed: `docs/workflows/referral-system-workflow.md`, `docs/playbooks/referral-system.md`, `docs/pipelines/referral-system-pipeline.md`

---

## Standards Referenced

- `docs/standards/api-endpoint-auth.md`
- `docs/standards/secure-coding.md`
- `docs/standards/tier-standards.md`
- `docs/standards/database-management.md`
- `docs/standards/INDEX.md`

---

## Prior Audits Referenced

- `docs/audits/2026-02-24-org-team-subscription-audit.md`
- `docs/audits/2026-03-13-tier-v4-audit.md`
- `docs/audit/comprehensive-audit-2026-03-15.md`

---

## Steps

### Step 1 — Issue referral code

| Aspect | Expected |
|--------|----------|
| API | Referrer issues a referral code via the documented referral endpoint | [ ] |
| HTTP | 200 with referral code | [ ] |
| DB | Referral row created (precursor to `ReferralRewardModel`) | [ ] |
| Tier check | Referral feature available at referrer's tier (per `tier-agent`) | [ ] |

### Step 2 — Recipient signs up with referral code

| Aspect | Expected |
|--------|----------|
| API | Recipient signs up with the code attached (form field or query param per docs) | [ ] |
| HTTP | 200; user created | [ ] |
| DB | Code recorded against the recipient's user row | [ ] |

### Step 3 — Recipient performs first paid checkout

| Aspect | Expected |
|--------|----------|
| API | Recipient calls POST `/billing/checkout` (any subscription price ID from Phase 1 of purchase matrix) | [ ] |
| HTTP | 200 with `checkout_session_url` | [ ] |
| Stripe | Coupon attached to the session (verifiable in Stripe test dashboard) | [ ] |
| User | Completes checkout in Stripe test UI; discount visible | [ ] |

### Step 4 — `checkout.session.completed` arrives

| Aspect | Expected |
|--------|----------|
| Webhook | Signature verified | [ ] |
| Handler | Detects coupon use; creates `ReferralRewardModel` row | [ ] |
| DB | `ReferralRewardModel` row references the Stripe coupon ID and the recipient's session | [ ] |
| Audit log | Referral-reward-applied entry | [ ] |

### Step 5 — Referrer reward applied

| Aspect | Expected |
|--------|----------|
| Reward | Referrer's reward credited per documented policy (e.g., credits, discount, payout) | [ ] |
| API | GET `/payments/credits` (or equivalent) reflects the reward | [ ] |
| DB | Reward ledger entry exists; matches policy in `docs/workflows/referral-system-workflow.md` | [ ] |

### Step 6 — Idempotency replay

| Aspect | Expected |
|--------|----------|
| Stripe CLI | Replay the `checkout.session.completed` event | [ ] |
| Handler | No duplicate `ReferralRewardModel` row created | [ ] |
| DB | Reward ledger unchanged | [ ] |

### Step 7 — Coupon misuse prevention

| Aspect | Expected |
|--------|----------|
| Recipient B | Different new user attempts to apply the same code | [ ] |
| Stripe | Coupon `max_redemptions` (or equivalent guard) prevents reuse | [ ] |
| API | Checkout fails or proceeds without discount per documented policy | [ ] |
| DB | No additional `ReferralRewardModel` row created | [ ] |

### Step 8 — Referrer can issue more codes (within tier limits)

| Aspect | Expected |
|--------|----------|
| API | Referrer issues a second code (within their tier's limit) | [ ] |
| Tier check | Tier-limited; over-limit attempts return 402/403 with explanation | [ ] |

---

## Reset After Run

- [ ] Recipient test account cancelled / cleaned up
- [ ] Stripe coupons deleted from test mode
- [ ] Referral DB rows cleaned (or restore from backup) for next audit run

---

## Failure Handling

If any step fails:
1. Stop. Do not advance.
2. Capture: HTTP response, webhook payload, coupon ID, DB diffs.
3. Coupon-reuse failures (Step 7) escalate to the security audit (potential abuse vector).
4. File regressions per agent rules.
5. Re-run from Step 1.

---

## Related Docs

- `docs/audit-playbooks/stripe-purchase-matrix-playbook.md` (Phase 3)
- `docs/audit-playbooks/stripe-functionality-audit-playbook.md`
- `docs/audit-pipelines/stripe-functionality-audit-pipeline.md`
- `docs/workflows/referral-system-workflow.md`
- `docs/pipelines/referral-system-pipeline.md`
- `docs/playbooks/referral-system.md`
- `docs/.claude/agents/apogee-function-unit-regression-tester.md`
- `docs/.claude/agents/tier-agent.md`
