# Stripe Test Suite Pipeline

**Version:** 1.0.0
**Last Updated:** 2026-04-24
**Status:** Active
**Purpose:** Sequenced technical/automation steps that the test coverage audit playbook orchestrates — exact pytest/vitest selection, real-PostgreSQL fixture setup, regression matrix diff against the most recent baseline.
**Audience:** `apogee-function-unit-regression-tester` agent + operator
**Audit Type:** test-coverage (technical sequence)

---

## ⚠️ Mandatory End-to-End Execution

**This pipeline MUST be executed from beginning to end without skipping any step, even if it was run recently.** Each step's output (test counts, coverage numbers, diff results) feeds the next. Skipping invalidates results. If a step fails, fix the underlying issue and re-run **from Phase 1** of `docs/audit-playbooks/stripe-test-coverage-audit-playbook.md`.

---

## Overview

This pipeline is the technical companion to `docs/audit-playbooks/stripe-test-coverage-audit-playbook.md`. It supports the playbook's three execution modes (A inventory / B execute / C execute + coverage gate); the operator selects the mode at invocation time per the owner's directive.

Local cluster only (per `feedback_local_not_gcp.md`). Real PostgreSQL fixtures only — no DB mocks (per `apogee-function-unit-regression-tester` agent definition). Endpoints `127.0.0.1` (not `localhost`) per agent definition.

---

## Prerequisites

See `docs/audit-playbooks/stripe-test-coverage-audit-playbook.md` Prerequisites. Plus:

- [ ] Python venv active in `blocksecops-api-service` and `blocksecops-shared/tier-config/python`
- [ ] `npm install` completed in `blocksecops-dashboard` (vitest available)
- [ ] DB backup created per `database-management.md` (Modes B and C write fixtures)
- [ ] Pods restarted after any code pull (Rule 3)

---

## Standards Referenced

- `docs/standards/testing-deployment.md`
- `docs/standards/core-development-rules.md` (Rule 3)
- `docs/standards/database-management.md`
- `docs/standards/api-endpoint-auth.md` (regression for `require_auth_with_scope` on write endpoints)
- `docs/standards/INDEX.md`

---

## Prior Audits Referenced

- `docs/audits/test-coverage.md`
- `docs/audits/2026-04-21-scanner-e2e-matrix-full-0.43.0.md`
- The most recent `docs/audit/YYYY-MM-DD-stripe-test-coverage-results.md` — diff baseline

---

## Phase 1 — Test File Inventory (always)

```bash
# 1.1.1 Security tests
ls -la /home/pwner/Git/blocksecops-api-service/tests/security/test_stripe_webhook_security.py
cd /home/pwner/Git/blocksecops-api-service
pytest tests/security/test_stripe_webhook_security.py --collect-only -q

# 1.1.2 Regression tests
ls -la tests/regression/test_stripe_webhook_regression.py
pytest tests/regression/test_stripe_webhook_regression.py --collect-only -q

# 1.1.3 Config unit tests
ls -la tests/unit/infrastructure/test_config.py
pytest tests/unit/infrastructure/test_config.py --collect-only -q | grep -i stripe

# 1.1.4 Dashboard billing vitest
cd /home/pwner/Git/blocksecops-dashboard
npx vitest list src/components/billing/__tests__/

# 1.1.5 Tier-config Stripe helpers
cd /home/pwner/Git/blocksecops-shared/tier-config/python
pytest tests/ --collect-only -q | grep -E "stripe|price|credit"
```

**Capture:** Test file paths and per-file test counts.

---

## Phase 2 — Cross-check Against Feature Tests (always)

```bash
# 2.1 Build a mapping table
echo "=== docs/feature-tests/37-stripe-billing.md scenarios ==="
grep -nE "^##|^- \[ \]|^- \[x\]" /home/pwner/Git/docs/feature-tests/37-stripe-billing.md

echo "=== docs/feature-tests/52-dual-payment-options.md scenarios ==="
grep -nE "^##|^- \[ \]|^- \[x\]" /home/pwner/Git/docs/feature-tests/52-dual-payment-options.md

echo "=== Implemented test names containing stripe/billing/credit ==="
cd /home/pwner/Git/blocksecops-api-service
pytest tests/ --collect-only -q 2>/dev/null | grep -iE "stripe|billing|credit|webhook"
```

Operator manually maps each scenario → at least one test name. Gaps are filed as drift.

**Capture:** Mapping table (scenario → test name); list of unmapped scenarios.

---

## Phase 3 — Diff Against Last Baseline (always)

```bash
# 3.1 Locate prior baseline
PRIOR=$(ls -1t /home/pwner/Git/docs/audit/*-stripe-test-coverage-results.md 2>/dev/null | head -1)
echo "Prior baseline: $PRIOR"

# 3.2 Extract prior test name list (assumes baseline embedded a list)
grep -E "^- " "$PRIOR" > /tmp/prior_tests.txt 2>/dev/null || echo "No prior baseline (first run)"

# 3.3 Current test name list
cd /home/pwner/Git/blocksecops-api-service
pytest tests/ --collect-only -q 2>/dev/null | grep -iE "stripe|billing|credit|webhook" > /tmp/current_tests.txt

# 3.4 Diff
diff /tmp/prior_tests.txt /tmp/current_tests.txt | tee /tmp/test_diff.txt

# 3.5 Skipped tests
grep -rEn "@pytest.mark.skip|pytest.skip|it.skip" \
  /home/pwner/Git/blocksecops-api-service/tests/security/ \
  /home/pwner/Git/blocksecops-api-service/tests/regression/ \
  /home/pwner/Git/blocksecops-api-service/tests/unit/infrastructure/ \
  | grep -iE "stripe|billing|credit"
```

**Capture:** Diff output; new/removed test lists; new skip annotations.

---

## Phase 4 — Execute Suites (Mode B and C)

### 4.1 pytest

```bash
cd /home/pwner/Git/blocksecops-api-service

# Real PostgreSQL fixture (no mock)
export DATABASE_URL="postgresql+asyncpg://blocksecops:<password>@127.0.0.1:5432/solidity_security"

pytest tests/security/test_stripe_webhook_security.py -v --tb=short 2>&1 | tee /tmp/pytest_security.log
pytest tests/regression/test_stripe_webhook_regression.py -v --tb=short 2>&1 | tee /tmp/pytest_regression.log
pytest tests/unit/infrastructure/test_config.py -v --tb=short 2>&1 | tee /tmp/pytest_config.log

# Verify no DB mocks slipped in (per agent rules)
grep -rEn "Mock|MagicMock|patch.*[Dd]atabase" \
  /home/pwner/Git/blocksecops-api-service/tests/security/test_stripe_webhook_security.py \
  /home/pwner/Git/blocksecops-api-service/tests/regression/test_stripe_webhook_regression.py
# Expected: zero matches (mocks only at Stripe/Supabase boundaries, NOT DB)
```

### 4.2 vitest

```bash
cd /home/pwner/Git/blocksecops-dashboard
npx vitest run src/components/billing/__tests__/ --reporter=verbose 2>&1 | tee /tmp/vitest_billing.log
[ -d src/lib/api/__tests__ ] && \
  npx vitest run src/lib/api/__tests__/billing.test.ts --reporter=verbose 2>&1 | tee /tmp/vitest_billing_api.log
```

### 4.3 Tier-config

```bash
cd /home/pwner/Git/blocksecops-shared/tier-config/python
pytest tests/ -v --tb=short 2>&1 | tee /tmp/pytest_tier_config.log
```

**Capture:** Per-file pytest/vitest summary; full logs at `/tmp/*.log` (or moved to evidence path).

---

## Phase 5 — Coverage Gate (Mode C only)

```bash
# 5.1 API-service coverage
cd /home/pwner/Git/blocksecops-api-service
pytest tests/ \
  --cov=src/application/services/stripe_service \
  --cov=src/presentation/api/v1/endpoints/stripe_webhook \
  --cov=src/presentation/api/v1/endpoints/billing \
  --cov=src/presentation/api/v1/endpoints/payments \
  --cov-report=term --cov-report=html:/tmp/cov_api 2>&1 | tail -40
# Threshold: ≥ 75%

# 5.2 Dashboard coverage
cd /home/pwner/Git/blocksecops-dashboard
npx vitest run src/components/billing/ --coverage 2>&1 | tail -40
# Threshold: ≥ 75%

# 5.3 Tier-config coverage
cd /home/pwner/Git/blocksecops-shared/tier-config/python
pytest tests/ --cov=blocksecops_tier_config --cov-report=term 2>&1 | tail -30
# Threshold: ≥ 80%
```

**Capture:** Coverage percentages; HTML report path; threshold pass/fail per surface.

---

## Output

Pipeline does not produce its own report. Evidence captured here is consumed by `stripe-test-coverage-audit-playbook.md` and embedded in `docs/audit/YYYY-MM-DD-stripe-test-coverage-results.md`.

---

## Failure Handling

If any step fails:
1. Stop the pipeline.
2. Record the failure with file:line and the offending commit/image tag.
3. Per agent rules: do not adjust tests to make them pass; fix the underlying code.
4. Per agent rules: if a code path cannot be tested locally, **say so explicitly** in the report — do not claim Pass.
5. Route to `stripe-test-coverage-audit-playbook.md` Failure Handling.

---

## Related Docs

- `docs/audit-playbooks/stripe-test-coverage-audit-playbook.md`
- `docs/.claude/agents/apogee-function-unit-regression-tester.md`
- `docs/feature-tests/37-stripe-billing.md`
- `docs/feature-tests/52-dual-payment-options.md`
- `docs/playbooks/tier-testing.md`
- `docs/pipelines/tier-testing-pipeline.md`
