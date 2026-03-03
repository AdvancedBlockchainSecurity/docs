# Playbook: Load Testing

**Version:** 1.0.0
**Last Updated:** February 24, 2026
**Audience:** Platform Operator | Developer

## Overview

Run load tests against the Apogee API to measure latency, throughput, error rates, and verify tier-based access control under concurrent load.

---

## Prerequisites

- [ ] API service running and healthy (`/api/v1/health/ready` returns 200)
- [ ] Test users exist in database for each tier (developer, starter, growth, enterprise)
- [ ] Python venv with `httpx` and `PyJWT` available (api-service venv works)

---

## Quick Start

```bash
# Run full load test (all 4 tiers, 13 endpoints, 5 concurrency levels)
cd /home/pwner/Git/blocksecops-api-service
.venv/bin/python3 /home/pwner/Git/docs/audits/scripts/load-test-by-tier.py
```

Results are printed to terminal and saved to `docs/audits/2026-02-24-load-test-results.md`.

---

## Test Matrix

### Endpoints (13)

| Category | Endpoint | Method | Auth | Tier Gate |
|----------|----------|--------|------|-----------|
| Health | `/health/live` | GET | None | None |
| Health | `/health/ready` | GET | None | None |
| User | `/users/me` | GET | JWT | Any |
| User | `/users/me/quota` | GET | JWT | Any |
| Core | `/contracts` | GET | JWT | Any |
| Core | `/scans` | GET | JWT | Any |
| Core | `/vulnerabilities` | GET | JWT | Any |
| Search | `/search` | GET | JWT | starter+ |
| Features | `/api-keys` | GET | JWT | starter+ |
| Features | `/webhooks` | GET | JWT | starter+ |
| Features | `/notification-channels` | GET | JWT | starter+ |
| Features | `/economic-analysis/quota` | GET | JWT | starter+ |
| Admin | `/audit-logs` | GET | JWT | enterprise |

### Concurrency Levels

| Level | Concurrent | Total Requests | Use Case |
|-------|-----------|----------------|----------|
| Serial | 1 | 50 | Baseline latency |
| Light | 5 | 100 | Normal usage |
| Moderate | 10 | 100 | Peak usage |
| Heavy | 25 | 100 | Stress test |
| Stress | 50 | 200 | Saturation point |

### Expected Behavior by Tier

| Tier | API Access | Expected Response |
|------|-----------|-------------------|
| Developer | Blocked (limit=0) | 429 on all endpoints |
| Starter | Blocked (limit=0) | 429 on all endpoints |
| Growth | Allowed (limit=-1) | 200 on starter+, 403 on enterprise-only |
| Enterprise | Allowed (limit=-1) | 200 on all endpoints |

---

## Test Users

Test users are pre-seeded in the database with predictable UUIDs:

| Tier | UUID | Email |
|------|------|-------|
| Developer | `11111111-1111-1111-1111-111111111111` | `test-developer@blocksecops.local` |
| Starter | `22222222-2222-2222-2222-222222222222` | `test-starter@blocksecops.local` |
| Growth | `33333333-3333-3333-3333-333333333333` | `test-growth@blocksecops.local` |
| Enterprise | `44444444-4444-4444-4444-444444444444` | `test-enterprise@blocksecops.local` |

JWT tokens are generated using HS256 with the local dev secret key (`JWT_SECRET_KEY` from config).

---

## Interpreting Results

### Status Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 403 | Tier gate denied (insufficient tier) |
| 404 | Resource not found (e.g., no quota record) |
| 405 | Method not allowed (e.g., search requires POST) |
| 429 | Rate limited (API call tracker or web rate limiter) |

### Latency Guidelines (Single Replica, Local Dev)

| Concurrency | Expected p99 | Notes |
|-------------|-------------|-------|
| 1 (serial) | < 500ms | Baseline, no contention |
| 5 (light) | < 300ms | Normal operating range |
| 10 (moderate) | < 1s | Acceptable for dev |
| 25 (heavy) | < 5s | Expected saturation |
| 50 (stress) | < 15s | Beyond single-replica capacity |

### Throughput Guidelines

| Endpoint Type | Expected at Serial | Expected at Light |
|---------------|-------------------|-------------------|
| Health (no DB) | 100-200 rps | 300-400 rps |
| Simple DB query | 30-50 rps | 60-100 rps |
| Complex DB query | 5-15 rps | 15-60 rps |

---

## Known Limitations

1. **IP-based rate limiting** — SlowAPI rate limiter is keyed by client IP. Running all tiers sequentially from the same machine causes rate limit window accumulation. Enterprise tier may show false 429s on later endpoints. Mitigation: add delays between tier tests or test tiers in separate runs.

2. **Single replica** — Local dev cluster runs 1 API replica. Latency at concurrency 25+ reflects single-replica bottleneck, not production performance.

3. **Search endpoint** — Requires POST method with request body. The load test script uses GET, so search always returns 405.

---

## Customization

### Testing a Single Tier

Edit the script's `main()` function to test only the desired tier:

```python
# In load-test-by-tier.py, comment out unwanted tiers
# await run_rate_limited_tier(client, "developer", ...)
# await run_rate_limited_tier(client, "starter", ...)
await run_full_tier(client, "growth", ...)
# await run_full_tier(client, "enterprise", ...)
```

### Adding New Endpoints

Add entries to the `ENDPOINTS` list in the script:

```python
ENDPOINTS = [
    # ...existing endpoints...
    Endpoint("/new-endpoint", "New feature", "GET", "starter"),
]
```

### Adjusting Concurrency

Modify the `CONCURRENCY_LEVELS` list:

```python
CONCURRENCY_LEVELS = [
    ConcurrencyLevel("serial", 1, 50),
    ConcurrencyLevel("light", 5, 100),
    # Add or remove levels as needed
]
```

---

## Related

- [Load test results (Feb 24, 2026)](../audits/2026-02-24-load-test-results.md)
- [Load test script](../audits/scripts/load-test-by-tier.py)
- [Tier Standards](../standards/tier-standards.md)
- [Smoke Test](../standards/smoke-test.md)
