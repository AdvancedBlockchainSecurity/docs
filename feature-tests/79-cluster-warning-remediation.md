# Feature Test: Cluster Warning Remediation

**Feature:** Celery worker liveness probe fix, vault secret sync fix, Docker cleanup
**Version:** api-service 0.29.27
**Date:** February 24, 2026
**Status:** Deployed and verified (all services healthy, 44/44 tier audit)

## Smoke Test Results (February 24, 2026)

Full platform smoke test after deployment (v0.29.27):

| Check | Result |
|-------|--------|
| All pods healthy | PASS |
| PostgreSQL running | PASS |
| Redis running | PASS |
| Vault unsealed | PASS |
| Traefik running | PASS |
| Database accessible | PASS |
| ExternalSecret synced | PASS |
| API health/ready | PASS (v0.29.27) |
| All 7 service health checks | PASS |
| All 9 image versions match | PASS |
| Tier audit (44 checks) | PASS |
| Disk usage | PASS (73%, down from 82%) |

## Celery Worker Liveness Probe

### Probe Configuration Verified

- [x] `celery inspect ping --timeout=10` (was 5s, subprocess needs 6-8s)
- [x] `timeoutSeconds: 15` exceeds celery --timeout by 5s
- [x] `periodSeconds: 120` (reduced frequency for long-running dedup tasks)
- [x] `failureThreshold: 3` (tolerates 3 consecutive failures = 6 min before kill)
- [x] `initialDelaySeconds: 30` (unchanged, sufficient for worker startup)

### CPU Request Verified

- [x] CPU request: 250m (was 100m, insufficient for 3 prefork workers)
- [x] CPU limit: 500m (unchanged)
- [x] Memory request: 256Mi (unchanged)
- [x] Memory limit: 512Mi (unchanged)

### Post-Deployment Verification

- [x] No new `Liveness probe failed` events from current pod
- [x] Old probe failure events are from terminated pod (pre-fix)
- [x] Celery worker pod: 1/1 Running, 0 restarts
- [x] Image: `harbor.0xapogee.local/blocksecops/api-service:0.29.27`

## ExternalSecret Sync

### Vault Secrets Seeded

- [x] `secret/local/api-service/oauth/github` — client_id, client_secret
- [x] `secret/local/api-service/oauth/gitlab` — client_id, client_secret
- [x] `secret/local/api-service/oauth/bitbucket` — client_id, client_secret
- [x] `secret/local/api-service/oauth/jira` — client_id, client_secret
- [x] `secret/local/api-service/encryption` — key
- [x] `secret/local/api-service/internal` — service_key
- [x] `secret/local/api-service/supabase` — anon_key, service_key
- [x] `secret/local/api-service/stripe` — api_key, webhook_secret
- [x] `secret/local/api-service/jira` — base_url, api_email, api_token, project_key
- [x] `secret/local/api-service/anthropic` — api_key

### Sync Status

- [x] ExternalSecret: `SecretSynced` / `Ready: True`
- [x] No `error processing spec.data` events from current ExternalSecret
- [x] Old sync error events are from pre-fix (before vault secrets seeded)

## Docker Cleanup

- [x] `docker image prune -a --force` — removed unused images
- [x] `docker builder prune -a --force` — cleared 30GB build cache
- [x] Disk usage: 82% → 73% (recovered ~41GB)

## Unit Tests

15 structural tests in `tests/unit/infrastructure/test_celery_worker_deployment.py`:

- [x] TestCeleryLivenessProbe (5 tests) — probe command, timeouts, period, failure threshold
- [x] TestCeleryResources (3 tests) — CPU >= 200m, memory >= 256Mi, limit >= 512Mi
- [x] TestCeleryConcurrency (3 tests) — --concurrency flag, matches celery_app.py, dedup queue
- [x] TestCelerySecurityContext (4 tests) — non-root, no escalation, read-only fs, drops ALL caps
- [x] Full suite: 1047 passed, 0 failed, 24 skipped

## Known Non-Issues

| Warning | Status | Reason |
|---------|--------|--------|
| HPA custom metrics unavailable | Expected | Prometheus/prometheus-adapter disabled by default for local dev |
| API startup probe failures | Transient | Normal during rollout; probe tolerates slow startup |

## Version History

| Version | PR | Changes |
|---------|-----|---------|
| 0.29.27 | #262 | Celery probe timeouts + CPU request + 15 unit tests |
