# 4-Layer CronJob Audit — Production

**Date:** 2026-04-15
**Auditor:** Apogee Platform Team
**Reference:** `audit/2026-04-15-postgresql-backup-recovery-summary.md` (the 4 layers)
**Scope:** Every CronJob deployed in any `*-prod` namespace on the production GKE cluster

## The 4 layers (from the postgresql-backup recovery)

For every CronJob:
1. **Secret references** — every `secretKeyRef.name` resolves to a Secret that exists in the live namespace
2. **Password / credential currency** — the value behind those references is the value the destination service actually accepts
3. **NetworkPolicy egress** — the pod can reach every destination it needs (DNS, database, GCS/S3, metadata server)
4. **ResourceQuota headroom** — namespace pod/CPU/memory quota allows the CronJob to co-exist with steady-state workloads

## Inventory

```
$ kubectl get cronjobs -A
NAMESPACE         NAME                SCHEDULE    SUSPEND   ACTIVE   LAST SCHEDULE   AGE
postgresql-prod   postgresql-backup   0 2 * * *   False     0        22h             27h
```

**Total deployed prod CronJobs: 1.**

The repository also defines `vault-backup` (`k8s/overlays/production/vault/backup-cronjob.yaml`) but the `vault-prod` namespace does not exist in the production cluster — Vault is local-only at this time. Defined-but-undeployed CronJobs are out of scope for this audit (they can't break what isn't running). When Vault prod is brought up, this audit must be redone.

## postgresql-backup — 4-layer review

Already covered in detail by `audit/2026-04-15-postgresql-backup-recovery-summary.md` and `audit/2026-04-15-postgresql-backup-network-policy-security-review.md`. Summary:

| Layer | Status | Evidence |
|-------|--------|----------|
| 1. Secret refs | PASS | CronJob references `postgresql-credentials`; `kubectl get secret postgresql-credentials -n postgresql-prod` returns the Secret with all 3 expected keys |
| 2. Password currency | PASS | `apogee-gcp-postgres-password` v2 in GCP Secret Manager matches the password baked into `apogee-gcp-database-url`; manual end-to-end backup succeeds |
| 3. NetworkPolicy egress | PASS | `postgresql-backup-network-policy` grants DNS + 5432 (postgres) + 169.254.169.252:988 (Workload Identity) + 169.254.169.254:80 (compute metadata) + 443 (GCS); OWASP walkthrough in the security-review doc gives 0 CRITICAL/HIGH/MEDIUM findings |
| 4. ResourceQuota | PASS | `postgresql-prod` quota at 4 pods (was 2); accommodates `postgresql-0` + scheduled backup + 2-pod headroom |

Plus, since 2026-04-15:
- `data-protection` alert group covers `CronJobJobFailed`, `PostgreSQLBackupStale` (25h), `CronJobPodConfigError` so any future regression on layers 1/3 is paged within 5 min instead of silent for 16 hours.
- Pod template hardened: `runAsNonRoot`, `readOnlyRootFilesystem`, `capabilities.drop: [ALL]`, seccompProfile `RuntimeDefault`, `/tmp` + `$HOME` mounted as emptyDir (defense-in-depth — pre-existing finding from the NetworkPolicy security review)

## Findings

| Finding | Severity | Status |
|---------|----------|--------|
| Only one prod CronJob exists today; the audit surface is small | INFO | n/a |
| `vault-backup` is defined but not deployed (Vault is local-only) | INFO | Track for re-audit when Vault prod comes online |
| `postgresql-backup` passes all 4 layers + has alerting | OK | All four layers green after the 2026-04-15 recovery |

**No CRITICAL, HIGH, MEDIUM, or LOW findings.**

## Re-audit triggers

Re-run this audit when:
- A new CronJob is added to any `*-prod` namespace
- A namespace ResourceQuota is changed
- The default-deny NetworkPolicy in a CronJob's namespace is modified
- A Secret consumed by a CronJob is renamed or moved between namespaces
- Vault is deployed to production

## See also

- `audit/2026-04-15-postgresql-backup-recovery-summary.md`
- `audit/2026-04-15-postgresql-backup-network-policy-security-review.md`
- `standards/networkpolicy-templates.md` — patterns to copy when adding a new CronJob
- `playbooks/postgresql-backup-operations.md` — operational runbook
