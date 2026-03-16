# API Endpoint Functional Test Audit — 2026-03-15

Tested from inside API pod via kubectl exec against localhost:8000.
Auth: Supabase JWT for jasonbrailowbizop@mail.com.

## Results

### Health (public)

| Endpoint | Status | Result |
|----------|--------|--------|
| GET /api/v1/health/live | 200 | PASS |
| GET /api/v1/health/ready | 200 | PASS |
| GET /api/v1/health/startup | 200 | PASS |

### Core Read (JWT)

| Endpoint | Status | Result |
|----------|--------|--------|
| GET /api/v1/contracts?limit=2 | 200 | PASS |
| GET /api/v1/scans?limit=2 | 200 | PASS |
| GET /api/v1/vulnerabilities?limit=2 | 200 | PASS |
| GET /api/v1/projects | 200 | PASS |
| GET /api/v1/scanners | 200 | PASS |
| GET /api/v1/organizations | 200 | PASS |

### Intelligence

| Endpoint | Status | Result |
|----------|--------|--------|
| GET /api/v1/intelligence/patterns?limit=3 | 200 | PASS |
| GET /api/v1/intelligence/patterns/BVD-SOLIDITY-TOK-011 | 200 | PASS — renamed pattern found |
| GET /api/v1/intelligence/exploits?limit=2 | 200 | PASS |
| GET /api/v1/intelligence/cves?limit=2 | 200 | PASS |
| GET /api/v1/intelligence/stats | 200 | PASS |
| GET /api/v1/intelligence/swc-mapping | 200 | PASS |

### Deduplication

| Endpoint | Status | Result |
|----------|--------|--------|
| GET /api/v1/deduplication/groups?limit=3 | 200 | PASS |

### Vulnerability Detail

| Endpoint | Status | Result |
|----------|--------|--------|
| GET /api/v1/vulnerabilities/c8679442-... | 200 | PASS |
| pattern_code field | BVD-SOLIDITY-TOK-011 | PASS — renamed correctly |
| false_positive_score field | null | Expected — pre-FP-fix vuln |
| fingerprint_code field | present (64 chars) | PASS |
| classification_confidence | 0.9 | PASS |

### Auth Enforcement

| Endpoint | Status | Result |
|----------|--------|--------|
| GET /api/v1/contracts (no auth) | 401 | PASS — correctly rejected |
| GET /api/v1/vulnerabilities (no auth) | 401 | PASS — correctly rejected |

### Billing

| Endpoint | Status | Result |
|----------|--------|--------|
| GET /api/v1/billing/plans | 200 | PASS |
| GET /api/v1/users/quota | 200 | PASS |

## Summary

| Category | Tested | Passed | Failed |
|----------|--------|--------|--------|
| Health | 3 | 3 | 0 |
| Core read | 6 | 6 | 0 |
| Intelligence | 6 | 6 | 0 |
| Deduplication | 1 | 1 | 0 |
| Vulnerability detail | 1 | 1 | 0 |
| Auth enforcement | 2 | 2 | 0 |
| Billing | 2 | 2 | 0 |
| **Total** | **21** | **21** | **0** |

## Notes

- Pattern rename migration verified: BVD-SOLIDITY-TOK-011 returned correctly
- FP scores null on pre-fix vulnerabilities (expected — only new scans populate)
- Intelligence Engine connectivity confirmed via patterns/exploits/CVEs endpoints
- All auth-protected endpoints correctly reject unauthenticated requests
