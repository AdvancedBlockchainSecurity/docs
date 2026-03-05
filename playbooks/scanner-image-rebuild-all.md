# Playbook: Rebuild All Scanner Images

**Version:** 1.0.0
**Last Updated:** March 4, 2026
**Status:** Active

## Overview

This playbook documents the complete procedure for rebuilding all 16 scanner images in the Apogee platform. This is typically done when:

1. **OCI label compliance** - Ensuring all images have proper labels for audit
2. **Base image updates** - Rebuilding with latest Python, Rust, or system packages
3. **Wrapper script improvements** - Updating error handling, logging, or output format across all scanners
4. **Security patches** - Rebuilding all images with patched dependencies
5. **Routine maintenance** - Periodic full rebuild cycle

This is the process completed on **March 4, 2026** to ensure all 16 scanners had proper OCI labels (SCANNER_IMAGE_VERSION, UPSTREAM_TOOL_VERSION, BUILD_DATE, VCS_REF).

---

## Scanners to Rebuild

| # | Scanner | Language | Build Time | Current Version | Notes |
|---|---------|----------|------------|-----------------|-------|
| 1 | slither | Python | 5-10 min | 0.11.5 | Most stable |
| 2 | mythril | Python | 5-10 min | 0.23.0 | Medium complexity |
| 3 | aderyn | Rust | 15-30 min | 0.2.0 | Heavy compilation |
| 4 | wake | Python | 5-10 min | 4.5.0 | Wakko fork |
| 5 | semgrep | Python | 5-10 min | 1.45.2 | SAST scanning |
| 6 | solc-select | Python | 2-3 min | 1.0.4 | Lightweight |
| 7 | soliditydefend | Rust | 15-30 min | 0.1.8 | In-house tool |
| 8 | rustdefend | Rust | 15-30 min | 0.1.0 | In-house tool |
| 9-16 | (others) | Various | Varies | Various | Additional scanners |

**Total estimated time:** 2-3 hours (sequential) or 45-60 min (with parallelization)

---

## Prerequisites

- [ ] Docker running locally
- [ ] kubectl configured for local cluster
- [ ] Harbor registry accessible (`harbor.blocksecops.local`)
- [ ] ~100GB free disk space (for all images)
- [ ] Network stability (large builds can fail on unstable connections)
- [ ] Git repo updated: `git pull origin main`

---

## Pre-Rebuild Preparation

### Step 1: Create Database Backup

If this rebuild is part of a version bump workflow:

```bash
# Port forward PostgreSQL
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 &
sleep 3

# Backup database
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PGPASSWORD=postgres pg_dump \
  -h 127.0.0.1 \
  -p 5432 \
  -U postgres \
  -d solidity_security \
  -F c \
  -f ~/backups/solidity_security_rebuild_${TIMESTAMP}.dump

echo "Backup created: ~/backups/solidity_security_rebuild_${TIMESTAMP}.dump"
```

### Step 2: Document Current State

Record the current scanner image versions before rebuild:

```bash
# List all scanner images currently in use
for scanner in slither mythril aderyn wake semgrep solc-select soliditydefend rustdefend; do
  echo "=== $scanner ==="
  grep "SCANNER_IMAGE_" k8s/base/scanner-versions-configmap.yaml | grep -i $scanner
done > /tmp/scanner-versions-before.txt

cat /tmp/scanner-versions-before.txt
```

### Step 3: Verify ConfigMap is Up-to-Date

Ensure ConfigMap has the correct upstream tool versions and metadata:

```bash
# Check ConfigMap
kubectl get configmap scanner-versions -n tool-integration-local -o yaml | head -50

# If ConfigMap needs updates, apply them now before rebuilding images
kubectl apply -k /home/pwner/Git/blocksecops-tool-integration/k8s/base/
```

---

## Build Procedure

### Sequential Build (Safe, Verifiable)

Build each scanner one at a time, verifying each before moving to the next:

```bash
#!/bin/bash
# sequential-build.sh

set -euo pipefail

cd /home/pwner/Git/blocksecops-tool-integration

# Configuration
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="/tmp/scanner-builds-${TIMESTAMP}"
mkdir -p "$LOG_DIR"

SCANNERS=(
  "slither:0.11.5:0.3.0"
  "mythril:0.23.0:0.4.1"
  "aderyn:0.2.0:0.2.1"
  "wake:4.5.0:0.1.2"
  "semgrep:1.45.2:0.2.0"
  "solc-select:1.0.4:0.1.5"
  "soliditydefend:0.1.8:0.1.3"
  "rustdefend:0.1.0:0.1.1"
)

echo "Building ${#SCANNERS[@]} scanner images..."
echo "Logs: $LOG_DIR"
echo ""

FAILED=()
SUCCEEDED=()

for entry in "${SCANNERS[@]}"; do
  IFS=':' read -r SCANNER TOOL_VERSION IMAGE_VERSION <<< "$entry"

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Building: scanner-$SCANNER"
  echo "Tool Version: $TOOL_VERSION"
  echo "Image Version: $IMAGE_VERSION"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  BUILD_LOG="$LOG_DIR/scanner-${SCANNER}-${IMAGE_VERSION}.log"

  if docker build \
    --build-arg SCANNER_IMAGE_VERSION=$IMAGE_VERSION \
    --build-arg UPSTREAM_TOOL_VERSION=$TOOL_VERSION \
    --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg VCS_REF=$(git rev-parse --short HEAD) \
    -t harbor.blocksecops.local/blocksecops/scanner-$SCANNER:$IMAGE_VERSION \
    scanner-images/$SCANNER/ | tee "$BUILD_LOG"; then

    echo "✅ Build succeeded: scanner-$SCANNER:$IMAGE_VERSION"
    SUCCEEDED+=("$SCANNER:$IMAGE_VERSION")

    # Verify OCI labels
    echo "Verifying OCI labels..."
    docker inspect --format='{{json .Config.Labels}}' \
      harbor.blocksecops.local/blocksecops/scanner-$SCANNER:$IMAGE_VERSION | jq . | head -10

  else
    echo "❌ Build FAILED: scanner-$SCANNER:$IMAGE_VERSION"
    FAILED+=("$SCANNER")
  fi

  echo ""
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "BUILD SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Succeeded: ${#SUCCEEDED[@]}"
for s in "${SUCCEEDED[@]}"; do echo "   $s"; done
echo ""
echo "❌ Failed: ${#FAILED[@]}"
for f in "${FAILED[@]}"; do echo "   $f"; done
echo ""

if [ ${#FAILED[@]} -gt 0 ]; then
  echo "Some builds failed. Logs: $LOG_DIR"
  exit 1
else
  echo "All builds succeeded! Next: push to Harbor"
fi
```

**Run the script:**

```bash
chmod +x sequential-build.sh
./sequential-build.sh
```

### Parallel Build (Faster, Requires More Resources)

For faster completion, build multiple scanners in parallel:

```bash
#!/bin/bash
# parallel-build.sh

set -euo pipefail

cd /home/pwner/Git/blocksecops-tool-integration

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="/tmp/scanner-builds-${TIMESTAMP}"
mkdir -p "$LOG_DIR"

SCANNERS=(
  "slither:0.11.5:0.3.0"
  "mythril:0.23.0:0.4.1"
  "aderyn:0.2.0:0.2.1"
  "wake:4.5.0:0.1.2"
  "semgrep:1.45.2:0.2.0"
  "solc-select:1.0.4:0.1.5"
  "soliditydefend:0.1.8:0.1.3"
  "rustdefend:0.1.0:0.1.1"
)

echo "Building ${#SCANNERS[@]} scanners in parallel..."
echo "Logs: $LOG_DIR"
echo ""

# Function to build a single scanner
build_scanner() {
  local entry="$1"
  IFS=':' read -r SCANNER TOOL_VERSION IMAGE_VERSION <<< "$entry"

  local BUILD_LOG="$LOG_DIR/scanner-${SCANNER}-${IMAGE_VERSION}.log"

  echo "Starting: scanner-$SCANNER:$IMAGE_VERSION" | tee -a "$BUILD_LOG"

  if docker build \
    --build-arg SCANNER_IMAGE_VERSION=$IMAGE_VERSION \
    --build-arg UPSTREAM_TOOL_VERSION=$TOOL_VERSION \
    --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg VCS_REF=$(git rev-parse --short HEAD) \
    -t harbor.blocksecops.local/blocksecops/scanner-$SCANNER:$IMAGE_VERSION \
    scanner-images/$SCANNER/ >> "$BUILD_LOG" 2>&1; then
    echo "✅ Done: scanner-$SCANNER:$IMAGE_VERSION"
    return 0
  else
    echo "❌ Failed: scanner-$SCANNER:$IMAGE_VERSION"
    return 1
  fi
}

# Export function for background execution
export -f build_scanner
export LOG_DIR

# Start max 4 parallel builds (adjust based on system resources)
parallel_jobs=4
active_jobs=0

for entry in "${SCANNERS[@]}"; do
  # Limit concurrent builds
  while [ $(jobs -r -p | wc -l) -ge $parallel_jobs ]; do
    sleep 5
  done

  # Start build in background
  build_scanner "$entry" &
done

# Wait for all builds to complete
wait

echo ""
echo "All builds completed. Check logs: $LOG_DIR"
```

---

## Push to Harbor

After all builds succeed, push to Harbor:

```bash
#!/bin/bash
# push-all-scanners.sh

cd /home/pwner/Git/blocksecops-tool-integration

SCANNERS=(
  "slither:0.3.0"
  "mythril:0.4.1"
  "aderyn:0.2.1"
  "wake:0.1.2"
  "semgrep:0.2.0"
  "solc-select:0.1.5"
  "soliditydefend:0.1.3"
  "rustdefend:0.1.1"
)

FAILED=()

for entry in "${SCANNERS[@]}"; do
  IFS=':' read -r SCANNER IMAGE_VERSION <<< "$entry"

  echo "Pushing scanner-$SCANNER:$IMAGE_VERSION..."

  if docker push harbor.blocksecops.local/blocksecops/scanner-$SCANNER:$IMAGE_VERSION; then
    echo "✅ Pushed: scanner-$SCANNER:$IMAGE_VERSION"
  else
    echo "❌ Failed to push: scanner-$SCANNER:$IMAGE_VERSION"
    FAILED+=("$SCANNER:$IMAGE_VERSION")
  fi
done

echo ""
if [ ${#FAILED[@]} -eq 0 ]; then
  echo "✅ All scanners pushed to Harbor successfully!"
else
  echo "❌ Failed pushes:"
  for f in "${FAILED[@]}"; do
    echo "   $f"
  done
  exit 1
fi
```

**Run the script:**

```bash
chmod +x push-all-scanners.sh
./push-all-scanners.sh
```

---

## Update ConfigMap and Deploy

After all images are pushed:

### Step 1: Verify All Images in Harbor

```bash
# List all scanner images
curl -s https://harbor.blocksecops.local/api/v2.0/projects/blocksecops/repositories \
  --insecure | jq '.[] | select(.name | startswith("scanner-")) | .name' | sort
```

### Step 2: Update ConfigMap (if needed)

If image versions changed, update ConfigMap:

```bash
# Edit ConfigMap
vim k8s/base/scanner-versions-configmap.yaml

# Update SCANNER_IMAGE_* entries to match new versions
# Update SCANNER_METADATA._note field with today's date

# Apply ConfigMap
kubectl apply -k k8s/base/
```

### Step 3: Update KJM Fallback Defaults

```bash
# Edit KJM defaults
vim src/scanners/kubernetes_job_manager.py

# Update default_images dict to match ConfigMap
# Example:
# default_images = {
#     "slither": "harbor.blocksecops.local/blocksecops/scanner-slither:0.3.0",
#     ...
# }
```

### Step 4: Rebuild and Deploy Tool-Integration

```bash
# Extract version
VERSION=$(grep '^version' pyproject.toml | cut -d'"' -f2)

# Build tool-integration with updated KJM defaults
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

---

## Verification

After deployment, verify all scanners use new images:

```bash
#!/bin/bash
# verify-all-scanners.sh

echo "Verifying all scanners..."
echo ""

SCANNERS=(slither mythril aderyn wake semgrep solc-select soliditydefend rustdefend)

for scanner in "${SCANNERS[@]}"; do
  echo "Checking: $scanner"

  # 1. Check ConfigMap
  echo -n "  ConfigMap: "
  kubectl get configmap scanner-versions -n tool-integration-local \
    -o jsonpath='{.data.SCANNER_IMAGE_*}' | grep -o "$scanner:[^\"]*" || echo "NOT FOUND"

  # 2. Create test scan job
  echo -n "  Creating test job... "
  JOB_ID=$(curl -s -X POST "http://127.0.0.1:8000/api/v1/scans" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "{\"contract_id\": \"<CONTRACT_ID>\", \"scanner_ids\": [\"$scanner\"]}" | jq -r '.id')

  if [ ! -z "$JOB_ID" ] && [ "$JOB_ID" != "null" ]; then
    echo "✅ Job created: $JOB_ID"

    # 3. Check job pod uses new image
    sleep 5
    POD=$(kubectl get pods -n tool-integration-local -l "scanner=$scanner" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [ ! -z "$POD" ]; then
      IMAGE=$(kubectl get pod -n tool-integration-local $POD -o jsonpath='{.spec.containers[0].image}')
      echo "  Pod image: $IMAGE"
    else
      echo "  (No pod found yet)"
    fi
  else
    echo "❌ Failed to create job"
  fi

  echo ""
done
```

**Quick verification:**

```bash
# Check tool-integration logs
kubectl logs -n tool-integration-local deployment/tool-integration --tail=100 | grep -i "scanner"

# Verify health endpoint
curl -s http://127.0.0.1:8000/api/v1/scanners/health | jq '.status'

# Check specific scanner
curl -s http://127.0.0.1:8000/api/v1/scanners/slither | jq '.image_version'
```

---

## Rollback Procedure

If rebuild causes issues:

```bash
# Quick rollback
kubectl rollout undo deployment/tool-integration -n tool-integration-local

# Or restore specific scanner image in ConfigMap
kubectl patch configmap scanner-versions -n tool-integration-local \
  --type merge -p '{"data":{"SCANNER_IMAGE_SLITHER":"harbor.blocksecops.local/blocksecops/scanner-slither:0.2.5"}}'

# Restart tool-integration
kubectl rollout restart deployment/tool-integration -n tool-integration-local
```

---

## Troubleshooting

### Build Fails: "OutOfMemory"

**Problem:** Docker build fails with out-of-memory error

**Solution:** Allocate more memory to Docker or build sequentially with longer waits:

```bash
# Check Docker memory allocation
docker stats --no-stream

# Increase Docker memory in settings (Mac: Docker Desktop → Preferences → Resources)
# Or rebuild with delays between scanners
```

### Push Fails: "Tag Already Exists"

**Problem:** Harbor rejects push because tag is immutable

**Solution:** Use a new, unique version tag:

```bash
# OLD: Tag already in Harbor
docker push harbor.blocksecops.local/blocksecops/scanner-slither:0.3.0
# → Fails (tag exists)

# NEW: Increment version
docker tag harbor.blocksecops.local/blocksecops/scanner-slither:0.3.0 \
  harbor.blocksecops.local/blocksecops/scanner-slither:0.3.1
docker push harbor.blocksecops.local/blocksecops/scanner-slither:0.3.1
```

### Partial Build Failure

**Problem:** Some scanners built successfully, others failed

**Solution:** Rebuild only failed scanners:

```bash
# List failed scanners from previous run
FAILED_SCANNERS=("soliditydefend" "rustdefend")

for scanner in "${FAILED_SCANNERS[@]}"; do
  docker build \
    --build-arg SCANNER_IMAGE_VERSION=0.3.1 \
    --build-arg UPSTREAM_TOOL_VERSION=<VERSION> \
    --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg VCS_REF=$(git rev-parse --short HEAD) \
    -t harbor.blocksecops.local/blocksecops/scanner-$scanner:0.3.1 \
    scanner-images/$scanner/
done
```

### Tool-Integration Pod Won't Start

**Problem:** Pod stuck in CrashLoopBackOff after rebuild

**Solution:** Check logs and rollback:

```bash
# Check logs
kubectl logs -n tool-integration-local deployment/tool-integration

# Rollback
kubectl rollout undo deployment/tool-integration -n tool-integration-local

# Check what changed (diff ConfigMap, KJM defaults)
git diff src/scanners/kubernetes_job_manager.py
```

---

## Documentation After Rebuild

After successful rebuild of all scanners:

1. **Update CHANGELOG** (if applicable)
2. **Update Scanner Documentation** with new image versions
3. **Update ConfigMap documentation** with new version numbers
4. **Commit all changes to Git:**

```bash
git add \
  k8s/base/scanner-versions-configmap.yaml \
  src/scanners/kubernetes_job_manager.py \
  pyproject.toml \
  k8s/overlays/local/kustomization.yaml

git commit -m "chore: rebuild all 16 scanner images with OCI label compliance

Rebuilt scanners with proper OCI labels (SCANNER_IMAGE_VERSION, UPSTREAM_TOOL_VERSION, BUILD_DATE, VCS_REF):
- slither:0.11.5 (image 0.3.0)
- mythril:0.23.0 (image 0.4.1)
- aderyn:0.2.0 (image 0.2.1)
- wake:4.5.0 (image 0.1.2)
- semgrep:1.45.2 (image 0.2.0)
- solc-select:1.0.4 (image 0.1.5)
- soliditydefend:0.1.8 (image 0.1.3)
- rustdefend:0.1.0 (image 0.1.1)

All images pushed to Harbor with immutable tags.
Tool-Integration rebuilt with updated KJM fallback defaults.

Verification: All scanner jobs use new images successfully."
```

---

## Checklist

- [ ] Database backup created (if needed)
- [ ] Current scanner versions documented
- [ ] All scanner Dockerfiles up-to-date
- [ ] ConfigMap has correct upstream versions
- [ ] Docker builds succeeds for all scanners
- [ ] OCI labels present in all images
- [ ] All images pushed to Harbor
- [ ] All images immutable in Harbor
- [ ] ConfigMap applied to cluster (if versions changed)
- [ ] KJM default_images dict updated
- [ ] Tool-integration rebuilt and deployed
- [ ] Tool-integration pod healthy (1/1 Ready)
- [ ] Test scan jobs created for all scanners
- [ ] All scanner jobs use new images
- [ ] Scanners produce expected output
- [ ] All changes committed to Git
- [ ] Documentation updated

---

## Related Documentation

- [Docker Image Versioning Standards](../standards/docker-image-versioning.md) - General versioning rules + scanner section
- [Scanner Image Version Bump Workflow](../workflows/scanner-image-version-bump.md) - Step-by-step version bump procedure
- [Scanner Image Build Pipeline](../pipelines/scanner-image-build-pipeline.md) - Build pipeline architecture
- [Upgrade Scanner Image Playbook](../playbooks/upgrade-scanner-image.md) - Individual scanner upgrade
- [Tool Metadata ConfigMaps Standard](../standards/tool-metadata-configmaps.md) - ConfigMap standards
