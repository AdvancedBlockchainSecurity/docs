# API Service v0.29.27 - Cluster Warning Remediation

**Date:** February 24, 2026
**Version:** 0.29.27
**Type:** Bug fix / Infrastructure (PATCH)
**PR:** api-service #262

## Summary

Fixed celery worker liveness probe false-positive pod kills and ExternalSecret sync errors discovered during comprehensive cluster health check. Updated vault init script with 10 missing secret paths added during security hardening (v0.29.20+). Recovered ~41GB disk space via Docker cleanup.

## Root Cause Analysis

### Celery Liveness Probe Timeout (High)

The `celery inspect ping` command spawns a subprocess that must import the entire Python/Celery runtime before executing. This import overhead alone takes 4-5s. The original probe had `--timeout=5` and `timeoutSeconds=10`, leaving only ~5s headroom. Under dedup task load with 3 concurrent prefork workers at only 100m CPU request, CPU contention pushed total probe execution past 10s — triggering Kubernetes to kill a healthy pod.

### ExternalSecret Sync Failure (High)

The `init-vault-local.sh` script was written before v0.29.20 security hardening. During hardening, 10 new vault paths were added to the ExternalSecret spec (per-provider OAuth, encryption, internal service key, supabase, stripe, jira, anthropic) but the vault init script was never updated to seed them. The ExternalSecret expected 24 keys but Vault only had ~8, causing `error processing spec.data[14]` on every 15s refresh.

### Disk Usage at 82% (Medium)

Accumulated Docker build cache (30GB) and unused images (~49GB reclaimable) from iterative development builds across 20+ services. No automated cleanup schedule in place.

## Changes

### Celery Worker Deployment (`k8s/base/api-service/deployment-celery-worker.yaml`)

| Setting | Before | After | Rationale |
|---------|--------|-------|-----------|
| `--timeout` | 5s | 10s | Subprocess needs 6-8s (4-5s import + 2-3s ping) |
| `timeoutSeconds` | 10s | 15s | 5s headroom over celery timeout |
| `periodSeconds` | 60s | 120s | Dedup tasks are long-running; 2 min is sufficient |
| CPU request | 100m | 250m | 3 prefork workers need more baseline CPU |

### Vault Init Script (`docs/scripts/init-vault-local.sh`)

Replaced generic `secret/local/api-service/oauth` with per-provider entries and added 10 missing paths:

| Vault Path | Keys | Purpose |
|------------|------|---------|
| `secret/local/api-service/oauth/github` | client_id, client_secret | GitHub OAuth |
| `secret/local/api-service/oauth/gitlab` | client_id, client_secret | GitLab OAuth |
| `secret/local/api-service/oauth/bitbucket` | client_id, client_secret | Bitbucket OAuth |
| `secret/local/api-service/oauth/jira` | client_id, client_secret | JIRA OAuth |
| `secret/local/api-service/encryption` | key | MFA secrets, OAuth token encryption |
| `secret/local/api-service/internal` | service_key | Service-to-service auth |
| `secret/local/api-service/supabase` | anon_key, service_key | Supabase credentials |
| `secret/local/api-service/stripe` | api_key, webhook_secret | Stripe billing |
| `secret/local/api-service/jira` | base_url, api_email, api_token, project_key | JIRA support |
| `secret/local/api-service/anthropic` | api_key | Claude AI features |

### Version Bump

- `pyproject.toml`: 0.29.26 → 0.29.27
- `k8s/overlays/local/api-service/kustomization.yaml`: newTag 0.29.26 → 0.29.27

## Unit Tests

15 new structural tests in `tests/unit/infrastructure/test_celery_worker_deployment.py`:

| Test Class | Tests | Validates |
|------------|-------|-----------|
| TestCeleryLivenessProbe | 5 | Probe command, celery timeout >= 10s, k8s timeout > celery timeout, period >= 60s, failure threshold >= 3 |
| TestCeleryResources | 3 | CPU request >= 200m, memory request >= 256Mi, memory limit >= 512Mi |
| TestCeleryConcurrency | 3 | --concurrency flag present, matches celery_app.py, dedicated dedup queue |
| TestCelerySecurityContext | 4 | Non-root, no privilege escalation, read-only root filesystem, drops ALL capabilities |

Full suite: 1047 passed, 0 failed, 24 skipped.

## Verification

- Celery worker: no new probe timeout warnings after deployment
- ExternalSecret: `SecretSynced` / `Ready: True`
- Disk: 82% → 73% (recovered ~41GB)
- Smoke test: all services healthy, v0.29.27 confirmed
- Tier audit: 44/44 checks passed
