# API Service v0.29.23–v0.29.26 - Tier Gate Enforcement

**Date:** February 24, 2026
**Versions:** 0.29.23, 0.29.24, 0.29.25, 0.29.26
**Type:** Security hardening (PATCH)
**PRs:** #258, #259, #260, #261

## Summary

Added tier-based access control (`require_tier()`) to all premium API endpoints, wrote 20 structural regression tests for enforcement, and fixed 5 stale unit tests for a fully clean test suite.

## Changes by Version

### v0.29.23 (PR #258) - Initial Tier Gates

Added `require_tier()` dependencies to 3 premium endpoints:
- `POST /api/v1/search` — `require_tier("team")`
- `GET /api/v1/api-keys` — `require_tier("growth")`
- `GET /api/v1/integrations` — `require_tier("growth")`

Files modified:
- `src/presentation/api/v1/endpoints/search.py`
- `src/presentation/api/v1/endpoints/api_keys.py`
- `src/presentation/api/v1/endpoints/integrations.py`

### v0.29.24 (PR #259) - Additional Tier Gates

Added `require_tier()` to 2 more premium endpoints discovered during tier audit:
- `GET /api/v1/notification-channels` — `require_tier("growth")`
- `GET /api/v1/webhooks` — `require_tier("growth")`

Files modified:
- `src/presentation/api/v1/endpoints/notification_channels.py`
- `src/presentation/api/v1/endpoints/webhooks.py`

### v0.29.25 (PR #260) - Tier Gate Unit Tests

Added 20 structural unit tests that verify tier gates at the source level:
- Tests read endpoint source files and verify `require_tier()` in route decorators
- Tests verify core endpoints (scans, contracts, vulnerabilities) do NOT have tier gates
- All tests run without database or external dependencies (<0.1s)

Files added:
- `tests/unit/presentation/test_tier_gate_enforcement.py`

### v0.29.26 (PR #261) - Fix Stale Unit Tests

Fixed 5 pre-existing test failures to achieve clean suite (1032 passed, 0 failed):

1. `test_cronjob_schedule_weekly` — Updated expected schedule from `0 */6 * * *` to `0 2 * * 0`
2. `test_load_environment_from_env` — Added `INTEGRATION_ENCRYPTION_KEY` to production env dict
3. `test_production_config` — Added `INTEGRATION_ENCRYPTION_KEY` to production env dict
4. `test_kubernetes_config` — Added `INTEGRATION_ENCRYPTION_KEY` to production env dict
5. `test_production_overlay_sets_registry` — Replaced scanner list test with SCANNER_REGISTRY validation

Files modified:
- `tests/unit/infrastructure/test_audit_fixes.py`
- `tests/unit/infrastructure/test_config.py`
- `tests/unit/infrastructure/test_configmap_overlay_consistency.py`

## Tier Access Control Summary

| Endpoint | Required Tier | Effect |
|----------|--------------|--------|
| POST /search | team | developer blocked |
| GET /api-keys | growth | developer, team blocked |
| GET /integrations | growth | developer, team blocked |
| GET /notification-channels | growth | developer, team blocked |
| GET /webhooks | growth | developer, team blocked |
| GET /audit-logs | growth | developer, team blocked |
| POST /economic-analysis/reports | enterprise | developer, team, growth blocked |
| POST /economic-analysis/simulate | enterprise | developer, team, growth blocked |

## Dual-Layer Access Control

The platform enforces two layers:
1. **API access gate** (`APICallTrackerMiddleware`): developer/team tiers get 429 (api_access_enabled=false)
2. **Feature tier gate** (`require_tier()`): growth tier gets 403 on enterprise-only endpoints

## Verification

- Tier audit: 36/36 endpoint/tier combinations correct
- Smoke test: 37/37 pass
- Unit tests: 1032 passed, 0 failed, 24 skipped
- Version drift: 0 across all 9 services
