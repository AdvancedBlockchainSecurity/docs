# Tier v4.0 Audit Results

**Date:** 2026-03-14 01:14:24 UTC
**Result:** 133/133 passed, 0 failed
**API Version:** 0.29.88
**Tier Config Version:** 4.0

## Summary

| Metric | Value |
|--------|-------|
| Total Assertions | 133 |
| Passed | 133 |
| Failed | 0 |
| Pass Rate | 100.0% |

## db_quotas (64/64 PASS)

| Test | Result | Detail |
|------|--------|--------|
| developer: monthly_scan_limit = 3 | PASS | Expected 3, got 3 |
| developer: max_files_per_scan = -1 | PASS | Expected -1, got -1 |
| developer: max_loc_per_scan = -1 | PASS | Expected -1, got -1 |
| developer: max_projects = 3 | PASS | Expected 3, got 3 |
| developer: max_team_members = 2 | PASS | Expected 2, got 2 |
| developer: monthly_api_calls_limit = 0 | PASS | Expected 0, got 0 |
| developer: result_retention_days = 7 | PASS | Expected 7, got 7 |
| developer: scan_priority = 50 | PASS | Expected 50, got 50 |
| developer: export_enabled = False | PASS | Expected False, got False |
| developer: api_access_enabled = False | PASS | Expected False, got False |
| developer: webhooks_enabled = False | PASS | Expected False, got False |
| developer: monthly_ai_explanations_limit = 0 | PASS | Expected 0, got 0 |
| developer: concurrent_scans_limit = 1 | PASS | Expected 1, got 1 |
| developer: web_requests_per_minute = 60 | PASS | Expected 60, got 60 |
| developer: api_requests_per_minute = 0 | PASS | Expected 0, got 0 |
| developer: api_requests_per_hour = 0 | PASS | Expected 0, got 0 |
| starter: monthly_scan_limit = 25 | PASS | Expected 25, got 25 |
| starter: max_files_per_scan = -1 | PASS | Expected -1, got -1 |
| starter: max_loc_per_scan = -1 | PASS | Expected -1, got -1 |
| starter: max_projects = 15 | PASS | Expected 15, got 15 |
| starter: max_team_members = 5 | PASS | Expected 5, got 5 |
| starter: monthly_api_calls_limit = 0 | PASS | Expected 0, got 0 |
| starter: result_retention_days = 90 | PASS | Expected 90, got 90 |
| starter: scan_priority = 40 | PASS | Expected 40, got 40 |
| starter: export_enabled = True | PASS | Expected True, got True |
| starter: api_access_enabled = False | PASS | Expected False, got False |
| starter: webhooks_enabled = True | PASS | Expected True, got True |
| starter: monthly_ai_explanations_limit = 75 | PASS | Expected 75, got 75 |
| starter: concurrent_scans_limit = 2 | PASS | Expected 2, got 2 |
| starter: web_requests_per_minute = 120 | PASS | Expected 120, got 120 |
| starter: api_requests_per_minute = 0 | PASS | Expected 0, got 0 |
| starter: api_requests_per_hour = 0 | PASS | Expected 0, got 0 |
| growth: monthly_scan_limit = 75 | PASS | Expected 75, got 75 |
| growth: max_files_per_scan = -1 | PASS | Expected -1, got -1 |
| growth: max_loc_per_scan = -1 | PASS | Expected -1, got -1 |
| growth: max_projects = -1 | PASS | Expected -1, got -1 |
| growth: max_team_members = 25 | PASS | Expected 25, got 25 |
| growth: monthly_api_calls_limit = -1 | PASS | Expected -1, got -1 |
| growth: result_retention_days = 365 | PASS | Expected 365, got 365 |
| growth: scan_priority = 25 | PASS | Expected 25, got 25 |
| growth: export_enabled = True | PASS | Expected True, got True |
| growth: api_access_enabled = True | PASS | Expected True, got True |
| growth: webhooks_enabled = True | PASS | Expected True, got True |
| growth: monthly_ai_explanations_limit = 300 | PASS | Expected 300, got 300 |
| growth: concurrent_scans_limit = 5 | PASS | Expected 5, got 5 |
| growth: web_requests_per_minute = 300 | PASS | Expected 300, got 300 |
| growth: api_requests_per_minute = 300 | PASS | Expected 300, got 300 |
| growth: api_requests_per_hour = 10000 | PASS | Expected 10000, got 10000 |
| enterprise: monthly_scan_limit = -1 | PASS | Expected -1, got -1 |
| enterprise: max_files_per_scan = -1 | PASS | Expected -1, got -1 |
| enterprise: max_loc_per_scan = -1 | PASS | Expected -1, got -1 |
| enterprise: max_projects = -1 | PASS | Expected -1, got -1 |
| enterprise: max_team_members = -1 | PASS | Expected -1, got -1 |
| enterprise: monthly_api_calls_limit = -1 | PASS | Expected -1, got -1 |
| enterprise: result_retention_days = 365 | PASS | Expected 365, got 365 |
| enterprise: scan_priority = 5 | PASS | Expected 5, got 5 |
| enterprise: export_enabled = True | PASS | Expected True, got True |
| enterprise: api_access_enabled = True | PASS | Expected True, got True |
| enterprise: webhooks_enabled = True | PASS | Expected True, got True |
| enterprise: monthly_ai_explanations_limit = -1 | PASS | Expected -1, got -1 |
| enterprise: concurrent_scans_limit = -1 | PASS | Expected -1, got -1 |
| enterprise: web_requests_per_minute = -1 | PASS | Expected -1, got -1 |
| enterprise: api_requests_per_minute = -1 | PASS | Expected -1, got -1 |
| enterprise: api_requests_per_hour = -1 | PASS | Expected -1, got -1 |

## health (2/2 PASS)

| Test | Result | Detail |
|------|--------|--------|
| GET /health/live returns 200 | PASS [200] |  |
| API version is 0.29.88 | PASS | Got version: 0.29.88 |

## billing (6/6 PASS)

| Test | Result | Detail |
|------|--------|--------|
| GET /billing/plans returns 200 | PASS [200] |  |
| All 4 tiers present | PASS | Found: ['developer', 'starter', 'growth', 'enterprise'] |
| developer: price is $0/mo | PASS | price_monthly=0 |
| starter: price is $199/mo | PASS | price_monthly=199 |
| growth: price is $499/mo | PASS | price_monthly=499 |
| enterprise: price is $1499/mo | PASS | price_monthly=1499 |

## user_tier (4/4 PASS)

| Test | Result | Detail |
|------|--------|--------|
| developer: tier = developer | PASS | Expected developer, got developer |
| starter: tier = starter | PASS | Expected starter, got starter |
| growth: tier = growth | PASS | Expected growth, got growth |
| enterprise: tier = enterprise | PASS | Expected enterprise, got enterprise |

## features (12/12 PASS)

| Test | Result | Detail |
|------|--------|--------|
| developer: api_access_enabled = False | PASS | Expected False, got False |
| developer: webhooks_enabled = False | PASS | Expected False, got False |
| developer: export_enabled = False | PASS | Expected False, got False |
| starter: api_access_enabled = False | PASS | Expected False, got False |
| starter: webhooks_enabled = True | PASS | Expected True, got True |
| starter: export_enabled = True | PASS | Expected True, got True |
| growth: api_access_enabled = True | PASS | Expected True, got True |
| growth: webhooks_enabled = True | PASS | Expected True, got True |
| growth: export_enabled = True | PASS | Expected True, got True |
| enterprise: api_access_enabled = True | PASS | Expected True, got True |
| enterprise: webhooks_enabled = True | PASS | Expected True, got True |
| enterprise: export_enabled = True | PASS | Expected True, got True |

## quota_api (8/8 PASS)

| Test | Result | Detail |
|------|--------|--------|
| developer: monthly_scan_limit = 3 | PASS | Expected 3, got 3 |
| developer: scan_priority = 50 | PASS | Expected 50, got 50 |
| starter: monthly_scan_limit = 25 | PASS | Expected 25, got 25 |
| starter: scan_priority = 40 | PASS | Expected 40, got 40 |
| growth: monthly_scan_limit = 75 | PASS | Expected 75, got 75 |
| growth: scan_priority = 25 | PASS | Expected 25, got 25 |
| enterprise: monthly_scan_limit = -1 | PASS | Expected -1, got -1 |
| enterprise: scan_priority = 5 | PASS | Expected 5, got 5 |

## api_access (4/4 PASS)

| Test | Result | Detail |
|------|--------|--------|
| developer: GET /api-keys blocked (403) | PASS [403] | Expected 403, got 403 |
| starter: GET /api-keys blocked (403) | PASS [403] | Expected 403, got 403 |
| growth: GET /api-keys allowed | PASS [200] | Got 200 |
| enterprise: GET /api-keys allowed | PASS [200] | Got 200 |

## tier_gate (8/8 PASS)

| Test | Result | Detail |
|------|--------|--------|
| developer: GET /api-keys — blocked (requires growth+) | PASS [403] | Expected 403, got 403 |
| starter: GET /api-keys — blocked (requires growth+) | PASS [403] | Expected 403, got 403 |
| growth: GET /api-keys — allowed (requires growth+) | PASS [200] | Got 200 |
| enterprise: GET /api-keys — allowed (requires growth+) | PASS [200] | Got 200 |
| developer: GET /webhooks — blocked (requires growth+) | PASS [403] | Expected 403, got 403 |
| starter: GET /webhooks — blocked (requires growth+) | PASS [403] | Expected 403, got 403 |
| growth: GET /webhooks — allowed (requires growth+) | PASS [200] | Got 200 |
| enterprise: GET /webhooks — allowed (requires growth+) | PASS [200] | Got 200 |

## rate_limits (4/4 PASS)

| Test | Result | Detail |
|------|--------|--------|
| developer: GET /users/me accessible | PASS [200] | status=200, rate_headers={} |
| starter: GET /users/me accessible | PASS [200] | status=200, rate_headers={} |
| growth: GET /users/me accessible | PASS [200] | status=200, rate_headers={} |
| enterprise: GET /users/me accessible | PASS [200] | status=200, rate_headers={} |

## stripe (21/21 PASS)

| Test | Result | Detail |
|------|--------|--------|
| Starter Monthly: price price_1TAfcL3ZtjkVcNXVjTSRsgYs is active | PASS | active=True |
| Starter Monthly: amount is 19900 cents | PASS | Expected 19900, got 19900 |
| Starter Annual: price price_1TAfcM3ZtjkVcNXVg9ll3Pqm is active | PASS | active=True |
| Starter Annual: amount is 202800 cents | PASS | Expected 202800, got 202800 |
| Growth Monthly: price price_1TAfcN3ZtjkVcNXVZQUALruH is active | PASS | active=True |
| Growth Monthly: amount is 49900 cents | PASS | Expected 49900, got 49900 |
| Growth Annual: price price_1TAfcO3ZtjkVcNXVVhAFfSwW is active | PASS | active=True |
| Growth Annual: amount is 502800 cents | PASS | Expected 502800, got 502800 |
| Enterprise Monthly: price price_1TAfcP3ZtjkVcNXVgFFrvw9i is active | PASS | active=True |
| Enterprise Monthly: amount is 149900 cents | PASS | Expected 149900, got 149900 |
| Credits Starter: price price_1TAfcV3ZtjkVcNXVM6qpmvA1 is active | PASS | active=True |
| Credits Starter: amount is 2500 cents | PASS | Expected 2500, got 2500 |
| Credits Builder: price price_1TAfcW3ZtjkVcNXVX6QaB1Sm is active | PASS | active=True |
| Credits Builder: amount is 9900 cents | PASS | Expected 9900, got 9900 |
| Credits Pro: price price_1TAfcX3ZtjkVcNXVvKAhWeXY is active | PASS | active=True |
| Credits Pro: amount is 39900 cents | PASS | Expected 39900, got 39900 |
| Credits Bulk: price price_1TAfcZ3ZtjkVcNXVLfhIA2K3 is active | PASS | active=True |
| Credits Bulk: amount is 125000 cents | PASS | Expected 125000, got 125000 |
| Subscription sub_1TAeUb3ZtjkVcNXVpW4h8kW5: price price_1TAfcL3ZtjkVcNXVjTSRsgYs is active | PASS | Subscription uses archived price! |
| Subscription sub_1TAeMb3ZtjkVcNXV7P27os3H: price price_1TAfcL3ZtjkVcNXVjTSRsgYs is active | PASS | Subscription uses archived price! |
| Subscription sub_1TAdOb3ZtjkVcNXVle3yorsi: price price_1TAfcL3ZtjkVcNXVjTSRsgYs is active | PASS | Subscription uses archived price! |

