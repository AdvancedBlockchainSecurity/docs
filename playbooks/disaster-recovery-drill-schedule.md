# Disaster Recovery Drill Schedule

**Status:** Active
**Last Updated:** 2026-04-15
**Cadence:** Quarterly
**Owner:** Platform Operator

## Why a recurring drill?

Backups that have never been restored are not backups. The 2026-04-15 PostgreSQL backup recovery incident exposed two compounding gaps:
1. The CronJob had been silently failing for 16+ hours — backups didn't exist
2. There was no scheduled exercise that would have caught (1) before a real incident needed it

Adding alerting (`PostgreSQLBackupStale`, `CronJobJobFailed`, `CronJobPodConfigError`) covers gap (1). This drill schedule covers gap (2) — confirming backups are actually recoverable on a regular cadence.

## Drill cadence

| Quarter | Drill | Focus |
|---------|-------|-------|
| Q1 (Jan/Feb/Mar) | **Backup restoration** | Restore latest GCS backup to a temp DB; row-count parity check |
| Q2 (Apr/May/Jun) | **Pod failure recovery** | `kubectl delete pod` random workload; verify auto-recovery + alerting fires |
| Q3 (Jul/Aug/Sep) | **Secret rotation** | Rotate JWT signing secret; verify session re-auth works; audit logs |
| Q4 (Oct/Nov/Dec) | **Full cluster rebuild** | Rebuild local cluster from scratch using disaster-recovery.md Scenario 3; time the process |

Schedule the drill in the **third week of the second month of each quarter** — late enough that quarter-start projects are settled, early enough that follow-up fixes can land before the quarter closes.

Next drills (live calendar):

| Date | Drill | Owner |
|------|-------|-------|
| 2026-05-20 | Q2 — Pod failure recovery | Platform Operator |
| 2026-08-19 | Q3 — Secret rotation | Platform Operator |
| 2026-11-18 | Q4 — Full cluster rebuild | Platform Operator |
| 2027-02-17 | Q1 — Backup restoration | Platform Operator |

## Q1 — Backup restoration drill

**Goal:** verify the latest production PostgreSQL backup in GCS is recoverable and contains all expected data.

**Procedure** (~30 min):

1. **Pick a backup** — list `gs://apogee-production-db-backups/postgresql/` and choose the most recent one
2. **Download + decompress** to a Cloud Shell or local workstation
3. **Restore to a throw-away DB** in production via `kubectl exec postgresql-0 …`:
   - `CREATE DATABASE drill_restore;`
   - `pg_restore -d drill_restore` (no overwrite of `solidity_security`)
4. **Compare row counts** between `solidity_security` and `drill_restore` for: `users`, `contracts`, `scans`, `api_keys`, `vulnerabilities`. Tolerate small deltas for tables added since the backup was taken (e.g., new tables created by recent migrations).
5. **Drop** `drill_restore` and clean up the local download

**Acceptance criteria:**
- Backup file downloads successfully (no IAM denial)
- pg_restore completes without errors
- Core table row counts within ±1% of live (allowing for in-flight rows since backup time)
- Drill completed within 30 min

**Documentation:** record results in `docs/audit/<YYYY-MM-DD>-q1-restore-drill.md`. If anything fails, file a follow-up issue and don't close the drill until the underlying problem is fixed.

## Q2 — Pod failure recovery drill

**Goal:** verify auto-recovery for stateless workloads + that alerting fires for non-recoverable pod states.

**Procedure** (~20 min):

1. Pick a stateless workload (e.g., `api-service`); confirm replicas ≥ 2
2. `kubectl delete pod <pod> -n api-service-prod` → expect new pod within 60s
3. Monitor `/api/v1/health/ready` from outside — should never return non-200 (rolling replacement)
4. Trigger an unrecoverable state: `kubectl set image deployment/api-service api-service=us-west1-docker.pkg.dev/.../api-service:does-not-exist -n api-service-prod`
5. Verify the `PodCrashLooping` (or equivalent) alert fires within 5 min
6. Roll back: `kubectl rollout undo deployment/api-service -n api-service-prod`

**Acceptance criteria:** zero user-visible downtime during pod delete; alert fires within SLO for unrecoverable state; rollback restores service in < 60s.

## Q3 — Secret rotation drill

**Goal:** verify secret rotation procedures work end-to-end without dropping live sessions.

**Procedure** (~45 min): see `docs/playbooks/secret-rotation.md` for the full procedure. Drill version exercises the JWT signing key only:

1. Generate new JWT secret value
2. Add new version to GCP Secret Manager → ExternalSecret syncs → api-service Pods restart
3. Validate: existing sessions invalidated, new logins work, no 5xx spike in metrics

## Q4 — Full cluster rebuild drill

**Goal:** validate the local-cluster rebuild path documented in `docs/playbooks/disaster-recovery.md` Scenario 3 still works.

**Procedure** (~2-4 hr): execute Scenario 3 against a sandbox cluster, time each phase, update the playbook for any drift discovered.

## Recording results

Every drill produces:
- A timestamped audit document in `docs/audit/<YYYY-MM-DD>-q<N>-<drill>.md`
- A diff of any playbook updates (in the same PR as the audit doc)
- A follow-up issue (or `TaskDocs` work summary) for any gap discovered

## What we don't drill (yet)

- **Cross-region failover** — currently manual per `disaster-recovery.md` Scenario 5; no automated cutover. Tracked as an aspirational follow-up; first run will be deferred until cross-region replication is in place.
- **GKE cluster loss + Terraform rebuild** — Scenario 4. Risky to drill in production. Will be exercised once a sandbox project mirror exists.

## See also

- `playbooks/disaster-recovery.md` — full DR scenarios
- `playbooks/postgresql-backup-operations.md` — daily backup ops + alerting
- `standards/database-management.md` — backup standards
