# Scanner Image Version Bump Workflow

**Version:** 1.0.0
**Last Updated:** March 4, 2026
**Status:** Active

## Overview

This workflow documents the complete process for bumping scanner image versions. Scanner images follow a dual-version model (upstream tool version + Apogee image version) with ConfigMap as the single source of truth.

```
┌──────────────────────────────────────────────────────────────┐
│            SCANNER IMAGE VERSION BUMP WORKFLOW                │
│                                                               │
│  Update Source of Truth (ConfigMap)                           │
│        │                                                      │
│        ▼                                                      │
│  Update Dockerfile Defaults                                   │
│        │                                                      │
│        ▼                                                      │
│  Update KJM Fallback Defaults                                 │
│        │                                                      │
│        ▼                                                      │
│  Build Scanner Image with All ARGs                            │
│        │                                                      │
│        ▼                                                      │
│  Push to Harbor (Immutable Tag)                               │
│        │                                                      │
│        ▼                                                      │
│  Apply ConfigMap Update                                       │
│        │                                                      │
│        ▼                                                      │
│  Rebuild + Deploy Tool-Integration Service                    │
│        │                                                      │
│        ▼                                                      │
│  Verify Scanner Jobs Use New Image                            │
│        │                                                      │
│        ▼                                                      │
│  Version bump complete                                        │
│                                                               │
└──────────────────────────────────────────────────────────────┘
```

---

## Key Concepts

### Dual Versioning

Each scanner has two independent version numbers:

| Version | Example | Purpose | Managed In |
|---------|---------|---------|-----------|
| **Tool Version** | `0.11.5` | Upstream scanner release | `ConfigMap.SCANNER_METADATA.<scanner>.version` |
| **Image Version** | `0.3.2` | Apogee wrapper + base image version | `ConfigMap.SCANNER_IMAGE_*` tags |

**Example:** Slither may have tool version `0.11.5` but image version `0.3.2`:
- `0.11.5` = upstream slither release
- `0.3.2` = how many times we've updated our Docker wrapper/base image

### Single Source of Truth

**ConfigMap `scanner-versions`** is the only authoritative source:

```
k8s/base/scanner-versions-configmap.yaml
    │
    ├─ SCANNER_METADATA (tool version, metadata)
    │
    └─ SCANNER_IMAGE_* (image version, registry URL)
        │
        ├─ Dockerfile ARG defaults (must match)
        │
        └─ KJM default_images dict (must match)
```

Any version mismatch between these three locations will cause problems.

### Immutable Tags

All image tags in Harbor are immutable. **You cannot overwrite a tag.** Every version change requires a new, unique tag.

---

## Workflow Steps

### Step 1: Identify What Changed

Determine what triggered the version bump:

| Scenario | Tool Version | Image Version | Both |
|----------|--------------|---------------|------|
| Upstream scanner release (e.g., slither 0.11.5 → 0.11.6) | **BUMP** | **BUMP MINOR** | Yes |
| Wrapper script fix (error handling, logging) | — | **BUMP PATCH** | No |
| Base image security patch | — | **BUMP PATCH** | No |
| Dockerfile refactor (same functionality) | — | **BUMP PATCH** | No |
| Breaking wrapper changes | — | **BUMP MAJOR** | No |

**Example:**
```
Old:   Tool=0.11.3, Image=0.2.5
New:   Tool=0.11.5, Image=0.3.0  ← Both bumped (tool + image minor)

vs.

Old:   Tool=0.11.5, Image=0.3.0
New:   Tool=0.11.5, Image=0.3.1  ← Only image patch (wrapper fix)
```

### Step 2: Update ConfigMap Source of Truth

**File:** `blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml`

Update both the tool version and image version:

```yaml
data:
  SCANNER_METADATA: |
    {
      "slither": {
        "version": "0.11.5",
        "developer": "Crytic/Trail of Bits",
        "_note": "Updated 2026-03-04 from 0.11.3, fixes reentrancy detection, scanner wrapper 0.3.0"
      }
    }
  SCANNER_IMAGE_SLITHER: "harbor.blocksecops.local/blocksecops/scanner-slither:0.3.0"
```

**What to include in `_note`:**
- Today's date
- Upstream version change summary (if bumping tool version)
- Scanner wrapper version number
- Key changes or bug fixes

### Step 3: Update Dockerfile ARG Defaults

**File:** `blocksecops-tool-integration/scanner-images/slither/Dockerfile`

Update the ARG defaults to match ConfigMap values:

```dockerfile
# Must match ConfigMap SCANNER_IMAGE_SLITHER tag
ARG SCANNER_IMAGE_VERSION=0.3.0

# Must match ConfigMap SCANNER_METADATA.slither.version
ARG UPSTREAM_TOOL_VERSION=0.11.5

ARG BUILD_DATE
ARG VCS_REF

FROM python:3.11-slim

# Clone upstream at specific version
RUN git clone --branch v${UPSTREAM_TOOL_VERSION} --depth 1 \
  https://github.com/crytic/slither.git .
```

**Critical:** Both ARGs must exactly match the ConfigMap values.

### Step 4: Update KJM Fallback Defaults

**File:** `blocksecops-tool-integration/src/scanners/kubernetes_job_manager.py`

Update the `default_images` dict. This is a fallback when ConfigMap is unavailable:

```python
default_images = {
    "slither": "harbor.blocksecops.local/blocksecops/scanner-slither:0.3.0",
    "mythril": "harbor.blocksecops.local/blocksecops/scanner-mythril:0.4.1",
    # ... more scanners
}
```

Must exactly match `ConfigMap.SCANNER_IMAGE_*` values.

### Step 5: Build Scanner Image with All ARGs

**Command Pattern:**

```bash
cd /home/pwner/Git/blocksecops-tool-integration

docker build \
  --build-arg SCANNER_IMAGE_VERSION=0.3.0 \
  --build-arg UPSTREAM_TOOL_VERSION=0.11.5 \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t harbor.blocksecops.local/blocksecops/scanner-slither:0.3.0 \
  scanner-images/slither/
```

**Key points:**
- All four ARGs are **required** for proper OCI labels
- `BUILD_DATE` must use ISO 8601 format with Z suffix
- `VCS_REF` is the short Git commit hash
- Tag must match `SCANNER_IMAGE_*` ConfigMap key exactly
- Do NOT use `latest` tag (Harbor enforces immutable tags)
- Build can take 5-30 minutes depending on scanner

**Verify OCI labels:**

```bash
docker inspect --format='{{json .Config.Labels}}' \
  harbor.blocksecops.local/blocksecops/scanner-slither:0.3.0 | jq
```

Expected output includes:
```json
{
  "org.opencontainers.image.version": "0.3.0",
  "scanner.tool.version": "0.11.5",
  "org.opencontainers.image.created": "2026-03-04T...",
  "org.opencontainers.image.revision": "abc1234"
}
```

### Step 6: Push to Harbor

```bash
docker push harbor.blocksecops.local/blocksecops/scanner-slither:0.3.0
```

**Verify push succeeded:**

```bash
curl -s https://harbor.blocksecops.local/api/v2.0/projects/blocksecops/repositories/scanner-slither/artifacts \
  --insecure | jq '.[0].tags[].name'

# Should output: ["0.3.0"]
```

**If push fails with "tag already exists":**
- The tag is immutable in Harbor
- You must use a different tag
- Increment the image version and rebuild

### Step 7: Apply ConfigMap Update

Apply the ConfigMap changes to the cluster:

```bash
kubectl apply -k /home/pwner/Git/blocksecops-tool-integration/k8s/overlays/local/
```

**Verify ConfigMap updated:**

```bash
kubectl get configmap scanner-versions -n tool-integration-local \
  -o jsonpath='{.data.SCANNER_IMAGE_SLITHER}'

# Should output: harbor.blocksecops.local/blocksecops/scanner-slither:0.3.0
```

### Step 8: Rebuild and Deploy Tool-Integration Service

The tool-integration service reads from ConfigMap and also has the `default_images` dict. Rebuild to update the KJM fallback:

```bash
cd /home/pwner/Git/blocksecops-tool-integration

# Extract version
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)

# Rebuild tool-integration with updated KJM defaults
docker build \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t harbor.blocksecops.local/blocksecops/tool-integration:${VERSION} .

docker push harbor.blocksecops.local/blocksecops/tool-integration:${VERSION}

# Deploy
kubectl apply -k k8s/overlays/local/

# Wait for rollout
kubectl rollout status deployment/tool-integration -n tool-integration-local --timeout=120s
```

**Alternative:** Use `deploy.sh` if available:

```bash
./scripts/deploy.sh
```

### Step 9: Verify Scanner Jobs Use New Image

After tool-integration pod restarts, verify the new image is being used:

```bash
# Check tool-integration logs for scanner registration
kubectl logs -n tool-integration-local deployment/tool-integration --tail=50 | grep -i "slither"

# Should show: "slither: 0.3.0" or "scanner-slither:0.3.0"
```

Create a test scan job to verify the new image:

```bash
# Trigger a scan with the updated scanner
curl -X POST "http://127.0.0.1:8000/api/v1/scans" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <TOKEN>" \
  -d '{"contract_id": "<CONTRACT_ID>", "scanner_ids": ["slither"]}'

# Check the scanner job Pod
kubectl get pods -n tool-integration-local | grep slither

# Check the job container image
kubectl describe pod -n tool-integration-local <POD_NAME> | grep "Image:"

# Should show: Image: harbor.blocksecops.local/blocksecops/scanner-slither:0.3.0
```

### Step 10: Commit All Changes

Commit ConfigMap, Dockerfile, KJM defaults, and tool-integration rebuild together:

```bash
git add \
  blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml \
  blocksecops-tool-integration/scanner-images/slither/Dockerfile \
  blocksecops-tool-integration/src/scanners/kubernetes_job_manager.py \
  blocksecops-tool-integration/pyproject.toml \
  blocksecops-tool-integration/k8s/overlays/local/kustomization.yaml

git commit -m "chore(tool-integration): bump slither from 0.11.3 to 0.11.5, image 0.2.5 → 0.3.0

- Update ConfigMap SCANNER_METADATA with new tool version
- Update ConfigMap SCANNER_IMAGE_SLITHER to 0.3.0
- Update Dockerfile ARG defaults to match ConfigMap
- Update KJM default_images fallback
- Rebuild tool-integration service with updated KJM

Tool-Integration: 0.28.44
Scanner Wrapper: 0.3.0"
```

---

## Multi-Scanner Batch Upgrade

When upgrading multiple scanners at once (e.g., routine version bumps):

```bash
# 1. Update ConfigMap with ALL scanner versions
vim blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml
# Update SCANNER_METADATA and SCANNER_IMAGE_* for each scanner

# 2. Build and push all scanner images
for scanner in slither mythril aderyn wake; do
  docker build \
    --build-arg SCANNER_IMAGE_VERSION=<NEW_VERSION> \
    --build-arg UPSTREAM_TOOL_VERSION=<NEW_TOOL_VERSION> \
    --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg VCS_REF=$(git rev-parse --short HEAD) \
    -t harbor.blocksecops.local/blocksecops/scanner-$scanner:<NEW_VERSION> \
    scanner-images/$scanner/

  docker push harbor.blocksecops.local/blocksecops/scanner-$scanner:<NEW_VERSION>
done

# 3. Update KJM defaults and rebuild tool-integration
vim src/scanners/kubernetes_job_manager.py
# Update all scanner entries in default_images

# 4. Deploy everything
./scripts/deploy.sh

# 5. Verify all scanners
curl -s http://127.0.0.1:8000/api/v1/scanners/health | jq
```

---

## Verification Checklist

After completing the version bump:

- [ ] ConfigMap SCANNER_METADATA updated with new tool version
- [ ] ConfigMap SCANNER_METADATA _note field updated with date and changes
- [ ] ConfigMap SCANNER_IMAGE_* tag updated
- [ ] Dockerfile ARG SCANNER_IMAGE_VERSION matches ConfigMap tag
- [ ] Dockerfile ARG UPSTREAM_TOOL_VERSION matches ConfigMap metadata
- [ ] Scanner image built with all ARGs (BUILD_DATE, VCS_REF, etc.)
- [ ] Scanner image pushed to Harbor successfully
- [ ] Image tag is immutable in Harbor (cannot be overwritten)
- [ ] KJM default_images dict updated to match ConfigMap
- [ ] Tool-integration rebuilt and deployed
- [ ] tool-integration pod healthy (1/1 Ready)
- [ ] Tool-integration logs show scanner registered with new version
- [ ] Test scan job uses new scanner image
- [ ] Solc pre-installed (solc-select + .svm for Foundry scanners)
- [ ] forge-std pre-installed (Foundry-based scanners only)
- [ ] No external downloads at runtime (verify with `offline = true`)
- [ ] All changes committed to Git
- [ ] OCI labels verified on image

---

## Troubleshooting

### Harbor Push Fails with "Tag Already Exists"

**Problem:** `docker push` fails with error about immutable tag

**Solution:** Tag is immutable in Harbor. You must increment the version and rebuild:

```bash
# Wrong version (already in use)
OLD: harbor.blocksecops.local/blocksecops/scanner-slither:0.3.0

# Correct: increment version
NEW: harbor.blocksecops.local/blocksecops/scanner-slither:0.3.1

# Update ConfigMap, Dockerfile, rebuild, push new tag
```

### ConfigMap and Dockerfile Versions Don't Match

**Problem:** Scanner job fails because ConfigMap and Dockerfile defaults differ

**Solution:** Ensure all three are synchronized:

```bash
# 1. Check ConfigMap
kubectl get configmap scanner-versions -n tool-integration-local -o yaml | grep SCANNER_IMAGE_SLITHER

# 2. Check Dockerfile
grep "ARG SCANNER_IMAGE_VERSION" scanner-images/slither/Dockerfile

# 3. Check KJM defaults
grep -A 20 "default_images = {" src/scanners/kubernetes_job_manager.py

# All three MUST show the same version tag
```

### OCI Labels Missing from Image

**Problem:** `docker inspect` doesn't show OCI labels

**Solution:** Build with explicit `--build-arg` (defaults alone aren't enough):

```bash
# WRONG: ARGs not passed to build command
docker build -t scanner-slither:0.3.0 scanner-images/slither/

# CORRECT: Pass all ARGs explicitly
docker build \
  --build-arg SCANNER_IMAGE_VERSION=0.3.0 \
  --build-arg UPSTREAM_TOOL_VERSION=0.11.5 \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t harbor.blocksecops.local/blocksecops/scanner-slither:0.3.0 \
  scanner-images/slither/
```

### Tool-Integration Pod Doesn't Pick Up ConfigMap

**Problem:** Pod still using old scanner version after ConfigMap update

**Solution:** Pod caches ConfigMap. Force restart:

```bash
kubectl rollout restart deployment/tool-integration -n tool-integration-local
kubectl rollout status deployment/tool-integration -n tool-integration-local
```

### Scanner Job Fails with Image Pull Error

**Problem:** Scanner job pod shows "ImagePullBackOff"

**Solution:**
1. Verify image exists in Harbor
2. Verify Harbor credentials in cluster

```bash
# Test pull locally
docker pull harbor.blocksecops.local/blocksecops/scanner-slither:0.3.0

# Check pod image pull error
kubectl describe pod -n tool-integration-local <POD_NAME> | grep -A 5 "Events:"

# Verify imagePullSecret in pod spec
kubectl get pod -n tool-integration-local <POD_NAME> -o yaml | grep imagePullSecret
```

---

## Related Documentation

- [Docker Image Versioning Standards](../standards/docker-image-versioning.md) - General Docker versioning rules + scanner section
- [Scanner Image Build Pipeline](../pipelines/scanner-image-build-pipeline.md) - Build pipeline architecture
- [Scanner Image Rebuild Playbook](../playbooks/scanner-image-rebuild-all.md) - Complete guide to rebuilding all 16 scanners
- [Upgrade Scanner Image Playbook](../playbooks/upgrade-scanner-image.md) - Individual scanner upgrade with pipeline integration
- [Scanner Upgrade Workflow](./scanner-upgrade-workflow.md) - Full scanner metadata + pattern seeding workflow
