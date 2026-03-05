# Scanner Image Build Pipeline

**Version:** 1.0.0
**Last Updated:** March 4, 2026
**Status:** Active

## Overview

This document describes the build pipeline for scanner images in the Apogee platform. Unlike service images (which are built per commit via CI/CD), scanner images are built on-demand when scanner versions are updated.

```
                    SCANNER IMAGE BUILD PIPELINE

Developer Update         ConfigMap Update        Build         Verification
    │                         │                  │                   │
    ▼                         ▼                  ▼                   ▼
Update Dockerfile      Update ConfigMap     Docker Build       Push to Harbor
    +                      +               with all ARGs             +
Update Tool Version    Update Image Tag     OCI Labels               │
    +                      +               BUILD_DATE, VCS_REF       │
Update Image Version   Update KJM dict          │                   ▼
    │                      │                   ▼              Apply ConfigMap
    └──────┬───────────────┘         Build succeeds?         Restart tool-int
           │                             ✅ Yes
           │                              │
           └──────────────────────────────┼──────────────────────────┘
                                         ▼
                                 docker push to Harbor
                                   (immutable tag)
                                          │
                                          ▼
                              Verify image in registry
                                          │
                                          ▼
                                Apply ConfigMap + deploy
                                tool-integration service
```

---

## Build Steps

### 1. Update Source Files

Make changes to trigger the build:

| File | Change | Why |
|------|--------|-----|
| `Dockerfile` | Update UPSTREAM_TOOL_VERSION or wrapper code | New tool version or wrapper fix |
| `ConfigMap` | Update SCANNER_METADATA version | Single source of truth |
| `ConfigMap` | Update SCANNER_IMAGE_* tag | Track image version |
| `KJM defaults` | Update default_images dict | Fallback image when ConfigMap unavailable |

**Example: Slither 0.11.3 → 0.11.5 upgrade**

```dockerfile
# scanner-images/slither/Dockerfile
ARG SCANNER_IMAGE_VERSION=0.3.0  # ← bump from 0.2.5
ARG UPSTREAM_TOOL_VERSION=0.11.5 # ← update from 0.11.3

RUN git clone --branch v${UPSTREAM_TOOL_VERSION} --depth 1 \
  https://github.com/crytic/slither.git .
```

```yaml
# k8s/base/scanner-versions-configmap.yaml
SCANNER_METADATA: |
  {
    "slither": {
      "version": "0.11.5",  # ← update from 0.11.3
      "developer": "Crytic/Trail of Bits",
      "_note": "Updated 2026-03-04, scanner image 0.3.0"
    }
  }
SCANNER_IMAGE_SLITHER: "harbor.blocksecops.local/blocksecops/scanner-slither:0.3.0"
```

```python
# src/scanners/kubernetes_job_manager.py
default_images = {
    "slither": "harbor.blocksecops.local/blocksecops/scanner-slither:0.3.0",  # ← update
    # ...
}
```

### 2. Build with OCI Labels

Build the Docker image with all required ARGs:

```bash
cd /home/pwner/Git/blocksecops-tool-integration/scanner-images/slither

SCANNER_IMAGE_VERSION=0.3.0
UPSTREAM_TOOL_VERSION=0.11.5

docker build \
  --build-arg SCANNER_IMAGE_VERSION=$SCANNER_IMAGE_VERSION \
  --build-arg UPSTREAM_TOOL_VERSION=$UPSTREAM_TOOL_VERSION \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t harbor.blocksecops.local/blocksecops/scanner-slither:$SCANNER_IMAGE_VERSION \
  .
```

**OCI labels embedded in image:**

```dockerfile
LABEL org.opencontainers.image.version="${SCANNER_IMAGE_VERSION}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL scanner.tool.version="${UPSTREAM_TOOL_VERSION}"
```

**Verify labels:**

```bash
docker inspect --format='{{json .Config.Labels}}' \
  harbor.blocksecops.local/blocksecops/scanner-slither:0.3.0 | jq '.["org.opencontainers.image.version"]'

# Output: "0.3.0"
```

### 3. Push to Harbor Registry

Push the immutable image to Harbor:

```bash
docker push harbor.blocksecops.local/blocksecops/scanner-slither:0.3.0
```

**Verify push:**

```bash
curl -s https://harbor.blocksecops.local/api/v2.0/projects/blocksecops/repositories/scanner-slither/artifacts \
  --insecure | jq '.[0]' | head -20

# Should show:
# {
#   "id": 12345,
#   "project_id": 3,
#   "repository_name": "scanner-slither",
#   "artifact_type": "image",
#   "media_type": "application/vnd.docker.distribution.manifest.v2+json",
#   "tags": [
#     {
#       "name": "0.3.0",
#       "push_time": "2026-03-04T...",
#       ...
#     }
#   ]
# }
```

**Tag is now immutable** — cannot be overwritten or deleted.

### 4. Apply ConfigMap and Restart Tool-Integration

After successful push, apply the updated ConfigMap:

```bash
kubectl apply -k /home/pwner/Git/blocksecops-tool-integration/k8s/overlays/local/
```

Restart tool-integration to pick up the new ConfigMap and rebuilt image:

```bash
cd /home/pwner/Git/blocksecops-tool-integration

# Extract version
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)

# Rebuild tool-integration with updated KJM defaults
docker build \
  --build-arg SERVICE_VERSION=$VERSION \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t harbor.blocksecops.local/blocksecops/tool-integration:$VERSION .

docker push harbor.blocksecops.local/blocksecops/tool-integration:$VERSION

# Deploy
kubectl apply -k k8s/overlays/local/

# Wait for rollout
kubectl rollout status deployment/tool-integration -n tool-integration-local --timeout=120s
```

### 5. Verify New Image in Cluster

After tool-integration restarts, verify the scanner job uses the new image:

```bash
# Check tool-integration logs
kubectl logs -n tool-integration-local deployment/tool-integration --tail=50 | grep slither

# Create test scan job
curl -X POST "http://127.0.0.1:8000/api/v1/scans" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <TOKEN>" \
  -d '{"contract_id": "<ID>", "scanner_ids": ["slither"]}'

# Verify job pod uses new image
kubectl get pods -n tool-integration-local | grep slither
kubectl describe pod -n tool-integration-local <POD_NAME> | grep "Image:"

# Should show: Image: harbor.blocksecops.local/blocksecops/scanner-slither:0.3.0
```

---

## Multi-Scanner Batch Build

When rebuilding multiple scanners at once:

```bash
#!/bin/bash
# Batch build all scanners

SCANNERS=(slither mythril aderyn wake semgrep solc-select soliditydefend rustdefend)

for scanner in "${SCANNERS[@]}"; do
  echo "Building scanner-$scanner..."

  # Extract versions from ConfigMap (requires kubectl)
  # For simplicity, define them here or read from configmap
  IMAGE_VERSION="0.3.0"  # Update for each batch

  docker build \
    --build-arg SCANNER_IMAGE_VERSION=$IMAGE_VERSION \
    --build-arg UPSTREAM_TOOL_VERSION=$(grep "\"version\"" \
      k8s/base/scanner-versions-configmap.yaml | head -1 | cut -d'"' -f4) \
    --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg VCS_REF=$(git rev-parse --short HEAD) \
    -t harbor.blocksecops.local/blocksecops/scanner-$scanner:$IMAGE_VERSION \
    scanner-images/$scanner/

  if [ $? -eq 0 ]; then
    echo "✅ Built scanner-$scanner:$IMAGE_VERSION"
    docker push harbor.blocksecops.local/blocksecops/scanner-$scanner:$IMAGE_VERSION
  else
    echo "❌ Failed to build scanner-$scanner"
    exit 1
  fi
done

echo "All scanners built successfully"
```

---

## Build Configuration Files

### ConfigMap (Source of Truth)

**File:** `blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: scanner-versions
  namespace: tool-integration-local
data:
  SCANNER_METADATA: |
    {
      "slither": {
        "version": "0.11.5",
        "developer": "Crytic/Trail of Bits",
        "_note": "Updated 2026-03-04, scanner image 0.3.0"
      },
      "mythril": {
        "version": "0.23.0",
        "developer": "ConsenSys",
        "_note": "Updated 2026-02-28, scanner image 0.4.1"
      }
    }
  SCANNER_IMAGE_SLITHER: "harbor.blocksecops.local/blocksecops/scanner-slither:0.3.0"
  SCANNER_IMAGE_MYTHRIL: "harbor.blocksecops.local/blocksecops/scanner-mythril:0.4.1"
  # ... more scanners
```

**Key points:**
- SCANNER_METADATA contains tool versions and metadata
- SCANNER_IMAGE_* contains registry image tags
- Both must be updated together during version bumps
- This ConfigMap is mounted as a volume in tool-integration pod
- tool-integration reads ConfigMap at startup and when querying scanner health

### Dockerfile (ARG Defaults)

**File:** `blocksecops-tool-integration/scanner-images/slither/Dockerfile`

```dockerfile
ARG SCANNER_IMAGE_VERSION=0.3.0
ARG UPSTREAM_TOOL_VERSION=0.11.5
ARG BUILD_DATE
ARG VCS_REF

FROM python:3.11-slim

LABEL org.opencontainers.image.title="Apogee Slither Scanner"
LABEL org.opencontainers.image.description="Slither security analysis wrapper for Kubernetes"
LABEL org.opencontainers.image.version="${SCANNER_IMAGE_VERSION}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.vendor="Apogee"
LABEL scanner.tool.version="${UPSTREAM_TOOL_VERSION}"

# Clone upstream scanner
RUN git clone --branch v${UPSTREAM_TOOL_VERSION} --depth 1 \
  https://github.com/crytic/slither.git .

# Wrapper script
COPY --chown=scanner:scanner wrapper.sh /app/wrapper.sh
RUN chmod +x /app/wrapper.sh

ENTRYPOINT ["/app/wrapper.sh"]
```

**Key points:**
- ARG defaults must match ConfigMap values
- BUILD_DATE and VCS_REF are passed at build time
- OCI labels record both image version and tool version
- Entrypoint is typically a wrapper script that runs the upstream tool

### KJM Fallback (Kubernetes Job Manager)

**File:** `blocksecops-tool-integration/src/scanners/kubernetes_job_manager.py`

```python
# Fallback image versions when ConfigMap is unavailable
default_images = {
    "slither": "harbor.blocksecops.local/blocksecops/scanner-slither:0.3.0",
    "mythril": "harbor.blocksecops.local/blocksecops/scanner-mythril:0.4.1",
    "aderyn": "harbor.blocksecops.local/blocksecops/scanner-aderyn:0.2.1",
    "wake": "harbor.blocksecops.local/blocksecops/scanner-wake:0.1.0",
    # ... more scanners
}
```

**Key points:**
- This dict is a fallback for when ConfigMap is not mounted or unavailable
- Must be kept in sync with `ConfigMap.SCANNER_IMAGE_*` values
- Used in Kubernetes Job Pod spec:
  ```python
  container_image = default_images.get(scanner_id)
  ```
- Tool-integration rebuild is needed when these values change

---

## Build Environment Variables

### Build Time (docker build)

| Variable | Value | Purpose |
|----------|-------|---------|
| `SCANNER_IMAGE_VERSION` | `0.3.0` | Our wrapper image version |
| `UPSTREAM_TOOL_VERSION` | `0.11.5` | Third-party tool version |
| `BUILD_DATE` | `2026-03-04T10:30:00Z` | ISO 8601 timestamp (UTC with Z) |
| `VCS_REF` | `abc1234` | Git commit short hash |

### Runtime (Pod Environment)

| Variable | Source | Purpose |
|----------|--------|---------|
| `SCANNER_ID` | Tool-Integration service | Which scanner to run |
| `CALLBACK_URL` | Tool-Integration service | Where to POST results |
| `TIMEOUT` | Tool-Integration service | Job execution timeout |
| `ADDITIONAL_ARGS` | Tool-Integration service | Tool-specific arguments |

---

## Harbor Registry Setup

### Project Settings

Scanner images are stored in the `blocksecops` project with immutable tag enforcement:

```bash
# Verify project settings
curl -s https://harbor.blocksecops.local/api/v2.0/projects/blocksecops \
  --insecure | jq '.project_name, .public'

# Should show:
# "blocksecops"
# false (private project)
```

### Immutable Tag Rule

Harbor enforces immutable tags at the project level. **All tags are immutable — cannot be overwritten or deleted.**

```bash
# Verify immutable tag rule
curl -s https://harbor.blocksecops.local/api/v2.0/projects/blocksecops/immutabletagrules \
  --insecure | jq '.[0]'

# Should show:
# {
#   "id": 1,
#   "project_id": 3,
#   "tag_pattern": "**",
#   "enabled": true
# }
```

**Implication:** Every build must use a unique, new tag. Rebuilding the same tag will fail.

### Image Retention Policy

By default, all versions are retained. To clean up old images:

```bash
# List all tags
curl -s https://harbor.blocksecops.local/api/v2.0/projects/blocksecops/repositories/scanner-slither/artifacts \
  --insecure | jq '.[].tags[].name'

# Delete old tag (if retention policy allows)
curl -X DELETE https://harbor.blocksecops.local/api/v2.0/projects/blocksecops/repositories/scanner-slither/artifacts/<digest> \
  --insecure
```

---

## Build Performance

### Typical Build Times

| Scanner | Language | Time | Notes |
|---------|----------|------|-------|
| slither | Python | 5-10 min | Most common, stable |
| mythril | Python | 5-10 min | Medium size |
| aderyn | Rust | 15-30 min | Large, compilation heavy |
| wake | Python | 5-10 min | Medium size |
| soliditydefend | Rust | 15-30 min | Large, many dependencies |

**With BuildKit cache:** 2-3 minutes for code-only changes
**Without cache:** Full build time as listed above

### Optimization

Use Docker BuildKit for faster builds:

```bash
# Enable BuildKit (usually enabled by default)
export DOCKER_BUILDKIT=1

docker build \
  --build-arg SCANNER_IMAGE_VERSION=0.3.0 \
  --build-arg UPSTREAM_TOOL_VERSION=0.11.5 \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t harbor.blocksecops.local/blocksecops/scanner-slither:0.3.0 \
  scanner-images/slither/
```

### Troubleshooting Build Failures

**Problem: "failed to compute cache key"**
- Dockerfile syntax error
- Missing base image
- Solution: Check Dockerfile and build command

**Problem: "network timeout"**
- Internet connectivity issue
- Git clone timeout
- Solution: Check network, retry with timeout increase

**Problem: "no space left on device"**
- Docker disk full
- Solution: `docker system prune`, allocate more space

**Problem: "OCI labels missing"**
- ARGs not passed to build command
- Solution: Use explicit `--build-arg` flags, don't rely on defaults

---

## Checklist

- [ ] Source files updated (Dockerfile, ConfigMap, KJM defaults)
- [ ] SCANNER_IMAGE_VERSION bumped
- [ ] UPSTREAM_TOOL_VERSION updated (if tool upgrade)
- [ ] ConfigMap SCANNER_METADATA._note field updated
- [ ] Dockerfile ARG defaults match ConfigMap values
- [ ] Docker build succeeds with all ARGs
- [ ] OCI labels present and correct in image
- [ ] Image pushed to Harbor successfully
- [ ] Image tag is immutable (cannot be overwritten)
- [ ] ConfigMap applied to cluster
- [ ] Tool-integration rebuilt and deployed
- [ ] Tool-integration pod healthy
- [ ] Test scanner job uses new image
- [ ] Scanner produces expected output
- [ ] All changes committed to Git

---

## Related Documentation

- [Docker Image Versioning Standards](../standards/docker-image-versioning.md) - General Docker versioning + scanner section
- [Scanner Image Version Bump Workflow](../workflows/scanner-image-version-bump.md) - Step-by-step version bump procedure
- [Scanner Image Rebuild Playbook](../playbooks/scanner-image-rebuild-all.md) - Complete guide for rebuilding all scanners
- [Upgrade Scanner Image Playbook](../playbooks/upgrade-scanner-image.md) - Individual scanner upgrade
- [Tool Metadata ConfigMaps Standard](../standards/tool-metadata-configmaps.md) - ConfigMap management standards
