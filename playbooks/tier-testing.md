# Tier Testing Playbook

- **Version:** 1.0.0
- **Last Updated:** March 14, 2026
- **Status:** Active

## Overview

This playbook provides step-by-step instructions for running the BlockSecOps tier test suite. It covers unit tests, integration tests, regression tests, and the production audit script. The source of truth for all tier definitions is always `tiers.json`.

## Running Tests

### Unit Tests (No Dependencies)

Unit tests run against the tier config module directly. No external services are required.

```bash
# Run all tier config validation tests
cd blocksecops-api-service
.venv/bin/pytest tests/unit/test_tier_config_validation.py -v

# Run tier gate enforcement tests
.venv/bin/pytest tests/unit/test_tier_gate_enforcement.py -v

# Run all unit tests together
.venv/bin/pytest tests/unit/ -m unit -v
```

### Integration Tests (Requires Running API + DB)

Integration tests require a running API server and database. Ensure both are available before running.

```bash
# Billing API endpoint tests
cd blocksecops-api-service
.venv/bin/pytest tests/integration/test_billing_api.py -v

# Feature gate access tests (403/200 verification)
.venv/bin/pytest tests/integration/test_feature_gates.py -v

# Quota enforcement tests (402 responses, reset dates)
.venv/bin/pytest tests/integration/test_quota_enforcement.py -v

# Run all integration tests together
.venv/bin/pytest tests/integration/ -m integration -v
```

### Regression Tests

Regression tests verify that billing API responses stay in sync with `tiers.json`.

```bash
# Verify billing plans match tiers.json
cd blocksecops-api-service
.venv/bin/pytest tests/regression/test_billing_plans_match_tiers_json.py -v
```

### Production Audit (133 Assertions)

The audit script verifies production state against `tiers.json`, including database quotas, Stripe subscriptions, and API responses.

```bash
# Run full production audit
cd blocksecops-api-service
.venv/bin/python3 docs/audits/scripts/audit-tier-v4.py
```

## When to Run Each Test Type

```
+-------------------+-----------------------------------------------+
| Event             | Tests to Run                                  |
+-------------------+-----------------------------------------------+
| Every PR          | Unit + Integration (automatic via CI/CD)      |
+-------------------+-----------------------------------------------+
| tiers.json change | Unit + Integration + Regression               |
+-------------------+-----------------------------------------------+
| Pricing update    | Unit + Integration + Regression + Audit       |
+-------------------+-----------------------------------------------+
| Stripe config     | Integration + Regression + Audit              |
| change            |                                               |
+-------------------+-----------------------------------------------+
| Pre-release       | All tests + Audit                             |
+-------------------+-----------------------------------------------+
| Post-deploy       | Audit                                         |
+-------------------+-----------------------------------------------+
| Incident /        | Audit + relevant Integration tests            |
| investigation     |                                               |
+-------------------+-----------------------------------------------+
```

## After Pricing Changes Checklist

Run through this checklist after any change to tier pricing, quotas, features, or Stripe configuration.

- [ ] Updated `tiers.json` with new values
- [ ] Verified Stripe price IDs in `tiers.json` match Stripe dashboard
- [ ] Ran unit tests -- all pass

```bash
.venv/bin/pytest tests/unit/test_tier_config_validation.py -v
```

- [ ] Ran integration tests -- all pass

```bash
.venv/bin/pytest tests/integration/test_billing_api.py -v
.venv/bin/pytest tests/integration/test_feature_gates.py -v
.venv/bin/pytest tests/integration/test_quota_enforcement.py -v
```

- [ ] Ran regression tests -- billing plans match `tiers.json`

```bash
.venv/bin/pytest tests/regression/test_billing_plans_match_tiers_json.py -v
```

- [ ] Deployed changes to staging
- [ ] Ran production audit against staging

```bash
.venv/bin/python3 docs/audits/scripts/audit-tier-v4.py
```

- [ ] Verified GET /billing/plans returns updated pricing
- [ ] Verified existing subscribers are unaffected (or migrated as intended)
- [ ] Verified Stripe webhook processing works for new price IDs
- [ ] Deployed to production
- [ ] Ran production audit against production

```bash
.venv/bin/python3 docs/audits/scripts/audit-tier-v4.py
```

- [ ] Confirmed dashboard displays correct pricing

## Troubleshooting

### Unit tests fail on tier config structure

The tier config module may be out of sync with `tiers.json`. Verify that `blocksecops_tier_config` loads from the correct `tiers.json` path.

### Integration tests return connection errors

Ensure the API server and database are running. Check that the test configuration points to the correct API URL and database connection string.

### Regression tests show pricing drift

The billing API is returning prices that do not match `tiers.json`. This usually means a deployment is needed to pick up `tiers.json` changes, or the API is caching stale values.

### Audit script reports Stripe mismatches

Compare the Stripe price IDs in `tiers.json` with the Stripe dashboard. Ensure that price IDs have not been archived or replaced in Stripe without updating `tiers.json`.

## Related Documentation

- [Tier Purchasing Workflow](../workflows/tier-purchasing-workflow.md)
- [Tier Upgrading Workflow](../workflows/tier-upgrading-workflow.md)
- [Tier Testing Pipeline](../pipelines/tier-testing-pipeline.md)
- `tiers.json` -- source of truth for all tier definitions
