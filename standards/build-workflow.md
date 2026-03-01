# Build Workflow

**Version:** 4.1.0
**Last Updated:** February 22, 2026

## Overview

Images are built locally with Docker, pushed to a container registry, and deployed via `kubectl apply`. The registry is configurable via the `REGISTRY` environment variable, defaulting to `harbor.blocksecops.local` for the server environment.

```
docker build → docker push ${REGISTRY}/blocksecops/<service>:<version> → kubectl apply -k
```

## Registry Configuration

All build commands use the `REGISTRY` variable for registry-agnostic builds:

```bash
# Default: Harbor (server environment)
REGISTRY="${REGISTRY:-harbor.blocksecops.local}"

# Override for GCP Artifact Registry
REGISTRY="us-west1-docker.pkg.dev/blocksecops-prod/blocksecops"

# Override for any other registry
REGISTRY="my-registry.example.com"
```

**Why a variable?**
- Supports Harbor (current server), GCP Artifact Registry (production), or any future registry
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

REGISTRY="${REGISTRY:-harbor.blocksecops.local}"

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

### Using Deploy Script (Recommended)

The deploy script enforces the full build-push-apply cycle, suspends CronJobs during deploy to prevent stale image execution, and verifies all images match after rollout:

```bash
# Full deploy: build → push → apply → verify
./scripts/deploy.sh

# Apply kustomization only (after manual build/push)
./scripts/deploy.sh --skip-build

# Preview what would happen
./scripts/deploy.sh --dry-run

# Or via Makefile (api-service)
make deploy
make deploy-apply
make deploy-dry-run
```

The script:
1. Extracts version from `pyproject.toml`/`package.json`
2. Verifies kustomization `newTag` matches — **fails if mismatch**
3. Builds and pushes Docker image
4. Runs `kubectl apply -k` (updates Deployments AND CronJobs)
5. Waits for rollout completion
6. Verifies all resource image tags match the source version

### Version Drift Checker

Run the platform-wide drift checker to detect version mismatches across all services:

```bash
# Check all services
/home/pwner/Git/scripts/check-version-drift.sh

# Only show drift (exit code 1 if any)
/home/pwner/Git/scripts/check-version-drift.sh --quiet
```

### Using Build Scripts (Legacy)

Each service has a build script for the build step only:

```bash
# Uses REGISTRY env var (defaults to harbor.blocksecops.local)
./scripts/build-image.sh

# Override registry
REGISTRY=us-west1-docker.pkg.dev/blocksecops-prod/blocksecops ./scripts/build-image.sh
```

**Note:** `build-image.sh` only builds — it does NOT push or apply. Use `deploy.sh` for the complete workflow.

### Kustomization Image Reference

Kustomization overlays specify the registry for their environment:

```yaml
# k8s/overlays/local/<service>/kustomization.yaml (Harbor)
images:
- name: <service>
  newName: harbor.blocksecops.local/blocksecops/<service>
  newTag: "0.29.0"

# k8s/overlays/gcp-production/<service>/kustomization.yaml (GCP)
images:
- name: <service>
  newName: us-west1-docker.pkg.dev/blocksecops-prod/blocksecops/<service>
  newTag: "0.29.0"
```

## Service-Specific Build Requirements

See [Docker Image Versioning](./docker-image-versioning.md) for detailed service-specific requirements, including:
- **Dashboard**: Requires parent directory build context + Supabase build args
- **Orchestration/Intelligence Engine**: Use pre-built base images from Harbor (see [Docker Base Images](./docker-base-images.md))

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

If Harbor is unavailable, import directly to containerd:

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
