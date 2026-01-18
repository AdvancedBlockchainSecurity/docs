# Docker Image Versioning Standards

**Version:** 3.1.0
**Last Updated:** January 17, 2026

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

### Step 3: Build and Deploy

See environment-specific workflows below.

### Step 4: Commit Together

```bash
git add pyproject.toml k8s/overlays/local/
git commit -m "chore(<service>): bump version to 0.2.1"
```

**CRITICAL:** Source version + kustomization must be committed together to stay in sync.

---

## Environment-Specific Workflows

### minikube (Recommended for Local Dev)

minikube shares its Docker daemon, so builds are immediately available:

```bash
# One-time setup per terminal session
eval $(minikube docker-env)

# Build and deploy (that's it!)
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
docker build -t blocksecops-<service>:$VERSION .
kubectl apply -k k8s/overlays/local/<service>/
```

### kubeadm with containerd

kubeadm uses containerd directly, requiring an extra import step:

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

**Tip:** Create an alias to simplify:
```bash
# Add to ~/.bashrc
build-and-import() {
  local svc=$1
  local ver=$(grep '^version' pyproject.toml | cut -d'"' -f2)
  docker build -t blocksecops-${svc}:${ver} . && \
  docker save blocksecops-${svc}:${ver} | sudo ctr -n k8s.io images import -
}
```

### kubeadm with Harbor (Recommended for Server)

Harbor provides proper registry semantics that match production:

```bash
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)
SERVICE="api-service"
REGISTRY="harbor.blocksecops.local"

# Build locally
docker build -t ${REGISTRY}/blocksecops/${SERVICE}:${VERSION} .

# Push to Harbor
docker push ${REGISTRY}/blocksecops/${SERVICE}:${VERSION}

# Deploy (Kubernetes pulls from Harbor)
kubectl apply -k k8s/overlays/server/${SERVICE}/
```

**Why Harbor instead of direct containerd import:**
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
kubectl apply -k k8s/overlays/server/${SERVICE}/
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

| Service | Version | Notes |
|---------|---------|-------|
| api-service | 0.10.2 | |
| dashboard | 0.30.4 | |
| data-service | 0.2.0 | |
| intelligence-engine | 0.2.0 | |
| notification | 0.1.2 | |
| orchestration | 0.9.1 | |
| tool-integration | 0.3.8 | |

All services are `0.x.x` (development phase). Version `1.0.0` indicates stable, production-ready API.

---

## OCI Image Labels

All Dockerfiles use OCI-compliant labels (not deprecated `org.label-schema`):

```dockerfile
ARG SERVICE_VERSION=0.0.0
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.title="BlockSecOps API Service"
LABEL org.opencontainers.image.description="Main API gateway for BlockSecOps platform"
LABEL org.opencontainers.image.version="${SERVICE_VERSION}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.vendor="BlockSecOps"
LABEL org.opencontainers.image.source="https://github.com/blocksecops/blocksecops-api-service"
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

## Related Documentation

- [Docker Standardization Plan](/home/pwner/Git/TaskDocs-BlockSecOps/DOCUMENTATION-UPDATE-2026-01-17-DOCKER-STANDARDIZATION-PLAN.md)
- [Harbor Local Installation](/home/pwner/Git/TaskDocs-BlockSecOps/phases/02-phase-3.1a1-add-harbor/HARBOR-LOCAL-INSTALLATION.md)
