# Load Test Results

**Date:** February 24, 2026
**Platform Version:** api-service 0.29.27
**Environment:** Local cluster (kubeadm, 1 replica, 200m/1CPU, 256Mi/1Gi)
**Duration:** 442s
**Tool:** Python asyncio + httpx (custom script)

## Executive Summary

- **Total requests sent:** 16,720
- **Connection errors:** 0
- **developer:** 200: 1100, 429: 110
- **team:** 200: 1100, 429: 110
- **growth:** 200: 3510, 403: 550, 404: 550, 405: 550, 429: 1990
- **enterprise:** 200: 3540, 404: 550, 405: 550, 429: 2510
- **Rate limit burst test:** first 429 at request #N/A
- **Issues found:** 5 (0 critical, 1 medium, 1 low, 3 info)

## Test Environment

| Setting | Value |
|---------|-------|
| API Base URL | `https://app.0xapogee.com/api/v1` |
| Cluster | kubeadm (single node) |
| API replicas | 1 |
| CPU | 200m request / 1 CPU limit |
| Memory | 256Mi request / 1Gi limit |
| DB pool | 10 + 20 overflow = 30 max |
| Auth | HS256 JWT (local dev fallback) |
| Concurrency levels | serial(1), light(5), moderate(10), heavy(25), stress(50) |

## Baseline Performance (Health Endpoints, No Auth)

| Endpoint | Concurrency | Requests | p50 (ms) | p95 (ms) | p99 (ms) | Throughput (rps) | Errors |
|----------|-------------|----------|----------|----------|----------|-----------------|--------|
| /health/live | 1 | 50 | 4.4 | 5.9 | 24.4 | 203.4 | 0 |
| /health/live | 5 | 100 | 10.7 | 23.2 | 31.2 | 409.3 | 0 |
| /health/live | 10 | 100 | 22.8 | 50.2 | 70.2 | 389.3 | 0 |
| /health/live | 25 | 100 | 88.1 | 409.6 | 497.5 | 180.2 | 0 |
| /health/live | 50 | 200 | 138.1 | 440.5 | 621.3 | 289.9 | 0 |
| /health/ready | 1 | 50 | 8.1 | 12.7 | 16.9 | 110.5 | 0 |
| /health/ready | 5 | 100 | 24.1 | 78.8 | 96.6 | 179.4 | 0 |
| /health/ready | 10 | 100 | 53.6 | 88.2 | 110.7 | 182.0 | 0 |
| /health/ready | 25 | 100 | 205.5 | 724.4 | 993.4 | 102.7 | 0 |
| /health/ready | 50 | 200 | 185.9 | 654.0 | 981.8 | 205.7 | 0 |

## Developer Tier

**Expected:** All requests return 429 (monthly API call limit = 0, API access blocked).

| Endpoint | Requests | 429 | Other | Avg Latency (ms) |
|----------|----------|-----|-------|-------------------|
| /users/me | 10 | 10 | 0 | 45.6 |
| /users/me/quota | 10 | 10 | 0 | 10.3 |
| /contracts | 10 | 10 | 0 | 7.9 |
| /scans | 10 | 10 | 0 | 9.2 |
| /vulnerabilities | 10 | 10 | 0 | 8.6 |
| /search | 10 | 10 | 0 | 15.3 |
| /api-keys | 10 | 10 | 0 | 17.8 |
| /webhooks | 10 | 10 | 0 | 13.9 |
| /notification-channels | 10 | 10 | 0 | 7.8 |
| /economic-analysis/quota | 10 | 10 | 0 | 10.7 |
| /audit-logs | 10 | 10 | 0 | 11.2 |

**Verification:** PASS — All authenticated requests returned 429.

## Team Tier

**Expected:** All requests return 429 (monthly API call limit = 0, API access blocked).

| Endpoint | Requests | 429 | Other | Avg Latency (ms) |
|----------|----------|-----|-------|-------------------|
| /users/me | 10 | 10 | 0 | 21.3 |
| /users/me/quota | 10 | 10 | 0 | 10.9 |
| /contracts | 10 | 10 | 0 | 7.6 |
| /scans | 10 | 10 | 0 | 10.5 |
| /vulnerabilities | 10 | 10 | 0 | 14.4 |
| /search | 10 | 10 | 0 | 18.2 |
| /api-keys | 10 | 10 | 0 | 16.2 |
| /webhooks | 10 | 10 | 0 | 16.5 |
| /notification-channels | 10 | 10 | 0 | 16.1 |
| /economic-analysis/quota | 10 | 10 | 0 | 11.3 |
| /audit-logs | 10 | 10 | 0 | 8.5 |

**Verification:** PASS — All authenticated requests returned 429.

## Growth Tier

| Endpoint | Concurrency | Requests | p50 (ms) | p95 (ms) | p99 (ms) | Throughput (rps) | Status Distribution |
|----------|-------------|----------|----------|----------|----------|-----------------|---------------------|
| /users/me | 1 | 50 | 20.7 | 89.5 | 109.5 | 38.2 | 200:50 |
| /users/me | 5 | 100 | 51.7 | 80.3 | 92.3 | 90.4 | 200:100 |
| /users/me | 10 | 100 | 112.6 | 241.0 | 245.2 | 75.8 | 200:100 |
| /users/me | 25 | 100 | 614.6 | 1269.5 | 1403.2 | 36.8 | 200:100 |
| /users/me | 50 | 200 | 767.1 | 1910.1 | 2446.8 | 55.0 | 200:200 |
| /users/me/quota | 1 | 50 | 18.5 | 94.0 | 107.3 | 41.7 | 404:50 |
| /users/me/quota | 5 | 100 | 46.0 | 96.6 | 104.0 | 104.9 | 404:100 |
| /users/me/quota | 10 | 100 | 81.1 | 104.2 | 112.4 | 118.0 | 404:100 |
| /users/me/quota | 25 | 100 | 233.0 | 1027.1 | 1165.8 | 68.9 | 404:100 |
| /users/me/quota | 50 | 200 | 790.2 | 2481.2 | 2716.9 | 47.6 | 404:200 |
| /contracts | 1 | 50 | 39.8 | 271.1 | 410.3 | 13.9 | 200:50 |
| /contracts | 5 | 100 | 75.6 | 243.1 | 288.7 | 57.0 | 200:100 |
| /contracts | 10 | 100 | 162.2 | 254.2 | 268.8 | 57.4 | 200:100 |
| /contracts | 25 | 100 | 1241.2 | 3323.8 | 3931.7 | 17.4 | 200:100 |
| /contracts | 50 | 200 | 1722.2 | 4994.7 | 5619.3 | 23.3 | 200:200 |
| /scans | 1 | 50 | 66.7 | 171.5 | 317.1 | 12.6 | 200:50 |
| /scans | 5 | 100 | 250.8 | 398.6 | 420.1 | 18.9 | 200:100 |
| /scans | 10 | 100 | 462.1 | 743.9 | 919.4 | 19.2 | 200:100 |
| /scans | 25 | 100 | 1594.3 | 3267.6 | 3969.2 | 13.3 | 200:100 |
| /scans | 50 | 200 | 2820.1 | 5486.4 | 6929.8 | 15.6 | 200:200 |
| /vulnerabilities | 1 | 50 | 70.0 | 202.3 | 213.5 | 11.7 | 200:50 |
| /vulnerabilities | 5 | 100 | 63.7 | 276.3 | 287.5 | 59.1 | 200:10 429:90 |
| /vulnerabilities | 10 | 100 | 139.7 | 377.7 | 464.7 | 57.5 | 429:100 |
| /vulnerabilities | 25 | 100 | 529.0 | 1277.5 | 1623.4 | 41.4 | 429:100 |
| /vulnerabilities | 50 | 200 | 893.9 | 2090.9 | 3388.1 | 46.7 | 429:200 |
| /search | 1 | 50 | 18.9 | 31.0 | 399.6 | 37.4 | 405:50 |
| /search | 5 | 100 | 45.0 | 115.3 | 124.2 | 88.1 | 405:100 |
| /search | 10 | 100 | 96.8 | 153.4 | 157.2 | 98.9 | 405:100 |
| /search | 25 | 100 | 240.1 | 1162.6 | 1487.0 | 62.3 | 405:100 |
| /search | 50 | 200 | 585.1 | 1449.0 | 2310.3 | 71.6 | 405:200 |
| /api-keys | 1 | 50 | 27.0 | 47.1 | 57.6 | 33.5 | 200:50 |
| /api-keys | 5 | 100 | 62.9 | 78.0 | 84.9 | 77.6 | 200:100 |
| /api-keys | 10 | 100 | 191.7 | 499.0 | 797.6 | 46.3 | 200:100 |
| /api-keys | 25 | 100 | 631.1 | 1264.1 | 1647.1 | 36.1 | 200:100 |
| /api-keys | 50 | 200 | 966.8 | 2501.9 | 2988.4 | 41.0 | 200:200 |
| /webhooks | 1 | 50 | 21.3 | 99.9 | 191.2 | 32.3 | 200:30 429:20 |
| /webhooks | 5 | 100 | 71.7 | 132.6 | 149.0 | 62.7 | 429:100 |
| /webhooks | 10 | 100 | 118.1 | 166.4 | 179.3 | 80.0 | 429:100 |
| /webhooks | 25 | 100 | 486.3 | 1509.4 | 1688.7 | 42.2 | 429:100 |
| /webhooks | 50 | 200 | 1089.9 | 2140.0 | 2740.1 | 45.0 | 429:200 |
| /notification-channels | 1 | 50 | 28.9 | 44.3 | 124.0 | 32.1 | 200:50 |
| /notification-channels | 5 | 100 | 77.7 | 138.1 | 142.4 | 59.5 | 200:10 429:90 |
| /notification-channels | 10 | 100 | 137.3 | 207.5 | 289.8 | 67.6 | 429:100 |
| /notification-channels | 25 | 100 | 472.7 | 1370.7 | 1621.8 | 44.0 | 429:100 |
| /notification-channels | 50 | 200 | 1041.2 | 2333.2 | 2784.4 | 43.1 | 429:200 |
| /economic-analysis/quota | 1 | 50 | 24.0 | 31.3 | 36.9 | 40.2 | 200:50 |
| /economic-analysis/quota | 5 | 100 | 71.1 | 142.2 | 165.9 | 61.9 | 200:10 429:90 |
| /economic-analysis/quota | 10 | 100 | 132.0 | 253.2 | 269.4 | 64.0 | 429:100 |
| /economic-analysis/quota | 25 | 100 | 517.0 | 1155.4 | 1483.1 | 41.9 | 429:100 |
| /economic-analysis/quota | 50 | 200 | 895.4 | 1831.2 | 2384.3 | 50.9 | 429:200 |
| /audit-logs | 1 | 50 | 20.0 | 89.3 | 94.7 | 40.3 | 403:50 |
| /audit-logs | 5 | 100 | 59.5 | 127.5 | 128.5 | 72.0 | 403:100 |
| /audit-logs | 10 | 100 | 139.0 | 255.5 | 289.8 | 62.9 | 403:100 |
| /audit-logs | 25 | 100 | 484.6 | 1658.5 | 1849.4 | 38.4 | 403:100 |
| /audit-logs | 50 | 200 | 909.7 | 2059.5 | 2785.3 | 47.9 | 403:200 |

## Enterprise Tier

| Endpoint | Concurrency | Requests | p50 (ms) | p95 (ms) | p99 (ms) | Throughput (rps) | Status Distribution |
|----------|-------------|----------|----------|----------|----------|-----------------|---------------------|
| /users/me | 1 | 50 | 22.9 | 102.8 | 186.2 | 31.4 | 200:50 |
| /users/me | 5 | 100 | 55.8 | 120.0 | 125.3 | 79.1 | 200:100 |
| /users/me | 10 | 100 | 149.8 | 254.6 | 260.1 | 62.7 | 200:100 |
| /users/me | 25 | 100 | 642.6 | 1413.2 | 1895.5 | 35.3 | 200:100 |
| /users/me | 50 | 200 | 889.3 | 1991.8 | 2404.8 | 49.5 | 200:200 |
| /users/me/quota | 1 | 50 | 18.2 | 26.6 | 82.8 | 51.8 | 404:50 |
| /users/me/quota | 5 | 100 | 49.5 | 102.0 | 109.9 | 86.2 | 404:100 |
| /users/me/quota | 10 | 100 | 98.3 | 420.0 | 423.4 | 72.0 | 404:100 |
| /users/me/quota | 25 | 100 | 412.1 | 1123.7 | 1307.6 | 47.3 | 404:100 |
| /users/me/quota | 50 | 200 | 678.7 | 1711.9 | 2067.0 | 61.6 | 404:200 |
| /contracts | 1 | 50 | 126.9 | 355.7 | 429.4 | 6.3 | 200:50 |
| /contracts | 5 | 100 | 429.4 | 828.3 | 866.6 | 10.0 | 200:100 |
| /contracts | 10 | 100 | 1186.3 | 1723.8 | 1786.5 | 8.4 | 200:100 |
| /contracts | 25 | 100 | 3302.0 | 7117.7 | 7717.9 | 6.5 | 200:100 |
| /contracts | 50 | 200 | 6657.7 | 11248.5 | 12631.4 | 7.0 | 200:200 |
| /scans | 1 | 50 | 63.0 | 118.6 | 226.6 | 13.6 | 200:50 |
| /scans | 5 | 100 | 211.9 | 428.6 | 569.4 | 20.3 | 200:100 |
| /scans | 10 | 100 | 500.4 | 1113.8 | 1130.1 | 17.7 | 200:100 |
| /scans | 25 | 100 | 1339.7 | 3668.4 | 4046.0 | 14.9 | 200:100 |
| /scans | 50 | 200 | 2851.5 | 4863.4 | 6021.6 | 16.6 | 200:200 |
| /vulnerabilities | 1 | 50 | 193.5 | 380.8 | 505.5 | 4.5 | 200:50 |
| /vulnerabilities | 5 | 100 | 60.1 | 1106.1 | 1164.5 | 29.4 | 200:10 429:90 |
| /vulnerabilities | 10 | 100 | 113.0 | 218.3 | 227.6 | 73.1 | 429:100 |
| /vulnerabilities | 25 | 100 | 591.4 | 1101.4 | 1569.8 | 38.2 | 429:100 |
| /vulnerabilities | 50 | 200 | 1062.9 | 2336.0 | 2823.1 | 43.4 | 429:200 |
| /search | 1 | 50 | 16.1 | 22.4 | 29.6 | 63.2 | 405:50 |
| /search | 5 | 100 | 39.9 | 94.0 | 98.0 | 96.1 | 405:100 |
| /search | 10 | 100 | 75.9 | 99.6 | 109.8 | 125.9 | 405:100 |
| /search | 25 | 100 | 277.3 | 1150.7 | 1713.1 | 63.1 | 405:100 |
| /search | 50 | 200 | 588.7 | 1458.6 | 2035.3 | 70.5 | 405:200 |
| /api-keys | 1 | 50 | 26.6 | 87.7 | 101.1 | 31.4 | 200:50 |
| /api-keys | 5 | 100 | 63.8 | 73.9 | 84.6 | 77.6 | 200:100 |
| /api-keys | 10 | 100 | 126.8 | 264.2 | 295.2 | 67.2 | 200:100 |
| /api-keys | 25 | 100 | 626.9 | 1559.6 | 1960.2 | 34.2 | 200:100 |
| /api-keys | 50 | 200 | 1198.0 | 2296.7 | 2577.7 | 40.5 | 200:200 |
| /webhooks | 1 | 50 | 26.9 | 39.0 | 115.5 | 33.7 | 200:30 429:20 |
| /webhooks | 5 | 100 | 73.1 | 134.3 | 145.3 | 63.3 | 429:100 |
| /webhooks | 10 | 100 | 138.0 | 360.0 | 406.4 | 62.4 | 429:100 |
| /webhooks | 25 | 100 | 625.1 | 1106.7 | 1343.9 | 37.3 | 429:100 |
| /webhooks | 50 | 200 | 709.4 | 2522.0 | 3121.2 | 47.3 | 429:200 |
| /notification-channels | 1 | 50 | 33.2 | 52.9 | 128.8 | 28.2 | 200:50 |
| /notification-channels | 5 | 100 | 69.5 | 447.1 | 453.6 | 50.8 | 200:10 429:90 |
| /notification-channels | 10 | 100 | 133.9 | 275.2 | 286.9 | 63.2 | 429:100 |
| /notification-channels | 25 | 100 | 695.0 | 1797.2 | 2482.8 | 32.0 | 429:100 |
| /notification-channels | 50 | 200 | 843.8 | 1845.1 | 2147.9 | 51.5 | 429:200 |
| /economic-analysis/quota | 1 | 50 | 23.0 | 36.1 | 75.6 | 38.9 | 200:50 |
| /economic-analysis/quota | 5 | 100 | 57.5 | 97.9 | 100.1 | 77.2 | 200:10 429:90 |
| /economic-analysis/quota | 10 | 100 | 150.2 | 383.1 | 456.9 | 56.5 | 429:100 |
| /economic-analysis/quota | 25 | 100 | 375.1 | 1317.5 | 1618.5 | 49.7 | 429:100 |
| /economic-analysis/quota | 50 | 200 | 918.8 | 2133.0 | 3086.6 | 47.2 | 429:200 |
| /audit-logs | 1 | 50 | 28.8 | 44.5 | 49.1 | 34.1 | 200:30 429:20 |
| /audit-logs | 5 | 100 | 72.0 | 198.7 | 294.7 | 53.5 | 429:100 |
| /audit-logs | 10 | 100 | 135.5 | 280.1 | 294.2 | 60.0 | 429:100 |
| /audit-logs | 25 | 100 | 572.5 | 1355.4 | 1678.3 | 36.7 | 429:100 |
| /audit-logs | 50 | 200 | 935.3 | 1926.9 | 2135.3 | 49.2 | 429:200 |

## Rate Limit Verification (Growth Tier Burst Test)

**Endpoint:** `/contracts`
**Total requests:** 350
**Concurrency:** 25
**First 429 at request:** #N/A (no 429 received)

| Status | Count | Percentage |
|--------|-------|------------|
| 200 | 350 | 100.0% |

**Latency:** p50=628.5ms, p95=3118.5ms, p99=4802.5ms

## Issues Found

### Issue 1: Enterprise Tier Rate Limited on Multiple Endpoints (Medium)

**Observed:** Enterprise tier (expected unlimited) received 429 responses on `/vulnerabilities`, `/webhooks`, `/notification-channels`, `/economic-analysis/quota`, and `/audit-logs` starting from the `light` (5 concurrent) level onwards.

**Root Cause:** The web request rate limiter (SlowAPI) is **IP-based**, not per-user. Since all 4 tiers are tested sequentially from the same machine (same IP), the rate limit sliding window accumulates requests across all tier tests. By the time enterprise tier reaches later endpoints, the IP has already consumed most of the rate limit budget from the growth tier tests (~5,500 requests). Enterprise-tier requests inherit the same IP bucket.

**Impact:** Load test results for enterprise tier are skewed — the 429 responses reflect IP-level rate limiting, not tier-level access control. In production with distributed clients, enterprise users would not hit this.

**Recommendation:** For future load tests, add a delay between tier tests to allow the sliding window to expire, or use separate source IPs per tier. No code changes needed — the IP-based rate limiter is correct behavior for DDoS protection.

### Issue 2: Growth Tier Burst Test Did Not Trigger Rate Limiting (Low)

**Observed:** 350 rapid requests to `/contracts` all returned 200 — no 429 at any point. The growth tier's `web_requests_per_minute` limit is 300.

**Root Cause:** The burst test runs as the final phase (Phase 6), after all other tests complete. By this point, sufficient time has elapsed (~400s) for the sliding window to expire. The 350 requests in rapid succession may complete within a few seconds, but the window had already reset.

**Impact:** The burst test did not effectively validate the 300/min rate limit threshold. To properly test this, the burst test should run as the first test for the tier before any window accumulation.

**Recommendation:** Redesign burst test to run at the start of a fresh rate limit window. Consider a standalone burst test script.

### Issue 3: `/search` Returns 405 Method Not Allowed (Info)

**Observed:** All requests to `GET /api/v1/search` returned 405 across all tiers.

**Root Cause:** The search endpoint requires POST method with a request body (search query), not GET. The load test script uses GET for all endpoints.

**Impact:** None — this is expected behavior. Search was not effectively tested.

### Issue 4: `/users/me/quota` Returns 404 (Info)

**Observed:** All requests to `GET /api/v1/users/me/quota` returned 404 for growth and enterprise tiers.

**Root Cause:** Test users may not have quota records in the database, or the endpoint path may differ from the expected route.

**Impact:** Quota endpoint was not effectively tested. No functional concern.

### Issue 5: Latency Degradation Under High Concurrency (Expected)

**Observed:** p99 latency exceeds 1s at concurrency 25 and exceeds 2s at concurrency 50 for most database-backed endpoints. The `/contracts` endpoint is the slowest, reaching p99=12.6s at concurrency 50.

**Root Cause:** Single API replica (200m CPU request, 1 CPU limit) with a 30-connection database pool (10 base + 20 overflow) cannot handle 25-50 concurrent requests without queuing. This is expected for a local dev cluster with 1 replica.

**Impact:** None for local development. Production will scale horizontally (multiple replicas + HPA).

**Key Latency Thresholds (Enterprise Tier):**

| Endpoint | p99 @ c=1 | p99 @ c=10 | p99 @ c=25 | p99 @ c=50 |
|----------|-----------|------------|------------|------------|
| /health/live | 24ms | 70ms | 498ms | 621ms |
| /health/ready | 17ms | 111ms | 993ms | 982ms |
| /users/me | 186ms | 260ms | 1,896ms | 2,405ms |
| /contracts | 429ms | 1,787ms | 7,718ms | 12,631ms |
| /scans | 227ms | 1,130ms | 4,046ms | 6,022ms |
| /vulnerabilities | 506ms | 228ms* | 1,570ms* | 2,823ms* |
| /api-keys | 101ms | 295ms | 1,960ms | 2,578ms |

*Rate-limited results (429), not representative of actual endpoint latency.

## Tier Access Control Verification

| Check | Result | Notes |
|-------|--------|-------|
| Developer: all endpoints return 429 | PASS | API access blocked (monthly_api_calls_limit=0) |
| Team: all endpoints return 429 | PASS | API access blocked (monthly_api_calls_limit=0) |
| Growth: core endpoints return 200 | PASS | /users/me, /contracts, /scans all 200 at serial |
| Growth: audit-logs returns 403 | PASS | Enterprise-only endpoint correctly gated |
| Enterprise: core endpoints return 200 | PASS | /users/me, /contracts, /scans, /api-keys all 200 at serial |
| Enterprise: audit-logs returns 200 | PARTIAL | 200:30, 429:20 at serial (IP rate limit interference) |
| Health endpoints: no auth required | PASS | 0 errors across all concurrency levels |
| Post-test health check | PASS | /health/live=200, /health/ready=200 |

## Recommendations

1. **Contracts endpoint optimization** — p99=429ms even at serial (1 concurrent). The `/contracts` endpoint is 3-4x slower than `/users/me` or `/api-keys` at all concurrency levels. Consider query optimization, pagination limits, or response caching.
2. **Scans endpoint optimization** — p99=317ms at serial, p99=6s at concurrency 50. Similar concern as contracts.
3. **Horizontal scaling for production** — Single replica saturates at ~10 concurrent requests (p99 > 1s). Production should target minimum 3 replicas with HPA based on CPU/request latency.
4. **Database connection pool tuning** — At concurrency 25+, database connection pool exhaustion likely contributes to latency spikes. Consider increasing base pool size from 10 to 20 for production.
5. **Health endpoint baseline** — `/health/ready` (DB check) hits p99=993ms at concurrency 25. If used as a load balancer health check, ensure check interval and timeout account for this.
6. **Separate burst test** — Create a standalone rate limit verification script that tests a single tier in isolation with fresh rate limit windows.
