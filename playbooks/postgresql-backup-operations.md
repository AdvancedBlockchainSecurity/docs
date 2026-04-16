# PostgreSQL Backup Operations Playbook

Operational runbook for the production PostgreSQL backup CronJob. Covers daily operations, manual triggers, troubleshooting, and restore procedures.

**Related:**
- `docs/playbooks/disaster-recovery.md` — full disaster recovery scenarios
- `docs/audit/2026-04-15-postgresql-backup-recovery-summary.md` — incident postmortem
- `docs/standards/database-management.md` — backup standards
- `docs/playbooks/gcp-secret-drift-validation-cron.md` — sibling CronJob `gcp-secret-drift-check` (deployed 2026-04-15) co-located in `postgresql-prod`. Weekly read-only comparison of the two GCP Secret Manager entries that feed this backup's authentication. Fires `GCPSecretDrift` (critical) ~24h before the next backup would fail auth — the specific pre-failure signal for the 2026-04-15 outage class.
- `docs/workflows/new-cronjob-deployment.md` — pattern followed by the sibling cron above

## Backup Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  CronJob: postgresql-backup  (schedule: 0 2 * * * UTC, daily)   │
│  ├── initContainer: pg-dump (postgres:15.4-alpine)              │
│  │     • PGSSLMODE=require                                       │
│  │     • Reads creds from Secret postgresql-credentials          │
│  │     • Writes /backup/postgresql-YYYYMMDD-HHMMSS.sql, gzips   │
│  │     • Retains 7 days locally on PVC                           │
│  └── container: gcs-upload (google/cloud-sdk:slim)               │
│        • Workload Identity → apogee-gcp-backup GSA               │
│        • Uploads /backup/*.sql.gz to                             │
│          gs://apogee-production-db-backups/postgresql/           │
└─────────────────────────────────────────────────────────────────┘
```

| Component | Value |
|-----------|-------|
| Namespace | `postgresql-prod` |
| CronJob | `postgresql-backup` |
| ServiceAccount | `postgresql-backup` (KSA, Workload-Identity-bound to GSA `apogee-gcp-backup`) |
| Secret | `postgresql-credentials` (synced from GCP Secret Manager via ExternalSecret) |
| Backup PVC | `postgresql-backup-pvc` (20 Gi, ReadWriteOnce) |
| GCS bucket | `gs://apogee-production-db-backups/postgresql/` |
| Local retention | 7 days (CronJob deletes older `*.sql.gz` from PVC) |
| GCS retention | Bucket lifecycle policy (separate config) |

## Daily Operations

### Verify last successful backup

```bash
# Most recent backup in GCS
gsutil ls -l gs://apogee-production-db-backups/postgresql/ | tail -3

# CronJob last-scheduled time
kubectl get cronjob postgresql-backup -n postgresql-prod

# Most recent job + its outcome
kubectl get jobs -n postgresql-prod | grep postgresql-backup | head -3
```

A healthy state shows: most recent backup is within the last 24 hours, `kube_job_status_succeeded` for the latest job, GCS upload completed.

### Manually trigger a backup

```bash
TS=$(date +%s)
kubectl create job --from=cronjob/postgresql-backup \
  postgresql-backup-manual-$TS -n postgresql-prod

# Watch progress
kubectl wait --for=condition=complete \
  job/postgresql-backup-manual-$TS -n postgresql-prod --timeout=300s

# Check logs
POD=$(kubectl get pods -n postgresql-prod -l job-name=postgresql-backup-manual-$TS -o name | head -1)
kubectl logs $POD -n postgresql-prod -c pg-dump
kubectl logs $POD -n postgresql-prod -c gcs-upload
```

## Troubleshooting

### Symptom: Pod stuck in `Init:CreateContainerConfigError`

**Cause:** Missing Secret, ConfigMap, or volume claim referenced by the pod spec.

**Diagnose:**
```bash
kubectl describe pod <pod> -n postgresql-prod | grep -A2 "Events:"
```

Look for `Error: secret "..." not found` or similar.

**Fix:**
- Verify Secret exists: `kubectl get secret postgresql-credentials -n postgresql-prod`
- Verify the CronJob env references the correct Secret name (`postgresql-credentials`, NOT `postgresql-secret`)
- Check the ExternalSecret synced successfully: `kubectl get externalsecret postgresql-credentials -n postgresql-prod`

### Symptom: pg_dump fails with `password authentication failed`

**Cause:** The Secret's `POSTGRES_PASSWORD` doesn't match PostgreSQL's actual password.

**Diagnose:**
```bash
# Get secret password
SECRET_PW=$(kubectl get secret postgresql-credentials -n postgresql-prod -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d)

# Try connecting from postgresql-0 directly
kubectl exec -n postgresql-prod postgresql-0 -- bash -c \
  "PGPASSWORD='$SECRET_PW' psql -h localhost -U blocksecops -d solidity_security -c 'SELECT 1;'"
```

If this fails, the Secret is out of sync with the actual DB password. Compare against the API service:
```bash
kubectl get secret api-service-secret -n api-service-prod \
  -o jsonpath='{.data.DATABASE_URL}' | base64 -d | \
  python3 -c "import sys, re; m=re.search(r':([^@:]+)@', sys.stdin.read()); print(m.group(1)[:6]+'...' if m else '')"
```

If the API service has a different password and it works, **the GCP Secret Manager value is stale**. Fix:
```bash
# Extract working password from API service
WORKING_PW=$(kubectl get secret api-service-secret -n api-service-prod \
  -o jsonpath='{.data.DATABASE_URL}' | base64 -d | \
  python3 -c "import sys, re; m=re.search(r':([^@:]+)@', sys.stdin.read()); print(m.group(1), end='')")

# Update GCP Secret Manager (REQUIRES RULE 0 OWNER APPROVAL)
echo -n "$WORKING_PW" | gcloud secrets versions add apogee-gcp-postgres-password --data-file=-

# Force ExternalSecret resync
kubectl annotate externalsecret postgresql-credentials -n postgresql-prod \
  force-sync="$(date +%s)" --overwrite
```

### Symptom: pg_dump fails with `pg_hba.conf rejects connection ... no encryption`

**Cause:** PostgreSQL requires `hostssl` for cluster connections; pg_dump didn't enable SSL.

**Fix:** Confirm CronJob env includes `PGSSLMODE=require`:
```bash
kubectl get cronjob postgresql-backup -n postgresql-prod -o yaml | grep -A1 PGSSLMODE
```

Should show `value: "require"`. If missing, add it to `backup-cronjob.yaml` env list.

### Symptom: `Operation timed out` connecting to `postgresql:5432`

**Cause:** NetworkPolicy denies egress from backup pod to PostgreSQL.

**Verify:**
```bash
kubectl get networkpolicy postgresql-backup-network-policy -n postgresql-prod -o yaml
```

Should have egress rules for:
- DNS (UDP/TCP 53)
- PostgreSQL podSelector on TCP 5432
- GKE metadata server (169.254.169.252:988 + 169.254.169.254:80)
- HTTPS 443 to internet (for GCS)

If missing, the NetworkPolicy was deleted. Re-apply from Git.

### Symptom: gcs-upload fails with `Anonymous caller does not have storage.objects.create access`

**Cause:** Workload Identity not propagating, OR egress to GKE metadata server (169.254.169.252:988) is blocked.

**Diagnose:**
```bash
# Check ServiceAccount has the correct annotation
kubectl get serviceaccount postgresql-backup -n postgresql-prod -o yaml | grep iam.gke.io

# Check GSA exists and has bucket access
gcloud storage buckets get-iam-policy gs://apogee-production-db-backups | \
  grep -A1 apogee-gcp-backup
```

Should show `roles/storage.objectAdmin` for `apogee-gcp-backup@…iam.gserviceaccount.com`.

**Most common fix:** the NetworkPolicy doesn't allow egress to the GKE metadata server. Verify `postgresql-backup-network-policy` has the `169.254.169.252/32:988` egress rule.

### Symptom: `exceeded quota: pods=2/2`

**Cause:** Namespace `resource-quota` set too low; failing/retrying backup pods accumulated.

**Diagnose:**
```bash
kubectl get resourcequota -n postgresql-prod
```

The namespace has TWO quotas: `postgresql-resource-quota` (10 pods, designed for the workload) AND `resource-quota` (4 pods, cluster-wide cost-control pattern). Kubernetes uses the most restrictive.

**Quick mitigation (if backups are failing now):**
- Clean up stuck pods: `kubectl delete pod <stuck-pod-name> -n postgresql-prod --grace-period=0 --force`

**Permanent fix:**
- Bump the postgresql-prod entry in `k8s/overlays/gcp/resource-controls/resource-quotas.yaml`

### Symptom: PVC `Multi-Attach` error

**Cause:** Backup PVC is `ReadWriteOnce`; another backup pod still has it attached.

**Diagnose:**
```bash
kubectl describe pvc postgresql-backup-pvc -n postgresql-prod | grep -A1 "Used By:"
```

**Fix:** Find and delete the older job whose pod still holds the attachment:
```bash
# Find old jobs
kubectl get jobs -n postgresql-prod | grep postgresql-backup

# Delete the pod's parent job (deletes pod automatically)
kubectl delete job <old-job-name> -n postgresql-prod
```

## Restore from GCS Backup

For full restore procedures, see `docs/playbooks/disaster-recovery.md`. Quick reference:

```bash
# 1. List available backups
gsutil ls -l gs://apogee-production-db-backups/postgresql/

# 2. Download a backup locally
gsutil cp gs://apogee-production-db-backups/postgresql/postgresql-YYYYMMDD-HHMMSS.sql.gz \
  /tmp/restore.sql.gz

# 3. Decompress
gunzip /tmp/restore.sql.gz

# 4. Copy into postgresql-0 pod
kubectl cp /tmp/restore.sql postgresql-prod/postgresql-0:/tmp/restore.sql

# 5. Restore (DESTRUCTIVE — coordinate downtime)
kubectl exec -n postgresql-prod postgresql-0 -- bash -c \
  "PGPASSWORD='$DB_PW' psql -h localhost -U blocksecops -d solidity_security -f /tmp/restore.sql"
```

## Alerting

Three alerts cover this CronJob (added 2026-04-15, see `k8s/gcp/alerting/alerting-rules.yaml` `data-protection` group):

| Alert | Condition | Severity | Action |
|-------|-----------|----------|--------|
| `CronJobJobFailed` | Any production CronJob has > 0 failed jobs for 5+ min | warning | Investigate via `kubectl describe job …` |
| `PostgreSQLBackupStale` | No successful postgresql-backup in 25+ hours | critical | Use this playbook's troubleshooting section |
| `CronJobPodConfigError` | Pod stuck in `CreateContainerConfigError` for 5+ min | warning | Check Secret/ConfigMap references |

## When to Update This Playbook

- After any backup-related incident
- When the CronJob spec changes (schedule, retention, image)
- When a new failure mode is discovered
- When GCP Secret Manager keys are renamed or restructured
