# API Service v0.28.21 - Consent Router Registration

**Date:** February 13, 2026
**Component:** blocksecops-api-service
**Type:** Bug Fix
**Priority:** High
**Status:** Complete

---

## Summary

The consent endpoint module (`consent.py`) was fully implemented — router, schemas, database model, and migration — but was never imported or registered in `main.py`. This caused a 404 on `/api/v1/consent/current`, which the dashboard's `ProtectedRoute` component calls on every page load.

## Root Cause

The consent module was created during Phase 1 (Legal Foundation, January 2026) with:
- `src/presentation/api/v1/endpoints/consent.py` — 4 endpoints
- `src/presentation/schemas/consent.py` — request/response schemas
- `src/infrastructure/database/models.py` — `TosConsentModel`
- Database migration creating `tos_consent_records` table

However, the import and `app.include_router()` call were never added to `src/main.py`.

## Changes Made

### `src/main.py`

Added import:
```python
from src.presentation.api.v1.endpoints import (
    ...
    consent,
    ...
)
```

Added router registration:
```python
app.include_router(consent.router, prefix="/api/v1", tags=["consent"])
```

## Consent Endpoints Now Available

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/consent/versions` | Public | Get current ToS and Privacy Policy version numbers |
| `GET` | `/consent/current` | JWT | Get user's current consent status and re-consent requirements |
| `POST` | `/consent/tos` | JWT | Record ToS and Privacy Policy consent |
| `POST` | `/consent/withdraw-ml` | JWT | Withdraw ML data collection consent |

### Current Document Versions

```
ToS: 2026.01.1
Privacy Policy: 2026.01.1
```

## Files Modified

| File | Change |
|------|--------|
| `src/main.py` | Added consent import and router registration |
| `pyproject.toml` | Version bump 0.28.20 → 0.28.21 |
| `k8s/overlays/local/api-service/kustomization.yaml` | newTag 0.28.20 → 0.28.21 |

## Verification

```bash
# Public endpoint (no auth required)
curl -sk https://app.0xapogee.local/api/v1/consent/versions
# Returns: {"tos_version":"2026.01.1","privacy_policy_version":"2026.01.1",...}

# Authenticated endpoint (requires JWT)
# Dashboard ProtectedRoute calls /consent/current on every page load
# No more 404 in browser console
```

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.28.20 | 2026-02-12 | Previous version (consent endpoints unreachable) |
| 0.28.21 | 2026-02-13 | Register consent router in main.py |
