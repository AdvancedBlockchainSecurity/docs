# Build Workflow

**Version:** 6.0.0
**Last Updated:** March 10, 2026

## Owner Approval Required

**MANDATORY:** All build, push, and deploy operations require explicit approval from the repository owner before execution. Do not build images, push to any registry, or apply Kustomize manifests without the owner's direct sign-off. See [Core Development Rules — Rule 0](./core-development-rules.md#rule-0-gitops-requires-owner-approval).

## Overview

Images are built locally with Docker, pushed to a container registry, and deployed via `kubectl apply`. The registry is configurable per environment via the `REGISTRY` environment variable.

```
docker build → docker push ${REGISTRY}/blocksecops/<service>:<version> → kubectl apply -k
```

## Registry Configuration

All build commands use the `REGISTRY` variable for registry-agnostic builds:

```bash
# Set for your environment:
# GCP:   REGISTRY="us-west1-docker.pkg.dev/<project>/apogee"
# Other: REGISTRY="my-registry.example.com/blocksecops"
export REGISTRY="<your-registry>"
```

**Why a variable?**
- Supports any container registry (self-hosted, GCP Artifact Registry, etc.)
- Build scripts, Dockerfiles, and CI/CD pipelines all use the same pattern
- Switch environments by changing one variable

## Build and Deploy Workflow

### Standard Service Build

```bash
cd /home/pwner/Git/blocksecops-<service>

# Read version from source of truth
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)  # Python
# or
VERSION=$(grep '"version"' package.json | head -1 | cut -d'"' -f4)  # Node.js

REGISTRY="${REGISTRY:?REGISTRY not set}"

# Build
docker build \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t ${REGISTRY}/blocksecops/<service>:${VERSION} .

# Push to registry
docker push ${REGISTRY}/blocksecops/<service>:${VERSION}

# Deploy
kubectl apply -k k8s/overlays/local/<service>/
```

> **MANDATORY:** All three `--build-arg` flags above are required, not optional.
>
> Without `SERVICE_VERSION`, `BUILD_DATE`, and `VCS_REF`, the resulting image's OCI labels (`org.opencontainers.image.version`, `.created`, `.revision`) will fall back to Dockerfile ARG defaults — typically a stale or generic value. This breaks **provenance tracing**: you cannot determine which Git commit produced a deployed image, when it was built, or whether the running version matches the source-of-truth `pyproject.toml`/`package.json`.
>
> **A build that omits any of these args is non-compliant** and must be re-built before pushing. Per the immutable tag policy, this means bumping the version (since the existing tag cannot be overwritten).
>
> **Single quick verification after build:**
> ```bash
> docker inspect --format='{{json .Config.Labels}}' ${REGISTRY}/blocksecops/<service>:${VERSION} | jq '."org.opencontainers.image.created", ."org.opencontainers.image.revision"'
> ```
> If either is empty/null, the build args were missed.

### Version Drift Checker

Run the platform-wide drift checker to detect version mismatches across all services:

```bash
# Check all services
/home/pwner/Git/scripts/check-version-drift.sh

# Only show drift (exit code 1 if any)
/home/pwner/Git/scripts/check-version-drift.sh --quiet
```

### Kustomization Image Reference

Kustomization overlays specify the registry for their environment:

```yaml
# k8s/overlays/<env>/<service>/kustomization.yaml
images:
- name: <service>
  newName: <registry>/blocksecops/<service>
  newTag: "0.29.0"

# Example: GCP Artifact Registry
# k8s/overlays/gcp-production/<service>/kustomization.yaml
images:
- name: <service>
  newName: us-west1-docker.pkg.dev/blocksecops-prod/blocksecops/<service>
  newTag: "0.29.0"
```

## Service-Specific Build Requirements

See [Docker Image Versioning](./docker-image-versioning.md) for detailed service-specific requirements, including:
- **Dashboard**: Requires parent directory build context + Supabase build args
- **Orchestration/Intelligence Engine**: Use pre-built base images from the container registry (see [Docker Base Images](./docker-base-images.md))

## Force Deployment Update

If kubectl apply doesn't trigger a rollout (same image tag):

```bash
# Option 1: Rollout restart
kubectl rollout restart deployment/<service> -n <namespace>

# Option 2: Set image explicitly
kubectl set image deployment/<service> <service>=<service>:<new-version> -n <namespace>
```

## Verifying Images

```bash
# Check what's in the registry
docker pull ${REGISTRY}/blocksecops/<service>:<version>

# Check what's running in cluster
kubectl get pods -n <namespace> -o jsonpath='{.items[*].spec.containers[*].image}'

# Check local Docker images
docker images | grep <service>
```

## Troubleshooting

### Pod stuck in ImagePullBackOff

```bash
# Check if image exists in registry
docker pull ${REGISTRY}/blocksecops/<service>:<version>

# Check pod events
kubectl describe pod -n <namespace> <pod-name>

# Verify imagePullPolicy
kubectl get deployment -n <namespace> <service> -o jsonpath='{.spec.template.spec.containers[0].imagePullPolicy}'
```

### Deployment not updating

```bash
# Force a rollout
kubectl rollout restart deployment/<service> -n <namespace>

# Wait for rollout
kubectl rollout status deployment/<service> -n <namespace>
```

### containerd Fallback (No Registry Available)

Fallback for environments without a container registry — import directly to containerd:

```bash
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
docker build -t blocksecops-<service>:${VERSION} .
docker save blocksecops-<service>:${VERSION} | sudo ctr -n k8s.io images import -
kubectl apply -k k8s/overlays/local/<service>/
```

**Limitation:** No pull semantics - `imagePullPolicy: Always` won't re-pull updated images.

---

## Related Standards

- [Docker Image Versioning](./docker-image-versioning.md) - Semantic versioning and service-specific builds
- [Docker Base Images](./docker-base-images.md) - Pre-built base images for heavy dependencies
- [Testing & Deployment](./testing-deployment.md) - Testing before deployment
