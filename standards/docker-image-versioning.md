# Docker Image Versioning Standards

**Version:** 3.6.0
**Last Updated:** February 27, 2026

## Single Source of Truth

The **application version file** is the single source of truth:

| Language | Source File | Field |
|----------|-------------|-------|
| Python | `pyproject.toml` | `version = "X.Y.Z"` |
| Node.js | `package.json` | `"version": "X.Y.Z"` |

All other version references are **derived** from this source.

## Semantic Versioning

All versions follow [Semantic Versioning 2.0.0](https://semver.org/):

| Increment | When | Example |
|-----------|------|---------|
| **PATCH** | Bug fixes, security patches | `0.3.12` → `0.3.13` |
| **MINOR** | New features (backwards-compatible) | `0.3.13` → `0.4.0` |
| **MAJOR** | Breaking changes | `0.4.0` → `1.0.0` |

## Version Bump Workflow

### Step 1: Update the Source

```bash
# Python service
sed -i 's/version = ".*"/version = "0.2.1"/' pyproject.toml

# Node.js service
npm version 0.2.1 --no-git-tag-version
```

### Step 2: Update Kustomization

The kustomization `newTag` must match the source version:

```yaml
# k8s/overlays/local/<service>/kustomization.yaml
images:
- name: <service>
  newName: blocksecops-<service>
  newTag: "0.2.1"  # Must match pyproject.toml/package.json
```

**Note:** The `app.kubernetes.io/version` label is optional and can be removed to reduce duplication.

### Step 3: Build, Push, and Apply

**All three steps are MANDATORY and must happen together:**

```bash
VERSION="0.2.1"
SERVICE="api-service"
REGISTRY="${REGISTRY:-harbor.blocksecops.local}"

# Build and push
docker build -t ${REGISTRY}/blocksecops/${SERVICE}:${VERSION} .
docker push ${REGISTRY}/blocksecops/${SERVICE}:${VERSION}

# Apply kustomization — updates BOTH Deployment AND CronJob
kubectl apply -k k8s/overlays/local/${SERVICE}/
```

**CRITICAL:** `kubectl apply -k` must be run after every version bump. Without this step, Deployments and CronJobs in the cluster remain at the previously-applied version. This is especially dangerous for CronJobs, which will silently run old code on their next schedule while Deployments may appear updated after a `kubectl rollout restart`.

### Step 4: Verify Deployment

```bash
# Verify Deployment image matches
kubectl get deployment -n ${SERVICE}-local ${SERVICE} -o jsonpath='{.spec.template.spec.containers[0].image}'

# Verify CronJob image matches (if service has CronJobs)
kubectl get cronjob -n ${SERVICE}-local -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.jobTemplate.spec.template.spec.containers[0].image}{"\n"}{end}'
```

### Step 5: Commit Together

```bash
git add pyproject.toml k8s/overlays/local/
git commit -m "chore(<service>): bump version to 0.2.1"
```

**CRITICAL:** Source version + kustomization must be committed together to stay in sync.

---

## Service-Specific Build Requirements

Some services have special build requirements due to shared dependencies or build-time environment variables.

### Dashboard (blocksecops-dashboard)

The dashboard requires:
1. **Parent directory context** - Dockerfile references `blocksecops-shared` sibling directory
2. **Build-time environment variables** - Supabase credentials are baked into static assets

```bash
cd /home/pwner/Git  # Parent directory containing both repos

VERSION=$(grep '"version"' blocksecops-dashboard/package.json | head -1 | cut -d'"' -f4)
REGISTRY="${REGISTRY:-harbor.blocksecops.local}"

# Get Supabase credentials from existing ConfigMap
SUPABASE_URL=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_url}')
SUPABASE_KEY=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_anon_key}')
WALLETCONNECT_ID=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.VITE_WALLETCONNECT_PROJECT_ID}')

# Build with required build args
docker build \
  -f blocksecops-dashboard/Dockerfile \
  --build-arg VITE_SUPABASE_URL=${SUPABASE_URL} \
  --build-arg VITE_SUPABASE_ANON_KEY=${SUPABASE_KEY} \
  --build-arg VITE_WALLETCONNECT_PROJECT_ID=${WALLETCONNECT_ID} \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(cd blocksecops-dashboard && git rev-parse --short HEAD) \
  -t ${REGISTRY}/blocksecops/dashboard:${VERSION} .

# Push and deploy
docker push ${REGISTRY}/blocksecops/dashboard:${VERSION}
kubectl apply -k blocksecops-dashboard/k8s/overlays/local/
```

**Why parent directory context?**
- Dashboard imports `@blocksecops/shared` from sibling `blocksecops-shared/typescript/`
- Dashboard imports `@blocksecops/tier-config` from sibling `blocksecops-shared/tier-config/typescript/`
- Dockerfile uses `COPY blocksecops-shared /workspace/blocksecops-shared`
- Dockerfile builds `@blocksecops/tier-config` package inside Docker before dashboard `npm install`
- Build context must include both directories

**Build prerequisites:**
- The root `.dockerignore` (`/home/pwner/Git/.dockerignore`) excludes `**/dist` and `**/node_modules`
- Tier-config `dist/` is built inside Docker (not copied from host)
- Dashboard `tsconfig.json` has `paths` mapping for `@blocksecops/tier-config` pointing to `../blocksecops-shared/tier-config/typescript/dist` for reliable type resolution in Docker builds
- Do NOT create ambient `.d.ts` files in `src/types/` that redeclare `@blocksecops/tier-config` — this overrides the real package types and causes missing export errors

### API Service (blocksecops-api-service)

Standard build from service directory:

```bash
cd /home/pwner/Git/blocksecops-api-service

VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
REGISTRY="${REGISTRY:-harbor.blocksecops.local}"

# Build image
docker build \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t ${REGISTRY}/blocksecops/api-service:${VERSION} .

# Push and deploy
docker push ${REGISTRY}/blocksecops/api-service:${VERSION}
kubectl apply -k k8s/overlays/local/api-service/
```

### Other Services

Most services follow the standard pattern (build from service directory):

| Service | Build Context | Special Requirements |
|---------|---------------|---------------------|
| api-service | Service directory | None |
| dashboard | **Parent directory** | Supabase build args, shared lib, tier-config build |
| data-service | Service directory | None |
| intelligence-engine | Service directory | None |
| notification | Service directory | None |
| orchestration | Service directory | None |
| tool-integration | Service directory | None |

---

## Environment-Specific Workflows

### kubeadm with Harbor (Recommended)

Harbor provides proper registry semantics that match production:

```bash
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
SERVICE="api-service"
REGISTRY="${REGISTRY:-harbor.blocksecops.local}"

# Build locally
docker build -t ${REGISTRY}/blocksecops/${SERVICE}:${VERSION} .

# Push to registry
docker push ${REGISTRY}/blocksecops/${SERVICE}:${VERSION}

# Deploy (Kubernetes pulls from registry)
kubectl apply -k k8s/overlays/local/${SERVICE}/
```

**Note:** Services deployed on the server still use `k8s/overlays/local/` kustomization. The `server/` overlay in `blocksecops-gcp-infrastructure` only contains IngressRoutes and CORS middleware for the `app.0xapogee.local` domain.

**Why a registry (Harbor/Artifact Registry) instead of direct containerd import:**
- `imagePullPolicy: Always` actually works (triggers real pulls)
- Digest tracking detects image updates
- `:latest` tag behaves correctly
- Matches GCP Artifact Registry workflow

### kubeadm with containerd (Fallback)

Direct import to containerd when Harbor is unavailable:

```bash
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
SERVICE="api-service"

# Build in Docker
docker build -t blocksecops-${SERVICE}:${VERSION} .

# Bridge to containerd
docker save blocksecops-${SERVICE}:${VERSION} | sudo ctr -n k8s.io images import -

# Deploy
kubectl apply -k k8s/overlays/local/${SERVICE}/
```

**Limitation:** No pull semantics - `imagePullPolicy: Always` won't re-pull updated images.

### GCP with Artifact Registry (Production)

CI/CD handles everything automatically:

1. Commit code with updated version
2. CI reads version from source file
3. CI builds and pushes to Artifact Registry
4. CI updates kustomization `newTag`
5. ArgoCD detects change and deploys

---

## Immutable Tag Policy

**MANDATORY:** All image tags in Harbor are immutable. Once a tag is pushed, it cannot be overwritten or deleted.

### Why Immutable Tags

| Concern | How Immutable Tags Help |
|---------|------------------------|
| Accidental overwrites | Cannot push same tag with different content |
| Accidental deletions | Cannot delete tags that are referenced by deployments |
| Reproducibility | Tag always resolves to the same image digest |
| Audit trail | Every version is permanently traceable |
| Environment parity | Same tag in local overlay translates to same content in GCP overlay |

### Harbor Configuration

Immutable tags are enforced at the Harbor project level via tag immutability rules:

```bash
# Verify immutable tag rule exists
curl -s -k -u admin:${HARBOR_PASSWORD} \
  https://harbor.blocksecops.local/api/v2.0/projects/blocksecops/immutabletagrules | jq
```

The rule matches all repositories (`**`) and all tags (`**`) in the `blocksecops` project.

### Version Bump Required for Changes

Because tags are immutable, any image change requires a version bump:

```bash
# Cannot do this (tag already exists, push will fail):
docker push harbor.blocksecops.local/blocksecops/api-service:0.28.2

# Must bump version first:
# 1. Update pyproject.toml: version = "0.28.3"
# 2. Update kustomization.yaml: newTag: "0.28.3"
# 3. Build and push with new tag
docker push harbor.blocksecops.local/blocksecops/api-service:0.28.3
```

### GCP Equivalent

In GCP Artifact Registry, immutability is enforced differently:

- **IAM policies** restrict delete permissions to admin roles only
- **Binary Authorization** can enforce that only signed/approved images are deployed
- **Vulnerability scanning** automatically scans pushed images

The workflow is the same: always bump the version, never overwrite a tag.

---

## Why Not `latest` Tag?

Per [Kubernetes documentation](https://kubernetes.io/docs/concepts/containers/images/):

| Explicit Versions | `latest` Tag |
|-------------------|--------------|
| Know what's running | Unknown version |
| Easy rollback | No rollback target |
| Reproducible builds | May vary between pulls |
| Tag change triggers rollout | Requires manual restart |

---

## Current Service Versions

| Service | Version | Kustomization Path | Notes |
|---------|---------|-------------------|-------|
| admin-portal | 0.7.6 | `k8s/overlays/local/` | Apogee rebrand: UI branding, metadata, vite config |
| api-service | 0.29.42 | `k8s/overlays/local/api-service/` | Tier gate fixes (integrations→team, IDE tokens→growth), automated database backup CronJob |
| contract-parser | 0.2.2 | `k8s/overlays/local/contract-parser/` | Apogee rebrand: OCI source URL, .env.example |
| dashboard | 0.46.11 | `k8s/overlays/local/` | Sidebar ABC ordering, Teams modal styling, dark mode toggle fix, scanner preset counts |
| data-service | 0.2.7 | `k8s/overlays/local/` | Apogee rebrand: OCI source URL, README |
| findings | 0.2.1 | `k8s/overlays/local/findings/` | Apogee rebrand: OCI labels, .env.example |
| analysis | 0.2.1 | `k8s/overlays/local/analysis/` | Apogee rebrand: OCI labels, .env.example |
| ui-core | 0.2.1 | `k8s/overlays/local/ui-core/` | Apogee rebrand: OCI labels, .env.example |
| intelligence-engine | 0.3.7 | `k8s/overlays/local/` | Apogee rebrand: OCI source/vendor, base images, .env |
| notification | 0.2.6 | `k8s/overlays/local/` | Apogee rebrand: OCI source URL |
| orchestration | 0.10.8 | `k8s/overlays/local/` | Apogee rebrand: OCI source URL, README |
| tool-integration | 0.5.11 | `k8s/overlays/local/` | Health probes, NetworkPolicy, server header removal |
| scanner-slither | 0.3.3 | N/A (scanner image) | find -L symlink fix |
| scanner-aderyn | 0.7.3 | N/A (scanner image) | find -L symlink fix |
| scanner-semgrep | 0.3.8 | N/A (scanner image) | find -L symlink fix |
| scanner-solhint | 0.1.8 | N/A (scanner image) | Robust JSON extraction fix |
| scanner-vyper | 0.3.1 | N/A (scanner image) | find -L symlink fix |
| scanner-moccasin | 0.3.1 | N/A (scanner image) | find -L symlink fix |
| scanner-halmos | 0.3.1 | N/A (scanner image) | find -L symlink fix |
| scanner-echidna | 0.3.2 | N/A (scanner image) | find -L symlink fix |
| scanner-medusa | 0.3.2 | N/A (scanner image) | find -L symlink fix |
| scanner-wake | 0.3.8 | N/A (scanner image) | find -L symlink fix |
| scanner-soliditydefend | 0.9.1 | N/A (scanner image) | find -L fix + code snippet extraction |
| scanner-sol-azy | 0.4.2 | N/A (scanner image) | find -L symlink fix |
| scanner-cargo-fuzz-solana | 0.3.1 | N/A (scanner image) | find -L symlink fix |
| scanner-trident | 0.3.1 | N/A (scanner image) | find -L symlink fix |
| scanner-rustdefend | 0.4.2 | N/A (scanner image) | v0.5.1: FP reduction (347 fewer), 61 detectors, custom rules engine |

### Infrastructure Images (Harbor)

| Image | Version | Harbor Path | Notes |
|-------|---------|-------------|-------|
| prometheus | v3.2.1 | `blocksecops/prometheus` | Metrics collection, disabled by default |
| prometheus-adapter | v0.11.2 | `blocksecops/prometheus-adapter` | HPA custom metrics bridge |

All services are `0.x.x` (development phase). Version `1.0.0` indicates stable, production-ready API.

---

## OCI Image Labels

All Dockerfiles use OCI-compliant labels (not deprecated `org.label-schema`):

```dockerfile
ARG SERVICE_VERSION=0.0.0
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.title="Apogee API Service"
LABEL org.opencontainers.image.description="Main API gateway for Apogee platform"
LABEL org.opencontainers.image.version="${SERVICE_VERSION}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.vendor="Apogee"
LABEL org.opencontainers.image.source="https://github.com/AdvancedBlockchainSecurity/blocksecops-api-service"
```

### Build with Labels

```bash
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
docker build \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t blocksecops-api-service:${VERSION} .
```

### Verify Labels

```bash
docker inspect --format='{{json .Config.Labels}}' blocksecops-api-service:${VERSION} | jq
```

---

## BuildKit Cache Mount Best Practices

When using BuildKit cache mounts in multi-stage Dockerfiles, use unique cache IDs to prevent lock conflicts during parallel builds.

### Problem

Cache mounts without IDs share the same cache across all stages:

```dockerfile
# BAD: Both stages share the same apt cache, causing lock conflicts
FROM python:3.11-slim AS builder
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && apt-get install -y gcc

FROM python:3.11-slim AS runtime
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && apt-get install -y curl
```

Error: `E: Could not get lock /var/lib/apt/lists/lock. It is held by process 0`

### Solution

Use unique cache IDs for each stage:

```dockerfile
# GOOD: Each stage has its own cache
FROM python:3.11-slim AS builder
RUN --mount=type=cache,id=apt-cache-builder,target=/var/cache/apt \
    --mount=type=cache,id=apt-lib-builder,target=/var/lib/apt \
    apt-get update && apt-get install -y gcc

FROM python:3.11-slim AS runtime
RUN --mount=type=cache,id=apt-cache-runtime,target=/var/cache/apt \
    --mount=type=cache,id=apt-lib-runtime,target=/var/lib/apt \
    apt-get update && apt-get install -y curl
```

### Cache ID Naming Convention

Use descriptive IDs: `{cache-type}-{stage-name}`

| Stage | Cache Type | ID Example |
|-------|------------|------------|
| builder | apt cache | `apt-cache-builder` |
| builder | apt lib | `apt-lib-builder` |
| runtime | apt cache | `apt-cache-runtime` |
| runtime | pip | `pip-cache-runtime` |

---

---

## Base Images

Some services use pre-built base images to optimize build times. See [Docker Base Images](./docker-base-images.md) for details.

### Base Image Workflow

| Service | Base Image | When to Rebuild |
|---------|------------|-----------------|
| intelligence-engine | `blocksecops-intelligence-base-cpu` | ML dependency changes |
| orchestration | `blocksecops-orchestration-base` | Security tool updates |

### Base Image Tag Format

```
{version}-{dockerfile-hash}
Example: 1.0.0-5ede3c61
```

Base images are stored in Harbor and referenced by application Dockerfiles:

```dockerfile
ARG BASE_REGISTRY=harbor.blocksecops.local
ARG BASE_IMAGE_TAG=1.0.0-ac02c353
FROM ${BASE_REGISTRY}/blocksecops/blocksecops-orchestration-base:${BASE_IMAGE_TAG} AS builder
```

---

## Related Documentation

- [Docker Base Images](./docker-base-images.md) - Pre-built base images for heavy dependencies
- [Docker Standardization Plan](/home/pwner/Git/TaskDocs-Apogee/DOCUMENTATION-UPDATE-2026-01-17-DOCKER-STANDARDIZATION-PLAN.md)
- [Harbor Local Installation](/home/pwner/Git/TaskDocs-Apogee/phases/02-phase-3.1a1-add-harbor/HARBOR-LOCAL-INSTALLATION.md)
