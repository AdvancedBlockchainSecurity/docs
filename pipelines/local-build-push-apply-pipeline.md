# Local Build-Push-Apply Pipeline

**Version:** 1.0.0
**Last Updated:** February 22, 2026

## Overview

This document describes the local build-push-apply pipeline used for deploying services to the kubeadm development cluster with Harbor as the container registry. Unlike the GCP GitOps pipeline (ArgoCD + Artifact Registry), the local pipeline is developer-driven and uses the `deploy.sh` script for automation.

## Pipeline Architecture

```
Developer Workstation                    Kubernetes Cluster (kubeadm)
┌───────────────────────┐               ┌──────────────────────────┐
│                       │               │                          │
│  pyproject.toml ──────┤               │  Deployment              │
│       │               │               │    └─ Pod (new image)    │
│       v               │               │                          │
│  kustomization.yaml   │               │  CronJob (suspended)     │
│       │               │               │    └─ Updated spec       │
│       v               │               │                          │
│  docker build ────────┤──push──►Harbor│──pull──►  Pods           │
│       │               │               │                          │
│  kubectl apply -k ────┤──apply──────► │  CronJob (resumed)       │
│       │               │               │                          │
│  rollout verify ◄─────┤◄─status────── │                          │
└───────────────────────┘               └──────────────────────────┘
```

## Pipeline Stages

### Stage 1: Version Validation

```
Input:  pyproject.toml (or package.json)
Output: VERSION variable
Check:  kustomization.yaml newTag == VERSION
Fail:   Exit with error if mismatch
```

The version in the application source file is the single source of truth. The kustomization overlay must reference the same version. A mismatch indicates the developer forgot to update one of the two files.

### Stage 2: CronJob Suspend

```
Action: kubectl patch cronjob -n <namespace> --type=merge -p '{"spec":{"suspend":true}}'
Why:    Prevents CronJobs from executing with the old image during the deploy window
```

CronJobs that fire between the `docker push` and `kubectl apply` steps would use the old image spec. Suspending prevents this race condition.

### Stage 3: Docker Build

```
Input:  Dockerfile, source code, build args
Output: Tagged image in local Docker daemon
Tags:   ${REGISTRY}/blocksecops/<service>:${VERSION}
Args:   SERVICE_VERSION, BUILD_DATE, VCS_REF
```

### Stage 4: Docker Push

```
Input:  Tagged image in Docker daemon
Output: Image in Harbor registry
Target: harbor.blocksecops.local/blocksecops/<service>:<version>
Note:   Harbor enforces immutable tags — cannot overwrite existing versions
```

### Stage 5: Kustomize Apply

```
Command: kubectl apply -k k8s/overlays/local/<service>/
Updates: Deployment spec, CronJob spec, ConfigMaps, Services
Effect:  Triggers rolling update for Deployments; updates CronJob template for next execution
```

### Stage 6: CronJob Resume

```
Action: kubectl patch cronjob -n <namespace> --type=merge -p '{"spec":{"suspend":false}}'
Config: startingDeadlineSeconds: 600 (allows recovery of missed schedules)
```

### Stage 7: Rollout Verification

```
Command: kubectl rollout status deployment/<service> -n <namespace> --timeout=120s
Check:   Deployment image tag matches VERSION
Check:   CronJob image tag matches VERSION
Check:   Pod is Running and Ready
```

## Error Handling

| Failure Point | Behavior | Recovery |
|---------------|----------|----------|
| Version mismatch | Script exits before build | Fix kustomization.yaml or pyproject.toml |
| Docker build fails | Script exits, CronJobs still suspended | Fix build error, re-run deploy.sh |
| Docker push fails | Script exits | Check Harbor connectivity, re-run |
| kubectl apply fails | Script exits | Check RBAC, manifests, re-run |
| Rollout timeout | Script reports failure | Check pod logs, events |

If the script fails after suspending CronJobs, resume them manually:

```bash
kubectl get cronjob -n <namespace> -o name | xargs -I{} kubectl patch {} -n <namespace> --type=merge -p '{"spec":{"suspend":false}}'
```

## Comparison with GCP Pipeline

| Aspect | Local Pipeline | GCP Pipeline |
|--------|---------------|--------------|
| Trigger | Manual (developer runs deploy.sh) | Automatic (push to main) |
| Registry | Harbor (self-hosted) | GCP Artifact Registry |
| Deploy method | kubectl apply -k | ArgoCD sync |
| CronJob safety | suspend/resume in script | ArgoCD sync waves |
| Drift detection | check-version-drift.sh | ArgoCD diff |
| Rollback | kubectl rollout undo | ArgoCD rollback |

## Related Documentation

- [GitOps CI/CD Pipeline](./gitops-ci-cd-pipeline.md) - GCP production pipeline
- [Local Deployment Workflow](../workflows/local-deployment-workflow.md) - Workflow documentation
- [Build Workflow Standards](../standards/build-workflow.md) - Build standards
- [Docker Image Versioning](../standards/docker-image-versioning.md) - Version management
