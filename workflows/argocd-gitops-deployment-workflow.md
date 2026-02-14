# ArgoCD GitOps Deployment Workflow

## Overview

This document defines the ArgoCD deployment workflow for the BlockSecOps platform, covering the ApplicationSet bootstrap process, sync wave ordering, GKE cluster registration, self-managing ArgoCD, and rollback procedures.

**ArgoCD Instances:**
- Bare-metal (local dev): v2.13.3 in `argocd-local` namespace, at https://argocd.blocksecops.local
- GCP (production): In `argocd-prod` namespace on GKE

**GCP Deployment Pattern:** ApplicationSet with list generator (not app-of-apps with wave directories)
**Manifest Location:** All GCP service manifests live in `blocksecops-gcp-infrastructure/k8s/overlays/gcp/services/{name}/`

---

## 1. ApplicationSet Bootstrap Workflow

### Existing ApplicationSet

The GCP deployment is defined in:
```
blocksecops-gcp-infrastructure/k8s/overlays/gcp/argocd/applications/applicationset.yaml
```

This ApplicationSet uses a **list generator** with 12 services. It creates one ArgoCD Application per service, all pointing at manifests within the same `blocksecops-gcp-infrastructure` repo.

### Bootstrap Sequence

```
┌──────────────────────────────────────────────────────────────────┐
│  Step 1: GKE cluster provisioned via Terraform                   │
│          (blocksecops-gcp-infrastructure/terraform/)             │
└──────────────────────────┬───────────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────────┐
│  Step 2: Deploy ArgoCD to GKE                                    │
│          kubectl apply -k k8s/overlays/gcp/argocd/              │
└──────────────────────────┬───────────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────────┐
│  Step 3: Deploy infrastructure prerequisites                     │
│          kubectl apply -f k8s/overlays/gcp/argocd/applications/ │
│              infrastructure.yaml  (external-secrets)             │
└──────────────────────────┬───────────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────────┐
│  Step 4: Apply the ApplicationSet                                │
│          kubectl apply -f applicationset.yaml -n argocd-prod    │
└──────────────────────────┬───────────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────────┐
│  Step 5: ArgoCD reads ApplicationSet                             │
│          → generates 12 Application CRDs from list generator     │
│          → each Application points to k8s/overlays/gcp/services/ │
│          → syncs them to GKE (with retry: 5 attempts, backoff)   │
└──────────────────────────┬───────────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────────┐
│  Step 6: All 12 services deployed to GKE                        │
│          ArgoCD continuously monitors for drift                  │
│          Auto-prune + self-heal enabled                           │
└──────────────────────────────────────────────────────────────────┘
```

### ApplicationSet Manifest (Existing)

```yaml
# blocksecops-gcp-infrastructure/k8s/overlays/gcp/argocd/applications/applicationset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: blocksecops-services
  namespace: argocd-prod
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
    - list:
        elements:
          - name: api-service
            namespace: api-service-prod
            hasDatabase: "true"
          - name: orchestration
            namespace: orchestration-prod
            hasDatabase: "true"
          - name: data-service
            namespace: data-service-prod
            hasDatabase: "true"
          - name: intelligence-engine
            namespace: intelligence-engine-prod
            hasDatabase: "true"
          - name: dashboard
            namespace: dashboard-prod
            hasDatabase: "false"
          - name: notification
            namespace: notification-prod
            hasDatabase: "false"
          - name: tool-integration
            namespace: tool-integration-prod
            hasDatabase: "false"
          - name: analysis
            namespace: analysis-prod
            hasDatabase: "false"
          - name: findings
            namespace: findings-prod
            hasDatabase: "false"
          - name: contract-parser
            namespace: contract-parser-prod
            hasDatabase: "false"
          - name: admin-portal
            namespace: admin-portal-prod
            hasDatabase: "false"
          - name: scanner-jobs
            namespace: scanner-jobs-prod
            hasDatabase: "false"
  template:
    metadata:
      name: '{{ .name }}'
      namespace: argocd-prod
      labels:
        app.kubernetes.io/name: '{{ .name }}'
        app.kubernetes.io/part-of: blocksecops
        environment: production
        has-database: '{{ .hasDatabase }}'
    spec:
      project: default
      source:
        repoURL: https://github.com/BlockSecOps/blocksecops-gcp-infrastructure.git
        targetRevision: main
        path: 'k8s/overlays/gcp/services/{{ .name }}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{ .namespace }}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
          allowEmpty: false
        syncOptions:
          - CreateNamespace=true
          - PrunePropagationPolicy=foreground
          - PruneLast=true
        retry:
          limit: 5
          backoff:
            duration: 5s
            factor: 2
            maxDuration: 3m
      revisionHistoryLimit: 10
```

### Infrastructure Application (Prerequisite)

Before the ApplicationSet, deploy the `infrastructure` Application which bootstraps ExternalSecrets:

```yaml
# k8s/overlays/gcp/argocd/applications/infrastructure.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: infrastructure
  namespace: argocd-prod
spec:
  project: default
  source:
    repoURL: https://github.com/BlockSecOps/blocksecops-gcp-infrastructure.git
    targetRevision: main
    path: k8s/overlays/gcp/external-secrets
  destination:
    server: https://kubernetes.default.svc
    namespace: external-secrets-prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

This deploys the `ClusterSecretStore` for GCP Secret Manager, which all services need for credential injection.

---

## 2. Sync Wave Ordering with Dependency Rationale

### Current Problem

The existing ApplicationSet deploys all 12 services simultaneously. This causes race conditions when services depend on each other (e.g., orchestration needs api-service's URL).

### Proposed: Add Sync Waves (5 Waves)

Add a `syncWave` field to the list generator and use it in the template annotations:

```yaml
generators:
  - list:
      elements:
        # Wave 1: Core services with no inter-service dependencies
        - name: api-service
          namespace: api-service-prod
          hasDatabase: "true"
          syncWave: "1"
        - name: data-service
          namespace: data-service-prod
          hasDatabase: "true"
          syncWave: "1"
        - name: intelligence-engine
          namespace: intelligence-engine-prod
          hasDatabase: "true"
          syncWave: "1"
        - name: contract-parser
          namespace: contract-parser-prod
          hasDatabase: "false"
          syncWave: "1"

        # Wave 2: Services that depend on api-service URL
        - name: orchestration
          namespace: orchestration-prod
          hasDatabase: "true"
          syncWave: "2"

        # Wave 3: Services that depend on api-service + orchestration
        - name: tool-integration
          namespace: tool-integration-prod
          hasDatabase: "false"
          syncWave: "3"
        - name: notification
          namespace: notification-prod
          hasDatabase: "false"
          syncWave: "3"

        # Wave 4: Frontends and auxiliary services
        - name: dashboard
          namespace: dashboard-prod
          hasDatabase: "false"
          syncWave: "4"
        - name: admin-portal
          namespace: admin-portal-prod
          hasDatabase: "false"
          syncWave: "4"
        - name: findings
          namespace: findings-prod
          hasDatabase: "false"
          syncWave: "4"
        - name: analysis
          namespace: analysis-prod
          hasDatabase: "false"
          syncWave: "4"
        - name: scanner-jobs
          namespace: scanner-jobs-prod
          hasDatabase: "false"
          syncWave: "4"
template:
  metadata:
    annotations:
      argocd.argoproj.io/sync-wave: '{{ .syncWave }}'
```

### Sync Wave Diagram

```
TIME ──────────────────────────────────────────────────────────────▶

  Prereq           Wave 1              Wave 2           Wave 3            Wave 4
┌──────────┐  ┌────────────────┐  ┌──────────────┐  ┌──────────────┐  ┌────────────────┐
│infra-    │  │api-service     │  │orchestration │  │tool-         │  │dashboard       │
│structure │→ │data-service    │→ │              │→ │integration   │→ │admin-portal    │
│(ext-     │  │intelligence-   │  │              │  │notification  │  │findings        │
│secrets)  │  │engine          │  │              │  │              │  │analysis        │
│          │  │contract-parser │  │              │  │              │  │scanner-jobs    │
└──────────┘  └────────────────┘  └──────────────┘  └──────────────┘  └────────────────┘
```

### Dependency Rationale

| Wave | Services | Depends On | Why This Order |
|------|----------|------------|----------------|
| Prereq | `infrastructure` (external-secrets ClusterSecretStore) | GCP Secret Manager | All services need ExternalSecrets to inject DB URLs, Redis URLs, API keys at startup |
| 1 | `api-service`, `data-service`, `intelligence-engine`, `contract-parser` | Prereq (secrets), Cloud SQL (managed), Redis (managed) | These services have no inter-service dependencies. Cloud SQL Proxy runs as a sidecar in each pod (not a standalone deployment). api-service is the central API hub. contract-parser is standalone (Rust). |
| 2 | `orchestration` | Wave 1 (`api-service`) | ExternalSecret includes `API_SERVICE_URL`. Celery workers call api-service to update scan status and fetch contract data. Celery broker uses Redis (managed). |
| 3 | `tool-integration`, `notification` | Wave 1 (`api-service`), Wave 2 (`orchestration`) | tool-integration's ExternalSecret includes `API_SERVICE_URL` — it posts scanner results back to api-service. notification listens to orchestration events via Redis pub/sub. |
| 4 | `dashboard`, `admin-portal`, `findings`, `analysis`, `scanner-jobs` | Wave 1 (`api-service`) | Frontends call api-service at runtime (browser-side). scanner-jobs has RBAC only (no deployment). Deploy last so API is ready when users arrive. |

### GCP Managed Services (Not in Sync Waves)

These are provisioned by Terraform, not by ArgoCD:
- **Cloud SQL PostgreSQL**: Private IP, accessed via Cloud SQL Proxy sidecar
- **Memorystore Redis**: Private IP, accessed directly from pods
- **GCP Secret Manager**: Accessed via External Secrets Operator

---

## 3. ArgoCD ↔ GKE Cluster Registration

### For Bare-Metal ArgoCD → GKE (Remote Cluster Access)

If the bare-metal ArgoCD (argocd-local) needs to manage GKE workloads:

#### Step 1: Authorize the Bare-Metal Server

```bash
# In gcp-infrastructure Terraform, add to master_authorized_networks:
master_authorized_networks = [
  {
    cidr_block   = "{home-server-public-ip}/32"
    display_name = "argocd-bare-metal"
  }
]
```

#### Step 2: Get GKE Credentials

```bash
gcloud container clusters get-credentials {cluster-name} \
  --region us-west1 \
  --project {project-id}

# Verify connectivity
kubectl --context gke_{project}_{region}_{cluster} get nodes
```

#### Step 3: Create ArgoCD Service Account on GKE

```bash
kubectl config use-context gke_{project}_{region}_{cluster}

kubectl create namespace argocd-manager
kubectl create serviceaccount argocd-manager -n argocd-manager

kubectl create clusterrolebinding argocd-manager \
  --clusterrole=cluster-admin \
  --serviceaccount=argocd-manager:argocd-manager

# Create long-lived token (K8s 1.24+)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: argocd-manager-token
  namespace: argocd-manager
  annotations:
    kubernetes.io/service-account.name: argocd-manager
type: kubernetes.io/service-account-token
EOF

sleep 5

# Extract credentials
ARGOCD_TOKEN=$(kubectl get secret argocd-manager-token -n argocd-manager \
  -o jsonpath='{.data.token}' | base64 -d)
GKE_CA_CERT=$(kubectl get secret argocd-manager-token -n argocd-manager \
  -o jsonpath='{.data.ca\.crt}')
GKE_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
```

#### Step 4: Register in Bare-Metal ArgoCD (Declarative Secret)

```bash
kubectl config use-context kubernetes-admin@kubernetes

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: gke-production-cluster
  namespace: argocd-local
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: gke-production
  server: "${GKE_SERVER}"
  config: |
    {
      "bearerToken": "${ARGOCD_TOKEN}",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "${GKE_CA_CERT}"
      }
    }
EOF
```

#### Step 5: Verify

```bash
argocd cluster list --server https://argocd.blocksecops.local

# Expected:
# SERVER                          NAME             STATUS
# https://kubernetes.default.svc  in-cluster       Successful
# https://{gke-endpoint}          gke-production   Successful
```

#### Step 6: Store Credentials in Vault (Production)

```yaml
# k8s/overlays/local/argocd/gke-cluster-externalsecret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: gke-production-cluster
  namespace: argocd-local
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: gke-production-cluster
    creationPolicy: Owner
    template:
      metadata:
        labels:
          argocd.argoproj.io/secret-type: cluster
      data:
        name: gke-production
        server: "{{ .server }}"
        config: |
          {
            "bearerToken": "{{ .token }}",
            "tlsClientConfig": {
              "insecure": false,
              "caData": "{{ .ca_cert }}"
            }
          }
  data:
    - secretKey: server
      remoteRef:
        key: secret/local/argocd/gke-cluster
        property: server
    - secretKey: token
      remoteRef:
        key: secret/local/argocd/gke-cluster
        property: token
    - secretKey: ca_cert
      remoteRef:
        key: secret/local/argocd/gke-cluster
        property: ca_cert
```

### For GCP ArgoCD (In-Cluster — Already Configured)

The GCP ArgoCD in `argocd-prod` deploys to `https://kubernetes.default.svc` (its own cluster). No external registration needed.

### Network Requirements

The existing NetworkPolicies in `infra-argocd` already allow:
- `argocd-repo-server-egress`: Port 443 to external Git (GitHub)
- `argocd-application-controller-egress`: Port 443 to Kubernetes API (includes GKE)

---

## 4. Self-Managing ArgoCD Workflow

### Concept

ArgoCD can manage its own configuration through an Application that points to the `infra-argocd` repository. When you update ArgoCD's config in Git, ArgoCD detects the change and applies it to itself.

### Self-Management Application (for bare-metal)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd-self
  namespace: argocd-local
spec:
  project: default
  source:
    repoURL: https://github.com/BlockSecOps/infra-argocd
    targetRevision: main
    path: k8s/overlays/local/argocd
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd-local
  syncPolicy:
    automated:
      prune: false       # CRITICAL: Never auto-prune ArgoCD's own resources
      selfHeal: true
    syncOptions:
      - CreateNamespace=false
      - ApplyOutOfSyncOnly=true
      - ServerSideApply=true  # Avoid conflicts with ArgoCD's own mutations
```

### Self-Management Flow

```
1. Developer pushes change to infra-argocd/k8s/overlays/local/
   (e.g., update RBAC policy, resource limits, ArgoCD version)

2. ArgoCD detects the change (polls infra-argocd repo)

3. ArgoCD compares desired state (Git) vs live state (itself)

4. ArgoCD applies the diff to its own namespace
   → e.g., rolling restart of argocd-server with new limits

5. If ArgoCD pods restart, sync resumes when pods are healthy

SAFETY: prune=false prevents ArgoCD from deleting itself
SAFETY: selfHeal=true ensures manual kubectl changes revert
```

### Upgrading ArgoCD Version (Self-Managed)

```bash
# 1. Update the kustomization files in Git:
#    k8s/base/argocd/kustomization.yaml: change install.yaml URL version
#    k8s/overlays/local/argocd/kustomization.yaml: change newTag

# 2. Commit and push
git add -A && git commit -m "chore(argocd): upgrade to v2.14.0" && git push

# 3. ArgoCD detects and applies (rolling update, no downtime)

# 4. If upgrade fails and ArgoCD is down:
kubectl apply -k k8s/overlays/local/argocd/  # Manual recovery
```

---

## 5. Rollback Procedures

### 5a. Rolling Back a Service (Image Tag Revert)

**Scenario:** `api-service` with tag `sha-abc1234` has a bug.

```bash
# Option 1: Git revert (preferred — full audit trail)
cd ~/Git/blocksecops-gcp-infrastructure
git log --oneline k8s/overlays/gcp/services/api-service/
git revert {commit-sha}
git push
# ArgoCD detects → syncs old image tag → GKE rolls back

# Option 2: Manual kustomize edit
cd k8s/overlays/gcp/services/api-service
# Edit kustomization.yaml to set previous image tag
git add . && git commit -m "revert(api-service): rollback to sha-def5678" && git push

# Option 3: ArgoCD UI (emergency — bypasses Git, creates drift)
# ArgoCD UI → Applications → api-service → History → Rollback
# WARNING: Fix Git afterwards to match
```

### 5b. Rolling Back Multiple Services

**Scenario:** A coordinated release broke multiple services.

```bash
cd ~/Git/blocksecops-gcp-infrastructure
git log --oneline
git revert --no-commit HEAD~3..HEAD  # Revert last 3 commits
git commit -m "revert: rollback platform to pre-release state"
git push
# ArgoCD syncs all affected services back
```

### 5c. Rolling Back ArgoCD Itself

```bash
# If ArgoCD is still partially functional:
cd ~/Git/infra-argocd
git revert {upgrade-commit}
git push
# ArgoCD self-heal picks up the revert

# If ArgoCD is completely down:
cd ~/Git/infra-argocd
git checkout {last-known-good-sha}
kubectl apply -k k8s/overlays/local/argocd/
kubectl rollout status deployment argocd-server -n argocd-local
git checkout main  # Return to main for future changes
```

### 5d. Emergency: Disable Auto-Sync

```bash
# Disable for one application
argocd app set api-service --sync-policy none \
  --server https://argocd.blocksecops.local

# Disable for ALL applications
for app in $(argocd app list -o name --server https://argocd.blocksecops.local); do
  argocd app set "$app" --sync-policy none \
    --server https://argocd.blocksecops.local
done

# Re-enable after fixing
argocd app set api-service \
  --sync-policy automated --self-heal --auto-prune \
  --server https://argocd.blocksecops.local
```

### 5e. Rollback Decision Tree

```
Is the issue in a single service?
├── YES → Git revert the image tag commit (5a)
└── NO
     │
     Is ArgoCD itself broken?
     ├── YES → kubectl apply from last-known-good commit (5c)
     └── NO
          │
          Are services crash-looping?
          ├── YES → Disable auto-sync (5d), fix root cause, re-enable
          └── NO
               │
               Coordinated release failure?
               ├── YES → Git revert multiple commits (5b)
               └── NO → Check individual service logs
```

---

## 6. ApplicationSet Sync Configuration

### Current Sync Policy (from actual YAML)

| Setting | Value | Purpose |
|---------|-------|---------|
| `automated.prune` | `true` | Remove resources deleted from Git |
| `automated.selfHeal` | `true` | Revert manual kubectl changes |
| `automated.allowEmpty` | `false` | Prevent syncing empty directories |
| `CreateNamespace` | `true` | Auto-create service namespaces |
| `PrunePropagationPolicy` | `foreground` | Wait for dependents before deleting |
| `PruneLast` | `true` | Delete removed resources after applying new ones |
| `retry.limit` | `5` | Retry failed syncs |
| `retry.backoff` | `5s → 3m` | Exponential backoff on failures |
| `revisionHistoryLimit` | `10` | Keep 10 previous revisions |

### Health Checks

ArgoCD natively monitors:
- Deployments: available replicas == desired
- StatefulSets: ready replicas == desired
- Services: endpoints exist
- Jobs: succeeded
- PVCs: bound

For ExternalSecrets (used by all services), add custom health check to `argocd-cm`:

```yaml
resource.customizations.health.external-secrets.io_ExternalSecret: |
  hs = {}
  if obj.status ~= nil then
    if obj.status.conditions ~= nil then
      for i, condition in ipairs(obj.status.conditions) do
        if condition.type == "Ready" and condition.status == "True" then
          hs.status = "Healthy"
          hs.message = condition.message
          return hs
        end
      end
    end
  end
  hs.status = "Progressing"
  hs.message = "Waiting for secret sync"
  return hs
```

---

## 7. Steady-State GitOps Workflow

```
┌─────────────────────────────────────────────────────────────────────┐
│  STEADY-STATE WORKFLOW                                              │
│                                                                     │
│  1. Developer pushes code to blocksecops-{service} repo             │
│                                                                     │
│  2. GitHub Actions CI:                                              │
│     a. Lint → Test → Security scan                                  │
│     b. Docker build (using existing Dockerfile) + push to           │
│        Artifact Registry                                            │
│     c. Update image tag in blocksecops-gcp-infrastructure           │
│        at k8s/overlays/gcp/services/{service}/kustomization.yaml    │
│                                                                     │
│  3. ArgoCD (argocd-prod on GKE) polls gcp-infrastructure repo      │
│                                                                     │
│  4. ArgoCD detects image tag change:                                │
│     a. Compares Git manifest vs live GKE state                      │
│     b. Calculates diff (new image tag → new ReplicaSet)             │
│     c. Applies rolling update to GKE cluster                        │
│                                                                     │
│  5. GKE pulls new image from Artifact Registry                      │
│                                                                     │
│  6. ArgoCD reports: Synced / Healthy                                │
│                                                                     │
│  7. If failure: ArgoCD retries (5x with backoff)                    │
│     If still failing: developer does git revert                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 8. Known Issues to Address

From `docs/INFRA-AGENT.md`:

| Issue | Impact | Fix Location |
|-------|--------|-------------|
| Scanner job memory limit 512Mi (need 2-4Gi for fuzzers) | OOMKill | `blocksecops-orchestration/k8s/base/scanner-jobs/configmap.yaml` |
| No scanner job retries (`JOB_BACKOFF_LIMIT: "0"`) | Single failure = permanent failure | Same file |
| Job deadline 300s too short for fuzzers (600s internal timeout) | Jobs killed before completion | Same file |
| Production overlays reduce resources below base values | Services underprovisioned in prod | `*/k8s/overlays/production/patches/resource-patch.yaml` |
| No Prometheus alerting rules configured | No automated alerts | `blocksecops-aws-infrastructure/k8s/overlays/local/monitoring/` |
| Missing orchestration PDB in local | No disruption protection | `blocksecops-orchestration/k8s/base/` |
