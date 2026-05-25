# Stripe Full Audit Playbook (Master Orchestrator)

**Version:** 1.0.0
**Last Updated:** 2026-04-24
**Status:** Active
**Purpose:** Orchestrate all five Stripe audits (documentation, security, functionality, purchase matrix, test coverage) end-to-end in a fixed order.
**Audience:** Operator (owner) — invokes the per-audit playbooks in sequence
**Audit Type:** orchestration

---

## ⚠️ Mandatory End-to-End Execution

**This audit MUST be run from beginning to end without skipping any phase, even if it was executed recently.** Each phase produces evidence the next phase depends on (the documentation audit catches drift that, if uncorrected, would invalidate the security and functionality audits; the security audit catches issues that affect what is safe to test in the purchase matrix). Skipping invalidates the audit report. If a phase fails, fix the underlying issue and re-run **from Phase 1** — do not patch and resume mid-audit.

When the owner says "run the Stripe full audit," every phase below runs, regardless of when it was last run.

---

## Overview

This master playbook is the single entry point for a complete Stripe audit. It does **not** restate the per-audit detail; it sequences the per-audit playbooks and records the consolidated outcome. Each per-audit playbook is independently invocable for targeted runs (per owner: "Each audit should have its own independent workflow").

Five audits run in this fixed order:

1. **Documentation audit** — catches drift first so later audits trust the docs
2. **Security audit** — Stripe-specific security (signature verification, metadata whitelist, redirect whitelist, secret hygiene, tenant isolation, audit-log review)
3. **Functionality audit** — every billing/payment code path (checkout, proration, deferral, cancel/reactivate, annual math, tax, invoices, plan-limit)
4. **Purchase matrix audit** — every purchasable product/SKU/coupon exercised in test mode against the test account
5. **Test coverage audit** — unit + regression + feature-test inventory and (operator-selected) execution

---

## Prerequisites

- [ ] Cluster reachable via ingress per `docs/standards/service-availability.md` (no `kubectl port-forward` for primary access)
- [ ] Test account `jasonbrailowbizop@mail.com` available (per memory: owner's authorized test account)
- [ ] Stripe **test mode** keys loaded; live keys NOT in use during audit
- [ ] DB backup exists per `docs/standards/database-management.md` (audit performs read-only queries, but the test mode purchases write to local DB)
- [ ] Owner approval to invoke the four agents listed below (Rule 0; per `feedback_gitops_each_step_approval.md`, each agent invocation is a fresh approval)
- [ ] No active GCP deployment under change (audit runs against local cluster per `feedback_local_not_gcp.md`)

---

## Standards Referenced

- `docs/standards/api-endpoint-auth.md` — write endpoints must use `require_auth_with_scope()`
- `docs/standards/secure-coding.md` — OWASP Top 10 baseline
- `docs/standards/encryption-standards.md` — TLS 1.2+, hashing, key management
- `docs/standards/secrets-management.md` — Vault + ESO; no secrets in Git
- `docs/standards/security-standards.md` — baseline hardening
- `docs/standards/kustomize-standards.md` — overlay structure
- `docs/standards/docker-image-versioning.md` — semver, immutable tags
- `docs/standards/ingress-networking.md` — service access pattern
- `docs/standards/database-management.md` — backup before any DB-affecting work
- `docs/standards/version-control-standards.md` — commit/PR workflow
- `docs/standards/testing-deployment.md` — test-before-deploy
- `docs/standards/tier-standards.md` — tier feature gating
- `docs/standards/INDEX.md` — full standards index

---

## Prior Audits Referenced

- `docs/audits/2026-02-25-platform-security-audit.md`
- `docs/audits/2026-02-25-auth-x402-audit.md`
- `docs/audits/2026-02-24-org-team-subscription-audit.md`
- `docs/audits/2026-03-13-tier-v4-audit.md`
- `docs/audits/2026-02-07_API_Security_Audit.md`
- `docs/audit/security-audit-fresh-2026-03-15.md`
- `docs/audit/comprehensive-audit-2026-03-15.md`
- `docs/audits/PLATFORM-AUDIT-CHECKLIST.md` — checklist-style template precedent
- `docs/audits/GO-LIVE-AUDIT-TESTING-CHECKLIST.md` — table-style test matrix precedent

---

## Agents Invoked (one per audit type)

| Audit | Agent | Output Path |
|-------|-------|-------------|
| Documentation | `apogee-documentation` | `TaskDocs-BlockSecOps/DOCUMENTATION-UPDATE-YYYY-MM-DD-stripe-audit.md` |
| Security | `apogee-security-audit` | `docs/audit/YYYY-MM-DD-stripe-security-audit.md` |
| Functionality | `apogee-function-unit-regression-tester` | `docs/audit/YYYY-MM-DD-stripe-functionality-test-results.md` |
| Purchase matrix | `apogee-function-unit-regression-tester` (with `tier-agent` consult) | `docs/audit/YYYY-MM-DD-stripe-purchase-matrix-results.md` |
| Test coverage | `apogee-function-unit-regression-tester` | `docs/audit/YYYY-MM-DD-stripe-test-coverage-results.md` |

Agent definitions: `docs/.claude/agents/apogee-documentation.md`, `apogee-security-audit.md`, `apogee-function-unit-regression-tester.md`, `tier-agent.md`.

---

## Phase 1: Documentation Audit

**Why first:** Drift in the docs (stale price IDs, broken file:line citations, missing standards cross-links) would taint every subsequent audit. Catch it first.

**Run:** `docs/audit-playbooks/stripe-documentation-audit-playbook.md` end-to-end.

| # | Test | Expected | Status |
|---|------|----------|--------|
| 1.1 | Documentation playbook completes all phases | Every phase checkbox green; no `[!]` rows | [ ] |
| 1.2 | Drift report is empty OR drift items are filed to `TaskDocs-BlockSecOps/` | Either no drift or filed drift tickets exist | [ ] |
| 1.3 | Audit report file written to `TaskDocs-BlockSecOps/DOCUMENTATION-UPDATE-YYYY-MM-DD-stripe-audit.md` | File exists, has Executive Summary | [ ] |

**Failure handling:** If drift is critical (e.g., a documented price ID does not match `tiers.json`), stop the full audit. Fix drift, then re-run from Phase 1.

---

## Phase 2: Security Audit

**Why second:** Security findings determine what is safe to exercise in the purchase matrix (e.g., if signature verification is broken, do not trigger live webhooks).

**Run:** `docs/audit-playbooks/stripe-security-audit-playbook.md` end-to-end.

| # | Test | Expected | Status |
|---|------|----------|--------|
| 2.1 | Security playbook completes all phases | Every phase checkbox green | [ ] |
| 2.2 | No new Critical or High findings (BSO-SEC-NNN) | Findings list reviewed; severity ≤ Medium for new items | [ ] |
| 2.3 | Audit report file written to `docs/audit/YYYY-MM-DD-stripe-security-audit.md` | File exists, BSO-SEC IDs continue prior sequence | [ ] |

**Failure handling:** If a Critical or High finding is identified, stop the full audit. File the finding per `apogee-security-audit` agent format. Do **not** proceed to purchase matrix until remediation is approved by the owner.

---

## Phase 3: Functionality Audit

**Run:** `docs/audit-playbooks/stripe-functionality-audit-playbook.md` end-to-end.

| # | Test | Expected | Status |
|---|------|----------|--------|
| 3.1 | Functionality playbook completes all phases | Every phase checkbox green | [ ] |
| 3.2 | All lifecycle transitions produce expected DB + webhook state | Diff between expected and actual is empty | [ ] |
| 3.3 | Audit report file written to `docs/audit/YYYY-MM-DD-stripe-functionality-test-results.md` | File exists | [ ] |

**Failure handling:** Functional regressions (e.g., proration math wrong, downgrade not deferred) are filed as test failures. Stop the full audit, file the regression, fix, then re-run from Phase 1.

---

## Phase 4: Purchase Matrix Audit

**Run:** `docs/audit-playbooks/stripe-purchase-matrix-playbook.md` end-to-end.

| # | Test | Expected | Status |
|---|------|----------|--------|
| 4.1 | Every subscription price ID in `tiers.json` exercised in test mode | All 6 (3 tiers × monthly/annual) checked off | [ ] |
| 4.2 | Every credit package in `tiers.json` exercised in test mode | All packages checked off | [ ] |
| 4.3 | Referral coupon application path exercised | Coupon issued, applied, `ReferralRewardModel` row written | [ ] |
| 4.4 | Audit report file written to `docs/audit/YYYY-MM-DD-stripe-purchase-matrix-results.md` | File exists | [ ] |

**Failure handling:** Any product that fails to checkout, fails webhook delivery, or fails to update DB state — file as a Functional regression and stop. Do not skip to Phase 5.

---

## Phase 5: Test Coverage Audit

**Run:** `docs/audit-playbooks/stripe-test-coverage-audit-playbook.md` end-to-end. The playbook supports three execution modes (inventory-only / execute / execute + coverage gate); the operator picks the mode at invocation time per the owner's "independently run according to what I ask at the time" directive.

| # | Test | Expected | Status |
|---|------|----------|--------|
| 5.1 | All required Stripe test files exist and contain expected test names | Inventory diff is empty | [ ] |
| 5.2 | Selected mode (inventory / execute / execute+gate) completes without unexpected skips | All declared tests run; no `pytest.skip` slipped in | [ ] |
| 5.3 | Audit report file written to `docs/audit/YYYY-MM-DD-stripe-test-coverage-results.md` | File exists, lists mode used | [ ] |

**Failure handling:** Failing or missing tests block the audit from being marked Pass. File regressions; do not mark this phase complete based on a partial run.

---

## Audit Report Template

Copy this into `docs/audit/YYYY-MM-DD-stripe-full-audit.md` after all five phases complete.

```markdown
# Stripe Full Audit — YYYY-MM-DD

**Auditor:** apogee-full-audit-orchestrator (operator: <name>)
**Scope:** Documentation, security, functionality, purchase matrix, test coverage for the entire Apogee Stripe surface.
**Standards referenced:** see Standards Referenced section of `docs/audit-playbooks/stripe-full-audit-playbook.md`
**Prior audits referenced:** see Prior Audits Referenced section of the same playbook

## Executive Summary
<2–4 sentences: overall pass/fail, headline findings, what changed since the last full audit>

## Phase Outcomes
| Phase | Audit | Status | Report |
|-------|-------|--------|--------|
| 1 | Documentation | [Pass/Fail] | [link] |
| 2 | Security | [Pass/Fail] | [link] |
| 3 | Functionality | [Pass/Fail] | [link] |
| 4 | Purchase Matrix | [Pass/Fail] | [link] |
| 5 | Test Coverage | [Pass/Fail] | [link] |

## Consolidated Findings
- **Critical:** <count + IDs>
- **High:** <count + IDs>
- **Medium:** <count + IDs>
- **Low/Info:** <count + IDs>

## Drift Items Filed
- `TaskDocs-BlockSecOps/<filename>` — <one line>

## Follow-ups
- [ ] <actionable item tied to owner>

## Appendix: Run Metadata
- Operator: <name>
- Cluster: <local | other>
- Stripe mode: test
- Test account: jasonbrailowbizop@mail.com
- Start time: <ISO 8601>
- End time: <ISO 8601>
```

---

## Failure Handling (master)

If any phase fails:
1. Stop. Do not advance to the next phase.
2. File the failure per the per-audit playbook's report format.
3. Fix the root cause (per `apogee-security-audit` "do not patch and resume" rule).
4. Re-run the **full** audit from Phase 1. Partial re-runs invalidate the report.

---

## Related Docs

- `docs/audit-playbooks/stripe-documentation-audit-playbook.md`
- `docs/audit-playbooks/stripe-security-audit-playbook.md`
- `docs/audit-playbooks/stripe-functionality-audit-playbook.md`
- `docs/audit-playbooks/stripe-purchase-matrix-playbook.md`
- `docs/audit-playbooks/stripe-test-coverage-audit-playbook.md`
- `docs/audit-workflows/` (5 workflow audits this playbook depends on)
- `docs/audit-pipelines/` (4 pipeline audits this playbook depends on)
- `docs/.claude/agents/apogee-security-audit.md`
- `docs/.claude/agents/apogee-function-unit-regression-tester.md`
- `docs/.claude/agents/apogee-documentation.md`
- `docs/.claude/agents/tier-agent.md`
