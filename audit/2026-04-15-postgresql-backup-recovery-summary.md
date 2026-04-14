# PostgreSQL Backup Recovery — Resolution Summary

**Date:** 2026-04-15
**Status:** RESOLVED — backups verified end-to-end
**Original incident:** [`2026-04-15-postgresql-backup-cronjob-broken.md`](./2026-04-15-postgresql-backup-cronjob-broken.md)

## What Was Actually Broken (4 Layered Issues)

The "missing Secret" symptom hid three additional layers. Each layer would have failed the backup independently — fixing only the surface bug would have produced new failure modes.

| Layer | Symptom | Root Cause |
|-------|---------|-----------|
| 1 | `Error: secret "postgresql-secret" not found` | CronJob env referenced `postgresql-secret`; live cluster Secret is named `postgresql-credentials` |
| 2 | `password authentication failed for user "blocksecops"` | GCP Secret Manager key `apogee-gcp-postgres-password` had a stale value (`pC5W…`) that didn't match PostgreSQL's actual password (`CYY2…`, embedded in `apogee-gcp-database-url` which the API service uses) |
| 3 | `pg_hba.conf rejects connection ... no encryption` | pg_dump didn't enable SSL; PostgreSQL `hostssl` requires it |
| 4 | `connection to server at "postgresql" failed: Operation timed out` | `default-deny-all` NetworkPolicy in postgresql-prod denied egress; no NetworkPolicy granted the backup pod egress to PostgreSQL:5432, GCS:443, or the GKE Workload Identity metadata server |

Plus an operational issue:

| | Symptom | Root Cause |
|---|---------|-----------|
| 5 | `exceeded quota: pods=2/2` | Cluster-wide `resource-quota` limited postgresql-prod to 2 pods. With postgresql-0 occupying one slot, a single failing/retrying backup pod monopolized the second slot for 16+ hours, blocking new backup attempts |

## What Made This a 16+ Hour Silent Outage

Existing alerts cover pod readiness, crash loops, deployment mismatches, CPU throttling — none cover CronJob job failures or backup staleness. The failure mode (`Init:CreateContainerConfigError`) doesn't trigger any alert in the previous ruleset. The CronJob silently retried for 16 hours producing nothing visible.

## All Fixes Applied

### Code (Git, ready for PR)

| File | Change |
|------|--------|
| `blocksecops-gcp-infrastructure/k8s/overlays/production/postgresql/backup-cronjob.yaml` | Secret name `postgresql-secret` → `postgresql-credentials`; added `PGSSLMODE=require` env var |
| `blocksecops-gcp-infrastructure/k8s/overlays/production/postgresql/networkpolicy.yaml` | New `postgresql-backup-network-policy`: egress to PostgreSQL:5432, GCS:443, GKE metadata server (169.254.169.252:988 + 169.254.169.254:80), DNS |
| `blocksecops-gcp-infrastructure/k8s/overlays/production/postgresql/externalsecret.yaml` | Replaced stale Vault-based ExternalSecret with the GCP-Secret-Manager-based one that's actually live |
| `blocksecops-gcp-infrastructure/k8s/overlays/gcp/resource-controls/resource-quotas.yaml` | postgresql-prod entry: `pods: 2 → 4` (room for postgresql-0 + scheduled backup + manual/test/exporter pods) |
| `blocksecops-gcp-infrastructure/k8s/gcp/alerting/alerting-rules.yaml` | New `data-protection` alert group with 3 rules: `CronJobJobFailed`, `PostgreSQLBackupStale` (no successful backup in 25h), `CronJobPodConfigError` |

### GCP Secret Manager (live change)

- Created version 2 of `apogee-gcp-postgres-password` with the working password value (extracted from `apogee-gcp-database-url`)

### Cluster operations during recovery

- Force-synced `postgresql-credentials` ExternalSecret (annotated with `force-sync` to skip the 1-hour interval)
- Cleaned up multiple stuck/failed backup pods that were holding PVC attachments and quota slots

## Verification

```
$ gsutil ls -l gs://apogee-production-db-backups/postgresql/
   8035805  2026-04-14T19:59:21Z  postgresql-20260414-195053.sql.gz
   8035804  2026-04-14T19:59:21Z  postgresql-20260414-195731.sql.gz
TOTAL: 2 objects, 16071609 bytes (15.33 MiB)
```

```
$ kubectl get resourcequota -n postgresql-prod
NAME                        REQUEST                          LIMIT                  AGE
postgresql-resource-quota   pods: 1/10  …                    limits.cpu: 1/4  …     29d
resource-quota              pods: 1/4   …                    limits.cpu: 1/4  …     35d
```

```
$ kubectl get networkpolicy -n postgresql-prod
postgresql-backup-network-policy     app.kubernetes.io/name=postgresql-backup     50m   ← NEW
```

```
$ kubectl get clusterrules.monitoring.googleapis.com apogee-platform-alerts -o yaml | grep -E "PostgreSQLBackupStale|CronJobJobFailed|CronJobPodConfigError"
- alert: CronJobJobFailed         ← NEW
- alert: PostgreSQLBackupStale    ← NEW
- alert: CronJobPodConfigError    ← NEW
```

## Lessons Learned

1. **Layered defenses can hide upstream rot.** The Secret name was the surface failure; pulling on it revealed password drift, missing NetworkPolicy, missing SSL, missing alerting. Each fix unblocked the next failure.

2. **Silent failures are the worst kind.** No paging mechanism existed for "backup hasn't run." Now there is one. Going forward, every CronJob in `*-prod` should have a freshness alert.

3. **GCP Secret Manager has duplicate-key drift risk.** Two keys (`apogee-gcp-database-url` and `apogee-gcp-postgres-password`) hold the same logical password. Either consolidate to one or set up monitoring that fires when they diverge.

4. **`default-deny-all` namespaces need explicit egress allowlists for every workload type, including transient ones (CronJobs).** The backup CronJob was a workload type that didn't exist when the namespace's NetworkPolicies were originally written. New workloads in restricted namespaces need a NetworkPolicy as part of the deployment.

5. **GitOps drift compounds silently.** The cluster had ExternalSecret + ResourceQuota state that wasn't reflected in Git. When the active state diverges from Git, future deployments behave unpredictably. A regular drift audit (e.g., monthly `kubectl diff -k` per overlay) would catch this.

## Recommended Follow-up Work

1. **Drift audit cron** — weekly automated `kubectl diff -k` across all overlays; report mismatches to a dashboard or alert channel
2. **GCP Secret Manager key consolidation** — eliminate `apogee-gcp-postgres-password`; have all consumers read from `apogee-gcp-database-url` and parse the password component
3. **Backup restore drill** — schedule a quarterly DR exercise where we restore a backup from GCS to a test PostgreSQL instance and verify data integrity
4. **Add per-workload NetworkPolicy template** — every new CronJob/Job/Deployment in a deny-all namespace should ship with its own NetworkPolicy
5. **Audit all production CronJobs** — apply the same 4-layer review (Secret refs, password sync, SSL, NetworkPolicy egress, ResourceQuota headroom) to other CronJobs

## Cross-references

- Original incident: [`2026-04-15-postgresql-backup-cronjob-broken.md`](./2026-04-15-postgresql-backup-cronjob-broken.md)
- Playbook: `docs/playbooks/postgresql-backup-operations.md` (NEW — operational runbook)
- Disaster recovery: `docs/playbooks/disaster-recovery.md` (UPDATED — backup inventory)
- Standard: `docs/standards/database-management.md` (UPDATED — GCS backup status)
- Work summary: `TaskDocs-BlockSecOps/work-summaries/2026-04-15-postgresql-backup-recovery.md`
