# API Service v0.29.22 - Webhook Rate Limit Fix

**Date:** February 24, 2026
**Version:** 0.29.22
**Type:** Fix (PATCH)
**PR:** #257

## Summary

Hotfix for webhook GET endpoints returning 500 after rate limiting was added in v0.29.21. The slowapi rate limiter requires a `response: Response` parameter to inject rate limit headers into the response.

## Root Cause

Fix 16 in v0.29.21 added `@limiter.limit("30/minute")` to three webhook GET endpoints but did not add the required `response: Response` parameter. slowapi raises `parameter 'response' must be an instance of starlette.responses.Response` when this parameter is missing.

## Changes

- Added `response: Response` parameter to `list_webhooks()`, `get_webhook()`, and `get_webhook_deliveries()`

## Files Modified

- `src/presentation/api/v1/endpoints/webhooks.py` (3 lines added)
- `pyproject.toml` (0.29.21 -> 0.29.22)
- `k8s/overlays/local/api-service/kustomization.yaml` (0.29.21 -> 0.29.22)

## Verification

Authenticated smoke test confirmed all webhook endpoints return 200 after fix.
