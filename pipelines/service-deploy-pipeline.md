# Service Deploy Pipeline

**Version:** 1.0.0
**Last Updated:** February 22, 2026
**Status:** Active

## Overview

This document defines the service deployment pipeline for both the development cluster (kubeadm + Harbor) and production (GKE + ArgoCD). The core safety invariant is the same across environments: **CronJobs must never execute stale images during a deployment.**

```
                    DEVELOPMENT CLUSTER                          GCP PRODUCTION
                    (Manual / deploy.sh)                         (ArgoCD + GitHub Actions)

Developer           Developer
    │                   │
    ▼                   ▼
pyproject.toml      pyproject.toml
    │                   │
    ▼                   ▼
docker build        GitHub Actions CI
docker push         → lint → test → build → push
    │                   │
    ▼                   ▼
Harbor              GCP Artifact Registry
    │                   │
    ▼                   ▼
deploy.sh           ArgoCD sync
├─ suspend CJs      ├─ sync wave 0: Deployments
├─ kubectl apply    ├─ sync wave 1: CronJobs (after Deployments healthy)
├─ rollout wait     ├─ health check
├─ verify images    └─ status: Synced
└─ resume CJs
```

---

## Development Cluster Pipeline

### Tools

| Tool | Location | Purpose |
|------|----------|---------|
| `deploy.sh` | `<service>/scripts/deploy.sh` | Full build-push-apply-verify cycle |
| `check-version-drift.sh` | `/home/pwner/Git/scripts/check-version-drift.sh` | Platform-wide version consistency check |
| `Makefile` | `<service>/Makefile` | Convenience targets (`make deploy`) |

### Pipeline Steps (deploy.sh)

```
Step 1: Extract Version
        Read version from pyproject.toml (Python) or package.json (Node.js)

Step 2: Verify Kustomization
        Compare newTag in kustomization.yaml against source version
        FAIL if mismatch → prevents applying stale manifests

Step 3: Docker Build
        Build image with OCI labels (SERVICE_VERSION, BUILD_DATE, VCS_REF)

Step 4: Docker Push
        Push to ${REGISTRY:-harbor.0xapogee.local}/blocksecops/<service>:<version>

Step 5: Suspend CronJobs                  ◄── SAFETY: prevents stale image execution
        Patch all CronJobs in namespace to suspend: true
        Track which CronJobs were suspended for later resumption

Step 6: kubectl apply -k
        Apply kustomization overlay (updates Deployment AND CronJob image tags)

Step 7: Rollout Wait
        kubectl rollout status — wait for Deployment pods to be ready

Step 8: Verify Images
        Confirm Deployment container image matches expected version
        Confirm CronJob container image matches expected version

Step 9: Resume CronJobs                   ◄── SAFETY: only after verified
        Unpatch CronJobs that were suspended in Step 5
```

### Usage

```bash
# Full deploy: build → push → apply → verify
./scripts/deploy.sh

# Apply only (after manual build/push)
./scripts/deploy.sh --skip-build

# Preview without executing
./scripts/deploy.sh --dry-run

# Override registry
./scripts/deploy.sh --registry us-west1-docker.pkg.dev/blocksecops-prod/blocksecops

# Via Makefile (api-service)
make deploy
make deploy-apply
make deploy-dry-run
```

### Version Drift Detection

Run the platform-wide drift checker before or after deployments:

```bash
# Check all services for version mismatches
/home/pwner/Git/scripts/check-version-drift.sh

# Quiet mode (exit code 1 if drift detected)
/home/pwner/Git/scripts/check-version-drift.sh --quiet
```

Output:
```
=== Version Drift Check ===
  OK:    api-service         source=0.29.8  kustomize=0.29.8  cluster=0.29.8  cronjob=0.29.8
  DRIFT: dashboard           source=0.46.1  kustomize=0.46.0  cluster=0.46.0
  OK:    data-service        source=0.2.1   kustomize=0.2.1   cluster=0.2.1
```

Compares four sources for each service:
1. **Source** — `pyproject.toml` or `package.json` (single source of truth)
2. **Kustomize** — `newTag` in kustomization overlay
3. **Cluster Deployment** — running container image tag
4. **Cluster CronJob** — CronJob template container image tag (if any)

---

## GCP Production Pipeline

### Architecture

Production uses two independent loops connected only by Git:

| Loop | Tool | Trigger | Responsibility |
|------|------|---------|----------------|
| **CI** | GitHub Actions | Push to main | Lint, test, build, push image, update image tag in gcp-infrastructure repo |
| **CD** | ArgoCD | Git poll (3 min) | Detect manifest change, sync to GKE, verify health |

### CI Pipeline (GitHub Actions)

```yaml
# Triggered on push to main branch of any service repo
on:
  push:
    branches: [main]

jobs:
  lint-and-test:
    # ruff check, mypy, pytest, bandit, safety

  build-and-push:
    # docker build → push to GCP Artifact Registry
    # Tag: sha-<commit-hash>

  update-manifests:
    # Update newTag in blocksecops-gcp-infrastructure repo
    # This triggers ArgoCD sync
```

See [GitOps CI/CD Pipeline](./gitops-ci-cd-pipeline.md) for complete GitHub Actions workflow templates.

### CD Pipeline (ArgoCD)

ArgoCD watches `blocksecops-gcp-infrastructure` repo and syncs to GKE:

```
ArgoCD polls Git (3 min) → detects newTag change → rolling update → health check → Synced
```

**CronJob safety in ArgoCD** is handled differently than the development cluster:

| Mechanism | How It Works |
|-----------|-------------|
| **Sync Waves** | CronJobs annotated with `sync-wave: "1"` deploy after Deployments (wave 0) |
| **Health Checks** | ArgoCD waits for Deployment health before advancing to next wave |
| **PreSync Hook** (optional) | Job that suspends CronJobs before sync starts |
| **PostSync Hook** (optional) | Job that resumes CronJobs after sync completes |

#### Sync Wave Configuration

```yaml
# Deployment (wave 0 — deploys first)
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"

# CronJob (wave 1 — deploys after Deployment is healthy)
apiVersion: batch/v1
kind: CronJob
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

This ensures ArgoCD applies the Deployment first, waits for it to be healthy, then updates the CronJob — preventing the window where a CronJob could run with a stale image.

#### PreSync/PostSync Hooks (Advanced)

For additional safety, add ArgoCD resource hooks:

```yaml
# PreSync: Suspend CronJobs before sync
apiVersion: batch/v1
kind: Job
metadata:
  name: presync-suspend-cronjobs
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
      - name: suspend
        image: bitnami/kubectl:latest
        command: ["sh", "-c"]
        args:
        - |
          for cj in $(kubectl get cronjob -n $NAMESPACE --no-headers -o name); do
            kubectl patch -n $NAMESPACE $cj -p '{"spec":{"suspend":true}}'
          done
      restartPolicy: Never

# PostSync: Resume CronJobs after sync
apiVersion: batch/v1
kind: Job
metadata:
  name: postsync-resume-cronjobs
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
      - name: resume
        image: bitnami/kubectl:latest
        command: ["sh", "-c"]
        args:
        - |
          for cj in $(kubectl get cronjob -n $NAMESPACE --no-headers -o name); do
            kubectl patch -n $NAMESPACE $cj -p '{"spec":{"suspend":false}}'
          done
      restartPolicy: Never
```

See [ArgoCD GitOps Deployment Workflow](../workflows/argocd-gitops-deployment-workflow.md) for the full ArgoCD configuration.

---

## CronJob Safety Invariant

**Principle:** CronJobs must never execute with a stale image during or after a deployment.

This invariant exists because `kubectl apply -k` updates Deployment and CronJob specs atomically, but:
- Deployments trigger a **rolling update** immediately (new pods replace old)
- CronJobs only run on their **next schedule** — if skipped, they silently run old code

### Root Cause (February 22, 2026 Incident)

During rapid iteration (30+ version bumps in 4 days), `kubectl apply -k` was occasionally skipped after version bumps. The Deployment was restarted manually with `kubectl rollout restart`, which picked up the new image — but the CronJob spec in the cluster still referenced the old image tag. The deduplication CronJob ran at 2 AM with image `0.29.5` while source was at `0.29.7`.

### Prevention Layers

| Layer | Environment | Mechanism |
|-------|------------|-----------|
| 1. Runtime check | Both | `verify_migration_compatibility()` — CronJob checks Alembic revision at startup, aborts if schema mismatch |
| 2. Deploy-time suspension | Dev cluster | `deploy.sh` suspends CronJobs during apply, resumes after verification |
| 2. Deploy-time ordering | GCP production | ArgoCD sync waves: Deployments (wave 0) before CronJobs (wave 1) |
| 3. Deadline enforcement | Both | `startingDeadlineSeconds: 600` — skips run if >10 minutes late (e.g., suspended during long deploy) |
| 4. Drift detection | Dev cluster | `check-version-drift.sh` — compares source, kustomize, cluster, and CronJob image tags |

### CronJob Spec Requirements

All CronJobs must include:

```yaml
spec:
  concurrencyPolicy: Forbid          # Prevent overlapping runs
  startingDeadlineSeconds: 600       # Skip if >10min late
  successfulJobsHistoryLimit: 3      # Retain last 3 successful
  failedJobsHistoryLimit: 3          # Retain last 3 failed
  jobTemplate:
    spec:
      activeDeadlineSeconds: 3600    # Kill after 1 hour
      backoffLimit: 2                # Retry up to 2 times
```

---

## Environment Comparison

| Aspect | Dev Cluster (kubeadm) | GCP Production (GKE) |
|--------|----------------------|---------------------|
| Registry | Harbor (`harbor.0xapogee.local`) | GCP Artifact Registry |
| Build trigger | Manual / `deploy.sh` | GitHub Actions on push to main |
| Deploy trigger | `kubectl apply -k` | ArgoCD auto-sync |
| CronJob safety | Script suspends/resumes | Sync waves + optional hooks |
| Drift detection | `check-version-drift.sh` | ArgoCD drift detection (auto-heal) |
| Rollback | Manual (`kubectl rollout undo`) | ArgoCD revision history |
| Image tags | Semver (`0.29.8`) | Semver + SHA (`sha-abc1234`) |
| Manifests | Per-service repo `k8s/overlays/local/` | `blocksecops-gcp-infrastructure/k8s/overlays/gcp/` |

---

## Related Documentation

- [Build Workflow](../standards/build-workflow.md) — Build commands and registry configuration
- [Docker Image Versioning](../standards/docker-image-versioning.md) — Semantic versioning and version bump workflow
- [GitOps CI/CD Pipeline](./gitops-ci-cd-pipeline.md) — GitHub Actions workflow templates for GCP
- [ArgoCD GitOps Deployment Workflow](../workflows/argocd-gitops-deployment-workflow.md) — ArgoCD ApplicationSet and sync configuration
- [Testing & Deployment](../standards/testing-deployment.md) — Pre-deployment testing requirements
- [Deduplication Maintenance Pipeline](./deduplication-pipeline.md) — CronJob that motivated this safety pattern
