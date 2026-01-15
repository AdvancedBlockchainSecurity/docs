# Docker Image Versioning Standards

**Version:** 3.0.0
**Last Updated:** January 14, 2026

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
