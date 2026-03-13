# Docker Image Versioning Standards

**Version:** 4.0.0
**Last Updated:** March 10, 2026

## Owner Approval Required

**MANDATORY:** All version bumps, image builds, registry pushes, and Kustomize applies require explicit approval from the repository owner before execution. See [Core Development Rules — Rule 0](./core-development-rules.md#rule-0-gitops-requires-owner-approval).

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

### Step 1: Bump Version in Source and Kustomization Files

Update the version in the source of truth file and all kustomization `newTag` values manually:

1. Edit `pyproject.toml` (Python), `package.json` (Node.js), or `Cargo.toml` (Rust) — update the `version` field
2. Update all `kustomization.yaml` files under `k8s/overlays/` — set `newTag` to the new version
3. Update `app.kubernetes.io/version` labels in kustomization files (where present)

```bash
# Example: bumping from 0.5.25 to 0.5.26
# 1. Edit source of truth
sed -i 's/version = "0.5.25"/version = "0.5.26"/' pyproject.toml

# 2. Update all kustomization overlays
grep -rl 'newTag: "0.5.25"' k8s/ | xargs sed -i 's/newTag: "0.5.25"/newTag: "0.5.26"/'
grep -rl 'app.kubernetes.io/version: "0.5.25"' k8s/ | xargs sed -i 's/app.kubernetes.io\/version: "0.5.25"/app.kubernetes.io\/version: "0.5.26"/'
```

**All version references must be updated together** — source file, kustomization `newTag`, and `app.kubernetes.io/version` labels.

### Step 2: Build, Push, and Apply

**All three steps are MANDATORY and must happen together:**

```bash
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
SERVICE="api-service"
REGISTRY="${REGISTRY:?REGISTRY not set}"

# Build and push
docker build \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t ${REGISTRY}/blocksecops/${SERVICE}:${VERSION} .
docker push ${REGISTRY}/blocksecops/${SERVICE}:${VERSION}

# Apply kustomization — updates BOTH Deployment AND CronJob
kubectl apply -k k8s/overlays/local/${SERVICE}/
```

**CRITICAL:** `kubectl apply -k` must be run after every version bump. Without this step, Deployments and CronJobs in the cluster remain at the previously-applied version. This is especially dangerous for CronJobs, which will silently run old code on their next schedule while Deployments may appear updated after a `kubectl rollout restart`.

### Step 3: Verify Deployment

```bash
# Verify Deployment image matches
kubectl get deployment -n ${SERVICE}-local ${SERVICE} -o jsonpath='{.spec.template.spec.containers[0].image}'

# Verify CronJob image matches (if service has CronJobs)
kubectl get cronjob -n ${SERVICE}-local -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.jobTemplate.spec.template.spec.containers[0].image}{"\n"}{end}'
```

### Step 4: Commit Together

```bash
git add pyproject.toml k8s/
git commit -m "chore(<service>): bump version to 0.2.1"
```

**CRITICAL:** Source version + kustomization must be committed together to stay in sync.

---

## Version Sync Checklist

When bumping a version, ensure all three locations are updated:

| Location | What to Update |
|----------|---------------|
| `pyproject.toml` / `package.json` / `Cargo.toml` | `version` field |
| `k8s/overlays/*/kustomization.yaml` | `newTag` under `images:` |
| `k8s/overlays/*/kustomization.yaml` | `app.kubernetes.io/version` label (where present) |

**Verification:**
```bash
# Check all version references match
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
echo "Source: $VERSION"
grep -r "newTag:" k8s/overlays/ | grep -v "$VERSION" && echo "MISMATCH" || echo "All synced"
```

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
REGISTRY="${REGISTRY:?REGISTRY not set}"

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
REGISTRY="${REGISTRY:?REGISTRY not set}"

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

### Admin Portal (blocksecops-admin-portal)

The admin portal requires Supabase build-time environment variables (baked into static assets by Vite):

```bash
cd /home/pwner/Git/blocksecops-admin-portal

VERSION=$(grep '"version"' package.json | head -1 | cut -d'"' -f4)
REGISTRY="${REGISTRY:?REGISTRY not set}"

# Build with Supabase build args + OCI labels
docker build \
  --build-arg VITE_ADMIN_SUPABASE_URL=${SUPABASE_URL} \
  --build-arg VITE_ADMIN_SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY} \
  --build-arg VITE_ENVIRONMENT=local \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t ${REGISTRY}/blocksecops/admin-portal:${VERSION} .

# Push and deploy
docker push ${REGISTRY}/blocksecops/admin-portal:${VERSION}
kubectl apply -k k8s/overlays/local/
```

**Required environment variables:**
- `SUPABASE_URL` — Supabase project URL (shared with dashboard)
- `SUPABASE_ANON_KEY` — Supabase anon key (shared with dashboard)

These are passed as `VITE_ADMIN_SUPABASE_URL` and `VITE_ADMIN_SUPABASE_ANON_KEY` build args. The Dockerfile validates they are non-empty at build time.

**Key differences from dashboard:**
- Builds from **service directory** (no parent context needed — no shared lib dependency)
- Uses `VITE_ADMIN_SUPABASE_*` env var prefix (not `VITE_SUPABASE_*`)
- Kustomization overlay at `k8s/overlays/local/` (not a subdirectory)

### Other Services

Most services follow the standard pattern (build from service directory):

| Service | Build Context | Special Requirements |
|---------|---------------|---------------------|
| api-service | Service directory | None |
| admin-portal | Service directory | Supabase build args (`VITE_ADMIN_SUPABASE_*`) |
| dashboard | **Parent directory** | Supabase build args, shared lib, tier-config build |
| data-service | Service directory | None |
| intelligence-engine | Service directory | None |
| notification | Service directory | None |
| orchestration | Service directory | None |
| tool-integration | Service directory | None |

---

## Environment-Specific Workflows

### Self-Hosted Registry (Recommended)

A container registry provides proper registry semantics that match production:

```bash
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
SERVICE="api-service"
REGISTRY="${REGISTRY:?REGISTRY not set}"

# Build locally
docker build -t ${REGISTRY}/blocksecops/${SERVICE}:${VERSION} .

# Push to registry
docker push ${REGISTRY}/blocksecops/${SERVICE}:${VERSION}

# Deploy (Kubernetes pulls from registry)
kubectl apply -k k8s/overlays/local/${SERVICE}/
```

**Why a container registry instead of direct containerd import:**
- `imagePullPolicy: Always` actually works (triggers real pulls)
- Digest tracking detects image updates
- `:latest` tag behaves correctly
- Matches GCP Artifact Registry workflow

### Direct containerd Import (No Registry Fallback)

Direct import to containerd when no registry is available:

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

Build locally and push to Artifact Registry:

```bash
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
SERVICE="api-service"
REGISTRY="us-west1-docker.pkg.dev/project-8a2657b9-d96c-4c0a-a69/apogee"

# Build with OCI labels
docker build \
  --provenance=false \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  --target runtime \
  -t ${REGISTRY}/${SERVICE}:${VERSION} .

# Push to Artifact Registry
docker push ${REGISTRY}/${SERVICE}:${VERSION}

# Apply kustomization
kubectl apply -k k8s/overlays/gcp/
```

**Note:** `--provenance=false` disables BuildKit attestation manifests that cause push failures with some registries. Docker 23+ uses BuildKit by default — this flag ensures standard image manifests are produced.

---

## Immutable Tag Policy

**MANDATORY:** All image tags are immutable. Once a tag is pushed, it cannot be overwritten or deleted.

### Why Immutable Tags

| Concern | How Immutable Tags Help |
|---------|------------------------|
| Accidental overwrites | Cannot push same tag with different content |
| Accidental deletions | Cannot delete tags that are referenced by deployments |
| Reproducibility | Tag always resolves to the same image digest |
| Audit trail | Every version is permanently traceable |
| Environment parity | Same tag in local overlay translates to same content in GCP overlay |

### Registry Configuration

Immutable tags are enforced at the registry level (e.g., tag immutability rules in Harbor, IAM policies in GCP Artifact Registry). Consult your registry's documentation for configuration details.

### Version Bump Required for Changes

Because tags are immutable, any image change requires a version bump:

```bash
# Cannot do this (tag already exists, push will fail):
docker push ${REGISTRY}/blocksecops/api-service:0.28.2

# Must bump version first:
# 1. Update pyproject.toml: version = "0.28.3"
# 2. Update kustomization.yaml: newTag: "0.28.3"
# 3. Build and push with new tag
docker push ${REGISTRY}/blocksecops/api-service:0.28.3
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

Base images are stored in a container registry and referenced by application Dockerfiles:

```dockerfile
ARG BASE_REGISTRY
ARG BASE_IMAGE_TAG=1.0.0-ac02c353
FROM ${BASE_REGISTRY}/blocksecops/blocksecops-orchestration-base:${BASE_IMAGE_TAG} AS builder
```

---

## Scanner Image Versioning

Scanner images follow a **different versioning model** than service images. Scanners are standalone Docker images that run in Kubernetes Jobs, managed by the tool-integration service.

### Source of Truth

**ConfigMap `scanner-versions`** in the `tool-integration-local` namespace is the single source of truth for scanner image versions and metadata.

**File:** `blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml`

```yaml
data:
  SCANNER_METADATA: |
    {
      "slither": {
        "version": "0.11.5",
        "developer": "Crytic/Trail of Bits",
        "_note": "Updated 2026-03-04, upgraded from 0.11.3"
      },
      "mythril": {
        "version": "0.23.0",
        "developer": "ConsenSys",
        "_note": "Updated 2026-02-28, added memory limit handling"
      }
    }
  SCANNER_IMAGE_SLITHER: "${REGISTRY}/blocksecops/scanner-slither:0.3.2"
  SCANNER_IMAGE_MYTHRIL: "${REGISTRY}/blocksecops/scanner-mythril:0.4.1"
  # ... more scanners
```

### Dual Version Model

Each scanner has **two version numbers**:

| Version Type | Example | Purpose | Source |
|--------------|---------|---------|--------|
| **Upstream Tool Version** | `0.11.5` (slither) | Third-party scanner tool release | `SCANNER_METADATA[scanner].version` |
| **Apogee Scanner Image Version** | `0.3.2` | Our wrapper image version for K8s tracking | `SCANNER_IMAGE_*` tag |

**Why two versions?**
- Upstream versions change with each scanner release
- Image versions track wrapper changes, base image updates, and bug fixes
- Both are immutable in the registry
- Each increment requires a rebuild and push

### Scanner Image Tag Format

```
${REGISTRY}/blocksecops/scanner-{name}:{image-version}

Examples:
- ${REGISTRY}/blocksecops/scanner-slither:0.3.2
- ${REGISTRY}/blocksecops/scanner-mythril:0.4.1
```

### Semantic Versioning for Scanner Images

| Increment | When | Example |
|-----------|------|---------|
| **PATCH** | Wrapper script fix, base image update | `0.3.1` → `0.3.2` |
| **MINOR** | Upstream tool upgrade (new features) | `0.3.2` → `0.4.0` |
| **MAJOR** | Breaking wrapper changes | `0.4.0` → `1.0.0` |

### Dockerfile ARG Defaults

All scanner Dockerfiles use `ARG` with defaults that must match the ConfigMap:

**File:** `blocksecops-tool-integration/scanner-images/slither/Dockerfile`

```dockerfile
ARG SCANNER_IMAGE_VERSION=0.3.2
ARG UPSTREAM_TOOL_VERSION=0.11.5
ARG BUILD_DATE
ARG VCS_REF

FROM python:3.11-slim

LABEL org.opencontainers.image.title="Apogee Slither Scanner"
LABEL org.opencontainers.image.version="${SCANNER_IMAGE_VERSION}"
LABEL org.opencontainers.image.vendor="Apogee"
LABEL scanner.tool.version="${UPSTREAM_TOOL_VERSION}"

# Clone upstream scanner at specific version
RUN git clone --branch v${UPSTREAM_TOOL_VERSION} --depth 1 \
  https://github.com/crytic/slither.git .
```

**Critical:** The `ARG SCANNER_IMAGE_VERSION=X.Y.Z` default must exactly match the value in `SCANNER_IMAGE_*` ConfigMap key.

### KJM Fallback Defaults

The Kubernetes Job Manager (`src/scanners/kubernetes_job_manager.py`) in tool-integration maintains a `default_images` dict as a fallback when ConfigMap is unavailable:

```python
default_images = {
    "slither": f"{REGISTRY}/blocksecops/scanner-slither:0.3.2",
    "mythril": f"{REGISTRY}/blocksecops/scanner-mythril:0.4.1",
    # ... more scanners (REGISTRY from environment)
}
```

**Critical:** This fallback must be kept in sync with ConfigMap values. Update it whenever ConfigMap `SCANNER_IMAGE_*` tags change.

### OCI Labels

All scanner Dockerfiles use OCI-compliant labels (standard across all images):

```dockerfile
ARG SCANNER_IMAGE_VERSION=0.3.2
ARG UPSTREAM_TOOL_VERSION=0.11.5
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.title="Apogee Slither Scanner"
LABEL org.opencontainers.image.description="Slither security analysis tool"
LABEL org.opencontainers.image.version="${SCANNER_IMAGE_VERSION}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.vendor="Apogee"
LABEL scanner.tool.version="${UPSTREAM_TOOL_VERSION}"
```

Build with all ARGs:

```bash
docker build \
  --build-arg SCANNER_IMAGE_VERSION=0.3.2 \
  --build-arg UPSTREAM_TOOL_VERSION=0.11.5 \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t ${REGISTRY}/blocksecops/scanner-slither:0.3.2 \
  scanner-images/slither/
```

### Immutable Tags

Like all Apogee images, scanner image tags are immutable. **Any change to a Dockerfile requires a version bump** — you cannot overwrite an existing tag.

```
❌ WRONG: Rebuild scanner-slither:0.3.2 after Dockerfile change
           → Registry push will be rejected (tag already exists)

✅ CORRECT: Bump to 0.3.3, rebuild, push new tag
```

### Version Bump Workflow for Scanners

Complete procedure when updating a scanner:

```
1. Update ConfigMap SCANNER_METADATA version (upstream version)
2. Update ConfigMap SCANNER_METADATA _note field (changelog)
3. Update Dockerfile ARG SCANNER_IMAGE_VERSION default
4. Update Dockerfile ARG UPSTREAM_TOOL_VERSION (if upgrading tool)
5. Update KJM default_images dict to match ConfigMap
6. Build with all ARGs: BUILD_DATE, VCS_REF, SCANNER_IMAGE_VERSION, UPSTREAM_TOOL_VERSION
7. Push to registry
8. Apply ConfigMap: kubectl apply -k k8s/overlays/local/
9. Rebuild + push tool-integration service (since KJM default_images changed)
10. Verify scanner jobs use new image
```

See [Scanner Image Version Bump Workflow](../workflows/scanner-image-version-bump.md) for detailed steps.

### No pyproject.toml for Scanners

Unlike services (which use `pyproject.toml` as source of truth), scanner images:
- Are standalone Docker images in `scanner-images/<name>/`
- Have no Python project file
- Use ConfigMap as the single source of truth
- Require manual version updates in Dockerfile and ConfigMap

---

## Related Documentation

- [Docker Base Images](./docker-base-images.md) - Pre-built base images for heavy dependencies
- [Scanner Image Version Bump Workflow](../workflows/scanner-image-version-bump.md) - Step-by-step version bump procedure
- [Scanner Image Build Pipeline](../pipelines/scanner-image-build-pipeline.md) - Build and push pipeline
- [Scanner Image Rebuild Playbook](../playbooks/scanner-image-rebuild-all.md) - Rebuilding all 16 scanners
- [Docker Standardization Plan](/home/pwner/Git/TaskDocs-Apogee/DOCUMENTATION-UPDATE-2026-01-17-DOCKER-STANDARDIZATION-PLAN.md)
- [Harbor Local Installation](/home/pwner/Git/TaskDocs-Apogee/phases/02-phase-3.1a1-add-harbor/HARBOR-LOCAL-INSTALLATION.md)
