# API Endpoints Reference

**Service:** BlockSecOps API Service v0.28.32
**Base URL:** `https://app.blocksecops.local/api/v1`
**Total Endpoints:** 452 across 54 groups
**OpenAPI Spec:** `/openapi.json` (accessible inside cluster on port 8000)
**Last Audited:** February 14, 2026

## Authentication

All endpoints (except health checks) require a JWT Bearer token:

```bash
curl -H "Authorization: Bearer <JWT_TOKEN>" https://app.blocksecops.local/api/v1/...
```

JWT tokens are issued by Supabase and support both RS256 (JWKS) and HS256 (secret key) algorithms.

### Tier-Based Rate Limiting

API access is rate-limited by subscription tier:

| Tier | Monthly API Calls | Scans/Month |
|------|-------------------|-------------|
| Developer | 0 (free) | 3 |
| Growth | 10,000 | 50 |
| Team | 50,000 | 200 |
| Enterprise | Unlimited | Unlimited |

Rate-limited responses return HTTP 429 with:
```json
{
  "error": "API call limit exceeded",
  "tier": "developer",
  "limit": 0,
  "used": 0,
  "reset_at": "2026-03-01T00:00:00+00:00",
  "upgrade_url": "/pricing"
}
```

## Endpoint Groups

| Group | Endpoints | Doc File | Description |
|-------|-----------|----------|-------------|
| [Health & Info](#) | 5 | [health.md](./health.md) | Service health checks, version info |
| [Users](#) | 7 | [users.md](./users.md) | User profile, preferences, quota |
| [Contracts](#) | 18 | [contracts.md](./contracts.md) | Smart contract management, analytics, structure |
| [Projects](#) | 15 | [projects.md](./projects.md) | Project management, access control |
| [Scans](#) | 22 | [scans.md](./scans.md) | Scan creation, results, batch operations |
| [Vulnerabilities](#) | 9 | [vulnerabilities.md](./vulnerabilities.md) | Vulnerability management, stats |
| [Analytics](#) | 6 | [analytics.md](./analytics.md) | Trends, scanner effectiveness |
| [Search](#) | 7 | [search.md](./search.md) | Quick search, saved searches |
| [Code Review](#) | 6 | [ai-code-review.md](./ai-code-review.md) | AI code review suggestions |
| [Code Repair](#) | 8 | [ai-code-repair.md](./ai-code-repair.md) | AI code repair generation |
| [Exploits](#) | 8 | [ai-exploits.md](./ai-exploits.md) | PoC exploit generation |
| [Invariants](#) | 11 | [ai-invariants.md](./ai-invariants.md) | Invariant generation |
| [Copilot](#) | 9 | [copilot.md](./copilot.md) | AI security copilot conversations |
| [ML](#) | 25 | [ml.md](./ml.md) | ML model stats, training, classification |
| [Intelligence](#) | 15 | [intelligence.md](./intelligence.md) | CVEs, exploits, patterns, NVD |
| [Deduplication](#) | 10 | [deduplication.md](./deduplication.md) | Finding deduplication groups |
| [Economic Analysis](#) | 5 | [economic-analysis.md](./economic-analysis.md) | Risk analysis, quota |
| [Organizations](#) | 52 | [organizations.md](./organizations.md) | Org management, members, teams, roles, invites, integrations, service accounts |
| [Admin](#) | 49 | [admin.md](./admin.md) | System health, user management, audit |
| [Billing](#) | 14 | [billing.md](./billing.md) | Plans, subscriptions, invoices |
| [Payments](#) | 12 | [payments.md](./payments.md) | Credits, packages, crypto payments |
| [API Keys](#) | 9 | [api-keys.md](./api-keys.md) | API key management |
| [Webhooks](#) | 10 | [webhooks.md](./webhooks.md) | Webhook configuration, events |
| [Notification Channels](#) | 8 | [notification-channels.md](./notification-channels.md) | Alert channels |
| [Monitoring](#) | 12 | [monitoring.md](./monitoring.md) | Contract monitoring, alerts |
| [IDE Integrations](#) | 8 | [ide-integrations.md](./ide-integrations.md) | IDE token management |
| [Auth](#) | 18 | [auth.md](./auth.md) | Wallet auth (ETH + Solana), OAuth, consent |
| [Scanners](#) | 4 | [scanners.md](./scanners.md) | Scanner list, presets |
| [Quality Gates](#) | 7 | [quality-gates.md](./quality-gates.md) | CI/CD quality gates |
| [Tags](#) | 8 | [tags.md](./tags.md) | Contract tagging |
| [Misc](#) | 26 | [misc.md](./misc.md) | Annotations, assignments, comments, favorites, feedback, roles, saved-searches, statistics, support-tickets, upload |

## Audit Summary

**Date:** February 14, 2026
**API Version:** 0.28.32
**Schemas:** 489 response/request models

### Test Results (GET endpoints)

| Status | Count | Description |
|--------|-------|-------------|
| 200 | ~100 | Successful responses |
| 404 | 3 | Expected (no org membership, dummy IDs) |
| 500 | 5 | Server errors (see Known Issues) |
| 429 | All (developer tier) | Rate limited for non-enterprise tiers |

### Known Issues Found During Audit

| Issue | Endpoint | Severity | Description |
|-------|----------|----------|-------------|
| Email validation | `GET /users/me`, `GET /users/me/enhanced` | Medium | Pydantic rejects `.local` TLD in email response serialization |
| Route conflict | `GET /invariants/templates` | High | "templates" parsed as UUID path param instead of matching `/templates` route |
| Tier attribute | `GET /invariants/user/quota` | Medium | `AttributeError: 'Tier' object has no attribute 'get'` |
| Datetime mismatch | `GET /ml/training-stats` | Low | Mixing timezone-aware and timezone-naive datetimes |
| Rate limit scope | Health endpoints | Low | Health/liveness probes should be exempt from rate limiting |

## Data Summary (Local Environment)

| Resource | Count |
|----------|-------|
| Users | 5 (test accounts) |
| Contracts | 1 (SemgrepTestContract) |
| Projects | 0 |
| Scans | 6 (all completed, semgrep) |
| Vulnerabilities | 21 (all low severity) |
| Scanners | 15 |
| Intelligence Patterns | 413 |
| CVEs | 3 |
| Exploit Records | 3 |
| Deduplication Groups | 768 |
| Copilot Conversations | 5 |
| Code Reviews | 2 |
| Code Repairs | 3 |
