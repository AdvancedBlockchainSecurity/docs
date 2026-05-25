# Stripe Billing Portal Audit Workflow

**Version:** 1.0.0
**Last Updated:** 2026-04-24
**Status:** Active
**Purpose:** End-to-end validation that the customer billing portal flow (portal session creation → invoice list/download → payment method update → billing details update → `customer.updated` webhook) works correctly and is properly authorized.
**Audience:** Operator (owner) + `apogee-function-unit-regression-tester` agent
**Audit Type:** functionality (portal journey)

---

## ⚠️ Mandatory End-to-End Execution

**This workflow MUST be run from beginning to end without skipping any step, even if it was exercised recently.** Each step depends on state established by the previous one. Skipping invalidates the result. If a step fails, fix the underlying issue and re-run **from Step 1**.

---

## Overview

This workflow exercises the user-facing billing portal experience end-to-end. The portal is a Stripe-hosted page launched from an Apogee-issued portal session URL. It must round-trip safely: changes made in the portal must propagate back via webhooks; reads (invoices, history) must be properly tenant-scoped.

Test mode only. Local cluster only. Test account `jasonbrailowbizop@mail.com` with at least one paid subscription history (run `stripe-subscription-lifecycle-audit-workflow.md` Steps 1–2 first to seed an invoice).

---

## Prerequisites

- [ ] Cluster reachable per `docs/standards/service-availability.md`
- [ ] Stripe **test mode** keys loaded; Stripe CLI forwarding active
- [ ] DB backup created per `docs/standards/database-management.md`
- [ ] Test account has at least one paid invoice in test mode
- [ ] Second test user available (for tenant isolation checks) — or use an org admin context

---

## Standards Referenced

- `docs/standards/api-endpoint-auth.md`
- `docs/standards/secure-coding.md` (BSO-SEC-014 redirect whitelist for `return_url`)
- `docs/standards/encryption-standards.md` (TLS for portal URLs)
- `docs/standards/INDEX.md`

---

## Prior Audits Referenced

- `docs/audits/2026-02-25-platform-security-audit.md`
- `docs/audits/2026-02-24-org-team-subscription-audit.md`
- `docs/audit/comprehensive-audit-2026-03-15.md`

---

## Steps

### Step 1 — Create portal session

| Aspect | Expected |
|--------|----------|
| API | POST `/billing/portal` with valid auth | [ ] |
| HTTP | 200 with `portal_url` (HTTPS, stripe.com host) | [ ] |
| Validation | `return_url` (if accepted as input) passes redirect whitelist (BSO-SEC-014) | [ ] |
| Audit log | Portal-session-created entry | [ ] |

### Step 2 — List invoices

| Aspect | Expected |
|--------|----------|
| API | GET `/billing/invoices` | [ ] |
| HTTP | 200; sorted by date desc; pagination if > N | [ ] |
| Authz | Returns only invoices for the authenticated user | [ ] |
| Cross-check | Count and IDs match Stripe dashboard for the test customer | [ ] |

### Step 3 — Download invoice PDF

| Aspect | Expected |
|--------|----------|
| API | GET `/billing/invoices/{id}/pdf` for an invoice owned by caller | [ ] |
| HTTP | 200; `Content-Type: application/pdf`; PDF bytes returned | [ ] |
| Authz | GET for an invoice not owned by caller → 404/403 | [ ] |

### Step 4 — Combined billing history

| Aspect | Expected |
|--------|----------|
| API | GET `/billing/history` | [ ] |
| HTTP | 200; combined Stripe + x402 credit history sorted by date | [ ] |
| Authz | Other users cannot read this history | [ ] |

### Step 5 — Update payment method (in Stripe portal)

| Aspect | Expected |
|--------|----------|
| User | In portal, replace payment method with test card `4242 4242 4242 4242` | [ ] |
| Stripe | `customer.updated` event emitted | [ ] |

### Step 6 — `customer.updated` webhook (no-op verification)

| Aspect | Expected |
|--------|----------|
| Webhook | POST `/api/v1/webhooks/stripe` arrives with `customer.updated` payload | [ ] |
| Handler | Currently a no-op (per inventory); confirm no unintended writes | [ ] |
| DB | No row changes resulting from the no-op | [ ] |
| Audit log | Event-received entry (or silent per implementation) | [ ] |

If the handler is no longer a no-op (e.g., email sync now wired), this is a **functionality drift** — file as a documentation update.

### Step 7 — Update billing details

| Aspect | Expected |
|--------|----------|
| API | PUT `/billing/details` with new company name + address + tax ID | [ ] |
| HTTP | 200; `BillingDetailsModel` row upserted | [ ] |
| Stripe | Billing details synced via Stripe API call | [ ] |
| API | GET `/billing/details` returns the new values | [ ] |
| Validation | Tax ID validated for type/format (per Stripe rules) | [ ] |

### Step 8 — Tenant isolation re-check

| Aspect | Expected |
|--------|----------|
| Other user | GET `/billing/portal` as User B → 200 with B's portal URL (NOT A's) | [ ] |
| Other user | GET `/billing/invoices` as B → only B's invoices | [ ] |
| Other user | GET `/billing/details` as B → only B's details | [ ] |

---

## Reset After Run

- [ ] Test account billing details restored if changed for the audit
- [ ] Portal sessions expire naturally (no manual cleanup required)

---

## Failure Handling

If any step fails:
1. Stop. Do not advance.
2. Capture: HTTP response, webhook payload, DB row diff.
3. File the regression. Tenant-isolation failures (Step 8) escalate to the security audit immediately.
4. Re-run from Step 1.

---

## Related Docs

- `docs/audit-playbooks/stripe-functionality-audit-playbook.md` (Phase 10)
- `docs/audit-playbooks/stripe-security-audit-playbook.md` (Phase 6 tenant isolation)
- `docs/audit-pipelines/stripe-functionality-audit-pipeline.md`
- `docs/workflows/billing-subscription-workflow.md`
- `docs/playbooks/stripe-payment-setup.md`
- `docs/.claude/agents/apogee-function-unit-regression-tester.md`
