# Feature Test: Tier Gate Enforcement

**Feature:** Tier-based feature access control for all premium endpoints
**Version:** api-service 0.29.23 through 0.29.42
**Date:** February 24, 2026
**Status:** Deployed and verified (37/37 smoke test, 36/36 tier audit)

## Smoke Test Results (February 24, 2026)

Full platform smoke test after final deployment (v0.29.26):

| Check | Result |
|-------|--------|
| API health/live | PASS (v0.29.26) |
| API health/ready | PASS (database connected) |
| Dashboard HTTPS | PASS (HTTP 200) |
| Admin portal HTTP | PASS (HTTP 200) |
| All 6 internal services | PASS |
| Authenticated endpoints | PASS |
| CronJob version drift | 0 drift |

## Tier Gate Verification

All 36 endpoint/tier combinations verified:

### Tier Hierarchy

| Tier | Level | API Access | Feature Access |
|------|-------|-----------|----------------|
| developer | 0 | Blocked (429) | N/A |
| team | 1 | Blocked (429) | N/A |
| growth | 2 | Allowed | Full except enterprise |
| enterprise | 3 | Allowed | Full |

### Endpoint Tests by Tier

#### Search (`require_tier("team")`)
- [ ] developer -> 429 (API access blocked)
- [ ] team -> 429 (API access blocked)
- [ ] growth -> 200 (allowed, growth >= team)
- [ ] enterprise -> 200 (allowed)

#### API Keys (`require_tier("growth")`)
- [ ] developer -> 429 (API access blocked)
- [ ] team -> 429 (API access blocked)
- [ ] growth -> 200 (allowed)
- [ ] enterprise -> 200 (allowed)

#### Integrations (`require_tier("team")`) — Updated v0.29.42
- [ ] developer -> 403 (tier too low)
- [ ] team -> 200 (allowed, integrations available to all paying tiers)
- [ ] growth -> 200 (allowed)
- [ ] enterprise -> 200 (allowed)

#### Notification Channels (`require_tier("growth")`)
- [ ] developer -> 429 (API access blocked)
- [ ] team -> 429 (API access blocked)
- [ ] growth -> 200 (allowed)
- [ ] enterprise -> 200 (allowed)

#### Webhooks (`require_tier("growth")`)
- [ ] developer -> 429 (API access blocked)
- [ ] team -> 429 (API access blocked)
- [ ] growth -> 200 (allowed)
- [ ] enterprise -> 200 (allowed)

#### Audit Logs (`require_tier("growth")`)
- [ ] developer -> 429 (API access blocked)
- [ ] team -> 429 (API access blocked)
- [ ] growth -> 200 (allowed)
- [ ] enterprise -> 200 (allowed)

#### Economic Analysis Reports (`require_tier("enterprise")`)
- [ ] developer -> 429 (API access blocked)
- [ ] team -> 429 (API access blocked)
- [ ] growth -> 403 (tier too low)
- [ ] enterprise -> 200 (allowed)

#### Economic Analysis Simulate (`require_tier("enterprise")`)
- [ ] developer -> 429 (API access blocked)
- [ ] team -> 429 (API access blocked)
- [ ] growth -> 403 (tier too low)
- [ ] enterprise -> 200 (allowed)

### Core Endpoints (Must NOT have tier gates)
- [ ] GET /scans -> 200 for all authenticated tiers
- [ ] GET /contracts -> 200 for all authenticated tiers
- [ ] GET /vulnerabilities -> 200 for all authenticated tiers

## Unit Tests

20 structural tests in `tests/unit/presentation/test_tier_gate_enforcement.py`:

- [ ] TestSearchTierGate (3 tests) - verifies `require_tier("team")` on POST `/search`
- [ ] TestApiKeysTierGate (3 tests) - verifies `require_tier("growth")` on GET `/api-keys`
- [ ] TestIntegrationsTierGate (2 tests) - verifies `require_tier("team")` on GET integrations list
- [ ] TestNotificationChannelsTierGate (2 tests) - verifies `require_tier("growth")` on GET list
- [ ] TestWebhooksTierGate (2 tests) - verifies `require_tier("growth")` on GET list
- [ ] TestAuditLogsTierGate (1 test) - verifies `require_tier("growth")` on GET `/audit-logs`
- [ ] TestEconomicAnalysisTierGate (4 tests) - verifies `require_tier("enterprise")` on reports/simulate
- [ ] TestUngatedEndpoints (3 tests) - verifies core endpoints do NOT have tier gates

## Stale Test Fixes (v0.29.26)

5 pre-existing test failures fixed:

- [ ] CronJob schedule test updated: expected `0 2 * * 0` (weekly Sunday 2AM)
- [ ] Production env tests: added `INTEGRATION_ENCRYPTION_KEY` to 3 test env dicts
- [ ] Production scanner overlay test: replaced with `test_production_overlay_sets_registry`
- [ ] Full suite: 1032 passed, 0 failed, 24 skipped

## Version History

| Version | PR | Changes |
|---------|-----|---------|
| 0.29.23 | #258 | Added tier gates: search (team), api-keys (growth), integrations (growth) |
| 0.29.24 | #259 | Added tier gates: notification-channels (growth), webhooks (growth) |
| 0.29.25 | #260 | Added 20 structural unit tests for tier gate enforcement |
| 0.29.26 | #261 | Fixed 5 stale unit tests; full suite clean (1032/0/24) |
| 0.29.42 | — | Integrations tier gate changed from growth to team; IDE tokens changed from team to growth |
