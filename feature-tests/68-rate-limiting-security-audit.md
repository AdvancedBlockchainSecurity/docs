# Feature Test: Rate Limiting Security Audit (v0.29.4)

**Feature:** Endpoint Rate Limiting for All API Operations
**Version:** API Service 0.29.4+
**Last Updated:** February 20, 2026

## Overview

All API endpoints must be rate-limited via the centralized tier configuration (`tiers.json`). Rate limits are enforced by slowapi decorators and return `429 Too Many Requests` when exceeded.

As of v0.29.4, rate limiting coverage was expanded from write/mutation endpoints only to include all 27 previously unprotected endpoint files (~170+ endpoints total), covering read operations, search, analytics, and CRUD operations.

---

## Prerequisites

1. API service running v0.29.4+
2. Authenticated user session (JWT token)
3. Access to `https://app.blocksecops.local`

---

## Test Cases

### TC-1: Contract Creation Rate Limit (10/min)

**Steps:**
1. Authenticate and obtain JWT token
2. Send 11 rapid POST requests to create contracts

**Request:**
```bash
TOKEN="<jwt-token>"
for i in $(seq 1 11); do
  HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -X POST \
    -d "{\"name\": \"RateLimitTest$i\", \"source_code\": \"pragma solidity ^0.8.0; contract Test$i {}\", \"language\": \"solidity\"}" \
    "https://app.blocksecops.local/api/v1/contracts")
  echo "Request $i: $HTTP_CODE"
done
```

**Expected Result:**
- Requests 1-10: `201 Created`
- Request 11: `429 Too Many Requests`
- Response headers include `X-RateLimit-Limit` and `X-RateLimit-Remaining`

---

### TC-2: Batch Scan Rate Limit (3/min)

**Steps:**
1. Authenticate and obtain JWT token
2. Send 4 rapid batch scan requests

**Request:**
```bash
for i in $(seq 1 4); do
  HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -X POST \
    -d '{"contract_ids": ["<contract-uuid>"], "scanner_ids": ["slither"]}' \
    "https://app.blocksecops.local/api/v1/scans/batch")
  echo "Request $i: $HTTP_CODE"
done
```

**Expected Result:**
- Requests 1-3: `200 OK` or `201 Created`
- Request 4: `429 Too Many Requests`

---

### TC-3: Webhook Secret Rotation Rate Limit (3/min)

**Steps:**
1. Create a webhook via API
2. Attempt to rotate its secret 4 times in rapid succession

**Request:**
```bash
WEBHOOK_ID="<webhook-uuid>"
for i in $(seq 1 4); do
  HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    -X POST \
    "https://app.blocksecops.local/api/v1/webhooks/$WEBHOOK_ID/rotate-secret")
  echo "Rotation $i: $HTTP_CODE"
done
```

**Expected Result:**
- Rotations 1-3: `200 OK`
- Rotation 4: `429 Too Many Requests`

---

### TC-4: File Upload Rate Limit (5/min)

**Steps:**
1. Upload 6 files in rapid succession

**Request:**
```bash
for i in $(seq 1 6); do
  HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    -F "file=@test_contract.sol" \
    "https://app.blocksecops.local/api/v1/upload")
  echo "Upload $i: $HTTP_CODE"
done
```

**Expected Result:**
- Uploads 1-5: `200 OK`
- Upload 6: `429 Too Many Requests`

---

### TC-5: Wallet Verification Rate Limit (5/min)

**Steps:**
1. Send 6 wallet verification requests

**Expected Result:**
- Requests 1-5: `200 OK` or `400 Bad Request` (invalid signature)
- Request 6: `429 Too Many Requests`

---

### TC-6: Analytics Dual-Auth (API Key Access)

**Steps:**
1. Create an API key with `analytics:read` scope
2. Request analytics endpoints using the API key

**Request:**
```bash
curl -sk \
  -H "X-API-Key: <api-key>" \
  "https://app.blocksecops.local/api/v1/analytics/tool-effectiveness?contract_id=<uuid>"
```

**Expected Result:** `200 OK` with analytics data (previously required JWT only)

**Endpoints supporting dual-auth:**
- `/api/v1/analytics/tool-effectiveness`
- `/api/v1/analytics/vulnerability-trends`
- `/api/v1/analytics/project-comparison`
- `/api/v1/analytics/scanner-effectiveness-dashboard`
- `/api/v1/analytics/summary`

---

### TC-7: Rate Limit Headers Present

**Steps:**
1. Send a request to any rate-limited endpoint

**Request:**
```bash
curl -sk -v \
  -H "Authorization: Bearer $TOKEN" \
  "https://app.blocksecops.local/api/v1/contracts" \
  2>&1 | grep -i "x-ratelimit"
```

**Expected Result:** Response includes rate limit headers:
```
X-RateLimit-Limit: 10
X-RateLimit-Remaining: 9
X-RateLimit-Reset: <timestamp>
```

---

### TC-8: User Profile Update Rate Limit (10/min)

**Steps:**
1. Send 11 profile update requests

**Request:**
```bash
for i in $(seq 1 11); do
  HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -X PUT \
    -d '{"display_name": "Test User"}' \
    "https://app.blocksecops.local/api/v1/users/me")
  echo "Update $i: $HTTP_CODE"
done
```

**Expected Result:**
- Requests 1-10: `200 OK`
- Request 11: `429 Too Many Requests`

---

## Rate Limit Reference

### Pre-existing Rate-Limited Endpoints (v0.28.42)

| Category | Endpoint | Limit | HTTP Method | Path |
|----------|----------|-------|-------------|------|
| operations | batchScan | 3/min | POST | `/api/v1/scans/batch` |
| operations | storeResults | 60/min | POST | `/api/v1/scans/{id}/results` |
| operations | storeFuzzingResults | 30/min | POST | `/api/v1/scans/{id}/fuzzing-results` |
| operations | recoverStaleScans | 5/min | POST | `/api/v1/scans/recover-stale` |
| operations | contractCreate | 10/min | POST | `/api/v1/contracts` |
| operations | contractUpdate | 20/min | PUT | `/api/v1/contracts/{id}` |
| operations | contractDelete | 10/min | DELETE | `/api/v1/contracts/{id}` |
| operations | contractBatchDelete | 3/min | POST | `/api/v1/contracts/batch-delete` |
| operations | fileUpload | 5/min | POST | `/api/v1/upload` |
| operations | projectCreate | 10/min | POST | `/api/v1/projects` |
| operations | projectUpdate | 20/min | PUT | `/api/v1/projects/{id}` |
| operations | projectDelete | 10/min | DELETE | `/api/v1/projects/{id}` |
| webhooks | webhookCreate | 5/min | POST | `/api/v1/webhooks` |
| webhooks | webhookUpdate | 10/min | PUT | `/api/v1/webhooks/{id}` |
| webhooks | webhookDelete | 10/min | DELETE | `/api/v1/webhooks/{id}` |
| webhooks | webhookSecretRotate | 3/min | POST | `/api/v1/webhooks/{id}/rotate-secret` |
| auth | walletVerify | 5/min | POST | `/api/v1/wallet/verify` |
| auth | walletLink | 5/min | POST | `/api/v1/wallet/link` |
| general | userProfileUpdate | 10/min | PUT | `/api/v1/users/me` |
| general | invariantApply | 10/min | POST | `/api/v1/invariants/{id}/apply` |
| general | invariantFeedback | 20/min | POST | `/api/v1/invariants/{id}/feedback` |
| general | invariantDelete | 10/min | DELETE | `/api/v1/invariants/{id}` |

### New Rate-Limited Endpoints (v0.29.4 Security Audit)

The following 27 endpoint files were added during the v0.29.4 security audit. All use tier-based rate limiting via `get_rate_limit_string("general", "default")` (60/min default) unless noted.

| Endpoint File | Endpoints Covered | Rate Limit | Notes |
|---------------|-------------------|------------|-------|
| `payments.py` | Payment operations | Tier-based (60/min) | |
| `billing.py` | Billing operations | Tier-based (60/min) | |
| `organizations.py` | Organization CRUD | Tier-based (60/min) | |
| `teams.py` | Team management | Tier-based (60/min) | |
| `intelligence.py` | Intelligence queries | Tier-based (60/min) | |
| `search.py` | Search endpoints | Tier-based (60/min) | |
| `vulnerabilities.py` | Vulnerability queries | Tier-based (60/min) | |
| `deduplication.py` | Dedup queries | Tier-based (60/min) | |
| `annotations.py` | Annotation CRUD | Tier-based (60/min) | |
| `comments.py` | Comment CRUD | Tier-based (60/min) | |
| `favorites.py` | Favorites CRUD | Tier-based (60/min) | |
| `tags.py` | Tag operations | Tier-based (60/min) | |
| `integrations.py` | Integration management | Tier-based (60/min) | |
| `analytics.py` | Analytics queries | Tier-based (60/min) | |
| `statistics.py` | Statistics queries | Tier-based (60/min) | |
| `patterns.py` | Pattern queries | Tier-based (60/min) | |
| `scan_results.py` | Scan result queries | Tier-based (60/min) | |
| `assignments.py` | Assignment operations | Tier-based (60/min) | |
| `quality_gates.py` | Quality gate operations | Tier-based (60/min) | |
| `saved_searches.py` | Saved search CRUD | Tier-based (60/min) | |
| `notification_channels.py` | Channel management | Tier-based (60/min) | |
| `consent.py` | Consent operations | Tier-based (60/min) | |
| `feedback.py` | Feedback submission | Tier-based (60/min) | |
| `support_tickets.py` | Support ticket CRUD | Tier-based (60/min) | |
| `oauth_callbacks.py` | OAuth token exchange | Fixed: 10/minute | Sensitive auth flow |
| `admin/impersonation.py` | Admin impersonation | Fixed: 5/minute | Admin-only, high risk |
| `gdpr.py` | GDPR data requests | Fixed: 5/minute | Resource-intensive |

### Endpoints Intentionally NOT Rate-Limited

| Endpoint File | Reason |
|---------------|--------|
| `health.py` | Must remain unthrottled for Kubernetes liveness/readiness probes |
| `websocket.py` | WebSocket connections, not HTTP request/response |
| `monitoring.py` | Internal monitoring endpoints |
| `admin/scan_monitoring.py` | Admin-only with MFA enforcement |
| `admin/system.py` | Admin-only with MFA enforcement |
| `admin/audit.py` | Admin-only with MFA enforcement |
| `admin/support.py` | Admin-only with MFA enforcement |
