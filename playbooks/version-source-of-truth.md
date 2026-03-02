# Playbook: Version Source-of-Truth Management

**Version:** 1.0.0
**Last Updated:** March 1, 2026
**Status:** Active

## Overview

Operational procedures for managing service versions across the Apogee platform, including version bumps, drift detection, troubleshooting, and the deploy workflow.

## Prerequisites

- Access to service Git repositories (`~/Git/blocksecops-*`)
- `kubectl` access to the local Kubernetes cluster
- Docker CLI with push access to Harbor (`harbor.blocksecops.local`)
- Owner approval for all GitOps operations (Rule 0)

---

## Part 1: Version Bump

### 1.1 Bump a Python Service

```bash
cd ~/Git/blocksecops-<service>

# 1. Update source of truth
#    Edit pyproject.toml: version = "X.Y.Z"
sed -i 's/version = ".*"/version = "0.30.0"/' pyproject.toml

# 2. Update kustomization to match
#    Edit k8s/overlays/local/<service>/kustomization.yaml: newTag: "X.Y.Z"
sed -i 's/newTag: ".*"/newTag: "0.30.0"/' k8s/overlays/local/<service>/kustomization.yaml

# 3. If kustomization has app.kubernetes.io/version label, update that too
sed -i 's/app.kubernetes.io\/version: ".*"/app.kubernetes.io\/version: "0.30.0"/' \
  k8s/overlays/local/<service>/kustomization.yaml

# 4. Verify both match
grep '^version' pyproject.toml
grep 'newTag:' k8s/overlays/local/<service>/kustomization.yaml
```

### 1.2 Bump a Node.js Service

```bash
cd ~/Git/blocksecops-<service>

# 1. Update source of truth
npm version 0.47.0 --no-git-tag-version

# 2. Update kustomization to match
sed -i 's/newTag: ".*"/newTag: "0.47.0"/' k8s/overlays/local/kustomization.yaml

# 3. Verify
grep '"version"' package.json | head -1
grep 'newTag:' k8s/overlays/local/kustomization.yaml
```

### 1.3 Semantic Version Rules

| Change Type | Increment | Example |
|-------------|-----------|---------|
| Bug fix, security patch | PATCH | 0.29.53 -> 0.29.54 |
| New feature (backwards-compatible) | MINOR | 0.29.54 -> 0.30.0 |
| Breaking change | MAJOR | 0.30.0 -> 1.0.0 |

---

## Part 2: Deploy

### 2.1 Full Deploy (Recommended)

```bash
cd ~/Git/blocksecops-<service>

# Full cycle: version check -> build -> push -> apply -> verify
./scripts/deploy.sh
```

The script will:
1. Extract version from `pyproject.toml`/`package.json`
2. Verify kustomization `newTag` matches (fails if not)
3. Build Docker image with version as tag + build arg
4. Push to Harbor
5. Suspend CronJobs
6. `kubectl apply -k`
7. Wait for rollout
8. Verify deployed image tags
9. Resume CronJobs

### 2.2 Apply-Only Deploy (Skip Build)

When the image already exists in Harbor and you only need to update Kubernetes:

```bash
./scripts/deploy.sh --skip-build
```

### 2.3 Dry Run

Preview what would happen without executing:

```bash
./scripts/deploy.sh --dry-run
```

### 2.4 Dashboard Deploy (Special Case)

Dashboard requires parent directory build context:

```bash
cd ~/Git  # Parent directory

VERSION=$(grep '"version"' blocksecops-dashboard/package.json | head -1 | cut -d'"' -f4)
REGISTRY="${REGISTRY:-harbor.blocksecops.local}"

SUPABASE_URL=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_url}')
SUPABASE_KEY=$(kubectl get configmap -n dashboard-local dashboard-config -o jsonpath='{.data.supabase_anon_key}')

docker build \
  -f blocksecops-dashboard/Dockerfile \
  --build-arg VITE_SUPABASE_URL=${SUPABASE_URL} \
  --build-arg VITE_SUPABASE_ANON_KEY=${SUPABASE_KEY} \
  --build-arg SERVICE_VERSION=${VERSION} \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(cd blocksecops-dashboard && git rev-parse --short HEAD) \
  -t ${REGISTRY}/blocksecops/dashboard:${VERSION} .

docker push ${REGISTRY}/blocksecops/dashboard:${VERSION}
kubectl apply -k blocksecops-dashboard/k8s/overlays/local/
```

---

## Part 3: Drift Detection

### 3.1 Platform-Wide Check

```bash
# Check all services
~/Git/scripts/check-version-drift.sh

# Only show drift (exit code 1 if any)
~/Git/scripts/check-version-drift.sh --quiet
```

Output example:

```
=== Version Drift Check ===

  OK    notification  source=0.2.6  kustomize=0.2.6  cluster=0.2.6
  DRIFT api-service
        source=0.29.54  kustomize=0.29.39  cluster=0.29.39

── Summary ──
  OK:      8
  Drift:   1
  Skipped: 0

Version drift detected! Run deploy.sh for affected services:
  cd <service-repo> && ./scripts/deploy.sh
```

### 3.2 Single-Service Check

```bash
cd ~/Git/blocksecops-<service>

# Compare source vs kustomization
SOURCE=$(grep '^version' pyproject.toml | head -1 | cut -d'"' -f2)
KUSTOM=$(grep 'newTag:' k8s/overlays/local/<service>/kustomization.yaml | \
  sed 's/.*newTag: *"\{0,1\}\([^"]*\)"\{0,1\}/\1/' | tr -d ' ')
CLUSTER=$(kubectl get deployment -n <service>-local <service> \
  -o jsonpath='{.spec.template.spec.containers[0].image}' | rev | cut -d: -f1 | rev)

echo "Source:       $SOURCE"
echo "Kustomize:    $KUSTOM"
echo "Cluster:      $CLUSTER"
```

### 3.3 Fix Drift

```bash
cd ~/Git/blocksecops-<service>

# 1. Read current source version
SOURCE=$(grep '^version' pyproject.toml | head -1 | cut -d'"' -f2)

# 2. Update kustomization to match
sed -i "s/newTag: \".*\"/newTag: \"${SOURCE}\"/" k8s/overlays/local/<service>/kustomization.yaml

# 3. Deploy
./scripts/deploy.sh
```

---

## Part 4: Verification

### 4.1 Verify Deployed Version

```bash
SERVICE=api-service
NAMESPACE=api-service-local

# Deployment image
kubectl get deployment -n $NAMESPACE $SERVICE \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# CronJob images (if any)
kubectl get cronjob -n $NAMESPACE \
  -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.jobTemplate.spec.template.spec.containers[0].image}{"\n"}{end}'

# Running pod image
kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].spec.containers[*].image}'
```

### 4.2 Verify OCI Labels on Image

```bash
VERSION=$(grep '^version' pyproject.toml | head -1 | cut -d'"' -f2)
docker inspect --format='{{json .Config.Labels}}' \
  harbor.blocksecops.local/blocksecops/<service>:${VERSION} | jq
```

### 4.3 Verify Harbor Tag Exists

```bash
curl -s -k -u admin:${HARBOR_PASSWORD} \
  "https://harbor.blocksecops.local/api/v2.0/projects/blocksecops/repositories/<service>/artifacts?page_size=5" \
  | jq '.[].tags[].name'
```

---

## Part 5: Troubleshooting

### 5.1 `deploy.sh` Fails at Version Mismatch

**Symptom:** `Version mismatch! pyproject.toml: 0.30.0, kustomization.yaml: 0.29.39`

**Fix:** Update kustomization `newTag` to match source file:

```bash
sed -i 's/newTag: ".*"/newTag: "0.30.0"/' k8s/overlays/local/<service>/kustomization.yaml
./scripts/deploy.sh
```

### 5.2 Harbor Push Rejected (Immutable Tag)

**Symptom:** `MANIFEST_INVALID: the tag already exists` or similar push error

**Cause:** Harbor immutable tag policy prevents overwriting existing tags.

**Fix:** Bump version — even for a rebuild of the same code:

```bash
# Bump patch version
sed -i 's/version = "0.30.0"/version = "0.30.1"/' pyproject.toml
sed -i 's/newTag: "0.30.0"/newTag: "0.30.1"/' k8s/overlays/local/<service>/kustomization.yaml
./scripts/deploy.sh
```

### 5.3 CronJobs Stuck Suspended After Failed Deploy

**Symptom:** CronJobs not running after a failed `deploy.sh`

**Fix:**

```bash
kubectl get cronjob -n <namespace> -o name | \
  xargs -I{} kubectl patch {} -n <namespace> --type=merge -p '{"spec":{"suspend":false}}'
```

### 5.4 Pod Running Old Image After Deploy

**Symptom:** `kubectl get pods` shows old image tag

**Check:**

```bash
# 1. Verify kustomize was applied
kubectl get deployment -n <namespace> <service> \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# 2. If deployment spec is correct but pod is old, check rollout status
kubectl rollout status deployment/<service> -n <namespace>

# 3. Force restart if needed
kubectl rollout restart deployment/<service> -n <namespace>
```

### 5.5 VERSION File vs pyproject.toml Mismatch

**Symptom:** `VERSION` file shows different version than `pyproject.toml`

**Context:** The `VERSION` file is a legacy artifact. `pyproject.toml` is the source of truth.

**Fix:** Either update `VERSION` to match, or ignore it:

```bash
# Sync VERSION file to match source of truth
grep '^version' pyproject.toml | cut -d'"' -f2 > VERSION
```

The `VERSION` file is only used by the legacy `bump-version.sh` script, not by `deploy.sh`.

---

## Part 6: Checklist

### Pre-Deploy Checklist

- [ ] Source file version bumped (`pyproject.toml` or `package.json`)
- [ ] Kustomization `newTag` updated to match
- [ ] Owner approval obtained (Rule 0)
- [ ] `deploy.sh --dry-run` shows expected changes

### Post-Deploy Checklist

- [ ] `deploy.sh` exited 0 (all verifications passed)
- [ ] `check-version-drift.sh` shows no drift for the service
- [ ] Health endpoint returns 200: `curl -sk https://app.0xapogee.local/api/v1/health/ready`
- [ ] Source + kustomization committed together

---

## Related Documentation

- [Version Source-of-Truth Workflow](../workflows/version-source-of-truth-workflow.md)
- [Version Source-of-Truth Pipeline](../pipelines/version-source-of-truth-pipeline.md)
- [Docker Image Versioning Standards](../standards/docker-image-versioning.md)
- [Build Workflow Standards](../standards/build-workflow.md)
- [Local Build-Push-Apply Pipeline](../pipelines/local-build-push-apply-pipeline.md)
- [Development to Production Pipeline](../pipelines/dev-to-prod-pipeline.md)
