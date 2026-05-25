# Stripe Webhook Event Audit Workflow

**Version:** 1.0.0
**Last Updated:** 2026-04-24
**Status:** Active
**Purpose:** End-to-end validation of every Stripe webhook event Apogee handles — `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.payment_succeeded`, `invoice.payment_failed`, `customer.updated`. Each event is triggered, signature-verified, dispatched, and replay-tested for idempotency.
**Audience:** Operator (owner) + `apogee-function-unit-regression-tester` agent (with `apogee-security-audit` consulted on signature checks)
**Audit Type:** functionality + security (webhook journey)

---

## ⚠️ Mandatory End-to-End Execution

**This workflow MUST be run from beginning to end without skipping any event, even if it was exercised recently.** Each event reveals a different code path; skipping any leaves a coverage gap. If an event fails, fix the underlying issue and re-run **from Event 1**.

---

## Overview

This workflow uses the Stripe CLI in test mode to trigger each webhook event end-to-end against the local API ingress. No `kubectl port-forward` (per `feedback_no_port_forward.md`); the Stripe CLI forwards to the ingress URL per `docs/standards/service-availability.md`.

For each event the workflow validates: **Stripe CLI trigger** → **signature verification** → **handler dispatch** → **DB consistency** → **audit log entry** → **idempotency replay**.

---

## Prerequisites

- [ ] Cluster reachable via ingress per `docs/standards/service-availability.md`
- [ ] Stripe **test mode** keys loaded
- [ ] `stripe-cli` installed and authenticated to test mode
- [ ] `stripe listen --forward-to https://<ingress-host>/api/v1/webhooks/stripe` active in a separate terminal
- [ ] DB backup created per `docs/standards/database-management.md`
- [ ] Test account `jasonbrailowbizop@mail.com` available; in a known state per the event under test
- [ ] Read access to `audit_logs` table

---

## Standards Referenced

- `docs/standards/api-endpoint-auth.md`
- `docs/standards/secure-coding.md`
- `docs/standards/encryption-standards.md`
- `docs/standards/secrets-management.md`
- `docs/standards/service-availability.md` (no port-forward)
- `docs/standards/INDEX.md`

---

## Prior Audits Referenced

- `docs/audits/2026-02-25-platform-security-audit.md`
- `docs/audits/2026-02-25-auth-x402-audit.md`
- `docs/audit/security-audit-fresh-2026-03-15.md`

---

## Pre-flight: Stripe CLI Forwarding

| # | Test | Expected | Status |
|---|------|----------|--------|
| 0.1 | `stripe listen --forward-to https://<ingress-host>/api/v1/webhooks/stripe` | Connected; forwarding webhook secret printed (use this `whsec_*` for `STRIPE_WEBHOOK_SECRET` during the audit) | [ ] |
| 0.2 | Test webhook reaches the API service | Liveness check OK; `POST /api/v1/webhooks/stripe/health` (or equivalent) returns 200 | [ ] |
| 0.3 | API uses the CLI-issued `whsec_*` secret | `STRIPE_WEBHOOK_SECRET` config matches | [ ] |

If pre-flight fails, fix forwarding before continuing.

---

## Event 1 — `checkout.session.completed`

### Trigger via Stripe CLI

| Aspect | Expected |
|--------|----------|
| Trigger | `stripe trigger checkout.session.completed` (or via real test-mode checkout) | [ ] |
| Signature | Handler verifies `Stripe-Signature` via `stripe.Webhook.construct_event` | [ ] |
| Dispatch | Routed to `checkout.session.completed` branch | [ ] |
| DB | Subscription created OR credit balance updated based on `mode` (`subscription` vs `payment`) | [ ] |
| Audit log | Event-handled entry | [ ] |
| Replay | Replay event → idempotent (no double-create / double-credit) | [ ] |

---

## Event 2 — `customer.subscription.updated`

| Aspect | Expected |
|--------|----------|
| Trigger | `stripe trigger customer.subscription.updated` | [ ] |
| Signature | Verified | [ ] |
| Dispatch | Tier / period / cancellation status reconciled with DB | [ ] |
| DB | `subscriptions` row mutated to match Stripe truth | [ ] |
| Audit log | Subscription-updated entry | [ ] |
| Replay | Idempotent | [ ] |

---

## Event 3 — `customer.subscription.deleted`

| Aspect | Expected |
|--------|----------|
| Trigger | `stripe trigger customer.subscription.deleted` | [ ] |
| Signature | Verified | [ ] |
| Dispatch | User downgraded to Developer | [ ] |
| DB | `subscriptions.status='canceled'`; user tier reverts | [ ] |
| Audit log | Subscription-deleted entry | [ ] |
| Replay | Idempotent | [ ] |

---

## Event 4 — `invoice.payment_succeeded`

| Aspect | Expected |
|--------|----------|
| Trigger | `stripe trigger invoice.payment_succeeded` | [ ] |
| Signature | Verified | [ ] |
| Dispatch | If subscription was `past_due`, reactivated; otherwise no-op or audit log only | [ ] |
| DB | `subscriptions.status='active'` if previously past_due | [ ] |
| Audit log | Payment-succeeded entry | [ ] |
| Replay | Idempotent | [ ] |

---

## Event 5 — `invoice.payment_failed`

| Aspect | Expected |
|--------|----------|
| Trigger | `stripe trigger invoice.payment_failed` | [ ] |
| Signature | Verified | [ ] |
| Dispatch | Subscription marked `past_due` | [ ] |
| DB | `subscriptions.status='past_due'` | [ ] |
| Audit log | Payment-failed entry | [ ] |
| Replay | Idempotent | [ ] |
| User-facing | (Documented behavior — email/notification triggered or queued) | [ ] |

---

## Event 6 — `customer.updated`

| Aspect | Expected |
|--------|----------|
| Trigger | `stripe trigger customer.updated` | [ ] |
| Signature | Verified | [ ] |
| Dispatch | Currently no-op per code inventory; confirm still no-op OR file drift if behavior added | [ ] |
| DB | No unintended writes | [ ] |
| Audit log | Event-received entry (silent or logged per implementation) | [ ] |
| Replay | Idempotent (no-op + no-op = no-op) | [ ] |

---

## Adversarial Sub-cases (cross-link to security audit)

These reproduce part of `stripe-security-audit-playbook.md` Phase 1 to ensure the webhook flow is covered both functionally and adversarially:

| # | Test | Expected | Status |
|---|------|----------|--------|
| A.1 | POST with no signature header | HTTP 400; `STRIPE_SIGNATURE_FAILURE` audit log row | [ ] |
| A.2 | POST with wrong-secret signature | HTTP 400; audit log row | [ ] |
| A.3 | POST with valid signature but malformed JSON body | HTTP 400 | [ ] |

---

## Reset After Run

- [ ] DB rows mutated by triggered test-mode events cleaned (or DB restored from backup if needed)
- [ ] `stripe listen` terminated
- [ ] Stripe test customers / subscriptions cleaned up

---

## Failure Handling

If any event fails:
1. Stop. Do not advance.
2. Capture: webhook payload, signature header, HTTP response, DB diff, audit-log row.
3. Signature/replay failures route to the security audit (BSO-SEC-NNN).
4. Functional/idempotency failures route to the functionality audit.
5. Re-run from Event 1.

---

## Related Docs

- `docs/audit-playbooks/stripe-security-audit-playbook.md` (Phases 1–2)
- `docs/audit-playbooks/stripe-functionality-audit-playbook.md`
- `docs/audit-pipelines/stripe-security-audit-pipeline.md`
- `docs/audit-workflows/stripe-subscription-lifecycle-audit-workflow.md`
- `docs/audit-workflows/stripe-credit-purchase-audit-workflow.md`
- `docs/pipelines/subscription-pipeline.md` — handler architecture
- `docs/.claude/agents/apogee-security-audit.md`
- `docs/.claude/agents/apogee-function-unit-regression-tester.md`
