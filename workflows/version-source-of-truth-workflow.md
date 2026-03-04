# Version Source-of-Truth Workflow

**Version:** 1.1.0
**Last Updated:** March 4, 2026

## Overview

Documents the end-to-end version lifecycle from source file through deployed pod, including all touchpoints, data transformations, and the two environment-specific pipelines (local and GCP).

## Services Involved

| Component | Role | Source of Truth |
|-----------|------|-----------------|
| `pyproject.toml` | Python service version | `version = "X.Y.Z"` |
| `package.json` | Node.js service version | `"version": "X.Y.Z"` |
| `Cargo.toml` | Rust service version | `version = "X.Y.Z"` |
| Kustomization overlay | Kubernetes image tag | `newTag: "X.Y.Z"` |
| Docker image | OCI label + registry tag | `--build-arg SERVICE_VERSION` |
| Harbor | Immutable image storage (local) | Tag cannot be overwritten |
| Artifact Registry | Immutable image storage (GCP) | IAM-controlled |

## Version Lifecycle

```
Phase 1: Version Bump (Developer)
──────────────────────────────────
Developer → Update pyproject.toml (or package.json)
                    │
                    └── version = "0.29.54"


Phase 2: Kustomization Auto-Sync
────────────────────────────────
After source version is updated, sync-version.sh auto-syncs all kustomization.yaml files:

deploy.sh or manual sync call:
                    │
                    ├── /home/pwner/Git/blocksecops-shared/scripts/docker/sync-version.sh
                    │       └── Reads source version (pyproject.toml)
                    │       └── Updates all k8s/overlays/*/kustomization.yaml newTag: "0.29.54"
                    │       └── Updates app.kubernetes.io/version labels
                    │
                    └── Result: All kustomization files now match source version


Phase 3: Build + Tag (deploy.sh or CI)
───────────────────────────────────────
Source version extracted at build time
                    │
                    ├── docker build --build-arg SERVICE_VERSION=0.29.54
                    │       ├── Image tag: registry/blocksecops/<service>:0.29.54
                    │       └── OCI label: org.opencontainers.image.version=0.29.54
                    │
                    └── docker push → Harbor (local) or Artifact Registry (GCP)
                            └── Immutable: tag cannot be overwritten


Phase 4: Deploy
───────────────
kubectl apply -k k8s/overlays/local/<service>/
                    │
                    ├── Deployment spec updated → rolling update triggered
                    ├── CronJob spec updated → next execution uses new image
                    └── Kubernetes pulls image from registry


Phase 5: Verification
─────────────────────
deploy.sh verifies post-rollout:
                    │
                    ├── Deployment image tag == source version
                    ├── CronJob image tag == source version
                    └── Pod Running + Ready


Phase 6: Commit
───────────────
git add pyproject.toml k8s/overlays/local/<service>/kustomization.yaml
git commit   ← source + kustomization committed together (MANDATORY)
```

## Version Flow Diagram

```
                    ┌──────────────────────────────────┐
                    │      SOURCE OF TRUTH              │
                    │                                   │
                    │  pyproject.toml  │  package.json   │
                    │  version="X.Y.Z" │ "version":"X.Y.Z"│
                    └────────┬─────────┴────────┬───────┘
                             │                  │
               ┌─────────────┼──────────────────┘
               │             │
               ▼             ▼
    ┌──────────────────┐  ┌──────────────────────────┐
    │ kustomization.yaml│  │ docker build              │
    │ newTag: "X.Y.Z"  │  │ --build-arg SERVICE_VERSION│
    │                  │  │ -t registry/svc:X.Y.Z     │
    └────────┬─────────┘  └──────────┬───────────────┘
             │                       │
             │                       ▼
             │            ┌──────────────────────┐
             │            │ Container Registry    │
             │            │ (Harbor / Artifact    │
             │            │  Registry)            │
             │            │ Immutable tag: X.Y.Z  │
             │            └──────────┬───────────┘
             │                       │
             ▼                       │
    ┌──────────────────────────────────────────────┐
    │     kubectl apply -k                          │
    │                                               │
    │  Deployment.spec.template.containers[0].image │
    │    → registry/blocksecops/svc:X.Y.Z           │
    │                                               │
    │  CronJob.spec.jobTemplate.containers[0].image │
    │    → registry/blocksecops/svc:X.Y.Z           │
    └──────────────────────────────────────────────┘
```

## Two Pipelines, Same Source of Truth

| Aspect | Local Pipeline | GCP Pipeline |
|--------|---------------|--------------|
| Source of truth | `pyproject.toml` / `package.json` | Same |
| Version extraction | `deploy.sh` reads source file | GitHub Actions reads source file |
| Kustomization update | `sync-version.sh` (automatic) | CI bot commits `newTag` to infra repo |
| Mismatch detection | `deploy.sh` auto-syncs on mismatch | CI validates before build |
| Build | `docker build` on dev machine | GitHub Actions runner |
| Registry | Harbor (immutable tags) | GCP Artifact Registry |
| Deploy trigger | `kubectl apply -k` (manual) | Config Sync polls Git (automatic) |
| CronJob safety | `deploy.sh` suspend/resume | ArgoCD sync waves |
| Drift detection | `check-version-drift.sh` | Config Sync continuous |
| Rollback | `kubectl rollout undo` | `git revert` + Config Sync |

## Enforcement Points

| Check | Where | Consequence |
|-------|-------|-------------|
| Source == kustomization `newTag` | `deploy.sh` step 2 | Auto-sync if mismatch, then proceed |
| Immutable tags | Harbor project config | Push rejected if tag already exists |
| Post-deploy image tag verification | `deploy.sh` step 8 | Non-zero exit + error output if mismatch |
| Platform-wide drift | `check-version-drift.sh` | Exit code 1 if any service drifted |
| Owner approval | All GitOps operations | Rule 0 — no automation without sign-off |

## Legacy Version File (Deprecated)

Some services contain a `VERSION` file and `bump-version.sh` script from an older workflow. These are **not** the source of truth:

| Mechanism | Status | Source | Updates |
|-----------|--------|--------|---------|
| `pyproject.toml` / `package.json` | **Current standard** | Source of truth | kustomization + Docker tag |
| `VERSION` file + `bump-version.sh` | **Legacy (stale)** | Reads `VERSION` file | `VERSION` + `k8s/base/deployment.yaml` |

The `VERSION` file does not update `pyproject.toml` or kustomization `newTag`. It should not be relied upon.

## Related Documentation

- [Version Source-of-Truth Pipeline](../pipelines/version-source-of-truth-pipeline.md)
- [Version Source-of-Truth Playbook](../playbooks/version-source-of-truth.md)
- [Docker Image Versioning Standards](../standards/docker-image-versioning.md)
- [Build Workflow Standards](../standards/build-workflow.md)
- [Local Build-Push-Apply Pipeline](../pipelines/local-build-push-apply-pipeline.md)
- [Development to Production Pipeline](../pipelines/dev-to-prod-pipeline.md)
