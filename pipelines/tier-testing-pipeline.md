# Tier Testing Pipeline

- **Version:** 1.0.0
- **Last Updated:** March 14, 2026
- **Status:** Active

## Overview

This document describes the test infrastructure for the BlockSecOps tier system. Tests are organized into unit, integration, and regression layers, plus a production audit script. The source of truth for all tier definitions is always `tiers.json`.

## Test Architecture

```
+-----------------------------------------------------------------------+
|                        CI/CD Pipeline                                 |
|                  .github/workflows/test.yml                           |
|                  (runs on every PR)                                   |
+-----------------------------------------------------------------------+
         |                    |                    |
         v                    v                    v
+-------------------+ +-------------------+ +-------------------+
|   Unit Tests      | | Integration Tests | | Regression Tests  |
|   @pytest.mark    | | @pytest.mark      | | drift detection   |
|     .unit         | |   .integration    | |                   |
+-------------------+ +-------------------+ +-------------------+
| test_tier_config_ | | test_billing_     | | test_billing_     |
|   validation.py   | |   api.py          | |   plans_match_    |
| test_tier_gate_   | | test_feature_     | |   tiers_json.py   |
|   enforcement.py  | |   gates.py        | |                   |
|                   | | test_quota_       | |                   |
|                   | |   enforcement.py  | |                   |
+-------------------+ +-------------------+ +-------------------+
                                                    |
                              +---------------------+
                              v
                  +-------------------------+
                  |   Production Audit      |
                  |   audit-tier-v4.py      |
                  |   (133 assertions)      |
                  |   manual / scheduled    |
                  +-------------------------+
```

## Unit Tests

### tests/unit/test_tier_config_validation.py

- **Marker:** `@pytest.mark.unit`
- **Dependencies:** None (no external services required)
- **Source:** Reads from `blocksecops_tier_config`
- **Validates:**
  - Tier config structure is well-formed
  - All required fields are present for each tier
  - Quotas are defined and have valid numeric values
  - Pricing fields are present and consistent
  - Features are correctly listed per tier
  - Stripe price IDs are present and follow expected format
  - Rate limits are defined and within acceptable ranges
  - Tier ordering is consistent (free < starter < growth < business < enterprise)

### tests/unit/test_tier_gate_enforcement.py (Existing)

- **Marker:** `@pytest.mark.unit`
- **Dependencies:** None
- **Validates:**
  - `require_tier()` decorators are applied to all tier-gated endpoints
  - Decorator arguments reference valid tier names
  - Structural checks ensure no endpoints are left unprotected

## Integration Tests

### tests/integration/test_billing_api.py

- **Marker:** `@pytest.mark.integration`
- **Dependencies:** Running API server, database
- **Validates:**
  - Billing endpoints return correct HTTP status codes
  - Quota fields are present and correctly typed in responses
  - Plan limits match expectations from `tiers.json`
  - Checkout session creation returns valid Stripe session URLs
  - Subscription endpoints return current tier and billing details

### tests/integration/test_feature_gates.py

- **Marker:** `@pytest.mark.integration`
- **Dependencies:** Running API server, database
- **Validates:**
  - Tier-gated endpoints return 403 for users below the required tier
  - Tier-gated endpoints return 200 for users at or above the required tier
  - Feature access changes immediately after tier upgrade or downgrade
  - Free tier users cannot access paid features

### tests/integration/test_quota_enforcement.py (Existing)

- **Marker:** `@pytest.mark.integration`
- **Dependencies:** Running API server, database
- **Validates:**
  - Quota exceeded returns 402 Payment Required
  - Quota reset dates are correctly calculated and returned
  - Usage counters increment properly
  - Quota limits match the values defined in `tiers.json`

## Regression Tests

### tests/regression/test_billing_plans_match_tiers_json.py

- **Purpose:** Catches drift between billing API responses and `tiers.json`
- **Dependencies:** Running API server
- **Validates:**
  - GET /billing/plans returns pricing that exactly matches `tiers.json`
  - All tiers defined in `tiers.json` appear in the billing plans response
  - No extra or missing tiers in the API response
  - Stripe price IDs in API responses match `tiers.json`

## Production Audit

### docs/audits/scripts/audit-tier-v4.py

- **Assertions:** 133
- **Execution:** Manual or scheduled (not part of CI/CD)
- **Validates:**
  - Database quotas match `tiers.json` for all active users
  - Stripe subscriptions match user tier assignments
  - API endpoint responses match expected tier behavior
  - No orphaned subscriptions or mismatched tiers
  - Rate limits enforced correctly per tier
  - All feature gates functioning in production

## CI/CD Configuration

The test pipeline is defined in `.github/workflows/test.yml` and runs on every pull request.

```
+---------------------------+
|  PR opened / updated      |
+---------------------------+
            |
            v
+---------------------------+
|  Checkout code            |
+---------------------------+
            |
            v
+---------------------------+
|  Install dependencies     |
+---------------------------+
            |
      +-----+-----+
      |           |
      v           v
+----------+ +---------------+
| Unit     | | Integration   |
| tests    | | tests         |
| (fast,   | | (requires     |
|  no deps)| |  API + DB)    |
+----------+ +---------------+
      |           |
      +-----+-----+
            |
            v
+---------------------------+
|  Report results           |
+---------------------------+
```

### Test Execution Summary

```
+-----------------------------------------+----------+---------------+-----------+
| Test File                               | Marker   | Dependencies  | CI/CD     |
+-----------------------------------------+----------+---------------+-----------+
| test_tier_config_validation.py          | unit     | None          | Yes       |
| test_tier_gate_enforcement.py           | unit     | None          | Yes       |
| test_billing_api.py                     | integr.  | API + DB      | Yes       |
| test_feature_gates.py                   | integr.  | API + DB      | Yes       |
| test_quota_enforcement.py               | integr.  | API + DB      | Yes       |
| test_billing_plans_match_tiers_json.py  | regress. | API           | Yes       |
| audit-tier-v4.py                        | --       | Production    | No        |
+-----------------------------------------+----------+---------------+-----------+
```

## Related Documentation

- [Tier Purchasing Workflow](../workflows/tier-purchasing-workflow.md)
- [Tier Upgrading Workflow](../workflows/tier-upgrading-workflow.md)
- [Tier Testing Playbook](../playbooks/tier-testing.md)
- `tiers.json` -- source of truth for all tier definitions
