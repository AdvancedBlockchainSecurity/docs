# GCP Secret Manager Drift Validation Cron — Design Proposal

**Status:** Proposed (design only — not deployed)
**Cadence:** Weekly (Sunday 05:00 UTC — offset from drift-audit-cron at 04:00)
**Owner:** Platform Operator
**Last Updated:** 2026-04-15

## Why this instead of consolidating the secrets

The 2026-04-15 PostgreSQL backup outage was caused in part by drift between two GCP Secret Manager entries that encode the same value:

- `apogee-gcp-postgres-password` — plaintext password consumed by the `postgresql-backup` CronJob via `postgresql-credentials` ExternalSecret (mapped key: `POSTGRES_PASSWORD`)
- `apogee-gcp-database-url` — full connection URL (`postgresql+asyncpg://blocksecops:<password>@...`) consumed by api-service + data-service + intelligence-engine + orchestration + notification + celery via `DATABASE_URL`

They must always carry the same password. The outage happened because `apogee-gcp-postgres-password` was rotated once and `apogee-gcp-database-url` was not (or vice-versa); the backup CronJob picked up the stale one and started failing auth.

### Why not just delete `apogee-gcp-postgres-password`?

Consolidating into `apogee-gcp-database-url` as the single source of truth would require:

1. Changing every consumer's `ExternalSecret` to extract the password from a URL via ESO's JSON/regex templating
2. Coordinated rollouts of 6+ services (api-service, data-service, intelligence-engine, orchestration, notification, celery-worker) with new `ExternalSecret` specs
3. Ensuring no service reads `apogee-gcp-postgres-password` anywhere else (seeded Secret references, Terraform state, legacy scripts)

Any mismapping lands a service on bad credentials; recovery is per-service rollback. **Blast radius: multiple core services.** Against the benefit of deduplication (a single value instead of two), the risk/benefit ratio is poor.

A validation cron addresses the *actual* problem — **drift between values that should be equal** — without touching any live secret reference.

## Design

### CronJob

`blocksecops-gcp-infrastructure/k8s/overlays/gcp/platform-ops/gcp-secret-drift-cron.yaml`:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: gcp-secret-drift-check
  namespace: platform-ops-prod
spec:
  schedule: "0 5 * * 0"        # Sunday 05:00 UTC
  successfulJobsHistoryLimit: 4
  failedJobsHistoryLimit: 6
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          serviceAccountName: gcp-secret-drift-check  # Workload Identity → apogee-gcp-secret-reader GSA
          securityContext:
            runAsNonRoot: true
            runAsUser: 65532
            runAsGroup: 65532
            fsGroup: 65532
            seccompProfile: {type: RuntimeDefault}
          containers:
          - name: drift-check
            image: google/cloud-sdk:slim
            securityContext:
              allowPrivilegeEscalation: false
              readOnlyRootFilesystem: true
              capabilities: {drop: ["ALL"]}
            env:
            - name: HOME
              value: /home/nonroot
            command: ["/bin/sh", "-c"]
            args:
            - |
              set -euo pipefail
              # Password embedded in the URL secret (source of truth for API services)
              URL_PW=$(gcloud secrets versions access latest \
                --secret=apogee-gcp-database-url \
                --project=project-8a2657b9-d96c-4c0a-a69 | \
                sed -E 's|^.*://[^:]+:([^@]+)@.*|\1|')
              # Plaintext password secret (source for backup CronJob)
              PLAIN_PW=$(gcloud secrets versions access latest \
                --secret=apogee-gcp-postgres-password \
                --project=project-8a2657b9-d96c-4c0a-a69)
              if [ "$URL_PW" != "$PLAIN_PW" ]; then
                echo "DRIFT: apogee-gcp-postgres-password != password in apogee-gcp-database-url"
                echo "       Re-sync before the next backup cycle at 02:00 UTC Monday."
                echo "       Runbook: docs/playbooks/postgresql-backup-operations.md"
                exit 1
              fi
              echo "OK: apogee-gcp-postgres-password matches apogee-gcp-database-url"
            volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: home
              mountPath: /home/nonroot
            resources:
              requests: {memory: "128Mi", cpu: "100m"}
              limits:   {memory: "256Mi", cpu: "200m"}
          volumes:
          - name: tmp
            emptyDir: {}
          - name: home
            emptyDir: {}
```

### ServiceAccount + Workload Identity binding

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gcp-secret-drift-check
  namespace: platform-ops-prod
  annotations:
    iam.gke.io/gcp-service-account: apogee-gcp-secret-reader@project-8a2657b9-d96c-4c0a-a69.iam.gserviceaccount.com
```

GSA `apogee-gcp-secret-reader` gets `roles/secretmanager.secretAccessor` on the two specific secrets (not project-wide):

```bash
for SECRET in apogee-gcp-database-url apogee-gcp-postgres-password; do
  gcloud secrets add-iam-policy-binding "$SECRET" \
    --member="serviceAccount:apogee-gcp-secret-reader@project-8a2657b9-d96c-4c0a-a69.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
done
```

### NetworkPolicy (follows `standards/networkpolicy-templates.md` Archetype 2)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: gcp-secret-drift-check-network-policy
  namespace: platform-ops-prod
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: gcp-secret-drift-check
  policyTypes: [Egress]
  egress:
  - to: []
    ports: [{port: 53, protocol: UDP}, {port: 53, protocol: TCP}]   # DNS
  - to:
    - ipBlock: {cidr: 169.254.169.252/32}                            # Workload Identity metadata
    ports: [{port: 988, protocol: TCP}]
  - to:
    - ipBlock: {cidr: 169.254.169.254/32}                            # Compute metadata
    ports: [{port: 80, protocol: TCP}]
  - to: []
    ports: [{port: 443, protocol: TCP}]                              # GCP Secret Manager API (HTTPS)
```

### Prometheus alert

Add to `k8s/gcp/alerting/alerting-rules.yaml` `data-protection` group:

```yaml
- alert: GCPSecretDrift
  expr: kube_job_status_failed{namespace="platform-ops-prod",job_name=~"gcp-secret-drift-check-.*"} > 0
  for: 10m
  labels:
    severity: critical
    team: platform
  annotations:
    summary: "GCP Secret Manager drift between postgres-password and database-url"
    description: >
      apogee-gcp-postgres-password and the password embedded in apogee-gcp-database-url
      have diverged. The next postgresql-backup run (02:00 UTC) will fail auth unless
      the two are re-synced. Runbook: docs/playbooks/postgresql-backup-operations.md.
```

**Severity critical:** drift here is a pre-outage signal for the most recent production incident (2026-04-15 silent backup failure). 10-min `for:` avoids paging on transient gcloud hiccups while still firing well before the Monday 02:00 UTC backup.

## Operator playbook when the alert fires

1. **Confirm drift**:
   ```bash
   URL_PW=$(gcloud secrets versions access latest --secret=apogee-gcp-database-url \
     --project=project-8a2657b9-d96c-4c0a-a69 | sed -E 's|^.*://[^:]+:([^@]+)@.*|\1|')
   PLAIN_PW=$(gcloud secrets versions access latest --secret=apogee-gcp-postgres-password \
     --project=project-8a2657b9-d96c-4c0a-a69)
   diff <(echo "$URL_PW") <(echo "$PLAIN_PW")
   ```
2. **Decide which is authoritative** — usually the URL (services are actively using it). Confirm by running a real connection:
   ```bash
   kubectl exec -n postgresql-prod postgresql-0 -- bash -c \
     "PGPASSWORD='$URL_PW' psql -h localhost -U blocksecops -d solidity_security -c 'SELECT 1;'"
   ```
3. **Re-sync the plaintext secret** (Rule 0 — destructive, requires approval):
   ```bash
   echo -n "$URL_PW" | gcloud secrets versions add apogee-gcp-postgres-password --data-file=-
   ```
4. **Force ExternalSecret refresh**:
   ```bash
   kubectl annotate externalsecret postgresql-credentials -n postgresql-prod \
     force-sync="$(date +%s)" --overwrite
   ```
5. **Document** — audit doc under `docs/audit/<YYYY-MM-DD>-secret-drift-resync.md` capturing which value was stale and why.

## What this design deliberately doesn't do

- **Does not rotate secrets.** The cron is purely read-only.
- **Does not auto-remediate drift.** Auto-remediation risks pushing a stale value back over a good one; manual judgement required.
- **Does not check other secret pairs.** Only the postgres password. Expand the script with more pairs as other duplicates are identified.
- **Does not replace the consolidation conversation.** If future work consolidates the two secrets, this cron becomes obsolete — delete it at that time.

## Implementation status

- [ ] Design doc (this file)
- [ ] IAM binding script
- [ ] CronJob + ServiceAccount + NetworkPolicy manifests in `k8s/overlays/gcp/platform-ops/`
- [ ] `kustomization.yaml` entry
- [ ] Prometheus alert rule in `k8s/gcp/alerting/alerting-rules.yaml`
- [ ] First dry-run (Sunday after merge)
- [ ] Audit doc after first successful run

Estimated effort: **~2 hours** including Workload Identity binding + first-run observation.

## Standards compliance

| Standard | How this complies |
|----------|-------------------|
| `core-development-rules.md` Rule 0 | Deployment requires owner approval |
| `core-development-rules.md` Rule 1 | All manifests in Git before `kubectl apply` |
| `secrets-management.md` | Workload Identity + least-privilege IAM (only the two secrets, only `secretAccessor`) |
| `kubernetes-pod-lifecycle.md` | Pod- and container-level securityContext, NetworkPolicy present |
| `secure-coding.md` | No shell injection (all inputs from gcloud), read-only filesystem, non-root execution |
| `networkpolicy-templates.md` | Archetype 2 (CronJob with GCP egress) |

## See also

- `audit/2026-04-15-postgresql-backup-recovery-summary.md` — the drift incident that motivated this
- `playbooks/drift-audit-cron.md` — sibling cron that audits Git/cluster drift
- `playbooks/postgresql-backup-operations.md` — runbook for drift resync
- `standards/networkpolicy-templates.md` — Archetype 2 template
