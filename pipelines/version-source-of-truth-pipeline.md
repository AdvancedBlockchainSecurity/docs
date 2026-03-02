# Version Source-of-Truth Pipeline

**Version:** 1.0.0
**Last Updated:** March 1, 2026

## Overview

Technical pipeline for version propagation from source file through deployed Kubernetes resources. Covers the `deploy.sh` automation, `check-version-drift.sh` validation, Docker build args, OCI labels, and kustomization image references.

## Pipeline Architecture

```
Source File                  deploy.sh                    Kubernetes Cluster
───────────                  ─────────                    ──────────────────
pyproject.toml ──extract──►  Step 1: VERSION var
                             Step 2: Verify kustomization ◄── kustomization.yaml
                             Step 3: docker build ────────►  Harbor Registry
                             Step 4: docker push ─────────►  (immutable tag)
                             Step 5: Suspend CronJobs ────►  CronJobs paused
                             Step 6: kubectl apply -k ────►  Deployment + CronJob updated
                             Step 7: Rollout wait ◄───────── Rolling update
                             Step 8: Verify tags ◄────────── Image tag check
                             Step 9: Resume CronJobs ─────►  CronJobs active

check-version-drift.sh      (post-deploy / daily)
───────────────────────
  For each service:
    source_ver  ← pyproject.toml / package.json / Cargo.toml
    kustom_ver  ← kustomization.yaml newTag
    cluster_ver ← kubectl get deployment image tag
    cronjob_ver ← kubectl get cronjob image tag
    → DRIFT if any mismatch
```

---

## Pipeline Stages

### Stage 1: Version Extraction

```
Input:  pyproject.toml (Python) | package.json (Node.js) | Cargo.toml (Rust)
Output: SOURCE_VERSION variable
Method:
  Python: grep '^version' pyproject.toml | head -1 | cut -d'"' -f2
  Node:   grep '"version"' package.json | head -1 | cut -d'"' -f4
  Rust:   grep '^version' Cargo.toml | head -1 | cut -d'"' -f2
```

### Stage 2: Kustomization Validation

```
Input:  SOURCE_VERSION, k8s/overlays/local/<service>/kustomization.yaml
Check:  newTag == SOURCE_VERSION
Fail:   Exit 1 with error message showing both values
Fix:    Update kustomization newTag to match source file
```

This is a **hard gate** — no build occurs if versions don't match.

### Stage 3: Docker Build

```
Input:  Dockerfile, source code, build arguments
Output: Tagged image in local Docker daemon
Tag:    ${REGISTRY}/blocksecops/<service>:${SOURCE_VERSION}
Args:
  SERVICE_VERSION  ← SOURCE_VERSION (baked into OCI label)
  BUILD_DATE       ← date -u +'%Y-%m-%dT%H:%M:%SZ'
  VCS_REF          ← git rev-parse --short HEAD
```

All Dockerfiles consume these args identically:

```dockerfile
ARG SERVICE_VERSION=0.0.0
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.version="${SERVICE_VERSION}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
```

### Stage 4: Docker Push

```
Input:  Tagged image in Docker daemon
Output: Image in Harbor registry
Target: harbor.blocksecops.local/blocksecops/<service>:<version>
Note:   Harbor enforces immutable tags — push fails if tag exists
```

### Stage 5: CronJob Suspend

```
Action: kubectl patch cronjob -n <namespace> -p '{"spec":{"suspend":true}}'
Why:    Prevents CronJobs from firing with the old image spec between push and apply
Scope:  All CronJobs in the service namespace
```

### Stage 6: Kustomize Apply

```
Command: kubectl apply -k k8s/overlays/local/<service>/
Updates: Deployment spec, CronJob spec, ConfigMaps, Services
Effect:  Triggers rolling update for Deployments; updates CronJob template
```

### Stage 7: Rollout Wait

```
Command: kubectl rollout status deployment/<service> -n <namespace> --timeout=120s
```

### Stage 8: Post-Deploy Verification

```
For Deployments:
  Actual:   kubectl get deployment -o jsonpath='{.spec.template.spec.containers[0].image}'
  Expected: ${REGISTRY}/blocksecops/<service>:${SOURCE_VERSION}

For CronJobs:
  Actual:   kubectl get cronjob -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].image}'
  Expected: ${REGISTRY}/blocksecops/<service>:${SOURCE_VERSION}

Exit 1 if any mismatch.
```

### Stage 9: CronJob Resume

```
Action: kubectl patch cronjob -n <namespace> -p '{"spec":{"suspend":false}}'
Scope:  Only CronJobs that were suspended in Stage 5
```

---

## Drift Detection Pipeline

### Script: `check-version-drift.sh`

**Location:** `/home/pwner/Git/scripts/check-version-drift.sh`

Checks all platform services for version consistency across three layers:

```
For each service in registry:
  ┌─────────────────────────────────────────────────────────────┐
  │  source_ver  = pyproject.toml / package.json / Cargo.toml  │
  │  kustom_ver  = kustomization.yaml newTag                   │
  │  cluster_ver = kubectl get deployment image tag             │
  │  cronjob_ver = kubectl get cronjob image tag                │
  │                                                             │
  │  OK    if source == kustom == cluster == cronjob            │
  │  DRIFT if any mismatch                                      │
  └─────────────────────────────────────────────────────────────┘
```

### Service Registry

| Service | Repo | Version Type | Kustomize Path | Namespace |
|---------|------|-------------|----------------|-----------|
| api-service | blocksecops-api-service | py | `k8s/overlays/local/api-service` | api-service-local |
| dashboard | blocksecops-dashboard | js | `k8s/overlays/local` | dashboard-local |
| admin-portal | blocksecops-admin-portal | js | `k8s/overlays/local` | admin-portal-local |
| data-service | blocksecops-data-service | py | `k8s/overlays/local/data-service` | data-service-local |
| intelligence-engine | blocksecops-intelligence-engine | py | `k8s/overlays/local/intelligence-engine` | intelligence-engine-local |
| notification | blocksecops-notification | py | `k8s/overlays/local/notification` | notification-local |
| orchestration | blocksecops-orchestration | py | `k8s/overlays/local/orchestration` | orchestration-local |
| tool-integration | blocksecops-tool-integration | py | `k8s/overlays/local` | tool-integration-local |
| contract-parser | blocksecops-contract-parser | rs | `k8s/overlays/local/contract-parser` | contract-parser-local |

---

## Error Handling

| Failure Point | Behavior | Recovery |
|---------------|----------|----------|
| Version mismatch (stage 2) | Script exits before build | Update kustomization `newTag` to match source |
| Docker build fails (stage 3) | Script exits, CronJobs still suspended | Fix build error, re-run; or manually resume CronJobs |
| Docker push fails (stage 4) | Script exits | Check Harbor connectivity; if immutable tag conflict, bump version |
| kubectl apply fails (stage 6) | Script exits | Check RBAC, manifests; manually resume CronJobs |
| Rollout timeout (stage 7) | Script reports failure | Check pod logs/events |
| Verification fails (stage 8) | Non-zero exit | Investigate image tag in cluster vs expected |

**CronJob recovery after failure:**

```bash
kubectl get cronjob -n <namespace> -o name | \
  xargs -I{} kubectl patch {} -n <namespace> --type=merge -p '{"spec":{"suspend":false}}'
```

---

## Files Involved

| File | Location | Role |
|------|----------|------|
| `pyproject.toml` | `<service-repo>/pyproject.toml` | Python version source of truth |
| `package.json` | `<service-repo>/package.json` | Node.js version source of truth |
| `Cargo.toml` | `<service-repo>/Cargo.toml` | Rust version source of truth |
| `kustomization.yaml` | `<service-repo>/k8s/overlays/local/<service>/` | Kubernetes image tag reference |
| `Dockerfile` | `<service-repo>/Dockerfile` | Consumes `SERVICE_VERSION` build arg |
| `deploy.sh` | `<service-repo>/scripts/deploy.sh` | Full deploy pipeline automation |
| `check-version-drift.sh` | `/home/pwner/Git/scripts/check-version-drift.sh` | Platform-wide drift detection |
| `bump-version.sh` | `<service-repo>/scripts/bump-version.sh` | **Legacy** — updates `VERSION` file only |

---

## Related Documentation

- [Version Source-of-Truth Workflow](../workflows/version-source-of-truth-workflow.md)
- [Version Source-of-Truth Playbook](../playbooks/version-source-of-truth.md)
- [Local Build-Push-Apply Pipeline](./local-build-push-apply-pipeline.md)
- [Development to Production Pipeline](./dev-to-prod-pipeline.md)
- [Docker Image Versioning Standards](../standards/docker-image-versioning.md)
- [Build Workflow Standards](../standards/build-workflow.md)
- [Kustomize Standards](../standards/kustomize-standards.md)
