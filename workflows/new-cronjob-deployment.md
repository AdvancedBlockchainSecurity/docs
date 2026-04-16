# Workflow: Deploy a New CronJob to Prod GCP

**Status:** Active
**Last Updated:** 2026-04-15
**Audience:** Platform Operator
**Part of:** `docs/standards/INDEX.md` — Kubernetes & Workflows

Codifies the pattern used by `postgresql-backup`, `gcp-secret-drift-check`, and `drift-audit` CronJobs. Follow this workflow when adding any new production CronJob — it bundles kustomize layout, Workload Identity binding, NetworkPolicy choice, alerting, and verification into one place.

## Pre-requisites

- [ ] Owner approval obtained for the CronJob scope (Rule 0)
- [ ] Fresh verified PostgreSQL backup in `gs://apogee-production-db-backups/postgresql/` if the CronJob will touch the database (per `standards/database-management.md`)
- [ ] You've read the relevant standards:
  - `standards/kubernetes-pod-lifecycle.md` (securityContext + revisionHistoryLimit)
  - `standards/networkpolicy-templates.md` (the four workload archetypes)
  - `standards/secrets-management.md` (Workload Identity vs Vault; when to use which)
  - `standards/docker-image-versioning.md` (tag the image, never `:latest`)

## Decision checklist

Before writing any YAML, answer these:

| Question | Typical answer | Affects |
|----------|---------------|---------|
| Does the CronJob need to call a GCP API (GCS, Secret Manager, Artifact Registry)? | Yes → create a GSA + Workload Identity binding. No → K8s ServiceAccount only. | Phase 2, Phase 3 |
| Does the CronJob mutate Kubernetes resources? | `get`/`list` only → read-only ClusterRole. `create`/`patch`/etc. → scope narrowly; document why. | Phase 3 |
| Which namespace? | Co-locate with the workload being guarded (`postgresql-prod`, `redis-prod`, etc.). Only create a new namespace if the CronJob is genuinely cross-cutting. | Phase 4 |
| Which NetworkPolicy archetype? | CronJob with GCP egress → Archetype 2 in `standards/networkpolicy-templates.md`. | Phase 4 |
| How often does it run? | Weekly is usually plenty for drift/audit crons; daily for backups. Avoid sub-hourly unless there's a reason. | Phase 5 |
| Failure alerting? | Add rule to the existing `data-protection` group in `k8s/gcp/alerting/alerting-rules.yaml`. | Phase 6 |

## Phase 1 — Scaffold the files

**Pattern to follow:** `blocksecops-gcp-infrastructure/k8s/overlays/production/postgresql/` (the `postgresql-backup` CronJob). Co-locate your CronJob with the workload it guards.

```
k8s/overlays/production/<host-namespace>/
├── <cronjob-name>-cron.yaml             # ServiceAccount + CronJob
├── <cronjob-name>-networkpolicy.yaml    # one-file NetworkPolicy for the cron pod
└── kustomization.yaml                   # add both files to resources:
```

**Common shape of `<cronjob-name>-cron.yaml`:**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: <cronjob-name>
  namespace: <host-namespace>
  annotations:
    # Only if the cron needs GCP APIs (Phase 2):
    iam.gke.io/gcp-service-account: apogee-gcp-<purpose>@project-8a2657b9-d96c-4c0a-a69.iam.gserviceaccount.com
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: <cronjob-name>
  namespace: <host-namespace>
spec:
  schedule: "0 5 * * 0"            # Sunday 05:00 UTC — offset from daily backups to avoid node contention
  successfulJobsHistoryLimit: 3    # per standards/kubernetes-pod-lifecycle.md
  failedJobsHistoryLimit: 3
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app.kubernetes.io/name: <cronjob-name>
        spec:
          restartPolicy: OnFailure
          serviceAccountName: <cronjob-name>
          # Pod-level securityContext (standards/kubernetes-pod-lifecycle.md)
          securityContext:
            runAsNonRoot: true
            runAsUser: 65532
            runAsGroup: 65532
            fsGroup: 65532
            seccompProfile: {type: RuntimeDefault}
          containers:
          - name: <cronjob-name>
            image: <upstream-image-pinned-by-tag>  # e.g. google/cloud-sdk:slim
            securityContext:
              allowPrivilegeEscalation: false
              readOnlyRootFilesystem: true
              capabilities: {drop: ["ALL"]}
            env:
            - name: HOME
              value: /home/nonroot
            command: ["/bin/sh", "-c", "..."]
            volumeMounts:
            - name: tmp
              mountPath: /tmp
            - name: home
              mountPath: /home/nonroot
            resources:
              requests: {memory: "128Mi", cpu: "100m"}
              limits:   {memory: "512Mi", cpu: "200m"}   # bump only if observed peak demands it
          volumes:
          - name: tmp
            emptyDir: {}
          - name: home
            emptyDir: {}
```

Why the `tmp` + `home` emptyDirs: most upstream images (postgres-client, gcloud, kubectl) write transient state to `/tmp` and `$HOME/.config/*`. `readOnlyRootFilesystem: true` breaks that unless you mount writable scratch. `HOME` is remapped so CLI tools find their config files.

## Phase 2 — Workload Identity binding (if needed)

Skip this phase if the CronJob only talks to the Kubernetes API.

Run these from your workstation with owner approval per Rule 0:

```bash
PROJECT=project-8a2657b9-d96c-4c0a-a69
GSA=apogee-gcp-<purpose>
NS=<host-namespace>
KSA=<cronjob-name>

# 1. Create the GSA
gcloud iam service-accounts create "$GSA" \
  --display-name="<one-line description of the role>" \
  --project="$PROJECT"

# 2. Grant it the minimum GCP roles it needs (scope to specific resources)
# Example: read-only access to two specific Secret Manager entries
for SECRET in apogee-gcp-database-url apogee-gcp-postgres-password; do
  gcloud secrets add-iam-policy-binding "$SECRET" \
    --member="serviceAccount:${GSA}@${PROJECT}.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"
done

# 3. Bind the K8s SA to the GSA via Workload Identity
gcloud iam service-accounts add-iam-policy-binding \
  "${GSA}@${PROJECT}.iam.gserviceaccount.com" \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:${PROJECT}.svc.id.goog[${NS}/${KSA}]"
```

The K8s SA needs the `iam.gke.io/gcp-service-account` annotation pointing at the GSA (already in the template above).

Capture the gcloud output in the PR description so the IAM state is reviewable.

## Phase 3 — RBAC (if the CronJob reads the K8s API)

Keep this as narrow as possible. For a read-only audit cron, a cluster-wide read-only ClusterRole is acceptable:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: <cronjob-name>-reader
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]     # never include patch/create/update here
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: <cronjob-name>-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: <cronjob-name>-reader
subjects:
- kind: ServiceAccount
  name: <cronjob-name>
  namespace: <host-namespace>
```

**Anti-pattern (don't):** granting `patch`/`create`/`update` just because `kubectl diff -k` needs server-side dry-run. Use a client-side diff approach instead (see `docs/playbooks/drift-audit-cron.md`). The security posture of "read-only audit" is compromised the moment this SA can mutate resources.

## Phase 4 — NetworkPolicy

Copy **Archetype 2** from `standards/networkpolicy-templates.md`:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: <cronjob-name>-netpol
  namespace: <host-namespace>
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: <cronjob-name>
  policyTypes: [Egress]    # CronJobs don't accept ingress
  egress:
  - to: []                                            # DNS
    ports: [{port: 53, protocol: UDP}, {port: 53, protocol: TCP}]
  - to:                                               # GKE Workload Identity metadata (if using WI)
    - ipBlock: {cidr: 169.254.169.252/32}
    ports: [{port: 988, protocol: TCP}]
  - to:                                               # Compute metadata fallback
    - ipBlock: {cidr: 169.254.169.254/32}
    ports: [{port: 80, protocol: TCP}]
  - to: []                                            # HTTPS egress (GCS / Secret Manager / GitHub / …)
    ports: [{port: 443, protocol: TCP}]
```

Adjust the egress rules to the minimum the cron actually needs. Remove the metadata-server rules if the CronJob doesn't use Workload Identity.

## Phase 5 — Kustomize wiring

Add both files to the host-namespace's `kustomization.yaml`:

```yaml
# k8s/overlays/production/<host-namespace>/kustomization.yaml
resources:
  - ...
  - <cronjob-name>-cron.yaml
  - <cronjob-name>-networkpolicy.yaml
```

Validate before commit:

```bash
kubectl apply -k k8s/overlays/production/<host-namespace> --dry-run=client
```

## Phase 6 — Prometheus alert

Extend the existing `data-protection` group in `k8s/gcp/alerting/alerting-rules.yaml`. Don't create a new group unless you have 3+ alerts on a different concern.

```yaml
- alert: <CronJobNameFailed>
  expr: kube_job_status_failed{namespace="<host-namespace>",job_name=~"<cronjob-name>-.*"} > 0
  for: 10m
  labels:
    severity: warning    # or critical for outages that block customer flow
    team: platform
  annotations:
    summary: "<human-readable failure description>"
    description: "<what to do; link to the runbook>"
```

## Phase 7 — Deploy + verify

```bash
# Apply the infra
kubectl apply -k /home/pwner/Git/blocksecops-gcp-infrastructure/k8s/overlays/production/<host-namespace>

# Apply the alerting
kubectl apply -k /home/pwner/Git/blocksecops-gcp-infrastructure/k8s/gcp/alerting/

# Verify SA exists with WI annotation
kubectl get sa <cronjob-name> -n <host-namespace> \
  -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}'

# Verify the CronJob is scheduled
kubectl get cronjob <cronjob-name> -n <host-namespace>

# Manually trigger an out-of-cycle run (can be re-triggered as many times as needed during verification)
TS=$(date +%s)
kubectl create job --from=cronjob/<cronjob-name> \
  "<cronjob-name>-verify-$TS" -n <host-namespace>
kubectl wait --for=condition=complete \
  "job/<cronjob-name>-verify-$TS" -n <host-namespace> --timeout=300s

# Tail the job logs and confirm expected behaviour
POD=$(kubectl get pod -n <host-namespace> -l job-name=<cronjob-name>-verify-$TS -o name | head -1)
kubectl logs -n <host-namespace> "$POD"

# Confirm the alert rule is loaded
kubectl get clusterrules.monitoring.googleapis.com apogee-platform-alerts -o yaml | grep <CronJobNameFailed>
```

## Phase 8 — Post-deploy documentation

After the verification run succeeds:

1. Update the CronJob's **runbook** (`docs/playbooks/<cronjob-name>.md`) — status **Active** + deployment date + the first successful-run evidence
2. Update the corresponding **audit doc** if one exists (e.g., the 2026-04-15 backup recovery audit)
3. If you created a new kind of CronJob (different archetype, novel failure mode), **update this workflow doc** so the next operator has a reference
4. Add an entry to **TaskDocs-BlockSecOps/work-summaries/** with standards-compliance table + rollback plan

## Anti-patterns (seen in practice, don't repeat)

| Anti-pattern | Consequence | What to do instead |
|--------------|-------------|--------------------|
| Granting the CronJob SA `patch`/`create`/`update` cluster-wide because `kubectl diff -k` needs it | Audit CronJob becomes an attack path; least-privilege principle broken | Use client-side diff (`kustomize build` + `kubectl get -o yaml` + line compare). See `docs/playbooks/drift-audit-cron.md`. |
| Creating a new namespace for every cron | Adds kustomize overhead, new default-deny to audit, no shared quotas | Co-locate with the workload being guarded |
| Hardcoding the image tag `:latest` | `standards/docker-image-versioning.md` violation | Pin to a released tag (and, future work, a digest) |
| Skipping `securityContext` on the pod/containers | `standards/kubernetes-pod-lifecycle.md` violation | Use the template in Phase 1 |
| Broad `to: []` on arbitrary TCP ports in the NetworkPolicy | Defeats the point of having a policy | Always restrict by port; only `443` / `53` are reasonable wildcards |
| Skipping Phase 6 alerting | Silent failures — the whole reason this workflow exists | Always add the alert rule |

## Reference deployments

- `blocksecops-gcp-infrastructure/k8s/overlays/production/postgresql/backup-cronjob.yaml` — daily PostgreSQL backup with GCS upload (Workload Identity, large egress surface for GCS)
- `blocksecops-gcp-infrastructure/k8s/overlays/production/postgresql/gcp-secret-drift-cron.yaml` — weekly Secret Manager comparison (Workload Identity, tight egress to Secret Manager only)
- `blocksecops-gcp-infrastructure/k8s/overlays/gcp/drift-audit/cronjob.yaml` — weekly GitOps drift audit (no GCP APIs; only K8s API + GitHub)

## See also

- `docs/standards/kubernetes-pod-lifecycle.md` — pod/container securityContext requirements
- `docs/standards/networkpolicy-templates.md` — the four workload archetypes
- `docs/standards/secrets-management.md` — Workload Identity vs Vault
- `docs/standards/docker-image-versioning.md` — immutable tag policy
- `docs/playbooks/postgresql-backup-operations.md` — operational reference for the most mature cron on the platform
