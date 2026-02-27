# Feature Test 72: Scanner & API Service Audit Fixes

**Date:** 2026-02-22
**Status:** Pass
**Services:** api-service (0.29.6), tool-integration (0.5.3), notification (0.2.0), dashboard (0.46.1)

---

## Scope

Verification of fixes from the comprehensive scanner and API service audit. Covers version consistency, metrics port configuration, MythrilParser removal, canary CronJob removal, race condition fixes, and load testing with real-world contracts.

---

## Changes Tested

### API Service Version & Port Fixes
- VERSION file, README, all overlay kustomizations synced to 0.29.6
- Prometheus annotation corrected: port 8000 → 9090
- Metrics containerPort 9090 added to base deployments and services
- `/users/me` 500 error fixed: EmailStr → str in response models (`.local` TLD rejection)
- `/scanners` 500 error fixed: added `response: Response` parameter for slowapi rate limiter
- 17 additional slowapi-decorated endpoints fixed across oauth_callbacks, invites, gdpr, impersonation
- Server header disclosure removed in SecurityHeadersMiddleware

### Tool Integration
- Canary CronJob removed (Kubernetes probes provide liveness/readiness checks)
- `canary-cronjob.yaml` deleted from base manifests
- `dry_run` parameter removed from trigger_scan endpoint
- MythrilParser removed (380 lines deprecated code)
- Wake scanner metadata note corrected: 0.3.7 → 0.3.8

### Dashboard Race Condition Fixes
- RC-FIX-013: useRef for stale closure in useScanCompletion
- RC-FIX-014: Single initialization effect in OrganizationContext
- RC-FIX-015: Token refresh mutex in API client
- RC-FIX-019: Reduced scan polling, disabled when background
- RC-FIX-021: Bounded dedup set in useNotifications

### Notification Race Condition Fixes
- RC-FIX-039/040: Snapshot iteration in broadcast/send_to_user
- RC-FIX-041: JWT validation with SUPABASE_JWT_SECRET
- RC-FIX-042: Topic subscription persistence
- RC-FIX-043: Redis list bounded with ltrim
- RC-FIX-044: Auth enforcement before subscribe

---

## Test Results

| # | Test | Result | Details |
|---|------|--------|---------|
| 1 | Scanner version consistency (Harbor vs ConfigMap vs docs) | Pass | All 16 scanners consistent across all 3 sources |
| 2 | API service health after version sync | Pass | `/api/v1/health/ready` returns v0.29.6 |
| 3 | Metrics port configuration | Pass | Port 9090 exposed in deployment and service manifests |
| 4 | Canary CronJob removed | Pass | CronJob deleted, dry_run parameter removed from trigger endpoint |
| 5 | MythrilParser removed from dispatch | Pass | 16 scanners in parametrize, no mythril references |
| 6 | Load test: OpenZeppelin ERC20 (6 scanners) | Pass | 142 findings, ~5 min |
| 7 | Load test: Uniswap V2 Router (3 scanners) | Pass | 87 findings, ~3 min |
| 8 | Load test: Compound Governor (2 scanners) | Pass | 64 findings, ~4 min |
| 9 | Contract-by-address feature | Pass | 4 contracts with addresses stored and returned |
| 10 | Harbor registry default in build scripts | Pass | 4 repos updated to harbor.0xapogee.local |
| 11 | `/users/me` endpoint returns user profile | Pass | EmailStr → str fix resolves `.local` TLD validation |
| 12 | `/scanners` endpoint returns scanner list | Pass | slowapi Response parameter fix resolves 500 error |
| 13 | Bulk scanning: 3 concurrent scans | Pass | Completed in 16s |
| 14 | Live scanning: Solidity single scanner | Pass | End-to-end scan completes |
| 15 | Live scanning: Multi-scanner (6 scanners) | Pass | All 6 scanners return findings |
| 16 | Live scanning: Vyper contract | Pass | Vyper scanners return findings |
| 17 | Live scanning: Rust/Solana contract | Pass | Solana scanners return findings |
| 18 | Server header not disclosed | Pass | `server: uvicorn` removed from responses |
| 19 | Version bump consistency (pyproject → kustomization → docs) | Pass | api-service 0.29.6, tool-integration 0.5.3 synced across all files |

---

## Known Issues (Documented, Not Fixed)

| Issue | Severity | Notes |
|-------|----------|-------|
| 100% of vulnerabilities lack pattern_id/detector_id | Critical | Intelligence classification pipeline not enriching stored findings |
| AST fingerprints NULL for all vulnerabilities | High | AST fingerprinting defined but never populated |
| 762 vulnerabilities with detector names as scanner_id | Medium | SolidityDefend detector names stored instead of "soliditydefend" |
| Dedup maintenance CronJob intermittent failure | Medium | DeadlineExceeded (1hr timeout), normally completes in 23min |
| 7 scanners with 0 Harbor pulls | Low | May use containerd cache; not necessarily broken |
