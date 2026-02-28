# API Service v0.27.7 - Dependencies Endpoint

## Version 0.27.7 - February 7, 2026

**Date:** 2026-02-07
**Component:** blocksecops-api-service (0.27.6 -> 0.27.7)
**Type:** Feature
**Priority:** Low
**Status:** Complete

### Summary

Added `GET /admin/dependencies` endpoint that reports installed Python package versions versus latest available on PyPI, plus platform service versions from internal health endpoints. This powers the admin portal Dependencies page.

### Added

- **`GET /api/v1/admin/dependencies`** — Returns dependency version information:
  - Uses `importlib.metadata` for installed Python package versions (26 key packages)
  - Queries PyPI JSON API concurrently for latest versions
  - 1-hour in-memory cache to avoid excessive PyPI requests
  - 5-second timeout per PyPI request
  - Reports platform service versions from internal health endpoints
  - Requires `support_admin` role minimum

- **Response Model:**
  ```json
  {
    "dependencies": [
      {
        "service": "api-service",
        "name": "fastapi",
        "current_version": "0.115.6",
        "latest_version": "0.115.8"
      },
      {
        "service": "orchestration",
        "name": "orchestration",
        "current_version": "0.9.10",
        "latest_version": "0.9.10"
      }
    ]
  }
  ```

- **Tracked Python Packages (26):**
  fastapi, uvicorn, pydantic, sqlalchemy, alembic, asyncpg, redis, httpx, python-jose, supabase, slowapi, celery, structlog, prometheus-client, scikit-learn, anthropic, web3, eth-account, stripe, reportlab, tree-sitter, tree-sitter-solidity, google-cloud-storage, google-cloud-secret-manager, sentry-sdk, cryptography

- **Tracked Platform Services (6):**
  tool-integration, orchestration, notification, intelligence-engine, data-service, contract-parser

### Code Changes

**New Files:**
- `src/presentation/api/v1/endpoints/admin/dependencies.py` — Dependencies endpoint (~120 lines)

**Files Modified:**
- `src/presentation/api/v1/endpoints/admin/__init__.py` — Registered dependencies router
- `pyproject.toml` — Version `0.27.6` -> `0.27.7`
- `k8s/overlays/local/api-service/kustomization.yaml` — newTag `"0.27.7"`

### Testing

**Verification Results:**
- OpenAPI docs show `/api/v1/admin/dependencies` endpoint
- Returns `{"detail":"Not authenticated"}` (401) without credentials
- Authenticated request returns list of dependencies with versions
- Network policy allows egress to PyPI (port 443)
- Admin action logged in audit trail

### Impact

- **User Impact:** Admin portal Dependencies page now functional
- **Breaking Changes:** None — new endpoint only
- **External Calls:** PyPI JSON API (`https://pypi.org/pypi/{package}/json`) with 1-hour cache
- **Performance:** First request may take 2-3 seconds (PyPI lookups); subsequent requests served from cache

### Related Documentation

- [Admin Portal v0.4.0 Changelog](ADMIN-PORTAL-V0.4.0-2026-02-07.md) - Frontend Dependencies page
- [API Service v0.27.5 Changelog](API-SERVICE-V0.27.5-SECURITY-FIXES-2026-02-06.md) - Previous version

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.27.7 | 2026-02-07 | Dependencies endpoint |
| 0.27.6 | 2026-02-07 | Cluster metrics normalization fixes |
| 0.27.5 | 2026-02-06 | NetworkPolicy rewrite, CronJob secret fix |
| 0.27.4 | 2026-02-06 | Scan timeout auto-retry |
| 0.27.2 | 2026-02-06 | Wallet auth nonce fix, OAuth plumbing |
| 0.27.0 | 2026-02-06 | Info severity removal, pending-to-queued mapping |

---

**Maintained By:** Apogee Team
**Status:** Complete
