# PostgreSQL SSL Enablement & Platform Health Check

**Date:** February 22, 2026
**Services Affected:** postgresql, data-service, notification, orchestration, tool-integration
**Type:** Infrastructure / Security

## Summary

Enabled PostgreSQL SSL in local development environment using cert-manager certificates, restored `/health` endpoints removed during previous session, fixed vault-policy job namespace issue, and resolved failed deduplication CronJobs.

## Changes

### PostgreSQL SSL Enablement

- **configmap-patch.yaml** (local overlay): Changed `ssl = off` to `ssl = on` with cert-manager certificate paths at `/etc/postgresql/certs-fixed/`
- **pg_hba.conf**: Updated from `host` (trust, no SSL requirement) to `hostssl` (require SSL) for all cluster connection ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16), added `hostnossl ... reject` for all network connections
- **statefulset-patch.yaml**: Added `fix-tls-permissions` initContainer to copy TLS certs from secret volume to emptyDir with correct permissions (key=0600, certs=0644). Restored `command: [postgres, -c, config_file=..., -c, hba_file=...]` to use mounted ConfigMap instead of docker-entrypoint.sh defaults
- **postgresql.conf**: Added `ssl_min_protocol_version = 'TLSv1.2'` and `password_encryption = scram-sha-256`

### Health Endpoint Restoration

Restored `/health` endpoints on three services that were removed in a previous session but were actively used by Docker HEALTHCHECK, ALB ingress annotations, and GCP overlay probes:

| Service | Version Bump | Change |
|---------|-------------|--------|
| data-service | 0.2.0 -> 0.2.1 | Restored `/health` endpoint |
| notification | 0.2.0 -> 0.2.1 | Restored `/health` endpoint |
| orchestration | 0.10.1 -> 0.10.2 | Restored `/health` endpoint |
| tool-integration | 0.5.3 -> 0.5.4 | Version bump for consistency |

### Vault-Policy Job Fix

- **Root cause:** Kustomize `namespace:` field was overriding the vault-policy Job's explicit `namespace: vault-local` to the service namespace (e.g., `postgresql-local`), but the Job requires the `vault` ServiceAccount and vault PVC which only exist in `vault-local`
- **Fix:** Removed vault-policy.yaml from postgresql and redis kustomization.yaml resources; apply vault-policy resources directly to `vault-local` via `kubectl apply -f`
- Both vault-policy-postgresql and vault-policy-redis completed successfully in 4 seconds

### Deduplication CronJob Fix

- **Root cause:** Failed jobs were using stale image tag `0.29.5` (created before CronJob spec update to `0.29.7`)
- **Fix:** Deleted the 2 failed jobs and triggered a manual test with correct `0.29.7` image
- Manual test job running successfully with correct image

## Verification

- PostgreSQL `SHOW ssl` returns `on`
- PostgreSQL `SHOW config_file` returns `/etc/postgresql/postgresql.conf` (mounted ConfigMap)
- 4 active SSL connections from services confirmed via `pg_stat_ssl`
- TLS key permissions: 0600, owned by postgres
- All 5 services reporting healthy
- 15/15 scanners available
- 41 pods running, 0 errors

## Documentation Updated

- `docs/standards/docker-image-versioning.md` - Updated Current Service Versions table
- `docs/standards/database-management.md` - Added SSL/TLS Configuration section (v2.0.0)
- `docs/standards/local-development-setup.md` - Updated TLS/SSL parity from "optional" to "enabled"
- `docs/standards/port-forwarding.md` - Updated health endpoint paths for orchestration, notification, data-service
- `docs/standards/smoke-test.md` - Updated internal health check URLs to use `/health` endpoints

## Files Modified

### blocksecops-gcp-infrastructure
- `k8s/overlays/local/postgresql/configmap-patch.yaml` - SSL enabled, pg_hba.conf updated
- `k8s/overlays/local/postgresql/statefulset-patch.yaml` - initContainer added, command restored
- `k8s/overlays/local/postgresql/kustomization.yaml` - Removed vault-policy.yaml from resources
- `k8s/overlays/local/redis/kustomization.yaml` - Removed vault-policy.yaml from resources

### Service Repositories
- `blocksecops-data-service/src/main.py` - Restored `/health` endpoint
- `blocksecops-data-service/pyproject.toml` - 0.2.0 -> 0.2.1
- `blocksecops-data-service/k8s/overlays/local/kustomization.yaml` - Updated version
- `blocksecops-notification/src/main.py` - Restored `/health` endpoint
- `blocksecops-notification/pyproject.toml` - 0.2.0 -> 0.2.1
- `blocksecops-notification/k8s/overlays/local/kustomization.yaml` - Updated version
- `blocksecops-orchestration/src/blocksecops_orchestration/api/main.py` - Restored `/health` endpoint
- `blocksecops-orchestration/pyproject.toml` - 0.10.1 -> 0.10.2
- `blocksecops-orchestration/k8s/overlays/local/orchestration/kustomization.yaml` - Updated version
- `blocksecops-tool-integration/pyproject.toml` - 0.5.3 -> 0.5.4
- `blocksecops-tool-integration/k8s/overlays/local/kustomization.yaml` - Updated version
