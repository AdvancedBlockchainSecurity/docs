# Stripe Functionality Audit Playbook

**Version:** 1.0.0
**Last Updated:** 2026-04-24
**Status:** Active
**Purpose:** Reusable, end-to-end functionality audit of every Stripe code path — checkout, tier change preview, upgrade/downgrade, cancel/reactivate, annual vs monthly billing math, tax, invoice retrieval, plan-limit enforcement.
**Audience:** Operator (owner) — invokes the `apogee-function-unit-regression-tester` agent and follows this procedure
**Audit Type:** functionality

---

## ⚠️ Mandatory End-to-End Execution

**This audit MUST be run from beginning to end without skipping any phase, even if it was executed recently.** Each phase produces evidence the next phase depends on (e.g., the upgrade phase establishes the subscription state the downgrade phase mutates). Skipping invalidates the audit report. If a phase fails, fix the underlying issue and re-run **from Phase 1** — do not patch and resume mid-audit.

When the owner says "run the Stripe functionality audit," every phase below runs.

---

## Overview

This playbook orchestrates a Stripe-scoped functionality audit using the `apogee-function-unit-regression-tester` agent (see `docs/.claude/agents/apogee-function-unit-regression-tester.md`). It covers the lifecycle and math correctness of every billing/payment code path.

The audit runs against the **local cluster only** (per `feedback_local_not_gcp.md`), uses Stripe **test mode** keys, and exercises the test account `jasonbrailowbizop@mail.com`. Integration tests hit the real local PostgreSQL — no mocked DB (per agent definition).

---

## Prerequisites

- [ ] Cluster reachable via ingress per `docs/standards/service-availability.md`
- [ ] Stripe **test mode** keys loaded; live keys NOT in use
- [ ] DB backup created via `database-management.md` procedure (audit writes test data)
- [ ] Owner approval to invoke `apogee-function-unit-regression-tester` agent (Rule 0)
- [ ] Test account `jasonbrailowbizop@mail.com` available
- [ ] Test account starts in known state (Developer tier, no active subscription) — reset via SQL fixture if needed
- [ ] Pods restarted after any code pull (per Rule 3, `core-development-rules.md`)

---

## Standards Referenced

- `docs/standards/api-endpoint-auth.md` — write endpoints must use `require_auth_with_scope()`
- `docs/standards/testing-deployment.md` — test-before-deploy
- `docs/standards/database-management.md` — backup before any DB-affecting work
- `docs/standards/tier-standards.md` — tier feature/quota gating
- `docs/standards/core-development-rules.md` — Rule 3 (pod restart after code changes)
- `docs/standards/INDEX.md`

---

## Prior Audits Referenced

- `docs/audits/2026-02-24-org-team-subscription-audit.md`
- `docs/audits/2026-03-13-tier-v4-audit.md`
- `docs/audits/2026-02-16_Go_Live_Audit_Test_Results.md`
- `docs/audit/comprehensive-audit-2026-03-15.md`
- `docs/audits/test-coverage.md`

---

## Agent Invocation

Invoke `apogee-function-unit-regression-tester` (Sonnet 4.6 default; escalate to Opus 4.7 only for unexplained regressions). Output goes to `docs/audit/YYYY-MM-DD-stripe-functionality-test-results.md`.

---

## Phase 1: Checkout Session Creation

### 1.1 Subscription checkout

| # | Test | Expected | Status |
|---|------|----------|--------|
| 1.1.1 | POST `/billing/checkout` with Starter monthly price ID | HTTP 200; `checkout_session_url` returned; tax enabled; promotion codes enabled; billing address required | [ ] |
| 1.1.2 | POST `/billing/checkout` with Growth annual price ID | HTTP 200; annual price reflected | [ ] |
| 1.1.3 | POST `/billing/checkout` with Enterprise tier (custom flow) | HTTP 200 OR documented exception with operator escalation | [ ] |
| 1.1.4 | POST `/billing/checkout` with invalid price ID | HTTP 400/422 | [ ] |
| 1.1.5 | POST `/billing/checkout` while user already has active subscription | HTTP 409 OR documented upgrade redirect path | [ ] |

**Verification:** `docs/audit-pipelines/stripe-functionality-audit-pipeline.md` Phase 1.

**Evidence to capture:** Response bodies, `subscriptions` table row count before/after.

---

## Phase 2: Tier Change Preview & Proration Math

### 2.1 Preview correctness

| # | Test | Expected | Status |
|---|------|----------|--------|
| 2.1.1 | GET `/billing/subscription/change-tier/preview?tier=growth&interval=monthly` while on Starter | Returns prorated charge; matches Stripe upcoming-invoice math | [ ] |
| 2.1.2 | GET preview for upgrade mid-cycle | Prorated immediate charge ≈ remaining-days * (new − old) / period_days | [ ] |
| 2.1.3 | GET preview for downgrade | Returns scheduled change at period end with credit; no immediate charge | [ ] |
| 2.1.4 | GET preview to same tier/interval | HTTP 400 OR no-op response | [ ] |
| 2.1.5 | GET preview while subscription is `past_due` | Documented behavior (block or allow) | [ ] |

**Evidence to capture:** Preview JSON for each scenario; spot-check arithmetic against Stripe's upcoming-invoice endpoint.

---

## Phase 3: Upgrade (Immediate Proration)

### 3.1 Apply upgrade

| # | Test | Expected | Status |
|---|------|----------|--------|
| 3.1.1 | POST `/billing/subscription/change-tier` (Starter → Growth) | HTTP 200; immediate proration charge created in Stripe; `subscriptions.tier` updated | [ ] |
| 3.1.2 | `customer.subscription.updated` webhook fires | Audit log + DB row reflect new tier | [ ] |
| 3.1.3 | Plan limits update immediately (`/billing/plan-limit`) | Returns Growth quota | [ ] |
| 3.1.4 | Dashboard shows new tier without manual refresh | UI reflects updated state | [ ] |

**Evidence to capture:** Subscription DB row before/after; webhook event payload.

---

## Phase 4: Downgrade (Deferred to Period End)

### 4.1 Schedule downgrade

| # | Test | Expected | Status |
|---|------|----------|--------|
| 4.1.1 | POST `/billing/subscription/change-tier` (Growth → Starter) | HTTP 200; Stripe `subscription.schedule` created OR proration_behavior set to defer | [ ] |
| 4.1.2 | `subscriptions.tier` remains Growth until period end | Not prematurely downgraded | [ ] |
| 4.1.3 | Plan limits remain Growth until period end | `/billing/plan-limit` returns Growth quota | [ ] |
| 4.1.4 | Period boundary crossed (simulate via Stripe test clock if available) | `customer.subscription.updated` fires; tier becomes Starter; quota becomes Starter | [ ] |

**Evidence to capture:** Schedule object, period boundary transition, plan-limit response before and after.

---

## Phase 5: Cancel (At Period End)

### 5.1 Cancel scheduled

| # | Test | Expected | Status |
|---|------|----------|--------|
| 5.1.1 | POST `/billing/subscription/cancel?at_period_end=true` | HTTP 200; `cancel_at_period_end=true` on Stripe subscription | [ ] |
| 5.1.2 | DB row updated with `cancellation_scheduled_for` timestamp | Matches Stripe's `current_period_end` | [ ] |
| 5.1.3 | User retains paid tier features until period end | Plan limits unchanged | [ ] |
| 5.1.4 | Period boundary crossed → `customer.subscription.deleted` fires | Tier downgraded to Developer; quota = 3/mo | [ ] |

**Evidence to capture:** Cancellation flag in DB; webhook payload at period end.

---

## Phase 6: Reactivate Before Period End

### 6.1 Undo cancellation

| # | Test | Expected | Status |
|---|------|----------|--------|
| 6.1.1 | POST `/billing/subscription/reactivate` while `cancel_at_period_end=true` | HTTP 200; flag cleared on Stripe | [ ] |
| 6.1.2 | DB `cancellation_scheduled_for` cleared | NULL | [ ] |
| 6.1.3 | `customer.subscription.updated` webhook fires | Reflects reactivation | [ ] |

---

## Phase 7: Cancel Immediately

### 7.1 Hard cancel

| # | Test | Expected | Status |
|---|------|----------|--------|
| 7.1.1 | POST `/billing/subscription/cancel?at_period_end=false` (admin/special path) | Documented behavior — likely 403 for self-service or 200 for admin | [ ] |
| 7.1.2 | Refund (or no refund) policy reflected per `tier-standards.md` | Matches documented policy | [ ] |
| 7.1.3 | Tier immediately becomes Developer | `/billing/plan-limit` reflects within seconds | [ ] |

---

## Phase 8: Annual vs Monthly Billing Math

### 8.1 Pricing arithmetic

| # | Test | Expected | Status |
|---|------|----------|--------|
| 8.1.1 | Starter annual = $2,028 (= $169/mo bulk-discounted, NOT $199 × 12 = $2,388) | Stripe price object matches | [ ] |
| 8.1.2 | Growth annual = $5,028 (= $419/mo bulk-discounted) | Stripe price object matches | [ ] |
| 8.1.3 | Pricing page (`/billing/plans`) reflects same numbers as `tiers.json` and Stripe | Three-way match | [ ] |
| 8.1.4 | Switching monthly → annual mid-cycle prorates correctly | Math validated against Stripe upcoming invoice | [ ] |

**Evidence to capture:** `tiers.json` snapshot, Stripe price object snapshot, `/billing/plans` response — all three.

---

## Phase 9: Tax Calculation

### 9.1 Stripe Automatic Tax

| # | Test | Expected | Status |
|---|------|----------|--------|
| 9.1.1 | Checkout for US-based test customer (CA address) | Tax line present; rate matches CA local tax | [ ] |
| 9.1.2 | Checkout for EU-based test customer with valid VAT ID | Reverse-charge applied OR VAT included per Stripe rules | [ ] |
| 9.1.3 | Checkout with invalid tax ID format | Tax ID rejected with clear error | [ ] |
| 9.1.4 | `stripe_tax_enabled=true` in `config.py` is honored | Tax calculation invoked | [ ] |

**Evidence to capture:** Tax line items on test invoices.

---

## Phase 10: Invoice Retrieval

### 10.1 List + PDF

| # | Test | Expected | Status |
|---|------|----------|--------|
| 10.1.1 | GET `/billing/invoices` for user with > 0 invoices | Sorted by date desc; pagination if > N | [ ] |
| 10.1.2 | GET `/billing/invoices/{id}/pdf` | Returns PDF bytes; `Content-Type: application/pdf` | [ ] |
| 10.1.3 | GET `/billing/invoices/{id}/pdf` for invoice not owned by caller | HTTP 404/403 | [ ] |
| 10.1.4 | GET `/billing/history` for user with both Stripe + x402 history | Combined chronological list | [ ] |

---

## Phase 11: Plan-Limit Enforcement

### 11.1 Quota gating

| # | Test | Expected | Status |
|---|------|----------|--------|
| 11.1.1 | GET `/billing/plan-limit` for Developer | Returns `contracts_per_month=3` | [ ] |
| 11.1.2 | GET `/billing/plan-limit` for Starter | Returns `25` | [ ] |
| 11.1.3 | GET `/billing/plan-limit` for Growth | Returns `75` | [ ] |
| 11.1.4 | Attempt scan after quota exhausted | HTTP 402 with quota-error message | [ ] |
| 11.1.5 | Quota resets at period boundary | Available scans return after rollover | [ ] |

---

## Audit Report Template

Copy this into `docs/audit/YYYY-MM-DD-stripe-functionality-test-results.md`.

```markdown
# Stripe Functionality Test Results — YYYY-MM-DD

**Author:** apogee-function-unit-regression-tester
**Scope:** Stripe billing/payments code paths — checkout, preview, upgrade, downgrade, cancel/reactivate, annual math, tax, invoices, plan-limit. Test mode only. Local cluster only.
**Standards referenced:** see Standards Referenced section of `docs/audit-playbooks/stripe-functionality-audit-playbook.md`

## Executive Summary
<2–4 sentences>

## Phase-by-phase Results
| Phase | Outcome | Notable |
|-------|---------|---------|
| 1 Checkout session | Pass/Fail | |
| 2 Preview/proration | Pass/Fail | |
| 3 Upgrade | Pass/Fail | |
| 4 Downgrade (deferred) | Pass/Fail | |
| 5 Cancel at period end | Pass/Fail | |
| 6 Reactivate | Pass/Fail | |
| 7 Cancel immediately | Pass/Fail | |
| 8 Annual vs monthly math | Pass/Fail | |
| 9 Tax | Pass/Fail | |
| 10 Invoices | Pass/Fail | |
| 11 Plan-limit | Pass/Fail | |

## Regressions
- <pass→fail compared to prior `docs/audit/*-test-results.md`>

## Bugs Discovered (per CLAUDE.md "Issue Reporting")
- <file to TaskDocs-BlockSecOps/>

## Follow-ups
- [ ] <actionable item tied to owner>
```

---

## Failure Handling

If any phase fails:
1. Stop. Do not advance.
2. File the regression with file:line and the offending commit/image tag (per agent definition).
3. Fix the root cause; do not adjust the test to make it pass.
4. Re-run the **full** audit from Phase 1.

---

## Related Docs

- `docs/audit-playbooks/stripe-full-audit-playbook.md` — orchestrator
- `docs/audit-pipelines/stripe-functionality-audit-pipeline.md` — exact commands per phase
- `docs/audit-workflows/stripe-subscription-lifecycle-audit-workflow.md` — end-to-end lifecycle journey
- `docs/audit-workflows/stripe-billing-portal-audit-workflow.md` — portal flow
- `docs/.claude/agents/apogee-function-unit-regression-tester.md`
- `docs/workflows/billing-subscription-workflow.md`
- `docs/workflows/subscription-workflow.md`
- `docs/workflows/tier-upgrading-workflow.md`
- `docs/pipelines/billing-feature-pipeline.md`
- `docs/pipelines/subscription-pipeline.md`
- `docs/feature-tests/37-stripe-billing.md`
- `docs/feature-tests/52-dual-payment-options.md`
