# CRITICAL FINDING: Production PostgreSQL Backup CronJob Broken

**Date discovered:** 2026-04-15
**Severity:** CRITICAL — production data at risk
**Status:** **RESOLVED 2026-04-15** (backups verified end-to-end; 16 MB across 2 files now in GCS)
**Discovered during:** Standards-compliance audit while attempting to take a baseline backup before establishing the practice going forward
**Cross-reference:** [`2026-04-15-postgresql-backup-recovery-summary.md`](./2026-04-15-postgresql-backup-recovery-summary.md) — the resolution audit

## Symptom

The `postgresql-backup` CronJob in `postgresql-prod` namespace has been failing to start backup pods for at least 16+ hours. Effect: **no production PostgreSQL backups have been taken**.

## Root Cause

The CronJob's pod template references Secret `postgresql-secret` for credentials, but the actual Secret in the namespace is named `postgresql-credentials`:

```bash
$ kubectl get secrets -n postgresql-prod | grep -i postgres
postgresql-credentials   Opaque              3      35d
postgresql-tls           kubernetes.io/tls   3      35d
```

The CronJob's pod template (`backup-cronjob.yaml` in `blocksecops-gcp-infrastructure/k8s/overlays/production/postgresql/`) references `postgresql-secret`, which does not exist. Each scheduled backup pod fails to start with:

```
Error: secret "postgresql-secret" not found
```

The pod retries indefinitely (the most recent failed pod retried 4,474 times over 16h before being cleaned up during this audit).

## Compounding Issue: ResourceQuota conflict

Two ResourceQuotas exist in `postgresql-prod`, with conflicting limits:

| ResourceQuota | Pod Limit | Source |
|---------------|-----------|--------|
| `postgresql-resource-quota` | 10 | Designed quota (in Git) |
| `resource-quota` | **2** | Likely orphaned, pre-dates the designed quota |

Kubernetes uses the most restrictive limit, so effectively the namespace allows only 2 pods. With `postgresql-0` running, only 1 backup pod can ever exist at a time. The stuck-failing backup pod monopolized this slot, blocking new manual backup attempts during this audit.

## Impact

- **Zero production PostgreSQL backups for at least 16 hours.** Could be longer; this is when I discovered the issue.
- Database recovery is impossible without backups (per `database-management.md`: "Data loss is NOT acceptable").
- Any major incident (corruption, accidental delete, infrastructure failure) in this window would have resulted in **permanent data loss**.

## Mitigation Taken (2026-04-15)

1. Cleaned up the stuck failing backup pod
2. Took a manual baseline backup directly via `kubectl exec postgresql-0 -- pg_dump`
3. Copied the backup to local filesystem at `/tmp/postgresql-baseline-2026-04-14.dump.gz` (8.1 MB compressed, gzip integrity verified)

This is a **temporary baseline only** — not a sustainable solution.

## Update 2026-04-15 — Investigation revealed deeper layer

While executing Phase 1 (Secret name fix), three additional issues were discovered that all contributed to the silent failure:

### Additional Issue A: Missing NetworkPolicy egress for backup pod
`postgresql-prod` has `default-deny-all` for ingress + egress. Five other NetworkPolicies grant specific exceptions, but **none grant the backup pod egress to PostgreSQL:5432 or GCS:443**. Even with the correct Secret name, the backup pod could not reach PostgreSQL.

**Fixed:** Added `postgresql-backup-network-policy` in `networkpolicy.yaml` (egress to DNS, postgresql:5432, internet:443).

### Additional Issue B: Resource quota too low for backup workload
The cluster-wide `resource-quota` (NOT the postgresql-specific `postgresql-resource-quota`) was set to 2 pods for postgresql-prod. With postgresql-0 occupying one slot, only one backup pod can ever exist — a failing/retrying pod monopolizes the slot, blocking new attempts indefinitely.

**Fixed:** Bumped `pods` from 2 → 4 in `k8s/overlays/gcp/resource-controls/resource-quotas.yaml` (postgresql-prod entry).

### Additional Issue C (CRITICAL): GCP Secret Manager password drift — STILL UNRESOLVED

Two separate GCP Secret Manager keys hold the PostgreSQL password:

| Secret Manager Key | Used By | Synced Password | Works Against PostgreSQL? |
|--------------------|---------|-----------------|---------------------------|
| `apogee-gcp-database-url` | `api-service-secret` ExternalSecret in `api-service-prod` | `CYY2...` (in URL) | YES — API service connects fine |
| `apogee-gcp-postgres-password` | `postgresql-credentials` ExternalSecret in `postgresql-prod` | `pC5W...` | **NO — authentication failed** |

The PostgreSQL `blocksecops` user's actual password matches `CYY2...`. The `apogee-gcp-postgres-password` Secret Manager key is stale.

**This means even with a correct Secret name (Issue 1) and NetworkPolicy (A) and Resource Quota (B), backups would still fail at password authentication.**

**Required fix (NEEDS OWNER APPROVAL — touches production GCP Secret Manager):**

Either:
1. Update `apogee-gcp-postgres-password` in GCP Secret Manager to match the actual PostgreSQL password (the value the API service uses, retrievable from `kubectl get secret api-service-secret -n api-service-prod -o jsonpath='{.data.DATABASE_URL}' | base64 -d`).

OR

2. Refactor `postgresql-credentials` ExternalSecret to read from `apogee-gcp-database-url` instead, and template-extract the password component. More complex, but eliminates the duplicate-key drift potential.

OR

3. Rotate the actual PostgreSQL `blocksecops` password to a fresh value, update BOTH GCP Secret Manager keys (`apogee-gcp-database-url` and `apogee-gcp-postgres-password`) to that value, then restart api-service to pick up the new password. Cleanest but most disruptive.

Recommend option 1 (lowest disruption: update one Secret Manager value, no app restart needed).

## Status of Original 4 Fixes

| # | Fix | Status |
|---|-----|--------|
| 1 | CronJob Secret name `postgresql-secret` → `postgresql-credentials` | DONE in Git + applied |
| A | Add `postgresql-backup-network-policy` for backup pod egress | DONE in Git + applied |
| B | Bump postgresql-prod `resource-quota` from 2 → 4 pods | DONE in Git + applied |
| 1.1 | Add `PGSSLMODE=require` env var (PostgreSQL requires hostssl) | DONE in Git + applied |
| C | GCP Secret Manager password drift | **PAUSED — needs owner direction** |
| 2 | Reconcile ExternalSecret drift (Vault → GCP Secret Manager) in Git | Not yet applied — pending C resolution |
| 4 | Add backup-failure alerting (3 PromRules) | Not yet applied — Phase 4 of plan |

## Required Fixes (NEED OWNER APPROVAL — Rule 0)

### Fix 1: Backup CronJob Secret reference

**File:** `blocksecops-gcp-infrastructure/k8s/overlays/production/postgresql/backup-cronjob.yaml`

Update the Secret reference from `postgresql-secret` → `postgresql-credentials` (or rename the Secret to match — but renaming would also require updating every other consumer).

Recommended: update the CronJob to reference `postgresql-credentials`.

### Fix 2: Remove the orphaned ResourceQuota

**Investigation:** Determine where `resource-quota` (the 2-pod limit) was created. Likely an artifact from an earlier deployment that wasn't cleaned up. The designed quota `postgresql-resource-quota` (10 pods) should be the only one.

```bash
kubectl get resourcequota resource-quota -n postgresql-prod -o yaml
# Confirm it's not in any current Git manifest
# If orphaned, remove it via kubectl delete (or document as intentional and bump postgresql-resource-quota down)
```

### Fix 3: Add backup-success alerting

The CronJob has been silently failing for 16+ hours with no alert. Add a Prometheus/Alertmanager rule:
- Alert if a backup hasn't completed successfully in the last 25 hours (allows for the daily cadence + buffer)
- Alert if the most recent backup pod is in `Failed`/`CrashLoopBackOff`/`Init:CreateContainerConfigError` state

### Fix 4: Re-run the manual baseline backup with proper destination

The current baseline backup is on the operator's laptop (`/tmp/...`). It should be in GCS for durability. Not actionable until Fix 1 lands and the CronJob writes to its proper destination.

## Standards Violated

- `docs/standards/database-management.md` — "Data loss is NOT acceptable" / "Pending: GCS-based backup CronJob" — the GCS-based CronJob exists in Git but is broken in production
- `docs/standards/core-development-rules.md` Rule 1 — codebase-first: the broken state suggests a Secret was renamed in production without updating the CronJob in Git, OR the CronJob was created referring to a Secret name that never existed in this namespace

## Audit Trail

| Time | Event |
|------|-------|
| ~2026-04-13 (or earlier) | Backup pods began failing to start due to missing Secret |
| 2026-04-14 02:00 | Most recent scheduled CronJob run (last `kubectl get cronjob LAST SCHEDULE`) — also failed |
| 2026-04-15 12:13 | Discovered during standards-compliance audit |
| 2026-04-15 12:14 | Cleaned up stuck pod |
| 2026-04-15 12:14 | Manual baseline backup taken via kubectl exec, saved locally |
| TBD | Fix 1 (Secret reference) — pending owner approval |
| TBD | Fix 2 (ResourceQuota cleanup) — pending owner approval |
| TBD | Fix 3 (alerting) — pending owner approval |

## Cross-references

- `docs/standards/database-management.md`
- `blocksecops-gcp-infrastructure/k8s/overlays/production/postgresql/backup-cronjob.yaml` (the broken file)
- `docs/audit/2026-04-13-scanner-pipeline-and-platform-improvements.md` (where SSL fix was made)
