# Stripe Security Audit Playbook

**Version:** 1.0.0
**Last Updated:** 2026-04-24
**Status:** Active
**Purpose:** Reusable, end-to-end security audit of the Apogee Stripe surface — signature verification, webhook idempotency, metadata whitelist, redirect URL whitelist, secret hygiene, tenant isolation, audit-log review.
**Audience:** Operator (owner) — invokes the `apogee-security-audit` agent and follows this procedure
**Audit Type:** security

---

## ⚠️ Mandatory End-to-End Execution

**This audit MUST be run from beginning to end without skipping any phase, even if it was executed recently.** Each phase produces evidence the next phase depends on (e.g., the signature-verification phase establishes the trust boundary that the metadata-whitelist phase relies on). Skipping invalidates the audit report. If a phase fails, fix the underlying issue and re-run **from Phase 1** — do not patch and resume mid-audit.

When the owner says "run the Stripe security audit," every phase below runs.

---

## Overview

This playbook orchestrates a Stripe-scoped security audit using the `apogee-security-audit` agent (see `docs/.claude/agents/apogee-security-audit.md`). It complements — and does not replace — the platform-wide security audits in `docs/audits/2026-02-25-platform-security-audit.md` and `docs/audits/2026-02-25-auth-x402-audit.md`. Findings continue the `BSO-SEC-NNN` ID sequence already established under `docs/security-audit/`.

The audit is **read-only and adversarial against the local cluster** (per `feedback_local_not_gcp.md`). It does not run against GCP production. It uses Stripe **test mode** keys exclusively.

---

## Prerequisites

- [ ] Cluster reachable via ingress per `docs/standards/service-availability.md`
- [ ] Stripe **test mode** keys loaded (sk_test_*, whsec_*); live keys NOT in use
- [ ] DB backup exists per `docs/standards/database-management.md`
- [ ] Owner approval to invoke `apogee-security-audit` agent (Rule 0)
- [ ] Test account `jasonbrailowbizop@mail.com` available (per memory)
- [ ] Read access to `audit_logs` table (`TierSecurityAlert` rows in particular)
- [ ] `stripe-cli` installed locally for webhook event triggering

---

## Standards Referenced

- `docs/standards/api-endpoint-auth.md` — write endpoints must use `require_auth_with_scope()`
- `docs/standards/secure-coding.md` — OWASP Top 10 baseline (CWE references)
- `docs/standards/encryption-standards.md` — TLS 1.2+, hashing, prohibited algorithms
- `docs/standards/secrets-management.md` — Vault + ESO; no secrets in Git (per `feedback_no_env_commits.md`)
- `docs/standards/security-standards.md` — baseline hardening
- `docs/standards/tier-standards.md` — tier feature gating
- `docs/standards/INDEX.md`

---

## Prior Audits Referenced

- `docs/audits/2026-02-25-platform-security-audit.md`
- `docs/audits/2026-02-25-auth-x402-audit.md`
- `docs/audits/2026-02-07_API_Security_Audit.md`
- `docs/audits/2026-02-24-org-team-subscription-audit.md`
- `docs/audit/security-audit-fresh-2026-03-15.md`
- `docs/audit/comprehensive-audit-2026-03-15.md`
- `docs/audit/2026-04-15-secure-coding-checklist-from-github.md`
- `docs/security-audit/` — historical `FIX-BSO-SEC-001` through `FIX-BSO-SEC-006`, `FULL-AUDIT-SUMMARY.md`

---

## Agent Invocation

Invoke `apogee-security-audit` (Opus 4.7) with scope: "Stripe surface only — webhook handler, billing endpoints, payment endpoints, Stripe service, Stripe-related models, Stripe secrets in Vault/ESO, Stripe-related audit logs."

Output goes to `docs/audit/YYYY-MM-DD-stripe-security-audit.md` per the agent's output format. Findings use `BSO-SEC-NNN` continuing the prior sequence.

---

## Phase 1: Signature Verification

### 1.1 Construct event signature failures

| # | Test | Expected | Status |
|---|------|----------|--------|
| 1.1.1 | POST `/api/v1/webhooks/stripe` with no `Stripe-Signature` header | HTTP 400; audit log row `TierSecurityAlert.STRIPE_SIGNATURE_FAILURE` written | [ ] |
| 1.1.2 | POST with malformed `Stripe-Signature` header (random bytes) | HTTP 400; audit log row written | [ ] |
| 1.1.3 | POST with valid signature format but wrong secret (signed with old `whsec_*`) | HTTP 400; audit log row written | [ ] |
| 1.1.4 | POST with replayed signature from prior valid event | HTTP 400 OR handler is idempotent (Phase 2 verifies) | [ ] |
| 1.1.5 | POST with signature constructed using `whsec_*` from a different environment | HTTP 400 | [ ] |

**Verification:** `docs/audit-pipelines/stripe-security-audit-pipeline.md` Phase 1 commands (read-only `curl` + audit-log `SELECT`).

**Evidence to capture:**
- Exact HTTP response body for each test
- `audit_logs` rows produced (timestamp, alert_type, request_id)
- File:line of `stripe.Webhook.construct_event(...)` invocation in `blocksecops-api-service/src/presentation/api/v1/endpoints/stripe_webhook.py`

---

## Phase 2: Webhook Idempotency

### 2.1 Replay a valid event twice

| # | Test | Expected | Status |
|---|------|----------|--------|
| 2.1.1 | Replay `checkout.session.completed` for a known credit purchase | First call credits balance; second call is a no-op (no double-credit) | [ ] |
| 2.1.2 | Replay `invoice.payment_succeeded` for a known subscription | Subscription remains `active`; no duplicate row in `payment_transactions` | [ ] |
| 2.1.3 | Replay `customer.subscription.updated` for a tier change | Subscription tier set once; no duplicate audit-log entries | [ ] |
| 2.1.4 | Send same event with different `event.id` (forged) | Second call is rejected OR processed independently per Stripe semantics — capture which | [ ] |

**Verification:** Pipeline Phase 2 commands. Read `payment_transactions.stripe_payment_intent_id` for uniqueness.

**Evidence to capture:** Row counts before/after each replay; idempotency key implementation file:line.

---

## Phase 3: Metadata Whitelist (Tier Escalation Prevention)

### 3.1 Forge metadata in checkout sessions

| # | Test | Expected | Status |
|---|------|----------|--------|
| 3.1.1 | Send `checkout.session.completed` with `metadata.tier="enterprise"` for a Starter price ID | Handler rejects mismatch OR derives tier from price ID, not metadata | [ ] |
| 3.1.2 | Send event with `metadata.user_id` of a different user than the session customer | Subscription assigned by customer ID, not metadata user_id | [ ] |
| 3.1.3 | Send event with `metadata.billing_interval="annual"` for a monthly price ID | Billing interval derived from price ID; metadata ignored or rejected | [ ] |
| 3.1.4 | Send event with `metadata.package_id` not in `tiers.json` credit packages | Handler rejects (BSO-SEC-015 server-side credit amount rule) | [ ] |
| 3.1.5 | Metadata value > 500 chars OR contains control characters | Handler rejects per metadata sanitization rules | [ ] |

**Evidence to capture:** Code path that resolves tier (file:line), comparison between price-ID-derived value and metadata-supplied value.

---

## Phase 4: Redirect URL Whitelist (BSO-SEC-014)

### 4.1 Open-redirect attempts

| # | Test | Expected | Status |
|---|------|----------|--------|
| 4.1.1 | POST `/payments/checkout/stripe` with `success_url=https://attacker.example/` | Rejected by `_validate_redirect_url()` whitelist | [ ] |
| 4.1.2 | POST with `cancel_url=javascript:alert(1)` | Rejected | [ ] |
| 4.1.3 | POST with `success_url` matching whitelist host but `@attacker` userinfo | Rejected | [ ] |
| 4.1.4 | POST with `success_url` matching whitelist scheme/host but path `/../../evil` | Rejected | [ ] |
| 4.1.5 | POST with whitelisted URL — succeeds | HTTP 200 + `session_url` returned | [ ] |

**Evidence to capture:** `_validate_redirect_url()` implementation (file:line), whitelist source (config vs hardcoded), test coverage for these inputs.

---

## Phase 5: Secret Hygiene

### 5.1 No Stripe secrets in Git

| # | Test | Expected | Status |
|---|------|----------|--------|
| 5.1.1 | `grep -r "sk_live_" /home/pwner/Git/blocksecops-* /home/pwner/Git/docs/` | Zero matches | [ ] |
| 5.1.2 | `grep -r "sk_test_" /home/pwner/Git/blocksecops-* /home/pwner/Git/docs/` outside example/test fixtures | Zero matches in production code | [ ] |
| 5.1.3 | `grep -r "whsec_" /home/pwner/Git/blocksecops-* /home/pwner/Git/docs/` | Zero matches outside docs/playbooks describing the variable name | [ ] |
| 5.1.4 | No `.env*` files containing Stripe keys committed (per `feedback_no_env_commits.md`) | Zero matches | [ ] |
| 5.1.5 | `STRIPE_API_KEY`, `STRIPE_WEBHOOK_SECRET` resolved from Vault via ExternalSecret | ExternalSecret manifests reference Vault paths; no inline `value:` for these keys | [ ] |
| 5.1.6 | `VITE_STRIPE_PUBLISHABLE_KEY` is a publishable (`pk_*`) key, never a secret key | Build-arg value matches `pk_*` pattern | [ ] |

**Evidence to capture:** ExternalSecret manifest paths; Vault path for each Stripe secret.

---

## Phase 6: Tenant Isolation

### 6.1 Cross-org/team subscription access

| # | Test | Expected | Status |
|---|------|----------|--------|
| 6.1.1 | User A queries `GET /billing/subscription` with User B's session cookie/JWT | HTTP 401/403; no leakage | [ ] |
| 6.1.2 | User A queries `GET /billing/invoices/{id}` for an invoice belonging to User B | HTTP 404 (or 403); no leakage | [ ] |
| 6.1.3 | Webhook arrives with customer ID matching User A; handler updates only A's subscription, not any sibling org | Only A's row mutated | [ ] |
| 6.1.4 | Org admin attempts to read another org's billing details | HTTP 403 | [ ] |
| 6.1.5 | Service-account API key from Org A used against Org B's billing endpoints | Rejected by org-scope check | [ ] |

**Evidence to capture:** Query-layer scoping (file:line in repository/data-access code); RBAC role check (file:line).

---

## Phase 7: Audit Log Review

### 7.1 STRIPE_SIGNATURE_FAILURE history

| # | Test | Expected | Status |
|---|------|----------|--------|
| 7.1.1 | `SELECT * FROM audit_logs WHERE alert_type='STRIPE_SIGNATURE_FAILURE' ORDER BY created_at DESC LIMIT 50` | Rows reviewed; spike investigation if > N/day | [ ] |
| 7.1.2 | Cross-reference with the IP source / user agent — any pattern of replay? | No anomalous source patterns | [ ] |
| 7.1.3 | Failed signature events correlated with deploys / secret rotations | Failures explained by rotation timing OR are unexplained (file as finding) | [ ] |
| 7.1.4 | Webhook delivery monitoring exists (Stripe dashboard delivery log reviewed) | Delivery log reviewed; failed deliveries enumerated | [ ] |

**Evidence to capture:** Last 50 audit-log rows summarized; Stripe dashboard delivery log screenshot reference.

---

## Audit Report Template

Copy this into `docs/audit/YYYY-MM-DD-stripe-security-audit.md` (matches `apogee-security-audit` agent output format).

```markdown
# Stripe Security Audit — YYYY-MM-DD

**Auditor:** apogee-security-audit
**Scope:** Stripe surface — webhook handler, billing endpoints, payment endpoints, Stripe service, Stripe-related models, Stripe secrets, Stripe-related audit logs. Excludes: `blocksecops_com` (out of scope per memory), Cairo (out of scope per memory), GCP-only execution paths (audit ran on local cluster).
**Severity scale:** Critical / High / Medium / Low / Info
**Standards referenced:** see Standards Referenced section of `docs/audit-playbooks/stripe-security-audit-playbook.md`

## Executive Summary
<2–4 sentences, non-technical>

## Findings

### BSO-SEC-NNN — <Title>
- **Severity:** <level>
- **CWE/OWASP:** <IDs>
- **Location:** `<repo>/<path>:<line>`
- **Description:** <what is wrong>
- **Impact:** <what an attacker gains>
- **Proof / Evidence:** <code snippet or request/response>
- **Recommended Fix:** <concrete change>
- **References:** <standards, prior FIX-BSO-SEC-XXX, CVEs>

## Positive Observations
<what is working well — important for balance>

## Phase-by-phase Status
| Phase | Outcome | Evidence Path |
|-------|---------|---------------|
| 1 Signature verification | Pass/Fail | <link> |
| 2 Webhook idempotency | Pass/Fail | <link> |
| 3 Metadata whitelist | Pass/Fail | <link> |
| 4 Redirect whitelist | Pass/Fail | <link> |
| 5 Secret hygiene | Pass/Fail | <link> |
| 6 Tenant isolation | Pass/Fail | <link> |
| 7 Audit log review | Pass/Fail | <link> |

## Follow-ups
- [ ] <actionable item tied to owner>
```

Finding IDs MUST continue the `BSO-SEC-NNN` sequence already in `docs/security-audit/`.

---

## Failure Handling

If any phase fails:
1. Stop. Do not advance.
2. File the finding using the report template above (`BSO-SEC-NNN`).
3. Fix the root cause; do not patch the test to make it pass.
4. Re-run the **full** audit from Phase 1.

Per `feedback_gitops_each_step_approval.md`: if remediation requires a code change, that is a separate fresh approval — do not bundle it with the audit task.

---

## Related Docs

- `docs/audit-playbooks/stripe-full-audit-playbook.md` — orchestrator
- `docs/audit-pipelines/stripe-security-audit-pipeline.md` — exact commands per phase
- `docs/audit-workflows/stripe-webhook-event-audit-workflow.md` — end-to-end webhook journey
- `docs/.claude/agents/apogee-security-audit.md` — agent definition
- `docs/workflows/stripe-dashboard-purchase-workflow.md`
- `docs/pipelines/subscription-pipeline.md`
- `docs/playbooks/stripe-payment-setup.md`
- `docs/playbooks/stripe-test-subscriptions.md`
