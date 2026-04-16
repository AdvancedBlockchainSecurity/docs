# Drift Audit Cron — Design + Playbook

**Status:** Suspended 2026-04-16 — blocked on repo-clone auth (Option A chosen)
**Namespace:** `platform-audit-prod` (manifests deployed, CronJob `spec.suspend: true`)
**Design note:** uses CLIENT-SIDE diff (`kustomize build` + `kubectl get -o yaml` + normalized-YAML compare). The original design proposed `kubectl diff -k`, but that would require server-side dry-run permissions (`patch`/`create`/`update` on all target resources) — unacceptable for a read-only audit CronJob. The implemented CronJob spec in `blocksecops-gcp-infrastructure/k8s/overlays/gcp/drift-audit/cronjob.yaml` is the authoritative reference; the YAML block in this doc is the historical design.

## Why suspended (2026-04-16)

First verification run failed on `git clone`:

```
fatal: could not read Username for 'https://github.com': No such device or address
```

`github.com/AdvancedBlockchainSecurity/blocksecops-gcp-infrastructure` returns 404 anonymously — it's private. The CronJob can't clone without credentials, and the design doc assumed anonymous access.

## Three options considered

| Option | Description | Cost | Security |
|--------|-------------|------|----------|
| **A — Suspend + defer (chosen)** | `spec.suspend: true` in Git + cluster. Cron doesn't run. Scaffolding (RBAC, namespace, NetworkPolicy, alert) stays in place for future un-blocking. | Zero ongoing cost | No new credential, no new failure mode |
| B — Wire a fine-grained read-only PAT | New K8s Secret synced from GCP Secret Manager; `git clone https://$TOKEN@github.com/...`. | ~1h implementation; credential rotation burden | New long-lived credential |
| C — Drop entirely | Revert all drift-audit manifests + alert + namespace. | Cleanup PR | Smallest surface, no resurrection path |

## Why A was chosen

1. **Existing alerts cover the actual-outage failure modes.** `CronJobJobFailed` (5 min), `PostgreSQLBackupStale` (25h), `GCPSecretDrift` (10m) catch the same class of problems that the 2026-04-15 outage surfaced. Drift-audit's unique value is catching drift *before* it becomes a symptom — real, but not load-bearing with current alerting.
2. **Worst-case-without-drift-audit is a 24h outage window.** Acceptable for a pre-customer platform.
3. **Option B adds a long-lived credential to own.** Every new secret is another thing to rotate, leak-check, and sync. Not worth it for marginal value over manual `kubectl diff -k` on demand.
4. **Scaffolding stays useful.** When we *do* want drift-audit (post-customer, more services, compliance driver, or an alternative auth path like GKE Config Sync), the manifests are already in Git — just flip `suspend: false` and wire auth.

## How to un-block (when we need drift-audit)

1. Pick an auth path (Option B PAT, Config Sync, GitHub App, self-hosted git mirror)
2. Update the CronJob spec to consume the credential (env var, volume mount, or different auth method)
3. Set `spec.suspend: false` in Git
4. `kubectl apply -k` + manual-trigger verification run
5. Update this playbook's status back to Active with the deployment date

## Manual drift check in the meantime

```bash
# Single overlay
kubectl diff -k /home/pwner/Git/blocksecops-gcp-infrastructure/k8s/overlays/gcp

# All production overlays
for OVERLAY in k8s/overlays/production/postgresql k8s/overlays/gcp; do
  echo "=== $OVERLAY ==="
  (cd /home/pwner/Git/blocksecops-gcp-infrastructure && kubectl diff -k "$OVERLAY")
done
```

The `kubectl diff -k` approach works from a workstation because the operator has cluster-admin; it doesn't generalize to an in-cluster read-only SA — which is why automation needed the client-side-diff design in the first place.
**Last Updated:** 2026-04-15
**Cadence:** Weekly (Sunday 04:00 UTC)
**Owner:** Platform Operator

## Why

The 2026-04-15 PostgreSQL backup recovery incident exposed three months of accumulated GitOps drift between the `blocksecops-gcp-infrastructure` overlays and the live cluster:
- `ExternalSecret/postgresql-credentials` was applied via raw `kubectl` outside Git
- `ResourceQuota/resource-quota` was applied 2026-03-10 with no Git source
- The `postgresql-backup` CronJob referenced a Secret name that didn't exist in the live cluster

Each individual divergence is small. Together, they took down backups for 16+ hours. A weekly automated diff that fires an alert on drift would have caught all three within the first week.

## Design

### CronJob (proposed)

`k8s/gcp/drift-audit/cronjob.yaml`:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: drift-audit
  namespace: platform-ops-prod
spec:
  schedule: "0 4 * * 0"        # Sunday 04:00 UTC
  successfulJobsHistoryLimit: 4
  failedJobsHistoryLimit: 6
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          serviceAccountName: drift-audit
          securityContext:
            runAsNonRoot: true
            runAsUser: 65532
            seccompProfile: {type: RuntimeDefault}
          containers:
          - name: drift-audit
            image: alpine/k8s:1.30.0    # has kubectl + git
            securityContext:
              allowPrivilegeEscalation: false
              readOnlyRootFilesystem: true
              capabilities: {drop: ["ALL"]}
            env:
            - name: HOME
              value: /home/nonroot
            - name: GIT_REPO
              value: https://github.com/AdvancedBlockchainSecurity/blocksecops-gcp-infrastructure
            - name: GIT_REF
              value: main
            command: ["/bin/sh", "-c"]
            args:
            - |
              set -e
              git clone --depth=1 --branch="$GIT_REF" "$GIT_REPO" /tmp/repo
              cd /tmp/repo
              FAILED=0
              for OVERLAY in $(find k8s/overlays -name kustomization.yaml -mindepth 2 -maxdepth 4 | xargs -n1 dirname); do
                # Only audit production overlays
                case "$OVERLAY" in *production* | *gcp* ) ;; * ) continue ;; esac
                echo "=== diff $OVERLAY ==="
                if ! kubectl diff -k "$OVERLAY" > /tmp/diff.txt 2>&1; then
                  RC=$?
                  if [ $RC -eq 1 ]; then
                    echo "DRIFT detected in $OVERLAY"
                    cat /tmp/diff.txt
                    FAILED=$((FAILED+1))
                  else
                    echo "ERROR running diff on $OVERLAY (rc=$RC)"
                    cat /tmp/diff.txt
                    FAILED=$((FAILED+1))
                  fi
                fi
              done
              if [ $FAILED -gt 0 ]; then
                echo "Total overlays with drift: $FAILED"
                exit 1
              fi
              echo "All overlays in sync"
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

### RBAC

`drift-audit` ServiceAccount needs cluster-wide **read** access (no write):

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: drift-audit-reader
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list"]
```

`kubectl diff` requires read access; it never writes. Don't grant `update`/`patch`/`create`.

### Alert

Add to `k8s/gcp/alerting/alerting-rules.yaml` `data-protection` group:

```yaml
- alert: GitOpsDriftDetected
  expr: kube_job_status_failed{namespace="platform-ops-prod",job_name=~"drift-audit-.*"} > 0
  for: 10m
  labels:
    severity: warning
    team: platform
  annotations:
    summary: "GitOps drift detected between Git overlays and cluster"
    description: "drift-audit Job failed. Run `kubectl logs job/{{ $labels.job_name }} -n platform-ops-prod` for the diff. See playbooks/drift-audit-cron.md."
```

## Playbook — when the alert fires

1. **Identify the drifted overlay**
   ```bash
   POD=$(kubectl logs -n platform-ops-prod job/drift-audit-<timestamp> | grep -oP 'DRIFT detected in \K\S+' | head -1)
   echo "Drifted overlay: $POD"
   ```
2. **Read the diff** (already in the Job logs)
3. **Decide which is correct**
   - **Cluster is right, Git is stale** — usually means an emergency hotfix didn't land back in Git. Reconcile by updating the Git file to match cluster (codebase-first compliance), open a PR, get approval. Example: the 2026-04-15 ExternalSecret reconciliation in `audit/2026-04-15-postgresql-backup-recovery-summary.md`.
   - **Git is right, cluster is stale** — someone made an ad-hoc `kubectl edit`. Reconcile by `kubectl apply -k <overlay>` (after Rule 0 approval). Example: scheduled rollback recovery.
   - **Both are wrong** — rare. Both updated in different ways. Manual merge required.
4. **Document** the resolution in `docs/audit/<YYYY-MM-DD>-drift-<overlay>.md`

## What this does NOT cover

- **Field-level mutations by controllers** — `kubectl diff` will flag fields that controllers add (e.g., `cluster-autoscaler.kubernetes.io/safe-to-evict` annotations on Deployment pods). The Job's exit-code-1 rule is noisy without a server-side dry-run filter or a per-resource ignore list. Tracked as a follow-up to suppress controller-managed annotations.
- **Resources outside the audited overlays** — anything applied by `gcloud` directly (Workload Identity bindings, Secret Manager secrets) won't show up. Consider a secondary audit comparing GCP Secret Manager versions against `ExternalSecret` references.
- **CRD schema drift** — `kubectl diff` doesn't catch CRD version skew.

## Implementation status

This document is the **design proposal**, not deployed. Estimated effort: 2-4 hr to ship the CronJob + RBAC + alert + first round of false-positive suppressions.

## See also

- `audit/2026-04-15-postgresql-backup-recovery-summary.md` — drift incident that motivated this
- `audit/2026-04-15-postgresql-backup-network-policy-security-review.md` — example of an OWASP-style audit doc
- `standards/core-development-rules.md` — Rule 1 codebase-first development
