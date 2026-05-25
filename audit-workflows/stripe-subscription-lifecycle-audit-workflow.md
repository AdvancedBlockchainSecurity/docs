# Stripe Subscription Lifecycle Audit Workflow

**Version:** 1.0.0
**Last Updated:** 2026-04-24
**Status:** Active
**Purpose:** End-to-end validation that the full subscription lifecycle (Free → Starter → upgrade to Growth → downgrade to Starter → cancel at period end → reactivate → cancel immediately) produces the expected API responses, webhook events, DB writes, dashboard UI state, and audit-log entries.
**Audience:** Operator (owner) + `apogee-function-unit-regression-tester` agent
**Audit Type:** functionality (lifecycle journey)

---

## ⚠️ Mandatory End-to-End Execution

**This workflow MUST be run from beginning to end without skipping any transition, even if it was exercised recently.** Each transition mutates state the next transition depends on. Skipping invalidates the result. If a transition fails, fix the underlying issue and re-run **from Step 1** (reset the test account first).

---

## Overview

This workflow is the canonical lifecycle journey exercised by `docs/audit-playbooks/stripe-functionality-audit-playbook.md` (Phases 3–7) and `docs/audit-playbooks/stripe-purchase-matrix-playbook.md` (Phase 1 reset cycles). It is also re-used by the test-coverage audit as the reference scenario for regression tests in `tests/regression/test_stripe_webhook_regression.py`.

Test mode only. Local cluster only (per `feedback_local_not_gcp.md`). Test account `jasonbrailowbizop@mail.com`.

---

## Prerequisites

- [ ] Cluster reachable per `docs/standards/service-availability.md`
- [ ] Stripe **test mode** keys loaded; Stripe CLI forwarding active to local API ingress
- [ ] DB backup created per `docs/standards/database-management.md`
- [ ] Test account starts in clean state (Developer tier, no active subscription, zero credits)
- [ ] Stripe test clock created (optional but recommended for period-boundary steps)

---

## Standards Referenced

- `docs/standards/api-endpoint-auth.md`
- `docs/standards/tier-standards.md`
- `docs/standards/database-management.md`
- `docs/standards/INDEX.md`

---

## Prior Audits Referenced

- `docs/audits/2026-02-24-org-team-subscription-audit.md`
- `docs/audits/2026-03-13-tier-v4-audit.md`
- `docs/audit/comprehensive-audit-2026-03-15.md`

---

## Lifecycle Steps

For every step the audit captures: **API call**, **expected HTTP response**, **expected webhook event**, **expected DB write** (which table / which row), **expected dashboard UI state**, **expected audit-log entry**.

### Step 1 — Free (baseline)

| Aspect | Expected |
|--------|----------|
| API | GET `/billing/subscription` returns null/empty | [ ] |
| HTTP | 200 with empty body or `{tier: "developer"}` | [ ] |
| Webhook | none | [ ] |
| DB | `subscriptions` table has no row for this user | [ ] |
| UI | Dashboard shows "Developer (free)" | [ ] |
| Audit log | none | [ ] |

### Step 2 — Subscribe to Starter (monthly)

| Aspect | Expected |
|--------|----------|
| API | POST `/billing/checkout` with Starter monthly price ID; complete checkout in Stripe test UI | [ ] |
| HTTP | 200 with `checkout_session_url`; redirect completes | [ ] |
| Webhook | `checkout.session.completed`, `customer.subscription.created`, `invoice.payment_succeeded` | [ ] |
| DB | `subscriptions` row created: `tier='starter'`, `billing_interval='monthly'`, `status='active'`, `stripe_subscription_id` set | [ ] |
| DB | `payment_transactions` row created with `stripe_payment_intent_id` | [ ] |
| UI | Dashboard shows "Starter" + new plan limits | [ ] |
| Audit log | Subscription created entry | [ ] |

### Step 3 — Upgrade to Growth (immediate proration)

| Aspect | Expected |
|--------|----------|
| API | GET `/billing/subscription/change-tier/preview?tier=growth&interval=monthly` returns prorated amount | [ ] |
| API | POST `/billing/subscription/change-tier` (target growth/monthly) | [ ] |
| HTTP | 200; immediate proration charge created | [ ] |
| Webhook | `customer.subscription.updated`, `invoice.payment_succeeded` (proration invoice) | [ ] |
| DB | `subscriptions.tier='growth'`; `subscriptions.updated_at` advances | [ ] |
| UI | Dashboard immediately shows Growth limits | [ ] |
| Audit log | Tier-change entry | [ ] |

### Step 4 — Downgrade to Starter (deferred to period end)

| Aspect | Expected |
|--------|----------|
| API | POST `/billing/subscription/change-tier` (target starter/monthly) | [ ] |
| HTTP | 200; subscription schedule created OR proration_behavior set to defer | [ ] |
| Webhook | `customer.subscription.updated` (schedule recorded) | [ ] |
| DB | `subscriptions.tier` remains `'growth'` until period boundary | [ ] |
| UI | Dashboard shows "Growth (downgrades to Starter on YYYY-MM-DD)" | [ ] |
| Audit log | Schedule-created entry | [ ] |

### Step 5 — Cross period boundary (downgrade fires)

| Aspect | Expected |
|--------|----------|
| API (out-of-band) | Stripe test clock advanced past `current_period_end` | [ ] |
| Webhook | `customer.subscription.updated` (tier changed), `invoice.payment_succeeded` (next period) | [ ] |
| DB | `subscriptions.tier='starter'` | [ ] |
| UI | Dashboard reverts to Starter limits | [ ] |
| Audit log | Tier-change applied entry | [ ] |

### Step 6 — Cancel at period end

| Aspect | Expected |
|--------|----------|
| API | POST `/billing/subscription/cancel?at_period_end=true` | [ ] |
| HTTP | 200; Stripe `cancel_at_period_end=true` | [ ] |
| Webhook | `customer.subscription.updated` | [ ] |
| DB | `subscriptions.cancellation_scheduled_for` set to `current_period_end` | [ ] |
| UI | Dashboard shows "Cancels on YYYY-MM-DD" | [ ] |
| Audit log | Cancellation-scheduled entry | [ ] |

### Step 7 — Reactivate before period end

| Aspect | Expected |
|--------|----------|
| API | POST `/billing/subscription/reactivate` | [ ] |
| HTTP | 200 | [ ] |
| Webhook | `customer.subscription.updated` | [ ] |
| DB | `subscriptions.cancellation_scheduled_for=NULL` | [ ] |
| UI | Dashboard removes the cancellation banner | [ ] |
| Audit log | Reactivation entry | [ ] |

### Step 8 — Cancel immediately (admin/special path)

| Aspect | Expected |
|--------|----------|
| API | POST `/billing/subscription/cancel?at_period_end=false` (admin or documented path) | [ ] |
| HTTP | 200 (admin) or 403 (self-service blocked) — match documented policy | [ ] |
| Webhook | `customer.subscription.deleted` | [ ] |
| DB | `subscriptions.status='canceled'`; user reverted to Developer | [ ] |
| UI | Dashboard reverts to Developer immediately | [ ] |
| Audit log | Hard-cancel entry | [ ] |

---

## Reset After Run

- [ ] Stripe test clock deleted (if used)
- [ ] Test account back to clean state (Developer, no sub, zero credits) for next audit run

---

## Failure Handling

If any step fails:
1. Stop. Do not advance.
2. Capture: HTTP response, webhook payload, DB row diff, dashboard screenshot, audit-log row.
3. File the regression to `TaskDocs-BlockSecOps/` per `apogee-function-unit-regression-tester` agent rules.
4. Fix the root cause; do not skip the step.
5. Reset the test account and re-run the workflow **from Step 1**.

---

## Related Docs

- `docs/audit-playbooks/stripe-functionality-audit-playbook.md` (Phases 3–7)
- `docs/audit-playbooks/stripe-purchase-matrix-playbook.md` (Phase 1 reset cycles)
- `docs/audit-pipelines/stripe-functionality-audit-pipeline.md` — exact commands
- `docs/audit-workflows/stripe-webhook-event-audit-workflow.md` — webhook delivery details
- `docs/workflows/billing-subscription-workflow.md`
- `docs/workflows/subscription-workflow.md`
- `docs/workflows/tier-upgrading-workflow.md`
- `docs/playbooks/stripe-test-subscriptions.md`
- `docs/.claude/agents/apogee-function-unit-regression-tester.md`
