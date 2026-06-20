# API Service v0.44.8 — BSO-SEC-021 Fix (Open Redirect on Billing Endpoints)

**Date:** 2026-06-19
**Author:** Apogee Team
**Services Affected:** api-service
**Version:** 0.44.3 -> 0.44.8
**Security Finding:** BSO-SEC-021 (HIGH) — Open redirect on `/api/v1/billing/portal` and `/api/v1/billing/checkout`
**Audit Reference:** `docs/audit/2026-05-09-stripe-security-audit.md`

## Summary

Resolved the HALT-triggering HIGH-severity finding from the 2026-05-09 Stripe security audit. The private `_validate_redirect_url` helper in `payments.py` has been promoted to a public shared function in `src/infrastructure/security/url_validation.py` and applied to the three previously-unvalidated URL parameters in `billing.py`. This closes the open-redirect attack chain on Stripe-hosted phishing redirects.

## Root Cause (from BSO-SEC-021)

The BSO-SEC-014 fix had introduced `_validate_redirect_url()` in `payments.py` to protect the credit-purchase checkout endpoint (`/api/v1/payments/checkout/stripe`). That fix was never propagated to the sibling billing endpoints added later:

- `POST /api/v1/billing/checkout` — `success_url` and `cancel_url` (body fields)
- `POST /api/v1/billing/portal` — `return_url` (query parameter)

All three parameters were passed directly to Stripe's SDK (`stripe.checkout.Session.create`, `stripe.billing_portal.Session.create`) without origin validation. Stripe would redirect the authenticated user's browser to whatever URL was supplied after the portal or checkout flow completed.

## Changes

### 1. New shared helper in `url_validation.py`

**File:** `src/infrastructure/security/url_validation.py`

Added public function `validate_redirect_url(url, allowed_origins)`. The function:
- Accepts a URL string and an allowlist of origin strings
- Rejects `javascript:`, `data:`, and `vbscript:` schemes unconditionally
- Validates the URL's origin (scheme + host) against the allowlist
- Returns `True` if allowed, `False` otherwise

The old private `_validate_redirect_url` helper in `payments.py` now imports and calls this shared function.

### 2. Validation applied in `billing.py`

**File:** `src/presentation/api/v1/endpoints/billing.py`

Applied `validate_redirect_url` to all three URL parameters using the same `allowed_origins = settings.cors_origins + [settings.dashboard_base_url]` allowlist pattern that BSO-SEC-014 established in `payments.py`:

| Endpoint | Parameter | Response on failure |
|----------|-----------|---------------------|
| `POST /api/v1/billing/checkout` | `success_url` | HTTP 400 — "Invalid success_url: origin not allowed" |
| `POST /api/v1/billing/checkout` | `cancel_url` | HTTP 400 — "Invalid cancel_url: origin not allowed" |
| `POST /api/v1/billing/portal` | `return_url` | HTTP 400 — "Invalid return_url: origin not allowed" |

### 3. `payments.py` refactored to use shared helper

**File:** `src/presentation/api/v1/endpoints/payments.py`

Removed the private `_validate_redirect_url` function (was the BSO-SEC-014 implementation). Updated `create_stripe_credit_checkout` to import and call `validate_redirect_url` from `url_validation.py`. Behavior is unchanged.

### 4. Version bump

- `pyproject.toml`: `0.44.3` -> `0.44.8`
- `k8s/overlays/gcp/kustomization.yaml`: image tag `0.44.3` -> `0.44.8`, `app.kubernetes.io/version` `0.44.3` -> `0.44.8`

## Files Modified

| File | Change |
|------|--------|
| `pyproject.toml` | Version bump 0.44.3 -> 0.44.8 |
| `k8s/overlays/gcp/kustomization.yaml` | Image tag + version label bump |
| `src/infrastructure/security/url_validation.py` | Added public `validate_redirect_url(url, allowed_origins)` (~20 lines) |
| `src/presentation/api/v1/endpoints/billing.py` | Applied `validate_redirect_url` to `success_url`, `cancel_url`, `return_url` |
| `src/presentation/api/v1/endpoints/payments.py` | Removed private `_validate_redirect_url`, now imports shared helper |

## Still Open from the 2026-05-09 Stripe Audit

The following findings from the same audit are NOT addressed in this release and remain open:

| Finding | Severity | Description |
|---------|----------|-------------|
| BSO-SEC-022 | MEDIUM | `UserModel.stripe_customer_id` lacks UNIQUE constraint at DB layer |
| BSO-SEC-023 | LOW | Stripe webhook endpoint has no rate limit |
| BSO-SEC-024 | MEDIUM | No event-level idempotency for subscription webhook events |

BSO-SEC-022 requires an Alembic migration with a pre-migration duplicate-detection query. BSO-SEC-024 requires creating a `stripe_event_log` table. Both need separate scheduling and planning.

## Audit Re-run Required

Per `docs/audit-playbooks/stripe-security-audit-playbook.md` failure-handling rules, the full audit must be re-run from Phase 1 after this fix. Phases 5–7 (secret hygiene, tenant isolation live probes, audit-log review) were not formally executed in the 2026-05-09 run.
