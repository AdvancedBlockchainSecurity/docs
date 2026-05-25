# Stripe Test Coverage Audit Playbook

**Version:** 1.0.0
**Last Updated:** 2026-04-24
**Status:** Active
**Purpose:** Reusable, end-to-end audit of Stripe-related unit, regression, and feature tests across `blocksecops-api-service`, `blocksecops-dashboard`, and `blocksecops-shared/tier-config`.
**Audience:** Operator (owner) — picks an execution mode at invocation time, then follows this procedure
**Audit Type:** test-coverage

---

## ⚠️ Mandatory End-to-End Execution

**This audit MUST be run from beginning to end without skipping any phase, even if it was executed recently.** Each phase produces evidence the next phase depends on. Skipping invalidates the audit report. If a phase fails, fix the underlying issue and re-run **from Phase 1** — do not patch and resume mid-audit.

When the owner says "run the Stripe test coverage audit," every phase below runs.

---

## Execution Modes (operator selects at invocation)

Per the owner's "independently run according to what I ask at the time" directive, this playbook supports three modes. The operator declares the mode in the audit report.

| Mode | What runs | When to use |
|------|-----------|-------------|
| **A — inventory** | Phases 1–3 only (file inventory + cross-check + diff). No tests executed. | Quick coverage drift check; CI is trusted to run the suites elsewhere. |
| **B — execute** | Phases 1–4: inventory + execute pytest/vitest/regression suites. | Standard audit; want proof the tests pass against current code. |
| **C — execute + coverage gate** | Phases 1–5: B plus enforce coverage thresholds (≥75% general, ≥80% ML per `apogee-function-unit-regression-tester.md`). | Most thorough; required before claiming "test audit Pass." |

Phases 1–3 are **always run** regardless of mode. Phases 4 and 5 are gated by mode.

---

## Overview

This playbook orchestrates a Stripe-scoped test audit using the `apogee-function-unit-regression-tester` agent (see `docs/.claude/agents/apogee-function-unit-regression-tester.md`). The agent's rules apply unchanged: real PostgreSQL (no DB mocks per memory `feedback_local_not_gcp.md`), local cluster only, `127.0.0.1` (not `localhost`).

Output goes to `docs/audit/YYYY-MM-DD-stripe-test-coverage-results.md`.

---

## Prerequisites

- [ ] Cluster reachable via ingress per `docs/standards/service-availability.md`
- [ ] Local PostgreSQL reachable; `solidity_security` DB schema current per `docs/database/SCHEMA.md`
- [ ] DB backup created per `docs/standards/database-management.md` (Mode B and C write to DB)
- [ ] Owner approval to invoke `apogee-function-unit-regression-tester` agent (Rule 0)
- [ ] Mode (A / B / C) selected by owner
- [ ] Pods restarted after any code pull (Rule 3)

---

## Standards Referenced

- `docs/standards/testing-deployment.md`
- `docs/standards/core-development-rules.md` — Rule 3 (pod restart)
- `docs/standards/database-management.md` — backup before writes
- `docs/standards/api-endpoint-auth.md` — write endpoints must use `require_auth_with_scope()` (regression covered)
- `docs/standards/tier-standards.md`
- `docs/standards/INDEX.md`

---

## Prior Audits Referenced

- `docs/audits/test-coverage.md`
- `docs/audits/2026-04-21-scanner-e2e-matrix-full-0.43.0.md` — canonical scanner E2E matrix format
- `docs/audits/2026-04-15-scanner-e2e-matrix-full-0.37.3.md`
- `docs/audits/2026-02-16_Go_Live_Audit_Test_Results.md`
- `docs/audits/2026-02-24-load-test-results.md` — performance baseline
- The most recent `docs/audit/YYYY-MM-DD-stripe-test-coverage-results.md` — diff baseline

---

## Phase 1: Required Test File Inventory (always)

### 1.1 Confirm required test files exist

| # | File | Required tests | Status |
|---|------|----------------|--------|
| 1.1.1 | `blocksecops-api-service/tests/security/test_stripe_webhook_security.py` | signature missing/malformed/wrong-secret, replay, metadata fuzzing, tier escalation, ownership, idempotency | [ ] |
| 1.1.2 | `blocksecops-api-service/tests/regression/test_stripe_webhook_regression.py` | event handler behavior, DB state, tier changes | [ ] |
| 1.1.3 | `blocksecops-api-service/tests/unit/infrastructure/test_config.py` | Stripe secret validation, env loading, `stripe_webhook_secret` required-in-prod assertion | [ ] |
| 1.1.4 | `blocksecops-dashboard` billing component vitest files (`src/components/billing/__tests__/`) | Provider render, billing API client error handling, plan-limit display | [ ] |
| 1.1.5 | `blocksecops-shared/tier-config/python/blocksecops_tier_config/` test module | `get_stripe_price_ids`, `get_tier_by_stripe_price_id`, `get_credit_packages` | [ ] |

**Verification:** `docs/audit-pipelines/stripe-test-suite-pipeline.md` Phase 1 commands.

**Evidence to capture:** File list with `ls`, test count per file via `pytest --collect-only -q` and `vitest --reporter=list --run`.

---

## Phase 2: Cross-check Against Feature Tests (always)

### 2.1 Documented feature tests vs implemented tests

| # | Test | Expected | Status |
|---|------|----------|--------|
| 2.1.1 | Each scenario in `docs/feature-tests/37-stripe-billing.md` has at least one corresponding test | Mapping table produced; gaps filed | [ ] |
| 2.1.2 | Each scenario in `docs/feature-tests/52-dual-payment-options.md` has at least one corresponding test | Same | [ ] |
| 2.1.3 | Each phase in `stripe-functionality-audit-playbook.md` has at least one supporting test | Same | [ ] |
| 2.1.4 | Each phase in `stripe-security-audit-playbook.md` has at least one supporting test | Same | [ ] |

**Evidence to capture:** Mapping table (feature-test scenario → pytest/vitest test name).

---

## Phase 3: Diff Against Last Baseline (always)

### 3.1 Regression diff

| # | Test | Expected | Status |
|---|------|----------|--------|
| 3.1.1 | Inventory diff vs the most recent `docs/audit/*-stripe-test-coverage-results.md` | New tests added; no tests silently removed | [ ] |
| 3.1.2 | If tests removed, ticket exists in `TaskDocs-BlockSecOps/` justifying removal | Documented justification | [ ] |
| 3.1.3 | New `pytest.skip` or `it.skip` calls compared to baseline | Each new skip justified | [ ] |

**Evidence to capture:** Diff of test names; list of new/removed/skipped tests.

---

## Phase 4: Execute Suites (Mode B and C)

### 4.1 Run pytest

| # | Test | Expected | Status |
|---|------|----------|--------|
| 4.1.1 | `pytest tests/security/test_stripe_webhook_security.py -v` | All pass; no unexpected skips | [ ] |
| 4.1.2 | `pytest tests/regression/test_stripe_webhook_regression.py -v` | All pass | [ ] |
| 4.1.3 | `pytest tests/unit/infrastructure/test_config.py -v` | All pass | [ ] |
| 4.1.4 | Real PostgreSQL used (no DB mock) per agent rules | Verified by inspecting fixture setup | [ ] |

### 4.2 Run vitest

| # | Test | Expected | Status |
|---|------|----------|--------|
| 4.2.1 | `vitest run src/components/billing/__tests__/` | All pass | [ ] |
| 4.2.2 | `vitest run src/lib/api/__tests__/billing.test.ts` (if present) | All pass | [ ] |

### 4.3 Tier-config tests

| # | Test | Expected | Status |
|---|------|----------|--------|
| 4.3.1 | `pytest blocksecops-shared/tier-config/python/tests/` | All pass | [ ] |

**Evidence to capture:** pytest summary, vitest summary, full output stored at evidence path.

---

## Phase 5: Coverage Gate (Mode C only)

### 5.1 Coverage thresholds

| # | Test | Expected | Status |
|---|------|----------|--------|
| 5.1.1 | API-service Stripe modules ≥ 75% line coverage | Threshold met | [ ] |
| 5.1.2 | Dashboard billing components ≥ 75% line coverage | Threshold met | [ ] |
| 5.1.3 | Tier-config Stripe helpers ≥ 80% (per ML floor analogue used by agent) | Threshold met | [ ] |
| 5.1.4 | Coverage report stored at `docs/audit/YYYY-MM-DD-stripe-coverage-report.html` (or txt) | File exists | [ ] |

**Evidence to capture:** Coverage report file path and key percentages.

---

## Audit Report Template

Copy this into `docs/audit/YYYY-MM-DD-stripe-test-coverage-results.md`.

```markdown
# Stripe Test Coverage Results — YYYY-MM-DD

**Author:** apogee-function-unit-regression-tester
**Mode:** A (inventory) | B (execute) | C (execute + coverage gate)
**Scope:** Stripe unit + regression + feature tests across api-service, dashboard, tier-config. Local cluster only. Real PostgreSQL.
**Standards referenced:** see Standards Referenced section of `docs/audit-playbooks/stripe-test-coverage-audit-playbook.md`

## Executive Summary
<2–4 sentences>

## Phase-by-phase Results
| Phase | Mode A | Mode B | Mode C | Outcome |
|-------|--------|--------|--------|---------|
| 1 Inventory | required | required | required | Pass/Fail |
| 2 Feature-test cross-check | required | required | required | Pass/Fail |
| 3 Baseline diff | required | required | required | Pass/Fail |
| 4 Execute suites | skipped | required | required | Pass/Fail |
| 5 Coverage gate | skipped | skipped | required | Pass/Fail |

## Inventory Diff vs Last Baseline
- New tests: <count and names>
- Removed tests: <count, names, justification ticket>
- Newly skipped tests: <count, names, justification>

## Coverage Numbers (Mode C)
| Surface | Coverage |
|---------|----------|
| API-service Stripe modules | XX% |
| Dashboard billing components | XX% |
| Tier-config Stripe helpers | XX% |

## Regressions
- <pass→fail compared to prior baseline>

## Bugs Discovered
- <file to TaskDocs-BlockSecOps/>

## Follow-ups
- [ ] <actionable item tied to owner>
```

---

## Failure Handling

If any phase fails:
1. Stop. Do not advance.
2. File the regression with file:line and the offending commit/image tag.
3. Fix the root cause; do not adjust tests to make them pass.
4. Re-run the **full** audit from Phase 1.
5. Per agent rules: if a code path cannot be tested locally, **say so explicitly** in the report — do not claim Pass.

---

## Related Docs

- `docs/audit-playbooks/stripe-full-audit-playbook.md` — orchestrator
- `docs/audit-pipelines/stripe-test-suite-pipeline.md` — exact commands per phase
- `docs/.claude/agents/apogee-function-unit-regression-tester.md`
- `docs/feature-tests/37-stripe-billing.md`
- `docs/feature-tests/52-dual-payment-options.md`
- `docs/playbooks/tier-testing.md`
- `docs/pipelines/tier-testing-pipeline.md`
