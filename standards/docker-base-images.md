# Docker Base Image Standards

**Version:** 2.1.0
**Last Updated:** January 26, 2026
**Status:** Active

## Overview

This standard defines the strategy for optimizing Docker build times using pre-built base images stored in Harbor. Services with heavy dependencies that rarely change should use dedicated base images to separate dependency installation from application code changes.

## Problem

Some services have long build times (~15-20 minutes) because they install large dependency sets from scratch on every build. Code-only changes trigger full dependency reinstalls, wasting CI/CD time and developer productivity.

## Solution

Create separate base images containing pre-installed heavy dependencies, store them in Harbor, and have application Dockerfiles build FROM these base images. Code changes only require copying files (~2-3 minutes instead of ~15-20 minutes).

---

## Services Using Base Images

| Service | Base Image (Harbor) |
|---------|---------------------|
| `blocksecops-intelligence-engine` | `harbor.blocksecops.local/blocksecops/blocksecops-intelligence-base-cpu` |
| `blocksecops-orchestration` | `harbor.blocksecops.local/blocksecops/blocksecops-orchestration-base` |

**Note:** GPU variant available: `blocksecops-intelligence-base-gpu`

## Build Time Comparison

| Scenario | Before | After |
|----------|--------|-------|
| Code change only | ~15-20 min | ~2-3 min |
| App dependency change | ~15-20 min | ~5-7 min |
| Base dependency change | ~15-20 min | ~15-20 min (base only) |

---

## Registry Location

Base images MUST be stored in a container registry to ensure availability and prevent deletion:

| Environment | Registry (`REGISTRY` value) | Example |
|-------------|----------|---------|
| **Local/Server** | `harbor.blocksecops.local` | `${REGISTRY}/blocksecops/blocksecops-intelligence-base-cpu:1.0.0-<hash>` |
| **Production** | `us-central1-docker.pkg.dev/solidity-security` | `${REGISTRY}/blocksecops/blocksecops-intelligence-base-cpu:1.0.0` |

### Why Harbor for Base Images

1. **Persistence** - Images won't be deleted by `docker prune`
2. **Availability** - Always available for builds without rebuilding
3. **Versioning** - Proper tag management and history
4. **Security Scanning** - Harbor can scan for vulnerabilities
5. **Team Sharing** - All developers use the same base images

---

## Base Image Versioning

Base images are versioned using a hash of their dependency specification:

- **Tag format**: `{version}-{requirements-hash}` (e.g., `1.0.0-e4beef6a`)
- **Hash source**: SHA256 of Dockerfile content (first 8 chars)
- **Rebuild trigger**: Any change to Dockerfile or requirements triggers new hash

### Current Versions

| Base Image | Tag | Dockerfile Hash |
|------------|-----|-----------------|
| `blocksecops-intelligence-base-cpu` | `1.0.0-5ede3c61` | 5ede3c61 (trimmed base-ml.txt, 7 packages, 1.85GB) |
| `blocksecops-orchestration-base` | `1.0.0-ac02c353` | ac02c353 |

---

## Directory Structure

### Intelligence Engine

```
blocksecops-intelligence-engine/
├── docker/
│   ├── base/
│   │   ├── Dockerfile.cpu           # CPU base image
│   │   └── Dockerfile.gpu           # GPU base image (CUDA)
│   └── build-base-image.sh          # Build script
├── requirements/
│   ├── base-ml.txt                  # ML dependencies (for base image)
│   └── base.txt                     # App-specific dependencies (lightweight)
└── Dockerfile                       # App image (FROM base)
```

### Orchestration

```
blocksecops-orchestration/
├── docker/
│   ├── base/
│   │   └── Dockerfile.orchestration # Security tools base image
│   └── build-base-image.sh          # Build script
├── requirements/
│   └── base.txt                     # App-specific dependencies
└── Dockerfile                       # App image (FROM base)
```

---

## Security Hardening

All base images MUST implement these security measures:

### 1. Checksum Verification for Binaries

```dockerfile
ARG ADERYN_VERSION=0.5.13
ARG ADERYN_SHA256=3a85c5067e10c29290907799e6937d93f01dc2dfb82bf980cd61aebd33ffa6ab
RUN wget -q https://github.com/cyfrin/aderyn/releases/download/aderyn-v${ADERYN_VERSION}/aderyn-x86_64-unknown-linux-gnu.tar.xz && \
    echo "${ADERYN_SHA256}  aderyn-x86_64-unknown-linux-gnu.tar.xz" | sha256sum -c - && \
    tar -xf aderyn-x86_64-unknown-linux-gnu.tar.xz && \
    mv */aderyn /usr/local/bin/aderyn && \
    chmod +x /usr/local/bin/aderyn && \
    rm -rf aderyn-*
```

### 2. Base Image Pinned by Digest

```dockerfile
FROM python:3.11-slim@sha256:5be45dbade29bebd6886af6b438fd7e0b4eb7b611f39ba62b430263f82de36d2 AS base
```

### 3. Non-Root User with No Shell

```dockerfile
RUN groupadd --gid 1000 appuser && \
    useradd --uid 1000 --gid appuser --shell /sbin/nologin --create-home appuser && \
    chmod 700 /home/appuser
```

### 4. Restricted Directory Permissions

```dockerfile
RUN mkdir -p /app/logs /app/data && \
    chown -R appuser:appuser /app/logs /app/data && \
    chmod 700 /app/logs /app/data
```

### 5. Pinned Package Versions

```dockerfile
RUN pip install --no-cache-dir \
    slither-analyzer==0.10.0 \
    crytic-compile==0.3.6 \
    solc-select==1.0.4
```

### 6. Git Repos Pinned to Commits

```dockerfile
ARG ANALYZER_COMMIT=8a9d1ebb7d362bc94f036fa9123d0977c6cb7436
RUN git clone https://github.com/Picodes/4naly3er.git /opt/4naly3er && \
    cd /opt/4naly3er && \
    git checkout ${ANALYZER_COMMIT}
```

---

## Dependency Conflict Resolution with Pipx

Some Python tools have conflicting dependencies. Use **pipx** to isolate them:

### Problem Tools

| Tool | Conflict |
|------|----------|
| `semgrep` | Requires `rich~=13.5.2`, conflicts with other packages |
| `eth-wake` | Requires older `eth-abi`, `eth-account`, `eth-utils` versions |

### Solution: Pipx Isolation

```dockerfile
# Install pipx with shared location for appuser access
ENV PIPX_HOME=/opt/pipx \
    PIPX_BIN_DIR=/opt/pipx/bin
RUN pip install --no-cache-dir pipx==1.7.1 && \
    mkdir -p /opt/pipx/bin && \
    pipx ensurepath

# Install conflicting tools via pipx (isolated virtualenvs)
RUN pipx install semgrep==1.97.0 && \
    /opt/pipx/bin/semgrep --version

RUN pipx install eth-wake==4.20.1 && \
    /opt/pipx/bin/wake --version

# Set permissions so appuser can execute
RUN chmod -R 755 /opt/pipx

# Add to PATH
ENV PATH="/opt/pipx/bin:/home/appuser/.local/bin:$PATH"
```

### Verification

```dockerfile
RUN pip check && echo "No dependency conflicts"
```

---

## Build Workflow

### Step 1: Build Base Image

```bash
cd blocksecops-orchestration  # or blocksecops-intelligence-engine
./docker/build-base-image.sh
```

The script:
1. Calculates hash from Dockerfile content
2. Builds image with tag `{version}-{hash}`
3. Tags as `latest`

### Step 2: Push to Registry

```bash
REGISTRY="${REGISTRY:-harbor.blocksecops.local}"

# Tag for registry
docker tag blocksecops/blocksecops-orchestration-base:1.0.0-ac02c353 \
  ${REGISTRY}/blocksecops/blocksecops-orchestration-base:1.0.0-ac02c353

docker tag blocksecops/blocksecops-orchestration-base:latest \
  ${REGISTRY}/blocksecops/blocksecops-orchestration-base:latest

# Push to registry
docker push ${REGISTRY}/blocksecops/blocksecops-orchestration-base:1.0.0-ac02c353
docker push ${REGISTRY}/blocksecops/blocksecops-orchestration-base:latest
```

### Step 3: Update Application Dockerfile

Update the `FROM` line to reference Harbor using the `BASE_REGISTRY` ARG pattern:

```dockerfile
ARG BASE_REGISTRY=harbor.blocksecops.local
ARG BASE_VARIANT=cpu
ARG BASE_IMAGE_TAG=latest

FROM ${BASE_REGISTRY}/blocksecops/blocksecops-intelligence-base-${BASE_VARIANT}:${BASE_IMAGE_TAG} AS builder
```

**Why `BASE_REGISTRY` ARG?**
- Allows switching registries without modifying Dockerfile
- Supports both local Harbor and production GCP Artifact Registry
- Can override at build time: `--build-arg BASE_REGISTRY=us-central1-docker.pkg.dev/project/repo`

### Step 4: Build Application Image

```bash
cd blocksecops-orchestration
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)

docker build \
  --build-arg BASE_IMAGE_TAG=latest \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t blocksecops-orchestration:${VERSION} .
```

### Step 5: Push Application Image to Registry

```bash
REGISTRY="${REGISTRY:-harbor.blocksecops.local}"
docker tag blocksecops-orchestration:${VERSION} \
  ${REGISTRY}/blocksecops/orchestration:${VERSION}
docker push ${REGISTRY}/blocksecops/orchestration:${VERSION}
```

---

## Deployment Requirements

### For All Base Image Services

| Requirement | Setting | Why |
|-------------|---------|-----|
| Image pull policy | `imagePullPolicy: IfNotPresent` | Allows Harbor pulls (not `Never`) |
| Kustomize labels | `includeSelectors: false` | Prevents immutable selector errors |
| Kustomize newName | Full registry path | e.g., `${REGISTRY}/blocksecops/intelligence-engine` |

### For ML Services (intelligence-engine)

| Requirement | Setting |
|-------------|---------|
| Memory limit | `2Gi` minimum |
| HF_HOME | `/app/models` |
| TRANSFORMERS_CACHE | `/app/models` |
| SENTENCE_TRANSFORMERS_HOME | `/app/models` |

---

## When to Rebuild Base Images

### Rebuild Required

1. Adding or removing packages from base requirements
2. Updating version constraints for base packages
3. Security patches require dependency updates
4. Tool version upgrades (Slither, Foundry, etc.)
5. Quarterly maintenance cycle

### Rebuild NOT Required

- Application code changes
- App-specific dependency changes (in `requirements/base.txt`)
- Configuration changes
- Environment variable changes

---

## Verification Checklist

Before pushing a base image to Harbor:

- [ ] All binary downloads have SHA256 checksum verification
- [ ] Base image pinned by digest (not just tag)
- [ ] All pip packages pinned to exact versions
- [ ] Git clones pinned to specific commits
- [ ] App user has `/sbin/nologin` shell
- [ ] Sensitive directories use `chmod 700`
- [ ] `pip check` passes (no dependency conflicts)
- [ ] All tools verified with `--version`
- [ ] Image scanned for vulnerabilities (optional: `trivy image`)

---

## Services NOT Using Base Images

The following services do not benefit from base images and should continue using standard multi-stage builds:

| Service | Image Size | Reason |
|---------|------------|--------|
| `blocksecops-api-service` | ~934 MB | Lightweight FastAPI dependencies, builds fast |
| `blocksecops-notification` | ~200 MB | Lightweight dependencies |
| `blocksecops-contract-parser` | ~200 MB | Rust with cargo dependency caching |
| `blocksecops-shared` | ~100 MB | Already optimized multi-stage build |
| Node.js frontends | ~300 MB | npm ci with cache mounts is efficient |

> **Note (January 26, 2026):** The api-service was reduced from 12.6GB to 934MB by moving ML dependencies (sentence-transformers, PyTorch) to intelligence-engine. See [ML-DEPENDENCY-SPLIT-2026-01-26](/home/pwner/Git/docs/changelogs/ML-DEPENDENCY-SPLIT-2026-01-26.md).

---

## Troubleshooting

| Problem | Symptom | Fix |
|---------|---------|-----|
| Tool not found | pipx tool missing | Check `which semgrep` shows `/opt/pipx/bin/semgrep` |
| Base image not found | Build fails | `docker pull harbor.blocksecops.local/blocksecops/<base-image>:latest` |
| ErrImageNeverPull | Pod stuck | Change `imagePullPolicy` to `IfNotPresent`, verify image in Harbor |
| Read-only filesystem | ML model cache error | Set `HF_HOME`, `TRANSFORMERS_CACHE`, `SENTENCE_TRANSFORMERS_HOME` to `/app/models` |
| Selector immutable | Deployment fails | Add `includeSelectors: false` to kustomization labels |
| OOM Killed (exit 137) | Pod restarts | Increase memory limit to `2Gi` for ML services |
| Disk space | Local disk full | `docker image prune -f` (Harbor images preserved) |

---

## Related Standards

- [Docker Image Versioning](./docker-image-versioning.md) - Semantic versioning for images
- [Container Images](../blocksecops-gcp-infrastructure/docs/standards/container-images.md) - Registry configuration
- [Build Workflow](./build-workflow.md) - Local build processes
- [Dependency Management](./dependency-management.md) - Dependency policies
