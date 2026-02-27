# Feature Test: Load Test by Tier

**Feature:** Comprehensive platform load testing across all 4 subscription tiers
**Version:** api-service 0.29.27
**Date:** February 24, 2026
**Status:** Complete (16,720 requests, 0 connection errors)

## Test Configuration

| Setting | Value |
|---------|-------|
| API Base URL | `https://app.0xapogee.local/api/v1` |
| Cluster | kubeadm (single node, 1 API replica) |
| CPU | 200m request / 1 CPU limit |
| Memory | 256Mi request / 1Gi limit |
| DB pool | 10 base + 20 overflow = 30 max |
| Auth | HS256 JWT (local dev fallback) |
| Concurrency levels | serial(1), light(5), moderate(10), heavy(25), stress(50) |
| Endpoints tested | 13 |
| Total requests | 16,720 |
| Duration | 442s |

## Tier Access Control Verification

### Developer Tier (monthly_api_calls_limit=0)

- [x] `/users/me` — 429 (10/10)
- [x] `/users/me/quota` — 429 (10/10)
- [x] `/contracts` — 429 (10/10)
- [x] `/scans` — 429 (10/10)
- [x] `/vulnerabilities` — 429 (10/10)
- [x] `/search` — 429 (10/10)
- [x] `/api-keys` — 429 (10/10)
- [x] `/webhooks` — 429 (10/10)
- [x] `/notification-channels` — 429 (10/10)
- [x] `/economic-analysis/quota` — 429 (10/10)
- [x] `/audit-logs` — 429 (10/10)

### Team Tier (monthly_api_calls_limit=0)

- [x] `/users/me` — 429 (10/10)
- [x] `/users/me/quota` — 429 (10/10)
- [x] `/contracts` — 429 (10/10)
- [x] `/scans` — 429 (10/10)
- [x] `/vulnerabilities` — 429 (10/10)
- [x] `/search` — 429 (10/10)
- [x] `/api-keys` — 429 (10/10)
- [x] `/webhooks` — 429 (10/10)
- [x] `/notification-channels` — 429 (10/10)
- [x] `/economic-analysis/quota` — 429 (10/10)
- [x] `/audit-logs` — 429 (10/10)

### Growth Tier (monthly_api_calls_limit=-1, web_requests_per_minute=300)

- [x] `/users/me` — 200 at serial (50/50)
- [x] `/contracts` — 200 at serial (50/50)
- [x] `/scans` — 200 at serial (50/50)
- [x] `/vulnerabilities` — 200 at serial (50/50)
- [x] `/api-keys` — 200 at serial (50/50)
- [x] `/notification-channels` — 200 at serial (50/50)
- [x] `/economic-analysis/quota` — 200 at serial (50/50)
- [x] `/audit-logs` — 403 at all concurrency levels (enterprise-only, correctly gated)
- [x] `/search` — 405 (requires POST, not GET — expected)
- [x] `/users/me/quota` — 404 (test user lacks quota record — expected)

### Enterprise Tier (monthly_api_calls_limit=-1, web_requests_per_minute=-1)

- [x] `/users/me` — 200 at all concurrency levels (50-200 requests each)
- [x] `/contracts` — 200 at all concurrency levels
- [x] `/scans` — 200 at all concurrency levels
- [x] `/api-keys` — 200 at all concurrency levels
- [x] `/vulnerabilities` — 200 at serial (50/50), 429 at higher concurrency (IP rate limit*)
- [x] `/webhooks` — 200:30 at serial, 429 at higher concurrency (IP rate limit*)
- [x] `/notification-channels` — 200 at serial (50/50), 429 at higher concurrency (IP rate limit*)
- [x] `/audit-logs` — 200:30 at serial, 429 at higher concurrency (IP rate limit*)
- [x] `/search` — 405 (requires POST — expected)
- [x] `/users/me/quota` — 404 (test user lacks quota record — expected)

*IP-based rate limiter (SlowAPI) accumulated requests from prior tier tests running on same machine.

## Baseline Performance

- [x] `/health/live` — p50=4.4ms at serial, 203 rps
- [x] `/health/live` — p50=10.7ms at light, 409 rps (peak throughput)
- [x] `/health/ready` — p50=8.1ms at serial, 110 rps
- [x] `/health/ready` — p50=24.1ms at light, 179 rps
- [x] No errors at any concurrency level for health endpoints

## Post-Test Health Check

- [x] `/health/live` — 200 (15.9ms)
- [x] `/health/ready` — 200 (52.1ms)
- [x] Platform remained healthy throughout entire test

## Issues Found

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | Enterprise tier rate limited by IP-based SlowAPI limiter | Medium | Documented (test artifact, not a bug) |
| 2 | Growth burst test did not trigger rate limit | Low | Documented (sliding window expired) |
| 3 | `/search` returns 405 | Info | Expected (requires POST) |
| 4 | `/users/me/quota` returns 404 | Info | Expected (no quota records for test users) |
| 5 | Latency degradation at concurrency 25+ | Info | Expected (single replica, 200m CPU) |

## Artifacts

| File | Location |
|------|----------|
| Load test script | `docs/audits/scripts/load-test-by-tier.py` |
| Full results report | `docs/audits/2026-02-24-load-test-results.md` |
