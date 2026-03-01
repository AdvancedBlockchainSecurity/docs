# Local Deployment Workflow

**Version:** 1.0.0
**Last Updated:** February 22, 2026

## Overview

This document covers the local deployment workflow for the Apogee platform running on kubeadm with Harbor registry. The workflow ensures the full version-build-push-apply-verify cycle is completed atomically, preventing version drift between source code, kustomization, and running cluster resources.

## Architecture

```
pyproject.toml/package.json (source of truth)
        |
        v
kustomization.yaml newTag (must match)
        |
        v
docker build → docker push → kubectl apply -k → rollout verify
                                    |
                            CronJob suspend/resume
```

## Automated Deploy (Recommended)

### deploy.sh Script

Each service that supports automated deployment has a `scripts/deploy.sh` script:

```bash
cd /home/pwner/Git/blocksecops-<service>

# Full deploy cycle
./scripts/deploy.sh

# Apply only (skip build/push)
./scripts/deploy.sh --skip-build

# Dry run (preview only)
./scripts/deploy.sh --dry-run
```

### What deploy.sh Does

1. **Version extraction** - Reads version from `pyproject.toml` (Python) or `package.json` (Node.js)
2. **Kustomization check** - Verifies `newTag` in kustomization.yaml matches the source version. Fails immediately if mismatch detected.
3. **CronJob suspend** - Suspends all CronJobs in the service namespace to prevent stale image execution during the deploy window
4. **Docker build** - Builds the image with OCI labels (`SERVICE_VERSION`, `BUILD_DATE`, `VCS_REF`)
5. **Docker push** - Pushes to Harbor at `harbor.blocksecops.local/blocksecops/<service>:<version>`
6. **kubectl apply -k** - Applies kustomization overlay, updating both Deployments and CronJobs
7. **CronJob resume** - Re-enables CronJobs after apply completes
8. **Rollout wait** - Waits for deployment rollout to complete
9. **Image verification** - Checks that Deployment and CronJob images match the expected version

### Makefile Targets (api-service)

```bash
make deploy          # Full deploy
make deploy-apply    # Apply only (--skip-build)
make deploy-dry-run  # Dry run
```

## Manual Deploy

When not using deploy.sh, follow these steps in order:

```bash
SERVICE="api-service"
cd /home/pwner/Git/blocksecops-${SERVICE}

# 1. Read version from source
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)

# 2. Verify kustomization matches
grep "newTag" k8s/overlays/local/${SERVICE}/kustomization.yaml
# Must show: newTag: "${VERSION}"

# 3. Build
REGISTRY="${REGISTRY:-harbor.blocksecops.local}"
docker build \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t ${REGISTRY}/blocksecops/${SERVICE}:${VERSION} .

# 4. Push
docker push ${REGISTRY}/blocksecops/${SERVICE}:${VERSION}

# 5. Apply (updates BOTH Deployment AND CronJobs)
kubectl apply -k k8s/overlays/local/${SERVICE}/

# 6. Wait for rollout
kubectl rollout status deployment/${SERVICE} -n ${SERVICE}-local --timeout=120s

# 7. Verify images
kubectl get deployment -n ${SERVICE}-local ${SERVICE} \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
kubectl get cronjob -n ${SERVICE}-local \
  -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.jobTemplate.spec.template.spec.containers[0].image}{"\n"}{end}'
```

## Platform-Wide Version Drift Check

After deployments, run the drift checker to verify all services are aligned:

```bash
/home/pwner/Git/scripts/check-version-drift.sh

# Quiet mode (exit code 1 if drift detected)
/home/pwner/Git/scripts/check-version-drift.sh --quiet
```

The drift checker compares three sources for each service:
1. **Source** - Version in `pyproject.toml` or `package.json`
2. **Kustomize** - `newTag` in kustomization.yaml
3. **Cluster** - Image tag on running Deployment and CronJobs

Any mismatch is flagged as drift and must be resolved before the service is considered properly deployed.

## CronJob Safety

CronJobs are particularly vulnerable to version drift because:
- They run on a schedule, not on rollout restart
- If `kubectl apply -k` is missed after a version bump, CronJobs silently run old code
- Unlike Deployments, there is no equivalent of `kubectl rollout restart` for CronJobs

The deploy.sh script addresses this by:
- Suspending CronJobs before the apply step
- Resuming after apply completes
- Setting `startingDeadlineSeconds: 600` to prevent missed schedules from queuing up

## Related Documentation

- [Build Workflow](../standards/build-workflow.md) - Registry configuration and build details
- [Docker Image Versioning](../standards/docker-image-versioning.md) - Semantic versioning and service versions
- [Deploy New Image Playbook](../playbooks/deploy-new-image.md) - Step-by-step deployment playbook
- [ArgoCD GitOps Deployment](./argocd-gitops-deployment-workflow.md) - GCP production deployment
- [Smoke Test](../standards/smoke-test.md) - Post-deployment verification
